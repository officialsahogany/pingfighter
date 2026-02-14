# downtown/hero_skill_icons.py
# 투기장 영웅 스킬 아이콘 시스템 (프로그래밍 방식 32x32 픽셀아트)

import pygame
import math
from typing import Dict, Optional

# 캐시된 아이콘 Surface {skill_id: Surface(32, 32)}
_skill_icon_cache: Dict[str, pygame.Surface] = {}


def get_skill_icon(skill_id: str, size: int = 32) -> Optional[pygame.Surface]:
    """스킬 ID로 아이콘 Surface 반환 (캐시 사용)"""
    cache_key = f"{skill_id}_{size}"
    if cache_key in _skill_icon_cache:
        return _skill_icon_cache[cache_key]

    # 32x32로 생성 후 필요시 스케일
    base = _create_icon(skill_id)
    if base is None:
        return None

    if size != 32:
        base = pygame.transform.smoothscale(base, (size, size))

    _skill_icon_cache[cache_key] = base
    return base


def clear_cache():
    """아이콘 캐시 초기화"""
    _skill_icon_cache.clear()


def _create_icon(skill_id: str) -> Optional[pygame.Surface]:
    """skill_id에 해당하는 32x32 아이콘 생성"""
    creators = {
        "dark_slash": _icon_dark_slash,
        "demon_step": _icon_demon_eye,
        "tentacle_wrap": _icon_tentacle_wrap,
        "abyss_ink": _icon_abyss_ink,
        "gravity_control": _icon_gravity_control,
        "dwarf_magic": _icon_dwarf_magic,
        "hell_fire": _icon_hellfire,
        "horn_charge": _icon_horn_charge,
        "puppet_control": _icon_puppet_control,
        "doll_curse": _icon_doll_curse,
        "dragon_breath": _icon_dragon_breath,
        "dragon_wing": _icon_dragon_wing,
        "steam_barrier": _icon_steam_barrier,
        "oil_spill": _icon_oil_spill,
        "shadow_clone": _icon_shadow_clone,
        "illusion_shuriken": _icon_illusion_shuriken,
        "charm": _icon_charm,
        "riddle_trick": _icon_riddle_trick,
        "ghost_summon": _icon_ghost_summon,
        "skeleton_archer": _icon_skeleton_archer,
        "bone_barrier": _icon_bone_barrier,
        "balloon_wall": _icon_balloon_wall,
        "bomb_surprise": _icon_bomb_surprise,
        "gatling_burst": _icon_gatling_burst,
        "sand_prison": _icon_sand_prison,
        "sand_vortex": _icon_sand_vortex,
        "solar_bolt": _icon_solar_bolt,
        "thunder_orb": _icon_thunder_orb,
        "banana_slice": _icon_banana_slice,
        "wild_roar": _icon_wild_roar,
    }
    creator = creators.get(skill_id)
    if creator:
        return creator()
    # 폴백: 물음표 아이콘
    return _icon_fallback(skill_id)


def _icon_fallback(skill_id: str) -> pygame.Surface:
    """알 수 없는 스킬용 폴백 아이콘"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    pygame.draw.circle(s, (60, 60, 80), (16, 16), 14)
    pygame.draw.circle(s, (100, 100, 120), (16, 16), 14, 2)
    # ? 표시
    pygame.draw.line(s, (200, 200, 200), (12, 11), (16, 11), 2)
    pygame.draw.line(s, (200, 200, 200), (16, 11), (16, 17), 2)
    pygame.draw.circle(s, (200, 200, 200), (16, 21), 1)
    return s


# ===== 무겐 (mugen) 스킬 =====

def _icon_dark_slash() -> pygame.Surface:
    """달빛 베기 - 보라색 사선 칼날 + 달 초승달"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경 원
    pygame.draw.circle(s, (25, 12, 45), (16, 16), 15)
    pygame.draw.circle(s, (40, 20, 70), (16, 16), 15, 1)
    # 사선 칼날 (좌하→우상)
    pygame.draw.line(s, (180, 150, 255), (6, 26), (26, 6), 3)
    pygame.draw.line(s, (220, 200, 255), (7, 25), (25, 7), 1)
    # 칼날 빛나는 효과
    pygame.draw.line(s, (255, 240, 255, 180), (8, 24), (24, 8), 1)
    # 초승달 (우상단)
    pygame.draw.circle(s, (200, 200, 255), (24, 8), 5)
    pygame.draw.circle(s, (25, 12, 45), (22, 6), 5)
    # 스파크
    for px, py in [(14, 18), (18, 14), (16, 16)]:
        pygame.draw.circle(s, (255, 255, 220), (px, py), 1)
    return s


def _icon_demon_eye() -> pygame.Surface:
    """귀신발걸음 - 유령 실루엣 + 잔상 발자국 + 보라 오라"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 어두운 보라 배경
    pygame.draw.circle(s, (25, 10, 45), (16, 16), 15)
    pygame.draw.circle(s, (60, 30, 90), (16, 16), 15, 1)
    # 잔상 발자국 (왼발-오른발 교대, 뒤에서 앞으로 페이드인)
    foot_pairs = [(8, 27, 60), (14, 24, 90), (20, 21, 130)]
    for fx, fy, fa in foot_pairs:
        pygame.draw.ellipse(s, (140, 80, 200, fa), (fx, fy, 5, 3))
        pygame.draw.ellipse(s, (180, 120, 240, fa // 2), (fx, fy, 5, 3), 1)
    # 유령 실루엣 (상체 - 머리+몸통, 투명하게 겹침)
    # 몸통 (아래로 갈수록 투명해지는 삼각형 실루엣)
    body_pts = [(12, 18), (20, 18), (22, 12), (16, 5), (10, 12)]
    pygame.draw.polygon(s, (160, 100, 220, 160), body_pts)
    pygame.draw.polygon(s, (200, 140, 255, 100), body_pts, 1)
    # 하체 흐릿한 잔상 (유령 꼬리)
    pygame.draw.polygon(s, (130, 80, 190, 80), [(10, 17), (16, 20), (22, 17)])
    # 귀신 눈 2개 (빨간 빛)
    pygame.draw.circle(s, (255, 50, 50), (13, 10), 2)
    pygame.draw.circle(s, (255, 50, 50), (19, 10), 2)
    pygame.draw.circle(s, (255, 180, 180), (13, 10), 1)
    pygame.draw.circle(s, (255, 180, 180), (19, 10), 1)
    # 보라색 오라 파동 (유령 주변)
    pygame.draw.arc(s, (140, 70, 220, 70), (6, 4, 20, 16), 0.3, 2.8, 1)
    pygame.draw.arc(s, (100, 50, 180, 40), (4, 2, 24, 20), 0.5, 2.6, 1)
    return s


# ===== 크라켄 (kraken) 스킬 =====

def _icon_tentacle_wrap() -> pygame.Surface:
    """촉수 휘감기 - 촉수가 감싸는 형태"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경
    pygame.draw.circle(s, (15, 40, 50), (16, 16), 15)
    pygame.draw.circle(s, (30, 70, 80), (16, 16), 15, 1)
    # 촉수 커브 (왼쪽에서 감싸기)
    points_outer = [(6, 8), (8, 12), (12, 18), (18, 22), (24, 20), (26, 14), (22, 8)]
    pygame.draw.lines(s, (60, 160, 180), False, points_outer, 3)
    # 안쪽 촉수
    points_inner = [(26, 24), (22, 26), (14, 24), (10, 18), (12, 12)]
    pygame.draw.lines(s, (40, 130, 150), False, points_inner, 2)
    # 빨판
    for px, py in [(8, 12), (12, 18), (18, 22), (22, 26)]:
        pygame.draw.circle(s, (80, 200, 220), (px, py), 2)
        pygame.draw.circle(s, (40, 120, 140), (px, py), 1)
    return s


