from PIL import Image, ImageDraw, ImageFilter
import random
import math

width, height = 600, 750

img = Image.new('RGB', (width, height))
draw = ImageDraw.Draw(img)

# 배경 - 어두운 사이버펑크 그라데이션 (보라빛)
for y in range(height):
    intensity = int(10 + (y / height) * 20)
    gradient_color = (intensity, intensity - 5, intensity + 10)  # 약간 보라빛
    draw.rectangle([0, y, width, y+1], fill=gradient_color)

# 중앙은 완전히 비워둠 - 미니멀 디자인
center_x, center_y = width//2, height//2

# 상단 수도원 지붕 실루엣 (미니멀)
# 중앙 지붕
roof_points = [
    (center_x - 100, 60),
    (center_x - 120, 80),
    (center_x, 30),
    (center_x + 120, 80),
    (center_x + 100, 60)
]
draw.polygon(roof_points, fill=(40, 30, 50))

# 좌측 작은 지붕
left_roof = [
    (80, 80),
    (60, 100),
    (120, 100),
    (140, 80)
]
draw.polygon(left_roof, fill=(35, 25, 45))

# 우측 작은 지붕
right_roof = [
    (width - 140, 80),
    (width - 120, 100),
    (width - 60, 100),
    (width - 80, 80)
]
draw.polygon(right_roof, fill=(35, 25, 45))

# 기둥 (심플하게 선으로만)
# 좌측 기둥들
for x in [40, 80, 120]:
    draw.rectangle([x - 2, 100, x + 2, 150], fill=(50, 40, 60))

# 우측 기둥들
for x in [width - 120, width - 80, width - 40]:
    draw.rectangle([x - 2, 100, x + 2, 150], fill=(50, 40, 60))

# 중앙 명상 원 (아주 희미하게)
meditation_radius = 60
# 원 테두리만 희미하게
for i in range(3):
    alpha = 30 - i * 10
    draw.ellipse([center_x - meditation_radius - i, center_y - meditation_radius - i,
                  center_x + meditation_radius + i, center_y + meditation_radius + i],
                 outline=(100, 80, 120, alpha), width=1)

# 사이버펑크 디지털 패턴 (테두리에만 최소한으로)
# 좌측 디지털 라인
for y in range(200, height - 200, 80):
    opacity = 40
    draw.line([10, y, 30, y], fill=(150, 100, 200, opacity), width=1)
    if random.random() > 0.5:
        draw.point((35, y), fill=(200, 150, 255, opacity))

# 우측 디지털 라인
for y in range(200, height - 200, 80):
    opacity = 40
    draw.line([width - 30, y, width - 10, y], fill=(150, 100, 200, opacity), width=1)
    if random.random() > 0.5:
        draw.point((width - 35, y), fill=(200, 150, 255, opacity))

# 하단 돌바닥 패턴 (미니멀)
stone_y = height - 100
# 돌 타일 (간단한 사각형)
for x in range(0, width, 60):
    draw.rectangle([x, stone_y, x + 55, stone_y + 20], 
                   fill=(45, 45, 50))
    draw.rectangle([x, stone_y + 25, x + 55, stone_y + 45], 
                   fill=(40, 40, 45))
    draw.rectangle([x, stone_y + 50, x + 55, stone_y + 70], 
                   fill=(35, 35, 40))
    draw.rectangle([x, stone_y + 75, x + 55, stone_y + 95], 
                   fill=(30, 30, 35))

# 상단 돌바닥 패턴 (미니멀)
for x in range(0, width, 60):
    draw.rectangle([x, 0, x + 55, 20], 
                   fill=(45, 45, 50))

# 홀로그램 연꽃 (아주 희미하게 테두리에만)
# 좌측 연꽃
lotus_x, lotus_y = 100, center_y
for petal in range(8):
    angle = petal * 45
    rad = math.radians(angle)
    px = lotus_x + math.cos(rad) * 20
    py = lotus_y + math.sin(rad) * 20
    draw.ellipse([px - 8, py - 4, px + 8, py + 4],
                 outline=(180, 150, 255, 30), width=1)

# 우측 연꽃
lotus_x, lotus_y = width - 100, center_y
for petal in range(8):
    angle = petal * 45
    rad = math.radians(angle)
    px = lotus_x + math.cos(rad) * 20
    py = lotus_y + math.sin(rad) * 20
    draw.ellipse([px - 8, py - 4, px + 8, py + 4],
                 outline=(180, 150, 255, 30), width=1)

# 디지털 먼지 입자 (극소량)
for _ in range(30):
    x = random.randint(50, width - 50)
    y = random.randint(100, height - 100)
    # 중앙 영역은 피함
    if abs(x - center_x) > 150 or abs(y - center_y) > 150:
        size = random.randint(1, 2)
        alpha = random.randint(20, 40)
        draw.ellipse([x, y, x + size, y + size],
                     fill=(200, 180, 255, alpha))

# 부드럽게 처리
img = img.filter(ImageFilter.SMOOTH)

img.save('stage4_field.png')
print("Stage 4 monk temple cyberpunk field created successfully!")