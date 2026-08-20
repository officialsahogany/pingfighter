# 탑 카드 선택 사용성 완료 보고

- 작성일: 2026-08-20
- 기준 본 트리 HEAD: `ec197813f`
- 격리 워크트리: `D:\main\bosspong_tower_card_pick_s1_d2bf`
- 격리 브랜치: `codex/tower-card-pick-s1-d2bf`

## 판정

- S1부터 S5까지 사용자가 본 트리에 통합했다. 격리 브랜치는 `ec197813f`로 리베이스하면서 이미 통합된 S2부터 S5 커밋을 중복 적용하지 않았다.
- S1-b의 60초 물리틱 타임아웃, 10초 카운트다운, 7개 로케일 안내, 무작위 활성 카드 자동 선택은 격리 브랜치에서 구조·Vulkan 게이트가 GREEN이다.
- S1-b의 실제 60초 무입력 라이브 플레이는 사용자 본 트리 확인 대상으로 남아 `unverified`다.
- 본 트리 통합과 푸시는 하지 않았다. 사용자 작업 트리의 헝크나 캐시도 가져오지 않았다.

## S2~S5 통합 이력

아래는 이전 격리 보고 당시의 슬라이스 커밋이다. 현재는 본 트리 `ec197813f`에 통합돼 있고 리베이스 과정에서 격리 브랜치의 중복 커밋은 제외했다.

| 슬라이스 | 커밋 | 내용 |
|---|---|---|
| S2 | `7ce271cf9` | 카드 설명의 조용한 행 폐기 제거 |
| S3 | `73b5e184d` | 설명 안 수치·배율·시간 강조 |
| S4 | `77699d215` | 무공/초식 종류별 흡수 목적지 |
| S5 | `aec21723a` | 기존 초식 구슬 툴팁을 탑 카드에 연결 |

## S1-b 시작 카드 카운트다운 개정

### 구현

- 타임아웃을 `60.0s`로 바꾸고, 프로젝트 물리 주기 72Hz에서 정확히 `4,320`틱으로 고정했다.
- 마지막 10초는 `720`틱이며, 남은 틱을 정수 초로 올림해 `10·9·8·7·6·5·4·3·2·1`만 노출한다. 11초에는 숨고 0은 표시하지 않는다.
- 타임아웃 권위는 idle `_process` delta나 벽시계가 아니라 `BattleSceneFrameController.process_physics()`가 한 번씩 전진시키는 틱 카운터다. 기존 `_elapsed_sec`는 카드 애니메이션용으로만 유지했다.
- 선택하지 않을 때 무작위 카드가 선택된다는 안내를 첫 카드 프레임부터 표시하고, ko/en/zh/ja/es/pt-BR/ru 7개 로케일을 등재했다.
- 자동 선택은 활성 카드 인덱스만 모은 뒤 전용 `RandomNumberGenerator`로 하나를 고른다. 활성 카드 1장은 그대로 선택되고 0장은 기존 `start_card_failsafe_auto_select_failed` 종료를 유지한다.
- 물리틱에서 흡수가 끝난 뒤 첫 idle 프레임이 로딩 hold를 재진입하지 않고 기존 랜딩 경로로 이어지도록 1회성 완료 표지를 추가했다.

### RNG 판정

독립 RNG를 선택했다. 무입력 타임아웃은 플레이어가 선택한 정상 진행이 아니라 예외 안전 경로이므로, 이때 게임플레이 RNG를 소비하면 같은 런 시드라도 60초 안에 눌렀는지 여부에 따라 이후 보상·연출 난수열이 갈라진다. 전용 RNG는 실제 세션 시작 때 `randomize()`하고, 씰에서는 고정 seed를 주입해 분산과 재현성을 함께 검증했다. 전역 RNG의 다음 값이 타임아웃 전후 동일하다는 단언도 통과했다.

### 씰과 반증

- 기존 `_verify_failsafe_autoselects_first_enabled_card`를 `_verify_failsafe_autoselects_random_enabled_card`로 개정했다. 폐지된 첫 활성 카드 고정 helper는 소스에서 0건이다.
- 새 물리틱 카운트다운 레그를 추가하고 공유 `_leg_count`를 `11`에서 `12`로 락스텝 갱신했다.
- 집중 씰은 `tower_start_card_smoke: ok`, `PASS=1 FAIL=0 TOTAL=1`, `All Godot smoke tests passed.`로 GREEN이다.
- 역방향으로 선택 인덱스를 잠시 `enabled_indices[0]`에 고정했을 때 `fixed-seed probes must select more than one enabled card across seeds`와 `random timeout selection must not stay locked to the first enabled card`가 RED였다. 독립 RNG 구현 복원 후 동일 씰이 다시 GREEN이다.
- 기존 `tower_start_card_smoke.gd`가 CI와 pre-push focused 목록에 이미 있으므로 신규 목록 항목은 필요하지 않았다.
- 최종 변경 GDScript 8개 warning scan은 경고 0건, headless load는 `[ApplicationQuitCoordinator] graceful headless shutdown complete`, `git diff --check`는 PASS다.

