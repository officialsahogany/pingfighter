"""
멀티플레이어 모드 - 스매셔 스킬 시스템 포함
캐릭터 선택, 게이지, 콤보, 스킬(쇼트/드라이브/파워스매싱) 구현
"""

import pygame
import random
import math

# ============================================================================
# 멀티플레이어 스킬 상수
# ============================================================================
MP_GAUGE_MAX = 500
MP_GAUGE_HIT_CHARGE = 30
MP_SHOT_GAUGE_COST = 100
MP_SHOT_SPEED_MULTIPLIER = 1.3
MP_POWER_SMASH_GAUGE_COST = 350
MP_POWER_SMASH_SPEED_MULT = 1.5
MP_DRIVE_CURVE_STRENGTH = 0.4
MP_DRIVE_SPEED_BOOST = 1.2
MP_COMBO_GAUGE_BONUS = {2: 0.2, 3: 0.4, 4: 0.6, 5: 0.8}
MP_COMBO_MAX_BONUS = 1.0  # 6콤보 이상: 100% 보너스

# P2 키 바인딩 (WASD + Space)
P2_KEY_UP = pygame.K_w
P2_KEY_DOWN = pygame.K_s
P2_KEY_LEFT = pygame.K_a
P2_KEY_RIGHT = pygame.K_d
P2_KEY_DASH = pygame.K_SPACE

# P1 키 바인딩 (방향키 + Shift)
P1_KEY_UP = pygame.K_UP
P1_KEY_DOWN = pygame.K_DOWN
P1_KEY_LEFT = pygame.K_LEFT
P1_KEY_RIGHT = pygame.K_RIGHT
P1_KEY_DASH = pygame.K_RSHIFT


def create_mp_player(is_top, player_num, width, height):
    """멀티플레이어용 플레이어 데이터 생성"""
    y_pos = 60 if is_top else height - 80
    return {
        "num": player_num,
        "is_top": is_top,
        "x": width // 2 - 50,
        "y": y_pos,
        "width": 100,
        "height": 20,
        "speed": 8,
        "character": "smasher",
        "gauge": 0,
        "gauge_max": MP_GAUGE_MAX,
        "combo": 0,
        "combo_timer": 0,
        "combo_display_timer": 0,
        "dash_cooldown": 0,
        "dash_active": False,
        "short_shot_active": False,
        "short_shot_timer": 0,
        "power_smash_active": False,
        "power_smash_timer": 0,
        "drive_active": False,
        "drive_direction": 0,
        "cleanse_cooldown": 0,
        "status_effects": [],
        "walking_timer": 0,
        "hit_pose_timer": 0,
        "facing_left": False,
        "knockback_x": 0,
        "knockback_timer": 0,
    }


def draw_mp_smasher_sprite(screen, player, step_phase, create_smasher_func):
    """멀티플레이어 스매셔 스프라이트 그리기"""
    try:
        is_left = player["facing_left"]
        is_hit = player["hit_pose_timer"] > 0
        walk_frame = int(step_phase * 4) % 4 if player["walking_timer"] > 0 else 0

        paddle_surf = create_smasher_func(
            player["width"],
            player["height"],
            is_left_pose=is_left,
            is_hit_pose=is_hit,
            walk_frame=walk_frame
        )

        if player["is_top"]:
            paddle_surf = pygame.transform.rotate(paddle_surf, 180)

        draw_x = player["x"] + player["knockback_x"]
        draw_y = player["y"]

        sprite_rect = paddle_surf.get_rect()
        sprite_rect.centerx = draw_x + player["width"] // 2
        sprite_rect.centery = draw_y + player["height"] // 2

        screen.blit(paddle_surf, sprite_rect)

    except Exception:
        color = (0, 150, 255) if player["num"] == 1 else (255, 100, 100)
        pygame.draw.rect(screen, color,
                        (player["x"], player["y"], player["width"], player["height"]),
                        border_radius=5)


