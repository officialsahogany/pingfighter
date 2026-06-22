# 링펫어(Lingpet tongue) + 해석기 시스템 — 단일 소스 설계

> 이 문서가 링펫어 언어·문자·문법 + 해석기(decoder) 메커니즘의 진실 원본입니다.
> 디자인/리뷰 = Claude. GDScript 배선 = 사용자/Codex. 자산(폰트/이미지) = Claude.
> 상태: **설계 락(2026-06-22), 미배선.** 적대 리뷰 1회 반영(아래 §8 검증 앵커).

## 0. 명칭 락 (잔재 제거)

| 항목 | 값 |
|---|---|
| 공식 표기(플레이어) | **링펫어** (EN: *Lingpet tongue*) |
| 내부 id | `lingpet_lang` |
| 데이터 키 루트 | `lingpet.language.*` |
| 폰트 family | **"Lingpet Script"** (v1 TTF: `d:\tmp\lingpet_font\LingpetScript-Regular.ttf`, repo 이전 예정 → `godot/assets/fonts/`) |
| 영구 진행 게이트 | `decoder_level` (0~5, plaza_save_store 저장). 플레이어 노출명: **링펫어 해석기 레벨** (EN *Lingpet Decoder Level*) |

`Ringa` / `Linga` 명칭은 폐기. 로마자는 별도 이름 없이 "발음 표기".

## 1. 컨셉

링펫 = 링피아 VR의 **디지털 코드 덩어리**가 **공명**으로 자아를 얻은 존재. 그들끼리 통하는
공통어 = **링펫어**. 플레이어는 **해석기**로 링펫어를 풀어가며 스토리를 진행한다. 코드 기원이
문법에 박혀 있다(§3): **뜻은 자음(코드)에, 감정은 모음(자아)에**.

## 2. 문자 체계 (확정: 알파벳형 음소 글리프 + 특수 시길)

- **음소 글리프 = 기본 문장 입력/표기.** 자음16 + 모음6, 로마자 키 → 기하 글리프(현 TTF).
  플레이어에겐 *신비로운 기하 상형문자*처럼 보이되, 내부는 음소 기반이라 입력/렌더/해석 플립이
  안정적이다. ("영어처럼 보이게"가 아니라 내부 구조만 음소 기반.)
- **특수기호/시길 = 의미층.** 별(✦)=감정/공명 체크섬을 기본으로, 코어 기억·질문·경고 등
  의미 마커. **미해석 시 숨고 100%에서 점등**.
- **해석은 글자 단위가 아니라 단어/토큰 단위로 한국어로 뒤집기.**
- **완전 표의 시길 = 희귀 연출 전용(확정).** 일반 문장은 알파벳형 음소 글리프, **코어 기억 /
  고유명사 / 금기어 / 제니스 보너스**만 "완전 표의 시길"(1글리프=1개념, 리거처/아틀라스)로 둔다.
  희소하게 써야 특별함이 산다 — 작업량/유지비도 통제.
- **비주얼 톤:** 신비로움(촛불·양피지·금박·별 글로우)은 **렌더 단계**(셰이더/배경/색)에서.
  폰트는 "형태"만 책임진다.

### 2.1 글자표 (키매핑) — v1
디그래프는 한 키로: `sh→x · kh→c · ng→g · ts→j · 성문폐쇄'→q`.

| 키 | 음소 | 글리프 | 키 | 음소 | 글리프 |
|---|---|---|---|---|---|
| a | a | ○ 원 | p | p | □ 사각 |
| e | e | △ 삼각상 | t | t | ▽ 삼각하 |
| i | i | │ 세로 | k | k | ✕ |
| o | o | ◎ 원+점 | q | ' | ● 점 |
| u | u | ∨ | s | s | » 이중꺾쇠 |
| y | y(으) | ◇ 마름모 | x | sh | ⬡ 육각 |
| c | kh | ⊠ 사각+X | v | v | ∧ |
| z | z | Ƶ 지그재그 | h | h | H |
| g | ng | ⊖│ 원+세로 | r | r | › |
| l | l | ∟ | j | ts | △· 삼각+점 |
| m | m | ⊞ 격자 | n | n | ◠ 호 |
| * | star | ✶ (체크섬) | ? | 물음 | 갈고리 |

