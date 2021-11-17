#!/usr/bin/env bash
#Copyright 2021  Tsinghua University Apache 2.0.

nj=8
mono=false
lm_unit=word
graph=

. ./cmd.sh 
. ./path.sh

. utils/parse_options.sh || exit 1;
decoder=$1
srcdir=$2
datadir=$3


if [ $mono = true ];then
  echo  "using monophone to generate graph"
  opt="--mono"
fi

for lm in C T uni;do
  $decoder --cmd "$decode_cmd" --nj $nj $srcdir/graph_${lm}_${lm_unit} $datadir/test $srcdir/decode_${lm}_${unit} || exit 1
done
