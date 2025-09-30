"""
get_final_boss_config 함수 - bosspong.py에서 추출
"""

import pygame
import math
import random
import items
from rendering.surface_cache import create_cached_surface
# from config.constants import BOSS_CONFIGS, TIMERS
# from config.game_settings import BALL_BASE_SPEED

def get_final_boss_config(stage, league_mode):
    """🏆 통합 보스 설정: 스테이지별 + 리그별 완전 연계"""
    # 임시 기본값 반환
    return {
        "accel": 0.798,
        "decel": 0.798,
        "max_speed": 6.3175,
        "instant_stop": 0.665,
        "predict_chance": 0.5,
        "predict_error": 90,
        "fail_chance": 0.01,
        "fail_error": 60
    }

# AI 성능 추적
ai_performance_stats = {
    "total_decisions": 0,
    "successful_hits": 0,
    "missed_balls": 0,
    "confidence_history": [],
    "learning_progress": 0.0
}

# AI 프레임 카운터 (Neural/Hybrid 모드용)
ai_frame_counter = 0

# 🏆 플레이어 실력 분석 시스템

# 플레이어 분석기 인스턴스
player_analyzer = None
skill_display_enabled = True
last_skill_update_time = 0

# 🎮 플레이어 설정

PLAYER_SPEED = 1                     # 플레이어 기본 이동 속도

# 🌊 기타 게임 효과

original_ball_speed_quake = [0, 0]   # 정글지진용 공 속도 백업

# 터렛 시스템 변수
turret_angles = {}  # 각 터렛의 현재 각도
turret_missiles = []  # 발사된 미사일 리스트
last_missile_time = 0  # 마지막 미사일 발사 시간

# 레이저 캐논 시스템 변수
laser_cannon_active = False  # 레이저 발사 중인지
last_laser_time = 0  # 마지막 레이저 발사 시간
laser_charging = False  # 레이저 충전 중인지
laser_charge_start = 0  # 충전 시작 시간
laser_beam_duration = 1500  # 레이저 지속 시간 (1.5초)
player_stunned = False  # 플레이어 감전 상태
player_stun_end_time = 0  # 감전 종료 시간
laser_cannon_angle = 90  # 레이저 캐논 현재 각도 (기본 6시 방향)
laser_target_angle = 90  # 레이저 캐논 목표 각도
laser_rotating_mode = False  # 레이저 회전 모드 (등대 모드)
laser_rotation_direction = 1  # 레이저 회전 방향 (1: 시계방향, -1: 반시계방향)
laser_cooldown = 5000  # 레이저 쿨타임 (5~9초 랜덤)
laser_rotation_range = 60  # 레이저 회전 범위 (랜덤으로 설정됨)
laser_rotation_speed = 1.0  # 레이저 회전 속도 배율 (랜덤으로 설정됨)

# 쉴드 안테나 시스템 변수
shield_antenna_active = False  # 쉴드 활성화 여부
shield_antenna_timer = 0  # 쉴드 타이머
shield_antenna_cooldown = random.randint(10000, 15000)  # 10~15초 쿨다운
last_shield_time = 0  # 마지막 쉴드 생성 시간
shield_duration = 3000  # 쉴드 지속 시간 (3초)
shield_fade_alpha = 255  # 쉴드 페이드 알파값
shield_position = 'center'  # 쉴드 위치 ('left', 'center', 'right')

# 인터셉터 시스템 변수 (스타크래프트 캐리어 스타일)
interceptors = []  # 활성화된 인터셉터 리스트
interceptor_launch_time = 0  # 마지막 인터셉터 출격 시간
interceptor_cooldown = random.randint(10000, 12000)  # 10~12초 쿨다운
interceptor_launching = False  # 인터셉터 출격 중인지
interceptor_launch_queue = []  # 출격 대기 중인 인터셉터
hangar_door_open = False  # 격납고 문 열림 상태
hangar_door_timer = 0  # 격납고 문 애니메이션 타이머

# 미사일 무적 시간
player_missile_invulnerable_time = 0  # 미사일 무적 종료 시간

# 미사일 넉백 시스템 (스테이지 5 화염탄과 동일)
player_missile_knockback_vel = 0  # 미사일 넉백 속도
player_missile_stunned_timer = 0  # 미사일 스턴 타이머

# 스테이지 6 보스 피격 효과 (소닉 스타일)
stage6_boss_hit_timer = 0  # 보스 피격 타이머 (깜빡임 지속 시간)
stage6_boss_hit_flash = False  # 보스 피격 깜빡임 상태

# 📦 아이템 시스템

# 액티브 아이템
active_item_slot = []                # 리스트로 바꿔서 최대 3개 보관
selected_item_index = 0              # 현재 선택 중인 아이템 인덱스
MAX_ITEM_SLOTS = 2                   # 최대 아이템 슬롯 수
active_item_icon_size = (28, 28)     # 화면에 표시할 크기
last_item_use_time = 0               # 마지막 아이템 사용 시간 (전역 쿨타임용)

