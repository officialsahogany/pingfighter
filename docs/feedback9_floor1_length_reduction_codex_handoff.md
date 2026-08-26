# 지시문 Y1 — 1층 길이를 5스텝에서 4스텝으로 줄여라

- **발행**: 관제탑 2026-08-27. 기준선 = 본 트리 **`1f1c97699`**.
  **격리 워크트리 + 격리 브랜치.** 본 트리 편집·통합·푸시 금지.
- **분류**: 밸런스 조정. 결함 수리가 아니다. 현재 동작은 설계대로다.

## 사용자 확정 결정

**1층이 길게 느껴진다. 확장 행 4개 중 구분 행 1개를 제거해 4스텝으로 줄인다.**

## 진단 (재조사 금지)

`tower_ascent_map_generator.gd:37~42`

```gdscript
const FLOOR_ONE_EXPANSION_ROW_ROLES: Array[String] = [
	"npc_separator",          # index 0 → lane 2  (ROUTE_CANDIDATE_COUNT)
	"boss_encounter",         # index 1 → lane 2
	"npc_separator",          # index 2 → lane 3  (MAP_LANE_COUNT_MIN, index>0)
	"optional_boss_encounter",# index 3 → lane 2
]
```

★**길이를 만드는 것은 노드 수가 아니라 밟는 행 수다.** 플레이어는 행마다
노드를 하나만 밟는다(나머지는 `소멸`). 레인 폭(2/3/4)을 줄여도 런은 전혀
짧아지지 않고 선택지만 줄어든다. **레인 폭을 건드리지 마라.**

현재 1층 경로 = 확장 4행 + 기존 1행 = **5스텝**.
2~8층 = 조밀 구간 2행 = **2스텝**. 체감 격차 2.5배.

## 요구

**`index 0` 의 `npc_separator` 를 제거하라.** 결과 배열은

```gdscript
["boss_encounter", "npc_separator", "optional_boss_encounter"]
```

⚠**`index 2` 쪽을 제거하지 마라.** 그러면 `boss_encounter` 와
`optional_boss_encounter` 가 인접해 전투 선택이 연달아 붙는다. `:99~106` 주석이
명시적으로 피하려던 배치다. `index 0` 을 빼면 남은 구분 행이 새 배열의
`index 1` 이라 `index > 0` 조건에 걸려 `MAP_LANE_COUNT_MIN` 풀 NPC 행을
그대로 유지한다. **두 보스 행 사이의 구분 행이 살아남는 쪽을 택한 것이다.**

### 판정해서 보고할 것 (관제탑 대기)

`index 0` 제거는 런 시작 직후 첫 행이 `boss_encounter` 가 된다는 뜻이다.
**상점·샘터 같은 준비 구간 없이 전투 선택으로 런이 시작되는지** 실제 생성
그래프로 확인하고, 그렇다면 그 사실과 대안(예: 역할 순서를
`["npc_separator", "boss_encounter", "optional_boss_encounter"]` 로 바꿔
구분 행을 앞에 두되 레인 규칙을 재조정)을 보고하라. **임의로 대안을 채택하지
말고 관제탑 판정을 기다려라.**

## 바꾸면 안 되는 것

1. **보스 선택 2개 유지.** `floor_one_boss_choice` 노드 수는 그대로다.
2. **로스터 전원 노출 유지.** `_floor_one_optional_encounter_enabled` 는
   피드백2 4항으로 확률제에서 상시로 바뀌었다(`:1574` 주석).
   **확률제로 되돌리지 마라.** 되돌리면 로스터 보스 하나가 지도에 아예
   안 나오는 런이 부활한다.
3. **층 관문은 단일 레인 초크포인트 보스.**
   `gatekeeper_boss_count == TowerAuditionBuildConfig.STANDARD_CLEAR_FLOOR`.
4. **2층 이상 밀도 불변.** `TEMP_OPTIONAL_ROWS_PER_FLOOR` 등 조밀 구간 상수는
   손대지 마라. 사용자는 1층만 줄이기로 했다.
