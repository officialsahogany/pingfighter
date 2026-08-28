# 지시문 Z10 — 서브 문구가 실제 보스와 일치하게

- **발행**: 관제탑 2026-08-29. 기준선 = 본 트리 HEAD (Z7-수정 착지 이후).
- **격리 워크트리 + 격리 브랜치.** 본 트리 편집·통합·푸시 금지.
- **적합 세션**: Z7-수정을 만든 세션(codex/feedback10-serve-wait-revert).
  같은 파일이며 방금 그 코드를 만졌다.

## 사용자 보고 (스크린샷 확정)

각시탈전인데 서브 대기 표시가 **"달지 차례"** 다. 상단 소형 표시와 중앙
대형 배너 둘 다.

## ★진범 (관제탑 확정 — 재조사 금지)

`godot/scripts/hud/serve_wait_indicator_renderer.gd`

```gdscript
const STAGE_BOSS_NAMES := { 1: "달지" }                       # :21~23
...
func _get_serve_label(player_serves: bool, context: Dictionary) -> String:
	var boss_name_key: String = str(STAGE_BOSS_NAMES.get(current_stage, "보스"))
	var boss_name: String = LanguageSettings.translate_text(boss_name_key)
	return LanguageSettings.translate("hud.serve_wait.boss_turn_format") % boss_name
```

★**스테이지 번호 고정 테이블**이다. 1층 3보스 로스터(달지/각시탈/포도대장)
도입 후 스테일 — variant 를 전혀 보지 않는다.

★**숨은 증상**: 테이블에 1층뿐이라 **2층 이상은 전부 폴백 "보스 차례"** 다.
청린귀·연묘 등 이름이 안 나온다. 함께 고쳐라.

상단 소형·중앙 대형 배너 모두 같은 `serve_label` 을 쓰므로(:51~60) 라벨
소스 한 곳만 고치면 둘 다 잡힌다.

## ★올바른 선례 (재구현 금지 — 그대로 따르라)

`scoreboard_overlay_header_renderer.gd:231~238` 이 정답 경로다.

```gdscript
var variant: String = _normalize_stage1_variant(draw_context.get("stage1_boss_variant", "dalji"))
... draw_context.get("stage_boss_variant", "") ...   # + StageBossVariantCatalog
```

`battle_scene_match_event_driver.gd:505~506` 이 owner 에
`stage1_boss_variant` / `stage_boss_variant` 를 세팅한다.

## 요구

1. `STAGE_BOSS_NAMES` 고정 테이블을 제거하고, 전광판 헤더와 **같은 계약**
   (owner/context 의 variant + `StageBossVariantCatalog` 계열)로 보스 표시
   이름을 얻어라.
2. **전 스테이지**에서 이름이 나와야 한다. 1층 3종 + 2층 이상 각 변형.
   매핑이 없는 변형이 있으면 **목록으로 보고**하고 폴백("보스")을 유지하라.
3. `_get_serve_label` 의 context 에 variant 가 실제로 들어오는지 확인하라.
   안 들어오면 배선을 추가하되 **전광판이 쓰는 것과 같은 컨텍스트 빌더**를
   써라. 새 경로를 만들지 마라.
4. 다국어: `boss_turn_format` ("%s 차례" / "%s Serve") 구조는 유지. 보스
   이름 번역은 기존 이름 번역 키를 재사용하라.

## ★함정

- **GRT-017/018 유형 주의**: 전투 씬 context 와 HUD context 가 다른 경로일
  수 있다. 전광판이 실제로 받는 컨텍스트와 서브 인디케이터가 받는 컨텍스트가
  같은 빌더인지 확인하고 보고하라.
- X6 사건의 교훈: 시드/변형 권위가 갈라지면 "달지 잡았는데 각시탈 비급"이
  났다. **이번엔 반대 방향(각시탈전인데 달지 표기)** — 표시 경로가 권위
  (owner 의 variant)를 안 읽은 것이다. 반드시 owner 권위를 읽어라.

## 씰 요구

1. ★**변형별 라벨 씰**: stage1 variant 를 dalji/gaksital/podo 로 바꿔가며
   `_get_serve_label` 이 각각 "달지 차례"/"각시탈 차례"/"포도대장 차례" 를
   내는지 단언. 고정 테이블로 되돌리면 RED 반증 후 복구.
2. 2층 이상 대표 변형 1개 이상(청린귀 등) 라벨 단언.
3. 기존 `serve_wait_indicator_localization_smoke` 의 "달지 차례" 단언이
   하드코딩을 봉인하고 있으면 **변형 파라미터화로 재작성**하라. 지우지 마라.
4. **CI/pre-push 락스텝** — 현재 255/255. `comm` 대조 사라진 항목 0.

## 게이트·보고

포커스드 스모크(+반증) → 경고 스캔 → 헤드리스 → `git diff --check` →
★픽셀 QA: **각시탈전 서브 대기** 캡처로 "각시탈 차례" 확인.
⚠기준선 RED 구분 보고, `godot/logs` 사전 복사, `-AllowDuringPlay`,
게임·에디터 종료 금지 — 기존 공통 게이트와 동일.

## 보고

커밋 해시 · 채택한 이름 소스 계약 · context 배선 확인 결과 ·
매핑 없는 변형 목록 · 씰 종단선과 반증 · 각시탈전 캡처 · 미해결.
