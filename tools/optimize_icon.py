# -*- coding: utf-8 -*-
# 图标优化：仅把与四角连通的白色外框替换为竖向天空蓝渐变，
# 与圆角方块背景平滑融合，消除白角与硬缝——来自Trae
from PIL import Image, ImageDraw

SRC = "assets/icons/app_icon_filled.jpg"
DST = "assets/icons/app_icon_v3.jpg"

TOP = (172, 214, 247)   # 渐变顶部：浅天蓝
BOT = (140, 188, 236)   # 渐变底部：略深天蓝
MARK = (255, 0, 255)    # 临时标记色
THRESH = 40             # 仅接近白色的连通外框会被标记

img = Image.open(SRC).convert("RGB")
w, h = img.size

# 在纯“颜色标记”的副本上做 floodfill，避免污染原图——来自Trae
marked = img.copy()
for (cx, cy) in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
    ImageDraw.floodfill(marked, (cx, cy), MARK, thresh=THRESH)

# 逐像素：被标记的外框像素用渐变着色，其余保持原样——来自Trae
tgt = [[x, y] for y in range(h) for x in range(w)]
pix = img.load()
mpix = marked.load()
for y in range(h):
    t = y / (h - 1)
    gr = tuple(int(TOP[i] + (BOT[i] - TOP[i]) * t) for i in range(3))
    for x in range(w):
        if mpix[x, y] == MARK:
            pix[x, y] = gr

img.save(DST)
print("saved", DST, f"{w}x{h}")

# 采样验证四角与边缘不再是白，且内部白色图案（书本页）未被改动——来自Trae
pts = {'tl': (2, 2), 'tr': (w - 3, 2), 'bl': (2, h - 3), 'br': (w - 3, h - 3),
       'topmid': (w // 2, 2), 'bottommid': (w // 2, h - 3)}
for k, (x, y) in pts.items():
    print(k, img.getpixel((x, y)))