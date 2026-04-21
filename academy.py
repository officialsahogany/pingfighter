"""
academy.py  — 호환용 최소 스텁 (Minimal Compatibility Stub)

아카데미 스킬 트리 시스템은 런타임 퍽 시스템으로 완전 대체되었다.
이 파일은 기존 호출부가 깨지지 않도록 동일한 public API를 유지하되,
모든 보너스를 0/1.0(중립값)으로 반환한다.

남아있는 역할:
  - ANGEL_ITEM_COOLDOWN_MULTIPLIER (천사 가호 전역 배율)
  - transcendent_crown_skill_bonus (전설 아이템 연동)
  - get_*() → 중립값 반환
"""

# ── 전설 아이템 연동 전역 변수 ────────────────────────────────────
transcendent_crown_skill_bonus = 0
ANGEL_ITEM_COOLDOWN_MULTIPLIER = 1.0

# ── 더미 skill_system ─────────────────────────────────────────────

class _DummySkillSystem:
    skill_points = 0
    skill_levels = {}
    total_invested_points = 0
    total_invested_points_by_tree = {}

    def get_skill_level(self, skill_id): return 0
    def get_skill_data(self, skill_id): return None
    def can_upgrade_skill(self, skill_id): return False
    def upgrade_skill(self, skill_id): return False
    def add_skill_points(self, pts): pass
    def reset_skill_points(self): pass
    def reset_all(self): pass
    def init_fresh_skills(self): pass
    def get_tree_total(self, tree_id): return 0
    def get_tree_id_for_skill(self, sid): return None
    def register_manual_investment(self, t, a): pass
    def to_save_dict(self): return {}
    def load_from_dict(self, d): return False

skill_system = _DummySkillSystem()

# 호환: academy.skill_points 접근
def __getattr__(name):
    if name == "skill_points":
        return skill_system.skill_points
    if name == "dash_quick_recovery_level":
        return 0
    raise AttributeError(f"module 'academy' has no attribute {name!r}")

# ── 발토르 대장장이 메뉴 호환 ─────────────────────────────────────
SKILL_TREES = {
    "blacksmith": {"name": "대장장이 스킬", "color": (180, 100, 220), "skills": []},
}
TREE_SUMMARIES = {"blacksmith": "발토르 전용 스킬입니다. (퇴역됨)"}

# ── get_*() 중립값 헬퍼 ───────────────────────────────────────────
def get_skill_bonus(skill_id): return 0
def get_skill_level(skill_id): return 0
def get_item_spawn_delay_multiplier(): return 1.0
def get_active_item_cooldown_multiplier(): return 1.0 * ANGEL_ITEM_COOLDOWN_MULTIPLIER
def get_active_item_gauge_bonus(): return 0
def get_item_slot_bonus(): return 0
def get_item_recycle_chance(): return 0.0
def get_caffeine_duration_multiplier(): return 1.0
def get_polish_efficiency_multiplier(): return 1.0
def get_treasure_map_field_multiplier(): return 1.0
def get_treasure_map_gacha_bonus(): return 0.0
def get_downtown_treasure_map_field_multiplier(): return 1.0
def get_downtown_treasure_map_gacha_bonus(): return 0.0
def get_downtown_gamble_settings(): return get_item_gamble_settings()
def check_all_dash_skills_mastered(): return False

def get_item_gamble_settings():
    runtime_bonus = 0.0
    try:
        from pingfighter import get_runtime_skill_bonus
        runtime_bonus = get_runtime_skill_bonus("downtown_gamble")
    except Exception:
        pass
    if runtime_bonus <= 0:
        return 0.0, 0
    return min(0.95, runtime_bonus), 1

# ── 포인트/스킬 관리 (no-op) ──────────────────────────────────────
def add_skill_points(pts): pass
def reset_skill_points(): pass
def reset_all_skills(): pass
def debug_max_dash_skills(): pass

# ── 아카데미 스킬 제안 UI ─────────────────────────────────────────
# 학장 아르카나가 미획득 액티브 스킬 중 하나를 제안한다.
#   · 슬롯 5/5: 기존 스킬과 무료 교환 (입장 시 열쇠 1개 이미 소모)
#   · 슬롯 <5/5: 1000 골드 구매 (빈 슬롯에 장착)
# 방문 1회 = 아카데미 건물 입장 1회. 같은 방문 안에서 학장을 여러 번
# 클릭해도 제안 스킬은 고정되어야 하므로, 추첨 결과는 모듈 레벨에
# 캐시하고 건물 재입장 시 manager가 reset_visit_cache()로 비운다.

