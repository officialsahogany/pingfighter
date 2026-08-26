# 지시문 Z1 — [P1] `_build_pool()` 인자수 파스 에러가 전체 경고 스캔을 막는다

- **발행**: 관제탑 2026-08-26. 기준선 = 본 트리 `52ff8ef32`.
  **격리 워크트리 + 격리 브랜치.** 본 트리 편집·통합·푸시 금지.
- **성격**: 착지 검증 중 발견한 **선재 커밋 결함**이다. 최근 착지(W1·W5·W3·X5)와
  무관하고, 도입은 **2026-08-16 `f9e55cd59`** 로 추정된다.
- **크기**: 작다. 호출부 4곳이다. 다만 **푸시 게이트를 막고 있다.**

---

## 관측

`godot/tools/run_warning_scan.ps1` **전체 스캔**이 실패한다.

```
Parse Error: Too few arguments for "_build_pool()" call. Expected at least 3 but received 2.
→ 래퍼가 "Godot warning scan emitted an error despite exit code 0" 로 throw, exit 1
```

## 진범

- **소유자**: `godot/scripts/plaza/plaza_shop_stock.gd:80`
  `func _build_pool(catalog: Object, legendary: bool, registry: Object)` — **3인자**
- **호출부**: `godot/tests/perk_conversion_shop_stock_smoke.gd:37`, `:38`, `:53`, `:54`
  — **2인자**로 부른다

**두 파일 모두 워크트리 CLEAN** 이고 `3e1ef2998` 과 바이트 동일하다.
**미커밋 WIP 탓이 아니다.**

⚠**GRT-048**(덕타이핑 `has_method` 게이트 동적 호출 인자수 트랩)의 인접 계열이다.
여기서는 정적 호출이라 파서가 잡았지만, 그 파서 에러가 **경고 스캔 전체를
쓰러뜨리는** 형태로 나타난다.

## 수리

1. 호출부 4곳이 `registry` 를 어디서 얻어야 하는지 **소유자 시그니처와 생산
   호출자를 대조해** 판정하라. `plaza_shop_stock.gd` 의 **생산 호출부**가
   `registry` 에 무엇을 넘기는지 보고 픽스처에서 같은 것을 만들어라.
   ⚠`null` 을 넘겨 파서만 통과시키는 것은 금지다 — 그 인자가 무엇을 하는지
   확인하고, 픽스처가 그 경로를 실제로 검증하도록 하라.
2. `_build_pool` 이 `registry` 를 쓰는 방식이 **호출부 4곳에서 서로 다른 기대를
   갖는지** 확인하라(전설 여부에 따라 다를 수 있다).
3. 수리 후 **전체 경고 스캔**이 통과하는지 확인하라. 포커스드 스캔만으로는
   이 결함이 안 잡힌다.

## 확인해 함께 보고할 것

- `perk_conversion_shop_stock_smoke` 가 **CI/pre-push 에 등재돼 있는지.**
  등재돼 있는데 파스 에러로 죽고 있었다면 **그동안 이 씰이 무효였다**는 뜻이다.
  등재돼 있지 않다면 등재해야 하는지 판단해 보고하라.
- `f9e55cd59` 가 무엇을 하려다 이렇게 됐는지 커밋 메시지를 확인하라.
  `registry` 인자를 **추가한 쪽**이 그 커밋이면, 그때 호출부를 안 고친 것이다.

## 씰 요구

1. `perk_conversion_shop_stock_smoke` 가 **실제로 실행되고 GREEN** 인지 확인하라.
   파스 에러로 죽던 씰이므로 **그 안의 단언이 지금까지 한 번도 안 돌았을 수 있다.**
   돌려보고 **다른 실패가 튀어나오면 그것도 보고하라**(별건일 수 있다).
2. **RED 반증**: 인자를 다시 2개로 되돌리면 전체 경고 스캔이 RED 가 되는지
   확인하고 **원상복구**하라.

## 게이트·보고

포커스드 스모크 → **전체 경고 스캔**(`run_warning_scan.ps1`, `-Paths` 없이) →
`run_headless_load_check.ps1` → `git diff --check`.

⚠**헤드리스/스모크/스캔 실행 전 `godot/logs`를 통째로 복사하라**(없으면 그렇게 보고).
⚠래퍼는 `-AllowDuringPlay` 선언 + PID/타임스탬프 고유 `--log-file`.
**사용자의 게임·에디터를 절대 종료하지 마라.**

보고: 커밋 해시 · `registry` 에 무엇을 넘겼는지와 근거 ·
**전체 경고 스캔 종단선 원문** · 씰 실행 결과(새 실패가 있으면 그것도) ·
CI 등재 여부 판단 · 미해결.
