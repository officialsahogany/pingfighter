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
    """야차맨 변신 상태의 봄버맨 스타일 패들 그리기."""
    import math
    x, y = paddle_rect.centerx, paddle_rect.centery
    w, h = paddle_rect.width, paddle_rect.height

    # 봄버맨 몸통 (검은 둥근 직사각형)
    body_rect = pygame_module.Rect(x - w // 2, y - h // 2, w, h)
    pygame_module.draw.rect(screen, (25, 25, 30), body_rect, border_radius=6)

    # 봄버맨 눈 (흰색 원 + 검은 동공)
    eye_size = max(3, h // 5)
    eye_y = y - h // 6
    left_eye_x = x - w // 5
    right_eye_x = x + w // 5
    pygame_module.draw.circle(screen, (255, 255, 255), (left_eye_x, eye_y), eye_size)
    pygame_module.draw.circle(screen, (255, 255, 255), (right_eye_x, eye_y), eye_size)
    pygame_module.draw.circle(screen, (20, 20, 20), (left_eye_x, eye_y), eye_size // 2 + 1)
    pygame_module.draw.circle(screen, (20, 20, 20), (right_eye_x, eye_y), eye_size // 2 + 1)

    # 봄버맨 안테나/퓨즈 (머리 위 불꽃)
    fuse_x = x
    fuse_base_y = y - h // 2
    fuse_tip_y = fuse_base_y - max(6, h // 3)
    pygame_module.draw.line(screen, (80, 80, 80), (fuse_x, fuse_base_y), (fuse_x, fuse_tip_y), 2)

    # 불꽃 애니메이션
    flame_offset = math.sin(phase_timer * 0.15) * 2
    flame_colors = [(255, 200, 50), (255, 140, 0), (255, 80, 0)]
    for i, color in enumerate(flame_colors):
        fr = max(2, 5 - i)
        fy = fuse_tip_y - i * 2 + int(flame_offset)
        pygame_module.draw.circle(screen, color, (fuse_x, fy), fr)

    # 봄버맨 벨트 (가로 줄)
    belt_y = y + h // 6
    pygame_module.draw.line(screen, (80, 60, 0), (x - w // 2 + 3, belt_y), (x + w // 2 - 3, belt_y), 2)
    # 벨트 버클
    pygame_module.draw.circle(screen, (200, 180, 50), (x, belt_y), 3)

    # 테두리 하이라이트
    pygame_module.draw.rect(screen, (60, 60, 65), body_rect, width=1, border_radius=6)
