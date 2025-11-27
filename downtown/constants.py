# downtown/constants.py
# 번화가 시스템 상수 정의

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
# 화면 설정 (pingfighter 게임과 동일하게 맞춤)
# =============================================================================
SCREEN_WIDTH = 600
SCREEN_HEIGHT = 750
TILE_SIZE = 40  # 타일 크기 (픽셀) - 세로형 맵에 맞게 조정

# =============================================================================
# 맵 설정 (세로형 - 위에서 아래로 탐험하며 스크롤)
# =============================================================================
MAP_WIDTH = 15   # 타일 개수 (가로) - 600 / 40 = 15
MAP_HEIGHT = 50  # 타일 개수 (세로) - 긴 탐험형 맵 (50 * 40 = 2000px)
MAP_PIXEL_WIDTH = MAP_WIDTH * TILE_SIZE   # 600
MAP_PIXEL_HEIGHT = MAP_HEIGHT * TILE_SIZE # 2000

# =============================================================================
# 타일 타입
# =============================================================================
class TileType:
    EMPTY = 0           # 빈 공간 (이동 불가)
    GROUND = 1          # 일반 바닥 (이동 가능)
    ROAD = 2            # 도로 (이동 가능, 빠른 이동)
    BUILDING = 3        # 건물 (픽셀 충돌로 판단)
    DECORATION = 4      # 장식물 (이동 가능 - 꽃밭, 화단 등)
    SPAWN = 5           # 플레이어 스폰 지점
    EXIT = 6            # 출구 (다음 스테이지로)
    WATER = 7           # 물 (이동 불가)
    BRIDGE = 8          # 다리 (이동 가능)

# =============================================================================
# 건물 타입
# =============================================================================
class BuildingType:
    CASINO = "casino"               # 도박장
    COLOSSEUM = "colosseum"         # 콜로세움
    BLACKSMITH = "blacksmith"       # 대장장이
    MAGIC_STORE = "magic_store"     # 마법 성소
    PET_SHOP = "pet_shop"           # 펫 상점
    ELDER = "elder"                 # 버프 노인
    MINIGAME = "minigame"           # 미니게임
    TAVERN = "tavern"               # 주점 (정보 수집)
    BANK = "bank"                   # 은행 (재화 저장)
    MYSTERY = "mystery"             # 미스터리 이벤트
    GACHA = "gacha"                 # 가챠샵
    ACADEMY = "academy"             # 스킬 학원

