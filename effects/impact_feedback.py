"""Lightweight impact feedback bus for gameplay-facing visual reactions."""

from __future__ import annotations

from dataclasses import dataclass
import math
import random
import sys
from typing import Any

import pygame
import pygame.gfxdraw

from config.settings_system import get_settings_manager

# --- Surface Pool: 크기별 재사용 가능한 SRCALPHA Surface 캐시 ---
_surface_pool: dict[tuple[int, int], pygame.Surface] = {}


def _get_pooled_surface(w: int, h: int) -> pygame.Surface:
    """크기별 Surface를 캐시에서 가져오거나 새로 생성 (매 프레임 new 방지)"""
    key = (w, h)
    surf = _surface_pool.get(key)
    if surf is None:
        surf = pygame.Surface((w, h), pygame.SRCALPHA)
        _surface_pool[key] = surf
    else:
        surf.fill((0, 0, 0, 0))
    return surf


class ImpactEvent:
    BALL_HITS_BOSS = "ball_hits_boss"
    BALL_HITS_PLAYER = "ball_hits_player"
    BALL_HITS_PLAYER_STRONG = "ball_hits_player_strong"
    SCORE_PLAYER = "score_player"
    SCORE_BOSS = "score_boss"
    SKILL_CAST = "skill_cast"
    ITEM_TRIGGER = "item_trigger"


@dataclass
class _Particle:
    x: float
    y: float
    vx: float
    vy: float
    life: float
    max_life: float
    size: float
    color: tuple[int, int, int]


@dataclass
class _Pulse:
    kind: str
    life: float
    max_life: float
    color: tuple[int, int, int]
    intensity: float = 1.0
    pos: tuple[float, float] | None = None
    size: tuple[float, float] | None = None
    radius: float = 0.0
    attach: str | None = None
    meta: dict[str, Any] | None = None


_particles: list[_Particle] = []
_pulses: list[_Pulse] = []
_recent_event_keys: dict[tuple[Any, ...], int] = {}
_frame_emit_ticks: list[int] = []


def _settings():
    try:
        return get_settings_manager()
    except Exception:
        return None


def _enabled() -> bool:
    manager = _settings()
    if manager is None:
        return True
    return bool(manager.get_setting("gameplay", "impact_feedback", True))


def _reduce_motion() -> bool:
    manager = _settings()
    if manager is None:
        return False
    return bool(manager.get_setting("accessibility", "reduce_motion", False))


def _screen_shake_enabled() -> bool:
    manager = _settings()
    if manager is None:
        return True
    return bool(manager.get_setting("graphics", "screen_shake", True))


def _shake_scale() -> float:
    manager = _settings()
    if manager is None:
        return 1.0
    try:
        return max(0.0, float(manager.get_setting("gameplay", "camera_shake_intensity", 1.0)))
    except Exception:
        return 1.0


def _get_pingfighter_module():
    return sys.modules.get("pingfighter")


def _get_game_offset() -> tuple[int, int]:
    mod = _get_pingfighter_module()
    if mod is None:
        return 0, 0
    return (
        int(getattr(mod, "screen_shake_offset_x", 0)),
        int(getattr(mod, "screen_shake_offset_y", 0)),
    )


def _get_entity_rect(name: str) -> pygame.Rect | None:
    mod = _get_pingfighter_module()
    if mod is None:
        return None
    rect = getattr(mod, name, None)
    if not isinstance(rect, pygame.Rect):
        return None
    result = rect.copy()
    offset_x, offset_y = _get_game_offset()
    result.x += offset_x
    result.y += offset_y
    return result


def _default_pos_for_event(event: str) -> tuple[float, float] | None:
    if event in (
        ImpactEvent.BALL_HITS_PLAYER,
        ImpactEvent.BALL_HITS_PLAYER_STRONG,
        ImpactEvent.SKILL_CAST,
        ImpactEvent.ITEM_TRIGGER,
    ):
        rect = _get_entity_rect("PLAYER")
    elif event == ImpactEvent.BALL_HITS_BOSS:
        rect = _get_entity_rect("BOSS")
    else:
        rect = None
    if rect is None:
        return None
    return float(rect.centerx), float(rect.centery)


