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

    ./local/prepare_letter.sh $corpus data/
fi

#2. generate mfcc fetures
if [ $stage -lt 2 ];then
    rm -rf data/mfcc_letter && mkdir -p data/mfcc_letter && \
    cp -R data/train_letter data/mfcc_letter/train && cp -R data/test_letter data/mfcc_letter/test
    for x in train test; do
        python3 ./local/search_file.py --data-dir `realpath ${corpus}/wav ` | sort > data/mfcc_letter/$x/wav.scp || exit 1;
        ./utils/fix_data_dir.sh data/mfcc_letter/$x/ 
        steps/make_mfcc.sh --mfcc-config conf/mfcc.conf  --nj $n --cmd "$train_cmd" \
           data/mfcc_letter/$x exp_letter/make_mfcc/$x exp_letter/mfcc/$x || exit 1;
        steps/compute_cmvn_stats.sh data/mfcc_letter/$x exp_letter/mfcc_cmvn/$x exp_letter/mfcc_cmvn/$x || exit 1;
    done
fi

#3.prepare language, make and format lm
if [ $stage -le 3 ];then
    utils/prepare_lang.sh --position_dependent_phones false data/dict_letter "<SPOKEN_NOISE>" \
        data/local/lang_letter data/lang_letter/ || exit 1;
    ./local/make_format_lm.sh --lm_order $lm_order --lang data/lang_letter --lm_unit letter \
        --lexicon data/dict_letter/lm_lexicon.txt data/graph_letter || exit 1;
fi

#4.train model
if [ $stage -le 4 ];then
    context_opts="--context-width=3 --central-position=1"
    splice_opts="--left-context=3 --right-context=3"
    mfcc_data=data/mfcc_letter/train/

    if false;then
    #monophone
    steps/train_mono.sh --boost-silence 1.25 --nj $n --cmd "$train_cmd" $mfcc_data \
        data/lang_letter/ exp_letter/mono || exit 1;
    #monophone_ali
    steps/align_si.sh --boost-silence 1.25 --nj $n --cmd "$train_cmd" $mfcc_data \
        data/lang_letter/ exp_letter/mono exp_letter/mono_ali || exit 1;

    #triphone
    steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" 1000 7000 \
        $mfcc_data data/lang_letter/ exp_letter/mono_ali exp_letter/tri1 || exit 1;
    #triphone_ali
    steps/align_si.sh --nj $n --cmd "$train_cmd" $mfcc_data data/lang_letter/ \
        exp_letter/tri1 exp_letter/tri1_ali || exit 1;

    #lda_mllt
    steps/train_lda_mllt.sh --cmd "$train_cmd" --context-opts "$context_opts" \
        --splice-opts "$splice_opts"  2500 15000  $mfcc_data data/lang_letter/  \
        exp_letter/tri1_ali exp_letter/tri2b || exit 1;
    #lda_mllt_ali
    steps/align_si.sh  --nj $n --cmd "$train_cmd" --use_graphs true $mfcc_data \
        data/lang_letter/ exp_letter/tri2b exp_letter/tri2b_ali || exit 1;

    #sat
    steps/train_sat.sh --context-opts "$context_opts"  --cmd "$train_cmd" 2500 15000 \
        $mfcc_data data/lang_letter/ exp_letter/tri2b_ali exp_letter/tri3b ||  exit 1;
    #sat_ali
    steps/align_fmllr.sh --nj $n --cmd "$train_cmd" $mfcc_data data/lang_letter/ \
        exp_letter/tri3b exp_letter/tri3b_ali || exit 1;

    #quick
    steps/train_quick.sh --cmd "$train_cmd" 6200 40000 $mfcc_data data/lang_letter/ \
        exp_letter/tri3b_ali exp_letter/tri4b || exit 1;
    #quick_ali
    steps/align_fmllr.sh --nj $n --cmd "$train_cmd" $mfcc_data data/lang_letter/ \
        exp_letter/tri4b exp_letter/tri4b_ali || exit 1;

    fi
    if [ $decode ];then
      ./local/mkgraphs.sh --$lm_unit letter exp_letter/tri4b/ data/graph/ || exit 1;
      ./local/decode_mongo.sh --nj $n  "steps/decode_fmllr.sh"  \
          exp_letter/tri4b/ data/mfcc_letter/test || exit 1;
    fi

fi

#5.TDNN
if [ $stage -le 5 ];then
     sh run_tdnn.sh --lm_unit letter
fi
