# Stage 7 Akamu R5 modular reintegration report

작성일: 2026-08-19

요청 기준 HEAD: `7c3be6a7695d6cf55403ef0825c04cf3dac56af6`

격리 워크트리: `C:\w\a7r5re`

통합 브랜치: `codex/stage7-akamu-r5-reintegration-7c3b`

## 1. 결론

`docs/stage7_akamu_r5_goal.md`의 L0~L5 계약을
`docs/stage7_akamu_r5_reintegration_goal.md`가 지정한 현재 소유자 모듈 위로
수동 이식했다. 이전 R5 브랜치를 merge하거나 전체 cherry-pick하지 않았다.
필요한 exact-HEAD 실행 계약도 현재 호출자/피호출자를 다시 추적해 hunk 단위로
선택했다.

P0~P5, 프로덕션·역방향 씰, 라이브 3판, 실제 Forward+ Vulkan 2020x1246 캡처
3장, 실제 오오라 사운드 재생, 변경 GDScript 경고 스캔, 헤드리스 로드,
CI/pre-push 락스텝, RNG 및 금지 경로 감사를 완료했다. 완료 판정은
`blocked 0`, `unverified 0`이다.

작업 시작 시 본 트리는 요청 기준 HEAD와 일치했고 dirty 5,008경로(수정 1,153,
미추적 3,855)였다. 모든 쓰기와 커밋은 격리 워크트리에서만 수행했다. 최종 보고서
작성 전 읽기 전용 스냅샷에서 본 트리는 다른 작업에 의해
`5f44e39ab3198751e56aa93ed505f4d3032fdc7b`로 이동했고 dirty 5,016경로(수정
1,154, 미추적 3,862)였다. 본 작업은 본 트리에서 stash, checkout, reset, merge,
cherry-pick, staging 또는 파일 쓰기를 하지 않았고 push하지 않았다.

## 2. 단계별 결과

| 단계 | 결과 | 프로덕션 계약과 증거 |
|---|---|---|
| P0 | 완료 | 정확한 기준 HEAD에서 `stage7_akamu_slice5_smoke.gd` 34건, `ball_boss_skill_pause_context_smoke.gd` 5건을 실패 문구별로 고정했다. 둘 다 `SCRIPT ERROR 0`이었다. |
| P1 | 완료 | `battle_frame_flow_deps_builder.gd`가 live pause context를 만들고 `battle_frame_flow_controller.gd`가 각성 freeze 소유자까지 전달한다. pause=true에서는 체인과 게이지 차감을 막고 pause=false에서는 정상 진행한다. |
| P2 | 완료 | swept ball-motion 순서에 바람 오오라를 연결하고, scene ball position/velocity와 이벤트 결과를 왕복시켰다. 분신 예약 우선권, 보스 소유 공, 하강 공, 디바운스, state 부재 역방향과 실제 block sound를 확인했다. |
| P3 | 완료 | `stage7_akamu_clone_state.gd`에서 개체 생성의 기존 motion RNG 뒤 마지막 호출로 `golden`을 1회 굴린다. 공 처치 결과가 `begin_dying()` 전에 golden/rect center를 담고 파사드가 신규 `stage7_akamu_starpoint_state.gd`에 무혼을 생성한다. 자연 소멸·보스 충돌은 드롭하지 않으며 공용 보상/흡인/정리 생명주기를 재사용했다. |
| P4 | 완료 | `stage7_akamu_superspeed_state.gd`의 단일 `COOLDOWN_SEC := 50.0`을 최초 해금과 재사용에 함께 쓴다. 각성 완료 직후 즉시 체인을 제거했고 각성 전 3장/후 4장 카드와 기본 한국어 포함 7개 지원 로케일 카피를 연결했다. |
| P5 | 완료 | 실제 `main.tscn` 독립 3판과 실제 프로덕션 렌더·오디오 소유자를 사용한 Forward+ 캡처를 완료했다. 임시 계측·캡처 스크립트는 검증 후 삭제해 변경 집합에 남기지 않았다. |

황금 확률은 R5 정본대로 `TEMP_GOLDEN_CHANCE := 0.50`, 처치당 무혼은
`TEMP_GOLDEN_MUHON_DROPS := 1`이다. 궁극기는 원본 25초/즉시 발동에서 승인된
50초 잠금으로 이탈했으며, 원본 값은 포트 계획 문서에 보존했다.

## 3. exact-HEAD 복구 hunk 판단

재통합 지시문의 세 과거 커밋은 통째로 적용하지 않고 현재 소비자 경로를 실행해
선택했다.

