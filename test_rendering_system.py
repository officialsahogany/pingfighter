"""
렌더링 시스템 테스트
통합된 렌더링 시스템이 올바르게 작동하는지 검증
"""
import pygame
import sys
import math
from typing import Dict, Any

# 렌더러 임포트
from rendering.render_manager import RenderManager

# 유틸리티 임포트
from utils.color_utils import get_stage_color, blend_colors, get_neon_color
from utils.math_utils import calculate_distance, get_angle_between, normalize_vector

# 상수
WIDTH = 600
HEIGHT = 750
FPS = 60

class RenderingSystemTest:
    """렌더링 시스템 테스트 클래스"""
    
    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((WIDTH, HEIGHT))
        pygame.display.set_caption("렌더링 시스템 테스트")
        self.clock = pygame.time.Clock()
        
        # 렌더 매니저 초기화
        self.render_manager = RenderManager(self.screen)
        
        # 테스트 상태
        self.running = True
        self.test_mode = 0  # 0-5: 다양한 테스트 모드
        self.frame_count = 0
        
        # 게임 상태 시뮬레이션
        self.game_state = self._create_test_game_state()
        
        # 폰트
        self.font = pygame.font.Font(None, 24)
        
    def _create_test_game_state(self) -> Dict[str, Any]:
        """테스트용 게임 상태 생성"""
        return {
            'background': self._create_gradient_background(),
            'boss': {
                'rect': pygame.Rect(WIDTH//2 - 60, 50, 120, 20),
                'color': (255, 0, 0),
                'stage': 1,
                'is_rage': False,
                'special_attack': None
            },
            'player': {
                'rect': pygame.Rect(WIDTH//2 - 50, HEIGHT - 100, 100, 20),
                'color': (0, 255, 0),
                'is_dashing': False,
                'is_charging': False,
                'charge_level': 0.0,
                'power_ups': {}
            },
            'ball': {
                'pos': [WIDTH//2, HEIGHT//2],
                'radius': 10,
                'color': (255, 255, 255),
                'power_shot': False,
                'curve_ball': False,
                'ghost_ball': False,
                'velocity': [5, 5]
            },
            'items': [],
            'score': {
                'player': 0,
                'boss': 0
            },
            'stage': 1,
            'gauges': {
                'special': {'value': 75, 'max': 100},
                'health': {'value': 80, 'max': 100}
            },
            'combo': {
                'count': 0,
                'multiplier': 1.0
            },
            'timer': 120,
            'active_powerups': {},
            'message': None
        }
    
    def _create_gradient_background(self) -> pygame.Surface:
        """그라데이션 배경 생성"""
        bg = pygame.Surface((WIDTH, HEIGHT))
        for y in range(HEIGHT):
            color_factor = y / HEIGHT
            color = (
                int(20 + 30 * color_factor),
                int(10 + 20 * color_factor),
                int(40 + 40 * color_factor)
            )
            pygame.draw.line(bg, color, (0, y), (WIDTH, y))
        return bg
    
    def update(self):
        """업데이트"""
        self.frame_count += 1
        
        # 공 움직임 시뮬레이션
        ball = self.game_state['ball']
        ball['pos'][0] += ball['velocity'][0]
        ball['pos'][1] += ball['velocity'][1]
        
        # 벽 충돌
        if ball['pos'][0] <= ball['radius'] or ball['pos'][0] >= WIDTH - ball['radius']:
            ball['velocity'][0] *= -1
            # 히트 이펙트
            self.render_manager.trigger_hit_effect(ball['pos'], 'ball')
            
        if ball['pos'][1] <= ball['radius'] or ball['pos'][1] >= HEIGHT - ball['radius']:
            ball['velocity'][1] *= -1
            # 히트 이펙트
            self.render_manager.trigger_hit_effect(ball['pos'], 'ball')
        
        # 패들 충돌 체크
        player_rect = self.game_state['player']['rect']
        boss_rect = self.game_state['boss']['rect']
        ball_rect = pygame.Rect(
            ball['pos'][0] - ball['radius'],
            ball['pos'][1] - ball['radius'],
            ball['radius'] * 2,
            ball['radius'] * 2
        )
        
        if ball_rect.colliderect(player_rect):
            ball['velocity'][1] = -abs(ball['velocity'][1])
            self.render_manager.trigger_hit_effect(ball['pos'], 'paddle')
            self.game_state['combo']['count'] += 1
            
        if ball_rect.colliderect(boss_rect):
            ball['velocity'][1] = abs(ball['velocity'][1])
            self.render_manager.trigger_hit_effect(ball['pos'], 'boss')
            
        # 플레이어 패들 이동 (마우스 따라가기)
        mouse_x, _ = pygame.mouse.get_pos()
        self.game_state['player']['rect'].centerx = mouse_x
        
        # 보스 AI (간단한 추적)
        boss_speed = 3
        if boss_rect.centerx < ball['pos'][0]:
            boss_rect.x += boss_speed
        elif boss_rect.centerx > ball['pos'][0]:
            boss_rect.x -= boss_speed
            
        # 테스트 모드별 특수 효과
        self._update_test_mode()
        
        # 타이머 업데이트
        if self.frame_count % FPS == 0:
            self.game_state['timer'] -= 1
            
        # 아이템 생성 (랜덤)
        if self.frame_count % 180 == 0:  # 3초마다
            import random
            self.game_state['items'].append({
                'pos': [random.randint(50, WIDTH-50), random.randint(100, HEIGHT-100)],
                'size': 20,
                'color': (random.randint(100, 255), random.randint(100, 255), 0),
                'type': 'powerup'
            })
        
        # 오래된 아이템 제거
        self.game_state['items'] = self.game_state['items'][-5:]  # 최대 5개
    
    def _update_test_mode(self):
        """테스트 모드별 특수 효과 업데이트"""
        if self.test_mode == 0:
            # 기본 모드
            pass
            
        elif self.test_mode == 1:
            # 파워샷 모드
            self.game_state['ball']['power_shot'] = True
            self.game_state['ball']['color'] = (255, 200, 0)
            
        elif self.test_mode == 2:
            # 대시 모드
            self.game_state['player']['is_dashing'] = (self.frame_count % 60) < 30
            
        elif self.test_mode == 3:
            # 차징 모드
            self.game_state['player']['is_charging'] = True
            self.game_state['player']['charge_level'] = (self.frame_count % 60) / 60.0
            
        elif self.test_mode == 4:
            # 레이지 모드
            self.game_state['boss']['is_rage'] = True
            self.game_state['boss']['color'] = (255, 100, 100)
            # 폭발 효과
            if self.frame_count % 60 == 0:
                self.render_manager.add_explosion(
                    (self.game_state['boss']['rect'].centerx, 
                     self.game_state['boss']['rect'].centery),
                    'large'
                )
                
        elif self.test_mode == 5:
            # 특수 효과 모드
            if self.frame_count % 30 == 0:
                # 레이저
                self.render_manager.add_laser(
                    (100, 100),
                    (WIDTH - 100, HEIGHT - 100)
                )
            if self.frame_count % 45 == 0:
                # 화면 흔들림
                self.render_manager.add_screen_shake(10, 15)
            if self.frame_count % 90 == 0:
                # 화면 플래시
                self.render_manager.add_screen_flash((255, 255, 0))
    
    def render(self):
        """렌더링"""
        # 렌더 매니저로 전체 프레임 렌더링
        self.render_manager.render_frame(self.game_state)
        
        # 테스트 정보 표시
        self._draw_test_info()
        
        # 디버그 모드 토글 안내
        debug_text = self.font.render(
            f"Press D for Debug | Mode: {self.test_mode} | Press 0-5 to change",
            True, (255, 255, 0)
        )
        self.screen.blit(debug_text, (10, HEIGHT - 30))
        
        pygame.display.flip()
    
    def _draw_test_info(self):
        """테스트 정보 표시"""
        info_texts = [
            "렌더링 시스템 테스트",
            f"FPS: {self.clock.get_fps():.1f}",
            f"Frame: {self.frame_count}",
            "",
            "테스트 모드:",
            "0: 기본",
            "1: 파워샷",
            "2: 대시",
            "3: 차징",
            "4: 레이지",
            "5: 특수 효과",
            "",
            "Q: 품질 변경",
            "C: 효과 초기화",
            "ESC: 종료"
        ]
        
        y = 10
        for text in info_texts:
            if text:
                surf = self.font.render(text, True, (200, 200, 200))
                self.screen.blit(surf, (WIDTH - 150, y))
            y += 25
    
    def handle_event(self, event):
        """이벤트 처리"""
        if event.type == pygame.QUIT:
            self.running = False
            
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.running = False
                
            # 테스트 모드 변경
            elif event.key >= pygame.K_0 and event.key <= pygame.K_5:
                self.test_mode = event.key - pygame.K_0
                print(f"테스트 모드 변경: {self.test_mode}")
                
            # 디버그 모드 토글
            elif event.key == pygame.K_d:
                self.render_manager.toggle_debug()
                
            # 품질 설정 변경
            elif event.key == pygame.K_q:
                qualities = ['low', 'medium', 'high']
                current = self.render_manager.settings.get('particle_quality', 'high')
                idx = qualities.index(current)
                new_quality = qualities[(idx + 1) % 3]
                self.render_manager.set_render_quality(new_quality)
                print(f"렌더링 품질 변경: {new_quality}")
                
            # 효과 초기화
            elif event.key == pygame.K_c:
                self.render_manager.clear_all_effects()
                print("모든 효과 초기화")
                
            # 메시지 테스트
            elif event.key == pygame.K_m:
                self.game_state['message'] = {
                    'text': '테스트 메시지!',
                    'duration': 120,
                    'position': 'center',
                    'size': 'large',
                    'color': get_neon_color()
                }
                
            # 콤보 증가
            elif event.key == pygame.K_SPACE:
                self.game_state['combo']['count'] += 1
                self.game_state['combo']['multiplier'] = 1.0 + (self.game_state['combo']['count'] * 0.1)
    
    def run(self):
        """메인 루프"""
        print("렌더링 시스템 테스트 시작")
        print("키 안내:")
        print("  0-5: 테스트 모드 변경")
        print("  D: 디버그 모드 토글")
        print("  Q: 렌더링 품질 변경")
        print("  C: 모든 효과 초기화")
        print("  M: 메시지 테스트")
        print("  SPACE: 콤보 증가")
        print("  ESC: 종료")
        
        while self.running:
            for event in pygame.event.get():
                self.handle_event(event)
            
            self.update()
            self.render()
            self.clock.tick(FPS)
            
        # 성능 통계 출력
        stats = self.render_manager.get_performance_stats()
        print("\n=== 성능 통계 ===")
        print(f"평균 FPS: {stats['avg_fps']:.1f}")
        print(f"평균 프레임 시간: {stats['avg_frame_time']:.2f}ms")
        print(f"최소 프레임 시간: {stats['min_frame_time']:.2f}ms")
        print(f"최대 프레임 시간: {stats['max_frame_time']:.2f}ms")
        
        pygame.quit()
        sys.exit()

def main():
    """메인 함수"""
    test = RenderingSystemTest()
    test.run()

if __name__ == "__main__":
    main()