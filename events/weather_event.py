# -*- coding: utf-8 -*-
"""Weather Event System - Wind and Fire effects during rounds"""

import random
import math
import pygame

# ============== Configuration ==============
WEATHER_EVENT_PROBABILITY = 0.10  # 10% 확률

# 미풍 (Breeze) - 약한 바람
BREEZE_WIND_FORCE_PLAYER = 1.2
BREEZE_WIND_FORCE_BOSS = 1.0
BREEZE_WIND_FORCE_BALL = 0.08

# 강풍 (Strong Gust) - 강한 바람 (미풍보다 세고 기존보다 약하게 조정)
GUST_WIND_FORCE_PLAYER = 1.8
GUST_WIND_FORCE_BOSS = 1.5
GUST_WIND_FORCE_BALL = 0.12

# 불 (Fire) - 공 속도 증가
FIRE_BASE_SPEED_BOOST = 1.20  # 기본 공 속도 20% 증가
FIRE_HIT_SPEED_BOOST_MIN = 1.15  # 패들 타격 시 15% 추가 증가
FIRE_HIT_SPEED_BOOST_MAX = 1.20  # 패들 타격 시 20% 추가 증가
FIRE_GAUGE_DRAIN_PER_SECOND = 5  # 초당 게이지 5 감소

# 얼음 (Ice) - 미끄러움 효과
ICE_DIRECTION_CHANGE_PENALTY = 0.20  # 방향전환 속도 20%로 감소 (80% 감소)
ICE_ACCELERATION_MULTIPLIER = 0.25  # 가속도 25%로 감소 (75% 감소)
ICE_FRICTION = 0.985  # 마찰계수 (1에 가까울수록 미끄러움)
ICE_DASH_SLIDE_DURATION = 45  # 대쉬 후 미끄러지는 프레임 수

# 소나기 (Rain) - 둔화 효과
RAIN_SPEED_PENALTY = 0.40  # 이동속도 40% 감소
RAIN_PARTICLE_COUNT = 150  # 빗방울 개수
RAIN_PARTICLE_SPEED_MIN = 12  # 빗방울 최소 속도
RAIN_PARTICLE_SPEED_MAX = 18  # 빗방울 최대 속도
RAIN_PARTICLE_LENGTH_MIN = 10  # 빗방울 최소 길이
RAIN_PARTICLE_LENGTH_MAX = 25  # 빗방울 최대 길이

# 우박 (Hail) - 넉백 효과 (화염탄과 동일한 수치)
HAIL_PARTICLE_COUNT = 25  # 우박 개수 (빗방울보다 적음)
HAIL_SPAWN_INTERVAL = 30  # 우박 생성 간격 (프레임)
HAIL_FALL_SPEED_MIN = 6  # 우박 최소 낙하 속도
HAIL_FALL_SPEED_MAX = 10  # 우박 최대 낙하 속도
HAIL_SIZE_MIN = 8  # 우박 최소 크기
HAIL_SIZE_MAX = 16  # 우박 최대 크기
HAIL_KNOCKBACK_DURATION = 18  # 넉백 지속 프레임 (0.3초 - 화염탄과 동일)
HAIL_KNOCKBACK_STRENGTH = 12  # 넉백 강도 (화염탄과 동일)
HAIL_STUN_DURATION = 0.3  # 스턴 지속 시간 (초) - 화염탄과 동일
HAIL_HIT_COOLDOWN = 45  # 같은 우박에 연속 피격 방지 쿨다운 (프레임)

WIND_MIN_DURATION = 2
WIND_MAX_DURATION = 3
FIRE_MIN_DURATION = 2
FIRE_MAX_DURATION = 3
ICE_MIN_DURATION = 2
ICE_MAX_DURATION = 3
RAIN_MIN_DURATION = 2
RAIN_MAX_DURATION = 3
HAIL_MIN_DURATION = 2
HAIL_MAX_DURATION = 3

# ============== Global State ==============
weather_event_active = False
weather_event_type = None  # "breeze", "gust", "fire", "ice", "rain", or "hail"
weather_event_direction = 0  # -1 = left, 1 = right (바람용)
weather_event_remaining_rounds = 0
weather_event_just_started = False
weather_event_just_ended = False
weather_warning_timer = 0
weather_warning_text = ""
weather_end_timer = 0
weather_end_text = ""
weather_particles = []
weather_particle_timer = 0

# 불 이벤트 전용 상태
fire_ball_trail = []  # 공의 불 궤적
fire_floor_particles_player = []  # 플레이어 진영 바닥 불
fire_floor_particles_boss = []  # 보스 진영 바닥 불
fire_floor_timer = 0
fire_gauge_drain_accumulator = 0.0  # 게이지 감소 누적기 (프레임 단위)
fire_warning_pulse_timer = 0  # 경고 깜빡임 타이머
fire_explosion_particles = []  # 화염 폭발 파티클

# 화재 넉백 설정
FIRE_KNOCKBACK_DISTANCE = 15  # 넉백 거리

# 얼음 이벤트 전용 상태
ice_floor_particles = []  # 바닥 얼음 파티클
ice_floor_timer = 0
ice_sparkle_particles = []  # 반짝이는 얼음 입자
ice_dash_particles = []  # 대쉬 시 튀는 얼음 가루

# 소나기 이벤트 전용 상태
rain_particles = []  # 빗방울 파티클
rain_splash_particles = []  # 빗방울이 바닥에 튀는 효과
rain_paddle_splash_particles = []  # 패들에 비가 맞아서 튀는 효과
rain_floor_splash_particles = []  # 바닥에 비가 맞아서 튀는 효과 (향상된 버전)
rain_initialized = False  # 빗방울 초기화 여부

# 우박 이벤트 전용 상태
hail_particles = []  # 우박 파티클 [(x, y, size, speed, hit_cooldown), ...]
hail_impact_particles = []  # 우박 충돌 파티클 [(x, y, vx, vy, life, max_life), ...]
hail_spawn_timer = 0  # 우박 생성 타이머
hail_initialized = False  # 우박 초기화 여부
hail_player_hit_cooldown = 0  # 플레이어 피격 쿨다운

# 폰트 캐시
_cached_font_large = None
_cached_font_small = None

# 사운드 캐시
_weather_wind_sound = None
_weather_fire_sound = None
_weather_rain_sound = None


def _get_korean_font(size):
    """한글 지원 폰트 반환"""
    try:
        from pixel_font_manager import get_font
        return get_font(size)
    except:
        pass

    korean_fonts = [
        "NanumSquareR.ttf",
        "NanumSquareB.ttf",
        "NanumGothic.ttf",
        "AppleGothic.ttf",
        "Malgun Gothic",
        "맑은 고딕",
    ]

    for font_name in korean_fonts:
        try:
            return pygame.font.Font(font_name, size)
        except:
            try:
                return pygame.font.SysFont(font_name, size)
            except:
                continue

    return pygame.font.Font(None, size)


def get_weather_font_large():
    """큰 폰트 반환 (경고 메시지용)"""
    global _cached_font_large
    if _cached_font_large is None:
        _cached_font_large = _get_korean_font(36)
    return _cached_font_large


def get_weather_font_small():
    """작은 폰트 반환 (상태 표시용)"""
    global _cached_font_small
    if _cached_font_small is None:
        _cached_font_small = _get_korean_font(20)
    return _cached_font_small


def _load_weather_sounds():
    """날씨 사운드 로드"""
    global _weather_wind_sound, _weather_fire_sound, _weather_rain_sound
    import os

    try:
        # 현재 파일 위치 기준으로 sounds 폴더 경로 계산
        current_dir = os.path.dirname(os.path.abspath(__file__))
        sounds_dir = os.path.join(os.path.dirname(current_dir), "sounds")

        wind_path = os.path.join(sounds_dir, "weatherwind.wav")
        fire_path = os.path.join(sounds_dir, "weatherfire.wav")
        rain_path = os.path.join(sounds_dir, "weather_rain.wav")

        if os.path.exists(wind_path) and _weather_wind_sound is None:
            _weather_wind_sound = pygame.mixer.Sound(wind_path)
            _weather_wind_sound.set_volume(0.5)
            print(f"[Weather] Wind sound loaded: {wind_path}")

        if os.path.exists(fire_path) and _weather_fire_sound is None:
            _weather_fire_sound = pygame.mixer.Sound(fire_path)
            _weather_fire_sound.set_volume(0.5)
            print(f"[Weather] Fire sound loaded: {fire_path}")

        if os.path.exists(rain_path) and _weather_rain_sound is None:
            _weather_rain_sound = pygame.mixer.Sound(rain_path)
            _weather_rain_sound.set_volume(0.5)
            print(f"[Weather] Rain sound loaded: {rain_path}")
    except Exception as e:
        print(f"[Weather] Sound load error: {e}")


def play_weather_sound(event_type):
    """날씨 이벤트 사운드 재생"""
    global _weather_wind_sound, _weather_fire_sound, _weather_rain_sound

    # 사운드가 아직 로드되지 않았으면 로드
    if _weather_wind_sound is None or _weather_fire_sound is None or _weather_rain_sound is None:
        _load_weather_sounds()

    try:
        if event_type in ("breeze", "gust") and _weather_wind_sound:
            _weather_wind_sound.play()
            print(f"[Weather] Playing wind sound for {event_type}")
        elif event_type == "fire" and _weather_fire_sound:
            _weather_fire_sound.play()
            print(f"[Weather] Playing fire sound")
        elif event_type == "rain" and _weather_rain_sound:
            _weather_rain_sound.play()
            print(f"[Weather] Playing rain sound")
    except Exception as e:
        print(f"[Weather] Sound play error: {e}")


def stop_weather_sound():
    """날씨 이벤트 사운드 정지"""
    global _weather_wind_sound, _weather_fire_sound, _weather_rain_sound

    try:
        if _weather_wind_sound:
            _weather_wind_sound.stop()
            print("[Weather] Wind sound stopped")
        if _weather_fire_sound:
            _weather_fire_sound.stop()
            print("[Weather] Fire sound stopped")
        if _weather_rain_sound:
            _weather_rain_sound.stop()
            print("[Weather] Rain sound stopped")
    except Exception as e:
        print(f"[Weather] Sound stop error: {e}")


