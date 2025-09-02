"""
픽셀 폰트 적용 스크립트
pingfighter.py에 픽셀 폰트를 쉽게 적용하는 예제
"""

# 사용법:
# 1. pingfighter.py 상단에 추가:
#    from pixel_font_manager import get_font, FontStyle, PixelColors, render_pixel_text

# 2. 기존 폰트 코드를 다음과 같이 변경:

# ===== 변경 전 =====
# font = pygame.font.Font("NanumSquareR.ttf", 40)
# text = font.render("Hello", True, WHITE)

# ===== 변경 후 =====
# font = get_font(40)  # 또는 FontStyle.title()
# text = font.render("Hello", True, PixelColors.WHITE)

# ===== 더 간단하게 =====
# render_pixel_text(screen, "Hello", (x, y), 40, PixelColors.WHITE)

# 실제 적용 예시 코드:
def example_usage():
    """pingfighter.py에서 사용하는 예시"""
    
    # 1. Import 추가 (파일 상단)
    from pixel_font_manager import get_font, FontStyle, PixelColors, render_pixel_text
    
    # 2. 기존 폰트 변경
    # 변경 전:
    # FONT = pygame.font.Font("NanumSquareR.ttf", 40)
    
    # 변경 후:
    FONT = get_font(40)  # 자동으로 픽셀 폰트 사용
    
    # 3. 다양한 스타일 사용
    title_font = FontStyle.title()        # 제목용
    menu_font = FontStyle.menu()          # 메뉴용
    score_font = FontStyle.score()        # 점수용
    small_font = FontStyle.small()        # 작은 텍스트
    
    # 4. 색상 사용
    # 변경 전:
    # WHITE = (255, 255, 255)
    # text = font.render("Score", True, WHITE)
    
    # 변경 후:
    text = score_font.render("Score", True, PixelColors.SCORE)
    
    # 5. 간편 렌더링
    # render_pixel_text(screen, "GAME OVER", (400, 300), 48, PixelColors.RED, center=True)

# 주요 변경 위치:
FONT_CHANGES = """
📝 pingfighter.py에서 변경할 주요 위치:

1. Line 481: FONT 초기화
   변경: FONT = get_font(40)

2. Line 1501-1502: 스테이지 폰트
   변경: font_large = FontStyle.title_large()
        font_small = FontStyle.small()

3. Line 2375: 아이템 표시 폰트
   변경: font = FontStyle.menu()

4. Line 4938: 슬롯머신 타이틀
   변경: title_font = FontStyle.title()

5. Line 5026-5032: 슬롯 결과 폰트
   변경: result_font = FontStyle.subtitle()
        continue_font = FontStyle.small()

6. Line 5205: 아이템 이름 폰트
   변경: name_font = FontStyle.item_name()

7. Line 5402: 게이지 폰트
   변경: gauge_font = FontStyle.gauge()

8. Line 6553-6554: 서브 정보 폰트
   변경: serve_font = FontStyle.menu()
        info_font = FontStyle.tiny()
"""

print("🎮 픽셀 폰트 적용 가이드")
print("=" * 50)
print("""
1. pixel_font_manager.py를 import
2. get_font() 또는 FontStyle 클래스 사용
3. PixelColors로 레트로 색상 사용
4. render_pixel_text()로 간편 렌더링
""")
print(FONT_CHANGES)

# 자동 적용 함수 (선택적)
def auto_apply_to_game():
    """게임에 자동으로 적용 (백업 권장)"""
    print("\n⚠️ 이 기능은 pingfighter.py를 직접 수정합니다.")
    print("   백업을 먼저 하시는 것을 권장합니다!")
    
    response = input("\n계속하시겠습니까? (y/n): ")
    if response.lower() != 'y':
        print("취소되었습니다.")
        return
    
    # 여기에 자동 변경 코드 추가 가능
    print("✅ 수동으로 적용하시는 것을 권장합니다.")
    print("   위의 가이드를 참고해주세요!")

if __name__ == "__main__":
    print("\n픽셀 폰트 매니저가 준비되었습니다!")
    print("pixel_font_manager.py를 게임에서 import하여 사용하세요.")
    
    # 테스트
    import pygame
    from pixel_font_manager import check_fonts, toggle_pixel_font
    
    pygame.init()
    check_fonts()
    
    print("\n🎮 사용 예시:")
    print("from pixel_font_manager import get_font, FontStyle, PixelColors")
    print("font = get_font(40)  # 또는 FontStyle.title()")
    print("text = font.render('Hello', True, PixelColors.RETRO_GREEN)")