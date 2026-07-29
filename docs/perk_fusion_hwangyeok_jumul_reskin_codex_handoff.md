# 퍽 융합 합일 모달 → 환격전 주물 의식(鑄物儀式) 리스킨 — Codex 핸드오프

작성: 2026-07-29 (Claude 아트디렉션). 실행 주체: Codex (imagegen/AutoSprite 생성 +
누끼 + repo 배치 + 팔레트 배선 + 검증 — `docs/skill_vfx_workflow.md` 분담 기준).

## 0. 배경 / 사용자 확정 사항

- 사용자 확정 (2026-07-29): 합일 연출 중심 은유 = **주물 의식**, 리스킨 범위 =
  **합일 모달 전체** (시네마틱 + 재료 선택 / 확인 / 결과 리빌 크롬).
- 문제 진단: 문구는 이미 무협 리브랜딩 완료("무공 합일", "이치를 하나로",
  `perk_fusion_localization.gd`)인데 비주얼은 SF 콜드부트(룬 섀시·카트리지·
  POST 게이지·시안 테크 글로우) 그대로 — 환격전 방향(옻칠·놋쇠·단청·먹선)과
  정면 충돌.
- 이 문서는 `docs/perk_fusion_cold_boot_cinematic_plan.md`의 §1 컨셉 락
  ("디스크하츠 카트리지" 은유 — 구 브랜드 앵커)과 §2 팔레트, §5 에셋 매니페스트를
  **환격전 방향으로 대체**한다. §3 스토리보드 비트 구조·길이, §4 티어 차등
  원칙(리컬러 금지·거동 차등), §7 런타임 계약, B5 핸드오프 공식(호스트는 reveal
  진입과 동시에 닫힘)은 **그대로 유지**한다.
- 코드/레포 내부 식별자(`cold_boot_*` 파일명·상수·비트명·프리셋명)는 리브랜딩
  방침대로 **유지**. 파일 리네임·상수 리네임 금지.
- 유저-대면 문구 전환("확정된 결과를 계산하고 있습니다" 등 기술 어휘의 무협화 +
  7언어 동기화)은 사용자가 이번 범위에서 제외 — §9 비스코프.

## 1. 리스킨 컨셉 (아트디렉션 확정)

**주물 의식**: 대성한 두 무공의 이치가 각인된 **무공패(牌)** 2기가 **진법
화로**(단청 진법판 + 옻칠 도가니 제단)에 안치되고, 화로 아가리가 태극 회전으로
봉인된 뒤 숯불이 차오르며, 쇳물 크레스트에서 두 패가 녹아 하나로 합쳐져 **금박
각인된 새 무공패**로 주조되어 나온다. 도박 결과 = **주물이 어떻게 식는가**:
정순한 완성(성공) / 균열·그을음(부작용) / 서기(瑞氣) 어린 명품(부산물).

- **재질 언어 = 기확정 환격전 HUD 세트와 동일 세트로 읽혀야 한다**: 옻칠 흑갈 +
  놋쇠/청동 림 + 단청 문양 밴드 + 먹선 윤곽 + 매듭(노리개) 악센트. 기준 시각
  레퍼런스 = `dash_token_frame_imagegen_v3.png` / 공유 기력 링 /
  `skill_orb_frame_imagegen_v2.png` (`docs/dash_token_hwaljubangul_hud_reskin_codex_handoff.md`
  §1 재질 정의 참조).
- **발광 문법은 유지하되 재질 번역**: "회로/룬 인레이 점등" → "화로 내부광·부적
  인광 점등". 결과 신호 문법 3색은 색상대를 크게 이탈하지 않게 번역해 기존
  신호 학습을 보존한다 — 시안(동기화)→**청염(靑焰)/옥빛** (도깨비불 계열 청록),
  골드(각성)→**놋쇠·금박·서기**, 적(과부하)→**주사(朱砂) 적**.
- 룬 각인 링 → **부적 먹선 인장 문양 링**. 실존 한자 문장·실존 부적 도상을 그대로
  쓰지 말고 창작 인장/전서풍 기하 문양으로 한 단계 번역(리브랜딩 수위 정책).
- 티어 차등은 기존 계약 그대로 **데이터 구동 거동 차등**: stutter=숯불 명멸,
  overshoot=금박 넘침 2차 링, surge=쇳물 튐(주사 번짐), fault=균열/그을음,
  byproduct=서기 장식 전개. 리컬러로 때우지 않는다.