### Vulkan 캡처

기존 실경로 QA 하네스를 물리틱 소유권에 맞춰 갱신하고, 트리 진입 뒤 자동 처리를 끈 상태에서 수동 고정틱만 주입했다. 2020x1246 Forward Mobile/Vulkan 캡처 6장과 3개 캐릭터 실경로가 GREEN이다. 직접 확인한 10·5·1 프레임은 안내 문구와 정수 숫자가 모두 보이고 카드와 기존 선택 안내를 가리지 않는다.

| 프레임 | SHA-256 |
|---|---|
| `start_card_countdown_10.png` | `6311940C7587AA9F5A71FD166EEAA85066A74A6F45CA2AFEB38DD141EBE9D2D5` |
| `start_card_countdown_5.png` | `FDB418587C846ABF9946330672B134FD83C806B748614026450448F64F9B04EB` |
| `start_card_countdown_1.png` | `C2BE8854A51D32B2E91458F220B24DD047692F2183EDA6924C5CC4E58FE6126A` |

- QA 터미널: `tower_start_card_visual_qa: captures=6`, `countdown_captures=10,5,1`, `live_cases=3`, `tower_start_card_visual_qa: ok`.
- 콜드 빌드: smasher `1.029ms`, viper `0.767ms`, blacksmith `0.501ms`, 예산 `8.000ms`.
- 실제 60초 무입력 본 트리 플레이: **unverified, 사용자 라이브 확인 대상**.

## S1 시작 카드 타임아웃 통합 이력

본 트리 통합본을 기준으로 삼았다. 180초 유한 실패안전, 첫 활성 카드 자동 지급, 정상 선택과 같은 0.78초 흡수·저장 경로, 자동 선택 실패 시 소프트락 방지 종료가 이미 포함돼 있다.

- 구조 씰: 본 트리에서 GREEN이라고 사용자가 확인했다.
- 공유 씰 레그 수: 광맥결 레그가 합쳐진 본 트리 값 `11`을 그대로 유지했다. S2부터 S5는 새 독립 씰을 추가했으므로 이 상수를 다시 건드리지 않았다.
- 실제 180초 무입력 지급: **unverified, 사용자 본 트리 라이브 확인 대상**.

## S2 설명 잘림 해소

### 전수 조사

7개 로케일, 레벨별 2,016개 설명 샘플을 기존 2+3행 예산으로 재현했다.

| 로케일 | 잘린 샘플 수 | 최악 샘플 | 원본 행 / 폐기 행 / 폐기 문자 |
|---|---:|---|---:|
| ko | 85 | `four_poisons` Lv.5 | 16 / 11 / 178 |
| en | 60 | `neural_helmet` Lv.1 | 7 / 4 / 113 |
| zh | 10 | `unlock_yeonmyo_vision_bonghongwe` Lv.1 | 6 / 3 / 24 |
| ja | 35 | `neural_helmet` Lv.1 | 6 / 3 / 39 |
| es | 68 | `neural_helmet` Lv.1 | 8 / 5 / 138 |
| pt-BR | 65 | `neural_helmet` Lv.1 | 8 / 5 / 144 |
| ru | 84 | `neural_helmet` Lv.1 | 9 / 6 / 146 |

### 선택한 해법

- 카드 크기와 히트테스트 치수는 유지했다.
- 설명 시작 비율을 `0.595`에서 `0.585`, 높이 비율을 `0.375`에서 `0.415`로 조정했다.
- 모든 명시적 개행과 자동 줄바꿈 행을 append하고, 18px부터 기존 compact 하한 10px까지 영역에 맞는 가장 큰 글자 크기를 고른다.
- 수정 후 7개 로케일 모두 `discarded_rows=0`, `discarded_chars=0`, 영역 overflow 0이다. 10px 하한에 닿는 것은 한국어 3개 샘플뿐이다.

GRT-021 씰은 실제 append 행 수와 원본 행 수가 같은지 단언하고, 최대 행을 1로 줄인 반증에서 폐기를 RED로 잡는다. GRT-022 씰은 카드 크기 불변과 카드 상단 모서리의 그리기/클릭 히트테스트 일치를 유지한다.

- 구조 판정: **verified**.
- 최장 설명 실제 픽셀 프레임: **unverified, 사용자 라이브 확인 대상**.

## S3 수치 강조

- `runtime_perk_description_emphasis.gd` 한 곳이 숫자, 퍼센트, 배율, 시간 토큰을 분리한다.
- 시작 카드와 보상 카드는 공통 `_draw_per_card_descriptions()` 경로를 사용한다.
- 본문은 기존 `Color(50/255, 42/255, 34/255)`를 유지하고, 강조는 기존 갈색 강조선 색 `Color(96/255, 55/255, 26/255)`를 재사용했다.
- 7개 로케일의 detail/description 2,681개 문자열을 검사했다. 숫자 포함 샘플은 ko 292, en 63, zh 65, ja 78, es 63, pt-BR 63, ru 63이며 숫자가 본문 세그먼트에 남은 경우는 0이다.

