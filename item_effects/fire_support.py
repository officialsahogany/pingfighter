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
        self.width = 160  # B-2는 더 큰 날개폭
        self.height = 50  # B-2는 얇은 프로필
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

        # 엔진 배기 화염 그리기
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

        # B-2 폭격기의 특징적인 삼각형/다이아몬드 날개 형태
        if self.direction == "left_to_right":
            body_points = [
                # 노즈 (전방)
                self._to_screen_point(base_x, base_y, w, h, 0.95, 0.50),
                # 우측 날개 끝
                self._to_screen_point(base_x, base_y, w, h, 0.85, 0.05),
                # 우측 날개 중간
                self._to_screen_point(base_x, base_y, w, h, 0.50, 0.15),
                # 중앙 뒤쪽
                self._to_screen_point(base_x, base_y, w, h, 0.05, 0.50),
                # 좌측 날개 중간
                self._to_screen_point(base_x, base_y, w, h, 0.50, 0.85),
                # 좌측 날개 끝
                self._to_screen_point(base_x, base_y, w, h, 0.85, 0.95),
            ]
        else:
            body_points = [
                # 노즈 (전방)
                self._to_screen_point(base_x, base_y, w, h, 0.05, 0.50),
                # 좌측 날개 끝
                self._to_screen_point(base_x, base_y, w, h, 0.15, 0.05),
                # 좌측 날개 중간
                self._to_screen_point(base_x, base_y, w, h, 0.50, 0.15),
                # 중앙 뒤쪽
                self._to_screen_point(base_x, base_y, w, h, 0.95, 0.50),
                # 우측 날개 중간
                self._to_screen_point(base_x, base_y, w, h, 0.50, 0.85),
                # 우측 날개 끝
                self._to_screen_point(base_x, base_y, w, h, 0.15, 0.95),
            ]

        # B-2의 특징적인 검은색
        main_color = (25, 25, 28) if not self.crashing else (60, 45, 35)
        outline_color = (10, 10, 12)
        highlight_color = (40, 40, 45)
        panel_color = (35, 35, 40)

        # 메인 동체 그리기
        pygame.draw.polygon(surface, main_color, body_points)
        pygame.draw.polygon(surface, outline_color, body_points, 2)

        # 날개 패널 라인과 디테일
        if self.direction == "left_to_right":
            # 우측 날개 패널
            panel_lines_right = [
                self._to_screen_point(base_x, base_y, w, h, 0.85, 0.25),
                self._to_screen_point(base_x, base_y, w, h, 0.60, 0.35),
            ]
            # 좌측 날개 패널
            panel_lines_left = [
                self._to_screen_point(base_x, base_y, w, h, 0.85, 0.75),
                self._to_screen_point(base_x, base_y, w, h, 0.60, 0.65),
            ]
            # 엔진 벌지 위치
            engine_center_right = self._to_screen_point(base_x, base_y, w, h, 0.30, 0.30)
            engine_center_left = self._to_screen_point(base_x, base_y, w, h, 0.30, 0.70)
        else:
            # 좌측 날개 패널
            panel_lines_right = [
                self._to_screen_point(base_x, base_y, w, h, 0.15, 0.25),
                self._to_screen_point(base_x, base_y, w, h, 0.40, 0.35),
            ]
            # 우측 날개 패널
            panel_lines_left = [
                self._to_screen_point(base_x, base_y, w, h, 0.15, 0.75),
                self._to_screen_point(base_x, base_y, w, h, 0.40, 0.65),
            ]
            # 엔진 벌지 위치
            engine_center_right = self._to_screen_point(base_x, base_y, w, h, 0.70, 0.30)
            engine_center_left = self._to_screen_point(base_x, base_y, w, h, 0.70, 0.70)

        # 날개 패널 라인
        pygame.draw.line(surface, panel_color, panel_lines_right[0], panel_lines_right[1], 2)
        pygame.draw.line(surface, panel_color, panel_lines_left[0], panel_lines_left[1], 2)

        # 엔진 벌지 (B-2의 특징적인 엔진 흡입구)
        engine_radius = int(h * 0.16)
        pygame.draw.circle(surface, (20, 20, 23), engine_center_right, engine_radius)
        pygame.draw.circle(surface, (20, 20, 23), engine_center_left, engine_radius)
        pygame.draw.circle(surface, outline_color, engine_center_right, engine_radius, 1)
        pygame.draw.circle(surface, outline_color, engine_center_left, engine_radius, 1)

        # 콕핏 위치 (중앙 상단)
        if self.direction == "left_to_right":
            cockpit_center = self._to_screen_point(base_x, base_y, w, h, 0.70, 0.50)
        else:
            cockpit_center = self._to_screen_point(base_x, base_y, w, h, 0.30, 0.50)
        
        cockpit_width = int(w * 0.08)
        cockpit_height = int(h * 0.20)
        cockpit_rect = pygame.Rect(
            cockpit_center[0] - cockpit_width // 2,
            cockpit_center[1] - cockpit_height // 2,
            cockpit_width,
            cockpit_height,
        )
        pygame.draw.ellipse(surface, (50, 60, 70), cockpit_rect)
        pygame.draw.ellipse(surface, outline_color, cockpit_rect, 1)

        # 날개 엣지 하이라이트 (스텔스 코팅 효과)
        edge_alpha = 80
        edge_surface = pygame.Surface((2, 2), pygame.SRCALPHA)
        if self.direction == "left_to_right":
            # 앞쪽 엣지
            edge_line = [
                self._to_screen_point(base_x, base_y, w, h, 0.95, 0.50),
                self._to_screen_point(base_x, base_y, w, h, 0.85, 0.05),
            ]
            pygame.draw.line(surface, (*highlight_color, edge_alpha), edge_line[0], edge_line[1], 2)
            edge_line2 = [
                self._to_screen_point(base_x, base_y, w, h, 0.95, 0.50),
                self._to_screen_point(base_x, base_y, w, h, 0.85, 0.95),
            ]
            pygame.draw.line(surface, (*highlight_color, edge_alpha), edge_line2[0], edge_line2[1], 2)
        else:
            # 앞쪽 엣지
            edge_line = [
                self._to_screen_point(base_x, base_y, w, h, 0.05, 0.50),
                self._to_screen_point(base_x, base_y, w, h, 0.15, 0.05),
            ]
            pygame.draw.line(surface, (*highlight_color, edge_alpha), edge_line[0], edge_line[1], 2)
            edge_line2 = [
                self._to_screen_point(base_x, base_y, w, h, 0.05, 0.50),
                self._to_screen_point(base_x, base_y, w, h, 0.15, 0.95),
            ]
            pygame.draw.line(surface, (*highlight_color, edge_alpha), edge_line2[0], edge_line2[1], 2)

    def _ratio_to_x(self, base_x: float, width: float, ratio: float) -> float:
        if self.direction == "left_to_right":
            return base_x + width * ratio
        return base_x + width * (1 - ratio)

    def _to_screen_point(
        self,
        base_x: float,
        base_y: float,
        width: float,
        height: float,
        px: float,
        py: float,
    ) -> tuple[int, int]:
        return (
            int(self._ratio_to_x(base_x, width, px)),
            int(base_y + height * py),
        )

    def _engine_positions(self) -> list[tuple[float, float]]:
        base_x = self.x
        base_y = self.y
        w = self.width
        h = self.height
        # B-2의 엔진은 날개 상단에 매립되어 있음
        if self.direction == "left_to_right":
            return [
                (self._ratio_to_x(base_x, w, 0.25), base_y + h * 0.30),
                (self._ratio_to_x(base_x, w, 0.25), base_y + h * 0.70),
            ]
        else:
            return [
                (self._ratio_to_x(base_x, w, 0.75), base_y + h * 0.30),
                (self._ratio_to_x(base_x, w, 0.75), base_y + h * 0.70),
            ]

    def _spawn_flame_particles(self, *, count: int) -> None:
        if count <= 0:
            return
        max_particles = 120
        if len(self.flame_particles) >= max_particles:
            return

        direction_sign = 1 if self.direction == "left_to_right" else -1
        for engine_x, engine_y in self._engine_positions():
            for _ in range(count):
                spawn_x = engine_x - direction_sign * random.uniform(5.5, 9.5)
                spawn_y = engine_y + random.uniform(-2.5, 2.5)
                particle = {
                    "x": spawn_x,
                    "y": spawn_y,
                    "vx": -direction_sign * random.uniform(0.6, 1.4),
                    "vy": random.uniform(-0.25, 0.25),
                    "gravity": 0.02,
                    "radius": random.uniform(3.2, 5.6),
                    "life": random.randint(12, 18),
                }
                particle["max_life"] = particle["life"]
                self.flame_particles.append(particle)
                if len(self.flame_particles) >= max_particles:
                    return

    def _update_flame_particles(self) -> None:
        if not self.flame_particles:
            return
        updated: list[dict[str, float]] = []
        for particle in self.flame_particles:
            particle["x"] += particle["vx"]
            particle["y"] += particle["vy"]
            particle["vy"] += particle["gravity"]
            particle["radius"] = max(1.2, particle["radius"] * 0.94)
            particle["life"] -= 1
            if particle["life"] > 0:
                updated.append(particle)
        self.flame_particles = updated

    def stop_sound(self) -> None:
        if self.sound_channel:
            try:
                self.sound_channel.stop()
            except Exception:  # noqa: BLE001
                pass
            self.sound_channel = None


