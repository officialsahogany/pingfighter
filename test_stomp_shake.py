#!/usr/bin/env python3
"""
Stage 2 보스 발구르기 화면 흔들림 테스트

플레이어가 2점 획득 후 보스가 발구르기 시작할 때부터
바위가 떨어질 때까지 화면 흔들림 효과 테스트
"""

import pygame
import sys
import os
import random

# 게임 디렉토리를 Python 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from backgrounds.animated_background_stage2 import AnimatedBackgroundStage2

# 상수 정의
WIDTH = 600
HEIGHT = 750
FPS = 60

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
GREEN = (34, 139, 34)  # 정글 색상
RED = (255, 0, 0)
BROWN = (139, 69, 19)

def test_stomp_shake():
    """보스 발구르기 화면 흔들림 테스트"""
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Stage 2 보스 발구르기 화면 흔들림 테스트")
    clock = pygame.time.Clock()
    
    # AnimatedBackgroundStage2 인스턴스 생성
    # 실제 이미지 파일이 있으면 사용, 없으면 stage2_field.png 사용
    try:
        animated_bg = AnimatedBackgroundStage2("stage2_field.png")
    except:
        # 이미지 파일이 없어도 테스트 가능하도록
        class MockAnimatedBg:
            def __init__(self):
                self.boss_rage_pending = False
                self.boss_rage_active = False
                self.boss_rage_timer = 0
                self.boss_stomp_count = 0
                self.boss_red_tint = 0
                self.boss_shake_offset_y = 0
                self.stomp_shake_offset_x = 0
                self.stomp_shake_offset_y = 0
                self.earthquake_active = False
                self.earthquake_timer = 0
                self.earthquake_duration = 80
                self.crisis_triggered = False
                self.cry_sound = None
                
            def check_crisis_situation(self, player_score, boss_score):
                is_crisis = (player_score == 2 and boss_score <= 2 and not self.crisis_triggered and not self.boss_rage_pending)
                if is_crisis:
                    self.boss_rage_pending = True
                    self.crisis_triggered = True
                    print("⚠️ Stage 2: 보스 위기 감지! 다음 라운드에서 분노 폭발 예정...")
                return is_crisis
                
            def start_boss_rage_animation(self):
                if self.boss_rage_pending and not self.boss_rage_active:
                    self.boss_rage_pending = False
                    self.boss_rage_active = True
                    self.boss_rage_timer = 0
                    self.boss_stomp_count = 0
                    print("😡 Stage 2 보스 분노 폭발! 바닥을 쿵쿵 밟기 시작!")
                    return True
                return False
                
            def update(self):
                if self.boss_rage_active:
                    self.boss_rage_timer += 1
                    
                    if self.boss_rage_timer <= 60:
                        self.boss_red_tint = min(255, self.boss_rage_timer * 4)
                        
                        if self.boss_rage_timer % 15 == 0:
                            self.boss_stomp_count += 1
                            self.boss_shake_offset_y = 20
                            self.stomp_shake_offset_x = random.randint(-5, 5)
                            self.stomp_shake_offset_y = random.randint(-3, 3)
                            print(f"💢 쿵! (발구르기 {self.boss_stomp_count}/4) - 화면 흔들림!")
                        elif self.boss_rage_timer % 15 == 5:
                            self.boss_shake_offset_y = -10
                            self.stomp_shake_offset_x = random.randint(-8, 8)
                            self.stomp_shake_offset_y = random.randint(-6, 6)
                        else:
                            self.boss_shake_offset_y = max(0, self.boss_shake_offset_y - 2)
                            self.stomp_shake_offset_x = int(self.stomp_shake_offset_x * 0.8)
                            self.stomp_shake_offset_y = int(self.stomp_shake_offset_y * 0.8)
                    
                    elif self.boss_rage_timer == 80:
                        print("💥💥 크아아악! 보스 최종 분노 폭발!")
                        self.boss_shake_offset_y = 30
                        self.stomp_shake_offset_x = random.randint(-12, 12)
                        self.stomp_shake_offset_y = random.randint(-10, 10)
                        self.earthquake_active = True
                        self.earthquake_timer = 0
                        print("🪨 하늘에서 바위가 떨어지기 시작! - 화면 대폭 흔들림!")
                    
                    elif self.boss_rage_timer <= 100:
                        self.boss_red_tint = max(0, 255 - (self.boss_rage_timer - 80) * 12)
                        self.boss_shake_offset_y = max(0, self.boss_shake_offset_y - 3)
                        self.stomp_shake_offset_x = random.randint(-6, 6)
                        self.stomp_shake_offset_y = random.randint(-4, 4)
                    
                    elif self.boss_rage_timer > 100:
                        self.boss_rage_active = False
                        self.boss_rage_timer = 0
                        self.boss_red_tint = 0
                        self.boss_shake_offset_y = 0
                        self.stomp_shake_offset_x = 0
                        self.stomp_shake_offset_y = 0
                        print("😤 보스 분노가 가라앉았다...")
                
                if self.earthquake_active:
                    self.earthquake_timer += 1
                    if self.earthquake_timer >= self.earthquake_duration:
                        self.earthquake_active = False
            
            def get_stomp_shake_offset(self):
                return (self.stomp_shake_offset_x, self.stomp_shake_offset_y)
            
            def get_earthquake_offset(self):
                if not self.earthquake_active:
                    return (0, 0)
                progress = self.earthquake_timer / self.earthquake_duration
                intensity = 8 * (1 - progress)
                offset_x = (random.random() - 0.5) * intensity * 2
                offset_y = (random.random() - 0.5) * intensity * 2
                return (int(offset_x), int(offset_y))
        
        animated_bg = MockAnimatedBg()
    
    # 테스트 상태
    running = True
    player_score = 0
    boss_score = 0
    screen_shake_offset_x = 0
    screen_shake_offset_y = 0
    
    # 폰트
    font = pygame.font.Font(None, 36)
    small_font = pygame.font.Font(None, 24)
    
    # 테스트용 보스 위치
    boss_rect = pygame.Rect(WIDTH // 2 - 40, 50, 80, 60)
    
    def trigger_boss_rage():
        """보스 분노 애니메이션 수동 트리거"""
        animated_bg.boss_rage_pending = True
        animated_bg.start_boss_rage_animation()
        print("💢 보스 분노 애니메이션 시작!")
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 보스 분노 트리거
                    trigger_boss_rage()
                elif event.key == pygame.K_1:
                    # 플레이어 점수 증가
                    player_score = min(3, player_score + 1)
                    animated_bg.check_crisis_situation(player_score, boss_score)
                elif event.key == pygame.K_2:
                    # 보스 점수 증가
                    boss_score = min(3, boss_score + 1)
                elif event.key == pygame.K_r:
                    # 리셋
                    player_score = 0
                    boss_score = 0
                    animated_bg.crisis_triggered = False
                    animated_bg.boss_rage_pending = False
                    animated_bg.boss_rage_active = False
                    animated_bg.boss_rage_timer = 0
                    animated_bg.stomp_shake_offset_x = 0
                    animated_bg.stomp_shake_offset_y = 0
        
        # 애니메이션 업데이트
        # AnimatedBackgroundStage2.update()는 dt 인자를 받음
        if hasattr(animated_bg, '__class__') and animated_bg.__class__.__name__ == 'AnimatedBackgroundStage2':
            animated_bg.update(1.0 / FPS)  # dt = 델타 타임
        else:
            animated_bg.update()  # MockAnimatedBg는 dt 인자 없음
        
        # 화면 흔들림 오프셋 가져오기
        stomp_offset_x, stomp_offset_y = animated_bg.get_stomp_shake_offset()
        earthquake_offset_x, earthquake_offset_y = animated_bg.get_earthquake_offset()
        
        # 흔들림 효과 합산
        screen_shake_offset_x = stomp_offset_x + earthquake_offset_x
        screen_shake_offset_y = stomp_offset_y + earthquake_offset_y
        
        # 렌더링
        if screen_shake_offset_x != 0 or screen_shake_offset_y != 0:
            # 흔들림이 있을 때 - temp_surface 사용
            temp_surface = pygame.Surface((WIDTH, HEIGHT))
            
            # 배경
            temp_surface.fill(GREEN)
            
            # 보스 그리기 (빨간색 틴트 적용)
            boss_color = WHITE
            if animated_bg.boss_rage_active:
                # 빨간색으로 변하는 효과
                red_tint = animated_bg.boss_red_tint
                boss_color = (255, 255 - red_tint // 2, 255 - red_tint // 2)
            
            # 보스 Y축 오프셋 (발구르기 애니메이션)
            boss_y_offset = animated_bg.boss_shake_offset_y
            boss_render_rect = boss_rect.copy()
            boss_render_rect.y += boss_y_offset
            
            pygame.draw.rect(temp_surface, boss_color, boss_render_rect)
            pygame.draw.rect(temp_surface, BLACK, boss_render_rect, 2)
            
            # 보스 얼굴
            if animated_bg.boss_rage_active and animated_bg.boss_rage_timer <= 60:
                # 화난 표정
                face_text = "😡"
            else:
                face_text = "😤"
            face_surface = font.render(face_text, True, BLACK)
            temp_surface.blit(face_surface, (boss_render_rect.centerx - 15, boss_render_rect.centery - 15))
            
            # 정보 텍스트
            score_text = font.render(f"Player: {player_score} | Boss: {boss_score}", True, WHITE)
            temp_surface.blit(score_text, (WIDTH//2 - score_text.get_width()//2, HEIGHT - 100))
            
            if animated_bg.boss_rage_active:
                rage_text = font.render(f"💢 발구르기 {animated_bg.boss_stomp_count}/4", True, RED)
                temp_surface.blit(rage_text, (WIDTH//2 - rage_text.get_width()//2, HEIGHT//2))
                
                timer_text = small_font.render(f"타이머: {animated_bg.boss_rage_timer}/100", True, WHITE)
                temp_surface.blit(timer_text, (WIDTH//2 - timer_text.get_width()//2, HEIGHT//2 + 40))
            
            offset_text = small_font.render(
                f"흔들림: ({screen_shake_offset_x}, {screen_shake_offset_y})", 
                True, WHITE
            )
            temp_surface.blit(offset_text, (10, 10))
            
            # 오프셋 적용하여 화면에 그리기
            screen.fill(BLACK)
            screen.blit(temp_surface, (screen_shake_offset_x, screen_shake_offset_y))
        else:
            # 흔들림 없을 때
            screen.fill(GREEN)
            
            # 보스 그리기
            pygame.draw.rect(screen, WHITE, boss_rect)
            pygame.draw.rect(screen, BLACK, boss_rect, 2)
            
            # 정보 텍스트
            score_text = font.render(f"Player: {player_score} | Boss: {boss_score}", True, WHITE)
            screen.blit(score_text, (WIDTH//2 - score_text.get_width()//2, HEIGHT - 100))
            
            if animated_bg.boss_rage_pending:
                pending_text = font.render("⚠️ 보스 분노 대기중...", True, RED)
                screen.blit(pending_text, (WIDTH//2 - pending_text.get_width()//2, HEIGHT//2))
        
        # 조작법
        controls = [
            "SPACE: 보스 분노 트리거",
            "1: 플레이어 점수 +1",
            "2: 보스 점수 +1",
            "R: 리셋",
            "ESC: 종료"
        ]
        y = HEIGHT - 250
        for control in controls:
            text = small_font.render(control, True, (200, 200, 200))
            screen.blit(text, (10, y))
            y += 25
        
        pygame.display.flip()
        clock.tick(FPS)
    
    pygame.quit()

if __name__ == "__main__":
    print("=" * 60)
    print("Stage 2 보스 발구르기 화면 흔들림 테스트")
    print("=" * 60)
    print("테스트 시나리오:")
    print("1. 플레이어 점수를 2점으로 설정 (키 1 두 번)")
    print("2. SPACE 키로 보스 분노 애니메이션 시작")
    print("3. 발구르기 동안 화면 흔들림 확인")
    print("4. 바위 떨어지는 동안(80-100 프레임) 흔들림 지속 확인")
    print("=" * 60)
    print("\n수정 내용:")
    print("✅ stomp_shake_offset_x/y 변수 추가")
    print("✅ 발구르기 시 화면 흔들림 효과 (15프레임마다)")
    print("✅ 착지 시 더 강한 흔들림")
    print("✅ 최종 발구르기(80프레임)에 가장 강한 흔들림")
    print("✅ 바위 떨어지는 동안 지속적인 흔들림")
    print("=" * 60)
    
    test_stomp_shake()