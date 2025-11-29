"""
전설 아이템 획득 애니메이션 통합 모듈
게임에 전설 아이템 획득 효과를 통합하는 헬퍼 함수들
"""

import pygame
from typing import Optional, Dict, Any
from .legendary_acquisition import LegendaryAcquisitionEffect

# 싱글톤 인스턴스
_legendary_effect = None

def get_legendary_effect() -> LegendaryAcquisitionEffect:
    """전설 아이템 획득 효과 싱글톤 반환"""
    global _legendary_effect
    if _legendary_effect is None:
        _legendary_effect = LegendaryAcquisitionEffect()
    return _legendary_effect

def trigger_legendary_acquisition(item_name: str, korean_name: str, item_icon: Any = None, paddle_pos: tuple = None):
    """전설 아이템 획득 애니메이션 트리거
    
    Args:
        item_name: 아이템 영문 이름
        korean_name: 아이템 한글 이름
        item_icon: 아이템 아이콘 Surface (선택사항)
        paddle_pos: 플레이어 패들 위치 (x, y) 튜플 (선택사항)
    """
    effect = get_legendary_effect()
    effect.trigger(item_name, korean_name, item_icon, paddle_pos)
    
    # 전설 아이템 획득 사운드 재생
    try:
        import pygame
        import os
        # 절대 경로 사용
        sound_path = "/Volumes/T7/윈도우용최신/game/bosspong/sounds/legendopen.wav"
        if os.path.exists(sound_path):
            sound = pygame.mixer.Sound(sound_path)
            sound.play()
            print(f"🔊 전설 아이템 사운드 재생: legendopen.wav")
        else:
            # 상대 경로 시도
            sound_path = "sounds/legendopen.wav"
            if os.path.exists(sound_path):
                sound = pygame.mixer.Sound(sound_path)
                sound.play()
                print(f"🔊 전설 아이템 사운드 재생: legendopen.wav")
    except Exception as e:
        print(f"사운드 재생 실패: {e}")
    
    print(f"🌟 전설 아이템 획득! {korean_name}")

def update_legendary_effect(dt: float, paddle_pos: tuple = None) -> bool:
    """전설 아이템 획득 효과 업데이트
    
    Args:
        dt: 델타 타임 (밀리초)
        paddle_pos: 플레이어 패들 위치 (x, y) 튜플 (선택사항)
        
    Returns:
        애니메이션 활성 상태
    """
    effect = get_legendary_effect()
    # 패들 위치 업데이트
    if paddle_pos:
        effect.paddle_x = paddle_pos[0]
        effect.paddle_y = paddle_pos[1]
    return effect.update(dt)

def draw_legendary_effect(screen: pygame.Surface, font_large: pygame.font.Font, 
                         font_huge: Optional[pygame.font.Font] = None):
    """전설 아이템 획득 효과 그리기
    
    Args:
        screen: 게임 화면
        font_large: 큰 폰트
        font_huge: 더 큰 폰트 (선택사항)
    """
    effect = get_legendary_effect()
    effect.draw(screen, font_large, font_huge)

def should_pause_for_legendary() -> bool:
    """전설 아이템 효과로 인해 게임을 일시정지해야 하는지 확인

    Returns:
        게임 일시정지 필요 여부
    """
    # 전설 아이템 획득 효과 체크
    effect = get_legendary_effect()
    if effect.should_pause_game():
        return True

    # 천사의 가호 주사위 애니메이션 체크
    try:
        from legendary_items import get_legendary_manager
        legendary_manager = get_legendary_manager()
        if legendary_manager and "angel_blessing" in getattr(legendary_manager, "active_items", []):
            angel_blessing = legendary_manager.get_item("angel_blessing")
            if angel_blessing and getattr(angel_blessing, "roll_anim_active", False):
                return True
    except Exception:
        pass

    return False

def is_legendary_effect_active() -> bool:
    """전설 아이템 획득 효과가 활성 상태인지 확인
    
    Returns:
        효과 활성 상태
    """
    effect = get_legendary_effect()
    return effect.is_active()

