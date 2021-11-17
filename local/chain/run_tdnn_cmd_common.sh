#!/bin/bash

set -e

stage=-10
nj=10
mfcc_dir=
fbank_dir=
test_dir=data/fbank/test
lang=data/lang_chain
gmm_dir=exp/tri4b
ali_dir=exp/tri4b_ali
lat_dir=exp/cmd_chain/gmm_lats
tree_dir=exp/cmd_chain/tree
dir=exp/cmd_chain/tdnn_relu_6l_context_L15-R15
lm=
# The rest are configs specific to this script.  Most of the parameters
# are just hardcoded at this level, in the commands below.
train_stage=-10
decode_stage=-3
get_egs_stage=-10
# TDNN options
frames_per_eg=150,120,90
remove_egs=false
common_egs_dir=
xent_regularize=0.1
preserve_model_interval=1
# End configuration section.
echo "$0 $@"  # Print the command line for logging

. ./cmd.sh
. ./path.sh
. parse_options.sh


# Please take this as a reference on how to specify all the options of
# local/chain/run_chain_common.sh
local/chain/run_chain_common.sh --stage $stage \
                                --gmm-dir $gmm_dir \
                                --ali-dir $ali_dir \
                                --lores-train-data-dir $mfcc_dir \
                                --lang $lang \
                                --lat-dir $lat_dir \
                                --num-leaves 510 \
                                --tree-dir $tree_dir || exit 1;

if [ $stage -le 14 ]; then
  echo "$0: creating neural net configs using the xconfig parser";

  num_targets=$(tree-info $tree_dir/tree | grep num-pdfs | awk '{print $2}')
  learning_rate_factor=$(echo "print 0.5/$xent_regularize" | python)
  opts="l2-regularize=0.002"
  output_opts="l2-regularize=0.0005"

  mkdir -p $dir/configs

  cat <<EOF > $dir/configs/network.xconfig
  input dim=40 name=input
      
  # please note that it is important to have input layer with the name=input
  # as the layer immediately preceding the fixed-affine-layer to enable
  # the use of short notation for the descriptor
  fixed-affine-layer name=lda input=Append(-3,0,3) affine-transform-file=$dir/configs/lda.mat
              
  # the first splicing is moved before the lda layer, so no splicing here
                
  relu-batchnorm-layer name=tdnn1 $opts dim=128 
  relu-batchnorm-layer name=tdnn2 $opts dim=128 input=Append(-3, 3)
  relu-batchnorm-layer name=tdnn3 $opts dim=128 input=Append(-3, 3)
  relu-batchnorm-layer name=tdnn4 $opts dim=128 input=Append(-3, 3)
  relu-batchnorm-layer name=tdnn5 $opts dim=128 input=Append(-3, 3)
                          
  relu-batchnorm-layer name=prefinal-chain input=tdnn5 $opts dim=128
  output-layer name=output include-log-softmax=false dim=$num_targets $output_opts
                              
  relu-batchnorm-layer name=prefinal-xent input=tdnn5 $opts dim=160
  output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor $output_opts

EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/
fi

if [ $stage -le 15 ]; then
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
    --trainer.num-chunk-per-minibatch 64 \
    --trainer.frames-per-iter 1500000 \
    --trainer.num-epochs 6 \
    --use-gpu='wait' \
    --trainer.optimization.num-jobs-initial 2 \
    --trainer.optimization.num-jobs-final 4 \
    --trainer.optimization.initial-effective-lrate 0.0008 \
    --trainer.optimization.final-effective-lrate 0.0001 \
    --trainer.max-param-change 2.0 \
    --cleanup.remove-egs $remove_egs \
    --cleanup.preserve-model-interval $preserve_model_interval \
    --feat-dir $fbank_dir \
    --tree-dir $tree_dir \
    --lat-dir $lat_dir \
    --dir $dir  || exit 1;
fi

if [ $stage -le 16 ];then
  echo "Train HCLG.fst"
  ./utils/format_lm.sh data/lang_chain $lm data/dict/lexicon.txt data/graph/lang
  ./utils/mkgraph.sh --self-loop-scale 1.0 data/graph/lang $dir data/graph/graph
fi

if [ $stage -le 17 ];then
echo "Decoding"
  steps/nnet3/decode.sh \
    --nj $nj --acwt 1.0 --post-decode-acwt 10.0 \
    --cmd "$decode_cmd" --stage $decode_stage \
    --iter final --beam 13 \
    data/graph/graph $test_dir \
    $dir/decode_graph_final

  wer=`cat $dir/decode_graph_final/scoring_kaldi/best_wer`
  echo "Baseline WER : $wer"
fi