def _icon_abyss_ink() -> pygame.Surface:
    """심해의 먹물 - 먹물 스플래시"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경
    pygame.draw.circle(s, (8, 8, 30), (16, 16), 15)
    pygame.draw.circle(s, (20, 20, 60), (16, 16), 15, 1)
    # 중앙 먹물 방울
    pygame.draw.circle(s, (15, 10, 50), (16, 15), 7)
    pygame.draw.circle(s, (30, 20, 70), (16, 15), 7, 1)
    # 스플래시 방울들
    splash_pos = [(8, 8), (24, 7), (6, 20), (26, 22), (12, 26), (22, 26)]
    for i, (px, py) in enumerate(splash_pos):
        r = 3 - (i % 2)
        pygame.draw.circle(s, (20, 15, 55), (px, py), r)
    # 보라 프린지
    pygame.draw.circle(s, (80, 40, 120, 100), (16, 15), 9, 2)
    return s


# ===== 키르케/크로노스 (chronos) 스킬 =====

def _icon_gravity_control() -> pygame.Surface:
    """중력가속 - 하향 화살표 + 중력 고리"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경
    pygame.draw.circle(s, (35, 20, 55), (16, 16), 15)
    pygame.draw.circle(s, (60, 40, 90), (16, 16), 15, 1)
    # 하향 화살표 3개 (위에서 아래로)
    for i in range(3):
        y_base = 6 + i * 8
        alpha = 255 - i * 50
        color = (150 + i * 30, 80, 200, alpha)
        # 화살표 V 형태
        pygame.draw.line(s, color, (10, y_base), (16, y_base + 5), 2)
        pygame.draw.line(s, color, (22, y_base), (16, y_base + 5), 2)
    # 중력 왜곡 고리
    pygame.draw.ellipse(s, (120, 80, 160, 80), (6, 22, 20, 6), 1)
    pygame.draw.ellipse(s, (140, 100, 180, 60), (8, 24, 16, 4), 1)
    return s


def _icon_dwarf_magic() -> pygame.Surface:
    """난쟁이마술 - 축소 마법 스파클"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경
    pygame.draw.circle(s, (40, 20, 60), (16, 16), 15)
    pygame.draw.circle(s, (70, 40, 100), (16, 16), 15, 1)
    # 큰 별 (축소 심볼)
    _draw_star(s, 16, 14, 8, 4, (180, 120, 240))
    # 작은 별 (축소된 결과)
    _draw_star(s, 24, 22, 4, 2, (220, 180, 255))
    # 축소 화살표 (큰→작은)
    pygame.draw.line(s, (255, 255, 180), (18, 16), (22, 20), 1)
    pygame.draw.line(s, (255, 255, 180), (22, 20), (20, 20), 1)
    pygame.draw.line(s, (255, 255, 180), (22, 20), (22, 18), 1)
    # 스파클 입자
    for px, py in [(8, 8), (24, 6), (6, 22), (10, 26)]:
        pygame.draw.circle(s, (255, 255, 200), (px, py), 1)
    return s


# ===== 오니마루 (onimaru) 스킬 =====

def _icon_hellfire() -> pygame.Surface:
    """도깨비불 - 청록색 도깨비불"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경
    pygame.draw.circle(s, (15, 30, 35), (16, 16), 15)
    pygame.draw.circle(s, (30, 60, 70), (16, 16), 15, 1)
    # 도깨비불 본체 (청록)
    flame_points = [(16, 6), (20, 12), (22, 18), (20, 24), (16, 26), (12, 24), (10, 18), (12, 12)]
    pygame.draw.polygon(s, (40, 160, 200), flame_points)
    pygame.draw.polygon(s, (60, 200, 240), flame_points, 2)
    # 내부 밝은 코어
    inner_points = [(16, 10), (18, 14), (19, 18), (17, 22), (15, 22), (13, 18), (14, 14)]
    pygame.draw.polygon(s, (100, 220, 255), inner_points)
    # 도깨비 눈 (작은 점 2개)
    pygame.draw.circle(s, (255, 100, 100), (14, 16), 1)
    pygame.draw.circle(s, (255, 100, 100), (18, 16), 1)
    return s


def _icon_horn_charge() -> pygame.Surface:
    """뿔 박치기 - 붉은 뿔 돌진"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경
    pygame.draw.circle(s, (50, 15, 20), (16, 16), 15)
    pygame.draw.circle(s, (80, 30, 35), (16, 16), 15, 1)
    # 뿔 (삼각형, 위를 향함)
    horn_points = [(16, 4), (20, 18), (12, 18)]
    pygame.draw.polygon(s, (200, 60, 60), horn_points)
    pygame.draw.polygon(s, (240, 100, 80), horn_points, 2)
    # 뿔 디테일 줄무늬
    pygame.draw.line(s, (180, 50, 40), (14, 12), (18, 12), 1)
    pygame.draw.line(s, (180, 50, 40), (15, 9), (17, 9), 1)
    # 충격파 라인
    for i in range(3):
        y = 20 + i * 3
        w = 6 + i * 3
        alpha = 200 - i * 50
        pygame.draw.line(s, (255, 180, 60, alpha), (16 - w, y), (16 + w, y), 1)
    # 이동선
    pygame.draw.line(s, (255, 200, 100, 150), (8, 24), (8, 28), 1)
    pygame.draw.line(s, (255, 200, 100, 150), (16, 24), (16, 28), 1)
    pygame.draw.line(s, (255, 200, 100, 150), (24, 24), (24, 28), 1)
    return s


# ===== 연화/마리아 (maria) 스킬 =====

def _icon_puppet_control() -> pygame.Surface:
    """꼭두각시 조종 - 십자 조종대 + 줄"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경
    pygame.draw.circle(s, (50, 30, 45), (16, 16), 15)
    pygame.draw.circle(s, (80, 50, 70), (16, 16), 15, 1)
    # 십자 조종대 (상단)
    pygame.draw.line(s, (180, 140, 100), (8, 8), (24, 8), 3)   # 가로
    pygame.draw.line(s, (180, 140, 100), (16, 5), (16, 11), 3)  # 세로
    # 줄 4개 (조종대→하단)
    string_color = (200, 140, 180)
    pygame.draw.line(s, string_color, (10, 8), (10, 24), 1)
    pygame.draw.line(s, string_color, (14, 8), (12, 24), 1)
    pygame.draw.line(s, string_color, (18, 8), (20, 24), 1)
    pygame.draw.line(s, string_color, (22, 8), (22, 24), 1)
    # 인형 몸체 (하단 간략)
    pygame.draw.circle(s, (200, 150, 180), (16, 24), 3)
    pygame.draw.line(s, (200, 150, 180), (16, 27), (16, 28), 1)
    return s


