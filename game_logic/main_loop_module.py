"""
main 함수 - bosspong.py에서 추출
1,066줄의 거대한 게임 루프를 별도 모듈로 분리
"""

import pygame
import math
import random
import sys
import effects_manager
import academy
from .stage2_effects import update_stage2_leaves, draw_stage2_leaves, stage2_leaves


def refresh_perfect_timing_indicator():
    global perfect_timing_indicator_active, perfect_timing_active
    counter_window = globals().get("short_shot_counter_window", 0)
    perfect_timing_indicator_active = perfect_timing_active or counter_window > 0


SHORT_SHOT_DASH_SPEED_MULTIPLIER = 1.30
SHORT_SHOT_POWER_SPEED_MULTIPLIER = 1.50

def main(stage_num, new_boss_mode=False):
    # 🏆 실시간 평가 시스템으로 변경됨
    
    # 관리자 단축키 변수 초기화
    global nine_just_pressed, last_nine_state
    nine_just_pressed = False
    last_nine_state = False
    
    # 게임 상태 & 스테이지 설정
    global current_stage, round_wins, round_losses, new_boss_mode_active
    global FIELD_GREEN, CURRENT_BG, BOSS_COLOR, SCREEN
    
    # 보스 AI 설정
    global BOSS_ACCELERATION, BOSS_DECELERATION, BOSS_MAX_SPEED, BOSS_INSTANT_STOP_DECELERATION
    global BOSS_ACCELERATION_DEFAULT, BOSS_DECELERATION_DEFAULT, BOSS_MAX_SPEED_DEFAULT, BOSS_INSTANT_STOP_DECELERATION_DEFAULT
    
    # 게임 진행 & 타이밍
    global is_waiting_for_serve, last_item_spawn_time, next_item_spawn_delay
    global boss_fail_timer, session_medal_earned, medal_score
    global perfect_timing_window
    
    # 아이템 시스템
    global selected_item_index, last_item_use_time
    global master_obtained, cooltime_obtained
    
    # 보스 스킬들
    global whip_active, whip_timer, whip_sound
    
    # 충돌 애니메이션
    global hit_animation_active, hit_animation_timer
    
    # 일시정지 시스템
    global game_paused
    
    # 파워스매싱 정지 시간 관리
    global power_smashing_freeze_start_time, power_smashing_freeze_active, power_smashing_freeze_duration
    global power_smashing_parabola_active, power_smashing_start_time
    
    # 대쉬 및 아이템 관련 전역 변수
    global dashholder_obtained, rolling_charge_timer, rolling_charges
    
    # 스테이지 1 벽 충돌 테두리 깜빡임 효과
    global border_flash_active, border_flash_timer, border_flash_duration, border_flash_color, border_flash_thickness
    
    # 스테이지 2 정글 테두리 효과
    global stage2_border_active, stage2_border_timer, stage2_border_flash_timer
    global stage2_border_flash_duration, stage2_vines, stage2_leaves
    
    boss_fail_timer = 0  # 보스 실수 타이머 초기화

    # 퍼펙트 타이밍 윈도우 최소 보장 (구버전 세이브 호환)
    if perfect_timing_window < 12:
        perfect_timing_window = 12

    current_stage = stage_num
    round_wins = 0
    round_losses = 0
    
    # 💪 체력형 보스 스테이지에서는 패배 조건을 5점으로 설정
    global win_goal, boss_current_health, boss_displayed_health, boss_damage_preview_health
    if current_stage in boss_health_stages:
        win_goal = 5  # 체력형 보스는 5점에서 패배
        # 체력형 보스 체력 초기화
        boss_current_health = boss_max_health  # 15
        boss_displayed_health = boss_max_health  # 15
        boss_damage_preview_health = boss_max_health  # 15
    else:
        win_goal = 3  # 일반 스테이지는 3점에서 패배
    
    # 🧠 딥러닝 AI 시스템 초기화
    initialize_enhanced_ai()
    
    # 🏆 플레이어 실력 분석 시스템 초기화
    initialize_player_analyzer()
    
    # 새로운 보스 배틀 모드 설정
    new_boss_mode_active = new_boss_mode
    
    if new_boss_mode_active:
        pass
        # 새로운 보스 선택 화면 표시
        show_new_boss_selection_screen()
        top_names = ["라이트닝 마스터", "아이스 퀸"]
        bottom_names = ["파이어 나이트", "윈드 스피릿"]
        top_name = top_names[selected_top_boss - 1]
        bottom_name = bottom_names[selected_bottom_boss - 1]
        print(f"🆕 NEW BOSS BATTLE: {top_name} vs {bottom_name}")
    
    # 듀스 시스템 초기화
    reset_deuce_system()

    # 🏆 통합 보스 설정: 스테이지별 + 리그별 완전 연계
    config = get_final_boss_config(stage_num, ai_mode)
    
    BOSS_ACCELERATION = config["accel"]
    BOSS_DECELERATION = config["decel"]
    BOSS_MAX_SPEED = config["max_speed"]
    BOSS_INSTANT_STOP_DECELERATION = config["instant_stop"]

    BOSS_ACCELERATION_DEFAULT = config["accel"]
    BOSS_DECELERATION_DEFAULT = config["decel"]
    BOSS_MAX_SPEED_DEFAULT = config["max_speed"]
    BOSS_INSTANT_STOP_DECELERATION_DEFAULT = config["instant_stop"]

    # 스테이지별 배경, 보스 컬러
    if stage_num == 1:
        CURRENT_BG = STAGE1_BG
        BOSS_COLOR = WHITE
    elif stage_num == 2:
        CURRENT_BG = STAGE2_BG
        BOSS_COLOR = (100, 255, 100)
    elif stage_num == 3:
        CURRENT_BG = STAGE3_BG
        BOSS_COLOR = (255, 255, 0)
    elif stage_num == 4:
        CURRENT_BG = STAGE4_BG
        BOSS_COLOR = (255, 255, 255)
    elif stage_num == 5:  # ✅ Stage 5 추가
        CURRENT_BG = STAGE5_BG
        BOSS_COLOR = (255, 80, 0)   # 홍련색
    elif stage_num == 6:  # ✅ Stage 6 추가 (항공모함)
        CURRENT_BG = STAGE6_BG
        BOSS_COLOR = (150, 200, 255)  # 금속/은색

    reset_round()

    # 아이템 첫 스폰 시간 설정 (첫스폰))
    last_item_spawn_time = pygame.time.get_ticks()
    next_item_spawn_delay = random.randint(10000, 20000)  # 첫 스폰 빠르게
    try:
        next_item_spawn_delay = int(next_item_spawn_delay * academy.get_item_spawn_delay_multiplier())
    except Exception:
        pass
    
    # selected_item_index 초기화 (active_item_slot이 비어있으면 0으로 설정)
    if not active_item_slot:
        pass
        selected_item_index = 0
    else:
        selected_item_index = min(selected_item_index, len(active_item_slot) - 1)

    running = True
    while running:
        # 프로파일러 프레임 시작
        if profiler:
            profiler.begin_frame()
        
        clock.tick(FPS)
        
        # 프로파일러 입력 처리 섹션
        if profiler:
            profiler.start_section("Input")
        
        # 키 입력 처리
        keys = pygame.key.get_pressed()
        
        # 7번키로 프로파일러 표시 토글
        if keys[pygame.K_7] and not getattr(main, 'key7_pressed', False):
            if profiler:
                profiler.toggle_visibility()
                print(f"프로파일러 표시: {'ON' if profiler.visible else 'OFF'}")
        main.key7_pressed = keys[pygame.K_7]
        
        # 🎯 퍼펙트 타이밍 시스템: 스페이스바 + 방향키 프레임 단위 입력 감지
        global space_just_pressed, last_space_state, perfect_timing_active, perfect_timing_frame_count, perfect_direction
        global perfect_timing_indicator_active
        global left_just_pressed, last_left_state, right_just_pressed, last_right_state
        global left_press_frame, right_press_frame, space_press_frame, frame_counter
        global perfect_timing_cooldown, perfect_timing_cooldown_frames, perfect_timing_input_used
        global drive_global_cooldown, drive_global_cooldown_frames, last_space_press_time
        global special_ready, special_active, special_gauge  # 🚀 파워스매싱 관련 변수들
        global power_smashing_direction, power_smashing_original_speed, ball_vel  # 🚀 파워스매싱 관련 변수
        global short_shot_counter_window
        
        # 프레임 카운터 증가
        frame_counter += 1
        
        # 🔧 대쉬 매니저 업데이트 (매 프레임)
        if dash is not None:
            pass
            # 아이템 보너스 동기화 (매 프레임)
            dash.update_bonuses(dashholder_obtained, dashgear_obtained, spikeboots_obtained)
            dash.update()
            # 레거시 시스템과 동기화
            dash_tokens, dash_timer, dash_consecutive, dash_max = dash.get_legacy_sync_data()
            if rolling_charges != dash_tokens or rolling_charge_timer != dash_timer:
                rolling_charges = dash_tokens
                rolling_charge_timer = dash_timer
                rolling_consecutive_count = dash_consecutive
        
        # 관리자용 9키 단축키 (3-0 승리)
        global boss_score, player_score
        current_nine_state = keys[pygame.K_9]
        nine_just_pressed = current_nine_state and not last_nine_state
        if nine_just_pressed:
            print("🎮 관리자 단축키: 즉시 3-0 승리!")
            boss_score = 0
            player_score = 3
            # 승리 화면으로 이동
            show_result(True)
            return
        last_nine_state = current_nine_state
        
        # 스페이스바 입력 감지 (감전 상태일 때는 무시)
        if not player_stunned:
            current_space_state = keys[pygame.K_SPACE]
            space_just_pressed = current_space_state and not last_space_state
            if space_just_pressed:
                space_press_frame = frame_counter
            last_space_state = current_space_state
        else:
            space_just_pressed = False
            current_space_state = False
            last_space_state = False
        
        # 🆕 방향키 입력 감지 (감전 상태일 때는 무시)
        if not player_stunned:
            current_left_state = keys[pygame.K_LEFT]
            left_just_pressed = current_left_state and not last_left_state
            if left_just_pressed:
                left_press_frame = frame_counter
            last_left_state = current_left_state
            
            current_right_state = keys[pygame.K_RIGHT]
            right_just_pressed = current_right_state and not last_right_state
            if right_just_pressed:
                right_press_frame = frame_counter
            last_right_state = current_right_state
        else:
            pass
            # 감전 상태일 때는 모든 입력을 False로
            left_just_pressed = False
            right_just_pressed = False
            last_left_state = False
            last_right_state = False
        
        # 🎯 퍼펙트 타이밍 쿨다운 관리 (연타 방지)
        if perfect_timing_cooldown > 0:
            perfect_timing_cooldown -= 1
        
        # 🆕 드라이브 전역 쿨다운 관리 (강력한 연타 방지)
        if drive_global_cooldown > 0:
            drive_global_cooldown -= 1
        
        # 🆕 스페이스바 연타 감지 (너무 빠른 입력 차단)
        current_time = pygame.time.get_ticks()
        min_space_interval = 200  # 최소 200ms (0.2초) 간격
        if space_just_pressed:
            if current_time - last_space_press_time < min_space_interval:
                space_just_pressed = False  # 너무 빠른 입력은 무시
                print(f"🚫 스페이스바 입력이 너무 빠릅니다! (간격: {current_time - last_space_press_time}ms)")
            else:
                last_space_press_time = current_time
        
        # 🎯 퍼펙트 타이밍 윈도우 활성화 체크 (매 프레임 체크)
        # 올바른 거리 계산: 패들까지의 실제 거리
        ball_to_paddle_distance = PLAYER.top - BALL.centery  # 양수 = 공이 패들 위쪽에 있음
        
        # 디버깅: 공과 패들 사이의 거리와 공 속도 출력 (가끔씩만)
        if pygame.time.get_ticks() % 30 == 0:  # 0.5초마다
            print(f"🎯 Debug: distance={ball_to_paddle_distance:.1f}, ball_vel_y={ball_vel[1]:.1f}, active={perfect_timing_active}, ball_y={BALL.centery:.1f}, paddle_top={PLAYER.top:.1f}")
        
        # 🚀 개선된 퍼펙트 타이밍 윈도우: 실제 충돌 가능 범위와 일치시키기
        # 공이 패들과 실제로 충돌할 수 있는 범위 내에서만 활성화
        # 드라이브 선입력 방지: 거리를 더 짧게 설정
        ball_will_hit_paddle = (
        ball_to_paddle_distance <= 24 and  # Y범위 약간 확대 (30 → 24)
        ball_to_paddle_distance > -12 and  # 약간의 여유 확대 (0 → -12)
            ball_vel[1] > 0 and
            # 🎯 추가 조건: 공의 X좌표가 패들 범위 내 또는 근처에 있는지 확인
            abs(BALL.centerx - PLAYER.centerx) <= (PADDLE_WIDTH / 2 + BALL_RADIUS + 15)  # 패들 범위 + 약간의 여유 (20 → 15)
        )
        
        if ball_will_hit_paddle:
            if not perfect_timing_active:
                perfect_timing_active = True
                perfect_timing_frame_count = 0
                perfect_timing_input_used = False  # 🆕 새로운 윈도우 시작 시 플래그 초기화
                refresh_perfect_timing_indicator()
                x_distance = abs(BALL.centerx - PLAYER.centerx)
                print(f"🎯 퍼펙트 타이밍 윈도우 활성화! (Y거리: {ball_to_paddle_distance:.1f}, X거리: {x_distance:.1f})")
        
        # 퍼펙트 타이밍 윈도우 관리
        if perfect_timing_active:
            perfect_timing_frame_count += 1
            
            # 🆕 퍼펙트 타이밍 입력 체크 (방향키 + 스페이스 동시 입력 필요)
            # 🚀 드라이브와 파워스매싱을 동일한 타이밍 윈도우에서 처리
            if (perfect_timing_frame_count <= perfect_timing_window and 
                perfect_timing_cooldown == 0 and not perfect_timing_input_used and 
                drive_global_cooldown == 0):
                
                # 🆕 개선된 동시 입력 감지 (2프레임 허용 범위) - 선입력 방지
                max_frame_gap = 3  # 최대 3프레임(0.05초) 차이까지 동시 입력으로 인정
                max_input_age = 12  # 최대 12프레임(약 0.2초) 전까지의 입력만 유효
                
                                    # 🚀 파워스매싱/고스트샷 발동: 게이지가 준비되었고 스페이스를 홀드하고 있다면
                if special_gauge >= 350 and keys[pygame.K_SPACE]:  # 파워스매시 발동 조건: 350 이상
                    pass
                    # 먼저 고스트샷 조건 체크
                    global mega_smashing_active, mega_smashing_bonus_applied, recent_dash_time, mega_smashing_start_time
                    global power_smashing_parabola_active  # global 선언을 먼저
                    current_time = pygame.time.get_ticks()
                    
                    # 고스트샷 조건:
                    # 1. 대쉬 후 1초 이내
                    # 2. 스페이스바를 대쉬 후에 눌렀을 것 (대쉬 전부터 홀드한 것 제외)
                    mega_smashing_window = 1000  # 1초
                    
                    if (recent_dash_time > 0 and 
                        (current_time - recent_dash_time) <= mega_smashing_window and
                        last_space_press_time > recent_dash_time):  # 스페이스바가 대쉬 후에 눌렸을 때만
                        
                        mega_smashing_active = True
                        mega_smashing_start_time = pygame.time.get_ticks()  # 고스트샷 시작 시간 기록
                        mega_smashing_boss_defense_count = 0  # 보스 방어 카운터 초기화
                        power_smashing_parabola_active = False  # 고스트샷은 파워스매싱 포물선 사용 안함
                        
                        # 🚀 고스트샷 발동 시 원래 위치 저장 후 300픽셀 위로 순간이동
                        original_y = BALL.centery  # 원래 위치 저장
                        BALL.centery = max(BALL_RADIUS, BALL.centery - 300)  # 화면 밖으로 나가지 않도록 제한
                        
                        # 원래 위치 저장 (handle_mega_smashing_trajectory에서 사용)
                        handle_mega_smashing_trajectory.original_y = original_y
                        handle_mega_smashing_trajectory.return_to_original = True
                        
                        print(f"🚀 고스트샷 발동! 원래 Y={original_y} → 상승 Y={BALL.centery}")
                        
                        # 🔧 고스트샷 발동 시 토큰 충전 타이머 확인 및 설정
                        base_charges = 1
                        holder_bonus = 1 if dashholder_obtained else 0
                        amplification_bonus = academy.get_skill_bonus("dash_amplification")
                        max_charges = int(base_charges + holder_bonus + amplification_bonus)
                        
                        # 토큰이 소진된 상태면 무조건 충전 타이머 설정
                        print(f"[DEBUG] 고스트샷 발동 전 상태 - 토큰: {rolling_charges}/{max_charges}, 타이머: {rolling_charge_timer}")
                        if rolling_charges < max_charges:
                            lightweight_bonus = academy.get_skill_bonus("dash_lightweight")
                            charge_time_reduction = lightweight_bonus
                            base_charge_time = 90  # 1.5초
                            rolling_charge_timer = int(base_charge_time * (1 - charge_time_reduction))
                            print(f"💥 고스트샷 발동 시 토큰 충전 시작 (타이머: {rolling_charge_timer})")
                        else:
                            print(f"[DEBUG] 고스트샷 발동 - 토큰 이미 최대: {rolling_charges}/{max_charges}")
                        
                        # 고스트샷 게이지 보너스
                        if not mega_smashing_bonus_applied:
                            special_gauge = min(special_gauge + 50, 1000)
                            mega_smashing_bonus_applied = True
                        print(f"💥 고스트샷 발동! (대쉬→스페이스 콤보) +50 게이지 보너스")
                        print(f"   대쉬 시간: {recent_dash_time}, 스페이스 시간: {last_space_press_time}, 간격: {last_space_press_time - recent_dash_time}ms")
                        show_fade_text("고스트샷!")
                    # else 제거 - 고스트샷이 이미 활성화되어 있을 수 있으므로
                    
                    # 파워스매싱 방향 설정 (고스트샷이든 일반 파워스매싱이든 공통)
                    global power_smashing_direction, power_smashing_start_time, power_smashing_arc_strength
                    global power_smashing_freeze_start_time, power_smashing_freeze_active
                    
                    if keys[pygame.K_LEFT]:
                        power_smashing_direction = -1  # 왼쪽
                        print(f"🚀 {'메가' if mega_smashing_active else '파워'}스매싱! (←+스페이스)")
                        # 뚜렷한 곡선 효과 적용
                        base_strength = -2.8  # 기본 강도 증가
                        random_variation = random.uniform(-0.4, 0.4)  # 랜덤 변화량
                        power_smashing_arc_strength = base_strength + random_variation  # 왼쪽 방향으로 뚜렷한 곡선
                    elif keys[pygame.K_RIGHT]:
                        power_smashing_direction = 1   # 오른쪽
                        print(f"🚀 {'메가' if mega_smashing_active else '파워'}스매싱! (→+스페이스)")
                        # 뚜렷한 곡선 효과 적용
                        base_strength = 2.8  # 기본 강도 증가
                        random_variation = random.uniform(-0.4, 0.4)  # 랜덤 변화량
                        power_smashing_arc_strength = base_strength + random_variation  # 오른쪽 방향으로 뚜렷한 곡선
                    else:
                        power_smashing_direction = 0   # 직선
                        print(f"🚀 {'메가' if mega_smashing_active else '파워'}스매싱! (스페이스)")
                        # 직선이므로 포물선 효과 없음
                        power_smashing_arc_strength = 0.0
                    
                    # 고스트샷이 아닐 때만 special_active 설정 (고스트샷은 게이지 충전 가능)
                    if not mega_smashing_active:
                        special_active = True
                    special_ready = False
                    special_gauge = max(0, special_gauge - 350)
                    
                    # 고스트샷 보너스: +50 게이지
                    if mega_smashing_active:
                        special_gauge += 50
                        current_max = get_max_gauge()
                        if special_gauge > current_max:
                            special_gauge = current_max  # 파워스매시 게이지 소모: 350
                    
                    # 🎵 파워스매싱 발동 효과음 재생
                    SOUND_POWER_SMASH.play()
                    print("🎵 파워스매싱 발동 효과음 재생!")
                    
                    # 🏆 파워스매싱 성공 기록
                    record_skill_usage(success=True)
                    
                    # 🔧 고스트샷일 때는 파워스매싱 정지 시간 사용하지 않음
                    if not mega_smashing_active:
                        pass
                        # 파워스매싱 정지 시간 시작
                        power_smashing_freeze_start_time = pygame.time.get_ticks()
                        power_smashing_freeze_active = True
                        print(f"🔧 파워스매싱 정지 시간 시작! (1초)")
                    else:
                        pass
                        # 고스트샷은 정지 없이 바로 시작
                        power_smashing_freeze_active = False
                        power_smashing_parabola_active = False  # 고스트샷은 파워스매싱 포물선 사용 안함
                        power_smashing_start_time = pygame.time.get_ticks()  # 고스트샷 시작 시간 설정
                        print(f"🐉 고스트샷은 정지 없이 바로 시작!")
                    
                    # 🔧 파워스매싱 발동 시 강제 충돌 처리 (범위 차이 문제 해결)
                    if not BALL.colliderect(PLAYER) and ball_to_paddle_distance <= 30 and ball_vel[1] > 0:
                        pass
                        # 공을 패들 근처로 강제 이동시켜 충돌 발생시키기
                        BALL.centery = PLAYER.top - BALL_RADIUS
                        print(f"🔧 파워스매싱 강제 충돌 처리! 공 위치 조정: Y={BALL.centery}")
                        
                        # 강제 충돌 처리 실행
                        drive_activated = calculate_bounce(PLAYER)
                        # 기존 SOUND_PADDLE.play() 제거 - 파워스매싱 전용 효과음 사용
                        
                        # 메가드라이브일 때는 공을 위로 보내도록 y 속도를 음수로 설정
                        if mega_smashing_active:
                            ball_vel[1] = -abs(ball_vel[1])  # 공을 위로(보스 방향으로) 보냄
                            print(f"💥 메가드라이브 - 공 방향 보스쪽으로 변경: Y속도={ball_vel[1]}")
                        
                        # 타격 이펙트 생성
                        create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=True)
                        
                        # 충돌 애니메이션
                        hit_animation_active = True
                        hit_animation_timer = HIT_ANIMATION_DURATION
                    
                    perfect_timing_cooldown = perfect_timing_cooldown_frames  # 쿨다운 시작
                    drive_global_cooldown = drive_global_cooldown_frames      # 🆕 전역 쿨다운 시작
                    perfect_timing_input_used = True  # 🆕 이 윈도우에서 입력 사용됨 표시
                    
                    # 🚀 파워스매싱 - 속도 대폭 증가
                    current_speed = math.hypot(ball_vel[0], ball_vel[1])
                    power_smashing_original_speed = current_speed  # 🎯 원래 속도 저장 (보스 반격 시 감속용)
                    
                    # 고스트샷은 초기에 느리게 시작 (용의 움직임을 위해)
                    if mega_smashing_active:
                        pass
                        # 고스트샷은 천천히 시작
                        new_speed = BALL_BASE_SPEED * 0.5  # 기본 속도의 50%로 시작
                        mega_smashing_original_speed = current_speed  # 원래 속도 저장
                        actual_boost = new_speed - current_speed  # 고스트샷도 actual_boost 계산
                    else:
                        pass
                        # 파워스매싱은 기존대로 빠르게
                        min_boost = BALL_BASE_SPEED * 1.2  # 최소 증가량
                        actual_boost = max(current_speed * 0.8, min_boost)  # 80% 증가 또는 최소값
                        new_speed = current_speed + actual_boost
                    
                    # 속도 비율 적용으로 방향 유지하면서 속도 증가
                    if current_speed > 0:
                        speed_ratio = new_speed / current_speed
                        ball_vel[0] *= speed_ratio
                        ball_vel[1] *= speed_ratio
                    else:
                        pass
                        # 정지 상태에서는 기본 속도로 설정
                        ball_vel[0] = BALL_BASE_SPEED * 0.8
                        ball_vel[1] = BALL_BASE_SPEED * 0.8
                    
                    # 파워스매싱 방향에 따른 X축 속도 조정 (고스트샷도 동일하게 처리)
                    if power_smashing_direction == -1:  # 왼쪽 파워스매싱
                        pass
                        ball_vel[0] = -abs(ball_vel[0]) * 1.3  # 왼쪽으로 강하게
                    elif power_smashing_direction == 1:  # 오른쪽 파워스매싱
                        pass
                        ball_vel[0] = abs(ball_vel[0]) * 1.3  # 오른쪽으로 강하게
                    else:  # 직선 파워스매싱
                        ball_vel[0] *= 1.1  # X축 약간 부스트
                        ball_vel[1] *= 1.1  # Y축 추가 10% 부스트
                    
                    final_speed = math.hypot(ball_vel[0], ball_vel[1])
                    print(f"🚀 파워스매싱! 이전속도: {current_speed:.2f}, 증가량: {actual_boost:.2f}, 최종속도: {final_speed:.2f}")
                    if short_shot_counter_window > 0:
                        prev_speed = math.hypot(ball_vel[0], ball_vel[1])
                        power_multiplier = SHORT_SHOT_POWER_SPEED_MULTIPLIER
                        ball_vel[0] *= power_multiplier
                        ball_vel[1] *= power_multiplier
                        boosted_speed = math.hypot(ball_vel[0], ball_vel[1])
                        short_shot_counter_window = 0
                        refresh_perfect_timing_indicator()
                        power_gain = boosted_speed - prev_speed
                        print(f"⚡ 쇼트 카운터 파워스매싱 보너스! 속도 {prev_speed:.2f} → {boosted_speed:.2f} (+{power_gain:.2f})")
                        final_speed = boosted_speed
                        effects_manager.spawn_short_shot_flash(BALL.centerx, BALL.centery)
                        effects_manager.spawn_short_shot_flash(PLAYER.centerx, PLAYER.centery)
                    # 고스트샷이 아닐 때만 POWER SMASHING 표시
                    if not mega_smashing_active:
                        show_fade_text("POWER SMASHING")
                    
                    # 💫 이펙트 초기화 - 고스트샷일 때는 아무 이펙트도 생성하지 않음
                    if not mega_smashing_active:
                        pass
                        # 파워스매싱일 때만 이펙트 생성
                        global power_smashing_trails, power_smashing_particles
                        power_smashing_trails.clear()
                        power_smashing_particles.clear()
                        
                        # 파워스매싱 파티클 생성
                        for i in range(20):
                            angle = (i / 20) * 2 * math.pi
                            speed = random.uniform(4, 6)
                            power_smashing_particles.append({
                                'x': BALL.centerx,
                                'y': BALL.centery,
                                'vx': math.cos(angle) * speed,
                                'vy': math.sin(angle) * speed,
                                'life': 40,
                                'color': (150, 200, 255),
                                'type': 'energy'
                            })
                        
                        # 전기 스파크
                        for _ in range(15):
                            angle = random.uniform(0, 2 * math.pi)
                            speed = random.uniform(5, 10)
                            power_smashing_particles.append({
                                'x': BALL.centerx,
                                'y': BALL.centery,
                                'vx': math.cos(angle) * speed,
                                'vy': math.sin(angle) * speed,
                                'life': 30,
                                'color': (200, 230, 255),
                                'type': 'spark'
                            })
                    
                    # 홀드 방식이므로 프레임 초기화 불필요
                
                # 왼쪽 방향키 + 스페이스키 동시 입력 (드라이브 - 파워스매싱이 준비되지 않은 경우)
                # 추가 조건: 키 입력이 최근(12프레임 이내)에 이루어졌어야 함
                elif (
                    left_press_frame >= 0
                    and space_press_frame >= 0
                    and abs(left_press_frame - space_press_frame) <= max_frame_gap
                    and (frame_counter - left_press_frame) <= max_input_age  # 왼쪽 키가 최근에 눌렸는지
                    and (frame_counter - space_press_frame) <= max_input_age  # 스페이스 키가 최근에 눌렸는지
                ):
                    perfect_direction = -1  # 왼쪽 드라이브
                    perfect_timing_cooldown = perfect_timing_cooldown_frames  # 쿨다운 시작
                    drive_global_cooldown = drive_global_cooldown_frames      # 🆕 전역 쿨다운 시작
                    perfect_timing_input_used = True  # 🆕 이 윈도우에서 입력 사용됨 표시
                    frame_gap = abs(left_press_frame - space_press_frame)
                    input_age = max(frame_counter - left_press_frame, frame_counter - space_press_frame)
                    print(f"🎯 왼쪽 드라이브! (←+스페이스 동시 입력 성공, 프레임 차이: {frame_gap}, 입력 나이: {input_age})")
                    # 사용된 프레임 초기화
                    left_press_frame = -1
                    space_press_frame = -1
                
                # 오른쪽 방향키 + 스페이스키 동시 입력 (드라이브 - 파워스매싱이 준비되지 않은 경우)
                elif (
                    right_press_frame >= 0
                    and space_press_frame >= 0
                    and abs(right_press_frame - space_press_frame) <= max_frame_gap
                    and (frame_counter - right_press_frame) <= max_input_age  # 오른쪽 키가 최근에 눌렸는지
                    and (frame_counter - space_press_frame) <= max_input_age  # 스페이스 키가 최근에 눌렸는지
                ):
                    perfect_direction = 1   # 오른쪽 드라이브
                    perfect_timing_cooldown = perfect_timing_cooldown_frames  # 쿨다운 시작
                    drive_global_cooldown = drive_global_cooldown_frames      # 🆕 전역 쿨다운 시작
                    perfect_timing_input_used = True  # 🆕 이 윈도우에서 입력 사용됨 표시
                    frame_gap = abs(right_press_frame - space_press_frame)
                    input_age = max(frame_counter - right_press_frame, frame_counter - space_press_frame)
                    print(f"🎯 오른쪽 드라이브! (→+스페이스 동시 입력 성공, 프레임 차이: {frame_gap}, 입력 나이: {input_age})")
                    # 사용된 프레임 초기화
                    right_press_frame = -1
                    space_press_frame = -1

                # 한쪽 방향키를 미리 홀드한 상태에서 스페이스바를 누른 경우도 허용 (연타 방지 조건은 동일)
                elif (
                    space_just_pressed
                    and drive_global_cooldown == 0
                    and (keys[pygame.K_LEFT] or keys[pygame.K_RIGHT])
                    and selected_character_type != "soldier"
                ):
                    perfect_direction = -1 if keys[pygame.K_LEFT] else 1
                    perfect_timing_cooldown = perfect_timing_cooldown_frames
                    drive_global_cooldown = drive_global_cooldown_frames
                    perfect_timing_input_used = True
                    frame_gap = 0
                    input_age = 0
                    print(f"🎯 드라이브 입력 감지! ({'←' if keys[pygame.K_LEFT] else '→'} 홀드 + 스페이스)")
                    if keys[pygame.K_LEFT]:
                        left_press_frame = frame_counter
                        right_press_frame = -1
                    else:
                        right_press_frame = frame_counter
                        left_press_frame = -1
                    space_press_frame = frame_counter
                
                # 🚫 스페이스바만 누르거나 방향키만 누른 경우
                elif space_just_pressed or left_just_pressed or right_just_pressed:
                    perfect_timing_input_used = True  # 입력은 사용됨으로 표시 (연타 방지)
                    print("🚫 드라이브 실패! 방향키(←/→)와 스페이스바를 동시에 눌러주세요!")
                    
                    # 🏆 스킬 실패 기록
                    record_skill_usage(success=False)
            
            # 🚀 파워스매싱은 이제 동일한 타이밍 윈도우에서 우선순위로 처리됨
            elif space_just_pressed and drive_global_cooldown > 0:
                pass
                # 전역 쿨다운 중일 때 스페이스바를 누른 경우 (가장 우선적으로 체크)
                print(f"🚫 드라이브 전역 쿨다운 중! ({drive_global_cooldown} 프레임 남음) - 연타 차단!")
            elif space_just_pressed and perfect_timing_input_used:
                pass
                # 이미 이 윈도우에서 입력을 사용한 경우
                print("🎯 이미 이 퍼펙트 타이밍 윈도우에서 입력을 사용했습니다! (연타 방지)")
            elif space_just_pressed and perfect_timing_cooldown > 0:
                pass
                # 쿨다운 중일 때 스페이스바를 누른 경우
                print(f"🎯 퍼펙트 타이밍 쿨다운 중! ({perfect_timing_cooldown} 프레임 남음)")
            
            # 윈도우 시간 초과 시 리셋
            if perfect_timing_frame_count > perfect_timing_window:
                perfect_timing_active = False
                perfect_timing_frame_count = 0
                perfect_direction = None
                perfect_timing_input_used = False  # 🆕 플래그 리셋
                refresh_perfect_timing_indicator()
                # 오래된 키 입력 기록 초기화 (선입력 방지)
                left_press_frame = -1
                right_press_frame = -1
                space_press_frame = -1
                print("🎯 퍼펙트 타이밍 윈도우 만료")
            
            # 🚀 개선된 윈도우 비활성화 조건: X축 범위도 체크
            ball_x_out_of_range = abs(BALL.centerx - PLAYER.centerx) > (PADDLE_WIDTH / 2 + BALL_RADIUS + 30)
            if (ball_to_paddle_distance > 100 or 
                ball_vel[1] <= 0 or 
                ball_to_paddle_distance < 0 or 
                ball_x_out_of_range):  # 🎯 X축 범위 벗어남도 체크
                perfect_timing_active = False
                perfect_timing_frame_count = 0
                if ball_x_out_of_range:
                    x_distance = abs(BALL.centerx - PLAYER.centerx)
                    print(f"🎯 퍼펙트 타이밍 윈도우 비활성화: 공이 패들 범위를 벗어남 (X거리: {x_distance:.1f})")
                perfect_direction = None
                perfect_timing_input_used = False  # 🆕 플래그 리셋
                refresh_perfect_timing_indicator()
                # 오래된 키 입력 기록 초기화 (선입력 방지)
                left_press_frame = -1
                right_press_frame = -1
                space_press_frame = -1
                print(f"🎯 퍼펙트 타이밍 윈도우 비활성화 (거리: {ball_to_paddle_distance:.1f}, vel_y: {ball_vel[1]:.1f})")
                
                # 나쁜 타이밍 감지 - 기회를 놓쳤거나 부정확한 타이밍
                if ball_to_paddle_distance > 50 and abs(ball_vel[1]) > 8:  # 거리가 멀고 빠른 공 놓침
                    pass
                    record_poor_timing_hit()
                elif perfect_timing_input_used and ball_to_paddle_distance > 30:  # 입력했지만 거리가 멀음
                    record_missed_opportunity()
        
        # 마우스 커서 설정 (비활성화됨)
        # if input_manager.get_control_mode() == "마우스":
        #     pygame.mouse.set_visible(False)  # 게임 중에는 마우스 커서 숨김
        # else:
        pygame.mouse.set_visible(True)   # 키보드 모드로 고정

        if profiler:
            profiler.end_section("Input")
            profiler.start_section("Events")
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            
            # 키보드 이벤트 처리
            if event.type == pygame.KEYDOWN:
                pass
                # 🎯 일시정지 토글 (P키)
                if event.key == pygame.K_p:
                    global game_paused
                    game_paused = not game_paused
                    print(f"🎯 게임 일시정지 토글: {'ON' if game_paused else 'OFF'}")
                    continue  # 일시정지 토글 후 다른 키 처리 건너뛰기
                
                # 🧠 AI 모드 전환 (N키)
                elif event.key == pygame.K_n:
                    toggle_ai_mode()
                # I키 기능 제거: ESC 메뉴의 '정보'에서 확인 가능
                # elif event.key == pygame.K_i:
                #     # 플레이어 스킬 표시 토글
                #     global skill_display_enabled
                #     skill_display_enabled = not skill_display_enabled
                #     print(f"🏆 플레이어 스킬 표시: {'ON' if skill_display_enabled else 'OFF'}")
                #     continue

            # 마우스 이벤트 처리 (비활성화됨)
            # if input_manager.get_control_mode() == "마우스":
            #     # 마우스 이벤트는 input_manager에서 처리
            #     input_manager.handle_mouse_event(event)
            #     # 마우스 휠로 아이템 선택 (조작 모드가 마우스일 때)
            #     if event.type == pygame.MOUSEWHEEL and input_manager.get_control_mode() == "마우스" and active_item_slot:
            #         if event.y > 0:  # 휠 위로
            #             selected_item_index = (selected_item_index - 1) % len(active_item_slot)
            #         elif event.y < 0:  # 휠 아래로
            #             selected_item_index = (selected_item_index + 1) % len(active_item_slot)

            # ESC 키로 일시정지 메뉴
            if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                result = show_pause_menu()
                if result == "surrender":
                    pass
                    # 기권 처리 - 먼저 평가 결과 표시
                    try:
                        if player_analyzer:
                            pass
                            show_death_evaluation()  # 기권 시에도 평가 결과 표시
                    except:
                        pass  # 평가 실패해도 계속 진행
                    
                    # 기권 처리
                    earned = int(session_medal_earned * 0.5)
                    medal_score += earned
                    session_medal_earned = 0
                    
                    # 아이템 관련 전부 초기화
                    items.reset_items()
                    
                    # 듀스 시스템 리셋 (기권 시)
                    reset_deuce_system()
                    
                    # 패시브 아이템 효과 초기화
                    speedboots_obtained = False
                    speedgear_obtained = False
                    battery_obtained = False
                    revival_obtained = False
                    revival_used = False
                    master_obtained = False
                    cooltime_obtained = False
                    chargebag_obtained = False
                    spikeboots_obtained = False
                    dashgear_obtained = False
                    bulkup_obtained = False
                    dashholder_obtained = False
                    gravitybelt_obtained = False
                    danger_sensor_obtained = False
                    sensor_obtained = False
                    items.speedboots_obtained = False
                    items.speedgear_obtained = False
                    items.battery_obtained = False
                    items.revival_obtained = False
                    items.revival_used = False
                    items.master_obtained = False
                    items.cooltime_obtained = False
                    items.chargebag_obtained = False
                    items.spikeboots_obtained = False
                    items.dashgear_obtained = False
                    items.bulkup_obtained = False
                    items.dashholder_obtained = False
                    items.gravitybelt_obtained = False
                    items.sensor_obtained = False
                    
                    # 대쉬 토큰 수 및 시너지 효과 리셋 (대쉬홀더 없이는 기본 1개)
                    rolling_charges = 1
                    gravity_speed_synergy = False  # 시너지 효과 리셋
                    
                    # 대쉬 매니저 완전 리셋
                    if dash is not None:
                        dash.update_bonuses(False, False, False)  # 모든 아이템 비활성화
                        dash.reset_to_base()  # 기본 상태로 리셋
                    
                    return "main_menu"  # 메인 메뉴로 돌아감
            
            # Tab 키로 정보창 패시브 탭으로 이동
            if event.type == pygame.KEYDOWN and event.key == pygame.K_TAB:
                show_game_info()

            # 플레이어 서브 입력
            if is_player_serve and is_waiting_for_serve:
                if event.type == pygame.KEYDOWN and event.key == pygame.K_SPACE:
                    pass
                    # 서브 실행 및 상태 업데이트
                    serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                    ball_vel = serve_result['ball_vel']
                    ball_impact_boost = serve_result['ball_impact_boost']
                    is_waiting_for_serve = serve_result['is_waiting_for_serve']
                    if serve_result['fireball_last_cast'] is not None:
                        fireball_last_cast = serve_result['fireball_last_cast']
                        fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                    SOUND_SERVE.play()
                    # 🏓 서브 시에도 물리 효과 적용
                    calculate_bounce(PLAYER)  # 서브는 드라이브 발동 안됨
                    # 🎯 서브 시 타격 이펙트 생성
                    create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=True)

            # 아이템 사용 - Aipill 활성화 시에는 아이템 사용 불가
            item_use_pressed = False
            direct_item_index = -1  # 숫자키로 직접 선택된 아이템 인덱스
            
            # 키보드 조작
            if event.type == pygame.KEYDOWN:
                if event.key in [pygame.K_s, 0x73, 0x6D]:  # 영어 S, 한글 ㅁ
                    item_use_pressed = True
                
                # 🔢 숫자키로 아이템 직접 사용 (1~6)
                elif event.key >= pygame.K_1 and event.key <= pygame.K_6:
                    number_key = event.key - pygame.K_1  # 0~5로 변환
                    if active_item_slot and number_key < len(active_item_slot):
                        direct_item_index = number_key
                        print(f"🔢 숫자키 {number_key + 1}번으로 아이템 직접 사용!")
                
                # 아이템 선택 - Aipill 활성화 시에도 선택은 가능 (시각적 피드백용)
                if event.key in [pygame.K_a, 0x61, 0x6E] and active_item_slot:  # 영어 A, 한글 ㄴ
                    pass
                    selected_item_index = (selected_item_index - 1) % len(active_item_slot)
                elif event.key in [pygame.K_d, 0x64, 0x6F] and active_item_slot:  # 영어 D, 한글 ㅇ
                    selected_item_index = (selected_item_index + 1) % len(active_item_slot)
            
            # 마우스 조작 (비활성화됨)
            # if input_manager.get_control_mode() == "마우스":
            #     if mouse_controls.get("item_use", False):
            #         item_use_pressed = True
            
            # 📦 아이템 사용 처리 (S키 또는 숫자키)
            if not aipill_active and active_item_slot:
                use_item = False
                target_index = -1
                
                # S키로 현재 선택된 아이템 사용
                if item_use_pressed and selected_item_index < len(active_item_slot):
                    use_item = True
                    target_index = selected_item_index
                
                # 숫자키로 직접 아이템 사용
                elif direct_item_index >= 0:
                    use_item = True
                    target_index = direct_item_index
                
                if use_item:
                    item = active_item_slot[target_index]
                    current_time = pygame.time.get_ticks()
                    
                    # 🔢 숫자키 사용 시 선택 인덱스도 업데이트
                    if direct_item_index >= 0:
                        selected_item_index = target_index
                    
                    # 쿨타임 체크 (개별 아이템 쿨타임 + 전역 쿨타임)
                    # 장인 아이템이 있으면 쿨타임 10% 감소 (0.8초), 쿨타임 아이템이 있으면 2.4초 추가 감소
                    cooldown_reduction = 800 if master_obtained else 0  # 10% of 8000ms
                    cooldown_reduction += 2400 if cooltime_obtained else 0  # 30% of 8000ms
                    base_cooldown = max(0, 8000 - cooldown_reduction)
                    try:
                        base_cooldown = int(base_cooldown * academy.get_active_item_cooldown_multiplier())
                    except Exception:
                        pass
                    individual_cooldown_ok = "last_use" not in item or current_time - item["last_use"] >= base_cooldown
                    global_cooldown_ok = current_time - last_item_use_time >= base_cooldown
                    if individual_cooldown_ok and global_cooldown_ok:  # 둘 다 만족해야 사용 가능
                        effect_result = apply_effect(item["effect"])
                        if effect_result == False:
                            continue

                        recycle_triggered = False
                        recycle_chance = 0.0
                        gauge_bonus = 0
                        try:
                            recycle_chance = academy.get_item_recycle_chance()
                            gauge_bonus = academy.get_active_item_gauge_bonus()
                        except Exception:
                            recycle_chance = 0.0
                            gauge_bonus = 0
                        if recycle_chance > 0 and random.random() < recycle_chance:
                            recycle_triggered = True
                            print("⚗️ 연금술 발동! 아이템이 유지됩니다.")

                        if gauge_bonus:
                            current_max = get_max_gauge() if 'get_max_gauge' in globals() else special_gauge_max
                            special_gauge = min(current_max, special_gauge + gauge_bonus)
                            if special_gauge >= 350:
                                special_ready = True

                        if not recycle_triggered:
                            # 사용한 아이템 제거
                            del active_item_slot[target_index]

                        if not recycle_triggered:
                            # 선택 인덱스 조정
                            if selected_item_index >= len(active_item_slot):
                                pass
                                selected_item_index = max(0, len(active_item_slot) - 1)
                            elif target_index <= selected_item_index and selected_item_index > 0:
                                pass
                                # 선택된 아이템보다 앞의 아이템이 삭제되면 인덱스 조정
                                selected_item_index -= 1
                        
                        # 전역 쿨타임 업데이트
                        last_item_use_time = current_time
                        
                        # 남은 다른 아이템들에만 쿨타임 적용 (사용한 아이템은 제거되었으므로)
                        for other_item in active_item_slot:
                            other_item["last_use"] = current_time
                    else:
                        pass
                        # 쿨타임 중일 때 피드백
                        if not individual_cooldown_ok:
                            print("개별 아이템 쿨타임 중...")
                        if not global_cooldown_ok:
                            remaining_time = ((8000 - cooldown_reduction) - (current_time - last_item_use_time)) / 1000
                            print(f"전역 쿨타임 중... {remaining_time:.1f}초 남음")

        # ✅ 플레이어 서브 자동 발사 (3초 이상 대기하면 자동으로 serve)
        if is_player_serve and is_waiting_for_serve:
            if pygame.time.get_ticks() - waiting_start_time >= 3000:  # 3초
                pass
                # 서브 실행 및 상태 업데이트
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                # 🏓 플레이어 자동 서브 시에도 물리 효과 적용
                calculate_bounce(PLAYER)  # 자동 서브는 드라이브 발동 안됨
                # 🎯 플레이어 자동 서브 시 타격 이펙트 생성
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=True)

        # 아이템 스폰 처리 (템스폰)
        if pygame.time.get_ticks() - last_item_spawn_time >= next_item_spawn_delay:
            items.spawn_random_item()
            last_item_spawn_time = pygame.time.get_ticks()
            next_item_spawn_delay = random.randint(15000, 25000)
            try:
                next_item_spawn_delay = int(next_item_spawn_delay * academy.get_item_spawn_delay_multiplier())
            except Exception:
                pass

        if profiler:
            profiler.end_section("Events")
            profiler.start_section("GameLogic")
        
        # 🎯 일시정지 상태가 아닐 때만 게임 로직 업데이트
        if not game_paused:
            pass
            # 🔧 파워스매싱 정지 시간 체크 및 처리
            if power_smashing_freeze_active:
                current_time = pygame.time.get_ticks()
                elapsed_freeze_time = current_time - power_smashing_freeze_start_time
                
                if elapsed_freeze_time >= power_smashing_freeze_duration:
                    pass
                    # 정지 시간 종료 - 공 발사 및 효과음 재생
                    power_smashing_freeze_active = False
                    # 고스트샷이 아닐 때만 파워스매싱 포물선 활성화
                    if not mega_smashing_active:
                        pass
                        power_smashing_parabola_active = True
                    else:
                        print(f"🐉 고스트샷 정지 시간 종료! mega_smashing_active={mega_smashing_active}")
                    power_smashing_start_time = current_time
                    
                    # 파워스매시 발사 후 special_active를 False로 설정하여 게이지 충전 허용
                    special_active = False
                    
                    # 🎵 파워스매싱 공 발사 효과음 재생
                    SOUND_POWER_SMASH_LAUNCH.play()
                    print("🎵 파워스매싱 정지 시간 종료! 공 발사 효과음 재생!")
                    print(f"🚀 파워스매싱 공 발사 시작! (게이지 충전 다시 활성화)")
                    
                    # 고스트샷 상태 확인
                    if mega_smashing_active:
                        print(f"🐉 정지 시간 종료 후 고스트샷 여전히 활성화됨!")
            
            # 🔧 파워스매싱 정지 시간 중에는 게임 로직 업데이트 생략 (고스트샷일 때는 정지 안함)
            if not power_smashing_freeze_active or mega_smashing_active:
                pass
                # 상태 업데이트
                # 🆕 새로운 보스전에서는 빨간 효과 업데이트 생략 (게이지를 사용하지 않음)
                if not new_boss_mode_active:
                    update_red_intensity()
                    update_gauge_animation()  # 게이지 부드러운 애니메이션 업데이트
                update_item_obtained_effect()  # 🆕 아이템 획득 효과 업데이트
                # 풍선 터지는 효과는 effects_manager에서 통합 관리
                update_impact_particles()  # 🎯 타격 이펙트 파티클 업데이트
                handle_whip()
                handle_balloon()  # 🆕 풍선 스킬 처리
                handle_quake()

                handle_new_boss_skills_timer()  # 🆕 새로운 보스들 스킬 타이머 처리
                handle_emotional_overdrive()
                handle_tears()
                check_tear_collisions()
                check_balloon_collisions()  # 🆕 풍선 충돌 감지
                update_water_trail()  # 🆕 물자국 업데이트
                handle_aipill()  # 🆕 AI 필 타이머 처리
                handle_wall()  # 🆕 벽돌 처리

                # 아이템 업데이트
                items.update_items(PLAYER, apply_effect, store_passive_item, store_active_item)

                handle_player(keys)
                handle_ball()
                handle_boss()
                
                # 🌟 대쉬 스피릿 레이저 시스템 업데이트
                update_dash_spirit_lasers()
                check_laser_ball_collision()

        if profiler:
            profiler.end_section("GameLogic")
            profiler.start_section("Rendering")
        
        # 원래 렌더링 로직 (항상 60fps)
        # 화면 흔들림 효과 처리
        draw_shaking_screen()
        
        if screen_shake_offset_x != 0 or screen_shake_offset_y != 0:
            pass
            # 화면 흔들림이 있을 때만 임시 표면 사용
            print(f"🎮 화면 흔들림 렌더링: offset=({screen_shake_offset_x}, {screen_shake_offset_y})")
            temp_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            
            # 임시 표면에 모든 것 그리기
            temp_surface.fill((0, 0, 0, 0))  # 투명한 배경으로 지우기
            # SCREEN을 임시로 temp_surface로 교체
            temp_screen = SCREEN
            SCREEN = temp_surface
            
            draw_field()
            draw_objects()
            draw_boss_health_bar()  # 💪 체력형 보스 체력바 그리기
            draw_laser_cannon_gauge()  # ⚡ 레이저 쿨타임 게이지바
            
            # 스테이지 1 벽 충돌 테두리 깜빡임 효과
            if current_stage == 1 and border_flash_active:
                print(f"🎨 테두리 렌더링 체크: stage={current_stage}, active={border_flash_active}, timer={border_flash_timer}")
                if border_flash_timer > 0:
                    pass
                    # 깜빡임 효과를 위한 알파값 계산 (빠른 페이드 아웃)
                    alpha = (border_flash_timer / border_flash_duration)
                    flash_color = (
                        int(border_flash_color[0] * alpha),
                        int(border_flash_color[1] * alpha),
                        int(border_flash_color[2] * alpha)
                    )
                    print(f"🎨 테두리 색상: {flash_color}, alpha={alpha}")
                    
                    # 테두리 그리기 (상, 하, 좌, 우)
                    pygame.draw.rect(temp_surface, flash_color, (0, 0, WIDTH, border_flash_thickness))  # 상단
                    pygame.draw.rect(temp_surface, flash_color, (0, HEIGHT - border_flash_thickness, WIDTH, border_flash_thickness))  # 하단
                    pygame.draw.rect(temp_surface, flash_color, (0, 0, border_flash_thickness, HEIGHT))  # 좌측
                    pygame.draw.rect(temp_surface, flash_color, (WIDTH - border_flash_thickness, 0, border_flash_thickness, HEIGHT))  # 우측
                    
                    border_flash_timer -= 1
                else:
                    border_flash_active = False
            
            # 원래 화면으로 복원하고 흔들림 적용
            SCREEN = temp_screen
            SCREEN.fill(BLACK)  # 원래 화면도 검은색으로 지우기
            SCREEN.blit(temp_surface, (screen_shake_offset_x, screen_shake_offset_y))
        else:
            pass
            # 흔들림이 없을 때는 직접 그리기
            draw_field()
            draw_objects()
            draw_boss_health_bar()  # 💪 체력형 보스 체력바 그리기
            draw_laser_cannon_gauge()  # ⚡ 레이저 쿨타임 게이지바
            
            # 스테이지 1 벽 충돌 테두리 깜빡임 효과
            if current_stage == 1 and border_flash_active:
                print(f"🎨 테두리 렌더링 체크: stage={current_stage}, active={border_flash_active}, timer={border_flash_timer}")
                if border_flash_timer > 0:
                    pass
                    # 깜빡임 효과를 위한 알파값 계산 (빠른 페이드 아웃)
                    alpha = (border_flash_timer / border_flash_duration)
                    flash_color = (
                        int(border_flash_color[0] * alpha),
                        int(border_flash_color[1] * alpha),
                        int(border_flash_color[2] * alpha)
                    )
                    print(f"🎨 테두리 색상: {flash_color}, alpha={alpha}")
                    
                    # 테두리 그리기 (상, 하, 좌, 우)
                    draw.rect( flash_color, (0, 0, WIDTH, border_flash_thickness))  # 상단
                    draw.rect( flash_color, (0, HEIGHT - border_flash_thickness, WIDTH, border_flash_thickness))  # 하단
                    draw.rect( flash_color, (0, 0, border_flash_thickness, HEIGHT))  # 좌측
                    draw.rect( flash_color, (WIDTH - border_flash_thickness, 0, border_flash_thickness, HEIGHT))  # 우측
                    
                    border_flash_timer -= 1
                else:
                    border_flash_active = False
        
        # 스테이지 2 정글 테두리 효과
        if current_stage == 2:
            draw_stage2_jungle_border()
            update_stage2_leaves()
            draw_stage2_leaves(SCREEN)
        
        draw_water_trail()  # 🆕 물자국 그리기
        draw_balloons()  # 🆕 풍선 그리기
        # 풍선 터지는 효과는 effects_manager에서 통합 관리
        draw_item_obtained_effect()  # 🆕 아이템 획득 효과 그리기
        draw_dash_spirit_lasers(SCREEN, PLAYER, dash_spirit_lasers)  # 🌟 대쉬 스피릿 레이저 그리기
        draw_ai_visualization()  # 🧠 AI 상태 시각화
        # draw_player_skill_display()  # 🏆 플레이어 실력 표시 (ESC 메뉴에서 확인)
        
        # 🎯 일시정지 UI 렌더링
        if game_paused:
            draw_pause_overlay()
        
        # === DRIVE! 텍스트 표시 ===
        global drive_text_timer
        if drive_text_timer > 0:
            drive_text_timer -= 1
            
            # 텍스트 위치 (플레이어 패들 주변)
            text_x = PLAYER.centerx
            text_y = PLAYER.centery - 60
            
            # 텍스트 애니메이션 (페이드 인/아웃)
            if drive_text_timer > 22:
                pass
                alpha = int(255 * ((30 - drive_text_timer) / 8))
            elif drive_text_timer < 8:
                pass
                alpha = int(255 * (drive_text_timer / 8))
            else:
                alpha = 255
            
            # DRIVE! 텍스트 그리기 (깨끗한 흰색, 폰트 크기 축소)
            try:
                drive_font = pygame.font.Font("NanumSquareEB.ttf", 28)
            except:
                drive_font = pygame.font.Font(None, 36)
            
            # 그림자 효과
            shadow_surf = drive_font.render("DRIVE!", True, (50, 50, 50))
            shadow_surf.set_alpha(alpha)
            shadow_rect = shadow_surf.get_rect(center=(text_x + 2, text_y + 2))
            SCREEN.blit(shadow_surf, shadow_rect)
            
            # 메인 텍스트 (깨끗한 흰색)
            text_surf = drive_font.render("DRIVE!", True, (255, 255, 255))
            text_surf.set_alpha(alpha)
            text_rect = text_surf.get_rect(center=(text_x, text_y))
            SCREEN.blit(text_surf, text_rect)
        
        if profiler:
            profiler.end_section("Rendering")
            profiler.draw()  # 프로파일러 오버레이 그리기
            
        pygame.display.flip()
        
        # 프로파일러 프레임 종료
        if profiler:
            profiler.end_frame()

        # 마우스 상태 업데이트 (비활성화됨)
        # # 마우스 위치 업데이트는 input_manager에서 처리
        # input_manager.update_mouse_position()
        # # 마우스 휠 상태 초기화는 input_manager에서 처리
        # input_manager.reset_wheel_events()
        # # MOUSE_WHEEL_DOWN은 input_manager에서 처리
        
        # 라운드 종료 체크
        if round_wins >= win_goal:
            pass
            # 🆕 게임 종료 시 즉시 상모돌리기 사운드 정지
            whip_active = False
            whip_timer = 0
            whip_sound.stop()
            if BOSS and hasattr(BOSS, 'whip_sound') and BOSS.whip_sound:
                BOSS.whip_sound.stop()
            
            show_result(True)
            return
        elif round_losses >= win_goal:
            pass
            # 🆕 게임 종료 시 즉시 상모돌리기 사운드 정지
            whip_active = False
            whip_timer = 0
            whip_sound.stop()
            if BOSS and hasattr(BOSS, 'whip_sound') and BOSS.whip_sound:
                BOSS.whip_sound.stop()
            
            # 🏆 스테이지 실패 기록
            record_stage_result(current_stage, cleared=False)
            
            show_result(False)
            return
