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
    """드래곤 브레스 - 화염 콘"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경
    pygame.draw.circle(s, (55, 25, 10), (16, 16), 15)
    pygame.draw.circle(s, (90, 40, 15), (16, 16), 15, 1)
    # 화염 콘 (좌→우 방향)
    # 외부 불꽃 (빨강)
    flame_outer = [(6, 16), (14, 8), (26, 6), (28, 16), (26, 26), (14, 24)]
    pygame.draw.polygon(s, (200, 50, 20), flame_outer)
    # 중간 불꽃 (오렌지)
    flame_mid = [(8, 16), (14, 10), (24, 10), (26, 16), (24, 22), (14, 22)]
    pygame.draw.polygon(s, (230, 120, 30), flame_mid)
    # 내부 불꽃 (노랑)
    flame_inner = [(10, 16), (15, 12), (22, 13), (23, 16), (22, 19), (15, 20)]
    pygame.draw.polygon(s, (255, 200, 60), flame_inner)
    # 코어 (흰노랑)
    pygame.draw.circle(s, (255, 240, 180), (12, 16), 2)
    return s


def _icon_dragon_wing() -> pygame.Surface:
    """용의 날개 - 날개 + 바람"""
    s = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 배경
    pygame.draw.circle(s, (45, 30, 15), (16, 16), 15)
    pygame.draw.circle(s, (80, 55, 30), (16, 16), 15, 1)
    # 날개 (좌측)
    wing_points = [(6, 22), (8, 10), (14, 6), (18, 8), (16, 14), (14, 20)]
    pygame.draw.polygon(s, (180, 120, 60), wing_points)
    pygame.draw.polygon(s, (220, 160, 80), wing_points, 2)
    # 날개 뼈대
    pygame.draw.line(s, (200, 140, 70), (8, 20), (14, 6), 1)
    pygame.draw.line(s, (200, 140, 70), (10, 18), (18, 8), 1)
    # 바람선 (우측)
    for i in range(3):
        y = 10 + i * 6
        x_start = 20
        x_end = 28
        alpha = 180 - i * 40
        pygame.draw.line(s, (200, 220, 255, alpha), (x_start, y), (x_end, y), 1)
        pygame.draw.line(s, (200, 220, 255, alpha), (x_end - 2, y - 1), (x_end, y), 1)
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
