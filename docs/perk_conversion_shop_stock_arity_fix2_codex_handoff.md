# 지시문 Z1-수정 — [P1] "낡은 단언"이 아니라 실패 중인 계약이었다

- **발행**: 관제탑 2026-08-26. 대상: 브랜치
  `codex/perk-shop-stock-arity-fix-52ff`(워크트리 `D:\codex_tmp\bosspong_shoparity_52ff`)의
  `208fe23e3` 위 **추가 커밋**. amend/rebase 금지. 본 트리 편집·푸시·통합 금지.
- **판정**: **REJECT.** ★**인자수 수리 자체는 정당하다**(아래 무결 목록).
  그러나 함께 한 "낡은 단언 2건 수정" 이 **계약 갱신이 아니라 단언 약화**이고,
  그 단언이 가리던 것이 **실제 생산 결함**이다.

## ★먼저 읽어라 (새 세션이면 필수)

1. **원 지시문**: `docs/perk_conversion_shop_stock_arity_fix_codex_handoff.md`
2. **직전 구현**: `git -C D:\codex_tmp\bosspong_shoparity_52ff -c safe.directory='*' show 208fe23e3`
3. 워크트리는 **이미 존재한다. 새로 만들지 마라.**
4. 본 트리 현재 HEAD 는 `6d436de71` 이고 **읽기 전용**이다.

---

## [P1] K1 — 삭제한 `not stock.is_empty()` 는 낡은 단언이 아니었다

세션은 `GUARANTEED_ACTIVE_ITEM_NAMES` 가 비어 있으니 낡았다고 판단하고
**"설정된 보장 목록과 정확히 일치"** 계약으로 바꿨다.

**그 단언을 되돌리면 소유자 코드 무변경 상태에서 스모크가 RED 가 된다.**
관제탑이 직접 실행해 확인했다. **즉 낡은 것이 아니라 실패 중이던 계약이다.**

⚠원 발주 문서 `docs/passive_to_perk_s2b2_codex_handoff.md` 가
**"플래그 ON: 반환 재고가 빈 배열이 아님"** 을 명시적으로 요구한다.
세션이 그 계약을 지운 것이다.

## [P1] K2 — 그 단언이 가리던 실제 결함: 광장 상점 재고가 항상 0이다

`boot_flow_scene.gd:60` 이 `PerkConversionFlags` 를 켠다.
그 구성에서 `build_inventory` 반환이 **빈 배열**이다(실측 `stock_size=0`).

**라이브에서 광장 상점 재고가 0 이다.**

**Z1 이전부터의 결함이다.** 그러나 **Z1 이 유일한 트립와이어를 제거했다.**

### 수리

1. **원 단언 2건을 복원하라.** 그러면 스모크가 RED 가 된다. **그것이 옳은 상태다.**
2. 그 RED 를 **실제로 고쳐라** — 플래그 ON 구성에서 `build_inventory` 가
   비어 있지 않은 재고를 돌려주게 하라.
   ⚠소유자(`plaza_shop_stock.gd`)를 읽고 **왜 비는지** 먼저 진단하라.
   `GUARANTEED_ACTIVE_ITEM_NAMES` 가 비어 있는 것이 원인이면
   **그것이 비어야 맞는지**부터 판정하라(`:16` 상수).
3. 고칠 수 없는 이유가 있으면 **고치지 말고 관제탑에 올려라.**
   단언을 약화시켜 GREEN 을 만들지 마라.

## [P2] K3 — CI 등재 씰 2건이 도입 시점부터 무효였다

본 트리 커밋 상태 자체가 파스 불가라, **CI 등재 씰 2건이 도입 시점부터
한 번도 유효하게 돈 적이 없고**, CI 의 경고 스캔 단계는 **클린 체크아웃에서
RED** 가 된다.

**전수로 열거하고 각각의 도입 커밋을 `git log -S` 로 특정해 보고하라.**
수리는 별건이지만 **목록이 필요하다.**

⚠세션이 언급한 후보: `character_info_live_stats_smoke`,
`character_info_stat_source_attribution_smoke`, Commando/Viper 오디오 상수,
Stage 3 tail-whip, stage-clear 테스트 API 불일치.

## [P3] K4 — flag-OFF 레그의 새 단언이 항진명제다

`_stock_has_all_guaranteed_active()` 는 **빈 목록에서 절대 실패할 수 없다.**
K1·K2 를 고치면 자연히 해소되지만, 남긴다면 목록이 비었을 때
**단언 자체를 스킵하지 말고 명시적으로 실패**하게 하라.

## [P3] K5 — 부정 레그가 없다

픽스처의 언락 스토어가 default-unlocked 라, **잠긴 콘텐츠가 실제로 걸러지는지**
검증하는 레그가 없다. 잠긴 항목이 재고에서 빠지는 부정 레그를 추가하라.

## 확인된 무결 (재작업 금지 · 관제탑이 직접 재현)

- ★**`registry` 인자가 정당하다.** `null` 통과가 아니고 생산 호출부
  `plaza_scene.gd:1502` 가 live `_runtime_registry` 를 넘기는 것과 형태가 같다.
  **비공허도 실측**했다 — `registry=null` 이면 `passive_pool` 0,
  실 registry 면 31.
- **RED 반증 재현됨** — 2인자로 되돌리면 전체 경고 스캔 RED.
- **대상 파스 오류는 실제로 사라졌다.**
- **본 트리 HEAD `6d436de71` 과 merge 무충돌**(트리 `213fc2c81`).
  단일 파일 변경이고 그 파일은 본 트리 HEAD 와 바이트 동일이라
  미커밋 WIP 를 건드리지 않는다.

## ★관제탑 통합 방침

리뷰 권고를 채택한다 — **인자수 수정 헝크만 취하고 단언 재작성 헝크는 취하지
않는다.** 헝크 분리가 가능하다:

- **취할 것**: `_build_pool(...)` / `build_inventory(...)` 호출부 인자 수정,
  `FakeRegistry` / 스토어 픽스처 추가
- **취하지 않을 것**: `not stock.is_empty()` 단언 삭제,
  `_stock_has_all_guaranteed_active()` 대체

**그러나 그렇게 하면 스모크가 RED 가 된다.** 그래서 이 지시문은 **K1·K2 를
함께 고쳐 GREEN 으로 만들라**고 요구한다. 그것이 안 되면 관제탑이
인자수 헝크만 착지시키고 RED 를 알려진 기저로 등재한다.

## 게이트·보고

포커스드 스모크 → **전체 경고 스캔** → `run_headless_load_check.ps1` →
`git diff --check`.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

보고: 추가 커밋 해시 · **원 단언 복원 후 RED 종단선** ·
**빈 재고의 진단과 수리(또는 못 고치는 이유)** ·
K3 파스 불가 씰 전수 목록 + 도입 커밋 · 미해결.
