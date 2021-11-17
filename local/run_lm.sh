#!/bin/bash
corpus=$1
order=$2
name=$3
vocab=$4

if [ $# != 4 ];then
  echo "Usage: $0 <corpus> <order> <name> <vocab>"
  exit 0
fi
soom=""
for s in `seq $order`;do
   soom=$soom" -addsmooth"${s}" 1" 
done
echo $soom
ngram-count -text $corpus -order $order -write ${name}.${order}.count 
ngram-count -vocab $vocab $soom  -limit-vocab $vocab -read ${name}.${order}.count -order $order -lm ${name}.${order}.lm
