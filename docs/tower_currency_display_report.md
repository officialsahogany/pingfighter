# 탑 재화 표시 정리 작업 보고서

## 작업 기준과 격리

- 기준 커밋: `894c3e821b1f776aff0581ae3671da1e8f0db497`
- 격리 워크트리: `D:\main\bosspong_tower_audition_689b`
- 격리 브랜치: `codex/tower-currency-display-894c`
- 기존 Godot 임포트 캐시: 전환 전후 모두 524개 파일
- 선행 로그 백업: `D:\codex_backups\tower_currency_20260819_231542`
- 본 트리 통합, 리베이스, 푸시: 하지 않음

## S1. 표시면 전수 조사

아래 줄 번호는 코드 변경 전 기준 커밋 `894c3e821`의 위치다. `gold`, `골드`,
`muhon`, `무혼`, `balance`, `currency`를 GDScript에서 교차 검색하고 `.tscn`과
`.tres`도 별도로 검색했다.

| 표시면 | 생산 경로 | 실제 그리기 경로 | 현행 표시와 S2~S4 작업 |
|---|---|---|---|
| 보스 클리어 후 보상 선택 | `tower_reward_pick_offer_builder.gd:283-288`가 카드별 무혼 가격을 만들고 `tower_reward_pick_state.gd:238-275`가 보유 무혼 문구를 뷰 모델에 넣음 | `runtime_perk_overlay_renderer.gd:597-608`가 보유 무혼을 17px 텍스트로, `:650`이 카드별 가격을 그림 | S4에서 보유 무혼을 기존 무혼 아이콘과 더 큰 글꼴의 `아이콘 : N개` 행으로 변경. 카드 가격과 경제 로직은 유지 |
| 상점 | `tower_ascent_flow_economy_progress.gd:145-197`이 금화 가격, 부족 문구와 내부 `gold` 잔액 판정을 만듦 | 공용 노드 모달의 `tower_ascent_flow_renderer.gd:1331-1373`이 행동 행의 `cost_text`를 그림. 잔액은 공용 잔액 행에서 그림 | S2에서 표시 문자열만 `금화`로 변경. S3 공용 잔액 행 적용 |
| 수련장 | `tower_ascent_flow_economy_progress.gd:349-435`가 무혼 가격과 부족 문구를 만듦 | 공용 노드 모달 행동 행과 잔액 행 | 무혼 용어는 유지. S3 공용 잔액 행 적용 |
| 파계승 | `tower_ascent_fallen_monk_node.gd:125-174`, `:351-429`가 무혼 가격과 부족 문구를 만듦 | 공용 노드 모달 행동 행과 잔액 행 | 무혼 용어는 유지. S3 공용 잔액 행 적용 |
| 수호의 샘터 | `tower_ascent_guardian_spring_node.gd:156-165`, `:285-339`가 무혼 가격과 부족 문구를 만들며 무료 행동도 같은 행을 사용 | 공용 노드 모달 행동 행과 잔액 행 | 무혼 용어는 유지. S3 공용 잔액 행 적용 |
| 휴식 노드 | `tower_ascent_rest_node.gd:35-63`이 무료 행동과 기회의 보석 회복 문구를 만듦 | 공용 노드 모달 행동 행과 잔액 행 | 유료 재화는 없지만 공용 모달이라 두 잔액이 노출됨. S3 공용 잔액 행 적용 |
| 노드 모달 공용 잔액 | `tower_ascent_node_modal_state.gd:131-155`가 `KEY_BALANCE_MUHON`과 `KEY_BALANCE_GOLD`를 실제 잔액에 적용 | `tower_ascent_flow_renderer.gd:1267-1277`의 두 고정 사각형과 `:1312-1328`의 채움·테두리 뱃지 드로어 | S2에서 금화 현지화. S3에서 가로 행 재산출, 채운 박스와 테두리 제거, 대비용 텍스트 외곽선 적용 |
| 런 결산 | `tower_ascent_settlement_state.gd:137-163`의 `build_lost_build_summary()`가 `muhon`과 `gold`를 읽고 한글 문구를 하드코딩 | `tower_ascent_flow_renderer.gd:1628-1677`이 `lost_build_rows`를 최대 6행으로 그림 | S2에서 새 결산 현지화 키를 모든 지원 언어에 등록하고 하드코딩 제거 |
| 전투 중 탑 무혼 HUD | `stage1_pillar_hud_scene_drawer.gd:592-612`가 이미 준비된 탑 flow의 실제 `muhon` 잔액만 읽음 | `stage1_pillar_ui_renderer.gd:375-414`가 기존 무혼 도형 아이콘과 수치를 필러에 그림 | 이미 아이콘과 큰 수치로 표시되며 이번 요구의 보상 선택 화면이 아님. 변경 없음 |
| 지도 오버레이 | `tower_ascent_flow_renderer.gd:171-307`의 지도 모델과 `:352-426`의 지도 드로어를 확인 | 지도 제목, 노드, 경로만 그리며 재화 문자열이나 잔액 행을 소비하지 않음 | 표시 지점 없음. `tower_ascent_flow_map_progress.gd:306-319`의 `balances`는 지도 표시가 아니라 보상 선택 컨텍스트 전달용 |

