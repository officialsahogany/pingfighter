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
# 필드 드랍 풀에서 엑티브/패시브 비중을 강제로 맞추기 위한 목표 비율
# (available_items를 구성한 뒤 가중치를 재조정해 엑티브 ≈ 75%, 패시브 ≈ 25%가 되도록 스케일한다)
TARGET_ACTIVE_DROP_SHARE = 0.75
TARGET_PASSIVE_DROP_SHARE = 0.25

WIDTH, HEIGHT = 600, 750  # 화면 크기

# 연금술 텍스트 이펙트 폰트 캐시
_alchemy_font = None


def get_alchemy_font():
    global _alchemy_font
    if _alchemy_font is None:
        # fonts/pixel/ 폴더의 네오둥근모 프로 우선 사용
        for candidate in [
            "PFStardust.ttf",
            "PFStardust.ttf",
            "NanumSquareB.ttf",
            "NanumSquareR.ttf"
        ]:
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
    SOUND_ITEM_GET = pygame.mixer.Sound(resource_path(os.path.join("sounds", "itemget.wav")))
    SOUND_ITEM_GET.set_volume(0.5)  # 볼륨 조절 (0.0 ~ 1.0)
except:
    SOUND_ITEM_GET = None

LONG_BOOST_ICON = None  # 이미지 로딩은 main에서 처리됨

# 아이템 아이콘 dictionary
ITEM_ICONS = {}
# 전설 아이콘 애니메이션 프레임 캐시
ITEM_ICON_ANIMATIONS = {}
_ICON_ANIMATION_SCALE_CACHE = {}
_LEGENDARY_ICON_NAMES = {"ragnarok_hammer", "hermes_shoes", "poseidon_trident", "angel_blessing", "sacred_laurel"}
# 전설 버프용 아이템 스폰 배율
LEGENDARY_ITEM_SPAWN_MULT = 1.0