## 2. 현행 구조 (2026-07-29 실측)

| 소유자 | 역할 | 리스킨 접점 |
|---|---|---|
| `godot/scripts/hud/perk_fusion_cold_boot_cinematic.gd` | 시네마틱 Node2D 호스트. 텍스처 우선 + 절차 드로 degraded 폴백 | 에셋 9종 교체 + 폴백 팔레트 상수(54~58행) |
| `godot/scripts/characters/perk_fusion_cold_boot_timeline_state.gd` | 비트 타임라인 (B0 0.5 / B1 0.4 / B2 0.9 / B3 0.25 / B4 0.7s) | **무접촉** — 타이밍 유지 |
| `godot/scripts/characters/perk_fusion_cold_boot_presentation.gd` | 티어→presentation plan (데이터 구동 tell) | **무접촉** |
| `godot/scripts/hud/perk_fusion_cold_boot_particle_factory.gd` | 벤트 스파크 / 골드 샤워 GPU 파티클 | 램프가 이미 웜톤(백열→주황→잔불 / 금가루) — **무접촉이 기본**, 픽셀 QA에서만 미세조정 |
| `godot/scripts/hud/perk_fusion_overlay_renderer.gd` | 모달 셸 + 선택/확인/리빌 크롬 + 연출 폴백 (전부 절차 드로) | 팔레트 상수(21~26행) + inline 색 스윕 (§6) |
| `godot/assets/sprites/effects/perk_fusion_cold_boot/` | 텍스처 9종 (아래 §5) | 전량 교체 |

시네마틱 에셋 소비 계약 (교체 시 지켜야 하는 실측값):

- 섀시 드로 스팬 = `(CHASSIS_RADIUS 132 + 10) * 2 = 284px` 정사각 박스, 원형
  실루엣.
- 카트리지(무공패) 드로 높이 96px, 도킹 위치 = 중심 ±46px. 페이스 플레이트
  중심 frac 상수 = `x 0.442`(우측 미러 1-x) / `y 0.510`, 아이콘 스팬 32px —
  **아트가 바뀌면 반드시 재실측 후 상수 갱신** (§7).
- `chassis_on`은 열 아지랑이 레이어(WritheEmberMaterial, 프리셋
  `cold_boot_ignition_haze[_surge]`)의 소스 텍스처로 **재사용**된다 — 점등판
  내부광이 실제로 밝아야 쉬머가 산다.
- 이그니션 시트 = 4x4 = 16프레임, `draw_texture_rect_region` 픽셀 rect 소비.
  진행도→프레임 원샷 재생(루프 아님).
- 모듈 3종은 `MODULE_DEPLOY_SPECS`가 폭(88/58/66px)만 고정하고 세로는 텍스처
  종횡비로 계산 — 종횡비 자유.

## 3. 비트별 번역표 (구조·타이밍 유지, 그림만 교체)

| 비트 | 현행 (SF) | 주물 의식 번역 |
|---|---|---|
| B0 DOCK_IN (0.5s) | 카트리지 2기 레일 활주 | 무공패 2기가 좌우에서 화로 제단 받침으로 활주 (각 패 페이스에 자기 무공 아이콘 유지 — 정체성 연속 계약 그대로) |
| B1 TWIST_LOCK (0.4s) | 링 칼라 회전-스냅 | 화로 태극 아가리 회전-체결 (거푸집 봉인, 둔중한 쇠 물림) |
| B2 BOOT_POST (0.9s) | POST 세그먼트 게이지 | 풀무 게이지: 화로 둘레 단청 문양 세그먼트 16개가 순차 점화. stutter=앰버→주사 명멸, overshoot=금박 2차 링 (기존 분기 코드 그대로) |
| B3 IGNITION_CREST (0.25s) | 이그니션 링 펄스 + 아지랑이 | 쇳물 크레스트: 용융 광륜 방사 (16f 시트 교체) + 열 아지랑이 재활용. surge=주사 번짐, dual gold=금물 2차 광륜, stabilizer=청염 안정 코일 |
| B4 REVEAL (0.7s) | 통합 코어 + 골드 모듈 전개 | 새 무공패 안착 + 대각 합성 융합 아이콘(계약 유지). 부산물=서기 장식(방울·매듭 노리개·옥패) 스태거 전개, 결함=균열 세그먼트·그을음 베이 |
| B5 SETTLE | 모달 리빌 패널 소유 | **변경 없음** |

