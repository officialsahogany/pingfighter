import os
import sys
from typing import Dict, Optional, Tuple

import pygame

from config.language_options import DEFAULT_LANGUAGE, LANGUAGE_CODES
from config.settings_system import get_settings_manager
from game_state.audio import (
    clamp_volume,
    get_bgm_volume,
    get_sfx_volume,
    set_bgm_volume as set_runtime_bgm_volume,
    set_sfx_volume as set_runtime_sfx_volume,
)
from localization.manager import get_localization_manager

# 전역 설정 변수들
AVAILABLE_LANGUAGE_CODES = LANGUAGE_CODES
LEGACY_LANGUAGE_MAP = {
    "한국어": "ko",
    "English": "en",
    "english": "en",
    "日本語": "ja",
    "Japanese": "ja",
    "japanese": "ja",
    "中文": "zh",
    "Chinese": "zh",
    "chinese": "zh",
}
LEGACY_CONTROL_MAP = {
    "키보드": "keyboard",
    "keyboard": "keyboard",
    "마우스": "mouse_keyboard",
    "mouse": "mouse_keyboard",
    "mouse_keyboard": "mouse_keyboard",
    "조이패드": "keyboard",
    "gamepad": "keyboard",
}
LANGUAGE = DEFAULT_LANGUAGE  # 언어 코드는 config.language_options 기준
BGM_VOLUME = 0.7  # 0.0 ~ 1.0
SFX_VOLUME = 0.8  # 0.0 ~ 1.0
ARENA_SOUND_PACK = "bk22"
FULLSCREEN = False  # True: 전체화면, False: 창모드
CONTROL_MODE = "keyboard"
CONTROL_OPTIONS = [
    ("keyboard", "option.controls.keyboard", "키보드"),
    ("mouse_keyboard", "option.controls.mouse", "마우스+키보드"),
]
VALID_CONTROL_SCHEMES = {value for value, _, _ in CONTROL_OPTIONS}
FONT_CACHE: Dict[Tuple[str, int], pygame.font.Font] = {}


def _get_runtime_game_module() -> Optional[object]:
    for module_name in ("pingfighter", "bosspong", "__main__"):
        module = sys.modules.get(module_name)
        if module is not None:
            return module
    return None


def _normalize_arena_sound_pack(value: str) -> str:
    return value if value in ("bk22", "anderson") else "bk22"


def normalize_control_scheme(value: str) -> str:
    normalized = LEGACY_CONTROL_MAP.get(value, value)
    if normalized in VALID_CONTROL_SCHEMES:
        return normalized
    return "keyboard"


def _apply_runtime_audio_settings() -> None:
    global BGM_VOLUME, SFX_VOLUME

    BGM_VOLUME = clamp_volume(BGM_VOLUME)
    SFX_VOLUME = clamp_volume(SFX_VOLUME)

    runtime_module = _get_runtime_game_module()
    store_bgm_volume = getattr(runtime_module, "store_bgm_volume", None) if runtime_module else None
    set_sfx_volume = getattr(runtime_module, "set_sfx_volume", None) if runtime_module else None

    if callable(store_bgm_volume):
        try:
            BGM_VOLUME = clamp_volume(float(store_bgm_volume(BGM_VOLUME)))
        except Exception:
            BGM_VOLUME = set_runtime_bgm_volume(BGM_VOLUME)
    else:
        BGM_VOLUME = set_runtime_bgm_volume(BGM_VOLUME)
        if runtime_module is not None and hasattr(runtime_module, "bgm_volume"):
            try:
                runtime_module.bgm_volume = BGM_VOLUME
            except Exception:
                pass

    try:
        import bgm_manager

        bgm_manager.set_bgm_volume(BGM_VOLUME)
    except Exception:
        pass

    if callable(set_sfx_volume):
        try:
            SFX_VOLUME = clamp_volume(float(set_sfx_volume(SFX_VOLUME)))
        except Exception:
            SFX_VOLUME = set_runtime_sfx_volume(SFX_VOLUME)
    else:
        SFX_VOLUME = set_runtime_sfx_volume(SFX_VOLUME)
        if runtime_module is not None and hasattr(runtime_module, "sfx_volume"):
            try:
                runtime_module.sfx_volume = SFX_VOLUME
            except Exception:
                pass


