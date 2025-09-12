import os
import sys

def resource_path(relative_path):
    """PyInstaller 번들과 일반 실행 모두에서 작동하는 리소스 경로 반환"""
    try:
        # PyInstaller 번들인 경우
        base_path = sys._MEIPASS
    except Exception:
        # 일반 Python 실행인 경우 - 상위 디렉토리로 이동
        base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    
    return os.path.join(base_path, relative_path)


# -*- coding: utf-8 -*-
import pygame
import math
import random

class AnimatedBackgroundStage2:
    def __init__(self, base_image_path="stage2_field.png"):
        self.base_image = pygame.image.load(resource_path(base_image_path)).convert()
        self.width = self.base_image.get_width()
        self.height = self.base_image.get_height()
        self.time = 0
        
        self.glow_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        self.particle_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        self.eye_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        self.center_x = self.width // 2
        self.center_y = self.height // 2
        self.stadium_radius = 80
        
        # 공 위치 추적용 변수
        self.ball_x = self.width // 2
        self.ball_y = self.height // 2
        
        # 표정 상태 ('neutral', 'happy', 'sad')
        self.expression = 'neutral'
        self.expression_timer = 0
        
        # 조명 효과 제거
        
        # 정글 잎사귀 떨어지기 (더 디테일하게)
        self.falling_leaves = []
        leaf_types = ['maple', 'oak', 'tropical']  # 다양한 잎 종류
        for _ in range(8):
            side = random.choice(['left', 'right'])
            if side == 'left':
                x = random.randint(0, 80)
            else:
                x = random.randint(self.width - 80, self.width)
            self.falling_leaves.append({
                'x': x,
                'y': random.randint(-100, 0),
                'speed': random.uniform(0.5, 2),
                'sway': random.uniform(0, math.pi * 2),
                'rotation': random.uniform(0, 360),
                'rotation_speed': random.uniform(-3, 3),
                'size': random.randint(8, 15),
                'type': random.choice(leaf_types),
                'color': random.choice([
                    (34, 139, 34),   # 밝은 녹색
                    (0, 128, 0),     # 중간 녹색
                    (85, 107, 47),   # 올리브 녹색
                    (107, 142, 35),  # 황록색
                    (154, 205, 50),  # 연두색
                ]),
                'side': side,
                'z_depth': random.uniform(0.5, 1.0)  # 깊이감을 위한 z값
            })
        
        # 덩굴 위치와 속성 (완전 정적)
        self.vines = []
        for i in range(6):
            self.vines.append({
                'x': random.randint(50, self.width - 50),
                'base_y': 0,  # 천장에서 시작하도록 고정
                'length': random.randint(100, 180),  # 더 길게 조정
                'thickness': random.randint(3, 6),
                'segments': [],  # 덩굴 세그먼트들
                'leaves': []  # 덩굴에 달린 잎들
            })
            # 덩굴 세그먼트 생성
            for j in range(10):
                self.vines[i]['segments'].append({
                    'offset_x': random.uniform(-5, 5),
                    'size': random.uniform(0.8, 1.2)
                })
        
        # 돌맹이들 제거 (사용자 요청)
        self.rocks = []
        
        # 🌿 리얼리스틱 덤불 시스템 (스크린샷 스타일)
        self.realistic_bushes = []
        
        # 보스 패들 주변 덤불 (상단 벽 근처)
        boss_positions = [
            {'x': 50, 'y': 40, 'size': 'large', 'variant': 0},    # 왼쪽 상단
            {'x': 550, 'y': 35, 'size': 'medium', 'variant': 1},  # 오른쪽 상단
            {'x': 25, 'y': 80, 'size': 'small', 'variant': 2},    # 왼쪽 중간
            {'x': 575, 'y': 75, 'size': 'medium', 'variant': 0},  # 오른쪽 중간
            {'x': 100, 'y': 25, 'size': 'small', 'variant': 1},   # 왼쪽 위 모서리
            {'x': 500, 'y': 20, 'size': 'large', 'variant': 2},   # 오른쪽 위 모서리
        ]
        
        # 플레이어 패들 주변 덤불 (하단 벽 근처)
        player_positions = [
            {'x': 50, 'y': 710, 'size': 'medium', 'variant': 1},   # 왼쪽 하단
            {'x': 550, 'y': 705, 'size': 'large', 'variant': 0},   # 오른쪽 하단
            {'x': 25, 'y': 670, 'size': 'small', 'variant': 2},    # 왼쪽 중간
            {'x': 575, 'y': 675, 'size': 'medium', 'variant': 1},  # 오른쪽 중간
            {'x': 100, 'y': 725, 'size': 'small', 'variant': 0},   # 왼쪽 아래 모서리
            {'x': 500, 'y': 720, 'size': 'large', 'variant': 2},   # 오른쪽 아래 모서리
        ]
        
        # 덤불 크기 정의
        size_map = {'small': 35, 'medium': 50, 'large': 70}
        
        for pos in boss_positions + player_positions:
            area_type = 'boss' if pos['y'] < 400 else 'player'
            bush = {
                'x': pos['x'],
                'y': pos['y'],
                'base_size': size_map[pos['size']],
                'variant': pos['variant'],  # 0,1,2 = 다른 덤불 스타일
                'rustle_amount': 0,  # 흔들림 정도 (평소에는 0)
                'rustle_angle': 0,   # 흔들림 방향
                'area': area_type,  # 영역 구분
                'clusters': self.generate_bush_clusters(size_map[pos['size']], pos['variant'], area_type),
                'leaves': self.generate_bush_leaves(size_map[pos['size']], pos['variant'], area_type)
            }
            self.realistic_bushes.append(bush)
        
        # 패들 위치 및 속도 추적용
        self.boss_paddle_x = self.width // 2
        self.player_paddle_x = self.width // 2
        self.prev_boss_paddle_x = self.width // 2
        self.prev_player_paddle_x = self.width // 2
        
        # 🗿 정글 보스 위기 상황 바위 시스템
        self.crisis_rocks = []  # 위기 상황 바위들
        self.earthquake_active = False  # 지진 효과 활성화
        self.earthquake_timer = 0  # 지진 타이머
        self.earthquake_duration = 60  # 정글지진 스킬 지속시간 감소 (60프레임) - 난이도 하향
        self.rock_spawn_triggered = False  # 바위 생성 트리거 여부
        self.crisis_triggered = False  # 위기 상황 발동 여부 (한 번만)
        
        # 🔥 보스 분노 애니메이션 시스템
        self.boss_rage_pending = False  # 다음 라운드에서 분노 애니메이션 예약
        self.boss_rage_active = False  # 분노 애니메이션 진행 중
        self.boss_rage_timer = 0  # 분노 애니메이션 타이머
        self.boss_stomp_count = 0  # 발 구르기 횟수
        self.boss_red_tint = 0  # 빨간색 틴트 강도 (0-255)
        self.boss_shake_offset_y = 0  # 보스 발구르기 Y축 흔들림
        self.cry_sound = None  # cry.wav 사운드 (pingfighter.py에서 전달받음)
        
        # 💢 발구르기 화면 흔들림 효과
        self.stomp_shake_offset_x = 0
        self.stomp_shake_offset_y = 0
        
        # 🧨 바위 파편 시스템
        self.rock_fragments = []  # 바위 파편들
        self.destroyed_rocks = []  # 파괴된 바위 추적
    
    def generate_bush_clusters(self, base_size, variant, area='boss'):
        """스크린샷 스타일의 덤불 클러스터 생성 (완전 정적)"""
        clusters = []
        
        # 플레이어 덤불은 더 덤불스럽게 (더 많은 클러스터, 더 불규칙)
        if area == 'player':
            cluster_count = 8 + (variant % 4)  # 플레이어: 8-11개 클러스터
            irregularity_factor = 1.5  # 더 불규칙한 모양
            density_factor = 1.2  # 더 밀집된 형태
        else:  # boss
            cluster_count = 6 + (variant % 3)  # 보스: 6-8개 클러스터
            irregularity_factor = 1.0  # 기본 불규칙성
            density_factor = 1.0  # 기본 밀도
        
        for i in range(cluster_count):
            # 시드 기반으로 완전히 결정적인 값들 생성
            seed = hash((base_size, variant, i, area)) % 10000
            angle_offset = (seed % 100) / 100.0 * 0.6 * irregularity_factor - 0.3 * irregularity_factor
            distance_factor = ((seed // 100) % 100) / 100.0 * 0.6 + 0.2
            size_factor = ((seed // 10000) % 100) / 100.0 * 0.6 + 0.4
            darkness_factor = ((seed // 1000000) % 100) / 100.0 * 0.4 + 0.6
            
            angle = (i / cluster_count) * 2 * math.pi + angle_offset
            distance = distance_factor * base_size * density_factor
            
            # 클러스터 포인트들을 미리 계산해서 저장
            cluster_points = []
            # 플레이어 덤불은 더 많은 포인트로 더 복잡한 모양
            num_points = 15 if area == 'player' else 12
            
            for j in range(num_points):
                point_seed = hash((seed, j, area)) % 10000
                variation = ((point_seed % 100) / 100.0) * 0.5 * irregularity_factor + 0.5
                
                point_angle = (j / num_points) * 2 * math.pi
                # 플레이어 덤불은 더 불규칙한 반경
                if area == 'player':
                    radius_noise = ((point_seed // 100) % 100) / 100.0 * 0.4 - 0.2  # -0.2 ~ 0.2
                    radius = (size_factor * base_size) * (variation + radius_noise)
                else:
                    radius = (size_factor * base_size) * variation
                
                point_x = math.cos(angle) * distance + math.cos(point_angle) * radius
                point_y = math.sin(angle) * distance + math.sin(point_angle) * radius
                cluster_points.append((point_x, point_y))
            
            cluster = {
                'offset_x': math.cos(angle) * distance,
                'offset_y': math.sin(angle) * distance,
                'size': size_factor * base_size,
                'darkness': darkness_factor,
                'variant_mod': variant,
                'static_points': cluster_points,  # 미리 계산된 포인트들
                'area_type': area  # 영역 타입 저장
            }
            clusters.append(cluster)
        
        return clusters
    
    def generate_bush_leaves(self, base_size, variant, area='boss'):
        """덤불 위 개별 잎사귀들 생성 (완전 정적)"""
        leaves = []
        
        # 플레이어 덤불은 더 많은 잎사귀로 더 덤불스럽게
        if area == 'player':
            leaf_count = 15 + (variant % 8)  # 플레이어: 15-22개 잎사귀
        else:  # boss
            leaf_count = 10 + (variant % 6)  # 보스: 10-15개 잎사귀
        
        leaf_types = ['oval', 'pointed', 'serrated']
        
        for i in range(leaf_count):
            # 시드 기반으로 완전히 결정적인 값들 생성
            seed = hash((base_size, variant, i, 'leaf', area)) % 100000
            
            angle = (seed % 360) * math.pi / 180  # 0 ~ 2π
            distance_factor = ((seed // 360) % 100) / 100.0 * 0.8 + 0.3  # 0.3 ~ 1.1
            
            # 플레이어 덤불은 더 다양한 크기의 잎사귀
            if area == 'player':
                size = ((seed // 36000) % 7) + 3  # 3 ~ 9 (더 넓은 범위)
            else:
                size = ((seed // 36000) % 5) + 4  # 4 ~ 8
            
            rotation = (seed % 360)  # 0 ~ 360도
            color_variant = (seed // 100) % 4  # 0 ~ 3
            leaf_type = leaf_types[(seed // 10000) % 3]  # oval, pointed, serrated
            
            distance = distance_factor * base_size
            
            leaf = {
                'offset_x': math.cos(angle) * distance,
                'offset_y': math.sin(angle) * distance,
                'size': size,
                'rotation': rotation,
                'color_variant': color_variant,
                'type': leaf_type
            }
            leaves.append(leaf)
        
        return leaves
    
    def trigger_bush_rustle(self, area, paddle_x, intensity_type='normal'):
        """패들 움직임에 따른 덤불 흔들림 트리거 (속도별 차등 적용)"""
        rustle_range = 150  # 흔들림 영향 범위 (픽셀)
        
        # 속도별 흔들림 강도 설정
        if intensity_type == 'dash':
            base_rustle = 15.0  # 대쉬 시 더 강한 흔들림
            angle_multiplier = 0.6  # 더 큰 각도
        else:  # normal
            base_rustle = 8.0   # 일반 이동 시 기본 흔들림
            angle_multiplier = 0.3  # 기본 각도
        
        for bush in self.realistic_bushes:
            if bush['area'] == area:
                # 패들과 덤불 사이의 거리 계산
                distance = abs(bush['x'] - paddle_x)
                
                if distance < rustle_range:
                    # 거리에 따른 흔들림 강도 (가까울수록 강함)
                    distance_factor = (rustle_range - distance) / rustle_range
                    bush['rustle_amount'] = distance_factor * base_rustle
                    
                    # 패들 이동 방향에 따른 흔들림 방향
                    if paddle_x > bush['x']:
                        bush['rustle_angle'] = angle_multiplier  # 오른쪽으로 흔들림
                    else:
                        bush['rustle_angle'] = -angle_multiplier  # 왼쪽으로 흔들림
    
    def set_expression(self, expression):
        """표정 설정 ('neutral', 'happy', 'sad')"""
        self.expression = expression
        self.expression_timer = 120  # 2초 동안 표정 유지
    
    def check_crisis_situation(self, player_score, boss_score):
        """보스 위기 상황 감지 (플레이어가 1점만 더 먹으면 승리)"""
        # 위기 상황: 플레이어 4점, 보스 0-4점 (플레이어가 1점만 더 먹으면 5점으로 승리)
        is_crisis = (player_score == 4 and boss_score <= 4 and not self.crisis_triggered and not self.boss_rage_pending)
        
        if is_crisis:
            # 다음 라운드에서 보스 분노 애니메이션 예약
            self.boss_rage_pending = True
            self.crisis_triggered = True
            print("⚠️ Stage 2: 보스 위기 감지! 다음 라운드에서 분노 폭발 예정...")
        
        return is_crisis
    
    def start_boss_rage_animation(self):
        """보스 분노 애니메이션 시작 (다음 라운드 시작 시)"""
        if self.boss_rage_pending and not self.boss_rage_active:
            self.boss_rage_pending = False
            self.boss_rage_active = True
            self.boss_rage_timer = 0
            self.boss_stomp_count = 0
            print("😡 Stage 2 보스 분노 폭발! 바닥을 쿵쿵 밟기 시작!")
            return True
        return False
    
    def trigger_earthquake(self):
        """정글 지진 효과 시작"""
        self.earthquake_active = True
        self.earthquake_timer = 0
        self.rock_spawn_triggered = False
        print(f"🌋 정글지진 효과 시작! 지속시간: {self.earthquake_duration}프레임")
    
    def spawn_skill_rocks(self):
        """정글지진 스킬 발동 시 바위 1-3개 즉시 생성"""
        # 맵 전체 영역
        map_x_min = 50   # 맵 가장자리 여유
        map_x_max = 550  # 맵 가장자리 여유
        map_y_min = 50   # 상단 여유 (UI 공간)
        map_y_max = 700  # 하단 여유 (플레이어 공간)
        
        # 실제 바위 스타일 (참조 이미지 기반 자연 바위)
        rock_styles = [
            {'type': 'dark_granite', 'colors': [(35, 35, 40), (55, 55, 60), (75, 75, 80)]},     # 어두운 화강암
            {'type': 'light_granite', 'colors': [(120, 115, 110), (140, 135, 130), (160, 155, 150)]}, # 밝은 화강암  
            {'type': 'reddish_stone', 'colors': [(85, 65, 55), (105, 85, 75), (125, 105, 95)]}, # 적갈색 바위
            {'type': 'yellowish_stone', 'colors': [(140, 120, 85), (160, 140, 105), (180, 160, 125)]}, # 황갈색 바위
            {'type': 'gray_stone', 'colors': [(70, 70, 75), (90, 90, 95), (110, 110, 115)]},    # 회색 바위
            {'type': 'mixed_stone', 'colors': [(95, 85, 80), (115, 105, 100), (135, 125, 120)]} # 혼합 바위
        ]
        
        num_rocks = random.randint(1, 2)  # 1-2개 바위 생성
        for i in range(num_rocks):
            # 맵 전체 랜덤 위치
            x = random.randint(map_x_min, map_x_max)
            y = random.randint(map_y_min, map_y_max)
            
            # 기존 바위들과 거리 확인 (너무 가깝지 않게)
            attempts = 0
            while attempts < 10:  # 최대 10번 시도
                too_close = False
                for existing_rock in self.crisis_rocks:
                    if abs(x - existing_rock['x']) < 70 and abs(y - existing_rock['y']) < 70:
                        too_close = True
                        break
                
                if not too_close:
                    break
                    
                x = random.randint(map_x_min, map_x_max)
                y = random.randint(map_y_min, map_y_max)
                attempts += 1
            
            # 20% 확률로 황금 바위 생성
            is_golden = random.random() < 0.20
            
            # 바위 속성
            if is_golden:
                # 황금 바위 스타일
                style = {'type': 'golden_rock', 'colors': [(255, 215, 0), (255, 223, 100), (255, 230, 150)]}
            else:
                style = random.choice(rock_styles)
            size = random.randint(25, 90)  # 랜덤 크기 (최대 2배)
            
            # 바위별로 고정된 불규칙한 점들 생성 (정적)
            rock_seed = hash((x, y, size, i, pygame.time.get_ticks())) % 10000
            random.seed(rock_seed)  # 바위별 고정 시드
            
            # 바위 모양을 위한 고정 점들 미리 생성 (더 둥글고 자연스럽게)
            fixed_points = []
            num_points = random.randint(12, 20)  # 더 많은 점으로 부드럽게
            for j in range(num_points):
                angle = (j / num_points) * 2 * math.pi
                # 둥근 바위를 위한 부드러운 변화
                base_radius = 0.8
                # 사인파를 이용한 부드러운 변화
                wave1 = math.sin(angle * 2.3) * 0.15
                wave2 = math.sin(angle * 3.7) * 0.1
                noise = random.uniform(-0.1, 0.1)  # 작은 노이즈만 추가
                
                radius_ratio = base_radius + wave1 + wave2 + noise
                radius_ratio = max(0.5, min(1.0, radius_ratio))  # 0.5 ~ 1.0 사이로 제한
                
                px = math.cos(angle) * radius_ratio
                py = math.sin(angle) * radius_ratio
                fixed_points.append((px, py))
            
            random.seed()  # 시드 리셋
            
            # 🌠 정글지진 바위는 하늘에서 떨어지는 효과
            rock = {
                'x': x,
                'y': y,  # 목표 y 위치
                'target_y': y,  # 최종 목표 위치 저장
                'fall_y': -100 - random.randint(0, 200),  # 화면 위 -100~-300에서 시작
                'size': size,
                'rotation': random.uniform(0, 360),
                'falling': True,  # 정글지진 바위는 처음부터 떨어짐
                'fall_speed': 0,  # 초기 낙하 속도
                'gravity': 0.8 + random.uniform(-0.2, 0.2),  # 중력 가속도 (약간 랜덤)
                'bounce_count': 0,  # 바운스 횟수
                'max_bounces': random.randint(1, 2),  # 1-2번 바운스
                'fall_timer': 0,
                'style': style,
                'fixed_points': fixed_points,  # 고정된 불규칙한 점들
                'collision_rect': pygame.Rect(x - size//2, y - size//2, size, size),
                'spawn_delay': i * 10,  # 순차적으로 떨어지도록 딜레이 (10프레임씩)
                'delay_timer': 0,  # 딜레이 타이머
                'shadow_scale': 0.2,  # 그림자 초기 크기 (작게 시작)
                'rock_seed': rock_seed,  # 바위 고유 시드 추가
                'is_golden': is_golden  # 황금 바위 여부
            }
            self.crisis_rocks.append(rock)
        
        print(f"⚡ 정글지진 스킬로 바위 {num_rocks}개 생성!")
    
    def spawn_crisis_rocks(self):
        """위기 상황 바위 3-4개 생성 (보스 패들 뒤쪽 방어벽)"""
        print("🔥🔥🔥 spawn_crisis_rocks() 함수 시작!")
        # 🛡️ 보스 패들 뒤쪽 영역만 지정 (방어벽 형태)
        # 보스 패들은 y=90 위치, 바위는 그 뒤쪽(위쪽) y=20~80 영역에 생성
        map_x_min = 80   # 왼쪽 여유
        map_x_max = 520  # 오른쪽 여유
        map_y_min = 20   # 보스 뒤쪽 상단 (화면 상단 근처)
        map_y_max = 80   # 보스 패들 바로 뒤 (보스 패들 y=90)
        
        # 실제 바위 스타일 (참조 이미지 기반 자연 바위)
        rock_styles = [
            {'type': 'dark_granite', 'colors': [(35, 35, 40), (55, 55, 60), (75, 75, 80)]},     # 어두운 화강암
            {'type': 'light_granite', 'colors': [(120, 115, 110), (140, 135, 130), (160, 155, 150)]}, # 밝은 화강암  
            {'type': 'reddish_stone', 'colors': [(85, 65, 55), (105, 85, 75), (125, 105, 95)]}, # 적갈색 바위
            {'type': 'yellowish_stone', 'colors': [(140, 120, 85), (160, 140, 105), (180, 160, 125)]}, # 황갈색 바위
            {'type': 'gray_stone', 'colors': [(70, 70, 75), (90, 90, 95), (110, 110, 115)]},    # 회색 바위
            {'type': 'mixed_stone', 'colors': [(95, 85, 80), (115, 105, 100), (135, 125, 120)]} # 혼합 바위
        ]
        
        # 🛡️ 방어벽 형태로 3-4개 바위 생성
        num_rocks = random.randint(3, 4)
        
        # 가로 방향으로 균등하게 배치 (방어벽 형태)
        x_spacing = (map_x_max - map_x_min) / (num_rocks + 1)
        
        for i in range(num_rocks):
            # X 위치는 균등 배치 + 약간의 랜덤 오프셋
            base_x = map_x_min + x_spacing * (i + 1)
            x_offset = random.randint(-20, 20)  # 약간의 무작위성
            x = int(base_x + x_offset)
            x = max(map_x_min, min(map_x_max, x))  # 범위 제한
            
            # Y 위치는 보스 뒤쪽 영역에서 랜덤 (2줄 정도로 배치)
            if i % 2 == 0:
                y = random.randint(map_y_min, map_y_min + 30)  # 첫 번째 줄
            else:
                y = random.randint(map_y_min + 30, map_y_max)  # 두 번째 줄
            
            # 20% 확률로 황금 바위 생성
            is_golden = random.random() < 0.20
            
            # 바위 속성
            if is_golden:
                # 황금 바위 스타일
                style = {'type': 'golden_rock', 'colors': [(255, 215, 0), (255, 223, 100), (255, 230, 150)]}
            else:
                style = random.choice(rock_styles)
            size = random.randint(25, 90)  # 랜덤 크기 (최대 2배)
            
            # 바위별로 고정된 불규칙한 점들 생성 (정적)
            rock_seed = hash((x, y, size, i)) % 10000
            random.seed(rock_seed)  # 바위별 고정 시드
            
            # 바위 모양을 위한 고정 점들 미리 생성 (더 둥글고 자연스럽게)
            fixed_points = []
            num_points = random.randint(12, 20)  # 더 많은 점으로 부드럽게
            for j in range(num_points):
                angle = (j / num_points) * 2 * math.pi
                # 둥근 바위를 위한 부드러운 변화
                base_radius = 0.8
                # 사인파를 이용한 부드러운 변화
                wave1 = math.sin(angle * 2.3) * 0.15
                wave2 = math.sin(angle * 3.7) * 0.1
                noise = random.uniform(-0.1, 0.1)  # 작은 노이즈만 추가
                
                radius_ratio = base_radius + wave1 + wave2 + noise
                
                # 타원형으로 약간 납작하게
                point_x = math.cos(angle) * radius_ratio
                point_y = math.sin(angle) * radius_ratio * 0.85
                fixed_points.append((point_x, point_y))
            
            # 원래 랜덤 시드 복원
            random.seed()
            
            # 🌠 위기 상황 바위도 하늘에서 떨어지는 효과
            rock = {
                'x': x,
                'y': y,  # 목표 y 위치
                'target_y': y,  # 최종 목표 위치 저장
                'fall_y': -150 - random.randint(0, 100),  # 화면 위 -150~-250에서 시작
                'size': size,
                'style': style,
                'fall_y': -100 - size,  # 화면 밖에서 시작
                'target_y': y,  # 최종 도착 지점
                'falling': True,
                'fall_speed': 2,  # 초기 속도
                'gravity': 0.8,
                'bounce_count': 0,
                'max_bounces': random.randint(1, 2),  # 1-2번 바운스
                'collision_rect': pygame.Rect(x - size//2, y - size//2, size, size),
                'fixed_points': fixed_points,  # 고정된 불규칙한 점들
                'rock_seed': rock_seed,  # 바위 고유 시드
                'spawn_delay': i * 8,  # 순차적으로 떨어지도록 딜레이 (8프레임씩)
                'delay_timer': 0,  # 딜레이 타이머
                'shadow_scale': 0.2,  # 그림자 초기 크기 (작게 시작)
                'rotation': random.uniform(0, 360),  # 회전 각도
                'is_golden': is_golden  # 황금 바위 여부
            }
            
            self.crisis_rocks.append(rock)
            print(f"  🪨 바위 {i+1} 추가됨: x={x}, y={y}, size={size}")
        
        print(f"🪨 위기 상황 바위 {num_rocks}개 생성! 보스 패들 뒤쪽 방어벽 구축")
        print(f"🔍 현재 crisis_rocks 리스트 크기: {len(self.crisis_rocks)}")
    
    def destroy_rock(self, rock):
        """바위 파괴 및 파편 생성 애니메이션"""
        # 파편 생성 (8-12개)
        num_fragments = random.randint(8, 12)
        
        for i in range(num_fragments):
            angle = (i / num_fragments) * 2 * math.pi + random.uniform(-0.3, 0.3)
            speed = random.uniform(3, 8)
            
            fragment = {
                'x': rock['x'],
                'y': rock['fall_y'] if rock['falling'] else rock['y'],
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed - random.uniform(2, 5),  # 위로 튕김
                'size': random.randint(5, rock['size'] // 3),
                'color': random.choice(rock['style']['colors']),
                'rotation': random.uniform(0, 360),
                'rotation_speed': random.uniform(-15, 15),
                'gravity': 0.5,
                'life': 45,  # 0.75초
                'bounce': 0.6
            }
            self.rock_fragments.append(fragment)
        
        print(f"💥 바위 파괴! {num_fragments}개 파편 생성")
    
    def check_ball_rock_collision(self, ball_rect):
        """공과 바위 충돌 체크 및 파괴"""
        for i, rock in enumerate(self.crisis_rocks):
            if not rock['falling']:  # 떨어진 바위만 충돌 체크
                if ball_rect.colliderect(rock['collision_rect']):
                    rock_size = rock['size']
                    is_golden = rock.get('is_golden', False)
                    
                    # 바위 파괴
                    self.destroy_rock(rock)
                    # 바위 리스트에서 제거
                    self.crisis_rocks.pop(i)
                    
                    # 바위 중심 좌표 반환 (황금 바위 여부와 관계없이)
                    return True, rock_size, is_golden, rock['x'], rock['y']
        return False, 0, False, 0, 0
    
    def destroy_rock(self, rock):
        """바위 파괴 및 파편 생성 애니메이션"""
        # 파편 생성 (8-12개)
        num_fragments = random.randint(8, 12)
        
        for i in range(num_fragments):
            angle = (i / num_fragments) * 2 * math.pi + random.uniform(-0.3, 0.3)
            speed = random.uniform(3, 8)
            
            fragment = {
                'x': rock['x'],
                'y': rock['fall_y'] if rock['falling'] else rock['y'],
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed - random.uniform(2, 5),  # 위로 튕김
                'size': random.randint(5, rock['size'] // 3),
                'color': random.choice(rock['style']['colors']),
                'rotation': random.uniform(0, 360),
                'rotation_speed': random.uniform(-15, 15),
                'gravity': 0.5,
                'life': 45,  # 0.75초
                'bounce': 0.6
            }
            self.rock_fragments.append(fragment)
        
        print(f"💥 바위 파괴! {num_fragments}개 파편 생성")
    
    
    def update(self, dt, ball_x=None, ball_y=None, boss_paddle_x=None, player_paddle_x=None, 
               player_score=None, boss_score=None):
        self.time += dt
        
        # 보스 위기 상황 감지
        if player_score is not None and boss_score is not None:
            self.check_crisis_situation(player_score, boss_score)
        
        # 🔥 보스 분노 애니메이션 처리
        if self.boss_rage_active:
            self.boss_rage_timer += 1
            
            # 0-60 프레임: 빨간색으로 변하면서 발구르기
            if self.boss_rage_timer <= 60:
                # 빨간색 틴트 점진적 증가
                self.boss_red_tint = min(255, self.boss_rage_timer * 4)
                
                # 15프레임마다 발구르기 (총 4번)
                if self.boss_rage_timer % 15 == 0:
                    self.boss_stomp_count += 1
                    self.boss_shake_offset_y = 20  # 보스가 뛰어오름
                    # 💢 화면 흔들림 효과 시작 (발구르기 시작)
                    self.stomp_shake_offset_x = random.randint(-5, 5)
                    self.stomp_shake_offset_y = random.randint(-3, 3)
                    # cry.wav 사운드 재생 (이미 재생 중이면 중지하고 다시 재생)
                    if self.cry_sound:
                        self.cry_sound.stop()  # 기존 재생 중지
                        self.cry_sound.play()
                    print(f"💢 쿵! (발구르기 {self.boss_stomp_count}/4) - 😭 cry.wav 재생 - 화면 흔들림!")
                elif self.boss_rage_timer % 15 == 5:
                    self.boss_shake_offset_y = -10  # 착지 충격
                    # 💢 착지 시 더 강한 흔들림
                    self.stomp_shake_offset_x = random.randint(-8, 8)
                    self.stomp_shake_offset_y = random.randint(-6, 6)
                else:
                    self.boss_shake_offset_y = max(0, self.boss_shake_offset_y - 2)
                    # 💢 흔들림 점차 감소
                    self.stomp_shake_offset_x = int(self.stomp_shake_offset_x * 0.8)
                    self.stomp_shake_offset_y = int(self.stomp_shake_offset_y * 0.8)
            
            # 60-80 프레임: 최종 강한 발구르기와 함께 지진 시작
            elif self.boss_rage_timer == 80:
                print("💥💥 크아아악! 보스 최종 분노 폭발!")
                self.boss_shake_offset_y = 30
                # 💢 최종 발구르기 - 가장 강한 흔들림
                self.stomp_shake_offset_x = random.randint(-12, 12)
                self.stomp_shake_offset_y = random.randint(-10, 10)
                self.trigger_earthquake()
                self.spawn_crisis_rocks()
                print("🪨 하늘에서 바위가 떨어지기 시작! - 화면 대폭 흔들림!")
            
            # 80-100 프레임: 빨간색 서서히 사라짐
            elif self.boss_rage_timer <= 100:
                self.boss_red_tint = max(0, 255 - (self.boss_rage_timer - 80) * 12)
                self.boss_shake_offset_y = max(0, self.boss_shake_offset_y - 3)
                # 💢 바위 떨어지는 동안 흔들림 지속
                self.stomp_shake_offset_x = random.randint(-6, 6)
                self.stomp_shake_offset_y = random.randint(-4, 4)
            
            # 100 프레임 이후: 애니메이션 종료
            elif self.boss_rage_timer > 100:
                self.boss_rage_active = False
                self.boss_rage_timer = 0
                self.boss_red_tint = 0
                self.boss_shake_offset_y = 0
                # 💢 발구르기 흔들림 초기화
                self.stomp_shake_offset_x = 0
                self.stomp_shake_offset_y = 0
                print("😤 보스 분노가 가라앉았다...")
        
        # 지진 효과 처리
        if self.earthquake_active:
            self.earthquake_timer += 1
            
            # 지진 지속시간 동안 유지 (정글지진 스킬과 동기화)
            if self.earthquake_timer >= self.earthquake_duration:
                # 위기 상황 바위는 생성하지 않음 (정글지진 스킬이 이미 바위 생성)
                self.earthquake_active = False
                self.earthquake_timer = 0
                self.rock_spawn_triggered = False
                print("🌋 정글지진 효과 종료")
        
        # 공 위치 업데이트
        if ball_x is not None and ball_y is not None:
            self.ball_x = ball_x
            self.ball_y = ball_y
        
        # 패들 위치 및 속도 업데이트와 덤불 흔들림 처리
        if boss_paddle_x is not None:
            # 이동 거리 계산 (속도 추정)
            movement_distance = abs(boss_paddle_x - self.boss_paddle_x)
            
            if movement_distance > 2:  # 2픽셀 이상 움직임 감지
                # 속도에 따른 흔들림 강도 결정
                if movement_distance > 15:  # 대쉬 속도 (빠른 이동)
                    rustle_intensity = 'dash'
                else:  # 일반 이동
                    rustle_intensity = 'normal'
                
                self.trigger_bush_rustle('boss', boss_paddle_x, rustle_intensity)
            
            self.prev_boss_paddle_x = self.boss_paddle_x
            self.boss_paddle_x = boss_paddle_x
        
        if player_paddle_x is not None:
            # 이동 거리 계산 (속도 추정)
            movement_distance = abs(player_paddle_x - self.player_paddle_x)
            
            if movement_distance > 2:  # 2픽셀 이상 움직임 감지
                # 속도에 따른 흔들림 강도 결정
                if movement_distance > 15:  # 대쉬 속도 (빠른 이동)
                    rustle_intensity = 'dash'
                else:  # 일반 이동
                    rustle_intensity = 'normal'
                
                self.trigger_bush_rustle('player', player_paddle_x, rustle_intensity)
            
            self.prev_player_paddle_x = self.player_paddle_x
            self.player_paddle_x = player_paddle_x
        
        # 덤불 흔들림 업데이트 (자연스러운 감쇠)
        for bush in self.realistic_bushes:
            if bush['rustle_amount'] > 0:
                bush['rustle_amount'] *= 0.85  # 점진적 감쇠
                bush['rustle_angle'] += 0.2  # 부드러운 회전
                
                # 거의 멈추면 완전히 정지
                if bush['rustle_amount'] < 0.5:
                    bush['rustle_amount'] = 0
                    bush['rustle_angle'] = 0
        
        # 위기 상황 바위 애니메이션 업데이트
        for rock in self.crisis_rocks:
            # 🌠 정글지진 바위의 순차적 떨어짐 처리
            if 'spawn_delay' in rock and rock['delay_timer'] < rock['spawn_delay']:
                rock['delay_timer'] += 1
                continue  # 아직 떨어질 시간이 아님
            
            if rock['falling']:
                # 중력 적용
                rock['fall_speed'] += rock['gravity']
                rock['fall_y'] += rock['fall_speed']
                
                # 🌠 그림자 크기 업데이트 (바위가 떨어질수록 그림자 커짐)
                if 'shadow_scale' in rock:
                    # 높이에 따른 그림자 크기 계산
                    height_ratio = (rock['fall_y'] - (-300)) / (rock['target_y'] - (-300))
                    height_ratio = max(0, min(1, height_ratio))  # 0~1 사이로 제한
                    rock['shadow_scale'] = 0.2 + (0.8 * height_ratio)  # 0.2에서 1.0까지 증가
                
                # 착지 체크
                if rock['fall_y'] >= rock['target_y']:
                    rock['fall_y'] = rock['target_y']
                    rock['bounce_count'] += 1
                    
                    # 바운스 효과
                    if rock['bounce_count'] <= rock['max_bounces']:
                        rock['fall_speed'] = -rock['fall_speed'] * 0.6  # 반발력 감소
                    else:
                        rock['falling'] = False
                        rock['fall_speed'] = 0
                        rock['shadow_scale'] = 1.0  # 착지 후 그림자 최대 크기
                
                # 충돌 박스 업데이트
                rock['collision_rect'].x = rock['x'] - rock['size']//2
                rock['collision_rect'].y = rock['fall_y'] - rock['size']//2
        
        # 🧨 파편 업데이트
        fragments_to_remove = []
        for i, fragment in enumerate(self.rock_fragments):
            # 물리 업데이트
            fragment['x'] += fragment['vx']
            fragment['y'] += fragment['vy']
            fragment['vy'] += fragment['gravity']
            fragment['rotation'] += fragment['rotation_speed']
            
            # 바닥 충돌
            if fragment['y'] > 700:
                fragment['y'] = 700
                fragment['vy'] *= -fragment['bounce']
                fragment['vx'] *= 0.8
            
            # 수명 감소
            fragment['life'] -= 1
            if fragment['life'] <= 0:
                fragments_to_remove.append(i)
        
        # 오래된 파편 제거
        for i in reversed(fragments_to_remove):
            self.rock_fragments.pop(i)
        
        # 파괴 효과 타이머 업데이트
        destroyed_to_remove = []
        for i, destroyed in enumerate(self.destroyed_rocks):
            destroyed['timer'] -= 1
            if destroyed['timer'] <= 0:
                destroyed_to_remove.append(i)
        
        for i in reversed(destroyed_to_remove):
            self.destroyed_rocks.pop(i)
        
        # 표정 타이머 업데이트
        if self.expression_timer > 0:
            self.expression_timer -= 1
            if self.expression_timer <= 0:
                self.expression = 'neutral'
    
    def get_earthquake_offset(self):
        """지진 효과를 위한 화면 흔들림 오프셋 반환"""
        if not self.earthquake_active:
            return (0, 0)
        
        # 지진 강도 (시간에 따라 감소)
        progress = self.earthquake_timer / self.earthquake_duration
        intensity = 8 * (1 - progress)  # 8픽셀에서 시작해서 점차 감소
        
        # 랜덤한 방향으로 흔들림
        offset_x = (random.random() - 0.5) * intensity * 2
        offset_y = (random.random() - 0.5) * intensity * 2
        
        return (int(offset_x), int(offset_y))
    
    def get_stomp_shake_offset(self):
        """보스 발구르기를 위한 화면 흔들림 오프셋 반환"""
        return (self.stomp_shake_offset_x, self.stomp_shake_offset_y)
    
    def get_crisis_rocks(self):
        """위기 상황 바위 리스트 반환 (충돌 판정용)"""
        return [rock for rock in self.crisis_rocks if not rock['falling']]
        
        # 잎사귀 떨어지기 (더 자연스럽게)
        for leaf in self.falling_leaves:
            # 깊이에 따른 속도 조절
            leaf['y'] += leaf['speed'] * leaf['z_depth']
            leaf['sway'] += 0.03
            leaf['x'] += math.sin(leaf['sway']) * 1.5 * leaf['z_depth']
            
            # 회전 효과
            leaf['rotation'] += leaf['rotation_speed']
            
            # 바닥에 닿으면 다시 위로
            if leaf['y'] > self.height:
                leaf['y'] = random.randint(-100, -20)
                leaf['rotation'] = random.uniform(0, 360)
                if leaf['side'] == 'left':
                    leaf['x'] = random.randint(0, 80)
                else:
                    leaf['x'] = random.randint(self.width - 80, self.width)
        
        # 덩굴 흔들림 업데이트 제거 (완전 정적)
        
        # 🌿 덤불 흔들림 업데이트 제거 (완전 정적)
    
    def draw_3d_rock(self, surface, x, y, size, color_base, moss_coverage):
        """3D 느낌의 돌맹이 그리기"""
        # 그림자 그리기
        shadow_surface = pygame.Surface((size * 2, size), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surface, (0, 0, 0, 40), 
                           (0, size//2, size * 2, size))
        surface.blit(shadow_surface, (x - size, y + size//2))
        
        # 돌 본체 (레이어드 그라데이션)
        for i in range(size):
            progress = i / size
            # 빛을 받는 부분은 밝게, 그림자 부분은 어둡게
            brightness = int(color_base + (1 - progress) * 40)
            color = (brightness, brightness - 10, brightness - 15)
            
            # 불규칙한 돌 모양
            offset_x = math.sin(progress * math.pi * 3) * 2
            offset_y = math.cos(progress * math.pi * 2) * 1
            
            pygame.draw.circle(surface, color, 
                             (int(x + offset_x), int(y - i//3 + offset_y)), 
                             size - i)
        
        # 하이라이트 제거 - 돌의 광택 원형 디자인 삭제
        
        # 이끼 효과
        if moss_coverage > 0:
            moss_alpha = int(100 * moss_coverage)
            for _ in range(int(5 * moss_coverage)):
                moss_x = x + random.randint(-size//2, size//2)
                moss_y = y + random.randint(-size//3, size//3)
                moss_size = random.randint(2, 4)
                pygame.draw.circle(surface, (34, 100, 34, moss_alpha),
                                 (moss_x, moss_y), moss_size)
    
    def draw_detailed_leaf(self, surface, x, y, size, leaf_type, color, rotation):
        """디테일한 잎사귀 그리기"""
        # 잎사귀 그림자
        shadow_surface = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
        shadow_x = size * 2
        shadow_y = size * 2
        
        if leaf_type == 'maple':
            # 단풍잎 모양 (5개 끝, 더 자연스럽게)
            points = []
            inner_points = []
            for i in range(10):
                angle = i * 36
                rad = math.radians(angle)
                if i % 2 == 0:
                    # 바깥쪽 끝점
                    length = size * 1.2
                    points.append((shadow_x + math.cos(rad) * length,
                                 shadow_y + math.sin(rad) * length))
                else:
                    # 안쪽 계곡
                    length = size * 0.5
                    inner_points.append((shadow_x + math.cos(rad) * length,
                                       shadow_y + math.sin(rad) * length))
            
            # 단풍잎 모양 조합
            all_points = []
            for i in range(5):
                all_points.append(points[i])
                if i < len(inner_points):
                    all_points.append(inner_points[i])
            pygame.draw.polygon(shadow_surface, (0, 0, 0, 30), all_points)
            
        elif leaf_type == 'oak':
            # 참나무 잎 (타원형 with 톱니)
            pygame.draw.ellipse(shadow_surface, (0, 0, 0, 20),
                              (shadow_x - size//2, shadow_y - size, size, size * 2))
            
        else:  # tropical
            # 열대 잎 (길쭉한 타원)
            pygame.draw.ellipse(shadow_surface, (0, 0, 0, 20),
                              (shadow_x - size//3, shadow_y - size, size * 0.6, size * 2))
        
        # 그림자 먼저 그리기
        surface.blit(shadow_surface, (x - size * 2 + 5, y - size * 2 + 5))
        
        # 잎사귀 본체
        leaf_surface = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
        center_x = size * 2
        center_y = size * 2
        
        if leaf_type == 'maple':
            # 더 자연스러운 단풍잎
            points = []
            inner_points = []
            for i in range(10):
                angle = i * 36
                rad = math.radians(angle)
                if i % 2 == 0:
                    length = size * 1.2
                    points.append((center_x + math.cos(rad) * length,
                                 center_y + math.sin(rad) * length))
                else:
                    length = size * 0.5
                    inner_points.append((center_x + math.cos(rad) * length,
                                       center_y + math.sin(rad) * length))
            
            all_points = []
            for i in range(5):
                all_points.append(points[i])
                if i < len(inner_points):
                    all_points.append(inner_points[i])
            
            # 그라데이션 효과를 위한 레이어
            for layer in range(3):
                layer_color = tuple(min(255, c + layer * 10) if i < 3 else c 
                                  for i, c in enumerate(color[:3])) + (color[3] if len(color) > 3 else 255,)
                scale = 1 - layer * 0.1
                layer_points = [(center_x + (p[0] - center_x) * scale, 
                               center_y + (p[1] - center_y) * scale) for p in all_points]
                pygame.draw.polygon(leaf_surface, layer_color, layer_points)
            
            # 잎맥 그리기
            for point in points:
                vein_color = tuple(max(0, c - 40) for c in color[:3]) + (color[3] if len(color) > 3 else 255,)
                pygame.draw.line(leaf_surface, vein_color,
                               (center_x, center_y), point, 1)
                
        elif leaf_type == 'oak':
            # 참나무 잎 (물결 모양 가장자리)
            # 기본 타원
            for layer in range(3):
                layer_color = tuple(min(255, c + layer * 10) if i < 3 else c 
                              for i, c in enumerate(color[:3])) + (color[3] if len(color) > 3 else 255,)
                pygame.draw.ellipse(leaf_surface, layer_color,
                                  (center_x - size//2 + layer, center_y - size + layer, 
                                   size - layer*2, size * 2 - layer*2))
            
            # 물결 모양 가장자리
            for i in range(8):
                wave_angle = i * 45
                wave_rad = math.radians(wave_angle)
                wave_x = center_x + math.cos(wave_rad) * size * 0.4
                wave_y = center_y + math.sin(wave_rad) * size * 0.8
                pygame.draw.circle(leaf_surface, color, (int(wave_x), int(wave_y)), size//4)
            
            # 잎맥
            vein_color = tuple(max(0, c - 40) for c in color[:3]) + (color[3] if len(color) > 3 else 255,)
            pygame.draw.line(leaf_surface, vein_color,
                           (center_x, center_y - size), (center_x, center_y + size), 2)
            # 옆 잎맥들
            for i in range(3):
                offset = (i + 1) * size // 4
                pygame.draw.line(leaf_surface, vein_color,
                               (center_x, center_y - offset), 
                               (center_x + size//3, center_y - offset - size//4), 1)
                pygame.draw.line(leaf_surface, vein_color,
                               (center_x, center_y - offset), 
                               (center_x - size//3, center_y - offset - size//4), 1)
            
        else:  # tropical
            # 열대 잎 (날카로운 끝과 광택)
            # 잎 몸체 (뾰족한 타원)
            points = [
                (center_x, center_y - size * 1.3),  # 위 끝
                (center_x + size * 0.4, center_y - size * 0.5),
                (center_x + size * 0.5, center_y),
                (center_x + size * 0.4, center_y + size * 0.5),
                (center_x, center_y + size * 1.3),  # 아래 끝
                (center_x - size * 0.4, center_y + size * 0.5),
                (center_x - size * 0.5, center_y),
                (center_x - size * 0.4, center_y - size * 0.5),
            ]
            
            # 그라데이션 레이어
            for layer in range(3):
                layer_color = tuple(min(255, c + layer * 15) if i < 3 else c 
                              for i, c in enumerate(color[:3])) + (color[3] if len(color) > 3 else 255,)
                scale = 1 - layer * 0.15
                layer_points = [(center_x + (p[0] - center_x) * scale, 
                               center_y + (p[1] - center_y) * scale) for p in points]
                pygame.draw.polygon(leaf_surface, layer_color, layer_points)
            
            # 광택 효과
            highlight_color = tuple(min(255, c + 50) for c in color[:3]) + (50,)
            pygame.draw.ellipse(leaf_surface, highlight_color,
                              (center_x - size//4, center_y - size//2, size//2, size))
            
            # 잎맥
            vein_color = tuple(max(0, c - 40) for c in color[:3]) + (color[3] if len(color) > 3 else 255,)
            pygame.draw.line(leaf_surface, vein_color,
                           (center_x, center_y - size * 1.2), (center_x, center_y + size * 1.2), 2)
            # 평행 잎맥들
            for offset in [-size//6, size//6]:
                pygame.draw.line(leaf_surface, vein_color,
                               (center_x + offset, center_y - size), 
                               (center_x + offset, center_y + size), 1)
        
        # 회전 적용
        if rotation != 0:
            rotated_surface = pygame.transform.rotate(leaf_surface, rotation)
            rotated_rect = rotated_surface.get_rect(center=(x, y))
            surface.blit(rotated_surface, rotated_rect)
        else:
            surface.blit(leaf_surface, (x - size * 2, y - size * 2))
    
    def draw_vine(self, surface, vine):
        """자연스러운 덩굴 그리기"""
        x = vine['x']
        base_y = vine['base_y']
        
        # 덩굴 그림자 (완전 정적)
        for i, segment in enumerate(vine['segments']):
            segment_y = base_y + (i * vine['length'] / 10)
            shadow_x = x + segment['offset_x'] + 3  # 흔들림 제거
            shadow_y = segment_y + 3
            
            thickness = int(vine['thickness'] * segment['size'])
            pygame.draw.circle(surface, (0, 0, 0, 30),
                             (int(shadow_x), int(shadow_y)), thickness)
        
        # 덩굴 본체 (완전 정적)
        points = []
        for i, segment in enumerate(vine['segments']):
            segment_y = base_y + (i * vine['length'] / 10)
            segment_x = x + segment['offset_x']  # 흔들림 제거
            points.append((segment_x, segment_y))
            
            # 덩굴 마디 그리기
            thickness = int(vine['thickness'] * segment['size'])
            color_variation = 20 + i * 2
            color = (color_variation, 60 + color_variation, color_variation)
            pygame.draw.circle(surface, color,
                             (int(segment_x), int(segment_y)), thickness)
        
        # 덩굴 연결선
        if len(points) > 1:
            pygame.draw.lines(surface, (40, 80, 40), False, points, vine['thickness'])
        
        # 덩굴에 작은 잎 추가
        for i in range(0, len(points), 3):
            if i < len(points):
                leaf_x, leaf_y = points[i]
                pygame.draw.circle(surface, (50, 150, 50), 
                                 (int(leaf_x + 10), int(leaf_y)), 4)
                pygame.draw.circle(surface, (50, 150, 50), 
                                 (int(leaf_x - 10), int(leaf_y)), 4)
    
    def draw_boss_bush(self, surface, bush):
        """보스 지역 덤불 그리기 (실제 덤불 참고 디테일)"""
        x = int(bush['x'])
        y = int(bush['y'])
        size = int(bush['size'])
        base_color = bush['base_color']
        highlight_color = bush['highlight_color']
        
        # 덤불 그림자 (타원형으로 더 자연스럽게)
        shadow_surface = pygame.Surface((size * 3, size), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surface, (0, 0, 0, 30), 
                           (0, 0, size * 3, size))
        surface.blit(shadow_surface, (x - size * 1.5 + 5, y + size//2 + 8))
        
        # 🌿 순수 덤불 구조: 나무가지 없이 잎덩어리만
        
        # 흔들림 효과 제거 (완전 정적)
        rustle_offset_x = 0
        rustle_offset_y = 0
        
        # 덤불 잎덩어리들 (불규칙한 클러스터 형태)
        leaf_clusters = [
            # (offset_x, offset_y, cluster_size, depth_level)
            (-size//3, -size//4, size//2, 0.8),    # 왼쪽 클러스터
            (size//4, -size//3, size//2, 0.9),     # 오른쪽 클러스터  
            (-size//6, -size//2, size//3, 1.0),    # 왼쪽 위 클러스터
            (size//5, -size//2, size//3, 0.7),     # 오른쪽 위 클러스터
            (0, -size//6, size//2, 0.9),           # 중앙 클러스터
            (-size//2, 0, size//4, 0.6),           # 왼쪽 중간
            (size//2, 0, size//4, 0.6),            # 오른쪽 중간
        ]
        
        # 깊이순으로 정렬 (뒤에서부터 그리기)
        leaf_clusters.sort(key=lambda c: c[3])
        
        for cluster_x, cluster_y, cluster_size, depth in leaf_clusters:
            # 흔들림 효과 적용
            cluster_center_x = x + cluster_x + rustle_offset_x
            cluster_center_y = y + cluster_y + rustle_offset_y
            
            # 깊이에 따른 색상 조정
            depth_factor = depth
            cluster_base = (
                int(base_color[0] * depth_factor),
                int(base_color[1] * depth_factor), 
                int(base_color[2] * depth_factor)
            )
            cluster_highlight = (
                int(highlight_color[0] * (depth_factor + 0.2)),
                int(highlight_color[1] * (depth_factor + 0.2)),
                int(highlight_color[2] * (depth_factor + 0.2))
            )
            
            # 클러스터 기본 형태 (불규칙한 원형)
            num_segments = 8
            points = []
            for i in range(num_segments):
                angle = (i / num_segments) * 2 * math.pi
                # 불규칙성 추가
                radius_variation = cluster_size * (0.7 + 0.3 * random.random())
                point_x = cluster_center_x + math.cos(angle) * radius_variation
                point_y = cluster_center_y + math.sin(angle) * radius_variation
                points.append((point_x, point_y))
            
            # 클러스터 그리기
            if len(points) >= 3:
                pygame.draw.polygon(surface, cluster_base, points)
                
                # 하이라이트 레이어 (조금 작게)
                highlight_points = []
                for px, py in points:
                    scale = 0.7
                    hx = cluster_center_x + (px - cluster_center_x) * scale  
                    hy = cluster_center_y + (py - cluster_center_y) * scale
                    highlight_points.append((hx, hy))
                
                if len(highlight_points) >= 3:
                    pygame.draw.polygon(surface, cluster_highlight, highlight_points)
        
        # 3. 개별 잎사귀들 (디테일 추가)
        for i in range(12):
            leaf_angle = random.uniform(0, 360)
            leaf_distance = random.uniform(size * 0.3, size * 0.8)
            leaf_x = x + math.cos(math.radians(leaf_angle)) * leaf_distance + rustle_offset_x
            leaf_y = y + math.sin(math.radians(leaf_angle)) * leaf_distance - size//6 + rustle_offset_y
            
            # 잎사귀 색상 (약간의 변화)
            leaf_variation = random.uniform(0.8, 1.2)
            leaf_color = (
                int(min(255, highlight_color[0] * leaf_variation)),
                int(min(255, highlight_color[1] * leaf_variation)),
                int(min(255, highlight_color[2] * leaf_variation))
            )
            
            # 잎사귀 모양 (작은 타원)
            leaf_size = random.randint(3, 6)
            leaf_rect = (leaf_x - leaf_size//2, leaf_y - leaf_size//4, leaf_size, leaf_size//2)
            pygame.draw.ellipse(surface, leaf_color, leaf_rect)
        
        # 4. 최상층 하이라이트 (햇빛 받는 부분)
        light_spots = [
            (x - size//4 + rustle_offset_x, y - size//3 + rustle_offset_y, size//6),
            (x + size//3 + rustle_offset_x, y - size//4 + rustle_offset_y, size//8),
            (x + rustle_offset_x, y - size//2 + rustle_offset_y, size//7),
        ]
        
        bright_color = (
            min(255, highlight_color[0] + 40),
            min(255, highlight_color[1] + 30), 
            min(255, highlight_color[2] + 20)
        )
        
        for spot_x, spot_y, spot_size in light_spots:
            pygame.draw.circle(surface, bright_color, (int(spot_x), int(spot_y)), spot_size)
            # 더 밝은 중심점
            pygame.draw.circle(surface, (min(255, bright_color[0] + 20), 
                                       min(255, bright_color[1] + 15), 
                                       min(255, bright_color[2] + 10)), 
                             (int(spot_x), int(spot_y)), spot_size//2)
    
    def draw_realistic_bush(self, surface, bush):
        """스크린샷 스타일의 리얼리스틱 덤불 렌더링"""
        x = bush['x']
        y = bush['y']
        base_size = bush['base_size']
        variant = bush['variant']
        
        # 흔들림 효과 적용
        rustle_x = math.sin(bush['rustle_angle']) * bush['rustle_amount']
        rustle_y = math.cos(bush['rustle_angle'] * 1.5) * bush['rustle_amount'] * 0.3
        
        # 덤불 그림자 (타원형, 더 부드럽게)
        shadow_width = base_size * 2.2
        shadow_height = base_size * 0.8
        shadow_surface = pygame.Surface((int(shadow_width), int(shadow_height)), pygame.SRCALPHA)
        
        # 그라데이션 그림자
        for i in range(int(shadow_height // 2)):
            alpha = int(40 * (1 - i / (shadow_height // 2)))
            color = (0, 0, 0, alpha)
            pygame.draw.ellipse(shadow_surface, color, 
                               (0, i, shadow_width, shadow_height - i*2))
        
        surface.blit(shadow_surface, (x - shadow_width//2 + 8 + rustle_x, 
                                     y + base_size//2 + 5 + rustle_y))
        
        # 1단계: 베이스 클러스터 (가장 어두운 뒷배경)
        base_colors = [
            [(25, 60, 25), (35, 80, 35), (30, 70, 30)],    # variant 0: 어두운 녹색
            [(30, 65, 30), (40, 85, 40), (35, 75, 35)],    # variant 1: 중간 녹색  
            [(35, 70, 35), (45, 90, 45), (40, 80, 40)]     # variant 2: 밝은 녹색
        ]
        
        colors = base_colors[variant % 3]
        
        for cluster in bush['clusters']:
            cluster_x = x + cluster['offset_x'] + rustle_x
            cluster_y = y + cluster['offset_y'] + rustle_y
            cluster_size = cluster['size']
            darkness = cluster['darkness']
            
            # 클러스터 색상 (어두운 베이스)
            base_color = colors[0]
            dark_color = tuple(int(c * darkness * 0.7) for c in base_color)
            
            # 미리 계산된 포인트들 사용 (완전 정적)
            points = []
            for static_point in cluster['static_points']:
                point_x = cluster_x + static_point[0] + rustle_x
                point_y = cluster_y + static_point[1] + rustle_y
                points.append((point_x, point_y))
            
            # 베이스 클러스터 그리기
            if len(points) >= 3:
                pygame.draw.polygon(surface, dark_color, points)
        
        # 2단계: 중간 레이어 (조금 더 밝은 색상)
        for cluster in bush['clusters']:
            cluster_x = x + cluster['offset_x'] + rustle_x
            cluster_y = y + cluster['offset_y'] + rustle_y
            cluster_size = cluster['size'] * 0.8  # 조금 작게
            darkness = cluster['darkness']
            
            mid_color = colors[1]
            color = tuple(int(c * darkness * 0.85) for c in mid_color)
            
            # 중간 레이어 클러스터 (미리 계산된 포인트 사용)
            points = []
            scale = 0.8  # 조금 작게
            for static_point in cluster['static_points']:
                point_x = cluster_x + static_point[0] * scale + rustle_x
                point_y = cluster_y + static_point[1] * scale + rustle_y
                points.append((point_x, point_y))
            
            if len(points) >= 3:
                pygame.draw.polygon(surface, color, points)
        
        # 3단계: 상단 하이라이트 레이어 (가장 밝은 색상)
        for cluster in bush['clusters']:
            cluster_x = x + cluster['offset_x'] + rustle_x
            cluster_y = y + cluster['offset_y'] + rustle_y
            cluster_size = cluster['size'] * 0.6  # 더 작게
            darkness = cluster['darkness']
            
            highlight_color = colors[2]
            color = tuple(int(c * darkness) for c in highlight_color)
            
            # 하이라이트 클러스터 (미리 계산된 포인트 사용)
            points = []
            scale = 0.6  # 더 작게
            for static_point in cluster['static_points']:
                point_x = cluster_x + static_point[0] * scale + rustle_x
                point_y = cluster_y + static_point[1] * scale + rustle_y
                points.append((point_x, point_y))
            
            if len(points) >= 3:
                pygame.draw.polygon(surface, color, points)
        
        # 4단계: 개별 잎사귀 디테일
        leaf_colors = [
            (50, 120, 50), (60, 140, 60), (70, 160, 70), (45, 110, 45)
        ]
        
        for leaf in bush['leaves']:
            leaf_x = x + leaf['offset_x'] + rustle_x * 0.7  # 잎은 덜 흔들림
            leaf_y = y + leaf['offset_y'] + rustle_y * 0.7
            leaf_size = leaf['size']
            leaf_color = leaf_colors[leaf['color_variant']]
            
            if leaf['type'] == 'oval':
                # 타원형 잎
                pygame.draw.ellipse(surface, leaf_color,
                                   (leaf_x - leaf_size//2, leaf_y - leaf_size//4,
                                    leaf_size, leaf_size//2))
            elif leaf['type'] == 'pointed':
                # 뾰족한 잎
                points = [
                    (leaf_x, leaf_y - leaf_size//2),  # 위쪽 끝
                    (leaf_x + leaf_size//3, leaf_y),
                    (leaf_x, leaf_y + leaf_size//2),  # 아래쪽 끝
                    (leaf_x - leaf_size//3, leaf_y)
                ]
                pygame.draw.polygon(surface, leaf_color, points)
            else:  # serrated
                # 톱니 모양 잎
                pygame.draw.circle(surface, leaf_color, 
                                 (int(leaf_x), int(leaf_y)), leaf_size//2)
                # 작은 톱니들
                for i in range(4):
                    angle = i * 90 + 45
                    edge_x = leaf_x + math.cos(math.radians(angle)) * leaf_size//3
                    edge_y = leaf_y + math.sin(math.radians(angle)) * leaf_size//3
                    pygame.draw.circle(surface, leaf_color,
                                     (int(edge_x), int(edge_y)), 2)
        
        # 5단계: 최상위 광택 효과 (햇빛 받는 부분)
        if variant == 0:  # 첫 번째 스타일만 광택
            highlight_spots = [
                (x - base_size//4 + rustle_x, y - base_size//3 + rustle_y, base_size//8),
                (x + base_size//3 + rustle_x, y - base_size//5 + rustle_y, base_size//10)
            ]
            
            for spot_x, spot_y, spot_size in highlight_spots:
                bright_color = (min(255, colors[2][0] + 60),
                               min(255, colors[2][1] + 40),
                               min(255, colors[2][2] + 30))
                pygame.draw.circle(surface, bright_color, 
                                 (int(spot_x), int(spot_y)), spot_size)
    
    def draw_crisis_rock(self, surface, rock):
        """실제 바위 참고 울퉁불퉁한 위기 상황 바위 렌더링"""
        x = rock['x']
        y = rock['fall_y'] if rock['falling'] else rock['y']
        size = rock['size']
        style = rock['style']
        colors = style['colors']
        rock_type = style['type']
        is_golden = rock.get('is_golden', False)
        
        # 🌠 바위 그림자 (하늘에서 떨어질 때 작게 시작해서 커짐)
        shadow_scale = rock.get('shadow_scale', 1.0)  # 기본값 1.0
        
        # 그림자는 항상 목표 위치에 그려짐 (바닥)
        shadow_x = rock['x']
        shadow_y = rock.get('target_y', rock['y'])  # 목표 위치에 그림자
        
        shadow_width = size * 2.2 * shadow_scale
        shadow_height = size * 0.8 * shadow_scale
        
        # 떨어지는 동안 그림자 투명도도 변경 (높이 있을수록 투명)
        shadow_alpha = int(30 + 20 * shadow_scale)  # 30~50 투명도
        
        shadow_surface = pygame.Surface((int(shadow_width), int(shadow_height)), pygame.SRCALPHA)
        
        # 불규칙한 그림자 모양
        shadow_points = []
        for i in range(8):
            angle = (i / 8) * 2 * math.pi
            # 불규칙한 반지름으로 자연스러운 그림자
            radius_factor = 0.8 + 0.4 * math.sin(i * 1.7) * math.cos(i * 2.3)
            shadow_point_x = shadow_width//2 + math.cos(angle) * shadow_width//3 * radius_factor
            shadow_point_y = shadow_height//2 + math.sin(angle) * shadow_height//3 * radius_factor
            shadow_points.append((shadow_point_x, shadow_point_y))
        
        if len(shadow_points) >= 3:
            pygame.draw.polygon(shadow_surface, (0, 0, 0, shadow_alpha), shadow_points)
        
        # 그림자는 항상 바닥(목표 위치)에 그려짐
        surface.blit(shadow_surface, (shadow_x - shadow_width//2 + 4, shadow_y + size//3 + 1))
        
        # 참조 이미지 기반 바위 형태별 렌더링 (정적)
        fixed_points = rock.get('fixed_points', [])
        rock_seed = rock.get('rock_seed', 0)
        
        if rock_type == 'dark_granite':
            # 어두운 화강암 (각진 형태)
            self.draw_dark_granite_rock(surface, x, y, size, colors, fixed_points, rock_seed)
            
        elif rock_type == 'light_granite':
            # 밝은 화강암 (덜 각진 형태)
            self.draw_light_granite_rock(surface, x, y, size, colors, fixed_points, rock_seed)
            
        elif rock_type == 'reddish_stone':
            # 적갈색 바위 (불규칙한 덩어리)
            self.draw_reddish_stone_rock(surface, x, y, size, colors, fixed_points, rock_seed)
            
        elif rock_type == 'yellowish_stone':
            # 황갈색 바위 (삼각형 형태)
            self.draw_yellowish_stone_rock(surface, x, y, size, colors, fixed_points, rock_seed)
            
        elif rock_type == 'gray_stone':
            # 회색 바위 (둥근 형태)
            self.draw_gray_stone_rock(surface, x, y, size, colors, fixed_points, rock_seed)
            
        elif rock_type == 'mixed_stone':
            # 혼합 바위 (복합 형태)
            self.draw_mixed_stone_rock(surface, x, y, size, colors, fixed_points, rock_seed)
        elif rock_type == 'golden_rock':
            # 황금 바위 (특별한 형태)
            self.draw_golden_rock(surface, x, y, size, colors, fixed_points, rock_seed)
        
        # 황금 바위에만 반짝임 효과 추가
        if is_golden:
            # 황금빛 반짝임 효과
            sparkle_time = pygame.time.get_ticks() / 100
            sparkle_intensity = abs(math.sin(sparkle_time)) * 0.5 + 0.5
            
            # 황금 후광 효과
            glow_surf = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
            glow_alpha = int(50 * sparkle_intensity)
            pygame.draw.circle(glow_surf, (255, 215, 0, glow_alpha), 
                             (size * 3 // 2, size * 3 // 2), size)
            surface.blit(glow_surf, (x - size * 3 // 2, y - size * 3 // 2))
            
            # 작은 반짝임 파티클들
            for i in range(3):
                sparkle_angle = sparkle_time * 2 + i * 120
                sparkle_x = x + math.cos(sparkle_angle) * size * 0.7
                sparkle_y = y + math.sin(sparkle_angle) * size * 0.7
                sparkle_size = int(3 + sparkle_intensity * 2)
                pygame.draw.circle(surface, (255, 255, 200), 
                                 (int(sparkle_x), int(sparkle_y)), sparkle_size)
        
        # 공통 하이라이트 제거 - 바위 왼쪽 상단 원형 디자인 삭제
    
    def draw_golden_rock(self, surface, x, y, size, colors, fixed_points, rock_seed):
        """황금 바위 (빛나는 특별한 형태)"""
        # 황금 바위 기본 형태
        points = []
        for point_ratio in fixed_points:
            px = x + point_ratio[0] * size
            py = y + point_ratio[1] * size
            points.append((px, py))
        
        if len(points) >= 3:
            # 황금색 그라데이션 효과
            # 가장 밝은 층
            pygame.draw.polygon(surface, colors[2], points)
            
            # 중간 층 (약간 작게)
            mid_points = []
            for point in points:
                mid_x = x + (point[0] - x) * 0.85
                mid_y = y + (point[1] - y) * 0.85
                mid_points.append((mid_x, mid_y))
            if len(mid_points) >= 3:
                pygame.draw.polygon(surface, colors[1], mid_points)
            
            # 가장 어두운 중심부 (더 작게)
            inner_points = []
            for point in points:
                inner_x = x + (point[0] - x) * 0.6
                inner_y = y + (point[1] - y) * 0.6
                inner_points.append((inner_x, inner_y))
            if len(inner_points) >= 3:
                pygame.draw.polygon(surface, colors[0], inner_points)
            
            # 황금 테두리
            pygame.draw.polygon(surface, (255, 255, 100), points, 2)
    
    def draw_dark_granite_rock(self, surface, x, y, size, colors, fixed_points, rock_seed):
        """어두운 화강암 (둥근 형태)"""
        # 미리 생성된 고정 점들 사용
        main_points = []
        for point_x_ratio, point_y_ratio in fixed_points:
            point_x = x + point_x_ratio * size
            point_y = y + point_y_ratio * size
            main_points.append((point_x, point_y))
        
        # 3단계 레이어로 입체감 (부드러운 그라데이션)
        for layer in range(3):
            layer_color = colors[layer]
            scale = 1.0 - layer * 0.15  # 부드러운 단계
            
            layer_points = []
            for px, py in main_points:
                lx = x + (px - x) * scale
                ly = y + (py - y) * scale
                layer_points.append((lx, ly))
            
            if len(layer_points) >= 3:
                pygame.draw.polygon(surface, layer_color, layer_points)
        
        # 부드러운 음영 효과 - 시드 기반으로 고정
        random.seed(rock_seed)
        for i in range(2):  # 라인 수 줄임
            angle = random.uniform(0, 2 * math.pi)
            line_length = size * 0.3  # 길이 줄임
            start_x = x + math.cos(angle) * size * 0.2
            start_y = y + math.sin(angle) * size * 0.2
            end_x = start_x + math.cos(angle + 0.3) * line_length
            end_y = start_y + math.sin(angle + 0.3) * line_length
            edge_color = tuple(max(0, c - 20) for c in colors[1])
            pygame.draw.line(surface, edge_color, (int(start_x), int(start_y)), 
                           (int(end_x), int(end_y)), 1)  # 두께도 줄임
        random.seed()  # 시드 복원
    
    def draw_light_granite_rock(self, surface, x, y, size, colors, fixed_points, rock_seed):
        """밝은 화강암 (둥글고 부드러운 형태)"""
        # 미리 생성된 고정 점들을 둥글게 보정
        main_points = []
        for point_x_ratio, point_y_ratio in fixed_points:
            # 둥근 모양으로 보정
            angle = math.atan2(point_y_ratio, point_x_ratio)
            radius = math.sqrt(point_x_ratio**2 + point_y_ratio**2) * size * 0.7
            point_x = x + math.cos(angle) * radius
            point_y = y + math.sin(angle) * radius * 0.85  # 타원형
            main_points.append((point_x, point_y))
        
        # 3단계 레이어 (부드러운 그라데이션)
        for layer in range(3):
            layer_color = colors[layer]
            scale = 1.0 - layer * 0.15
            
            layer_points = []
            for px, py in main_points:
                lx = x + (px - x) * scale
                ly = y + (py - y) * scale
                layer_points.append((lx, ly))
            
            if len(layer_points) >= 3:
                pygame.draw.polygon(surface, layer_color, layer_points)
        
        # 밝은 알갱이 텍스처 제거 - 원형 grain 디자인 삭제
    
    def draw_reddish_stone_rock(self, surface, x, y, size, colors, fixed_points, rock_seed):
        """적갈색 바위 (둥근 덩어리 형태)"""
        # 미리 생성된 고정 점들을 둥글게 보정
        main_points = []
        for point_x_ratio, point_y_ratio in fixed_points:
            # 둥근 모양으로 보정
            angle = math.atan2(point_y_ratio, point_x_ratio)
            radius = math.sqrt(point_x_ratio**2 + point_y_ratio**2) * size * 0.75
            point_x = x + math.cos(angle) * radius
            point_y = y + math.sin(angle) * radius * 0.88
            main_points.append((point_x, point_y))
        
        # 3단계 레이어 (적갈색 톤)
        for layer in range(3):
            layer_color = colors[layer]
            scale = 1.0 - layer * 0.18
            
            layer_points = []
            for px, py in main_points:
                lx = x + (px - x) * scale
                ly = y + (py - y) * scale
                layer_points.append((lx, ly))
            
            if len(layer_points) >= 3:
                pygame.draw.polygon(surface, layer_color, layer_points)
        
        # 적갈색 바위 특유의 얼룩 패턴 제거 - 원형 spot 디자인 삭제
    
    def draw_yellowish_stone_rock(self, surface, x, y, size, colors, fixed_points, rock_seed):
        """황갈색 바위 (둥근 형태)"""
        # 미리 생성된 고정 점들을 둥글게 수정
        main_points = []
        for point_x_ratio, point_y_ratio in fixed_points:
            # 둥근 모양으로 조정
            angle = math.atan2(point_y_ratio, point_x_ratio)
            radius = math.sqrt(point_x_ratio**2 + point_y_ratio**2) * size * 0.75
            point_x = x + math.cos(angle) * radius
            point_y = y + math.sin(angle) * radius * 0.9  # 약간 타원형
            main_points.append((point_x, point_y))
        
        # 3단계 레이어 (황갈색 톤)
        for layer in range(3):
            layer_color = colors[layer]
            scale = 1.0 - layer * 0.16
            
            layer_points = []
            for px, py in main_points:
                lx = x + (px - x) * scale
                ly = y + (py - y) * scale
                layer_points.append((lx, ly))
            
            if len(layer_points) >= 3:
                pygame.draw.polygon(surface, layer_color, layer_points)
        
        # 황갈색 바위 특유의 그라데이션 라인 - 시드 기반으로 고정
        random.seed(rock_seed + 300)
        for i in range(3):
            line_angle = random.uniform(0, math.pi)
            line_start_x = x - size * 0.3 + random.randint(-5, 5)
            line_start_y = y - size * 0.2 + i * size * 0.2
            line_end_x = x + size * 0.3 + random.randint(-5, 5)
            line_end_y = line_start_y + random.randint(-3, 3)
            line_color = tuple(max(0, c - 20) for c in colors[1])
            pygame.draw.line(surface, line_color, (int(line_start_x), int(line_start_y)), 
                           (int(line_end_x), int(line_end_y)), 2)
        random.seed()  # 시드 복원
    
    def draw_gray_stone_rock(self, surface, x, y, size, colors, fixed_points, rock_seed):
        """회색 바위 (둥근 형태, 참조 이미지 여섯 번째 바위)"""
        # 미리 생성된 고정 점들을 둥근 형태로 수정
        main_points = []
        for point_x_ratio, point_y_ratio in fixed_points:
            # 둥근 모양으로 조정 (각도 완화)
            angle = math.atan2(point_y_ratio, point_x_ratio)
            radius = math.sqrt(point_x_ratio**2 + point_y_ratio**2) * size * 0.7
            point_x = x + math.cos(angle) * radius
            point_y = y + math.sin(angle) * radius * 0.8  # 세로로 약간 늘어진 타원
            main_points.append((point_x, point_y))
        
        # 3단계 레이어 (부드러운 회색 그라데이션)
        for layer in range(3):
            layer_color = colors[layer]
            scale = 1.0 - layer * 0.14
            
            layer_points = []
            for px, py in main_points:
                lx = x + (px - x) * scale
                ly = y + (py - y) * scale
                layer_points.append((lx, ly))
            
            if len(layer_points) >= 3:
                pygame.draw.polygon(surface, layer_color, layer_points)
        
        # 회색 바위 특유의 부드러운 텍스처 - 시드 기반으로 고정
        random.seed(rock_seed + 400)
        for i in range(5):
            texture_x = x + random.randint(-size//4, size//4)
            texture_y = y + random.randint(-size//4, size//4)
            texture_size = random.randint(2, 4)
            texture_color = tuple(min(255, c + random.randint(-5, 10)) for c in colors[2])
            pygame.draw.circle(surface, texture_color, (texture_x, texture_y), texture_size)
        random.seed()  # 시드 복원
    
    def draw_mixed_stone_rock(self, surface, x, y, size, colors, fixed_points, rock_seed):
        """혼합 바위 (둥근 형태)"""
        # 미리 생성된 고정 점들을 둥글게 보정
        main_points = []
        for point_x_ratio, point_y_ratio in fixed_points:
            # 둥근 모양으로 보정
            angle = math.atan2(point_y_ratio, point_x_ratio)
            radius = math.sqrt(point_x_ratio**2 + point_y_ratio**2) * size * 0.8
            point_x = x + math.cos(angle) * radius
            point_y = y + math.sin(angle) * radius * 0.85
            main_points.append((point_x, point_y))
        
        # 3단계 레이어 (혼합 색상)
        for layer in range(3):
            layer_color = colors[layer]
            scale = 1.0 - layer * 0.17
            
            layer_points = []
            for px, py in main_points:
                lx = x + (px - x) * scale
                ly = y + (py - y) * scale
                layer_points.append((lx, ly))
            
            if len(layer_points) >= 3:
                pygame.draw.polygon(surface, layer_color, layer_points)
        
        # 혼합 바위 특성 (부드러운 패턴) - 시드 기반으로 고정
        random.seed(rock_seed + 500)
        # 부드러운 음영
        for i in range(2):
            angle = random.uniform(0, 2 * math.pi)
            line_length = size * 0.25  # 길이 줄임
            start_x = x + math.cos(angle) * size * 0.15
            start_y = y + math.sin(angle) * size * 0.15
            end_x = start_x + math.cos(angle + 0.2) * line_length
            end_y = start_y + math.sin(angle + 0.2) * line_length
            edge_color = tuple(max(0, c - 15) for c in colors[1])
            pygame.draw.line(surface, edge_color, (int(start_x), int(start_y)), 
                           (int(end_x), int(end_y)), 1)
        
        # 알갱이 텍스처 제거 - 원형 grain 디자인 삭제
    
    def draw_rock_fragments(self, surface):
        """바위 파편 그리기 애니메이션"""
        for fragment in self.rock_fragments:
            # 수명에 따른 투명도
            alpha = int(255 * (fragment['life'] / 45))
            
            # 파편 색상
            color = (*fragment['color'], alpha)
            
            # 회전하는 파편 그리기
            points = []
            vertices = 5  # 5각형 파편
            for j in range(vertices):
                angle = (j / vertices * 2 * math.pi) + math.radians(fragment['rotation'])
                x = fragment['x'] + math.cos(angle) * fragment['size']
                y = fragment['y'] + math.sin(angle) * fragment['size']
                points.append((x, y))
            
            if len(points) >= 3:
                # 파편 그림자
                shadow_points = [(p[0] + 3, p[1] + 3) for p in points]
                pygame.draw.polygon(surface, (0, 0, 0, alpha // 3), shadow_points)
                # 파편 본체
                pygame.draw.polygon(surface, color[:3], points)
    
    def draw_destroyed_rock_effect(self, surface):
        """파괴된 바위 잔상 효과"""
        # 원형 이펙트 제거 - 사용자 요청
        pass
    
    def draw_rock_fragments(self, surface):
        """바위 파편 그리기 애니메이션"""
        for fragment in self.rock_fragments:
            # 수명에 따른 투명도
            alpha = int(255 * (fragment['life'] / 45))
            
            # 파편 색상
            color = (*fragment['color'], alpha)
            
            # 회전하는 파편 그리기
            points = []
            vertices = 5  # 5각형 파편
            for j in range(vertices):
                angle = (j / vertices * 2 * math.pi) + math.radians(fragment['rotation'])
                x = fragment['x'] + math.cos(angle) * fragment['size']
                y = fragment['y'] + math.sin(angle) * fragment['size']
                points.append((x, y))
            
            if len(points) >= 3:
                # 파편 그림자
                shadow_points = [(p[0] + 3, p[1] + 3) for p in points]
                pygame.draw.polygon(surface, (0, 0, 0, alpha // 3), shadow_points)
                # 파편 본체
                pygame.draw.polygon(surface, color[:3], points)
    
    def draw_destroyed_rock_effect(self, surface):
        """파괴된 바위 잔상 효과"""
        # 원형 이펙트 제거 - 사용자 요청
        pass
    
    def draw(self, screen):
        screen.blit(self.base_image, (0, 0))
        
        # 덩굴 그리기
        for vine in self.vines:
            self.draw_vine(screen, vine)
        
        # 🌿 리얼리스틱 덤불 시스템 렌더링
        for bush in self.realistic_bushes:
            self.draw_realistic_bush(screen, bush)
        
        # 돌맹이 그리기 제거 (사용자 요청)
        # for rock in self.rocks:
        #     self.draw_3d_rock(screen, rock['x'], rock['y'], rock['size'],
        #                     rock['color_base'], rock['moss_coverage'])
        
        # 눈동자 그리기
        self.eye_surface.fill((0, 0, 0, 0))
        
        # 눈 위치 (맵 중앙 악어 엠블럼)
        left_eye_x = self.center_x - 27
        right_eye_x = self.center_x + 27
        eye_y = self.center_y - 12
        
        # 눈 크기
        eye_radius = 12
        pupil_radius = 5
        
        # 눈동자 위치 계산 함수
        def calculate_pupil_position(eye_x, eye_y):
            dx = self.ball_x - eye_x
            dy = self.ball_y - eye_y
            distance = math.sqrt(dx**2 + dy**2)
            
            if distance > 0:
                # 눈동자가 움직일 수 있는 최대 거리
                max_distance = eye_radius - pupil_radius - 2
                
                # 방향 벡터 정규화
                dx_norm = dx / distance
                dy_norm = dy / distance
                
                # 눈동자 위치 계산
                pupil_offset_x = dx_norm * min(max_distance, distance * 0.05)
                pupil_offset_y = dy_norm * min(max_distance, distance * 0.05)
                
                return pupil_offset_x, pupil_offset_y
            return 0, 0
        
        # 왼쪽 눈 흰자
        pygame.draw.circle(self.eye_surface, (255, 255, 255), 
                          (left_eye_x, eye_y), eye_radius)
        pygame.draw.circle(self.eye_surface, (0, 50, 0), 
                          (left_eye_x, eye_y), eye_radius, 2)
        
        # 왼쪽 눈동자
        left_pupil_x, left_pupil_y = calculate_pupil_position(left_eye_x, eye_y)
        pygame.draw.circle(self.eye_surface, (0, 0, 0),
                          (int(left_eye_x + left_pupil_x), 
                           int(eye_y + left_pupil_y)), pupil_radius)
        # 하이라이트
        pygame.draw.circle(self.eye_surface, (255, 255, 255),
                          (int(left_eye_x + left_pupil_x - 2), 
                           int(eye_y + left_pupil_y - 2)), 2)
        
        # 오른쪽 눈 흰자
        pygame.draw.circle(self.eye_surface, (255, 255, 255), 
                          (right_eye_x, eye_y), eye_radius)
        pygame.draw.circle(self.eye_surface, (0, 50, 0), 
                          (right_eye_x, eye_y), eye_radius, 2)
        
        # 오른쪽 눈동자
        right_pupil_x, right_pupil_y = calculate_pupil_position(right_eye_x, eye_y)
        pygame.draw.circle(self.eye_surface, (0, 0, 0),
                          (int(right_eye_x + right_pupil_x), 
                           int(eye_y + right_pupil_y)), pupil_radius)
        # 하이라이트
        pygame.draw.circle(self.eye_surface, (255, 255, 255),
                          (int(right_eye_x + right_pupil_x - 2), 
                           int(eye_y + right_pupil_y - 2)), 2)
        
        # 표정 그리기
        mouth_y = self.center_y + 20
        
        if self.expression == 'happy':
            # 활짝 웃는 표정 (플레이어 패배 시)
            # 큰 웃는 입
            pygame.draw.arc(self.eye_surface, (0, 0, 0),
                           (self.center_x - 30, mouth_y - 10, 60, 40),
                           0, math.pi, 8)
            # 입 안 채우기 (빨간색)
            pygame.draw.ellipse(self.eye_surface, (200, 50, 50),
                              (self.center_x - 25, mouth_y, 50, 20))
            # 이빨 그리기
            for i in range(4):
                tooth_x = self.center_x - 15 + i * 10
                pygame.draw.rect(self.eye_surface, (255, 255, 255),
                                (tooth_x, mouth_y, 8, 10))
            
            # 눈이 웃는 모양 (초승달 모양)
            pygame.draw.arc(self.eye_surface, (0, 0, 0),
                           (left_eye_x - eye_radius, eye_y - eye_radius - 5, 
                            eye_radius * 2, eye_radius * 2),
                           0, math.pi, 3)
            pygame.draw.arc(self.eye_surface, (0, 0, 0),
                           (right_eye_x - eye_radius, eye_y - eye_radius - 5,
                            eye_radius * 2, eye_radius * 2),
                           0, math.pi, 3)
                           
        elif self.expression == 'sad':
            # 울상 표정 (플레이어 승리 시)
            # 처진 입
            pygame.draw.arc(self.eye_surface, (0, 0, 0),
                           (self.center_x - 25, mouth_y - 5, 50, 30),
                           math.pi * 0.2, math.pi * 0.8, 5)
            
            # 눈물 그리기
            for tear_x in [left_eye_x, right_eye_x]:
                tear_y = eye_y + eye_radius + 5
                # 눈물 방울
                pygame.draw.circle(self.eye_surface, (100, 150, 255),
                                 (tear_x, tear_y), 4)
                pygame.draw.circle(self.eye_surface, (150, 200, 255),
                                 (tear_x, tear_y + 8), 3)
                pygame.draw.circle(self.eye_surface, (200, 220, 255),
                                 (tear_x, tear_y + 14), 2)
            
            # 눈썹이 처진 모양
            pygame.draw.line(self.eye_surface, (0, 50, 0),
                           (left_eye_x - 15, eye_y - 20),
                           (left_eye_x + 10, eye_y - 25), 3)
            pygame.draw.line(self.eye_surface, (0, 50, 0),
                           (right_eye_x - 10, eye_y - 25),
                           (right_eye_x + 15, eye_y - 20), 3)
        else:
            # 중립 표정 - 입을 그리지 않음 (또는 매우 작은 입만)
            pass  # 입을 그리지 않음
        
        screen.blit(self.eye_surface, (0, 0))
        
        self.glow_surface.fill((0, 0, 0, 0))
        pulse = math.sin(self.time * 0.003) * 0.5 + 0.5
        
        # 악어 눈 반짝임 효과 (눈동자 위에 오버레이)
        if pulse > 0.95:  # 매우 가끔씩만 반짝임
            # 왼쪽 눈 글로우
            pygame.draw.circle(self.glow_surface,
                             (255, 255, 100, 60),
                             (left_eye_x, eye_y),
                             eye_radius + 5)
            # 오른쪽 눈 글로우
            pygame.draw.circle(self.glow_surface,
                             (255, 255, 100, 60),
                             (right_eye_x, eye_y),
                             eye_radius + 5)
        
        screen.blit(self.glow_surface, (0, 0), special_flags=pygame.BLEND_ADD)
        
        # 떨어지는 잎사귀 (디테일하게)
        self.particle_surface.fill((0, 0, 0, 0))
        for leaf in self.falling_leaves:
            # 깊이감에 따른 투명도 조절
            alpha_modifier = int(255 * leaf['z_depth'])
            
            # 새로운 디테일한 잎사귀 그리기
            self.draw_detailed_leaf(
                self.particle_surface,
                int(leaf['x']),
                int(leaf['y']),
                leaf['size'],
                leaf['type'],
                (*leaf['color'], alpha_modifier),
                leaf['rotation']
            )
        
        screen.blit(self.particle_surface, (0, 0))
        
        # 🗿 위기 상황 바위 렌더링
        for rock in self.crisis_rocks:
            self.draw_crisis_rock(screen, rock)
        
        # 💥 파편 렌더링 (원형 효과 제거)
        self.draw_rock_fragments(screen)
        
        # 🔥 보스 분노 빨간색 틴트 효과
        if self.boss_red_tint > 0:
            red_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            red_surface.fill((255, 0, 0, min(100, self.boss_red_tint // 2)))
            screen.blit(red_surface, (0, 0))
        
        # 스캔라인 효과 제거