def _clamp_color(color: tuple[int, int, int] | None, fallback: tuple[int, int, int]) -> tuple[int, int, int]:
    if color is None:
        return fallback
    return tuple(max(0, min(255, int(channel))) for channel in color)


def _default_color(event: str, meta: dict[str, Any] | None) -> tuple[int, int, int]:
    meta = meta or {}
    if event == ImpactEvent.BALL_HITS_BOSS:
        return _clamp_color(meta.get("color"), (245, 248, 255))
    if event == ImpactEvent.BALL_HITS_PLAYER:
        return (245, 248, 255)
    if event == ImpactEvent.BALL_HITS_PLAYER_STRONG:
        return (255, 220, 120)
    if event == ImpactEvent.SCORE_PLAYER:
        return (255, 220, 80)
    if event == ImpactEvent.SCORE_BOSS:
        return (220, 40, 40)
    if event == ImpactEvent.SKILL_CAST:
        character = str(meta.get("character", "")).lower()
        if character == "smasher":
            return (255, 135, 60)
        if character == "viper":
            return (185, 110, 255)
        if character == "blacksmith":
            return (255, 170, 70)
        return _clamp_color(meta.get("color"), (120, 220, 255))
    if event == ImpactEvent.ITEM_TRIGGER:
        return _clamp_color(meta.get("color"), (255, 225, 120))
    return (255, 255, 255)


def _dedupe_window_ms(event: str) -> int:
    if event in (ImpactEvent.BALL_HITS_PLAYER, ImpactEvent.BALL_HITS_PLAYER_STRONG, ImpactEvent.BALL_HITS_BOSS):
        return 24
    return 10


