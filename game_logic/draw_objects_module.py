"""
draw_objects 함수 - bosspong.py에서 추출
2,724줄의 거대한 함수를 별도 모듈로 분리
"""

import pygame
import math
import random

def draw_objects():
    global quake_offset_y, rainbow_index, ball_trail, ball_angle
    global hit_animation_active, hit_animation_timer
    global boss_trail, long_boost_animating, long_boost_animation_step
    global long_boost_growing, long_boost_shrinking, long_boost_active
    global PADDLE_WIDTH
    global stage4_magnetic_active, boss_throwing, boss_throw_timer
    global tear_particles
    global hongryun_hit_count, HONGRYUN_MAX_HITS
    global walls  # 🆕 벽돌 변수 추가
    global boss_hit_animation_active, boss_hit_animation_timer  # 🆕 보스 충돌 애니메이션 변수 추가
    global power_smashing_trails, power_smashing_particles, mega_smashing_meteor_trail  # 🔥 파워스매싱 이펙트 변수 추가
    global perfect_timing_active, perfect_timing_frame_count, perfect_timing_window  # 🎯 퍼펙트 타이밍 변수 추가
    global perfect_timing_indicator_active, short_shot_counter_window
    global special_gauge  # 🆕 드라이브 게이지 확인용
    global grenade_shake_timer  # 💣 수류탄 화면 흔들림
    global shield_antenna_active, shield_antenna_timer, shield_antenna_cooldown
    global last_shield_time, shield_duration, shield_fade_alpha, shield_position
    global laser_cannon_angle, laser_charging, laser_cannon_active, laser_charge_start
    global player_stunned, player_stun_end_time, laser_beam_duration
    global last_laser_time, laser_rotating_mode
    global turret_angles, turret_missiles, last_missile_time
    global interceptors, interceptor_launch_time, interceptor_cooldown
    global interceptor_launching, interceptor_launch_queue, hangar_door_open, hangar_door_timer
    global player_missile_invulnerable_time  # 미사일 무적 시간
    new_tear_particles = []  # ✅ 함수 시작 시 초기화

    # 🎾 서브 대기 상태 UI (미니멀 디자인)
    if is_waiting_for_serve:
        pass
        # 시간 계산
        current_time = pygame.time.get_ticks()
        wait_time = current_time - waiting_start_time
        
        if is_player_serve:
            pass
            # 🟢 플레이어 서브 - 하단 미니멀 UI
            serve_font = pygame.font.Font("NanumSquareB.ttf", 24)
            info_font = pygame.font.Font("NanumSquareR.ttf", 16)
            
            # 간단한 텍스트만 표시
            serve_text = serve_font.render("Player Serve", True, (255, 255, 255))
            serve_rect = serve_text.get_rect(center=(WIDTH // 2, HEIGHT - 100))
            SCREEN.blit(serve_text, serve_rect)
            
            # 액센트 라인
            line_width = serve_rect.width + 20
            line_y = serve_rect.bottom + 5
            line_surface = pygame.Surface((line_width, 2), pygame.SRCALPHA)
            line_surface.fill((0, 200, 100))
            SCREEN.blit(line_surface, ((WIDTH - line_width) // 2, line_y))
            
            # 3초 후 자동 서브 카운트다운
            if wait_time >= 1000:
                remaining = max(0, 3000 - wait_time) // 1000
                if remaining > 0:
                    pass
                    countdown_text = info_font.render(f"SPACE ({remaining}s)", True, (200, 200, 200))
                else:
                    pass
                    countdown_text = info_font.render("Auto serve", True, (255, 255, 100))
            else:
                countdown_text = info_font.render("Press SPACE", True, (200, 200, 200))
            
            countdown_rect = countdown_text.get_rect(center=(WIDTH // 2, serve_rect.bottom + 20))
            SCREEN.blit(countdown_text, countdown_rect)
            
        else:
            pass
            # 🔴 보스 서브 - 상단 미니멀 UI
            serve_font = pygame.font.Font("NanumSquareB.ttf", 24)
            info_font = pygame.font.Font("NanumSquareR.ttf", 16)
            
            # 간단한 텍스트만 표시
            boss_name = boss_names.get(current_stage, "Boss")
            serve_text = serve_font.render(f"{boss_name} Serve", True, (255, 255, 255))
            serve_rect = serve_text.get_rect(center=(WIDTH // 2, 80))
            SCREEN.blit(serve_text, serve_rect)
            
            # 액센트 라인
            line_width = serve_rect.width + 20
            line_y = serve_rect.bottom + 5
            line_surface = pygame.Surface((line_width, 2), pygame.SRCALPHA)
            line_surface.fill((200, 80, 80))
            SCREEN.blit(line_surface, ((WIDTH - line_width) // 2, line_y))
            
            # 상태 텍스트
            if boss_fake_move and wait_delay > 0:
                remaining = max(0, wait_delay - wait_time) // 100
                if remaining > 0:
                    pass
                    status_text = info_font.render("Preparing...", True, (200, 200, 200))
                else:
                    pass
                    status_text = info_font.render("Ready", True, (255, 255, 100))
            else:
                status_text = info_font.render("Waiting...", True, (200, 200, 200))
            
            status_rect = status_text.get_rect(center=(WIDTH // 2, serve_rect.bottom + 20))
            SCREEN.blit(status_text, status_rect)

    # 🎯 퍼펙트 타이밍 윈도우 시각적 표시 (드라이브 가능 시 항상 유지)
    elif perfect_timing_indicator_active and special_gauge >= 150:
        pass
        # 공 주변에 퍼펙트 타이밍 인디케이터 그리기
        timing_alpha = 255
        timing_radius = 30 + int(5 * math.sin(pygame.time.get_ticks() * 0.2))
        
        # 반투명 원 그리기 - 파워스매싱 준비 상태에 따라 색상 변경
        timing_surface = pygame.Surface((timing_radius*2, timing_radius*2), pygame.SRCALPHA)
        if special_ready:
            pass
            # 파워스매싱 준비 상태일 때 - 빨간색 원
            pygame.draw.circle(timing_surface, (255, 80, 80, timing_alpha), (timing_radius, timing_radius), timing_radius, 3)
        else:
            pass
            # 일반 드라이브 상태일 때 - 노란색 원
            pygame.draw.circle(timing_surface, (255, 255, 0, timing_alpha), (timing_radius, timing_radius), timing_radius, 3)
        SCREEN.blit(timing_surface, (BALL.centerx - timing_radius, BALL.centery - timing_radius))
        
        # 텍스트 표시 - 파워스매싱 준비 상태에 따라 다르게 표시
        timing_font = pygame.font.Font("NanumSquareR.ttf", 24)
        if short_shot_counter_window > 0:
            timing_text = timing_font.render("Combo!", True, (255, 255, 0))
        elif special_ready:
            pass
            # 파워스매싱 준비 상태일 때 - 빨간색 SMASHING
            timing_text = timing_font.render("SMASHING", True, (255, 80, 80))
        else:
            pass
            # 일반 드라이브 상태일 때 - 노란색 Drive!
            timing_text = timing_font.render("Drive!", True, (255, 255, 0))
        text_rect = timing_text.get_rect(center=(BALL.centerx, BALL.centery - 50))
        SCREEN.blit(timing_text, text_rect)

    # 화면 흔들림 효과 계산
    quake_offset_y = random.randint(-5, 5) if quake_active else 0
    
    # 💣 수류탄 폭발 화면 흔들림
    grenade_offset_x = 0
    grenade_offset_y = 0
    if grenade_shake_timer > 0:
        pass
        # 흔들림 강도 계산 (시간이 지날수록 약해짐)
        intensity = grenade_shake_timer / 15.0
        grenade_offset_x = random.randint(-int(8 * intensity), int(8 * intensity))
        grenade_offset_y = random.randint(-int(6 * intensity), int(6 * intensity))
        grenade_shake_timer -= 1
    
    # 최종 화면 흔들림 오프셋
    total_offset_x = grenade_offset_x
    total_offset_y = quake_offset_y + grenade_offset_y

    # 화면 흔들림을 적용하여 오브젝트 그리기
    def draw_with_shake(surface, pos):
        """  화면 흔들림을 적용하여 그리기"""
        SCREEN.blit(surface, (pos[0] + total_offset_x, pos[1] + total_offset_y))
    
    def draw_rect_with_shake(color, rect, width=0):
        """ 화면 흔들림을 적용하여 사각형 그리기"""
        shaken_rect = pygame.Rect(rect.x + total_offset_x, rect.y + total_offset_y, rect.width, rect.height)
        draw.rect( color, shaken_rect, width)
    
    def draw_circle_with_shake(color, pos, radius, width=0):
        """  화면 흔들림을 적용하여 원 그리기"""
        draw.circle(color, (int(pos[0] + total_offset_x), int(pos[1] + total_offset_y)), radius, width)
    
    # === 보스 이미지 선택 + 스테이지별 전용 사이즈 적용 ===
    if new_boss_mode_active:
        pass
        # 🆕 새로운 보스 모드에서는 상단 보스 선택
        if selected_top_boss == 1:
            pass
            # 라이트닝 마스터 (임시로 stage3 이미지 사용 - 전기 속성)
            boss_img = BOSS_IMG_STAGE3
            boss_w, boss_h = BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT
        elif selected_top_boss == 2:
            pass
            # 아이스 퀸 (임시로 stage4 이미지 사용 - 얼음 속성)
            boss_img = BOSS_IMG_STAGE4
            boss_w, boss_h = BOSS_IMG_STAGE4_WIDTH, BOSS_IMG_STAGE4_HEIGHT
        else:
            boss_img = BOSS_IMG_STAGE1
            boss_w, boss_h = BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT
    elif current_stage == 1:
        boss_img = BOSS_IMG_STAGE1
        boss_w, boss_h = BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT
    elif current_stage == 2:
        boss_img = SPEED_DEFENSE_IMG if speed_defense_active else BOSS_IMG_STAGE2
        boss_w, boss_h = BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT
    elif current_stage == 3:
        boss_img = BOSS_IMG_STAGE3
        boss_w, boss_h = BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT
    elif current_stage == 4:
        boss_img = BOSS_IMG_STAGE4
        boss_w, boss_h = BOSS_IMG_STAGE4_WIDTH, BOSS_IMG_STAGE4_HEIGHT
    elif current_stage == 5:
        boss_img = BOSS_IMG_STAGE5
        boss_w, boss_h = BOSS_IMG_STAGE5_WIDTH, BOSS_IMG_STAGE5_HEIGHT
    elif current_stage == 6:
        pass
        # 🚢 스테이지 6: 항공모함 스타일 보스 (체력형)
        # 보스 속도 계산 (이전 위치와 현재 위치 차이)
        global boss_prev_x
        boss_current_speed = abs(BOSS.x - boss_prev_x) if boss_prev_x else 0
        boss_prev_x = BOSS.x
        boss_img = draw_aircraft_carrier_boss(boss_current_speed, BOSS.x)
        boss_w, boss_h = 220, 85  # 배틀크루저는 더 크고 위용있게
    else:
        boss_img = pygame.Surface((BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT), pygame.SRCALPHA)
        boss_img.fill((255, 255, 255))
        boss_w, boss_h = BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT

#     boss_img = pygame.transform.scale(boss_img, (boss_w, boss_h))

    # 🎭 풍악보이 상모돌리기 회전 효과
    whip_rotation_angle = 0
    if current_stage == 1 and whip_active:
        pass
        # 빠른 속도로 회전 (팽이처럼)
        rotation_speed = 15  # 회전 속도 (도/프레임)
        current_time = pygame.time.get_ticks()
        whip_rotation_angle = (current_time * rotation_speed / 16.67) % 360  # 60fps 기준
        boss_img = pygame.transform.rotate(boss_img, whip_rotation_angle)

    # === 보스 던지는 모션 ===
    boss_offset_y = 0
    tilt_angle_boss = 0
    if current_stage == 5 and boss_throwing:
        boss_offset_y = -10  # 살짝 위로 올림
        tilt_angle_boss = -15 if (pygame.time.get_ticks() // 100) % 2 == 0 else 15

    # 좌우 기울기 효과 제거 (사용자 요청)
    # elif not is_waiting_for_serve and not (current_stage == 2 and speed_defense_active):
    #     # 평상시 좌우 기울기
    #     if BOSS.x > WIDTH // 2:
    #         tilt_angle_boss = -10
    #     elif BOSS.x < WIDTH // 2:
    #         tilt_angle_boss = 10

    # === 보스 회전 처리 ===
    # 보스 패들 충돌 애니메이션 처리
    if boss_hit_animation_active:
        pass
        # 스테이지별 기본 지속시간 계산
        if current_stage == 1:
            pass
            base_duration = 5
        elif current_stage == 2:
            pass
            base_duration = 7
        elif current_stage == 3:
            pass
            base_duration = 8
        elif current_stage == 4:
            pass
            base_duration = 6
        elif current_stage == 5:
            pass
            base_duration = 9
        else:
            base_duration = BOSS_HIT_ANIMATION_DURATION
            
        progress = base_duration - boss_hit_animation_timer
        
        # 스테이지별 차별화된 충돌 애니메이션
        if current_stage == 1:
            pass
            # 스테이지 1: 부드러운 회전 (15도)
            hit_tilt_angle = 15 - (progress * 3)
        elif current_stage == 2:
            pass
            # 스테이지 2: 빠른 회전 (25도)
            hit_tilt_angle = 25 - (progress * 4)
        elif current_stage == 3:
            pass
            # 스테이지 3: 강한 회전 (30도)
            hit_tilt_angle = 30 - (progress * 4)
        elif current_stage == 4:
            pass
            # 스테이지 4: 중간 회전 (20도)
            hit_tilt_angle = 20 - (progress * 3)
        elif current_stage == 5:
            pass
            # 스테이지 5: 최강 회전 (35도)
            hit_tilt_angle = 35 - (progress * 4)
        else:
            pass
            # 기본값
            hit_tilt_angle = 20 - (progress * 3)
            
        boss_hit_animation_timer -= 1
        if boss_hit_animation_timer <= 0:
            boss_hit_animation_active = False
        tilt_angle_boss = hit_tilt_angle  # 충돌 애니메이션 우선 적용
    
    # 상모돌리기 중이거나 스피드디펜스 중일 때는 기울기 효과 제거
    if (current_stage == 1 and whip_active) or (current_stage == 2 and speed_defense_active):
        rotated_boss = boss_img.copy()
        boss_rect = rotated_boss.get_rect(center=(BOSS.centerx + screen_shake_offset_x, BOSS.centery + boss_offset_y + screen_shake_offset_y))
    else:
        pass
        # 원래 보스 회전 로직 (화면 흔들림 오프셋 적용)
        rotated_boss = pygame.Surface((boss_w, boss_h), pygame.SRCALPHA)
        rotated_boss.blit(boss_img, (0, 0))
        rotated_boss = pygame.transform.rotate(rotated_boss, tilt_angle_boss)
        boss_rect = rotated_boss.get_rect(center=(BOSS.centerx + screen_shake_offset_x, BOSS.centery + boss_offset_y + screen_shake_offset_y))

    # === Stage 2 스피드 디펜스 꼬리효과 ===
    if current_stage == 2 and speed_defense_active:
        pass
        # 원래 꼬리 효과 (매 프레임 추가) - 더 많은 잔상 추가
        boss_trail.append((BOSS.centerx, BOSS.centery, 255))
    
    # 꼬리 효과 알파값 감소 및 정리 (스피드 디펜스 활성화 여부와 관계없이 실행)
    boss_trail[:] = [(x, y, a-8) for x, y, a in boss_trail if a > 8]  # 더 천천히 사라지도록
    
    # 원래 꼬리 효과 렌더링 - 길게 늘어진 잔상 효과
    if boss_trail:
        for i, (x, y, alpha) in enumerate(boss_trail):
            # 잔상 크기를 점진적으로 줄이기
            scale_factor = 1.0 - (i * 0.02)  # 뒤로 갈수록 작아짐
            trail_width = int(BOSS_IMG_WIDTH * scale_factor)
            trail_height = int(BOSS_IMG_HEIGHT * scale_factor)
            
            if trail_width > 10 and trail_height > 10:  # 너무 작아지면 그리지 않음
                pass
#                 trail_img = pygame.transform.scale(SPEED_DEFENSE_IMG, (trail_width, trail_height))
                trail_img.set_alpha(alpha)
                trail_rect = trail_img.get_rect(center=(x, y))
                SCREEN.blit(trail_img, trail_rect.topleft)

    # === Stage 3 오버드라이브 꼬리 ===
    if current_stage == 3 and emotional_overdrive_active:
        for x, y, alpha in overdrive_trails:
#             trail = pygame.transform.scale(BOSS_IMG_STAGE3, (boss_w, boss_h))
            trail.set_alpha(alpha)
            trail_rect = trail.get_rect(center=(x, y))
            SCREEN.blit(trail, trail_rect.topleft)
        if overdrive_flash_timer < 15:
            apply_white_glow(rotated_boss, intensity=80)

    if current_stage == 3 and boss_special_ready and not emotional_overdrive_active:
        time_now = pygame.time.get_ticks()
        if (time_now // 250) % 2 == 0:
            apply_white_glow(rotated_boss, intensity=60)

    # === Stage 3 빨간 오버레이 ===
    if current_stage == 3 and boss_red_intensity > 0:
        rotated_boss_copy = rotated_boss.copy()
        apply_red_overlay(rotated_boss_copy, boss_red_intensity)
        SCREEN.blit(rotated_boss_copy, boss_rect.topleft)
    else:
        pass
        # 보스 충돌 시 빛나는 효과 추가 (파워스매싱 상태일 때만)
        if boss_hit_animation_active and boss_hit_animation_timer > BOSS_HIT_ANIMATION_DURATION - 3 and special_active:
            pass
            # 파워스매싱 충돌 직후 3프레임 동안 빛나는 효과
            glow_intensity = (BOSS_HIT_ANIMATION_DURATION - boss_hit_animation_timer) * 20
            apply_white_glow(rotated_boss, intensity=glow_intensity)
        draw_with_shake(rotated_boss, boss_rect.topleft)
    
    # === Stage 6 쉴드 안테나 그리기 (패들 위에 직접) ===
    if current_stage == 6:
        pass
        # 왼쪽 안테나 (패들 왼쪽)
        antenna_left_x = BOSS.left + 20
        antenna_left_y = BOSS.centery
        
        # 안테나 기둥
        draw.rect((110, 120, 130), 
                        (antenna_left_x - 2, antenna_left_y - 10, 4, 20))
        # 안테나 베이스
        draw.circle((140, 150, 160), 
                          (antenna_left_x, antenna_left_y), 5)
        # 안테나 끝 발광체
        antenna_tip_y = antenna_left_y - 15
        draw.circle((200, 210, 220), 
                          (antenna_left_x, antenna_tip_y), 4)
        if shield_antenna_active:
            pass
            # 활성화시 빛나는 효과
            draw.circle((255, 255, 255), 
                              (antenna_left_x, antenna_tip_y), 3)
            # 빛나는 파티클
            for _ in range(2):
                spark_offset = random.randint(-5, 5)
                draw.circle((200, 220, 255), 
                                  (antenna_left_x + spark_offset, antenna_tip_y + random.randint(-3, 3)), 1)
        
        # 오른쪽 안테나 (패들 오른쪽)
        antenna_right_x = BOSS.right - 20
        antenna_right_y = BOSS.centery
        
        # 안테나 기둥
        draw.rect((110, 120, 130), 
                        (antenna_right_x - 2, antenna_right_y - 10, 4, 20))
        # 안테나 베이스
        draw.circle((140, 150, 160), 
                          (antenna_right_x, antenna_right_y), 5)
        # 안테나 끝 발광체
        antenna_tip_y = antenna_right_y - 15
        draw.circle((200, 210, 220), 
                          (antenna_right_x, antenna_tip_y), 4)
        if shield_antenna_active:
            pass
            # 활성화시 빛나는 효과
            draw.circle((255, 255, 255), 
                              (antenna_right_x, antenna_tip_y), 3)
            # 빛나는 파티클
            for _ in range(2):
                spark_offset = random.randint(-5, 5)
                draw.circle((200, 220, 255), 
                                  (antenna_right_x + spark_offset, antenna_tip_y + random.randint(-3, 3)), 1)
    
    # 🎯 보스 확장 히트박스 디버그 표시 (개발용)
    DEBUG_SHOW_HITBOX = False  # True로 변경하면 히트박스가 보임
    if DEBUG_SHOW_HITBOX:
        pass
        # 스테이지 6에서만 확장된 히트박스 표시
        if current_stage == 6:
            pass
            # 확장된 히트박스 그리기 (반투명 빨간색)
            boss_hitbox_expanded = pygame.Rect(
                BOSS.x - BOSS.width // 2,  # 왼쪽으로 절반 폭만큼 확장
                BOSS.y,  # y 위치는 그대로
                BOSS.width * 2,  # 너비를 2배로
                BOSS.height  # 높이는 그대로
            )
            hitbox_surface = pygame.Surface((boss_hitbox_expanded.width, boss_hitbox_expanded.height), pygame.SRCALPHA)
            hitbox_surface.fill((255, 0, 0, 50))  # 반투명 빨간색
            SCREEN.blit(hitbox_surface, boss_hitbox_expanded.topleft)
            
            # 히트박스 테두리 (실선)
            draw.rect((255, 0), boss_hitbox_expanded, 2)
        
        # 원본 보스 패들 크기 표시 (파란색) - 모든 스테이지
        draw.rect((0, 0, 255), BOSS, 2)
    
    # 🌀 스턴 시 머리 위 빙글빙글 도는 별 효과 (작게, 머리 위로)
    if boss_stunned_timer > 0:
        pass
        # 별 3개가 머리 위에서 회전
        # 프레임 기반 회전 (스턴 타이머를 이용)
        rotation_angle = (60 - boss_stunned_timer) * 6  # 스턴 타이머를 이용한 회전 (6도씩)
        num_stars = 3
        radius = 20  # 회전 반경 (25 → 20)
        
        for i in range(num_stars):
            # 각 별의 회전 각도
            angle = (rotation_angle + i * (360 / num_stars)) % 360
            angle_rad = math.radians(angle)
            
            # 별 위치 (보스 머리 위 - 더 아래로)
            star_x = BOSS.centerx + radius * math.cos(angle_rad)
            star_y = BOSS.top - 15 + radius * math.sin(angle_rad) * 0.5  # 더 아래로 조정 (25 → 15)
            
            # 별 그리기 (더 작게)
            star_size = 8  # 12 → 8로 축소
            star_points = []
            for j in range(10):
                angle_star = j * 36 - 90
                angle_star_rad = math.radians(angle_star)
                if j % 2 == 0:
                    pass
                    # 바깥쪽 점
                    px = star_x + star_size * math.cos(angle_star_rad)
                    py = star_y + star_size * math.sin(angle_star_rad)
                else:
                    pass
                    # 안쪽 점
                    px = star_x + (star_size * 0.4) * math.cos(angle_star_rad)
                    py = star_y + (star_size * 0.4) * math.sin(angle_star_rad)
                star_points.append((px, py))
            
            # 별 색상 (노란색 계열)
            star_color = (255, 255, 100)
            draw.polygon(star_color, star_points, 0)
            draw.polygon((255, 200, 0), star_points, 1)  # 얇은 테두리
            
            # 별 글로우 효과
            glow_surface = pygame.Surface((star_size * 3, star_size * 3), pygame.SRCALPHA)
            pygame.draw.circle(glow_surface, (255, 255, 100, 60), 
                             (star_size * 1.5, star_size * 1.5), star_size)
            SCREEN.blit(glow_surface, (star_x - star_size * 1.5, star_y - star_size * 1.5))

    # === Stage 4 자기장 이펙트 ===
    if current_stage == 4 and stage4_magnetic_active:
        magnetic_surface = pygame.Surface((260, 260), pygame.SRCALPHA)
        
        # 기본 자기장 원
        pygame.draw.circle(magnetic_surface, (100, 200, 255, 80), (130, 130), 130, width=6)
        pygame.draw.circle(magnetic_surface, (180, 220, 255, 50), (130, 130), 80, width=0)
        
        # 전기 이펙트 - 번개 모양의 선들
        electric_time = pygame.time.get_ticks()
        num_bolts = 8  # 전기 번개 개수
        
        for i in range(num_bolts):
            # 각 번개의 시작과 끝 각도
            start_angle = (electric_time * 0.002 + i * (360 / num_bolts)) % 360
            end_angle = start_angle + random.randint(30, 90)
            
            # 내부와 외부 반경 사이를 오가는 번개
            inner_radius = 60 + random.randint(-10, 10)
            outer_radius = 120 + random.randint(-10, 10)
            
            # 시작점과 끝점 계산
            start_x = 130 + inner_radius * math.cos(math.radians(start_angle))
            start_y = 130 + inner_radius * math.sin(math.radians(start_angle))
            end_x = 130 + outer_radius * math.cos(math.radians(end_angle))
            end_y = 130 + outer_radius * math.sin(math.radians(end_angle))
            
            # 중간 지점들 (지그재그 효과)
            mid_points = []
            num_segments = 3
            for j in range(1, num_segments):
                t = j / num_segments
                mid_x = start_x + (end_x - start_x) * t + random.randint(-15, 15)
                mid_y = start_y + (end_y - start_y) * t + random.randint(-15, 15)
                mid_points.append((mid_x, mid_y))
            
            # 전기 색상 (밝은 청백색)
            electric_alpha = 180 + random.randint(-30, 30)
            electric_color = (150 + random.randint(0, 105), 200 + random.randint(0, 55), 255, electric_alpha)
            
            # 번개 그리기 (메인 라인)
            points = [(start_x, start_y)] + mid_points + [(end_x, end_y)]
            for k in range(len(points) - 1):
                pygame.draw.line(magnetic_surface, electric_color, points[k], points[k+1], 2)
            
            # 글로우 효과 (더 굵고 투명한 선)
            glow_color = (100, 150, 255, electric_alpha // 3)
            for k in range(len(points) - 1):
                pygame.draw.line(magnetic_surface, glow_color, points[k], points[k+1], 4)
        
        # 펄스 효과 (주기적으로 밝아짐)
        pulse = abs(math.sin(electric_time * 0.005)) * 0.5 + 0.5
        if pulse > 0.8:  # 주기적으로 강한 번쩍임
            flash_surface = pygame.Surface((260, 260), pygame.SRCALPHA)
            pygame.draw.circle(flash_surface, (200, 230, 255, int(40 * pulse)), (130, 130), 130, width=0)
            magnetic_surface.blit(flash_surface, (0, 0))
        
        SCREEN.blit(magnetic_surface, (BOSS.centerx - 130, BOSS.centery - 130))

    # === 롱부스트 애니메이션 처리 (레거시 코드 - 새로운 점진적 크기 변화로 대체됨) ===

    # === 플레이어 이미지 (새로운 보스 모드 고려) ===
    if new_boss_mode_active:
        pass
        # 🆕 새로운 보스 모드에서는 하단 보스 이미지 사용
        try:
            if selected_bottom_boss == 1:
                pass
                # 파이어 나이트 이미지 (임시로 stage1 이미지 사용, 나중에 별도 이미지 추가 가능)
# #                 boss_img = pygame.image.load("boss_stage1.png").convert_alpha()
                # 화염 속성 느낌으로 빨간색 틴트 적용
#                 base_ufo_img = pygame.transform.scale(boss_img, (250, 100))
                pass
            elif selected_bottom_boss == 2:
                pass
                # 윈드 스피릿 이미지 (임시로 stage2 이미지 사용, 나중에 별도 이미지 추가 가능)
# #                 boss_img = pygame.image.load("boss_stage2.png").convert_alpha()
                # 바람 속성 느낌으로 사용
#                 base_ufo_img = pygame.transform.scale(boss_img, (250, 100))
            else:
                pass
                base_ufo_img = PLAYER_IMG
        except:
            # 이미지 로드 실패 시 기본 플레이어 이미지 사용
            base_ufo_img = PLAYER_IMG
    else:
        pass
        # 일반 모드에서는 UFO 플레이어 이미지 사용
        base_ufo_img = PLAYER_IMG
    
    # 스킬 효과 적용: 패들 크기 증가
    skill_boosted_width = skill.apply_paddle_size_boost(PADDLE_WIDTH)
    scale_ratio = skill_boosted_width / 155
    
    # 🍄 거대화포션 효과 적용 (점진적 크기 변화)
    scale_ratio *= long_boost_scale
    
    if scale_ratio != 1.0:
        new_width = int(base_ufo_img.get_width() * scale_ratio)
        new_height = int(base_ufo_img.get_height() * scale_ratio)
#         base_ufo_img = pygame.transform.scale(base_ufo_img, (new_width, new_height))

    keys = pygame.key.get_pressed()
    tilt_angle = 0
    if hit_animation_active:
        progress = HIT_ANIMATION_DURATION - hit_animation_timer
        tilt_angle = -20 + (progress * 7)
        hit_animation_timer -= 1
        if hit_animation_timer <= 0:
            pass
            hit_animation_active = False
    else:
        if keys[pygame.K_LEFT] or keys[pygame.K_a]:
            pass
            tilt_angle = 10
        elif keys[pygame.K_RIGHT] or keys[pygame.K_d]:
            tilt_angle = -10

    # 🔥💣💡 투척 모션 중일 때 특별한 회전 각도 적용
    if molotov_throwing or grenade_throwing or flare_throwing:
        throw_progress = 0
        if molotov_throwing:
            pass
            throw_progress = 1.0 - (molotov_throw_timer / 30.0)  # 0에서 1로 진행
        elif grenade_throwing:
            pass
            throw_progress = 1.0 - (grenade_throw_timer / 30.0)  # 0에서 1로 진행
        elif flare_throwing:
            throw_progress = 1.0 - (flare_throw_timer / 30.0)  # 0에서 1로 진행
        
        # 투척 모션: UFO가 뒤로 젖혔다가 앞으로 던지는 동작
        if throw_progress < 0.3:
            pass
            # 준비 단계: 뒤로 젖히기
            tilt_angle = 30 * (throw_progress / 0.3)
        elif throw_progress < 0.7:
            pass
            # 유지 단계
            tilt_angle = 30
        else:
            pass
            # 투척 단계: 앞으로 던지기
            tilt_angle = 30 - 50 * ((throw_progress - 0.7) / 0.3)
    
    rotated_player = pygame.transform.rotate(base_ufo_img, tilt_angle).copy()
    
    # 🎭 보스 vs 보스전과 🆕 새로운 보스전에서는 빨간 효과 제거 (게이지를 사용하지 않음)
    if not new_boss_mode_active:
        if not special_active and red_intensity > 0:
            apply_red_overlay(rotated_player, red_intensity)
        
        # 🆕 눈물샤워 디버프 시 파란색 변색 효과
        if player_slow_timer > 0:
            apply_blue_overlay(rotated_player, intensity=120)
    
    # 🏃 대쉬 잔상 효과 그리기
    global dash_afterimages, rolling_active, rolling_timer, rolling_direction

    legacy_state = globals().get("LEGACY_STATE")
    rolling_state = getattr(legacy_state, "rolling", None) if legacy_state else None

    if rolling_state is not None:
        rolling_active_flag = rolling_state.active
        rolling_timer_value = rolling_state.timer
    else:
        rolling_active_flag = rolling_active
        rolling_timer_value = rolling_timer

    # 대쉬 중일 때 잔상 추가
    if rolling_active_flag and rolling_timer_value > 0:
        # 대쉬 방향에 따른 잔상 생성 위치
        afterimage_x = PLAYER.centerx
        afterimage_y = PLAYER.centery
        
        # 잔상 이미지 생성 (현재 회전된 이미지 복사)
        afterimage = rotated_player.copy()
        
        # 잔상 투명도 설정 (대쉬 진행도에 따라 조절)
        alpha = min(180, int(180 * (rolling_timer_value / 15)))  # 최대 180 투명도
        
        # 잔상 리스트에 추가 (최대 5개 유지)
        dash_afterimages.append({
            'x': afterimage_x,
            'y': afterimage_y, 
            'alpha': alpha,
            'image': afterimage,
            'life': 10  # 잔상 지속 시간
        })
        
        # 잔상 개수 제한
        if len(dash_afterimages) > 5:
            dash_afterimages.pop(0)
    
    # 잔상 그리기 및 업데이트
    new_afterimages = []
    for afterimage in dash_afterimages:
        # 잔상 투명도 적용
        afterimage_surf = afterimage['image'].copy()
        afterimage_surf.set_alpha(afterimage['alpha'])
        
        # 잔상 위치 계산 (점점 뒤로 밀림)
        afterimage_rect = afterimage_surf.get_rect(center=(afterimage['x'], afterimage['y']))
        
        # 잔상 그리기
        SCREEN.blit(afterimage_surf, afterimage_rect.topleft)
        
        # 잔상 업데이트
        afterimage['alpha'] -= 25  # 투명도 감소
        afterimage['life'] -= 1
        
        # 아직 살아있는 잔상만 유지
        if afterimage['alpha'] > 0 and afterimage['life'] > 0:
            new_afterimages.append(afterimage)
    
    dash_afterimages = new_afterimages
    
    # UFO 이미지 그리기 (화면 흔들림 오프셋 적용)
    player_rect = rotated_player.get_rect(center=(PLAYER.centerx + screen_shake_offset_x, PLAYER.centery + screen_shake_offset_y))
    
    # 🎯 스킬 인디케이터 UI 그리기 (패들 아래)
    if not new_boss_mode_active:  # 일반 모드에서만 표시
        pass
        # 스킬 게이지 계산
        skill_gauge_ratio = min(1.0, special_gauge / special_gauge_max)
        
        # 스킬 인디케이터는 표시하지 않음 (UI 정리)
    
    # 미사일 무적 시간 체크
    time_now = pygame.time.get_ticks()
    is_missile_invulnerable = time_now < player_missile_invulnerable_time
    
    # UFO 이미지 그리기 (깜빡임 효과 적용 - 최적화 버전)
    if special_ready:
        if (time_now // 250) % 2 == 0:
            pass
            # 🚀 성능 최적화: 블렌딩 모드를 사용한 깜빡임 효과
            bright_ufo = rotated_player.copy()
            # 밝기 오버레이 생성
            bright_overlay = pygame.Surface(bright_ufo.get_size(), pygame.SRCALPHA)
            bright_overlay.fill((100, 100, 100, 128))  # 밝기 오버레이
            # 블렌딩 모드로 효율적으로 밝기 적용
            bright_ufo.blit(bright_overlay, (0, 0), special_flags=pygame.BLEND_ADD)
            # 미사일 무적 시간이면 반투명 처리
            if is_missile_invulnerable and (time_now // 100) % 2 == 0:
                bright_ufo.set_alpha(100)
            draw_with_shake(bright_ufo, player_rect.topleft)
        else:
            player_to_draw = rotated_player.copy()
            # 미사일 무적 시간이면 반투명 처리
            if is_missile_invulnerable and (time_now // 100) % 2 == 0:
                player_to_draw.set_alpha(100)
            draw_with_shake(player_to_draw, player_rect.topleft)
    else:
        player_to_draw = rotated_player.copy()
        # 미사일 무적 시간이면 반투명 처리
        if is_missile_invulnerable and (time_now // 100) % 2 == 0:
            player_to_draw.set_alpha(100)
        draw_with_shake(player_to_draw, player_rect.topleft)
    
    # 🔥💣💡 투척 모션 중 아이템 표시
    if molotov_throwing or grenade_throwing or flare_throwing:
        throw_progress = 0
        item_icon = None
        
        if molotov_throwing:
            throw_progress = 1.0 - (molotov_throw_timer / 30.0)
            try:
                pass  # 빈 try 블록 수정
#                 item_icon = pygame.image.load("items/molotov.png").convert_alpha()
#                 item_icon = pygame.transform.scale(item_icon, (40, 40))
            except:
                # 화염병 기본 아이콘
                item_icon = pygame.Surface((40, 40), pygame.SRCALPHA)
                pygame.draw.circle(item_icon, (255, 100, 0), (20, 20), 15)
                
        elif grenade_throwing:
            throw_progress = 1.0 - (grenade_throw_timer / 30.0)
            try:
                pass  # 빈 try 블록 수정
#                 item_icon = pygame.image.load("items/grenade.png").convert_alpha()
#                 item_icon = pygame.transform.scale(item_icon, (40, 40))
            except:
                # 수류탄 기본 아이콘
                item_icon = pygame.Surface((40, 40), pygame.SRCALPHA)
                pygame.draw.circle(item_icon, (100, 150, 100), (20, 20), 15)
                
        elif flare_throwing:
            throw_progress = 1.0 - (flare_throw_timer / 30.0)
            try:
                pass  # 빈 try 블록 수정
#                 item_icon = pygame.image.load("items/flare.png").convert_alpha()
#                 item_icon = pygame.transform.scale(item_icon, (40, 40))
            except:
                # 조명탄 기본 아이콘
                item_icon = pygame.Surface((40, 40), pygame.SRCALPHA)
                pygame.draw.circle(item_icon, (255, 255, 200), (20, 20), 15)
        
        # 연막탄은 즉시 발동으로 변경되어 투척 모션 제거됨
        
        if item_icon:
            pass
            # 투척 모션에 따른 아이템 위치 계산
            if throw_progress < 0.7:
                pass
                # 준비 및 유지 단계: UFO 위에 아이템 표시
                item_x = PLAYER.centerx + screen_shake_offset_x
                item_y = PLAYER.centery - 30 + screen_shake_offset_y
                # 아이템도 같이 회전
                item_angle = tilt_angle
            else:
                pass
                # 투척 단계: 아이템이 앞으로 날아가는 효과
                throw_distance = ((throw_progress - 0.7) / 0.3) * 50
                item_x = PLAYER.centerx + screen_shake_offset_x
                item_y = PLAYER.centery - 30 - throw_distance + screen_shake_offset_y
                item_angle = -30
            
            # 아이템 회전 및 그리기
            rotated_item = pygame.transform.rotate(item_icon, item_angle)
            item_rect = rotated_item.get_rect(center=(item_x, item_y))
            SCREEN.blit(rotated_item, item_rect.topleft)

    # 수류탄 그리기
    for grenade in grenades:
        # 회전된 수류탄 아이콘 그리기
        try:
            pass  # Empty try block fix
# #             icon = pygame.image.load("items/grenade.png").convert_alpha()
#             icon = pygame.transform.scale(icon, (36, 36))  # 화염병보다 약간 크게
            rotated_icon = pygame.transform.rotate(icon, grenade["rotation"])
            icon_rect = rotated_icon.get_rect(center=(grenade["x"], grenade["y"]))
            SCREEN.blit(rotated_icon, icon_rect)
        except:
            # 기본 원형 그리기
            draw.circle((80, 100, 80), (int(grenade["x"]), int(grenade["y"])), 12)
    
    # 현실감 있는 수류탄 폭발 효과 그리기
    for zone in explosion_zones:
        if zone["active"]:
            pass
            # 폭발 사이즈 계산 (시간에 따라 포다짐)
            explosion_surface = pygame.Surface((zone["radius"]*3, zone["radius"]*3), pygame.SRCALPHA)
            center = zone["radius"] * 1.5
            
            # 1. 충격파 효과 (가장 바깥쪽)
            shockwave_radius = zone["radius"] + (15 - zone["duration"]) * 8
            if shockwave_radius < zone["radius"] * 2.5:
                pygame.draw.circle(explosion_surface, (255, 255, 255, 30), 
                                 (int(center), int(center)), int(shockwave_radius), 4)
            
            # 2. 폭발 화염 구체 (주황색-빨간색 그라데이션)
            for i in range(zone["radius"], 0, -3):
                progress = (15 - zone["duration"]) / 15.0
                
                # 시간에 따라 색상 변화
                ratio = i / max(zone["radius"], 1)
                if zone["duration"] > 10:  # 초기: 흰색-노란색
                    r = 255
                    g = int(255 - (1 - ratio) * 100)
                    b = int(200 - (1 - ratio) * 150)
                elif zone["duration"] > 5:  # 중반: 주황색-빨간색
                    r = 255
                    g = int(150 - (1 - ratio) * 100)
                    b = int(50 - (1 - ratio) * 40)
                else:  # 후반: 빨간색-검은색
                    r = int(200 - (1 - ratio) * 100)
                    g = int(50 - (1 - ratio) * 40)
                    b = 30
                
                # 색상 값이 유효한 범위에 있도록 보장
                r = max(0, min(255, r))
                g = max(0, min(255, g))
                b = max(0, min(255, b))
                alpha = max(0, min(255, int((200 * zone["duration"] / 15) * ratio)))
                color = (r, g, b, alpha)
                pygame.draw.circle(explosion_surface, color, (int(center), int(center)), i)
            
            # 3. 연기 효과 (회색 구름)
            smoke_radius = zone["radius"] * 0.8 + (15 - zone["duration"]) * 4
            smoke_alpha = max(0, 100 - (15 - zone["duration"]) * 6)
            for j in range(3):  # 여러 개의 연기 구름
                offset_x = random.randint(-20, 20)
                offset_y = random.randint(-20, 20)
                pygame.draw.circle(explosion_surface, (80, 80, 80, smoke_alpha), 
                                 (int(center + offset_x), int(center + offset_y - (15 - zone["duration"]) * 2)), 
                                 int(smoke_radius + random.randint(-10, 10)), 0)
            
            # 4. 섬광 효과 (랜덤 방향으로 퍼지는 빛)
            if zone["duration"] > 10:
                num_sparks = 8
                for k in range(num_sparks):
                    angle = (k * 360 / num_sparks) + random.randint(-20, 20)
                    spark_length = zone["radius"] * 0.7 + random.randint(-10, 10)
                    spark_end_x = center + spark_length * math.cos(math.radians(angle))
                    spark_end_y = center + spark_length * math.sin(math.radians(angle))
                    pygame.draw.line(explosion_surface, (255, 255, 200, 150), 
                                   (int(center), int(center)), 
                                   (int(spark_end_x), int(spark_end_y)), 2)
            
            SCREEN.blit(explosion_surface, (zone["x"] - center, zone["y"] - center))
    
    # 연막탄 그리기
    for smoke_grenade in smoke_grenades:
        if smoke_grenade["arrived"]:
            pass
            # 도착 후 대기 중인 연막탄 (바닥에 있음)
            if smoke_grenade["timer"] < 60:
                pass
                # 땅에 떨어진 연막탄 그림자
                shadow_rect = pygame.Rect(smoke_grenade["x"] - 15, smoke_grenade["y"] - 3, 30, 6)
                draw.ellipse( (0, 0, 0, 100), shadow_rect)
                
                # 깜빡이는 효과 (빨간 LED)
                if smoke_grenade["timer"] % 15 < 8:
                    draw.circle((255, 0, 0), 
                                     (int(smoke_grenade["x"]), int(smoke_grenade["y"] - 5)), 3)
                
                # 연막탄 본체
                try:
                    pass  # Empty try block fix
# #                     icon = pygame.image.load("items/smoke_grenade.png").convert_alpha()
#                     icon = pygame.transform.scale(icon, (28, 28))
                    icon_rect = icon.get_rect(center=(smoke_grenade["x"], smoke_grenade["y"] - 5))
                    SCREEN.blit(icon, icon_rect)
                except:
                    draw.circle((100, 100, 100), 
                                     (int(smoke_grenade["x"]), int(smoke_grenade["y"] - 5)), 10)
        else:
            pass
            # 날아가는 중인 연막탄
            # 궤적 그리기
            if "trail" in smoke_grenade:
                for i, pos in enumerate(smoke_grenade["trail"]):
                    alpha = int(255 * (i / len(smoke_grenade["trail"])) * 0.3)
                    draw.circle( (150, 150, 150, alpha), 
                                     (int(pos[0]), int(pos[1])), 2)
            
            # 연막탄 본체
            try:
                pass  # Empty try block fix
# #                 icon = pygame.image.load("items/smoke_grenade.png").convert_alpha()
#                 icon = pygame.transform.scale(icon, (32, 32))
                rotated_icon = pygame.transform.rotate(icon, smoke_grenade["rotation"])
                icon_rect = rotated_icon.get_rect(center=(smoke_grenade["x"], smoke_grenade["y"]))
                SCREEN.blit(rotated_icon, icon_rect)
            except:
                # 기본 원형 그리기
                draw.circle((150, 150, 150), 
                                 (int(smoke_grenade["x"]), int(smoke_grenade["y"])), 10)
    
    # 연막 지역 그리기
    for smoke_zone in smoke_zones:
        if smoke_zone["opacity"] > 0:
            pass
            # 연막 파티클 그리기
            for particle in smoke_zone["particles"]:
                # 파티클 투명도 계산
                particle_alpha = min(smoke_zone["opacity"], 
                                   int(smoke_zone["opacity"] * (particle["lifetime"] / 80)))
                
                # 연막 파티클 그리기 (회색 연기)
                smoke_surface = pygame.Surface((int(particle["size"] * 2), int(particle["size"] * 2)), 
                                              pygame.SRCALPHA)
                
                # 그라데이션 효과를 위한 여러 레이어
                for i in range(3):
                    layer_size = particle["size"] - i * (particle["size"] / 4)
                    if layer_size > 0:
                        layer_alpha = particle_alpha // (i + 1)
                        color = (120 + i * 20, 120 + i * 20, 120 + i * 20, layer_alpha)
                        pygame.draw.circle(smoke_surface, color,
                                         (int(particle["size"]), int(particle["size"])),
                                         int(layer_size))
                
                SCREEN.blit(smoke_surface, 
                           (particle["x"] - particle["size"], particle["y"] - particle["size"]))
            
            # 연막 영역 표시 제거 (원형 경계선 삭제)
    
    # 조명탄 그리기
    for flare in flares:
        # 도착 후 대기 중인 조명탄 표시
        if flare.get("arrived", False) and not flare["exploded"]:
            pass
            # 깜빡이는 효과만 표시 (카운트다운 없음)
            if flare["timer"] % 10 < 5:
                draw.circle((255, 255, 100), 
                                 (int(flare["x"]), int(flare["y"])), 12)
            draw.circle((255, 200, 0), 
                             (int(flare["x"]), int(flare["y"])), 8, 2)
        else:
            pass
            # 날아가는 중인 조명탄
            try:
                pass  # Empty try block fix
# #                 icon = pygame.image.load("items/flare.png").convert_alpha()
#                 icon = pygame.transform.scale(icon, (32, 32))
                rotated_icon = pygame.transform.rotate(icon, flare["rotation"])
                icon_rect = rotated_icon.get_rect(center=(flare["x"], flare["y"]))
                SCREEN.blit(rotated_icon, icon_rect)
            except:
                # 기본 원형 그리기
                draw.circle((255, 255, 200), (int(flare["x"]), int(flare["y"])), 10)
    
    # 조명 지대 그리기 (섬광 효과)
    for zone in flare_zones:
        if zone.get("flash", False):
            pass
            # 섬광 효과: 매우 밝고 강렬한 빛
            if zone["duration"] > 0:
                pass
                # 화면 전체를 밝게 만드는 효과
                flash_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
                flash_alpha = int(180 * zone["intensity"])  # 더 강한 섬광
                flash_surface.fill((255, 255, 230, flash_alpha))
                SCREEN.blit(flash_surface, (0, 0))
                
                # 폭발 중심부 강렬한 빛
                for i in range(5):  # 더 많은 레이어로 강렬함 표현
                    radius = zone["radius"] * (1 - i * 0.15)
                    alpha = int(255 * zone["intensity"] * (1 - i * 0.2))
                    if alpha > 0:
                        light_surface = pygame.Surface((int(radius * 2), int(radius * 2)), pygame.SRCALPHA)
                        # 흰색에 가까운 밝은 빛
                        color = (255, 255, 240, min(255, alpha))
                        pygame.draw.circle(light_surface, color, 
                                         (int(radius), int(radius)), int(radius))
                        SCREEN.blit(light_surface, (zone["x"] - radius, zone["y"] - radius))
                
                # 번쩍이는 십자 섬광
                if zone["intensity"] > 0.7:
                    cross_length = zone["radius"] * 2
                    cross_width = 5
                    draw.line((255, 255, 255), 
                                   (zone["x"] - cross_length, zone["y"]), 
                                   (zone["x"] + cross_length, zone["y"]), cross_width)
                    draw.line((255, 255, 255), 
                                   (zone["x"], zone["y"] - cross_length), 
                                   (zone["x"], zone["y"] + cross_length), cross_width)
        else:
            pass
            # 일반 조명 효과 (기존 코드)
            for i in range(3):
                radius = zone["radius"] * (1 - i * 0.2)
                alpha = int(100 * zone["intensity"] * (1 - i * 0.3))
                if alpha > 0:
                    light_surface = pygame.Surface((int(radius * 2), int(radius * 2)), pygame.SRCALPHA)
                    color = (255, 255, 200, alpha)
                    pygame.draw.circle(light_surface, color, 
                                     (int(radius), int(radius)), int(radius))
                    SCREEN.blit(light_surface, (zone["x"] - radius, zone["y"] - radius))
    
    # 보스 혼란 상태 표시 (물음표가 빙글빙글)
    if boss_confused_timer > 0:
        pass
        # 회전 각도 계산 (시간에 따라 빙글빙글)
        rotation_speed = 0.005  # 회전 속도
        current_time = pygame.time.get_ticks()
        
        # 물음표 폰트 설정
        try:
            question_font = pygame.font.Font("NanumSquareB.ttf", 28)
        except:
            question_font = pygame.font.Font(None, 28)
        
        # 3개의 물음표가 보스 주위를 빙글빙글 돌기
        num_questions = 3
        orbit_radius = 40  # 회전 반경
        
        for i in range(num_questions):
            # 각 물음표의 각도 계산 (균등하게 배치)
            angle = current_time * rotation_speed + (i * 2 * math.pi / num_questions)
            
            # 물음표 위치 계산 (원형 궤도)
            x = BOSS.centerx + orbit_radius * math.cos(angle)
            y = BOSS.centery - 25 + orbit_radius * math.sin(angle) * 0.5  # Y축은 타원형으로
            
            # 물음표 크기 변화 (앞뒤 구분)
            size_factor = 0.8 + 0.2 * math.sin(angle)  # 0.8 ~ 1.0 사이 변화
            
            # 물음표 색상 (깜빡이는 효과)
            if math.sin(current_time * 0.01 + i) > 0:
                pass
                color = (255, 255, 100)  # 밝은 노란색
            else:
                color = (255, 200, 50)   # 어두운 노란색
            
            # 물음표 그리기
            question_text = question_font.render("?", True, color)
            
            # 크기 조절
            scaled_width = int(question_text.get_width() * size_factor)
            scaled_height = int(question_text.get_height() * size_factor)
            if scaled_width > 0 and scaled_height > 0:
                pass
#                 scaled_question = pygame.transform.scale(question_text, (scaled_width, scaled_height))
                question_rect = scaled_question.get_rect(center=(int(x), int(y)))
                
                # 그림자 효과
                shadow_color = (50, 50, 0)
                shadow_text = question_font.render("?", True, shadow_color)
#                 scaled_shadow = pygame.transform.scale(shadow_text, (scaled_width, scaled_height))
                shadow_rect = scaled_shadow.get_rect(center=(int(x + 2), int(y + 2)))
                SCREEN.blit(scaled_shadow, shadow_rect)
                
                # 물음표 본체
                SCREEN.blit(scaled_question, question_rect)
        
        # 중앙에 큰 물음표 효과 추가 (추가 시각 효과)
        center_angle = current_time * rotation_speed * 2  # 더 빠르게 회전
        
        # 중앙 물음표 폰트 (더 크게)
        try:
            center_question_font = pygame.font.Font("NanumSquareB.ttf", 45)
        except:
            center_question_font = pygame.font.Font(None, 45)
        
        # 물음표 색상 (깜빡이는 효과)
        if math.sin(current_time * 0.015) > 0:
            pass
            center_color = (255, 255, 150)  # 밝은 노란색
        else:
            center_color = (255, 220, 100)   # 약간 어두운 노란색
        
        # 중앙 물음표 그리기 (회전 효과)
        center_question_text = center_question_font.render("?", True, center_color)
        
        # 회전 적용
        rotation_angle = math.degrees(center_angle)
        rotated_question = pygame.transform.rotate(center_question_text, rotation_angle)
        
        # 중앙에 위치
        question_rect = rotated_question.get_rect(center=(BOSS.centerx, BOSS.centery - 25))
        
        # 그림자 효과
        shadow_color = (100, 100, 50)
        shadow_text = center_question_font.render("?", True, shadow_color)
        rotated_shadow = pygame.transform.rotate(shadow_text, rotation_angle)
        shadow_rect = rotated_shadow.get_rect(center=(BOSS.centerx + 3, BOSS.centery - 22))
        SCREEN.blit(rotated_shadow, shadow_rect)
        
        # 물음표 본체
        SCREEN.blit(rotated_question, question_rect)
    
    # 화염병 그리기
    for molotov in molotovs:
        # 회전된 화염병 아이콘 그리기
        try:
            pass  # Empty try block fix
# #             icon = pygame.image.load("items/molotov.png").convert_alpha()
#             icon = pygame.transform.scale(icon, (32, 32))
            rotated_icon = pygame.transform.rotate(icon, molotov["rotation"])
            icon_rect = rotated_icon.get_rect(center=(molotov["x"], molotov["y"]))
            SCREEN.blit(rotated_icon, icon_rect)
        except:
            # 기본 원형 그리기
            draw.circle((255, 100, 0), (int(molotov["x"]), int(molotov["y"])), 10)
    
    # 화염 지대 그리기 - 불길이 번지는 효과
    for fire_zone in fire_zones:
        # 바닥에 기름이 번진 효과 (반투명 검은색 타원)
        oil_surface = pygame.Surface((fire_zone["width"], fire_zone["height"]), pygame.SRCALPHA)
        pygame.draw.ellipse(oil_surface, (30, 20, 10, 50), 
                          (0, 0, fire_zone["width"], fire_zone["height"]))
        SCREEN.blit(oil_surface, (fire_zone["x"] - fire_zone["width"]/2, 
                                 fire_zone["y"] - fire_zone["height"]/2))
        
        # 개별 불꽃 파티클 그리기
        for flame in fire_zone["flames"]:
            # 불꽃 색상 (노란색 → 주황색 → 빨간색)
            color_phase = flame["color_phase"]
            if color_phase < 0.3:
                pass
                # 밝은 노란색 중심부
                r, g, b = 255, 255, 100
            elif color_phase < 0.7:
                pass
                # 주황색
                r, g, b = 255, 150, 0
            else:
                pass
                # 빨간색 외곽
                r, g, b = 200, 50, 0
            
            # 투명도는 lifetime에 따라
            alpha = min(180, int(150 * (flame["lifetime"] / 30)))
            
            # 불꽃 그리기 (여러 겹으로)
            for layer in range(2):
                layer_size = flame["size"] * (1 - layer * 0.4)
                layer_alpha = alpha * (1 - layer * 0.5)
                if layer_alpha > 0 and layer_size > 0:
                    flame_surface = pygame.Surface((int(layer_size * 2), int(layer_size * 2)), pygame.SRCALPHA)
                    color_with_alpha = (r, g, b, int(layer_alpha))
                    pygame.draw.circle(flame_surface, color_with_alpha, 
                                     (int(layer_size), int(layer_size)), int(layer_size))
                    # 불꽃에 흔들림 효과 추가
                    wobble_x = random.uniform(-2, 2)
                    wobble_y = random.uniform(-1, 1)
                    SCREEN.blit(flame_surface, (int(flame["x"] - layer_size + wobble_x), 
                                               int(flame["y"] - layer_size + wobble_y)))
    
    # 🆕 벽돌 그리기
    for wall in walls:
        wall_rect = wall["rect"]
        wall_crack_level = wall["crack_level"]
        
        # 벽돌 기본 색상 (갈색)
        wall_color = (139, 69, 19)
        
        # 균열에 따른 색상 변화
        if wall_crack_level == 1:
            pass
            wall_color = (160, 82, 45)  # 살짝 밝은 갈색
        elif wall_crack_level == 2:
            pass
            wall_color = (184, 134, 11)  # 더 밝은 갈색
        elif wall_crack_level == 3:
            wall_color = (218, 165, 32)  # 금색
        
        # 벽돌 그리기
        draw.rect(wall_color, wall_rect)
        draw.rect((255, 255, 255), wall_rect, 2)  # 흰색 테두리
        
        # 균열 그리기
        if wall_crack_level > 0:
            crack_color = (255, 0, 0) if wall_crack_level >= 3 else (255, 255, 0)
            # 충돌횟수에 비례해서 균열 개수 증가
            crack_count = wall_crack_level * 3  # 1회 충돌당 3개, 2회 충돌당 6개, 3회 충돌당 9개 균열
            
            # 균열 선 그리기
            for i in range(crack_count):
                # 균열의 시작점 (벽돌 내부에서 랜덤)
                start_x = wall_rect.x + random.randint(5, wall_rect.width - 5)
                start_y = wall_rect.y + random.randint(5, wall_rect.height - 5)
                
                # 균열의 방향과 길이 (충돌횟수가 많을수록 더 긴 균열)
                crack_length = random.randint(8, 15 + wall_crack_level * 3)  # 충돌횟수에 따라 길이 증가
                angle = random.uniform(0, 2 * math.pi)  # 랜덤 각도
                
                # 균열의 끝점 계산
                end_x = start_x + int(math.cos(angle) * crack_length)
                end_y = start_y + int(math.sin(angle) * crack_length)
                
                # 균열 두께 (충돌횟수가 많을수록 두꺼워짐)
                crack_thickness = min(4, 1 + wall_crack_level)
                
                draw.line(crack_color, (start_x, start_y), (end_x, end_y), crack_thickness)

    # === Stage 4 명상타임 공 잔상 ===
    if current_stage == 4 and meditation_active:
        for x, y, alpha in meditation_trails:
            rotated_trail = pygame.transform.rotate(BALL_IMG, ball_angle)
            rotated_trail.set_alpha(alpha)
            SCREEN.blit(rotated_trail, (x - BALL.width // 2, y - BALL.height // 2))

    # === 공 (화면 흔들림 오프셋 적용) ===
    ball_rect = BALL.copy()
    ball_rect.x += screen_shake_offset_x
    ball_rect.y += quake_offset_y + screen_shake_offset_y
    
    # 💫 파워스매싱 잔상 효과 그리기 (세련된 버전) - 고스트샷일 때는 제외
    if (power_smashing_parabola_active or power_smashing_freeze_active) and not mega_smashing_active:
        pass
        # 잔상 업데이트 (현재 공 위치 추가)
        if len(power_smashing_trails) == 0 or \
           (len(power_smashing_trails) > 0 and 
            math.hypot(BALL.centerx - power_smashing_trails[-1][0], 
                      BALL.centery - power_smashing_trails[-1][1]) > 8):
            power_smashing_trails.append((BALL.centerx, BALL.centery, 255, BALL.width))
        
        # 오래된 잔상 제거 및 알파값 감소
        new_trails = []
        for trail in power_smashing_trails:
            x, y, alpha, size = trail
            alpha -= 20  # 더 빠른 페이드
            if alpha > 0:
                new_trails.append((x, y, alpha, size))
        power_smashing_trails = new_trails
        
        # 잔상 그리기 (전기 효과)
        for i, trail in enumerate(power_smashing_trails):
            x, y, alpha, size = trail
            color_intensity = alpha / 255.0
            
            # 전기 효과를 위한 서페이스
            trail_surface = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
            center = size * 1.5
            
            # 전기 번개 효과 (얇은 선들)
            if i < len(power_smashing_trails) - 1:
                next_trail = power_smashing_trails[i + 1]
                next_x, next_y = next_trail[0], next_trail[1]
                
                # 메인 번개
                lightning_color = (150, 200, 255, int(alpha * 0.8))
                draw.line(lightning_color[:3], (x, y), (next_x, next_y), max(1, int(3 * color_intensity)))
                
                # 주변 전기 스파크
                for _ in range(2):
                    spark_offset_x = random.randint(-10, 10)
                    spark_offset_y = random.randint(-10, 10)
                    spark_color = (200, 220, 255, int(alpha * 0.4))
                    draw.line(spark_color[:3], (x, y), 
                                   (x + spark_offset_x, y + spark_offset_y), 1)
            
            # 중심 에너지 코어 (파란색-흰색 그라데이션)
            core_size = int(size * 0.6 * color_intensity)
            if core_size > 0:
                pass
                # 외부 글로우 (파란색)
                glow_color = (100, 150, 255)
                pygame.draw.circle(trail_surface, (*glow_color, int(alpha * 0.2)), 
                                 (int(center), int(center)), int(size * 0.9))
                
                # 중간 레이어 (밝은 파란색)
                mid_color = (150, 200, 255)
                pygame.draw.circle(trail_surface, (*mid_color, int(alpha * 0.4)), 
                                 (int(center), int(center)), int(size * 0.6))
                
                # 내부 코어 (거의 흰색)
                core_color = (220, 240, 255)
                pygame.draw.circle(trail_surface, (*core_color, int(alpha * 0.6)), 
                                 (int(center), int(center)), core_size)
                
                SCREEN.blit(trail_surface, (x - center, y - center))
    
    # ✨ 파워스매싱 파티클 효과 업데이트 및 그리기 (세련된 버전) - 고스트샷일 때는 제외
    if len(power_smashing_particles) > 0 and not mega_smashing_active:
        new_particles = []
        for particle in power_smashing_particles:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['vx'] *= 0.92  # 속도 감소
            particle['vy'] *= 0.92
            particle['vy'] += 0.1  # 약간의 중력 효과
            particle['life'] -= 1
            
            if particle['life'] > 0:
                new_particles.append(particle)
                
                # 에너지 파티클 그리기
                alpha = int(255 * (particle['life'] / 60))
                size = int(2 + (particle['life'] / 60) * 2)
                
                # 파티클 타입에 따른 렌더링
                if particle.get('type') == 'spark':
                    pass
                    # 전기 스파크 타입
                    spark_length = int(5 + (particle['life'] / 60) * 5)
                    end_x = particle['x'] + particle['vx'] * 2
                    end_y = particle['y'] + particle['vy'] * 2
                    draw.line( (*particle['color'], alpha), 
                                   (particle['x'], particle['y']), (end_x, end_y), 1)
                else:
                    pass
                    # 에너지 구체 타입
                    particle_surface = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
                    center = size * 2
                    
                    # 외부 글로우
                    glow_alpha = int(alpha * 0.3)
                    pygame.draw.circle(particle_surface, (*particle['color'], glow_alpha), 
                                     (center, center), size * 2)
                    
                    # 내부 코어
                    core_alpha = int(alpha * 0.8)
                    pygame.draw.circle(particle_surface, (255, 255, 255, core_alpha), 
                                     (center, center), size)
                    
                    SCREEN.blit(particle_surface, (particle['x'] - center, particle['y'] - center))
        
        power_smashing_particles = new_particles
        
        # 고스트샷 이펙트는 별도 함수에서 처리
        if False:  # 고스트샷 이펙트 제거 (render_mega_smashing_effects에서 처리)
            new_meteor_trail = []
            current_time = pygame.time.get_ticks() / 1000.0  # 초 단위 시간
            
            for meteor in mega_smashing_meteor_trail:
                # 회전 각도 업데이트 (불규칙한 속도 변화)
                speed_variation = math.sin(current_time * meteor.get('orbit_frequency', 3)) * 0.05
                meteor['angle'] += meteor['angular_speed'] * (1 + speed_variation)
                
                # 복잡한 나선형 움직임을 위한 반경 변화
                wobble1 = math.sin(current_time * meteor.get('orbit_frequency', 3) + meteor['offset_phase']) * meteor.get('wobble_amplitude', 5)
                wobble2 = math.cos(current_time * 2.1 + meteor['offset_phase'] * 0.7) * 3
                current_radius = meteor['radius'] + wobble1 + wobble2
                
                # 공 중심을 기준으로 복잡한 궤도를 그리는 위치 계산
                # 리사주 곡선 효과 추가
                x = BALL.centerx + math.cos(meteor['angle']) * current_radius + math.sin(meteor['angle'] * 2) * 10
                y = BALL.centery + math.sin(meteor['angle']) * current_radius + math.cos(meteor['angle'] * 3) * 8
                
                # 궤적에 현재 위치 추가
                meteor['trail'].append((x, y, meteor['life']))
                
                # 궤적 길이 제한
                if len(meteor['trail']) > 15:
                    meteor['trail'].pop(0)
                
                meteor['life'] -= 0.5  # 천천히 사라지게
                
                if meteor['life'] > 0:
                    new_meteor_trail.append(meteor)
                    
                    # 유성 궤적 그리기 (무지개빛 효과)
                    if len(meteor['trail']) > 1:
                        for i in range(len(meteor['trail']) - 1):
                            x1, y1, life1 = meteor['trail'][i]
                            x2, y2, life2 = meteor['trail'][i + 1]
                            
                            # 고스트샷 특수 색상 효과
                            trail_alpha = int((life2 / 120) * 255)
                            trail_width = int(meteor['size'] * (life2 / 120) * 0.7)
                            
                            if trail_width > 0 and trail_alpha > 10:
                                pass
                                # 무지개빛 색상 변화 (시간에 따라)
                                color_shift = meteor.get('color_shift', 0)
                                hue = (current_time * 100 + i * 10 + color_shift * 360) % 360
                                
                                # HSV to RGB 변환 (무지개 효과)
                                c = 1.0
                                h = hue / 60.0
                                x_val = c * (1 - abs((h % 2) - 1))
                                
                                if h < 1:
                                    pass
                                    r, g, b = c, x_val, 0
                                elif h < 2:
                                    pass
                                    r, g, b = x_val, c, 0
                                elif h < 3:
                                    pass
                                    r, g, b = 0, c, x_val
                                elif h < 4:
                                    pass
                                    r, g, b = 0, x_val, c
                                elif h < 5:
                                    pass
                                    r, g, b = x_val, 0, c
                                else:
                                    r, g, b = c, 0, x_val
                                
                                # 네온 효과를 위한 밝기 증가
                                r = min(255, int(r * 255 * 1.5))
                                g = min(255, int(g * 255 * 1.5))
                                b = min(255, int(b * 255 * 1.5))
                                
                                # 외곽 글로우 (더 밝은 색)
                                draw.line( (r, g, b, min(255, trail_alpha // 2)), 
                                               (x1, y1), (x2, y2), max(1, trail_width + 2))
                                # 코어 (황금색 + 무지개)
                                core_r = min(255, (255 + r) // 2)
                                core_g = min(255, (215 + g) // 2)
                                core_b = min(255, b)
                                draw.line( (core_r, core_g, core_b, min(255, trail_alpha)), 
                                               (x1, y1), (x2, y2), max(1, trail_width))
                    
                    # 유성 헤드 그리기
                    head_size = int(meteor['size'] * (meteor['life'] / 90))
                    if head_size > 0:
                        pass
                        # 홀로그램 글로우
                        glow_surface = pygame.Surface((head_size * 4, head_size * 4), pygame.SRCALPHA)
                        glow_alpha = int((meteor['life'] / 90) * 150)
                        
                        # 외부 글로우 (청록색)
                        pygame.draw.circle(glow_surface, (0, 255, 255, min(255, glow_alpha // 2)),
                                         (head_size * 2, head_size * 2), head_size * 2)
                        # 내부 코어 (황금색)
                        pygame.draw.circle(glow_surface, (255, 215, 0, min(255, glow_alpha)),
                                         (head_size * 2, head_size * 2), head_size)
                        SCREEN.blit(glow_surface, (x - head_size * 2, y - head_size * 2))
            
            mega_smashing_meteor_trail = new_meteor_trail
        
        # 움직이는 동안 계속 파티클 생성 (더 세련된 효과) - 고스트샷일 때는 제외
        if power_smashing_parabola_active and not mega_smashing_active and random.random() < 0.7:
            pass
            # 에너지 파티클
            for _ in range(1):
                angle = random.uniform(0, 2 * math.pi)
                speed = random.uniform(0.5, 2)
                power_smashing_particles.append({
                    'x': BALL.centerx + random.randint(-5, 5),
                    'y': BALL.centery + random.randint(-5, 5),
                    'vx': math.cos(angle) * speed,
                    'vy': math.sin(angle) * speed,
                    'life': 25,
                    'color': random.choice([(100, 150, 255), (150, 200, 255), (200, 220, 255)]),
                    'type': 'energy'
                })
            
            # 전기 스파크
            if random.random() < 0.3:
                angle = random.uniform(0, 2 * math.pi)
                speed = random.uniform(2, 4)
                power_smashing_particles.append({
                    'x': BALL.centerx,
                    'y': BALL.centery,
                    'vx': math.cos(angle) * speed,
                    'vy': math.sin(angle) * speed,
                    'life': 15,
                    'color': (200, 230, 255),
                    'type': 'spark'
                })
    
    # 🎯 레이저스코프 궤적 그리기 (공 그리기 전에)
    # [StageRenderer로 대체]

    stage_renderer.draw('predicted_trajectory', points=predicted_trajectory)

    # draw_predicted_trajectory()  # 원본 백업
    
    # 👻 고스트샷 귀신 이펙트 렌더링
    render_mega_smashing_effects()
    
    # 공 이미지 결정
    ball_img_to_draw = BALL_IMG  # 🔧 예전 파워스매싱(공이 붉게 되는 것) 제거
    
    # 💎 고스트샷 발동 시 보라색-검은색 그라데이션 광물질 효과
    if mega_smashing_active:
        pass
        # 시간 기반 애니메이션
        ghost_time = pygame.time.get_ticks() * 0.002
        
        # 기본 공 이미지를 복사
        ghost_ball = ball_img_to_draw.copy()
        
        # 보라색 오버레이 표면 생성
        overlay = pygame.Surface((BALL.width, BALL.height), pygame.SRCALPHA)
        
        # 중심에서 외곽으로 그라데이션
        center_x = BALL.width // 2
        center_y = BALL.height // 2
        max_radius = BALL.width // 2
        
        # 어두운 보라색 틴트 효과
        tint_surface = pygame.Surface((BALL.width, BALL.height), pygame.SRCALPHA)
        
        # 시간에 따른 색상 변화 (맥동 효과)
        pulse = (math.sin(ghost_time * 2) + 1) * 0.5
        
        # 보라색-검은색 그라데이션을 위한 색상 설정
        base_purple = (60 + int(pulse * 40), 0, 80 + int(pulse * 50))  # 어두운 보라색
        
        # 전체적으로 어두운 보라색 틴트 적용
        pygame.draw.circle(tint_surface, (*base_purple, 180),
                         (center_x, center_y), max_radius)
        
        # 원본 이미지에 틴트 적용
        ghost_ball.blit(tint_surface, (0, 0), special_flags=pygame.BLEND_MULT)
        
        # 보라색 그라데이션 효과 추가
        for i in range(3):
            radius = max_radius - i * (max_radius // 4)
            alpha = 80 - i * 20
            color = (
                120 + int(pulse * 60) - i * 20,
                20 + int(pulse * 20) - i * 10,
                180 + int(pulse * 40) - i * 30
            )
            pygame.draw.circle(overlay, (*color, alpha),
                             (center_x, center_y), radius)
        
        # 오버레이를 공에 적용
        ghost_ball.blit(overlay, (0, 0), special_flags=pygame.BLEND_ADD)
        
        # 광물질 반짝임 효과
        sparkle_surface = pygame.Surface((BALL.width, BALL.height), pygame.SRCALPHA)
        for _ in range(5):
            sparkle_x = random.randint(5, BALL.width - 5)
            sparkle_y = random.randint(5, BALL.height - 5)
            sparkle_size = random.randint(1, 2)
            
            # 반짝이는 점 (밝은 보라빛)
            pygame.draw.circle(sparkle_surface, (200, 150, 255, 200),
                             (sparkle_x, sparkle_y), sparkle_size)
        
        ghost_ball.blit(sparkle_surface, (0, 0))
        
        # 크리스탈 하이라이트 효과
        highlight_offset = int(math.sin(ghost_time * 3) * 2)
        pygame.draw.circle(ghost_ball, (220, 180, 255, 200),
                         (center_x - 5 + highlight_offset, center_y - 5), 3)
        
        # 검은 테두리 효과
        pygame.draw.circle(overlay, (20, 0, 40, 150),
                         (center_x, center_y), max_radius, 2)
        ghost_ball.blit(overlay, (0, 0))
        
        # 최종 이미지로 설정
        ball_img_to_draw = ghost_ball
        
    # 🆕 새로운 보스전에서는 드라이브 모니터(연두색 공) 제거
    elif not new_boss_mode_active and drive_ball_active:
        pass
        # 프리즘 구체 효과를 위한 시간 기반 변화
        prism_time = pygame.time.get_ticks() * 0.003
        
        # 기본 공 이미지 복사
        base_ball = ball_img_to_draw.copy()
        
        # 선명한 무지개 색상 스펙트럼
        rainbow_colors = [
            (255, 0, 0),      # 강한 빨강
            (255, 127, 0),    # 강한 주황
            (255, 255, 0),    # 강한 노랑
            (0, 255, 0),      # 강한 초록
            (0, 127, 255),    # 강한 하늘색
            (0, 0, 255),      # 강한 파랑
            (127, 0, 255),    # 강한 보라
        ]
        
        # 각도에 따른 프리즘 효과
        angle_offset = prism_time % 360
        
        # 무지개 그라데이션 오버레이
        overlay = pygame.Surface((BALL.width, BALL.height), pygame.SRCALPHA)
        
        # 무지개 스트라이프 효과
        for i, color in enumerate(rainbow_colors):
            # 각 색상의 각도 계산
            stripe_angle = (angle_offset + i * 51) % 360
            
            # 색상 강도를 시간에 따라 변화
            pulse = (math.sin(math.radians(stripe_angle * 2)) + 1) * 0.5
            intensity = 0.4 + pulse * 0.4
            
            # 무지개 띠 그리기
            stripe_width = BALL.width // 3
            stripe_pos = i * 5 - 10 + int(math.sin(math.radians(stripe_angle)) * 3)
            
            # 각 색상 띠를 대각선으로 그리기
            for j in range(BALL.height):
                x = stripe_pos + j // 2
                if 0 <= x < BALL.width:
                    color_with_alpha = (*color, int(intensity * 150))
                    pygame.draw.line(overlay, color_with_alpha, 
                                   (x, j), (x + 2, j), 2)
        
        # 오버레이를 공에 블렌드
        base_ball.blit(overlay, (0, 0), special_flags=pygame.BLEND_ADD)
        
        # 프리즘 굴절 효과 (색상 시프트)
        shift_surface = pygame.Surface((BALL.width, BALL.height), pygame.SRCALPHA)
        color_idx = int((prism_time / 10) % len(rainbow_colors))
        prism_color = rainbow_colors[color_idx]
        shift_surface.fill((*prism_color, 40))
        base_ball.blit(shift_surface, (0, 0), special_flags=pygame.BLEND_ADD)
        
        # 중앙에 밝은 하이라이트 추가 (크리스탈 느낌)
        highlight = pygame.Surface((BALL.width, BALL.height), pygame.SRCALPHA)
        pygame.draw.circle(highlight, (255, 255, 255, 100),
                         (BALL.width//2 - 3, BALL.height//2 - 3), 6)
        pygame.draw.circle(highlight, (255, 255, 255, 50),
                         (BALL.width//2, BALL.height//2), 10)
        base_ball.blit(highlight, (0, 0), special_flags=pygame.BLEND_ADD)
        
        # 회전 적용
        rotated_ball = pygame.transform.rotate(base_ball, ball_angle)
        ball_img_rect = rotated_ball.get_rect(center=ball_rect.center)
        draw_with_shake(rotated_ball, ball_img_rect.topleft)
    else:
        pass
        # 기본 공 그리기
        rotated_ball = pygame.transform.rotate(ball_img_to_draw, ball_angle)
        ball_img_rect = rotated_ball.get_rect(center=ball_rect.center)
        draw_with_shake(rotated_ball, ball_img_rect.topleft)
    
    # ⚡ 라이트닝 마스터 번개 충격 효과 - 공 주위에 번개 고리
    if new_boss_mode_active and lightning_strike_active:
        pass
        # 번개 고리 그리기
        thunder_time = pygame.time.get_ticks() * 0.01
        for i in range(8):  # 8개의 번개 볼트
            angle = (i * 45 + thunder_time * 50) % 360  # 회전하는 번개
            rad = math.radians(angle)
            
            # 번개 볼트 위치 계산
            radius = BALL.width // 2 + 15 + math.sin(thunder_time + i) * 5
            bolt_x = ball_rect.centerx + math.cos(rad) * radius
            bolt_y = ball_rect.centery + math.sin(rad) * radius
            
            # 번개 색상 (번쩍거리는 효과)
            flash_intensity = int(200 + 55 * math.sin(thunder_time * 3 + i))
            lightning_color = (flash_intensity, flash_intensity, 100)
            
            # 번개 볼트 그리기 (중심에서 외곽으로)
            draw.line(lightning_color, ball_rect.center, (int(bolt_x), int(bolt_y)), 3)
            
            # 번개 끝에 작은 원 효과
            draw.circle(lightning_color, (int(bolt_x), int(bolt_y)), 4)
        
        # 공 중심에 전기 글로우 효과
        glow_alpha = int(100 + 50 * math.sin(thunder_time * 5))
        glow_surface = pygame.Surface((BALL.width + 30, BALL.height + 30), pygame.SRCALPHA)
        pygame.draw.circle(glow_surface, (255, 255, 150, glow_alpha), 
                         ((BALL.width + 30) // 2, (BALL.height + 30) // 2), BALL.width // 2 + 10)
        SCREEN.blit(glow_surface, (ball_rect.centerx - (BALL.width + 30) // 2, 
                                 ball_rect.centery - (BALL.height + 30) // 2))
    
    # 🔥 파이어 나이트 화염 돌진 효과 - 하단 패들 주위에 화염 효과
    if new_boss_mode_active and fire_charge_active:
        pass
        # 화염 효과 시간
        flame_time = pygame.time.get_ticks() * 0.015
        
        # 하단 패들 (파이어 나이트) 주위에 화염 고리
        for i in range(12):  # 12개의 화염 파티클
            angle = (i * 30 + flame_time * 100) % 360  # 빠르게 회전하는 화염
            rad = math.radians(angle)
            
            # 화염 파티클 위치 계산 (패들 주위)
            radius = PADDLE_WIDTH // 2 + 20 + math.sin(flame_time + i * 0.5) * 8
            flame_x = PLAYER.centerx + math.cos(rad) * radius
            flame_y = PLAYER.centery + math.sin(rad) * radius
            
            # 화염 색상 (오렌지에서 빨강으로 번갈아가며)
            flame_intensity = int(150 + 105 * math.sin(flame_time * 4 + i))
            if i % 2 == 0:
                pass
                flame_color = (255, flame_intensity, 0)  # 오렌지
            else:
                flame_color = (255, flame_intensity // 2, 0)  # 빨강
            
            # 화염 파티클 그리기
            flame_size = int(6 + 3 * math.sin(flame_time * 2 + i))
            draw.circle(flame_color, (int(flame_x), int(flame_y)), flame_size)
            
            # 내부에 밝은 중심 추가
            inner_size = max(2, flame_size - 2)
            draw.circle((255, 255, 200), (int(flame_x), int(flame_y)), inner_size)
        
        # 패들 중심에 화염 글로우 효과
        glow_alpha = int(80 + 40 * math.sin(flame_time * 6))
        glow_surface = pygame.Surface((PADDLE_WIDTH + 40, PADDLE_HEIGHT + 40), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_surface, (255, 100, 0, glow_alpha), 
                           (0, 0, PADDLE_WIDTH + 40, PADDLE_HEIGHT + 40))
        SCREEN.blit(glow_surface, (PLAYER.centerx - (PADDLE_WIDTH + 40) // 2, 
                                 PLAYER.centery - (PADDLE_HEIGHT + 40) // 2))
        
        # 화염 꼬리 효과 (패들 뒤쪽)
        for i in range(5):
            tail_x = PLAYER.centerx - i * 15  # 패들 뒤로 이어지는 꼬리
            tail_y = PLAYER.centery + random.randint(-5, 5)
            tail_alpha = int(100 - i * 15)
            if tail_alpha > 0:
                tail_surface = pygame.Surface((20, 20), pygame.SRCALPHA)
                pygame.draw.circle(tail_surface, (255, 150, 0, tail_alpha), (10, 10), 10 - i)
                SCREEN.blit(tail_surface, (tail_x - 10, tail_y - 10))

    # 🔹 공 꼬리
    if special_active:
        ball_trail.append((BALL.centerx, BALL.centery, 200))
    ball_trail = [(x, y, a - 10) for x, y, a in ball_trail if a > 10][:10]
    for x, y, alpha in ball_trail:
#         trail = pygame.transform.scale(ball_img_to_draw, (BALL.width, BALL.height))
        trail.set_alpha(alpha)
        SCREEN.blit(trail, (x - BALL.width // 2, y - BALL.height // 2))

    # === Stage 5 화염탄 ===
    if current_stage == 5:
        for fireball in fireballs:
            pos = fireball[0]
            SCREEN.blit(FIREBALL_IMG, (pos[0] - 16, pos[1] - 16))
    
    # 🔥 화염탄 폭발 이펙트 그리기
    draw_fireball_explosion_particles()

    # === Stage 5 화염 용이 소용돌이치며 공을 따라오는 이펙트 ===
    if flame_trail_active:
        pass
        # 용의 몸체를 그리기 위한 시간 기반 애니메이션
        time_now = pygame.time.get_ticks()
        
        if len(flame_trail_positions) > 2:
            pass
            # 🐉 화염 용 몸체 그리기
            for i in range(len(flame_trail_positions) - 1):
                if i < len(flame_trail_positions) - 1:
                    x1, y1 = flame_trail_positions[i]
                    x2, y2 = flame_trail_positions[i + 1]
                    
                    # 위치 비율 계산 (꼬리에서 머리로)
                    progress = i / max(1, len(flame_trail_positions) - 1)
                    
                    # 소용돌이 효과를 위한 사인파 적용
                    wave_offset = math.sin(time_now * 0.01 + i * 0.5) * 10
                    spiral_offset = math.cos(time_now * 0.008 + i * 0.3) * 8
                    
                    # 용의 몸체 두께 (머리로 갈수록 굵어짐)
                    thickness = int(3 + progress * 12)
                    
                    # 색상 그라데이션 (꼬리: 어두운 붉은색 → 머리: 밝은 주황색)
                    r = int(150 + progress * 105)
                    g = int(20 + progress * 100)
                    b = int(10 + progress * 20)
                    body_color = (min(255, r), min(255, g), min(255, b))
                    
                    # 용의 몸체 중심선
                    center_x = x1 + wave_offset
                    center_y = y1 + spiral_offset
                    
                    # 몸체 메인 부분
                    draw.circle(body_color, (int(center_x), int(center_y)), thickness)
                    
                    # 용의 비늘 효과 (일정 간격마다)
                    if i % 3 == 0:
                        scale_color = (min(255, r + 50), min(255, g + 30), b)
                        draw.circle(scale_color, (int(center_x + thickness/2), int(center_y)), 
                                         max(2, thickness//3))
                    
                    # 화염 효과 (외곽 불꽃)
                    if progress > 0.3:  # 몸체 중간부터 화염 시작
                        flame_alpha = int(100 + progress * 155)
                        for angle in range(0, 360, 60):  # 6방향 불꽃
                            flame_x = center_x + math.cos(math.radians(angle + time_now * 0.5)) * (thickness + 4)
                            flame_y = center_y + math.sin(math.radians(angle + time_now * 0.5)) * (thickness + 4)
                            flame_size = max(1, int(2 + progress * 3))
                            
                            # 불꽃 그라데이션
                            draw.circle((255, 200, 100),
                                             (int(flame_x), int(flame_y)), flame_size)
                            if flame_size > 2:
                                draw.circle((255, 255, 200),
                                                 (int(flame_x), int(flame_y)), flame_size - 1)
            
            # 🐉 용의 머리 (공 위치)
            if flame_trail_positions:
                head_x, head_y = flame_trail_positions[-1]
                
                # 머리 본체
                draw.circle((255, 150, 50), 
                                 (int(head_x), int(head_y)), 15)
                draw.circle((255, 200, 100),
                                 (int(head_x), int(head_y)), 10)
                
                # 용의 눈 (빛나는 효과)
                eye_glow = int(abs(math.sin(time_now * 0.01)) * 100 + 155)
                draw.circle((eye_glow, eye_glow, 0),
                                 (int(head_x - 5), int(head_y - 3)), 3)
                draw.circle((eye_glow, eye_glow, 0),
                                 (int(head_x + 5), int(head_y - 3)), 3)
                
                # 용의 뿔
                horn_color = (200, 50, 50)
                draw.line(horn_color, (int(head_x - 8), int(head_y - 10)),
                               (int(head_x - 12), int(head_y - 18)), 3)
                draw.line(horn_color, (int(head_x + 8), int(head_y - 10)),
                               (int(head_x + 12), int(head_y - 18)), 3)
                
                # 화염 숨결 효과
                if random.random() < 0.6:  # 60% 확률로 화염 분출
                    for _ in range(5):
                        breath_angle = math.radians(random.randint(160, 200))  # 아래쪽 방향
                        breath_dist = random.randint(10, 25)
                        breath_x = head_x + math.cos(breath_angle) * breath_dist
                        breath_y = head_y + math.sin(breath_angle) * breath_dist
                        breath_size = random.randint(2, 4)
                        draw.circle((255, random.randint(100, 200), 0),
                                         (int(breath_x), int(breath_y)), breath_size)

    # 🚀 성능 최적화: 눈물 파티클 렌더링 최적화
    new_tear_particles = []
    # 파티클 개수 제한으로 성능 향상
    max_particles = 20  # 최대 20개 파티클만 유지
    active_particles = 0
    
    for p in tear_particles:
        if active_particles >= max_particles:
            break  # 최대 개수 제한
            
        x, y, vx, vy, alpha, size = p
        x += vx
        y += vy
        alpha -= 8  # 더 빨리 사라지게 해서 성능 향상 (5 → 8)
        
        if alpha > 0:
            pass
            # 🚀 성능 최적화: 간단한 원형으로 그리기 (Surface 생성 생략)
            color = (100, 150, min(255, alpha))  # 푸른 물빛
            draw.circle(color, (int(x + size//2), int(y + size//2)), size//2)
            new_tear_particles.append([x, y, vx, vy, alpha, size])
            active_particles += 1
    
    tear_particles[:] = new_tear_particles

    # 🎯 타격 이펙트 파티클 그리기
    # [StageRenderer로 대체]

    stage_renderer.draw('impact_particles', particles=impact_particles)

    # draw_impact_particles()  # 원본 백업

    # 모든 이펙트 업데이트 및 그리기
    effects_manager.update_all_effects()
    effects_manager.draw_all_effects(SCREEN)
    
    # 터렛 미사일 업데이트 및 그리기 (스테이지 6에서만)
    if current_stage == 6:
        global player_missile_stunned_timer, player_missile_knockback_vel
        current_time = pygame.time.get_ticks()
        
        # 미사일 업데이트
        new_missiles = []
        missile_hit_this_frame = False  # 이번 프레임에 미사일 충돌 여부
        
        for missile in turret_missiles:
            # 미사일 이동
            missile['x'] += missile['vx']
            missile['y'] += missile['vy']
            missile['age'] += 1
            
            # 화면 밖으로 나가거나 너무 오래된 미사일 제거
            if (0 <= missile['x'] <= WIDTH and 0 <= missile['y'] <= HEIGHT and 
                missile['age'] < 300):  # 5초 후 제거
                new_missiles.append(missile)
                
                # 플레이어와 충돌 체크 (무적 시간이 아니고 연막 안에 있지 않을 때만)
                missile_rect = pygame.Rect(missile['x'] - 3, missile['y'] - 3, 6, 6)
                if missile_rect.colliderect(PLAYER) and current_time > player_missile_invulnerable_time and not is_player_in_smoke():
                    pass
                    # 스테이지 5 화염탄과 동일한 넉백 시스템 적용
                    # 미사일 방향에 따른 넉백 속도 설정
                    missile_speed = math.sqrt(missile['vx']**2 + missile['vy']**2)
                    if missile_speed > 0:
                        pass
                        # 미사일 진행 방향으로 넉백 (화염탄의 25% 강도)
                        knockback_direction = missile['vx'] / abs(missile['vx']) if missile['vx'] != 0 else random.choice([-1, 1])
                        player_missile_knockback_vel = knockback_direction * 9  # 화염탄의 25% 강도 (36 -> 18 -> 9)
                        player_missile_stunned_timer = int(0.3 * FPS)  # 화염탄과 동일한 스턴 시간 (0.3초)
                    
                    # 충돌 효과 표시
                    effects_manager.create_impact_effect(missile['x'], missile['y'], 10, is_player=False)
                    
                    # 화면 흔들림 효과 추가
                    for _ in range(10):
                        spark_x = PLAYER.x + random.randint(0, PLAYER.width)
                        spark_y = PLAYER.y + random.randint(0, PLAYER.height)
                        effects_manager.spawn_star_particles(spark_x, spark_y, count=3)
                    
                    # 한 프레임에 한 번만 사운드 재생
                    if not missile_hit_this_frame:
                        SOUND_MISSILE.play()  # 미사일 충돌 사운드 재생
                        missile_hit_this_frame = True
                        # 무적 시간 설정 (0.5초로 감소)
                        player_missile_invulnerable_time = current_time + 500
                    
                    continue  # 충돌한 미사일은 제거
        
        turret_missiles = new_missiles
        
        # 미사일 그리기 (탄도미사일 스타일)
        for missile in turret_missiles:
            mx, my = int(missile['x']), int(missile['y'])
            
            # 미사일 각도 계산 (진행 방향)
            angle = math.atan2(missile['vy'], missile['vx'])
            
            # 미사일 길이와 두께
            missile_length = 12
            missile_width = 3
            
            # 미사일 탄두 (앞부분 - 원뿔형)
            tip_x = mx + math.cos(angle) * missile_length // 2
            tip_y = my + math.sin(angle) * missile_length // 2
            
            # 미사일 후미
            tail_x = mx - math.cos(angle) * missile_length // 2
            tail_y = my - math.sin(angle) * missile_length // 2
            
            # 미사일 몸체 (짙은 회색 원통형)
            draw.line((80, 80, 80), 
                           (tail_x, tail_y), (tip_x, tip_y), missile_width + 2)
            draw.line((120, 120, 120), 
                           (tail_x, tail_y), (tip_x, tip_y), missile_width)
            
            # 탄두 (빨간색 팁)
            warhead_x = mx + math.cos(angle) * (missile_length // 2 - 2)
            warhead_y = my + math.sin(angle) * (missile_length // 2 - 2)
            draw.circle((200, 50, 50), (int(warhead_x), int(warhead_y)), 2)
            draw.circle((255, 100, 100), (int(warhead_x), int(warhead_y)), 1)
            
            # 날개/핀 (미사일 안정 날개)
            fin_offset = missile_length // 3
            fin_x = mx - math.cos(angle) * fin_offset
            fin_y = my - math.sin(angle) * fin_offset
            
            # 좌우 날개
            perp_angle = angle + math.pi / 2
            fin_size = 3
            
            # 왼쪽 날개
            left_fin_x = fin_x + math.cos(perp_angle) * fin_size
            left_fin_y = fin_y + math.sin(perp_angle) * fin_size
            draw.line((100, 100, 100), 
                           (int(fin_x), int(fin_y)), 
                           (int(left_fin_x), int(left_fin_y)), 2)
            
            # 오른쪽 날개
            right_fin_x = fin_x - math.cos(perp_angle) * fin_size
            right_fin_y = fin_y - math.sin(perp_angle) * fin_size
            draw.line((100, 100, 100), 
                           (int(fin_x), int(fin_y)), 
                           (int(right_fin_x), int(right_fin_y)), 2)
            
            # 추진 화염 효과
            for i in range(4):
                flame_dist = (i + 1) * 3
                flame_x = tail_x - math.cos(angle) * flame_dist
                flame_y = tail_y - math.sin(angle) * flame_dist
                flame_size = 4 - i
                
                if i < 2:
                    pass
                    # 밝은 화염 (노란색-주황색)
                    flame_color = (255, 200 - i*50, 100 - i*30)
                else:
                    pass
                    # 연기 (회색)
                    flame_color = (150 - i*20, 150 - i*20, 150 - i*20)
                
                draw.circle(flame_color, (int(flame_x), int(flame_y)), flame_size)
        
        # 마지막 발사 시간 업데이트
        if len(turret_missiles) > 0:
            last_missile_time = pygame.time.get_ticks()
    
    # === 플라즈마 레이저 캐논 시스템 (스테이지 6) ===
    if current_stage == 6:
        global laser_cannon_active, last_laser_time, laser_charging, laser_charge_start
        global player_stunned, player_stun_end_time, laser_beam_duration, laser_rotating_mode, laser_rotation_direction, laser_cooldown
        global laser_rotation_range, laser_rotation_speed
        current_time = pygame.time.get_ticks()
        
        # 체력이 60% 이하일 때만 레이저 작동
        health_percent = (boss_current_health / boss_max_health) * 100
        
        # 5~9초마다 레이저 충전 시작 (체력 60% 이하일 때만, 혼란 상태가 아닐 때만)
        if health_percent <= 60 and not laser_charging and not laser_cannon_active and current_time - last_laser_time > laser_cooldown and boss_confused_timer == 0:
            laser_charging = True
            laser_charge_start = current_time
            # 레이저 충전 사운드 재생
            SOUND_STAGE6_BEAM_CHARGE.play()
            # 체력에 따른 레이저 패턴 결정
            if health_percent <= 40:
                pass
                # 40% 이하: 등대처럼 회전하는 레이저 (모든 요소 랜덤)
                laser_cannon_angle = random.choice([120, 90, 60])  # 시작 방향
                laser_rotating_mode = True  # 회전 모드 활성화
                laser_rotation_direction = random.choice([1, -1])  # 50% 확률로 시계방향/반시계방향
                laser_rotation_range = random.randint(40, 90)  # 회전 범위 40~90도 랜덤
                laser_rotation_speed = random.uniform(0.7, 1.5)  # 회전 속도 0.7~1.5배 랜덤
            else:
                pass
                # 60% ~ 41%: 기존 고정 방향 레이저
                laser_cannon_angle = random.choice([120, 90, 60])  # 4시(120도), 6시(90도), 8시(60도) 방향
                laser_rotating_mode = False  # 고정 모드
        
        # 충전 완료 후 발사
        if laser_charging and current_time - laser_charge_start > 1500:  # 1.5초 충전
            laser_charging = False
            laser_cannon_active = True
            last_laser_time = current_time
            
            # 체력에 따른 레이저 지속시간 설정
            if health_percent <= 40:
                pass
                laser_beam_duration = 2500  # 40% 이하: 2.5초
            else:
                laser_beam_duration = 1500  # 기본: 1.5초
            
            # 레이저 빔 사운드 재생
            SOUND_STAGE6_BEAM.play()
        
        # 레이저 빔 그리기 및 충돌 체크
        if laser_cannon_active:
            beam_time = current_time - last_laser_time
            if beam_time < laser_beam_duration:
                pass
                # 레이저 빔 위치 및 방향 계산
                # 회전 모드인 경우 등대처럼 천천히 회전
                if laser_rotating_mode:
                    pass
                    # 진정한 등대 효과: 사인파를 이용한 왕복 운동
                    # 주기적으로 왕복하는 속도 (laser_rotation_speed로 조절)
                    oscillation_period = 2000 / laser_rotation_speed  # 기본 2초 주기, 속도 배율 적용
                    
                    # 시간에 따른 진동 위치 (-1 ~ 1)
                    oscillation_factor = math.sin((beam_time / oscillation_period) * 2 * math.pi)
                    
                    # 회전 범위의 절반만큼 좌우로 움직임
                    rotation_offset = (laser_rotation_range / 2) * oscillation_factor * laser_rotation_direction
                    
                    # 최종 각도 계산
                    current_angle = laser_cannon_angle + rotation_offset
                    
                    angle_rad = math.radians(current_angle)
                else:
                    pass
                    # 고정 모드
                    angle_rad = math.radians(laser_cannon_angle)
                beam_start_x = BOSS.centerx
                beam_start_y = BOSS.bottom + 35  # 캐논 끝에서 시작
                
                # 빔 끝점 계산 (각도에 따라)
                beam_length = HEIGHT
                beam_end_x = beam_start_x + int(math.cos(angle_rad) * beam_length)
                beam_end_y = beam_start_y + int(math.sin(angle_rad) * beam_length)
                
                # 레이저 빔 그리기 (파란색 플라즈마)
                # 빔이 끝날 때 점점 얇아지는 효과 (마지막 0.5초 동안)
                fade_start_time = laser_beam_duration - 500  # 마지막 0.5초
                if beam_time > fade_start_time:
                    fade_progress = (beam_time - fade_start_time) / 500  # 0~1
                    beam_width = int(20 * (1 - fade_progress))  # 20에서 0으로 감소
                    beam_width = max(1, beam_width)  # 최소 1픽셀
                else:
                    beam_width = 20
                
                # 🌀 나선형 파장 애니메이션 (못 모양)
                # 빔 주위를 감싸고 도는 나선형 파장들
                num_spirals = 3  # 나선 개수
                for spiral_idx in range(num_spirals):
                    spiral_offset = (spiral_idx * 2 * math.pi / num_spirals) + (beam_time * 0.01)  # 시간에 따라 회전
                    
                    # 빔을 따라 나선형 그리기
                    points_per_spiral = 30
                    for i in range(points_per_spiral):
                        t = i / points_per_spiral  # 0~1 사이의 빔 위치
                        
                        # 빔 상의 위치
                        base_x = beam_start_x + (beam_end_x - beam_start_x) * t
                        base_y = beam_start_y + (beam_end_y - beam_start_y) * t
                        
                        # 나선형 오프셋 계산
                        spiral_angle = spiral_offset + t * 8 * math.pi  # 빔을 따라 8회전
                        spiral_radius = beam_width + 10 + math.sin(t * math.pi) * 5  # 중간이 더 넓은 나선
                        
                        # 빔에 수직인 방향으로 오프셋 적용
                        perpendicular_angle = angle_rad + math.pi/2
                        spiral_x = base_x + math.cos(perpendicular_angle) * math.cos(spiral_angle) * spiral_radius
                        spiral_y = base_y + math.sin(perpendicular_angle) * math.cos(spiral_angle) * spiral_radius
                        
                        # 나선 입자 그리기
                        wave_alpha = int(150 * (1 - t))  # 끝으로 갈수록 투명
                        wave_size = 3 + int(2 * math.sin(spiral_angle))
                        wave_color = (100 + int(50 * math.sin(spiral_angle)), 
                                    150 + int(50 * math.cos(spiral_angle)), 
                                    255)
                        
                        draw.circle(wave_color, (int(spiral_x), int(spiral_y)), wave_size)
                        
                        # 연결선 그리기 (나선 흐름 표현)
                        if i > 0:
                            prev_t = (i-1) / points_per_spiral
                            prev_base_x = beam_start_x + (beam_end_x - beam_start_x) * prev_t
                            prev_base_y = beam_start_y + (beam_end_y - beam_start_y) * prev_t
                            prev_spiral_angle = spiral_offset + prev_t * 8 * math.pi
                            prev_spiral_x = prev_base_x + math.cos(perpendicular_angle) * math.cos(prev_spiral_angle) * spiral_radius
                            prev_spiral_y = prev_base_y + math.sin(perpendicular_angle) * math.cos(prev_spiral_angle) * spiral_radius
                            
                            draw.line((*wave_color, wave_alpha//2), (int(prev_spiral_x), int(prev_spiral_y)), 
                                           (int(spiral_x), int(spiral_y)), 1)
                
                # 외곽 글로우 효과 - 여러 개의 선으로 글로우 표현
                for i in range(5):
                    glow_alpha = 50 - i * 10
                    glow_width = beam_width + i * 8
                    glow_color = (50, 100, 255)
                    draw.line( (*glow_color, glow_alpha),
                                   (beam_start_x, beam_start_y),
                                   (beam_end_x, beam_end_y), 
                                   glow_width)
                
                # 메인 빔
                draw.line((100, 150, 255), 
                               (beam_start_x, beam_start_y), (beam_end_x, beam_end_y), beam_width)
                draw.line((150, 200, 255), 
                               (beam_start_x, beam_start_y), (beam_end_x, beam_end_y), beam_width - 6)
                draw.line((200, 230, 255), 
                               (beam_start_x, beam_start_y), (beam_end_x, beam_end_y), beam_width - 12)
                
                # 전기 스파크 효과
                for _ in range(10):
                    t = random.random()  # 0~1 사이의 빔 위치
                    spark_x = beam_start_x + int((beam_end_x - beam_start_x) * t)
                    spark_y = beam_start_y + int((beam_end_y - beam_start_y) * t)
                    spark_offset = random.randint(-beam_width, beam_width)
                    spark_x += int(math.sin(angle_rad) * spark_offset)
                    spark_y -= int(math.cos(angle_rad) * spark_offset)
                    spark_length = random.randint(10, 30)
                    spark_end_x = spark_x + random.randint(-spark_length, spark_length)
                    draw.line((255, 255, 255), 
                                   (spark_x, spark_y), (spark_end_x, spark_y), 1)
                
                # 플레이어와 충돌 체크 (선분과 사각형 충돌)
                player_center_x = PLAYER.centerx
                player_center_y = PLAYER.centery
                
                # 선분과 점 사이의 최단 거리 계산
                line_vec_x = beam_end_x - beam_start_x
                line_vec_y = beam_end_y - beam_start_y
                line_len = math.sqrt(line_vec_x**2 + line_vec_y**2)
                
                if line_len > 0:
                    t = max(0, min(1, ((player_center_x - beam_start_x) * line_vec_x + 
                                      (player_center_y - beam_start_y) * line_vec_y) / (line_len**2)))
                    closest_x = beam_start_x + t * line_vec_x
                    closest_y = beam_start_y + t * line_vec_y
                    
                    distance = math.sqrt((player_center_x - closest_x)**2 + (player_center_y - closest_y)**2)
                    
                    # 플레이어 패들과 빔의 충돌 (빔 두께 + 패들 반지름, 연막 안에 있지 않을 때만)
                    if distance < beam_width/2 + PADDLE_WIDTH/2 and not player_stunned and not is_player_in_smoke():
                        pass
                        # 플레이어 감전
                        player_stunned = True
                        player_stun_end_time = current_time + 1000  # 1초 스턴
                        
                        # 감전 효과
                        SOUND_WALL.play()  # 전기 소리 대용
            else:
                laser_cannon_active = False
                # 레이저 빔 사운드 정지
                SOUND_STAGE6_BEAM.stop()
                # 다음 레이저 쿨타임을 5~9초 랜덤으로 설정
                laser_cooldown = random.randint(5000, 9000)
        
        # 플레이어 감전 상태 체크
        if player_stunned:
            if current_time > player_stun_end_time:
                pass
                player_stunned = False
            else:
                pass
                # 감전 효과 그리기
                for _ in range(5):
                    spark_x = PLAYER.x + random.randint(0, PLAYER.width)
                    spark_y = PLAYER.y + random.randint(0, PLAYER.height)
                    spark_size = random.randint(3, 8)
                    draw.circle((150, 200, 255), (spark_x, spark_y), spark_size)
                    draw.circle((255, 255, 255), (spark_x, spark_y), spark_size - 2)
    
    # === 쉴드 안테나 시스템 (스테이지 6) ===
    if current_stage == 6:
        current_time = pygame.time.get_ticks()
        
        # 체력이 70% 이하일 때만 쉴드 작동
        health_percent = (boss_current_health / boss_max_health) * 100
        
        # 쉴드 활성화 체크 (체력 70% 이하일 때만)
        if health_percent <= 70 and not shield_antenna_active and current_time - last_shield_time > shield_antenna_cooldown:
            shield_antenna_active = True
            shield_antenna_timer = current_time
            shield_fade_alpha = 255
            # 쉴드 위치 랜덤 설정 (왼쪽 또는 오른쪽)
            shield_position = random.choice(['left', 'right'])
            # 다음 쉴드 쿨다운 랜덤 설정
            shield_antenna_cooldown = random.randint(10000, 15000)
        
        # 쉴드 그리기 및 충돌 처리
        if shield_antenna_active:
            shield_elapsed = current_time - shield_antenna_timer
            
            if shield_elapsed < shield_duration:
                pass
                # 쉴드 위치에 따라 중심점 설정
                if shield_position == 'left':
                    pass
                    # 왼쪽 대각선 (8시 방향 바라봄)
                    shield_center_x = BOSS.left - 50
                    shield_center_y = BOSS.bottom + 50
                    start_angle = 100  # 8시 방향 (100도~160도)
                    end_angle = 160
                elif shield_position == 'right':
                    pass
                    # 오른쪽 대각선 (4시 방향 바라봄)
                    shield_center_x = BOSS.right + 50
                    shield_center_y = BOSS.bottom + 50
                    start_angle = 20  # 4시 방향 (20도~80도)
                    end_angle = 80
                else:  # center - 삭제하고 left/right만 사용
                    pass
                    # 랜덤하게 left 또는 right 선택
                    if random.random() < 0.5:
                        pass
                        # 왼쪽 대각선 (8시 방향)
                        shield_center_x = BOSS.left - 50
                        shield_center_y = BOSS.bottom + 50
                        start_angle = 100
                        end_angle = 160
                    else:
                        pass
                        # 오른쪽 대각선 (4시 방향)
                        shield_center_x = BOSS.right + 50
                        shield_center_y = BOSS.bottom + 50
                        start_angle = 20
                        end_angle = 80
                
                shield_radius = 80  # 더 큰 쉴드
                
                # 페이드 효과
                if shield_elapsed > shield_duration - 500:  # 마지막 0.5초 페이드 아웃
                    shield_fade_alpha = int(255 * (shield_duration - shield_elapsed) / 500)
                
                # 초승달 모양 그리기
                shield_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
                
                # 여러 개의 호를 겹쳐서 초승달 효과
                for arc_num in range(3):
                    arc_radius = shield_radius + arc_num * 5
                    arc_alpha = shield_fade_alpha // (1 + arc_num)
                    arc_thickness = 3 - arc_num
                    
                    # 호 그리기
                    for angle_deg in range(start_angle, end_angle):
                        angle = math.radians(angle_deg)
                        x1 = shield_center_x + int(math.cos(angle) * arc_radius)
                        y1 = shield_center_y + int(math.sin(angle) * arc_radius)
                        
                        next_angle = math.radians(angle_deg + 1)
                        x2 = shield_center_x + int(math.cos(next_angle) * arc_radius)
                        y2 = shield_center_y + int(math.sin(next_angle) * arc_radius)
                        
                        pygame.draw.line(shield_surface, (220, 240, 255, arc_alpha), 
                                       (x1, y1), (x2, y2), arc_thickness)
                
                # 빛나는 효과
                for i in range(2):
                    glow_alpha = shield_fade_alpha // (3 + i * 2)
                    glow_radius = shield_radius + 10 + i * 8
                    
                    for angle_deg in range(start_angle, end_angle, 3):
                        angle = math.radians(angle_deg)
                        x = shield_center_x + int(math.cos(angle) * glow_radius)
                        y = shield_center_y + int(math.sin(angle) * glow_radius)
                        pygame.draw.circle(shield_surface, (200, 220, 255, glow_alpha), (x, y), 2)
                
                SCREEN.blit(shield_surface, (0, 0))
                
                # 쉴드 테두리 빛나는 입자
                for _ in range(5):
                    angle = random.uniform(math.radians(start_angle), math.radians(end_angle))
                    particle_dist = shield_radius + random.randint(-5, 5)
                    particle_x = shield_center_x + int(math.cos(angle) * particle_dist)
                    particle_y = shield_center_y + int(math.sin(angle) * particle_dist)
                    draw.circle((255, 255, 255), (particle_x, particle_y), 2)
                
                # 공과 쉴드 충돌 체크
                ball_center_x = BALL.centerx
                ball_center_y = BALL.centery
                distance_to_shield = math.sqrt((ball_center_x - shield_center_x)**2 + 
                                              (ball_center_y - shield_center_y)**2)
                
                # 공의 각도 계산 (쉴드 중심 기준)
                ball_angle = math.degrees(math.atan2(ball_center_y - shield_center_y, 
                                                     ball_center_x - shield_center_x))
                if ball_angle < 0:
                    ball_angle += 360
                
                # 공이 쉴드 호의 범위 내에 있고 적절한 거리에 있을 때 충돌
                angle_in_range = start_angle <= ball_angle <= end_angle
                distance_in_range = (shield_radius - 10) < distance_to_shield < (shield_radius + 20)
                
                # 공이 쉴드에 닿으면 튕겨냄
                if angle_in_range and distance_in_range and ball_vel[1] < 0:
                    pass
                    # 공을 반사
                    ball_vel[1] = abs(ball_vel[1])
                    
                    # 반사 이펙트
                    SOUND_WALL.play()
                    for _ in range(10):
                        spark_angle = random.uniform(0, math.pi * 2)
                        spark_dist = random.uniform(0, 20)
                        spark_x = ball_center_x + int(math.cos(spark_angle) * spark_dist)
                        spark_y = ball_center_y + int(math.sin(spark_angle) * spark_dist)
                        draw.circle((255, 255, 255), (spark_x, spark_y), random.randint(1, 3))
            else:
                pass
                # 쉴드 비활성화
                shield_antenna_active = False
                last_shield_time = current_time
    
    # === 인터셉터 시스템 (스타크래프트 캐리어 스타일) ===
    if current_stage == 6:
        current_time = pygame.time.get_ticks()
        health_percent = (boss_current_health / boss_max_health) * 100
        
        # 체력이 30% 이하일 때만 작동
        if health_percent <= 30:
            pass
            # 인터셉터 출격 체크 (혼란 상태가 아닐 때만)
            if not interceptor_launching and current_time - interceptor_launch_time > interceptor_cooldown and boss_confused_timer == 0:
                pass
                # 출격 준비
                interceptor_launching = True
                hangar_door_open = True
                hangar_door_timer = current_time
                # 3~4기 출격 대기 (기존 4~6기에서 25% 감소)
                num_interceptors = random.randint(3, 4)
                for i in range(num_interceptors):
                    interceptor_launch_queue.append({
                        'launch_time': current_time + 200 * i,  # 0.2초 간격으로 출격
                        'id': f"interceptor_{current_time}_{i}"
                    })
                # 다음 출격 쿨다운 설정 (시간도 늘려서 빈도 감소)
                interceptor_cooldown = random.randint(15000, 18000)
            
            # 격납고 문 애니메이션
            if hangar_door_open:
                door_elapsed = current_time - hangar_door_timer
                if door_elapsed < 1000:  # 1초간 열림
                    pass
                    # 격납고 문 그리기
                    door_width = int(40 * (door_elapsed / 1000))
                    door_x = BOSS.centerx - 20
                    door_y = BOSS.bottom - 10
                    draw.rect((40, 40, 50), (door_x, door_y, door_width, 15))
                    draw.rect((20, 20, 30), (door_x, door_y, door_width, 15), 2)
                    # 내부 빛
                    draw.rect((100, 150, 200), (door_x + 2, door_y + 2, door_width - 4, 11))
                else:
                    pass
                    # 문 완전 열림
                    door_x = BOSS.centerx - 20
                    door_y = BOSS.bottom - 10
                    draw.rect((40, 40, 50), (door_x, door_y, 40, 15))
                    draw.rect((100, 150, 200), (door_x + 2, door_y + 2, 36, 11))
            
            # 인터셉터 출격
            if interceptor_launch_queue:
                to_launch = []
                for interceptor_data in interceptor_launch_queue:
                    if current_time >= interceptor_data['launch_time']:
                        pass
                        # 인터셉터 생성
                        new_interceptor = {
                            'id': interceptor_data['id'],
                            'x': BOSS.centerx,
                            'y': BOSS.bottom,
                            'target_x': BOSS.centerx + random.randint(-150, 150),
                            'target_y': BOSS.bottom + random.randint(80, 150),
                            'speed': 3,
                            'angle': 0,
                            'state': 'launching',  # launching, patrolling, intercepting, returning
                            'patrol_center_x': 0,
                            'patrol_center_y': 0,
                            'health': 1,  # 한 번 맞으면 파괴
                            'glow_timer': 0
                        }
                        interceptors.append(new_interceptor)
                        to_launch.append(interceptor_data)
                        SOUND_WALL.play()  # 출격 사운드
                
                # 출격한 인터셉터 제거
                for launched in to_launch:
                    interceptor_launch_queue.remove(launched)
                
                # 모든 인터셉터가 출격했으면
                if not interceptor_launch_queue:
                    interceptor_launching = False
                    interceptor_launch_time = current_time
                    # 격납고 문 닫기 타이머
                    hangar_door_timer = current_time + 1000
            
            # 격납고 문 닫기
            if not interceptor_launching and hangar_door_open:
                if current_time - hangar_door_timer > 500:  # 0.5초 후 닫기
                    hangar_door_open = False
            
            # 인터셉터 업데이트 및 그리기
            for interceptor in interceptors[:]:
                # 상태에 따른 이동
                if interceptor['state'] == 'launching':
                    pass
                    # 목표 위치로 이동
                    dx = interceptor['target_x'] - interceptor['x']
                    dy = interceptor['target_y'] - interceptor['y']
                    dist = math.sqrt(dx**2 + dy**2)
                    
                    if dist > 5:
                        interceptor['x'] += (dx / dist) * interceptor['speed']
                        interceptor['y'] += (dy / dist) * interceptor['speed']
                    else:
                        pass
                        # 목표 도착, 순찰 시작
                        interceptor['state'] = 'patrolling'
                        interceptor['patrol_center_x'] = interceptor['x']
                        interceptor['patrol_center_y'] = interceptor['y']
                
                elif interceptor['state'] == 'patrolling':
                    pass
                    # 원형 순찰
                    interceptor['angle'] += 0.05
                    patrol_radius = 30
                    interceptor['x'] = interceptor['patrol_center_x'] + math.cos(interceptor['angle']) * patrol_radius
                    interceptor['y'] = interceptor['patrol_center_y'] + math.sin(interceptor['angle']) * patrol_radius
                    
                    # 공과의 거리 체크
                    ball_dist = math.sqrt((BALL.centerx - interceptor['x'])**2 + 
                                         (BALL.centery - interceptor['y'])**2)
                    
                    # 공이 가까이 오면 요격 준비
                    if ball_dist < 100 and ball_vel[1] < 0:  # 공이 위로 올라가는 중
                        interceptor['state'] = 'intercepting'
                
                elif interceptor['state'] == 'intercepting':
                    pass
                    # 공을 향해 이동
                    dx = BALL.centerx - interceptor['x']
                    dy = BALL.centery - interceptor['y']
                    dist = math.sqrt(dx**2 + dy**2)
                    
                    if dist > 5:
                        interceptor['x'] += (dx / dist) * interceptor['speed'] * 2  # 빠른 이동
                        interceptor['y'] += (dy / dist) * interceptor['speed'] * 2
                    
                    # 공과 충돌 체크
                    if dist < 20:
                        pass
                        # 공 튀김
                        ball_vel[1] = abs(ball_vel[1])
                        ball_vel[0] += random.uniform(-2, 2)
                        
                        # 인터셉터 파괴
                        interceptors.remove(interceptor)
                        
                        # 폭발 이펙트
                        SOUND_STAGE6_INTERCEPTOR_HIT.play()
                        for _ in range(15):
                            spark_angle = random.uniform(0, math.pi * 2)
                            spark_dist = random.uniform(0, 25)
                            spark_x = interceptor['x'] + math.cos(spark_angle) * spark_dist
                            spark_y = interceptor['y'] + math.sin(spark_angle) * spark_dist
                            draw.circle((255, 200, 100), 
                                             (int(spark_x), int(spark_y)), random.randint(2, 4))
                        continue
                    
                    # 공이 멀어지면 다시 순찰
                    if dist > 150 or ball_vel[1] > 0:
                        interceptor['state'] = 'patrolling'
                
                # 인터셉터 그리기
                interceptor['glow_timer'] += 0.1
                glow = abs(math.sin(interceptor['glow_timer'])) * 50
                
                # 본체 (삼각형 모양)
                points = []
                for angle in range(3):
                    angle_rad = math.radians(angle * 120 + interceptor['angle'] * 50)
                    px = interceptor['x'] + math.cos(angle_rad) * 8
                    py = interceptor['y'] + math.sin(angle_rad) * 8
                    points.append((px, py))
                
                # 그림자
                shadow_points = [(p[0] + 2, p[1] + 2) for p in points]
                draw.polygon((30, 30, 40), shadow_points)
                
                # 본체
                draw.polygon((100, 120, 140), points)
                draw.polygon((150, 170, 190), points, 2)
                
                # 에너지 코어
                draw.circle((100 + glow, 150 + glow, 255), 
                                 (int(interceptor['x']), int(interceptor['y'])), 3)
                draw.circle((255, 255, 255), 
                                 (int(interceptor['x']), int(interceptor['y'])), 1)
                
                # 추진 효과
                if interceptor['state'] in ['launching', 'intercepting']:
                    pass
                    # 이동 방향 계산
                    if interceptor['state'] == 'launching':
                        move_dx = interceptor['target_x'] - interceptor['x']
                        move_dy = interceptor['target_y'] - interceptor['y']
                    else:  # intercepting
                        move_dx = BALL.centerx - interceptor['x']
                        move_dy = BALL.centery - interceptor['y']
                    
                    move_dist = math.sqrt(move_dx**2 + move_dy**2)
                    
                    for i in range(3):
                        trail_x = interceptor['x'] - (move_dx/move_dist if move_dist > 0 else 0) * i * 5
                        trail_y = interceptor['y'] - (move_dy/move_dist if move_dist > 0 else 0) * i * 5
                        trail_alpha = 100 - i * 30
                        draw.circle((100, 150, 200), 
                                         (int(trail_x), int(trail_y)), 4 - i)
    
    # 목성 띠 애니메이션 그리기 (무중력벨트 + 스피드기어 시너지)
    if gravity_speed_synergy:
        draw_jupiter_ring(SCREEN, PLAYER)

    # === HUD ===
    # 테스트: StageRenderer 사용
    if current_stage == 3 and tears_active:
        stage_renderer.draw('tears', tears_data=falling_tears, stage=current_stage, img=TEAR_IMG)
    # draw_tears()  # 원본 백업
    
    # 🆕 새로운 보스전에서는 UI 요소들 숨기기
    if not new_boss_mode_active:
        pass
        # 장인 아이템이 있으면 쿨타임 10% 감소 (0.8초), 쿨타임 아이템이 있으면 2.4초 추가 감소
        cooldown_reduction = 800 if master_obtained else 0  # 10% of 8000ms
        cooldown_reduction += 2400 if cooltime_obtained else 0  # 30% of 8000ms
        items.draw_active_item(SCREEN, active_item_slot, active_item_icon_size, selected_item_index, 8000 - cooldown_reduction)  # 쿨타임
        items.draw_items(SCREEN)
        draw_player_gauge()  # 플레이어 게이지바
    
    # 말풍선 그리기 (항상 그려야 함)
    draw_speech()
    
    # === Stage 3 멘헤라걸 게이지바 (세일러문 요술봉 스타일) ===
    if current_stage == 3:
        pass
        # 요술봉 위치와 크기
        wand_x = WIDTH - 50  # 오른쪽에서 50px
        wand_y = 30  # 상단에서 30px
        wand_height = 100  # 전체 높이
        
        time_now = pygame.time.get_ticks()
        
        # 🌙 상단 달 장식 (반달 모양)
        moon_radius = 12
        moon_center_x = wand_x
        moon_center_y = wand_y
        
        # 달 배경 (금색 테두리)
        draw.circle((255, 215, 0), (moon_center_x, moon_center_y), moon_radius + 2)
        draw.circle((255, 255, 200), (moon_center_x, moon_center_y), moon_radius)
        
        # 반달 효과 (오른쪽을 가림)
        draw.circle((20, 20, 40), (moon_center_x + 5, moon_center_y), moon_radius - 2)
        
        # ⭐ 별 장식 (달 주변)
        star_offset = 20
        star_size = 4
        # 작은 별들 애니메이션
        twinkle = abs(math.sin(time_now * 0.003)) * 0.5 + 0.5
        star_color = (255, int(255 * twinkle), int(255 * twinkle))
        
        # 왼쪽 별
        draw.circle(star_color, (moon_center_x - star_offset, moon_center_y), star_size)
        # 오른쪽 별
        draw.circle(star_color, (moon_center_x + star_offset, moon_center_y - 5), star_size - 1)
        # 아래 별
        draw.circle(star_color, (moon_center_x + 10, moon_center_y + 15), star_size - 2)
        
        # 💎 보석 몸체 (육각형 스타일)
        gem_y = wand_y + 25
        gem_height = 60
        gem_width = 24
        
        # 보석 외곽선 (금색)
        gem_points = [
            (wand_x, gem_y),  # 상단
            (wand_x + gem_width//2, gem_y + gem_height//3),  # 오른쪽 상단
            (wand_x + gem_width//2, gem_y + gem_height*2//3),  # 오른쪽 하단
            (wand_x, gem_y + gem_height),  # 하단
            (wand_x - gem_width//2, gem_y + gem_height*2//3),  # 왼쪽 하단
            (wand_x - gem_width//2, gem_y + gem_height//3),  # 왼쪽 상단
        ]
        draw.polygon((255, 215, 0), gem_points, 3)
        
        # 보석 내부 배경 (반투명 분홍색)
        inner_gem_points = [
            (wand_x, gem_y + 3),
            (wand_x + gem_width//2 - 3, gem_y + gem_height//3),
            (wand_x + gem_width//2 - 3, gem_y + gem_height*2//3),
            (wand_x, gem_y + gem_height - 3),
            (wand_x - gem_width//2 + 3, gem_y + gem_height*2//3),
            (wand_x - gem_width//2 + 3, gem_y + gem_height//3),
        ]
        draw.polygon((40, 20, 40), inner_gem_points)
        
        # 게이지 채우기 (보석 내부에 마법 에너지)
        if displayed_boss_gauge > 0:
            fill_ratio = displayed_boss_gauge / 500
            fill_height = int((gem_height - 6) * fill_ratio)
            
            # 그라데이션 효과를 위한 세그먼트
            segments = 5
            for i in range(segments):
                segment_y = gem_y + gem_height - 3 - (fill_height * (i + 1) // segments)
                segment_height = fill_height // segments
                
                # 게이지 레벨별 색상 변화
                if displayed_boss_gauge <= 170:
                    pass
                    # 은빛 → 연분홍
                    color_intensity = 200 + (55 * i // segments)
                    segment_color = (color_intensity, color_intensity, 255)
                elif displayed_boss_gauge <= 350:
                    pass
                    # 연분홍 → 진분홍
                    color_intensity = 255 - (55 * i // segments)
                    segment_color = (255, color_intensity, 255)
                elif displayed_boss_gauge <= 499:
                    pass
                    # 진보라색
                    color_intensity = 200 - (50 * i // segments)
                    segment_color = (200, color_intensity, 255)
                else:
                    pass
                    # 무지개 효과
                    rainbow_index = int((time_now // 100 + i) % 7)
                    rainbow_colors = [(255,0,0), (255,165,0), (255,255,0), (0,255,0), (0,127,255), (0,0,255), (139,0,255)]
                    segment_color = rainbow_colors[rainbow_index]
                
                # 각 세그먼트를 육각형 모양에 맞춰 그리기
                if segment_y > gem_y + 3 and segment_y < gem_y + gem_height - 3:
                    pass
                    # 육각형 너비 계산
                    relative_y = (segment_y - gem_y) / gem_height
                    if relative_y < 0.33:
                        pass
                        width = int(gem_width * (relative_y * 3))
                    elif relative_y < 0.67:
                        pass
                        width = gem_width - 6
                    else:
                        width = int(gem_width * ((1 - relative_y) * 3))
                    
                    if width > 0:
                        draw.rect( segment_color,
                                       (wand_x - width//2, segment_y, width, segment_height))
        
        # ✨ 마법 반짝임 효과
        if displayed_boss_gauge >= 350:  # 파워 레벨 이상일 때
            sparkle_count = 3 if displayed_boss_gauge < 500 else 5
            for i in range(sparkle_count):
                sparkle_angle = (time_now * 0.002 + i * 2 * math.pi / sparkle_count) % (2 * math.pi)
                sparkle_x = wand_x + int(15 * math.cos(sparkle_angle))
                sparkle_y = gem_y + gem_height//2 + int(15 * math.sin(sparkle_angle))
                sparkle_size = int(2 + abs(math.sin(time_now * 0.005 + i)) * 2)
                draw.circle((255, 255, 255), (sparkle_x, sparkle_y), sparkle_size)
        
        # 🎀 하단 리본 장식
        ribbon_y = gem_y + gem_height + 5
        ribbon_width = 30
        ribbon_height = 8
        
        # 리본 중앙
        draw.ellipse( (255, 20, 147), 
                          (wand_x - ribbon_width//2, ribbon_y, ribbon_width, ribbon_height))
        # 리본 매듭
        draw.circle((255, 105, 180), (wand_x, ribbon_y + ribbon_height//2), 5)
        
        # 게이지 준비 상태 표시 (전체 요술봉 깜빡임 + 후광)
        if boss_special_ready:
            if (time_now // 250) % 2 == 0:
                pass
                # 후광 효과
                for radius in range(30, 10, -5):
                    alpha = 255 - (radius - 10) * 8
                    glow_color = (255, 200, 255, alpha)
                    draw.circle(glow_color[:3], (wand_x, gem_y + gem_height//2), radius, 2)
        
        # 🔢 멘헤라걸 게이지바 아래에 숫자 표시 (현재/최대)
        boss_gauge_text = f"{int(displayed_boss_gauge)}/500"
        boss_text_color = (255, 255, 255) if displayed_boss_gauge < 500 else (255, 255, 100)  # 만렙일 때는 노란색
        
        # 폰트 로드 (작은 크기)
        try:
            boss_gauge_font = pygame.font.Font("NanumSquareB.ttf", 14)
        except:
            boss_gauge_font = pygame.font.Font(None, 14)
        
        boss_gauge_text_surface = boss_gauge_font.render(boss_gauge_text, True, boss_text_color)
        boss_text_rect = boss_gauge_text_surface.get_rect()
        
        # 요술봉 아래쪽에 중앙 정렬
        boss_text_x = wand_x - boss_text_rect.width // 2
        boss_text_y = ribbon_y + ribbon_height + 10  # 리본 아래 10픽셀
        
        # 텍스트 배경 (반투명 검은 배경으로 가독성 향상)
        boss_text_bg_rect = pygame.Rect(boss_text_x - 2, boss_text_y - 1, boss_text_rect.width + 4, boss_text_rect.height + 2)
        draw.rect((0, 0, 0, 180), boss_text_bg_rect, border_radius=3)
        draw.rect((100, 100, 100), boss_text_bg_rect, 1, border_radius=3)
        
        # 텍스트 렌더링
        SCREEN.blit(boss_gauge_text_surface, (boss_text_x, boss_text_y))

        # === Stage 5 홍련폭염 게이지 - 용이 물고있는 신비로운 구슬 ===
    if current_stage == 5:
        pass
        # 구슬 크기와 간격
        orb_radius = 10  # 30% 작게 조정 (14 -> 10)
        spacing = 30  # 간격도 조정
        total_width = (orb_radius * 2 + spacing) * HONGRYUN_MAX_HITS - spacing
        start_x = WIDTH - total_width - 40  # 오른쪽 여백
        start_y = 30
        
        time_now = pygame.time.get_ticks()
        
        for i in range(HONGRYUN_MAX_HITS):
            orb_x = start_x + i * (orb_radius * 2 + spacing)
            
            # 🐉 용의 머리 그리기 (구슬 위) - 크기 조정
            dragon_color = (180, 40, 40) if i < hongryun_hit_count else (60, 60, 60)
            
            # 용의 머리 (삼각형) - 비율 조정
            dragon_head = [
                (orb_x - 6, start_y - orb_radius - 6),
                (orb_x + 6, start_y - orb_radius - 6),
                (orb_x, start_y - orb_radius - 11)
            ]
            draw.polygon(dragon_color, dragon_head)
            
            # 용의 눈 (활성화시 빛남) - 크기 조정
            if i < hongryun_hit_count:
                eye_glow = int(abs(math.sin(time_now * 0.005 + i)) * 100 + 155, 0)
                draw.circle((eye_glow, eye_glow, 0), (orb_x - 2, start_y - orb_radius - 7), 1)
                draw.circle((eye_glow, eye_glow, 0), (orb_x + 2, start_y - orb_radius - 7), 1)
            
            # 🔮 영롱한 구슬 그리기
            if i < hongryun_hit_count:
                pass
                # 활성화된 구슬 - 다층 레이어로 영롱함 표현
                
                # 외부 광륜 (펄스 효과) - 더 붉은 색상
                pulse = abs(math.sin(time_now * 0.003 + i * 0.5))
                halo_radius = orb_radius + 5 + pulse * 3
                halo_color = (255, 50 + int(pulse * 30), 30)
                for r in range(3):
                    alpha = 60 - r * 20
                    draw.circle( (*halo_color, alpha), 
                                     (orb_x, start_y), int(halo_radius - r), 1)
                
                # 메인 구슬 (붉은 물이 차오르는 효과)
                for layer in range(5):
                    layer_radius = orb_radius - layer * 2
                    if layer_radius > 0:
                        pass
                        # 더 붉은 색상으로 변경
                        if layer == 0:  # 외곽 - 진한 붉은색
                            pass
                            color = (180, 20, 20)
                        elif layer == 1:
                            pass
                            color = (220, 30, 30)
                        elif layer == 2:
                            pass
                            color = (255, 50, 40)
                        elif layer == 3:
                            pass
                            color = (255, 80, 60)
                        else:  # 중심 - 밝은 붉은색
                            color = (255, 120, 100)
                        
                        draw.circle(color, (orb_x, start_y), layer_radius)
                
                # 내부 불꽃 효과 - 붉은 핵
                flame_offset = math.sin(time_now * 0.008 + i) * 2
                draw.circle((255, 100, 80), 
                                 (orb_x + int(flame_offset), start_y), 2)
                
                # 빛 반사 효과 (하이라이트) - 크기 조정
                draw.circle((255, 200, 200), 
                                 (orb_x - 3, start_y - 3), 2)
                draw.circle((255, 240, 240), 
                                 (orb_x - 2, start_y - 2), 1)
                
                # 신비로운 불꽃 파티클 - 붉은 불씨
                if random.random() < 0.3:  # 30% 확률로 파티클 생성
                    for _ in range(2):
                        particle_angle = random.random() * math.pi * 2
                        particle_dist = orb_radius + random.randint(2, 6)
                        particle_x = orb_x + int(math.cos(particle_angle) * particle_dist)
                        particle_y = start_y + int(math.sin(particle_angle) * particle_dist)
                        particle_size = random.randint(1, 2)
                        draw.circle((255, 80, 40), 
                                         (particle_x, particle_y), particle_size)
                
            else:
                pass
                # 비활성 구슬 - 어둡고 투명한 느낌
                # 외곽 테두리
                draw.circle((50, 50, 50), (orb_x, start_y), orb_radius, 2)
                
                # 내부 (투명한 유리구슬 느낌)
                for layer in range(3):
                    layer_radius = orb_radius - layer * 3
                    if layer_radius > 0:
                        color = (40 + layer * 10, 40 + layer * 10, 40 + layer * 10)
                        draw.circle(color, (orb_x, start_y), layer_radius)
                
                # 희미한 하이라이트
                draw.circle((70, 70, 70), 
                                 (orb_x - 3, start_y - 3), 2)
            
            # 🐉 용의 턱 (구슬 아래) - 크기 조정
            jaw_points = [
                (orb_x - 7, start_y + orb_radius + 2),
                (orb_x - 4, start_y + orb_radius + 5),
                (orb_x + 4, start_y + orb_radius + 5),
                (orb_x + 7, start_y + orb_radius + 2)
            ]
            draw.lines(dragon_color, jaw_points, False, 2)
            
            # 용의 이빨 (활성화시만) - 크기 조정
            if i < hongryun_hit_count:
                for tooth_x in [-4, -1, 1, 4]:
                    draw.line((255, 255, 200), 
                                   (orb_x + tooth_x, start_y + orb_radius + 2),
                                   (orb_x + tooth_x, start_y + orb_radius + 4), 1)
