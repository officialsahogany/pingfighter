"""
물리 시스템 관리자 (Physics Manager)
- 공 물리 처리
- 서브 로직
- 충돌 감지
"""

import pygame
import random
import math

# 전역 변수들
_screen = None
_ball = None
_player = None
_boss = None
_width = 0
_height = 0

def init_physics_manager(screen, ball, player, boss, width, height):
    """물리 매니저 초기화"""
    global _screen, _ball, _player, _boss, _width, _height
    _screen = screen
    _ball = ball
    _player = player
    _boss = boss
    _width = width
    _height = height
    print("")

def reset_ball(is_player_serve=True):
    """공 위치 리셋 - 서버에 따라 위치 설정"""
    global _ball, _width, _height, _player, _boss
    if _ball is None:
        return
    
    # 서버에 따라 공 위치 설정
    _ball.centerx = _width // 2
    
    if is_player_serve:
        # 플레이어 서브: 플레이어 패들 근처
        _ball.centery = _height - 80  # 플레이어 패들 위쪽
    else:
        # 보스 서브: 보스 패들 근처  
        _ball.centery = 80  # 보스 패들 아래쪽
    
    print(f"   : ({_ball.centerx}, {_ball.centery}) - {'' if is_player_serve else ''}")

def serve_ball(is_player_serve=True, current_stage=1):
    """공 서브"""
    # 기본 서브 속도와 방향 설정
    base_speed = 9
    
    # 튜토리얼 스테이지(50)는 적절한 속도 사용 (slow_ball_timer 회피)
    if current_stage == 50:
        base_speed = 8  # 튜토리얼용 적절한 속도 (임계값 7.65 이상, 기본 속도 9 이하)
        if is_player_serve:
            # 플레이어 서브: 위로
            ball_vel = [random.choice([-2, 2]), -base_speed]
        else:
            # 보스 서브: 아래로
            ball_vel = [random.choice([-2, 2]), base_speed]
        
        # 튜토리얼 서브 디버깅
        import math
        actual_speed = math.hypot(ball_vel[0], ball_vel[1])
        print(f"🎓 튜토리얼 서브: ball_vel={ball_vel}, 실제속도={actual_speed:.2f}, 임계값={9*0.85:.2f}")
    else:
        if is_player_serve:
            # 플레이어 서브: 위로
            ball_vel = [random.choice([-3, 3]), -base_speed]
        else:
            # 보스 서브: 아래로
            ball_vel = [random.choice([-3, 3]), base_speed]
        
        # 스테이지별 속도 조정 (튜토리얼 제외) - 안전한 상한 적용
        stage_multiplier = 1.0 + min((current_stage - 1) * 0.03, 0.5)  # 최대 1.5배까지만
        ball_vel[0] *= stage_multiplier
        ball_vel[1] *= stage_multiplier
        
        # 서브 속도 안전 상한 적용
        import math
        current_speed = math.hypot(ball_vel[0], ball_vel[1])
        max_serve_speed = base_speed * 1.6  # 기본 속도의 1.6배까지만 허용
        if current_speed > max_serve_speed:
            scale = max_serve_speed / current_speed
            ball_vel[0] *= scale
            ball_vel[1] *= scale
            print(f"⚠️ 서브 속도 제한 적용: {current_speed:.2f} → {max_serve_speed:.2f}")
    
    # 볼 임팩트 부스트 (기본값)
    ball_impact_boost = 1.0
    
    print(f"  :  {ball_vel},  : {is_player_serve}")
    
    return {
        'ball_vel': ball_vel,
        'ball_impact_boost': ball_impact_boost,
        'is_waiting_for_serve': False,  # 서브 완료 후에는 대기 상태 해제
        'fireball_last_cast': None      # 홍련탄 관련 (기본값)
    }