## 3. 음운 / 문법 v0.1

- **음운:** 자음 p t k '(q) s sh(x) kh(c) v z h m n ng(g) r l ts(j) / 모음 a e i o u y.
- **단어 = 자음어근(뜻) + 모음패턴(감정, 필수).** a–a 중립 / o–o 따뜻 / i–e 다급 / u–y 슬픔 /
  e–i 호기심. 감정 없는 단어는 없음(부패체 `nuly`만 전부 y로 단조롭게 말함).
- **패킷 구조:** `[헤더] · [페이로드] · [체크섬(별 ✦)]`. 캐주얼은 헤더/체크섬 생략, 진심/격식은 필수.
- **어순 VSO** + 역할 후치표지: `=ta`(목적) `=shi`(~에게/로) `=ven`(~로부터) `=on`(~에서) `=lo`(~랑/함께).
- **동사:** 시상 `-li`(현재/실행중) `-tha`(과거/반환됨) `-ko`(미래/대기열) 무표지(상수/진리);
  명령 `-zha`; 부정 접두 `nu-`.
- **질문:** 의문사가 호기심 모음(e–i)을 품음 — `vei`(무엇) `tei`(누구) `dei`(어디) `zei`(왜);
  예/아니오 = 끝에 `=ne`.
- **강조/지속 = 루프(반복).** `soro-soro`=계속 달리다. **수 = 이진**(nul0·un1·du2·kwa4·ot8…`mox`).
  명사: 쌍 `-vo`, 복수 `-eth`.
- **예문:** `Kamatha na pala=ta.`(나는 밥을 먹었다) · `Kamatha tu pala=ta=ne?`(밥 먹었어?) ·
  따뜻 버전 `Komotha … ✦`. 새 어근: k-m(먹다) p-l(밥/양식).

## 4. 해석기 메커니즘 (확정)

### 4.1 권위값 = 영구 `decoder_level` (※런 링코어 아님)
- **근거(코드, §8):** 링코어는 v5에서 **런 단위**(store meta-only no-op, `_run_ring_core_tier`가
  `reset_for_new_run()`에서 0). → 스토리 게이트로 쓰면 **매 런 진행도 리셋**되므로 불가.
- `decoder_level` 0~5, **plaza_save_store(영구 원장 — 컨티뉴 보석과 동거)에 저장.**
- **해석률 = clamp(decoder_level × 20, 0, 100).** Lv1=20% … Lv5=100%.
- **상승 경로 = 스토리/수집 마일스톤 중심(확정).** 골드 구매로는 올리지 않는다(링코어 경제와 혼동 +
  "언어를 이해한다"는 서사 보상 약화). 골드/구매는 **보조 장치**만(예: 일시 힌트). 기본 래더(조정 가능):
  - Lv1(20%) = 첫 링펫 부화·계약(튜토리얼) — *첫 교감으로 해석기 보정*
  - Lv2(40%) = 스테이지 2 클리어 · Lv3(60%) = 스테이지 3 클리어
  - Lv4(80%) = 스테이지 4 클리어 · Lv5(100%) = 스테이지 5(홍련) 클리어
  - 수집 마일스톤은 동일 레벨의 **대체 트리거**로 추가 가능; 스테이지 6/제니스는 표의 시길 보너스.
- **저장 스키마 = `decoder_level: int`(0~5) 단일값, 마일스톤이 monotonic-max로만 올림.** 어떤
  마일스톤이 어느 레벨을 여는지는 별도 매핑이라 **스키마/헬퍼를 흔들지 않고 조정 가능**(S1 안정성의 핵심).
- **런 골드 링코어와 무관.**
- 런 링코어(친밀도 캡)는 그대로. 둘은 **별개 시스템** — 문서/UI에서 명확히 구분.
- (옵션, 후속) 링코어 높은 런에 *일시 +reveal 보너스*는 가능하나 코어 게이트는 영구 decoder_level.

