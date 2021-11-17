#!/usr/bin/env bash

#    This is the standard "tdnn" system, built in nnet3 with xconfigs.

set -e -o pipefail -u

stage=0
nj=5

lm_unit=word
train_stage=-10
remove_egs=false
srand=0
# set common_egs_dir to use previously dumped egs.
common_egs_dir=

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

if [ "$lm_unit" == "word" ];then
   suffix=""
else
   suffix="_letter"
fi

gmm_dir=exp${suffix}/tri4b
ali_dir=exp${suffix}/tri4b_ali
dir=exp${suffix}/nnet3/tdnn
train_data_dir=data/fbank_${lm_unit}/train
test_data_dir=data/fbank_${lm_unit}/test


if [ $stage -le 1 ];then
   rm -rf data/fbank_${lm_unit} && mkdir -p data/fbank_${lm_unit} && cp -R data/train data/fbank_${lm_unit} && cp -R data/test data/fbank_${lm_unit}
   for files in wav.scp spk2utt utt2spk text spk2gender;do
     cp data/mfcc_${lm_unit}/train/${files} data/fbank_${lm_unit}/train/
     cp data/mfcc_${lm_unit}/test/${files} data/fbank_${lm_unit}/test/
   done

   for x in train test;do
     ./steps/make_fbank.sh --fbank-config conf/fbank.conf --nj $nj --cmd "$train_cmd" data/fbank_${lm_unit}/$x exp${suffix}/make_fbank/ exp${suffix}/make_fbank || exit 1
     ./steps/compute_cmvn_stats.sh data/fbank_${lm_unit}/train exp${suffix}/train/fbank_cmvn/ exp${suffix}/train/fbank_cmvn/ || exit 1
   done
fi


if [ $stage -le 2 ]; then
  mkdir -p $dir
  echo "$0: creating neural net configs using the xconfig parser";

  num_targets=$(tree-info $gmm_dir/tree |grep num-pdfs|awk '{print $2}')

  mkdir -p $dir/configs
  cat <<EOF > $dir/configs/network.xconfig
  input dim=40 name=input

  # please note that it is important to have input layer with the name=input
  # as the layer immediately preceding the fixed-affine-layer to enable
  # the use of short notation for the descriptor
  fixed-affine-layer name=lda input=Append(-2,-1,0,1,2) affine-transform-file=$dir/configs/lda.mat

  # the first splicing is moved before the lda layer, so no splicing here
  relu-renorm-layer name=tdnn1 dim=650
  relu-renorm-layer name=tdnn2 dim=650 input=Append(-1,0,1)
  relu-renorm-layer name=tdnn3 dim=650 input=Append(-1,0,1)
  relu-renorm-layer name=tdnn4 dim=650 input=Append(-3,0,3)
  relu-renorm-layer name=tdnn5 dim=650 input=Append(-6,-3,0)
  output-layer name=output dim=$num_targets max-change=1.5
EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/
fi

if [ $stage -le 3 ]; then

  steps/nnet3/train_dnn.py --stage=$train_stage \
    --cmd="$train_cmd" \
    --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
    --trainer.srand=$srand \
    --trainer.max-param-change=2.0 \
    --trainer.num-epochs=8 \
    --trainer.samples-per-iter=400000 \
    --trainer.optimization.num-jobs-initial=2 \
    --trainer.optimization.num-jobs-final=6 \
    --trainer.optimization.initial-effective-lrate=0.0015 \
    --trainer.optimization.final-effective-lrate=0.00015 \
    --trainer.optimization.minibatch-size=256,128 \
    --egs.dir="$common_egs_dir" \
    --cleanup.remove-egs=$remove_egs \
    --use-gpu=wait \
    --feat-dir=$train_data_dir \
    --ali-dir=$ali_dir \
    --lang=data/lang \
    --dir=$dir  || exit 1;
fi

if [ $stage -le 4 ]; then
  for lm in C T uni;do
    ./steps/nnet3/decode.sh \
    $gmm_dir/graph_${lm}_${lm_unit} \
    data/fbank_${lm_unit}/test $dir/decode_${lm}_${lm_unit} || exit 1;
  done
fi