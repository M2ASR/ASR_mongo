#!/bin/bash
# Copyright 2021 Tsinghua University Apache 2.0.

. ./cmd.sh
. ./path.sh

n=20      #parallel jobs
stage=4
lm_order=3
decode=true
corpus=/m2asr/mongolian/corpus


#1. prepare data
if [ $stage -le 1 ];then
    for dir in train test dict C_lm T_lm;do
      if [ ! -d $corpus/${dir} ];then
        echo "There is no $dir directory in corpus dir: ${corpus}" 
        echo "Please check and keep the corpus dir in original form"
        echo "Or visit m2asr.cslt.org to request the corpus" && exit 1;
      fi 
    done

    if [ ! -d data ];then
      mkdir data
    fi

    cp -r $corpus/{train,test,dict,C_lm,T_lm,uni_lm} data/ || exit 1;
    ln -s `realpath data/C_lm` data/C_lm_word 
    ln -s `realpath data/T_lm` data/T_lm_word
    ln -s `realpath data/uni_lm` data/uni_lm_word
fi

#2. generate mfcc and fetures
if [ $stage -lt 2 ];then
    rm -rf data/mfcc_word && mkdir -p data/mfcc_word &&  cp -R data/train data/mfcc_word && cp -R data/test data/mfcc_word/
    for x in train test; do
        python3 ./local/search_file.py --data-dir `realpath ${corpus}/wav ` | sort > data/mfcc_word/$x/wav.scp || exit 1;
        ./utils/fix_data_dir.sh data/mfcc_word/$x/ 
        steps/make_mfcc.sh --mfcc-config conf/mfcc.conf  --nj $n --cmd "$train_cmd" data/mfcc_word/$x exp/make_mfcc/$x exp/make_mfcc/$x || exit 1;
        steps/compute_cmvn_stats.sh data/mfcc_word/$x exp/mfcc_cmvn/$x exp/mfcc_cmvn/$x || exit 1;
    done
fi

#3.prepare language, make and format lm
if [ $stage -le 3 ];then
    utils/prepare_lang.sh --position_dependent_phones false data/dict "<SPOKEN_NOISE>" data/local/lang data/lang/ || exit 1;
    ./local/make_format_lm.sh --lm_order $lm_order --lang data/lang --lm_unit word --lexicon data/dict/word_lm_lexicon.txt data/graph || exit 1;
fi

#4.train model
if [ $stage -le 4 ];then
    context_opts="--context-width=3 --central-position=1"
    splice_opts="--left-context=3 --right-context=3"
    mfcc_data=data/mfcc_word/train/

    if false;then
    #monophone
    steps/train_mono.sh --boost-silence 1.25 --nj $n --cmd "$train_cmd" $mfcc_data data/lang/ exp/mono || exit 1;
    #monophone_ali
    steps/align_si.sh --boost-silence 1.25 --nj $n --cmd "$train_cmd" $mfcc_data data/lang/ exp/mono exp/mono_ali || exit 1;

    #triphone
    steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" 1200 7000 $mfcc_data data/lang/ exp/mono_ali exp/tri1 || exit 1;
    #triphone_ali
    steps/align_si.sh --nj $n --cmd "$train_cmd" $mfcc_data data/lang/ exp/tri1 exp/tri1_ali || exit 1;

    #lda_mllt
    steps/train_lda_mllt.sh --cmd "$train_cmd" --context-opts "$context_opts" --splice-opts "$splice_opts"  2500 15000  $mfcc_data data/lang/ exp/tri1_ali exp/tri2b || exit 1;
    #lda_mllt_ali
    steps/align_si.sh  --nj $n --cmd "$train_cmd" --use_graphs true $mfcc_data data/lang/ exp/tri2b exp/tri2b_ali || exit 1;

    #sat
    steps/train_sat.sh --context-opts "$context_opts"  --cmd "$train_cmd" 2500 15000 $mfcc_data data/lang/ exp/tri2b_ali exp/tri3b ||  exit 1;
    #sat_ali
    steps/align_fmllr.sh --nj $n --cmd "$train_cmd" $mfcc_data data/lang/ exp/tri3b exp/tri3b_ali || exit 1;
    fi

    #quick
    steps/train_quick.sh --cmd "$train_cmd" 6200 40000 $mfcc_data data/lang/ exp/tri3b_ali exp/tri4b || exit 1;
    #quick_ali
    steps/align_fmllr.sh --nj $n --cmd "$train_cmd" $mfcc_data data/lang/ exp/tri4b exp/tri4b_ali || exit 1;

    if [ $decode ];then
      ./local/mkgraphs.sh --lm_unit word exp/tri4b/ data/graph/ || exit 1;
      ./local/decode_mongo.sh --nj $n  "steps/decode_fmllr.sh" exp/tri4b/ data/mfcc_word/test || exit 1;
    fi

fi

#5.TDNN
if [ $stage -le 5 ];then
     sh run_tdnn.sh
fi