# 패시브 아이템
selected_passive_item = -1           # 패시브 아이템 선택 인덱스

# 전역변수
speech_text = ""
speech_timer = 0  # 말풍선 표시 시간 (타이머)

# === Stage 5 화염탄 전역 변수 ===
fireballs = []  # [(pos, vel), ...] 여러 발의 화염탄을 관리

fireball_cooldown = 5000      # ms 단위 쿨타임
fireball_last_cast = 0        # 마지막 발사 시각
fireball_speed = 15           # 화염탄 발사 속도
round_start_time = 0          # 라운드 시작 시간 (화염탄 2.5초 지연용)

boss_throwing = False         # 보스 던지는 모션 여부
boss_throw_timer = 0          # 보스 던지는 모션 지속 시간 (프레임 단위)

# === Stage 4 자기장 관련 ===
magnet_curve_angle = 0

# === Stage 5 홍련 전용 게이지 ===
hongryeon_gauge = 0
hongryeon_gauge_max = 500

# === Stage 3 눈물샤워 관련 ===
tear_shower_active = False
tear_shower_timer = 0
tear_particles = []  # 💧 파티클 리스트

# fireball_img = pygame.Surface((40, 40), pygame.SRCALPHA)
# pygame.draw.circle(fireball_img, (255, 80, 0), (20, 20), 20)  # 화염탄 예비 이미지

# 아이템 아이콘 로드
# # # gauge_200_icon = pygame.image.load("items/gauge_200.png").convert_alpha()  # 함수 내부로 이동 필요
# # gauge_200_icon = pygame.transform.scale(gauge_200_icon, (32, 32))

# 게이지 충전 아이콘 로드
try:
    pass  # 빈 try 블록 수정
#     gauge_charge_icon = pygame.image.load("items/gauge_200.png").convert_alpha()
#     gauge_charge_icon = pygame.transform.scale(gauge_charge_icon, (32, 32))
except:
    # 사이버펑크 스타일 게이지 충전 아이콘
    gauge_charge_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 에너지 링
    for i in range(3):
        size = 14 - i * 3
        alpha = 255 - i * 60
        pygame.draw.circle(gauge_charge_icon, (255, 0, 255, alpha), (16, 16), size, 2)
    # 번개 모양
    points = [(16, 6), (20, 16), (18, 16), (16, 26), (14, 16), (12, 16)]
    pygame.draw.polygon(gauge_charge_icon, (255, 100, 255), points)
    pygame.draw.polygon(gauge_charge_icon, (255, 255, 255), points, 1)

# 스피드부츠 아이콘 로드
try:
    pass  # Empty try block fix
# #     speedboots_icon = pygame.image.load("items/speedboots.png").convert_alpha()
#     speedboots_icon = pygame.transform.scale(speedboots_icon, (32, 32))
except:
    # 사이버펑크 스타일 스피드부츠 아이콘
    speedboots_icon = create_cached_surface((32, 32), transparent=True)
    # 부츠 모양
    pygame.draw.polygon(speedboots_icon, (0, 255, 200), [(8, 20), (24, 20), (22, 12), (10, 12)])
    pygame.draw.polygon(speedboots_icon, (0, 200, 150), [(8, 20), (24, 20), (22, 12), (10, 12)], 2)
    # 속도 라인
    for i in range(3):
        y = 14 + i * 2
        pygame.draw.line(speedboots_icon, (255, 255, 0, 200-i*50), (4-i*2, y), (8, y), 2)

# 무중력벨트 아이콘 로드
try:
    pass  # Empty try block fix
# #     gravitybelt_icon = pygame.image.load("gravitybelt.png").convert_alpha()
#     gravitybelt_icon = pygame.transform.scale(gravitybelt_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    gravitybelt_icon = create_cached_surface((32, 32), transparent=True)
    pygame.draw.rect(gravitybelt_icon, (100, 100, 255), (8, 8, 16, 16))  # 파란색 벨트 모양
    pygame.draw.rect(gravitybelt_icon, (255, 255, 255), (10, 10, 12, 12), 2)  # 흰색 테두리

# 스피드기어 아이콘 로드
try:
    pass  # Empty try block fix
# #     speedgear_icon = pygame.image.load("items/speedgear.png").convert_alpha()
#     speedgear_icon = pygame.transform.scale(speedgear_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    speedgear_icon = create_cached_surface((32, 32), transparent=True)
    pygame.draw.circle(speedgear_icon, (255, 150, 0), (16, 16), 12)  # 주황색 기어 외곽
    pygame.draw.circle(speedgear_icon, (255, 255, 255), (16, 16), 8)  # 흰색 기어 내부
    pygame.draw.circle(speedgear_icon, (255, 150, 0), (16, 16), 4)  # 주황색 기어 중심

