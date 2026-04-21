import os

import pygame

from resource_path import resource_path

LOGO_INTRO_BG = (0, 0, 0)
LOGO_INTRO_RING = (245, 238, 225)
LOGO_INTRO_RING_HILITE = (250, 248, 243, 110)
LOGO_INTRO_RED = (208, 42, 34)
# Warm cream halo: reads as a soft radial bloom against the black BG without
# tinting the red disc.
LOGO_INTRO_GLOW_COLOR = (255, 210, 160)
LOGO_INTRO_FRAME_COUNT = 24
LOGO_INTRO_COLS = 6
LOGO_INTRO_CELL_W = 965
LOGO_INTRO_CELL_H = 961
# Fade-in was removed: bootstrap already displays the logo disc at full
# opacity, so ramping the composite back from 0 caused a visible pop.
LOGO_INTRO_FADE_OUT_MS = 300
LOGO_INTRO_SCALE_IN_MS = 300
LOGO_INTRO_SCALE_IN_START = 0.82
LOGO_INTRO_FPS = 15
LOGO_INTRO_LOOP_COUNT = 1
LOGO_INTRO_TOTAL_ANIM_MS = int((1000 / LOGO_INTRO_FPS) * LOGO_INTRO_FRAME_COUNT * LOGO_INTRO_LOOP_COUNT)

# Studio text (rendered once at cache-build time, alpha-modulated at draw time).
LOGO_INTRO_TEXT = "동네게임즈"
LOGO_INTRO_TEXT_COLOR = LOGO_INTRO_GLOW_COLOR
LOGO_INTRO_TEXT_SIZE_RATIO = 0.17
LOGO_INTRO_TEXT_GAP_MIN_PX = 16
LOGO_INTRO_TEXT_GAP_RATIO = 0.06
LOGO_INTRO_TEXT_REVEAL_MS = 500
# Glint: warm off-white (harmonizes with cream glow instead of cold flash),
# starts after the reveal fully lands, peak alpha capped so ADD blend reads as
# a refined glass sheen rather than a chrome blowout.
LOGO_INTRO_TEXT_GLINT_DELAY_MS = 550
LOGO_INTRO_TEXT_GLINT_MS = 600
LOGO_INTRO_GLINT_COLOR = (255, 245, 220)
LOGO_INTRO_GLINT_PEAK_ALPHA = 170
LOGO_INTRO_TEXT_DRIFT_RATIO = 0.015
LOGO_INTRO_TEXT_DRIFT_MIN_PX = 3

_logo_intro_cache: dict[tuple[int, int], dict[str, object]] = {}


def _render_studio_text(diameter: int) -> tuple[pygame.Surface, pygame.Surface] | None:
    try:
        from font_config import load_font
    except Exception:
        return None
    try:
        if not pygame.font.get_init():
            pygame.font.init()
        size = max(14, int(diameter * LOGO_INTRO_TEXT_SIZE_RATIO))
        font = load_font(size, "bold")
        if font is None:
            return None
        # Base tinted text for the reveal + a white mask used by the glint pass.
        rendered = font.render(LOGO_INTRO_TEXT, True, LOGO_INTRO_TEXT_COLOR)
        rendered_hi = font.render(LOGO_INTRO_TEXT, True, (255, 255, 255))
        return rendered.convert_alpha(), rendered_hi.convert_alpha()
    except Exception:
        return None


