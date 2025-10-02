import os
import sys
import academy

def resource_path(relative_path):
    """PyInstaller 번들과 일반 실행 모두에서 작동하는 리소스 경로 반환"""
    try:
        # PyInstaller 번들인 경우
        base_path = sys._MEIPASS
    except Exception:
        # 일반 Python 실합인 경우
        base_path = os.path.dirname(os.path.abspath(__file__))
    
    return os.path.join(base_path, relative_path)

# -*- coding: utf-8 -*-
import pygame
import random
import math
 
# pingfighter.py에서 get_item_icon 함수 import
try:
    from pingfighter import get_item_icon
except ImportError:
    # import 실패 시 ITEM_ICONS에서 아이콘 찾기
    def get_item_icon(item_name):
        # ITEM_ICONS 딕셔너리에서 아이콘 반환
        if 'ITEM_ICONS' in globals() and item_name in ITEM_ICONS:
            return ITEM_ICONS[item_name]
        return None

ACTIVE_COOLDOWN_MS = 8000  # 8초 쿨타임

WIDTH, HEIGHT = 600, 750  # 화면 크기

# 연금술 텍스트 이펙트 폰트 캐시
_alchemy_font = None


def get_alchemy_font():
    global _alchemy_font
    if _alchemy_font is None:
        for candidate in ["NeoDunggeunmoPro.ttf", "NeoDGM.ttf", "NanumSquareB.ttf", "NanumSquareR.ttf"]:
            try:
                _alchemy_font = pygame.font.Font(resource_path(candidate), 18)
                break
            except Exception:
                _alchemy_font = None
        if _alchemy_font is None:
            _alchemy_font = pygame.font.Font(None, 18)
    return _alchemy_font

# 사운드 로드
try:
    SOUND_ITEM_GET = pygame.mixer.Sound("sounds/itemget.wav")
    SOUND_ITEM_GET.set_volume(0.5)  # 볼륨 조절 (0.0 ~ 1.0)
except:
    SOUND_ITEM_GET = None

LONG_BOOST_ICON = None  # 이미지 로딩은 main에서 처리됨

# 아이템 아이콘 dictionary
ITEM_ICONS = {}
# 전설 아이콘 애니메이션 프레임 캐시
ITEM_ICON_ANIMATIONS = {}
_ICON_ANIMATION_SCALE_CACHE = {}
_LEGENDARY_ICON_NAMES = {"ragnarok_hammer", "hermes_shoes", "poseidon_trident"}


def _render_legendary_icon_frames(item_name, target_size):
    """legendary_item.draw_icon을 사용해 지정 크기의 프레임을 생성"""

    try:
        from legendary_items import get_legendary_manager
    except Exception:
        return None

    legendary_manager = get_legendary_manager()
    legendary_item = None
    if legendary_manager:
        legendary_item = legendary_manager.get_item(item_name)
    if legendary_item is None:
        return None

    base_frames = ITEM_ICON_ANIMATIONS.get(item_name)
    if not base_frames:
        return None

    total_frames = len(base_frames)
    if total_frames == 0:
        return None

    original_frame = getattr(legendary_item, "current_frame", 0)
    original_counter = getattr(legendary_item, "frame_counter", 0)
    original_animation_time = getattr(legendary_item, "animation_time", 0.0)
    original_offset = getattr(legendary_item, "animation_offset", 0.0)

    rendered = []
    for idx in range(total_frames):
        legendary_item.current_frame = idx
        legendary_item.frame_counter = 0
        legendary_item.animation_time = idx / max(1, total_frames)
        legendary_item.animation_offset = 0
        frame_surface = pygame.Surface(target_size, pygame.SRCALPHA)
        legendary_item.draw_icon(frame_surface, 0, 0, target_size[0])
        rendered.append(frame_surface)

    legendary_item.current_frame = original_frame
    legendary_item.frame_counter = original_counter
    legendary_item.animation_time = original_animation_time
    legendary_item.animation_offset = original_offset

    return rendered


def get_item_icon_animation(item_name, size=None):
    """아이템 이름과 원하는 크기에 맞는 애니메이션 프레임 리스트를 반환"""

    frames = ITEM_ICON_ANIMATIONS.get(item_name)
    if not frames:
        return None

    if size is None:
        return frames

    if isinstance(size, int):
        target_size = (size, size)
    else:
        target_size = tuple(size)

    cache_key = (item_name, target_size)
    if cache_key in _ICON_ANIMATION_SCALE_CACHE:
        return _ICON_ANIMATION_SCALE_CACHE[cache_key]

    scaled_frames = []
    if item_name in _LEGENDARY_ICON_NAMES and frames and frames[0].get_size() != target_size:
        rendered_frames = _render_legendary_icon_frames(item_name, target_size)
        if rendered_frames:
            scaled_frames = rendered_frames
        else:
            for frame in frames:
                if frame.get_size() == target_size:
                    scaled_frames.append(frame.copy())
                else:
                    scaled_frames.append(pygame.transform.smoothscale(frame, target_size))
    else:
        for frame in frames:
            if frame.get_size() == target_size:
                scaled_frames.append(frame.copy())
            else:
                scaled_frames.append(pygame.transform.smoothscale(frame, target_size))

    _ICON_ANIMATION_SCALE_CACHE[cache_key] = scaled_frames
    return scaled_frames