# 건물 정보 (각 건물별 고유 디자인 및 크기 - 세로형 화면에 맞게 축소)
BUILDING_INFO = {
    BuildingType.CASINO: {
        "name": "네온 카지노",
        "name_en": "Neon Casino",
        "icon": "🎰",
        "color": (255, 20, 147),     # 네온 핑크
        "ap_cost": 1,
        "size": (3, 2),              # 넓고 낮은 사이버펑크 스타일
        "pixel_size": (110, 75),     # 픽셀 단위 크기 (축소)
        "description": "화려한 네온 불빛 아래서 행운을 시험하세요",
        "rarity": 0.8,
        "style": "cyberpunk",
    },
    BuildingType.COLOSSEUM: {
        "name": "고대 투기장",
        "name_en": "Ancient Colosseum",
        "icon": "⚔️",
        "color": (180, 160, 140),    # 대리석/돌
        "ap_cost": 2,
        "size": (3, 3),              # 크고 웅장한 고대 신전
        "pixel_size": (120, 110),    # (축소)
        "description": "영웅들이 격돌하는 웅장한 투기장",
        "rarity": 0.5,
        "style": "ancient_rome",
    },
    BuildingType.BLACKSMITH: {
        "name": "용광로 대장간",
        "name_en": "Volcanic Forge",
        "icon": "🔨",
        "color": (255, 100, 50),     # 용암/불
        "ap_cost": 1,
        "size": (2, 2),              # 굴뚝이 있는 정사각형
        "pixel_size": (80, 95),      # 세로로 굴뚝 포함 (축소)
        "description": "불타는 용광로에서 무기를 단련하세요",
        "rarity": 0.9,
        "style": "volcanic",
    },
    BuildingType.MAGIC_STORE: {
        "name": "마법 성소",
        "name_en": "Mystic Sanctuary",
        "icon": "🌙",
        "color": (120, 80, 200),     # 깊은 보라
        "ap_cost": 1,
        "size": (2, 2),              # 신비한 마법 성소
        "pixel_size": (75, 88),      # (축소)
        "description": "달의 힘이 깃든 신비로운 마법 성소",
        "rarity": 1.0,
        "style": "sanctuary",
    },
    BuildingType.PET_SHOP: {
        "name": "숲의 펫샵",
        "name_en": "Forest Pet Haven",
        "icon": "🐾",
        "color": (100, 180, 80),     # 자연 녹색
        "ap_cost": 1,
        "size": (2, 2),              # 자연친화적 목조 건물
        "pixel_size": (75, 70),      # (축소)
        "description": "모험을 함께할 신비로운 동반자를 만나세요",
        "rarity": 0.6,
        "style": "nature",
    },
    BuildingType.ELDER: {
        "name": "피라미드 현자",
        "name_en": "Pyramid Oracle",
        "icon": "👁️",
        "color": (255, 215, 0),      # 이집트 금
        "ap_cost": 1,
        "size": (2, 2),              # 피라미드 형태
        "pixel_size": (85, 80),      # (축소)
        "description": "고대의 지혜가 담긴 신비로운 피라미드",
        "rarity": 0.7,
        "style": "egyptian",
    },
    BuildingType.MINIGAME: {
        "name": "레트로 아케이드",
        "name_en": "Retro Arcade",
        "icon": "🎮",
        "color": (57, 255, 20),      # 네온 그린
        "ap_cost": 1,
        "size": (2, 2),              # 네온 빛나는 게임장
        "pixel_size": (80, 75),      # (축소)
        "description": "추억의 레트로 게임을 즐겨보세요",
        "rarity": 0.8,
        "style": "retro_cyber",
    },
    BuildingType.TAVERN: {
        "name": "모험가의 선술집",
        "name_en": "Adventurer's Tavern",
        "icon": "🍺",
        "color": (210, 150, 100),    # 따뜻한 나무색
        "ap_cost": 1,
        "size": (2, 2),              # 2층 목조 건물
        "pixel_size": (95, 88),      # (축소)
        "description": "모험가들이 모이는 따뜻한 선술집",
        "rarity": 0.7,
        "style": "medieval",
    },
    BuildingType.BANK: {
        "name": "스타뱅크",
        "name_en": "StarBank",
        "icon": "⭐",
        "color": (255, 215, 0),      # 황금색
        "ap_cost": 0,
        "size": (2, 2),              # 별빛 환전소
        "pixel_size": (85, 80),      # (축소)
        "description": "환전,예금 등 은행업무를 합니다",
        "rarity": 0.5,
        "style": "star_luxury",
    },
    BuildingType.MYSTERY: {
        "name": "???",
        "name_en": "Void Portal",
        "icon": "❓",
        "color": (100, 0, 150),      # 보이드 퍼플
        "ap_cost": 1,
        "size": (2, 2),              # 차원의 틈
        "pixel_size": (65, 65),      # (축소)
        "description": "차원의 틈에서 무엇이 기다릴까요?",
        "rarity": 0.3,
        "style": "void",
    },
    BuildingType.GACHA: {
        "name": "스타 가챠샵",
        "name_en": "Star Gacha Shop",
        "icon": "🌟",
        "color": (255, 200, 50),     # 반짝이는 금색
        "ap_cost": 1,
        "size": (2, 2),              # 화려한 가챠 머신
        "pixel_size": (85, 90),      # (축소)
        "description": "가챠로 희귀 아이템을 뽑아보세요!",
        "rarity": 0.85,
        "style": "gacha",
    },
    BuildingType.ACADEMY: {
        "name": "대학교",
        "name_en": "Magic Academy",
        "icon": "📚",
        "color": (150, 100, 255),    # 마법의 보라색
        "ap_cost": 1,
        "size": (3, 2),              # 3개의 탑이 있는 넓은 성
        "pixel_size": (110, 95),     # 3개 탑 포함 크기
        "description": "스킬을 배울 수 있는 학교",
        "rarity": 0.9,
        "style": "magic_school",
    },
}

# =============================================================================
# 행동 포인트 설정
# =============================================================================
BASE_ACTION_POINTS = 4          # 기본 AP
MAX_ACTION_POINTS = 10          # 최대 AP
AP_PER_STAGE_CLEAR = 1          # 스테이지 클리어 시 추가 AP

# =============================================================================
# 플레이어 설정 (600x750 세로형 화면에 맞춤)
# =============================================================================
PLAYER_SPEED = 4                # 이동 속도 (작은 화면에 맞게 조정)
PLAYER_SIZE = 191               # 플레이어 크기 (225에서 15% 감소)
PLAYER_ANIMATION_SPEED = 0.15   # 애니메이션 속도

