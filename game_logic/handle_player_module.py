"""
handle_player 함수 - bosspong.py에서 추출
1,137줄의 거대한 함수를 별도 모듈로 분리
"""

import pygame
import math
import random

def handle_player(keys):
    global ball_angle, special_gauge, special_ready, special_active, recent_dash_time, recent_dash_success_window
    global power_smashing_direction, mega_smashing_bonus_applied
    global boss_special_gauge, boss_special_ready
    global current_speed, player_slow_timer
    global rolling_consecutive_count, rolling_consecutive_timer  # 🎯 연속 대쉬 카운터 및 타이머
    global long_boost_active, long_boost_timer, PADDLE_WIDTH
    global long_boost_animating, long_boost_shrinking, long_boost_growing
    global player_stunned_timer, player_knockback_vel  # 🔹 스턴 전역
    global long_boost_scale, long_boost_target_scale, LONG_BOOST_TRANSITION_TIME, LONG_BOOST_DURATION
    global PLAYER, speedboots_obtained, speedgear_obtained
    global aipill_active  # 🆕 AI 필 변수 추가
    global wall_installing  # 🆕 벽돌 설치 변수 추가
    global is_waiting_for_serve  # 🆕 서브 대기 상태 변수 추가
    global is_player_serve  # 🆕 플레이어 서브 상태 변수 추가
    global gravitybelt_obtained  # 🆕 무중력벨트 변수 추가
    global rolling_active, rolling_timer, rolling_direction, rolling_speed
    global rolling_stun_timer, rolling_dash_available_timer, rolling_cooldown, rolling_charges, rolling_charge_timer
    global player_missile_stunned_timer, player_missile_knockback_vel, current_stage  # 스테이지 6 미사일 넉백
    global is_danger_sensor_dash  # 위험감지센서 대쉬 플래그
    global token_states  # 🆕 토큰 상태 리스트
    global molotov_throwing, molotov_throw_timer  # 화염병 투척 모션
    global grenade_throwing, grenade_throw_timer  # 수류탄 투척 모션
    global flare_throwing, flare_throw_timer  # 조명탄 투척 모션
    
    # 🆕 새로운 보스 모드에서는 하단 보스가 플레이어 역할
    if new_boss_mode_active:
        if selected_bottom_boss == 1:
            pass
            handle_fire_knight_as_bottom()  # 파이어 나이트
        elif selected_bottom_boss == 2:
            handle_wind_spirit_as_bottom()  # 윈드 스피릿
        return
    
    # 마우스 조작 처리 (비활성화됨)
    mouse_controls = {}
    # if input_manager.get_control_mode() == "마우스":
    #     mouse_controls = input_manager.handle_mouse_controls(selected_item_index, active_item_slot)

    # 키 입력 변수 초기화
    space_pressed = keys[pygame.K_SPACE]
    down_pressed = keys[pygame.K_DOWN]
    
    # 마우스 조작 (비활성화됨)
    # if input_manager.get_control_mode() == "마우스":
    #     if mouse_controls.get("space", False):
    #         space_pressed = True
    #     if mouse_controls.get("down", False):
    #         down_pressed = True

    special_gauge_max = get_max_gauge()  # 🔧 아카데미 스킬 적용된 최대치

    # ✅ 스턴 상태 처리
    if player_stunned_timer > 0:
        player_stunned_timer -= 1
        # 넉백 적용
        PLAYER.x += player_knockback_vel
        PLAYER.x = max(0, min(WIDTH - PADDLE_WIDTH, PLAYER.x))
        # 감속
        player_knockback_vel *= 0.85
        PLAYER.width = int(PADDLE_WIDTH * long_boost_scale)  # 스턴 중에도 거대화포션 효과 적용
        return  # 🔹 스턴 중에는 조작 불가
    
    # 스테이지 6 미사일 넉백 처리
    if current_stage == 6 and player_missile_stunned_timer > 0:
        player_missile_stunned_timer -= 1
        # 넉백 적용
        PLAYER.x += player_missile_knockback_vel
        PLAYER.x = max(0, min(WIDTH - PADDLE_WIDTH, PLAYER.x))
        # 감속 (화염탄과 동일한 0.85)
        player_missile_knockback_vel *= 0.85
        PLAYER.width = int(PADDLE_WIDTH * long_boost_scale)  # 스턴 중에도 거대화포션 효과 적용
        return  # 미사일 넉백 중에는 조작 불가

    # 🆕 벽돌 설치 중에는 움직이지 못함
    if wall_installing:
        return
    
    # 🔥 화염병 투척 모션 중 처리
    if molotov_throwing:
        molotov_throw_timer -= 1
        if molotov_throw_timer <= 0:
            molotov_throwing = False
            throw_molotov()  # 실제 투척
        return  # 투척 모션 중에는 조작 불가
    
    # 💣 수류탄 투척 모션 중 처리
    if grenade_throwing:
        grenade_throw_timer -= 1
        if grenade_throw_timer <= 0:
            grenade_throwing = False
            throw_grenade()  # 실제 투척
        return  # 투척 모션 중에는 조작 불가
    
    # 💡 조명탄 투척 모션 중 처리
    if flare_throwing:
        flare_throw_timer -= 1
        if flare_throw_timer <= 0:
            flare_throwing = False
            throw_flare()  # 실제 투척
        return  # 투척 모션 중에는 조작 불가
    
    # 연막탄 투척 모션 제거 (즉시 발동으로 변경됨)

    # ✅ 디버프 적용: 느려지는 효과
    if player_slow_timer > 0:
        speed_factor = 0.3
        player_slow_timer -= 1
    else:
        speed_factor = 1.0

    # === 롱부스트 타이머 체크 및 점진적 크기 변화 ===
    if long_boost_active:
        if long_boost_timer > 0:
            long_boost_timer -= 1
            
            # 시작 단계 (1초간 점진적 확대)
            if long_boost_timer > LONG_BOOST_DURATION - LONG_BOOST_TRANSITION_TIME:
                progress = (LONG_BOOST_DURATION - long_boost_timer) / LONG_BOOST_TRANSITION_TIME
                long_boost_scale = 1.0 + (1.5 - 1.0) * progress
                
            # 유지 단계
            elif long_boost_timer > LONG_BOOST_TRANSITION_TIME:
                long_boost_scale = 1.5
                
            # 종료 단계 (1초간 점진적 축소)
            else:
                progress = long_boost_timer / LONG_BOOST_TRANSITION_TIME
                long_boost_scale = 1.0 + (1.5 - 1.0) * progress
            
            # 타이머 종료 시
            if long_boost_timer == 0:
                long_boost_active = False
                long_boost_scale = 1.0
                long_boost_target_scale = 1.0
                print("🍄 거대화포션 효과 종료")
    
    # === 레이저스코프 타이머 체크 ===
    global predictor_active, predictor_timer
    if predictor_active and predictor_timer > 0:
        predictor_timer -= 1
        if predictor_timer == 0:
            predictor_active = False
            print("🎯 레이저스코프 효과 종료!")

    # 🆕 AI 필 효과 적용
    if aipill_active:
        pass
        # AI 필 활성화 시 필살기/아이템 사용 불가 (게이지는 유지하되 획득 불가)
        special_ready = False
        special_active = False
        
        # AI 필 활성화 시 공을 99% 확률로 막아내는 완벽한 추적
        # 공의 중심을 패들의 중심으로 맞추기
        target_x = BALL.centerx - PADDLE_WIDTH // 2
        
        # 경계 처리 - 패들이 화면 밖으로 나가지 않도록
        if target_x < 0:
            pass
            target_x = 0
        elif target_x > WIDTH - PADDLE_WIDTH:
            target_x = WIDTH - PADDLE_WIDTH
        
        # 즉시 목표 위치로 이동 (지연 없음)
        if abs(PLAYER.x - target_x) > 0.5:  # 0.5픽셀 이상 차이나면 움직임
            if PLAYER.x < target_x:
                pass
                # 오른쪽으로 이동
                current_speed = MAX_SPEED * aipill_speed_boost
            elif PLAYER.x > target_x:
                pass
                # 왼쪽으로 이동
                current_speed = -MAX_SPEED * aipill_speed_boost
        else:
            pass
            # 목표 위치에 도달하면 즉시 정지
            current_speed = 0
    else:
        pass
        # 🆕 구르기 상태 처리
        if rolling_active:
            pass
            # 구르기 중일 때
            rolling_timer -= 1
            if rolling_timer <= 0:
                pass
                # 구르기 종료, 통제 불가능 상태 시작
                rolling_active = False
                
                # 🤖 위험감지센서 자동 대쉬는 통제불능시간 없음
                if is_danger_sensor_dash:
                    rolling_stun_timer = 0
                    rolling_dash_available_timer = 0
                    is_danger_sensor_dash = False  # 플래그 리셋
                    print("🤖 위험감지센서 자동 대쉬 완료 - 통제불능시간 제거!")
                else:
                    pass
                    # 일반 대쉬의 경우 기존 로직 적용
                    # 아카데미 스킬 효과: 통제불능 시간 감소 (모듈제어)
                    module_control_bonus = academy.get_skill_bonus("dash_module_control")
                    stun_reduction = int(module_control_bonus * 30)  # 기본 30프레임에서 10%씩 감소
                    
                    # 스파이크부츠 효과: 제어불능 시간 15% 감소
                    base_stun_time = 30  # 0.5초 (60fps * 0.5)
                    if spikeboots_obtained:
                        base_stun_time = int(base_stun_time * 0.85)  # 15% 감소 (85%로 단축)
                    
                    final_stun_time = max(1, base_stun_time - stun_reduction)  # 최소 1프레임
                    rolling_stun_timer = final_stun_time
                    rolling_dash_available_timer = final_stun_time
                
                current_speed = 0
            else:
                pass
                # 구르기 중에는 순간적으로 매우 빠르게 이동 후 빠르게 감속
                if rolling_timer > 20:  # 처음 10프레임은 매우 빠르게
                    pass
                    current_speed = rolling_direction * 40  # 매우 빠른 속도 (50에서 40으로 20% 감소)
                else:  # 나머지는 빠르게 감속
                    decel_factor = rolling_timer / 20.0
                    current_speed = rolling_direction * 40 * decel_factor
        elif rolling_stun_timer > 0:
            pass
            # 구르기 후 통제 불가능 상태
            rolling_stun_timer -= 1
            if rolling_dash_available_timer > 0:
                rolling_dash_available_timer -= 1
            # 통제 불가능 중에는 조작 불가
            if not gravitybelt_obtained:
                pass
                # 무중력벨트가 없을 때만 감속 적용
                if current_speed > 0:
                    pass
                    current_speed -= DECELERATION * 2  # 빠른 감속
                elif current_speed < 0:
                    current_speed += DECELERATION * 2

            # 🎯 토큰이 2개 이상 있을 때 통제불능 상태에서도 추가 대쉬 가능 (대쉬홀더 또는 증폭 스킬)
            base_charges = 1  # 기본 1개
            holder_bonus = 1 if dashholder_obtained else 0  # 대쉬홀더 +1개
            amplification_bonus = academy.get_skill_bonus("dash_amplification")
            max_charges = int(base_charges + holder_bonus + amplification_bonus)
            
            if max_charges > 1 and rolling_charges > 0:
                pass
                # 🎯 연속 대쉬 할인을 고려한 실제 게이지 요구량 계산
                base_gauge_cost = 140  # 대시 기본 비용: 160 → 140
                # 대시 실행 시 rolling_consecutive_count가 1 증가하므로 미리 계산
                next_consecutive_count = rolling_consecutive_count + 1
                consecutive_discount = 0.5 ** (next_consecutive_count - 1)  # 실제 대시에서 사용할 할인율
                discounted_cost = int(base_gauge_cost * consecutive_discount)
                if dashgear_obtained:
                    discounted_cost = int(discounted_cost * 0.8)  # 대쉬기어 20% 할인
                battery_bonus = academy.get_skill_bonus("dash_battery_pack")
                required_gauge = max(10, int(discounted_cost * (1 - battery_bonus)))  # 실제 필요 게이지
                
                if keys[pygame.K_LEFT] and down_pressed and special_gauge >= required_gauge and rolling_charges > 0:
                    pass
                    # 통제불능 상태에서 왼쪽 대쉬 실행 (아래키 + 왼쪽키 필요)
                    rolling_active = True
                    
                    # 🆕 대쉬 효과음 재생
                    SOUND_DASH.play()
                    
                    # 대쉬기어 효과: 대쉬 거리 10% 증가
                    base_rolling_timer = 15  # 기본 대쉬 시간
                    if dashgear_obtained:
                        base_rolling_timer = 16  # 0.267초 대쉬 (15 * 1.1)
                    
                    # 🚀 아카데미 스킬 효과 적용: 대쉬 거리 증가 (도약)
                    jump_bonus = academy.get_skill_bonus("dash_jump")  # 도약: 대쉬거리 증가
                    total_distance_bonus = jump_bonus
                    base_rolling_timer = int(base_rolling_timer * (1 + total_distance_bonus))
                    
                    # 스킬 효과 적용: 대쉬 거리 증가
                    skill_distance_boost = skill.apply_dash_distance_boost(base_rolling_timer)
                    rolling_timer = int(skill_distance_boost)
                    rolling_direction = -1
                    
                    # 🌟 대쉬 스피릿 스킬: 확률적 레이저 생성
                    dash_spirit_level = academy.get_skill_bonus("dash_spirit")
                    if dash_spirit_level > 0:
                        pass
                        # 확률 계산: 레벨1=15%, 레벨2=30%
                        dash_spirit_chance = dash_spirit_level
                        if random.random() < dash_spirit_chance:
                            pass
                            # 🎯 플레이어를 따라오다가 대쉬 거리의 50% 지점에서 스피릿 생성 종료
                            # 대쉬 중 속도는 40, 첫 20프레임은 최대 속도, 이후 감속
                            # 평균적으로 rolling_timer의 약 70% 정도가 효과적인 이동 시간
                            actual_dash_distance = int(rolling_timer * 40 * 0.7)  # 실제 대쉬 거리
                            dash_distance = int(actual_dash_distance * 0.5)  # 대쉬 거리의 50% 지점에서 종료
                            create_dash_spirit_laser(PLAYER.centerx, PLAYER.centery, -1, dash_distance)
                    # 🔧 토큰 사용 - 대쉬 매니저와 동기화
                    rolling_charges = max(0, rolling_charges - 1)
                    
                    # 최대 토큰 수 계산 (먼저 계산해야 함)
                    base_charges = 1  # 기본 1개
                    holder_bonus = 1 if dashholder_obtained else 0  # 대쉬홀더 +1개
                    amplification_bonus = academy.get_skill_bonus("dash_amplification")
                    max_charges = int(base_charges + holder_bonus + amplification_bonus)
                    
                    # 오른쪽부터 토큰 소진 (token_states가 있을 때만)
                    if 'token_states' in globals() and len(token_states) > 0:
                        pass
                        # 오른쪽부터 검색하여 소진
                        for idx in range(min(len(token_states), max_charges) - 1, -1, -1):
                            if idx < len(token_states) and token_states[idx]:
                                token_states[idx] = False
                                break
                    else:
                        pass
                        # token_states가 없으면 초기화
                        token_states = [True] * rolling_charges + [False] * (max_charges - rolling_charges)
                    
                    # 아카데미 스킬 효과: 쿨타임 감소
                    dash_cooldown_bonus = academy.get_skill_bonus("dash_cooldown")
                    cooldown_reduction = int(dash_cooldown_bonus * 60)  # 초 단위를 프레임으로 변환
                    
                    # 다중 토큰 시스템 로직 (대쉬홀더 또는 증폭 스킬)
                    if max_charges > 1:
                        if rolling_charges >= 1:  # 아직 1개 이상 남아있으면 (2개에서 1개 사용)
                            rolling_cooldown = max(6, 60 - cooldown_reduction)   # 1초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 60 - cooldown_reduction)  # 1초 후 풀 충전 (2개로)
                        else:  # 마지막 대쉬 사용 (1개에서 0개)
                            rolling_cooldown = max(6, 90 - cooldown_reduction)   # 1.5초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 90 - cooldown_reduction)  # 1.5초 후 1개 충전
                    else:
                        pass
                        # 기본 대쉬 후 1.5초
                        base_cooldown = 90  # 1.5초 (90프레임)
                        
                        # 스파이크부츠 효과: 쿨타임 20% 감소
                        if spikeboots_obtained:
                            base_cooldown = int(base_cooldown * 0.8)  # 20% 감소 (80%로 단축)
                        
                        rolling_cooldown = max(6, base_cooldown - cooldown_reduction)  # 최소 0.1초
                        rolling_charge_timer = max(6, base_cooldown - cooldown_reduction)  # 쿨타임과 동일
                        print(f"[DEBUG] 대쉬 사용 후 충전 타이머 설정: {rolling_charge_timer} (토큰: {rolling_charges})")
                    
                    # 🎯 연속 대쉬 할인 시스템: 연속 사용 시 50%씩 할인
                    rolling_consecutive_count += 1
                    rolling_consecutive_timer = 60  # 1초간 연속 대쉬 유지
                    
                    # 🔧 대쉬 매니저와 동기화 - 토큰 소모 및 충전 타이머 설정
                    if dash is not None:
                        dash.sync_with_legacy_system(rolling_charges, rolling_charge_timer, rolling_consecutive_count)
                    
                    # 기본 게이지 소모량
                    base_gauge_cost = 140  # 대시 기본 비용: 160 → 140
                    
                    # 연속 대쉬 할인 계산 (첫 번째: 160, 두 번째: 80, 세 번째: 40...)
                    consecutive_discount = 0.5 ** (rolling_consecutive_count - 1)  # 0.5^0=1, 0.5^1=0.5, 0.5^2=0.25...
                    discounted_cost = int(base_gauge_cost * consecutive_discount)
                    
                    # 대쉬기어 효과: 게이지 소모 20% 감소
                    if dashgear_obtained:
                        discounted_cost = int(discounted_cost * 0.8)  # 20% 추가 할인
                    
                    # 아카데미 스킬 효과 적용: 게이지 소모 감소 (배터리팩)
                    battery_bonus = academy.get_skill_bonus("dash_battery_pack")
                    final_gauge_cost = max(10, int(discounted_cost * (1 - battery_bonus)))  # 최소 10은 소모
                    special_gauge = max(0, special_gauge - final_gauge_cost)  # 게이지가 음수가 되지 않도록 보정
                    # 🔹 게이지 감소 시 special_ready 상태 업데이트
                    if special_gauge < special_gauge_max:
                        special_ready = False
                    print(f"통제불능 상태에서 왼쪽 대쉬 실행! (연속 {rolling_consecutive_count}회, 할인된 소모: {final_gauge_cost}, 남은 횟수: {rolling_charges}, 게이지: {special_gauge})")
                
                elif keys[pygame.K_RIGHT] and down_pressed and special_gauge >= required_gauge and rolling_charges > 0:
                    pass
                    # 통제불능 상태에서 오른쪽 대쉬 실행 (아래키 + 오른쪽키 필요)
                    rolling_active = True
                    
                    # 🆕 대쉬 효과음 재생
                    SOUND_DASH.play()
                    
                    # 대쉬기어 효과: 대쉬 거리 10% 증가
                    base_rolling_timer = 15  # 기본 대쉬 시간
                    if dashgear_obtained:
                        base_rolling_timer = 16  # 0.267초 대쉬 (15 * 1.1)
                    
                    # 🚀 아카데미 스킬 효과 적용: 대쉬 거리 증가 (도약)
                    jump_bonus = academy.get_skill_bonus("dash_jump")  # 도약: 대쉬거리 증가
                    total_distance_bonus = jump_bonus
                    base_rolling_timer = int(base_rolling_timer * (1 + total_distance_bonus))
                    
                    # 스킬 효과 적용: 대쉬 거리 증가
                    skill_distance_boost = skill.apply_dash_distance_boost(base_rolling_timer)
                    rolling_timer = int(skill_distance_boost)
                    rolling_direction = 1
                    
                    # 🌟 대쉬 스피릿 스킬: 확률적 레이저 생성
                    dash_spirit_level = academy.get_skill_bonus("dash_spirit")
                    if dash_spirit_level > 0:
                        pass
                        # 확률 계산: 레벨1=15%, 레벨2=30%
                        dash_spirit_chance = dash_spirit_level
                        if random.random() < dash_spirit_chance:
                            pass
                            # 🎯 플레이어를 따라오다가 대쉬 거리의 50% 지점에서 스피릿 생성 종료
                            # 대쉬 중 속도는 40, 첫 20프레임은 최대 속도, 이후 감속
                            # 평균적으로 rolling_timer의 약 70% 정도가 효과적인 이동 시간
                            actual_dash_distance = int(rolling_timer * 40 * 0.7)  # 실제 대쉬 거리
                            dash_distance = int(actual_dash_distance * 0.5)  # 대쉬 거리의 50% 지점에서 종료
                            create_dash_spirit_laser(PLAYER.centerx, PLAYER.centery, 1, dash_distance)
                    # 🔧 토큰 사용 - 대쉬 매니저와 동기화
                    rolling_charges = max(0, rolling_charges - 1)
                    
                    # 최대 토큰 수 계산 (먼저 계산해야 함)
                    base_charges = 1  # 기본 1개
                    holder_bonus = 1 if dashholder_obtained else 0  # 대쉬홀더 +1개
                    amplification_bonus = academy.get_skill_bonus("dash_amplification")
                    max_charges = int(base_charges + holder_bonus + amplification_bonus)
                    
                    # 오른쪽부터 토큰 소진 (token_states가 있을 때만)
                    if 'token_states' in globals() and len(token_states) > 0:
                        pass
                        # 오른쪽부터 검색하여 소진
                        for idx in range(min(len(token_states), max_charges) - 1, -1, -1):
                            if idx < len(token_states) and token_states[idx]:
                                token_states[idx] = False
                                break
                    else:
                        pass
                        # token_states가 없으면 초기화
                        token_states = [True] * rolling_charges + [False] * (max_charges - rolling_charges)
                    
                    # 아카데미 스킬 효과: 쿨타임 감소
                    dash_cooldown_bonus = academy.get_skill_bonus("dash_cooldown")
                    cooldown_reduction = int(dash_cooldown_bonus * 60)  # 초 단위를 프레임으로 변환
                    
                    # 다중 토큰 시스템 로직 (대쉬홀더 또는 증폭 스킬)
                    if max_charges > 1:
                        if rolling_charges >= 1:  # 아직 1개 이상 남아있으면 (2개에서 1개 사용)
                            rolling_cooldown = max(6, 60 - cooldown_reduction)   # 1초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 60 - cooldown_reduction)  # 1초 후 풀 충전 (2개로)
                        else:  # 마지막 대쉬 사용 (1개에서 0개)
                            rolling_cooldown = max(6, 90 - cooldown_reduction)   # 1.5초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 90 - cooldown_reduction)  # 1.5초 후 1개 충전
                    else:
                        pass
                        # 기본 대쉬 후 1.5초
                        base_cooldown = 90  # 1.5초 (90프레임)
                        
                        # 스파이크부츠 효과: 쿨타임 20% 감소
                        if spikeboots_obtained:
                            base_cooldown = int(base_cooldown * 0.8)  # 20% 감소 (80%로 단축)
                        
                        rolling_cooldown = max(6, base_cooldown - cooldown_reduction)  # 최소 0.1초
                        rolling_charge_timer = max(6, base_cooldown - cooldown_reduction)  # 쿨타임과 동일
                        print(f"[DEBUG] 대쉬 사용 후 충전 타이머 설정: {rolling_charge_timer} (토큰: {rolling_charges})")
                    
                    # 기본 게이지 소모량
                    base_gauge_cost = 140  # 대시 기본 비용: 160 → 140
                    discounted_cost = base_gauge_cost
                    
                    # 대쉬기어 효과: 게이지 소모 20% 감소
                    if dashgear_obtained:
                        discounted_cost = int(discounted_cost * 0.8)  # 20% 할인
                    
                    # 아카데미 스킬 효과 적용: 게이지 소모 감소 (배터리팩)
                    battery_bonus = academy.get_skill_bonus("dash_battery_pack")
                    final_gauge_cost = max(10, int(discounted_cost * (1 - battery_bonus)))  # 최소 10은 소모
                    special_gauge = max(0, special_gauge - final_gauge_cost)  # 게이지가 음수가 되지 않도록 보정
                    # 🔹 게이지 감소 시 special_ready 상태 업데이트
                    if special_gauge < special_gauge_max:
                        special_ready = False
                    print(f"통제불능 상태에서 오른쪽 대쉬 실행! (남은 횟수: {rolling_charges}, 게이지: {special_gauge})")

        else:
            pass
            # 🆕 구르기 쿨타임 감소
            if rolling_cooldown > 0:
                rolling_cooldown -= 1
            
            # 🆕 연속 대쉬 타이머 감소 (1초 후 연속 대쉬 카운터 리셋)
            if rolling_consecutive_timer > 0:
                rolling_consecutive_timer -= 1
                if rolling_consecutive_timer <= 0:
                    rolling_consecutive_count = 0  # 연속 대쉬 카운터 리셋
                    print("연속 대쉬 시간 만료 - 할인 리셋")
            
            # 🆕 구르기 충전 타이머 감소
            if rolling_charge_timer > 0:
                old_timer = rolling_charge_timer
                rolling_charge_timer -= 1
                if rolling_charge_timer % 30 == 0 or rolling_charge_timer <= 5:
                    print(f"[DEBUG] 충전 타이머 감소: {old_timer} → {rolling_charge_timer}")
                
                if rolling_charge_timer <= 0:
                    pass
                    # 토큰 충전
                    base_charges = 1
                    holder_bonus = 1 if dashholder_obtained else 0
                    amplification_bonus = academy.get_skill_bonus("dash_amplification")
                    max_charges = int(base_charges + holder_bonus + amplification_bonus)
                    
                    old_charges = rolling_charges
                    rolling_charges = min(rolling_charges + 1, max_charges)
                    
                    # 왼쪽부터 토큰 충전 (token_states가 있을 때만)
                    if 'token_states' in globals() and len(token_states) > 0:
                        pass
                        # 첫 번째 비어있는 토큰을 찾아서 충전
                        for idx in range(min(len(token_states), max_charges)):
                            if idx < len(token_states) and not token_states[idx]:
                                token_states[idx] = True
                                break
                    else:
                        pass
                        # token_states가 없으면 초기화
                        token_states = [True] * rolling_charges + [False] * (max_charges - rolling_charges)
                    
                    # 아직 최대 토큰이 아니면 다음 충전 타이머 설정
                    if rolling_charges < max_charges:
                        pass
                        # 경량화 스킬 효과 적용
                        lightweight_bonus = academy.get_skill_bonus("dash_lightweight")
                        charge_time_reduction = lightweight_bonus
                        base_charge_time = 90  # 1.5초
                        rolling_charge_timer = int(base_charge_time * (1 - charge_time_reduction))
                        print(f"[DEBUG] 다음 토큰 충전 타이머 설정: {rolling_charge_timer}프레임")
                    else:
                        rolling_consecutive_count = 0  # 모든 토큰 충전 시 연속 카운터 리셋
                    
                    print(f"✅ 토큰 충전 완료! 현재: {rolling_charges}/{max_charges}")
                    print(f"[DEBUG] 충전 후 타이머: {rolling_charge_timer}")
            
            # 🆕 구르기 충전 - 대쉬 매니저에게 위임 (비활성화 - 고스트샷 버그 때문에)
            # 대쉬 매니저와의 동기화를 일시적으로 비활성화
            if False and dash is not None:
                pass
                # 대쉬 매니저의 상태를 가져와서 레거시 시스템과 동기화
                dash_tokens, dash_timer, dash_consecutive, dash_max = dash.get_legacy_sync_data()
                if rolling_charges != dash_tokens or rolling_charge_timer != dash_timer:
                    rolling_charges = dash_tokens
                    rolling_charge_timer = dash_timer
                    rolling_consecutive_count = dash_consecutive
            
            # 🆕 구르기 더블탭 감지
            current_time = pygame.time.get_ticks()
            
            # 아래키 + 방향키로 대쉬 발동 (무릎보호대 효과 적용)
            # 플레이어 서브 상태일 때 처음 6초 동안은 대쉬 발동 불가
            can_use_rolling = False
            
            # 기본 대쉬 조건 (일반 상태에서만)
            if rolling_charges > 0 and not is_waiting_for_serve and rolling_stun_timer <= 0:
                can_use_rolling = True
            # 플레이어 서브 상태에서는 6초 후에만 대쉬 가능
            elif is_player_serve and is_waiting_for_serve and rolling_charges > 0:
                serve_wait_time = pygame.time.get_ticks() - waiting_start_time
                if serve_wait_time >= 6000:  # 6초 이상 대기했을 때만
                    can_use_rolling = True
            
            # 디버깅: 대쉬 조건 확인
            if keys[pygame.K_DOWN]:
                print(f"아래키 눌림 - 대쉬 조건: charges={rolling_charges}, stun_timer={rolling_stun_timer}, waiting_serve={is_waiting_for_serve}, player_serve={is_player_serve}, can_use={can_use_rolling}")
                if is_player_serve and is_waiting_for_serve:
                    serve_wait_time = pygame.time.get_ticks() - waiting_start_time
                    print(f"서브 대기 시간: {serve_wait_time}ms")
            
            if down_pressed and can_use_rolling and rolling_charges > 0 and not rolling_active:
                pass
                # 🎯 연속 대쉬 할인을 고려한 실제 게이지 요구량 계산  
                base_gauge_cost = 140  # 대시 기본 비용: 160 → 140
                # 대시 실행 시 rolling_consecutive_count가 1 증가하므로 미리 계산
                next_consecutive_count = rolling_consecutive_count + 1
                consecutive_discount = 0.5 ** (next_consecutive_count - 1)  # 실제 대시에서 사용할 할인율
                discounted_cost = int(base_gauge_cost * consecutive_discount)
                if dashgear_obtained:
                    discounted_cost = int(discounted_cost * 0.8)  # 대쉬기어 20% 할인
                battery_bonus = academy.get_skill_bonus("dash_battery_pack")
                required_gauge = max(10, int(discounted_cost * (1 - battery_bonus)))  # 실제 필요 게이지
                
                if keys[pygame.K_LEFT] and keys[pygame.K_DOWN] and special_gauge >= required_gauge:
                    pass
                    # 아래키 + 왼쪽 - 대쉬 실행
                    rolling_active = True
                    
                    # 🆕 대쉬 효과음 재생
                    SOUND_DASH.play()
                    
                    # 대쉬기어 효과: 대쉬 거리 10% 증가
                    base_rolling_timer = 15  # 기본 대쉬 시간
                    if dashgear_obtained:
                        base_rolling_timer = 16  # 0.267초 대쉬 (15 * 1.1)
                    
                    # 아카데미 스킬 효과 적용: 대쉬 거리 증가 (도약)
                    jump_bonus = academy.get_skill_bonus("dash_jump")  # 도약: 대쉬거리 증가
                    total_distance_bonus = jump_bonus
                    base_rolling_timer = int(base_rolling_timer * (1 + total_distance_bonus))
                    
                    # 스킬 효과 적용: 대쉬 거리 증가 (기존 시스템 유지)
                    skill_distance_boost = skill.apply_dash_distance_boost(base_rolling_timer)
                    rolling_timer = int(skill_distance_boost)
                    rolling_direction = -1
                    
                    # 🌟 대쉬 스피릿 스킬: 확률적 레이저 생성
                    dash_spirit_level = academy.get_skill_bonus("dash_spirit")
                    if dash_spirit_level > 0:
                        pass
                        # 확률 계산: 레벨1=15%, 레벨2=30%
                        dash_spirit_chance = dash_spirit_level
                        if random.random() < dash_spirit_chance:
                            pass
                            # 🎯 플레이어를 따라오다가 대쉬 거리의 50% 지점에서 스피릿 생성 종료
                            # 대쉬 중 속도는 40, 첫 20프레임은 최대 속도, 이후 감속
                            # 평균적으로 rolling_timer의 약 70% 정도가 효과적인 이동 시간
                            actual_dash_distance = int(rolling_timer * 40 * 0.7)  # 실제 대쉬 거리
                            dash_distance = int(actual_dash_distance * 0.5)  # 대쉬 거리의 50% 지점에서 종료
                            create_dash_spirit_laser(PLAYER.centerx, PLAYER.centery, -1, dash_distance)
                    # 🔧 토큰 사용 - 대쉬 매니저와 동기화
                    rolling_charges = max(0, rolling_charges - 1)
                    
                    # 최대 토큰 수 계산 (먼저 계산해야 함)
                    base_charges = 1  # 기본 1개
                    holder_bonus = 1 if dashholder_obtained else 0  # 대쉬홀더 +1개
                    amplification_bonus = academy.get_skill_bonus("dash_amplification")
                    max_charges = int(base_charges + holder_bonus + amplification_bonus)
                    
                    # 오른쪽부터 토큰 소진 (token_states가 있을 때만)
                    if 'token_states' in globals() and len(token_states) > 0:
                        pass
                        # 오른쪽부터 검색하여 소진
                        for idx in range(min(len(token_states), max_charges) - 1, -1, -1):
                            if idx < len(token_states) and token_states[idx]:
                                token_states[idx] = False
                                break
                    else:
                        pass
                        # token_states가 없으면 초기화
                        token_states = [True] * rolling_charges + [False] * (max_charges - rolling_charges)
                    
                    # 아카데미 스킬 효과: 쿨타임 감소
                    dash_cooldown_bonus = academy.get_skill_bonus("dash_cooldown")
                    cooldown_reduction = int(dash_cooldown_bonus * 60)  # 초 단위를 프레임으로 변환
                    
                    # 다중 토큰 시스템 로직 (대쉬홀더 또는 증폭 스킬)
                    if max_charges > 1:
                        if rolling_charges >= 1:  # 아직 1개 이상 남아있으면 (2개에서 1개 사용)
                            rolling_cooldown = max(6, 60 - cooldown_reduction)   # 1초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 60 - cooldown_reduction)  # 1초 후 풀 충전 (2개로)
                        else:  # 마지막 대쉬 사용 (1개에서 0개)
                            rolling_cooldown = max(6, 90 - cooldown_reduction)   # 1.5초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 90 - cooldown_reduction)  # 1.5초 후 1개 충전
                    else:
                        pass
                        # 기본 대쉬 후 1.5초
                        base_cooldown = 90  # 1.5초 (90프레임)
                        
                        # 스파이크부츠 효과: 쿨타임 20% 감소
                        if spikeboots_obtained:
                            base_cooldown = int(base_cooldown * 0.8)  # 20% 감소 (80%로 단축)
                        
                        rolling_cooldown = max(6, base_cooldown - cooldown_reduction)  # 최소 0.1초
                        rolling_charge_timer = max(6, base_cooldown - cooldown_reduction)  # 쿨타임과 동일
                        print(f"[DEBUG] 대쉬 사용 후 충전 타이머 설정: {rolling_charge_timer} (토큰: {rolling_charges})")
                    
                    # 🎯 연속 대쉬 할인 시스템: 연속 사용 시 50%씩 할인
                    rolling_consecutive_count += 1
                    rolling_consecutive_timer = 60  # 1초간 연속 대쉬 유지
                    
                    # 🔧 대쉬 매니저와 동기화 - 토큰 소모 및 충전 타이머 설정
                    if dash is not None:
                        dash.sync_with_legacy_system(rolling_charges, rolling_charge_timer, rolling_consecutive_count)
                    
                    # 기본 게이지 소모량
                    base_gauge_cost = 140  # 대시 기본 비용: 160 → 140
                    
                    # 연속 대쉬 할인 계산 (첫 번째: 160, 두 번째: 80, 세 번째: 40...)
                    consecutive_discount = 0.5 ** (rolling_consecutive_count - 1)  # 0.5^0=1, 0.5^1=0.5, 0.5^2=0.25...
                    discounted_cost = int(base_gauge_cost * consecutive_discount)
                    
                    # 대쉬기어 효과: 게이지 소모 20% 감소
                    if dashgear_obtained:
                        discounted_cost = int(discounted_cost * 0.8)  # 20% 추가 할인
                    
                    # 아카데미 스킬 효과 적용: 게이지 소모 감소 (배터리팩)
                    battery_bonus = academy.get_skill_bonus("dash_battery_pack")
                    final_gauge_cost = max(10, int(discounted_cost * (1 - battery_bonus)))  # 최소 10은 소모
                    special_gauge = max(0, special_gauge - final_gauge_cost)  # 게이지가 음수가 되지 않도록 보정
                    # 🔹 게이지 감소 시 special_ready 상태 업데이트
                    if special_gauge < special_gauge_max:
                        special_ready = False
                    print(f"왼쪽 대쉬 실행! (연속 {rolling_consecutive_count}회, 할인된 소모: {final_gauge_cost}, 남은 횟수: {rolling_charges}, 게이지: {special_gauge})")
                    
                    # 🏆 대쉬 사용 기록

                    recent_dash_time = pygame.time.get_ticks()
                    mega_smashing_bonus_applied = False  # 고스트샷 보너스 리셋 (새로운 콤보 가능)
                    record_dash_usage(success=False)  # 일단 사용만 기록, 성공은 공 충돌 시 체크
                # 🔧 대쉬 매니저와 4번째 대쉬 위치 동기화
                if dash is not None and rolling_charge_timer > 0:
                    dash.sync_with_legacy_system(rolling_charges, rolling_charge_timer, rolling_consecutive_count)
                
                elif keys[pygame.K_RIGHT] and keys[pygame.K_DOWN] and special_gauge >= required_gauge:
                    pass
                    # 아래키 + 오른쪽 - 대쉬 실행
                    rolling_active = True
                    
                    # 🆕 대쉬 효과음 재생
                    SOUND_DASH.play()
                    
                    # 대쉬기어 효과: 대쉬 거리 10% 증가
                    base_rolling_timer = 15  # 기본 대쉬 시간
                    if dashgear_obtained:
                        base_rolling_timer = 16  # 0.267초 대쉬 (15 * 1.1)
                    
                    # 아카데미 스킬 효과 적용: 대쉬 거리 증가 (도약)
                    jump_bonus = academy.get_skill_bonus("dash_jump")  # 도약: 대쉬거리 증가
                    total_distance_bonus = jump_bonus
                    base_rolling_timer = int(base_rolling_timer * (1 + total_distance_bonus))
                    
                    # 스킬 효과 적용: 대쉬 거리 증가 (기존 시스템 유지)
                    skill_distance_boost = skill.apply_dash_distance_boost(base_rolling_timer)
                    rolling_timer = int(skill_distance_boost)
                    rolling_direction = 1
                    
                    # 🌟 대쉬 스피릿 스킬: 확률적 레이저 생성
                    dash_spirit_level = academy.get_skill_bonus("dash_spirit")
                    if dash_spirit_level > 0:
                        pass
                        # 확률 계산: 레벨1=15%, 레벨2=30%
                        dash_spirit_chance = dash_spirit_level
                        if random.random() < dash_spirit_chance:
                            pass
                            # 🎯 플레이어를 따라오다가 대쉬 거리의 50% 지점에서 스피릿 생성 종료
                            # 대쉬 중 속도는 40, 첫 20프레임은 최대 속도, 이후 감속
                            # 평균적으로 rolling_timer의 약 70% 정도가 효과적인 이동 시간
                            actual_dash_distance = int(rolling_timer * 40 * 0.7)  # 실제 대쉬 거리
                            dash_distance = int(actual_dash_distance * 0.5)  # 대쉬 거리의 50% 지점에서 종료
                            create_dash_spirit_laser(PLAYER.centerx, PLAYER.centery, 1, dash_distance)
                    # 🔧 토큰 사용 - 대쉬 매니저와 동기화
                    rolling_charges = max(0, rolling_charges - 1)
                    
                    # 최대 토큰 수 계산 (먼저 계산해야 함)
                    base_charges = 1  # 기본 1개
                    holder_bonus = 1 if dashholder_obtained else 0  # 대쉬홀더 +1개
                    amplification_bonus = academy.get_skill_bonus("dash_amplification")
                    max_charges = int(base_charges + holder_bonus + amplification_bonus)
                    
                    # 오른쪽부터 토큰 소진 (token_states가 있을 때만)
                    if 'token_states' in globals() and len(token_states) > 0:
                        pass
                        # 오른쪽부터 검색하여 소진
                        for idx in range(min(len(token_states), max_charges) - 1, -1, -1):
                            if idx < len(token_states) and token_states[idx]:
                                token_states[idx] = False
                                break
                    else:
                        pass
                        # token_states가 없으면 초기화
                        token_states = [True] * rolling_charges + [False] * (max_charges - rolling_charges)
                    
                    # 아카데미 스킬 효과: 쿨타임 감소
                    dash_cooldown_bonus = academy.get_skill_bonus("dash_cooldown")
                    cooldown_reduction = int(dash_cooldown_bonus * 60)  # 초 단위를 프레임으로 변환
                    
                    # 다중 토큰 시스템 로직 (대쉬홀더 또는 증폭 스킬)
                    if max_charges > 1:
                        if rolling_charges >= 1:  # 아직 1개 이상 남아있으면 (2개에서 1개 사용)
                            rolling_cooldown = max(6, 60 - cooldown_reduction)   # 1초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 60 - cooldown_reduction)  # 1초 후 풀 충전 (2개로)
                        else:  # 마지막 대쉬 사용 (1개에서 0개)
                            rolling_cooldown = max(6, 90 - cooldown_reduction)   # 1.5초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 90 - cooldown_reduction)  # 1.5초 후 1개 충전
                    else:
                        pass
                        # 기본 대쉬 후 1.5초
                        base_cooldown = 90  # 1.5초 (90프레임)
                        
                        # 스파이크부츠 효과: 쿨타임 20% 감소
                        if spikeboots_obtained:
                            base_cooldown = int(base_cooldown * 0.8)  # 20% 감소 (80%로 단축)
                        
                        rolling_cooldown = max(6, base_cooldown - cooldown_reduction)  # 최소 0.1초
                        rolling_charge_timer = max(6, base_cooldown - cooldown_reduction)  # 쿨타임과 동일
                        print(f"[DEBUG] 대쉬 사용 후 충전 타이머 설정: {rolling_charge_timer} (토큰: {rolling_charges})")
                    
                    # 🎯 연속 대쉬 할인 시스템: 연속 사용 시 50%씩 할인
                    rolling_consecutive_count += 1
                    rolling_consecutive_timer = 60  # 1초간 연속 대쉬 유지
                    
                    # 🔧 대쉬 매니저와 동기화 - 토큰 소모 및 충전 타이머 설정
                    if dash is not None:
                        dash.sync_with_legacy_system(rolling_charges, rolling_charge_timer, rolling_consecutive_count)
                    
                    # 기본 게이지 소모량
                    base_gauge_cost = 140  # 대시 기본 비용: 160 → 140
                    
                    # 연속 대쉬 할인 계산 (첫 번째: 160, 두 번째: 80, 세 번째: 40...)
                    consecutive_discount = 0.5 ** (rolling_consecutive_count - 1)  # 0.5^0=1, 0.5^1=0.5, 0.5^2=0.25...
                    discounted_cost = int(base_gauge_cost * consecutive_discount)
                    
                    # 대쉬기어 효과: 게이지 소모 20% 감소
                    if dashgear_obtained:
                        discounted_cost = int(discounted_cost * 0.8)  # 20% 추가 할인
                    
                    # 아카데미 스킬 효과 적용: 게이지 소모 감소 (배터리팩)
                    battery_bonus = academy.get_skill_bonus("dash_battery_pack")
                    final_gauge_cost = max(10, int(discounted_cost * (1 - battery_bonus)))  # 최소 10은 소모
                    special_gauge = max(0, special_gauge - final_gauge_cost)  # 게이지가 음수가 되지 않도록 보정
                    # 🔹 게이지 감소 시 special_ready 상태 업데이트
                    if special_gauge < special_gauge_max:
                        special_ready = False
                    print(f"오른쪽 대쉬 실행! (연속 {rolling_consecutive_count}회, 할인된 소모: {final_gauge_cost}, 남은 횟수: {rolling_charges}, 게이지: {special_gauge})")
                    
                    # 🏆 대쉬 사용 기록

                    recent_dash_time = pygame.time.get_ticks()
                    mega_smashing_bonus_applied = False  # 고스트샷 보너스 리셋 (새로운 콤보 가능)
                    record_dash_usage(success=False)  # 일단 사용만 기록, 성공은 공 충돌 시 체크

            # 🆕 스피드부츠 효과 적용 (15% 증가)
            speed_multiplier = (1.0 + PERMANENT_SPEED_BOOST) if speedboots_obtained else 1.0
            # 스킬 효과 적용: 패들 속도 증가
            skill_speed_boost = skill.apply_paddle_speed_boost(0)
            effective_max_speed = (MAX_SPEED + skill_speed_boost) * speed_multiplier
            
            # 일반 이동 키 처리 (키보드 + 마우스 조작 통합)
            # 통제불능 상태에서는 일반 이동 불가 (더블대쉬 아이템 소지 시에도)
            if rolling_stun_timer <= 0:
                pass
                # 키보드 조작
                left_pressed = keys[pygame.K_LEFT]
                right_pressed = keys[pygame.K_RIGHT]
                
                # 마우스 조작 (비활성화됨)
                if False:  # input_manager.get_control_mode() == "마우스":
                    pass
                    # 마우스 위치로 직접 패들 이동
                    mouse_x, mouse_y = pygame.mouse.get_pos()
                    target_x = mouse_x - PADDLE_WIDTH // 2
                    
                    # 경계 처리
                    target_x = max(0, min(WIDTH - PADDLE_WIDTH, target_x))
                    
                    # 즉시 이동
                    PLAYER.x = target_x
                    current_speed = 0
                    
                    # 마우스 클릭 처리 (이미 이벤트 루프에서 처리됨)
                    mouse_state = input_manager.get_mouse_state()
                    if mouse_state['left_pressed']:
                        left_pressed = True
                    if mouse_state['right_pressed']:
                        pass
                        right_pressed = True
                else:
                    pass
                    # 키보드 조작 (감전 상태가 아닐 때만)
                    if not player_stunned:
                        if gravitybelt_obtained:
                            pass
                            # 무중력벨트: 완전히 기계적인 즉각 이동 (키 누르는 동안만)
                            # 시너지 효과일 때는 추가 속도 +3
                            speed_bonus = 3 if gravity_speed_synergy else 0
                            if left_pressed:
                                pass
                                current_speed = -(effective_max_speed + speed_bonus) * speed_factor
                            elif right_pressed:
                                pass
                                current_speed = (effective_max_speed + speed_bonus) * speed_factor
                            else:
                                pass
                                # 키를 떼면 즉시 정지
                                current_speed = 0
                        else:
                            pass
                            # 일반 이동: 가속도와 감속도 적용
                            if left_pressed:
                                if current_speed > -effective_max_speed * speed_factor:
                                    pass
                                    current_speed -= ACCELERATION
                            elif right_pressed:
                                if current_speed < effective_max_speed * speed_factor:
                                    pass
                                    current_speed += ACCELERATION
                            else:
                                pass
                                # 키를 떼었을 때 감속 적용 (무중력벨트가 없을 때만)
                                if not gravitybelt_obtained:
                                    if current_speed > 0:
                                        pass
                                        current_speed -= DECELERATION
                                    elif current_speed < 0:
                                        current_speed += DECELERATION
                                # 무중력벨트가 있으면 감속 로직 완전 무시 (속도 유지)
                    else:
                        pass
                        # 감전 상태일 때는 즉시 정지
                        current_speed = 0
        
    # 🆕 스피드기어 효과: 빠른 방향 전환 감속 (무중력벨트 없을 때만, 감전 상태가 아닐 때만)
    if not gravitybelt_obtained and not player_stunned:
        direction_change_boost = DIRECTION_CHANGE_BOOST if speedgear_obtained else 1.0  # 150% 더 빠른 방향 전환
        
        # 빠른 방향 전환 감속
        if keys[pygame.K_LEFT] and current_speed > 0:
            pass
            current_speed -= INSTANT_STOP_DECELERATION * direction_change_boost
        elif keys[pygame.K_RIGHT] and current_speed < 0:
            current_speed += INSTANT_STOP_DECELERATION * direction_change_boost
    # 무중력벨트가 있으면 모든 감속 로직 완전 무시 (속도 유지)
    # 감전 상태일 때도 모든 감속 로직 무시

    # 위치 적용 (감전 상태가 아닐 때만)
    if not player_stunned:
        PLAYER.x += current_speed
        # 패들 크기 변화를 고려한 X 좌표 제한
        actual_paddle_width = int(PADDLE_WIDTH * long_boost_scale * (synergy_paddle_width_boost if gravity_speed_synergy else 1.0))
        PLAYER.x = max(0, min(WIDTH - actual_paddle_width, PLAYER.x))
    
    # 무중력벨트 + 스피드기어 시너지 효과 적용
    if gravity_speed_synergy:
        pass
        PLAYER.width = int(PADDLE_WIDTH * synergy_paddle_width_boost * long_boost_scale)  # 시너지 + 거대화포션
    else:
        PLAYER.width = int(PADDLE_WIDTH * long_boost_scale)  # 거대화포션 효과 적용

    # (퍼펙트 타이밍 윈도우 감지 로직은 메인 루프로 이동)

    # 공 충돌 처리 - Aipill 활성화 시에는 모든 방향에서 감지, 비활성화 시에는 측면 충돌도 감지
    # 패들 끝부분 충돌을 위해 Y속도 조건 완화 - 공이 매우 빠르게 위로 가지 않는 한 모두 감지
    # 서브 대기 중에는 충돌 체크하지 않음
    global player_collision_handled, player_collision_cooldown, player_sound_cooldown, last_hit_by
    global mega_smashing_active, mega_smashing_meteor_trail, mega_smashing_ghosts, mega_smashing_ghost_scatter
    # Y속도와 관계없이 충돌 감지 (고스트샷 등 특수 상황 대응)
    if check_collision(BALL, PLAYER) and not is_waiting_for_serve:
        pass
        # 디버그: 충돌 위치 정보
        collision_x = BALL.centerx - PLAYER.centerx
        collision_side = "LEFT" if collision_x < 0 else "RIGHT"
        edge_distance = abs(collision_x) - (PADDLE_WIDTH / 2)
        print(f"🎯 handle_player 충돌! 위치: {collision_side}, 중심거리: {collision_x:.1f}, 가장자리거리: {edge_distance:.1f}, Y속도: {ball_vel[1]:.1f}")
        
        # 💥 고스트샷 종료 (플레이어 패들에 돌아왔을 때)
        # 고스트샷 첫 2초 동안은 패들 충돌을 무시하고 계속 진행
        if mega_smashing_active:
            elapsed_time = (pygame.time.get_ticks() - mega_smashing_start_time) / 1000
            if elapsed_time > 2.0:  # 2초 이후에만 고스트샷 종료
                mega_smashing_active = False
                mega_smashing_bonus_applied = False
                mega_smashing_meteor_trail.clear()
                mega_smashing_ghosts.clear()  # 귀신들 제거
                mega_smashing_ghost_scatter = False  # 흩어짐 상태 리셋
                
                # 🔧 고스트샷 종료 시 토큰 충전 타이머 초기화
                base_charges = 1
                holder_bonus = 1 if dashholder_obtained else 0
                amplification_bonus = academy.get_skill_bonus("dash_amplification")
                max_charges = int(base_charges + holder_bonus + amplification_bonus)
                
                print(f"[DEBUG] 고스트샷 종료 - 현재 토큰: {rolling_charges}/{max_charges}, 타이머: {rolling_charge_timer}")
                
                # 토큰이 부족한 경우 무조건 충전 타이머 설정
                if rolling_charges < max_charges:
                    pass
                    # 경량화 스킬 효과 적용
                    lightweight_bonus = academy.get_skill_bonus("dash_lightweight")
                    charge_time_reduction = lightweight_bonus  # 5% per level
                    base_charge_time = 90  # 1.5초
                    rolling_charge_timer = int(base_charge_time * (1 - charge_time_reduction))
                    print(f"💥 고스트샷 종료! 토큰 충전 시작 (타이머: {rolling_charge_timer}프레임 = {rolling_charge_timer/60:.1f}초)")
                    print(f"[DEBUG] 충전 타이머 강제 설정 완료: {rolling_charge_timer}")
                else:
                    pass
                    print(f"💥 고스트샷 종료! (토큰 이미 최대: {rolling_charges}/{max_charges})")
            else:
                print(f"🌟 고스트샷 궤적 진행 중 ({elapsed_time:.1f}/2.0초) - 패들 충돌 무시")
        
        # 충돌 처리 플래그 설정
        player_collision_handled = True
        last_hit_by = "player"  # 플레이어가 공을 쳤음을 기록
        
        # 🚀 가속화 스킬: 대쉬 상태에서 공과 충돌 시 순간 공속도 증가
        if rolling_active:
            acceleration_bonus = academy.get_skill_bonus("dash_acceleration")
            if acceleration_bonus > 0:
                pass
                # 🎯 현재 공속도 저장 (원래 속도 기록)
                original_ball_speed = [ball_vel[0], ball_vel[1]]
                global acceleration_original_speed, acceleration_active
                acceleration_original_speed = original_ball_speed[:]
                acceleration_active = True
                
                # 🚀 10% × 레벨만큼 순간 속도 증가
                speed_multiplier = 1 + acceleration_bonus  # acceleration_bonus가 이미 0.1 × level
                ball_vel[0] *= speed_multiplier
                ball_vel[1] *= speed_multiplier
                print(f"🚀 가속화 스킬 발동! 공 속도 {acceleration_bonus*100:.0f}% 증가 (배율: {speed_multiplier:.2f})")
                print(f"🔄 원래 속도 저장: {acceleration_original_speed}")
        
        drive_activated = calculate_bounce(PLAYER)
        print(f"🔍 DEBUG: calculate_bounce 반환값 - drive_activated: {drive_activated}")  # 🔍 디버그
        
        # 드라이브 발동 시 게이지 충전 차단 플래그 설정
        global drive_just_activated
        if drive_activated:
            drive_just_activated = True
            print("🎯 드라이브 발동! 게이지 충전 차단 플래그 설정")
        
        # 사운드 쿨다운이 없을 때만 사운드 재생
        if player_sound_cooldown <= 0:
            SOUND_PADDLE.play()
            player_sound_cooldown = 20  # 약 0.33초 쿨다운
            print(f"🔊 handle_player에서 사운드 재생 (쿨다운 설정: 20)")
        else:
            print(f"🔇 사운드 쿨다운 중 (남은 쿨다운: {player_sound_cooldown})")
        
        # 🏆 플레이어 히트 기록
        is_perfect = perfect_timing_active and perfect_direction is not None
        record_player_hit(is_perfect_timing=is_perfect, is_power_smash=drive_activated)
        
        # 🏆 대쉬 성공 체크 (최근 2초 내에 대쉬했다면 성공으로 기록)
        current_time = pygame.time.get_ticks()
        if recent_dash_time > 0 and (current_time - recent_dash_time) <= recent_dash_success_window:
            pass
            # 대쉬 후 성공적으로 공을 쳤으므로 성공으로 업데이트
            record_dash_usage(success=True)
            
            # 🏆 대쉬 활용 능력 상세 분석
            ball_distance = abs(BALL.centery - PLAYER.centery)
            ball_speed = math.hypot(ball_vel[0], ball_vel[1])
            
            # 생명 구조 상황 판정 (위험한 상황에서 대쉬로 공을 맞춘 경우)
            if ball_distance > 100 or ball_speed > 10:  # 멀거나 빠른 공
                record_dash_life_save()
                print("🏆 대쉬로 생명 구조!")
            
            # 대쉬 방어 구조 판정 (불가능한 영역에서 가드) - 신규
            paddle_width = PLAYER.width
            ball_x_distance = abs(BALL.centerx - PLAYER.centerx)
            if ball_x_distance > paddle_width * 1.5:  # 패들 범위 밖에서 가드
                record_dash_defensive_save()
                print("🏆 대쉬로 불가능한 영역 가드!")
            
            # 공격적 대쉬 성공 (승리 기여) 판정
            if ball_speed > 12:  # 강력한 반격
                record_dash_victory()
                print("🏆 대쉬로 강력한 반격!")
                
            # 대쉬 클러치 승리 판정 (상대가 못막고 바로 승리) - 신규  
            if ball_speed > 15 and ball_vel[1] < 0:  # 매우 빠른 공을 위로 반격
                record_dash_clutch_victory()
                print("🏆 대쉬 클러치 승리!")
                
            # 공속도 적응 점수 기록 - 신규
            record_speed_adaptation(ball_speed)
            
            recent_dash_time = 0  # 성공 기록 후 초기화
        
        # 🏆 가드 능력 기록 (공과의 거리, 공 속도)
        ball_distance = abs(BALL.centery - PLAYER.centery)
        ball_speed = math.hypot(ball_vel[0], ball_vel[1])
        is_close_call = ball_distance < 20  # 매우 가까운 거리
        record_guard_action(ball_distance, ball_speed, is_close_call)
        
        # 🏆 공속도 적응 점수 기록 (일반 가드에서도)
        record_speed_adaptation(ball_speed)
 
        # 🎯 타격 이펙트 생성 (공 속도에 따라 강도 조절)
        create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=True)

        global hit_animation_active, hit_animation_timer
        hit_animation_active = True
        hit_animation_timer = HIT_ANIMATION_DURATION
        
        # 무중력벨트 + 스피드기어 시너지 시 별가루 파티클 생성
        if gravity_speed_synergy:
            print(f"별가루 파티클 생성! 시너지 상태: {gravity_speed_synergy}")
            effects_manager.spawn_star_particles(PLAYER.centerx, PLAYER.centery, count=3)
        else:
            print(f"별가루 파티클 생성 안됨! 시너지 상태: {gravity_speed_synergy}")

        # 🔹 게이지 처리 - Aipill 활성화 시에는 게이지 감소만, 비활성화 시에는 게이지 증가
        print(f"공 충돌 시 aipill_active: {aipill_active}")  # 디버깅용
        
        # Aipill 활성화 시 게이지 감소만
        if aipill_active:
            print(f"Aipill 활성화 상태 - 공 충돌 감지! 현재 게이지: {special_gauge}")  # 디버깅용
            # Aipill 활성화 시 공이 맞을 때마다 게이지 90 감소만
            old_gauge = special_gauge
            special_gauge = max(0, special_gauge - 90)
            print(f"Aipill 활성화 중 - 게이지 감소: {old_gauge} → {special_gauge}")  # 디버깅용
            # 🔹 게이지 감소 시 special_ready 상태 업데이트
            if special_gauge < 350:  # 파워스매시 발동 조건
                special_ready = False
            # 게이지가 0이 되면 aipill 효과 종료
            if special_gauge <= 0:
                aipill_active = False
                special_gauge = 0
                print("Aipill 효과 종료")  # 디버깅용
            # Aipill 활성화 시에는 절대 게이지 증가 금지
            print("Aipill 활성화로 인한 게이지 감소 완료")  # 디버깅용
            return
        # 🎯 게이지 충전을 handle_player에서만 처리 (handle_ball 충돌 시에는 충전하지 않음)
        # 대쉬 중이거나 대쉬 직후, 드라이브 발동 시에는 게이지 충전 차단
        if not aipill_active and not special_active and not rolling_active and player_collision_cooldown <= 0 and not drive_activated:
            pass
            # 스킬 효과 적용: 게이지 충전 증가
            base_gauge_gain = 80  # 사용자 요청에 따라 80으로 설정
            skill_gauge_boost = skill.apply_gauge_boost(0)
            total_gauge_gain = base_gauge_gain + skill_gauge_boost
            
            print(f"🔍 DEBUG: ✅ handle_player에서 게이지 충전 ({total_gauge_gain})")
            special_gauge += total_gauge_gain
            # 🔧 동적 최대치 제한 적용
            current_max = get_max_gauge()
            if special_gauge > current_max:
                special_gauge = current_max
            # 🔧 필살기 준비 상태 업데이트 (400 이상일 때)
            if special_gauge >= 350:  # 파워스매시 발동 조건
                special_ready = True

            if current_stage == 2:
                boss_special_gauge = min(500, boss_special_gauge + 70)
                if boss_special_gauge >= 500:
                    boss_special_ready = True
            # 충돌 쿨다운 설정하여 중복 충전 방지
            player_collision_cooldown = 15
        elif rolling_active:
            pass
            print(f"🔍 DEBUG: ❌ 대쉬 중이므로 handle_player 게이지 충전 차단됨!")
        elif player_collision_cooldown > 0:
            pass
            print(f"🔍 DEBUG: ❌ 충돌 쿨다운 중이므로 게이지 충전 차단됨! (남은 쿨다운: {player_collision_cooldown})")
        elif drive_activated:
            pass
            print(f"🔍 DEBUG: ❌ 드라이브 발동으로 게이지 충전 차단됨!")
        else:
            print(f"🔍 DEBUG: ❌ handle_player에서 게이지 충전 차단됨")

        # 🔹 파워스매싱은 이제 퍼펙트 타이밍 윈도우에서 처리됨 (드라이브와 동일한 타이밍)
        # handle_player에서는 제거하고 메인 루프의 퍼펙트 타이밍 윈도우에서 처리

