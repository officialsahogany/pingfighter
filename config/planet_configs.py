"""
우주 행성 맵 시스템 - 행성/보스 로스터 설정
각 행성 = 기존 스테이지 (맵, 필러, 장치 공유)
각 행성에 보스 3명 슬롯 (랜덤 1명 선출)
"""

# 행성 설정 (display_stage 기준)
PLANET_CONFIGS = {
    1: {
        "name": "조선시대 행성",
        "theme_color": (180, 120, 50),      # 황금빛
        "glow_color": (255, 200, 80),        # 발광 색
        "ring_color": None,                   # 고리 없음
        "size": 28,                           # 행성 반지름
        "boss_roster": [
            {"name": "풍악보이", "implemented": True},
            {"name": "포도대장", "implemented": True},
            {"name": "각시탈", "implemented": True},
        ],
    },
    2: {
        "name": "정글 행성",
        "theme_color": (60, 130, 55),
        "glow_color": (100, 200, 80),
        "ring_color": (80, 160, 70),          # 초록 고리
        "size": 32,
        "boss_roster": [
            {"name": "악어장군", "implemented": True},
            {"name": "두더지왕", "implemented": True},
            {"name": "???", "implemented": False},
        ],
    },
    3: {
        "name": "멘헤라 행성",
        "theme_color": (180, 70, 150),
        "glow_color": (255, 120, 220),
        "ring_color": (200, 80, 180),
        "size": 26,
        "boss_roster": [
            {"name": "멘헤라걸", "implemented": True},
            {"name": "???", "implemented": False},
            {"name": "???", "implemented": False},
        ],
    },
    4: {
        "name": "사원 행성",
        "theme_color": (140, 100, 60),
        "glow_color": (220, 180, 100),
        "ring_color": None,
        "size": 30,
        "boss_roster": [
            {"name": "퐁크", "implemented": True},
            {"name": "???", "implemented": False},
            {"name": "???", "implemented": False},
        ],
    },
    5: {
        "name": "해상전투 행성",
        "theme_color": (50, 90, 160),
        "glow_color": (80, 150, 255),
        "ring_color": (60, 120, 200),
        "size": 34,
        "boss_roster": [
            {"name": "네메시스", "implemented": True},
            {"name": "???", "implemented": False},
            {"name": "???", "implemented": False},
        ],
    },
    6: {
        "name": "화염 행성",
        "theme_color": (200, 55, 55),
        "glow_color": (255, 100, 50),
        "ring_color": (255, 80, 30),
        "size": 30,
        "boss_roster": [
            {"name": "홍련", "implemented": True},
            {"name": "???", "implemented": False},
            {"name": "???", "implemented": False},
        ],
    },
    7: {
        "name": "테트리스 행성",
        "theme_color": (120, 170, 255),
        "glow_color": (160, 200, 255),
        "ring_color": (100, 150, 255),
        "size": 28,
        "boss_roster": [
            {"name": "테트리서", "implemented": True},
            {"name": "???", "implemented": False},
            {"name": "???", "implemented": False},
        ],
    },
    8: {
        "name": "그림자 행성",
        "theme_color": (60, 80, 120),
        "glow_color": (100, 130, 180),
        "ring_color": None,
        "size": 36,
        "boss_roster": [
            {"name": "아카무 리고", "implemented": True},
            {"name": "???", "implemented": False},
            {"name": "???", "implemented": False},
        ],
    },
}

# 전체 행성 수
TOTAL_PLANETS = len(PLANET_CONFIGS)


def get_available_bosses(planet_num):
    """해당 행성에서 선출 가능한 (구현된) 보스 목록 반환"""
    config = PLANET_CONFIGS.get(planet_num)
    if not config:
        return []
    return [b for b in config["boss_roster"] if b["implemented"]]


def select_random_boss(planet_num, rng=None):
    """해당 행성에서 랜덤으로 보스 1명 선출"""
    import random
    available = get_available_bosses(planet_num)
    if not available:
        return None
    if rng:
        return rng.choice(available)
    return random.choice(available)
