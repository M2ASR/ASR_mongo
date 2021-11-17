# -*- coding:utf-8 -*-
# Author: Ying Shi

import os
import sys
import argparse
import random
import string

def get_args():
    # ArgumentParser
    parser = argparse.ArgumentParser(
        description = "Read a data path and find files with specific suffix "
        "and print it as kaldi scp format <id path>")
    parser.add_argument('--data-dir', required = True,
                       help = 'root dir of data')
    parser.add_argument('--suffix', default = 'wav',
                        help = 'File suffix you want to find')
    parser.add_argument('--random-name', default = False, 
                                   help = 'add a random string to the tail of id'
                                   ' to prevent the duplicate of id')

    args = parser.parse_args()
    return args


def find_file(path, suffix = 'wav', rnd_name = False):
    # Recursive search file by specific suffix
    for items in os.listdir(path):
       sub_path = path + '/' + items
       if os.path.isdir(sub_path):
           find_file(sub_path, suffix, rnd_name)
       elif items.endswith(suffix):
           sub_suffix = make_rand() if rnd_name else ""
           name = items.replace("." + suffix, "") + sub_suffix
           print ("{} {}".format(name, sub_path))


def make_rand():
    # make random name suffix 
    return "-SUB" + "".join(random.sample(string.ascii_letters + string.digits, 10))
       


if __name__ == "__main__":
    
    args = get_args()
    kwargs = {'suffix': args.suffix, 'rnd_name': args.random_name}
    find_file(args.data_dir, **kwargs)