def load_item_icons():
    """모든 아이템 아이콘을 로드하는 함수"""
    global ITEM_ICONS, LONG_BOOST_ICON
    print("Loading item icons...")

    ITEM_ICONS.clear()
    ITEM_ICON_ANIMATIONS.clear()
    _ICON_ANIMATION_SCALE_CACHE.clear()

    icon_files = {
        "long_boost": "long_boost_icon.png",
        "slot_add": "slot_add_icon.png",
        "gauge_charge": "gauge_200.png",
        "speedboots": "speedboots.png",
        "speedgear": "speedgear.png",
        "aipill": "aipill.png",
        "battery": "battery.png",
        "wall": "wall.png",
        "revival": "revival.png",
        "commando_arm": "commando_arm.png",
        "bulkup": "bulkup.png",
        "sensor": "sensor.png",
        "stopwatch": "stopwatch_icon.png",
        "flare": "flare.png",
        "master": "master.png",
        "chargebag": "chargebag.png",
        "pandora_box": "pandora_box.png",
        "dashgear": "dashgear.png",
        "dashholder": "dashholder.png",
        "spikeboots": "spikeboots.png",
        "dowsing_pendulum": "dowsing_pendulum.png",
        "fireball": "fireball.png",
        "coolingball": "coolingball.png",
        "gravitybelt": "gravitybelt.png",
        "grenade": "grenade.png",
        "molotov": "molotov.png",
        "smoke_grenade": "smoke_grenade.png",
        "devil_dice": "devil_dice.png",  # 😈 악마의 주사위 아이콘 추가
        "cooltime": "cooltime.png",  # 쿨타임 아이콘 추가  
        "life_elixir": "life_elixir.png",  # 생명수 아이콘
        "technical_vest": "technical_vest.png",  # 테크니컬조끼 아이콘
        "fuel_pouch": "fuel_pouch.png",  # 연료파우치 아이콘
        "bluetooth_ring": "bluetooth_ring.png",  # 블루투스링 아이콘
        "star_detector": "star_detector.png",  # 별탐지기 아이콘
        "foul_whistle": "foul_whistle.png",  # 반칙호루라기 아이콘
        "smartphone": "smartphone.png",  # 스마트폰 아이콘
        "bazooka": "bazooka.png",  # 바주카포 아이콘
        "ammo_box": "ammo_box.png",  # 탄약상자 아이콘
        "doping_potion": "doping_potion.png",  # 도핑물약 아이콘
        "net_gun": "net_gun.png",  # 그물덫총 아이콘
        "fire_support": "fire_support.png",  # 화력지원 아이콘
        "spider_mine": "spider_mine.png",  # 스파이더지뢰 아이콘
        "repair_kit": "repair_kit.png",  # 수리키트 아이콘
        # 전설 아이템(아이콘)
        "ragnarok_hammer": "legendary/ragnarok_hammer.png",
        "hermes_shoes": "legendary/hermes_shoes.png",
        "poseidon_trident": "legendary/poseidon_trident.png"
    }

    legendary_manager = None

    for item_name, icon_file in icon_files.items():
        if item_name == "poseidon_trident":
            try:
                if legendary_manager is None:
                    from legendary_items import get_legendary_manager  # 순환 의존성 방지용 지연 import
                    legendary_manager = get_legendary_manager()

                trident = legendary_manager.get_item("poseidon_trident") if legendary_manager else None
                icon_frames = getattr(trident, "icon_frames", None)

                if icon_frames:
                    copied_frames = [frame.copy() for frame in icon_frames if frame]
                    if copied_frames:
                        ITEM_ICON_ANIMATIONS[item_name] = copied_frames
                        ITEM_ICONS[item_name] = pygame.transform.smoothscale(copied_frames[0], (32, 32))
                        continue
            except Exception as exc:
                print(f"[WARN] Poseidon icon animation sync failed: {exc}")

        try:
            icon_path = resource_path(os.path.join("items", icon_file))
            icon = pygame.image.load(icon_path)
            icon = pygame.transform.scale(icon, (32, 32))  # 표준 크기로 조정
            ITEM_ICONS[item_name] = icon
            
            # LONG_BOOST_ICON도 설정
            if item_name == "long_boost":
                LONG_BOOST_ICON = icon
        except:
            # 아이콘 로드 실패 시 기본 Surface 생성
            icon = pygame.Surface((32, 32), pygame.SRCALPHA)
            pygame.draw.circle(icon, (200, 200, 200), (16, 16), 14)
            ITEM_ICONS[item_name] = icon
    
    # ITEM_TYPES 배열의 각 아이템에 아이콘 할당
    for item_type in ITEM_TYPES:
        item_name = item_type["name"]
        if item_name in ITEM_ICONS:
            item_type["icon"] = ITEM_ICONS[item_name]
        animations_32 = get_item_icon_animation(item_name, (32, 32))
        if animations_32:
            item_type["icon_animation_frames"] = animations_32

    print(f"Item icons loaded")


