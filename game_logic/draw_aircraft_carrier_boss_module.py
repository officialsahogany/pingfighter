"""
draw_aircraft_carrier_boss 함수 - 고퀄리티 울트라 배틀크루저 (v2)
"""

import pygame
import math
import random

def draw_aircraft_carrier_boss(boss_speed=0, boss_x=0):
    """⚔️ 스테이지 6 울트라 배틀크루저 - 최강의 전함 보스 패들 (고퀄리티 v2)"""
    import random
    global laser_cannon_angle, laser_charging, laser_cannon_active, laser_charge_start
    global shield_antenna_active, stage6_boss_hit_timer, stage6_boss_hit_flash

    # 🎯 소닉 스타일 피격 효과 타이머 업데이트
    if stage6_boss_hit_timer > 0:
        stage6_boss_hit_timer -= 1
        stage6_boss_hit_flash = (stage6_boss_hit_timer // 4) % 2 == 0
        if stage6_boss_hit_timer <= 0:
            stage6_boss_hit_flash = False

    carrier_width = 220
    carrier_height = 85

    carrier_surface = pygame.Surface((carrier_width, carrier_height), pygame.SRCALPHA)

    damage_ratio = 1.0 - (boss_current_health / boss_max_health)
    time_now = pygame.time.get_ticks()

    def apply_hit_effect(color):
        if stage6_boss_hit_flash:
            r, g, b = color[:3]
            return (min(255, r + 120), max(0, g - 30), max(0, b - 30))
        return color

    # ============================================================
    # === 1. 함선 실루엣 (각진 스텔스 구축함 형태) ===
    # ============================================================
    # 뾰족한 함수(bow)가 아래(플레이어 방향), 함미(stern)가 위쪽
    cx = carrier_width // 2  # 110

    # 외곽 선체 폴리곤 (스텔스 구축함 실루엣)
    hull_outline = [
        (cx, 82),           # 함수 첨단 (하단 중앙 - 플레이어 방향)
        (cx - 30, 72),      # 함수 좌측
        (cx - 55, 62),      # 좌현 전방
        (cx - 80, 50),      # 좌현 중앙
        (cx - 95, 38),      # 좌현 후방
        (cx - 90, 22),      # 함미 좌측
        (cx - 75, 15),      # 함미 좌 코너
        (cx + 75, 15),      # 함미 우 코너
        (cx + 90, 22),      # 함미 우측
        (cx + 95, 38),      # 우현 후방
        (cx + 80, 50),      # 우현 중앙
        (cx + 55, 62),      # 우현 전방
        (cx + 30, 72),      # 함수 우측
    ]

    # --- 선체 다층 렌더링 (아래서 위로) ---

    # 최하부 그림자
    shadow_hull = [(x + 2, y + 2) for x, y in hull_outline]
    pygame.draw.polygon(carrier_surface, (15, 18, 22, 120), shadow_hull)

    # 하부 선체 (짙은 메탈)
    hull_base = apply_hit_effect((45, 52, 62))
    pygame.draw.polygon(carrier_surface, hull_base, hull_outline)

    # 중부 선체 (한 단계 밝은 영역 - 약간 안쪽)
    hull_mid_points = [
        (cx, 78),
        (cx - 26, 69), (cx - 50, 60), (cx - 73, 48),
        (cx - 86, 37), (cx - 82, 23), (cx - 68, 18),
        (cx + 68, 18), (cx + 82, 23), (cx + 86, 37),
        (cx + 73, 48), (cx + 50, 60), (cx + 26, 69),
    ]
    hull_mid_color = apply_hit_effect((62, 72, 85) if damage_ratio < 0.5 else (55, 62, 72))
    pygame.draw.polygon(carrier_surface, hull_mid_color, hull_mid_points)

    # 상부 갑판 (가장 밝은 영역 - 더 안쪽)
    deck_points = [
        (cx, 74),
        (cx - 22, 66), (cx - 44, 57), (cx - 65, 46),
        (cx - 78, 36), (cx - 74, 24), (cx - 60, 20),
        (cx + 60, 20), (cx + 74, 24), (cx + 78, 36),
        (cx + 65, 46), (cx + 44, 57), (cx + 22, 66),
    ]
    deck_color = apply_hit_effect((78, 90, 105) if damage_ratio < 0.3 else (68, 78, 90))
    pygame.draw.polygon(carrier_surface, deck_color, deck_points)

    # 갑판 상부 하이라이트 라인
    highlight_color = (100, 115, 132)
    for i in range(len(deck_points) - 1):
        pygame.draw.line(carrier_surface, highlight_color, deck_points[i], deck_points[i + 1], 1)
    pygame.draw.line(carrier_surface, highlight_color, deck_points[-1], deck_points[0], 1)

    # ============================================================
    # === 2. 장갑판 패널 시스템 (대각선 기하학 패턴) ===
    # ============================================================
    panel_base = (95, 108, 125) if boss_current_health > 10 else (80, 90, 105)
    panel_glow = (115, 140, 175) if boss_current_health > 12 else (95, 115, 140)

    # 좌현 장갑판 (대각선 배치)
    armor_panels_left = [
        (cx - 70, 30, 20, 12), (cx - 55, 38, 22, 11),
        (cx - 42, 47, 20, 10), (cx - 28, 55, 18, 10),
    ]
    # 우현 장갑판 (대칭)
    armor_panels_right = [
        (cx + 50, 30, 20, 12), (cx + 33, 38, 22, 11),
        (cx + 22, 47, 20, 10), (cx + 10, 55, 18, 10),
    ]

    for panels in [armor_panels_left, armor_panels_right]:
        for px, py, pw, ph in panels:
            # 패널 외곽 (3D 입체감)
            pygame.draw.rect(carrier_surface, (55, 65, 78), (px - 1, py - 1, pw + 2, ph + 2))
            pygame.draw.rect(carrier_surface, apply_hit_effect(panel_base), (px, py, pw, ph))
            # 패널 테두리 하이라이트
            pygame.draw.rect(carrier_surface, panel_glow, (px, py, pw, ph), 1)
            # 에너지 라인 (펄스 효과)
            pulse = abs(math.sin(time_now * 0.003 + px * 0.05))
            line_color = (int(100 + pulse * 35), int(120 + pulse * 40), int(140 + pulse * 55))
            pygame.draw.line(carrier_surface, line_color, (px + 2, py + ph // 2), (px + pw - 2, py + ph // 2), 1)
            # 에너지 코어 포인트
            core_x = px + pw // 2
            core_y = py + ph // 2
            pygame.draw.circle(carrier_surface, panel_glow, (core_x, core_y), 2)
            if boss_current_health > 8:
                pygame.draw.circle(carrier_surface, (170, 200, 240), (core_x, core_y), 1)

    # ============================================================
    # === 3. 비행갑판 (Flight Deck) - 중앙 활주로 ===
    # ============================================================
    # 활주로 영역 (함선 중앙 세로 방향)
    runway_color = apply_hit_effect((70, 80, 95))
    runway_light = (90, 105, 120)

    # 중앙 활주로 바닥
    runway_points = [
        (cx - 12, 24), (cx + 12, 24),
        (cx + 15, 45), (cx + 10, 68),
        (cx - 10, 68), (cx - 15, 45),
    ]
    pygame.draw.polygon(carrier_surface, runway_color, runway_points)
    pygame.draw.polygon(carrier_surface, runway_light, runway_points, 1)

    # 활주로 중앙선 (파선)
    for i in range(5):
        line_y = 28 + i * 9
        line_len = 5
        pygame.draw.line(carrier_surface, (140, 155, 175), (cx, line_y), (cx, line_y + line_len), 1)

    # 착함 유도등 (활주로 양쪽 점멸)
    for i in range(6):
        light_y = 26 + i * 8
        light_pulse = abs(math.sin(time_now * 0.008 + i * 0.4))
        light_alpha = int(120 + light_pulse * 135)
        light_color = (light_alpha, min(255, light_alpha + 30), min(255, int(180 + light_pulse * 75)))
        pygame.draw.circle(carrier_surface, light_color, (cx - 10, light_y), 1)
        pygame.draw.circle(carrier_surface, light_color, (cx + 10, light_y), 1)

    # 착함 마크 (원형)
    pygame.draw.circle(carrier_surface, (100, 115, 135), (cx, 50), 6, 1)
    pygame.draw.line(carrier_surface, (100, 115, 135), (cx - 4, 50), (cx + 4, 50), 1)
    pygame.draw.line(carrier_surface, (100, 115, 135), (cx, 46), (cx, 54), 1)

    # ============================================================
    # === 4. 구조적 디테일 (리벳, 섹션 라인) ===
    # ============================================================
    rivet_color = (115, 128, 142)

    # 종방향 구조 라인 (함선 길이 방향)
    struct_lines = [
        ((cx - 40, 25), (cx - 18, 68)),
        ((cx + 40, 25), (cx + 18, 68)),
        ((cx - 65, 28), (cx - 35, 60)),
        ((cx + 65, 28), (cx + 35, 60)),
    ]
    for start, end in struct_lines:
        pygame.draw.line(carrier_surface, (85, 95, 110), start, end, 1)

    # 횡방향 구조 라인 (프레임 라인)
    for y_offset in [30, 42, 55]:
        # 좌현~우현 곡선 대신 직선으로 단순화
        left_x = max(cx - 80, cx - int(90 - (y_offset - 20) * 0.8))
        right_x = min(cx + 80, cx + int(90 - (y_offset - 20) * 0.8))
        pygame.draw.line(carrier_surface, rivet_color, (left_x, y_offset), (right_x, y_offset), 1)
        # 리벳 포인트
        for rx in range(left_x + 10, right_x, 15):
            pygame.draw.circle(carrier_surface, rivet_color, (rx, y_offset), 1)

    # ============================================================
    # === 5. 야마토 캐논급 주포 터렛 시스템 ===
    # ============================================================
    # 함선 형태에 맞춰 곡선 배치
    turret_positions = [
        (cx - 60, 35), (cx - 35, 48), (cx - 15, 60),
        (cx + 15, 60), (cx + 35, 48), (cx + 60, 35),
    ]
    for idx, (tx, ty) in enumerate(turret_positions):
        # 터렛 베이스 (다층 구조 + 그림자)
        pygame.draw.circle(carrier_surface, (40, 48, 58), (tx + 1, ty + 1), 9)  # 그림자
        pygame.draw.circle(carrier_surface, apply_hit_effect((50, 58, 70)), (tx, ty), 9)
        pygame.draw.circle(carrier_surface, apply_hit_effect((65, 75, 88)), (tx, ty), 7)
        pygame.draw.circle(carrier_surface, apply_hit_effect((80, 92, 108)), (tx, ty), 5)

        # 듀얼 포신 (쌍발) - 아래(플레이어) 방향
        gun_angle = math.sin(time_now * 0.00001 + tx * 0.01) * 2
        for barrel_offset in [-2, 2]:
            barrel_x = tx + barrel_offset
            gun_end_x = barrel_x + int(14 * math.cos(math.radians(90 + gun_angle)))
            gun_end_y = ty + int(14 * math.sin(math.radians(90 + gun_angle)))

            # 포신 그라데이션
            pygame.draw.line(carrier_surface, (38, 45, 55), (barrel_x, ty), (gun_end_x, gun_end_y), 4)
            pygame.draw.line(carrier_surface, (55, 65, 78), (barrel_x, ty), (gun_end_x - 1, gun_end_y - 1), 3)
            pygame.draw.line(carrier_surface, (72, 82, 95), (barrel_x, ty), (gun_end_x - 2, gun_end_y - 2), 2)

        # 터렛 중앙 에너지 코어
        pygame.draw.circle(carrier_surface, (140, 168, 200), (tx, ty), 3)
        pygame.draw.circle(carrier_surface, (175, 205, 235), (tx - 1, ty - 1), 1)

    # ============================================================
    # === 6. 사령부 브릿지 타워 (파고다식 다층 구조) ===
    # ============================================================
    bridge_x = cx + 42  # 우현 약간 후방

    # 브릿지 기초 플랫폼
    pygame.draw.rect(carrier_surface, (48, 55, 65), (bridge_x - 3, 20, 46, 28))
    pygame.draw.rect(carrier_surface, apply_hit_effect((68, 78, 92)), (bridge_x - 1, 18, 42, 26))

    # 중간층 (전투지휘소 - CIC)
    bridge_mid = apply_hit_effect((85, 95, 112) if boss_current_health > 5 else (70, 78, 88))
    pygame.draw.rect(carrier_surface, bridge_mid, (bridge_x + 3, 14, 34, 20))
    # CIC 수평 디테일 라인
    for i in range(4):
        pygame.draw.line(carrier_surface, (105, 118, 135),
                        (bridge_x + 5 + i * 8, 16), (bridge_x + 5 + i * 8, 30), 1)

    # 최상층 (전망대/함장실)
    bridge_top = apply_hit_effect((95, 108, 125) if boss_current_health > 3 else (78, 88, 100))
    pygame.draw.rect(carrier_surface, bridge_top, (bridge_x + 7, 10, 26, 13))
    # 상층 하이라이트
    pygame.draw.line(carrier_surface, (120, 135, 155), (bridge_x + 7, 10), (bridge_x + 33, 10), 1)

    # 통합 마스트 (안테나 타워)
    pygame.draw.rect(carrier_surface, (108, 120, 135), (bridge_x + 18, 4, 4, 8))
    pygame.draw.line(carrier_surface, (128, 140, 158), (bridge_x + 20, 4), (bridge_x + 20, 1), 2)

    # 파노라마 브릿지 창문 시스템 (5개)
    for i in range(5):
        window_x = bridge_x + 8 + i * 5
        pygame.draw.rect(carrier_surface, (85, 95, 108), (window_x - 1, 11, 5, 9), 1)
        glow_i = int(140 + 60 * abs(math.sin(time_now * 0.002 + i * 0.3)))
        pygame.draw.rect(carrier_surface, (glow_i, min(255, glow_i + 30), 200), (window_x, 12, 3, 7))
        pygame.draw.line(carrier_surface, (195, 215, 245), (window_x, 12), (window_x + 2, 12), 1)

    # ============================================================
    # === 7. 위상 배열 레이더 시스템 (페이저 어레이) ===
    # ============================================================
    radar_x = bridge_x + 20
    # 레이더 베이스 돔
    pygame.draw.circle(carrier_surface, (72, 82, 95), (radar_x, 8), 7)
    pygame.draw.circle(carrier_surface, (108, 125, 148), (radar_x, 8), 5)
    pygame.draw.circle(carrier_surface, (130, 150, 172), (radar_x, 8), 3)

    # 멀티 레이어 레이더 스캔 (극저속 회전)
    radar_angle = time_now * 0.00005
    for r in range(1, 4):
        angle_offset = radar_angle + r * 0.2
        scan_range = 6 + r * 2
        antenna_end_x = radar_x + scan_range * math.cos(angle_offset)
        antenna_end_y = 8 + scan_range * math.sin(angle_offset)
        scan_color = (min(255, 75 + r * 15), min(255, 95 + r * 15), min(255, 115 + r * 15))
        pygame.draw.line(carrier_surface, scan_color, (radar_x, 8), (int(antenna_end_x), int(antenna_end_y)), 2)

    # 레이더 코어 펄스
    pulse = abs(math.sin(time_now * 0.005))
    core_color = (int(175 + pulse * 80), int(195 + pulse * 60), 255)
    pygame.draw.circle(carrier_surface, core_color, (radar_x, 8), 2)

    # 보조 통신 안테나
    for i, ant_x in enumerate([bridge_x + 8, bridge_x + 32]):
        ant_height = 5 - i
        pygame.draw.line(carrier_surface, (150, 162, 175), (ant_x, 15), (ant_x, ant_height), 2)
        pygame.draw.circle(carrier_surface, (192, 205, 218), (ant_x, ant_height), 1)

    # ============================================================
    # === 8. 함선 좌현 무장 클러스터 (CIWS + VLS) ===
    # ============================================================
    # VLS 셀 (수직발사대) - 좌현
    vls_positions = [(cx - 80, 28), (cx - 75, 34), (cx - 68, 40)]
    for vx, vy in vls_positions:
        pygame.draw.rect(carrier_surface, (55, 62, 72), (vx - 3, vy - 3, 6, 6))
        pygame.draw.rect(carrier_surface, (75, 85, 98), (vx - 2, vy - 2, 4, 4))
        # VLS 해치 라인
        pygame.draw.line(carrier_surface, (92, 105, 118), (vx - 2, vy), (vx + 2, vy), 1)
        pygame.draw.line(carrier_surface, (92, 105, 118), (vx, vy - 2), (vx, vy + 2), 1)

    # ============================================================
    # === 9. 쉴드 안테나 시스템 ===
    # ============================================================
    shield_antenna_x = cx
    shield_antenna_y = 75

    pygame.draw.circle(carrier_surface, (88, 98, 112), (shield_antenna_x, shield_antenna_y), 5)
    pygame.draw.circle(carrier_surface, (128, 140, 155), (shield_antenna_x, shield_antenna_y), 3)
    pygame.draw.line(carrier_surface, (168, 180, 195),
                    (shield_antenna_x, shield_antenna_y),
                    (shield_antenna_x, shield_antenna_y - 8), 2)

    tip_glow = abs(math.sin(time_now * 0.003)) * 100
    if shield_antenna_active:
        pygame.draw.circle(carrier_surface, (195, 215, 255),
                          (shield_antenna_x, shield_antenna_y - 8), 4)
        pygame.draw.circle(carrier_surface, (255, 255, 255),
                          (shield_antenna_x, shield_antenna_y - 8), 2)
        # 쉴드 활성화 시 에너지 방출 이펙트
        for i in range(3):
            ring_r = 6 + i * 3 + int(abs(math.sin(time_now * 0.01 + i)) * 2)
            ring_alpha = max(30, 80 - i * 20)
            ring_surf = pygame.Surface((ring_r * 2 + 2, ring_r * 2 + 2), pygame.SRCALPHA)
            pygame.draw.circle(ring_surf, (150, 200, 255, ring_alpha), (ring_r + 1, ring_r + 1), ring_r, 1)
            carrier_surface.blit(ring_surf, (shield_antenna_x - ring_r - 1, shield_antenna_y - 8 - ring_r - 1))
    else:
        glow_value = min(255, int(145 + tip_glow))
        glow_color = (glow_value, min(255, int(165 + tip_glow)), min(255, int(195 + tip_glow)))
        pygame.draw.circle(carrier_surface, glow_color,
                          (shield_antenna_x, shield_antenna_y - 8), 3)
        pygame.draw.circle(carrier_surface, (172, 192, 215),
                          (shield_antenna_x, shield_antenna_y - 8), 1)

    # ============================================================
    # === 10. 플라즈마 레이저 캐논 (함수 하단 중앙) ===
    # ============================================================
    laser_cannon_x = cx
    laser_cannon_y = 82

    pygame.draw.circle(carrier_surface, (62, 72, 85), (laser_cannon_x, laser_cannon_y), 8)
    pygame.draw.circle(carrier_surface, (82, 95, 108), (laser_cannon_x, laser_cannon_y), 6)

    if laser_charging or laser_cannon_active:
        cannon_angle_rad = math.radians(laser_cannon_angle)
        barrel_end_x = laser_cannon_x + int(math.cos(cannon_angle_rad) * 12)
        barrel_end_y = laser_cannon_y + int(math.sin(cannon_angle_rad) * 12)

        pygame.draw.line(carrier_surface, (45, 55, 65),
                        (laser_cannon_x, laser_cannon_y), (barrel_end_x, barrel_end_y), 5)
        pygame.draw.line(carrier_surface, (65, 75, 88),
                        (laser_cannon_x, laser_cannon_y), (barrel_end_x, barrel_end_y), 3)

        if laser_charging:
            charge_progress = (time_now - laser_charge_start) / 1500.0
            charge_glow = int(255 * min(1.0, charge_progress))
            pygame.draw.circle(carrier_surface,
                             (min(255, charge_glow), min(255, charge_glow + 50), 255),
                             (barrel_end_x, barrel_end_y), int(3 + charge_progress * 3))
            for _ in range(int(5 * charge_progress)):
                spark_angle = random.uniform(0, math.pi * 2)
                spark_dist = random.uniform(5, 15)
                spark_x = barrel_end_x + int(math.cos(spark_angle) * spark_dist)
                spark_y = barrel_end_y + int(math.sin(spark_angle) * spark_dist)
                pygame.draw.circle(carrier_surface, (145, 195, 255), (spark_x, spark_y), 1)
    else:
        pygame.draw.line(carrier_surface, (45, 55, 65),
                        (laser_cannon_x, laser_cannon_y),
                        (laser_cannon_x, laser_cannon_y + 12), 5)
        pygame.draw.line(carrier_surface, (65, 75, 88),
                        (laser_cannon_x, laser_cannon_y),
                        (laser_cannon_x, laser_cannon_y + 12), 3)

    pygame.draw.circle(carrier_surface, (105, 115, 128), (laser_cannon_x, laser_cannon_y), 3)
    if laser_charging or laser_cannon_active:
        pygame.draw.circle(carrier_surface, (145, 195, 255), (laser_cannon_x, laser_cannon_y), 2)

    # ============================================================
    # === 11. 비행대대 편대 시스템 ===
    # ============================================================
    max_fighters = 10
    current_fighters = int(max_fighters * (boss_current_health / boss_max_health))

    # 함선 형태에 맞춘 V자 포메이션
    fighter_positions = [
        (cx - 50, 30), (cx - 38, 36), (cx - 26, 42), (cx - 16, 50), (cx - 8, 58),
        (cx + 50, 30), (cx + 38, 36), (cx + 26, 42), (cx + 16, 50), (cx + 8, 58),
    ]

    for i in range(current_fighters):
        if i < len(fighter_positions):
            fx, fy = fighter_positions[i]
            # 하이테크 인터셉터 (스텔스)
            fighter_body = (75, 88, 105) if i < 5 else (65, 78, 92)
            pygame.draw.polygon(carrier_surface, fighter_body,
                               [(fx, fy), (fx + 10, fy + 1), (fx + 8, fy + 3), (fx + 2, fy + 3)])
            # 날개
            wing_color = (58, 70, 85)
            pygame.draw.polygon(carrier_surface, wing_color,
                               [(fx + 3, fy + 1), (fx, fy - 2), (fx + 1, fy + 1)])
            pygame.draw.polygon(carrier_surface, wing_color,
                               [(fx + 7, fy + 1), (fx + 10, fy - 2), (fx + 9, fy + 1)])
            # 콕핏
            pygame.draw.circle(carrier_surface, (112, 132, 155), (fx + 5, fy + 1), 1)

    # ============================================================
    # === 12. 플라즈마 부스트 엔진 시스템 (좌현 4기) ===
    # ============================================================
    # 엔진을 함선 형태에 맞춰 재배치 (함미 상단)
    engine_positions = [
        (cx - 82, 24), (cx - 78, 30), (cx - 72, 36), (cx - 66, 42),
    ]
    for idx, (ex, ey) in enumerate(engine_positions):
        # 엔진 노즐 하우징
        pygame.draw.rect(carrier_surface, (38, 45, 55), (ex - 8, ey - 1, 16, 8))
        pygame.draw.rect(carrier_surface, (55, 65, 78), (ex - 6, ey, 12, 6))
        pygame.draw.rect(carrier_surface, (72, 82, 95), (ex - 4, ey + 1, 8, 4))

        boss_velocity = abs(boss_speed)
        if boss_velocity > 0.3:
            jet_length = int(12 + boss_velocity * 6)
            flame_offset = (time_now // 50) % 3

            # 외곽 화염
            for i in range(3):
                offset_y = flame_offset - 1 + i
                flame_color = (min(255, 200 + i * 15), max(50, 120 - i * 30), 20)
                pygame.draw.line(carrier_surface, flame_color,
                                (ex - 8, ey + 2 + offset_y),
                                (ex - 8 - jet_length - i * 2, ey + 2 + offset_y), 4 - i)

            # 코어 화염 (밝은 흰노랑)
            core_color = (255, 255, min(255, 180 + int(boss_velocity * 20)))
            pygame.draw.line(carrier_surface, core_color,
                            (ex - 7, ey + 3), (ex - 7 - jet_length // 2, ey + 3), 2)

            # 불꽃 파티클
            for _ in range(int(2 + boss_velocity)):
                spark_x = ex - 8 - random.randint(0, jet_length + 5)
                spark_y = ey + 3 + random.randint(-2, 2)
                spark_color = random.choice([
                    (255, random.randint(180, 255), random.randint(0, 80)),
                    (255, 255, random.randint(150, 255))
                ])
                pygame.draw.circle(carrier_surface, spark_color, (spark_x, spark_y), 1)

    # 우현 엔진 (대칭)
    engine_positions_r = [
        (cx + 82, 24), (cx + 78, 30), (cx + 72, 36), (cx + 66, 42),
    ]
    for idx, (ex, ey) in enumerate(engine_positions_r):
        pygame.draw.rect(carrier_surface, (38, 45, 55), (ex - 8, ey - 1, 16, 8))
        pygame.draw.rect(carrier_surface, (55, 65, 78), (ex - 6, ey, 12, 6))
        pygame.draw.rect(carrier_surface, (72, 82, 95), (ex - 4, ey + 1, 8, 4))

        if abs(boss_speed) > 0.3:
            jet_length = int(12 + abs(boss_speed) * 6)
            flame_offset = (time_now // 50) % 3
            for i in range(3):
                offset_y = flame_offset - 1 + i
                flame_color = (min(255, 200 + i * 15), max(50, 120 - i * 30), 20)
                pygame.draw.line(carrier_surface, flame_color,
                                (ex + 8, ey + 2 + offset_y),
                                (ex + 8 + jet_length + i * 2, ey + 2 + offset_y), 4 - i)
            core_color = (255, 255, min(255, 180 + int(abs(boss_speed) * 20)))
            pygame.draw.line(carrier_surface, core_color,
                            (ex + 7, ey + 3), (ex + 7 + jet_length // 2, ey + 3), 2)
            for _ in range(int(2 + abs(boss_speed))):
                spark_x = ex + 8 + random.randint(0, jet_length + 5)
                spark_y = ey + 3 + random.randint(-2, 2)
                spark_color = random.choice([
                    (255, random.randint(180, 255), random.randint(0, 80)),
                    (255, 255, random.randint(150, 255))
                ])
                pygame.draw.circle(carrier_surface, spark_color, (spark_x, spark_y), 1)

    # ============================================================
    # === 13. 포인트 디펜스 시스템 (CIWS 터렛) ===
    # ============================================================
    defense_positions = [
        (cx - 70, 25), (cx - 50, 32), (cx - 30, 40), (cx + 30, 40),
        (cx + 50, 32), (cx + 70, 25), (cx - 20, 52), (cx + 20, 52),
    ]

    global turret_angles, turret_missiles, last_missile_time
    current_time = pygame.time.get_ticks()

    for idx, (dx, dy) in enumerate(defense_positions):
        turret_id = f"turret_{idx}_{dx}_{dy}"
        if turret_id not in turret_angles:
            turret_angles[turret_id] = random.randint(0, 360)

        turret_angles[turret_id] = (turret_angles[turret_id] + 1) % 120
        barrel_angle = 60 + turret_angles[turret_id]
        angle_rad = math.radians(barrel_angle)

        # 터렛 베이스
        pygame.draw.circle(carrier_surface, (58, 68, 78), (dx, dy), 4)
        pygame.draw.circle(carrier_surface, (78, 88, 100), (dx, dy), 3)

        # 회전 포신
        barrel_length = 9
        barrel_end_x = dx + int(math.cos(angle_rad) * barrel_length)
        barrel_end_y = dy + int(math.sin(angle_rad) * barrel_length)
        pygame.draw.line(carrier_surface, (82, 95, 108), (dx, dy), (barrel_end_x, barrel_end_y), 3)
        pygame.draw.circle(carrier_surface, (112, 125, 138), (barrel_end_x, barrel_end_y), 2)

        # 미사일 발사
        if boss_current_health > 0 and random.random() < 0.0015 and boss_confused_timer == 0:
            missile_x = boss_x + dx
            missile_y = BOSS_Y + dy + 10
            base_angle = 90
            spread_angle = random.randint(-30, 30)
            final_angle = base_angle + spread_angle
            angle_for_missile = math.radians(final_angle)
            missile_speed = random.uniform(2, 4)
            missile_vx = math.cos(angle_for_missile) * missile_speed
            missile_vy = math.sin(angle_for_missile) * missile_speed
            new_missile = {
                'x': missile_x, 'y': missile_y,
                'vx': missile_vx, 'vy': missile_vy,
                'age': 0, 'turret_id': turret_id
            }
            turret_missiles.append(new_missile)

        # 터렛 렌즈
        pygame.draw.circle(carrier_surface, (95, 105, 118), (dx, dy), 2)

    # ============================================================
    # === 14. 항행등 (Running Lights) - 애니메이션 ===
    # ============================================================
    # 좌현 항행등 (빨간색)
    port_light_pulse = 0.5 + 0.5 * abs(math.sin(time_now * 0.004))
    port_light_color = (int(180 + port_light_pulse * 75), 30, 30)
    pygame.draw.circle(carrier_surface, port_light_color, (cx - 88, 32), 2)
    # 글로우
    port_glow_surf = pygame.Surface((12, 12), pygame.SRCALPHA)
    pygame.draw.circle(port_glow_surf, (*port_light_color, int(60 * port_light_pulse)), (6, 6), 5)
    carrier_surface.blit(port_glow_surf, (cx - 93, 27))

    # 우현 항행등 (녹색)
    stbd_light_pulse = 0.5 + 0.5 * abs(math.sin(time_now * 0.004 + 1.0))
    stbd_light_color = (30, int(180 + stbd_light_pulse * 75), 30)
    pygame.draw.circle(carrier_surface, stbd_light_color, (cx + 88, 32), 2)
    stbd_glow_surf = pygame.Surface((12, 12), pygame.SRCALPHA)
    pygame.draw.circle(stbd_glow_surf, (*stbd_light_color, int(60 * stbd_light_pulse)), (6, 6), 5)
    carrier_surface.blit(stbd_glow_surf, (cx + 83, 27))

    # 함미등 (백색)
    stern_light_pulse = 0.6 + 0.4 * abs(math.sin(time_now * 0.003))
    stern_color = (int(180 + stern_light_pulse * 75), int(185 + stern_light_pulse * 70), int(195 + stern_light_pulse * 60))
    pygame.draw.circle(carrier_surface, stern_color, (cx - 70, 17), 2)
    pygame.draw.circle(carrier_surface, stern_color, (cx + 70, 17), 2)

    # 함수 마스트 라이트 (경고등 - 파란색 점멸)
    bow_blink = int(time_now * 0.003) % 2
    if bow_blink:
        pygame.draw.circle(carrier_surface, (100, 160, 255), (cx, 78), 2)
        bow_glow = pygame.Surface((10, 10), pygame.SRCALPHA)
        pygame.draw.circle(bow_glow, (100, 160, 255, 50), (5, 5), 4)
        carrier_surface.blit(bow_glow, (cx - 5, 73))

    # 갑판 엣지 라이트 (좌우 대칭, 교대 점멸)
    for i in range(6):
        edge_phase = (time_now // 200 + i) % 6
        if edge_phase < 3:
            edge_alpha = int(100 + 80 * abs(math.sin(time_now * 0.006 + i * 0.5)))
            edge_color = (edge_alpha, min(255, edge_alpha + 20), min(255, int(180 + edge_alpha * 0.3)))
            # 좌현 엣지
            ey = 24 + i * 8
            elx = cx - int(75 - i * 6)
            pygame.draw.circle(carrier_surface, edge_color, (elx, ey), 1)
            # 우현 엣지
            erx = cx + int(75 - i * 6)
            pygame.draw.circle(carrier_surface, edge_color, (erx, ey), 1)

    # ============================================================
    # === 15. 전투 손상 시스템 ===
    # ============================================================
    if damage_ratio > 0.2:
        # 시스템 오작동 스파크
        for _ in range(int(damage_ratio * 6)):
            spark_x = random.randint(cx - 80, cx + 80)
            spark_y = random.randint(22, 72)
            spark_type = random.choice(['electric', 'plasma', 'fire'])
            if spark_type == 'electric':
                spark_color = (145, 195, 255)
            elif spark_type == 'plasma':
                spark_color = (255, 145, 255)
            else:
                spark_color = (255, 195, 95)
            pygame.draw.circle(carrier_surface, spark_color, (spark_x, spark_y), 1)

    if damage_ratio > 0.4:
        # 장갑판 균열
        for _ in range(int(damage_ratio * 4)):
            crack_x = random.randint(cx - 70, cx + 70)
            crack_y = random.randint(25, 65)
            crack_length = random.randint(5, 12)
            crack_end_x = crack_x + random.randint(-crack_length, crack_length)
            crack_end_y = crack_y + random.randint(-4, 4)
            pygame.draw.line(carrier_surface, (38, 42, 48),
                           (crack_x, crack_y), (crack_end_x, crack_end_y), 1)

    if damage_ratio > 0.5:
        # 화재 및 플라즈마 누출
        for _ in range(int(damage_ratio * 5)):
            leak_x = random.randint(cx - 65, cx + 65)
            leak_y = random.randint(25, 68)
            if random.random() < 0.6:
                pygame.draw.circle(carrier_surface, (255, 95, 0), (leak_x, leak_y), 3)
                pygame.draw.circle(carrier_surface, (255, 145, 0), (leak_x, leak_y), 2)
                pygame.draw.circle(carrier_surface, (255, 195, 45), (leak_x, leak_y), 1)
            else:
                pygame.draw.circle(carrier_surface, (95, 145, 255), (leak_x, leak_y), 2)
                pygame.draw.circle(carrier_surface, (145, 195, 255), (leak_x, leak_y), 1)
            if random.random() < 0.5:
                smoke_x = leak_x + random.randint(-4, 4)
                smoke_y = leak_y - random.randint(3, 8)
                pygame.draw.circle(carrier_surface, (48, 48, 48), (smoke_x, smoke_y), 2)

    # ============================================================
    # === 16. 체력 기반 연기/화염/폭발 ===
    # ============================================================
    health_percent = (boss_current_health / boss_max_health) * 100

    if health_percent <= 50:
        smoke_count = 3
        if health_percent <= 10:
            smoke_count = 10
        elif health_percent <= 20:
            smoke_count = 7
        elif health_percent <= 30:
            smoke_count = 5

        for _ in range(smoke_count):
            smoke_x = random.randint(cx - 70, cx + 70)
            smoke_y = random.randint(25, 60)
            for i in range(3):
                smoke_size = random.randint(6, 12) + i * 3
                smoke_alpha = random.randint(18, 50) - i * 8
                smoke_color = (55 + i * 18, 55 + i * 18, 55 + i * 18, max(5, smoke_alpha))
                smoke_circle = pygame.Surface((smoke_size * 2, smoke_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(smoke_circle, smoke_color, (smoke_size, smoke_size), smoke_size)
                offset_x = random.randint(-2, 2)
                offset_y = random.randint(-4, -1) - i * 2
                carrier_surface.blit(smoke_circle, (smoke_x - smoke_size + offset_x, smoke_y - smoke_size + offset_y))

    if health_percent <= 30:
        fire_intensity = 1.0
        fire_count = 3
        if health_percent <= 10:
            fire_intensity = 3.0
            fire_count = 7
        elif health_percent <= 20:
            fire_intensity = 2.0
            fire_count = 5

        for _ in range(fire_count):
            fire_x = random.randint(cx - 60, cx + 60)
            fire_y = random.randint(28, 62)
            flame_wave = abs(math.sin(time_now * 0.01 + fire_x))

            core_size = int(4 * fire_intensity * (0.8 + flame_wave * 0.2))
            pygame.draw.circle(carrier_surface, (255, 255, 195), (fire_x, fire_y), core_size)

            mid_size = int(6 * fire_intensity * (0.9 + flame_wave * 0.1))
            mid_surf = pygame.Surface((mid_size * 2, mid_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(mid_surf, (255, 145, 45, 175), (mid_size, mid_size), mid_size)
            carrier_surface.blit(mid_surf, (fire_x - mid_size, fire_y - mid_size))

            outer_size = int(9 * fire_intensity * (1.0 + flame_wave * 0.2))
            outer_surf = pygame.Surface((outer_size * 2, outer_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(outer_surf, (255, 45, 25, 115), (outer_size, outer_size), outer_size)
            carrier_surface.blit(outer_surf, (fire_x - outer_size, fire_y - outer_size - int(flame_wave * 3)))

            if random.random() < 0.3 * fire_intensity:
                for _ in range(int(2 * fire_intensity)):
                    spark_x = fire_x + random.randint(-12, 12)
                    spark_y = fire_y + random.randint(-8, -2)
                    spark_color = (255, random.randint(95, 195), 0)
                    pygame.draw.circle(carrier_surface, spark_color, (spark_x, spark_y), random.randint(1, 2))

    if health_percent <= 10:
        if random.random() < 0.2:
            explosion_x = random.randint(cx - 60, cx + 60)
            explosion_y = random.randint(28, 58)
            flash_size = random.randint(12, 22)
            pygame.draw.circle(carrier_surface, (255, 255, 255), (explosion_x, explosion_y), flash_size)
            pygame.draw.circle(carrier_surface, (255, 195, 95), (explosion_x, explosion_y), flash_size - 3)
            pygame.draw.circle(carrier_surface, (255, 95, 0), (explosion_x, explosion_y), flash_size - 6)
            for _ in range(6):
                debris_x = explosion_x + random.randint(-18, 18)
                debris_y = explosion_y + random.randint(-18, 18)
                debris_color = (random.randint(145, 255), random.randint(45, 145), 0)
                pygame.draw.circle(carrier_surface, debris_color, (debris_x, debris_y), random.randint(1, 3))

    # ============================================================
    # === 17. 대형 레이저 캐논 (함수 전면) ===
    # ============================================================
    cannon_x = cx
    cannon_y = 15

    pygame.draw.circle(carrier_surface, (72, 82, 95), (cannon_x, cannon_y), 12)
    pygame.draw.circle(carrier_surface, (92, 105, 118), (cannon_x, cannon_y), 10)

    cannon_barrel_length = 20
    angle_rad = math.radians(laser_cannon_angle)
    cannon_barrel_end_x = cannon_x + int(math.cos(angle_rad) * cannon_barrel_length)
    cannon_barrel_end_y = cannon_y + int(math.sin(angle_rad) * cannon_barrel_length)

    pygame.draw.line(carrier_surface, (82, 95, 108),
                     (cannon_x, cannon_y), (cannon_barrel_end_x, cannon_barrel_end_y), 8)
    pygame.draw.line(carrier_surface, (105, 118, 130),
                     (cannon_x, cannon_y), (cannon_barrel_end_x, cannon_barrel_end_y), 6)

    pygame.draw.circle(carrier_surface, (115, 125, 138),
                      (cannon_barrel_end_x, cannon_barrel_end_y), 6)
    pygame.draw.circle(carrier_surface, (135, 145, 158),
                      (cannon_barrel_end_x, cannon_barrel_end_y), 4)

    if laser_charging:
        charge_time = current_time - laser_charge_start
        charge_ratio = min(1.0, charge_time / 1000)
        for _ in range(int(8 * charge_ratio)):
            particle_angle = random.uniform(0, math.pi * 2)
            particle_dist = random.uniform(8, 25 * (1 - charge_ratio))
            particle_x = cannon_barrel_end_x + int(math.cos(particle_angle) * particle_dist)
            particle_y = cannon_barrel_end_y + int(math.sin(particle_angle) * particle_dist)
            particle_color = (95, int(145 + 100 * charge_ratio), 255)
            pygame.draw.circle(carrier_surface, particle_color,
                             (particle_x, particle_y), random.randint(1, 3))
        core_size = int(4 + 5 * charge_ratio)
        pygame.draw.circle(carrier_surface, (145, 195, 255),
                         (cannon_barrel_end_x, cannon_barrel_end_y), core_size)
        pygame.draw.circle(carrier_surface, (255, 255, 255),
                         (cannon_barrel_end_x, cannon_barrel_end_y), core_size - 2)

    # ============================================================
    # === 18. 쉴드 안테나 (함수 전면 좌우) ===
    # ============================================================
    antenna_left_x = cx - 50
    antenna_right_x = cx + 50
    antenna_y = 22

    for ant_x in [antenna_left_x, antenna_right_x]:
        pygame.draw.rect(carrier_surface, (105, 115, 128), (ant_x - 2, antenna_y, 4, 12))
        pygame.draw.circle(carrier_surface, (132, 142, 155), (ant_x, antenna_y), 4)
        pygame.draw.circle(carrier_surface, (192, 205, 215), (ant_x, antenna_y - 5), 3)
        if shield_antenna_active:
            pygame.draw.circle(carrier_surface, (255, 255, 255), (ant_x, antenna_y - 5), 2)

    # ============================================================
    # === 19. 선체 외곽 하이라이트 (최종 패스) ===
    # ============================================================
    if damage_ratio < 0.6:
        # 선체 외곽선 하이라이트 (상단)
        highlight_alpha = int(80 * (1.0 - damage_ratio))
        for i in range(len(hull_outline) - 1):
            pygame.draw.line(carrier_surface, (125, 140, 158),
                           hull_outline[i], hull_outline[i + 1], 1)
        pygame.draw.line(carrier_surface, (125, 140, 158),
                       hull_outline[-1], hull_outline[0], 1)

    return carrier_surface
