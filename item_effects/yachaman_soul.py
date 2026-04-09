"""Yachaman Soul passive item runtime."""

from __future__ import annotations

import math
import random

# Transformation state
yachaman_active = False
yachaman_used_this_round = False
yachaman_anim_active = False
yachaman_anim_timer = 0
yachaman_anim_phase = 0  # 0=gather, 1=burst, 2=complete
yachaman_anim_x = 0
yachaman_anim_y = 0
yachaman_particles = []

# Transformation stats
YACHAMAN_MOVE_SPEED = 4
YACHAMAN_PADDLE_SIZE_MULT = 0.7

# Animation timings
YACHAMAN_GATHER_FRAMES = 60
YACHAMAN_BURST_FRAMES = 30
YACHAMAN_TOTAL_FRAMES = 90

# Activation chance
_activation_chance = 65
_enhancement_bonus_pct = 0


def set_activation_chance(chance: float):
    """Set the base activation chance from runtime loot state."""
    global _activation_chance
    _activation_chance = chance


def set_enhancement_bonus(pct: float):
    """Set the runtime enhancement bonus percent."""
    global _enhancement_bonus_pct
    _enhancement_bonus_pct = pct


def get_activation_chance() -> float:
    """Return the current activation chance including bonuses."""
    base = _activation_chance
    if _enhancement_bonus_pct > 0:
        base = base * (1 + _enhancement_bonus_pct / 100)

    try:
        import pingfighter

        polish_level = pingfighter.runtime_skill_levels.get("legendary_polish", 0)
        if polish_level > 0:
            base = base * (1 + 0.03 * polish_level)
    except Exception:
        pass

    return min(base, 95)


def try_activate() -> bool:
    """Try to start the revival transformation animation."""
    global yachaman_used_this_round
    global yachaman_anim_active, yachaman_anim_timer, yachaman_anim_phase

    if yachaman_active or yachaman_used_this_round:
        return False

    if random.random() * 100 <= get_activation_chance():
        yachaman_used_this_round = True
        yachaman_anim_active = True
        yachaman_anim_timer = 0
        yachaman_anim_phase = 0
        return True
    return False


def complete_transform():
    """Finish the animation and enter the transformed state."""
    global yachaman_active, yachaman_anim_active
    yachaman_active = True
    yachaman_anim_active = False


def on_defeat_in_yachaman():
    """Lose the transformation after getting scored on in transformed state."""
    global yachaman_active
    yachaman_active = False


def reset_for_new_round():
    """Reset round-scoped state for the next round."""
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
    """Reset all runtime state when leaving gameplay."""
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
    """Advance the transformation animation. Returns True on completion."""
    global yachaman_anim_timer, yachaman_anim_phase, yachaman_particles

    if not yachaman_anim_active:
        return False

    yachaman_anim_timer += 1

    if yachaman_anim_phase == 0 and yachaman_anim_timer >= YACHAMAN_GATHER_FRAMES:
        yachaman_anim_phase = 1
        yachaman_anim_timer = 0
        yachaman_particles = []
        for _ in range(40):
            angle = random.uniform(0, math.tau)
            speed = random.uniform(3, 12)
            yachaman_particles.append(
                {
                    "x": yachaman_anim_x,
                    "y": yachaman_anim_y,
                    "vx": math.cos(angle) * speed,
                    "vy": math.sin(angle) * speed,
                    "life": random.randint(15, 30),
                    "max_life": 30,
                    "size": random.randint(3, 8),
                    "color": random.choice(
                        [
                            (20, 20, 20),
                            (40, 40, 40),
                            (60, 30, 0),
                            (80, 40, 0),
                            (255, 120, 0),
                            (255, 80, 0),
                        ]
                    ),
                }
            )
    elif yachaman_anim_phase == 1 and yachaman_anim_timer >= YACHAMAN_BURST_FRAMES:
        yachaman_anim_phase = 2
        complete_transform()
        return True

    for particle in yachaman_particles:
        particle["x"] += particle["vx"]
        particle["y"] += particle["vy"]
        particle["vy"] += 0.2
        particle["life"] -= 1

    yachaman_particles = [particle for particle in yachaman_particles if particle["life"] > 0]
    return False