| 과거 커밋 | 채택 결과 | 판단 |
|---|---|---|
| `46b711127` | `30231a5a3`에서 resource loader, Stage 2 ambient, right-pillar portrait, active-item effect controller, Smasher 상태/씰의 필요한 hunk만 채택 | 현재 main 로드가 실제로 요구한 함수·인자 계약이었다. `active_item_catalog.gd` hunk는 첫 복구에서는 소비자 증거가 없어 보류했다. |
| `218fce0ac` | `012cfbd4c`에서 project renderer 설정과 energy/overdrive draw 계약을 채택 | 현재 draw 호출 arity와 초기 renderer 설정을 맞춰 헤드리스 main 로드 오류를 제거했다. |
| `16b0674d4` | `7b59f964e`에서 status, bomb, pingpong, prism renderer arity hunk를 채택 | 현재 ball draw facade가 호출하는 정확한 시그니처만 복구했다. |
| `46b711127`의 보류 hunk | `81c5fee8e`에서 hologram icon 상수 한 줄만 후속 채택 | fresh live `active_item_effect_renderer.gd -> TimerGaugeRenderer -> ActiveItemCatalog` 경로가 `HOLOGRAM_DISK_ICON_PATH`를 실제 요구함을 확인한 뒤 채택했다. 이로써 라이브 로그의 `SCRIPT ERROR 4`, `ERROR 1`을 0으로 줄였다. |

과거 브랜치의 단일 `stage7_akamu_state.gd` 구현, 사라진 소유 영역, 현재 소비자가
요구하지 않는 브랜치별 hunk는 채택하지 않았다. exact-HEAD 복구 4커밋은 R5 기능
커밋과 분리했다.

## 4. L3 라이브 3판 계측

각 판은 별도 fresh Godot 프로세스, 고유 로그, BelowNormal 우선순위로 실제
`main.tscn` Stage 7 매치를 진행했다. RESULT는 각성 완료 전환이 50초 쿨다운을
설정한 직후의 게이지 잔량이며, 세 판 모두 궁극기 비활성 상태와 serious error 0을
확인했다.

| 판 | 게이지 잔량 | 최초 쿨다운 | 궁극기 활성 | 스코어 | 실경과(초) | 로그 SHA-256 |
|---:|---:|---:|---|---:|---:|---|
| 1 | 234 | 50.000 | false | 4:0 | 55.547 | `C415C71EB6453CA91D009B08A90EFDAFBBA70C8DE306DF87C783072B3ED28016` |
| 2 | 177 | 50.000 | false | 4:0 | 68.448 | `ACA6A0B6843047AFCB0415C1BBA4E0A2A82F405EDAFF728FD418C5ACADD6E505` |
| 3 | 280 | 50.000 | false | 4:0 | 122.287 | `2728D5BABE7FB928E895CC7BB18C230D637F7BE45C7D29AD9E00A654AF61740F` |

로그:

- `C:\w\akamu_r5_reintegration_evidence\P5_L3_match1c_20260819T102627272Z_godot.log`
- `C:\w\akamu_r5_reintegration_evidence\P5_L3_match2b_20260819T102738831Z_godot.log`
- `C:\w\akamu_r5_reintegration_evidence\P5_L3_match3i_20260819T111218445Z_godot.log`

## 5. RED 문구별 대조

| 씰 | P0 기준 | 최종 | 감소 | 신규 문구 | 잔존 분류 |
|---|---:|---:|---:|---:|---|
| `stage7_akamu_slice5_smoke.gd` | 34건/고유 30 | 24건/고유 20 | 10건 | 0 | first-live/awakening 9, superspeed predictive dash/hold 12, ordinary Stage 7 dash gauge-owner 3 |
| `ball_boss_skill_pause_context_smoke.gd` | 5 | 2 | 3 | 0 | active-item tear-gas direct context compatibility/canonical alias 2 |

해소된 slice5 문구는 active-item/Star Coil pause 중 즉시 궁극기 체인과 게이지 보존,
분신·오오라 중첩 예약, motion-event context 오오라 전달, block sound, swept 오오라
우선순위, 보스 paddle 밖 반사, 상승 위협 역전이다. pause-context에서는 owner Star
Coil 플래그와 swept tear-gas compatibility/canonical 전달 3문구가 해소됐다.

최종 RED 두 실행은 모두 `SCRIPT ERROR 0`이며 신규 실패 문구가 없다. 잔존 항목은
P0에서 이미 존재했고 이번 R5 네 기능의 blocked/unverified가 아니라 각 표에 적은
별도 소유자 부채다.

## 6. Vulkan 및 실제 오디오 증거

실제 `main.tscn`, production Stage 7 state/renderers, production `game_audio`,
Forward+ Vulkan, root viewport 2020x1246을 사용했다. 로그와 메트릭은 exit 0,
`SCRIPT ERROR 0`, `ERROR 0`, `result=PASS`다.

| 장면 | 육안/실행 확인 | 파일 | SHA-256 |
|---|---|---|---|
| 황금 분신과 무혼 | 일반 분신과 구분되는 황금 분신 2기 및 중앙 무혼, clipping 없음 | `C:\w\akamu_r5_reintegration_evidence\P5_golden_clone_muhon_2020x1246_20260819 111811.png` | `ADE16B4B2D06C25686EFBE3604868061A7F80AFFDE8701250B2DC777457F5382` |
| 오오라 반사 순간 | 청록 오오라와 보스 부근 충돌 flash, 카드 rail clipping 없음 | `C:\w\akamu_r5_reintegration_evidence\P5_wind_aura_bounce_2020x1246_20260819 111811.png` | `8F14C2C634396AB02D40D30B013465C322D02EB282B04DC552C6913DE17934CE` |
| 각성 후 잠긴 궁극기 | 4번째 카드 노출, superspeed 비활성, cooldown 50.000, clipping 없음 | `C:\w\akamu_r5_reintegration_evidence\P5_post_awakening_locked_ultimate_2020x1246_20260819 111811.png` | `D84201D240DC7378E61B5B39712BD85A9A1F04B9A7BB96086D6695FF32055E06` |