ITEM_TYPES = [
    {
        "name": "long_boost",
        "color": (100, 200, 255),
        "effect": "long_boost",
        "icon": None,
        "chance": 0.028,  # 30% 감소 (0.040 → 0.028)
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "slot_add",  # 🆕 새 아이템 추가
        "color": (255, 180, 80),
        "effect": "slot_add",
        "icon": None,
        "chance": 0.010,  # 확률 1.0%로 상향 (기존: 0.3%)
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "gauge_charge",  # 🆕 게이지 충전 아이템
        "color": (255, 100, 255),  # 보라색
        "effect": "gauge_charge",
        "icon": None,
        "chance": 0.042,  # 30% 감소 (0.060 → 0.042)
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "speedboots",  # 🆕 스피드부츠 아이템
        "color": (0, 255, 100),  # 초록색
        "effect": "speedboots",
        "icon": None,
        "chance": 0.005,  # 테스트용 높은 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "speedgear",  # 🆕 스피드기어 아이템
        "color": (255, 150, 0),  # 주황색
        "effect": "speedgear",
        "icon": None,
        "chance": 0.005,  # 테스트용 높은 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "aipill",  # 🆕 AI 필 아이템
        "color": (100, 200, 255),  # 하늘색
        "effect": "aipill",
        "icon": None,
        "chance": 0.006,  # 중간 확률
        "duration": 300,  # 5초 (60fps * 5)
        "unlock_condition": None
    },
    {
        "name": "battery",  # 🆕 배터리 아이템 (게이지 유지)
        "color": (255, 255, 0),  # 노란색
        "effect": "battery",
        "icon": None,
        "chance": 0.005,  # 중간 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "wall",  # 🆕 벽돌 설치 아이템
        "color": (139, 69, 19),  # 갈색
        "effect": "wall",
        "icon": None,
        "chance": 0.035,  # 중간 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "revival",  # 🆕 부활 아이템
        "color": (255, 0, 255),  # 마젠타색
        "effect": "revival",
        "icon": None,
        "chance": 0.005,  # 낮은 확률 (1번만 드롭)
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "master",  # 🆕 장인 아이템
        "color": (255, 215, 0),  # 금색
        "effect": "master",
        "icon": None,
        "chance": 0.005,  # 중간 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "cooltime",  # 🆕 쿨타임 아이템
        "color": (0, 255, 255),  # 시안색
        "effect": "cooltime",
        "icon": None,
        "chance": 0.005,  # 중간 확률
        "duration": 600,
        "unlock_condition": None
    },

    {
        "name": "chargebag",  # 🆕 충전가방 아이템
        "color": (100, 255, 100),  # 초록색
        "effect": "chargebag",
        "icon": None,
        "chance": 0.005,  # 중간 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "spikeboots",  # 🆕 스파이크부츠 아이템
        "color": (255, 100, 255),  # 마젠타색
        "effect": "spikeboots",
        "icon": None,
        "chance": 0.005,  # 중간 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "dashgear",  # 🆕 대쉬기어 아이템
        "color": (100, 100, 255),  # 파란색
        "effect": "dashgear",
        "icon": None,
        "chance": 0.005,  # 중간 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "bulkup",  # 🆕 벌크업 아이템 (패시브)
        "color": (255, 100, 100),  # 빨간색
        "effect": "bulkup",
        "icon": None,
        "chance": 0.005,  # 낮은 확률 (1회만 획득)
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "sensor",  # 🆕 감지센서 아이템 (패시브)
        "color": (150, 150, 255),  # 연파란색
        "effect": "sensor",
        "icon": None,
        "chance": 0.005,  # 중간 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "gravitybelt",  # 🆕 무중력벨트 아이템 (패시브)
        "color": (100, 100, 255),  # 파란색
        "effect": "gravitybelt",
        "icon": None,
        "chance": 0.002,  # 중간 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "dashholder",  # 🆕 대쉬홀더 아이템 (패시브)
        "color": (255, 150, 100),  # 주황색
        "effect": "dashholder",
        "icon": None,
        "chance": 0.008,  # 확률 0.8%로 상향 (기존: 0.5%)
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "dowsing_pendulum",  # 🧲 다우징팬들럼 아이템 (패시브)
        "color": (100, 150, 255),  # 하늘색
        "effect": "dowsing_pendulum",
        "icon": None,
        "chance": 0.005,  # 확률 1.2%
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "pandora_box",  # 🌈 판도라의 상자 액티브 아이템
        "color": (255, 0, 255),  # 무지개색 (마젠타로 표현)
        "effect": "pandora_box",
        "icon": None,
        "chance": 0.003,  # 확률 0.8%
        "duration": 180,  # 3초간 지속
        "unlock_condition": None
    },
    {
        "name": "molotov",  # 🔥 화염병 액티브 아이템
        "color": (255, 100, 0),  # 주황색
        "effect": "molotov",
        "icon": None,
        "chance": 0.015,  # 확률 조정 (2.0%)
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "grenade",  # 💣 수류탄 액티브 아이템
        "color": (80, 100, 80),  # 군용 녹색
        "effect": "grenade",
        "icon": None,
        "chance": 0.018,  # 확률 1.8%
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "spider_mine",  # 🕷️ 스파이더지뢰 액티브 아이템
        "color": (120, 90, 160),  # 보랏빛 금속톤
        "effect": "spider_mine",
        "icon": None,
        "chance": 0.007,  # 확률 1.2%
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "smartphone",  # 📱 스마트폰 패시브 아이템
        "color": (100, 150, 200),  # 스마트폰 블루
        "effect": "smartphone",
        "icon": None,
        "chance": 0.004,  # 확률 0.5%
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "flare",  # 💡 조명탄 액티브 아이템
        "color": (255, 255, 200),  # 밝은 노란색
        "effect": "flare",
        "icon": None,
        "chance": 0.020,  # 확률 2.0%
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "smoke_grenade",  # 💨 연막탄 액티브 아이템
        "color": (150, 150, 150),  # 회색
        "effect": "smoke_grenade",
        "icon": None,
        "chance": 0.018,  # 확률 1.8%
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "life_elixir",  # 🌈 생명수 액티브 아이템
        "color": (200, 100, 255),  # 무지개빛 보라색
        "effect": "life_elixir",
        "icon": None,
        "chance": 0.008,  # 확률 0.8% (희귀 아이템)
        "duration": 0,
        "unlock_condition": None
    },
    {
        "name": "repair_kit",  # 🛠️ 수리키트 액티브 아이템
        "color": (220, 210, 140),  # 황동빛 수리 상자
        "effect": "repair_kit",
        "icon": None,
        "chance": 0.004,  # 발토르 전용 희귀 아이템
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "stopwatch",  # ⏱️ 스탑워치 액티브 아이템
        "color": (180, 140, 90),  # 갈색 (시계 색상)
        "effect": "stopwatch",
        "icon": None,
        "chance": 0.006,  # 확률 1.5%
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "commando_arm",  # 💪 코만도암 패시브 아이템
        "color": (60, 60, 70),  # 다크 그레이 (군용 색상)
        "effect": "commando_arm",
        "icon": None,
        "chance": 0.008,  # 확률 1.2%
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "devil_dice",  # 😈 악마의 주사위 액티브 아이템
        "color": (139, 0, 0),  # 다크 레드 (악마의 색)
        "effect": "devil_dice",
        "icon": None,
        "chance": 0.002,  # 확률 1% (희귀 아이템)
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "technical_vest",  # 테크니컬조끼 패시브 아이템
        "color": (70, 130, 180),  # 스틸 블루 (조끼 색상)
        "effect": "technical_vest",
        "icon": None,
        "chance": 0.012,  # 확률 1.2%
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "fuel_pouch",  # 연료파우치 패시브 아이템
        "color": (180, 100, 40),  # 갈색 (가죽 파우치 색상)
        "effect": "fuel_pouch",
        "icon": None,
        "chance": 0.005,  # 
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "bluetooth_ring",  # 블루투스링 패시브 아이템
        "color": (100, 150, 255),  # 블루투스 블루 색상
        "effect": "bluetooth_ring",
        "icon": None,
        "chance": 0.03,  # 확률 1%
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "star_detector",  # 🌟 별탐지기 패시브 아이템
        "color": (80, 200, 220),  # 청록계열 하이라이트
        "effect": "star_detector",
        "icon": None,
        "chance": 0.004,  # 희귀 패시브 기본 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "foul_whistle",  # 반칙호루라기 패시브 아이템
        "color": (255, 235, 120),  # 심판의 경고등 색상
        "effect": "foul_whistle",
        "icon": None,
        "chance": 0.005,  # 기본 0.5% 확률
        "duration": 600,
        "unlock_condition": None
    },
    # 전설 아이템 (필드 스폰 가능)
    {
        "name": "ragnarok_hammer",  # 라그나로크 해머 전설 아이템
        "color": (255, 50, 50),  # 붉은색 (전설 색상)
        "effect": "ragnarok_hammer",
        "icon": None,
        "chance": 0.0008,  # 전설 아이템 1% 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "hermes_shoes",  # 헤르메스의 신발 전설 아이템
        "color": (100, 200, 255),  # 하늘색 (전설 색상)
        "effect": "hermes_shoes",
        "icon": None,
        "chance": 0.0008,  # 전설 아이템 1% 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "poseidon_trident",  # 포세이돈의 삼지창 전설 아이템
        "color": (50, 150, 255),  # 바다색 (전설 색상)
        "effect": "poseidon_trident",
        "icon": None,
        "chance": 0.0008,  # 테스트용 99% 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "knee_pads",  # 킥차져 패시브 아이템
        "color": (80, 80, 100),  # 어두운 회색-파란색
        "effect": "knee_pads",
        "icon": None,
        "chance": 0.005,  # 확률 1.0%
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "ammo_box",  # 📦 탄약상자 액티브 아이템 (물자보급 전용)
        "color": (139, 69, 19),  # 갈색 (탄약상자 색상)
        "effect": "ammo_box",
        "icon": None,
        "chance": 0,  # 확률 0% (물자보급에서만 획득 가능)
        "duration": 0,  # 즉시 사용형
        "unlock_condition": None
    },
    {
        "name": "fire_support",  # 화력지원 화기류 (물자보급 전용)
        "color": (255, 160, 70),
        "effect": "fire_support",
        "icon": None,
        "chance": 0.0,  # 필드 드롭 금지 (물자보급 전용)
        "duration": 0,
        "unlock_condition": None
    },
    {
        "name": "doping_potion",  # 도핑물약 액티브 아이템 (물자보급 전용)
        "color": (120, 220, 160),  # 연두색 계열 강화약
        "effect": "doping_potion",
        "icon": None,
        "chance": 0,
        "duration": 0,
        "unlock_condition": None
    }
]




try:
    UNKNOWN_ITEM_ICON = pygame.image.load(resource_path("items/unknown_item.png"))
    UNKNOWN_ITEM_ICON = pygame.transform.scale(UNKNOWN_ITEM_ICON, (60, 60))
