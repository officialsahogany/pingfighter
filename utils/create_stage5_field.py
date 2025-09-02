from PIL import Image, ImageDraw, ImageFilter
import random
import math

width, height = 600, 750

img = Image.new('RGB', (width, height))
draw = ImageDraw.Draw(img)

# 배경 - 어두운 사이버펑크 그라데이션 (붉은빛)
for y in range(height):
    intensity = int(15 + (y / height) * 25)
    gradient_color = (intensity + 10, intensity - 5, intensity - 10)  # 붉은빛
    draw.rectangle([0, y, width, y+1], fill=gradient_color)

# 중앙은 최대한 미니멀하게
center_x, center_y = width//2, height//2

# 왼쪽 상단 매화나무
tree_base_x, tree_base_y = 80, 150

# 나무 줄기 (간단하게)
trunk_points = [
    (tree_base_x - 15, tree_base_y),
    (tree_base_x - 20, tree_base_y - 80),
    (tree_base_x - 10, tree_base_y - 120),
    (tree_base_x + 5, tree_base_y - 100),
    (tree_base_x + 10, tree_base_y - 60),
    (tree_base_x + 15, tree_base_y)
]
draw.polygon(trunk_points, fill=(40, 30, 25))

# 매화 가지들
branches = [
    [(tree_base_x - 10, tree_base_y - 80), (tree_base_x - 50, tree_base_y - 100)],
    [(tree_base_x - 5, tree_base_y - 100), (tree_base_x - 40, tree_base_y - 130)],
    [(tree_base_x, tree_base_y - 90), (tree_base_x + 30, tree_base_y - 110)],
    [(tree_base_x + 5, tree_base_y - 70), (tree_base_x + 40, tree_base_y - 85)]
]

for branch in branches:
    draw.line(branch, fill=(35, 25, 20), width=3)

# 매화꽃 (핑크빛)
plum_blossoms = [
    (tree_base_x - 45, tree_base_y - 95),
    (tree_base_x - 35, tree_base_y - 125),
    (tree_base_x - 20, tree_base_y - 110),
    (tree_base_x + 25, tree_base_y - 105),
    (tree_base_x + 35, tree_base_y - 80),
    (tree_base_x - 50, tree_base_y - 105),
    (tree_base_x + 15, tree_base_y - 95)
]

for blossom_pos in plum_blossoms:
    # 5개 꽃잎
    for petal in range(5):
        angle = petal * 72
        rad = math.radians(angle)
        px = blossom_pos[0] + math.cos(rad) * 8
        py = blossom_pos[1] + math.sin(rad) * 8
        draw.ellipse([px - 5, py - 3, px + 5, py + 3],
                     fill=(255, 180, 200))
    # 꽃 중심
    draw.ellipse([blossom_pos[0] - 3, blossom_pos[1] - 3,
                  blossom_pos[0] + 3, blossom_pos[1] + 3],
                 fill=(255, 100, 120))

# 중국 전통 문양 - 팔괘 (아주 희미하게 중앙)
bagua_radius = 50
bagua_alpha = 20

# 팔괘 외곽 원 (희미하게)
draw.ellipse([center_x - bagua_radius, center_y - bagua_radius,
              center_x + bagua_radius, center_y + bagua_radius],
             outline=(255, 100, 50, bagua_alpha), width=1)

# 팔괘 선들 (8방향)
for i in range(8):
    angle = i * 45
    rad = math.radians(angle)
    x1 = center_x + math.cos(rad) * (bagua_radius - 10)
    y1 = center_y + math.sin(rad) * (bagua_radius - 10)
    x2 = center_x + math.cos(rad) * bagua_radius
    y2 = center_y + math.sin(rad) * bagua_radius
    draw.line([x1, y1, x2, y2], fill=(255, 120, 60, bagua_alpha), width=1)

