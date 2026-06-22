# Untranslated Surface I18n Formatter Mapping

Generated 2026-06-21 from workflow `wf_9cfa6be0-e24`. Each surface uses the latest verified result when available.

## Defeat chance-gems continue screen

- Verified: `true`
- Entries: `9`
- Formatter mappings: `6`
- Verify notes: Read the real source (defeat_chance_gems_continue_screen.gd) at lines 316, 317, 344-347, 354, and the segmented status block 697-725. All 9 Korean strings are quoted VERBATIM and match source byte-for-byte, including both \n line breaks in the two guide blocks and the trailing ellipsis '...' on 흔들립니다. Confirmed the two segmented messages are each three separately-colored draw_string segments via _draw_centered_text_segments (white surround + cyan '1개' count + white tail); reconstructed full Korean is accurate. Placeholders: only the two segmented full-message templates carry %s (one each, same position-agnostic count token) and EN/ZH/JA/ES each contain exactly one %s — no mismatch. Glossary cross-checked in language_settings_data.gd: 패배->Defeat (cf. 'Defeat Prevention' l.2494/3013/3532/4051), 확인->Confirmar ES (l.4213). '기회의 보석'/'Chance Gem' has NO prior rendering anywhere in the file (new surface), so authoring a fresh term is correct, not a divergence. No personal names on this surface, so transliteration=false throughout is correct. Dotted keys are lowercase, stable, collision-free under defeat.continue.*. Completeness: every player-facing source string is present (title, subtitle, 2 branch guides, confirm button, 2 segmented status messages, the standalone cyan count token, trembling fallthrough). No corrections were required; proposed table accepted as-is.
- Wiring note: All strings are static labels except: (1) the two multiline guide blocks (l.344 default vs l.347 last-chance) selected by runtime branch `visual_remaining <= 0`; (2) the three mutually-exclusive status messages inside `_draw_continue_status_text`, selected by `_phase == PRESENT` (l.704-706) / `_is_shatter_window_active() or _has_shatter_completed()` (l.717-719) / else fallthrough (l.725). SEGMENTED-COLOR: the l.704-706 and l.717-719 messages are drawn as THREE separately-colored segments (white surround + cyan '1개' count + white tail) via `_draw_centered_text_segments`. Because word order differs per locale, the count segment cannot stay mid-string for all languages. Recommended runtime: keep ONE template key per full message with a `%s` for the colored count, render translate(key) % [count], then color-highlight the substring matching the count argument (or split the localized string on the count token). The standalone count token '1개' is given its own key (defeat.continue.gem_count_one) so the runtime can color-match/substitute the highlighted substring. Multiline guides preserve the literal \n and must render with `_draw_multiline_centered_text` per-line centering (splits on \n). EN/ZH/JA/ES authored; PT-BR/RU fall back to EN.

```text
status_present (l.699-711, _phase == PRESENT) -> defeat.continue.gem_consume_on_confirm
status_shatter_done (l.712-723, _is_shatter_window_active() or _has_shatter_completed()) -> defeat.continue.gem_consumed
status_shatter_idle (l.725, fallthrough) -> defeat.continue.gem_trembling
guide_default (l.344, visual_remaining > 0) -> defeat.continue.guide_default
guide_last_chance (l.347, visual_remaining <= 0) -> defeat.continue.guide_last_chance
colored_count_token (l.705, l.718 cyan '1개') -> defeat.continue.gem_count_one
```

## Defeat settlement screen

- Verified: `true`
- Entries: `24`
- Formatter mappings: `13`
- Verify notes: Re-read defeat_settlement_screen.gd in full; all 24 Korean strings quoted verbatim against source line numbers (no drift, none dropped, none invented). Cross-checked language_settings_data.gd by grep for every reused term. FIXED 4 issues: (1) perk_level_entry ZH '등급/等级%d' -> 'Lv.%d' to match the project's universal 'Lv.%d' convention (lang 2638 羁绊 Lv.%d); (2) perk_level_entry ES 'Nv.%d' -> 'Lv.%d' (lang 773 ES uses Lv.5); (3) 퍽 section EN 'Perks' -> 'Perk' to match existing EXACT_TEXT singular 'Perk' (lang 2262); (4) 퍽 section ES 'Perks' -> 'Perk' (lang 3819). Verified placeholder parity: gold_breakdown carries exactly two %dG in [plaza, runtime] order in all four locales; perk_level_entry carries %s then %d; single-%d entries consistent. Confirmed which strings already have EXACT_TEXT renderings (획득 골드, 최종 스코어, 액티브, 패시브, 퍽, 없음, 멘헤라걸, 달지, 악어장군, 홍련, 테트리서) and which are genuinely NEW (도전 종료, subtitle, 도달 보스, 아이템 [EN/ZH/JA/ES], 클리어한 보스, gold_breakdown, 메인 메뉴로, 알 수 없음, 스테이지 %d, 스테이지 %d 보스, 폰크). Confirmed 폰크 and 알 수 없음 have no existing rendering. Confirmed the stat-box VALUE '%d : %d' is non-translatable and correctly not keyed. Perk and item display names correctly routed to existing PERK_NAME_*/item-name maps, not new keys.
- Wiring note: Source: godot/scripts/core/defeat_settlement_screen.gd (verbatim re-read). Player-facing Korean strings: draw() lines 83-114 (도전 종료 83, 이번 링피아 여정의 기록입니다 84, 획득 골드 91, 최종 스코어 92, 도달 보스 93, 아이템 98, 액티브 99, 패시브 100, 퍽 102, 클리어한 보스 107, gold-breakdown footer 108, 메인 메뉴로 114), STAGE_BOSS_NAMES 11-16, and helper formatters (_build_stage_snapshot reached_stage_label 161, _get_stage_boss_name fallback 265, _format_labels 없음 335 / +%d 341, _build_perk_labels '%s Lv.%d' 250, stat-box current_boss fallback '알 수 없음' 93).\n\nPERK NAMES — DO NOT add new keys: _get_perk_name() (line 254) pulls the display name from RuntimePerkCatalog.get_perk_data().name (Korean perk name by perk_id). Localize through the EXISTING PERK_NAME_EN/ZH/JA/ES maps keyed by perk_id, NOT by new defeat.* keys. The screen formats '%s Lv.%d' (line 250); the Lv. template is captured as defeat.settlement.perk_level_entry, but the %s token MUST come from the perk-name map.\n\nITEM NAMES are also dynamic (ActiveItemCatalog.get_display_name line 222 / MythicItemCatalog.get_display_name line 224, or the item dict display_name at line 215) — localize via the existing item-name maps, NOT new keys.\n\nBOSS NAMES: every STAGE_BOSS_NAMES value already exists in EXACT_TEXT_* EXCEPT 폰크 (Ponk), which has NO existing rendering anywhere (new defeat.boss.ponk added). Route boss-name localization through the existing EXACT_TEXT_* exact-match path (covers 5 of 6) and only fall back to defeat.boss.ponk for 폰크. The defeat.boss.* mirrors carry identical text so 달지/홍련 etc. cannot drift; keep ONE source of truth.\n\nGLOSSARY REUSE (verified by grep of language_settings_data.gd): 획득 골드=Gold Acquired/获得金币/獲得ゴールド/Oro obtenido; 최종 스코어=Final Score/最终比分/最終スコア/Puntuación final; 액티브=Active/主动/アクティブ/Activo; 패시브=Passive/被动/パッシブ/Pasivo; 퍽=Perk/升级/パーク/Perk; 없음=None/无/なし/Ninguno; 멘헤라걸=Menhera Girl/病娇少女/メンヘラガール/Chica Menhera. Authored EN/ZH/JA/ES for those keys match the existing exact-match values verbatim. Bare '아이템' has only PT_BR/RU renderings, so EN/ZH/JA/ES are newly authored (Items/道具/アイテム/Objetos), aligned to the established item-word convention.\n\nLv. CONVENTION (verified): the project keeps 'Lv.%d' literally in ALL locales — '교감 Lv.%d' -> ZH '羁绊 Lv.%d' (line 2638), ES uses 'Lv.5' (line 773). The proposal's ZH '等级%d' and ES 'Nv.%d' were drift and are corrected to 'Lv.%d'.\n\nPLACEHOLDERS: '%dG' = integer + literal G; footer (line 108) uses two %dG in order [plaza, runtime] — both kept literal-G in source order. reached_stage_label (161), stage_n_boss fallback (265), list_overflow_more (341) use one %d. perk_level_entry uses %s then %d. All locales preserve identical placeholder count and order.\n\nNOTE: 최종 스코어's VALUE is '%d : %d' (player : boss, line 92) — that value is a non-translatable numeric format, so no key was authored for it; only the label is keyed.

