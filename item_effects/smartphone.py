"""
스마트폰 (Smartphone) - 패시브 아이템
플레이어가 스탑워치나 AI알약을 소지하고 있을 경우,
공을 놓치기 직전 순간에 자동으로 해당 아이템을 사용합니다.
"""

import pygame
import math

class Smartphone:
    def __init__(self):
        self.active = False
        self.last_activation_time = 0
        self.activation_cooldown = 180  # 3 seconds cooldown at 60 FPS
        self.danger_threshold = 50  # Distance threshold for danger detection
        self.auto_activated = False  # Flag to prevent multiple activations
        self.urgent_override = False  # 패배 임박 시 쿨타임 무시 발동 플래그
        # 최근 프레임 상태(불필요한 조기 발동 억제용)
        self.last_player_y = None
        self.last_ball_y = None
        self.last_y_gap = None
        self.closing_streak = 0
        self.closing_streak = 0
        
    def activate(self, game_state, current_stage):
        """패시브 아이템 활성화"""
        self.active = True
        print("스마트폰 패시브 아이템 활성화 - 위험 순간 자동 아이템 사용")
        
    def check_danger_v2(self, ball_x, ball_y, ball_vx, ball_vy, paddle_y, paddle_size, player_x=None):
        """Y축 기준 위험 판단(바닥 패배 규칙에 정합)

        - 공 속도 크기에 관계없이 패들이 제시간에 도달 불가로 예측되면 True
        - 바닥 도달 임박(frames<=20)이고 패들 범위 밖이면 True
        - 스톱워치 자동 발동을 최대한 앞당기기 위한 보수적 판단
        """
        # 화면/패들 파라미터를 메인 모듈에서 우선 취득
        try:
            import sys
            main_module = sys.modules.get('__main__')
            SCREEN_HEIGHT = getattr(main_module, 'HEIGHT', 750)
            PADDLE_HEIGHT = getattr(main_module, 'PADDLE_HEIGHT', 50)
            PADDLE_WIDTH = getattr(main_module, 'PADDLE_WIDTH', 155)
        except Exception:
            SCREEN_HEIGHT = 750
            PADDLE_HEIGHT = 50
            PADDLE_WIDTH = 155

        PLAYER_CENTERY = paddle_y
        PLAYER_CENTERX = player_x if player_x is not None else 50

        # 호출마다 초기화
        self.urgent_override = False

        # 패들 위에 공이 있으면 발동하지 않음 (패들이 받을 수 있는 영역)
        # X축: 패들 중심 ± 패들 너비/2 + 여유 10px
        # Y축: 패들 위 50px 이내
        paddle_left = PLAYER_CENTERX - (PADDLE_WIDTH / 2) - 10
        paddle_right = PLAYER_CENTERX + (PADDLE_WIDTH / 2) + 10
        ball_over_paddle_x = (paddle_left <= ball_x <= paddle_right)
        ball_over_paddle_y = (ball_y >= PLAYER_CENTERY - 50) and (ball_y <= PLAYER_CENTERY + PADDLE_HEIGHT / 2)
        
        # 공이 패들 위에 있고 아래로 떨어지는 중이면 플레이어가 받을 수 있음
        if ball_over_paddle_x and ball_over_paddle_y and ball_vy > 0:
            # print(f"[DEBUG] 패들 위 공 - 발동 억제: X={ball_x:.0f} (패들:{paddle_left:.0f}~{paddle_right:.0f}), Y={ball_y:.0f}")
            return False
        
        # 패들 양쪽 100프레임 이내 영역에서는 발동하지 않음
        # 공이 왼쪽으로 이동 중이고 패들 X축에 도달하는 시간이 100프레임 이내
        if ball_vx < 0 and ball_x > PLAYER_CENTERX:
            frames_to_paddle_x = (ball_x - PLAYER_CENTERX) / abs(ball_vx)
            if frames_to_paddle_x <= 100:
                # print(f"[DEBUG] 패들 100프레임 이내 - 발동 억제: {frames_to_paddle_x:.1f}프레임 후 도달")
                return False
        
        # 공이 오른쪽으로 이동 중이고 패들 X축에서 멀어지는 시간이 100프레임 이내
        elif ball_vx > 0 and ball_x < PLAYER_CENTERX:
            frames_from_paddle_x = (PLAYER_CENTERX - ball_x) / abs(ball_vx)
            if frames_from_paddle_x <= 100:
                # print(f"[DEBUG] 패들 100프레임 이내 - 발동 억제: {frames_from_paddle_x:.1f}프레임 전 통과")
                return False

        # 동적 위험 영역 계산: 공의 위치와 속도에 따라 조정 (조기 발동 억제 강화)
        # 기본적으로 더 아래에서만 판단하고, 빠른 공도 과도하게 일찍 감지하지 않도록 제한
        ball_speed_total = (ball_vx**2 + ball_vy**2)**0.5 if ball_vx != 0 or ball_vy != 0 else 1
        
        # 속도에 따른 감지 영역 동적 조정 (더 아래로 내림)
        if ball_speed_total >= 20:  # 매우 빠른 공
            PLAYER_ZONE_MIN_Y = int(SCREEN_HEIGHT * 0.82)
        elif ball_speed_total >= 15:  # 빠른 공
            PLAYER_ZONE_MIN_Y = int(SCREEN_HEIGHT * 0.85)
        else:  # 보통 속도
            PLAYER_ZONE_MIN_Y = int(SCREEN_HEIGHT * 0.88)
        
        # 추가 조건: X축 거리도 고려
        x_distance_to_player = abs(ball_x - PLAYER_CENTERX)
        
        # 공이 너무 멀리 있으면 (X축으로 400px 이상) Y축 체크 더 엄격하게
        if x_distance_to_player > 400:
            PLAYER_ZONE_MIN_Y = int(SCREEN_HEIGHT * 0.92)
        
        if ball_y < PLAYER_ZONE_MIN_Y:
            return False

        # 플레이어 방향(아래)으로 이동 중인지 확인
        if ball_vy <= 0:
            return False

        # 직전 타자 체크(플레이어가 직전에 친 공이면 제외)
        try:
            import sys
            main_module = sys.modules.get('__main__')
            if main_module and getattr(main_module, 'last_hit_by', None) == 'player':
                return False
        except Exception:
            pass

        # 플레이어 이동 속도(대시 고려)
        PLAYER_NORMAL_SPEED = 10
        PLAYER_DASH_SPEED = 30
        # 도달 가능성 계산은 '대시를 활용하지 않는' 보수적 기준으로 판단
        # 이미 대시 중인 경우에만 대시 속도를 반영
        is_rolling_active = False
        try:
            is_rolling_active = bool(getattr(main_module, 'rolling_active', False)) if main_module else False
        except Exception:
            pass
        player_speed = PLAYER_DASH_SPEED if is_rolling_active else PLAYER_NORMAL_SPEED
        # 대시 토큰이 있으면 실제로는 대시로 커버 가능하므로 최소 대시 속도로 재평가
        try:
            if main_module and getattr(main_module, 'rolling_charges', 0) > 0:
                player_speed = max(player_speed, PLAYER_DASH_SPEED)
        except Exception:
            pass
        # 실측 플레이어 속도로 상향 보정: 치러 가는 중이면 더 빠르게 가정하여 과잉 발동 억제
        try:
            if self.last_player_y is not None:
                observed_speed = abs(paddle_y - self.last_player_y)
                if observed_speed > 0:
                    player_speed = max(player_speed, observed_speed * 1.2)
        except Exception:
            pass

        # 공 속도와 바닥까지 남은 프레임 먼저 계산
        ball_speed_y = abs(ball_vy) if ball_vy != 0 else 0.1
        frames_to_floor = (SCREEN_HEIGHT - ball_y) / ball_speed_y if ball_speed_y > 0 else 9999
        
        # 공이 플레이어 Y까지 도달하는 시간(프레임)
        dy_to_player = PLAYER_CENTERY - ball_y
        # 공이 이미 플레이어보다 아래 있으면 바닥 임박 체크로 넘김
        if dy_to_player < 0 and frames_to_floor > 30:
            return False
        time_to_reach_player = abs(dy_to_player) / ball_speed_y if dy_to_player != 0 else 0

        # [가드] 플레이어 패들 바로 위 영역에서는 발동하지 않음
        # 의미: 공이 패들의 가로 범위(±width/2 + 8px) 안에 있고,
        #       패들 중심 위쪽 근접 높이(패들 높이 × 1.2) 범위에 있으며,
        #       아래로 이동 중일 때는 플레이어가 직접 받아칠 수 있는 안정권으로 간주
        try:
            x_margin = 4  # 가로 밴드 축소(덜 과민)
            paddle_left = PLAYER_CENTERX - (PADDLE_WIDTH / 2) - x_margin
            paddle_right = PLAYER_CENTERX + (PADDLE_WIDTH / 2) + x_margin
            in_paddle_x_band = (paddle_left <= ball_x <= paddle_right)
            # 세로 밴드 축소: 패들 높이의 0.6배까지만 안정권으로 간주
            above_paddle_near = (ball_y <= PLAYER_CENTERY) and (ball_y >= (PLAYER_CENTERY - PADDLE_HEIGHT * 0.6))
            # 극임박(바닥까지 12프레임 이내)은 예외: 가드 무시하고 이후 로직으로 판단
            if in_paddle_x_band and above_paddle_near and (ball_vy > 0) and (frames_to_floor > 12):
                # 패들 바로 위 안정권: 위험 아님으로 처리
                return False
        except Exception:
            pass

        # Y축 영역 필터링: 공이 너무 높이 있으면 무시 (스크린샷 문제 해결)
        # 단, 바닥 근처나 실제 위험 상황은 예외 처리
        ball_speed_total = (ball_vx**2 + ball_vy**2)**0.5
        x_distance = abs(ball_x - PLAYER_CENTERX)
        
        # 바닥 임박 상황은 항상 체크 (Y > 680)
        if ball_y > 680:
            pass  # 바닥 근처는 항상 위험 판단 진행
        else:
            # 높이 떠있는 공 필터링
            # 기본: 화면의 75% (562) 이상에서만 체크
            PLAYER_ZONE_MIN_Y = int(SCREEN_HEIGHT * 0.75)  # 562
            
            # 초고속 공은 조금 더 일찍 체크
            if ball_speed_total >= 25:  # 초고속
                PLAYER_ZONE_MIN_Y = int(SCREEN_HEIGHT * 0.70)  # 525
            elif ball_speed_total >= 20:  # 매우 빠름
                PLAYER_ZONE_MIN_Y = int(SCREEN_HEIGHT * 0.72)  # 540
            
            # X축 거리가 멀고 Y가 높으면 무시
            if x_distance > 400 and ball_y < PLAYER_ZONE_MIN_Y:
                return False
            
            # 일반적으로 높이 떠있으면 무시
            if ball_y < PLAYER_ZONE_MIN_Y:
                # 단, 빠르게 떨어지는 공은 예외
                if ball_vy <= 15:  # 보통 속도로 떨어지는 공
                    return False
        
        # 조기 발동 방지: 실제 위협 시간 계산
        # 공이 플레이어 위치에 도달하는 예상 시간 (X, Y 모두 고려)
        estimated_threat_time = float('inf')
        
        # X축 도달 시간
        if ball_vx < 0 and ball_x > PLAYER_CENTERX:
            x_time = (ball_x - PLAYER_CENTERX) / abs(ball_vx)
        else:
            x_time = float('inf')
        
        # Y축 도달 시간 (플레이어 Y 근처)
        if ball_vy > 0:
            y_time_to_player = (PLAYER_CENTERY - ball_y) / ball_vy if PLAYER_CENTERY > ball_y else 0
        else:
            y_time_to_player = float('inf')
        
        # 실제 위협 시간은 둘 중 작은 값
        estimated_threat_time = min(x_time, y_time_to_player)
        
        # 너무 먼 미래면 (50프레임 = 0.83초 이상) 무시
        if estimated_threat_time > 50:
            return False
        
        # 위험감지센서 방식 참조: 플레이어 X에서의 교차 예측 기반 판단 강화
        # 1) 공이 플레이어 X까지 오는 시간 t_to_player_x 계산 (좌측으로 이동 중일 때만 의미)
        miss_at_player_x = None
        t_to_player_x = None
        near_hit_imminent = False
        if ball_vx < 0 and ball_x > PLAYER_CENTERX:
            t_to_player_x = (ball_x - PLAYER_CENTERX) / abs(ball_vx) if ball_vx != 0 else 1e9
            if t_to_player_x < frames_to_floor and t_to_player_x < 90:  # 1.5초 이내만 고려 (너무 먼 미래 제외)
                # 상하 반사까지 고려한 예측 Y 계산
                def reflect_y(y0, vy0, dt, y_min, y_max):
                    size = max(y_max - y_min, 1)
                    total = (y0 - y_min) + vy0 * dt
                    period = 2 * size
                    m = total % period
                    if m < 0:
                        m += period
                    if m <= size:
                        return y_min + m
                    else:
                        return y_max - (m - size)
                y_min, y_max = 0, SCREEN_HEIGHT
                predicted_y_at_player_x = reflect_y(ball_y, ball_vy, t_to_player_x, y_min, y_max)
                y_gap_at_player_x = abs(predicted_y_at_player_x - PLAYER_CENTERY)
                time_needed_for_y2 = y_gap_at_player_x / max(player_speed, 0.1)
                # 2) 예측시점에 도달 가능한지 체크 (여유 1.10)
                can_reach_at_player_x = time_needed_for_y2 <= t_to_player_x * 1.10
                # 3) 패들 유효 범위 안에 들어오는지도 체크(약간의 여유)
                within_paddle_band = y_gap_at_player_x <= (PADDLE_HEIGHT * 0.75 + 6)

                # 3.5) 플레이어가 직접 타격 가능한 거리면 절대 발동 금지
                # 타격 가능 조건: X축 도달시간 내에 Y축 이동 가능 + 패들 범위
                HITTING_ZONE_FRAMES = 24  # 0.4초 이내 타격 가능 영역
                PADDLE_EFFECTIVE_HEIGHT = PADDLE_HEIGHT * 1.2  # 패들 유효 타격 범위 (약간 여유)
                
                if t_to_player_x <= HITTING_ZONE_FRAMES:
                    # 매우 가까운 타격 영역 - 무조건 억제
                    can_definitely_hit = (y_gap_at_player_x <= PADDLE_EFFECTIVE_HEIGHT) or \
                                       (time_needed_for_y2 <= t_to_player_x * 1.3)
                    if can_definitely_hit:
                        # print(f"[DEBUG] 타격 가능 영역 - 발동 억제: t_x={t_to_player_x:.1f}, y_gap={y_gap_at_player_x:.0f}")
                        near_hit_imminent = True
                elif t_to_player_x <= 30:  # 0.5초 이내
                    # 중간 거리 - 패들 범위 내면 억제 (완화)
                    within_paddle_zone = y_gap_at_player_x <= (PADDLE_HEIGHT * 1.0)
                    can_reach_comfortably = time_needed_for_y2 <= t_to_player_x * 1.2
                    if within_paddle_zone or can_reach_comfortably:
                        # print(f"[DEBUG] 중거리 타격 가능 - 발동 억제: t_x={t_to_player_x:.1f}")
                        near_hit_imminent = True

                # 플레이어 X 교차 직전 '미스 확정'이면 패들 높이에서 즉시 발동 (바닥까지 기다리지 않음)
                CROSS_URGENT_FRAMES = 12  # 교차 임박 임계 (약 0.2초)
                if (t_to_player_x <= CROSS_URGENT_FRAMES) and (not can_reach_at_player_x):
                    if y_gap_at_player_x > (PADDLE_HEIGHT * 0.75):
                        # 패들 범위를 확실히 벗어남 → 즉시 긴급 발동 허용
                        self.urgent_override = True
                        return True

                # 최종 판단: 타격 영역이 아니면서 도달 불가능하면 미스
                if not (can_reach_at_player_x or within_paddle_band):
                    # 예측시점에서도 못 막음 → 미스 확정에 가깝다
                    miss_at_player_x = True

        # 보강 가드: 단기 전방 시뮬레이션으로 패들 충돌 가능성 있으면 발동 금지
        # 36프레임(0.6초) 내, 좌측으로 접근하며, 바닥 도달 이전에 플레이어 X 대역을 통과하고 Y범위에 들어오면 차단
        def predict_can_hit_discrete(max_frames=36, x_band=12, y_scale=1.0, y_margin=6):
            if ball_vx >= 0:
                return False
            # 추정된 플레이어 가용 속도로 Y를 따라갈 수 있는지도 간단 체크
            for t in range(1, max_frames + 1):
                if t > frames_to_floor:
                    break
                xt = ball_x + ball_vx * t
                if xt > PLAYER_CENTERX + x_band:
                    continue
                yt = reflect_y(ball_y, ball_vy, t, 0, SCREEN_HEIGHT) if 'reflect_y' in locals() else (ball_y + ball_vy * t)
                y_gap_t = abs(yt - PLAYER_CENTERY)
                if y_gap_t <= (PADDLE_HEIGHT * y_scale + y_margin):
                    # 또한 플레이어가 t 프레임 내에 이동 가능할지 추정
                    if (y_gap_t / max(player_speed, 0.1)) <= t * 1.15:
                        return True
                    # 또는 최근 추세상 빠르게 접근 중이면 허용
                    if is_closing and y_gap_t <= (PADDLE_HEIGHT * 1.1):
                        return True
            return False

        try:
            if predict_can_hit_discrete():
                near_hit_imminent = True
        except Exception:
            pass

        # 타격 직전 억제: 예측상 매우 임박한 히트로 판단되면 모든 일반/근접 트리거를 차단
        # 긴급(극임박 바닥)만 예외

        # 패들이 이동하는데 필요한 시간(프레임)
        y_distance = abs(ball_y - PLAYER_CENTERY)
        time_needed_for_y = y_distance / max(player_speed, 0.1)
        # 이전 프레임 대비 갭 추세(치러 가는 중인지): 빠르게 좁혀오면 불필요 발동 억제
        prev_gap = self.last_y_gap
        cur_gap = y_distance
        is_closing = prev_gap is not None and cur_gap < prev_gap
        # 도달 가능 여부(플레이어가 최대 속도로 움직여 공이 패들 Y에 도달하기 전 차단 가능한가?)
        REACH_MARGIN = 1.05  # 소폭 완화: 약간만 여유를 두고 도달 가능 판단
        can_reach_at_paddle_y = time_needed_for_y <= time_to_reach_player * REACH_MARGIN

        # 실제 위험 판단 개선: Y>680 영역에서 더 적극적으로 감지
        SAFETY_MARGIN = 0.9
        
        # 바닥 근처(Y>=680)에서는 타격 영역 억제 완화
        in_hitting_zone = False
        if ball_y < 680:  # 바닥에서 멀 때만 타격 영역 체크
            in_hitting_zone = (t_to_player_x is not None and t_to_player_x <= 15)
        
        # Y>=680 영역에서는 단순하게 판단 (바닥 근처)
        if ball_y >= 680:
            # X축이 매우 가까우면 (5프레임 이내) 타격 가능하므로 제외
            x_very_close = (t_to_player_x is not None and t_to_player_x <= 5)
            
            # 바닥 가까운 공 - 여러 조건으로 위험 판단
            # 조건1: Y 거리가 패들 높이의 20% 이상 (10픽셀 이상)
            # 조건2: 바닥 매우 임박하고 Y 거리가 있음 (8프레임 이내 + 5픽셀 이상)
            # 조건3: X축 교차 임박하고 Y 거리가 있음 (12프레임 이내 + 8픽셀 이상)
            y_gap_large = y_distance >= PADDLE_HEIGHT * 0.2  # 10픽셀 이상
            floor_urgent = (frames_to_floor <= 8) and (y_distance >= 5)  # 바닥 매우 임박
            x_urgent = (t_to_player_x is not None and t_to_player_x <= 12) and (y_distance >= 8)  # X축 임박
            
            y_gap_condition = y_gap_large or floor_urgent or x_urgent
            
            # 디버그 출력 (필요시 주석 해제)
            # x_reach_str = f"{t_to_player_x:.1f}" if t_to_player_x is not None else "999"
            # print(f"[DEBUG Y>=680] Y={ball_y:.0f}, Y갭={y_distance:.0f}, X도달={x_reach_str}, 바닥까지={frames_to_floor:.1f}")
            # print(f"  - Y갭 큼: {y_gap_large} (갭={y_distance:.0f} >= 10)")
            # print(f"  - 바닥 긴급: {floor_urgent} (바닥<={8} AND 갭>={5})")
            # print(f"  - X축 긴급: {x_urgent} (X<={12} AND 갭>={8})")
            # print(f"  - 종합 Y갭 조건: {y_gap_condition}")
            # print(f"  - X 매우 가까움: {x_very_close}")
            
            if y_gap_condition and not x_very_close:
                # 발동 높이 가드: 공이 플레이어 패들 범위를 크게 벗어나면(바닥 너무 가까이) 발동하지 않음
                # 패들 하단 + 여유 50픽셀까지 허용 (더 관대하게)
                activation_height_ok = (ball_y <= (PLAYER_CENTERY + PADDLE_HEIGHT))
                # print(f"  - 높이 가드: {activation_height_ok} (Y={ball_y:.0f} <= {PLAYER_CENTERY + PADDLE_HEIGHT:.0f})")
                # print(f"  - miss_at_player_x: {miss_at_player_x}, near_hit: {near_hit_imminent}")
                # 바닥 임박+높이 가드일 때 허용 (프레임 조건 완화)
                if frames_to_floor <= 15 and activation_height_ok and (not near_hit_imminent):
                    print(f"[DEBUG] 🚨 바닥 근처 위험 발동! Y={ball_y:.0f}, 바닥까지={frames_to_floor:.1f}")
                    return True
        
        # 일반 위험 판단
        # 조건 1: Y축 도달 불가능 + 타격 영역 아님
        condition1 = (not can_reach_at_paddle_y) and (not in_hitting_zone) and (not near_hit_imminent)
        # 조건 2: 충분한 Y 거리 + 시간 부족
        condition2 = y_distance > PADDLE_HEIGHT / 2 and (time_needed_for_y > time_to_reach_player * SAFETY_MARGIN)
        # 조건 3: 바닥이 어느 정도 가까움 (완화)
        condition3 = frames_to_floor <= 24
        
        # miss_at_player_x 조건 완화 - True가 아니어도 발동 가능
        if condition1 and condition2 and condition3 and (not near_hit_imminent):
            # 대시 중 여부를 출력(도달 판단은 is_rolling_active를 반영함)
            try:
                dash_state = bool(is_rolling_active)
            except Exception:
                dash_state = False
            # 플레이어가 빠르게 좁혀오는 중이고, 갭이 패들 높이의 0.9배 이하면 안전 처리
            if is_closing and cur_gap <= (PADDLE_HEIGHT * 0.9):
                self.last_player_y = paddle_y
                self.last_ball_y = ball_y
                self.last_y_gap = cur_gap
                return False
            # 연속 근접 추세면 억제 (히스테리시스)
            if self.closing_streak >= 2:
                self.last_player_y = paddle_y
                self.last_ball_y = ball_y
                self.last_y_gap = cur_gap
                return False
            # miss_at_player_x가 True면 더 확실한 위험
            if miss_at_player_x is True:
                print(f"[DEBUG] 🚨🚨 위험 확정(Y+X): dy={y_distance:.0f}, t_hit={time_to_reach_player:.1f}, t_need={time_needed_for_y:.1f}, dash={dash_state}")
            else:
                print(f"[DEBUG] 🚨 위험(Y): dy={y_distance:.0f}, t_hit={time_to_reach_player:.1f}, t_need={time_needed_for_y:.1f}, dash={dash_state}")
            return True

        # 패들 근접 트리거: 더 낮은 임계(패들에 매우 근접했을 때만) 발동
        # 패들 높이의 0.30배 또는 14px 중 더 큰 값(약간 더 일찍)
        near_window = max(int(PADDLE_HEIGHT * 0.30), 14)
        # miss_at_player_x 조건 제거하여 더 쉽게 발동
        if (not can_reach_at_paddle_y) and (0 < dy_to_player <= near_window) and y_distance > PADDLE_HEIGHT / 2 \
           and (not in_hitting_zone) and (not near_hit_imminent):
            # 치러 가는 중이면 근접 트리거 억제
            if is_closing:
                self.last_player_y = paddle_y
                self.last_ball_y = ball_y
                self.last_y_gap = cur_gap
                return False
            if self.closing_streak >= 2:
                self.last_player_y = paddle_y
                self.last_ball_y = ball_y
                self.last_y_gap = cur_gap
                return False
            print(f"[DEBUG] ⚠️ 패들 근접: dy_to_player={dy_to_player:.0f} (≤{near_window})")
            return True

        # 바닥 임박 시(패배 직전) 패들 범위 밖이면 위험 처리 - 단, 아주 임박(<=8프레임) 외엔 미스 확정 필요
        # 바닥에 닿기 전 플레이어가 현 위치에서 패들 중심까지 이동해 차단 가능한지 체크
        can_reach_before_floor = time_needed_for_y <= frames_to_floor * REACH_MARGIN
        # 바닥 임박 임계: 18프레임 (약 0.3초)
        if frames_to_floor <= 18 and y_distance > PADDLE_HEIGHT / 2:
            # 발동 높이 가드: 공이 플레이어 패들 범위를 크게 벗어나면(바닥 너무 가까이) 발동하지 않음
            # 패들 하단 + 여유 25픽셀까지 허용 (PLAYER_CENTERY + 25 + 25 = PLAYER_CENTERY + 50)
            activation_height_ok = (ball_y <= (PLAYER_CENTERY + PADDLE_HEIGHT * 0.25))
            # 바닥 임박 상황에서는 도달 가능성 + (미스 확정 또는 극임박) + 높이 가드
            if activation_height_ok and (not can_reach_before_floor) and ((miss_at_player_x is True) or (frames_to_floor <= 8)):
                # print(f"[DEBUG] 🚨🚨 바닥 임박 긴급!: frames={frames_to_floor:.1f}, dy={y_distance:.0f}")
                # 바닥 임박은 쿨타임을 무시하고 발동해야 하므로 플래그 설정
                self.urgent_override = True
                return True

        # 상태 기록 갱신(다음 프레임 비교용)
        self.last_player_y = paddle_y
        self.last_ball_y = ball_y
        self.last_y_gap = cur_gap
        # 히스테리시스: 연속으로 갭이 줄어드는 경우 카운트하여 조기 발동 억제
        try:
            if prev_gap is not None and (prev_gap - cur_gap) > 1:
                self.closing_streak = min(self.closing_streak + 1, 5)
            else:
                self.closing_streak = 0
        except Exception:
            pass
        # 히스테리시스: 연속으로 갭이 줄어드는 경우 카운트하여 조기 발동 억제
        try:
            if prev_gap is not None and (prev_gap - cur_gap) > 2:
                self.closing_streak = min(self.closing_streak + 1, 5)
            else:
                self.closing_streak = 0
        except Exception:
            pass

        # 초고속 낙하 근접 시 추가 포착 - miss_at_player_x 무관
        if (not can_reach_at_paddle_y) and ball_speed_y >= 15 and dy_to_player <= 150 and y_distance > PADDLE_HEIGHT / 2:
            print(f"[DEBUG] 🚨 초고속 낙하: vy={ball_speed_y:.0f}, dy_to_player={dy_to_player:.0f}")
            return True

        return False

    def check_danger(self, ball_x, ball_y, ball_vx, ball_vy, paddle_y, paddle_size, player_x=None):
        """공을 놓칠 위험이 있는지 감지 - 플레이어가 패배 직전 상황 판단"""
        # 게임 상수
        PADDLE_WIDTH = 155  # 패들 너비
        PADDLE_HEIGHT = 50  # 패들 높이
        PLAYER_CENTERX = player_x if player_x is not None else 50  # 실제 플레이어 X 위치
        PLAYER_CENTERY = paddle_y  # 실제 플레이어 Y 위치
        SCREEN_HEIGHT = 800  # 게임 화면 높이
        SCREEN_WIDTH = 800  # 게임 화면 너비
        
        # 플레이어 영역 정의 (화면 하단 영역)
        PLAYER_ZONE_MIN_Y = 400  # 플레이어 영역 시작 Y (화면 중앙부터)
        
        # 공이 플레이어 영역에 있지 않으면 위험 없음
        if ball_y < PLAYER_ZONE_MIN_Y:
            return False
        
        # 첫 번째 체크: 공이 플레이어를 향해 오고 있는지 (왼쪽으로 이동)
        if ball_vx >= 0:  # 공이 오른쪽으로 가거나 정지 = 플레이어를 향하지 않음
            return False
        
        # 두 번째 체크: last_hit_by 확인 - 플레이어가 친 공이면 발동 안함
        import sys
        main_module = sys.modules.get('__main__')
        if main_module and hasattr(main_module, 'last_hit_by'):
            last_hit_by = main_module.last_hit_by
            if last_hit_by == "player":
                return False
        
        # 공이 플레이어 뒤에 있으면 이미 놓친 것
        if ball_x <= PLAYER_CENTERX - PADDLE_WIDTH/2:
            return False
        
        # 플레이어 이동 속도 (대시 고려)
        PLAYER_NORMAL_SPEED = 10
        PLAYER_DASH_SPEED = 30  # 대시 속도
        
        # 대시 가능 여부 체크
        can_dash = False
        if main_module and hasattr(main_module, 'rolling_charges'):
            can_dash = main_module.rolling_charges > 0
        
        # 사용할 플레이어 속도 결정
        player_speed = PLAYER_DASH_SPEED if can_dash else PLAYER_NORMAL_SPEED
        
        # 공 속도 (0이면 매우 작은 값으로 설정하여 나눗셈 오류 방지)
        ball_speed = abs(ball_vx) if ball_vx != 0 else 0.1
        
        # 공이 플레이어 X 위치에 도달하는 시간 계산
        x_distance = ball_x - PLAYER_CENTERX
        if x_distance <= 0:  # 이미 지나감
            return False
            
        time_to_reach = x_distance / ball_speed
        
        # Y축 거리 계산
        y_distance = abs(ball_y - PLAYER_CENTERY)
        
        # 플레이어가 Y축으로 이동하는데 필요한 시간
        time_needed_for_y = y_distance / player_speed
        
        # 핵심 판단: 플레이어가 공에 도달할 수 없는 경우
        # 여유 시간을 조금 두어 확실한 경우만 발동
        SAFETY_MARGIN = 0.8  # 80% 마진
        
        if time_needed_for_y > time_to_reach * SAFETY_MARGIN:
            # 패들 높이도 고려 - 패들 범위 내라면 안전
            if y_distance <= PADDLE_HEIGHT / 2:
                return False
            
            print(f"[DEBUG] 🚨 공을 놓칠 위험! X거리:{x_distance:.0f}px, Y거리:{y_distance:.0f}px")
            print(f"       도달 시간:{time_to_reach:.1f}프레임, 필요 시간:{time_needed_for_y:.1f}프레임")
            print(f"       플레이어 속도:{player_speed}, 대시 가능:{can_dash}")
            return True
        
        # 특수 케이스: 매우 빠른 공이 가까이 있을 때
        if ball_speed >= 20 and x_distance <= 100:
            # Y축 거리가 멀고 시간이 부족하면
            if y_distance > 100 and time_needed_for_y > time_to_reach:
                print(f"[DEBUG] 🚨 초고속 공! 속도:{ball_speed:.0f}, X거리:{x_distance:.0f}px")
                return True
        
        # 특수 케이스2: 화면 끝쪽에 있는 공
        if (ball_y <= 50 or ball_y >= SCREEN_HEIGHT - 50):
            # 화면 끝에서 끝으로 이동하는 경우
            if (PLAYER_CENTERY <= 100 and ball_y >= SCREEN_HEIGHT - 100) or \
               (PLAYER_CENTERY >= SCREEN_HEIGHT - 100 and ball_y <= 100):
                # 대각선 거리가 너무 멀면
                diagonal_distance = ((x_distance ** 2) + (y_distance ** 2)) ** 0.5
                diagonal_time = diagonal_distance / player_speed
                if diagonal_time > time_to_reach * SAFETY_MARGIN:
                    print(f"[DEBUG] 🚨 화면 끝 공! 대각선 거리:{diagonal_distance:.0f}px")
                    return True
        
        # 모든 조건을 통과하면 안전
        return False
        
    def update(self, game_state, current_stage):
        """위험 감지 및 자동 아이템 사용"""
        if not self.active:
            print("[DEBUG] 스마트폰이 비활성 상태입니다.")
            return
        
        # Debug: 매 프레임마다 호출되는지 확인 (주석 처리 가능)
        # print("[DEBUG] 스마트폰 update() 호출됨")
        
        # 쿨타임 감소(즉시 리턴하지 않음: 긴급 상황에서 무시하고 발동하기 위함)
        if self.last_activation_time > 0:
            self.last_activation_time -= 1
        # 쿨타임 종료 시 플래그 리셋
        if self.last_activation_time <= 0:
            self.auto_activated = False
            
        # Get necessary game state
        ball_x = getattr(current_stage, 'ball_x', 400)
        ball_y = getattr(current_stage, 'ball_y', 300)
        ball_vx = getattr(current_stage, 'ball_vx', 0)
        ball_vy = getattr(current_stage, 'ball_vy', 0)
        paddle_y = getattr(current_stage, 'paddle_y', 300)
        paddle_size = getattr(current_stage, 'paddle_size', 100)
        
        # Get actual player X position from main module if available
        import sys
        main_module = sys.modules.get('__main__')
        if main_module and hasattr(main_module, 'PLAYER'):
            player_rect = main_module.PLAYER
            if player_rect:
                player_x = player_rect.centerx
                # print(f"[DEBUG] 실제 플레이어 X 위치: {player_x}")
            else:
                player_x = 50  # Default fallback
        else:
            player_x = 50  # Default fallback
        
        # Check if in danger (Y축 판단 버전 사용)
        danger_now = self.check_danger_v2(ball_x, ball_y, ball_vx, ball_vy, paddle_y, paddle_size, player_x)
        # 디바운스: 긴급이 아닌 경우 연속 3프레임 이상 위험일 때만 발동 허용
        allow_persistent = False
        if danger_now:
            if self.urgent_override:
                allow_persistent = True
            else:
                self.danger_streak = min(getattr(self, 'danger_streak', 0) + 1, 6)
                allow_persistent = (self.danger_streak >= 3)
        else:
            self.danger_streak = 0

        if danger_now:
            if not self.auto_activated:  # Prevent multiple activations
                # Check for active items in player's slots
                active_items = game_state.get('active_items', [])
                print(f"[DEBUG] 위험 감지됨! active_items 개수: {len(active_items)}")
                
                # More detailed debugging
                for i, item in enumerate(active_items):
                    if item is None:
                        print(f"[DEBUG] 슬롯 {i}: None (빈 슬롯)")
                    elif isinstance(item, dict):
                        print(f"[DEBUG] 슬롯 {i}: dict - name='{item.get('name', 'NO_NAME')}', effect='{item.get('effect', 'NO_EFFECT')}'")
                        # Print all keys in the item dict for debugging
                        print(f"[DEBUG]   - 아이템 키: {list(item.keys())}")
                    else:
                        print(f"[DEBUG] 슬롯 {i}: 예상치 못한 타입 - {type(item)}")
                
                # Priority: Stopwatch > AI Pill
                stopwatch_available = False
                ai_pill_available = False
                
                for i, item in enumerate(active_items):
                    if item and isinstance(item, dict):
                        item_name = item.get('name', '')
                        # Case-insensitive comparison for safety
                        if item_name.lower() == 'stopwatch':
                            stopwatch_available = True
                            print(f"[DEBUG] ✅ 스탑워치 발견! (슬롯 {i})")
                        elif item_name.lower() in ['aipill', 'ai_pill']:
                            ai_pill_available = True
                            print(f"[DEBUG] ✅ AI알약 발견! (슬롯 {i})")
                            
                # Auto-activate appropriate item (스톱워치 우선)
                can_fire = ((self.last_activation_time <= 0) and allow_persistent) or self.urgent_override
                if stopwatch_available and can_fire:
                    print("🚨 스마트폰: 위험 감지! 스탑워치 자동 사용!")
                    self.activate_stopwatch(game_state, current_stage)
                    self.auto_activated = True
                    # 긴급 발동 후에도 기본 쿨타임 설정
                    self.last_activation_time = self.activation_cooldown
                    self.urgent_override = False
                elif ai_pill_available and can_fire:
                    print("🚨 스마트폰: 위험 감지! AI알약 자동 사용!")
                    self.activate_ai_pill(game_state, current_stage)
                    self.auto_activated = True
                    self.last_activation_time = self.activation_cooldown
                    self.urgent_override = False
                    
    def activate_stopwatch(self, game_state, current_stage):
        """스탑워치 자동 활성화"""
        # Call the global activate_stopwatch function from pingfighter.py
        import sys
        # Get the main module (pingfighter.py)
        main_module = sys.modules.get('__main__')
        if main_module and hasattr(main_module, 'activate_stopwatch'):
            # Check if stopwatch is not already active
            if not getattr(main_module, 'stopwatch_active', False):
                main_module.activate_stopwatch()
                # Remove stopwatch from active items in the actual game slot
                if hasattr(main_module, 'active_item_slot'):
                    active_item_slot = main_module.active_item_slot
                    if active_item_slot:
                        # Find and delete the stopwatch item (like normal usage)
                        for i in range(len(active_item_slot) - 1, -1, -1):  # Iterate backwards to avoid index issues
                            item = active_item_slot[i]
                            if item and item.get('name') == 'stopwatch':
                                del active_item_slot[i]  # Completely remove from list
                                print(f"[DEBUG] 스마트폰이 스탑워치를 슬롯 {i}에서 완전히 제거 (del 사용)")
                                # Adjust selected index if needed
                                if hasattr(main_module, 'selected_item_index'):
                                    if main_module.selected_item_index >= len(active_item_slot):
                                        main_module.selected_item_index = max(0, len(active_item_slot) - 1)
                                break
                # Also remove from local game_state for consistency
                active_items = game_state.get('active_items', [])
                for i in range(len(active_items) - 1, -1, -1):
                    if active_items[i] and active_items[i].get('name') == 'stopwatch':
                        del active_items[i]
                        break
        else:
            print("스탑워치 함수를 찾을 수 없습니다")
            
    def activate_ai_pill(self, game_state, current_stage):
        """AI알약 자동 활성화"""
        # Call the global activate_aipill function from pingfighter.py
        import sys
        # Get the main module (pingfighter.py)
        main_module = sys.modules.get('__main__')
        if main_module and hasattr(main_module, 'activate_aipill'):
            # Check if aipill is not already active
            if not getattr(main_module, 'aipill_active', False):
                main_module.activate_aipill()
                # Remove aipill from active items in the actual game slot
                if hasattr(main_module, 'active_item_slot'):
                    active_item_slot = main_module.active_item_slot
                    if active_item_slot:
                        # Find and delete the aipill item (like normal usage)
                        for i in range(len(active_item_slot) - 1, -1, -1):  # Iterate backwards to avoid index issues
                            item = active_item_slot[i]
                            if item and item.get('name') == 'aipill':
                                del active_item_slot[i]  # Completely remove from list
                                print(f"[DEBUG] 스마트폰이 AI알약을 슬롯 {i}에서 완전히 제거 (del 사용)")
                                # Adjust selected index if needed
                                if hasattr(main_module, 'selected_item_index'):
                                    if main_module.selected_item_index >= len(active_item_slot):
                                        main_module.selected_item_index = max(0, len(active_item_slot) - 1)
                                break
                # Also remove from local game_state for consistency
                active_items = game_state.get('active_items', [])
                for i in range(len(active_items) - 1, -1, -1):
                    if active_items[i] and active_items[i].get('name') == 'aipill':
                        del active_items[i]
                        break
        else:
            print("AI알약 함수를 찾을 수 없습니다")
            
    def draw_effects(self, screen, **kwargs):
        """시각적 효과 (선택사항)"""
        if self.active and self.last_activation_time > 0:
            # Draw a small notification when auto-activation happens
            font = pygame.font.Font(None, 24)
            text = font.render("AUTO!", True, (255, 255, 0))
            screen.blit(text, (100, 50))
            
    def draw_icon(self, surface, x, y, size):
        """아이콘 그리기"""
        # Smartphone body
        body_color = (40, 40, 45)
        screen_color = (100, 150, 200)
        button_color = (60, 60, 65)
        
        # Draw body
        body_rect = pygame.Rect(x + size//4, y + size//6, size//2, size*2//3)
        pygame.draw.rect(surface, body_color, body_rect, border_radius=3)
        
        # Draw screen
        screen_rect = pygame.Rect(x + size//4 + 2, y + size//6 + 3, size//2 - 4, size//2 - 4)
        pygame.draw.rect(surface, screen_color, screen_rect)
        
        # Draw home button
        button_rect = pygame.Rect(x + size//2 - 3, y + size*2//3 - 5, 6, 6)
        pygame.draw.circle(surface, button_color, button_rect.center, 3)
        
        # Draw notification icon on screen
        if self.active:
            # Bell icon
            bell_x = x + size//2
            bell_y = y + size//3
            pygame.draw.circle(surface, (255, 255, 100), (bell_x, bell_y), 3)
            pygame.draw.line(surface, (255, 255, 100), (bell_x - 2, bell_y + 2), (bell_x + 2, bell_y + 2))

# Singleton instance
smartphone_instance = None

def get_smartphone_instance():
    global smartphone_instance
    if smartphone_instance is None:
        print("[DEBUG] 스마트폰 인스턴스 최초 생성")
        smartphone_instance = Smartphone()
    else:
        print(f"[DEBUG] 기존 스마트폰 인스턴스 반환 - active: {smartphone_instance.active}")
    return smartphone_instance