def reset_weather_state():
    """Reset all weather state variables"""
    global weather_event_active, weather_event_type, weather_event_direction
    global weather_event_remaining_rounds, weather_event_just_started, weather_event_just_ended
    global weather_warning_timer, weather_warning_text, weather_end_timer, weather_end_text
    global weather_particles, weather_particle_timer
    global fire_ball_trail, fire_floor_particles_player, fire_floor_particles_boss, fire_floor_timer
    global fire_explosion_particles
    global ice_floor_particles, ice_floor_timer, ice_sparkle_particles, ice_dash_particles
    global rain_particles, rain_splash_particles, rain_initialized

    # 🔊 날씨 사운드 정지
    stop_weather_sound()

    weather_event_active = False
    weather_event_type = None
    weather_event_direction = 0
    weather_event_remaining_rounds = 0
    weather_event_just_started = False
    weather_event_just_ended = False
    weather_warning_timer = 0
    weather_warning_text = ""
    weather_end_timer = 0
    weather_end_text = ""
    weather_particles = []
    weather_particle_timer = 0

    # 불 관련 초기화
    fire_ball_trail = []
    fire_floor_particles_player = []
    fire_floor_particles_boss = []
    fire_floor_timer = 0
    fire_explosion_particles = []

    # 얼음 관련 초기화
    ice_floor_particles = []
    ice_floor_timer = 0
    ice_sparkle_particles = []
    ice_dash_particles = []

    # 소나기 관련 초기화
    rain_particles = []
    rain_splash_particles = []
    rain_paddle_splash_particles = []
    rain_floor_splash_particles = []
    rain_initialized = False


def check_weather_event_on_round_start():
    """
    Called at the start of each round to check/update weather events.
    Returns dict with event status information.
    """
    global weather_event_active, weather_event_type, weather_event_direction
    global weather_event_remaining_rounds, weather_event_just_started, weather_event_just_ended
    global weather_warning_timer, weather_warning_text, weather_end_timer, weather_end_text
    global fire_ball_trail, fire_floor_particles_player, fire_floor_particles_boss
    global ice_floor_particles, ice_sparkle_particles

    result = {
        "started": False,
        "ended": False,
        "type": None,
        "direction": 0,
        "message": ""
    }

    weather_event_just_started = False
    weather_event_just_ended = False

    # If weather is already active, decrement remaining rounds
    if weather_event_active:
        weather_event_remaining_rounds -= 1

        if weather_event_remaining_rounds <= 0:
            # Weather event ends
            weather_event_active = False
            weather_event_just_ended = True

            # 🔊 날씨 사운드 정지
            stop_weather_sound()

            if weather_event_type == "breeze":
                weather_end_text = "미풍이 지나갔습니다!"
            elif weather_event_type == "gust":
                weather_end_text = "강풍이 지나갔습니다!"
            elif weather_event_type == "fire":
                weather_end_text = "불이 꺼졌습니다!"
                # 불 파티클 초기화
                fire_ball_trail = []
                fire_floor_particles_player = []
                fire_floor_particles_boss = []
            elif weather_event_type == "ice":
                weather_end_text = "얼음이 녹았습니다!"
                # 얼음 파티클 초기화
                ice_floor_particles = []
                ice_sparkle_particles = []
            elif weather_event_type == "rain":
                weather_end_text = "소나기가 그쳤습니다!"
                # 소나기 파티클 초기화
                rain_particles = []
                rain_splash_particles = []
                rain_paddle_splash_particles = []
                rain_floor_splash_particles = []
                rain_initialized = False

            weather_end_timer = 180  # 3 seconds at 60fps
            result["ended"] = True
            result["type"] = weather_event_type
            result["message"] = weather_end_text
            weather_event_type = None
            weather_event_direction = 0
            return result

        # Weather continues
        result["type"] = weather_event_type
        result["direction"] = weather_event_direction
        return result

    # Check for new weather event
    if random.random() < WEATHER_EVENT_PROBABILITY:
        weather_event_active = True
        weather_event_just_started = True

        # 20% 확률로 미풍, 강풍, 불, 얼음, 소나기 중 하나 (5가지)
        event_roll = random.random()
        if event_roll < 0.20:
            weather_event_type = "breeze"
            weather_event_direction = random.choice([-1, 1])
            weather_event_remaining_rounds = random.randint(WIND_MIN_DURATION, WIND_MAX_DURATION)
            weather_warning_text = "미풍이 불어옴!"
        elif event_roll < 0.40:
            weather_event_type = "gust"
            weather_event_direction = random.choice([-1, 1])
            weather_event_remaining_rounds = 1  # 강풍은 딱 1턴만 지속
            weather_warning_text = "강풍이 불어옴!"
        elif event_roll < 0.60:
            weather_event_type = "fire"
            weather_event_direction = 0  # 불은 방향 없음
            weather_event_remaining_rounds = random.randint(FIRE_MIN_DURATION, FIRE_MAX_DURATION)
            weather_warning_text = "화재 발생!"
        elif event_roll < 0.80:
            weather_event_type = "ice"
            weather_event_direction = 0  # 얼음은 방향 없음
            weather_event_remaining_rounds = random.randint(ICE_MIN_DURATION, ICE_MAX_DURATION)
            weather_warning_text = "빙판 발생!"
        else:
            weather_event_type = "rain"
            weather_event_direction = 0  # 소나기는 방향 없음
            weather_event_remaining_rounds = random.randint(RAIN_MIN_DURATION, RAIN_MAX_DURATION)
            weather_warning_text = "소나기 발생!"

        weather_warning_timer = 180  # 3 seconds

        result["started"] = True
        result["type"] = weather_event_type
        result["direction"] = weather_event_direction
        result["message"] = weather_warning_text

        # 날씨 이벤트 사운드 재생
        play_weather_sound(weather_event_type)

        if weather_event_type == "fire":
            print(f"[Weather] Fire started! Duration: {weather_event_remaining_rounds} round(s)")
        elif weather_event_type == "ice":
            print(f"[Weather] Ice started! Duration: {weather_event_remaining_rounds} round(s)")
        elif weather_event_type == "rain":
            print(f"[Weather] Rain started! Duration: {weather_event_remaining_rounds} round(s)")
        else:
            dir_text = "Left" if weather_event_direction < 0 else "Right"
            type_text = "Breeze" if weather_event_type == "breeze" else "Strong Gust"
            print(f"[Weather] {type_text} started! Direction: {dir_text}, Duration: {weather_event_remaining_rounds} round(s)")

    return result


def apply_weather_effects_to_player(player_rect, screen_width):
    """
    Calculate wind push for player paddle.
    Returns the amount to add to player's x position.
    """
    if not weather_event_active:
        return 0.0

    if weather_event_type == "breeze":
        wind_force = BREEZE_WIND_FORCE_PLAYER
    elif weather_event_type == "gust":
        wind_force = GUST_WIND_FORCE_PLAYER
    else:
        return 0.0  # 불은 패들에 영향 없음

    wind_push = wind_force * weather_event_direction

    new_x = player_rect.centerx + wind_push
    half_width = player_rect.width // 2

    if new_x - half_width < 0:
        wind_push = -(player_rect.centerx - half_width)
    elif new_x + half_width > screen_width:
        wind_push = screen_width - half_width - player_rect.centerx

    return wind_push


def apply_weather_effects_to_boss(boss_rect, screen_width):
    """
    Calculate wind push for boss paddle.
    Returns the amount to add to boss's x position.
    """
    if not weather_event_active:
        return 0.0

    if weather_event_type == "breeze":
        wind_force = BREEZE_WIND_FORCE_BOSS
    elif weather_event_type == "gust":
        wind_force = GUST_WIND_FORCE_BOSS
    else:
        return 0.0  # 불은 패들에 영향 없음

    wind_push = wind_force * weather_event_direction

    new_x = boss_rect.centerx + wind_push
    half_width = boss_rect.width // 2

    if new_x - half_width < 0:
        wind_push = -(boss_rect.centerx - half_width)
    elif new_x + half_width > screen_width:
        wind_push = screen_width - half_width - boss_rect.centerx

    return wind_push


def apply_weather_effects_to_ball(ball_vel):
    """
    Calculate wind effect on ball.
    Returns (dx, dy) to add to ball velocity.
    바람이 불어도 공의 수직 이동력을 유지하기 위해
    공의 진행 방향에 따라 수직 힘도 추가함.
    """
    if not weather_event_active:
        return (0.0, 0.0)

    if weather_event_type == "breeze":
        wind_force_x = BREEZE_WIND_FORCE_BALL
        vertical_boost = 0.03  # 미풍: 약한 수직 보정
    elif weather_event_type == "gust":
        wind_force_x = GUST_WIND_FORCE_BALL
        vertical_boost = 0.06  # 강풍: 강한 수직 보정
    else:
        return (0.0, 0.0)  # 불/얼음은 별도 처리

    # 수평 바람 효과
    dx = wind_force_x * weather_event_direction

    # 수직 보정: 공의 진행 방향에 따라 수직 힘 추가
    # ball_vel[1] < 0: 공이 위로 이동 중 (플레이어가 친 공) -> 위로 더 밀어줌 (dy 음수)
    # ball_vel[1] > 0: 공이 아래로 이동 중 (보스가 친 공) -> 아래로 더 밀어줌 (dy 양수)
    dy = 0.0
    if ball_vel[1] < 0:
        # 플레이어가 친 공 -> 위로 가는 힘 강화
        dy = -vertical_boost
    elif ball_vel[1] > 0:
        # 보스가 친 공 -> 아래로 가는 힘 강화
        dy = vertical_boost

    return (dx, dy)


def is_fire_active():
    """불 이벤트가 활성화되어 있는지 확인"""
    return weather_event_active and weather_event_type == "fire"


def get_fire_base_speed_multiplier():
    """불 이벤트 시 기본 공 속도 배율 반환"""
    if is_fire_active():
        return FIRE_BASE_SPEED_BOOST
    return 1.0


def get_fire_hit_speed_multiplier():
    """불 이벤트 시 패들 타격 후 속도 증가 배율 반환 (15%~20% 랜덤)"""
    if is_fire_active():
        return random.uniform(FIRE_HIT_SPEED_BOOST_MIN, FIRE_HIT_SPEED_BOOST_MAX)
    return 1.0


def get_fire_gauge_drain(fps=60):
    """불 이벤트 시 프레임당 게이지 감소량 반환"""
    global fire_gauge_drain_accumulator

    if not is_fire_active():
        fire_gauge_drain_accumulator = 0.0
        return 0

    # 초당 5 감소 → 프레임당 감소량 계산
    drain_per_frame = FIRE_GAUGE_DRAIN_PER_SECOND / fps
    fire_gauge_drain_accumulator += drain_per_frame

    # 정수 단위로 감소 (누적기가 1 이상이면 반환)
    if fire_gauge_drain_accumulator >= 1.0:
        drain_amount = int(fire_gauge_drain_accumulator)
        fire_gauge_drain_accumulator -= drain_amount
        return drain_amount
    return 0