def _icon_doll_curse() -> pygame.Surface:
    """인형의 저주 - 저주 인형 + 보라 오라"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경
    pygame.draw.circle(s, (45, 15, 35), (16, 16), 15)
    pygame.draw.circle(s, (70, 30, 55), (16, 16), 15, 1)
    # 인형 몸체
    pygame.draw.circle(s, (160, 100, 140), (16, 12), 5)  # 머리
    pygame.draw.rect(s, (160, 100, 140), (13, 17, 6, 8))  # 몸
    # X 눈
    pygame.draw.line(s, (255, 80, 80), (14, 10), (16, 12), 1)
    pygame.draw.line(s, (255, 80, 80), (16, 10), (14, 12), 1)
    pygame.draw.line(s, (255, 80, 80), (17, 10), (19, 12), 1)
    pygame.draw.line(s, (255, 80, 80), (19, 10), (17, 12), 1)
    # 저주 오라
    pygame.draw.circle(s, (140, 60, 180, 60), (16, 14), 10, 2)
    pygame.draw.circle(s, (180, 80, 220, 40), (16, 14), 12, 1)
    # 보라 불꽃 입자
    for px, py in [(8, 8), (24, 6), (6, 20), (26, 18)]:
        pygame.draw.circle(s, (160, 80, 200), (px, py), 1)
    return s


# ===== 이그니스 (ignis) 스킬 =====

def _icon_dragon_breath() -> pygame.Surface:
    """드래곤 브레스 - 용 머리에서 뿜어져 나오는 화염 브레스"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경 (깊은 암적색 + 열기 글로우)
    pygame.draw.circle(s, (50, 15, 8), (16, 16), 15)
    pygame.draw.circle(s, (80, 30, 12), (16, 16), 15, 1)
    # 열기 글로우 (중앙~우측으로 퍼지는 열복사)
    heat_glow = pygame.Surface((32, 32), pygame.SRCALPHA)
    pygame.draw.circle(heat_glow, (255, 80, 20, 25), (22, 16), 12)
    pygame.draw.circle(heat_glow, (255, 120, 30, 15), (26, 16), 8)
    s.blit(heat_glow, (0, 0))

    # === 화염 브레스 (좌측 입에서 우측으로 퍼지는 콘 형태) ===
    # 최외곽 불꽃 (짙은 적색 + 검은 연기 테두리)
    flame_smoke = [(7, 16), (12, 6), (20, 3), (28, 5), (30, 16), (28, 27), (20, 29), (12, 26)]
    pygame.draw.polygon(s, (120, 25, 5), flame_smoke)
    # 외부 불꽃 (붉은 오렌지)
    flame_outer = [(8, 16), (13, 8), (20, 5), (27, 7), (29, 16), (27, 25), (20, 27), (13, 24)]
    pygame.draw.polygon(s, (210, 55, 15), flame_outer)
    # 중간 불꽃 (오렌지)
    flame_mid = [(9, 16), (14, 10), (20, 8), (25, 10), (27, 16), (25, 22), (20, 24), (14, 22)]
    pygame.draw.polygon(s, (240, 130, 25), flame_mid)
    # 내부 불꽃 (밝은 주황~노랑)
    flame_inner = [(10, 16), (15, 12), (20, 11), (23, 13), (24, 16), (23, 19), (20, 21), (15, 20)]
    pygame.draw.polygon(s, (255, 190, 50), flame_inner)
    # 코어 (흰노랑 - 가장 뜨거운 부분)
    flame_core = [(11, 16), (15, 14), (19, 13), (21, 16), (19, 19), (15, 18)]
    pygame.draw.polygon(s, (255, 240, 150), flame_core)
    # 초고온 코어 중심
    pygame.draw.circle(s, (255, 255, 220), (12, 16), 2)
    pygame.draw.circle(s, (255, 255, 250), (12, 16), 1)

    # === 용 머리 실루엣 (좌측, 불을 내뿜는 형태) ===
    head_dark = (80, 35, 15)
    head_mid = (110, 55, 20)
    head_light = (140, 75, 30)
    # 용 머리 윤곽 (옆모습 - 위턱+아래턱 벌린 상태)
    # 윗머리+뿔
    pygame.draw.polygon(s, head_dark, [(2, 10), (4, 6), (6, 5), (5, 8), (8, 10), (8, 14), (2, 14)])
    # 아래턱
    pygame.draw.polygon(s, head_dark, [(2, 18), (8, 18), (8, 22), (6, 23), (4, 22), (2, 20)])
    # 머리 디테일 (비늘 느낌)
    pygame.draw.line(s, head_mid, (3, 9), (5, 9), 1)
    pygame.draw.line(s, head_mid, (3, 12), (6, 12), 1)
    # 뿔 하이라이트
    pygame.draw.line(s, head_light, (4, 6), (6, 5), 1)
    # 눈 (분노의 노란 눈)
    pygame.draw.circle(s, (255, 200, 40), (5, 11), 1)
    pygame.draw.circle(s, (255, 255, 180), (5, 11), 0)
    # 콧구멍에서 나오는 연기
    pygame.draw.circle(s, (180, 80, 30, 100), (7, 13), 1)
    pygame.draw.circle(s, (160, 60, 20, 80), (7, 19), 1)

    # === 불씨/엠버 파티클 (화염 주변에 떠다니는 불씨) ===
    ember_positions = [(18, 4), (26, 9), (29, 14), (28, 22), (22, 27), (15, 5), (25, 4)]
    for i, (ex, ey) in enumerate(ember_positions):
        c = [(255, 160, 40), (255, 200, 60), (255, 120, 20)][i % 3]
        pygame.draw.circle(s, (*c, 200 - i * 15), (ex, ey), 1)

    # 화염 끝 갈래 (우측 끝에서 갈라지는 불꽃 혀)
    pygame.draw.line(s, (255, 140, 30, 160), (27, 8), (30, 5), 1)
    pygame.draw.line(s, (255, 140, 30, 160), (28, 16), (31, 16), 1)
    pygame.draw.line(s, (255, 140, 30, 160), (27, 24), (30, 27), 1)
    return s


