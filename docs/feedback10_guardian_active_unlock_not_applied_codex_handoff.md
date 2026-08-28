# 지시문 Z3 — 수호령 액티브 추가해금이 적용되지 않는다

- **발행**: 관제탑 2026-08-28. 기준선 = 본 트리 **`15b2b3170`**.
  **격리 워크트리 + 격리 브랜치.** 본 트리 편집·통합·푸시 금지.

## 사용자 보고

> 전투에서 **수호령 알을 깬 뒤 흡수하기**에서 **액티브 스킬 추가 해금**이
> 떴는데도, 현재 내 수호령의 액티브 스킬이 **추가 해금되지 않는** 버그.

## ★가장 먼저 갈라야 할 것 — 적용 실패인가 표시 실패인가

**둘 중 무엇인지 증명하기 전에 고치지 마라.** 수리 위치가 완전히 달라진다.

### 가설 A — 적용 실패

`lingpet_guardian_run_state.gd:505~514` `_set_unlock_count` 는 보상 장부만
갱신한다.

```gdscript
REWARD_TYPE_SECOND_ACTIVE_UNLOCK:
	counts["second_active_unlocked"] = value
```

이 플래그가 **실제 펫 로드아웃의 두 번째 액티브 슬롯**
(`second_active_skill_id`)을 채우는 데까지 이어지는지 확인하라.
장부만 켜지고 로드아웃이 비어 있으면 가설 A 다.

### 가설 B — 표시 실패 (★등록된 함정이 있다)

**`docs/godot_runtime_traps.md#grt-024` 를 반드시 읽어라.**
"Lingpet Second-Active-Slot HUD Parity Trap".

런타임 스냅샷은 두 번째 슬롯을 **접미사 `_1` 키 쌍**으로 노출한다
(`companion_skill_id_1`, `_name_1`, `_cooldown_1`, `_ready_1`, `_card_path_1` …).
GRT-024 의 상시 규칙:

> Any HUD / debug / localization surface that reads companion active-skill state
> must handle BOTH slots (un-suffixed AND `_1`), not just the primary.
> **Reading only `companion_skill_id` silently drops the second active card with
> no error and passing state smokes.**

**실제로 해금은 됐는데 어떤 표시 경로가 `_1` 을 안 읽는 것**일 수 있다.
사용자는 화면으로 판단했으므로 이 가능성이 열려 있다.

### 증명 방법

1. 흡수에서 액티브 추가 해금을 받은 직후
   - `reward_counts.second_active_unlocked`
   - 펫 로드아웃의 `second_active_skill_id` / `_level`
   - 스냅샷의 `companion_skill_id_1`
   세 값을 **모두 찍어라.**
2. 장부 true + 로드아웃 빈값 → **가설 A**.
   장부 true + 로드아웃 채워짐 + 스냅샷 `_1` 있음 → **가설 B**(표시 경로 추적).
3. 재현 픽스처를 만들고 **어느 단계에서 끊기는지** 보고하라.

## 참고 — 인접 착지

X2(`97d7daafc`)가 **샘터 첫 수호령**에 액티브·패시브 각 Lv.1 을 보장하도록
고쳤다. `_roll_tower_spring_first_pick_loadout` 이 액티브 해금 후보 중 1개를
뽑아 `_grant_and_activate_pet` 에 레벨 1,1 로 넘긴다.
**흡수 경로가 같은 계약을 쓰는지 대조하라.** 한쪽만 로드아웃을 채우고 있을 수
있다.

⚠**부화 롤 재사용 함정**: `_roll_hatch_skill_level = randi_range(0, 3)` 은
**25% 확률로 0(스킬 없음)** 이 나온다. 추가 해금에 그대로 재사용하면
"해금 떴는데 없다"가 재현된다. **이 경로가 그것을 쓰는지 확인하라.**

## 요구

1. **증명 후에만 고쳐라.** 가설을 확정하고 그 지점만 수리하라.
2. 가설 B 라면 **GRT-024 의 상시 규칙대로 모든 소비 표면**을 훑어라.
   TAB 캐릭터 정보 패널과 인배틀 레일 둘 다이며, 그 밖에 디버그·다국어
   표면도 규칙 대상이다.
3. **장부와 실상태의 동기 지점을 명시하라.** 어디가 소유자인지 보고하라.

## 씰 요구

1. ★**종단 씰**: 흡수 → 액티브 추가 해금 → **로드아웃과 스냅샷 `_1` 이
   모두 채워지고** 두 표시 표면이 카드 2장을 낸다.
   ⚠**장부 플래그만 확인하는 씰을 만들지 마라.** 그게 지금 통과하고 있다.
2. **반증**: 수리를 되돌리면 RED 가 되는지 확인하고 원상복구하라.
3. **CI/pre-push 락스텝.** ⚠**현재 251/251 이다.**
   착지 전후 항목 집합을 `comm` 으로 대조해 **사라진 항목 0** 을 증명하라.

## 게이트·보고

포커스드 스모크(+반증) → `run_warning_scan.ps1 -Paths <touched>` →
`run_headless_load_check.ps1` → `git diff --check` →
★**픽셀 QA**: 액티브 2개를 가진 수호령의 TAB 패널과 인배틀 레일을 캡처하라.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs` 를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

## ★알려진 기준선 RED (이 작업 탓 아님)

HEAD 의 **깨끗한 격리 워크트리**(미추적 0·더티 0)에서 CI 씰 251건 중 다수가
이미 RED 다. `docs/untracked_preload_dependency_audit_2026_08_27.md` 참조.
**착수 전 기준선을 먼저 재고 신규 RED 와 구분해서 보고하라.** 선재 RED 를
고치려 들지 마라.

## 보고

커밋 해시 · **가설 A/B 판정과 세 값 계측 로그** · 끊긴 단계 ·
장부↔실상태 동기 소유자 · 부화 롤 재사용 여부 · X2 계약과의 대조 결과 ·
가설 B 라면 훑은 표시 표면 목록 · 씰 종단선과 반증 ·
기준선 RED 대비 신규 RED 0 증명 · 픽셀 캡처 · 미해결.
