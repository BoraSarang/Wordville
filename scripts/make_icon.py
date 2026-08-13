#!/usr/bin/env python3
"""Wordville 앱 아이콘 생성 — 64x64 픽셀 아트 → 16배 NEAREST 확대 (레트로 픽셀)"""
import os
from PIL import Image, ImageDraw, ImageFont

S = 64
CREAM = (0xFF, 0xF6, 0xE9, 255)
BROWN = (0x5B, 0x46, 0x36, 255)
GREEN = (0xA8, 0xD6, 0x72, 255)
SKY = (0x8E, 0xC9, 0xF5, 255)
PEACH = (0xFF, 0xB4, 0x8A, 255)
WHITE = (0xFF, 0xFF, 0xFF, 255)

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# 배경 — 둥근 사각형 (크림) + 갈색 테두리
d.rounded_rectangle([1, 1, S - 2, S - 2], radius=13, fill=CREAM)
d.rounded_rectangle([1, 1, S - 2, S - 2], radius=13, outline=BROWN, width=3)

# 하단 땅 — 복숭아 잔디 스트립
d.rectangle([4, 50, 59, 58], fill=PEACH)
d.rectangle([4, 58, 59, 62], fill=(0xE8, 0x9B, 0x6E, 255))

# 책 — 초록 펼친 책 (중앙)
book_x0, book_x1, book_y0, book_y1 = 10, 53, 18, 48
d.rounded_rectangle([book_x0, book_y0, book_x1, book_y1], radius=5, fill=GREEN)
d.rounded_rectangle([book_x0, book_y0, book_x1, book_y1], radius=5, outline=BROWN, width=2)
# 책 중앙 접힘선
d.line([31, 20, 31, 46], fill=BROWN, width=1)
# 왼쪽 페이지 선
d.line([15, 22, 15, 44], fill=(0x8F, 0xB8, 0x5E, 255), width=1)
d.line([22, 22, 22, 44], fill=(0x8F, 0xB8, 0x5E, 255), width=1)
# 오른쪽 페이지 선
d.line([40, 22, 40, 44], fill=(0x8F, 0xB8, 0x5E, 255), width=1)
d.line([47, 22, 47, 44], fill=(0x8F, 0xB8, 0x5E, 255), width=1)

# 연필 — 하늘색, 책 위 대각선
d.line([14, 44, 28, 30], fill=BROWN, width=4)
d.line([14, 44, 28, 30], fill=SKY, width=2)
d.polygon([(12, 46), (16, 42), (18, 48)], fill=(0xE8, 0x9B, 0x6E, 255))  # 심

# "글" — 흰색 둥근모꼴
font_path = "macos/Resources/Fonts/NeoDunggeunmo.ttf"
font = ImageFont.truetype(font_path, 22)
text = "글"
bbox = d.textbbox((0, 0), text, font=font)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
tx = (S - tw) // 2 - bbox[0]
ty = (S - th) // 2 - bbox[1] - 1
d.text((tx, ty), text, font=font, fill=WHITE)

# NEAREST 스케일로 픽셀 아트 완성 (1024 베이스)
out_dir = "/tmp/wordville_icon"
os.makedirs(out_dir, exist_ok=True)
base = img.resize((1024, 1024), Image.NEAREST)
base.save(f"{out_dir}/base_1024.png")

# iconset 생성
iconset = f"{out_dir}/AppIcon.iconset"
os.makedirs(iconset, exist_ok=True)
sizes = {
    "icon_16x16.png": 16, "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32, "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128, "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256, "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512, "icon_512x512@2x.png": 1024,
}
for name, size in sizes.items():
    scaled = img.resize((size, size), Image.NEAREST)
    scaled.save(f"{iconset}/{name}")
    print(f"{name}: {size}x{size} OK")

print("DONE")