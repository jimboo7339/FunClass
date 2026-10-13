"""把渲染好的图标导出成 Android 启动器资源 + 设置页用的预览图。

产出（android/app/src/main/res 下）：
  mipmap-*/ic_launcher_<id>.png          传统图标（Android 8 以下的启动器）
  mipmap-*/ic_launcher_<id>_foreground.png  自适应图标前景层
  mipmap-anydpi-v26/ic_launcher_<id>.xml    自适应图标定义
  drawable/ic_launcher_<id>_background.xml  背景层渐变（矢量，不占像素）
以及 assets/icons/launcher/<id>.png：设置页「更换图标」卡片里的预览图。

图标 id 列表和背景渐变来自 gen.mjs 写出的 icons.json，
只在这里维护一份，避免两边数字对不上。——来自Trae
"""
import json
import os

from PIL import Image, ImageDraw

from bggrad import gradient

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.abspath(os.path.join(HERE, "..", ".."))
PNG = os.path.join(HERE, "png")
RES = os.path.join(PROJ, "android", "app", "src", "main", "res")
ASSETS = os.path.join(PROJ, "assets", "icons", "launcher")

variants = json.load(open(os.path.join(HERE, "icons.json"), encoding="utf-8"))

# dpi 限定符 → 传统图标边长 / 自适应图层边长（108dp 基准）
DENSITIES = [
    ("mdpi", 48, 108),
    ("hdpi", 72, 162),
    ("xhdpi", 96, 216),
    ("xxhdpi", 144, 324),
    ("xxxhdpi", 192, 432),
]

PREVIEW = 192


def hex2argb(s):
    s = s.lstrip("#")
    return "#FF" + s.upper()


def gradient_xml(stops):
    """shape 渐变。angle=315 的方向是左上→右下，和 SVG 里的 x1/y1→x2/y2 对齐；
    Android 只支持 start/center/end 三档，中间档固定在 50% 处，
    和 SVG 的 0.55 差一点点，肉眼看不出来。——来自Trae"""
    c = [s[1] for s in stops]
    if len(c) == 2:
        c.append(c[1])
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!-- 由 tool/icon_design/export_android.py 生成，改图标请改 gen.mjs 后重跑 -->\n"
        "<shape xmlns:android=\"http://schemas.android.com/apk/res/android\"\n"
        "    android:shape=\"rectangle\">\n"
        "    <gradient\n"
        f"        android:angle=\"315\"\n"
        f"        android:startColor=\"{hex2argb(c[0])}\"\n"
        f"        android:centerColor=\"{hex2argb(c[1])}\"\n"
        f"        android:endColor=\"{hex2argb(c[2])}\"\n"
        "        android:type=\"linear\" />\n"
        "</shape>\n"
    )


def adaptive_xml(v):
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!-- 由 tool/icon_design/export_android.py 生成，改图标请改 gen.mjs 后重跑 -->\n"
        "<adaptive-icon xmlns:android=\"http://schemas.android.com/apk/res/android\">\n"
        f"    <background android:drawable=\"@drawable/ic_launcher_{v['id']}_background\" />\n"
        f"    <foreground android:drawable=\"@mipmap/ic_launcher_{v['id']}_foreground\" />\n"
        "</adaptive-icon>\n"
    )


def write_text(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def squircle(img, radius_ratio=0.223):
    r = int(img.width * radius_ratio)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, img.width - 1, img.height - 1], radius=r, fill=255
    )
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG", optimize=True)


for v in variants:
    vid = v["id"]
    legacy_src = Image.open(os.path.join(PNG, f"v_{vid}.png")).convert("RGBA")
    fg_src = Image.open(os.path.join(PNG, f"fg_{vid}.png")).convert("RGBA")

    for dpi, legacy_px, layer_px in DENSITIES:
        save(
            legacy_src.resize((legacy_px, legacy_px), Image.LANCZOS),
            os.path.join(RES, f"mipmap-{dpi}", f"ic_launcher_{vid}.png"),
        )
        save(
            fg_src.resize((layer_px, layer_px), Image.LANCZOS),
            os.path.join(RES, f"mipmap-{dpi}", f"ic_launcher_{vid}_foreground.png"),
        )

    write_text(
        os.path.join(RES, "mipmap-anydpi-v26", f"ic_launcher_{vid}.xml"),
        adaptive_xml(v),
    )
    write_text(
        os.path.join(RES, "drawable", f"ic_launcher_{vid}_background.xml"),
        gradient_xml(v["fullBleedStops"]),
    )

    # 设置页预览：按现代启动器的样子给（自适应图层 + 圆角遮罩），
    # 用户在手机上看到什么，选择框里就是什么
    adaptive = Image.alpha_composite(gradient(v["fullBleedStops"], 1024), fg_src)
    save(
        squircle(adaptive.resize((PREVIEW, PREVIEW), Image.LANCZOS)),
        os.path.join(ASSETS, f"{vid}.png"),
    )


# 经典图标：直接把现有 xxxhdpi 的那张当预览，不重新画
classic = os.path.join(RES, "mipmap-xxxhdpi", "ic_launcher.png")
if os.path.exists(classic):
    legacy_classic = Image.open(classic).convert("RGBA").resize(
        (PREVIEW, PREVIEW), Image.LANCZOS
    )
    save(
        squircle(legacy_classic),
        os.path.join(ASSETS, "classic.png"),
    )

print("done")
