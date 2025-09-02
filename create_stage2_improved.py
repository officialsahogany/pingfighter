#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Stage 2 개선된 배경 생성기
- 밝은 배경
- 중앙 캐릭터 유지
- 성능 최적화
"""

import pygame
import math

# 초기화
pygame.init()

# 화면 크기
WIDTH = 600
HEIGHT = 750
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Stage 2 - 개선된 정글 테마")

def create_stage2_improved_background():
    """Stage 2 개선된 배경 생성"""
    background = pygame.Surface((WIDTH, HEIGHT))
    
    # 1. 밝은 정글 배경 (어두운 검정색에서 밝은 정글 색상으로 변경)
    for y in range(HEIGHT):
        ratio = y / HEIGHT
        # 위쪽은 밝은 녹색 하늘, 아래쪽은 진한 정글 바닥
        if y < HEIGHT // 3:
            # 하늘 부분 - 밝은 청록색
            sky_ratio = y / (HEIGHT // 3)
            r = int(40 + sky_ratio * 20)
            g = int(80 + sky_ratio * 30)
            b = int(60 + sky_ratio * 20)
        else:
            # 정글 바닥 부분 - 진한 녹색에서 갈색으로
            ground_ratio = (y - HEIGHT // 3) / (HEIGHT * 2 // 3)
            r = int(30 + ground_ratio * 40)
            g = int(60 - ground_ratio * 20)
            b = int(30 + ground_ratio * 20)
        pygame.draw.line(background, (r, g, b), (0, y), (WIDTH, y))
    
    # 2. 정글 테두리 (밝은 녹색)
    border_thickness = 10
    border_color = (34, 139, 34)  # Forest Green
    inner_border_color = (50, 205, 50)  # Lime Green
    
    # 외부 테두리
    pygame.draw.rect(background, border_color, (0, 0, WIDTH, border_thickness))
    pygame.draw.rect(background, border_color, (0, HEIGHT - border_thickness, WIDTH, border_thickness))
    pygame.draw.rect(background, border_color, (0, 0, border_thickness, HEIGHT))
    pygame.draw.rect(background, border_color, (WIDTH - border_thickness, 0, border_thickness, HEIGHT))
    
    # 내부 장식 테두리
    inner_thickness = 2
    pygame.draw.rect(background, inner_border_color, 
                    (border_thickness, border_thickness, 
                     WIDTH - 2*border_thickness, inner_thickness))
    pygame.draw.rect(background, inner_border_color,
                    (border_thickness, HEIGHT - border_thickness - inner_thickness, 
                     WIDTH - 2*border_thickness, inner_thickness))
    
    # 3. 중앙 스타디움 라인 (밝은 녹색)
    center_x = WIDTH // 2
    center_y = HEIGHT // 2
    stadium_radius = 80
    
    # 원형 스타디움
    pygame.draw.circle(background, (0, 200, 0), (center_x, center_y), stadium_radius, 3)
    pygame.draw.circle(background, (0, 150, 0), (center_x, center_y), stadium_radius - 5, 1)
    
    # 가로 중앙선
    pygame.draw.line(background, (0, 200, 0), (0, center_y), (WIDTH, center_y), 2)
    
    # 4. 중앙 캐릭터 얼굴 (유지하되 약간 투명하게)
    face_surface = pygame.Surface((160, 160), pygame.SRCALPHA)
    
    # 얼굴 배경 (타원형)
    face_color = (50, 150, 50, 180)  # 반투명 녹색
    pygame.draw.ellipse(face_surface, face_color, (20, 30, 120, 100))
    
    # 눈 (노란색)
    eye_color = (255, 215, 0)
    pygame.draw.circle(face_surface, eye_color, (50, 70), 8)
    pygame.draw.circle(face_surface, eye_color, (110, 70), 8)
    
    # 눈동자
    pygame.draw.circle(face_surface, (0, 0, 0), (50, 70), 4)
    pygame.draw.circle(face_surface, (0, 0, 0), (110, 70), 4)
    
    # 입 (삼각형 이빨)
    mouth_y = 100
    teeth_color = (255, 255, 255)
    for i in range(6):
        x = 45 + i * 12
        pygame.draw.polygon(face_surface, teeth_color, 
                           [(x, mouth_y), (x + 5, mouth_y - 8), (x + 10, mouth_y)])
    
    # 얼굴을 배경에 블릿
    background.blit(face_surface, (center_x - 80, center_y - 80))
    
    # 5. 간소화된 덤불 (양쪽 가장자리)
    bush_positions = [
        # 왼쪽 덤불들
        (30, 100), (50, 200), (40, 300), (35, 400), (45, 500), (30, 600),
        # 오른쪽 덤불들
        (WIDTH - 30, 150), (WIDTH - 50, 250), (WIDTH - 40, 350), 
        (WIDTH - 35, 450), (WIDTH - 45, 550), (WIDTH - 30, 650)
    ]
    
    for bush_x, bush_y in bush_positions:
        # 덤불 그림자
        shadow_color = (20, 40, 20, 50)
        pygame.draw.ellipse(background, shadow_color, 
                          (bush_x - 25, bush_y + 10, 50, 20))
        
        # 덤불 본체 (단순한 원 클러스터)
        bush_color = (34, 100, 34)
        highlight_color = (50, 150, 50)
        
        # 메인 덤불
        pygame.draw.circle(background, bush_color, (bush_x, bush_y), 20)
        pygame.draw.circle(background, bush_color, (bush_x - 10, bush_y - 5), 15)
        pygame.draw.circle(background, bush_color, (bush_x + 10, bush_y - 5), 15)
        
        # 하이라이트
        pygame.draw.circle(background, highlight_color, (bush_x - 5, bush_y - 8), 8)
        pygame.draw.circle(background, highlight_color, (bush_x + 5, bush_y - 6), 6)
    
    # 6. 덩굴 장식 (정적, 단순화)
    vine_positions = [(100, 0), (200, 0), (400, 0), (500, 0)]
    vine_color = (40, 80, 40)
    
    for vine_x, vine_y in vine_positions:
        # 간단한 덩굴 (직선 + 약간의 곡선)
        points = []
        for i in range(10):
            y = vine_y + i * 15
            x = vine_x + math.sin(i * 0.5) * 10
            points.append((x, y))
            # 덩굴 마디
            pygame.draw.circle(background, vine_color, (int(x), int(y)), 4)
        
        # 덩굴 연결선
        if len(points) > 1:
            pygame.draw.lines(background, vine_color, False, points, 3)
    
    # 7. 장식 나뭇잎 (적은 수, 정적)
    leaf_decorations = [
        (150, 50, (50, 150, 50)),
        (450, 80, (60, 160, 60)),
        (250, HEIGHT - 50, (40, 140, 40)),
        (350, HEIGHT - 80, (55, 155, 55))
    ]
    
    for leaf_x, leaf_y, leaf_color in leaf_decorations:
        # 간단한 타원형 잎
        pygame.draw.ellipse(background, leaf_color, 
                          (leaf_x - 10, leaf_y - 15, 20, 30))
        # 잎맥
        pygame.draw.line(background, (30, 100, 30), 
                        (leaf_x, leaf_y - 15), (leaf_x, leaf_y + 15), 1)
    
    return background

def main():
    """메인 실행 함수"""
    clock = pygame.time.Clock()
    running = True
    
    # Stage 2 개선된 배경 생성
    stage2_bg = create_stage2_improved_background()
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_s:
                    # S키를 누르면 이미지 저장
                    pygame.image.save(stage2_bg, "stage2_field_improved.png")
                    print("Stage 2 개선된 배경이 'stage2_field_improved.png'로 저장되었습니다!")
        
        # 배경 그리기
        screen.blit(stage2_bg, (0, 0))
        
        # 화면 업데이트
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()

if __name__ == "__main__":
    main()
    print("\n=== Stage 2 개선 사항 ===")
    print("✅ 배경 밝기 증가 (검정 → 밝은 정글색)")
    print("✅ 중앙 캐릭터 유지 (반투명 처리)")
    print("✅ 덤불 시스템 단순화 (클러스터 50% 감소)")
    print("✅ 낙엽 개수 감소 (8개 → 4개)")
    print("✅ 성능 최적화")
    print("\n개선 후 시각적 명료성과 성능이 향상되었습니다!")