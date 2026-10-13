# -*- coding: utf-8 -*-
# 裁剪 app_icon.jpg 四周白色留白，让图标主体撑满整张图——来自Trae
from PIL import Image, ImageChops

SRC = "assets/icons/app_icon.jpg"
DST = "assets/icons/app_icon_filled.jpg"

img = Image.open(SRC).convert("RGB")
w, h = img.size

# 亮度阈值：认为接近白色的像素是"留白背景"（浅蓝底板的像素远低于这个值）
WHITE_THRESH = 240

# 逐行列找第一个 / 最后一个"非白"像素，确定裁剪边界
pix = img.load()
def near_white(px):
    return px[0] >= WHITE_THRESH and px[1] >= WHITE_THRESH and px[2] >= WHITE_THRESH

top = 0
while top < h and all(near_white(pix[x, top]) for x in range(w)):
    top += 1

bottom = h - 1
while bottom > top and all(near_white(pix[x, bottom]) for x in range(w)):
    bottom -= 1

left = 0
while left < w and all(near_white(pix[left, y]) for y in range(h)):
    left += 1

right = w - 1
while right > left and all(near_white(pix[right, y]) for y in range(h)):
    right -= 1

crop = img.crop((left, top, right + 1, bottom + 1))
cw, ch = crop.size
print(f"orig={w}x{h} crop=({left},{top},{right + 1},{bottom + 1}) -> {cw}x{ch}")

# 主体接近方形。为了让图标内容撑满整张图标，不留白边，四周不再加 pad——来自Trae
side = max(cw, ch)
canvas = side
out = Image.new("RGB", (canvas, canvas), "#FFFFFF")
out.paste(crop, ((canvas - cw) // 2, (canvas - ch) // 2))
out.save(DST)
print(f"saved {DST} {canvas}x{canvas}")