전이 촉감 펄스(CHNK 시각 앵커 아크)와 파티클 발화 조건(데이터 구동)은 유지 —
색만 §4 번역을 따른다.

## 4. 팔레트 번역 (신호 문법 보존)

교체 대상 상수 (1차 소스). 최종 수치는 픽셀 QA에서 미세조정하되 역할-색상
매핑은 고정:

| 역할 | 현행 | 번역안 | 위치 |
|---|---|---|---|
| 동기화/진행 악센트 | 시안 `(0.32, 0.86, 1.0)` | 청염 옥빛 `(0.30, 0.84, 0.74)` | cinematic `ACCENT_COLOR`:54, overlay `ACCENT_COLOR`:24 |
| 각성/잭팟 | 골드 `(1.0, 0.79, 0.27)` | **유지** (이미 놋쇠 금) | 양쪽 `GOLD_COLOR` |
| 결함/과부하 | 핑크 적 `(1.0, 0.48, 0.48)` | 주사 적 `(0.90, 0.32, 0.22)` | cinematic `FAULT_COLOR`:56, overlay `_draw_probabilities` side_color:171, irreversible 텍스트:155 |
| 안정화 세이브 | 시안-청 `(0.45, 0.90, 1.0)` | 밝은 청염 `(0.52, 0.92, 0.82)` | cinematic `CORE_STABLE_COLOR`:57, overlay:171 |
| 섀시/심연 바탕 | 네이비 `(0.01, 0.015, 0.035)` | 옻칠 흑갈 `(0.022, 0.014, 0.009)` | cinematic `CHASSIS_COLOR`:58, overlay `BACKDROP_COLOR`:21 |
| 모달 패널 | 남색 `(0.055, 0.07, 0.12)` | 옻칠 갈흑 `(0.085, 0.062, 0.042)` | overlay `PANEL_COLOR`:22 |
| 패널 보더 | 하늘 `(0.36, 0.73, 1.0)` | 놋쇠 헤어라인 `(0.80, 0.63, 0.31)` | overlay `PANEL_BORDER_COLOR`:23 |
| 보조 텍스트 | 한랭 회청 `(0.68, 0.76, 0.88)` | 한지 모래빛 `(0.84, 0.78, 0.66)` | overlay `MUTED_COLOR`:26 |
| 확률 success | 민트 `(0.39, 0.92, 0.73)` | 청염 계열로 통일 `(0.34, 0.86, 0.70)` | overlay:172 |

inline 스윕 대상 (상수 밖 하드코딩 — 같은 커밋에서 함께 전환):
overlay 70행(패널 외곽 글로우 남색), 261~262·322~323·345행(아이콘 암판 남색 —
옻칠 흑갈로), 311~312행(카드 배경/보더 남색군), 393~397행(버튼 fill/border
남색군 — 옻칠 바탕 + 놋쇠/청염 보더), 404행(헤딩 하늘빛 → 한지 백금),
487~488행(아이콘 폴백 시안 원 → 청염), cinematic 373행(폴백 림 시안).

## 5. 에셋 목록 + 생성 스펙 (9종, 동일 경로 교체 랜딩)

**같은 파일 경로에 교체 랜딩한다** — 시네마틱의 경로 상수·프리웜 매니페스트가
그대로라 배선 변경이 0이다. 구판 롤백 레퍼런스는 git 이력(커밋된 상태)이
담당하므로 시블링 사본 불필요. 마젠타 소스/누끼 중간물은 `images/` 보관 관례를
따른다.

**⚠️ 크로마키는 마젠타 `#ff00ff` 필수** (단청 녹·청록이 팔레트에 들어감 —
그린 키 despill 사고 위험. `chroma_key.py <src> <dst> --key magenta`).
**⚠️ Gemini 세션 트랩**: 반복 작업은 1536/1024로, 2048은 단발.

### 5.1 imagegen 정지 크롬 8종

공통: 정면 뷰, 넉넉한 투명 마진, 알파 bbox 에지 비접촉, 먹선 윤곽. 소스
512~1024px(원형 섀시는 1024 권장), 런타임 스팬은 §2 실측값이 소화.