```text
STAGE_BOSS_NAMES[1]=달지 -> REUSE existing EXACT_TEXT '달지' (Dalji); defeat.boss.dalji is the same-text mirror
STAGE_BOSS_NAMES[2]=악어장군 -> REUSE existing EXACT_TEXT '악어장군' (Alligator General); defeat.boss.alligator_general mirror
STAGE_BOSS_NAMES[3]=멘헤라걸 -> REUSE existing EXACT_TEXT '멘헤라걸' (Menhera Girl); defeat.boss.menhera_girl mirror
STAGE_BOSS_NAMES[4]=폰크 -> defeat.boss.ponk (NEW — no existing rendering anywhere)
STAGE_BOSS_NAMES[5]=홍련 -> REUSE existing EXACT_TEXT '홍련' (Hongryun); defeat.boss.hongryun mirror
STAGE_BOSS_NAMES[6]=테트리서 -> REUSE existing EXACT_TEXT '테트리서' (Tetrisser); defeat.boss.tetrisser mirror
_get_stage_boss_name(stage_id) fallback (stage_id not in STAGE_BOSS_NAMES) -> defeat.boss.stage_n_boss (template '스테이지 %d 보스')
current_boss stat fallback (stage.get('current_boss', '알 수 없음')) -> defeat.settlement.boss_unknown
_build_perk_labels '%s Lv.%d' (line 250): %s token -> EXISTING PERK_NAME_* map by perk_id (NOT a new key); template -> defeat.settlement.perk_level_entry
_format_item_label active item display_name -> EXISTING ActiveItemCatalog.get_display_name / item-name maps (NOT a new key)
_format_item_label passive/mythic item display_name -> EXISTING MythicItemCatalog.get_display_name / item-name maps (NOT a new key)
_format_labels empty list -> defeat.settlement.list_empty ('없음', REUSE existing)
_format_labels overflow -> defeat.settlement.list_overflow_more ('+%d')
```

## Misc surfaces: perk overlay, weapon names, stage landing, horn strawberry, pickup, scroll button, char-info labels

