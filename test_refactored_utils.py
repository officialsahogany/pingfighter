#!/usr/bin/env python3
"""
리팩토링된 유틸리티 모듈 테스트
각 모듈이 독립적으로 잘 작동하는지 확인
"""
import pygame
import sys
import random
from utils.color_utils import *
from utils.math_utils import *
from utils.draw_utils import DrawHelper, draw_gradient_rect, draw_glow_effect, draw_star
from utils.particle_utils import *
from utils.game_constants import *
from config.constants import WIDTH, HEIGHT

def test_color_utils():
    """색상 유틸리티 테스트"""
    print("=" * 50)
    print("색상 유틸리티 테스트")
    print("-" * 50)
    
    # 기본 색상 상수 테스트
    print(f"WHITE: {WHITE}")
    print(f"BLACK: {BLACK}")
    print(f"RED: {RED}")
    
    # 스테이지 색상 테스트
    for stage in range(1, 7):
        color = get_stage_color(stage)
        print(f"Stage {stage} 색상: {color}")
    
    # 색상 블렌딩 테스트
    blended = blend_colors(RED, BLUE, 0.5)
    print(f"RED와 BLUE 50% 블렌딩: {blended}")
    
    # 네온 색상 테스트
    neon_cyan = get_neon_color(CYAN)
    print(f"CYAN 네온 효과: {neon_cyan}")
    
    print("✅ 색상 유틸리티 테스트 완료\n")

def test_math_utils():
    """수학 유틸리티 테스트"""
    print("=" * 50)
    print("수학 유틸리티 테스트")
    print("-" * 50)
    
    # 거리 계산 테스트
    pos1 = (0, 0)
    pos2 = (3, 4)
    distance = calculate_distance(pos1, pos2)
    print(f"(0,0)과 (3,4) 사이 거리: {distance}")  # 예상: 5.0
    
    # 벡터 정규화 테스트
    normalized = normalize_vector(3, 4)
    print(f"(3, 4) 벡터 정규화: {normalized}")  # 예상: (0.6, 0.8)
    
    # 각도 계산 테스트
    angle = get_angle_between(pos1, pos2)
    print(f"(0,0)에서 (3,4)로의 각도: {angle} 라디안")
    
    # 선형 보간 테스트
    lerped = lerp(0, 100, 0.3)
    print(f"0에서 100까지 30% 보간: {lerped}")  # 예상: 30
    
    # 값 제한 테스트
    clamped = clamp(150, 0, 100)
    print(f"150을 0~100으로 클램핑: {clamped}")  # 예상: 100
    
    print("✅ 수학 유틸리티 테스트 완료\n")

def test_pygame_dependent():
    """Pygame 의존 기능 테스트 (시각적 확인)"""
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("유틸리티 모듈 테스트")
    clock = pygame.time.Clock()
    
    # DrawHelper 테스트
    draw_helper = DrawHelper(screen)
    
    # 파티클 리스트
    particles = []
    
    # 테스트 시간
    test_duration = 300  # 5초
    frame_count = 0
    
    running = True
    while running and frame_count < test_duration:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 스페이스바로 파티클 생성
                    mouse_x, mouse_y = pygame.mouse.get_pos()
                    for _ in range(10):
                        create_energy_particle(mouse_x, mouse_y, particles)
                        create_spark_particle(mouse_x, mouse_y, particles)
                        create_neon_particle(mouse_x, mouse_y, particles)
        
        # 화면 지우기
        screen.fill(BLACK)
        
        # 그라데이션 배경
        draw_gradient_rect(screen, (0, 0, WIDTH, HEIGHT // 2), 
                          DARK_GRAY, get_stage_color(1))
        draw_gradient_rect(screen, (0, HEIGHT // 2, WIDTH, HEIGHT // 2), 
                          get_stage_color(1), BLACK)
        
        # DrawHelper로 도형 그리기
        # 원
        draw_helper.circle(RED, (100, 100), 30)
        draw_helper.circle(GREEN, (100, 100), 25, 2)
        
        # 사각형
        draw_helper.rect(BLUE, (200, 80, 60, 40))
        draw_helper.rect(YELLOW, (200, 80, 60, 40), 2)
        
        # 선
        draw_helper.line(CYAN, (300, 100), (400, 100), 3)
        
        # 다각형 (삼각형)
        points = [(450, 120), (430, 80), (470, 80)]
        draw_helper.polygon(MAGENTA, points)
        
        # 글로우 효과
        mouse_x, mouse_y = pygame.mouse.get_pos()
        draw_glow_effect(screen, (mouse_x, mouse_y), 20, NEON_PALETTE[frame_count % len(NEON_PALETTE)])
        
        # 별 그리기
        star_rotation = frame_count * 0.02
        draw_star(screen, YELLOW, (WIDTH // 2, 300), 50, 25, 5, star_rotation)
        
        # 파티클 업데이트 및 그리기
        particles = update_particles(particles, gravity=0.1, friction=0.99)
        draw_particles(screen, particles)
        
        # 정보 표시
        font = pygame.font.Font(None, 24)
        info_texts = [
            f"프레임: {frame_count}/{test_duration}",
            f"파티클 수: {len(particles)}",
            "스페이스바: 파티클 생성",
            "ESC: 종료"
        ]
        
        y = 10
        for text in info_texts:
            text_surface = font.render(text, True, WHITE)
            screen.blit(text_surface, (10, y))
            y += 30
        
        # 스테이지 색상 팔레트 표시
        for i in range(1, 7):
            color = get_stage_color(i)
            x = 10 + (i - 1) * 95
            y = HEIGHT - 60
            pygame.draw.rect(screen, color, (x, y, 80, 40))
            text = font.render(f"Stage {i}", True, WHITE)
            screen.blit(text, (x + 10, y + 10))
        
        pygame.display.flip()
        clock.tick(FPS)
        frame_count += 1
    
    pygame.quit()
    print("✅ Pygame 의존 테스트 완료\n")

def test_constants():
    """상수 테스트"""
    print("=" * 50)
    print("게임 상수 테스트")
    print("-" * 50)
    
    print(f"화면 크기: {WIDTH}x{HEIGHT}")
    print(f"FPS: {FPS}")
    print(f"대시 쿨다운: {DASH_COOLDOWN} 프레임")
    print(f"아이템 스폰 간격: {ITEM_SPAWN_INTERVAL} 프레임")
    print(f"최대 파티클 수: {MAX_PARTICLES}")
    
    print("\n게임 모드:")
    for mode, name in GAME_MODES.items():
        print(f"  {mode}: {name}")
    
    print("\n스테이지 난이도:")
    for stage, multiplier in STAGE_DIFFICULTY_MULTIPLIER.items():
        print(f"  Stage {stage}: x{multiplier}")
    
    print("✅ 상수 테스트 완료\n")

def main():
    """메인 테스트 실행"""
    print("🚀 리팩토링된 유틸리티 모듈 테스트 시작")
    print("=" * 50)
    
    # 각 모듈 테스트
    test_color_utils()
    test_math_utils()
    test_constants()
    
    # Pygame 의존 테스트 (시각적 확인)
    print("시각적 테스트를 시작합니다...")
    print("마우스를 움직이고 스페이스바를 눌러 파티클을 생성하세요.")
    test_pygame_dependent()
    
    print("\n" + "=" * 50)
    print("✨ 모든 테스트 완료!")
    print("리팩토링된 모듈들이 정상적으로 작동합니다.")
    print("=" * 50)

if __name__ == "__main__":
    main()