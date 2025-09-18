import math
import random
from typing import List, Dict, Optional

import pygame

from config.constants import WIDTH, HEIGHT


class AK47:
    """군인 전용 자동소총 아이템 로직"""

    def __init__(self):
        self.active = False
        self.duration = 1800  # 30초 (30 * 60 FPS)
        self.remaining_time = 0

        # 탄약 및 발사 관련 설정
        self.max_ammo = 90
        self.current_ammo = 90
        self.fire_interval = 6  # 0.1초 간격 (60 FPS 기준)
        self.shot_cooldown = 0

        # 총알 설정
        self.bullet_speed = 16
        self.bullet_lifetime = 60  # 1초
        self.bullets: List[Dict[str, float]] = []
        
        # 정확도 관련 설정
        self.accuracy_spread_angle = 0.15  # 라디안 단위 (약 8.6도)
        self.recoil_accumulation = 0  # 연속 발사 시 반동 누적
        self.max_recoil = 0.15  # 최대 반동 각도 (라디안)
        self.recoil_recovery_rate = 0.02  # 프레임당 반동 회복률
        
        # 발사 모드 관련
        self.burst_mode = True  # 단발 모드에서는 2발 연사
        self.burst_shots_fired = 0  # 현재 버스트에서 발사한 총알 수
        self.burst_shots_required = 2  # 버스트당 발사할 총알 수
        self.is_firing = False  # 현재 발사 중인지 여부
        self.space_was_released = True  # 스페이스바가 떼어졌는지 추적
        
        # 이동속도 감소 관련
        self.movement_debuff = 0.5  # 연사 시 이동속도 50% 감소 (50%로 감소)

    # ------------------------------------------------------------------
    # 상태 관리
    # ------------------------------------------------------------------
    def activate(self, game_state, current_stage):
        """AK-47 활성화 및 상태 초기화"""
        self.active = True
        self.remaining_time = self.duration
        self.current_ammo = self.max_ammo
        self.shot_cooldown = 0
        self.bullets.clear()
        self.recoil_accumulation = 0  # 반동 초기화
        print("AK-47 활성화! 90발 연사 가능")

    def deactivate(self):
        """AK-47 비활성화"""
        self.active = False
        self.bullets.clear()
        self.current_ammo = self.max_ammo
        self.shot_cooldown = 0
        self.recoil_accumulation = 0  # 반동 초기화
        print("AK-47 효과 종료")

    # ------------------------------------------------------------------
    # 발사 로직
    # ------------------------------------------------------------------
    def can_fire(self) -> bool:
        """현재 발사 가능한지 여부 반환"""
        return (
            self.active
            and self.current_ammo > 0
            and self.shot_cooldown <= 0
        )

    def handle_space_input(self, space_pressed: bool) -> None:
        """스페이스바 입력 상태를 추적하고 버스트 모드를 관리한다."""
        if space_pressed:
            if self.space_was_released:
                # 스페이스를 처음 눌렀을 때 - 2발 연사 시작
                self.space_was_released = False
                self.burst_shots_fired = 0
                self.is_firing = True
            # 스페이스를 계속 누르고 있으면 연사 모드로 전환
            elif self.burst_shots_fired >= self.burst_shots_required:
                self.is_firing = True
        else:
            # 스페이스를 떼었을 때
            self.space_was_released = True
            self.is_firing = False
            self.burst_shots_fired = 0

    def fire(self, player_rect: pygame.Rect, target_rect: Optional[pygame.Rect]) -> bool:
        """총알을 생성하여 발사한다."""
        if not self.can_fire():
            return False

        bullet = self._create_bullet(player_rect, target_rect)
        if not bullet:
            return False

        self.bullets.append(bullet)
        self.current_ammo = max(0, self.current_ammo - 1)
        self.shot_cooldown = self.fire_interval
        
        # 연속 발사 시 반동 누적
        self.recoil_accumulation = min(self.recoil_accumulation + 0.03, self.max_recoil)

        if self.current_ammo == 0:
            print("AK-47 탄약 소진! 추가 발사가 불가합니다.")
        return True
    
    def should_fire(self) -> bool:
        """현재 발사해야 하는지 여부를 반환한다."""
        if not self.active or not self.is_firing:
            return False
            
        # 버스트 모드에서 2발만 발사
        if self.burst_shots_fired < self.burst_shots_required:
            if self.can_fire():
                self.burst_shots_fired += 1
                return True
        # 연사 모드 (스페이스를 계속 누르고 있을 때)
        elif self.space_was_released == False:
            return self.can_fire()
            
        return False

    def _create_bullet(self, player_rect: pygame.Rect, target_rect: Optional[pygame.Rect]) -> Optional[Dict[str, float]]:
        """플레이어 위치에서 목표를 향해 총알 데이터를 만든다."""
        start_x = player_rect.centerx
        start_y = player_rect.centery

        if target_rect is not None:
            target_x = target_rect.centerx
            target_y = target_rect.centery
        else:
            # 목표가 없으면 화면 중앙 상단으로 향하게 한다.
            target_x = start_x
            target_y = 0

        # 기본 방향 계산
        dx = target_x - start_x
        dy = target_y - start_y
        distance = math.hypot(dx, dy)
        if distance == 0:
            return None

        # 방향 정규화
        dx /= distance
        dy /= distance
        
        # 현재 각도 계산
        base_angle = math.atan2(dy, dx)
        
        # 정확도 오차 적용 (기본 분산 + 반동 누적)
        total_spread = self.accuracy_spread_angle + self.recoil_accumulation
        angle_offset = random.uniform(-total_spread, total_spread)
        
        # 최종 발사 각도
        final_angle = base_angle + angle_offset
        
        # 새로운 방향 벡터 계산
        final_dx = math.cos(final_angle) * self.bullet_speed
        final_dy = math.sin(final_angle) * self.bullet_speed

        return {
            "x": start_x,
            "y": start_y,
            "dx": final_dx,
            "dy": final_dy,
            "life": self.bullet_lifetime,
        }

    # ------------------------------------------------------------------
    # 업데이트 & 충돌 처리
    # ------------------------------------------------------------------
    def update(self, boss_rect: Optional[pygame.Rect] = None) -> List[Dict[str, float]]:
        """매 프레임 호출. 총알 이동과 쿨다운 갱신.

        Returns:
            총알이 보스를 적중시켰을 때의 이벤트 리스트.
        """
        if not self.active:
            return []

        events: List[Dict[str, float]] = []

        # 지속 시간 감소 (아이템 유지 시간)
        self.remaining_time -= 1
        if self.remaining_time <= 0:
            self.deactivate()
            return events

        if self.shot_cooldown > 0:
            self.shot_cooldown -= 1
            
        # 반동 회복 (발사하지 않을 때)
        if self.shot_cooldown <= 0 and not self.is_firing:
            self.recoil_accumulation = max(0, self.recoil_accumulation - self.recoil_recovery_rate)

        # 총알 이동 및 충돌 처리
        events.extend(self._update_bullets(boss_rect))
        return events

    def _update_bullets(self, boss_rect: Optional[pygame.Rect]) -> List[Dict[str, float]]:
        events: List[Dict[str, float]] = []
        alive_bullets: List[Dict[str, float]] = []

        for bullet in self.bullets:
            bullet["x"] += bullet["dx"]
            bullet["y"] += bullet["dy"]
            bullet["life"] -= 1

            # 화면 밖으로 나가거나 수명이 다하면 폐기
            if (
                bullet["life"] <= 0
                or bullet["x"] < -40
                or bullet["x"] > WIDTH + 40
                or bullet["y"] < -40
                or bullet["y"] > HEIGHT + 40
            ):
                continue

            hit_boss = False
            if boss_rect is not None:
                bullet_rect = pygame.Rect(int(bullet["x"]) - 3, int(bullet["y"]) - 3, 6, 6)
                if bullet_rect.colliderect(boss_rect):
                    hit_boss = True

            if hit_boss:
                events.append({
                    "type": "boss_hit",
                    "bullet_x": bullet["x"],
                    "bullet_y": bullet["y"],
                    "vel_x": bullet["dx"],
                    "vel_y": bullet["dy"],
                })
            else:
                alive_bullets.append(bullet)

        self.bullets = alive_bullets
        return events

    # ------------------------------------------------------------------
    # 렌더링 헬퍼
    # ------------------------------------------------------------------
    def draw_bullets(self, screen: pygame.Surface):
        for bullet in self.bullets:
            pos = (int(bullet["x"]), int(bullet["y"]))
            pygame.draw.circle(screen, (255, 230, 120), pos, 3)
            pygame.draw.circle(screen, (255, 255, 200), pos, 2)

    def ammo_ratio(self) -> float:
        if self.max_ammo == 0:
            return 0.0
        return self.current_ammo / self.max_ammo
    
    def get_movement_speed_multiplier(self) -> float:
        """연사 중일 때 이동속도 배율 반환
        
        Returns:
            float: 이동속도 배율 (1.0 = 100%, 0.5 = 50%)
        """
        if not self.active:
            return 1.0
        
        # 실제로 발사 중일 때만 이동속도 감소
        # is_firing이 True일 때만 감속 적용 (shot_cooldown은 제거)
        if self.is_firing:
            return self.movement_debuff
        
        return 1.0

# 싱글톤 인스턴스
ak47_instance = None

def get_ak47_instance():
    global ak47_instance
    if ak47_instance is None:
        ak47_instance = AK47()
    return ak47_instance