- 구조 판정: **verified**.
- 실제 렌더 색 대비: **unverified, 사용자 라이브 확인 대상**.

## S4 흡수 연출 방향

- 공통 `tower_card_absorption_target_resolver.gd`가 카드 종류를 한 번 분류한다.
- 무공은 실제 뷰포트 하단 중앙 `Vector2(view.x * 0.5, view.y * 0.91)`로 간다. 2020x1246 씰의 목적지는 `(1010, 1133.86)`이다.
- 초식과 비전 초식은 기존 `runtime_perk_active_unlock_flight.gd`의 초식 슬롯 목적지를 그대로 쓴다.
- 시작 카드도 보상 카드의 30px 들어올림, 곡선 비행, 입자 경로를 재사용한다.
- 시작/보상 지속 시간은 모두 `0.78s`로 유지했고 도착점이 정확히 일치한다.
- 흡수 경로에 `randf`, `randi`, `randomize`, `seed` 호출이 없고 별도 게임플레이 RNG 상태도 전후 동일하다.

- 구조·경로 판정: **verified**.
- 흡수 중간 프레임과 체감 속도: **unverified, 사용자 라이브 확인 대상**.

## S5 초식 툴팁 연동

- 새 툴팁을 만들지 않았다. 기존 `smasher_skill_orb_tooltip_renderer.gd`가 카드 호버 상태도 받아 같은 제목, 비용·쿨타임, 조작 설명과 `skill_orb_tooltip_effect_preview_renderer.gd` 효과 미리보기를 그린다.
- 아직 장착되지 않은 카드 초식은 같은 스킬 설정 스냅샷의 정본 `skill_data`에서 해석한다.
- 시작 카드와 보상 카드가 같은 `_draw_hovered_tower_chosik_tooltip()` 브리지를 호출한다.
- 패널은 전체 카드 묶음을 피하는 좌, 우, 상, 하 후보를 순서대로 검사하고 실제 뷰포트 안에 클램프한다.
- GRT-044는 트리 안에서 `canvas.get_viewport_rect().size`를 우선하고, 트리 밖에서만 전달된 크기로 폴백한다.
- 2020x1246 구조 씰에서 시작 초식과 보상 비전 초식 패널이 세 카드와 모두 비중첩이고 화면 안에 있었다.
- `start_card_kind=mugong`인 반증 카드는 `unlocks_skill` 값이 있어도 툴팁 상태가 비어 있다.

- 구조·배치 판정: **verified**.
- 실제 호버 패널 픽셀과 효과 미리보기: **unverified, 사용자 라이브 확인 대상**.

## 자동 검증

각 신규 씰은 `.github/workflows/godot-ci.yml`과 `godot/tools/run_pre_push_checks.ps1`의 focused 목록에 함께 등재했다.

- S2 관련 스모크: `PASS=3 FAIL=0`, 종단선 `All Godot smoke tests passed.`
- S3 및 S2 회귀: GREEN, 종단선 확인
- S4 전용 및 시작 카드 회귀: GREEN
- S5 전용과 S4, 시작 카드, 기존 초식 툴팁 회귀 5종: `PASS=5 FAIL=0`, 종단선 확인
- 최종 S2부터 S5 및 시작 카드 통합 구조 묶음: `PASS=5 FAIL=0 TOTAL=5`, `All Godot smoke tests passed.`
- S2부터 S5 touched GDScript 11개 warning scan: 경고 0건
- headless load: `[ApplicationQuitCoordinator] graceful headless shutdown complete`, PASS
- `git diff --check`: PASS

`tower_reward_pick_smoke.gd`는 자체 종단선 `tower_reward_pick_smoke: ok`까지 도달한 뒤 기존 맵 아이콘 `.ctex` 누락으로 래퍼가 실패했다. 코드 반증 실패가 아니라 격리 캐시의 알려진 기준선 문제이며, 사용자 지시에 따라 캐시 보충이나 재시도를 하지 않았다.

## 남은 사용자 라이브 체크

1. 시작 카드 화면에서 60초 무입력 후 무작위 활성 카드가 실제 지급되고 흡수·저장되는지 확인한다.
2. 최장 설명 카드가 잘리지 않는지와 수치·배율·시간 강조 대비를 확인한다.
3. 무공은 하단 중앙, 초식은 해당 초식 슬롯으로 흡수되는지 확인한다.
4. 시작·보상 초식 카드 호버 패널이 카드와 겹치거나 화면 밖으로 잘리지 않는지 확인한다.

위 확인 전까지 격리 브랜치는 통합 대기 상태다.
