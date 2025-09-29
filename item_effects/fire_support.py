from __future__ import annotations

import random
from dataclasses import dataclass
from typing import Callable, List, Optional
import sys

import pygame


@dataclass
class Bomb:
    """내부 폭탄 상태를 추적."""

    x: float
    y: float
    vx: float
    vy: float
    gravity: float
    target_y: float
    life: int = 240


class FireSupportAircraft:
    """화력지원 호출 시 등장하는 폭격기."""

    def __init__(
        self,
        screen_width: int,
        screen_height: int,
        cruise_y: Optional[float] = None,
        engine_sound: Optional[pygame.mixer.Sound] = None,
        direction: str = "left_to_right",
    ) -> None:
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.width = 148
        self.height = 40
        self.direction = direction
        supply_altitude = _get_supply_aircraft_altitude()
        desired_y = cruise_y if cruise_y is not None else supply_altitude
        lower_bound = 20
        upper_bound = self.screen_height - self.height - 20
        self.y = max(lower_bound, min(upper_bound, desired_y))
        if self.direction == "right_to_left":
            self.x = self.screen_width + self.width
            self.speed = -1.8
        else:
            self.direction = "left_to_right"
            self.x = -self.width
            self.speed = 1.8
        self.active = True
        self.crashing = False
        self.spawn_timer = 0
        self.invulnerable_frames = 45
        self.crash_velocity_y = 0.4
        self.crash_gravity = 0.18
        self.engine_sound = engine_sound
        self.sound_channel: Optional[pygame.mixer.Channel] = None
        self.flame_particles: list[dict[str, float]] = []
        if self.engine_sound is not None:
            try:
                self.sound_channel = self.engine_sound.play(-1)
                if self.sound_channel:
                    self.sound_channel.set_volume(0.6)
            except Exception:  # noqa: BLE001
                self.sound_channel = None

    def get_rect(self) -> pygame.Rect:
        return pygame.Rect(int(self.x), int(self.y), self.width, self.height)

    def update(self, ball_rect: Optional[pygame.Rect], last_hit_by: Optional[str]) -> dict:
        if not self.active:
            self._update_flame_particles()
            return {"finished": True}

        self.spawn_timer += 1
        events: dict = {}

        if not self.crashing:
            self.x += self.speed
            # 폭격기는 공에 맞아도 추락하지 않는다
            if self.direction == "left_to_right" and self.x > self.screen_width + self.width:
                self.active = False
                events["finished"] = True
            elif self.direction == "right_to_left" and self.x < -self.width:
                self.active = False
                events["finished"] = True
            self._spawn_flame_particles(count=2)
        else:
            self.x += self.speed * 0.35
            self.crash_velocity_y = min(self.crash_velocity_y + self.crash_gravity, 6)
            self.y += self.crash_velocity_y
            if self.y >= self.screen_height - 96:
                self.active = False
                events["crash_landed"] = True
            self._spawn_flame_particles(count=1)

        self._update_flame_particles()

        if not self.active:
            self.stop_sound()

        return events

    def can_drop(self) -> bool:
        return self.active and not self.crashing and self.spawn_timer >= self.invulnerable_frames

    def drop_anchor(self, center_y: float) -> tuple[float, float]:
        drop_x = self.x + self.width * 0.3
        drop_y = center_y + random.uniform(-40, 40)
        return drop_x, drop_y

    def draw(self, surface: pygame.Surface) -> None:
        if not self.active and not self.crashing and not self.flame_particles:
            return

        for particle in self.flame_particles:
            ratio = particle["life"] / particle["max_life"] if particle["max_life"] else 0
            outer_color = (
                int(120 + 135 * ratio),
                int(60 + 110 * ratio),
                int(30 + 70 * ratio),
            )
            inner_color = (
                255,
                int(200 * ratio + 40),
                int(120 * ratio + 20),
            )
            center = (int(particle["x"]), int(particle["y"]))
            outer_radius = max(1, int(particle["radius"]))
            inner_radius = max(1, int(particle["radius"] * 0.55))
            pygame.draw.circle(surface, outer_color, center, outer_radius)
            pygame.draw.circle(surface, inner_color, center, inner_radius)

        if not self.active and not self.crashing:
            return

        base_x = self.x
        base_y = self.y
        w = self.width
        h = self.height

        body_points = [
            self._to_screen_point(base_x, base_y, w, h, 0.00, 0.50),
            self._to_screen_point(base_x, base_y, w, h, 0.06, 0.20),
            self._to_screen_point(base_x, base_y, w, h, 0.18, 0.08),
            self._to_screen_point(base_x, base_y, w, h, 0.40, 0.03),
            self._to_screen_point(base_x, base_y, w, h, 0.70, 0.20),
            self._to_screen_point(base_x, base_y, w, h, 0.92, 0.50),
            self._to_screen_point(base_x, base_y, w, h, 0.70, 0.80),
            self._to_screen_point(base_x, base_y, w, h, 0.40, 0.97),
            self._to_screen_point(base_x, base_y, w, h, 0.18, 0.85),
            self._to_screen_point(base_x, base_y, w, h, 0.06, 0.60),
        ]

        main_color = (38, 46, 58) if not self.crashing else (96, 70, 50)
        outline_color = (18, 24, 32)
        highlight_color = (64, 78, 98)

        pygame.draw.polygon(surface, main_color, body_points)
        pygame.draw.lines(surface, outline_color, True, body_points, 2)

        leading_edge = [
            self._to_screen_point(base_x, base_y, w, h, 0.06, 0.20),
            self._to_screen_point(base_x, base_y, w, h, 0.18, 0.08),
            self._to_screen_point(base_x, base_y, w, h, 0.40, 0.03),
            self._to_screen_point(base_x, base_y, w, h, 0.70, 0.20),
        ]
        pygame.draw.lines(surface, highlight_color, False, leading_edge, 3)

        cockpit_width = int(w * 0.18)
        cockpit_height = int(h * 0.32)
        cockpit_center_x = self._ratio_to_x(base_x, w, 0.68)
        cockpit_rect = pygame.Rect(
            int(cockpit_center_x - cockpit_width / 2),
            int(base_y + h * 0.32),
            cockpit_width,
            cockpit_height,
        )
        pygame.draw.ellipse(surface, (90, 120, 150), cockpit_rect)
        pygame.draw.ellipse(surface, outline_color, cockpit_rect, 2)

        inlet_width = int(w * 0.12)
        inlet_height = int(h * 0.14)
        inlet_top = int(base_y + h * 0.40)
        left_inlet_rect = pygame.Rect(
            int(self._ratio_to_x(base_x, w, 0.36) - inlet_width / 2),
            inlet_top,
            inlet_width,
            inlet_height,
        )
        right_inlet_rect = pygame.Rect(
            int(self._ratio_to_x(base_x, w, 0.52) - inlet_width / 2),
            inlet_top,
            inlet_width,
            inlet_height,
        )
        for inlet in (left_inlet_rect, right_inlet_rect):
            pygame.draw.rect(surface, (52, 62, 80), inlet, border_radius=3)
            pygame.draw.rect(surface, outline_color, inlet, 1, border_radius=3)

        tail_line = [
            self._to_screen_point(base_x, base_y, w, h, 0.06, 0.60),
            self._to_screen_point(base_x, base_y, w, h, 0.18, 0.85),
            self._to_screen_point(base_x, base_y, w, h, 0.40, 0.97),
            self._to_screen_point(base_x, base_y, w, h, 0.70, 0.80),
            self._to_screen_point(base_x, base_y, w, h, 0.92, 0.50),
        ]
        pygame.draw.lines(surface, (24, 30, 40), False, tail_line, 2)

    def stop_sound(self) -> None:
        if self.sound_channel:
            try:
                self.sound_channel.stop()
            except Exception:  # noqa: BLE001
                pass
            self.sound_channel = None


