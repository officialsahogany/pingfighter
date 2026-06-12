# Mythic transient owner sync 슬리밍 (F4) 설계 노트

72fps 예산 프로젝트(`docs/frame_budget_72fps_optimization_design.md`)의 F4 슬라이스.
2026-06-13 진단 런(디버그 스폰 헤르메스/혼딸기, `physics.items.mythic.*` 26라벨)에서
mythic per-tick 비용의 본체가 패밀리 업데이트가 아니라 **`sync_after`(81%, 틱당
~0.9ms)** 로 확정됐다. 실제 비용은 `mythic_item_owner_syncer.sync_transient_owner_state`:

1. owner의 `mythic_item_state`(~57키, 중첩 컨텍스트 dict ~10개) **`duplicate(true)`
   딥카피를 매 틱**
2. 컨텍스트 dict 10종(sensor/hermes/celestial/baal/rainbow/adversity/shrapnel/
   poseidon/horn/odins) 매 틱 재구성
3. ~57개 `_put_state_if_changed` + ~45개 `_set_owner_if_changed`
   (후자는 키마다 `owner.get` 읽기)

장착-상시 게이트(헤르메스 `is_equipped`, 혼딸기 `is_equipped`, 쿨다운형 3종)가
active 경로를 매 틱 돌리므로, 이 비용은 해당 아이템 장착 내내 고정비가 된다.

## 불변 계약 (전 슬라이스 공통)

- `mythic_item_state`의 공개 키 집합·값 의미는 불변. 소비자(HUD/패널/저장)는 수정
  대상 아님.
- equip / unequip / reset / load / 라운드 경계는 **풀 싱크 허용** 지점이다.
- per-tick transient sync는 owner state **딥카피 금지**.
- 헤르메스/혼딸기 "장착만으로 full pass"는 별도 슬라이스(F4-B)로 분리.

## F4-A: sync_after 슬리밍 (이번 슬라이스)

원리: **"owner에 마지막으로 push한 값"을 런타임(syncer 인스턴스) 측 캐시로 들고,
비교를 owner 읽기가 아니라 캐시와 한다.** 클린 틱(값 무변화)은 owner에 단 한 번도
접촉하지 않는다.

- `mythic_item_owner_syncer`에 `_transient_state_cache`(part-1: state dict 키),
  `_transient_owner_cache`(part-2: 톱레벨 키), `_transient_sync_primed` 추가.
- per-tick 흐름:
  1. 컨텍스트 10종 + 스칼라 값 계산 (v1에서는 매 틱 전부 — 아래 "의도적 보류" 참조)
  2. 캐시와 비교 → 클린이면 **owner 접촉 0회 종료**
  3. part-1 dirty: 그때만 owner dict 1회 read + `duplicate(true)` 1회 + 기존
     `_put_state_if_changed` 머지 + 조건부 set (기존 쓰기 의미 그대로 → 출력 동일)
  4. part-2: dirty 키만 기존 `_set_owner_if_changed` 경유 (empty-value skip 의미 보존)
  5. 캐시 갱신
- 캐시 무효화(드리프트넷 보존): **풀 `sync_owner` 진입 시 + `runtime.reset()`에서
  `invalidate_transient_sync_cache()`** — 제3자가 owner를 덮어쓰는 알려진 지점
  (매치 리셋의 `mythic_item_state: {}`, 로드, 장비 변경)은 전부 풀 싱크/리셋을
  동반하므로, 무효화 후 첫 틱이 full-dirty 1회 기록으로 수렴한다.
- `sync_ragnarok_transient_owner_state`(라그나로크 전용 브랜치)도 자기가 쓴 2키를
  캐시에 반영해 일관성 유지.

### 의도적 보류: 컨텍스트 10종의 dirty/active-family 게이팅

원 계약엔 "컨텍스트는 활성/dirty family만 재빌드"가 있으나, 게터 필드 감사 결과
**family transient 프레디킷 밖에서 변하는 필드**가 여럿이다(`sensor_enabled`,
adversity `pending_invincible`/`last_trigger_roll_pct`/`last_reflect_center`,
shrapnel `last_proc_*` 등 이벤트성 필드). 프로브 게이팅을 v1에 넣으면 "프로브
false인데 컨텍스트가 변함 → HUD 스테일" 회귀면이 넓다. v1은 컨텍스트를 매 틱
빌드(소형 dict 리터럴)하되 딥카피·owner 읽기를 제거하고, **재측정에서 컨텍스트
빌드가 잔여 지배 비용으로 나오면** per-family 필드 감사를 동반한 v2(또는 F4-B에
병합)로 게이팅한다. 이때 프레디킷은 update gate의 per-family 조건을 공유 헬퍼로
추출해 게이트와 syncer가 한 소스를 쓰고, 감사 불통과 family는 always-rebuild
목록에 남긴다.

### 씰 (스모크)

`mythic_transient_sync_slimming_smoke.gd`, 실제 `MythicItemRuntime` +
get/set 카운팅 owner(F1 스모크의 SchemaGatedCountingOwner 패턴 확장):

1. 클린 틱 = owner get/set **0회** (수정 전 코드에서는 매 틱 get≥46이라 FAIL —
   회귀 감지 확인 필수)
2. dirty 틱(런타임 필드 변경)은 owner에 도달하고 값이 정확
3. 제3자 owner 덮어쓰기 + `invalidate` → 다음 틱 1회 기록으로 복구(드리프트넷)
4. 풀 `sync_owner` 후 transient sync가 스테일 캐시로 잘못 skip하지 않음
5. F1 스모크(`mythic_round_start_sync_smoke`) 4계약 전부 그대로 통과

## 재측정 합격선

- `physics.items.mythic.sync_after`: 틱당 avg 0.9ms → **유의미 감소**(기대: 클린
  틱 위주 구간에서 0.2ms대; 쿨다운 카운트다운 중에는 dirty 틱이라 더 높음 — 정상).
- active 경로 n이 여전히 틱 수에 붙어 있으면(장착-상시 게이트) **F4-B**로.

## F4-B: full-pass 게이트 강등 (다음 슬라이스, 측정 후)

- 헤르메스/혼딸기 `is_equipped` 및 쿨다운형(poseidon/sensor/smartphone 쿨다운)
  상시 조건을 `has_runtime_update_work`에서 빼고 **per-family 업데이트로 강등** —
  full pass는 진짜 다중-family transient가 있을 때만.
- 강등 시 각 family의 자체 업데이트(쿨다운 틱다운, 헤르메스 트레일 등)는 idle
  경로 또는 family 전용 경량 패스에서 계속 돌아야 한다(쿨다운이 멈추면 안 됨).
- update gate per-family 프레디킷 추출(위 v2와 공유)부터 시작.
