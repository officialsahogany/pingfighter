import pygame
import sys
import math
import random

pygame.init()
screen = pygame.display.set_mode((300, 300))
pygame.display.set_caption("군인 캐릭터 앞모습 테스트")
clock = pygame.time.Clock()

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)

def create_soldier_front_view():
    """군인 캐릭터 앞모습 - 전신"""
    img = pygame.Surface((150, 200), pygame.SRCALPHA)
    
    # 중심점 설정
    center_x = 75
    
    # === 머리와 헬멧 ===
    head_y = 30
    # 헬멧 그림자
    pygame.draw.ellipse(img, (45, 65, 30), 
                       (center_x - 22, head_y - 2, 44, 36))
    # 헬멧 베이스
    pygame.draw.ellipse(img, (70, 90, 50), 
                       (center_x - 20, head_y, 40, 35))
    # 헬멧 앞면 디테일
    pygame.draw.ellipse(img, (80, 100, 60), 
                       (center_x - 15, head_y + 3, 30, 28))
    # 헬멧 끈
    pygame.draw.arc(img, (50, 70, 35), 
                   (center_x - 20, head_y + 28, 40, 20), 
                   0, math.pi, 2)
    
    # === 얼굴 ===
    face_y = head_y + 25
    # 얼굴 베이스
    pygame.draw.ellipse(img, (210, 180, 150), 
                       (center_x - 12, face_y, 24, 28))
    # 눈
    eye_y = face_y + 8
    # 왼쪽 눈
    pygame.draw.ellipse(img, (30, 30, 30), 
                       (center_x - 8, eye_y, 5, 6))
    pygame.draw.ellipse(img, WHITE, 
                       (center_x - 7, eye_y + 1, 2, 2))
    # 오른쪽 눈
    pygame.draw.ellipse(img, (30, 30, 30), 
                       (center_x + 3, eye_y, 5, 6))
    pygame.draw.ellipse(img, WHITE, 
                       (center_x + 4, eye_y + 1, 2, 2))
    # 코
    pygame.draw.line(img, (180, 150, 120), 
                    (center_x, eye_y + 6), (center_x, eye_y + 10), 1)
    # 입 (진지한 표정)
    pygame.draw.arc(img, (160, 120, 90), 
                   (center_x - 5, face_y + 16, 10, 6), 
                   0.2, 2.9, 2)
    
    # === 목 ===
    neck_y = face_y + 26
    pygame.draw.rect(img, (190, 160, 130), 
                    (center_x - 8, neck_y, 16, 8))
    
    # === 상체 (군복) ===
    body_y = neck_y + 8
    # 어깨
    shoulder_points = [
        (center_x - 35, body_y + 5),
        (center_x - 20, body_y),
        (center_x + 20, body_y),
        (center_x + 35, body_y + 5),
        (center_x + 32, body_y + 40),
        (center_x + 15, body_y + 45),
        (center_x - 15, body_y + 45),
        (center_x - 32, body_y + 40)
    ]
    pygame.draw.polygon(img, (115, 105, 65), shoulder_points)
    
    # 군복 디테일
    # 지퍼
    pygame.draw.line(img, (85, 75, 45), 
                    (center_x, body_y + 5), (center_x, body_y + 40), 2)
    # 주머니
    pygame.draw.rect(img, (95, 85, 55), 
                    (center_x - 25, body_y + 15, 12, 10))
    pygame.draw.rect(img, (95, 85, 55), 
                    (center_x + 13, body_y + 15, 12, 10))
    # 계급장
    pygame.draw.polygon(img, (160, 140, 70), [
        (center_x - 30, body_y + 8),
        (center_x - 20, body_y + 6),
        (center_x - 20, body_y + 12),
        (center_x - 30, body_y + 10)
    ])
    pygame.draw.polygon(img, (160, 140, 70), [
        (center_x + 20, body_y + 6),
        (center_x + 30, body_y + 8),
        (center_x + 30, body_y + 10),
        (center_x + 20, body_y + 12)
    ])
    
    # === 팔 ===
    # 왼팔 (탁구채를 들고 있는 팔)
    left_arm_points = [
        (center_x - 32, body_y + 10),
        (center_x - 35, body_y + 25),
        (center_x - 30, body_y + 45),
        (center_x - 25, body_y + 48),
        (center_x - 20, body_y + 45),
        (center_x - 25, body_y + 25),
        (center_x - 28, body_y + 12)
    ]
    pygame.draw.polygon(img, (120, 108, 68), left_arm_points)
    
    # 오른팔
    right_arm_points = [
        (center_x + 28, body_y + 12),
        (center_x + 25, body_y + 25),
        (center_x + 20, body_y + 45),
        (center_x + 25, body_y + 48),
        (center_x + 30, body_y + 45),
        (center_x + 35, body_y + 25),
        (center_x + 32, body_y + 10)
    ]
    pygame.draw.polygon(img, (120, 108, 68), right_arm_points)
    
    # === 손 ===
    # 왼손 (탁구채를 잡고 있는 손)
    hand_x = center_x - 25
    hand_y = body_y + 50
    pygame.draw.ellipse(img, (210, 180, 150), 
                       (hand_x - 5, hand_y - 5, 10, 10))
    # 손가락들
    for i in range(4):
        angle = -0.3 + i * 0.2
        finger_x = hand_x + math.cos(angle) * 7
        finger_y = hand_y + math.sin(angle) * 7
        pygame.draw.ellipse(img, (200, 170, 140), 
                           (finger_x - 1, finger_y - 1, 3, 4))
    
    # 오른손
    right_hand_x = center_x + 25
    pygame.draw.ellipse(img, (210, 180, 150), 
                       (right_hand_x - 5, hand_y + 10, 10, 10))
    
    # === 탁구채 ===
    paddle_x = hand_x - 5
    paddle_y = hand_y - 15
    # 손잡이
    pygame.draw.rect(img, (100, 60, 40), 
                    (paddle_x - 2, paddle_y + 15, 5, 15))
    # 라켓 면 (원형)
    pygame.draw.ellipse(img, (80, 100, 60), 
                       (paddle_x - 13, paddle_y - 13, 26, 26))
    pygame.draw.ellipse(img, (100, 120, 80), 
                       (paddle_x - 13, paddle_y - 13, 26, 26), 2)
    # 라켓 고무 (빨간색)
    pygame.draw.ellipse(img, (150, 40, 30), 
                       (paddle_x - 10, paddle_y - 10, 20, 20))
    # 중앙 패턴
    pygame.draw.ellipse(img, (130, 30, 20), 
                       (paddle_x - 6, paddle_y - 6, 12, 12))
    # 군용 별 마크
    for i in range(5):
        angle = math.radians(i * 72 - 90)
        x = paddle_x + int(3 * math.cos(angle))
        y = paddle_y + int(3 * math.sin(angle))
        pygame.draw.line(img, (100, 20, 10), (paddle_x, paddle_y), (x, y), 1)
    
    # === 하체 ===
    waist_y = body_y + 45
    # 벨트
    pygame.draw.rect(img, (60, 50, 30), 
                    (center_x - 25, waist_y, 50, 5))
    pygame.draw.rect(img, (140, 120, 60), 
                    (center_x - 8, waist_y - 1, 16, 7))
    
    # === 다리 ===
    leg_y = waist_y + 5
    # 왼쪽 다리
    left_leg_points = [
        (center_x - 15, leg_y),
        (center_x - 18, leg_y + 20),
        (center_x - 16, leg_y + 40),
        (center_x - 12, leg_y + 55),
        (center_x - 8, leg_y + 55),
        (center_x - 5, leg_y + 40),
        (center_x - 8, leg_y + 20),
        (center_x - 10, leg_y)
    ]
    pygame.draw.polygon(img, (110, 100, 60), left_leg_points)
    
    # 오른쪽 다리
    right_leg_points = [
        (center_x + 10, leg_y),
        (center_x + 8, leg_y + 20),
        (center_x + 5, leg_y + 40),
        (center_x + 8, leg_y + 55),
        (center_x + 12, leg_y + 55),
        (center_x + 16, leg_y + 40),
        (center_x + 18, leg_y + 20),
        (center_x + 15, leg_y)
    ]
    pygame.draw.polygon(img, (110, 100, 60), right_leg_points)
    
    # === 군화 ===
    boot_y = leg_y + 55
    # 왼쪽 군화
    pygame.draw.polygon(img, (40, 35, 25), [
        (center_x - 12, boot_y),
        (center_x - 14, boot_y + 8),
        (center_x - 12, boot_y + 12),
        (center_x - 2, boot_y + 12),
        (center_x, boot_y + 8),
        (center_x - 2, boot_y),
        (center_x - 8, boot_y)
    ])
    # 군화 끈
    pygame.draw.line(img, (25, 20, 15), 
                    (center_x - 10, boot_y + 2), (center_x - 4, boot_y + 2), 1)
    pygame.draw.line(img, (25, 20, 15), 
                    (center_x - 10, boot_y + 5), (center_x - 4, boot_y + 5), 1)
    
    # 오른쪽 군화
    pygame.draw.polygon(img, (40, 35, 25), [
        (center_x + 2, boot_y),
        (center_x, boot_y + 8),
        (center_x + 2, boot_y + 12),
        (center_x + 12, boot_y + 12),
        (center_x + 14, boot_y + 8),
        (center_x + 12, boot_y),
        (center_x + 8, boot_y)
    ])
    # 군화 끈
    pygame.draw.line(img, (25, 20, 15), 
                    (center_x + 4, boot_y + 2), (center_x + 10, boot_y + 2), 1)
    pygame.draw.line(img, (25, 20, 15), 
                    (center_x + 4, boot_y + 5), (center_x + 10, boot_y + 5), 1)
    
    # === 위장 패턴 ===
    camo_colors = [(85, 75, 45), (105, 95, 55), (95, 85, 50)]
    # 상체 위장
    for i in range(12):
        camo_x = center_x - 25 + (i % 4) * 12 + random.randint(-3, 3)
        camo_y = body_y + 10 + (i // 4) * 10 + random.randint(-2, 2)
        camo_size = random.randint(5, 9)
        pygame.draw.ellipse(img, camo_colors[i % 3], 
                           (camo_x, camo_y, camo_size, camo_size - 1))
    
    # 다리 위장
    for i in range(6):
        # 왼쪽 다리
        camo_x = center_x - 12 + random.randint(-3, 3)
        camo_y = leg_y + 10 + i * 7 + random.randint(-1, 1)
        pygame.draw.ellipse(img, camo_colors[i % 3], 
                           (camo_x, camo_y, random.randint(4, 6), random.randint(3, 5)))
        # 오른쪽 다리
        camo_x = center_x + 12 + random.randint(-3, 3)
        camo_y = leg_y + 10 + i * 7 + random.randint(-1, 1)
        pygame.draw.ellipse(img, camo_colors[i % 3], 
                           (camo_x, camo_y, random.randint(4, 6), random.randint(3, 5)))
    
    return img

# 군인 캐릭터 이미지 생성
soldier_img = create_soldier_front_view()

running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_SPACE:
                # 스페이스바를 누르면 새로운 위장 패턴으로 재생성
                soldier_img = create_soldier_front_view()
    
    screen.fill(WHITE)
    
    # 군인 캐릭터 그리기
    screen.blit(soldier_img, (75, 50))
    
    # 설명 텍스트
    font = pygame.font.Font(None, 24)
    text = font.render("Press SPACE to regenerate", True, BLACK)
    screen.blit(text, (50, 10))
    
    pygame.display.flip()
    clock.tick(60)

pygame.quit()
sys.exit()