- Verified: `true`
- Entries: `54`
- Formatter mappings: `14`
- Verify notes: All KO strings verified VERBATIM against source. Fixes applied: (1) Beretta ZH/JA — existing data renders "Beretta" in Latin for ALL locales (data lines 944/1124/1184/2022 etc.), so changed proposed 贝瑞塔/ベレッタ to "Beretta" for glossary consistency. (2) net_gun ZH "网陷阱枪"→"网陷枪", JA "ネット罠ガン"→"ネットトラップガン", ES "Lanzarredes trampa"→"Pistola red trampa" to match existing soldier_unlock_net_gun (data 998/1058/1118). (3) bowling_trap ZH "保龄陷阱"→"保龄球陷阱" to match soldier_unlock_bowling_trap (data 1000). (4) suicide_drone ES kept "Dron suicida" (matches existing 1120). (5) bazooka/fire_support/suicide_drone JA/ZH/ES confirmed matching existing soldier_unlock_* renderings. KEY-MISMATCH confirmed precisely: data key is "몸집크기" (NO space, lines 2559/3078/3597/4116) but stats_presenter.gd:64 passes "몸집 크기" (WITH space); data key is "대시 후딜시간" (NO space 후딜시간, lines 2487/3006/3525/4044) but code line 68 passes "대시 후딜 시간" (WITH space). Both silently miss translate_text. Wiring confirmations: 광장으로 already wrapped in translate_text (scroll helper:127) but NO data key exists — must add. ◆ 현재 퍽 / 선택 대기 / 퍽 골드 / select hints / loading / swap dialog / level tags / horn skills / weapon names / 표시할 능력치 없음 / 플레이어·링펫 능력치 section titles / character_type_label (바이퍼/코만도/스매셔, duplicated in formatter:90-95 AND owner_state:73-76) are all rendered RAW without translate_text. make_display_stat_row (lingpet_presenter:933) DOES wrap label+value, so 알/부화 진행 translate once keys exist (상태 already exists). 소림사 already has data key (2358/2877/3396/3915) but subtitle not wrapped — wire call site. 대시 거리/이동 속도 exist and match proposed sibling renderings. AK-47 identical all locales.
- Wiring note: Most of these surfaces render raw Korean with NO translate() wrapper, so wiring requires BOTH adding dotted keys to language_settings_data.gd AND wrapping call sites in LanguageSettings.translate_text(...) (apply % args AFTER translate for template entries). KEY-MISMATCH (spelling-alignment, NOT new keys): (1) stats_presenter.gd:64 passes "몸집 크기" but data key is "몸집크기" (no space) at 2559/3078/3597/4116; (2) stats_presenter.gd:68 passes "대시 후딜 시간" but data key is "대시 후딜시간" (no space) at 2487/3006/3525/4044. Pick ONE canonical spelling and make code+data agree (recommend removing the space in code to match existing data keys — zero data churn). WEAPON NAMES: an existing key family soldier_unlock_* already carries identical renderings (net_gun/fire_support/bowling_trap/suicide_drone/bazooka/ak47 at data 938-943/998-1003/1058-1063/1118-1123) and the per-locale Beretta string (944/1124/...). Prefer REUSING those existing renderings; if new weapon.name.* keys are added they MUST match them verbatim (done below). pistol & beretta have no display-name key yet (perk path renders Beretta-only) — beretta uses Latin "Beretta" across all locales per the existing convention. character_type_label() Korean (바이퍼/코만도/스매셔) is hardcoded in TWO places (character_info_overlay_formatter.gd:90-95 AND character_info_overlay_owner_state.gd:73-76) — both must be wrapped/keyed or one path leaks raw Korean. 소림사 stage4 subtitle: data key EXISTS (2358/2877/3396/3915); only wire stage_landing_intro to translate the subtitle (do NOT add a duplicate key). 광장으로 already calls translate_text — only the data key is missing. Already-localized (confirm spelling only, no action): 이동 속도, 게이지 획득량, 최대 게이지, 대시 거리, 액티브 아이템 슬롯, 미획득, 상태, 능력치, 캐릭터 정보, 다음 스테이지, 나가기, 획득한 퍽 없음, 탄약, 탄환, 호출권, 무제한, 재장전. Perk-overlay level tags _level_text()/_long_level_text() are dynamic formatters keyed off choice flags (is_gold_conversion/is_instant/unlock-badge) — see formatter_mapping; 500골드 is a literal inside the long template (no placeholder). The +%d acquired-overflow and Lv.%d fallthroughs are numeric-only (no key strictly required). AK-47 ammo text and commando status_text are already per-language-branched in code and need no key.

```text
runtime_perk_overlay_renderer._level_text: is_gold_conversion=true -> perk.overlay.level_tag.gold (골드)
runtime_perk_overlay_renderer._level_text: is_instant=true -> perk.overlay.level_tag.instant (즉시)
runtime_perk_overlay_renderer._level_text: unlock-badge=true -> perk.overlay.level_tag.unlock (해금)
runtime_perk_overlay_renderer._level_text: default -> 'Lv.%d' (no key, numeric)
runtime_perk_overlay_renderer._long_level_text: is_gold_conversion=true -> perk.overlay.long_level.gold (  (500골드))
runtime_perk_overlay_renderer._long_level_text: is_instant=true -> perk.overlay.long_level.instant (  (즉시 효과))
runtime_perk_overlay_renderer._long_level_text: unlock-badge=true -> perk.overlay.long_level.unlock (  (액티브 해금))
runtime_perk_overlay_renderer._long_level_text: default -> '  (Lv.%d → Lv.%d)' (no key, numeric)
commando_weapon_controller.get_weapon_data badge: rental_weapons.has(id) -> weapon.badge.rental (대여)
commando_weapon_controller.get_weapon_data badge: permanent_owned.has(id) -> weapon.badge.permanent (영구)
commando_weapon_controller.get_weapon_data badge: id==BASE_WEAPON else '' -> weapon.badge.base (기본)
weapon display_name_ko -> weapon.name.* by id: pistol->pistol, commando_pistol->beretta, net_gun->net_gun, fire_support->fire_support, bowling_trap->bowling_trap, suicide_drone->suicide_drone, bazooka->bazooka, ak47->ak47 (or REUSE existing soldier_unlock_* keys)
active_item_pickup_feedback.ACTIVE_USE_HINT_FORMAT -> hud.pickup.active_use_hint (%d번 키로 사용)
character_info_overlay_formatter.character_type_label: viper->charinfo.character_type.viper, soldier->charinfo.character_type.commando, default->charinfo.character_type.smasher
```

## Plaza dynamic messages: bank + shop + gacha