def draw_animation(screen, pygame_module):
    """Draw the transformation animation."""
    if not yachaman_anim_active:
        return

    cx, cy = yachaman_anim_x, yachaman_anim_y

    if yachaman_anim_phase == 0:
        progress = yachaman_anim_timer / YACHAMAN_GATHER_FRAMES
        radius = int(10 + progress * 35)
        alpha = int(100 + progress * 155)

        sphere = pygame_module.Surface((radius * 2, radius * 2), pygame_module.SRCALPHA)
        pygame_module.draw.circle(sphere, (20, 20, 25, alpha), (radius, radius), radius)
        screen.blit(sphere, (cx - radius, cy - radius))

        for i in range(8):
            angle = math.radians(i * 45 + yachaman_anim_timer * 6)
            dist = int((1 - progress) * 120 + 20)
            sx = cx + int(math.cos(angle) * dist)
            sy = cy + int(math.sin(angle) * dist)
            color = (255, 100 + int(progress * 80), 0)
            end_x = cx + int(math.cos(angle) * radius * 0.5)
            end_y = cy + int(math.sin(angle) * radius * 0.5)
            pygame_module.draw.line(screen, color, (sx, sy), (end_x, end_y), 2)

    elif yachaman_anim_phase == 1:
        progress = yachaman_anim_timer / YACHAMAN_BURST_FRAMES

        ring_radius = int(20 + progress * 80)
        ring_alpha = int(255 * (1 - progress))
        ring_surf = pygame_module.Surface((ring_radius * 2 + 4, ring_radius * 2 + 4), pygame_module.SRCALPHA)
        pygame_module.draw.circle(
            ring_surf,
            (255, 120, 0, ring_alpha),
            (ring_radius + 2, ring_radius + 2),
            ring_radius,
            3,
        )
        screen.blit(ring_surf, (cx - ring_radius - 2, cy - ring_radius - 2))

        for particle in yachaman_particles:
            alpha = int(255 * (particle["life"] / particle["max_life"]))
            size = particle["size"]
            part_surf = pygame_module.Surface((size, size), pygame_module.SRCALPHA)
            color = particle["color"]
            pygame_module.draw.circle(
                part_surf,
                (color[0], color[1], color[2], alpha),
                (size // 2, size // 2),
                size // 2,
            )
            screen.blit(part_surf, (int(particle["x"]) - size // 2, int(particle["y"]) - size // 2))

        flash_alpha = int(255 * (1 - progress))
        flash_size = int(30 + progress * 20)
        flash = pygame_module.Surface((flash_size * 2, flash_size * 2), pygame_module.SRCALPHA)
        pygame_module.draw.circle(
            flash,
            (255, 255, 200, flash_alpha),
            (flash_size, flash_size),
            flash_size,
        )
        screen.blit(flash, (cx - flash_size, cy - flash_size))


def draw_yachaman_paddle(screen, pygame_module, paddle_rect, phase_timer=0):
    """패들 히트박스는 투명 (캐릭터만 표시)."""
    pass


_yachaman_walk_timer = 0
_yachaman_move_dir = 0
_yachaman_prev_x = 0


def draw_yachaman_character(screen, pygame_module, paddle_rect, phase_timer=0):
    """Draw the transformed Yachaman character above the paddle."""
    global _yachaman_walk_timer, _yachaman_move_dir, _yachaman_prev_x

    draw = pygame_module.draw
    cx = paddle_rect.centerx
    # 발바닥 = 패들 하단 (패들에 밀착)
    foot_y = paddle_rect.bottom

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

    walk_phase = (_yachaman_walk_timer * 0.18) % math.tau if _yachaman_move_dir != 0 else 0.0
    walk_swing = math.sin(walk_phase)
    bob = int(abs(walk_swing) * 2) if _yachaman_move_dir != 0 else 0

    # ── 크기 기준 ──
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
    hip_y = body_top + body_h

    # 색상
    BLACK = (25, 25, 30)
    DARK = (35, 35, 40)
    DARKER = (18, 18, 22)
    BELT_COL = (120, 90, 20)
    SHOE = (40, 40, 45)

    # ── 다리 (걷기 모션) ──
    leg_spread = 7
    if _yachaman_move_dir != 0:
        l_off = int(walk_swing * 6)
        r_off = int(-walk_swing * 6)
    else:
        l_off = 0
        r_off = 0

    for side, offset in [(-1, l_off), (1, r_off)]:
        lx = cx + side * leg_spread
        top = (lx, hip_y)
        bot = (lx + offset, hip_y + leg_len)
        draw.line(screen, BLACK, top, bot, leg_w)
        draw.ellipse(screen, SHOE,
                     pygame_module.Rect(bot[0] - foot_w // 2, bot[1], foot_w, foot_h))

    # ── 몸통 ──
    body_rect = pygame_module.Rect(cx - body_w // 2, body_top, body_w, body_h)
    draw.rect(screen, BLACK, body_rect, border_radius=5)
    # 뒷면 세로줄 (등 디테일)
    draw.line(screen, DARKER, (cx, body_top + 3), (cx, body_top + body_h - 4), 2)

    # 벨트 (뒷면에서도 보임)
    belt_y = body_top + body_h - 5
    draw.line(screen, BELT_COL, (cx - body_w // 2 + 2, belt_y), (cx + body_w // 2 - 2, belt_y), 2)

    # ── 팔 (걷기 반대 스윙) ──
    shoulder_y = body_top + 4
    if _yachaman_move_dir != 0:
        la_sw = int(-walk_swing * 5)
        ra_sw = int(walk_swing * 5)
    else:
        la_sw = 0
        ra_sw = 0

    for side, sw in [(-1, la_sw), (1, ra_sw)]:
        a_top = (cx + side * (body_w // 2 + 1), shoulder_y)
        a_bot = (cx + side * (body_w // 2 + arm_len) + sw, shoulder_y + arm_len)
        draw.line(screen, BLACK, a_top, a_bot, arm_w)
        draw.circle(screen, DARK, a_bot, 3)

    # ── 머리 (뒷모습 — 둥근 검은 뒤통수) ──
    draw.circle(screen, BLACK, (cx, head_y), head_r)
    # 뒤통수 하이라이트 (약간 위쪽 밝은 반달)
    hl_surf = pygame_module.Surface((head_r * 2, head_r * 2), pygame_module.SRCALPHA)
    pygame_module.draw.circle(hl_surf, (40, 40, 45, 120),
                              (head_r, head_r - 3), int(head_r * 0.7))
    screen.blit(hl_surf, (cx - head_r, head_y - head_r))

    # ── 퓨즈 + 불꽃 (뒤에서도 머리 위에 보임) ──
    fuse_base = (cx, head_y - head_r + 2)
    fuse_tip = (cx + 3, head_y - head_r - 10 + bob)
    draw.line(screen, (90, 80, 70), fuse_base, fuse_tip, 2)

    flame_wobble = math.sin(phase_timer * 0.2) * 2
    for r, g, b, fr in [(255, 220, 80, 5), (255, 160, 30, 4), (255, 80, 0, 3)]:
        fy = int(fuse_tip[1] - (5 - fr) * 1.5 + flame_wobble)
        fx = int(fuse_tip[0] + flame_wobble * 0.5)
        draw.circle(screen, (r, g, b), (fx, fy), fr)

    # ── 머리 테두리 ──
    draw.circle(screen, DARKER, (cx, head_y), head_r, 1)
