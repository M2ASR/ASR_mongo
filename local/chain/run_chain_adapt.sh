#!/bin/bash

set -e

stage=-1
nj=10

# data and ali dir
mfcc_dir=data/train/mfcc
fbank_dir=data/train/fbank
ali_dir=exp/tri4b_ali
gmm_dir=exp/tri4b

# for decode
lang_dir=data/lang
test_dir=data/fbank/test

# The rest are configs specific to this script.  Most of the parameters
# are just hardcoded at this level, in the commands below.
train_stage=-10
get_egs_stage=-10
decode_iter=

# TDNN options
frames_per_eg=150,120,90
remove_egs=false
xent_regularize=0.1
preserve_model_interval=5
common_egs_dir=
input_model=exp/chain-skip/tdnn-f-cn/final.mdl
tree_dir=exp/chain-skip/tree
chain_lang=data/lang_chain
lat_dir=exp/chain-skip/gmm_lats_ada
re_build_tree=true
dir=

# End configuration section.
echo "$0 $@"  # Print the command line for logging

. ./cmd.sh
. ./path.sh
. parse_options.sh

# if we are using the speed-perturbed data we need to generate
# alignments for it.

for f in $gmm_dir/final.mdl $fbank_dir/feats.scp \
    $mfcc_dir/feats.scp $input_model; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done

if [ $stage -le 0 ];then
    
  if $re_build_tree ;then
    echo "Re-build tree according to new training data"
    echo "Make alignment for training data"
    steps/align_fmllr.sh --nj $nj --cmd "$train_cmd" $mfcc_dir data/lang $gmm_dir $ali_dir
    tree_dir=${tree_dir}_rebuild
    local/chain/run_chain_common.sh --stage $stage \
                                  --gmm-dir $gmm_dir \
                                  --ali-dir $ali_dir \
                                  --lores-train-data-dir $mfcc_dir \
                                  --lang $chain_lang \
                                  --lat-dir $lat_dir \
                                  --num-leaves 510 \
                                  --tree-dir $tree_dir || exit 1;
    num_pdfs=`tree-info $tree_dir/tree | grep num-pdfs | awk '{print $2}'`
    mkdir -p $dir/configs/
    cat << EOF > $dir/configs/init_final.config
    component name=prefinal-chain.affine type=NaturalGradientAffineComponent input-dim=128 output-dim=128  max-change=0.75 l2-regularize=0.002
    component-node name=prefinal-chain.affine component=prefinal-chain.affine input=tdnn5.batchnorm
    component name=prefinal-chain.relu type=RectifiedLinearComponent dim=128 self-repair-scale=1e-05
    component-node name=prefinal-chain.relu component=prefinal-chain.relu input=prefinal-chain.affine
    component name=prefinal-chain.batchnorm type=BatchNormComponent dim=128 target-rms=1.0
    component-node name=prefinal-chain.batchnorm component=prefinal-chain.batchnorm input=prefinal-chain.relu
    component name=output.affine type=NaturalGradientAffineComponent input-dim=128 output-dim=$num_pdfs  l2-regularize=0.0005 max-change=1.5 param-stddev=0.0 bias-stddev=0.0
    component-node name=output.affine component=output.affine input=prefinal-chain.batchnorm
    output-node name=output input=output.affine objective=linear
    component name=prefinal-xent.affine type=NaturalGradientAffineComponent input-dim=128 output-dim=160  max-change=0.75 l2-regularize=0.002
    component-node name=prefinal-xent.affine component=prefinal-xent.affine input=tdnn5.batchnorm
    component name=prefinal-xent.relu type=RectifiedLinearComponent dim=160 self-repair-scale=1e-05
    component-node name=prefinal-xent.relu component=prefinal-xent.relu input=prefinal-xent.affine
    component name=prefinal-xent.batchnorm type=BatchNormComponent dim=160 target-rms=1.0
    component-node name=prefinal-xent.batchnorm component=prefinal-xent.batchnorm input=prefinal-xent.relu
    component name=output-xent.affine type=NaturalGradientAffineComponent input-dim=160 output-dim=$num_pdfs learning-rate-factor=5.0 l2-regularize=0.0005 max-change=1.5 param-stddev=0.0 bias-stddev=0.0
    component-node name=output-xent.affine component=output-xent.affine input=prefinal-xent.batchnorm
    component name=output-xent.log-softmax type=LogSoftmaxComponent dim=$num_pdfs
    component-node name=output-xent.log-softmax component=output-xent.log-softmax input=output-xent.affine
    output-node name=output-xent input=output-xent.log-softmax objective=linear
EOF
    nnet3-init $input_model $dir/configs/init_final.config $dir/0.mdl
    input_model=$dir/0.mdl
  else
    echo "Genearte lattice for training data"
    steps/align_fmllr_lats.sh  --nj $nj --cmd "$train_cmd" ${mfcc_dir} \
     $lang_dir $gmm_dir $lat_dir || exit 1;
  fi
fi

if [ $stage -le 1 ]; then
 if [ ! -d $dir ];then
    mkdir -p $dir 
 fi
 steps/nnet3/chain/train.py --stage $train_stage \
    --cmd "$cuda_cmd" \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
    --chain.xent-regularize $xent_regularize \
    --chain.leaky-hmm-coefficient 0.1 \
    --chain.l2-regularize 0.0 \
    --chain.apply-deriv-weights false \
    --chain.lm-opts="--num-extra-lm-states=2000" \
    --egs.dir "$common_egs_dir" \
    --egs.stage $get_egs_stage \
    --egs.opts "--frames-overlap-per-eg 0" \
    --egs.chunk-width $frames_per_eg \
    --trainer.num-chunk-per-minibatch 128  \
    --trainer.frames-per-iter 1500000 \
    --trainer.num-epochs 4 \
    --use-gpu='wait' \
    --trainer.optimization.num-jobs-initial 2 \
    --trainer.optimization.num-jobs-final 4 \
    --trainer.optimization.initial-effective-lrate 0.001 \
    --trainer.optimization.final-effective-lrate 0.0001 \
    --trainer.max-param-change 2.0 \
    --trainer.input-model=$input_model \
    --cleanup.remove-egs $remove_egs \
    --cleanup.preserve-model-interval $preserve_model_interval \
    --feat-dir $fbank_dir \
    --tree-dir $tree_dir \
    --lat-dir $lat_dir \
    --dir $dir  || exit 1;
fi