def _build_glow(size: tuple[int, int]) -> pygame.Surface:
    width, height = size
    glow = pygame.Surface((width, height), pygame.SRCALPHA)
    center = (width // 2, height // 2)
    max_radius = max(width, height) // 2
    # Outer rings faint, inner rings stronger. Drawing largest-first lets each
    # successive inner circle overlay with higher alpha, producing a radial
    # bloom toward the logo disc.
    layers = 10
    for idx in range(layers):
        radius = max(10, max_radius - idx * max(6, max_radius // 16))
        alpha = min(90, 10 + idx * 10)
        pygame.draw.circle(glow, (*LOGO_INTRO_GLOW_COLOR, alpha), center, radius)
    return glow


def _slice_logo_wave_sheet(frame_size: tuple[int, int]) -> list[pygame.Surface]:
    sheet = pygame.image.load(resource_path(os.path.join("intro", "penguin_logo_wave.png"))).convert_alpha()
    frames: list[pygame.Surface] = []
    for index in range(LOGO_INTRO_FRAME_COUNT):
        col = index % LOGO_INTRO_COLS
        row = index // LOGO_INTRO_COLS
        rect = pygame.Rect(
            col * LOGO_INTRO_CELL_W,
            row * LOGO_INTRO_CELL_H,
            LOGO_INTRO_CELL_W,
            LOGO_INTRO_CELL_H,
        )
        frame = sheet.subsurface(rect).copy()
        if frame.get_size() != frame_size:
            frame = pygame.transform.smoothscale(frame, frame_size)
        frames.append(frame)
    return frames


def _build_logo_backdrop(diameter: int) -> pygame.Surface:
    surface = pygame.Surface((diameter, diameter), pygame.SRCALPHA)
    center = (diameter // 2, diameter // 2)
    outer_radius = max(1, diameter // 2 - 2)
    ring_thickness = max(12, int(diameter * 0.072))
    inner_radius = max(1, outer_radius - ring_thickness)

    pygame.draw.circle(surface, LOGO_INTRO_RING, center, outer_radius)
    pygame.draw.circle(surface, LOGO_INTRO_RED, center, inner_radius)

    # A subtle highlight keeps the ring from looking too flat after we
    # remove the baked-in static penguin from the original logo source.
    highlight = pygame.Surface((diameter, diameter), pygame.SRCALPHA)
    pygame.draw.circle(
        highlight,
        LOGO_INTRO_RING_HILITE,
        (center[0], max(0, int(diameter * 0.28))),
        max(8, int(diameter * 0.18)),
    )
    surface.blit(highlight, (0, 0))
    return surface


def _build_logo_layout(screen_size: tuple[int, int]) -> dict[str, object]:
    screen_w, screen_h = screen_size
    diameter = max(160, int(round(min(screen_w * 0.44, screen_h * 0.60))))
    scaled_logo_size = (diameter, diameter)
    scaled_logo = _build_logo_backdrop(diameter)
    pad_x = max(24, scaled_logo_size[0] // 12)
    pad_y = max(24, scaled_logo_size[1] // 12)
    local_w = scaled_logo_size[0] + pad_x * 2
    local_h = scaled_logo_size[1] + pad_y * 2
    logo_rect = scaled_logo.get_rect(center=(local_w // 2, local_h // 2))
    center_pos = ((screen_w - local_w) // 2, (screen_h - local_h) // 2)
    return {
        "scaled_logo": scaled_logo,
        "scaled_logo_size": scaled_logo_size,
        "local_size": (local_w, local_h),
        "logo_rect": logo_rect,
        "center_pos": center_pos,
    }


def _build_bootstrap_logo_frame(screen_size: tuple[int, int]) -> dict[str, object]:
    layout = _build_logo_layout(screen_size)
    local_w, local_h = layout["local_size"]
    glow = _build_glow((local_w, local_h))
    composite = pygame.Surface((local_w, local_h), pygame.SRCALPHA)
    composite.blit(glow, (0, 0))
    composite.blit(layout["scaled_logo"], layout["logo_rect"])
    return {
        "frame": composite,
        "pos": layout["center_pos"],
    }


def _build_glare_brush(height: int) -> pygame.Surface:
    width = int(height * 2.0)
    brush = pygame.Surface((width, height), pygame.SRCALPHA)
    slant = int(height * 0.5)
    for x in range(width):
        dist = abs(x - (width // 2))
        intensity = max(0.0, 1.0 - (dist / (width // 2)))
        intensity = intensity * intensity * (3 - 2 * intensity)
        alpha = int(LOGO_INTRO_GLINT_PEAK_ALPHA * intensity)
        if alpha > 0:
            pygame.draw.aaline(
                brush,
                (*LOGO_INTRO_GLINT_COLOR, alpha),
                (x, 0),
                (x - slant, height),
            )
    return brush


def _build_logo_intro_cache(screen_size: tuple[int, int]) -> dict[str, object]:
    layout = _build_logo_layout(screen_size)
    scaled_logo = layout["scaled_logo"]
    scaled_logo_size = layout["scaled_logo_size"]
    logo_rect = layout["logo_rect"]

    frame_scale = min(
        (scaled_logo_size[0] * 0.94) / LOGO_INTRO_CELL_W,
        (scaled_logo_size[1] * 0.94) / LOGO_INTRO_CELL_H,
    )
    frame_scale = max(0.1, frame_scale)
    scaled_frame_size = (
        max(1, int(round(LOGO_INTRO_CELL_W * frame_scale))),
        max(1, int(round(LOGO_INTRO_CELL_H * frame_scale))),
    )
    scaled_frames = _slice_logo_wave_sheet(scaled_frame_size)

    layout_w, layout_h = layout["local_size"]
    local_w = max(layout_w, scaled_frame_size[0] + max(24, scaled_logo_size[0] // 6))
    local_h = max(layout_h, scaled_frame_size[1] + max(24, scaled_logo_size[1] // 6))
    glow = _build_glow((local_w, local_h))

    composite_frames: list[pygame.Surface] = []
    for frame in scaled_frames:
        composite = pygame.Surface((local_w, local_h), pygame.SRCALPHA)
        composite.blit(glow, (0, 0))
        composite_logo_rect = scaled_logo.get_rect(center=(local_w // 2, local_h // 2))
        frame_rect = frame.get_rect(center=composite_logo_rect.center)
        composite.blit(scaled_logo, composite_logo_rect)
        composite.blit(frame, frame_rect)
        composite_frames.append(composite)

    center_pos = ((screen_size[0] - local_w) // 2, (screen_size[1] - local_h) // 2)

    diameter = scaled_logo_size[0]
    text_tuple = _render_studio_text(diameter)
    text_surface = None
    text_hi_surface = None
    text_pos: tuple[int, int] | None = None
    text_drift_px = 0
    glare_brush = None
    scratch_surface = None

    if text_tuple is not None:
        text_surface, text_hi_surface = text_tuple
        gap = max(LOGO_INTRO_TEXT_GAP_MIN_PX, int(diameter * LOGO_INTRO_TEXT_GAP_RATIO))
        text_top = center_pos[1] + local_h + gap
        text_left = (screen_size[0] - text_surface.get_width()) // 2
        text_pos = (text_left, text_top)
        text_drift_px = max(LOGO_INTRO_TEXT_DRIFT_MIN_PX, int(diameter * LOGO_INTRO_TEXT_DRIFT_RATIO))
        glare_brush = _build_glare_brush(text_hi_surface.get_height())
        scratch_surface = pygame.Surface(text_hi_surface.get_size(), pygame.SRCALPHA)

    return {
        "frames": composite_frames,
        "pos": center_pos,
        "text_surface": text_surface,
        "text_hi_surface": text_hi_surface,
        "text_pos": text_pos,
        "text_drift_px": text_drift_px,
        "glare_brush": glare_brush,
        "scratch_surface": scratch_surface,
    }


def _get_logo_intro_cache(screen_size: tuple[int, int]) -> dict[str, object]:
    cached = _logo_intro_cache.get(screen_size)
    if cached is None:
        cached = _build_logo_intro_cache(screen_size)
        _logo_intro_cache[screen_size] = cached
    return cached


def _start_logo_intro_sound() -> None:
    """로고 인트로 시작과 동시에 bgm/logo.wav를 1회 재생."""
    sound_path = resource_path(os.path.join("bgm", "logo.wav"))
    if not os.path.exists(sound_path):
        return
    try:
        if not pygame.mixer.get_init():
            try:
                pygame.mixer.pre_init(frequency=44100, size=-16, channels=2, buffer=512)
            except Exception:
                pass
            pygame.mixer.init()
        pygame.mixer.Sound(sound_path).play()
    except Exception as exc:
        print(f"[로고 인트로] 사운드 재생 실패: {exc}", flush=True)


def play_logo_intro(
    target_surface: pygame.Surface,
    *,
    surface_provider=None,
) -> None:
    """로고 인트로 재생.

    surface_provider: 선택적 callable. 주어지면 매 프레임 이를 호출해 현재
    렌더 타겟 Surface를 얻는다. F9/F10 등 재생 중 해상도/모드 전환으로 호출자
    쪽의 SCREEN 객체가 재생성되는 경우에 사용한다. 반환값이 None이면 지금
    보유한 타겟을 유지한다.
    """
    if not pygame.display.get_init():
        return

    def _current_surface(fallback: pygame.Surface) -> pygame.Surface:
        if surface_provider is None:
            return fallback
        try:
            s = surface_provider()
        except Exception:
            s = None
        return s if s is not None else fallback

    _start_logo_intro_sound()

    surface = _current_surface(target_surface)
    bootstrap = _build_bootstrap_logo_frame(surface.get_size())
    # Bootstrap must match the loop's starting scale so the scale-up entry
    # grows from a single continuous state (no pop between bootstrap and frame 0).
    bootstrap_frame = bootstrap["frame"]
    boot_orig_w, boot_orig_h = bootstrap_frame.get_size()
    boot_w = max(1, int(boot_orig_w * LOGO_INTRO_SCALE_IN_START))
    boot_h = max(1, int(boot_orig_h * LOGO_INTRO_SCALE_IN_START))
    bootstrap_scaled = pygame.transform.smoothscale(bootstrap_frame, (boot_w, boot_h))
    boot_pos_x = bootstrap["pos"][0] + (boot_orig_w - boot_w) // 2
    boot_pos_y = bootstrap["pos"][1] + (boot_orig_h - boot_h) // 2
    surface.fill(LOGO_INTRO_BG)
    surface.blit(bootstrap_scaled, (boot_pos_x, boot_pos_y))
    pygame.display.flip()
    pygame.event.pump()

    cached_size = surface.get_size()
    cache = _get_logo_intro_cache(cached_size)
    frames = cache["frames"]
    pos_x, pos_y = cache["pos"]
    text_surface = cache.get("text_surface")
    text_hi_surface = cache.get("text_hi_surface")
    glare_brush = cache.get("glare_brush")
    scratch_surface = cache.get("scratch_surface")
    text_pos = cache.get("text_pos")
    text_drift_px = int(cache.get("text_drift_px", 0) or 0)
    total_ms = LOGO_INTRO_TOTAL_ANIM_MS + LOGO_INTRO_FADE_OUT_MS
    clock = pygame.time.Clock()
    start_ms = pygame.time.get_ticks()

    try:
        while True:
            now_ms = pygame.time.get_ticks()
            elapsed_ms = now_ms - start_ms
            if elapsed_ms >= total_ms:
                break

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    raise SystemExit

            # 매 프레임 현재 렌더 타겟을 다시 구한다. 크기가 바뀌면 캐시 재빌드.
            surface = _current_surface(surface)
            current_size = surface.get_size()
            if current_size != cached_size:
                cache = _get_logo_intro_cache(current_size)
                frames = cache["frames"]
                pos_x, pos_y = cache["pos"]
                text_surface = cache.get("text_surface")
                text_hi_surface = cache.get("text_hi_surface")
                glare_brush = cache.get("glare_brush")
                scratch_surface = cache.get("scratch_surface")
                text_pos = cache.get("text_pos")
                text_drift_px = int(cache.get("text_drift_px", 0) or 0)
                cached_size = current_size

            if elapsed_ms < LOGO_INTRO_SCALE_IN_MS:
                # Cubic ease-out: grows fast, settles into full size.
                t = elapsed_ms / LOGO_INTRO_SCALE_IN_MS
                eased = 1.0 - (1.0 - t) ** 3
                scale = LOGO_INTRO_SCALE_IN_START + (1.0 - LOGO_INTRO_SCALE_IN_START) * eased
                alpha = 255
                frame_index = min(
                    LOGO_INTRO_FRAME_COUNT - 1,
                    int(elapsed_ms / max(1, (1000 / LOGO_INTRO_FPS))),
                )
            elif elapsed_ms < LOGO_INTRO_TOTAL_ANIM_MS:
                scale = 1.0
                alpha = 255
                frame_index = min(
                    LOGO_INTRO_FRAME_COUNT - 1,
                    int(elapsed_ms / max(1, (1000 / LOGO_INTRO_FPS))),
                )
            else:
                fade_elapsed_ms = elapsed_ms - LOGO_INTRO_TOTAL_ANIM_MS
                fade_t = min(1.0, fade_elapsed_ms / max(1, LOGO_INTRO_FADE_OUT_MS))
                # Smoothstep (Hermite) for a graceful fade-out at both ends.
                eased = fade_t * fade_t * (3.0 - 2.0 * fade_t)
                alpha = int(255 * (1.0 - eased))
                scale = 1.0
                frame_index = LOGO_INTRO_FRAME_COUNT - 1

            surface.fill(LOGO_INTRO_BG)
            frame = frames[frame_index]
            if scale < 1.0:
                orig_w, orig_h = frame.get_size()
                new_w = max(1, int(orig_w * scale))
                new_h = max(1, int(orig_h * scale))
                draw_frame = pygame.transform.smoothscale(frame, (new_w, new_h))
                draw_pos = (pos_x + (orig_w - new_w) // 2, pos_y + (orig_h - new_h) // 2)
            else:
                draw_frame = frame
                draw_pos = (pos_x, pos_y)
            draw_frame.set_alpha(max(0, min(255, alpha)))
            surface.blit(draw_frame, draw_pos)

            if text_surface is not None and text_pos is not None:
                # Glow reveal: text is invisible during scale-in, then fades in
                # via smoothstep while drifting upward into its final slot.
                if elapsed_ms < LOGO_INTRO_SCALE_IN_MS:
                    text_alpha_raw = 0
                    drift_offset = text_drift_px
                else:
                    reveal_t = min(
                        1.0,
                        (elapsed_ms - LOGO_INTRO_SCALE_IN_MS) / max(1, LOGO_INTRO_TEXT_REVEAL_MS),
                    )
                    eased_reveal = reveal_t * reveal_t * (3.0 - 2.0 * reveal_t)
                    text_alpha_raw = int(255 * eased_reveal)
                    drift_offset = int((1.0 - eased_reveal) * text_drift_px)
                # Sync fade-out with logo so both vanish together.
                text_alpha = max(0, min(text_alpha_raw, alpha))
                if text_alpha > 0:
                    text_surface.set_alpha(text_alpha)
                    draw_y = text_pos[1] + drift_offset
                    surface.blit(text_surface, (text_pos[0], draw_y))

                    # Glint reflection effect
                    if text_hi_surface is not None and glare_brush is not None and scratch_surface is not None:
                        glint_start_ms = LOGO_INTRO_SCALE_IN_MS + LOGO_INTRO_TEXT_GLINT_DELAY_MS
                        if glint_start_ms <= elapsed_ms < glint_start_ms + LOGO_INTRO_TEXT_GLINT_MS:
                            glint_progress = (elapsed_ms - glint_start_ms) / LOGO_INTRO_TEXT_GLINT_MS
                            text_w = text_surface.get_width()
                            brush_w = glare_brush.get_width()
                            sweep_x = int(-brush_w + glint_progress * (text_w + brush_w))

                            scratch_surface.fill((0, 0, 0, 0))
                            scratch_surface.blit(glare_brush, (sweep_x, 0))
                            text_hi_surface.set_alpha(text_alpha)
                            scratch_surface.blit(text_hi_surface, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                            surface.blit(scratch_surface, (text_pos[0], draw_y), special_flags=pygame.BLEND_RGB_ADD)

            pygame.display.flip()
            clock.tick(60)
    finally:
        _logo_intro_cache.clear()