### 4.2 데이터 계약 — 안정 키 (※raw ko 금지)
- **근거:** `untranslated_surface_i18n_design.md` §1.3 — 완성 한국어를 `translate_text()`에 던지기
  **금지**. `LanguageSettings.translate(stable_key)` + 템플릿 경로 사용.
- 발화 1건(예):
```
lingpet.language.maribo.greet_arrive = {
  speaker = "maribo", emotion = "warm",
  glyph_text = "komotha tu pala=ta=ne",   # Lingpet Script 폰트로 렌더(미해석 표시)
  tokens = [
    {key="lingpet.language.maribo.greet_arrive.tok01", glyph="komotha", tier=3, kind="verb"},
    {key=".tok02", glyph="tu",   tier=1, kind="root"},
    {key=".tok03", glyph="pala", tier=2, kind="noun"},
    {key=".tok_emotion", glyph="✦", tier=5, kind="emotion"},
  ],
}
```
- 각 `token.key`는 언어별 테이블(KO/EN/ZH/JA/ES 명시, PT-BR/RU=EN fallback)에 등록. **raw ko 직접 금지.**
- 토큰 `tier`(1~5)로 공개 순서 결정: `tier ≤ decoder_level` → 한국어, 아니면 글리프. 토큰 tier를
  배분해 공개 비율 ≈ `decoder_level×20%`. **결정론**(같은 레벨 = 항상 같은 공개 집합).

### 4.3 렌더 계약 — 세그먼트 + RichTextLabel
- **근거:** `character_info_overlay_text_line_cache.draw_string_cached`는 단일 문자열/단일 색
  (§8). 토큰별 색 + 글리프/한국어 혼합 + 별 점등은 단독 불가.
- `reveal(line, decoder_level) -> 세그먼트 배열`: `[{kind: glyph|ko, text, color, decoded, emotion}]`.
- 렌더 = **RichTextLabel 호스트**: 미해석 런 = Lingpet Script 폰트런, 해석 런 = 본문 한국어 폰트,
  색은 토큰별, 별(✦)은 인라인 글리프로 100%에서 점등. (진짜 폰트가 있으므로 BBCode 폰트/색 런이 깔끔.)

### 4.4 호스트 (어디서)
- **인배틀 바크**(비차단 HUD) / **플라자 "링펫 사육사 링링" 스토리 장면**(기존 speech rect 재활용) /
  **도감**(net-new, `decoder_level` 오르면 재방문 시 재해석 — 리플레이 훅, 스토리 척추).
- 차단 모달이면 `battle_scene_modal_gate_controller` 등록; 바크는 비차단.

## 5. 트랩 브리프 (배선 전 필독)
1. **권위값 단일화** — 해석기/도감/HUD 전부 `decoder_level` 한 소스. **런 링코어와 혼동 금지.**
2. **i18n** — raw ko 금지, 안정 키 + 템플릿(`untranslated_surface_i18n_design.md` 준수).
3. **결정론** — 글리프/공개 집합은 (토큰, 레벨) 안정. 프레임마다 랜덤 금지.
4. **렌더** — `draw_string_cached` 단독 금지 → 세그먼트/RichTextLabel.
5. **폰트 로드** — TTF를 `godot/assets/fonts/`에 두고 `FontFile` 프리웜. 누락 시 글리프 안 보임.
6. **공개 비율 스모크** — 레벨별 한국어 공개 비율 ≈ 20×N 단언(반증검증).

## 6. 슬라이스 백본
- **S0** 명칭/문자/문법/계약 락(이 문서) + TTF repo 이전 + 글자표.
- **S1** `decoder_level` 영구 저장(plaza_save_store) + getter + 해석률 헬퍼 + 스모크. **✅완료/리뷰 APPROVE(2026-06-23).**
- **S1.5** 마일스톤 훅(스테이지 클리어 → `unlock_decoder_level`). **✅완료/스모크 통과(2026-06-23). §6.2.**
- **S2** 언어 데이터 모듈(`lingpet.language.*` 키 + 토큰 tier) + `reveal()` 순수함수 + 비율/결정론 스모크. **§6.3.**
- **S3** 렌더(RichTextLabel 세그먼트 호스트) + 해석 플립.
- **S4** 호스트 배선(바크 / 플라자 링링 / 도감).
- **S5** i18n 키 테이블 등록 + 라이브 QA.

