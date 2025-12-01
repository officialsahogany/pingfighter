import math
import random
import sys
from typing import Callable

import pygame

class Bazooka:
    """바주카포 화기류 아이템"""
    def __init__(self):
        self.active = False
        self.equipped = False  # 현재 장착 중인지
        self.ammo_count = 4  # 총알 4개
        self.max_ammo = 4
        self.cooldown_timer = 0  # 발사 쿨타임
        self.COOLDOWN_TIME = 120  # 2초 쿨타임 (60fps)
        self.CONTROL_LOCK_TIME = 30  # 통제불능 시간 0.5초 (60fps)
        self.control_lock_timer = 0
        
        # 발사체 관련
        self.projectiles = []  # 발사체 리스트
        self.INITIAL_SPEED = 3  # 초기 속도 (매우 느림)
        self.ACCELERATION = 0.8  # 가속도 (기존 0.3에서 증가)
        self.MAX_SPEED = 35  # 최대 속도 (기존 25에서 증가)
        self.EXPLOSION_RADIUS = 110  # 폭발 범위 (수류탄 150의 약 73%)
        self.KNOCKBACK_POWER = 40  # 넉백 거리 (수류탄과 동일)
        self.STUN_DURATION = 90  # 스턴 시간 1.5초 (수류탄보다 0.5초 짧음)
        
        # 플레이어 반동 관련
        self.player_knockback = {
            "direction": 0,  # -1: 왼쪽, 1: 오른쪽
            "strength": 0,   # 넉백 거리
            "active": False  # 넉백 활성화 여부
        }
        
        # 애니메이션 관련
        self.fire_animation_timer = 0
        self.muzzle_flash_timer = 0
        self.firing_pose_timer = 0  # 발사 자세 애니메이션 타이머
        
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
            
        # 발사체 생성 (수직 상방향, 가속도 시스템)
        projectile = {
            "x": player_rect.centerx,
            "y": player_rect.top - 20,
            "vel_x": 0,  # 수직 직선
            "vel_y": -self.INITIAL_SPEED,  # 초기 느린 속도
            "speed": self.INITIAL_SPEED,  # 현재 속도
            "active": True,
            "start_time": current_time,
            "smoke_trail": []  # 연기 궤적
        }
        
        # 플레이어 반동 넉백 비활성화
        # knockback_direction = random.choice([-1, 1])  # -1: 왼쪽, 1: 오른쪽
        # knockback_strength = 30  # 넉백 거리
        
        # 반동 데이터 비활성화
        self.player_knockback = {
            "direction": 0,
            "strength": 0,
            "active": False
        }
        
        self.projectiles.append(projectile)
        self.ammo_count -= 1
        self.cooldown_timer = self.COOLDOWN_TIME
        self.control_lock_timer = self.CONTROL_LOCK_TIME
        self.fire_animation_timer = 15  # 발사 애니메이션
        self.muzzle_flash_timer = 5  # 총구 화염
        self.firing_pose_timer = self.CONTROL_LOCK_TIME  # 발사 자세 지속 시간

        if self.ammo_count <= 0:
            self.ammo_count = 0
            self.active = False

        print(f"🚀 바주카포 발사! 남은 탄약: {self.ammo_count}")
        return True
        
    def reload_with_special_ammo(self, *, track_reload: bool = False, announce: bool = True):
        """특수탄약으로 재장전"""
        self.ammo_count = self.max_ammo
        self.active = True
        if announce:
            print(f"🚀 바주카포 재장전 완료! 탄약: {self.ammo_count}/{self.max_ammo}")

        if track_reload:
            register = self._get_reload_tracker()
            if register:
                register("bazooka")

    def get_player_knockback(self):
        """플레이어 넉백 정보 반환"""
        if self.player_knockback["active"]:
            # 넉백 정보 반환 후 비활성화
            knockback_data = self.player_knockback.copy()
            self.player_knockback["active"] = False
            return knockback_data
        return None
        
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
        if self.firing_pose_timer > 0:
            self.firing_pose_timer -= 1
            
        # 발사체 업데이트
        for projectile in self.projectiles[:]:
            if not projectile["active"]:
                self.projectiles.remove(projectile)
                continue
            
            # 연기 궤적 추가 (현재 위치 저장)
            if len(projectile["smoke_trail"]) == 0 or \
               abs(projectile["x"] - projectile["smoke_trail"][-1][0]) > 5 or \
               abs(projectile["y"] - projectile["smoke_trail"][-1][1]) > 5:
                projectile["smoke_trail"].append((projectile["x"], projectile["y"]))
                
            # 연기 궤적 길이 제한 (최대 10개 지점)
            if len(projectile["smoke_trail"]) > 10:
                projectile["smoke_trail"].pop(0)
            
            # 가속도 적용
            if projectile["speed"] < self.MAX_SPEED:
                projectile["speed"] += self.ACCELERATION
                projectile["vel_y"] = -projectile["speed"]  # 수직 상방향 이동
                
            # 위치 업데이트
            projectile["x"] += projectile["vel_x"]
            projectile["y"] += projectile["vel_y"]

            # 화면 상단 벽(보스 뒷벽)에 도달하면 벽 충돌로 처리 (check_wall_collision에서 폭발)
            # y < -50 제거 조건을 완화하여 벽 충돌 체크가 먼저 발생하도록 함
            if projectile["y"] < -100:  # 벽 충돌 체크 이후에도 남아있으면 제거
                projectile["active"] = False
                
    def check_boss_collision(self, boss_rect, screen_width=800):
        """보스와의 충돌 체크 (보스 패들 + 뒷벽 포함)"""
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
            
            # 보스 패들과 충돌 체크
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
                print(f"💥 바주카포 보스 패들 명중! 폭발 범위: {self.EXPLOSION_RADIUS}px")
                
        return explosions

    def _get_reload_tracker(self) -> Callable[[str], None] | None:
        for module_name in ("__main__", "pingfighter"):
            module = sys.modules.get(module_name)
            if not module:
                continue
            candidate = getattr(module, "register_weapon_reload", None)
            if callable(candidate):
                return candidate
            controller = getattr(module, "soldier_controller", None)
            name_resolver = getattr(module, "get_item_name_korean", None)
            if controller and hasattr(controller, "register_reload"):
                def fallback(weapon: str, *, _controller=controller, _resolver=name_resolver) -> None:
                    if weapon == "pistol":
                        return
                    try:
                        degraded = _controller.register_reload(weapon)
                    except Exception:
                        return
                    if degraded:
                        try:
                            label = _resolver(weapon) if callable(_resolver) else weapon
                            print(f"⚠️ {label} 노후화!")
                        except Exception:
                            print(f"⚠️ {weapon} 노후화!")

                return fallback
        return None
        
    def check_wall_collision(self):
        """벽과의 충돌 체크 (화면 경계)"""
        explosions = []
        
        for projectile in self.projectiles[:]:
            if not projectile["active"]:
                continue
                
            # 화면 상단 벽과 충돌 체크 (y <= 20)
            if projectile["y"] <= 20:
                # 뒷벽 폭발 생성
                explosion = {
                    "x": projectile["x"],
                    "y": 20,  # 벽 위치에서 폭발
                    "radius": self.EXPLOSION_RADIUS,
                    "knockback": self.KNOCKBACK_POWER,
                    "stun_duration": self.STUN_DURATION
                }
                explosions.append(explosion)
                
                # 발사체 제거
                projectile["active"] = False
                print(f"💥 바주카포 벽 충돌! 폭발 범위: {self.EXPLOSION_RADIUS}px")
                
            # 화면 좌우 벽과 충돌 체크
            elif projectile["x"] <= 10 or projectile["x"] >= 790:
                # 측벽 폭발 생성
                explosion = {
                    "x": max(10, min(790, projectile["x"])),  # 화면 내 위치로 조정
                    "y": projectile["y"],
                    "radius": self.EXPLOSION_RADIUS,
                    "knockback": self.KNOCKBACK_POWER,
                    "stun_duration": self.STUN_DURATION
                }
                explosions.append(explosion)
                
                # 발사체 제거
                projectile["active"] = False
                print(f"💥 바주카포 측벽 충돌! 폭발 범위: {self.EXPLOSION_RADIUS}px")
                
        return explosions
        
    def draw_projectiles(self, screen):
        """발사체 그리기"""
        for projectile in self.projectiles:
            if not projectile["active"]:
                continue
                
            x, y = int(projectile["x"]), int(projectile["y"])
            
            # 연기 궤적 그리기 (미사일 뒤쪽)
            smoke_trail = projectile.get("smoke_trail", [])
            if len(smoke_trail) > 1:
                for i, (trail_x, trail_y) in enumerate(smoke_trail):
                    # 궤적이 오래될수록 흐릿해짐
                    alpha_factor = (i + 1) / len(smoke_trail)
                    smoke_size = int(3 + alpha_factor * 4)  # 3~7px
                    smoke_alpha = int(80 * alpha_factor)  # 투명도
                    
                    # 연기 색상 (회색에서 검은색으로)
                    smoke_color = (smoke_alpha, smoke_alpha, smoke_alpha)
                    if smoke_alpha > 0:
                        pygame.draw.circle(screen, smoke_color, 
                                         (int(trail_x), int(trail_y)), smoke_size)
                        
                        # 내부 연기 (조금 더 밝게)
                        inner_alpha = min(smoke_alpha + 30, 120)
                        inner_color = (inner_alpha, inner_alpha, inner_alpha)
                        inner_size = max(1, smoke_size - 1)
                        pygame.draw.circle(screen, inner_color,
                                         (int(trail_x), int(trail_y)), inner_size)
            
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
            
            # 추진부 화염 (속도에 따라 크기 변화)
            speed_factor = projectile.get("speed", self.INITIAL_SPEED) / self.MAX_SPEED
            base_flame_height = int(8 + speed_factor * 12)  # 8~20px
            flame_height = base_flame_height + random.randint(-2, 2)
            flame_width = int(3 + speed_factor * 3)  # 3~6px
            
            flame_points = [
                (x - flame_width, y + 15),
                (x, y + 15 + flame_height),
                (x + flame_width, y + 15)
            ]
            
            # 외부 화염 (주황색, 속도에 따라 색상 강화)
            flame_red = min(255, int(200 + speed_factor * 55))
            flame_color = (flame_red, 150, int(50 * speed_factor))
            pygame.draw.polygon(screen, flame_color, flame_points)
            
            # 내부 화염 (노란색)
            inner_flame_points = [
                (x - flame_width//2, y + 15),
                (x, y + 15 + flame_height - 3),
                (x + flame_width//2, y + 15)
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
    
    def draw_firing_pose(self, screen, player_rect):
        """바주카포 발사 자세 그리기"""
        if self.firing_pose_timer <= 0:
            return
            
        # 애니메이션 진행도 (1.0 -> 0.0)
        progress = self.firing_pose_timer / self.CONTROL_LOCK_TIME
        
        # 패들 중심 좌표
        center_x = player_rect.centerx
        center_y = player_rect.centery
        
        # 반동 효과 (발사 직후 뒤로 밀림)
        recoil_offset = int(3 * progress) if self.fire_animation_timer > 0 else 0
        
        # 군인 몸체 (발사 자세)
        body_width = 25
        body_height = 15
        body_rect = pygame.Rect(
            center_x - body_width//2 + recoil_offset, 
            center_y - body_height//2, 
            body_width, 
            body_height
        )
        
        # 군인 몸체 그리기 (군복 색상)
        pygame.draw.rect(screen, (60, 80, 40), body_rect)  # 어두운 군복 녹색
        pygame.draw.rect(screen, (40, 60, 20), body_rect, 2)  # 테두리
        
        # 바주카포 발사기 (오른쪽 어깨 위 수직 위치)
        bazooka_length = 50
        bazooka_width = 8
        # 오른쪽 어깨 위에 수직으로 위치
        shoulder_x = center_x + 12 + recoil_offset  # 오른쪽 어깨 위치
        shoulder_y = center_y - 10  # 어깨 높이
        bazooka_x = shoulder_x - bazooka_width//2  # 수직이므로 width가 x방향
        bazooka_y = shoulder_y - bazooka_length  # 위쪽으로 길게 뻗음
        
        # 바주카포 본체 (수직 방향으로 회전, 어두운 금속색)
        bazooka_rect = pygame.Rect(bazooka_x, bazooka_y, bazooka_width, bazooka_length)
        pygame.draw.rect(screen, (40, 40, 45), bazooka_rect)
        pygame.draw.rect(screen, (30, 30, 35), bazooka_rect, 2)
        
        # 바주카포 총구 (위쪽 원형)
        muzzle_x = bazooka_x + bazooka_width//2
        muzzle_y = bazooka_y
        pygame.draw.circle(screen, (30, 30, 35), (muzzle_x, muzzle_y), bazooka_width//2 + 2)
        pygame.draw.circle(screen, (20, 20, 25), (muzzle_x, muzzle_y), bazooka_width//2)
        
        # 조준경/손잡이 (수직 위치에 맞게 조정)
        sight_x = bazooka_x + bazooka_width + 2
        sight_y = bazooka_y + bazooka_length//3
        pygame.draw.rect(screen, (50, 50, 55), (sight_x, sight_y, 4, 8))
        
        # 군인 머리 (헬멧)
        head_size = 8
        head_x = center_x - head_size//2 + recoil_offset - 5  # 약간 뒤쪽
        head_y = center_y - head_size//2 - 8
        
        pygame.draw.rect(screen, (40, 60, 20), (head_x, head_y, head_size, head_size))  # 헬멧
        pygame.draw.rect(screen, (30, 45, 15), (head_x, head_y, head_size, head_size), 1)
        
        # 오른쪽 팔 (바주카포를 지지하는 자세)
        right_arm_points = [
            (center_x + 8 + recoil_offset, center_y - 3),  # 오른쪽 어깨
            (shoulder_x, shoulder_y - 5),  # 바주카포 아래쪽 지지점
            (shoulder_x + 3, shoulder_y),  # 손목
            (center_x + 12 + recoil_offset, center_y + 3)   # 몸쪽
        ]
        pygame.draw.polygon(screen, (50, 70, 30), right_arm_points)
        
        # 왼쪽 팔 (바주카포 중간 지지)
        left_arm_points = [
            (center_x - 8 + recoil_offset, center_y - 2),  # 왼쪽 어깨
            (bazooka_x - 3, bazooka_y + bazooka_length//2),  # 바주카포 중간 지지점
            (bazooka_x + 2, bazooka_y + bazooka_length//2 + 3),  # 손목
            (center_x - 5 + recoil_offset, center_y + 2)   # 몸쪽
        ]
        pygame.draw.polygon(screen, (50, 70, 30), left_arm_points)
        
        # 총구 화염 효과 (수직 위쪽으로 발사)
        if self.muzzle_flash_timer > 0:
            flash_length = 20 + random.randint(-3, 3)
            flash_width = 12 + random.randint(-2, 2)
            
            # 화염 본체 (밝은 주황색) - 위쪽 방향
            flash_points = [
                (muzzle_x - flash_width//2, muzzle_y),
                (muzzle_x - flash_width//4, muzzle_y - flash_length),
                (muzzle_x, muzzle_y - flash_length - 5),
                (muzzle_x + flash_width//4, muzzle_y - flash_length),
                (muzzle_x + flash_width//2, muzzle_y)
            ]
            pygame.draw.polygon(screen, (255, 200, 50), flash_points)
            
            # 내부 화염 (밝은 노란색) - 위쪽 방향
            inner_flash_points = [
                (muzzle_x - flash_width//3, muzzle_y),
                (muzzle_x - flash_width//6, muzzle_y - flash_length//2),
                (muzzle_x, muzzle_y - flash_length//2 - 3),
                (muzzle_x + flash_width//6, muzzle_y - flash_length//2),
                (muzzle_x + flash_width//3, muzzle_y)
            ]
            pygame.draw.polygon(screen, (255, 255, 200), inner_flash_points)
            
            # 연기 효과 (위쪽 방향)
            for i in range(3):
                smoke_x = muzzle_x + random.randint(-5, 5)
                smoke_y = muzzle_y - flash_length - i * 8 + random.randint(-2, 2)
                smoke_radius = 4 + i
                smoke_alpha = 100 - i * 25
                smoke_color = (smoke_alpha, smoke_alpha, smoke_alpha)
                pygame.draw.circle(screen, smoke_color, (smoke_x, smoke_y), smoke_radius)
        
        # 발사 반동 효과선
        if self.fire_animation_timer > 0:
            for i in range(3):
                line_x = center_x + 20 + i * 8 + recoil_offset
                line_y1 = center_y - 5 + i * 2
                line_y2 = center_y + 5 - i * 2
                line_alpha = 255 - i * 60
                line_color = (line_alpha, line_alpha//2, 0)
                pygame.draw.line(screen, line_color, (line_x, line_y1), (line_x, line_y2), 2)

# 싱글톤 인스턴스
bazooka_instance = None

def get_bazooka_instance():
    global bazooka_instance
    if bazooka_instance is None:
        bazooka_instance = Bazooka()
    return bazooka_instance
