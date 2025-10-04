"""
😈 Devil's Dice Active Item
악마의 주사위 - 6가지 랜덤 효과를 발동하는 액티브 아이템
지속시간: 30초 (다음 라운드 유지, 스테이지 전환시 종료)
"""

import pygame
import random
import math
from typing import Dict, Any

from resource_path import resource_path


class DevilDice:
    """악마의 주사위 액티브 아이템"""
    
    def __init__(self):
        """초기화"""
        # 효과 상태
        self.active = False
        self.duration = 1800  # 30초 (60 FPS * 30)
        self.time_remaining = 0
        self.current_stage = -1  # 효과가 시작된 스테이지
        
        # 주사위 결과 (1-3 범위의 값)
        self.dice_results = {
            'paddle_size': 2,      # 1: 50% 감소, 2: 변화없음, 3: 50% 증가
            'skill_gauge': 2,      # 1: 50% 감소, 2: 변화없음, 3: 50% 증가
            'item_spawn': 2,       # 1: 50% 감소, 2: 변화없음, 3: 50% 증가
            'item_cooldown': 2,  # 1: 50% 감소, 2: 변화없음, 3: 50% 증가
            'skill_dash_cost': 2,  # 1: 50% 감소, 2: 변화없음, 3: 50% 증가
            'dash_cooldown': 2,    # 1: 50% 감소, 2: 변화없음, 3: 50% 증가
            'player_speed': 2,     # 1: 50% 감소, 2: 변화없음, 3: 50% 증가
        }
        
        # 효과 배율
        self.effect_multipliers = {
            1: 0.5,   # 50% 감소
            2: 1.0,   # 변화없음
            3: 1.5    # 50% 증가
        }
        
        # 원본 값 저장 (복원용)
        self.original_values = {}
        
        # 시각 효과
        self.flame_particles = []
        self.gauge_color = (139, 0, 0)  # 다크 레드
        self.gauge_glow_timer = 0
        
        # 주사위 굴리기 애니메이션
        self.roll_animation_timer = 0
        self.roll_animation_duration = 120  # 2초
        self.is_rolling = False
        self.roll_display_results = self.dice_results.copy()
        self.displayed_face_value = 1
        self.locked_face_value = None
        self.final_idle_phase = 0.0
        self.dice_offset_y = 0.0
        self.dice_vertical_velocity = 0.0
        self.dice_gravity = 0.45
        self.waiting_for_confirm = False  # 스페이스바 대기 중
        self.space_pressed = False  # 스페이스바 입력 확인
        
        # 폰트
        self.font = None
        self.small_font = None
        self.init_fonts()
        
    def init_fonts(self):
        """폰트 초기화"""
        font_candidates = [
            "fonts/pixel/NeoDunggeunmoPro.ttf",
            "NeoDunggeunmoPro.ttf",
            "fonts/pixel/NeoDGM.ttf",
            "NeoDGM.ttf",
            "NanumSquareB.ttf",
            "NanumSquareR.ttf",
        ]

        for candidate in font_candidates:
            try:
                path = resource_path(candidate)
                self.font = pygame.font.Font(path, 24)
                self.small_font = pygame.font.Font(path, 16)
                break
            except Exception:
                self.font = None
                self.small_font = None

        if self.font is None or self.small_font is None:
            self.font = pygame.font.Font(None, 24)
            self.small_font = pygame.font.Font(None, 16)
    
    def activate(self, game_state: Dict[str, Any], current_stage: int) -> Dict[str, float]:
        """
        악마의 주사위 발동
        Args:
            game_state: 게임 상태 정보
            current_stage: 현재 스테이지
        Returns:
            적용할 배율 딕셔너리
        """
        if self.active:
            return self.get_current_multipliers()
        
        self.active = True
        self.time_remaining = self.duration
        self.current_stage = current_stage
        
        # 주사위 굴리기 (각 항목마다 1-3 랜덤) - 미리 결정하지만 표시하지 않음
        for key in self.dice_results:
            self.dice_results[key] = random.randint(1, 3)
        
        # 굴리기 애니메이션 시작
        self.is_rolling = True
        self.roll_animation_timer = 0
        self.waiting_for_confirm = False
        self.space_pressed = False
        self.locked_face_value = None
        self.displayed_face_value = random.randint(1, 6)
        self.final_idle_phase = 0.0
        self.dice_offset_y = 0.0
        self.dice_vertical_velocity = -8.5
        # 초기 표시값은 모두 랜덤으로 시작
        for key in self.roll_display_results:
            self.roll_display_results[key] = random.randint(1, 3)

        # 원본 값 저장 (실제 구현시 게임에서 가져와야 함)
        self._save_original_values(game_state)
        
        # 주사위 굴리기 애니메이션 시작
        self.is_rolling = True
        self.roll_animation_timer = 0
        self.waiting_for_confirm = False
        self.space_pressed = False
        
        # 디버그 출력 (애니메이션 완료 후 표시되도록 변경)
        print("!   ...")
        
        return self.get_current_multipliers()
    
    def _save_original_values(self, game_state: Dict[str, Any]):
        """원본 값 저장"""
        # 실제 게임 구현시 여기서 원본 값들을 저장
        # 예시:
        # self.original_values['paddle_width'] = game_state.get('paddle_width', 100)
        # self.original_values['skill_gauge_max'] = game_state.get('skill_gauge_max', 100)
        pass
    
    def _print_results(self):
        """주사위 결과 출력"""
        results_text = {
            'paddle_size': ['50% 감소', '변화없음', '50% 증가'],
            'skill_gauge': ['50% 감소', '변화없음', '50% 증가'],
            'item_spawn': ['50% 감소', '변화없음', '50% 증가'],
            'item_cooldown': ['50% 감소', '변화없음', '50% 증가'],
            'skill_dash_cost': ['50% 감소', '변화없음', '50% 증가'],
            'dash_cooldown': ['50% 감소', '변화없음', '50% 증가'],
            'player_speed': ['50% 감소', '변화없음', '50% 증가'],
        }
        
        print(":")
        print(f"     : {results_text['paddle_size'][self.dice_results['paddle_size']-1]}")
        print(f"     : {results_text['skill_gauge'][self.dice_results['skill_gauge']-1]}")
        print(f"     : {results_text['item_spawn'][self.dice_results['item_spawn']-1]}")
        print(f"     : {results_text['item_cooldown'][self.dice_results['item_cooldown']-1]}")
        print(f"    / : {results_text['skill_dash_cost'][self.dice_results['skill_dash_cost']-1]}")
        print(f"     : {results_text['dash_cooldown'][self.dice_results['dash_cooldown']-1]}")
        print(f"     : {results_text['player_speed'][self.dice_results['player_speed']-1]}")

    def _update_dice_face(self):
        """굴림 애니메이션용 주사위 눈 업데이트"""
        if self.locked_face_value is not None:
            self.displayed_face_value = self.locked_face_value
            return

        if self.roll_animation_timer % 2 == 0:
            self.displayed_face_value = random.randint(1, 6)

    def get_current_multipliers(self) -> Dict[str, float]:
        """현재 적용중인 배율 반환"""
        if not self.active:
            return {
                'paddle_size': 1.0,
                'skill_gauge': 1.0,
                'item_spawn': 1.0,
                'item_cooldown': 1.0,
                'skill_dash_cost': 1.0,
                'dash_cooldown': 1.0,
                'player_speed': 1.0,
            }
        
        return {
            'paddle_size': self.effect_multipliers[self.dice_results['paddle_size']],
            'skill_gauge': self.effect_multipliers[self.dice_results['skill_gauge']],
            'item_spawn': self.effect_multipliers[self.dice_results['item_spawn']],
            'item_cooldown': self.effect_multipliers[self.dice_results['item_cooldown']],
            'skill_dash_cost': self.effect_multipliers[self.dice_results['skill_dash_cost']],
            'dash_cooldown': self.effect_multipliers[self.dice_results['dash_cooldown']],
            'player_speed': self.effect_multipliers[self.dice_results['player_speed']],
        }
    
    def update(self, current_stage: int) -> bool:
        """
        업데이트
        Args:
            current_stage: 현재 스테이지
        Returns:
            효과가 여전히 활성중인지 여부
        """
        if not self.active:
            return False
        
        # 스테이지가 변경되면 효과 종료
        if current_stage != self.current_stage:
            self.deactivate()
            return False
        
        # 주사위 굴리는 중이 아닐 때만 시간 감소
        if not self.is_rolling:
            self.time_remaining -= 1
            
            # 남은 시간이 3초 이하일 때 경고
            if self.time_remaining == 180:  # 3초 (60fps * 3)
                print("! (3 )")
            elif self.time_remaining == 60:  # 1초
                print("! (1 )")
            
            if self.time_remaining <= 0:
                self.deactivate()
                return False
        
        # 굴리기 애니메이션 업데이트
        if self.is_rolling:
            if not self.waiting_for_confirm:
                self.roll_animation_timer += 1

            self._update_dice_face()

            if not self.waiting_for_confirm:
                self.dice_vertical_velocity += self.dice_gravity
                self.dice_offset_y += self.dice_vertical_velocity

                if self.dice_offset_y > 0:
                    self.dice_offset_y = 0
                    self.dice_vertical_velocity *= -0.65
                    if abs(self.dice_vertical_velocity) < 0.8:
                        self.dice_vertical_velocity = -2.5
                elif self.dice_offset_y < -90:
                    self.dice_offset_y = -90
                    if self.dice_vertical_velocity < 0:
                        self.dice_vertical_velocity *= -0.6

            if self.roll_animation_timer >= self.roll_animation_duration:
                if self.locked_face_value is None:
                    total_score = sum(self.dice_results.values())
                    self.locked_face_value = (total_score % 6) + 1
                self.displayed_face_value = self.locked_face_value

                # 애니메이션 완료 - 실제 결과로 표시 변경
                if not self.waiting_for_confirm:
                    self.roll_display_results = self.dice_results.copy()
                    self._print_results()
                    self.waiting_for_confirm = True
                    self.dice_vertical_velocity = -4.0
            else:
                # 애니메이션 중 랜덤 값 표시 (주사위 굴리는 효과)
                if self.roll_animation_timer % 3 == 0:  # 더 빠르게 변경
                    for key in self.roll_display_results:
                        self.roll_display_results[key] = random.randint(1, 3)

        # 스페이스바 대기 중이고 스페이스바가 눌렸으면 화면 닫기
        if self.waiting_for_confirm and self.space_pressed:
            self.is_rolling = False
            self.waiting_for_confirm = False
            self.space_pressed = False
            self.locked_face_value = None
            self.displayed_face_value = 1
            self.final_idle_phase = 0.0
            self.dice_offset_y = 0.0
            self.dice_vertical_velocity = 0.0

        if self.waiting_for_confirm:
            self.final_idle_phase += 0.08
            hover_base = -12
            hover_amp = 4
            self.dice_offset_y = hover_base + math.sin(self.final_idle_phase * 0.8) * hover_amp
        else:
            self.final_idle_phase = 0.0

        # 주사위 굴리는 중이 아닐 때만 게이지 효과 업데이트
        if not self.is_rolling:
            # 게이지 반짝임 효과
            self.gauge_glow_timer += 0.1
            
            # 화염 파티클 업데이트
            self._update_flame_particles()
        
        return True
    
    def _update_flame_particles(self):
        """화염 파티클 업데이트"""
        # 파티클 생성 및 업데이트는 패들 위치가 필요하므로
        # 실제 구현시 draw_paddle_effect에서 처리
        pass
    
    def deactivate(self):
        """효과 종료 - 모든 설정을 원래대로 복원"""
        if not self.active:
            return
        
        self.active = False
        self.time_remaining = 0
        self.is_rolling = False
        self.waiting_for_confirm = False
        self.space_pressed = False
        self.locked_face_value = None
        self.displayed_face_value = 1
        self.final_idle_phase = 0.0
        self.dice_offset_y = 0.0
        self.dice_vertical_velocity = 0.0

        # 모든 값을 기본으로 리셋 (2 = 변화없음 = 1.0배율)
        for key in self.dice_results:
            self.dice_results[key] = 2  # 변화없음 (1.0 배율)

        # 화염 파티클 초기화
        self.flame_particles.clear()
        
        print("!    .")
    
    def draw_gauge(self, screen: pygame.Surface, x: int, y: int):
        """
        지속시간 게이지 그리기 - 사용자 요청으로 비활성화됨
        우측 상단 게이지는 표시하지 않음
        """
        pass  # 게이지 그리기 비활성화
    
    def draw_paddle_effect(self, screen: pygame.Surface, paddle_rect: pygame.Rect):
        """
        패들에 어두운 기운 효과 그리기
        Args:
            screen: 화면
            paddle_rect: 패들 위치
        """
        if not self.active:
            return

        # 어두운 화염 파티클 생성
        if random.random() < 0.3:  # 30% 확률로 생성
            particle = {
                'x': paddle_rect.centerx + random.randint(-paddle_rect.width//2, paddle_rect.width//2),
                'y': paddle_rect.centery,
                'vx': random.uniform(-1, 1),
                'vy': random.uniform(-3, -1),
                'size': random.randint(3, 8),
                'life': random.randint(20, 40),
                'color': random.choice([
                    (139, 0, 0),    # 다크 레드
                    (75, 0, 130),   # 인디고
                    (25, 25, 112),  # 미드나잇 블루
                    (128, 0, 128)   # 퍼플
                ])
            }
            self.flame_particles.append(particle)
        
        # 파티클 업데이트 및 그리기
        for particle in self.flame_particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1
            particle['size'] *= 0.95  # 크기 감소
            
            if particle['life'] <= 0 or particle['size'] < 1:
                self.flame_particles.remove(particle)
                continue
            
            # 파티클 그리기 (투명도 효과)
            alpha = particle['life'] / 40
            color = (*particle['color'], int(255 * alpha))
            
            # 글로우 효과
            for i in range(3):
                glow_size = int(particle['size'] * (1 + i * 0.5))
                glow_alpha = alpha * (0.3 - i * 0.1)
                if glow_alpha > 0:
                    glow_surface = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surface, (*particle['color'], int(255 * glow_alpha)),
                                     (glow_size, glow_size), glow_size)
                    screen.blit(glow_surface, (particle['x'] - glow_size, particle['y'] - glow_size))
            
            # 중심 파티클
            pygame.draw.circle(screen, particle['color'], 
                             (int(particle['x']), int(particle['y'])), 
                             int(particle['size']))
        
        # 패들 주변 사각 오라 비활성화
        # 사용자 요청: "사각 범위를 투명하게" → 기존의 사각형 오라(반투명 사각 Surface)는 그리지 않음.
        # 색상 변화는 패들 이미지 자체 틴트로 pingfighter.py에서 처리한다.

    def _draw_dice_animation(self, screen: pygame.Surface, center_x: int, center_y: int):
        """붉은 기운이 도는 주사위 애니메이션을 그린다."""
        base_size = 140
        spinning = self.locked_face_value is None

        if spinning:
            phase = self.roll_animation_timer * 0.25
            scale_wave = math.sin(phase)
            scale_amount = 0.16
        else:
            phase = self.final_idle_phase
            scale_wave = math.sin(phase * 0.7)
            scale_amount = 0.05

        dice_size = int(base_size * (1.0 + scale_wave * scale_amount))
        dice_size = max(90, dice_size)

        final_center_y = int(center_y + self.dice_offset_y)

        dice_surface = pygame.Surface((dice_size, dice_size), pygame.SRCALPHA)
        rect = dice_surface.get_rect()
        outer_radius = int(dice_size * 0.18)
        inner_radius = max(6, int(dice_size * 0.14))

        pygame.draw.rect(dice_surface, (70, 0, 0, 235), rect, border_radius=outer_radius)
        inner_rect = rect.inflate(-int(dice_size * 0.18), -int(dice_size * 0.18))
        pygame.draw.rect(dice_surface, (220, 40, 40, 255), inner_rect, border_radius=inner_radius)
        pygame.draw.rect(dice_surface, (255, 200, 200, 90), inner_rect, width=3, border_radius=inner_radius)

        highlight_height = max(8, int(inner_rect.height * 0.35))
        highlight_surface = pygame.Surface((inner_rect.width, highlight_height), pygame.SRCALPHA)
        pygame.draw.rect(highlight_surface, (255, 180, 180, 90), highlight_surface.get_rect(), border_radius=int(inner_rect.width * 0.08))
        dice_surface.blit(highlight_surface, (inner_rect.left, inner_rect.top))

        pip_layouts = {
            1: [(0, 0)],
            2: [(-1, -1), (1, 1)],
            3: [(-1, -1), (0, 0), (1, 1)],
            4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
            5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
            6: [(-1, -1.2), (1, -1.2), (-1, 0), (1, 0), (-1, 1.2), (1, 1.2)],
        }

        face_value = max(1, min(6, self.displayed_face_value))
        pip_offset = dice_size * 0.26
        pip_radius = max(5, int(dice_size * 0.08))

        for px, py in pip_layouts.get(face_value, [(0, 0)]):
            cx = int(rect.centerx + px * pip_offset)
            cy = int(rect.centery + py * pip_offset)
            pygame.draw.circle(dice_surface, (150, 20, 20, 110), (cx, cy), pip_radius + 3)
            pygame.draw.circle(dice_surface, (255, 240, 240), (cx, cy), pip_radius)
            pygame.draw.circle(dice_surface, (255, 80, 80), (cx, cy), max(2, pip_radius - 3))

        if spinning:
            rotation = (self.roll_animation_timer * 12) % 360 + math.sin(self.roll_animation_timer * 0.3) * 12
        else:
            rotation = math.sin(self.final_idle_phase * 0.6) * 5

        rotated = pygame.transform.rotozoom(dice_surface, rotation, 1.0)
        rotated_rect = rotated.get_rect(center=(center_x, final_center_y))
        screen.blit(rotated, rotated_rect)

    def draw_dice_results(self, screen: pygame.Surface, x: int, y: int):
        """
        주사위 결과 표시 (굴리기 애니메이션 포함)
        Args:
            screen: 화면
            x, y: 표시 위치
        """
        if not self.active or not self.is_rolling:
            return
        
        # 전체 화면 반투명 오버레이 (일시정지 효과)
        full_overlay = pygame.Surface((screen.get_width(), screen.get_height()), pygame.SRCALPHA)
        full_overlay.fill((0, 0, 0, 150))
        screen.blit(full_overlay, (0, 0))
        
        panel_width = 500
        panel_height = 490
        panel_x = (screen.get_width() - panel_width) // 2
        panel_y = (screen.get_height() - panel_height) // 2

        dice_center_x = screen.get_width() // 2
        base_center_y = panel_y + 130
        self._draw_dice_animation(screen, dice_center_x, base_center_y)

        # 각 항목 결과 표시
        items = [
            ('패들 크기', 'paddle_size'),
            ('스킬 게이지', 'skill_gauge'),
            ('아이템 스폰률', 'item_spawn'),
            ('아이템 쿨타임', 'item_cooldown'),
            ('스킬/대쉬 비용', 'skill_dash_cost'),
            ('대쉬 쿨타임', 'dash_cooldown'),
            ('플레이어 속도', 'player_speed'),
        ]
        
        results_text = ['50% 감소', '변화없음', '50% 증가']
        colors_default = [(255, 100, 100), (200, 200, 200), (100, 255, 100)]
        invert_keys = {'item_cooldown', 'skill_dash_cost', 'dash_cooldown'}

        # 결과 영역 반투명 배경 (텍스트 가독성용)
        text_panel_y = panel_y + 205
        text_panel_height = len(items) * 40 + 70
        text_panel = pygame.Surface((panel_width, text_panel_height), pygame.SRCALPHA)
        pygame.draw.rect(text_panel, (20, 0, 0, 180), (0, 0, panel_width, text_panel_height), border_radius=15)
        pygame.draw.rect(text_panel, (139, 0, 0, 200), (0, 0, panel_width, text_panel_height), 2, border_radius=15)
        screen.blit(text_panel, (panel_x, text_panel_y))

        # 결과 표시 시작 Y 위치
        start_y = text_panel_y + 35

        for i, (name, key) in enumerate(items):
            y_pos = start_y + i * 40

            # 항목 이름
            if self.small_font:
                name_text = self.small_font.render(f"{name}:", True, (255, 255, 255))
                screen.blit(name_text, (panel_x + 80, y_pos))
                
                # 결과 (애니메이션 중에는 숨김 또는 ???, 끝나면 실제 결과)
                if self.roll_animation_timer < self.roll_animation_duration - 30:
                    # 굴리는 중 - 결과 숨김
                    if self.roll_animation_timer % 6 < 3:  # 빠르게 깜빡임
                        result_text = "???"
                        result_color = (150, 150, 150)
                    else:
                        # 랜덤 텍스트 표시
                        temp_idx = random.randint(0, 2)
                        result_text = results_text[temp_idx]
                        result_color = (100, 100, 100)
                else:
                    # 실제 결과 표시 (애니메이션 완료 후)
                    result_idx = self.dice_results[key] - 1
                    if key in invert_keys:
                        # 감소가 이득인 항목은 색상을 뒤집는다
                        result_color = colors_default[2 - result_idx]
                    else:
                        result_color = colors_default[result_idx]
                    result_text = results_text[result_idx]
                    
                    # 결과 강조 효과
                    if self.roll_animation_timer < self.roll_animation_duration + 30:
                        # 결과가 나타난 직후 반짝임
                        flash = abs(math.sin((self.roll_animation_timer - self.roll_animation_duration) * 0.3))
                        result_color = tuple(min(255, int(c + flash * 50)) for c in result_color)
                
                result_surface = self.small_font.render(result_text, True, result_color)
                result_rect = result_surface.get_rect(left=panel_x + 280, centery=y_pos + 10)
                screen.blit(result_surface, result_rect)
        
        # 스페이스바 안내 문구 (애니메이션 완료 후)
        if self.waiting_for_confirm and self.small_font:
            instruction_text = "스페이스바를 눌러 계속하기"
            instruction_color = (255, 255, 100)  # 노란색
            # 깜빡임 효과
            if pygame.time.get_ticks() % 1000 < 500:  # 0.5초마다 깜빡임
                instruction_surface = self.small_font.render(instruction_text, True, instruction_color)
                instruction_rect = instruction_surface.get_rect(centerx=screen.get_width()//2, 
                                                              y=text_panel_y + text_panel_height - 30)
                screen.blit(instruction_surface, instruction_rect)
    
    def handle_spacebar(self):
        """스페이스바 입력 처리"""
        if self.waiting_for_confirm:
            self.space_pressed = True
    
    def get_save_data(self) -> Dict[str, Any]:
        """저장 데이터 반환"""
        return {
            'active': self.active,
            'time_remaining': self.time_remaining,
            'current_stage': self.current_stage,
            'dice_results': self.dice_results.copy()
        }
    
    def load_save_data(self, data: Dict[str, Any]):
        """저장 데이터 로드"""
        self.active = data.get('active', False)
        self.time_remaining = data.get('time_remaining', 0)
        self.current_stage = data.get('current_stage', -1)
        self.dice_results = data.get('dice_results', self.dice_results.copy())


