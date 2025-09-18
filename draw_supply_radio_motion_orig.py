def draw_supply_radio_motion(screen):
    """무전기 모션 그리기 - 실제로 귀에 대고 통화하는 모습"""
    global supply_radio_motion, supply_radio_timer
    
    if not supply_radio_motion or supply_radio_timer <= 0:
        supply_radio_motion = False  # 확실히 비활성화
        return
    
    # 플레이어 위치
    player_x = PLAYER.centerx
    player_y = PLAYER.centery
    
    # === 캐릭터 상체 그리기 (무전기 들고 있는 자세) ===
    # 머리 (약간 오른쪽으로 기울임)
    head_x = player_x + 5
    head_y = player_y - 25
    head_color = (255, 220, 190)  # 피부색
    pygame.draw.circle(screen, head_color, (head_x, head_y), 12)
    
    # 헬멧 (군인 캐릭터)
    helmet_color = (70, 80, 60)  # 카키색
    pygame.draw.arc(screen, helmet_color, 
                   pygame.Rect(head_x - 14, head_y - 14, 28, 28), 
                   math.pi, 0, 8)
    pygame.draw.line(screen, helmet_color, 
                    (head_x - 14, head_y), 
                    (head_x + 14, head_y), 3)
    
    # 오른팔 (무전기를 들고 있는 팔)
    arm_color = (100, 110, 90)  # 군복색
    # 어깨에서 팔꿈치까지
    pygame.draw.line(screen, arm_color,
                    (player_x + 15, player_y - 10),  # 어깨
                    (player_x + 25, player_y - 5),   # 팔꿈치
                    5)
    # 팔꿈치에서 손목까지 (위로 올림)
    pygame.draw.line(screen, arm_color,
                    (player_x + 25, player_y - 5),   # 팔꿈치
                    (head_x + 18, head_y - 5),       # 손목 (귀 근처)
                    5)
    
    # 오른손 (무전기를 잡고 있음)
    hand_x = head_x + 18
    hand_y = head_y - 5
    pygame.draw.circle(screen, head_color, (hand_x, hand_y), 4)
    
    # === 무전기 (크고 디테일하게) ===
    radio_width = 16
    radio_height = 24
    radio_x = hand_x
    radio_y = hand_y
    
    # 무전기 본체 (군용 녹색)
    radio_color = (40, 50, 40)
    radio_rect = pygame.Rect(radio_x - radio_width//2, radio_y - radio_height//2, 
                           radio_width, radio_height)
    pygame.draw.rect(screen, radio_color, radio_rect)
    pygame.draw.rect(screen, (20, 30, 20), radio_rect, 2)  # 진한 테두리
    
    # 무전기 안테나 (길고 굵게)
    antenna_color = (140, 140, 140)
    antenna_base_x = radio_x
    antenna_base_y = radio_y - radio_height//2
    pygame.draw.line(screen, antenna_color, 
                    (antenna_base_x, antenna_base_y), 
                    (antenna_base_x - 2, antenna_base_y - 20), 3)
    # 안테나 끝 볼
    pygame.draw.circle(screen, antenna_color, 
                      (antenna_base_x - 2, antenna_base_y - 20), 2)
    
    # 무전기 스피커 그릴 (귀에 대는 부분)
    speaker_area = pygame.Rect(radio_x - 6, radio_y - radio_height//2 + 2, 12, 8)
    pygame.draw.rect(screen, (60, 60, 60), speaker_area)
    for i in range(4):
        y = radio_y - radio_height//2 + 3 + i * 2
        pygame.draw.line(screen, (80, 80, 80),
                        (radio_x - 5, y),
                        (radio_x + 5, y), 1)
    
    # 무전기 버튼과 다이얼
    # 메인 버튼 (PTT - Push To Talk)
    pygame.draw.circle(screen, (200, 50, 50), 
                      (radio_x, radio_y), 3)
    pygame.draw.circle(screen, (150, 30, 30), 
                      (radio_x, radio_y), 3, 1)
    
    # 볼륨 다이얼
    pygame.draw.circle(screen, (100, 100, 100), 
                      (radio_x - 4, radio_y + 6), 2)
    pygame.draw.circle(screen, (100, 100, 100), 
                      (radio_x + 4, radio_y + 6), 2)
    
    # LED 표시등 (송신 중)
    led_color = (0, 255, 0) if supply_radio_timer % 10 < 5 else (0, 150, 0)  # 깜빡임
    pygame.draw.circle(screen, led_color, 
                      (radio_x, radio_y - 8), 2)
    
    # === 무전 신호 효과 (전파) ===
    signal_alpha = int(255 * (supply_radio_timer / 30))  # 페이드 효과
    if signal_alpha > 0:
        # 무전기에서 나오는 전파
        signal_surface = pygame.Surface((120, 120), pygame.SRCALPHA)
        for i in range(4):
            radius = 20 + i * 15
            alpha = max(0, signal_alpha - i * 50)
            # 전파 색상 (녹색 계열)
            signal_color = (100, 255, 100, alpha)
            pygame.draw.circle(signal_surface, signal_color, (60, 60), radius, 3)
            
            # 전파 곡선 효과
            arc_rect = pygame.Rect(60 - radius, 60 - radius, radius * 2, radius * 2)
            pygame.draw.arc(signal_surface, signal_color, arc_rect, 
                          -math.pi/4, math.pi/4, 2)
        
        screen.blit(signal_surface, (radio_x - 60, radio_y - 60))
    
    # 대사 텍스트 (무전 내용)
    if supply_radio_timer > 20:
        text = "지원 요청!"
    elif supply_radio_timer > 10:
        text = "물자 투하!"
    else:
        text = "알았다!"
    
    # 말풍선 효과
    bubble_x = player_x - 30
    bubble_y = player_y - 50
    bubble_width = 60
    bubble_height = 20
    
    # 말풍선 배경
    bubble_color = (255, 255, 255, 200)
    bubble_surface = pygame.Surface((bubble_width, bubble_height), pygame.SRCALPHA)
    pygame.draw.rect(bubble_surface, bubble_color, 
                    (0, 0, bubble_width, bubble_height), border_radius=5)
    pygame.draw.rect(bubble_surface, (0, 0, 0), 
                    (0, 0, bubble_width, bubble_height), 2, border_radius=5)
    
    # 말풍선 꼬리
    tail_points = [
        (bubble_width//2 - 5, bubble_height),
        (bubble_width//2 + 5, bubble_height),
        (bubble_width//2 + 10, bubble_height + 8)
    ]
    pygame.draw.polygon(bubble_surface, bubble_color, tail_points)
    pygame.draw.lines(bubble_surface, (0, 0, 0), False, 
                     [(tail_points[0]), (tail_points[2]), (tail_points[1])], 2)
    
    screen.blit(bubble_surface, (bubble_x, bubble_y))
    
    # 텍스트 렌더링
    try:
        font = pygame.font.Font(None, 16)
        text_surface = font.render(text, True, (0, 0, 0))
        text_rect = text_surface.get_rect(center=(bubble_x + bubble_width//2, bubble_y + bubble_height//2))
        screen.blit(text_surface, text_rect)
    except:
        pass
    
    # 타이머 감소 (30프레임 = 0.5초 동안 유지)
    if supply_radio_timer > 0:
        supply_radio_timer -= 1
        if supply_radio_timer <= 0:
            supply_radio_motion = False
            print("📻 무전기 모션 완료")