def _center_icon_surface(icon: pygame.Surface, size: int = 32, padding: int = 2) -> pygame.Surface:
    """투명 여백이 큰 아이콘을 잘라내고 중앙 정렬해 작은 해상도에서도 선명하게 보이도록 스케일."""
    try:
        mask = pygame.mask.from_surface(icon)
        bbox = mask.get_bounding_rect()
        if bbox.width == 0 or bbox.height == 0:
            return pygame.transform.smoothscale(icon, (size, size))
        cropped = icon.subsurface(bbox)
        target = max(1, size - padding * 2)
        scale = target / max(cropped.get_width(), cropped.get_height())
        new_w = max(1, min(size, int(cropped.get_width() * scale)))
        new_h = max(1, min(size, int(cropped.get_height() * scale)))
        scaled = pygame.transform.smoothscale(cropped, (new_w, new_h))
        canvas = pygame.Surface((size, size), pygame.SRCALPHA)
        canvas.blit(scaled, ((size - new_w) // 2, (size - new_h) // 2))
        return canvas
    except Exception:
        return pygame.transform.smoothscale(icon, (size, size))

def _draw_vitamin_bottle_icon_flat(size: int = 32) -> pygame.Surface:
    """깔끔한 '갈색병 + 파란 라벨' 평면 아이콘(정적). 오라/엠블럼/애니 없음."""
    s = pygame.Surface((size, size), pygame.SRCALPHA)
    cx, cy = size // 2, size // 2
    k = size / 32.0

    # 병 바디(호박색 유리) - 하단 평평, 상단만 둥글게
    body_w = int(14*k)
    body_h = int(20*k)
    body_left = cx - body_w//2
    body_top = cy + int(2*k) - body_h//2
    top_curve_h = max(4, int(8*k))  # 상단 곡면 높이
    amber = (155, 95, 45)
    amber_dark = (100, 60, 28)
    # 하단 직사각 영역(폭 유지, 바닥 납작)
    rect_lower = pygame.Rect(body_left, body_top + top_curve_h, body_w, body_h - top_curve_h)
    pygame.draw.rect(s, amber, rect_lower)
    # 상단 곡면(타원)
    ellipse_top = pygame.Rect(body_left, body_top, body_w, top_curve_h*2//2)
    pygame.draw.ellipse(s, amber, ellipse_top)
    # 외곽선: 좌/우/바닥은 직선, 윗부분만 아크
    pygame.draw.line(s, amber_dark, (body_left, rect_lower.top), (body_left, rect_lower.bottom), 1)
    pygame.draw.line(s, amber_dark, (body_left + body_w, rect_lower.top), (body_left + body_w, rect_lower.bottom), 1)
    pygame.draw.line(s, amber_dark, (body_left, rect_lower.bottom), (body_left + body_w, rect_lower.bottom), 1)
    try:
        pygame.draw.arc(s, amber_dark, ellipse_top, math.pi, 0, 1)
    except Exception:
        pass

    # 목 부분(간단)
    neck = pygame.Rect(0, 0, int(10*k), int(6*k))
    neck.center = (cx, body_top + int(3*k))
    pygame.draw.rect(s, amber, neck, border_radius=int(2*k))
    pygame.draw.rect(s, amber_dark, neck, 1, border_radius=int(2*k))

    # 캡(단색, 과한 디테일 제거)
    cap = pygame.Rect(0, 0, int(12*k), int(4*k))
    cap.center = (cx, neck.top - int(2*k))
    cap_col = (190, 160, 65)
    cap_edge = (120, 100, 40)
    pygame.draw.rect(s, cap_col, cap, border_radius=int(2*k))
    pygame.draw.rect(s, cap_edge, cap, 1, border_radius=int(2*k))

    # 라벨(파란색)
    label = pygame.Rect(0, 0, int(13*k), int(7*k))
    label.center = (cx, cy + int(4*k))
    blue = (38, 90, 210)
    blue_edge = (20, 55, 130)
    pygame.draw.rect(s, blue, label, border_radius=int(2*k))
    pygame.draw.rect(s, blue_edge, label, 1, border_radius=int(2*k))

    # 유리 미세 하이라이트(세로 얇은 반사)
    hi = pygame.Surface((size, size), pygame.SRCALPHA)
    slim = pygame.Rect(body_left+int(2*k), body_top+int(4*k), int(2*k), int(12*k))
    pygame.draw.rect(hi, (255,255,255,40), slim)
    s.blit(hi, (0,0), special_flags=pygame.BLEND_PREMULTIPLIED)

    return s

def _draw_vitamin_bottle_icon_hires(size: int = 32, glow_phase: float = 0.0, ss: int = 3) -> pygame.Surface:
    """슈퍼샘플링(SSAA)로 더 깔끔한 박카스풍 아이콘 생성."""
    hi = size * ss
    surf = pygame.Surface((hi, hi), pygame.SRCALPHA)
    cx, cy = hi // 2, hi // 2

    def sc(v):
        return int(round(v * ss))

    # 배경 오라(다중 원으로 그라데이션)
    for i in range(6):
        rr = sc(10 + i * 2)
        alpha = int(40 * (1 - i / 6.0) * (0.6 + 0.4 * (0.5 + 0.5 * math.sin(glow_phase * 2 * math.pi))))
        pygame.draw.circle(surf, (70, 130, 255, alpha), (cx, cy), rr)

    # 병 본체 (유리 그라데이션)
    body = pygame.Rect(0, 0, sc(14), sc(20))
    body.center = (cx, cy + sc(2))
    glass_cols = [(110, 65, 28, 255), (150, 92, 44, 235), (200, 135, 78, 210)]
    for i, (r, g, b, a) in enumerate(glass_cols):
        inner = body.inflate(-sc(i * 1.2), -sc(i * 1.2))
        pygame.draw.ellipse(surf, (r, g, b, a), inner)
    # 외곽선
    pygame.draw.ellipse(surf, (60, 35, 15, 200), body, sc(0.8))

    # 목 부분
    neck = pygame.Rect(0, 0, sc(10), sc(7))
    neck.center = (cx, body.top + sc(3))
    pygame.draw.rect(surf, (150, 92, 44, 235), neck, border_radius=sc(2))
    pygame.draw.rect(surf, (80, 45, 18, 210), neck, sc(0.8), border_radius=sc(2))

    # 캡(금색) + 홈 라인
    cap = pygame.Rect(0, 0, sc(12), sc(5))
    cap.center = (cx, neck.top - sc(2))
    pygame.draw.rect(surf, (220, 190, 80), cap, border_radius=sc(1.5))
    pygame.draw.rect(surf, (140, 110, 40), cap, sc(0.8), border_radius=sc(1.5))
    # 홈
    for x in range(cap.left + sc(2), cap.right - sc(2), sc(2)):
        pygame.draw.line(surf, (180, 150, 60), (x, cap.top + sc(1)), (x, cap.bottom - sc(1)))
    # 캡 하이라이트
    pygame.draw.rect(surf, (255, 240, 160), (cap.left + sc(2), cap.top + sc(1), sc(6), sc(1)))

    # 라벨(블루)
    label = pygame.Rect(0, 0, sc(13), sc(7))
    label.center = (cx, cy + sc(4))
    pygame.draw.rect(surf, (35, 90, 205), label, border_radius=sc(2.5))
    pygame.draw.rect(surf, (18, 56, 130), label, sc(0.8), border_radius=sc(2.5))
    # 중앙 엠블럼 (붉은 원 + 날개형 V)
    pygame.draw.circle(surf, (225, 40, 40), label.center, sc(2.6))
    lx, ly = label.center
    wing = [
        (lx - sc(4.2), ly), (lx - sc(1.2), ly - sc(2.0)), (lx, ly),
        (lx + sc(1.2), ly - sc(2.0)), (lx + sc(4.2), ly), (lx, ly + sc(2.2))
    ]
    pygame.draw.polygon(surf, (248, 248, 252), wing)

    # 유리 하이라이트(사선 반사)
    hl = pygame.Surface((hi, hi), pygame.SRCALPHA)
    pygame.draw.ellipse(hl, (255, 255, 255, 70), body.inflate(sc(3), sc(2)))
    hl = pygame.transform.rotate(hl, -25)
    surf.blit(hl, (0, 0), special_flags=pygame.BLEND_PREMULTIPLIED)

    # 바닥 그림자
    pygame.draw.ellipse(surf, (0, 0, 0, 110), (cx - sc(7), cy + sc(9), sc(14), sc(4)))

    # 다운샘플링으로 안티앨리어싱 적용
    return pygame.transform.smoothscale(surf, (size, size))

def _make_vitamin_icon_frames(size: int = 32, frame_count: int = 8) -> list[pygame.Surface]:
    frames = []
    for i in range(frame_count):
        phase = i / frame_count
        frames.append(_draw_vitamin_bottle_icon_hires(size, glow_phase=phase, ss=3))
    return frames


def _draw_laser_scope_icon(size: int = 32) -> pygame.Surface:
    """레이저스코프 아이콘 그리기 - 조준경 + 레이저 빔"""
    s = pygame.Surface((size, size), pygame.SRCALPHA)
    cx, cy = size // 2, size // 2
    k = size / 32.0

    # 배경 글로우 (빨간색)
    for i in range(3):
        radius = int((14 - i * 3) * k)
        alpha = 30 - i * 10
        pygame.draw.circle(s, (255, 50, 50, alpha), (cx, cy), radius)

    # 조준경 외곽 원 (검은색 + 회색 테두리)
    outer_radius = int(12 * k)
    pygame.draw.circle(s, (40, 40, 50), (cx, cy), outer_radius)
    pygame.draw.circle(s, (80, 80, 100), (cx, cy), outer_radius, 2)

    # 내부 원 (어두운 유리)
    inner_radius = int(9 * k)
    pygame.draw.circle(s, (20, 30, 40), (cx, cy), inner_radius)

    # 레이저 십자선 (빨간색)
    laser_color = (255, 50, 50)
    laser_glow = (255, 100, 100, 100)
    cross_len = int(8 * k)

    # 글로우 효과
    glow_surf = pygame.Surface((size, size), pygame.SRCALPHA)
    pygame.draw.line(glow_surf, laser_glow, (cx - cross_len, cy), (cx + cross_len, cy), 3)
    pygame.draw.line(glow_surf, laser_glow, (cx, cy - cross_len), (cx, cy + cross_len), 3)
    s.blit(glow_surf, (0, 0))

    # 핵심 레이저 라인
    pygame.draw.line(s, laser_color, (cx - cross_len, cy), (cx + cross_len, cy), 1)
    pygame.draw.line(s, laser_color, (cx, cy - cross_len), (cx, cy + cross_len), 1)

    # 중앙 점 (밝은 빨간색)
    pygame.draw.circle(s, (255, 150, 150), (cx, cy), int(2 * k))
    pygame.draw.circle(s, (255, 255, 255), (cx, cy), int(1 * k))

    # 조준경 마운트 (위아래 작은 돌출부)
    mount_color = (60, 60, 70)
    mount_w = int(4 * k)
    mount_h = int(3 * k)
    # 위쪽 마운트
    pygame.draw.rect(s, mount_color, (cx - mount_w//2, int(2 * k), mount_w, mount_h))
    # 아래쪽 마운트
    pygame.draw.rect(s, mount_color, (cx - mount_w//2, size - int(5 * k), mount_w, mount_h))

    # 유리 반사 하이라이트
    highlight_surf = pygame.Surface((size, size), pygame.SRCALPHA)
    pygame.draw.arc(highlight_surf, (255, 255, 255, 40),
                   (cx - inner_radius + 2, cy - inner_radius + 2,
                    inner_radius * 2 - 4, inner_radius * 2 - 4),
                   math.pi * 0.7, math.pi * 1.3, 2)
    s.blit(highlight_surf, (0, 0))

    return s


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
        "bulletproof_hat": "bulletproof_hat.png",
        "spiked_helmet": "spiked_helmet.png",
        "dowsing_pendulum": "dowsing_pendulum.png",
        "fireball": "fireball.png",
        "coolingball": "coolingball.png",
        "gravitybelt": "gravitybelt.png",
        "grenade": "grenade.png",
        "molotov": "molotov.png",
        "smoke_grenade": "smoke_grenade.png",
        "devil_dice": "devil_dice.png",  # 😈 악마의 주사위 아이콘 추가
        "cooltime": "coolingball.png",  # 쿨타임(쿨링볼) 아이콘  
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
        "berserk_potion": "berserk_potion.png",  # 광폭물약 아이콘
        "net_gun": "net_gun.png",  # 그물덫총 아이콘
        "fire_support": "fire_support.png",  # 화력지원 아이콘
        "spider_mine": "spider_mine.png",  # 스파이더지뢰 아이콘
        "repair_kit": "repair_kit.png",  # 수리키트 아이콘
        "vitamin_pill": "vitamin_pill.png",  # 비타민약 아이콘 (없을 시 코드로 그립니다)
        "laser_scope": "laser_scope.png",  # 레이저스코프 아이콘
        "knee_pads": "knee_pads.png",  # 무릎보호대 아이콘
        # 전설 아이템(아이콘)
        "ragnarok_hammer": "legendary/ragnarok_hammer.png",
        "hermes_shoes": "legendary/hermes_shoes.png",
        "poseidon_trident": "legendary/poseidon_trident.png",
        "angel_blessing": "legendary/angel_blessing.png"  # 천사의 가호 아이콘
    }

    legendary_manager = None

    for item_name, icon_file in icon_files.items():
        # 비타민약: 고정 아이콘(갈색병+파란 라벨), 애니메이션/오라 제거
        if item_name == "vitamin_pill":
            try:
                ITEM_ICONS[item_name] = _draw_vitamin_bottle_icon_flat(32)
            except Exception:
                fallback = pygame.Surface((32,32), pygame.SRCALPHA)
                pygame.draw.rect(fallback, (150,90,45), (12,10,8,14))
                pygame.draw.rect(fallback, (38,90,210), (10,16,12,6))
                ITEM_ICONS[item_name] = fallback
            # 애니메이션 프레임은 등록하지 않음(정적 아이콘 요구)
            continue
        if item_name == "ragnarok_hammer":
            try:
                if legendary_manager is None:
                    from legendary_items import get_legendary_manager  # 순환 의존성 방지용 지연 import
                    legendary_manager = get_legendary_manager()

                hammer = legendary_manager.get_item("ragnarok_hammer") if legendary_manager else None
                frames = getattr(hammer, "animation_frames", None)

                if frames:
                    copied_frames = [frame.copy() for frame in frames if frame]
                    if copied_frames:
                        ITEM_ICON_ANIMATIONS[item_name] = copied_frames
                        ITEM_ICONS[item_name] = pygame.transform.smoothscale(copied_frames[0], (32, 32))
                        continue
            except Exception as exc:
                print(f"[WARN] Ragnarok icon animation sync failed: {exc}")

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
            # 여백이 많은 아이콘은 잘라 중앙 정렬 후 스케일링
            if item_name == "spiked_helmet":
                icon = _center_icon_surface(icon, 32, padding=2)
            else:
                icon = pygame.transform.scale(icon, (32, 32))  # 표준 크기로 조정
            ITEM_ICONS[item_name] = icon
            
            # LONG_BOOST_ICON도 설정
            if item_name == "long_boost":
                LONG_BOOST_ICON = icon
        except:
            # 아이콘 로드 실패 시 고품질 절차적 아이콘 생성
            if item_name == "vitamin_pill":
                try:
                    frames = _make_vitamin_icon_frames(32, 8)
                    ITEM_ICON_ANIMATIONS[item_name] = frames
                    ITEM_ICONS[item_name] = frames[0]
                except Exception:
                    # 안전 폴백: 간단한 병 실루엣
                    icon = pygame.Surface((32, 32), pygame.SRCALPHA)
                    pygame.draw.rect(icon, (160, 100, 60), (12, 10, 8, 14))
                    pygame.draw.rect(icon, (230, 200, 90), (11, 7, 10, 4))
                    pygame.draw.rect(icon, (30, 90, 200), (10, 16, 12, 6))
                    ITEM_ICONS[item_name] = icon
            elif item_name == "laser_scope":
                # 레이저스코프 아이콘 프로시저럴 생성
                try:
                    ITEM_ICONS[item_name] = _draw_laser_scope_icon(32)
                except Exception:
                    icon = pygame.Surface((32, 32), pygame.SRCALPHA)
                    pygame.draw.circle(icon, (255, 50, 50), (16, 16), 12)
                    pygame.draw.line(icon, (255, 100, 100), (4, 16), (28, 16), 2)
                    pygame.draw.line(icon, (255, 100, 100), (16, 4), (16, 28), 2)
                    ITEM_ICONS[item_name] = icon
            else:
                icon = pygame.Surface((32, 32), pygame.SRCALPHA)
                pygame.draw.circle(icon, (200, 200, 200), (16, 16), 14)
                ITEM_ICONS[item_name] = icon
    
    placeholder_icon = get_item_icon("empty_legendary")
    if placeholder_icon:
        ITEM_ICONS["empty_legendary"] = pygame.transform.smoothscale(placeholder_icon, (32, 32))

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
        "chance": 0.006,  # 확률 1.0%로 상향 (기존: 0.3%)
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
        "chance": 0.003,  # 중간 확률
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
        "chance": 0.005,  # 확률 1.2%
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
        "chance": 0.006,  # 확률 1%
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
    {
        "name": "bulletproof_hat",  # 방탄모자 패시브 아이템
        "color": (80, 110, 150),  # 진한 네이비 톤
        "effect": "bulletproof_hat",
        "icon": None,
        "chance": 0.006,  # 희귀 패시브 기본 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "spiked_helmet",  # 가시투구 패시브 아이템
        "color": (100, 120, 140),  # 짙은 강철색
        "effect": "spiked_helmet",
        "icon": None,
        "chance": 0.006,  # 희귀 패시브 기본 확률
        "duration": 600,
        "unlock_condition": None
    },
    # 전설 아이템 (필드 스폰 가능)
    {
        "name": "ragnarok_hammer",  # 라그나로크 해머 전설 아이템
        "color": (255, 50, 50),  # 붉은색 (전설 색상)
        "effect": "ragnarok_hammer",
        "icon": None,
        "chance": 0.0004,  # 전설 아이템 필드 드랍 0.04% 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "hermes_shoes",  # 헤르메스의 신발 전설 아이템
        "color": (100, 200, 255),  # 하늘색 (전설 색상)
        "effect": "hermes_shoes",
        "icon": None,
        "chance": 0.0004,  # 전설 아이템 필드 드랍 0.04% 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "poseidon_trident",  # 포세이돈의 삼지창 전설 아이템
        "color": (50, 150, 255),  # 바다색 (전설 색상)
        "effect": "poseidon_trident",
        "icon": None,
        "chance": 0.0004,  # 전설 아이템 필드 드랍 0.04% 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "angel_blessing",  # 천사의 가호 전설 아이템
        "color": (220, 240, 255),  # 옅은 하늘색
        "effect": "angel_blessing",
        "icon": None,
        "chance": 0.0004,  # 전설 아이템 필드 드랍 0.04% 확률
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "sacred_laurel",  # 신성 월계수 전설 아이템
        "color": (100, 200, 100),  # 연두색
        "effect": "sacred_laurel",
        "icon": None,
        "chance": 0.0004,  # 전설 아이템 필드 드랍 0.04% 확률
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
        "name": "berserk_potion",  # 광폭물약 액티브 아이템 (발토르 전용)
        "color": (230, 90, 80),  # 화염빛 붉은색
        "effect": "berserk_potion",
        "icon": None,
        "chance": 0.004,  # 희귀 전용 아이템 확률 (발토르 전용)
        "duration": 900,
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
    },
    {
        "name": "vitamin_pill",  # 비타민약 액티브 아이템
        "color": (80, 170, 255),  # 청량한 블루
        "effect": "vitamin_pill",
        "icon": None,
        "chance": 0.012,  # 기본 1.2%
        "duration": 600,
        "unlock_condition": None
    },
    {
        "name": "laser_scope",  # 레이저스코프 액티브 아이템
        "color": (255, 50, 50),  # 빨간색 (레이저 색상)
        "effect": "laser_scope",
        "icon": None,
        "chance": 0.004,  # 확률 0.4%
        "duration": 1500,  # 25초
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
bulletproof_hat_obtained = False  # 방탄모자 아이템 획득 여부
spiked_helmet_obtained = False  # 가시투구 아이템 획득 여부
spikeboots_obtained = False  # 스파이크부츠 아이템 획득 여부
dashgear_obtained = False  # 대쉬기어 아이템 획득 여부
bulkup_obtained = False  # 벌크업 아이템 획득 여부
sensor_obtained = False  # 감지센서 아이템 획득 여부
gravitybelt_obtained = False  # 무중력벨트 아이템 획득 여부
dashholder_obtained = False  # 대쉬홀더 아이템 획득 여부
commando_arm_obtained = False  # 코만도암 아이템 획득 여부
commando_arm_count = 0         # 코만도암 획득 개수 (스택용)
dowsing_pendulum_obtained = False  # 다우징팬들럼 아이템 획득 여부
technical_vest_obtained = False  # 테크니컬조끼 아이템 획득 여부

# 전설 아이템 획득 여부
ragnarok_hammer_obtained = False  # 라그나로크 해머 획득 여부
hermes_shoes_obtained = False  # 헤르메스의 신발 획득 여부
poseidon_trident_obtained = False  # 포세이돈의 삼지창 획득 여부
angel_blessing_obtained = False  # 천사의 가호 획득 여부
sacred_laurel_obtained = False  # 신성 월계수 획득 여부
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
    "bulletproof_hat": True,
    "spiked_helmet": True,
    "smartphone": True,
    "ammo_box": True,
    "fire_support": True,
    "doping_potion": True,
    "berserk_potion": True,
    "vitamin_pill": True,
    "laser_scope": True,

    # 전설 아이템 해금 상태
    "ragnarok_hammer": True,
    "hermes_shoes": True,
    "poseidon_trident": True,
    
    # 패시브 아이템
    "knee_pads": True
    
}

# 현재 떠 있는 아이템 리스트
item_list = []

# 패시브 아이템은 중복 스폰을 허용하여 롤 옵션 파밍을 지원한다.
PASSIVE_DUPLICATE_ALLOWED = {
    "slot_add", "speedboots", "speedgear", "battery", "revival", "master", "cooltime",
    "chargebag", "spikeboots", "dashgear", "bulkup", "sensor", "dashholder",
    "gravitybelt", "dowsing_pendulum", "commando_arm", "technical_vest",
    "fuel_pouch", "bluetooth_ring", "star_detector", "foul_whistle",
    "smartphone", "knee_pads"
}


def _allow_duplicate_passive(name: str) -> bool:
    return name in PASSIVE_DUPLICATE_ALLOWED

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
    bulletproof_hat_obtained = False  # 방탄모자 획득 상태 초기화
    spiked_helmet_obtained = False  # 가시투구 획득 상태 초기화
    spikeboots_obtained = False  # spikeboots 획득 상태 초기화
    dashgear_obtained = False  # dashgear 획득 상태 초기화
    
    global bulkup_obtained, gravitybelt_obtained, dashholder_obtained, sensor_obtained
    bulkup_obtained = False  # bulkup 획득 상태 초기화
    gravitybelt_obtained = False  # gravitybelt 획득 상태 초기화
    dashholder_obtained = False  # dashholder 획득 상태 초기화
    sensor_obtained = False  # sensor 획득 상태 초기화
    
    global dowsing_pendulum_obtained, commando_arm_obtained, commando_arm_count, technical_vest_obtained
    dowsing_pendulum_obtained = False  # dowsing_pendulum 획득 상태 초기화
    commando_arm_obtained = False  # commando_arm 획득 상태 초기화
    commando_arm_count = 0         # commando_arm 스택 초기화
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
    global ragnarok_hammer_obtained, poseidon_trident_obtained, foul_whistle_obtained, angel_blessing_obtained
    
    debug_spawn = os.environ.get("PINGF_DEBUG_ITEMS", "0").lower() in ("1", "true", "yes", "on")
    if debug_spawn:
        # 디버그: 포세이돈 플래그 상태 출력
        print(f"[DEBUG spawn_random_item] poseidon_trident_obtained = {poseidon_trident_obtained}")
    
    # passive_item_list를 가져와서 이미 보유한 패시브 아이템 확인
    selected_character = None
    try:
        import pingfighter
        current_passive_items = [item["name"] for item in pingfighter.passive_item_list]
        selected_character = getattr(pingfighter, "selected_character_type", None)
        if debug_spawn:
            print(f"[DEBUG spawn_random_item] selected_character_type: {selected_character}")
            print(f"[DEBUG] Current passive items in inventory: {current_passive_items}")
    except Exception:
        current_passive_items = []
        selected_character = None
    
    # 현재 필드에 떠 있는 아이템들의 이름 목록 생성 (중복 방지)
    items_in_field = [item["type"]["name"] for item in item_list]
    if debug_spawn:
        print(f"[DEBUG] Items currently in field: {items_in_field}")
    
    # 스폰 가능한 아이템 목록 생성
    available_items = []
    
    for item in ITEM_TYPES:
        if not unlocked_items.get(item["name"], False):
            continue

        # 발토르 전용 아이템은 타 캐릭터 플레이 시 스폰하지 않음
        if item["name"] == "repair_kit" and selected_character != "blacksmith":
            continue
        if item["name"] == "berserk_potion" and selected_character != "blacksmith":
            continue

        # slot_add는 패시브 파밍 허용 (장착 슬롯 상한은 별도 로직으로 제한)
        if item["name"] == "slot_add" and slot_add_obtained >= 2 and not _allow_duplicate_passive("slot_add"):
            continue

        # speedboots 아이템은 한 번 획득해도 추가 스폰 허용(파밍용)
        if item["name"] == "speedboots" and speedboots_obtained and not _allow_duplicate_passive("speedboots"):
            continue

        if item["name"] == "speedgear" and speedgear_obtained and not _allow_duplicate_passive("speedgear"):
            continue

        if item["name"] == "battery" and battery_obtained and not _allow_duplicate_passive("battery"):
            continue

        if item["name"] == "revival" and (revival_obtained or revival_used) and not _allow_duplicate_passive("revival"):
            continue

        if item["name"] == "master" and master_obtained and not _allow_duplicate_passive("master"):
            continue

        if item["name"] == "cooltime" and cooltime_obtained and not _allow_duplicate_passive("cooltime"):
            continue

        if item["name"] == "chargebag" and chargebag_obtained and not _allow_duplicate_passive("chargebag"):
            continue

        if item["name"] == "spikeboots" and spikeboots_obtained and not _allow_duplicate_passive("spikeboots"):
            continue

        if item["name"] == "dashgear" and dashgear_obtained and not _allow_duplicate_passive("dashgear"):
            continue

        if item["name"] == "bulkup" and bulkup_obtained and not _allow_duplicate_passive("bulkup"):
            continue

        if item["name"] == "dashholder" and dashholder_obtained and not _allow_duplicate_passive("dashholder"):
            continue

        if item["name"] == "gravitybelt" and gravitybelt_obtained and not _allow_duplicate_passive("gravitybelt"):
            continue

        if item["name"] == "sensor" and sensor_obtained and not _allow_duplicate_passive("sensor"):
            continue

        if item["name"] == "dowsing_pendulum" and dowsing_pendulum_obtained and not _allow_duplicate_passive("dowsing_pendulum"):
            continue
        
        # commando_arm 중복 스폰 허용 (장착 스택 제한은 별도 처리)
        
        if item["name"] == "technical_vest" and technical_vest_obtained and not _allow_duplicate_passive("technical_vest"):
            continue
        
        if item["name"] == "fuel_pouch" and fuel_pouch_obtained and not _allow_duplicate_passive("fuel_pouch"):
            continue
        
        if item["name"] == "bluetooth_ring" and bluetooth_ring_obtained and not _allow_duplicate_passive("bluetooth_ring"):
            continue

        if item["name"] == "star_detector" and star_detector_obtained and not _allow_duplicate_passive("star_detector"):
            continue

        # 화력지원은 물자보급 전용이므로 필드에서는 절대 스폰하지 않음
        if item["name"] == "fire_support":
            continue

        # foul_whistle 아이템은 한 번 획득해도 추가 스폰 허용(파밍용)
        if item["name"] == "foul_whistle" and foul_whistle_obtained and not _allow_duplicate_passive("foul_whistle"):
            continue

        # knee_pads 아이템 중복 허용
        if item["name"] == "knee_pads" and knee_pads_obtained and not _allow_duplicate_passive("knee_pads"):
            continue
        
        # 라그나로크 해머는 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "ragnarok_hammer" and ragnarok_hammer_obtained:
            continue
        
        # 헤르메스의 신발은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "hermes_shoes" and hermes_shoes_obtained:
            continue
        
        # 방탄모자는 한 번 획득하면 더 이상 스폰하지 않음
        if item["name"] == "bulletproof_hat" and bulletproof_hat_obtained:
            continue
        # 가시투구는 한 번 획득하면 더 이상 스폰하지 않음
        if item["name"] == "spiked_helmet" and spiked_helmet_obtained:
            continue
        
        # 포세이돈의 삼지창은 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "poseidon_trident":
            print(f"[DEBUG] Checking poseidon_trident: obtained = {poseidon_trident_obtained}")
            if poseidon_trident_obtained:
                print(f"[DEBUG] Skipping poseidon_trident spawn (already obtained)")
                continue
            else:
                print(f"[DEBUG] poseidon_trident can spawn (not obtained yet)")

        # 천사의 가호는 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "angel_blessing" and angel_blessing_obtained:
            continue
        
        # 신성 월계수는 한 번 획득하면 더 이상 스폰 안함
        if item["name"] == "sacred_laurel" and sacred_laurel_obtained:
            continue
        
        # 패시브 아이템 중복 스폰 허용(파밍). 단, 동일 아이템이 필드에 이미 있을 때는 혼잡 방지를 위해 1개만 유지.
        if item["name"] in items_in_field and item["name"] != "chargebag":
            print(f"[DEBUG] Skipping {item['name']} - already spawned in field (limit 1 concurrently)")
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
    try:
        skill_spawn_boost *= LEGENDARY_ITEM_SPAWN_MULT
    except Exception:
        pass

    legendary_names = {"ragnarok_hammer", "hermes_shoes", "poseidon_trident", "angel_blessing", "sacred_laurel"}
    try:
        legendary_multiplier = academy.get_treasure_map_field_multiplier()
    except Exception:
        legendary_multiplier = 1.0

    # 1) 기본 가중치 계산 (스킬/전설 배수 적용)
    base_weights: list[tuple[dict, float]] = []
    active_sum = passive_sum = 0.0
    passive_names = {
        "speedboots", "speedgear", "battery", "slot_add", "revival", "master", "cooltime",
        "chargebag", "spikeboots", "dashgear", "sensor", "bulkup", "dashholder", "gravitybelt",
        "dowsing_pendulum", "commando_arm", "technical_vest", "fuel_pouch", "bluetooth_ring",
        "star_detector", "foul_whistle", "smartphone", "knee_pads", "ragnarok_hammer",
        "hermes_shoes", "poseidon_trident", "angel_blessing", "bulletproof_hat", "spiked_helmet"
    }

    for item in available_items:
        w = item["chance"] * skill_spawn_boost
        if item["name"] in legendary_names:
            w *= legendary_multiplier
        base_weights.append((item, w))
        if item["name"] in passive_names:
            passive_sum += w
        else:
            active_sum += w

    # 2) 목표 비율(75/25)에 맞춰 그룹별 스케일링
    scaled_weights: list[tuple[dict, float]] = []
    target_a = TARGET_ACTIVE_DROP_SHARE
    target_p = TARGET_PASSIVE_DROP_SHARE

    if active_sum > 0 and passive_sum > 0:
        active_scale = target_a / active_sum
        passive_scale = target_p / passive_sum
    elif active_sum > 0:
        active_scale = 1.0
        passive_scale = 0.0
    elif passive_sum > 0:
        active_scale = 0.0
        passive_scale = 1.0
    else:
        return  # 방어적: 가중치가 모두 0이면 스폰하지 않음

    for item, w in base_weights:
        if item["name"] in passive_names:
            scaled_w = w * passive_scale
        else:
            scaled_w = w * active_scale
        scaled_weights.append((item, scaled_w))

    total_chance = sum(w for _, w in scaled_weights)
    if total_chance <= 0:
        return

    random_value = random.random() * total_chance

    current_chance = 0.0
    selected_item = None
    for item, w in scaled_weights:
        current_chance += w
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
            if item_name in ["speedboots", "speedgear", "battery", "slot_add", "revival", "master", "cooltime", "chargebag", "spikeboots", "dashgear", "sensor", "bulkup", "dashholder", "gravitybelt", "dowsing_pendulum", "commando_arm", "technical_vest", "fuel_pouch", "bluetooth_ring", "star_detector", "foul_whistle", "smartphone", "knee_pads", "ragnarok_hammer", "hermes_shoes", "poseidon_trident", "bulletproof_hat", "spiked_helmet"]:
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
    """엑티브 아이템 슬롯 + 쿨타임 표시 + 툴팁."""
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

    mouse_pos = pygame.mouse.get_pos()
    tooltip = None

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
                    countdown_font = pygame.font.Font(resource_path("PFStardust.ttf"), 32)
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

        # 단일 슬롯 툴팁 대상 기록
        slot_rect = pygame.Rect(x, y, SLOT_W, SLOT_H)
        if slot_rect.collidepoint(mouse_pos) and active_item_slot.get("name"):
            tooltip = active_item_slot.get("name")

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

    # 툴팁 렌더링 (마우스 오버된 마지막 슬롯 기준)
    if tooltip:
        try:
            font = pygame.font.Font("NanumSquareB.ttf", 14)
        except Exception:
            font = pygame.font.Font(None, 16)
        text = tooltip
        text_surf = font.render(text, True, (255, 255, 255))
        text_rect = text_surf.get_rect()
        padding = 6
        bg_surf = pygame.Surface((text_rect.width + padding * 2, text_rect.height + padding * 2), pygame.SRCALPHA)
        bg_surf.fill((20, 24, 32, 230))
        pygame.draw.rect(bg_surf, (90, 130, 200), bg_surf.get_rect(), 1)
        text_rect.center = bg_surf.get_rect().center
        bg_surf.blit(text_surf, text_rect)
        mx, my = mouse_pos
        screen.blit(bg_surf, (mx + 12, my + 12))
