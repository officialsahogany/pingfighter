"""
draw_aircraft_carrier_boss 함수 - 건담 스타일 전투 로봇 전신 (130x40)
"""

import pygame
import math
import random

def draw_aircraft_carrier_boss(boss_speed=0, boss_x=0):
    """스테이지 6 네메시스 - 건담 스타일 공중부양 전투 로봇 (전신, 130x40)"""
    import random
    global laser_cannon_angle, laser_charging, laser_cannon_active, laser_charge_start
    global shield_antenna_active, stage6_boss_hit_timer, stage6_boss_hit_flash

    if stage6_boss_hit_timer > 0:
        stage6_boss_hit_timer -= 1
        stage6_boss_hit_flash = (stage6_boss_hit_timer // 4) % 2 == 0
        if stage6_boss_hit_timer <= 0:
            stage6_boss_hit_flash = False

    W = 130
    H = 40
    surface = pygame.Surface((W, H), pygame.SRCALPHA)

    damage_ratio = 1.0 - (boss_current_health / boss_max_health)
    t = pygame.time.get_ticks()
    cx = W // 2  # 65

    def hit(c):
        if stage6_boss_hit_flash:
            return (min(255, c[0] + 120), max(0, c[1] - 30), max(0, c[2] - 30))
        return c

    # 색상
    navy = hit((28, 38, 58))
    navy_m = hit((42, 55, 78))
    navy_l = hit((58, 72, 98))
    white = hit((175, 185, 200))
    white_l = hit((200, 210, 225))
    white_d = hit((140, 150, 168))
    blue = hit((55, 100, 175))
    blue_l = hit((80, 135, 210))
    blue_d = hit((35, 68, 130))
    gold = hit((215, 185, 80))
    gold_l = hit((240, 215, 120))
    red = hit((195, 55, 45))
    eye_g = (0, 230, 120)

    hover = math.sin(t * 0.005) * 1  # 부유 바운스 (작게)

    # ============================================================
    # 하부 부유 글로우
    # ============================================================
    hp = 0.6 + 0.4 * abs(math.sin(t * 0.006))
    for i in range(3):
        gr = 15 + i * 5
        ga = int((35 - i * 10) * hp)
        gs = pygame.Surface((gr * 2, 4), pygame.SRCALPHA)
        pygame.draw.ellipse(gs, (60, 140, 255, max(3, ga)), (0, 0, gr * 2, 4))
        surface.blit(gs, (cx - gr, 37 + i))

    # ============================================================
    # 다리 (Legs) - 하단 Y:28~38
    # ============================================================
    leg_y = 28 + int(hover)
    for side in [-1, 1]:
        lx = cx + side * 10

        # 허벅지
        pygame.draw.rect(surface, navy_m, (lx - 3, leg_y, 6, 5))
        # 무릎 관절
        pygame.draw.circle(surface, navy, (lx, leg_y + 5), 2)
        # 정강이
        pygame.draw.rect(surface, white_d, (lx - 3, leg_y + 6, 6, 4))
        pygame.draw.rect(surface, white, (lx - 2, leg_y + 7, 4, 3))
        # 발 (부스터 노즐)
        pygame.draw.rect(surface, navy, (lx - 4, leg_y + 10, 8, 3))
        # 발 부스터 글로우
        thrust_p = 0.5 + 0.5 * abs(math.sin(t * 0.01 + side))
        thrust_c = (int(60 + thrust_p * 50), int(130 + thrust_p * 60), int(220 + thrust_p * 35))
        pygame.draw.rect(surface, thrust_c, (lx - 3, leg_y + 12, 6, 2))

        # 사이드 스커트 (허벅지 옆)
        sk = [
            (lx + side * 4, leg_y - 1),
            (lx + side * 9, leg_y),
            (lx + side * 10, leg_y + 5),
            (lx + side * 5, leg_y + 4),
        ]
        pygame.draw.polygon(surface, blue_d, sk)
        pygame.draw.polygon(surface, navy_l, sk, 1)

    # 프론트 스커트 (중앙)
    fsk = [(cx - 6, leg_y - 1), (cx + 6, leg_y - 1),
           (cx + 7, leg_y + 4), (cx - 7, leg_y + 4)]
    pygame.draw.polygon(surface, blue, fsk)
    pygame.draw.polygon(surface, navy_l, fsk, 1)

    # ============================================================
    # 몸통 (Torso) - Y:14~28
    # ============================================================
    torso_y = 14 + int(hover)

    # 몸통 프레임
    torso = [
        (cx - 18, torso_y + 2),
        (cx - 20, torso_y + 6),
        (cx - 18, torso_y + 14),
        (cx - 8, torso_y + 14),
        (cx + 8, torso_y + 14),
        (cx + 18, torso_y + 14),
        (cx + 20, torso_y + 6),
        (cx + 18, torso_y + 2),
    ]
    pygame.draw.polygon(surface, navy, torso)

    # 흉부 V자 장갑 (건담 특유)
    chest_v = [
        (cx, torso_y + 1),
        (cx - 15, torso_y + 7),
        (cx - 12, torso_y + 10),
        (cx, torso_y + 6),
        (cx + 12, torso_y + 10),
        (cx + 15, torso_y + 7),
    ]
    pygame.draw.polygon(surface, white, chest_v)
    pygame.draw.line(surface, white_l, (cx, torso_y + 2), (cx - 14, torso_y + 7), 1)
    pygame.draw.line(surface, white_l, (cx, torso_y + 2), (cx + 14, torso_y + 7), 1)

    # 콕핏 해치
    cock = [
        (cx, torso_y + 4), (cx - 4, torso_y + 6),
        (cx - 3, torso_y + 9), (cx + 3, torso_y + 9),
        (cx + 4, torso_y + 6),
    ]
    pygame.draw.polygon(surface, navy, cock)
    gp = 0.7 + 0.3 * abs(math.sin(t * 0.003))
    pygame.draw.polygon(surface, (int(30 * gp), int(60 + 40 * gp), int(100 + 50 * gp)), [
        (cx, torso_y + 5), (cx - 3, torso_y + 6),
        (cx - 2, torso_y + 8), (cx + 2, torso_y + 8), (cx + 3, torso_y + 6),
    ])

    # 리액터 코어
    ry = torso_y + 10
    rp = 0.5 + 0.5 * abs(math.sin(t * 0.007))
    # 글로우
    rg_s = int(5 + rp * 2)
    rg_sf = pygame.Surface((rg_s * 2, rg_s * 2), pygame.SRCALPHA)
    pygame.draw.circle(rg_sf, (60, 160, 255, int(40 * rp)), (rg_s, rg_s), rg_s)
    surface.blit(rg_sf, (cx - rg_s, ry - rg_s))
    pygame.draw.circle(surface, blue_d, (cx, ry), 3)
    pygame.draw.circle(surface, (80, 180, 255), (cx, ry), 2)
    pygame.draw.circle(surface, (255, 255, 255), (cx - 1, ry - 1), 1)

    # 복부
    pygame.draw.rect(surface, white_d, (cx - 6, torso_y + 11, 12, 3))
    pygame.draw.line(surface, navy_l, (cx - 4, torso_y + 12), (cx + 4, torso_y + 12), 1)

    # 몸통 테두리
    pygame.draw.polygon(surface, navy_l, torso, 1)

    # ============================================================
    # 양팔 (Arms) - 어깨~손
    # ============================================================
    for side in [-1, 1]:
        ax = cx + side * 20

        # 어깨 아머 (숄더 번더)
        sh = [
            (ax - side * 3, torso_y + 1 + int(hover)),
            (ax + side * 14, torso_y - 1 + int(hover)),
            (ax + side * 17, torso_y + 4 + int(hover)),
            (ax + side * 15, torso_y + 10 + int(hover)),
            (ax + side * 8, torso_y + 12 + int(hover)),
            (ax - side * 1, torso_y + 10 + int(hover)),
        ]
        pygame.draw.polygon(surface, blue, sh)
        # 상면 하이라이트
        pygame.draw.polygon(surface, blue_l, sh[:3] + [sh[-1]])
        pygame.draw.polygon(surface, blue_d, sh, 1)

        # 어깨 벤트
        vp = abs(math.sin(t * 0.005 + side))
        vc = (int(60 + vp * 40), int(120 + vp * 60), int(200 + vp * 55))
        vx = ax + side * 8
        vy = torso_y + 5 + int(hover)
        pygame.draw.rect(surface, vc, (vx - 2, vy, 4, 2))

        # 상완
        ua_x = ax + side * 14
        ua_y = torso_y + 10 + int(hover)
        pygame.draw.rect(surface, white_d, (ua_x - 2, ua_y, 4, 6))
        pygame.draw.rect(surface, white, (ua_x - 1, ua_y + 1, 2, 4))
        # 관절
        pygame.draw.circle(surface, navy, (ua_x, ua_y + 6), 2)

        # 전완
        fa_x = ax + side * 18
        fa_y = torso_y + 16 + int(hover)
        fa = [
            (fa_x - side * 3, fa_y),
            (fa_x + side * 5, fa_y - 1),
            (fa_x + side * 7, fa_y + 4),
            (fa_x + side * 5, fa_y + 8),
            (fa_x - side * 2, fa_y + 7),
        ]
        pygame.draw.polygon(surface, white_d, fa)
        pygame.draw.polygon(surface, navy_l, fa, 1)

        # 핸드
        hx = fa_x + side * 5
        hy = fa_y + 7
        pygame.draw.circle(surface, navy, (hx, hy), 2)

        # 전완 무장
        mx = fa_x + side * 3
        my = fa_y + 5
        pygame.draw.rect(surface, navy, (mx - 1, my, 3, 2))
        if boss_current_health > 8:
            wp = abs(math.sin(t * 0.006 + side * 2))
            pygame.draw.circle(surface, (int(100 + wp * 60), int(160 + wp * 50), 255), (mx, my + 2), 1)

    # ============================================================
    # 머리 (Head) - Y:2~14
    # ============================================================
    head_y = 3 + int(hover)

    # 목
    pygame.draw.rect(surface, navy, (cx - 3, head_y + 9, 6, 3))

    # 헬멧
    helm = [
        (cx, head_y),
        (cx - 8, head_y + 3),
        (cx - 9, head_y + 7),
        (cx - 7, head_y + 10),
        (cx - 4, head_y + 11),
        (cx + 4, head_y + 11),
        (cx + 7, head_y + 10),
        (cx + 9, head_y + 7),
        (cx + 8, head_y + 3),
    ]
    pygame.draw.polygon(surface, white, helm)

    # 페이스 플레이트
    face = [
        (cx - 6, head_y + 5),
        (cx + 6, head_y + 5),
        (cx + 7, head_y + 8),
        (cx + 5, head_y + 10),
        (cx - 5, head_y + 10),
        (cx - 7, head_y + 8),
    ]
    pygame.draw.polygon(surface, navy, face)

    # 치크 가드 (빨강)
    for side in [-1, 1]:
        ck = [
            (cx + side * 5, head_y + 7),
            (cx + side * 8, head_y + 6),
            (cx + side * 8, head_y + 9),
            (cx + side * 5, head_y + 10),
        ]
        pygame.draw.polygon(surface, red, ck)

    # 듀얼 아이
    ep = 0.7 + 0.3 * abs(math.sin(t * 0.008))
    for side in [-1, 1]:
        ex = cx + side * 3
        ey = head_y + 7
        # 글로우
        egs = pygame.Surface((8, 6), pygame.SRCALPHA)
        pygame.draw.ellipse(egs, (0, int(200 * ep), int(100 * ep), int(50 * ep)), (0, 0, 8, 6))
        surface.blit(egs, (ex - 4, ey - 3))
        # 아이
        pygame.draw.ellipse(surface, eye_g, (ex - 2, ey - 1, 4, 3))
        pygame.draw.ellipse(surface, (120, 255, 180), (ex - 1, ey, 2, 1))

    # 이마 센서 (빨강)
    pygame.draw.circle(surface, red, (cx, head_y + 4), 1)

    # V핀
    vfy = head_y
    # 좌
    pygame.draw.polygon(surface, gold, [
        (cx - 1, vfy + 1), (cx - 10, vfy - 4),
        (cx - 8, vfy - 3), (cx, vfy + 1),
    ])
    pygame.draw.polygon(surface, gold_l, [
        (cx - 1, vfy + 1), (cx - 10, vfy - 4),
        (cx - 8, vfy - 3), (cx, vfy + 1),
    ], 1)
    # 우
    pygame.draw.polygon(surface, gold, [
        (cx + 1, vfy + 1), (cx + 10, vfy - 4),
        (cx + 8, vfy - 3), (cx, vfy + 1),
    ])
    pygame.draw.polygon(surface, gold_l, [
        (cx + 1, vfy + 1), (cx + 10, vfy - 4),
        (cx + 8, vfy - 3), (cx, vfy + 1),
    ], 1)

    # 헬멧 엣지
    if damage_ratio < 0.5:
        pygame.draw.polygon(surface, white_d, helm, 1)

    # ============================================================
    # 백팩 스러스터 (좌우)
    # ============================================================
    for side in [-1, 1]:
        bx = cx + side * 18
        by = torso_y + 1 + int(hover)
        # 백팩 본체
        bp = [
            (bx - side * 1, by),
            (bx + side * 5, by - 1),
            (bx + side * 6, by + 8),
            (bx + side * 3, by + 10),
            (bx - side * 1, by + 9),
        ]
        pygame.draw.polygon(surface, navy, bp)
        pygame.draw.polygon(surface, navy_m, bp, 1)

        # 스러스터 노즐
        for j in range(2):
            ny = by + 4 + j * 3
            nx = bx + side * 4
            pygame.draw.circle(surface, (40, 48, 58), (nx, ny), 2)
            # 이동 시 화염
            if abs(boss_speed) > 0.3:
                tp = 0.6 + 0.4 * abs(math.sin(t * 0.015 + j))
                fc = (int(100 + tp * 80), int(160 + tp * 60), 255)
                pygame.draw.ellipse(surface, fc, (nx - 1, ny + 2, 3, 2))

    # ============================================================
    # 쉴드 안테나 (어깨)
    # ============================================================
    if shield_antenna_active:
        for side in [-1, 1]:
            ax = cx + side * 28
            ay = torso_y + 4 + int(hover)
            pygame.draw.circle(surface, (195, 215, 255), (ax, ay), 3)
            pygame.draw.circle(surface, (255, 255, 255), (ax, ay), 1)
            for ri in range(2):
                rr = 4 + ri * 2 + int(abs(math.sin(t * 0.01 + ri)))
                rs = pygame.Surface((rr * 2 + 2, rr * 2 + 2), pygame.SRCALPHA)
                pygame.draw.circle(rs, (140, 200, 255, max(15, 50 - ri * 20)), (rr + 1, rr + 1), rr, 1)
                surface.blit(rs, (ax - rr - 1, ay - rr - 1))

    # ============================================================
    # 레이저 캐논 (리액터)
    # ============================================================
    if laser_charging:
        cp = min(1.0, (t - laser_charge_start) / 1500.0)
        for _ in range(int(4 * cp)):
            pa = random.uniform(0, math.pi * 2)
            pd = random.uniform(5, 15 * (1 - cp))
            px = cx + int(math.cos(pa) * pd)
            py = ry + int(math.sin(pa) * pd)
            pygame.draw.circle(surface, (100, int(150 + 100 * cp), 255), (px, py), 1)
        cr = int(3 + 4 * cp)
        pygame.draw.circle(surface, (140, 200, 255), (cx, ry), cr)
        pygame.draw.circle(surface, (255, 255, 255), (cx, ry), max(1, cr - 2))

    # ============================================================
    # CIWS 미사일 (기존 호환)
    # ============================================================
    global turret_angles, turret_missiles, last_missile_time
    current_time = pygame.time.get_ticks()

    defense_positions = [
        (cx - 30, torso_y + 4 + int(hover)), (cx - 18, torso_y + 8 + int(hover)),
        (cx + 18, torso_y + 8 + int(hover)), (cx + 30, torso_y + 4 + int(hover)),
        (cx - 10, leg_y + 2), (cx + 10, leg_y + 2),
    ]

    for idx, (dx, dy) in enumerate(defense_positions):
        turret_id = f"turret_{idx}_{dx}_{dy}"
        if turret_id not in turret_angles:
            turret_angles[turret_id] = random.randint(0, 360)
        turret_angles[turret_id] = (turret_angles[turret_id] + 1) % 120

        if boss_current_health > 0 and random.random() < 0.0015 and boss_confused_timer == 0:
            missile_x = boss_x + dx
            missile_y = BOSS_Y + dy + 10
            angle_for_missile = math.radians(90 + random.randint(-30, 30))
            missile_speed = random.uniform(2, 4)
            turret_missiles.append({
                'x': missile_x, 'y': missile_y,
                'vx': math.cos(angle_for_missile) * missile_speed,
                'vy': math.sin(angle_for_missile) * missile_speed,
                'age': 0, 'turret_id': turret_id
            })

    # ============================================================
    # 손상 효과
    # ============================================================
    if damage_ratio > 0.3:
        for _ in range(int(damage_ratio * 3)):
            sx = random.randint(cx - 25, cx + 25)
            sy = random.randint(5, 35) + int(hover)
            pygame.draw.circle(surface, random.choice([(150, 200, 255), (255, 200, 100)]), (sx, sy), 1)

    if damage_ratio > 0.5:
        for _ in range(int(damage_ratio * 2)):
            sx = random.randint(cx - 20, cx + 20)
            sy = random.randint(8, 32) + int(hover)
            cl = random.randint(3, 7)
            pygame.draw.line(surface, (35, 40, 48),
                           (sx, sy), (sx + random.randint(-cl, cl), sy + random.randint(-2, 2)), 1)

    health_pct = (boss_current_health / boss_max_health) * 100
    if health_pct <= 50:
        sn = 2 if health_pct > 30 else (3 if health_pct > 10 else 5)
        for _ in range(sn):
            sx = random.randint(cx - 20, cx + 20)
            sy = random.randint(6, 30) + int(hover)
            ss = pygame.Surface((8, 8), pygame.SRCALPHA)
            pygame.draw.circle(ss, (60, 60, 60, 30), (4, 4), 4)
            surface.blit(ss, (sx - 4, sy - 4))

    if health_pct <= 30:
        fi = 1.0 if health_pct > 10 else 2.0
        for _ in range(2 if health_pct > 10 else 4):
            fx = random.randint(cx - 18, cx + 18)
            fy = random.randint(8, 28) + int(hover)
            fw = abs(math.sin(t * 0.01 + fx))
            pygame.draw.circle(surface, (255, 255, 200), (fx, fy), int(2 * fi * (0.8 + fw * 0.2)))
            fs = pygame.Surface((6, 6), pygame.SRCALPHA)
            pygame.draw.circle(fs, (255, 100, 30, 120), (3, 3), 3)
            surface.blit(fs, (fx - 3, fy - 3))

    if health_pct <= 10 and random.random() < 0.2:
        ex = random.randint(cx - 15, cx + 15)
        ey = random.randint(8, 28) + int(hover)
        es = random.randint(6, 10)
        pygame.draw.circle(surface, (255, 255, 255), (ex, ey), es)
        pygame.draw.circle(surface, (255, 200, 100), (ex, ey), es - 2)

    return surface
