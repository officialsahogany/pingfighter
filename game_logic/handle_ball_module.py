"""
handle_ball 함수 - bosspong.py에서 추출
1,591줄의 거대한 함수를 별도 모듈로 분리
"""

import math
import random

import pygame

from core.game_state import GameState

import game_logic.stage2_effects as stage2_effects


CHARGBAG_WALL_COOLDOWN_FRAMES = 1
DEFAULT_CHARGEBAG_BASE_GAIN = 80

def handle_ball():
    # 게임 상태 변수들
    global round_wins, round_losses, boss_speed_boost_timer, boss_fail_timer
    global is_waiting_for_serve, deuce_wins, deuce_losses
    
    # 플레이어 & 보스 게이지/스킬 시스템
    global special_gauge, special_ready, special_active
    global boss_special_gauge, boss_special_ready, boss_red_intensity
    global boss_special_gauge_stage4, boss_special_ready_stage4
    global boss_current_health  # 💪 체력형 보스 체력 변수
    
    # 스테이지2 효과
    global stage2_border_flash_timer
    
    # 충돌 쿨다운
    global player_collision_cooldown, boss_collision_cooldown, player_collision_handled, player_sound_cooldown
    
    # 공 물리 & 움직임
    global ball_vel, ball_angle, slow_ball_timer, horizontal_bounce_count
    global ball_impact_boost, ball_boost_decay_rate, ball_min_boost
    global player_last_shot_speed
    
    # 고스트샷 관련 변수들
    global mega_smashing_active, mega_smashing_bonus_applied, mega_smashing_meteor_trail
    global mega_smashing_boss_defense_count, mega_smashing_ghost_scatter, mega_smashing_ghost_scatter_time
    global mega_smashing_ghosts, dashholder_obtained, rolling_charges, rolling_charge_timer
    
    # 충돌 쿨다운 감소
    if player_collision_cooldown > 0:
        player_collision_cooldown -= 1
    if boss_collision_cooldown > 0:
        boss_collision_cooldown -= 1
    if player_sound_cooldown > 0:
        player_sound_cooldown -= 1
    
    # 프레임 시작 시 충돌 플래그 리셋 (매 프레임마다 리셋)
    player_collision_handled = False
    
    # 드라이브 & 파워스매싱 시스템
    global drive_ball_active, drive_hit_boss, ball_spin_strength, drive_speed_increase
    global drive_active, drive_spin_speed
    global power_smashing_original_speed, power_smashing_parabola_active
    global power_smashing_start_time, power_smashing_arc_strength
    global mega_smashing_active, mega_smashing_bonus_applied, mega_smashing_meteor_trail
    
    # 보스별 특수 스킬들
    global whip_hit_by_player, whip_active, original_speed, whip_original_ball_speed
    global meditation_active, meditation_timer, meditation_angle
    global stage4_magnetic_active, stage4_magnetic_timer, stage4_magnetic_radius, magnet_curve_angle
    global flame_trail_active, flame_trail_timer, flame_trail_phase
    global flame_trail_positions, flame_trail_start_time, flame_trail_base_vel
    global fireballs, fireball_cooldown, fireball_last_cast, fireball_speed
    global boss_throwing, boss_throw_timer
    global hongryun_hit_count, hongryun_ready
    
    # 아이템 & 효과 시스템
    global aipill_active, walls, rolling_charges, rolling_active
    global rolling_direction, rolling_timer
    global danger_sensor_obtained, danger_sensor_auto_dash_cooldown, danger_sensor_last_auto_dash_time
    
    # 애니메이션 & 이펙트
    global hit_animation_active, hit_animation_timer, boss_hit_timer
    global flame_particles, player_stunned_timer, player_knockback_vel
    global boss_fire_hit_timer  # 💪 보스 화염 타격 타이머
    
    # 방어 스킬들
    global speed_defense_active, speed_defense_timer, speed_defense_checked
    
    # 타이머들
    global last_tears_cast_time, quake_last_used_time

    special_gauge_max = get_max_gauge()  # 🔧 아카데미 스킬 적용된 최대치

    # 위험감지센서용 보스 히트 타이머 감소
    if boss_hit_timer > 0:
        boss_hit_timer -= 1
    
    # 💪 보스 화염 타격 타이머 감소
    if boss_fire_hit_timer > 0:
        boss_fire_hit_timer -= 1

    # === Stage 4 자기장 처리 ===
    if current_stage == 4 and stage4_magnetic_active:
        stage4_magnetic_timer -= 1
        distance = math.hypot(BALL.centerx - BOSS.centerx, BALL.centery - BOSS.centery)
        if distance < stage4_magnetic_radius:
            magnet_curve_angle += 4.1
            direction_to_player = pygame.math.Vector2(
                PLAYER.centerx - BALL.centerx,
                PLAYER.centery - BALL.centery
            )
            if direction_to_player.length() != 0:
                direction_to_player = direction_to_player.normalize()
            curve_vector = direction_to_player.rotate(magnet_curve_angle) * 1.8
            ball_vel[0] += curve_vector.x
            ball_vel[1] += curve_vector.y
            ball_vel[0] *= 1.04
            ball_vel[1] *= 1.04

            # 속도 상한
            current_speed = math.hypot(ball_vel[0], ball_vel[1])
            max_speed = BALL_BASE_SPEED * 2.2
            if current_speed > max_speed:
                scale = max_speed / current_speed
                ball_vel[0] *= scale
                ball_vel[1] *= scale

        if stage4_magnetic_timer <= 0:
            stage4_magnetic_active = False
            recover_speed = max(player_last_shot_speed, BALL_BASE_SPEED)
            direction = pygame.math.Vector2(ball_vel)
            if direction.length() == 0:
                pass
                direction = pygame.math.Vector2(0, 1)
            else:
                direction = direction.normalize()
            ball_vel = [direction.x * recover_speed, direction.y * recover_speed]
            magnet_curve_angle = 0

    # === Stage 4 명상타임 처리 ===
    if current_stage == 4 and meditation_active:
        meditation_timer -= 1
        meditation_angle += 9
        BALL.centerx = int(BOSS.centerx + math.cos(math.radians(meditation_angle)) * 80)
        BALL.centery = int(BOSS.centery + math.sin(math.radians(meditation_angle)) * 80)
        meditation_trails.append((BALL.centerx, BALL.centery, 200))
        meditation_trails[:] = [(x, y, a-15) for x, y, a in meditation_trails if a > 15][:12]
        if meditation_timer <= 0:
            meditation_active = False
            angle_deg = random.randint(-60, 60)
            speed = max(player_last_shot_speed, BALL_BASE_SPEED * random.uniform(1.1, 1.4))
            rad = math.radians(angle_deg)
            ball_vel = [speed * math.sin(rad), speed * math.cos(rad)]
            ball_angle = 0
            drive_active = True
            drive_spin_speed = random.choice([-0.6, 0.6])
        return

    # ✅ 서브 대기
    if is_waiting_for_serve:
        if is_player_serve:
            BALL.centerx = PLAYER.centerx
            BALL.bottom = PLAYER.top - 5
        else:
            BALL.centerx = BOSS.centerx
            BALL.top = BOSS.bottom + 5
        return

    # === Stage 5 화염탄 ===
    if current_stage == 5:
        now = pygame.time.get_ticks()
        # 🔥 라운드 시작 2.5초 후부터 화염탄 발사 가능
        if (now - fireball_last_cast > fireball_cooldown and 
            now - round_start_time >= 2500):
            fireball_last_cast = now
            fireball_cooldown = random.randint(3500, 5000)
            num_fireballs = random.randint(2, 3) if random.random() < 0.4 else 1
            
            # 🆕 화염탄 발사 효과음 재생
            SOUND_FIREBALL.play()
            
            for i in range(num_fireballs):
                pos = [BOSS.centerx, BOSS.bottom]
                offset_angle = random.uniform(-20, 20)
                dir_vec = pygame.math.Vector2(
                    PLAYER.centerx - BOSS.centerx,
                    PLAYER.centery - BOSS.centery
                ).normalize().rotate(offset_angle)
                vel = [dir_vec.x * fireball_speed, dir_vec.y * fireball_speed]
                fireballs.append([pos, vel])
            boss_throwing = True
            boss_throw_timer = 25      

        if boss_throwing:
            boss_throw_timer -= 1
            if boss_throw_timer <= 0:
                boss_throwing = False

        new_fireballs = []
        for pos, vel in fireballs:
            pos[0] += vel[0]
            pos[1] += vel[1]
            fireball_rect = pygame.Rect(pos[0]-8, pos[1]-8, 16, 16)
            if fireball_rect.colliderect(PLAYER):
                player_stunned_timer = int(0.3 * FPS)
                player_knockback_vel = random.choice([-18, 18])

                # 🔥 화염탄 폭발 이펙트 생성
                create_fireball_explosion(pos[0], pos[1])

                # 🔹 홍련 게이지 충전
                hongryun_hit_count += 1
                if hongryun_hit_count >= HONGRYUN_MAX_HITS:
                    hongryun_ready = True

                continue  # 화염탄 제거
               
            if 0 <= pos[0] <= WIDTH and 0 <= pos[1] <= HEIGHT:
                new_fireballs.append([pos, vel])
        fireballs = new_fireballs
        
        # 🔥 화염탄 폭발 파티클 업데이트
        update_fireball_explosion_particles()

    # === Stage 5 홍련폭염 (뱀 궤적) ===
    if flame_trail_active:
        flame_trail_timer -= 1
        flame_trail_positions.append((BALL.centerx, BALL.centery))
        if len(flame_trail_positions) > 30:
            flame_trail_positions.pop(0)
        effects_manager.spawn_flame_particles(BALL.centerx, BALL.centery, count=3)

        # 초기화
        if flame_trail_phase == 0:
            flame_trail_phase = 1
            flame_trail_start_time = pygame.time.get_ticks()
            flame_trail_base_vel = pygame.math.Vector2(
                PLAYER.centerx - BALL.centerx,
                PLAYER.centery - BALL.centery
            ).normalize()

        elapsed = (pygame.time.get_ticks() - flame_trail_start_time) / 1000.0

        # 0~1초 차징
        if elapsed < 1.0:
            BALL.x += math.sin(elapsed * 25) * 2
            BALL.y += math.cos(elapsed * 30) * 1
            return

        # 1초 이후 가속 + 뱀 궤적
        accel_elapsed = elapsed - 1.0
        max_speed = 6.0
        accel_time = 6.0
        current_speed = max_speed * min(1.0, accel_elapsed / accel_time)
        current_speed = max(0.001, current_speed ** 1.2)

        amplitude_x = min(40, 10 + accel_elapsed * 6)
        amplitude_y = min(20, 5 + accel_elapsed * 3)
        noise_x = random.uniform(-2, 2)
        noise_y = random.uniform(-1, 1)

        BALL.x += flame_trail_base_vel.x * current_speed + math.sin(accel_elapsed * 6) * amplitude_x + noise_x
        BALL.y += flame_trail_base_vel.y * current_speed + math.cos(accel_elapsed * 3) * amplitude_y + noise_y

        # 🔹 플레이어 충돌 처리 - 화려한 폭발 이벤트
        if BALL.colliderect(PLAYER):
            flame_trail_active = False
            flame_trail_positions.clear()
            player_stunned_timer = int(0.3 * FPS)
            player_knockback_vel = random.choice([-36, 36])

            # 🎆 대규모 화염 폭발 이벤트
            explosion_x = PLAYER.centerx
            explosion_y = PLAYER.top
            
            # 1️⃣ 중심 폭발 - 큰 화염구
            for ring in range(3):  # 3개의 링
                for angle_deg in range(0, 360, 15):  # 24방향
                    angle = math.radians(angle_deg)
                    speed = 8.0 - ring * 2.0  # 바깥 링일수록 느리게
                    size = 8 - ring * 2  # 바깥 링일수록 작게
                    
                    vx = math.cos(angle) * speed
                    vy = math.sin(angle) * speed
                    
                    flame_particles.append([
                        explosion_x, explosion_y,
                        vx, vy,
                        255,  # 알파
                        max(3, size)  # 크기
                    ])
            
            # 2️⃣ 화염 파편 - 작은 불꽃들 (80개)
            for _ in range(80):
                angle = random.uniform(0, 2*math.pi)
                speed = random.uniform(3.0, 12.0)
                vx = math.cos(angle) * speed
                vy = math.sin(angle) * speed
                
                # 다양한 크기의 파편
                size = random.choices([2, 3, 4, 5, 6], weights=[30, 25, 20, 15, 10])[0]
                
                flame_particles.append([
                    explosion_x + random.randint(-10, 10),
                    explosion_y + random.randint(-5, 5),
                    vx, vy,
                    255,
                    size
                ])
            
            # 3️⃣ 화염 기둥 효과 - 수직으로 솟아오르는 화염
            for i in range(15):
                for side in [-1, 0, 1]:  # 3개 기둥
                    column_x = explosion_x + side * 20
                    vy = -random.uniform(8.0, 15.0)  # 위로 솟구침
                    vx = side * random.uniform(0.5, 2.0)  # 약간 옆으로
                    
                    flame_particles.append([
                        column_x + random.randint(-5, 5),
                        explosion_y,
                        vx, vy,
                        255,
                        random.randint(4, 7)
                    ])
            
            # 4️⃣ 스파크 효과 - 빠르게 튀는 작은 불씨들
            for _ in range(40):
                angle = random.uniform(0, 2*math.pi)
                speed = random.uniform(10.0, 18.0)  # 매우 빠름
                vx = math.cos(angle) * speed
                vy = math.sin(angle) * speed
                
                flame_particles.append([
                    explosion_x, explosion_y,
                    vx, vy,
                    255,
                    1  # 매우 작은 크기
                ])
            
            # 5️⃣ 화염 폭풍 효과 - 회전하는 화염
            for spiral in range(5):  # 5개의 나선
                base_angle = (spiral * 72) * math.pi / 180  # 72도씩 분리
                for i in range(10):
                    angle = base_angle + (i * 0.3)  # 나선형
                    distance = i * 4
                    
                    spiral_x = explosion_x + math.cos(angle) * distance
                    spiral_y = explosion_y + math.sin(angle) * distance
                    
                    # 나선을 따라 바깥으로 퍼지는 속도
                    vx = math.cos(angle) * 3.0
                    vy = math.sin(angle) * 3.0
                    
                    flame_particles.append([
                        spiral_x, spiral_y,
                        vx, vy,
                        200,  # 약간 투명
                        random.randint(3, 5)
                    ])
            
            # 6️⃣ 화면 흔들림 효과를 위한 추가 시각 효과
            # 큰 플래시 효과를 위한 중심 폭발
            for _ in range(3):
                flash_size = random.randint(15, 25)
                flame_particles.append([
                    explosion_x + random.randint(-20, 20),
                    explosion_y + random.randint(-10, 10),
                    random.uniform(-1, 1),  # 거의 정지
                    random.uniform(-1, 1),
                    200,  # 반투명
                    flash_size  # 큰 크기
                ])
            
            # 🔊 시각적 임팩트를 위한 잔광 효과
            effects_manager.spawn_flame_particles(explosion_x, explosion_y, count=50)
            
            # 화면 전체 플래시 효과 (옵션)
            flash_surface = pygame.Surface((WIDTH, HEIGHT))
            flash_surface.fill((255, 200, 100))
            flash_surface.set_alpha(100)
            SCREEN.blit(flash_surface, (0, 0))

            return

    # --- 고스트샷 궤적 이동 (독립적 처리) ---
    if mega_smashing_active:
        if not power_smashing_parabola_active:
            pass
            handle_mega_smashing_trajectory()
        else:
            print(f"⚠️ 고스트샷 활성화되었지만 power_smashing_parabola_active={power_smashing_parabola_active}로 인해 실행 안됨")
    
    # --- 파워스매싱 포물선 궤적 이동 ---
    elif power_smashing_parabola_active:
        time_now = pygame.time.get_ticks()
        elapsed_time = (time_now - power_smashing_start_time) / 1000.0  # 초 단위
        
        # 파워스매싱만 처리 (고스트샷은 위에서 별도 처리)
        if False:  # 고스트샷 로직 제거
            pass
            # 🐍 고스트샷: 뱀처럼 구불거리고 예측불가능한 궤적
            
            # 패턴 선택 (시간에 따라 변화)
            pattern_phase = int(elapsed_time * 2) % 4  # 0.5초마다 패턴 변경
            
            if pattern_phase == 0:  # 🐍 뱀처럼 구불거리는 패턴
                snake_freq = 8.0 + math.sin(elapsed_time * 3) * 2  # 주파수 변화
                snake_amp = 6.0 + math.cos(elapsed_time * 2) * 3   # 진폭 변화
                
                # S자 움직임
                snake_x = math.sin(elapsed_time * snake_freq) * snake_amp
                # 진행 방향에 따른 추가 움직임
                progressive_x = math.sin(elapsed_time * 1.5) * 0.3  # 90% 감소
                
                horizontal_force = snake_x + progressive_x
                
                # 간혹 급격한 방향 전환 (15% 확률)
                if random.random() < 0.15:
                    horizontal_force *= -0.2  # 90% 감소
                    
            elif pattern_phase == 1:  # 🌀 나선형 한바퀴 도는 패턴
                pass
                # 원형 궤도
                orbit_radius = 8.0 + elapsed_time * 2
                orbit_speed = 12.0  # 회전 속도
                
                circular_x = math.cos(elapsed_time * orbit_speed) * orbit_radius
                circular_y_component = math.sin(elapsed_time * orbit_speed) * 3  # Y축에도 영향
                
                horizontal_force = circular_x
                
                # 스파이럴 효과 추가
                spiral_factor = math.sin(elapsed_time * 20) * 2
                horizontal_force += spiral_factor
                
            elif pattern_phase == 2:  # ⚡ 지그재그 번개 패턴
                pass
                # 톱니파 움직임
                zigzag_period = 0.1  # 지그재그 주기
                zigzag_phase = (elapsed_time % zigzag_period) / zigzag_period
                
                if zigzag_phase < 0.5:
                    pass
                    horizontal_force = 15.0  # 오른쪽으로 급격히
                else:
                    horizontal_force = -15.0  # 왼쪽으로 급격히
                    
                # 진폭 변화
                amplitude_mod = math.sin(elapsed_time * 3) * 0.5 + 1.0
                horizontal_force *= amplitude_mod
                
            else:  # 🎯 불규칙한 텔레포트 패턴
                pass
                # 순간이동처럼 보이는 효과
                if random.random() < 0.3:  # 30% 확률로 순간이동
                    teleport_distance = random.uniform(-12, 12)
                    horizontal_force = teleport_distance * 3  # 강한 수평 이동
                else:
                    pass
                    # 일반적인 리사주 곡선
                    freq1 = 3.7 + random.uniform(-0.5, 0.5)
                    horizontal_force = math.sin(freq1 * elapsed_time) * 5
            
            # 고스트샷 방향성 적용
            direction_factor = power_smashing_arc_strength / abs(power_smashing_arc_strength) if power_smashing_arc_strength != 0 else 1
            horizontal_force *= direction_factor
            
            ball_vel[0] += horizontal_force
            
            # 🚀 수직 움직임 - 위로 진행하되 약간의 변화 추가
            base_upward_force = -3.5  # 기본 위쪽 힘
            
            # 패턴에 따른 수직 변화
            if pattern_phase == 1:  # 나선형일 때 Y축 변화
                pass
                vertical_variation = math.sin(elapsed_time * 12) * 1.5
            elif pattern_phase == 2:  # 지그재그일 때 미세한 상하 움직임
                pass
                vertical_variation = math.cos(elapsed_time * 15) * 0.8
            else:
                vertical_variation = math.sin(elapsed_time * 5) * 1.0
            
            vertical_force = base_upward_force + vertical_variation
            
            # 가끔 부스트 (10% 확률)
            if random.random() < 0.1:
                vertical_force -= random.uniform(0.2, 0.5)  # 더 빠르게 위로 (90% 감소)
            
            ball_vel[1] += vertical_force
            
            # 속도 리미터 (너무 빨라지는 것 방지하되 여전히 빠름)
            max_speed = 4.5  # 고스트샷 속도 90% 감소 (45 -> 4.5)
            current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
            if current_speed > max_speed:
                speed_ratio = max_speed / current_speed
                ball_vel[0] *= speed_ratio
                ball_vel[1] *= speed_ratio
                
        else:
            pass
            # 일반 파워스매싱: 기존 포물선 궤적
            # 수평 이동: 강한 방향성 + 적당한 랜덤 변화
            horizontal_decay = max(0.4, 1.0 - elapsed_time * 0.15)  # 적당히 감소, 최소 40% 유지
            
            # 적당한 랜덤 요소 추가
            chaos_factor = math.sin(elapsed_time * 5.0) * 0.2 + random.uniform(-0.15, 0.15)
            horizontal_force = power_smashing_arc_strength * horizontal_decay * (1.0 + chaos_factor)
            ball_vel[0] += horizontal_force
            
            # 수직 이동: 뚜렷한 중력 효과로 명확한 포물선
            # 포물선의 상승과 하강을 뚜렷하게
            if elapsed_time < 1.8:  # 첫 1.8초 동안은 포물선 상승
                pass
                # 초기에는 확실하게 위로, 시간이 지나면서 감소
                base_lift = power_smashing_gravity_effect * 2.2 * (1.8 - elapsed_time) / 1.8  # 뚜렷하게 증가
                # 적당한 수직 변화 요소 추가
                vertical_chaos = math.cos(elapsed_time * 5.0) * 0.015
                vertical_lift = base_lift + vertical_chaos
                ball_vel[1] -= vertical_lift  # 위로 밀어올림 (음수)
                vertical_force = -vertical_lift
            else:  # 1.8초 후부터는 중력으로 뚜렷하게 하강
                base_pull = power_smashing_gravity_effect * 1.8 * (elapsed_time - 1.8)  # 뚜렷한 하강
                # 적당한 하강 변화 요소 추가
                descent_chaos = math.sin(elapsed_time * 7.0) * 0.015
                vertical_pull = base_pull + descent_chaos
                ball_vel[1] += vertical_pull  # 아래로 당김 (양수)
                vertical_force = vertical_pull
        
        # 디버깅 출력 (가끔씩만)
        if time_now % 120 == 0:  # 2초마다
            print(f"🎯 파워스매싱 포물선: 경과시간 {elapsed_time:.2f}s, 수평력 {horizontal_force:.3f}, 수직력 {vertical_force:.3f}")

    # --- 드라이브 이동 ---
    if drive_active:
        ball_vel[0] += drive_spin_speed
        ball_angle += drive_spin_speed * 25
        drive_spin_speed *= 0.995
        if abs(drive_spin_speed) < 0.05:
            drive_active = False

    # --- 수직 정지 방지 ---
    if abs(ball_vel[1]) < 0.5:
        ball_vel[1] += random.choice([-1, 1]) * 1.5

    # --- 위험감지센서 자동 대쉬 로직 ---
    # 디버깅: 센서 상태 확인
    if danger_sensor_obtained:
        print(f"센서 상태 - obtained: {danger_sensor_obtained}, enabled: {danger_sensor_enabled}, ball_vel[1]: {ball_vel[1]:.2f}, BALL.centery: {BALL.centery:.1f}, HEIGHT*0.75: {HEIGHT * 0.75:.1f}")
    
    # 공이 화면의 절반 이하(플레이어와 중간지점의 가운데)로 내려왔을 때만 탐지
    if danger_sensor_obtained and danger_sensor_enabled and ball_vel[1] > 0 and BALL.centery > HEIGHT * 0.75:  # 공이 아래로 내려오고 화면 3/4 지점 이하
        current_time = pygame.time.get_ticks()
        
        # 쿨타임 체크 (10초)
        if not hasattr(handle_ball, 'danger_sensor_last_activation_time'):
            handle_ball.danger_sensor_last_activation_time = 0
        
        # 쿨타임 중이면 위험감지센서만 비활성화하고 공 이동은 계속
        sensor_can_activate = current_time - handle_ball.danger_sensor_last_activation_time >= 10000
        
        # 공의 예상 위치 계산
        time_to_reach_player = (PLAYER.centery - BALL.centery) / ball_vel[1] if ball_vel[1] > 0 else 0
        
        if time_to_reach_player > 0 and time_to_reach_player < 60:  # 1초 이내에 도달할 예정
            predicted_x = BALL.centerx + ball_vel[0] * time_to_reach_player
            
            # 플레이어가 현재 속도로 이동했을 때 도달할 수 있는지 계산
            player_speed = 8  # 플레이어 기본 이동 속도
            player_max_distance = player_speed * time_to_reach_player  # 플레이어 최대 이동 거리
            distance_to_predicted = abs(predicted_x - PLAYER.centerx)
            
            print(f"감지센서 계산 - time_to_reach: {time_to_reach_player:.1f}, predicted_x: {predicted_x:.1f}, distance: {distance_to_predicted:.1f}, max_distance: {player_max_distance:.1f}")
            
            # 도달할 수 없는 상황이면 자동 대쉬 (쿨타임 체크 포함)
            if distance_to_predicted > player_max_distance + PADDLE_WIDTH // 2 and sensor_can_activate:
                pass
                # 대쉬 방향 결정
                dash_direction = 1 if predicted_x > PLAYER.centerx else -1
                print(f"대쉬 조건 체크 - charges: {rolling_charges}, active: {rolling_active}, waiting: {is_waiting_for_serve}")
                
                # 대쉬 실행 - 위험감지센서는 게이지와 토큰 소모 없이 사용
                if not rolling_active and not is_waiting_for_serve:
                    global is_danger_sensor_dash
                    rolling_active = True
                    is_danger_sensor_dash = True  # 위험감지센서 대쉬 플래그 설정
                    
                    # 대시기어 효과: 대시 거리 10% 증가
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
                    rolling_direction = dash_direction
                    # rolling_charges -= 1  # 🚫 위험감지센서 자동 대쉬는 토큰을 소모하지 않음
                    
                    # 🆕 위험감지센서 자동 대쉬는 게이지와 토큰을 소모하지 않음
                    print(f"🤖 위험감지센서 자동 대쉬 - 게이지/토큰 소모 없음 (현재 게이지: {special_gauge}, 토큰: {rolling_charges})")
                    
                    # 쿨타임 설정
                    handle_ball.danger_sensor_last_activation_time = current_time
                    
                    # 대쉬 효과음 재생
                    SOUND_DASH.play()
                    
                    print(f"🤖 위험감지센서 자동 대쉬! 방향: {'오른쪽' if dash_direction > 0 else '왼쪽'} (자동)")
                else:
                    print(f"대쉬 조건 불만족 - charges: {rolling_charges}, active: {rolling_active}, waiting: {is_waiting_for_serve}")

    # --- 🏓 적응형 물리 효과: 충돌 후 점진적 감속 ---
    # 🌊 저속에서는 감속 완화, 고속에서는 감속 강화
    current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
    
    if ball_impact_boost > ball_min_boost:
        pass
        # 속도별 적응형 감속률 적용
        if current_speed < 10:  # 저속: 감속 60% 완화
            pass
            adaptive_decay_rate = 1.0 - (1.0 - ball_boost_decay_rate) * 0.4
        elif current_speed < 15:  # 중속: 기본 감속
            pass
            adaptive_decay_rate = ball_boost_decay_rate
        else:  # 고속: 감속 강화
            speed_ratio = min(current_speed / 25.0, 1.0)
            penalty_factor = 1.0 + speed_ratio * 0.5
            adaptive_decay_rate = 1.0 - (1.0 - ball_boost_decay_rate) * penalty_factor
        
        ball_impact_boost *= adaptive_decay_rate
        
        # 최소값 보정
        if ball_impact_boost < ball_min_boost:
            ball_impact_boost = ball_min_boost
            
        # 디버그 출력 (가끔씩만)
        if pygame.time.get_ticks() % 300 < 16:  # 대략 5초마다
            print(f"🏓 적응형 감속: 속도={current_speed:.1f}, 감속률={adaptive_decay_rate:.3f}, 부스트={ball_impact_boost:.2f}")
    
    # --- 🌪️ 스핀 효과 처리 ---
    global ball_spin_strength, ball_spin_direction, ball_spin_decay
    if ball_spin_strength > 0.01:  # 스핀이 충분히 남아있을 때
        pass
        # 스핀에 의한 곡선 이동 (공의 횡방향 속도에 영향)
        spin_force = ball_spin_strength * ball_spin_direction * 3.5  # 커브율 증가
        ball_vel[0] += spin_force
        
        # 스핀 감소
        ball_spin_strength *= ball_spin_decay
        
        print(f"🌪️ 스핀 적용: strength={ball_spin_strength:.3f}, direction={ball_spin_direction}, force={spin_force:.2f}")
    else:
        pass
        # 스핀이 거의 없으면 완전히 제거
        ball_spin_strength = 0.0
        ball_spin_direction = 0
        # 드라이브 공 상태 비활성화 (자연스럽게 스핀이 끝난 경우)
        if drive_ball_active:
            drive_ball_active = False
            drive_hit_boss = False
            print("🌟 드라이브 효과가 자연스럽게 끝나서 원래 색상으로 복구됨!")

    # --- 🛡️ 무한 수평 왕복 방지 시스템 ---
    global horizontal_movement_timer, horizontal_threshold, max_horizontal_time, angle_correction_strength
    
    # Y속도가 매우 작으면 (거의 수평) 타이머 증가
    current_y_speed = abs(ball_vel[1] * ball_impact_boost)
    if current_y_speed < horizontal_threshold:
        horizontal_movement_timer += 1
        
        # 일정 시간 이상 수평 움직임이 지속되면 점진적으로 Y속도 보정
        if horizontal_movement_timer > max_horizontal_time:
            correction_factor = min(1.0, (horizontal_movement_timer - max_horizontal_time) / 60.0)  # 1초에 걸쳐 점진적 보정
            y_correction = angle_correction_strength * correction_factor
            
            # 공이 위쪽에 있으면 아래로, 아래쪽에 있으면 위로 보정
            if BALL.centery < HEIGHT // 2:
                pass
                ball_vel[1] += y_correction  # 아래쪽으로 보정
            else:
                ball_vel[1] -= y_correction  # 위쪽으로 보정
                
            if horizontal_movement_timer % 60 == 0:  # 1초마다 로그
                pass
                print(f"🛡️ 수평 움직임 보정 적용: timer={horizontal_movement_timer}, correction={y_correction:.3f}")
    else:
        pass
        # Y속도가 충분하면 타이머 리셋
        if horizontal_movement_timer > 0:
            print(f"🛡️ 수평 움직임 타이머 리셋: {horizontal_movement_timer} → 0")
            horizontal_movement_timer = 0

    # --- 공 이동 (현실적인 물리 부스트 적용) ---
    BALL.x += ball_vel[0] * ball_impact_boost
    BALL.y += ball_vel[1] * ball_impact_boost

    # --- 벽 충돌 처리 ---
    if BALL.left <= 0:
        BALL.left = 0
        ball_vel[0] *= -1
        SOUND_WALL.play()
        
        # 스테이지 1에서 벽 충돌 시 테두리 깜빡임 효과 활성화
        if current_stage == 1:
            border_flash_active = True
            border_flash_timer = border_flash_duration
            print(f"🔥 벽 충돌! 테두리 효과 활성화: stage={current_stage}, timer={border_flash_timer}")
        # 스테이지 2에서 벽 충돌 시 정글 테두리 효과 활성화
        elif current_stage == 2:
            print(f"🌿 DEBUG: Stage 2 벽 충돌 감지! current_stage={current_stage}")
            stage2_border_flash_timer = stage2_border_flash_duration
            
            # 공 속도 계산
            current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
            print(f"🌿 DEBUG: 공 속도={current_speed:.1f}, ball_vel=({ball_vel[0]:.1f}, {ball_vel[1]:.1f})")
            
            # 속도에 비례한 잎사귀 개수 계산 (느릴 때 1-2개, 빠를 때 5-6개)
            # 속도 범위: 대략 3(느림) ~ 25(빠름)
            min_leaves = 1
            max_leaves = 6
            # 속도를 0-1 범위로 정규화 (3-25 속도 범위 기준)
            speed_normalized = min(1.0, max(0.0, (current_speed - 3) / 22))
            # 잎사귀 개수 계산
            leaves_count = int(min_leaves + speed_normalized * (max_leaves - min_leaves))
            # 최소값과 최대값 범위 보장
            leaves_count = max(1, min(6, leaves_count))
            
            # 충돌 위치에서 디테일한 잎사귀 생성 (좌벽)
            leaf_types = ['maple', 'oak', 'tropical']
            for i in range(leaves_count):
                leaf = {
                    'x': 0,  # 좌벽
                    'y': BALL.centery + random.randint(-50, 50),
                    'vx': random.uniform(1.0, 3.0),  # 오른쪽으로 떨어짐
                    'vy': random.uniform(0.5, 2.5),
                    'rotation': random.uniform(0, 360),
                    'rotation_speed': random.uniform(-8, 8),
                    'type': random.choice(leaf_types),
                    'color': random.choice([
                        (34, 139, 34),  # 숲 녹색
                        (0, 128, 0),    # 중간 녹색  
                        (85, 107, 47),  # 올리브 녹색
                        (107, 142, 35), # 황록색
                        (154, 205, 50), # 연두색
                        (50, 100, 50),  # 진한 녹색
                    ]),
                    'size': random.randint(12, 25),
                    'life': 150  # 2.5초 동안 떨어짐
                }
                stage2_effects.stage2_leaves.append(leaf)
            print(f"🌿 정글 벽 충돌! 속도={current_speed:.1f}, 잎사귀={leaves_count}개, 전체={len(stage2_effects.stage2_leaves)}개")
        
        # 🌊 벽 충돌 시간 기록 (관성 보존용)
        last_wall_collision_time = pygame.time.get_ticks()
        if current_stage != 2:  # 스테이지 2가 아닐 때만 속도 재계산
            current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
        print(f"🧱 좌벽 충돌! 현재 속도: {current_speed:.1f}, 관성 보존 시작")
        
        # 충전가방 효과: 공이 벽에 닿을 때마다 플레이어 패들 충전량의 20% 충전
        if chargebag_obtained and not aipill_active:
            pass
            # 플레이어 패들이 공에 닿을 때 얻는 게이지량의 20% 계산
            base_gauge_gain = 80
            skill_gauge_boost = skill.apply_gauge_boost(0)
            total_gauge_gain = base_gauge_gain + skill_gauge_boost
            chargebag_gain = int(total_gauge_gain * 0.2)  # 20%
            
            print(f"🔍 DEBUG: 충전가방 효과 적용 시도 (게이지 증가: {chargebag_gain})")
            old_gauge = special_gauge
            # 🔧 동적 최대치 계산 적용
            current_max = get_max_gauge()
            special_gauge = min(current_max, special_gauge + chargebag_gain)
            print(f"충전가방 효과! 게이지 충전: {old_gauge} → {special_gauge} (+{chargebag_gain})")
            
    elif BALL.right >= WIDTH:
        BALL.right = WIDTH
        ball_vel[0] *= -1
        SOUND_WALL.play()
        
        # 스테이지 1에서 벽 충돌 시 테두리 깜빡임 효과 활성화
        if current_stage == 1:
            border_flash_active = True
            border_flash_timer = border_flash_duration
            print(f"🔥 벽 충돌! 테두리 효과 활성화: stage={current_stage}, timer={border_flash_timer}")
        # 스테이지 2에서 벽 충돌 시 정글 테두리 효과 활성화
        elif current_stage == 2:
            print(f"🌿 DEBUG: Stage 2 벽 충돌 감지! current_stage={current_stage}")
            stage2_border_flash_timer = stage2_border_flash_duration
            
            # 공 속도 계산
            current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
            print(f"🌿 DEBUG: 공 속도={current_speed:.1f}, ball_vel=({ball_vel[0]:.1f}, {ball_vel[1]:.1f})")
            
            # 속도에 비례한 잎사귀 개수 계산 (느릴 때 1-2개, 빠를 때 5-6개)
            # 속도 범위: 대략 3(느림) ~ 25(빠름)
            min_leaves = 1
            max_leaves = 6
            # 속도를 0-1 범위로 정규화 (3-25 속도 범위 기준)
            speed_normalized = min(1.0, max(0.0, (current_speed - 3) / 22))
            # 잎사귀 개수 계산
            leaves_count = int(min_leaves + speed_normalized * (max_leaves - min_leaves))
            # 최소값과 최대값 범위 보장
            leaves_count = max(1, min(6, leaves_count))
            
            # 충돌 위치에서 디테일한 잎사귀 생성 (우벽)
            leaf_types = ['maple', 'oak', 'tropical']
            for i in range(leaves_count):
                leaf = {
                    'x': WIDTH,  # 우벽
                    'y': BALL.centery + random.randint(-50, 50),
                    'vx': random.uniform(-3.0, -1.0),  # 왼쪽으로 떨어짐
                    'vy': random.uniform(0.5, 2.5),
                    'rotation': random.uniform(0, 360),
                    'rotation_speed': random.uniform(-8, 8),
                    'type': random.choice(leaf_types),
                    'color': random.choice([
                        (34, 139, 34),  # 숲 녹색
                        (0, 128, 0),    # 중간 녹색  
                        (85, 107, 47),  # 올리브 녹색
                        (107, 142, 35), # 황록색
                        (154, 205, 50), # 연두색
                        (50, 100, 50),  # 진한 녹색
                    ]),
                    'size': random.randint(12, 25),
                    'life': 150  # 2.5초 동안 떨어짐
                }
                stage2_effects.stage2_leaves.append(leaf)
            print(f"🌿 정글 벽 충돌! 속도={current_speed:.1f}, 잎사귀={leaves_count}개, 전체={len(stage2_effects.stage2_leaves)}개")
        
        # 🌊 벽 충돌 시간 기록 (관성 보존용)
        last_wall_collision_time = pygame.time.get_ticks()
        if current_stage != 2:  # 스테이지 2가 아닐 때만 속도 재계산
            current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
        print(f"🧱 우벽 충돌! 현재 속도: {current_speed:.1f}, 관성 보존 시작")
        
        # 충전가방 효과: 공이 벽에 닿을 때마다 플레이어 패들 충전량의 20% 충전
        if chargebag_obtained and not aipill_active:
            pass
            # 플레이어 패들이 공에 닿을 때 얻는 게이지량의 20% 계산
            base_gauge_gain = 80
            skill_gauge_boost = skill.apply_gauge_boost(0)
            total_gauge_gain = base_gauge_gain + skill_gauge_boost
            chargebag_gain = int(total_gauge_gain * 0.2)  # 20%
            
            print(f"🔍 DEBUG: 충전가방 효과 적용 시도 (게이지 증가: {chargebag_gain})")
            old_gauge = special_gauge
            # 🔧 동적 최대치 계산 적용
            current_max = get_max_gauge()
            special_gauge = min(current_max, special_gauge + chargebag_gain)
            print(f"충전가방 효과! 게이지 충전: {old_gauge} → {special_gauge} (+{chargebag_gain})")

    # --- 수평만 튕김 카운트 ---
    if abs(ball_vel[1]) < 1 and (BALL.left <= 0 or BALL.right >= WIDTH):
        pass
        horizontal_bounce_count += 1
    else:
        horizontal_bounce_count = 0

    # --- 무승부 처리 ---
    if horizontal_bounce_count >= 6:
        show_fade_text("무승부! 다시 대결!")
        reset_round()
        return

    # --- 천장 충돌 (플레이어 점수) ---
    if BALL.top <= 0:
        pass
        # 💪 체력형 보스전에서는 공이 보스 뒤로 나가지 않도록 바리케이트 적용
        if current_stage in boss_health_stages:
            pass
            # 🚫 스테이지 6에서 파워 스킬들이 벽에 맞으면 종료
            if current_stage == 6:
                pass
                # 드라이브 종료
                if drive_ball_active:
                    drive_ball_active = False
                    drive_hit_boss = False
                    drive_speed_increase = 0.0
                    ball_spin_strength = 0.0
                    ball_spin_direction = 0
                    print("🚫 스테이지 6: 드라이브가 벽에 맞아 종료됨!")
                
                # 파워스매싱 종료
                if power_smashing_parabola_active:
                    power_smashing_parabola_active = False
                    power_smashing_direction = None
                    power_smashing_trails.clear()
                    power_smashing_particles.clear()
                    print("🚫 스테이지 6: 파워스매싱이 벽에 맞아 종료됨!")
                
                # 고스트샷 종료
                if mega_smashing_active:
                    mega_smashing_active = False
                    mega_smashing_bonus_applied = False
                    mega_smashing_meteor_trail.clear()
                    print("🚫 스테이지 6: 고스트샷이 벽에 맞아 종료됨!")
            
            # 공을 경계에서 튕겨냄 (바리케이트 효과)
            BALL.top = 0
            ball_vel[1] = abs(ball_vel[1])  # 아래쪽으로 방향 전환
            
            # 바리케이트 충돌 이펙트 (텍스트 없이 파티클만)
            effects_manager.spawn_star_particles(BALL.centerx, 10, count=8)
            return
        
        # 🧠 AI 학습: 보스가 공을 놓쳤음 (제거됨)
        
        if deuce_mode:
            deuce_wins += 1
            show_winner_text("플레이어")
            show_score(SCREEN, deuce_wins, deuce_losses, WIDTH, HEIGHT, draw_field, draw_objects)
            # 스테이지 2에서 플레이어가 라운드 이길 때마다 악어 짧은 울상
            if current_stage == 2 and animated_bg_stage2:
                pass
                animated_bg_stage2.set_expression('sad')
        else:
            round_wins += 1
            # 🏗️ GameState 동기화 및 이벤트 발생
            game_state.round_wins = round_wins
            emit_event(EventType.ROUND_WIN, {'stage': current_stage, 'score': round_wins})
            show_winner_text("플레이어")
            show_score(SCREEN, round_wins, round_losses, WIDTH, HEIGHT, draw_field, draw_objects)
            # 스테이지 2에서 플레이어가 라운드 이길 때마다 악어 짧은 울상
            if current_stage == 2 and animated_bg_stage2:
                animated_bg_stage2.set_expression('sad')
        
        # 듀스 시스템 체크
        result = check_deuce_system()
        if result == "player_win":
            pass
            # 스테이지 2에서 플레이어 승리 시 악어 울상
            if current_stage == 2 and animated_bg_stage2:
                animated_bg_stage2.set_expression('sad')
            show_result(True)
            return
        elif result == "boss_win":
            pass
            # 스테이지 2에서 플레이어 패배 시 악어 활짝 웃기
            if current_stage == 2 and animated_bg_stage2:
                animated_bg_stage2.set_expression('happy')
            show_result(False)
            return
        elif result == "deuce_started" or result == "deuce_restart":
            pass
            # 듀스 시작/재시작 시 점수 표시 업데이트
            show_score(SCREEN, deuce_wins, deuce_losses, WIDTH, HEIGHT, draw_field, draw_objects)
        
        go_to_next_round()
        return

    # 🆕 벽돌 충돌 검사 (공이 벽돌 영역을 통과할 때)
    wall_hit = False
    for wall in walls:
        if BALL.colliderect(wall["rect"]):
            pass
            # 벽돌에 맞은 횟수 증가
            wall["hit_count"] += 1
            wall["crack_level"] = wall["hit_count"]
            
            # 공 튕기기
            ball_vel[1] = -abs(ball_vel[1])  # 위로 튕기기
            ball_vel[0] *= 0.8  # 좌우 속도 감소
            
            # 벽돌 파괴 효과음
            SOUND_WALL.play()
            
            print(f"벽돌에 맞음! ({wall['hit_count']}/2)")
            
            # 충전가방 효과: 공이 벽에 닿을 때마다 플레이어 패들 충전량의 20% 충전
            if chargebag_obtained and not aipill_active:
                pass
                # 플레이어 패들이 공에 닿을 때 얻는 게이지량의 20% 계산
                base_gauge_gain = 80
                skill_gauge_boost = skill.apply_gauge_boost(0)
                total_gauge_gain = base_gauge_gain + skill_gauge_boost
                chargebag_gain = int(total_gauge_gain * 0.2)  # 20%
                
                old_gauge = special_gauge
                # 🔧 동적 최대치 계산 적용
                current_max = get_max_gauge()
                special_gauge = min(current_max, special_gauge + chargebag_gain)
                print(f"충전가방 효과! 게이지 충전: {old_gauge} → {special_gauge} (+{chargebag_gain})")
            
            # 벽돌이 파괴되면 handle_wall에서 처리됨
            wall_hit = True
            break
    
    # 🗿 스테이지 2 위기 상황 바위 충돌 판정 (보스 실점 방지)
    rock_hit = False
    if current_stage == 2 and animated_bg_stage2 is not None:
        pass
        # 바위와 공 충돌 체크 (바위 파괴)
        if animated_bg_stage2.check_ball_rock_collision(BALL):
            pass
            # 공 반사
            ball_vel[0] = -ball_vel[0] * random.uniform(0.9, 1.1)
            ball_vel[1] = -ball_vel[1] * random.uniform(0.9, 1.1)
            rock_hit = True
            print(f"💥 바위 파괴! 공 반사!")
        else:
            pass
            # 기존 충돌 체크 (떨어지는 바위는 파괴 안됨)
            crisis_rocks = animated_bg_stage2.get_crisis_rocks()
            ball_rect = BALL
            
            for rock in crisis_rocks:
                if ball_rect.colliderect(rock['collision_rect']):
                    pass
                    # 벽돌과 같은 방식으로 공 반사
                    # 위쪽에서 충돌 시 위로 반사
                    if ball_vel[1] > 0:  # 아래로 가던 공
                        ball_vel[1] = -abs(ball_vel[1])  # 위로 반사
                        BALL.bottom = rock['collision_rect'].top - 1
                    else:  # 위로 가던 공
                        ball_vel[1] = abs(ball_vel[1])  # 아래로 반사
                        BALL.top = rock['collision_rect'].bottom + 1
                    
                    # 좌우 반사도 처리
                    if abs(BALL.centerx - rock['collision_rect'].centerx) > rock['collision_rect'].width // 3:
                        ball_vel[0] = -ball_vel[0]
                    
                    rock_hit = True
                    print(f"💎 위기 상황 바위 충돌! 보스 실점 방지!")
                    break
    
    # --- 바닥 충돌 (보스 점수) - 바위에 맞지 않았을 때만 ---
    if BALL.bottom >= HEIGHT and not rock_hit:
        pass
        # 🏆 플레이어 미스 기록 및 실수 분석 - 강화된 실수 감지
        ball_distance = abs(BALL.centery - PLAYER.centery)
        ball_speed = math.hypot(ball_vel[0], ball_vel[1])
        
        # 치명적 실수 판정 (더 엄격한 기준)
        if ball_speed < 10 and ball_distance < 120:  # 느리고 가까운 공을 놓침 (기준 완화로 더 많이 감지)
            pass
            record_critical_miss()
        elif ball_distance < 80:  # 가까운 공을 놓침 (기준 완화)
            pass
            record_missed_opportunity()
        elif ball_speed < 6:  # 매우 느린 공을 놓침 (새로 추가)
            record_critical_miss()
        
        # 연속 실수에 대한 추가 페널티
        if player_analyzer and player_analyzer.stats.current_miss_streak > 2:
            record_poor_timing_hit()  # 연속 실수시 나쁜 타이밍으로 기록
        
        # 일반 미스 기록
        try:
            if player_analyzer:
                pass
                player_analyzer.record_miss()
        except:
            pass
        
        # 벽돌이 없거나 벽돌을 맞지 않았으면 보스 점수
        if deuce_mode:
            deuce_losses += 1
            boss_name = boss_names.get(current_stage, "보스")
            show_winner_text(boss_name)
            show_score(SCREEN, deuce_wins, deuce_losses, WIDTH, HEIGHT, draw_field, draw_objects)
            # 스테이지 2에서 보스가 라운드 이길 때마다 악어 짧은 웃음
            if current_stage == 2 and animated_bg_stage2:
                pass
                animated_bg_stage2.set_expression('happy')
        else:
            round_losses += 1
            # 🏗️ GameState 동기화 및 이벤트 발생
            game_state.round_losses = round_losses
            emit_event(EventType.ROUND_LOSE, {'stage': current_stage, 'score': round_losses})
            boss_name = boss_names.get(current_stage, "보스")
            show_winner_text(boss_name)
            show_score(SCREEN, round_wins, round_losses, WIDTH, HEIGHT, draw_field, draw_objects)
            # 스테이지 2에서 보스가 라운드 이길 때마다 악어 짧은 웃음
            if current_stage == 2 and animated_bg_stage2:
                animated_bg_stage2.set_expression('happy')
        
        # 듀스 시스템 체크
        result = check_deuce_system()
        if result == "player_win":
            pass
            # 스테이지 2에서 플레이어 승리 시 악어 울상
            if current_stage == 2 and animated_bg_stage2:
                animated_bg_stage2.set_expression('sad')
            show_result(True)
            return
        elif result == "boss_win":
            pass
            # 스테이지 2에서 플레이어 패배 시 악어 활짝 웃기
            if current_stage == 2 and animated_bg_stage2:
                animated_bg_stage2.set_expression('happy')
            show_result(False)
            return
        elif result == "deuce_started" or result == "deuce_restart":
            pass
            # 듀스 시작/재시작 시 점수 표시 업데이트
            show_score(SCREEN, deuce_wins, deuce_losses, WIDTH, HEIGHT, draw_field, draw_objects)
        
        go_to_next_round()
        return

    # --- 공 속도 느려질 때 보정 (파워스매싱 활성화 시 면역) ---
    current_speed = math.hypot(ball_vel[0], ball_vel[1])
    if current_speed < BALL_BASE_SPEED * 0.85 and not special_active:  # 🚀 파워스매싱 중에는 보정 무시
        slow_ball_timer += 1
        if slow_ball_timer >= 180:
            direction = pygame.math.Vector2(ball_vel).normalize()
            ball_vel[0] = direction.x * BALL_BASE_SPEED
            ball_vel[1] = direction.y * BALL_BASE_SPEED
            slow_ball_timer = 0
    else:
        slow_ball_timer = 0

        # === Stage 3 눈물샤워 충돌 처리 ===
    if tear_shower_active and BALL.colliderect(PLAYER):
        player_stunned_timer = int(0.3 * FPS)
        player_knockback_vel = random.choice([-12, 12])
        # 🚀 성능 최적화: 파티클 개수를 절반으로 줄임 (12 → 6)
        for _ in range(6):
            angle = random.uniform(200, 340)
            speed = random.uniform(1.0, 3.0)
            vx = math.cos(math.radians(angle)) * speed
            vy = math.sin(math.radians(angle)) * speed
            tear_particles.append([
                PLAYER.centerx, PLAYER.top,
                vx, vy,
                255,                   # 알파
                random.randint(2, 4)   # 크기
            ])

    # --- 플레이어 충돌 ---
    # 공이 패들과 충돌하고, 공이 위로 올라가지 않는지 확인 (중복 충돌 방지)
    # 패들 끝부분 충돌도 처리하기 위해 Y속도 조건 완화
    # 측면 충돌도 허용하기 위해 Y속도 조건을 더 완화 (>= -10)
    # 충돌 쿨다운이 없고 handle_player에서 처리되지 않았을 때만 처리
    # 서브 대기 중에는 충돌 체크하지 않음
    # handle_player가 놓친 충돌 처리 (Y속도 조건 제거 - handle_player와 동일하게)
    if BALL.colliderect(PLAYER) and player_collision_cooldown <= 0 and not player_collision_handled and not is_waiting_for_serve:
        pass
        # 디버그: 충돌 위치 정보
        collision_x = BALL.centerx - PLAYER.centerx
        collision_side = "LEFT" if collision_x < 0 else "RIGHT"
        edge_distance = abs(collision_x) - (PADDLE_WIDTH / 2)
        print(f"🎯 handle_ball 충돌! (handle_player에서 놓친 충돌) 위치: {collision_side}, 중심거리: {collision_x:.1f}, 가장자리거리: {edge_distance:.1f}, Y속도: {ball_vel[1]:.1f}")
        
        # 🏗️ 충돌 이벤트 발생
        emit_event(EventType.BALL_HIT_PLAYER, {
            'collision_x': collision_x,
            'collision_side': collision_side,
            'ball_speed': (ball_vel[0], ball_vel[1])
        })
        
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
                
                # 🔧 고스트샷 종료 시 토큰 충전 타이머 초기화 (handle_ball에서도 처리)
                base_charges = 1
                holder_bonus = 1 if dashholder_obtained else 0
                amplification_bonus = academy.get_skill_bonus("dash_amplification")
                max_charges = int(base_charges + holder_bonus + amplification_bonus)
                
                print(f"[DEBUG] (handle_ball) 고스트샷 종료 - 현재 토큰: {rolling_charges}/{max_charges}, 타이머: {rolling_charge_timer}")
                
                # 토큰이 부족한 경우 무조건 충전 타이머 설정
                if rolling_charges < max_charges:
                    pass
                    # 경량화 스킬 효과 적용
                    lightweight_bonus = academy.get_skill_bonus("dash_lightweight")
                    charge_time_reduction = lightweight_bonus
                    base_charge_time = 90  # 1.5초
                    rolling_charge_timer = int(base_charge_time * (1 - charge_time_reduction))
                    print(f"💥 고스트샷 종료! (handle_ball) 토큰 충전 시작 (타이머: {rolling_charge_timer})")
                    print(f"[DEBUG] (handle_ball) 충전 타이머 강제 설정: {rolling_charge_timer}")
                else:
                    pass
                    print(f"💥 고스트샷 종료! (handle_ball) 토큰 이미 최대: {rolling_charges}/{max_charges}")
            else:
                print(f"🌟 고스트샷 궤적 진행 중 ({elapsed_time:.1f}/2.0초) - 패들 충돌 무시 (handle_ball)")
        if current_stage == 4 and boss_special_ready_stage4:
            stage4_magnetic_active = True
            stage4_magnetic_timer = 150
            boss_special_ready_stage4 = False
            boss_special_gauge_stage4 = 0
            show_speech("굴절자기장!", duration=90)

        if current_stage <= 5 and random.random() < boss_speed_config[current_stage]["fail_chance"]:
            boss_fail_timer = 60

        tear_chance = boss_speed_config[current_stage].get("tear_chance", 0.13) if current_stage <= 5 else 0.13
        if boss_fail_timer > 0:
            tear_chance = min(1.0, tear_chance + 0.3)

        time_now = pygame.time.get_ticks()
        if current_stage == 3:
            if time_now - last_tears_cast_time >= TEARS_COOLDOWN:
                if random.random() < tear_chance:
                    activate_tears_of_pain()
                    show_speech("눈물샤워!!", duration=90)
                    last_tears_cast_time = time_now

        calculate_bounce(PLAYER)  # handle_ball에서는 반환값 사용 안함 (게이지 처리가 handle_player에서 이미 됨)
        player_last_shot_speed = math.hypot(ball_vel[0], ball_vel[1])

        # 🎯 타격 이펙트 생성 (공 속도에 따라 강도 조절)
        create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=True)
        
        # 🆕 새로운 보스 모드에서 하단 보스의 스킬 발동 체크
        if new_boss_mode_active:
            print(f"🆕 handle_ball에서 새로운 보스 모드 하단 보스 스킬 체크! selected_bottom_boss={selected_bottom_boss}")  # 디버그
            if selected_bottom_boss == 1:
                print("🔥 파이어 나이트 스킬 호출!")
                handle_fire_knight_skills()  # 파이어 나이트 스킬
            elif selected_bottom_boss == 2:
                print("💨 윈드 스피릿 스킬 호출!")
                handle_wind_spirit_skills()  # 윈드 스피릿 스킬
        
        # 🌟 드라이브 공이 보스 패들에 맞고 다시 플레이어 패들에 맞으면 원래 색상으로 복구
        if drive_ball_active and drive_hit_boss:
            drive_ball_active = False
            drive_hit_boss = False
            drive_speed_increase = 0.0  # 🆕 드라이브 속도 증가량 리셋
            print("🌟 드라이브 공이 플레이어 패들에 재충돌하여 원래 색상으로 복구됨!")

        # handle_player에서 이미 사운드를 재생하므로 여기서는 재생하지 않음
        # handle_player에서 놓친 충돌의 경우에만 사운드 재생
        if not player_collision_handled and player_sound_cooldown <= 0:
            SOUND_PADDLE.play()
            player_sound_cooldown = 20  # 약 0.33초 쿨다운
            print("🔊 handle_ball에서 사운드 재생 (handle_player가 놓친 충돌)")
        
        hit_animation_active = True
        hit_animation_timer = HIT_ANIMATION_DURATION

        if ball_vel[0] != 0:
            direction = math.copysign(1, ball_vel[0])
            ball_angle += direction * 10

        ball_vel[0] *= 1.03
        ball_vel[1] *= 1.03

        # 🔹 handle_ball에서는 게이지 충전하지 않음 (handle_player에서만 처리)
        # handle_player에서 놓친 충돌의 경우에만 백업으로 게이지 충전
        global drive_just_activated
        print(f"🔍 DEBUG: handle_ball 충돌 감지 - handle_player가 놓친 충돌")
        
        # handle_player가 놓친 충돌에 대해서만 게이지 충전
        # 드라이브 발동 시에도 게이지 충전 차단
        if not aipill_active and not special_active and not rolling_active and player_collision_cooldown <= 0 and not drive_just_activated:
            pass
            # 스킬 효과 적용: 게이지 충전 증가
            base_gauge_gain = 80  # 사용자 요청에 따라 80으로 설정
            skill_gauge_boost = skill.apply_gauge_boost(0)
            total_gauge_gain = base_gauge_gain + skill_gauge_boost
            
            print(f"🔍 DEBUG: ✅ handle_ball에서 백업 게이지 충전 (handle_player가 놓친 충돌) ({total_gauge_gain})")
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
            # 충돌 쿨다운 설정
            player_collision_cooldown = 15
        else:
            print(f"🔍 DEBUG: ❌ handle_ball에서 게이지 충전 차단됨 (쿨다운: {player_collision_cooldown}, rolling: {rolling_active}, drive: {drive_just_activated})")
        
        if drive_just_activated:
            drive_just_activated = False  # 🆕 한 번 사용 후 리셋
        
        # 🔹 게이지 상태 실시간 업데이트 (게이지가 감소했을 때도 반영)
        if special_gauge < 350:  # 파워스매시 발동 조건
            special_ready = False

        # handle_player에서 이미 쿨다운을 설정했으므로 여기서는 설정하지 않음

        if whip_active:
            whip_hit_by_player = True

        # 🚀 handle_ball에서의 파워스매싱은 이미 handle_player에서 처리되므로 제거
        # (중복 발동 방지를 위해 주석 처리)

    # --- 보스 충돌 ---
    # 서브 대기 중에는 충돌 체크하지 않음
    global last_hit_by
    
    # 스테이지 6에서만 보스 히트박스를 2배로 확장 (항공모함 보스 특성)
    if current_stage == 6:
        pass
        # 항공모함 보스는 큰 함체를 가지므로 히트박스 확장
        boss_hitbox_expanded = pygame.Rect(
            BOSS.x - BOSS.width // 2,  # 왼쪽으로 절반 폭만큼 확장
            BOSS.y,  # y 위치는 그대로
            BOSS.width * 2,  # 너비를 2배로
            BOSS.height  # 높이는 그대로
        )
    else:
        pass
        # 다른 스테이지는 원래 크기 사용
        boss_hitbox_expanded = BOSS
    
        if boss_hitbox_expanded.colliderect(BALL) and boss_collision_cooldown <= 0 and not is_waiting_for_serve:
            pass
            # 🎆 파워스매싱 상태 확인 (보스 충돌 직전에)
            was_power_smashing = power_smashing_parabola_active

            # 💥 고스트샷 공과 충돌 시 처리
            if mega_smashing_active:
                pass
                # 보스 방어 횟수 증가
                mega_smashing_boss_defense_count += 1
                print(f"🐉 고스트샷 보스 방어! 고스트샷 종료!")
            
            # 🎯 고스트샷 방어 시 공속도 50% 감소
            ball_vel[0] *= 0.5
            ball_vel[1] *= 0.5
            print(f"⚡ 고스트샷 방어로 공속도 50% 감소! 현재 속도: ({ball_vel[0]:.1f}, {ball_vel[1]:.1f})")
            
            # 1번 방어 시 즉시 고스트샷 종료로 변경
            if mega_smashing_boss_defense_count >= 1:
                pass
                # 👻 귀신들 흩어짐 효과 발동
                if not mega_smashing_ghost_scatter and len(mega_smashing_ghosts) > 0:
                    mega_smashing_ghost_scatter = True
                    mega_smashing_ghost_scatter_time = pygame.time.get_ticks()
                    
                    # 각 귀신에게 무서운 속도로 흩어지는 방향 설정
                    for ghost in mega_smashing_ghosts:
                        # 보스 위치에서 귀신 위치로의 벡터 (반대 방향으로 튕김)
                        dx = ghost['x'] - BOSS.centerx
                        dy = ghost['y'] - BOSS.centery
                        distance = math.hypot(dx, dy)
                        if distance > 0:
                            dx /= distance
                            dy /= distance
                        else:
                            pass
                            # 랜덤 방향
                            angle = random.uniform(0, 2 * math.pi)
                            dx = math.cos(angle)
                            dy = math.sin(angle)
                        
                        # 무서운 속도로 흩어짐
                        scatter_speed = random.uniform(15, 25)
                        ghost['scatter_vx'] = dx * scatter_speed
                        ghost['scatter_vy'] = dy * scatter_speed
                    
                    print("👻 귀신들이 무서운 속도로 흩어짐!")
                
                # 고스트샷 종료 (보스가 2번 방어)
                mega_smashing_active = False
                mega_smashing_bonus_applied = False
                mega_smashing_meteor_trail.clear()
                mega_smashing_boss_defense_count = 0  # 카운터 리셋
                print("💥 고스트샷 종료! (보스가 방어 성공)")
            # 일반 충돌로 처리하기 위해 아래로 계속 진행
        
        # 일반 충돌 처리 (고스트샷도 종료 후 일반 충돌 처리)
        last_hit_by = "boss"  # 보스가 공을 쳤음을 기록
        calculate_bounce(BOSS)
        
        # 💪 체력형 보스 데미지 적용 (파워스매싱, 드라이브, 일반 공격)
        if current_stage in boss_health_stages:
            pass
            # 파워스매싱 상태 체크 (최우선)
            if was_power_smashing:
                damage = boss_damage_values["power"]  # 파워스매싱 데미지 (3)
                # 🚫 스테이지 6에서는 파워스매싱 종료
                if current_stage == 6:
                    power_smashing_parabola_active = False
                    power_smashing_direction = None
                    power_smashing_trails.clear()
                    power_smashing_particles.clear()
                    print("🚫 스테이지 6: 파워스매싱이 보스 패들에 맞아 종료됨!")
            # 드라이브 상태 체크
            elif drive_ball_active:
                damage = boss_damage_values["drive"]  # 드라이브 데미지 (2)
                # 🚫 스테이지 6에서는 드라이브 종료
                if current_stage == 6:
                    drive_ball_active = False
                    drive_hit_boss = False
                    drive_speed_increase = 0.0
                    ball_spin_strength = 0.0
                    ball_spin_direction = 0
                    print("🚫 스테이지 6: 드라이브가 보스 패들에 맞아 종료됨!")
            else:
                damage = boss_damage_values["basic"]  # 기본 공격 데미지 (1)
            
            boss_current_health = max(0, boss_current_health - damage)
            
            # 🎯 스테이지 6 보스 피격 효과 (소닉 스타일)
            if current_stage == 6:
                global stage6_boss_hit_timer, stage6_boss_hit_flash
                stage6_boss_hit_timer = 30  # 0.5초간 깜빡임 (60 FPS 기준)
                stage6_boss_hit_flash = True
                SOUND_STAGE6_BOSS_HIT.play()  # 피격 사운드 재생
                print(f"🎯 스테이지 6 보스 피격! 체력: {boss_current_health}/{boss_max_health}")
            
            # 💪 보스 체력이 0이 되면 즉시 승리
            if boss_current_health <= 0:
                print("🏆 체력형 보스 체력이 0! 플레이어 승리!")
                show_result(True)
                return
            
            # 🎯 타격 이펙트 생성 (공 속도에 따라 강도 조절)
            create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
            
            # 체력형 보스에서는 정지화면 없이 바로 다음 처리로 넘어감
            # 드라이브 효과 종료만 처리하고 나머지 스킬 등은 건너뜀
            if drive_ball_active:
                drive_ball_active = False
                drive_hit_boss = False
                print("🌟 체력형 보스: 드라이브 효과 종료")
            
            # 충돌 쿨다운 설정
            boss_collision_cooldown = 10
            return  # 체력형 보스에서는 여기서 종료하여 정지화면 방지
            
            # 🎯 타격 이펙트 생성 (공 속도에 따라 강도 조절)
            create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
        
        # 🌟 드라이브 효과 종료 (보스가 받아치면)
        if drive_ball_active:
            drive_ball_active = False
            drive_hit_boss = False
            print("🌟 드라이브 효과가 보스 충돌로 종료됨!")
        
        # 🧠 AI 학습: 보스가 공을 성공적으로 맞췄음 (제거됨)
        
        # 🌪️ 상모돌리기 발동 체크 (스테이지 1, 보스 충돌 시 12% 확률)
        if not new_boss_mode_active and current_stage == 1 and random.random() <= 0.12:
            activate_whip()
            show_speech("상모돌리기!!", duration=whip_duration)
        
        # 🆕 새로운 보스 모드에서 상단 보스의 스킬 발동 체크
        if new_boss_mode_active:
            print(f"🆕 handle_ball에서 새로운 보스 모드 상단 보스 스킬 체크! selected_top_boss={selected_top_boss}")  # 디버그
            if selected_top_boss == 1:
                print("⚡ 라이트닝 마스터 스킬 호출!")
                handle_lightning_master_skills()  # 라이트닝 마스터 스킬
            elif selected_top_boss == 2:
                print("🧊 아이스 퀸 스킬 호출!")
                handle_ice_queen_skills()  # 아이스 퀸 스킬
        
        # 🚀 가속화 스킬 효과 복원: 보스 패들이 맞받아칠 때 원래 속도의 -10%로 복원
        global acceleration_active, acceleration_original_speed
        if acceleration_active:
            pass
            # 원래 속도의 90% (10% 감소)로 복원
            restore_speed_x = acceleration_original_speed[0] * 0.9
            restore_speed_y = acceleration_original_speed[1] * 0.9
            
            # 방향 보정: 보스가 맞받아치므로 Y방향 반전
            ball_vel[0] = restore_speed_x
            ball_vel[1] = -abs(restore_speed_y)  # 위쪽으로 (음수)
            
            print(f"🚀 가속화 효과 복원! 원래 속도 {acceleration_original_speed} → 복원 속도 [{restore_speed_x:.2f}, {restore_speed_y:.2f}] (-10%)")
            
            # 가속화 효과 해제
            acceleration_active = False
            acceleration_original_speed = [0, 0]
        
        # 🌟 드라이브 공이 보스 패들에 닿으면 효과 50% 감소 + 드라이브 증가 공속의 90% 감소
        if drive_ball_active and not drive_hit_boss:
            drive_hit_boss = True
            ball_spin_strength *= 0.5  # 드라이브 효과 50% 감소
            
            # 🆕 드라이브로 증가한 공속의 90%를 감소시키는 새로운 메커니즘
            if drive_speed_increase > 0:
                pass
                # 현재 공속 계산
                current_speed = math.hypot(ball_vel[0], ball_vel[1])
                # 드라이브로 증가한 속도의 90%를 감소
                speed_reduction = drive_speed_increase * 0.9
                new_speed = max(1.0, current_speed - speed_reduction)  # 최소 속도 1.0 보장
                
                # 속도 비율 계산하여 ball_vel에 적용
                speed_ratio = new_speed / current_speed if current_speed > 0 else 1.0
                ball_vel[0] *= speed_ratio
                ball_vel[1] *= speed_ratio
                
                # 남은 드라이브 증가량 업데이트 (10%만 남김)
                drive_speed_increase *= 0.1
                
                print(f"🌟 드라이브 공이 보스 패들에 닿아 드라이브 증가 공속의 90% 감소!")
                print(f"   속도 감소: {current_speed:.2f} → {new_speed:.2f} (-{speed_reduction:.2f})")
                print(f"   남은 드라이브 증가량: {drive_speed_increase:.2f}")
            else:
                print("🌟 드라이브 공이 보스 패들에 닿았지만 추적된 증가 공속이 없음")
            
            # 🚨 드라이브 반격 속도 제한 시스템 (플레이어 대응 가능한 수준으로)
            current_speed_after = math.hypot(ball_vel[0], ball_vel[1])
            max_drive_counter_speed = 16.0  # 드라이브 반격 최대 속도 제한
            
            if current_speed_after > max_drive_counter_speed:
                speed_limit_ratio = max_drive_counter_speed / current_speed_after
                ball_vel[0] *= speed_limit_ratio
                ball_vel[1] *= speed_limit_ratio
                
                print(f"🚨 드라이브 반격 속도 제한 적용!")
                print(f"   제한 전: {current_speed_after:.2f} → 제한 후: {max_drive_counter_speed:.2f}")
                print(f"   플레이어 대응 가능한 수준으로 조정됨")
            
            # 🎯 추가 안전 장치: 플레이어 방향으로 향하는 빠른 공의 추가 감속
            if ball_vel[1] > 0:  # 플레이어 방향으로 향하는 공
                player_direction_speed = math.hypot(ball_vel[0], ball_vel[1])
                max_player_direction_speed = 14.0  # 플레이어 방향 최대 속도 더 엄격하게 제한
                
                if player_direction_speed > max_player_direction_speed:
                    safety_ratio = max_player_direction_speed / player_direction_speed
                    ball_vel[0] *= safety_ratio
                    ball_vel[1] *= safety_ratio
                    
                    print(f"🛡️ 플레이어 방향 안전 제한 적용!")
                    print(f"   {player_direction_speed:.2f} → {max_player_direction_speed:.2f}")
                    print(f"   대응 시간 확보를 위한 추가 감속")
        
        # 🌟 상모돌리기 중 플레이어가 공을 맞춘 후 보스 패들에 재충돌 시 상모돌리기 강제종료 + 속도 복구
        if whip_active and whip_hit_by_player:
            pass
            # 🔥 상모돌리기 강제종료
            whip_active = False
            whip_timer = 0
            whip_sound.stop()  # 상모돌리기 사운드 중지
            print("🌟 상모돌리기 강제종료! (플레이어 패들→보스 패들 충돌)")
            
            # 🔄 공속도 원래대로 복구
            ball_vel[0] = whip_original_ball_speed[0]
            ball_vel[1] = whip_original_ball_speed[1]
            whip_hit_by_player = False  # 상태 리셋
            print(f"🌟 상모돌리기 속도 복구! 복구된 속도: {whip_original_ball_speed}")
        
        # 감지센서용 보스 히트 타이머 설정 (무제한)
        boss_hit_timer = 999999
        
        # 충돌 쿨다운 설정
        boss_collision_cooldown = 10
        
        # 보스 패들 충돌 애니메이션 활성화
        global boss_hit_animation_active, boss_hit_animation_timer
        boss_hit_animation_active = True
        
        # 스테이지별 애니메이션 지속시간 조정
        if current_stage == 1:
            pass
            base_duration = 5  # 스테이지 1: 빠른 회복
        elif current_stage == 2:
            pass
            base_duration = 7  # 스테이지 2: 중간 회복
        elif current_stage == 3:
            pass
            base_duration = 8  # 스테이지 3: 느린 회복
        elif current_stage == 4:
            pass
            base_duration = 6  # 스테이지 4: 기본 회복
        elif current_stage == 5:
            pass
            base_duration = 9  # 스테이지 5: 가장 느린 회복
        else:
            base_duration = BOSS_HIT_ANIMATION_DURATION
            
        boss_hit_animation_timer = base_duration
        
            # 충돌 강도에 따른 애니메이션 강화 (공 속도 기반)
            ball_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
            if ball_speed > 8:  # 빠른 공일 때 더 강한 애니메이션
                boss_hit_animation_timer = base_duration + 2

            # 스테이지 2: 보스 패들이 공을 맞출 때 게이지 70 충전
            if current_stage == 2:
                boss_special_gauge = min(500, boss_special_gauge + 70)
                if boss_special_gauge >= 500:
                    boss_special_ready = True

            if current_stage == 5 and hongryun_ready:
                flame_trail_active = True
                flame_trail_timer = 120
                flame_trail_phase = 0
            flame_trail_positions.clear()
            
            show_hongryun_explosion()  # ⬅ 추가된 장면 연출

            # ✅ 발동 후 게이지 초기화
            hongryun_ready = False
            hongryun_hit_count = 0

        # 보스 충돌 사운드 재생
        if current_stage == 2 and speed_defense_active:
            pass
            SOUND_DEFENSE_HIT.play()
        else:
            SOUND_PADDLE.play()

        if ball_vel[0] != 0:
            direction = math.copysign(1, ball_vel[0])
            ball_angle += direction * 10

        # 🚀 파워스매싱 종료 및 감속 로직
        if was_power_smashing:
            pass
            # 파워스매싱 공을 보스가 받아쳤을 때: 플레이어가 대응 가능한 속도로 조정
            if power_smashing_original_speed > 0:
                pass
                # 원래 속도의 70%로 감속 (플레이어가 대응하기 쉽게)
                target_speed = power_smashing_original_speed * 0.7  
                current_speed = math.hypot(ball_vel[0], ball_vel[1])
                
                if current_speed > 0:
                    speed_ratio = target_speed / current_speed
                    ball_vel[0] *= speed_ratio
                    ball_vel[1] *= speed_ratio
                    print(f"🚀 파워스매싱 보스 반격! 원래속도: {power_smashing_original_speed:.2f} → 감속속도: {target_speed:.2f} (-30%)")
                else:
                    pass
                    # 공이 정지 상태라면 기본 속도의 70%로 설정
                    ball_vel[0] = BALL_BASE_SPEED * 0.7 * 0.7
                    ball_vel[1] = BALL_BASE_SPEED * 0.7 * 0.7
            else:
                pass
                # 기존 로직 (원래 속도 정보가 없는 경우) - 더 많이 감속
                ball_vel[0] /= 2.0  # 1.5 -> 2.0으로 변경 (더 많이 감속)
                ball_vel[1] /= 2.0
            
            # special_active 리셋
            special_active = False
            ball_trail.clear()
            power_smashing_original_speed = 0.0  # 원래 속도 정보 초기화
            
            # 🎯 포물선 궤적 시스템 즉시 비활성화
            power_smashing_parabola_active = False
            power_smashing_start_time = 0
            power_smashing_arc_strength = 0.0
            
            # 🎆 파워스매싱 이펙트 즉시 정리
            power_smashing_trails.clear()
            power_smashing_particles.clear()
            mega_smashing_meteor_trail.clear()
            mega_smashing_active = False
            
            print(f"🎆 파워스매싱 이펙트 해제됨! (보스 반격)")

        # --- 스테이지별 보스 스킬 ---
        # 🆕 새로운 보스 모드에서는 기존 보스 스킬 발동 비활성화 (중복 방지)
        if not new_boss_mode_active and current_stage == 1:
            pass
            # 상모돌리기는 이제 보스 패들 충돌 시에만 발동 (매 프레임 체크 제거)
            if random.random() <= 0.15 and not balloon_used_this_round:  # 풍선 스킬 확률 15%, 한 라운드에 한 번만
                pass
                activate_balloon()
        elif not new_boss_mode_active and current_stage == 2:
            time_now = pygame.time.get_ticks()
            if (time_now - quake_last_used_time >= QUAKE_COOLDOWN) and random.random() <= 0.15:
                activate_quake()
                show_speech("정글지진!", duration=quake_duration)
                quake_last_used_time = time_now
        elif not new_boss_mode_active and current_stage == 3:
            if not boss_special_ready:
                boss_special_gauge += 60
                if boss_special_gauge >= 500:
                    boss_special_gauge = 500
                    boss_special_ready = True
                    boss_special_waiting = True
                    boss_special_timer = pygame.time.get_ticks() + random.randint(700, 1500)
            target = 220 if boss_special_gauge >= 500 else (boss_special_gauge / 500) * 220
            if boss_red_intensity < target:
                pass
                boss_red_intensity += (target - boss_red_intensity) * 0.1
            else:
                boss_red_intensity -= (boss_red_intensity - target) * 0.1
            boss_red_intensity = min(220, max(0, boss_red_intensity))
            if boss_special_ready:
                show_fade_text("사이코볼!")
                activate_emotional_overdrive()
                boss_special_ready = False
                boss_special_gauge = 0
                boss_red_intensity = 0
        elif not new_boss_mode_active and current_stage == 4:
            if not meditation_active and random.random() <= 0.13:
                activate_meditation()
            if not stage4_magnetic_active:
                boss_special_gauge_stage4 += 90
                if boss_special_gauge_stage4 >= 300:
                    boss_special_gauge_stage4 = 300
                    boss_special_ready_stage4 = True
