def show_drive_monitor_demo(background):
    """드라이브 모니터 표시 시범"""
    clock = pygame.time.Clock()
    
    # 폰트 설정 (챕터2와 동일)
    font_medium = FontStyle.body()    # 24pt 대사용
    font_small = FontStyle.small()    # 18pt 안내용
    BOSS_COLOR = (255, 100, 100)  # 조교 텍스트 색상
    CYAN = (0, 255, 255)  # 안내 텍스트 색상
    
    # 색상 그라데이션 설정
    gradient_colors = [
        (255, 255, 100),  # 노란색
        (255, 200, 100),  # 주황색
        (255, 150, 200),  # 핑크
        (200, 150, 255),  # 보라색
        (150, 200, 255),  # 하늘색
        (100, 255, 200),  # 민트색
    ]
    color_change_duration = 2000  # 2초마다 색상 변경
    
    # 데모용 매개변수 - 실제 게임과 동일한 조건
    boss_x = WIDTH // 2
    boss_y = 120  # 챕터2와 동일한 높이
    
    # 조교 이미지 미리 로드 (중복 방지)
    try:
        boss_img_path = resource_path("boss_tutorial.png")
        boss_img = pygame.image.load(boss_img_path).convert_alpha()
        boss_img = pygame.transform.scale(boss_img, (80, 100))
    except:
        boss_img = None
    
    # 공 시작/타겟 위치
    ball_start_y = HEIGHT - 150  # 플레이어 높이 근처에서 시작
    ball_target_x = boss_x
    ball_target_y = boss_y + 80  # 보스 패들 아래쪽
    
    # 챕터2 스타일 - 스페이스바를 누를 때까지 계속 반복
    demo_complete = False
    demo_start_time = pygame.time.get_ticks()
    cycle_duration = 3000  # 3초 주기로 왼쪽/오른쪽 전환
    drive_text_timer = 0  # DRIVE! 텍스트 표시 타이머
    drive_text_duration = 2000  # 2초 동안 표시
    
    while not demo_complete:
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE:
                    # 스페이스바를 누르면 데모 종료
                    return
        
        current_time = pygame.time.get_ticks()
        elapsed = current_time - demo_start_time
        
        # 3초 주기로 왼쪽/오른쪽 전환 (챕터2 방식)
        cycle_phase = (elapsed // 1500) % 4  # 0:왼쪽, 1:대기, 2:오른쪽, 3:대기
        
        # 챕터2 스타일: 실제 게임 필드 표시
        SCREEN.fill((20, 30, 60))  # 어두운 파란 배경
        
        # 중앙선 그리기
        pygame.draw.line(SCREEN, (100, 100, 100), (0, HEIGHT // 2), (WIDTH, HEIGHT // 2), 2)
        
        # 중앙 원 그리기
        pygame.draw.circle(SCREEN, (100, 100, 100), (WIDTH // 2, HEIGHT // 2), 80, 2)
        
        # 공 위치 계산
        if cycle_phase == 0 or cycle_phase == 2:
            # 공이 접근하는 애니메이션
            phase_elapsed = elapsed % 1500
            progress = phase_elapsed / 1500.0
            smooth_progress = progress ** 0.8  # 처음에는 느리고 점점 빨라짐
            
            # 현재 cycle에 따른 공 위치 설정
            if cycle_phase == 0:  # 왼쪽에서 접근
                ball_start_x = boss_x - 300
                ball_x = ball_start_x + (ball_target_x - ball_start_x) * smooth_progress
            else:  # 오른쪽에서 접근
                ball_start_x = boss_x + 300
                ball_x = ball_start_x - (ball_start_x - ball_target_x) * smooth_progress
            
            # Y 축은 포물선 궤적으로
            arc_height = -50  # 포물선 높이
            ball_y = ball_start_y + (ball_target_y - ball_start_y) * smooth_progress
            ball_y += arc_height * 4 * smooth_progress * (1 - smooth_progress)  # 포물선 공식
        else:
            # 대기 상태에서는 공을 숨김
            ball_x = -100
            ball_y = -100
            progress = 0
        
        # 조교(보스) 그리기 - 단일 인스턴스 보장
        if boss_img:
            boss_rect = boss_img.get_rect(center=(boss_x, boss_y))
            SCREEN.blit(boss_img, boss_rect)
        else:
            # 조교 기본 모양 - 더 생동감 있게
            # 몸통
            body_color = (180, 90, 90)
            pygame.draw.ellipse(SCREEN, body_color, (boss_x - 35, boss_y - 40, 70, 85))
            # 패들 (핑퐁을 들고 있는 모습)
            paddle_color = (100, 50, 50)
            pygame.draw.rect(SCREEN, paddle_color, (boss_x - 45, boss_y - 10, 90, 15), border_radius=3)
            # 얼굴
            pygame.draw.circle(SCREEN, (230, 180, 180), (boss_x, boss_y - 20), 22)  # 얼굴
            # 눈
            pygame.draw.circle(SCREEN, (0, 0, 0), (boss_x - 7, boss_y - 25), 3)  # 왼쪽 눈
            pygame.draw.circle(SCREEN, (0, 0, 0), (boss_x + 7, boss_y - 25), 3)  # 오른쪽 눈
            # 입 (집중하는 표정)
            import math
            pygame.draw.arc(SCREEN, (0, 0, 0), (boss_x - 8, boss_y - 18, 16, 10), 0, math.pi, 2)
        
        # 공 그리기 (공이 접근할 때만)
        if cycle_phase == 0 or cycle_phase == 2:
            # 공 속도에 따른 잔상 효과 (실제 게임처럼)
            ball_color = (255, 200, 0)  # 노란색 공
            ball_radius = 8  # 실제 게임 공 크기
            
            if progress > 0.1:  # 초반에는 잔상 없음
                for i in range(3):
                    trail_alpha = 100 - i * 30
                    trail_offset = i * 15
                    trail_x = ball_x - (ball_x - ball_start_x) * (trail_offset / 300)
                    trail_y = ball_y - (ball_y - ball_start_y) * (trail_offset / 300)
                    trail_surface = pygame.Surface((ball_radius * 3, ball_radius * 3), pygame.SRCALPHA)
                    pygame.draw.circle(trail_surface, (*ball_color, trail_alpha), 
                                     (ball_radius * 1.5, ball_radius * 1.5), ball_radius)
                    SCREEN.blit(trail_surface, (int(trail_x - ball_radius * 1.5), int(trail_y - ball_radius * 1.5)))
            
            # 메인 공
            pygame.draw.circle(SCREEN, (255, 255, 150), (int(ball_x), int(ball_y)), ball_radius + 2)  # 외곽 글로우
            pygame.draw.circle(SCREEN, ball_color, (int(ball_x), int(ball_y)), ball_radius)  # 메인 공
            pygame.draw.circle(SCREEN, (255, 255, 255), (int(ball_x - 2), int(ball_y - 2)), 2)  # 하이라이트
            
            # 드라이브 모니터 원 그리기 - 실제 게임처럼 거리에 따라 투명도 조절
            distance = ((ball_x - boss_x) ** 2 + (ball_y - boss_y) ** 2) ** 0.5
            drive_range = 70  # 실제 게임 드라이브 가능 범위 (크기 감소)
            
            # 드라이브 범위에 가까워지면 표시
            if distance < drive_range * 2:  # 드라이브 범위의 2배 내에서부터 표시 시작
                # 드라이브 가능 영역 표시 - 단일 원
                if distance < drive_range:
                    # 범위 내에서 강한 표시
                    alpha = int(200 + 55 * (1 - distance / drive_range))  # 거리에 따른 투명도
                else:
                    # 범위 밖이지만 가까이 있을 때 희미하게 표시 (페이드 아웃)
                    fade_distance = distance - drive_range
                    max_fade = drive_range  # 페이드 아웃 거리
                    if fade_distance < max_fade:
                        alpha = int(100 * (1 - fade_distance / max_fade))
                    else:
                        alpha = 0
                
                # 단일 드라이브 모니터 원 (실제 게임과 동일)
                if alpha > 0:
                    # 더 큰 서페이스로 원을 그림
                    circle_surface = pygame.Surface((drive_range * 2 + 10, drive_range * 2 + 10), pygame.SRCALPHA)
                    pygame.draw.circle(circle_surface, (0, 255, 255, min(255, alpha)), 
                                     (drive_range + 5, drive_range + 5), drive_range, 3)
                    # 내부 원 추가 (더 선명한 표시)
                    if distance < drive_range:
                        pygame.draw.circle(circle_surface, (0, 255, 255, min(100, alpha // 2)), 
                                         (drive_range + 5, drive_range + 5), drive_range - 3, 1)
                    SCREEN.blit(circle_surface, (boss_x - drive_range - 5, boss_y - drive_range - 5))
                
                # 공이 드라이브 범위에 들어오면 DRIVE! 표시
                if distance < drive_range:
                    # 드라이브 텍스트 - 게임적인 폰트와 효과
                    font = FontStyle.body()
                    # 텍스트 크기 변화 (펄싱 효과)
                    pulse = abs(math.sin(elapsed * 0.005)) * 0.3 + 0.7
                    text_color = (0, int(255 * pulse), int(255 * pulse))
                    drive_text = font.render("DRIVE!", True, text_color)
                    text_rect = drive_text.get_rect(center=(boss_x, boss_y - 60))
                    SCREEN.blit(drive_text, text_rect)
                # 공이 범위를 벗어나도 잠시 더 표시 (페이드 아웃)
                elif distance < drive_range * 1.5:
                    # 드라이브 텍스트 - 페이드 아웃 효과
                    font = FontStyle.body()
                    pulse = abs(math.sin(elapsed * 0.005)) * 0.3 + 0.7
                    fade = 1.0 - (distance - drive_range) / (drive_range * 0.5)
                    text_color = (0, int(255 * pulse * fade), int(255 * pulse * fade))
                    drive_text = font.render("DRIVE!", True, text_color)
                    text_rect = drive_text.get_rect(center=(boss_x, boss_y - 60))
                    SCREEN.blit(drive_text, text_rect)
                
                    # 타이밍 인디케이터 - 더 세련된 UI
                    timing_progress = 1.0 - (distance / drive_range)
                    bar_width = 60  # 더 작은 크기
                    bar_height = 6
                    bar_x = boss_x - bar_width // 2
                    bar_y = boss_y - 85
                    
                    # 배경 바 (둥근 모서리)
                    bar_surface = pygame.Surface((bar_width + 4, bar_height + 4), pygame.SRCALPHA)
                    pygame.draw.rect(bar_surface, (30, 30, 30, 200), (0, 0, bar_width + 4, bar_height + 4), border_radius=3)
                    pygame.draw.rect(bar_surface, (100, 100, 100, 150), (0, 0, bar_width + 4, bar_height + 4), 1, border_radius=3)
                    SCREEN.blit(bar_surface, (bar_x - 2, bar_y - 2))
                    
                    # 진행 바 (그라디언트 효과)
                    if timing_progress > 0:
                        progress_width = int(bar_width * timing_progress)
                        progress_surface = pygame.Surface((progress_width, bar_height), pygame.SRCALPHA)
                        for x in range(progress_width):
                            gradient_alpha = int(200 + 55 * (x / bar_width))
                            gradient_color = (0, 200 + int(55 * (x / bar_width)), 200 + int(55 * (x / bar_width)), gradient_alpha)
                            pygame.draw.line(progress_surface, gradient_color, (x, 0), (x, bar_height))
                        SCREEN.blit(progress_surface, (bar_x, bar_y))
        
        # 챕터2 스타일 텍스트 배경 (항상 표시)
        text_bg_height = 80
        text_bg = pygame.Surface((WIDTH, text_bg_height), pygame.SRCALPHA)
        text_bg.fill((0, 0, 0, 180))
        text_y_position = HEIGHT - 150
        SCREEN.blit(text_bg, (0, text_y_position))
        
        # 시범 안내 텍스트 - 항상 동일한 텍스트 표시
        display_text = "[조교] 드라이브 모니터가 표시가 된다."
        
        # 현재 시간 가져오기
        current_time = pygame.time.get_ticks()
        
        # 색상 계산 (그라데이션)
        color_time = current_time % (color_change_duration * len(gradient_colors))
        color_index = int(color_time / color_change_duration)
        next_color_index = (color_index + 1) % len(gradient_colors)
        
        # 현재 색상과 다음 색상 사이의 보간값 계산
        transition_progress = (color_time % color_change_duration) / color_change_duration
        
        # 부드러운 전환을 위한 사인 함수 적용
        smooth_progress = (math.sin((transition_progress - 0.5) * math.pi) + 1) / 2
        
        # 색상 보간
        current_color = gradient_colors[color_index]
        next_color = gradient_colors[next_color_index]
        
        interpolated_color = (
            int(current_color[0] + (next_color[0] - current_color[0]) * smooth_progress),
            int(current_color[1] + (next_color[1] - current_color[1]) * smooth_progress),
            int(current_color[2] + (next_color[2] - current_color[2]) * smooth_progress)
        )
        
        # 텍스트 렌더링 (그라데이션 색상 적용)
        text_surface = font_medium.render(display_text, True, interpolated_color)
        text_rect = text_surface.get_rect(center=(WIDTH // 2, text_y_position + text_bg_height // 2))
        
        # 텍스트 그림자 효과
        shadow_surface = font_medium.render(display_text, True, (0, 0, 0))
        shadow_rect = text_rect.copy()
        shadow_rect.x += 2
        shadow_rect.y += 2
        SCREEN.blit(shadow_surface, shadow_rect)
        
        # 실제 텍스트
        SCREEN.blit(text_surface, text_rect)
        
        # 스페이스바 안내 (화면 하단에 표시)
        instruction = "SPACE - 계속"
        inst_surface = font_small.render(instruction, True, CYAN)
        inst_rect = inst_surface.get_rect(bottomright=(WIDTH - 20, HEIGHT - 20))
        
        # 깜빡임 효과
        if pygame.time.get_ticks() % 1000 < 500:
            SCREEN.blit(inst_surface, inst_rect)
        
        pygame.display.flip()
        clock.tick(60)