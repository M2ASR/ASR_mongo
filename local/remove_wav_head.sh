#!/bin/bash

wav_scp=$1
save_path=$2


cat $wav_scp | while read line;do
    wav=`echo $line|cut -d' ' -f2`
    wavname=`basename $wav | sed s/.wav//g`
    sox $wav -t raw $save_path/${wavname}.pcm
done
