"""
야차맨의 영혼 (Yachaman Soul) — 머리 부위 패시브 아이템.

실점(패배) 시 일정 확률로 봄버맨 형상의 야차맨으로 변신하여 부활.
야차맨 상태: 이동속도 4 고정, 패들 사이즈 -30%, 검은 봄버맨 외형.
야차맨 상태에서 재패배 시 실점 처리.
"""

import random

# ── 야차맨 변신 상태 ──
yachaman_active = False          # 야차맨 변신 중 여부
yachaman_used_this_round = False # 이번 라운드에서 이미 발동했는지
yachaman_anim_active = False     # 변신 애니메이션 진행 중
yachaman_anim_timer = 0          # 애니메이션 타이머
yachaman_anim_phase = 0          # 0=수집, 1=폭발, 2=변신완료
yachaman_anim_x = 0              # 애니메이션 중심 X
yachaman_anim_y = 0              # 애니메이션 중심 Y
yachaman_particles = []          # 변신 파티클

# 야차맨 스탯
YACHAMAN_MOVE_SPEED = 4          # 고정 이동속도
YACHAMAN_PADDLE_SIZE_MULT = 0.7  # 패들 사이즈 70% (30% 감소)

# 애니메이션 상수
YACHAMAN_GATHER_FRAMES = 60      # 1초
YACHAMAN_BURST_FRAMES = 30       # 0.5초
YACHAMAN_TOTAL_FRAMES = 90       # 1.5초

# 활성화 확률 (롤옵션으로 결정, 기본 65%)
_activation_chance = 65
_enhancement_bonus_pct = 0


def set_activation_chance(chance: float):
    """롤옵션에서 결정된 발동 확률을 설정."""
    global _activation_chance
    _activation_chance = chance


def set_enhancement_bonus(pct: float):
    """강화 버프 보너스 설정."""
    global _enhancement_bonus_pct
    _enhancement_bonus_pct = pct


def get_activation_chance() -> float:
    """현재 발동 확률 반환 (연마 + 강화 보너스 포함)."""
    base = _activation_chance
    # 강화 보너스 적용
    if _enhancement_bonus_pct > 0:
        base = base * (1 + _enhancement_bonus_pct / 100)
    # 연마 퍽 보너스
    try:
        import pingfighter
        polish_level = pingfighter.runtime_skill_levels.get("legendary_polish", 0)
        if polish_level > 0:
            base = base * (1 + 0.03 * polish_level)
    except Exception:
        pass
    return min(base, 95)  # 최대 95% 캡


def try_activate() -> bool:
    """실점 시 야차맨 변신 시도. 성공 시 True."""
    global yachaman_active, yachaman_used_this_round
    global yachaman_anim_active, yachaman_anim_timer, yachaman_anim_phase

    if yachaman_active or yachaman_used_this_round:
        return False

    chance = get_activation_chance()
    roll = random.random() * 100
    if roll <= chance:
        yachaman_used_this_round = True
        yachaman_anim_active = True
        yachaman_anim_timer = 0
        yachaman_anim_phase = 0
        return True
    return False


def complete_transform():
    """애니메이션 완료 후 변신 상태 적용."""
    global yachaman_active, yachaman_anim_active
    yachaman_active = True
    yachaman_anim_active = False


def on_defeat_in_yachaman():
    """야차맨 상태에서 패배 시 — 변신 해제 + 실점 처리."""
    global yachaman_active
    yachaman_active = False


def reset_for_new_round():
    """라운드 시작 시 리셋 (변신 사용 여부 초기화)."""
    global yachaman_used_this_round, yachaman_active
    global yachaman_anim_active, yachaman_anim_timer, yachaman_anim_phase
    global yachaman_particles
    yachaman_used_this_round = False
    yachaman_active = False
    yachaman_anim_active = False
    yachaman_anim_timer = 0
    yachaman_anim_phase = 0
    yachaman_particles = []


def reset_all():
    """게임 오버/메인 메뉴 복귀 시 전체 초기화."""
    global yachaman_active, yachaman_used_this_round
    global yachaman_anim_active, yachaman_anim_timer, yachaman_anim_phase
    global yachaman_particles
    global _activation_chance, _enhancement_bonus_pct
    yachaman_active = False
    yachaman_used_this_round = False
    yachaman_anim_active = False
    yachaman_anim_timer = 0
    yachaman_anim_phase = 0
    yachaman_particles = []
    _activation_chance = 65
    _enhancement_bonus_pct = 0