def _icon_dragon_wing() -> pygame.Surface:
    """용의 날개 - 펼쳐진 용 날개 + 바람 이펙트 + 비늘 디테일"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경 (깊은 갈색/금색 톤 - 드래곤 테마)
    pygame.draw.circle(s, (40, 25, 12), (16, 16), 15)
    pygame.draw.circle(s, (80, 55, 25), (16, 16), 15, 1)
    # 배경 글로우 (날개 주변 오라)
    glow = pygame.Surface((32, 32), pygame.SRCALPHA)
    pygame.draw.circle(glow, (255, 160, 40, 20), (14, 14), 13)
    s.blit(glow, (0, 0))

    # === 날개 색상 팔레트 ===
    wing_dark = (130, 70, 25)        # 어두운 갈색 (그림자)
    wing_base = (185, 115, 45)       # 기본 날개막 색
    wing_mid = (210, 145, 55)        # 중간 톤
    wing_light = (240, 185, 80)      # 밝은 하이라이트
    wing_glow = (255, 220, 120)      # 금빛 글로우
    bone_color = (160, 100, 40)      # 뼈대 색
    bone_light = (200, 150, 70)      # 뼈대 하이라이트

    # === 왼쪽 날개 (메인 - 크게 펼침) ===
    # 날개막 전체 실루엣 (그림자)
    wing_L_full = [(5, 24), (4, 18), (3, 12), (5, 6), (9, 3), (14, 4),
                   (17, 7), (18, 11), (17, 16), (15, 21), (12, 25)]
    pygame.draw.polygon(s, wing_dark, wing_L_full)

    # 날개막 섹션 1 (상단 - 가장 큰 막)
    section1 = [(5, 6), (9, 3), (14, 4), (17, 7), (12, 10), (7, 12)]
    pygame.draw.polygon(s, wing_base, section1)
    pygame.draw.polygon(s, wing_mid, [(6, 7), (10, 4), (13, 5), (16, 7), (12, 9), (8, 11)])

    # 날개막 섹션 2 (중단)
    section2 = [(4, 12), (7, 12), (12, 10), (17, 7), (18, 11), (17, 16), (12, 16), (6, 16)]
    pygame.draw.polygon(s, wing_base, section2)
    pygame.draw.polygon(s, wing_mid, [(5, 13), (8, 13), (13, 11), (17, 9), (17, 14), (13, 15), (7, 15)])

    # 날개막 섹션 3 (하단)
    section3 = [(4, 16), (6, 16), (12, 16), (17, 16), (15, 21), (12, 25), (5, 24)]
    pygame.draw.polygon(s, wing_base, section3)
    pygame.draw.polygon(s, (175, 105, 40), [(5, 17), (7, 17), (13, 17), (14, 20), (11, 23), (6, 22)])

    # === 날개 뼈대 (3개의 갈비뼈 구조) ===
    # 메인 뼈대 (어깨→상단 끝)
    pygame.draw.line(s, bone_color, (8, 22), (9, 3), 2)
    pygame.draw.line(s, bone_light, (8, 22), (9, 3), 1)
    # 두 번째 뼈대 (어깨→중단)
    pygame.draw.line(s, bone_color, (8, 22), (17, 8), 2)
    pygame.draw.line(s, bone_light, (9, 21), (17, 8), 1)
    # 세 번째 뼈대 (어깨→하단 끝)
    pygame.draw.line(s, bone_color, (8, 22), (17, 16), 2)
    pygame.draw.line(s, bone_light, (9, 21), (16, 16), 1)

    # 뼈대 관절 마디 표시
    for jx, jy in [(9, 6), (12, 10), (14, 15), (10, 14)]:
        pygame.draw.circle(s, bone_light, (jx, jy), 1)

    # 어깨 관절 (두꺼운 원)
    pygame.draw.circle(s, bone_color, (8, 22), 3)
    pygame.draw.circle(s, bone_light, (8, 22), 2)
    pygame.draw.circle(s, wing_glow, (8, 22), 1)

    # === 날개막 하이라이트 (빛 반사) ===
    pygame.draw.line(s, wing_light, (7, 8), (12, 5), 1)
    pygame.draw.line(s, wing_light, (6, 14), (14, 12), 1)
    pygame.draw.line(s, wing_glow, (8, 5), (11, 4), 1)

    # === 비늘 디테일 (어깨~몸통 부근) ===
    scale_positions = [(7, 26), (9, 27), (6, 28), (8, 29), (10, 28)]
    for sx, sy in scale_positions:
        if 0 <= sy < 32:
            pygame.draw.circle(s, wing_mid, (sx, sy), 1)
            pygame.draw.circle(s, wing_dark, (sx, sy + 1), 1)

    # === 바람 이펙트 (우측 - 날갯짓으로 인한 돌풍) ===
    wind_colors = [
        (220, 235, 255, 140),
        (200, 220, 255, 110),
        (180, 210, 255, 80),
        (160, 200, 250, 50),
    ]
    # 바람선 (곡선 형태 - 날개에서 우하단으로 퍼짐)
    wind_lines = [
        [(19, 8), (22, 7), (26, 8), (29, 7)],
        [(20, 12), (23, 11), (27, 12), (30, 11)],
        [(19, 17), (23, 16), (27, 17), (30, 16)],
        [(18, 22), (22, 21), (26, 22), (29, 21)],
    ]
    for i, pts in enumerate(wind_lines):
        c = wind_colors[i]
        pygame.draw.lines(s, c, False, pts, 1)
        # 바람 끝 화살촉
        ex, ey = pts[-1]
        pygame.draw.line(s, c, (ex - 2, ey - 1), (ex, ey), 1)
        pygame.draw.line(s, c, (ex - 2, ey + 1), (ex, ey), 1)

    # 바람 파티클 (작은 점들)
    for px, py in [(24, 9), (28, 13), (25, 19), (22, 24), (30, 9)]:
        pygame.draw.circle(s, (200, 225, 255, 100), (px, py), 1)

    # === 금빛 용기 파티클 (버프 스킬 느낌) ===
    for px, py in [(20, 5), (26, 15), (22, 26)]:
        pygame.draw.circle(s, (255, 220, 80, 120), (px, py), 1)

    # 외곽 글로우 강조
    pygame.draw.circle(s, (255, 200, 80, 40), (16, 16), 14, 1)
    return s


# ===== 마리/기어 (gear) 스킬 =====

def _icon_steam_barrier() -> pygame.Surface:
    """스팀 배리어 - 배리어 + 증기"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경
    pygame.draw.circle(s, (40, 30, 20), (16, 16), 15)
    pygame.draw.circle(s, (70, 55, 35), (16, 16), 15, 1)
    # 배리어 (수평 반원형 방패)
    pygame.draw.arc(s, (160, 130, 80), (4, 8, 24, 20), 0.5, 2.6, 3)
    pygame.draw.arc(s, (200, 170, 100), (4, 8, 24, 20), 0.5, 2.6, 1)
    # 방패 중앙 기어 모양
    pygame.draw.circle(s, (140, 100, 60), (16, 16), 4)
    pygame.draw.circle(s, (180, 140, 80), (16, 16), 4, 1)
    pygame.draw.circle(s, (100, 70, 40), (16, 16), 2)
    # 증기 이펙트 (상단)
    steam_positions = [(10, 6), (16, 4), (22, 6)]
    for px, py in steam_positions:
        pygame.draw.circle(s, (220, 220, 240, 100), (px, py), 2)
        pygame.draw.circle(s, (200, 200, 220, 60), (px, py - 2), 1)
    return s


def _icon_oil_spill() -> pygame.Surface:
    """기름 투척 - 기름 방울 + 웅덩이"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경
    pygame.draw.circle(s, (20, 18, 12), (16, 16), 15)
    pygame.draw.circle(s, (40, 35, 25), (16, 16), 15, 1)
    # 기름 방울 (비행 중)
    pygame.draw.circle(s, (50, 40, 25), (12, 10), 4)
    pygame.draw.circle(s, (70, 55, 35), (12, 10), 4, 1)
    # 하이라이트
    pygame.draw.circle(s, (90, 80, 50), (11, 9), 1)
    # 두 번째 방울
    pygame.draw.circle(s, (50, 40, 25), (20, 8), 3)
    pygame.draw.circle(s, (70, 55, 35), (20, 8), 3, 1)
    # 웅덩이 (하단)
    pygame.draw.ellipse(s, (40, 35, 20), (6, 22, 20, 6))
    pygame.draw.ellipse(s, (60, 50, 30), (6, 22, 20, 6), 1)
    # 오일 광택
    pygame.draw.ellipse(s, (80, 100, 60, 60), (10, 23, 6, 3))
    return s


# ===== 쿠로카게 (kurokage) 스킬 =====

def _icon_shadow_clone() -> pygame.Surface:
    """그림자분신 - 닌자 실루엣 2개"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경
    pygame.draw.circle(s, (18, 18, 28), (16, 16), 15)
    pygame.draw.circle(s, (35, 35, 50), (16, 16), 15, 1)
    # 뒤쪽 분신 (반투명)
    _draw_ninja_silhouette(s, 18, 14, (50, 50, 70, 120))
    # 앞쪽 본체 (진하게)
    _draw_ninja_silhouette(s, 12, 16, (60, 60, 90))
    # 잔상 효과 선
    pygame.draw.line(s, (80, 80, 120, 80), (22, 10), (26, 8), 1)
    pygame.draw.line(s, (80, 80, 120, 60), (24, 14), (28, 12), 1)
    return s


