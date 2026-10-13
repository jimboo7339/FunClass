# -*- coding: utf-8 -*-
# 将图标四周与四角连接的白色区域填充为背景蓝，避免生成启动图标后四角发白——来自Trae
from PIL import Image, ImageDraw

SRC = "assets/icons/app_icon_filled.jpg"
DST = "assets/icons/app_icon_v2.jpg"

# 深一点的天蓝，与圆角方块的浅蓝底色相近但略深，覆盖白角更自然
FILL = (140, 196, 250)
THRESH = 42  # 只有连通的接近白色像素才会被填充，内部白色图案不会受影响

img = Image.open(SRC).convert("RGB")
w, h = img.size

corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
for (cx, cy) in corners:
    ImageDraw.floodfill(img, (cx, cy), FILL, thresh=THRESH)

img.save(DST)
print("saved", DST, f"{w}x{h}")

# 重新采样结果，确认四角与上下边变成蓝色而非白色
pts = {'tl': (2, 2), 'tr': (w - 3, 2), 'bl': (2, h - 3), 'br': (w - 3, h - 3),
       'topmid': (w // 2, 2), 'bottommid': (w // 2, h - 3),
       'leftmid': (2, h // 2), 'rightmid': (w - 3, h // 2)}
for k, (x, y) in pts.items():
    print(k, img.getpixel((x, y)))