- Verified: `true`
- Entries: `28`
- Formatter mappings: `29`
- Verify notes: Re-read plaza_scene.gd _format_bank_transaction_message (2693-2714), _format_shop_transaction_message (2717-2745), _format_gacha_transaction_message (2748-2767). Every Korean string in the proposed table matches source VERBATIM. All reason branches (no_ap, no_plaza_gold, no_bank_deposit, interest_already_claimed, _; no_ap, not_enough_gold, active_slots_full, no_active_item, no_passive_item, inventory_full, missing_item_runtime/missing_owner, _; no_ap, not_enough_gold, active_slots_full, missing_item_runtime/missing_owner, empty_gacha_pool, _) and action branches (deposit, withdraw, interest; purchase, sale; gacha single tail) covered. Confirmed bank uses 열쇠(Key)=no_ap text but no_plaza_gold checks 골드; bank action 'deposit' reads delta_deposit while 'withdraw' reads delta_gold and 'interest' reads interest_gold — wiring_note arg order is correct. shop.purchase reads delta_gold, shop.sale reads sell_price, gacha.draw reads delta_gold. display_name empties to '아이템' fallback in BOTH shop and gacha (confirmed lines 2720-2721 and 2751-2752). Placeholder counts/order match Korean templates across EN/ZH/JA/ES in every dynamic entry (%d in deposit/withdraw/interest; %s+%d in purchase/sale/draw). No source string missing; no extra/drifted string. Glossary terms (Key/Gold/Active/Passive/Inventory/Stage/Interest/Deposit/Withdraw/Gacha draw) applied consistently. No personal names in this surface, so transliteration=false for all.
- Wiring note: Three formatters in godot/scripts/plaza/plaza_scene.gd (lines 2693-2767) return finished Korean sentences keyed on summary.reason (when changed==false) and summary.action (when changed==true). Replace each return with translate(key) % [args]. Argument order: bank.deposit -> [delta_deposit:int]; bank.withdraw -> [delta_gold:int]; bank.interest -> [interest_gold:int]; shop.purchase -> [display_name:str, delta_gold:int]; shop.sale -> [display_name:str, sell_price:int]; gacha.draw -> [display_name:str, delta_gold:int]. Static (no-arg) keys use plain translate(key). The display_name arg is a localized item name passed as %s. The %dG unit keeps the literal 'G' currency suffix in every locale (matches existing G shorthand); shop.sale and gacha success keep the +/no-sign as authored. The Korean object particle 을(를) carries no info — drop it in EN/ZH/JA/ES. display_name falls back to '아이템' (plaza.msg.shop.fallback_item) when empty in BOTH shop (line 2721) and gacha (line 2752). NOTE: this surface covers ONLY bank/shop/gacha; the lingpet-store formatter (_format_lingpet_store_transaction_message, line 2770+) is a SEPARATE surface — its no_ap there actually reads '행동력이 부족합니다.' (AP, not Key) and must not be confused with the gacha/shop no_ap keys here.

```text
BANK: changed==false reason 'no_ap' -> plaza.msg.bank.no_ap
BANK: reason 'no_plaza_gold' -> plaza.msg.bank.no_plaza_gold
BANK: reason 'no_bank_deposit' -> plaza.msg.bank.no_bank_deposit
BANK: reason 'interest_already_claimed' -> plaza.msg.bank.interest_already_claimed
BANK: reason default (_) -> plaza.msg.bank.default_blocked
BANK: changed==true action 'deposit' -> plaza.msg.bank.deposit
BANK: action 'withdraw' -> plaza.msg.bank.withdraw
BANK: action 'interest' -> plaza.msg.bank.interest
BANK: action default (no match) -> plaza.msg.bank.processed
SHOP: changed==false reason 'no_ap' -> plaza.msg.shop.no_ap
SHOP: reason 'not_enough_gold' -> plaza.msg.shop.not_enough_gold
SHOP: reason 'active_slots_full' -> plaza.msg.shop.active_slots_full
SHOP: reason 'no_active_item' -> plaza.msg.shop.no_active_item
SHOP: reason 'no_passive_item' -> plaza.msg.shop.no_passive_item
SHOP: reason 'inventory_full' -> plaza.msg.shop.inventory_full
SHOP: reason 'missing_item_runtime'/'missing_owner' -> plaza.msg.shop.missing_item_bag
SHOP: reason default (_) -> plaza.msg.shop.default_blocked
SHOP: changed==true action 'purchase' -> plaza.msg.shop.purchase
SHOP: action 'sale' -> plaza.msg.shop.sale
SHOP: action default (no match) -> plaza.msg.shop.traded
SHOP: empty display_name fallback -> plaza.msg.shop.fallback_item
GACHA: changed==false reason 'no_ap' -> plaza.msg.gacha.no_ap
GACHA: reason 'not_enough_gold' -> plaza.msg.gacha.not_enough_gold
GACHA: reason 'active_slots_full' -> plaza.msg.gacha.active_slots_full
GACHA: reason 'missing_item_runtime'/'missing_owner' -> plaza.msg.gacha.missing_item_bag
GACHA: reason 'empty_gacha_pool' -> plaza.msg.gacha.empty_gacha_pool
GACHA: reason default (_) -> plaza.msg.gacha.default_blocked
GACHA: changed==true (no action branch, single tail template) -> plaza.msg.gacha.draw
GACHA: empty display_name fallback -> plaza.msg.shop.fallback_item (shared '아이템' fallback)
```

## Plaza dynamic messages: lingpet-store + blacksmith + academy + tavern + ledger defaults + inline failures