def update_animation() -> bool:
    """애니메이션 업데이트. 완료 시 True 반환."""
    global yachaman_anim_timer, yachaman_anim_phase, yachaman_particles

    if not yachaman_anim_active:
        return False

    yachaman_anim_timer += 1

    if yachaman_anim_phase == 0 and yachaman_anim_timer >= YACHAMAN_GATHER_FRAMES:
        yachaman_anim_phase = 1
        yachaman_anim_timer = 0
        # 폭발 파티클 생성
        yachaman_particles = []
        for _ in range(40):
            angle = random.uniform(0, 6.283)
            speed = random.uniform(3, 12)
            import math
            yachaman_particles.append({
                "x": yachaman_anim_x,
                "y": yachaman_anim_y,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed,
                "life": random.randint(15, 30),
                "max_life": 30,
                "size": random.randint(3, 8),
                "color": random.choice([
                    (20, 20, 20), (40, 40, 40), (60, 30, 0),
                    (80, 40, 0), (255, 120, 0), (255, 80, 0)
                ])
            })

    elif yachaman_anim_phase == 1 and yachaman_anim_timer >= YACHAMAN_BURST_FRAMES:
        yachaman_anim_phase = 2
        complete_transform()
        return True

    # 파티클 업데이트
    for p in yachaman_particles:
        p["x"] += p["vx"]
        p["y"] += p["vy"]
        p["vy"] += 0.2  # 중력
        p["life"] -= 1

    yachaman_particles = [p for p in yachaman_particles if p["life"] > 0]
    return False


