"""
😈 Devil's Dice Active Item
악마의 주사위 - 6가지 랜덤 효과를 발동하는 액티브 아이템
지속시간: 60초 (다음 라운드 유지, 스테이지 전환시 종료)
"""

import pygame
import random
import math
from typing import Dict, Any, Optional, Tuple

class DevilDice:
    """악마의 주사위 액티브 아이템"""
    
    def __init__(self):
        """초기화"""
        # 효과 상태
        self.active = False
        self.duration = 3600  # 60초 (60 FPS * 60)
        self.time_remaining = 0
        self.current_stage = -1  # 효과가 시작된 스테이지
        
        # 주사위 결과 (1-3 범위의 값)
        self.dice_results = {
            'paddle_size': 2,      # 1: 50% 감소, 2: 변화없음, 3: 50% 증가
            'skill_gauge': 2,      # 1: 50% 감소, 2: 변화없음, 3: 50% 증가
            'item_spawn': 2,       # 1: 50% 감소, 2: 변화없음, 3: 50% 증가
            'active_cooldown': 2,  # 1: 50% 감소, 2: 변화없음, 3: 50% 증가
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
        self.roll_display_results = {}
        self.waiting_for_confirm = False  # 스페이스바 대기 중
        self.space_pressed = False  # 스페이스바 입력 확인
        
        # 폰트
        self.font = None
        self.small_font = None
        self.init_fonts()
        
    def init_fonts(self):
        """폰트 초기화"""
        try:
            self.font = pygame.font.Font("NeoDGM.ttf", 24)
            self.small_font = pygame.font.Font("NeoDGM.ttf", 16)
        except:
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
            'active_cooldown': ['50% 감소', '변화없음', '50% 증가'],
            'skill_dash_cost': ['50% 감소', '변화없음', '50% 증가'],
            'dash_cooldown': ['50% 감소', '변화없음', '50% 증가'],
            'player_speed': ['50% 감소', '변화없음', '50% 증가'],
        }
        
        print(":")
        print(f"     : {results_text['paddle_size'][self.dice_results['paddle_size']-1]}")
        print(f"     : {results_text['skill_gauge'][self.dice_results['skill_gauge']-1]}")
        print(f"     : {results_text['item_spawn'][self.dice_results['item_spawn']-1]}")
        print(f"     : {results_text['active_cooldown'][self.dice_results['active_cooldown']-1]}")
        print(f"    / : {results_text['skill_dash_cost'][self.dice_results['skill_dash_cost']-1]}")
        print(f"     : {results_text['dash_cooldown'][self.dice_results['dash_cooldown']-1]}")
        print(f"     : {results_text['player_speed'][self.dice_results['player_speed']-1]}")
    
    def get_current_multipliers(self) -> Dict[str, float]:
        """현재 적용중인 배율 반환"""
        if not self.active:
            return {
                'paddle_size': 1.0,
                'skill_gauge': 1.0,
                'item_spawn': 1.0,
                'active_cooldown': 1.0,
                'skill_dash_cost': 1.0,
                'dash_cooldown': 1.0,
                'player_speed': 1.0,
            }
        
        return {
            'paddle_size': self.effect_multipliers[self.dice_results['paddle_size']],
            'skill_gauge': self.effect_multipliers[self.dice_results['skill_gauge']],
            'item_spawn': self.effect_multipliers[self.dice_results['item_spawn']],
            'active_cooldown': self.effect_multipliers[self.dice_results['active_cooldown']],
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
            self.roll_animation_timer += 1
            if self.roll_animation_timer >= self.roll_animation_duration:
                # 애니메이션 완료 - 실제 결과로 표시 변경
                if not self.waiting_for_confirm:
                    # 최종 결과로 표시값 설정
                    self.roll_display_results = self.dice_results.copy()
                    # 결과 출력
                    self._print_results()
                    # 스페이스바 대기 상태로 전환
                    self.waiting_for_confirm = True
                # is_rolling은 유지하여 결과 화면 계속 표시
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
        
        # 모든 값을 기본으로 리셋 (2 = 변화없음 = 1.0배율)
        for key in self.dice_results:
            self.dice_results[key] = 2  # 변화없음 (1.0 배율)
        
        # 화염 파티클 초기화
        self.flame_particles.clear()
        
        print("!    .")
    
    def draw_gauge(self, screen: pygame.Surface, x: int, y: int):
        """
        지속시간 게이지 그리기
        Args:
            screen: 화면
            x, y: 게이지 위치 (우측 상단 기준)
        """
        if not self.active:
            return
        
        # 게이지 크기
        gauge_width = 150
        gauge_height = 20
        
        # 남은 시간 비율
        time_ratio = self.time_remaining / self.duration
        
        # 게이지 배경 (어두운 색)
        bg_rect = pygame.Rect(x - gauge_width - 10, y, gauge_width, gauge_height)
        pygame.draw.rect(screen, (50, 0, 0), bg_rect)
        pygame.draw.rect(screen, (100, 0, 0), bg_rect, 2)
        
        # 게이지 채우기 (악마스러운 붉은색)
        if time_ratio > 0:
            fill_width = int(gauge_width * time_ratio)
            fill_rect = pygame.Rect(x - gauge_width - 10, y, fill_width, gauge_height)
            
            # 그라데이션 효과
            glow_intensity = abs(math.sin(self.gauge_glow_timer)) * 0.3 + 0.7
            color = (
                int(139 * glow_intensity),
                int(0),
                int(0)
            )
            pygame.draw.rect(screen, color, fill_rect)
        
        # 악마 아이콘 또는 텍스트
        if self.small_font:
            text = self.small_font.render("😈", True, (255, 100, 100))
            screen.blit(text, (x - gauge_width - 35, y - 2))
        
        # 남은 시간 텍스트
        if self.small_font:
            time_text = f"{self.time_remaining // 60}s"
            text_surface = self.small_font.render(time_text, True, (255, 255, 255))
            text_rect = text_surface.get_rect(center=(x - gauge_width // 2 - 10, y + gauge_height // 2))
            screen.blit(text_surface, text_rect)
    
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
        
        # 패들 주변 어두운 오라
        if self.active:
            # 펄스 효과
            pulse = abs(math.sin(self.gauge_glow_timer * 2)) * 0.3 + 0.2
            
            # 어두운 오라 그리기
            for i in range(3):
                aura_size = i * 5 + 5
                aura_alpha = pulse * (0.3 - i * 0.1)
                if aura_alpha > 0:
                    aura_surface = pygame.Surface((paddle_rect.width + aura_size * 2, 
                                                  paddle_rect.height + aura_size * 2), pygame.SRCALPHA)
                    pygame.draw.rect(aura_surface, (139, 0, 0, int(255 * aura_alpha)),
                                   aura_surface.get_rect(), border_radius=5)
                    screen.blit(aura_surface, (paddle_rect.x - aura_size, paddle_rect.y - aura_size))
    
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
        
        # 중앙 패널
        panel_width = 500
        panel_height = 490  # 패들 게이지 충전량 제거로 원래 높이로
        panel_x = (screen.get_width() - panel_width) // 2
        panel_y = (screen.get_height() - panel_height) // 2
        
        # 패널 배경 (악마스러운 디자인)
        panel = pygame.Surface((panel_width, panel_height), pygame.SRCALPHA)
        pygame.draw.rect(panel, (20, 0, 0, 230), (0, 0, panel_width, panel_height), border_radius=15)
        pygame.draw.rect(panel, (139, 0, 0), (0, 0, panel_width, panel_height), 3, border_radius=15)
        
        # 빛나는 테두리 효과
        glow_intensity = abs(math.sin(self.gauge_glow_timer)) * 0.5 + 0.5
        pygame.draw.rect(panel, (int(255 * glow_intensity), 0, 0), 
                        (0, 0, panel_width, panel_height), 2, border_radius=15)
        
        screen.blit(panel, (panel_x, panel_y))
        
        # 제목 
        if self.font:
            title = "[ 악마의 주사위 ]"
            title_surface = self.font.render(title, True, (255, 100, 100))
            title_rect = title_surface.get_rect(centerx=screen.get_width()//2, y=panel_y + 20)
            screen.blit(title_surface, title_rect)
        
        # 주사위 굴리는 애니메이션 상태 표시
        if self.roll_animation_timer < self.roll_animation_duration - 30:
            # 주사위 굴리는 중
            if self.small_font:
                rolling_text = "주사위를 굴리는 중..."
                anim_offset = math.sin(self.roll_animation_timer * 0.3) * 5
                rolling_surface = self.small_font.render(rolling_text, True, (255, 255, 100))
                rolling_rect = rolling_surface.get_rect(centerx=screen.get_width()//2, 
                                                       y=panel_y + 60 + anim_offset)
                screen.blit(rolling_surface, rolling_rect)
                
                # 주사위 숫자 애니메이션 (유니코드 대신 숫자 사용)
                dice_number = ((self.roll_animation_timer // 5) % 6) + 1
                dice_text = f"[ {dice_number} ]"
                dice_surface = self.font.render(dice_text, True, (255, 255, 255))
                dice_rect = dice_surface.get_rect(centerx=screen.get_width()//2, y=panel_y + 90)
                screen.blit(dice_surface, dice_rect)
                
                # 주사위 굴리는 애니메이션 효과
                for i in range(3):
                    side_number = random.randint(1, 6)
                    offset_x = (i - 1) * 80
                    side_text = str(side_number)
                    alpha = random.randint(50, 150)
                    side_color = (alpha, alpha, alpha)
                    side_surface = self.small_font.render(side_text, True, side_color)
                    side_rect = side_surface.get_rect(centerx=screen.get_width()//2 + offset_x, 
                                                     y=panel_y + 115)
                    screen.blit(side_surface, side_rect)
        
        # 각 항목 결과 표시
        items = [
            ('패들 크기', 'paddle_size'),
            ('스킬 게이지', 'skill_gauge'),
            ('아이템 스폰률', 'item_spawn'),
            ('액티브 쿨타임', 'active_cooldown'),
            ('스킬/대쉬 비용', 'skill_dash_cost'),
            ('대쉬 쿨타임', 'dash_cooldown'),
            ('플레이어 속도', 'player_speed'),
        ]
        
        results_text = ['50% 감소', '변화없음', '50% 증가']
        colors = [(255, 100, 100), (200, 200, 200), (100, 255, 100)]
        
        # 결과 표시 시작 Y 위치
        start_y = panel_y + 140
        
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
                    result_color = colors[result_idx]
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
                                                              y=panel_y + panel_height - 40)
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
    
    # 게이지는 이제 pingfighter.py의 draw_player_gauge()에서 그림
    # instance.draw_gauge(screen, 590, 100)  # 제거됨
    
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