# AI 필 아이콘 로드
try:
    pass  # Empty try block fix
# #     aipill_icon = pygame.image.load("items/aipill.png").convert_alpha()
#     aipill_icon = pygame.transform.scale(aipill_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    aipill_icon = create_cached_surface((32, 32), transparent=True)
    pygame.draw.circle(aipill_icon, (100, 200, 255), (16, 16), 12)  # 하늘색 알약 외곽
    pygame.draw.circle(aipill_icon, (255, 255, 255), (16, 16), 8)   # 흰색 알약 내부
    pygame.draw.rect(aipill_icon, (100, 200, 255), (12, 8, 8, 16))  # 하늘색 AI 표시

# 부활 아이콘 로드
try:
    pass  # Empty try block fix
# #     revival_icon = pygame.image.load("items/revival.png").convert_alpha()
#     revival_icon = pygame.transform.scale(revival_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    revival_icon = create_cached_surface((32, 32), transparent=True)
    pygame.draw.circle(revival_icon, (255, 0, 255), (16, 16), 12)  # 마젠타색 외곽
    pygame.draw.circle(revival_icon, (255, 255, 255), (16, 16), 8)  # 흰색 내부
    pygame.draw.circle(revival_icon, (255, 0, 255), (16, 16), 4)   # 마젠타색 중심

# 장인 아이콘 로드
try:
    pass  # Empty try block fix
# #     master_icon = pygame.image.load("items/master.png").convert_alpha()
#     master_icon = pygame.transform.scale(master_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    master_icon = create_cached_surface((32, 32), transparent=True)
    pygame.draw.circle(master_icon, (255, 215, 0), (16, 16), 12)  # 금색 외곽
    pygame.draw.circle(master_icon, (255, 255, 255), (16, 16), 8)  # 흰색 내부
    pygame.draw.circle(master_icon, (255, 215, 0), (16, 16), 4)   # 금색 중심

# 쿨타임 아이콘 로드
try:
    pass  # Empty try block fix
# #     cooltime_icon = pygame.image.load("items/coolingball.png").convert_alpha()
#     cooltime_icon = pygame.transform.scale(cooltime_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    cooltime_icon = create_cached_surface((32, 32), transparent=True)
    pygame.draw.circle(cooltime_icon, (0, 255, 255), (16, 16), 12)  # 시안색 외곽
    pygame.draw.circle(cooltime_icon, (255, 255, 255), (16, 16), 8)  # 흰색 내부
    pygame.draw.circle(cooltime_icon, (0, 255, 255), (16, 16), 4)   # 시안색 중심

# 🌈 생명수 아이콘 생성 (무지개빛 포션)
try:
    pass  # Empty try block fix
# #     life_elixir_icon = pygame.image.load("items/life_elixir.png").convert_alpha()
#     life_elixir_icon = pygame.transform.scale(life_elixir_icon, (32, 32))
except:
    # 무지개빛 포션 아이콘 생성
    life_elixir_icon = create_cached_surface((32, 32), transparent=True)
    
    # 포션 병 모양 (둥근 바닥)
    # 병 몸통
    pygame.draw.ellipse(life_elixir_icon, (60, 60, 80, 200), (8, 12, 16, 18))
    pygame.draw.ellipse(life_elixir_icon, (80, 80, 100, 180), (9, 13, 14, 16))
    
    # 병 목
    pygame.draw.rect(life_elixir_icon, (60, 60, 80, 200), (13, 8, 6, 6))
    pygame.draw.rect(life_elixir_icon, (80, 80, 100, 180), (14, 9, 4, 5))
    
    # 코르크 마개
    pygame.draw.rect(life_elixir_icon, (139, 69, 19, 255), (12, 6, 8, 4))
    pygame.draw.rect(life_elixir_icon, (160, 82, 45, 255), (13, 7, 6, 2))
    
    # 무지개빛 액체 (그라데이션 효과)
    rainbow_colors = [
        (255, 0, 0),      # 빨강
        (255, 127, 0),    # 주황
        (255, 255, 0),    # 노랑
        (0, 255, 0),      # 초록
        (0, 127, 255),    # 하늘
        (0, 0, 255),      # 파랑
        (127, 0, 255),    # 보라
    ]
    
    # 액체 층별로 그리기
    for i, color in enumerate(rainbow_colors):
        y_pos = 15 + i * 2
        if y_pos < 28:  # 병 안에만 그리기
            pass
            # 반투명 무지개 액체
            liquid_color = (*color, 150)
            pygame.draw.ellipse(life_elixir_icon, liquid_color, 
                              (10, y_pos, 12, 3))
    
    # 반짝임 효과
    pygame.draw.circle(life_elixir_icon, (255, 255, 255, 200), (12, 16), 2)
    pygame.draw.circle(life_elixir_icon, (255, 255, 255, 150), (19, 20), 1)
    
    # 병 하이라이트
    pygame.draw.arc(life_elixir_icon, (255, 255, 255, 100), 
                    (8, 12, 16, 18), math.radians(200), math.radians(250), 2)

