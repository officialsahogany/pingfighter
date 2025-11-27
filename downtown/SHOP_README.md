# 상점 시스템 (Shop System)

광장(Downtown)의 상점 시스템입니다. 5가지 테마 중 선택 가능합니다.

## 5가지 상점 테마

### 1. 네온 마켓 (cyberpunk)
- **스타일**: 사이버펑크
- **주색상**: 네온 핑크 (#FF1493)
- **부색상**: 사이버 시안 (#00FFFF)
- **특징**: 첨단 기술과 네온 불빛의 미래적 상점

### 2. 마법 상점 (fantasy)
- **스타일**: 판타지
- **주색상**: 보라색 (#8A2BE2)
- **부색상**: 금색 (#FFD700)
- **특징**: 신비로운 마법 아이템과 마법진이 있는 상점

### 3. 기어 상회 (steampunk)
- **스타일**: 스팀펑크
- **주색상**: 황동색 (#B8860B)
- **부색상**: 녹슨 철 (#8B4513)
- **특징**: 증기기관과 기계 장치로 가득한 빅토리아 시대 상점

### 4. 숲속 교역소 (nature)
- **스타일**: 자연
- **주색상**: 숲 녹색 (#228B22)
- **부색상**: 나무색 (#D2B48C)
- **특징**: 자연과 조화로운 전통 교역소

### 5. 황금 갤러리 (luxury)
- **스타일**: 고급
- **주색상**: 금색 (#FFD700)
- **부색상**: 은색 (#C0C0C0)
- **특징**: 최고급 프리미엄 아이템 전문점

## 테마 테스트 방법

### 1. 테마 선택 미리보기
```bash
cd downtown
python3 test_shop_themes.py preview
```
- 5가지 테마를 카드 형식으로 표시
- [← →] 키로 선택
- [ENTER]로 확정 후 상점 열기

### 2. 모든 테마 비교
```bash
python3 test_shop_themes.py compare
```
- 5가지 테마를 한 화면에 나란히 표시
- 색상 샘플 확인 가능

### 3. 특정 테마 바로 테스트
```bash
python3 test_shop_themes.py cyberpunk
python3 test_shop_themes.py fantasy
python3 test_shop_themes.py steampunk
python3 test_shop_themes.py nature
python3 test_shop_themes.py luxury
```

## 상점 기능

### 아이템 구매
- **조작법**:
  - [↑↓] 또는 [W/S]: 아이템 선택
  - [SPACE] 또는 [ENTER]: 구매
  - [ESC]: 상점 나가기

### 상점 아이템 목록
1. 🧪 체력 물약 - 100G (HP 50 회복)
2. 💙 마나 물약 - 80G (MP 30 회복)
3. 🛡️ 방어구 - 500G (방어력 +10)
4. 💎 강화석 - 300G (무기 강화 재료)
5. 🍀 행운의 부적 - 400G (크리티컬 확률 +5%)
6. 📜 순간이동 주문서 - 200G (체크포인트로 이동)
7. 👻 투명 망토 - 600G (3초간 무적)
8. 🗝️ 황금 열쇠 - 1000G (숨겨진 방 개방)

### 골드 시스템
- 플레이어의 현재 골드 표시
- 구매 가능한 아이템은 밝은 색상으로 표시
- 구매 불가능한 아이템은 빨간색으로 표시

## 코드 구조

### shop.py
- `Shop` 클래스: 상점 메인 로직
- `ShopItem` 클래스: 아이템 정보
- `THEMES` 딕셔너리: 5가지 테마 정의
- `preview_shop_themes()`: 테마 선택 UI

### manager.py 통합
- `_show_shop()`: 상점 열기
- MAGIC_STORE 건물에서 호출
- 구매 결과를 `result_data`에 기록

## 테마 변경 방법

### manager.py에서 테마 변경
```python
# downtown/manager.py의 _show_shop() 함수에서:
shop = Shop(self.screen, theme="fantasy", freetype_fonts=self._freetype_fonts)
# theme 값을 변경: "cyberpunk", "fantasy", "steampunk", "nature", "luxury"
```

### 새 테마 추가
```python
# shop.py의 Shop.THEMES 딕셔너리에 추가:
"new_theme": {
    "name": "테마 이름",
    "name_en": "Theme Name",
    "description": "테마 설명",
    "primary_color": (R, G, B),
    "secondary_color": (R, G, B),
    "bg_color": (R, G, B),
    "style": "theme_style"
}
```

## 향후 개발 계획
- [ ] 아이템 판매 기능
- [ ] 아이템 카테고리별 필터
- [ ] 할인/특가 시스템
- [ ] 상점주 NPC 대화
- [ ] 퀘스트 아이템 잠금/해제
- [ ] 상점 레벨 시스템

## 사용 예시

```python
from downtown.shop import Shop

# 상점 생성
shop = Shop(screen, theme="cyberpunk", freetype_fonts=fonts)

# 플레이어 골드 설정
shop.set_player_gold(1000)

# 상점 열기
purchased_items, remaining_gold = shop.open(1000)

# 결과 처리
for item in purchased_items:
    print(f"구매: {item.name} - {item.price}G")
print(f"남은 골드: {remaining_gold}G")
```

## 주의사항
- 한글 폰트가 필요합니다 (NanumSquareB.ttf)
- pygame 및 pygame.freetype 모듈 필요
- 상점은 MAGIC_STORE 건물에서만 작동합니다
- 다른 건물에 적용하려면 manager.py의 `_run_building_event()` 수정

## 문의
상점 시스템 관련 질문이나 버그 리포트는 GitHub Issues에 등록해주세요.