- Verified: `true`
- Entries: `79`
- Formatter mappings: `73`
- Verify notes: Re-read plaza_scene.gd verbatim: all four formatters (_format_lingpet_store ~2770, _format_blacksmith ~2813, _format_academy ~2846, _format_tavern ~2871), ledger defaults+summaries (~1469-1548), menu state tag (~1651), inline failures (~2382-2662). Every Korean string matched the proposal exactly (no Korean drift). PLACEHOLDERS: all printf tokens (%s, %d, %dG) verified in source order against args (e.g. ring_core.success = [ring_core_name, new_cap, abs(delta_gold)]; blacksmith.result_success = [display_name, new_level, abs(delta_gold)]; tavern.summary = [plaza_gold, ap_current, quest_state, quest_name, reward_gold]). MAIN FIX CLASS (glossary, rule #3): language_settings_data.gd authoritatively renders 링코어 as ZH 环核 / JA リングコア / ES Núcleo de anillo (line 2302/2821/3340/3859) and 친밀도 as ZH 亲密度 / JA 親密度 / ES Afinidad (line 2117/2636/3155/3674). The proposal left 'Ring Core' English in ALL ZH/JA/ES entries — corrected across all 9 ring_core-bearing entries (no_ap..success + fallback.ring_core_name). 액티브=主动/アクティブ/Activo (2258/2777/3296/3815), 골드=gold/金币/ゴールド/oro confirmed. EN copy, 행동력/열쇠/의뢰 renderings (no existing glossary key) kept as proposed (AP/Key/Quest natural-locale). No source string from this surface is missing; no extra strings invented.
- Wiring note: All four transaction formatters build their string from stable codes: each branches on summary.get("reason")/summary.get("action")/summary.get("result") and the boolean summary.get("changed"). Runtime fix: replace each `return "..."` / `return "..." % [...]` with `return tr(KEY)` or `return tr(KEY) % [localized_args]`, keeping printf placeholders and arg order IDENTICAL. GLOSSARY CORRECTION applied: language_settings_data.gd renders 링코어 NOT as English in ZH/JA/ES but as 环核 / リングコア / Núcleo de anillo (lines 2302/2821/3340/3859), and 친밀도 as 亲密度 / 親密度 / Afinidad (2117/2636/3155/3674); every Ring Core occurrence corrected. Korean particle 은(는) appears only in blacksmith.max_level and is dropped naturally per locale. Ledger default messages (~1475-1545) are the fallback for _active_menu_last_message==''. Ledger NUMBER summary lines (보유 %dG | ...) are composed inline with already-glossed labels and are keyed (보유=Held/예금=Deposit/열쇠=Key/행동력=AP/액티브=Active/링펫=Lingpet/알=Egg/수업료=Lesson fee/비용=Cost/대상 없음=No target/진행 중=In progress/제안=Offered). Menu-row state tag (~1651) and inline device-not-found failures (~2382-2662) are static one-key-each. Fallback display names (아이템=item, 링코어=Ring Core, 의뢰=quest) are keyed. Reuse the SAME key across alias code groups returning identical Korean (missing_lingpet_runtime/missing_affinity_store; missing_lingpet_runtime/missing_owner; missing_runtime_perk_state/missing_runtime_perk_catalog). %dG = gold (int + G suffix), %d = plain int, %s = a localized name the caller must localize before substitution. The AP/Key split is intentional and per-building (ring_core/academy/tavern no_ap=행동력/AP; egg/blacksmith no_ap=열쇠/Key) — do NOT collapse to one key.

```text
LINGPET STORE ring_core (action=='ring_core', changed==false): no_ap -> plaza.msg.lingpet.ring_core.no_ap
ring_core not_enough_gold -> plaza.msg.lingpet.ring_core.not_enough_gold
ring_core missing_lingpet_runtime / missing_affinity_store -> plaza.msg.lingpet.ring_core.missing_runtime
ring_core max_ring_core_tier -> plaza.msg.lingpet.ring_core.max_tier
ring_core missing_ring_core_price -> plaza.msg.lingpet.ring_core.missing_price
ring_core ring_core_upgrade_failed -> plaza.msg.lingpet.ring_core.upgrade_failed
ring_core default (_) -> plaza.msg.lingpet.ring_core.unavailable
ring_core changed==true (success) -> plaza.msg.lingpet.ring_core.success
LINGPET STORE egg (action!='ring_core', changed==false): no_ap -> plaza.msg.lingpet.egg.no_ap
egg not_enough_gold -> plaza.msg.lingpet.egg.not_enough_gold
egg egg_already_active -> plaza.msg.lingpet.egg.already_active
egg no_hatch_candidates -> plaza.msg.lingpet.egg.no_candidates
egg missing_lingpet_runtime / missing_owner -> plaza.msg.lingpet.egg.missing_runtime
egg manage_stub -> plaza.msg.lingpet.egg.manage_stub
egg default (_) -> plaza.msg.lingpet.egg.unavailable
egg changed==true (success) -> plaza.msg.lingpet.egg.success
BLACKSMITH changed==false: no_ap -> plaza.msg.blacksmith.no_ap
blacksmith not_enough_gold -> plaza.msg.blacksmith.not_enough_gold
blacksmith no_active_item -> plaza.msg.blacksmith.no_active_item
blacksmith max_level -> plaza.msg.blacksmith.max_level
blacksmith missing_owner -> plaza.msg.blacksmith.missing_owner
blacksmith default (_) -> plaza.msg.blacksmith.unavailable
blacksmith result=='success' -> plaza.msg.blacksmith.result_success
blacksmith result=='maintain' -> plaza.msg.blacksmith.result_maintain
blacksmith result=='fail' -> plaza.msg.blacksmith.result_fail
blacksmith result default -> plaza.msg.blacksmith.result_attempted
ACADEMY changed==false: no_ap -> plaza.msg.academy.no_ap
academy not_enough_gold -> plaza.msg.academy.not_enough_gold
academy missing_owner -> plaza.msg.academy.missing_owner
academy missing_runtime_perk_state / missing_runtime_perk_catalog -> plaza.msg.academy.missing_runtime
academy choice_already_active -> plaza.msg.academy.choice_active
academy no_academy_choices -> plaza.msg.academy.no_choices
academy exchange_stub -> plaza.msg.academy.exchange_stub
academy default (_) -> plaza.msg.academy.unavailable
academy changed==true & choice_opened==true -> plaza.msg.academy.lesson_started
academy changed==true & choice_opened==false -> plaza.msg.academy.lesson_no_choice
TAVERN changed==false: no_ap -> plaza.msg.tavern.no_ap
tavern quest_already_active -> plaza.msg.tavern.quest_active
tavern stage_already_accepted -> plaza.msg.tavern.stage_accepted
tavern invalid_quest -> plaza.msg.tavern.invalid_quest
tavern no_active_quest -> plaza.msg.tavern.no_active_quest
tavern quest_in_progress -> plaza.msg.tavern.quest_in_progress
tavern missing_plaza_save_store -> plaza.msg.tavern.missing_store
tavern default (_) -> plaza.msg.tavern.unavailable
tavern action=='accept' -> plaza.msg.tavern.accepted
tavern action=='complete' -> plaza.msg.tavern.completed
tavern action default -> plaza.msg.tavern.processed
INLINE device-not-found null guard: gacha (2570) -> plaza.fail.gacha_device_missing
lingpet_store (2591) -> plaza.fail.lingpet_device_missing
blacksmith (2613) -> plaza.fail.blacksmith_ledger_missing
academy (2633) -> plaza.fail.academy_device_missing
tavern (2662) -> plaza.fail.tavern_device_missing
bank (2391) -> plaza.fail.bank_ledger_missing
default menu type _trigger_menu_action (2382) -> plaza.fail.not_ready
shop reorder success (2445) -> plaza.msg.shop.reorder_done
MENU ROW state tag _is_executable_menu_type true (1651) -> plaza.menu.state.executable
MENU ROW state tag false (1651) -> plaza.menu.state.coming_soon
LEDGER default (_active_menu_last_message==''): bank (1475) -> plaza.ledger.default.bank
shop (1484) -> plaza.ledger.default.shop
gacha (1494) -> plaza.ledger.default.gacha
lingpet_store (1504) -> plaza.ledger.default.lingpet
tavern (1519) -> plaza.ledger.default.tavern
academy (1528) -> plaza.ledger.default.academy
blacksmith (1545) -> plaza.ledger.default.blacksmith
ledger else-branch note (1548) -> plaza.ledger.default.coming_soon
LEDGER summary lines: bank (1469) -> plaza.ledger.bank.summary
shop (1478) -> plaza.ledger.shop.summary
gacha (1487) -> plaza.ledger.gacha.summary
lingpet (1497) -> plaza.ledger.lingpet.summary
tavern (1511) -> plaza.ledger.tavern.summary; quest_state %s = plaza.ledger.tavern.state.in_progress | plaza.ledger.tavern.state.offered (1510)
academy (1522) -> plaza.ledger.academy.summary
blacksmith (1538) -> plaza.ledger.blacksmith.summary; target %s = plaza.ledger.blacksmith.target (1534, has_target) | plaza.ledger.blacksmith.no_target (1532)
FALLBACK names: ring_core_name absent (2790) -> plaza.msg.lingpet.fallback.ring_core_name; blacksmith display_name absent (2817) & blacksmith ledger target name (1535) -> plaza.fallback.item_name; tavern quest_name absent (2873/2875) & tavern ledger name (1515) -> plaza.fallback.quest_name
```

## Plaza static UI: building menu specs + building display names + action labels + ring-core tier names

- Verified: `true`
- Entries: `58`
- Formatter mappings: `20`
- Verify notes: Read all 6 real source files. KEY WIRING CORRECTION vs proposed table: plaza_scene.gd:1982-1988 sets _active_menu_actions = const-dict BUILDING_MENU_SPECS[type].actions, then OVERRIDES with get_menu_action_labels() ONLY for academy / lingpet_store / tavern. gacha, blacksmith, shop, bank do NOT get an override, so their const-dict 'actions' literals ARE the LIVE displayed labels (verified at draw site _draw_menu_action_row 1465-1466). Consequences I fixed: (1) GACHA live label is the const-dict baked literal '액티브 캡슐 뽑기 150G' (digit baked), NOT the module's %dG form — proposed note wrongly called the baked literal 'stale'; it is the live string. I keep the %dG TEMPLATE key but the wiring_note now says gacha must be rewired to source from PlazaGachaTransactions.get_menu_action_labels() so the placeholder survives. (2) BLACKSMITH live label is the const-dict '마지막 아이템 강화' (happens to equal the module string). (3) BANK action labels were MISSING entirely from the proposed table — '예금 100G' '출금 100G' '이자 정산' are LIVE (no module override) — added 3 entries. (4) ACADEMY const-dict actions are '스킬 획득'/'스킬 교환' but the live override gives '스킬 수업 %dG'/'스킬 교환'; the dead '스킬 획득' is now keyed for completeness (parity with the keyed tavern '퀘스트 받기'). All other const-dict action literals confirmed verbatim. Glossary checks vs language_settings_data.gd: 링코어 stat-row = Ring Core/环核/リングコア/Núcleo de anillo (2302/2821/3340/3859) → missing_tier fallback reuses it exactly; perk lingpet_ring_core_upgrade = EN 'Ring Core Upgrade', ES 'Mejora de Ring Core' (896/1076) → upgrade_generic matches. 링펫=Lingpet (2110). ZH for ring-core action templates uses 环核 to match the stat-row. ES action templates keep 'Ring Core' untranslated (matching the ES perk glossary which keeps 'Ring Core'), while the bare %s fallback reuses ES 'Núcleo de anillo' from the stat-row key — intentional split, flagged. Tier-name locale rendering is intentionally non-uniform (ZH translates loanwords to meaning 标准/增压/超载/超频/终极/巅峰; JA keeps katakana; ES keeps English loanwords) because the KR source words are themselves English loanwords; acceptable per locale. NOT keyed (adjacent, outside the 4 named families): the '닫기' close button (1463) and the bank ledger line '보유 %dG  |  예금 %dG  |  열쇠 %d' (1469) — flag for a follow-up plaza-UI surface. Placeholder audit: every %d / %s in EN/ZH/JA/ES matches Korean count & order; 'G' gold suffix kept immediately after %d everywhere.
- Wiring note: Four string families wire differently and the action-label override is partial — this is the load-bearing correction. (1) Building display names + subtitles + NPC names + greeting lines are CONST DICTS in plaza_scene.gd (BUILDING_MENU_SPECS title/subtitle ~89-121, INTERIOR_NPC_NAMES ~67-75, INTERIOR_GREETING_LINES ~77-85). The seven type words are ALSO duplicated verbatim in plaza_asset_loader.gd get_building_display_name match (~649-665). The const-dict title and the asset_loader match return the SAME seven words, so each building resolves to ONE shared key (plaza.building.<type>.name); fix BOTH sites to translate() the shared key or the asset_loader path leaks Korean. (2) Action labels: plaza_scene.gd:1982 first loads _active_menu_actions from the const-dict BUILDING_MENU_SPECS[type].actions, then OVERRIDES it with each module's get_menu_action_labels() ONLY for academy (1984), lingpet_store (1986), and tavern (1988). gacha, blacksmith, shop, bank are NOT overridden, so their const-dict 'actions' literals ARE the LIVE displayed labels (drawn at _draw_menu_action_row 1465-1466). Therefore: gacha shows the BAKED literal '액티브 캡슐 뽑기 150G' (digit baked into the const-dict, NOT the module's %dG), and blacksmith shows '마지막 아이템 강화', and bank shows the three baked '예금 100G'/'출금 100G'/'이자 정산'. To localize with placeholders, REWIRE gacha and blacksmith (and ideally bank) to source from their transaction modules' get_menu_action_labels() (gacha module returns the %dG form), then translate(\"plaza.action.<id>\") % [cost]. The const-dict baked '...150G'/'...250G' literals and the dead '스킬 획득' (academy)/'퀘스트 받기' (tavern)/'링펫 관리' (lingpet_store) are landmines: they will not localize the digit and several disagree with the live module wording — do not source live labels from the const-dict for overridden buildings; for the 3 currently-unoverridden buildings, add the override so the placeholder template wins. (3) Ring-core tier names are an indexed array RING_CORE_TIER_NAMES (index 1..6; index 0 is an empty-string sentinel with no key). get_ring_core_tier_name(tier) returns by index -> map tier index to plaza.ring_core.tier.<n>. The ring-core ACTION label _build_ring_core_action_label (~238) builds \"%s 링코어 강화 %dG\" % [next_tier_name, cost] with three fallback states (링코어 최대 단계 / 링코어 강화 준비 중 / 링코어 강화). The %s arg must itself be a LOCALIZED tier name, so the composed runtime call is translate(\"plaza.action.lingpet_ring_core.upgrade\") % [translate(plaza.ring_core.tier.N), cost]. The bare \"링코어\" fallback (offer.get next_tier_name default in the %s slot) reuses the existing stat-row \"링코어\" key (Ring Core / 环核 / リングコア / Núcleo de anillo) — do not add a new key for it. (4) Tavern quest catalog (QUEST_CATALOG name/description, plaza_tavern_transactions.gd ~3-22) is player-facing in the tavern offer/report UI and is keyed. Out-of-scope adjacent strings noted but not keyed here: the '닫기' close-button label and the bank ledger line '보유 %dG  |  예금 %dG  |  열쇠 %d' — route to a follow-up plaza-UI surface.