except:
    UNKNOWN_ITEM_ICON = pygame.Surface((60, 60), pygame.SRCALPHA)
    pygame.draw.circle(UNKNOWN_ITEM_ICON, (200, 200, 200), (15, 15), 15)
    pygame.draw.line(UNKNOWN_ITEM_ICON, (0, 0, 0), (10, 10), (20, 20), 2)


slot_add_obtained = 0  # 획득한 개수 카운트
speedboots_obtained = False  # 스피드부츠 획득 여부
speedgear_obtained = False  # 스피드기어 획득 여부
battery_obtained = False  # 배터리 획득 여부
revival_obtained = False  # 부활 아이템 획득 여부
revival_used = False  # 부활 아이템 사용 여부
master_obtained = False  # 장인 아이템 획득 여부
cooltime_obtained = False  # 쿨타임 아이템 획득 여부

chargebag_obtained = False  # 충전가방 아이템 획득 여부
fuel_pouch_obtained = False  # 연료파우치 아이템 획득 여부
bluetooth_ring_obtained = False  # 블루투스링 아이템 획득 여부
star_detector_obtained = False  # 별탐지기 아이템 획득 여부
foul_whistle_obtained = False  # 반칙호루라기 아이템 획득 여부
spikeboots_obtained = False  # 스파이크부츠 아이템 획득 여부
dashgear_obtained = False  # 대쉬기어 아이템 획득 여부
bulkup_obtained = False  # 벌크업 아이템 획득 여부
sensor_obtained = False  # 감지센서 아이템 획득 여부
gravitybelt_obtained = False  # 무중력벨트 아이템 획득 여부
dashholder_obtained = False  # 대쉬홀더 아이템 획득 여부
commando_arm_obtained = False  # 코만도암 아이템 획득 여부
dowsing_pendulum_obtained = False  # 다우징팬들럼 아이템 획득 여부
technical_vest_obtained = False  # 테크니컬조끼 아이템 획득 여부

# 전설 아이템 획득 여부
ragnarok_hammer_obtained = False  # 라그나로크 해머 획득 여부
hermes_shoes_obtained = False  # 헤르메스의 신발 획득 여부
poseidon_trident_obtained = False  # 포세이돈의 삼지창 획득 여부
smartphone_obtained = False  # 스마트폰 아이템 획득 여부
knee_pads_obtained = False  # 무릎보호대 아이템 획득 여부


active_item_slot = None

# 해금 상태
unlocked_items = {
  
    "long_boost": True,
    "slot_add": True,
    "gauge_charge": True,
    "speedboots": True,
    "speedgear": True,
    "aipill": True,
    "battery": True,
    "wall": True,
    "revival": True,
    "master": True,
    "cooltime": True,

    "chargebag": True,
    "spikeboots": True,
    "dashgear": True,
    "bulkup": True,
    "sensor": True,
    "gravitybelt": True,
    "dashholder": True,
    "dowsing_pendulum": True,
    "molotov": True,
    "grenade": True,
    "spider_mine": True,
    "flare": True,
    "smoke_grenade": True,
    "pandora_box": True,
    "stopwatch": True,
    "commando_arm": True,
    "life_elixir": True,
    "repair_kit": True,
    "devil_dice": True,
    "technical_vest": True,
    "fuel_pouch": True,
    "bluetooth_ring": True,
    "star_detector": True,
    "foul_whistle": True,
    "smartphone": True,
    "ammo_box": True,
    "fire_support": True,
    "doping_potion": True,
    
    # 전설 아이템 해금 상태
    "ragnarok_hammer": True,
    "hermes_shoes": True,
    "poseidon_trident": True,
    
    # 패시브 아이템
    "knee_pads": True
    
}

# 현재 떠 있는 아이템 리스트
item_list = []

# 필드 아이템만 초기화하는 함수 (스테이지 전환용)
def clear_field_items():
    """필드에 스폰된 아이템만 제거 (물음표 아이콘 아이템들)"""
    global item_list
    item_list = []  # 필드 아이템 리스트 초기화
    print("")

# 아이템 초기화 함수
def reset_items():
    global active_item_slot, selected_item_index, MAX_ITEM_SLOTS
    global passive_item_list, item_list
    global items  # 아이템 모듈 (slot_add_obtained 카운트 리셋용)

    active_item_slot = []  # 엑티브 아이템 초기화
    selected_item_index = 0
    MAX_ITEM_SLOTS = 3  # 기본값으로 초기화
    passive_item_list = []  # 패시브 아이템 초기화
    item_list = []  # 필드 아이템도 초기화
    
    global slot_add_obtained, speedboots_obtained, speedgear_obtained, battery_obtained
    global revival_obtained, revival_used, master_obtained, cooltime_obtained
    global chargebag_obtained, fuel_pouch_obtained, bluetooth_ring_obtained, star_detector_obtained, foul_whistle_obtained
    global spikeboots_obtained, dashgear_obtained
    
    slot_add_obtained = 0  # slot_add 획득 카운트 초기화
    speedboots_obtained = False  # speedboots 획득 상태 초기화
    speedgear_obtained = False  # speedgear 획득 상태 초기화
    battery_obtained = False  # battery 획득 상태 초기화
    revival_obtained = False  # revival 획득 상태 초기화
    revival_used = False  # revival 사용 상태 초기화
    master_obtained = False  # master 획득 상태 초기화
    cooltime_obtained = False  # cooltime 획득 상태 초기화

    chargebag_obtained = False  # chargebag 획득 상태 초기화
    fuel_pouch_obtained = False  # fuel_pouch 획득 상태 초기화
    bluetooth_ring_obtained = False  # bluetooth_ring 획득 상태 초기화
    star_detector_obtained = False  # star_detector 획득 상태 초기화
    foul_whistle_obtained = False  # foul_whistle 획득 상태 초기화
    spikeboots_obtained = False  # spikeboots 획득 상태 초기화
    dashgear_obtained = False  # dashgear 획득 상태 초기화
    
    global bulkup_obtained, gravitybelt_obtained, dashholder_obtained, sensor_obtained
    bulkup_obtained = False  # bulkup 획득 상태 초기화
    gravitybelt_obtained = False  # gravitybelt 획득 상태 초기화
    dashholder_obtained = False  # dashholder 획득 상태 초기화
    sensor_obtained = False  # sensor 획득 상태 초기화
    
    global dowsing_pendulum_obtained, commando_arm_obtained, technical_vest_obtained
    dowsing_pendulum_obtained = False  # dowsing_pendulum 획득 상태 초기화
    commando_arm_obtained = False  # commando_arm 획득 상태 초기화
    technical_vest_obtained = False  # technical_vest 획득 상태 초기화
    
    # 전설 아이템 획득 상태는 게임 세션 동안 유지되므로 초기화하지 않음
    # (한 번 획득한 전설 아이템은 더 이상 필드에 나타나지 않도록 함)

    try:
        from item_effects.foul_whistle import get_foul_whistle_instance

        get_foul_whistle_instance().deactivate()
    except Exception:
        pass

    try:
        from item_effects.star_detector import deactivate_star_detector

        deactivate_star_detector()
    except Exception:
        pass

    try:
        from item_effects.fire_support import get_fire_support_instance

        get_fire_support_instance().reset_runtime()
    except Exception:
        pass


