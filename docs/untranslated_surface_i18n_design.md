# 미번역 Surface i18n 설계 - 광장 / 패배 / Stage 6

작성일: 2026-06-21

대상: Godot **환격전**의 비한국어 모드에서 한국어가 노출되는 광장,
패배 결산/컨티뉴, Stage 6 테트리서 HUD, 기타 HUD surface.

이 문서는 구현 전에 고정할 설계 문서다. 실제 키 테이블은
`docs/untranslated_surface_i18n_key_table.tsv`, 포매터 분기 매핑은
`docs/untranslated_surface_i18n_formatter_mapping.md`를 기준으로 한다.

## 1. 확정 정책

### 1.1 PT-BR / RU

신규 광장, 결산, Stage 6 문자열의 PT-BR/RU는 영어 fallback을 유지한다.

- EN/ZH/JA/ES는 명시 번역한다.
- PT-BR/RU는 신규 키에 대해 영어 문자열을 표시해도 된다.
- 단, PT-BR/RU에서도 한국어가 직접 노출되면 실패다.
- `EXACT_TEXT_PT_BR := EXACT_TEXT_EN`, `EXACT_TEXT_RU := EXACT_TEXT_EN` 구조는 유지한다.
- `TEXT` 맵에 신규 정적 키를 넣을 때는 PT-BR/RU 칸에도 영어 fallback 값을 채워 키 정합 스모크를 통과시킨다.

### 1.2 고유명

광장 NPC 개인명은 음역한다. 직책/건물 기능명은 각 언어에서 자연스러운 의미 번역을 쓴다.

예:
- `상점주인 모라` -> `Shopkeeper Mora`
- `은행원 도윤` -> `Bank Teller Doyun`
- `대장장이 강철` -> `Blacksmith Gangcheol`
- `상점` -> `Shop`
- `은행` -> `Bank`
- `링펫스토어` -> `Lingpet Store`

순수 건물명까지 `Sangjeom`, `Eunhaeng`처럼 음역하지 않는다. 기능 UI에서는 플레이어가 즉시 역할을 알아보는 쪽이 우선이다.

### 1.3 키 시스템

완성된 한국어 문장을 `translate_text()`에 던지는 방식은 금지한다.

광장 거래 메시지처럼 `%s/%d`가 이미 채워진 뒤 반환되는 문자열은 exact-match가 실패한다.
해당 경로는 안정 키 + 템플릿 포맷으로 바꾼다.

예:

```gdscript
# before
return "%s을(를) 구매했습니다. %dG" % [display_name, gold]

# after
return LanguageSettings.translate("plaza.msg.shop.purchase") % [
	localized_display_name,
	gold,
]
```

템플릿의 placeholder 개수와 순서는 KO/EN/ZH/JA/ES에서 동일해야 한다. 인자 이름,
아이템명, 퍽명, 보스명은 템플릿 포맷 전에 별도로 현지화한다.

## 2. 산출물

### 2.1 키 테이블

`docs/untranslated_surface_i18n_key_table.tsv`

컬럼:

```text
verified  surface  key  ko  placeholders  en  zh  ja  es
```

`verified=true` 행은 워크플로 검증 패스에서 소스 재확인을 마친 항목이다.
현재 TSV는 모든 surface가 최신 verified 결과를 사용한다.

현재 표면별 행 수:

| Surface | 행 수 | 상태 |
|---|---:|---|
| Defeat chance-gems continue screen | 9 | verified |
| Defeat settlement screen | 24 | verified |
| Plaza dynamic messages: bank + shop + gacha | 28 | verified |
| Plaza static UI: NPC names + greetings + quests + interior_view labels | 48 | verified |
| Stage 6 Tetriser boss-skill HUD | 16 | verified |
| Plaza dynamic messages: lingpet-store + blacksmith + academy + tavern + ledger defaults + inline failures | 79 | verified |
| Plaza static UI: building menu specs + building display names + action labels + ring-core tier names | 58 | verified |
| Misc surfaces: perk overlay, weapon names, stage landing, horn strawberry, pickup, scroll button, char-info labels | 54 | verified |

총 316개 키 후보다.

### 2.2 포매터 매핑

`docs/untranslated_surface_i18n_formatter_mapping.md`

각 surface별로 다음을 기록한다.

