# 경로 서브 바람·표적 아이콘 작업 보고서

- 기준 지시문: `docs/tower_route_serve_wind_target_goal.md` (`d5fcab16233d1cb89ed42cab49134aca63760b82`)
- 작업 브랜치: `codex/tower-route-serve-wind-target-d5fc`
- 코드 종단 HEAD: `4314b21d4d4c87a1437ebe2b1e39af8d30ff038c`
- 통합·푸시: 하지 않음
- 판정: **GREEN** — S1~S5, 라이브 오너 물리 1회, 필수 게이트 모두 완료. `blocked=0`, `unverified=0`

## 1. 선행 워크트리 감사와 보전 판단

### `_live`

- 경로: `C:\Users\woduq\.codex\tmp\bosspong_tower_start_card_amend2_live`
- HEAD: `8cbc635ce020f5e9655621cd649c9871daf0fef4`, detached HEAD
- 실측 상태: 기본 compact 표기 2,055건. `-uall`로 개별 미추적 파일을 펼치면 2,362건(추적 변경 685 + 개별 미추적 1,677), staged 0건이다.
- reflog에는 워크트리 생성 시점의 HEAD 1건만 있고, 이 워크트리 고유의 작성 커밋은 없다.
- 본 작업의 선행 오너 3파일 해시는 이전 `_0c60` 검증 오버레이와 동일했다. 2천여 건은 특정 기능의 독립 작업물이 아니라 과거 라이브 부팅 검증을 위해 본 트리 상태를 통째로 덮은 오버레이로 판정했다.
- **판단: 브랜치를 만들거나 커밋하지 않고 그대로 보존.** 브랜치 이름만 붙여도 미커밋 파일은 보전되지 않으며, 이 상태를 커밋하면 다수의 무관 WIP를 이 세션의 작업으로 잘못 귀속한다. 감사 중 `_live`에는 쓰기·checkout·reset·clean을 전혀 수행하지 않았다.

### `_0c60`

- 경로: `C:\Users\woduq\.codex\tmp\bosspong_tower_start_card_amend2_0c60`
- 기존 브랜치 `codex/tower-start-card-amend2-0c60`은 `3184caa0667acf247b89ebd45b211d372211b4da`에 그대로 남겼다.
- 초기 미추적 2건은 d5fc 기준에서 추적 파일과 경로가 겹치는 캠프파이어 자산이었다. 먼저 아래 외부 경로로 원본을 보전한 뒤 재사용 워크트리를 만들었다.
  - `C:\Users\woduq\.codex\backups\tower_start_card_amend2_0c60_untracked_20260820`
  - PNG SHA-256: `4C56811CAA0036E8DC9CF206DC4C5FA548F8B3E60EB920A89DF6D3D3BFD94185`
  - import SHA-256: `6E6F8C5C7F8C91897E1E9F6C2203186864453560B5D86830ED3FF0CF85CBB11A`
- 약 10GB의 새 콜드 워크트리를 만들지 않고 warm `.godot` 캐시를 가진 `_0c60`을 재사용했다.
- 최종 상태: 브랜치 `codex/tower-route-serve-wind-target-d5fc`, clean.

## 2. 구현 결과와 커밋 매핑

| 슬라이스 | 커밋 | 결과 |
|---|---|---|
| S1 표적 아이콘화 | `7602b9ef1408f29c61685b7993e86d6a2f3b5fb2` | 경로 표적이 `tower_ascent_map_iconography.gd`의 기존 `build_map_icon_presentation()`을 재사용한다. 텍스처가 있으면 이름 문자열을 그리지 않으며, 누락 시에만 기존 오너의 fallback label을 보존한다. |
| S2 바람 상태 | `1f55adfa34281acfafdcbefae87dba0f23980de8` | `tower_ascent_route_wind_policy.gd` 신설. ROUTE_AIM 진입에서 gameplay RNG를 정확히 1회 소비하고 선택 종료까지 고정한다. |
| S3 풍향계 표시 | `5095af1b0ea5007e55f93a13ec925d3477241227` | 각도기 옆 절차형 풍향계. 무풍도 중앙 고리로 항상 보이며 좌·우 화살표와 1~3칸 강도를 표시한다. 신규 아트·문구는 없다. |
| S4 게이지 영향 | `0d19e4c6137ee88a765ee2b66dba957311c3b341` | 공 궤적이 아니라 각도기 왕복 범위의 중심을 바람 방향으로 이동한다. 범위 폭과 왕복 주기는 유지한다. |
| S5 씰 | `fa111e5522e6be3878eec07c1ba6aa0525f2f61a` | 단일 진입 롤, 프레임 고정, 60/40, 최대풍 도달 가능성, 궤적 비영향, 표적 이름 부정 레그를 봉인하고 CI/pre-push 목록을 lockstep 갱신했다. |
| 경고 교정 | `120e99644790a4417f7b8fecbbc184668d4c5a78` | 활성 강도칸의 filled `draw_rect`에 무의미한 width를 넘기지 않도록 분기해 Vulkan 러너 경고를 제거했다. |
| Vulkan·라이브 오너 QA | `4314b21d4d4c87a1437ebe2b1e39af8d30ff038c` | 2020×1246 강제 상태 캡처, 12프레임 스트립, 실제 `BattleSceneShell` 메타 오너와 생산 공 물리의 보정 명중을 한 wrapper로 고정했다. |

