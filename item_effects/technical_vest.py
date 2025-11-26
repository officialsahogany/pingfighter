"""
테크니컬조끼 아이템 효과
플레이어 패들에 공이 닿았을 때 10~20% 확률로 3~6초간 연막 생성
연막은 플레이어 패들을 따라다니며 최소 3초 이상 분사 후 페이드아웃
"""

import os
import pygame
import random
import math

class TechnicalVest:
    def __init__(self):
        self.active = False
        self.smoke_instances = []  # 활성 연막 인스턴스들
        self.trigger_chance = 0.15  # 15% 확률 (롤 옵션으로 덮어씀)
        self.smoke_duration_frames = 300  # 5초 (롤 옵션으로 덮어씀)
        self.emission_duration_frames = 180  # 3초 연막 분사
        self.player_paddle_rect = None  # 플레이어 패들 위치 추적용
        self.duration = 3600  # 60초 (60 FPS)
        self.timer = 0  # 활성화 시간 추적
        self.debug = os.environ.get("DEBUG_TECH_VEST", "0") == "1"
        
    def activate(self, game_state, current_stage):
        """테크니컬조끼 아이템 활성화"""
        self.active = True
        self.timer = 0  # 타이머 리셋
        
    def deactivate(self):
        """테크니컬조끼 비활성화"""
        self.active = False
        self.smoke_instances.clear()
        
    def on_ball_paddle_collision(self, player_paddle_rect):
        """플레이어 패들에 공이 닿았을 때 호출"""
        if not self.active:
            return
            
        # 20% 확률(롤 옵션 반영)로 연막 생성
        if random.random() < self.trigger_chance:
            # 플레이어 패들 위치에 연막 생성
            smoke = {
                'start_x': player_paddle_rect.centerx,
                'start_y': player_paddle_rect.centery,
                'radius': 0,
                'max_radius': 120,  # 최대 반경
                'duration': self.smoke_duration_frames,  # 롤 옵션 적용
                'emission_duration': self.emission_duration_frames,  # 3초간 분사
                'timer': 0,
                'particles': [],
                'trail_particles': []  # 패들 이동 경로에 남는 파티클
            }
            
            self.smoke_instances.append(smoke)
            if self.debug:
                print(f"[TECH_VEST] smoke spawned chance={self.trigger_chance*100:.1f}% duration={self.smoke_duration_frames/60:.1f}s emission={self.emission_duration_frames/60:.1f}s")
            
    def update(self, player_paddle_rect=None):
        """연막 상태 업데이트"""
        if not self.active:
            return
        
        # 타이머 증가 및 지속시간 체크
        self.timer += 1
        if self.timer >= self.duration:
            self.deactivate()
            return
        
        # 플레이어 패들 위치 업데이트
        if player_paddle_rect:
            self.player_paddle_rect = player_paddle_rect
            
        # 각 연막 인스턴스 업데이트
        for smoke in self.smoke_instances[:]:
            smoke['timer'] += 1
            
            # 3초간 연막 분사 (패들 따라다니며)
            if smoke['timer'] <= smoke['emission_duration'] and self.player_paddle_rect:
                # 2프레임마다 새로운 파티클 생성
                if smoke['timer'] % 2 == 0:
                    for _ in range(5):  # 파티클 수 증가
                        particle = {
                            'x': self.player_paddle_rect.centerx + random.randint(-15, 15),
                            'y': self.player_paddle_rect.centery + random.randint(-10, 10),
                            'vx': random.uniform(-2.5, 2.5),  # 더 넓게 퍼짐
                            'vy': random.uniform(-3.0, -0.5),  # 더 강하게 위로 올라감
                            'size': random.randint(15, 30),  # 초기 크기
                            'max_size': random.randint(40, 60),  # 최대 크기
                            'alpha': random.randint(140, 200),
                            'initial_alpha': random.randint(140, 200),  # 초기 알파값 저장
                            'birth_time': smoke['timer'],
                            'creation_order': len(smoke['trail_particles']),  # 생성 순서 저장
                            'lifetime': 60  # 1초로 단축
                        }
                        smoke['trail_particles'].append(particle)
            
            # 연막 반경 확장 (첫 1초)
            if smoke['timer'] < 60:
                smoke['radius'] = smoke['max_radius'] * (smoke['timer'] / 60)
            else:
                smoke['radius'] = smoke['max_radius']
            
            # 모든 파티클 업데이트
            if len(smoke['trail_particles']) > 0:
                for i, particle in enumerate(smoke['trail_particles'][:]):
                    particle['x'] += particle['vx']
                    particle['y'] += particle['vy']
                    
                    # 파티클 수명 계산
                    particle_age = smoke['timer'] - particle['birth_time']
                    
                    # 속도 감속 및 확산 효과
                    particle['vx'] *= 0.98  # 수평 감속
                    particle['vy'] *= 0.95  # 수직 감속 (위로 계속 올라가도록)
                    particle['vy'] -= 0.05  # 약간의 부력 효과
                    
                    # 크기 확장 (더 빠르게)
                    if particle_age < 30:  # 처음 0.5초간 확장
                        size_progress = particle_age / 30
                        particle['size'] = particle['size'] + (particle['max_size'] - particle['size']) * 0.05
                    else:
                        particle['size'] = particle['max_size']
                    
                    # 모든 파티클이 생성 후 즉시 페이드아웃 시작
                    # 연막 발동 내내 일정한 빠른 사라짐 효과
                    particle_fade_start = 9  # 0.15초 후 페이드 시작
                    
                    if particle_age > particle_fade_start:
                        # 더 빠른 속도로 자연스럽게 페이드아웃
                        fade_duration = 30  # 0.5초간 매우 빠르게 페이드아웃
                        fade_progress = min(1.0, (particle_age - particle_fade_start) / fade_duration)
                        
                        # 선형 페이드아웃으로 일정한 속도 유지
                        # 또는 약간의 ease-out만 적용하여 자연스럽게
                        ease_progress = 1 - (1 - fade_progress) * (1 - fade_progress)  # ease-out quadratic
                        
                        fade_factor = 1 - ease_progress
                        particle['alpha'] = max(0, particle['initial_alpha'] * fade_factor)
                    
                    # 개별 파티클이 완전히 투명해지면 제거
                    if particle['alpha'] <= 0 or particle_age >= particle['lifetime']:
                        smoke['trail_particles'].remove(particle)
                    
            # 시간이 다 되면 제거
            if smoke['timer'] >= smoke['duration'] and len(smoke['trail_particles']) == 0:
                self.smoke_instances.remove(smoke)
                
    def draw_effects(self, screen, **kwargs):
        """연막 효과 그리기"""
        if not self.active or not self.smoke_instances:
            return
            
        for smoke in self.smoke_instances:
            # 트레일 파티클 그리기 (먼저 생성된 것부터 그려서 레이어링 효과)
            # 오래된 파티클일수록 뒤에 그려져서 새 파티클이 위에 오도록
            for particle in smoke['trail_particles']:
                if particle['alpha'] > 0:
                    # 연막 색상 (회색 계열에 약간의 파란색)
                    size = int(particle['size'])
                    smoke_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                    alpha = min(255, int(particle['alpha']))
                    
                    # 파티클 나이에 따른 색상 변화
                    particle_age = smoke['timer'] - particle['birth_time']
                    
                    # 그라데이션 효과를 위한 여러 겹 그리기
                    for i in range(3):
                        layer_size = size - i * (size // 4)
                        if layer_size > 0:
                            # 레이어별 알파값 조정
                            layer_alpha = alpha * (1 - i * 0.3)
                            
                            # 페이드아웃 중인 파티클은 더 밝고 투명하게
                            if particle['alpha'] < particle['initial_alpha']:
                                fade_ratio = particle['alpha'] / particle['initial_alpha']
                                # 사라지는 파티클은 점진적으로 밝아지고 투명해짐
                                # 부드러운 색상 전환
                                base_gray = int(140 + i * 10 + (1 - fade_ratio) * 80)
                                base_blue = int(160 + i * 5 + (1 - fade_ratio) * 60)
                                # 알파값도 더 부드럽게 조정
                                layer_alpha = layer_alpha * fade_ratio
                            else:
                                # 정상 파티클
                                base_gray = 140 + i * 10
                                base_blue = 160 + i * 5
                            
                            color = (min(255, base_gray), 
                                   min(255, base_gray), 
                                   min(255, base_blue), 
                                   int(layer_alpha))
                            pygame.draw.circle(smoke_surf, color, 
                                             (size, size), layer_size)
                    
                    screen.blit(smoke_surf, (particle['x'] - size, 
                                           particle['y'] - size))
                    
    def check_smoke_collision(self, x, y):
        """특정 위치가 연막 안에 있는지 확인"""
        if not self.active:
            return False
            
        for smoke in self.smoke_instances:
            # 연막 파티클들과의 충돌 체크
            for particle in smoke['trail_particles']:
                if particle['alpha'] > 30:  # 어느 정도 보이는 파티클만 체크
                    distance = math.sqrt((x - particle['x'])**2 + (y - particle['y'])**2)
                    if distance <= particle.get('size', 30):  # 현재 크기 사용
                        return True
        return False
        
    def get_smoke_areas(self):
        """현재 활성 연막 영역들 반환 (Stage 4 몽크 상호작용용)"""
        if not self.active:
            return []
            
        areas = []
        for smoke in self.smoke_instances:
            # 플레이어 패들 주변 영역 반환
            if self.player_paddle_rect and smoke['timer'] <= smoke['emission_duration']:
                areas.append({
                    'x': self.player_paddle_rect.centerx,
                    'y': self.player_paddle_rect.centery,
                    'radius': smoke['radius']
                })
        return areas

    def get_remaining_time(self):
        """남은 연막 지속 시간을 초 단위로 반환 (가장 오래 남은 인스턴스 기준)."""
        if not self.active or not self.smoke_instances:
            return 0.0
        remaining_frames = max(
            max(0, smoke.get('duration', 0) - smoke.get('timer', 0))
            for smoke in self.smoke_instances
        )
        return remaining_frames / 60.0

# 싱글톤 인스턴스
technical_vest_instance = None

def get_technical_vest_instance():
    global technical_vest_instance
    if technical_vest_instance is None:
        technical_vest_instance = TechnicalVest()
    return technical_vest_instance

def activate_technical_vest(game_state, current_stage):
    """테크니컬조끼 활성화"""
    vest = get_technical_vest_instance()
    vest.activate(game_state, current_stage)
    if vest.debug:
        print(f"[TECH_VEST] activate chance={vest.trigger_chance*100:.1f}% duration={vest.smoke_duration_frames/60:.1f}s emission={vest.emission_duration_frames/60:.1f}s")

def deactivate_technical_vest():
    """테크니컬조끼 비활성화"""
    vest = get_technical_vest_instance()
    vest.deactivate()

def on_ball_paddle_collision_technical_vest(player_paddle_rect):
    """플레이어 패들과 공 충돌 시 호출"""
    vest = get_technical_vest_instance()
    vest.on_ball_paddle_collision(player_paddle_rect)
    
def update_technical_vest(player_paddle_rect=None):
    """테크니컬조끼 업데이트"""
    vest = get_technical_vest_instance()
    vest.update(player_paddle_rect)

def draw_technical_vest_effects(screen, **kwargs):
    """테크니컬조끼 효과 그리기"""
    vest = get_technical_vest_instance()
    vest.draw_effects(screen, **kwargs)

def check_technical_vest_smoke_collision(x, y):
    """연막 충돌 체크"""
    vest = get_technical_vest_instance()
    return vest.check_smoke_collision(x, y)

def get_technical_vest_smoke_areas():
    """연막 영역 정보 반환"""
    vest = get_technical_vest_instance()
    return vest.get_smoke_areas()


def get_technical_vest_remaining_time():
    """연막이 활성화되어 있다면 남은 시간을 초 단위로 반환."""
    vest = get_technical_vest_instance()
    return vest.get_remaining_time()


def configure_technical_vest(chance_pct=None, duration_sec=None, emission_sec=None):
    """
    롤 옵션/밸런스 값을 테크니컬조끼 인스턴스에 반영.
    Args:
        chance_pct: 연막 생성 확률(%) – 0~100
        duration_sec: 연막 지속 시간(초)
        emission_sec: 연막 분사 시간(초) – 지정 시 덮어씀
    """
    vest = get_technical_vest_instance()
    if chance_pct is not None:
        vest.trigger_chance = max(0.0, min(1.0, chance_pct / 100.0))
    if duration_sec is not None:
        vest.smoke_duration_frames = max(1, int(duration_sec * 60))
        # 시인성 확보를 위해 분사 시간도 전체 지속 시간으로 확장
        vest.emission_duration_frames = vest.smoke_duration_frames
    if emission_sec is not None:
        vest.emission_duration_frames = max(1, int(emission_sec * 60))
    if vest.debug:
        print(f"[TECH_VEST] configure chance={vest.trigger_chance*100:.1f}% duration={vest.smoke_duration_frames/60:.1f}s emission={vest.emission_duration_frames/60:.1f}s")