def _apply_runtime_control_scheme() -> None:
    runtime_module = _get_runtime_game_module()
    if runtime_module is not None and hasattr(runtime_module, "CONTROL_MODE"):
        try:
            runtime_module.CONTROL_MODE = CONTROL_MODE
        except Exception:
            pass


def _get_current_display_mode() -> str:
    runtime_module = _get_runtime_game_module()
    get_display_mode = getattr(runtime_module, "get_display_mode", None) if runtime_module else None
    if callable(get_display_mode):
        try:
            mode = get_display_mode()
        except Exception:
            mode = None
        if mode in ("fullscreen", "cinema", "windowed"):
            return mode
    return "fullscreen" if FULLSCREEN else "windowed"


def _sync_fullscreen_from_runtime() -> None:
    global FULLSCREEN
    FULLSCREEN = _get_current_display_mode() != "windowed"


def _apply_display_selection(fullscreen_enabled: bool) -> None:
    global FULLSCREEN

    runtime_module = _get_runtime_game_module()
    target_mode = "fullscreen" if fullscreen_enabled else "windowed"
    switch_display_mode = getattr(runtime_module, "switch_display_mode", None) if runtime_module else None

    if callable(switch_display_mode):
        try:
            if _get_current_display_mode() != target_mode:
                switch_display_mode(target_mode)
        except Exception:
            pass
    else:
        toggle_fullscreen = getattr(runtime_module, "toggle_fullscreen", None) if runtime_module else None
        if callable(toggle_fullscreen) and FULLSCREEN != fullscreen_enabled:
            try:
                toggle_fullscreen()
            except Exception:
                pass

    FULLSCREEN = fullscreen_enabled


def save_settings():
    """설정을 공용 설정 저장소와 레거시 파일에 저장."""

    global LANGUAGE, BGM_VOLUME, SFX_VOLUME, FULLSCREEN, CONTROL_MODE, ARENA_SOUND_PACK

    LANGUAGE = normalize_language_code(LANGUAGE)
    CONTROL_MODE = normalize_control_scheme(CONTROL_MODE)
    ARENA_SOUND_PACK = _normalize_arena_sound_pack(ARENA_SOUND_PACK)
    BGM_VOLUME = clamp_volume(BGM_VOLUME)
    SFX_VOLUME = clamp_volume(SFX_VOLUME)
    _sync_fullscreen_from_runtime()

    try:
        settings_manager = get_settings_manager()
        settings_manager.set_setting("language", "language", LANGUAGE)
        settings_manager.set_setting("audio", "music_volume", BGM_VOLUME)
        settings_manager.set_setting("audio", "sfx_volume", SFX_VOLUME)
        settings_manager.set_setting("audio", "arena_sound_pack", ARENA_SOUND_PACK)
        settings_manager.set_setting("controls", "control_scheme", CONTROL_MODE)
        settings_manager.save_settings()
    except Exception:
        pass

    _apply_runtime_audio_settings()
    _apply_runtime_control_scheme()
    get_localization_manager().set_language(LANGUAGE)

    try:
        with open("settings.txt", "w", encoding="utf-8") as f:
            f.write(f"LANGUAGE={LANGUAGE}\n")
            f.write(f"BGM_VOLUME={BGM_VOLUME}\n")
            f.write(f"SFX_VOLUME={SFX_VOLUME}\n")
            f.write(f"FULLSCREEN={FULLSCREEN}\n")
            f.write(f"CONTROL_MODE={CONTROL_MODE}\n")
    except Exception:
        pass