```text
academy live action 0 (module override) -> plaza.action.academy.skill_lesson ("스킬 수업 %dG")
academy live action 1 (module override) -> plaza.action.academy.skill_exchange ("스킬 교환")
academy const-dict action 0 (DEAD, overridden) -> plaza.action.academy.acquire_skill_legacy_label ("스킬 획득")
gacha live action 0 (const-dict, NO override; baked digit) -> plaza.action.gacha.pull_active_capsule ("액티브 캡슐 뽑기 %dG") — rewire to module form to keep %d
blacksmith live action 0 (const-dict, NO override) -> plaza.action.blacksmith.enhance_last_item ("마지막 아이템 강화")
bank live action 0 (const-dict, NO override) -> plaza.action.bank.deposit ("예금 100G")
bank live action 1 (const-dict, NO override) -> plaza.action.bank.withdraw ("출금 100G")
bank live action 2 (const-dict, NO override) -> plaza.action.bank.settle_interest ("이자 정산")
tavern live action 0 (module override) -> plaza.action.tavern.accept_quest ("의뢰 받기")
tavern live action 1 (module override) -> plaza.action.tavern.report_quest ("의뢰 보고")
tavern const-dict action 0 (DEAD, overridden) -> plaza.action.tavern.accept_quest_legacy_label ("퀘스트 받기")
lingpet_store live action 0 (module override) -> plaza.action.lingpet_store.pull_resonance_egg ("공명 알 뽑기 %dG")
lingpet_store const-dict action 1 (DEAD, overridden by ring-core) -> plaza.action.lingpet_store.manage_lingpets ("링펫 관리")
lingpet_store live action 1 can_upgrade -> plaza.action.lingpet_ring_core.upgrade ("%s 링코어 강화 %dG")
lingpet_store live action 1 reason=max_ring_core_tier -> plaza.action.lingpet_ring_core.max_tier ("링코어 최대 단계")
lingpet_store live action 1 reason=missing_lingpet_runtime -> plaza.action.lingpet_ring_core.preparing ("링코어 강화 준비 중")
lingpet_store live action 1 default fallback -> plaza.action.lingpet_ring_core.upgrade_generic ("링코어 강화")
ring-core %s tier-name slot index 1..6 -> plaza.ring_core.tier.1..6 (array index 0 is empty-string sentinel, no key)
ring-core %s missing-tier fallback literal "링코어" -> existing stat-row key (Ring Core / 环核 / リングコア / Núcleo de anillo)
building display name (BOTH plaza_scene BUILDING_MENU_SPECS.title AND plaza_asset_loader.get_building_display_name) shop/bank/gacha/lingpet_store/blacksmith/tavern/academy -> plaza.building.<type>.name (one shared key per type, fix both sites)
```

