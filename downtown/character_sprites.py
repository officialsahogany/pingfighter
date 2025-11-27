# downtown/character_sprites.py
# 번화가 캐릭터 스프라이트 시스템
# 선택한 캐릭터(스매셔, 코만도, 발토르)의 이미지를 로드하고 관리
# 메인 게임(pingfighter.py)의 캐릭터 생성 함수를 활용

import pygame
import os
import sys

def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)


# =============================================================================
# 캐릭터 스프라이트 설정
# =============================================================================

# 캐릭터 타입별 이미지 파일 매핑 (PNG 폴백용)
CHARACTER_SPRITE_FILES = {
    "smasher": None,                          # 코드로 생성
    "soldier": None,                          # 코드로 생성
    "blacksmith": "blacksmith_base.png",      # 발토르 (PNG 파일)
    "optimus": None,                          # 옵티머스 (코드로 생성)
    "normal": None,                           # 스매셔와 동일 (코드로 생성)
}

# 번화가에서의 캐릭터 크기 (픽셀)
# pingfighter 게임 화면(600x750)에서 잘 보이도록 크게 설정
# 225에서 15% 감소: 225 → 191
DOWNTOWN_CHARACTER_SIZE = 191

# 스프라이트 캐시 (로드된 이미지 저장)
_sprite_cache = {}

# 메인 게임 캐릭터 생성 함수 참조
_pingfighter_module = None


def _get_pingfighter_module():
    """pingfighter 모듈 동적 로드 (순환 참조 방지)"""
    global _pingfighter_module
    if _pingfighter_module is None:
        try:
            import pingfighter
            _pingfighter_module = pingfighter
        except ImportError:
            _pingfighter_module = False  # 로드 실패 표시
    return _pingfighter_module if _pingfighter_module else None


# =============================================================================
# 캐릭터 스프라이트 로드 함수
# =============================================================================

def load_character_sprite(character_type):
    """
    캐릭터 타입에 맞는 스프라이트 로드
    스매셔/코만도는 pingfighter의 create 함수 사용, 발토르는 PNG 파일

    Args:
        character_type: 'smasher', 'soldier', 'blacksmith', 'normal'

    Returns:
        pygame.Surface: 로드된 캐릭터 스프라이트 (크기 조정됨)
    """
    # 캐시에 있으면 반환
    if character_type in _sprite_cache:
        return _sprite_cache[character_type]

    # 유효한 캐릭터 타입인지 확인
    if character_type not in CHARACTER_SPRITE_FILES:
        character_type = "normal"

    sprite = None

    # 스매셔/코만도/옵티머스는 pingfighter의 캐릭터 생성 함수 사용
    if character_type in ("smasher", "normal"):
        sprite = _create_smasher_sprite()
    elif character_type == "soldier":
        sprite = _create_soldier_sprite()
    elif character_type == "blacksmith":
        sprite = _load_blacksmith_sprite()
    elif character_type == "optimus":
        sprite = _create_optimus_sprite()

    # 실패 시 폴백
    if sprite is None:
        sprite = _create_fallback_sprite(character_type)

    # 캐시에 저장
    _sprite_cache[character_type] = sprite
    return sprite


def _create_smasher_sprite():
    """스매셔 스프라이트 생성 (pingfighter의 create_smasher_paddle_surface 활용)"""
    pf = _get_pingfighter_module()
    if pf and hasattr(pf, 'create_smasher_paddle_surface'):
        try:
            original = pf.create_smasher_paddle_surface(0.0)
            return _scale_sprite(original)
        except Exception as e:
            print(f"스매셔 스프라이트 생성 실패: {e}")
    return None


def _create_soldier_sprite():
    """코만도 스프라이트 생성 (pingfighter의 create_soldier_paddle_surface 활용)"""
    pf = _get_pingfighter_module()
    if pf and hasattr(pf, 'create_soldier_paddle_surface'):
        try:
            original = pf.create_soldier_paddle_surface()
            return _scale_sprite(original)
        except Exception as e:
            print(f"코만도 스프라이트 생성 실패: {e}")
    return None


