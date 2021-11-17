#!/usr/bin/python

import sys
for l in sys.stdin:
    l=l.strip()
    l=l.replace('"<s>"','')
    l=l.replace('"</s>"','')
    ll=l.split()
    lk=ll[0]
    for v in ll[1:]:
        v = v.decode('utf-8')
        for i in v:
           lk= lk + ' ' + i
        
    print lk.encode('utf-8')
