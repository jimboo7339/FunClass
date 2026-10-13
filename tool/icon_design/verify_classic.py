# 验证经典图标修复效果：合成"圆形遮罩下的自适应图标"与"squircle 下的 legacy"
# 输出到 build/icon_verify.png，肉眼看有没有白圈、拼图有没有被裁。——来自Trae
import os
from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
S = 432  # xxxhdpi


def circle_mask(size):
    m = Image.new('L', (size, size), 0)
    ImageDraw.Draw(m).ellipse([0, 0, size - 1, size - 1], fill=255)
    return m


def squircle_mask(size, r_ratio=0.223):
    m = Image.new('L', (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=int(size * r_ratio), fill=255)
    return m


def gradient_bg(size):
    # 复刻 XML 渐变 angle=315（左上→右下）近似：垂直线性即可验证
    top = (0xBB, 0xDD, 0xF8)
    bot = (0x97, 0xC2, 0xED)
    img = Image.new('RGB', (size, size))
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        ImageDraw.Draw(img).line([(0, y), (size, y)], fill=c)
    return img


def masked(img, mask):
    out = Image.new('RGBA', img.size)
    out.paste(img, (0, 0), mask)
    return out


legacy = Image.open(os.path.join(RES, 'mipmap-xxxhdpi', 'ic_launcher.png')).convert('RGB').resize((S, S), Image.LANCZOS)
fg = Image.open(os.path.join(RES, 'mipmap-xxxhdpi', 'ic_launcher_foreground.png')).convert('RGBA')

# 自适应合成：背景铺满 + 前景叠加
adaptive = gradient_bg(S).convert('RGBA')
adaptive.alpha_composite(fg)

cells = [
    ('adaptive + circle', masked(adaptive.convert('RGB'), circle_mask(S))),
    ('legacy + squircle', masked(legacy, squircle_mask(S))),
    ('legacy + circle', masked(legacy, circle_mask(S))),
]
pad, label_h = 24, 40
W = len(cells) * S + (len(cells) + 1) * pad
H = S + label_h + 2 * pad
canvas = Image.new('RGB', (W, H), (0x60, 0x8C, 0xD8))  # 模拟桌面蓝底
d = ImageDraw.Draw(canvas)
for i, (name, img) in enumerate(cells):
    x = pad + i * (S + pad)
    canvas.paste(img, (x, pad + label_h), img)
    d.text((x, pad + 10), name, fill=(255, 255, 255))
out = os.path.join(ROOT, 'build', 'icon_verify.png')
canvas.save(out)
print('wrote', out)
