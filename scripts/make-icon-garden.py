#!/usr/bin/env python3
"""ころころ菜園のアイコン（1024x1024、透過なし）。春の空・木の育て箱の断面・ころんとした作物 3 つ。
使い方: python3 scripts/make-icon-garden.py"""
import os
from PIL import Image, ImageDraw, ImageFilter

S = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "App", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def hx(v):
    return tuple(int(v[i:i + 2], 16) for i in (0, 2, 4))


img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
top, low = hx("86CDF0"), hx("EAF6DA")
for y in range(S):
    d.line([(0, y), (S, y)], fill=lerp(top, low, min(1, y / (S * 0.7))))
# 太陽
d.ellipse([720, 70, 940, 290], fill=hx("FFF3B8"))
# 丘
d.ellipse([-300, 560, 700, 1100], fill=hx("C8E3A0"))
d.ellipse([350, 600, 1400, 1150], fill=hx("99C866"))


def clay(cx, cy, rx, ry, body, shade, layer):
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
    base = Image.new("RGB", (S, S), hx(body))
    g = Image.new("RGB", (S, S))
    gd = ImageDraw.Draw(g)
    for y in range(int(cy - ry), int(cy + ry) + 1):
        t = max(0, (y - (cy - ry * 0.2)) / (ry * 1.2))
        gd.line([(cx - rx, y), (cx + rx, y)], fill=lerp(hx(body), hx(shade), min(1, t)))
    layer.paste(g, (0, 0), m)
    hl = Image.new("L", (S, S), 0)
    ImageDraw.Draw(hl).ellipse([cx - rx * 0.62, cy - ry * 0.72, cx - rx * 0.05, cy - ry * 0.25], fill=120)
    hl = hl.filter(ImageFilter.GaussianBlur(rx * 0.12))
    layer.paste(Image.new("RGB", (S, S), (255, 255, 255)), (0, 0), hl)


# 育て箱（板と土）
d.rounded_rectangle([60, 840, 964, 1060], radius=30, fill=hx("6E4A31"))
for (x, y, r) in [(180, 900, 12), (420, 950, 9), (700, 910, 14), (860, 980, 10), (300, 1000, 8)]:
    d.ellipse([x - r * 1.4, y - r, x + r * 1.4, y + r], fill=hx("A59684"))
for x in (40, 924):
    d.rounded_rectangle([x, 380, x + 60, 1060], radius=18, fill=hx("C48B52"))
    d.ellipse([x + 20, 520, x + 40, 540], fill=hx("6E6A66"))
    d.ellipse([x + 20, 760, x + 40, 780], fill=hx("6E6A66"))

# 作物：キャベツ（大）・にんじん（横）・いちご
layer = img.copy()
clay(390, 690, 220, 200, "A9D67C", "77AE52", layer)
clay(390, 700, 140, 125, "C8E6A2", "8FC064", layer)
clay(745, 735, 125, 112, "EF4A52", "B82D3B", layer)
clay(700, 470, 95, 88, "F39133", "C96A1C", layer)
img = layer
d = ImageDraw.Draw(img)
# いちごの粒とへた
for (x, y) in [(705, 720), (760, 700), (800, 740), (730, 775), (775, 795), (690, 765)]:
    d.ellipse([x - 7, y - 10, x + 7, y + 10], fill=hx("FCE6A0"))
d.polygon([(745, 610), (700, 640), (735, 640), (745, 670), (760, 640), (795, 640)], fill=hx("5FA843"))
# にんじんの葉
d.polygon([(690, 385), (660, 300), (705, 380)], fill=hx("5DAA45"))
d.polygon([(705, 382), (720, 285), (725, 385)], fill=hx("5DAA45"))
# キャベツの葉すじ
d.arc([260, 560, 520, 820], 200, 320, fill=hx("77AE52"), width=10)
# 落ちてくる種（点線）
for y in range(140, 330, 40):
    d.ellipse([388, y, 400, y + 14], fill=(255, 255, 255))
d.ellipse([360, 60, 430, 140], fill=hx("C69863"))
img.save(OUT, "PNG")
print("saved", OUT, img.size, img.mode)