def handle_legendary_space_press() -> bool:
    """전설 아이템 효과에서 스페이스바 입력 처리
    
    Returns:
        입력이 처리되었는지 여부
    """
    effect = get_legendary_effect()
    return effect.handle_space_press()

def skip_legendary_animation() -> bool:
    """전설 아이템 획득 연출을 즉시 종료 (AI 자동 플레이용)."""
    skipped = False

    # 전설 아이템 획득 효과 스킵
    effect = get_legendary_effect()
    if effect.force_skip():
        skipped = True

    # 천사의 가호 주사위 애니메이션 스킵
    try:
        from legendary_items import get_legendary_manager
        legendary_manager = get_legendary_manager()
        if legendary_manager and "angel_blessing" in getattr(legendary_manager, "active_items", []):
            angel_blessing = legendary_manager.get_item("angel_blessing")
            if angel_blessing and getattr(angel_blessing, "roll_anim_active", False):
                angel_blessing.roll_anim_active = False
                angel_blessing.waiting_for_space = False
                print("[AngelBlessing] AI 모드로 인해 애니메이션 스킵됨")
                skipped = True
    except Exception:
        pass

    return skipped

def reset_legendary_effect():
    """전설 아이템 획득 효과 리셋"""
    global _legendary_effect
    _legendary_effect = None

# 게임 통합을 위한 헬퍼 함수
def integrate_legendary_effect_to_game(game_update_func):
    """게임 업데이트 함수에 전설 아이템 효과 통합
    
    데코레이터로 사용하여 게임 업데이트 함수를 래핑
    
    Example:
        @integrate_legendary_effect_to_game
        def update_game(dt):
            # 게임 로직
            pass
    """
    def wrapper(dt, *args, **kwargs):
        # 전설 아이템 효과가 활성화되어 있고 게임을 일시정지해야 하는 경우
        if should_pause_for_legendary():
            # 전설 아이템 효과만 업데이트
            update_legendary_effect(dt)
            return
        
        # 일반 게임 업데이트
        result = game_update_func(dt, *args, **kwargs)
        
        # 전설 아이템 효과 업데이트 (일시정지가 필요 없는 마지막 단계)
        if is_legendary_effect_active():
            update_legendary_effect(dt)
            
        return result
    
    return wrapper

# 아이템 획득 시 호출할 함수
def check_and_trigger_legendary_on_pickup(item_type: str, item_data: Dict[str, Any]):
    """아이템 획득 시 전설 아이템인지 확인하고 효과 트리거
    
    Args:
        item_type: 아이템 타입/이름
        item_data: 아이템 데이터 딕셔너리
    """
    # 전설 아이템 목록 (legendary_items.py와 동기화 필요)
    legendary_items = {
        'infinity_gauntlet': '인피니티 건틀릿',
        'phoenix_feather': '불사조의 깃털',
        'chronos_clock': '크로노스의 시계',
        'excalibur_blade': '엑스칼리버',
        'ragnarok_hammer': '라그나로크 해머',
        'angel_blessing': '천사의 가호',
        '전설의벨트': '전설의 벨트'  # 특수 시너지 아이템
    }
    
    # 전설 아이템인지 확인
    if item_type in legendary_items:
        trigger_legendary_acquisition(item_type, legendary_items[item_type])
        return True
    
    # 아이템 데이터에서 rarity 확인
    if item_data.get('rarity') == 'legendary' or item_data.get('tier') == 'legendary':
        korean_name = item_data.get('korean_name', item_data.get('name', item_type))
        trigger_legendary_acquisition(item_type, korean_name)
        return True
        
    return False

# 게임 시작 시 초기화
def initialize_legendary_effects(width: int = 600, height: int = 750):
    """전설 아이템 효과 시스템 초기화
    
    Args:
        width: 화면 너비
        height: 화면 높이
    """
    global _legendary_effect
    _legendary_effect = LegendaryAcquisitionEffect(width, height)
    print("[Legendary] Item acquisition effect system initialized")
