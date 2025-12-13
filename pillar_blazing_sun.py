# -*- coding: utf-8 -*-
"""
붉게 타오르는 태양 필러 배경 (로딩 화면용)
게임 화면 테두리를 불타오르는 태양 표면 스타일로 장식
로딩 진행률에 따라 점진적으로 더 강렬하게 타오름
- 실제 태양 표면처럼 이글거리는 플라즈마 질감
- 코로나, 플레어, 플라즈마 소용돌이 효과
- start.png 아트워크 배경 레이어 지원
"""

import math
import random
import os
import sys
import platform
import pygame


def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)


# 플랫폼 감지
_is_macos = platform.system() == 'Darwin'


class BlazingSunFrame:
    """붉게 타오르는 태양 표면 테두리 필러"""

    def __init__(self, screen_width: int, screen_height: int,
                 game_width: int, game_height: int):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        # 게임 영역 위치 (중앙)
        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        # 애니메이션 시간
        self.time = 0.0

        # 로딩 진행률 (0.0 ~ 1.0)
        self.intensity = 0.0

        # 플라즈마 셀 (태양 표면의 대류 셀)
        self.plasma_cells = []
        self._init_plasma_cells()

        # 태양 플레어 (폭발적인 분출)
        self.flares = []
        self._init_flares()

        # 코로나 가닥 (외곽의 가는 불꽃 줄기)
        self.corona_strands = []
        self._init_corona_strands()

        # 떠다니는 불꽃 파티클
        self.fire_particles = []

        # 노이즈 오프셋 (플라즈마 움직임용)
        self.noise_offset = random.uniform(0, 1000)

        # 아트워크 필러 (start.png)
        self._artwork_surface = None
        self._left_pillar_surface = None
        self._right_pillar_surface = None
        self._artwork_loaded = False

        # 캐시: 알파값별 미리 렌더링된 필러 서피스 (copy() 호출 제거)
        self._cached_left_pillars = {}  # {alpha: surface}
        self._cached_right_pillars = {}  # {alpha: surface}
        self._alpha_cache_step = 15  # 15단위로 캐싱 (성능과 메모리 균형)

        # 그라데이션 원형 캐시 (패치/플라즈마 셀용)
        self._gradient_circle_cache = {}  # {(size, intensity_bucket): surface}

        # 첫 프레임 최적화: 복잡한 효과 점진적 활성화
        self._frame_count = 0
        self._warmup_frames = 5  # 첫 5프레임은 단순 렌더링

        self._load_artwork()

    def _load_artwork(self):
        """start.png 아트워크 로드 및 필러 서피스 생성"""
        try:
            artwork_path = resource_path("start.png")
            if os.path.exists(artwork_path):
                self._artwork_surface = pygame.image.load(artwork_path).convert()
                self._create_artwork_pillars()
                self._artwork_loaded = True
                print(f"[BlazingSun] 아트워크 로드 완료: {self._artwork_surface.get_size()}")
            else:
                print(f"[BlazingSun] 아트워크 파일 없음: {artwork_path}")
        except Exception as e:
            print(f"[BlazingSun] 아트워크 로드 실패: {e}")
            self._artwork_surface = None

    def _create_artwork_pillars(self):
        """아트워크에서 좌우 필러 서피스 생성"""
        if self._artwork_surface is None:
            return

        # 아트워크 크기
        art_w, art_h = self._artwork_surface.get_size()

        # 화면 높이에 맞춰 스케일 계산
        scale = self.screen_height / art_h
        scaled_w = int(art_w * scale)
        scaled_h = self.screen_height

        # 스케일된 아트워크
        if _is_macos:
            scaled_artwork = pygame.transform.scale(
                self._artwork_surface, (scaled_w, scaled_h)
            )
        else:
            scaled_artwork = pygame.transform.smoothscale(
                self._artwork_surface, (scaled_w, scaled_h)
            )

        # 왼쪽 필러 (아트워크 왼쪽 부분)
        left_width = self.game_x
        if left_width > 0:
            self._left_pillar_surface = pygame.Surface(
                (left_width, self.screen_height), pygame.SRCALPHA
            )
            # 아트워크 왼쪽 부분 추출
            self._left_pillar_surface.blit(scaled_artwork, (0, 0),
                (0, 0, left_width, self.screen_height))

        # 오른쪽 필러 (아트워크 오른쪽 부분)
        right_width = self.screen_width - self.game_x - self.game_width
        if right_width > 0:
            self._right_pillar_surface = pygame.Surface(
                (right_width, self.screen_height), pygame.SRCALPHA
            )
            # 아트워크 오른쪽 부분 추출
            src_x = max(0, scaled_w - right_width)
            self._right_pillar_surface.blit(scaled_artwork, (0, 0),
                (src_x, 0, right_width, self.screen_height))

    def _init_plasma_cells(self):
        """태양 표면의 플라즈마 대류 셀 초기화"""
        # 테두리 영역에 플라즈마 셀 배치
        self.plasma_cells = []

        # 상단 테두리
        for i in range(20):
            self.plasma_cells.append({
                'x': random.uniform(0, self.screen_width),
                'y': random.uniform(0, self.game_y),
                'radius': random.uniform(15, 45),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(0.5, 1.5),
                'turbulence': random.uniform(0.3, 0.8),
            })

        # 하단 테두리
        for i in range(20):
            self.plasma_cells.append({
                'x': random.uniform(0, self.screen_width),
                'y': random.uniform(self.game_y + self.game_height, self.screen_height),
                'radius': random.uniform(15, 45),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(0.5, 1.5),
                'turbulence': random.uniform(0.3, 0.8),
            })

        # 좌측 테두리
        for i in range(15):
            self.plasma_cells.append({
                'x': random.uniform(0, self.game_x),
                'y': random.uniform(0, self.screen_height),
                'radius': random.uniform(15, 40),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(0.5, 1.5),
                'turbulence': random.uniform(0.3, 0.8),
            })

        # 우측 테두리
        for i in range(15):
            self.plasma_cells.append({
                'x': random.uniform(self.game_x + self.game_width, self.screen_width),
                'y': random.uniform(0, self.screen_height),
                'radius': random.uniform(15, 40),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(0.5, 1.5),
                'turbulence': random.uniform(0.3, 0.8),
            })

    def _init_flares(self):
        """태양 플레어 초기화 - 폭발적 분출"""
        num_flares = 16
        for i in range(num_flares):
            angle = (i / num_flares) * math.pi * 2
            self.flares.append({
                'angle': angle,
                'base_length': random.uniform(20, 60),
                'width': random.uniform(8, 25),
                'speed': random.uniform(0.8, 2.0),
                'phase': random.uniform(0, math.pi * 2),
                'intensity': random.uniform(0.5, 1.0),
                'active': random.random() > 0.3,  # 70% 확률로 활성
            })

    def _init_corona_strands(self):
        """코로나 가닥 초기화 - 외곽의 가느다란 불꽃"""
        num_strands = 80
        for i in range(num_strands):
            # 테두리 전체에 분포
            side = random.choice(['top', 'bottom', 'left', 'right'])
            if side == 'top':
                x = random.uniform(0, self.screen_width)
                y = 0
                angle = math.pi / 2 + random.uniform(-0.3, 0.3)
            elif side == 'bottom':
                x = random.uniform(0, self.screen_width)
                y = self.screen_height
                angle = -math.pi / 2 + random.uniform(-0.3, 0.3)
            elif side == 'left':
                x = 0
                y = random.uniform(0, self.screen_height)
                angle = 0 + random.uniform(-0.3, 0.3)
            else:
                x = self.screen_width
                y = random.uniform(0, self.screen_height)
                angle = math.pi + random.uniform(-0.3, 0.3)

            self.corona_strands.append({
                'x': x,
                'y': y,
                'angle': angle,
                'length': random.uniform(15, 50),
                'thickness': random.uniform(1, 4),
                'speed': random.uniform(1, 3),
                'phase': random.uniform(0, math.pi * 2),
                'wave_amp': random.uniform(2, 8),
            })

    def set_intensity(self, intensity: float):
        """강렬함 설정 (0.0 ~ 1.0, 로딩 진행률과 연동)"""
        self.intensity = max(0.0, min(1.0, intensity))

    def update(self, dt: float):
        """애니메이션 업데이트"""
        self.time += dt
        self.noise_offset += dt * 0.5

        # 프레임 카운트 증가 (첫 프레임 최적화용)
        self._frame_count += 1

        # 플라즈마 셀 업데이트
        for cell in self.plasma_cells:
            # 위치 약간 흔들림
            cell['current_x'] = cell['x'] + math.sin(self.time * cell['speed'] + cell['phase']) * 5
            cell['current_y'] = cell['y'] + math.cos(self.time * cell['speed'] * 0.7 + cell['phase']) * 5
            # 크기 펄스
            cell['current_radius'] = cell['radius'] * (0.8 + 0.4 * math.sin(self.time * cell['speed'] * 2 + cell['phase']))

        # 플레어 업데이트
        for flare in self.flares:
            wave = math.sin(self.time * flare['speed'] + flare['phase'])
            flare['current_length'] = flare['base_length'] * (0.5 + 0.8 * (wave * 0.5 + 0.5))
            flare['current_length'] *= (0.2 + self.intensity * 1.5)

            # 랜덤하게 플레어 활성화/비활성화
            if random.random() < 0.002:
                flare['active'] = not flare['active']

        # 불꽃 파티클 생성
        spawn_rate = 0.15 + self.intensity * 0.5
        if random.random() < spawn_rate:
            self._spawn_fire_particle()

        # 불꽃 파티클 업데이트
        for p in self.fire_particles[:]:
            p['life'] -= dt
            p['y'] += p['vy'] * dt * 60
            p['x'] += p['vx'] * dt * 60
            p['x'] += math.sin(self.time * 4 + p['phase']) * p['wobble'] * 0.5
            p['size'] *= 0.97
            p['vy'] *= 0.98

            if p['life'] <= 0 or p['size'] < 0.5:
                self.fire_particles.remove(p)

    def _spawn_fire_particle(self):
        """불꽃 파티클 생성"""
        if len(self.fire_particles) > 150:
            return

        # 테두리 위치에서 생성
        side = random.choice(['top', 'bottom', 'left', 'right'])

        if side == 'top' and self.game_y > 10:
            x = random.uniform(0, self.screen_width)
            y = random.uniform(5, self.game_y - 5)
            vx = random.uniform(-0.5, 0.5)
            vy = random.uniform(0.5, 2)
        elif side == 'bottom' and self.game_y > 10:
            x = random.uniform(0, self.screen_width)
            y = random.uniform(self.game_y + self.game_height + 5, self.screen_height - 5)
            vx = random.uniform(-0.5, 0.5)
            vy = random.uniform(-2, -0.5)
        elif side == 'left' and self.game_x > 10:
            x = random.uniform(5, self.game_x - 5)
            y = random.uniform(0, self.screen_height)
            vx = random.uniform(0.5, 2)
            vy = random.uniform(-0.5, 0.5)
        elif side == 'right' and self.game_x > 10:
            x = random.uniform(self.game_x + self.game_width + 5, self.screen_width - 5)
            y = random.uniform(0, self.screen_height)
            vx = random.uniform(-2, -0.5)
            vy = random.uniform(-0.5, 0.5)
        else:
            return

        base_size = 2 + self.intensity * 6

        self.fire_particles.append({
            'x': x,
            'y': y,
            'vx': vx,
            'vy': vy,
            'size': random.uniform(base_size * 0.5, base_size * 1.5),
            'life': random.uniform(0.3, 1.2),
            'phase': random.uniform(0, math.pi * 2),
            'wobble': random.uniform(0.5, 2),
            'heat': random.uniform(0.5, 1.0),  # 열기 (색상 결정)
        })

    def _get_plasma_color(self, heat: float, variance: float = 0.0):
        """플라즈마/태양 표면 색상 반환"""
        heat = max(0, min(1, heat + variance))

        # 강렬함에 따른 전체 밝기 조절
        brightness = 0.3 + self.intensity * 0.7

        if self.intensity < 0.2:
            # 초반: 어두운 적색/암적색
            r = int((80 + heat * 60) * brightness)
            g = int((15 + heat * 20) * brightness)
            b = int((5 + heat * 10) * brightness)
        elif self.intensity < 0.5:
            # 중반: 주황색/적색
            t = (self.intensity - 0.2) / 0.3
            r = int((120 + heat * 80 + t * 50) * brightness)
            g = int((30 + heat * 40 + t * 30) * brightness)
            b = int((5 + heat * 15) * brightness)
        elif self.intensity < 0.8:
            # 후반: 밝은 주황/노랑
            t = (self.intensity - 0.5) / 0.3
            r = int((200 + heat * 55) * brightness)
            g = int((80 + heat * 80 + t * 60) * brightness)
            b = int((10 + heat * 30 + t * 30) * brightness)
        else:
            # 최대: 백열/노란 백색
            t = (self.intensity - 0.8) / 0.2
            r = int((240 + heat * 15) * brightness)
            g = int((160 + heat * 60 + t * 35) * brightness)
            b = int((40 + heat * 60 + t * 80) * brightness)

        return (min(255, r), min(255, g), min(255, b))

    def draw(self, surface: pygame.Surface, clear_game_area: bool = True, draw_artwork: bool = True, artwork_opacity: float = 1.0):
        """전체 렌더링

        Args:
            surface: 렌더링할 서피스
            clear_game_area: 게임 영역을 검게 클리어할지 여부
            draw_artwork: 아트워크 필러(start.png)를 그릴지 여부
            artwork_opacity: 아트워크 투명도 조절 (0.0~1.0, 기본값 1.0)
        """
        self._artwork_opacity = artwork_opacity
        # 1. 기본 배경 (어두운 적색)
        self._draw_base_background(surface)

        # 2. 플라즈마 대류 셀 (태양 표면 질감)
        self._draw_plasma_cells(surface)

        # 3. 코로나 가닥 (외곽 불꽃 줄기)
        self._draw_corona_strands(surface)

        # 4. 태양 플레어 (분출)
        self._draw_flares(surface)

        # 5. 불꽃 파티클
        self._draw_fire_particles(surface)

        # 6. 아트워크 필러 (start.png) - 태양 효과 위에 블렌딩 (옵션)
        if draw_artwork:
            self._draw_artwork_pillars(surface)

        # 7. 게임 영역은 자연스러운 원형 비네트로 어둡게 (사각형 박스 제거)
        if clear_game_area:
            self._draw_vignette_fade(surface)

    def _get_cached_pillar(self, is_left: bool, alpha: int) -> pygame.Surface | None:
        """알파값에 해당하는 캐시된 필러 서피스 반환 (없으면 생성)"""
        # 알파값을 스텝 단위로 정규화
        cached_alpha = (alpha // self._alpha_cache_step) * self._alpha_cache_step
        cached_alpha = max(0, min(255, cached_alpha))

        cache = self._cached_left_pillars if is_left else self._cached_right_pillars
        source = self._left_pillar_surface if is_left else self._right_pillar_surface

        if source is None:
            return None

        if cached_alpha not in cache:
            # 캐시에 없으면 새로 생성
            cached_surf = source.copy()
            cached_surf.set_alpha(cached_alpha)
            cache[cached_alpha] = cached_surf

        return cache[cached_alpha]

    def _draw_artwork_pillars(self, surface: pygame.Surface):
        """아트워크 필러 그리기 - 태양 효과 위에 블렌딩 (캐시 사용)"""
        if not self._artwork_loaded:
            return

        # 진행률에 따라 아트워크 표시 (점점 더 잘 보임)
        opacity_mult = getattr(self, '_artwork_opacity', 1.0)
        base_alpha = int(50 + self.intensity * 150)  # 50 ~ 200
        artwork_alpha = int(base_alpha * opacity_mult)

        # 왼쪽 필러 (캐시된 서피스 사용 - copy() 제거)
        left_surf = self._get_cached_pillar(True, artwork_alpha)
        if left_surf is not None:
            surface.blit(left_surf, (0, 0))

        # 오른쪽 필러 (캐시된 서피스 사용 - copy() 제거)
        right_surf = self._get_cached_pillar(False, artwork_alpha)
        if right_surf is not None:
            right_x = self.game_x + self.game_width
            surface.blit(right_surf, (right_x, 0))

    def _get_cached_gradient_circle(self, size: int, intensity_key: int) -> pygame.Surface:
        """캐시된 그라데이션 원형 서피스 반환 (없으면 생성)"""
        cache_key = (size, intensity_key)
        if cache_key not in self._gradient_circle_cache:
            surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            center = size
            # step을 4로 늘려서 성능 향상 (3 -> 4)
            for r in range(size, 0, -4):
                ratio = r / size
                # intensity_key를 기반으로 색상 계산
                heat = 0.4 + 0.4 * (intensity_key / 10)
                color = self._get_plasma_color(heat * ratio, variance=(1 - ratio) * 0.3)
                alpha = int(80 * ratio * (0.3 + self.intensity * 0.7))
                pygame.draw.circle(surf, (*color, alpha), (center, center), r)
            self._gradient_circle_cache[cache_key] = surf
        return self._gradient_circle_cache[cache_key]

    def _draw_base_background(self, surface: pygame.Surface):
        """기본 배경 - 이글거리는 태양 표면"""
        # 기본 색상
        base_color = self._get_plasma_color(0.3)
        surface.fill(base_color)

        # 첫 프레임 워밍업: 패치 수 점진적 증가
        if self._frame_count < self._warmup_frames:
            num_patches = min(4, 2 + self._frame_count)  # 2, 3, 4, 4, 4...
        else:
            num_patches = 8  # 12 -> 8로 줄임 (성능 향상)

        # 노이즈 기반 텍스처 (간단한 버전)
        intensity_mult = 0.3 + self.intensity * 0.7
        patch_size = int(50 + 80 * intensity_mult)

        for i in range(num_patches):
            px = (math.sin(self.noise_offset * 0.3 + i * 0.7) * 0.5 + 0.5) * self.screen_width
            py = (math.cos(self.noise_offset * 0.25 + i * 0.9) * 0.5 + 0.5) * self.screen_height

            # 게임 영역 내부는 스킵
            if (self.game_x < px < self.game_x + self.game_width and
                self.game_y < py < self.game_y + self.game_height):
                continue

            # 캐시된 그라데이션 사용 (heat를 정수 키로 변환)
            heat_key = int((0.4 + 0.4 * math.sin(self.time * 0.5 + i)) * 10)
            patch_surf = self._get_cached_gradient_circle(patch_size, heat_key)
            surface.blit(patch_surf, (int(px) - patch_size, int(py) - patch_size))

    def _draw_plasma_cells(self, surface: pygame.Surface):
        """플라즈마 대류 셀 그리기 - 태양 표면의 끓어오르는 패턴"""
        # 첫 프레임 워밍업: 플라즈마 셀 수 점진적 증가
        if self._frame_count < self._warmup_frames:
            max_cells = min(len(self.plasma_cells), 5 + self._frame_count * 5)
        else:
            max_cells = len(self.plasma_cells)

        cell_count = 0
        for cell in self.plasma_cells:
            if cell_count >= max_cells:
                break
            cell_count += 1

            cx = cell.get('current_x', cell['x'])
            cy = cell.get('current_y', cell['y'])
            radius = cell.get('current_radius', cell['radius'])

            # 게임 영역과 겹치면 스킵
            if (self.game_x - radius < cx < self.game_x + self.game_width + radius and
                self.game_y - radius < cy < self.game_y + self.game_height + radius):
                if (self.game_x + 20 < cx < self.game_x + self.game_width - 20 and
                    self.game_y + 20 < cy < self.game_y + self.game_height - 20):
                    continue

            radius *= (0.5 + self.intensity * 0.8)
            if radius < 3:
                continue

            # 다층 원형 그라데이션 (step을 3으로 늘려 성능 향상, 2 -> 3)
            cell_surf = pygame.Surface((int(radius * 2.5), int(radius * 2.5)), pygame.SRCALPHA)
            center = int(radius * 1.25)

            for r in range(int(radius), 0, -3):  # step 2 -> 3
                ratio = r / radius
                heat = 0.3 + 0.6 * (1 - ratio) + cell['turbulence'] * 0.2
                color = self._get_plasma_color(heat)
                alpha = int(150 * (1 - ratio * 0.3) * (0.4 + self.intensity * 0.6))
                pygame.draw.circle(cell_surf, (*color, alpha), (center, center), r)

            surface.blit(cell_surf, (int(cx) - center, int(cy) - center))

    def _draw_corona_strands(self, surface: pygame.Surface):
        """코로나 가닥 그리기 - 외곽의 불꽃 줄기"""
        # 첫 프레임 워밍업: 코로나 가닥 수 점진적 증가
        if self._frame_count < self._warmup_frames:
            max_strands = min(len(self.corona_strands), 10 + self._frame_count * 15)
        else:
            max_strands = len(self.corona_strands)

        min_intensity = 0.2 + self.intensity * 0.8

        strand_count = 0
        for strand in self.corona_strands:
            if strand_count >= max_strands:
                break
            strand_count += 1
            wave = math.sin(self.time * strand['speed'] + strand['phase'])
            current_angle = strand['angle'] + wave * 0.1
            current_length = strand['length'] * (0.6 + 0.6 * (wave * 0.5 + 0.5)) * min_intensity

            if current_length < 3:
                continue

            x1 = strand['x']
            y1 = strand['y']

            # 곡선 형태로 여러 세그먼트
            points = [(x1, y1)]
            segments = 5
            for s in range(1, segments + 1):
                t = s / segments
                wave_offset = math.sin(self.time * 3 + strand['phase'] + t * 4) * strand['wave_amp'] * t
                perp_angle = current_angle + math.pi / 2

                seg_x = x1 + math.cos(current_angle) * current_length * t + math.cos(perp_angle) * wave_offset
                seg_y = y1 + math.sin(current_angle) * current_length * t + math.sin(perp_angle) * wave_offset
                points.append((seg_x, seg_y))

            # 그라데이션 색상으로 그리기
            for i in range(len(points) - 1):
                ratio = i / max(1, len(points) - 2)
                heat = 0.8 - ratio * 0.4
                color = self._get_plasma_color(heat)
                thickness = max(1, int(strand['thickness'] * (1 - ratio * 0.6) * min_intensity))
                pygame.draw.line(surface, color, points[i], points[i + 1], thickness)

    def _draw_flares(self, surface: pygame.Surface):
        """태양 플레어 그리기 - 폭발적 분출"""
        if self.intensity < 0.1:
            return

        cx = self.game_x + self.game_width // 2
        cy = self.game_y + self.game_height // 2

        for flare in self.flares:
            if not flare['active']:
                continue

            angle = flare['angle']
            length = flare.get('current_length', flare['base_length'])
            width = flare['width'] * (0.5 + self.intensity * 0.8)

            if length < 5:
                continue

            start_x = cx + math.cos(angle) * (self.game_width // 2 + 10)
            start_y = cy + math.sin(angle) * (self.game_height // 2 + 10)
            end_x = start_x + math.cos(angle) * length
            end_y = start_y + math.sin(angle) * length

            perp_angle = angle + math.pi / 2
            half_width = width / 2

            p1 = (start_x + math.cos(perp_angle) * half_width,
                  start_y + math.sin(perp_angle) * half_width)
            p2 = (start_x - math.cos(perp_angle) * half_width,
                  start_y - math.sin(perp_angle) * half_width)
            p3 = (end_x, end_y)

            # 여러 레이어로 글로우 효과 (4레이어로 성능 유지)
            for layer in range(4, 0, -1):
                scale = 1 + (layer - 1) * 0.15
                sp1 = (start_x + (p1[0] - start_x) * scale, start_y + (p1[1] - start_y) * scale)
                sp2 = (start_x + (p2[0] - start_x) * scale, start_y + (p2[1] - start_y) * scale)
                sp3 = (start_x + (p3[0] - start_x) * scale, start_y + (p3[1] - start_y) * scale)

                heat = 0.6 + (4 - layer) * 0.1
                color = self._get_plasma_color(heat)
                alpha = int((200 - layer * 40) * flare['intensity'])

                try:
                    flare_surf = pygame.Surface((self.screen_width, self.screen_height), pygame.SRCALPHA)
                    pygame.draw.polygon(flare_surf, (*color, alpha), [sp1, sp2, sp3])
                    surface.blit(flare_surf, (0, 0))
                except:
                    pass

    def _draw_fire_particles(self, surface: pygame.Surface):
        """불꽃 파티클 그리기"""
        for p in self.fire_particles:
            heat = p['heat']
            color = self._get_plasma_color(heat)
            size = int(p['size'])
            alpha = int(255 * (p['life'] / 1.2) * 0.8)

            if size > 0 and alpha > 0:
                # 글로우 효과
                glow_size = size + 4
                glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)

                # 외부 글로우
                glow_color = (*color, alpha // 3)
                pygame.draw.circle(glow_surf, glow_color, (glow_size, glow_size), glow_size)

                # 내부 밝은 부분
                inner_color = self._get_plasma_color(min(1, heat + 0.3))
                pygame.draw.circle(glow_surf, (*inner_color, alpha), (glow_size, glow_size), size)

                surface.blit(glow_surf, (int(p['x']) - glow_size, int(p['y']) - glow_size))

    def _draw_vignette_fade(self, surface: pygame.Surface):
        """게임 영역만 검게 클리어 - 테두리 사각형 박스 없음, 자연스러운 페이드"""
        # 게임 영역을 검게 채우기 (로딩 화면용)
        game_rect = pygame.Rect(self.game_x, self.game_y, self.game_width, self.game_height)
        pygame.draw.rect(surface, (3, 3, 12), game_rect)

    def resize(self, screen_width: int, screen_height: int,
               game_width: int, game_height: int):
        """화면 크기 변경"""
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        # 재초기화
        self.fire_particles = []
        self._init_plasma_cells()
        self._init_flares()
        self._init_corona_strands()
        # 아트워크 필러 재생성
        if self._artwork_surface is not None:
            self._create_artwork_pillars()


# 전역 인스턴스
_blazing_sun_bg = None


def init_blazing_sun_background(screen_width: int, screen_height: int,
                                 game_width: int, game_height: int) -> BlazingSunFrame:
    """불타는 태양 필러 초기화"""
    global _blazing_sun_bg
    _blazing_sun_bg = BlazingSunFrame(screen_width, screen_height, game_width, game_height)
    return _blazing_sun_bg


def get_blazing_sun_background() -> BlazingSunFrame:
    """불타는 태양 필러 인스턴스 반환"""
    return _blazing_sun_bg


# 테스트
if __name__ == "__main__":
    import time as time_module

    pygame.init()
    screen = pygame.display.set_mode((600, 750))
    pygame.display.set_caption("Blazing Sun Frame Test - Solar Surface")
    clock = pygame.time.Clock()

    # 필러 생성 (게임 영역: 520x670)
    pillar = BlazingSunFrame(600, 750, 520, 670)

    running = True
    test_progress = 0.0
    auto_mode = True

    font = pygame.font.Font(None, 36)

    print("=" * 50)
    print("🔥 불타는 태양 필러 테스트 (태양 표면 스타일)")
    print("=" * 50)
    print("조작법:")
    print("  ↑/↓ : 강렬함 수동 조절")
    print("  SPACE : 자동 로딩 시뮬레이션 시작/정지")
    print("  R : 리셋")
    print("  ESC : 종료")
    print("=" * 50)

    while running:
        dt = clock.tick(60) / 1000.0

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    auto_mode = not auto_mode
                    print(f"자동 모드: {'ON' if auto_mode else 'OFF'}")
                elif event.key == pygame.K_r:
                    test_progress = 0.0
                    print("리셋!")

        keys = pygame.key.get_pressed()
        if not auto_mode:
            if keys[pygame.K_UP]:
                test_progress = min(1.0, test_progress + dt * 0.5)
            if keys[pygame.K_DOWN]:
                test_progress = max(0.0, test_progress - dt * 0.5)
        else:
            # 자동 진행
            test_progress += dt * 0.15
            if test_progress > 1.0:
                test_progress = 0.0

        pillar.set_intensity(test_progress)
        pillar.update(dt)
        pillar.draw(screen)

        # 정보 표시
        text = font.render(f"Intensity: {test_progress:.0%}", True, (255, 255, 255))
        screen.blit(text, (pillar.game_x + 20, pillar.game_y + 20))

        mode_text = font.render(f"Mode: {'AUTO' if auto_mode else 'MANUAL'}", True, (200, 200, 200))
        screen.blit(mode_text, (pillar.game_x + 20, pillar.game_y + 50))

        pygame.display.flip()

    print("테스트 종료!")
    pygame.quit()
