import math
import random
import sys
from typing import Callable, Dict, List, Optional, Sequence, Tuple

import pygame

from config.constants import WIDTH, HEIGHT, TARGET_FPS


class NetTrapGun:
    """군인 전용 그물덫총 화기류.

    플레이어가 작살을 던져 상단에 도달하면 5초 동안 유지되는 넓은 그물을 전개한다.
    전개 순간 보스 패들이 그물 범위 안에 있으면 수평 이동이 280px 폭 내부로 제한된다.
    """

    MAX_AMMO = 4
    CONTROL_LOCK_FRAMES = 30  # 0.5초 (60fps)
    COOLDOWN_FRAMES = 120  # 2초 쿨다운
    NET_WIDTH = 280
    NET_HEIGHT = 140
    NET_DURATION_FRAMES = 240  # 4초 지속 (60fps)
    PROJECTILE_SPEED = -18

    def __init__(self) -> None:
        self.equipped: bool = False
        self.active: bool = False
        self.ammo_count: int = self.MAX_AMMO
        self.cooldown_timer: int = 0
        self.control_lock_timer: int = 0

        # 발사체 및 그물 상태
        self.projectiles: List[Dict[str, object]] = []
        self.nets: List[Dict[str, object]] = []

        # 애니메이션 관련
        self.throw_pose_timer: int = 0
        self.harpoon_flash_timer: int = 0

        # 디버그 플래그
        self.debug_enabled: bool = True
        self.last_player_dashing: bool = False
        self.dash_break_duration: int = max(6, int(0.4 * TARGET_FPS))
        self.player_slow_factor: float = 0.7

    # ------------------------------------------------------------------
    # 상태 관리
    # ------------------------------------------------------------------
    def _debug(self, message: str) -> None:
        if self.debug_enabled:
            print(f"[NetGun] {message}")

    def reset(self) -> None:
        self._debug("reset → clearing state")
        self.projectiles.clear()
        self.nets.clear()
        self.cooldown_timer = 0
        self.control_lock_timer = 0
        self.throw_pose_timer = 0
        self.harpoon_flash_timer = 0
        self.last_player_dashing = False

    def equip(self) -> None:
        self.equipped = True
        self.active = True
        self._debug("equip → 그물덫총 장착")

    def unequip(self) -> None:
        self.equipped = False
        self.active = False
        self._debug("unequip → 그물덫총 해제")

    def reload(self, *, track_reload: bool = False) -> None:
        self.ammo_count = self.MAX_AMMO
        self.active = True
        self._debug(f"reload → ammo={self.ammo_count}/{self.MAX_AMMO}")

        if track_reload:
            tracker = self._get_reload_tracker()
            if tracker:
                tracker("net_gun")

    # ------------------------------------------------------------------
    # 발사 로직
    # ------------------------------------------------------------------
    def can_fire(self) -> bool:
        return (
            self.equipped
            and self.active
            and self.ammo_count > 0
            and self.cooldown_timer <= 0
            and self.control_lock_timer <= 0
        )

    def fire(self, player_rect: pygame.Rect, boss_rect: Optional[pygame.Rect]) -> bool:
        if not self.can_fire():
            return False

        target_x: float
        target_y: float
        if boss_rect is not None:
            target_x = boss_rect.centerx
            target_y = boss_rect.centery
        else:
            target_x = player_rect.centerx
            target_y = player_rect.centery - 200

        dx = target_x - player_rect.centerx
        dy = target_y - (player_rect.centery - 10)
        distance = math.hypot(dx, dy)
        if distance == 0:
            distance = 1
        norm_dx = dx / distance
        norm_dy = dy / distance

        projectile = {
            "x": float(player_rect.centerx),
            "y": float(player_rect.top - 12),
            "vx": norm_dx * abs(self.PROJECTILE_SPEED),
            "vy": norm_dy * abs(self.PROJECTILE_SPEED),
            "origin": (player_rect.centerx, player_rect.centery - 10),
            "rope_points": [],
            "active": True,
            "target": (target_x, target_y),
            "spawned_net": False,
        }

        self.projectiles.append(projectile)
        self.ammo_count = max(0, self.ammo_count - 1)
        self.cooldown_timer = self.COOLDOWN_FRAMES
        self.control_lock_timer = self.CONTROL_LOCK_FRAMES
        self.throw_pose_timer = self.CONTROL_LOCK_FRAMES
        self.harpoon_flash_timer = 6

        if self.ammo_count == 0:
            self.active = False

        self._debug(
            "fire → "
            f"target=({target_x:.1f}, {target_y:.1f}), "
            f"vel=({projectile['vx']:.2f}, {projectile['vy']:.2f}), "
            f"ammo={self.ammo_count}"
        )
        return True

    # ------------------------------------------------------------------
    # 업데이트 & 제어
    # ------------------------------------------------------------------
    def update(
        self,
        player_rect: Optional[pygame.Rect],
        boss_rect: Optional[pygame.Rect],
        player_is_dashing: bool = False,
    ) -> None:
        dash_triggered = player_is_dashing and not self.last_player_dashing
        self.last_player_dashing = player_is_dashing

        if dash_triggered:
            self._debug("dash detected → attempt rope break")
            self._break_rope()

        if self.cooldown_timer > 0:
            self.cooldown_timer -= 1
        if self.control_lock_timer > 0:
            self.control_lock_timer -= 1
        if self.throw_pose_timer > 0:
            self.throw_pose_timer -= 1
        if self.harpoon_flash_timer > 0:
            self.harpoon_flash_timer -= 1

        # 발사체 이동
        for projectile in self.projectiles[:]:
            if not projectile["active"]:
                self.projectiles.remove(projectile)
                continue

            projectile["x"] += projectile["vx"]
            projectile["y"] += projectile["vy"]

            # 밧줄 흔적 업데이트 (플레이어 중심 → 작살 위치)
            origin = projectile.get("origin")
            if player_rect is not None:
                origin = (player_rect.centerx, player_rect.centery - 10)
                projectile["origin"] = origin

            rope_points: List[tuple] = projectile["rope_points"]
            rope_points.append((projectile["x"], projectile["y"]))
            if len(rope_points) > 18:
                rope_points.pop(0)

            # 상대 진영 도달 검사 (보스 허리 위치 근처)
            projectile_rect = pygame.Rect(int(projectile["x"]) - 6, int(projectile["y"]) - 6, 12, 12)

            hit_target = False
            if boss_rect is not None:
                expanded_boss = boss_rect.inflate(120, 80)
                previous_pos = (
                    projectile["x"] - projectile["vx"],
                    projectile["y"] - projectile["vy"],
                )
                if projectile_rect.colliderect(expanded_boss):
                    hit_target = True
                    self._debug(
                        f"hit → direct overlap at ({projectile['x']:.1f}, {projectile['y']:.1f})"
                    )
                else:
                    seg_start = pygame.math.Vector2(previous_pos)
                    seg_end = pygame.math.Vector2(projectile["x"], projectile["y"])
                    clamp_x = max(expanded_boss.left, min(expanded_boss.right, seg_end.x))
                    clamp_y = max(expanded_boss.top, min(expanded_boss.bottom, seg_end.y))
                    closest_point = pygame.math.Vector2(clamp_x, clamp_y)
                    segment_vec = seg_end - seg_start
                    if segment_vec.length_squared() > 0:
                        t = (closest_point - seg_start).dot(segment_vec) / segment_vec.length_squared()
                        t = max(0.0, min(1.0, t))
                        projection = seg_start + segment_vec * t
                        distance_sq = (projection - closest_point).length_squared()
                        if distance_sq <= 36:
                            hit_target = True
                            self._debug(
                                "hit → segment proximity <=6px "
                                f"(dist={distance_sq**0.5:.2f})"
                            )
                    else:
                        if (closest_point - seg_start).length_squared() <= 36:
                            hit_target = True
                            self._debug("hit → stationary proximity <=6px")

            if hit_target:
                self._deploy_net(projectile, boss_rect)
                projectile["active"] = False
                continue

            # 화면 밖 또는 목표 초과 시 제거 (포획 실패)
            off_screen = (
                projectile["x"] < -60
                or projectile["x"] > WIDTH + 60
                or projectile["y"] < -60
                or projectile["y"] > HEIGHT + 60
            )

            passed_target = False
            target = projectile.get("target")
            if target and not hit_target:
                to_target_before = math.hypot(projectile["x"] - projectile["vx"] - target[0], projectile["y"] - projectile["vy"] - target[1])
                to_target_after = math.hypot(projectile["x"] - target[0], projectile["y"] - target[1])
                if to_target_after > to_target_before and to_target_before < 40:
                    passed_target = True

            if off_screen or passed_target:
                if not projectile.get("spawned_net"):
                    self._debug(
                        "projectile miss → deploying dissolve net"
                    )
                    self._deploy_net(projectile, boss_rect)
                projectile["active"] = False
                reason = "off-screen" if off_screen else "passed target"
                self._debug(
                    f"projectile removed ({reason}) at x={projectile['x']:.1f}, y={projectile['y']:.1f}"
                )

        # 그물 업데이트
        for net in self.nets[:]:
            net["timer"] -= 1
            if net.get("rope_broken"):
                net["rope_snap_timer"] = max(0, net.get("rope_snap_timer", 0) - 1)
            if net["timer"] <= 0:
                if net.get("boss_trapped"):
                    print("🕸️ 그물 해제 - 보스 패들 자유")
                self.nets.remove(net)
                continue

            # 그물 흔들림 애니메이션용 위상 업데이트
            net["phase"] += 0.12

            if boss_rect is not None and net.get("boss_trapped"):
                self._clamp_boss_to_net(boss_rect, net)

    def _deploy_net(
        self,
        projectile: Dict[str, object],
        boss_rect: Optional[pygame.Rect],
    ) -> None:
        projectile["spawned_net"] = True
        center_x = int(projectile["x"])
        width = self.NET_WIDTH

        target = projectile.get("target")
        if target is not None:
            target_y = target[1]
        elif boss_rect is not None:
            target_y = boss_rect.centery
        else:
            target_y = HEIGHT * 0.2

        if boss_rect is not None:
            desired_height = int(boss_rect.height * 1.1)
        else:
            desired_height = self.NET_HEIGHT
        height = max(min(desired_height, self.NET_HEIGHT), max(90, desired_height // 2))

        left = center_x - width // 2
        left = max(0, min(WIDTH - width, left))

        top = target_y - height // 2
        top = max(20, min(HEIGHT - height - 20, top))

        rect = pygame.Rect(left, top, width, height)
        boss_trapped = bool(boss_rect and rect.colliderect(boss_rect))

        if boss_trapped:
            timer = self.NET_DURATION_FRAMES
            dissolve = False
        else:
            timer = max(18, int(0.35 * TARGET_FPS))
            dissolve = True

        net = {
            "rect": rect,
            "timer": timer,
            "max_timer": timer,
            "phase": 0.0,
            "boss_trapped": boss_trapped,
            "origin": projectile.get("origin"),
            "deploy_x": center_x,
            "shape": self._generate_net_shape(rect.size),
            "dissolve": dissolve,
            "hooked_player": boss_trapped and not dissolve,
            "rope_broken": False,
            "rope_snap_timer": 0,
            "rope_snap_duration": self.dash_break_duration,
        }

        if dissolve:
            net["hooked_player"] = False
            if not boss_trapped:
                net["rope_broken"] = True
        self.nets.append(net)

        if boss_trapped:
            self._debug(
                f"deploy → success rect=({rect.left},{rect.top},{rect.width},{rect.height})"
            )
            print(
                f"🕸️ 보스 포획 성공! 지속시간 {self.NET_DURATION_FRAMES/60:.1f}초, 범위 {rect.left}-{rect.right}px"
            )
            print("🪤 장력 유지: 보스를 묶고 있는 동안 군인의 이동 속도가 30% 감소합니다.")
        else:
            self._debug(
                f"deploy → miss rect=({rect.left},{rect.top},{rect.width},{rect.height}), timer={timer}"
            )
            print("🕸️ 그물 전개 - 보스 포획 실패 (즉시 용해)")

    def _clamp_boss_to_net(self, boss_rect: pygame.Rect, net: Dict[str, object]) -> None:
        net_rect: pygame.Rect = net["rect"]
        # 보스 좌표를 그물 내부로 제한
        boss_rect.x = max(net_rect.left, min(net_rect.right - boss_rect.width, boss_rect.x))

    # ------------------------------------------------------------------
    # 렌더링 헬퍼
    # ------------------------------------------------------------------
    def draw_projectiles(self, screen: pygame.Surface) -> None:
        for projectile in self.projectiles:
            if not projectile["active"]:
                continue

            x = int(projectile["x"])
            y = int(projectile["y"])
            origin = projectile.get("origin", (x, y + 40))

            # 밧줄 그리기 (감소하는 두께)
            rope_points = [origin] + list(projectile["rope_points"])
            if len(rope_points) >= 2:
                for idx in range(len(rope_points) - 1):
                    start = rope_points[idx]
                    end = rope_points[idx + 1]
                    thickness = max(1, 4 - idx // 4)
                    pygame.draw.line(screen, (210, 180, 140), start, end, thickness)

            # 작살 헤드
            angle = math.atan2(projectile.get("vy", 0.0), projectile.get("vx", 0.0))
            heading = angle if projectile.get("vx", 0.0) or projectile.get("vy", 0.0) else -math.pi / 2
            tip = (x + math.cos(heading) * 16, y + math.sin(heading) * 16)
            left = (x + math.cos(heading + math.pi * 0.75) * 8, y + math.sin(heading + math.pi * 0.75) * 8)
            right = (x + math.cos(heading - math.pi * 0.75) * 8, y + math.sin(heading - math.pi * 0.75) * 8)
            pygame.draw.polygon(
                screen,
                (200, 220, 230),
                [tip, left, right],
            )
            shaft_rect = pygame.Rect(0, 0, 6, 18)
            shaft_rect.center = (x - math.cos(heading) * 6, y - math.sin(heading) * 6)
            pygame.draw.rect(screen, (130, 140, 150), shaft_rect)

    def draw_nets(self, screen: pygame.Surface) -> None:
        for net in self.nets:
            rect: pygame.Rect = net["rect"]
            dissolve = net.get("dissolve", False)
            max_timer = net.get("max_timer", self.NET_DURATION_FRAMES)
            if max_timer <= 0:
                max_timer = 1
            remaining_ratio = max(0.0, net["timer"] / max_timer)
            alpha = int((200 if not dissolve else 150) * remaining_ratio + 30)

            # 반투명 배경
            surface = pygame.Surface(rect.size, pygame.SRCALPHA)
            surface.fill((0, 0, 0, 0))

        phase = net["phase"]
        polygon_points = net["shape"]
        cx = rect.width / 2
        cy = rect.height / 2
        jittered_points = []
        constrict_x = 0.7 if net.get("hooked_player") and not dissolve else 1.0
        if dissolve:
            shrink = remaining_ratio ** 1.4
            jitter_amp = 4 + (1 - remaining_ratio) * 8
            vertical_scale = 0.45 + 0.25 * remaining_ratio
        else:
            shrink = 0.9 + 0.1 * remaining_ratio
            jitter_amp = 3
            vertical_scale = 0.6 + 0.3 * remaining_ratio

        for px, py in polygon_points:
            rel_x = px - cx
            rel_y = py - cy
            sine_seed = phase + (px + py) * 0.03
            jitter_x = math.sin(sine_seed) * jitter_amp
            jitter_y = math.cos(sine_seed * 0.8) * (jitter_amp * 0.5)
            final_x = cx + rel_x * shrink * constrict_x + jitter_x
            final_y = cy + rel_y * vertical_scale + jitter_y
            if dissolve:
                final_y += (1 - remaining_ratio) ** 1.2 * rect.height * 0.6
                final_x += math.sin(phase * 1.7 + px * 0.05) * (1 - remaining_ratio) * 10
            jittered_points.append((final_x, final_y))

        fill_alpha = max(20, int(alpha * (0.4 if dissolve else 0.55)))
        outline_color = (210, 240, 255, max(60, alpha))
        fill_color = (95, 140, 180, fill_alpha)

        pygame.draw.polygon(surface, fill_color, jittered_points)
        pygame.draw.polygon(surface, outline_color, jittered_points, 2)

        lattice_color = (175, 215, 245, int(alpha * 0.7))
        self._draw_mesh(surface, jittered_points, lattice_color, dissolve, remaining_ratio)

        screen.blit(surface, rect.topleft)

    def draw_throw_pose(self, screen: pygame.Surface, player_rect: pygame.Rect) -> None:
        if self.throw_pose_timer <= 0:
            return

        # 플레이어 패들 위에 간단한 작살 던지는 포즈를 오버레이한다.
        overlay_width = player_rect.width
        overlay_height = player_rect.height
        overlay = pygame.Surface((overlay_width, overlay_height), pygame.SRCALPHA)

        # 팔/작살 간이 드로잉
        arm_color = (220, 200, 160)
        pygame.draw.rect(overlay, arm_color, (overlay_width // 2 - 4, overlay_height // 2 - 8, 8, 24))

        # 작살 몸체
        pygame.draw.rect(overlay, (90, 100, 120), (overlay_width // 2 + 6, overlay_height // 2 - 4, 28, 6))
        pygame.draw.polygon(
            overlay,
            (200, 220, 230),
            [
                (overlay_width // 2 + 34, overlay_height // 2 - 6),
                (overlay_width // 2 + 48, overlay_height // 2),
                (overlay_width // 2 + 34, overlay_height // 2 + 6),
            ],
        )

        # 밧줄 (선 형태)
        pygame.draw.line(
            overlay,
            (210, 180, 140, 220),
            (overlay_width // 2 + 6, overlay_height // 2 + 2),
            (overlay_width // 2 - 18, overlay_height - 6),
            3,
        )

        screen.blit(overlay, (player_rect.x, player_rect.y - 6))

    # ------------------------------------------------------------------
    # 상태 조회
    # ------------------------------------------------------------------
    def boss_is_trapped(self) -> bool:
        return any(net.get("boss_trapped") for net in self.nets)

    def time_until_free(self) -> int:
        trapped_nets = [net for net in self.nets if net.get("boss_trapped")]
        if not trapped_nets:
            return 0
        return max(net["timer"] for net in trapped_nets)

    def _generate_net_shape(self, size: Tuple[int, int]) -> Sequence[Tuple[float, float]]:
        width, height = size
        cx = width / 2
        cy = height / 2
        radius_x = width / 2
        radius_y = height / 2
        points: List[Tuple[float, float]] = []
        steps = 36
        seed = random.random()
        for i in range(steps):
            angle = (i / steps) * math.tau
            noise = math.sin(angle * 3 + seed * math.tau) * 0.18
            noise += math.sin(angle * 7 + seed * 5) * 0.08
            scale = 0.82 + noise
            px = cx + math.cos(angle) * radius_x * scale
            py = cy + math.sin(angle) * radius_y * scale
            points.append((px, py))
        return points

    def _draw_mesh(
        self,
        surface: pygame.Surface,
        hull_points: Sequence[Tuple[float, float]],
        color: Tuple[int, int, int, int],
        dissolve: bool,
        life_ratio: float,
    ) -> None:
        cx = sum(p[0] for p in hull_points) / len(hull_points)
        cy = sum(p[1] for p in hull_points) / len(hull_points)
        subdivisions = 10 if dissolve else 14
        radius_x = max(abs(px - cx) for px, _ in hull_points)
        radius_y = max(abs(py - cy) for _, py in hull_points)

        for i in range(subdivisions):
            t = i / subdivisions
            angle = t * math.tau
            base = 0.48 + 0.2 * math.sin(angle * 5)
            if dissolve:
                radius = base * (0.6 + 0.3 * life_ratio)
            else:
                radius = base * 0.9
            inner_x = cx + math.cos(angle) * radius_x * radius
            inner_y = cy + math.sin(angle) * radius_y * radius
            pygame.draw.circle(surface, color, (int(inner_x), int(inner_y)), 1)

        chord_step = max(3, len(hull_points) // (12 if dissolve else 14))
        for i in range(0, len(hull_points), chord_step):
            start = hull_points[i]
            end = hull_points[(i + chord_step * 3) % len(hull_points)]
            pygame.draw.aaline(surface, color, start, end)

        spoke_step = max(2, len(hull_points) // (10 if dissolve else 18))
        for i in range(0, len(hull_points), spoke_step):
            dest = hull_points[(i + spoke_step * 2) % len(hull_points)]
            mid_x = (hull_points[i][0] + dest[0]) / 2
            mid_y = (hull_points[i][1] + dest[1]) / 2
            pygame.draw.aaline(surface, color, (cx, cy), (mid_x, mid_y))

    def draw_rope(self, screen: pygame.Surface, player_rect: Optional[pygame.Rect]) -> None:
        if player_rect is None:
            return

        start = (player_rect.centerx, player_rect.centery - 10)

        for net in self.nets:
            hooked = net.get("hooked_player") and not net.get("dissolve")
            breaking = net.get("rope_broken") and net.get("dissolve")
            if not (hooked or breaking):
                continue

            end_full = (net["rect"].centerx, net["rect"].centery)
            rope_color = (210, 190, 150)
            highlight_color = (255, 240, 200)
            end = end_full

            if breaking:
                snap_duration = net.get("rope_snap_duration", 1)
                snap_timer = net.get("rope_snap_timer", 0)
                if snap_duration <= 0:
                    continue
                progress = max(0.0, min(1.0, snap_timer / snap_duration))
                if progress <= 0.0:
                    continue

                end = (
                    start[0] + (end_full[0] - start[0]) * progress,
                    start[1] + (end_full[1] - start[1]) * progress,
                )
                rope_color = (235, 160, 160)
                highlight_color = (255, 210, 210)

            control1 = (
                start[0] * 0.66 + end[0] * 0.34,
                start[1] * 0.66 + end[1] * 0.34 + 20,
            )
            control2 = (
                start[0] * 0.34 + end[0] * 0.66,
                start[1] * 0.34 + end[1] * 0.66 + 28,
            )
            path = [start, control1, control2, end]
            int_path = [(int(x), int(y)) for x, y in path]
            pygame.draw.lines(screen, rope_color, False, int_path, 4)
            pygame.draw.aalines(screen, highlight_color, False, path)

    def get_player_speed_multiplier(self) -> float:
        for net in self.nets:
            if net.get("hooked_player") and not net.get("dissolve"):
                return self.player_slow_factor
        return 1.0

    def _get_reload_tracker(self) -> Callable[[str], None] | None:
        for module_name in ("__main__", "pingfighter"):
            module = sys.modules.get(module_name)
            if not module:
                continue
            candidate = getattr(module, "register_weapon_reload", None)
            if callable(candidate):
                return candidate
            controller = getattr(module, "soldier_controller", None)
            name_resolver = getattr(module, "get_item_name_korean", None)
            if controller and hasattr(controller, "register_reload"):
                def fallback(weapon: str, *, _controller=controller, _resolver=name_resolver) -> None:
                    if weapon == "pistol":
                        return
                    try:
                        degraded = _controller.register_reload(weapon)
                    except Exception:
                        return
                    if degraded:
                        try:
                            label = _resolver(weapon) if callable(_resolver) else weapon
                            print(f"⚠️ {label} 노후화!")
                        except Exception:
                            print(f"⚠️ {weapon} 노후화!")

                return fallback
        return None

    def _break_rope(self) -> None:
        broke = False
        for net in self.nets:
            if net.get("hooked_player") and not net.get("dissolve"):
                net["hooked_player"] = False
                net["dissolve"] = True
                net["rope_broken"] = True
                net["timer"] = self.dash_break_duration
                net["max_timer"] = self.dash_break_duration
                net["rope_snap_timer"] = self.dash_break_duration
                broke = True
        if broke:
            self._debug(
                f"rope break → net dissolving in {self.dash_break_duration} frames"
            )


_net_gun_instance: Optional[NetTrapGun] = None


def get_net_gun_instance() -> NetTrapGun:
    global _net_gun_instance
    if _net_gun_instance is None:
        _net_gun_instance = NetTrapGun()
    return _net_gun_instance
