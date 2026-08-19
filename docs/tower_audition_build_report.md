# 오디션 제출 빌드 작업 보고서

## 결론

- 격리 브랜치에서 S1~S6의 사용자 가시 동작을 구현했다.
- 실제 프로덕션 전환 경로로 1층부터 7층까지 한 런을 완주했다. 8회 전투가 모두
  `source_status=ported`였고, 임시/껍데기 보스는 0회였다.
- 7층 클리어는 새 종료 경로가 아니라 기존 표준 클리어 판정과 런 정산을 사용했다.
- **본 트리 통합 후 익스포트 필요**. 사용자의 2026-08-19 후속 지시에 따라 이
  격리 워크트리에서는 익스포트 빌드와 실행 검증을 하지 않았다.

## 작업 기준과 격리

- 기준 커밋: `689bba2ee6f4047f3bcb632d0111a09504010922`
- 격리 워크트리: `D:\main\bosspong_tower_audition_689b`
- 격리 브랜치: `codex/tower-audition-689b`
- 리베이스/푸시: 하지 않음
- 본 트리의 dirty/untracked WIP와 Godot 편집기: 수정하거나 종료하지 않음
- 선행 로그 백업: `D:\codex_backups\tower_audition_20260819_212531`

작업 커밋은 다음과 같이 분리했다.

1. `33b82bd72` — 캠프파이어 아이콘 의존 자산 등재
2. `cdd09d3f4` — 1~7층 오디션 구성과 역방향 레그
3. `c001ec21a` — 기준 커밋에서 누락된 라이브 인스턴스 계약 복원
4. `da653438c` — 실제 1~7층 Vulkan 완주/캡처 QA

## S1~S6 구현 결과

### S1. 1층 선택 행

- 오디션 게이트 ON일 때 1층에도 표준 2후보 선택 행을 생성하고 총 행 수를 함께
  보정한다.
- 진입 노드와 첫 후보 ID는 그래프의 첫 두 행 및 생성된 edge에서 파생한다.
- 사용자 가시 순서는 `1층 시작 보스 -> 1층 선택 행`이다. 기존 프로덕션 flow는
  탑 진입 전에 끝낸 실제 전투를 `entry_node_id`의 승리로 결산하므로, 지시문의
  문자 그대로 선택 행을 수문장 앞에 두면 비전투 노드를 전투 승리로 기록한다.
  따라서 생성된 1층 수문장을 entry로 유지하고, 그 outgoing 후보를 생성된 1층
  선택 행으로 파생했다. 실제 캡처로 1층 클리어 직후 1층 선택 행 노출을 확인했다.

### S2~S3. 1~3층 보스 풀과 시작 다양화

- 기존 등록 풀 9종을 유지한다.
  - 1층: 달지, 각시탈, 포도대장
  - 2층: 청린귀, 두더지왕, 아라크네
  - 3층: 환묘 연묘, 테디베어, 엘리스
- `map_seed` 전용 `RandomNumberGenerator`로 층별 슬롯을 결정론적으로 섞는다.
- 시작 전투와 생성 그래프의 1층 entry가 같은 시드 슬롯을 사용한다.
- seed 1/3/4의 실제 시작 전환에서 각각 각시탈/달지/포도대장을 확인했다.

### S4. 4~7층 선형 진행

- `TEMP_AUDITION_LINEAR_FLOORS`가 켜진 동안 선택 행은 비전투 후보만 만들고,
  전투 슬롯은 `ported`만 필터링한다.
- 실제 완주 관문은 퐁크 -> 홍련 -> 테트리서 -> 아카무 리고였다.
- 4~7층의 임시 슬롯은 실제 후보/전투에 한 번도 진입하지 않았다.

### S5. 7층 종료

- 활성 표준 클리어 층을 7층으로 바꾸고 8~12층은 잠긴 phase metadata로만 남긴다.
- 7층 관문 승리 후 기존 `begin_floor_nine_resolution` 판정과 기존
  `begin_run_settlement` 조립 계약을 재사용한다.
- 실제 정산 결과: `result_kind=standard_clear`, `floor=7`,
  `highest_floor=7`, `clear_count=1`.

### S6. 제출 빌드 기본 탑 모드

- Windows export preset에 `tower_audition` feature를 부여했다.
- master gate와 export feature가 모두 있을 때만 기본 탑 모드가 된다.
- 에디터/개발 실행은 기존처럼 환경변수 opt-in이며, 명시적 환경변수 OFF가
  제출 기본값보다 우선한다.

## 되돌리기 상수 표

정본은 `godot/scripts/tower_ascent/tower_audition_build_config.gd`이다.

