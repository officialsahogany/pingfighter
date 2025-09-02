"""
draw_aircraft_carrier_boss 함수 - bosspong.py에서 추출
"""

import pygame
import math
import random

def draw_aircraft_carrier_boss(boss_speed=0, boss_x=0):
    """⚔️ 스테이지 6 울트라 배틀크루저 - 최강의 전함 보스 패들"""
    import random
    global laser_cannon_angle, laser_charging, laser_cannon_active, laser_charge_start
    global shield_antenna_active, stage6_boss_hit_timer, stage6_boss_hit_flash
    
    # 🎯 소닉 스타일 피격 효과 타이머 업데이트
    if stage6_boss_hit_timer > 0:
        stage6_boss_hit_timer -= 1
        # 깜빡임 효과 (매 4프레임마다 on/off)
        stage6_boss_hit_flash = (stage6_boss_hit_timer // 4) % 2 == 0
        if stage6_boss_hit_timer <= 0:
            stage6_boss_hit_flash = False
    
    carrier_width = 220
    carrier_height = 85
    
    # 배틀크루저 표면 생성
    carrier_surface = pygame.Surface((carrier_width, carrier_height), pygame.SRCALPHA)
    
    # 체력에 따른 손상 정도 계산
    damage_ratio = 1.0 - (boss_current_health / boss_max_health)
    time_now = pygame.time.get_ticks()
    
    # 🌟 체력 기반 에너지 쉴드 효과 (제거)
    # 파란색 테두리가 나타나지 않도록 주석 처리
    # if boss_current_health > 10:
    #     # 외곽 에너지 쉴드 (체력이 높을수록 강함)
    #     shield_alpha = int(20 + (boss_current_health / boss_max_health) * 30)
    #     shield_color = (100, 150, 255, shield_alpha)
    #     for i in range(3):
    #         pygame.draw.rect(carrier_surface, shield_color, 
    #                        (3-i, 3-i, carrier_width-6+i*2, carrier_height-6+i*2), 1)
    
    # === 메인 선체 (5단계 레이어드 구조로 입체감 강화) ===
    # 🎯 소닉 스타일 피격 효과 적용 (붉은색 오버레이)
    def apply_hit_effect(color):
        if stage6_boss_hit_flash:
            pass
            # 붉은색으로 강하게 변환 (소닉 스타일)
            r, g, b = color
            return (min(255, r + 120), max(0, g - 30), max(0, b - 30))
        return color
    
    # 최하부 그림자 레이어
    shadow_color = apply_hit_effect((35, 40, 45))
    pygame.draw.rect(carrier_surface, shadow_color, (6, 48, carrier_width-12, 34))
    
    # 하부 선체 (진한 금속색 + 그라데이션 효과)
    hull_base_color = apply_hit_effect((65, 75, 85) if damage_ratio < 0.7 else (55, 60, 70))
    pygame.draw.rect(carrier_surface, hull_base_color, (8, 45, carrier_width-16, 32))
    # 하부 하이라이트
    pygame.draw.line(carrier_surface, apply_hit_effect((75, 85, 95)), (8, 46), (carrier_width-8, 46), 1)
    
    # 중하부 전환 레이어
    trans_color = apply_hit_effect((72, 82, 95) if damage_ratio < 0.6 else (62, 70, 78))
    pygame.draw.rect(carrier_surface, trans_color, (10, 40, carrier_width-20, 28))
    
    # 중부 선체 (조금 밝은 색)
    hull_mid_color = apply_hit_effect((80, 90, 105) if damage_ratio < 0.5 else (70, 75, 85))
    pygame.draw.rect(carrier_surface, hull_mid_color, (12, 35, carrier_width-24, 25))
    # 중부 하이라이트
    pygame.draw.line(carrier_surface, apply_hit_effect((90, 100, 115)), (12, 36), (carrier_width-12, 36), 1)
    
    # 상부 선체 (가장 밝은 색 + 메탈릭 효과)
    hull_top_color = apply_hit_effect((95, 110, 125) if damage_ratio < 0.3 else (85, 95, 110))
    pygame.draw.rect(carrier_surface, hull_top_color, (16, 25, carrier_width-32, 20))
    # 상부 메탈릭 하이라이트
    pygame.draw.line(carrier_surface, (115, 130, 145), (16, 26), (carrier_width-16, 26), 1)
    pygame.draw.line(carrier_surface, (105, 120, 135), (16, 28), (carrier_width-16, 28), 1)
    
    # === 배틀크루저 특유의 고급 장갑판 시스템 ===
    # 반응형 장갑판 패널들 (체력에 따라 색상 변화)
    panel_base = (110, 125, 140) if boss_current_health > 10 else (90, 100, 115)
    panel_glow = (130, 160, 200) if boss_current_health > 12 else (110, 135, 160)
    
    for i in range(8):  # 더 많은 패널
        panel_x = 15 + i * 25
        if panel_x < carrier_width - 35:
            pass
            # 패널 외곽 (3D 효과)
            pygame.draw.rect(carrier_surface, (70, 80, 90), (panel_x-1, 27, 23, 17))
            pygame.draw.rect(carrier_surface, panel_base, (panel_x, 28, 21, 15))
            pygame.draw.rect(carrier_surface, panel_glow, (panel_x, 28, 21, 15), 1)
            
            # 패널 내부 고급 디테일
            # 에너지 라인 (펄스 효과)
            pulse = abs(math.sin(time_now * 0.003 + i * 0.5))
            line_color = (int(120 + pulse * 30), int(130 + pulse * 40), int(145 + pulse * 50))
            pygame.draw.line(carrier_surface, line_color, 
                           (panel_x + 2, 30), (panel_x + 19, 30), 1)
            pygame.draw.line(carrier_surface, line_color, 
                           (panel_x + 2, 35), (panel_x + 19, 35), 1)
            pygame.draw.line(carrier_surface, line_color, 
                           (panel_x + 2, 40), (panel_x + 19, 40), 1)
            
            # 중앙 에너지 코어
            core_x = panel_x + 10
            core_y = 35
            pygame.draw.circle(carrier_surface, panel_glow, (core_x, core_y), 2)
            if boss_current_health > 8:
                pygame.draw.circle(carrier_surface, (180, 210, 255), (core_x, core_y), 1)
    
    # === 추가 몸통 디테일 ===
    # 구조적 리벳 라인들
    rivet_color = (130, 140, 155)
    # 수평 구조 라인들
    for y_pos in [30, 40, 50, 60]:
        pygame.draw.line(carrier_surface, rivet_color, 
                        (15, y_pos), (carrier_width - 15, y_pos), 1)
        # 리벳 포인트들
        for x_pos in range(25, carrier_width - 20, 20):
            pygame.draw.circle(carrier_surface, rivet_color, (x_pos, y_pos), 1)
    
    # 수직 구조 라인들
    for x_pos in range(30, carrier_width - 30, 35):
        pygame.draw.line(carrier_surface, rivet_color, 
                        (x_pos, 28), (x_pos, 65), 1)
    
    # 장갑판 섹션 구분선
    section_color = (100, 115, 130)
    section_positions = [50, 90, 130, 170]
    for sect_x in section_positions:
        if sect_x < carrier_width - 20:
            pygame.draw.line(carrier_surface, section_color, 
                           (sect_x, 25), (sect_x, 70), 2)
            # 섹션 하이라이트
            pygame.draw.line(carrier_surface, (140, 150, 165), 
                           (sect_x + 1, 25), (sect_x + 1, 70), 1)
    
    # 웨폰 하드포인트 마운트
    hardpoint_positions = [(40, 45), (80, 45), (120, 45), (160, 45)]
    for hx, hy in hardpoint_positions:
        if hx < carrier_width - 25:
            pass
            # 하드포인트 베이스
            pygame.draw.rect(carrier_surface, (75, 85, 100), (hx-3, hy-3, 6, 6))
            pygame.draw.rect(carrier_surface, (95, 105, 120), (hx-2, hy-2, 4, 4))
            # 마운트 포인트
            pygame.draw.circle(carrier_surface, (115, 125, 140), (hx, hy), 2)
            pygame.draw.circle(carrier_surface, (135, 145, 160), (hx, hy), 1)
    
    # 배기구/벤트 시스템
    vent_positions = [(35, 55), (65, 55), (95, 55), (125, 55), (155, 55)]
    for vx, vy in vent_positions:
        if vx < carrier_width - 20:
            pass
            # 벤트 그릴
            for i in range(3):
                pygame.draw.line(carrier_surface, (60, 70, 85), 
                               (vx + i*2, vy), (vx + i*2, vy + 8), 1)
            # 벤트 프레임
            pygame.draw.rect(carrier_surface, (80, 90, 105), (vx-1, vy-1, 7, 10), 1)
    
    # 센서 어레이 시스템
    sensor_positions = [(45, 20), (75, 20), (105, 20), (135, 20)]
    for sx, sy in sensor_positions:
        if sx < carrier_width - 15:
            pass
            # 센서 돔
            pygame.draw.circle(carrier_surface, (90, 110, 130), (sx, sy), 3)
            pygame.draw.circle(carrier_surface, (110, 130, 150), (sx, sy), 2)
            # 센서 렌즈
            pygame.draw.circle(carrier_surface, (150, 170, 190), (sx-1, sy-1), 1)
    
    # === 야마토 캐논급 주포 터렛 시스템 ===
    # 듀얼 배럴 주포 터렛 (더 강력한 느낌)
    turret_positions = [(30, 38), (65, 36), (100, 36), (135, 38), (170, 38)]
    for idx, (tx, ty) in enumerate(turret_positions):
        if tx < carrier_width - 25:
            pass
            # 터렛 베이스 (다층 구조)
            pygame.draw.circle(carrier_surface, (50, 60, 70), (tx, ty), 10)
            pygame.draw.circle(carrier_surface, (70, 80, 90), (tx, ty), 8)
            pygame.draw.circle(carrier_surface, (90, 100, 110), (tx, ty), 6)
            
            # 듀얼 포신 (쌍발)
            gun_angle = math.sin(time_now * 0.00001 + tx * 0.01) * 2  # 극도로 느린 움직임 (100배 느리게, 각도도 작게)
            for barrel_offset in [-2, 2]:  # 두 개의 포신
                barrel_x = tx + barrel_offset
                gun_end_x = barrel_x + 15 * math.cos(math.radians(gun_angle))
                gun_end_y = ty + 15 * math.sin(math.radians(gun_angle)) + barrel_offset
                
                # 포신 그라데이션 (굵기 변화)
                pygame.draw.line(carrier_surface, (40, 50, 60), 
                               (barrel_x, ty), (gun_end_x, gun_end_y), 4)
                pygame.draw.line(carrier_surface, (60, 70, 80), 
                               (barrel_x, ty), (gun_end_x-2, gun_end_y), 3)
                pygame.draw.line(carrier_surface, (80, 90, 100), 
                               (barrel_x, ty), (gun_end_x-4, gun_end_y), 2)
                
                # 포구 플래시 제거 (사용자 요청 - 주황색 빛 제거)
                # if boss_current_health > 8 and random.random() < 0.1:
                #     flash_color = (255, 200, 100)
                #     pygame.draw.circle(carrier_surface, flash_color, 
                #                      (int(gun_end_x), int(gun_end_y)), 3)
            
            # 터렛 중앙 에너지 코어
            pygame.draw.circle(carrier_surface, (150, 180, 210), (tx, ty), 3)
            pygame.draw.circle(carrier_surface, (180, 210, 240), (tx-1, ty-1), 1)
    
    # === 사령부 브릿지 (미래형 다층 구조) ===
    bridge_x = carrier_width - 75
    
    # 브릿지 기초 플랫폼
    pygame.draw.rect(carrier_surface, (55, 65, 75), (bridge_x-2, 18, 54, 32))
    pygame.draw.rect(carrier_surface, (75, 85, 100), (bridge_x, 15, 50, 30))
    
    # 중간층 (지휘소)
    bridge_mid = (95, 105, 120) if boss_current_health > 5 else (75, 85, 95)
    pygame.draw.rect(carrier_surface, bridge_mid, (bridge_x + 5, 12, 40, 22))
    # 중간층 디테일
    for i in range(3):
        pygame.draw.line(carrier_surface, (115, 125, 140), 
                        (bridge_x + 8 + i*12, 14), (bridge_x + 8 + i*12, 30), 1)
    
    # 최상층 (전망대)
    bridge_top = (105, 115, 130) if boss_current_health > 3 else (85, 95, 105)
    pygame.draw.rect(carrier_surface, bridge_top, (bridge_x + 10, 8, 30, 15))
    
    # 지휘탑 안테나 타워
    pygame.draw.rect(carrier_surface, (115, 125, 140), (bridge_x + 23, 3, 4, 8))
    pygame.draw.line(carrier_surface, (135, 145, 160), (bridge_x + 25, 3), (bridge_x + 25, 0), 2)
    
    # 파노라마 브릿지 창문 시스템
    for i in range(5):
        window_x = bridge_x + 10 + i * 6
        # 창문 프레임
        pygame.draw.rect(carrier_surface, (100, 110, 120), (window_x-1, 9, 6, 10), 1)
        # 내부 블루 글로우 (커맨드 센터 느낌)
        glow_intensity = int(150 + 50 * abs(math.sin(time_now * 0.002 + i * 0.3)))
        pygame.draw.rect(carrier_surface, (glow_intensity, glow_intensity + 30, 200), 
                        (window_x, 10, 4, 8))
        # 창문 반사 및 디테일
        pygame.draw.line(carrier_surface, (200, 220, 255), 
                        (window_x, 10), (window_x + 2, 10), 1)
        # 내부 활동 표시 제거 (사용자 요청 - 주황색 깜빡임 제거)
        # if random.random() < 0.05:
        #     pygame.draw.circle(carrier_surface, (255, 200, 100), (window_x + 2, 14), 1)
    
    # === 폐이저 어레이 레이더 시스템 ===
    # 주 레이더 돔 (입체적 구조)
    radar_x = bridge_x + 25
    # 레이더 베이스
    pygame.draw.circle(carrier_surface, (80, 90, 100), (radar_x, 8), 7)
    pygame.draw.circle(carrier_surface, (120, 140, 160), (radar_x, 8), 5)
    pygame.draw.circle(carrier_surface, (140, 160, 180), (radar_x, 8), 3)
    
    # 멀티 레이어 레이더 스캔 효과 (극도로 천천히 회전)
    radar_angle = time_now * 0.00005  # 0.0003 → 0.00005 (60배 더 느리게)
    for r in range(1, 4):  # 여러 개의 스캔 라인
        angle_offset = radar_angle + r * 0.2  # 0.5 → 0.2 (라인 간격도 좁게)
        scan_range = 6 + r * 2
        antenna_end_x = radar_x + scan_range * math.cos(angle_offset)
        antenna_end_y = 8 + scan_range * math.sin(angle_offset)
        # 색상도 더 어둡게 조정하여 덜 눈에 띄게
        scan_color = (min(255, 80 + r*15), min(255, 100 + r*15), min(255, 120 + r*15))
        pygame.draw.line(carrier_surface, scan_color, 
                        (radar_x, 8), (antenna_end_x, antenna_end_y), 2)  # 두께도 줄임
    
    # 중앙 레이더 코어 (펄스 빛)
    pulse = abs(math.sin(time_now * 0.005))
    core_color = (int(180 + pulse * 75), int(200 + pulse * 55), 255)
    pygame.draw.circle(carrier_surface, core_color, (radar_x, 8), 2)
    
    # 보조 통신 안테나들
    for i, ant_x in enumerate([bridge_x + 10, bridge_x + 40]):
        ant_height = 5 - i
        pygame.draw.line(carrier_surface, (160, 170, 180), 
                        (ant_x, 15), (ant_x, ant_height), 2)
        # 안테나 팁
        pygame.draw.circle(carrier_surface, (200, 210, 220), (ant_x, ant_height), 1)
    
    # === 쉴드 안테나 시스템 (사용자가 그린 디자인 참고) ===
    # 안테나 위치 (함선 앞쪽 중앙)
    shield_antenna_x = carrier_width // 2
    shield_antenna_y = 75  # 함선 앞쪽
    
    # 안테나 베이스 (둥근 돔)
    pygame.draw.circle(carrier_surface, (100, 110, 120), (shield_antenna_x, shield_antenna_y), 5)
    pygame.draw.circle(carrier_surface, (140, 150, 160), (shield_antenna_x, shield_antenna_y), 3)
    
    # 안테나 기둥
    pygame.draw.line(carrier_surface, (180, 190, 200), 
                    (shield_antenna_x, shield_antenna_y), 
                    (shield_antenna_x, shield_antenna_y - 8), 2)
    
    # 안테나 팁 (쉴드 생성기)
    tip_glow = abs(math.sin(time_now * 0.003)) * 100
    if shield_antenna_active:
        pass
        # 쉴드 활성화 시 밝게 빛남
        pygame.draw.circle(carrier_surface, (200, 220, 255), 
                          (shield_antenna_x, shield_antenna_y - 8), 4)
        pygame.draw.circle(carrier_surface, (255, 255, 255), 
                          (shield_antenna_x, shield_antenna_y - 8), 2)
    else:
        pass
        # 비활성화 시 약하게 빛남
        glow_value = min(255, int(150 + tip_glow))
        glow_color = (glow_value, min(255, int(170 + tip_glow)), min(255, int(200 + tip_glow)))
        pygame.draw.circle(carrier_surface, glow_color, 
                          (shield_antenna_x, shield_antenna_y - 8), 3)
        pygame.draw.circle(carrier_surface, (180, 200, 220), 
                          (shield_antenna_x, shield_antenna_y - 8), 1)
    
    # === 플라즈마 레이저 캐논 ===
    # 레이저 캐논 위치 (함선 아래쪽 중앙)
    laser_cannon_x = carrier_width // 2
    laser_cannon_y = 85  # 함선 아래쪽
    
    # 캐논 베이스 (회전 가능)
    pygame.draw.circle(carrier_surface, (70, 80, 90), (laser_cannon_x, laser_cannon_y), 8)
    pygame.draw.circle(carrier_surface, (90, 100, 110), (laser_cannon_x, laser_cannon_y), 6)
    
    # 캐논 포신 (각도에 따라 회전)
    if laser_charging or laser_cannon_active:
        pass
        # 충전 중이거나 발사 중일 때
        cannon_angle_rad = math.radians(laser_cannon_angle)
        barrel_end_x = laser_cannon_x + int(math.cos(cannon_angle_rad) * 12)
        barrel_end_y = laser_cannon_y + int(math.sin(cannon_angle_rad) * 12)
        
        # 포신 그리기
        pygame.draw.line(carrier_surface, (50, 60, 70), 
                        (laser_cannon_x, laser_cannon_y), 
                        (barrel_end_x, barrel_end_y), 5)
        pygame.draw.line(carrier_surface, (70, 80, 90), 
                        (laser_cannon_x, laser_cannon_y), 
                        (barrel_end_x, barrel_end_y), 3)
        
        # 충전 중 효과
        if laser_charging:
            charge_progress = (time_now - laser_charge_start) / 1500.0  # 0 ~ 1
            charge_glow = int(255 * charge_progress)
            # 포구에 충전 빛
            pygame.draw.circle(carrier_surface, 
                             (min(255, charge_glow), min(255, charge_glow + 50), 255), 
                             (barrel_end_x, barrel_end_y), int(3 + charge_progress * 3))
            # 파란색 전기 스파크
            for _ in range(int(5 * charge_progress)):
                spark_angle = random.uniform(0, math.pi * 2)
                spark_dist = random.uniform(5, 15)
                spark_x = barrel_end_x + int(math.cos(spark_angle) * spark_dist)
                spark_y = barrel_end_y + int(math.sin(spark_angle) * spark_dist)
                pygame.draw.circle(carrier_surface, (150, 200, 255), (spark_x, spark_y), 1)
    else:
        pass
        # 기본 상태 (아래 방향)
        pygame.draw.line(carrier_surface, (50, 60, 70), 
                        (laser_cannon_x, laser_cannon_y), 
                        (laser_cannon_x, laser_cannon_y + 12), 5)
        pygame.draw.line(carrier_surface, (70, 80, 90), 
                        (laser_cannon_x, laser_cannon_y), 
                        (laser_cannon_x, laser_cannon_y + 12), 3)
    
    # 캐논 중심 코어
    pygame.draw.circle(carrier_surface, (110, 120, 130), (laser_cannon_x, laser_cannon_y), 3)
    if laser_charging or laser_cannon_active:
        pass
        # 충전/발사 중 밝게
        pygame.draw.circle(carrier_surface, (150, 200, 255), (laser_cannon_x, laser_cannon_y), 2)
    
    # === 비행대대 편대 시스템 (체력 기반 전투기 배치) ===
    max_fighters = 12  # 더 많은 전투기
    current_fighters = int(max_fighters * (boss_current_health / boss_max_health))
    
    # V자 포메이션 전투기 배열
    fighter_positions = [
        # 전방 편대
        (20, 32), (35, 30), (50, 28), (65, 28), (80, 30), (95, 32),
        # 후방 편대
        (25, 35), (40, 33), (55, 31), (70, 31), (85, 33), (100, 35)
    ]
    
    for i in range(current_fighters):
        if i < len(fighter_positions):
            fx, fy = fighter_positions[i]
            if fx < carrier_width - 15:
                pass
                # 하이테크 인터셉터 스타일
                # 동체 (더 날렵한 형태)
                fighter_body = (80, 95, 110) if i < 6 else (70, 85, 100)  # 전방편대가 더 밝음
                pygame.draw.polygon(carrier_surface, fighter_body, 
                                   [(fx, fy), (fx+12, fy+1), (fx+10, fy+3), (fx+2, fy+3)])
                
                # 날개 (격납고 형태)
                wing_color = (65, 80, 95)
                # 왼쪽 날개
                pygame.draw.polygon(carrier_surface, wing_color,
                                   [(fx+3, fy+1), (fx, fy-2), (fx+1, fy+1)])
                # 오른쪽 날개
                pygame.draw.polygon(carrier_surface, wing_color,
                                   [(fx+9, fy+1), (fx+12, fy-2), (fx+11, fy+1)])
                
                # 콕핏 하이라이트
                pygame.draw.circle(carrier_surface, (120, 140, 160), (fx+6, fy+1), 1)
                
                # 미사일 마운트 제거 (사용자 요청 - 주황색 선 제거)
                # if boss_current_health > 10:
                #     pygame.draw.line(carrier_surface, (200, 100, 50), 
                #                    (fx+2, fy+3), (fx+2, fy+4), 1)
                #     pygame.draw.line(carrier_surface, (200, 100, 50), 
                #                    (fx+10, fy+3), (fx+10, fy+4), 1)
    
    # === 플라즈마 부스트 엔진 시스템 ===
    # 대형 슬링스트림 엔진 4기
    engine_positions = [(3, 48), (3, 56), (3, 64), (3, 72)]
    for idx, (ex, ey) in enumerate(engine_positions):
        # 엔진 노즐 하우징 (입체적)
        pygame.draw.rect(carrier_surface, (40, 50, 60), (ex, ey-1, 18, 10))
        pygame.draw.rect(carrier_surface, (60, 70, 80), (ex, ey, 16, 8))
        pygame.draw.rect(carrier_surface, (80, 90, 100), (ex+2, ey+1, 12, 6))
        
        # 플라즈마 제트 효과 (보스 움직임에 따라 동적으로)
        boss_velocity = abs(boss_speed)
        
        # 보스가 움직일 때만 제트 효과 표시
        if boss_velocity > 0.3:  # 더 민감하게 반응
            pass
            # 움직임 속도에 비례한 제트 길이 (더 길게)
            jet_length = int(15 + boss_velocity * 8)  # 더 긴 화염
            jet_intensity = min(255, int(180 + boss_velocity * 30))  # 더 밝게
            
            # 애니메이션 효과를 위한 오프셋
            flame_offset = (pygame.time.get_ticks() // 50) % 3
            
            # 외곽 글로우 효과 (더 크게)
            glow_color = (255, 100, 50, 30)  # 주황색 글로우
            for g in range(3):
                pygame.draw.line(carrier_surface, (255, 80 - g*20, 30), 
                                (ex, ey + 4), (ex - jet_length - g*2, ey + 4), 5 - g)
            
            # 메인 화염 (더 화려하게)
            # 외곽 화염 (빨간색-주황색)
            for i in range(3):
                offset_y = flame_offset - 1 + i
                flame_alpha = 200 - i * 50
                flame_red = min(255, jet_intensity + i * 10)
                flame_color = (flame_red, max(50, jet_intensity - 100 - i*30), 20)
                pygame.draw.line(carrier_surface, flame_color, 
                                (ex-1, ey + 3 + offset_y), 
                                (ex - jet_length - i*2, ey + 3 + offset_y), 4 - i)
            
            # 중간층 (주황색-노란색)
            mid_color = (255, min(255, jet_intensity + 30), 80)
            pygame.draw.line(carrier_surface, mid_color, 
                            (ex, ey + 4), (ex - jet_length*2//3, ey + 4), 3)
            
            # 코어 (밝은 노란색-흰색)
            core_color = (255, 255, min(255, 180 + boss_velocity * 20))
            pygame.draw.line(carrier_surface, core_color, 
                            (ex+1, ey + 4), (ex - jet_length//2, ey + 4), 2)
            
            # 플라즈마 번개 효과 (가끔씩)
            if random.random() < 0.3:
                bolt_x = ex - random.randint(5, jet_length)
                bolt_y = ey + 4 + random.randint(-2, 2)
                pygame.draw.line(carrier_surface, (200, 200, 255),
                                (ex, ey + 4), (bolt_x, bolt_y), 1)
            
            # 불꽃 파티클 효과 (더 많이)
            particle_count = int(3 + boss_velocity * 2)
            for _ in range(particle_count):
                spark_x = ex - random.randint(0, jet_length + 10)
                spark_y = ey + 4 + random.randint(-3, 3)
                spark_size = random.choice([1, 1, 2])
                spark_color = random.choice([
                    (255, random.randint(180, 255), random.randint(0, 100)),
                    (255, random.randint(150, 200), 50),
                    (255, 255, random.randint(150, 255))
                ])
                pygame.draw.circle(carrier_surface, spark_color, (spark_x, spark_y), spark_size)
    
    # === 포인트 디펜스 미사일 시스템 ===
    # 자동 방어 미사일 터렛
    defense_positions = [(25, 22), (45, 20), (65, 22), (85, 20), 
                        (105, 22), (125, 20), (145, 22), (165, 20)]
    
    global turret_angles, turret_missiles, last_missile_time
    current_time = pygame.time.get_ticks()
    
    for idx, (dx, dy) in enumerate(defense_positions):
        if dx < carrier_width - 15:
            pass
            # 터렛 ID 생성
            turret_id = f"turret_{idx}_{dx}_{dy}"
            
            # 터렛 각도 초기화 및 업데이트
            if turret_id not in turret_angles:
                turret_angles[turret_id] = random.randint(0, 360)
            
            # 천천히 좌우로 움직이는 포신 (아래를 향하되 각도가 변함)
            turret_angles[turret_id] = (turret_angles[turret_id] + 1) % 120  # 0~120도 범위
            barrel_angle = 60 + turret_angles[turret_id]  # 60~180도 (대략 아래 방향)
            angle_rad = math.radians(barrel_angle)
            
            # 터렛 베이스
            pygame.draw.circle(carrier_surface, (65, 75, 85), (dx, dy), 4)
            pygame.draw.circle(carrier_surface, (85, 95, 105), (dx, dy), 3)
            
            # 아래를 향하는 포신 그리기
            barrel_length = 10
            barrel_end_x = dx + int(math.cos(angle_rad) * barrel_length)
            barrel_end_y = dy + int(math.sin(angle_rad) * barrel_length)
            pygame.draw.line(carrier_surface, (90, 100, 110), (dx, dy), (barrel_end_x, barrel_end_y), 3)
            
            # 포구 끝부분 (더 크게)
            pygame.draw.circle(carrier_surface, (120, 130, 140), (barrel_end_x, barrel_end_y), 3)
            pygame.draw.circle(carrier_surface, (100, 110, 120), (barrel_end_x, barrel_end_y), 2)
            
            # 미사일 발사 (터렛별로 다른 타이밍)
            if boss_current_health > 0 and random.random() < 0.0015 and boss_confused_timer == 0:  # 0.15% 확률로 매 프레임 발사 (발사 빈도 더 줄임, 혼란 상태가 아닐 때만)
                pass
                # 미사일 발사 위치 (보스 패들 절대 좌표로 변환)
                missile_x = boss_x + dx
                missile_y = BOSS_Y + dy + 10  # 포신 끝에서 발사
                
                # 아래 방향으로 랜덤한 각도로 발사 (수직에서 ±30도 범위)
                base_angle = 90  # 아래 방향 (90도)
                spread_angle = random.randint(-30, 30)  # ±30도 랜덤 스프레드
                final_angle = base_angle + spread_angle
                angle_for_missile = math.radians(final_angle)
                
                # 미사일 속도 설정 (랜덤 속도)
                missile_speed = random.uniform(2, 4)  # 2~4 사이 랜덤 속도
                missile_vx = math.cos(angle_for_missile) * missile_speed
                missile_vy = math.sin(angle_for_missile) * missile_speed
                
                # 미사일 추가
                new_missile = {
                    'x': missile_x,
                    'y': missile_y,
                    'vx': missile_vx,
                    'vy': missile_vy,
                    'age': 0,
                    'turret_id': turret_id
                }
                turret_missiles.append(new_missile)
            
            # 터렛 중앙 렌즈
            lens_color = (100, 100, 100)  # 회색
            pygame.draw.circle(carrier_surface, lens_color, (dx, dy), 1)
            pygame.draw.circle(carrier_surface, (100, 110, 120), (dx, dy), 2)
    
    # === 울트라 배틀크루저 전투 손상 시스템 ===
    if damage_ratio > 0.2:
        pass
        # 시스템 오작동 스파크 (안정적인 효과)
        for _ in range(int(damage_ratio * 8)):
            spark_x = random.randint(10, carrier_width - 10)
            spark_y = random.randint(25, 75)
            # 전기 스파크 색상 변화
            spark_type = random.choice(['electric', 'plasma', 'fire'])
            if spark_type == 'electric':
                pass
                spark_color = (150, 200, 255)  # 전기 파란색
            elif spark_type == 'plasma':
                pass
                spark_color = (255, 150, 255)  # 플라즈마 보라색
            else:
                spark_color = (255, 200, 100)  # 화염 노란색
            pygame.draw.circle(carrier_surface, spark_color, (spark_x, spark_y), 1)
    
    if damage_ratio > 0.4:
        pass
        # 장갑판 균열 및 손상
        for _ in range(int(damage_ratio * 5)):
            crack_x = random.randint(20, carrier_width - 20)
            crack_y = random.randint(30, 65)
            crack_length = random.randint(5, 15)
            crack_end_x = crack_x + random.randint(-crack_length, crack_length)
            crack_end_y = crack_y + random.randint(-5, 5)
            pygame.draw.line(carrier_surface, (40, 45, 50), 
                           (crack_x, crack_y), (crack_end_x, crack_end_y), 1)
    
    if damage_ratio > 0.5:
        pass
        # 화재 및 플라즈마 누출
        for _ in range(int(damage_ratio * 7)):
            leak_x = random.randint(15, carrier_width - 15)
            leak_y = random.randint(30, 70)
            
            if random.random() < 0.6:
                pass
                # 화재 효과 (계층적 화염)
                pygame.draw.circle(carrier_surface, (255, 100, 0), (leak_x, leak_y), 3)
                pygame.draw.circle(carrier_surface, (255, 150, 0), (leak_x, leak_y), 2)
                pygame.draw.circle(carrier_surface, (255, 200, 50), (leak_x, leak_y), 1)
            else:
                pass
                # 플라즈마 누출 (파란색 에너지)
                pygame.draw.circle(carrier_surface, (100, 150, 255), (leak_x, leak_y), 2)
                pygame.draw.circle(carrier_surface, (150, 200, 255), (leak_x, leak_y), 1)
            
            # 연기 효과
            if random.random() < 0.5:
                smoke_x = leak_x + random.randint(-5, 5)
                smoke_y = leak_y - random.randint(3, 10)
                pygame.draw.circle(carrier_surface, (50, 50, 50), (smoke_x, smoke_y), 2)
    
    # === 에너지 쉴드 효과 (제거) ===
    # 파란색 테두리가 나타나지 않도록 주석 처리
    # if damage_ratio < 0.3:  # 체력이 70% 이상일 때
    #     shield_alpha = int(30 + 20 * abs(math.sin(time_now * 0.005)))
    #     shield_color = (100, 150, 255, shield_alpha)
    #     # 쉴드 윤곽선
    #     pygame.draw.rect(carrier_surface, shield_color[:3], 
    #                     (3, 20, carrier_width - 6, carrier_height - 25), 2)
    #     # 쉴드 헥사곤 패턴
    #     for i in range(0, carrier_width - 10, 20):
    #         for j in range(0, carrier_height - 20, 15):
    #             if random.random() < 0.3:
    #                 hex_x, hex_y = 8 + i, 25 + j
    #                 pygame.draw.circle(carrier_surface, shield_color[:3], (hex_x, hex_y), 3, 1)
    
    # 🔥 체력에 따른 손상 효과 (연기, 화염)
    health_percent = (boss_current_health / boss_max_health) * 100
    
    # 체력 50% 이하: 연기 효과
    if health_percent <= 50:
        pass
        # 연기 파티클 생성
        smoke_points = []
        if health_percent <= 10:
            pass
            smoke_count = 12  # 체력 10% 이하: 매우 많은 연기
        elif health_percent <= 20:
            pass
            smoke_count = 8   # 체력 20% 이하: 많은 연기
        elif health_percent <= 30:
            pass
            smoke_count = 5   # 체력 30% 이하: 중간 연기
        else:
            smoke_count = 3   # 체력 50% 이하: 약간의 연기
        
        # 랜덤 위치에서 연기 생성
        for _ in range(smoke_count):
            smoke_x = random.randint(20, carrier_width - 20)
            smoke_y = random.randint(30, 60)
            smoke_points.append((smoke_x, smoke_y))
        
        # 연기 그리기
        for smoke_x, smoke_y in smoke_points:
            # 여러 크기의 연기 구름
            for i in range(3):
                smoke_size = random.randint(8, 15) + i * 3
                smoke_alpha = random.randint(20, 60) - i * 10
                smoke_color = (60 + i * 20, 60 + i * 20, 60 + i * 20, smoke_alpha)
                
                # 연기 원 그리기
                smoke_circle = pygame.Surface((smoke_size * 2, smoke_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(smoke_circle, smoke_color, (smoke_size, smoke_size), smoke_size)
                
                # 연기 위치 약간 흔들기
                offset_x = random.randint(-2, 2)
                offset_y = random.randint(-5, -1) - i * 2
                carrier_surface.blit(smoke_circle, (smoke_x - smoke_size + offset_x, smoke_y - smoke_size + offset_y))
    
    # 체력 30% 이하: 화염 효과 시작
    if health_percent <= 30:
        fire_intensity = 1.0
        if health_percent <= 10:
            fire_intensity = 3.0  # 체력 10% 이하: 대형 화염
            fire_count = 8
        elif health_percent <= 20:
            fire_intensity = 2.0  # 체력 20% 이하: 강한 화염
            fire_count = 5
        else:
            fire_intensity = 1.0  # 체력 30% 이하: 약한 화염
            fire_count = 3
        
        # 화염 위치 생성
        fire_points = []
        for _ in range(fire_count):
            fire_x = random.randint(25, carrier_width - 25)
            fire_y = random.randint(35, 65)
            fire_points.append((fire_x, fire_y))
        
        # 화염 그리기
        for fire_x, fire_y in fire_points:
            # 화염 애니메이션 (시간에 따라 변화)
            flame_wave = abs(math.sin(time_now * 0.01 + fire_x))
            
            # 화염 코어 (흰색-노란색)
            core_size = int(4 * fire_intensity * (0.8 + flame_wave * 0.2))
            pygame.draw.circle(carrier_surface, (255, 255, 200), (fire_x, fire_y), core_size)
            
            # 중간 화염 (주황색)
            mid_size = int(7 * fire_intensity * (0.9 + flame_wave * 0.1))
            mid_color = (255, 150, 50, 180)
            flame_mid = pygame.Surface((mid_size * 2, mid_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(flame_mid, mid_color, (mid_size, mid_size), mid_size)
            carrier_surface.blit(flame_mid, (fire_x - mid_size, fire_y - mid_size))
            
            # 외부 화염 (빨간색)
            outer_size = int(10 * fire_intensity * (1.0 + flame_wave * 0.2))
            outer_color = (255, 50, 30, 120)
            flame_outer = pygame.Surface((outer_size * 2, outer_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(flame_outer, outer_color, (outer_size, outer_size), outer_size)
            carrier_surface.blit(flame_outer, (fire_x - outer_size, fire_y - outer_size - int(flame_wave * 3)))
            
            # 불꽃 파티클 효과
            if random.random() < 0.3 * fire_intensity:
                for _ in range(int(2 * fire_intensity)):
                    spark_x = fire_x + random.randint(-15, 15)
                    spark_y = fire_y + random.randint(-10, -2)
                    spark_color = (255, random.randint(100, 200), 0)
                    pygame.draw.circle(carrier_surface, spark_color, (spark_x, spark_y), random.randint(1, 2))
    
    # 체력 10% 이하: 폭발 효과 추가
    if health_percent <= 10:
        pass
        # 랜덤 폭발 효과
        if random.random() < 0.2:  # 20% 확률로 폭발
            explosion_x = random.randint(30, carrier_width - 30)
            explosion_y = random.randint(30, 60)
            
            # 폭발 플래시
            flash_size = random.randint(15, 25)
            pygame.draw.circle(carrier_surface, (255, 255, 255), (explosion_x, explosion_y), flash_size)
            pygame.draw.circle(carrier_surface, (255, 200, 100), (explosion_x, explosion_y), flash_size - 3)
            pygame.draw.circle(carrier_surface, (255, 100, 0), (explosion_x, explosion_y), flash_size - 6)
            
            # 파편 효과
            for _ in range(8):
                debris_x = explosion_x + random.randint(-20, 20)
                debris_y = explosion_y + random.randint(-20, 20)
                debris_color = (random.randint(150, 255), random.randint(50, 150), 0)
                pygame.draw.circle(carrier_surface, debris_color, (debris_x, debris_y), random.randint(1, 3))
    
    # === 플라즈마 레이저 캐논 ===
    # 글로벌 변수는 이미 draw_objects에서 선언됨
    current_time = pygame.time.get_ticks()
    
    # 캐논 위치 (함선 전면 중앙)
    cannon_x = carrier_width // 2
    cannon_y = 15
    
    # 캐논 각도는 충전 시작할 때 이미 설정됨
    # laser_cannon_angle은 draw_objects에서 충전 시 설정
    
    # 캐논 베이스 그리기
    pygame.draw.circle(carrier_surface, (80, 90, 100), (cannon_x, cannon_y), 12)
    pygame.draw.circle(carrier_surface, (100, 110, 120), (cannon_x, cannon_y), 10)
    
    # 회전하는 캐논 포신
    cannon_barrel_length = 20
    angle_rad = math.radians(laser_cannon_angle)
    cannon_barrel_end_x = cannon_x + int(math.cos(angle_rad) * cannon_barrel_length)
    cannon_barrel_end_y = cannon_y + int(math.sin(angle_rad) * cannon_barrel_length)
    
    # 포신 그리기 (두께 좋 표현)
    pygame.draw.line(carrier_surface, (90, 100, 110), 
                     (cannon_x, cannon_y), (cannon_barrel_end_x, cannon_barrel_end_y), 8)
    pygame.draw.line(carrier_surface, (110, 120, 130), 
                     (cannon_x, cannon_y), (cannon_barrel_end_x, cannon_barrel_end_y), 6)
    
    # 캐논 끝부분 (발사구)
    pygame.draw.circle(carrier_surface, (120, 130, 140), 
                      (cannon_barrel_end_x, cannon_barrel_end_y), 6)
    pygame.draw.circle(carrier_surface, (140, 150, 160), 
                      (cannon_barrel_end_x, cannon_barrel_end_y), 4)
    
    # 충전 효과
    if laser_charging:
        charge_time = current_time - laser_charge_start
        charge_ratio = min(1.0, charge_time / 1000)  # 1초 충전
        
        # 충전 파티클 효과
        for _ in range(int(10 * charge_ratio)):
            particle_angle = random.uniform(0, math.pi * 2)
            particle_dist = random.uniform(10, 30 * (1 - charge_ratio))
            particle_x = cannon_barrel_end_x + int(math.cos(particle_angle) * particle_dist)
            particle_y = cannon_barrel_end_y + int(math.sin(particle_angle) * particle_dist)
            
            # 파란색 에너지 파티클
            particle_color = (100, 150 + int(100 * charge_ratio), 255)
            pygame.draw.circle(carrier_surface, particle_color, 
                             (particle_x, particle_y), random.randint(1, 3))
        
        # 충전 코어
        core_size = int(4 + 6 * charge_ratio)
        core_color = (150, 200, 255)
        pygame.draw.circle(carrier_surface, core_color, 
                         (cannon_barrel_end_x, cannon_barrel_end_y), core_size)
        pygame.draw.circle(carrier_surface, (255, 255, 255), 
                         (cannon_barrel_end_x, cannon_barrel_end_y), core_size - 2)
    
    # === 쉴드 안테나 시스템 ===
    # 안테나 위치 (함선 전면 좌우)
    antenna_left_x = 30
    antenna_right_x = carrier_width - 30
    antenna_y = 25
    
    # 왼쪽 안테나
    pygame.draw.rect(carrier_surface, (110, 120, 130), 
                     (antenna_left_x - 2, antenna_y, 4, 15))
    pygame.draw.circle(carrier_surface, (140, 150, 160), 
                      (antenna_left_x, antenna_y), 4)
    # 안테나 끝 발광체
    pygame.draw.circle(carrier_surface, (200, 210, 220), 
                      (antenna_left_x, antenna_y - 5), 3)
    if shield_antenna_active:
        pass
        # 활성화시 빛나는 효과
        pygame.draw.circle(carrier_surface, (255, 255, 255), 
                          (antenna_left_x, antenna_y - 5), 2)
    
    # 오른쪽 안테나
    pygame.draw.rect(carrier_surface, (110, 120, 130), 
                     (antenna_right_x - 2, antenna_y, 4, 15))
    pygame.draw.circle(carrier_surface, (140, 150, 160), 
                      (antenna_right_x, antenna_y), 4)
    # 안테나 끝 발광체
    pygame.draw.circle(carrier_surface, (200, 210, 220), 
                      (antenna_right_x, antenna_y - 5), 3)
    if shield_antenna_active:
        pass
        # 활성화시 빛나는 효과
        pygame.draw.circle(carrier_surface, (255, 255, 255), 
                          (antenna_right_x, antenna_y - 5), 2)
    
    return carrier_surface