# 화염 패턴 (테두리에 최소한으로)
# 좌측 화염
for y in range(200, height - 200, 100):
    flame_height = 30
    flame_width = 20
    # 화염 모양
    flame_points = [
        (20, y),
        (20 - flame_width//2, y - flame_height//3),
        (20 - flame_width//4, y - flame_height*2//3),
        (20, y - flame_height),
        (20 + flame_width//4, y - flame_height*2//3),
        (20 + flame_width//2, y - flame_height//3)
    ]
    draw.polygon(flame_points, fill=(255, 80, 30, 60))

# 우측 화염
for y in range(200, height - 200, 100):
    flame_height = 30
    flame_width = 20
    # 화염 모양
    flame_points = [
        (width - 20, y),
        (width - 20 - flame_width//2, y - flame_height//3),
        (width - 20 - flame_width//4, y - flame_height*2//3),
        (width - 20, y - flame_height),
        (width - 20 + flame_width//4, y - flame_height*2//3),
        (width - 20 + flame_width//2, y - flame_height//3)
    ]
    draw.polygon(flame_points, fill=(255, 80, 30, 60))

# 사이버펑크 디지털 꽃잎 (떨어지는 효과용 위치 표시)
digital_petals = []
for _ in range(15):
    x = random.randint(100, width - 100)
    y = random.randint(100, height - 100)
    # 중앙 영역은 피함
    if abs(x - center_x) > 100 or abs(y - center_y) > 100:
        size = 3
        draw.ellipse([x - size, y - size, x + size, y + size],
                     fill=(255, 150, 180, 40))

# 하단 중국식 격자 패턴 (간단하게)
grid_y = height - 80
for x in range(0, width, 40):
    # 세로선
    draw.line([x, grid_y, x, height], fill=(100, 50, 30, 50), width=1)
    # 가로선
    if x % 80 == 0:
        draw.line([x, grid_y + 20, x + 80, grid_y + 20], fill=(100, 50, 30, 50), width=1)
        draw.line([x, grid_y + 40, x + 80, grid_y + 40], fill=(100, 50, 30, 50), width=1)
        draw.line([x, grid_y + 60, x + 80, grid_y + 60], fill=(100, 50, 30, 50), width=1)

# 상단 중국식 격자 패턴
for x in range(0, width, 40):
    # 세로선
    draw.line([x, 0, x, 80], fill=(100, 50, 30, 50), width=1)
    # 가로선
    if x % 80 == 0:
        draw.line([x, 20, x + 80, 20], fill=(100, 50, 30, 50), width=1)
        draw.line([x, 40, x + 80, 40], fill=(100, 50, 30, 50), width=1)
        draw.line([x, 60, x + 80, 60], fill=(100, 50, 30, 50), width=1)

# 디지털 화염 입자 (극소량)
for _ in range(20):
    x = random.randint(50, width - 50)
    y = random.randint(150, height - 150)
    # 중앙 영역은 피함
    if abs(x - center_x) > 120 or abs(y - center_y) > 120:
        size = random.randint(1, 2)
        alpha = random.randint(30, 60)
        color = random.choice([
            (255, 100, 50, alpha),  # 주황
            (255, 50, 50, alpha),   # 빨강
            (255, 200, 100, alpha)  # 노랑
        ])
        draw.ellipse([x, y, x + size, y + size], fill=color)

# 오른쪽 하단에 작은 매화 장식
decoration_x, decoration_y = width - 100, height - 100
for i in range(3):
    blossom_x = decoration_x + random.randint(-20, 20)
    blossom_y = decoration_y + random.randint(-20, 20)
    # 5개 꽃잎 (작게)
    for petal in range(5):
        angle = petal * 72 + random.randint(-10, 10)
        rad = math.radians(angle)
        px = blossom_x + math.cos(rad) * 5
        py = blossom_y + math.sin(rad) * 5
        draw.ellipse([px - 3, py - 2, px + 3, py + 2],
                     fill=(255, 180, 200, 80))

# 부드럽게 처리
img = img.filter(ImageFilter.SMOOTH)

img.save('stage5_field.png')
print("Stage 5 Chinese traditional flame flower field created successfully!")