| 항목 | 현재 정확한 값 | 오디션 뒤 되돌리기 |
|---|---|---|
| 전체 master gate | `TEMP_AUDITION_BUILD_ENABLED := true` | **`false`로 변경**. 이것 하나로 표준 9층, 일반 보스 풀, 개발 opt-in 동작 복원 |
| export feature 이름 | `TEMP_AUDITION_EXPORT_FEATURE := "tower_audition"` | master OFF 뒤 dormant. 위생상 Windows preset의 `tower_audition`도 제거 가능 |
| 오디션 클리어 층 | `TEMP_AUDITION_CLEAR_FLOOR := 7` | master OFF이면 사용되지 않고 `STANDARD_CLEAR_FLOOR := 9`가 복원됨 |
| 선형 층 | `TEMP_AUDITION_LINEAR_FLOORS: Array[int] = [4, 5, 6, 7]` | master OFF이면 사용되지 않음 |
| 표준 클리어 층 | `STANDARD_CLEAR_FLOOR := 9` | 변경하지 않음 |
| Windows export feature | `custom_features="tower_audition"` | 오디션 제출 종료 후 feature 문자열 제거 |

## 검증 증거

### 스모크, 경고, 로드

- 오디션 영향권 집중 배치: `PASS=14 FAIL=0 TOTAL=14`
- 배치 종단선: `All Godot smoke tests passed.`
- 집중 배치에는 오디션 전용 스모크, 12층/2-phase 역방향 레그, 맵 생성,
  보스 회피/라우팅, 9층 기존 종료, 정산, 시작 카드, route serve를 포함했다.
- 탑 이름 전체 42개도 추가 실행했다: `PASS=40 FAIL=2 TOTAL=42`.
  두 RED는 이번 diff 밖의 기준 커밋 정적 씰이다.
  - `tower_ascent_flow_owner_refactor_smoke.gd`: 실제 eager `.new()`는 20개인데
    오래된 씰이 19개를 고정 단언한다.
  - `tower_ascent_phase_c_node_visual_qa_contract_smoke.gd`: 기존 QA 소스에 없는
    `BattlePlayfieldSceneDrawer` 문자열을 고정 단언한다.
  이 두 파일과 그 대상 소스는 오디션 구현에서 수정하지 않았다.
- 수정 GDScript 28개 focused warning scan: 경고 0건.
- `tools/run_headless_load_check.ps1`: `Godot headless load check passed.`
- PowerShell QA wrapper parser: PASS.
- `git diff --check`: PASS.
- 전체 1,385개 nightly smoke를 완료했다는 주장은 하지 않는다.

### 실제 시작 다양화

| 목표 | 시드 | 실제 슬롯/variant | 로그 |
|---|---:|---|---|
| 각시탈 | 1 | `floor_01_gaksital` / `gaksi` | `.godot/codex_logs/tower_audition_live_startup_gaksi_49936_20260819124700783.log` |
| 달지 | 3 | `floor_01_dalji` / `dalji` | `.godot/codex_logs/tower_audition_live_startup_dalji_23380_20260819124801120.log` |
| 포도대장 | 4 | `floor_01_podo` / `podo` | `.godot/codex_logs/tower_audition_live_startup_podo_14172_20260819124904181.log` |

### 실제 1~7층 완주

- 최종 GREEN 로그:
  `.godot/codex_logs/tower_audition_live_full_gaksi_50656_20260819131312874.log`
- 터미널:
  `tower_audition_live_qa: full_run_ok combats=8 gate_floors=[1, 2, 3, 4, 5, 6, 7] blocked_shells=0`
- 실제 전투 순서:
  - 1층 각시탈(관문)
  - 2층 청린귀(관문)
  - 3층 환묘 연묘(선택 전투), 엘리스(관문)
  - 4층 퐁크, 5층 홍련, 6층 테트리서, 7층 아카무 리고(관문)
- 모든 encounter가 `source_status=ported`; fallback/stand-in은 0.
- 최종 로그의 `SCRIPT ERROR`는 0건이다. wrapper가 별도 집계한 165건의
  resource 오류는 이 격리 트리에 없는 `d708b16c9` 자산과 불완전 import cache에
  한정되며, 라우팅/판정 종단선과 분리해 보존했다.
- 증거 JSON:
  `.godot/codex_captures/tower_audition/tower_audition_live_evidence.json`
- 사용자 실제 save와 분리하기 위해 wrapper가 이 프로세스의 `APPDATA`만 고유한
  `.godot/codex_userdata/...`로 리디렉션하고 종료 시 호출자 환경을 복원했다.

### Vulkan 캡처 육안 확인

세 파일은 모두 3072x1670이며 실제 렌더를 육안 확인했다.