# 채찍질 특수기술 관련 변수
whip_active = False
whip_duration = 260  # 260프레임 (약 4.3초)으로 증가
whip_timer = 0
whip_hit_by_player = False  # 플레이어가 공 맞췄는지 추적
whip_original_ball_speed = [0, 0]  # 상모돌리기 발동 전 공 속도 저장

# 풍선 스킬 관련 변수
balloon_active = False
balloon_timer = 0
balloon_duration = 120  # 2초
balloons = []  # 풍선 리스트 [{"x": int, "y": int, "radius": int, "color": tuple}]
balloon_used_this_round = False  # 이번 라운드에 풍선 스킬 사용 여부

medal_score = 0
current_stage = 1

# 🏗️ 전역 변수를 GameState와 동기화
# game_state.player_score = 0  # 모듈에서는 실행하지 않음
# game_state.ai_score = 0
# game_state.round_wins = round_wins
# game_state.round_losses = round_losses
# game_state.current_stage = current_stage
# game_state.medal_score = medal_score
# game_state.special_gauge = special_gauge
# game_state.special_ready = special_ready
# game_state.deuce_mode = deuce_mode
# game_state.deuce_wins = deuce_wins
# game_state.deuce_losses = deuce_losses

# 스테이지 1 벽 충돌 테두리 깜빡임 효과
border_flash_active = False  # 테두리 깜빡임 활성화 상태
border_flash_timer = 0  # 깜빡임 타이머
border_flash_duration = 20  # 깜빡임 지속 시간 (프레임) - 증가
border_flash_color = (255, 255, 0)  # 깜빡임 색상 (노란색) - 더 눈에 띄게
border_flash_thickness = 10  # 테두리 두께 - 증가