def draw_mp_gauge(screen, player, width, height, get_font_func):
    """멀티플레이어 게이지 바 그리기"""
    gauge_width = 150
    gauge_height = 12
    border = 2

    if player["is_top"]:
        gauge_x = width - gauge_width - 20
        gauge_y = 20
    else:
        gauge_x = width - gauge_width - 20
        gauge_y = height - gauge_height - 20

    pygame.draw.rect(screen, (40, 40, 50),
                    (gauge_x - border, gauge_y - border,
                     gauge_width + border * 2, gauge_height + border * 2),
                    border_radius=3)

    fill_ratio = player["gauge"] / player["gauge_max"]
    fill_width = int(gauge_width * fill_ratio)

    if fill_ratio >= 0.7:
        gauge_color = (100, 255, 100)
    elif fill_ratio >= 0.35:
        gauge_color = (255, 200, 50)
    else:
        gauge_color = (200, 100, 100)

    if fill_width > 0:
        pygame.draw.rect(screen, gauge_color,
                        (gauge_x, gauge_y, fill_width, gauge_height),
                        border_radius=2)

    shot_pos = int(gauge_width * (MP_SHOT_GAUGE_COST / MP_GAUGE_MAX))
    smash_pos = int(gauge_width * (MP_POWER_SMASH_GAUGE_COST / MP_GAUGE_MAX))

    pygame.draw.line(screen, (150, 150, 150),
                    (gauge_x + shot_pos, gauge_y - 2),
                    (gauge_x + shot_pos, gauge_y + gauge_height + 2), 1)
    pygame.draw.line(screen, (255, 100, 100),
                    (gauge_x + smash_pos, gauge_y - 2),
                    (gauge_x + smash_pos, gauge_y + gauge_height + 2), 1)

    try:
        label_font = get_font_func(14)
    except:
        label_font = pygame.font.Font(None, 14)

    label = f"P{player['num']}"
    label_surf = label_font.render(label, True, (200, 200, 200))
    label_x = gauge_x - label_surf.get_width() - 8
    label_y = gauge_y + (gauge_height - label_surf.get_height()) // 2
    screen.blit(label_surf, (label_x, label_y))


def draw_mp_combo_effect(screen, player, width, height, get_font_func):
    """콤보 이펙트 표시"""
    if player["combo_display_timer"] <= 0 or player["combo"] < 2:
        return

    combo = player["combo"]

    if player["is_top"]:
        x, y = width - 100, 50
    else:
        x, y = width - 100, height - 60

    if combo >= 6:
        color = (255, 50, 50)
    elif combo >= 4:
        color = (255, 150, 50)
    else:
        color = (255, 255, 100)

    scale = 1.0 + (player["combo_display_timer"] / 60) * 0.3

    try:
        combo_font = get_font_func(int(24 * scale))
    except:
        combo_font = pygame.font.Font(None, int(24 * scale))

    combo_text = combo_font.render(f"{combo} COMBO!", True, color)
    text_rect = combo_text.get_rect(center=(x, y))
    screen.blit(combo_text, text_rect)


