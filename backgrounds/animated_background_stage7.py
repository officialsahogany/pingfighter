"""Stage 7 전용 애니메이션 배경.

중세 요새 내부 느낌을 유지하면서 은은한 조명과 조그마한 빛 입자를 움직여
정적인 배경 위에 생동감을 추가한다.
"""

from __future__ import annotations

import math
import random
from typing import List, Tuple

import pygame

# ============================================================
# Surface 캐시 시스템 (성능 최적화)
# ============================================================
_stage7_surface_cache = {}

def _get_cached_surface(width: int, height: int) -> pygame.Surface:
    """캐시된 투명 Surface 반환"""
    key = (width, height)
    if key not in _stage7_surface_cache:
        if len(_stage7_surface_cache) > 100:
            _stage7_surface_cache.clear()
        _stage7_surface_cache[key] = pygame.Surface((width, height), pygame.SRCALPHA)
    surface = _stage7_surface_cache[key]
    surface.fill((0, 0, 0, 0))
    return surface

Color = Tuple[int, int, int]

# 화면 크기 - config에서 가져오기
try:
    from config.constants import PILLAR_UI_WIDTH, GAME_PLAY_WIDTH
    PILLAR_OFFSET = PILLAR_UI_WIDTH  # 80px
    GAME_WIDTH = GAME_PLAY_WIDTH  # 600px
except ImportError:
    PILLAR_OFFSET = 80
    GAME_WIDTH = 600