# 충전가방 아이콘 로드
try:
    pass  # Empty try block fix
# #     chargebag_icon = pygame.image.load("items/chargebag.png").convert_alpha()
#     chargebag_icon = pygame.transform.scale(chargebag_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    chargebag_icon = create_cached_surface((32, 32), transparent=True)
    pygame.draw.circle(chargebag_icon, (100, 255, 100), (16, 16), 12)  # 초록색 외곽
    pygame.draw.circle(chargebag_icon, (255, 255, 255), (16, 16), 8)  # 흰색 내부
    pygame.draw.circle(chargebag_icon, (100, 255, 100), (16, 16), 4)   # 초록색 중심

# 스파이크부츠 아이콘 로드
try:
    pass  # Empty try block fix
# #     spikeboots_icon = pygame.image.load("items/spikeboots.png").convert_alpha()
#     spikeboots_icon = pygame.transform.scale(spikeboots_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    spikeboots_icon = create_cached_surface((32, 32), transparent=True)
    pygame.draw.circle(spikeboots_icon, (255, 100, 255), (16, 16), 12)  # 마젠타색 외곽
    pygame.draw.circle(spikeboots_icon, (255, 255, 255), (16, 16), 8)  # 흰색 내부
    pygame.draw.circle(spikeboots_icon, (255, 100, 255), (16, 16), 4)   # 마젠타색 중심

# 대쉬기어 아이콘 로드
try:
    pass  # Empty try block fix
# #     dashgear_icon = pygame.image.load("items/dashgear.png").convert_alpha()
#     dashgear_icon = pygame.transform.scale(dashgear_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    dashgear_icon = create_cached_surface((32, 32), transparent=True)
    pygame.draw.circle(dashgear_icon, (100, 100, 255), (16, 16), 12)  # 파란색 외곽
    pygame.draw.circle(dashgear_icon, (255, 255, 255), (16, 16), 8)  # 흰색 내부
    pygame.draw.circle(dashgear_icon, (100, 100, 255), (16, 16), 4)   # 파란색 중심

# 벌크업 아이콘 로드
try:
    pass  # Empty try block fix
# #     bulkup_icon = pygame.image.load("items/bulkup.png").convert_alpha()
#     bulkup_icon = pygame.transform.scale(bulkup_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    bulkup_icon = create_cached_surface((32, 32), transparent=True)
    pygame.draw.circle(bulkup_icon, (255, 100, 100), (16, 16), 12)  # 빨간색 외곽
    pygame.draw.circle(bulkup_icon, (255, 255, 255), (16, 16), 8)  # 흰색 내부
    pygame.draw.circle(bulkup_icon, (255, 100, 100), (16, 16), 4)   # 빨간색 중심

# 감지센서 아이콘 로드
try:
    pass  # Empty try block fix
# #     sensor_icon = pygame.image.load("items/sensor.png").convert_alpha()
#     sensor_icon = pygame.transform.scale(sensor_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    sensor_icon = create_cached_surface((32, 32), transparent=True)
    pygame.draw.circle(sensor_icon, (150, 150, 255), (16, 16), 12)  # 연파란색 외곽
    pygame.draw.circle(sensor_icon, (255, 255, 255), (16, 16), 8)  # 흰색 내부
    pygame.draw.circle(sensor_icon, (150, 150, 255), (16, 16), 4)   # 연파란색 중심

# 대쉬홀더 아이콘 로드
try:
    pass  # Empty try block fix
# #     dashholder_icon = pygame.image.load("items/dashholder.png").convert_alpha()
#     dashholder_icon = pygame.transform.scale(dashholder_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    dashholder_icon = create_cached_surface((32, 32), transparent=True)
    pygame.draw.circle(dashholder_icon, (255, 150, 100), (16, 16), 12)  # 주황색 외곽
    pygame.draw.circle(dashholder_icon, (255, 255, 255), (16, 16), 8)  # 흰색 내부
    pygame.draw.circle(dashholder_icon, (255, 150, 100), (16, 16), 4)   # 주황색 중심

