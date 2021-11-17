export KALDI_ROOT=home/shiying/toolkit/kaldi/kaldi.5.5
export SRILM_ROOT=home/shiying/toolkit/kaldi/kaldi.5.5/tools/srilm/bin/i686-m64
export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:$KALDI_ROOT/tools/sph2pipe_v2.5:$SRILM_ROOT:$PWD:$PATH
[ ! -f $KALDI_ROOT/tools/config/common_path.sh ] && echo >&2 "The standard file $KALDI_ROOT/tools/config/common_path.sh is not present -> Exit!" && exit 1
. $KALDI_ROOT/tools/config/common_path.sh
export LC_ALL=C