### 제외 및 음성 확인

- `.tscn`과 `.tres`에서 여섯 검색어의 탑 재화 표시 문자열은 0건이었다. 이번
  표시면은 모두 GDScript 뷰 모델과 드로어가 소유한다.
- `character_info_overlay_header_presenter.gd:25-38`에는 퍽 골드 문자열 생성기가
  남아 있지만, 실제 `draw_header()`는 `:116-119`에서 그 표시줄을 의도적으로
  제거하고 빈 결과를 반환한다. 현재 플레이어에게 노출되지 않으며 탑 런 재화도
  아니므로 변경하지 않는다.
- `stage1_pillar_hud_scene_drawer.gd:588-590`과
  `stage1_pillar_ui_renderer.gd:344-372`의 금색 카운터는 광장·퍽 골드다. 탑 런
  `gold`가 아니므로 `금화` 용어 금지 씰과 이번 레이아웃 변경에서 제외한다.
- `runtime_perk_overlay_renderer.gd:2055`의 `무공 골드`와 그 밖의 퍽 골드 문구도
  별도 재화이므로 제외한다.
- 노드 모달 포인터 경로 `tower_ascent_node_modal_state.gd:86-122`는 행동 행
  `get_action_rects()`만 히트테스트한다. 잔액 행은 클릭 대상이나 입력 소비자가
  아니므로 GRT-022 상단 모서리 클릭 반증은 적용 대상이 아니다.

## S2. 탑 금화 용어와 결산 현지화

- 노드 모달의 `KEY_BALANCE_GOLD`, `KEY_COST_GOLD`,
  `KEY_INSUFFICIENT_GOLD`를 한국어 `금화`로 바꿨다.
- 세 키를 한국어, 영어, 중국어, 일본어, 스페인어, 브라질 포르투갈어,
  러시아어 블록에 모두 등재했다. 영어는 기존 의미대로 `Gold`, 일본어는
  `金貨`를 사용한다.
- 결산의 하드코딩 행을 `KEY_LOST_BUILD_CURRENCY_ROW`로 옮기고 같은 7개
  언어 블록에 등재했다. 한국어 결과는 `무혼 17 · 금화 91`이다.
- 내부 `gold` 딕셔너리 키, 가격, 잔액 판정, 저장 형식은 바꾸지 않았다.
- 부분 번역 블록이 전체 번역 완료로 오인되지 않도록 누락 로케일 검사는
  한국어 정본의 모든 키 존재 여부를 계속 확인한다.
- 한국어 카탈로그에 엠대시는 0건이다.

S2 집중 검증은 노드 모달, 상점, 결산 스모크 `PASS=3 FAIL=0`과 5개 변경
GDScript의 집중 경고 스캔 0건으로 통과했다. 스모크는 7개 지원 언어의 세 금화
키와 결산 재화 행을 실제 로케일 오버라이드로 순회한다.

## S3. 노드 모달 잔액 행

- 기준 행을 `Rect2(170, 240, 420, 42)`로 다시 잡고, 36px 간격을 뺀 폭을
  반으로 나눠 무혼과 금화 항목 폭을 각각 192px로 파생했다. 화면 스케일과
  오프셋은 기존 노드 모달 화면 레이아웃을 그대로 사용한다.
- 각 항목은 `아이콘 20px + 간격 10px + 현지화 문구`의 한 가로 행이다.
  무혼은 기존 `CommonStarpointVisualHost.draw_muhon_fallback()`을 재사용하고,
  금화는 기존 필러 HUD의 코드 기반 동전 구성을 사용한다. 신규 아트 자산은 없다.
