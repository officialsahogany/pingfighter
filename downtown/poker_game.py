"""
포커 게임 모듈 - 4인 텍사스 홀덤 (프리미엄 버전)
플레이어(남) + NPC 3명(동서북) 포커 테이블
고퀄리티 카드 애니메이션 & 프리미엄 UI
"""

import pygame
import pygame.freetype
import pygame.gfxdraw
import random
import math
import os
import sys
import time

# 리소스 경로 함수
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)


# ============================================
# BGM 관리
# ============================================
class PokerBGM:
    """포커 게임 BGM 관리자 - 4곡 랜덤 재생"""
    _instance = None
    _previous_music = None  # 이전 BGM 상태 저장
    _previous_pos = 0  # 이전 BGM 재생 위치

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def __init__(self):
        self.bgm_paths = []  # 여러 BGM 경로 리스트
        self.current_bgm_index = -1  # 현재 재생 중인 BGM 인덱스
        self.is_playing = False
        self.volume = 0.5
        self._init_bgm_paths()

    def _init_bgm_paths(self):
        """BGM 경로 초기화 (4곡)"""
        bgm_files = ["pokerbgm.wav", "pokerbgm2.wav", "pokerbgm3.wav", "pokerbgm4.wav"]

        try:
            current_dir = os.path.dirname(os.path.abspath(__file__))
            parent_dir = os.path.dirname(current_dir)

            for bgm_file in bgm_files:
                bgm_path = os.path.join(parent_dir, "bgm", bgm_file)

                if os.path.exists(bgm_path):
                    self.bgm_paths.append(bgm_path)
                else:
                    # PyInstaller 환경
                    pyinstaller_path = resource_path(os.path.join("..", "bgm", bgm_file))
                    if os.path.exists(pyinstaller_path):
                        self.bgm_paths.append(pyinstaller_path)

            print(f"[PokerBGM] 로드된 BGM: {len(self.bgm_paths)}곡")
        except Exception as e:
            print(f"[PokerBGM] BGM 경로 초기화 실패: {e}")

    def _play_random_bgm(self):
        """랜덤 BGM 재생 (이전 곡 제외)"""
        if not self.bgm_paths:
            return False

        try:
            # 이전에 재생한 곡 제외하고 랜덤 선택
            available_indices = [i for i in range(len(self.bgm_paths)) if i != self.current_bgm_index]
            if not available_indices:
                available_indices = list(range(len(self.bgm_paths)))

            self.current_bgm_index = random.choice(available_indices)
            bgm_path = self.bgm_paths[self.current_bgm_index]

            pygame.mixer.music.load(bgm_path)
            pygame.mixer.music.set_volume(self.volume)
            pygame.mixer.music.play(0)  # 한 번만 재생 (끝나면 ENDSOUND 이벤트)

            # 음악 종료 이벤트 설정
            pygame.mixer.music.set_endevent(pygame.USEREVENT + 100)

            print(f"[PokerBGM] BGM 재생: {os.path.basename(bgm_path)} ({self.current_bgm_index + 1}/{len(self.bgm_paths)})")
            return True
        except Exception as e:
            print(f"[PokerBGM] BGM 재생 실패: {e}")
            return False

    def start(self, volume=0.5):
        """포커 BGM 시작 (이전 BGM 상태 저장)"""
        if not self.bgm_paths:
            print("[PokerBGM] BGM 파일을 찾을 수 없습니다")
            return False

        try:
            self.volume = volume

            # 현재 재생 중인 음악 상태 저장
            if pygame.mixer.music.get_busy():
                PokerBGM._previous_music = True
                try:
                    PokerBGM._previous_pos = pygame.mixer.music.get_pos()
                except:
                    PokerBGM._previous_pos = 0
            else:
                PokerBGM._previous_music = False

            # 랜덤 BGM 재생 시작
            self.is_playing = True
            return self._play_random_bgm()
        except Exception as e:
            print(f"[PokerBGM] BGM 재생 실패: {e}")
            return False

    def check_and_play_next(self):
        """현재 BGM이 끝났는지 확인하고 다음 곡 재생"""
        if self.is_playing and not pygame.mixer.music.get_busy():
            self._play_random_bgm()

    def handle_music_end_event(self, event):
        """음악 종료 이벤트 처리"""
        if event.type == pygame.USEREVENT + 100 and self.is_playing:
            self._play_random_bgm()

    def stop(self):
        """포커 BGM 정지"""
        if self.is_playing:
            try:
                pygame.mixer.music.fadeout(500)  # 0.5초 페이드아웃
                pygame.mixer.music.set_endevent()  # 이벤트 해제
                self.is_playing = False
                self.current_bgm_index = -1
                print("[PokerBGM] BGM 정지")
            except Exception as e:
                print(f"[PokerBGM] BGM 정지 실패: {e}")

    def set_volume(self, volume):
        """볼륨 설정 (0.0 ~ 1.0)"""
        try:
            self.volume = max(0.0, min(1.0, volume))
            pygame.mixer.music.set_volume(self.volume)
        except:
            pass


# ============================================
# 파티클 시스템
# ============================================
class Particle:
    """개별 파티클"""
    def __init__(self, x, y, color, vx=0, vy=0, life=1.0, size=3, gravity=0):
        self.x = x
        self.y = y
        self.color = color
        self.vx = vx
        self.vy = vy
        self.life = life
        self.max_life = life
        self.size = size
        self.gravity = gravity
        self.alpha = 255

    def update(self, dt):
        self.x += self.vx * dt
        self.y += self.vy * dt
        self.vy += self.gravity * dt
        self.life -= dt
        self.alpha = int(255 * (self.life / self.max_life))
        return self.life > 0

    def draw(self, screen):
        if self.alpha <= 0:
            return
        color = (*self.color[:3], max(0, min(255, self.alpha)))
        surf = pygame.Surface((self.size * 2, self.size * 2), pygame.SRCALPHA)
        pygame.draw.circle(surf, color, (self.size, self.size), self.size)
        screen.blit(surf, (self.x - self.size, self.y - self.size))


class ParticleSystem:
    """파티클 시스템 관리자"""
    def __init__(self):
        self.particles = []

    def emit_sparkle(self, x, y, count=10, color=(255, 215, 0)):
        """반짝이는 파티클"""
        for _ in range(count):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(50, 150)
            vx = math.cos(angle) * speed
            vy = math.sin(angle) * speed
            size = random.uniform(2, 5)
            life = random.uniform(0.5, 1.2)
            self.particles.append(Particle(x, y, color, vx, vy, life, size, gravity=100))

    def emit_win(self, x, y):
        """승리 이펙트"""
        colors = [(255, 215, 0), (255, 255, 100), (255, 200, 50), (255, 255, 200)]
        for _ in range(50):
            color = random.choice(colors)
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(100, 300)
            vx = math.cos(angle) * speed
            vy = math.sin(angle) * speed
            size = random.uniform(3, 8)
            life = random.uniform(1.0, 2.0)
            self.particles.append(Particle(x, y, color, vx, vy, life, size, gravity=200))

    def emit_card_trail(self, x, y, color=(200, 200, 255)):
        """카드 이동 트레일"""
        for _ in range(3):
            ox = random.uniform(-5, 5)
            oy = random.uniform(-5, 5)
            size = random.uniform(2, 4)
            self.particles.append(Particle(x + ox, y + oy, color, 0, 0, 0.3, size))

    def update(self, dt):
        self.particles = [p for p in self.particles if p.update(dt)]

    def draw(self, screen):
        for p in self.particles:
            p.draw(screen)