## 6.1 S1 배선 계약 (`decoder_level` 영구 저장) — 배선=사용자/Codex, 리뷰=Claude

**소유 모듈:** `plaza_save_store`(영구 원장, 컨티뉴 보석과 동거). 새 키 `decoder_level: int`(기본 0).
S1 구현은 `SAVE_SCHEMA_VERSION = 6`으로 올려 v5/구세이브 로드 시 `decoder_level = 0`을 쓰는 정규화 저장을 유도한다.

**헬퍼(이름 고정):**
- `get_decoder_level() -> int` — clamp 0~5.
- `unlock_decoder_level(level: int) -> bool` — `max(현재, clamp(level,0,5))`로 **monotonic 상승**,
  값이 변하면 저장 + true 반환. **절대 낮추지 않음.**
- `LingpetDecoder.decode_pct_for_level(level: int) -> int` (순수) = `clampi(level*20, 0, 100)`.
- 게임플레이엔 raw setter 노출 금지(테스트 전용 훅/clear만).

**마일스톤 훅:** 스테이지 클리어 / 첫 부화 지점에서 `unlock_decoder_level(N)` 호출(§4.1 래더).
어느 지점이 어느 N인지는 **매핑 1곳**에 모아 둠(스키마 불변).

**스모크 계약(`decoder_level_store_smoke.gd`, 반증검증 필수):**
1. 기본값 0 + 저장/로드 라운드트립 보존(plaza_save_store 스키마에 키 선언 → 구세이브는 0 디폴트).
2. `unlock_decoder_level` **monotonic**: 3 올린 뒤 2 호출 → 3 유지(반증: 일반 setter면 2로 내려가 FAIL).
3. clamp: 음수/6+ 입력 → 0~5.
4. `decode_pct_for_level` = {0,20,40,60,80,100}.
5. 새 플레이스루 골드/AP 리셋은 `decoder_level`을 유지한다(`clear()`만 전체 초기화).

**트랩:**
- **단일 권위:** 해석률을 읽는 모든 곳(해석기/도감/HUD)은 `get_decoder_level()` 한 소스.
  **런 `ring_core_tier` 절대 혼용 금지.**
- **스키마/마이그레이션:** plaza_save_store에 키 추가 시 구세이브 로드가 0으로 디폴트되도록 선언
  (Owner-Field Schema / BOM·스키마 함정 정신). 누락 시 set이 조용히 실패하거나 로드 시 사라짐.
- **monotonic / 영구:** 라운드·런 리셋 경로가 `decoder_level`을 건드리면 안 됨(영구값) — 런 리셋과 분리 확인.

## 6.2 S1.5 배선 계약 (마일스톤 훅: 클리어/부화 → `decoder_level`) — 배선=사용자/Codex, 리뷰=Claude

**왜 먼저:** S1은 저장 계층뿐 — 인게임에서 레벨이 오르는 경로가 없으면 S2 reveal이 테스트값으로만 도는
"예쁜데 안 사는" 계층이 된다.

**확정 앵커(코드):** 스테이지 클리어는 `stage_clear_result_screen._apply_stage_clear_progress_once()`
→ `plaza_save_store.apply_stage_clear_progress(stage_id, gold, grant_ap)`([plaza_save_store.gd:253])로
**단일 funnel**. `stage_id` = 방금 클리어한 스테이지(AP 키와 동일 의미). 결과 스크린이 `_plaza_save_store`
인스턴스 보유.

**기본(권장) — 단일 훅:** `apply_stage_clear_progress` 본문(AP 블록 다음)에 한 줄 —
`unlock_decoder_level(clampi(stage_id, 1, MAX_DECODER_LEVEL))`
- Stage1→Lv1, Stage2→Lv2 … Stage5→Lv5, Stage6→Lv5(clamp, no-op). 사용자 래더(Stage2~5→Lv2~5)를
  정확히 충족 + **Lv1은 스테이지1 클리어에서 안전 보장**(튜토리얼이 그 전에 첫 링펫을 주므로 "첫 유대→첫 이해"로 읽힘).