def load_settings():
    """공용 설정 저장소 기준으로 설정을 불러오고 레거시 파일도 호환."""

    global LANGUAGE, BGM_VOLUME, SFX_VOLUME, FULLSCREEN, CONTROL_MODE, ARENA_SOUND_PACK

    legacy_language = LANGUAGE
    legacy_bgm_volume = BGM_VOLUME
    legacy_sfx_volume = SFX_VOLUME
    legacy_fullscreen = FULLSCREEN
    legacy_control_mode = CONTROL_MODE
    legacy_arena_sound_pack = ARENA_SOUND_PACK

    try:
        if os.path.exists("settings.txt"):
            with open("settings.txt", "r", encoding="utf-8") as f:
                for line in f:
                    if "=" not in line:
                        continue
                    key, value = line.strip().split("=", 1)
                    if key == "LANGUAGE":
                        legacy_language = normalize_language_code(value)
                    elif key == "BGM_VOLUME":
                        legacy_bgm_volume = clamp_volume(float(value))
                    elif key == "SFX_VOLUME":
                        legacy_sfx_volume = clamp_volume(float(value))
                    elif key == "FULLSCREEN":
                        legacy_fullscreen = value == "True"
                    elif key == "CONTROL_MODE":
                        legacy_control_mode = normalize_control_scheme(value)
    except Exception:
        pass

    try:
        settings_manager = get_settings_manager()
        LANGUAGE = normalize_language_code(
            settings_manager.get_setting("language", "language", legacy_language)
        )
        BGM_VOLUME = clamp_volume(
            float(settings_manager.get_setting("audio", "music_volume", legacy_bgm_volume))
        )
        SFX_VOLUME = clamp_volume(
            float(settings_manager.get_setting("audio", "sfx_volume", legacy_sfx_volume))
        )
        ARENA_SOUND_PACK = _normalize_arena_sound_pack(
            settings_manager.get_setting("audio", "arena_sound_pack", legacy_arena_sound_pack)
        )
        CONTROL_MODE = normalize_control_scheme(
            settings_manager.get_setting("controls", "control_scheme", legacy_control_mode)
        )
    except Exception:
        LANGUAGE = legacy_language
        BGM_VOLUME = legacy_bgm_volume
        SFX_VOLUME = legacy_sfx_volume
        ARENA_SOUND_PACK = _normalize_arena_sound_pack(legacy_arena_sound_pack)
        CONTROL_MODE = normalize_control_scheme(legacy_control_mode)

    _apply_runtime_control_scheme()
    _apply_runtime_audio_settings()
    BGM_VOLUME = clamp_volume(get_bgm_volume())
    SFX_VOLUME = clamp_volume(get_sfx_volume())
    FULLSCREEN = legacy_fullscreen
    _sync_fullscreen_from_runtime()
    get_localization_manager().set_language(LANGUAGE)


def normalize_language_code(value: str) -> str:
    if value in AVAILABLE_LANGUAGE_CODES:
        return value
    mapped = LEGACY_LANGUAGE_MAP.get(value, None)
    if mapped:
        return mapped
    return DEFAULT_LANGUAGE


def translate(key: str, fallback: str) -> str:
    return get_localization_manager().get_text(key, fallback)


def get_language_display_name(code: str) -> str:
    return get_localization_manager().get_language_label(code)


def get_control_display_name(canonical_value: str, translation_key: str, fallback: str) -> str:
    return translate(translation_key, fallback)


def get_localized_font(size: int, bold: bool = False) -> pygame.font.Font:
    manager = get_localization_manager()
    language_code = manager.current_language
    if bold:
        primary_font = "NanumSquareB.ttf"
        fallback_font = "Pretendard-Bold.ttf"
    else:
        primary_font = "NanumSquareR.ttf"
        fallback_font = "Pretendard-Regular.ttf"

    font_path = primary_font if language_code != "ja" else fallback_font
    cache_key = (font_path, size)
    if cache_key in FONT_CACHE:
        return FONT_CACHE[cache_key]

    font: pygame.font.Font
    try:
        font = pygame.font.Font(font_path, size)
    except Exception:
        try:
            font = pygame.font.Font(fallback_font, size)
            cache_key = (fallback_font, size)
        except Exception:
            font = pygame.font.Font(None, size)
            cache_key = ("__default__", size)

    FONT_CACHE[cache_key] = font
    return font

