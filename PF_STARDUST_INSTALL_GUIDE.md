# 🌟 PF스타더스트 3.0 S 폰트 설치 가이드

## 폰트 정보
- **폰트명**: PF스타더스트 3.0 S
- **제작자**: 피나타 (Pinata)
- **스타일**: 픽셀 폰트
- **라이선스**: 무료 (개인/상업용 가능)

## 설치 방법

### 방법 1: 네이버 블로그에서 직접 다운로드 (권장)
1. 아래 링크 접속:
   https://m.blog.naver.com/campanula913/221366697603
   
2. 블로그에서 TTF 파일 다운로드

3. 다운로드한 파일을 `PFStardust.ttf`로 이름 변경

4. 게임 폴더 (`/Users/pika/Desktop/game/bosspong/`)에 복사

### 방법 2: 온라인 변환기 사용
1. WOFF2 파일이 있다면 변환기 사용:
   https://cloudconvert.com/woff2-to-ttf
   
2. 변환된 TTF 파일을 `PFStardust.ttf`로 저장

3. 게임 폴더에 복사

## 적용 확인
게임을 실행하면 콘솔에 다음 메시지가 나타납니다:
```
🌟 PF스타더스트 3.0 S 폰트 활성화!
```

## 현재 설정
- 시스템이 자동으로 폰트를 감지합니다
- PFStardust.ttf가 없으면 기본 픽셀 폰트 사용
- pixel_font_manager.py가 자동으로 처리

## 문제 해결
- TTF 파일만 pygame에서 지원됩니다
- WOFF/WOFF2는 웹 전용이므로 변환 필요
- 파일명은 정확히 `PFStardust.ttf`여야 함