class FireSupport:
    """병사 화력지원 무기."""

    CALL_LOCK_FRAMES = 30
    MIN_DELAY_FRAMES = 120
    MAX_DELAY_FRAMES = 180
    BOMB_INTERVAL_FRAMES = 60
    BOMB_MIN_COUNT = 5
    BOMB_MAX_COUNT = 7
    BOMB_GRAVITY = 0.35
    BOMB_INITIAL_VY = 2.0
    BOMB_HORIZONTAL_JITTER = 1.1
    MAX_AMMO = 1

    def __init__(self) -> None:
        self.equipped = False
        self.ammo_count = 0
        self.strike_active = False
        self.calling = False
        self.call_timer = 0
        self.delay_timer = 0
        self.bombs_remaining = 0
        self.bomb_cooldown = 0
        self.bombs: List[Bomb] = []
        self.aircraft: Optional[FireSupportAircraft] = None
        self.screen_width = 0
        self.screen_height = 0
        self.finished = False
        self.radio_active = False
        self.last_bomb_y = 0.0
        self.max_ammo = self.MAX_AMMO

    def reset_state(self) -> None:
        self.strike_active = False
        self.calling = False
        self.call_timer = 0
        self.delay_timer = 0
        self.bombs_remaining = 0
        self.bomb_cooldown = 0
        self.bombs.clear()
        if self.aircraft:
            self.aircraft.stop_sound()
        self.aircraft = None
        self.finished = False
        self.radio_active = False
        self.last_bomb_y = 0.0

    def on_acquired(self) -> None:
        self.reset_state()
        self.ammo_count = self.max_ammo

    def reset_runtime(self) -> None:
        self.reset_state()
        self.ammo_count = 0

    def equip(self) -> None:
        self.equipped = True

    def unequip(self) -> None:
        self.equipped = False

    def can_call(self) -> bool:
        return self.equipped and self.ammo_count > 0 and not self.strike_active

    def start_call(self, screen_width: int, screen_height: int, cruise_y: Optional[float] = None) -> bool:
        if not self.can_call():
            return False

        self.reset_state()
        self.strike_active = True
        self.calling = True
        self.call_timer = self.CALL_LOCK_FRAMES
        self.delay_timer = random.randint(self.MIN_DELAY_FRAMES, self.MAX_DELAY_FRAMES)
        self.bombs_remaining = random.randint(self.BOMB_MIN_COUNT, self.BOMB_MAX_COUNT)
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.ammo_count = max(0, self.ammo_count - 1)
        self.radio_active = True
        if cruise_y is not None:
            engine_sound = self._get_aircraft_sound()
            direction = random.choice(["left_to_right", "right_to_left"])
            self.aircraft = FireSupportAircraft(
                screen_width,
                screen_height,
                cruise_y,
                engine_sound=engine_sound,
                direction=direction,
            )
            self.aircraft.spawn_timer = self.aircraft.invulnerable_frames
            self.calling = False
            self.delay_timer = 0
        return True

    def update(
        self,
        *,
        boss_rect: pygame.Rect,
        ball_rect: Optional[pygame.Rect],
        last_hit_by: Optional[str],
        create_explosion: Callable[[float, float], None],
    ) -> None:
        if not self.strike_active:
            return

        if self.calling:
            if self.call_timer > 0:
                self.call_timer -= 1
            if self.call_timer <= 0:
                self.calling = False
            return

        if self.delay_timer > 0:
            self.delay_timer -= 1
            if self.delay_timer == 0:
                cruise_y = _get_supply_aircraft_altitude()
                engine_sound = self._get_aircraft_sound()
                self.aircraft = FireSupportAircraft(
                    self.screen_width,
                    self.screen_height,
                    cruise_y,
                    engine_sound=engine_sound,
                )
                self.last_bomb_y = boss_rect.centery

        if self.aircraft:
            events = self.aircraft.update(ball_rect, last_hit_by)
            if events.get("crash_landed") or events.get("finished"):
                self.aircraft.stop_sound()
                self.aircraft = None
            if self.aircraft and self.aircraft.can_drop() and self.bombs_remaining > 0:
                if self.bomb_cooldown <= 0 and self.aircraft.spawn_timer >= 60:
                    drop_x = random.uniform(60, self.screen_width - 60)
                    drop_y = boss_rect.centery + random.uniform(-50, 50)
                    self.last_bomb_y = drop_y
                    bomb = Bomb(
                        x=drop_x,
                        y=drop_y,
                        vx=0.0,
                        vy=self.BOMB_INITIAL_VY,
                        gravity=self.BOMB_GRAVITY,
                        target_y=min(self.screen_height - 60, boss_rect.centery + random.randint(-50, 50)),
                    )
                    self.bombs.append(bomb)
                    self.bombs_remaining -= 1
                    self.bomb_cooldown = self.BOMB_INTERVAL_FRAMES
                if self.bomb_cooldown > 0:
                    self.bomb_cooldown -= 1
        else:
            self.bomb_cooldown = 0

        if self.bombs:
            new_bombs: List[Bomb] = []
            for bomb in self.bombs:
                bomb.x += bomb.vx
                bomb.y += bomb.vy
                bomb.vy += bomb.gravity
                bomb.life -= 1
                if bomb.y >= bomb.target_y or bomb.life <= 0:
                    create_explosion(bomb.x, bomb.y)
                elif bomb.y < self.screen_height:
                    new_bombs.append(bomb)
            self.bombs = new_bombs

        if self.aircraft is None and not self.bombs and self.bombs_remaining <= 0:
            self.strike_active = False
            self.finished = True
            self.radio_active = False

    def draw(self, surface: pygame.Surface) -> None:
        if self.aircraft:
            self.aircraft.draw(surface)
        for bomb in self.bombs:
            pos = (int(bomb.x), int(bomb.y))
            pygame.draw.circle(surface, (255, 200, 120), pos, 6)
            pygame.draw.circle(surface, (255, 120, 60), pos, 3)

    def is_calling(self) -> bool:
        return self.strike_active and self.calling

    def is_active(self) -> bool:
        return self.strike_active or bool(self.bombs)

    def should_remove_weapon(self) -> bool:
        # 화력지원 장비는 탄약이 소진되어도 UI에서 비활성 상태를 표시해야 하므로 슬롯에서 제거하지 않는다.
        return False

    def clear_finished_flag(self) -> None:
        self.finished = False

    def _get_aircraft_sound(self) -> Optional[pygame.mixer.Sound]:
        for module_name in ("pingfighter", "__main__"):
            module = sys.modules.get(module_name)
            if not module:
                continue
            sound = getattr(module, "SOUND_AIRPLANE", None)
            if sound is not None:
                return sound
        try:
            from resource_path import resource_path

            sound_path = resource_path("sounds/airplane.wav")
            return pygame.mixer.Sound(sound_path)
        except Exception:  # noqa: BLE001
            return None


_fire_support_instance: Optional[FireSupport] = None


def get_fire_support_instance() -> FireSupport:
    global _fire_support_instance
    if _fire_support_instance is None:
        _fire_support_instance = FireSupport()
    return _fire_support_instance
def _get_supply_aircraft_altitude() -> float:
    """물자보급 비행기의 기본 고도를 조회한다."""

    module = sys.modules.get("pingfighter")
    if module:
        supply_cls = getattr(module, "SupplyAircraft", None)
        if supply_cls is not None:
            if hasattr(supply_cls, "DEFAULT_ALTITUDE"):
                return float(getattr(supply_cls, "DEFAULT_ALTITUDE"))
            if hasattr(supply_cls, "y"):
                try:
                    return float(getattr(supply_cls, "y"))
                except Exception:  # noqa: BLE001
                    pass
    return 50.0
