import pygame
import math
import time

class AK47:
    def __init__(self):
        self.active = False
        self.duration = 1800  # 30초 (30 * 60 FPS)
        self.remaining_time = 0
        
        # 총알 관련 설정
        self.max_ammo = 30
        self.current_ammo = 30
        self.reload_time = 120  # 2초 (120 프레임)
        self.reloading = False
        self.reload_timer = 0
        
        # 발사 관련 설정
        self.fire_rate = 6  # 0.1초 = 6 프레임 at 60 FPS
        self.last_shot_time = 0
        self.is_firing = False
        
        # 총알 리스트
        self.bullets = []
        
        # 사운드 효과 (나중에 추가 가능)
        self.shot_sound = None
        self.reload_sound = None
        
    def activate(self, game_state, current_stage):
        """AK-47 활성화"""
        self.active = True
        self.remaining_time = self.duration
        self.current_ammo = self.max_ammo
        self.reloading = False
        self.reload_timer = 0
        print("AK-47 활성화! 30발 연사 가능")
        
    def update(self, current_stage):
        """AK-47 업데이트 (매 프레임 호출)"""
        if not self.active:
            return
            
        # 지속시간 감소
        self.remaining_time -= 1
        if self.remaining_time <= 0:
            self.deactivate()
            return
            
        # AK-47은 재장전 없음 - 탄약 소진시 사라짐
                
        # 총알 업데이트
        self.update_bullets(current_stage)
        
        # 발사 쿨타임 업데이트
        if self.last_shot_time > 0:
            self.last_shot_time -= 1
            
    def can_fire(self):
        """발사 가능한지 확인"""
        return (self.active and 
                not self.reloading and 
                self.current_ammo > 0 and 
                self.last_shot_time <= 0)
                
    def fire(self, player_rect, ball_rect):
        """AK-47 발사"""
        if not self.can_fire():
            return False
            
        # 총알 생성
        bullet = self.create_bullet(player_rect, ball_rect)
        if bullet:
            self.bullets.append(bullet)
            self.current_ammo -= 1
            self.last_shot_time = self.fire_rate
            
            # 탄창이 비었으면 더 이상 발사 불가 (무기는 유지)
            if self.current_ammo <= 0:
                print("AK-47 탄약 소진! 재장전이 필요합니다.")
                
            return True
        return False
        
    def create_bullet(self, player_rect, ball_rect):
        """총알 생성"""
        # 플레이어 중심에서 공 방향으로 총알 발사
        start_x = player_rect.centerx
        start_y = player_rect.centery
        
        # 공 방향 계산
        dx = ball_rect.centerx - start_x
        dy = ball_rect.centery - start_y
        distance = math.sqrt(dx*dx + dy*dy)
        
        if distance == 0:
            return None
            
        # 정규화
        dx /= distance
        dy /= distance
        
        # 총알 속도 (빠른 속도)
        speed = 15
        
        bullet = {
            'x': start_x,
            'y': start_y,
            'dx': dx * speed,
            'dy': dy * speed,
            'life': 60  # 1초간 존재
        }
        
        return bullet
        
    def start_reload(self):
        """재장전 시작 - AK-47은 재장전 불가"""
        # AK-47은 재장전이 없고 탄약 소진 시 사라짐
        pass
            
    def update_bullets(self, current_stage):
        """총알 업데이트"""
        bullets_to_remove = []
        
        for i, bullet in enumerate(self.bullets):
            # 총알 이동
            bullet['x'] += bullet['dx']
            bullet['y'] += bullet['dy']
            bullet['life'] -= 1
            
            # 화면 밖으로 나가거나 수명이 다한 총알 제거
            if (bullet['life'] <= 0 or 
                bullet['x'] < 0 or bullet['x'] > 800 or
                bullet['y'] < 0 or bullet['y'] > 600):
                bullets_to_remove.append(i)
                continue
                
            # 공과의 충돌 검사 (stage가 객체인 경우에만)
            if hasattr(current_stage, 'ball_x') and hasattr(current_stage, 'ball_y'):
                ball_rect = pygame.Rect(current_stage.ball_x - 10, current_stage.ball_y - 10, 20, 20)
                bullet_rect = pygame.Rect(bullet['x'] - 3, bullet['y'] - 3, 6, 6)
                
                if bullet_rect.colliderect(ball_rect):
                    # 공에 넉백 효과 적용
                    self.apply_knockback(current_stage, bullet)
                    bullets_to_remove.append(i)
                
        # 제거할 총알들 삭제 (역순으로)
        for i in reversed(bullets_to_remove):
            del self.bullets[i]
            
    def apply_knockback(self, current_stage, bullet):
        """공에 넉백 효과 적용"""
        # stage가 객체이고 ball 속도 속성이 있는 경우에만 넉백 적용
        if (hasattr(current_stage, 'ball_dx') and hasattr(current_stage, 'ball_dy')):
            # 짧은 거리 넉백 (기존 속도에 추가)
            knockback_power = 5
            current_stage.ball_dx += bullet['dx'] * knockback_power / 15  # 총알 속도 기준으로 조정
            current_stage.ball_dy += bullet['dy'] * knockback_power / 15
            
            # 속도 제한 (너무 빨라지지 않도록)
            max_speed = 12
            current_speed = math.sqrt(current_stage.ball_dx**2 + current_stage.ball_dy**2)
            if current_speed > max_speed:
                current_stage.ball_dx = (current_stage.ball_dx / current_speed) * max_speed
                current_stage.ball_dy = (current_stage.ball_dy / current_speed) * max_speed
            
    def draw_bullets(self, screen):
        """총알 그리기"""
        for bullet in self.bullets:
            # 노란색 총알
            pygame.draw.circle(screen, (255, 255, 0), 
                             (int(bullet['x']), int(bullet['y'])), 3)
            # 총알 궤적 효과
            pygame.draw.circle(screen, (255, 255, 100), 
                             (int(bullet['x']), int(bullet['y'])), 2)
                             
    def draw_ui(self, screen, font):
        """UI 표시 (탄창, 재장전 상태 등)"""
        if not self.active:
            return
            
        # 탄창 표시
        ammo_text = f"AK-47: {self.current_ammo}/{self.max_ammo}"
            
        text_surface = font.render(ammo_text, True, (255, 255, 255))
        screen.blit(text_surface, (10, 80))
        
        # 지속시간 표시
        time_left = self.remaining_time // 60
        time_text = f"시간: {time_left}초"
        time_surface = font.render(time_text, True, (255, 255, 255))
        screen.blit(time_surface, (10, 100))
        
    def deactivate(self):
        """AK-47 비활성화"""
        self.active = False
        self.bullets.clear()
        self.current_ammo = self.max_ammo
        self.reloading = False
        print("AK-47 효과 종료")

# 싱글톤 인스턴스
ak47_instance = None

def get_ak47_instance():
    global ak47_instance
    if ak47_instance is None:
        ak47_instance = AK47()
    return ak47_instance