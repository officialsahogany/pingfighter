# 🎮 PingFighter 픽셀 폰트 통합 가이드

## 📋 현재 상태
- ✅ 네오둥근모 픽셀 폰트 다운로드 완료
- ✅ pixel_font_manager.py 모듈 생성 완료
- ✅ pingfighter.py IndentationError 수정 완료 (라인 5107-5132)
- ✅ 테스트 스크립트 작성 완료

## 🚀 빠른 시작

### 1. 테스트 실행
```bash
# 픽셀 폰트 시스템 테스트
python test_pixel_fonts.py

# 게임 실행 테스트
python pingfighter.py
```

### 2. 기본 사용법
```python
# 파일 상단에 import 추가
from pixel_font_manager import get_font, FontStyle, PixelColors, render_pixel_text

# 기존 폰트 코드 변경
# 변경 전:
font = pygame.font.Font("NanumSquareR.ttf", 40)

# 변경 후:
font = get_font(40)  # 자동으로 픽셀 폰트 사용
```

## 📝 주요 변경 위치 (pingfighter.py)

### 1. 메인 폰트 (Line 481-483)
```python
# 변경 전:
FONT = pygame.font.Font("NanumSquareR.ttf", 40)

# 변경 후:
from pixel_font_manager import get_font, FontStyle
FONT = get_font(40)  # 또는 FontStyle.title()
```

### 2. 스테이지 타이틀 (Line 1501-1502)
```python
# 변경 전:
font_large = pygame.font.Font("NanumSquareB.ttf", 64)
font_small = pygame.font.Font("NanumSquareR.ttf", 20)

# 변경 후:
font_large = FontStyle.title_large()
font_small = FontStyle.small()
```

### 3. 점수 표시 (Line 2375)
```python
# 변경 전:
font = pygame.font.Font("NanumSquareB.ttf", 26)

# 변경 후:
font = FontStyle.score()
```

### 4. 슬롯머신 텍스트 (Line 4938-5032)
```python
# 변경 전:
title_font = pygame.font.Font("NanumSquareB.ttf", 48)
result_font = pygame.font.Font("NanumSquareB.ttf", 36)

# 변경 후:
title_font = FontStyle.title()
result_font = FontStyle.subtitle()
```

### 5. 아이템 표시 (Line 5205)
```python
# 변경 전:
name_font = pygame.font.Font("NanumSquareB.ttf", 12)

# 변경 후:
name_font = FontStyle.item_name()
```

### 6. 게이지 텍스트 (Line 5402)
```python
# 변경 전:
gauge_font = pygame.font.Font("NanumSquareR.ttf", 14)

# 변경 후:
gauge_font = FontStyle.gauge()
```

### 7. 서브 정보 (Line 6553-6554)
```python
# 변경 전:
serve_font = pygame.font.Font("NanumSquareR.ttf", 26)
info_font = pygame.font.Font("NanumSquareR.ttf", 18)

# 변경 후:
serve_font = FontStyle.menu()
info_font = FontStyle.tiny()
```

## 🎨 폰트 스타일 프리셋

### 사용 가능한 스타일
```python
FontStyle.title_large()  # 큰 제목 (64pt → 72pt 픽셀)
FontStyle.title()        # 일반 제목 (40pt → 48pt 픽셀)
FontStyle.subtitle()     # 부제목 (32pt → 36pt 픽셀)
FontStyle.menu()         # 메뉴 (28pt → 32pt 픽셀)
FontStyle.body()         # 본문 (24pt → 28pt 픽셀)
FontStyle.small()        # 작은 텍스트 (20pt → 24pt 픽셀)
FontStyle.tiny()         # 아주 작은 (16pt → 18pt 픽셀)
FontStyle.score()        # 점수 (36pt → 42pt 픽셀)
FontStyle.gauge()        # 게이지 (14pt → 16pt 픽셀)
FontStyle.item_name()    # 아이템 이름 (12pt → 14pt 픽셀)
FontStyle.item_obtain()  # 아이템 획득 (9pt → 11pt 픽셀)
```

## 🌈 색상 프리셋

### 기본 색상
```python
PixelColors.WHITE        # (255, 255, 255)
PixelColors.BLACK        # (0, 0, 0)
PixelColors.RED          # (255, 0, 0)
PixelColors.GREEN        # (0, 255, 0)
PixelColors.BLUE         # (0, 0, 255)
PixelColors.YELLOW       # (255, 255, 0)
```

### 레트로 색상
```python
PixelColors.RETRO_GREEN  # 클래식 터미널 녹색
PixelColors.RETRO_AMBER  # 오래된 모니터 주황
PixelColors.RETRO_CYAN   # 네온 청록색
PixelColors.RETRO_PINK   # 네온 핑크
```

### 게임 특화 색상
```python
PixelColors.SCORE        # 점수용 노란색
PixelColors.HEALTH       # 체력용 녹색
PixelColors.DAMAGE       # 데미지용 빨간색
PixelColors.ENERGY       # 에너지용 파란색
PixelColors.ITEM         # 아이템용 주황색
PixelColors.SPECIAL      # 특수용 마젠타
```

## 🛠️ 고급 기능

### 1. 간편 렌더링
```python
# 중앙 정렬 텍스트
render_pixel_text(screen, "GAME OVER", (400, 300), 48, 
                 PixelColors.RED, center=True)
```

### 2. 깜빡이는 텍스트
```python
render_blinking_text(screen, "PRESS START", (400, 500), 32,
                    PixelColors.WHITE, PixelColors.YELLOW, speed=500)
```

### 3. 그림자 효과
```python
render_shadow_text(screen, "BOSS BATTLE", (400, 100), 48,
                  PixelColors.RED, PixelColors.BLACK, offset=3)
```

### 4. 폰트 토글
```python
# 런타임에 픽셀/기본 폰트 전환
toggle_pixel_font()
```

## 🔧 문제 해결

### 폰트가 안 보일 때
1. NeoDunggeunmoPro.ttf 파일이 있는지 확인
2. pixel_font_manager.py가 같은 폴더에 있는지 확인
3. `check_fonts()` 함수로 상태 확인

### 크기가 이상할 때
- 픽셀 폰트는 자동으로 18% 크기 조정됨
- 필요시 `adjust_pixel_size()` 함수 수정

### 한글이 깨질 때
- UTF-8 인코딩 확인
- 폰트 파일이 한글을 지원하는지 확인

## 📌 현재 수정 완료 사항

### ✅ 수정된 IndentationError (Line 5107-5132)
```python
# 슬롯머신 가이드 텍스트 부분
if slot_stop_order == 0:
    # 픽셀 폰트 (들여쓰기 수정 완료)
    try:
        guide_font = pygame.font.Font("NeoDunggeunmoPro.ttf", 28)
    except:
        guide_font = pygame.font.Font("NanumSquareR.ttf", 24)
```

## 💡 추천 사항

1. **점진적 적용**: 한 번에 모든 폰트를 바꾸지 말고 단계적으로 적용
2. **테스트 우선**: test_pixel_fonts.py로 먼저 테스트
3. **백업 필수**: pingfighter.py 백업 후 수정
4. **성능 확인**: 폰트 캐싱으로 성능 향상 확인

## 📧 지원

문제 발생 시:
1. `check_fonts()` 실행하여 폰트 상태 확인
2. test_pixel_fonts.py로 기본 기능 테스트
3. 에러 메시지와 함께 보고