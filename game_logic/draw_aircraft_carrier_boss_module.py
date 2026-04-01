"""
draw_aircraft_carrier_boss 함수 - 건담 스타일 전투 로봇 (v3)
"""

import pygame
import math
import random

def draw_aircraft_carrier_boss(boss_speed=0, boss_x=0):
    """⚔️ 스테이지 6 네메시스 - 건담 스타일 공중부양 전투 로봇"""
    import random
    global laser_cannon_angle, laser_charging, laser_cannon_active, laser_charge_start
    global shield_antenna_active, stage6_boss_hit_timer, stage6_boss_hit_flash

    # 피격 효과 타이머
    if stage6_boss_hit_timer > 0:
        stage6_boss_hit_timer -= 1
        stage6_boss_hit_flash = (stage6_boss_hit_timer // 4) % 2 == 0
        if stage6_boss_hit_timer <= 0:
            stage6_boss_hit_flash = False

    carrier_width = 220
    carrier_height = 85
    surface = pygame.Surface((carrier_width, carrier_height), pygame.SRCALPHA)

    damage_ratio = 1.0 - (boss_current_health / boss_max_health)
    time_now = pygame.time.get_ticks()
    cx = carrier_width // 2  # 110

    def hit(color):
        if stage6_boss_hit_flash:
            r, g, b = color[:3]
            return (min(255, r + 120), max(0, g - 30), max(0, b - 30))
        return color

    # === 색상 팔레트 (건담 블루/화이트/다크네이비) ===
    navy = hit((28, 38, 58))
    navy_mid = hit((42, 55, 78))
    navy_light = hit((58, 72, 98))
    armor_white = hit((175, 185, 200))
    armor_light = hit((200, 210, 225))
    armor_mid = hit((145, 155, 172))
    armor_dark = hit((110, 120, 138))
    blue_main = hit((55, 100, 175))
    blue_light = hit((80, 135, 210))
    blue_dark = hit((35, 68, 130))
    gold = hit((215, 185, 80))
    gold_light = hit((240, 215, 120))
    red_accent = hit((195, 55, 45))
    eye_green = (0, 230, 120)
    eye_glow = (120, 255, 180)
    reactor_blue = (80, 180, 255)

    # 호버 바운스 (부유감)
    hover = math.sin(time_now * 0.004) * 2
    # 기체 기울기 (이동 방향)
    tilt = max(-3, min(3, boss_speed * 0.4))

    # ============================================================
    # === 0. 하부 부유 글로우 (공중부양 이펙트) ===
    # ============================================================
    hover_pulse = 0.6 + 0.4 * abs(math.sin(time_now * 0.006))
    for i in range(4):
        glow_r = 35 + i * 8
        glow_alpha = int((50 - i * 10) * hover_pulse)
        glow_surf = pygame.Surface((glow_r * 2, 8), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_surf, (60, 140, 255, max(5, glow_alpha)), (0, 0, glow_r * 2, 8))
        surface.blit(glow_surf, (cx - glow_r, 78 + i + int(hover)))

    # ============================================================
    # === 1. 양팔 (좌우 대칭 - 패들 역할, 펼친 상태) ===
    # ============================================================
    for side in [-1, 1]:
        arm_base_x = cx + side * 42

        # --- 어깨 아머 (숄더 번더) ---
        shoulder_points = [
            (arm_base_x - side * 5, 22 + int(hover)),
            (arm_base_x + side * 28, 18 + int(hover)),
            (arm_base_x + side * 35, 25 + int(hover)),
            (arm_base_x + side * 32, 38 + int(hover)),
            (arm_base_x + side * 22, 42 + int(hover)),
            (arm_base_x - side * 2, 40 + int(hover)),
        ]
        # 어깨 그림자
        shadow_pts = [(x + 1, y + 2) for x, y in shoulder_points]
        pygame.draw.polygon(surface, (15, 20, 30, 80), shadow_pts)
        # 어깨 본체
        pygame.draw.polygon(surface, blue_main, shoulder_points)
        # 어깨 상면 하이라이트
        top_pts = shoulder_points[:3] + [shoulder_points[-1]]
        pygame.draw.polygon(surface, blue_light, top_pts)
        # 어깨 에지 라인
        pygame.draw.polygon(surface, blue_dark, shoulder_points, 1)

        # 어깨 장갑 디테일
        detail_x = arm_base_x + side * 15
        detail_y = 28 + int(hover)
        pygame.draw.rect(surface, navy_mid, (detail_x - 5, detail_y, 10, 8))
        pygame.draw.rect(surface, navy_light, (detail_x - 4, detail_y + 1, 8, 6))
        # 어깨 에너지 벤트
        vent_pulse = abs(math.sin(time_now * 0.005 + side))
        vent_color = (int(60 + vent_pulse * 40), int(120 + vent_pulse * 60), int(200 + vent_pulse * 55))
        pygame.draw.rect(surface, vent_color, (detail_x - 3, detail_y + 2, 6, 2))

        # --- 상완 (Upper Arm) ---
        upper_arm_x = arm_base_x + side * 30
        upper_arm_y = 36 + int(hover)
        pygame.draw.rect(surface, armor_mid, (upper_arm_x - 4, upper_arm_y, 8, 14))
        pygame.draw.rect(surface, armor_white, (upper_arm_x - 3, upper_arm_y + 1, 6, 12))
        # 관절 링
        pygame.draw.circle(surface, navy, (upper_arm_x, upper_arm_y + 14), 4)
        pygame.draw.circle(surface, navy_mid, (upper_arm_x, upper_arm_y + 14), 3)
        pygame.draw.circle(surface, navy_light, (upper_arm_x, upper_arm_y + 14), 2)

        # --- 전완 (Forearm) ---
        forearm_x = arm_base_x + side * 38
        forearm_y = 48 + int(hover)
        forearm_points = [
            (forearm_x - side * 6, forearm_y),
            (forearm_x + side * 8, forearm_y - 2),
            (forearm_x + side * 12, forearm_y + 8),
            (forearm_x + side * 10, forearm_y + 18),
            (forearm_x - side * 4, forearm_y + 16),
            (forearm_x - side * 7, forearm_y + 6),
        ]
        pygame.draw.polygon(surface, armor_dark, forearm_points)
        pygame.draw.polygon(surface, armor_mid, [
            forearm_points[0], forearm_points[1], forearm_points[2], forearm_points[-1]
        ])
        pygame.draw.polygon(surface, navy_light, forearm_points, 1)

        # 전완 무장 마운트
        mount_x = forearm_x + side * 6
        mount_y = forearm_y + 10
        pygame.draw.rect(surface, navy, (mount_x - 3, mount_y - 2, 6, 6))
        pygame.draw.rect(surface, navy_mid, (mount_x - 2, mount_y - 1, 4, 4))
        # 무장 포구
        pygame.draw.circle(surface, (50, 55, 65), (mount_x, mount_y + 4), 2)
        if boss_current_health > 8:
            weapon_pulse = abs(math.sin(time_now * 0.006 + side * 2))
            pygame.draw.circle(surface, (int(100 + weapon_pulse * 60), int(160 + weapon_pulse * 50), 255),
                              (mount_x, mount_y + 4), 1)

        # --- 핸드 / 빔 사벨 마운트 ---
        hand_x = forearm_x + side * 10
        hand_y = forearm_y + 16
        pygame.draw.circle(surface, navy, (hand_x, hand_y), 3)
        pygame.draw.circle(surface, navy_mid, (hand_x, hand_y), 2)

        # 손상 시 스파크
        if damage_ratio > 0.4 and random.random() < 0.15:
            spark_x = arm_base_x + side * random.randint(15, 35)
            spark_y = random.randint(25, 55) + int(hover)
            pygame.draw.circle(surface, (200, 220, 255), (spark_x, spark_y), 1)

    # ============================================================
    # === 2. 몸통 (Torso / Core Body) ===
    # ============================================================
    torso_y = 20 + int(hover)

    # --- 몸통 메인 프레임 ---
    torso_points = [
        (cx - 32, torso_y + 2),    # 좌상
        (cx - 38, torso_y + 12),   # 좌 어깨 연결
        (cx - 35, torso_y + 35),   # 좌하
        (cx - 20, torso_y + 45),   # 좌하 스커트
        (cx + 20, torso_y + 45),   # 우하 스커트
        (cx + 35, torso_y + 35),   # 우하
        (cx + 38, torso_y + 12),   # 우 어깨 연결
        (cx + 32, torso_y + 2),    # 우상
    ]
    # 몸통 그림자
    shadow = [(x + 1, y + 2) for x, y in torso_points]
    pygame.draw.polygon(surface, (12, 15, 22, 90), shadow)
    # 몸통 본체
    pygame.draw.polygon(surface, navy, torso_points)

    # 상부 흉부 장갑 (흰색 V자 패턴 - 건담 특유)
    chest_upper = [
        (cx, torso_y + 4),         # V자 꼭지점 (중앙 상단)
        (cx - 28, torso_y + 14),   # 좌
        (cx - 25, torso_y + 22),   # 좌하
        (cx, torso_y + 16),        # 중앙
        (cx + 25, torso_y + 22),   # 우하
        (cx + 28, torso_y + 14),   # 우
    ]
    pygame.draw.polygon(surface, armor_white, chest_upper)
    # 흉부 하이라이트
    pygame.draw.line(surface, armor_light, (cx, torso_y + 5), (cx - 26, torso_y + 14), 1)
    pygame.draw.line(surface, armor_light, (cx, torso_y + 5), (cx + 26, torso_y + 14), 1)

    # 콕핏 해치 (중앙)
    cockpit_y = torso_y + 13
    cockpit_points = [
        (cx, cockpit_y - 3),
        (cx - 8, cockpit_y + 2),
        (cx - 6, cockpit_y + 8),
        (cx + 6, cockpit_y + 8),
        (cx + 8, cockpit_y + 2),
    ]
    pygame.draw.polygon(surface, navy, cockpit_points)
    pygame.draw.polygon(surface, navy_mid, cockpit_points, 1)
    # 콕핏 글래스
    glass_points = [
        (cx, cockpit_y - 1),
        (cx - 5, cockpit_y + 2),
        (cx - 4, cockpit_y + 6),
        (cx + 4, cockpit_y + 6),
        (cx + 5, cockpit_y + 2),
    ]
    glass_pulse = 0.7 + 0.3 * abs(math.sin(time_now * 0.003))
    glass_color = (int(30 * glass_pulse), int(60 + 40 * glass_pulse), int(100 + 50 * glass_pulse))
    pygame.draw.polygon(surface, glass_color, glass_points)
    # 글래스 반사
    pygame.draw.line(surface, (100, 150, 200), (cx - 3, cockpit_y + 1), (cx + 1, cockpit_y - 1), 1)

    # --- 리액터 코어 (가슴 중앙 발광체) ---
    reactor_y = torso_y + 22
    reactor_pulse = 0.5 + 0.5 * abs(math.sin(time_now * 0.007))
    # 리액터 글로우
    glow_size = int(8 + reactor_pulse * 3)
    glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
    pygame.draw.circle(glow_surf, (60, 160, 255, int(50 * reactor_pulse)), (glow_size, glow_size), glow_size)
    surface.blit(glow_surf, (cx - glow_size, reactor_y - glow_size))
    # 리액터 본체
    pygame.draw.circle(surface, blue_dark, (cx, reactor_y), 5)
    pygame.draw.circle(surface, reactor_blue, (cx, reactor_y), 4)
    pygame.draw.circle(surface, (180, 225, 255), (cx, reactor_y), 2)
    pygame.draw.circle(surface, (255, 255, 255), (cx - 1, reactor_y - 1), 1)

    # --- 복부 장갑 ---
    abdomen_y = torso_y + 28
    # 복부 중앙 패널
    pygame.draw.rect(surface, armor_dark, (cx - 12, abdomen_y, 24, 10))
    pygame.draw.rect(surface, armor_mid, (cx - 10, abdomen_y + 1, 20, 8))
    # 복부 디테일 라인
    pygame.draw.line(surface, navy_light, (cx - 8, abdomen_y + 3), (cx + 8, abdomen_y + 3), 1)
    pygame.draw.line(surface, navy_light, (cx - 6, abdomen_y + 6), (cx + 6, abdomen_y + 6), 1)

    # --- 허리 / 스커트 아머 ---
    skirt_y = torso_y + 38
    # 프론트 스커트 (3판)
    for i in range(3):
        sx = cx - 16 + i * 12
        skirt_pts = [
            (sx, skirt_y), (sx + 10, skirt_y),
            (sx + 12, skirt_y + 10), (sx - 2, skirt_y + 10),
        ]
        skirt_color = blue_main if i == 1 else navy_mid
        pygame.draw.polygon(surface, skirt_color, skirt_pts)
        pygame.draw.polygon(surface, navy_light, skirt_pts, 1)

    # 사이드 스커트
    for side in [-1, 1]:
        ss_x = cx + side * 25
        side_skirt = [
            (ss_x, skirt_y - 2), (ss_x + side * 10, skirt_y),
            (ss_x + side * 12, skirt_y + 12), (ss_x + side * 2, skirt_y + 10),
        ]
        pygame.draw.polygon(surface, blue_dark, side_skirt)
        pygame.draw.polygon(surface, navy_light, side_skirt, 1)

    # 몸통 외곽 테두리
    pygame.draw.polygon(surface, navy_light, torso_points, 1)

    # ============================================================
    # === 3. 머리 (Head Unit) ===
    # ============================================================
    head_y = 8 + int(hover)

    # 목 (넥 조인트)
    pygame.draw.rect(surface, navy, (cx - 5, head_y + 12, 10, 6))
    pygame.draw.rect(surface, navy_mid, (cx - 4, head_y + 13, 8, 4))

    # 헬멧 (메인 헤드)
    helmet_points = [
        (cx, head_y - 2),          # 정수리
        (cx - 14, head_y + 4),     # 좌상
        (cx - 16, head_y + 10),    # 좌
        (cx - 14, head_y + 15),    # 좌하
        (cx - 8, head_y + 16),     # 좌하 턱
        (cx + 8, head_y + 16),     # 우하 턱
        (cx + 14, head_y + 15),    # 우하
        (cx + 16, head_y + 10),    # 우
        (cx + 14, head_y + 4),     # 우상
    ]
    pygame.draw.polygon(surface, armor_white, helmet_points)
    # 헬멧 상부 하이라이트
    pygame.draw.line(surface, armor_light, (cx - 12, head_y + 4), (cx + 12, head_y + 4), 1)

    # 페이스 플레이트 (진한 색)
    face_points = [
        (cx - 10, head_y + 7),
        (cx + 10, head_y + 7),
        (cx + 12, head_y + 12),
        (cx + 8, head_y + 15),
        (cx - 8, head_y + 15),
        (cx - 12, head_y + 12),
    ]
    pygame.draw.polygon(surface, navy, face_points)

    # 치크 가드 (볼 장갑) - 빨간 액센트
    for side in [-1, 1]:
        cheek = [
            (cx + side * 8, head_y + 10),
            (cx + side * 13, head_y + 9),
            (cx + side * 14, head_y + 14),
            (cx + side * 9, head_y + 15),
        ]
        pygame.draw.polygon(surface, red_accent, cheek)

    # 듀얼 아이 (건담 스타일 - 녹색 발광)
    eye_pulse = 0.7 + 0.3 * abs(math.sin(time_now * 0.008))
    for side in [-1, 1]:
        eye_x = cx + side * 5
        eye_y = head_y + 10
        # 아이 글로우
        eye_glow_surf = pygame.Surface((12, 8), pygame.SRCALPHA)
        pygame.draw.ellipse(eye_glow_surf, (0, int(200 * eye_pulse), int(100 * eye_pulse), int(60 * eye_pulse)), (0, 0, 12, 8))
        surface.blit(eye_glow_surf, (eye_x - 6, eye_y - 4))
        # 아이 본체
        pygame.draw.ellipse(surface, eye_green, (eye_x - 3, eye_y - 2, 6, 4))
        pygame.draw.ellipse(surface, eye_glow, (eye_x - 2, eye_y - 1, 4, 2))
        # 동공 하이라이트
        pygame.draw.circle(surface, (255, 255, 255), (eye_x + side, eye_y - 1), 1)

    # 중앙 포어헤드 센서 (이마 카메라)
    pygame.draw.circle(surface, red_accent, (cx, head_y + 6), 2)
    pygame.draw.circle(surface, (255, 100, 80), (cx, head_y + 6), 1)

    # === V 핀 (V-Fin) - 건담의 상징 ===
    vfin_y = head_y - 1
    # 좌 V핀
    vfin_left = [
        (cx - 2, vfin_y + 2),
        (cx - 18, vfin_y - 8),
        (cx - 15, vfin_y - 7),
        (cx - 1, vfin_y + 1),
    ]
    pygame.draw.polygon(surface, gold, vfin_left)
    pygame.draw.polygon(surface, gold_light, vfin_left, 1)
    # 우 V핀
    vfin_right = [
        (cx + 2, vfin_y + 2),
        (cx + 18, vfin_y - 8),
        (cx + 15, vfin_y - 7),
        (cx + 1, vfin_y + 1),
    ]
    pygame.draw.polygon(surface, gold, vfin_right)
    pygame.draw.polygon(surface, gold_light, vfin_right, 1)

    # 헬멧 에지
    if damage_ratio < 0.5:
        pygame.draw.polygon(surface, armor_dark, helmet_points, 1)

    # ============================================================
    # === 4. 백팩 / 스러스터 유닛 (좌우) ===
    # ============================================================
    for side in [-1, 1]:
        bp_x = cx + side * 32
        bp_y = torso_y + 2

        # 백팩 본체
        bp_points = [
            (bp_x - side * 3, bp_y),
            (bp_x + side * 8, bp_y - 2),
            (bp_x + side * 10, bp_y + 15),
            (bp_x + side * 6, bp_y + 20),
            (bp_x - side * 2, bp_y + 18),
        ]
        pygame.draw.polygon(surface, navy, bp_points)
        pygame.draw.polygon(surface, navy_mid, bp_points, 1)

        # 스러스터 노즐 (2연장)
        for j in range(2):
            noz_x = bp_x + side * 5
            noz_y = bp_y + 12 + j * 6
            pygame.draw.circle(surface, (40, 48, 58), (noz_x, noz_y), 3)
            pygame.draw.circle(surface, (55, 65, 78), (noz_x, noz_y), 2)

            # 스러스터 화염 (이동 시)
            if abs(boss_speed) > 0.3:
                thrust_pulse = 0.6 + 0.4 * abs(math.sin(time_now * 0.015 + j * 1.5))
                flame_len = int(5 + abs(boss_speed) * 3)
                for fi in range(3):
                    fy = noz_y + 3 + fi * 2
                    fw = max(1, 3 - fi)
                    flame_color = (
                        int(100 + thrust_pulse * 80),
                        int(160 + thrust_pulse * 60),
                        255
                    )
                    pygame.draw.ellipse(surface, flame_color, (noz_x - fw, fy, fw * 2, 3))

        # 방열 핀
        for fi in range(3):
            fin_y = bp_y + 2 + fi * 5
            pygame.draw.line(surface, navy_light,
                           (bp_x + side * 8, fin_y), (bp_x + side * 14, fin_y - 1), 1)

    # ============================================================
    # === 5. 쉴드 안테나 시스템 ===
    # ============================================================
    shield_y = torso_y + 8 + int(hover)
    if shield_antenna_active:
        # 양 어깨에서 쉴드 에너지 방출
        for side in [-1, 1]:
            ant_x = cx + side * 40
            pygame.draw.circle(surface, (195, 215, 255), (ant_x, shield_y), 4)
            pygame.draw.circle(surface, (255, 255, 255), (ant_x, shield_y), 2)
            for ri in range(3):
                ring_r = 5 + ri * 3 + int(abs(math.sin(time_now * 0.01 + ri)) * 2)
                ring_surf = pygame.Surface((ring_r * 2 + 2, ring_r * 2 + 2), pygame.SRCALPHA)
                pygame.draw.circle(ring_surf, (140, 200, 255, max(20, 70 - ri * 20)),
                                  (ring_r + 1, ring_r + 1), ring_r, 1)
                surface.blit(ring_surf, (ant_x - ring_r - 1, shield_y - ring_r - 1))
    else:
        for side in [-1, 1]:
            ant_x = cx + side * 40
            ant_glow = abs(math.sin(time_now * 0.003)) * 60
            pygame.draw.circle(surface, (int(140 + ant_glow), int(160 + ant_glow), int(190 + ant_glow)),
                              (ant_x, shield_y), 3)

    # ============================================================
    # === 6. 레이저 캐논 (리액터 코어에서 발사) ===
    # ============================================================
    laser_y = reactor_y + 5

    if laser_charging or laser_cannon_active:
        cannon_angle_rad = math.radians(laser_cannon_angle)
        barrel_end_x = cx + int(math.cos(cannon_angle_rad) * 12)
        barrel_end_y = laser_y + int(math.sin(cannon_angle_rad) * 12)

        # 충전 이펙트
        if laser_charging:
            charge_progress = min(1.0, (time_now - laser_charge_start) / 1500.0)
            charge_glow = int(255 * charge_progress)
            # 리액터에서 에너지 수렴
            for _ in range(int(6 * charge_progress)):
                p_angle = random.uniform(0, math.pi * 2)
                p_dist = random.uniform(8, 25 * (1 - charge_progress))
                px = cx + int(math.cos(p_angle) * p_dist)
                py = laser_y + int(math.sin(p_angle) * p_dist)
                pygame.draw.circle(surface, (100, int(150 + 100 * charge_progress), 255), (px, py), 1)
            # 충전 코어
            core_r = int(4 + 5 * charge_progress)
            pygame.draw.circle(surface, (140, 200, 255), (cx, laser_y), core_r)
            pygame.draw.circle(surface, (255, 255, 255), (cx, laser_y), max(1, core_r - 2))

    # ============================================================
    # === 7. CIWS 미사일 터렛 (어깨/팔에 배치) ===
    # ============================================================
    defense_positions = [
        (cx - 55, 28 + int(hover)), (cx - 40, 35 + int(hover)),
        (cx - 25, 42 + int(hover)), (cx + 25, 42 + int(hover)),
        (cx + 40, 35 + int(hover)), (cx + 55, 28 + int(hover)),
        (cx - 15, 55 + int(hover)), (cx + 15, 55 + int(hover)),
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

        barrel_length = 8
        barrel_end_x = dx + int(math.cos(angle_rad) * barrel_length)
        barrel_end_y = dy + int(math.sin(angle_rad) * barrel_length)

        # 미사일 발사
        if boss_current_health > 0 and random.random() < 0.0015 and boss_confused_timer == 0:
            missile_x = boss_x + dx
            missile_y = BOSS_Y + dy + 10
            spread_angle = random.randint(-30, 30)
            angle_for_missile = math.radians(90 + spread_angle)
            missile_speed = random.uniform(2, 4)
            new_missile = {
                'x': missile_x, 'y': missile_y,
                'vx': math.cos(angle_for_missile) * missile_speed,
                'vy': math.sin(angle_for_missile) * missile_speed,
                'age': 0, 'turret_id': turret_id
            }
            turret_missiles.append(new_missile)

    # ============================================================
    # === 8. 전투 손상 효과 ===
    # ============================================================
    if damage_ratio > 0.2:
        for _ in range(int(damage_ratio * 5)):
            sx = random.randint(cx - 40, cx + 40)
            sy = random.randint(15, 70) + int(hover)
            spark_color = random.choice([(150, 200, 255), (255, 200, 100), (255, 150, 255)])
            pygame.draw.circle(surface, spark_color, (sx, sy), 1)

    if damage_ratio > 0.4:
        for _ in range(int(damage_ratio * 3)):
            cx2 = random.randint(cx - 30, cx + 30)
            cy2 = random.randint(20, 60) + int(hover)
            cl = random.randint(5, 10)
            pygame.draw.line(surface, (35, 40, 48),
                           (cx2, cy2), (cx2 + random.randint(-cl, cl), cy2 + random.randint(-3, 3)), 1)

    if damage_ratio > 0.5:
        for _ in range(int(damage_ratio * 4)):
            fx = random.randint(cx - 35, cx + 35)
            fy = random.randint(22, 62) + int(hover)
            if random.random() < 0.6:
                pygame.draw.circle(surface, (255, 100, 0), (fx, fy), 3)
                pygame.draw.circle(surface, (255, 150, 0), (fx, fy), 2)
                pygame.draw.circle(surface, (255, 200, 50), (fx, fy), 1)
            else:
                pygame.draw.circle(surface, (100, 150, 255), (fx, fy), 2)
                pygame.draw.circle(surface, (150, 200, 255), (fx, fy), 1)

    # 체력 50% 이하: 연기
    health_pct = (boss_current_health / boss_max_health) * 100
    if health_pct <= 50:
        smoke_n = 3 if health_pct > 30 else (5 if health_pct > 20 else (7 if health_pct > 10 else 10))
        for _ in range(smoke_n):
            sx = random.randint(cx - 35, cx + 35)
            sy = random.randint(15, 55) + int(hover)
            for si in range(3):
                s_size = random.randint(5, 10) + si * 2
                s_alpha = max(5, random.randint(15, 40) - si * 8)
                s_surf = pygame.Surface((s_size * 2, s_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(s_surf, (55 + si * 15, 55 + si * 15, 55 + si * 15, s_alpha),
                                  (s_size, s_size), s_size)
                surface.blit(s_surf, (sx - s_size, sy - s_size - si * 2))

    # 체력 30% 이하: 화염
    if health_pct <= 30:
        f_int = 1.0 if health_pct > 20 else (2.0 if health_pct > 10 else 3.0)
        f_count = 3 if health_pct > 20 else (5 if health_pct > 10 else 7)
        for _ in range(f_count):
            fx = random.randint(cx - 30, cx + 30)
            fy = random.randint(20, 55) + int(hover)
            fw = abs(math.sin(time_now * 0.01 + fx))
            cs = int(3 * f_int * (0.8 + fw * 0.2))
            pygame.draw.circle(surface, (255, 255, 200), (fx, fy), cs)
            ms = int(5 * f_int * (0.9 + fw * 0.1))
            m_surf = pygame.Surface((ms * 2, ms * 2), pygame.SRCALPHA)
            pygame.draw.circle(m_surf, (255, 150, 50, 170), (ms, ms), ms)
            surface.blit(m_surf, (fx - ms, fy - ms))

    # 체력 10% 이하: 폭발
    if health_pct <= 10 and random.random() < 0.2:
        ex = random.randint(cx - 30, cx + 30)
        ey = random.randint(20, 55) + int(hover)
        es = random.randint(10, 18)
        pygame.draw.circle(surface, (255, 255, 255), (ex, ey), es)
        pygame.draw.circle(surface, (255, 200, 100), (ex, ey), es - 2)
        pygame.draw.circle(surface, (255, 100, 0), (ex, ey), es - 5)

    return surface
