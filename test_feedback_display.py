#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
피드백 디스플레이 테스트
Test the feedback display rendering with fixed formatting
"""

import pygame
import sys
import os

# 픽셀 폰트 설정
if os.path.exists("PFStardust.ttf"):
    PIXEL_FONT = "PFStardust.ttf"
elif os.path.exists("NeoDunggeunmoPro.ttf"):
    PIXEL_FONT = "NeoDunggeunmoPro.ttf"
else:
    PIXEL_FONT = None

def test_feedback_display():
    pygame.init()
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("피드백 디스플레이 테스트")
    clock = pygame.time.Clock()
    
    # 폰트 설정
    if PIXEL_FONT:
        font_large = pygame.font.Font(PIXEL_FONT, 24)
        font_medium = pygame.font.Font(PIXEL_FONT, 18)
        font_small = pygame.font.Font(PIXEL_FONT, 14)
    else:
        font_large = pygame.font.Font(None, 24)
        font_medium = pygame.font.Font(None, 18)
        font_small = pygame.font.Font(None, 14)
    
    # 샘플 피드백 텍스트 (수정된 포맷)
    feedback_texts = [
        "━━━ ⚡ 스킬 마스터리 ━━━",
        "🏆 등급: 🌟 전설이 되신 분",
        "",
        "📖 이야기",
        "당신의 손끝에서 번개가 춤춥니다.",
        "보스들이 '오늘은 집에 일찍 가고 싶다'고",
        "생각할 정도로 압도적입니다.",
        "",
        "🌟 빛나는 순간들",
        "▶ 타이밍의 신이 친구 신청을 보냈습니다",
        "▶ 파워 스매시가 보스의 멘탈까지 스매싱",
        "▶ 당신의 플레이를 본 공이 스스로 빨라집니다",
        "",
        "🌱 성장의 여정",
        "이미 정상에 서 있지만,",
        "우주에는 또 다른 보스가 있을지도?",
        "",
        "✨ 지혜의 속삭임",
        "진정한 고수는 실력을 자랑하지 않지만,",
        "가끔은 자랑해도 됩니다. 진짜 잘하시네요!",
        "",
        "【최우선 과제】 스킬과 더 친해지세요",
        "【자랑거리】 당신의 대쉬는 예술입니다",
        "【총평】 거의 다 왔습니다! 조금만 더!"
    ]
    
    # 색상 설정
    WHITE = (255, 255, 255)
    BLACK = (0, 0, 0)
    GREEN = (100, 255, 100)
    YELLOW = (255, 255, 100)
    BLUE = (100, 150, 255)
    DARK_BG = (30, 30, 40)
    
    running = True
    scroll_y = 0
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_UP:
                    scroll_y = min(scroll_y + 20, 0)
                elif event.key == pygame.K_DOWN:
                    scroll_y = max(scroll_y - 20, -len(feedback_texts) * 20 + 400)
        
        # 화면 클리어
        screen.fill(DARK_BG)
        
        # 패널 그리기
        panel_rect = pygame.Rect(50, 50, 700, 500)
        pygame.draw.rect(screen, (40, 40, 50), panel_rect)
        pygame.draw.rect(screen, GREEN, panel_rect, 2)
        
        # 제목
        title_text = font_large.render("📝 상세 피드백 분석", True, GREEN)
        title_rect = title_text.get_rect(center=(400, 80))
        screen.blit(title_text, title_rect)
        
        # 피드백 내용 렌더링
        y_pos = 120 + scroll_y
        for line in feedback_texts:
            if 50 < y_pos < 520:  # 패널 내부에만 표시
                if line.startswith("━━━"):
                    # 타이틀 라인
                    text_surface = font_medium.render(line, True, YELLOW)
                elif line.startswith("🏆") or line.startswith("📖") or line.startswith("🌟") or line.startswith("🌱") or line.startswith("✨"):
                    # 섹션 헤더
                    text_surface = font_medium.render(line, True, GREEN)
                elif line.startswith("【"):
                    # 특별 섹션
                    text_surface = font_small.render(line, True, BLUE)
                elif line.startswith("▶"):
                    # 불릿 포인트
                    text_surface = font_small.render(line, True, WHITE)
                else:
                    # 일반 텍스트
                    text_surface = font_small.render(line, True, WHITE)
                
                text_rect = text_surface.get_rect(left=80, top=y_pos)
                screen.blit(text_surface, text_rect)
            
            y_pos += 20
        
        # 스크롤 안내
        if len(feedback_texts) * 20 > 400:
            scroll_text = font_small.render("↑↓ 스크롤", True, (150, 150, 150))
            scroll_rect = scroll_text.get_rect(right=740, bottom=540)
            screen.blit(scroll_text, scroll_rect)
        
        # 조작 안내
        control_text = font_small.render("ESC: 종료 | ↑↓: 스크롤", True, (180, 180, 180))
        control_rect = control_text.get_rect(center=(400, 570))
        screen.blit(control_text, control_rect)
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    return True

if __name__ == "__main__":
    print("🎮 피드백 디스플레이 테스트 시작...")
    print("━" * 40)
    print("✅ 수정된 포맷:")
    print("  - 마크다운 제거 (** 제거)")
    print("  - 장식선 사용 (━━━)")
    print("  - 대괄호 사용 【】")
    print("  - 이모지 유지 🌟 📖 🌱")
    print("━" * 40)
    
    if test_feedback_display():
        print("✅ 테스트 완료!")
    else:
        print("❌ 테스트 실패")