def get_fire_warning_pulse():
    """불 이벤트 시 게이지바 경고 깜빡임 값 반환 (0.0 ~ 1.0)"""
    global fire_warning_pulse_timer

    if not is_fire_active():
        fire_warning_pulse_timer = 0
        return 0.0

    fire_warning_pulse_timer += 1
    # 부드러운 사인파 펄스 (약 1초 주기)
    pulse = (math.sin(fire_warning_pulse_timer * 0.1) + 1) / 2  # 0.0 ~ 1.0
    return pulse * 0.4 + 0.1  # 0.1 ~ 0.5 범위로 조정 (너무 강하지 않게)


def create_fire_explosion(x, y):
    """화염 폭발 파티클 생성 - 공이 패들에 닿을 때 호출"""
    global fire_explosion_particles

    if not is_fire_active():
        return

    # 폭발 파티클 생성 (다양한 크기와 속도)
    for _ in range(25):
        angle = random.uniform(0, math.pi * 2)
        speed = random.uniform(3, 12)
        fire_explosion_particles.append({
            "x": x,
            "y": y,
            "vx": math.cos(angle) * speed,
            "vy": math.sin(angle) * speed,
            "size": random.uniform(4, 12),
            "lifetime": 0,
            "max_lifetime": random.randint(20, 40),
            "alpha": 1.0,
            "color_phase": random.uniform(0, 1),  # 색상 단계 (노랑->주황->빨강)
            "type": "explosion"
        })

    # 불꽃 스파크 (작은 입자들)
    for _ in range(15):
        angle = random.uniform(0, math.pi * 2)
        speed = random.uniform(5, 15)
        fire_explosion_particles.append({
            "x": x,
            "y": y,
            "vx": math.cos(angle) * speed,
            "vy": math.sin(angle) * speed - 2,  # 약간 위로
            "size": random.uniform(1, 3),
            "lifetime": 0,
            "max_lifetime": random.randint(15, 30),
            "alpha": 1.0,
            "color_phase": 0,  # 밝은 노랑
            "type": "spark"
        })

    print(f"[Weather] Fire explosion created at ({x}, {y})")


def update_fire_explosion_particles():
    """화염 폭발 파티클 업데이트"""
    global fire_explosion_particles

    for p in fire_explosion_particles[:]:
        p["lifetime"] += 1
        p["x"] += p["vx"]
        p["y"] += p["vy"]

        # 중력 효과 (스파크는 더 빨리 떨어짐)
        if p["type"] == "spark":
            p["vy"] += 0.5
        else:
            p["vy"] += 0.2

        # 감속
        p["vx"] *= 0.95
        p["vy"] *= 0.95

        # 크기 감소
        p["size"] *= 0.96

        # 알파 감소
        lifetime_ratio = p["lifetime"] / p["max_lifetime"]
        p["alpha"] = 1.0 - lifetime_ratio

        # 수명 종료 또는 너무 작아지면 제거
        if p["lifetime"] >= p["max_lifetime"] or p["size"] < 0.5:
            fire_explosion_particles.remove(p)


