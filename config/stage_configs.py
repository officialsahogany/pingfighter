"""
스테이지별 설정
각 스테이지의 보스, 배경, 난이도 등 설정
"""

# ============= 스테이지 정보 =============
TOTAL_STAGES = 8
BOSS_HEALTH_STAGES = [6, 11, 16, 21]  # 체력형 보스가 등장하는 스테이지

# ============= 스테이지별 보스 설정 =============
BOSS_CONFIGS = {
    1: {
        "name": "풍악보이",
        "color": (255, 255, 255),
        "accel": 0.798,       # 35% 감소
        "decel": 0.798,
        "max_speed": 6.3175,  # 35% 감소
        "instant_stop": 0.665,
        "predict_distance": 160,
        "skill_power": 1.0,
        "fail_error": 315,    # 10% 감소
        "special_skill": "whip",  # 상모돌리기
        # 보스 대쉬 쿨타임 (초 단위, 최소~최대)
        "dash_cooldown_range": (40.0, 55.0),
        # 보스 대쉬 발동 확률 (0.0~1.0)
        "dash_trigger_chance": 0.30,
        # 보스 대쉬 후 통제불능 시간(초)
        "dash_stun_duration": 0.60,
        # 보스 대쉬 최대 이동 거리(px)
        "dash_max_distance": 240,
    },
    2: {
        "name": "악어장군",
        "color": (0, 255, 0),
        "accel": 0.840,     
        "decel": 0.840,     
        "max_speed": 6.3,   # 11.5 -> 11.0 으로 감소 (원래 6.585에서 6.3으로)
        "instant_stop": 0.714,
        "predict_distance": 150,
        "skill_power": 0.8,
        "fail_error": 285,
        "special_skill": "speed_defense",  # 스피드디펜스
        # 스테이지 2: 대쉬 쿨타임 38~53초
        "dash_cooldown_range": (38.0, 53.0),
        "dash_trigger_chance": 0.33,
        "dash_stun_duration": 0.56,
        "dash_max_distance": 250,
    },
    3: {
        "name": "멘헤라걸",
        "color": (255, 0, 255),
        "accel": 0.866,     
        "decel": 0.866,     
        "max_speed": 6.521,   
        "instant_stop": 0.768,
        "predict_distance": 150,
        "skill_power": 0.6,
        "fail_error": 260,
        "special_skill": "emotional_overdrive",  # 감정 폭주
        # 스테이지 3: 대쉬 쿨타임 36~51초
        "dash_cooldown_range": (36.0, 51.0),
        "dash_trigger_chance": 0.36,
        "dash_stun_duration": 0.52,
        "dash_max_distance": 260,
    },
    4: {
        "name": "퐁크",
        "color": (255, 215, 0),
        "accel": 0.900,     # 사용자 요청 값
        "decel": 0.900,     # 사용자 요청 값
        "max_speed": 6.912,  # 사용자 요청 값
        "instant_stop": 0.740,  # 사용자 요청 값
        "predict_distance": 150,  # 사용자 요청 값
        "skill_power": 0.4,
        "fail_error": 260,  # 사용자 요청 값
        "special_skill": "grenade",  # 수류탄
        # 스테이지 4: 조금 더 짧은 대쉬 쿨타임
        "dash_cooldown_range": (34.0, 48.0),
        "dash_max_distance": 270,
    },
    5: {
        "name": "홍련",
        "color": (255, 80, 0),
        "accel": 0.973,       
        "decel": 0.973,       
        "max_speed": 7.571,   
        "instant_stop": 0.859,
        "predict_distance": 130,
        "skill_power": 0.2,
        "fail_error": 245,
        "special_skill": "chaos_ball",  # 카오스볼
        # 스테이지 5: 고난이도 구간, 쿨타임 추가 단축
        "dash_cooldown_range": (32.0, 46.0),
        # 홍련은 대쉬 가능 (네메시스와 구분)
        "dash_enabled": True,
        "dash_max_distance": 280,
    },
    6: {
        "name": "보스러시",
        "color": (255, 255, 255),
        "accel": 2.0,
        "decel": 2.0,
        "max_speed": 13.0,
        "instant_stop": 1.5,
        "predict_distance": 60,
        "skill_power": 1.0,
        "fail_error": 50,
        "special_skill": "ultimate",
        "is_health_boss": True,
        "max_health": 15,
        # 스테이지 6: 체력형 보스, 더 자주 대쉬
        "dash_cooldown_range": (26.0, 38.0),
        "dash_max_distance": 290,
    },
    7: {
        "name": "테트리서",
        "color": (120, 170, 255),
        "accel": 0.3,
        "decel": 0.4,
        "max_speed": 4.95,
        "instant_stop": 0.5,
        "predict_distance": 140,
        "skill_power": 0.3,
        "fail_error": 230,
        "special_skill": "tetris_field",
        # 스테이지 7: 최종 보스, 가장 짧은 대쉬 쿨타임
        "dash_cooldown_range": (28.0, 40.0),
        "dash_max_distance": 300,
    },
    8: {
        "name": "탁닌자",
        "color": (60, 80, 120),
        "accel": 1.11,
        "decel": 1.11,
        "max_speed": 9.4,
        "instant_stop": 1.131,
        "predict_distance": 120,
        "skill_power": 0.35,
        "fail_error": 180,
        "special_skill": None,  # 스킬은 추후 구현 예정
        "dash_cooldown_range": (26.0, 38.0),
        "dash_max_distance": 310,
    },
}