1. **`cold_boot_chassis_off.png`** — 꺼진 진법 화로: 원형 옻칠 흑갈 제단 +
   놋쇠 이중 림 + **미점등 부적 먹선 인장 문양 링**(음각·어두움) + 4방위 매듭
   악센트 + 중앙에 무공패 2기가 안착할 베이 2칸(세로 홈). 회전 요소는 없으니
   방사 대칭 강제는 아니나 상하 정위는 유지.
2. **`cold_boot_chassis_on.png`** — 같은 구도 점등판: 화로 심부 숯불 내부광
   (주황-금), 인장 문양 링이 청염 인광으로 점등, 단청 밴드 채도 상승. 아지랑이
   소스 겸용이므로 내부광 영역이 실제로 밝을 것.
3. **`cold_boot_cartridge_left.png` / `_right.png`** — 무공패 좌/우(미러 쌍):
   세로 놋쇠+옻칠 패(牌), 상단 매듭 고리, 단청 테두리, 중앙에 아이콘이 앉을
   **무지 암판 페이스 플레이트**(32px 아이콘 안착 자리 — 문양 넣지 말 것).
   수락 후 플레이트 중심 frac 실측 필수 (§7).
4. **`cold_boot_module_shoulder_pod.png`** — 서기 장식 1: 청동 무령 방울
   (활주방울 상단 장식과 동족 실루엣 — 둥근 몸통+울림 구멍+고리).
5. **`cold_boot_module_collar_ring.png`** — 서기 장식 2: 매듭 노리개 (술 짧게,
   축소 뭉갬 금지).
6. **`cold_boot_module_gem_plate.png`** — 서기 장식 3: 옥 패 (놋쇠 받침 + 청옥
   코어 — 기력 청옥 노리개와 동족).
7. **`cold_boot_spark_shard.png`** — 대장간 불똥 샤드 (작은 웜톤 파편 — 현행이
   이미 유사하면 교체 생략 가능, 픽셀 QA에서 판단).

프롬프트 골격 (섀시 예 — 나머지는 소재만 치환):

```text
Create a circular Korean mythic-martial ritual crucible altar for a game
cinematic, top-lit front view, on a perfectly flat solid #ff00ff
chroma-key background.

Dark lacquered brown-black wooden/bronze altar disc, double polished
brass rims, a ring band of unlit invented seal-script talisman engravings
(dark recessed ink lines, not real Chinese text), dancheong-style
geometric accents in muted red / deep teal / gold with thin black ink
outlines, four small knotted norigae ornaments at the cardinal points,
and two vertical empty docking recesses at the center where two metal
tablets will sit. Unlit, cold state.

No text, no characters, no scene background, no watermark. Background
exactly flat #ff00ff, no gradient. Do not use #ff00ff inside the art.
```

### 5.2 AutoSprite 시트 1종

8. **`cold_boot_ignition_ring_sheet.png`** — 쇳물 용융 광륜 16프레임
   (**AutoSprite MCP 필수** — 런타임 스킬-이펙트 시트 규정). 4x4 그리드
   락스텝 유지(`IGNITION_SHEET_COLS/ROWS` 상수와 일치 — atlas grid authority
   트랩). 내용: 도가니 중심에서 방사 확장하는 용융 청동 광륜 원샷 (놋쇠
   금-주황 주조색 + 청염 가장자리), 프레임 1→16 = 발생→확산→소산. 루프 아님.
   전 프레임 중심·스케일 안정, 셀 에지 비접촉 마진.

### 5.3 후처리 공통

- `py .claude/skills/sprite-generation/chroma_key.py <src> <dst.png> --key magenta`
- 검증: 알파 채널 / 네 모서리 투명 / 알파 bbox 에지 비접촉 / 마젠타 프린지
  없음(암·명 배경 양쪽).
- `--headless --import`로 `.png.import` + `.ctex` 실체화 후 PNG와 함께 커밋.

## 6. 모달 크롬 절차 드로 전환 (코드만, 신규 텍스처 없음)

- §4 팔레트 상수 + inline 스윕이 1차 전부다. 형상 변경은 최소: (선택) 패널
  네 모서리에 놋쇠 꺾쇠 헤어라인 4개(draw_line 8콜) 정도까지만 허용 — 모달은
  일시 화면이지만 절차 다층화로 과설계하지 않는다.
