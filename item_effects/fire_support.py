from __future__ import annotations

import random
from dataclasses import dataclass
from typing import Callable, List, Optional

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

    def __init__(self, screen_width: int, screen_height: int, cruise_y: Optional[float] = None) -> None:
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.width = 110
        self.height = 32
        self.x = -self.width
        self.y = cruise_y if cruise_y is not None else max(80, screen_height * 0.35)
        self.speed = 1.8
        self.active = True
        self.crashing = False
        self.spawn_timer = 0
        self.invulnerable_frames = 45
        self.crash_velocity_y = 0.4
        self.crash_gravity = 0.18

    def get_rect(self) -> pygame.Rect:
        return pygame.Rect(int(self.x), int(self.y), self.width, self.height)

    def update(self, ball_rect: Optional[pygame.Rect], last_hit_by: Optional[str]) -> dict:
        if not self.active:
            return {"finished": True}

        self.spawn_timer += 1
        events: dict = {}

        if not self.crashing:
            self.x += self.speed
            if ball_rect and last_hit_by == "player" and self.spawn_timer >= self.invulnerable_frames:
                if self.get_rect().colliderect(ball_rect):
                    self.crashing = True
                    events["hit"] = True
            if self.x > self.screen_width + self.width:
                self.active = False
                events["finished"] = True
        else:
            self.x += self.speed * 0.35
            self.crash_velocity_y = min(self.crash_velocity_y + self.crash_gravity, 6)
            self.y += self.crash_velocity_y
            if self.y >= self.screen_height - 96:
                self.active = False
                events["crash_landed"] = True

        return events

    def can_drop(self) -> bool:
        return self.active and not self.crashing and self.spawn_timer >= self.invulnerable_frames

    def drop_anchor(self) -> tuple[float, float]:
        return (self.x + self.width * 0.7, self.y + self.height - 4)

    def draw(self, surface: pygame.Surface) -> None:
        if not self.active and not self.crashing:
            return
        body_rect = pygame.Rect(int(self.x), int(self.y), self.width, self.height)
        pygame.draw.rect(surface, (90, 110, 140), body_rect, border_radius=6)
        pygame.draw.rect(surface, (35, 45, 70), body_rect, 2, border_radius=6)
        cockpit = pygame.Rect(int(self.x + 12), int(self.y + 6), 26, 14)
        pygame.draw.rect(surface, (150, 190, 220), cockpit, border_radius=4)
        pygame.draw.rect(surface, (60, 90, 130), cockpit, 1, border_radius=4)
        wing = pygame.Rect(int(self.x + self.width * 0.3), int(self.y - 6), int(self.width * 0.55), 10)
        pygame.draw.rect(surface, (70, 90, 120), wing, border_radius=4)
        tail = pygame.Rect(int(self.x + self.width * 0.8), int(self.y - 2), 18, 18)
        pygame.draw.rect(surface, (70, 90, 120), tail, border_radius=4)
        engine_color = (200, 120, 60) if self.crashing else (230, 170, 90)
        for offset in (18, 44, 70):
            pygame.draw.circle(surface, engine_color, (int(self.x + offset), int(self.y + self.height)), 4)


class FireSupport:
    """병사 화력지원 무기."""

    CALL_LOCK_FRAMES = 30
    MIN_DELAY_FRAMES = 120
    MAX_DELAY_FRAMES = 300
    BOMB_INTERVAL_FRAMES = 42
    BOMB_MIN_COUNT = 5
    BOMB_MAX_COUNT = 7
    BOMB_GRAVITY = 0.35
    BOMB_INITIAL_VY = 2.0
    BOMB_HORIZONTAL_JITTER = 1.1

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

    def reset_state(self) -> None:
        self.strike_active = False
        self.calling = False
        self.call_timer = 0
        self.delay_timer = 0
        self.bombs_remaining = 0
        self.bomb_cooldown = 0
        self.bombs.clear()
        self.aircraft = None
        self.finished = False
        self.radio_active = False

    def on_acquired(self) -> None:
        self.reset_state()
        self.ammo_count = 1

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
            self.aircraft = FireSupportAircraft(screen_width, screen_height, cruise_y)
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
                cruise_y = max(70, min(self.screen_height * 0.65, boss_rect.centery - 140))
                self.aircraft = FireSupportAircraft(self.screen_width, self.screen_height, cruise_y)

        if self.aircraft:
            events = self.aircraft.update(ball_rect, last_hit_by)
            if events.get("crash_landed") or events.get("finished"):
                self.aircraft = None
            if self.aircraft and self.aircraft.can_drop() and self.bombs_remaining > 0:
                if self.aircraft.get_rect().centerx >= self.screen_width * 0.45:
                    if self.bomb_cooldown <= 0:
                        drop_x, drop_y = self.aircraft.drop_anchor()
                        bomb = Bomb(
                            x=drop_x + random.uniform(-14, 14),
                            y=drop_y,
                            vx=random.uniform(0.4, self.BOMB_HORIZONTAL_JITTER),
                            vy=self.BOMB_INITIAL_VY,
                            gravity=self.BOMB_GRAVITY,
                            target_y=min(self.screen_height - 40, boss_rect.centery + random.randint(-40, 60)),
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
        return self.finished and self.ammo_count <= 0

    def clear_finished_flag(self) -> None:
        self.finished = False


_fire_support_instance: Optional[FireSupport] = None


def get_fire_support_instance() -> FireSupport:
    global _fire_support_instance
    if _fire_support_instance is None:
        _fire_support_instance = FireSupport()
    return _fire_support_instance