# ITEM_TYPES에 아이콘 할당 (아이콘이 정의된 경우만)
'''
for item in items.ITEM_TYPES:
    if item["name"] == "gauge_200":
        pass
        # item["icon"] = gauge_200_icon  # gauge_200_icon이 정의되지 않음
    elif item["name"] == "gauge_charge":
        pass
        item["icon"] = gauge_charge_icon
    elif item["name"] == "speedboots":
        pass
        item["icon"] = speedboots_icon
    elif item["name"] == "gravitybelt":
        pass
        item["icon"] = gravitybelt_icon
    elif item["name"] == "speedgear":
        pass
        item["icon"] = speedgear_icon
    elif item["name"] == "aipill":
        pass
        item["icon"] = aipill_icon
    elif item["name"] == "revival":
        pass
        item["icon"] = revival_icon
    elif item["name"] == "master":
        pass
        item["icon"] = master_icon
    elif item["name"] == "cooltime":
        item["icon"] = cooltime_icon

    elif item["name"] == "chargebag":
        pass
        item["icon"] = chargebag_icon
    elif item["name"] == "spikeboots":
        pass
        item["icon"] = spikeboots_icon
    elif item["name"] == "dashgear":
        pass
        item["icon"] = dashgear_icon
    elif item["name"] == "bulkup":
        pass
        item["icon"] = bulkup_icon
    elif item["name"] == "sensor":
        pass
        item["icon"] = sensor_icon
    elif item["name"] == "dashholder":
        pass
        item["icon"] = dashholder_icon
    elif item["name"] == "molotov":
        try:
            pass  # Empty try block fix
# #             item["icon"] = pygame.image.load("items/molotov.png").convert_alpha()
#             item["icon"] = pygame.transform.scale(item["icon"], (32, 32))
        except:
            # 화염병 기본 아이콘
            item["icon"] = create_cached_surface((32, 32), transparent=True)
            pygame.draw.circle(item["icon"], (255, 100, 0), (16, 16), 12)
    elif item["name"] == "grenade":
        try:
            pass  # Empty try block fix
# #             item["icon"] = pygame.image.load("items/grenade.png").convert_alpha()
#             item["icon"] = pygame.transform.scale(item["icon"], (32, 32))
        except:
            # 수류탄 기본 아이콘
            item["icon"] = create_cached_surface((32, 32), transparent=True)
            pygame.draw.circle(item["icon"], (80, 100, 80), (16, 16), 12)
            pygame.draw.rect(item["icon"], (60, 60, 60), (14, 8, 4, 6))
'''

# === 롱부스트 관련 ===
long_boost_active = False
long_boost_timer = 0
long_boost_scale = 1.0  # 현재 패들 크기 배율
long_boost_target_scale = 1.0  # 목표 패들 크기 배율
LONG_BOOST_DURATION = 360  # 6초 (60fps * 6)
LONG_BOOST_TRANSITION_TIME = 60  # 1초 동안 크기 변화

# === 배터리 관련 ===
battery_obtained = False  # 배터리 획득 여부

# === 부활 관련 ===
revival_obtained = False  # 부활 아이템 획득 여부
revival_used = False  # 부활 아이템 사용 여부

# === 장인 관련 ===
master_obtained = False  # 장인 아이템 획득 여부

# === 쿨타임 관련 ===
cooltime_obtained = False  # 쿨타임 아이템 획득 여부

# === 충전가방 관련 ===
chargebag_obtained = False  # 충전가방 아이템 획득 여부

# === 스파이크부츠 관련 ===
spikeboots_obtained = False  # 스파이크부츠 아이템 획득 여부

# === 대쉬기어 관련 ===
dashgear_obtained = False  # 대쉬기어 아이템 획득 여부

# === 벌크업 관련 ===
bulkup_obtained = False  # 벌크업 아이템 획득 여부

# === 대쉬홀더 관련 ===
dashholder_obtained = False  # 대쉬홀더 아이템 획득 여부
# 위험감지센서 관련 변수 (독립적 관리)
danger_sensor_obtained = False  # 위험감지센서 아이템 획득 여부
danger_sensor_enabled = True  # 위험감지센서 활성화 상태 (ON/OFF)
danger_sensor_auto_dash_cooldown = 0  # 자동 대쉬 쿨타임
sensor_obtained = False  # 센서 아이템 획득 여부 (호환성)
sensor_enabled = True  # 센서 활성화 상태 (호환성)
danger_sensor_last_auto_dash_time = 0  # 마지막 자동 대쉬 시간
is_danger_sensor_dash = False  # 위험감지센서로 발동된 대쉬인지 구분 플래그

# === 감지센서 관련 ===
sensor_auto_dash_cooldown = 0  # 자동 대쉬 쿨타임
sensor_last_auto_dash_time = 0  # 마지막 자동 대쉬 시간
boss_hit_timer = 0  # 보스가 공을 때린 후 경과 시간

# === 벽돌 관련 ===
walls = []  # 벽돌 리스트 [{"rect": pygame.Rect, "hit_count": int, "crack_level": int}]
wall_installing = False  # 벽돌 설치 중
wall_install_timer = 0  # 설치 타이머 (0.5초 = 30프레임)

# === 화염병 관련 ===
molotovs = []  # 던져진 화염병 리스트
fire_zones = []  # 화염 지대 리스트
wall_install_gauge_visible = False  # 설치 게이지 표시 여부
molotov_throwing = False  # 화염병 투척 모션 중
molotov_throw_timer = 0  # 투척 모션 타이머
molotov_target_x = 0  # 화염병 목표 X 좌표
molotov_target_y = 0  # 화염병 목표 Y 좌표

