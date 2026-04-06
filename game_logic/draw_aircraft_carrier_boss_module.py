"""
draw_aircraft_carrier_boss 함수 - 인간형 건담 로봇 (바이퍼 스타일, 100x90)
다중 레이어 셰이딩, 관절 디테일, 에너지 도관, 인간 비율
"""

import pygame
import math
import random

def draw_aircraft_carrier_boss(boss_speed=0, boss_x=0):
    """스테이지 6 네메시스 - 인간형 건담 전투 로봇 (100x90, 전신 인간 비율)"""
    import random
    global laser_cannon_angle, laser_charging, laser_cannon_active, laser_charge_start
    global shield_antenna_active, stage6_boss_hit_timer, stage6_boss_hit_flash

    if stage6_boss_hit_timer > 0:
        stage6_boss_hit_timer -= 1
        stage6_boss_hit_flash = (stage6_boss_hit_timer // 4) % 2 == 0
        if stage6_boss_hit_timer <= 0:
            stage6_boss_hit_flash = False

    W, H = 100, 90
    surface = pygame.Surface((W, H), pygame.SRCALPHA)
    dmg = 1.0 - (boss_current_health / boss_max_health)
    t = pygame.time.get_ticks()
    cx = W // 2  # 50

    def hit(c):
        if stage6_boss_hit_flash:
            return (min(255, c[0] + 120), max(0, c[1] - 30), max(0, c[2] - 30))
        return c

    # ═══ 컬러 팔레트 ═══
    p = {
        "frame_shadow": hit((18, 28, 48)), "frame_main": hit((32, 48, 72)),
        "frame_light": hit((48, 68, 98)), "frame_highlight": hit((62, 85, 118)),
        "frame_seam": hit((72, 95, 130)),
        "armor_shadow": hit((120, 128, 142)), "armor_main": hit((165, 175, 192)),
        "armor_light": hit((195, 205, 220)), "armor_edge": hit((210, 218, 232)),
        "blue_shadow": hit((28, 55, 110)), "blue_main": hit((45, 85, 160)),
        "blue_light": hit((65, 115, 195)), "blue_edge": hit((85, 140, 215)),
        "neon": (80, 200, 255), "neon_bright": (160, 235, 255),
        "neon_dim": (40, 120, 200), "neon_glow": (60, 180, 255, 60),
        "reactor": (80, 180, 255), "reactor_bright": (180, 230, 255),
        "reactor_core": (255, 255, 255),
        "eye": (0, 230, 120), "eye_bright": (120, 255, 180),
        "eye_glow": (0, 200, 100, 50),
        "vfin": hit((215, 185, 80)), "vfin_light": hit((240, 215, 120)),
        "red": hit((195, 55, 45)), "red_light": hit((230, 80, 65)),
        "outline": hit((12, 18, 32)),
    }

    # ═══ 모션 ═══
    breath = math.sin(t * 0.004)
    sway = math.sin(t * 0.006 + 0.5)
    hover = breath * 1.2
    torso_bob = int(breath * 0.8)
    arm_swing = int(breath * 1.5 + sway * 0.8)
    lean = int(breath * 0.4)

    spd = abs(boss_speed)
    if spd > 0.5:
        ww = math.sin((t * 0.008) % 1.0 * math.pi * 2)
        torso_bob = int(abs(ww) * 1.5)
        arm_swing = int(ww * 3)

    # ═══ 인체 비율 기준점 (머리:몸:다리 = 1:1.5:2) ═══
    head_top = 4 + int(hover)
    head_h = 18
    torso_top = head_top + head_h + 2  # ~24
    torso_h = 22
    leg_top = torso_top + torso_h      # ~46
    leg_h = 34

    # ════════════════════════════════════════════
    # 0. 하부 부유 글로우
    # ════════════════════════════════════════════
    gp = 0.5 + 0.5 * abs(math.sin(t * 0.006))
    for i in range(3):
        gr = 10 + i * 4
        ga = int((30 - i * 8) * gp)
        gs = pygame.Surface((gr * 2, 4), pygame.SRCALPHA)
        pygame.draw.ellipse(gs, (*p["neon"], max(3, ga)), (0, 0, gr * 2, 4))
        surface.blit(gs, (cx - gr, H - 5 + i))

    # ════════════════════════════════════════════
    # 1. 다리 (Legs) Y:46~80 — 긴 다리, 인간 비율
    # ════════════════════════════════════════════
    for side in [-1, 1]:
        lx = cx + side * 8

        # ─ 허벅지 (장갑 + 도관) ─
        thigh_y = leg_top + torso_bob
        pygame.draw.rect(surface, p["frame_shadow"], (lx - 4, thigh_y, 8, 12))
        pygame.draw.rect(surface, p["frame_main"], (lx - 3, thigh_y + 1, 6, 10))
        # 허벅지 아머 플레이트
        pygame.draw.rect(surface, p["armor_shadow"], (lx - 3, thigh_y + 2, 6, 5))
        pygame.draw.rect(surface, p["armor_main"], (lx - 2, thigh_y + 2, 4, 4))
        pygame.draw.line(surface, p["armor_edge"], (lx - 2, thigh_y + 2), (lx + 2, thigh_y + 2), 1)
        # 에너지 도관
        pygame.draw.line(surface, p["neon_dim"], (lx, thigh_y + 2), (lx, thigh_y + 10), 1)

        # ─ 무릎 관절 ─
        knee_y = thigh_y + 13
        pygame.draw.circle(surface, p["frame_shadow"], (lx, knee_y), 4)
        pygame.draw.circle(surface, p["frame_main"], (lx, knee_y), 3)
        pygame.draw.circle(surface, p["frame_light"], (lx, knee_y), 2)
        # 무릎 네온 포인트
        pygame.draw.circle(surface, p["neon"], (lx - 1, knee_y - 1), 1)

        # ─ 정강이 (긴 아머) ─
        shin_y = knee_y + 4
        pygame.draw.rect(surface, p["armor_shadow"], (lx - 4, shin_y, 8, 10))
        pygame.draw.rect(surface, p["armor_main"], (lx - 3, shin_y + 1, 6, 8))
        # 정강이 상부 하이라이트
        pygame.draw.line(surface, p["armor_light"], (lx - 3, shin_y), (lx + 3, shin_y), 1)
        # 정강이 에너지 도관
        pygame.draw.line(surface, p["neon_dim"], (lx, shin_y + 1), (lx, shin_y + 8), 1)
        # 정강이 프레임 에지
        pygame.draw.rect(surface, p["frame_seam"], (lx - 4, shin_y, 8, 10), 1)

        # ─ 발 (부스터 내장) ─
        foot_y = shin_y + 10
        pygame.draw.rect(surface, p["frame_shadow"], (lx - 5, foot_y, 10, 4))
        pygame.draw.rect(surface, p["frame_main"], (lx - 4, foot_y, 8, 3))
        # 발 앞부분 디테일
        pygame.draw.line(surface, p["frame_light"], (lx - 4, foot_y), (lx + 4, foot_y), 1)
        # 부스터 글로우
        tp = 0.4 + 0.6 * abs(math.sin(t * 0.01 + side))
        tc = (int(60 + tp * 50), int(140 + tp * 60), int(220 + tp * 35))
        pygame.draw.rect(surface, tc, (lx - 3, foot_y + 3, 6, 2))
        bg = pygame.Surface((10, 4), pygame.SRCALPHA)
        pygame.draw.ellipse(bg, (*tc, int(40 * tp)), (0, 0, 10, 4))
        surface.blit(bg, (lx - 5, foot_y + 3))

        # ─ 사이드 스커트 (블루 아머) ─
        sk = [
            (lx + side * 5, leg_top - 2 + torso_bob),
            (lx + side * 13, leg_top - 1 + torso_bob),
            (lx + side * 14, leg_top + 8 + torso_bob),
            (lx + side * 6, leg_top + 7 + torso_bob),
        ]
        pygame.draw.polygon(surface, p["blue_shadow"], sk)
        pygame.draw.polygon(surface, p["blue_main"], [sk[0], sk[1],
            (lx + side * 13, leg_top + 3 + torso_bob), (lx + side * 5, leg_top + 2 + torso_bob)])
        pygame.draw.polygon(surface, p["blue_edge"], sk, 1)

    # 프론트 스커트
    fsk_y = leg_top - 2 + torso_bob
    fsk = [(cx - 7, fsk_y), (cx + 7, fsk_y), (cx + 8, fsk_y + 8), (cx - 8, fsk_y + 8)]
    pygame.draw.polygon(surface, p["blue_main"], fsk)
    pygame.draw.polygon(surface, p["blue_edge"], fsk, 1)
    pygame.draw.line(surface, p["neon_dim"], (cx, fsk_y + 1), (cx, fsk_y + 7), 1)

    # ════════════════════════════════════════════
    # 2. 몸통 (Torso) Y:24~46
    # ════════════════════════════════════════════
    ty = torso_top + torso_bob

    torso_pts = [
        (cx - 18, ty + 2), (cx - 20, ty + 6),
        (cx - 18, ty + 18), (cx - 8, ty + 22),
        (cx + 8, ty + 22), (cx + 18, ty + 18),
        (cx + 20, ty + 6), (cx + 18, ty + 2),
    ]
    sh = [(x + 1, y + 1) for x, y in torso_pts]
    pygame.draw.polygon(surface, (*p["outline"], 60), sh)
    pygame.draw.polygon(surface, p["frame_shadow"], torso_pts)

    # V자 흉부 장갑
    chest_v = [
        (cx, ty + 2), (cx - 16, ty + 9), (cx - 12, ty + 13),
        (cx, ty + 8), (cx + 12, ty + 13), (cx + 16, ty + 9),
    ]
    pygame.draw.polygon(surface, p["armor_main"], chest_v)
    pygame.draw.line(surface, p["armor_light"], (cx, ty + 3), (cx - 14, ty + 9), 1)
    pygame.draw.line(surface, p["armor_light"], (cx, ty + 3), (cx + 14, ty + 9), 1)
    # V자 네온 도관
    pygame.draw.line(surface, p["neon_dim"], (cx, ty + 4), (cx - 11, ty + 9), 1)
    pygame.draw.line(surface, p["neon_dim"], (cx, ty + 4), (cx + 11, ty + 9), 1)

    # 콕핏
    cock = [(cx, ty + 5), (cx - 4, ty + 8), (cx - 3, ty + 12),
            (cx + 3, ty + 12), (cx + 4, ty + 8)]
    pygame.draw.polygon(surface, p["frame_shadow"], cock)
    gpulse = 0.7 + 0.3 * abs(math.sin(t * 0.003))
    glass_c = (int(20 * gpulse), int(50 + 40 * gpulse), int(90 + 50 * gpulse))
    pygame.draw.polygon(surface, glass_c, [
        (cx, ty + 6), (cx - 3, ty + 8), (cx - 2, ty + 11),
        (cx + 2, ty + 11), (cx + 3, ty + 8)])
    pygame.draw.line(surface, (80, 140, 200), (cx - 2, ty + 7), (cx + 1, ty + 6), 1)

    # 리액터 코어
    ry = ty + 14
    rp = 0.5 + 0.5 * abs(math.sin(t * 0.007))
    rgs = int(6 + rp * 2)
    rgf = pygame.Surface((rgs * 2, rgs * 2), pygame.SRCALPHA)
    pygame.draw.circle(rgf, (*p["reactor"], int(45 * rp)), (rgs, rgs), rgs)
    surface.blit(rgf, (cx - rgs, ry - rgs))
    pygame.draw.circle(surface, p["blue_shadow"], (cx, ry), 4)
    pygame.draw.circle(surface, p["reactor"], (cx, ry), 3)
    pygame.draw.circle(surface, p["reactor_bright"], (cx, ry), 2)
    pygame.draw.circle(surface, p["reactor_core"], (cx - 1, ry - 1), 1)

    # 복부
    ab_y = ty + 17
    pygame.draw.rect(surface, p["frame_main"], (cx - 6, ab_y, 12, 4))
    pygame.draw.line(surface, p["frame_light"], (cx - 4, ab_y + 1), (cx + 4, ab_y + 1), 1)
    pygame.draw.line(surface, p["neon_dim"], (cx - 5, ab_y + 3), (cx + 5, ab_y + 3), 1)

    pygame.draw.polygon(surface, p["frame_seam"], torso_pts, 1)

    # ════════════════════════════════════════════
    # 3. 양팔 (Arms) — 어깨~핸드
    # ════════════════════════════════════════════
    for side in [-1, 1]:
        ax = cx + side * 20

        # ─ 어깨 아머 (블루, 큰 사이즈) ─
        shy = ty + int(hover)
        sh_pts = [
            (ax - side * 2, shy),
            (ax + side * 15, shy - 2),
            (ax + side * 18, shy + 5),
            (ax + side * 16, shy + 12),
            (ax + side * 8, shy + 14),
            (ax, shy + 12),
        ]
        pygame.draw.polygon(surface, p["blue_shadow"], sh_pts)
        pygame.draw.polygon(surface, p["blue_main"], sh_pts[:3] + [sh_pts[-1]])
        pygame.draw.polygon(surface, p["blue_light"], [sh_pts[0], sh_pts[1],
            (ax + side * 16, shy + 4)])
        pygame.draw.polygon(surface, p["blue_edge"], sh_pts, 1)
        # 어깨 벤트
        vp = abs(math.sin(t * 0.005 + side * 1.5))
        vc = (int(60 + vp * 50), int(140 + vp * 60), int(220 + vp * 35))
        vx = ax + side * 9
        vy = shy + 5
        pygame.draw.rect(surface, vc, (vx - 2, vy, 5, 2))
        if vp > 0.6:
            vgs = pygame.Surface((10, 5), pygame.SRCALPHA)
            pygame.draw.ellipse(vgs, (*vc, int(30 * vp)), (0, 0, 10, 5))
            surface.blit(vgs, (vx - 5, vy - 1))

        # ─ 상완 ─
        ua_x = ax + side * 15
        ua_y = shy + 12 + arm_swing // 2
        pygame.draw.rect(surface, p["frame_shadow"], (ua_x - 3, ua_y, 6, 10))
        pygame.draw.rect(surface, p["frame_main"], (ua_x - 2, ua_y + 1, 4, 8))
        pygame.draw.line(surface, p["neon_dim"], (ua_x, ua_y + 2), (ua_x, ua_y + 8), 1)

        # 팔꿈치
        ej_y = ua_y + 10
        pygame.draw.circle(surface, p["frame_shadow"], (ua_x, ej_y), 3)
        pygame.draw.circle(surface, p["frame_light"], (ua_x, ej_y), 2)
        pygame.draw.circle(surface, p["neon"], (ua_x - 1, ej_y - 1), 1)

        # ─ 전완 (아머) ─
        fa_x = ax + side * 18
        fa_y = ej_y + 2 - arm_swing // 2
        fa_pts = [
            (fa_x - side * 4, fa_y),
            (fa_x + side * 6, fa_y - 1),
            (fa_x + side * 8, fa_y + 5),
            (fa_x + side * 6, fa_y + 10),
            (fa_x - side * 3, fa_y + 9),
        ]
        pygame.draw.polygon(surface, p["armor_shadow"], fa_pts)
        pygame.draw.polygon(surface, p["armor_main"], [fa_pts[0], fa_pts[1], fa_pts[2], fa_pts[-1]])
        pygame.draw.polygon(surface, p["armor_edge"], fa_pts, 1)
        pygame.draw.line(surface, p["neon_dim"], (fa_x, fa_y + 1), (fa_x + side * 2, fa_y + 8), 1)

        # 무장
        mx = fa_x + side * 5
        my = fa_y + 6
        pygame.draw.rect(surface, p["frame_shadow"], (mx - 2, my, 4, 3))
        if boss_current_health > 8:
            wp = abs(math.sin(t * 0.006 + side * 2))
            pygame.draw.circle(surface, (int(80 + wp * 60), int(160 + wp * 50), 255), (mx, my + 3), 1)

        # 핸드
        hx = fa_x + side * 7
        hy = fa_y + 9
        pygame.draw.circle(surface, p["frame_shadow"], (hx, hy), 3)
        pygame.draw.circle(surface, p["frame_main"], (hx, hy), 2)

    # ════════════════════════════════════════════
    # 4. 머리 (Head) Y:4~22
    # ════════════════════════════════════════════
    hy = head_top - lean

    # 목
    pygame.draw.rect(surface, p["frame_shadow"], (cx - 3, hy + head_h - 2, 6, 4))
    pygame.draw.rect(surface, p["frame_main"], (cx - 2, hy + head_h - 1, 4, 3))
    pygame.draw.line(surface, p["neon_dim"], (cx, hy + head_h - 1), (cx, hy + head_h + 2), 1)

    # 헬멧
    helm = [
        (cx, hy),
        (cx - 10, hy + 4), (cx - 11, hy + 10),
        (cx - 9, hy + 14), (cx - 5, hy + head_h - 2),
        (cx + 5, hy + head_h - 2), (cx + 9, hy + 14),
        (cx + 11, hy + 10), (cx + 10, hy + 4),
    ]
    pygame.draw.polygon(surface, p["armor_shadow"], helm)
    pygame.draw.polygon(surface, p["armor_main"], helm[:3] + [helm[-1]])
    pygame.draw.line(surface, p["armor_light"], (cx - 8, hy + 4), (cx + 8, hy + 4), 1)
    # 헬멧 중앙 릿지
    pygame.draw.line(surface, p["armor_edge"], (cx, hy + 1), (cx, hy + 8), 1)
    if dmg < 0.5:
        pygame.draw.polygon(surface, p["armor_edge"], helm, 1)

    # 페이스 플레이트
    face = [
        (cx - 7, hy + 7), (cx + 7, hy + 7),
        (cx + 9, hy + 11), (cx + 6, hy + 14),
        (cx - 6, hy + 14), (cx - 9, hy + 11),
    ]
    pygame.draw.polygon(surface, p["frame_shadow"], face)

    # 턱 가드
    chin = [(cx - 4, hy + 13), (cx + 4, hy + 13),
            (cx + 5, hy + 16), (cx - 5, hy + 16)]
    pygame.draw.polygon(surface, p["frame_main"], chin)

    # 치크 가드 (레드)
    for side in [-1, 1]:
        ck = [
            (cx + side * 5, hy + 9), (cx + side * 10, hy + 8),
            (cx + side * 10, hy + 12), (cx + side * 6, hy + 13),
        ]
        pygame.draw.polygon(surface, p["red"], ck)
        pygame.draw.line(surface, p["red_light"], ck[0], ck[1], 1)

    # 듀얼 아이 (발광)
    ep = 0.7 + 0.3 * abs(math.sin(t * 0.008))
    for side in [-1, 1]:
        ex = cx + side * 4
        ey = hy + 10
        egs = pygame.Surface((10, 6), pygame.SRCALPHA)
        pygame.draw.ellipse(egs, (*p["eye_glow"][:3], int(50 * ep)), (0, 0, 10, 6))
        surface.blit(egs, (ex - 5, ey - 3))
        pygame.draw.ellipse(surface, p["eye"], (ex - 3, ey - 2, 6, 4))
        pygame.draw.ellipse(surface, p["eye_bright"], (ex - 2, ey - 1, 4, 2))
        pygame.draw.circle(surface, (255, 255, 255), (ex + side, ey - 1), 1)

    # 이마 센서
    pygame.draw.circle(surface, p["red"], (cx, hy + 5), 2)
    pygame.draw.circle(surface, p["red_light"], (cx, hy + 5), 1)

    # V핀 (골드)
    for side in [-1, 1]:
        vfin = [
            (cx + side * 1, hy + 2),
            (cx + side * 14, hy - 5),
            (cx + side * 12, hy - 4),
            (cx, hy + 2),
        ]
        pygame.draw.polygon(surface, p["vfin"], vfin)
        pygame.draw.polygon(surface, p["vfin_light"], vfin, 1)

    # ════════════════════════════════════════════
    # 5. 백팩 스러스터
    # ════════════════════════════════════════════
    for side in [-1, 1]:
        bx = cx + side * 18
        by = ty + 1 + int(hover)
        bp = [(bx, by), (bx + side * 6, by - 1),
              (bx + side * 7, by + 12), (bx + side * 4, by + 14), (bx, by + 13)]
        pygame.draw.polygon(surface, p["frame_shadow"], bp)
        pygame.draw.polygon(surface, p["frame_main"], bp[:3] + [bp[-1]])
        pygame.draw.polygon(surface, p["frame_seam"], bp, 1)
        for j in range(2):
            ny = by + 5 + j * 4
            nx = bx + side * 4
            pygame.draw.circle(surface, p["frame_shadow"], (nx, ny), 2)
            if spd > 0.3:
                fp = 0.5 + 0.5 * abs(math.sin(t * 0.015 + j))
                fc = (int(80 + fp * 80), int(160 + fp * 60), 255)
                pygame.draw.ellipse(surface, fc, (nx - 2, ny + 2, 4, 3))
        for fi in range(3):
            fy = by + 2 + fi * 4
            pygame.draw.line(surface, p["frame_light"],
                           (bx + side * 6, fy), (bx + side * 10, fy), 1)

    # ════════════════════════════════════════════
    # 6. 쉴드 안테나
    # ════════════════════════════════════════════
    if shield_antenna_active:
        for side in [-1, 1]:
            ax = cx + side * 30
            ay = ty + 5 + int(hover)
            pygame.draw.circle(surface, p["neon_bright"], (ax, ay), 3)
            pygame.draw.circle(surface, (255, 255, 255), (ax, ay), 1)
            for ri in range(2):
                rr = 4 + ri * 3
                rs = pygame.Surface((rr * 2 + 2, rr * 2 + 2), pygame.SRCALPHA)
                pygame.draw.circle(rs, (*p["neon"], max(10, 50 - ri * 20)), (rr + 1, rr + 1), rr, 1)
                surface.blit(rs, (ax - rr - 1, ay - rr - 1))

    # ════════════════════════════════════════════
    # 7. 레이저 캐논
    # ════════════════════════════════════════════
    if laser_charging:
        cp = min(1.0, (t - laser_charge_start) / 1500.0)
        for _ in range(int(5 * cp)):
            pa = random.uniform(0, math.pi * 2)
            pd = random.uniform(5, 18 * (1 - cp))
            px = cx + int(math.cos(pa) * pd)
            py = ry + int(math.sin(pa) * pd)
            pygame.draw.circle(surface, (100, int(150 + 100 * cp), 255), (px, py), 1)
        cr = int(4 + 5 * cp)
        pygame.draw.circle(surface, p["reactor"], (cx, ry), cr)
        pygame.draw.circle(surface, p["reactor_core"], (cx, ry), max(1, cr - 2))

    # ════════════════════════════════════════════
    # 8. CIWS 미사일
    # ════════════════════════════════════════════
    global turret_angles, turret_missiles, last_missile_time
    current_time = pygame.time.get_ticks()
    defense_positions = [
        (cx - 30, ty + 5 + int(hover)), (cx - 18, ty + 10 + int(hover)),
        (cx + 18, ty + 10 + int(hover)), (cx + 30, ty + 5 + int(hover)),
        (cx - 8, leg_top + 5), (cx + 8, leg_top + 5),
    ]
    for idx, (dx, dy) in enumerate(defense_positions):
        turret_id = f"turret_{idx}_{dx}_{dy}"
        if turret_id not in turret_angles:
            turret_angles[turret_id] = random.randint(0, 360)
        turret_angles[turret_id] = (turret_angles[turret_id] + 1) % 120
        if boss_current_health > 0 and random.random() < 0.0012 and boss_confused_timer == 0:
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
            sx = random.randint(cx - 20, cx + 20)
            sy = random.randint(8, 75)
            pygame.draw.circle(surface, random.choice([(150, 200, 255), (255, 200, 100)]), (sx, sy), 1)

    if dmg > 0.5:
        for _ in range(int(dmg * 2)):
            sx = random.randint(cx - 16, cx + 16)
            sy = random.randint(10, 70)
            cl = random.randint(3, 7)
            pygame.draw.line(surface, p["outline"], (sx, sy),
                           (sx + random.randint(-cl, cl), sy + random.randint(-3, 3)), 1)

    health_pct = (boss_current_health / boss_max_health) * 100
    if health_pct <= 50:
        sn = 2 if health_pct > 30 else (4 if health_pct > 10 else 6)
        for _ in range(sn):
            sx = random.randint(cx - 16, cx + 16)
            sy = random.randint(10, 65)
            ss = pygame.Surface((8, 8), pygame.SRCALPHA)
            pygame.draw.circle(ss, (55, 55, 55, 25), (4, 4), 4)
            surface.blit(ss, (sx - 4, sy - 4))

    if health_pct <= 30:
        fi = 1.0 if health_pct > 10 else 2.0
        for _ in range(2 if health_pct > 10 else 4):
            fx = random.randint(cx - 14, cx + 14)
            fy = random.randint(10, 60)
            fw = abs(math.sin(t * 0.01 + fx))
            pygame.draw.circle(surface, (255, 255, 200), (fx, fy), int(2 * fi * (0.8 + fw * 0.2)))
            fs = pygame.Surface((6, 6), pygame.SRCALPHA)
            pygame.draw.circle(fs, (255, 100, 30, 120), (3, 3), 3)
            surface.blit(fs, (fx - 3, fy - 3))

    if health_pct <= 10 and random.random() < 0.2:
        ex = random.randint(cx - 12, cx + 12)
        ey = random.randint(10, 60)
        es = random.randint(5, 9)
        pygame.draw.circle(surface, (255, 255, 255), (ex, ey), es)
        pygame.draw.circle(surface, (255, 200, 100), (ex, ey), es - 2)

    return surface