| 캡처 | SHA-256 |
|---|---|
| `.godot/codex_captures/tower_audition/floor_01_choice_map.png` | `02B2129321C50774AAE386675123DFDF808B70F106DEB7B4027541417E96E24B` |
| `.godot/codex_captures/tower_audition/floor_04_to_07_battle.png` | `BDC08E5797975A8DA3A7FCE096F11015C43379C355B0943327A345DCD8E9193F` |
| `.godot/codex_captures/tower_audition/floor_07_clear_settlement.png` | `E05B08F8EAD6FF7DD6E820A381069319C5D5174EF0EA174DA63EADF2AD656AC9` |

## 익스포트 대체 지시와 본 트리 통합

본 트리의 `d708b16c9`에는 이 워크트리에 없는 런타임 자산 43종과 `.import`
43종이 있다. 따라서 이 격리 워크트리의 PCK는 제출물이 될 수 없고, 사용자의
후속 지시대로 `tools/build_windows.ps1 -Mode Release`를 실행하지 않았다.

통합 시 다음을 지킨다.

1. 리베이스하지 말고 본 트리의 `d708b16c9` 및 후속 자산을 유지한 채 이
   브랜치를 통합한다.
2. `godot/export_presets.cfg` 충돌 시 본 트리의 최신 preset 설정을 보존하면서
   Windows 제출 preset에 `tower_audition` feature를 합친다.
3. `c001ec21a`의 아래 exact-head 계약 파일은 본 트리에 동등하거나 더 최신인
   구현이 이미 있으면 **본 트리 버전을 우선**한다. 커밋이 patch-equivalent로
   비면 건너뛰어도 된다.
4. `campfire_icon_hq_v1.png`와 `.import`는 `33b82bd72`에서 등재했으며,
   사용자 확인대로 `d708b16c9`에서 제외되어 자산 충돌이 없다.
5. `.godot/codex_*` 로그·캡처·격리 사용자 데이터는 추적 파일이 아니므로
   통합하거나 제출 PCK에 포함하지 않는다.
6. 통합한 본 트리의 완전한 캐시/자산 상태에서 Release export 후 exe를 직접
   실행하여 기본 탑 진입과 PCK의 43종 자산 포함을 최종 확인한다.

### 통합 주의 파일

오디션 구성 핵심:

- `godot/export_presets.cfg`
- `godot/scripts/tower_ascent/tower_audition_build_config.gd`
- `godot/scripts/tower_ascent/tower_ascent_feature_flags.gd`
- `godot/scripts/tower_ascent/tower_ascent_map_generator.gd`
- `godot/scripts/tower_ascent/tower_ascent_boss_registry.gd`
- `godot/scripts/tower_ascent/tower_ascent_flow_state.gd`
- `godot/scripts/tower_ascent/tower_ascent_flow_map_progress.gd`
- `godot/scripts/tower_ascent/tower_ascent_flow_runtime.gd`
- `godot/scripts/tower_ascent/tower_ascent_flow_ending_progress.gd`
- `godot/scripts/tower_ascent/tower_ascent_ending_state.gd`
- `godot/scripts/core/battle_scene_match_flow_driver.gd`
- `godot/scripts/core/battle_scene_selection_startup_lifecycle.gd`
- `godot/scripts/core/game_selection_state.gd`

본 트리 최신 버전 우선 exact-head 계약:

- `godot/scripts/ball/energy_ball_renderer.gd`
- `godot/scripts/ball/smasher_overdrive_ball_trail_renderer.gd`
- `godot/scripts/characters/smasher_overdrive_state.gd`
- `godot/scripts/hud/right_pillar_portrait_renderer.gd`
- `godot/scripts/items/active_item_catalog.gd`
- `godot/scripts/items/active_item_effect_controller.gd`
- `godot/scripts/resources/project_resource_loader.gd`
- `godot/scripts/stages/stage2/stage2_ambient_visual_state.gd`
- `godot/scripts/stages/stage2/stage2_boss_rage_state.gd`
- `godot/scripts/stages/stage2/stage2_chaos_rock_absorb_state.gd`
- `godot/scripts/stages/stage2/stage2_rock_runtime_state.gd`
- `godot/scripts/stages/stage2/stage2_rustle_state.gd`
- `godot/scripts/stages/stage2/stage2_water_visual_state.gd`

## 최종 제출 전에 남은 단일 게이트

**본 트리 통합 후 익스포트 필요**:

```powershell
cd D:\main\bosspong\godot
.\tools\build_windows.ps1 -Mode Release
```

그 뒤 `builds/windows/DiskHearts_Lingpia.exe`를 환경변수 없이 직접 실행해
탑 기본 진입, 아이템 아이콘/두루마리/보이드 팬텀/캐릭터 정보 틀 표시,
1~7층 완주를 제출 후보에서 최종 확인한다.
