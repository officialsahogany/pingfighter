import pygame
import math
import random

class Bazooka:
    """바주카포 화기류 아이템"""
    def __init__(self):
        self.active = False
        self.equipped = False  # 현재 장착 중인지
        self.ammo_count = 3  # 총알 3개
        self.max_ammo = 3
        self.cooldown_timer = 0  # 발사 쿨타임
        self.COOLDOWN_TIME = 120  # 2초 쿨타임 (60fps)
        self.CONTROL_LOCK_TIME = 42  # 통제불능 시간 0.7초 (60fps)
        self.control_lock_timer = 0
        
        # 발사체 관련
        self.projectiles = []  # 발사체 리스트
        self.PROJECTILE_SPEED = 15  # 발사체 속도
        self.EXPLOSION_RADIUS = 80  # 폭발 범위
        self.KNOCKBACK_POWER = 30  # 넉백 거리 (권총의 2배)
        self.STUN_DURATION = 120  # 스턴 시간 2초 (60fps)
        
        # 애니메이션 관련
        self.fire_animation_timer = 0
        self.muzzle_flash_timer = 0
        
    def equip(self):
        """바주카포 장착"""
        self.equipped = True
        self.active = True
        print("🚀 바주카포 장착!")
        
    def unequip(self):
        """바주카포 해제"""
        self.equipped = False
        self.active = False
        print("🔫 바주카포 해제!")
        
    def can_fire(self):
        """발사 가능 여부 확인"""
        return (self.equipped and 
                self.ammo_count > 0 and 
                self.cooldown_timer <= 0 and 
                self.control_lock_timer <= 0)
    
    def fire(self, player_rect, current_time):
        """바주카포 발사"""
        if not self.can_fire():
            return False
            
        # 발사체 생성 (수직 상방향)
        projectile = {
            "x": player_rect.centerx,
            "y": player_rect.top - 20,
            "vel_x": 0,  # 수직 직선
            "vel_y": -self.PROJECTILE_SPEED,
            "active": True,
            "start_time": current_time
        }
        
        self.projectiles.append(projectile)
        self.ammo_count -= 1
        self.cooldown_timer = self.COOLDOWN_TIME
        self.control_lock_timer = self.CONTROL_LOCK_TIME
        self.fire_animation_timer = 15  # 발사 애니메이션
        self.muzzle_flash_timer = 5  # 총구 화염
        
        print(f"🚀 바주카포 발사! 남은 탄약: {self.ammo_count}")
        return True
        
    def reload_with_special_ammo(self):
        """특수탄약으로 재장전"""
        self.ammo_count = self.max_ammo
        print(f"🚀 바주카포 재장전 완료! 탄약: {self.ammo_count}/{self.max_ammo}")
        
    def update(self, dt):
        """업데이트"""
        # 타이머 업데이트
        if self.cooldown_timer > 0:
            self.cooldown_timer -= 1
        if self.control_lock_timer > 0:
            self.control_lock_timer -= 1
        if self.fire_animation_timer > 0:
            self.fire_animation_timer -= 1
        if self.muzzle_flash_timer > 0:
            self.muzzle_flash_timer -= 1
            
        # 발사체 업데이트
        for projectile in self.projectiles[:]:
            if not projectile["active"]:
                self.projectiles.remove(projectile)
                continue
                
            # 위치 업데이트
            projectile["x"] += projectile["vel_x"]
            projectile["y"] += projectile["vel_y"]
            
            # 화면 밖으로 나가면 제거
            if projectile["y"] < -50:
                projectile["active"] = False
                
    def check_boss_collision(self, boss_rect):
        """보스와의 충돌 체크"""
        explosions = []
        
        for projectile in self.projectiles[:]:
            if not projectile["active"]:
                continue
                
            # 발사체 히트박스
            projectile_rect = pygame.Rect(
                projectile["x"] - 10, 
                projectile["y"] - 10,
                20, 30
            )
            
            # 보스와 충돌 체크
            if projectile_rect.colliderect(boss_rect):
                # 폭발 생성
                explosion = {
                    "x": projectile["x"],
                    "y": projectile["y"],
                    "radius": self.EXPLOSION_RADIUS,
                    "knockback": self.KNOCKBACK_POWER,
                    "stun_duration": self.STUN_DURATION
                }
                explosions.append(explosion)
                
                # 발사체 제거
                projectile["active"] = False
                print(f"💥 바주카포 명중! 폭발 범위: {self.EXPLOSION_RADIUS}")
                
        return explosions
        
    def draw_projectiles(self, screen):
        """발사체 그리기"""
        for projectile in self.projectiles:
            if not projectile["active"]:
                continue
                
            x, y = int(projectile["x"]), int(projectile["y"])
            
            # 로켓 본체 (어두운 회색)
            body_rect = pygame.Rect(x - 4, y - 15, 8, 30)
            pygame.draw.rect(screen, (60, 60, 60), body_rect)
            pygame.draw.rect(screen, (40, 40, 40), body_rect, 2)
            
            # 탄두 (빨간색)
            warhead_points = [
                (x, y - 20),  # 꼭대기
                (x - 6, y - 10),  # 왼쪽
                (x + 6, y - 10)   # 오른쪽
            ]
            pygame.draw.polygon(screen, (200, 50, 50), warhead_points)
            pygame.draw.polygon(screen, (150, 30, 30), warhead_points, 2)
            
            # 추진부 화염
            flame_height = random.randint(8, 12)
            flame_points = [
                (x - 3, y + 15),
                (x, y + 15 + flame_height),
                (x + 3, y + 15)
            ]
            
            # 외부 화염 (주황색)
            pygame.draw.polygon(screen, (255, 150, 0), flame_points)
            
            # 내부 화염 (노란색)
            inner_flame_points = [
                (x - 2, y + 15),
                (x, y + 15 + flame_height - 3),
                (x + 2, y + 15)
            ]
            pygame.draw.polygon(screen, (255, 255, 150), inner_flame_points)
            
            # 연기 효과
            for i in range(3):
                smoke_y = y + 15 + i * 5
                smoke_radius = 3 + i
                smoke_alpha = 100 - i * 30
                smoke_color = (smoke_alpha, smoke_alpha, smoke_alpha)
                pygame.draw.circle(screen, smoke_color, (x, smoke_y), smoke_radius)
                
    def draw_explosion_effect(self, screen, explosion_x, explosion_y, progress):
        """폭발 효과 그리기"""
        # progress: 0.0 ~ 1.0
        max_radius = self.EXPLOSION_RADIUS
        current_radius = int(max_radius * progress)
        
        # 충격파
        if progress < 0.5:
            shockwave_radius = int(max_radius * 1.5 * progress * 2)
            shockwave_alpha = int(255 * (1 - progress * 2))
            pygame.draw.circle(screen, (255, 255, 255), 
                             (explosion_x, explosion_y), shockwave_radius, 3)
        
        # 폭발 구체
        if progress < 0.7:
            # 외부 폭발 (빨간색)
            explosion_color = (255, int(200 * (1 - progress)), 0)
            pygame.draw.circle(screen, explosion_color,
                             (explosion_x, explosion_y), current_radius)
            
            # 내부 코어 (흰색-노란색)
            core_radius = int(current_radius * 0.6)
            core_color = (255, 255, int(255 * (1 - progress)))
            pygame.draw.circle(screen, core_color,
                             (explosion_x, explosion_y), core_radius)
        
        # 파편 효과
        if progress < 0.8:
            fragment_count = 12
            for i in range(fragment_count):
                angle = (math.pi * 2 * i) / fragment_count
                distance = max_radius * progress * 1.5
                frag_x = explosion_x + int(math.cos(angle) * distance)
                frag_y = explosion_y + int(math.sin(angle) * distance)
                frag_size = int(5 * (1 - progress))
                pygame.draw.circle(screen, (255, 150, 0), (frag_x, frag_y), frag_size)

# 싱글톤 인스턴스
bazooka_instance = None

def get_bazooka_instance():
    global bazooka_instance
    if bazooka_instance is None:
        bazooka_instance = Bazooka()
    return bazooka_instance