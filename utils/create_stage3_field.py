from PIL import Image, ImageDraw, ImageFilter, ImageFont
import random
import math

width, height = 600, 750

img = Image.new('RGB', (width, height))
draw = ImageDraw.Draw(img)

# 멘헤라 핑크 그라데이션 배경
for y in range(height):
    intensity = int(80 + (y / height) * 40)
    gradient_color = (intensity + 20, intensity - 20, intensity)  # 핑크빛
    draw.rectangle([0, y, width, y+1], fill=gradient_color)

# 체크무늬 패턴 (파스텔 핑크/흰색) - 크기 5배 증가
checker_size = 150  # 30 -> 150
for x in range(0, width, checker_size * 2):
    for y in range(0, height, checker_size * 2):
        # 체커보드 패턴
        draw.rectangle([x, y, x + checker_size, y + checker_size], 
                      fill=(255, 200, 220, 50))
        draw.rectangle([x + checker_size, y + checker_size, 
                       x + checker_size * 2, y + checker_size * 2], 
                      fill=(255, 200, 220, 50))

# 일본식 벚꽃 잎 떨어지기 (2~3개만)
for _ in range(3):
    petal_x = random.randint(100, width - 100)
    petal_y = random.randint(100, height - 100)
    petal_size = random.randint(8, 15)
    
    # 벚꽃 잎 모양 (5개 꽃잎)
    for i in range(5):
        angle = i * 72 + random.randint(-10, 10)
        rad = math.radians(angle)
        x = petal_x + math.cos(rad) * petal_size
        y = petal_y + math.sin(rad) * petal_size
        draw.ellipse([x - 5, y - 3, x + 5, y + 3], 
                    fill=(255, 150, 200))

# 가운데 요소들 모두 제거 - 깔끔한 체크무늬 배경만 유지

# 카와이 별 장식 (80% 감소 - 20개에서 4개로)
for _ in range(4):
    star_x = random.randint(50, width - 50)
    star_y = random.randint(50, height - 50)
    star_size = random.randint(5, 10)
    
    # 4각 별
    draw.polygon([
        (star_x, star_y - star_size),
        (star_x + star_size//2, star_y - star_size//2),
        (star_x + star_size, star_y),
        (star_x + star_size//2, star_y + star_size//2),
        (star_x, star_y + star_size),
        (star_x - star_size//2, star_y + star_size//2),
        (star_x - star_size, star_y),
        (star_x - star_size//2, star_y - star_size//2)
    ], fill=(255, 255, 150))

# 픽셀 하트 테두리 (상단)
for i in range(0, width, 40):
    # 픽셀 하트
    pixel_size = 3
    hx, hy = i + 20, 20
    # 하트 픽셀 패턴
    heart_pixels = [
        (hx - 6, hy), (hx - 3, hy), (hx + 3, hy), (hx + 6, hy),
        (hx - 9, hy + 3), (hx - 6, hy + 3), (hx - 3, hy + 3), 
        (hx, hy + 3), (hx + 3, hy + 3), (hx + 6, hy + 3), (hx + 9, hy + 3),
        (hx - 9, hy + 6), (hx - 6, hy + 6), (hx - 3, hy + 6),
        (hx, hy + 6), (hx + 3, hy + 6), (hx + 6, hy + 6), (hx + 9, hy + 6),
        (hx - 6, hy + 9), (hx - 3, hy + 9), (hx, hy + 9),
        (hx + 3, hy + 9), (hx + 6, hy + 9),
        (hx - 3, hy + 12), (hx, hy + 12), (hx + 3, hy + 12),
        (hx, hy + 15)
    ]
    for px, py in heart_pixels:
        draw.rectangle([px - 1, py - 1, px + 1, py + 1], fill=(255, 100, 150))

# 픽셀 하트 테두리 (하단)
for i in range(0, width, 40):
    hx, hy = i + 20, height - 35
    heart_pixels = [
        (hx - 6, hy), (hx - 3, hy), (hx + 3, hy), (hx + 6, hy),
        (hx - 9, hy + 3), (hx - 6, hy + 3), (hx - 3, hy + 3), 
        (hx, hy + 3), (hx + 3, hy + 3), (hx + 6, hy + 3), (hx + 9, hy + 3),
        (hx - 9, hy + 6), (hx - 6, hy + 6), (hx - 3, hy + 6),
        (hx, hy + 6), (hx + 3, hy + 6), (hx + 6, hy + 6), (hx + 9, hy + 6),
        (hx - 6, hy + 9), (hx - 3, hy + 9), (hx, hy + 9),
        (hx + 3, hy + 9), (hx + 6, hy + 9),
        (hx - 3, hy + 12), (hx, hy + 12), (hx + 3, hy + 12),
        (hx, hy + 15)
    ]
    for px, py in heart_pixels:
        draw.rectangle([px - 1, py - 1, px + 1, py + 1], fill=(255, 100, 150))

# 글리치 효과 제거 - 깔끔한 배경 유지

# 부드럽게 처리
img = img.filter(ImageFilter.SMOOTH)

img.save('stage3_field.png')
print("Stage 3 menhera cyberpunk field created successfully!")