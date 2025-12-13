"""
draw_player_gauge 함수 - bosspong.py에서 추출
"""

import pygame
import math
import random

def draw_player_gauge():
    """플레이어 게이지바를 오른쪽 하단에 세로로 표시 - 고급스러운 버전"""
    global special_gauge, special_gauge_max, special_ready, aipill_active
    global long_boost_active, long_boost_timer
    global wall_installing, wall_install_timer, wall_install_gauge_visible
    global rolling_charges, rolling_cooldown  # 🔴 대쉬 토큰 표시용

    legacy_state = globals().get("LEGACY_STATE")
    rolling_state = getattr(legacy_state, "rolling", None) if legacy_state else None

    if rolling_state is not None:
        current_rolling_charges = rolling_state.charges
        current_rolling_cooldown = rolling_state.cooldown
        current_rolling_charge_timer = rolling_state.charge_timer
    else:
        current_rolling_charges = rolling_charges
        current_rolling_cooldown = rolling_cooldown
        current_rolling_charge_timer = globals().get("rolling_charge_timer", 0)
    
    # 필살기 게이지바 위치와 크기 - 엣지있는 주인공 스타일
    gauge_x = WIDTH - 40  # 오른쪽에서 40px
    gauge_y = HEIGHT - 180  # 하단에서 180px 위
    gauge_width = 14  # 더 얇게
    gauge_height = 100  # 높이
    
    time_now = pygame.time.get_ticks()
    
    # ⚡ 전기 효과 강도 (게이지가 높을수록 강해짐)
    electric_intensity = displayed_gauge / special_gauge_max if displayed_gauge > 0 else 0
    
    # 🔷 육각형 프레임 상단
    hex_top = [
        (gauge_x + gauge_width // 2, gauge_y - 10),
        (gauge_x - 3, gauge_y),
        (gauge_x - 3, gauge_y + 8),
        (gauge_x + gauge_width + 3, gauge_y + 8),
        (gauge_x + gauge_width + 3, gauge_y),
    ]
    draw.polygon((80, 90, 100), hex_top)
    draw.polygon((180, 190, 200), hex_top, 2)
    
    # 🔷 육각형 프레임 하단
    hex_bottom = [
        (gauge_x - 3, gauge_y + gauge_height - 8),
        (gauge_x - 3, gauge_y + gauge_height),
        (gauge_x + gauge_width // 2, gauge_y + gauge_height + 10),
        (gauge_x + gauge_width + 3, gauge_y + gauge_height),
        (gauge_x + gauge_width + 3, gauge_y + gauge_height - 8),
    ]
    draw.polygon((80, 90, 100), hex_bottom)
    draw.polygon((180, 190, 200), hex_bottom, 2)
    
    # 🎯 메인 프레임 배경
    # 어두운 메탈릭 배경
    main_rect = pygame.Rect(gauge_x - 2, gauge_y, gauge_width + 4, gauge_height)
    draw.rect((25, 28, 35), main_rect)
    
    # 내부 홈 (음각 효과)
    inner_rect = pygame.Rect(gauge_x, gauge_y + 2, gauge_width, gauge_height - 4)
    draw.rect((15, 18, 25), inner_rect)
    
    # 사이드 라인 디테일 (테크니컬한 느낌)
    for i in range(3):
        line_y = gauge_y + 20 + i * 30
        # 왼쪽 라인
        draw.line((100, 110, 120), 
                        (gauge_x - 5, line_y), (gauge_x - 2, line_y), 1)
        # 오른쪽 라인
        draw.line((100, 110, 120), 
                        (gauge_x + gauge_width + 2, line_y), (gauge_x + gauge_width + 5, line_y), 1)
    
    # 센터 라인 (세로 중앙선)
    center_x = gauge_x + gauge_width // 2
    draw.line((60, 65, 75), 
                    (center_x, gauge_y + 5), (center_x, gauge_y + gauge_height - 5), 1)
    
    # ⚡ 게이지 채우기 - 전기/플라즈마 스타일
    if displayed_gauge > 0:
        fill_ratio = displayed_gauge / special_gauge_max
        fill_height = int((gauge_height - 4) * fill_ratio)
        
        # 게이지 레벨별 색상 (차갑고 날카로운 색상)
        if displayed_gauge < 150:
            pass
            # 레벨 1: 차가운 청백색
            base_color = (180, 200, 220)
            energy_color = (200, 220, 240)
        elif displayed_gauge < 250:
            pass
            # 레벨 2: 전기 청색
            base_color = (100, 180, 255)
            energy_color = (150, 200, 255)
        elif displayed_gauge < 350:
            pass
            # 레벨 3: 강렬한 시안
            base_color = (0, 220, 255)
            energy_color = (100, 240, 255)
        else:
            pass
            # 레벨 4: 플라즈마 (청백색 + 보라)
            pulse = abs(math.sin(time_now * 0.005))
            base_color = (
                int(100 + pulse * 100),
                int(150 + pulse * 50),
                255
            )
            energy_color = (200, 200, 255)
        
        # 메인 에너지 채우기
        fill_y = gauge_y + gauge_height - fill_height - 2
        
        # 3층 레이어 구조
        for layer in range(3):
            layer_alpha = 255 - layer * 50
            layer_width = gauge_width - 4 - layer * 2
            
            if layer_width > 0:
                for i in range(fill_height):
                    # 펄스 효과
                    pulse_offset = abs(math.sin((time_now * 0.003) + (i * 0.1)))
                    
                    if layer == 0:  # 코어 레이어
                        pass
                        color = energy_color
                    elif layer == 1:  # 미들 레이어
                        pass
                        color = base_color
                    else:  # 외곽 레이어
                        color = tuple(int(c * 0.7) for c in base_color)
                    
                    # 색상에 펄스 적용
                    final_color = tuple(min(255, int(c + pulse_offset * 20)) for c in color)
                    
                    draw.line(final_color, (gauge_x + 2 + layer, fill_y + i),
                                   (gauge_x + 2 + layer_width, fill_y + i))
        
        # ⚡ 전기 스파크 효과 (350 이상일 때)
        if displayed_gauge >= 350:
            spark_count = 2 if displayed_gauge < special_gauge_max else 4
            for _ in range(spark_count):
                spark_y = fill_y + random.randint(0, fill_height - 1)
                spark_x = gauge_x + random.randint(2, gauge_width - 2)
                spark_length = random.randint(3, 7)
                
                # 번개 모양
                points = []
                current_x = spark_x
                current_y = spark_y
                for i in range(3):
                    next_x = current_x + random.randint(-3, 3)
                    next_y = current_y + spark_length // 3
                    points.append((current_x, current_y))
                    points.append((next_x, next_y))
                    current_x = next_x
                    current_y = next_y
                
                if len(points) > 1:
                    draw.lines((255, 255, 255, 1), False, points, 1)
        
        # 상단 에너지 글로우
        if fill_ratio > 0.5:
            glow_height = 5
            for i in range(glow_height):
                alpha = 100 - i * 20
                glow_color = tuple(min(255, c + 50) for c in energy_color)
                draw.line(glow_color, (gauge_x + 2, fill_y - i),
                               (gauge_x + gauge_width - 2, fill_y - i))
    
    # ⚡ 파워 준비 상태 표시 (전기 효과)
    if displayed_gauge >= 350:
        pass
        # 외곽 전기 아크
        if (time_now // 100) % 3 == 0:  # 간헐적으로
            pass
            # 상단 아크
            arc_start = (gauge_x - 5, gauge_y - 5)
            arc_end = (gauge_x + gauge_width + 5, gauge_y - 5)
            arc_mid = (gauge_x + gauge_width // 2, gauge_y - 8)
            draw.lines((150, 255, 200, 1), False, 
                            [arc_start, arc_mid, arc_end], 1)
            
            # 하단 아크
            arc_start = (gauge_x - 5, gauge_y + gauge_height + 5)
            arc_end = (gauge_x + gauge_width + 5, gauge_y + gauge_height + 5)
            arc_mid = (gauge_x + gauge_width // 2, gauge_y + gauge_height + 8)
            draw.lines((150, 255, 200, 1), False, 
                            [arc_start, arc_mid, arc_end], 1)
        
        # 코너 발광
        corner_glow = int(abs(math.sin(time_now * 0.004)) * 100 + 155)
        corner_color = (corner_glow, corner_glow, 255)
        # 상단 코너
        draw.circle(corner_color, (gauge_x, gauge_y), 3)
        draw.circle(corner_color, (gauge_x + gauge_width, gauge_y), 3)
        # 하단 코너
        draw.circle(corner_color, (gauge_x, gauge_y + gauge_height), 3)
        draw.circle(corner_color, (gauge_x + gauge_width, gauge_y + gauge_height), 3)
    
    # 🔢 게이지바 위에 숫자 표시 (현재/최대)
    gauge_text = f"{int(displayed_gauge)}/{special_gauge_max}"
    text_color = (255, 255, 255) if displayed_gauge < special_gauge_max else (255, 255, 100)  # 만렙일 때는 노란색
    
    # 폰트 로드 (작은 크기)
    try:
        gauge_font = pygame.font.Font("NanumSquareB.ttf", 14)
    except:
        gauge_font = pygame.font.Font(None, 14)
    
    gauge_text_surface = gauge_font.render(gauge_text, True, text_color)
    text_rect = gauge_text_surface.get_rect()
    
    # 게이지바 위쪽에 중앙 정렬
    text_x = gauge_x + gauge_width // 2 - text_rect.width // 2
    text_y = gauge_y - 20  # 게이지바 위 20픽셀
    
    # 텍스트 배경 (반투명 검은 배경으로 가독성 향상)
    text_bg_rect = pygame.Rect(text_x - 2, text_y - 1, text_rect.width + 4, text_rect.height + 2)
    draw.rect((0, 0, 0, 180), text_bg_rect, border_radius=3)
    draw.rect((100, 100, 100), text_bg_rect, 1, border_radius=3)
    
    # 텍스트 렌더링
    SCREEN.blit(gauge_text_surface, (text_x, text_y))

    # 🎯 거대화포션 지속시간 게이지바
    item_gauge_active = long_boost_active and long_boost_timer > 0
    
    if item_gauge_active:
        gauge_x = WIDTH - 75  # 필살기 게이지 왼쪽에 배치
        gauge_y = HEIGHT - 180  # 필살기 게이지와 같은 높이
        gauge_width = 14  # 플레이어 게이지와 동일한 폭
        gauge_height = 100
        
        # 🔷 육각형 프레임 상단 (플레이어 게이지와 동일)
        hex_top = [
            (gauge_x + gauge_width // 2, gauge_y - 10),
            (gauge_x - 3, gauge_y),
            (gauge_x - 3, gauge_y + 8),
            (gauge_x + gauge_width + 3, gauge_y + 8),
            (gauge_x + gauge_width + 3, gauge_y),
        ]
        draw.polygon((80, 90, 100), hex_top)
        draw.polygon((180, 190, 200), hex_top, 2)
        
        # 🔷 육각형 프레임 하단
        hex_bottom = [
            (gauge_x - 3, gauge_y + gauge_height - 8),
            (gauge_x - 3, gauge_y + gauge_height),
            (gauge_x + gauge_width // 2, gauge_y + gauge_height + 10),
            (gauge_x + gauge_width + 3, gauge_y + gauge_height),
            (gauge_x + gauge_width + 3, gauge_y + gauge_height - 8),
        ]
        draw.polygon((80, 90, 100), hex_bottom)
        draw.polygon((180, 190, 200), hex_bottom, 2)
        
        # 🎯 메인 프레임 배경
        main_rect = pygame.Rect(gauge_x - 2, gauge_y, gauge_width + 4, gauge_height)
        draw.rect((25, 28, 35), main_rect)
        
        # 내부 홈 (음각 효과) - 게이지 채우기 전에만 그리기
        inner_rect = pygame.Rect(gauge_x, gauge_y + 2, gauge_width, gauge_height - 4)
        draw.rect((15, 18, 25), inner_rect)
        
        # 사이드 라인 디테일
        for i in range(3):
            line_y = gauge_y + 20 + i * 30
            draw.line((100, 110, 120), 
                            (gauge_x - 5, line_y), (gauge_x - 2, line_y), 1)
            draw.line((100, 110, 120), 
                            (gauge_x + gauge_width + 2, line_y), (gauge_x + gauge_width + 5, line_y), 1)
        
        # ⚡ 게이지 채우기 - 활성 아이템에 따라 색상 결정
        if long_boost_active and long_boost_timer > 0:
            # 거대화포션 활성화 시
            remaining_ratio = long_boost_timer / LONG_BOOST_DURATION
            fill_height = int((gauge_height - 4) * remaining_ratio)
            
            # 거대화포션 색상 (황금빛 -> 주황색)
            if remaining_ratio > 0.6:
                base_color = (255, 215, 0)  # 골드
                energy_color = (255, 235, 100)
            elif remaining_ratio > 0.3:
                base_color = (255, 165, 0)  # 주황색
                energy_color = (255, 195, 50)
            else:
                # 끝날 때 깜빡임 효과
                pulse = abs(math.sin(time_now * 0.01))
                base_color = (255, int(100 + pulse * 65), 0)
                energy_color = (255, int(150 + pulse * 50), 50)
        else:
            fill_height = 0
            
        # 게이지 그리기 (fill_height가 0보다 클 때만)
        if fill_height > 0:
            fill_y = gauge_y + gauge_height - fill_height - 2
            
            # 3층 레이어 구조 (플레이어 게이지와 동일)
            for layer in range(3):
                layer_alpha = 255 - layer * 50
                layer_width = gauge_width - 4 - layer * 2
                
                if layer_width > 0:
                    layer_rect = pygame.Rect(gauge_x + 2 + layer, fill_y, layer_width, fill_height)
                    
                    # 레이어별 색상 조정
                    layer_color = (
                        min(255, base_color[0] + layer * 20),
                        min(255, base_color[1] + layer * 20),
                        min(255, base_color[2] + layer * 20)
                    )
                    
                    draw.rect(layer_color, layer_rect)
            
            # ✨ 특수 효과
            if long_boost_active and remaining_ratio > 0.1:
                # 거대화포션: 반짝임 효과
                if random.random() < 0.3:  # 30% 확률로 반짝임
                    sparkle_y = fill_y + random.randint(0, max(1, fill_height - 1))
                    sparkle_color = (255, 255, 200, 150)
                    draw.line(sparkle_color, (gauge_x + 2, sparkle_y),
                                   (gauge_x + gauge_width - 2, sparkle_y), 1)
    
    # 🆕 벽돌 설치 게이지 (플레이어 패들 바로 위)
    if wall_install_gauge_visible and wall_installing:
        pass
        # 설치 게이지 위치 (플레이어 패들 바로 위)
        install_gauge_x = PLAYER.centerx - 40  # 패들 중앙 기준 좌우 40픽셀
        install_gauge_y = PLAYER.top - 30  # 패들 위 30픽셀
        install_gauge_width = 80  # 패들 너비와 동일
        install_gauge_height = 8  # 얇은 게이지
        
        # 설치 게이지 배경 (회색)
        draw.rect((80, 80, 80), 
                         (install_gauge_x, install_gauge_y, install_gauge_width, install_gauge_height))
        
        # 설치 게이지 테두리 (갈색)
        draw.rect((139, 69, 19), 
                         (install_gauge_x, install_gauge_y, install_gauge_width, install_gauge_height), 2)
        
        # 설치 게이지 채우기 (남은 시간에 따라 증가)
        install_max_timer = 30  # 0.5초 (30프레임)
        progress_ratio = (install_max_timer - wall_install_timer) / install_max_timer
        fill_width = int(install_gauge_width * progress_ratio)
        
        # 갈색에서 노란색으로 그라데이션
        if progress_ratio < 0.5:
            pass
            gauge_color = (139, 69, 19)  # 갈색
        elif progress_ratio < 0.8:
            pass
            gauge_color = (160, 82, 45)  # 밝은 갈색
        else:
            gauge_color = (255, 255, 0)  # 노란색
        
        # 채워진 부분 그리기 (왼쪽에서부터)
        draw.rect( gauge_color, 
                         (install_gauge_x + 2, install_gauge_y + 2, fill_width - 4, install_gauge_height - 4))
    
    # 대쉬 전용 게이지바 제거 - 토큰볼을 게이지로 활용
    
    # 🔴 대쉬 토큰 표시 (플레이어 게이지바 하단에 고정)
    token_radius = 6  # 토큰 크기
    token_spacing = 16  # 토큰 간격
    
    # 🔧 정확한 최대 토큰 수 계산 (대쉬홀더 + 증폭 스킬)
    base_charges = 1  # 기본 1개
    holder_bonus = 1 if dashholder_obtained else 0  # 대쉬홀더 +1개
    amplification_bonus = academy.get_skill_bonus("dash_amplification")
    max_tokens = int(base_charges + holder_bonus + amplification_bonus)
    
    # 토큰 표시 시작 위치 (플레이어 게이지바 중앙 하단에 항상 고정)
    player_gauge_x = WIDTH - 40  # 플레이어 게이지바 X 위치
    player_gauge_width = 14  # 플레이어 게이지바 폭
    token_start_x = player_gauge_x + player_gauge_width // 2 - (max_tokens * token_spacing) // 2 + token_spacing // 2
    token_y = gauge_y + gauge_height + 15  # 게이지바 아래 15픽셀
    
    # 🔧 대쉬 토큰 표시 - 오른쪽부터 소진 / 왼쪽부터 충전
    # 최종 해결: token_states 리스트로 각 토큰 개별 추적
    global token_states
    if 'token_states' not in globals():
        token_states = [True] * current_rolling_charges + [False] * (max_tokens - current_rolling_charges)
    
    # 토큰 상태 배열 크기 조정
    if len(token_states) != max_tokens:
        pass
        # 현재 충전된 토큰 수 계산
        current_charged = sum(1 for state in token_states if state)
        # 새로운 토큰 상태 배열 생성
        if current_rolling_charges > 0:
            pass
            # 실제 충전된 토큰 수에 맞춰 재구성
            token_states = [True] * min(current_rolling_charges, max_tokens) + [False] * max(0, max_tokens - current_rolling_charges)
        else:
            pass
            # 토큰이 없으면 모두 비어있음
            token_states = [False] * max_tokens
    
    for i in range(max_tokens):
        token_x = token_start_x + i * token_spacing
        
        # 토큰 상태에 따른 표시
        if i < len(token_states) and token_states[i]:
            pass
            # 사용 가능한 토큰 - 밝은 빨간색
            token_color = (255, 80, 80)
            glow_color = (255, 150, 150)
            is_available = True
        else:
            pass
            # 사용된 토큰 - 충전 중
            # 충전 진행률 계산
            if current_rolling_charge_timer > 0:
                pass
                # _token_charge_states에서 각 토큰별 개별 타이머/max_time 가져오기 (균등 애니메이션용)
                _token_charge_states = globals().get("_token_charge_states", [])
                _charging_state = globals().get("_charging_state", {"timer": 0, "index": -1, "max_time": 90})

                # 현재 토큰(i)에 대한 충전 상태 가져오기
                if i < len(_token_charge_states) and _token_charge_states[i]["max_time"] > 0:
                    # 개별 토큰 상태 사용 (균등 애니메이션)
                    charging_timer = _token_charge_states[i]["timer"]
                    max_charge_time = _token_charge_states[i]["max_time"]
                else:
                    # 폴백: 기존 _charging_state 사용
                    max_charge_time = _charging_state.get("max_time", 90)
                    charging_timer = _charging_state.get("timer", current_rolling_charge_timer)

                # max_charge_time이 0이면 기본값 사용
                if max_charge_time <= 0:
                    max_charge_time = 90  # 균등 애니메이션을 위한 고정값

                # 충전 진행률 (0.0 ~ 1.0) - 개별 토큰 타이머 사용
                charge_progress = 1.0 - (charging_timer / max_charge_time)
                charge_progress = max(0, min(1, charge_progress))
                
                # 충전 중인 토큰 확인 (왼쪽부터 충전)
                # 왼쪽부터 첫 번째 비어있는 토큰만 충전
                is_charging = False
                for j in range(len(token_states)):
                    if not token_states[j]:  # 비어있는 토큰 발견
                        if j == i:  # 현재 토큰이 첫 번째 비어있는 토큰인 경우
                            is_charging = True
                        break  # 첫 번째 비어있는 토큰만 찾으면 종료
                
                if is_charging:
                    pass
                    # 충전 중 - 빨간색이 차오르는 효과
                    base_empty_color = (60, 30, 30)  # 비어있는 상태
                    base_full_color = (255, 80, 80)  # 가득 찬 상태
                    
                    # 충전 진행률에 따른 색상 보간
                    token_color = (
                        int(base_empty_color[0] + (base_full_color[0] - base_empty_color[0]) * charge_progress),
                        int(base_empty_color[1] + (base_full_color[1] - base_empty_color[1]) * charge_progress),
                        int(base_empty_color[2] + (base_full_color[2] - base_empty_color[2]) * charge_progress)
                    )
                    glow_color = (
                        int(100 + 155 * charge_progress),
                        int(50 + 100 * charge_progress),
                        int(50 + 100 * charge_progress)
                    )
                    is_available = False
                else:
                    pass
                    # 아직 충전 차례가 아님 - 완전히 비어있는 상태 (어두운 회색)
                    token_color = (40, 20, 20)  # 더 어두운 색
                    glow_color = (50, 25, 25)  # 글로우도 최소화
                    is_available = False
                    charge_progress = 0  # 충전 진행률 0으로 설정
            else:
                pass
                # 충전 타이머 없음 - 완전히 비어있는 상태
                token_color = (60, 30, 30)
                glow_color = (80, 40, 40)
                is_available = False
        
        # 글로우 효과 (토큰이 사용 가능할 때만)
        if is_available:
            pass
            # 글로우 효과를 위한 반투명 원
            glow_surface = pygame.Surface((token_radius * 4, token_radius * 4), pygame.SRCALPHA)
            pygame.draw.circle(glow_surface, (*glow_color, 60), 
                             (token_radius * 2, token_radius * 2), token_radius * 2)
            SCREEN.blit(glow_surface, (token_x - token_radius * 2, token_y - token_radius * 2))
        
        # 충전 중인 토큰의 물 차오르는 효과
        if not is_available and 'charge_progress' in locals() and 'is_charging' in locals() and is_charging and charge_progress > 0:
            pass
            # 배경 원 (비어있는 상태)
            draw.circle((40, 20, 20), (int(token_x), int(token_y)), token_radius)
            
            # 아래에서 위로 차오르는 물 효과
            if charge_progress > 0:
                pass
                # 충전 높이 계산 (아래에서 위로)
                fill_height = int(token_radius * 2 * charge_progress)
                
                # 원형 내부에 차오르는 사각형 영역 클리핑
                # 원의 하단부터 시작
                fill_y_start = token_y + token_radius - fill_height
                
                # 물결 효과를 위한 sin 파동
                wave_offset = math.sin(pygame.time.get_ticks() * 0.005) * 1
                
                # 채워진 부분 그리기 (원 안에서만)
                for y in range(int(fill_y_start), int(token_y + token_radius)):
                    # 현재 y 위치에서 원의 너비 계산
                    dy = abs(y - token_y)
                    if dy <= token_radius:
                        pass
                        # 원의 방정식: x² + y² = r²
                        dx = math.sqrt(token_radius * token_radius - dy * dy)
                        
                        # 물결 효과 추가
                        wave = wave_offset * (1 - (y - fill_y_start) / fill_height) if fill_height > 0 else 0
                        
                        # 그라데이션 색상 (아래가 더 진함)
                        gradient_ratio = (y - fill_y_start) / fill_height if fill_height > 0 else 0
                        color_r = int(token_color[0] * (0.7 + 0.3 * gradient_ratio))
                        color_g = int(token_color[1] * (0.7 + 0.3 * gradient_ratio))
                        color_b = int(token_color[2] * (0.7 + 0.3 * gradient_ratio))
                        
                        # 수평선 그리기
                        draw.line((color_r, color_g, color_b),
                                       (token_x - dx + wave, y),
                                       (token_x + dx + wave, y))
            
            # 테두리
            draw.circle((100, 50, 50), (int(token_x), int(token_y)), token_radius, 1)
            
            # 충전 펄스 효과 (반짝임)
            if charge_progress > 0.5:
                pulse_alpha = int(50 + 50 * math.sin(pygame.time.get_ticks() * 0.01))
                pulse_surface = pygame.Surface((token_radius * 2 + 4, token_radius * 2 + 4), pygame.SRCALPHA)
                pygame.draw.circle(pulse_surface, (255, 100, 100, pulse_alpha),
                                 (token_radius + 2, token_radius + 2), token_radius + 1)
                SCREEN.blit(pulse_surface, (token_x - token_radius - 2, token_y - token_radius - 2))
        else:
            pass
            # 메인 토큰 원 (기본 상태)
            draw.circle(token_color, (int(token_x), int(token_y)), token_radius)
            
            # 토큰 테두리 (입체감)
            border_color = (200, 200, 200) if is_available else (80, 80, 80)
            draw.circle(border_color, (int(token_x), int(token_y)), token_radius, 1)
            
            # 하이라이트 효과 (작은 흰색 점)
            if is_available:
                highlight_x = token_x - token_radius // 3
                highlight_y = token_y - token_radius // 3
                draw.circle((255, 255, 255), 
                                 (int(highlight_x), int(highlight_y)), token_radius // 4)
