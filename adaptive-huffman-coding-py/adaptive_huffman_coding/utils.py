import collections
import itertools
import math

from matplotlib import pyplot as plt
from PIL import Image
import numpy as np


def show_raw_img(original_filename, extracted_filename, code, size):
    with open(original_filename, 'rb') as img_file:
        try:
            original_img = Image.frombytes(code, size, img_file.read())
        except:
            original_img = plt.imread(original_filename)
#        original_img = np.fromfile(img_file, dtype=np.uint8)
    with open(extracted_filename, 'rb') as img_file:
        try:
            extracted_img = Image.frombytes(code, size, img_file.read())
        except:
            extracted_img = plt.imread(extracted_filename)
#        extracted_img = np.fromfile(img_file, dtype=np.uint8)
#    original_img.shape = extracted_img.shape = size
    _, axarr = plt.subplots(1, 2)
    axarr[0].set_title('Imagen Transmitida')
    axarr[0].imshow(original_img, cmap='gray')
    axarr[1].set_title('Imagen Recibida')
    axarr[1].imshow(extracted_img, cmap='gray')
    axarr[0].axes.get_xaxis().set_visible(False)
    axarr[0].axes.get_yaxis().set_visible(False)
    axarr[1].axes.get_xaxis().set_visible(False)
    axarr[1].axes.get_yaxis().set_visible(False)
    plt.show()


def encode_dpcm(seq):
    return (
        (item - seq[idx - 1]) & 0xff if idx else item
        for idx, item in enumerate(seq)
    )


def decode_dpcm(seq):
    return itertools.accumulate(seq, lambda x, y: (x + y) & 0xff)


def bin_str2bool_list(binary_string):
    return [c == '1' for c in binary_string]


def bool_list2bin_str(boolean_list):
    return ''.join('1' if i else '0' for i in boolean_list)


def bool_list2int(boolean_list):
    return sum(v << i for i, v in enumerate(reversed(boolean_list)))


def entropy(byte_seq):
    counter = collections.Counter(byte_seq)
    ret = 0
    for count in counter.values():
        prob = count / sum(counter.values())
        ret += prob * math.log2(prob)
    return -ret