# 전역 인스턴스
devil_dice_instance = None

def get_devil_dice_instance() -> DevilDice:
    """악마의 주사위 인스턴스 반환"""
    global devil_dice_instance
    if devil_dice_instance is None:
        devil_dice_instance = DevilDice()
    return devil_dice_instance

def activate_devil_dice(game_state: Dict[str, Any], current_stage: int) -> Dict[str, float]:
    """
    악마의 주사위 발동 (외부에서 호출)
    Returns:
        적용할 배율 딕셔너리
    """
    instance = get_devil_dice_instance()
    return instance.activate(game_state, current_stage)

def update_devil_dice(current_stage: int) -> bool:
    """악마의 주사위 업데이트"""
    instance = get_devil_dice_instance()
    return instance.update(current_stage)

def draw_devil_dice_effects(screen: pygame.Surface, paddle_rect: pygame.Rect = None):
    """악마의 주사위 시각 효과 그리기"""
    instance = get_devil_dice_instance()
    
    # 우측 상단 게이지는 사용자 요청으로 제거됨
    # 우측 하단 게이지는 pingfighter.py의 draw_player_gauge()에서 그림
    
    # 패들 효과 그리기
    if paddle_rect:
        instance.draw_paddle_effect(screen, paddle_rect)
    
    # 주사위 결과 애니메이션
    instance.draw_dice_results(screen, 300, 375)