class FireSupport:
    """병사 화력지원 무기."""

    CALL_LOCK_FRAMES = 42  # 0.7초 동안 무전 교신 연출 유지 (60fps 기준)
    MIN_DELAY_FRAMES = 120
    MAX_DELAY_FRAMES = 180
    BOMB_INTERVAL_FRAMES = 60
    BOMB_MIN_COUNT = 5
    BOMB_MAX_COUNT = 7
    BOMB_GRAVITY = 0.35
    BOMB_INITIAL_VY = 2.0
    BOMB_HORIZONTAL_JITTER = 1.1
    MAX_AMMO = 1
    RADIO_RELEASE_FRAMES = 90  # 폭격 종료 후 무전 사운드를 유지할 추가 프레임 수
    RADIO_MIN_FRAMES = int(6.0 * 60)  # 최소 무전 사운드 유지 시간 (6초)

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
        self._has_initial_load = False
        self.reuse_locked = False
        self.radio_release_timer = 0
        self.radio_channel: Optional[pygame.mixer.Channel] = None
        self._radio_sound: pygame.mixer.Sound | bool | None = None
        self.radio_volume = 1.0
        self.radio_volume_call = 0.55
        self.radio_min_timer = 0

    def reset_state(self) -> None:
        self._stop_radio_loop()
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
        self.reuse_locked = False
        self.radio_release_timer = 0
        self.radio_min_timer = 0

    def on_acquired(self) -> None:
        track_reload = self._has_initial_load
        self.rearm(track_reload=track_reload)
        self._has_initial_load = True

    def reset_runtime(self) -> None:
        self.reset_state()
        self.ammo_count = 0
        self._has_initial_load = False

    def rearm(self, *, track_reload: bool = False, ammo_override: Optional[int] = None) -> None:
        self.reset_state()
        if ammo_override is not None:
            self.max_ammo = max(1, ammo_override)
        self.ammo_count = self.max_ammo
        # 화력지원은 재장전 시 곧바로 재사용 가능해야 하므로 equip 상태를 복원한다.
        self.equip()
        if track_reload:
            tracker = self._get_reload_tracker()
            if tracker:
                tracker("fire_support")

    def equip(self) -> None:
        self.equipped = True

    def unequip(self) -> None:
        self.equipped = False

    def can_call(self) -> bool:
        return (
            self.equipped
            and self.ammo_count > 0
            and not self.strike_active
            and not self.reuse_locked
        )

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
        self._ensure_radio_loop()
        self.reuse_locked = True
        self.radio_min_timer = self.RADIO_MIN_FRAMES
        self.unequip()  # 발동과 동시에 무전 장비를 비활성화해 UI/입력에서 상태를 명확히 표시
        self._notify_lockout()
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

        if self.radio_active:
            self._ensure_radio_loop()
            if self.radio_release_timer <= 0:
                target_volume = self.radio_volume_call if self.calling else self.radio_volume
                self._set_radio_volume(target_volume)
            if self.radio_min_timer > 0:
                self.radio_min_timer -= 1

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
            if self.radio_min_timer > 0:
                # 최소 유지 시간 동안에는 강한 무전 볼륨을 유지한다.
                self._set_radio_volume(self.radio_volume)
            elif self.radio_release_timer <= 0:
                self.radio_release_timer = self.RADIO_RELEASE_FRAMES
            else:
                self.radio_release_timer -= 1
                fade_ratio = max(0.0, self.radio_release_timer / self.RADIO_RELEASE_FRAMES)
                self._set_radio_volume(self.radio_volume * fade_ratio)
                if self.radio_release_timer <= 0:
                    self.strike_active = False
                    self.finished = True
                    self.radio_active = False
                    self.reuse_locked = False
                    self._stop_radio_loop()
                    self.radio_release_timer = 0
                    self.radio_min_timer = 0

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

    def is_locked(self) -> bool:
        return self.reuse_locked

    def should_remove_weapon(self) -> bool:
        # 화력지원 장비는 탄약이 소진되어도 UI에서 비활성 상태를 표시해야 하므로 슬롯에서 제거하지 않는다.
        return False

    def clear_finished_flag(self) -> None:
        self.finished = False

    def _notify_lockout(self) -> None:
        module = sys.modules.get("pingfighter")
        if not module:
            return
        handler = getattr(module, "handle_fire_support_lockout", None)
        if callable(handler):
            try:
                handler()
            except Exception:  # noqa: BLE001
                pass

    def _stop_radio_loop(self) -> None:
        if self.radio_channel:
            try:
                self.radio_channel.stop()
            except Exception:  # noqa: BLE001
                pass
            self.radio_channel = None

    def _ensure_radio_loop(self) -> None:
        sound = self._get_radio_sound()
        if sound is None:
            return
        try:
            if self.radio_channel is None or not self.radio_channel.get_busy():
                self.radio_channel = sound.play(-1)
                if self.radio_channel:
                    self.radio_channel.set_volume(self.radio_volume_call)
        except Exception:  # noqa: BLE001
            self.radio_channel = None

    def _set_radio_volume(self, volume: float) -> None:
        if self.radio_channel:
            try:
                clamped = max(0.0, min(1.0, volume))
                self.radio_channel.set_volume(clamped)
            except Exception:  # noqa: BLE001
                pass

    def _get_radio_sound(self) -> Optional[pygame.mixer.Sound]:
        if self._radio_sound is None:
            try:
                from resource_path import resource_path

                sound_path = resource_path("sounds/radio.wav")
                sound = pygame.mixer.Sound(sound_path)
                sound.set_volume(self.radio_volume)
                self._radio_sound = sound
            except Exception:  # noqa: BLE001
                self._radio_sound = False
        if self._radio_sound is False:
            return None
        return self._radio_sound

    def _get_reload_tracker(self) -> Callable[[str], None] | None:
        for module_name in ("__main__", "pingfighter"):
            module = sys.modules.get(module_name)
            if not module:
                continue
            tracker = getattr(module, "register_weapon_reload", None)
            if callable(tracker):
                return tracker
        return None

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
