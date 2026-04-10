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
    reset_bomb_spin()


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
    reset_bomb_spin()


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

    skill_active = bomb_spin_active
    skill_phase = bomb_spin_phase if skill_active else -1
    skill_dir = bomb_spin_direction if bomb_spin_direction != 0 else (_yachaman_move_dir if _yachaman_move_dir != 0 else 1)

    # 이동 감지
    dx = cx - _yachaman_prev_x
    _yachaman_prev_x = cx
    if skill_active:
        if bomb_spin_direction != 0:
            _yachaman_move_dir = bomb_spin_direction
        if skill_phase == 2 and abs(dx) > 0.5:
            _yachaman_walk_timer += 1
        else:
            _yachaman_walk_timer = max(0, _yachaman_walk_timer - 1)
    elif dx < -1:
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
    bob = int(abs(walk_swing) * 2) if _yachaman_move_dir != 0 and not skill_active else 0

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
    ARM_GLOW = (255, 170, 70)

    recovery_progress = 0.0
    if skill_active and skill_phase == 3:
        rec_t = bomb_spin_timer - BOMB_SPIN_WINDUP - BOMB_SPIN_SPIN1 - BOMB_SPIN_SPIN2
        recovery_progress = min(1.0, max(0.0, rec_t / max(1, BOMB_SPIN_RECOVERY)))

    body_shift_x = 0
    torso_offset_y = 0
    if skill_active:
        if skill_phase == 0:
            body_shift_x = int(skill_dir * 2)
            torso_offset_y = 2
        elif skill_phase == 1:
            body_shift_x = int(math.sin(bomb_spin_angle) * 2)
            torso_offset_y = int(math.cos(bomb_spin_angle * 2.0) * 2)
        elif skill_phase == 2:
            body_shift_x = int(skill_dir * 5 + math.sin(bomb_spin_angle) * 2)
            torso_offset_y = -1 + int(math.cos(bomb_spin_angle * 2.0) * 2)
        elif skill_phase == 3:
            body_shift_x = int(skill_dir * 3 * (1.0 - recovery_progress))
            torso_offset_y = int(2 * (1.0 - recovery_progress))

    body_cx = cx + body_shift_x
    body_top += torso_offset_y
    hip_y += torso_offset_y

    if skill_active and skill_phase in (1, 2):
        spin_shadow_w = 24 + int(abs(math.sin(bomb_spin_angle)) * 8)
        shadow_rect = pygame_module.Rect(body_cx - spin_shadow_w // 2, foot_y - 3, spin_shadow_w, 7)
        draw.ellipse(screen, (18, 18, 22), shadow_rect)
        swirl_rect = pygame_module.Rect(body_cx - 18, body_top - 4, 36, 30)
        swirl_start = bomb_spin_angle + (0.3 if skill_phase == 2 else 0.0)
        draw.arc(screen, ARM_GLOW, swirl_rect, swirl_start, swirl_start + math.pi * 1.15, 2)

    # ── 다리 (걷기 / 회전 자세) ──
    leg_spread = 7
    if skill_active:
        leg_spread = 9
        if skill_phase == 0:
            l_off = -skill_dir * 2
            r_off = skill_dir * 2
        elif skill_phase == 1:
            twist = math.sin(bomb_spin_angle)
            l_off = int(twist * 5)
            r_off = int(-twist * 5)
        elif skill_phase == 2:
            twist = math.sin(bomb_spin_angle)
            l_off = int(skill_dir * 4 + twist * 3)
            r_off = int(skill_dir * 2 - twist * 3)
        else:
            settle = 1.0 - recovery_progress
            l_off = int(skill_dir * 2 * settle)
            r_off = int(skill_dir * 1 * settle)
    elif _yachaman_move_dir != 0:
        l_off = int(walk_swing * 6)
        r_off = int(-walk_swing * 6)
    else:
        l_off = 0
        r_off = 0

    for side, offset in [(-1, l_off), (1, r_off)]:
        lx = body_cx + side * leg_spread
        top = (lx, hip_y)
        bot = (lx + offset, hip_y + leg_len)
        draw.line(screen, BLACK, top, bot, leg_w)
        draw.ellipse(screen, SHOE,
                     pygame_module.Rect(bot[0] - foot_w // 2, bot[1], foot_w, foot_h))

    # ── 몸통 ──
    body_rect = pygame_module.Rect(body_cx - body_w // 2, body_top, body_w, body_h)
    draw.rect(screen, BLACK, body_rect, border_radius=5)
    # 뒷면 세로줄 (등 디테일)
    draw.line(screen, DARKER, (body_cx, body_top + 3), (body_cx, body_top + body_h - 4), 2)

    # 벨트 (뒷면에서도 보임)
    belt_y = body_top + body_h - 5
    draw.line(screen, BELT_COL, (body_cx - body_w // 2 + 2, belt_y), (body_cx + body_w // 2 - 2, belt_y), 2)

    # ── 팔 (걷기 / 폭탄돌리기 포즈) ──
    shoulder_y = body_top + 4
    if skill_active:
        if skill_phase == 0:
            extend = min(1.0, bomb_spin_timer / max(1, BOMB_SPIN_WINDUP))
        elif skill_phase in (1, 2):
            extend = 1.0
        else:
            extend = max(0.4, 1.0 - recovery_progress * 0.4)

        hold_x = bomb_spin_helmet_x if bomb_spin_helmet_x != 0 else body_cx
        hold_y = bomb_spin_helmet_y if bomb_spin_helmet_y != 0 else head_y - head_r

        for side in (-1, 1):
            shoulder = (body_cx + side * (body_w // 2 + 1), shoulder_y)
            hand_target = (
                int(shoulder[0] + ((hold_x + side * 4) - shoulder[0]) * extend),
                int(shoulder[1] + ((hold_y + 2) - shoulder[1]) * extend),
            )
            elbow_bias_y = -9 if skill_phase in (0, 1) else -6
            elbow = (
                int((shoulder[0] + hand_target[0]) * 0.5 + side * 6 - skill_dir * 2),
                int((shoulder[1] + hand_target[1]) * 0.5 + elbow_bias_y),
            )
            draw.line(screen, BLACK, shoulder, elbow, arm_w)
            draw.line(screen, BLACK, elbow, hand_target, arm_w)
            draw.circle(screen, DARK, hand_target, 3)
            if skill_phase in (1, 2):
                draw.line(screen, ARM_GLOW, elbow, hand_target, 1)
    elif _yachaman_move_dir != 0:
        la_sw = int(-walk_swing * 5)
        ra_sw = int(walk_swing * 5)
        for side, sw in [(-1, la_sw), (1, ra_sw)]:
            a_top = (body_cx + side * (body_w // 2 + 1), shoulder_y)
            a_bot = (body_cx + side * (body_w // 2 + arm_len) + sw, shoulder_y + arm_len)
            draw.line(screen, BLACK, a_top, a_bot, arm_w)
            draw.circle(screen, DARK, a_bot, 3)
    else:
        for side in (-1, 1):
            a_top = (body_cx + side * (body_w // 2 + 1), shoulder_y)
            a_bot = (body_cx + side * (body_w // 2 + arm_len), shoulder_y + arm_len)
            draw.line(screen, BLACK, a_top, a_bot, arm_w)
            draw.circle(screen, DARK, a_bot, 3)

    # ── 머리 / 투구를 벗은 자리 ──
    if skill_active:
        neck_rect = pygame_module.Rect(body_cx - 8, head_y - 3, 16, 10)
        draw.ellipse(screen, DARK, neck_rect)
        core_surf = pygame_module.Surface((18, 18), pygame_module.SRCALPHA)
        pygame_module.draw.circle(core_surf, (255, 120, 20, 80), (9, 9), 7)
        screen.blit(core_surf, (body_cx - 9, head_y - 10))
        draw.line(screen, (255, 210, 120), (body_cx - 3, head_y - 2), (body_cx + 3, head_y - 2), 2)
        if skill_phase in (1, 2):
            spark_offset = int(math.sin(bomb_spin_angle * 2.0) * 2)
            draw.circle(screen, (255, 160, 40), (body_cx - 5, head_y - 9 + spark_offset), 2)
            draw.circle(screen, (255, 110, 10), (body_cx + 5, head_y - 11 - spark_offset), 2)
    else:
        draw.circle(screen, BLACK, (body_cx, head_y), head_r)
        # 뒤통수 하이라이트 (약간 위쪽 밝은 반달)
        hl_surf = pygame_module.Surface((head_r * 2, head_r * 2), pygame_module.SRCALPHA)
        pygame_module.draw.circle(hl_surf, (40, 40, 45, 120),
                                  (head_r, head_r - 3), int(head_r * 0.7))
        screen.blit(hl_surf, (body_cx - head_r, head_y - head_r))

        # ── 퓨즈 + 불꽃 (뒤에서도 머리 위에 보임) ──
        fuse_base = (body_cx, head_y - head_r + 2)
        fuse_tip = (body_cx + 3, head_y - head_r - 10 + bob)
        draw.line(screen, (90, 80, 70), fuse_base, fuse_tip, 2)

        flame_wobble = math.sin(phase_timer * 0.2) * 2
        for r, g, b, fr in [(255, 220, 80, 5), (255, 160, 30, 4), (255, 80, 0, 3)]:
            fy = int(fuse_tip[1] - (5 - fr) * 1.5 + flame_wobble)
            fx = int(fuse_tip[0] + flame_wobble * 0.5)
            draw.circle(screen, (r, g, b), (fx, fy), fr)

        # ── 머리 테두리 ──
        draw.circle(screen, DARKER, (body_cx, head_y), head_r, 1)


# ============================================================================
# 💣 폭탄돌리기 스킬 (Bomb Spin)
# ============================================================================
# 이동 중 Space/좌클릭 → 양손으로 투구 잡고 2바퀴 회전 → 2바퀴째 전진 대시
# 투구(검은 원)도 공과 충돌 판정

# ── 스킬 상태 ──
bomb_spin_active = False
bomb_spin_timer = 0
bomb_spin_phase = 0        # 0=준비, 1=1바퀴, 2=2바퀴+대시, 3=종료
bomb_spin_direction = 0    # -1=좌, 1=우 (발동 시 이동 방향)
bomb_spin_angle = 0.0      # 현재 회전 각도 (라디안)
bomb_spin_cooldown = 0     # 쿨다운 타이머

# 투구 히트박스 (공 충돌용)
bomb_spin_helmet_x = 0
bomb_spin_helmet_y = 0
BOMB_SPIN_HELMET_R = 14    # 투구 반지름

# ── 폭탄 장전 상태 (공에 폭탄 실림) ──
bomb_loaded_on_ball = False           # 공에 폭탄이 실린 상태
bomb_explosion_active = False         # 폭발 애니메이션 진행 중
bomb_explosion_timer = 0
bomb_explosion_x = 0
bomb_explosion_y = 0
BOMB_EXPLOSION_FRAMES = 30           # 폭발 애니메이션 0.5초
BOMB_STUN_DURATION = 60              # 1초 스턴 (60프레임)
BOMB_KNOCKBACK_POWER = 15.0          # 넉백 강도
bomb_explosion_particles = []

# 타이밍 (프레임 @ 60fps)
BOMB_SPIN_WINDUP = 8       # 준비 (팔 내밈)
BOMB_SPIN_SPIN1 = 20       # 1바퀴 회전
BOMB_SPIN_SPIN2 = 20       # 2바퀴 회전 + 대시
BOMB_SPIN_RECOVERY = 10    # 복귀
BOMB_SPIN_TOTAL = BOMB_SPIN_WINDUP + BOMB_SPIN_SPIN1 + BOMB_SPIN_SPIN2 + BOMB_SPIN_RECOVERY
BOMB_SPIN_COOLDOWN = 90    # 쿨다운 1.5초
BOMB_SPIN_SPIN1_SPEED = 6   # 1바퀴째 이동 속도 (px/frame)
BOMB_SPIN_DASH_SPEED = 22   # 2바퀴째 대시 속도 (px/frame)


def try_bomb_spin(direction: int) -> bool:
    """폭탄돌리기 시도. 이동 중(direction!=0)이고 쿨다운이 아닐 때 발동."""
    global bomb_spin_active, bomb_spin_timer, bomb_spin_phase
    global bomb_spin_direction, bomb_spin_angle

    if not yachaman_active:
        return False
    if bomb_spin_active or bomb_spin_cooldown > 0:
        return False
    if direction == 0:
        return False

    bomb_spin_active = True
    bomb_spin_timer = 0
    bomb_spin_phase = 0
    bomb_spin_direction = direction
    bomb_spin_angle = 0.0
    return True


def update_bomb_spin(player_cx: int, player_cy: int) -> dict:
    """매 프레임 호출. 플레이어 중심 좌표 전달.
    Returns dict: {dx: 이동량, helmet_rect: (x,y,r) or None, done: bool}
    """
    global bomb_spin_active, bomb_spin_timer, bomb_spin_phase
    global bomb_spin_angle, bomb_spin_cooldown
    global bomb_spin_helmet_x, bomb_spin_helmet_y

    # 쿨다운 감소
    if bomb_spin_cooldown > 0:
        bomb_spin_cooldown -= 1

    if not bomb_spin_active:
        return {"dx": 0, "helmet_rect": None, "done": False}

    bomb_spin_timer += 1
    dx = 0
    helmet = None

    t = bomb_spin_timer

    # 회전 중심 = 몸통 중앙 (팔을 앞으로 나란히 내린 높이)
    spin_center_y = player_cy - 15  # 어깨~몸통 중간

    if t <= BOMB_SPIN_WINDUP:
        # 준비: 투구를 머리에서 앞으로 나란히 자세로 내림
        bomb_spin_phase = 0
        progress = t / BOMB_SPIN_WINDUP
        # 머리 위(-50) → 앞으로 나란히 높이(0)로 이동
        start_y = player_cy - 50
        end_y = spin_center_y
        bomb_spin_helmet_x = player_cx + int(bomb_spin_direction * progress * 30)
        bomb_spin_helmet_y = int(start_y + (end_y - start_y) * progress)
        helmet = (bomb_spin_helmet_x, bomb_spin_helmet_y, BOMB_SPIN_HELMET_R)

    elif t <= BOMB_SPIN_WINDUP + BOMB_SPIN_SPIN1:
        # 1바퀴: 큰 원 회전 (좌우로 넓게) + 전진
        bomb_spin_phase = 1
        spin_t = t - BOMB_SPIN_WINDUP
        bomb_spin_angle = (spin_t / BOMB_SPIN_SPIN1) * math.pi * 2
        progress = spin_t / BOMB_SPIN_SPIN1
        speed = BOMB_SPIN_SPIN1_SPEED * min(1.0, progress * 2)
        dx = int(bomb_spin_direction * speed)
        # 큰 궤도: X축 넓게(35px), Y축도 적당히(20px)
        orbit_rx = 35
        orbit_ry = 20
        bomb_spin_helmet_x = player_cx + int(math.sin(bomb_spin_angle) * orbit_rx)
        bomb_spin_helmet_y = spin_center_y + int(-math.cos(bomb_spin_angle) * orbit_ry)
        helmet = (bomb_spin_helmet_x, bomb_spin_helmet_y, BOMB_SPIN_HELMET_R)

    elif t <= BOMB_SPIN_WINDUP + BOMB_SPIN_SPIN1 + BOMB_SPIN_SPIN2:
        # 2바퀴: 더 큰 원 회전 + 고속 대시
        bomb_spin_phase = 2
        spin_t = t - BOMB_SPIN_WINDUP - BOMB_SPIN_SPIN1
        bomb_spin_angle = (spin_t / BOMB_SPIN_SPIN2) * math.pi * 2
        progress = spin_t / BOMB_SPIN_SPIN2
        speed = BOMB_SPIN_DASH_SPEED * (1.0 - progress * 0.4)
        dx = int(bomb_spin_direction * speed)
        # 더 큰 궤도 + 전방 오프셋
        orbit_rx = 40
        orbit_ry = 22
        fwd_offset = int(bomb_spin_direction * 22)
        bomb_spin_helmet_x = player_cx + fwd_offset + int(math.sin(bomb_spin_angle) * orbit_rx)
        bomb_spin_helmet_y = spin_center_y + int(-math.cos(bomb_spin_angle) * orbit_ry)
        helmet = (bomb_spin_helmet_x, bomb_spin_helmet_y, BOMB_SPIN_HELMET_R)

    else:
        # 복귀
        bomb_spin_phase = 3
        rec_t = t - BOMB_SPIN_WINDUP - BOMB_SPIN_SPIN1 - BOMB_SPIN_SPIN2
        if rec_t >= BOMB_SPIN_RECOVERY:
            bomb_spin_active = False
            bomb_spin_cooldown = BOMB_SPIN_COOLDOWN
            bomb_spin_phase = 0
            return {"dx": 0, "helmet_rect": None, "done": True}
        # 투구가 앞으로나란히 → 머리로 돌아감
        progress = rec_t / BOMB_SPIN_RECOVERY
        bomb_spin_helmet_x = player_cx
        bomb_spin_helmet_y = int(spin_center_y + (player_cy - 50 - spin_center_y) * progress)
        helmet = (bomb_spin_helmet_x, bomb_spin_helmet_y, BOMB_SPIN_HELMET_R)

    return {"dx": dx, "helmet_rect": helmet, "done": False}


def check_bomb_spin_ball_collision(ball_rect) -> bool:
    """투구와 공의 충돌 판정. 충돌 시 True + 공에 폭탄 장전."""
    global bomb_loaded_on_ball
    if not bomb_spin_active or bomb_spin_phase not in (1, 2):
        return False
    bcx = ball_rect.centerx
    bcy = ball_rect.centery
    dist = math.hypot(bcx - bomb_spin_helmet_x, bcy - bomb_spin_helmet_y)
    if dist < BOMB_SPIN_HELMET_R + ball_rect.width // 2:
        bomb_loaded_on_ball = True  # 공에 폭탄 실림!
        return True
    return False


def trigger_bomb_explosion(boss_cx: int, boss_cy: int):
    """보스가 폭탄 공을 반격 시 폭발 발동. 넉백+스턴 적용을 위한 데이터 반환."""
    global bomb_loaded_on_ball, bomb_explosion_active, bomb_explosion_timer
    global bomb_explosion_x, bomb_explosion_y, bomb_explosion_particles

    if not bomb_loaded_on_ball:
        return None

    bomb_loaded_on_ball = False
    bomb_explosion_active = True
    bomb_explosion_timer = 0
    bomb_explosion_x = boss_cx
    bomb_explosion_y = boss_cy

    # 폭발 파티클
    bomb_explosion_particles = []
    for _ in range(30):
        angle = random.uniform(0, math.pi * 2)
        speed = random.uniform(2, 10)
        bomb_explosion_particles.append({
            "x": float(boss_cx), "y": float(boss_cy),
            "vx": math.cos(angle) * speed,
            "vy": math.sin(angle) * speed,
            "life": random.randint(15, 30),
            "max_life": 30,
            "size": random.randint(3, 7),
            "color": random.choice([
                (255, 200, 50), (255, 140, 0), (255, 80, 0),
                (40, 40, 40), (60, 60, 60)
            ])
        })

    return {
        "stun_frames": BOMB_STUN_DURATION,
        "knockback": BOMB_KNOCKBACK_POWER,
    }


def update_bomb_explosion():
    """폭발 애니메이션 업데이트."""
    global bomb_explosion_active, bomb_explosion_timer, bomb_explosion_particles

    if not bomb_explosion_active:
        return

    bomb_explosion_timer += 1
    if bomb_explosion_timer >= BOMB_EXPLOSION_FRAMES:
        bomb_explosion_active = False
        bomb_explosion_particles = []
        return

    for p in bomb_explosion_particles:
        p["x"] += p["vx"]
        p["y"] += p["vy"]
        p["vy"] += 0.3
        p["vx"] *= 0.95
        p["life"] -= 1
    bomb_explosion_particles = [p for p in bomb_explosion_particles if p["life"] > 0]


def draw_bomb_explosion(screen, pygame_module):
    """폭발 이펙트 그리기."""
    if not bomb_explosion_active:
        return

    draw = pygame_module.draw
    progress = bomb_explosion_timer / BOMB_EXPLOSION_FRAMES

    # 폭발 링
    ring_r = int(15 + progress * 60)
    ring_alpha = int(255 * (1 - progress))
    ring_surf = pygame_module.Surface((ring_r * 2 + 4, ring_r * 2 + 4), pygame_module.SRCALPHA)
    pygame_module.draw.circle(ring_surf, (255, 160, 0, ring_alpha),
                              (ring_r + 2, ring_r + 2), ring_r, 3)
    screen.blit(ring_surf, (bomb_explosion_x - ring_r - 2, bomb_explosion_y - ring_r - 2))

    # 내부 플래시
    if progress < 0.3:
        flash_r = int(25 * (1 - progress / 0.3))
        flash_alpha = int(200 * (1 - progress / 0.3))
        flash = pygame_module.Surface((flash_r * 2, flash_r * 2), pygame_module.SRCALPHA)
        pygame_module.draw.circle(flash, (255, 255, 200, flash_alpha),
                                  (flash_r, flash_r), flash_r)
        screen.blit(flash, (bomb_explosion_x - flash_r, bomb_explosion_y - flash_r))

    # 파티클
    for p in bomb_explosion_particles:
        alpha = int(255 * (p["life"] / p["max_life"]))
        s = pygame_module.Surface((p["size"], p["size"]), pygame_module.SRCALPHA)
        c = p["color"]
        pygame_module.draw.circle(s, (c[0], c[1], c[2], alpha),
                                  (p["size"] // 2, p["size"] // 2), p["size"] // 2)
        screen.blit(s, (int(p["x"]) - p["size"] // 2, int(p["y"]) - p["size"] // 2))


def draw_bomb_indicator_on_ball(screen, pygame_module, ball_rect):
    """공에 폭탄이 실린 상태 표시 (공 위에 작은 폭탄 아이콘)."""
    if not bomb_loaded_on_ball:
        return
    bcx, bcy = ball_rect.centerx, ball_rect.top - 6
    # 작은 검은 원 + 불꽃
    pygame_module.draw.circle(screen, (25, 25, 30), (bcx, bcy), 5)
    pygame_module.draw.circle(screen, (255, 200, 50), (bcx + 1, bcy - 6), 3)
    pygame_module.draw.circle(screen, (255, 120, 0), (bcx + 1, bcy - 7), 2)
    pygame_module.draw.line(screen, (80, 80, 80), (bcx, bcy - 5), (bcx + 1, bcy - 4), 1)


def draw_bomb_spin(screen, pygame_module, player_cx, player_cy, phase_timer=0):
    """폭탄돌리기 스킬 이펙트 그리기."""
    if not bomb_spin_active:
        return

    hx, hy = bomb_spin_helmet_x, bomb_spin_helmet_y
    r = BOMB_SPIN_HELMET_R

    # 회전 중 모션 블러/궤적
    if bomb_spin_phase in (1, 2):
        # 궤적 잔상
        trail_alpha = 110
        for i in range(3):
            trail_angle = bomb_spin_angle - (i + 1) * 0.5
            orbit_r = 22 if bomb_spin_phase == 1 else 24
            tx = player_cx + int(math.sin(trail_angle) * orbit_r)
            ty = player_cy - 30 + int(-math.cos(trail_angle) * orbit_r * 0.5)
            if bomb_spin_phase == 2:
                tx += int(bomb_spin_direction * 15)
            a = max(28, trail_alpha - i * 28)
            _draw_bomb_spin_helmet(screen, pygame_module, tx, ty, r, trail_angle, alpha=a, draw_flame=False)

    current_angle = bomb_spin_angle if bomb_spin_phase in (1, 2) else 0.0
    _draw_bomb_spin_helmet(screen, pygame_module, hx, hy, r, current_angle, alpha=255, draw_flame=True)

    # 대시 중 스피드 라인
    if bomb_spin_phase == 2:
        for i in range(5):
            ly = hy - 8 + i * 4
            lx_start = hx - bomb_spin_direction * 20 - i * 3
            lx_end = lx_start - bomb_spin_direction * (12 + i * 2)
            line_surf = pygame_module.Surface((abs(lx_end - lx_start) + 2, 2), pygame_module.SRCALPHA)
            pygame_module.draw.line(line_surf, (255, 200, 100, 120 - i * 20),
                                   (0, 0), (abs(lx_end - lx_start), 0), 1)
            screen.blit(line_surf, (min(lx_start, lx_end), ly))

    # 테두리
    if bomb_spin_phase in (1, 2):
        glow = pygame_module.Surface((r * 3, r * 3), pygame_module.SRCALPHA)
        pygame_module.draw.circle(glow, (255, 120, 0, 40), (r * 3 // 2, r * 3 // 2), r + 4)
        screen.blit(glow, (hx - r * 3 // 2, hy - r * 3 // 2))


def _draw_bomb_spin_helmet(screen, pygame_module, cx, cy, radius, spin_angle, alpha=255, draw_flame=True):
    """회전 중 x축 뒤집힘이 보이는 투구를 그린다."""
    draw = pygame_module.draw
    surf_size = radius * 4
    surf = pygame_module.Surface((surf_size, surf_size), pygame_module.SRCALPHA)
    local_cx = surf_size // 2
    local_cy = surf_size // 2

    flip_strength = abs(math.cos(spin_angle * 1.7))
    shell_h = max(8, int(radius * 2 * (0.45 + flip_strength * 0.55)))
    shell_rect = pygame_module.Rect(local_cx - radius, local_cy - shell_h // 2, radius * 2, shell_h)

    draw.ellipse(surf, (25, 25, 30, alpha), shell_rect)

    highlight_w = max(8, int(radius * 1.2))
    highlight_h = max(4, int(shell_h * 0.55))
    highlight_rect = pygame_module.Rect(
        local_cx - highlight_w // 2 - 2,
        local_cy - highlight_h // 2 - 3,
        highlight_w,
        highlight_h,
    )
    draw.ellipse(surf, (40, 40, 45, min(alpha, 160)), highlight_rect)

    if shell_h >= radius + 8:
        visor_rect = pygame_module.Rect(local_cx - radius // 2, local_cy - 1, radius, max(2, shell_h // 5))
        draw.ellipse(surf, (60, 60, 68, min(alpha, 140)), visor_rect)

    if draw_flame:
        fuse_base = (local_cx, shell_rect.top + 3)
        fuse_tip = (local_cx + 3, shell_rect.top - 7 + int(math.sin(spin_angle * 2.5) * 2))
        draw.line(surf, (90, 80, 70, alpha), fuse_base, fuse_tip, 2)
        wobble = math.sin(spin_angle * 3.1) * 2
        for cr, cg, cb, fr in [(255, 220, 80, 4), (255, 140, 0, 3), (255, 80, 0, 2)]:
            draw.circle(
                surf,
                (cr, cg, cb, min(alpha, 230)),
                (int(fuse_tip[0] + wobble), int(fuse_tip[1] - (4 - fr) + wobble * 0.5)),
                fr,
            )

    draw.ellipse(surf, (18, 18, 22, alpha), shell_rect, 1)
    screen.blit(surf, (cx - local_cx, cy - local_cy))


def reset_bomb_spin():
    """스킬 상태 리셋."""
    global bomb_spin_active, bomb_spin_timer, bomb_spin_phase
    global bomb_spin_angle, bomb_spin_cooldown
    global bomb_spin_direction, bomb_spin_helmet_x, bomb_spin_helmet_y
    global bomb_loaded_on_ball, bomb_explosion_active, bomb_explosion_timer
    global bomb_explosion_particles
    bomb_spin_active = False
    bomb_spin_timer = 0
    bomb_spin_phase = 0
    bomb_spin_angle = 0.0
    bomb_spin_cooldown = 0
    bomb_spin_direction = 0
    bomb_loaded_on_ball = False
    bomb_explosion_active = False
    bomb_explosion_timer = 0
    bomb_explosion_particles = []
    bomb_spin_helmet_x = 0
    bomb_spin_helmet_y = 0
