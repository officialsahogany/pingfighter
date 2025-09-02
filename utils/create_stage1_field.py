from PIL import Image, ImageDraw, ImageFilter
import random
import math

width, height = 600, 750

img = Image.new('RGB', (width, height), color=(245, 235, 220))
draw = ImageDraw.Draw(img)

gradient = Image.new('RGB', (width, height))
gradient_draw = ImageDraw.Draw(gradient)
for y in range(height):
    intensity = int(20 + (y / height) * 30)
    gradient_draw.rectangle([0, y, width, y+1], fill=(intensity, intensity, intensity+10))
img.paste(gradient, (0, 0))

# 격자무늬 제거 - 깔끔한 바닥 유지

# 단청무늬 테두리 - 전통 한국 단청 스타일
beam_width = 30
dancheong_colors = [
    (220, 40, 40),    # 주홍
    (40, 180, 100),   # 청록
    (255, 200, 0),    # 황금
    (255, 255, 255),  # 백색
    (40, 40, 150),    # 군청
]

# 상단 테두리 - 가로 줄무늬 단청
for y in range(6):
    stripe_height = 5
    y_pos = y * stripe_height
    color = dancheong_colors[y % len(dancheong_colors)]
    draw.rectangle([0, y_pos, width, y_pos + stripe_height], fill=color)

# 상단 장식 패턴
for x in range(30, width - 30, 60):
    # 연꽃 무늬
    draw.ellipse([x - 12, 8, x + 12, 22], fill=(220, 40, 40))
    draw.ellipse([x - 8, 10, x + 8, 20], fill=(255, 200, 0))
    draw.ellipse([x - 4, 12, x + 4, 18], fill=(40, 180, 100))

# 하단 테두리 - 가로 줄무늬 단청  
for y in range(6):
    stripe_height = 5
    y_pos = height - 30 + y * stripe_height
    color = dancheong_colors[y % len(dancheong_colors)]
    draw.rectangle([0, y_pos, width, y_pos + stripe_height], fill=color)

# 하단 장식 패턴
for x in range(30, width - 30, 60):
    # 연꽃 무늬
    draw.ellipse([x - 12, height - 22, x + 12, height - 8], fill=(220, 40, 40))
    draw.ellipse([x - 8, height - 20, x + 8, height - 10], fill=(255, 200, 0))
    draw.ellipse([x - 4, height - 18, x + 4, height - 12], fill=(40, 180, 100))

# 왼쪽 테두리 - 세로 줄무늬 단청
for x in range(6):
    stripe_width = 5
    x_pos = x * stripe_width
    color = dancheong_colors[x % len(dancheong_colors)]
    draw.rectangle([x_pos, 30, x_pos + stripe_width, height - 30], fill=color)

# 왼쪽 장식 패턴
for y in range(60, height - 60, 60):
    # 연꽃 무늬
    draw.ellipse([8, y - 12, 22, y + 12], fill=(220, 40, 40))
    draw.ellipse([10, y - 8, 20, y + 8], fill=(255, 200, 0))
    draw.ellipse([12, y - 4, 18, y + 4], fill=(40, 180, 100))

# 오른쪽 테두리 - 세로 줄무늬 단청
for x in range(6):
    stripe_width = 5
    x_pos = width - 30 + x * stripe_width
    color = dancheong_colors[x % len(dancheong_colors)]
    draw.rectangle([x_pos, 30, x_pos + stripe_width, height - 30], fill=color)

# 오른쪽 장식 패턴
for y in range(60, height - 60, 60):
    # 연꽃 무늬
    draw.ellipse([width - 22, y - 12, width - 8, y + 12], fill=(220, 40, 40))
    draw.ellipse([width - 20, y - 8, width - 10, y + 8], fill=(255, 200, 0))
    draw.ellipse([width - 18, y - 4, width - 12, y + 4], fill=(40, 180, 100))

# 바둑판 선 제거 - 깔끔한 배경 유지

center_x, center_y = width//2, height//2
taegeuk_radius = 80  # 더 크게

# 태극 배경 원 (밝은 배경)
draw.ellipse([center_x-taegeuk_radius-5, center_y-taegeuk_radius-5, 
              center_x+taegeuk_radius+5, center_y+taegeuk_radius+5], 
             fill=(200, 200, 200))

draw.ellipse([center_x-taegeuk_radius, center_y-taegeuk_radius, 
              center_x+taegeuk_radius, center_y+taegeuk_radius], 
             outline=(50, 50, 150), width=5)  # 더 두꺼운 테두리

red_color = (25, 25, 200)  # 밝은 군청색
blue_color = (15, 15, 100)  # 진한 군청색

draw.pieslice([center_x-taegeuk_radius+3, center_y-taegeuk_radius+3,
               center_x+taegeuk_radius-3, center_y+taegeuk_radius-3],
              90, 270, fill=red_color)

draw.ellipse([center_x-taegeuk_radius//2, center_y-taegeuk_radius+3,
              center_x+taegeuk_radius//2, center_y-3],
             fill=blue_color)
draw.ellipse([center_x-taegeuk_radius//2, center_y+3,
              center_x+taegeuk_radius//2, center_y+taegeuk_radius-3],
             fill=red_color)

draw.ellipse([center_x-15, center_y-taegeuk_radius//2-15,
              center_x+15, center_y-taegeuk_radius//2+15],
             fill=red_color)
draw.ellipse([center_x-15, center_y+taegeuk_radius//2-15,
              center_x+15, center_y+taegeuk_radius//2+15],
             fill=blue_color)

# 단청 장식 제거 - 깔끔한 배경 유지

for i in range(3):
    glow_radius = 65 + i * 5
    glow = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_opacity = 30 - i * 10
    glow_draw.ellipse([center_x-glow_radius, center_y-glow_radius,
                      center_x+glow_radius, center_y+glow_radius],
                     fill=(0, 255, 200, glow_opacity))
    img = Image.alpha_composite(img.convert('RGBA'), glow).convert('RGB')

img = img.filter(ImageFilter.SMOOTH_MORE)

img.save('stage1_field.png')
print("Stage 1 field (static) created successfully!")