- 이전 `Color(PAPER_DEEP, 0.62)` 채움과 금색 사각 테두리를 모두 제거했다.
  밝은 바탕과 어두운 바탕 모두에서 읽히도록 18px 먹색 글자에 종이색 2px
  외곽선을 둔다. 외곽선 크기와 모든 내부 좌표는 기준 상수와 화면 스케일에서
  파생한다.
- 잔액 행은 입력 대상이 아니다. 집중 스모크가 두 항목의 상단 모서리를 실제
  `select_at_position()`에 넣어 행동 행으로 선택되지 않음을 반증한다. 행동 행의
  기존 상단 모서리 히트테스트도 함께 통과했다.

S3 집중 스모크는 포인터·레이아웃과 노드 모달 셸 `PASS=2 FAIL=0`, 변경
GDScript 2개의 집중 경고 스캔은 0건이다. 기존
`tower_ascent_phase_c_node_visual_qa_contract_smoke.gd`의 기준점 RED도 별도로
재현했으며, 이 브랜치 변경과 무관한 누락 문자열 정적 단언이다. 전체 관문에서는
범위와 판정을 다시 분리한다.

## S4. 보상 선택 무혼 보유 행

- 보상 선택 문구를 한국어 `무혼 : {amount}개`로 바꿨고 7개 언어 모두 콜론과
  각 언어의 자연스러운 수량 표기를 사용한다.
- 기존 17px 텍스트 한 줄을 공용 무혼 도형 아이콘과 26px 기준 글꼴의 전용
  행으로 교체했다. 최소 글꼴 21px, 아이콘 크기, 아이콘 뒤 간격, 행 높이,
  외곽선은 모두 26px 기준 글꼴에서 파생한다.
- 실제 렌더러가 `build_tower_reward_balance_rows()`에서 append한 배열을 그대로
  순회한다. 2020×1246, 4카드, 능력치 띠 활성 경계에서 실제 append 수는 1이고
  행 전체가 뷰포트 안에 있다.
- GRT-021 역방향 레그는 220×80과 긴 잔액 문구를 넣었을 때 잘린 행을 그리지
  않고 실제 append 수가 0임을 단언한다. GRT-054 파생 상수와 두 행 수 단언은
  같은 생산 계산 함수를 사용한다.

S4 집중 스모크는 보상 선택, 공용 전통 카드 UI, 10행 능력치 띠
`PASS=3 FAIL=0`, 변경 GDScript 3개의 집중 경고 스캔은 0건이다.

## S5. 용어 금지 씰

- `tower_currency_display_term_ban_smoke.gd`가 `scripts/tower_ascent`의 모든
  GDScript와 공용 HUD 드로어의 실제 탑 보상 표시 함수 구간에서 플레이어 노출
  문자열을 검사한다.
- 한국어 `골드`가 다시 들어가면 실패한다. 내부 ASCII 호환 식별자 `gold`,
  딕셔너리 키, 함수명은 검사 대상 문자열에서 제외한다.
- 별개 재화인 `퍽 골드`, `무공 골드`는 명시적으로 허용한다.
- 반증 레그는 가짜 표시 문자열 `"골드 10"`을 검출해 RED가 되는지, 내부
  `gold`와 두 예외 문구는 GREEN인지 함께 확인한다.
- 씰을 단독 통과시킨 뒤 `.github/workflows/godot-ci.yml`과
  `godot/tools/run_pre_push_checks.ps1`에 각각 정확히 한 번 등재했다. 두 목록은
  각각 172개이며 차이가 없다.
- Vulkan 픽스처의 상점 표기도 `골드`에서 `금화`로 고쳤고, 보상 캡처 잔액은
  요구 예시를 직접 확인하도록 7로 고정했다. 제품 경제값이나 가격은 바꾸지 않았다.

## 실제 로케일 전환 결과

노드 모달과 결산 스모크에서 로케일 오버라이드를 실제로 바꿔 카탈로그 경로의
결과를 확인했다. 아래 값은 잔액 91, 무혼 17을 넣은 결과다.

| 로케일 | 잔액 | 비용 | 결산 요약 |
|---|---|---|---|
| 한국어 | `금화 91` | `91 금화` | `무혼 17 · 금화 91` |
| 영어 | `Gold 91` | `91 Gold` | `Muhon 17 · Gold 91` |
| 일본어 | `金貨 91` | `91 金貨` | `武魂 17 · 金貨 91` |