def _create_optimus_sprite():
    """옵티머스 스프라이트 생성 (pingfighter의 create_optimus_paddle_surface 활용)"""
    pf = _get_pingfighter_module()
    if pf and hasattr(pf, 'create_optimus_paddle_surface'):
        try:
            original = pf.create_optimus_paddle_surface(0.0)
            return _scale_sprite(original)
        except Exception as e:
            print(f"옵티머스 스프라이트 생성 실패: {e}")
    return None


def _load_blacksmith_sprite():
    """발토르 스프라이트 로드 (PNG 파일)"""
    sprite_file = CHARACTER_SPRITE_FILES["blacksmith"]
    if sprite_file is None:
        return None

    sprite_path = resource_path(sprite_file)

    try:
        original = pygame.image.load(sprite_path)
        try:
            original = original.convert_alpha()
        except pygame.error:
            pass
        return _scale_sprite(original)
    except Exception as e:
        print(f"발토르 스프라이트 로드 실패: {e}")
    return None


def _scale_sprite(original):
    """스프라이트 크기 조정 (비율 유지)"""
    if original is None:
        return None

    orig_w, orig_h = original.get_size()

    # 비율 유지하면서 크기 조정
    scale = DOWNTOWN_CHARACTER_SIZE / max(orig_w, orig_h)
    new_w = int(orig_w * scale)
    new_h = int(orig_h * scale)

    # 크기 조정
    sprite = pygame.transform.smoothscale(original, (new_w, new_h))
    return sprite


def _create_fallback_sprite(character_type):
    """
    이미지 로드 실패 시 폴백 스프라이트 생성
    캐릭터 타입에 따라 다른 색상 적용
    """
    # 캐릭터별 색상 (메인 게임 테마에 맞춤)
    colors = {
        "smasher": (70, 102, 162),        # 파란색 메카 (스매셔)
        "soldier": (60, 80, 50),           # 밀리터리 그린 (코만도)
        "blacksmith": (139, 90, 43),       # 갈색 (대장장이 발토르)
        "optimus": (255, 165, 0),          # 오렌지색 (옵티머스)
        "normal": (70, 102, 162),          # 파란색 (스매셔와 동일)
    }

    color = colors.get(character_type, (0, 255, 255))

    # 폴백 스프라이트 생성
    size = DOWNTOWN_CHARACTER_SIZE
    sprite = pygame.Surface((size, size), pygame.SRCALPHA)

    # 몸통
    body_rect = pygame.Rect(size//4, size//3, size//2, size//2)
    pygame.draw.ellipse(sprite, color, body_rect)
    pygame.draw.ellipse(sprite, (255, 255, 255), body_rect, 2)

    # 머리
    head_rect = pygame.Rect(size//4, size//8, size//2, size//3)
    pygame.draw.ellipse(sprite, (255, 220, 180), head_rect)
    pygame.draw.ellipse(sprite, (200, 180, 150), head_rect, 1)

    # 눈
    pygame.draw.circle(sprite, (40, 40, 40), (size//3, size//4), 3)
    pygame.draw.circle(sprite, (40, 40, 40), (size*2//3, size//4), 3)

    return sprite


def get_directional_sprite(sprite, direction):
    """
    방향에 따른 스프라이트 변환

    Args:
        sprite: 원본 스프라이트
        direction: 0=하, 1=좌, 2=우, 3=상

    Returns:
        변환된 스프라이트
    """
    if sprite is None:
        return None

    if direction == 1:  # 왼쪽 - 좌우 반전
        return pygame.transform.flip(sprite, True, False)
    elif direction == 2:  # 오른쪽 - 원본 (기본 방향)
        return sprite
    elif direction == 3:  # 위 - 원본 유지 (뒷모습은 별도 처리 필요시 추가)
        return sprite
    else:  # 아래 (기본)
        return sprite


def clear_sprite_cache():
    """스프라이트 캐시 초기화"""
    _sprite_cache.clear()


# =============================================================================
# 캐릭터 정보 유틸리티
# =============================================================================

def get_character_display_name(character_type):
    """캐릭터 표시 이름 반환"""
    names = {
        "smasher": "스매셔",
        "soldier": "코만도",
        "blacksmith": "발토르",
        "optimus": "옵티머스",
        "normal": "플레이어",
    }
    return names.get(character_type, "플레이어")


def get_available_characters():
    """사용 가능한 캐릭터 목록 반환"""
    return list(CHARACTER_SPRITE_FILES.keys())
