#!/usr/bin/env bash
#Copyright 2021  Tsinghua University Apache 2.0.


. ./path.sh ## Source the tools/utils (import the queue.pl)
. utils/parse_options.sh || exit 1;


corpus=$1

# prepare letter training and test set
for dir in train test;do
    if [ ! -d data/${dir}_letter ];then
      mkdir -p data/${dir}_letter
    fi
    awk '{printf($1" ")
         for(x=2;x<=NF;x++){
           for(y=1;y<=length($x)-1;y++)
             printf(substr($x, y, 1)" ")
           printf(substr($x, length($x), 1)"# ")}
         print("")
    }' $corpus/$dir/text > data/${dir}_letter/text || exit 1;
    cp $corpus/$dir/{utt2spk,spk2utt,spk2gender} data/${dir}_letter/ || exit 1;
done

# prepare C,T,uni_lm;do
for dir in C_lm T_lm uni_lm;do
    if [ ! -d data/${dir}_letter ];then
       mkdir -p data/${dir}_letter
    fi
    awk '{print $1;print $1"#"}' $corpus/dict/nonsilence_phones.txt > data/${dir}_letter/words.txt
    awk '{for(x=1;x<=NF;x++){
            for(y=1;y<=length($x)-1;y++)
              printf(substr($x, y, 1" "))
            printf(substr($x, length($x), 1)"# ")}
          print("")
         }' $corpus/${dir}/text > data/${dir}_letter/text
done

# prepare dict
if [ ! -d data/dict_letter ];then
   mkdir -p data/dict_letter
fi
rm -f data/dict_letter/lexicon.txt data/dict_letter/lm_lexicon.txt
rm -f data/dict_letter/silence_phones.txt data/dict_letter/optional_silence.txt
echo "SIL sil" >> data/dict_letter/lexicon.txt
echo "<SPOKEN_NOISE> sil" >> data/dict_letter/lexicon.txt
awk '{print $1" "$1;print $1"# "$1"1"}' $corpus/dict/nonsilence_phones.txt >> data/dict_letter/lexicon.txt
awk '{print $1" "$1;print $1"# "$1"1"}' $corpus/dict/nonsilence_phones.txt >> data/dict_letter/lm_lexicon.txt
awk '{print $1;print $1"1"}' $corpus/dict/nonsilence_phones.txt > data/dict_letter/nonsilence_phones.txt
touch data/dict_letter/extra_questions.txt
echo "sil" >> data/dict_letter/silence_phones.txt
echo "sil" >> data/dict_letter/optional_silence.txt