세 언어뿐 아니라 등록된 7개 로케일(KO, EN, ZH, JA, ES, PT-BR, RU)을 모두
순회했으며 누락 키는 0건이다.

## Vulkan 실화면 증거

두 QA 래퍼 모두 Godot 4.6.2 Forward Mobile/Vulkan, RTX 5070에서 실행했다.
노드 모달 래퍼는 6장, 보상 선택 래퍼는 3장을 만들고 각각 `ok`로 끝났다.

| 장면 | 해상도 | SHA-256 | 확인 결과 |
|---|---:|---|---|
| `.godot/codex_captures/tower_ascent_phase_c/shop.png` | 2020x1246 | `37C1BEAD74240994FEB314CE660912596E5BA1848546AF397CA733F204D0E17A` | 밝은 상점 배경, 무혼·금화 가로 정렬, 박스 없음 |
| `.godot/codex_captures/tower_ascent_phase_c/training.png` | 2020x1246 | `5E211D7F290445DAEF32204CADEA3E522F2CD41D1E6C8C3B68E3DA12369A8D18` | 어두운 수련장 배경, 같은 행의 대비 확인 |
| `.godot/codex_captures/tower_reward_pick/four_card_reward_pick.png` | 2020x1246 | `2922206D86CEAA17ABB109E7CC5E409633BB58B95E41EB4AF1973D8B5166C575` | 확대된 무혼 아이콘과 `무혼 : 7개` 확인 |

## 최종 검증

| 게이트 | 결과 |
|---|---|
| 변경 GDScript 13개 `run_warning_scan.ps1 -Paths` | GREEN, 경고 0건 |
| 요청 표시면 집중 스모크 11개 | `PASS=11 FAIL=0 TOTAL=11` |
| 배치 종단선 | `All Godot smoke tests passed.` |
| 요청 집중 배치 `SCRIPT ERROR` | 0건 |
| `run_headless_load_check.ps1` | GREEN, 정상 종료 표식 확인 |
| Vulkan 2020x1246 캡처 | GREEN, 9장 생성, 위 3장 육안 확인 |
| `git diff --check` | GREEN |
| 요청 게이트 blocked/unverified | 0건 |

추가로 범위 밖 저장소 전체 게이트도 진단했다. 전체 경고 스캔은 이 브랜치가
수정하지 않은 `active_item_effect_renderer.gd:78`에서
`TimerGaugeRenderer.HOLOGRAM_DISK_ICON_PATH`를 해석하지 못하는 기존 오류로
RED였다. 전체 172개 집중 목록은 `PASS=151 FAIL=21 TOTAL=172`이며 21건은 캐릭터
정보, 잭팟, 리소스 사이드카, 매치 스킬 의존성, Stage 7 결과, Odin, 플레이필드,
광장, 수호령/탈것 등 이번 재화 표시 변경 밖의 기존 실패다. 본 트리의 해당
파일에는 다른 세션의 미커밋 수정이 있어 복사하거나 함께 고치지 않았다. 따라서
이 결과는 요청 범위 GREEN과 분리해 기록한다.

## 캐시·커밋·통합 상태

- 기존 격리 워크트리의 524개 임포트 캐시를 그대로 재사용했다.
- 전체 경고 진단에 필요한 단 하나의 누락 캐시만 본 트리에서 선별 시드했다.
  원본 PNG SHA-256은 양쪽 모두
  `3CE74C6BA42DE0D4ED9F144016107528511B33E3CF2E75AB3A357827BB4E4CF8`,
  `.import` 설정 SHA-256은 양쪽 모두
  `9CCF701E6CFB5FAB2A3F0A0C99CDBC19F2649262F41CEC13404F22D017C7A7BD`였다.
  복사한 `.ctex`의 양쪽 SHA-256은
  `A208EB53A7AE227A5707D93F04F06DCCF46850AEB258B9BCC5AAA8A6B1867D99`이며,
  현재 캐시 파일 수는 525개다. 통짜 캐시 복사는 하지 않았다.
- S1~S4 커밋은 각각 `af004d251`, `22dd5f681`, `ecbca143f`, `b7503d9a6`이다.
  S5와 이 최종 보고서는 다섯 번째 독립 커밋으로 묶는다.
- 기준 커밋은 `894c3e821b1f776aff0581ae3671da1e8f0db497`이며, 브랜치는
  `codex/tower-currency-display-894c`다.
- 본 트리 통합과 푸시는 하지 않았다. 보고 후 지시를 기다린다.