# === 수류탄 관련 ===
grenades = []  # 던져진 수류탄 리스트
explosion_zones = []  # 폭발 지역 리스트
grenade_throwing = False  # 수류탄 투척 모션 중
grenade_throw_timer = 0  # 투척 모션 타이머
grenade_target_x = 0  # 수류탄 목표 X 좌표
grenade_target_y = 0  # 수류탄 목표 Y 좌표

# === 조명탄 관련 ===
flares = []  # 던져진 조명탄 리스트
flare_zones = []  # 조명 지역 리스트
flare_throwing = False  # 조명탄 투척 모션 중
flare_throw_timer = 0  # 투척 모션 타이머
flare_target_x = 0  # 조명탄 목표 X 좌표
flare_target_y = 0  # 조명탄 목표 Y 좌표
boss_confused_timer = 0  # 보스 혼란 타이머 (조명탄 효과)

# === 연막탄 관련 ===
smoke_grenades = []  # 던져진 연막탄 리스트
smoke_zones = []  # 연막 지역 리스트
smoke_grenade_target_x = 0  # 연막탄 목표 X 좌표
smoke_grenade_target_y = 0  # 연막탄 목표 Y 좌표

# 보스별 스피드 및 예측 설정 - config에서 가져온 값에 추가 설정
# BOSS_CONFIGS에서 기본값을 가져오고 추가 속성만 정의
boss_speed_config = {}
'''
for stage_num in range(1, 6):
    if stage_num in BOSS_CONFIGS:
        boss_speed_config[stage_num] = {
            "accel": BOSS_CONFIGS[stage_num]["accel"],
            "decel": BOSS_CONFIGS[stage_num]["decel"],
            "max_speed": BOSS_CONFIGS[stage_num]["max_speed"],
            "instant_stop": BOSS_CONFIGS[stage_num]["instant_stop"],
            # AI 추가 설정
            "predict_chance": 0.45 + (stage_num - 1) * 0.05,  # 스테이지별 증가
            "predict_error": 95 - (stage_num - 1) * 5,        # 스테이지별 감소
            "fail_chance": 0.010 - (stage_num - 1) * 0.001,   # 스테이지별 감소
            "fail_error": BOSS_CONFIGS[stage_num]["fail_error"],
        }
'''

# 보스 기본 속도 설정값 (초기값 저장용)
BOSS_ACCELERATION_DEFAULT = 0.798       # 35% 감소: 1.2 → 0.798
BOSS_DECELERATION_DEFAULT = 0.798       # 35% 감소: 1.2 → 0.798
BOSS_MAX_SPEED_DEFAULT = 6.3175         # 35% 감소: 9.5 → 6.3175
BOSS_INSTANT_STOP_DECELERATION_DEFAULT = 0.665  # 35% 감소: 1 → 0.665

# 기본 적용 값
BOSS_ACCELERATION = BOSS_ACCELERATION_DEFAULT
BOSS_DECELERATION = BOSS_DECELERATION_DEFAULT
BOSS_MAX_SPEED = BOSS_MAX_SPEED_DEFAULT
BOSS_INSTANT_STOP_DECELERATION = BOSS_INSTANT_STOP_DECELERATION_DEFAULT

# CURRENT_BG = STAGE1_BG  # 기본값 - STAGE1_BG가 정의되지 않음

quake_last_used_time = -9999  # 마지막 정글지진 발동 시간
QUAKE_COOLDOWN = 4000         # 쿨타임: 7000ms (7초 예시)

horizontal_bounce_count = 0

boss_trail = []  # [(x, y, alpha)] 형식의 튜플 리스트

long_boost_growing = False
long_boost_shrinking = False

BALL_BASE_SPEED = 9  # 기본값
player_last_shot_speed = BALL_BASE_SPEED  # 기본 속도로 초기화

round_wins = 0
round_losses = 0
win_goal = 3  # 기본 승리 목표점수

# 핑파이터 스타일 듀스 시스템
deuce_mode = False  # 듀스 모드 상태
deuce_goal = 4  # 듀스에서의 승리 목표점수 (4점)
deuce_wins = 0  # 듀스에서의 플레이어 점수
deuce_losses = 0  # 듀스에서의 보스 점수

is_player_serve = True
is_waiting_for_serve = True
waiting_start_time = 0
wait_delay = 0

# === 일시정지 시스템 ===
game_paused = False  # 게임 일시정지 상태

boss_fake_move = False
boss_fake_start_time = 0
boss_fake_duration = 2000
boss_fake_during_player_serve = False

speed_defense_active = False
speed_defense_cooldown = 5000  # TIMERS["speed_defense_cooldown"]  # 데이터에서 가져오기
speed_defense_timer = 0

speed_defense_checked = False

original_speed = [0, 0]  # 암행트위스트 발동 전 속도 백업용

last_hit_time = 0  # 플레이어 마지막으로 맞은 시간

