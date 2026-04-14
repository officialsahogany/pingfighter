"""CPU post-process manager for final game-frame effects."""

from __future__ import annotations

from typing import Callable

import pygame


BudgetGetter = Callable[[], str]


class PostProcessManager:
    """Owns lightweight post-process state and future effect scratch buffers."""

    _VIGNETTE_ALPHA_BY_LEVEL = {
        "normal": 0,
        "warning": 0,
        "critical": 0,
    }
    _HIT_FLASH_ALPHA_MULTIPLIER_BY_LEVEL = {
        "normal": 1.0,
        "warning": 0.9,
        "critical": 0.75,
    }

    def __init__(self) -> None:
        self.enabled = True
        self.debug_bypass = False
        self.disabled_for_session = False
        self.width = 0
        self.height = 0
        self._budget_getter: BudgetGetter | None = None
        self._last_budget_level = "normal"
        self._consecutive_failures = 0
        self._failure_logged = False

        # Future effect state placeholders.
        self._vignette_strength = 1.0
        self._hit_flash = None
        self._hit_flash_start_ms = 0
        self._hit_flash_end_ms = 0
        self._chromatic_pulse_end_ms = 0
        self._scratch_a: pygame.Surface | None = None
        self._scratch_b: pygame.Surface | None = None
        self._vignette_cache: dict[tuple[int, int, int], pygame.Surface] = {}

    def set_enabled(self, enabled: bool) -> None:
        self.enabled = bool(enabled)

    def set_budget_getter(self, getter: BudgetGetter | None) -> None:
        self._budget_getter = getter

    def resize(self, width: int, height: int) -> None:
        width = max(1, int(width))
        height = max(1, int(height))
        if (width, height) == (self.width, self.height):
            return
        self.width = width
        self.height = height
        self._scratch_a = None
        self._scratch_b = None
        self._vignette_cache.clear()

    def toggle_debug_bypass(self) -> bool:
        self.debug_bypass = not self.debug_bypass
        return self.debug_bypass

    def set_vignette_strength(self, strength: float) -> None:
        self._vignette_strength = max(0.0, min(float(strength), 1.0))

    def trigger_hit_flash(
        self,
        color: tuple[int, int, int] = (255, 255, 255),
        alpha: int = 0,
        duration_ms: int = 0,
    ) -> None:
        alpha = max(0, min(int(alpha), 255))
        duration_ms = max(0, int(duration_ms))
        if alpha <= 0 or duration_ms <= 0:
            self._clear_hit_flash()
            return

        now_ms = pygame.time.get_ticks()
        self._hit_flash = {
            "color": tuple(int(max(0, min(255, c))) for c in color[:3]),
            "alpha": alpha,
            "duration_ms": duration_ms,
        }
        self._hit_flash_start_ms = now_ms
        self._hit_flash_end_ms = now_ms + duration_ms

    def trigger_chromatic_pulse(self, offset_px: int = 0, duration_ms: int = 0) -> None:
        duration_ms = max(0, int(duration_ms))
        self._chromatic_pulse_end_ms = pygame.time.get_ticks() + duration_ms

    def apply(self, surface: pygame.Surface | None) -> pygame.Surface | None:
        if surface is None:
            return surface
        if not self.enabled or self.debug_bypass or self.disabled_for_session:
            return surface

        try:
            if surface.get_size() != (self.width, self.height):
                self.resize(*surface.get_size())

            self._last_budget_level = self._get_budget_level()
            self._consecutive_failures = 0

            result_surface = surface
            now_ms = pygame.time.get_ticks()

            vignette_alpha = self._get_vignette_alpha()
            if vignette_alpha > 0:
                result_surface = self._apply_vignette(result_surface, vignette_alpha)

            hit_flash_state = self._get_hit_flash_state(now_ms)
            if hit_flash_state is not None:
                color, alpha = hit_flash_state
                result_surface = self._apply_hit_flash(result_surface, color, alpha)

            return result_surface
        except Exception as exc:
            self._handle_failure(exc)
            return surface

    def _get_budget_level(self) -> str:
        if self._budget_getter is None:
            return "normal"
        try:
            return str(self._budget_getter())
        except Exception:
            return "normal"

    def _get_vignette_alpha(self) -> int:
        if self.width <= 0 or self.height <= 0:
            return 0
        if self._vignette_strength <= 0.0:
            return 0

        base_alpha = self._VIGNETTE_ALPHA_BY_LEVEL.get(self._last_budget_level, 0)
        if base_alpha <= 0:
            return 0

        return max(0, min(255, int(round(base_alpha * self._vignette_strength))))

    def _apply_vignette(self, surface: pygame.Surface, alpha: int) -> pygame.Surface:
        scratch = self._get_scratch_surface(surface)
        scratch.fill((0, 0, 0, 0))
        scratch.blit(surface, (0, 0))
        scratch.blit(self._get_vignette_surface(alpha), (0, 0))
        return scratch

    def _get_hit_flash_state(
        self, now_ms: int
    ) -> tuple[tuple[int, int, int], int] | None:
        if self._hit_flash is None:
            return None

        duration_ms = max(1, int(self._hit_flash["duration_ms"]))
        elapsed_ms = max(0, now_ms - self._hit_flash_start_ms)
        if elapsed_ms >= duration_ms or self._hit_flash_end_ms <= now_ms:
            self._clear_hit_flash()
            return None

        remaining_ratio = max(0.0, min(1.0, 1.0 - (elapsed_ms / duration_ms)))
        budget_multiplier = self._HIT_FLASH_ALPHA_MULTIPLIER_BY_LEVEL.get(
            self._last_budget_level, 1.0
        )
        effective_alpha = int(
            round(self._hit_flash["alpha"] * remaining_ratio * budget_multiplier)
        )
        if effective_alpha <= 0:
            return None

        return self._hit_flash["color"], effective_alpha

    def _apply_hit_flash(
        self, surface: pygame.Surface, color: tuple[int, int, int], alpha: int
    ) -> pygame.Surface:
        scratch = self._get_scratch_surface(surface)
        scratch.fill((0, 0, 0, 0))
        scratch.blit(surface, (0, 0))
        additive_color = tuple(
            max(0, min(255, int(channel * (alpha / 255.0)))) for channel in color
        )
        scratch.fill((*additive_color, 0), special_flags=pygame.BLEND_RGB_ADD)
        return scratch

    def _get_scratch_surface(
        self, source_surface: pygame.Surface | None = None
    ) -> pygame.Surface:
        if self._scratch_a is None or self._scratch_a.get_size() != (
            self.width,
            self.height,
        ):
            self._scratch_a = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        if self._scratch_b is None or self._scratch_b.get_size() != (
            self.width,
            self.height,
        ):
            self._scratch_b = pygame.Surface((self.width, self.height), pygame.SRCALPHA)

        if source_surface is self._scratch_a:
            return self._scratch_b
        return self._scratch_a

    def _get_vignette_surface(self, alpha: int) -> pygame.Surface:
        cache_key = (self.width, self.height, int(alpha))
        cached = self._vignette_cache.get(cache_key)
        if cached is not None:
            return cached

        vignette = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        edge_span = max(40, min(self.width, self.height) // 5)
        corner_radius = max(12, min(self.width, self.height) // 6)

        for layer in range(edge_span):
            inset = layer
            rect = pygame.Rect(
                inset,
                inset,
                self.width - inset * 2,
                self.height - inset * 2,
            )
            if rect.width <= 2 or rect.height <= 2:
                break

            t = layer / max(1, edge_span - 1)
            layer_alpha = int(alpha * ((1.0 - t) ** 2.2))
            if layer_alpha <= 0:
                continue

            layer_radius = max(0, corner_radius - inset)
            pygame.draw.rect(
                vignette,
                (0, 0, 0, layer_alpha),
                rect,
                width=1,
                border_radius=layer_radius,
            )

        self._vignette_cache[cache_key] = vignette
        return vignette

    def _clear_hit_flash(self) -> None:
        self._hit_flash = None
        self._hit_flash_start_ms = 0
        self._hit_flash_end_ms = 0

    def _handle_failure(self, exc: Exception) -> None:
        self._consecutive_failures += 1
        if self._consecutive_failures < 3 or self._failure_logged:
            return

        self.disabled_for_session = True
        self._failure_logged = True
        print(f"[PostProcess] Disabled for this session after repeated failures: {exc}", flush=True)


_postprocess_manager: PostProcessManager | None = None


def get_postprocess_manager() -> PostProcessManager:
    global _postprocess_manager
    if _postprocess_manager is None:
        _postprocess_manager = PostProcessManager()
    return _postprocess_manager


def apply_postprocess(surface: pygame.Surface | None) -> pygame.Surface | None:
    return get_postprocess_manager().apply(surface)


def trigger_hit_flash(
    color: tuple[int, int, int] = (255, 255, 255),
    alpha: int = 0,
    duration_ms: int = 0,
) -> None:
    get_postprocess_manager().trigger_hit_flash(color=color, alpha=alpha, duration_ms=duration_ms)


def trigger_chromatic_pulse(offset_px: int = 0, duration_ms: int = 0) -> None:
    get_postprocess_manager().trigger_chromatic_pulse(offset_px=offset_px, duration_ms=duration_ms)


def set_vignette_strength(strength: float) -> None:
    get_postprocess_manager().set_vignette_strength(strength)


def toggle_postprocess_bypass() -> bool:
    return get_postprocess_manager().toggle_debug_bypass()
