#!/usr/bin/env python3
"""
Phase 10: handle_ball 함수 분할
1,244줄의 거대 함수를 논리적인 작은 함수들로 분리
"""

def split_handle_ball():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # handle_ball 함수 시작 찾기
    handle_ball_start = 0
    for i, line in enumerate(lines):
        if line.strip() == 'def handle_ball():':
            handle_ball_start = i
            break
    
    print(f"handle_ball 함수 시작: {handle_ball_start+1}줄")
    
    # 새로운 함수들 생성
    new_functions = []
    
    # 1. 타이머 업데이트 함수
    new_functions.append("""
def update_ball_timers():
    \"\"\"공 관련 타이머들 업데이트\"\"\"
    global player_collision_cooldown, boss_collision_cooldown, player_sound_cooldown
    global boss_hit_timer, boss_fire_hit_timer, player_collision_handled
    
    # 충돌 쿨다운 감소
    if player_collision_cooldown > 0:
        player_collision_cooldown -= 1
    if boss_collision_cooldown > 0:
        boss_collision_cooldown -= 1
    if player_sound_cooldown > 0:
        player_sound_cooldown -= 1
    
    # 프레임 시작 시 충돌 플래그 리셋
    player_collision_handled = False
    
    # 위험감지센서용 보스 히트 타이머 감소
    if boss_hit_timer > 0:
        boss_hit_timer -= 1
    
    # 보스 화염 타격 타이머 감소
    if boss_fire_hit_timer > 0:
        boss_fire_hit_timer -= 1
""")
    
    # 2. Stage 4 자기장 처리
    new_functions.append("""
def handle_stage4_magnetic():
    \"\"\"Stage 4 자기장 효과 처리\"\"\"
    global stage4_magnetic_active, stage4_magnetic_timer, magnet_curve_angle
    global ball_vel, player_last_shot_speed
    
    if current_stage != 4 or not stage4_magnetic_active:
        return False
    
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
            direction = pygame.math.Vector2(0, 1)
        else:
            direction = direction.normalize()
        ball_vel = [direction.x * recover_speed, direction.y * recover_speed]
        magnet_curve_angle = 0
    
    return True
""")
    
    # 3. Stage 4 명상 처리
    new_functions.append("""
def handle_stage4_meditation():
    \"\"\"Stage 4 명상 효과 처리\"\"\"
    global meditation_active, meditation_timer, meditation_angle
    global ball_vel, ball_angle, drive_active, drive_spin_speed
    global player_last_shot_speed
    
    if current_stage != 4 or not meditation_active:
        return False
    
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
    
    return True
""")
    
    # 4. Stage 5 화염탄 처리
    new_functions.append("""
def handle_stage5_fireballs():
    \"\"\"Stage 5 화염탄 처리\"\"\"
    global fireballs, fireball_last_cast, fireball_cooldown, fireball_speed
    global boss_throwing, boss_throw_timer, hongryun_hit_count, hongryun_ready
    global player_stunned_timer, player_knockback_vel
    
    if current_stage != 5:
        return
    
    now = pygame.time.get_ticks()
    
    # 화염탄 발사
    if (now - fireball_last_cast > fireball_cooldown and 
        now - round_start_time >= 2500):
        fireball_last_cast = now
        fireball_cooldown = random.randint(3500, 5000)
        num_fireballs = random.randint(2, 3) if random.random() < 0.4 else 1
        
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
    
    # 화염탄 업데이트
    new_fireballs = []
    for pos, vel in fireballs:
        pos[0] += vel[0]
        pos[1] += vel[1]
        fireball_rect = pygame.Rect(pos[0]-8, pos[1]-8, 16, 16)
        
        if fireball_rect.colliderect(PLAYER):
            player_stunned_timer = int(0.3 * FPS)
            player_knockback_vel = random.choice([-18, 18])
            create_fireball_explosion(pos[0], pos[1])
            
            # 홍련 게이지 충전
            hongryun_hit_count += 1
            if hongryun_hit_count >= HONGRYUN_MAX_HITS:
                hongryun_ready = True
            continue
        
        if 0 <= pos[0] <= WIDTH and 0 <= pos[1] <= HEIGHT:
            new_fireballs.append([pos, vel])
    
    fireballs = new_fireballs
    update_fireball_explosion_particles()
""")
    
    # 5. 홍련폭염 처리
    new_functions.append("""
def handle_flame_trail():
    \"\"\"Stage 5 홍련폭염 (뱀 궤적) 처리\"\"\"
    global flame_trail_active, flame_trail_timer, flame_trail_phase
    global flame_trail_positions, flame_trail_start_time, flame_trail_base_vel
    global ball_vel
    
    if not flame_trail_active:
        return
    
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
    
    # 뱀 궤적 움직임 처리
    if elapsed < 1.0:
        # 차징 단계
        BALL.x += math.sin(elapsed * 25) * 2
        BALL.y += math.cos(elapsed * 25) * 2
    elif elapsed < 3.0:
        # 뱀 궤적 이동
        t = (elapsed - 1.0) / 2.0
        snake_amplitude = 40 * (1 - t)
        snake_frequency = 8
        
        perpendicular = pygame.math.Vector2(-flame_trail_base_vel.y, flame_trail_base_vel.x)
        snake_offset = perpendicular * math.sin(elapsed * snake_frequency) * snake_amplitude
        
        base_speed = BALL_BASE_SPEED * 1.5
        ball_vel[0] = flame_trail_base_vel.x * base_speed + snake_offset.x
        ball_vel[1] = flame_trail_base_vel.y * base_speed + snake_offset.y
    
    if flame_trail_timer <= 0:
        flame_trail_active = False
        flame_trail_phase = 0
        flame_trail_positions.clear()
        # 정상 속도로 복귀
        current_speed = math.hypot(ball_vel[0], ball_vel[1])
        if current_speed > 0:
            normal_speed = BALL_BASE_SPEED
            scale = normal_speed / current_speed
            ball_vel[0] *= scale
            ball_vel[1] *= scale
""")
    
    # 함수들을 handle_ball 바로 앞에 삽입
    lines_to_insert = []
    for func in new_functions:
        lines_to_insert.extend(func.strip().split('\n'))
        lines_to_insert.append('')  # 함수 간 빈 줄
    
    # handle_ball 함수 수정
    handle_ball_end = handle_ball_start + 1
    for i in range(handle_ball_start + 1, len(lines)):
        if lines[i].strip() and not lines[i][0].isspace():
            handle_ball_end = i
            break
    
    # 새로운 handle_ball 함수 생성
    new_handle_ball = ['def handle_ball():\n']
    new_handle_ball.append('    \"\"\"공 처리 메인 함수 - 리팩토링됨\"\"\"\n')
    
    # 글로벌 변수 선언들 유지 (필요한 것들만)
    for i in range(handle_ball_start + 1, handle_ball_start + 50):
        if i < len(lines) and 'global' in lines[i]:
            new_handle_ball.append(lines[i])
    
    new_handle_ball.append('\n')
    new_handle_ball.append('    special_gauge_max = get_max_gauge()\n')
    new_handle_ball.append('\n')
    new_handle_ball.append('    # 타이머 업데이트\n')
    new_handle_ball.append('    update_ball_timers()\n')
    new_handle_ball.append('\n')
    new_handle_ball.append('    # Stage별 특수 효과 처리\n')
    new_handle_ball.append('    if handle_stage4_magnetic():\n')
    new_handle_ball.append('        return\n')
    new_handle_ball.append('    if handle_stage4_meditation():\n')
    new_handle_ball.append('        return\n')
    new_handle_ball.append('\n')
    new_handle_ball.append('    # 서브 대기 상태 체크\n')
    new_handle_ball.append('    if is_waiting_for_serve:\n')
    new_handle_ball.append('        if is_player_serve:\n')
    new_handle_ball.append('            BALL.centerx = PLAYER.centerx\n')
    new_handle_ball.append('            BALL.bottom = PLAYER.top - 5\n')
    new_handle_ball.append('        else:\n')
    new_handle_ball.append('            BALL.centerx = BOSS.centerx\n')
    new_handle_ball.append('            BALL.top = BOSS.bottom + 5\n')
    new_handle_ball.append('        return\n')
    new_handle_ball.append('\n')
    new_handle_ball.append('    # Stage 5 특수 효과\n')
    new_handle_ball.append('    handle_stage5_fireballs()\n')
    new_handle_ball.append('    handle_flame_trail()\n')
    new_handle_ball.append('\n')
    
    # 나머지 handle_ball 내용 추가 (중복 제거)
    skip_until = 0
    for i in range(handle_ball_start + 50, handle_ball_end):
        line = lines[i]
        
        # 이미 분리한 부분은 건너뛰기
        if skip_until > i:
            continue
            
        if 'if current_stage == 4 and stage4_magnetic_active:' in line:
            # Stage 4 자기장 부분 건너뛰기
            skip_until = i + 50
            continue
        elif 'if current_stage == 4 and meditation_active:' in line:
            # Stage 4 명상 부분 건너뛰기
            skip_until = i + 30
            continue
        elif 'if current_stage == 5:' in line and 'fireball' in lines[i+2]:
            # Stage 5 화염탄 부분 건너뛰기
            skip_until = i + 100
            continue
        elif 'if flame_trail_active:' in line:
            # 홍련폭염 부분 건너뛰기
            skip_until = i + 80
            continue
        elif 'if player_collision_cooldown > 0:' in line:
            # 타이머 업데이트 부분 건너뛰기
            skip_until = i + 10
            continue
        else:
            new_handle_ball.append(line)
    
    # 파일 쓰기
    new_lines = []
    new_lines.extend(lines[:handle_ball_start])
    new_lines.extend([line + '\n' if not line.endswith('\n') else line for line in lines_to_insert])
    new_lines.extend(new_handle_ball)
    new_lines.extend(lines[handle_ball_end:])
    
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print(f"✅ handle_ball 함수 분할 완료!")
    print(f"   - 5개의 새로운 함수 생성")
    print(f"   - 예상 코드 감소: ~200줄")

if __name__ == "__main__":
    split_handle_ball()