- 원본 포매터/렌더러의 분기 조건
- 분기 코드 -> 안정 키 매핑
- placeholder 인자 순서
- 동적 인자 현지화 책임
- 검증 여부

## 3. 구현 규칙

### 3.1 `TEXT` 우선

점 키 기반 정적 UI와 동적 템플릿은 `LanguageSettings.translate(key)` 경로로 넣는다.

대상:
- `plaza.*`
- `defeat.*`
- `stage6.skill.*`
- `perk.overlay.*`
- `weapon.*`
- `stage.landing.*`
- `hud.*`
- `charinfo.*`

`EXACT_TEXT_*`는 이미 raw Korean source가 들어오는 레거시 exact-match 경로에만 쓴다.
신규 광장 포매터를 exact-match로 설계하지 않는다.

### 3.2 모든 언어 키 정합

`TEXT` 키는 KO/EN/ZH/JA/ES/PT_BR/RU 모두에 추가한다.

- KO: 원문
- EN/ZH/JA/ES: TSV 명시 번역
- PT_BR/RU: 영어 fallback 값

`EXACT_TEXT`에 새 키가 정말 필요한 경우 EN/ZH/JA/ES를 모두 추가해야 한다. PT_BR/RU는 alias 정책을 유지한다.

### 3.3 동적 이름 현지화

포맷 템플릿의 `%s`에 raw 한국어 이름을 넣지 않는다.

- 아이템명: 기존 item display map / catalog localization 경로
- mythic 아이템명: 기존 mythic item map
- 퍽명: `PERK_NAME_*`를 perk id로 조회
- 보스명: 기존 exact text를 우선 재사용, 없는 이름만 신규 키
- NPC명: TSV의 `plaza.npc.*`
- 무기명: TSV의 `weapon.name.*`

### 3.4 문자 조합형 UI

분절 컬러 텍스트처럼 언어별 어순이 달라지는 UI는 한국어 segment 순서를 고정하지 않는다.

예: 컨티뉴 화면의 `확인하면 기회의 보석이 / 1개 / 소모됩니다.`

권장 구현:

1. 전체 템플릿을 `defeat.continue.gem_consume_on_confirm`으로 번역한다.
2. `%s`에 현지화된 count token을 넣는다.
3. 렌더러는 완성 문자열에서 count token substring만 강조색으로 칠한다.

## 4. Surface별 배선 요약

### 4.1 Plaza 동적 메시지

대상:
- `godot/scripts/plaza/plaza_scene.gd`
- `_format_bank_transaction_message`
- `_format_shop_transaction_message`
- `_format_gacha_transaction_message`
- `_format_lingpet_store_transaction_message`
- `_format_blacksmith_transaction_message`
- `_format_academy_transaction_message`
- `_format_tavern_transaction_message`

분기 코드(`reason`, `action`)는 그대로 유지한다. 각 return은 `translate(key)`로 바꾸고,
필요한 인자만 `%`로 적용한다.

주의:
- shop/gacha `display_name == ""` fallback도 키화한다.
- shop/gacha/bank의 `no_ap`는 현재 `열쇠가 부족합니다.`지만, lingpet/academy/tavern 쪽은 `행동력이 부족합니다.`다. 같은 reason 이름이라도 텍스트 의미가 다르므로 키를 공유하지 않는다.

### 4.2 Plaza 정적 UI

대상:
- 건물 메뉴 제목/부제/액션
- 건물 표시명
- NPC명/인사말
- tavern quest name/description
- interior trade modal labels
- sell confirm labels
- ring-core tier names

건물 기능명은 의미 번역, NPC 개인명은 음역한다.

인사말의 `|` separator와 `\n` newline은 유지한다. 런타임 split 로직을 바꾸지 않는
경우 번역 문자열도 동일한 separator를 포함해야 한다.

### 4.3 Defeat settlement

대상:
- `godot/scripts/core/defeat_settlement_screen.gd`

정적 라벨은 `defeat.settlement.*`로 키화한다.

주의:
- 퍽 이름은 신규 `defeat.*` 키가 아니라 기존 `PERK_NAME_*` 맵을 사용한다.
- 아이템 이름도 기존 catalog localization을 사용한다.
- 보스명은 기존 exact text가 있는 경우 재사용한다. `폰크`는 신규 렌더링이 필요하다.
- `%d : %d` 같은 순수 점수값은 번역하지 않는다.