def draw_slider(surface, x, y, width, height, value, min_val, max_val, color=(100, 150, 255)):
    """슬라이더 그리기"""
    # 슬라이더 배경
    pygame.draw.rect(surface, (60, 60, 80), (x, y, width, height))
    pygame.draw.rect(surface, (100, 100, 120), (x, y, width, height), 2)
    
    # 슬라이더 핸들 위치 계산
    handle_x = x + (value - min_val) / (max_val - min_val) * (width - 20)
    handle_y = y + height // 2 - 10
    
    # 슬라이더 핸들
    pygame.draw.rect(surface, color, (handle_x, handle_y, 20, 20))
    pygame.draw.rect(surface, (255, 255, 255), (handle_x, handle_y, 20, 20), 2)
    
    # 값 표시
    font = get_localized_font(16)
    value_text = font.render(f"{int(value * 100)}%", True, (255, 255, 255))
    surface.blit(value_text, (x + width + 10, y + height // 2 - 8))

def draw_button(surface, x, y, width, height, text, selected=False, color=(100, 150, 255)):
    """버튼 그리기"""
    # 버튼 배경
    if selected:
        pygame.draw.rect(surface, color, (x, y, width, height))
        pygame.draw.rect(surface, (255, 255, 255), (x, y, width, height), 3)
    else:
        pygame.draw.rect(surface, (60, 60, 80), (x, y, width, height))
        pygame.draw.rect(surface, (100, 100, 120), (x, y, width, height), 2)
    
    # 텍스트
    font = get_localized_font(18)
    text_surface = font.render(text, True, (255, 255, 255))
    text_rect = text_surface.get_rect(center=(x + width // 2, y + height // 2))
    surface.blit(text_surface, text_rect)

def show_options_menu(screen, width, height):
    """옵션 메뉴 표시"""
    global LANGUAGE, BGM_VOLUME, SFX_VOLUME, FULLSCREEN, CONTROL_MODE, ARENA_SOUND_PACK
    
    # 설정 불러오기
    load_settings()
    localization_manager = get_localization_manager()
    localization_manager.set_language(LANGUAGE)
    _apply_runtime_control_scheme()
    
    # 사운드 로드 (메인 게임에서 사용하는 사운드들)
    try:
        SOUND_BUTTON_CLICK = pygame.mixer.Sound("sounds/button_click.wav")
        SOUND_BUTTON_HOVER = pygame.mixer.Sound("sounds/button_hover.wav")
    except:
        # 사운드 파일이 없으면 빈 사운드 생성
        SOUND_BUTTON_CLICK = pygame.mixer.Sound(buffer=bytes([0]*44))
        SOUND_BUTTON_HOVER = pygame.mixer.Sound(buffer=bytes([0]*44))
    
    # 메뉴 상태
    selected_category = 0  # 0: 언어, 1: 사운드, 2: 화면, 3: 조작
    selected_option = 0  # 각 카테고리 내에서 선택된 옵션
    category_keys = ["language", "sound", "screen", "controls"]
    selected_option = 1 if FULLSCREEN else 0
    arena_bk22_rect = pygame.Rect(0, 0, 0, 0)
    arena_anderson_rect = pygame.Rect(0, 0, 0, 0)
    
    # 애니메이션 변수
    animation_timer = 0
    particles = []
    
    # 색상 팔레트
    color_palettes = [
        [(20, 12, 35), (35, 25, 65), (50, 35, 95)],  # 보라빛
        [(35, 20, 12), (55, 35, 25), (75, 50, 35)],  # 주황빛
        [(12, 35, 20), (25, 55, 35), (35, 75, 50)],  # 초록빛
        [(35, 12, 20), (55, 25, 35), (75, 35, 50)]   # 붉은빛
    ]
    
    while True:
        animation_timer += 1
        
        # 배경 그리기 (메인 메뉴와 동일한 스타일)
        color_cycle = (animation_timer // 540) % len(color_palettes)
        current_palette = color_palettes[color_cycle]
        next_palette = color_palettes[(color_cycle + 1) % len(color_palettes)]
        
        transition_ratio = (animation_timer % 540) / 540
        transition_ratio = (1 - math.cos(transition_ratio * math.pi)) / 2
        
        for y in range(height):
            color_ratio = y / height
            time_factor = math.sin(animation_timer * 0.005) * 0.15 + 0.85
            
            r1, g1, b1 = current_palette[0]
            r2, g2, b2 = next_palette[0]
            r = int(r1 + (r2 - r1) * transition_ratio)
            g = int(g1 + (g2 - g1) * transition_ratio)
            b = int(b1 + (b2 - b1) * transition_ratio)
            
            r = int(r + color_ratio * (current_palette[2][0] - r) * time_factor * 0.6)
            g = int(g + color_ratio * (current_palette[2][1] - g) * time_factor * 0.6)
            b = int(b + color_ratio * (current_palette[2][2] - b) * time_factor * 0.6)
            
            r = max(10, min(80, r))
            g = max(10, min(80, g))
            b = max(10, min(80, b))
            
            pygame.draw.line(screen, (r, g, b), (0, y), (width, y))
        
        # 제목
        title_font = get_localized_font(48, bold=True)
        title_value = translate("option.title", "옵션")
        title_text = title_font.render(title_value, True, (255, 255, 255))
        title_rect = title_text.get_rect(center=(width // 2, 80))
        
        # 제목 그림자
        title_shadow = title_font.render(title_value, True, (100, 100, 100))
        screen.blit(title_shadow, (title_rect.x + 2, title_rect.y + 2))
        screen.blit(title_text, title_rect)
        
        # 카테고리 버튼들
        categories = [translate(f"option.category.{key}", key.title()) for key in category_keys]
        category_width = 120
        category_height = 40
        category_spacing = 20
        total_width = len(categories) * category_width + (len(categories) - 1) * category_spacing
        start_x = (width - total_width) // 2
        
        for i, category in enumerate(categories):
            x = start_x + i * (category_width + category_spacing)
            y = 150
            selected = (i == selected_category)
            draw_button(screen, x, y, category_width, category_height, category, selected)
        
        # 옵션 내용 영역
        content_y = 220
        content_height = 300
        
        # 선택된 카테고리에 따른 내용 표시
        if selected_category == 0:  # 언어
            for i, language_code in enumerate(AVAILABLE_LANGUAGE_CODES):
                x = width // 2 - 100
                y = content_y + i * 60
                selected = (LANGUAGE == language_code)
                draw_button(
                    screen,
                    x,
                    y,
                    200,
                    50,
                    get_language_display_name(language_code),
                    selected,
                )
                
        elif selected_category == 1:  # 사운드
            # BGM 볼륨
            font = get_localized_font(20)
            bgm_text = font.render(translate("option.sound.bgm_volume", "BGM"), True, (255, 255, 255))
            screen.blit(bgm_text, (width // 2 - 200, content_y))
            draw_slider(screen, width // 2 - 150, content_y + 30, 300, 20, BGM_VOLUME, 0.0, 1.0)
            
            # 효과음 볼륨
            sfx_text = font.render(translate("option.sound.sfx_volume", "SFX"), True, (255, 255, 255))
            screen.blit(sfx_text, (width // 2 - 200, content_y + 80))
            draw_slider(screen, width // 2 - 150, content_y + 110, 300, 20, SFX_VOLUME, 0.0, 1.0)

            arena_pack_text = font.render("투기장 사운드팩", True, (255, 255, 255))
            screen.blit(arena_pack_text, (width // 2 - 200, content_y + 160))
            arena_bk22_rect = pygame.Rect(width // 2 - 150, content_y + 195, 130, 40)
            arena_anderson_rect = pygame.Rect(width // 2 + 10, content_y + 195, 150, 40)
            draw_button(
                screen,
                arena_bk22_rect.x,
                arena_bk22_rect.y,
                arena_bk22_rect.width,
                arena_bk22_rect.height,
                "BK22팩",
                ARENA_SOUND_PACK == "bk22",
            )
            draw_button(
                screen,
                arena_anderson_rect.x,
                arena_anderson_rect.y,
                arena_anderson_rect.width,
                arena_anderson_rect.height,
                "Anderson팩",
                ARENA_SOUND_PACK == "anderson",
            )
            
        elif selected_category == 2:  # 화면
            modes = [
                (0, translate("option.screen.windowed", "Windowed")),
                (1, translate("option.screen.fullscreen", "Fullscreen"))
            ]
            for i, mode in enumerate(modes):
                x = width // 2 - 100
                y = content_y + i * 60
                selected = (selected_option == i)  # 선택된 옵션으로 변경
                draw_button(screen, x, y, 200, 50, mode[1], selected)
                
            # 안내 텍스트
            guide_font = get_localized_font(16)
            guide_text = guide_font.render(
                translate("option.screen.guide", "Use ↑↓ to choose, Space/Enter to apply"),
                True,
                (200, 200, 200)
            )
            screen.blit(guide_text, (width // 2 - 150, content_y + 150))
                
        elif selected_category == 3:  # 조작
            for i, (canonical_value, translation_key, fallback_label) in enumerate(CONTROL_OPTIONS):
                x = width // 2 - 100
                y = content_y + i * 60
                control_label = get_control_display_name(canonical_value, translation_key, fallback_label)
                selected = (CONTROL_MODE == canonical_value)
                draw_button(screen, x, y, 200, 50, control_label, selected)
            
            # 마우스 조작 안내 텍스트
            mouse_hint = translate("option.controls.mouse_hint", "Mouse hint")
            if CONTROL_MODE == "mouse_keyboard":
                guide_font = get_localized_font(14)
                guide_text = guide_font.render(mouse_hint, True, (200, 200, 200))
                screen.blit(guide_text, (width // 2 - 200, content_y + 150))
        
        # 뒤로가기 버튼
        back_button_rect = pygame.Rect(50, height - 80, 120, 40)
        draw_button(
            screen,
            back_button_rect.x,
            back_button_rect.y,
            back_button_rect.width,
            back_button_rect.height,
            translate("option.back", "Back")
        )
        
        # 적용 버튼
        apply_button_rect = pygame.Rect(width - 170, height - 80, 120, 40)
        draw_button(
            screen,
            apply_button_rect.x,
            apply_button_rect.y,
            apply_button_rect.width,
            apply_button_rect.height,
            translate("option.apply", "Apply")
        )
        
        pygame.display.flip()
        
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
                
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return
                    
                elif event.key == pygame.K_LEFT:
                    if selected_category > 0:
                        selected_category -= 1
                        SOUND_BUTTON_HOVER.play()
                elif event.key == pygame.K_RIGHT:
                    if selected_category < len(category_keys) - 1:
                        selected_category += 1
                        SOUND_BUTTON_HOVER.play()
                        
                elif event.key == pygame.K_UP:
                    if selected_category == 0:  # 언어
                        if LANGUAGE not in AVAILABLE_LANGUAGE_CODES:
                            LANGUAGE = DEFAULT_LANGUAGE
                        current_index = AVAILABLE_LANGUAGE_CODES.index(LANGUAGE)
                        LANGUAGE = AVAILABLE_LANGUAGE_CODES[(current_index - 1) % len(AVAILABLE_LANGUAGE_CODES)]
                        get_localization_manager().set_language(LANGUAGE)
                        SOUND_BUTTON_HOVER.play()
                    elif selected_category == 2:  # 화면
                        selected_option = (selected_option - 1) % 2
                        SOUND_BUTTON_HOVER.play()
                    elif selected_category == 3:  # 조작
                        controls = [value for value, _, _ in CONTROL_OPTIONS]
                        current_index = controls.index(CONTROL_MODE)
                        CONTROL_MODE = controls[(current_index - 1) % len(controls)]
                        _apply_runtime_control_scheme()
                        SOUND_BUTTON_HOVER.play()
                        
                elif event.key == pygame.K_DOWN:
                    if selected_category == 0:  # 언어
                        if LANGUAGE not in AVAILABLE_LANGUAGE_CODES:
                            LANGUAGE = DEFAULT_LANGUAGE
                        current_index = AVAILABLE_LANGUAGE_CODES.index(LANGUAGE)
                        LANGUAGE = AVAILABLE_LANGUAGE_CODES[(current_index + 1) % len(AVAILABLE_LANGUAGE_CODES)]
                        get_localization_manager().set_language(LANGUAGE)
                        SOUND_BUTTON_HOVER.play()
                    elif selected_category == 2:  # 화면
                        selected_option = (selected_option + 1) % 2
                        SOUND_BUTTON_HOVER.play()
                    elif selected_category == 3:  # 조작
                        controls = [value for value, _, _ in CONTROL_OPTIONS]
                        current_index = controls.index(CONTROL_MODE)
                        CONTROL_MODE = controls[(current_index + 1) % len(controls)]
                        _apply_runtime_control_scheme()
                        SOUND_BUTTON_HOVER.play()
                        
                elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                    if selected_category == 2:  # 화면 카테고리에서
                        # 선택된 옵션에 따라 화면 모드 변경
                        new_fullscreen = (selected_option == 1)
                        _apply_display_selection(new_fullscreen)
                        SOUND_BUTTON_CLICK.play()
                    else:
                        SOUND_BUTTON_CLICK.play()
                        save_settings()
                        return
                    
            elif event.type == pygame.MOUSEBUTTONDOWN:
                mouse_x, mouse_y = pygame.mouse.get_pos()
                
                # 카테고리 버튼 클릭
                for i, category in enumerate(categories):
                    x = start_x + i * (category_width + category_spacing)
                    y = 150
                    if x <= mouse_x <= x + category_width and y <= mouse_y <= y + category_height:
                        selected_category = i
                        # 화면 카테고리로 이동할 때 현재 화면 모드에 맞게 selected_option 설정
                        if i == 2:  # 화면 카테고리
                            _sync_fullscreen_from_runtime()
                            selected_option = 1 if FULLSCREEN else 0
                        SOUND_BUTTON_HOVER.play()
                        break
                
                # 뒤로가기 버튼 클릭
                if back_button_rect.collidepoint(mouse_x, mouse_y):
                    SOUND_BUTTON_CLICK.play()
                    return
                    
                # 적용 버튼 클릭
                if apply_button_rect.collidepoint(mouse_x, mouse_y):
                    SOUND_BUTTON_CLICK.play()
                    save_settings()
                    return
                
                # 슬라이더 클릭 (사운드 카테고리)
                if selected_category == 1:
                    if content_y + 30 <= mouse_y <= content_y + 50:  # BGM 슬라이더
                        if width // 2 - 150 <= mouse_x <= width // 2 + 150:
                            ratio = (mouse_x - (width // 2 - 150)) / 300
                            BGM_VOLUME = clamp_volume(ratio)
                            _apply_runtime_audio_settings()
                    elif content_y + 110 <= mouse_y <= content_y + 130:  # SFX 슬라이더
                        if width // 2 - 150 <= mouse_x <= width // 2 + 150:
                            ratio = (mouse_x - (width // 2 - 150)) / 300
                            SFX_VOLUME = clamp_volume(ratio)
                            _apply_runtime_audio_settings()
                    elif arena_bk22_rect.collidepoint(mouse_x, mouse_y):
                        ARENA_SOUND_PACK = "bk22"
                        SOUND_BUTTON_CLICK.play()
                    elif arena_anderson_rect.collidepoint(mouse_x, mouse_y):
                        ARENA_SOUND_PACK = "anderson"
                        SOUND_BUTTON_CLICK.play()
                
                # 옵션 버튼 클릭
                if selected_category == 0:  # 언어
                    for i, language_code in enumerate(AVAILABLE_LANGUAGE_CODES):
                        x = width // 2 - 100
                        y = content_y + i * 60
                        if x <= mouse_x <= x + 200 and y <= mouse_y <= y + 50:
                            LANGUAGE = language_code
                            get_localization_manager().set_language(LANGUAGE)
                            SOUND_BUTTON_CLICK.play()
                            break
                            
                elif selected_category == 2:  # 화면
                    modes = [
                        (0, translate("option.screen.windowed", "Windowed")),
                        (1, translate("option.screen.fullscreen", "Fullscreen"))
                    ]
                    for i, mode in enumerate(modes):
                        x = width // 2 - 100
                        y = content_y + i * 60
                        if x <= mouse_x <= x + 200 and y <= mouse_y <= y + 50:
                            selected_option = i
                            SOUND_BUTTON_CLICK.play()
                            # 선택된 옵션에 따라 화면 모드 변경
                            new_fullscreen = (selected_option == 1)
                            _apply_display_selection(new_fullscreen)
                            break
                            
                elif selected_category == 3:  # 조작
                    for i, (canonical_value, translation_key, fallback_label) in enumerate(CONTROL_OPTIONS):
                        control_label = get_control_display_name(canonical_value, translation_key, fallback_label)
                        x = width // 2 - 100
                        y = content_y + i * 60
                        if x <= mouse_x <= x + 200 and y <= mouse_y <= y + 50:
                            CONTROL_MODE = canonical_value
                            _apply_runtime_control_scheme()
                            SOUND_BUTTON_CLICK.play()
                            break

# 수학 모듈 import 추가
import math