def draw_animation(screen, pygame_module):
    """변신 애니메이션 그리기."""
    import math
    if not yachaman_anim_active:
        return

    cx, cy = yachaman_anim_x, yachaman_anim_y

    if yachaman_anim_phase == 0:
        # 수집 페이즈: 검은 에너지 구체 + 나선형 수렴
        progress = yachaman_anim_timer / YACHAMAN_GATHER_FRAMES
        radius = int(10 + progress * 35)
        alpha = int(100 + progress * 155)

        # 검은 구체
        sphere = pygame_module.Surface((radius * 2, radius * 2), pygame_module.SRCALPHA)
        pygame_module.draw.circle(sphere, (20, 20, 25, alpha), (radius, radius), radius)
        screen.blit(sphere, (cx - radius, cy - radius))

        # 수렴하는 에너지 라인
        num_lines = 8
        for i in range(num_lines):
            angle = math.radians(i * 45 + yachaman_anim_timer * 6)
            dist = int((1 - progress) * 120 + 20)
            sx = cx + int(math.cos(angle) * dist)
            sy = cy + int(math.sin(angle) * dist)
            line_alpha = int(progress * 200)
            color = (255, 100 + int(progress * 80), 0, min(255, line_alpha))
            end_x = cx + int(math.cos(angle) * radius * 0.5)
            end_y = cy + int(math.sin(angle) * radius * 0.5)
            pygame_module.draw.line(screen, color[:3], (sx, sy), (end_x, end_y), 2)

    elif yachaman_anim_phase == 1:
        # 폭발 페이즈
        progress = yachaman_anim_timer / YACHAMAN_BURST_FRAMES

        # 폭발 링
        ring_radius = int(20 + progress * 80)
        ring_alpha = int(255 * (1 - progress))
        ring_surf = pygame_module.Surface((ring_radius * 2 + 4, ring_radius * 2 + 4), pygame_module.SRCALPHA)
        pygame_module.draw.circle(ring_surf, (255, 120, 0, ring_alpha),
                                  (ring_radius + 2, ring_radius + 2), ring_radius, 3)
        screen.blit(ring_surf, (cx - ring_radius - 2, cy - ring_radius - 2))

        # 파티클
        for p in yachaman_particles:
            alpha = int(255 * (p["life"] / p["max_life"]))
            s = pygame_module.Surface((p["size"], p["size"]), pygame_module.SRCALPHA)
            c = p["color"]
            pygame_module.draw.circle(s, (c[0], c[1], c[2], alpha),
                                      (p["size"] // 2, p["size"] // 2), p["size"] // 2)
            screen.blit(s, (int(p["x"]) - p["size"] // 2, int(p["y"]) - p["size"] // 2))

        # 중앙 플래시
        flash_alpha = int(255 * (1 - progress))
        flash_size = int(30 + progress * 20)
        flash = pygame_module.Surface((flash_size * 2, flash_size * 2), pygame_module.SRCALPHA)
        pygame_module.draw.circle(flash, (255, 255, 200, flash_alpha),
                                  (flash_size, flash_size), flash_size)
        screen.blit(flash, (cx - flash_size, cy - flash_size))


def draw_yachaman_paddle(screen, pygame_module, paddle_rect, phase_timer=0):
    """야차맨 변신 상태 - 봄버맨 풀 캐릭터 그리기 (패들 위에 봄버맨 전신)."""
    # 패들 히트박스는 그대로 유지 (투명), 봄버맨 캐릭터를 패들 위에 그림
    # 패들 바를 반투명으로 표시
    bar_surf = pygame_module.Surface((paddle_rect.width, paddle_rect.height), pygame_module.SRCALPHA)
    pygame_module.draw.rect(bar_surf, (30, 30, 35, 100), (0, 0, paddle_rect.width, paddle_rect.height), border_radius=4)
    screen.blit(bar_surf, paddle_rect.topleft)


# ── 봄버맨 캐릭터 전체 그리기 (패들 위) ──
_yachaman_walk_timer = 0
_yachaman_move_dir = 0  # -1=좌, 0=정지, 1=우
_yachaman_prev_x = 0


def draw_yachaman_character(screen, pygame_module, paddle_rect, phase_timer=0):
    """패들 위에 봄버맨 전신 캐릭터를 그리기 (걷기 모션 포함)."""
    import math
    global _yachaman_walk_timer, _yachaman_move_dir, _yachaman_prev_x

    draw = pygame_module.draw
    cx = paddle_rect.centerx
    foot_y = paddle_rect.top  # 발바닥 = 패들 상단

    # 이동 감지
    dx = cx - _yachaman_prev_x
    _yachaman_prev_x = cx
    if dx < -1:
        _yachaman_move_dir = -1
        _yachaman_walk_timer += 1
    elif dx > 1:
        _yachaman_move_dir = 1
        _yachaman_walk_timer += 1
    else:
        _yachaman_move_dir = 0
        _yachaman_walk_timer = 0

    walk_phase = (_yachaman_walk_timer * 0.18) % (2 * math.pi) if _yachaman_move_dir != 0 else 0
    walk_swing = math.sin(walk_phase)  # -1 ~ 1
    bob = int(abs(walk_swing) * 2) if _yachaman_move_dir != 0 else 0  # 상하 바운스

    # ── 크기 기준 (캐릭터 높이 ~60px) ──
    char_h = 58
    head_r = 14
    body_w = 22
    body_h = 18
    arm_len = 12
    arm_w = 5
    leg_len = 14
    leg_w = 5
    foot_w = 8
    foot_h = 4

    head_y = foot_y - char_h + head_r + bob
    body_top = head_y + head_r - 2
    body_bot = body_top + body_h
    hip_y = body_bot

    # 색상
    BLACK = (25, 25, 30)
    DARK = (35, 35, 40)
    WHITE = (255, 255, 255)
    PUPIL = (15, 15, 15)
    BELT_COL = (120, 90, 20)
    BUCKLE = (220, 200, 60)
    SHOE = (40, 40, 45)

    # ── 다리 (걷기 모션) ──
    leg_spread = 7
    left_leg_x = cx - leg_spread
    right_leg_x = cx + leg_spread

    if _yachaman_move_dir != 0:
        left_leg_offset = int(walk_swing * 6)
        right_leg_offset = int(-walk_swing * 6)
    else:
        left_leg_offset = 0
        right_leg_offset = 0

    # 왼쪽 다리
    ll_top = (left_leg_x, hip_y)
    ll_bot = (left_leg_x + left_leg_offset, hip_y + leg_len)
    draw.line(screen, BLACK, ll_top, ll_bot, leg_w)
    # 왼쪽 발
    lf_rect = pygame_module.Rect(ll_bot[0] - foot_w // 2, ll_bot[1], foot_w, foot_h)
    draw.ellipse(screen, SHOE, lf_rect)

    # 오른쪽 다리
    rl_top = (right_leg_x, hip_y)
    rl_bot = (right_leg_x + right_leg_offset, hip_y + leg_len)
    draw.line(screen, BLACK, rl_top, rl_bot, leg_w)
    # 오른쪽 발
    rf_rect = pygame_module.Rect(rl_bot[0] - foot_w // 2, rl_bot[1], foot_w, foot_h)
    draw.ellipse(screen, SHOE, rf_rect)

    # ── 몸통 ──
    body_rect = pygame_module.Rect(cx - body_w // 2, body_top, body_w, body_h)
    draw.rect(screen, BLACK, body_rect, border_radius=5)
    # 몸통 하이라이트
    hl_rect = pygame_module.Rect(cx - body_w // 2 + 3, body_top + 2, body_w - 6, body_h - 4)
    draw.rect(screen, DARK, hl_rect, border_radius=3)

    # 벨트
    belt_y = body_top + body_h - 5
    draw.line(screen, BELT_COL, (cx - body_w // 2 + 2, belt_y), (cx + body_w // 2 - 2, belt_y), 2)
    draw.circle(screen, BUCKLE, (cx, belt_y), 3)

    # ── 팔 (걷기 시 반대 스윙) ──
    shoulder_y = body_top + 4

    if _yachaman_move_dir != 0:
        left_arm_swing = int(-walk_swing * 5)
        right_arm_swing = int(walk_swing * 5)
    else:
        left_arm_swing = 0
        right_arm_swing = 0

    # 왼팔
    la_top = (cx - body_w // 2 - 1, shoulder_y)
    la_bot = (cx - body_w // 2 - arm_len + left_arm_swing, shoulder_y + arm_len)
    draw.line(screen, BLACK, la_top, la_bot, arm_w)
    # 왼손 (둥글)
    draw.circle(screen, DARK, la_bot, 3)

    # 오른팔
    ra_top = (cx + body_w // 2 + 1, shoulder_y)
    ra_bot = (cx + body_w // 2 + arm_len + right_arm_swing, shoulder_y + arm_len)
    draw.line(screen, BLACK, ra_top, ra_bot, arm_w)
    draw.circle(screen, DARK, ra_bot, 3)

    # ── 머리 (큰 둥근 봄버맨 헤드) ──
    draw.circle(screen, BLACK, (cx, head_y), head_r)
    # 머리 하이라이트
    draw.circle(screen, DARK, (cx - 3, head_y - 4), int(head_r * 0.6))

    # ── 눈 ──
    eye_r = 4
    eye_y_pos = head_y + 1
    pupil_r = 2
    # 이동 방향에 따라 동공 시선
    pupil_offset = _yachaman_move_dir * 1

    for side in [-1, 1]:
        ex = cx + side * 6
        draw.circle(screen, WHITE, (ex, eye_y_pos), eye_r)
        draw.circle(screen, PUPIL, (ex + pupil_offset, eye_y_pos), pupil_r)

    # ── 퓨즈 + 불꽃 ──
    fuse_base = (cx + 2, head_y - head_r + 2)
    fuse_tip = (cx + 5, head_y - head_r - 10 + bob)
    draw.line(screen, (90, 80, 70), fuse_base, fuse_tip, 2)

    # 불꽃 (흔들림)
    flame_x = fuse_tip[0]
    flame_y = fuse_tip[1]
    flame_wobble = math.sin(phase_timer * 0.2) * 2
    flames = [(255, 220, 80, 5), (255, 160, 30, 4), (255, 80, 0, 3)]
    for r, g, b, fr in flames:
        fy = int(flame_y - (5 - fr) * 1.5 + flame_wobble)
        fx = int(flame_x + flame_wobble * 0.5)
        draw.circle(screen, (r, g, b), (fx, fy), fr)

    # ── ? 마크 (봄버맨 몸통 중앙) ──
    try:
        font = pygame_module.font.Font(None, 16)
        q_surf = font.render("?", True, (180, 180, 180))
        q_rect = q_surf.get_rect(center=(cx, body_top + body_h // 2 - 1))
        screen.blit(q_surf, q_rect)
    except Exception:
        pass
