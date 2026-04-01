"""
draw_aircraft_carrier_boss 함수 - 인간형 로봇 건담 (바이퍼 스타일, 130x40)
다중 레이어 셰이딩, 관절 디테일, 에너지 도관, 리액터 발광
"""

import pygame
import math
import random

def draw_aircraft_carrier_boss(boss_speed=0, boss_x=0):
    """스테이지 6 네메시스 - 인간형 전투 로봇 (바이퍼 참고, 130x40)"""
    import random
    global laser_cannon_angle, laser_charging, laser_cannon_active, laser_charge_start
    global shield_antenna_active, stage6_boss_hit_timer, stage6_boss_hit_flash

    if stage6_boss_hit_timer > 0:
        stage6_boss_hit_timer -= 1
        stage6_boss_hit_flash = (stage6_boss_hit_timer // 4) % 2 == 0
        if stage6_boss_hit_timer <= 0:
            stage6_boss_hit_flash = False

    W, H = 130, 40
    surface = pygame.Surface((W, H), pygame.SRCALPHA)
    dmg = 1.0 - (boss_current_health / boss_max_health)
    t = pygame.time.get_ticks()
    cx = W // 2

    def hit(c):
        if stage6_boss_hit_flash:
            return (min(255, c[0] + 120), max(0, c[1] - 30), max(0, c[2] - 30))
        return c

    # ═══ 컬러 팔레트 (바이퍼 스타일 다중 셰이딩) ═══
    p = {
        # 프레임 (3단계 셰이딩)
        "frame_shadow": hit((18, 28, 48)),
        "frame_main": hit((32, 48, 72)),
        "frame_light": hit((48, 68, 98)),
        "frame_highlight": hit((62, 85, 118)),
        "frame_seam": hit((72, 95, 130)),
        # 아머 플레이트 (흰색 계열)
        "armor_shadow": hit((120, 128, 142)),
        "armor_main": hit((165, 175, 192)),
        "armor_light": hit((195, 205, 220)),
        "armor_edge": hit((210, 218, 232)),
        # 블루 아머 (숄더/스커트)
        "blue_shadow": hit((28, 55, 110)),
        "blue_main": hit((45, 85, 160)),
        "blue_light": hit((65, 115, 195)),
        "blue_edge": hit((85, 140, 215)),
        # 네온/에너지 (시안 도관)
        "neon": (80, 200, 255),
        "neon_bright": (160, 235, 255),
        "neon_dim": (40, 120, 200),
        "neon_glow": (60, 180, 255, 60),
        # 리액터 (흉부)
        "reactor": (80, 180, 255),
        "reactor_bright": (180, 230, 255),
        "reactor_core": (255, 255, 255),
        # 아이
        "eye": (0, 230, 120),
        "eye_bright": (120, 255, 180),
        "eye_glow": (0, 200, 100, 50),
        # V핀
        "vfin": hit((215, 185, 80)),
        "vfin_light": hit((240, 215, 120)),
        # 레드 액센트
        "red": hit((195, 55, 45)),
        "red_light": hit((230, 80, 65)),
        # 아웃라인
        "outline": hit((12, 18, 32)),
    }

    # ═══ 모션 (아이들 호흡 + 부유) ═══
    breath = math.sin(t * 0.004)
    sway = math.sin(t * 0.006 + 0.5)
    hover = breath * 1.0
    torso_bob = int(breath * 0.8)
    arm_swing = int(breath * 1.5 + sway * 0.8)
    lean = int(breath * 0.4)

    # 이동 시 모션 강화
    spd = abs(boss_speed)
    if spd > 0.5:
        walk_phase = (t * 0.008) % 1.0
        walk_wave = math.sin(walk_phase * math.pi * 2)
        torso_bob = int(abs(walk_wave) * 1.5)
        arm_swing = int(walk_wave * 3)

    ty = 12 + torso_bob + int(hover)  # 토르소 기준 Y

    # ════════════════════════════════════════════
    # 0. 하부 부유 글로우
    # ════════════════════════════════════════════
    gp = 0.5 + 0.5 * abs(math.sin(t * 0.006))
    for i in range(3):
        gr = 12 + i * 4
        ga = int((30 - i * 8) * gp)
        gs = pygame.Surface((gr * 2, 4), pygame.SRCALPHA)
        pygame.draw.ellipse(gs, (*p["neon"], max(3, ga)), (0, 0, gr * 2, 4))
        surface.blit(gs, (cx - gr, 37 + i))

    # ════════════════════════════════════════════
    # 1. 다리 (Legs) — 관절 디테일 + 에너지 도관
    # ════════════════════════════════════════════
    leg_y = ty + 16
    for side in [-1, 1]:
        lx = cx + side * 8

        # 허벅지 (다층 셰이딩)
        pygame.draw.rect(surface, p["frame_shadow"], (lx - 3, leg_y, 6, 5))
        pygame.draw.rect(surface, p["frame_main"], (lx - 2, leg_y + 1, 4, 4))
        # 허벅지 에너지 도관 (네온 라인)
        pygame.draw.line(surface, p["neon_dim"], (lx, leg_y + 1), (lx, leg_y + 4), 1)

        # 무릎 관절 (구체)
        pygame.draw.circle(surface, p["frame_shadow"], (lx, leg_y + 6), 3)
        pygame.draw.circle(surface, p["frame_light"], (lx, leg_y + 6), 2)
        # 무릎 하이라이트
        pygame.draw.circle(surface, p["neon"], (lx - 1, leg_y + 5), 1)

        # 정강이 (아머 플레이트)
        pygame.draw.rect(surface, p["armor_shadow"], (lx - 3, leg_y + 8, 6, 4))
        pygame.draw.rect(surface, p["armor_main"], (lx - 2, leg_y + 8, 4, 3))
        # 정강이 에지
        pygame.draw.line(surface, p["armor_edge"], (lx - 2, leg_y + 8), (lx + 2, leg_y + 8), 1)

        # 발 (부스터 노즐)
        pygame.draw.rect(surface, p["frame_shadow"], (lx - 4, leg_y + 12, 8, 3))
        pygame.draw.rect(surface, p["frame_main"], (lx - 3, leg_y + 12, 6, 2))
        # 부스터 글로우
        tp = 0.4 + 0.6 * abs(math.sin(t * 0.01 + side))
        tc = (int(60 + tp * 50), int(140 + tp * 60), int(220 + tp * 35))
        pygame.draw.rect(surface, tc, (lx - 2, leg_y + 14, 4, 2))
        # 부스터 광원
        bg = pygame.Surface((8, 4), pygame.SRCALPHA)
        pygame.draw.ellipse(bg, (*tc, int(40 * tp)), (0, 0, 8, 4))
        surface.blit(bg, (lx - 4, leg_y + 14))

        # 사이드 스커트 (블루 아머)
        sk = [
            (lx + side * 4, leg_y - 2),
            (lx + side * 10, leg_y - 1),
            (lx + side * 11, leg_y + 5),
            (lx + side * 5, leg_y + 4),
        ]
        pygame.draw.polygon(surface, p["blue_shadow"], sk)
        # 스커트 상면
        pygame.draw.polygon(surface, p["blue_main"], [sk[0], sk[1], (lx + side * 10, leg_y + 2), (lx + side * 4, leg_y + 1)])
        pygame.draw.polygon(surface, p["blue_edge"], sk, 1)

    # 프론트 스커트
    fsk = [(cx - 5, leg_y - 2), (cx + 5, leg_y - 2),
           (cx + 6, leg_y + 4), (cx - 6, leg_y + 4)]
    pygame.draw.polygon(surface, p["blue_main"], fsk)
    pygame.draw.polygon(surface, p["blue_edge"], fsk, 1)
    # 프론트 스커트 중앙 라인
    pygame.draw.line(surface, p["neon_dim"], (cx, leg_y - 1), (cx, leg_y + 3), 1)

    # ════════════════════════════════════════════
    # 2. 몸통 (Torso) — V자 흉부 + 리액터 + 복부
    # ════════════════════════════════════════════
    # 몸통 프레임 (다층)
    torso_pts = [
        (cx - 16, ty + 1),
        (cx - 18, ty + 5),
        (cx - 16, ty + 14),
        (cx - 7, ty + 16),
        (cx + 7, ty + 16),
        (cx + 16, ty + 14),
        (cx + 18, ty + 5),
        (cx + 16, ty + 1),
    ]
    # 그림자
    sh = [(x + 1, y + 1) for x, y in torso_pts]
    pygame.draw.polygon(surface, (*p["outline"], 60), sh)
    # 본체
    pygame.draw.polygon(surface, p["frame_shadow"], torso_pts)

    # 흉부 V자 아머 (건담 특유 - 밝은 색)
    chest_v = [
        (cx, ty + 1),
        (cx - 14, ty + 7),
        (cx - 11, ty + 10),
        (cx, ty + 6),
        (cx + 11, ty + 10),
        (cx + 14, ty + 7),
    ]
    pygame.draw.polygon(surface, p["armor_main"], chest_v)
    # V자 하이라이트 라인
    pygame.draw.line(surface, p["armor_light"], (cx, ty + 2), (cx - 13, ty + 7), 1)
    pygame.draw.line(surface, p["armor_light"], (cx, ty + 2), (cx + 13, ty + 7), 1)
    # V자 에너지 도관 (네온 라인)
    pygame.draw.line(surface, p["neon_dim"], (cx, ty + 3), (cx - 10, ty + 7), 1)
    pygame.draw.line(surface, p["neon_dim"], (cx, ty + 3), (cx + 10, ty + 7), 1)

    # 콕핏 해치
    cock = [(cx, ty + 4), (cx - 3, ty + 6), (cx - 2, ty + 9),
            (cx + 2, ty + 9), (cx + 3, ty + 6)]
    pygame.draw.polygon(surface, p["frame_shadow"], cock)
    gpulse = 0.7 + 0.3 * abs(math.sin(t * 0.003))
    glass_c = (int(20 * gpulse), int(50 + 40 * gpulse), int(90 + 50 * gpulse))
    pygame.draw.polygon(surface, glass_c, [
        (cx, ty + 5), (cx - 2, ty + 6), (cx - 1, ty + 8),
        (cx + 1, ty + 8), (cx + 2, ty + 6)])
    # 글래스 반사
    pygame.draw.line(surface, (80, 140, 200), (cx - 1, ty + 5), (cx + 1, ty + 6), 1)

    # 리액터 코어 (발광)
    ry = ty + 10
    rp = 0.5 + 0.5 * abs(math.sin(t * 0.007))
    # 리액터 글로우
    rgs = int(5 + rp * 2)
    rgf = pygame.Surface((rgs * 2, rgs * 2), pygame.SRCALPHA)
    pygame.draw.circle(rgf, (*p["reactor"], int(40 * rp)), (rgs, rgs), rgs)
    surface.blit(rgf, (cx - rgs, ry - rgs))
    # 리액터 본체
    pygame.draw.circle(surface, p["blue_shadow"], (cx, ry), 3)
    pygame.draw.circle(surface, p["reactor"], (cx, ry), 2)
    pygame.draw.circle(surface, p["reactor_core"], (cx - 1, ry - 1), 1)

    # 복부 (세그먼트 패널)
    ab_y = ty + 12
    pygame.draw.rect(surface, p["frame_main"], (cx - 5, ab_y, 10, 3))
    pygame.draw.line(surface, p["frame_light"], (cx - 3, ab_y + 1), (cx + 3, ab_y + 1), 1)
    # 복부 에너지 도관
    pygame.draw.line(surface, p["neon_dim"], (cx - 4, ab_y + 2), (cx + 4, ab_y + 2), 1)

    # 몸통 테두리
    pygame.draw.polygon(surface, p["frame_seam"], torso_pts, 1)

    # ════════════════════════════════════════════
    # 3. 양팔 (Arms) — 다중 셰이딩 + 블레이드
    # ════════════════════════════════════════════
    for side in [-1, 1]:
        ax = cx + side * 18

        # ─ 어깨 아머 (블루, 다층) ─
        sh_pts = [
            (ax - side * 2, ty + int(hover)),
            (ax + side * 13, ty - 1 + int(hover)),
            (ax + side * 16, ty + 4 + int(hover)),
            (ax + side * 14, ty + 10 + int(hover)),
            (ax + side * 7, ty + 12 + int(hover)),
            (ax, ty + 10 + int(hover)),
        ]
        # 어깨 그림자
        pygame.draw.polygon(surface, p["blue_shadow"], sh_pts)
        # 어깨 상면
        pygame.draw.polygon(surface, p["blue_main"], sh_pts[:3] + [sh_pts[-1]])
        # 어깨 하이라이트
        pygame.draw.polygon(surface, p["blue_light"], [sh_pts[0], sh_pts[1], (ax + side * 14, ty + 3 + int(hover))])
        # 어깨 에지
        pygame.draw.polygon(surface, p["blue_edge"], sh_pts, 1)
        # 어깨 벤트 (에너지 방출구)
        vp = abs(math.sin(t * 0.005 + side * 1.5))
        vc = (int(60 + vp * 50), int(140 + vp * 60), int(220 + vp * 35))
        vx = ax + side * 8
        vy = ty + 4 + int(hover)
        pygame.draw.rect(surface, vc, (vx - 2, vy, 4, 2))
        # 벤트 글로우
        if vp > 0.6:
            vgs = pygame.Surface((8, 4), pygame.SRCALPHA)
            pygame.draw.ellipse(vgs, (*vc, int(30 * vp)), (0, 0, 8, 4))
            surface.blit(vgs, (vx - 4, vy - 1))

        # ─ 상완 (프레임 + 아머) ─
        ua_x = ax + side * 14
        ua_y = ty + 10 + int(hover) + arm_swing // 2
        pygame.draw.rect(surface, p["frame_shadow"], (ua_x - 2, ua_y, 4, 6))
        pygame.draw.rect(surface, p["frame_main"], (ua_x - 1, ua_y + 1, 2, 4))
        # 상완 에너지 도관
        pygame.draw.line(surface, p["neon_dim"], (ua_x, ua_y + 1), (ua_x, ua_y + 4), 1)

        # 팔꿈치 관절
        ej_y = ua_y + 6
        pygame.draw.circle(surface, p["frame_shadow"], (ua_x, ej_y), 2)
        pygame.draw.circle(surface, p["frame_light"], (ua_x, ej_y), 1)

        # ─ 전완 (아머 플레이트 + 무장) ─
        fa_x = ax + side * 18
        fa_y = ej_y + 1 - arm_swing // 2
        fa_pts = [
            (fa_x - side * 3, fa_y),
            (fa_x + side * 5, fa_y - 1),
            (fa_x + side * 7, fa_y + 4),
            (fa_x + side * 5, fa_y + 8),
            (fa_x - side * 2, fa_y + 7),
        ]
        pygame.draw.polygon(surface, p["armor_shadow"], fa_pts)
        pygame.draw.polygon(surface, p["armor_main"], [fa_pts[0], fa_pts[1], fa_pts[2], fa_pts[-1]])
        pygame.draw.polygon(surface, p["armor_edge"], fa_pts, 1)
        # 전완 에너지 도관
        pygame.draw.line(surface, p["neon_dim"], (fa_x, fa_y + 1), (fa_x + side * 2, fa_y + 6), 1)

        # 무장 마운트 (포구)
        mx = fa_x + side * 4
        my = fa_y + 5
        pygame.draw.rect(surface, p["frame_shadow"], (mx - 1, my, 3, 2))
        if boss_current_health > 8:
            wp = abs(math.sin(t * 0.006 + side * 2))
            pygame.draw.circle(surface, (int(80 + wp * 60), int(160 + wp * 50), 255), (mx, my + 2), 1)

        # ─ 핸드 ─
        hx = fa_x + side * 6
        hy = fa_y + 7
        pygame.draw.circle(surface, p["frame_shadow"], (hx, hy), 2)
        pygame.draw.circle(surface, p["frame_main"], (hx, hy), 1)

    # ════════════════════════════════════════════
    # 4. 머리 (Head) — V핀 + 듀얼아이 + 치크가드
    # ════════════════════════════════════════════
    hy = 2 + int(hover) - lean

    # 목 (관절 디테일)
    pygame.draw.rect(surface, p["frame_shadow"], (cx - 3, hy + 10, 6, 3))
    pygame.draw.rect(surface, p["frame_main"], (cx - 2, hy + 10, 4, 2))
    # 목 에너지 도관
    pygame.draw.line(surface, p["neon_dim"], (cx, hy + 10), (cx, hy + 12), 1)

    # 헬멧 (다층 셰이딩)
    helm = [
        (cx, hy),
        (cx - 8, hy + 3), (cx - 9, hy + 7),
        (cx - 7, hy + 10), (cx - 4, hy + 11),
        (cx + 4, hy + 11), (cx + 7, hy + 10),
        (cx + 9, hy + 7), (cx + 8, hy + 3),
    ]
    # 헬멧 그림자
    pygame.draw.polygon(surface, p["armor_shadow"], helm)
    # 헬멧 상면 (밝은 영역)
    pygame.draw.polygon(surface, p["armor_main"], helm[:3] + [helm[-1]])
    # 헬멧 하이라이트
    pygame.draw.line(surface, p["armor_light"], (cx - 6, hy + 3), (cx + 6, hy + 3), 1)
    # 헬멧 에지
    if dmg < 0.5:
        pygame.draw.polygon(surface, p["armor_edge"], helm, 1)

    # 페이스 플레이트 (어두운 영역)
    face = [
        (cx - 6, hy + 5), (cx + 6, hy + 5),
        (cx + 7, hy + 8), (cx + 5, hy + 10),
        (cx - 5, hy + 10), (cx - 7, hy + 8),
    ]
    pygame.draw.polygon(surface, p["frame_shadow"], face)

    # 치크 가드 (레드 액센트)
    for side in [-1, 1]:
        ck = [
            (cx + side * 5, hy + 7), (cx + side * 8, hy + 6),
            (cx + side * 8, hy + 9), (cx + side * 5, hy + 10),
        ]
        pygame.draw.polygon(surface, p["red"], ck)
        # 치크 하이라이트
        pygame.draw.line(surface, p["red_light"], ck[0], ck[1], 1)

    # 듀얼 아이 (발광)
    ep = 0.7 + 0.3 * abs(math.sin(t * 0.008))
    for side in [-1, 1]:
        ex = cx + side * 3
        ey = hy + 7
        # 아이 글로우
        egs = pygame.Surface((10, 6), pygame.SRCALPHA)
        pygame.draw.ellipse(egs, (*p["eye_glow"][:3], int(50 * ep)), (0, 0, 10, 6))
        surface.blit(egs, (ex - 5, ey - 3))
        # 아이 본체
        pygame.draw.ellipse(surface, p["eye"], (ex - 2, ey - 1, 4, 3))
        pygame.draw.ellipse(surface, p["eye_bright"], (ex - 1, ey, 2, 1))
        # 동공 하이라이트
        pygame.draw.circle(surface, (255, 255, 255), (ex + side, ey - 1), 1)

    # 이마 센서 (레드)
    pygame.draw.circle(surface, p["red"], (cx, hy + 4), 1)

    # V핀 (골드 — 건담의 상징)
    vfy = hy
    for side in [-1, 1]:
        vfin = [
            (cx + side * 1, vfy + 1),
            (cx + side * 11, vfy - 5),
            (cx + side * 9, vfy - 4),
            (cx, vfy + 1),
        ]
        pygame.draw.polygon(surface, p["vfin"], vfin)
        pygame.draw.polygon(surface, p["vfin_light"], vfin, 1)

    # ════════════════════════════════════════════
    # 5. 백팩 스러스터 (좌우)
    # ════════════════════════════════════════════
    for side in [-1, 1]:
        bx = cx + side * 16
        by = ty + int(hover)
        bp = [
            (bx, by), (bx + side * 5, by - 1),
            (bx + side * 6, by + 8), (bx + side * 3, by + 10), (bx, by + 9),
        ]
        pygame.draw.polygon(surface, p["frame_shadow"], bp)
        pygame.draw.polygon(surface, p["frame_main"], bp[:3] + [bp[-1]])
        pygame.draw.polygon(surface, p["frame_seam"], bp, 1)
        # 스러스터 노즐
        for j in range(2):
            ny = by + 4 + j * 3
            nx = bx + side * 4
            pygame.draw.circle(surface, p["frame_shadow"], (nx, ny), 2)
            # 이동 시 화염
            if spd > 0.3:
                fp = 0.5 + 0.5 * abs(math.sin(t * 0.015 + j))
                fc = (int(80 + fp * 80), int(160 + fp * 60), 255)
                pygame.draw.ellipse(surface, fc, (nx - 1, ny + 2, 3, 2))
        # 방열 핀
        for fi in range(2):
            fy = by + 2 + fi * 4
            pygame.draw.line(surface, p["frame_light"],
                           (bx + side * 5, fy), (bx + side * 9, fy), 1)

    # ════════════════════════════════════════════
    # 6. 쉴드 안테나 (어깨 발광)
    # ════════════════════════════════════════════
    if shield_antenna_active:
        for side in [-1, 1]:
            ax = cx + side * 28
            ay = ty + 3 + int(hover)
            pygame.draw.circle(surface, p["neon_bright"], (ax, ay), 3)
            pygame.draw.circle(surface, (255, 255, 255), (ax, ay), 1)
            for ri in range(2):
                rr = 4 + ri * 2
                rs = pygame.Surface((rr * 2 + 2, rr * 2 + 2), pygame.SRCALPHA)
                pygame.draw.circle(rs, (*p["neon"], max(10, 50 - ri * 20)), (rr + 1, rr + 1), rr, 1)
                surface.blit(rs, (ax - rr - 1, ay - rr - 1))

    # ════════════════════════════════════════════
    # 7. 레이저 캐논 (리액터에서 충전)
    # ════════════════════════════════════════════
    if laser_charging:
        cp = min(1.0, (t - laser_charge_start) / 1500.0)
        for _ in range(int(4 * cp)):
            pa = random.uniform(0, math.pi * 2)
            pd = random.uniform(5, 15 * (1 - cp))
            px = cx + int(math.cos(pa) * pd)
            py = ry + int(math.sin(pa) * pd)
            pygame.draw.circle(surface, (100, int(150 + 100 * cp), 255), (px, py), 1)
        cr = int(3 + 4 * cp)
        pygame.draw.circle(surface, p["reactor"], (cx, ry), cr)
        pygame.draw.circle(surface, p["reactor_core"], (cx, ry), max(1, cr - 2))

    # ════════════════════════════════════════════
    # 8. CIWS 미사일 (기존 호환)
    # ════════════════════════════════════════════
    global turret_angles, turret_missiles, last_missile_time
    current_time = pygame.time.get_ticks()
    defense_positions = [
        (cx - 28, ty + 4 + int(hover)), (cx - 16, ty + 8 + int(hover)),
        (cx + 16, ty + 8 + int(hover)), (cx + 28, ty + 4 + int(hover)),
        (cx - 8, leg_y + 2), (cx + 8, leg_y + 2),
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

    # ════════════════════════════════════════════
    # 9. 손상 효과
    # ════════════════════════════════════════════
    if dmg > 0.3:
        for _ in range(int(dmg * 3)):
            sx = random.randint(cx - 22, cx + 22)
            sy = random.randint(4, 34)
            pygame.draw.circle(surface, random.choice([(150, 200, 255), (255, 200, 100)]), (sx, sy), 1)

    if dmg > 0.5:
        for _ in range(int(dmg * 2)):
            sx = random.randint(cx - 18, cx + 18)
            sy = random.randint(6, 30)
            cl = random.randint(3, 6)
            pygame.draw.line(surface, p["outline"], (sx, sy),
                           (sx + random.randint(-cl, cl), sy + random.randint(-2, 2)), 1)

    health_pct = (boss_current_health / boss_max_health) * 100
    if health_pct <= 50:
        sn = 2 if health_pct > 30 else (4 if health_pct > 10 else 6)
        for _ in range(sn):
            sx = random.randint(cx - 18, cx + 18)
            sy = random.randint(5, 28)
            ss = pygame.Surface((8, 8), pygame.SRCALPHA)
            pygame.draw.circle(ss, (55, 55, 55, 25), (4, 4), 4)
            surface.blit(ss, (sx - 4, sy - 4))

    if health_pct <= 30:
        fi = 1.0 if health_pct > 10 else 2.0
        for _ in range(2 if health_pct > 10 else 4):
            fx = random.randint(cx - 15, cx + 15)
            fy = random.randint(6, 28)
            fw = abs(math.sin(t * 0.01 + fx))
            pygame.draw.circle(surface, (255, 255, 200), (fx, fy), int(2 * fi * (0.8 + fw * 0.2)))
            fs = pygame.Surface((6, 6), pygame.SRCALPHA)
            pygame.draw.circle(fs, (255, 100, 30, 120), (3, 3), 3)
            surface.blit(fs, (fx - 3, fy - 3))

    if health_pct <= 10 and random.random() < 0.2:
        ex = random.randint(cx - 14, cx + 14)
        ey = random.randint(6, 26)
        es = random.randint(5, 9)
        pygame.draw.circle(surface, (255, 255, 255), (ex, ey), es)
        pygame.draw.circle(surface, (255, 200, 100), (ex, ey), es - 2)

    return surface
