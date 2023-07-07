import numpy as np
from matplotlib import pyplot as plt
from matplotlib.colors import hsv_to_rgb
from struct import unpack


def plot_color_buffer(buf, path):
    
    bsize = len(buf)
    roll_index = unpack(">H", buf[bsize-2:])[0]
    print(roll_index/4)
    # roll_index = 0

    buf2 = np.roll(buf[:1000],-roll_index)

    size = (bsize-2)//4
    print(size)
    hue = np.zeros((size,))
    sat = np.zeros((size,))
    val = np.zeros((size,))
    for i in range(size):
        hue[i], sat[i], val[i] = unpack(">HBB", buf2[4*i:4*i+4])
    
    hsv = np.zeros((size, 3))
    hsv[:, 0] = hue/360
    hsv[:, 1] = sat/100
    hsv[:, 2] = val/100
    
    rgb = hsv_to_rgb(hsv)

    fig, (ax1, ax2, ax3) = plt.subplots(3, sharex=True, figsize=(6,6))
    plt.subplots_adjust(hspace=0)
    ax1.plot(((hue-50)%360)+50, label="hue")
    ax1.scatter(list(range(size)), 0*np.ones((size,)), c=rgb, s=30)
    ax1.legend()
    ax2.plot(sat, label="sat")
    ax2.plot(val, label="val")
    ax2.legend()
    ax3.plot(sat*val, label="chroma")
    ax3.axhline(3500, color="0.5", label="3500")
    ax3.legend()
    plt.savefig(path, facecolor="white")