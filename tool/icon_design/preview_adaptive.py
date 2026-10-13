"""把前景层叠到背景渐变上、按启动器遮罩裁切，验证自适应图标实际观感。

自适应图标画布 108dp；系统圆形遮罩直径 72dp（即画布的 2/3），
保证可见的安全区只有中间 66dp，所以前景必须缩到这一圈里。——来自Trae
"""
import json
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PNG = os.path.join(HERE, "png")
OUT = os.path.join(HERE, "contact_adaptive.png")

variants = json.load(open(os.path.join(HERE, "icons.json"), encoding="utf-8"))


def hex2(s):
    s = s.lstrip("#")
    return tuple(int(s[i : i + 2], 16) for i in (0, 2, 4))


def gradient(stops, size=1024):
    """左上→右下线性渐变。

    线性渐变在放大时不会失真，所以先在小尺寸上逐像素插值、再放大，
    比直接在 1024×1024 上跑 Python 双重循环快两个数量级。——来自Trae
    """
    small = 64
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


def circle_mask(size, diameter_ratio):
    m = Image.new("L", (size, size), 0)
    d = int(size * diameter_ratio)
    ImageDraw.Draw(m).ellipse(((size - d) // 2, (size - d) // 2, (size + d) // 2, (size + d) // 2), fill=255)
    return m


def squircle_mask(size, ratio=0.0):
    r = int(size * 0.223)
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=255)
    return m


CACHE = {}


def bg_for(idx):
    if idx not in CACHE:
        CACHE[idx] = gradient(variants[idx]["fullBleedStops"], 1024)
    return CACHE[idx]


CELL = 150
rows = len(variants)
cols = 4  # 传统合成 / 圆形遮罩 / 圆角遮罩 / 48px 小尺寸
pad = 18
sheet = Image.new("RGBA", (cols * (CELL + pad) + pad, rows * (CELL + pad) + pad), (238, 240, 245, 255))

for r, v in enumerate(variants):
    fg = Image.open(os.path.join(PNG, f"fg_{v['id']}.png")).convert("RGBA")
    legacy = Image.open(os.path.join(PNG, f"v_{v['id']}.png")).convert("RGBA")
    adaptive = Image.alpha_composite(bg_for(r), fg)

    cells = [
        legacy,
        Image.composite(adaptive, Image.new("RGBA", adaptive.size, (0, 0, 0, 0)), circle_mask(1024, 2 / 3)),
        Image.composite(adaptive, Image.new("RGBA", adaptive.size, (0, 0, 0, 0)), squircle_mask(1024)),
        Image.composite(adaptive, Image.new("RGBA", adaptive.size, (0, 0, 0, 0)), circle_mask(1024, 2 / 3)).resize(
            (48, 48), Image.LANCZOS
        ),
    ]
    for c, im in enumerate(cells):
        target = 48 if c == 3 else CELL
        im = im.resize((target, target), Image.LANCZOS) if im.size != (target, target) else im
        if c == 3:  # 小尺寸放到格子里居中，方便看真实桌面大小
            holder = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            holder.alpha_composite(im, ((CELL - 48) // 2, (CELL - 48) // 2))
            im = holder
        sheet.alpha_composite(im, (pad + c * (CELL + pad), pad + r * (CELL + pad)))

sheet.save(OUT)
print("wrote", OUT)
