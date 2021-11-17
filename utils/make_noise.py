import sys
import os
import numpy as np 

'''
wav-reverberate --shift-output=true --additive-signals='/work102/shiying/CSLTProject/huawei_enhancement/enhance_reverb_noise/data/airport_noise/cut/noise_00010002_05_02_TP_05.1.wav,/work102/shiying/CSLTProject/huawei_enhancement/enhance_reverb_noise/data/airport_noise/cut/noise_00010002_05_02_TP_05.13.wav,/work102/shiying/CSLTProject/huawei_enhancement/enhance_reverb_noise/data/airport_noise/cut/noise_00010002_05_02_TP_05.18.wav' --start-times='0,0,0' --snrs='3,5,3' /work102/shiying/CSLTProject/huawei_enhancement/enhance_reverb_noise/data/aishell_sub/reverb/ID2166W0430.0.3.60.wav noisy.3.5.3.wav
'''

wav_scp = sys.argv[1]
noise_scp = sys.argv[2]
outdir = sys.argv[3]
write_script = sys.argv[4] 

wf = open(write_script, 'a')
wf.write("#!/bin/bash\n")


write_command = 'wav-reverberate --shift-output=true --additive-signals='
opt = '--start-times="0,0,0"'

with open(noise_scp) as nf:
    noise_wav = [x.strip().split()[1] for x in nf.readlines()]

num_noise = len(noise_wav)

wavf = open(wav_scp, 'r')

for utt_detail in wavf.readlines():
    utt, wav = utt_detail.strip().split()
    wavname=wav.split('/')[-1]
    snr = np.random.normal(loc=8, scale=2, size=3)
    snr = map(lambda x: str(x), snr)
    noise_index = np.random.randint(0, num_noise, 3)
    noise_list = [noise_wav[x] for x in noise_index.tolist()]
    write_line = '{command}"{noise}" {opt} --snrs="{snrs}" {wav} {outdir}/{out}\n'.format(
                  command=write_command, noise=",".join(noise_list), opt=opt, snrs=",".join(list(snr)), 
                  wav=wav, outdir=outdir, out=wavname)
    print(write_line, flush=True)
    wf.write(write_line)

wf.close()