## 3. 확정된 바람 모델과 S4 판단

- 무풍 60%, 바람 40%.
- 바람일 때 좌/우를 같은 확률로 고르고, 강도 1/2/3도 같은 확률로 고른다.
- 강도표:
  - 약풍: 중심 편향 6°, 표시 비율 0.34
  - 보통풍: 중심 편향 12°, 표시 비율 0.67
  - 강풍: 중심 편향 18°, 표시 비율 1.00
- 바람은 결과를 바꾸는 gameplay RNG 소유이며 presentation RNG를 쓰지 않는다. 진입 롤 결과와 갱신된 RNG state는 스냅샷에 남는다.
- S4는 **왕복 범위 중심 이동**을 선택했다. 강풍 좌측 범위는 `-73°..37°`, 강풍 우측 범위는 `-37°..73°`이다. 기존 폭 110°와 주기 2.4초는 유지된다.
- 표적에 필요한 실제 각도는 약 `±17.745°`이므로 최대풍에서도 두 표적 모두 범위 안이다. “바람이 강하면 원하는 경로가 잠긴다”는 실패를 만들지 않으면서, 보이는 중심과 발사 타이밍이 달라져 조작 보정이 필요하다.
- 발사 뒤 `ball_vel`이나 공 스텝에는 바람을 적용하지 않는다. 동일 발사 각도의 비행 궤적이 바람 모델과 무관하다는 부정 레그가 GREEN이다.

## 4. 생산 경로와 검증

검증 경로는 다음 생산 오너를 통과한다.

`BattleSceneShell` 메타 키 → `TowerAscentFlowOwner.update_selective()` → 입력 스냅샷·플레이어 이동 → `TowerAscentRouteServeRuntime` → `BallMotionStepper`/`BallPhysics` → swept 표적 판정 → `MAP_TRANSITION`

표적 표시는 `TowerAscentFlowOwner`가 생성 노드 데이터를 `TowerAscentFlowRenderer.build_map_icon_presentation()`에 넘겨 만든 캐시를 실제 renderer가 그린다. QA 전용 표적 리터럴이나 별도 발사 화면은 제품 코드에 추가하지 않았다.

### 자동 게이트

| 게이트 | 결과 | 종단 증거 |
|---|---|---|
| 관련 스모크 6종 | GREEN 6/6 | `Smoke summary: PASS=6 FAIL=0 TOTAL=6` / `All Godot smoke tests passed.` |
| 신규 전용 씰 | GREEN | `tower_route_serve_wind_target_smoke: ok` |
| 변경 GDScript 9종 경고 스캔 | GREEN | `Godot warning scan passed with no GDScript warnings.` |
| 헤드리스 로드 | GREEN | `Godot headless load check passed.` |
| Vulkan 2020×1246 | GREEN | `tower_route_serve_wind_target_visual_qa: ok ...` / `Tower route wind and target Vulkan visual QA passed.` |
| scoped diff | GREEN | `git diff --check` 출력 없음 |
| CI/pre-push lockstep | GREEN | 신규 씰 리터럴 각 1건 |

관련 스모크 6종은 다음과 같다.

