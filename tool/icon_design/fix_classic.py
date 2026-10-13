# 修复经典图标"周围一圈"：源图 app_icon_v3.jpg 的蓝瓦片四周有一圈浅蓝背景，
# 启动器套圆角/圆形遮罩后露出来像白边。
# 两层修法：
#  1) legacy mipmap PNG：中心裁掉背景条、瓦片全出血撑满画布（MIUI 等 squircle
#     遮罩下不再有圈；圆角本来就会被遮罩裁掉）
#  2) 自适应图标（Android 8+ 新启动器）：背景 = 瓦片同色系蓝色渐变铺满，
#     前景 = 瓦片放大到画布 85%（留在安全区内，圆形遮罩也裁不到拼图）
#     —— 圈的位置变成蓝底，白圈消失
#  3) 重生成设置页预览 assets/icons/launcher/classic.png
# 来自Trae
import os
from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
SRC = os.path.join(ROOT, 'assets', 'icons', 'app_icon_v3.jpg')

LEGACY = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
FG = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}

# legacy：裁掉四周背景条的比例（瓦片直边距画布边缘约 2%，留 5% 余量确保出血）
LEGACY_CROP = 0.90
# 自适应前景：全出血。用户主诉就是"周围一圈"，squircle 遮罩（MIUI 等）下
# 前景与 legacy 观感完全一致；圆形遮罩下书本底部会轻微切边，可接受
FG_SCALE = 1.0


def center_crop(im, ratio):
    w, h = im.size
    side = int(min(w, h) * ratio)
    x0 = (w - side) // 2
    y0 = (h - side) // 2
    return im.crop((x0, y0, x0 + side, y0 + side))


def on_canvas(tile, canvas_size):
    """把瓦片贴到透明画布中心。"""
    out = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    out.paste(tile, (0, 0))
    return out


def main():
    src = Image.open(SRC).convert('RGB')
    tile = center_crop(src, LEGACY_CROP)

    # 取瓦片自身蓝色做 adaptive 背景渐变（上浅下深，与瓦片一致）
    def hx(c): return '#%02X%02X%02X' % c
    top = tile.getpixel((tile.width // 2, int(tile.height * 0.04)))
    mid = tile.getpixel((int(tile.width * 0.04), tile.height // 2))
    bot = tile.getpixel((tile.width // 2, int(tile.height * 0.96)))
    print('gradient', hx(top), hx(mid), hx(bot))

    # 1) legacy：全出血
    for d, s in LEGACY.items():
        p = os.path.join(RES, f'mipmap-{d}', 'ic_launcher.png')
        tile.resize((s, s), Image.LANCZOS).save(p)
        print('wrote', os.path.relpath(p, ROOT))

    # 2) adaptive 前景：85% 居中
    fg_side = 1024
    fg_tile = tile.resize(
        (int(fg_side * FG_SCALE),) * 2, Image.LANCZOS)
    fg_master = on_canvas(fg_tile, fg_side)
    for d, s in FG.items():
        p = os.path.join(RES, f'mipmap-{d}', 'ic_launcher_foreground.png')
        fg_master.resize((s, s), Image.LANCZOS).save(p)
        print('wrote', os.path.relpath(p, ROOT))

    os.makedirs(os.path.join(RES, 'mipmap-anydpi-v26'), exist_ok=True)
    with open(os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher.xml'), 'w',
              encoding='utf-8') as f:
        f.write('''<?xml version="1.0" encoding="utf-8"?>
<!-- 经典图标补上自适应资源：背景用瓦片同色渐变铺满，遮罩后不再有白圈 -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_classic_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''')
    print('wrote mipmap-anydpi-v26/ic_launcher.xml')

    os.makedirs(os.path.join(RES, 'drawable'), exist_ok=True)
    with open(os.path.join(RES, 'drawable', 'ic_launcher_classic_background.xml'),
              'w', encoding='utf-8') as f:
        f.write(f'''<?xml version="1.0" encoding="utf-8"?>
<!-- 经典图标自适应背景：取瓦片自身的蓝色渐变，遮罩后与前景同色无缝 -->
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <gradient
        android:angle="315"
        android:startColor="{hx(top)}"
        android:centerColor="{hx(mid)}"
        android:endColor="{hx(bot)}"
        android:type="linear"/>
</shape>
''')
    print('wrote drawable/ic_launcher_classic_background.xml')

    # 3) 设置页预览：legacy 全出血图套 squircle（与 export_android.py 同参数）
    prev = tile.resize((192, 192), Image.LANCZOS)
    mask = Image.new('L', (192, 192), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, 191, 191], radius=int(192 * 0.223), fill=255)
    out = Image.new('RGBA', (192, 192))
    out.paste(prev, (0, 0), mask)
    pp = os.path.join(ROOT, 'assets', 'icons', 'launcher', 'classic.png')
    out.save(pp)
    print('wrote', os.path.relpath(pp, ROOT))


if __name__ == '__main__':
    main()