def _icon_illusion_shuriken() -> pygame.Surface:
    """환영수리검 - 4각 수리검 + 잔상"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경
    pygame.draw.circle(s, (25, 25, 40), (16, 16), 15)
    pygame.draw.circle(s, (45, 45, 65), (16, 16), 15, 1)
    # 잔상 수리검 (반투명)
    _draw_shuriken(s, 20, 12, 5, (100, 100, 140, 80))
    # 메인 수리검
    _draw_shuriken(s, 14, 16, 7, (140, 140, 180))
    # 중앙 구멍
    pygame.draw.circle(s, (80, 80, 120), (14, 16), 2)
    # 이동 잔상 선
    for i in range(3):
        alpha = 120 - i * 30
        pygame.draw.line(s, (100, 120, 180, alpha), (22 + i * 2, 10 + i), (24 + i * 2, 12 + i), 1)
    return s


# ===== 헬퍼 함수 =====

def _draw_star(surface, cx, cy, outer_r, inner_r, color, points=5):
    """별 모양 그리기"""
    pts = []
    for i in range(points * 2):
        angle = math.pi / 2 + i * math.pi / points
        r = outer_r if i % 2 == 0 else inner_r
        px = cx + r * math.cos(angle)
        py = cy - r * math.sin(angle)
        pts.append((int(px), int(py)))
    if len(pts) >= 3:
        pygame.draw.polygon(surface, color, pts)


def _draw_ninja_silhouette(surface, cx, cy, color):
    """닌자 실루엣 그리기"""
    # 머리
    pygame.draw.circle(surface, color, (cx, cy - 4), 4)
    # 몸통
    pygame.draw.rect(surface, color, (cx - 3, cy, 6, 7))
    # 머리띠 (눈 부분)
    line_color = color[:3] if len(color) >= 3 else color
    pygame.draw.line(surface, (*line_color[:3], 200), (cx - 5, cy - 4), (cx + 5, cy - 4), 1)


def _draw_shuriken(surface, cx, cy, size, color):
    """수리검 (4각 별) 그리기"""
    pts = [
        (cx, cy - size),       # 상
        (cx + size // 3, cy - size // 3),
        (cx + size, cy),       # 우
        (cx + size // 3, cy + size // 3),
        (cx, cy + size),       # 하
        (cx - size // 3, cy + size // 3),
        (cx - size, cy),       # 좌
        (cx - size // 3, cy - size // 3),
    ]
    if len(pts) >= 3:
        pygame.draw.polygon(surface, color, pts)


# ===== 벤시 (banshee) 스킬 =====

def _icon_charm() -> pygame.Surface:
    """매혹 - 유령 하트 + 소용돌이 + 최면 눈"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 어두운 청보라 배경
    pygame.draw.circle(s, (25, 20, 50), (16, 16), 15)
    pygame.draw.circle(s, (50, 40, 80), (16, 16), 15, 1)
    # 소용돌이 (최면 효과)
    for i in range(3):
        r = 11 - i * 3
        start_angle = i * 1.2
        pygame.draw.arc(s, (140, 80, 200, 180 - i * 40),
                       (16 - r, 16 - r, r * 2, r * 2),
                       start_angle, start_angle + 3.5, 2)
    # 하트 (중앙, 핑크+시안 그라데이션 느낌)
    # 하트 왼쪽 볼
    pygame.draw.circle(s, (200, 80, 160), (13, 12), 4)
    # 하트 오른쪽 볼
    pygame.draw.circle(s, (180, 100, 200), (19, 12), 4)
    # 하트 아래쪽 꼭짓점
    pygame.draw.polygon(s, (190, 90, 180), [
        (9, 14), (16, 22), (23, 14),
    ])
    # 하트 하이라이트
    pygame.draw.circle(s, (240, 150, 210), (12, 11), 2)
    # 유령빛 글로우
    pygame.draw.circle(s, (100, 200, 240, 60), (16, 16), 10)
    # 스파크
    for px, py in [(8, 8), (24, 8), (16, 26)]:
        pygame.draw.circle(s, (200, 220, 255), (px, py), 1)
    return s


def _icon_riddle_trick() -> pygame.Surface:
    """수수께끼 묘기 - ? 물음표 랜덤박스 (조커 테마)"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경 (조커 레드+골드 테마)
    pygame.draw.circle(s, (50, 15, 25), (16, 16), 15)
    pygame.draw.circle(s, (180, 60, 60), (16, 16), 15, 1)

    # 랜덤박스 본체 (금색 상자)
    box_color = (220, 180, 60)
    box_dark = (160, 120, 30)
    box_light = (255, 220, 100)
    box_rect = (7, 11, 18, 14)
    pygame.draw.rect(s, box_dark, box_rect, border_radius=2)
    pygame.draw.rect(s, box_color, (8, 12, 16, 12), border_radius=1)
    # 상자 뚜껑 (약간 열린 느낌)
    pygame.draw.rect(s, box_light, (6, 10, 20, 4), border_radius=2)
    pygame.draw.rect(s, box_dark, (6, 10, 20, 4), 1, border_radius=2)
    # 상자 리본 (빨강)
    pygame.draw.line(s, (220, 50, 60), (16, 10), (16, 24), 2)
    pygame.draw.line(s, (220, 50, 60), (6, 12), (26, 12), 2)

    # 큰 ? 물음표 (상자 위에 떠오름 - 흰색+골드 글로우)
    # ? 곡선 부분
    pygame.draw.arc(s, (255, 240, 120), (11, 1, 10, 10), 0.3, 3.5, 2)
    # ? 세로 줄기
    pygame.draw.line(s, (255, 240, 120), (16, 8), (16, 11), 2)
    # ? 점
    pygame.draw.circle(s, (255, 255, 200), (16, 14), 1)
    # ? 글로우
    glow_surf = pygame.Surface((12, 16), pygame.SRCALPHA)
    pygame.draw.circle(glow_surf, (255, 220, 80, 40), (6, 8), 7)
    s.blit(glow_surf, (10, 0), special_flags=pygame.BLEND_ADD)

    # 다색 스파클 (랜덤 스킬 상징 - 상자에서 뿜어져 나옴)
    sparkle_colors = [
        (255, 100, 100),  # 빨강
        (100, 255, 100),  # 초록
        (100, 150, 255),  # 파랑
        (255, 255, 100),  # 노랑
        (255, 100, 255),  # 마젠타
    ]
    sparkle_pos = [(6, 5), (26, 5), (4, 16), (28, 16), (16, 27)]
    for (px, py), c in zip(sparkle_pos, sparkle_colors):
        pygame.draw.circle(s, (*c, 180), (px, py), 1)

    # 테두리 강조
    pygame.draw.circle(s, (255, 200, 80, 80), (16, 16), 15, 1)
    return s


# ===== 네크로 (necro) 스킬 =====

def _icon_ghost_summon() -> pygame.Surface:
    """유령소환 - 유령 패들 2개 + 소환진"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경 원 (어두운 청록)
    pygame.draw.circle(s, (20, 35, 30), (16, 16), 15)
    pygame.draw.circle(s, (60, 110, 95), (16, 16), 15, 1)

    # 소환진 (하단 반원)
    pygame.draw.arc(s, (80, 180, 160, 140), (6, 20, 20, 10), 3.14, 6.28, 2)
    # 소환진 내부 작은 원
    pygame.draw.circle(s, (60, 150, 130, 80), (16, 24), 3, 1)

    # 유령 1 (왼쪽)
    ghost1_x, ghost1_y = 9, 10
    pygame.draw.ellipse(s, (80, 180, 160, 180), (ghost1_x - 4, ghost1_y - 3, 8, 10))
    # 유령1 물결 하단
    for i in range(3):
        wx = ghost1_x - 3 + i * 3
        pygame.draw.ellipse(s, (80, 180, 160, 130), (wx, ghost1_y + 5, 3, 4))
    # 유령1 눈
    pygame.draw.circle(s, (140, 255, 230), (ghost1_x - 1, ghost1_y), 1)
    pygame.draw.circle(s, (140, 255, 230), (ghost1_x + 2, ghost1_y), 1)

    # 유령 2 (오른쪽)
    ghost2_x, ghost2_y = 23, 10
    pygame.draw.ellipse(s, (80, 180, 160, 180), (ghost2_x - 4, ghost2_y - 3, 8, 10))
    for i in range(3):
        wx = ghost2_x - 3 + i * 3
        pygame.draw.ellipse(s, (80, 180, 160, 130), (wx, ghost2_y + 5, 3, 4))
    pygame.draw.circle(s, (140, 255, 230), (ghost2_x - 1, ghost2_y), 1)
    pygame.draw.circle(s, (140, 255, 230), (ghost2_x + 2, ghost2_y), 1)

    # 스파클
    for px, py in [(16, 6), (6, 18), (26, 18)]:
        pygame.draw.circle(s, (180, 255, 230), (px, py), 1)

    return s