## Plaza static UI: NPC names + greetings + quests + interior_view labels

- Verified: `true`
- Entries: `48`
- Formatter mappings: `16`
- Verify notes: All 47 source strings verified verbatim against the three real files. Corrections applied: (1) JA 나가기 出る->退出 to match glossary line 3315. (2) JA price_label.sell 売値->売却価格 to match canonical 판매가 (glossary line 3533). (3) JA price_label.buy 買値->購入価格 to mirror corrected sell rendering. (4) ES quest scroll_delivery desc 스테이지 'etapa'->'fase' (glossary renders 스테이지 as 'fase', lines 3833/4188). (5) ES tavern action labels normalized to 'encargo' consistently. Added 2 dropped player-facing strings: line 594 %dG gold display and line 1120 ESC literal. Confirmed: 판매가 EN/ZH match glossary (Sell Price/售价); 취소 ES=Cancelar (glossary 4212), EN/ZH/JA have no canonical glossary entry so standard renderings used; 인벤토리/행동력/구매가/오늘의특가/아이템거래/실행 not in glossary, natural renderings used. '|' separators and literal \n preserved in templates (runtime splits in plaza_interior_view _draw_shopkeeper_speech_bubble line 654-657). All printf placeholders (%s, %d, %dG) confirmed identical in count/order across EN/ZH/JA/ES. AP glossary=Action Point; ES uses PA abbreviation, EN/ZH/JA keep AP.
- Wiring note: Three source files. (1) plaza_scene.gd INTERIOR_NPC_NAMES (lines 67-75) and INTERIOR_GREETING_LINES (lines 77-85) are dicts keyed by building id (shop/bank/gacha/lingpet_store/blacksmith/tavern/academy); use the building id as the dotted-key leaf. Greeting strings contain a '|' separator that the runtime splits into two bubble lines (plaza_interior_view _draw_shopkeeper_speech_bubble line 655-657 splits on '\\n' then '|'); kept each greeting as ONE piped key so translate(key) returns a piped string the existing split logic handles unchanged. (2) plaza_tavern_transactions.gd QUEST_CATALOG (lines 3-22): each quest has a stable id (supply_route/neon_trace/scroll_delivery) -> map id to plaza.quest.<id>.name / .desc; get_menu_action_labels() (line 26) two actions -> plaza.quest.action.accept / .report. (3) plaza_interior_view.gd static draw-time literals plus printf templates. NPC names embed a TYPE word (상점주인=Shopkeeper, 은행원=Bank Teller, etc.) + a TRANSLITERATED personal name (모라=Mora etc.): translate the type word naturally per locale, transliterate the name (transliteration=true). Templates keeping %s/%d/%dG: '%s을(를) 판매할까요?' (1266), '%s  ·  거래' (932), '%s의 효과를 전투 중에 발동합니다.' (2047), '%dG' (594), 'AP %d' (1365), '%s  %d' panel title+count (1139), '%s %sG'/'%s -' price text (1214). The 판매가/구매가 labels (1213) feed the price_text template as the first %s. The shopkeeper default bubble (654) carries a literal \\n that must be kept in the template. 'ESC' (1120) is a fixed keycap literal - recorded but locale-invariant.