- **monotonic-max가 중복/역순을 자동 처리** → per-stage "이미 지급" 트래킹 불필요(AP식 `_awarded_stages` 흉내 금지).
- `unlock_decoder_level`은 값이 변할 때 자체 `save()` → 기존 gold/AP save-gating은 그대로 둔다.

**옵션 — 부화 순간 Lv1(문자 그대로):** "첫 알 부화 즉시"를 원하면 부화 finalize
(`lingpet_egg_runtime`의 `hit_result.hatched` ~line 1134)에 `unlock_decoder_level(1)`. **단 그 지점은
현재 plaza_save_store 핸들이 없음** → 스토어/콜백 스레딩 필요(침습적). 이득(같은 20%·한 스테이지 빠름)
대비 배선비가 커서 **비권장**. 스토리 비트가 꼭 필요하면 스토어 접근 가능한 다음 체크포인트에서
`lingpet_collection_state.find_first_owned_pet_id(owner)` 게이트로.

**스모크 계약(`decoder_level_store_smoke.gd` 확장 또는 `decoder_milestone_smoke.gd`, 반증검증 필수):**
1. **래더:** 새 세이브에서 stage 2 클리어 → Lv2 · stage 5 → Lv5 · stage 6 → Lv5(clamp).
2. **중복 클리어:** stage 3 두 번 → Lv3 유지.
3. **역순:** stage 5 클리어 후 stage 2 클리어 → Lv5 유지(역행 안 함).
4. **새 플레이스루:** 클리어로 Lv4 → `reset_gold_and_ap_for_new_playthrough()` → Lv4 유지.
5. **반증:** 훅을 monotonic이 아닌 plain set으로 바꾸면 2·3이 FAIL(역순/중복이 레벨을 내림)을
   in-place 토글로 먼저 확인.

**트랩:**
- 훅은 **store 단일 funnel**(`apply_stage_clear_progress`)에. 결과 스크린의 3개 호출처
  (`stage_clear_result_screen.gd` 779/797/865)에 흩뿌리지 말 것(누락 위험).
- `clampi(stage_id, 1, MAX_DECODER_LEVEL)`로 스테이지6+ 오버플로 차단.
- decoder 마일스톤은 **monotonic에 위임** — 별도 awarded-tracking 추가 금지.
- 비-클리어 경로에서 decoder 레벨을 올리지 말 것(funnel은 진짜 클리어에서만 호출됨 — 그대로 유지).

## 6.3 S2 배선 계약 (언어 데이터 + `reveal()` 순수함수) — 배선=사용자/Codex, 리뷰=Claude

**범위:** 데이터 모듈 + `reveal()` 순수함수 + 비율/결정론 스모크. **렌더(세그먼트→화면)는 S3,
ko 문자열 해석(translate)은 S3/S5.** S2의 `reveal`은 **i18n 키만 내보내고 문자열을 해석하지 않는다**
(순수성·결정론·테스트 용이).

**데이터 모듈:** `lingpet_language_catalog.gd`(RefCounted, 정적 데이터 + 조회). `lingpet.language.<pet>.<line>` 엔트리:
```
{
  id, speaker, emotion,                      # emotion: warm/calm/urgent/sad/curious
  glyph_text = "komotha tu pala=ta=ne",      # 미해석 전체 표시(Lingpet Script 폰트, S3)
  tokens = [ {key, glyph, tier, kind}, … ]   # kind: root/verb/noun/particle/loop/emotion
}
```
- 토큰 `tier` 1~5는 §4.2대로 **공개 순서**. 한 줄의 토큰 tier를 분포시켜 누적 공개율 ≈ 20×N%.
  (5토큰 = tier당 1개가 기본형. 감정/별 토큰 = tier 5 → 마지막에 점등.)
- 최소 1~2개 샘플 라인(예: maribo `greet_arrive`)만 있어도 S2 충족(대량 콘텐츠는 후속).

**`reveal(line, decoder_level) -> Array` (순수, `lingpet_decoder.gd`에 추가):**
- 각 토큰: `tier <= decoder_level` → `{kind="ko", key, decoded=true, tier, token_kind, emotion}` ;
  아니면 → `{kind="glyph", text=glyph, decoded=false, tier, token_kind}`.