# ============================================
# 칩 스택 시스템
# ============================================
class ChipStack:
    """칩 스택 - 골드에 비례해서 쌓이는 칩 (2~4개 스택, 고퀄리티 디자인)"""
    # 칩 색상 (금액별) - 메인색, 엣지색, 패턴색
    CHIP_DESIGNS = [
        {'main': (220, 220, 235), 'edge': (255, 255, 255), 'pattern': (180, 180, 200), 'value': 50},    # 흰색/은색
        {'main': (220, 60, 60), 'edge': (255, 255, 255), 'pattern': (180, 40, 40), 'value': 100},       # 빨강
        {'main': (50, 120, 220), 'edge': (255, 255, 255), 'pattern': (30, 80, 180), 'value': 500},      # 파랑
        {'main': (50, 180, 80), 'edge': (255, 255, 255), 'pattern': (30, 140, 50), 'value': 1000},      # 초록
        {'main': (255, 140, 50), 'edge': (255, 255, 255), 'pattern': (220, 100, 30), 'value': 2000},    # 주황
        {'main': (140, 50, 200), 'edge': (255, 215, 0), 'pattern': (100, 30, 160), 'value': 5000},      # 보라 (금테)
        {'main': (30, 30, 30), 'edge': (255, 215, 0), 'pattern': (60, 60, 60), 'value': 10000},         # 검정 (금테)
    ]

    def __init__(self, x, y, direction='up'):
        self.x = x
        self.y = y
        self.direction = direction
        self.gold = 0
        self.chip_radius = 14  # 칩 반지름 (+30%)
        self.chip_height = 5   # 칩 두께 (+30%)
        self.stack_spacing = 28  # 스택 간 간격 (+30%)

        # 각 스택의 높이 변화 (자연스럽게)
        self.stack_height_offsets = [0, -2, 1, -1]

    def set_gold(self, gold):
        """골드 설정"""
        self.gold = max(0, gold)

    def _calculate_stacks(self):
        """골드에 따른 스택 구성 계산 (여러 색상의 칩 분배)"""
        if self.gold <= 0:
            return []

        stacks = []
        remaining = self.gold

        # 높은 가치부터 칩 배분
        for i in range(len(self.CHIP_DESIGNS) - 1, -1, -1):
            design = self.CHIP_DESIGNS[i]
            value = design['value']
            if remaining >= value:
                chip_count = min(remaining // value, 8)  # 한 스택당 최대 8개
                if chip_count > 0:
                    stacks.append({
                        'design_idx': i,
                        'count': chip_count
                    })
                    remaining -= chip_count * value

            if len(stacks) >= 4:  # 최대 4개 스택
                break

        # 스택이 없으면 최소 1개
        if not stacks and self.gold > 0:
            stacks.append({'design_idx': 0, 'count': 1})

        return stacks

    def draw(self, screen, offset_x=0, offset_y=0):
        """여러 스택 그리기"""
        if self.gold <= 0:
            return

        stacks = self._calculate_stacks()
        if not stacks:
            return

        base_x = self.x + offset_x
        base_y = self.y + offset_y

        # 스택 개수에 따라 시작 위치 조정 (중앙 정렬)
        num_stacks = len(stacks)
        total_width = (num_stacks - 1) * self.stack_spacing
        start_x = base_x - total_width // 2

        # 각 스택 그리기 (뒤에서부터 - 깊이감)
        for stack_idx, stack_info in enumerate(stacks):
            stack_x = start_x + stack_idx * self.stack_spacing
            height_offset = self.stack_height_offsets[stack_idx % 4]
            design = self.CHIP_DESIGNS[stack_info['design_idx']]

            for chip_idx in range(stack_info['count']):
                chip_y = base_y - chip_idx * self.chip_height + height_offset
                self._draw_premium_chip(screen, stack_x, chip_y, design)

    def _draw_premium_chip(self, screen, x, y, design):
        """고퀄리티 칩 그리기 (가장자리 패턴 포함)"""
        main_color = design['main']
        edge_color = design['edge']
        pattern_color = design['pattern']
        r, g, b = main_color

        # 1. 칩 옆면 (그림자 효과)
        shadow_color = (max(0, r - 80), max(0, g - 80), max(0, b - 80))
        for i in range(3):
            pygame.draw.ellipse(screen, shadow_color,
                               (x - self.chip_radius, y + i,
                                self.chip_radius * 2, self.chip_height + 2))

        # 2. 칩 옆면 디테일 (줄무늬)
        side_light = (max(0, r - 40), max(0, g - 40), max(0, b - 40))
        pygame.draw.ellipse(screen, side_light,
                           (x - self.chip_radius, y,
                            self.chip_radius * 2, self.chip_height + 1))

        # 3. 칩 윗면 베이스
        pygame.draw.ellipse(screen, main_color,
                           (x - self.chip_radius, y - self.chip_height,
                            self.chip_radius * 2, self.chip_height * 2 + 1))

        # 4. 칩 내부 원 (2중)
        inner_radius1 = self.chip_radius - 4
        inner_radius2 = self.chip_radius - 6
        pygame.draw.ellipse(screen, pattern_color,
                           (x - inner_radius1, y - self.chip_height + 1,
                            inner_radius1 * 2, self.chip_height * 2 - 2), 1)
        pygame.draw.ellipse(screen, edge_color,
                           (x - inner_radius2, y - self.chip_height + 2,
                            inner_radius2 * 2, self.chip_height * 2 - 4), 1)

        # 6. 외곽 테두리
        pygame.draw.ellipse(screen, edge_color,
                           (x - self.chip_radius, y - self.chip_height,
                            self.chip_radius * 2, self.chip_height * 2 + 1), 1)


class ChipAnimation:
    """칩 이동 애니메이션 (고퀄리티)"""
    # 칩 디자인 (ChipStack과 동일)
    CHIP_DESIGNS = [
        {'main': (220, 220, 235), 'edge': (255, 255, 255), 'pattern': (180, 180, 200), 'value': 50},
        {'main': (220, 60, 60), 'edge': (255, 255, 255), 'pattern': (180, 40, 40), 'value': 100},
        {'main': (50, 120, 220), 'edge': (255, 255, 255), 'pattern': (30, 80, 180), 'value': 500},
        {'main': (50, 180, 80), 'edge': (255, 255, 255), 'pattern': (30, 140, 50), 'value': 1000},
        {'main': (255, 140, 50), 'edge': (255, 255, 255), 'pattern': (220, 100, 30), 'value': 2000},
        {'main': (140, 50, 200), 'edge': (255, 215, 0), 'pattern': (100, 30, 160), 'value': 5000},
    ]

    def __init__(self, start_x, start_y, end_x, end_y, gold_amount, duration=0.5):
        self.start_x = start_x
        self.start_y = start_y
        self.end_x = end_x
        self.end_y = end_y
        self.gold_amount = gold_amount
        self.duration = duration
        self.elapsed = 0
        self.done = False
        self.trail = []  # 잔상 위치들

        # 칩 구성 계산 (금액에 따라 여러 색상)
        self.chips = self._calculate_chips()

    def _calculate_chips(self):
        """금액에 따른 칩 구성"""
        chips = []
        remaining = self.gold_amount

        for i in range(len(self.CHIP_DESIGNS) - 1, -1, -1):
            design = self.CHIP_DESIGNS[i]
            value = design['value']
            if remaining >= value:
                count = min(remaining // value, 4)
                for _ in range(count):
                    chips.append(design)
                    remaining -= value
                if len(chips) >= 6:  # 최대 6개 칩
                    break

        if not chips and self.gold_amount > 0:
            chips.append(self.CHIP_DESIGNS[0])

        return chips[:6]

    def update(self, dt):
        """애니메이션 업데이트"""
        if self.done:
            return False

        self.elapsed += dt

        # 진행률 계산 (easing)
        progress = min(1.0, self.elapsed / self.duration)
        eased = 1 - (1 - progress) ** 3  # ease-out cubic

        # 현재 위치 계산
        current_x = self.start_x + (self.end_x - self.start_x) * eased
        current_y = self.start_y + (self.end_y - self.start_y) * eased

        # 잔상 추가 (매 프레임)
        self.trail.append({
            'x': current_x,
            'y': current_y,
            'alpha': 255,
            'time': 0
        })

        # 잔상 페이드아웃
        for t in self.trail:
            t['time'] += dt
            t['alpha'] = max(0, 255 - int(t['time'] * 800))

        # 오래된 잔상 제거
        self.trail = [t for t in self.trail if t['alpha'] > 0]

        if progress >= 1.0:
            self.done = True

        return not self.done

    def get_current_position(self):
        """현재 위치 반환"""
        progress = min(1.0, self.elapsed / self.duration)
        eased = 1 - (1 - progress) ** 3
        x = self.start_x + (self.end_x - self.start_x) * eased
        y = self.start_y + (self.end_y - self.start_y) * eased
        return x, y

    def draw(self, screen):
        """칩 애니메이션 그리기"""
        # 잔상 그리기
        for t in self.trail:
            alpha = t['alpha']
            if alpha <= 0:
                continue
            self._draw_flying_chips(screen, t['x'], t['y'], alpha // 3)

        # 메인 칩 그리기
        if not self.done:
            x, y = self.get_current_position()
            self._draw_flying_chips(screen, x, y, 255)

    def _draw_flying_chips(self, screen, x, y, alpha):
        """날아가는 칩들 그리기 (고퀄리티)"""
        chip_radius = 12  # +30%
        chip_height = 4   # +30%

        for i, design in enumerate(self.chips):
            chip_y = y - i * chip_height

            # 칩 서피스 생성
            surf_width = chip_radius * 2 + 8
            surf_height = chip_height * 3 + 8
            surf = pygame.Surface((surf_width, surf_height), pygame.SRCALPHA)

            main = design['main']
            edge = design['edge']
            r, g, b = main

            cx = surf_width // 2
            cy = chip_height + 4

            # 1. 옆면 그림자
            shadow = (max(0, r - 80), max(0, g - 80), max(0, b - 80), alpha)
            pygame.draw.ellipse(surf, shadow,
                               (cx - chip_radius, cy, chip_radius * 2, chip_height + 2))

            # 2. 옆면
            side = (max(0, r - 40), max(0, g - 40), max(0, b - 40), alpha)
            pygame.draw.ellipse(surf, side,
                               (cx - chip_radius, cy - 1, chip_radius * 2, chip_height + 1))

            # 3. 윗면
            top = (r, g, b, alpha)
            pygame.draw.ellipse(surf, top,
                               (cx - chip_radius, cy - chip_height, chip_radius * 2, chip_height * 2))

            # 4. 테두리
            border = (edge[0], edge[1], edge[2], alpha // 2)
            pygame.draw.ellipse(surf, border,
                               (cx - chip_radius, cy - chip_height, chip_radius * 2, chip_height * 2), 1)

            screen.blit(surf, (x - surf_width // 2, chip_y - surf_height // 2))


class ChipAnimationManager:
    """칩 애니메이션 관리자"""
    def __init__(self):
        self.animations = []

    def add_animation(self, start_x, start_y, end_x, end_y, gold_amount, duration=0.4):
        """새 애니메이션 추가"""
        anim = ChipAnimation(start_x, start_y, end_x, end_y, gold_amount, duration)
        self.animations.append(anim)

    def update(self, dt):
        """모든 애니메이션 업데이트"""
        for anim in self.animations:
            anim.update(dt)
        # 완료된 애니메이션 제거
        self.animations = [a for a in self.animations if not a.done]

    def draw(self, screen):
        """모든 애니메이션 그리기"""
        for anim in self.animations:
            anim.draw(screen)

    def has_animations(self):
        """진행 중인 애니메이션 있는지"""
        return len(self.animations) > 0


# ============================================
# 카드 애니메이션 시스템
# ============================================
class CardAnimation:
    """카드 애니메이션 - 프리미엄 버전"""
    def __init__(self, card, start_x, start_y, end_x, end_y, duration=0.5,
                 delay=0, flip_at=0.5, start_face_up=False):
        self.card = card
        self.start_x = start_x
        self.start_y = start_y
        self.end_x = end_x
        self.end_y = end_y
        self.current_x = start_x
        self.current_y = start_y
        self.duration = duration
        self.delay = delay
        self.elapsed = 0
        self.flip_at = flip_at  # 카드 뒤집는 타이밍 (0~1)
        self.start_face_up = start_face_up
        self.flipped = start_face_up
        self.completed = False
        self.scale = 0.2  # 시작 스케일 (더 작게 시작)
        self.rotation = random.uniform(-15, 15)  # 시작 회전 (덜 과격하게)
        self.target_rotation = 0
        self.shadow_alpha = 0  # 그림자 투명도
        self.arc_height = 40  # 호를 그리며 이동 (포물선 효과)

    def _ease_out_back(self, t):
        """부드러운 오버슈트 이징 (살짝 튕기는 효과)"""
        c1 = 1.70158
        c3 = c1 + 1
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)

    def _ease_out_quart(self, t):
        """부드러운 감속 이징"""
        return 1 - pow(1 - t, 4)

    def _ease_in_out_cubic(self, t):
        """부드러운 가속-감속 이징"""
        if t < 0.5:
            return 4 * t * t * t
        else:
            return 1 - pow(-2 * t + 2, 3) / 2

    def update(self, dt):
        if self.completed:
            return True

        if self.delay > 0:
            self.delay -= dt
            return False

        self.elapsed += dt
        progress = min(1.0, self.elapsed / self.duration)

        # 이징 함수 (부드러운 가속-감속)
        eased = self._ease_in_out_cubic(progress)

        # 위치용 이징 (살짝 오버슈트)
        position_eased = self._ease_out_back(progress) if progress > 0.5 else self._ease_out_quart(progress * 2) * 0.5

        # 위치 보간 (X축)
        self.current_x = self.start_x + (self.end_x - self.start_x) * position_eased

        # Y축은 포물선 효과 추가 (호를 그리며 이동)
        linear_y = self.start_y + (self.end_y - self.start_y) * position_eased
        arc_offset = -self.arc_height * math.sin(progress * math.pi)  # 포물선
        self.current_y = linear_y + arc_offset

        # 스케일 보간 (더 부드럽게)
        scale_eased = self._ease_out_quart(progress)
        self.scale = 0.2 + 0.8 * scale_eased

        # 회전 보간 (부드럽게 0으로)
        rotation_eased = self._ease_out_quart(progress)
        self.rotation = self.rotation * (1 - rotation_eased)

        # 그림자 효과 (착지할 때 강해짐)
        self.shadow_alpha = int(80 * scale_eased)

        # 카드 뒤집기
        if not self.flipped and progress >= self.flip_at:
            self.flipped = True
            self.card.face_up = not self.start_face_up or self.card.face_up

        if progress >= 1.0:
            self.completed = True
            self.current_x = self.end_x
            self.current_y = self.end_y
            self.scale = 1.0
            self.rotation = 0
            self.shadow_alpha = 80

        return self.completed


# ============================================
# 카드 클래스 (프리미엄)
# ============================================
class Card:
    """개별 카드 - 프리미엄 디자인"""
    SUITS = ['hearts', 'diamonds', 'clubs', 'spades']
    RANKS = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']

    SUIT_SYMBOLS = {
        'hearts': '♥',
        'diamonds': '♦',
        'clubs': '♣',
        'spades': '♠'
    }

    SUIT_COLORS = {
        'hearts': (220, 40, 40),
        'diamonds': (220, 40, 40),
        'clubs': (25, 25, 25),
        'spades': (25, 25, 25)
    }

    # 페이스 카드 이름
    FACE_NAMES = {
        'J': 'JACK',
        'Q': 'QUEEN',
        'K': 'KING',
        'A': 'ACE'
    }

    def __init__(self, suit, rank):
        self.suit = suit
        self.rank = rank
        self.face_up = True
        self.hover = False
        self.selected = False

    def get_value(self):
        """카드 숫자 값 (A=14, K=13, Q=12, J=11)"""
        if self.rank == 'A':
            return 14
        elif self.rank == 'K':
            return 13
        elif self.rank == 'Q':
            return 12
        elif self.rank == 'J':
            return 11
        else:
            return int(self.rank)

    def __str__(self):
        return f"{self.rank}{self.SUIT_SYMBOLS[self.suit]}"

    def __repr__(self):
        return self.__str__()


# ============================================
# 덱 클래스
# ============================================
class Deck:
    """52장 카드 덱"""
    def __init__(self):
        self.cards = []
        self.reset()

    def reset(self):
        """덱 초기화 및 셔플"""
        self.cards = []
        for suit in Card.SUITS:
            for rank in Card.RANKS:
                self.cards.append(Card(suit, rank))
        self.shuffle()

    def shuffle(self):
        """카드 섞기"""
        random.shuffle(self.cards)

    def deal(self, face_up=True):
        """카드 한 장 뽑기"""
        if self.cards:
            card = self.cards.pop()
            card.face_up = face_up
            return card
        return None


# ============================================
# 패 랭킹 평가
# ============================================
class HandEvaluator:
    """포커 패 평가"""

    HIGH_CARD = 1
    ONE_PAIR = 2
    TWO_PAIR = 3
    THREE_OF_KIND = 4
    STRAIGHT = 5
    FLUSH = 6
    FULL_HOUSE = 7
    FOUR_OF_KIND = 8
    STRAIGHT_FLUSH = 9
    ROYAL_FLUSH = 10

    HAND_NAMES = {
        1: "하이 카드",
        2: "원 페어",
        3: "투 페어",
        4: "트리플",
        5: "스트레이트",
        6: "플러시",
        7: "풀 하우스",
        8: "포카드",
        9: "스트레이트 플러시",
        10: "로얄 플러시"
    }

    @staticmethod
    def evaluate(cards):
        if len(cards) < 5:
            return (0, [], "카드 부족")

        best_hand = None
        best_rank = 0
        best_tiebreaker = []

        from itertools import combinations

        # 디버그: 모든 카드 출력
        print(f"[HAND EVAL] 전체 카드 ({len(cards)}장): {[str(c) for c in cards]}")
        print(f"[HAND EVAL] 무늬: {[c.suit for c in cards]}")

        for combo in combinations(cards, 5):
            rank, tiebreaker = HandEvaluator._evaluate_five(list(combo))
            # 디버그: 플러시 이상일 때 출력
            if rank >= 6:
                print(f"[HAND EVAL] 조합: {[str(c) for c in combo]} -> 랭크 {rank}")
            if rank > best_rank or (rank == best_rank and tiebreaker > best_tiebreaker):
                best_rank = rank
                best_tiebreaker = tiebreaker
                best_hand = combo

        print(f"[HAND EVAL] 최종 결과: 랭크 {best_rank} = {HandEvaluator.HAND_NAMES.get(best_rank, '알 수 없음')}")
        return (best_rank, best_tiebreaker, HandEvaluator.HAND_NAMES.get(best_rank, "알 수 없음"))

    @staticmethod
    def _evaluate_five(cards):
        values = sorted([c.get_value() for c in cards], reverse=True)
        suits = [c.suit for c in cards]

        is_flush = len(set(suits)) == 1
        is_straight = HandEvaluator._is_straight(values)

        value_counts = {}
        for v in values:
            value_counts[v] = value_counts.get(v, 0) + 1

        counts = sorted(value_counts.values(), reverse=True)

        if is_flush and is_straight and values == [14, 13, 12, 11, 10]:
            return (HandEvaluator.ROYAL_FLUSH, values)

        if is_flush and is_straight:
            return (HandEvaluator.STRAIGHT_FLUSH, values)

        if counts == [4, 1]:
            four_val = [v for v, c in value_counts.items() if c == 4][0]
            kicker = [v for v, c in value_counts.items() if c == 1][0]
            return (HandEvaluator.FOUR_OF_KIND, [four_val, kicker])

        if counts == [3, 2]:
            three_val = [v for v, c in value_counts.items() if c == 3][0]
            two_val = [v for v, c in value_counts.items() if c == 2][0]
            return (HandEvaluator.FULL_HOUSE, [three_val, two_val])

        if is_flush:
            return (HandEvaluator.FLUSH, values)

        if is_straight:
            return (HandEvaluator.STRAIGHT, values)

        if counts == [3, 1, 1]:
            three_val = [v for v, c in value_counts.items() if c == 3][0]
            kickers = sorted([v for v, c in value_counts.items() if c == 1], reverse=True)
            return (HandEvaluator.THREE_OF_KIND, [three_val] + kickers)

        if counts == [2, 2, 1]:
            pairs = sorted([v for v, c in value_counts.items() if c == 2], reverse=True)
            kicker = [v for v, c in value_counts.items() if c == 1][0]
            return (HandEvaluator.TWO_PAIR, pairs + [kicker])

        if counts == [2, 1, 1, 1]:
            pair_val = [v for v, c in value_counts.items() if c == 2][0]
            kickers = sorted([v for v, c in value_counts.items() if c == 1], reverse=True)
            return (HandEvaluator.ONE_PAIR, [pair_val] + kickers)

        return (HandEvaluator.HIGH_CARD, values)

    @staticmethod
    def _is_straight(values):
        sorted_vals = sorted(set(values), reverse=True)
        if len(sorted_vals) != 5:
            return False

        if sorted_vals[0] - sorted_vals[4] == 4:
            return True

        if sorted_vals == [14, 5, 4, 3, 2]:
            return True

        return False

    @staticmethod
    def get_detailed_hand_name(rank, tiebreaker, cards=None):
        """상세 족보 이름 반환 (예: A 원페어, K 스트레이트, 다이아 플러시)"""
        # 숫자를 카드 이름으로 변환
        value_names = {
            14: 'A', 13: 'K', 12: 'Q', 11: 'J', 10: '10',
            9: '9', 8: '8', 7: '7', 6: '6', 5: '5',
            4: '4', 3: '3', 2: '2'
        }
        # 무늬 이름
        suit_names = {
            'hearts': '하트', 'diamonds': '다이아',
            'clubs': '클로버', 'spades': '스페이드'
        }

        if not tiebreaker:
            return HandEvaluator.HAND_NAMES.get(rank, "알 수 없음")

        main_value = value_names.get(tiebreaker[0], str(tiebreaker[0])) if tiebreaker else ''

        if rank == HandEvaluator.ROYAL_FLUSH:
            return "로얄 플러시"
        elif rank == HandEvaluator.STRAIGHT_FLUSH:
            return f"{main_value} 스트레이트 플러시"
        elif rank == HandEvaluator.FOUR_OF_KIND:
            return f"{main_value} 포카드"
        elif rank == HandEvaluator.FULL_HOUSE:
            second_value = value_names.get(tiebreaker[1], str(tiebreaker[1])) if len(tiebreaker) > 1 else ''
            return f"{main_value}/{second_value} 풀하우스"
        elif rank == HandEvaluator.FLUSH:
            # 플러시는 무늬 표시
            if cards:
                suits = [c.suit for c in cards]
                suit_count = {}
                for s in suits:
                    suit_count[s] = suit_count.get(s, 0) + 1
                flush_suit = max(suit_count, key=suit_count.get)
                suit_name = suit_names.get(flush_suit, flush_suit)
                return f"{suit_name} 플러시"
            return f"{main_value} 플러시"
        elif rank == HandEvaluator.STRAIGHT:
            return f"{main_value} 스트레이트"
        elif rank == HandEvaluator.THREE_OF_KIND:
            return f"{main_value} 트리플"
        elif rank == HandEvaluator.TWO_PAIR:
            second_value = value_names.get(tiebreaker[1], str(tiebreaker[1])) if len(tiebreaker) > 1 else ''
            return f"{main_value}/{second_value} 투페어"
        elif rank == HandEvaluator.ONE_PAIR:
            return f"{main_value} 원페어"
        elif rank == HandEvaluator.HIGH_CARD:
            return f"{main_value} 하이카드"

        return HandEvaluator.HAND_NAMES.get(rank, "알 수 없음")


# ============================================
# 포커 플레이어 클래스 (4인용)
# ============================================
class PokerPlayer:
    """포커 플레이어 (유저 또는 NPC)"""

    # NPC 이름 목록
    NPC_NAMES = ["풍악보이", "악어장군", "멘헤라걸", "퐁크", "홍련", "테트리서", "퐁닌자", "상점주인", "은행지점장", "아카데미회장", "오락실주인", "펫샵사장", "차원여행자"]

    def __init__(self, position, gold, is_human=False, name=None):
        """
        position: 'south'(플레이어), 'west', 'north', 'east'
        gold: 보유 골드
        is_human: 인간 플레이어 여부
        name: 이름 (NPC는 랜덤 생성)
        """
        self.position = position
        self.gold = gold
        self.initial_gold = gold
        self.is_human = is_human
        self.name = name if name else (random.choice(PokerPlayer.NPC_NAMES) if not is_human else "플레이어")

        self.hand = []  # 홀 카드 2장
        self.current_bet = 0  # 현재 라운드에서 베팅한 금액
        self.total_bet = 0  # 전체 게임에서 베팅한 금액
        self.folded = False  # 폴드 여부
        self.is_all_in = False  # 올인 여부
        self.is_bankrupt = False  # 파산 여부
        self.hand_result = None  # 패 결과 (랭크, 타이브레이커, 이름)

        # AI 성향 (NPC용)
        self.aggression = random.uniform(0.3, 0.8)  # 공격성 (0~1)
        self.bluff_tendency = random.uniform(0.1, 0.4)  # 블러핑 성향

    def reset_for_round(self):
        """새 라운드를 위한 리셋"""
        self.hand = []
        self.current_bet = 0
        self.total_bet = 0
        self.folded = False
        self.is_all_in = False
        self.hand_result = None

    def can_bet(self, amount):
        """베팅 가능 여부"""
        return not self.folded and not self.is_bankrupt and self.gold >= amount

    def bet(self, amount):
        """베팅"""
        actual_amount = min(amount, self.gold)
        self.gold -= actual_amount
        self.current_bet += actual_amount
        self.total_bet += actual_amount
        if self.gold <= 0:
            self.is_all_in = True
        return actual_amount

    def fold(self):
        """폴드"""
        self.folded = True

    def win(self, amount):
        """승리 시 상금 획득"""
        self.gold += amount


# ============================================
# 포커 게임 클래스 (4인용)
# ============================================
class PokerGame:
    """4인 텍사스 홀덤 게임"""

    STATE_BETTING = 'betting'
    STATE_DEALING = 'dealing'      # 카드 딜링 애니메이션
    STATE_PREFLOP = 'preflop'
    STATE_FLOP_DEALING = 'flop_dealing'  # 플랍 딜링 애니메이션
    STATE_FLOP = 'flop'
    STATE_TURN_DEALING = 'turn_dealing'
    STATE_TURN = 'turn'
    STATE_RIVER_DEALING = 'river_dealing'
    STATE_RIVER = 'river'
    STATE_SHOWDOWN_INTRO = 'showdown_intro'  # 쇼다운 시작 연출
    STATE_SHOWDOWN_REVEAL = 'showdown_reveal'  # 플레이어별 카드 공개
    STATE_SHOWDOWN_HAND = 'showdown_hand'  # 족보 하이라이트
    STATE_SHOWDOWN = 'showdown'  # 결과 표시
    STATE_GAME_OVER = 'game_over'

    # 플레이어 위치 순서 (시계방향: 남->서->북->동)
    POSITIONS = ['south', 'west', 'north', 'east']
    POSITION_NAMES = {'south': '남', 'west': '서', 'north': '북', 'east': '동'}

    def __init__(self, player_gold=1000):
        self.deck = Deck()
        self.community_cards = []

        # 4명의 플레이어 생성
        self.players = {}

        # 플레이어 (남쪽 - 유저)
        self.players['south'] = PokerPlayer('south', player_gold, is_human=True, name="플레이어")

        # NPC 3명 (서, 북, 동) - 각각 500~1000골드 랜덤
        used_names = set()
        for pos in ['west', 'north', 'east']:
            # 중복되지 않는 이름 선택
            available_names = [n for n in PokerPlayer.NPC_NAMES if n not in used_names]
            name = random.choice(available_names)
            used_names.add(name)
            gold = random.randint(500, 1000)
            self.players[pos] = PokerPlayer(pos, gold, is_human=False, name=name)

        # 게임 상태
        self.pot = 0
        self.min_bet = 10
        self.max_bet = 100  # 최대 판돈 제한
        self.current_bet_to_call = 0  # 콜하기 위해 필요한 금액

        # 현재 턴
        self.current_player_idx = 0  # 현재 액션할 플레이어 인덱스
        self.dealer_idx = 0  # 딜러 버튼 위치
        self.round_starter_idx = 0  # 라운드 시작 플레이어

        # 베팅 라운드 관리
        self.betting_round_complete = False
        self.last_raiser_idx = -1  # 마지막으로 레이즈한 플레이어

        # 하우스 엣지 (카지노 수수료 5%)
        self.house_edge = 0.05

        # 연승 패널티 시스템
        self.player_win_streak = 0
        self.win_streak_penalty = 0.02  # 연승당 2% 추가 수수료

        # 플로팅 텍스트 트리거용 (UI에서 읽어서 애니메이션 생성)
        self.pending_floating_texts = []  # [(text, type, target), ...]

        self.state = self.STATE_BETTING
        self.winners = []  # 승자 목록 (동점일 수 있음)
        self.result_message = ""

        self.animation_timer = 0
        self.card_animations = []
        self.pending_cards = []

        # NPC 생각 시스템
        self.npc_thinking = False  # NPC가 생각 중인지
        self.npc_thinking_player = None  # 현재 생각 중인 NPC 위치
        self.npc_think_start_time = 0  # 생각 시작 시간
        self.npc_think_duration = 0  # 생각 지속 시간 (ms)
        self.npc_pending_action = None  # 결정된 액션 (action, amount)
        self.npc_action_display = None  # 표시할 액션 텍스트
        self.npc_action_display_time = 0  # 액션 표시 시작 시간
        self.npc_turn_queue = []  # 처리할 NPC 순서
        self.npcs_acted_this_round = False  # 이번 라운드에서 NPC들이 액션했는지
        self.waiting_for_player_response = False  # NPC 레이즈 후 플레이어 응답 대기 중
        self.spectator_mode = False  # 관전자 모드 (플레이어 폴드 후)

        # 쇼다운 애니메이션 시스템
        self.showdown_phase = 0  # 현재 쇼다운 단계
        self.showdown_player_idx = 0  # 현재 카드 공개 중인 플레이어 인덱스
        self.showdown_card_idx = 0  # 현재 공개 중인 카드 인덱스
        self.showdown_timer = 0  # 쇼다운 타이머
        self.showdown_reveal_order = []  # 카드 공개 순서 (폴드 안한 플레이어)
        self.showdown_current_player = None  # 현재 쇼다운 중인 플레이어
        self.showdown_hand_highlight = []  # 족보에 사용된 카드 인덱스
        self.showdown_hand_effect_timer = 0  # 족보 이펙트 타이머
        self.showdown_hand_rank = 0  # 현재 플레이어 족보 등급 (1-10)
        self.showdown_particles = []  # 파티클 이펙트

        # 편의용 프로퍼티
        self.player_gold = player_gold  # 호환성 유지

    @property
    def human_player(self):
        """유저 플레이어 반환"""
        return self.players['south']

    @property
    def dealer_bankrupt(self):
        """모든 NPC가 파산했는지 확인 (4인용)"""
        for pos, player in self.players.items():
            if pos != 'south' and not player.is_bankrupt:
                return False
        return True

    @property
    def current_action_player(self):
        """현재 액션해야 하는 플레이어 위치"""
        if self.current_player_idx < len(self.POSITIONS):
            return self.POSITIONS[self.current_player_idx]
        return None

    def get_active_players(self):
        """폴드하지 않은 활성 플레이어 목록"""
        return [p for p in self.players.values() if not p.folded and not p.is_bankrupt]

    def get_player_count(self):
        """활성 플레이어 수"""
        return len(self.get_active_players())

    def start_new_round(self):
        """새 라운드 시작"""
        self.deck.reset()
        self.community_cards = []
        self.pot = 0
        self.current_bet_to_call = 0

        # 모든 플레이어 리셋
        for player in self.players.values():
            player.reset_for_round()

        # 파산 플레이어 체크 (최소 베팅 불가)
        for player in self.players.values():
            if player.gold < self.min_bet:
                player.is_bankrupt = True

        # 활성 플레이어 수 체크
        active_count = len([p for p in self.players.values() if not p.is_bankrupt])
        if active_count < 2:
            self.state = self.STATE_GAME_OVER
            self.result_message = "게임 종료 - 참가자 부족"
            return

        self.state = self.STATE_BETTING
        self.winners = []
        self.result_message = ""
        self.card_animations = []
        self.pending_cards = []
        self.betting_round_complete = False
        self.last_raiser_idx = -1
        self.npcs_acted_this_round = False  # NPC 액션 플래그 리셋
        self.waiting_for_player_response = False  # 플레이어 응답 대기 리셋
        self.spectator_mode = False  # 관전자 모드 리셋

        # 딜러 버튼 이동 (시계방향)
        self.dealer_idx = (self.dealer_idx + 1) % 4

        # 플레이어 골드 동기화
        self.player_gold = self.human_player.gold

    def place_bet(self, amount):
        """초기 베팅 (안테)"""
        if self.state != self.STATE_BETTING:
            return False

        amount = max(self.min_bet, min(amount, self.max_bet, self.human_player.gold))

        if amount > self.human_player.gold:
            return False

        # 모든 활성 플레이어가 동일 금액 베팅
        for player in self.players.values():
            if not player.is_bankrupt:
                bet_amount = min(amount, player.gold)
                player.bet(bet_amount)
                self.pot += bet_amount

        self.current_bet_to_call = amount
        self._start_deal_animation()
        return True

    def _start_deal_animation(self):
        """4인용 딜링 애니메이션 시작"""
        self.state = self.STATE_DEALING
        self.card_animations = []

        # 덱 위치 (화면 중앙)
        deck_x = 400
        deck_y = 300

        # 각 플레이어 카드 위치 설정
        card_positions = {
            'south': [(340, 440), (410, 440)],  # 플레이어 (하단)
            'west': [(60, 250), (60, 310)],      # 서쪽 NPC (좌측, 세로 배치)
            'north': [(340, 80), (410, 80)],    # 북쪽 NPC (상단)
            'east': [(680, 250), (680, 310)],   # 동쪽 NPC (우측, 세로 배치)
        }

        # 각 플레이어에게 카드 2장씩 배분
        delay = 0
        deal_order = ['south', 'west', 'north', 'east']  # 딜링 순서

        for round_num in range(2):  # 2라운드 (각 1장씩)
            for pos in deal_order:
                player = self.players[pos]
                if player.is_bankrupt:
                    continue

                card = self.deck.deal(player.is_human)  # 유저만 앞면
                player.hand.append(card)

                card_pos = card_positions[pos][round_num]

                anim = CardAnimation(
                    card, deck_x, deck_y, card_pos[0], card_pos[1],
                    duration=0.5, delay=delay,
                    flip_at=0.7 if player.is_human else 1.1,
                    start_face_up=False
                )
                self.card_animations.append(anim)
                delay += 0.12

    def _start_community_deal(self, count):
        """커뮤니티 카드 딜링"""
        deck_x = 400
        deck_y = 300

        # 커뮤니티 카드 위치 계산 (테이블 중앙)
        base_x = 225 + len(self.community_cards) * 65
        comm_y = 280

        for i in range(count):
            card = self.deck.deal(True)
            card.face_up = False  # 시작은 뒷면

            end_x = base_x + i * 65

            anim = CardAnimation(
                card, deck_x, deck_y, end_x, comm_y,
                duration=0.5, delay=i * 0.15,
                flip_at=0.6, start_face_up=False
            )
            self.card_animations.append(anim)
            self.pending_cards.append(card)

    def proceed_to_next_stage(self):
        """다음 스테이지로 진행"""
        # 새 라운드 시작 - 베팅 상태 리셋
        self.npcs_acted_this_round = False
        for player in self.players.values():
            player.current_bet = 0  # 새 라운드에서 베팅액 리셋
        self.current_bet_to_call = 0  # 콜 금액도 리셋

        if self.state == self.STATE_PREFLOP:
            self.state = self.STATE_FLOP_DEALING
            self._start_community_deal(3)

        elif self.state == self.STATE_FLOP:
            self.state = self.STATE_TURN_DEALING
            self._start_community_deal(1)

        elif self.state == self.STATE_TURN:
            self.state = self.STATE_RIVER_DEALING
            self._start_community_deal(1)

        elif self.state == self.STATE_RIVER:
            self._showdown()

    def _npc_ai_decision(self, npc):
        """NPC AI: 패 강도와 성향에 따른 결정"""
        # 핸드 + 커뮤니티 카드로 현재 패 평가
        if self.community_cards:
            npc_cards = npc.hand + self.community_cards
            hand_result = HandEvaluator.evaluate(npc_cards)
            hand_rank = hand_result[0]
        else:
            # 프리플랍: 홀 카드만으로 평가
            hand_rank = self._evaluate_hole_cards_for_player(npc)

        # 베팅 기준으로 레이즈 범위 계산
        base_bet = self.current_bet_to_call if self.current_bet_to_call > 0 else self.min_bet
        min_raise = max(10, int(base_bet * 0.3))
        max_raise = min(int(base_bet * 1.5), npc.gold)

        # NPC 성향 적용
        aggression = npc.aggression
        bluff = npc.bluff_tendency

        # 폴드 확률 계산
        fold_chance = 0.0
        if hand_rank <= 1:  # 하이 카드
            fold_chance = 0.4 - (aggression * 0.2) + (bluff * 0.1)
        elif hand_rank <= 2:  # 원 페어
            fold_chance = 0.15 - (aggression * 0.1)

        # 레이즈 확률 계산
        raise_chance = 0.0
        if hand_rank >= 6:  # 플러시 이상
            raise_chance = 0.8 + (aggression * 0.15)
        elif hand_rank >= 4:  # 트리플 이상
            raise_chance = 0.5 + (aggression * 0.2)
        elif hand_rank >= 2:  # 페어
            raise_chance = 0.25 + (aggression * 0.15)
        else:  # 하이 카드 - 블러핑
            raise_chance = bluff * 0.4

        # 스테이지 보정
        if self.state == self.STATE_TURN:
            raise_chance *= 1.1
        elif self.state == self.STATE_RIVER:
            raise_chance *= 1.2

        # 결정
        roll = random.random()
        if roll < fold_chance:
            return ('fold', 0)
        elif roll < fold_chance + raise_chance and npc.gold >= min_raise:
            raise_amount = int(min_raise + random.random() * (max_raise - min_raise) * aggression)
            raise_amount = min(raise_amount, npc.gold)
            if raise_amount >= min_raise:
                return ('raise', raise_amount)

        return ('call', 0)

    def _evaluate_hole_cards_for_player(self, player):
        """플레이어의 홀 카드만으로 핸드 강도 평가"""
        if len(player.hand) < 2:
            return 1

        card1, card2 = player.hand
        rank1 = card1.get_value() - 2
        rank2 = card2.get_value() - 2

        # 포켓 페어
        if rank1 == rank2:
            return 3 + (rank1 / 12)

        # 높은 카드
        high_count = sum(1 for r in [rank1, rank2] if r >= 9)
        suited = card1.suit == card2.suit

        score = 1.0
        if high_count == 2:
            score = 2.5
        elif high_count == 1:
            score = 1.8

        if suited:
            score += 0.5

        if abs(rank1 - rank2) == 1:
            score += 0.3

        return min(3, score)

    def npc_action(self, npc):
        """NPC의 액션 수행"""
        if npc.folded or npc.is_bankrupt or npc.is_all_in:
            return ('skip', 0)

        action, amount = self._npc_ai_decision(npc)

        if action == 'fold':
            npc.fold()
            return ('fold', 0)

        elif action == 'raise' and amount > 0:
            # NPC 레이즈: 먼저 콜 금액 + 레이즈 금액을 베팅해야 함
            call_needed = self.current_bet_to_call - npc.current_bet
            total_bet_needed = call_needed + amount
            actual_bet = npc.bet(total_bet_needed)
            self.pot += actual_bet
            self.current_bet_to_call = npc.current_bet  # NPC의 현재 베팅이 새로운 콜 기준
            return ('raise', actual_bet)

        else:  # call
            # 콜 금액 계산 (현재 콜해야 할 금액 - 이미 베팅한 금액)
            call_needed = self.current_bet_to_call - npc.current_bet
            if call_needed > 0:
                actual_bet = npc.bet(call_needed)
                self.pot += actual_bet
            return ('call', call_needed)

    def fold(self):
        """플레이어가 폴드"""
        if self.state in [self.STATE_PREFLOP, self.STATE_FLOP, self.STATE_TURN, self.STATE_RIVER]:
            self.human_player.fold()
            self.waiting_for_player_response = False  # 응답 완료
            self.spectator_mode = True  # 관전자 모드 활성화

            # 남은 플레이어 체크
            active = self.get_active_players()
            if len(active) == 1:
                winner = active[0]
                self.winners = [{'position': winner.position, 'player': winner, 'hand_result': None}]
                winner.win(self.pot)
                self.result_message = f"{winner.name} 승리! (다른 플레이어 모두 폴드)"
                self.state = self.STATE_GAME_OVER
                self.spectator_mode = False
            else:
                # 관전자 모드: NPC들끼리 자동 진행
                self._start_spectator_npc_round()
            return True
        return False

    def call(self):
        """플레이어가 콜/체크"""
        if self.state in [self.STATE_PREFLOP, self.STATE_FLOP, self.STATE_TURN, self.STATE_RIVER]:
            player = self.human_player
            call_needed = self.current_bet_to_call - player.current_bet
            if call_needed > 0 and player.gold >= call_needed:
                actual_bet = player.bet(call_needed)
                self.pot += actual_bet

            # NPC 레이즈에 대한 응답이었으면 바로 다음 페이즈로
            if self.waiting_for_player_response:
                self.waiting_for_player_response = False
                self._finish_betting_round()
            # NPC들이 이번 라운드에서 아직 액션 안 했으면 NPC 턴으로
            elif not self.npcs_acted_this_round:
                self._continue_betting_round()
            else:
                # NPC들이 이미 액션했으면 라운드 완료 체크
                self._check_round_complete()
            return True
        return False

    def get_call_amount(self):
        """현재 콜하기 위해 필요한 금액 반환"""
        return max(0, self.current_bet_to_call - self.human_player.current_bet)

    def raise_bet(self, additional_amount):
        """플레이어가 레이즈"""
        if self.state in [self.STATE_PREFLOP, self.STATE_FLOP, self.STATE_TURN, self.STATE_RIVER]:
            player = self.human_player
            call_needed = self.current_bet_to_call - player.current_bet
            total_needed = call_needed + additional_amount

            if player.gold >= total_needed:
                actual_bet = player.bet(total_needed)
                self.pot += actual_bet
                self.current_bet_to_call = player.current_bet
                self.last_raiser_idx = 0  # 플레이어는 항상 인덱스 0

                # 플레이어가 레이즈했으므로 NPC들 다시 액션해야 함
                self.npcs_acted_this_round = False
                self._continue_betting_round()
                return True
        return False

    def _continue_betting_round(self):
        """베팅 라운드 계속 (NPC 턴 순차 처리 시작)"""
        # NPC 턴 큐 설정 (서->북->동 순서)
        self.npc_turn_queue = []
        for pos in ['west', 'north', 'east']:
            npc = self.players[pos]
            if not npc.folded and not npc.is_bankrupt and not npc.is_all_in:
                self.npc_turn_queue.append(pos)

        # 큐가 비어있으면 바로 다음 스테이지
        if not self.npc_turn_queue:
            self._finish_betting_round()
            return

        # 첫 번째 NPC 생각 시작
        self._start_npc_thinking(self.npc_turn_queue.pop(0))

    def _start_npc_thinking(self, position):
        """NPC 생각 시작"""
        import time
        self.npc_thinking = True
        self.npc_thinking_player = position
        self.npc_think_start_time = time.time() * 1000  # ms로 변환
        self.npc_think_duration = random.randint(1000, 3000)  # 1~3초
        self.npc_pending_action = None
        self.npc_action_display = None

    def update_npc_thinking(self):
        """NPC 생각 업데이트 (매 프레임 호출)"""
        import time
        current_time = time.time() * 1000

        # 생각 중일 때
        if self.npc_thinking:
            elapsed = current_time - self.npc_think_start_time

            # 생각 시간 완료
            if elapsed >= self.npc_think_duration:
                # 액션 결정
                npc = self.players[self.npc_thinking_player]
                action, amount = self.npc_action(npc)
                self.npc_pending_action = (action, amount)

                # 액션 텍스트 생성
                if action == 'fold':
                    self.npc_action_display = f"{npc.name}: 폴드!"
                elif action == 'call':
                    # call_needed가 0이면 체크, 아니면 콜
                    if amount == 0:
                        self.npc_action_display = f"{npc.name}: 체크"
                    else:
                        self.npc_action_display = f"{npc.name}: 콜 ({amount}G)"
                elif action == 'raise':
                    self.npc_action_display = f"{npc.name}: 레이즈! ({amount}G)"
                elif action == 'skip':
                    # 스킵인 경우 바로 다음 NPC로
                    self._process_next_npc()
                    return

                self.npc_action_display_time = current_time
                self.npc_thinking = False

        # 액션 표시 후 0.8초 대기
        if self.npc_action_display:
            display_elapsed = current_time - self.npc_action_display_time
            if display_elapsed >= 800:
                # 다음 NPC로 넘어가거나 베팅 라운드 종료
                self._process_next_npc()

    def _process_next_npc(self):
        """다음 NPC 처리 또는 베팅 라운드 종료"""
        self.npc_action_display = None

        # 한 명만 남았는지 체크
        active = self.get_active_players()
        if len(active) == 1:
            winner = active[0]
            self.winners = [{'position': winner.position, 'player': winner, 'hand_result': None}]
            winner.win(self.pot)
            self.result_message = f"{winner.name} 승리!"
            self.state = self.STATE_GAME_OVER
            return

        # 다음 NPC가 있으면 생각 시작
        if self.npc_turn_queue:
            self._start_npc_thinking(self.npc_turn_queue.pop(0))
        else:
            # 모든 NPC 액션 완료
            # 관전자 모드가 아닐 때만 플레이어 차례로 돌아감
            if not self.spectator_mode:
                human = self.players['south']
                if not human.folded and not human.is_all_in:
                    call_needed = self.current_bet_to_call - human.current_bet
                    if call_needed > 0:
                        # 플레이어가 콜/폴드 해야 함 (NPC 레이즈에 대한 응답)
                        self.current_player_idx = 0  # 플레이어 차례로 설정
                        self.npcs_acted_this_round = True  # NPC들은 액션 완료
                        self.waiting_for_player_response = True  # 플레이어 응답 대기
                        return

            # NPC들 액션 완료 표시
            self.npcs_acted_this_round = True
            # 관전자 모드: 다음 스테이지 후 다시 NPC 라운드 시작
            if self.spectator_mode:
                self._finish_betting_round_spectator()
            else:
                # 모두 베팅액 맞춤 - 다음 스테이지로
                self._finish_betting_round()

    def _check_round_complete(self):
        """플레이어 콜/체크 후 라운드 완료 체크"""
        # 한 명만 남았는지 체크
        active = self.get_active_players()
        if len(active) == 1:
            winner = active[0]
            self.winners = [{'position': winner.position, 'player': winner, 'hand_result': None}]
            winner.win(self.pot)
            self.result_message = f"{winner.name} 승리!"
            self.state = self.STATE_GAME_OVER
            return

        # 모든 플레이어가 현재 베팅액에 맞췄는지 확인
        all_matched = True
        for player in active:
            if player.current_bet < self.current_bet_to_call and not player.is_all_in:
                all_matched = False
                break

        if all_matched:
            # 모두 맞춤 - 다음 스테이지로
            self._finish_betting_round()

    def _finish_betting_round(self):
        """베팅 라운드 종료 후 다음 스테이지로"""
        # 한 명만 남았는지 다시 체크
        active = self.get_active_players()
        if len(active) == 1:
            winner = active[0]
            self.winners = [{'position': winner.position, 'player': winner, 'hand_result': None}]
            winner.win(self.pot)
            self.result_message = f"{winner.name} 승리!"
            self.state = self.STATE_GAME_OVER
            return

        # 다음 스테이지로 진행
        self.proceed_to_next_stage()

    def _start_spectator_npc_round(self):
        """관전자 모드: NPC들끼리 베팅 라운드 시작"""
        # 활성 NPC 큐 설정
        self.npc_turn_queue = []
        for pos in ['west', 'north', 'east']:
            npc = self.players[pos]
            if not npc.folded and not npc.is_bankrupt and not npc.is_all_in:
                self.npc_turn_queue.append(pos)

        # 활성 플레이어가 1명이면 승자 결정
        active = self.get_active_players()
        if len(active) == 1:
            winner = active[0]
            self.winners = [{'position': winner.position, 'player': winner, 'hand_result': None}]
            winner.win(self.pot)
            self.result_message = f"{winner.name} 승리!"
            self.state = self.STATE_GAME_OVER
            self.spectator_mode = False
            return

        # 큐가 비어있으면 다음 스테이지
        if not self.npc_turn_queue:
            self._finish_betting_round_spectator()
            return

        # 첫 번째 NPC 생각 시작
        self._start_npc_thinking(self.npc_turn_queue.pop(0))

    def _finish_betting_round_spectator(self):
        """관전자 모드: 베팅 라운드 종료 후 처리"""
        # 한 명만 남았는지 체크
        active = self.get_active_players()
        if len(active) == 1:
            winner = active[0]
            self.winners = [{'position': winner.position, 'player': winner, 'hand_result': None}]
            winner.win(self.pot)
            self.result_message = f"{winner.name} 승리!"
            self.state = self.STATE_GAME_OVER
            self.spectator_mode = False
            return

        # 다음 스테이지로 진행
        self.proceed_to_next_stage()

        # 쇼다운이 아니면 다시 NPC 라운드 시작
        if self.state not in [self.STATE_SHOWDOWN, self.STATE_GAME_OVER,
                              self.STATE_SHOWDOWN_INTRO, self.STATE_SHOWDOWN_REVEAL, self.STATE_SHOWDOWN_HAND]:
            # 베팅 상태 리셋 후 다음 NPC 라운드
            self.npcs_acted_this_round = False
            self._start_spectator_npc_round()

    def _showdown(self):
        """쇼다운: 애니메이션 쇼다운 시작"""
        # 활성 플레이어 패 평가 (카드는 아직 공개하지 않음)
        active = self.get_active_players()
        self.hand_results = {}

        for player in active:
            all_cards = player.hand + self.community_cards
            player.hand_result = HandEvaluator.evaluate(all_cards)
            self.hand_results[player.position] = player.hand_result

        # 카드 공개 순서 설정 (폴드하지 않은 플레이어, 딜러 왼쪽부터)
        self.showdown_reveal_order = []
        for pos in self.POSITIONS:
            player = self.players[pos]
            if not player.folded and not player.is_bankrupt:
                self.showdown_reveal_order.append(player)

        # 쇼다운 애니메이션 초기화
        self.showdown_phase = 0
        self.showdown_player_idx = 0
        self.showdown_card_idx = 0
        self.showdown_timer = 0
        self.showdown_current_player = None
        self.showdown_hand_highlight = []
        self.showdown_hand_effect_timer = 0
        self.showdown_particles = []

        # 쇼다운 인트로 시작
        self.state = self.STATE_SHOWDOWN_INTRO

    def _finish_showdown(self):
        """쇼다운 완료: 승자 결정 및 상금 분배"""
        active = self.get_active_players()

        # 최고 패 찾기
        best_rank = -1
        best_tiebreaker = []
        winner_players = []

        for player in active:
            rank, tiebreaker, name = player.hand_result
            if rank > best_rank or (rank == best_rank and tiebreaker > best_tiebreaker):
                best_rank = rank
                best_tiebreaker = tiebreaker
                winner_players = [player]
            elif rank == best_rank and tiebreaker == best_tiebreaker:
                winner_players.append(player)

        # winners를 딕셔너리 리스트로 저장 (UI에서 사용)
        self.winners = [{'position': p.position, 'player': p, 'hand_result': p.hand_result}
                        for p in winner_players]

        # 상금 분배
        if winner_players:
            # 하우스 엣지 계산
            total_fee_rate = self.house_edge
            player_won = any(p.is_human for p in winner_players)
            if player_won:
                total_fee_rate += self.player_win_streak * self.win_streak_penalty
            total_fee_rate = min(total_fee_rate, 0.20)

            fee = int(self.pot * total_fee_rate)
            prize = self.pot - fee
            share = prize // len(winner_players)

            for winner in winner_players:
                winner.win(share)

            # 결과 메시지
            if len(winner_players) == 1:
                winner = winner_players[0]
                hand_name = winner.hand_result[2]
                if winner.is_human:
                    self.player_win_streak += 1
                    net_profit = share - winner.total_bet
                    self.result_message = f"승리! {hand_name} (+{net_profit}G)"
                    if fee > 0:
                        self.pending_floating_texts.append((f"-{fee} (수수료)", 'fee', 'south'))
                    self.pending_floating_texts.append((f"+{net_profit}", 'win', 'south'))
                else:
                    self.player_win_streak = 0
                    self.result_message = f"{winner.name} 승리! {hand_name}"
            else:
                winner_names = ", ".join([w.name for w in winner_players])
                self.result_message = f"무승부! {winner_names}"
        else:
            self.result_message = "모두 폴드!"

        # 플레이어 골드 동기화
        self.player_gold = self.human_player.gold

        # 쇼다운 완료 - 관전자 모드 해제
        self.spectator_mode = False

        self.state = self.STATE_SHOWDOWN

    def _get_hand_rank_level(self, hand_rank):
        """족보 등급 반환 (1-10, 높을수록 화려한 애니메이션)"""
        # HandEvaluator rank: 0=하이카드, 1=원페어, ... 9=로얄플러시
        return hand_rank + 1

    def _get_best_five_cards(self, player):
        """플레이어의 최고 5장 카드 조합 반환"""
        all_cards = player.hand + self.community_cards
        if len(all_cards) < 5:
            return all_cards

        # 모든 5장 조합 중 최고 찾기
        from itertools import combinations
        best_combo = None
        best_result = (-1, [], "")

        for combo in combinations(all_cards, 5):
            result = HandEvaluator.evaluate(list(combo))
            if result[0] > best_result[0] or (result[0] == best_result[0] and result[1] > best_result[1]):
                best_result = result
                best_combo = list(combo)

        return best_combo if best_combo else all_cards[:5]

    def update_showdown_animation(self, dt):
        """쇼다운 애니메이션 업데이트"""
        self.showdown_timer += dt

        # 인트로 단계 (0.5초 대기)
        if self.state == self.STATE_SHOWDOWN_INTRO:
            if self.showdown_timer >= 0.5:
                self.showdown_timer = 0
                self.showdown_player_idx = 0
                if self.showdown_reveal_order:
                    self.showdown_current_player = self.showdown_reveal_order[0]
                    self.showdown_card_idx = 0
                    self.state = self.STATE_SHOWDOWN_REVEAL
                else:
                    self._finish_showdown()

        # 카드 공개 단계
        elif self.state == self.STATE_SHOWDOWN_REVEAL:
            # 0.3초마다 카드 한 장씩 공개
            if self.showdown_timer >= 0.3:
                self.showdown_timer = 0
                player = self.showdown_current_player

                if player and self.showdown_card_idx < len(player.hand):
                    # 카드 공개
                    player.hand[self.showdown_card_idx].face_up = True
                    self.showdown_card_idx += 1

                # 모든 카드 공개 완료
                if player and self.showdown_card_idx >= len(player.hand):
                    # 족보 하이라이트 단계로 전환
                    self.showdown_hand_highlight = self._get_best_five_cards(player)
                    rank = player.hand_result[0] if player.hand_result else 0
                    self.showdown_hand_rank = self._get_hand_rank_level(rank)
                    self.showdown_hand_effect_timer = 0
                    self.state = self.STATE_SHOWDOWN_HAND

        # 족보 하이라이트 단계
        elif self.state == self.STATE_SHOWDOWN_HAND:
            self.showdown_hand_effect_timer += dt

            # 족보 등급에 따른 표시 시간 (높을수록 길게)
            display_time = 1.0 + (self.showdown_hand_rank * 0.15)

            # 파티클 업데이트
            self._update_showdown_particles(dt)

            if self.showdown_hand_effect_timer >= display_time:
                # 다음 플레이어로
                self.showdown_player_idx += 1

                if self.showdown_player_idx < len(self.showdown_reveal_order):
                    # 다음 플레이어 카드 공개
                    self.showdown_current_player = self.showdown_reveal_order[self.showdown_player_idx]
                    self.showdown_card_idx = 0
                    self.showdown_timer = 0
                    self.showdown_hand_highlight = []
                    self.showdown_particles = []
                    self.state = self.STATE_SHOWDOWN_REVEAL
                else:
                    # 모든 플레이어 공개 완료 - 결과 표시
                    self._finish_showdown()

    def _update_showdown_particles(self, dt):
        """쇼다운 파티클 업데이트"""
        # 파티클 생성 (족보 등급에 따라 개수 결정)
        if self.showdown_hand_rank >= 4:  # 쓰리카드 이상
            spawn_rate = self.showdown_hand_rank * 2
            for _ in range(int(spawn_rate * dt * 60)):
                self.showdown_particles.append({
                    'x': random.randint(100, 500),
                    'y': random.randint(200, 400),
                    'vx': random.uniform(-50, 50),
                    'vy': random.uniform(-100, -50),
                    'life': 1.0,
                    'color': self._get_particle_color()
                })

        # 파티클 업데이트
        for p in self.showdown_particles[:]:
            p['x'] += p['vx'] * dt
            p['y'] += p['vy'] * dt
            p['vy'] += 100 * dt  # 중력
            p['life'] -= dt
            if p['life'] <= 0:
                self.showdown_particles.remove(p)

    def _get_particle_color(self):
        """족보 등급에 따른 파티클 색상"""
        if self.showdown_hand_rank >= 9:  # 스트레이트 플러시 이상
            return (255, 215, 0)  # 골드
        elif self.showdown_hand_rank >= 7:  # 풀하우스 이상
            return (255, 100, 100)  # 레드
        elif self.showdown_hand_rank >= 5:  # 스트레이트 이상
            return (100, 200, 255)  # 블루
        else:
            return (200, 200, 200)  # 실버

    def update(self, dt):
        """게임 상태 업데이트"""
        self.animation_timer += dt

        # 애니메이션 업데이트
        all_completed = True
        for anim in self.card_animations:
            if not anim.update(dt):
                all_completed = False

        # 딜링 애니메이션 완료 체크
        if all_completed and self.card_animations:
            self.card_animations = []

            # 펜딩 카드를 커뮤니티에 추가
            for card in self.pending_cards:
                card.face_up = True
                self.community_cards.append(card)
            self.pending_cards = []

            # 상태 전환
            if self.state == self.STATE_DEALING:
                self.state = self.STATE_PREFLOP
                # 프리플롭 시작 - NPC 액션 플래그 리셋
                self.npcs_acted_this_round = False
                # 안테는 이미 베팅된 상태이므로 current_bet 유지
            elif self.state == self.STATE_FLOP_DEALING:
                self.state = self.STATE_FLOP
            elif self.state == self.STATE_TURN_DEALING:
                self.state = self.STATE_TURN
            elif self.state == self.STATE_RIVER_DEALING:
                self.state = self.STATE_RIVER

        # 쇼다운 애니메이션 업데이트
        if self.state in [self.STATE_SHOWDOWN_INTRO, self.STATE_SHOWDOWN_REVEAL, self.STATE_SHOWDOWN_HAND]:
            self.update_showdown_animation(dt)


# ============================================
# 프리미엄 카드 렌더러
# ============================================
class PremiumCardRenderer:
    """고퀄리티 카드 렌더링"""

    def __init__(self):
        self.card_cache = {}
        self.back_cache = {}

    def draw_card(self, screen, card, x, y, width=70, height=98,
                  scale=1.0, rotation=0, face_up=None):
        """프리미엄 카드 그리기"""
        w = int(width * scale)
        h = int(height * scale)

        if w < 10 or h < 10:
            return

        # 표시할 면 결정
        show_face = card.face_up if face_up is None else face_up

        # 카드 서피스 생성
        card_surf = pygame.Surface((w, h), pygame.SRCALPHA)

        if show_face:
            self._draw_card_face(card_surf, card, w, h)
        else:
            self._draw_card_back(card_surf, w, h)

        # 회전 적용
        if rotation != 0:
            card_surf = pygame.transform.rotate(card_surf, rotation)

        # 그림자
        shadow_surf = pygame.Surface((w + 6, h + 6), pygame.SRCALPHA)
        pygame.draw.rect(shadow_surf, (0, 0, 0, 60), (4, 6, w, h), border_radius=8)
        screen.blit(shadow_surf, (x - 2, y - 1))

        # 카드 그리기
        screen.blit(card_surf, (x, y))

    def _draw_card_face(self, surf, card, w, h):
        """카드 앞면 - 클래식 솔리테어 스타일 (흰 배경, 중앙 큰 무늬 1개)"""
        # 흰색 배경
        surf.fill((255, 255, 255))

        # 둥근 모서리 테두리
        pygame.draw.rect(surf, (180, 180, 180), (0, 0, w, h), 2, border_radius=6)

        # 하트/다이아 = 빨간색, 클럽/스페이드 = 검은색
        is_red = card.suit in ['hearts', 'diamonds']
        suit_color = (200, 30, 30) if is_red else (30, 30, 30)
        symbol = Card.SUIT_SYMBOLS[card.suit]

        # === 통일된 배치 설정 (모든 문양 동일 적용) ===
        rank_size = int(w * 0.22)           # 랭크 폰트 크기
        small_suit_size = int(w * 0.16)     # 코너 작은 문양 크기

        # 공통 값
        margin_x = int(w * 0.08)            # 좌우 마진
        rank_height = int(h * 0.15)         # 랭크 텍스트 높이
        suit_offset_y = int(h * 0.20)       # 랭크 아래 문양까지의 간격

        # === 좌상단 (숫자 + 작은 문양) - 더 위로 ===
        top_margin_y = int(h * 0.01)        # 상단 마진 (미세하게 더 위로)
        rank_x = margin_x
        rank_y = top_margin_y
        self._draw_rank(surf, card.rank, rank_x, rank_y, suit_color, rank_size)

        # 작은 문양 위치 (랭크 중앙 아래에 정렬) - 미세하게 아래로
        suit_x = margin_x + (rank_size - small_suit_size) // 2
        suit_y = top_margin_y + suit_offset_y + int(h * 0.02)
        self._draw_suit_shape(surf, symbol,
                              suit_x + small_suit_size // 2,
                              suit_y + small_suit_size // 2,
                              small_suit_size, suit_color)

        # === 중앙 대형 문양 (모든 카드 동일) ===
        cx, cy = w // 2, h // 2
        large_size = int(w * 0.55)
        self._draw_suit_shape(surf, symbol, cx, cy, large_size, suit_color)

        # === 우하단 (숫자 + 작은 문양) ===
        bottom_margin_y = int(h * 0.03)     # 하단 마진
        bottom_margin_x = int(w * 0.03)     # 우측 마진 (더 오른쪽으로)

        # 10일 때 왼쪽으로 살짝 이동하여 중앙정렬
        rank_adjust_x = int(w * 0.03) if card.rank == '10' else 0

        rank_bottom_x = w - bottom_margin_x - rank_size - rank_adjust_x
        rank_bottom_y = h - bottom_margin_y - rank_height - int(h * 0.03)
        self._draw_rank(surf, card.rank, rank_bottom_x, rank_bottom_y, suit_color, rank_size, flip=True)

        # 작은 문양 위치 - 숫자 위에 (숫자와 x축 중앙정렬) - 숫자와 간격 좁힘
        bottom_suit_x = rank_bottom_x + (rank_size - small_suit_size) // 2
        bottom_suit_y = rank_bottom_y - small_suit_size - int(h * 0.01)
        self._draw_suit_shape(surf, symbol,
                              bottom_suit_x + small_suit_size // 2,
                              bottom_suit_y + small_suit_size // 2,
                              small_suit_size, suit_color)

    def _draw_rank(self, surf, rank, x, y, color, size, flip=False):
        """랭크 텍스트"""
        font_size = max(10, size)
        try:
            font = pygame.font.SysFont('Arial Black', font_size)
        except:
            font = pygame.font.Font(None, font_size + 4)

        text = font.render(rank, True, color)
        if flip:
            text = pygame.transform.rotate(text, 180)
        surf.blit(text, (x, y))

    def _draw_suit_symbol(self, surf, symbol, x, y, color, size):
        """무늬 심볼 - 도형으로 직접 그리기"""
        self._draw_suit_shape(surf, symbol, x + size // 2, y + size // 2, size, color)

    def _draw_suit_shape(self, surf, suit_symbol, cx, cy, size, color):
        """무늬를 도형으로 직접 그리기 - 실제 포커 카드 무늬 참고"""
        s = max(8, size)
        half = s / 2

        if suit_symbol == '♥':  # 하트 - 위가 둥글고 아래가 뾰족
            # 하트 크기
            w = s * 0.9   # 전체 너비
            h = s * 0.95  # 전체 높이
            r = w * 0.28  # 상단 원 반지름

            # 원 중심 위치
            circle_y = cy - h * 0.22
            circle_left_x = cx - w * 0.23
            circle_right_x = cx + w * 0.23

            # 상단 왼쪽 원
            pygame.draw.circle(surf, color, (int(circle_left_x), int(circle_y)), int(r))
            # 상단 오른쪽 원
            pygame.draw.circle(surf, color, (int(circle_right_x), int(circle_y)), int(r))
            # 하단 뾰족한 삼각형 - 원과 자연스럽게 연결
            pygame.draw.polygon(surf, color, [
                (circle_left_x - r * 0.85, circle_y + r * 0.2),   # 왼쪽
                (circle_right_x + r * 0.85, circle_y + r * 0.2), # 오른쪽
                (cx, cy + h * 0.48)                               # 하단 뾰족점
            ])

        elif suit_symbol == '♦':  # 다이아몬드 - 세로로 긴 마름모
            w = s * 0.666  # 너비 (10% 추가 증가: 0.605 * 1.1)
            h = s * 1.029  # 높이 (10% 추가 증가: 0.935 * 1.1)
            pygame.draw.polygon(surf, color, [
                (cx, cy - h * 0.5),      # 상단
                (cx + w * 0.5, cy),      # 우측
                (cx, cy + h * 0.5),      # 하단
                (cx - w * 0.5, cy)       # 좌측
            ])

        elif suit_symbol == '♣':  # 클로버 - 세 개의 둥근 잎 + 줄기
            r = s * 0.252  # 잎 반지름 (10% 감소: 0.28 * 0.9)

            # 상단 잎 (12시) - 더 위로
            pygame.draw.circle(surf, color, (int(cx), int(cy - r * 1.1)), int(r))
            # 좌하단 잎 (8시) - 더 벌어지게
            pygame.draw.circle(surf, color, (int(cx - r * 1.05), int(cy + r * 0.2)), int(r))
            # 우하단 잎 (4시) - 더 벌어지게
            pygame.draw.circle(surf, color, (int(cx + r * 1.05), int(cy + r * 0.2)), int(r))

            # 중앙 빈틈 채우기 (더 크게)
            pygame.draw.circle(surf, color, (int(cx), int(cy)), int(r * 0.9))

            # 줄기 (밑으로 갈수록 넓어지는 형태)
            stem_top_w = s * 0.10
            stem_bot_w = s * 0.20
            stem_h = s * 0.38
            stem_top = cy + r * 0.5
            pygame.draw.polygon(surf, color, [
                (cx - stem_top_w, stem_top),
                (cx + stem_top_w, stem_top),
                (cx + stem_bot_w, stem_top + stem_h),
                (cx - stem_bot_w, stem_top + stem_h)
            ])

        elif suit_symbol == '♠':  # 스페이드 - 뒤집힌 하트 + 중앙에 밑으로 넓어지는 막대
            # 하트와 동일한 크기 사용
            w = s * 0.9
            h = s * 0.95
            r = w * 0.34  # 하단 원 반지름 (더 크게 - 굴곡 강조)

            # === 1. 뒤집힌 하트 (하트를 180도 회전) ===
            # 하단 원 중심 위치 (더 아래로, 더 벌어지게)
            circle_y = cy + h * 0.18
            circle_left_x = cx - w * 0.26
            circle_right_x = cx + w * 0.26

            # 하단 왼쪽 원 (더 큰 원으로 굴곡 강조)
            pygame.draw.circle(surf, color, (int(circle_left_x), int(circle_y)), int(r))
            # 하단 오른쪽 원
            pygame.draw.circle(surf, color, (int(circle_right_x), int(circle_y)), int(r))

            # 상단 뾰족한 삼각형 (하트의 하단을 위로)
            pygame.draw.polygon(surf, color, [
                (circle_left_x - r * 0.75, circle_y - r * 0.3),   # 왼쪽
                (circle_right_x + r * 0.75, circle_y - r * 0.3),  # 오른쪽
                (cx, cy - h * 0.48)                                # 상단 뾰족점
            ])

            # === 2. 중앙 막대 (밑으로 갈수록 넓어짐) ===
            stem_top_w = s * 0.06   # 상단 너비 (좁음)
            stem_bot_w = s * 0.18   # 하단 너비 (넓음)
            stem_h = s * 0.30       # 막대 높이
            stem_top_y = circle_y + r * 0.3  # 원 아래에서 시작

            pygame.draw.polygon(surf, color, [
                (cx - stem_top_w, stem_top_y),              # 왼쪽 상단 (좁음)
                (cx + stem_top_w, stem_top_y),              # 오른쪽 상단 (좁음)
                (cx + stem_bot_w, stem_top_y + stem_h),     # 오른쪽 하단 (넓음)
                (cx - stem_bot_w, stem_top_y + stem_h)      # 왼쪽 하단 (넓음)
            ])

    def _draw_ornate_suit(self, surf, suit_symbol, cx, cy, size, color):
        """화려한 장식이 있는 에이스 무늬 (스크린샷 스타일)"""
        s = max(20, size)

        if suit_symbol == '♣':  # 클로버 - 화려한 장식
            # 기본 클로버 형태
            r = s * 0.22
            # 상단 잎
            pygame.draw.circle(surf, color, (int(cx), int(cy - r * 1.2)), int(r))
            # 좌하단 잎
            pygame.draw.circle(surf, color, (int(cx - r * 1.0), int(cy + r * 0.1)), int(r))
            # 우하단 잎
            pygame.draw.circle(surf, color, (int(cx + r * 1.0), int(cy + r * 0.1)), int(r))

            # 장식 - 좌우 스크롤 곡선
            scroll_r = s * 0.35
            # 왼쪽 스크롤
            pygame.draw.arc(surf, color, (int(cx - s * 0.7), int(cy - s * 0.1), int(scroll_r), int(scroll_r)), 0.5, 2.5, 2)
            pygame.draw.arc(surf, color, (int(cx - s * 0.75), int(cy + s * 0.15), int(scroll_r * 0.8), int(scroll_r * 0.8)), 3.5, 5.8, 2)
            # 오른쪽 스크롤
            pygame.draw.arc(surf, color, (int(cx + s * 0.35), int(cy - s * 0.1), int(scroll_r), int(scroll_r)), 0.6, 2.6, 2)
            pygame.draw.arc(surf, color, (int(cx + s * 0.4), int(cy + s * 0.15), int(scroll_r * 0.8), int(scroll_r * 0.8)), 3.7, 6.0, 2)

            # 중앙 장식 점들
            dot_r = s * 0.04
            pygame.draw.circle(surf, color, (int(cx), int(cy - r * 0.3)), int(dot_r))
            pygame.draw.circle(surf, color, (int(cx - r * 0.5), int(cy + r * 0.5)), int(dot_r))
            pygame.draw.circle(surf, color, (int(cx + r * 0.5), int(cy + r * 0.5)), int(dot_r))

            # 줄기 (화려한 버전)
            stem_w = s * 0.12
            stem_h = s * 0.45
            pygame.draw.polygon(surf, color, [
                (cx - stem_w, cy + r * 0.3),
                (cx + stem_w, cy + r * 0.3),
                (cx + stem_w * 0.3, cy + stem_h),
                (cx - stem_w * 0.3, cy + stem_h)
            ])
            # 줄기 장식
            pygame.draw.circle(surf, color, (int(cx), int(cy + stem_h * 0.7)), int(s * 0.06))

        elif suit_symbol == '♥':  # 하트 - 화려한 장식
            w_h = s * 0.9
            h_h = s * 0.95
            r = w_h * 0.28

            # 원 중심 위치
            circle_y = cy - h_h * 0.22
            circle_left_x = cx - w_h * 0.23
            circle_right_x = cx + w_h * 0.23

            # 하트 외곽선 (두꺼운 선)
            # 상단 원들
            pygame.draw.circle(surf, color, (int(circle_left_x), int(circle_y)), int(r))
            pygame.draw.circle(surf, color, (int(circle_right_x), int(circle_y)), int(r))
            # 하단 삼각형 - 원과 자연스럽게 연결
            pygame.draw.polygon(surf, color, [
                (circle_left_x - r * 0.85, circle_y + r * 0.2),
                (circle_right_x + r * 0.85, circle_y + r * 0.2),
                (cx, cy + h_h * 0.50)
            ])

            # 내부 장식 (검정으로 하트 안에 패턴)
            inner_color = (15, 15, 15)  # 배경색
            inner_scale = 0.55
            ir = r * inner_scale
            inner_circle_y = cy - h_h * 0.18
            pygame.draw.circle(surf, inner_color, (int(cx - w_h * 0.20), int(inner_circle_y)), int(ir))
            pygame.draw.circle(surf, inner_color, (int(cx + w_h * 0.20), int(inner_circle_y)), int(ir))
            pygame.draw.polygon(surf, inner_color, [
                (cx - w_h * 0.32, inner_circle_y + ir * 0.2),
                (cx + w_h * 0.32, inner_circle_y + ir * 0.2),
                (cx, cy + h_h * 0.30)
            ])

            # 스크롤 장식
            scroll_w = s * 0.25
            # 좌우 곡선 장식
            pygame.draw.arc(surf, color, (int(cx - s * 0.55), int(cy - s * 0.05), int(scroll_w), int(scroll_w * 1.2)), 0.3, 2.8, 2)
            pygame.draw.arc(surf, color, (int(cx + s * 0.30), int(cy - s * 0.05), int(scroll_w), int(scroll_w * 1.2)), 0.3, 2.8, 2)

            # 중앙 장식 점
            pygame.draw.circle(surf, color, (int(cx), int(cy - h_h * 0.05)), int(s * 0.05))

        elif suit_symbol == '♦':  # 다이아몬드 - 화려한 장식
            w_d = s * 0.495  # 10% 증가
            h_d = s * 0.77   # 10% 증가

            # 메인 다이아몬드
            pygame.draw.polygon(surf, color, [
                (cx, cy - h_d * 0.6),
                (cx + w_d * 0.6, cy),
                (cx, cy + h_d * 0.6),
                (cx - w_d * 0.6, cy)
            ])

            # 내부 장식 (검은색 다이아몬드)
            inner_color = (15, 15, 15)
            pygame.draw.polygon(surf, inner_color, [
                (cx, cy - h_d * 0.35),
                (cx + w_d * 0.35, cy),
                (cx, cy + h_d * 0.35),
                (cx - w_d * 0.35, cy)
            ])

            # 화려한 스크롤 장식 (상하좌우)
            scroll_size = s * 0.22
            # 상단 장식
            pygame.draw.arc(surf, color, (int(cx - scroll_size/2), int(cy - h_d * 0.85), int(scroll_size), int(scroll_size * 0.8)), 3.14, 6.28, 2)
            # 하단 장식
            pygame.draw.arc(surf, color, (int(cx - scroll_size/2), int(cy + h_d * 0.55), int(scroll_size), int(scroll_size * 0.8)), 0, 3.14, 2)
            # 좌측 장식
            pygame.draw.arc(surf, color, (int(cx - w_d * 0.9), int(cy - scroll_size/2), int(scroll_size * 0.8), int(scroll_size)), 4.7, 7.85, 2)
            # 우측 장식
            pygame.draw.arc(surf, color, (int(cx + w_d * 0.55), int(cy - scroll_size/2), int(scroll_size * 0.8), int(scroll_size)), 1.57, 4.7, 2)

            # 코너 장식 점들
            dot_r = s * 0.04
            pygame.draw.circle(surf, color, (int(cx), int(cy - h_d * 0.75)), int(dot_r))
            pygame.draw.circle(surf, color, (int(cx), int(cy + h_d * 0.75)), int(dot_r))
            pygame.draw.circle(surf, color, (int(cx - w_d * 0.75), int(cy)), int(dot_r))
            pygame.draw.circle(surf, color, (int(cx + w_d * 0.75), int(cy)), int(dot_r))

        elif suit_symbol == '♠':  # 스페이드 - 뒤집힌 하트 + 중앙에 밑으로 넓어지는 막대 (화려한 버전)
            # 하트와 동일한 크기 사용
            w = s * 0.9
            h = s * 0.95
            r = w * 0.34  # 하단 원 반지름 (더 크게 - 굴곡 강조)

            # === 1. 뒤집힌 하트 (하트를 180도 회전) ===
            # 하단 원 중심 위치 (더 아래로, 더 벌어지게)
            circle_y = cy + h * 0.18
            circle_left_x = cx - w * 0.26
            circle_right_x = cx + w * 0.26

            # 하단 왼쪽 원 (더 큰 원으로 굴곡 강조)
            pygame.draw.circle(surf, color, (int(circle_left_x), int(circle_y)), int(r))
            # 하단 오른쪽 원
            pygame.draw.circle(surf, color, (int(circle_right_x), int(circle_y)), int(r))

            # 상단 뾰족한 삼각형 (하트의 하단을 위로)
            pygame.draw.polygon(surf, color, [
                (circle_left_x - r * 0.75, circle_y - r * 0.3),   # 왼쪽
                (circle_right_x + r * 0.75, circle_y - r * 0.3),  # 오른쪽
                (cx, cy - h * 0.48)                                # 상단 뾰족점
            ])

            # === 2. 중앙 막대 (밑으로 갈수록 넓어짐) ===
            stem_top_w = s * 0.06   # 상단 너비 (좁음)
            stem_bot_w = s * 0.18   # 하단 너비 (넓음)
            stem_h = s * 0.30       # 막대 높이
            stem_top_y = circle_y + r * 0.3  # 원 아래에서 시작

            pygame.draw.polygon(surf, color, [
                (cx - stem_top_w, stem_top_y),              # 왼쪽 상단 (좁음)
                (cx + stem_top_w, stem_top_y),              # 오른쪽 상단 (좁음)
                (cx + stem_bot_w, stem_top_y + stem_h),     # 오른쪽 하단 (넓음)
                (cx - stem_bot_w, stem_top_y + stem_h)      # 왼쪽 하단 (넓음)
            ])

            # 장식 점들
            dot_r = s * 0.03
            pygame.draw.circle(surf, color, (int(cx), int(cy - h * 0.55)), int(dot_r))
            pygame.draw.circle(surf, color, (int(cx), int(stem_top_y + stem_h + s * 0.05)), int(dot_r))

    def _draw_face_card(self, surf, card, w, h, color):
        """페이스 카드 (J, Q, K) 디자인 - 프리미엄 블랙 스타일"""
        cx, cy = w // 2, h // 2
        symbol = Card.SUIT_SYMBOLS[card.suit]
        letter = card.rank

        # 중앙 프레임 영역
        frame_margin = int(w * 0.12)
        frame_x = frame_margin
        frame_y = int(h * 0.30)
        frame_w = w - frame_margin * 2
        frame_h = int(h * 0.40)

        # 프레임 테두리 (무늬 색상)
        pygame.draw.rect(surf, color, (frame_x, frame_y, frame_w, frame_h), 2, border_radius=4)

        # 인물 실루엣
        person_cx = cx
        person_cy = frame_y + frame_h // 2

        # 머리
        head_r = int(w * 0.09)
        pygame.draw.circle(surf, color, (person_cx, person_cy - int(frame_h * 0.20)), head_r, 2)

        # 몸통
        body_top_w = int(w * 0.12)
        body_bot_w = int(w * 0.18)
        body_h = int(frame_h * 0.35)
        body_top_y = person_cy - int(frame_h * 0.02)
        pygame.draw.polygon(surf, color, [
            (person_cx - body_top_w, body_top_y),
            (person_cx + body_top_w, body_top_y),
            (person_cx + body_bot_w, body_top_y + body_h),
            (person_cx - body_bot_w, body_top_y + body_h)
        ], 2)

        # 왕관 (K만)
        if letter == 'K':
            crown_y = person_cy - int(frame_h * 0.38)
            pygame.draw.polygon(surf, color, [
                (person_cx - int(w * 0.10), crown_y + int(h * 0.04)),
                (person_cx - int(w * 0.08), crown_y),
                (person_cx - int(w * 0.03), crown_y + int(h * 0.02)),
                (person_cx, crown_y - int(h * 0.02)),
                (person_cx + int(w * 0.03), crown_y + int(h * 0.02)),
                (person_cx + int(w * 0.08), crown_y),
                (person_cx + int(w * 0.10), crown_y + int(h * 0.04)),
            ], 2)
        # 여왕 티아라 (Q만)
        elif letter == 'Q':
            tiara_y = person_cy - int(frame_h * 0.35)
            pygame.draw.arc(surf, color,
                          (person_cx - int(w * 0.10), tiara_y, int(w * 0.20), int(h * 0.06)),
                          3.14, 0, 2)
        # 잭 모자 (J만)
        elif letter == 'J':
            hat_y = person_cy - int(frame_h * 0.35)
            pygame.draw.ellipse(surf, color,
                              (person_cx - int(w * 0.08), hat_y, int(w * 0.16), int(h * 0.04)), 2)

    def _draw_ace_card(self, surf, card, w, h, color, symbol):
        """에이스 카드 디자인 - 프리미엄 장식 스타일 (스크린샷 참조)"""
        cx, cy = w // 2, h // 2

        # 대형 중앙 심볼 (화려한 장식 버전)
        large_size = int(w * 0.55)
        self._draw_ornate_suit(surf, symbol, cx, cy, large_size, color)

    def _draw_pip_card(self, surf, card, w, h, color, symbol):
        """숫자 카드 핍 패턴 - 넓게 분산된 레이아웃"""
        cx, cy = w // 2, h // 2
        value = card.get_value()

        # 핍 크기 (무늬가 잘 보이도록 적당한 크기)
        pip_size = int(w * 0.20)

        # 핍 배치 (카드 값에 따라)
        positions = self._get_pip_positions(value, w, h)

        for px, py, flipped in positions:
            # 도형으로 직접 그리기
            self._draw_suit_shape(surf, symbol, int(px), int(py), pip_size, color)

    def _get_pip_positions(self, value, w, h):
        """핍 위치 계산 - 실제 포커 카드 레이아웃 (좌상단/우하단 숫자 영역 피함)"""
        cx, cy = w // 2, h // 2

        # 핍 영역 - 좌상단과 우하단 숫자+무늬 영역 피해서 배치
        # 상단/하단 위치 (숫자 영역 피해서)
        top = int(h * 0.32)      # 상단 줄 (숫자 아래)
        top2 = int(h * 0.42)     # 상단 두번째 줄
        mid = cy                  # 중앙
        bot2 = int(h * 0.58)     # 하단 두번째 줄
        bot = int(h * 0.68)      # 하단 줄 (숫자 위)

        # 좌우 위치 (중앙에 더 가깝게)
        left = int(w * 0.30)
        right = int(w * 0.70)

        patterns = {
            2: [(cx, int(h * 0.35), False), (cx, int(h * 0.65), True)],
            3: [(cx, int(h * 0.32), False), (cx, mid, False), (cx, int(h * 0.68), True)],
            4: [(left, top, False), (right, top, False),
                (left, bot, True), (right, bot, True)],
            5: [(left, top, False), (right, top, False),
                (cx, mid, False),
                (left, bot, True), (right, bot, True)],
            6: [(left, top, False), (right, top, False),
                (left, mid, False), (right, mid, False),
                (left, bot, True), (right, bot, True)],
            7: [(left, top, False), (right, top, False),
                (cx, int(h * 0.40), False),
                (left, mid, False), (right, mid, False),
                (left, bot, True), (right, bot, True)],
            8: [(left, top, False), (right, top, False),
                (cx, int(h * 0.40), False),
                (left, mid, False), (right, mid, False),
                (cx, int(h * 0.60), True),
                (left, bot, True), (right, bot, True)],
            9: [(left, top, False), (right, top, False),
                (left, top2, False), (right, top2, False),
                (cx, mid, False),
                (left, bot2, True), (right, bot2, True),
                (left, bot, True), (right, bot, True)],
            10: [(left, top, False), (right, top, False),
                 (cx, int(h * 0.38), False),
                 (left, top2, False), (right, top2, False),
                 (left, bot2, True), (right, bot2, True),
                 (cx, int(h * 0.62), True),
                 (left, bot, True), (right, bot, True)],
        }

        return patterns.get(value, [(cx, mid, False)])

    def _draw_card_back(self, surf, w, h):
        """카드 뒷면 (프리미엄)"""
        # 배경 그라데이션 (진한 보라~파랑)
        for i in range(h):
            ratio = i / h
            r = int(45 + ratio * 15)
            g = int(35 + ratio * 20)
            b = int(80 + ratio * 30)
            pygame.draw.line(surf, (r, g, b), (0, i), (w, i))

        # 외곽 테두리
        pygame.draw.rect(surf, (80, 70, 120), (0, 0, w, h), 2, border_radius=8)

        # 내부 프레임
        margin = 5
        pygame.draw.rect(surf, (70, 60, 100),
                        (margin, margin, w - margin*2, h - margin*2), 1, border_radius=6)

        # 중앙 장식 패턴
        cx, cy = w // 2, h // 2

        # 다이아몬드 패턴
        pattern_size = min(w, h) * 0.15
        for row in range(-1, 3):
            for col in range(-1, 3):
                dx = cx + col * pattern_size * 1.2 - pattern_size * 0.6
                dy = cy + row * pattern_size * 1.4 - pattern_size * 0.7

                if margin + 5 < dx < w - margin - 5 and margin + 5 < dy < h - margin - 5:
                    points = [
                        (dx, dy - pattern_size * 0.4),
                        (dx + pattern_size * 0.3, dy),
                        (dx, dy + pattern_size * 0.4),
                        (dx - pattern_size * 0.3, dy)
                    ]
                    pygame.draw.polygon(surf, (100, 85, 140), points)
                    pygame.draw.polygon(surf, (120, 100, 160), points, 1)

        # 중앙 원 장식
        pygame.draw.circle(surf, (90, 75, 130), (cx, cy), int(min(w, h) * 0.2), 2)
        pygame.draw.circle(surf, (110, 95, 150), (cx, cy), int(min(w, h) * 0.12))


# ============================================
# 포커 게임 UI (프리미엄)
# ============================================
class PokerGameUI:
    """포커 게임 UI - 프리미엄 버전"""

    CARD_WIDTH = 60   # 70 * 0.85 = 59.5 -> 60
    CARD_HEIGHT = 83  # 98 * 0.85 = 83.3 -> 83

    def __init__(self, screen_width, screen_height, fonts=None):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game = None
        self.fonts = fonts

        self.bet_amount = 50
        self.selected_action = -1  # 키보드 선택 (-1: 없음)
        self.raise_amount = 20
        self.hovered_action = -1  # 마우스 호버 중인 버튼 (-1: 없음)
        self.action_buttons = []  # 버튼 영역 저장용

        # 레이즈 범위 (베팅에 비례하여 동적 계산)
        self.min_raise = 10
        self.max_raise = 100
        self.raise_step = 10  # 레이즈 증감 단위

        self.animation_timer = 0
        self.show_result_timer = 0
        self.result_shown = False
        self.win_chips_triggered = False  # 승리 시 칩 애니메이션 트리거 여부
        self.last_npc_action_display = None  # 마지막 NPC 액션 표시 (칩 애니메이션 중복 방지)

        # 색상 팔레트 (프리미엄)
        self.DARK_BG = (18, 15, 25)
        self.TABLE_FELT = (25, 85, 55)
        self.TABLE_FELT_LIGHT = (35, 110, 70)
        self.TABLE_BORDER = (60, 45, 35)
        self.TABLE_BORDER_LIGHT = (100, 80, 60)
        self.GOLD = (255, 200, 50)
        self.GOLD_LIGHT = (255, 230, 120)
        self.WHITE = (255, 255, 255)
        self.SILVER = (200, 200, 210)
        self.BLACK = (15, 15, 15)
        self.RED = (200, 50, 50)
        self.BLUE = (80, 140, 220)

        # 렌더러 & 파티클
        self.card_renderer = PremiumCardRenderer()
        self.particles = ParticleSystem()

        # 칩 스택 시스템
        self.chip_stacks = {}  # 플레이어별 칩 스택 {'south': ChipStack, ...}
        self.pot_chip_stack = None  # 판돈 칩 스택
        self.chip_animation_manager = ChipAnimationManager()
        self._init_chip_stacks()

        self._font_cache = {}

        # 테이블 애니메이션용 변수
        self.table_glow_phase = 0
        self.table_sparkle_timer = 0
        self.table_sparkles = []  # 테이블 테두리 반짝임 효과
        self.table_pulse_phase = 0  # 테이블 펄스 효과

        # BGM 관리자
        self.bgm = PokerBGM.get_instance()

        # 플로팅 텍스트 애니메이션 (수수료, 획득 골드 등)
        self.floating_texts = []  # [(text, x, y, color, timer, max_timer), ...]

        # 골드 증감 효과음 로드
        self.gold_sound = None
        self._load_gold_sound()

        # 족보 스크롤 패널 관련 변수
        self.show_hand_rankings = False  # 족보 패널 표시 여부
        self.hand_rankings_scroll = 0  # 스크롤 애니메이션 진행도 (0~1)
        self.hand_rankings_target = 0  # 목표 스크롤 (0: 닫힘, 1: 열림)
        self.scroll_icon_animation = 0  # 스크롤 아이콘 애니메이션 타이머
        self.scroll_icon_rect = None  # 스크롤 아이콘 클릭 영역
        self.hand_ranking_rects = {}  # 각 족보 항목의 영역 (툴팁용)
        self.hovered_hand_rank = None  # 현재 호버 중인 족보

        # 포커 족보 순위 (높은 순서대로)
        self.HAND_RANKINGS_LIST = [
            (10, "로얄 스트레이트 플러시", (255, 215, 0)),      # 금색
            (9, "스트레이트 플러시", (255, 180, 50)),           # 밝은 금색
            (8, "포카드", (255, 100, 100)),                     # 빨간색
            (7, "풀하우스", (255, 150, 100)),                   # 주황색
            (6, "플러시", (100, 180, 255)),                     # 파란색
            (5, "스트레이트", (100, 255, 180)),                 # 민트색
            (4, "트리플", (200, 150, 255)),                     # 보라색
            (3, "투페어", (180, 180, 180)),                     # 은색
            (2, "원페어", (150, 150, 150)),                     # 회색
            (1, "하이카드", (120, 120, 120)),                   # 어두운 회색
        ]

        # 족보별 예시 카드와 설명 (툴팁용)
        # 카드 형식: (숫자, 문양) - 문양: 's'=스페이드, 'h'=하트, 'd'=다이아, 'c'=클로버
        self.HAND_RANKING_EXAMPLES = {
            10: {  # 로얄 스트레이트 플러시
                "cards": [("A", "s"), ("K", "s"), ("Q", "s"), ("J", "s"), ("10", "s")],
                "desc": "같은 문양의 A-K-Q-J-10\n가장 높은 족보!"
            },
            9: {  # 스트레이트 플러시
                "cards": [("9", "h"), ("8", "h"), ("7", "h"), ("6", "h"), ("5", "h")],
                "desc": "같은 문양의 연속된 5장\n로얄 다음으로 강력!"
            },
            8: {  # 포카드
                "cards": [("K", "s"), ("K", "h"), ("K", "d"), ("K", "c"), ("7", "s")],
                "desc": "같은 숫자 4장\n매우 희귀한 족보"
            },
            7: {  # 풀하우스
                "cards": [("Q", "s"), ("Q", "h"), ("Q", "d"), ("9", "c"), ("9", "s")],
                "desc": "트리플 + 원페어\n강력한 조합"
            },
            6: {  # 플러시
                "cards": [("A", "d"), ("J", "d"), ("8", "d"), ("6", "d"), ("3", "d")],
                "desc": "같은 문양 5장\n숫자는 상관없음"
            },
            5: {  # 스트레이트
                "cards": [("8", "s"), ("7", "h"), ("6", "d"), ("5", "c"), ("4", "s")],
                "desc": "연속된 숫자 5장\n문양은 달라도 됨"
            },
            4: {  # 트리플
                "cards": [("J", "s"), ("J", "h"), ("J", "d"), ("8", "c"), ("4", "s")],
                "desc": "같은 숫자 3장\n중상위 족보"
            },
            3: {  # 투페어
                "cards": [("10", "s"), ("10", "h"), ("7", "d"), ("7", "c"), ("A", "s")],
                "desc": "페어 2쌍\n자주 나오는 족보"
            },
            2: {  # 원페어
                "cards": [("A", "s"), ("A", "h"), ("K", "d"), ("9", "c"), ("5", "s")],
                "desc": "같은 숫자 2장\n기본적인 족보"
            },
            1: {  # 하이카드
                "cards": [("A", "s"), ("J", "h"), ("8", "d"), ("6", "c"), ("2", "s")],
                "desc": "아무 조합 없음\n가장 높은 카드로 비교"
            },
        }

    def _init_chip_stacks(self):
        """칩 스택 초기화"""
        cx = self.screen_width // 2
        cy = self.screen_height // 2

        # 플레이어별 칩 스택 위치 설정
        # south(플레이어): 정보 패널 오른쪽
        # north: 정보 패널 오른쪽
        # west: 정보 패널 오른쪽 (이름+골드 박스 오른쪽)
        # east: 정보 패널 왼쪽 (이름+골드 박스 왼쪽)
        self.chip_stack_positions = {
            'south': (150, self.screen_height - 200),  # 플레이어 정보 패널 오른쪽 (위로 40px 올림)
            'north': (cx - 50, 70),  # 북쪽 NPC 정보 패널 오른쪽
            'west': (155, cy - 140),  # 서쪽 NPC 정보 패널 오른쪽 (위로 40px 올림)
            'east': (self.screen_width - 165, cy - 140),  # 동쪽 NPC 정보 패널 왼쪽 (위로 40px 올림)
        }

        # 칩 스택 생성
        for position, (x, y) in self.chip_stack_positions.items():
            self.chip_stacks[position] = ChipStack(x, y, 'up')

        # 판돈 칩 스택 (판돈 박스 왼쪽)
        self.pot_chip_stack = ChipStack(cx - 120, cy + 80, 'up')

    def _update_chip_stacks(self):
        """플레이어 골드에 맞게 칩 스택 업데이트"""
        if not self.game:
            return

        for position, player in self.game.players.items():
            if position in self.chip_stacks:
                self.chip_stacks[position].set_gold(player.gold)

        # 판돈 칩 스택 업데이트
        if self.pot_chip_stack:
            self.pot_chip_stack.set_gold(self.game.pot)

    def _get_chip_stack_position(self, position):
        """플레이어 위치에 따른 칩 스택 중심 좌표 반환"""
        if position in self.chip_stack_positions:
            return self.chip_stack_positions[position]
        return (self.screen_width // 2, self.screen_height // 2)

    def _get_pot_chip_position(self):
        """판돈 칩 스택 위치 반환 (베팅 시 칩 이동 목적지)"""
        cx = self.screen_width // 2
        cy = self.screen_height // 2
        return (cx - 120, cy + 80)  # 판돈 칩 스택 위치 (pot_chip_stack과 동일)

    def trigger_chip_animation(self, from_position, gold_amount):
        """베팅 시 칩 이동 애니메이션 트리거"""
        if gold_amount <= 0:
            return

        start_pos = self._get_chip_stack_position(from_position)
        end_pos = self._get_pot_chip_position()  # 판돈 칩 스택 위치로 이동

        self.chip_animation_manager.add_animation(
            start_pos[0], start_pos[1],
            end_pos[0], end_pos[1],
            gold_amount,
            duration=0.4
        )

    def trigger_win_chip_animation(self, winner_position):
        """승리 시 판돈 칩이 승자에게 이동하는 애니메이션"""
        if not self.game:
            return

        pot_amount = self.game.pot
        if pot_amount <= 0:
            return

        start_pos = self._get_pot_chip_position()  # 판돈 칩 스택 위치에서 출발
        end_pos = self._get_chip_stack_position(winner_position)

        # 여러 번에 나눠서 칩 이동 (더 화려하게)
        delay_count = min(5, pot_amount // 200 + 1)
        for i in range(delay_count):
            # 약간씩 다른 시작점에서 출발 (퍼지는 효과)
            offset_x = random.randint(-15, 15)
            offset_y = random.randint(-10, 10)
            self.chip_animation_manager.add_animation(
                start_pos[0] + offset_x, start_pos[1] + offset_y,
                end_pos[0], end_pos[1],
                pot_amount // delay_count,
                duration=0.5 + i * 0.1
            )

    def _load_gold_sound(self):
        """골드 증감 효과음 로드"""
        try:
            # sounds 폴더에서 itemget.wav 로드
            current_dir = os.path.dirname(os.path.abspath(__file__))
            parent_dir = os.path.dirname(current_dir)
            sound_path = os.path.join(parent_dir, "sounds", "itemget.wav")

            if os.path.exists(sound_path):
                self.gold_sound = pygame.mixer.Sound(sound_path)
                self.gold_sound.set_volume(0.5)
            else:
                # PyInstaller 환경
                alt_path = resource_path(os.path.join("..", "sounds", "itemget.wav"))
                if os.path.exists(alt_path):
                    self.gold_sound = pygame.mixer.Sound(alt_path)
                    self.gold_sound.set_volume(0.5)
        except Exception as e:
            print(f"[PokerGameUI] 골드 효과음 로드 실패: {e}")

    def _play_gold_sound(self):
        """골드 증감 효과음 재생"""
        if self.gold_sound:
            try:
                self.gold_sound.play()
            except Exception:
                pass

    def start_game(self, player_gold):
        self.game = PokerGame(player_gold)
        self.game.start_new_round()
        self.bet_amount = min(50, player_gold)
        self.result_shown = False
        self.win_chips_triggered = False
        self.last_npc_action_display = None

        # 포커 BGM 시작
        if self.bgm:
            self.bgm.start(volume=0.4)

    def _update_raise_range(self):
        """현재 베팅에 비례하여 레이즈 범위 계산"""
        if not self.game:
            return

        base_bet = self.game.current_bet_to_call if self.game.current_bet_to_call > 0 else self.game.min_bet
        self.min_raise = max(10, int(base_bet * 0.5))  # 최소: 베팅의 50%
        self.max_raise = min(int(base_bet * 2.0), self.game.human_player.gold)  # 최대: 베팅의 200% 또는 보유 골드
        self.raise_step = max(5, int(base_bet * 0.1))  # 증감 단위: 베팅의 10%

        # 레이즈 금액이 범위를 벗어나면 조정
        if self.raise_amount < self.min_raise:
            self.raise_amount = self.min_raise
        elif self.raise_amount > self.max_raise:
            self.raise_amount = self.max_raise

    def handle_event(self, event):
        if not self.game:
            return None

        # BGM 종료 이벤트 처리 (곡이 끝나면 다음 곡 재생)
        if event.type == pygame.USEREVENT + 100:
            if self.bgm:
                self.bgm.handle_music_end_event(event)
            return None

        if event.type == pygame.KEYDOWN:
            # ESC는 언제든 나갈 수 있음
            if event.key == pygame.K_ESCAPE:
                # BGM 정지
                if self.bgm:
                    self.bgm.stop()
                return 'exit'

            # 애니메이션 중에는 다른 입력 무시 (일부 상태)
            if self.game.state in [PokerGame.STATE_DEALING, PokerGame.STATE_FLOP_DEALING,
                                   PokerGame.STATE_TURN_DEALING, PokerGame.STATE_RIVER_DEALING]:
                return None

            if self.game.state == PokerGame.STATE_BETTING:
                return self._handle_betting_input(event)
            elif self.game.state in [PokerGame.STATE_PREFLOP, PokerGame.STATE_FLOP,
                                      PokerGame.STATE_TURN, PokerGame.STATE_RIVER]:
                return self._handle_action_input(event)
            elif self.game.state in [PokerGame.STATE_SHOWDOWN, PokerGame.STATE_GAME_OVER,
                                      PokerGame.STATE_SHOWDOWN_INTRO, PokerGame.STATE_SHOWDOWN_REVEAL,
                                      PokerGame.STATE_SHOWDOWN_HAND]:
                return self._handle_result_input(event)

        # 마우스 이동 - 호버 처리
        elif event.type == pygame.MOUSEMOTION:
            return self._handle_mouse_hover(event.pos)

        # 마우스 클릭 - 버튼 클릭 처리
        elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            return self._handle_mouse_click(event.pos)

        # 마우스 휠 - 금액 조정
        elif event.type == pygame.MOUSEWHEEL:
            return self._handle_mouse_wheel(event.y)

        return None

    def _handle_mouse_wheel(self, wheel_y):
        """마우스 휠로 금액 조정"""
        # 베팅 상태일 때 - 베팅 금액 조정
        if self.game.state == PokerGame.STATE_BETTING:
            if wheel_y > 0:  # 휠 위로 - 금액 증가
                self.bet_amount = min(self.game.max_bet, self.game.players['south'].gold, self.bet_amount + 10)
            elif wheel_y < 0:  # 휠 아래로 - 금액 감소
                self.bet_amount = max(self.game.min_bet, self.bet_amount - 10)
            return None

        # 액션 상태일 때 - 레이즈 금액 조정 (베팅에 비례)
        if self.game.state in [PokerGame.STATE_PREFLOP, PokerGame.STATE_FLOP,
                                PokerGame.STATE_TURN, PokerGame.STATE_RIVER]:
            if wheel_y > 0:  # 휠 위로 - 레이즈 금액 증가
                self.raise_amount = min(self.max_raise, self.game.players['south'].gold, self.raise_amount + self.raise_step)
            elif wheel_y < 0:  # 휠 아래로 - 레이즈 금액 감소
                self.raise_amount = max(self.min_raise, self.raise_amount - self.raise_step)
            return None

        return None

    def _handle_mouse_hover(self, pos):
        """마우스 호버 처리"""
        # 족보 패널 호버 체크 (패널이 열려있을 때)
        self.hovered_hand_rank = None
        if self.show_hand_rankings and self.hand_rankings_scroll > 0.9:
            for rank, rect in self.hand_ranking_rects.items():
                if rect.collidepoint(pos):
                    self.hovered_hand_rank = rank
                    break

        # 액션 상태일 때만 버튼 호버 처리
        if self.game.state not in [PokerGame.STATE_PREFLOP, PokerGame.STATE_FLOP,
                                    PokerGame.STATE_TURN, PokerGame.STATE_RIVER]:
            self.hovered_action = -1
            return None

        # 버튼 영역 체크
        self.hovered_action = -1
        for i, btn_rect in enumerate(self.action_buttons):
            if btn_rect.collidepoint(pos):
                self.hovered_action = i
                break
        return None

    def _handle_mouse_click(self, pos):
        """마우스 클릭 처리"""
        # 족보 스크롤 아이콘 클릭 체크 (항상 가능)
        if self.handle_scroll_icon_click(pos):
            return None

        # 족보 패널이 열려있을 때 패널 외부 클릭 시 닫기
        if self.show_hand_rankings:
            # 패널 영역 계산
            panel_width = 240
            panel_height = 360
            panel_x = self.screen_width - panel_width - 5
            panel_y = self.screen_height - 80 - panel_height
            panel_rect = pygame.Rect(panel_x - 10, panel_y - 10, panel_width + 20, panel_height + 20)

            # 패널 외부 클릭 시 닫기
            if not panel_rect.collidepoint(pos):
                self.show_hand_rankings = False

        # 애니메이션 중에는 무시
        if self.game.state in [PokerGame.STATE_DEALING, PokerGame.STATE_FLOP_DEALING,
                               PokerGame.STATE_TURN_DEALING, PokerGame.STATE_RIVER_DEALING]:
            return None

        # 베팅 상태일 때 화살표 클릭 처리 및 확인 버튼
        if self.game.state == PokerGame.STATE_BETTING:
            cx = self.screen_width // 2
            y = self.screen_height - 80
            arrow_y = y + 35

            # 왼쪽 화살표 영역 (감소)
            left_arrow_rect = pygame.Rect(cx - 110, arrow_y - 15, 35, 30)
            if left_arrow_rect.collidepoint(pos):
                self.bet_amount = max(self.game.min_bet, self.bet_amount - 10)
                return None

            # 오른쪽 화살표 영역 (증가)
            right_arrow_rect = pygame.Rect(cx + 75, arrow_y - 15, 35, 30)
            if right_arrow_rect.collidepoint(pos):
                self.bet_amount = min(self.game.max_bet, self.game.players['south'].gold, self.bet_amount + 10)
                return None

            # 베팅 박스 중앙 영역 클릭 시 확인 (Space와 동일)
            # 화살표 영역을 제외한 중앙 금액 표시 영역
            bet_confirm_rect = pygame.Rect(cx - 70, y - 15, 140, 70)
            if bet_confirm_rect.collidepoint(pos):
                if self.game.place_bet(self.bet_amount):
                    # 칩 애니메이션
                    self._spawn_chip_animation(self.bet_amount)
                    # 베팅 완료 후 레이즈 범위 업데이트
                    self._update_raise_range()
                return None

        # 액션 상태일 때 버튼 클릭 처리 (관전자 모드에서는 무시)
        if self.game.state in [PokerGame.STATE_PREFLOP, PokerGame.STATE_FLOP,
                                PokerGame.STATE_TURN, PokerGame.STATE_RIVER]:
            if self.game.spectator_mode:
                return None  # 관전자 모드에서는 버튼 클릭 무시
            for i, btn_rect in enumerate(self.action_buttons):
                if btn_rect.collidepoint(pos):
                    # 마우스 클릭 시 키보드 선택 해제하고 바로 실행
                    self.selected_action = -1

                    # NPC 응답 대기 중이면 버튼 2개 (콜/폴드)
                    if self.game.waiting_for_player_response:
                        if i == 0:  # CALL
                            call_amount = self.game.get_call_amount()
                            if call_amount > self.game.players['south'].gold:
                                return None  # 골드 부족
                            if call_amount > 0:
                                self._spawn_chip_animation(call_amount)
                            self.game.call()
                            return 'action_call'
                        elif i == 1:  # FOLD
                            self.game.fold()
                            return 'action_fold'
                    else:
                        # 일반 상태: 버튼 3개 (콜/레이즈/폴드)
                        if i == 0:  # CALL/CHECK
                            call_amount = self.game.get_call_amount()
                            if call_amount > self.game.players['south'].gold:
                                return None  # 골드 부족
                            if call_amount > 0:
                                self._spawn_chip_animation(call_amount)
                            self.game.call()
                            return 'action_call'
                        elif i == 1:  # RAISE
                            if self.game.raise_bet(self.raise_amount):
                                human = self.game.players['south']
                                call_needed = self.game.current_bet_to_call - human.current_bet
                                total = self.raise_amount + max(0, call_needed)
                                self._spawn_chip_animation(total)
                                return 'action_raise'
                        elif i == 2:  # FOLD
                            self.game.fold()
                            return 'action_fold'

        # 결과/쇼다운 상태일 때 클릭으로 진행 (Space와 동일)
        # 쇼다운 애니메이션 중에는 스킵 불가
        if self.game.state in [PokerGame.STATE_SHOWDOWN, PokerGame.STATE_GAME_OVER]:
            # 딜러 파산 시 계속 불가
            if self.game.dealer_bankrupt:
                return 'exit'
            if self.game.players['south'].gold >= self.game.min_bet:
                self.game.start_new_round()
                self.bet_amount = min(50, self.game.players['south'].gold)
                self.result_shown = False
                self.win_chips_triggered = False
                self.last_npc_action_display = None
                return 'new_round'
            else:
                return 'exit'

        return None

    def _handle_betting_input(self, event):
        if event.key == pygame.K_LEFT:
            self.bet_amount = max(self.game.min_bet, self.bet_amount - 10)
        elif event.key == pygame.K_RIGHT:
            self.bet_amount = min(self.game.max_bet, self.game.players['south'].gold, self.bet_amount + 10)
        elif event.key == pygame.K_UP:
            self.bet_amount = min(self.game.max_bet, self.game.players['south'].gold, self.bet_amount + 50)
        elif event.key == pygame.K_DOWN:
            self.bet_amount = max(self.game.min_bet, self.bet_amount - 50)
        elif event.key in [pygame.K_RETURN, pygame.K_z, pygame.K_SPACE]:
            if self.game.place_bet(self.bet_amount):
                # 칩 애니메이션
                self._spawn_chip_animation(self.bet_amount)
                # 베팅 완료 후 레이즈 범위 업데이트
                self._update_raise_range()
                return 'bet_placed'
        elif event.key == pygame.K_ESCAPE:
            return 'exit'
        return None

    def _handle_action_input(self, event):
        # 관전자 모드일 때는 ESC만 처리
        if self.game.spectator_mode:
            if event.key == pygame.K_ESCAPE:
                return 'exit'
            return None

        # NPC 응답 대기 중이면 버튼 2개 (콜/폴드), 아니면 3개 (콜/레이즈/폴드)
        num_actions = 2 if self.game.waiting_for_player_response else 3

        if event.key == pygame.K_LEFT:
            # 키보드 사용 시 selected_action 활성화
            if self.selected_action == -1:
                self.selected_action = num_actions - 1  # 왼쪽 누르면 마지막에서 시작
            else:
                self.selected_action = (self.selected_action - 1) % num_actions
            self.hovered_action = -1  # 키보드 사용 시 호버 해제
        elif event.key == pygame.K_RIGHT:
            # 키보드 사용 시 selected_action 활성화
            if self.selected_action == -1:
                self.selected_action = 0  # 오른쪽 누르면 처음(CALL)에서 시작
            else:
                self.selected_action = (self.selected_action + 1) % num_actions
            self.hovered_action = -1  # 키보드 사용 시 호버 해제
        elif event.key == pygame.K_UP:
            # 레이즈 금액 증가 (NPC 응답 대기 중이면 무시)
            if not self.game.waiting_for_player_response:
                self.raise_amount = min(self.max_raise, self.game.players['south'].gold, self.raise_amount + self.raise_step)
        elif event.key == pygame.K_DOWN:
            # 레이즈 금액 감소 (NPC 응답 대기 중이면 무시)
            if not self.game.waiting_for_player_response:
                self.raise_amount = max(self.min_raise, self.raise_amount - self.raise_step)
        elif event.key in [pygame.K_RETURN, pygame.K_z, pygame.K_SPACE]:
            # 키보드로 확인 시 selected_action 사용
            if self.game.waiting_for_player_response:
                # NPC 응답 대기 중: 0=콜, 1=폴드
                if self.selected_action == 0:
                    call_amount = self.game.get_call_amount()
                    if call_amount > self.game.players['south'].gold:
                        return None  # 골드 부족
                    if call_amount > 0:
                        self._spawn_chip_animation(call_amount)
                    self.game.call()
                    return 'action_call'
                elif self.selected_action == 1:
                    self.game.fold()
                    return 'action_fold'
            else:
                # 일반 상태: 0=콜, 1=레이즈, 2=폴드
                if self.selected_action == 0:
                    call_amount = self.game.get_call_amount()
                    if call_amount > self.game.players['south'].gold:
                        return None  # 골드 부족
                    if call_amount > 0:
                        self._spawn_chip_animation(call_amount)
                    self.game.call()
                    return 'action_call'
                elif self.selected_action == 1:
                    if self.game.raise_bet(self.raise_amount):
                        self._spawn_chip_animation(self.raise_amount)
                        return 'action_raise'
                elif self.selected_action == 2:
                    self.game.fold()
                    return 'action_fold'
            # selected_action이 -1이면 아무 동작 안함 (마우스로 클릭해야 함)
        elif event.key == pygame.K_ESCAPE:
            return 'exit'
        return None

    def _handle_result_input(self, event):
        if event.key in [pygame.K_RETURN, pygame.K_z, pygame.K_SPACE]:
            # 딜러 파산 시 계속 불가
            if self.game.dealer_bankrupt:
                return 'exit'  # 파산 시 ESC와 동일하게 종료
            if self.game.players['south'].gold >= self.game.min_bet:
                self.game.start_new_round()
                self.bet_amount = min(50, self.game.players['south'].gold)
                self.result_shown = False
                self.win_chips_triggered = False
                self.last_npc_action_display = None
                return 'new_round'
            else:
                return 'exit'
        elif event.key == pygame.K_ESCAPE:
            return 'exit'
        return None

    def _spawn_chip_animation(self, amount, from_position='south'):
        """칩 애니메이션 생성 - 베팅 시 칩이 판돈으로 이동"""
        # 파티클 효과
        self.particles.emit_sparkle(
            self.screen_width // 2,
            self.screen_height - 100,
            count=15, color=self.GOLD
        )
        # 칩 이동 애니메이션 트리거
        self.trigger_chip_animation(from_position, amount)

    def update(self, dt):
        self.animation_timer += dt
        self.particles.update(dt)

        # 칩 스택 업데이트
        self._update_chip_stacks()

        # 칩 애니메이션 업데이트
        self.chip_animation_manager.update(dt)

        # 족보 패널 스크롤 애니메이션 업데이트
        self._update_hand_rankings_scroll(dt)

        # 플로팅 텍스트 업데이트
        updated_floating = []
        for ft in self.floating_texts:
            text, x, y, color, timer, max_timer, text_type, target = ft
            timer += dt
            if timer < max_timer:
                updated_floating.append((text, x, y, color, timer, max_timer, text_type, target))
        self.floating_texts = updated_floating

        if self.game:
            self.game.update(dt)

            # NPC 생각 업데이트 및 NPC 베팅 시 칩 애니메이션
            if self.game.npc_thinking or self.game.npc_action_display:
                self.game.update_npc_thinking()

                # NPC 액션이 새로 표시되면 칩 애니메이션 트리거
                if self.game.npc_action_display and self.game.npc_action_display != self.last_npc_action_display:
                    self.last_npc_action_display = self.game.npc_action_display
                    # NPC 베팅 액션 감지 (콜/레이즈만 칩 애니메이션)
                    if self.game.npc_thinking_player and self.game.npc_pending_action:
                        action, amount = self.game.npc_pending_action
                        if action in ['call', 'raise'] and amount > 0:
                            self.trigger_chip_animation(self.game.npc_thinking_player, amount)
            else:
                # NPC 액션 표시가 없을 때 추적 초기화
                if self.last_npc_action_display is not None and not self.game.npc_action_display:
                    self.last_npc_action_display = None

            # 승리 시 파티클 효과, 칩 애니메이션 및 플로팅 텍스트 생성
            if self.game.state in [PokerGame.STATE_SHOWDOWN, PokerGame.STATE_GAME_OVER] and not self.result_shown:
                self.result_shown = True
                # 4인용: 플레이어가 승자 목록에 있는지 확인
                player_won = any(w['position'] == 'south' for w in self.game.winners) if self.game.winners else False
                if player_won:
                    self.particles.emit_win(self.screen_width // 2, self.screen_height // 2)

                # 승리 시 칩 애니메이션 - 판돈이 승자에게 이동
                if not self.win_chips_triggered and self.game.winners:
                    self.win_chips_triggered = True
                    for winner_info in self.game.winners:
                        winner_pos = winner_info['position']
                        self.trigger_win_chip_animation(winner_pos)

                # 펜딩된 플로팅 텍스트 처리
                if self.game.pending_floating_texts:
                    # 플레이어(south) 골드 위치: 좌하단 플레이어 정보 패널 옆
                    player_x, player_y = 130, self.screen_height - 35
                    # 딜러/NPC 골드 위치: 해당 NPC 위치에 맞게
                    dealer_x, dealer_y = 150, 70

                    player_offset = 0
                    dealer_offset = 0
                    played_sound = False

                    for item in self.game.pending_floating_texts:
                        text, text_type, target = item

                        # 타입별 색상 결정
                        if text_type == 'fee':
                            color = (255, 150, 100)  # 주황색 (수수료)
                        elif text_type == 'win':
                            color = (100, 255, 100)  # 초록색 (획득)
                        elif text_type == 'lose':
                            color = (255, 100, 100)  # 빨간색 (손실)
                        else:
                            color = (255, 255, 255)

                        # 타겟별 위치 결정 (south = 플레이어)
                        if target == 'player' or target == 'south':
                            x = player_x
                            y = player_y - player_offset
                            player_offset += 25
                            actual_target = 'south'
                        else:  # dealer 또는 다른 NPC
                            x = dealer_x
                            y = dealer_y + dealer_offset
                            dealer_offset += 25
                            actual_target = 'dealer'

                        # 플로팅 텍스트 추가 (text, x, y, color, timer, max_timer, type, target)
                        self.floating_texts.append((text, x, y, color, 0, 2.0, text_type, actual_target))

                        # 효과음 재생 (한 번만)
                        if not played_sound:
                            self._play_gold_sound()
                            played_sound = True

                    self.game.pending_floating_texts = []

    def draw(self, screen):
        if not self.game:
            return

        # 배경
        self._draw_background(screen)

        # 테이블
        self._draw_premium_table(screen)

        # 카드
        self._draw_cards(screen)

        # UI
        self._draw_ui(screen)

        # 상태별 UI
        if self.game.state == PokerGame.STATE_BETTING:
            self._draw_betting_ui(screen)
        elif self.game.state in [PokerGame.STATE_DEALING, PokerGame.STATE_FLOP_DEALING,
                                  PokerGame.STATE_TURN_DEALING, PokerGame.STATE_RIVER_DEALING]:
            self._draw_dealing_ui(screen)
        elif self.game.state in [PokerGame.STATE_PREFLOP, PokerGame.STATE_FLOP,
                                  PokerGame.STATE_TURN, PokerGame.STATE_RIVER]:
            self._draw_action_ui(screen)
        elif self.game.state in [PokerGame.STATE_SHOWDOWN_INTRO, PokerGame.STATE_SHOWDOWN_REVEAL,
                                  PokerGame.STATE_SHOWDOWN_HAND]:
            self._draw_showdown_animation_ui(screen)
        elif self.game.state in [PokerGame.STATE_SHOWDOWN, PokerGame.STATE_GAME_OVER]:
            self._draw_result_ui(screen)

        # 칩 스택 그리기
        self._draw_chip_stacks(screen)

        # 칩 애니메이션 그리기
        self.chip_animation_manager.draw(screen)

        # 파티클
        self.particles.draw(screen)

        # 플로팅 텍스트 (수수료, 획득 골드 등)
        self._draw_floating_texts(screen)

        # 족보 스크롤 아이콘 (항상 표시)
        self._draw_scroll_icon(screen)

        # 족보 패널 (열려있을 때)
        self._draw_hand_rankings_panel(screen)

    def _draw_chip_stacks(self, screen):
        """플레이어/NPC 칩 스택 및 판돈 칩 스택 그리기"""
        if not self.game:
            return

        # 각 플레이어의 칩 스택 그리기
        for position, chip_stack in self.chip_stacks.items():
            if position in self.game.players:
                chip_stack.draw(screen)

        # 판돈 칩 스택 그리기
        if self.pot_chip_stack and self.game.pot > 0:
            self.pot_chip_stack.draw(screen)

    def _draw_floating_texts(self, screen):
        """플로팅 텍스트 렌더링 (위로/아래로 이동하며 페이드아웃)"""
        for ft in self.floating_texts:
            text, base_x, base_y, color, timer, max_timer, text_type, target = ft

            # 진행률 계산 (0.0 ~ 1.0)
            progress = timer / max_timer

            # 이동 방향: 플레이어(south)는 위로, 딜러/NPC는 아래로 (최대 60px)
            if target == 'dealer':
                y_offset = progress * 60  # 아래로 이동
            else:  # south 또는 player
                y_offset = -progress * 60  # 위로 이동
            current_y = base_y + y_offset

            # 페이드아웃 (0.5초 후부터 페이드)
            if progress > 0.5:
                alpha = int(255 * (1.0 - (progress - 0.5) * 2))
            else:
                alpha = 255

            alpha = max(0, min(255, alpha))

            if alpha <= 0:
                continue

            # 골드 아이콘 그리기 (24x24로 확대)
            icon_size = 24
            icon_x = int(base_x)
            icon_y = int(current_y)

            # 아이콘 서피스 생성 (텍스트 길이에 맞게 충분히 크게)
            icon_surf = pygame.Surface((icon_size + 250, icon_size + 10), pygame.SRCALPHA)

            # 골드 코인 아이콘 그리기
            coin_color = (255, 200, 50, alpha)
            coin_border = (200, 150, 30, alpha)
            pygame.draw.circle(icon_surf, coin_color, (icon_size // 2, icon_size // 2 + 2), icon_size // 2 - 1)
            pygame.draw.circle(icon_surf, coin_border, (icon_size // 2, icon_size // 2 + 2), icon_size // 2 - 1, 2)

            # G 텍스트 (코인 내부) - 시스템 폰트 사용
            try:
                small_font = pygame.font.SysFont('Arial', 14, bold=True)
                g_surf = small_font.render("G", True, (180, 130, 20))
                g_surf.set_alpha(alpha)
                g_rect = g_surf.get_rect()
                icon_surf.blit(g_surf, (icon_size // 2 - g_rect.width // 2, icon_size // 2 - g_rect.height // 2 + 2))
            except:
                pass

            # 숫자 텍스트 - 한글 지원 폰트 사용 (Pretendard 폰트 직접 로드)
            try:
                text_font = None
                # Pretendard 폰트 파일 직접 로드 시도
                font_paths = [
                    resource_path(os.path.join("..", "fonts", "프리텐다드", "public", "static", "Pretendard-Bold.otf")),
                    resource_path(os.path.join("fonts", "프리텐다드", "public", "static", "Pretendard-Bold.otf")),
                ]
                for font_path in font_paths:
                    if os.path.exists(font_path):
                        try:
                            text_font = pygame.font.Font(font_path, 22)
                            break
                        except:
                            continue

                # 폰트 파일 로드 실패 시 시스템 폰트 시도
                if text_font is None:
                    for font_name in ['Malgun Gothic', 'AppleGothic', 'NanumGothic', 'Arial']:
                        try:
                            text_font = pygame.font.SysFont(font_name, 22, bold=True)
                            if text_font:
                                break
                        except:
                            continue

                if text_font is None:
                    text_font = pygame.font.Font(None, 24)

                text_color = (color[0], color[1], color[2])
                text_surf = text_font.render(text, True, text_color)
                text_surf.set_alpha(alpha)
                text_rect = text_surf.get_rect()
                icon_surf.blit(text_surf, (icon_size + 6, (icon_size - text_rect.height) // 2 + 2))
            except:
                pass

            # 화면에 블릿
            screen.blit(icon_surf, (icon_x, icon_y))

    def _draw_background(self, screen):
        """프리미엄 배경"""
        # 그라데이션 배경
        for y in range(self.screen_height):
            ratio = y / self.screen_height
            r = int(18 + ratio * 8)
            g = int(15 + ratio * 10)
            b = int(25 + ratio * 15)
            pygame.draw.line(screen, (r, g, b), (0, y), (self.screen_width, y))


    def _draw_premium_table(self, screen):
        """프리미엄 포커 테이블 - 화려한 애니메이션 버전"""
        cx, cy = self.screen_width // 2, self.screen_height // 2 + 20

        # 테이블 크기
        table_w, table_h = 520, 320

        # 애니메이션 업데이트
        self.table_glow_phase += 0.03
        self.table_pulse_phase += 0.05
        self.table_sparkle_timer += 1

        # 외부 글로우 효과 (여러 레이어)
        glow_intensity = 0.5 + 0.3 * math.sin(self.table_glow_phase)
        for i in range(4, 0, -1):
            glow_surf = pygame.Surface((table_w + 80 + i * 20, table_h + 80 + i * 20), pygame.SRCALPHA)
            glow_alpha = int(25 * glow_intensity * (5 - i) / 4)
            glow_color = (50, 180, 100, glow_alpha)
            pygame.draw.ellipse(glow_surf, glow_color, (0, 0, table_w + 80 + i * 20, table_h + 80 + i * 20))
            screen.blit(glow_surf, (cx - table_w // 2 - 40 - i * 10, cy - table_h // 2 - 40 - i * 10))

        # 테이블 그림자 (깊이감)
        shadow_surf = pygame.Surface((table_w + 50, table_h + 50), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 100), (0, 0, table_w + 50, table_h + 50))
        screen.blit(shadow_surf, (cx - table_w // 2 - 25, cy - table_h // 2 - 15))

        # 테이블 외곽 프레임 (그라데이션 나무 테두리)
        frame_w, frame_h = table_w + 40, table_h + 40
        for i in range(8):
            ratio = i / 8
            r = int(80 - ratio * 30)
            g = int(60 - ratio * 25)
            b = int(45 - ratio * 20)
            pygame.draw.ellipse(screen, (r, g, b),
                               (cx - frame_w // 2 + i * 2, cy - frame_h // 2 + i * 2,
                                frame_w - i * 4, frame_h - i * 4))

        # 골드 테두리 라인 (애니메이션)
        gold_pulse = 0.7 + 0.3 * math.sin(self.table_pulse_phase * 2)
        gold_color = (int(255 * gold_pulse), int(180 * gold_pulse), int(50 * gold_pulse))
        pygame.draw.ellipse(screen, gold_color,
                           (cx - frame_w // 2, cy - frame_h // 2, frame_w, frame_h), 3)

        # 내부 골드 하이라이트
        pygame.draw.ellipse(screen, (120, 100, 70),
                           (cx - frame_w // 2 + 5, cy - frame_h // 2 + 5, frame_w - 10, frame_h - 10), 2)

        # 펠트 (고급 그라데이션)
        for i in range(12):
            ratio = i / 12
            # 중앙이 밝고 가장자리가 어두운 그라데이션
            brightness = 1.0 - ratio * 0.25
            r = int(self.TABLE_FELT[0] * brightness + 15 * (1 - ratio))
            g = int(self.TABLE_FELT[1] * brightness + 35 * (1 - ratio))
            b = int(self.TABLE_FELT[2] * brightness + 20 * (1 - ratio))
            pygame.draw.ellipse(screen, (r, g, b),
                               (cx - table_w // 2 + i * 3, cy - table_h // 2 + i * 3,
                                table_w - i * 6, table_h - i * 6))

        # 펠트 중앙 하이라이트 (조명 효과)
        highlight_surf = pygame.Surface((200, 120), pygame.SRCALPHA)
        for i in range(60):
            alpha = int(15 * (1 - i / 60))
            pygame.draw.ellipse(highlight_surf, (100, 200, 130, alpha),
                               (i, i // 2, 200 - i * 2, 120 - i))
        screen.blit(highlight_surf, (cx - 100, cy - 80))

        # 테이블 내부 장식 라인 (애니메이션 점선)
        self._draw_animated_table_border(screen, cx, cy, table_w, table_h)

        # 코너 장식
        self._draw_table_corner_decorations(screen, cx, cy, table_w, table_h)

        # 반짝임 효과 생성 및 그리기
        self._update_and_draw_table_sparkles(screen, cx, cy, table_w, table_h)

        # 중앙 로고/장식 (업그레이드)
        self._draw_table_logo(screen, cx, cy - 20)

        # POT 표시
        self._draw_pot_display(screen, cx, cy + 50)

    def _draw_animated_table_border(self, screen, cx, cy, table_w, table_h):
        """애니메이션 테이블 내부 테두리"""
        # 내부 라인 (점선 애니메이션)
        inner_w, inner_h = table_w - 60, table_h - 60
        num_segments = 48
        dash_offset = (self.table_glow_phase * 30) % 15

        for i in range(num_segments):
            angle = (i / num_segments) * 2 * math.pi
            next_angle = ((i + 1) / num_segments) * 2 * math.pi

            # 점선 효과 (교차)
            if (i + int(dash_offset / 3)) % 3 == 0:
                continue

            x1 = cx + math.cos(angle) * (inner_w // 2)
            y1 = cy + math.sin(angle) * (inner_h // 2)
            x2 = cx + math.cos(next_angle) * (inner_w // 2)
            y2 = cy + math.sin(next_angle) * (inner_h // 2)

            # 색상 그라데이션
            color_phase = (i / num_segments + self.table_glow_phase * 0.5) % 1
            r = int(50 + 30 * math.sin(color_phase * math.pi * 2))
            g = int(140 + 40 * math.sin(color_phase * math.pi * 2))
            b = int(90 + 30 * math.sin(color_phase * math.pi * 2))

            pygame.draw.line(screen, (r, g, b), (x1, y1), (x2, y2), 2)

        # 두 번째 내부 라인 (부드러운 글로우)
        glow_alpha = int(60 + 30 * math.sin(self.table_pulse_phase))
        inner_line_surf = pygame.Surface((table_w, table_h), pygame.SRCALPHA)
        pygame.draw.ellipse(inner_line_surf, (70, 180, 120, glow_alpha),
                           (30, 30, inner_w, inner_h), 2)
        screen.blit(inner_line_surf, (cx - table_w // 2, cy - table_h // 2))

    def _draw_table_corner_decorations(self, screen, cx, cy, table_w, table_h):
        """테이블 코너 장식"""
        corners = [
            (cx - table_w // 2 + 50, cy - table_h // 2 + 30),   # 좌상
            (cx + table_w // 2 - 50, cy - table_h // 2 + 30),   # 우상
            (cx - table_w // 2 + 50, cy + table_h // 2 - 30),   # 좌하
            (cx + table_w // 2 - 50, cy + table_h // 2 - 30),   # 우하
        ]

        for i, (corner_x, corner_y) in enumerate(corners):
            # 펄스 효과
            pulse = 0.7 + 0.3 * math.sin(self.table_pulse_phase + i * 0.8)

            # 외부 원
            pygame.draw.circle(screen, (60, 150, 100), (int(corner_x), int(corner_y)), 12, 2)

            # 내부 빛나는 원
            inner_color = (int(80 * pulse), int(200 * pulse), int(130 * pulse))
            pygame.draw.circle(screen, inner_color, (int(corner_x), int(corner_y)), 6)

            # 글로우 효과
            glow_surf = pygame.Surface((30, 30), pygame.SRCALPHA)
            glow_alpha = int(40 * pulse)
            pygame.draw.circle(glow_surf, (100, 220, 150, glow_alpha), (15, 15), 12)
            screen.blit(glow_surf, (corner_x - 15, corner_y - 15))

    def _update_and_draw_table_sparkles(self, screen, cx, cy, table_w, table_h):
        """테이블 테두리 반짝임 효과"""
        # 새 반짝임 생성
        if self.table_sparkle_timer % 8 == 0:
            angle = random.uniform(0, math.pi * 2)
            # 타원 경계에 반짝임 배치
            x = cx + math.cos(angle) * (table_w // 2 + 10)
            y = cy + math.sin(angle) * (table_h // 2 + 10)
            self.table_sparkles.append({
                'x': x, 'y': y,
                'life': 1.0,
                'size': random.uniform(2, 5),
                'color': random.choice([
                    (255, 215, 0),      # 골드
                    (200, 255, 200),    # 연녹색
                    (150, 255, 180),    # 민트
                    (255, 255, 200),    # 크림
                ])
            })

        # 반짝임 업데이트 및 그리기
        new_sparkles = []
        for sparkle in self.table_sparkles:
            sparkle['life'] -= 0.03
            if sparkle['life'] > 0:
                new_sparkles.append(sparkle)

                # 그리기
                alpha = int(255 * sparkle['life'])
                size = sparkle['size'] * (0.5 + sparkle['life'] * 0.5)
                color = (*sparkle['color'][:3], alpha)

                sparkle_surf = pygame.Surface((int(size * 4), int(size * 4)), pygame.SRCALPHA)

                # 별 모양 반짝임
                center = int(size * 2)
                # 중앙 원
                pygame.draw.circle(sparkle_surf, color, (center, center), int(size))
                # 십자 광선
                for angle in [0, math.pi/2, math.pi, math.pi*3/2]:
                    end_x = center + math.cos(angle) * size * 2
                    end_y = center + math.sin(angle) * size * 2
                    pygame.draw.line(sparkle_surf, color, (center, center), (end_x, end_y), max(1, int(size / 2)))

                screen.blit(sparkle_surf, (sparkle['x'] - center, sparkle['y'] - center))

        self.table_sparkles = new_sparkles[:30]  # 최대 30개 유지

    def _draw_table_logo(self, screen, x, y):
        """테이블 중앙 로고 - 업그레이드 버전"""
        # 로고 배경 글로우
        glow_pulse = 0.6 + 0.4 * math.sin(self.table_pulse_phase * 1.5)
        for i in range(4, 0, -1):
            glow_surf = pygame.Surface((90 + i * 10, 90 + i * 10), pygame.SRCALPHA)
            glow_alpha = int(20 * glow_pulse * (5 - i) / 4)
            pygame.draw.circle(glow_surf, (60, 180, 110, glow_alpha),
                              (45 + i * 5, 45 + i * 5), 40 + i * 5)
            screen.blit(glow_surf, (x - 45 - i * 5, y - 45 - i * 5))

        # 외부 장식 원 (회전 애니메이션)
        num_dots = 12
        for i in range(num_dots):
            angle = (i / num_dots) * 2 * math.pi + self.table_glow_phase
            dot_x = x + math.cos(angle) * 42
            dot_y = y + math.sin(angle) * 42
            dot_pulse = 0.5 + 0.5 * math.sin(self.table_pulse_phase + i * 0.5)
            dot_color = (int(80 + 40 * dot_pulse), int(180 + 40 * dot_pulse), int(120 + 40 * dot_pulse))
            pygame.draw.circle(screen, dot_color, (int(dot_x), int(dot_y)), 3)

        # 메인 원
        pygame.draw.circle(screen, (40, 120, 80), (x, y), 38, 3)
        pygame.draw.circle(screen, (50, 150, 95), (x, y), 32, 2)
        pygame.draw.circle(screen, (35, 100, 65), (x, y), 28)

        # 내부 하이라이트
        highlight_surf = pygame.Surface((50, 50), pygame.SRCALPHA)
        pygame.draw.ellipse(highlight_surf, (80, 180, 120, 60), (8, 5, 34, 20))
        screen.blit(highlight_surf, (x - 25, y - 30))

        # 텍스트 (글로우 효과)
        text_glow = int(140 + 40 * math.sin(self.table_glow_phase * 2))
        self._draw_text(screen, "POKER", x, y - 8, (70, text_glow, 110), 16, center=True)

        # 카드 문양 장식 (직접 그리기 - 폰트 깨짐 방지)
        symbol_colors = [(200, 200, 220), (220, 80, 80), (220, 80, 80), (200, 200, 220)]
        for i, col in enumerate(symbol_colors):
            angle = (i / 4) * 2 * math.pi - math.pi / 4 + self.table_glow_phase * 0.3
            sym_x = int(x + math.cos(angle) * 22)
            sym_y = int(y + math.sin(angle) * 22 + 5)
            self._draw_card_symbol_mini(screen, i, sym_x, sym_y, col, 6)

    def _draw_card_symbol_mini(self, screen, symbol_index, x, y, color, size):
        """미니 카드 문양 직접 그리기 (0=스페이드, 1=하트, 2=다이아, 3=클럽)"""
        if symbol_index == 0:  # 스페이드 ♠ - 뒤집힌 하트 + 중앙에 밑으로 넓어지는 막대
            s = size * 1.2

            # === 1. 뒤집힌 하트 (하트를 180도 회전: 아래가 둥글고 위가 뾰족) ===
            r = s * 0.42  # 원 반지름 (더 크게 - 굴곡 강조)
            circle_y = y + s * 0.20  # 원 중심 Y (아래쪽)
            circle_offset = s * 0.32  # 원 사이 간격 (더 벌어지게)

            # 하단 두 원 (더 큰 원으로 굴곡 강조)
            pygame.draw.circle(screen, color, (int(x - circle_offset), int(circle_y)), int(r))
            pygame.draw.circle(screen, color, (int(x + circle_offset), int(circle_y)), int(r))

            # 위로 뾰족한 삼각형 (하트의 하단을 위로)
            tri_bottom = circle_y - r * 0.2
            tri_top = y - s * 0.55  # 상단 뾰족점
            tri_half_width = s * 0.65

            pygame.draw.polygon(screen, color, [
                (x, tri_top),                      # 상단 뾰족점
                (x - tri_half_width, tri_bottom),  # 왼쪽 하단
                (x + tri_half_width, tri_bottom),  # 오른쪽 하단
            ])

            # === 2. 중앙 막대 (밑으로 갈수록 넓어짐) ===
            stem_top_w = s * 0.08   # 상단 너비 (좁음)
            stem_bot_w = s * 0.22   # 하단 너비 (넓음)
            stem_h = s * 0.42
            stem_top_y = circle_y + r * 0.35  # 원 아래에서 시작

            pygame.draw.polygon(screen, color, [
                (x - stem_top_w, stem_top_y),              # 왼쪽 상단 (좁음)
                (x + stem_top_w, stem_top_y),              # 오른쪽 상단 (좁음)
                (x + stem_bot_w, stem_top_y + stem_h),     # 오른쪽 하단 (넓음)
                (x - stem_bot_w, stem_top_y + stem_h)      # 왼쪽 하단 (넓음)
            ])
        elif symbol_index == 1:  # 하트 ♥
            # 두 개의 원 + 삼각형
            pygame.draw.circle(screen, color, (x - size // 2, y - size // 3), size // 2 + 1)
            pygame.draw.circle(screen, color, (x + size // 2, y - size // 3), size // 2 + 1)
            points = [(x, y + size), (x - size, y - size // 4), (x + size, y - size // 4)]
            pygame.draw.polygon(screen, color, points)
        elif symbol_index == 2:  # 다이아몬드 ♦
            # 마름모 형태 (10% 크게)
            sz = size * 1.1
            points = [
                (x, y - sz),      # 상단
                (x + sz, y),      # 우측
                (x, y + sz),      # 하단
                (x - sz, y),      # 좌측
            ]
            pygame.draw.polygon(screen, color, points)
        elif symbol_index == 3:  # 클럽 ♣
            # 세 개의 큰 원 (잎) + 줄기
            s = size * 1.3  # 전체 크기 확대
            leaf_r = int(s * 0.50)  # 잎 반지름 (더 크게)

            # 상단 잎 (더 위로, 더 도드라지게)
            pygame.draw.circle(screen, color, (x, int(y - s * 0.55)), leaf_r)
            # 좌하단 잎 (더 벌어지게)
            pygame.draw.circle(screen, color, (int(x - s * 0.52), int(y + s * 0.1)), leaf_r)
            # 우하단 잎 (더 벌어지게)
            pygame.draw.circle(screen, color, (int(x + s * 0.52), int(y + s * 0.1)), leaf_r)

            # 중앙 빈틈 채우기
            pygame.draw.circle(screen, color, (x, int(y - s * 0.15)), int(leaf_r * 0.6))

            # 줄기 (밑으로 갈수록 넓어지는 형태)
            stem_top_w = s * 0.12
            stem_bot_w = s * 0.24
            stem_top = y + s * 0.35
            pygame.draw.polygon(screen, color, [
                (x - stem_top_w, stem_top),
                (x + stem_top_w, stem_top),
                (x + stem_bot_w, y + s * 0.75),
                (x - stem_bot_w, y + s * 0.75)
            ])

    def _draw_pot_display(self, screen, x, y):
        """팟 표시 (프리미엄) - 금액에 따른 애니메이션"""
        pot = self.game.pot

        # 팟 박스
        box_w, box_h = 170, 60

        # 애니메이션 오프셋 계산 (판돈에 따라)
        shake_x, shake_y = 0, 0
        heat_intensity = 0  # 열기 효과 강도
        inferno_mode = False  # 3000골드 이상 극한 모드

        if pot >= 3000:
            # 3000골드 이상: 극한 인페르노 모드
            shake_speed = 18  # 매우 빠른 흔들림
            shake_amount = 5  # 매우 강한 흔들림
            shake_x = int(math.sin(self.table_pulse_phase * shake_speed) * shake_amount)
            shake_y = int(math.cos(self.table_pulse_phase * shake_speed * 1.5) * shake_amount * 0.8)
            # 추가 랜덤 진동
            shake_x += int(math.sin(self.table_pulse_phase * 25) * 2)
            shake_y += int(math.cos(self.table_pulse_phase * 30) * 1.5)
            heat_intensity = 1.5
            inferno_mode = True
        elif pot >= 2000:
            # 2000골드 이상: 힘찬 흔들림 + 열기 효과
            shake_speed = 12  # 빠른 흔들림
            shake_amount = 3  # 강한 흔들림
            shake_x = int(math.sin(self.table_pulse_phase * shake_speed) * shake_amount)
            shake_y = int(math.cos(self.table_pulse_phase * shake_speed * 1.3) * shake_amount * 0.7)
            heat_intensity = 1.0
        elif pot >= 1000:
            # 1000골드 이상: 가벼운 흔들림
            shake_speed = 6  # 느린 흔들림
            shake_amount = 1.5  # 약한 흔들림
            shake_x = int(math.sin(self.table_pulse_phase * shake_speed) * shake_amount)
            shake_y = int(math.cos(self.table_pulse_phase * shake_speed * 1.2) * shake_amount * 0.5)
            heat_intensity = 0.3

        # 위치에 흔들림 적용
        draw_x = x + shake_x
        draw_y = y + shake_y

        # 2000골드 이상: 열기 글로우 효과
        if heat_intensity > 0.5:
            # 붉은 열기 글로우 (인페르노 모드에서 더 강렬하게)
            glow_size = 50 if inferno_mode else 30  # 인페르노: 더 넓은 글로우
            glow_surf = pygame.Surface((box_w + glow_size, box_h + glow_size), pygame.SRCALPHA)
            glow_speed = 12 if inferno_mode else 8
            glow_pulse = 0.6 + 0.4 * math.sin(self.table_pulse_phase * glow_speed)
            glow_layers = 5 if inferno_mode else 3  # 인페르노: 더 많은 레이어

            for i in range(glow_layers, 0, -1):
                if inferno_mode:
                    # 인페르노: 더 강렬한 빨강/주황 글로우
                    glow_alpha = int(60 * glow_pulse * heat_intensity * (glow_layers + 1 - i) / glow_layers)
                    # 바깥쪽은 빨강, 안쪽은 노랑
                    red_ratio = i / glow_layers
                    glow_color = (255, int(80 + 120 * (1 - red_ratio) * glow_pulse), int(30 * (1 - red_ratio)), glow_alpha)
                else:
                    glow_alpha = int(40 * glow_pulse * heat_intensity * (4 - i) / 3)
                    glow_color = (255, 100 + int(50 * glow_pulse), 50, glow_alpha)

                half_glow = glow_size // 2
                pygame.draw.rect(glow_surf, glow_color,
                               (half_glow - i * 5, half_glow - i * 5, box_w + i * 10, box_h + i * 10),
                               border_radius=12)
            screen.blit(glow_surf, (draw_x - box_w // 2 - glow_size // 2, draw_y - glow_size // 2))

            # 인페르노 모드: 외곽 불꽃 링 효과
            if inferno_mode:
                ring_surf = pygame.Surface((box_w + 60, box_h + 60), pygame.SRCALPHA)
                ring_cx, ring_cy = (box_w + 60) // 2, (box_h + 60) // 2
                for angle in range(0, 360, 15):
                    rad = math.radians(angle + self.table_pulse_phase * 100)
                    ring_pulse = 0.5 + 0.5 * math.sin(self.table_pulse_phase * 10 + angle * 0.1)
                    ring_r = 50 + int(8 * ring_pulse)
                    spark_x = ring_cx + int(math.cos(rad) * ring_r * (box_w / box_h))
                    spark_y = ring_cy + int(math.sin(rad) * ring_r)
                    spark_size = 2 + int(3 * ring_pulse)
                    spark_alpha = int(180 * ring_pulse)
                    spark_color = (255, int(100 + 100 * ring_pulse), 30, spark_alpha)
                    pygame.draw.circle(ring_surf, spark_color, (spark_x, spark_y), spark_size)
                screen.blit(ring_surf, (draw_x - box_w // 2 - 30, draw_y - 30))

        # 그림자
        pygame.draw.rect(screen, (0, 0, 0, 60), (draw_x - box_w // 2 + 3, draw_y + 3, box_w, box_h), border_radius=8)

        # 배경 (열기에 따라 색상 변화)
        for i in range(box_h):
            ratio = i / box_h
            if inferno_mode:
                # 인페르노: 강렬한 빨강/검정 그라데이션 (용암처럼)
                heat_pulse = 0.6 + 0.4 * math.sin(self.table_pulse_phase * 10 + i * 0.15)
                lava_wave = 0.5 + 0.5 * math.sin(self.table_pulse_phase * 8 + i * 0.2)
                r = int(80 + ratio * 40 + 60 * heat_intensity * heat_pulse)
                g = int(20 + ratio * 15 + 30 * lava_wave)
                b = int(15 + ratio * 10)
            elif heat_intensity > 0.5:
                # 붉은 열기 배경
                heat_pulse = 0.7 + 0.3 * math.sin(self.table_pulse_phase * 6 + i * 0.1)
                r = int(55 + ratio * 20 + 30 * heat_intensity * heat_pulse)
                g = int(30 + ratio * 10)
                b = int(35 + ratio * 10)
            else:
                r = int(35 + ratio * 15)
                g = int(30 + ratio * 10)
                b = int(45 + ratio * 15)
            pygame.draw.line(screen, (r, g, b),
                           (draw_x - box_w // 2, draw_y + i), (draw_x + box_w // 2, draw_y + i))

        # 지그재그 테두리 (금색/은색 교차, 열기 시 금색/주황색)
        box_x = draw_x - box_w // 2
        zigzag_size = 6  # 지그재그 크기

        if inferno_mode:
            # 인페르노: 빨강/노랑 교차 (불타는 효과) + 매우 빠른 애니메이션
            heat_pulse = 0.5 + 0.5 * math.sin(self.table_pulse_phase * 15)
            red_color = (255, int(50 + 80 * heat_pulse), 30)
            yellow_color = (255, int(200 + 55 * heat_pulse), int(50 + 50 * heat_pulse))
            border_colors = [red_color, yellow_color]
        elif heat_intensity > 0.5:
            # 열기 효과: 금색/주황색 교차 + 움직이는 효과
            heat_pulse = 0.7 + 0.3 * math.sin(self.table_pulse_phase * 10)
            orange_color = (255, int(150 + 50 * heat_pulse), 50)
            border_colors = [self.GOLD, orange_color]
        else:
            border_colors = [self.GOLD, self.SILVER]

        # 지그재그 오프셋 (애니메이션용) - 인페르노는 더 빠르게
        zigzag_speed = 4 if inferno_mode else 2
        zigzag_offset = int(self.table_pulse_phase * zigzag_speed) % (zigzag_size * 2) if pot >= 1000 else 0

        # 상단 지그재그
        for i in range(-zigzag_offset, box_w + zigzag_size * 2, zigzag_size * 2):
            x1 = max(box_x, box_x + i)
            x2 = min(box_x + i + zigzag_size, box_x + box_w)
            x3 = min(box_x + i + zigzag_size * 2, box_x + box_w)
            if x1 < box_x + box_w and x2 > box_x:
                color_idx = ((i + zigzag_offset) // (zigzag_size * 2)) % 2
                pygame.draw.line(screen, border_colors[color_idx], (x1, draw_y), (x2, draw_y - 3), 2)
                pygame.draw.line(screen, border_colors[color_idx], (x2, draw_y - 3), (x3, draw_y), 2)

        # 하단 지그재그
        for i in range(-zigzag_offset, box_w + zigzag_size * 2, zigzag_size * 2):
            x1 = max(box_x, box_x + i)
            x2 = min(box_x + i + zigzag_size, box_x + box_w)
            x3 = min(box_x + i + zigzag_size * 2, box_x + box_w)
            if x1 < box_x + box_w and x2 > box_x:
                color_idx = ((i + zigzag_offset) // (zigzag_size * 2)) % 2
                pygame.draw.line(screen, border_colors[color_idx], (x1, draw_y + box_h), (x2, draw_y + box_h + 3), 2)
                pygame.draw.line(screen, border_colors[color_idx], (x2, draw_y + box_h + 3), (x3, draw_y + box_h), 2)

        # 좌측 지그재그
        for i in range(-zigzag_offset, box_h + zigzag_size * 2, zigzag_size * 2):
            y1 = max(draw_y, draw_y + i)
            y2 = min(draw_y + i + zigzag_size, draw_y + box_h)
            y3 = min(draw_y + i + zigzag_size * 2, draw_y + box_h)
            if y1 < draw_y + box_h and y2 > draw_y:
                color_idx = ((i + zigzag_offset) // (zigzag_size * 2)) % 2
                pygame.draw.line(screen, border_colors[color_idx], (box_x, y1), (box_x - 3, y2), 2)
                pygame.draw.line(screen, border_colors[color_idx], (box_x - 3, y2), (box_x, y3), 2)

        # 우측 지그재그
        for i in range(-zigzag_offset, box_h + zigzag_size * 2, zigzag_size * 2):
            y1 = max(draw_y, draw_y + i)
            y2 = min(draw_y + i + zigzag_size, draw_y + box_h)
            y3 = min(draw_y + i + zigzag_size * 2, draw_y + box_h)
            if y1 < draw_y + box_h and y2 > draw_y:
                color_idx = ((i + zigzag_offset) // (zigzag_size * 2)) % 2
                pygame.draw.line(screen, border_colors[color_idx], (box_x + box_w, y1), (box_x + box_w + 3, y2), 2)
                pygame.draw.line(screen, border_colors[color_idx], (box_x + box_w + 3, y2), (box_x + box_w, y3), 2)

        # 모서리 장식 (금색 동그라미, 열기 시 펄스)
        corner_radius = 4
        if inferno_mode:
            # 인페르노: 더 큰 펄스 + 빨간색으로 변화
            corner_pulse = int(3 * math.sin(self.table_pulse_phase * 12))
            corner_radius = 5 + corner_pulse
            corner_color_pulse = 0.5 + 0.5 * math.sin(self.table_pulse_phase * 10)
            corner_color = (255, int(100 + 100 * corner_color_pulse), 30)
        elif heat_intensity > 0.5:
            corner_pulse = int(2 * math.sin(self.table_pulse_phase * 8))
            corner_radius = 4 + corner_pulse
            corner_color = self.GOLD
        else:
            corner_color = self.GOLD
        pygame.draw.circle(screen, corner_color, (box_x, draw_y), corner_radius)
        pygame.draw.circle(screen, corner_color, (box_x + box_w, draw_y), corner_radius)
        pygame.draw.circle(screen, corner_color, (box_x, draw_y + box_h), corner_radius)
        pygame.draw.circle(screen, corner_color, (box_x + box_w, draw_y + box_h), corner_radius)

        # 2000골드 이상: 상단에 불꽃 파티클
        if heat_intensity > 0.5:
            if inferno_mode:
                # 인페르노: 더 많고, 크고, 높이 솟는 불꽃
                flame_count = 9  # 더 많은 불꽃
                for i in range(flame_count):
                    flame_x = box_x + 10 + i * 18 + int(math.sin(self.table_pulse_phase * 8 + i) * 8)
                    # 더 높이 솟는 불꽃
                    flame_height = int(abs(math.sin(self.table_pulse_phase * 12 + i * 1.2)) * 18)
                    flame_y = draw_y - 12 - flame_height
                    flame_size = 4 + int(math.sin(self.table_pulse_phase * 9 + i) * 3)
                    # 색상 변화 (빨강 → 노랑 → 주황)
                    color_phase = (self.table_pulse_phase * 6 + i * 0.8) % (math.pi * 2)
                    if color_phase < math.pi:
                        flame_color = (255, int(80 + 120 * math.sin(color_phase)), 30)
                    else:
                        # Clamp values to valid 0-255 range
                        g_val = max(0, min(255, int(200 + 55 * math.sin(color_phase))))
                        b_val = max(0, min(255, int(80 * abs(math.sin(color_phase)))))
                        flame_color = (255, g_val, b_val)
                    pygame.draw.circle(screen, flame_color, (flame_x, flame_y), max(2, flame_size))
                    # 불꽃 꼬리 (트레일)
                    for t in range(1, 3):
                        trail_y = flame_y + t * 4
                        trail_size = max(1, flame_size - t)
                        trail_alpha = 0.7 - t * 0.2
                        trail_color = (255, int(150 * trail_alpha), int(30 * trail_alpha))
                        pygame.draw.circle(screen, trail_color, (flame_x, trail_y), trail_size)

                # 하단에도 불꽃 추가 (인페르노만)
                for i in range(5):
                    flame_x = box_x + 20 + i * 35 + int(math.sin(self.table_pulse_phase * 7 + i + 2) * 6)
                    flame_y = draw_y + box_h + 8 + int(abs(math.sin(self.table_pulse_phase * 10 + i)) * 6)
                    flame_size = 3 + int(math.sin(self.table_pulse_phase * 8 + i) * 2)
                    g_val = max(0, min(255, int(100 + 80 * math.sin(self.table_pulse_phase * 5 + i))))
                    flame_color = (255, g_val, 40)
                    pygame.draw.circle(screen, flame_color, (flame_x, flame_y), max(1, flame_size))
            else:
                # 일반 2000골드: 기존 불꽃
                for i in range(5):
                    flame_x = box_x + 20 + i * 35 + int(math.sin(self.table_pulse_phase * 5 + i) * 5)
                    flame_y = draw_y - 8 - int(abs(math.sin(self.table_pulse_phase * 8 + i * 1.5)) * 8)
                    flame_size = 3 + int(math.sin(self.table_pulse_phase * 6 + i) * 2)
                    g_val = max(0, min(255, 150 + int(50 * math.sin(self.table_pulse_phase * 4 + i))))
                    flame_color = (255, g_val, 50)
                    pygame.draw.circle(screen, flame_color, (flame_x, flame_y), max(1, flame_size))

        # 칩 아이콘
        chip_x = draw_x - box_w // 2 + 28
        chip_y = draw_y + box_h // 2
        self._draw_chip(screen, chip_x, chip_y, 16)

        # 판돈 텍스트 (열기 시 색상 변화)
        if inferno_mode:
            # 인페르노: 빨강/주황 깜빡이는 텍스트 + 더 큰 폰트
            text_pulse = 0.5 + 0.5 * math.sin(self.table_pulse_phase * 10)
            pot_color = (255, int(120 + 80 * text_pulse), int(40 * text_pulse))
            label_color = (255, int(180 + 75 * text_pulse), int(100 * text_pulse))
            pot_size = 28  # 더 큰 폰트
        elif heat_intensity > 0.5:
            text_pulse = 0.7 + 0.3 * math.sin(self.table_pulse_phase * 6)
            pot_color = (255, int(200 + 55 * text_pulse), int(100 * text_pulse))
            label_color = self.SILVER
            pot_size = 26
        else:
            pot_color = self.GOLD_LIGHT
            label_color = self.SILVER
            pot_size = 26

        self._draw_text(screen, "판돈", draw_x + 15, draw_y + 6, label_color, 20, center=True)
        self._draw_text(screen, f"{pot:,}", draw_x + 8, draw_y + 30, pot_color, pot_size, center=True)
        self._draw_gold_coin(screen, draw_x + 60, draw_y + 42, 14)

    def _draw_chip(self, screen, x, y, radius):
        """칩 그리기"""
        # 그림자
        pygame.draw.circle(screen, (0, 0, 0, 80), (x + 2, y + 2), radius)

        # 칩 본체
        pygame.draw.circle(screen, (180, 140, 60), (x, y), radius)
        pygame.draw.circle(screen, self.GOLD, (x, y), radius - 2)
        pygame.draw.circle(screen, (200, 160, 80), (x, y), radius - 4)

        # 칩 테두리 장식
        pygame.draw.circle(screen, (150, 120, 50), (x, y), radius, 2)

        # 내부 선
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            inner_r = radius - 4
            outer_r = radius - 2
            pygame.draw.line(screen, (170, 130, 50),
                           (x + math.cos(rad) * inner_r, y + math.sin(rad) * inner_r),
                           (x + math.cos(rad) * outer_r, y + math.sin(rad) * outer_r), 2)

    def _draw_cards(self, screen):
        """카드 그리기 - 4인 테이블"""
        cx = self.screen_width // 2
        cy = self.screen_height // 2
        is_showdown = self.game.state in [PokerGame.STATE_SHOWDOWN, PokerGame.STATE_GAME_OVER,
                                           PokerGame.STATE_SHOWDOWN_INTRO, PokerGame.STATE_SHOWDOWN_REVEAL,
                                           PokerGame.STATE_SHOWDOWN_HAND]
        is_dealing = self.game.state in [PokerGame.STATE_DEALING, PokerGame.STATE_FLOP_DEALING,
                                          PokerGame.STATE_TURN_DEALING, PokerGame.STATE_RIVER_DEALING]

        # 쇼다운 레이아웃
        if is_showdown and self.game.community_cards:
            self._draw_showdown_cards(screen)
            return

        # 딜링 애니메이션 중
        if is_dealing:
            self._draw_animated_cards(screen)
            return

        # 일반 게임 레이아웃
        # 커뮤니티 카드 (중앙) - 더 위로 이동
        if self.game.community_cards:
            comm_y = cy - 60
            total_width = len(self.game.community_cards) * (self.CARD_WIDTH + 10)
            comm_start_x = cx - total_width // 2

            for i, card in enumerate(self.game.community_cards):
                card_x = comm_start_x + i * (self.CARD_WIDTH + 10)
                self.card_renderer.draw_card(screen, card, card_x, comm_y,
                                            self.CARD_WIDTH, self.CARD_HEIGHT)

        # 4인 플레이어 카드 위치
        card_positions = {
            'south': (cx - self.CARD_WIDTH - 8, self.screen_height - 180),  # 플레이어 (하단)
            'north': (cx - 20, 60),                                          # 북쪽 NPC (상단) - 가운데로 이동
            'west': (30, cy - self.CARD_HEIGHT // 2),                        # 서쪽 NPC (좌측)
            'east': (self.screen_width - 20 - self.CARD_WIDTH, cy - self.CARD_HEIGHT // 2),  # 동쪽 NPC (우측) - 더 오른쪽
        }

        label_colors = {
            'south': self.BLUE,
            'north': self.RED,
            'west': (255, 180, 100),  # 주황색
            'east': (100, 255, 180),  # 민트색
        }

        for position, player in self.game.players.items():
            if not player.hand:
                continue

            start_x, card_y = card_positions[position]
            is_human = player.is_human

            for i, card in enumerate(player.hand):
                if position in ['west', 'east']:
                    # 좌우 플레이어는 세로 배치
                    card_x = start_x
                    actual_y = card_y + i * 50
                else:
                    # 상하 플레이어는 가로 배치
                    card_x = start_x + i * (self.CARD_WIDTH + 15)
                    actual_y = card_y

                # NPC 카드는 뒷면으로 (쇼다운 전)
                if not is_human and not is_showdown:
                    self.card_renderer.draw_card(screen, card, card_x, actual_y,
                                                self.CARD_WIDTH, self.CARD_HEIGHT, face_up=False)
                else:
                    self.card_renderer.draw_card(screen, card, card_x, actual_y,
                                                self.CARD_WIDTH, self.CARD_HEIGHT)

            # 플레이어(south)만 카드 라벨 표시 - NPC는 정보 패널에 이름 있음
            if position == 'south':
                label_x = start_x + self.CARD_WIDTH
                label_y = card_y - 25
                label_text = "YOUR HAND"
                self._draw_text(screen, label_text, label_x, label_y, label_colors[position], 14, center=True)

            # NPC 베팅 금액 표시 (카드 하단)
            if position != 'south' and player.current_bet > 0:
                bet_text = f"베팅:{player.current_bet}"
                if position == 'north':
                    # 북쪽 NPC - 카드 하단 중앙
                    bet_x = start_x + self.CARD_WIDTH  # 두 카드 중간
                    bet_y = card_y + self.CARD_HEIGHT + 5
                elif position == 'west':
                    # 서쪽 NPC - 카드 우측 하단
                    bet_x = start_x + self.CARD_WIDTH + 10
                    bet_y = card_y + self.CARD_HEIGHT + 30
                elif position == 'east':
                    # 동쪽 NPC - 카드 좌측 하단
                    bet_x = start_x - 10
                    bet_y = card_y + self.CARD_HEIGHT + 30
                self._draw_text(screen, bet_text, bet_x, bet_y, (200, 200, 100), 12, center=True)

        # 플레이어(south) 현재 족보 표시 (커뮤니티 카드가 있을 때만)
        if self.game.community_cards and 'south' in self.game.players:
            south_player = self.game.players['south']
            if south_player.hand and len(south_player.hand) == 2:
                # 플레이어 카드 + 커뮤니티 카드로 족보 계산
                all_cards = south_player.hand + self.game.community_cards
                if len(all_cards) >= 5:
                    hand_result = HandEvaluator.evaluate(all_cards)
                    rank = hand_result[0]
                    tiebreaker = hand_result[1]
                    # 상세 족보 이름 (예: A 원페어, K 스트레이트)
                    hand_name = HandEvaluator.get_detailed_hand_name(rank, tiebreaker, all_cards)

                    # 플레이어 카드 우측에 표시
                    south_x, south_y = card_positions['south']
                    hand_text_x = south_x + self.CARD_WIDTH + 15 + self.CARD_WIDTH + 20
                    hand_text_y = south_y + self.CARD_HEIGHT // 2 - 7

                    # 족보에 따른 색상
                    if rank >= 9:  # 로얄 플러시, 스트레이트 플러시
                        hand_color = (255, 215, 0)  # 금색
                    elif rank >= 7:  # 풀하우스, 포카드
                        hand_color = (255, 100, 255)  # 분홍색
                    elif rank >= 5:  # 스트레이트, 플러시
                        hand_color = (100, 200, 255)  # 하늘색
                    elif rank >= 2:  # 원페어, 투페어, 트리플
                        hand_color = (150, 255, 150)  # 연두색
                    else:  # 하이카드
                        hand_color = (180, 180, 180)  # 회색

                    self._draw_text(screen, f"[{hand_name}]", hand_text_x, hand_text_y,
                                   hand_color, 14, center=False)

    def _draw_animated_cards(self, screen):
        """애니메이션 중인 카드 그리기 - 4인 테이블"""
        cx = self.screen_width // 2
        cy = self.screen_height // 2

        # 이미 배치된 카드들 (애니메이션 완료된 것들)
        # 커뮤니티 카드 - 더 위로 이동
        if self.game.community_cards:
            comm_y = cy - 60
            total_width = len(self.game.community_cards) * (self.CARD_WIDTH + 10)
            comm_start_x = cx - total_width // 2

            for i, card in enumerate(self.game.community_cards):
                card_x = comm_start_x + i * (self.CARD_WIDTH + 10)
                self.card_renderer.draw_card(screen, card, card_x, comm_y,
                                            self.CARD_WIDTH, self.CARD_HEIGHT)

        # 4인 플레이어 카드 위치
        card_positions = {
            'south': (cx - self.CARD_WIDTH - 8, self.screen_height - 180),
            'north': (cx - 20, 60),  # 가운데로 이동
            'west': (30, cy - self.CARD_HEIGHT // 2),
            'east': (self.screen_width - 20 - self.CARD_WIDTH, cy - self.CARD_HEIGHT // 2),
        }

        # 각 플레이어 카드 (딜링 완료된 것만)
        for position, player in self.game.players.items():
            if not player.hand:
                continue
            start_x, card_y = card_positions[position]
            is_human = player.is_human

            for i, card in enumerate(player.hand):
                animating = any(a.card == card and not a.completed for a in self.game.card_animations)
                if not animating:
                    if position in ['west', 'east']:
                        card_x = start_x
                        actual_y = card_y + i * 50
                    else:
                        card_x = start_x + i * (self.CARD_WIDTH + 15)
                        actual_y = card_y

                    # NPC 카드는 뒷면
                    if not is_human:
                        self.card_renderer.draw_card(screen, card, card_x, actual_y,
                                                    self.CARD_WIDTH, self.CARD_HEIGHT, face_up=False)
                    else:
                        self.card_renderer.draw_card(screen, card, card_x, actual_y,
                                                    self.CARD_WIDTH, self.CARD_HEIGHT)

        # 플레이어(south) 현재 족보 표시 (커뮤니티 카드가 있을 때만)
        if self.game.community_cards and 'south' in self.game.players:
            south_player = self.game.players['south']
            if south_player.hand and len(south_player.hand) == 2:
                # 플레이어 카드 + 커뮤니티 카드로 족보 계산
                all_cards = south_player.hand + self.game.community_cards
                if len(all_cards) >= 5:
                    hand_result = HandEvaluator.evaluate(all_cards)
                    rank = hand_result[0]
                    tiebreaker = hand_result[1]
                    # 상세 족보 이름 (예: A 원페어, K 스트레이트)
                    hand_name = HandEvaluator.get_detailed_hand_name(rank, tiebreaker, all_cards)

                    # 플레이어 카드 우측에 표시
                    south_x, south_y = card_positions['south']
                    # 카드 2장 너비 + 여백 계산 (카드간격: CARD_WIDTH + 15)
                    hand_text_x = south_x + self.CARD_WIDTH + 15 + self.CARD_WIDTH + 20
                    hand_text_y = south_y + self.CARD_HEIGHT // 2 - 7

                    # 족보에 따른 색상
                    if rank >= 9:  # 로얄 플러시, 스트레이트 플러시
                        hand_color = (255, 215, 0)  # 금색
                    elif rank >= 7:  # 풀하우스, 포카드
                        hand_color = (255, 100, 255)  # 분홍색
                    elif rank >= 5:  # 스트레이트, 플러시
                        hand_color = (100, 200, 255)  # 하늘색
                    elif rank >= 2:  # 원페어, 투페어, 트리플
                        hand_color = (150, 255, 150)  # 연두색
                    else:  # 하이카드
                        hand_color = (180, 180, 180)  # 회색

                    self._draw_text(screen, f"[{hand_name}]", hand_text_x, hand_text_y,
                                   hand_color, 14, center=False)

        # 펜딩 카드 (커뮤니티 딜링 중)
        if self.game.pending_cards:
            comm_y = cy - 60
            base_idx = len(self.game.community_cards)
            base_x = 200 + base_idx * (self.CARD_WIDTH + 10)

            for i, card in enumerate(self.game.pending_cards):
                animating = any(a.card == card and not a.completed for a in self.game.card_animations)
                if not animating:
                    card_x = base_x + i * (self.CARD_WIDTH + 10)
                    self.card_renderer.draw_card(screen, card, card_x, comm_y,
                                                self.CARD_WIDTH, self.CARD_HEIGHT)

        # 애니메이션 중인 카드들
        for anim in self.game.card_animations:
            if not anim.completed:
                # 트레일 효과
                self.particles.emit_card_trail(anim.current_x + self.CARD_WIDTH // 2,
                                              anim.current_y + self.CARD_HEIGHT // 2)

                self.card_renderer.draw_card(
                    screen, anim.card,
                    int(anim.current_x), int(anim.current_y),
                    self.CARD_WIDTH, self.CARD_HEIGHT,
                    scale=anim.scale,
                    rotation=anim.rotation,
                    face_up=anim.flipped
                )

    def _draw_showdown_cards(self, screen):
        """쇼다운 시 카드 배치 - 4인 텍사스 홀덤 방식
        모든 플레이어 홀카드 2장 공개, 커뮤니티 카드는 가운데 유지"""
        cx = self.screen_width // 2
        cy = self.screen_height // 2

        # 커뮤니티 카드 (중앙) - 위로 이동
        if self.game.community_cards:
            comm_y = cy - 60
            total_width = len(self.game.community_cards) * (self.CARD_WIDTH + 10)
            comm_start_x = cx - total_width // 2

            for i, card in enumerate(self.game.community_cards):
                card_x = comm_start_x + i * (self.CARD_WIDTH + 10)
                self.card_renderer.draw_card(screen, card, card_x, comm_y,
                                            self.CARD_WIDTH, self.CARD_HEIGHT)

            self._draw_text(screen, "COMMUNITY CARDS", cx, comm_y - 30, self.GOLD, 14, center=True)

        # 4인 플레이어 카드 위치 (쇼다운용)
        card_positions = {
            'south': (cx - self.CARD_WIDTH - 8, self.screen_height - 140),  # 더 아래로 이동
            'north': (cx - 20, 60),  # 가운데로 이동
            'west': (30, cy - self.CARD_HEIGHT // 2 - 30),   # 약간 위로 이동
            'east': (self.screen_width - 20 - self.CARD_WIDTH, cy - self.CARD_HEIGHT // 2 - 30),  # 약간 위로 이동
        }

        border_colors = {
            'south': (100, 150, 255),   # 파란색
            'north': (255, 100, 100),   # 빨간색
            'west': (255, 180, 100),    # 주황색
            'east': (100, 255, 180),    # 민트색
        }

        # 승자 정보 가져오기
        winner_positions = []
        if hasattr(self.game, 'winners') and self.game.winners:
            winner_positions = [w['position'] for w in self.game.winners]

        for position, player in self.game.players.items():
            if not player.hand or player.folded:
                continue

            start_x, card_y = card_positions[position]
            border_color = border_colors[position]

            # 승자는 황금색 테두리
            if position in winner_positions:
                border_color = self.GOLD

            for i, card in enumerate(player.hand):
                card.face_up = True  # 쇼다운이므로 모두 공개

                if position in ['west', 'east']:
                    card_x = start_x
                    actual_y = card_y + i * 50
                else:
                    card_x = start_x + i * (self.CARD_WIDTH + 15)
                    actual_y = card_y

                # 강조 테두리
                pygame.draw.rect(screen, border_color,
                               (card_x - 3, actual_y - 3, self.CARD_WIDTH + 6, self.CARD_HEIGHT + 6),
                               2, border_radius=6)

                self.card_renderer.draw_card(screen, card, card_x, actual_y,
                                            self.CARD_WIDTH, self.CARD_HEIGHT)

            # 레이블
            label_x = start_x + self.CARD_WIDTH
            if position == 'south':
                label_y = card_y - 25
                label_text = "YOUR HAND"
            else:
                if position in ['west', 'east']:
                    label_x = start_x + self.CARD_WIDTH + 10 if position == 'west' else start_x
                label_y = card_y - 25
                label_text = player.name

            # 승자 표시
            if position in winner_positions:
                label_text = f"★ {label_text} ★"

            self._draw_text(screen, label_text, label_x, label_y, border_colors[position], 14, center=True)

            # 각 플레이어 족보 표시
            if hasattr(self.game, 'hand_results') and position in self.game.hand_results:
                hand_result = self.game.hand_results[position]
                rank = hand_result[0]
                tiebreaker = hand_result[1]
                # 상세 족보 이름 (예: A 원페어, K 스트레이트)
                all_cards = player.hand + self.game.community_cards if player.hand else []
                hand_name = HandEvaluator.get_detailed_hand_name(rank, tiebreaker, all_cards)

                # 족보 표시 위치 결정
                if position == 'south':
                    hand_label_x = label_x
                    hand_label_y = card_y + self.CARD_HEIGHT + 20
                elif position == 'north':
                    hand_label_x = label_x
                    hand_label_y = card_y + self.CARD_HEIGHT + 20
                elif position == 'west':
                    # 좌측 NPC - 카드 상단에 표시 (더 위로)
                    hand_label_x = start_x + self.CARD_WIDTH // 2
                    hand_label_y = card_y - 65  # 카드 위쪽으로 더 이동
                else:  # east
                    # 우측 NPC - 카드 상단에 표시 (왼쪽, 더 위로 이동)
                    hand_label_x = start_x + self.CARD_WIDTH // 2 - 30  # 왼쪽으로 30px 이동
                    hand_label_y = card_y - 70  # 카드 위쪽으로 더 이동

                # 승자는 황금색, 나머지는 흰색
                hand_color = self.GOLD if position in winner_positions else self.WHITE

                # 배경 박스 추가 (가독성 향상) - 테두리 없음
                text_width = len(hand_name) * 11 + 30  # 텍스트 너비 계산 확대
                box_height = 26  # 박스 높이 확대
                bg_rect = pygame.Rect(hand_label_x - text_width // 2, hand_label_y - 4, text_width, box_height)
                pygame.draw.rect(screen, (20, 20, 30, 200), bg_rect, border_radius=6)

                self._draw_text(screen, f"[{hand_name}]", hand_label_x, hand_label_y + 2, hand_color, 16, center=True)

    def _draw_ui(self, screen):
        """기본 UI - 4인 테이블"""
        cx = self.screen_width // 2
        cy = self.screen_height // 2

        # 쇼다운/결과 상태인지 확인
        is_showdown = self.game.state in [PokerGame.STATE_SHOWDOWN, PokerGame.STATE_GAME_OVER,
                                           PokerGame.STATE_SHOWDOWN_INTRO, PokerGame.STATE_SHOWDOWN_REVEAL,
                                           PokerGame.STATE_SHOWDOWN_HAND]

        # 4인 플레이어 정보 표시 위치
        # 쇼다운 시에는 좌우 플레이어 정보를 카드 아래로 이동
        # 북쪽 NPC: 상단 중앙에서 살짝 왼쪽 (상단 카드와 겹침 방지)
        north_info_x = cx - 180  # 중앙에서 왼쪽으로 180px
        if is_showdown:
            player_info_positions = {
                'south': (20, self.screen_height - 180),    # 좌하단 (플레이어) - 카드 y축과 정렬
                'north': (north_info_x, 15),                 # 상단 중앙-왼쪽 (북쪽 NPC)
                'west': (20, cy + 80),                       # 좌측 - 카드 아래로 이동
                'east': (self.screen_width - 150, cy + 80),  # 우측 - 카드 아래로 이동
            }
        else:
            player_info_positions = {
                'south': (20, self.screen_height - 180),    # 좌하단 (플레이어) - 카드 y축과 정렬
                'north': (north_info_x, 15),                 # 상단 중앙-왼쪽 (북쪽 NPC)
                'west': (20, cy - 130),                      # 좌측 - 커뮤니티 카드 위로 이동
                'east': (self.screen_width - 150, cy - 130), # 우측 - 커뮤니티 카드 위로 이동
            }

        label_colors = {
            'south': self.BLUE,
            'north': self.RED,
            'west': (255, 180, 100),
            'east': (100, 255, 180),
        }

        # 현재 턴인 플레이어 조명 효과
        current_turn = None
        if self.game.state in [PokerGame.STATE_PREFLOP, PokerGame.STATE_FLOP,
                               PokerGame.STATE_TURN, PokerGame.STATE_RIVER]:
            if self.game.npc_thinking and self.game.npc_thinking_player:
                # NPC 생각 중
                current_turn = self.game.npc_thinking_player
            elif self.game.waiting_for_player_response:
                # NPC 레이즈 후 플레이어 응답 대기
                current_turn = 'south'
            elif not self.game.betting_round_complete:
                # 베팅 라운드 진행 중 - 플레이어 차례
                south = self.game.players.get('south')
                if south and not south.folded and not south.is_all_in:
                    current_turn = 'south'

        if current_turn:
            self._draw_turn_spotlight(screen, current_turn, player_info_positions)

        # 각 플레이어 정보 패널 표시
        for position, player in self.game.players.items():
            x, y = player_info_positions[position]
            color = label_colors[position]
            self._draw_player_info_panel(screen, x, y, player, color)

        # 팟(Pot) 정보 - 제거됨 (UI 간소화)

        # 현재 콜 금액 (플레이어 차례일 때)
        human = self.game.players['south']
        if self.game.current_action_player == 'south' and not human.folded:
            call_amount = self.game.current_bet_to_call - human.current_bet
            if call_amount > 0:
                self._draw_text(screen, f"콜: {call_amount}G", cx, self.screen_height - 230, self.SILVER, 14, center=True)

        # 연승 표시 (플레이어 정보 옆)
        if self.game.player_win_streak > 0:
            streak_color = (255, 100, 100) if self.game.player_win_streak >= 3 else (255, 200, 100)
            intensity = 1.5 if self.game.player_win_streak >= 3 else 1.0
            # 불꽃 아이콘 + 텍스트
            fire_x = 152
            fire_y = self.screen_height - 40
            self._draw_fire_icon(screen, fire_x, fire_y, 16, intensity)
            self._draw_text(screen, f"{self.game.player_win_streak}연승", fire_x + 18, self.screen_height - 47, streak_color, 14)

        # 게임 상태 (우상단)
        state_names = {
            'betting': '베팅',
            'dealing': '딜링...',
            'preflop': '프리플랍',
            'flop_dealing': '플랍...',
            'flop': '플랍',
            'turn_dealing': '턴...',
            'turn': '턴',
            'river_dealing': '리버...',
            'river': '리버',
            'showdown': '쇼다운',
            'game_over': '게임 종료'
        }
        state_text = state_names.get(self.game.state, self.game.state)
        self._draw_status_badge(screen, self.screen_width - 20, 20, state_text)

        # NPC 생각 중 또는 액션 표시
        self._draw_npc_thinking(screen)

    def _draw_npc_thinking(self, screen):
        """NPC 생각 중 또는 액션 표시"""
        import time
        cx = self.screen_width // 2
        cy = self.screen_height // 2

        # NPC 위치별 말풍선 좌표
        bubble_positions = {
            'west': (150, cy - 80),
            'north': (cx + 120, 100),
            'east': (self.screen_width - 150, cy - 80),
        }

        # 생각 중일 때
        if self.game.npc_thinking and self.game.npc_thinking_player:
            position = self.game.npc_thinking_player
            if position in bubble_positions:
                bx, by = bubble_positions[position]
                npc = self.game.players[position]

                # 생각 시간에 따른 점 개수 (애니메이션)
                current_time = time.time() * 1000
                elapsed = current_time - self.game.npc_think_start_time
                dots = int((elapsed / 400) % 4)  # 0~3개 점
                think_text = f"{npc.name} 생각 중" + "." * dots

                # 말풍선 배경
                text_width = len(think_text) * 10 + 20
                bubble_rect = pygame.Rect(bx - text_width // 2, by - 15, text_width, 30)
                pygame.draw.rect(screen, (40, 35, 50), bubble_rect, border_radius=8)
                pygame.draw.rect(screen, (150, 140, 100), bubble_rect, 2, border_radius=8)

                # 텍스트
                self._draw_text(screen, think_text, bx, by - 8, (255, 220, 150), 14, center=True)

        # 액션 표시
        if self.game.npc_action_display and self.game.npc_thinking_player:
            position = self.game.npc_thinking_player
            if position in bubble_positions:
                bx, by = bubble_positions[position]

                # 액션별 색상
                action_text = self.game.npc_action_display
                if "폴드" in action_text:
                    text_color = (180, 180, 180)
                    border_color = (100, 100, 100)
                elif "레이즈" in action_text:
                    text_color = (255, 100, 100)
                    border_color = (255, 80, 80)
                elif "콜" in action_text:
                    text_color = (100, 255, 150)
                    border_color = (80, 200, 100)
                else:  # 체크
                    text_color = (150, 200, 255)
                    border_color = (100, 150, 200)

                # 말풍선 배경
                text_width = len(action_text) * 10 + 24
                bubble_rect = pygame.Rect(bx - text_width // 2, by - 14, text_width, 28)
                pygame.draw.rect(screen, (30, 30, 40), bubble_rect, border_radius=8)
                pygame.draw.rect(screen, border_color, bubble_rect, 2, border_radius=8)

                # 텍스트
                self._draw_text(screen, action_text, bx, by - 6, text_color, 12, center=True)

    def _draw_turn_spotlight(self, screen, position, player_info_positions):
        """현재 턴인 플레이어에게 조명 효과"""
        if position not in player_info_positions:
            return

        player = self.game.players.get(position)
        if not player or player.folded or player.is_bankrupt:
            return

        x, y = player_info_positions[position]
        box_w, box_h = 130, 45

        # 조명 효과 - 여러 겹의 반투명 글로우
        spotlight_surf = pygame.Surface((box_w + 60, box_h + 60), pygame.SRCALPHA)

        # 위치별 조명 색상
        spotlight_colors = {
            'south': (100, 150, 255),   # 파란색 (플레이어)
            'north': (255, 100, 100),   # 빨간색
            'west': (255, 180, 100),    # 주황색
            'east': (100, 255, 180),    # 민트색
        }
        base_color = spotlight_colors.get(position, (255, 220, 100))

        # 펄스 애니메이션 (시간에 따라 밝기 변화)
        import math
        pulse = (math.sin(self.animation_timer * 3) + 1) / 2  # 0~1 사이 값
        alpha_base = 25 + int(20 * pulse)

        # 외곽 글로우 (큰 원)
        for i in range(3):
            alpha = alpha_base - i * 8
            if alpha > 0:
                glow_color = (*base_color, alpha)
                radius = 30 - i * 5
                pygame.draw.ellipse(spotlight_surf, glow_color,
                                   (30 - radius, 30 - radius,
                                    box_w + radius * 2, box_h + radius * 2))

        screen.blit(spotlight_surf, (x - 30, y - 30))

        # 테두리 강조 효과
        border_alpha = 150 + int(50 * pulse)
        border_color = (*base_color, min(255, border_alpha))
        border_surf = pygame.Surface((box_w + 6, box_h + 6), pygame.SRCALPHA)
        pygame.draw.rect(border_surf, border_color, (0, 0, box_w + 6, box_h + 6), 3, border_radius=8)
        screen.blit(border_surf, (x - 3, y - 3))

    def _draw_player_info_panel(self, screen, x, y, player, color):
        """플레이어 정보 패널 그리기"""
        box_w, box_h = 130, 45

        # 파산/폴드한 플레이어는 어둡게
        if player.is_bankrupt:
            bg_color = (15, 15, 20)
            border_color = (60, 60, 60)
        elif player.folded:
            bg_color = (20, 20, 25)
            border_color = (80, 80, 80)
        else:
            bg_color = (30, 25, 40)
            border_color = color

        pygame.draw.rect(screen, bg_color, (x, y, box_w, box_h), border_radius=6)
        pygame.draw.rect(screen, border_color, (x, y, box_w, box_h), 2, border_radius=6)

        # 이름 (상단) - 파산/폴드 태그 표시
        if player.is_bankrupt:
            name_text = f"{player.name} (파산)"
            text_color = (120, 80, 80)
        elif player.folded:
            name_text = f"{player.name} (FOLD)"
            text_color = (100, 100, 100)
        else:
            name_text = player.name
            text_color = color
        self._draw_text(screen, name_text, x + box_w // 2, y + 5, text_color, 11, center=True)

        # 금화 아이콘 + 골드 (하단)
        coin_size = 18
        self._draw_gold_coin(screen, x + 15, y + 32, coin_size)
        if player.is_bankrupt:
            gold_color = (80, 60, 60)
        elif player.folded:
            gold_color = (100, 100, 80)
        else:
            gold_color = self.GOLD_LIGHT
        self._draw_text(screen, f"{player.gold:,}", x + 32, y + 24, gold_color, 14)

        # 현재 베팅 금액은 카드 하단에 표시하므로 패널에서는 제거됨

    def _draw_gold_coin(self, screen, x, y, size):
        """금화 아이콘 그리기 - 인게임과 동일한 입체감 있는 동전"""
        # 금화 서피스 생성
        coin_surf = pygame.Surface((size + 4, size + 4), pygame.SRCALPHA)

        cx, cy = size // 2 + 2, size // 2 + 2
        radius = size // 2

        # 색상 정의
        gold_dark = (180, 130, 20)      # 어두운 금색 (테두리/그림자)
        gold_main = (255, 200, 50)       # 메인 금색
        gold_light = (255, 235, 120)     # 밝은 금색 (하이라이트)
        gold_shine = (255, 250, 200)     # 반짝임

        # 그림자 (약간 아래 오른쪽)
        pygame.draw.circle(coin_surf, (0, 0, 0, 80), (cx + 2, cy + 2), radius)

        # 외곽 테두리 (어두운 금색)
        pygame.draw.circle(coin_surf, gold_dark, (cx, cy), radius)

        # 메인 금화
        pygame.draw.circle(coin_surf, gold_main, (cx, cy), radius - 2)

        # 내부 테두리 (입체감)
        pygame.draw.circle(coin_surf, gold_dark, (cx, cy), radius - 3, 1)

        # 상단 하이라이트 (반원)
        highlight_rect = (cx - radius + 4, cy - radius + 3, (radius - 4) * 2, radius - 2)
        pygame.draw.arc(coin_surf, gold_light, highlight_rect, 0.5, 2.6, 2)

        # 중앙에 별 무늬
        star_size = radius // 2
        star_points = []
        for i in range(5):
            # 바깥 점
            angle = math.pi / 2 + i * 2 * math.pi / 5
            px = cx + int(star_size * math.cos(angle))
            py = cy - int(star_size * math.sin(angle))
            star_points.append((px, py))
            # 안쪽 점
            angle += math.pi / 5
            px = cx + int(star_size * 0.4 * math.cos(angle))
            py = cy - int(star_size * 0.4 * math.sin(angle))
            star_points.append((px, py))

        if len(star_points) >= 3:
            pygame.draw.polygon(coin_surf, gold_dark, star_points)
            # 별 하이라이트
            inner_star = [(int(cx + (p[0] - cx) * 0.7), int(cy + (p[1] - cy) * 0.7)) for p in star_points]
            if len(inner_star) >= 3:
                pygame.draw.polygon(coin_surf, gold_light, inner_star)

        # 반짝임 효과 (우상단)
        pygame.draw.circle(coin_surf, gold_shine, (cx + radius // 3, cy - radius // 3), 2)

        screen.blit(coin_surf, (x - size // 2, y - size // 2))

    def _draw_fire_icon(self, screen, x, y, size, intensity=1.0):
        """불꽃 아이콘 그리기 - 연승 표시용"""
        fire_surf = pygame.Surface((size + 4, size + 8), pygame.SRCALPHA)

        cx = size // 2 + 2
        base_y = size + 4

        # 애니메이션 효과 (펄스)
        pulse = (math.sin(self.animation_timer * 5) + 1) / 2 * 0.2 + 0.9

        # 색상 정의 (intensity에 따라 조절)
        if intensity >= 1.5:  # 3연승 이상
            orange_dark = (200, 60, 0)
            orange_main = (255, 100, 20)
            yellow = (255, 180, 50)
            yellow_light = (255, 230, 100)
        else:
            orange_dark = (200, 100, 20)
            orange_main = (255, 150, 50)
            yellow = (255, 200, 80)
            yellow_light = (255, 235, 150)

        # 외곽 불꽃 (큰 불꽃)
        flame_points = [
            (cx, int(base_y - size * 1.1 * pulse)),  # 꼭대기
            (cx + size // 3, int(base_y - size * 0.6)),  # 오른쪽 위
            (cx + size // 2, base_y - size // 4),  # 오른쪽 중간
            (cx + size // 3, base_y),  # 오른쪽 아래
            (cx, base_y - size // 6),  # 중앙 아래 (오목)
            (cx - size // 3, base_y),  # 왼쪽 아래
            (cx - size // 2, base_y - size // 4),  # 왼쪽 중간
            (cx - size // 3, int(base_y - size * 0.6)),  # 왼쪽 위
        ]
        pygame.draw.polygon(fire_surf, orange_dark, flame_points)

        # 중간 불꽃
        inner_scale = 0.7
        inner_points = [
            (cx, int(base_y - size * 0.9 * pulse)),
            (cx + int(size // 3 * inner_scale), int(base_y - size * 0.5)),
            (cx + int(size // 2.5 * inner_scale), base_y - size // 5),
            (cx + int(size // 4 * inner_scale), base_y - 2),
            (cx, base_y - size // 5),
            (cx - int(size // 4 * inner_scale), base_y - 2),
            (cx - int(size // 2.5 * inner_scale), base_y - size // 5),
            (cx - int(size // 3 * inner_scale), int(base_y - size * 0.5)),
        ]
        pygame.draw.polygon(fire_surf, orange_main, inner_points)

        # 내부 불꽃 (노란색)
        core_scale = 0.45
        core_points = [
            (cx, int(base_y - size * 0.7 * pulse)),
            (cx + int(size // 4 * core_scale), int(base_y - size * 0.4)),
            (cx + int(size // 3 * core_scale), base_y - size // 6),
            (cx, base_y - 3),
            (cx - int(size // 3 * core_scale), base_y - size // 6),
            (cx - int(size // 4 * core_scale), int(base_y - size * 0.4)),
        ]
        pygame.draw.polygon(fire_surf, yellow, core_points)

        # 중심 하이라이트
        highlight_points = [
            (cx, int(base_y - size * 0.5 * pulse)),
            (cx + size // 8, base_y - size // 4),
            (cx, base_y - 4),
            (cx - size // 8, base_y - size // 4),
        ]
        pygame.draw.polygon(fire_surf, yellow_light, highlight_points)

        screen.blit(fire_surf, (x - size // 2 - 2, y - size // 2 - 4))

    def _draw_status_badge(self, screen, x, y, text):
        """상태 배지"""
        # 텍스트 크기 계산
        padding = 15
        text_w = len(text) * 10 + padding * 2
        box_h = 28

        box_x = x - text_w

        # 배경
        pygame.draw.rect(screen, (40, 35, 55), (box_x, y, text_w, box_h), border_radius=4)
        pygame.draw.rect(screen, self.BLUE, (box_x, y, text_w, box_h), 2, border_radius=4)

        # 텍스트
        self._draw_text(screen, text, box_x + text_w // 2, y + 5, self.WHITE, 14, center=True)

    def _draw_betting_ui(self, screen):
        """베팅 UI (프리미엄)"""
        cx = self.screen_width // 2
        y = self.screen_height - 95

        # 베팅 박스 (높이 확대)
        box_w, box_h = 340, 80
        box_x = cx - box_w // 2

        # 그림자
        pygame.draw.rect(screen, (0, 0, 0, 80), (box_x + 4, y + 4, box_w, box_h), border_radius=12)

        # 배경 그라데이션
        for i in range(box_h):
            ratio = i / box_h
            r = int(35 + ratio * 15)
            g = int(30 + ratio * 12)
            b = int(50 + ratio * 15)
            pygame.draw.line(screen, (r, g, b), (box_x, y + i), (box_x + box_w, y + i))

        # 단순 골드 테두리
        pygame.draw.rect(screen, self.GOLD, (box_x, y, box_w, box_h), 2, border_radius=12)

        # 베팅 금액 표시
        self._draw_text(screen, "베팅 금액", cx, y + 8, self.SILVER, 12, center=True)

        # 금액과 화살표
        arrow_y = y + 38

        # 왼쪽 화살표
        pygame.draw.polygon(screen, self.GOLD, [
            (cx - 100, arrow_y),
            (cx - 85, arrow_y - 10),
            (cx - 85, arrow_y + 10)
        ])

        # 금액 + 골드 코인 아이콘
        bet_text = f"{self.bet_amount:,}"
        self._draw_text(screen, bet_text, cx - 12, y + 30, self.GOLD_LIGHT, 24, center=True)
        # 숫자 길이에 따라 아이콘 위치 조정 (숫자에서 적당히 떨어진 위치)
        text_half_width = len(bet_text) * 7  # 24pt 폰트 기준 대략적 반너비
        self._draw_gold_coin(screen, cx - 12 + text_half_width + 12, y + 40, 16)

        # 오른쪽 화살표
        pygame.draw.polygon(screen, self.GOLD, [
            (cx + 100, arrow_y),
            (cx + 85, arrow_y - 10),
            (cx + 85, arrow_y + 10)
        ])

        # 조작법 (박스 안에 들어오도록)
        self._draw_text(screen, "◀▶/휠:±10 ▲▼:±50 Space/클릭:확인 ESC:나가기",
                       cx, y + 62, (120, 120, 130), 10, center=True)

    def _draw_scroll_icon(self, screen):
        """족보 스크롤 아이콘 그리기 (고급 붉은 융단 파피루스 스타일)"""
        cx = self.screen_width // 2
        icon_x = cx + 230  # 더 오른쪽으로
        icon_y = self.screen_height - 65
        icon_size = 50

        # 애니메이션 업데이트
        self.scroll_icon_animation += 0.03
        bounce = math.sin(self.scroll_icon_animation * 1.5) * 2
        glow_pulse = 0.7 + 0.3 * math.sin(self.scroll_icon_animation * 2)

        # 클릭 영역 저장
        self.scroll_icon_rect = pygame.Rect(icon_x - icon_size//2, int(icon_y - icon_size//2 + bounce),
                                            icon_size, icon_size + 10)

        # 신비로운 외부 글로우 (다중 레이어)
        for i in range(3, 0, -1):
            glow_surf = pygame.Surface((icon_size + 30 + i*10, icon_size + 30 + i*10), pygame.SRCALPHA)
            glow_alpha = int(40 * glow_pulse * (4-i) / 3)
            # 붉은색 + 금색 혼합 글로우
            pygame.draw.ellipse(glow_surf, (180, 80, 40, glow_alpha),
                              (0, 0, icon_size + 30 + i*10, icon_size + 30 + i*10))
            screen.blit(glow_surf, (icon_x - icon_size//2 - 15 - i*5,
                                   int(icon_y - icon_size//2 + bounce - 15 - i*5)))

        # 스크롤 본체 서피스
        scroll_surf = pygame.Surface((40, 50), pygame.SRCALPHA)

        # 붉은 융단 배경 그라데이션
        for i in range(50):
            ratio = i / 50
            # 깊은 와인레드 → 진홍색 그라데이션
            r = int(120 + ratio * 30 - abs(ratio - 0.5) * 40)
            g = int(25 + ratio * 15)
            b = int(35 + ratio * 15)
            pygame.draw.line(scroll_surf, (r, g, b), (3, i), (37, i))

        # 파피루스 질감 효과 (노이즈)
        for _ in range(30):
            nx = random.randint(5, 35)
            ny = random.randint(5, 45)
            noise_alpha = random.randint(10, 30)
            pygame.draw.circle(scroll_surf, (200, 180, 150, noise_alpha), (nx, ny), 1)

        # 금색 테두리
        pygame.draw.rect(scroll_surf, (200, 160, 60), (2, 2, 36, 46), 2, border_radius=4)
        pygame.draw.rect(scroll_surf, (255, 200, 80), (3, 3, 34, 44), 1, border_radius=3)

        # 상단 스크롤 롤 (말린 부분) - 골드 장식
        roll_color_dark = (140, 100, 40)
        roll_color_light = (220, 180, 80)
        roll_color_highlight = (255, 230, 150)

        # 상단 롤
        pygame.draw.ellipse(scroll_surf, roll_color_dark, (0, -2, 40, 10))
        pygame.draw.ellipse(scroll_surf, roll_color_light, (2, 0, 36, 7))
        pygame.draw.ellipse(scroll_surf, roll_color_highlight, (8, 1, 24, 4))

        # 하단 롤
        pygame.draw.ellipse(scroll_surf, roll_color_dark, (0, 44, 40, 10))
        pygame.draw.ellipse(scroll_surf, roll_color_light, (2, 45, 36, 7))
        pygame.draw.ellipse(scroll_surf, roll_color_highlight, (8, 46, 24, 4))

        # 중앙 카드 문양 (스페이드)
        spade_color = (255, 215, 100)
        # 스페이드 심볼
        pygame.draw.polygon(scroll_surf, spade_color, [
            (20, 15), (14, 24), (17, 24), (17, 28), (23, 28), (23, 24), (26, 24)
        ])
        pygame.draw.circle(scroll_surf, spade_color, (16, 22), 4)
        pygame.draw.circle(scroll_surf, spade_color, (24, 22), 4)

        # 장식 라인
        pygame.draw.line(scroll_surf, (255, 200, 100), (8, 33), (32, 33), 1)
        pygame.draw.line(scroll_surf, (255, 200, 100), (10, 37), (30, 37), 1)
        pygame.draw.line(scroll_surf, (255, 200, 100), (12, 41), (28, 41), 1)

        # 스크롤 그리기
        screen.blit(scroll_surf, (icon_x - 20, int(icon_y - 25 + bounce)))

        # 반짝임 효과
        if int(self.scroll_icon_animation * 10) % 20 < 3:
            sparkle_surf = pygame.Surface((8, 8), pygame.SRCALPHA)
            pygame.draw.polygon(sparkle_surf, (255, 255, 200, 200), [
                (4, 0), (5, 3), (8, 4), (5, 5), (4, 8), (3, 5), (0, 4), (3, 3)
            ])
            screen.blit(sparkle_surf, (icon_x + 10, int(icon_y - 20 + bounce)))

        # "족보" 라벨 (금색 그림자)
        self._draw_text(screen, "족보", icon_x + 1, int(icon_y + 32 + bounce + 1), (80, 40, 20), 11, center=True)
        self._draw_text(screen, "족보", icon_x, int(icon_y + 32 + bounce), (255, 200, 100), 11, center=True)

    def _draw_hand_rankings_panel(self, screen):
        """족보 패널 그리기 (고급 붉은 융단 파피루스 스타일)"""
        if self.hand_rankings_scroll <= 0:
            return

        # 현재 플레이어 족보 계산
        current_hand_rank = 0
        if self.game and self.game.community_cards:
            player = self.game.players.get('south')
            if player and player.hand:
                all_cards = player.hand + self.game.community_cards
                hand_result = HandEvaluator.evaluate(all_cards)
                current_hand_rank = hand_result[0]

        # 패널 크기 및 위치 (더 오른쪽으로)
        panel_width = 240
        panel_height = 360
        panel_x = self.screen_width - panel_width - 5  # 더 오른쪽으로
        panel_y_base = self.screen_height - 80

        # 스크롤 애니메이션 적용 (아래에서 위로 올라옴)
        scroll_offset = (1 - self.hand_rankings_scroll) * panel_height
        panel_y = int(panel_y_base - panel_height + scroll_offset)

        # 클리핑 영역 설정
        clip_rect = pygame.Rect(panel_x - 15, panel_y_base - panel_height - 20,
                                panel_width + 30, panel_height + 40)
        screen.set_clip(clip_rect)

        # === 외부 글로우 효과 (신비로운 빛) ===
        glow_pulse = 0.7 + 0.3 * math.sin(self.scroll_icon_animation * 1.5)
        for i in range(4, 0, -1):
            glow_surf = pygame.Surface((panel_width + i*15, panel_height + i*15), pygame.SRCALPHA)
            glow_alpha = int(25 * glow_pulse * (5-i) / 4)
            pygame.draw.rect(glow_surf, (150, 50, 30, glow_alpha),
                           (0, 0, panel_width + i*15, panel_height + i*15), border_radius=15)
            screen.blit(glow_surf, (panel_x - i*7, panel_y - i*7))

        # === 메인 패널 배경 (붉은 융단 그라데이션) ===
        for i in range(panel_height):
            ratio = i / panel_height
            # 깊은 와인레드 그라데이션 (상단 밝음 → 하단 어두움)
            brightness = 1.0 - ratio * 0.3
            edge_dark = abs(ratio - 0.5) * 0.2  # 가장자리 약간 어둡게
            r = int((100 + ratio * 40) * brightness - edge_dark * 30)
            g = int((20 + ratio * 15) * brightness)
            b = int((30 + ratio * 20) * brightness)
            pygame.draw.line(screen, (max(0,r), max(0,g), max(0,b)),
                           (panel_x, panel_y + i), (panel_x + panel_width, panel_y + i))

        # === 파피루스 질감 오버레이 ===
        texture_surf = pygame.Surface((panel_width, panel_height), pygame.SRCALPHA)
        for _ in range(80):
            tx = random.randint(5, panel_width - 5)
            ty = random.randint(5, panel_height - 5)
            t_alpha = random.randint(5, 20)
            t_size = random.randint(1, 3)
            pygame.draw.circle(texture_surf, (200, 180, 150, t_alpha), (tx, ty), t_size)
        screen.blit(texture_surf, (panel_x, panel_y))

        # === 화려한 금색 테두리 (다중 레이어) ===
        # 외부 어두운 테두리
        pygame.draw.rect(screen, (100, 70, 30), (panel_x - 3, panel_y - 3,
                        panel_width + 6, panel_height + 6), 4, border_radius=12)
        # 메인 금색 테두리
        pygame.draw.rect(screen, (200, 160, 60), (panel_x - 1, panel_y - 1,
                        panel_width + 2, panel_height + 2), 3, border_radius=10)
        # 내부 밝은 금색 하이라이트
        pygame.draw.rect(screen, (255, 220, 120), (panel_x + 1, panel_y + 1,
                        panel_width - 2, panel_height - 2), 1, border_radius=8)

        # === 코너 장식 (금색 문양) ===
        corner_size = 20
        corner_color = (255, 200, 80)
        corners = [
            (panel_x + 5, panel_y + 5),  # 좌상단
            (panel_x + panel_width - 25, panel_y + 5),  # 우상단
            (panel_x + 5, panel_y + panel_height - 25),  # 좌하단
            (panel_x + panel_width - 25, panel_y + panel_height - 25),  # 우하단
        ]
        for cx, cy in corners:
            pygame.draw.line(screen, corner_color, (cx, cy + 8), (cx + 8, cy), 2)
            pygame.draw.line(screen, corner_color, (cx + corner_size - 8, cy),
                           (cx + corner_size, cy + 8), 2)

        # === 제목 영역 ===
        title_y = panel_y + 12
        # 제목 배경 (어두운 붉은색)
        title_bg = pygame.Surface((panel_width - 30, 35), pygame.SRCALPHA)
        for i in range(35):
            ratio = i / 35
            r = int(60 + ratio * 20)
            g = int(15 + ratio * 10)
            b = int(25 + ratio * 10)
            pygame.draw.line(title_bg, (r, g, b, 230), (0, i), (panel_width - 30, i))
        screen.blit(title_bg, (panel_x + 15, title_y - 2))

        # 제목 테두리
        pygame.draw.rect(screen, (200, 160, 60), (panel_x + 15, title_y - 2,
                        panel_width - 30, 35), 2, border_radius=5)

        # 제목 텍스트 (카드 문양 포함)
        self._draw_text(screen, "♠ 포커 족보 ♥", panel_x + panel_width // 2,
                       title_y + 6, (255, 215, 100), 16, center=True)

        # === 족보 목록 ===
        item_y = panel_y + 58
        item_height = 28
        self.hand_ranking_rects = {}  # 매 프레임 초기화

        for rank, name, color in self.HAND_RANKINGS_LIST:
            is_current = (rank == current_hand_rank)
            is_hovered = (rank == self.hovered_hand_rank)

            # 항목 영역 저장 (툴팁용)
            item_rect = pygame.Rect(panel_x + 12, item_y - 2, panel_width - 24, item_height + 2)
            self.hand_ranking_rects[rank] = item_rect

            # 호버 효과 (현재 족보가 아닐 때)
            if is_hovered and not is_current:
                hover_surf = pygame.Surface((panel_width - 24, item_height + 2), pygame.SRCALPHA)
                for hi in range(item_height + 2):
                    h_ratio = hi / (item_height + 2)
                    h_alpha = int(40 - abs(h_ratio - 0.5) * 30)
                    pygame.draw.line(hover_surf, (200, 180, 150, h_alpha),
                                   (0, hi), (panel_width - 24, hi))
                screen.blit(hover_surf, (panel_x + 12, item_y - 2))
                # 호버 테두리 (밝은 갈색)
                pygame.draw.rect(screen, (180, 150, 100),
                               (panel_x + 12, item_y - 2, panel_width - 24, item_height + 2), 1, border_radius=5)

            if is_current:
                # 현재 족보 하이라이트 (황금빛 배경)
                highlight_surf = pygame.Surface((panel_width - 24, item_height + 2), pygame.SRCALPHA)
                for hi in range(item_height + 2):
                    h_ratio = hi / (item_height + 2)
                    h_alpha = int(80 - abs(h_ratio - 0.5) * 60)
                    pygame.draw.line(highlight_surf, (255, 200, 50, h_alpha),
                                   (0, hi), (panel_width - 24, hi))
                screen.blit(highlight_surf, (panel_x + 12, item_y - 2))

                # 하이라이트 테두리 (금색)
                pygame.draw.rect(screen, (255, 200, 80),
                               (panel_x + 12, item_y - 2, panel_width - 24, item_height + 2), 2, border_radius=5)

                # 화살표 마커
                arrow_x = panel_x + 20
                arrow_cy = item_y + item_height // 2
                pygame.draw.polygon(screen, (255, 215, 100), [
                    (arrow_x, arrow_cy - 6),
                    (arrow_x + 10, arrow_cy),
                    (arrow_x, arrow_cy + 6)
                ])

            # 텍스트 색상
            if is_current:
                rank_color = (255, 230, 150)
                name_color = color
            elif is_hovered:
                rank_color = (220, 200, 170)
                name_color = (240, 220, 200)
            else:
                rank_color = (180, 160, 140)
                name_color = (200, 180, 160)

            # 순위 번호와 족보 이름
            font_size = 13 if is_current else 11
            self._draw_text(screen, f"{rank}.", panel_x + 38, item_y + 4, rank_color, font_size)
            self._draw_text(screen, name, panel_x + 60, item_y + 4, name_color, font_size)

            # 현재 족보 옆에 표시
            if is_current:
                self._draw_text(screen, "← 현재", panel_x + 130, item_y + 5, (255, 220, 100), 9)

            # 구분선 (희미한 금색)
            if rank > 1:
                pygame.draw.line(screen, (120, 90, 50, 100),
                               (panel_x + 30, item_y + item_height + 1),
                               (panel_x + panel_width - 30, item_y + item_height + 1), 1)

            item_y += item_height

        # 클리핑 해제
        screen.set_clip(None)

        # 툴팁 그리기 (클리핑 해제 후)
        if self.hovered_hand_rank and self.hovered_hand_rank in self.HAND_RANKING_EXAMPLES:
            self._draw_hand_ranking_tooltip(screen, self.hovered_hand_rank)

    def _draw_hand_ranking_tooltip(self, screen, rank):
        """족보 툴팁 그리기 - 예시 카드와 설명"""
        if rank not in self.HAND_RANKING_EXAMPLES:
            return

        example = self.HAND_RANKING_EXAMPLES[rank]
        cards = example["cards"]
        desc = example["desc"]

        # 족보 이름 가져오기
        rank_name = ""
        rank_color = (255, 255, 255)
        for r, name, color in self.HAND_RANKINGS_LIST:
            if r == rank:
                rank_name = name
                rank_color = color
                break

        # 툴팁 크기 및 위치 (족보 패널 왼쪽에 표시)
        tooltip_width = 200
        tooltip_height = 140
        panel_width = 240
        panel_x = self.screen_width - panel_width - 5

        # 호버된 항목 위치 기준으로 툴팁 위치 결정
        if rank in self.hand_ranking_rects:
            item_rect = self.hand_ranking_rects[rank]
            tooltip_x = panel_x - tooltip_width - 15
            tooltip_y = item_rect.centery - tooltip_height // 2

            # 화면 경계 체크
            if tooltip_y < 10:
                tooltip_y = 10
            if tooltip_y + tooltip_height > self.screen_height - 10:
                tooltip_y = self.screen_height - tooltip_height - 10
        else:
            return

        # === 툴팁 배경 (고급 스타일) ===
        tooltip_surf = pygame.Surface((tooltip_width, tooltip_height), pygame.SRCALPHA)

        # 그라데이션 배경 (어두운 녹색/파랑 계열 - 카지노 테이블 느낌)
        for i in range(tooltip_height):
            ratio = i / tooltip_height
            r = int(25 + ratio * 15)
            g = int(40 + ratio * 20)
            b = int(35 + ratio * 15)
            pygame.draw.line(tooltip_surf, (r, g, b, 240), (0, i), (tooltip_width, i))

        screen.blit(tooltip_surf, (tooltip_x, tooltip_y))

        # 외부 글로우
        glow_surf = pygame.Surface((tooltip_width + 10, tooltip_height + 10), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (100, 150, 120, 40), (0, 0, tooltip_width + 10, tooltip_height + 10), border_radius=12)
        screen.blit(glow_surf, (tooltip_x - 5, tooltip_y - 5))

        # 테두리 (금색)
        pygame.draw.rect(screen, (180, 150, 80), (tooltip_x, tooltip_y, tooltip_width, tooltip_height), 2, border_radius=8)
        pygame.draw.rect(screen, (220, 190, 100), (tooltip_x + 1, tooltip_y + 1, tooltip_width - 2, tooltip_height - 2), 1, border_radius=7)

        # === 족보 이름 ===
        self._draw_text(screen, rank_name, tooltip_x + tooltip_width // 2, tooltip_y + 8, rank_color, 14, center=True)

        # 구분선
        pygame.draw.line(screen, (120, 100, 60), (tooltip_x + 15, tooltip_y + 28), (tooltip_x + tooltip_width - 15, tooltip_y + 28), 1)

        # === 예시 카드 그리기 ===
        card_width = 30
        card_height = 42
        cards_total_width = len(cards) * (card_width + 4) - 4
        card_start_x = tooltip_x + (tooltip_width - cards_total_width) // 2
        card_y = tooltip_y + 35

        # 문양 색상
        suit_colors = {'s': (30, 30, 30), 'h': (200, 50, 50), 'd': (200, 50, 50), 'c': (30, 30, 30)}

        for i, (value, suit) in enumerate(cards):
            cx = card_start_x + i * (card_width + 4)

            # 카드 배경 (흰색)
            pygame.draw.rect(screen, (250, 248, 240), (cx, card_y, card_width, card_height), border_radius=3)
            pygame.draw.rect(screen, (100, 100, 100), (cx, card_y, card_width, card_height), 1, border_radius=3)

            # 숫자/문자
            suit_color = suit_colors.get(suit, (30, 30, 30))
            # 값 표시 (좌상단)
            self._draw_text(screen, value, cx + 5, card_y + 3, suit_color, 9)

            # 문양 기호 (중앙) - 직접 도형으로 그리기
            sym_cx = cx + card_width // 2
            sym_cy = card_y + card_height // 2 + 2
            sym_size = 7

            if suit == 's':  # 스페이드 ♠
                # 위쪽 뾰족한 부분 (하트 뒤집은 모양)
                pygame.draw.polygon(screen, suit_color, [
                    (sym_cx, sym_cy - sym_size),
                    (sym_cx - sym_size, sym_cy + 2),
                    (sym_cx + sym_size, sym_cy + 2)
                ])
                pygame.draw.circle(screen, suit_color, (sym_cx - 4, sym_cy + 1), 4)
                pygame.draw.circle(screen, suit_color, (sym_cx + 4, sym_cy + 1), 4)
                # 아래 기둥
                pygame.draw.polygon(screen, suit_color, [
                    (sym_cx - 2, sym_cy + 3),
                    (sym_cx + 2, sym_cy + 3),
                    (sym_cx + 3, sym_cy + sym_size),
                    (sym_cx - 3, sym_cy + sym_size)
                ])
            elif suit == 'h':  # 하트 ♥
                # 두 개의 원 (상단)
                pygame.draw.circle(screen, suit_color, (sym_cx - 4, sym_cy - 3), 5)
                pygame.draw.circle(screen, suit_color, (sym_cx + 4, sym_cy - 3), 5)
                # 아래 뾰족한 부분
                pygame.draw.polygon(screen, suit_color, [
                    (sym_cx - 8, sym_cy - 2),
                    (sym_cx + 8, sym_cy - 2),
                    (sym_cx, sym_cy + sym_size)
                ])
            elif suit == 'd':  # 다이아 ♦
                # 마름모 형태
                pygame.draw.polygon(screen, suit_color, [
                    (sym_cx, sym_cy - sym_size),      # 상단
                    (sym_cx + sym_size - 1, sym_cy),  # 우측
                    (sym_cx, sym_cy + sym_size),      # 하단
                    (sym_cx - sym_size + 1, sym_cy)   # 좌측
                ])
            elif suit == 'c':  # 클로버 ♣
                # 세 개의 원
                pygame.draw.circle(screen, suit_color, (sym_cx, sym_cy - 4), 4)
                pygame.draw.circle(screen, suit_color, (sym_cx - 5, sym_cy + 1), 4)
                pygame.draw.circle(screen, suit_color, (sym_cx + 5, sym_cy + 1), 4)
                # 아래 기둥
                pygame.draw.polygon(screen, suit_color, [
                    (sym_cx - 2, sym_cy + 2),
                    (sym_cx + 2, sym_cy + 2),
                    (sym_cx + 3, sym_cy + sym_size),
                    (sym_cx - 3, sym_cy + sym_size)
                ])

        # === 설명 텍스트 ===
        desc_y = card_y + card_height + 10
        desc_lines = desc.split('\n')
        for line in desc_lines:
            self._draw_text(screen, line, tooltip_x + tooltip_width // 2, desc_y, (200, 200, 180), 10, center=True)
            desc_y += 18

        # 연결선 (툴팁과 항목 사이)
        if rank in self.hand_ranking_rects:
            item_rect = self.hand_ranking_rects[rank]
            line_start = (tooltip_x + tooltip_width, tooltip_y + tooltip_height // 2)
            line_end = (item_rect.left, item_rect.centery)
            pygame.draw.line(screen, (150, 130, 80, 150), line_start, line_end, 1)

    def _update_hand_rankings_scroll(self, dt):
        """족보 패널 스크롤 애니메이션 업데이트"""
        scroll_speed = 5.0  # 애니메이션 속도

        if self.show_hand_rankings:
            self.hand_rankings_target = 1.0
        else:
            self.hand_rankings_target = 0.0

        # 부드러운 애니메이션
        diff = self.hand_rankings_target - self.hand_rankings_scroll
        self.hand_rankings_scroll += diff * scroll_speed * dt

        # 정밀도 보정
        if abs(diff) < 0.01:
            self.hand_rankings_scroll = self.hand_rankings_target

    def toggle_hand_rankings(self):
        """족보 패널 토글"""
        self.show_hand_rankings = not self.show_hand_rankings

    def handle_scroll_icon_click(self, pos):
        """스크롤 아이콘 클릭 처리"""
        if self.scroll_icon_rect and self.scroll_icon_rect.collidepoint(pos):
            self.toggle_hand_rankings()
            return True
        return False

    def _draw_dealing_ui(self, screen):
        """딜링 중 UI"""
        cx = self.screen_width // 2
        y = self.screen_height - 60

        # 로딩 표시
        dots = "." * (int(self.animation_timer * 3) % 4)
        self._draw_text(screen, f"딜링 중{dots}", cx, y, self.SILVER, 16, center=True)

    def _draw_action_ui(self, screen):
        """액션 UI (프리미엄) - 마우스 호버/클릭 지원"""
        cx = self.screen_width // 2
        y = self.screen_height - 85

        # 관전자 모드일 때 액션 버튼 숨기고 관전 중 표시
        if self.game.spectator_mode:
            self.action_buttons = []  # 버튼 비활성화
            # 관전 중 표시
            self._draw_text(screen, "👁 관전 중...", cx, y + 10, (150, 150, 180), 16, center=True)
            self._draw_text(screen, "ESC: 나가기", cx, y + 35, (100, 100, 110), 10, center=True)
            return

        # 콜 금액 계산
        call_amount = self.game.get_call_amount()

        # 콜 버튼 텍스트 (콜 금액 표시)
        if call_amount > 0:
            call_text = f"콜 {call_amount}G"
            call_show_gold = True
        else:
            call_text = "체크"  # 딜러가 체크했으면 플레이어도 체크
            call_show_gold = False

        # NPC 레이즈에 대한 응답 중이면 콜/폴드만 표시
        if self.game.waiting_for_player_response:
            actions = [
                (call_text, (80, 180, 100), (100, 220, 120), call_show_gold),
                ("폴드", (180, 80, 80), (220, 100, 100), False)
            ]
        else:
            actions = [
                (call_text, (80, 180, 100), (100, 220, 120), call_show_gold),
                (f"레이즈 +{self.raise_amount}", (200, 170, 60), (240, 200, 80), True),  # 골드 아이콘 표시
                ("폴드", (180, 80, 80), (220, 100, 100), False)
            ]

        btn_w, btn_h = 110, 50
        total_w = len(actions) * btn_w + (len(actions) - 1) * 15
        start_x = cx - total_w // 2

        # 버튼 영역 저장 (마우스 처리용)
        self.action_buttons = []

        for i, (action, color, color_light, show_gold_icon) in enumerate(actions):
            btn_x = start_x + i * (btn_w + 15)

            # 버튼 영역 저장
            btn_rect = pygame.Rect(btn_x, y, btn_w, btn_h)
            self.action_buttons.append(btn_rect)

            # 선택 또는 호버 여부
            is_selected = (i == self.selected_action)
            is_hovered = (i == self.hovered_action)

            # NPC 차례이거나 콜 금액이 플레이어 골드보다 크면 비활성화
            # NPC 생각 중, 액션 표시 중, 또는 NPC 큐에 대기 중이면 플레이어 차례 아님
            is_npc_turn = (self.game.npc_thinking and self.game.npc_thinking_player) or \
                          self.game.npc_action_display or \
                          self.game.npc_turn_queue or \
                          self.game.betting_round_complete
            is_disabled = is_npc_turn or (i == 0 and call_amount > self.game.players['south'].gold)

            # 그림자
            pygame.draw.rect(screen, (0, 0, 0, 80), (btn_x + 3, y + 3, btn_w, btn_h), border_radius=8)

            if is_disabled:
                # 비활성화 버튼
                pygame.draw.rect(screen, (50, 50, 55), (btn_x, y, btn_w, btn_h), border_radius=8)
                pygame.draw.rect(screen, (80, 80, 90), (btn_x, y, btn_w, btn_h), 2, border_radius=8)
                text_color = (100, 100, 110)
            elif is_selected:
                # 선택된 버튼 (글로우 효과)
                pygame.draw.rect(screen, (*color_light, 50), (btn_x - 4, y - 4, btn_w + 8, btn_h + 8), border_radius=10)
                pygame.draw.rect(screen, color_light, (btn_x, y, btn_w, btn_h), border_radius=8)
                pygame.draw.rect(screen, self.WHITE, (btn_x, y, btn_w, btn_h), 2, border_radius=8)
                text_color = self.WHITE
            elif is_hovered:
                # 호버 효과 (선택보다 약간 연한 효과)
                hover_color = tuple(min(255, c + 30) for c in color)
                pygame.draw.rect(screen, (*color, 30), (btn_x - 2, y - 2, btn_w + 4, btn_h + 4), border_radius=9)
                pygame.draw.rect(screen, hover_color, (btn_x, y, btn_w, btn_h), border_radius=8)
                pygame.draw.rect(screen, color_light, (btn_x, y, btn_w, btn_h), 2, border_radius=8)
                text_color = self.WHITE
            else:
                pygame.draw.rect(screen, (40, 35, 50), (btn_x, y, btn_w, btn_h), border_radius=8)
                pygame.draw.rect(screen, color, (btn_x, y, btn_w, btn_h), 2, border_radius=8)
                text_color = (150, 150, 160)

            # 텍스트와 골드 아이콘 그리기
            if show_gold_icon:
                # 버튼: 텍스트 + 골드 코인 아이콘
                text_x = btn_x + btn_w // 2 - 8  # 텍스트를 왼쪽으로 약간 이동
                text_y = y + btn_h // 2 - 10
                self._draw_text(screen, action, text_x, text_y, text_color, 14, center=True)
                # 골드 코인 아이콘 (텍스트와 수평 맞춤)
                coin_x = btn_x + btn_w - 18
                coin_y = text_y + 7  # 텍스트 중앙과 수평 맞춤
                self._draw_gold_coin(screen, coin_x, coin_y, 14)
            else:
                self._draw_text(screen, action, btn_x + btn_w // 2, y + btn_h // 2 - 10, text_color, 14, center=True)

        # 레이즈 범위 표시 (NPC 응답 대기 중이면 숨김)
        if not self.game.waiting_for_player_response:
            range_text = f"레이즈: {self.min_raise}~{self.max_raise}G (±{self.raise_step})"
            self._draw_text(screen, range_text, cx, y + 55, (120, 120, 140), 10, center=True)
            # 조작법
            self._draw_text(screen, "◀▶/클릭: 선택  ▲▼/휠: 레이즈 조절  Space: 확인  ESC: 나가기",
                           cx, y + 70, (100, 100, 110), 10, center=True)
        else:
            # NPC 레이즈 응답 시 조작법
            self._draw_text(screen, "◀▶/클릭: 선택  Space: 확인  ESC: 나가기",
                           cx, y + 55, (100, 100, 110), 10, center=True)

    def _draw_showdown_animation_ui(self, screen):
        """쇼다운 애니메이션 UI - 플레이어별 카드 공개 및 족보 하이라이트"""
        cx = self.screen_width // 2
        cy = self.screen_height // 2

        # 현재 쇼다운 중인 플레이어
        current_player = self.game.showdown_current_player

        # 쇼다운 인트로
        if self.game.state == PokerGame.STATE_SHOWDOWN_INTRO:
            # "SHOWDOWN" 텍스트 애니메이션
            progress = min(1.0, self.game.showdown_timer / 0.5)
            scale = 0.5 + progress * 0.5
            alpha = int(255 * progress)

            # 배경 어둡게
            overlay = pygame.Surface((self.screen_width, self.screen_height), pygame.SRCALPHA)
            overlay.fill((0, 0, 0, int(100 * progress)))
            screen.blit(overlay, (0, 0))

            # SHOWDOWN 텍스트
            font_size = int(36 * scale)
            self._draw_text_with_glow(screen, "SHOWDOWN", cx, cy - 50,
                                     (255, 215, 0), font_size, (255, 150, 0, 100))

        # 카드 공개 및 족보 하이라이트 단계
        elif self.game.state in [PokerGame.STATE_SHOWDOWN_REVEAL, PokerGame.STATE_SHOWDOWN_HAND]:
            if current_player:
                # 현재 플레이어 이름 표시
                name = current_player.name
                pos = current_player.position

                # 위치별 표시 좌표
                name_positions = {
                    'south': (cx, self.screen_height - 180),
                    'north': (cx, 100),
                    'west': (120, cy),
                    'east': (self.screen_width - 120, cy)
                }
                name_x, name_y = name_positions.get(pos, (cx, cy))

                # 플레이어 이름 하이라이트
                self._draw_text_with_glow(screen, name, name_x, name_y - 40,
                                         (0, 255, 255), 18, (0, 200, 255, 80))

                # 족보 하이라이트 단계
                if self.game.state == PokerGame.STATE_SHOWDOWN_HAND:
                    self._draw_hand_highlight_effect(screen, current_player)

        # 파티클 렌더링
        self._draw_showdown_particles(screen)

    def _draw_text_with_glow(self, screen, text, x, y, color, size, glow_color):
        """글로우 효과가 있는 텍스트 그리기"""
        # 글로우
        glow_surf = pygame.Surface((len(text) * size + 40, size + 30), pygame.SRCALPHA)
        for offset in range(3, 0, -1):
            glow_alpha = glow_color[3] // (offset + 1) if len(glow_color) > 3 else 50
            temp_color = (glow_color[0], glow_color[1], glow_color[2], glow_alpha)
            # 간단한 텍스트 렌더링 (실제로는 _draw_text 사용)
        # 메인 텍스트
        self._draw_text(screen, text, x, y, color, size, center=True)

    def _draw_hand_highlight_effect(self, screen, player):
        """족보 하이라이트 이펙트 그리기"""
        if not player or not player.hand_result:
            return

        rank = player.hand_result[0]
        hand_name = player.hand_result[2]
        rank_level = self.game._get_hand_rank_level(rank)

        # 위치별 표시 좌표
        pos = player.position
        cx = self.screen_width // 2

        # 족보 이름 표시 위치
        hand_positions = {
            'south': (cx, self.screen_height - 120),
            'north': (cx, 160),
            'west': (180, self.screen_height // 2 + 30),
            'east': (self.screen_width - 180, self.screen_height // 2 + 30)
        }
        hx, hy = hand_positions.get(pos, (cx, self.screen_height // 2))

        # 족보 등급별 색상 및 효과
        effect_timer = self.game.showdown_hand_effect_timer

        if rank_level >= 9:  # 스트레이트 플러시 이상 - 레인보우
            hue = (effect_timer * 360) % 360
            color = self._hsv_to_rgb(hue, 1.0, 1.0)
            glow_color = (255, 215, 0, 150)
            font_size = 24
        elif rank_level >= 7:  # 풀하우스 이상 - 골드
            color = (255, 215, 0)
            glow_color = (255, 200, 100, 120)
            font_size = 22
        elif rank_level >= 5:  # 스트레이트 이상 - 시안
            color = (0, 255, 255)
            glow_color = (0, 200, 255, 100)
            font_size = 20
        elif rank_level >= 3:  # 투페어 이상 - 그린
            color = (100, 255, 100)
            glow_color = (100, 255, 100, 80)
            font_size = 18
        else:  # 원페어 이하 - 화이트
            color = (220, 220, 220)
            glow_color = (200, 200, 200, 60)
            font_size = 16

        # 펄스 효과
        pulse = 1.0 + 0.1 * math.sin(effect_timer * 6)
        font_size = int(font_size * pulse)

        # 글로우 서피스
        glow_size = font_size + 20
        glow_surf = pygame.Surface((glow_size * len(hand_name) // 2 + 60, glow_size + 20), pygame.SRCALPHA)

        # 글로우 그리기
        for i in range(3):
            alpha = glow_color[3] // (i + 1)
            radius = (3 - i) * 4
            pygame.draw.rect(glow_surf, (glow_color[0], glow_color[1], glow_color[2], alpha),
                           (radius, radius, glow_surf.get_width() - radius * 2, glow_surf.get_height() - radius * 2),
                           border_radius=10)

        screen.blit(glow_surf, (hx - glow_surf.get_width() // 2, hy - glow_surf.get_height() // 2))

        # 족보 이름 텍스트
        self._draw_text(screen, hand_name, hx, hy, color, font_size, center=True)

        # 등급 표시 (스타)
        if rank_level >= 4:
            star_count = min(5, (rank_level - 3))
            star_y = hy + font_size + 5
            star_width = star_count * 20
            start_x = hx - star_width // 2 + 10

            for i in range(star_count):
                sx = start_x + i * 20
                self._draw_star(screen, sx, star_y, 8, (255, 215, 0))

    def _draw_star(self, screen, x, y, size, color):
        """별 그리기"""
        points = []
        for i in range(10):
            angle = math.radians(i * 36 - 90)
            r = size if i % 2 == 0 else size * 0.4
            px = x + r * math.cos(angle)
            py = y + r * math.sin(angle)
            points.append((px, py))
        pygame.draw.polygon(screen, color, points)

    def _draw_showdown_particles(self, screen):
        """쇼다운 파티클 렌더링"""
        for p in self.game.showdown_particles:
            alpha = int(255 * p['life'])
            color = (*p['color'][:3], alpha)

            # 파티클 크기
            size = int(4 * p['life'])
            if size > 0:
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(surf, color, (size, size), size)
                screen.blit(surf, (int(p['x']) - size, int(p['y']) - size))

    def _hsv_to_rgb(self, h, s, v):
        """HSV to RGB 변환"""
        h = h / 360.0
        i = int(h * 6)
        f = (h * 6) - i
        p = v * (1 - s)
        q = v * (1 - f * s)
        t = v * (1 - (1 - f) * s)

        i = i % 6
        if i == 0:
            r, g, b = v, t, p
        elif i == 1:
            r, g, b = q, v, p
        elif i == 2:
            r, g, b = p, v, t
        elif i == 3:
            r, g, b = p, q, v
        elif i == 4:
            r, g, b = t, p, v
        else:
            r, g, b = v, p, q

        return (int(r * 255), int(g * 255), int(b * 255))

    def _draw_result_ui(self, screen):
        """결과 UI (4인 프리미엄)"""
        cx = self.screen_width // 2

        # 모든 NPC 파산 특별 화면
        if self.game.dealer_bankrupt:
            self._draw_dealer_bankrupt_ui(screen)
            return

        # 결과 박스 - 위치를 더 위로 이동하여 플레이어 카드가 보이게
        box_w, box_h = 420, 140
        box_y = self.screen_height // 2 + 60  # 화면 중앙 아래쪽으로 이동

        # 그림자
        pygame.draw.rect(screen, (0, 0, 0, 100), (cx - box_w // 2 + 5, box_y + 5, box_w, box_h), border_radius=15)

        # 결과 색상 (4인용 - 유저 승리 여부)
        player_won = False
        winner_names = []
        if self.game.winners:
            winner_positions = [w['position'] for w in self.game.winners]
            player_won = 'south' in winner_positions
            winner_names = [self.game.players[pos].name for pos in winner_positions]

        if player_won:
            result_color = (80, 220, 100)
            glow_color = (100, 255, 120, 30)
            if len(self.game.winners) > 1:
                title = "SPLIT POT!"
            else:
                title = "VICTORY!"
        elif self.game.human_player.folded:
            result_color = (180, 180, 180)
            glow_color = (150, 150, 150, 30)
            title = "FOLDED"
        else:
            result_color = (220, 80, 80)
            glow_color = (255, 100, 100, 30)
            title = "DEFEAT"

        # 글로우 효과
        glow_surf = pygame.Surface((box_w + 20, box_h + 20), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, glow_color, (0, 0, box_w + 20, box_h + 20), border_radius=18)
        screen.blit(glow_surf, (cx - box_w // 2 - 10, box_y - 10))

        # 배경
        for i in range(box_h):
            ratio = i / box_h
            r = int(25 + ratio * 15)
            g = int(20 + ratio * 12)
            b = int(35 + ratio * 18)
            pygame.draw.line(screen, (r, g, b),
                           (cx - box_w // 2, box_y + i), (cx + box_w // 2, box_y + i))

        pygame.draw.rect(screen, result_color, (cx - box_w // 2, box_y, box_w, box_h), 3, border_radius=15)

        # 결과 타이틀
        self._draw_text(screen, title, cx, box_y + 12, result_color, 28, center=True)

        # 승자 정보
        info_y = box_y + 50
        if winner_names:
            winner_text = "승자: " + ", ".join(winner_names)
            self._draw_text(screen, winner_text, cx, info_y, (255, 255, 200), 14, center=True)

        # 플레이어 패 정보
        human = self.game.human_player
        if hasattr(self.game, 'hand_results') and 'south' in self.game.hand_results:
            hand_name = self.game.hand_results['south'][2]
            self._draw_text(screen, f"나의 패: {hand_name}", cx, info_y + 22, (150, 200, 255), 12, center=True)

        # 골드 변화
        gold_text = f"골드: {human.gold:,}G"
        self._draw_text(screen, gold_text, cx, info_y + 45, self.GOLD_LIGHT, 16, center=True)

        # 계속하기
        if human.gold >= self.game.min_bet:
            self._draw_text(screen, "Enter/클릭: 계속  ESC: 나가기", cx, info_y + 70, (120, 120, 130), 12, center=True)
        else:
            self._draw_text(screen, "골드 부족! ESC: 나가기", cx, info_y + 70, (255, 100, 100), 12, center=True)

    def _draw_dealer_bankrupt_ui(self, screen):
        """모든 NPC 파산 특별 화면 (4인용)"""
        cx = self.screen_width // 2
        cy = self.screen_height // 2

        # 전체 화면 어둡게
        overlay = pygame.Surface((self.screen_width, self.screen_height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        screen.blit(overlay, (0, 0))

        # 결과 박스 (더 크게)
        box_w, box_h = 450, 220
        box_x = cx - box_w // 2
        box_y = cy - box_h // 2

        # 황금색 글로우
        glow_surf = pygame.Surface((box_w + 40, box_h + 40), pygame.SRCALPHA)
        for i in range(20, 0, -2):
            alpha = int(50 * (1 - i / 20))
            pygame.draw.rect(glow_surf, (255, 200, 50, alpha),
                           (20 - i, 20 - i, box_w + i * 2, box_h + i * 2), border_radius=20)
        screen.blit(glow_surf, (box_x - 20, box_y - 20))

        # 배경 (황금 그라데이션)
        for i in range(box_h):
            ratio = i / box_h
            r = int(40 + ratio * 20)
            g = int(35 + ratio * 15)
            b = int(20 + ratio * 10)
            pygame.draw.line(screen, (r, g, b),
                           (box_x, box_y + i), (box_x + box_w, box_y + i))

        pygame.draw.rect(screen, self.GOLD, (box_x, box_y, box_w, box_h), 4, border_radius=15)

        # 타이틀 - 연승 시 양쪽에 불꽃 아이콘
        title_y = box_y + 20
        if self.game.player_win_streak > 0:
            intensity = 1.5 if self.game.player_win_streak >= 3 else 1.0
            # 왼쪽 불꽃
            self._draw_fire_icon(screen, cx - 90, title_y + 5, 20, intensity)
            # 타이틀 텍스트
            self._draw_text(screen, "대승리!", cx, title_y, self.GOLD, 32, center=True)
            # 오른쪽 불꽃
            self._draw_fire_icon(screen, cx + 70, title_y + 5, 20, intensity)
        else:
            self._draw_text(screen, "대승리!", cx, title_y, self.GOLD, 32, center=True)

        # 서브 타이틀
        self._draw_text(screen, "축하합니다! 모든 상대를 파산시켰습니다!", cx, box_y + 65, (255, 255, 200), 16, center=True)

        # 파산한 NPC 목록
        bankrupt_npcs = [p.name for pos, p in self.game.players.items()
                         if pos != 'south' and p.gold <= 0]
        if bankrupt_npcs:
            bankrupt_text = "파산: " + ", ".join(bankrupt_npcs)
            self._draw_text(screen, bankrupt_text, cx, box_y + 100, (200, 200, 200), 14, center=True)

        # 최종 골드 + 골드 코인 아이콘
        gold_amount = self.game.players['south'].gold
        gold_text = f"최종 보유 골드: {gold_amount:,}"
        # 텍스트 그리기 (아이콘 공간 확보를 위해 왼쪽으로)
        self._draw_text(screen, gold_text, cx - 15, box_y + 130, self.GOLD_LIGHT, 18, center=True)
        # 골드 코인 아이콘 (텍스트 오른쪽 끝에서 떨어진 위치)
        # 폰트 크기 18 기준 대략적 문자 너비 계산
        text_pixel_width = len(gold_text) * 10  # 18pt 폰트 기준 대략적 너비
        icon_x = cx - 15 + text_pixel_width // 2 + 12  # 텍스트 끝에서 12px 오른쪽
        self._draw_gold_coin(screen, icon_x, box_y + 138, 16)

        # 안내
        self._draw_text(screen, "테이블이 닫힙니다. ESC를 눌러 나가세요.", cx, box_y + 175, (150, 150, 160), 14, center=True)

    def _get_font(self, size):
        """폰트 가져오기 (캐시 사용)"""
        if size not in self._font_cache:
            try:
                for font_name in ['NanumGothic', 'AppleGothic', 'malgun gothic', 'Arial']:
                    try:
                        self._font_cache[size] = pygame.font.SysFont(font_name, size)
                        break
                    except:
                        continue
                if size not in self._font_cache:
                    self._font_cache[size] = pygame.font.Font(None, size + 10)
            except:
                self._font_cache[size] = pygame.font.Font(None, size + 10)
        return self._font_cache[size]

    def _draw_text(self, screen, text, x, y, color, size, center=False, right=False):
        """텍스트 그리기"""
        if self.fonts:
            if size >= 28:
                font_key = 'large'
            elif size <= 14:
                font_key = 'small'
            else:
                font_key = 'medium'

            font = self.fonts.get(font_key) or self.fonts.get('medium') or self.fonts.get('default')
            if font:
                try:
                    text_surface, text_rect = font.render(text, color)

                    if center:
                        text_rect.centerx = x
                        text_rect.y = y
                    elif right:
                        text_rect.right = x
                        text_rect.y = y
                    else:
                        text_rect.x = x
                        text_rect.y = y

                    screen.blit(text_surface, text_rect)
                    return
                except Exception:
                    pass

        if size not in self._font_cache:
            try:
                for font_name in ['NanumGothic', 'AppleGothic', 'malgun gothic', 'Arial']:
                    try:
                        self._font_cache[size] = pygame.font.SysFont(font_name, size)
                        break
                    except:
                        continue
                if size not in self._font_cache:
                    self._font_cache[size] = pygame.font.Font(None, size + 10)
            except:
                self._font_cache[size] = pygame.font.Font(None, size + 10)

        font = self._font_cache[size]
        text_surface = font.render(text, True, color)
        text_rect = text_surface.get_rect()

        if center:
            text_rect.centerx = x
            text_rect.y = y
        elif right:
            text_rect.right = x
            text_rect.y = y
        else:
            text_rect.x = x
            text_rect.y = y

        screen.blit(text_surface, text_rect)

    def get_player_gold(self):
        return self.game.players['south'].gold if self.game else 0


# ============================================
# 테스트용 메인
# ============================================
if __name__ == "__main__":
    pygame.init()
    pygame.mixer.init()  # 믹서 초기화 (BGM용)
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("텍사스 홀덤 포커 - Premium")
    clock = pygame.time.Clock()

    ui = PokerGameUI(800, 600)
    ui.start_game(1000)

    running = True
    while running:
        dt = clock.tick(60) / 1000.0

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                # BGM 정지 후 종료
                if ui.bgm:
                    ui.bgm.stop()
                running = False
            elif event.type == pygame.USEREVENT + 100:
                # BGM 종료 이벤트 - 다음 곡 재생
                if ui.bgm:
                    ui.bgm.handle_music_end_event(event)
            else:
                result = ui.handle_event(event)
                if result == 'exit':
                    running = False

        ui.update(dt)
        ui.draw(screen)
        pygame.display.flip()

    pygame.quit()
