#!/usr/bin/env python3
"""AK-47 사운드 시스템 테스트 스크립트"""

import pygame
import sys
import os

# Pygame 초기화
pygame.init()
pygame.mixer.init()

# 화면 설정
WIDTH = 800
HEIGHT = 600
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("AK-47 사운드 테스트")

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
YELLOW = (255, 255, 0)

# 리소스 경로 함수
def resource_path(relative_path):
    """PyInstaller와 개발 환경 모두에서 작동하는 리소스 경로"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)

# 폰트 설정
try:
    font = pygame.font.Font(resource_path("fonts/NanumSquareB.ttf"), 24)
    small_font = pygame.font.Font(resource_path("fonts/NanumSquareB.ttf"), 18)
except:
    font = pygame.font.Font(None, 24)
    small_font = pygame.font.Font(None, 18)

# AK-47 사운드 로드
try:
    ak47_sound = pygame.mixer.Sound(resource_path("sounds/ak47.wav"))
    ak47_sound.set_volume(0.5)
    sound_loaded = True
except Exception as e:
    print(f"사운드 로드 실패: {e}")
    ak47_sound = None
    sound_loaded = False

# 테스트 변수
space_pressed = False
space_was_released = True
burst_shots_fired = 0
burst_shots_required = 2
is_firing = False
shot_cooldown = 0
fire_interval = 6  # 0.1초 (60 FPS)
ammo = 90
last_shot_time = 0

# 메인 루프
clock = pygame.time.Clock()
running = True

while running:
    dt = clock.tick(60) / 1000.0  # 60 FPS
    
    # 이벤트 처리
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_R:
                # R키로 탄약 재장전
                ammo = 90
                burst_shots_fired = 0
                is_firing = False
    
    # 키 상태 확인
    keys = pygame.key.get_pressed()
    
    # 스페이스바 입력 처리 (AK-47 로직 시뮬레이션)
    if keys[pygame.K_SPACE]:
        if space_was_released:
            # 스페이스를 처음 눌렀을 때 - 2발 연사 시작
            space_was_released = False
            burst_shots_fired = 0
            is_firing = True
        elif burst_shots_fired >= burst_shots_required:
            # 스페이스를 계속 누르고 있으면 연사 모드
            is_firing = True
    else:
        # 스페이스를 떼었을 때
        space_was_released = True
        is_firing = False
        burst_shots_fired = 0
    
    # 쿨다운 감소
    if shot_cooldown > 0:
        shot_cooldown -= 1
    
    # 발사 처리
    if is_firing and ammo > 0 and shot_cooldown <= 0:
        # 버스트 모드에서 2발만 발사
        if burst_shots_fired < burst_shots_required:
            if sound_loaded and ak47_sound:
                ak47_sound.play()
            ammo -= 1
            shot_cooldown = fire_interval
            burst_shots_fired += 1
            last_shot_time = pygame.time.get_ticks()
        # 연사 모드
        elif not space_was_released:
            if sound_loaded and ak47_sound:
                ak47_sound.play()
            ammo -= 1
            shot_cooldown = fire_interval
            last_shot_time = pygame.time.get_ticks()
    
    # 화면 그리기
    SCREEN.fill(BLACK)
    
    # 제목
    title = font.render("AK-47 사운드 테스트", True, WHITE)
    title_rect = title.get_rect(center=(WIDTH // 2, 50))
    SCREEN.blit(title, title_rect)
    
    # 사운드 상태
    sound_status = "사운드 로드됨" if sound_loaded else "사운드 로드 실패!"
    color = GREEN if sound_loaded else RED
    status_text = small_font.render(f"상태: {sound_status}", True, color)
    SCREEN.blit(status_text, (50, 150))
    
    # 탄약 표시
    ammo_text = small_font.render(f"탄약: {ammo}/90", True, WHITE)
    SCREEN.blit(ammo_text, (50, 200))
    
    # 발사 모드
    mode = "대기 중"
    mode_color = WHITE
    if is_firing:
        if burst_shots_fired < burst_shots_required:
            mode = f"버스트 모드 ({burst_shots_fired}/{burst_shots_required})"
            mode_color = YELLOW
        else:
            mode = "연사 모드"
            mode_color = RED
    mode_text = small_font.render(f"모드: {mode}", True, mode_color)
    SCREEN.blit(mode_text, (50, 250))
    
    # 마지막 발사 시간
    current_time = pygame.time.get_ticks()
    time_since_shot = (current_time - last_shot_time) / 1000.0 if last_shot_time > 0 else 0
    time_text = small_font.render(f"마지막 발사: {time_since_shot:.1f}초 전", True, WHITE)
    SCREEN.blit(time_text, (50, 300))
    
    # 조작 설명
    instructions = [
        "스페이스바: 발사 (한 번 누르면 2발, 계속 누르면 연사)",
        "R: 탄약 재장전",
        "ESC: 종료"
    ]
    y = 400
    for instruction in instructions:
        inst_text = small_font.render(instruction, True, WHITE)
        SCREEN.blit(inst_text, (50, y))
        y += 30
    
    # 시각적 피드백
    if is_firing and shot_cooldown == fire_interval:
        # 발사 시 플래시 효과
        flash_surface = pygame.Surface((WIDTH, HEIGHT))
        flash_surface.set_alpha(30)
        flash_surface.fill(YELLOW)
        SCREEN.blit(flash_surface, (0, 0))
    
    pygame.display.flip()

# 종료
pygame.quit()
sys.exit()