_visit_pick_cache = {
    "offered_perk": None,
    "character_type": None,
    "consumed": False,
}


def reset_visit_cache():
    """새 아카데미 방문 시 호출 — 다음 show_academy_menu에서 새로 추첨."""
    global _visit_pick_cache
    _visit_pick_cache = {
        "offered_perk": None,
        "character_type": None,
        "consumed": False,
    }

def _wrap_text(text, max_chars):
    """글자 수 기준 단순 줄바꿈 (한글 섞여도 동작)."""
    if not text:
        return []
    lines = []
    current = ""
    for ch in text:
        current += ch
        if len(current) >= max_chars:
            lines.append(current)
            current = ""
    if current:
        lines.append(current)
    return lines


def _open_swap_dialog(pf, character_type, new_perk_id):
    """5/5 상태에서 기존 스킬 하나와 교체하기 위해 스왑 팝업을 연다.
    취소되면 None."""
    perk_map = pf._get_character_unlock_perks(character_type)
    new_skill_name = perk_map.get(new_perk_id)
    if not new_skill_name:
        return None
    if character_type == "smasher":
        return pf._show_smasher_skill_swap_dialog(new_skill_name)
    if character_type == "viper":
        return pf._show_viper_skill_swap_dialog(new_skill_name)
    if character_type == "soldier":
        return pf._show_soldier_skill_swap_dialog(new_skill_name)
    return None