# 스테이지 2 정글 테두리 효과
stage2_border_active = False  # 스테이지 2 테두리 활성화 상태
stage2_border_timer = 0  # 테두리 애니메이션 타이머
stage2_border_flash_timer = 0  # 벽 충돌 시 깜빡임 타이머
stage2_border_flash_duration = 25  # 깜빡임 지속 시간
stage2_vines = []  # 덩굴 위치 리스트
stage2_leaves = []  # 나뭇잎 위치 리스트

# 체력형 보스 시스템 (스테이지 6, 11, 16, 21)
boss_health_stages = [6, 11, 16, 21]  # 체력형 보스가 등장하는 스테이지
# STAGE_BOSS_HEALTH가 정의되지 않아서 기본값 사용
STAGE_BOSS_HEALTH = {
    1: 15,
    2: 20, 
    3: 25,
    4: 30,
    5: 35,
    6: 40
}
current_stage = 1  # 기본값
boss_max_health = STAGE_BOSS_HEALTH.get(current_stage, 15)  # 스테이지별 보스 체력
boss_current_health = 15  # 보스 현재 체력
boss_health_bar_width = 200  # 체력바 너비
boss_health_bar_height = 8  # 체력바 높이 (더 얇게)
boss_displayed_health = 15  # 스무스하게 표시되는 체력 (감소 애니메이션용)
boss_damage_preview_health = 15  # 데미지 프리뷰용 체력
boss_damage_values = {
    "basic": 1,     # 기본 공격 데미지
    "drive": 2,     # 드라이브 데미지
    "power": 3      # 파워 스매싱 데미지
}
boss_fire_hit_count = 0  # 화염탄 맞은 횟수 (3회마다 체력 1 감소)
boss_fire_hit_timer = 0  # 화염 타격 쿨다운 타이머 (중복 방지)

stage_medal_rewards = {
    1: 10,
    2: 20,
    3: 40,
    4: 80,
    5: 100,
    6: 130,
    7: 180,
    8: 200,
    9: 250,
    10: 300,
    11: 350
}

session_medal_earned = 0  # main 함수 외부에 선언

final_wave_direction = [0, 0]  # 공의 마지막 이동 방향 (X, Y)