class AnimatedBackgroundStage7:
    """Stage 7 배경 위에 얹는 경량 애니메이션 오버레이."""

    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.time = 0.0

        # 토치 중심 좌표 (정적인 배경과 동일 위치)
        self.torch_positions: List[Tuple[int, int]] = [
            (96, 176),
            (width - 96, 176),
            (96, height - 220),
            (width - 96, height - 220),
        ]

        # 내부 잔광 효과용 파티클
        self.light_motes: List[dict] = []
        for _ in range(12):
            self.light_motes.append(
                {
                    "x": random.uniform(140, width - 140),
                    "y": random.uniform(height / 2 - 90, height / 2 + 110),
                    "speed": random.uniform(12.0, 26.0),  # px/sec
                    "phase": random.uniform(0, math.tau),
                    "radius": random.uniform(2.0, 4.0),
                }
            )

        # 이동하는 라이트 밴드 설정
        self.band_width = 200
        self.band_height = 180
        self.band_top = int(height / 2 - self.band_height / 2)

        # 라이트 밴드 프리렌더 (200 draw.line 호출 → 1회 프리렌더)
        self._prerendered_band = pygame.Surface((self.band_width, self.band_height), pygame.SRCALPHA)
        half = self.band_width / 2
        for x in range(self.band_width):
            intensity = max(0.0, 1.0 - abs(x - half) / half)
            alpha = int(70 * (intensity ** 1.8))
            color = (120, 186, 255, alpha)
            pygame.draw.line(self._prerendered_band, color, (x, 0), (x, self.band_height))

        # 중앙 회전 큐브(의사 3D) 파라미터
        # - 정적 자원 사용 없이 폴리곤만으로 그리며, per‑frame 연산을 최소화한다.
        self.cube_enabled = True
        self.cube_size = int(min(self.width, self.height) * 0.09)  # 화면 크기 비례
        self.cube_center = (self.width // 2, self.height // 2)
        self.cube_center_offset = (0, 0)  # 필요 시 미세조정용
        # 현재 기준에서 2배 확대: 0.00486 → 0.00972
        self.cube_scale = 0.00972
        # 8개 정점(기본 단위 큐브)을 미리 정의하고, 매 프레임 회전/투영만 갱신
        s = 1.0
        self._cube_vertices = [
            (-s, -s, -s), (s, -s, -s), (s, s, -s), (-s, s, -s),  # 뒤쪽 면
            (-s, -s,  s), (s, -s,  s), (s, s,  s), (-s, s,  s),  # 앞쪽 면
        ]
        # 각 면은 정점 인덱스의 시계방향 나열로 정의. painter's algorithm용으로 정렬한다.
        self._cube_faces = [
            (0, 1, 2, 3),  # back
            (4, 5, 6, 7),  # front
            (0, 1, 5, 4),  # top
            (3, 2, 6, 7),  # bottom
            (1, 2, 6, 5),  # right
            (0, 3, 7, 4),  # left
        ]
        # 윤곽선 강조용 엣지 목록(중복 제거)
        self._cube_edges = {
            tuple(sorted(e)) for e in (
                (0,1),(1,2),(2,3),(3,0),
                (4,5),(5,6),(6,7),(7,4),
                (0,4),(1,5),(2,6),(3,7),
            )
        }
        # 투영/조명 계수
        self._cube_fov = 360.0
        self._cube_cam_dist = 3.2
        self._light_dir = _normalize((0.4, -0.7, 0.6))

        # 큐브 전용 레이어/마스크(매 프레임 재사용) — 원형 링 내부에만 렌더링
        self._cube_layer = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        self._cube_mask = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        self._init_cube_mask()

        # 공-큐브 상호작용/상태
        self._ring_radius_px = int(96 * (self.width / 600.0))
        # 히스테리시스(경계 떨림 방지): 진입/이탈 반경을 다르게 사용
        self._ring_margin_px = max(2, int(12 * (self.width / 600.0)))
        self._ball_inside = False
        self._last_mark_ms = -99999
        self._mark_cooldown_ms = 600  # 0.6s 디바운스 (경계에서 다중 트리거 방지)
        # 누적 히트 카운트(전체가 점점 붉어짐) 및 폭발 임계치
        self._hit_count: int = 0
        self._hit_to_explode: int = 10
        # 진동/폭발/재생성 타이머
        self._vibrate_until_ms = 0
        self._vibrate_mode: str | None = None  # 'solve' 또는 None
        self._explosion_request = False
        self._hidden_until_ms = 0  # 폭발 후 비가시 기간(15초)
        self._rebuild_anim_ms = 0
        self._rebuild_total_ms = 1400  # 홀로그램 재조립 연출 길이
        # 레이저 녹는 애니메이션 (폭발 없이 사르르 녹음)
        self._laser_melt_ms = 0  # 남은 녹는 시간
        self._laser_melt_total_ms = 1200  # 녹는 애니메이션 총 시간
        # 홀로그램 스캔라인 레이어 캐시
        self._holo_layer = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        # 큐브 히트 신호(메인 루프에서 이펙트/사운드 처리)
        self._hit_events: list[tuple[int, int]] = []

    def update(self, elapsed_ms: int | float | None = None) -> None:
        """프레임마다 호출. elapsed_ms는 pygame clock 값(ms)"""

        if elapsed_ms is None:
            elapsed_ms = 16
        dt = (elapsed_ms or 0) / 1000.0
        self.time += dt

        for mote in self.light_motes:
            mote["x"] += mote["speed"] * dt
            mote["y"] += math.sin(self.time * 2.0 + mote["phase"]) * 0.5
            if mote["x"] > self.width + 40:
                mote["x"] = -40
                mote["y"] = random.uniform(self.height / 2 - 90, self.height / 2 + 110)
                mote["phase"] = random.uniform(0, math.tau)

        # 진동 기간/재생성 애니메이션 타임라인 업데이트
        now_ms = int(self.time * 1000)
        if self._rebuild_anim_ms > 0:
            self._rebuild_anim_ms = max(0, self._rebuild_anim_ms - int(elapsed_ms))
        # 레이저 녹는 애니메이션 업데이트
        if self._laser_melt_ms > 0:
            self._laser_melt_ms = max(0, self._laser_melt_ms - int(elapsed_ms))
            # 녹기 완료 → 숨김 상태로 전환
            if self._laser_melt_ms <= 0:
                self._hidden_until_ms = now_ms + random.randint(20000, 35000)  # 20~35초 후 재조립
                self._hit_count = 0
        # 숨김(폭발 후) 타임아웃이 끝났으면 재조립 시작
        if self._hidden_until_ms and now_ms >= self._hidden_until_ms:
            self._hidden_until_ms = 0
            self._rebuild_anim_ms = self._rebuild_total_ms
            # 상태 초기화(누적 히트/컬러 진행도 리셋)
            self._hit_count = 0
            # 재생성 시작 시 진입/쿨다운 상태 리셋
            self._ball_inside = False
            self._last_mark_ms = -99999

    def update_ball(self, ball_x: float, ball_y: float) -> None:
        # 중앙 원형 링 내부로 '진입'하는 순간만 카운트 + 히스테리시스/쿨다운 적용
        cx, cy = self.cube_center
        dx = ball_x - cx
        dy = ball_y - cy
        dist2 = dx * dx + dy * dy
        r_enter = max(1, self._ring_radius_px - self._ring_margin_px)
        r_exit = self._ring_radius_px + self._ring_margin_px
        # 히스테리시스 적용 판정
        if self._ball_inside:
            inside = dist2 <= (r_exit * r_exit)
        else:
            inside = dist2 <= (r_enter * r_enter)

        if inside and not self._ball_inside and self._is_visible():
            now_ms = int(self.time * 1000)
            if now_ms - self._last_mark_ms >= self._mark_cooldown_ms:
                self._mark_next_face_red()
                self._last_mark_ms = now_ms
                # 0.5초간 미세 진동 + 히트 신호 큐에 추가
                self._vibrate_until_ms = max(self._vibrate_until_ms or 0, now_ms + 500)
                self._hit_events.append((int(ball_x), int(ball_y)))
        self._ball_inside = inside

    def pop_hit_event(self) -> tuple[int, int] | None:
        if self._hit_events:
            return self._hit_events.pop(0)
        return None

    def pop_explosion_request(self) -> bool:
        if self._explosion_request:
            self._explosion_request = False
            return True
        return False

    def trigger_laser_melt(self) -> bool:
        """테트로미노 광선에 의한 강제 녹이기 (폭발 없이 사르르 녹음). 성공 시 True 반환."""
        now_ms = int(self.time * 1000)
        # 이미 숨김 중이면 무효
        if self._hidden_until_ms and now_ms < self._hidden_until_ms:
            return False
        # 이미 녹는 중이면 무효
        if self._laser_melt_ms > 0:
            return False
        # 녹는 애니메이션 시작 (폭발 없음!)
        self._laser_melt_ms = self._laser_melt_total_ms
        # 진동 상태 초기화
        self._vibrate_until_ms = 0
        self._vibrate_mode = None
        # 재조립 중이었다면 취소
        self._rebuild_anim_ms = 0
        return True

    def is_cube_active(self) -> bool:
        """큐브가 활성 상태인지 확인 (레이저 타겟 가능 여부)."""
        now_ms = int(self.time * 1000)
        # 숨김 중이면 비활성
        if self._hidden_until_ms and now_ms < self._hidden_until_ms:
            return False
        # 녹는 중이면 비활성
        if self._laser_melt_ms > 0:
            return False
        # 재조립 중이어도 타겟 가능 (재조립 중이면 즉시 다시 녹일 수 있음)
        return True

    def is_melting(self) -> bool:
        """현재 녹는 애니메이션 중인지 확인."""
        return self._laser_melt_ms > 0

    def get_melt_progress(self) -> float:
        """녹는 진행도 반환 (0.0 = 시작, 1.0 = 완료)."""
        if self._laser_melt_ms <= 0:
            return 0.0
        return 1.0 - (self._laser_melt_ms / self._laser_melt_total_ms)

    def _is_visible(self) -> bool:
        # 숨김 중이 아니면 표시 (녹는 중도 표시됨)
        now_ms = int(self.time * 1000)
        return not (self._hidden_until_ms and now_ms < self._hidden_until_ms)

    def _mark_next_face_red(self) -> None:
        # 이미 진동/숨김/재조립이면 무시
        now_ms = int(self.time * 1000)
        if self._vibrate_until_ms and now_ms < self._vibrate_until_ms:
            return
        if self._hidden_until_ms and now_ms < self._hidden_until_ms:
            return
        if self._rebuild_anim_ms > 0:
            return
        # 전체가 조금씩 붉어지는 누적 히트 증가
        self._hit_count = min(self._hit_to_explode, self._hit_count + 1)
        # 임계치 도달 시 1초 진동 후 폭발
        if self._hit_count >= self._hit_to_explode:
            self._vibrate_until_ms = now_ms + 1000
            self._vibrate_mode = 'solve'
            # 폭발은 진동 끝날 때 draw()에서 1회 트리거


    def draw(self, surface: pygame.Surface, *, offset: Tuple[int, int] = (0, 0)) -> None:
        """애니메이션 레이어를 그린다.

        Args:
            surface: 대상 Surface (보통 SCREEN 또는 사본)
            offset: 전체 배경이 이동할 때의 오프셋 (스크린 흔들림 등)
        """

        ox, oy = offset
        # 캐시된 오버레이 Surface 재사용 (매 프레임 새로 생성하지 않음)
        if not hasattr(self, '_overlay_cache') or self._overlay_cache is None:
            self._overlay_cache = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        overlay = self._overlay_cache
        overlay.fill((0, 0, 0, 0))  # 투명하게 클리어

        # 배경형 오버레이(반투명 요소)
        self._draw_torch_glow(overlay)
        self._draw_light_band(overlay)
        self._draw_motes(overlay)

        # 먼저 배경 오버레이를 그린 뒤, 큐브는 최상단에 직접 블릿하여 완전 불투명 보장
        surface.blit(overlay, (ox, oy))
        if self.cube_enabled and self._is_visible():
            self._draw_center_cube(surface, base_offset=(ox, oy))

        # 테두리 (마지막에 그려서 위에 표시)
        self._draw_border(surface)

    def _draw_border(self, surface: pygame.Surface) -> None:
        """중세 요새 테마 테두리 그리기"""
        border_thickness = 10
        # SCREEN Surface 전체를 감싸는 테두리 (SCREEN은 이미 게임 전체 영역)
        x_off = 0
        game_w = self.width
        h = self.height

        # 기본 테두리 색상 (진한 보라/청색 - 테트리스 테마)
        base_color = (40, 50, 80)  # 어두운 청보라
        inner_color = (60, 80, 120)  # 밝은 청보라
        glow_accent = (120, 170, 255)  # 밝은 파란색 악센트

        # 메인 테두리
        pygame.draw.rect(surface, base_color, (x_off, 0, game_w, border_thickness))
        pygame.draw.rect(surface, base_color, (x_off, h - border_thickness, game_w, border_thickness))
        pygame.draw.rect(surface, base_color, (x_off, 0, border_thickness, h))
        pygame.draw.rect(surface, base_color, (x_off + game_w - border_thickness, 0, border_thickness, h))

        # 내부 테두리 (깊이감)
        inner_thickness = 2
        pygame.draw.rect(surface, inner_color,
                        (x_off + border_thickness - inner_thickness, border_thickness - inner_thickness,
                         game_w - 2*(border_thickness - inner_thickness), inner_thickness))
        pygame.draw.rect(surface, inner_color,
                        (x_off + border_thickness - inner_thickness, h - border_thickness,
                         game_w - 2*(border_thickness - inner_thickness), inner_thickness))
        pygame.draw.rect(surface, inner_color,
                        (x_off + border_thickness - inner_thickness, border_thickness - inner_thickness,
                         inner_thickness, h - 2*(border_thickness - inner_thickness)))
        pygame.draw.rect(surface, inner_color,
                        (x_off + game_w - border_thickness, border_thickness - inner_thickness,
                         inner_thickness, h - 2*(border_thickness - inner_thickness)))

        # 코너 장식
        corner_radius = 5
        # 좌상단
        pygame.draw.circle(surface, glow_accent, (x_off + border_thickness//2, border_thickness//2), corner_radius)
        # 우상단
        pygame.draw.circle(surface, glow_accent, (x_off + game_w - border_thickness//2, border_thickness//2), corner_radius)
        # 좌하단
        pygame.draw.circle(surface, glow_accent, (x_off + border_thickness//2, h - border_thickness//2), corner_radius)
        # 우하단
        pygame.draw.circle(surface, glow_accent, (x_off + game_w - border_thickness//2, h - border_thickness//2), corner_radius)

    # ------------------------------------------------------------------
    # 내부 헬퍼
    # ------------------------------------------------------------------
    def _draw_torch_glow(self, overlay: pygame.Surface) -> None:
        # 최적화: 팔레트와 레이어 수 줄임 (4→2), circle 호출 최소화
        prism_palette = [
            (120, 200, 255),
            (255, 180, 120),
        ]

        for index, (x, y) in enumerate(self.torch_positions):
            wobble = 0.4 + 0.3 * math.sin(self.time * 6.0 + index * 1.7)
            base_radius = 28 + 2 * math.sin(self.time * 4.3 + index)

            # 최적화: 레이어 2개만 렌더링
            for layer, color in enumerate(prism_palette):
                layer_radius = base_radius * (1.0 + layer * 0.35)
                alpha = int(70 + 35 * wobble - layer * 12)
                if alpha > 0:
                    pygame.draw.circle(overlay, (*color, alpha), (x, y - 4), int(layer_radius))

            core_alpha = int(180 + 50 * wobble)
            pygame.draw.circle(overlay, (255, 236, 200, core_alpha), (x, y - 6), 14)

            # 최적화: 헤일로 링은 wobble이 높을 때만 그림
            if wobble > 0.5:
                halo_radius = base_radius * 1.8
                halo_alpha = int(50 + 40 * wobble)
                pygame.draw.circle(overlay, (120, 200, 255, halo_alpha), (x, y - 6), int(halo_radius), width=2)

    def _draw_light_band(self, overlay: pygame.Surface) -> None:
        sweep = (self.time * 120) % (self.width + self.band_width) - self.band_width
        overlay.blit(
            self._prerendered_band,
            (int(sweep), self.band_top),
            special_flags=pygame.BLEND_PREMULTIPLIED,
        )

    def _draw_motes(self, overlay: pygame.Surface) -> None:
        for mote in self.light_motes:
            wobble = math.sin(self.time * 3.0 + mote["phase"])
            radius = mote["radius"] + wobble * 0.4
            alpha = int(80 + 40 * wobble)
            pygame.draw.circle(
                overlay,
                (170, 220, 255, alpha),
                (int(mote["x"]), int(mote["y"])),
                max(1, int(radius)),
            )

    # ------------------------------------------------------------------
    # 중앙 회전 큐브 (의사 3D)
    # ------------------------------------------------------------------
    def _init_cube_mask(self) -> None:
        # stage7 배경 생성 스크립트 기준(600x750, 링 반경 96px)을 해상도에 맞춰 스케일
        cx, cy = self.cube_center
        rx = int(96 * (self.width / 600.0))
        ry = rx  # 원형 유지 (배경도 균등 스케일 가정)
        self._cube_mask.fill((0, 0, 0, 0))
        pygame.draw.circle(self._cube_mask, (255, 255, 255, 255), (cx, cy), min(rx, ry))

    def _draw_center_cube(self, target_surface: pygame.Surface, *, base_offset: tuple[int, int] = (0, 0)) -> None:
        # 녹는 진행도 계산
        melt_progress = 0.0
        if self._laser_melt_ms > 0:
            melt_progress = 1.0 - (self._laser_melt_ms / max(1, self._laser_melt_total_ms))

        # 느린 회전 속도 + 진동 시 오프셋 흔들림
        # 녹을 때는 회전이 빨라지고 불규칙해짐
        melt_spin = melt_progress * 3.0  # 녹을수록 빠르게 회전
        ang_y = self.time * (0.55 + melt_spin)
        ang_x = self.time * (0.35 + melt_spin * 0.7)
        rot_y = _rot_y(ang_y)
        rot_x = _rot_x(ang_x)

        # 정점 회전 + 스케일 + 투영
        # 너무 작은 값도 반영되도록 최소값을 낮춤(부동소수 스케일 허용)
        # 녹을 때 크기 감소
        shrink = 1.0 - melt_progress * 0.6  # 최대 60% 축소
        size = max(0.05, self.cube_size * self.cube_scale * shrink)
        offx, offy = self.cube_center_offset

        # 진동 중이면 무작위 지터 적용
        now_ms = int(self.time * 1000)
        if self._vibrate_until_ms and now_ms < self._vibrate_until_ms:
            jitter = 2 + max(0, int((self._vibrate_until_ms - now_ms) * 0.003))  # 끝날수록 약해짐
            offx += random.randint(-jitter, jitter)
            offy += random.randint(-jitter, jitter)

        # 녹을 때 아래로 내려감 + 울렁거림
        if melt_progress > 0:
            # 아래로 서서히 내려감
            offy += int(melt_progress * 50)
            # 큰 울렁거림 (전체가 흔들림)
            wobble_intensity = melt_progress * 8
            offx += int(math.sin(self.time * 12) * wobble_intensity)
            offy += int(math.cos(self.time * 10) * wobble_intensity * 0.5)

        cx, cy = (self.cube_center[0] + offx, self.cube_center[1] + offy)
        projected: list[tuple[float, float, float]] = []  # (px, py, z)

        for idx, (vx, vy, vz) in enumerate(self._cube_vertices):
            # 녹을 때 정점별 왜곡 (울렁거리는 효과)
            if melt_progress > 0:
                # 각 정점마다 다른 위상으로 울렁거림
                phase = idx * 0.8
                wobble_t = self.time * 8 + phase
                wobble_amt = melt_progress * 0.4  # 녹을수록 심하게 울렁
                vx += math.sin(wobble_t) * wobble_amt
                vy += math.cos(wobble_t * 1.3) * wobble_amt
                vz += math.sin(wobble_t * 0.9) * wobble_amt
                # 아래쪽 정점은 더 많이 늘어남 (녹아내리는 느낌)
                if vy > 0:  # 아래쪽 정점
                    vy += melt_progress * 0.5  # 아래로 늘어남

            # 회전
            x1, y1, z1 = _mat_vec_mul(rot_y, (vx, vy, vz))
            x2, y2, z2 = _mat_vec_mul(rot_x, (x1, y1, z1))
            # 카메라 변환(전방 +z)
            zc = z2 + self._cube_cam_dist
            # 단순 원근 투영
            f = self._cube_fov / max(0.001, zc)
            px = cx + x2 * f * (size * 0.5)
            py = cy + y2 * f * (size * 0.5)
            projected.append((px, py, zc))

        # 페인터스 알고리즘: 면을 z 평균으로 뒤→앞 정렬
        face_order = sorted(
            self._cube_faces,
            key=lambda face: sum(projected[i][2] for i in face) / 4.0,
            reverse=True,
        )

        # 큐브 전용 레이어에만 그린 뒤, 원형 마스크로 클리핑하여 최종 surface에 합성
        self._cube_layer.fill((0, 0, 0, 0))
        # 바닥 원형 하이라이트(원형 링 내부 강조)
        base_alpha = 55
        base_radius = int(size * 0.95)
        pygame.draw.circle(self._cube_layer, (120, 200, 255, base_alpha), (cx, cy), base_radius)
        pygame.draw.circle(self._cube_layer, (180, 230, 255, base_alpha + 20), (cx, cy), int(base_radius * 0.6))

        # 면 채우기 + 라이트 셰이딩
        for face in face_order:
            i0, i1, i2, i3 = face
            p0 = projected[i0]
            p1 = projected[i1]
            p2 = projected[i2]
            p3 = projected[i3]
            poly = [(p0[0], p0[1]), (p1[0], p1[1]), (p2[0], p2[1]), (p3[0], p3[1])]

            # 면 노멀 계산
            # 2D 투영 좌표로는 정확한 노멀 산출이 어렵기 때문에,
            # 모델 공간 고정 노멀을 회전 행렬로 변환해 사용한다.
            # 시각적 안정성을 위해 고정된 면 노멀을 회전 행렬로 변환하여 사용한다.
            face_normal_model = _face_normal(face)
            nx, ny, nz = _mat_vec_mul(rot_x, _mat_vec_mul(rot_y, face_normal_model))
            n = _normalize((nx, ny, nz))
            light = max(0.0, _dot(n, self._light_dir))

            # 네온 블루→레드로 전체가 점차 붉어지도록 보간
            base_blue = (100, 170, 255)
            target_red = (255, 80, 80)
            target_purple = (200, 80, 255)  # 녹을 때 보라색으로
            hit_progress = min(1.0, self._hit_count / max(1, self._hit_to_explode))

            # 녹을 때는 보라색으로 변함
            if melt_progress > 0:
                # 현재 색상에서 보라색으로 전환
                current_col = (
                    int(base_blue[0] + (target_red[0] - base_blue[0]) * hit_progress),
                    int(base_blue[1] + (target_red[1] - base_blue[1]) * hit_progress),
                    int(base_blue[2] + (target_red[2] - base_blue[2]) * hit_progress),
                )
                base_col = (
                    int(current_col[0] + (target_purple[0] - current_col[0]) * melt_progress),
                    int(current_col[1] + (target_purple[1] - current_col[1]) * melt_progress),
                    int(current_col[2] + (target_purple[2] - current_col[2]) * melt_progress),
                )
            else:
                base_col = (
                    int(base_blue[0] + (target_red[0] - base_blue[0]) * hit_progress),
                    int(base_blue[1] + (target_red[1] - base_blue[1]) * hit_progress),
                    int(base_blue[2] + (target_red[2] - base_blue[2]) * hit_progress),
                )

            shade = 0.35 + 0.65 * light
            # 녹을 때 투명도 감소
            face_alpha = int(255 * (1.0 - melt_progress * 0.85))
            col = (
                int(base_col[0] * shade),
                int(base_col[1] * shade),
                int(base_col[2] * shade),
                face_alpha,
            )
            pygame.draw.polygon(self._cube_layer, col, poly)

        # 외곽선 그리기(가독성 향상). 얇은 라인 2중 처리로 네온 느낌
        edge_points = {idx: (projected[idx][0], projected[idx][1]) for idx in range(len(projected))}
        # 작은 큐브에서 외곽선이 과해 보이지 않도록 두께를 스케일에 맞춤
        line_w_main = 1 if size < 12 else 2
        line_w_glow = 2 if size < 12 else 4
        # 녹을 때 외곽선도 페이드아웃 + 보라색으로 변함
        edge_alpha_main = int(170 * (1.0 - melt_progress * 0.9))
        edge_alpha_glow = int(110 * (1.0 - melt_progress * 0.9))
        if melt_progress > 0:
            edge_color_main = (
                int(220 + (200 - 220) * melt_progress),
                int(240 + (100 - 240) * melt_progress),
                int(255 + (255 - 255) * melt_progress),
                edge_alpha_main,
            )
            edge_color_glow = (
                int(120 + (180 - 120) * melt_progress),
                int(200 + (80 - 200) * melt_progress),
                255,
                edge_alpha_glow,
            )
        else:
            edge_color_main = (220, 240, 255, edge_alpha_main)
            edge_color_glow = (120, 200, 255, edge_alpha_glow)

        for a, b in self._cube_edges:
            ax, ay = edge_points[a]
            bx, by = edge_points[b]
            pygame.draw.line(self._cube_layer, edge_color_main, (ax, ay), (bx, by), line_w_main)
            pygame.draw.line(self._cube_layer, edge_color_glow, (ax, ay), (bx, by), line_w_glow)

        # 홀로그램 재조립 연출: 스캔라인/페이드
        if self._rebuild_anim_ms > 0:
            k = 1.0 - (self._rebuild_anim_ms / max(1, self._rebuild_total_ms))
            self._apply_hologram_effect(self._cube_layer, intensity=k)

        # 녹는 파티클 효과 (물방울)
        if melt_progress > 0:
            self._apply_melt_effect(self._cube_layer, progress=melt_progress, center=(cx, cy))

        # 원형 마스크 적용(큐브 영역만 남김)
        self._cube_layer.blit(self._cube_mask, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
        ox, oy = base_offset
        target_surface.blit(self._cube_layer, (ox, oy))

        # 진동 종료 처리: 'solve' 모드에서만 폭발 요청
        if self._vibrate_until_ms and now_ms >= self._vibrate_until_ms:
            self._vibrate_until_ms = 0
            if self._vibrate_mode == 'solve':
                self._explosion_request = True
                # 재생성까지의 숨김 시간: 25~45초 랜덤
                self._hidden_until_ms = now_ms + random.randint(25000, 45000)
            self._vibrate_mode = None

    def _apply_hologram_effect(self, target: pygame.Surface, *, intensity: float) -> None:
        # intensity: 0(시작) → 1(완료). 스캔라인/그리드/페이드인을 혼합.
        self._holo_layer.fill((0, 0, 0, 0))
        alpha = int(120 * (1.0 - intensity))
        step = max(4, int(10 - 8 * intensity))
        color = (120, 200, 255, alpha)
        for y in range(0, self.height, step):
            pygame.draw.line(self._holo_layer, color, (0, y), (self.width, y))
        # 약한 그리드
        if intensity < 0.7:
            grid_alpha = int(60 * (1.0 - intensity / 0.7))
            grid_color = (120, 200, 255, grid_alpha)
            for x in range(0, self.width, step * 2):
                pygame.draw.line(self._holo_layer, grid_color, (x, 0), (x, self.height))
        # 알파를 보존하기 위해 RGB 채널만 가산합성
        target.blit(self._holo_layer, (0, 0), special_flags=pygame.BLEND_RGB_ADD)

    def _apply_melt_effect(self, target: pygame.Surface, *, progress: float, center: tuple[int, int]) -> None:
        """녹는 효과 파티클: 떨어지는 물방울 효과만 추가 (메인 녹는 효과는 3D 렌더링에서 처리됨).

        Args:
            target: 큐브가 그려진 레이어
            progress: 0.0(시작) → 1.0(완전히 녹음)
            center: 큐브 중심 좌표 (cx, cy)
        """
        cx, cy = center

        # 떨어지는 물방울 파티클
        if progress > 0.15 and progress < 0.95:
            num_drops = int(12 * progress)
            for i in range(num_drops):
                # 중심 주변에서 떨어지는 물방울
                drop_x = cx + random.randint(-35, 35)
                drop_y = cy + int(30 + progress * 80) + random.randint(0, 40)
                drop_size = random.randint(2, 5)
                drop_alpha = int(180 * (1.0 - progress * 0.8))
                drop_color = (200, 100, 255, drop_alpha)
                pygame.draw.circle(target, drop_color, (drop_x, drop_y), drop_size)


# ----------------------------- 수학 유틸 ------------------------------
def _rot_y(theta: float) -> tuple[tuple[float, float, float], ...]:
    c, s = math.cos(theta), math.sin(theta)
    return ((c, 0.0, s), (0.0, 1.0, 0.0), (-s, 0.0, c))


def _rot_x(theta: float) -> tuple[tuple[float, float, float], ...]:
    c, s = math.cos(theta), math.sin(theta)
    return ((1.0, 0.0, 0.0), (0.0, c, -s), (0.0, s, c))


def _mat_vec_mul(m: tuple[tuple[float, float, float], ...], v: tuple[float, float, float]) -> tuple[float, float, float]:
    (x, y, z) = v
    return (
        m[0][0] * x + m[0][1] * y + m[0][2] * z,
        m[1][0] * x + m[1][1] * y + m[1][2] * z,
        m[2][0] * x + m[2][1] * y + m[2][2] * z,
    )


def _normalize(v: tuple[float, float, float]) -> tuple[float, float, float]:
    x, y, z = v
    mag = math.sqrt(x * x + y * y + z * z) or 1.0
    return (x / mag, y / mag, z / mag)


def _dot(a: tuple[float, float, float], b: tuple[float, float, float]) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _face_normal(face: tuple[int, int, int, int]) -> tuple[float, float, float]:
    # 모델 공간 기준 고정 노멀(단위 큐브 좌표계)
    # faces 순서(back, front, top, bottom, right, left)
    idx = (
        (0, 0, -1),   # back  z-
        (0, 0, 1),    # front z+
        (0, -1, 0),   # top   y-
        (0, 1, 0),    # bottom y+
        (1, 0, 0),    # right x+
        (-1, 0, 0),   # left  x-
    )
    # face는 튜플이므로 해당 면을 통해 매핑. 단, 면의 위치에 의존하지 않고
    # 위 순서를 그대로 사용한다.
    # 안전하게 매핑하기 위해 길이와 모양을 비교하여 인덱스를 찾는다.
    faces_ref = [
        (0, 1, 2, 3),
        (4, 5, 6, 7),
        (0, 1, 5, 4),
        (3, 2, 6, 7),
        (1, 2, 6, 5),
        (0, 3, 7, 4),
    ]
    try:
        k = faces_ref.index(face)
    except ValueError:
        k = 1  # 기본값: front
    return idx[k]
