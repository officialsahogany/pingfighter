"""
색상 관련 상수 및 유틸리티 함수 모음
점진적 리팩토링을 위한 색상 관련 코드 분리
"""

# === 기본 색상 상수 ===
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
YELLOW = (255, 255, 0)
CYAN = (0, 255, 255)
MAGENTA = (255, 0, 255)
GRAY = (128, 128, 128)
LIGHT_GRAY = (192, 192, 192)
DARK_GRAY = (64, 64, 64)

# === 추가 색상 상수 ===
ORANGE = (255, 165, 0)
PURPLE = (128, 0, 255)
PINK = (255, 192, 203)
LIME = (0, 255, 0)
DARK_BLUE = (0, 0, 139)
DARK_GREEN = (0, 100, 0)
DARK_RED = (139, 0, 0)
GOLD = (255, 215, 0)
SILVER = (192, 192, 192)
BRONZE = (205, 127, 50)

# === 스테이지별 테마 색상 ===
STAGE_COLORS = {
    1: (0, 150, 100),   # 사이버펑크 청록
    2: (0, 100, 200),   # 심해 파랑
    3: (255, 0, 128),   # 네온 핑크
    4: (255, 215, 0),   # 황금
    5: (255, 100, 0),   # 용암 주황
    6: (128, 0, 255),   # 보라
}

# === 색상 유틸리티 함수 ===
def get_stage_color(stage):
    """스테이지별 대표 색상 반환"""
    return STAGE_COLORS.get(stage, WHITE)

def fade_color(color, alpha):
    """색상에 알파값 적용 (투명도 조절)"""
    if len(color) == 3:
        return (*color, alpha)
    elif len(color) == 4:
        return (*color[:3], alpha)
    return color

def blend_colors(color1, color2, ratio):
    """두 색상을 비율에 따라 블렌딩
    
    Args:
        color1: 첫 번째 색상 (RGB 튜플)
        color2: 두 번째 색상 (RGB 튜플)
        ratio: 블렌딩 비율 (0.0 ~ 1.0)
    
    Returns:
        블렌딩된 색상 (RGB 튜플)
    """
    r1, g1, b1 = color1[:3]
    r2, g2, b2 = color2[:3]
    ratio = max(0, min(1, ratio))  # 0~1 범위로 클램핑
    
    r = int(r1 * (1 - ratio) + r2 * ratio)
    g = int(g1 * (1 - ratio) + g2 * ratio)
    b = int(b1 * (1 - ratio) + b2 * ratio)
    
    # 0~255 범위로 클램핑
    r = max(0, min(255, r))
    g = max(0, min(255, g))
    b = max(0, min(255, b))
    
    return (r, g, b)

def get_complementary_color(color):
    """보색 계산"""
    r, g, b = color[:3]
    return (255 - r, 255 - g, 255 - b)

def get_brightness(color):
    """색상의 밝기 계산 (0~255)"""
    r, g, b = color[:3]
    # ITU-R BT.709 luma 계수 사용
    return int(0.2126 * r + 0.7152 * g + 0.0722 * b)

def adjust_brightness(color, factor):
    """색상 밝기 조절
    
    Args:
        color: RGB 색상
        factor: 밝기 조절 비율 (1.0 = 원본, 0.5 = 50% 어둡게, 2.0 = 2배 밝게)
    
    Returns:
        조절된 색상
    """
    r, g, b = color[:3]
    r = int(max(0, min(255, r * factor)))
    g = int(max(0, min(255, g * factor)))
    b = int(max(0, min(255, b * factor)))
    return (r, g, b)

def get_gradient_colors(start_color, end_color, steps):
    """그라데이션 색상 리스트 생성
    
    Args:
        start_color: 시작 색상
        end_color: 끝 색상
        steps: 단계 수
    
    Returns:
        색상 리스트
    """
    colors = []
    for i in range(steps):
        ratio = i / (steps - 1) if steps > 1 else 0
        colors.append(blend_colors(start_color, end_color, ratio))
    return colors

def rgb_to_hex(color):
    """RGB 색상을 HEX 문자열로 변환"""
    r, g, b = color[:3]
    return f"#{r:02x}{g:02x}{b:02x}"

def hex_to_rgb(hex_color):
    """HEX 문자열을 RGB 튜플로 변환"""
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def get_neon_color(base_color, intensity=1.5):
    """네온 효과 색상 생성 (밝고 채도 높은 색상)"""
    r, g, b = base_color[:3]
    
    # 가장 높은 채널 찾기
    max_channel = max(r, g, b)
    if max_channel == 0:
        return base_color
    
    # 비율 유지하면서 밝기 증가
    factor = (255 / max_channel) * intensity
    factor = min(factor, 2.5)  # 최대 2.5배로 제한
    
    return adjust_brightness(base_color, factor)

def get_pastel_color(base_color, softness=0.5):
    """파스텔 톤 색상 생성 (부드럽고 연한 색상)"""
    # 흰색과 블렌딩하여 파스텔 톤 생성
    return blend_colors(base_color, WHITE, softness)

# === 색상 팔레트 ===
CYBERPUNK_PALETTE = [
    (0, 255, 255),    # 사이언
    (255, 0, 128),    # 핫 핑크
    (128, 0, 255),    # 퍼플
    (0, 255, 128),    # 민트
    (255, 128, 0),    # 오렌지
]

NEON_PALETTE = [
    get_neon_color(CYAN),
    get_neon_color(MAGENTA),
    get_neon_color(YELLOW),
    get_neon_color(GREEN),
    get_neon_color(ORANGE),
]

PASTEL_PALETTE = [
    get_pastel_color(PINK, 0.6),
    get_pastel_color(BLUE, 0.6),
    get_pastel_color(GREEN, 0.6),
    get_pastel_color(YELLOW, 0.6),
    get_pastel_color(PURPLE, 0.6),
]