def _icon_skeleton_archer() -> pygame.Surface:
    """해골 궁수 - 활을 당기는 해골"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경 원 (어두운 녹색)
    pygame.draw.circle(s, (20, 35, 25), (16, 16), 15)
    pygame.draw.circle(s, (60, 90, 60), (16, 16), 15, 1)

    bone = (210, 200, 175)
    eye_green = (100, 255, 130)
    bow_brown = (140, 100, 60)

    # 두개골
    pygame.draw.circle(s, bone, (12, 10), 5)
    # 눈구멍 (초록빛)
    pygame.draw.circle(s, eye_green, (10, 9), 1)
    pygame.draw.circle(s, eye_green, (14, 9), 1)

    # 척추 + 갈비뼈
    pygame.draw.line(s, bone, (12, 15), (12, 24), 1)
    for ry in [17, 20]:
        pygame.draw.line(s, (180, 170, 145), (9, ry), (15, ry), 1)

    # 다리
    pygame.draw.line(s, bone, (12, 24), (10, 29), 1)
    pygame.draw.line(s, bone, (12, 24), (14, 29), 1)

    # 활 (오른쪽)
    pygame.draw.arc(s, bow_brown, (18, 6, 8, 20), -1.2, 1.2, 2)

    # 시위 (당기는 상태)
    pygame.draw.line(s, (200, 200, 180), (22, 8), (16, 16), 1)
    pygame.draw.line(s, (200, 200, 180), (22, 24), (16, 16), 1)

    # 화살
    pygame.draw.line(s, bone, (15, 16), (26, 16), 1)
    # 화살촉
    pygame.draw.polygon(s, (180, 180, 160), [(27, 16), (25, 14), (25, 18)])

    # 팔 (활 잡는 쪽)
    pygame.draw.line(s, bone, (12, 17), (19, 15), 1)
    # 팔 (시위 당기는 쪽)
    pygame.draw.line(s, bone, (12, 18), (16, 16), 1)

    return s


def _icon_bone_barrier() -> pygame.Surface:
    """뼈 장막 - 날카로운 뼈 가시 장벽"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경 원 (어두운 보라/뼈색)
    pygame.draw.circle(s, (25, 15, 30), (16, 16), 15)
    pygame.draw.circle(s, (80, 60, 90), (16, 16), 15, 1)

    bone = (210, 200, 175)
    bone_dark = (160, 150, 125)
    bone_light = (235, 225, 205)
    purple_glow = (140, 80, 180, 100)

    # 뼈 장벽 베이스 (수평 바)
    pygame.draw.rect(s, bone_dark, (5, 17, 22, 3))
    pygame.draw.rect(s, bone, (5, 18, 22, 2))
    # 상단 하이라이트
    pygame.draw.line(s, bone_light, (6, 17), (26, 17), 1)

    # 뼈 가시들 (위쪽으로 솟아오름)
    spikes = [(7, 6), (11, 4), (16, 3), (21, 5), (25, 7)]
    for sx, top_y in spikes:
        # 가시 몸체
        pygame.draw.line(s, bone, (sx, 17), (sx, top_y), 2)
        # 뾰족한 끝
        pygame.draw.line(s, bone_light, (sx - 1, top_y + 2), (sx, top_y), 1)
        pygame.draw.line(s, bone_light, (sx + 1, top_y + 2), (sx, top_y), 1)
        # 마디 표시
        mid_y = (17 + top_y) // 2
        pygame.draw.line(s, bone_dark, (sx - 1, mid_y), (sx + 1, mid_y), 1)

    # 아래쪽 작은 가시들
    for sx, bot_y in [(8, 24), (13, 26), (19, 25), (24, 23)]:
        pygame.draw.line(s, bone_dark, (sx, 20), (sx, bot_y), 1)
        pygame.draw.circle(s, bone, (sx, bot_y), 1)

    # 보라색 마법 기운
    pygame.draw.circle(s, purple_glow, (10, 14), 3)
    pygame.draw.circle(s, purple_glow, (22, 14), 3)
    pygame.draw.circle(s, (120, 60, 160, 60), (16, 10), 2)

    # 두개골 장식 (중앙)
    pygame.draw.circle(s, bone, (16, 14), 3)
    pygame.draw.circle(s, (30, 15, 35), (15, 13), 1)  # 왼눈
    pygame.draw.circle(s, (30, 15, 35), (17, 13), 1)  # 오른눈

    return s


# ===== 조커 (joker) 스킬 =====

def _icon_balloon_wall() -> pygame.Surface:
    """익살스런파티 - 컬러풀한 풍선들"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경 원 (따뜻한 톤)
    pygame.draw.circle(s, (35, 25, 40), (16, 16), 15)
    pygame.draw.circle(s, (100, 70, 110), (16, 16), 15, 1)

    # 풍선들 (다양한 색상)
    balloons = [
        (8, 10, 5, (230, 70, 70)),      # 빨강
        (16, 8, 5, (255, 200, 50)),      # 노랑
        (24, 11, 5, (80, 200, 120)),     # 초록
        (12, 17, 4, (70, 140, 230)),     # 파랑
        (20, 16, 4, (200, 100, 220)),    # 보라
    ]
    for bx, by, br, bc in balloons:
        # 풍선 본체
        pygame.draw.ellipse(s, bc, (bx - br, by - int(br * 1.2), br * 2, int(br * 2.4)))
        # 하이라이트
        pygame.draw.circle(s, tuple(min(255, c + 60) for c in bc),
                         (bx - 1, by - 2), max(1, br // 2))
        # 줄
        pygame.draw.line(s, (180, 180, 180), (bx, by + br), (bx, by + br + 4), 1)

    # 꼭지점
    for bx, by, br, bc in balloons:
        knot_y = by + int(br * 1.0)
        pygame.draw.circle(s, tuple(max(0, c - 40) for c in bc), (bx, knot_y), 1)

    return s


def _icon_bomb_surprise() -> pygame.Surface:
    """폭탄 서프라이즈 - 도화선 달린 폭탄"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경 원 (위험한 빨강/주황)
    pygame.draw.circle(s, (40, 20, 15), (16, 16), 15)
    pygame.draw.circle(s, (120, 60, 40), (16, 16), 15, 1)

    # 폭탄 몸체 (검은 원)
    pygame.draw.circle(s, (40, 40, 40), (16, 18), 9)
    pygame.draw.circle(s, (80, 80, 80), (16, 18), 9, 1)
    # 하이라이트
    pygame.draw.circle(s, (80, 80, 90), (13, 15), 3)

    # 도화선
    pygame.draw.line(s, (160, 120, 60), (20, 12), (22, 7), 2)
    # 불꽃
    pygame.draw.circle(s, (255, 200, 50), (23, 5), 3)
    pygame.draw.circle(s, (255, 255, 150), (23, 5), 2)
    pygame.draw.circle(s, (255, 140, 30), (22, 4), 2)

    # 경고 느낌표
    pygame.draw.line(s, (255, 80, 50), (8, 10), (8, 16), 2)
    pygame.draw.circle(s, (255, 80, 50), (8, 19), 1)

    # 폭발 스파크
    for angle_deg in [0, 72, 144, 216, 288]:
        rad = math.radians(angle_deg)
        sx = 16 + int(math.cos(rad) * 13)
        sy = 18 + int(math.sin(rad) * 13)
        pygame.draw.circle(s, (255, 180, 60, 120), (sx, sy), 1)

    return s