5. `audition_enabled` 경로는 확장 행을 쓰지 않는다. 회귀시키지 마라.

## ★최우선 위험 — 지도 생성 실패율

`_has_floor_one_boss_avoidance_path` 는 `:407` 에서 **후보 채택 조건**이다.
회피 경로가 없는 후보는 버려지고 재시도한다. 행을 하나 빼면 회피 레인을
만들 여지가 줄어 **후보 기각률이 오른다.**

⚠**미결 보류 건과 직결된다: 내보낸 빌드에서 지도 생성이 16.5% 실패하는
현상이 이미 보고돼 있다.** 이 변경이 그 수치를 악화시키면 착지 불가다.

**필수 측정**: 변경 전후로 **동일 시드 집합(최소 2,000 시드)** 에 대해
- 생성 성공률
- `floor_one_boss_avoidance_path_missing` 이슈 발생률
- 후보 재시도 횟수 분포(평균·최대)

를 재고, **전후 표를 보고에 실어라.** 성공률이 떨어지면 수치와 함께 보고하고
멈춰라. 임의로 재시도 상한을 올려 덮지 마라.

## 씰 요구

다음 3개가 1층 구조를 봉인한다. 전부 CI·pre-push 등재분이다.

| 씰 | 봉인 내용 |
|---|---|
| `tower_ascent_floor_one_expansion_contract_smoke.gd` | `:167` 행 수, **`:209` `added_node_count == 10`**, 회피 경로, 관문 초크포인트, 전투 노드 합계 |
| `tower_ascent_12_floor_map_smoke.gd` | 12층 전체 그래프 |
| `tower_optional_extra_boss_distribution_smoke.gd` | 선택 조우 분포 |

1. **`added_node_count` 기대값을 손으로 추정하지 마라.** 실제 생성 그래프에서
   `floor_one_expansion_added_node` 를 세어 새 값을 얻고, 그 값을 씰에 넣어라.
   ⚠현재 4행의 레인 합은 2+2+3+2=9 인데 씰은 10 이다. **차이 1의 출처를
   먼저 규명하고 보고하라.** 규명 전에 새 상수를 확정하지 마라.
2. **다시 5스텝으로 되돌리면 RED 가 되는지 반증하고 원상복구하라.**
3. 위 3개 씰 전부 GREEN 유지. 실패하면 기대값 재작성 근거를 보고에 적어라.
4. **CI/pre-push 락스텝.** ⚠**현재 249/249 다.** 통째 교체하지 말고 필요한
   줄만 고쳐라. 착지 전후로 항목 집합을 `comm` 으로 대조해 **사라진 항목 0**
   을 증명하라.

## 게이트·보고

포커스드 스모크(+반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` →
**실제 지도 렌더 픽셀 확인**(1층 행이 4개로 줄고 구분 행이 두 보스 행 사이에
남아 있는지 눈으로).

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs` 를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

⚠**신규 자산을 만들면 `.import` 사이드카를 반드시 동반하라.** 격리 워크트리는
에디터가 없어 사이드카가 생기지 않는다. 만들 수 없으면 **그 사실을 보고에
명시하라.** 조용히 PNG 만 커밋하면 익스포트 빌드에서 텍스처가 빈다.
(이 작업은 자산이 필요 없을 것이다.)

## 보고

커밋 해시 · 제거한 역할과 결과 배열 · **차이 1의 출처 규명** ·
새 `added_node_count` 와 도출 근거 · 5스텝 복귀 RED 반증 종단선 ·
**생성 성공률 전후 표(2,000 시드)** · 회피 경로 이슈율 ·
런 시작 첫 행 판정 · CI 항목 집합 대조 결과 · 미해결.

## 알려진 선재 RED (이 작업 탓 아님)

- 전체 경고 스캔 RED — 파스 오류 경로 테스트 17 + 도구 2.
  CI 등재 3건은 도입 시점부터 무효였다.
- `tower_ascent_flow_owner_refactor_smoke` — `tower_ascent_flow_runtime.gd`
  710줄 vs 500줄 예산.