- 시네마틱 절차 폴백(텍스처 부재 분기)도 같은 상수를 읽으므로 자동 동반 전환
  — 폴백 전용 색이 남지 않게 §4 inline 목록 전수 확인.
- 카드/버튼/뱃지의 상태 문법(골드=선택, 악센트=하이라이트, 회색=비활성)은
  유지 — 색만 번역.

## 7. 함정 체크리스트 (기존 트랩 매핑)

- **카트리지 face plate frac 재실측**: 아트 교체 후
  `CARTRIDGE_PLATE_CENTER_X/Y_FRAC`·`CARTRIDGE_PLATE_ICON_SPAN`을 신 에셋
  실측으로 갱신하지 않으면 재료 아이콘이 패 문양 위에 떠 보인다. 갱신값을 이
  문서 §7.1에 추기할 것.
- **예약 에셋 re-stat**: 동일 경로 교체라 신규 경로 배선 없음. 단 에셋이
  레포에 실재하기 전에 코드 커밋을 선행하지 말 것 (아트+상수+씰 같은 슬라이스).
- **atlas grid authority**: AutoSprite 산출이 4x4가 아니면 재배치 후 랜딩.
  상수 변경 금지가 기본.
- **WritheEmberMaterial 공유 패밀리**: 프리셋 이름
  `cold_boot_ignition_haze[_surge]` 유지, 인라인 셰이더 신설 금지. 신 점등판
  아트에서 쉬머가 죽으면 프리셋 uniforms만 튜닝.
- **draw_polygon UV 정규화 / draw_set_transform**: 모듈 회전 quad 기존 코드
  무접촉이 정상 — 아트만 교체.
- **비헤드리스 QA 임포트 실체화** (스테일 RED), **공허-GREEN**(표준 러너
  `run_smoke_tests.ps1` 관통), **헝크분리 커밋**(외래 WIP 다수 — 이 슬라이스
  파일만).

### 7.1 무공패 face plate 최종 실측 (2026-07-29 Codex 실행)

- 최종 좌/우 소스: `742x1024`, 동일 원본의 셀 단위 수평 미러 쌍.
- 무지 암판 안전영역 frac: `Rect2(0.247, 0.323, 0.506, 0.503)`.
- 적용 상수: `CARTRIDGE_PLATE_CENTER_X_FRAC = 0.500`,
  `CARTRIDGE_PLATE_CENTER_Y_FRAC = 0.587`, `CARTRIDGE_PLATE_ICON_SPAN = 32.0`.
- `CARTRIDGE_DRAW_HEIGHT = 96.0`에서 32px 아이콘 rect가 좌/우 모두 위
  안전영역 안에 들어감을 `perk_fusion_cold_boot_cinematic_smoke.gd`가 봉인한다.
- 실측 오버레이 아카이브:
  `images/perk_fusion_hwangyeok_jumul_reskin/qa/cartridge_plate_probe.png`.

## 8. 검증 / 씰

- 기존 스모크 GREEN 유지: `perk_fusion_cold_boot_cinematic_smoke`,
  `_cold_boot_presentation_smoke`, `_cold_boot_timeline_smoke`,
  `perk_fusion_overlay_renderer_smoke`, `perk_fusion_modal_flow/input_smoke`,
  `perk_fusion_icon_runtime_smoke`, `perk_fusion_result_icon_prepare_smoke`.
- 갱신형 씰: face plate frac 상수가 신 에셋 실측과 동기인지(아이콘 rect가
  플레이트 rect 안인지)를 cinematic 스모크에 1레그 추가.
- `run_headless_load_check.ps1` + `run_warning_scan.ps1`.
- **픽셀 QA (사인오프 필수)**: ① 4페이즈(선택/확인/연출/리빌) 전부 신규 팔레트
  ② 티어 4종(success/stable/side_effect/byproduct) 연출 각 1회 — 데이터 구동
  tell(명멸·금박 링·주사 번짐·서기 전개)이 새 아트에서 읽히는지 ③ 텍스처 부재
  폴백 강제 1회(임시 리네임) — 절차 폴백도 환격전 팔레트인지 ④ 스킵 경로
  ⑤ 같은 화면의 기확정 환격전 HUD(활주방울 다이얼·초식 소켓)와 재질 언어
  통일 읽기 확인. 교체 전/후 비교 스크린샷 1세트 아카이브.
