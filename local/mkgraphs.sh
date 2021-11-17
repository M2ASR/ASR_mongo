#!/usr/bin/env bash
#Copyright 2021  Tsinghua University Apache 2.0.

lm_unit=word

. ./path.sh ## Source the tools/utils (import the queue.pl)
. utils/parse_options.sh || exit 1;


model=$1
lang=$2
# make arpa lm and format lm with lang
echo "make HCLG" 

for lm in C T uni;do
  ./utils/mkgraph.sh $lang/lang_${lm}_${lm_unit} $model ${model}/graph_${lm}_${lm_unit} || exit 1;
done

echo "Success: make HCLG"