1. `tower_route_serve_wind_target_smoke.gd`
2. `tower_ascent_route_serve_smoke.gd`
3. `tower_ascent_data_driven_renderer_smoke.gd`
4. `tower_map_iconography_contract_smoke.gd`
5. `tower_ascent_vertical_slice_smoke.gd`
6. `tower_ascent_map_overlay_render_smoke.gd`

### Vulkan 캡처와 육안 판정

캡처 루트는 ignored 경로 `godot/.godot/codex_captures/tower_route_serve_wind_target/`이다.

- `route_wind_calm.png`: 무풍 중앙 고리, 비활성 강도칸, 각도기와 비겹침.
- `route_wind_max_left.png`: 좌향 화살표와 좌측 3칸, 게이지 중심 좌편향.
- `route_wind_max_right.png`: 우향 화살표와 우측 3칸, 게이지 중심 우편향.
- `route_target_icons.png`: 이름 문자열 없이 수호의 샘터·파계승 지도 아이콘이 큰 표적으로 표시된다. 중앙의 패배 보스 흔적과 겹치지 않는다.
- `route_wind_sweep_strip.png`: 강풍 우측 상태의 각도침 1주기 12프레임. 순차 이동과 되돌림이 끊기지 않는다.
- `route_live_compensated_aim.png`: 실제 진입 롤 `right/strong/+18°`에서 왼쪽 표적 각도 `-17.745°`를 기다린 보정 프레임.

육안 판정은 여섯 장 모두 GREEN이다. 아이콘·안내문·각도기·풍향계 사이 클리핑이나 겹침이 없고, 무풍/좌풍/우풍이 색뿐 아니라 형태와 위치로도 구분된다.

### 라이브 오너 1회

- 결정적 gameplay RNG 입력을 골라 **실제 ROUTE_AIM 진입 함수가** `right/strong/+18°`를 한 번 굴리게 했다. QA가 wind model을 결과로 주입한 것이 아니다.
- 실제 `BattleSceneShell`의 property list에 없는 `_get/_set` 메타 키를 사용했다.
- 바람을 본 뒤 왼쪽 표적의 물리 각도 `-17.745°`가 될 때까지 실제 왕복 게이지를 진행하고 입력 edge를 1회 발행했다.
- `debug_serve_toward()`는 사용하지 않았다. 생산 서브, 공 스텝, swept 충돌 판정이 왼쪽 노드 `floor_02_route_01_lane_01`을 선택하고 `MAP_TRANSITION`으로 전이했다.
- 결과: 원하는 표적 보정 명중 GREEN, `SCRIPT ERROR` 0건.

## 5. 분리 보고: 선재 전체 전투 QA 부채

초기 탐색에서 기존 `run_tower_route_serve_owner_meta_visual_qa.ps1`도 실행했다. 이 wrapper는 d5fc 격리 베이스의 전체 `MainScene`을 인스턴스화하면서 본 작업과 무관한 선재 임포트/API 드리프트(`energy_ball_renderer` 인자 수, `smasher_overdrive_ball_trail_renderer` 인자 수, `active_item_effect_query` bool 변환, Stage 4 Ponk ctex 및 다수 imported 자산 누락)를 만나 RED였다. 로그는 다음 위치에 보존했다.

`godot/.godot/codex_logs/tower_route_serve_owner_meta_visual_qa_51716_20260820010929822.log`

이 RED를 본 작업의 GREEN으로 오인하거나 삭제하지 않았다. 본 기능의 검증은 위 오류 모듈을 로드하지 않되 실제 shell 메타 오너·생산 flow·공 물리·renderer를 관통하는 전용 Vulkan wrapper로 분리했고 `SCRIPT ERROR` 0을 확인했다. 따라서 이 선재 부채는 S1~S5의 blocked/unverified가 아니며, 전체 전투 렌더 트랙에 귀속한다.

## 6. 통합 대기 상태

- 보고서 작성 직전 본 트리 실측 HEAD는 작업 시작 시의 `d5fcab162`에서 `7805939301ed77d1583cbcb986b21756ed21a822`로 진행했고, 사용자 WIP도 계속 존재한다.
- 요청대로 본 트리에 통합하지 않았다.
- `tower_ascent_flow_renderer.gd`를 공유하는 지도 카메라 추적 작업보다 이 커밋열을 먼저 통합해야 한다.
- 코드 종단 `4314b21d4`까지 격리 브랜치는 clean이며, 보고서 커밋을 더한 상태로 승인·통합 지시를 기다린다.
