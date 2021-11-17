#!/bin/bash

pcm_scp=$1
save_path=$2

cat $pcm_scp | while read line;do

    pcm=`echo $line | cut -d' ' -f2`
    pcm_name=`basename $pcm | sed s/.pcm//g`
    
    rtc_agc $pcm $save_path/agc/pcm/${pcm_name}.pcm
    rtc_ns $pcm $save_path/ns/pcm/${pcm_name}.pcm
    
    # ns agc
    rtc_agc $save_path/ns/pcm/${pcm_name}.pcm $save_path/ns_agc/pcm/${pcm_name}.pcm

    # agc ns
    rtc_ns  $save_path/agc/pcm/${pcm_name}.pcm  $save_path/agc_ns/pcm/${pcm_name}.pcm

done
