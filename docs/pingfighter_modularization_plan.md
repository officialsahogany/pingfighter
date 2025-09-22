# pingfighter.py 모듈화 1차 계획 (2025-09-22)

## 현황 개요
- 파일 길이: 50,952 라인 / 최상위 함수 392개, 클래스 2개.
- 상단부터 `resource_path`, 렌더 헬퍼, 수백 개 전역 상태, 스테이지·아이템별 전역 세트, UI/메뉴 함수, `game_loop()` 등 모든 워크플로가 단일 스크립트에 집중.
- 헤더 기준 주요 블록: 기본 상수(≈L349), 전역 상태 정의(≈L913~2300), 일시정지/인벤토리/캐릭터 UI (≈L2319 이후), 코만도/스테이지 전용 전역 (≈L5222 이후), 스탑워치·총기 시스템 전역 (≈L6760 이후), `game_loop` 및 메뉴 UI (≈L48430 이후).
- `resource_path` / 렌더링 헬퍼 / UI 버튼 페인터 등 재사용 함수가 별도 모듈 없이 흩어져 있어 교차 참조 많음.

## 1차 분리 대상 (우선순위)
1. **게임 루프 & 전환 흐름 (`game_loop`, `show_start_screen`, `show_pause_menu` 계열)**
   - 새 패키지 `game_loop/` 내 `main.py`, `pause.py`, `character_select.py` 로 나눔.
   - 필수 의존성: 화면 갱신 함수(`draw_field`, `draw_objects`), 사운드 플레이어, 상태 변수.
   - 전역 사용 최소화를 위해 `GameContext`(dataclass) 초안 정의 → 메뉴 함수에 전달.
2. **상수 및 공용 리소스 핸들러**
   - `pingfighter/constants.py` 에 색상/치수/속도 상수 이전.
   - `resource_path` 등 유틸을 `pingfighter/utils.py` 로 이동 후 기존 호출부는 `from pingfighter.utils import resource_path` 로 교체.
3. **UI 컴포넌트 레이어**
   - `draw_pause_overlay`, `draw_modern_panel`, `get_rank_badge_surface` 등 순수 렌더 함수 → `ui/components/pause.py`, `ui/components/badges.py` 등으로 분리.
   - 렌더 함수는 `pygame.Surface` 기준 순수 함수로 재작성하여 테스트 가능성 확보.
4. **아이템/캐릭터 상태 묶음**
   - `active_item_slot`, `passive_item_list` 등 전역을 `game_state/items.py` 모듈에서 dataclass + reset 함수로 관리.
   - 기존 `items` 모듈과 상호작용 인터페이스 정리 (`ItemStateManager` 등).
5. **스테이지·스킬 전역 변수 그룹화**
   - Stage/Skill 별 전역 세트를 각각 모듈화 (`stage/stage4.py`, `stage/stage5.py` 등)하여 초기화/리셋 함수 제공.

## 진행 순서 제안
1. **컨텍스트/상수 추출 (소규모 PR) – 안전성 확보**
   - `pingfighter/context.py`에 `GameContext` (화면 Surface, clock, 전역 상태 참조) 정의.
   - `game_loop` 및 메뉴 함수 시그니처를 컨텍스트 기반으로 리팩토링.
   - 회귀: `pytest test_round_reset.py test_pause_menu.py` (필요 시 신규 테스트 작성).
2. **일시정지/옵션/캐릭터 UI 모듈화**
   - `ui/pause_menu.py`, `ui/options_menu.py`, `ui/character_manager.py` 생성.
   - 파라미터화한 컨텍스트/헬퍼에 의존하도록 이관.
   - 회귀: UI 렌더 관련 스냅샷 테스트 (`pytest test_rendering_ui.py::test_pause_menu_render` 등 추가 예정).
3. **아이템 상태 관리자 추출**
   - `game_state/items.py` 도입, 전역 제거 후 `ItemManager` 및 `Items` 모듈 연동 업데이트.
   - 신규 단위 테스트: `tests/test_item_state_manager.py` 작성.
4. **루프 외부 시스템 분리 (Stage/Effect)**
   - Stage 전역 초기화 함수를 모듈로 이동, `round_reset` 경로 업데이트.
   - Effects/Particles 공용 베이스 (`effects/base.py`) 추가 후 기존 함수 래핑.
5. **레거시 백업 파일 정리**
   - `legacy/` 폴더 생성, `bosspong_backup_*.py` 이동 및 `README` 안내 작성.

## 리스크 & 대응
- **광범위 전역 의존성**: 모듈화 과정에서 초기화 순서 문제 발생 가능 → 단계별로 `GameContext`에 명시적으로 주입.
- **테스트 부재 구간**: UI 함수 다수에 테스트 없음 → 스냅샷/표면 픽셀 검증용 보조 테스트 추가.
- **PyInstaller 경로 처리**: `resource_path` 위치 이동 시 import 경로 주의, 양쪽 실행 흐름에서 경로 검증 필요.

## 다음 단계 액션
- [ ] `pingfighter.py` 내 상수 및 전역 선언 영향도 정리 (컨텍스트 설계 초안 문서화).
- [ ] `GameContext` 설계 초안 작성 및 최소 참조 리스트 추출.
- [ ] `game_loop()` 호출부를 컨텍스트 기반 구조로 리팩터링하는 작은 패치 초안 준비.

