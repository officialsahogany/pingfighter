# 영어(다국어) 번역 누락 수정 설계 — 광장 / 패배·컨티뉴 / Stage6 / 기타

> **단일 소스 문서.** 전투 밖 화면들의 한국어 누수를 안정 키(stable-key) 기반 i18n으로
> 막기 위한 설계 + 키 테이블이다. **배선(코드 변경)은 사용자/Codex가 이 문서 기준으로 수행**하고,
> Claude는 진단·설계·키 테이블·리뷰를 담당한다.
> 진단 근거: 영어 번역 감사(2단계) — 등록 surface는 깨끗(`localization_coverage_smoke` ok),
> 미등록 draw surface에서 **실제 미번역 한글 102건**(검증 후) 확인.

## 0. 상태 / 범위

- **대상 surface(확정 누수):** 광장(Plaza) 시스템 전체, 패배 결산(`defeat_settlement_screen`),
  컨티뉴(`defeat_chance_gems_continue_screen`), Stage6 테트리서 보스 스킬 HUD, 그리고 소규모 잔여
  surface(퍽 오버레이, 코만도 무기명, 스테이지 진입 자막, 뿔딸기 스킬, 픽업 안내, 스테이지클리어
  "광장으로" 버튼, 캐릭터 정보 패널 일부 라벨).
- **영향 언어:** 광장/패배/Stage6 등은 `translate`를 **아예 호출하지 않으므로** 영어뿐 아니라
  **中文·日本語·Español 등 모든 비한국어 언어에서도 한국어로 노출**된다. 즉 영어만의 문제가 아니다.
- **이 문서 산출물:** 표준 키 네임스페이스, 구현 패턴(코드), 회귀 스모크 스펙, 전체
  KO→EN/ZH/JA/ES 키 테이블(§9).

## 1. 진단 요약 (어디가 새는가)

| 영역 | 파일 | 누수 성격 |
|---|---|---|
| 광장 동적 메시지 | `plaza_scene.gd` `_format_*_transaction_message` (2693~2900) | **완성 문장** 반환(코드별 분기). exact key 매칭 불가 |
| 광장 정적 UI | `plaza_scene.gd` `BUILDING_MENU_SPECS`/`INTERIOR_*`, `plaza_interior_view.gd`, 거래 모듈 액션 라벨 | raw 한글 직접 draw |
| 패배 결산/컨티뉴 | `defeat_settlement_screen.gd`, `defeat_chance_gems_continue_screen.gd` | `translate` 미호출(전 화면 raw) |
| Stage6 HUD | `stage6_tetriser_boss_skill_hud_renderer.gd` `TOOLTIP_INFO` | const dict raw 한글 |
| 잔여 | `runtime_perk_overlay_renderer.gd`, `commando_weapon_controller.gd`/`commando_firearm_selector_renderer.gd`, `stage_landing_intro.gd`, `horn_strawberry_skill_pillar_renderer.gd`, `active_item_pickup_feedback.gd`, `stage_clear_result_scroll_content_draw_helper.gd`, `character_info_overlay_*` | direct draw + 일부 키 불일치 |

## 2. 근본 원인 (translate fallback)