def show_academy_menu(screen, width, height, selected_character="smasher", read_only=False):
    """학장 아르카나 스킬 제안 모달. 호출 1회 = 방문 1회."""
    import math
    import os
    import random
    import pygame
    import pygame.freetype

    try:
        import pingfighter as pf
    except Exception:
        return None

    character_type = selected_character or "smasher"

    # 5구슬 슬롯 시스템이 없는 캐릭터는 기능 비활성
    supported = character_type in ("smasher", "viper", "soldier")

    # 미획득 후보
    unowned = pf.get_academy_unowned_active_perks(character_type) if supported else []

    # 방문 캐시 우선. 캐시된 perk이 여전히 미획득 리스트 + 같은 캐릭 기준에
    # 유효하면 재사용, 아니면 새 추첨 후 캐시.
    global _visit_pick_cache
    visit_consumed = bool(_visit_pick_cache.get("consumed"))
    cached_perk = _visit_pick_cache.get("offered_perk")
    cached_char = _visit_pick_cache.get("character_type")
    if visit_consumed:
        offered_perk = None
    else:
        if (
            supported
            and cached_perk
            and cached_char == character_type
            and cached_perk in unowned
        ):
            offered_perk = cached_perk
        else:
            offered_perk = random.choice(unowned) if unowned else None
            _visit_pick_cache["offered_perk"] = offered_perk
            _visit_pick_cache["character_type"] = character_type

    slots_full = pf._are_character_skill_slots_full(character_type) if supported else False

    # 스타일
    BG_DARK = (25, 15, 45)
    BORDER_PURPLE = (180, 100, 255)
    BORDER_GLOW = (120, 60, 180)
    TEXT_WHITE = (240, 245, 255)
    TEXT_GOLD = (255, 215, 100)
    TEXT_PURPLE = (200, 150, 255)
    TEXT_DIM = (150, 150, 180)
    TEXT_DISABLED = (110, 100, 130)
    BUTTON_BG = (50, 30, 80)
    BUTTON_HOVER = (100, 60, 150)
    BUTTON_DISABLED = (45, 35, 55)

    # 폰트
    font_candidates = []
    for rel_path in (
        "NanumSquareB.ttf",
        os.path.join("fonts", "NanumSquareB.ttf"),
        os.path.join("fonts", "프리텐다드", "public", "static", "alternative", "Pretendard-Bold.ttf"),
    ):
        try:
            font_candidates.append(pf.resource_path(rel_path))
        except Exception:
            font_candidates.append(rel_path)

    def load_font(size):
        for candidate in font_candidates:
            try:
                if candidate and os.path.exists(candidate):
                    return pygame.freetype.Font(candidate, size)
            except Exception:
                continue
        try:
            return pygame.freetype.SysFont("malgungothic", size)
        except Exception:
            return None

    font_title = load_font(22)
    font_medium = load_font(15)
    font_small = load_font(12)
    font_tiny = load_font(11)

    def render_text(font, text, color):
        if font is None or not text:
            return None, None
        try:
            return font.render(text, color)
        except Exception:
            return None, None

    # 배경 스냅샷
    try:
        bg_snapshot = screen.copy()
    except Exception:
        bg_snapshot = None

    clock = pygame.time.Clock()

    dialog_w, dialog_h = 560, 480
    dialog_x = (width - dialog_w) // 2
    dialog_y = (height - dialog_h) // 2

    temp_message = ""
    temp_message_timer = 0  # ms
    success_message = ""
    success_message_timer = 0

    result = None
    running = True
    showcase_start_ticks = pygame.time.get_ticks()  # 팝인(intro) 기준

    while running:
        dt = clock.tick(60)
        mouse_pos = pygame.mouse.get_pos()

        click_pos = None
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.event.post(pygame.event.Event(pygame.QUIT))
                return None
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
            if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                click_pos = event.pos

        # 배경
        if bg_snapshot is not None:
            screen.blit(bg_snapshot, (0, 0))
        overlay = pygame.Surface((width, height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 160))
        screen.blit(overlay, (0, 0))

        # 대화창 판넬
        dialog_surf = pygame.Surface((dialog_w, dialog_h), pygame.SRCALPHA)
        pygame.draw.rect(dialog_surf, (*BG_DARK, 240), (0, 0, dialog_w, dialog_h), border_radius=10)
        screen.blit(dialog_surf, (dialog_x, dialog_y))
        pygame.draw.rect(screen, BORDER_GLOW, (dialog_x - 2, dialog_y - 2, dialog_w + 4, dialog_h + 4), 3, border_radius=12)
        pygame.draw.rect(screen, BORDER_PURPLE, (dialog_x, dialog_y, dialog_w, dialog_h), 2, border_radius=10)

        # 제목
        surf, rect = render_text(font_title, "학장 아르카나의 제안", TEXT_WHITE)
        if surf:
            screen.blit(surf, (dialog_x + dialog_w // 2 - rect.width // 2, dialog_y + 18))

        # 골드 표시
        try:
            cur_gold = int(pf.downtown_gold)
        except Exception:
            cur_gold = 0
        gold_text = f"소지 골드 : {cur_gold}G"
        surf, rect = render_text(font_small, gold_text, TEXT_GOLD)
        if surf:
            screen.blit(surf, (dialog_x + dialog_w - rect.width - 18, dialog_y + 22))

        content_y = dialog_y + 62

        if offered_perk is None:
            # 미획득 0개 or 미지원 캐릭터
            if visit_consumed and supported:
                msg_lines = [
                    "이번 방문의 가르침은 여기까지일세.",
                    "",
                    "다음에 다시 찾아오게.",
                ]
            elif not supported:
                msg_lines = [
                    "이 캐릭터에게 가르쳐줄 비기는 없네...",
                    "",
                    "다른 길을 택하시게.",
                ]
            else:
                msg_lines = [
                    "허허, 이미 모든 비기를 익혔군 그래.",
                    "",
                    "내가 더 가르칠 게 없네. 다음에 또 오시게.",
                ]
            for line in msg_lines:
                surf, rect = render_text(font_medium, line, TEXT_WHITE)
                if surf:
                    screen.blit(surf, (dialog_x + dialog_w // 2 - rect.width // 2, content_y))
                content_y += 32

            btn_w, btn_h = 140, 40
            cancel_btn = pygame.Rect(
                dialog_x + dialog_w // 2 - btn_w // 2,
                dialog_y + dialog_h - 60,
                btn_w, btn_h
            )
            hover = cancel_btn.collidepoint(mouse_pos)
            pygame.draw.rect(screen, BUTTON_HOVER if hover else BUTTON_BG, cancel_btn, border_radius=6)
            pygame.draw.rect(screen, BORDER_PURPLE, cancel_btn, 2, border_radius=6)
            surf, rect = render_text(font_medium, "돌아가기", TEXT_WHITE)
            if surf:
                screen.blit(surf, (cancel_btn.centerx - rect.width // 2, cancel_btn.centery - rect.height // 2))

            if click_pos and cancel_btn.collidepoint(click_pos):
                running = False
        else:
            # 제안 내용
            perk_name = pf.get_academy_perk_display_name(character_type, offered_perk)
            perk_desc = pf.get_academy_perk_description(character_type, offered_perk)
            perk_color = pf.get_academy_perk_icon_color(character_type, offered_perk)
            perk_map = pf._get_character_unlock_perks(character_type)
            skill_name = perk_map.get(offered_perk, offered_perk)

            if slots_full:
                npc_line = "자네 슬롯이 가득 찼군. 이걸로 하나 바꿔보지 않겠나?"
            else:
                npc_line = "이 기술 어떤가? 1000 골드면 내가 가르쳐주겠네."
            surf, rect = render_text(font_medium, npc_line, TEXT_PURPLE)
            if surf:
                screen.blit(surf, (dialog_x + dialog_w // 2 - rect.width // 2, content_y))
            content_y += 34

            # === 스킬 쇼케이스 (가산 발광 + 부유 + 꼬리 + 웨이브 룬 + 팝인) ===
            now_ticks = pygame.time.get_ticks()
            t_sec = now_ticks / 1000.0

            # [업그레이드 5] 팝인 스케일 — 모달 열린 직후 0.35초 동안 바깥으로 확장.
            elapsed = (now_ticks - showcase_start_ticks) / 1000.0
            intro = math.sin(min(1.0, max(0.0, elapsed / 0.35)) * math.pi / 2)

            # [업그레이드 2] 전체 부유 (호버링) — 쇼케이스 묶음이 위아래로 4px 진동.
            float_offset = math.sin(t_sec * 2.0) * 4.0
            cx = dialog_x + dialog_w // 2
            cy = content_y + 78 + int(float_offset)

            # [업그레이드 1 + 튜닝] 1) 외곽 소프트 오라 — 방사형 그라데이션 (30 스텝).
            # 하드한 3단 디스크 대신 중심→바깥 ease-out 감쇠로 부드러운 글로우.
            # BLEND_RGB_ADD + pre-multiplied alpha 로 투명도 유지한 채 자체발광.
            aura_pulse = 0.45 + 0.35 * math.sin(t_sec * 1.6)
            aura_max_r = int(108 * intro)
            if aura_max_r > 4:
                aura_surf = pygame.Surface(
                    (aura_max_r * 2 + 4, aura_max_r * 2 + 4), pygame.SRCALPHA
                )
                center = (aura_max_r + 2, aura_max_r + 2)
                steps = 30
                # 중심 피크 밝기 (아우라 펄스 반영). 낮게 잡아 투명도 확보.
                peak_alpha = 68 * (0.75 + 0.25 * aura_pulse)
                # 바깥(step=steps)부터 중심(step=1) 순으로 그려서 안쪽이 덮어쓰도록.
                for s in range(steps, 0, -1):
                    t = s / steps                     # 1.0(outer) → ~0(center)
                    fade = (1.0 - t) ** 2             # ease-out quadratic
                    alpha = int(peak_alpha * fade)
                    if alpha <= 0:
                        continue
                    r = max(1, int(aura_max_r * t))
                    # 가산혼합용 프리멀티플라이 — alpha 무시 문제 해결.
                    pre_color = tuple(
                        min(255, int(c * alpha / 255)) for c in perk_color[:3]
                    )
                    pygame.draw.circle(aura_surf, (*pre_color, 255), center, r)
                screen.blit(
                    aura_surf,
                    (cx - aura_max_r - 2, cy - aura_max_r - 2),
                    special_flags=pygame.BLEND_RGB_ADD,
                )

            # [업그레이드 4] 2) 회전 룬 링 — 웨이브 펄스 (각 마커가 파도타기).
            rune_r = int(62 * intro)
            rune_angle = t_sec * 0.6
            if rune_r > 0:
                for k in range(8):
                    ang = rune_angle + k * (2 * math.pi / 8)
                    rx = cx + int(math.cos(ang) * rune_r)
                    ry = cy + int(math.sin(ang) * rune_r)
                    # 순번 k 와 시간으로 0~1 변조 (파도 주기 4.0)
                    dot_pulse = (math.sin(t_sec * 4.0 - k * 0.8) + 1.0) * 0.5
                    dot_radius = 2 + int(dot_pulse * 2)       # 2 ~ 4 px
                    core_radius = max(1, int(dot_pulse * 2))  # 1 ~ 2 px 하이라이트
                    pygame.draw.circle(screen, TEXT_GOLD, (rx, ry), dot_radius)
                    pygame.draw.circle(screen, (255, 255, 230), (rx, ry), core_radius)

            # [업그레이드 1] 3) 내부 펄스 헤일로 — 가산혼합으로 자체발광.
            halo_pulse = 0.5 + 0.5 * math.sin(t_sec * 3.2)
            halo_alpha = int(130 + 80 * halo_pulse)
            halo_r = max(0, int(46 * intro))
            if halo_r > 0:
                halo_surf = pygame.Surface((halo_r * 2 + 6, halo_r * 2 + 6), pygame.SRCALPHA)
                halo_color = tuple(min(255, c + 40) for c in perk_color[:3])
                pygame.draw.circle(
                    halo_surf,
                    (*halo_color, halo_alpha),
                    (halo_r + 3, halo_r + 3),
                    halo_r,
                    3,
                )
                screen.blit(
                    halo_surf,
                    (cx - halo_r - 3, cy - halo_r - 3),
                    special_flags=pygame.BLEND_RGB_ADD,
                )

            # 4) 중앙 대형 아이콘 — 가독성 우선: 팝인 무관, 즉시 풀사이즈.
            icon_size = 64
            pygame.draw.circle(screen, BG_DARK, (cx, cy), 36)
            pygame.draw.circle(screen, TEXT_GOLD, (cx, cy), 36, 2)
            try:
                pf._draw_skill_icon_symbol(
                    screen, skill_name, cx, cy, icon_size, True, perk_color
                )
            except Exception:
                pygame.draw.circle(screen, perk_color, (cx, cy), icon_size // 2 - 4)
                pygame.draw.circle(screen, TEXT_WHITE, (cx, cy), icon_size // 2 - 4, 2)

            # [업그레이드 1+3] 5) 궤도 스파클 + 꼬리 잔상 + 가산혼합.
            sparkle_specs = [
                (72, 1.4, 0.0, (255, 240, 160)),
                (58, -1.9, math.pi / 2, (255, 215, 100)),
                (82, 1.1, math.pi, (220, 200, 255)),
                (68, -1.6, math.pi * 1.5, (180, 220, 255)),
            ]
            sparkle_canvas = None
            for (srad_base, sspd, soffset, scolor) in sparkle_specs:
                srad = srad_base * intro
                if srad <= 1:
                    continue
                # 혜성 꼬리: 과거 시각의 가상 위치에 점점 작아지는 점 3개.
                if sparkle_canvas is None:
                    sparkle_canvas = pygame.Surface(
                        (dialog_w, dialog_h + 160), pygame.SRCALPHA
                    )
                    canvas_ox = dialog_x
                    canvas_oy = dialog_y - 80
                for trail_idx in range(3, 0, -1):
                    past_ang = (t_sec - trail_idx * 0.045) * sspd + soffset
                    tx = cx + int(math.cos(past_ang) * srad)
                    ty = cy + int(math.sin(past_ang) * srad * 0.55)
                    # 꼬리 투명도 감쇠 (가까울수록 진하게)
                    trail_fade = int(180 * (1.0 - trail_idx / 4.0))
                    pygame.draw.circle(
                        sparkle_canvas,
                        (*scolor, trail_fade),
                        (tx - canvas_ox, ty - canvas_oy),
                        max(1, 2 - trail_idx // 2),
                    )
                # 본체 (십자 + 코어)
                sang = t_sec * sspd + soffset
                sx = cx + int(math.cos(sang) * srad)
                sy = cy + int(math.sin(sang) * srad * 0.55)
                lx, ly = sx - canvas_ox, sy - canvas_oy
                pygame.draw.line(sparkle_canvas, scolor, (lx - 3, ly), (lx + 3, ly), 1)
                pygame.draw.line(sparkle_canvas, scolor, (lx, ly - 3), (lx, ly + 3), 1)
                pygame.draw.circle(sparkle_canvas, scolor, (lx, ly), 1)

            if sparkle_canvas is not None:
                screen.blit(
                    sparkle_canvas,
                    (canvas_ox, canvas_oy),
                    special_flags=pygame.BLEND_RGB_ADD,
                )

            content_y = cy + 52 - int(float_offset)  # 아래 텍스트는 호버링과 무관하게 고정

            # 스킬 이름 (대형 금색, 중앙)
            surf, rect = render_text(font_title, f"《  {perk_name}  》", TEXT_GOLD)
            if surf:
                screen.blit(surf, (dialog_x + dialog_w // 2 - rect.width // 2, content_y))
            content_y += rect.height + 10 if surf else 32

            # 설명 (중앙 정렬, 최대 3줄)
            desc_lines = _wrap_text(perk_desc, 34) if perk_desc else []
            for line in desc_lines[:3]:
                surf, rect = render_text(font_small, line, TEXT_WHITE)
                if surf:
                    screen.blit(surf, (dialog_x + dialog_w // 2 - rect.width // 2, content_y))
                content_y += 20

            # 버튼
            btn_w, btn_h = 160, 42
            action_btn = pygame.Rect(
                dialog_x + dialog_w // 2 - btn_w - 10,
                dialog_y + dialog_h - 60,
                btn_w, btn_h
            )
            cancel_btn = pygame.Rect(
                dialog_x + dialog_w // 2 + 10,
                dialog_y + dialog_h - 60,
                btn_w, btn_h
            )

            if slots_full:
                action_label = "교환하기 (무료)"
                enabled = True
            else:
                action_label = "배우기 (1000G)"
                enabled = cur_gold >= 1000

            hover = action_btn.collidepoint(mouse_pos) and enabled
            if enabled:
                pygame.draw.rect(screen, BUTTON_HOVER if hover else BUTTON_BG, action_btn, border_radius=6)
                pygame.draw.rect(screen, BORDER_PURPLE, action_btn, 2, border_radius=6)
                btn_color = TEXT_WHITE
            else:
                pygame.draw.rect(screen, BUTTON_DISABLED, action_btn, border_radius=6)
                pygame.draw.rect(screen, TEXT_DIM, action_btn, 2, border_radius=6)
                btn_color = TEXT_DISABLED
            surf, rect = render_text(font_medium, action_label, btn_color)
            if surf:
                screen.blit(surf, (action_btn.centerx - rect.width // 2, action_btn.centery - rect.height // 2))

            cancel_hover = cancel_btn.collidepoint(mouse_pos)
            pygame.draw.rect(screen, BUTTON_HOVER if cancel_hover else BUTTON_BG, cancel_btn, border_radius=6)
            pygame.draw.rect(screen, BORDER_PURPLE, cancel_btn, 2, border_radius=6)
            surf, rect = render_text(font_medium, "그만두기", TEXT_WHITE)
            if surf:
                screen.blit(surf, (cancel_btn.centerx - rect.width // 2, cancel_btn.centery - rect.height // 2))

            # 클릭 처리 (성공 메시지 중이면 무시)
            if success_message_timer <= 0 and click_pos:
                if cancel_btn.collidepoint(click_pos):
                    running = False
                elif action_btn.collidepoint(click_pos):
                    if not enabled:
                        temp_message = "\"돈이 부족하군 자네..\""
                        temp_message_timer = 1800
                    else:
                        if slots_full:
                            old_skill = _open_swap_dialog(pf, character_type, offered_perk)
                            if old_skill:
                                if pf.apply_academy_skill_swap(character_type, offered_perk, old_skill):
                                    result = ("swapped", offered_perk, old_skill)
                                    success_message = f"교환 완료! {perk_name}"
                                    success_message_timer = 900
                        else:
                            if pf.apply_academy_skill_purchase(character_type, offered_perk):
                                result = ("purchased", offered_perk, None)
                                success_message = f"-1000G ▶ {perk_name} 습득!"
                                success_message_timer = 900
                        if result:
                            _visit_pick_cache["consumed"] = True
                            _visit_pick_cache["offered_perk"] = None

        # 임시 메시지 (골드 부족 등)
        if temp_message and temp_message_timer > 0:
            temp_message_timer -= dt
            surf, rect = render_text(font_medium, temp_message, TEXT_GOLD)
            if surf:
                screen.blit(surf, (
                    dialog_x + dialog_w // 2 - rect.width // 2,
                    dialog_y + dialog_h - 100
                ))
            if temp_message_timer <= 0:
                temp_message = ""

        # 성공 메시지 + 자동 닫기
        if success_message and success_message_timer > 0:
            success_message_timer -= dt
            flash = pygame.Surface((dialog_w, 50), pygame.SRCALPHA)
            flash.fill((255, 215, 100, 160))
            screen.blit(flash, (dialog_x, dialog_y + dialog_h // 2 - 25))
            surf, rect = render_text(font_title, success_message, BG_DARK)
            if surf:
                screen.blit(surf, (
                    dialog_x + dialog_w // 2 - rect.width // 2,
                    dialog_y + dialog_h // 2 - rect.height // 2
                ))
            if success_message_timer <= 0:
                running = False

        # 하단 힌트
        surf, rect = render_text(font_tiny, "클릭으로 선택  |  ESC 닫기", TEXT_DIM)
        if surf:
            screen.blit(surf, (dialog_x + dialog_w // 2 - rect.width // 2, dialog_y + dialog_h - 16))

        pygame.display.flip()

    return result