def _icon_gatling_burst() -> pygame.Surface:
    """개틀링 버스트 - 회전하는 기관포 + 총알"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경 원 (건메탈 다크)
    pygame.draw.circle(s, (30, 35, 45), (16, 16), 15)
    pygame.draw.circle(s, (80, 90, 110), (16, 16), 15, 1)

    # 기관포 본체 (가로 배치)
    pygame.draw.rect(s, (60, 65, 75), (6, 13, 16, 8), border_radius=2)
    pygame.draw.rect(s, (90, 95, 105), (7, 14, 14, 6), border_radius=1)

    # 총열 3개
    for dy in [-2, 0, 2]:
        pygame.draw.line(s, (50, 52, 58), (22, 17 + dy), (29, 17 + dy), 2)
        # 총구 끝 점
        pygame.draw.circle(s, (40, 42, 48), (29, 17 + dy), 1)

    # 회전부 (원형)
    pygame.draw.circle(s, (75, 78, 85), (22, 17), 4)
    pygame.draw.circle(s, (100, 105, 115), (22, 17), 3)
    pygame.draw.circle(s, (65, 68, 78), (22, 17), 2)

    # 머즐 플래쉬 (오른쪽 끝)
    pygame.draw.circle(s, (255, 200, 80, 180), (30, 17), 3)
    pygame.draw.circle(s, (255, 255, 200, 200), (30, 17), 2)

    # 총알 궤적 (3발)
    for i, (bx, by) in enumerate([(28, 10), (26, 7), (30, 13)]):
        pygame.draw.circle(s, (255, 230, 100), (bx, by), 2)
        pygame.draw.circle(s, (255, 255, 200), (bx, by), 1)
        # 궤적 선
        pygame.draw.line(s, (255, 200, 80, 100),
                        (bx - 3, by + 2), (bx, by), 1)

    # LED 표시 (빨간색)
    pygame.draw.circle(s, (255, 50, 30), (8, 15), 2)
    pygame.draw.circle(s, (255, 150, 100), (8, 15), 1)

    return s


def _icon_sand_prison() -> pygame.Surface:
    """모래감옥 - 모래 벽으로 둘러싸인 감옥"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경 (사막 톤)
    pygame.draw.circle(s, (50, 40, 25), (16, 16), 15)
    pygame.draw.circle(s, (100, 80, 45), (16, 16), 15, 1)

    # 모래 감옥 벽 (좌우 세로 바)
    for x in [7, 24]:
        for y in range(5, 28, 3):
            r = 185 + (y % 5) * 8
            g = 155 + (y % 5) * 5
            b = 80 + (y % 5) * 5
            pygame.draw.rect(s, (r, g, b), (x - 1, y, 3, 2))
    # 상하 연결 바
    pygame.draw.line(s, (200, 170, 95), (7, 5), (24, 5), 2)
    pygame.draw.line(s, (200, 170, 95), (7, 27), (24, 27), 2)

    # 중앙에 갇힌 느낌 (작은 원)
    pygame.draw.circle(s, (160, 130, 80, 150), (16, 16), 5, 1)
    # 모래 파티클
    for px, py in [(11, 10), (20, 12), (13, 22), (21, 20)]:
        pygame.draw.circle(s, (210, 185, 110, 160), (px, py), 1)

    # 쇠사슬 느낌 X 표시
    pygame.draw.line(s, (180, 150, 80, 180), (10, 9), (22, 24), 1)
    pygame.draw.line(s, (180, 150, 80, 180), (22, 9), (10, 24), 1)

    return s


def _icon_sand_vortex() -> pygame.Surface:
    """모래회오리 - 나선형 모래 소용돌이 2개"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경 (사막 톤)
    pygame.draw.circle(s, (45, 38, 22), (16, 16), 15)
    pygame.draw.circle(s, (110, 90, 50), (16, 16), 15, 1)

    # 소용돌이 2개 (좌, 우)
    for center_x, center_y in [(11, 14), (22, 18)]:
        # 나선형 그리기
        for a_deg in range(0, 540, 20):
            rad = math.radians(a_deg)
            r = 7 * (1 - a_deg / 1080)
            if r < 1:
                break
            px = center_x + int(math.cos(rad) * r)
            py = center_y + int(math.sin(rad) * r)
            alpha = max(60, 220 - a_deg // 3)
            r_c = min(255, 190 + a_deg // 15)
            g_c = max(110, 165 - a_deg // 20)
            b_c = max(50, 90 - a_deg // 20)
            if 0 <= px < 32 and 0 <= py < 32:
                pygame.draw.circle(s, (r_c, g_c, b_c, alpha), (px, py), 1)

        # 소용돌이 중심
        pygame.draw.circle(s, (240, 210, 140), (center_x, center_y), 2)
        pygame.draw.circle(s, (255, 240, 200), (center_x, center_y), 1)

    # 모래 파티클 궤적
    for px, py in [(8, 8), (25, 10), (14, 24), (19, 7), (6, 20)]:
        pygame.draw.circle(s, (210, 185, 110, 120), (px, py), 1)

    # 화살표 느낌 (상대 방향으로 나아감)
    pygame.draw.line(s, (220, 190, 110, 180), (16, 6), (16, 3), 1)
    pygame.draw.line(s, (220, 190, 110, 180), (14, 5), (16, 3), 1)
    pygame.draw.line(s, (220, 190, 110, 180), (18, 5), (16, 3), 1)

    return s


# ===== 라 (ra) 스킬 =====

def _icon_solar_bolt() -> pygame.Surface:
    """천둥 낙뢰 - 황금 번개 + 태양 광휘"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경 (깊은 남색 - 폭풍 하늘)
    pygame.draw.circle(s, (15, 15, 45), (16, 16), 15)
    pygame.draw.circle(s, (40, 35, 80), (16, 16), 15, 1)

    # 태양 글로우 (상단 - 라의 태양 테마)
    pygame.draw.circle(s, (255, 200, 60, 50), (16, 8), 6)
    pygame.draw.circle(s, (255, 220, 100, 30), (16, 8), 8)

    # 메인 번개 지그재그 (상→하, 황금색 4단계 굵기)
    bolt_points = [(16, 4), (19, 10), (14, 13), (20, 19), (15, 22), (18, 28)]
    # 글로우 레이어 (넓은 발광)
    pygame.draw.lines(s, (255, 200, 60, 60), False, bolt_points, 5)
    # 외부 글로우
    pygame.draw.lines(s, (255, 180, 40, 120), False, bolt_points, 3)
    # 코어 외곽
    pygame.draw.lines(s, (255, 220, 80), False, bolt_points, 2)
    # 코어 (밝은 흰노랑)
    pygame.draw.lines(s, (255, 255, 200), False, bolt_points, 1)

    # 가지 번개 (왼쪽)
    branch_l = [(14, 13), (9, 16), (11, 19)]
    pygame.draw.lines(s, (255, 200, 80, 140), False, branch_l, 2)
    pygame.draw.lines(s, (255, 240, 160), False, branch_l, 1)

    # 가지 번개 (오른쪽)
    branch_r = [(20, 19), (25, 21), (23, 24)]
    pygame.draw.lines(s, (255, 200, 80, 140), False, branch_r, 2)
    pygame.draw.lines(s, (255, 240, 160), False, branch_r, 1)

    # 충격 스파크 (번개 하단 착탄점)
    for angle_deg in range(0, 360, 45):
        rad = math.radians(angle_deg)
        sx = 18 + int(math.cos(rad) * 5)
        sy = 28 + int(math.sin(rad) * 3)
        if 0 <= sx < 32 and 0 <= sy < 32:
            pygame.draw.circle(s, (255, 255, 180), (sx, sy), 1)

    # 태양 광선 (상단에서 방사)
    for angle_deg in [200, 250, 290, 340]:
        rad = math.radians(angle_deg)
        rx = 16 + int(math.cos(rad) * 4)
        ry = 8 + int(math.sin(rad) * 4)
        ex = 16 + int(math.cos(rad) * 7)
        ey = 8 + int(math.sin(rad) * 7)
        pygame.draw.line(s, (255, 220, 100, 140), (rx, ry), (ex, ey), 1)

    return s