final_wave_direction = [0, 0]  # 공의 마지막 이동 방향 (X, Y)

# # PLAYER_IMG = pygame.image.load("ufo_player.png").convert_alpha()
# PLAYER_IMG = pygame.transform.scale(PLAYER_IMG, (250, 100))  # 세로 늘리기

boss_special_waiting = False
boss_special_timer = 0  # 이 변수도 같이 쓰이므로!

# UFO 확장 애니메이션 관련
long_boost_animating = False
long_boost_animation_step = 0
long_boost_animation_timer = 0

# 보스 이미지 크기 - config 오버라이드
BOSS_IMG_WIDTH = 160  # 기본값 오버라이드
BOSS_IMG_HEIGHT = 80

# 스테이지 4, 5 전용 사이즈
BOSS_IMG_STAGE4_WIDTH = 130
BOSS_IMG_STAGE4_HEIGHT = 70
BOSS_IMG_STAGE5_WIDTH = 130
BOSS_IMG_STAGE5_HEIGHT = 70

# 전역 변수 추가 (파일 위쪽에 위치)
whip_wave_phase = 0

# 🚀 가속화 스킬 관련 변수
acceleration_active = False  # 가속화 효과 활성 여부
acceleration_original_speed = [0, 0]  # 가속화 적용 전 원래 공속도

# 📍 타격 이펙트 관련 변수
impact_particles = []  # 타격 파티클 리스트 [x, y, vx, vy, size, alpha, color, life]
last_impact_strength = 0  # 마지막 타격 강도

# === 멘헤라걸 전용 붉어짐 효과 관련 전역 변수 ===
boss_red_intensity = 0  # 붉은 정도 (0 ~ 255)
boss_special_gauge = 0  # 보스 필살기 게이지
boss_special_ready = False

# 사이코볼
emotional_overdrive_active = False
emotional_overdrive_timer = 0

# === 대쉬 스피릿 레이저 시스템 ===
dash_spirit_lasers = []  # [(start_x, start_y, end_x, end_y, remaining_time, direction, electric_offset), ...]
DASH_SPIRIT_LASER_DURATION = 360  # 6초 (60fps 기준)
DASH_SPIRIT_LASER_WIDTH = 8  # 레이저 두께
DASH_SPIRIT_LASER_COLOR = (135, 206, 235)  # 하늘색 (SkyBlue)
DASH_SPIRIT_ELECTRIC_COLOR = (255, 255, 255)  # 전기 효과 (흰색)

long_boost_last_width = 166  # 기본 패들 크기
# long_boost_scaled_img = PLAYER_IMG.copy()  # PLAYER_IMG가 정의되지 않음

# === Stage 5 화염 궤적 스킬 관련 전역 ===
flame_trail_active = False
flame_trail_timer = 0
flame_trail_phase = 0
flame_trail_positions = []  # [(x, y)] 궤적 저장

# 패들 반짝임
overdrive_flash_timer = 0

# 잔상 저장
overdrive_trails = []

# 대쉬 잔상 효과
dash_afterimages = []  # [(x, y, alpha, image)]

psycho_bg_timer = 0

# === 멘헤라걸 스킬: 눈물의 비 관련 전역 변수 ===
tears_active = False
tears_timer = 0
falling_tears = []  # [(x, y, speed)] 리스트

last_tears_cast_time = -9999  # 마지막 눈물샤워 발동 시간
TEARS_COOLDOWN = 7000        # 쿨타임 (밀리초 단위 = 5초)

passive_item_list = []

try:
    pass  # Empty try block fix
# #     BOSS_IMG_STAGE1 = pygame.image.load("boss_stage1.png").convert_alpha()
#     BOSS_IMG_STAGE1 = pygame.transform.scale(BOSS_IMG_STAGE1, (BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT))
except:
    BOSS_IMG_STAGE1 = pygame.Surface((BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT), pygame.SRCALPHA)
    BOSS_IMG_STAGE1.fill((255, 255, 255))

try:
    pass  # Empty try block fix
# #     BOSS_IMG_STAGE2 = pygame.image.load("boss_stage2.png").convert_alpha()
#     BOSS_IMG_STAGE2 = pygame.transform.scale(BOSS_IMG_STAGE2, (BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT))
except:
    BOSS_IMG_STAGE2 = pygame.Surface((BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT), pygame.SRCALPHA)
    BOSS_IMG_STAGE2.fill((0, 255, 0))

try:
    pass  # Empty try block fix
# #     BOSS_IMG_STAGE3 = pygame.image.load("boss_stage3.png").convert_alpha()
#     BOSS_IMG_STAGE3 = pygame.transform.scale(BOSS_IMG_STAGE3, (BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT))
except:
    BOSS_IMG_STAGE3 = pygame.Surface((BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT), pygame.SRCALPHA)
    BOSS_IMG_STAGE3.fill((255, 0, 255))  # 보스 3의 기본 색상 (보라색 예시)