- §10 업그레이드 슬라이스 실행 시 §10.3 QA 항목을 위 목록에 병합.

## 9. 명시적 비스코프 (후속 트랙)

1. **문구 무협화**: "확정된 결과를 계산하고 있습니다" 등 기술 어휘 → 무협
   어휘("이치를 벼리고 있습니다" 류) + 7언어 동기화. 사용자가 이번 범위에서
   제외 — 별도 슬라이스.
2. **SFX**: CHNK/THUNK → 쇠 물림·망치질·방울 울림 원샷 (이름-연출-사운드
   삼위일치). 포지셔널 패닝 정책 준수.
3. **리빌 패널 텍스처 프레임화**: 절차 유지가 이번 기본. 이후 필요 시
   ui-hud-generation 트랙.
4. **융합 아이콘 스타일**: 대각 합성 계약(`prepare_fusion_pair_icon`) 무접촉.

## 10. 프리미엄 업그레이드 슬라이스 (2026-07-29 사용자 승인 — "8점" 목표)

배경: 기본 리스킨(§1~§8, Codex 랜딩 `deb6e31cc`)은 재질·정체성·팔레트 축을
회수한다. 정지 프레임 채점에서 남은 감점 축 = **구도 여백**(빈 패널에 기물
하나 — 설계된 여백이 아님)과 **타이포/헤딩**(장식 없는 시스템 다이얼로그급
텍스트). 이 섹션이 그 두 축을 올린다. 목표 = 연출 화면 8/10, 모달 크롬 7/10.
기물 추가·다층 발광으로 채우는 방향은 금지 — 두 항목 모두 "조용한 바탕"이
원칙이다.

### 10.1 제단 바닥 진법 백플레이트 (신규 에셋 1종 + 배선)

- 파일: `godot/assets/sprites/effects/perk_fusion_cold_boot/cold_boot_altar_backplate.png`
  — **이 트랙에서 유일하게 새 배선이 생기는 항목** (§5의 9종은 동일 경로
  교체였음).
- 내용: 화로 뒤에 깔리는 대형 저채도 진법 원판 — 먹선 동심원 2~3중 +
  전서풍 창작 인장 문양 밴드(실존 한자 금지) + 8방위 방사 괘선, 옻칠 흑갈
  바탕. 화로 스팬(284px)의 ~1.8배인 **~520px**로 그려 "기물 하나 떠 있는
  빈 판"을 "설계된 제단"으로 바꾼다.
- **톤 규율 (합격 기준)**: 저채도·저대비 필수 — 중앙 기물(화로·무공패·융합
  아이콘)보다 시각 무게가 커지면 실패. 런타임 알파 0.22~0.35 밴드.
- 생성: imagegen 소스 1024, 마젠타 크로마, §5.3 후처리 공통 동일. 프롬프트
  골격:

```text
Create a large circular Korean mythic ritual formation floor plate
(altar backplate) for a game cinematic, viewed straight from the front,
on a perfectly flat solid #ff00ff chroma-key background.

Very dark lacquered brown-black disc with subdued thin brass concentric
rings, a faint band of invented seal-script talisman glyphs (dark
recessed ink lines, NOT real Chinese text), and eight thin radial rule
lines toward the cardinal and intercardinal points. Low saturation, low
contrast, quiet and flat — this sits BEHIND a brighter crucible
centerpiece and must never compete with it. No bright highlights, no
glow, no metallic shine.

No text, no characters, no scene, no watermark. Background exactly flat
#ff00ff. Do not use #ff00ff inside the art.
```

- 배선 (`perk_fusion_cold_boot_cinematic.gd`):
  - prewarm manifest에 `altar_backplate` 키 추가 — 기존 file_exists 게이트
    패턴 그대로 (부재 시 해당 조각 미표시, per-frame re-stat 없음).
  - `_draw_chassis` 직전에 정적 `draw_texture_rect` 1콜. **회전·스케일
    펄스·elapsed 트윈 금지** — CB4c-3에서 실측한 차분 검출기 베이스라인
    오염(잔광이 s12 SNAP 차분 46→276px 오염) 재발 방지. 시각 변화는 비트
    스냅샷 기반 알파 2단만 허용: 꺼짐(B0~B1) 0.22 → 점등(B2~) 0.32.
  - 절차 폴백: 텍스처 부재 시 먹선 동심원 `draw_arc` 2~3콜 (§4 팔레트 상수).
