import numpy as np
from matplotlib import pyplot as plt
from matplotlib.colors import hsv_to_rgb
from struct import unpack


def plot_color_buffer(buf, path):
    
    COLOR_HUES = (51, 219, 133, 359)
    
    bsize = len(buf)
    (chroma_threshold, roll_index) = unpack(">HH", buf[bsize-4:])
    print(roll_index/4)
    # roll_index = 0

    buf2 = np.roll(buf[:1000],-roll_index)

    size = (bsize-2)//4
    hue = []
    sat = []
    val = []
    detections = []
    ii = 0
    for i in range(size):
        h, s, v = unpack(">HBB", buf2[4*i:4*i+4])
        if h == 361:
            if s == 0:
                colh = COLOR_HUES[v]
                detections.append((ii, colh, 0))
            if s == 1:
                colh1 = COLOR_HUES[v >> 4]
                colh2 = COLOR_HUES[v & 0x0F]
                detections.append((ii, colh1, 1))
                detections.append((ii, colh2, 2))
            continue
        ii += 1
        hue.append(h)
        sat.append(s)
        val.append(v)
    
    size = len(hue)
    hsv = np.zeros((size, 3))
    hsv[:, 0] = np.array(hue)/360
    hsv[:, 1] = np.array(sat)/100
    hsv[:, 2] = np.array(val)/100
    
    rgb = hsv_to_rgb(hsv)

    fig, (ax1, ax2, ax3) = plt.subplots(3, sharex=True, figsize=(6,6))
    plt.subplots_adjust(hspace=0)
    ax1.plot(((hsv[:,0]*360-50)%360)+50, label="hue")
    ax1.scatter(list(range(size)), 0*np.ones((size,)), c=rgb, s=30)
    ax1.legend()
    ax2.plot(hsv[:,1]*100, label="sat")
    ax2.plot(hsv[:,2]*100, label="val")
    ax2.legend()
    ax3.plot(hsv[:,2]*hsv[:,1]*10000, label="chroma")
    ax3.axhline(chroma_threshold, color="0.5", label="threshold")
    
    for i, colh, err in detections:
        ls = "-"
        if err == 1:
            ls="-"
        if err == 2:
            ls=":"
        ax3.axvline(i, c=hsv_to_rgb([(colh/360.0)%1.0, 1.0, 1.0]), ls=ls)
    ax3.legend()
    plt.savefig(path, facecolor="white")