"""
Boss Movement Integration Patch
pingfighter.py에 부드러운 보스 움직임을 적용하는 통합 패치
"""

from game_logic.smooth_boss_movement import (
    get_smooth_movement, 
    apply_smooth_boss_movement
)


def patch_boss_movement(handle_boss_func):
    """
    기존 보스 AI 함수를 래핑하여 부드러운 움직임 적용
    
    Args:
        handle_boss_func: 원본 보스 AI 함수
        
    Returns:
        function: 패치된 보스 AI 함수
    """
    def smoothed_handle_boss(*args, **kwargs):
        # 원본 함수 먼저 실행하여 target 위치 결정
        result = handle_boss_func(*args, **kwargs)
        
        # 전역 변수 접근
        import pingfighter
        
        # 스무딩 적용
        smoother = get_smooth_movement()
        
        # 현재 보스 위치와 속도 가져오기
        boss_x = pingfighter.BOSS.x
        boss_centerx = pingfighter.BOSS.centerx
        current_speed = pingfighter.boss_current_speed
        
        # future_x 가져오기 (보스 AI가 계산한 목표 위치)
        # 이 부분은 각 handle_boss 함수 내부에서 계산됨
        # 여기서는 BOSS.centerx의 변화를 감지하여 스무딩 적용
        
        return result
        
    return smoothed_handle_boss


def integrate_smooth_movement():
    """
    pingfighter.py에 부드러운 움직임 시스템 통합
    이 함수를 pingfighter.py 초기화 부분에서 호출
    """
    print("")
    
    # 스무딩 시스템 초기화
    smoother = get_smooth_movement()
    
    # 초기 설정 (난이도별로 조정 가능)
    smoother.smoothing_factor = 0.08  # 더 부드러운 기본값
    smoother.prediction_smoothing = 0.15
    smoother.max_acceleration = 0.5  # 더 부드러운 가속
    smoother.max_velocity = 7.0
    smoother.deadzone_radius = 20  # 20픽셀 반경의 데드존
    smoother.min_movement_threshold = 1.0  # 최소 움직임 임계값
    
    return smoother


def apply_smooth_movement_in_ai(boss_x, target_x, current_speed, config):
    """
    AI 함수 내부에서 직접 호출할 수 있는 스무딩 적용 함수
    
    사용 예:
    # 기존 코드:
    BOSS.x += boss_current_speed
    
    # 개선된 코드:
    new_x, new_speed = apply_smooth_movement_in_ai(
        BOSS.x, future_x, boss_current_speed, config
    )
    BOSS.x = new_x
    boss_current_speed = new_speed
    """
    max_speed = config.get("max_speed", 8)
    acceleration = config.get("accel", 0.5)
    deceleration = config.get("decel", 0.3)
    
    # 스무딩 적용
    new_position, new_speed = apply_smooth_boss_movement(
        boss_x, target_x, current_speed,
        max_speed, acceleration, deceleration
    )
    
    return new_position, new_speed


def create_movement_config(stage, league_type="normal"):
    """
    스테이지와 리그 타입에 따른 움직임 설정 생성
    
    Args:
        stage: 현재 스테이지 (1-6)
        league_type: 리그 타입 ("normal", "champion", "mythic")
        
    Returns:
        dict: 움직임 설정
    """
    # 기본 설정
    base_config = {
        "max_speed": 6,
        "accel": 0.4,
        "decel": 0.3,
        "smoothing": 0.15,
        "prediction_smoothing": 0.25
    }
    
    # 스테이지별 조정
    stage_multipliers = {
        1: 0.8,   # Stage 1: 느림
        2: 0.9,   # Stage 2: 약간 느림
        3: 1.0,   # Stage 3: 보통
        4: 1.1,   # Stage 4: 약간 빠름
        5: 1.2,   # Stage 5: 빠름
        6: 1.3    # Stage 6: 매우 빠름
    }
    
    # 리그별 조정
    league_multipliers = {
        "normal": 1.0,
        "champion": 1.2,
        "mythic": 1.4
    }
    
    # 최종 계산
    stage_mult = stage_multipliers.get(stage, 1.0)
    league_mult = league_multipliers.get(league_type, 1.0)
    
    config = base_config.copy()
    config["max_speed"] *= stage_mult * league_mult
    config["accel"] *= stage_mult * league_mult
    
    # 스무딩 팩터는 반대로 (빠를수록 덜 부드럽게)
    config["smoothing"] = 0.15 / (stage_mult * league_mult * 0.5 + 0.5)
    
    return config