def _make_dedupe_key(event: str, pos: tuple[float, float] | None, meta: dict[str, Any] | None) -> tuple[Any, ...]:
    meta = meta or {}
    custom = meta.get("dedupe_key")
    if custom is not None:
        return event, custom
    if pos is None:
        return event, meta.get("character"), meta.get("skill_name"), meta.get("item_name")
    return event, int(pos[0] // 16), int(pos[1] // 16), meta.get("character"), meta.get("skill_name"), meta.get("item_name")


def _can_emit_this_frame(ticks: int) -> bool:
    _frame_emit_ticks[:] = [emit_tick for emit_tick in _frame_emit_ticks if ticks - emit_tick <= 16]
    if len(_frame_emit_ticks) >= 3:
        return False
    _frame_emit_ticks.append(ticks)
    return True


def _spawn_burst(
    pos: tuple[float, float],
    color: tuple[int, int, int],
    *,
    count: int,
    speed_min: float,
    speed_max: float,
    size_min: float,
    size_max: float,
    life_min: float,
    life_max: float,
) -> None:
    if count <= 0:
        return
    for _ in range(count):
        angle = random.uniform(0.0, math.tau)
        speed = random.uniform(speed_min, speed_max)
        life = random.uniform(life_min, life_max)
        _particles.append(
            _Particle(
                x=pos[0],
                y=pos[1],
                vx=math.cos(angle) * speed,
                vy=math.sin(angle) * speed,
                life=life,
                max_life=life,
                size=random.uniform(size_min, size_max),
                color=color,
            )
        )


def _add_pulse(**kwargs: Any) -> None:
    _pulses.append(_Pulse(**kwargs))


def _add_ring_pulse(
    pos: tuple[float, float],
    color: tuple[int, int, int],
    *,
    life: float,
    intensity: float,
    start_radius: float,
    end_radius: float,
    alpha: int,
    start_width: float = 3.0,
    end_width: float = 1.0,
) -> None:
    _add_pulse(
        kind="ring",
        life=life,
        max_life=life,
        color=color,
        intensity=intensity,
        pos=pos,
        radius=end_radius,
        meta={
            "start_radius": float(start_radius),
            "end_radius": float(end_radius),
            "start_width": float(start_width),
            "end_width": float(end_width),
            "alpha": max(0, min(255, int(alpha))),
        },
    )


def _apply_shake(frames: int, intensity: float) -> None:
    if frames <= 0 or intensity <= 0 or _reduce_motion() or not _screen_shake_enabled():
        return
    mod = _get_pingfighter_module()
    if mod is None:
        return
    scaled_intensity = max(0.0, intensity * _shake_scale())
    if scaled_intensity <= 0:
        return
    current_frames = int(getattr(mod, "screen_shake_timer", 0))
    current_intensity = int(getattr(mod, "screen_shake_intensity", 0) or 0)
    new_intensity = max(1, int(round(scaled_intensity)))
    setattr(mod, "screen_shake_timer", max(current_frames, int(frames)))
    setattr(mod, "screen_shake_intensity", max(current_intensity, new_intensity))


def _draw_particle(screen: pygame.Surface, particle: _Particle) -> None:
    """파티클 그리기 - gfxdraw 직접 렌더링 (Surface 생성 제거)"""
    life_ratio = max(0.0, particle.life / max(0.001, particle.max_life))
    alpha = int(255 * life_ratio)
    radius = max(1, int(particle.size))
    if alpha <= 0:
        return
    offset_x, offset_y = _get_game_offset()
    px = int(particle.x + offset_x)
    py = int(particle.y + offset_y)
    r, g, b = particle.color
    pygame.gfxdraw.filled_circle(screen, px, py, radius, (r, g, b, alpha))


def _draw_band(screen: pygame.Surface, pulse: _Pulse) -> None:
    """밴드 이펙트 - Surface 풀 사용"""
    width = screen.get_width()
    band_height = int(pulse.size[1] if pulse.size else 60)
    height = screen.get_height()
    y = 0 if pulse.meta and pulse.meta.get("edge") == "top" else height - band_height
    progress = 1.0 - (pulse.life / max(0.001, pulse.max_life))
    alpha = int((1.0 - progress) * 150)
    overlay = _get_pooled_surface(width, band_height)
    for idx in range(band_height):
        falloff = 1.0 - (idx / max(1, band_height - 1))
        pygame.draw.line(
            overlay,
            (*pulse.color, int(alpha * falloff)),
            (0, idx),
            (width, idx),
        )
    screen.blit(overlay, (0, y))


def _draw_ring(screen: pygame.Surface, pulse: _Pulse) -> None:
    """링 펄스 - gfxdraw 직접 렌더링 (Surface 생성 제거)"""
    if pulse.pos is None:
        return
    progress = 1.0 - (pulse.life / max(0.001, pulse.max_life))
    radius = max(4, int(pulse.radius * (0.4 + progress * 0.8)))
    alpha = int((1.0 - progress) * 160)
    if alpha <= 0 or radius <= 0:
        return
    offset_x, offset_y = _get_game_offset()
    cx = int(pulse.pos[0] + offset_x)
    cy = int(pulse.pos[1] + offset_y)
    r, g, b = pulse.color
    pygame.gfxdraw.aacircle(screen, cx, cy, radius, (r, g, b, alpha))


def _draw_shock_ring(screen: pygame.Surface, pulse: _Pulse) -> None:
    """Render a lightweight expanding ring with tapering line width."""
    if pulse.pos is None:
        return
    meta = pulse.meta or {}
    progress = 1.0 - (pulse.life / max(0.001, pulse.max_life))
    start_radius = float(meta.get("start_radius", max(4.0, pulse.radius * 0.4)))
    end_radius = float(meta.get("end_radius", max(start_radius + 1.0, pulse.radius)))
    radius = max(2, int(round(start_radius + (end_radius - start_radius) * progress)))
    start_width = float(meta.get("start_width", 2.0))
    end_width = float(meta.get("end_width", 1.0))
    ring_width = max(1, int(round(start_width + (end_width - start_width) * progress)))
    alpha = int((1.0 - progress) * float(meta.get("alpha", 160)))
    if alpha <= 0 or radius <= 0:
        return

    offset_x, offset_y = _get_game_offset()
    cx = int(pulse.pos[0] + offset_x)
    cy = int(pulse.pos[1] + offset_y)
    overlay_pad = ring_width + 6
    overlay_size = radius * 2 + overlay_pad * 2 + 2
    overlay = _get_pooled_surface(overlay_size, overlay_size)
    center = overlay_size // 2
    glow_alpha = max(0, alpha // 3)
    if glow_alpha > 0:
        pygame.draw.circle(
            overlay,
            (*pulse.color, glow_alpha),
            (center, center),
            radius + 1,
            min(radius, ring_width + 2),
        )
    pygame.draw.circle(
        overlay,
        (*pulse.color, alpha),
        (center, center),
        radius,
        min(radius, ring_width),
    )
    screen.blit(overlay, (cx - center, cy - center))


def _draw_paddle_pulse(screen: pygame.Surface, pulse: _Pulse) -> None:
    """패들 펄스 - Surface 풀 사용"""
    rect = _get_entity_rect("PLAYER" if pulse.attach == "player" else "BOSS")
    if rect is None:
        return
    progress = 1.0 - (pulse.life / max(0.001, pulse.max_life))
    inflate = int((2 + 4 * progress) * pulse.intensity)
    alpha = int((1.0 - progress) * 150)
    outline = rect.inflate(inflate * 2, inflate * 2)
    surface = _get_pooled_surface(outline.width + 8, outline.height + 8)
    draw_rect = pygame.Rect(4, 4, outline.width, outline.height)
    pygame.draw.rect(surface, (*pulse.color, alpha), draw_rect, max(1, int(2 + pulse.intensity)), border_radius=6)
    screen.blit(surface, (outline.x - 4, outline.y - 4))


def _draw_slash(screen: pygame.Surface, pulse: _Pulse) -> None:
    """슬래시 이펙트 - Surface 풀 사용"""
    progress = 1.0 - (pulse.life / max(0.001, pulse.max_life))
    alpha = int((1.0 - progress) * 180)
    rect = _get_entity_rect("PLAYER")
    if rect is None:
        return
    slash_width = max(rect.width + 18, 36)
    slash_height = max(8, int(8 * pulse.intensity))
    overlay = _get_pooled_surface(slash_width, slash_height * 3)
    center_y = overlay.get_height() // 2
    for idx in range(slash_height):
        falloff = 1.0 - idx / max(1, slash_height)
        line_alpha = int(alpha * falloff)
        pygame.draw.line(
            overlay,
            (*pulse.color, line_alpha),
            (0, center_y - idx),
            (slash_width, center_y - idx),
            1,
        )
        pygame.draw.line(
            overlay,
            (*pulse.color, line_alpha),
            (0, center_y + idx),
            (slash_width, center_y + idx),
            1,
        )
    screen.blit(overlay, (rect.centerx - slash_width // 2, rect.centery - overlay.get_height() // 2))


def fire(
    event: str,
    *,
    pos: tuple[float, float] | None = None,
    intensity: float = 1.0,
    color: tuple[int, int, int] | None = None,
    meta: dict[str, Any] | None = None,
) -> None:
    """Queue a gameplay-facing impact feedback event."""
    if not _enabled():
        return

    ticks = pygame.time.get_ticks()
    pos = pos or _default_pos_for_event(event)
    meta = dict(meta or {})
    event_color = _clamp_color(color, _default_color(event, meta))
    dedupe_key = _make_dedupe_key(event, pos, meta)
    last_tick = _recent_event_keys.get(dedupe_key, -99999)
    if ticks - last_tick <= _dedupe_window_ms(event):
        return

    if not _can_emit_this_frame(ticks):
        return

    _recent_event_keys[dedupe_key] = ticks
    intensity = max(0.2, min(2.0, float(intensity)))
    motion_scale = 0.33 if _reduce_motion() else 1.0

    if event == ImpactEvent.BALL_HITS_BOSS and pos is not None:
        burst_count = max(2, int((6 + intensity * 2.4) * motion_scale))
        _spawn_burst(
            pos,
            event_color,
            count=burst_count,
            speed_min=80.0,
            speed_max=180.0,
            size_min=1.6,
            size_max=2.8,
            life_min=0.10,
            life_max=0.20,
        )
        _add_ring_pulse(
            pos,
            event_color,
            life=0.24,
            intensity=intensity,
            start_radius=7.0,
            end_radius=28.0 + intensity * 6.0,
            alpha=140,
        )
        return

    if event == ImpactEvent.BALL_HITS_PLAYER:
        if pos is not None:
            _spawn_burst(
                pos,
                event_color,
                count=max(2, int(5 * motion_scale)),
                speed_min=70.0,
                speed_max=150.0,
                size_min=1.4,
                size_max=2.4,
                life_min=0.10,
                life_max=0.18,
            )
            _add_ring_pulse(
                pos,
                event_color,
                life=0.24,
                intensity=1.2,
                start_radius=7.0,
                end_radius=28.0,
                alpha=140,
            )
        return

    if event == ImpactEvent.BALL_HITS_PLAYER_STRONG:
        if pos is not None:
            _add_ring_pulse(
                pos,
                event_color,
                life=0.32,
                intensity=1.6,
                start_radius=8.0,
                end_radius=60.0,
                alpha=200,
                start_width=4.0,
            )
            _spawn_burst(
                pos,
                event_color,
                count=max(4, int(14 * motion_scale)),
                speed_min=110.0,
                speed_max=240.0,
                size_min=2.0,
                size_max=3.6,
                life_min=0.14,
                life_max=0.28,
            )
        _apply_shake(max(4, int(6 + intensity * 3)), 5.0 + intensity * 3.0)
        return

    if event == ImpactEvent.SCORE_PLAYER:
        _add_pulse(
            kind="band",
            life=0.40,
            max_life=0.40,
            color=event_color,
            intensity=intensity,
            size=(0.0, 60.0),
            meta={"edge": "top"},
        )
        return

    if event == ImpactEvent.SCORE_BOSS:
        _add_pulse(
            kind="band",
            life=0.40,
            max_life=0.40,
            color=event_color,
            intensity=intensity,
            size=(0.0, 60.0),
            meta={"edge": "bottom"},
        )
        _apply_shake(2, 2.0)
        return

    if event == ImpactEvent.SKILL_CAST:
        if pos is not None:
            _add_pulse(kind="ring", life=0.25, max_life=0.25, color=event_color, intensity=intensity, pos=pos, radius=26 + intensity * 10)
        return

    if event == ImpactEvent.ITEM_TRIGGER:
        _add_pulse(kind="slash", life=0.20, max_life=0.20, color=event_color, intensity=intensity, attach="player")


def update(dt: float) -> None:
    """Advance impact feedback animations."""
    if dt <= 0:
        dt = 1.0 / 60.0

    if _recent_event_keys:
        now_tick = pygame.time.get_ticks()
        stale_before = now_tick - 120
        stale_keys = [key for key, tick in _recent_event_keys.items() if tick < stale_before]
        for key in stale_keys:
            _recent_event_keys.pop(key, None)

    for particle in _particles[:]:
        particle.life -= dt
        if particle.life <= 0:
            _particles.remove(particle)
            continue
        particle.x += particle.vx * dt
        particle.y += particle.vy * dt
        particle.vx *= 0.92
        particle.vy *= 0.92

    for pulse in _pulses[:]:
        pulse.life -= dt
        if pulse.life <= 0:
            _pulses.remove(pulse)


def draw(screen: pygame.Surface) -> None:
    """Render active impact feedback layers."""
    if not _enabled():
        return

    for particle in _particles:
        _draw_particle(screen, particle)

    for pulse in _pulses:
        if pulse.kind == "band":
            _draw_band(screen, pulse)
        elif pulse.kind == "ring":
            _draw_shock_ring(screen, pulse)
        elif pulse.kind == "paddle":
            _draw_paddle_pulse(screen, pulse)
        elif pulse.kind == "slash":
            _draw_slash(screen, pulse)


def clear() -> None:
    """Drop all active feedback state."""
    _particles.clear()
    _pulses.clear()
    _recent_event_keys.clear()
    _frame_emit_ticks.clear()
