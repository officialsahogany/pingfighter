"""
🔥 Fire Machine Event for Stage 5
특별 이벤트: 기계가 플레이어 쪽 바닥에 랜덤하게 화염을 방사
화염병과 동일한 성능, 대쉬로만 통과 가능
"""

import pygame
import math
import random
from typing import List, Dict, Tuple, Optional, Any

class Stage5FireMachineEvent:
    """스테이지 5 - 바닥 화염 방사 기계 이벤트"""

    def __init__(self, screen_width: int = 760, screen_height: int = 750):
        # 필러 UI 오프셋 (좌우 80px씩)
        try:
            from config.constants import PILLAR_UI_WIDTH, GAME_PLAY_WIDTH
            self.pillar_offset = PILLAR_UI_WIDTH  # 80px
            self.game_play_width = GAME_PLAY_WIDTH  # 600px
        except ImportError:
            self.pillar_offset = 80
            self.game_play_width = 600

        self.screen_width = screen_width
        self.screen_height = screen_height
        self.screen = None

        # Event state
        self.active = False
        self.phase = "idle"
        self.timer = 0

        # Timing constants (스테이지 1과 동일)
        self.DOOR_OPEN_TIME = 60  # 1초 (바닥 열림)
        self.DOOR_OPEN_DELAY = 30  # 0.5초 대기
        self.MACHINE_RISE_TIME = 90  # 1.5초 (기계 등장)
        self.MACHINE_RISE_DELAY = 90  # 1.5초 대기
        self.SPRAYING_TIME = 120  # 2초 (화염 방사 시간)
        self.SPRAYING_DELAY = 60  # 1초 대기
        self.MACHINE_LOWER_TIME = 90  # 1.5초 (기계 하강)
        self.MACHINE_LOWER_DELAY = 30  # 0.5초 대기
        self.DOOR_CLOSE_TIME = 60  # 1초 (바닥 닫힘)

        # Machine properties - 게임 플레이 영역 중앙에 배치 (필러 오프셋 적용)
        self.machine_scale = 0.0
        self.machine_x = self.pillar_offset + self.game_play_width // 2  # 기계 X 위치 (게임 영역 중앙)
        self.machine_y = screen_height // 2  # 기계 Y 위치 (맵 중앙)

        # Door properties (원형 바닥 - 게임 영역 중앙에 위치)
        self.door_open_percent = 0.0
        self.door_radius = 100  # 원형 바닥의 반지름
        self.door_center_x = self.pillar_offset + self.game_play_width // 2
        self.door_center_y = screen_height // 2
        
        # Fire zones (화염 지대)
        self.fire_zones: List[Dict] = []
        self.spray_timer = 0  # 화염 방사 타이머
        self.spray_count = 0  # 방사한 화염 지대 수
        self.MAX_FIRE_ZONES = 1  # 최대 1개의 화염 지대만 생성
        
        # Fire stream animation (화염 스트림 애니메이션)
        self.fire_streams: List[Dict] = []  # 진행 중인 화염 스트림
        self.STREAM_DURATION = 60  # 1초 (60fps)
        
        # Fire zone properties (화염병과 동일)
        self.FIRE_ZONE_WIDTH = 80  # 너비를 20% 줄임 (100 -> 80)
        self.FIRE_ZONE_HEIGHT = 32  # 높이도 20% 줄임 (40 -> 32)
        self.FIRE_ZONE_DURATION = 150  # 2.5초 (60fps * 2.5) 유지
        
        # Sound effects
        self.sound_door = None
        self.sound_machine = None
        self.sound_fire = None  # 화염 방사 사운드
        
        # Spray particles (화염 방사 시각 효과)
        self.spray_particles = []
        
        # Smoke particles (화염 소멸 시 연기 효과)
        self.smoke_particles = []
        
        # Cannon barrel properties (포구)
        self.cannon_angle = 0  # 현재 포구 각도
        self.target_cannon_angle = 0  # 목표 포구 각도
        self.cannon_length = 60  # 포구 최대 길이
        self.cannon_current_length = 0  # 현재 포구 길이 (애니메이션용)
        self.cannon_width = 20  # 포구 너비
        self.cannon_emergence = 0.0  # 포구 출현 정도 (0.0 ~ 1.0)
        self.is_aiming = False  # 조준 중인지 여부
        self.aim_target_x = 0  # 조준 목표 X
        self.aim_target_y = 0  # 조준 목표 Y

        # 용 입 벌림 애니메이션
        self.dragon_jaw_open = 0.0  # 입 벌림 정도 (0.0 ~ 1.0)
        self.dragon_jaw_phase = "closed"  # closed, opening, open, breathing
        self.DRAGON_JAW_OPEN_TIME = 30  # 입 벌리는 시간 (0.5초)
        
        # Font for debugging
        self.font = None
        
    def init_font(self):
        """폰트 초기화 - PF스타더스트 픽셀 폰트"""
        if not self.font:
            try:
                self.font = pygame.font.Font("PFStardust.ttf", 20)
            except:
                self.font = pygame.font.Font(None, 20)
    
    def should_trigger(self, current_stage: int) -> bool:
        """이벤트 발동 조건 체크 - 외부 타이머가 결정"""
        print(f"🔥 [should_trigger] Called with - Stage: {current_stage}, Active: {self.active}")
        
        # Stage 5에서만 발동
        if current_stage != 5:
            print(f"🔥 [should_trigger] Stage {current_stage} != 5, 이벤트 발동 불가")
            return False
        
        # 이미 활성화 중이면 발동 불가
        if self.active:
            print(f"🔥 [should_trigger] 이미 활성화 중, 이벤트 발동 불가")
            return False
        
        print(f"🔥 [should_trigger] 이벤트 발동 가능!")
        return True
    
    def activate(self, screen: pygame.Surface, sound_door: Any = None, 
                 sound_machine: Any = None, sound_fire: Any = None):
        """이벤트 활성화"""
        print(f"🔥 [activate] Called - 타이머 기반 이벤트 발동")
        print(f"🔥 [activate] Current state - Active: {self.active}")
        
        if self.active:
            print(f"🔥 [activate] Already active, returning False")
            return False
            
        self.screen = screen
        self.sound_door = sound_door  # stage1door.wav (재활용)
        self.sound_machine = sound_machine  # stage1muchine.wav (재활용)
        self.sound_fire = sound_fire  # 화염 방사 사운드
        self.active = True
        self.phase = "door_opening"
        self.timer = 0
        # 기존 화염 지대는 유지
        self.door_open_percent = 0.0
        self.machine_scale = 0.0
        self.spray_timer = 0
        self.spray_count = 0
        self.spray_particles.clear()
        self.is_aiming = False  # 조준 상태 초기화
        self.cannon_angle = 0  # 포구 각도 초기화
        self.cannon_emergence = 0.0  # 포구 출현도 초기화
        self.cannon_current_length = 0  # 포구 길이 초기화
        self.dragon_jaw_open = 0.0  # 용 입 벌림 초기화
        self.dragon_jaw_phase = "closed"  # 입 닫힌 상태
        self.init_font()
        
        print(f"🔥 Stage 5 화염 방사 기계 이벤트 활성화!")
        return True
    
    def update(self) -> bool:
        """이벤트 업데이트. Returns True if event is still active"""
        if not self.active:
            # 화염 지대와 연기는 이벤트가 끝나도 계속 업데이트
            self._update_fire_zones()
            self._update_smoke_particles()
            return False
        
        self.timer += 1
        
        if self.phase == "door_opening":
            # 바닥 열기 시작 시 사운드 재생
            if self.timer == 1 and self.sound_door:
                self.sound_door.play()
            
            # 문 열기 애니메이션
            progress = min(1.0, self.timer / self.DOOR_OPEN_TIME)
            self.door_open_percent = self._ease_out_cubic(progress)
            
            if self.timer >= self.DOOR_OPEN_TIME:
                self.phase = "door_open_wait"
                self.timer = 0
                
        elif self.phase == "door_open_wait":
            if self.timer >= self.DOOR_OPEN_DELAY:
                self.phase = "machine_rising"
                self.timer = 0
                
        elif self.phase == "machine_rising":
            # 기계 상승 시작 시 사운드 재생
            if self.timer == 1 and self.sound_machine:
                self.sound_machine.play()
            
            # 기계 등장 애니메이션 (크기 커짐)
            progress = min(1.0, self.timer / self.MACHINE_RISE_TIME)
            self.machine_scale = self._ease_out_cubic(progress)
            
            if self.timer >= self.MACHINE_RISE_TIME:
                self.phase = "machine_rise_wait"
                self.timer = 0
                
        elif self.phase == "machine_rise_wait":
            if self.timer >= self.MACHINE_RISE_DELAY:
                self.phase = "spraying"
                self.timer = 0
                
        elif self.phase == "spraying":
            # === 0단계: 목이 나오기 전에 먼저 조준 방향 설정 (첫 프레임에만) ===
            # timer += 1이 먼저 실행되므로 timer == 1일 때가 첫 프레임
            if self.timer == 1:
                # 플레이어 쪽 바닥 영역으로 조준 방향 설정
                fixed_floor_y = self.screen_height - 50
                self.aim_target_x = random.randint(50, self.screen_width - 50)
                self.aim_target_y = fixed_floor_y
                # 조준 각도를 바로 설정 (목이 처음부터 올바른 방향으로 나옴)
                self.cannon_angle = math.atan2(
                    self.aim_target_y - self.machine_y,
                    self.aim_target_x - self.machine_x
                )
                self.target_cannon_angle = self.cannon_angle
                print(f"🐉 용 방향 설정! 목표: ({self.aim_target_x}, {self.aim_target_y}), 각도: {math.degrees(self.cannon_angle):.1f}°")

            # === 1단계: 용 목이 먼저 길게 뻗어나감 (0~45프레임) ===
            if self.timer < 45:
                self.cannon_emergence = self._ease_out_cubic(self.timer / 45)
                self.cannon_current_length = self.cannon_length * self.cannon_emergence
                self.dragon_jaw_phase = "closed"
                self.dragon_jaw_open = 0.0

            # === 2단계: 입 벌리기 애니메이션 (45~75프레임) ===
            elif self.timer < 75:
                self.cannon_emergence = 1.0
                self.cannon_current_length = self.cannon_length
                jaw_progress = (self.timer - 45) / self.DRAGON_JAW_OPEN_TIME
                self.dragon_jaw_open = self._ease_out_cubic(min(1.0, jaw_progress))
                self.dragon_jaw_phase = "opening"
                if jaw_progress >= 1.0:
                    self.dragon_jaw_phase = "open"

            # === 3단계: 입 완전히 열림 + 화염 방사 ===
            else:
                self.cannon_emergence = 1.0
                self.cannon_current_length = self.cannon_length
                self.dragon_jaw_phase = "breathing"
                # 입이 열린 상태에서 약간 벌렁거림 (숨쉬는 효과)
                self.dragon_jaw_open = 1.0 + 0.1 * math.sin(self.timer * 0.2)

                # 화염 방사 중 (스트림 시작) - 입이 열린 후에만 발사
                self._spray_fire()

            # 스트림과 화염 지대 업데이트
            self._update_fire_streams()
            self._update_fire_zones()

            # 방사 파티클 업데이트
            self._update_spray_particles()

            # 연기 파티클 업데이트
            self._update_smoke_particles()

            if self.timer >= self.SPRAYING_TIME:
                self.phase = "spraying_wait"
                self.timer = 0
                
        elif self.phase == "spraying_wait":
            # 스트림과 화염 지대 계속 업데이트
            self._update_fire_streams()
            self._update_fire_zones()
            self._update_smoke_particles()

            # 입 닫기 애니메이션 (처음 30프레임 동안)
            if self.timer < 30:
                close_progress = self.timer / 30.0
                self.dragon_jaw_open = 1.0 - self._ease_in_cubic(close_progress)
                self.dragon_jaw_phase = "closing"
            else:
                self.dragon_jaw_open = 0.0
                self.dragon_jaw_phase = "closed"

            if self.timer >= self.SPRAYING_DELAY:
                self.phase = "machine_lowering"
                self.timer = 0
                
        elif self.phase == "machine_lowering":
            # 기계 하강 시작 시 사운드 재생
            if self.timer == 1 and self.sound_machine:
                self.sound_machine.play()
            
            # 기계와 포구 사라지는 애니메이션
            progress = min(1.0, self.timer / self.MACHINE_LOWER_TIME)
            self.machine_scale = 1.0 - self._ease_in_cubic(progress)
            self.cannon_emergence = 1.0 - self._ease_in_cubic(progress)
            self.cannon_current_length = self.cannon_length * self.cannon_emergence
            
            # 스트림과 화염 지대 계속 업데이트
            self._update_fire_streams()
            self._update_fire_zones()
            self._update_smoke_particles()
            
            if self.timer >= self.MACHINE_LOWER_TIME:
                self.phase = "machine_lower_wait"
                self.timer = 0
                
        elif self.phase == "machine_lower_wait":
            # 스트림과 화염 지대 계속 업데이트
            self._update_fire_streams()
            self._update_fire_zones()
            self._update_smoke_particles()
            
            if self.timer >= self.MACHINE_LOWER_DELAY:
                self.phase = "door_closing"
                self.timer = 0
                
        elif self.phase == "door_closing":
            # 바닥 닫기 시작 시 사운드 재생
            if self.timer == 1 and self.sound_door:
                self.sound_door.play()
            
            # 문 닫기 애니메이션
            progress = min(1.0, self.timer / self.DOOR_CLOSE_TIME)
            self.door_open_percent = 1.0 - self._ease_in_cubic(progress)
            
            # 스트림과 화염 지대 계속 업데이트
            self._update_fire_streams()
            self._update_fire_zones()
            self._update_smoke_particles()
            
            if self.timer >= self.DOOR_CLOSE_TIME:
                self.deactivate()
                return False
        
        return self.active
    
    def _spray_fire(self):
        """화염 방사"""
        # 조준 단계 (처음에 목표 설정) - spraying 단계에서 이미 설정됨
        if not self.is_aiming and self.spray_count < self.MAX_FIRE_ZONES and self.spray_timer == 0:
            # 조준 방향은 spraying 단계 시작 시 이미 설정됨
            # 여기서는 is_aiming만 True로 설정
            self.is_aiming = True
            print(f"🎯 화염 발사 준비 완료! 목표: ({self.aim_target_x}, {self.aim_target_y})")
        
        # 포구 회전 (부드럽게 목표 각도로 회전)
        if self.is_aiming:
            angle_diff = self.target_cannon_angle - self.cannon_angle
            # 각도 차이를 -π ~ π 범위로 정규화
            while angle_diff > math.pi:
                angle_diff -= 2 * math.pi
            while angle_diff < -math.pi:
                angle_diff += 2 * math.pi
            
            # 부드럽게 회전 (0.1 속도로)
            self.cannon_angle += angle_diff * 0.15
            
            # 충분히 조준되었으면 발사
            if abs(angle_diff) < 0.1 and self.spray_timer >= 20:  # 최소 20프레임(0.3초) 조준 시간
                # 화염 스트림 생성 (용머리 입 위치에서 발사)
                # 용 전체 길이: 목(70%) + 머리(head_length_px = 70 * scale)
                dragon_total = self.cannon_current_length * 1.5  # 전체 길이
                neck_len = dragon_total * 0.7  # 목 길이
                head_len = 70 * self.machine_scale  # 머리 길이
                dragon_mouth_length = neck_len + head_len  # 입 위치
                fire_stream = {
                    "start_x": self.machine_x + math.cos(self.cannon_angle) * dragon_mouth_length,
                    "start_y": self.machine_y + math.sin(self.cannon_angle) * dragon_mouth_length,
                    "target_x": self.aim_target_x,
                    "target_y": self.aim_target_y,
                    "timer": 0,
                    "max_timer": self.STREAM_DURATION,
                    "particles": [],  # 스트림 파티클들
                    "completed": False
                }
                
                # 스트림의 각도와 거리 계산
                distance = math.hypot(
                    self.aim_target_x - fire_stream["start_x"], 
                    self.aim_target_y - fire_stream["start_y"]
                )
                fire_stream["angle"] = self.cannon_angle
                fire_stream["distance"] = distance
                
                self.fire_streams.append(fire_stream)
                self.spray_count += 1
                self.is_aiming = False  # 조준 완료
                
                # 방사 효과음
                if self.sound_fire:
                    self.sound_fire.play()
                
                print(f"🔥 화염 스트림 발사! 각도: {math.degrees(self.cannon_angle):.1f}°")
        
        self.spray_timer += 1
    
    def _create_spray_particles(self, target_x, target_y):
        """화염 방사 시각 효과 파티클 생성"""
        # 기계에서 목표 지점으로 날아가는 파티클
        for i in range(20):
            angle = math.atan2(target_y - self.machine_y, target_x - self.machine_x)
            spread = random.uniform(-0.3, 0.3)  # 약간의 퍼짐
            final_angle = angle + spread
            
            speed = random.uniform(8, 12)
            particle = {
                "x": self.machine_x,
                "y": self.machine_y,
                "vel_x": math.cos(final_angle) * speed,
                "vel_y": math.sin(final_angle) * speed,
                "lifetime": 30,
                "size": random.uniform(3, 8),
                "color": random.choice([(255, 100, 0), (255, 150, 0), (255, 200, 0)])
            }
            self.spray_particles.append(particle)
    
    def _update_spray_particles(self):
        """방사 파티클 업데이트"""
        for particle in self.spray_particles[:]:
            particle["x"] += particle["vel_x"]
            particle["y"] += particle["vel_y"]
            particle["lifetime"] -= 1
            particle["size"] *= 0.95  # 점점 작아짐
            
            if particle["lifetime"] <= 0 or particle["size"] < 1:
                self.spray_particles.remove(particle)
    
    def _create_smoke_effect(self, center_x, center_y, width, height):
        """화염 소멸 시 연기 효과 생성"""
        # 연기 파티클 생성 (30~50개)
        for _ in range(random.randint(30, 50)):
            # 화염 지대 영역 내에서 랜덤 위치
            x = center_x + random.uniform(-width/2, width/2)
            y = center_y + random.uniform(-height/2, height/2)
            
            # 연기는 위로 올라가면서 퍼짐
            vel_x = random.uniform(-2, 2)
            vel_y = random.uniform(-4, -1)  # 위쪽으로
            
            # 회색 계열 색상 (연기)
            gray_value = random.randint(80, 150)
            color = (gray_value, gray_value, gray_value)
            
            particle = {
                "x": x,
                "y": y,
                "vel_x": vel_x,
                "vel_y": vel_y,
                "size": random.uniform(10, 20),
                "lifetime": random.randint(30, 60),  # 0.5~1초
                "color": color,
                "alpha": 200  # 초기 투명도
            }
            self.smoke_particles.append(particle)
    
    def _update_smoke_particles(self):
        """연기 파티클 업데이트"""
        for particle in self.smoke_particles[:]:
            particle["lifetime"] -= 1
            particle["x"] += particle["vel_x"]
            particle["y"] += particle["vel_y"]
            
            # 연기는 위로 올라가면서 느려짐
            particle["vel_y"] *= 0.98
            particle["vel_x"] *= 0.95
            
            # 크기는 점점 커지면서 투명해짐
            particle["size"] *= 1.02
            particle["alpha"] = int(200 * (particle["lifetime"] / 60))  # 점점 투명해짐
            
            if particle["lifetime"] <= 0 or particle["alpha"] <= 10:
                self.smoke_particles.remove(particle)
    
    def _update_fire_streams(self):
        """화염 스트림 업데이트 (물줄기 애니메이션)"""
        for stream in self.fire_streams[:]:
            stream["timer"] += 1
            progress = stream["timer"] / stream["max_timer"]
            
            if progress <= 1.0 and not stream["completed"]:
                # 스트림이 점진적으로 뻗어나감
                current_distance = stream["distance"] * progress
                stream_x = stream["start_x"] + math.cos(stream["angle"]) * current_distance
                stream_y = stream["start_y"] + math.sin(stream["angle"]) * current_distance
                
                # 스트림 파티클 생성 (물줄기 효과)
                for i in range(3):  # 매 프레임마다 3개 파티클
                    particle = {
                        "x": stream_x + random.uniform(-5, 5),
                        "y": stream_y + random.uniform(-5, 5),
                        "vel_x": random.uniform(-1, 1),
                        "vel_y": random.uniform(0, 2),
                        "size": random.uniform(6, 12),
                        "lifetime": 30,
                        "color": random.choice([(255, 100, 0), (255, 150, 0), (255, 200, 0)])
                    }
                    stream["particles"].append(particle)
                
                # 스트림이 목표 지점에 도달했을 때
                if progress >= 1.0 and not stream["completed"]:
                    stream["completed"] = True
                    # 화염 지대 생성
                    self._create_fire_zone(stream["target_x"], stream["target_y"])
            
            # 파티클 업데이트
            for particle in stream["particles"][:]:
                particle["x"] += particle["vel_x"]
                particle["y"] += particle["vel_y"]
                particle["lifetime"] -= 1
                particle["size"] *= 0.96
                
                if particle["lifetime"] <= 0:
                    stream["particles"].remove(particle)
            
            # 완료되고 파티클이 모두 사라진 스트림 제거
            if stream["completed"] and len(stream["particles"]) == 0:
                self.fire_streams.remove(stream)
    
    def _create_fire_zone(self, x, y):
        """화염 지대 생성 (스트림이 도달한 후)"""
        fire_zone = {
            "x": x,
            "y": y,
            "width": self.FIRE_ZONE_WIDTH,
            "height": self.FIRE_ZONE_HEIGHT,
            "duration": self.FIRE_ZONE_DURATION,
            "flames": [],  # 개별 불꽃 파티클들
            "spread_timer": 0,  # 불길 번짐 타이머
            "push_timer": 0  # 밀어내기 타이머
        }
        
        # 초기 불꽃 파티클 생성
        for i in range(15):
            flame = {
                "x": x + random.uniform(-30, 30),
                "y": y + random.uniform(-10, 10),
                "size": random.uniform(8, 20),
                "lifetime": random.uniform(20, 40),
                "color_phase": random.uniform(0, 1)
            }
            fire_zone["flames"].append(flame)
        
        self.fire_zones.append(fire_zone)
        print(f"🔥 화염 지대 생성! 위치: ({x}, {y})")
    
    def _update_fire_zones(self):
        """화염 지대 업데이트"""
        for fire_zone in self.fire_zones[:]:
            fire_zone["duration"] -= 1
            fire_zone["spread_timer"] += 1
            fire_zone["push_timer"] += 1
            
            # 불길 번짐 효과 - 지속적으로 새 불꽃 추가
            if fire_zone["spread_timer"] % 5 == 0 and len(fire_zone["flames"]) < 30:
                for i in range(3):
                    flame = {
                        "x": fire_zone["x"] + random.uniform(-fire_zone["width"]/2, fire_zone["width"]/2),
                        "y": fire_zone["y"] + random.uniform(-fire_zone["height"]/2, fire_zone["height"]/2),
                        "size": random.uniform(5, 15),
                        "lifetime": random.uniform(15, 30),
                        "color_phase": random.uniform(0, 1)
                    }
                    fire_zone["flames"].append(flame)
            
            # 개별 불꽃 업데이트
            for flame in fire_zone["flames"][:]:
                flame["lifetime"] -= 1
                flame["size"] *= 0.98  # 점점 작아짐
                flame["y"] -= random.uniform(0.5, 1.5)  # 위로 올라감
                flame["x"] += random.uniform(-1, 1)  # 좌우로 흔들림
                flame["color_phase"] = (flame["color_phase"] + 0.05) % 1
                
                if flame["lifetime"] <= 0 or flame["size"] < 2:
                    fire_zone["flames"].remove(flame)
            
            # 지속시간 종료 체크
            if fire_zone["duration"] <= 0:
                self.fire_zones.remove(fire_zone)
                print(f"🔥 화염 지대 소멸")
    
    def check_fire_zone_collision(self, player_rect, is_rolling=False, in_smoke_grenade=False):
        """
        화염 지대와 플레이어 충돌 체크
        Returns: (in_fire, push_direction) - in_fire가 True면 화염 지대 안에 있음, push_direction은 넉백 방향
        """
        for fire_zone in self.fire_zones[:]:  # 리스트 복사본으로 순회 (삭제를 위해)
            fire_rect = pygame.Rect(
                fire_zone["x"] - fire_zone["width"]/2,
                fire_zone["y"] - fire_zone["height"]/2,
                fire_zone["width"],
                fire_zone["height"]
            )
            
            if player_rect.colliderect(fire_rect):
                if not is_rolling:
                    # 연막탄 연기 안에 있으면 넉백 면역
                    if in_smoke_grenade:
                        print(f"💨 연막탄 연기로 화염 넉백 면역!")
                        return False, 0  # 연막탄 연기가 보호해줌
                    
                    # 대쉬 중이 아니고 연막탄도 없으면 넉백 (스턴 없음)
                    # 넉백 방향 계산: 화염 중심에서 플레이어로 밀어냄
                    push_x = player_rect.centerx - fire_zone["x"]
                    
                    # 플레이어가 화염의 정중앙에 있을 때를 대비한 처리
                    if abs(push_x) < 5:  # 거의 중앙에 있으면
                        push_direction = random.choice([-1, 1])  # 랜덤 방향
                    else:
                        push_direction = 1 if push_x > 0 else -1
                    
                    # 디버그 출력 추가
                    print(f"🔥 화염 충돌! 플레이어 X={player_rect.centerx}, 화염 X={fire_zone['x']}, 방향={push_direction}")
                    return True, push_direction
                else:
                    # 대쉬 중이면 화염 즉시 소멸 및 연기 효과 생성
                    self._create_smoke_effect(fire_zone["x"], fire_zone["y"], 
                                            fire_zone["width"], fire_zone["height"])
                    self.fire_zones.remove(fire_zone)
                    print(f"💨 대쉬로 화염 소멸! 연기 효과 생성")
                    return False, 0  # 대쉬로 화염을 꺼뜨렸으므로 넉백 없음
        
        return False, 0
    
    def check_monk_collision(self, monk_x, monk_y, monk_width=60, monk_height=80):
        """
        화염 지대와 몽크 충돌 체크
        Returns: (in_fire, push_direction, push_force) - in_fire가 True면 화염 지대 안에 있음
        """
        monk_rect = pygame.Rect(
            monk_x - monk_width//2,
            monk_y - monk_height//2,
            monk_width,
            monk_height
        )
        
        for fire_zone in self.fire_zones:
            fire_rect = pygame.Rect(
                fire_zone["x"] - fire_zone["width"]/2,
                fire_zone["y"] - fire_zone["height"]/2,
                fire_zone["width"],
                fire_zone["height"]
            )
            
            if monk_rect.colliderect(fire_rect):
                # 화염에 닿은 몽크는 즉시 넉백
                # 넉백 방향 계산: 화염 중심에서 몽크 방향으로 밀어냄
                push_x = monk_x - fire_zone["x"]
                push_y = monk_y - fire_zone["y"]
                
                # 거리 계산
                distance = math.sqrt(push_x**2 + push_y**2)
                if distance < 1:
                    distance = 1  # 0으로 나누기 방지
                
                # 정규화된 방향 벡터
                push_dir_x = push_x / distance
                push_dir_y = push_y / distance
                
                # 넉백 힘 (화염 중심에 가까울수록 강함)
                push_force = 15 + (50 / max(distance, 10)) * 10  # 15~25의 힘
                
                print(f"🔥 몽크가 화염에 닿음! 넉백 방향: ({push_dir_x:.2f}, {push_dir_y:.2f}), 힘: {push_force:.1f}")
                return True, (push_dir_x, push_dir_y), push_force
        
        return False, (0, 0), 0
    
    def get_fire_zones(self):
        """활성화된 화염 지대 리스트 반환"""
        return self.fire_zones
    
    def draw_background(self, screen: pygame.Surface):
        """배경 요소 그리기 (공 아래에 그려질 요소들)"""
        if not self.active:
            return
        
        # 원형 바닥 구멍 그리기
        if self.door_open_percent > 0:
            current_radius = int(self.door_radius * self.door_open_percent)
            
            # 구멍 테두리 (여러 원으로 그라데이션 효과)
            for i in range(5):
                border_color = (50 + i * 10, 20 + i * 5, 20 + i * 5)  # 점점 밝아지는 붉은 테두리
                pygame.draw.circle(screen, border_color, 
                                 (self.door_center_x, self.door_center_y), 
                                 current_radius + (5 - i), 2)
            
            # 구멍 내부 (검은색 그라데이션)
            for i in range(current_radius, 0, -5):
                darkness = int((1 - i / current_radius) * 50)  # 중앙으로 갈수록 어두워짐
                color = (darkness, 0, 0)  # 검은색에서 약간의 붉은 색조
                pygame.draw.circle(screen, color, 
                                 (self.door_center_x, self.door_center_y), i)
    
    def draw(self, screen: pygame.Surface):
        """활성 이벤트 그리기 (공 위에 그려질 요소들)"""
        # 화염 지대 그리기 (항상 그림)
        for fire_zone in self.fire_zones:
            # 화염 지대 바닥 제거 (빨간 네모 박스 제거 요청)
            # fire_surface = pygame.Surface((fire_zone["width"], fire_zone["height"]))
            # fire_surface.set_alpha(100)
            # fire_surface.fill((200, 50, 0))
            # screen.blit(fire_surface, 
            #            (fire_zone["x"] - fire_zone["width"]/2, 
            #             fire_zone["y"] - fire_zone["height"]/2))
            
            # 개별 불꽃 그리기
            for flame in fire_zone["flames"]:
                # 색상 변화 (빨강 -> 주황 -> 노랑) - 0-255 범위 보장
                color_intensity = max(0, min(255, int(255 * (flame["lifetime"] / 30))))
                if flame["color_phase"] < 0.33:
                    color = (255, max(0, min(255, color_intensity // 2)), 0)
                elif flame["color_phase"] < 0.66:
                    color = (255, max(0, min(255, color_intensity)), 0)
                else:
                    color = (255, 255, max(0, min(255, color_intensity // 2)))
                
                pygame.draw.circle(screen, color, 
                                 (int(flame["x"]), int(flame["y"])), 
                                 int(flame["size"]))
            
            # 화염 지대 테두리 제거 (요청에 따라 주석 처리)
            # pygame.draw.rect(screen, (255, 100, 0), 
            #                (fire_zone["x"] - fire_zone["width"]/2, 
            #                 fire_zone["y"] - fire_zone["height"]/2,
            #                 fire_zone["width"], fire_zone["height"]), 2)
        
        if not self.active:
            return
        
        # 🌺 홍련(紅蓮) 사이버펑크 기계 그리기
        if self.machine_scale > 0:
            machine_size = int(100 * self.machine_scale)  # 크기 증가
            
            # 중심 원형 코어 (사이버펑크 스타일)
            core_size = int(40 * self.machine_scale)
            # 다중 원으로 네온 효과
            for i in range(3):
                glow_alpha = 150 - i * 40
                glow_size = core_size + i * 5
                glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (255, 0, 100, glow_alpha), 
                                 (glow_size, glow_size), glow_size)
                screen.blit(glow_surf, (self.machine_x - glow_size, self.machine_y - glow_size))
            
            # 중심 코어
            pygame.draw.circle(screen, (20, 0, 10), (self.machine_x, self.machine_y), core_size)
            pygame.draw.circle(screen, (255, 50, 150), (self.machine_x, self.machine_y), core_size, 3)
            
            # 홍련 꽃잎 (8개의 연꽃 잎) - 사이버펑크 스타일
            if self.machine_scale >= 0.5:
                petal_count = 8
                for i in range(petal_count):
                    angle = (360 / petal_count) * i + self.timer * 2  # 회전 애니메이션
                    rad = math.radians(angle)
                    
                    # 꽃잎 위치
                    petal_dist = 50 * self.machine_scale
                    petal_x = self.machine_x + math.cos(rad) * petal_dist
                    petal_y = self.machine_y + math.sin(rad) * petal_dist
                    
                    # 꽃잎 모양 (타원형으로 그리기)
                    petal_width = int(25 * self.machine_scale)
                    petal_height = int(40 * self.machine_scale)
                    
                    # 꽃잎 표면
                    petal_surf = pygame.Surface((petal_width * 2, petal_height * 2), pygame.SRCALPHA)
                    # 그라데이션 효과를 위한 여러 타원
                    for j in range(3):
                        petal_color = (255 - j * 30, 50 + j * 20, 100 + j * 30, 200 - j * 50)
                        pygame.draw.ellipse(petal_surf, petal_color,
                                          (j * 2, j * 2, petal_width * 2 - j * 4, petal_height * 2 - j * 4))
                    
                    # 회전 적용
                    rotated_petal = pygame.transform.rotate(petal_surf, -angle)
                    petal_rect = rotated_petal.get_rect(center=(int(petal_x), int(petal_y)))
                    screen.blit(rotated_petal, petal_rect)
                    
                    # 꽃잎 테두리 (네온 효과)
                    pygame.draw.circle(screen, (255, 100, 200), (int(petal_x), int(petal_y)), 
                                     int(12 * self.machine_scale), 2)
            
            # 화염 방사구 (꽃잎 끝에 위치)
            if self.machine_scale >= 1.0:
                for i in range(8):
                    angle = (360 / 8) * i + self.timer * 2
                    rad = math.radians(angle)
                    nozzle_dist = 60 * self.machine_scale
                    nozzle_x = self.machine_x + math.cos(rad) * nozzle_dist
                    nozzle_y = self.machine_y + math.sin(rad) * nozzle_dist
                    
                    # 방사구 (사이버펑크 스타일)
                    pygame.draw.circle(screen, (50, 0, 20), 
                                     (int(nozzle_x), int(nozzle_y)), 
                                     int(8 * self.machine_scale))
                    pygame.draw.circle(screen, (255, 100, 0), 
                                     (int(nozzle_x), int(nozzle_y)), 
                                     int(8 * self.machine_scale), 2)
                    # 내부 빛
                    pygame.draw.circle(screen, (255, 200, 100), 
                                     (int(nozzle_x), int(nozzle_y)), 
                                     int(3 * self.machine_scale))
            
            # 🐉 용머리 포구 그리기 (디테일한 동양풍 용)
            if self.machine_scale >= 0.8 and self.cannon_emergence > 0:
                # 용 전체 길이 (목이 먼저 길게 늘어남)
                dragon_total_length = self.cannon_current_length * self.machine_scale * 1.5
                dragon_scale = self.machine_scale * self.cannon_emergence

                if dragon_total_length > 5:
                    # 용 색상 팔레트 (홍련 기계와 동일한 붉은색/분홍색 계열)
                    dragon_deep = (40, 10, 20)        # 깊은 붉은색
                    dragon_dark = (80, 20, 30)        # 어두운 붉은색
                    dragon_mid = (120, 30, 50)        # 중간 붉은색
                    dragon_light = (180, 50, 80)      # 밝은 붉은색
                    dragon_highlight = (255, 100, 150) # 핑크 하이라이트
                    dragon_pink = (255, 150, 180)     # 핑크 악센트 (입 안)
                    dragon_glow = (255, 200, 150)     # 화염 발광색

                    # 수직 방향
                    perp_angle = self.cannon_angle + math.pi / 2

                    # === 1단계: 긴 목 (화염 방향으로 먼저 뻗어나감) ===
                    neck_length = dragon_total_length * 0.7  # 목이 전체의 70%
                    neck_segments = 15  # 더 많은 세그먼트로 부드러운 목

                    # 목 두께 (시작 -> 머리로 갈수록 두꺼워짐)
                    for i in range(neck_segments):
                        progress = i / neck_segments
                        seg_x = self.machine_x + math.cos(self.cannon_angle) * (neck_length * progress)
                        seg_y = self.machine_y + math.sin(self.cannon_angle) * (neck_length * progress)

                        # 목 두께 (시작: 얇음 -> 중간: 두꺼움 -> 머리: 약간 좁아짐)
                        if progress < 0.5:
                            thickness = 8 + progress * 30  # 8 -> 23
                        else:
                            thickness = 23 + (progress - 0.5) * 10  # 23 -> 28
                        thickness = int(thickness * dragon_scale)

                        # 목 비늘 레이어 (3D 효과)
                        for layer in range(4):
                            layer_offset = layer * 2
                            layer_thickness = max(1, thickness - layer * 3)

                            # 색상 그라데이션
                            if layer == 0:
                                color = dragon_deep
                            elif layer == 1:
                                color = dragon_dark
                            elif layer == 2:
                                color = dragon_mid
                            else:
                                color = dragon_light

                            # 위아래로 목 그리기
                            for side in [-1, 1]:
                                offset_x = math.cos(perp_angle) * (layer_thickness * side * 0.5)
                                offset_y = math.sin(perp_angle) * (layer_thickness * side * 0.5)
                                pygame.draw.circle(screen, color,
                                                 (int(seg_x + offset_x), int(seg_y + offset_y)),
                                                 max(1, layer_thickness // 2))

                        # 비늘 패턴 (V자 형태)
                        if i % 2 == 0 and progress > 0.1:
                            scale_size = int(thickness * 0.8)
                            # 비늘 중심
                            pygame.draw.polygon(screen, dragon_highlight,
                                              [(int(seg_x), int(seg_y - scale_size * 0.3)),
                                               (int(seg_x - scale_size * 0.4), int(seg_y + scale_size * 0.2)),
                                               (int(seg_x), int(seg_y)),
                                               (int(seg_x + scale_size * 0.4), int(seg_y + scale_size * 0.2))])
                            pygame.draw.polygon(screen, dragon_dark,
                                              [(int(seg_x), int(seg_y - scale_size * 0.3)),
                                               (int(seg_x - scale_size * 0.4), int(seg_y + scale_size * 0.2)),
                                               (int(seg_x), int(seg_y)),
                                               (int(seg_x + scale_size * 0.4), int(seg_y + scale_size * 0.2))], 1)

                    # === 2단계: 용 머리 (디테일한 서피스로 그리기) ===
                    head_start_x = self.machine_x + math.cos(self.cannon_angle) * neck_length
                    head_start_y = self.machine_y + math.sin(self.cannon_angle) * neck_length
                    head_size = int(55 * dragon_scale)  # 머리 기본 크기 (약간 크게)
                    head_length_px = int(80 * dragon_scale)  # 머리 길이 (더 길게)

                    # 머리 끝 (입) 위치
                    mouth_x = head_start_x + math.cos(self.cannon_angle) * head_length_px
                    mouth_y = head_start_y + math.sin(self.cannon_angle) * head_length_px

                    # 머리 서피스 생성 (충분히 크게)
                    surf_size = head_length_px * 4
                    head_surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
                    cx, cy = surf_size // 2, surf_size // 2  # 서피스 중심

                    # 입 벌림 계산
                    base_jaw_open = 25 * self.dragon_jaw_open  # 최대 25픽셀 열림
                    if self.dragon_jaw_phase == "breathing":
                        jaw_open_amount = base_jaw_open + 4 * math.sin(self.timer * 0.3)
                    else:
                        jaw_open_amount = base_jaw_open

                    # --- 1. 갈기 (머리 뒤쪽에서 뻗어나가는 불꽃 같은 형태) ---
                    mane_colors = [dragon_deep, dragon_dark, dragon_mid, dragon_light, dragon_highlight]
                    for mane_i in range(7):
                        mane_angle = -50 + mane_i * 17  # -50도 ~ 52도
                        mane_wave = math.sin(self.timer * 0.15 + mane_i * 0.8) * 8
                        mane_len = head_size * (1.0 - abs(mane_i - 3) * 0.12) + mane_wave
                        mane_rad = math.radians(mane_angle - 90)

                        mane_base_x = cx - head_length_px * 0.35
                        mane_tip_x = mane_base_x + math.cos(mane_rad) * mane_len
                        mane_tip_y = cy + math.sin(mane_rad) * mane_len

                        # 갈기 두께 (뿌리: 두껍게, 끝: 뾰족하게)
                        mane_base_w = head_size * 0.12
                        mane_points = [
                            (mane_base_x - mane_base_w, cy - head_size * 0.15),
                            (mane_tip_x, mane_tip_y),
                            (mane_base_x + mane_base_w, cy - head_size * 0.15),
                        ]
                        # 레이어 효과
                        for layer, color in enumerate(mane_colors[:3]):
                            shrink = layer * 2
                            pygame.draw.polygon(head_surf, color, mane_points)
                        pygame.draw.polygon(head_surf, dragon_highlight, mane_points, 1)

                    # --- 2. 뿔 (크고 곡선형, 사슴뿔 스타일) ---
                    for horn_side in [-1, 1]:
                        horn_base_x = cx - head_length_px * 0.25
                        horn_base_y = cy + horn_side * head_size * 0.35

                        # 메인 뿔
                        horn_len = head_size * 0.9
                        horn_curve = math.sin(self.timer * 0.1) * 2  # 약간의 움직임
                        horn_points = [
                            (horn_base_x, horn_base_y),
                            (horn_base_x - head_size * 0.3, horn_base_y + horn_side * head_size * 0.4 + horn_curve),
                            (horn_base_x - head_size * 0.5, horn_base_y + horn_side * head_size * 0.7),
                            (horn_base_x - head_size * 0.4, horn_base_y + horn_side * head_size * 0.5 + horn_curve),
                            (horn_base_x - head_size * 0.15, horn_base_y + horn_side * head_size * 0.2),
                        ]
                        pygame.draw.polygon(head_surf, dragon_dark, horn_points)
                        pygame.draw.lines(head_surf, dragon_highlight, False, horn_points, 2)

                        # 뿔 링 (마디)
                        for ring in range(3):
                            ring_x = horn_base_x - head_size * 0.1 * (ring + 1)
                            ring_y = horn_base_y + horn_side * head_size * 0.15 * (ring + 1)
                            pygame.draw.ellipse(head_surf, dragon_light,
                                              (ring_x - 4, ring_y - 2, 8, 4))

                    # --- 3. 머리 본체 (더 입체적인 형태) ---
                    # 머리 뒤쪽 (둥근 두개골)
                    pygame.draw.ellipse(head_surf, dragon_dark,
                                       (cx - head_length_px * 0.45, cy - head_size * 0.45,
                                        head_length_px * 0.55, head_size * 0.9))
                    # 머리 중간 (좀 더 밝게)
                    pygame.draw.ellipse(head_surf, dragon_mid,
                                       (cx - head_length_px * 0.4, cy - head_size * 0.4,
                                        head_length_px * 0.5, head_size * 0.8))

                    # 이마 융기 (눈썹 뼈)
                    brow_points = [
                        (cx - head_length_px * 0.2, cy - head_size * 0.35),
                        (cx + head_length_px * 0.1, cy - head_size * 0.45),
                        (cx + head_length_px * 0.2, cy - head_size * 0.4),
                        (cx + head_length_px * 0.1, cy - head_size * 0.3),
                        (cx - head_length_px * 0.1, cy - head_size * 0.25),
                    ]
                    pygame.draw.polygon(head_surf, dragon_light, brow_points)
                    pygame.draw.polygon(head_surf, dragon_highlight, brow_points, 1)

                    # --- 4. 주둥이 (더 길고 위엄있는 형태) ---
                    snout_length = head_length_px * 0.75

                    # 윗턱 (더 디테일한 형태)
                    upper_jaw = [
                        (cx - head_length_px * 0.05, cy - head_size * 0.2),   # 머리 연결부
                        (cx + head_length_px * 0.15, cy - head_size * 0.35),  # 코등 시작
                        (cx + head_length_px * 0.35, cy - head_size * 0.32),  # 코등 중간
                        (cx + head_length_px * 0.55, cy - head_size * 0.25),  # 코등 끝
                        (cx + snout_length, cy - head_size * 0.12),           # 코끝 위
                        (cx + snout_length + 5, cy - head_size * 0.02),       # 코끝 (앞으로 돌출)
                        (cx + snout_length, cy + head_size * 0.02),           # 코끝 아래
                        (cx + head_length_px * 0.4, cy),                       # 입천장
                        (cx - head_length_px * 0.05, cy - head_size * 0.05),  # 머리 연결부
                    ]
                    pygame.draw.polygon(head_surf, dragon_mid, upper_jaw)

                    # 윗턱 비늘 디테일 (더 많이)
                    for row in range(2):
                        for i in range(6):
                            det_x = cx + head_length_px * 0.1 + i * head_length_px * 0.1
                            det_y = cy - head_size * 0.32 + row * head_size * 0.08
                            det_size = int(head_size * 0.06)
                            pygame.draw.circle(head_surf, dragon_light, (int(det_x), int(det_y)), det_size)
                            pygame.draw.circle(head_surf, dragon_dark, (int(det_x), int(det_y)), det_size, 1)

                    # 콧등 하이라이트 (메인 라인)
                    pygame.draw.line(head_surf, dragon_highlight,
                                   (cx + head_length_px * 0.15, cy - head_size * 0.36),
                                   (cx + head_length_px * 0.6, cy - head_size * 0.22), 3)
                    # 콧등 보조 라인
                    pygame.draw.line(head_surf, dragon_light,
                                   (cx + head_length_px * 0.2, cy - head_size * 0.28),
                                   (cx + head_length_px * 0.55, cy - head_size * 0.18), 2)

                    # 아랫턱 (더 디테일하게)
                    lower_jaw = [
                        (cx - head_length_px * 0.05, cy + head_size * 0.15),   # 머리 연결부
                        (cx + head_length_px * 0.1, cy + head_size * 0.25 + jaw_open_amount * 0.3),
                        (cx + head_length_px * 0.3, cy + head_size * 0.22 + jaw_open_amount * 0.6),
                        (cx + head_length_px * 0.5, cy + head_size * 0.18 + jaw_open_amount * 0.8),
                        (cx + snout_length * 0.85, cy + head_size * 0.08 + jaw_open_amount * 0.9),
                        (cx + snout_length * 0.9, cy + head_size * 0.05 + jaw_open_amount * 0.5),
                        (cx + snout_length * 0.85, cy + head_size * 0.02),
                        (cx + head_length_px * 0.35, cy + head_size * 0.05),
                        (cx - head_length_px * 0.05, cy + head_size * 0.08),
                    ]
                    pygame.draw.polygon(head_surf, dragon_dark, lower_jaw)
                    pygame.draw.polygon(head_surf, dragon_deep, lower_jaw, 2)

                    # 아랫턱 비늘
                    for i in range(4):
                        det_x = cx + head_length_px * 0.15 + i * head_length_px * 0.12
                        det_y = cy + head_size * 0.15 + jaw_open_amount * 0.4
                        pygame.draw.circle(head_surf, dragon_mid, (int(det_x), int(det_y)), int(head_size * 0.05))

                    # --- 5. 입 안쪽 (더 깊은 느낌) ---
                    if jaw_open_amount > 2:
                        # 입 안 어두운 배경
                        mouth_back = [
                            (cx + head_length_px * 0.05, cy),
                            (cx + snout_length * 0.75, cy),
                            (cx + head_length_px * 0.05, cy + jaw_open_amount * 0.4),
                        ]
                        pygame.draw.polygon(head_surf, (30, 10, 15), mouth_back)

                        # 입 안쪽 (핑크/붉은색)
                        mouth_inside = [
                            (cx + head_length_px * 0.1, cy - head_size * 0.02),
                            (cx + snout_length * 0.7, cy + head_size * 0.02),
                            (cx + head_length_px * 0.1, cy + jaw_open_amount * 0.35),
                        ]
                        pygame.draw.polygon(head_surf, dragon_pink, mouth_inside)

                        # 혀 (더 역동적인 형태)
                        if jaw_open_amount > 8:
                            tongue_wave = math.sin(self.timer * 0.25) * 4
                            tongue_wave2 = math.cos(self.timer * 0.2) * 3
                            tongue_color = (220, 80, 100)
                            tongue_tip_color = (255, 120, 140)

                            tongue_points = [
                                (cx + head_length_px * 0.2, cy + jaw_open_amount * 0.15),
                                (cx + head_length_px * 0.35, cy + jaw_open_amount * 0.25 + tongue_wave),
                                (cx + head_length_px * 0.5, cy + jaw_open_amount * 0.2 + tongue_wave2),
                                (cx + head_length_px * 0.65, cy + jaw_open_amount * 0.3 - tongue_wave),
                                (cx + head_length_px * 0.8, cy + jaw_open_amount * 0.35),
                                # 갈라진 혀끝
                                (cx + head_length_px * 0.9, cy + jaw_open_amount * 0.25),
                                (cx + head_length_px * 0.85, cy + jaw_open_amount * 0.3),
                                (cx + head_length_px * 0.9, cy + jaw_open_amount * 0.4),
                                # 돌아오기
                                (cx + head_length_px * 0.65, cy + jaw_open_amount * 0.35 - tongue_wave),
                                (cx + head_length_px * 0.5, cy + jaw_open_amount * 0.28 + tongue_wave2),
                                (cx + head_length_px * 0.35, cy + jaw_open_amount * 0.32 + tongue_wave),
                                (cx + head_length_px * 0.2, cy + jaw_open_amount * 0.22),
                            ]
                            pygame.draw.polygon(head_surf, tongue_color, tongue_points)
                            # 혀 중앙선
                            pygame.draw.line(head_surf, (180, 60, 80),
                                           (cx + head_length_px * 0.25, cy + jaw_open_amount * 0.2),
                                           (cx + head_length_px * 0.75, cy + jaw_open_amount * 0.3), 2)

                    # --- 6. 이빨 (더 날카롭고 다양한 크기) ---
                    # 윗니 (날카로운 송곳니)
                    tooth_color = (255, 255, 245)
                    tooth_shadow = (200, 200, 190)
                    for t in range(7):
                        tooth_x = cx + head_length_px * 0.12 + t * head_length_px * 0.1
                        # 앞니는 작고, 송곳니(1,5번)는 크게
                        if t in [1, 5]:
                            tooth_size = head_size * 0.3
                            tooth_w = 5
                        elif t in [2, 4]:
                            tooth_size = head_size * 0.18
                            tooth_w = 4
                        else:
                            tooth_size = head_size * 0.12
                            tooth_w = 3

                        tooth_points = [
                            (tooth_x - tooth_w, cy - head_size * 0.02),
                            (tooth_x, cy + tooth_size),
                            (tooth_x + tooth_w, cy - head_size * 0.02)
                        ]
                        pygame.draw.polygon(head_surf, tooth_color, tooth_points)
                        pygame.draw.polygon(head_surf, tooth_shadow, tooth_points, 1)

                    # 아랫니 (입이 열렸을 때만)
                    if jaw_open_amount > 5:
                        for t in range(5):
                            tooth_x = cx + head_length_px * 0.18 + t * head_length_px * 0.11
                            tooth_size = head_size * (0.2 if t in [0, 4] else 0.12)
                            base_y = cy + head_size * 0.06 + jaw_open_amount * 0.35
                            tooth_w = 3 if t in [0, 4] else 2

                            tooth_points = [
                                (tooth_x - tooth_w, base_y),
                                (tooth_x, base_y - tooth_size),
                                (tooth_x + tooth_w, base_y)
                            ]
                            pygame.draw.polygon(head_surf, tooth_color, tooth_points)

                    # --- 7. 눈 (더 크고 위엄있게) ---
                    eye_x = cx - head_length_px * 0.02
                    eye_y = cy - head_size * 0.22
                    eye_w = head_size * 0.4
                    eye_h = head_size * 0.22

                    # 눈두덩이 (어두운 부분)
                    pygame.draw.ellipse(head_surf, dragon_deep,
                                       (eye_x - eye_w/2 - 3, eye_y - eye_h/2 - 3, eye_w + 6, eye_h + 6))

                    # 눈 배경 (검은색)
                    pygame.draw.ellipse(head_surf, (15, 5, 8),
                                       (eye_x - eye_w/2, eye_y - eye_h/2, eye_w, eye_h))

                    # 홍채 (불타는 느낌)
                    iris_glow = 150 + int(50 * math.sin(self.timer * 0.15))
                    pygame.draw.ellipse(head_surf, (255, iris_glow, 30),
                                       (eye_x - eye_w/2 + 3, eye_y - eye_h/2 + 3, eye_w - 6, eye_h - 6))

                    # 눈동자 (세로 슬릿) - 화염 상태에 따라 크기 변화
                    pupil_width = 3 if self.dragon_jaw_phase == "breathing" else 5
                    pygame.draw.ellipse(head_surf, (20, 5, 5),
                                       (eye_x - pupil_width/2, eye_y - eye_h/2 + 4, pupil_width, eye_h - 8))

                    # 눈 하이라이트 (두 개)
                    pygame.draw.circle(head_surf, (255, 255, 220),
                                      (int(eye_x - eye_w * 0.25), int(eye_y - eye_h * 0.15)), 4)
                    pygame.draw.circle(head_surf, (255, 200, 150),
                                      (int(eye_x + eye_w * 0.1), int(eye_y + eye_h * 0.1)), 2)

                    # --- 8. 콧구멍 (연기 효과 포함) ---
                    nostril_x = cx + snout_length - head_size * 0.1
                    nostril_y = cy - head_size * 0.08

                    # 콧구멍 테두리
                    pygame.draw.ellipse(head_surf, dragon_deep,
                                       (nostril_x - 7, nostril_y - 5, 12, 8))
                    pygame.draw.ellipse(head_surf, (10, 5, 15),
                                       (nostril_x - 5, nostril_y - 3, 8, 5))

                    # 두 번째 콧구멍
                    pygame.draw.ellipse(head_surf, dragon_deep,
                                       (nostril_x - 7, nostril_y + 6, 12, 8))
                    pygame.draw.ellipse(head_surf, (10, 5, 15),
                                       (nostril_x - 5, nostril_y + 8, 8, 5))

                    # 콧구멍에서 나오는 연기 (화염 방사 시)
                    if self.dragon_jaw_phase == "breathing":
                        smoke_alpha = int(80 + 40 * math.sin(self.timer * 0.3))
                        for smoke_i in range(3):
                            smoke_x = nostril_x + 5 + smoke_i * 4 + math.sin(self.timer * 0.2 + smoke_i) * 3
                            smoke_y = nostril_y + math.cos(self.timer * 0.15 + smoke_i) * 2
                            smoke_size = 4 - smoke_i
                            smoke_surf = pygame.Surface((smoke_size * 2, smoke_size * 2), pygame.SRCALPHA)
                            pygame.draw.circle(smoke_surf, (100, 100, 100, smoke_alpha - smoke_i * 20),
                                             (smoke_size, smoke_size), smoke_size)
                            head_surf.blit(smoke_surf, (int(smoke_x - smoke_size), int(smoke_y - smoke_size)))

                    # --- 9. 수염 (더 우아하게 흐르는 형태) ---
                    whisker_base_x = cx + head_length_px * 0.05
                    whisker_base_y = cy + head_size * 0.18 + jaw_open_amount * 0.3

                    for w in range(5):
                        wave = math.sin(self.timer * 0.12 + w * 0.6) * 6
                        wave2 = math.cos(self.timer * 0.1 + w * 0.4) * 4
                        whisker_len = 45 - w * 5

                        whisker_points = [
                            (whisker_base_x - w * 6, whisker_base_y + w * 4),
                            (whisker_base_x - w * 6 - whisker_len * 0.4 + wave, whisker_base_y + w * 4 + whisker_len * 0.5 + wave2),
                            (whisker_base_x - w * 6 - whisker_len * 0.8 + wave * 1.5, whisker_base_y + w * 4 + whisker_len * 0.8),
                            (whisker_base_x - w * 6 - whisker_len + wave * 2, whisker_base_y + w * 4 + whisker_len),
                        ]
                        # 수염 두께 (뿌리: 두껍게, 끝: 가늘게)
                        pygame.draw.lines(head_surf, dragon_highlight, False, whisker_points, 3 - w // 2)

                    # --- 10. 머리 테두리 강조 ---
                    pygame.draw.polygon(head_surf, dragon_deep, upper_jaw, 2)

                    # --- 11. 볼/광대뼈 부분 디테일 ---
                    cheek_x = cx - head_length_px * 0.1
                    cheek_y = cy + head_size * 0.05
                    pygame.draw.ellipse(head_surf, dragon_light,
                                       (cheek_x - head_size * 0.15, cheek_y - head_size * 0.1,
                                        head_size * 0.25, head_size * 0.15))

                    # 머리 회전 및 배치
                    rotated_head = pygame.transform.rotate(head_surf, -math.degrees(self.cannon_angle))
                    head_rect = rotated_head.get_rect(center=(int(head_start_x + math.cos(self.cannon_angle) * head_length_px * 0.3),
                                                              int(head_start_y + math.sin(self.cannon_angle) * head_length_px * 0.3)))
                    screen.blit(rotated_head, head_rect)

                    # === 입에서 나오는 화염 발광 효과 (입이 열릴 때만) ===
                    if self.cannon_emergence >= 0.8 and self.dragon_jaw_open > 0.3:
                        # 발광 강도는 입 벌림 정도에 비례
                        glow_multiplier = min(1.0, self.dragon_jaw_open)
                        glow_intensity = int((150 + 80 * math.sin(self.timer * 0.2)) * glow_multiplier)

                        # 다중 레이어 글로우
                        for g in range(5):
                            glow_size = int((20 - g * 3) * dragon_scale * glow_multiplier)
                            if glow_size < 1:
                                continue
                            alpha = int((100 - g * 15) * glow_multiplier)
                            r = min(255, 255)
                            gr = min(255, glow_intensity + g * 20)
                            b = min(255, 100 + g * 30)

                            glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                            pygame.draw.circle(glow_surf, (r, gr, b, alpha),
                                             (glow_size, glow_size), glow_size)
                            screen.blit(glow_surf, (int(mouth_x - glow_size), int(mouth_y - glow_size)))
                
                # 조준선 (조준 중일 때만) - 용 입에서 목표까지
                if self.is_aiming:
                    # 점선 조준선
                    line_length = math.hypot(
                        self.aim_target_x - mouth_x,
                        self.aim_target_y - mouth_y
                    )
                    segments = int(line_length / 20)

                    for i in range(0, segments, 2):  # 짝수 세그먼트만 그려서 점선 효과
                        start_ratio = i / segments
                        end_ratio = min((i + 1) / segments, 1)

                        start_x = mouth_x + (self.aim_target_x - mouth_x) * start_ratio
                        start_y = mouth_y + (self.aim_target_y - mouth_y) * start_ratio
                        end_x = mouth_x + (self.aim_target_x - mouth_x) * end_ratio
                        end_y = mouth_y + (self.aim_target_y - mouth_y) * end_ratio

                        # 레이저 조준선 (빨간색)
                        pygame.draw.line(screen, (255, 0, 0, 100),
                                       (int(start_x), int(start_y)),
                                       (int(end_x), int(end_y)), 1)

                    # 조준점 표시
                    pygame.draw.circle(screen, (255, 0, 0),
                                     (int(self.aim_target_x), int(self.aim_target_y)), 8, 2)
                    pygame.draw.circle(screen, (255, 100, 100),
                                     (int(self.aim_target_x), int(self.aim_target_y)), 4, 2)
        
        # 화염 스트림 그리기 (물줄기 애니메이션)
        for stream in self.fire_streams:
            # 스트림 진행도
            progress = stream["timer"] / stream["max_timer"]
            
            # 스트림 메인 라인 그리기 (굵은 화염줄기)
            if progress > 0:
                current_distance = stream["distance"] * min(1.0, progress)
                end_x = stream["start_x"] + math.cos(stream["angle"]) * current_distance
                end_y = stream["start_y"] + math.sin(stream["angle"]) * current_distance
                
                # 여러 개의 라인으로 굵기 표현
                for width_offset in range(-3, 4):
                    for height_offset in range(-3, 4):
                        offset_start_x = stream["start_x"] + width_offset
                        offset_start_y = stream["start_y"] + height_offset
                        offset_end_x = end_x + width_offset
                        offset_end_y = end_y + height_offset
                        
                        # 중심일수록 밝은 색
                        if abs(width_offset) + abs(height_offset) <= 2:
                            color = (255, 200, 0)  # 밝은 노랑
                        elif abs(width_offset) + abs(height_offset) <= 4:
                            color = (255, 150, 0)  # 주황
                        else:
                            color = (255, 100, 0)  # 어두운 주황
                        
                        pygame.draw.line(screen, color, 
                                       (offset_start_x, offset_start_y),
                                       (offset_end_x, offset_end_y), 2)
            
            # 스트림 파티클 그리기
            for particle in stream["particles"]:
                color = particle["color"]
                # 알파 효과를 위한 색상 페이드
                fade_factor = particle["lifetime"] / 30
                faded_color = (
                    int(color[0] * fade_factor),
                    int(color[1] * fade_factor),
                    int(color[2] * fade_factor)
                )
                pygame.draw.circle(screen, faded_color,
                                 (int(particle["x"]), int(particle["y"])),
                                 int(particle["size"]))
        
        # 방사 파티클 그리기
        for particle in self.spray_particles:
            pygame.draw.circle(screen, particle["color"],
                             (int(particle["x"]), int(particle["y"])),
                             int(particle["size"]))
        
        # 연기 파티클 그리기 (반투명 효과)
        for particle in self.smoke_particles:
            # 연기 서피스 생성 (알파 채널 적용을 위해)
            smoke_surf = pygame.Surface((int(particle["size"] * 2), int(particle["size"] * 2)), pygame.SRCALPHA)
            # 알파값이 적용된 연기 원 그리기
            color_with_alpha = (*particle["color"], particle["alpha"])
            pygame.draw.circle(smoke_surf, color_with_alpha, 
                             (int(particle["size"]), int(particle["size"])), 
                             int(particle["size"]))
            # 화면에 블릿
            screen.blit(smoke_surf, 
                       (int(particle["x"] - particle["size"]), 
                        int(particle["y"] - particle["size"])))
    
    def deactivate(self):
        """이벤트 비활성화"""
        self.active = False
        self.phase = "idle"
        self.timer = 0
        # 화염 지대는 유지 (계속 타오름)
        print(f"🔥 Stage 5 화염 방사 기계 이벤트 종료")
    
    def reset(self):
        """모든 이벤트 리셋 (새 게임 시작 시)"""
        self.active = False
        self.phase = "idle"
        self.timer = 0
        self.fire_zones.clear()
        self.fire_streams.clear()  # 스트림도 초기화
        self.spray_particles.clear()
        self.smoke_particles.clear()  # 연기 파티클도 초기화
        self.door_open_percent = 0.0
        self.machine_scale = 0.0
        self.spray_timer = 0
        self.spray_count = 0
        print("🔥 Stage 5 화염 방사 기계 이벤트 리셋")
    
    def reset_for_deuce(self):
        """듀스 재시작 시 이벤트 부분 리셋"""
        self.active = False
        self.phase = "idle"
        self.timer = 0
        self.fire_streams.clear()  # 스트림도 초기화
        self.spray_particles.clear()
        self.smoke_particles.clear()  # 연기 파티클도 초기화
        self.door_open_percent = 0.0
        self.machine_scale = 0.0
        self.spray_timer = 0
        self.spray_count = 0
        # 화염 지대는 유지
        print("🔥 Stage 5 화염 방사 기계 이벤트 - 듀스 리셋")
    
    def _ease_out_cubic(self, t: float) -> float:
        """Ease-out cubic 애니메이션 곡선"""
        return 1 - pow(1 - t, 3)
    
    def _ease_in_cubic(self, t: float) -> float:
        """Ease-in cubic 애니메이션 곡선"""
        return t * t * t