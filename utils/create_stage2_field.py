from PIL import Image, ImageDraw, ImageFilter
import random
import math

width, height = 600, 750

img = Image.new('RGB', (width, height))
draw = ImageDraw.Draw(img)

# 스타디움 바닥 - 어두운 사이버펑크 그라데이션
for y in range(height):
    intensity = int(15 + (y / height) * 25)
    gradient_color = (intensity, intensity + 5, intensity + 10)
    draw.rectangle([0, y, width, y+1], fill=gradient_color)

# 중앙 악어 얼굴 엠블럼 카펫
center_x, center_y = width//2, height//2

# 카펫 배경 (타원형)
carpet_width = 180
carpet_height = 150
draw.ellipse([center_x - carpet_width//2, center_y - carpet_height//2,
              center_x + carpet_width//2, center_y + carpet_height//2],
             fill=(50, 100, 50))

# 카펫 테두리
draw.ellipse([center_x - carpet_width//2, center_y - carpet_height//2,
              center_x + carpet_width//2, center_y + carpet_height//2],
             outline=(30, 70, 30), width=3)

# 악어 얼굴
# 머리 (메인 타원)
head_width = 120
head_height = 100
draw.ellipse([center_x - head_width//2, center_y - head_height//2,
              center_x + head_width//2, center_y + head_height//2],
             fill=(60, 140, 60))

# 주둥이 (긴 타원)
snout_width = 80
snout_height = 40
draw.ellipse([center_x - snout_width//2, center_y + 20,
              center_x + snout_width//2, center_y + 20 + snout_height],
             fill=(50, 120, 50))

# 눈 (양쪽)
eye_size = 15
# 왼쪽 눈
draw.ellipse([center_x - 35, center_y - 20,
              center_x - 35 + eye_size, center_y - 20 + eye_size],
             fill=(200, 200, 0))
draw.ellipse([center_x - 32, center_y - 17,
              center_x - 32 + 8, center_y - 17 + 8],
             fill=(0, 0, 0))

# 오른쪽 눈
draw.ellipse([center_x + 20, center_y - 20,
              center_x + 20 + eye_size, center_y - 20 + eye_size],
             fill=(200, 200, 0))
draw.ellipse([center_x + 23, center_y - 17,
              center_x + 23 + 8, center_y - 17 + 8],
             fill=(0, 0, 0))

# 코 구멍
draw.ellipse([center_x - 8, center_y + 35,
              center_x - 3, center_y + 42],
             fill=(20, 60, 20))
draw.ellipse([center_x + 3, center_y + 35,
              center_x + 8, center_y + 42],
             fill=(20, 60, 20))

# 이빨 (삼각형들)
tooth_color = (255, 255, 230)
# 왼쪽 이빨들
for i in range(3):
    tx = center_x - 30 + i * 12
    ty = center_y + 30
    draw.polygon([(tx, ty), (tx - 3, ty + 8), (tx + 3, ty + 8)],
                fill=tooth_color)

# 오른쪽 이빨들
for i in range(3):
    tx = center_x + 6 + i * 12
    ty = center_y + 30
    draw.polygon([(tx, ty), (tx - 3, ty + 8), (tx + 3, ty + 8)],
                fill=tooth_color)

# 악어 비늘 패턴 (작은 다이아몬드)
for row in range(3):
    for col in range(5):
        scale_x = center_x - 40 + col * 20
        scale_y = center_y - 30 + row * 20
        if abs(scale_x - center_x) < 35 and abs(scale_y - center_y) < 40:
            draw.polygon([(scale_x, scale_y - 3),
                         (scale_x - 3, scale_y),
                         (scale_x, scale_y + 3),
                         (scale_x + 3, scale_y)],
                        fill=(40, 100, 40))

# 🏟️ 경기장 센터라인 (정글 테마 녹색)
line_color = (0, 180, 80)  # 밝은 정글 녹색
line_width = 3

# 중앙 서클 반지름
circle_radius = 120  # 악어 엠블럼보다 약간 크게

# 수평 센터라인 (원 밖에서만 - 왼쪽 부분)
draw.line([0, center_y, center_x - circle_radius, center_y], fill=line_color, width=line_width)

# 수평 센터라인 (원 밖에서만 - 오른쪽 부분)
draw.line([center_x + circle_radius, center_y, width, center_y], fill=line_color, width=line_width)

# 중앙 서클 (악어 엠블럼 둘러싸기)
draw.ellipse([center_x - circle_radius, center_y - circle_radius,
              center_x + circle_radius, center_y + circle_radius],
             outline=line_color, width=line_width)

# 센터 스팟 (중앙점 표시)
center_spot_radius = 8
draw.ellipse([center_x - center_spot_radius, center_y - center_spot_radius,
              center_x + center_spot_radius, center_y + center_spot_radius],
             fill=line_color)

# 사이버펑크 그리드 (바닥)
for x in range(100, width - 100, 40):
    for y in range(center_y - 200, center_y + 200, 40):
        opacity = int(50 - abs(y - center_y) / 5)
        if opacity > 0:
            draw.point((x, y), fill=(0, 200, 150, opacity))

# 테두리 정글 - 왼쪽 제거됨 (사용자 요청)

# 테두리 정글 - 오른쪽 제거됨 (사용자 요청)

# 상단 정글 덩굴 제거됨 (사용자 요청)

# 상단 바위 제거됨 (사용자 요청)

# 하단 정글 덩굴 제거됨 (사용자 요청)

# 네온 조명 제거 - 깔끔한 배경 유지

# 부드럽게 처리
img = img.filter(ImageFilter.SMOOTH)

img.save('stage2_field.png')
print("Stage 2 jungle cyberpunk field created successfully!")