# 아이템 생성
def spawn_random_item():
    # 전역 변수 참조
    global ragnarok_hammer_obtained, poseidon_trident_obtained, foul_whistle_obtained
    
    # 디버그: 포세이돈 플래그 상태 출력
    print(f"[DEBUG spawn_random_item] poseidon_trident_obtained = {poseidon_trident_obtained}")
    
    # passive_item_list를 가져와서 이미 보유한 패시브 아이템 확인
    selected_character = None
    try:
        import pingfighter
        current_passive_items = [item["name"] for item in pingfighter.passive_item_list]
        selected_character = getattr(pingfighter, "selected_character_type", None)
        print(f"[DEBUG spawn_random_item] selected_character_type: {selected_character}")
        print(f"[DEBUG] Current passive items in inventory: {current_passive_items}")
    except Exception:
        current_passive_items = []
        selected_character = None
    
    # 현재 필드에 떠 있는 아이템들의 이름 목록 생성 (중복 방지)
    items_in_field = [item["type"]["name"] for item in item_list]
    print(f"[DEBUG] Items currently in field: {items_in_field}")
    
    # 스폰 가능한 아이템 목록 생성
    available_items = []
    
    for item in ITEM_TYPES:
        if not unlocked_items.get(item["name"], False):
            continue

        # 발토르 전용 수리키트는 타 캐릭터 플레이 시 스폰하지 않음
        if item["name"] == "repair_kit" and selected_character != "blacksmith":
            continue

        # slot_add 아이템은 2개 이상 먹었으면 스폰 안함
        if item["name"] == "slot_add" and slot_add_obtained >= 2:
            continue

        # speedboots 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "speedboots" and speedboots_obtained:
            continue

        # speedgear 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "speedgear" and speedgear_obtained:
            continue

        # battery 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "battery" and battery_obtained:
            continue

        # revival 아이템은 한 번 획득하거나 사용했으면 더 이상 스폰 안함
        if item["name"] == "revival" and (revival_obtained or revival_used):
            continue

        # master 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "master" and master_obtained:
            continue

        # cooltime 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "cooltime" and cooltime_obtained:
            continue

        # chargebag 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "chargebag" and chargebag_obtained:
            continue

        # spikeboots 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "spikeboots" and spikeboots_obtained:
            continue

        # dashgear 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "dashgear" and dashgear_obtained:
            continue

        # bulkup 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "bulkup" and bulkup_obtained:
            continue

        # dashholder 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "dashholder" and dashholder_obtained:
            continue

        # gravitybelt 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "gravitybelt" and gravitybelt_obtained:
            continue

        # sensor 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "sensor" and sensor_obtained:
            continue

        # dowsing_pendulum 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "dowsing_pendulum" and dowsing_pendulum_obtained:
            continue
        
        # commando_arm 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "commando_arm" and commando_arm_obtained:
            continue
        
        # technical_vest 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "technical_vest" and technical_vest_obtained:
            continue
        
        # fuel_pouch 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "fuel_pouch" and fuel_pouch_obtained:
            continue
        
        # bluetooth_ring 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "bluetooth_ring" and bluetooth_ring_obtained:
            continue

        # star_detector 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "star_detector" and star_detector_obtained:
            continue

        # 화력지원은 물자보급 전용이므로 필드에서는 절대 스폰하지 않음
        if item["name"] == "fire_support":
            continue

        # foul_whistle 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "foul_whistle" and foul_whistle_obtained:
            continue

        # knee_pads 아이템은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "knee_pads" and knee_pads_obtained:
            continue
        
        # 라그나로크 해머는 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "ragnarok_hammer" and ragnarok_hammer_obtained:
            continue
        
        # 헤르메스의 신발은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "hermes_shoes" and hermes_shoes_obtained:
            continue
        
        # 포세이돈의 삼지창은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "poseidon_trident":
            print(f"[DEBUG] Checking poseidon_trident: obtained = {poseidon_trident_obtained}")
            if poseidon_trident_obtained:
                print(f"[DEBUG] Skipping poseidon_trident spawn (already obtained)")
                continue
            else:
                print(f"[DEBUG] poseidon_trident can spawn (not obtained yet)")
        
        # 🚫 패시브 아이템 중복 방지 (chargebag 제외)
        # 이미 소지한 패시브 아이템은 더 이상 스폰하지 않음
        # chargebag은 중복 가능하므로 제외하고 체크
        
        # 이미 인벤토리에 있는 패시브 아이템인지 확인
        if item["name"] in current_passive_items and item["name"] != "chargebag":
            print(f"[DEBUG] Skipping {item['name']} - already in passive inventory")
            continue
        
        # 현재 필드에 떠 있는 아이템과 중복되는지 확인 (판도라의 상자 중복 방지)
        if item["name"] in items_in_field and item["name"] != "chargebag":
            print(f"[DEBUG] Skipping {item['name']} - already spawned in field")
            continue

        # 스폰 가능한 아이템을 목록에 추가 (확률 포함)
        available_items.append(item)
    
    # 스폰 가능한 아이템이 없으면 종료
    if not available_items:
        return
    
    # 확률에 따라 하나의 아이템만 선택하여 스폰
    # 스킬 효과 적용: 아이템 스폰 확률 증가
    import skill
    skill_spawn_boost = skill.apply_item_spawn_boost(1.0)  # 기본 확률 1.0에 스킬 효과 적용

    legendary_names = {"ragnarok_hammer", "hermes_shoes", "poseidon_trident"}
    try:
        legendary_multiplier = academy.get_treasure_map_field_multiplier()
    except Exception:
        legendary_multiplier = 1.0

    total_chance = 0.0
    for item in available_items:
        adjusted_chance = item["chance"] * skill_spawn_boost
        if item["name"] in legendary_names:
            adjusted_chance *= legendary_multiplier
        total_chance += adjusted_chance
    random_value = random.random() * total_chance

    current_chance = 0
    selected_item = None

    for item in available_items:
        adjusted_chance = item["chance"] * skill_spawn_boost
        if item["name"] in legendary_names:
            adjusted_chance *= legendary_multiplier
        current_chance += adjusted_chance  # 스킬 부스트 적용 수정
        if random_value <= current_chance:
            selected_item = item
            break
    
    # 선택된 아이템이 있으면 스폰
    if selected_item:
        x = WIDTH // 2
        y = HEIGHT // 2
        vel = [random.choice([-4, -3, 3, 4]), random.choice([-4, -3, 3, 4])]  # 기존보다 빠름

        # 아이템 타입 복사 후 revealed 속성 추가
        item_type_copy = selected_item.copy()
        item_type_copy["revealed"] = False  # 처음에는 공개되지 않은 상태

        new_item = {
            "x": x,
            "y": y,
            "vel": vel,
            "type": item_type_copy,
            "timer": selected_item["duration"],
            "bounce_count": 0,
            "max_bounces": random.randint(3, 6),
            "angle": 0  # 회전각도
        }
        item_list.append(new_item)
        
        # 라그나로크 해머가 스폰되면 애니메이션을 위해 인스턴스만 준비 (효과는 적용하지 않음)
        if selected_item["name"] == "ragnarok_hammer":
            from legendary_items import get_legendary_manager
            legendary_manager = get_legendary_manager()
            if legendary_manager:
                # 라그나로크 해머 인스턴스가 없으면 생성만 하고 activate는 하지 않음
                # 이렇게 하면 애니메이션은 가능하지만 효과는 적용되지 않음
                hammer = legendary_manager.get_item("ragnarok_hammer")
                if not hammer:
                    # 인스턴스가 없으면 초기화만 함 (activate 호출 안 함)
                    legendary_manager._init_legendary_items()
        
        # 헤르메스의 신발이 스폰되면 애니메이션을 위해 인스턴스만 준비 (효과는 적용하지 않음)
        if selected_item["name"] == "hermes_shoes":
            from legendary_items import get_legendary_manager
            legendary_manager = get_legendary_manager()
            if legendary_manager:
                # 헤르메스의 신발 인스턴스가 없으면 생성만 하고 activate는 하지 않음
                hermes = legendary_manager.get_item("hermes_shoes")
                if not hermes:
                    # 인스턴스가 없으면 초기화만 함 (activate 호출 안 함)
                    legendary_manager._init_legendary_items()
        
        # 포세이돈의 삼지창이 스폰되면 애니메이션을 위해 인스턴스만 준비 (효과는 적용하지 않음)
        if selected_item["name"] == "poseidon_trident":
            from legendary_items import get_legendary_manager
            legendary_manager = get_legendary_manager()
            if legendary_manager:
                # 포세이돈의 삼지창 인스턴스가 없으면 생성만 하고 activate는 하지 않음
                trident = legendary_manager.get_item("poseidon_trident")
                if not trident:
                    # 인스턴스가 없으면 초기화만 함 (activate 호출 안 함)
                    legendary_manager._init_legendary_items()

        # 신성 월계수도 동일하게 초기화만 수행해 아이콘 애니메이션이 가능하도록 함

