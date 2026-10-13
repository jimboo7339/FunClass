"""按 icons.json 的 stop 列表生成线性渐变位图。

线性渐变放大后不会失真，所以先在小尺寸上逐像素插值、再双线性放大，
比直接在 1024×1024 上跑 Python 双重循环快两个数量级。——来自Trae
"""
from PIL import Image


def hex2(s):
    s = s.lstrip("#")
    return tuple(int(s[i : i + 2], 16) for i in (0, 2, 4))


def gradient(stops, size=1024, small=64):
    """左上→右下方向的线性渐变，返回 RGBA"""
    img = Image.new("RGB", (small, small))
    px = img.load()
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * (small - 1))
            for a, b in zip(stops, stops[1:]):
                if a[0] <= t <= b[0]:
                    k = 0 if b[0] == a[0] else (t - a[0]) / (b[0] - a[0])
                    c0, c1 = hex2(a[1]), hex2(b[1])
                    px[x, y] = tuple(round(c0[i] + (c1[i] - c0[i]) * k) for i in range(3))
                    break
            else:
                px[x, y] = hex2(stops[-1][1])
    return img.resize((size, size), Image.BILINEAR).convert("RGBA")
