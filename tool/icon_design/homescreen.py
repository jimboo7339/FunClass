"""把 5 款图标摆成桌面的样子，用来做最终目测。"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "..", "assets", "icons", "launcher")
OUT = os.path.join(HERE, "homescreen.png")

ORDER = ["classic", "puzzle", "smile", "book", "spark"]
W, H = 1080, 620
ICON = 132


def wallpaper():
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        top = (226, 233, 245)
        bot = (196, 206, 226)
        row = tuple(round(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = row
    return img.convert("RGBA")


def squircle(img, ratio=0.223):
    from PIL import ImageDraw as D

    r = int(img.width * ratio)
    mask = Image.new("L", img.size, 0)
    D.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius=r, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def font(size):
    for p in (
        r"C:\Windows\Fonts\msyh.ttc",
        r"C:\Windows\Fonts\msyhbd.ttc",
        r"C:\Windows\Fonts\segoeui.ttf",
    ):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


sheet = wallpaper()
draw = ImageDraw.Draw(sheet)
label_font = font(26)

gap = W // (len(ORDER) + 1)
for i, name in enumerate(ORDER):
    im = Image.open(os.path.join(ASSETS, f"{name}.png")).convert("RGBA")
    im = squircle(im.resize((ICON, ICON), Image.LANCZOS))
    cx = gap * (i + 1)
    x = cx - ICON // 2
    # 一点投影，模拟启动器给图标的落地阴影
    shadow = Image.new("RGBA", (ICON, ICON), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 70), (0, 0), im.split()[3])
    sheet.alpha_composite(shadow, (x + 3, 176))
    sheet.alpha_composite(im, (x, 168))
    text = "趣课"
    box = draw.textbbox((0, 0), text, font=label_font)
    draw.text(
        (cx - (box[2] - box[0]) / 2, 168 + ICON + 18),
        text,
        font=label_font,
        fill=(30, 34, 42, 255),
    )
    draw.text((cx - 26, 96), name, font=font(22), fill=(90, 98, 112, 255))

sheet.convert("RGB").save(OUT)
print("wrote", OUT)