def show_character_select(screen, width, height, get_font_func, play_sound_func, create_smasher_func):
    """멀티플레이어 캐릭터 선택 화면"""
    clock = pygame.time.Clock()

    characters = [
        {"id": "smasher", "name": "스매셔", "available": True, "color": (0, 150, 255)},
        {"id": "commando", "name": "코만도", "available": False, "color": (100, 100, 100)},
        {"id": "baltor", "name": "발토르", "available": False, "color": (100, 100, 100)},
        {"id": "optimus", "name": "옵티머스", "available": False, "color": (100, 100, 100)},
    ]

    current_player = 1
    p1_selection = None
    p2_selection = None
    hover_index = 0
    p1_is_top = random.choice([True, False])

    while True:
        clock.tick(60)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return None
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return None
                elif event.key == pygame.K_LEFT:
                    hover_index = (hover_index - 1) % len(characters)
                    try:
                        play_sound_func()
                    except:
                        pass
                elif event.key == pygame.K_RIGHT:
                    hover_index = (hover_index + 1) % len(characters)
                    try:
                        play_sound_func()
                    except:
                        pass
                elif event.key in (pygame.K_RETURN, pygame.K_SPACE):
                    if characters[hover_index]["available"]:
                        if current_player == 1:
                            p1_selection = characters[hover_index]["id"]
                            current_player = 2
                            try:
                                play_sound_func()
                            except:
                                pass
                        else:
                            p2_selection = characters[hover_index]["id"]
                            try:
                                play_sound_func()
                            except:
                                pass
                            return ((p1_selection, p1_is_top), (p2_selection, not p1_is_top))

            if event.type == pygame.MOUSEBUTTONDOWN:
                mx, my = pygame.mouse.get_pos()
                card_width = 140
                card_height = 180
                start_x = (width - (len(characters) * (card_width + 20) - 20)) // 2
                card_y = height // 2 - card_height // 2

                for idx, char in enumerate(characters):
                    card_x = start_x + idx * (card_width + 20)
                    card_rect = pygame.Rect(card_x, card_y, card_width, card_height)
                    if card_rect.collidepoint(mx, my) and char["available"]:
                        if current_player == 1:
                            p1_selection = char["id"]
                            current_player = 2
                            try:
                                play_sound_func()
                            except:
                                pass
                        else:
                            p2_selection = char["id"]
                            try:
                                play_sound_func()
                            except:
                                pass
                            return ((p1_selection, p1_is_top), (p2_selection, not p1_is_top))

        mx, my = pygame.mouse.get_pos()
        card_width = 140
        card_height = 180
        start_x = (width - (len(characters) * (card_width + 20) - 20)) // 2
        card_y = height // 2 - card_height // 2

        for idx, char in enumerate(characters):
            card_x = start_x + idx * (card_width + 20)
            card_rect = pygame.Rect(card_x, card_y, card_width, card_height)
            if card_rect.collidepoint(mx, my):
                hover_index = idx

        screen.fill((20, 25, 40))

        try:
            title_font = get_font_func(48)
            sub_font = get_font_func(24)
            card_font = get_font_func(20)
            hint_font = get_font_func(16)
        except:
            title_font = pygame.font.Font(None, 48)
            sub_font = pygame.font.Font(None, 24)
            card_font = pygame.font.Font(None, 20)
            hint_font = pygame.font.Font(None, 16)

        title = f"P{current_player} 캐릭터 선택"
        title_color = (0, 150, 255) if current_player == 1 else (255, 100, 100)
        title_surf = title_font.render(title, True, title_color)
        screen.blit(title_surf, (width // 2 - title_surf.get_width() // 2, 60))

        if current_player == 1:
            pos_text = "상단" if p1_is_top else "하단"
        else:
            pos_text = "하단" if p1_is_top else "상단"
        pos_surf = sub_font.render(f"위치: {pos_text}", True, (180, 180, 180))
        screen.blit(pos_surf, (width // 2 - pos_surf.get_width() // 2, 120))

        for idx, char in enumerate(characters):
            card_x = start_x + idx * (card_width + 20)
            is_hover = idx == hover_index
            is_available = char["available"]

            if is_hover and is_available:
                bg_color = (60, 70, 90)
                border_color = title_color
                border_w = 3
            elif is_available:
                bg_color = (40, 45, 60)
                border_color = (80, 90, 110)
                border_w = 2
            else:
                bg_color = (30, 30, 40)
                border_color = (50, 50, 60)
                border_w = 1

            pygame.draw.rect(screen, bg_color, (card_x, card_y, card_width, card_height), border_radius=10)
            pygame.draw.rect(screen, border_color, (card_x, card_y, card_width, card_height), border_w, border_radius=10)

            name_color = char["color"] if is_available else (80, 80, 80)
            name_surf = card_font.render(char["name"], True, name_color)
            name_x = card_x + (card_width - name_surf.get_width()) // 2
            screen.blit(name_surf, (name_x, card_y + card_height - 40))

            if not is_available:
                soon_surf = hint_font.render("Coming Soon", True, (100, 100, 100))
                soon_x = card_x + (card_width - soon_surf.get_width()) // 2
                screen.blit(soon_surf, (soon_x, card_y + card_height - 20))

            if char["id"] == "smasher" and is_available:
                try:
                    preview_surf = create_smasher_func(60, 12, False, False, 0)
                    preview_x = card_x + (card_width - 60) // 2
                    preview_y = card_y + 60
                    screen.blit(preview_surf, (preview_x, preview_y))
                except:
                    pygame.draw.rect(screen, (0, 150, 255), (card_x + 40, card_y + 60, 60, 12), border_radius=3)

        if p1_selection:
            p1_info = f"P1: {p1_selection} ({'상단' if p1_is_top else '하단'})"
            p1_surf = sub_font.render(p1_info, True, (0, 150, 255))
            screen.blit(p1_surf, (20, height - 60))

        hint1 = hint_font.render("← → 선택, Enter 확정, ESC 취소", True, (120, 120, 120))
        screen.blit(hint1, (width // 2 - hint1.get_width() // 2, height - 40))

        pygame.display.flip()

    return None


def run_multiplayer_game(screen, width, height, get_font_func, play_sound_funcs,
                         create_smasher_func, bgm_manager):
    """멀티플레이어 게임 실행

    Args:
        screen: pygame 화면
        width, height: 화면 크기
        get_font_func: 폰트 가져오기 함수
        play_sound_funcs: dict {"click": func, "hit": func, "wall": func, "score": func, "short_shot": func}
        create_smasher_func: 스매셔 스프라이트 생성 함수
        bgm_manager: BGM 관리자
    """
    # 캐릭터 선택
    selection = show_character_select(
        screen, width, height, get_font_func,
        play_sound_funcs.get("click", lambda: None),
        create_smasher_func
    )

    if selection is None:
        return False

    (p1_char, p1_is_top), (p2_char, p2_is_top) = selection

    clock = pygame.time.Clock()

    p1_score = 0
    p2_score = 0
    win_score = 5

    p1 = create_mp_player(p1_is_top, 1, width, height)
    p2 = create_mp_player(p2_is_top, 2, width, height)

    top_player = p1 if p1_is_top else p2
    bottom_player = p2 if p1_is_top else p1

    ball_radius = 10
    ball_x = float(width // 2)
    ball_y = float(height // 2)
    ball_speed_x = 5.0
    ball_speed_y = 5.0 * (1 if random.random() > 0.5 else -1)
    ball_base_speed = 5.0
    ball_max_speed = 18.0
    ball_curve_x = 0.0

    ball_short_shot = False
    ball_power_smash = False
    ball_last_hitter = None

    round_start_delay = 60
    round_timer = round_start_delay
    game_paused = True

    hit_effects = []
    screen_shake = 0
    screen_shake_x = 0
    screen_shake_y = 0

    walk_animation_timer = 0.0

    try:
        bgm_manager.play_stage_bgm(1)
    except:
        pass

    def reset_ball(scorer_is_top):
        nonlocal ball_x, ball_y, ball_speed_x, ball_speed_y
        nonlocal ball_curve_x, ball_short_shot, ball_power_smash
        ball_x = float(width // 2)
        ball_y = float(height // 2)
        ball_speed_x = ball_base_speed * (1 if random.random() > 0.5 else -1)
        ball_speed_y = ball_base_speed * (1 if scorer_is_top else -1)
        ball_curve_x = 0.0
        ball_short_shot = False
        ball_power_smash = False

    def apply_skill_on_hit(player, keys, is_p1):
        nonlocal ball_speed_x, ball_speed_y, ball_curve_x
        nonlocal ball_short_shot, ball_power_smash, hit_effects, screen_shake

        speed_mult = 1.0
        applied_curve = 0.0
        is_short = False
        is_power = False

        if is_p1:
            key_up, key_down = P1_KEY_UP, P1_KEY_DOWN
            key_left, key_right = P1_KEY_LEFT, P1_KEY_RIGHT
        else:
            key_up, key_down = P2_KEY_UP, P2_KEY_DOWN
            key_left, key_right = P2_KEY_LEFT, P2_KEY_RIGHT

        if keys[key_down] and player["gauge"] >= MP_POWER_SMASH_GAUGE_COST:
            player["gauge"] -= MP_POWER_SMASH_GAUGE_COST
            speed_mult = MP_POWER_SMASH_SPEED_MULT
            is_power = True
            ball_power_smash = True
            player["power_smash_active"] = True
            player["power_smash_timer"] = 30
            screen_shake = 15
            hit_effects.append((player["x"] + player["width"]//2, player["y"], 45, (255, 100, 50), "POWER SMASH!"))
            try:
                play_sound_funcs.get("short_shot", lambda: None)()
            except:
                pass
        elif keys[key_up] and player["gauge"] >= MP_SHOT_GAUGE_COST:
            player["gauge"] -= MP_SHOT_GAUGE_COST
            speed_mult = MP_SHOT_SPEED_MULTIPLIER
            is_short = True
            ball_short_shot = True
            player["short_shot_active"] = True
            player["short_shot_timer"] = 30
            hit_effects.append((player["x"] + player["width"]//2, player["y"], 30, (100, 200, 255), "SHORT!"))
            try:
                play_sound_funcs.get("short_shot", lambda: None)()
            except:
                pass
        elif keys[key_left]:
            applied_curve = -MP_DRIVE_CURVE_STRENGTH
            speed_mult = MP_DRIVE_SPEED_BOOST
            player["drive_active"] = True
            player["drive_direction"] = -1
            hit_effects.append((player["x"] + player["width"]//2, player["y"], 20, (255, 255, 100), "DRIVE!"))
        elif keys[key_right]:
            applied_curve = MP_DRIVE_CURVE_STRENGTH
            speed_mult = MP_DRIVE_SPEED_BOOST
            player["drive_active"] = True
            player["drive_direction"] = 1
            hit_effects.append((player["x"] + player["width"]//2, player["y"], 20, (255, 255, 100), "DRIVE!"))

        ball_curve_x = applied_curve
        return speed_mult, applied_curve, is_short, is_power

    def charge_gauge(player):
        base_charge = MP_GAUGE_HIT_CHARGE
        combo = player["combo"]
        if combo >= 6:
            bonus = MP_COMBO_MAX_BONUS
        else:
            bonus = MP_COMBO_GAUGE_BONUS.get(combo, 0)
        total_charge = int(base_charge * (1 + bonus))
        player["gauge"] = min(player["gauge"] + total_charge, player["gauge_max"])

    def update_player_timers(player):
        if player["combo_timer"] > 0:
            player["combo_timer"] -= 1
            if player["combo_timer"] <= 0:
                player["combo"] = 0
        if player["combo_display_timer"] > 0:
            player["combo_display_timer"] -= 1
        if player["hit_pose_timer"] > 0:
            player["hit_pose_timer"] -= 1
        if player["walking_timer"] > 0:
            player["walking_timer"] -= 1
        if player["dash_cooldown"] > 0:
            player["dash_cooldown"] -= 1
        if player["short_shot_timer"] > 0:
            player["short_shot_timer"] -= 1
            if player["short_shot_timer"] <= 0:
                player["short_shot_active"] = False
        if player["power_smash_timer"] > 0:
            player["power_smash_timer"] -= 1
            if player["power_smash_timer"] <= 0:
                player["power_smash_active"] = False
        if player["knockback_timer"] > 0:
            player["knockback_timer"] -= 1
            player["knockback_x"] *= 0.85
            if player["knockback_timer"] <= 0:
                player["knockback_x"] = 0

    def apply_knockback(player, direction, strength=15):
        player["knockback_x"] = direction * strength
        player["knockback_timer"] = 10

    def show_result(winner, p1_sc, p2_sc):
        result_clock = pygame.time.Clock()
        animation_timer = 0
        while True:
            dt = result_clock.tick(60) / 1000.0
            animation_timer += dt
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return
                if event.type == pygame.KEYDOWN:
                    if event.key in (pygame.K_RETURN, pygame.K_SPACE, pygame.K_ESCAPE):
                        return
                if event.type == pygame.MOUSEBUTTONDOWN:
                    return

            screen.fill((15, 20, 30))
            try:
                title_font = get_font_func(64)
                score_font = get_font_func(36)
                hint_font = get_font_func(24)
            except:
                title_font = pygame.font.Font(None, 64)
                score_font = pygame.font.Font(None, 36)
                hint_font = pygame.font.Font(None, 24)

            winner_color = (0, 150, 255) if winner == "P1" else (255, 100, 100)
            title_text = title_font.render(f"{winner} 승리!", True, winner_color)
            title_rect = title_text.get_rect(center=(width // 2, height // 2 - 80))
            screen.blit(title_text, title_rect)

            score_text = score_font.render(f"P1: {p1_sc}  -  P2: {p2_sc}", True, (200, 200, 200))
            score_rect = score_text.get_rect(center=(width // 2, height // 2))
            screen.blit(score_text, score_rect)

            hint_text = hint_font.render("아무 키나 눌러 메뉴로 돌아가기", True, (150, 150, 150))
            hint_rect = hint_text.get_rect(center=(width // 2, height // 2 + 80))
            screen.blit(hint_text, hint_rect)

            pygame.display.flip()

    running = True
    while running:
        dt = clock.tick(60)
        walk_animation_timer += dt / 1000.0

        if screen_shake > 0:
            screen_shake -= 1
            screen_shake_x = random.randint(-3, 3)
            screen_shake_y = random.randint(-3, 3)
        else:
            screen_shake_x = 0
            screen_shake_y = 0

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return False
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    try:
                        bgm_manager.play_menu_bgm()
                    except:
                        pass
                    return True

        if game_paused:
            round_timer -= 1
            if round_timer <= 0:
                game_paused = False

        keys = pygame.key.get_pressed()

        if not game_paused:
            # P1 이동
            p1_moving = False
            p1_move_speed = p1["speed"]
            if p1["dash_cooldown"] <= 0 and keys[P1_KEY_DASH]:
                p1_move_speed += 3
                p1["dash_cooldown"] = 30
            if keys[P1_KEY_LEFT]:
                p1["x"] -= p1_move_speed
                p1["facing_left"] = True
                p1_moving = True
            if keys[P1_KEY_RIGHT]:
                p1["x"] += p1_move_speed
                p1["facing_left"] = False
                p1_moving = True
            if p1_moving:
                p1["walking_timer"] = 10
            p1["x"] = max(0, min(width - p1["width"], p1["x"]))

            # P2 이동
            p2_moving = False
            p2_move_speed = p2["speed"]
            if p2["dash_cooldown"] <= 0 and keys[P2_KEY_DASH]:
                p2_move_speed += 3
                p2["dash_cooldown"] = 30
            if keys[P2_KEY_LEFT]:
                p2["x"] -= p2_move_speed
                p2["facing_left"] = True
                p2_moving = True
            if keys[P2_KEY_RIGHT]:
                p2["x"] += p2_move_speed
                p2["facing_left"] = False
                p2_moving = True
            if p2_moving:
                p2["walking_timer"] = 10
            p2["x"] = max(0, min(width - p2["width"], p2["x"]))

            update_player_timers(p1)
            update_player_timers(p2)

            ball_x += ball_speed_x
            ball_y += ball_speed_y

            if ball_curve_x != 0:
                ball_speed_x += ball_curve_x * 0.5
                ball_curve_x *= 0.98
                if abs(ball_curve_x) < 0.01:
                    ball_curve_x = 0

            if ball_x - ball_radius <= 0:
                ball_x = ball_radius
                ball_speed_x = abs(ball_speed_x)
                try:
                    play_sound_funcs.get("wall", lambda: None)()
                except:
                    pass
            elif ball_x + ball_radius >= width:
                ball_x = width - ball_radius
                ball_speed_x = -abs(ball_speed_x)
                try:
                    play_sound_funcs.get("wall", lambda: None)()
                except:
                    pass

            # 하단 플레이어 충돌
            bp = bottom_player
            if (ball_y + ball_radius >= bp["y"] and
                ball_y - ball_radius <= bp["y"] + bp["height"] and
                ball_x >= bp["x"] and ball_x <= bp["x"] + bp["width"] and
                ball_speed_y > 0):
                ball_speed_y = -abs(ball_speed_y)
                hit_pos = (ball_x - bp["x"]) / bp["width"]
                ball_speed_x = (hit_pos - 0.5) * 10
                is_p1 = (bp["num"] == 1)
                speed_mult, curve, is_short, is_power = apply_skill_on_hit(bp, keys, is_p1)
                ball_speed_x *= speed_mult
                ball_speed_y *= speed_mult
                speed = math.sqrt(ball_speed_x**2 + ball_speed_y**2)
                if speed > ball_max_speed:
                    factor = ball_max_speed / speed
                    ball_speed_x *= factor
                    ball_speed_y *= factor
                bp["combo"] += 1
                bp["combo_timer"] = 180
                bp["combo_display_timer"] = 60
                charge_gauge(bp)
                bp["hit_pose_timer"] = 15
                ball_last_hitter = bp
                top_player["combo"] = 0
                if is_power and ball_power_smash:
                    direction = 1 if ball_x > top_player["x"] + top_player["width"]//2 else -1
                    apply_knockback(top_player, direction, 20)
                try:
                    play_sound_funcs.get("hit", lambda: None)()
                except:
                    pass

            # 상단 플레이어 충돌
            tp = top_player
            if (ball_y - ball_radius <= tp["y"] + tp["height"] and
                ball_y + ball_radius >= tp["y"] and
                ball_x >= tp["x"] and ball_x <= tp["x"] + tp["width"] and
                ball_speed_y < 0):
                ball_speed_y = abs(ball_speed_y)
                hit_pos = (ball_x - tp["x"]) / tp["width"]
                ball_speed_x = (hit_pos - 0.5) * 10
                is_p1 = (tp["num"] == 1)
                speed_mult, curve, is_short, is_power = apply_skill_on_hit(tp, keys, is_p1)
                ball_speed_x *= speed_mult
                ball_speed_y *= speed_mult
                speed = math.sqrt(ball_speed_x**2 + ball_speed_y**2)
                if speed > ball_max_speed:
                    factor = ball_max_speed / speed
                    ball_speed_x *= factor
                    ball_speed_y *= factor
                tp["combo"] += 1
                tp["combo_timer"] = 180
                tp["combo_display_timer"] = 60
                charge_gauge(tp)
                tp["hit_pose_timer"] = 15
                ball_last_hitter = tp
                bottom_player["combo"] = 0
                if is_power and ball_power_smash:
                    direction = 1 if ball_x > bottom_player["x"] + bottom_player["width"]//2 else -1
                    apply_knockback(bottom_player, direction, 20)
                try:
                    play_sound_funcs.get("hit", lambda: None)()
                except:
                    pass

            # 득점 체크
            scored = False
            scorer_is_top = False
            if ball_y - ball_radius <= 0:
                if bottom_player["num"] == 1:
                    p1_score += 1
                else:
                    p2_score += 1
                scored = True
                scorer_is_top = False
                try:
                    play_sound_funcs.get("score", lambda: None)()
                except:
                    pass
            elif ball_y + ball_radius >= height:
                if top_player["num"] == 1:
                    p1_score += 1
                else:
                    p2_score += 1
                scored = True
                scorer_is_top = True
                try:
                    play_sound_funcs.get("score", lambda: None)()
                except:
                    pass

            if scored:
                reset_ball(scorer_is_top)
                game_paused = True
                round_timer = round_start_delay
                p1["combo"] = 0
                p2["combo"] = 0
                if p1_score >= win_score or p2_score >= win_score:
                    winner = "P1" if p1_score >= win_score else "P2"
                    show_result(winner, p1_score, p2_score)
                    try:
                        bgm_manager.play_menu_bgm()
                    except:
                        pass
                    return True

        # 이펙트 업데이트
        new_effects = []
        for eff in hit_effects:
            x, y, timer, color, text = eff
            if timer > 0:
                new_effects.append((x, y - 1, timer - 1, color, text))
        hit_effects = new_effects

        # 렌더링
        screen.fill((20, 25, 35))
        offset_x, offset_y = screen_shake_x, screen_shake_y

        pygame.draw.line(screen, (60, 70, 90),
                        (offset_x, height // 2 + offset_y),
                        (width + offset_x, height // 2 + offset_y), 2)
        for i in range(0, width, 30):
            pygame.draw.circle(screen, (80, 90, 110), (i + offset_x, height // 2 + offset_y), 3)

        draw_mp_smasher_sprite(screen, p1, walk_animation_timer, create_smasher_func)
        draw_mp_smasher_sprite(screen, p2, walk_animation_timer, create_smasher_func)

        ball_draw_x = int(ball_x) + offset_x
        ball_draw_y = int(ball_y) + offset_y
        if ball_short_shot:
            pygame.draw.circle(screen, (100, 200, 255), (ball_draw_x, ball_draw_y), ball_radius + 4, 2)
        if ball_power_smash:
            pygame.draw.circle(screen, (255, 100, 50), (ball_draw_x, ball_draw_y), ball_radius + 6, 3)
        pygame.draw.circle(screen, (255, 255, 255), (ball_draw_x, ball_draw_y), ball_radius)
        pygame.draw.circle(screen, (200, 200, 200), (ball_draw_x, ball_draw_y), ball_radius, 2)

        draw_mp_gauge(screen, p1, width, height, get_font_func)
        draw_mp_gauge(screen, p2, width, height, get_font_func)
        draw_mp_combo_effect(screen, p1, width, height, get_font_func)
        draw_mp_combo_effect(screen, p2, width, height, get_font_func)

        try:
            effect_font = get_font_func(20)
        except:
            effect_font = pygame.font.Font(None, 20)
        for eff in hit_effects:
            x, y, timer, color, text = eff
            eff_surf = effect_font.render(text, True, color)
            screen.blit(eff_surf, (x - eff_surf.get_width()//2, y))

        try:
            score_font = get_font_func(36)
        except:
            score_font = pygame.font.Font(None, 36)
        p1c, p2c = (0, 150, 255), (255, 100, 100)
        tp_label = "P1" if top_player["num"] == 1 else "P2"
        tp_clr = p1c if top_player["num"] == 1 else p2c
        tp_scr = p1_score if top_player["num"] == 1 else p2_score
        tp_text = score_font.render(f"{tp_label}: {tp_scr}", True, tp_clr)
        screen.blit(tp_text, (20, 15))
        bp_label = "P1" if bottom_player["num"] == 1 else "P2"
        bp_clr = p1c if bottom_player["num"] == 1 else p2c
        bp_scr = p1_score if bottom_player["num"] == 1 else p2_score
        bp_text = score_font.render(f"{bp_label}: {bp_scr}", True, bp_clr)
        screen.blit(bp_text, (20, height - 40))

        if game_paused and round_timer > 0:
            countdown = (round_timer // 20) + 1
            try:
                countdown_font = get_font_func(72)
            except:
                countdown_font = pygame.font.Font(None, 72)
            countdown_text = countdown_font.render(str(countdown), True, (255, 255, 0))
            screen.blit(countdown_text, (width//2 - countdown_text.get_width()//2, height//2 - countdown_text.get_height()//2))

        try:
            help_font = get_font_func(14)
        except:
            help_font = pygame.font.Font(None, 14)
        if top_player["num"] == 1:
            top_help = "P1: ←→ | ↑+히트:쇼트 | ↓+히트:파워스매싱 | ←→+히트:드라이브"
        else:
            top_help = "P2: A/D | W+히트:쇼트 | S+히트:파워스매싱 | A/D+히트:드라이브"
        top_help_surf = help_font.render(top_help, True, (120, 120, 120))
        screen.blit(top_help_surf, (width//2 - top_help_surf.get_width()//2, 5))
        if bottom_player["num"] == 1:
            bot_help = "P1: ←→ | ↑+히트:쇼트 | ↓+히트:파워스매싱 | ←→+히트:드라이브"
        else:
            bot_help = "P2: A/D | W+히트:쇼트 | S+히트:파워스매싱 | A/D+히트:드라이브"
        bot_help_surf = help_font.render(bot_help, True, (120, 120, 120))
        screen.blit(bot_help_surf, (width//2 - bot_help_surf.get_width()//2, height - 18))
        esc_help = help_font.render("ESC: 메뉴", True, (100, 100, 100))
        screen.blit(esc_help, (width - esc_help.get_width() - 10, height // 2 - 8))

        pygame.display.flip()

    return True