def draw_fire_explosion_particles(screen):
    """화염 폭발 파티클 그리기"""
    for p in fire_explosion_particles:
        size = int(p["size"])
        if size < 1:
            continue

        alpha = int(255 * p["alpha"])
        if alpha < 10:
            continue

        # 색상 계산 (노랑 -> 주황 -> 빨강)
        lifetime_ratio = p["lifetime"] / p["max_lifetime"]
        phase = p["color_phase"] + lifetime_ratio * 0.5

        if p["type"] == "spark":
            # 스파크는 밝은 노랑/흰색
            r, g, b = 255, 255, 150
        elif phase < 0.3:
            # 밝은 노랑
            r, g, b = 255, 255, 100
        elif phase < 0.6:
            # 주황
            r, g, b = 255, 150, 50
        else:
            # 빨강/어두운 주황
            r, g, b = 255, 80, 30

        x, y = int(p["x"]), int(p["y"])

        # 글로우 효과
        surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
        center = size * 2

        # 외부 글로우
        glow_alpha = alpha // 3
        pygame.draw.circle(surf, (r, g, b, glow_alpha), (center, center), size * 2)

        # 코어
        pygame.draw.circle(surf, (r, g, b, alpha), (center, center), size)

        # 밝은 중심
        if size > 2:
            inner_alpha = min(255, int(alpha * 1.2))
            pygame.draw.circle(surf, (255, 255, 200, inner_alpha), (center, center), max(1, size // 2))

        screen.blit(surf, (x - center, y - center))


def get_fire_knockback_distance():
    """화재 이벤트 시 넉백 거리 반환"""
    if is_fire_active():
        return FIRE_KNOCKBACK_DISTANCE
    return 0


# ============== 얼음 이벤트 함수들 ==============
def is_ice_active():
    """얼음 이벤트가 활성화되어 있는지 확인"""
    return weather_event_active and weather_event_type == "ice"


def get_ice_direction_change_multiplier():
    """얼음 이벤트 시 방향전환 속도 배율 반환 (0.20 = 80% 감소)"""
    if is_ice_active():
        return ICE_DIRECTION_CHANGE_PENALTY
    return 1.0


def get_ice_acceleration_multiplier():
    """얼음 이벤트 시 가속도 배율 반환 (0.25 = 75% 감소)"""
    if is_ice_active():
        return ICE_ACCELERATION_MULTIPLIER
    return 1.0


def get_ice_friction():
    """얼음 이벤트 시 마찰계수 반환 (1에 가까울수록 미끄러움)"""
    if is_ice_active():
        return ICE_FRICTION
    return 0.0  # 일반 상태에서는 마찰 미적용


def get_ice_dash_slide_duration():
    """얼음 이벤트 시 대쉬 후 미끄러지는 프레임 수 반환"""
    if is_ice_active():
        return ICE_DASH_SLIDE_DURATION
    return 0


def create_ice_dash_particles(x, y, dash_direction, is_player=True):
    """대쉬 시 얼음 가루 파티클 생성 - 이동 방향을 따라 튀는 효과

    Args:
        x: 대쉬 시작 x 좌표
        y: 대쉬 시작 y 좌표
        dash_direction: 대쉬 방향 (-1: 왼쪽, 1: 오른쪽)
        is_player: 플레이어인지 여부 (True: 플레이어, False: 보스)
    """
    global ice_dash_particles

    if not is_ice_active():
        return

    # 대쉬 방향의 반대로 파티클이 튀어나감 (땅을 긁으며 튀는 느낌)
    base_vx = -dash_direction * 3  # 대쉬 반대 방향으로 튀어나감

    # 메인 얼음 조각들 (큰 파티클)
    for _ in range(12):
        angle_spread = random.uniform(-0.5, 0.5)  # 약간의 각도 퍼짐
        speed = random.uniform(4, 10)

        # 플레이어는 위로, 보스는 아래로 튀어오름
        vy_direction = -1 if is_player else 1

        ice_dash_particles.append({
            "x": x + random.uniform(-20, 20),
            "y": y,
            "vx": base_vx + math.cos(angle_spread) * speed * -dash_direction,
            "vy": vy_direction * random.uniform(2, 6) + random.uniform(-1, 1),
            "size": random.uniform(3, 8),
            "lifetime": 0,
            "max_lifetime": random.randint(25, 45),
            "alpha": random.uniform(0.7, 1.0),
            "rotation": random.uniform(0, 360),
            "rotation_speed": random.uniform(-15, 15),
            "type": "chunk",
            "sparkle_phase": random.uniform(0, math.pi * 2)
        })

    # 작은 얼음 가루 (미세 파티클)
    for _ in range(20):
        angle = random.uniform(-math.pi/3, math.pi/3)  # 부채꼴 모양으로 퍼짐
        speed = random.uniform(2, 8)

        vy_direction = -1 if is_player else 1

        ice_dash_particles.append({
            "x": x + random.uniform(-30, 30),
            "y": y + random.uniform(-5, 5),
            "vx": base_vx * 0.5 + math.cos(angle) * speed * -dash_direction,
            "vy": vy_direction * random.uniform(1, 4) + math.sin(angle) * speed * 0.3,
            "size": random.uniform(1, 3),
            "lifetime": 0,
            "max_lifetime": random.randint(15, 30),
            "alpha": random.uniform(0.5, 0.9),
            "rotation": 0,
            "rotation_speed": 0,
            "type": "dust",
            "sparkle_phase": random.uniform(0, math.pi * 2)
        })

    # 반짝이는 빛 입자
    for _ in range(8):
        ice_dash_particles.append({
            "x": x + random.uniform(-25, 25),
            "y": y,
            "vx": random.uniform(-3, 3) + base_vx * 0.3,
            "vy": (-1 if is_player else 1) * random.uniform(1, 3),
            "size": random.uniform(1, 2),
            "lifetime": 0,
            "max_lifetime": random.randint(10, 20),
            "alpha": 1.0,
            "rotation": 0,
            "rotation_speed": 0,
            "type": "sparkle",
            "sparkle_phase": random.uniform(0, math.pi * 2)
        })

    print(f"[Weather] Ice dash particles created at ({x}, {y}), direction: {'left' if dash_direction < 0 else 'right'}")


def update_ice_dash_particles():
    """대쉬 얼음 파티클 업데이트"""
    global ice_dash_particles

    for p in ice_dash_particles[:]:
        p["lifetime"] += 1
        p["x"] += p["vx"]
        p["y"] += p["vy"]

        # 중력 효과
        if p["type"] == "chunk":
            p["vy"] += 0.3  # 큰 조각은 더 빨리 떨어짐
            p["rotation"] += p["rotation_speed"]
        elif p["type"] == "dust":
            p["vy"] += 0.15  # 가루는 천천히
        else:  # sparkle
            p["vy"] += 0.1

        # 공기 저항
        p["vx"] *= 0.96
        p["vy"] *= 0.98

        # 크기 감소
        if p["type"] == "chunk":
            p["size"] *= 0.97
        else:
            p["size"] *= 0.95

        # 알파 감소
        lifetime_ratio = p["lifetime"] / p["max_lifetime"]
        p["alpha"] = (1.0 - lifetime_ratio) * p.get("alpha", 1.0)

        # 반짝임 페이즈 업데이트
        p["sparkle_phase"] = p.get("sparkle_phase", 0) + 0.4

        # 수명 종료 또는 너무 작아지면 제거
        if p["lifetime"] >= p["max_lifetime"] or p["size"] < 0.3:
            ice_dash_particles.remove(p)


def draw_ice_dash_particles(screen):
    """대쉬 얼음 파티클 그리기"""
    for p in ice_dash_particles:
        size = int(p["size"])
        if size < 1:
            continue

        alpha = int(255 * min(1.0, p.get("alpha", 1.0)))
        if alpha < 5:
            continue

        x, y = int(p["x"]), int(p["y"])

        if p["type"] == "chunk":
            # 큰 얼음 조각 - 다각형 모양
            surf = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
            center = size * 3 // 2

            # 외부 글로우
            glow_alpha = alpha // 4
            pygame.draw.circle(surf, (200, 230, 255, glow_alpha), (center, center), size + 2)

            # 메인 얼음 조각 (불규칙한 다각형처럼 보이게)
            ice_color = (220, 245, 255, alpha)
            pygame.draw.circle(surf, ice_color, (center, center), size)

            # 밝은 하이라이트
            highlight_alpha = min(255, int(alpha * 1.2))
            pygame.draw.circle(surf, (255, 255, 255, highlight_alpha),
                             (center - size//3, center - size//3), max(1, size//3))

            screen.blit(surf, (x - center, y - center))

        elif p["type"] == "dust":
            # 작은 얼음 가루
            surf = pygame.Surface((size * 2 + 2, size * 2 + 2), pygame.SRCALPHA)
            center = size + 1

            # 반투명 하늘색
            dust_color = (200, 240, 255, alpha)
            pygame.draw.circle(surf, dust_color, (center, center), size)

            screen.blit(surf, (x - center, y - center))

        else:  # sparkle
            # 반짝이는 빛
            sparkle = (math.sin(p.get("sparkle_phase", 0)) + 1) / 2
            sparkle_alpha = int(alpha * sparkle)

            if sparkle_alpha > 10:
                surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
                center = size * 2

                # 밝은 흰색 점
                pygame.draw.circle(surf, (255, 255, 255, sparkle_alpha), (center, center), size)

                # 십자형 빛
                line_alpha = sparkle_alpha // 2
                pygame.draw.line(surf, (255, 255, 255, line_alpha),
                               (center - size * 2, center), (center + size * 2, center), 1)
                pygame.draw.line(surf, (255, 255, 255, line_alpha),
                               (center, center - size * 2), (center, center + size * 2), 1)

                screen.blit(surf, (x - center, y - center))


def update_ice_floor_particles(screen_width, screen_height):
    """바닥 얼음 파티클 업데이트 - 반짝이는 얼음 효과"""
    global ice_floor_particles, ice_sparkle_particles, ice_floor_timer

    if not is_ice_active():
        ice_floor_particles = []
        ice_sparkle_particles = []
        return

    ice_floor_timer += 1

    # 바닥 얼음 타일 패턴 (한 번만 생성, 이후 유지)
    if len(ice_floor_particles) < 20:
        # 플레이어 진영 (하단)
        for i in range(10):
            ice_floor_particles.append({
                "x": random.uniform(20, screen_width - 20),
                "y": screen_height - random.uniform(5, 25),
                "size": random.uniform(30, 60),
                "alpha": random.uniform(0.15, 0.3),
                "rotation": random.uniform(0, 360),
                "type": "floor"
            })
        # 보스 진영 (상단)
        for i in range(10):
            ice_floor_particles.append({
                "x": random.uniform(20, screen_width - 20),
                "y": random.uniform(5, 25),
                "size": random.uniform(30, 60),
                "alpha": random.uniform(0.15, 0.3),
                "rotation": random.uniform(0, 360),
                "type": "floor"
            })

    # 반짝이는 얼음 입자 생성
    if ice_floor_timer % 3 == 0:
        # 플레이어 진영
        ice_sparkle_particles.append({
            "x": random.uniform(10, screen_width - 10),
            "y": screen_height - random.uniform(3, 20),
            "size": random.uniform(1, 3),
            "lifetime": 0,
            "max_lifetime": random.randint(20, 40),
            "alpha": random.uniform(0.5, 1.0),
            "sparkle_phase": random.uniform(0, math.pi * 2)
        })
        # 보스 진영
        ice_sparkle_particles.append({
            "x": random.uniform(10, screen_width - 10),
            "y": random.uniform(3, 20),
            "size": random.uniform(1, 3),
            "lifetime": 0,
            "max_lifetime": random.randint(20, 40),
            "alpha": random.uniform(0.5, 1.0),
            "sparkle_phase": random.uniform(0, math.pi * 2)
        })

    # 반짝이 파티클 업데이트
    for p in ice_sparkle_particles[:]:
        p["lifetime"] += 1
        p["sparkle_phase"] += 0.3

        if p["lifetime"] >= p["max_lifetime"]:
            ice_sparkle_particles.remove(p)


def draw_ice_particles(screen):
    """얼음 파티클 그리기 - 투명한 청량감 있는 얼음 효과"""
    if not is_ice_active():
        return

    # 1. 바닥 얼음 레이어 (큰 투명 패치)
    for p in ice_floor_particles:
        size = int(p["size"])
        alpha = int(255 * p["alpha"])

        # 얼음 색상 - 연한 하늘색/청록색
        surf = pygame.Surface((size * 2, size), pygame.SRCALPHA)

        # 그라데이션 효과
        outer_color = (180, 220, 255, alpha // 3)
        mid_color = (200, 235, 255, alpha // 2)
        inner_color = (220, 245, 255, alpha)

        # 타원형 얼음 패치
        pygame.draw.ellipse(surf, outer_color, (0, 0, size * 2, size))
        pygame.draw.ellipse(surf, mid_color, (size // 4, size // 8, size * 3 // 2, size * 3 // 4))
        pygame.draw.ellipse(surf, inner_color, (size // 2, size // 4, size, size // 2))

        screen.blit(surf, (int(p["x"]) - size, int(p["y"]) - size // 2))

    # 2. 반짝이는 입자 레이어
    for p in ice_sparkle_particles:
        lifetime_ratio = p["lifetime"] / p["max_lifetime"]
        sparkle = (math.sin(p["sparkle_phase"]) + 1) / 2  # 0 ~ 1
        alpha = int(255 * p["alpha"] * sparkle * (1 - lifetime_ratio))

        if alpha < 10:
            continue

        size = int(p["size"])
        x, y = int(p["x"]), int(p["y"])

        # 반짝이는 별 모양
        surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
        center = size * 2

        # 밝은 하얀색/하늘색 반짝임
        pygame.draw.circle(surf, (255, 255, 255, alpha), (center, center), size)
        pygame.draw.circle(surf, (200, 240, 255, alpha // 2), (center, center), size * 2)

        # 십자형 반짝임
        pygame.draw.line(surf, (255, 255, 255, alpha), (center - size * 2, center), (center + size * 2, center), 1)
        pygame.draw.line(surf, (255, 255, 255, alpha), (center, center - size * 2), (center, center + size * 2), 1)

        screen.blit(surf, (x - center, y - center))


# ============== 소나기 이벤트 함수들 ==============
def is_rain_active():
    """소나기 이벤트가 활성화되어 있는지 확인"""
    return weather_event_active and weather_event_type == "rain"


def get_rain_speed_penalty():
    """소나기 이벤트 시 이동속도 감소율 반환 (0.30 = 30% 감소)"""
    if is_rain_active():
        return RAIN_SPEED_PENALTY
    return 0.0


def init_rain_particles(screen_width, screen_height):
    """빗방울 파티클 초기화"""
    global rain_particles, rain_initialized

    if rain_initialized:
        return

    rain_particles = []
    for _ in range(RAIN_PARTICLE_COUNT):
        rain_particles.append({
            "x": random.uniform(0, screen_width),
            "y": random.uniform(-screen_height, screen_height),
            "speed": random.uniform(RAIN_PARTICLE_SPEED_MIN, RAIN_PARTICLE_SPEED_MAX),
            "length": random.uniform(RAIN_PARTICLE_LENGTH_MIN, RAIN_PARTICLE_LENGTH_MAX),
            "alpha": random.uniform(0.3, 0.7),
            "wind_offset": random.uniform(-1, 1)  # 약간의 바람 효과
        })

    rain_initialized = True
    print(f"[Weather] Rain particles initialized: {len(rain_particles)} drops")


def update_rain_particles(screen_width, screen_height):
    """빗방울 파티클 업데이트"""
    global rain_particles, rain_splash_particles

    if not is_rain_active():
        rain_particles = []
        rain_splash_particles = []
        return

    # 빗방울 업데이트
    for p in rain_particles:
        # 아래로 떨어짐 + 약간의 바람 효과
        p["y"] += p["speed"]
        p["x"] += p["wind_offset"]

        # 화면 아래로 벗어나면 상단에서 다시 생성
        if p["y"] > screen_height + 10:
            p["y"] = random.uniform(-50, -10)
            p["x"] = random.uniform(0, screen_width)
            p["speed"] = random.uniform(RAIN_PARTICLE_SPEED_MIN, RAIN_PARTICLE_SPEED_MAX)

            # 바닥에 물방울 튀는 효과 생성 (확률적)
            if random.random() < 0.3:
                rain_splash_particles.append({
                    "x": p["x"],
                    "y": screen_height - 5,
                    "radius": random.uniform(2, 5),
                    "lifetime": 0,
                    "max_lifetime": random.randint(8, 15),
                    "alpha": 0.6
                })

        # 화면 좌우로 벗어나면 반대편으로
        if p["x"] < -10:
            p["x"] = screen_width + 5
        elif p["x"] > screen_width + 10:
            p["x"] = -5

    # 물방울 튀는 효과 업데이트
    for splash in rain_splash_particles[:]:
        splash["lifetime"] += 1
        splash["radius"] += 0.5  # 점점 커지며 퍼짐
        splash["alpha"] *= 0.85  # 점점 투명해짐

        if splash["lifetime"] >= splash["max_lifetime"]:
            rain_splash_particles.remove(splash)


def create_rain_paddle_splash(x, y, is_player=True):
    """패들에 비가 맞았을 때 튀기는 이펙트 생성

    Args:
        x: 충돌 x 좌표
        y: 충돌 y 좌표
        is_player: 플레이어 패들인지 여부 (True: 플레이어, False: 보스)
    """
    global rain_paddle_splash_particles

    if not is_rain_active():
        return

    # 튀기는 방향 (플레이어는 위로, 보스는 아래로 + 좌우로 퍼짐)
    splash_dir = -1 if is_player else 1

    # 메인 물방울 튀김 (큰 입자들)
    for _ in range(6):
        angle = random.uniform(-math.pi/3, math.pi/3)  # 부채꼴 모양으로 퍼짐
        speed = random.uniform(3, 7)

        rain_paddle_splash_particles.append({
            "x": x + random.uniform(-8, 8),
            "y": y,
            "vx": math.sin(angle) * speed,
            "vy": splash_dir * abs(math.cos(angle)) * speed,
            "size": random.uniform(2, 5),
            "lifetime": 0,
            "max_lifetime": random.randint(15, 30),
            "alpha": random.uniform(0.6, 1.0),
            "type": "droplet",
            "gravity": 0.3
        })

    # 작은 물방울 스프레이 (미세 입자들)
    for _ in range(10):
        angle = random.uniform(-math.pi/2, math.pi/2)
        speed = random.uniform(2, 5)

        rain_paddle_splash_particles.append({
            "x": x + random.uniform(-5, 5),
            "y": y + random.uniform(-3, 3),
            "vx": math.sin(angle) * speed,
            "vy": splash_dir * abs(math.cos(angle)) * speed * 0.8,
            "size": random.uniform(1, 2.5),
            "lifetime": 0,
            "max_lifetime": random.randint(10, 20),
            "alpha": random.uniform(0.4, 0.8),
            "type": "mist",
            "gravity": 0.15
        })

    # 물방울 링 효과 (충돌 지점에 원형 파동)
    rain_paddle_splash_particles.append({
        "x": x,
        "y": y,
        "vx": 0,
        "vy": 0,
        "size": 3,
        "lifetime": 0,
        "max_lifetime": 20,
        "alpha": 0.7,
        "type": "ring",
        "gravity": 0
    })


def create_rain_floor_splash(x, y):
    """바닥에 비가 맞았을 때 튀기는 이펙트 생성 (향상된 버전)

    Args:
        x: 충돌 x 좌표
        y: 충돌 y 좌표 (바닥)
    """
    global rain_floor_splash_particles

    if not is_rain_active():
        return

    # 위로 튀어오르는 물방울들
    for _ in range(4):
        angle = random.uniform(-math.pi/4, math.pi/4)  # 위쪽으로 퍼짐
        speed = random.uniform(2, 5)

        rain_floor_splash_particles.append({
            "x": x + random.uniform(-3, 3),
            "y": y,
            "vx": math.sin(angle) * speed,
            "vy": -abs(math.cos(angle)) * speed,  # 항상 위로
            "size": random.uniform(1.5, 3),
            "lifetime": 0,
            "max_lifetime": random.randint(12, 22),
            "alpha": random.uniform(0.5, 0.9),
            "type": "droplet",
            "gravity": 0.4
        })

    # 작은 미스트/스프레이
    for _ in range(6):
        angle = random.uniform(-math.pi/2, math.pi/2)
        speed = random.uniform(1, 3)

        rain_floor_splash_particles.append({
            "x": x + random.uniform(-2, 2),
            "y": y,
            "vx": math.sin(angle) * speed,
            "vy": -abs(math.cos(angle)) * speed * 0.5,
            "size": random.uniform(0.8, 1.8),
            "lifetime": 0,
            "max_lifetime": random.randint(8, 15),
            "alpha": random.uniform(0.3, 0.6),
            "type": "mist",
            "gravity": 0.2
        })

    # 바닥 원형 파동
    rain_floor_splash_particles.append({
        "x": x,
        "y": y,
        "vx": 0,
        "vy": 0,
        "size": 2,
        "lifetime": 0,
        "max_lifetime": 15,
        "alpha": 0.5,
        "type": "ring",
        "gravity": 0
    })


def update_rain_particles_with_collision(screen_width, screen_height, player_rect=None, player_image_rect=None):
    """빗방울 파티클 업데이트 - 패들 및 바닥 충돌 감지 포함

    Args:
        screen_width: 화면 너비
        screen_height: 화면 높이
        player_rect: 플레이어 패들 박스 rect (선택적)
        player_image_rect: 플레이어 패들 이미지 rect (선택적, 이것을 사용하여 충돌 감지)
    """
    global rain_particles, rain_splash_particles, rain_paddle_splash_particles, rain_floor_splash_particles

    if not is_rain_active():
        rain_particles = []
        rain_splash_particles = []
        rain_paddle_splash_particles = []
        rain_floor_splash_particles = []
        return

    # 빗방울 업데이트
    for p in rain_particles:
        old_y = p["y"]

        # 아래로 떨어짐 + 약간의 바람 효과
        p["y"] += p["speed"]
        p["x"] += p["wind_offset"]

        # 플레이어 패들 이미지와 충돌 체크
        if player_image_rect is not None:
            # 빗방울이 패들 영역 안에 있는지 확인
            if (player_image_rect.left <= p["x"] <= player_image_rect.right and
                old_y < player_image_rect.top <= p["y"]):
                # 패들 상단에 충돌!
                create_rain_paddle_splash(p["x"], player_image_rect.top, is_player=True)
                # 빗방울 리셋
                p["y"] = random.uniform(-50, -10)
                p["x"] = random.uniform(0, screen_width)
                p["speed"] = random.uniform(RAIN_PARTICLE_SPEED_MIN, RAIN_PARTICLE_SPEED_MAX)
                continue

        # 화면 아래로 벗어나면 상단에서 다시 생성
        if p["y"] > screen_height + 10:
            p["y"] = random.uniform(-50, -10)
            p["x"] = random.uniform(0, screen_width)
            p["speed"] = random.uniform(RAIN_PARTICLE_SPEED_MIN, RAIN_PARTICLE_SPEED_MAX)

            # 바닥에 물방울 튀는 효과 생성 (확률적)
            if random.random() < 0.4:
                floor_x = random.uniform(0, screen_width)
                create_rain_floor_splash(floor_x, screen_height - 5)

                # 기존 간단한 스플래시도 추가 (원형 파동)
                rain_splash_particles.append({
                    "x": floor_x,
                    "y": screen_height - 5,
                    "radius": random.uniform(2, 5),
                    "lifetime": 0,
                    "max_lifetime": random.randint(8, 15),
                    "alpha": 0.6
                })

        # 화면 좌우로 벗어나면 반대편으로
        if p["x"] < -10:
            p["x"] = screen_width + 5
        elif p["x"] > screen_width + 10:
            p["x"] = -5

    # 기존 물방울 튀는 효과 업데이트
    for splash in rain_splash_particles[:]:
        splash["lifetime"] += 1
        splash["radius"] += 0.5  # 점점 커지며 퍼짐
        splash["alpha"] *= 0.85  # 점점 투명해짐

        if splash["lifetime"] >= splash["max_lifetime"]:
            rain_splash_particles.remove(splash)

    # 패들 스플래시 파티클 업데이트
    for p in rain_paddle_splash_particles[:]:
        p["lifetime"] += 1
        p["x"] += p["vx"]
        p["y"] += p["vy"]

        # 중력 적용
        p["vy"] += p["gravity"]

        # 공기 저항
        p["vx"] *= 0.98
        p["vy"] *= 0.99

        # 타입별 처리
        if p["type"] == "ring":
            # 링은 커지면서 사라짐
            p["size"] += 1.5
            p["alpha"] *= 0.88
        else:
            # 물방울은 크기 유지하다가 사라짐
            lifetime_ratio = p["lifetime"] / p["max_lifetime"]
            p["alpha"] = (1.0 - lifetime_ratio) * p.get("alpha", 1.0) * 1.5
            if lifetime_ratio > 0.7:
                p["size"] *= 0.95

        # 수명 종료
        if p["lifetime"] >= p["max_lifetime"] or p["alpha"] < 0.05:
            rain_paddle_splash_particles.remove(p)

    # 바닥 스플래시 파티클 업데이트
    for p in rain_floor_splash_particles[:]:
        p["lifetime"] += 1
        p["x"] += p["vx"]
        p["y"] += p["vy"]

        # 중력 적용
        p["vy"] += p["gravity"]

        # 공기 저항
        p["vx"] *= 0.97
        p["vy"] *= 0.98

        # 타입별 처리
        if p["type"] == "ring":
            p["size"] += 1.2
            p["alpha"] *= 0.85
        else:
            lifetime_ratio = p["lifetime"] / p["max_lifetime"]
            p["alpha"] = (1.0 - lifetime_ratio) * p.get("alpha", 1.0) * 1.3
            if lifetime_ratio > 0.6:
                p["size"] *= 0.93

        # 수명 종료
        if p["lifetime"] >= p["max_lifetime"] or p["alpha"] < 0.05:
            rain_floor_splash_particles.remove(p)


def draw_rain_particles(screen, screen_width, screen_height):
    """빗방울 파티클 그리기"""
    if not is_rain_active():
        return

    # 어두운 오버레이 (분위기 연출)
    overlay = pygame.Surface((screen_width, screen_height), pygame.SRCALPHA)
    overlay.fill((30, 40, 60, 40))  # 어두운 파란색 오버레이
    screen.blit(overlay, (0, 0))

    # 빗방울 그리기
    for p in rain_particles:
        alpha = int(255 * p["alpha"])
        start_x = int(p["x"])
        start_y = int(p["y"])
        end_x = int(p["x"] + p["wind_offset"] * 2)
        end_y = int(p["y"] + p["length"])

        # 빗방울 색상 (밝은 파란색/회색)
        rain_color = (180, 200, 220, alpha)

        # 얇은 선으로 빗방울 표현
        rain_surf = pygame.Surface((abs(end_x - start_x) + 4, int(p["length"]) + 4), pygame.SRCALPHA)
        pygame.draw.line(rain_surf, rain_color, (2, 0), (2 + (end_x - start_x), int(p["length"])), 2)
        screen.blit(rain_surf, (min(start_x, end_x) - 2, start_y))

    # 물방울 튀는 효과 그리기 (기존)
    for splash in rain_splash_particles:
        alpha = int(255 * splash["alpha"])
        if alpha < 10:
            continue

        radius = int(splash["radius"])
        x, y = int(splash["x"]), int(splash["y"])

        # 원형 물결
        splash_color = (150, 180, 210, alpha)
        splash_surf = pygame.Surface((radius * 2 + 4, radius + 4), pygame.SRCALPHA)
        pygame.draw.ellipse(splash_surf, splash_color, (0, 0, radius * 2, radius // 2 + 2), 1)
        screen.blit(splash_surf, (x - radius, y - radius // 4))

    # 패들 스플래시 파티클 그리기
    for p in rain_paddle_splash_particles:
        alpha_val = min(1.0, p.get("alpha", 0.5))
        alpha = int(255 * alpha_val)
        if alpha < 10:
            continue

        x, y = int(p["x"]), int(p["y"])
        size = max(1, int(p["size"]))

        if p["type"] == "ring":
            # 원형 파동 - 타원형으로 그림
            ring_size = int(p["size"])
            if ring_size > 1:
                ring_surf = pygame.Surface((ring_size * 2 + 4, ring_size + 4), pygame.SRCALPHA)
                ring_color = (180, 210, 240, alpha)
                pygame.draw.ellipse(ring_surf, ring_color, (0, 0, ring_size * 2, ring_size // 2 + 2), 2)
                screen.blit(ring_surf, (x - ring_size, y - ring_size // 4))
        elif p["type"] == "droplet":
            # 큰 물방울 - 타원형
            droplet_surf = pygame.Surface((size * 2 + 2, size * 2 + 2), pygame.SRCALPHA)
            # 외곽 글로우
            glow_color = (150, 190, 230, alpha // 3)
            pygame.draw.circle(droplet_surf, glow_color, (size + 1, size + 1), size + 1)
            # 메인 물방울
            droplet_color = (180, 210, 240, alpha)
            pygame.draw.circle(droplet_surf, droplet_color, (size + 1, size + 1), size)
            # 하이라이트
            if size > 2:
                highlight_color = (220, 240, 255, min(255, alpha + 50))
                pygame.draw.circle(droplet_surf, highlight_color, (size, size), max(1, size // 3))
            screen.blit(droplet_surf, (x - size - 1, y - size - 1))
        else:  # mist
            # 작은 미스트 - 흐릿한 원
            mist_surf = pygame.Surface((size * 2 + 2, size * 2 + 2), pygame.SRCALPHA)
            mist_color = (170, 200, 230, alpha)
            pygame.draw.circle(mist_surf, mist_color, (size + 1, size + 1), size)
            screen.blit(mist_surf, (x - size - 1, y - size - 1))

    # 바닥 스플래시 파티클 그리기
    for p in rain_floor_splash_particles:
        alpha_val = min(1.0, p.get("alpha", 0.5))
        alpha = int(255 * alpha_val)
        if alpha < 10:
            continue

        x, y = int(p["x"]), int(p["y"])
        size = max(1, int(p["size"]))

        if p["type"] == "ring":
            # 바닥 원형 파동 - 더 납작한 타원
            ring_size = int(p["size"])
            if ring_size > 1:
                ring_surf = pygame.Surface((ring_size * 2 + 4, ring_size // 2 + 4), pygame.SRCALPHA)
                ring_color = (160, 195, 230, alpha)
                pygame.draw.ellipse(ring_surf, ring_color, (0, 0, ring_size * 2, ring_size // 3 + 2), 1)
                screen.blit(ring_surf, (x - ring_size, y - ring_size // 6))
        elif p["type"] == "droplet":
            # 튀어오르는 물방울
            droplet_surf = pygame.Surface((size * 2 + 2, size * 2 + 2), pygame.SRCALPHA)
            droplet_color = (175, 205, 235, alpha)
            pygame.draw.circle(droplet_surf, droplet_color, (size + 1, size + 1), size)
            # 밝은 하이라이트
            if size > 1:
                highlight_color = (210, 235, 255, min(255, alpha + 40))
                pygame.draw.circle(droplet_surf, highlight_color, (size, size), max(1, size // 2))
            screen.blit(droplet_surf, (x - size - 1, y - size - 1))
        else:  # mist
            # 작은 미스트
            mist_surf = pygame.Surface((size * 2 + 2, size * 2 + 2), pygame.SRCALPHA)
            mist_color = (165, 195, 225, alpha)
            pygame.draw.circle(mist_surf, mist_color, (size + 1, size + 1), size)
            screen.blit(mist_surf, (x - size - 1, y - size - 1))


# ============== 우박 (Hail) 이벤트 함수 ==============

def is_hail_active():
    """우박 이벤트가 활성화되어 있는지 확인"""
    return weather_event_active and weather_event_type == "hail"


def init_hail_particles(screen_width, screen_height):
    """우박 파티클 초기화"""
    global hail_particles, hail_initialized, hail_spawn_timer

    if hail_initialized:
        return

    hail_particles = []
    hail_spawn_timer = 0
    hail_initialized = True
    print(f"[Weather] Hail system initialized")


def spawn_hail_particle(screen_width):
    """새 우박 파티클 생성"""
    global hail_particles

    size = random.uniform(HAIL_SIZE_MIN, HAIL_SIZE_MAX)
    hail_particles.append({
        "x": random.uniform(50, screen_width - 50),
        "y": random.uniform(-100, -20),
        "size": size,
        "speed": random.uniform(HAIL_FALL_SPEED_MIN, HAIL_FALL_SPEED_MAX),
        "rotation": random.uniform(0, 360),
        "rotation_speed": random.uniform(-5, 5),
        "wobble": random.uniform(0, math.pi * 2),
        "wobble_speed": random.uniform(0.1, 0.3),
        "alpha": random.uniform(0.7, 1.0)
    })


def update_hail_particles(screen_width, screen_height, player_rect=None):
    """우박 파티클 업데이트 및 플레이어 충돌 체크

    Returns:
        dict or None: 충돌 시 넉백 정보 {"knockback_vel": float, "stun_duration": float}
    """
    global hail_particles, hail_impact_particles, hail_spawn_timer, hail_player_hit_cooldown

    if not is_hail_active():
        hail_particles = []
        hail_impact_particles = []
        return None

    # 새 우박 생성
    hail_spawn_timer += 1
    if hail_spawn_timer >= HAIL_SPAWN_INTERVAL:
        hail_spawn_timer = 0
        # 한 번에 1-3개 생성
        for _ in range(random.randint(1, 3)):
            if len(hail_particles) < HAIL_PARTICLE_COUNT:
                spawn_hail_particle(screen_width)

    # 플레이어 피격 쿨다운 감소
    if hail_player_hit_cooldown > 0:
        hail_player_hit_cooldown -= 1

    hit_result = None

    # 우박 업데이트
    for hail in hail_particles[:]:
        # 낙하
        hail["y"] += hail["speed"]
        # 좌우 흔들림
        hail["wobble"] += hail["wobble_speed"]
        hail["x"] += math.sin(hail["wobble"]) * 0.5
        # 회전
        hail["rotation"] += hail["rotation_speed"]

        # 플레이어 충돌 체크
        if player_rect is not None and hail_player_hit_cooldown <= 0:
            hail_rect = pygame.Rect(
                hail["x"] - hail["size"] / 2,
                hail["y"] - hail["size"] / 2,
                hail["size"],
                hail["size"]
            )
            if hail_rect.colliderect(player_rect):
                # 충돌! 넉백 정보 반환 (화염탄과 동일한 방식)
                # 화염탄: random.choice([-12, 12]) 방식 사용
                hit_result = {
                    "knockback_vel": random.choice([-12, 12]),  # 화염탄과 동일한 넉백 강도
                    "stun_duration": HAIL_STUN_DURATION
                }
                hail_player_hit_cooldown = HAIL_HIT_COOLDOWN

                # 충돌 이펙트 생성
                create_hail_impact(hail["x"], hail["y"], hail["size"])

                # 이 우박 제거
                hail_particles.remove(hail)
                continue

        # 화면 아래로 벗어나면 제거 및 바닥 충돌 효과
        if hail["y"] > screen_height + 10:
            create_hail_impact(hail["x"], screen_height - 5, hail["size"] * 0.7)
            hail_particles.remove(hail)
            continue

    # 충돌 파티클 업데이트
    for p in hail_impact_particles[:]:
        p["x"] += p["vx"]
        p["y"] += p["vy"]
        p["vy"] += 0.3  # 중력
        p["life"] -= 1

        if p["life"] <= 0:
            hail_impact_particles.remove(p)

    return hit_result


def create_hail_impact(x, y, size):
    """우박 충돌 이펙트 생성"""
    global hail_impact_particles

    particle_count = int(size * 2)
    for _ in range(particle_count):
        angle = random.uniform(0, math.pi * 2)
        speed = random.uniform(2, 6)
        hail_impact_particles.append({
            "x": x,
            "y": y,
            "vx": math.cos(angle) * speed,
            "vy": math.sin(angle) * speed - 2,  # 위쪽으로 튀어오름
            "life": random.randint(10, 25),
            "max_life": 25,
            "size": random.uniform(2, 5)
        })


def draw_hail_particles(screen, screen_width, screen_height):
    """우박 파티클 그리기"""
    if not is_hail_active():
        return

    # 어두운 오버레이 (폭풍 분위기)
    overlay = pygame.Surface((screen_width, screen_height), pygame.SRCALPHA)
    overlay.fill((40, 50, 70, 50))  # 어두운 회색-파란 오버레이
    screen.blit(overlay, (0, 0))

    # 우박 그리기
    for hail in hail_particles:
        x, y = int(hail["x"]), int(hail["y"])
        size = int(hail["size"])
        alpha = int(255 * hail["alpha"])

        # 우박 표면 생성 (불규칙한 다각형으로 표현)
        hail_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)

        # 외곽 (어두운 파란색-회색)
        outer_color = (180, 200, 220, alpha)
        # 내부 (밝은 흰색-파란색)
        inner_color = (230, 240, 255, alpha)
        # 하이라이트
        highlight_color = (255, 255, 255, min(255, alpha + 30))

        center = size

        # 불규칙한 우박 모양 (6-8각형)
        num_points = random.randint(6, 8)
        points = []
        for i in range(num_points):
            angle = (i / num_points) * math.pi * 2 + math.radians(hail["rotation"])
            radius = size * random.uniform(0.7, 1.0)
            px = center + math.cos(angle) * radius
            py = center + math.sin(angle) * radius
            points.append((px, py))

        if len(points) >= 3:
            pygame.draw.polygon(hail_surf, outer_color, points)
            # 내부 밝은 부분
            inner_points = [(center + (p[0] - center) * 0.6, center + (p[1] - center) * 0.6) for p in points]
            pygame.draw.polygon(hail_surf, inner_color, inner_points)
            # 하이라이트
            pygame.draw.circle(hail_surf, highlight_color, (center - size // 4, center - size // 4), size // 4)

        screen.blit(hail_surf, (x - size, y - size))

    # 충돌 파티클 그리기
    for p in hail_impact_particles:
        life_ratio = p["life"] / p["max_life"]
        alpha = int(200 * life_ratio)
        size = int(p["size"] * life_ratio)

        if size < 1 or alpha < 10:
            continue

        # 얼음 파편 색상 (밝은 흰색-파란색)
        color = (220, 235, 255, alpha)
        particle_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
        pygame.draw.circle(particle_surf, color, (size, size), size)
        screen.blit(particle_surf, (int(p["x"]) - size, int(p["y"]) - size))


def reset_hail_state():
    """우박 이벤트 상태 초기화"""
    global hail_particles, hail_impact_particles, hail_spawn_timer
    global hail_initialized, hail_player_hit_cooldown

    hail_particles = []
    hail_impact_particles = []
    hail_spawn_timer = 0
    hail_initialized = False
    hail_player_hit_cooldown = 0


def update_fire_ball_trail(ball_x, ball_y, ball_vel_x, ball_vel_y):
    """불타는 공의 궤적 업데이트"""
    global fire_ball_trail

    if not is_fire_active():
        fire_ball_trail = []
        return

    # 새 궤적 파티클 추가
    speed = math.hypot(ball_vel_x, ball_vel_y)
    for _ in range(3):  # 프레임당 3개 파티클
        fire_ball_trail.append({
            "x": ball_x + random.uniform(-8, 8),
            "y": ball_y + random.uniform(-8, 8),
            "vx": -ball_vel_x * 0.1 + random.uniform(-1, 1),
            "vy": -ball_vel_y * 0.1 + random.uniform(-2, 0),
            "size": random.uniform(4, 10),
            "lifetime": 0,
            "max_lifetime": random.randint(15, 30),
            "color_phase": random.uniform(0, 1)
        })

    # 기존 파티클 업데이트
    for p in fire_ball_trail[:]:
        p["x"] += p["vx"]
        p["y"] += p["vy"]
        p["vy"] -= 0.1  # 불은 위로 올라감
        p["lifetime"] += 1
        p["size"] *= 0.95  # 점점 작아짐

        if p["lifetime"] >= p["max_lifetime"] or p["size"] < 1:
            fire_ball_trail.remove(p)


def update_fire_floor_particles(screen_width, screen_height):
    """바닥 불 파티클 업데이트 - 세련된 투명 불꽃 효과"""
    global fire_floor_particles_player, fire_floor_particles_boss, fire_floor_timer

    if not is_fire_active():
        fire_floor_particles_player = []
        fire_floor_particles_boss = []
        return

    fire_floor_timer += 1

    # 불꽃 소스 개수 줄임 (6개로)
    num_flame_sources = 6
    flame_spacing = (screen_width - 80) / (num_flame_sources - 1)

    # 플레이어 진영 (하단) - 낮은 불꽃
    player_floor_y = screen_height - 8  # 바닥에 더 가깝게

    for i in range(num_flame_sources):
        base_x = 40 + i * flame_spacing

        # 메인 불꽃 - 작고 낮게, 느리게 생성
        if fire_floor_timer % 4 == 0:
            fire_floor_particles_player.append({
                "x": base_x + random.uniform(-20, 20),
                "y": player_floor_y,
                "vx": random.uniform(-0.3, 0.3),
                "vy": random.uniform(-1.5, -0.8),  # 천천히 위로
                "size": random.uniform(4, 8),
                "lifetime": 0,
                "max_lifetime": random.randint(20, 35),
                "type": "main",
                "alpha": random.uniform(0.4, 0.7),  # 투명도
                "flicker": random.uniform(0, math.pi * 2)
            })

        # 작은 불씨 - 가끔만
        if fire_floor_timer % 8 == 0:
            fire_floor_particles_player.append({
                "x": base_x + random.uniform(-30, 30),
                "y": player_floor_y - random.uniform(5, 15),
                "vx": random.uniform(-0.8, 0.8),
                "vy": random.uniform(-2.5, -1.5),
                "size": random.uniform(1.5, 3),
                "lifetime": 0,
                "max_lifetime": random.randint(15, 25),
                "type": "ember",
                "alpha": random.uniform(0.5, 0.8),
                "flicker": random.uniform(0, math.pi * 2)
            })

        # 바닥 글로우 - 크고 투명하게
        if fire_floor_timer % 6 == 0:
            fire_floor_particles_player.append({
                "x": base_x + random.uniform(-15, 15),
                "y": player_floor_y + 3,
                "vx": 0,
                "vy": 0,
                "size": random.uniform(20, 35),
                "lifetime": 0,
                "max_lifetime": random.randint(30, 50),
                "type": "glow",
                "alpha": random.uniform(0.15, 0.25),  # 매우 투명
                "flicker": random.uniform(0, math.pi * 2)
            })

    # 보스 진영 (상단)
    boss_floor_y = 8

    for i in range(num_flame_sources):
        base_x = 40 + i * flame_spacing

        # 메인 불꽃 - 아래로
        if fire_floor_timer % 4 == 0:
            fire_floor_particles_boss.append({
                "x": base_x + random.uniform(-20, 20),
                "y": boss_floor_y,
                "vx": random.uniform(-0.3, 0.3),
                "vy": random.uniform(0.8, 1.5),  # 아래로
                "size": random.uniform(4, 8),
                "lifetime": 0,
                "max_lifetime": random.randint(20, 35),
                "type": "main",
                "alpha": random.uniform(0.4, 0.7),
                "flicker": random.uniform(0, math.pi * 2)
            })

        # 불씨
        if fire_floor_timer % 8 == 0:
            fire_floor_particles_boss.append({
                "x": base_x + random.uniform(-30, 30),
                "y": boss_floor_y + random.uniform(5, 15),
                "vx": random.uniform(-0.8, 0.8),
                "vy": random.uniform(1.5, 2.5),
                "size": random.uniform(1.5, 3),
                "lifetime": 0,
                "max_lifetime": random.randint(15, 25),
                "type": "ember",
                "alpha": random.uniform(0.5, 0.8),
                "flicker": random.uniform(0, math.pi * 2)
            })

        # 바닥 글로우
        if fire_floor_timer % 6 == 0:
            fire_floor_particles_boss.append({
                "x": base_x + random.uniform(-15, 15),
                "y": boss_floor_y - 3,
                "vx": 0,
                "vy": 0,
                "size": random.uniform(20, 35),
                "lifetime": 0,
                "max_lifetime": random.randint(30, 50),
                "type": "glow",
                "alpha": random.uniform(0.15, 0.25),
                "flicker": random.uniform(0, math.pi * 2)
            })

    # 파티클 업데이트
    for particles in [fire_floor_particles_player, fire_floor_particles_boss]:
        for p in particles[:]:
            p["x"] += p["vx"]
            p["y"] += p["vy"]
            p["lifetime"] += 1
            p["flicker"] = p.get("flicker", 0) + 0.2

            # 타입별 크기/투명도 감소
            if p["type"] == "main":
                p["size"] *= 0.97
                p["alpha"] *= 0.98
            elif p["type"] == "ember":
                p["size"] *= 0.95
                p["alpha"] *= 0.96
            elif p["type"] == "glow":
                p["size"] *= 0.99
                p["alpha"] *= 0.97

            if p["lifetime"] >= p["max_lifetime"] or p["size"] < 0.5 or p["alpha"] < 0.05:
                particles.remove(p)


def draw_fire_particles(screen):
    """불 파티클 그리기 - 투명도 활용 세련된 버전"""
    if not is_fire_active():
        return

    def get_fire_color_for_trail(phase, lifetime_ratio):
        """공 궤적용 불 색상 계산"""
        alpha = int(255 * (1 - lifetime_ratio) * 0.85)
        if phase < 0.33:
            return (255, 255, 100, alpha)  # 노랑
        elif phase < 0.66:
            return (255, 150, 50, alpha)   # 주황
        else:
            return (255, 80, 30, alpha)    # 빨강

    # 공 궤적 그리기
    for p in fire_ball_trail:
        lifetime_ratio = p["lifetime"] / p["max_lifetime"]
        color = get_fire_color_for_trail(p["color_phase"], lifetime_ratio)
        size = int(p["size"])
        if size > 0:
            surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            pygame.draw.circle(surf, color, (size, size), size)
            screen.blit(surf, (int(p["x"]) - size, int(p["y"]) - size))

    # 바닥 불 그리기 - 레이어별 (glow -> main -> ember)
    for particles in [fire_floor_particles_player, fire_floor_particles_boss]:

        # 1. 글로우 레이어 - 바닥에 은은한 빛
        for p in particles:
            if p.get("type") != "glow":
                continue
            size = int(p["size"])
            if size < 1:
                continue

            alpha = p.get("alpha", 0.2)
            flicker = 1.0 + 0.1 * math.sin(p.get("flicker", 0))

            # 부드러운 주황/빨강 빛
            base_alpha = int(255 * alpha * flicker)
            surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)

            # 그라데이션 효과 - 바깥쪽 더 투명
            outer_alpha = base_alpha // 3
            inner_alpha = base_alpha // 2
            pygame.draw.circle(surf, (255, 80, 20, outer_alpha), (size, size), size)
            pygame.draw.circle(surf, (255, 120, 40, inner_alpha), (size, size), size * 2 // 3)

            screen.blit(surf, (int(p["x"]) - size, int(p["y"]) - size))

        # 2. 메인 불꽃 레이어 - 작은 불꽃
        for p in particles:
            if p.get("type") != "main":
                continue
            size = int(p["size"])
            if size < 1:
                continue

            alpha = p.get("alpha", 0.5)
            lifetime_ratio = p["lifetime"] / p["max_lifetime"]
            flicker = 1.0 + 0.15 * math.sin(p.get("flicker", 0))

            # 색상: 노랑 -> 주황 -> 빨강
            if lifetime_ratio < 0.4:
                r, g, b = 255, 220, 100
            elif lifetime_ratio < 0.7:
                r, g, b = 255, 150, 50
            else:
                r, g, b = 255, 80, 30

            base_alpha = int(255 * alpha * flicker * (1 - lifetime_ratio * 0.5))

            # 작은 원형 불꽃
            surf = pygame.Surface((size * 2 + 2, size * 2 + 2), pygame.SRCALPHA)
            pygame.draw.circle(surf, (r, g, b, base_alpha), (size + 1, size + 1), size)
            # 밝은 코어
            core_alpha = min(255, int(base_alpha * 1.2))
            pygame.draw.circle(surf, (255, 255, 200, core_alpha), (size + 1, size + 1), max(1, size // 2))

            screen.blit(surf, (int(p["x"]) - size - 1, int(p["y"]) - size - 1))

        # 3. 불씨 레이어 - 작은 스파크
        for p in particles:
            if p.get("type") != "ember":
                continue
            size = int(p["size"])
            if size < 1:
                continue

            alpha = p.get("alpha", 0.6)
            flicker = 1.0 + 0.2 * math.sin(p.get("flicker", 0) * 2)

            base_alpha = int(255 * alpha * flicker)

            # 밝은 노랑/주황 점
            surf = pygame.Surface((size * 2 + 2, size * 2 + 2), pygame.SRCALPHA)
            pygame.draw.circle(surf, (255, 200, 80, base_alpha), (size + 1, size + 1), size)

            screen.blit(surf, (int(p["x"]) - size - 1, int(p["y"]) - size - 1))


def update_weather_particles(screen_width, screen_height):
    """Update wind particle effects"""
    global weather_particles, weather_particle_timer

    # 불/얼음 이벤트는 별도 처리
    if weather_event_type in ("fire", "ice"):
        weather_particles = []
        return

    if not weather_event_active:
        weather_particles = []
        return

    spawn_interval = 3 if weather_event_type == "breeze" else 2
    particle_speed_min = 5 if weather_event_type == "breeze" else 8
    particle_speed_max = 10 if weather_event_type == "breeze" else 15

    weather_particle_timer += 1
    if weather_particle_timer >= spawn_interval:
        weather_particle_timer = 0
        start_x = -10 if weather_event_direction > 0 else screen_width + 10
        start_y = random.randint(50, screen_height - 50)
        weather_particles.append({
            "x": start_x,
            "y": start_y,
            "speed": random.uniform(particle_speed_min, particle_speed_max),
            "size": random.randint(2, 5),
            "alpha": random.randint(80, 180) if weather_event_type == "breeze" else random.randint(100, 200),
            "wave_offset": random.uniform(0, math.pi * 2),
            "lifetime": 0
        })

    for p in weather_particles[:]:
        p["x"] += p["speed"] * weather_event_direction
        p["y"] += math.sin(p["lifetime"] * 0.1 + p["wave_offset"]) * 0.5
        p["lifetime"] += 1

        if (weather_event_direction > 0 and p["x"] > screen_width + 20) or \
           (weather_event_direction < 0 and p["x"] < -20) or \
           p["lifetime"] > 300:
            weather_particles.remove(p)


def draw_weather_particles(screen):
    """Draw wind particle effects"""
    if not weather_event_active or weather_event_type in ("fire", "ice"):
        return

    for p in weather_particles:
        if weather_event_type == "breeze":
            color = (180, 200, 255, p["alpha"])
        else:
            color = (200, 220, 255, p["alpha"])

        surf = pygame.Surface((p["size"] * 3, p["size"]), pygame.SRCALPHA)
        pygame.draw.ellipse(surf, color, (0, 0, p["size"] * 3, p["size"]))
        screen.blit(surf, (int(p["x"]), int(p["y"])))


def update_weather_ui_timers():
    """Update warning/end message timers"""
    global weather_warning_timer, weather_end_timer

    if weather_warning_timer > 0:
        weather_warning_timer -= 1
    if weather_end_timer > 0:
        weather_end_timer -= 1


def draw_weather_warning(screen, screen_width, screen_height, font=None):
    """Draw weather warning or end message with fade effects"""
    if font is None:
        font = get_weather_font_large()

    # Draw start warning
    if weather_warning_timer > 0:
        alpha = 255
        if weather_warning_timer > 150:
            alpha = int((180 - weather_warning_timer) / 30 * 255)
        elif weather_warning_timer < 30:
            alpha = int(weather_warning_timer / 30 * 255)

        # 날씨 종류에 따른 색상
        if "강풍" in weather_warning_text:
            text_color = (255, 200, 100)  # 주황색 (강풍)
            border_color = (255, 150, 50)
        elif "미풍" in weather_warning_text:
            text_color = (200, 230, 255)  # 연한 파란색 (미풍)
            border_color = (150, 200, 255)
        elif "화재" in weather_warning_text:
            text_color = (255, 100, 50)   # 빨간색 (불)
            border_color = (255, 50, 0)
        elif "빙판" in weather_warning_text:
            text_color = (180, 230, 255)  # 하늘색 (얼음)
            border_color = (100, 200, 255)
        else:
            text_color = (255, 255, 255)
            border_color = (200, 200, 200)

        txt = font.render(weather_warning_text, True, text_color)
        rect = txt.get_rect(center=(screen_width // 2, screen_height // 3))

        bg = rect.inflate(40, 20)
        bgs = pygame.Surface((bg.width, bg.height), pygame.SRCALPHA)
        bgs.fill((0, 0, 0, min(180, alpha)))
        screen.blit(bgs, bg.topleft)
        pygame.draw.rect(screen, border_color, bg, 3)

        txt.set_alpha(alpha)
        screen.blit(txt, rect)

    # Draw end message
    if weather_end_timer > 0:
        alpha = 255
        if weather_end_timer > 150:
            alpha = int((180 - weather_end_timer) / 30 * 255)
        elif weather_end_timer < 30:
            alpha = int(weather_end_timer / 30 * 255)

        txt = font.render(weather_end_text, True, (150, 255, 150))
        rect = txt.get_rect(center=(screen_width // 2, screen_height // 3))

        bg = rect.inflate(40, 20)
        bgs = pygame.Surface((bg.width, bg.height), pygame.SRCALPHA)
        bgs.fill((0, 0, 50, min(180, alpha)))
        screen.blit(bgs, bg.topleft)
        pygame.draw.rect(screen, (100, 200, 100), bg, 3)

        txt.set_alpha(alpha)
        screen.blit(txt, rect)


def draw_weather_indicator(screen, x, y, font=None):
    """Draw small weather status indicator during active event"""
    if not weather_event_active:
        return

    if font is None:
        font = get_weather_font_small()

    if weather_event_type == "breeze":
        dir_arrow = "<-" if weather_event_direction < 0 else "->"
        type_text = f"미풍 {dir_arrow}"
        text_color = (180, 200, 255)
        bg_color = (0, 0, 80, 150)
    elif weather_event_type == "gust":
        dir_arrow = "<-" if weather_event_direction < 0 else "->"
        type_text = f"강풍 {dir_arrow}"
        text_color = (255, 200, 100)
        bg_color = (50, 20, 0, 150)
    elif weather_event_type == "fire":
        type_text = "불"
        text_color = (255, 100, 50)
        bg_color = (80, 0, 0, 150)
    elif weather_event_type == "ice":
        type_text = "얼음"
        text_color = (180, 230, 255)
        bg_color = (0, 50, 80, 150)
    else:
        return

    txt = font.render(f"{type_text} ({weather_event_remaining_rounds}R)", True, text_color)
    rect = txt.get_rect(topleft=(x, y))

    bg = rect.inflate(10, 6)
    bgs = pygame.Surface((bg.width, bg.height), pygame.SRCALPHA)
    bgs.fill(bg_color)
    screen.blit(bgs, bg.topleft)
    screen.blit(txt, rect)


# ============== Utility Functions ==============
def is_weather_active():
    return weather_event_active


def get_weather_type():
    return weather_event_type


def get_weather_direction():
    return weather_event_direction


def get_weather_remaining_rounds():
    return weather_event_remaining_rounds


def force_start_breeze_event(direction=None, duration=None):
    """Force start a breeze event for testing"""
    global weather_event_active, weather_event_type, weather_event_direction
    global weather_event_remaining_rounds, weather_event_just_started
    global weather_warning_timer, weather_warning_text

    weather_event_active = True
    weather_event_type = "breeze"
    weather_event_direction = direction if direction else random.choice([-1, 1])
    weather_event_remaining_rounds = duration if duration else random.randint(1, 2)
    weather_event_just_started = True
    weather_warning_text = "미풍이 불어옴!"
    weather_warning_timer = 180

    print(f"[Weather] Forced breeze start! Direction: {'Left' if weather_event_direction < 0 else 'Right'}, Duration: {weather_event_remaining_rounds}")


def force_start_gust_event(direction=None, duration=None):
    """Force start a gust event for testing"""
    global weather_event_active, weather_event_type, weather_event_direction
    global weather_event_remaining_rounds, weather_event_just_started
    global weather_warning_timer, weather_warning_text

    weather_event_active = True
    weather_event_type = "gust"
    weather_event_direction = direction if direction else random.choice([-1, 1])
    weather_event_remaining_rounds = duration if duration else random.randint(1, 2)
    weather_event_just_started = True
    weather_warning_text = "강풍이 불어옴!"
    weather_warning_timer = 180

    print(f"[Weather] Forced gust start! Direction: {'Left' if weather_event_direction < 0 else 'Right'}, Duration: {weather_event_remaining_rounds}")


def force_start_fire_event(duration=None):
    """Force start a fire event for testing"""
    global weather_event_active, weather_event_type, weather_event_direction
    global weather_event_remaining_rounds, weather_event_just_started
    global weather_warning_timer, weather_warning_text

    weather_event_active = True
    weather_event_type = "fire"
    weather_event_direction = 0
    weather_event_remaining_rounds = duration if duration else random.randint(1, 2)
    weather_event_just_started = True
    weather_warning_text = "화재 발생!"
    weather_warning_timer = 180

    print(f"[Weather] Forced fire start! Duration: {weather_event_remaining_rounds}")


def force_start_ice_event(duration=None):
    """Force start an ice event for testing"""
    global weather_event_active, weather_event_type, weather_event_direction
    global weather_event_remaining_rounds, weather_event_just_started
    global weather_warning_timer, weather_warning_text

    weather_event_active = True
    weather_event_type = "ice"
    weather_event_direction = 0
    weather_event_remaining_rounds = duration if duration else random.randint(1, 2)
    weather_event_just_started = True
    weather_warning_text = "빙판 발생!"
    weather_warning_timer = 180

    print(f"[Weather] Forced ice start! Duration: {weather_event_remaining_rounds}")


def force_start_rain_event(duration=None):
    """Force start a rain event for testing"""
    global weather_event_active, weather_event_type, weather_event_direction
    global weather_event_remaining_rounds, weather_event_just_started
    global weather_warning_timer, weather_warning_text
    global rain_initialized

    weather_event_active = True
    weather_event_type = "rain"
    weather_event_direction = 0
    weather_event_remaining_rounds = duration if duration else random.randint(2, 3)
    weather_event_just_started = True
    weather_warning_text = "소나기 발생!"
    weather_warning_timer = 180
    rain_initialized = False  # 빗방울 다시 초기화

    # 소나기 사운드 재생
    play_weather_sound("rain")

    print(f"[Weather] Forced rain start! Duration: {weather_event_remaining_rounds}")


def force_start_hail_event(duration=None):
    """Force start a hail event for testing"""
    global weather_event_active, weather_event_type, weather_event_direction
    global weather_event_remaining_rounds, weather_event_just_started
    global weather_warning_timer, weather_warning_text
    global hail_initialized

    weather_event_active = True
    weather_event_type = "hail"
    weather_event_direction = 0
    weather_event_remaining_rounds = duration if duration else random.randint(2, 3)
    weather_event_just_started = True
    weather_warning_text = "우박 발생!"
    weather_warning_timer = 180
    hail_initialized = False  # 우박 다시 초기화

    # 우박 사운드 재생 (소나기 사운드 재사용)
    play_weather_sound("rain")

    print(f"[Weather] Forced hail start! Duration: {weather_event_remaining_rounds}")