def _icon_thunder_orb() -> pygame.Surface:
    """천둥 뇌구 - 육각형 프레임 + 에너지 구체 + 번개 아크"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    cx, cy = 16, 16

    # 배경 (어두운 남색)
    pygame.draw.circle(s, (10, 8, 30), (cx, cy), 15)

    # === 육각형 프레임 ===
    hex_r = 13  # 육각형 외접원 반지름
    hex_pts = []
    for i in range(6):
        ang = math.radians(60 * i - 90)  # 꼭짓점이 위에서 시작
        hx = cx + math.cos(ang) * hex_r
        hy = cy + math.sin(ang) * hex_r
        hex_pts.append((int(hx), int(hy)))

    # 육각형 외곽 글로우 (진한 파랑)
    pygame.draw.polygon(s, (20, 40, 100, 60), hex_pts)
    # 육각형 테두리 (밝은 파랑)
    pygame.draw.polygon(s, (60, 110, 200), hex_pts, 2)
    # 육각형 내부 밝은 테두리
    hex_inner_pts = []
    for i in range(6):
        ang = math.radians(60 * i - 90)
        hx = cx + math.cos(ang) * (hex_r - 2)
        hy = cy + math.sin(ang) * (hex_r - 2)
        hex_inner_pts.append((int(hx), int(hy)))
    pygame.draw.polygon(s, (40, 80, 160, 80), hex_inner_pts, 1)

    # === 에너지 구체 (중앙) ===
    # 외부 글로우
    pygame.draw.circle(s, (40, 100, 200, 40), (cx, cy), 8)
    pygame.draw.circle(s, (80, 160, 255, 60), (cx, cy), 6)
    # 구체 본체
    pygame.draw.circle(s, (120, 190, 255), (cx, cy), 5)
    pygame.draw.circle(s, (180, 220, 255), (cx, cy), 4)
    pygame.draw.circle(s, (220, 240, 255), (cx, cy), 3)
    # 밝은 코어
    pygame.draw.circle(s, (245, 250, 255), (cx, cy), 2)
    pygame.draw.circle(s, (255, 255, 255), (cx, cy - 1), 1)

    # === 구체에서 육각형 꼭짓점으로 번개 아크 6개 ===
    for i, (hx, hy) in enumerate(hex_pts):
        # 구체 표면 시작점
        ang = math.radians(60 * i - 90)
        sx = cx + int(math.cos(ang) * 5)
        sy = cy + int(math.sin(ang) * 5)
        # 중간 지그재그점 (살짝 어긋남)
        mid_ang = math.radians(60 * i - 90 + 12)
        mid_r = hex_r * 0.6
        mx = cx + int(math.cos(mid_ang) * mid_r)
        my = cy + int(math.sin(mid_ang) * mid_r)
        # 아크 글로우 (두꺼운 반투명)
        pygame.draw.line(s, (60, 130, 255, 100), (sx, sy), (mx, my), 2)
        pygame.draw.line(s, (60, 130, 255, 100), (mx, my), (hx, hy), 2)
        # 아크 코어 (가는 밝은 선)
        pygame.draw.line(s, (180, 220, 255), (sx, sy), (mx, my), 1)
        pygame.draw.line(s, (180, 220, 255), (mx, my), (hx, hy), 1)

    # 꼭짓점 스파크 (3개만)
    for i in [0, 2, 4]:
        px, py = hex_pts[i]
        if 0 <= px < 32 and 0 <= py < 32:
            pygame.draw.circle(s, (200, 230, 255), (px, py), 1)

    return s


# ===== 원숭이왕 (monkeyking) 스킬 =====

def _icon_banana_slice() -> pygame.Surface:
    """바나나 슬라이스 - 바나나 + 슬라이스 궤적"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경 원 (따뜻한 갈색 톤)
    pygame.draw.circle(s, (45, 35, 15), (16, 16), 15)
    pygame.draw.circle(s, (100, 80, 30), (16, 16), 15, 1)

    # 바나나 본체 (초승달 모양)
    peel_dark = (198, 156, 41)
    peel_mid = (227, 189, 52)
    peel_light = (247, 220, 89)
    stem_green = (154, 165, 67)
    tip_dark = (89, 60, 31)

    # 바나나 몸통 (커브 형태)
    body_outer = [(7, 18), (10, 12), (14, 9), (19, 8), (23, 10), (25, 14), (24, 18)]
    body_inner = [(24, 18), (23, 20), (20, 22), (15, 22), (11, 21), (8, 20), (7, 18)]
    body_full = body_outer + body_inner
    pygame.draw.polygon(s, peel_dark, body_full)

    # 밝은 부분 (상단 하이라이트)
    hl_outer = [(9, 16), (12, 11), (16, 9), (21, 9), (24, 12), (23, 16)]
    hl_inner = [(23, 16), (21, 18), (17, 19), (13, 18), (10, 17), (9, 16)]
    hl_full = hl_outer + hl_inner
    pygame.draw.polygon(s, peel_mid, hl_full)

    # 더 밝은 줄 (광택)
    pygame.draw.lines(s, peel_light, False,
                      [(11, 13), (15, 10), (20, 10), (23, 13)], 1)

    # 꼭지 (왼쪽 끝)
    pygame.draw.circle(s, stem_green, (7, 18), 2)

    # 끝 (오른쪽)
    pygame.draw.circle(s, tip_dark, (25, 14), 2)

    # 슬라이스 궤적 (대각선 칼날 효과 - 바나나를 자르는 느낌)
    # 밝은 황금색 궤적
    pygame.draw.line(s, (255, 240, 150), (5, 6), (27, 26), 2)
    pygame.draw.line(s, (255, 255, 200), (6, 5), (28, 25), 1)

    # 슬라이스 스파크 (궤적 위)
    for px, py in [(9, 9), (16, 16), (23, 23), (26, 25)]:
        pygame.draw.circle(s, (255, 255, 180), (px, py), 1)

    # 바나나 조각 파편 (슬라이스 결과)
    pygame.draw.polygon(s, peel_mid, [(4, 25), (7, 23), (9, 26)])  # 작은 조각 왼쪽
    pygame.draw.polygon(s, peel_mid, [(24, 4), (27, 6), (25, 8)])  # 작은 조각 오른쪽

    # 테두리 글로우
    pygame.draw.circle(s, (255, 220, 80, 60), (16, 16), 14, 1)

    return s


def _icon_wild_roar() -> pygame.Surface:
    """야생의 포효 - 포효하는 원숭이 입 + 황금 충격파 링"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경 원 (깊은 갈색/주황)
    pygame.draw.circle(s, (50, 30, 15), (16, 16), 15)
    pygame.draw.circle(s, (120, 80, 30), (16, 16), 15, 1)

    # 충격파 링 3개 (바깥→안 갈수록 밝게)
    ring_color_outer = (255, 180, 40, 60)
    ring_color_mid = (255, 200, 60, 100)
    ring_color_inner = (255, 220, 100, 160)
    pygame.draw.circle(s, ring_color_outer, (16, 16), 14, 2)
    pygame.draw.circle(s, ring_color_mid, (16, 16), 11, 2)
    pygame.draw.circle(s, ring_color_inner, (16, 16), 8, 1)

    # 원숭이 얼굴 실루엣 (중앙)
    face_brown = (140, 90, 40)
    face_light = (190, 140, 80)
    # 머리 윤곽
    pygame.draw.circle(s, face_brown, (16, 14), 6)
    # 얼굴 밝은 부분 (하단 턱 쪽)
    pygame.draw.circle(s, face_light, (16, 16), 4)

    # 크게 벌린 입 (포효!)
    mouth_points = [(12, 16), (16, 22), (20, 16)]
    pygame.draw.polygon(s, (60, 20, 10), mouth_points)
    # 입 안쪽 밝은 부분
    pygame.draw.polygon(s, (120, 40, 20), [(13, 17), (16, 21), (19, 17)])
    # 이빨 (위쪽)
    pygame.draw.line(s, (240, 230, 210), (13, 16), (14, 18), 1)
    pygame.draw.line(s, (240, 230, 210), (19, 16), (18, 18), 1)

    # 눈 (분노의 빛)
    pygame.draw.circle(s, (255, 200, 50), (13, 13), 2)
    pygame.draw.circle(s, (255, 255, 180), (13, 13), 1)
    pygame.draw.circle(s, (255, 200, 50), (19, 13), 2)
    pygame.draw.circle(s, (255, 255, 180), (19, 13), 1)

    # 충격파 방사선 (대각선 4방향)
    ray_color = (255, 220, 80, 140)
    for angle_deg in [45, 135, 225, 315]:
        rad = math.radians(angle_deg)
        sx = 16 + int(math.cos(rad) * 9)
        sy = 16 + int(math.sin(rad) * 9)
        ex = 16 + int(math.cos(rad) * 14)
        ey = 16 + int(math.sin(rad) * 14)
        pygame.draw.line(s, ray_color, (sx, sy), (ex, ey), 1)

    # 스파크 (충격파 끝)
    for angle_deg in [0, 90, 180, 270]:
        rad = math.radians(angle_deg)
        px = 16 + int(math.cos(rad) * 14)
        py = 16 + int(math.sin(rad) * 14)
        if 0 <= px < 32 and 0 <= py < 32:
            pygame.draw.circle(s, (255, 255, 200), (px, py), 1)

    return s