메트릭은 `renderer=forward_plus`, `rendering_device=true`, requested/root
`2020x1246`, capture 3, HUD card 4, superspeed inactive/cooldown 50을 기록한다.
오오라 충돌 시 실제 stream은
`res://assets/sounds/stage7_akamu_aura_block.wav`였고
`audio_playing_after_collision=true`였다.

- 메트릭: `C:\w\akamu_r5_reintegration_evidence\P5_vulkan_metrics_20260819 111811.txt`, SHA-256 `05644AC1EFB4255FE0208CAE7264232A2316A3B7A760F978C1A3AC4690EC6610`
- Vulkan 로그: `C:\w\akamu_r5_reintegration_evidence\P5_vulkan_20260819T111809883Z_godot.log`, SHA-256 `101D8947F0FEF805754C2803CEA08AF1ECBBA7FDAD0CC0F9D855B552B7010BE9`

## 7. 최종 검증표

| 게이트 | 상태 | 결과 |
|---|---|---|
| R5/공용 소비자 집중 씰 | VERIFIED | 16/16 GREEN, 종단선 `All Godot smoke tests passed.` |
| 타워/Stage 7 양성 회귀 | VERIFIED | 14/14 GREEN, 종단선 `All Godot smoke tests passed.` |
| 변경 GDScript `-Paths` 경고 스캔 | VERIFIED | 37/37, warning 0 |
| `run_headless_load_check.ps1` | VERIFIED | graceful shutdown, PASS |
| `verify_agent_harness.ps1` | VERIFIED | interactive-play guard와 harness GREEN |
| CI/pre-push 락스텝 | VERIFIED | slice5, pause-context, golden-clone, unlock-cooldown 각각 양쪽 정확히 1회 등재 |
| Forward+ Vulkan/오디오 | VERIFIED | 3캡처, 2020x1246, 실제 audio playing, serious error 0 |
| RNG 소유권 | VERIFIED | renderer random call 0; 분신 golden은 기존 velocity/noise RNG 뒤 마지막 1회; starpoint는 렌더 RNG가 없고 주입된 authoritative RNG만 소비 |
| 금지 경로 | VERIFIED | 신규 asset 0, 임시 P5 tool 0, monolith 복원 0, merge/cherry-pick 0 |
| `git diff --check` | VERIFIED | PASS |
| blocked | VERIFIED | 0 |
| unverified | VERIFIED | 0 |

보존한 최종 텍스트 로그:

- `C:\w\akamu_r5_reintegration_evidence\P5_final_focused16_20260819T112953907Z.txt`
- `C:\w\akamu_r5_reintegration_evidence\P5_final_tower_stage7_positive14_20260819T113056211Z.txt`
- `C:\w\akamu_r5_reintegration_evidence\P5_final_warning_scan_20260819T113118673Z.txt`
- `C:\w\akamu_r5_reintegration_evidence\P5_final_headless_load_20260819T113130759Z.txt`
- `C:\w\akamu_r5_reintegration_evidence\P5_final_harness_20260819T113226322Z.txt`

추가 비게이트 탐색에서 `tower_ascent_boss_avoidance_smoke.gd`는 untouched
`tower_ascent_flow_renderer.gd`가 참조하는 미존재 타워/플라자/아이콘 asset preload로
실패했다. 같은 원인으로 생긴 compile cascade이며 R5 변경 경로·신규 실패가 아니다.
양성 타워 상태 씰인 `tower_ascent_run_state_smoke.gd`는 GREEN이다. 이 결과는 숨기지
않고
`C:\w\akamu_r5_reintegration_evidence\P5_baseline_tower_boss_avoidance_missing_assets_20260819.txt`
기준선 로그와 위 14/14 GREEN 로그로 분리했다.

## 8. 커밋 구성

1. `2fe304554` `test(stage7): freeze modular R5 debt baselines`
2. `8fa20a9e2` `fix(stage7): pass live pause context through awakening freeze`
3. `68213ed70` `fix(stage7): wire swept wind aura collision`
4. `30231a5a3` `fix(runtime): restore required exact-head load contracts`
5. `012cfbd4c` `fix(runtime): complete required exact-head draw contracts`
6. `7b59f964e` `fix(runtime): finish required exact-head ball draw arities`
7. `25e97b1cd` `feat(stage7): reintegrate golden clone Muhon drops`
8. `24b73acdf` `feat(stage7): gate ultimate behind shared cooldown`
9. `81c5fee8e` `fix(runtime): restore hologram icon catalog contract`
10. 최종 문서 커밋 — 본 보고서와 사전감사 표의 구현 정합성 갱신

모든 커밋은 로컬 격리 브랜치에만 있고 push하지 않았다.
