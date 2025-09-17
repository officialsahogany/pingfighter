import pygame
import math

class AmmoBox:
    """탄약상자 액티브 아이템 - 활성화된 화기류의 탄창을 재장전"""
    def __init__(self):
        self.active = False
        self.duration = 0  # 즉시 사용형 아이템
        self.reload_animation_timer = 0  # 재장전 애니메이션 타이머
        self.RELOAD_ANIMATION_TIME = 60  # 1초간 재장전 애니메이션
        self.reload_progress = 0  # 재장전 진행도 (0~1)
        self.reloaded_weapon = None  # 재장전된 무기 이름
        
        # 지원하는 화기류 목록
        self.supported_weapons = ["pistol", "bazooka", "ak47"]  # 권총, 바주카포, AK-47 재장전 가능
        
    def activate(self, game_state, current_stage):
        """탄약상자 사용 - 플레이어가 소지한 모든 화기류의 탄약을 100% 충전"""
        self.active = True
        self.reload_animation_timer = self.RELOAD_ANIMATION_TIME
        self.reload_progress = 0
        self.reloaded_weapons = []  # 재장전된 무기들 리스트
        
        # 플레이어가 소지한 화기류 목록 확인
        try:
            from pingfighter import soldier_weapons
            print(f"📦 탄약상자 사용! 소지 화기류: {soldier_weapons}")
        except:
            soldier_weapons = []
        
        # 권총은 pingfighter.py에서 직접 재장전 처리
        self.reloaded_weapons.append("pistol")  # 애니메이션 표시용
        
        # 바주카포 재장전
        if "bazooka" in soldier_weapons:
            try:
                from item_effects.bazooka import get_bazooka_instance
                bazooka = get_bazooka_instance()
                
                if bazooka and bazooka.ammo_count < bazooka.max_ammo:
                    prev_ammo = bazooka.ammo_count
                    bazooka.ammo_count = bazooka.max_ammo
                    self.reloaded_weapons.append("bazooka")
                    print(f"   🚀 바주카포 재장전: {prev_ammo} → {bazooka.ammo_count}")
                    
            except ImportError:
                pass
        
        # AK-47 재장전
        if "ak47" in soldier_weapons:
            try:
                from item_effects.ak47 import get_ak47_instance
                ak47 = get_ak47_instance()
                
                if ak47 and ak47.active and ak47.current_ammo < ak47.max_ammo:
                    prev_ammo = ak47.current_ammo
                    ak47.current_ammo = ak47.max_ammo
                    self.reloaded_weapons.append("ak47")
                    print(f"   🔫 AK-47 재장전: {prev_ammo} → {ak47.current_ammo}")
                    
            except ImportError:
                pass
        
        # 재장전된 무기가 있는지 확인
        if self.reloaded_weapons:
            print(f"📦 탄약상자: {len(self.reloaded_weapons)}개 화기류 재장전 완료!")
            # 첫 번째 재장전된 무기를 애니메이션용으로 선택
            self.reloaded_weapon = self.reloaded_weapons[0]
            return True
        else:
            print("📦 탄약상자: 재장전할 화기류가 없거나 이미 만충전 상태입니다!")
            self.active = False
            return False
        
    def update(self, current_stage):
        """업데이트 - 재장전 애니메이션 진행"""
        if not self.active:
            return
            
        if self.reload_animation_timer > 0:
            self.reload_animation_timer -= 1
            # 재장전 진행도 계산 (0~1)
            self.reload_progress = 1.0 - (self.reload_animation_timer / self.RELOAD_ANIMATION_TIME)
            
            # 애니메이션 종료
            if self.reload_animation_timer <= 0:
                self.active = False
                self.reload_progress = 0
                self.reloaded_weapon = None
                
    def draw_effects(self, screen, **kwargs):
        """재장전 애니메이션 효과 그리기"""
        if not self.active or self.reload_animation_timer <= 0:
            return
            
        player_rect = kwargs.get('player_rect')
        if not player_rect:
            return
            
        # 재장전 애니메이션 위치 (플레이어 위)
        center_x = player_rect.centerx
        center_y = player_rect.top - 40
        
        # 탄약상자 아이콘 (애니메이션)
        box_size = int(20 + math.sin(self.reload_progress * math.pi) * 10)  # 크기 변화
        box_rect = pygame.Rect(center_x - box_size//2, center_y - box_size//2, box_size, box_size)
        
        # 상자 본체 (갈색)
        pygame.draw.rect(screen, (139, 69, 19), box_rect)
        pygame.draw.rect(screen, (101, 67, 33), box_rect, 2)
        
        # 상자 십자 표시
        cross_size = box_size // 3
        pygame.draw.line(screen, (255, 255, 255), 
                        (center_x - cross_size, center_y),
                        (center_x + cross_size, center_y), 3)
        pygame.draw.line(screen, (255, 255, 255),
                        (center_x, center_y - cross_size),
                        (center_x, center_y + cross_size), 3)
        
        # 탄약 재장전 효과 (1발씩 올라가는 애니메이션)
        if self.reloaded_weapon == "bazooka":
            # 바주카포 탄약 (3발)
            for i in range(3):
                # 각 탄약의 애니메이션 타이밍
                bullet_progress = max(0, min(1, (self.reload_progress * 3) - i))
                if bullet_progress > 0:
                    # 탄약 위치 (아래에서 위로)
                    bullet_y = center_y + 20 - int(bullet_progress * 40)
                    bullet_x = center_x + (i - 1) * 15
                    
                    # 탄약 그리기 (작은 로켓)
                    bullet_rect = pygame.Rect(bullet_x - 3, bullet_y - 8, 6, 16)
                    pygame.draw.rect(screen, (100, 100, 100), bullet_rect)
                    
                    # 탄두 (빨간색)
                    warhead_points = [
                        (bullet_x, bullet_y - 10),
                        (bullet_x - 3, bullet_y - 5),
                        (bullet_x + 3, bullet_y - 5)
                    ]
                    pygame.draw.polygon(screen, (200, 50, 50), warhead_points)
                    
                    # 빛나는 효과
                    glow_alpha = int(255 * (1 - bullet_progress))
                    if glow_alpha > 0:
                        pygame.draw.circle(screen, (255, 255, 200), (bullet_x, bullet_y), 8, 1)
                        
        elif self.reloaded_weapon == "ak47":
            # AK-47 탄약 (30발 - 간단히 표현)
            # 탄창 모양으로 올라가는 애니메이션
            mag_progress = self.reload_progress
            if mag_progress > 0:
                # 탄창 위치 (아래에서 위로)
                mag_y = center_y + 20 - int(mag_progress * 40)
                mag_x = center_x
                
                # AK-47 탄창 그리기 (특징적인 곡선형)
                mag_rect = pygame.Rect(mag_x - 6, mag_y - 15, 12, 30)
                pygame.draw.rect(screen, (60, 50, 30), mag_rect)
                pygame.draw.rect(screen, (40, 30, 20), mag_rect, 2)
                
                # 탄약 표시 (노란색 점들)
                for i in range(3):
                    bullet_y = mag_y - 10 + i * 10
                    pygame.draw.circle(screen, (255, 215, 0), (mag_x, bullet_y), 2)
                
                # 빛나는 효과
                glow_alpha = int(255 * (1 - mag_progress))
                if glow_alpha > 0:
                    pygame.draw.rect(screen, (255, 255, 200), mag_rect.inflate(4, 4), 1)
        
        # 재장전 완료 텍스트
        if self.reload_progress > 0.8:
            try:
                import pygame.freetype
                font = pygame.freetype.Font(None, 20)
                text = "재장전 완료!"
                text_surface, text_rect = font.render(text, (255, 255, 100))
                text_rect.center = (center_x, center_y - 30)
                screen.blit(text_surface, text_rect)
            except:
                pass
                
    def reset(self):
        """아이템 효과 리셋"""
        self.active = False
        self.reload_animation_timer = 0
        self.reload_progress = 0
        self.reloaded_weapon = None

# 싱글톤 인스턴스
ammo_box_instance = None

def get_ammo_box_instance():
    global ammo_box_instance
    if ammo_box_instance is None:
        ammo_box_instance = AmmoBox()
    return ammo_box_instance