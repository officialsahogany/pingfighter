"""
스테이지별 설정
각 스테이지의 보스, 배경, 난이도 등 설정
"""

# ============= 스테이지 정보 =============
TOTAL_STAGES = 6
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
    },
    2: {
        "name": "악어장군",
        "color": (0, 255, 0),
        "accel": 0.840,     
        "decel": 0.840,     
        "max_speed": 6.585,   
        "instant_stop": 0.714,
        "predict_distance": 150,
        "skill_power": 0.8,
        "fail_error": 285,
        "special_skill": "speed_defense",  # 스피드디펜스
    },
    3: {
        "name": "멘헤라걸",
        "color": (255, 0, 255),
        "accel": 0.899,     
        "decel": 0.899,     
        "max_speed": 6.952,   
        "instant_stop": 0.768,
        "predict_distance": 140,
        "skill_power": 0.6,
        "fail_error": 260,
        "special_skill": "emotional_overdrive",  # 감정 폭주
    },
    4: {
        "name": "퐁크",
        "color": (255, 215, 0),
        "accel": 0.867,     
        "decel": 0.867,     
        "max_speed": 6.785,  
        "instant_stop": 0.720,
        "predict_distance": 150,
        "skill_power": 0.4,
        "fail_error": 270,
        "special_skill": "grenade",  # 수류탄
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
    }
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