# ============= 스테이지별 배경 설정 =============
STAGE_BACKGROUNDS = {
    1: {
        "file": "stage1_field.png",
        "animated_class": "AnimatedBackground",
        "theme": "cyber_green",
        "ambient_color": (10, 50, 20),
    },
    2: {
        "file": "stage2_field.png", 
        "animated_class": "AnimatedBackgroundStage2",
        "theme": "jungle_deep",
        "ambient_color": (5, 10, 40),
    },
    3: {
        "file": "stage3_field.png",
        "animated_class": "AnimatedBackgroundStage3",
        "theme": "neon_pink",
        "ambient_color": (50, 10, 50),
    },
    4: {
        "file": "stage4_field.png",
        "animated_class": "AnimatedBackgroundStage4",
        "theme": "golden_cyber",
        "ambient_color": (50, 40, 10),
    },
    5: {
        "file": "stage5_field.png",
        "animated_class": "AnimatedBackgroundStage5", 
        "theme": "fire_storm",
        "ambient_color": (60, 20, 10),
    },
    6: {
        "file": "stage6_field.png",
        "animated_class": None,  # 스테이지 6은 특별 처리
        "theme": "space_carrier",
        "ambient_color": (20, 20, 40),
    },
    7: {
        "file": "stage7_field.png",
        "animated_class": None,
        "theme": "tetris_arena",
        "ambient_color": (24, 36, 68),
    },
    8: {
        # 임시로 스테이지7 필드를 재사용 (전용 맵/애니메이션 추후 추가 예정)
        "file": "stage7_field.png",
        "animated_class": None,
        "theme": "shadow_dojo",
        "ambient_color": (20, 28, 48),
    }
}

# ============= 스테이지별 난이도 조정 =============
STAGE_DIFFICULTY_MULTIPLIERS = {
    1: 1.0,   # 기본
    2: 1.2,   # 20% 어려움
    3: 1.4,   # 40% 어려움
    4: 1.6,   # 60% 어려움
    5: 1.8,   # 80% 어려움
    6: 2.0,   # 100% 어려움 (2배)
    7: 2.2,
    8: 2.35,
}

# ============= 스테이지별 특수 효과 =============
STAGE_SPECIAL_EFFECTS = {
    1: {
        "whip_enabled": True,
        "whip_chance": 0.12,  # 12% 확률
        "whip_duration": 200,
    },
    2: {
        "earthquake_enabled": True,
        "crisis_rocks_enabled": True,
        "rock_count": (3, 4),  # 3-4개
    },
    3: {
        "emotional_enabled": True,
        "tear_spawn_rate": 0.3,
        "mood_swing_speed": 2.0,
    },
    4: {
        "grenade_enabled": True,
        "grenade_damage": 50,
        "grenade_radius": 100,
    },
    5: {
        "chaos_enabled": True,
        "fireball_count": 3,
        "fire_damage": 30,
    },
    6: {
        "all_skills_enabled": True,
        "skill_rotation": True,
        "health_system": True,
    },
    7: {
        "tetrimino_field_active": True,
    },
    8: {
        # 공닌자 스킬/이펙트는 추후 추가 예정
    }
}

# ============= 리그별 보스 강화 =============
LEAGUE_BOSS_MULTIPLIERS = {
    "junior": {
        "speed": 1.0,
        "skill": 1.0,
        "health": 1.0,
    },
    "senior": {
        "speed": 1.5,
        "skill": 1.3,
        "health": 1.2,
    },
    "master": {
        "speed": 2.0,
        "skill": 1.6,
        "health": 1.5,
    },
    "legend": {
        "speed": 3.0,
        "skill": 2.0,
        "health": 2.0,
    }
}
