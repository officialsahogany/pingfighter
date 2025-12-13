# -*- coding: utf-8 -*-
"""
스테이지 7 테트리서 필러 배경
- 고전 테트리스 레이아웃 (NEXT, SCORE, LEVEL, LINES 패널)
- 사이버틱/네온 스타일 UI
- 실제 테트리스처럼 블록이 내려오며 회전/이동
- 바닥부터 쌓이고 한 줄 완성 시 삭제
- 크리스탈 테트로미노 실드 시스템
"""

import math
import random
import pygame
from typing import List, Tuple, Optional, Dict


class CrystalShieldBlock:
    """보스 주변을 회전하는 크리스탈 테트로미노 블록"""

    def __init__(self, start_x: float, start_y: float, target_x: float, target_y: float,
                 color: Tuple[int, int, int], block_size: int, orbit_angle: float):
        # 시작 위치 (필러에서 분해된 위치)
        self.start_x = start_x
        self.start_y = start_y
        self.x = start_x
        self.y = start_y

        # 목표 위치 (보스 위치)
        self.target_x = target_x
        self.target_y = target_y

        # 색상 및 크기
        self.color = color
        self.original_size = block_size
        self.size = block_size
        self.min_size = 16  # 최종 실드 블록 크기 (작게)

        # 애니메이션 상태
        self.phase = "floating"  # floating -> moving -> orbiting
        self.float_height = 0.0
        self.float_speed = random.uniform(1.5, 2.5)
        self.float_timer = 0.0
        self.float_duration = random.uniform(0.5, 1.0)  # 분해 후 떠오르는 시간

        # 이동 애니메이션
        self.move_timer = 0.0
        self.move_duration = random.uniform(0.8, 1.5)
        self.move_delay = random.uniform(0.0, 0.5)  # 순차적 이동을 위한 딜레이

        # 궤도 설정
        self.orbit_angle = orbit_angle  # 보스 주변 궤도 위치
        self.orbit_radius = 100  # 보스로부터의 거리 (더 작게)
        self.orbit_speed = 0.4  # 회전 속도 (더 느리게)

        # 무지개 홀로그램
        self.rainbow_offset = random.uniform(0, 1)
        self.rainbow_time = 0.0

        # 활성 상태
        self.active = True
        self.alpha = 255
        self.fade_speed = 0.0  # 피격 시 페이드 아웃 속도
        self.evaporating = False  # 증발 중
        self.evaporate_scale = 1.0  # 증발 시 스케일 효과

    def update(self, dt: float, boss_x: float, boss_y: float) -> bool:
        """블록 업데이트, False 반환 시 제거"""
        if not self.active:
            self.alpha -= self.fade_speed * dt * 255
            # 증발 효과: 크기가 커지면서 사라짐
            if self.evaporating:
                self.evaporate_scale += dt * 3.0  # 점점 커짐
                self.rainbow_time += dt * 5.0  # 빠른 무지개 변화
            if self.alpha <= 0:
                return False
            return True

        self.rainbow_time += dt
        self.target_x = boss_x
        self.target_y = boss_y

        if self.phase == "floating":
            # 공중으로 떠오르는 애니메이션
            self.float_timer += dt
            self.float_height = math.sin(self.float_timer * self.float_speed * math.pi) * 30
            self.y = self.start_y - self.float_height

            if self.float_timer >= self.float_duration:
                self.phase = "waiting"
                self.float_timer = 0.0

        elif self.phase == "waiting":
            # 이동 딜레이 대기
            self.move_delay -= dt
            # 떠있는 상태 유지
            self.float_timer += dt
            self.y = self.start_y - 30 + math.sin(self.float_timer * 3) * 5

            if self.move_delay <= 0:
                self.phase = "moving"
                self.move_timer = 0.0

        elif self.phase == "moving":
            # 보스를 향해 이동
            self.move_timer += dt
            progress = min(1.0, self.move_timer / self.move_duration)

            # 이징 함수 (ease-out cubic)
            eased = 1 - (1 - progress) ** 3

            # 궤도 위치 계산
            orbit_x = self.target_x + math.cos(self.orbit_angle) * self.orbit_radius
            orbit_y = self.target_y + math.sin(self.orbit_angle) * self.orbit_radius

            # 시작점에서 궤도 위치로 이동
            self.x = self.start_x + (orbit_x - self.start_x) * eased
            self.y = (self.start_y - 30) + (orbit_y - (self.start_y - 30)) * eased

            # 크기 축소
            self.size = self.original_size + (self.min_size - self.original_size) * eased

            if progress >= 1.0:
                self.phase = "orbiting"

        elif self.phase == "orbiting":
            # 보스 주변 궤도 회전
            self.orbit_angle += self.orbit_speed * dt
            self.x = self.target_x + math.cos(self.orbit_angle) * self.orbit_radius
            self.y = self.target_y + math.sin(self.orbit_angle) * self.orbit_radius

        return True

    def draw(self, surface: pygame.Surface):
        """블록 그리기"""
        if self.alpha <= 0:
            return

        # 무지개 색상 계산
        hue = (self.rainbow_offset + self.rainbow_time * 0.5) % 1.0
        r, g, b = self._hsv_to_rgb(hue, 0.7, 1.0)
        rainbow_color = (int(r * 255), int(g * 255), int(b * 255))

        # 증발 효과 적용
        size = int(self.size * self.evaporate_scale)
        px = int(self.x - size // 2)
        py = int(self.y - size // 2)

        # 알파 조정
        alpha_mult = self.alpha / 255.0

        # 글로우 효과
        glow_alpha = int(30 * alpha_mult)
        if glow_alpha > 0:
            glow_surface = pygame.Surface((size + 8, size + 8), pygame.SRCALPHA)
            pygame.draw.rect(glow_surface, (*rainbow_color, glow_alpha),
                           (0, 0, size + 8, size + 8), border_radius=4)
            surface.blit(glow_surface, (px - 4, py - 4))

        # 메인 블록
        main_alpha = int(80 * alpha_mult)
        if main_alpha > 0:
            block_surface = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.rect(block_surface, (*rainbow_color, main_alpha),
                           (0, 0, size, size), border_radius=3)
            # 외곽선
            pygame.draw.rect(block_surface, (*rainbow_color, int(150 * alpha_mult)),
                           (0, 0, size, size), 2, border_radius=3)
            surface.blit(block_surface, (px, py))

        # 하이라이트
        highlight_alpha = int(100 * alpha_mult)
        if highlight_alpha > 0 and size > 6:
            pygame.draw.line(surface, (255, 255, 255, highlight_alpha),
                           (px + 3, py + 3), (px + size // 3, py + 3), 1)

    def _hsv_to_rgb(self, h, s, v):
        """HSV to RGB 변환"""
        i = int(h * 6)
        f = h * 6 - i
        p = v * (1 - s)
        q = v * (1 - f * s)
        t = v * (1 - (1 - f) * s)
        i = i % 6
        if i == 0: return (v, t, p)
        if i == 1: return (q, v, p)
        if i == 2: return (p, v, t)
        if i == 3: return (p, q, v)
        if i == 4: return (t, p, v)
        return (v, p, q)

    def get_rect(self) -> pygame.Rect:
        """충돌 판정용 rect 반환 - 블록의 실제 크기"""
        size = int(self.size)
        return pygame.Rect(int(self.x - size // 2), int(self.y - size // 2), size, size)

    def get_collision_rect(self) -> pygame.Rect:
        """충돌 판정용 확장된 rect 반환 - 빠른 공 터널링 방지

        블록이 작고 공이 빠를 때 한 프레임에 블록을 통과하는 문제를 방지하기 위해
        충돌 영역을 확장합니다.
        """
        size = int(self.size)
        # 최소 충돌 영역 24px 보장 (원래 블록 크기가 16일 때도 안정적인 충돌 감지)
        collision_size = max(size, 24)
        # 추가 패딩 (공 반지름 고려)
        padding = 8
        total_size = collision_size + padding * 2
        return pygame.Rect(
            int(self.x - total_size // 2),
            int(self.y - total_size // 2),
            total_size,
            total_size
        )

    def hit(self):
        """플레이어 공에 피격됨"""
        self.active = False
        self.fade_speed = 3.0  # 빠른 페이드 아웃

    def hit_evaporate(self):
        """홀로그램처럼 증발 (더 화려한 효과)"""
        self.active = False
        self.fade_speed = 4.0  # 빠른 증발
        self.evaporating = True  # 증발 효과 활성화


class CrystalShieldSystem:
    """크리스탈 테트로미노 실드 시스템 - 기존 블록이 직접 공중부양"""

    # 애니메이션 페이즈 타이밍 (초)
    PHASE_AURA = 3.0        # 신비한 기운 끌어모음 + 충격파 발사 (2초 -> 3초)
    PHASE_FLOATING = 3.0    # 블록 해체 및 둥둥 떠다님
    PHASE_GATHERING = 0.5   # 테트리서에게 빠르게 모임 (속도 증가: 1.0 -> 0.5)
    PHASE_FORMING = 2.0     # 실드 형성 + 플라즈마 폭발

    FINAL_SHIELD_COUNT = 24  # 최종 실드 블록 수

    def __init__(self):
        self.shield_blocks: List[CrystalShieldBlock] = []
        self.activated = False
        self.pending_activation = False  # 다음 라운드에 활성화 대기
        self.animation_phase = "idle"
        # idle -> aura -> floating -> gathering -> forming -> active
        self.animation_timer = 0.0

        # 보스 위치 (pingfighter.py에서 업데이트)
        self.boss_x = 0
        self.boss_y = 0
        self.screen_height = 600  # 기본값

        # 아우라 효과
        self.aura_particles: List[Dict] = []
        self.aura_intensity = 0.0

        # 화면 정지 플래그
        self.freeze_screen = False

        # 필러 블록 수집 완료 여부
        self.collection_complete = False

        # 플라즈마 폭발 효과
        self.plasma_particles: List[Dict] = []
        self.plasma_intensity = 0.0
        self.explosion_triggered = False

        # 아우라 페이드아웃 (페이즈 전환 시 자연스러운 연결)
        self.aura_fade_out = False
        self.aura_fade_timer = 0.0
        self.AURA_FADE_DURATION = 1.0  # 페이드아웃 시간

        # 화면 너비 (블록 생성 시 필요)
        self.screen_width = 800  # 기본값

        # === 충격파 시스템 ===
        self.shockwave_phase = "gathering"  # gathering -> exploding -> injecting
        self.shockwave_particles: List[Dict] = []  # 충격파 파티클
        self.shockwave_triggered = False  # 충격파 발사 여부
        self.injection_particles: List[Dict] = []  # 블록에 주입되는 파티클

        # === 새로운 시스템: 떠다니는 블록 (보드에서 직접 가져옴) ===
        self.floating_blocks: List[Dict] = []  # 공중부양 중인 블록들
        self.left_game_ref = None  # 좌측 테트리스 게임 참조
        self.right_game_ref = None  # 우측 테트리스 게임 참조

        # 결합 애니메이션
        self.merging_blocks: List[Dict] = []  # 결합 중인 블록들
        self.merge_targets: List[Dict] = []  # 최종 24개 실드 위치

        # 빛 입자 효과 (공중부양 블록 주변)
        self.light_particles: List[Dict] = []
        self.light_pulse_timer = 0.0  # 빛 펄스 타이머

        # 응축 효과 (forming 페이즈)
        self.condensing_energy = 0.0  # 응축 에너지 (0~1)
        self.energy_rings: List[Dict] = []  # 에너지 링

    def schedule_activation(self, left_game, right_game, boss_x: float, boss_y: float,
                            screen_height: int, screen_width: int = 800):
        """다음 라운드에 실드 활성화 예약 - 테트리스 게임 참조 저장"""
        if self.activated or self.pending_activation:
            return

        self.pending_activation = True
        self.left_game_ref = left_game
        self.right_game_ref = right_game
        self.boss_x = boss_x
        self.boss_y = boss_y
        self.screen_height = screen_height
        self.screen_width = screen_width

        # 현재 보드의 블록 수 카운트
        left_count = 0
        right_count = 0
        if left_game:
            for row in left_game.board:
                left_count += sum(1 for cell in row if cell is not None)
        if right_game:
            for row in right_game.board:
                right_count += sum(1 for cell in row if cell is not None)

        print(f"[CrystalShield] 다음 라운드에 실드 활성화 예약됨 (좌측 {left_count}개, 우측 {right_count}개)")

    def start_activation(self, boss_x: float, boss_y: float):
        """실제 활성화 시작 (다음 라운드 시작 시 호출)"""
        if not self.pending_activation or self.activated:
            return False

        self.pending_activation = False
        self.activated = True
        self.boss_x = boss_x
        self.boss_y = boss_y
        self.animation_phase = "aura"
        self.animation_timer = 0.0
        self.freeze_screen = True
        self.explosion_triggered = False
        self.aura_fade_out = False
        self.aura_fade_timer = 0.0

        # 충격파 시스템 초기화
        self.shockwave_phase = "gathering"
        self.shockwave_triggered = False
        self.shockwave_particles.clear()
        self.injection_particles.clear()

        # 아우라 파티클 생성
        self._create_aura_particles()

        # 플라즈마 파티클 생성
        self._create_plasma_particles()

        # 테트리스 보드에서 직접 블록 데이터 수집 (공중부양용)
        self._collect_board_blocks()

        # 최종 24개 실드 위치 계산
        self._calculate_merge_targets()

        print(f"[CrystalShield] 활성화 시작 - 공중부양 블록 수: {len(self.floating_blocks)}")
        return True

    def _collect_board_blocks(self):
        """테트리스 보드에서 직접 블록 수집 - 공중부양할 블록들"""
        self.floating_blocks.clear()

        # 좌측 보드 블록 수집
        if self.left_game_ref:
            for y in range(self.left_game_ref.rows):
                for x in range(self.left_game_ref.cols):
                    color = self.left_game_ref.board[y][x]
                    if color is not None:
                        px = self.left_game_ref.offset_x + x * self.left_game_ref.block_size
                        py = self.left_game_ref.offset_y + y * self.left_game_ref.block_size
                        self.floating_blocks.append({
                            'x': px + self.left_game_ref.block_size // 2,
                            'y': py + self.left_game_ref.block_size // 2,
                            'start_x': px + self.left_game_ref.block_size // 2,
                            'start_y': py + self.left_game_ref.block_size // 2,
                            'color': color,
                            'size': self.left_game_ref.block_size,
                            'side': 'left',
                            'grid_x': x,
                            'grid_y': y,
                            'game_ref': self.left_game_ref,
                            # 공중부양 목표 위치
                            'float_target_x': px + random.uniform(-20, 20),
                            'float_target_y': random.uniform(self.screen_height * 0.25, self.screen_height * 0.45),
                            'float_reached': False,
                            'disassemble_delay': random.uniform(0.0, 1.5),
                            'float_timer': random.uniform(0, math.pi * 2),
                            # 결합 대상 인덱스 (-1이면 미할당)
                            'merge_target_idx': -1,
                            'alpha': 255,
                            'rainbow_offset': random.uniform(0, 1),
                        })
                        # 보드에서 제거 (공중부양 시작)
                        # self.left_game_ref.board[y][x] = None  # floating 시작 시 제거

        # 우측 보드 블록 수집
        if self.right_game_ref:
            for y in range(self.right_game_ref.rows):
                for x in range(self.right_game_ref.cols):
                    color = self.right_game_ref.board[y][x]
                    if color is not None:
                        px = self.right_game_ref.offset_x + x * self.right_game_ref.block_size
                        py = self.right_game_ref.offset_y + y * self.right_game_ref.block_size
                        self.floating_blocks.append({
                            'x': px + self.right_game_ref.block_size // 2,
                            'y': py + self.right_game_ref.block_size // 2,
                            'start_x': px + self.right_game_ref.block_size // 2,
                            'start_y': py + self.right_game_ref.block_size // 2,
                            'color': color,
                            'size': self.right_game_ref.block_size,
                            'side': 'right',
                            'grid_x': x,
                            'grid_y': y,
                            'game_ref': self.right_game_ref,
                            # 공중부양 목표 위치
                            'float_target_x': px + random.uniform(-20, 20),
                            'float_target_y': random.uniform(self.screen_height * 0.25, self.screen_height * 0.45),
                            'float_reached': False,
                            'disassemble_delay': random.uniform(0.0, 1.5),
                            'float_timer': random.uniform(0, math.pi * 2),
                            # 결합 대상 인덱스 (-1이면 미할당)
                            'merge_target_idx': -1,
                            'alpha': 255,
                            'rainbow_offset': random.uniform(0, 1),
                        })

        print(f"[CrystalShield] 보드 블록 수집 완료: {len(self.floating_blocks)}개")

    def _calculate_merge_targets(self):
        """최종 24개 실드 위치 계산 (보스 주변 궤도)"""
        self.merge_targets.clear()

        for i in range(self.FINAL_SHIELD_COUNT):
            orbit_angle = (2 * math.pi * i) / self.FINAL_SHIELD_COUNT
            self.merge_targets.append({
                'orbit_angle': orbit_angle,
                'orbit_radius': 60,
                'blocks_merged': 0,  # 이 위치에 결합된 블록 수
            })

    def _assign_blocks_to_targets(self):
        """floating 블록들을 24개 타겟에 할당"""
        if not self.floating_blocks:
            return

        # 블록 수에 따라 각 타겟에 몇 개씩 할당할지 계산
        total_blocks = len(self.floating_blocks)
        blocks_per_target = max(1, total_blocks // self.FINAL_SHIELD_COUNT)

        # 균등 분배
        for i, block in enumerate(self.floating_blocks):
            target_idx = i % self.FINAL_SHIELD_COUNT
            block['merge_target_idx'] = target_idx

    def _create_shield_blocks_from_stored(self):
        """저장된 필러 블록에서 실드 블록 생성 - 좌우 균등 배분"""
        pillar_blocks = self.stored_pillar_blocks.copy()  # 원본 보존

        # 블록 수 고정 (완전한 원을 형성하기 위해)
        MAX_SHIELD_BLOCKS = 24  # 24개의 크리스탈 테트로미노 (좌12 + 우12)
        BLOCKS_PER_SIDE = MAX_SHIELD_BLOCKS // 2  # 각 측면 12개

        # 게임 영역 계산 (좌측/우측 필러 영역)
        game_x = (self.screen_width - 400) // 2  # 대략적인 게임 영역 시작
        game_center_x = self.screen_width // 2  # 화면 중앙
        right_pillar_start = game_x + 400  # 게임 영역 끝

        # 좌측/우측 블록 분류
        left_blocks = []
        right_blocks = []

        for block in pillar_blocks:
            if block['x'] < game_center_x:
                left_blocks.append(block)
            else:
                right_blocks.append(block)

        print(f"[CrystalShield] 좌측 블록: {len(left_blocks)}개, 우측 블록: {len(right_blocks)}개")

        # 좌측 블록이 부족하면 생성
        while len(left_blocks) < BLOCKS_PER_SIDE:
            x = random.uniform(20, game_x - 20)  # 좌측 필러
            y = random.uniform(self.screen_height * 0.6, self.screen_height - 50)
            left_blocks.append({
                'x': x,
                'y': y,
                'color': (100, 150, 200),
                'size': 16,
                'side': 'left'
            })

        # 우측 블록이 부족하면 생성
        while len(right_blocks) < BLOCKS_PER_SIDE:
            x = random.uniform(right_pillar_start + 20, self.screen_width - 20)  # 우측 필러
            y = random.uniform(self.screen_height * 0.6, self.screen_height - 50)
            right_blocks.append({
                'x': x,
                'y': y,
                'color': (100, 150, 200),
                'size': 16,
                'side': 'right'
            })

        # 좌측 12개, 우측 12개 선택하여 번갈아 배치
        selected_blocks = []
        for i in range(BLOCKS_PER_SIDE):
            if i < len(left_blocks):
                selected_blocks.append(left_blocks[i])
            if i < len(right_blocks):
                selected_blocks.append(right_blocks[i])

        num_blocks = len(selected_blocks)
        print(f"[CrystalShield] 총 선택된 블록: {num_blocks}개 (좌{min(len(left_blocks), BLOCKS_PER_SIDE)} + 우{min(len(right_blocks), BLOCKS_PER_SIDE)})")

        # 필러 블록들을 실드 블록으로 변환
        for i in range(num_blocks):
            block = selected_blocks[i]
            orbit_angle = (2 * math.pi * i) / num_blocks

            # 떠다닐 목표 Y 위치 (화면 Y축 1/4 ~ 1/2 사이)
            float_target_y = random.uniform(self.screen_height * 0.25, self.screen_height * 0.5)
            float_target_x = block['x'] + random.uniform(-30, 30)

            shield_block = CrystalShieldBlock(
                start_x=block['x'],
                start_y=block['y'],
                target_x=self.boss_x,
                target_y=self.boss_y,
                color=block.get('color', (100, 150, 200)),
                block_size=block.get('size', 16),
                orbit_angle=orbit_angle
            )

            # 떠다니는 위치 저장
            shield_block.float_target_x = float_target_x
            shield_block.float_target_y = float_target_y
            shield_block.float_reached = False
            shield_block.phase = "waiting"  # 초기 상태

            # 해체 딜레이 (순차적으로 해체)
            shield_block.disassemble_delay = random.uniform(0.0, 1.5)

            self.shield_blocks.append(shield_block)

    def _create_aura_particles(self):
        """신비로운 아우라 파티클 생성"""
        self.aura_particles.clear()
        for _ in range(50):
            angle = random.uniform(0, 2 * math.pi)
            distance = random.uniform(80, 200)
            self.aura_particles.append({
                'angle': angle,
                'distance': distance,
                'speed': random.uniform(0.5, 2.0),
                'size': random.uniform(3, 10),
                'alpha': random.uniform(100, 200),
                'hue': random.uniform(0, 1),
            })

    def _create_plasma_particles(self):
        """플라즈마 폭발 파티클 생성"""
        self.plasma_particles.clear()
        for _ in range(100):
            angle = random.uniform(0, 2 * math.pi)
            self.plasma_particles.append({
                'angle': angle,
                'distance': 0,
                'speed': random.uniform(200, 500),
                'size': random.uniform(5, 15),
                'alpha': 255,
                'hue': random.uniform(0, 1),
                'lifetime': random.uniform(0.5, 1.0),
                'age': 0,
            })

    def _create_shockwave_particles(self):
        """충격파 파티클 생성 - 보스에서 사방으로 발사"""
        self.shockwave_particles.clear()

        # 메인 충격파 링
        for i in range(60):
            angle = (2 * math.pi * i) / 60
            self.shockwave_particles.append({
                'angle': angle,
                'distance': 10,
                'speed': random.uniform(400, 600),  # 빠른 확산
                'size': random.uniform(8, 15),
                'alpha': 255,
                'hue': random.uniform(0.5, 0.7),  # 청록색 계열
                'type': 'ring'
            })

        # 추가 방사형 파티클
        for _ in range(40):
            angle = random.uniform(0, 2 * math.pi)
            self.shockwave_particles.append({
                'angle': angle,
                'distance': 5,
                'speed': random.uniform(300, 500),
                'size': random.uniform(4, 10),
                'alpha': 200,
                'hue': random.uniform(0, 1),  # 무지개색
                'type': 'particle'
            })

        # 좌우 테트로미노를 향한 주입 파티클 생성
        self._create_injection_particles()

    def _create_injection_particles(self):
        """좌우 테트로미노에 주입되는 파티클 생성"""
        self.injection_particles.clear()

        # 게임 영역 계산
        game_x = (self.screen_width - 400) // 2
        right_pillar_start = game_x + 400

        # 좌측 필러로 향하는 파티클
        left_target_x = game_x // 2
        for i in range(30):
            target_y = self.screen_height * 0.3 + random.uniform(0, self.screen_height * 0.5)
            self.injection_particles.append({
                'x': self.boss_x,
                'y': self.boss_y,
                'target_x': left_target_x + random.uniform(-50, 50),
                'target_y': target_y,
                'progress': 0.0,
                'speed': random.uniform(0.8, 1.5),
                'delay': random.uniform(0, 0.3),  # 순차적 발사
                'size': random.uniform(6, 12),
                'hue': random.uniform(0, 1),
                'alpha': 255,
                'side': 'left',
                'arrived': False
            })

        # 우측 필러로 향하는 파티클
        right_target_x = right_pillar_start + (self.screen_width - right_pillar_start) // 2
        for i in range(30):
            target_y = self.screen_height * 0.3 + random.uniform(0, self.screen_height * 0.5)
            self.injection_particles.append({
                'x': self.boss_x,
                'y': self.boss_y,
                'target_x': right_target_x + random.uniform(-50, 50),
                'target_y': target_y,
                'progress': 0.0,
                'speed': random.uniform(0.8, 1.5),
                'delay': random.uniform(0, 0.3),
                'size': random.uniform(6, 12),
                'hue': random.uniform(0, 1),
                'alpha': 255,
                'side': 'right',
                'arrived': False
            })

    def _update_injection_particles(self, dt: float):
        """주입 파티클 업데이트 - 보스에서 좌우 테트로미노로 이동"""
        for p in self.injection_particles:
            # 딜레이 처리
            if p['delay'] > 0:
                p['delay'] -= dt
                continue

            if not p['arrived']:
                # 진행도 업데이트
                p['progress'] += p['speed'] * dt

                if p['progress'] >= 1.0:
                    p['progress'] = 1.0
                    p['arrived'] = True

                # 이징 함수 (ease-out cubic)
                eased = 1 - math.pow(1 - p['progress'], 3)

                # 위치 업데이트 (곡선 경로)
                # 중간에 약간 위로 휘어지는 경로
                mid_y = min(p['y'], p['target_y']) - 50
                if eased < 0.5:
                    # 전반부: 위로 휘어짐
                    t = eased * 2
                    p['x'] = self.boss_x + (p['target_x'] - self.boss_x) * t * 0.5
                    p['y'] = self.boss_y + (mid_y - self.boss_y) * t
                else:
                    # 후반부: 목표로 내려감
                    t = (eased - 0.5) * 2
                    mid_x = self.boss_x + (p['target_x'] - self.boss_x) * 0.5
                    p['x'] = mid_x + (p['target_x'] - mid_x) * t
                    p['y'] = mid_y + (p['target_y'] - mid_y) * t

            else:
                # 도착 후 페이드아웃
                p['alpha'] = max(0, p['alpha'] - 300 * dt)

                # 도착 시 블록에 빛나는 효과 (floating_blocks에 마킹)
                if p['alpha'] > 200:
                    for block in self.floating_blocks:
                        if block.get('side') == p['side']:
                            block['injected'] = True
                            block['inject_glow'] = 1.0

    def update(self, dt: float, boss_x: float, boss_y: float) -> bool:
        """시스템 업데이트, freeze_screen 상태 반환"""
        if not self.activated:
            return False

        self.boss_x = boss_x
        self.boss_y = boss_y
        self.animation_timer += dt

        if self.animation_phase == "aura":
            # Phase 1: 신비한 기운 끌어모음 + 충격파 발사 (3초)
            # 0~1.2초: 아우라 파티클이 보스에게 모임
            # 1.2~1.5초: 충격파 폭발
            # 1.5~3.0초: 충격파가 좌우 테트로미노에 주입

            # 디버그: 현재 타이머 출력 (0.5초마다)
            if int(self.animation_timer * 2) != int((self.animation_timer - dt) * 2):
                print(f"[CrystalShield] Aura phase: timer={self.animation_timer:.2f}, shockwave_phase={self.shockwave_phase}")

            if self.animation_timer < 1.2:
                # Phase 1a: 아우라 파티클이 보스에게 모임
                self.shockwave_phase = "gathering"
                self.aura_intensity = min(1.0, self.animation_timer / 0.5)

                # 아우라 파티클이 보스에게 점점 빠르게 모임
                gather_speed = 40 + (self.animation_timer / 1.2) * 80  # 40 -> 120
                for p in self.aura_particles:
                    p['angle'] += p['speed'] * dt
                    p['distance'] = max(5, p['distance'] - gather_speed * dt)

            elif self.animation_timer < 1.5:
                # Phase 1b: 충격파 폭발
                if not self.shockwave_triggered:
                    self.shockwave_triggered = True
                    self.shockwave_phase = "exploding"
                    self._create_shockwave_particles()
                    print("[CrystalShield] 충격파 발사!")

                # 충격파 파티클 확장
                for p in self.shockwave_particles:
                    p['distance'] += p['speed'] * dt
                    p['alpha'] = max(0, p['alpha'] - 200 * dt)

                self.aura_intensity = max(0.5, 1.0 - (self.animation_timer - 1.2) / 0.3)

            else:
                # Phase 1c: 충격파가 테트로미노에 주입
                self.shockwave_phase = "injecting"

                # 주입 파티클 업데이트
                self._update_injection_particles(dt)

                # 아우라 페이드아웃
                fade_progress = (self.animation_timer - 1.5) / 1.5
                self.aura_intensity = max(0.0, 0.5 - fade_progress * 0.5)

            if self.animation_timer >= self.PHASE_AURA:
                self.animation_phase = "floating"
                self.animation_timer = 0.0
                self.aura_fade_out = False
                self.aura_intensity = 0.0
                self.shockwave_triggered = False
                self.shockwave_particles.clear()
                self.injection_particles.clear()
                # 보드에서 블록 제거 (이제 floating_blocks로 관리)
                self._clear_board_blocks()
                print("[CrystalShield] Phase: floating (블록 공중부양)")

        elif self.animation_phase == "floating":
            # Phase 2: 블록들이 공중으로 둥둥 떠오름 (3초)
            # 빛 펄스 타이머 업데이트
            self.light_pulse_timer += dt * 3.0  # 빠른 펄스

            for block in self.floating_blocks:
                # 해체 딜레이 후 떠오르기 시작
                if block['disassemble_delay'] > 0:
                    block['disassemble_delay'] -= dt
                    continue

                if not block['float_reached']:
                    # 목표 위치로 천천히 이동 (부유 효과)
                    dx = block['float_target_x'] - block['x']
                    dy = block['float_target_y'] - block['y']
                    dist = math.sqrt(dx * dx + dy * dy)

                    if dist > 5:
                        speed = 100 * dt  # 천천히 떠오름
                        block['x'] += (dx / dist) * speed
                        block['y'] += (dy / dist) * speed
                    else:
                        block['float_reached'] = True
                        # 빛 입자 생성 (목표 도달 시)
                        self._spawn_light_particles_for_block(block)
                else:
                    # 떠다니는 효과 (위아래로 흔들림)
                    block['float_timer'] += dt
                    block['y'] = block['float_target_y'] + math.sin(block['float_timer'] * 2 + block['rainbow_offset'] * 10) * 8
                    block['x'] = block['float_target_x'] + math.sin(block['float_timer'] * 1.5 + block['rainbow_offset'] * 5) * 5

            # 빛 입자 업데이트
            self._update_light_particles(dt)

            if self.animation_timer >= self.PHASE_FLOATING:
                self.animation_phase = "gathering"
                self.animation_timer = 0.0
                # 블록들을 24개 타겟에 할당
                self._assign_blocks_to_targets()
                # 시작 위치 저장
                for block in self.floating_blocks:
                    block['gather_start_x'] = block['x']
                    block['gather_start_y'] = block['y']
                print("[CrystalShield] Phase: gathering (블록 수집)")

        elif self.animation_phase == "gathering":
            # Phase 3: 테트리서에게 빠르게 모임 (1초) - 모든 블록이 보스에게 모임
            progress = min(1.0, self.animation_timer / self.PHASE_GATHERING)
            eased = 1 - math.pow(1 - progress, 3)  # ease-out cubic

            for block in self.floating_blocks:
                target_idx = block['merge_target_idx']
                if target_idx >= 0 and target_idx < len(self.merge_targets):
                    target = self.merge_targets[target_idx]
                    # 궤도 위치 계산
                    orbit_x = boss_x + math.cos(target['orbit_angle']) * target['orbit_radius']
                    orbit_y = boss_y + math.sin(target['orbit_angle']) * target['orbit_radius']

                    # 시작점에서 궤도 위치로 이동
                    start_x = block.get('gather_start_x', block['x'])
                    start_y = block.get('gather_start_y', block['y'])
                    block['x'] = start_x + (orbit_x - start_x) * eased
                    block['y'] = start_y + (orbit_y - start_y) * eased

                    # 크기 점점 축소
                    original_size = block['size']
                    block['current_size'] = original_size * (1.0 - eased * 0.3)

            # 플라즈마 강도 증가
            self.plasma_intensity = min(1.0, progress)

            if self.animation_timer >= self.PHASE_GATHERING:
                self.animation_phase = "forming"
                self.animation_timer = 0.0
                # 최종 24개 실드 블록 생성
                self._create_final_shield_blocks()
                print("[CrystalShield] Phase: forming (실드 형성 + 플라즈마 폭발)")

        elif self.animation_phase == "forming":
            # Phase 4: 실드 형성 + 플라즈마 폭발 (2초)
            progress = self.animation_timer / self.PHASE_FORMING

            # 블록들 궤도 회전 (에너지 응축에 따라 회전 속도 증가)
            rotation_mult = 1.0 + progress * 3.0  # 1x -> 4x 속도 증가
            for block in self.shield_blocks:
                block.orbit_angle += block.orbit_speed * dt * rotation_mult
                block.x = boss_x + math.cos(block.orbit_angle) * block.orbit_radius
                block.y = boss_y + math.sin(block.orbit_angle) * block.orbit_radius

            # 빛 응축 효과 (0.0 ~ 0.6) -> 폭발 (0.6 ~ 0.7) -> 페이드아웃 (0.7 ~ 1.0)
            if progress < 0.6:
                # Phase 4a: 에너지 응축 - 빛이 점점 강해지며 수축
                condense_progress = progress / 0.6
                self.condensing_energy = condense_progress
                self.plasma_intensity = condense_progress * 0.8  # 최대 0.8

                # 에너지 링 업데이트 (응축됨에 따라 작아짐)
                self._update_energy_rings(dt, condense_progress)

            elif progress < 0.7:
                # Phase 4b: 폭발 직전 - 에너지 최대
                self.condensing_energy = 1.0
                self.plasma_intensity = 1.0

                if not self.explosion_triggered:
                    # 폭발 트리거
                    self.explosion_triggered = True
                    self.floating_blocks.clear()
                    self.light_particles.clear()  # 빛 입자도 클리어
                    self.energy_rings.clear()  # 에너지 링도 클리어
                    # 폭발 파티클 강화
                    self._boost_plasma_explosion()
                    print("[CrystalShield] 플라즈마 폭발! - 24개 실드 형성 완료")

            else:
                # Phase 4c: 폭발 후 페이드아웃
                fade_progress = (progress - 0.7) / 0.3
                self.plasma_intensity = max(0, 1.0 - fade_progress * 1.5)
                self.condensing_energy = max(0, 1.0 - fade_progress)

            # 플라즈마 파티클 업데이트
            if self.explosion_triggered:
                for p in self.plasma_particles:
                    p['age'] += dt
                    if p['age'] < p['lifetime']:
                        p['distance'] += p['speed'] * dt
                        p['alpha'] = int(255 * (1 - p['age'] / p['lifetime']))

            if self.animation_timer >= self.PHASE_FORMING:
                self.animation_phase = "active"
                self.freeze_screen = False
                self.collection_complete = True
                self.aura_intensity = 0
                print("[CrystalShield] Phase: active (게임 시작)")

        elif self.animation_phase == "active":
            # 활성 상태 - 블록들이 보스 주변 회전
            self.shield_blocks = [b for b in self.shield_blocks
                                 if b.update(dt, boss_x, boss_y)]

        return self.freeze_screen

    def _update_energy_rings(self, dt: float, condense_progress: float):
        """에너지 링 업데이트 - 응축됨에 따라 링이 작아지며 빛이 모임"""
        # 에너지 링 생성 (주기적으로)
        if random.random() < 0.3:  # 30% 확률로 새 링 생성
            self.energy_rings.append({
                'radius': 150 * (1.0 - condense_progress * 0.5),  # 응축됨에 따라 작아짐
                'target_radius': 30,  # 최종 수축 목표
                'alpha': 200,
                'hue': random.uniform(0, 1),
                'thickness': random.uniform(2, 5),
                'shrink_speed': random.uniform(80, 150),
            })

        # 기존 링 업데이트
        new_rings = []
        for ring in self.energy_rings:
            # 링이 중심으로 수축
            ring['radius'] -= ring['shrink_speed'] * dt * (0.5 + condense_progress)
            ring['alpha'] = int(200 * (ring['radius'] / 150))

            if ring['radius'] > ring['target_radius'] and ring['alpha'] > 0:
                new_rings.append(ring)

        self.energy_rings = new_rings

    def _boost_plasma_explosion(self):
        """플라즈마 폭발 파티클 강화"""
        # 기존 파티클 속도 및 크기 증가
        for p in self.plasma_particles:
            p['speed'] *= 1.5
            p['size'] *= 1.3
            p['lifetime'] *= 0.8  # 더 빨리 사라지게

        # 추가 폭발 파티클 생성
        for _ in range(50):
            angle = random.uniform(0, 2 * math.pi)
            self.plasma_particles.append({
                'angle': angle,
                'distance': 0,
                'speed': random.uniform(300, 600),
                'size': random.uniform(8, 20),
                'alpha': 255,
                'hue': random.uniform(0, 1),
                'lifetime': random.uniform(0.3, 0.7),
                'age': 0,
            })

    def _spawn_light_particles_for_block(self, block: Dict):
        """블록 주변에 빛 입자 생성"""
        for _ in range(3):  # 블록당 3개 입자
            angle = random.uniform(0, 2 * math.pi)
            self.light_particles.append({
                'x': block['x'],
                'y': block['y'],
                'vx': math.cos(angle) * random.uniform(20, 50),
                'vy': math.sin(angle) * random.uniform(20, 50),
                'size': random.uniform(3, 8),
                'alpha': 255,
                'hue': block['rainbow_offset'],
                'lifetime': random.uniform(1.0, 2.0),
                'age': 0,
                'pulse_offset': random.uniform(0, 2 * math.pi),
                'block_ref': block,  # 블록 참조 (따라다니기 위해)
            })

    def _update_light_particles(self, dt: float):
        """빛 입자 업데이트"""
        new_particles = []
        for p in self.light_particles:
            p['age'] += dt
            if p['age'] >= p['lifetime']:
                continue

            # 블록 따라다니기 (부드럽게)
            if p.get('block_ref'):
                block = p['block_ref']
                target_x = block['x'] + p['vx'] * 0.3
                target_y = block['y'] + p['vy'] * 0.3
                p['x'] += (target_x - p['x']) * dt * 2
                p['y'] += (target_y - p['y']) * dt * 2
            else:
                p['x'] += p['vx'] * dt
                p['y'] += p['vy'] * dt

            # 알파 펄스 (밝아졌다 투명 반복)
            pulse = math.sin(self.light_pulse_timer * 4 + p['pulse_offset'])
            base_alpha = 1.0 - (p['age'] / p['lifetime'])
            p['alpha'] = int(255 * base_alpha * (0.5 + 0.5 * pulse))

            new_particles.append(p)

        self.light_particles = new_particles

        # 떠다니는 블록들에서 추가 입자 생성 (지속적으로)
        for block in self.floating_blocks:
            if block['float_reached'] and random.random() < 0.05:  # 5% 확률
                self._spawn_light_particles_for_block(block)

    def _clear_board_blocks(self):
        """테트리스 보드에서 블록 제거 (floating으로 이동했으므로)"""
        if self.left_game_ref:
            for y in range(self.left_game_ref.rows):
                for x in range(self.left_game_ref.cols):
                    self.left_game_ref.board[y][x] = None
        if self.right_game_ref:
            for y in range(self.right_game_ref.rows):
                for x in range(self.right_game_ref.cols):
                    self.right_game_ref.board[y][x] = None

    def _create_final_shield_blocks(self):
        """최종 24개 실드 블록 생성 (여러 블록이 결합되어 형성)"""
        self.shield_blocks.clear()

        for i, target in enumerate(self.merge_targets):
            # 이 타겟에 결합된 블록들의 색상 혼합
            merged_colors = []
            for block in self.floating_blocks:
                if block['merge_target_idx'] == i:
                    merged_colors.append(block['color'])

            # 색상 평균 계산 (또는 무지개색 사용)
            if merged_colors:
                avg_r = sum(c[0] for c in merged_colors) // len(merged_colors)
                avg_g = sum(c[1] for c in merged_colors) // len(merged_colors)
                avg_b = sum(c[2] for c in merged_colors) // len(merged_colors)
                color = (avg_r, avg_g, avg_b)
            else:
                color = (100, 150, 200)

            # 실드 블록 생성
            orbit_x = self.boss_x + math.cos(target['orbit_angle']) * target['orbit_radius']
            orbit_y = self.boss_y + math.sin(target['orbit_angle']) * target['orbit_radius']

            shield_block = CrystalShieldBlock(
                start_x=orbit_x,
                start_y=orbit_y,
                target_x=self.boss_x,
                target_y=self.boss_y,
                color=color,
                block_size=16,
                orbit_angle=target['orbit_angle']
            )
            shield_block.phase = "orbiting"
            self.shield_blocks.append(shield_block)

        print(f"[CrystalShield] 최종 실드 블록 {len(self.shield_blocks)}개 생성")

    def draw(self, surface: pygame.Surface):
        """실드 시스템 그리기"""
        if not self.activated:
            return

        # 아우라 효과 그리기
        if self.animation_phase in ["aura", "floating", "gathering", "forming"]:
            self._draw_aura(surface)

        # 충격파 효과 그리기 (aura 페이즈 중)
        if self.animation_phase == "aura":
            self._draw_shockwave(surface)
            self._draw_injection_particles(surface)

        # 공중부양 블록들 그리기 (floating/gathering 페이즈)
        if self.animation_phase in ["floating", "gathering"]:
            self._draw_floating_blocks(surface)

        # 플라즈마 에너지 효과
        if self.animation_phase in ["gathering", "forming"]:
            self._draw_plasma_energy(surface)

        # 플라즈마 폭발 파티클
        if self.explosion_triggered:
            self._draw_plasma_explosion(surface)

        # 실드 블록들 그리기 (forming/active 페이즈)
        if self.animation_phase in ["forming", "active"]:
            for block in self.shield_blocks:
                block.draw(surface)

    def _draw_floating_blocks(self, surface: pygame.Surface):
        """공중부양 중인 블록들 그리기 (무지개빛 효과 + 빛 펄스)"""
        # 먼저 빛 입자 그리기 (블록 뒤에)
        self._draw_light_particles(surface)

        for block in self.floating_blocks:
            x, y = int(block['x']), int(block['y'])
            size = int(block.get('current_size', block['size']))
            base_alpha = int(block.get('alpha', 255))

            if base_alpha <= 0 or size <= 0:
                continue

            # 무지개 색상 계산
            hue = (block['rainbow_offset'] + self.animation_timer * 0.5) % 1.0
            r, g, b = self._hsv_to_rgb(hue, 0.7, 1.0)
            rainbow_color = (int(r * 255), int(g * 255), int(b * 255))

            # 빛 펄스 효과 (float_reached일 때만 밝아졌다 투명 반복)
            if block['float_reached']:
                pulse = math.sin(self.light_pulse_timer * 4 + block['rainbow_offset'] * 10)
                pulse_alpha = 0.5 + 0.5 * pulse  # 0.0 ~ 1.0 사이
                alpha = int(base_alpha * (0.4 + 0.6 * pulse_alpha))  # 최소 40% ~ 100%
                glow_intensity = 0.5 + 0.5 * pulse_alpha
            else:
                alpha = base_alpha
                glow_intensity = 0.5

            # 글로우 효과 (펄스에 따라 강도 변화)
            glow_size = size + int(10 * glow_intensity)
            glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
            glow_alpha = int(60 * glow_intensity)
            pygame.draw.rect(glow_surf, (*rainbow_color, glow_alpha),
                           (0, 0, glow_size, glow_size), border_radius=4)
            surface.blit(glow_surf, (x - glow_size // 2, y - glow_size // 2))

            # 메인 블록
            block_surf = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.rect(block_surf, (*rainbow_color, min(200, alpha)),
                           (0, 0, size, size), border_radius=2)
            # 테두리 (밝게 빛나는 효과)
            border_alpha = min(255, int(alpha * (0.8 + 0.4 * glow_intensity)))
            pygame.draw.rect(block_surf, (*rainbow_color, border_alpha),
                           (0, 0, size, size), 2, border_radius=2)
            surface.blit(block_surf, (x - size // 2, y - size // 2))

            # 블록 내부 하이라이트 (펄스에 따라)
            if block['float_reached'] and glow_intensity > 0.7:
                highlight_surf = pygame.Surface((size - 4, size - 4), pygame.SRCALPHA)
                highlight_alpha = int(100 * (glow_intensity - 0.5))
                pygame.draw.rect(highlight_surf, (255, 255, 255, highlight_alpha),
                               (0, 0, size - 4, size - 4), border_radius=1)
                surface.blit(highlight_surf, (x - size // 2 + 2, y - size // 2 + 2))

    def _draw_light_particles(self, surface: pygame.Surface):
        """빛 입자 그리기"""
        for p in self.light_particles:
            if p['alpha'] <= 0:
                continue

            x, y = int(p['x']), int(p['y'])
            size = int(p['size'])

            # 무지개 색상
            hue = (p['hue'] + self.animation_timer * 0.3) % 1.0
            r, g, b = self._hsv_to_rgb(hue, 0.5, 1.0)
            color = (int(r * 255), int(g * 255), int(b * 255))

            # 글로우 효과
            glow_size = size * 3
            glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*color, p['alpha'] // 4),
                             (glow_size, glow_size), glow_size)
            surface.blit(glow_surf, (x - glow_size, y - glow_size))

            # 코어 (밝은 중심)
            particle_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            pygame.draw.circle(particle_surf, (*color, p['alpha']),
                             (size, size), size)
            # 흰색 중심
            pygame.draw.circle(particle_surf, (255, 255, 255, p['alpha'] // 2),
                             (size, size), max(1, size // 2))
            surface.blit(particle_surf, (x - size, y - size))

    def _draw_aura(self, surface: pygame.Surface):
        """신비로운 아우라 효과"""
        if self.aura_intensity <= 0:
            return

        # 중앙 글로우
        glow_radius = int(100 * self.aura_intensity)
        if glow_radius > 0:
            glow_surface = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)

            for r in range(glow_radius, 0, -5):
                alpha = int(40 * (r / glow_radius) * self.aura_intensity)
                hue = (self.animation_timer * 0.3) % 1.0
                rgb = self._hsv_to_rgb(hue, 0.5, 1.0)
                color = (int(rgb[0] * 255), int(rgb[1] * 255), int(rgb[2] * 255), alpha)
                pygame.draw.circle(glow_surface, color, (glow_radius, glow_radius), r)

            surface.blit(glow_surface,
                        (int(self.boss_x - glow_radius), int(self.boss_y - glow_radius)))

        # 파티클들
        for p in self.aura_particles:
            px = self.boss_x + math.cos(p['angle']) * p['distance']
            py = self.boss_y + math.sin(p['angle']) * p['distance']
            rgb = self._hsv_to_rgb(p['hue'], 0.6, 1.0)
            color = (int(rgb[0] * 255), int(rgb[1] * 255), int(rgb[2] * 255))
            alpha = int(p['alpha'] * self.aura_intensity)
            if alpha > 0:
                particle_surface = pygame.Surface((int(p['size'] * 2), int(p['size'] * 2)), pygame.SRCALPHA)
                pygame.draw.circle(particle_surface, (*color, alpha),
                                 (int(p['size']), int(p['size'])), int(p['size']))
                surface.blit(particle_surface, (int(px - p['size']), int(py - p['size'])))

    def _draw_shockwave(self, surface: pygame.Surface):
        """충격파 효과 그리기 - 보스에서 사방으로 퍼지는 충격파"""
        if not self.shockwave_triggered:
            return

        # 충격파 링 그리기
        for p in self.shockwave_particles:
            if p['alpha'] <= 0:
                continue

            px = self.boss_x + math.cos(p['angle']) * p['distance']
            py = self.boss_y + math.sin(p['angle']) * p['distance']

            # 무지개 색상
            hue = (p['hue'] + self.animation_timer * 0.5) % 1.0
            rgb = self._hsv_to_rgb(hue, 0.7, 1.0)
            color = (int(rgb[0] * 255), int(rgb[1] * 255), int(rgb[2] * 255))

            alpha = int(p['alpha'])
            if alpha > 0:
                size = int(p['size'])
                if p['type'] == 'ring':
                    # 링 파티클 (약간 큰 글로우)
                    glow_size = size * 2
                    glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surf, (*color, alpha // 2),
                                     (glow_size, glow_size), glow_size)
                    pygame.draw.circle(glow_surf, (255, 255, 255, alpha),
                                     (glow_size, glow_size), size // 2)
                    surface.blit(glow_surf, (int(px - glow_size), int(py - glow_size)))
                else:
                    # 일반 파티클
                    particle_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(particle_surf, (*color, alpha),
                                     (size, size), size)
                    surface.blit(particle_surf, (int(px - size), int(py - size)))

        # 충격파 링 (확장되는 원형 링)
        if self.shockwave_phase == "exploding":
            shockwave_progress = (self.animation_timer - 1.2) / 0.3
            ring_radius = int(50 + shockwave_progress * 300)
            ring_alpha = int(200 * (1.0 - shockwave_progress))

            if ring_alpha > 0 and ring_radius > 0:
                # 외곽 충격파 링
                ring_surf = pygame.Surface((ring_radius * 2 + 20, ring_radius * 2 + 20), pygame.SRCALPHA)
                for thickness in range(5, 0, -1):
                    alpha = ring_alpha // (6 - thickness)
                    hue = (self.animation_timer * 2 + thickness * 0.1) % 1.0
                    rgb = self._hsv_to_rgb(hue, 0.6, 1.0)
                    color = (int(rgb[0] * 255), int(rgb[1] * 255), int(rgb[2] * 255), alpha)
                    pygame.draw.circle(ring_surf, color,
                                     (ring_radius + 10, ring_radius + 10), ring_radius, thickness)
                surface.blit(ring_surf, (int(self.boss_x - ring_radius - 10),
                                        int(self.boss_y - ring_radius - 10)))

    def _draw_injection_particles(self, surface: pygame.Surface):
        """주입 파티클 그리기 - 보스에서 좌우 테트로미노로 이동하는 에너지"""
        for p in self.injection_particles:
            if p['alpha'] <= 0:
                continue

            # 딜레이 중인 파티클은 그리지 않음
            if p['delay'] > 0:
                continue

            x, y = int(p['x']), int(p['y'])
            size = int(p['size'])

            # 무지개 색상
            hue = (p['hue'] + self.animation_timer * 0.8) % 1.0
            rgb = self._hsv_to_rgb(hue, 0.7, 1.0)
            color = (int(rgb[0] * 255), int(rgb[1] * 255), int(rgb[2] * 255))

            alpha = int(p['alpha'])

            # 꼬리 효과 (이동 궤적)
            if p['progress'] > 0.1 and not p['arrived']:
                trail_length = 5
                for t in range(trail_length):
                    trail_progress = max(0, p['progress'] - t * 0.05)
                    if trail_progress > 0:
                        eased = 1 - math.pow(1 - trail_progress, 3)
                        mid_y = min(self.boss_y, p['target_y']) - 50

                        if eased < 0.5:
                            tt = eased * 2
                            tx = self.boss_x + (p['target_x'] - self.boss_x) * tt * 0.5
                            ty = self.boss_y + (mid_y - self.boss_y) * tt
                        else:
                            tt = (eased - 0.5) * 2
                            mid_x = self.boss_x + (p['target_x'] - self.boss_x) * 0.5
                            tx = mid_x + (p['target_x'] - mid_x) * tt
                            ty = mid_y + (p['target_y'] - mid_y) * tt

                        trail_alpha = alpha // (t + 2)
                        trail_size = max(2, size - t * 2)
                        if trail_alpha > 0:
                            trail_surf = pygame.Surface((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
                            pygame.draw.circle(trail_surf, (*color, trail_alpha),
                                             (trail_size, trail_size), trail_size)
                            surface.blit(trail_surf, (int(tx - trail_size), int(ty - trail_size)))

            # 메인 파티클
            # 글로우
            glow_size = size * 2
            glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*color, alpha // 3),
                             (glow_size, glow_size), glow_size)
            surface.blit(glow_surf, (x - glow_size, y - glow_size))

            # 코어
            core_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            pygame.draw.circle(core_surf, (*color, alpha), (size, size), size)
            pygame.draw.circle(core_surf, (255, 255, 255, alpha // 2), (size, size), size // 2)
            surface.blit(core_surf, (x - size, y - size))

            # 도착 시 스파크 효과
            if p['arrived'] and p['alpha'] > 150:
                spark_size = size * 3
                spark_surf = pygame.Surface((spark_size * 2, spark_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(spark_surf, (255, 255, 255, int(p['alpha'] * 0.5)),
                                 (spark_size, spark_size), spark_size)
                surface.blit(spark_surf, (x - spark_size, y - spark_size))

    def _draw_plasma_energy(self, surface: pygame.Surface):
        """플라즈마 에너지 응축 효과 (무지개빛)"""
        if self.plasma_intensity <= 0:
            return

        # 에너지 링 (수축 중인 링들) 먼저 그리기
        self._draw_energy_rings(surface)

        # 응축 효과 - 빛 입자가 중심으로 모이는 효과
        if self.condensing_energy > 0:
            # 응축 빛 광선 (중심으로 향하는 선들)
            num_rays = 12
            for i in range(num_rays):
                angle = (2 * math.pi * i / num_rays) + self.animation_timer * 2
                hue = (i / num_rays + self.animation_timer * 0.5) % 1.0
                rgb = self._hsv_to_rgb(hue, 0.6, 1.0)
                color = (int(rgb[0] * 255), int(rgb[1] * 255), int(rgb[2] * 255))

                # 외부에서 중심으로 향하는 광선
                outer_dist = 120 * (1.0 - self.condensing_energy * 0.5)
                inner_dist = 30 * (1.0 - self.condensing_energy * 0.3)

                outer_x = self.boss_x + math.cos(angle) * outer_dist
                outer_y = self.boss_y + math.sin(angle) * outer_dist
                inner_x = self.boss_x + math.cos(angle) * inner_dist
                inner_y = self.boss_y + math.sin(angle) * inner_dist

                alpha = int(150 * self.condensing_energy)
                if alpha > 0:
                    # 광선 그리기
                    ray_surf = pygame.Surface((300, 300), pygame.SRCALPHA)
                    pygame.draw.line(ray_surf, (*color, alpha),
                                   (150 + int(outer_x - self.boss_x), 150 + int(outer_y - self.boss_y)),
                                   (150 + int(inner_x - self.boss_x), 150 + int(inner_y - self.boss_y)), 2)
                    surface.blit(ray_surf, (int(self.boss_x - 150), int(self.boss_y - 150)))

        # 무지개빛 플라즈마 링 (기본)
        ring_count = 5
        for i in range(ring_count):
            hue = (self.animation_timer * 0.5 + i * 0.2) % 1.0
            rgb = self._hsv_to_rgb(hue, 0.8, 1.0)
            color = (int(rgb[0] * 255), int(rgb[1] * 255), int(rgb[2] * 255))

            # 응축에 따라 링 크기 변화
            base_radius = (50 + i * 15) * (1.0 - self.condensing_energy * 0.3)
            radius = int(base_radius * self.plasma_intensity)
            alpha = int(100 * self.plasma_intensity * (1 - i / ring_count))

            if radius > 0 and alpha > 0:
                ring_surf = pygame.Surface((radius * 2 + 4, radius * 2 + 4), pygame.SRCALPHA)
                pygame.draw.circle(ring_surf, (*color, alpha), (radius + 2, radius + 2), radius, 3)
                surface.blit(ring_surf, (int(self.boss_x - radius - 2), int(self.boss_y - radius - 2)))

        # 중앙 에너지 코어 (응축될수록 밝아짐)
        core_intensity = self.plasma_intensity * (1.0 + self.condensing_energy)
        core_radius = int(30 * min(1.5, core_intensity))
        if core_radius > 0:
            core_surf = pygame.Surface((core_radius * 2, core_radius * 2), pygame.SRCALPHA)
            for r in range(core_radius, 0, -3):
                hue = (self.animation_timer * 2 + r * 0.05) % 1.0
                rgb = self._hsv_to_rgb(hue, 0.6, 1.0)
                color = (int(rgb[0] * 255), int(rgb[1] * 255), int(rgb[2] * 255))
                alpha = int(200 * (r / core_radius) * min(1.0, core_intensity))
                pygame.draw.circle(core_surf, (*color, alpha), (core_radius, core_radius), r)
            surface.blit(core_surf, (int(self.boss_x - core_radius), int(self.boss_y - core_radius)))

            # 응축 시 흰색 코어 추가
            if self.condensing_energy > 0.5:
                white_radius = int(15 * (self.condensing_energy - 0.5) * 2)
                if white_radius > 0:
                    white_alpha = int(200 * (self.condensing_energy - 0.5) * 2)
                    white_surf = pygame.Surface((white_radius * 2, white_radius * 2), pygame.SRCALPHA)
                    pygame.draw.circle(white_surf, (255, 255, 255, white_alpha),
                                     (white_radius, white_radius), white_radius)
                    surface.blit(white_surf, (int(self.boss_x - white_radius), int(self.boss_y - white_radius)))

    def _draw_energy_rings(self, surface: pygame.Surface):
        """수축 중인 에너지 링 그리기"""
        for ring in self.energy_rings:
            if ring['alpha'] <= 0 or ring['radius'] <= 0:
                continue

            radius = int(ring['radius'])
            hue = (ring['hue'] + self.animation_timer * 0.5) % 1.0
            rgb = self._hsv_to_rgb(hue, 0.7, 1.0)
            color = (int(rgb[0] * 255), int(rgb[1] * 255), int(rgb[2] * 255))

            ring_surf = pygame.Surface((radius * 2 + 10, radius * 2 + 10), pygame.SRCALPHA)
            thickness = int(ring['thickness'])
            pygame.draw.circle(ring_surf, (*color, ring['alpha']),
                             (radius + 5, radius + 5), radius, thickness)
            surface.blit(ring_surf, (int(self.boss_x - radius - 5), int(self.boss_y - radius - 5)))

    def _draw_plasma_explosion(self, surface: pygame.Surface):
        """플라즈마 폭발 파티클"""
        for p in self.plasma_particles:
            if p['alpha'] <= 0:
                continue

            px = self.boss_x + math.cos(p['angle']) * p['distance']
            py = self.boss_y + math.sin(p['angle']) * p['distance']

            hue = (p['hue'] + self.animation_timer) % 1.0
            rgb = self._hsv_to_rgb(hue, 0.7, 1.0)
            color = (int(rgb[0] * 255), int(rgb[1] * 255), int(rgb[2] * 255))

            size = int(p['size'] * (1 - p['age'] / p['lifetime']))
            if size > 0:
                particle_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(particle_surf, (*color, p['alpha']),
                                 (size, size), size)
                surface.blit(particle_surf, (int(px - size), int(py - size)))

    def _hsv_to_rgb(self, h, s, v):
        """HSV to RGB 변환"""
        i = int(h * 6)
        f = h * 6 - i
        p = v * (1 - s)
        q = v * (1 - f * s)
        t = v * (1 - (1 - f) * s)
        i = i % 6
        if i == 0: return (v, t, p)
        if i == 1: return (q, v, p)
        if i == 2: return (p, v, t)
        if i == 3: return (p, q, v)
        if i == 4: return (t, p, v)
        return (v, p, q)

    def check_ball_collision(self, ball_rect: pygame.Rect, is_player_ball: bool) -> Optional[CrystalShieldBlock]:
        """공과 실드 블록 충돌 체크

        Args:
            ball_rect: 공의 rect
            is_player_ball: 플레이어 공인지 여부

        Returns:
            충돌한 블록 (플레이어 공일 경우만), 없으면 None
        """
        if not is_player_ball:
            # 보스 공은 충돌 무시
            return None

        # 궤도 상에서 활성 블록만 모아서 각도 순으로 정렬
        orbiting_blocks = [(i, block) for i, block in enumerate(self.shield_blocks)
                          if block.active and block.phase == "orbiting"]

        if not orbiting_blocks:
            return None

        # 각도 순으로 정렬 (인접 블록 찾기 위해)
        orbiting_blocks.sort(key=lambda x: x[1].orbit_angle % (2 * math.pi))

        # 공 중심 좌표
        ball_cx = ball_rect.centerx
        ball_cy = ball_rect.centery

        for list_idx, (block_idx, block) in enumerate(orbiting_blocks):
            # 확장된 충돌 영역 사용 (터널링 방지)
            collision_rect = block.get_collision_rect()
            if ball_rect.colliderect(collision_rect):
                # 추가 확인: 공 중심과 블록 중심 사이의 거리 체크
                # 블록 중심
                block_cx = block.x
                block_cy = block.y
                dx = ball_cx - block_cx
                dy = ball_cy - block_cy
                dist_sq = dx * dx + dy * dy
                # 블록 실제 크기 기반 충돌 반경 (공 반지름 + 블록 반지름)
                block_radius = block.size / 2
                ball_radius = max(ball_rect.width, ball_rect.height) / 2
                hit_radius = block_radius + ball_radius + 8  # 추가 여유분
                hit_radius_sq = hit_radius * hit_radius

                if dist_sq <= hit_radius_sq:
                    # 피격된 블록 증발
                    block.hit_evaporate()

                    # 양옆 인접 블록도 증발 (홀로그램 효과)
                    total_orbiting = len(orbiting_blocks)
                    if total_orbiting > 1:
                        # 왼쪽 인접 블록 (이전 인덱스)
                        left_idx = (list_idx - 1) % total_orbiting
                        left_block = orbiting_blocks[left_idx][1]
                        if left_block.active:
                            left_block.hit_evaporate()

                        # 오른쪽 인접 블록 (다음 인덱스)
                        right_idx = (list_idx + 1) % total_orbiting
                        right_block = orbiting_blocks[right_idx][1]
                        if right_block.active:
                            right_block.hit_evaporate()

                    return block

        return None

    def get_active_block_count(self) -> int:
        """활성 블록 수 반환"""
        return sum(1 for b in self.shield_blocks if b.active)

    def reset(self):
        """시스템 리셋"""
        self.shield_blocks.clear()
        self.aura_particles.clear()
        self.plasma_particles.clear()
        self.floating_blocks.clear()
        self.merge_targets.clear()
        self.light_particles.clear()  # 빛 입자 초기화
        self.energy_rings.clear()  # 에너지 링 초기화
        self.activated = False
        self.pending_activation = False
        self.animation_phase = "idle"
        self.animation_timer = 0.0
        self.freeze_screen = False
        self.collection_complete = False
        self.plasma_intensity = 0.0
        self.aura_intensity = 0.0
        self.explosion_triggered = False
        self.aura_fade_out = False
        self.aura_fade_timer = 0.0
        self.light_pulse_timer = 0.0  # 빛 펄스 타이머 초기화
        self.condensing_energy = 0.0  # 응축 에너지 초기화
        self.left_game_ref = None
        self.right_game_ref = None
        # screen_width와 screen_height는 유지


class TetrisUIPanel:
    """고전 테트리스 스타일 UI 패널 (사이버틱 네온 스타일)"""

    def __init__(self, x: int, y: int, width: int, height: int, title: str = ""):
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.title = title
        self.time = 0.0

        # 네온 색상
        self.border_color = (60, 100, 160)
        self.bg_color = (15, 25, 45)
        self.glow_color = (80, 140, 255)
        self.text_color = (200, 220, 255)
        self.accent_color = (0, 255, 255)  # 시안

    def update(self, dt: float):
        self.time += dt

    def draw(self, surface: pygame.Surface, content_callback=None):
        """패널 그리기"""
        # 글로우 효과 (펄스)
        pulse = 0.7 + 0.3 * math.sin(self.time * 2.0)
        glow_alpha = int(30 * pulse)

        # 외곽 글로우
        for i in range(3, 0, -1):
            glow_rect = pygame.Rect(self.x - i, self.y - i,
                                   self.width + i * 2, self.height + i * 2)
            glow_surf = pygame.Surface((self.width + i * 2 + 2, self.height + i * 2 + 2), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*self.glow_color, glow_alpha // i),
                           (0, 0, glow_surf.get_width(), glow_surf.get_height()),
                           border_radius=3)
            surface.blit(glow_surf, (self.x - i - 1, self.y - i - 1))

        # 배경
        bg_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        pygame.draw.rect(bg_surf, (*self.bg_color, 200),
                        (0, 0, self.width, self.height), border_radius=2)
        surface.blit(bg_surf, (self.x, self.y))

        # 테두리 (네온 스타일)
        pygame.draw.rect(surface, self.border_color,
                        (self.x, self.y, self.width, self.height), 2, border_radius=2)

        # 내부 테두리 (하이라이트)
        inner_rect = pygame.Rect(self.x + 2, self.y + 2, self.width - 4, self.height - 4)
        pygame.draw.rect(surface, (*self.glow_color, 40), inner_rect, 1, border_radius=1)

        # 타이틀
        if self.title:
            self._draw_title(surface)

        # 컨텐츠 콜백
        if content_callback:
            content_callback(surface, self.x, self.y, self.width, self.height)

    def _draw_title(self, surface: pygame.Surface):
        """타이틀 그리기 (네온 스타일)"""
        try:
            font = pygame.font.Font(None, 16)
        except:
            font = pygame.font.SysFont('Arial', 12)

        # 타이틀 배경
        title_height = 18
        title_rect = pygame.Rect(self.x, self.y, self.width, title_height)
        pygame.draw.rect(surface, (*self.border_color, 150), title_rect, border_radius=2)
        pygame.draw.rect(surface, (*self.border_color, 200), title_rect, 0, border_radius=2)

        # 타이틀 텍스트
        text_surf = font.render(self.title, True, self.accent_color)
        text_x = self.x + (self.width - text_surf.get_width()) // 2
        text_y = self.y + (title_height - text_surf.get_height()) // 2 + 1
        surface.blit(text_surf, (text_x, text_y))


class TetrisGame:
    """한쪽 필러의 테트리스 게임 로직"""

    TETROMINOS = {
        'I': [[(0, 0), (1, 0), (2, 0), (3, 0)],
              [(0, 0), (0, 1), (0, 2), (0, 3)],
              [(0, 0), (1, 0), (2, 0), (3, 0)],
              [(0, 0), (0, 1), (0, 2), (0, 3)]],
        'O': [[(0, 0), (1, 0), (0, 1), (1, 1)],
              [(0, 0), (1, 0), (0, 1), (1, 1)],
              [(0, 0), (1, 0), (0, 1), (1, 1)],
              [(0, 0), (1, 0), (0, 1), (1, 1)]],
        'T': [[(0, 0), (1, 0), (2, 0), (1, 1)],
              [(1, 0), (0, 1), (1, 1), (1, 2)],
              [(1, 0), (0, 1), (1, 1), (2, 1)],
              [(0, 0), (0, 1), (1, 1), (0, 2)]],
        'S': [[(1, 0), (2, 0), (0, 1), (1, 1)],
              [(0, 0), (0, 1), (1, 1), (1, 2)],
              [(1, 0), (2, 0), (0, 1), (1, 1)],
              [(0, 0), (0, 1), (1, 1), (1, 2)]],
        'Z': [[(0, 0), (1, 0), (1, 1), (2, 1)],
              [(1, 0), (0, 1), (1, 1), (0, 2)],
              [(0, 0), (1, 0), (1, 1), (2, 1)],
              [(1, 0), (0, 1), (1, 1), (0, 2)]],
        'J': [[(0, 0), (0, 1), (1, 1), (2, 1)],
              [(0, 0), (1, 0), (0, 1), (0, 2)],
              [(0, 0), (1, 0), (2, 0), (2, 1)],
              [(1, 0), (1, 1), (0, 2), (1, 2)]],
        'L': [[(2, 0), (0, 1), (1, 1), (2, 1)],
              [(0, 0), (0, 1), (0, 2), (1, 2)],
              [(0, 0), (1, 0), (2, 0), (0, 1)],
              [(0, 0), (1, 0), (1, 1), (1, 2)]],
    }

    # 세련된 뮤트 색상
    COLORS = {
        'I': (70, 140, 150),
        'O': (150, 140, 80),
        'T': (110, 80, 140),
        'S': (80, 130, 90),
        'Z': (140, 80, 90),
        'J': (70, 90, 140),
        'L': (140, 110, 80),
    }

    def __init__(self, cols: int, rows: int, block_size: int, offset_x: int, offset_y: int):
        self.cols = cols
        self.rows = rows
        self.block_size = block_size
        self.offset_x = offset_x
        self.offset_y = offset_y

        # 게임 보드 (None = 빈칸, 색상 = 블록)
        self.board: List[List[Optional[Tuple[int, int, int]]]] = [
            [None for _ in range(cols)] for _ in range(rows)
        ]

        # 현재 떨어지는 블록
        self.current_piece: Optional[dict] = None
        # NEXT 블록 (다음에 나올 블록)
        self.next_piece_type: str = random.choice(list(self.TETROMINOS.keys()))
        self.spawn_piece()

        # 점수/레벨/라인 (고전 테트리스 스타일)
        self.score: int = 0
        self.level: int = 1
        self.lines_cleared: int = 0

        # 타이머
        self.fall_timer = 0.0
        self.fall_speed = 0.4  # 초당 2.5칸 (2배 빠르게)
        self.move_timer = 0.0
        self.move_delay = 0.2  # 좌우 이동 간격 (더 빠르게)
        self.rotate_timer = 0.0
        self.rotate_delay = 0.4  # 회전 간격 (더 빠르게)

        # 라인 클리어 애니메이션
        self.clearing_lines: List[int] = []
        self.clear_timer = 0.0
        self.clear_duration = 0.3

        # 무지개 애니메이션 타이머
        self.rainbow_time = 0.0

    def spawn_piece(self):
        """새 블록 생성 - NEXT 시스템 사용"""
        piece_type = self.next_piece_type
        self.next_piece_type = random.choice(list(self.TETROMINOS.keys()))
        self.current_piece = {
            'type': piece_type,
            'rotation': 0,
            'x': random.randint(0, max(0, self.cols - 4)),
            'y': -2,
            'color': self.COLORS[piece_type],
        }

    def get_piece_blocks(self, piece: dict) -> List[Tuple[int, int]]:
        """현재 회전 상태의 블록 좌표들 반환"""
        rotations = self.TETROMINOS[piece['type']]
        blocks = rotations[piece['rotation'] % len(rotations)]
        return [(piece['x'] + bx, piece['y'] + by) for bx, by in blocks]

    def is_valid_position(self, piece: dict, dx: int = 0, dy: int = 0, dr: int = 0) -> bool:
        """위치가 유효한지 확인"""
        test_piece = piece.copy()
        test_piece['x'] += dx
        test_piece['y'] += dy
        test_piece['rotation'] = (piece['rotation'] + dr) % 4

        for bx, by in self.get_piece_blocks(test_piece):
            # 좌우 벽 체크
            if bx < 0 or bx >= self.cols:
                return False
            # 바닥 체크
            if by >= self.rows:
                return False
            # 다른 블록과 충돌 체크
            if by >= 0 and self.board[by][bx] is not None:
                return False

        return True

    def lock_piece(self):
        """현재 블록을 보드에 고정"""
        if not self.current_piece:
            return

        for bx, by in self.get_piece_blocks(self.current_piece):
            if 0 <= by < self.rows and 0 <= bx < self.cols:
                self.board[by][bx] = self.current_piece['color']

        # 라인 클리어 체크
        self.check_lines()

        # 새 블록 생성
        self.spawn_piece()

    def check_lines(self):
        """완성된 라인 체크"""
        self.clearing_lines = []
        for y in range(self.rows):
            if all(self.board[y][x] is not None for x in range(self.cols)):
                self.clearing_lines.append(y)

        if self.clearing_lines:
            self.clear_timer = self.clear_duration

    def clear_lines(self):
        """라인 삭제 처리"""
        num_lines = len(self.clearing_lines)
        for y in sorted(self.clearing_lines, reverse=True):
            del self.board[y]
            self.board.insert(0, [None for _ in range(self.cols)])

        # 점수 계산 (고전 테트리스 스타일)
        score_table = {1: 100, 2: 300, 3: 500, 4: 800}
        self.score += score_table.get(num_lines, 0) * self.level
        self.lines_cleared += num_lines

        # 레벨업 (10줄마다)
        self.level = 1 + self.lines_cleared // 10

        self.clearing_lines = []

    def update(self, dt: float):
        """게임 업데이트"""
        # 무지개 애니메이션 타이머
        self.rainbow_time += dt

        # 라인 클리어 애니메이션 처리
        if self.clearing_lines:
            self.clear_timer -= dt
            if self.clear_timer <= 0:
                self.clear_lines()
            return

        if not self.current_piece:
            self.spawn_piece()
            return

        # 랜덤 좌우 이동
        self.move_timer += dt
        if self.move_timer >= self.move_delay:
            self.move_timer = 0
            if random.random() < 0.4:  # 40% 확률로 이동
                direction = random.choice([-1, 1])
                if self.is_valid_position(self.current_piece, dx=direction):
                    self.current_piece['x'] += direction

        # 랜덤 회전
        self.rotate_timer += dt
        if self.rotate_timer >= self.rotate_delay:
            self.rotate_timer = 0
            if random.random() < 0.25:  # 25% 확률로 회전
                if self.is_valid_position(self.current_piece, dr=1):
                    self.current_piece['rotation'] = (self.current_piece['rotation'] + 1) % 4

        # 아래로 이동
        self.fall_timer += dt
        if self.fall_timer >= self.fall_speed:
            self.fall_timer = 0
            if self.is_valid_position(self.current_piece, dy=1):
                self.current_piece['y'] += 1
            else:
                self.lock_piece()

    def draw(self, surface: pygame.Surface):
        """보드와 현재 블록 그리기"""
        # 쌓인 블록들
        for y in range(self.rows):
            for x in range(self.cols):
                if self.board[y][x] is not None:
                    color = self.board[y][x]
                    # 라인 클리어 애니메이션
                    if y in self.clearing_lines:
                        flash = int(255 * (self.clear_timer / self.clear_duration))
                        color = (flash, flash, flash)

                    self._draw_block(surface, x, y, color, is_falling=False)

        # 현재 떨어지는 블록
        if self.current_piece and not self.clearing_lines:
            for bx, by in self.get_piece_blocks(self.current_piece):
                if by >= 0:
                    self._draw_block(surface, bx, by, self.current_piece['color'], is_falling=True)

    def draw_next_preview(self, surface: pygame.Surface, panel_x: int, panel_y: int,
                          panel_width: int, panel_height: int):
        """NEXT 블록 미리보기 그리기"""
        if not self.next_piece_type:
            return

        # NEXT 블록의 형태 가져오기
        rotations = self.TETROMINOS[self.next_piece_type]
        blocks = rotations[0]  # 기본 회전 상태
        color = self.COLORS[self.next_piece_type]

        # 미니 블록 크기 (패널에 맞게)
        mini_size = min(10, (panel_width - 20) // 5, (panel_height - 30) // 5)

        # 블록의 바운딩 박스 계산
        min_x = min(b[0] for b in blocks)
        max_x = max(b[0] for b in blocks)
        min_y = min(b[1] for b in blocks)
        max_y = max(b[1] for b in blocks)
        block_width = (max_x - min_x + 1) * mini_size
        block_height = (max_y - min_y + 1) * mini_size

        # 패널 중앙에 배치 (타이틀 영역 피해서)
        start_x = panel_x + (panel_width - block_width) // 2
        start_y = panel_y + 22 + (panel_height - 26 - block_height) // 2

        # 무지개 효과
        hue_offset = (self.rainbow_time * 0.5) % 1.0

        for bx, by in blocks:
            px = start_x + (bx - min_x) * mini_size
            py = start_y + (by - min_y) * mini_size

            # 무지개 색상 계산
            hue = (hue_offset + bx * 0.2 + by * 0.15) % 1.0
            r, g, b = self._hsv_to_rgb(hue, 0.7, 1.0)
            rainbow_color = (int(r * 255), int(g * 255), int(b * 255))

            # 글로우
            pygame.draw.rect(surface, (*rainbow_color, 20),
                           (px - 1, py - 1, mini_size + 2, mini_size + 2), border_radius=2)
            # 메인 블록
            pygame.draw.rect(surface, (*rainbow_color, 60),
                           (px, py, mini_size - 1, mini_size - 1), border_radius=1)
            # 테두리
            pygame.draw.rect(surface, (*rainbow_color, 120),
                           (px, py, mini_size - 1, mini_size - 1), 1, border_radius=1)

    def draw_stats_panel(self, surface: pygame.Surface, panel_x: int, panel_y: int,
                         panel_width: int, panel_height: int, stat_type: str):
        """SCORE/LEVEL/LINES 패널 그리기"""
        try:
            font = pygame.font.Font(None, 14)
            value_font = pygame.font.Font(None, 18)
        except:
            font = pygame.font.SysFont('Arial', 10)
            value_font = pygame.font.SysFont('Arial', 14)

        # 값 가져오기
        if stat_type == "SCORE":
            value = str(self.score)
            accent = (0, 255, 200)  # 시안-그린
        elif stat_type == "LEVEL":
            value = str(self.level)
            accent = (255, 200, 0)  # 골드
        else:  # LINES
            value = str(self.lines_cleared)
            accent = (255, 100, 255)  # 마젠타

        # 값 텍스트 (가운데 정렬)
        value_surf = value_font.render(value, True, accent)
        value_x = panel_x + (panel_width - value_surf.get_width()) // 2
        value_y = panel_y + 20 + (panel_height - 24 - value_surf.get_height()) // 2
        surface.blit(value_surf, (value_x, value_y))

        # 글로우 효과 (값 주변)
        glow_surf = pygame.Surface((value_surf.get_width() + 10, value_surf.get_height() + 6), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*accent, 15),
                        (0, 0, glow_surf.get_width(), glow_surf.get_height()), border_radius=3)
        surface.blit(glow_surf, (value_x - 5, value_y - 3))
        surface.blit(value_surf, (value_x, value_y))

    def _hsv_to_rgb(self, h, s, v):
        """HSV to RGB 변환"""
        i = int(h * 6)
        f = h * 6 - i
        p = v * (1 - s)
        q = v * (1 - f * s)
        t = v * (1 - (1 - f) * s)
        i = i % 6
        if i == 0: return (v, t, p)
        if i == 1: return (q, v, p)
        if i == 2: return (p, v, t)
        if i == 3: return (p, q, v)
        if i == 4: return (t, p, v)
        return (v, p, q)

    def _draw_block(self, surface: pygame.Surface, grid_x: int, grid_y: int,
                    color: Tuple[int, int, int], is_falling: bool = False):
        """단일 블록 그리기 - 무지개빛 홀로그램 프리즘 스타일"""
        px = self.offset_x + grid_x * self.block_size
        py = self.offset_y + grid_y * self.block_size
        size = self.block_size - 1

        # 위치에 따른 무지개 색상 계산 (프리즘 효과)
        hue_offset = (grid_x * 0.3 + grid_y * 0.2 + self.rainbow_time * 0.5) % 1.0

        # HSV to RGB 변환 (무지개 스펙트럼)
        def hsv_to_rgb(h, s, v):
            i = int(h * 6)
            f = h * 6 - i
            p = v * (1 - s)
            q = v * (1 - f * s)
            t = v * (1 - (1 - f) * s)
            i = i % 6
            if i == 0: return (v, t, p)
            if i == 1: return (q, v, p)
            if i == 2: return (p, v, t)
            if i == 3: return (p, q, v)
            if i == 4: return (t, p, v)
            return (v, p, q)

        r, g, b = hsv_to_rgb(hue_offset, 0.6, 1.0)
        rainbow_color = (int(r * 255), int(g * 255), int(b * 255))

        # 투명도 설정 (80% 더 투명하게)
        if is_falling:
            base_alpha = 4
            inner_alpha = 2
            glow_alpha = 1
        else:
            base_alpha = 3
            inner_alpha = 1
            glow_alpha = 1

        # 외곽 글로우 (부드러운 빛 번짐)
        glow_rect = pygame.Rect(px - 1, py - 1, size + 2, size + 2)
        pygame.draw.rect(surface, (*rainbow_color, glow_alpha), glow_rect, border_radius=2)

        # 메인 외곽선 (무지개빛)
        pygame.draw.rect(surface, (*rainbow_color, base_alpha),
                        (px, py, size, size), 1, border_radius=1)

        # 내부 미세 채움 (유리 느낌)
        inner_rect = pygame.Rect(px + 1, py + 1, size - 2, size - 2)
        pygame.draw.rect(surface, (*rainbow_color, inner_alpha), inner_rect, border_radius=1)

        # 하이라이트 (상단 좌측 - 빛 반사)
        highlight_color = (255, 255, 255)
        pygame.draw.line(surface, (*highlight_color, inner_alpha),
                        (px + 2, py + 2), (px + size // 3, py + 2), 1)
        pygame.draw.line(surface, (*highlight_color, inner_alpha),
                        (px + 2, py + 2), (px + 2, py + size // 3), 1)


class TetriserPillarBackground:
    """테트리서 스타일 필러 배경 - 고전 테트리스 레이아웃 + 사이버틱 스타일"""

    # 배경 그라데이션 색상
    BG_COLORS = {
        'top': (30, 50, 80),
        'mid': (40, 65, 100),
        'bottom': (15, 28, 50),
        'deep': (10, 18, 35),
    }

    # 프레임 색상
    FRAME_COLORS = {
        'dark': (25, 40, 65),
        'mid': (45, 70, 105),
        'light': (70, 100, 140),
    }

    # 사이버틱 네온 색상
    NEON_COLORS = {
        'cyan': (0, 255, 255),
        'magenta': (255, 0, 255),
        'yellow': (255, 255, 0),
        'green': (0, 255, 128),
        'blue': (80, 140, 255),
        'panel_bg': (15, 25, 45),
        'panel_border': (60, 100, 160),
        'text_glow': (100, 180, 255),
    }

    def __init__(self, screen_width: int, screen_height: int,
                 game_width: int, game_height: int):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        self.time = 0.0

        # 블록 크기 계산
        self.block_size = max(12, min(18, self.game_x // 10))

        # 좌우 테트리스 게임 초기화
        self.left_game: Optional[TetrisGame] = None
        self.right_game: Optional[TetrisGame] = None
        self._init_games()

        # 배경 캐시
        self._bg_cache: Optional[pygame.Surface] = None
        self._create_bg_cache()

        # 크리스탈 실드 시스템
        self.crystal_shield = CrystalShieldSystem()
        self.tetris_stopped = False  # 실드 활성화 후 테트리스 중지

        # UI 패널들 (고전 테트리스 레이아웃)
        self._init_ui_panels()

    def _init_ui_panels(self):
        """고전 테트리스 스타일 UI 패널 초기화"""
        # 패널 크기 설정
        panel_width = min(70, self.game_x - 20)
        panel_height_next = 55  # NEXT 패널
        panel_height_stat = 38  # 통계 패널
        panel_spacing = 8

        # 좌측 패널들 (NEXT, SCORE)
        left_panel_x = 8

        self.left_next_panel = TetrisUIPanel(
            left_panel_x, 30, panel_width, panel_height_next, "NEXT"
        )
        self.left_score_panel = TetrisUIPanel(
            left_panel_x, 30 + panel_height_next + panel_spacing,
            panel_width, panel_height_stat, "SCORE"
        )
        self.left_level_panel = TetrisUIPanel(
            left_panel_x, 30 + panel_height_next + panel_height_stat + panel_spacing * 2,
            panel_width, panel_height_stat, "LEVEL"
        )
        self.left_lines_panel = TetrisUIPanel(
            left_panel_x, 30 + panel_height_next + panel_height_stat * 2 + panel_spacing * 3,
            panel_width, panel_height_stat, "LINES"
        )

        # 우측 패널들
        right_start = self.game_x + self.game_width
        right_panel_x = right_start + 8

        self.right_next_panel = TetrisUIPanel(
            right_panel_x, 30, panel_width, panel_height_next, "NEXT"
        )
        self.right_score_panel = TetrisUIPanel(
            right_panel_x, 30 + panel_height_next + panel_spacing,
            panel_width, panel_height_stat, "SCORE"
        )
        self.right_level_panel = TetrisUIPanel(
            right_panel_x, 30 + panel_height_next + panel_height_stat + panel_spacing * 2,
            panel_width, panel_height_stat, "LEVEL"
        )
        self.right_lines_panel = TetrisUIPanel(
            right_panel_x, 30 + panel_height_next + panel_height_stat * 2 + panel_spacing * 3,
            panel_width, panel_height_stat, "LINES"
        )

    def _init_games(self):
        """좌우 테트리스 게임 초기화"""
        # 좌측 필러
        if self.game_x > 60:
            cols = max(4, (self.game_x - 20) // self.block_size)
            rows = self.screen_height // self.block_size
            self.left_game = TetrisGame(
                cols=cols,
                rows=rows,
                block_size=self.block_size,
                offset_x=10,
                offset_y=0
            )

        # 우측 필러
        right_start = self.game_x + self.game_width
        right_width = self.screen_width - right_start
        if right_width > 60:
            cols = max(4, (right_width - 20) // self.block_size)
            rows = self.screen_height // self.block_size
            self.right_game = TetrisGame(
                cols=cols,
                rows=rows,
                block_size=self.block_size,
                offset_x=right_start + 10,
                offset_y=0
            )

    def _create_bg_cache(self):
        """배경 캐시 생성 (단순 그라데이션)"""
        self._bg_cache = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )

        top = self.BG_COLORS['top']
        mid = self.BG_COLORS['mid']
        bottom = self.BG_COLORS['bottom']

        # 전체 화면에 세로 그라데이션 (모든 영역을 빈틈없이 채움)
        for y in range(0, self.screen_height + 2, 2):
            ratio = y / max(1, self.screen_height)

            if ratio < 0.5:
                t = ratio * 2
                color = (
                    int(top[0] + (mid[0] - top[0]) * t),
                    int(top[1] + (mid[1] - top[1]) * t),
                    int(top[2] + (mid[2] - top[2]) * t),
                )
            else:
                t = (ratio - 0.5) * 2
                color = (
                    int(mid[0] + (bottom[0] - mid[0]) * t),
                    int(mid[1] + (bottom[1] - mid[1]) * t),
                    int(mid[2] + (bottom[2] - mid[2]) * t),
                )

            # 전체 너비로 그라데이션 (좌측 + 우측 필러 + 상하단 모서리 모두 포함)
            pygame.draw.rect(self._bg_cache, color, (0, y, self.screen_width, 2))

        # 상하단은 더 어두운 색으로 덮어씌움
        if self.game_y > 0:
            pygame.draw.rect(self._bg_cache, self.BG_COLORS['deep'],
                           (0, 0, self.screen_width, self.game_y))
        bottom_start = self.game_y + self.game_height
        if bottom_start < self.screen_height:
            pygame.draw.rect(self._bg_cache, self.BG_COLORS['deep'],
                           (0, bottom_start, self.screen_width, self.screen_height - bottom_start))

        # 은은한 그리드 라인
        self._draw_subtle_grid(self._bg_cache)

        # 프레임
        self._draw_frame(self._bg_cache)

    def _draw_subtle_grid(self, surface: pygame.Surface):
        """은은한 그리드 라인"""
        grid_color = (50, 70, 100, 25)

        # 좌측 필러 그리드
        if self.game_x > 20:
            for y in range(0, self.screen_height, self.block_size):
                pygame.draw.line(surface, grid_color, (0, y), (self.game_x - 5, y), 1)
            for x in range(0, self.game_x, self.block_size):
                pygame.draw.line(surface, grid_color, (x, 0), (x, self.screen_height), 1)

        # 우측 필러 그리드
        right_start = self.game_x + self.game_width + 5
        if right_start < self.screen_width:
            for y in range(0, self.screen_height, self.block_size):
                pygame.draw.line(surface, grid_color, (right_start, y), (self.screen_width, y), 1)
            for x in range(right_start, self.screen_width, self.block_size):
                pygame.draw.line(surface, grid_color, (x, 0), (x, self.screen_height), 1)

    def _draw_frame(self, surface: pygame.Surface):
        """프레임 테두리"""
        # 외곽 프레임
        border_width = 8
        for i in range(border_width):
            t = i / border_width
            if t < 0.5:
                color = self.FRAME_COLORS['dark']
            else:
                color = self.FRAME_COLORS['mid']

            rect = pygame.Rect(i, i, self.screen_width - i * 2, self.screen_height - i * 2)
            pygame.draw.rect(surface, (*color, 200), rect, 1)

        # 내곽 프레임 (게임 영역 주변)
        margin = 8
        inner_rect = pygame.Rect(
            self.game_x - margin,
            self.game_y - margin,
            self.game_width + margin * 2,
            self.game_height + margin * 2
        )

        # 그라데이션 테두리
        for i in range(4):
            alpha = 100 - i * 20
            color = self.FRAME_COLORS['light']
            rect = inner_rect.inflate(-i * 2, -i * 2)
            pygame.draw.rect(surface, (*color, alpha), rect, 1)

    def update(self, dt: float, boss_x: float = 0, boss_y: float = 0):
        """업데이트"""
        self.time += dt

        # 크리스탈 실드 시스템 업데이트
        if self.crystal_shield.activated:
            self.crystal_shield.update(dt, boss_x, boss_y)

        # UI 패널 업데이트
        self.left_next_panel.update(dt)
        self.left_score_panel.update(dt)
        self.left_level_panel.update(dt)
        self.left_lines_panel.update(dt)
        self.right_next_panel.update(dt)
        self.right_score_panel.update(dt)
        self.right_level_panel.update(dt)
        self.right_lines_panel.update(dt)

        # 테트리스가 중지되지 않았을 때만 업데이트
        if not self.tetris_stopped:
            if self.left_game:
                self.left_game.update(dt)
            if self.right_game:
                self.right_game.update(dt)

    def draw(self, surface: pygame.Surface):
        """전체 렌더링"""
        # 1. 배경
        if self._bg_cache:
            surface.blit(self._bg_cache, (0, 0))

        # 2. 테트리스 게임
        # 실드 애니메이션 중에는 페이드아웃 효과와 함께 표시
        if self.crystal_shield.activated:
            if self.crystal_shield.animation_phase == "aura":
                # 아우라 페이즈: 테트리스 보드 정상 표시
                if self.left_game:
                    self.left_game.draw(surface)
                if self.right_game:
                    self.right_game.draw(surface)
            elif self.crystal_shield.animation_phase == "floating":
                # floating 페이즈에서 보드 페이드아웃
                fade_progress = min(1.0, self.crystal_shield.animation_timer / 1.5)  # 1.5초 동안 페이드아웃
                alpha = int(255 * (1.0 - fade_progress))

                if alpha > 0:
                    # 반투명 레이어에 테트리스 그리기
                    tetris_layer = pygame.Surface((self.screen_width, self.screen_height), pygame.SRCALPHA)
                    if self.left_game:
                        self.left_game.draw(tetris_layer)
                    if self.right_game:
                        self.right_game.draw(tetris_layer)
                    tetris_layer.set_alpha(alpha)
                    surface.blit(tetris_layer, (0, 0))
            # gathering/forming/active 단계에서는 보드 숨김
        elif not self.tetris_stopped:
            # 정상 상태: 테트리스 게임 그리기
            if self.left_game:
                self.left_game.draw(surface)
            if self.right_game:
                self.right_game.draw(surface)

        # 3. 고전 테트리스 UI 패널들
        self._draw_ui_panels(surface)

        # 4. 게임 영역 글로우
        self._draw_game_border_glow(surface)

    def _draw_ui_panels(self, surface: pygame.Surface):
        """고전 테트리스 스타일 UI 패널들 그리기"""
        # 좌측 패널들
        if self.left_game:
            # NEXT 패널
            self.left_next_panel.draw(surface)
            self.left_game.draw_next_preview(
                surface,
                self.left_next_panel.x, self.left_next_panel.y,
                self.left_next_panel.width, self.left_next_panel.height
            )

            # SCORE 패널
            self.left_score_panel.draw(surface)
            self.left_game.draw_stats_panel(
                surface,
                self.left_score_panel.x, self.left_score_panel.y,
                self.left_score_panel.width, self.left_score_panel.height, "SCORE"
            )

            # LEVEL 패널
            self.left_level_panel.draw(surface)
            self.left_game.draw_stats_panel(
                surface,
                self.left_level_panel.x, self.left_level_panel.y,
                self.left_level_panel.width, self.left_level_panel.height, "LEVEL"
            )

            # LINES 패널
            self.left_lines_panel.draw(surface)
            self.left_game.draw_stats_panel(
                surface,
                self.left_lines_panel.x, self.left_lines_panel.y,
                self.left_lines_panel.width, self.left_lines_panel.height, "LINES"
            )

        # 우측 패널들
        if self.right_game:
            # NEXT 패널
            self.right_next_panel.draw(surface)
            self.right_game.draw_next_preview(
                surface,
                self.right_next_panel.x, self.right_next_panel.y,
                self.right_next_panel.width, self.right_next_panel.height
            )

            # SCORE 패널
            self.right_score_panel.draw(surface)
            self.right_game.draw_stats_panel(
                surface,
                self.right_score_panel.x, self.right_score_panel.y,
                self.right_score_panel.width, self.right_score_panel.height, "SCORE"
            )

            # LEVEL 패널
            self.right_level_panel.draw(surface)
            self.right_game.draw_stats_panel(
                surface,
                self.right_level_panel.x, self.right_level_panel.y,
                self.right_level_panel.width, self.right_level_panel.height, "LEVEL"
            )

            # LINES 패널
            self.right_lines_panel.draw(surface)
            self.right_game.draw_stats_panel(
                surface,
                self.right_lines_panel.x, self.right_lines_panel.y,
                self.right_lines_panel.width, self.right_lines_panel.height, "LINES"
            )

    def draw_shield(self, surface: pygame.Surface):
        """크리스탈 실드 그리기 (게임 영역 위에 그려야 함)"""
        if self.crystal_shield.activated:
            self.crystal_shield.draw(surface)

    def _draw_game_border_glow(self, surface: pygame.Surface):
        """게임 영역 테두리 글로우"""
        pulse = 0.7 + 0.3 * math.sin(self.time * 1.5)
        base_alpha = int(20 * pulse)

        glow_color = (80, 120, 170)

        for i in range(3):
            alpha = max(0, base_alpha - i * 6)
            if alpha > 0:
                rect = pygame.Rect(
                    self.game_x - 10 - i,
                    self.game_y - 10 - i,
                    self.game_width + 20 + i * 2,
                    self.game_height + 20 + i * 2
                )
                pygame.draw.rect(surface, (*glow_color, alpha), rect, 1)

    def resize(self, screen_width: int, screen_height: int,
               game_width: int, game_height: int):
        """화면 크기 변경"""
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height
        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        self.block_size = max(12, min(18, self.game_x // 10))

        self._init_games()
        self._init_ui_panels()  # UI 패널 재초기화
        self._bg_cache = None
        self._create_bg_cache()

    def trigger_excitement(self, level: float = 1.5):
        """이벤트 트리거 (득점 시 등)"""
        # 블록 낙하 속도 일시적으로 증가
        if self.left_game:
            self.left_game.fall_speed = max(0.2, self.left_game.fall_speed - 0.1 * level)
        if self.right_game:
            self.right_game.fall_speed = max(0.2, self.right_game.fall_speed - 0.1 * level)

    def _collect_pillar_blocks(self) -> List[Dict]:
        """필러의 모든 블록을 수집하여 반환"""
        blocks = []
        left_count = 0
        right_count = 0

        # 좌측 필러 블록 수집
        if self.left_game:
            for y in range(self.left_game.rows):
                for x in range(self.left_game.cols):
                    if self.left_game.board[y][x] is not None:
                        px = self.left_game.offset_x + x * self.left_game.block_size
                        py = self.left_game.offset_y + y * self.left_game.block_size
                        blocks.append({
                            'x': px + self.left_game.block_size // 2,
                            'y': py + self.left_game.block_size // 2,
                            'color': self.left_game.board[y][x],
                            'size': self.left_game.block_size,
                            'side': 'left'  # 어느 쪽인지 표시
                        })
                        left_count += 1

        # 우측 필러 블록 수집
        if self.right_game:
            for y in range(self.right_game.rows):
                for x in range(self.right_game.cols):
                    if self.right_game.board[y][x] is not None:
                        px = self.right_game.offset_x + x * self.right_game.block_size
                        py = self.right_game.offset_y + y * self.right_game.block_size
                        blocks.append({
                            'x': px + self.right_game.block_size // 2,
                            'y': py + self.right_game.block_size // 2,
                            'color': self.right_game.board[y][x],
                            'size': self.right_game.block_size,
                            'side': 'right'  # 어느 쪽인지 표시
                        })
                        right_count += 1

        print(f"[CrystalShield] 블록 수집: 좌측 {left_count}개, 우측 {right_count}개, 총 {len(blocks)}개")
        return blocks

    def activate_crystal_shield(self, boss_x: float, boss_y: float):
        """크리스탈 실드 활성화 예약 - 플레이어가 4점 획득 후 호출
        다음 라운드 시작 시 실제 애니메이션이 시작됨
        """
        if self.crystal_shield.activated or self.crystal_shield.pending_activation:
            return False

        # 실드 활성화 예약 (테트리스 게임 참조 전달)
        self.crystal_shield.schedule_activation(
            self.left_game, self.right_game,
            boss_x, boss_y, self.screen_height, self.screen_width
        )

        return True

    def start_shield_animation(self, boss_x: float, boss_y: float):
        """크리스탈 실드 애니메이션 시작 - 다음 라운드 시작 시 호출
        Returns: True if animation started, False if not pending
        """
        if not self.crystal_shield.pending_activation:
            return False

        # 실제 활성화 시작
        result = self.crystal_shield.start_activation(boss_x, boss_y)

        if result:
            # 테트리스 중지 (블록은 아직 보드에 남아있음 - 애니메이션용)
            self.tetris_stopped = True
            if self.left_game:
                self.left_game.current_piece = None
            if self.right_game:
                self.right_game.current_piece = None

        return result

    def is_shield_pending(self) -> bool:
        """실드 활성화가 예약되어 있는지"""
        return self.crystal_shield.pending_activation

    def clear_tetris_boards(self):
        """테트리스 보드 클리어 (실드 애니메이션 완료 후 호출)"""
        if self.left_game:
            self.left_game.board = [[None for _ in range(self.left_game.cols)]
                                     for _ in range(self.left_game.rows)]
        if self.right_game:
            self.right_game.board = [[None for _ in range(self.right_game.cols)]
                                      for _ in range(self.right_game.rows)]

    def is_screen_frozen(self) -> bool:
        """화면 정지 상태 여부"""
        return self.crystal_shield.freeze_screen

    def check_ball_collision(self, ball_rect: pygame.Rect, is_player_ball: bool) -> Optional[CrystalShieldBlock]:
        """공과 크리스탈 실드 충돌 체크"""
        return self.crystal_shield.check_ball_collision(ball_rect, is_player_ball)

    def get_shield_block_count(self) -> int:
        """활성 실드 블록 수"""
        return self.crystal_shield.get_active_block_count()

    def is_shield_active(self) -> bool:
        """실드가 활성화되어 있는지"""
        return self.crystal_shield.activated and self.crystal_shield.animation_phase == "active"

    def reset_shield(self):
        """실드 시스템 리셋"""
        self.crystal_shield.reset()
        self.tetris_stopped = False
        self._init_games()


# 전역 인스턴스
_tetriser_bg = None


def init_tetriser_background(screen_width: int, screen_height: int,
                              game_width: int, game_height: int) -> TetriserPillarBackground:
    """테트리서 필러 배경 초기화"""
    global _tetriser_bg
    _tetriser_bg = TetriserPillarBackground(screen_width, screen_height, game_width, game_height)
    return _tetriser_bg


def get_tetriser_background() -> TetriserPillarBackground:
    """테트리서 필러 배경 인스턴스 반환"""
    return _tetriser_bg


def activate_crystal_shield(boss_x: float, boss_y: float) -> bool:
    """크리스탈 실드 활성화 (전역 함수)"""
    if _tetriser_bg:
        return _tetriser_bg.activate_crystal_shield(boss_x, boss_y)
    return False


def is_shield_screen_frozen() -> bool:
    """화면 정지 상태 확인 (전역 함수)"""
    if _tetriser_bg:
        return _tetriser_bg.is_screen_frozen()
    return False


def check_shield_ball_collision(ball_rect: pygame.Rect, is_player_ball: bool) -> Optional[CrystalShieldBlock]:
    """실드 블록 충돌 체크 (전역 함수)"""
    if _tetriser_bg:
        return _tetriser_bg.check_ball_collision(ball_rect, is_player_ball)
    return None


def get_shield_block_count() -> int:
    """실드 블록 수 반환 (전역 함수)"""
    if _tetriser_bg:
        return _tetriser_bg.get_shield_block_count()
    return 0


def is_crystal_shield_active() -> bool:
    """실드 활성 상태 확인 (전역 함수)"""
    if _tetriser_bg:
        return _tetriser_bg.is_shield_active()
    return False


def reset_crystal_shield():
    """실드 리셋 (전역 함수)"""
    if _tetriser_bg:
        _tetriser_bg.reset_shield()


def is_shield_pending() -> bool:
    """실드 활성화가 예약되어 있는지 (전역 함수)"""
    if _tetriser_bg:
        return _tetriser_bg.is_shield_pending()
    return False


def start_shield_animation(boss_x: float, boss_y: float) -> bool:
    """실드 애니메이션 시작 - 다음 라운드 시작 시 호출 (전역 함수)"""
    if _tetriser_bg:
        return _tetriser_bg.start_shield_animation(boss_x, boss_y)
    return False


def clear_tetris_boards():
    """테트리스 보드 클리어 (전역 함수)"""
    if _tetriser_bg:
        _tetriser_bg.clear_tetris_boards()