def get_devil_dice_multipliers() -> Dict[str, float]:
    """현재 적용중인 배율 반환"""
    instance = get_devil_dice_instance()
    return instance.get_current_multipliers()

def is_devil_dice_active() -> bool:
    """악마의 주사위 활성 상태 확인"""
    instance = get_devil_dice_instance()
    return instance.active

def get_devil_dice_duration_ratio() -> float:
    """악마의 주사위 지속시간 비율 반환 (0.0 ~ 1.0)"""
    instance = get_devil_dice_instance()
    if not instance.active:
        return 0.0
    return instance.time_remaining / instance.duration

def handle_devil_dice_spacebar():
    """악마의 주사위 스페이스바 입력 처리"""
    instance = get_devil_dice_instance()
    instance.handle_spacebar()

def is_devil_dice_waiting_confirm() -> bool:
    """악마의 주사위가 스페이스바 대기 중인지 확인"""
    instance = get_devil_dice_instance()
    return instance.waiting_for_confirm

def is_devil_dice_rolling() -> bool:
    """악마의 주사위가 굴려지는 중인지 확인 (게임 일시정지 용)"""
    instance = get_devil_dice_instance()
    return instance.is_rolling

def deactivate_devil_dice():
    """악마의 주사위 효과 강제 종료 (메인 메뉴 복귀 시)"""
    instance = get_devil_dice_instance()
    if instance.active:
        print("-")
        instance.deactivate()