```text
quest id supply_route -> plaza.quest.supply_route.name / plaza.quest.supply_route.desc
quest id neon_trace -> plaza.quest.neon_trace.name / plaza.quest.neon_trace.desc
quest id scroll_delivery -> plaza.quest.scroll_delivery.name / plaza.quest.scroll_delivery.desc
tavern menu action index 0 (의뢰 받기) -> plaza.quest.action.accept
tavern menu action index 1 (의뢰 보고) -> plaza.quest.action.report
building id shop -> plaza.npc.shop / plaza.greeting.shop
building id bank -> plaza.npc.bank / plaza.greeting.bank
building id gacha -> plaza.npc.gacha / plaza.greeting.gacha
building id lingpet_store -> plaza.npc.lingpet_store / plaza.greeting.lingpet_store
building id blacksmith -> plaza.npc.blacksmith / plaza.greeting.blacksmith
building id tavern -> plaza.npc.tavern / plaza.greeting.tavern
building id academy -> plaza.npc.academy / plaza.greeting.academy
trade hover panel == 'player' -> plaza.interior.price_label.sell ; else -> plaza.interior.price_label.buy
price > 0 -> plaza.interior.price_text_value ; else -> plaza.interior.price_text_unavailable
strewn label != '' -> plaza.interior.strewn_trade_label ; else -> plaza.interior.strewn_trade_label_fallback
item has description/desc/korean_desc/tooltip/summary -> (use item desc) ; elif name != '' -> plaza.interior.trade.desc_fallback_named ; else -> plaza.interior.trade.desc_fallback_generic
```

## Stage 6 Tetriser boss-skill HUD

- Verified: `true`
- Entries: `16`
- Formatter mappings: `0`
- Verify notes: All 16 Korean strings verified VERBATIM against TOOLTIP_INFO (L22-39): 4 skill ids x {name, trigger, cooldown, description}. No source string dropped, none invented. No printf placeholders anywhere — every value is a fixed label/sentence; numbers (5~10, 7~15, 30, 50/100, 50, 500) are baked into the localized text. Glossary grep of language_settings_data.gd corrections applied: (1) boss name 테트리서 = "Tetrisser" (EN/ES L2361/L3918), "特崔瑟" (ZH L2880), "テトリサー" (JA L3399) — proposal had wrong "Tetriser"/"特里瑟", fixed stage6.skill.super.name across EN/ZH/ES (JA was already correct). (2) Confirmed 게이지=Gauge/能量/ゲージ/Energía (L2484/3003/3522/4041) — proposal's gauge fields already matched, kept. (3) Confirmed 자동=Auto/自动/自動/Auto (L2431/2950/3469/3988) — trigger fields match. (4) Confirmed 발동 중=Casting/发动中/発動中/Activando (L2471/2990/3509/4028); super.cooldown "발동 중 드레인" uses natural phrasing ("drains while active") which is correct for the phrase context, ZH/JA keep 发动中/発動中 prefix. (5) Confirmed 변신=Transform/变身/変身/transformación (L2505/3024/3543/4062) — super.description aligned. Tetro-prefix names (낙하 테트로/테트로 벽) kept block-oriented renderings (ZH 方块=tetromino block) since 테트로 denotes the blocks, not the boss; only 초인테트리서 carries the boss transliteration.
- Wiring note: All strings live in stage6_tetriser_boss_skill_hud_renderer.gd TOOLTIP_INFO (lines 22-39): four skill ids (stage6_tetro_drop / stage6_guard / stage6_wall / stage6_super), each with name/trigger/cooldown/description. These STATIC label dicts are consumed by BossSkillCardHudSpec.draw_skill_tooltip (call at lines 129-132) which receives the per-id sub-dict via _get_array_safe_dict(TOOLTIP_INFO.get(...)). The same `name` field is ALSO drawn as the active card label via skill.get("name") at lines 177/181 in _draw_card — but that `name` comes from the HUD context entry (context["stage6_boss_skill_hud_skills"]), NOT from TOOLTIP_INFO. Runtime fix: (1) replace the literal Korean in TOOLTIP_INFO with translate(key) per field using stage6.skill.<id>.{name,trigger,cooldown,description}; (2) CRITICAL — the card-label `name` drawn at L177/181 is sourced upstream in stage6_tetriser_state.get_hud_context()'s `stage6_boss_skill_hud_skills` builder, which likely hardcodes the same Korean name a second time; that builder must read the SAME stage6.skill.<id>.name key so card label and tooltip stay in sync (audit that second site for a duplicate Korean literal). No printf placeholders on this surface, so formatter_mapping is empty and there is no dynamic formatter.