def update_items(player_rect, apply_effect_func, store_passive_func=None, store_active_func=None, sound_item_get=None):
    global item_list
    new_items = []

    for item in item_list:
        # 위치 이동
        item["x"] += item["vel"][0]
        item["y"] += item["vel"][1]

        # 회전 각도 증가
        item["angle"] = (item["angle"] + 2) % 360

        # 벽에 부딪히면 튕기기 + 튕김 횟수 증가
        if item["x"] <= 0 or item["x"] >= WIDTH:
            item["vel"][0] *= -1
            item["bounce_count"] += 1
        if item["y"] <= 0 or item["y"] >= HEIGHT:
            item["vel"][1] *= -1
            item["bounce_count"] += 1

        # 아이템 충돌 판정
        item_rect = pygame.Rect(item["x"] - 15, item["y"] - 15, 30, 30)

        if item_rect.colliderect(player_rect):
            # 아이템 획득 시 revealed를 True로 설정
            item["type"]["revealed"] = True
            
            # 아이템 획득 사운드 재생 (외부에서 전달받은 사운드 사용)
            if sound_item_get:
                try:
                    sound_item_get.play()
                except Exception as e:
                    print(f"  : {e}")
            else:
                # 내부 사운드 시도
                if SOUND_ITEM_GET:
                    try:
                        SOUND_ITEM_GET.play()
                    except Exception as e:
                        print(f"   : {e}")
            
            item_name = item["type"]["name"]
            print(f"🔍 DEBUG: 아이템 획득 감지: {item_name}")
            # 패시브 아이템과 엑티브 아이템 구분
            if item_name in ["speedboots", "speedgear", "battery", "slot_add", "revival", "master", "cooltime", "chargebag", "spikeboots", "dashgear", "sensor", "bulkup", "dashholder", "gravitybelt", "dowsing_pendulum", "commando_arm", "technical_vest", "fuel_pouch", "bluetooth_ring", "star_detector", "foul_whistle", "smartphone", "knee_pads", "ragnarok_hammer", "hermes_shoes", "poseidon_trident"]:
                # 패시브 아이템 처리
                print(f"🔍 DEBUG: {item_name}을(를) 패시브 아이템으로 처리 중...")
                if store_passive_func:
                    item_data = {
                        "name": item_name,
                        "color": item["type"]["color"],
                        "effect": item_name,
                        "icon": None,  # 아이콘은 pingfighter.py의 store_passive_item에서 get_item_icon으로 설정됨
                        "x": item["x"],
                        "y": item["y"]
                    }
                    print(f"🔍 DEBUG: store_passive_func 호출 중... item_data: {item_data['name']}")
                    store_passive_func(item_data)
                    print(f"✅ DEBUG: {item_name} 패시브 아이템 처리 완료!")
                else:
                    print(f"❌ DEBUG: store_passive_func가 None입니다!")
            else:
                # 엑티브 아이템 처리 - store_active_item을 통해 슬롯에 저장
                if store_active_func:
                    item_data = {
                        "name": item_name,
                        "color": item["type"]["color"],
                        "effect": item_name,
                        "icon": None,  # 아이콘은 pingfighter.py의 store_active_item에서 get_item_icon으로 설정됨
                        "x": item["x"],
                        "y": item["y"]
                    }
                    store_active_func(item_data)
        else:
            if item["bounce_count"] < item["max_bounces"]:
                new_items.append(item)  # 남아있는 아이템만 리스트에 유지

    item_list = new_items  # 아이템 리스트 갱신