### 4.4 Defeat continue

대상:
- `godot/scripts/core/defeat_chance_gems_continue_screen.gd`

multiline guide는 `\n`을 유지한다.
세그먼트 컬러 status text는 전체 템플릿 + count substring 강조 방식으로 바꾼다.

### 4.5 Stage 6 Tetriser HUD

대상:
- `godot/scripts/stages/stage6/stage6_tetriser_boss_skill_hud_renderer.gd`
- `godot/scripts/stages/stage6/stage6_tetriser_state.gd`

`TOOLTIP_INFO`와 카드 label source를 같은 `stage6.skill.<id>.*` 키로 묶는다.
tooltip만 번역하고 card label은 `stage6_tetriser_state.gd`의 hardcoded Korean을 계속 쓰는 부분 번역은 실패다.

### 4.6 Misc surfaces

대상:
- `runtime_perk_overlay_renderer.gd`
- `commando_weapon_controller.gd`
- `commando_firearm_selector_renderer.gd`
- `stage_landing_intro.gd`
- `horn_strawberry_skill_pillar_renderer.gd`
- `active_item_pickup_feedback.gd`
- `stage_clear_result_scroll_content_draw_helper.gd`
- `character_info_overlay_stats_presenter.gd`
- `character_info_overlay_lingpet_presenter.gd`
- `character_info_overlay_header_presenter.gd`

캐릭터 정보 패널에는 철자 불일치로 exact-match가 실패하는 값이 있다.

- 코드: `몸집 크기`, 기존 키: `몸집크기`
- 코드: `대시 후딜 시간`, 기존 키: `대시 후딜시간`

이 둘은 새 키를 늘리기보다 canonical spelling을 정하고 코드와 데이터 중 하나를 맞춘다.

## 5. 회귀 스모크

기존 `localization_coverage_smoke.gd`는 카탈로그/포매터/일부 화이트리스트 중심이라
draw surface 누수를 직접 보지 못한다. 아래 focused smoke를 추가한다.

### 5.1 `plaza_localization_smoke.gd`

검사:
- 모든 plaza formatter reason/action 분기 출력
- 빈 display_name fallback
- item display_name이 현지화된 뒤 템플릿에 들어가는지
- 건물/NPC/인사말/퀘스트/ring-core tier 텍스트

언어:
- EN/ZH/JA/ES/PT_BR/RU

단언:
- 비한국어에서 Hangul 0
- EN/ZH/JA/ES는 한국어 원문과 다름
- placeholder 결과가 깨지지 않음

### 5.2 `defeat_i18n_smoke.gd`

검사:
- defeat settlement label builder
- boss name table
- perk/item dynamic name route
- chance-gems guide/status templates
- segmented count highlight input

### 5.3 `stage6_tetriser_hud_i18n_smoke.gd`

검사:
- `stage6.skill.*` name/trigger/cooldown/description
- tooltip info와 card label source가 같은 현지화 키를 쓰는지

### 5.4 `misc_hud_i18n_smoke.gd`

검사:
- perk overlay static labels
- commando weapon names/badges
- stage landing subtitles
- horn strawberry skill labels/descriptions
- active item pickup hint
- stage-clear `광장으로`
- character-info stat labels

## 6. 구현 순서

1. `TEXT` 맵에 verified surface부터 추가한다.
2. `LanguageSettings`에 필요하면 `format_text(key, args)` 같은 작은 helper를 추가한다.
3. Plaza bank/shop/gacha formatter를 안정 키 템플릿으로 교체한다.
4. Defeat continue/settlement를 교체한다.
5. Stage 6 tooltip + card label source를 동시에 교체한다.
6. Misc/Plaza author-pass였던 surface도 검증 완료됐으므로, 적용 전에는 최신 소스와 충돌이 없는지만 재확인한다.
7. focused smoke를 추가한다.
8. `godot/tools/run_warning_scan.ps1`와 `godot/tools/run_headless_load_check.ps1`를 실행한다.

## 7. 검증 전제

이 문서는 구현 전 설계/테이블 산출물이다. 아직 런타임 코드는 바꾸지 않았다.
구현 전에 반드시 원본 파일을 다시 읽고 최신 코드와 placeholder/order 충돌이 없는지 재확인해야 한다.
