#!/usr/bin/env bash
#Copyright 2021  Tsinghua University Apache 2.0.

lm_order=3
lm_unit=word
lang=data/lang
lexicon=data/dict/word_lm_lexicon.txt

. ./path.sh ## Source the tools/utils (import the queue.pl)
. utils/parse_options.sh || exit 1;

if ! `command -v ngram 1>/dev/null`; then
   echo "Error: srilm toolkit is not installed"
   echo "You are suggested to install srilm by tools/extras/install_srilm.sh" 
   exit 1;
fi

graph_dir=$1

# make arpa lm and format lm with lang
echo "make arpa lm and format lm with lang"

for files in $lang/phones.txt $lexicon;do
   if [ ! -f $files ];then
     echo "No such file $files" && exit 1;
   fi
done

for lm in C T uni;do
  lm_dir=${lm}_lm_${lm_unit}
  ./local/run_lm.sh data/${lm_dir}/text $lm_order data/${lm_dir}/${lm} data/${lm_dir}/words.txt || exit 1;
  tar -zcvf data/${lm_dir}/${lm}.${lm_order}.lm.tar.gz data/${lm_dir}/${lm}.${lm_order}.lm || exit 1;
  ./utils/format_lm.sh $lang data/${lm_dir}/${lm}.${lm_order}.lm.tar.gz $lexicon $graph_dir/lang_${lm}_${lm_unit} || exit 1;
done

echo "C_lm, T_lm and unic lm have been made and formated"