def draw_items(screen):
    for item in item_list:
        # revealed 속성 체크
        if not item["type"].get("revealed", True):
            # 아직 공개되지 않은 아이템은 물음표 아이콘 표시
            icon = UNKNOWN_ITEM_ICON
        else:
            # 전설 아이템인지 체크 (라그나로크 해머, 헤르메스의 신발 등)
            item_name = item["type"].get("name", "")
            if item_name == "ragnarok_hammer":
                # 라그나로크 해머는 전설 아이템 매니저를 통해 애니메이션 그리기
                from legendary_items import get_legendary_manager
                legendary_manager = get_legendary_manager()
                if legendary_manager:
                    hammer = legendary_manager.get_item("ragnarok_hammer")
                    if hammer:
                        # 애니메이션 업데이트 (밀리초 단위)
                        hammer.update(16)  # 60fps 기준 16ms
                        # 애니메이션 아이콘 그리기 (회전 없이)
                        hammer.draw_icon(screen, int(item["x"]) - 30, int(item["y"]) - 30, 60)
                        continue
            elif item_name == "hermes_shoes":
                # 헤르메스의 신발도 전설 아이템 매니저를 통해 애니메이션 그리기
                from legendary_items import get_legendary_manager
                legendary_manager = get_legendary_manager()
                if legendary_manager:
                    hermes = legendary_manager.get_item("hermes_shoes")
                    if hermes:
                        # 애니메이션 업데이트 (밀리초 단위)
                        hermes.update(16)  # 60fps 기준 16ms
                        # 애니메이션 아이콘 그리기 (회전 없이)
                        hermes.draw_icon(screen, int(item["x"]) - 30, int(item["y"]) - 30, 60)
                        continue
            elif item_name == "poseidon_trident":
                # 포세이돈의 삼지창도 전설 아이템 매니저를 통해 애니메이션 그리기
                from legendary_items import get_legendary_manager
                legendary_manager = get_legendary_manager()
                if legendary_manager:
                    trident = legendary_manager.get_item("poseidon_trident")
                    if trident:
                        # 애니메이션 업데이트 (밀리초 단위)
                        trident.update(16)  # 60fps 기준 16ms
                        # 애니메이션 아이콘 그리기 (회전 없이)
                        trident.draw_icon(screen, int(item["x"]) - 30, int(item["y"]) - 30, 60)
                        continue
            
            # 일반 아이템은 기존 방식대로 처리
            icon = item["type"].get("icon")
            if not icon:
                # 아이콘이 없으면 색상 원으로 표시
                pygame.draw.circle(screen, item["type"]["color"], (int(item["x"]), int(item["y"])), 20)
                continue
        
        if icon:
            angle = item.get("angle", 0)
            # ✅ 회전 후 강제로 크기 맞추기
            icon = pygame.transform.scale(icon, (60, 60))  # 다시 강제 스케일링
            rotated_icon = pygame.transform.rotate(icon, angle)
            rect = rotated_icon.get_rect(center=(int(item["x"]), int(item["y"])))
            screen.blit(rotated_icon, rect.topleft)







# 해금 조건 체크 함수
def check_item_unlock_conditions(current_stage, medal_score):
    for item in ITEM_TYPES:
        if unlocked_items.get(item["name"], False):
            continue
        cond = item.get("unlock_condition")
        if not cond:
            continue
        if cond["type"] == "stage_clear" and current_stage >= cond["stage"]:
            unlocked_items[item["name"]] = True
        elif cond["type"] == "medal" and medal_score >= cond["amount"]:
            unlocked_items[item["name"]] = True


# 아이템 아이콘을 화면에 그리기 위한 함수
# 이제 선택 인덱스를 받아서 강조 표시까지 지원

def draw_cooldown_overlay(screen, x, y, size, last_use_time, cooldown_ms):
    """엑티브 아이템 쿨타임 그림자 표시 (워크래프트 스타일 시계방향 부채꼴)"""
    now = pygame.time.get_ticks()
    elapsed = now - last_use_time
    
    # 쿨타임이 끝났거나 아직 시작되지 않았으면 그림자 안 그림
    if elapsed >= cooldown_ms or elapsed < 0:
        return

    # 남은 시간 비율 계산 (1.0 → 0.0)
    remaining_ratio = 1 - (elapsed / cooldown_ms)
    
    # 시계방향으로 감소하는 각도 (360도에서 시작해서 0도로)
    angle = 360 * remaining_ratio

    overlay = pygame.Surface((size, size), pygame.SRCALPHA)
    center = size // 2

    # 부채꼴 좌표 생성 (시계방향으로 감소)
    points = [(center, center)]
    
    # 0도부터 angle도까지 시계방향으로 그리기
    for a in range(int(angle) + 1):
        rad = math.radians(a)  # 시계방향 (양수)
        px = center + center * math.cos(rad)
        py = center + center * math.sin(rad)
        points.append((px, py))

    if len(points) > 2:
        pygame.draw.polygon(overlay, (0, 0, 0, 180), points)  # 더 진하게 (100 -> 180)

    screen.blit(overlay, (x, y))


