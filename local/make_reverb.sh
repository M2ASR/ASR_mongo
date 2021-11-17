#!/bin/bash

# v is volume changing factor
# r is the room scale of reverb
v=(0.1 0.2 0.3 0.4 0.4 0.4 0.5 0.6 0.6 0.6)
r=(100 100 100 80 80 80 60 60 40 40)


function random(){
  min=$1;
  max=$2-$1;
  num=$(($RANDOM+1234567));
  ((rnum=num%max+min));
  echo $rnum;
}

scp=$1
reverb=$2

if [ ! -d $reverb ];then
    mkdir -p $reverb
fi
echo "Wavname volume_factor reverb_factor"
cat $scp | while read line;do
    wav=`echo $line | cut -d' ' -f2`
    wavname=`basename $wav| sed s/.wav//g`
    rvi=$(random 1 10)
    rv=${v[$rvi]}
    rri=$(random 1 10)
    rr=${r[$rri]}
    echo $wavname $rv $rr
    #sox -v $rv $wav ${reverb}/${wavname}.${rv}.${rr}.wav reverb 100 0 $rr 0 0 
    sox -v $rv $wav ${reverb}/${wavname}.wav reverb 100 0 $rr 0 0 
done