- **LanguageSettings 호출 금지**(키만 반환). 레벨은 인자로만(내부에서 `get_decoder_level` 읽지 말 것 — 순수).
- 감정/별 토큰(kind="emotion", tier 5)은 레벨5에서만 decoded → S3가 점등.

**스모크(`lingpet_reveal_smoke.gd`, 반증검증 필수):**
1. **tier 게이트(정밀):** 토큰 tier T는 `level>=T`일 때만 decoded(`<=` 경계). 모든 level×token 조합 단언.
2. **단조 공개:** level L의 decoded 집합 ⊆ level L+1(올릴수록 공개만, 가려지지 않음).
3. **경계:** level0 = 전부 glyph(decoded 0) · level5 = 전부 decoded.
4. **결정론:** `reveal(line, L)` 두 번 호출 == 동일 배열(랜덤/순서 흔들림 0).
5. **저작 비율:** 각 샘플 라인 decoded 비율 ≈ 20×L% (허용오차 ±1토큰) — tier 분포 저작 검증.
6. **반증:** 게이트를 `>`로(또는 토큰 순서 셔플) 바꾸면 1·2·5 FAIL을 in-place 토글로 먼저 확인.

**트랩:**
- `reveal()`는 **순수**(LanguageSettings/`get_decoder_level` 호출 금지, 레벨=인자). 호출처가 `get_decoder_level()`를 넘김(단일 권위).
- tier 게이트는 `<=`(off-by-one 주의).
- **ko 문자열을 reveal에서 미리 해석 금지** — 키만. `translate(key)`는 S3/S5(raw ko 금지 규칙 §4.2 유지).
- 토큰 `key`는 `lingpet.language.*` 네임스페이스; 언어 테이블 등록은 S5.

## 7. (이전 검토에서) 무효화된 항목
- ❌ "링코어 = 계정 공용 영구 파츠" — **틀림**. v5는 런 단위(§4.1). 영구 게이트는 `decoder_level`.
- ❌ 데이터에 raw `ko` 문자열 + `translate_text()` — i18n 규칙 위반(§4.2).
- ❌ `draw_string_cached` 단독 렌더 — 토큰 색/혼합 불가(§4.3).
- ❌ "완전 표의문자(글리프=개념)" 전면 채택 — 알파벳형 + 특수시길로 확정, 표의는 고유명사/코어기억 한정.

## 8. 검증된 코드 앵커 (2026-06-22)
- 링코어 런 단위: `lingpet_affinity_store.gd:73, 192-203` (meta-only no-op) /
  `lingpet_affinity_state.gd:142, 152` (`_run_ring_core_tier`가 `reset_for_new_run`에서 0).
- i18n 규칙: `untranslated_surface_i18n_design.md:40` / `language_settings.gd` `translate(stable_key)`.
- 렌더 캐시 한계(단일 문자열/색): `character_info_overlay_text_line_cache.gd:43`.
- 영구 원장: `plaza_save_store` (컨티뉴 보석 영구 저장처).
- 플라자 NPC 호스트: `plaza_scene.gd:68-86` ("링펫 사육사 링링" + speech rect).
- 폰트 v1: `d:\tmp\lingpet_font\LingpetScript-Regular.ttf` (+ 빌더 `d:\tmp\build_lingpet_font.py`).

## 9. 잔여 결정 / 후속
- ✅ **상승 경로 = 스토리/수집 마일스톤 중심**(골드 구매 비채택, 보조만). §4.1.
- ✅ **플레이어 명칭 = 링펫어 해석기 레벨** (EN Lingpet Decoder Level).
- ✅ **완전 표의 시길 = 희귀 연출 전용**(코어기억/고유명사/금기어/제니스). §2.
- 기본 마일스톤 래더 세부(어떤 스테이지/수집이 어느 레벨)는 조정 가능 — 스키마 불변.
- 완전 표의 시길 실제 후보 목록(코어 기억/고유명사) — 콘텐츠 작성 시.
- TTF repo 경로/family 최종 + 글리프 미세조정(`m` 격자 등).
- (옵션) 런 링코어 높을 때 일시 +reveal 보너스 여부.
