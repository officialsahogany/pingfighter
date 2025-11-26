"""
🎈 Balloon Machine Event for Stage 1
특별 이벤트: 10~30초마다 랜덤하게 풍선 발사 기계 등장
풍선파티 스킬과 동일한 물리 효과 적용
"""

import pygame
import math
import random
from typing import List, Dict, Tuple, Optional, Any

class BalloonMachineEvent:
    """스테이지 1 - 10~30초마다 랜덤하게 풍선 발사 기계 이벤트"""
    
    def __init__(self, screen_width: int = 600, screen_height: int = 750):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.screen = None  # Will be set when activated
        
        # Event state
        self.active = False
        
        # Timer-based triggering
        self.cooldown_timer = 0  # 다음 이벤트까지 대기 시간
        self.MIN_COOLDOWN = 1200  # 20초 (60 FPS * 20)
        self.MAX_COOLDOWN = 2100  # 35초 (60 FPS * 35)
        self._set_next_cooldown()  # 초기 쿨다운 설정
        # Phases: idle, door_opening, door_open_wait, machine_rising, machine_rise_wait, 
        #         shooting, shooting_wait, machine_lowering, machine_lower_wait, door_closing
        self.phase = "idle"
        self.timer = 0
        
        # Timing constants (in frames, 60 FPS) - 실시간 진행
        self.DOOR_OPEN_TIME = 60  # 1초 (바닥 열림)
        self.DOOR_OPEN_DELAY = 30  # 0.5초 대기
        self.MACHINE_RISE_TIME = 90  # 1.5초 (기계 등장)
        self.MACHINE_RISE_DELAY = 90  # 1.5초 대기
        self.SHOOTING_TIME = 90  # 1.5초 (풍선 발사 - 6개 발사 시간)
        self.SHOOTING_DELAY = 90  # 1.5초 대기
        self.MACHINE_LOWER_TIME = 90  # 1.5초 (기계 하강)
        self.MACHINE_LOWER_DELAY = 30  # 0.5초 대기
        self.DOOR_CLOSE_TIME = 60  # 1초 (바닥 닫힘)
        
        # Machine properties
        self.machine_scale = 0.0  # 0 = invisible, 1 = full size (등장 애니메이션용)
        self.machine_x = screen_width // 2  # 기계 X 위치 (맵 중앙)
        self.machine_y = screen_height // 2  # 기계 Y 위치 (맵 중앙)
        
        # Door properties (맵 중앙에 위치)
        self.door_open_percent = 0.0  # 0 = closed, 1 = fully open
        self.door_width = 200
        self.door_height = 200  # 더 큰 문
        self.door_x = (screen_width - self.door_width) // 2
        self.door_y = (screen_height - self.door_height) // 2  # 맵 중앙
        
        # Balloons
        self.balloons: List[Dict] = []
        self.balloon_shoot_timer = 0  # 풍선 발사 타이머
        self.balloon_shoot_count = 0  # 발사한 풍선 개수
        self.BALLOON_SHOOT_INTERVAL = 10  # 0.17초 (10프레임)마다 발사 - 더 빠르게
        self.balloon_colors = [
            (255, 100, 100),  # 빨간색
            (100, 255, 100),  # 초록색
            (100, 100, 255),  # 파란색
            (255, 255, 100),  # 노란색
            (255, 100, 255),  # 마젠타
            (100, 255, 255),  # 시안
            (255, 200, 100),  # 주황색
            (200, 100, 255),  # 보라색
        ]
        
        # Randomization for balloons
        self.total_balloon_count = 6  # 실제 개수는 activate에서 4~6으로 랜덤 설정
        self.balloon_shoot_order = []  # 랜덤 발사 순서
        self.balloon_shoot_angles = []  # 랜덤 발사 각도
        self.special_balloon_indices = []  # 특별한 풍선이 나올 순서들 (0~2개)
        
        # Font for debugging
        self.font = None
        
        # Sound effect
        self.sound_balloon = None
        
    def init_font(self):
        """폰트 초기화"""
        if not self.font:
            try:
                self.font = pygame.font.Font("NeoDGM.ttf", 20)
            except:
                self.font = pygame.font.Font(None, 20)
    
    def _set_next_cooldown(self):
        """다음 이벤트까지의 쿨다운 시간을 랜덤하게 설정"""
        self.cooldown_timer = random.randint(self.MIN_COOLDOWN, self.MAX_COOLDOWN)
        print(f"[BalloonMachine] 다음 이벤트까지 {self.cooldown_timer/60:.1f}초")
    
    def update_timer(self):
        """타이머 업데이트 (매 프레임 호출)"""
        if not self.active and self.cooldown_timer > 0:
            self.cooldown_timer -= 1
            if self.cooldown_timer == 0:
                return True  # 이벤트 발동 시간
        return False
    
    def should_trigger(self, player_score: int, current_stage: int) -> bool:
        """이벤트 발동 조건 체크 - 타이머 기반"""
        # Stage 1에서만 작동
        if current_stage != 1:
            return False
            
        # 이미 활성 중이면 발동하지 않음
        if self.active:
            return False
        
        # 타이머가 0이 되면 발동
        return self.cooldown_timer == 0
    
    def activate(self, screen: pygame.Surface, sound_balloon: Any = None, 
                 sound_door: Any = None, sound_machine: Any = None, player_score: int = 0):
        """이벤트 활성화"""
        print(f"[BalloonMachine] 풍선 기계 이벤트 발동!")
        
        if self.active:
            print(f"[BalloonMachine] Already active, returning False")
            return False
            
        self.screen = screen
        self.sound_balloon = sound_balloon
        self.sound_door = sound_door  # stage1door.wav
        self.sound_machine = sound_machine  # stage1muchine.wav
        self.active = True
        self.phase = "door_opening"
        self.timer = 0
        # 풍선은 clear하지 않음 (이전 풍선 유지)
        # self.balloons.clear()  
        self.door_open_percent = 0.0
        self.machine_scale = 0.0  # 기계 크기 초기화
        self.balloon_shoot_timer = 0  # 풍선 발사 타이머 초기화
        self.balloon_shoot_count = 0  # 발사한 풍선 개수 초기화
        self.init_font()
        
        # 발사할 풍선 개수를 2~4개 사이에서 랜덤하게 결정
        self.total_balloon_count = random.randint(2, 4)
        
        # 랜덤 발사 순서 생성 (발사할 개수만큼의 인덱스를 섞음)
        self.balloon_shoot_order = list(range(self.total_balloon_count))
        random.shuffle(self.balloon_shoot_order)
        
        # 특별한 풍선이 나올 순서들을 랜덤하게 결정 (0~2개)
        # 먼저 개수를 0~2 사이에서 랜덤하게 결정
        special_count = random.randint(0, min(2, self.total_balloon_count))  # 풍선 개수를 초과하지 않도록
        # 중복되지 않게 특별한 풍선 인덱스 선택
        if special_count > 0:
            self.special_balloon_indices = random.sample(range(self.total_balloon_count), special_count)
        else:
            self.special_balloon_indices = []
        print(f"[BalloonMachine] 총 {self.total_balloon_count}개 풍선, 특별한 풍선 {special_count}개: {self.special_balloon_indices}")
        
        # 랜덤 발사 각도 생성 (발사할 개수만큼의 랜덤 각도)
        # 기본 방향을 개수에 맞게 조정
        self.balloon_shoot_angles = []
        for i in range(self.total_balloon_count):
            base_angle = (math.pi * 2 / self.total_balloon_count) * i
            # -15도 ~ +15도 사이의 랜덤 오프셋
            offset = random.uniform(-math.pi/12, math.pi/12)
            self.balloon_shoot_angles.append(base_angle + offset)
        # 각도들도 섞어서 순서를 랜덤하게
        random.shuffle(self.balloon_shoot_angles)
        
        # 풍선 기계 이벤트 활성화
        
        return True
    
    def update(self) -> bool:
        """이벤트 업데이트. Returns True if event is still active"""
        if not self.active:
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
            # 0.5초 대기 (문 열린 상태 유지)
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
            # 1.5초 대기 (기계 완전히 나온 상태 유지)
            if self.timer >= self.MACHINE_RISE_DELAY:
                self.phase = "shooting"
                self.timer = 0
                self.balloon_shoot_timer = 0
                self.balloon_shoot_count = 0
                
        elif self.phase == "shooting":
            # 풍선 발사 중 (빠르게 6개 발사)
            self.balloon_shoot_timer += 1
            if self.balloon_shoot_timer >= self.BALLOON_SHOOT_INTERVAL and self.balloon_shoot_count < self.total_balloon_count:
                # 랜덤 순서와 각도로 발사
                self._shoot_single_balloon(self.balloon_shoot_count)
                self.balloon_shoot_count += 1
                self.balloon_shoot_timer = 0
            
            # 풍선들 업데이트
            self._update_balloons()
            
            # 모든 풍선 발사 완료 확인
            if self.balloon_shoot_count >= self.total_balloon_count:
                self.phase = "shooting_wait"
                self.timer = 0
                
        elif self.phase == "shooting_wait":
            # 1.5초 대기 (풍선 발사 후)
            self._update_balloons()  # 풍선 계속 업데이트
            
            if self.timer >= self.SHOOTING_DELAY:
                self.phase = "machine_lowering"
                self.timer = 0
                
        elif self.phase == "machine_lowering":
            # 기계 하강 시작 시 사운드 재생
            if self.timer == 1 and self.sound_machine:
                self.sound_machine.play()
            
            # 기계 사라지는 애니메이션 (크기 작아짐)
            progress = min(1.0, self.timer / self.MACHINE_LOWER_TIME)
            self.machine_scale = 1.0 - self._ease_in_cubic(progress)
            
            # 풍선들 계속 업데이트
            self._update_balloons()
            
            if self.timer >= self.MACHINE_LOWER_TIME:
                self.phase = "machine_lower_wait"
                self.timer = 0
                
        elif self.phase == "machine_lower_wait":
            # 0.5초 대기 (기계 완전히 들어간 후)
            self._update_balloons()  # 풍선 계속 업데이트
            
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
            
            # 풍선들 계속 업데이트
            self._update_balloons()
            
            if self.timer >= self.DOOR_CLOSE_TIME:
                self.deactivate()
                return False
        
        return self.active
    
    def _shoot_single_balloon(self, index: int):
        """한 개의 풍선을 발사"""
        center_x = self.machine_x
        center_y = self.machine_y
        
        # 랜덤화된 각도 사용
        angle = self.balloon_shoot_angles[index]
        speed = random.uniform(3.0, 4.0)
        
        # 현재 발사 순서가 특별한 풍선 순서인지 확인 (1~3개 중 하나)
        is_special = (index in self.special_balloon_indices)
        
        # 랜덤 색상 선택 (특별한 풍선이 아닌 경우)
        if not is_special:
            color = self.balloon_colors[self.balloon_shoot_order[index] % len(self.balloon_colors)]
        else:
            color = (255, 255, 255)  # 특별한 풍선은 흰색 기본
        
        balloon = {
            "x": center_x,
            "y": center_y,
            "vx": math.cos(angle) * speed,
            "vy": math.sin(angle) * speed,
            "radius": random.randint(25, 35),
            "color": color,
            "bounce": 0,
            "lifetime": 0,
            "is_special": is_special  # 특별한 풍선 플래그
        }
        self.balloons.append(balloon)
        
        # 풍선 발사할 때 사운드 재생
        if self.sound_balloon:
            self.sound_balloon.play()
        
        # 특별한 풍선인지 일반 풍선인지 구분하여 생성 완료
    
    def _update_balloons(self):
        """풍선 위치 업데이트 (풍선파티 스킬과 동일한 물리)"""
        for balloon in self.balloons[:]:
            # 풍선 위치 업데이트
            balloon["x"] += balloon["vx"]
            balloon["y"] += balloon["vy"]
            
            # 튀는 애니메이션 (풍선파티와 동일)
            balloon["bounce"] += 0.2
            balloon["y"] += int(math.sin(balloon["bounce"]) * 1)
            
            # 벽 충돌 감지 및 튕김 처리 (풍선파티와 동일한 로직)
            if balloon["x"] - balloon["radius"] <= 0:  # 왼쪽 벽
                balloon["x"] = balloon["radius"]
                balloon["vx"] = abs(balloon["vx"])  # 오른쪽으로 튕김
            elif balloon["x"] + balloon["radius"] >= self.screen_width:  # 오른쪽 벽
                balloon["x"] = self.screen_width - balloon["radius"]
                balloon["vx"] = -abs(balloon["vx"])  # 왼쪽으로 튕김
                
            if balloon["y"] - balloon["radius"] <= 0:  # 위쪽 벽
                balloon["y"] = balloon["radius"]
                balloon["vy"] = abs(balloon["vy"])  # 아래쪽으로 튕김
            elif balloon["y"] + balloon["radius"] >= self.screen_height:  # 아래쪽 벽
                balloon["y"] = self.screen_height - balloon["radius"]
                balloon["vy"] = -abs(balloon["vy"])  # 위쪽으로 튕김
    
    def draw_background(self, screen: pygame.Surface):
        """배경 요소 그리기 (공 아래에 그려질 요소들)"""
        if not self.active:
            return
        
        # 문 그리기
        if self.door_open_percent > 0:
            self._draw_door(screen)
        
        # 기계 그리기 (대기 상태에서도 그리기)
        if self.phase in ["machine_rising", "machine_rise_wait", "shooting", "shooting_wait", "machine_lowering"]:
            self._draw_machine(screen)
    
    def draw(self, screen: pygame.Surface):
        """이벤트 그리기 (공 위에 그려질 요소들)"""
        if not self.active:
            return
        
        # 풍선만 그리기 (공 위에 그려짐)
        self._draw_balloons(screen)
        
        # 디버그 정보 (개발 중에만)
        # self._draw_debug_info(screen)
    
    def _draw_door(self, screen: pygame.Surface):
        """중앙 문 그리기 (원형 포털 스타일 - 테두리만)"""
        # 포털 크기 (열린 정도에 따라)
        portal_radius = int(100 * self.door_open_percent)
        
        if portal_radius > 0:
            # 포털 배경 제거 - 공이 보이도록 투명하게
            # 포털 테두리만 그리기 (여러 겹)
            for i in range(5):  # 더 많은 테두리로 포털 느낌 강화
                radius = portal_radius - i * 3
                if radius > 0:
                    # 바깥쪽은 밝고 안쪽은 어둡게
                    color_value = 100 + (4 - i) * 25
                    alpha = 200 - i * 30
                    # 테두리만 그리기 (width 파라미터로 선 두께 지정)
                    pygame.draw.circle(screen, (color_value, color_value, color_value + 30), 
                                     (self.machine_x, self.machine_y), radius, 3)
            
    
    def _draw_machine(self, screen: pygame.Surface):
        """풍선 발사 기계 그리기 (메카니컬 십자 터렛 스타일)"""
        if self.machine_scale <= 0:
            return
            
        # 투명도 효과
        alpha = int(200 * self.machine_scale)
        center_x = self.machine_x
        center_y = self.machine_y
        
        # 십자형 터렛 베이스 그리기
        # 수직 빔
        beam_width = int(30 * self.machine_scale)
        beam_length = int(100 * self.machine_scale)
        
        # 수직 빔 (위아래)
        vertical_surface = pygame.Surface((beam_width, beam_length), pygame.SRCALPHA)
        # 메탈릭 그라데이션 효과
        for i in range(beam_width):
            shade = 80 + int(40 * abs((i - beam_width/2) / (beam_width/2)))
            pygame.draw.line(vertical_surface, (shade, shade, shade + 20, alpha),
                           (i, 0), (i, beam_length))
        # 중앙 하이라이트
        pygame.draw.line(vertical_surface, (200, 200, 220, alpha),
                       (beam_width//2, 0), (beam_width//2, beam_length), 2)
        screen.blit(vertical_surface, (center_x - beam_width//2, center_y - beam_length//2))
        
        # 수평 빔 (좌우)
        horizontal_surface = pygame.Surface((beam_length, beam_width), pygame.SRCALPHA)
        for i in range(beam_width):
            shade = 80 + int(40 * abs((i - beam_width/2) / (beam_width/2)))
            pygame.draw.line(horizontal_surface, (shade, shade, shade + 20, alpha),
                           (0, i), (beam_length, i))
        # 중앙 하이라이트
        pygame.draw.line(horizontal_surface, (200, 200, 220, alpha),
                       (0, beam_width//2), (beam_length, beam_width//2), 2)
        screen.blit(horizontal_surface, (center_x - beam_length//2, center_y - beam_width//2))
        
        # 중앙 코어 (원형 터렛 허브)
        core_radius = int(25 * self.machine_scale)
        if core_radius > 0:
            # 외부 링
            pygame.draw.circle(screen, (100, 100, 120, alpha), 
                             (center_x, center_y), core_radius, 3)
            # 내부 링
            pygame.draw.circle(screen, (150, 150, 170, alpha), 
                             (center_x, center_y), core_radius - 5, 2)
            # 중심점
            pygame.draw.circle(screen, (200, 200, 220, alpha), 
                             (center_x, center_y), 5)
        
        # 코너 조인트 (십자 연결부)
        joint_size = int(8 * self.machine_scale)
        if joint_size > 0:
            # 4개의 코너 조인트
            joints = [
                (center_x - beam_length//2, center_y),  # 왼쪽
                (center_x + beam_length//2, center_y),  # 오른쪽
                (center_x, center_y - beam_length//2),  # 위
                (center_x, center_y + beam_length//2),  # 아래
            ]
            for jx, jy in joints:
                pygame.draw.circle(screen, (120, 120, 140, alpha), (int(jx), int(jy)), joint_size)
                pygame.draw.circle(screen, (180, 180, 200, alpha), (int(jx), int(jy)), joint_size, 2)
        
        # 발사구 (6개 - 풍선 개수와 일치)
        for i in range(6):
            angle = (math.pi * 2 / 6) * i
            barrel_distance = 35 * self.machine_scale
            barrel_x = center_x + math.cos(angle) * barrel_distance
            barrel_y = center_y + math.sin(angle) * barrel_distance
            barrel_size = int(10 * self.machine_scale)
            
            if barrel_size > 0:
                # 발사구 외부 링
                pygame.draw.circle(screen, (60, 60, 80, alpha), (int(barrel_x), int(barrel_y)), barrel_size)
                # 발사구 내부 (더 어둡게)
                pygame.draw.circle(screen, (30, 30, 40, alpha), (int(barrel_x), int(barrel_y)), barrel_size - 2)
                # 발사구 하이라이트 링
                pygame.draw.circle(screen, (150, 150, 170, alpha), (int(barrel_x), int(barrel_y)), barrel_size, 2)
                # 중앙에서 발사구로 연결선
                connection_alpha = alpha // 2
                pygame.draw.line(screen, (100, 100, 120, connection_alpha), 
                               (center_x, center_y), (int(barrel_x), int(barrel_y)), 2)
                
                # 발사구에서 중심으로 연결선
                pygame.draw.line(screen, (100, 100, 130), 
                               (int(center_x), int(center_y)), 
                               (int(barrel_x), int(barrel_y)), 2)
        
        # 중심부 장식
        center_size = int(15 * self.machine_scale)
        if center_size > 0:
            pygame.draw.circle(screen, (200, 200, 220), (center_x, center_y), center_size)
            pygame.draw.circle(screen, (150, 150, 180), (center_x, center_y), center_size, 3)
        
        # 깜빡이는 라이트 효과
        if self.phase == "shooting" and self.timer % 20 < 10:
            light_size = int(8 * self.machine_scale)
            if light_size > 0:
                pygame.draw.circle(screen, (255, 100, 100), (center_x, center_y), light_size)
    
    def _draw_balloons(self, screen: pygame.Surface):
        """풍선 그리기 (풍선파티 스킬과 동일한 스타일)"""
        for balloon in self.balloons:
            x, y = balloon["x"], balloon["y"]
            radius = balloon["radius"]
            color = balloon["color"]
            is_special = balloon.get("is_special", False)
            
            if is_special:
                # 🌟 특별한 풍선 빛나는 효과
                # 글로우 효과 (여러 층의 반투명 원)
                glow_intensity = 0.7 + 0.3 * math.sin(self.timer * 0.05)  # 부드럽게 깜빡임
                glow_surface = pygame.Surface((radius * 6, radius * 6), pygame.SRCALPHA)
                
                # 외부 글로우 (3층)
                for i in range(3):
                    glow_radius = radius * (2.5 - i * 0.5)
                    alpha = int(20 * glow_intensity * (i + 1))
                    # 무지개색 글로우 효과
                    hue = (self.timer * 2 + i * 30) % 360
                    if hue < 120:  # 빨강 -> 노랑
                        glow_color = (255, int(255 * hue / 120), 0, alpha)
                    elif hue < 240:  # 노랑 -> 파랑
                        glow_color = (int(255 * (1 - (hue - 120) / 120)), 0, int(255 * (hue - 120) / 120), alpha)
                    else:  # 파랑 -> 빨강
                        glow_color = (int(255 * (hue - 240) / 120), 0, int(255 * (1 - (hue - 240) / 120)), alpha)
                    
                    pygame.draw.circle(glow_surface, glow_color, 
                                     (radius * 3, radius * 3), int(glow_radius))
                
                # 글로우 표면을 화면에 블릿
                screen.blit(glow_surface, (x - radius * 3, y - radius * 3))
                
                # 특별한 전통 무늬 풍선 (삼태극 소용돌이)
                # 원 전체를 3개 구역으로 나누어 그리기
                
                # 회전 애니메이션 (천천히)
                rotation = self.timer * 0.005
                
                # 배경 흰색
                pygame.draw.circle(screen, (255, 255, 255), (int(x), int(y)), radius)
                
                # 3개의 소용돌이 섹션 그리기
                angles = [0, 120, 240]  # 3등분
                colors = [(0, 70, 160), (206, 17, 38), (255, 196, 0)]  # 파랑, 빨강, 노랑
                
                for i, (angle, color) in enumerate(zip(angles, colors)):
                    # 각 섹션의 시작 각도 (회전 적용)
                    start_angle = math.radians(angle) + rotation
                    
                    # 소용돌이 헤드 (큰 원)
                    head_x = x + math.cos(start_angle) * radius * 0.4
                    head_y = y + math.sin(start_angle) * radius * 0.4
                    head_radius = radius * 0.35
                    pygame.draw.circle(screen, color, (int(head_x), int(head_y)), int(head_radius))
                    
                    # 소용돌이 꼬리 (작아지는 원들)
                    for j in range(1, 4):
                        tail_angle = start_angle + (j * 0.3)
                        tail_dist = radius * (0.4 - j * 0.08)
                        tail_x = x + math.cos(tail_angle) * tail_dist
                        tail_y = y + math.sin(tail_angle) * tail_dist
                        tail_radius = head_radius * (1 - j * 0.25)
                        if tail_radius > 0:
                            pygame.draw.circle(screen, color, (int(tail_x), int(tail_y)), int(tail_radius))
                
                # 중앙 원 (흰색)
                pygame.draw.circle(screen, (255, 255, 255), (int(x), int(y)), radius // 5)
                
                # 테두리 (검은색)
                pygame.draw.circle(screen, (0, 0, 0), (int(x), int(y)), radius, 2)
                
                # 하이라이트
                highlight_x = int(x - radius * 0.3)
                highlight_y = int(y - radius * 0.3)
                pygame.draw.circle(screen, (255, 255, 255, 120), (highlight_x, highlight_y), radius // 6)
            else:
                # 일반 풍선
                # 풍선 몸체
                pygame.draw.circle(screen, color, (int(x), int(y)), radius)
                
                # 풍선 테두리
                pygame.draw.circle(screen, (255, 255, 255), (int(x), int(y)), radius, 2)
                
                # 풍선 하이라이트 (반짝이는 효과)
                highlight_x = int(x - radius // 3)
                highlight_y = int(y - radius // 3)
                pygame.draw.circle(screen, (255, 255, 255), (highlight_x, highlight_y), radius // 4)
            
            # 풍선 줄 (아래쪽으로) - 모든 풍선 공통
            line_start = (int(x), int(y + radius))
            line_end = (int(x), int(y + radius + 20))
            pygame.draw.line(screen, (100, 100, 100), line_start, line_end, 2)
            
            # 풍선 움직임 방향 표시 (작은 화살표) - 모든 풍선 공통
            arrow_length = 8
            arrow_x = int(x + balloon["vx"] * arrow_length)
            arrow_y = int(y + balloon["vy"] * arrow_length)
            pygame.draw.line(screen, (200, 200, 200), (int(x), int(y)), (arrow_x, arrow_y), 1)
    
    def _draw_debug_info(self, screen: pygame.Surface):
        """디버그 정보 표시"""
        if self.font:
            debug_text = f"Phase: {self.phase} | Timer: {self.timer}"
            text_surface = self.font.render(debug_text, True, (255, 255, 0))
            screen.blit(text_surface, (10, 10))
    
    def deactivate(self):
        """이벤트 비활성화 및 다음 타이머 설정"""
        print(f"[BalloonMachine] 이벤트 종료, 다음 타이머 설정")
        self.active = False
        self._set_next_cooldown()  # 다음 이벤트까지의 쿨다운 설정
        self.phase = "idle"
        self.timer = 0
        # 풍선은 남겨둠 (계속 맵에서 돌아다니게)
        # self.balloons.clear()  
        # 풍선 기계 이벤트 비활성화 - 풍선은 필드에 남아있음
        print(f" [deactivate] Complete - active is now {self.active}")
    
    def reset(self):
        """이벤트 리셋 (새 게임 시작 시)"""
        self.active = False
        self.triggered_at_1 = False  # 1점 트리거 리셋
        self.triggered_at_3 = False  # 3점 트리거 리셋
        self.phase = "idle"
        self.timer = 0
        self.balloons.clear()  # 새 게임 시작 시에만 풍선 제거
        self.door_open_percent = 0.0
        self.machine_scale = 0.0
    
    def reset_for_deuce(self):
        """듀스 재시작 시 3점 트리거만 리셋"""
        print(f" [reset_for_deuce]   - triggered_at_3")
        self.triggered_at_3 = False  # 3점 트리거만 리셋 (듀스에서 다시 발동 가능하도록)
    
    def get_balloons(self) -> List[Dict]:
        """현재 활성화된 풍선 리스트 반환 (충돌 감지용)"""
        return self.balloons
    
    def check_balloon_collisions(self, ball_rect: Any, ball_radius: int, ball_vel: List[float], 
                                effects_manager: Any = None, sound_balloon: Any = None,
                                whip_active: bool = False, trade_point_system: Any = None) -> bool:
        """
        풍선과 공의 충돌 감지 (풍선파티 스킬과 동일한 로직)
        
        Args:
            ball_rect: 공의 pygame.Rect 객체
            ball_radius: 공의 반지름
            ball_vel: 공의 속도 벡터 [vx, vy] (참조로 전달되어 직접 수정됨)
            effects_manager: 이펙트 매니저 (풍선 터지는 효과)
            sound_balloon: 풍선 터지는 효과음
            whip_active: 상모돌리기 활성화 상태 (True일 때 각도 변경 없음)
            trade_point_system: TradePointSystem 인스턴스 (별 생성용)
            
        Returns:
            충돌이 발생했으면 True, 아니면 False
        """
        if not self.balloons:
            return False
        
        # 충돌 체크 시작
            
        collision_occurred = False
        
        for idx, balloon in enumerate(self.balloons[:]):  # 복사본으로 순회
            # 풍선의 중심점과 공의 중심점 사이의 거리 계산
            dx = ball_rect.centerx - balloon["x"]
            dy = ball_rect.centery - balloon["y"]
            distance = math.sqrt(dx*dx + dy*dy)
            
            # 충돌 감지 (공 반지름 + 풍선 반지름)
            collision_distance = ball_radius + balloon["radius"]
            
            if distance <= collision_distance:
                # 충돌한 풍선 처리
                is_special = balloon.get("is_special", False)
                
                # 🎈 풍선 터지는 효과음 재생
                if sound_balloon:
                    sound_balloon.play()
                
                # 풍선 터뜨리기 효과
                if effects_manager:
                    effects_manager.create_balloon_pop_effect(
                        balloon["x"], balloon["y"], balloon["color"]
                    )
                
                if is_special and trade_point_system:
                    # 특별한 풍선 터짐 - 트레이드 포인트 별 생성
                    star = trade_point_system.spawn_star(balloon["x"], balloon["y"], "balloon")
                
                # 풍선 제거
                self.balloons.remove(balloon)
                
                # 상모돌리기 활성화 중이면 각도 변경 없이 풍선만 터뜨림
                if not whip_active:
                    # 현재 공의 각도 계산
                    current_angle = math.atan2(ball_vel[1], ball_vel[0])
                    
                    # 세로 방향으로 더 많이 꺾이도록 조정
                    # 현재 각도가 수평에 가까운지 확인 (0도 또는 180도 근처)
                    horizontal_angle = abs(math.cos(current_angle))  # 1에 가까울수록 수평
                    
                    # 수평에 가까울수록 더 큰 세로 각도 변화 적용
                    if horizontal_angle > 0.7:  # 수평에 가까운 경우
                        # 위 또는 아래로 적당히 꺾기 (25도~35도) - 기존 45~60도에서 완화
                        if ball_vel[1] >= 0:
                            # 아래로 가고 있으면 위로 꺾기
                            angle_change = random.uniform(-0.611, -0.436)  # -35도 ~ -25도
                        else:
                            # 위로 가고 있으면 아래로 꺾기
                            angle_change = random.uniform(0.436, 0.611)  # 25도 ~ 35도
                    else:
                        # 이미 세로 방향이면 약간만 조정 (10도~20도) - 기존 15~30도에서 완화
                        angle_change = random.uniform(-0.349, 0.349)  # -20도 ~ +20도
                        # 세로 성분 강화
                        if abs(ball_vel[1]) < abs(ball_vel[0]) * 0.5:  # y속도가 너무 작으면
                            angle_change = random.choice([-0.524, 0.524])  # ±30도로 완화 (기존 ±45도)
                    
                    new_angle = current_angle + angle_change
                    
                    # 현재 속도 크기 유지
                    speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
                    
                    # 새로운 속도 벡터 계산
                    ball_vel[0] = math.cos(new_angle) * speed
                    ball_vel[1] = math.sin(new_angle) * speed
                    
                    # 최소 세로 속도 보장 (너무 수평이 되지 않도록)
                    min_vertical_ratio = 0.3  # 최소 30%는 세로 성분 (기존 40%에서 완화)
                    if abs(ball_vel[1]) < speed * min_vertical_ratio:
                        # 세로 속도가 너무 작으면 강제로 증가
                        ball_vel[1] = math.copysign(speed * min_vertical_ratio, ball_vel[1])
                        # 전체 속도 유지를 위해 가로 속도 조정
                        ball_vel[0] = math.copysign(math.sqrt(speed**2 - ball_vel[1]**2), ball_vel[0])
                    
                    # 공 각도 변경 완료
                
                collision_occurred = True
                # 한 프레임에 하나의 풍선만 터뜨리기
                break
        
        return collision_occurred

    def pop_balloon_at_point(self, x: float, y: float, radius: float = 0.0,
                             effects_manager: Any = None, sound_balloon: Any = None,
                             trade_point_system: Any = None) -> bool:
        """
        특정 좌표에서 풍선을 터뜨린다.

        코만도 권총 탄환처럼 작은 투사체가 풍선과 충돌할 때 사용한다.

        Args:
            x, y: 충돌 지점 좌표
            radius: 투사체의 반지름(픽셀)
            effects_manager: 팝 이펙트 생성에 사용
            sound_balloon: 풍선 터지는 효과음 (미지정 시 activate 때 전달된 사운드 사용)
            trade_point_system: 특별 풍선 보상 처리를 위한 시스템
        Returns:
            풍선을 터뜨렸다면 True, 아니면 False
        """
        if not self.balloons:
            return False

        hit_balloon = None
        for balloon in self.balloons:
            dx = x - balloon["x"]
            dy = y - balloon["y"]
            distance = math.sqrt(dx * dx + dy * dy)
            if distance <= balloon["radius"] + radius:
                hit_balloon = balloon
                break

        if not hit_balloon:
            return False

        is_special = hit_balloon.get("is_special", False)

        # 효과음: 우선 전달받은 사운드, 없으면 활성화 때 등록된 사운드 사용
        play_sound = sound_balloon or self.sound_balloon
        if play_sound:
            play_sound.play()

        # 팝 이펙트
        if effects_manager:
            effects_manager.create_balloon_pop_effect(
                hit_balloon["x"], hit_balloon["y"], hit_balloon["color"]
            )

        # 특별 풍선 보상 처리
        if is_special and trade_point_system:
            trade_point_system.spawn_star(hit_balloon["x"], hit_balloon["y"], "balloon")

        try:
            self.balloons.remove(hit_balloon)
        except ValueError:
            pass

        return True
    
    def _ease_out_cubic(self, t: float) -> float:
        """Ease-out cubic 애니메이션 커브"""
        return 1 - pow(1 - t, 3)
    
    def _ease_in_cubic(self, t: float) -> float:
        """Ease-in cubic 애니메이션 커브"""
        return t * t * t
    
    def reset(self):
        """이벤트 완전 리셋 (새 게임 시작 시)"""
        self.active = False
        self.phase = "idle"
        self.timer = 0
        self.balloons.clear()
        self._set_next_cooldown()  # 새로운 쿨다운 설정
        print("[BalloonMachine] 완전 리셋 - 새 게임 시작")
    
    def reset_for_deuce(self):
        """듀스 재시작 시 리셋 - 타이머는 유지"""
        # 듀스에서도 타이머는 계속 진행되도록 함
        print("[BalloonMachine] 듀스 리셋 - 타이머는 유지")