def draw_active_item(screen, active_item_slot, icon_size, selected_index=0, cooldown_ms=10000, round_start_time=None, alchemy_notices=None):
    """엑티브 아이템 슬롯 + 쿨타임 표시 통합"""
    if not active_item_slot:
        return

    HEIGHT = 750
    slot_x = 10
    slot_y = HEIGHT - icon_size[1] - 10
    SLOT_W, SLOT_H = icon_size
    border_margin = 2  # 선택 테두리용
    
    # 라운드 시작 시간 체크 (투척류 아이템 5초 제한용)
    import pygame
    current_time = pygame.time.get_ticks()
    
    # round_start_time이 전달되지 않은 경우 충분한 시간이 지난 것으로 간주
    if round_start_time is None:
        time_since_round_start = 10000
    else:
        time_since_round_start = current_time - round_start_time

    # 리스트 형태(다중 슬롯)
    notice_font = get_alchemy_font() if alchemy_notices else None

    if isinstance(active_item_slot, list):
        for i, item in enumerate(active_item_slot):
            x = slot_x + i * (SLOT_W + 10)
            y = slot_y

            # 슬롯 배경
            pygame.draw.rect(screen, (0, 0, 0), (x, y, SLOT_W, SLOT_H))

            # item이 None인 경우 빈 슬롯으로 처리
            if item is None:
                continue

            # 아이콘 표시
            item_name = item.get("name") or item.get("effect")
            if item_name in _LEGENDARY_ICON_NAMES:
                try:
                    from legendary_items import get_legendary_manager
                    legendary_manager = get_legendary_manager()
                    legendary_item = legendary_manager.get_item(item_name) if legendary_manager else None
                except Exception:
                    legendary_item = None

                if legendary_item:
                    legendary_item.update(1 / 60.0, ui_mode=True)
                    legend_surface = pygame.Surface(icon_size, pygame.SRCALPHA)
                    legendary_item.draw_icon(legend_surface, 0, 0, icon_size[0])
                    screen.blit(legend_surface, (x, y))
                elif item.get("icon"):
                    icon = pygame.transform.scale(item["icon"], icon_size)
                    screen.blit(icon, (x, y))
                else:
                    radius = int(SLOT_W * 0.28)
                    center_x = x + SLOT_W // 2
                    center_y = y + SLOT_H // 2
                    pygame.draw.circle(screen, item["color"], (center_x, center_y), radius)
            elif "icon" in item and item["icon"]:
                icon = pygame.transform.scale(item["icon"], icon_size)
                screen.blit(icon, (x, y))
            else:
                radius = int(SLOT_W * 0.28)
                center_x = x + SLOT_W // 2
                center_y = y + SLOT_H // 2
                pygame.draw.circle(screen, item["color"], (center_x, center_y), radius)

            # ✅ 쿨타임 그림자 표시 (워크래프트3 스타일)
            if "last_use" in item:
                draw_cooldown_overlay(screen, x, y, SLOT_W, item["last_use"], cooldown_ms)
            
            # 🎯 투척류 아이템 5초 카운트다운 표시
            throwing_items = ["molotov", "grenade", "flare", "spider_mine"]
            item_name = item.get("name", item.get("effect", ""))
            if item_name in throwing_items and time_since_round_start < 5000:
                remaining_seconds = int((5000 - time_since_round_start) / 1000) + 1  # 5, 4, 3, 2, 1
                
                # 반투명 검은색 오버레이
                overlay = pygame.Surface((SLOT_W, SLOT_H))
                overlay.set_alpha(180)
                overlay.fill((0, 0, 0))
                screen.blit(overlay, (x, y))
                
                # 카운트다운 숫자 표시 (크고 굵게)
                try:
                    countdown_font = pygame.font.Font("NeoDGM.ttf", 32)
                except:
                    countdown_font = pygame.font.Font(None, 40)
                
                countdown_text = countdown_font.render(str(remaining_seconds), True, (255, 100, 100))
                text_rect = countdown_text.get_rect(center=(x + SLOT_W // 2, y + SLOT_H // 2))
                
                # 테두리 효과
                outline_text = countdown_font.render(str(remaining_seconds), True, (0, 0, 0))
                for dx, dy in [(-2, -2), (-2, 2), (2, -2), (2, 2)]:
                    outline_rect = outline_text.get_rect(center=(x + SLOT_W // 2 + dx, y + SLOT_H // 2 + dy))
                    screen.blit(outline_text, outline_rect)
                
                # 메인 숫자
                screen.blit(countdown_text, text_rect)

            # 선택 슬롯 강조
            if i == selected_index:
                pygame.draw.rect(screen, (255, 100, 100),
                                 (x - border_margin, y - border_margin,
                                  SLOT_W + border_margin * 2, SLOT_H + border_margin * 2), 3)
            
            # 🔢 숫자키 힌트 표시 (1~6) - 왼쪽 상단, 밝은 테두리 추가
            if i < 6:  # 최대 6개까지만 숫자키 지원
                try:
                    number_font = pygame.font.Font("NanumSquareB.ttf", 11)
                    # 흰색 텍스트에 검은 테두리
                    number_text = number_font.render(str(i + 1), True, (255, 255, 255))
                    
                    # 테두리 효과를 위한 검은색 텍스트
                    outline_text = number_font.render(str(i + 1), True, (0, 0, 0))
                    
                    # 테두리 그리기 (4방향)
                    for dx, dy in [(-1, -1), (-1, 1), (1, -1), (1, 1), (0, -1), (0, 1), (-1, 0), (1, 0)]:
                        screen.blit(outline_text, (x + 2 + dx, y + 1 + dy))
                    
                    # 메인 텍스트
                    screen.blit(number_text, (x + 2, y + 1))
                except:
                    # 폰트 로드 실패 시 기본 폰트 사용
                    number_font = pygame.font.Font(None, 16)
                    number_text = number_font.render(str(i + 1), True, (255, 255, 255))
                    screen.blit(number_text, (x + 2, y + 2))

            if alchemy_notices and notice_font:
                for notice in alchemy_notices:
                    if notice.get("slot_index") != i:
                        continue
                    duration = max(1, notice.get("duration", 1))
                    remaining = max(0, notice.get("timer", 0))
                    if remaining <= 0:
                        continue
                    ratio = remaining / duration
                    progress = 1.0 - ratio
                    alpha = int(220 * (ratio ** 0.9))
                    y_offset = -12 - progress * 18
                    text = "연금술!"
                    text_surface = notice_font.render(text, True, (190, 170, 255))
                    scale = 1.0 + 0.08 * math.sin(progress * math.pi)
                    if abs(scale - 1.0) > 0.01:
                        w = max(1, int(text_surface.get_width() * scale))
                        h = max(1, int(text_surface.get_height() * scale))
                        text_surface = pygame.transform.smoothscale(text_surface, (w, h))
                    text_surface.set_alpha(alpha)
                    text_rect = text_surface.get_rect(center=(x + SLOT_W // 2, y - 10 + y_offset))
                    glow_surface = pygame.Surface((text_rect.width + 10, text_rect.height + 6), pygame.SRCALPHA)
                    pygame.draw.ellipse(glow_surface, (190, 170, 255, int(alpha * 0.25)), glow_surface.get_rect())
                    screen.blit(glow_surface, (text_rect.x - 5, text_rect.y - 3))
                    shadow = notice_font.render(text, True, (0, 0, 0))
                    shadow = pygame.transform.smoothscale(shadow, text_surface.get_size())
                    shadow.set_alpha(int(alpha * 0.5))
                    screen.blit(shadow, (text_rect.x + 2, text_rect.y + 2))
                    screen.blit(text_surface, text_rect)
                    break
    else:
        # 단일 슬롯 처리
        x, y = slot_x, slot_y

        # 슬롯 배경
        pygame.draw.rect(screen, (0, 0, 0), (x, y, SLOT_W, SLOT_H))

        # active_item_slot이 None인 경우 처리
        if active_item_slot is None:
            return

        # 아이콘 표시
        if "icon" in active_item_slot and active_item_slot["icon"]:
            icon = pygame.transform.scale(active_item_slot["icon"], icon_size)
            screen.blit(icon, (x, y))
        else:
            radius = int(SLOT_W * 0.28)
            center_x = x + SLOT_W // 2
            center_y = y + SLOT_H // 2
            pygame.draw.circle(screen, active_item_slot["color"], (center_x, center_y), radius)

        # ✅ 쿨타임 그림자 표시 (워크래프트3 스타일)
        if "last_use" in active_item_slot:
            draw_cooldown_overlay(screen, x, y, SLOT_W, active_item_slot["last_use"], cooldown_ms)

        # 강조 테두리
        pygame.draw.rect(screen, (255, 100, 100),
                         (x - border_margin, y - border_margin,
                          SLOT_W + border_margin * 2, SLOT_H + border_margin * 2), 3)

        if alchemy_notices and notice_font:
            for notice in alchemy_notices:
                if notice.get("slot_index") != 0:
                    continue
                duration = max(1, notice.get("duration", 1))
                remaining = max(0, notice.get("timer", 0))
                if remaining <= 0:
                    continue
                ratio = remaining / duration
                progress = 1.0 - ratio
                alpha = int(220 * (ratio ** 0.9))
                y_offset = -12 - progress * 18
                text = "연금술!"
                text_surface = notice_font.render(text, True, (190, 170, 255))
                scale = 1.0 + 0.08 * math.sin(progress * math.pi)
                if abs(scale - 1.0) > 0.01:
                    w = max(1, int(text_surface.get_width() * scale))
                    h = max(1, int(text_surface.get_height() * scale))
                    text_surface = pygame.transform.smoothscale(text_surface, (w, h))
                text_surface.set_alpha(alpha)
                text_rect = text_surface.get_rect(center=(x + SLOT_W // 2, y - 10 + y_offset))
                glow_surface = pygame.Surface((text_rect.width + 10, text_rect.height + 6), pygame.SRCALPHA)
                pygame.draw.ellipse(glow_surface, (190, 170, 255, int(alpha * 0.25)), glow_surface.get_rect())
                screen.blit(glow_surface, (text_rect.x - 5, text_rect.y - 3))
                shadow = notice_font.render(text, True, (0, 0, 0))
                shadow = pygame.transform.smoothscale(shadow, text_surface.get_size())
                shadow.set_alpha(int(alpha * 0.5))
                screen.blit(shadow, (text_rect.x + 2, text_rect.y + 2))
                screen.blit(text_surface, text_rect)
                break
