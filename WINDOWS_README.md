# PingFighter Windows 실행 가이드

## 🎮 빠른 시작
1. **install_requirements.bat** 실행 (처음 한 번만)
2. **run_game.bat** 실행

## 📋 시스템 요구사항
- Windows 7 이상
- Python 3.8 이상
- pygame 라이브러리

## 🔧 문제 해결

### 한글이 깨지는 경우
- Windows 시스템 언어를 한국어로 설정
- 코드페이지를 UTF-8로 변경: `chcp 65001`

### 배경이 안 나오는 경우
- stage1_field.png ~ stage6_field.png 파일 확인
- backgrounds/ 폴더 확인

### 아이템 아이콘이 안 나오는 경우
- items/ 폴더의 모든 .png 파일 확인
- items/legendary/ 폴더 확인

### 효과음이 안 나오는 경우
- sounds/ 폴더의 모든 .wav 파일 확인
- Windows 오디오 서비스 실행 중인지 확인

## 📁 필요한 폴더 구조
```
bosspong/
├── items/
│   ├── legendary/
│   └── *.png
├── sounds/
│   └── *.wav
├── backgrounds/
├── fonts/
│   └── *.ttf
└── pingfighter.py
```

## ✅ 수정 내역
1. UTF-8 인코딩 헤더 추가
2. resource_path 함수로 모든 리소스 경로 통일
3. Windows 한글 폰트 폴백 처리
4. 전설 아이템 폴더 자동 생성
5. unknown_item.png 경로 수정
6. AnimatedBackground 경로 수정

## 🚀 실행 파일 빌드 (선택사항)
```bash
pyinstaller PingFighter_Windows.spec
```

빌드된 실행 파일은 dist/ 폴더에 생성됩니다.
