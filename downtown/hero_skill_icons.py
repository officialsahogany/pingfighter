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