# =============================================================================
# 색상 팔레트 (사이버펑크/우주 테마)
# =============================================================================
class Colors:
    # 배경
    BG_DARK = (15, 15, 35)
    BG_SPACE = (10, 10, 30)

    # 네온 색상
    NEON_PINK = (255, 20, 147)
    NEON_CYAN = (0, 255, 255)
    NEON_PURPLE = (138, 43, 226)
    NEON_GREEN = (57, 255, 20)
    NEON_ORANGE = (255, 165, 0)
    NEON_YELLOW = (255, 255, 0)

    # UI 색상
    UI_PRIMARY = (100, 149, 237)
    UI_SECONDARY = (70, 130, 180)
    UI_ACCENT = (255, 215, 0)
    UI_DANGER = (255, 69, 0)
    UI_SUCCESS = (50, 205, 50)

    # 타일 색상
    TILE_GROUND = (40, 40, 60)
    TILE_ROAD = (60, 60, 80)
    TILE_WATER = (30, 60, 100)

    # 텍스트
    TEXT_WHITE = (255, 255, 255)
    TEXT_GRAY = (180, 180, 180)
    TEXT_GOLD = (255, 215, 0)

# =============================================================================
# 행성 테마
# =============================================================================
class PlanetTheme:
    CYBER_CITY = "cyber_city"       # 사이버펑크 도시
    DESERT_TOWN = "desert_town"     # 사막 마을
    FOREST_VILLAGE = "forest_village"  # 숲속 마을
    ICE_STATION = "ice_station"     # 얼음 정거장
    VOLCANIC_PORT = "volcanic_port" # 화산 항구
    CLOUD_CITY = "cloud_city"       # 구름 도시
    UNDERWATER_BASE = "underwater"  # 해저 기지
    SPACE_STATION = "space_station" # 우주 정거장

PLANET_THEMES = {
    PlanetTheme.CYBER_CITY: {
        "name": "네온 시티",
        "bg_color": (15, 15, 35),
        "ground_color": (35, 35, 50),         # 바닥: 어두운 톤
        "road_color": (90, 95, 120),          # 도로: 밝은 돌길 (대비 강화)
        "accent_color": Colors.NEON_CYAN,
        "particles": "neon_rain",
    },
    PlanetTheme.DESERT_TOWN: {
        "name": "사막 마을",
        "bg_color": (60, 40, 20),
        "ground_color": (170, 150, 110),      # 바닥: 모래
        "road_color": (210, 195, 165),        # 도로: 밝은 사암 (대비 강화)
        "accent_color": Colors.NEON_ORANGE,
        "particles": "sand",
    },
    PlanetTheme.FOREST_VILLAGE: {
        "name": "숲속 마을",
        "bg_color": (20, 40, 20),
        "ground_color": (30, 65, 30),         # 바닥: 어두운 풀밭
        "road_color": (140, 120, 90),         # 도로: 밝은 흙길 (대비 강화)
        "accent_color": Colors.NEON_GREEN,
        "particles": "leaves",
    },
    PlanetTheme.ICE_STATION: {
        "name": "얼음 정거장",
        "bg_color": (20, 30, 50),
        "ground_color": (160, 180, 200),      # 바닥: 어두운 얼음
        "road_color": (220, 235, 250),        # 도로: 밝은 눈길 (대비 강화)
        "accent_color": Colors.NEON_CYAN,
        "particles": "snow",
    },
    PlanetTheme.SPACE_STATION: {
        "name": "우주 정거장",
        "bg_color": (5, 5, 15),
        "ground_color": (40, 40, 55),         # 바닥: 어두운 금속
        "road_color": (100, 105, 130),        # 도로: 밝은 금속 통로 (대비 강화)
        "accent_color": Colors.NEON_PURPLE,
        "particles": "stars",
    },
}

# =============================================================================
# 이벤트 설정
# =============================================================================
EVENT_TRANSITION_TIME = 0.5     # 이벤트 전환 시간 (초)
INTERACTION_RANGE = TILE_SIZE   # 상호작용 범위

# =============================================================================
# 사운드
# =============================================================================
SOUND_FOOTSTEP = "footstep"
SOUND_DOOR_OPEN = "door_open"
SOUND_COIN = "coin"
SOUND_INTERACT = "interact"