- 씰: cinematic 스모크에 backplate 유/무 양쪽 draw 무크래시 + 점등 전/후
  알파 2단 레그. 아트+배선+씰 같은 슬라이스 (경로 선배선 커밋 금지).

### 10.2 헤딩 장식 + 타이포 위계 (overlay renderer 절차 드로만, 신규 텍스처 없음)

`_draw_heading` 업그레이드 — 4페이즈 공통 적용:

1. **좌우 괘선**: 타이틀 양옆 놋쇠 헤어라인(중앙→바깥 알파 페이드, draw_line
   세그먼트 2~3개씩). 배치는 하드코딩 오프셋 금지 —
   `font.get_string_size` **실측 타이틀 폭 기준**으로 좌우 시작점을 잡는다
   (7언어 최장 타이틀에서 겹침 없어야 함).
2. **낙관(落款) 스탬프**: 타이틀 우측 소형 주사 적 방형 인장 — draw_rect
   프레임 + 내부 추상 획 2~3개 절차 드로. 실존 한자 금지, **유니코드 장식
   문자(✦류) 금지** — 한국어 폰트 스택 tofu 트랩 (CLAUDE.md 기재 실패 사례).
3. **타이틀 이중 드로 그림자**: 어두운 오프셋 1회 + 본 드로(§4 한지 백금
   톤). 발광/글로우 다층화 금지.

- 부제(subtitle)는 현행 유지 (크기·MUTED 톤).
- 예산: 추가 드로 콜 +15 이내. 모달 한정 화면이지만 §6 과설계 금지 규율 준수.
- 씰: `perk_fusion_overlay_renderer_smoke`의 기존 draw 관통 레그 무크래시
  유지. 시각 판정은 픽셀 QA 소유.

### 10.3 QA 추가 (§8 픽셀 QA 목록에 병합)

- ⑥ 백플레이트: 4티어 연출 + 스킵 + 폴백 강제에서 팝인/깜빡임 없음, 중앙
  기물 대비 시각 무게 열위 유지 (백플레이트가 먼저 눈에 들어오면 실패).
- ⑦ 헤딩 장식: 4페이즈 × 7언어 중 최장 타이틀(독일어권 주의)에서 괘선·낙관
  겹침 없음.
- ⑧ 재채점 게이트: 업그레이드 후 정지 프레임 재채점 — 연출 화면 8/10·모달
  크롬 7/10 미달 시 §10.1 알파/스팬·§10.2 장식 밀도부터 재조정 (기물 추가로
  채우지 말 것).

### 10.4 실행 종결 (2026-07-29 Codex)

- 구현 착지: `169f428ae12b6bb1333eebfddd2fcc47e6ff30b0`.
  `cold_boot_altar_backplate.png` 원본/후처리/임포트, prewarm 키,
  화로 전 520px 정적 드로, B0/B1 `0.22` → B2 이후 `0.32` 알파 2단,
  텍스처 부재 동심원 폴백을 함께 랜딩했다. 회전·트윈·스케일 펄스는 없다.
- 헤딩은 실측 타이틀 폭 기반 좌우 3세그먼트 괘선, 절차 낙관, 단일 그림자를
  `+11` 드로 콜로 추가했다. 7언어 x 8개 실제 제목 변형의 기하 비중첩과
  4페이즈 x 7언어 실렌더를 fail-closed 하니스에 편입했다.
- 검증: 관련 스모크 8종 GREEN, repo-local headless load PASS, touched GDScript
  경고 스캔 PASS. 전수 경고 스캔은 외래 Guardian Spirit WIP 테스트의 제거된
  링펫 상수 참조에서 중단되어 이번 경로와 분리 보고한다.
- 픽셀 QA 50장과 요약은
  `C:/Users/woduq/bosspong_backups/qa_evidence/perk_fusion_cold_boot_7613709_21328_79789b7ed94c/`,
  repo 비교판은 `images/perk_fusion_hwangyeok_jumul_reskin/qa/premium_upgrade_*.png`.
  재채점은 **연출 화면 8/10·모달 크롬 7/10**으로 목표 게이트를 충족했다.