try:
    pass  # Empty try block fix
# #     BOSS_IMG_STAGE4 = pygame.image.load("boss_stage4.png").convert_alpha()
#     BOSS_IMG_STAGE4 = pygame.transform.scale(BOSS_IMG_STAGE4, (BOSS_IMG_STAGE4_WIDTH, BOSS_IMG_STAGE4_HEIGHT))
except:
    BOSS_IMG_STAGE4 = pygame.Surface((BOSS_IMG_STAGE4_WIDTH, BOSS_IMG_STAGE4_HEIGHT), pygame.SRCALPHA)
    BOSS_IMG_STAGE4.fill((200, 200, 150))

try:
    pass  # Empty try block fix
# #     BOSS_IMG_STAGE5 = pygame.image.load("boss_stage5.png").convert_alpha()
#     BOSS_IMG_STAGE5 = pygame.transform.scale(BOSS_IMG_STAGE5, (BOSS_IMG_STAGE5_WIDTH, BOSS_IMG_STAGE5_HEIGHT))
except:
    BOSS_IMG_STAGE5 = pygame.Surface((BOSS_IMG_STAGE5_WIDTH, BOSS_IMG_STAGE5_HEIGHT), pygame.SRCALPHA)
    BOSS_IMG_STAGE5.fill((255, 80, 0))

try:
    pass  # Empty try block fix
# #     SPEED_DEFENSE_IMG = pygame.image.load("boss_stage2_speed.png").convert_alpha()
#     SPEED_DEFENSE_IMG = pygame.transform.scale(SPEED_DEFENSE_IMG, (BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT))
except:
    SPEED_DEFENSE_IMG = pygame.Surface((BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT), pygame.SRCALPHA)
    SPEED_DEFENSE_IMG.fill((255, 0, 0))  # 디버깅용 붉은 사각형

try:
    pass  # Empty try block fix
# #     TEAR_IMG = pygame.image.load("tear_drop.png").convert_alpha()
#     TEAR_IMG = pygame.transform.scale(TEAR_IMG, (36, 36))  # 원하는 크기로 조정
except:
    TEAR_IMG = pygame.Surface((24, 24), pygame.SRCALPHA)
    pygame.draw.circle(TEAR_IMG, (0, 200, 255), (12, 12), 12)  # 예비용 원형 눈물

# BOSS_IMG = BOSS_IMG_STAGE1  # 기본값: Stage 1 보스 이미지 - BOSS_IMG_STAGE1이 정의되지 않음
# # BALL_IMG = pygame.image.load("ball.png").convert_alpha()
# BALL_IMG = pygame.transform.smoothscale(BALL_IMG, (36, 36))  # BALL_IMG가 정의되지 않음

hit_animation_active = False
hit_animation_timer = 0
HIT_ANIMATION_DURATION = 6  # 프레임 수

player_slow_timer = 0  # 눈물 디버프 지속 시간 (프레임 단위)

quake_offset_y = 0  # ← 전역 초기화 (draw_objects에서 사용)

# 화면 흔들림 오프셋 변수들
screen_shake_offset_x = 0
screen_shake_offset_y = 0
grenade_shake_timer = 0  # 수류탄 폭발 화면 흔들림 타이머

# Stage 2 특수 기술: 정글지진
quake_active = False
quake_duration = 80
quake_timer = 0

# 전역
flame_particles = []

# 별가루 파티클 시스템 (무중력벨트 + 스피드기어 시너지)
star_particles = []
star_particle_timer = 0
star_particle_spawn_rate = 3  # 3프레임마다 파티클 생성

# 목성 띠 애니메이션 (무중력벨트 + 스피드기어 시너지)
jupiter_ring_angle = 0  # 회전 각도
jupiter_ring_speed = 3  # 회전 속도
jupiter_ring_segments = 12  # 띠 세그먼트 개수

# 무중력벨트 + 스피드기어 시너지 효과
gravity_speed_synergy = False  # 시너지 활성화 여부
synergy_paddle_width_boost = 1.6  # 패들 가로길이 60% 증가

# draw 함수들을 rendering 모듈에서 가져옵니다 - 주석 처리 (모듈이 없음)
# draw_jupiter_ring = new_draw.draw_jupiter_ring
# draw_gradient_background = new_draw.draw_gradient_background  # 그라데이션 배경

# draw 헬퍼 함수들 임포트 - 주석 처리 (모듈이 없음)
# from rendering.draw_helpers import (
#     draw_outlined_circle, draw_glowing_circle, 
#     draw_transparent_rect, draw_shield_effect,
#     quick_circle, quick_rect, quick_line,
#     WHITE, BLACK, RED, GREEN, BLUE, YELLOW, CYAN
# )

# 객체 렌더러 임포트 - 주석 처리 (모듈이 없음)
# from rendering.object_renderer import get_renderer

# Surface 캐싱 시스템은 이미 임포트됨