`LanguageSettings.translate_text(text)` ([language_settings.gd:288](../godot/scripts/core/language_settings.gd#L288))는
한국어가 아닐 때 `EXACT_TEXT_*`에 키가 있거나 `_translate_known_patterns`가 처리하면 번역을, **그 외에는
입력 한국어 원문을 그대로 반환**한다. 그래서 누수는 두 부류다:

- **direct_draw_leak** — 한글이 `translate`/`translate_text`를 한 번도 안 거치고 `draw_string`/label로 직행.
- **missing_key_leak** — `translate_text`는 거치나 매칭 키/패턴이 없어 한글로 fallback (철자 불일치 포함).

`translate(key)` ([language_settings.gd:275](../godot/scripts/core/language_settings.gd#L275))는 `TEXT[lang]` →
`TEXT[DEFAULT_LANGUAGE]` → key 순으로 fallback 한다(점-키 정적 라벨용).

## 3. 아키텍처 (3축)

1. **안정 키 + 템플릿 i18n** — 완성 문장을 번역 키로 쓰지 않는다.
   - 동적 메시지: 기존 `reason`/`action` 코드 switch는 유지하고, 각 분기가
     `LanguageSettings.translate("plaza.msg.shop.purchase") % [localized_name, gold]`로 반환.
     템플릿이 `%s`/`%d`를 보유하고 **인자는 현지화**해서 채운다. `display_name`은 substitution 전에 현지화.
   - 정적 라벨: 점-키 하나씩(`plaza.building.shop.name` 등) → `translate(key)`로 교체.
2. **추가 키는 무조건 다국어 동기** — §5 참조.
3. **실제 출력 검사 focused smoke** — 화이트리스트 추가가 아니라 실 렌더러/포매터 출력을 비한국어
   언어로 구동해 Hangul 0 + 템플릿이 한국어와 다름을 단언 — §7.

## 4. 확정 정책

- **PT-BR / RU = 영어 fallback.** 별도 번역은 작성하지 않는다(프로젝트의 의도된 부분 번역 posture).
  단 §5의 스모크 정합을 위해 키 자체는 존재해야 하므로 **pt-BR/ru 값 = EN 문자열**로 채운다.
- **고유명 = 음역.** NPC 인명은 로마자 음역(모라→Mora, 도윤→Doyun, 루미→Lumi, 링링→Ringring,
  강철→Gangcheol, 하랑→Harang, 서율→Seoyul). 일반 건물 유형어는 영어권 가독성을 위해 영문 의미어
  (상점→Shop, 은행→Bank, 대장간→Forge, 선술집→Tavern, 아카데미→Academy 등). §9 표의
  `translit` 열로 인명 항목을 식별.

## 5. 키 배치 규칙 & 스모크 정합 (중요)

신규 점-키는 **`TEXT` 맵**(`language_settings_data.gd` line 4477~)에 둔다. `TEXT`는 alias 메커니즘이 없고
[localization_coverage_smoke.gd:138-142](../godot/tests/localization_coverage_smoke.gd#L138)가 **7개 언어 전부**
한국어와 동일 키 집합을 강제한다. 따라서 각 신규 키는:

- `ko` = 한국어 템플릿(원문)
- `en` / `zh` / `ja` / `es` = §9 표의 번역
- `pt-BR` / `ru` = **EN 문자열 그대로**(영어 fallback)

→ 7개 서브딕트 모두에 키가 존재해야 `_verify_same_keys`가 통과한다. (`EXACT_TEXT`에 넣는 경우 PT/RU는
alias라 자동 EN fallback이지만, **EN-only 추가는 `EXACT_TEXT_EN↔ZH/JA/ES` 정합
[smoke:175-179](../godot/tests/localization_coverage_smoke.gd#L175)을 깨므로 ZH/JA/ES도 반드시 함께** 넣어야
한다. 본 설계는 점-키 일관성을 위해 `TEXT` 맵을 표준으로 한다.)

> **퍽 이름·보스 이름 같은 기존 자산은 새 키를 만들지 말 것.** 퍽 이름은 이미 있는 `PERK_NAME_*` 맵을
> perk id로 조회해 현지화한다(패배 결산의 `RuntimePerkCatalog.get_perk_data().name` raw 사용을 교체).
> 보스 이름은 §9 `defeat.boss.*` 표를 쓰되, `format_stage_*` 계열에 이미 현지화 소스가 있으면 재사용.

## 6. 구현 패턴 (코드)

### 6.1 Plaza 동적 메시지 (포매터)

`reason`/`action` 코드는 그대로 두고 반환만 템플릿 키로 교체한다. 예:

```gdscript
# BEFORE — plaza_scene.gd _format_shop_transaction_message
match str(summary.get("action", "")):
    "purchase":
        return "%s을(를) 구매했습니다. %dG" % [display_name, int(summary.get("delta_gold", 0))]

# AFTER
var localized_name := _localize_item_display_name(display_name)  # 현 언어로 현지화
match str(summary.get("action", "")):
    "purchase":
        return LanguageSettings.translate("plaza.msg.shop.purchase") % [localized_name, int(summary.get("delta_gold", 0))]
```

- `display_name`은 `LanguageSettings.localize_item_data(...)` / 아이템 표시 맵으로 **먼저 현지화**한 뒤 `%s`에 채운다.
- 인자 순서·개수는 §9 `formatter_mapping`/`placeholders`를 그대로 따른다(예: `shop.purchase` = `[name:%s, gold:%d]`).
- `%dG`의 `G`는 모든 언어에서 리터럴 유지(기존 G 약어 관행).
- 빈 `display_name` fallback("아이템")은 `plaza.msg.shop.fallback_item` 키 사용.

**✅ 구현·검증 완료(2026-06-21) — shop이 레퍼런스 구현.** 실제 적용된 이름 현지화 헬퍼(이걸 그대로 복제):

```gdscript
# plaza_scene.gd — id 기반 ITEM_DISPLAY로 base name 현지화(Korean은 원문 유지)
func _localize_shop_item_name(summary: Dictionary) -> String:
    var korean_display := str(summary.get("display_name", "")).strip_edges()
    var item_id := str(summary.get("item_name", "")).strip_edges()
    if korean_display == "" and item_id == "":
        return LanguageSettings.translate("plaza.msg.shop.fallback_item")
    if LanguageSettings.get_language() == LanguageSettings.LANGUAGE_KOREAN:
        return korean_display if korean_display != "" else LanguageSettings.translate("plaza.msg.shop.fallback_item")
    var item_data := {"name": item_id}
    if korean_display != "":
        item_data["display_name"] = korean_display
    var localized: Dictionary = LanguageSettings.localize_item_data(item_data)
    var localized_name := str(localized.get("display_name", "")).strip_edges()
    if localized_name == "":
        localized_name = LanguageSettings.translate("plaza.msg.shop.fallback_item")
    return localized_name
```

> **⚠️ 품질 접두사 caveat (복제 시 필수 준수).** 현지화는 **item id → `ITEM_DISPLAY` base name**으로만 한다.
> 품질 접두사(`name_prefix`, 예 "전설")를 `localize_item_data`에 주입해 `qualified_display_name`을 쓰려는 시도는
> **금지** — 접두사 문자열은 `EXACT_TEXT` 키 보장이 없어 `translate_text`가 한글을 그대로 반환(누수)할 수 있다.
> 슬라이스에선 비한국어에서 접두사를 **드롭**(base name만)하여 누수 0을 보장했다. 접두사 현지화가 필요하면
> 별도 후속(접두사 문자열의 전수 EXACT_TEXT/QUALITY 키화)으로 처리하고, 그 전까지는 base-name-only를 유지.
> 봉인: `godot/tests/plaza_shop_localization_smoke.gd` (실 포매터 출력 6언어 구동 + EN 정확값 pin, 반증검증 통과).
> bank/gacha 등 동일 패밀리는 이 헬퍼를 공유/복제하면 된다.

### 6.2 Plaza 정적 라벨

`BUILDING_MENU_SPECS`/`INTERIOR_NPC_NAMES`/`INTERIOR_GREETING_LINES`/`RING_CORE_TIER_NAMES`/`QUEST_CATALOG`/
거래 모듈 액션 라벨의 raw 한글을 **표시 시점에 `translate(key)`로 변환**한다. 데이터 dict는 한국어를
키 결정용 id로 남겨도 되고, draw 직전 매핑 테이블로 키를 골라도 된다. 핵심은 draw에 도달하는 최종
문자열이 `translate(key)` 결과여야 한다는 것.

### 6.3 패배 결산 / 컨티뉴

`defeat_settlement_screen.gd` / `defeat_chance_gems_continue_screen.gd`는 `translate`를 전혀 안 쓰므로
모든 `_draw_*` 라벨 인자를 `LanguageSettings.translate("defeat.settlement.title")` 등으로 감싼다.
보스명은 스냅샷 빌드 시 `defeat.boss.*`로 현지화, 퍽명은 `PERK_NAME_*`로 현지화(§5 노트).
컨티뉴 화면의 `\n` 포함 다중행/색상 세그먼트 문자열은 §9 표의 구조(세그먼트 분할)를 보존.

### 6.4 Stage6 HUD

`TOOLTIP_INFO` const는 skill id 키 dict이므로 접근 시점에 `name`/`description`/`trigger`/`cooldown`을
`stage6.skill.<id>.*` 키로 현지화하거나, 표시용 사본을 현지화해 반환하는 accessor를 둔다.
`trigger`의 숫자(5~10초 등)는 유지하고 단어만 번역.

### 6.5 char-info 라벨 — 키 불일치(싼 수정)

`character_info_overlay_stats_presenter.gd`의 일부 라벨은 `EXACT_TEXT_EN`에 **유사 키가 이미 있는데
철자(띄어쓰기/대시-대쉬)가 달라** 매칭 실패한다(§9 misc 표의 `note` 참조). 코드 리터럴 철자를 기존
키와 일치시키면 새 키 없이 해결된다. 그 외(섹션 제목 등)는 신규 키.

## 7. 회귀 방지 — focused smoke 스펙

화이트리스트 스캔이 아니라 **실제 출력**을 검사하는 focused smoke를 추가한다(파일 오너별 분리 권장).
공통 패턴: 비한국어 언어로 전환 → 실 함수 호출 → 출력에 Hangul 없음 + (동적은) **한국어 템플릿과 달라짐**
단언(영어 fallback 위장 차단). 헬퍼는 기존 `_has_hangul`/`_expect_no_hangul` 재사용.

- **`plaza_localization_smoke.gd`** — 각 `_format_*_transaction_message`를 모든 `reason`/`action` 코드 +
  현지화된 `display_name`으로 구동해 출력 스캔. `BUILDING_MENU_SPECS`/`INTERIOR_NPC_NAMES`/
  `INTERIOR_GREETING_LINES`/`RING_CORE_TIER_NAMES`/`QUEST_CATALOG` 표시 경로도 스캔. `%s`/`%d` 치환
  후에도 Hangul 0 단언.
- **`defeat_screen_localization_smoke.gd`** — 대표 스냅샷으로 결산/컨티뉴 라벨 생성 경로를
  EN/ZH/JA/ES로 구동해 스캔(보스명·퍽명 포함).
- **`stage6_boss_skill_hud_localization_smoke.gd`** — `TOOLTIP_INFO` 현지화 accessor 출력 스캔.
- 세 스모크를 `run_smoke_tests.ps1`/pre-push 게이트에 포함.
- (선택) `localization_coverage_smoke`의 runtime-surface 목록에 위 surface를 추가해 이중 봉인.

## 8. Codex 배선 체크리스트

1. §9 표의 키를 `TEXT` 7개 서브딕트에 추가(ko=원문, en/zh/ja/es=표, pt-BR/ru=EN 문자열).
2. 포매터 반환을 `translate(key) % [localized_args]`로 교체(§6.1, `formatter_mapping` 순서 준수).
3. `display_name`/아이템명/보스명/퍽명 현지화 헬퍼 경유(§5 노트).
4. 정적 라벨 raw 한글 → `translate(key)`로 교체(§6.2~6.4).
5. char-info 키 불일치 철자 정렬(§6.5).
6. focused smoke 3종 추가 + 게이트 등록(§7).
7. 실행 검증: 언어를 EN/ZH/JA/ES로 바꿔 광장·패배·Stage6 화면 라이브 확인(픽셀 QA).

## 9. 키 테이블 (KO → EN / ZH / JA / ES)

> pt-BR/ru는 EN 값을 그대로 복제(§4·§5). `placeholders`는 치환 인자(순서). `translit`=인명 음역 항목.
> 셀의 `<br>`은 원문 줄바꿈(`\n`). 워크플로 작성→적대 검증(66건 수정) 산출물.


_총 316 키 / 8 surface / 검증 수정 66건._

### 9.1 Plaza dynamic messages: bank + shop + gacha  (28)
> **배선:** Three formatters in godot/scripts/plaza/plaza_scene.gd (lines 2693-2767) return finished Korean sentences keyed on summary.reason (when changed==false) and summary.action (when changed==true). Replace each return with translate(key) % [args]. Argument order: bank.deposit -> [delta_deposit:int]; bank.withdraw -> [delta_gold:int]; bank.interest -> [interest_gold:int]; shop.purchase -> [display_name:str, delta_gold:int]; shop.sale -> [display_name:str, sell_price:int]; gacha.draw -> [display_name:str, delta_gold:int]. Static (no-arg) keys use plain translate(key). The display_name arg is a localized item name passed as %s. The %dG unit keeps the literal 'G' currency suffix in every locale (matches existing G shorthand); shop.sale and gacha success keep the +/no-sign as authored. The Korean object particle 을(를) carries no info — drop it in EN/ZH/JA/ES. display_name falls back to '아이템' (plaza.msg.shop.fallback_item) when empty in BOTH shop (line 2721) and gacha (line 2752). NOTE: this surface covers ONLY bank/shop/gacha; the lingpet-store formatter (_format_lingpet_store_transaction_message, line 2770+) is a SEPARATE surface — its no_ap there actually reads '행동력이 부족합니다.' (AP, not Key) and must not be confused with the gacha/shop no_ap keys here.

_검증: Re-read plaza_scene.gd _format_bank_transaction_message (2693-2714), _format_shop_transaction_message (2717-2745), _format_gacha_transaction_message (2748-2767). Every Korean string in the proposed table matches source VERBATIM. All reason branches (no_ap, no_plaza_gold, no_bank_deposit, interest_already_claimed, _; no_ap, not_enough_gold, active_slots_full, no_active_item, no_passive_item, inventory_full, missing_item_runtime/missing_owner, _; no_ap, not_enough_gold, active_slots_full, missing_item_runtime/missing_owner, empty_gacha_pool, _) and action branches (deposit, withdraw, interest; p_

<details><summary>formatter code → key 매핑 (29)</summary>

- BANK: changed==false reason 'no_ap' -> plaza.msg.bank.no_ap
- BANK: reason 'no_plaza_gold' -> plaza.msg.bank.no_plaza_gold
- BANK: reason 'no_bank_deposit' -> plaza.msg.bank.no_bank_deposit
- BANK: reason 'interest_already_claimed' -> plaza.msg.bank.interest_already_claimed
- BANK: reason default (_) -> plaza.msg.bank.default_blocked
- BANK: changed==true action 'deposit' -> plaza.msg.bank.deposit
- BANK: action 'withdraw' -> plaza.msg.bank.withdraw
- BANK: action 'interest' -> plaza.msg.bank.interest
- BANK: action default (no match) -> plaza.msg.bank.processed
- SHOP: changed==false reason 'no_ap' -> plaza.msg.shop.no_ap
- SHOP: reason 'not_enough_gold' -> plaza.msg.shop.not_enough_gold
- SHOP: reason 'active_slots_full' -> plaza.msg.shop.active_slots_full
- SHOP: reason 'no_active_item' -> plaza.msg.shop.no_active_item
- SHOP: reason 'no_passive_item' -> plaza.msg.shop.no_passive_item
- SHOP: reason 'inventory_full' -> plaza.msg.shop.inventory_full
- SHOP: reason 'missing_item_runtime'/'missing_owner' -> plaza.msg.shop.missing_item_bag
- SHOP: reason default (_) -> plaza.msg.shop.default_blocked
- SHOP: changed==true action 'purchase' -> plaza.msg.shop.purchase
- SHOP: action 'sale' -> plaza.msg.shop.sale
- SHOP: action default (no match) -> plaza.msg.shop.traded
- SHOP: empty display_name fallback -> plaza.msg.shop.fallback_item
- GACHA: changed==false reason 'no_ap' -> plaza.msg.gacha.no_ap
- GACHA: reason 'not_enough_gold' -> plaza.msg.gacha.not_enough_gold
- GACHA: reason 'active_slots_full' -> plaza.msg.gacha.active_slots_full
- GACHA: reason 'missing_item_runtime'/'missing_owner' -> plaza.msg.gacha.missing_item_bag
- GACHA: reason 'empty_gacha_pool' -> plaza.msg.gacha.empty_gacha_pool
- GACHA: reason default (_) -> plaza.msg.gacha.default_blocked
- GACHA: changed==true (no action branch, single tail template) -> plaza.msg.gacha.draw
- GACHA: empty display_name fallback -> plaza.msg.shop.fallback_item (shared '아이템' fallback)
</details>

| key | KO | ph | EN | ZH | JA | ES | T | note |
|---|---|---|---|---|---|---|:-:|---|
| `plaza.msg.bank.no_ap` | 열쇠가 부족합니다. |  | Not enough Keys. | 钥匙不足。 | 鍵が足りません。 | No tienes suficientes Llaves. |  | Verbatim '열쇠가 부족합니다.' Uses 열쇠=Key per source. |
| `plaza.msg.bank.no_plaza_gold` | 맡길 골드가 없습니다. |  | No Gold to deposit. | 没有可存入的金币。 | 預けるゴールドがありません。 | No hay Oro para depositar. |  |  |
| `plaza.msg.bank.no_bank_deposit` | 찾거나 정산할 예금이 없습니다. |  | No deposit to withdraw or settle. | 没有可取出或结算的存款。 | 引き出すか精算する預金がありません。 | No hay depósito para retirar ni liquidar. |  | 정산 = settle (interest settlement). |
| `plaza.msg.bank.interest_already_claimed` | 이번 스테이지 이자는 이미 정산했습니다. |  | You already settled this stage's interest. | 本关卡的利息已经结算过了。 | 今ステージの利息はすでに精算済みです。 | Ya liquidaste el interés de esta fase. |  | 이자=Interest, 스테이지=Stage. |
| `plaza.msg.bank.default_blocked` | 지금은 처리할 수 없습니다. |  | Can't process that right now. | 目前无法处理。 | 今は処理できません。 | No se puede procesar ahora. |  | Fallback when changed==false and reason unmatched. |
| `plaza.msg.bank.deposit` | %dG를 예금했습니다. | %d | Deposited %dG. | 已存入 %dG。 | %dGを預けました。 | Depositaste %dG. |  | %d = deposited gold amount (delta_deposit); keep literal G unit. 예금=Deposit. |
| `plaza.msg.bank.withdraw` | %dG를 출금했습니다. | %d | Withdrew %dG. | 已取出 %dG。 | %dGを引き出しました。 | Retiraste %dG. |  | 출금=Withdraw. |
| `plaza.msg.bank.interest` | 이자 %dG를 받았습니다. | %d | Received %dG interest. | 获得了 %dG 利息。 | 利息%dGを受け取りました。 | Recibiste %dG de interés. |  | 이자=Interest. |
| `plaza.msg.bank.processed` | 처리했습니다. |  | Done. | 已处理。 | 処理しました。 | Hecho. |  | Generic success fallback. |
| `plaza.msg.shop.no_ap` | 열쇠가 부족합니다. |  | Not enough Keys. | 钥匙不足。 | 鍵が足りません。 | No tienes suficientes Llaves. |  | Same text as bank.no_ap; separate key per namespace policy. |
| `plaza.msg.shop.not_enough_gold` | 골드가 부족합니다. |  | Not enough Gold. | 金币不足。 | ゴールドが足りません。 | No tienes suficiente Oro. |  |  |
| `plaza.msg.shop.active_slots_full` | 액티브 슬롯이 가득 찼습니다. |  | Active slots are full. | 主动技能槽已满。 | アクティブスロットが満杯です。 | Las ranuras activas están llenas. |  | 액티브=Active, 슬롯=Slot. |
| `plaza.msg.shop.no_active_item` | 판매할 액티브 아이템이 없습니다. |  | No Active item to sell. | 没有可出售的主动物品。 | 売却するアクティブアイテムがありません。 | No hay objeto Activo para vender. |  |  |
| `plaza.msg.shop.no_passive_item` | 판매할 패시브 아이템이 없습니다. |  | No Passive item to sell. | 没有可出售的被动物品。 | 売却するパッシブアイテムがありません。 | No hay objeto Pasivo para vender. |  | 패시브=Passive. |
| `plaza.msg.shop.inventory_full` | 인벤토리가 가득 찼습니다. |  | Inventory is full. | 背包已满。 | インベントリが満杯です。 | El inventario está lleno. |  | 인벤토리=Inventory. |
| `plaza.msg.shop.missing_item_bag` | 아이템 가방을 찾을 수 없습니다. |  | Can't find the item bag. | 找不到物品背包。 | アイテムバッグが見つかりません。 | No se encuentra la bolsa de objetos. |  | Two reason codes map to this one key. |
| `plaza.msg.shop.default_blocked` | 지금은 거래할 수 없습니다. |  | Can't trade right now. | 目前无法交易。 | 今は取引できません。 | No se puede comerciar ahora. |  |  |
| `plaza.msg.shop.purchase` | %s을(를) 구매했습니다. %dG | %s, %d | Purchased %s. %dG | 购买了 %s。%dG | %sを購入しました。%dG | Compraste %s. %dG |  | %s=localized item name, %d=gold spent (delta_gold). Korean 을(를) dropped in other locales. |
| `plaza.msg.shop.sale` | %s을(를) 판매했습니다. +%dG | %s, %d | Sold %s. +%dG | 出售了 %s。+%dG | %sを売却しました。+%dG | Vendiste %s. +%dG |  | %s=item name, %d=sell_price; keep leading + sign and G unit. |
| `plaza.msg.shop.traded` | 거래했습니다. |  | Trade complete. | 交易完成。 | 取引しました。 | Operación completada. |  | Generic success fallback. |
| `plaza.msg.shop.fallback_item` | 아이템 |  | Item | 物品 | アイテム | Objeto |  | Default display_name when summary has no name; used by both shop (line 2721) and gacha (line 2752) %s slots. |
| `plaza.msg.gacha.no_ap` | 열쇠가 부족합니다. |  | Not enough Keys. | 钥匙不足。 | 鍵が足りません。 | No tienes suficientes Llaves. |  | Same text as bank/shop no_ap; separate gacha key. |
| `plaza.msg.gacha.not_enough_gold` | 뽑기 비용이 부족합니다. |  | Not enough Gold for the draw. | 抽取费用不足。 | ガチャ費用が足りません。 | No hay Oro suficiente para tirar. |  | 뽑기=Gacha draw. |
| `plaza.msg.gacha.active_slots_full` | 액티브 슬롯이 가득 찼습니다. |  | Active slots are full. | 主动技能槽已满。 | アクティブスロットが満杯です。 | Las ranuras activas están llenas. |  | Same text as shop.active_slots_full; separate gacha key. |
| `plaza.msg.gacha.missing_item_bag` | 아이템 가방을 찾을 수 없습니다. |  | Can't find the item bag. | 找不到物品背包。 | アイテムバッグが見つかりません。 | No se encuentra la bolsa de objetos. |  | Two reason codes map to this one key. |
| `plaza.msg.gacha.empty_gacha_pool` | 뽑기 캡슐이 비어 있습니다. |  | The gacha capsule is empty. | 扭蛋胶囊是空的。 | ガチャカプセルが空です。 | La cápsula de gacha está vacía. |  | 캡슐=capsule (gacha pool empty). |
| `plaza.msg.gacha.default_blocked` | 지금은 뽑을 수 없습니다. |  | Can't draw right now. | 目前无法抽取。 | 今は引けません。 | No se puede tirar ahora. |  |  |
| `plaza.msg.gacha.draw` | %s을(를) 뽑았습니다. %dG | %s, %d | Drew %s. %dG | 抽到了 %s。%dG | %sを引きました。%dG | Obtuviste %s. %dG |  | %s=localized item name, %d=gold spent (delta_gold). Single success template (no action branch). |

### 9.2 Plaza dynamic messages: lingpet-store + blacksmith + academy + tavern + ledger defaults + inline failures  (79)
> **배선:** All four transaction formatters build their string from stable codes: each branches on summary.get("reason")/summary.get("action")/summary.get("result") and the boolean summary.get("changed"). Runtime fix: replace each `return "..."` / `return "..." % [...]` with `return tr(KEY)` or `return tr(KEY) % [localized_args]`, keeping printf placeholders and arg order IDENTICAL. GLOSSARY CORRECTION applied: language_settings_data.gd renders 링코어 NOT as English in ZH/JA/ES but as 环核 / リングコア / Núcleo de anillo (lines 2302/2821/3340/3859), and 친밀도 as 亲密度 / 親密度 / Afinidad (2117/2636/3155/3674); every Ring Core occurrence corrected. Korean particle 은(는) appears only in blacksmith.max_level and is dropped naturally per locale. Ledger default messages (~1475-1545) are the fallback for _active_menu_last_message==''. Ledger NUMBER summary lines (보유 %dG | ...) are composed inline with already-glossed labels and are keyed (보유=Held/예금=Deposit/열쇠=Key/행동력=AP/액티브=Active/링펫=Lingpet/알=Egg/수업료=Lesson fee/비용=Cost/대상 없음=No target/진행 중=In progress/제안=Offered). Menu-row state tag (~1651) and inline device-not-found failures (~2382-2662) are static one-key-each. Fallback display names (아이템=item, 링코어=Ring Core, 의뢰=quest) are keyed. Reuse the SAME key across alias code groups returning identical Korean (missing_lingpet_runtime/missing_affinity_store; missing_lingpet_runtime/missing_owner; missing_runtime_perk_state/missing_runtime_perk_catalog). %dG = gold (int + G suffix), %d = plain int, %s = a localized name the caller must localize before substitution. The AP/Key split is intentional and per-building (ring_core/academy/tavern no_ap=행동력/AP; egg/blacksmith no_ap=열쇠/Key) — do NOT collapse to one key.

_검증: Re-read plaza_scene.gd verbatim: all four formatters (_format_lingpet_store ~2770, _format_blacksmith ~2813, _format_academy ~2846, _format_tavern ~2871), ledger defaults+summaries (~1469-1548), menu state tag (~1651), inline failures (~2382-2662). Every Korean string matched the proposal exactly (no Korean drift). PLACEHOLDERS: all printf tokens (%s, %d, %dG) verified in source order against args (e.g. ring_core.success = [ring_core_name, new_cap, abs(delta_gold)]; blacksmith.result_success = [display_name, new_level, abs(delta_gold)]; tavern.summary = [plaza_gold, ap_current, quest_state, qu_

<details><summary>formatter code → key 매핑 (73)</summary>

- LINGPET STORE ring_core (action=='ring_core', changed==false): no_ap -> plaza.msg.lingpet.ring_core.no_ap
- ring_core not_enough_gold -> plaza.msg.lingpet.ring_core.not_enough_gold
- ring_core missing_lingpet_runtime / missing_affinity_store -> plaza.msg.lingpet.ring_core.missing_runtime
- ring_core max_ring_core_tier -> plaza.msg.lingpet.ring_core.max_tier
- ring_core missing_ring_core_price -> plaza.msg.lingpet.ring_core.missing_price
- ring_core ring_core_upgrade_failed -> plaza.msg.lingpet.ring_core.upgrade_failed
- ring_core default (_) -> plaza.msg.lingpet.ring_core.unavailable
- ring_core changed==true (success) -> plaza.msg.lingpet.ring_core.success
- LINGPET STORE egg (action!='ring_core', changed==false): no_ap -> plaza.msg.lingpet.egg.no_ap
- egg not_enough_gold -> plaza.msg.lingpet.egg.not_enough_gold
- egg egg_already_active -> plaza.msg.lingpet.egg.already_active
- egg no_hatch_candidates -> plaza.msg.lingpet.egg.no_candidates
- egg missing_lingpet_runtime / missing_owner -> plaza.msg.lingpet.egg.missing_runtime
- egg manage_stub -> plaza.msg.lingpet.egg.manage_stub
- egg default (_) -> plaza.msg.lingpet.egg.unavailable
- egg changed==true (success) -> plaza.msg.lingpet.egg.success
- BLACKSMITH changed==false: no_ap -> plaza.msg.blacksmith.no_ap
- blacksmith not_enough_gold -> plaza.msg.blacksmith.not_enough_gold
- blacksmith no_active_item -> plaza.msg.blacksmith.no_active_item
- blacksmith max_level -> plaza.msg.blacksmith.max_level
- blacksmith missing_owner -> plaza.msg.blacksmith.missing_owner
- blacksmith default (_) -> plaza.msg.blacksmith.unavailable
- blacksmith result=='success' -> plaza.msg.blacksmith.result_success
- blacksmith result=='maintain' -> plaza.msg.blacksmith.result_maintain
- blacksmith result=='fail' -> plaza.msg.blacksmith.result_fail
- blacksmith result default -> plaza.msg.blacksmith.result_attempted
- ACADEMY changed==false: no_ap -> plaza.msg.academy.no_ap
- academy not_enough_gold -> plaza.msg.academy.not_enough_gold
- academy missing_owner -> plaza.msg.academy.missing_owner
- academy missing_runtime_perk_state / missing_runtime_perk_catalog -> plaza.msg.academy.missing_runtime
- academy choice_already_active -> plaza.msg.academy.choice_active
- academy no_academy_choices -> plaza.msg.academy.no_choices
- academy exchange_stub -> plaza.msg.academy.exchange_stub
- academy default (_) -> plaza.msg.academy.unavailable
- academy changed==true & choice_opened==true -> plaza.msg.academy.lesson_started
- academy changed==true & choice_opened==false -> plaza.msg.academy.lesson_no_choice
- TAVERN changed==false: no_ap -> plaza.msg.tavern.no_ap
- tavern quest_already_active -> plaza.msg.tavern.quest_active
- tavern stage_already_accepted -> plaza.msg.tavern.stage_accepted
- tavern invalid_quest -> plaza.msg.tavern.invalid_quest
- tavern no_active_quest -> plaza.msg.tavern.no_active_quest
- tavern quest_in_progress -> plaza.msg.tavern.quest_in_progress
- tavern missing_plaza_save_store -> plaza.msg.tavern.missing_store
- tavern default (_) -> plaza.msg.tavern.unavailable
- tavern action=='accept' -> plaza.msg.tavern.accepted
- tavern action=='complete' -> plaza.msg.tavern.completed
- tavern action default -> plaza.msg.tavern.processed
- INLINE device-not-found null guard: gacha (2570) -> plaza.fail.gacha_device_missing
- lingpet_store (2591) -> plaza.fail.lingpet_device_missing
- blacksmith (2613) -> plaza.fail.blacksmith_ledger_missing
- academy (2633) -> plaza.fail.academy_device_missing
- tavern (2662) -> plaza.fail.tavern_device_missing
- bank (2391) -> plaza.fail.bank_ledger_missing
- default menu type _trigger_menu_action (2382) -> plaza.fail.not_ready
- shop reorder success (2445) -> plaza.msg.shop.reorder_done
- MENU ROW state tag _is_executable_menu_type true (1651) -> plaza.menu.state.executable
- MENU ROW state tag false (1651) -> plaza.menu.state.coming_soon
- LEDGER default (_active_menu_last_message==''): bank (1475) -> plaza.ledger.default.bank
- shop (1484) -> plaza.ledger.default.shop
- gacha (1494) -> plaza.ledger.default.gacha
- lingpet_store (1504) -> plaza.ledger.default.lingpet
- tavern (1519) -> plaza.ledger.default.tavern
- academy (1528) -> plaza.ledger.default.academy
- blacksmith (1545) -> plaza.ledger.default.blacksmith
- ledger else-branch note (1548) -> plaza.ledger.default.coming_soon
- LEDGER summary lines: bank (1469) -> plaza.ledger.bank.summary
- shop (1478) -> plaza.ledger.shop.summary
- gacha (1487) -> plaza.ledger.gacha.summary
- lingpet (1497) -> plaza.ledger.lingpet.summary
- tavern (1511) -> plaza.ledger.tavern.summary; quest_state %s = plaza.ledger.tavern.state.in_progress | plaza.ledger.tavern.state.offered (1510)
- academy (1522) -> plaza.ledger.academy.summary
- blacksmith (1538) -> plaza.ledger.blacksmith.summary; target %s = plaza.ledger.blacksmith.target (1534, has_target) | plaza.ledger.blacksmith.no_target (1532)
- FALLBACK names: ring_core_name absent (2790) -> plaza.msg.lingpet.fallback.ring_core_name; blacksmith display_name absent (2817) & blacksmith ledger target name (1535) -> plaza.fallback.item_name; tavern quest_name absent (2873/2875) & tavern ledger name (1515) -> plaza.fallback.quest_name
</details>

| key | KO | ph | EN | ZH | JA | ES | T | note |
|---|---|---|---|---|---|---|:-:|---|
| `plaza.msg.lingpet.ring_core.no_ap` | 행동력이 부족합니다. |  | Not enough Action Points. | 行动力不足。 | 行動力が足りません。 | No tienes suficientes Puntos de Acción. |  | Ring core no_ap uses 행동력(AP). Identical Korean reused by academy.no_ap and tavern.no_ap; kept as separate keys per namespace. |
| `plaza.msg.lingpet.ring_core.not_enough_gold` | 링코어 강화 비용이 부족합니다. |  | Not enough Gold to upgrade the Ring Core. | 升级环核的金币不足。 | リングコアの強化に必要なゴールドが足りません。 | No tienes suficiente oro para mejorar el Núcleo de anillo. |  | 강화=upgrade. FIXED: 링코어 -&gt; 环核/リングコア/Núcleo de anillo per glossary (was English 'Ring Core'). |
| `plaza.msg.lingpet.ring_core.missing_runtime` | 링코어 장부를 찾을 수 없습니다. |  | Ring Core ledger not found. | 找不到环核账本。 | リングコアの帳簿が見つかりません。 | No se encontró el registro del Núcleo de anillo. |  | Covers missing_lingpet_runtime and missing_affinity_store (same string). FIXED 링코어 rendering in zh/ja/es. |
| `plaza.msg.lingpet.ring_core.max_tier` | 링코어가 이미 최대 단계입니다. |  | The Ring Core is already at the maximum tier. | 环核已达到最高阶。 | リングコアはすでに最大段階です。 | El Núcleo de anillo ya está en el nivel máximo. |  | 단계=tier. FIXED 링코어 rendering in zh/ja/es. |
| `plaza.msg.lingpet.ring_core.missing_price` | 링코어 가격표가 비어 있습니다. |  | The Ring Core price list is empty. | 环核价目表为空。 | リングコアの価格表が空です。 | La lista de precios del Núcleo de anillo está vacía. |  | FIXED 링코어 rendering in zh/ja/es. |
| `plaza.msg.lingpet.ring_core.upgrade_failed` | 링코어 강화에 실패했습니다. |  | Ring Core upgrade failed. | 环核升级失败。 | リングコアの強化に失敗しました。 | La mejora del Núcleo de anillo falló. |  | FIXED 링코어 rendering in zh/ja/es. |
| `plaza.msg.lingpet.ring_core.unavailable` | 지금은 링코어를 강화할 수 없습니다. |  | You can't upgrade the Ring Core right now. | 现在无法升级环核。 | 今はリングコアを強化できません。 | No puedes mejorar el Núcleo de anillo ahora mismo. |  | Default fallback for ring_core failure. FIXED 링코어 rendering in zh/ja/es. |
| `plaza.msg.lingpet.ring_core.success` | %s 링코어가 친밀도 Lv.%d까지 열렸습니다. -%dG | %s, %d, %dG | %s Ring Core unlocked up to Affinity Lv.%d. -%dG | %s 环核已解锁至亲密度 Lv.%d。-%dG | %s リングコアを親密度 Lv.%d まで解放しました。-%dG | %s Núcleo de anillo desbloqueado hasta Afinidad Lv.%d. -%dG |  | Args: ring_core_name (%s, may fall back to '링코어'), new_cap (%d), abs(delta_gold) (%dG). FIXED: 링코어 -&gt; 环核/リングコア/Núcleo de anillo (was 'Ring Core' in zh/ja/es). 친밀도=Affinity/亲密度/親密度/Afinidad. Lv. token kept verbatim. |
| `plaza.msg.lingpet.egg.no_ap` | 열쇠가 부족합니다. |  | Not enough Keys. | 钥匙不足。 | 鍵が足りません。 | No tienes suficientes llaves. |  | Egg path uses 열쇠(Key) for no_ap, unlike ring_core which uses 행동력(AP). Same Korean reused by blacksmith.no_ap. |
| `plaza.msg.lingpet.egg.not_enough_gold` | 알 뽑기 비용이 부족합니다. |  | Not enough Gold to draw an egg. | 抽蛋的金币不足。 | 卵を引くゴールドが足りません。 | No tienes suficiente oro para sacar un huevo. |  | 알 뽑기 = egg gacha draw. |
| `plaza.msg.lingpet.egg.already_active` | 이미 깨어날 알이 기다리고 있습니다. |  | An egg is already waiting to hatch. | 已经有一颗蛋在等待孵化。 | すでに孵化を待つ卵があります。 | Ya hay un huevo esperando a eclosionar. |  |  |
| `plaza.msg.lingpet.egg.no_candidates` | 지금 뽑을 수 있는 새 링펫 알이 없습니다. |  | There are no new Lingpet eggs to draw right now. | 目前没有可以抽取的新 Lingpet 蛋。 | 今引ける新しい Lingpet の卵はありません。 | No hay huevos de Lingpet nuevos para sacar ahora mismo. |  |  |
| `plaza.msg.lingpet.egg.missing_runtime` | 링펫 장치를 찾을 수 없습니다. |  | Lingpet device not found. | 找不到 Lingpet 装置。 | Lingpet の装置が見つかりません。 | No se encontró el dispositivo de Lingpet. |  | Covers missing_lingpet_runtime and missing_owner. Same Korean also appears as inline failure at line 2591 (plaza.fail.lingpet_device_missing) — both keys kept, identical translation. |
| `plaza.msg.lingpet.egg.manage_stub` | 링펫 관리는 다음 단계에서 열립니다. |  | Lingpet management will open in a later milestone. | Lingpet 管理将在后续阶段开放。 | Lingpet 管理は次の段階で開放されます。 | La gestión de Lingpet se abrirá en una fase posterior. |  |  |
| `plaza.msg.lingpet.egg.unavailable` | 지금은 알을 뽑을 수 없습니다. |  | You can't draw an egg right now. | 现在无法抽蛋。 | 今は卵を引けません。 | No puedes sacar un huevo ahora mismo. |  | Default fallback for egg failure. |
| `plaza.msg.lingpet.egg.success` | 공명 알이 전투에 나타났습니다. -%dG | %dG | A Resonance Egg has appeared in battle. -%dG | 共鸣蛋出现在战斗中。-%dG | 共鳴の卵が戦闘に現れました。-%dG | Un Huevo de Resonancia apareció en la batalla. -%dG |  | 공명 알 = Resonance Egg. Single arg abs(delta_gold). |
| `plaza.msg.blacksmith.no_ap` | 열쇠가 부족합니다. |  | Not enough Keys. | 钥匙不足。 | 鍵が足りません。 | No tienes suficientes llaves. |  | Blacksmith no_ap uses 열쇠(Key). |
| `plaza.msg.blacksmith.not_enough_gold` | 강화 비용이 부족합니다. |  | Not enough Gold to upgrade. | 升级的金币不足。 | 強化に必要なゴールドが足りません。 | No tienes suficiente oro para mejorar. |  | 강화=upgrade. |
| `plaza.msg.blacksmith.no_active_item` | 강화할 액티브 아이템이 없습니다. |  | There is no Active item to upgrade. | 没有可升级的主动道具。 | 強化できるアクティブアイテムがありません。 | No hay objeto Activo para mejorar. |  | 액티브=Active/主动/アクティブ/Activo per glossary. |
| `plaza.msg.blacksmith.max_level` | %s은(는) 이미 최대 강화입니다. | %s | %s is already at maximum upgrade. | %s 已达到最高强化。 | %s はすでに最大強化です。 | %s ya está en la mejora máxima. |  | %s = display_name (falls back to '아이템'/item). Korean particle 은(는) dropped naturally. |
| `plaza.msg.blacksmith.missing_owner` | 아이템 가방을 찾을 수 없습니다. |  | Item bag not found. | 找不到道具背包。 | アイテムバッグが見つかりません。 | No se encontró la bolsa de objetos. |  | 아이템 가방 = item bag/inventory. Same Korean also used by gacha missing_item_runtime/missing_owner (out of this surface). |
| `plaza.msg.blacksmith.unavailable` | 지금은 강화할 수 없습니다. |  | You can't upgrade right now. | 现在无法强化。 | 今は強化できません。 | No puedes mejorar ahora mismo. |  | Default fallback for blacksmith failure. |
| `plaza.msg.blacksmith.result_success` | %s +%d 강화 성공! -%dG | %s, %d, %dG | %s +%d upgrade succeeded! -%dG | %s +%d 强化成功！-%dG | %s +%d 強化成功！-%dG | ¡%s +%d mejora exitosa! -%dG |  | Args: display_name (%s), new_level (%d), abs(delta_gold) (%dG). |
| `plaza.msg.blacksmith.result_maintain` | %s 강화 유지. -%dG | %s, %dG | %s upgrade maintained. -%dG | %s 强化保持。-%dG | %s 強化を維持。-%dG | %s mejora mantenida. -%dG |  | Args: display_name (%s), abs(delta_gold) (%dG). Maintain = level unchanged but gold spent. |
| `plaza.msg.blacksmith.result_fail` | %s 강화 실패. 아이템은 유지됩니다. -%dG | %s, %dG | %s upgrade failed. The item is kept. -%dG | %s 强化失败。道具予以保留。-%dG | %s 強化失敗。アイテムは維持されます。-%dG | %s mejora fallida. El objeto se conserva. -%dG |  | Args: display_name (%s), abs(delta_gold) (%dG). |
| `plaza.msg.blacksmith.result_attempted` | 강화를 시도했습니다. |  | Upgrade attempted. | 已尝试强化。 | 強化を試みました。 | Mejora intentada. |  | Default fallback when result code is unrecognized. |
| `plaza.msg.academy.no_ap` | 행동력이 부족합니다. |  | Not enough Action Points. | 行动力不足。 | 行動力が足りません。 | No tienes suficientes Puntos de Acción. |  | Academy no_ap uses 행동력(AP). |
| `plaza.msg.academy.not_enough_gold` | 수업료가 부족합니다. |  | Not enough Gold for the lesson fee. | 学费的金币不足。 | 授業料のゴールドが足りません。 | No tienes suficiente oro para la matrícula. |  | 수업료 = lesson fee (수업=Lesson per glossary). |
| `plaza.msg.academy.missing_owner` | 현재 캐릭터를 찾을 수 없습니다. |  | Current character not found. | 找不到当前角色。 | 現在のキャラクターが見つかりません。 | No se encontró el personaje actual. |  |  |
| `plaza.msg.academy.missing_runtime` | 스킬 수업 장치를 찾을 수 없습니다. |  | Skill lesson device not found. | 找不到技能授课装置。 | スキル授業の装置が見つかりません。 | No se encontró el dispositivo de lecciones de habilidad. |  | Covers missing_runtime_perk_state and missing_runtime_perk_catalog. |
| `plaza.msg.academy.choice_active` | 이미 진행 중인 스킬 선택이 있습니다. |  | A skill selection is already in progress. | 已经有正在进行的技能选择。 | すでに進行中のスキル選択があります。 | Ya hay una selección de habilidad en curso. |  |  |
| `plaza.msg.academy.no_choices` | 지금 배울 수 있는 스킬이 없습니다. |  | There are no skills to learn right now. | 目前没有可学习的技能。 | 今学べるスキルはありません。 | No hay habilidades para aprender ahora mismo. |  |  |
| `plaza.msg.academy.exchange_stub` | 스킬 교환은 다음 단계에서 열립니다. |  | Skill exchange will open in a later milestone. | 技能交换将在后续阶段开放。 | スキル交換は次の段階で開放されます。 | El intercambio de habilidades se abrirá en una fase posterior. |  |  |
| `plaza.msg.academy.unavailable` | 지금은 수업을 진행할 수 없습니다. |  | You can't take a lesson right now. | 现在无法上课。 | 今は授業を進められません。 | No puedes tomar una lección ahora mismo. |  | Default fallback for academy failure. |
| `plaza.msg.academy.lesson_started` | 스킬 수업을 시작합니다. -%dG | %dG | Starting the skill lesson. -%dG | 开始技能授课。-%dG | スキル授業を始めます。-%dG | Comenzando la lección de habilidad. -%dG |  | Single arg abs(delta_gold). choice_opened==true branch. |
| `plaza.msg.academy.lesson_no_choice` | 수업료를 냈지만 선택지를 열지 못했습니다. |  | You paid the lesson fee but no choices could be opened. | 已支付学费，但未能打开选项。 | 授業料を払いましたが選択肢を開けませんでした。 | Pagaste la matrícula pero no se pudo abrir ninguna opción. |  | changed==true but choice_opened==false. |
| `plaza.msg.tavern.no_ap` | 행동력이 부족합니다. |  | Not enough Action Points. | 行动力不足。 | 行動力が足りません。 | No tienes suficientes Puntos de Acción. |  | Tavern no_ap uses 행동력(AP). |
| `plaza.msg.tavern.quest_active` | 이미 진행 중인 의뢰가 있습니다. |  | A quest is already in progress. | 已经有正在进行的委托。 | すでに進行中の依頼があります。 | Ya hay una misión en curso. |  | 의뢰=quest per glossary. |
| `plaza.msg.tavern.stage_accepted` | 이번 스테이지의 의뢰는 이미 받았습니다. |  | You have already accepted this Stage's quest. | 本关卡的委托已经接取。 | このステージの依頼はすでに受けています。 | Ya aceptaste la misión de esta Etapa. |  | 스테이지=Stage per glossary. |
| `plaza.msg.tavern.invalid_quest` | 의뢰서가 손상되었습니다. |  | The quest sheet is corrupted. | 委托书已损坏。 | 依頼書が破損しています。 | La hoja de misión está dañada. |  | 의뢰서 = quest sheet/order document. |
| `plaza.msg.tavern.no_active_quest` | 보고할 의뢰가 없습니다. |  | There is no quest to report. | 没有可汇报的委托。 | 報告する依頼がありません。 | No hay misión que reportar. |  |  |
| `plaza.msg.tavern.quest_in_progress` | 다음 전투를 마친 뒤 보고할 수 있습니다. |  | You can report after finishing the next battle. | 完成下一场战斗后才能汇报。 | 次の戦闘を終えてから報告できます。 | Podrás reportar tras terminar la próxima batalla. |  |  |
| `plaza.msg.tavern.missing_store` | 의뢰 장부를 찾을 수 없습니다. |  | Quest ledger not found. | 找不到委托账本。 | 依頼の帳簿が見つかりません。 | No se encontró el registro de misiones. |  | missing_plaza_save_store code. |
| `plaza.msg.tavern.unavailable` | 지금은 의뢰를 처리할 수 없습니다. |  | You can't handle a quest right now. | 现在无法处理委托。 | 今は依頼を処理できません。 | No puedes gestionar una misión ahora mismo. |  | Default fallback for tavern failure. |
| `plaza.msg.tavern.accepted` | %s 의뢰를 받았습니다. | %s | Accepted the %s quest. | 已接取「%s」委托。 | 「%s」の依頼を受けました。 | Aceptaste la misión «%s». |  | %s = quest_name (falls back to '의뢰'/quest). |
| `plaza.msg.tavern.completed` | %s 보고 완료. +%dG | %s, %dG | %s reported. +%dG | 「%s」汇报完成。+%dG | 「%s」の報告完了。+%dG | «%s» reportada. +%dG |  | Args: quest_name (%s), delta_gold (%dG, positive reward). |
| `plaza.msg.tavern.processed` | 의뢰를 처리했습니다. |  | Quest handled. | 已处理委托。 | 依頼を処理しました。 | Misión gestionada. |  | Default fallback when action code is neither accept nor complete. |
| `plaza.ledger.default.bank` | 첫 은행 처리 때 열쇠 1개를 사용합니다. |  | Your first bank action this visit uses 1 Key. | 本次首次办理银行业务将消耗 1 把钥匙。 | 今回最初の銀行処理で鍵を1個使用します。 | Tu primera operación bancaria de esta visita usa 1 llave. |  | Default _active_menu_last_message for bank when empty. 열쇠=Key. |
| `plaza.ledger.default.shop` | 첫 거래 때 열쇠 1개를 사용합니다. |  | Your first trade this visit uses 1 Key. | 本次首次交易将消耗 1 把钥匙。 | 今回最初の取引で鍵を1個使用します。 | Tu primer intercambio de esta visita usa 1 llave. |  | Shop default ledger message. |
| `plaza.ledger.default.gacha` | 첫 뽑기 때 열쇠 1개를 사용합니다. |  | Your first draw this visit uses 1 Key. | 本次首次抽取将消耗 1 把钥匙。 | 今回最初の抽選で鍵を1個使用します。 | Tu primera tirada de esta visita usa 1 llave. |  | Gacha default ledger message. 뽑기=Gacha draw. |
| `plaza.ledger.default.lingpet` | 첫 알 뽑기 때 열쇠 1개를 사용합니다. |  | Your first egg draw this visit uses 1 Key. | 本次首次抽蛋将消耗 1 把钥匙。 | 今回最初の卵の抽選で鍵を1個使用します。 | Tu primera tirada de huevo de esta visita usa 1 llave. |  | Lingpet store default ledger message. |
| `plaza.ledger.default.tavern` | 첫 의뢰 처리 때 행동력 1개를 사용합니다. |  | Your first quest action this visit uses 1 Action Point. | 本次首次处理委托将消耗 1 点行动力。 | 今回最初の依頼処理で行動力を1個使用します。 | Tu primera acción de misión de esta visita usa 1 Punto de Acción. |  | Tavern default ledger message. 행동력=AP. |
| `plaza.ledger.default.academy` | 첫 수업 처리 때 행동력 1개를 사용합니다. |  | Your first lesson action this visit uses 1 Action Point. | 本次首次上课将消耗 1 点行动力。 | 今回最初の授業処理で行動力を1個使用します。 | Tu primera acción de lección de esta visita usa 1 Punto de Acción. |  | Academy default ledger message. |
| `plaza.ledger.default.blacksmith` | 첫 강화 시도 때 열쇠 1개를 사용합니다. |  | Your first upgrade attempt this visit uses 1 Key. | 本次首次强化尝试将消耗 1 把钥匙。 | 今回最初の強化試行で鍵を1個使用します。 | Tu primer intento de mejora de esta visita usa 1 llave. |  | Blacksmith default ledger message. |
| `plaza.ledger.default.coming_soon` | 준비 중 |  | Coming soon | 准备中 | 準備中 | Próximamente |  | Ledger else-branch note for unimplemented building types. |
| `plaza.ledger.bank.summary` | 보유 %dG  |  예금 %dG  |  열쇠 %d | %dG, %dG, %d | Held %dG  |  Deposit %dG  |  Keys %d | 持有 %dG  |  存款 %dG  |  钥匙 %d | 所持 %dG  |  預金 %dG  |  鍵 %d | En mano %dG  |  Depósito %dG  |  Llaves %d |  | Bank ledger numeric line. Args: plaza_gold, bank_deposit_gold, ap_current. 예금=Deposit, 열쇠=Key. Double-space '  |  ' separators kept verbatim. |
| `plaza.ledger.shop.summary` | 보유 %dG  |  열쇠 %d  |  액티브 %d개 | %dG, %d, %d | Held %dG  |  Keys %d  |  Active %d | 持有 %dG  |  钥匙 %d  |  主动 %d 个 | 所持 %dG  |  鍵 %d  |  アクティブ %d個 | En mano %dG  |  Llaves %d  |  Activos %d |  | Shop ledger line. Args: plaza_gold, ap_current, active_item_slot_count. 액티브=Active/主动/アクティブ/Activo; counter 개 dropped naturally. |
| `plaza.ledger.gacha.summary` | 보유 %dG  |  열쇠 %d  |  액티브 %d개  |  1회 %dG | %dG, %d, %d, %dG | Held %dG  |  Keys %d  |  Active %d  |  Per draw %dG | 持有 %dG  |  钥匙 %d  |  主动 %d 个  |  单次 %dG | 所持 %dG  |  鍵 %d  |  アクティブ %d個  |  1回 %dG | En mano %dG  |  Llaves %d  |  Activos %d  |  Por tirada %dG |  | Gacha ledger line. Args: plaza_gold, ap_current, active_item_slot_count, PULL_COST. 1회=per draw. |
| `plaza.ledger.lingpet.summary` | 보유 %dG  |  열쇠 %d  |  링펫 %d종  |  알 %dG | %dG, %d, %d, %dG | Held %dG  |  Keys %d  |  Lingpets %d  |  Egg %dG | 持有 %dG  |  钥匙 %d  |  Lingpet %d 种  |  蛋 %dG | 所持 %dG  |  鍵 %d  |  Lingpet %d種  |  卵 %dG | En mano %dG  |  Llaves %d  |  Lingpets %d  |  Huevo %dG |  | Lingpet store ledger line. Args: plaza_gold, ap_current, owned_lingpet_count, EGG_COST. 종 (species counter) dropped naturally. |
| `plaza.ledger.tavern.summary` | 보유 %dG  |  행동력 %d  |  %s: %s +%dG | %dG, %d, %s, %s, %dG | Held %dG  |  AP %d  |  %s: %s +%dG | 持有 %dG  |  行动力 %d  |  %s: %s +%dG | 所持 %dG  |  行動力 %d  |  %s: %s +%dG | En mano %dG  |  PA %d  |  %s: %s +%dG |  | Tavern ledger line. Args: plaza_gold, ap_current, quest_state (%s = plaza.ledger.tavern.state.*), quest_name (%s), reward_gold (%dG). AP/행동력=Action Point (abbrev PA in es). |
| `plaza.ledger.tavern.state.in_progress` | 진행 중 |  | In progress | 进行中 | 進行中 | En curso |  | quest_state value when an active quest exists; substituted into plaza.ledger.tavern.summary first %s. |
| `plaza.ledger.tavern.state.offered` | 제안 |  | Offered | 提议 | 提案 | Ofrecida |  | quest_state value when only an offered quest exists. |
| `plaza.ledger.academy.summary` | 보유 %dG  |  행동력 %d  |  수업료 %dG | %dG, %d, %dG | Held %dG  |  AP %d  |  Lesson fee %dG | 持有 %dG  |  行动力 %d  |  学费 %dG | 所持 %dG  |  行動力 %d  |  授業料 %dG | En mano %dG  |  PA %d  |  Matrícula %dG |  | Academy ledger line. Args: plaza_gold, ap_current, LESSON_COST. 수업료=lesson fee. |
| `plaza.ledger.blacksmith.summary` | 보유 %dG  |  열쇠 %d  |  %s  |  비용 %dG | %dG, %d, %s, %dG | Held %dG  |  Keys %d  |  %s  |  Cost %dG | 持有 %dG  |  钥匙 %d  |  %s  |  费用 %dG | 所持 %dG  |  鍵 %d  |  %s  |  費用 %dG | En mano %dG  |  Llaves %d  |  %s  |  Coste %dG |  | Blacksmith ledger line. Args: plaza_gold, ap_current, target_text (%s = plaza.ledger.blacksmith.target | plaza.ledger.blacksmith.no_target), cost (%dG). |
| `plaza.ledger.blacksmith.target` | %s +%d | %s, %d | %s +%d | %s +%d | %s +%d | %s +%d |  | Blacksmith target descriptor when has_target. Args: display_name (%s, falls back to '아이템'/item), level (%d). Substituted into plaza.ledger.blacksmith.summary third %s. |
| `plaza.ledger.blacksmith.no_target` | 대상 없음 |  | No target | 无目标 | 対象なし | Sin objetivo |  | Blacksmith target descriptor when has_target is false. |
| `plaza.menu.state.executable` | 실행 |  | Run | 执行 | 実行 | Ejecutar |  | Menu action row state tag when _is_executable_menu_type is true. |
| `plaza.menu.state.coming_soon` | 준비 중 |  | Coming soon | 准备中 | 準備中 | Próximamente |  | Menu action row state tag when not executable. Same Korean as plaza.ledger.default.coming_soon; separate key for the menu-row surface. |
| `plaza.fail.not_ready` | 아직 준비 중입니다. |  | Not available yet. | 暂未开放。 | まだ準備中です。 | Aún no está disponible. |  | Inline failure for unrecognized menu type in _trigger_menu_action. |
| `plaza.fail.bank_ledger_missing` | 은행 장부를 열 수 없습니다. |  | Couldn't open the bank ledger. | 无法打开银行账本。 | 銀行の帳簿を開けません。 | No se pudo abrir el registro del banco. |  | Inline failure when _plaza_save_store lacks perform_bank_transaction. |
| `plaza.msg.shop.reorder_done` | 아이템 순서를 바꿨습니다. |  | Reordered the items. | 已调整道具顺序。 | アイテムの順序を変更しました。 | Se reordenaron los objetos. |  | Shop trade reorder success message (inline). |
| `plaza.fail.gacha_device_missing` | 가챠 장치를 찾을 수 없습니다. |  | Gacha device not found. | 找不到扭蛋装置。 | ガチャ装置が見つかりません。 | No se encontró el dispositivo de Gacha. |  | Inline failure when _plaza_gacha_transactions is null. 가챠=Gacha draw. |
| `plaza.fail.lingpet_device_missing` | 링펫 장치를 찾을 수 없습니다. |  | Lingpet device not found. | 找不到 Lingpet 装置。 | Lingpet の装置が見つかりません。 | No se encontró el dispositivo de Lingpet. |  | Inline failure when _plaza_lingpet_store_transactions is null. Same Korean as plaza.msg.lingpet.egg.missing_runtime. |
| `plaza.fail.blacksmith_ledger_missing` | 대장간 장부를 찾을 수 없습니다. |  | Forge ledger not found. | 找不到铁匠铺账本。 | 鍛冶屋の帳簿が見つかりません。 | No se encontró el registro de la herrería. |  | Inline failure when _plaza_blacksmith_transactions is null. 대장간=Forge/Blacksmith per glossary. |
| `plaza.fail.academy_device_missing` | 아카데미 장치를 찾을 수 없습니다. |  | Academy device not found. | 找不到学院装置。 | アカデミーの装置が見つかりません。 | No se encontró el dispositivo de la Academia. |  | Inline failure when _plaza_academy_transactions is null. 아카데미=Academy per glossary. |
| `plaza.fail.tavern_device_missing` | 선술집 의뢰 장치를 찾을 수 없습니다. |  | Tavern quest device not found. | 找不到酒馆委托装置。 | 酒場の依頼装置が見つかりません。 | No se encontró el dispositivo de misiones de la taberna. |  | Inline failure when _plaza_tavern_transactions is null. 선술집=Tavern, 의뢰=quest per glossary. |
| `plaza.msg.lingpet.fallback.ring_core_name` | 링코어 |  | Ring Core | 环核 | リングコア | Núcleo de anillo |  | Fallback name substituted into plaza.msg.lingpet.ring_core.success %s when ring_core_name is absent. FIXED to match glossary EXACT_TEXT 링코어 -&gt; 环核/リングコア/Núcleo de anillo (language_settings_data.gd:2302/2821/3340/3859). |
| `plaza.fallback.item_name` | 아이템 |  | item | 道具 | アイテム | objeto |  | Generic fallback display name used by blacksmith formatter (display_name default, line 2817) and blacksmith ledger target (line 1535). Lowercase generic noun. |
| `plaza.fallback.quest_name` | 의뢰 |  | quest | 委托 | 依頼 | misión |  | Generic fallback quest name used by tavern formatter (quest_name default, lines 2873/2875) and tavern ledger (line 1515). |

### 9.3 Plaza static UI: building menu specs + building display names + action labels + ring-core tier names  (58)
> **배선:** Four string families wire differently and the action-label override is partial — this is the load-bearing correction. (1) Building display names + subtitles + NPC names + greeting lines are CONST DICTS in plaza_scene.gd (BUILDING_MENU_SPECS title/subtitle ~89-121, INTERIOR_NPC_NAMES ~67-75, INTERIOR_GREETING_LINES ~77-85). The seven type words are ALSO duplicated verbatim in plaza_asset_loader.gd get_building_display_name match (~649-665). The const-dict title and the asset_loader match return the SAME seven words, so each building resolves to ONE shared key (plaza.building.<type>.name); fix BOTH sites to translate() the shared key or the asset_loader path leaks Korean. (2) Action labels: plaza_scene.gd:1982 first loads _active_menu_actions from the const-dict BUILDING_MENU_SPECS[type].actions, then OVERRIDES it with each module's get_menu_action_labels() ONLY for academy (1984), lingpet_store (1986), and tavern (1988). gacha, blacksmith, shop, bank are NOT overridden, so their const-dict 'actions' literals ARE the LIVE displayed labels (drawn at _draw_menu_action_row 1465-1466). Therefore: gacha shows the BAKED literal '액티브 캡슐 뽑기 150G' (digit baked into the const-dict, NOT the module's %dG), and blacksmith shows '마지막 아이템 강화', and bank shows the three baked '예금 100G'/'출금 100G'/'이자 정산'. To localize with placeholders, REWIRE gacha and blacksmith (and ideally bank) to source from their transaction modules' get_menu_action_labels() (gacha module returns the %dG form), then translate(\"plaza.action.<id>\") % [cost]. The const-dict baked '...150G'/'...250G' literals and the dead '스킬 획득' (academy)/'퀘스트 받기' (tavern)/'링펫 관리' (lingpet_store) are landmines: they will not localize the digit and several disagree with the live module wording — do not source live labels from the const-dict for overridden buildings; for the 3 currently-unoverridden buildings, add the override so the placeholder template wins. (3) Ring-core tier names are an indexed array RING_CORE_TIER_NAMES (index 1..6; index 0 is an empty-string sentinel with no key). get_ring_core_tier_name(tier) returns by index -> map tier index to plaza.ring_core.tier.<n>. The ring-core ACTION label _build_ring_core_action_label (~238) builds \"%s 링코어 강화 %dG\" % [next_tier_name, cost] with three fallback states (링코어 최대 단계 / 링코어 강화 준비 중 / 링코어 강화). The %s arg must itself be a LOCALIZED tier name, so the composed runtime call is translate(\"plaza.action.lingpet_ring_core.upgrade\") % [translate(plaza.ring_core.tier.N), cost]. The bare \"링코어\" fallback (offer.get next_tier_name default in the %s slot) reuses the existing stat-row \"링코어\" key (Ring Core / 环核 / リングコア / Núcleo de anillo) — do not add a new key for it. (4) Tavern quest catalog (QUEST_CATALOG name/description, plaza_tavern_transactions.gd ~3-22) is player-facing in the tavern offer/report UI and is keyed. Out-of-scope adjacent strings noted but not keyed here: the '닫기' close-button label and the bank ledger line '보유 %dG  |  예금 %dG  |  열쇠 %d' — route to a follow-up plaza-UI surface.

_검증: Read all 6 real source files. KEY WIRING CORRECTION vs proposed table: plaza_scene.gd:1982-1988 sets _active_menu_actions = const-dict BUILDING_MENU_SPECS[type].actions, then OVERRIDES with get_menu_action_labels() ONLY for academy / lingpet_store / tavern. gacha, blacksmith, shop, bank do NOT get an override, so their const-dict 'actions' literals ARE the LIVE displayed labels (verified at draw site _draw_menu_action_row 1465-1466). Consequences I fixed: (1) GACHA live label is the const-dict baked literal '액티브 캡슐 뽑기 150G' (digit baked), NOT the module's %dG form — proposed note wrongly calle_

<details><summary>formatter code → key 매핑 (20)</summary>

- academy live action 0 (module override) -> plaza.action.academy.skill_lesson ("스킬 수업 %dG")
- academy live action 1 (module override) -> plaza.action.academy.skill_exchange ("스킬 교환")
- academy const-dict action 0 (DEAD, overridden) -> plaza.action.academy.acquire_skill_legacy_label ("스킬 획득")
- gacha live action 0 (const-dict, NO override; baked digit) -> plaza.action.gacha.pull_active_capsule ("액티브 캡슐 뽑기 %dG") — rewire to module form to keep %d
- blacksmith live action 0 (const-dict, NO override) -> plaza.action.blacksmith.enhance_last_item ("마지막 아이템 강화")
- bank live action 0 (const-dict, NO override) -> plaza.action.bank.deposit ("예금 100G")
- bank live action 1 (const-dict, NO override) -> plaza.action.bank.withdraw ("출금 100G")
- bank live action 2 (const-dict, NO override) -> plaza.action.bank.settle_interest ("이자 정산")
- tavern live action 0 (module override) -> plaza.action.tavern.accept_quest ("의뢰 받기")
- tavern live action 1 (module override) -> plaza.action.tavern.report_quest ("의뢰 보고")
- tavern const-dict action 0 (DEAD, overridden) -> plaza.action.tavern.accept_quest_legacy_label ("퀘스트 받기")
- lingpet_store live action 0 (module override) -> plaza.action.lingpet_store.pull_resonance_egg ("공명 알 뽑기 %dG")
- lingpet_store const-dict action 1 (DEAD, overridden by ring-core) -> plaza.action.lingpet_store.manage_lingpets ("링펫 관리")
- lingpet_store live action 1 can_upgrade -> plaza.action.lingpet_ring_core.upgrade ("%s 링코어 강화 %dG")
- lingpet_store live action 1 reason=max_ring_core_tier -> plaza.action.lingpet_ring_core.max_tier ("링코어 최대 단계")
- lingpet_store live action 1 reason=missing_lingpet_runtime -> plaza.action.lingpet_ring_core.preparing ("링코어 강화 준비 중")
- lingpet_store live action 1 default fallback -> plaza.action.lingpet_ring_core.upgrade_generic ("링코어 강화")
- ring-core %s tier-name slot index 1..6 -> plaza.ring_core.tier.1..6 (array index 0 is empty-string sentinel, no key)
- ring-core %s missing-tier fallback literal "링코어" -> existing stat-row key (Ring Core / 环核 / リングコア / Núcleo de anillo)
- building display name (BOTH plaza_scene BUILDING_MENU_SPECS.title AND plaza_asset_loader.get_building_display_name) shop/bank/gacha/lingpet_store/blacksmith/tavern/academy -> plaza.building.<type>.name (one shared key per type, fix both sites)
</details>

| key | KO | ph | EN | ZH | JA | ES | T | note |
|---|---|---|---|---|---|---|:-:|---|
| `plaza.building.shop.name` | 상점 |  | Shop | 商店 | ショップ | Tienda |  | Generic building type word; same literal in both the const-dict title and the asset_loader match() — one shared key, fix both sites. |
| `plaza.building.shop.subtitle` | 골드로 아이템을 사고파는 곳 |  | Where you buy and sell items with Gold | 用金币买卖道具的地方 | ゴールドでアイテムを売買する場所 | Donde compras y vendes objetos con Oro |  |  |
| `plaza.building.bank.name` | 은행 |  | Bank | 银行 | 銀行 | Banco |  | Generic type word. |
| `plaza.building.bank.subtitle` | 골드를 맡기고 찾는 금고 |  | A vault to deposit and withdraw Gold | 存取金币的金库 | ゴールドを預けて引き出す金庫 | Una bóveda para depositar y retirar Oro |  | Uses Deposit/Withdraw glossary verbs. |
| `plaza.building.gacha.name` | 가챠샵 |  | Gacha Shop | 扭蛋商店 | ガチャショップ | Tienda Gacha |  | Generic type word. |
| `plaza.building.gacha.subtitle` | 아이템 뽑기 장치 |  | An item gacha-draw machine | 道具抽取装置 | アイテム抽選装置 | Una máquina de tirada gacha de objetos |  |  |
| `plaza.building.lingpet_store.name` | 링펫스토어 |  | Lingpet Store | 灵宠商店 | リンペットストア | Tienda de Lingpets |  | Lingpet is the project glossary term for 링펫. |
| `plaza.building.lingpet_store.subtitle` | 링펫 알과 링펫 관련 상점 |  | A shop for Lingpet eggs and Lingpet goods | 出售灵宠蛋及灵宠相关商品的商店 | リンペットの卵やリンペット関連の品を扱う店 | Una tienda de huevos de Lingpet y artículos de Lingpet |  |  |
| `plaza.building.blacksmith.name` | 대장간 |  | Forge | 铁匠铺 | 鍛冶屋 | Herrería |  | Generic type word; glossary allows Forge/Blacksmith. |
| `plaza.building.blacksmith.subtitle` | 아이템을 강화하는 공방 |  | A workshop to upgrade items | 强化道具的工坊 | アイテムを強化する工房 | Un taller para mejorar objetos |  | 강화 = Upgrade per glossary. |
| `plaza.building.tavern.name` | 선술집 |  | Tavern | 酒馆 | 酒場 | Taberna |  | Generic type word. |
| `plaza.building.tavern.subtitle` | 퀘스트를 받는 의뢰소 |  | A request office where you take on quests | 接受委托任务的委托所 | クエストを受ける依頼所 | Una oficina de encargos donde aceptas misiones |  | 퀘스트/의뢰 both render as Quest per glossary. |
| `plaza.building.academy.name` | 아카데미 |  | Academy | 学院 | アカデミー | Academia |  | Generic type word. |
| `plaza.building.academy.subtitle` | 액티브 스킬을 얻고 교환하는 곳 |  | Where you gain and exchange Active skills | 获得并交换主动技能的地方 | アクティブスキルを習得し交換する場所 | Donde obtienes e intercambias habilidades Activas |  | 액티브 = Active per glossary. |
| `plaza.building.shop.npc_name` | 상점주인 모라 |  | Shopkeeper Mora | 店主 莫拉 | 店主 モラ | Tendera Mora | ✓ | Personal name 모라-&gt;Mora (transliterated); 상점주인 = shopkeeper (type word). |
| `plaza.building.bank.npc_name` | 은행원 도윤 |  | Banker Doyun | 银行职员 道允 | 銀行員 ドユン | Cajero Doyun | ✓ | Personal name 도윤-&gt;Doyun (transliterated). |
| `plaza.building.gacha.npc_name` | 가챠 오퍼레이터 루미 |  | Gacha Operator Lumi | 扭蛋操作员 露米 | ガチャオペレーター ルミ | Operadora de Gacha Lumi | ✓ | Personal name 루미-&gt;Lumi (transliterated). |
| `plaza.building.lingpet_store.npc_name` | 링펫 사육사 링링 |  | Lingpet Breeder Ringring | 灵宠饲养员 玲玲 | リンペット飼育員 リンリン | Criadora de Lingpets Ringring | ✓ | Personal name 링링-&gt;Ringring (transliterated); Lingpet glossary term. |
| `plaza.building.blacksmith.npc_name` | 대장장이 강철 |  | Blacksmith Gangcheol | 铁匠 钢铁 | 鍛冶屋 ガンチョル | Herrero Gangcheol | ✓ | Personal name 강철-&gt;Gangcheol (transliterated per policy); 대장장이 = blacksmith type word. |
| `plaza.building.tavern.npc_name` | 선술집 주인 하랑 |  | Tavern Keeper Harang | 酒馆老板 哈朗 | 酒場の主人 ハラン | Tabernero Harang | ✓ | Personal name 하랑-&gt;Harang (transliterated). |
| `plaza.building.academy.npc_name` | 아카데미 교관 서율 |  | Academy Instructor Seoyul | 学院教官 瑞律 | アカデミー教官 ソユル | Instructor de la Academia Seoyul | ✓ | Personal name 서율-&gt;Seoyul (transliterated). |
| `plaza.building.shop.greeting` | 어서오세요!|필요한 장비를 골라볼까요? |  | Welcome!|Shall we pick out the gear you need? | 欢迎光临！|来挑选你需要的装备吧？ | いらっしゃいませ！|必要な装備を選びましょうか？ | ¡Bienvenido!|¿Elegimos el equipo que necesitas? |  | '|' is a literal line-break separator used by the greeting renderer; keep it identical (same position) in every locale. |
| `plaza.building.bank.greeting` | 금고는 안전합니다.|맡기거나 찾아가세요. |  | The vault is secure.|Deposit or withdraw as you like. | 金库很安全。|尽管存取吧。 | 金庫は安全です。|お預けやお引き出しをどうぞ。 | La bóveda es segura.|Deposita o retira a tu gusto. |  | Keep the '|' line-break separator. |
| `plaza.building.gacha.greeting` | 캡슐이 돌 준비를|마쳤어요. |  | The capsule is all set|and ready to spin. | 胶囊已经准备好|可以开始转动了。 | カプセルを回す準備が|整いました。 | La cápsula está lista|para girar. |  | Keep the '|' line-break separator. |
| `plaza.building.lingpet_store.greeting` | 공명 알이 오늘도|반짝이고 있어요. |  | The resonance eggs are|shimmering again today. | 共鸣蛋今天也|闪闪发光呢。 | 共鳴の卵が今日も|きらめいています。 | Los huevos de resonancia|vuelven a brillar hoy. |  | 공명 알 = resonance egg (Lingpet egg lore term). Keep the '|' separator. |
| `plaza.building.blacksmith.greeting` | 좋은 장비는|망치질을 버팁니다. |  | Good gear can take|a good hammering. | 好装备|经得起锤炼。 | 良い装備は|槌打ちに耐えます。 | El buen equipo aguanta|los martillazos. |  | Keep the '|' line-break separator. |
| `plaza.building.tavern.greeting` | 의뢰서를|확인해 보시겠습니까? |  | Would you like to|check the request board? | 要看一看|委托书吗？ | 依頼書を|確認してみますか？ | ¿Quieres revisar|el tablón de encargos? |  | Keep the '|' line-break separator. |
| `plaza.building.academy.greeting` | 새 기술을 익힐|준비가 됐나요? |  | Are you ready to|learn a new skill? | 准备好|学习新技能了吗？ | 新しい技を覚える|準備はできましたか？ | ¿Listo para|aprender una nueva habilidad? |  | Keep the '|' line-break separator. |
| `plaza.action.academy.skill_lesson` | 스킬 수업 %dG | %d | Skill Lesson %dG | 技能课程 %dG | スキルレッスン %dG | Lección de habilidad %dG |  | LIVE academy action 0 (module override at plaza_scene 1984). %d is gold cost; keep 'G' immediately after %d in all locales. |
| `plaza.action.academy.skill_exchange` | 스킬 교환 |  | Exchange Skill | 交换技能 | スキル交換 | Intercambiar habilidad |  | LIVE academy action 1. |
| `plaza.action.academy.acquire_skill_legacy_label` | 스킬 획득 |  | Acquire Skill | 获得技能 | スキル習得 | Obtener habilidad |  | STALE const-dict literal; overridden at runtime by the academy module's '스킬 수업 %dG'. Keyed for completeness; runtime should not source this. |
| `plaza.action.gacha.pull_active_capsule` | 액티브 캡슐 뽑기 %dG | %d | Draw Active Capsule %dG | 抽取主动胶囊 %dG | アクティブカプセル抽選 %dG | Tirar cápsula Activa %dG |  | 뽑기 = gacha draw; 액티브 = Active. CAUTION: gacha has NO override in plaza_scene, so the LIVE displayed label is the const-dict BAKED literal '액티브 캡슐 뽑기 150G' (digit baked). Rewire gacha to source from this module's %dG form so the placeholder localizes. |
| `plaza.action.blacksmith.enhance_last_item` | 마지막 아이템 강화 |  | Upgrade Last Item | 强化最近的道具 | 直近のアイテムを強化 | Mejorar último objeto |  | 강화 = Upgrade. LIVE blacksmith action 0: blacksmith has NO override so the const-dict literal displays; it equals the module string, so one key is safe. |
| `plaza.action.bank.deposit` | 예금 100G |  | Deposit 100G | 存入 100G | 預金 100G | Depositar 100G |  | 예금 = Deposit per glossary. LIVE bank action 0 (bank has NO module override). The '100' is a baked fixed amount in the const-dict (no placeholder in source); kept as a literal here. If bank cost ever becomes dynamic, switch to '예금 %dG'. |
| `plaza.action.bank.withdraw` | 출금 100G |  | Withdraw 100G | 取出 100G | 引き出し 100G | Retirar 100G |  | 출금 = Withdraw per glossary. LIVE bank action 1. Baked '100' literal in source. |
| `plaza.action.bank.settle_interest` | 이자 정산 |  | Settle Interest | 结算利息 | 利息精算 | Liquidar intereses |  | 이자 = Interest per glossary. LIVE bank action 2. |
| `plaza.action.tavern.accept_quest` | 의뢰 받기 |  | Accept Quest | 接受委托 | クエストを受ける | Aceptar misión |  | LIVE tavern action 0 (module override at plaza_scene 1988); differs from the stale const-dict '퀘스트 받기'. |
| `plaza.action.tavern.report_quest` | 의뢰 보고 |  | Report Quest | 汇报委托 | クエストを報告 | Informar misión |  | LIVE tavern action 1. |
| `plaza.action.tavern.accept_quest_legacy_label` | 퀘스트 받기 |  | Accept Quest | 接受委托 | クエストを受ける | Aceptar misión |  | STALE const-dict duplicate (uses 퀘스트 vs module 의뢰); overridden at runtime. Keyed for completeness. |
| `plaza.action.lingpet_store.pull_resonance_egg` | 공명 알 뽑기 %dG | %d | Draw Resonance Egg %dG | 抽取共鸣蛋 %dG | 共鳴の卵を抽選 %dG | Tirar huevo de resonancia %dG |  | 공명 알 = resonance egg. LIVE lingpet_store action 0 (module override). %d gold cost; keep 'G' suffix. Const-dict copy bakes '공명 알 뽑기 250G' — stale, do not localize that literal. |
| `plaza.action.lingpet_store.manage_lingpets` | 링펫 관리 |  | Manage Lingpets | 管理灵宠 | リンペット管理 | Gestionar Lingpets |  | STALE const-dict action 1; the live module replaces slot 1 with the ring-core upgrade label, so this is overridden at runtime. Keyed for completeness. |
| `plaza.action.lingpet_ring_core.upgrade` | %s 링코어 강화 %dG | %s, %d | Upgrade %s Ring Core %dG | 强化%s环核 %dG | %s リングコア強化 %dG | Mejorar Ring Core %s %dG |  | LIVE lingpet_store action 1 (can_upgrade). %s is a LOCALIZED ring-core tier name (plaza.ring_core.tier.N); %d is gold cost. Keep both placeholders in order; keep 'G' after %d. 강화 = Upgrade, 링코어 = Ring Core. ES keeps 'Ring Core' untranslated to match the ES perk glossary (lingpet_ring_core_upgrade). |
| `plaza.action.lingpet_ring_core.max_tier` | 링코어 최대 단계 |  | Ring Core Max Tier | 环核已达最高阶 | リングコア最大段階 | Ring Core al nivel máximo |  | Fallback state. |
| `plaza.action.lingpet_ring_core.preparing` | 링코어 강화 준비 중 |  | Preparing Ring Core Upgrade | 环核强化准备中 | リングコア強化 準備中 | Preparando mejora de Ring Core |  | Fallback state. |
| `plaza.action.lingpet_ring_core.upgrade_generic` | 링코어 강화 |  | Ring Core Upgrade | 环核强化 | リングコア強化 | Mejora de Ring Core |  | Generic fallback. Matches existing perk key lingpet_ring_core_upgrade rendering (EN 'Ring Core Upgrade', ES 'Mejora de Ring Core'). |
| `plaza.action.lingpet_ring_core.missing_tier_name_fallback` | 링코어 |  | Ring Core | 环核 | リングコア | Núcleo de anillo |  | Reuses the EXISTING stat-row '링코어' key (Ring Core / 环核 / リングコア / Núcleo de anillo at language_settings_data.gd 2302/2821/3340/3859). Only the %s arg when next_tier_name is empty. Prefer referencing that existing key over duplicating. |
| `plaza.ring_core.tier.1` | 스탠다드 |  | Standard | 标准 | スタンダード | Estándar |  | Tier 1 (KR is an English loanword rendered as meaning). Array index 0 is empty-string sentinel (no key). |
| `plaza.ring_core.tier.2` | 부스트 |  | Boost | 增压 | ブースト | Boost |  | Tier 2. |
| `plaza.ring_core.tier.3` | 하이퍼 |  | Hyper | 超载 | ハイパー | Hyper |  | Tier 3. |
| `plaza.ring_core.tier.4` | 오버드라이브 |  | Overdrive | 超频 | オーバードライブ | Overdrive |  | Tier 4. |
| `plaza.ring_core.tier.5` | 얼티밋 |  | Ultimate | 终极 | アルティメット | Ultimate |  | Tier 5. |
| `plaza.ring_core.tier.6` | 제니스 |  | Zenith | 巅峰 | ゼニス | Zenith |  | Tier 6 (max). |
| `plaza.tavern.quest.supply_route.name` | 보급로 점검 |  | Supply Route Inspection | 补给线检查 | 補給路点検 | Inspección de la ruta de suministros |  | Quest catalog name shown in tavern offer/report UI. |
| `plaza.tavern.quest.supply_route.description` | 다음 전투를 마친 뒤 선술집에 보고합니다. |  | Report back to the tavern after finishing your next battle. | 完成下一场战斗后，回酒馆汇报。 | 次の戦闘を終えたら酒場に報告します。 | Informa en la taberna tras terminar tu próxima batalla. |  |  |
| `plaza.tavern.quest.neon_trace.name` | 네온 흔적 조사 |  | Neon Trace Investigation | 霓虹痕迹调查 | ネオンの痕跡調査 | Investigación del rastro de neón |  |  |
| `plaza.tavern.quest.neon_trace.description` | 거리의 이상 신호를 기록하고 다음 광장에서 보고합니다. |  | Record the anomalous signals on the street and report at the next plaza. | 记录街道上的异常信号，并在下一个广场汇报。 | 街の異常な信号を記録し、次の広場で報告します。 | Registra las señales anómalas de la calle e informa en la próxima plaza. |  | 광장 = Plaza (town hub). |
| `plaza.tavern.quest.scroll_delivery.name` | 의뢰서 배달 |  | Request Letter Delivery | 委托书递送 | 依頼書の配達 | Entrega de la carta de encargo |  |  |
| `plaza.tavern.quest.scroll_delivery.description` | 다음 스테이지를 지나 돌아온 뒤 배달 완료를 보고합니다. |  | Clear the next Stage, then return and report the delivery as complete. | 通过下一个关卡后返回，汇报递送完成。 | 次のステージを越えて戻ったら配達完了を報告します。 | Pasa la siguiente Etapa, luego regresa e informa que la entrega está completa. |  | 스테이지 = Stage per glossary. |

### 9.4 Plaza static UI: NPC names + greetings + quests + interior_view labels  (48)
> **배선:** Three source files. (1) plaza_scene.gd INTERIOR_NPC_NAMES (lines 67-75) and INTERIOR_GREETING_LINES (lines 77-85) are dicts keyed by building id (shop/bank/gacha/lingpet_store/blacksmith/tavern/academy); use the building id as the dotted-key leaf. Greeting strings contain a '|' separator that the runtime splits into two bubble lines (plaza_interior_view _draw_shopkeeper_speech_bubble line 655-657 splits on '\\n' then '|'); kept each greeting as ONE piped key so translate(key) returns a piped string the existing split logic handles unchanged. (2) plaza_tavern_transactions.gd QUEST_CATALOG (lines 3-22): each quest has a stable id (supply_route/neon_trace/scroll_delivery) -> map id to plaza.quest.<id>.name / .desc; get_menu_action_labels() (line 26) two actions -> plaza.quest.action.accept / .report. (3) plaza_interior_view.gd static draw-time literals plus printf templates. NPC names embed a TYPE word (상점주인=Shopkeeper, 은행원=Bank Teller, etc.) + a TRANSLITERATED personal name (모라=Mora etc.): translate the type word naturally per locale, transliterate the name (transliteration=true). Templates keeping %s/%d/%dG: '%s을(를) 판매할까요?' (1266), '%s  ·  거래' (932), '%s의 효과를 전투 중에 발동합니다.' (2047), '%dG' (594), 'AP %d' (1365), '%s  %d' panel title+count (1139), '%s %sG'/'%s -' price text (1214). The 판매가/구매가 labels (1213) feed the price_text template as the first %s. The shopkeeper default bubble (654) carries a literal \\n that must be kept in the template. 'ESC' (1120) is a fixed keycap literal - recorded but locale-invariant.

_검증: All 47 source strings verified verbatim against the three real files. Corrections applied: (1) JA 나가기 出る->退出 to match glossary line 3315. (2) JA price_label.sell 売値->売却価格 to match canonical 판매가 (glossary line 3533). (3) JA price_label.buy 買値->購入価格 to mirror corrected sell rendering. (4) ES quest scroll_delivery desc 스테이지 'etapa'->'fase' (glossary renders 스테이지 as 'fase', lines 3833/4188). (5) ES tavern action labels normalized to 'encargo' consistently. Added 2 dropped player-facing strings: line 594 %dG gold display and line 1120 ESC literal. Confirmed: 판매가 EN/ZH match glossary (Sell Price/售价)_

<details><summary>formatter code → key 매핑 (16)</summary>

- quest id supply_route -> plaza.quest.supply_route.name / plaza.quest.supply_route.desc
- quest id neon_trace -> plaza.quest.neon_trace.name / plaza.quest.neon_trace.desc
- quest id scroll_delivery -> plaza.quest.scroll_delivery.name / plaza.quest.scroll_delivery.desc
- tavern menu action index 0 (의뢰 받기) -> plaza.quest.action.accept
- tavern menu action index 1 (의뢰 보고) -> plaza.quest.action.report
- building id shop -> plaza.npc.shop / plaza.greeting.shop
- building id bank -> plaza.npc.bank / plaza.greeting.bank
- building id gacha -> plaza.npc.gacha / plaza.greeting.gacha
- building id lingpet_store -> plaza.npc.lingpet_store / plaza.greeting.lingpet_store
- building id blacksmith -> plaza.npc.blacksmith / plaza.greeting.blacksmith
- building id tavern -> plaza.npc.tavern / plaza.greeting.tavern
- building id academy -> plaza.npc.academy / plaza.greeting.academy
- trade hover panel == 'player' -> plaza.interior.price_label.sell ; else -> plaza.interior.price_label.buy
- price > 0 -> plaza.interior.price_text_value ; else -> plaza.interior.price_text_unavailable
- strewn label != '' -> plaza.interior.strewn_trade_label ; else -> plaza.interior.strewn_trade_label_fallback
- item has description/desc/korean_desc/tooltip/summary -> (use item desc) ; elif name != '' -> plaza.interior.trade.desc_fallback_named ; else -> plaza.interior.trade.desc_fallback_generic
</details>

| key | KO | ph | EN | ZH | JA | ES | T | note |
|---|---|---|---|---|---|---|:-:|---|
| `plaza.npc.shop` | 상점주인 모라 |  | Shopkeeper Mora | 店主 莫拉 | 店主 モラ | Tendera Mora | ✓ | Type word 상점주인=Shopkeeper; personal name 모라-&gt;Mora transliterated. |
| `plaza.npc.bank` | 은행원 도윤 |  | Bank Teller Doyun | 银行职员 道允 | 銀行員 ドユン | Cajero Doyun | ✓ | Type word 은행원=Bank Teller; 도윤-&gt;Doyun. |
| `plaza.npc.gacha` | 가챠 오퍼레이터 루미 |  | Gacha Operator Lumi | 扭蛋操作员 露米 | ガチャオペレーター ルミ | Operadora de Gacha Lumi | ✓ | Type words 가챠 오퍼레이터=Gacha Operator; 루미-&gt;Lumi. |
| `plaza.npc.lingpet_store` | 링펫 사육사 링링 |  | Lingpet Keeper Ringring | 灵宠饲养员 玲玲 | リンペット飼育員 リンリン | Cuidadora de Lingpets Ringring | ✓ | 링펫=Lingpet (glossary); 사육사=Keeper; 링링-&gt;Ringring. |
| `plaza.npc.blacksmith` | 대장장이 강철 |  | Blacksmith Gangcheol | 铁匠 钢铁 | 鍛冶屋 ガンチョル | Herrero Gangcheol | ✓ | Type word 대장장이=Blacksmith; 강철-&gt;Gangcheol (proper-noun policy; ZH uses literal 钢铁 reading of the name). |
| `plaza.npc.tavern` | 선술집 주인 하랑 |  | Tavern Owner Harang | 酒馆老板 哈朗 | 酒場の主人 ハラン | Tabernero Harang | ✓ | Type words 선술집 주인=Tavern Owner; 하랑-&gt;Harang. |
| `plaza.npc.academy` | 아카데미 교관 서율 |  | Academy Instructor Seoyul | 学院教官 瑞栗 | アカデミー教官 ソユル | Instructor de la Academia Seoyul | ✓ | Type words 아카데미 교관=Academy Instructor; 서율-&gt;Seoyul. |
| `plaza.greeting.shop` | 어서오세요!|필요한 장비를 골라볼까요? |  | Welcome!|Shall we pick out some gear? | 欢迎光临！|来挑选需要的装备吧？ | いらっしゃいませ！|必要な装備を選びましょうか？ | ¡Bienvenido!|¿Elegimos algo de equipo? |  | '|' separator preserved; runtime splits into two speech-bubble lines. |
| `plaza.greeting.bank` | 금고는 안전합니다.|맡기거나 찾아가세요. |  | The vault is secure.|Deposit or withdraw as you like. | 金库十分安全。|可以存入或取出。 | 金庫は安全です。|預けるか引き出してください。 | La bóveda es segura.|Deposita o retira a tu gusto. |  | 맡기다/찾다 align with Deposit/Withdraw glossary; '|' preserved. |
| `plaza.greeting.gacha` | 캡슐이 돌 준비를|마쳤어요. |  | The capsules are ready|to spin. | 扭蛋已经准备好|开始转动了。 | カプセルが回る準備は|できています。 | Las cápsulas están listas|para girar. |  | '|' preserved. |
| `plaza.greeting.lingpet_store` | 공명 알이 오늘도|반짝이고 있어요. |  | The resonance eggs are|shining again today. | 共鸣蛋今天也|闪闪发光呢。 | 共鳴の卵が今日も|輝いていますよ。 | Los huevos de resonancia|brillan otra vez hoy. |  | 공명 알=resonance egg (Lingpet hatching motif); '|' preserved. |
| `plaza.greeting.blacksmith` | 좋은 장비는|망치질을 버팁니다. |  | Good gear withstands|the hammer's blows. | 好装备经得起|锤子的敲打。 | 良い装備は|ハンマーに耐えます。 | El buen equipo aguanta|los golpes del martillo. |  | '|' preserved. |
| `plaza.greeting.tavern` | 의뢰서를|확인해 보시겠습니까? |  | Care to take a look|at the quest board? | 要看看|委托书吗？ | 依頼書を|確認してみますか？ | ¿Quieres echar un vistazo|a los encargos? |  | 의뢰=Quest (glossary); '|' preserved. |
| `plaza.greeting.academy` | 새 기술을 익힐|준비가 됐나요? |  | Ready to learn|a new technique? | 准备好学习|新技能了吗？ | 新しい技を学ぶ|準備はできましたか？ | ¿Listo para aprender|una nueva técnica? |  | '|' preserved. |
| `plaza.quest.supply_route.name` | 보급로 점검 |  | Supply Route Inspection | 补给线检查 | 補給路点検 | Inspección de la ruta de suministro |  | Quest id supply_route. |
| `plaza.quest.supply_route.desc` | 다음 전투를 마친 뒤 선술집에 보고합니다. |  | Report to the tavern after finishing the next battle. | 结束下一场战斗后向酒馆报告。 | 次の戦闘を終えたら酒場に報告します。 | Informa en la taberna tras terminar la próxima batalla. |  |  |
| `plaza.quest.neon_trace.name` | 네온 흔적 조사 |  | Neon Trace Investigation | 霓虹痕迹调查 | ネオンの痕跡調査 | Investigación del rastro neón |  | Quest id neon_trace. |
| `plaza.quest.neon_trace.desc` | 거리의 이상 신호를 기록하고 다음 광장에서 보고합니다. |  | Record the strange signals on the streets and report at the next plaza. | 记录街道上的异常信号，并在下一个广场报告。 | 街の異常な信号を記録し、次の広場で報告します。 | Registra las señales extrañas de las calles e informa en la próxima plaza. |  | 광장=Plaza (hub). |
| `plaza.quest.scroll_delivery.name` | 의뢰서 배달 |  | Quest Letter Delivery | 委托书递送 | 依頼書の配達 | Entrega del encargo |  | Quest id scroll_delivery; 의뢰서=quest letter. |
| `plaza.quest.scroll_delivery.desc` | 다음 스테이지를 지나 돌아온 뒤 배달 완료를 보고합니다. |  | Pass through the next stage, return, then report the delivery as complete. | 通过下一关返回后，报告递送已完成。 | 次のステージを越えて戻ったら、配達完了を報告します。 | Pasa la próxima fase, regresa e informa que la entrega está completa. |  | 스테이지=Stage; ES rendering corrected to 'fase' per glossary (다음 스테이지=Siguiente fase, line 3833). |
| `plaza.quest.action.accept` | 의뢰 받기 |  | Accept Quest | 接受委托 | 依頼を受ける | Aceptar encargo |  | Tavern menu action 0. |
| `plaza.quest.action.report` | 의뢰 보고 |  | Report Quest | 汇报委托 | 依頼を報告 | Reportar encargo |  | Tavern menu action 1. |
| `plaza.interior.gold_amount` | %dG | %d | %dG | %dG | %dG | %dG |  | ADDED (was dropped). %d = plaza_gold; trailing G = Gold (glossary). Layout-only template, locale-invariant. |
| `plaza.interior.exit` | 나가기 |  | Exit | 离开 | 退出 | Salir |  | JA corrected 出る-&gt;退出 to match glossary (나가기 line 3315). |
| `plaza.interior.npc_default_message` | 필요한 물건이 있으면 테이블의 물건을 골라봐. |  | If you need something, pick an item off the table. | 需要什么的话，从桌上挑选吧。 | 必要なものがあれば、テーブルの品を選んでね。 | Si necesitas algo, elige un objeto de la mesa. |  | Shown when _last_message is empty in the side NPC panel. |
| `plaza.interior.shopkeeper_default_message` | 필요한 거 있어?<br>좋은 걸로 골라왔지. |  | Need anything?<br>I brought in the good stuff. | 需要什么吗？<br>我可挑了些好货。 | 何かいる？<br>良い物を選んできたよ。 | ¿Necesitas algo?<br>Traje lo mejorcito. |  | Contains literal \n; runtime splits on \n then '|' (lines 655-657). Keep the newline in the template. |
| `plaza.interior.trade.close_hint` | ESC |  | ESC | ESC | ESC | ESC |  | ADDED (was dropped). Fixed keycap literal; locale-invariant. |
| `plaza.interior.trade.title` | 아이템 거래 |  | Item Trade | 物品交易 | アイテム取引 | Intercambio de objetos |  |  |
| `plaza.interior.trade.player_panel_title` | 내 인벤토리 (판매) |  | My Inventory (Sell) | 我的背包（出售） | 自分のインベントリ（売却） | Mi inventario (Vender) |  | 인벤토리=Inventory (glossary). Passed as %s into '%s  %d' at line 1139. |
| `plaza.interior.trade.shop_panel_title` | 상점 물품 (구매) |  | Shop Stock (Buy) | 商店物品（购买） | 店の品物（購入） | Mercancía de la tienda (Comprar) |  | Passed as %s into '%s  %d' at line 1139. |
| `plaza.interior.trade.panel_title_count` | %s  %d | %s, %d | %s  %d | %s  %d | %s  %d | %s  %d |  | %s = localized panel title, %d = item count. Layout-only template. |
| `plaza.interior.strewn_trade_label` | %s  ·  거래 | %s | %s  ·  Trade | %s  ·  交易 | %s  ·  取引 | %s  ·  Comerciar |  | %s = object label; 거래=Trade. |
| `plaza.interior.strewn_trade_label_fallback` | 거래 |  | Trade | 交易 | 取引 | Comerciar |  | Used when label == '' so the '%s  ·  거래' template degrades to bare '거래'. |
| `plaza.interior.price_label.sell` | 판매가 |  | Sell Price | 售价 | 売却価格 | Precio de venta |  | Matches glossary 판매가 exactly (line 2495/3014/3533/4052). JA corrected 売値-&gt;売却価格. |
| `plaza.interior.price_label.buy` | 구매가 |  | Buy Price | 买价 | 購入価格 | Precio de compra |  | No glossary entry; mirrors corrected 판매가 style. JA corrected 買値-&gt;購入価格. |
| `plaza.interior.price_text_value` | %s %sG | %s, %s | %s %sG | %s %sG | %s %sG | %s %sG |  | First %s = localized price label, second %s = formatted gold amount; trailing G = Gold. Layout-only template. |
| `plaza.interior.price_text_unavailable` | %s - | %s | %s - | %s - | %s - | %s - |  | %s = localized price label; '-' when no price. Layout-only template. |
| `plaza.interior.todays_deal` | 오늘의 특가 |  | Today's Deal | 今日特价 | 本日の特価 | Oferta del día |  |  |
| `plaza.interior.sell_confirm.equipped_warning` | 장착 중인 아이템입니다 |  | This item is currently equipped | 该物品正在装备中 | 装備中のアイテムです | Este objeto está equipado |  |  |
| `plaza.interior.sell_confirm.prompt` | %s을(를) 판매할까요? | %s | Sell %s? | 要出售 %s 吗？ | %s を売却しますか？ | ¿Vender %s? |  | %s = item name. Korean 을(를) object particle dropped in target locales per policy. |
| `plaza.interior.sell_confirm.sell_button` | 판매 |  | Sell | 出售 | 売却 | Vender |  |  |
| `plaza.interior.cancel` | 취소 |  | Cancel | 取消 | キャンセル | Cancelar |  | Shared cancel label at both 취소 callsites (1268, 1370). ES=Cancelar matches glossary (line 4212). |
| `plaza.interior.object_panel.run_hint` | 선택한 오브젝트의 기능을 실행합니다. |  | Run the function of the selected object. | 执行所选对象的功能。 | 選択したオブジェクトの機能を実行します。 | Ejecuta la función del objeto seleccionado. |  |  |
| `plaza.interior.object_panel.ap_text` | AP %d | %d | AP %d | AP %d | AP %d | PA %d |  | AP=Action Point (glossary). %d = current AP. ES uses PA (Puntos de Acción); EN/ZH/JA keep AP. |
| `plaza.interior.object_panel.confirm_button` | 실행 |  | Run | 执行 | 実行 | Ejecutar |  |  |
| `plaza.interior.trade.item_name_fallback` | 아이템 |  | Item | 物品 | アイテム | Objeto |  | Default display name when item has no localized name. |
| `plaza.interior.trade.desc_fallback_named` | %s의 효과를 전투 중에 발동합니다. | %s | Activates %s's effect during battle. | 在战斗中发动 %s 的效果。 | 戦闘中に %s の効果を発動します。 | Activa el efecto de %s durante la batalla. |  | %s = item name. |
| `plaza.interior.trade.desc_fallback_generic` | 상세 효과는 장착 후 확인할 수 있습니다. |  | Detailed effects can be checked after equipping. | 装备后可查看详细效果。 | 詳しい効果は装備後に確認できます。 | Los efectos detallados se pueden ver tras equiparlo. |  | Shown when item has neither description nor name. |

### 9.5 Defeat settlement screen  (24)
> **배선:** Source: godot/scripts/core/defeat_settlement_screen.gd (verbatim re-read). Player-facing Korean strings: draw() lines 83-114 (도전 종료 83, 이번 링피아 여정의 기록입니다 84, 획득 골드 91, 최종 스코어 92, 도달 보스 93, 아이템 98, 액티브 99, 패시브 100, 퍽 102, 클리어한 보스 107, gold-breakdown footer 108, 메인 메뉴로 114), STAGE_BOSS_NAMES 11-16, and helper formatters (_build_stage_snapshot reached_stage_label 161, _get_stage_boss_name fallback 265, _format_labels 없음 335 / +%d 341, _build_perk_labels '%s Lv.%d' 250, stat-box current_boss fallback '알 수 없음' 93).  PERK NAMES — DO NOT add new keys: _get_perk_name() (line 254) pulls the display name from RuntimePerkCatalog.get_perk_data().name (Korean perk name by perk_id). Localize through the EXISTING PERK_NAME_EN/ZH/JA/ES maps keyed by perk_id, NOT by new defeat.* keys. The screen formats '%s Lv.%d' (line 250); the Lv. template is captured as defeat.settlement.perk_level_entry, but the %s token MUST come from the perk-name map.  ITEM NAMES are also dynamic (ActiveItemCatalog.get_display_name line 222 / MythicItemCatalog.get_display_name line 224, or the item dict display_name at line 215) — localize via the existing item-name maps, NOT new keys.  BOSS NAMES: every STAGE_BOSS_NAMES value already exists in EXACT_TEXT_* EXCEPT 폰크 (Ponk), which has NO existing rendering anywhere (new defeat.boss.ponk added). Route boss-name localization through the existing EXACT_TEXT_* exact-match path (covers 5 of 6) and only fall back to defeat.boss.ponk for 폰크. The defeat.boss.* mirrors carry identical text so 달지/홍련 etc. cannot drift; keep ONE source of truth.  GLOSSARY REUSE (verified by grep of language_settings_data.gd): 획득 골드=Gold Acquired/获得金币/獲得ゴールド/Oro obtenido; 최종 스코어=Final Score/最终比分/最終スコア/Puntuación final; 액티브=Active/主动/アクティブ/Activo; 패시브=Passive/被动/パッシブ/Pasivo; 퍽=Perk/升级/パーク/Perk; 없음=None/无/なし/Ninguno; 멘헤라걸=Menhera Girl/病娇少女/メンヘラガール/Chica Menhera. Authored EN/ZH/JA/ES for those keys match the existing exact-match values verbatim. Bare '아이템' has only PT_BR/RU renderings, so EN/ZH/JA/ES are newly authored (Items/道具/アイテム/Objetos), aligned to the established item-word convention.  Lv. CONVENTION (verified): the project keeps 'Lv.%d' literally in ALL locales — '교감 Lv.%d' -> ZH '羁绊 Lv.%d' (line 2638), ES uses 'Lv.5' (line 773). The proposal's ZH '等级%d' and ES 'Nv.%d' were drift and are corrected to 'Lv.%d'.  PLACEHOLDERS: '%dG' = integer + literal G; footer (line 108) uses two %dG in order [plaza, runtime] — both kept literal-G in source order. reached_stage_label (161), stage_n_boss fallback (265), list_overflow_more (341) use one %d. perk_level_entry uses %s then %d. All locales preserve identical placeholder count and order.  NOTE: 최종 스코어's VALUE is '%d : %d' (player : boss, line 92) — that value is a non-translatable numeric format, so no key was authored for it; only the label is keyed.

_검증: Re-read defeat_settlement_screen.gd in full; all 24 Korean strings quoted verbatim against source line numbers (no drift, none dropped, none invented). Cross-checked language_settings_data.gd by grep for every reused term. FIXED 4 issues: (1) perk_level_entry ZH '등급/等级%d' -> 'Lv.%d' to match the project's universal 'Lv.%d' convention (lang 2638 羁绊 Lv.%d); (2) perk_level_entry ES 'Nv.%d' -> 'Lv.%d' (lang 773 ES uses Lv.5); (3) 퍽 section EN 'Perks' -> 'Perk' to match existing EXACT_TEXT singular 'Perk' (lang 2262); (4) 퍽 section ES 'Perks' -> 'Perk' (lang 3819). Verified placeholder parity: gold_

<details><summary>formatter code → key 매핑 (13)</summary>

- STAGE_BOSS_NAMES[1]=달지 -> REUSE existing EXACT_TEXT '달지' (Dalji); defeat.boss.dalji is the same-text mirror
- STAGE_BOSS_NAMES[2]=악어장군 -> REUSE existing EXACT_TEXT '악어장군' (Alligator General); defeat.boss.alligator_general mirror
- STAGE_BOSS_NAMES[3]=멘헤라걸 -> REUSE existing EXACT_TEXT '멘헤라걸' (Menhera Girl); defeat.boss.menhera_girl mirror
- STAGE_BOSS_NAMES[4]=폰크 -> defeat.boss.ponk (NEW — no existing rendering anywhere)
- STAGE_BOSS_NAMES[5]=홍련 -> REUSE existing EXACT_TEXT '홍련' (Hongryun); defeat.boss.hongryun mirror
- STAGE_BOSS_NAMES[6]=테트리서 -> REUSE existing EXACT_TEXT '테트리서' (Tetrisser); defeat.boss.tetrisser mirror
- _get_stage_boss_name(stage_id) fallback (stage_id not in STAGE_BOSS_NAMES) -> defeat.boss.stage_n_boss (template '스테이지 %d 보스')
- current_boss stat fallback (stage.get('current_boss', '알 수 없음')) -> defeat.settlement.boss_unknown
- _build_perk_labels '%s Lv.%d' (line 250): %s token -> EXISTING PERK_NAME_* map by perk_id (NOT a new key); template -> defeat.settlement.perk_level_entry
- _format_item_label active item display_name -> EXISTING ActiveItemCatalog.get_display_name / item-name maps (NOT a new key)
- _format_item_label passive/mythic item display_name -> EXISTING MythicItemCatalog.get_display_name / item-name maps (NOT a new key)
- _format_labels empty list -> defeat.settlement.list_empty ('없음', REUSE existing)
- _format_labels overflow -> defeat.settlement.list_overflow_more ('+%d')
</details>

| key | KO | ph | EN | ZH | JA | ES | T | note |
|---|---|---|---|---|---|---|:-:|---|
| `defeat.settlement.title` | 도전 종료 |  | Run Over | 挑战结束 | 挑戦終了 | Fin del intento |  | Panel header. No existing rendering in language_settings_data.gd (verified). 'Run' = a single Lingpia attempt/journey. |
| `defeat.settlement.subtitle` | 이번 링피아 여정의 기록입니다 |  | A record of this Lingpia journey | 本次林皮亚旅程的记录 | 今回のリンピア旅路の記録です | Un registro de este viaje por Lingpia |  | No existing rendering (verified). 링피아=Lingpia (world/setting proper noun, romanized). |
| `defeat.settlement.stat_gold_acquired` | 획득 골드 |  | Gold Acquired | 获得金币 | 獲得ゴールド | Oro obtenido |  | REUSE existing EXACT_TEXT '획득 골드' (lang data 2273/2792/3311/3830 = Gold Acquired/获得金币/獲得ゴールド/Oro obtenido). Authored values match the existing rendering exactly to avoid drift; prefer routing through the exact-match path. |
| `defeat.settlement.stat_final_score` | 최종 스코어 |  | Final Score | 最终比分 | 最終スコア | Puntuación final |  | REUSE existing EXACT_TEXT '최종 스코어' (lang data 2274/2793/3312/3831). NOTE: the stat VALUE is '%d : %d' (player : boss, line 92) and is NOT translatable; only this LABEL keys here. Authored values match existing exactly. |
| `defeat.settlement.stat_reached_boss` | 도달 보스 |  | Boss Reached | 抵达Boss | 到達ボス | Boss alcanzado |  | No existing rendering (verified). 보스=Boss (glossary). Value is the boss name (dynamic, from STAGE_BOSS_NAMES or '알 수 없음' fallback). |
| `defeat.settlement.section_items` | 아이템 |  | Items | 道具 | アイテム | Objetos |  | Section header. Bare '아이템' only has PT_BR(Item)/RU(Предмет) renderings (lang data 4233/4366) — EN/ZH/JA/ES are NEW. Chose 道具/アイテム/Objetos to match the established item-name convention (액티브 아이템=主动道具/アクティブアイテム/Objeto activo). Plural-ish since it heads a list. |
| `defeat.settlement.label_active` | 액티브 |  | Active | 主动 | アクティブ | Activo |  | REUSE existing EXACT_TEXT '액티브' (lang data 2258/2777/3296/3815 = Active/主动/アクティブ/Activo). Source concatenates the label + two spaces + a runtime-built joined list; key the label only (spacing/concat is runtime layout). |
| `defeat.settlement.label_passive` | 패시브 |  | Passive | 被动 | パッシブ | Pasivo |  | REUSE existing EXACT_TEXT '패시브' (lang data 2259/2778/3297/3816 = Passive/被动/パッシブ/Pasivo). Label-only key; concat is runtime layout. |
| `defeat.settlement.section_perks` | 퍽 |  | Perk | 升级 | パーク | Perk |  | REUSE existing EXACT_TEXT '퍽' (lang data 2262/2781/3300/3819 = Perk/升级/パーク/Perk). FIXED: proposal had EN/ES 'Perks' (plural) which would DRIFT from the existing 'Perk' exact-match; aligned to singular so the section header routes cleanly through the existing path. ZH 升级 / JA パーク match existing. |
| `defeat.settlement.perk_level_entry` | %s Lv.%d | %s, %d | %s Lv.%d | %s Lv.%d | %s Lv.%d | %s Lv.%d |  | Per-perk list entry. %s = perk display name from the EXISTING PERK_NAME_* map by perk_id (NOT a new key; _get_perk_name -&gt; RuntimePerkCatalog.get_perk_data().name); %d = perk level. FIXED: the project keeps 'Lv.%d' literally in ALL locales (lang data 2638 교감 Lv.%d -&gt; ZH '羁绊 Lv.%d'; ES 773 uses 'Lv.5'). Proposal's ZH '等级%d' and ES 'Nv.%d' were drift and are corrected to 'Lv.%d'. Placeholder order %s then %d preserved in every locale. |
| `defeat.settlement.cleared_bosses_label` | 클리어한 보스 |  | Bosses Cleared | 已通关Boss | クリアしたボス | Bosses derrotados |  | No existing rendering (verified). 보스=Boss. Source concatenates label + two spaces + a runtime-built joined boss-name list; key the label only. |
| `defeat.settlement.gold_breakdown` | 광장의 보유 골드 %dG + 이번 도전 골드 %dG | %dG, %dG | Plaza Gold %dG + This Run's Gold %dG | 广场持有金币 %dG + 本次挑战金币 %dG | 広場の所持ゴールド %dG ＋ 今回の挑戦ゴールド %dG | Oro de la Plaza %dG + Oro de este intento %dG |  | 광장=Plaza, 골드=Gold/G. First %dG = plaza gold (gold.plaza), second %dG = runtime/this-run gold (gold.runtime), in this order. Both '%dG' literal-G tokens kept in the same order in every locale. Verbatim-confirmed from source (single + separator, two %dG). |
| `defeat.settlement.button_main_menu` | 메인 메뉴로 |  | To Main Menu | 返回主菜单 | メインメニューへ | Al menú principal |  | No existing rendering (verified). Dismiss button returns to main menu. '...로' = directional 'to'. |
| `defeat.settlement.list_empty` | 없음 |  | None | 无 | なし | Ninguno |  | REUSE existing EXACT_TEXT '없음' (lang data 2434/2953/3472/3991 = None/无/なし/Ninguno). Shown when an item/perk/boss list is empty. Authored values match existing exactly. |
| `defeat.settlement.list_overflow_more` | +%d | %d | +%d | +%d | +%d | +%d |  | Overflow counter appended after LIST_LIMIT(5) entries; %d = remaining count. No translatable words; identical across locales (listed for completeness). Verbatim-confirmed. |
| `defeat.settlement.boss_unknown` | 알 수 없음 |  | Unknown | 未知 | 不明 | Desconocido |  | Fallback when current_boss missing. CONFIRMED no existing '알 수 없음' rendering in language_settings_data.gd — NEW key required. |
| `defeat.settlement.reached_stage_label` | 스테이지 %d | %d | Stage %d | 第%d关 | ステージ%d | Fase %d |  | 스테이지 convention: ZH 关 (다음 스테이지-&gt;下一关), JA ステージ, ES fase (verified lang data 2276/3314/3833). %d = stage number. ZH '第%d关' is consistent with 关; JA/ES match existing exactly. Stored in snapshot; not currently drawn in draw() but is a player-facing snapshot label. |
| `defeat.boss.dalji` | 달지 |  | Dalji | 达尔吉 | ダルジ | Dalji | ✓ | Boss proper name. ALREADY in EXACT_TEXT_* (lang data 2354/2873/3392/3911 = Dalji/达尔吉/ダルジ/Dalji). REUSE existing exact-match; values match. Keep ONE source of truth. |
| `defeat.boss.alligator_general` | 악어장군 |  | Alligator General | 鳄鱼将军 | ワニ将軍 | General Caimán |  | Descriptive boss title (translated). ALREADY in EXACT_TEXT_* (lang data 2355/2874/3393/3912 = Alligator General/鳄鱼将军/ワニ将軍/General Caimán). REUSE existing exact-match; values match. |
| `defeat.boss.menhera_girl` | 멘헤라걸 |  | Menhera Girl | 病娇少女 | メンヘラガール | Chica Menhera |  | Boss title. CONFIRMED already in EXACT_TEXT_* (lang data 2401/2920/3439/3958 = Menhera Girl/病娇少女/メンヘラガール/Chica Menhera). REUSE existing exact-match; all four values match. |
| `defeat.boss.ponk` | 폰크 |  | Ponk | 彭克 | ポンク | Ponk | ✓ | NEW — CONFIRMED '폰크' has NO existing rendering in language_settings_data.gd (grep miss). Boss proper name, transliterated (Ponk). ZH 彭克 is a sensible transliteration; flag for reviewer/native confirmation. |
| `defeat.boss.hongryun` | 홍련 |  | Hongryun | 红莲 | 紅蓮 | Hongryun | ✓ | Boss proper name. ALREADY in EXACT_TEXT_* (lang data 2356/2875/3394/3913 = Hongryun/红莲/紅蓮/Hongryun). REUSE existing exact-match; values match. ZH 红莲 / JA 紅蓮 are the established CJK renderings of 홍련. |
| `defeat.boss.tetrisser` | 테트리서 |  | Tetrisser | 特崔瑟 | テトリサー | Tetrisser | ✓ | Boss proper name (Tetris-themed). ALREADY in EXACT_TEXT_* (lang data 2361/2880/3399/3918 = Tetrisser/特崔瑟/テトリサー/Tetrisser). REUSE existing exact-match; values match. |
| `defeat.boss.stage_n_boss` | 스테이지 %d 보스 | %d | Stage %d Boss | 第%d关Boss | ステージ%dボス | Boss de la fase %d |  | Fallback boss label when stage_id not in STAGE_BOSS_NAMES. No existing rendering (verified). %d = stage number. 스테이지=Stage/关/ステージ/fase, 보스=Boss per glossary. Placeholder %d kept in source order in every locale. |

### 9.6 Defeat chance-gems continue screen  (9)
> **배선:** All strings are static labels except: (1) the two multiline guide blocks (l.344 default vs l.347 last-chance) selected by runtime branch `visual_remaining <= 0`; (2) the three mutually-exclusive status messages inside `_draw_continue_status_text`, selected by `_phase == PRESENT` (l.704-706) / `_is_shatter_window_active() or _has_shatter_completed()` (l.717-719) / else fallthrough (l.725). SEGMENTED-COLOR: the l.704-706 and l.717-719 messages are drawn as THREE separately-colored segments (white surround + cyan '1개' count + white tail) via `_draw_centered_text_segments`. Because word order differs per locale, the count segment cannot stay mid-string for all languages. Recommended runtime: keep ONE template key per full message with a `%s` for the colored count, render translate(key) % [count], then color-highlight the substring matching the count argument (or split the localized string on the count token). The standalone count token '1개' is given its own key (defeat.continue.gem_count_one) so the runtime can color-match/substitute the highlighted substring. Multiline guides preserve the literal \n and must render with `_draw_multiline_centered_text` per-line centering (splits on \n). EN/ZH/JA/ES authored; PT-BR/RU fall back to EN.

_검증: Read the real source (defeat_chance_gems_continue_screen.gd) at lines 316, 317, 344-347, 354, and the segmented status block 697-725. All 9 Korean strings are quoted VERBATIM and match source byte-for-byte, including both \n line breaks in the two guide blocks and the trailing ellipsis '...' on 흔들립니다. Confirmed the two segmented messages are each three separately-colored draw_string segments via _draw_centered_text_segments (white surround + cyan '1개' count + white tail); reconstructed full Korean is accurate. Placeholders: only the two segmented full-message templates carry %s (one each, same_

<details><summary>formatter code → key 매핑 (6)</summary>

- status_present (l.699-711, _phase == PRESENT) -> defeat.continue.gem_consume_on_confirm
- status_shatter_done (l.712-723, _is_shatter_window_active() or _has_shatter_completed()) -> defeat.continue.gem_consumed
- status_shatter_idle (l.725, fallthrough) -> defeat.continue.gem_trembling
- guide_default (l.344, visual_remaining > 0) -> defeat.continue.guide_default
- guide_last_chance (l.347, visual_remaining <= 0) -> defeat.continue.guide_last_chance
- colored_count_token (l.705, l.718 cyan '1개') -> defeat.continue.gem_count_one
</details>

| key | KO | ph | EN | ZH | JA | ES | T | note |
|---|---|---|---|---|---|---|:-:|---|
| `defeat.continue.title` | 패배 |  | Defeat | 失败 | 敗北 | Derrota |  | Screen title. Matches existing 패배 -&gt; Defeat glossary (cf. 'Defeat Prevention' / 'Round-Loss Cancel Chance' in language_settings_data.gd l.2494/2544). |
| `defeat.continue.subtitle` | 아쉽지만 다음 기회를 노려보세요. |  | Better luck next time — aim for the next chance. | 很遗憾，期待下一次机会吧。 | 惜しいですが、次のチャンスを狙いましょう。 | Lástima, pero busca la próxima oportunidad. |  | Subtitle under the Defeat title. |
| `defeat.continue.guide_default` | 기회의 보석은 패배 시 1개가 소모됩니다.<br>모든 보석이 소모되면 더 이상 도전할 수 없습니다. |  | One Chance Gem is consumed each time you are defeated.<br>When all gems are gone, you can no longer challenge. | 每次失败会消耗 1 颗机会宝石。<br>所有宝石耗尽后，将无法再挑战。 | 敗北するとチャンスジェムが1個消費されます。<br>すべてのジェムが消費されると、これ以上挑戦できません。 | Se consume una Gema de Oportunidad cada vez que eres derrotado.<br>Cuando se agoten todas las gemas, ya no podrás desafiar. |  | Default guide shown while visual_remaining &gt; 0. PRESERVE the literal \n line break: rendered line-by-line by _draw_multiline_centered_text (l.728, splits on \n, centers each line). 기회의 보석 = Chance Gem (기회=chance, 보석=gem). |
| `defeat.continue.guide_last_chance` | 이번이 마지막 기회입니다.<br>다음 패배 시 게임이 종료됩니다. |  | This is your last chance.<br>The game ends on your next defeat. | 这是最后的机会。<br>下次失败时游戏将结束。 | これが最後のチャンスです。<br>次に敗北するとゲームが終了します。 | Esta es tu última oportunidad.<br>El juego terminará en tu próxima derrota. |  | Last-chance guide shown when visual_remaining &lt;= 0 (drawn in gold). PRESERVE the literal \n line break (multiline centered). |
| `defeat.continue.confirm_button` | 확인 |  | Confirm | 确认 | 決定 | Confirmar |  | Confirm button label (drawn only in PRESENT phase). ES matches existing 확인 -&gt; Confirmar in language_settings_data.gd:4213. EN/ZH/JA have no pre-existing button rendering in the map; Confirm/确认/決定 are the natural game-UI renderings. |
| `defeat.continue.gem_consume_on_confirm` | 확인하면 기회의 보석이 1개 소모됩니다. | %s | Confirming will consume %s Chance Gem. | 确认后将消耗 %s 颗机会宝石。 | 決定するとチャンスジェムを %s 個消費します。 | Al confirmar se consumirá %s Gema de Oportunidad. |  | SEGMENTED 3-color message, PRESENT phase. Source segments: '확인하면 기회의 보석이 '(white l.704) + '1개'(cyan count l.705) + ' 소모됩니다.'(white l.706). Reconstructed full Korean = '확인하면 기회의 보석이 1개 소모됩니다.'. %s is the colored count token (=defeat.continue.gem_count_one). Runtime substitutes the count arg then color-highlights that substring; word order differs per locale so the count cannot stay mid-string for all languages. |
| `defeat.continue.gem_consumed` | 기회의 보석이 1개 소모되었습니다. | %s | %s Chance Gem was consumed. | 已消耗 %s 颗机会宝石。 | チャンスジェムを %s 個消費しました。 | Se consumió %s Gema de Oportunidad. |  | SEGMENTED 3-color message, shown when shatter window active or completed. Source segments: '기회의 보석이 '(white l.717) + '1개'(cyan count l.718) + ' 소모되었습니다.'(white l.719). Reconstructed full Korean = '기회의 보석이 1개 소모되었습니다.'. %s is the colored count token (=defeat.continue.gem_count_one). |
| `defeat.continue.gem_count_one` | 1개 |  | 1 | 1 | 1個 | 1 |  | The cyan-colored count token that fills %s in gem_consume_on_confirm and gem_consumed. Korean '1개' = '1 (item/counter)'. EN/ZH/ES render as bare '1' (the noun lives in the template); JA keeps the counter '1個'. This is the substring the segmented draw highlights in cyan (Color(0.43,0.78,1.0)). |
| `defeat.continue.gem_trembling` | 기회의 보석이 흔들립니다... |  | The Chance Gem trembles... | 机会宝石在颤动… | チャンスジェムが揺れています… | La Gema de Oportunidad tiembla... |  | Fallthrough status text during the shatter window (single non-segmented _draw_centered_text). Preserve the trailing ellipsis. ZH/JA use the locale ellipsis …; EN/ES keep '...'. |

### 9.7 Stage 6 Tetriser boss-skill HUD  (16)
> **배선:** All strings live in stage6_tetriser_boss_skill_hud_renderer.gd TOOLTIP_INFO (lines 22-39): four skill ids (stage6_tetro_drop / stage6_guard / stage6_wall / stage6_super), each with name/trigger/cooldown/description. These STATIC label dicts are consumed by BossSkillCardHudSpec.draw_skill_tooltip (call at lines 129-132) which receives the per-id sub-dict via _get_array_safe_dict(TOOLTIP_INFO.get(...)). The same `name` field is ALSO drawn as the active card label via skill.get("name") at lines 177/181 in _draw_card — but that `name` comes from the HUD context entry (context["stage6_boss_skill_hud_skills"]), NOT from TOOLTIP_INFO. Runtime fix: (1) replace the literal Korean in TOOLTIP_INFO with translate(key) per field using stage6.skill.<id>.{name,trigger,cooldown,description}; (2) CRITICAL — the card-label `name` drawn at L177/181 is sourced upstream in stage6_tetriser_state.get_hud_context()'s `stage6_boss_skill_hud_skills` builder, which likely hardcodes the same Korean name a second time; that builder must read the SAME stage6.skill.<id>.name key so card label and tooltip stay in sync (audit that second site for a duplicate Korean literal). No printf placeholders on this surface, so formatter_mapping is empty and there is no dynamic formatter.

_검증: All 16 Korean strings verified VERBATIM against TOOLTIP_INFO (L22-39): 4 skill ids x {name, trigger, cooldown, description}. No source string dropped, none invented. No printf placeholders anywhere — every value is a fixed label/sentence; numbers (5~10, 7~15, 30, 50/100, 50, 500) are baked into the localized text. Glossary grep of language_settings_data.gd corrections applied: (1) boss name 테트리서 = "Tetrisser" (EN/ES L2361/L3918), "特崔瑟" (ZH L2880), "テトリサー" (JA L3399) — proposal had wrong "Tetriser"/"特里瑟", fixed stage6.skill.super.name across EN/ZH/ES (JA was already correct). (2) Confirmed 게이지=_

| key | KO | ph | EN | ZH | JA | ES | T | note |
|---|---|---|---|---|---|---|:-:|---|
| `stage6.skill.tetro_drop.name` | 낙하 테트로 |  | Falling Tetro | 坠落方块 | 落下テトロ | Tetro descendente |  | Skill name. 테트로=Tetro (the tetromino block, not the boss); ZH 方块=block/tetromino for clarity. |
| `stage6.skill.tetro_drop.trigger` | 자동(5~10초) |  | Auto (5-10s) | 自动(5~10秒) | 自動(5~10秒) | Auto (5-10s) |  | 자동=Auto/自动/自動/Auto (glossary L2431/2950/3469/3988). Numbers 5~10 + unit kept. |
| `stage6.skill.tetro_drop.cooldown` | 게이지 30 |  | Gauge 30 | 能量30 | ゲージ30 | Energía 30 |  | Cooldown field holds a gauge cost. 게이지=Gauge/能量/ゲージ/Energía (glossary L2484/3003/3522/4041). Number 30 kept. |
| `stage6.skill.tetro_drop.description` | 테트로미노 블록이 조립되어 낙하·정착합니다. 공/대시/연막으로 파괴. |  | Tetromino blocks assemble, then fall and settle. Destroy them with the ball, dash, or smoke. | 俄罗斯方块组装后坠落并固定。可用球/冲刺/烟雾摧毁。 | テトロミノブロックが組み立てられて落下・着地します。ボール／ダッシュ／煙幕で破壊。 | Los bloques tetromino se ensamblan, caen y se asientan. Destrúyelos con la bola, el dash o el humo. |  | 공=ball, 대시=dash, 연막=smoke, 정착=settle. Tetromino is standard. |
| `stage6.skill.guard.name` | 가드 블록 |  | Guard Block | 守护方块 | ガードブロック | Bloque de guardia |  | 가드=Guard, 블록=Block. |
| `stage6.skill.guard.trigger` | 자동(7~15초) |  | Auto (7-15s) | 自动(7~15秒) | 自動(7~15秒) | Auto (7-15s) |  | 자동=Auto. Numbers 7~15 + unit kept. |
| `stage6.skill.guard.cooldown` | 게이지 50/100 |  | Gauge 50/100 | 能量50/100 | ゲージ50/100 | Energía 50/100 |  | Tiered gauge cost. 게이지=Gauge. Numbers kept verbatim with slash. |
| `stage6.skill.guard.description` | 보스 좌우에 4셀 가로 바를 전개해 상단을 방어합니다(최대 4개). |  | Deploys 4-cell horizontal bars on the boss's left and right to defend the top (up to 4). | 在首领左右展开4格横条防御上方(最多4个)。 | ボスの左右に4セルの横バーを展開して上部を防御します(最大4個)。 | Despliega barras horizontales de 4 celdas a izquierda y derecha del jefe para defender la parte superior (hasta 4). |  | 보스=Boss, 셀=cell, 최대 4개=up to 4. Numbers kept. |
| `stage6.skill.wall.name` | 테트로 벽 |  | Tetro Wall | 方块墙 | テトロウォール | Muro de tetro |  | 테트로=Tetro (block), 벽=Wall. ZH 方块墙=tetromino-block wall. |
| `stage6.skill.wall.trigger` | 자동(30초) |  | Auto (30s) | 自动(30秒) | 自動(30秒) | Auto (30s) |  | 자동=Auto. Number 30 + unit kept. |
| `stage6.skill.wall.cooldown` | 게이지 50 |  | Gauge 50 | 能量50 | ゲージ50 | Energía 50 |  | Gauge cost. 게이지=Gauge. Number 50 kept. |
| `stage6.skill.wall.description` | 좌우 가장자리에 테트로 벽을 쌓아 압박합니다(셀 단위 파괴). |  | Stacks tetro walls along the left and right edges to apply pressure (destroyed cell by cell). | 在左右边缘堆砌方块墙施加压力(逐格摧毁)。 | 左右の端にテトロの壁を積み上げて圧迫します(セル単位で破壊)。 | Apila muros de tetro en los bordes izquierdo y derecho para presionar (se destruyen celda por celda). |  | 가장자리=edge, 압박=pressure, 셀 단위=cell by cell. |
| `stage6.skill.super.name` | 초인테트리서 |  | Super Tetrisser | 超人特崔瑟 | 超人テトリサー | Super Tetrisser |  | FIXED: boss name 테트리서 must use established glossary romanization 'Tetrisser' (EN L2361/ES L3918), '特崔瑟' (ZH L2880), 'テトリサー' (JA L3399) — proposal had wrong 'Tetriser'/'特里瑟'. 초인=Super(human) (cf. JA 超人, ZH 超人). transliteration kept false: this is a skill name (containing the boss proper noun), not a standalone personal name. |
| `stage6.skill.super.trigger` | 게이지 500 |  | Gauge 500 | 能量500 | ゲージ500 | Energía 500 |  | Trigger threshold is a gauge amount. 게이지=Gauge. Number 500 kept. |
| `stage6.skill.super.cooldown` | 발동 중 드레인 |  | Drains while active | 发动中持续消耗 | 発動中ドレイン | Drena mientras está activo |  | 발동 중=while active (glossary standalone=Casting/发动中/発動中/Activando, L2471/2990/3509/4028); 드레인=drain (gauge drains during the super form). ZH/JA keep 发动中/発動中 prefix; natural verb 'drains' fits the phrase. No number. |
| `stage6.skill.super.description` | 초인 변신: 본체가 커지고 테트로가 거대·공 면역이 되며 큐브로 광선을 쏩니다. |  | Super transformation: the body grows larger, tetros become huge and immune to the ball, and cubes fire beams. | 超人变身:本体变大,方块变得巨大且免疫球,并用方块发射光线。 | 超人変身:本体が巨大化し、テトロが巨大化・ボール無効になり、キューブでビームを撃ちます。 | Transformación super: el cuerpo crece, los tetros se vuelven enormes e inmunes a la bola, y los cubos disparan rayos. |  | 변신=Transform/变身/変身/transformación (glossary L2505/3024/3543/4062), 면역=immune, 큐브=cube, 광선=beam, 본체=main body. |

### 9.8 Misc surfaces: perk overlay, weapon names, stage landing, horn strawberry, pickup, scroll button, char-info labels  (54)
> **배선:** Most of these surfaces render raw Korean with NO translate() wrapper, so wiring requires BOTH adding dotted keys to language_settings_data.gd AND wrapping call sites in LanguageSettings.translate_text(...) (apply % args AFTER translate for template entries). KEY-MISMATCH (spelling-alignment, NOT new keys): (1) stats_presenter.gd:64 passes "몸집 크기" but data key is "몸집크기" (no space) at 2559/3078/3597/4116; (2) stats_presenter.gd:68 passes "대시 후딜 시간" but data key is "대시 후딜시간" (no space) at 2487/3006/3525/4044. Pick ONE canonical spelling and make code+data agree (recommend removing the space in code to match existing data keys — zero data churn). WEAPON NAMES: an existing key family soldier_unlock_* already carries identical renderings (net_gun/fire_support/bowling_trap/suicide_drone/bazooka/ak47 at data 938-943/998-1003/1058-1063/1118-1123) and the per-locale Beretta string (944/1124/...). Prefer REUSING those existing renderings; if new weapon.name.* keys are added they MUST match them verbatim (done below). pistol & beretta have no display-name key yet (perk path renders Beretta-only) — beretta uses Latin "Beretta" across all locales per the existing convention. character_type_label() Korean (바이퍼/코만도/스매셔) is hardcoded in TWO places (character_info_overlay_formatter.gd:90-95 AND character_info_overlay_owner_state.gd:73-76) — both must be wrapped/keyed or one path leaks raw Korean. 소림사 stage4 subtitle: data key EXISTS (2358/2877/3396/3915); only wire stage_landing_intro to translate the subtitle (do NOT add a duplicate key). 광장으로 already calls translate_text — only the data key is missing. Already-localized (confirm spelling only, no action): 이동 속도, 게이지 획득량, 최대 게이지, 대시 거리, 액티브 아이템 슬롯, 미획득, 상태, 능력치, 캐릭터 정보, 다음 스테이지, 나가기, 획득한 퍽 없음, 탄약, 탄환, 호출권, 무제한, 재장전. Perk-overlay level tags _level_text()/_long_level_text() are dynamic formatters keyed off choice flags (is_gold_conversion/is_instant/unlock-badge) — see formatter_mapping; 500골드 is a literal inside the long template (no placeholder). The +%d acquired-overflow and Lv.%d fallthroughs are numeric-only (no key strictly required). AK-47 ammo text and commando status_text are already per-language-branched in code and need no key.

_검증: All KO strings verified VERBATIM against source. Fixes applied: (1) Beretta ZH/JA — existing data renders "Beretta" in Latin for ALL locales (data lines 944/1124/1184/2022 etc.), so changed proposed 贝瑞塔/ベレッタ to "Beretta" for glossary consistency. (2) net_gun ZH "网陷阱枪"→"网陷枪", JA "ネット罠ガン"→"ネットトラップガン", ES "Lanzarredes trampa"→"Pistola red trampa" to match existing soldier_unlock_net_gun (data 998/1058/1118). (3) bowling_trap ZH "保龄陷阱"→"保龄球陷阱" to match soldier_unlock_bowling_trap (data 1000). (4) suicide_drone ES kept "Dron suicida" (matches existing 1120). (5) bazooka/fire_support/suicide_drone J_

<details><summary>formatter code → key 매핑 (14)</summary>

- runtime_perk_overlay_renderer._level_text: is_gold_conversion=true -> perk.overlay.level_tag.gold (골드)
- runtime_perk_overlay_renderer._level_text: is_instant=true -> perk.overlay.level_tag.instant (즉시)
- runtime_perk_overlay_renderer._level_text: unlock-badge=true -> perk.overlay.level_tag.unlock (해금)
- runtime_perk_overlay_renderer._level_text: default -> 'Lv.%d' (no key, numeric)
- runtime_perk_overlay_renderer._long_level_text: is_gold_conversion=true -> perk.overlay.long_level.gold (  (500골드))
- runtime_perk_overlay_renderer._long_level_text: is_instant=true -> perk.overlay.long_level.instant (  (즉시 효과))
- runtime_perk_overlay_renderer._long_level_text: unlock-badge=true -> perk.overlay.long_level.unlock (  (액티브 해금))
- runtime_perk_overlay_renderer._long_level_text: default -> '  (Lv.%d → Lv.%d)' (no key, numeric)
- commando_weapon_controller.get_weapon_data badge: rental_weapons.has(id) -> weapon.badge.rental (대여)
- commando_weapon_controller.get_weapon_data badge: permanent_owned.has(id) -> weapon.badge.permanent (영구)
- commando_weapon_controller.get_weapon_data badge: id==BASE_WEAPON else '' -> weapon.badge.base (기본)
- weapon display_name_ko -> weapon.name.* by id: pistol->pistol, commando_pistol->beretta, net_gun->net_gun, fire_support->fire_support, bowling_trap->bowling_trap, suicide_drone->suicide_drone, bazooka->bazooka, ak47->ak47 (or REUSE existing soldier_unlock_* keys)
- active_item_pickup_feedback.ACTIVE_USE_HINT_FORMAT -> hud.pickup.active_use_hint (%d번 키로 사용)
- character_info_overlay_formatter.character_type_label: viper->charinfo.character_type.viper, soldier->charinfo.character_type.commando, default->charinfo.character_type.smasher
</details>

| key | KO | ph | EN | ZH | JA | ES | T | note |
|---|---|---|---|---|---|---|:-:|---|
| `perk.overlay.title` | 스킬 강화! |  | Skill Upgrade! | 技能强化！ | スキル強化！ | ¡Mejora de habilidad! |  | Perk-choice modal title. Rendered raw (used as TITLE_TEXT const) — wrap call site. |
| `perk.overlay.select_hint` | 마우스 클릭 또는 ← → / Enter 로 선택 |  | Click or use ← → / Enter to select | 鼠标点击或用 ← → / Enter 选择 | クリック または ← → / Enter で選択 | Haz clic o usa ← → / Enter para elegir |  | Selection hint when choices are selectable. Raw — wrap. |
| `perk.overlay.loading_choices` | 선택지를 불러오는 중 |  | Loading choices | 正在载入选项 | 選択肢を読み込み中 | Cargando opciones |  | Shown when choices not yet selectable. Raw — wrap. |
| `perk.overlay.extra_choices` | 추가 %d개 | %d | +%d more | 还有 %d 个 | あと %d 個 | +%d más |  | Pending extra perk choices (pending-1). %d preserved in all locales. |
| `perk.overlay.swap_dialog_title` | 화기 슬롯 교체 |  | Swap Firearm Slot | 更换火器槽 | 火器スロット交換 | Cambiar ranura de arma |  | Unlock-swap dialog title for commando firearms. Raw — wrap. |
| `perk.overlay.swap_new_weapon` | 새 화기: %s | %s | New firearm: %s | 新火器：%s | 新しい火器：%s | Arma nueva: %s |  | %s is the new weapon display name (localize via weapon.name.* before substitution). %s preserved all locales. |
| `perk.overlay.swap_confirm_hint` | Enter 선택 / Esc 취소 |  | Enter to confirm / Esc to cancel | Enter 确认 / Esc 取消 | Enter で決定 / Esc でキャンセル | Enter para confirmar / Esc para cancelar |  | Swap dialog confirm/cancel hint. Raw — wrap. |
| `perk.overlay.current_perks_header` | ◆ 현재 퍽 |  | ◆ Current Perks | ◆ 当前升级 | ◆ 現在のパーク | ◆ Perks actuales |  | Status panel header. ◆ is decorative — keep literal. 퍽 rendered Perks/升级/パーク/Perks per existing perk-related data usage. Raw — wrap (the diamond can be re-prepended or kept inside the key). |
| `perk.overlay.pending_count` | 선택 대기: %d | %d | Choices Waiting: %d | 待选择: %d | 選択待ち: %d | Opciones en espera: %d |  | Status panel pending-choices line. Raw — wrap. %d preserved. |
| `perk.overlay.perk_gold` | 퍽 골드: %d | %d | Perk Gold: %d | 升级金币: %d | パークゴールド: %d | Oro de perk: %d |  | Status panel perk-gold line. Gold/金币/ゴールド/Oro per glossary. Raw — wrap. %d preserved. |
| `perk.overlay.acquired_overflow` | +%d | %d | +%d | +%d | +%d | +%d |  | Overflow count when acquired perks exceed icon row. Purely numeric — no translation needed; key optional, kept for completeness. |
| `perk.overlay.level_tag.gold` | 골드 |  | Gold | 金币 | ゴールド | Oro |  | Short card level tag for gold-conversion perk choices. Dynamic formatter — see formatter_mapping. |
| `perk.overlay.level_tag.instant` | 즉시 |  | Instant | 立即 | 即時 | Instantáneo |  | Short card level tag for instant-effect perk choices. |
| `perk.overlay.level_tag.unlock` | 해금 |  | Unlock | 解锁 | 解放 | Desbloqueo |  | Short card level tag for character-unlock perk choices. |
| `perk.overlay.long_level.gold` |   (500골드) |  |   (500 Gold) |   (500 金币) |   (500 ゴールド) |   (500 de oro) |  | Long level text for gold-conversion choice. Leading 2 spaces are layout padding — preserve. 500 is literal (not a placeholder). Gold/金币/ゴールド/Oro per glossary. |
| `perk.overlay.long_level.instant` |   (즉시 효과) |  |   (Instant Effect) |   (立即生效) |   (即時効果) |   (Efecto instantáneo) |  | Long level text for instant-effect choice. Preserve leading 2 spaces. |
| `perk.overlay.long_level.unlock` |   (액티브 해금) |  |   (Active Unlock) |   (解锁主动技能) |   (アクティブ解放) |   (Desbloqueo activo) |  | Long level text for active-skill unlock choice. 액티브=Active per glossary. Preserve leading 2 spaces. |
| `weapon.name.pistol` | 권총 |  | Pistol | 手枪 | 拳銃 | Pistola |  | Base commando weapon. No existing display-name key — new. Also drawn as selector panel title. |
| `weapon.name.beretta` | 베레타 |  | Beretta | Beretta | Beretta | Beretta | ✓ | GLOSSARY FIX: existing data renders Beretta as Latin 'Beretta' for ALL locales (soldier_unlock_beretta 944/1124/1184; commando_pistol korean field 2022 etc.) — changed proposed ZH 贝瑞塔/JA ベレッタ to 'Beretta' for consistency. id is commando_pistol but display name is 베레타. Brand proper noun. |
| `weapon.name.net_gun` | 그물덫총 |  | Net Trap Gun | 网陷枪 | ネットトラップガン | Pistola red trampa |  | GLOSSARY FIX to match existing soldier_unlock_net_gun (EN 938 / ZH 998 网陷枪 / JA 1058 ネットトラップガン / ES 1118 Pistola red trampa). Prefer reusing soldier_unlock_net_gun rendering. |
| `weapon.name.fire_support` | 화력지원 |  | Fire Support | 火力支援 | 火力支援 | Apoyo de fuego |  | Matches existing soldier_unlock_fire_support (939/999/1059/1119). Airstrike call-in weapon. |
| `weapon.name.bowling_trap` | 볼링트랩 |  | Bowling Trap | 保龄球陷阱 | ボウリングトラップ | Trampa de bolos |  | GLOSSARY FIX: ZH 保龄陷阱→保龄球陷阱 to match existing soldier_unlock_bowling_trap (940/1000/1060/1120). |
| `weapon.name.suicide_drone` | 자폭드론 |  | Suicide Drone | 自爆无人机 | 自爆ドローン | Dron suicida |  | Matches existing soldier_unlock_suicide_drone (941/1001/1061/1121). |
| `weapon.name.bazooka` | 바주카포 |  | Bazooka | 火箭筒 | バズーカ | Bazuca |  | Matches existing soldier_unlock_bazooka (942/1002/1062/1122). |
| `weapon.name.ak47` | AK-47 |  | AK-47 | AK-47 | AK-47 | AK-47 | ✓ | Firearm model — identical all locales (matches soldier_unlock_ak47 943/1003/1063/1123). |
| `weapon.badge.rental` | 대여 |  | Rental | 租借 | レンタル | Alquiler |  | Rental badge. Appears as data badge in controller AND as raw draw_string in selector renderer:270 — both must localize. |
| `weapon.badge.permanent` | 영구 |  | Permanent | 永久 | 永続 | Permanente |  | Permanent-ownership badge (permanent_owned branch). |
| `weapon.badge.base` | 기본 |  | Base | 基础 | 基本 | Base |  | Base-weapon badge (pistol / BASE_WEAPON only). |
| `stage.landing.subtitle.stage1` | 조선 골목 |  | Joseon Alley | 朝鲜小巷 | 朝鮮の路地 | Callejón de Joseon | ✓ | Stage 1 landing subtitle. 조선/Joseon dynasty proper noun (transliterate); 골목=alley natural. Raw — wrap call site. |
| `stage.landing.subtitle.stage2` | 정글 지진 |  | Jungle Quake | 丛林地震 | ジャングル地震 | Terremoto en la jungla |  | 정글=jungle, 지진=earthquake/quake. Raw — wrap. |
| `stage.landing.subtitle.stage3` | 멘헤라 인형극장 |  | Menhera Puppet Theater | 病娇玩偶剧场 | メンヘラ人形劇場 | Teatro de marionetas Menhera | ✓ | 멘헤라/Menhera borrowed JP-origin term — transliterate EN/ES, native メンヘラ JA, 病娇 ZH. 인형극장=puppet theater. Raw — wrap. |
| `stage.landing.subtitle.stage4` | 소림사 |  | Shaolin Temple | 少林寺 | 少林寺 | Templo Shaolin |  | ALREADY LOCALIZED: 소림사 key exists in language_settings_data.gd (2358/2877/3396/3915). Code does NOT wrap subtitle — wire the call site to the existing key; do NOT add a duplicate. Renderings here copy existing entries. |
| `item.horn_strawberry.skill.horn_charge.name` | 뿔박치기 |  | Horn Charge | 顶角冲撞 | 角突進 | Embestida de cuerno |  | 뿔=horn, 박치기=headbutt/charge. |
| `item.horn_strawberry.skill.horn_charge.desc` | 앞으로 돌진해 보스를 기절시키고 강하게 밀쳐냅니다. |  | Charges forward to stun the boss and knock it back hard. | 向前冲撞，使首领眩晕并将其猛烈击退。 | 前方に突進してボスを気絶させ、強くノックバックさせます。 | Embiste hacia adelante para aturdir al jefe y empujarlo con fuerza. |  | Boss=Boss per glossary. |
| `item.horn_strawberry.skill.field.name` | 딸기장판 |  | Strawberry Mat | 草莓地垫 | イチゴマット | Alfombra de fresa |  | 딸기=strawberry, 장판=floor mat/deployed barrier. |
| `item.horn_strawberry.skill.field.desc` | 딸기 장막을 깔아 내려오는 공을 한 번 튕겨냅니다. |  | Lays a strawberry curtain that bounces a falling ball once. | 铺开一道草莓帘幕，将下落的球弹回一次。 | イチゴの幕を敷き、落ちてくるボールを一度跳ね返します。 | Despliega una cortina de fresa que rebota una vez la bola que cae. |  |  |
| `item.horn_strawberry.skill.eat.name` | 딸기먹기 |  | Eat Strawberry | 吃草莓 | イチゴを食べる | Comer fresa |  | 딸기=strawberry, 먹기=eating. |
| `item.horn_strawberry.skill.eat.desc` | 딸기를 먹어 패들을 키우고 꼭지를 세 갈래로 발사합니다. |  | Eats a strawberry to enlarge the paddle and fires its stem in three directions. | 吃下草莓使球拍变大，并将草莓蒂朝三个方向发射。 | イチゴを食べてパドルを大きくし、ヘタを三方向に発射します。 | Come una fresa para agrandar la pala y dispara el tallo en tres direcciones. |  | 패들=paddle, 꼭지=stem/cap, 세 갈래=three directions. |
| `item.horn_strawberry.skill.bomb.name` | 딸기폭탄 |  | Strawberry Bomb | 草莓炸弹 | イチゴ爆弾 | Bomba de fresa |  | 딸기=strawberry, 폭탄=bomb. |
| `item.horn_strawberry.skill.bomb.desc` | 폭탄 30개를 흩뿌리고 페인트 안의 보스를 느리게 합니다. |  | Scatters 30 bombs and slows the boss inside the paint zone. | 撒出30颗炸弹，并使禁区内的首领减速。 | 爆弾を30個ばらまき、ペイント内のボスを遅くします。 | Esparce 30 bombas y ralentiza al jefe dentro de la zona pintada. |  | 30 is a literal count (not a placeholder). 페인트=painted/key zone near the boss. Boss=Boss per glossary. |
| `hud.pickup.active_use_hint` | %d번 키로 사용 | %d | Use with key %d | 按 %d 键使用 | %d キーで使用 | Usar con la tecla %d |  | %d is the active-item slot number (slot_index+1). %d preserved all locales. |
| `hud.scroll_button.to_plaza` | 광장으로 |  | To Plaza | 前往广场 | 広場へ | Ir a la plaza |  | Stage-clear result scroll button. 광장=Plaza per glossary. ALREADY wrapped in translate_text() at call site — only the data key is missing; add it. |
| `charinfo.stat.body_size` | 몸집 크기 |  | Body Size | 体型 | 体サイズ | Tamaño corporal |  | KEY-MISMATCH FIX: existing EXACT_TEXT key is '몸집크기' (NO space) at data 2559/3078/3597/4116, but code passes '몸집 크기' (WITH space) so translate_text silently misses → KO fallback. Align spelling (recommend removing the space in code). EN/ZH/JA/ES copied verbatim from existing entries. |
| `charinfo.stat.dash_recovery_time` | 대시 후딜 시간 |  | Dash Recovery | 冲刺后摇 | ダッシュ後隙時間 | Recuperación del dash |  | KEY-MISMATCH FIX: existing key is '대시 후딜시간' (NO space in 후딜시간) at data 2487/3006/3525/4044, but code passes '대시 후딜 시간' (WITH space). Align spelling. Renderings copied verbatim from existing entries. |
| `charinfo.stat.dash_recharge` | 대시 재충전 |  | Dash Recharge | 冲刺充能 | ダッシュ再充填 | Recarga del dash |  | NEW key — no existing entry. Matches sibling 'Dash ...' style (대시 거리/대시 후딜시간 exist). delta_stat_row wraps label in translate_text. |
| `charinfo.stat.item_recharge` | 아이템 재충전 |  | Item Recharge | 道具充能 | アイテム再充填 | Recarga de objeto |  | NEW key. Active-item cooldown recharge stat row. |
| `charinfo.stat.none_to_show` | 표시할 능력치 없음 |  | No stats to show | 无可显示的属性 | 表示する能力値なし | No hay estadísticas que mostrar |  | NEW key. Empty-state for player stat rows. Drawn RAW via _draw_text_centered_xy (no translate_text) — wrap call site. 능력치=Stats per glossary. |
| `charinfo.section.player_stats` | 플레이어 능력치 |  | Player Stats | 玩家属性 | プレイヤー能力値 | Estadísticas del jugador |  | NEW key. Section title passed RAW to draw_cached_player_stat_rows (drawn without translate_text:118) — wrap. 능력치 base maps Stats/属性/能力値/Estadísticas. |
| `charinfo.section.lingpet_stats` | 링펫 능력치 |  | Lingpet Stats | 灵宠属性 | リンペット能力値 | Estadísticas del Lingpet |  | NEW key. Section title passed RAW to draw_lingpet_stat_rows — wrap. 링펫=Lingpet per glossary (ZH 灵宠 / JA リンペット per existing usage). |
| `charinfo.lingpet.state.egg` | 알 |  | Egg | 蛋 | 卵 | Huevo |  | NEW key. Lingpet egg-state value (paired with 상태=Status row). make_display_stat_row:935 wraps value in translate_text — translates automatically once key exists. 상태 already exists. |
| `charinfo.lingpet.hatch_progress` | 부화 진행 |  | Hatch Progress | 孵化进度 | 孵化進行 | Progreso de eclosión |  | NEW key. Egg hatch-progress stat label; value is an int pair (e.g. 1/3) via format_int_pair separately. make_display_stat_row wraps label. |
| `charinfo.character_type.viper` | 바이퍼 |  | Viper | 维珀 | ヴァイパー | Viper | ✓ | Composed-subtitle character-type label, currently NOT translated (raw KO). Personal/character name — transliterate. Subtitle = display_name + '  /  ' + this label. Both formatter:92 AND owner_state:73 must localize. |
| `charinfo.character_type.commando` | 코만도 |  | Commando | 突击兵 | コマンド | Comando | ✓ | Character-type label (soldier id, display 코만도). Transliterate Commando; ZH 突击兵 natural. Currently untranslated in composed subtitle. |
| `charinfo.character_type.smasher` | 스매셔 |  | Smasher | 重击手 | スマッシャー | Smasher | ✓ | Character-type label (default/smasher). Transliterate. Currently untranslated in composed subtitle. |



## 10. 범위 외 / 후속

- PT-BR/RU 완전 현지화(현재 영어 fallback). 추후 필요 시 override 테이블로 승격.
- 음역 표기 최종 확정은 §9 표 리뷰에서(특히 건물 유형어의 영문 의미어 vs 음역 선택).
- 디버그 메뉴(F2/F3 등 `*debug*`)는 의도적 dev-only로 번역 대상 아님.
- 본 문서의 키/번역은 적대 검증을 거쳤으나, 라이브 픽셀 QA에서 길이 오버플로(버튼/스탯 박스 폭)
  발견 시 해당 EN/ZH 문자열을 단축 조정.
