# 광장 건물·NPC "링피아 통일" 슬라이스 플랜 — 디스크하츠 - 링피아

작성 2026-07-02. 이 문서가 **광장 건물·NPC 링피아 통일 피벗의 단일 소스**다.
상위 SSOT는 `docs/plaza_port_plan.md`이며, 이 피벗은 그 문서의 "스테이지별 건물/NPC
재생성(6테마×7동)" 계획을 **폐기·대체**한다(§0.7·§0.5의 "건물 테마별 재생성" 대형
슬라이스 취소). 바닥·패럴랙스의 스테이지별 테마는 이 피벗의 범위가 **아니다** — 그대로
유지한다.

## 0. 결정 (사용자 확정 2026-07-02)

1. **건물 7종 + 인테리어 NPC 7종을 하나의 중립 "링피아" 아트로 통일한다.**
   스테이지별로 건물/NPC를 다르게 만드는 계획은 공식 폐기.
2. **아트 방식 = 새 중립 링피아 아트 재생성** (현 cyber_joseon 유지 아님). 홀로/VR
   사이버 허브 톤으로, 어떤 스테이지 바닥 위에도 어울리는 theme-neutral 세트.
3. **바닥·패럴랙스는 스테이지별 테마 유지** (cyber_joseon/jungle_relic/neon_city/…
   이미 배선됨, 손대지 않음). "어느 스테이지를 깼는지"는 바닥·하늘이 계속 표현한다.
4. **엠블럼 7종 + NPC 이름/역할/인사 7종은 전부 보존.** 아트만 리스킨.

설계 논리: 링피아 = 가상현실 세계. 건물·NPC는 스테이지와 무관하게 상주하는 **VR 허브
인프라**(상점은 상점, 은행은 은행)이므로 하나의 일관된 링피아 룩이어야 한다. 바닥 색은
스테이지마다 바뀌지만(정글 녹색·네온 핑크 등), 건물은 **팔레트가 안정적인 프랜차이즈
사이버 시그니처**(CYBER_CYAN `(0,0.90,1.0)` / CYBER_MAGENTA `(1.0,0.12,0.76)`)를 유지해
"바뀌는 바닥 위의 변하지 않는 허브"로 읽히게 한다.

## 1. 현 코드 상태 (통일이 왜 대형 리팩터가 아닌가)

- **건물·NPC는 이미 전 스테이지 공통이다.** `plaza_asset_loader.gd`의
  `BUILDING_MANIFEST_PATHS`(:77-83)와 `INTERIOR_NPC_TEXTURE_PATHS`(:23-30)가 전부
  `stage1_cyber_joseon` / `stage1_interior_*` 하드코딩. `build_building_specs(stage_id,…)`는
  stage_id를 **배치 RNG 시드**에만 쓰고 건물 아트 선택엔 안 쓴다. 스테이지별 건물/NPC는
  런타임에 배선된 적이 없다(계획만 존재했다).
- **스테이지별로 실제 갈리는 건 바닥/패럴랙스뿐이다.** `resolve_floor_texture_paths(stage_id)`가
  slug 매니페스트 오버라이드를 하고 없으면 stage1 fallback.
- **렌더는 100% 매니페스트/로더 간접참조 — 테마 하드코딩 0.** (§4 계약)
  - `_draw_building`(`plaza_scene.gd:1158-1183`): base/sign/window 3레이어를 spec dict에서
    받아 고정 alpha/color로 draw. `if theme == …` 없음, 한옥 전용 지오메트리 없음.
  - `_draw_npc`(`plaza_interior_view.gd:601-621`): `NPC_RECT = Rect2(26,118,236,500)` 상수 안에
    aspect-fit + bottom-align. 테마 조회 없음.

→ **통일 = ①새 중립 아트 생산 ②로더 상수/매니페스트 repoint ③구 cyber_joseon 건물/NPC
에셋 제거 ④스모크 경로 갱신 ⑤문서 락.** 렌더 코드 수정 불필요.

## 2. 아트 디렉션 브리프 (Claude → Codex 생산)

### 2.1 컨셉 — "링피아 OS가 인스턴스화한 VR 허브 파사드"

건물은 실제 세계의 건축이 아니라 **가상세계 OS가 렌더한 시설 유닛**처럼 보인다. 깨끗한
기하 볼륨 + 투사형 홀로 사인 + 데이터-글라스 창 + 사이버 트림. "매트릭스 로딩 존" /
"디지털 라운지" 무드. 3/4 정면 파사드(사이드뷰 거리 문법)는 현 문법 그대로 유지.

### 2.2 theme-neutral 규칙 (핵심 — 금지 목록)

이 세트의 존재 이유는 **어떤 스테이지 바닥 위에도 이질감 없이 얹히는 것**이다. 따라서:
- **실세계 문화 모티프 금지**: 한옥 기와/단청/처마, 정글 식생, 특정 국가·시대 건축, 사찰,
  중화 시장 간판 등 **stage 테마를 연상시키는 것 일절 금지.**
- 대신 **홀로/데이터 컨스트럭트 건축**: 모듈형 파드, 홀로-에미터 프레임, 발광 글라스,
  부유 패널, 얇은 네온 엣지 트림, 격자 데이터 텍스처.
- **팔레트 안정 규칙**: 베이스는 딥 인디고/차콜(광장 야경 먹남 계열), 네온은 시안+마젠타
  프랜차이즈 시그니처, 창 내부광은 웜(현 window color `(1.0,0.93,0.78)`). 바닥이 정글
  녹색이든 네온 핑크든 **건물 팔레트는 바뀌지 않는다** → 건물이 시각적 상수가 된다.
- 채도/명도 위계: 근경 건물 > 중경 담장 > 원경(기존 유지). 건물이 가장 선명.

### 2.3 엠블럼 사전 (보존 — 건물 1차 식별 장치)

간판은 텍스트가 아니라 **홀로 그림 엠블럼 푯말**(sign_emissive 레이어). 7종 모티프는
theme-invariant로 확정되어 있으니 **형태 그대로 링피아 홀로 스타일로만 리스킨**한다.
(출처: `docs/plaza_port_plan.md` §5.1 공통 엠블럼 사전 + 각 매니페스트 `identity_emblem`.)

| type | 한글 | 엠블럼 모티프 | display_height |
|---|---|---|---|
| shop | 상점 | 금화 + 아이템 상자/보따리 | 220 (낮은 파드) |
| tavern | 선술집 | 두루마리 의뢰서 + 컵/등롱 | 220 (낮은 파드) |
| gacha | 가챠샵 | 투명 캡슐 + 회전 화살표 | 250 (중간) |
| lingpet_store | 링펫스토어 | 빛나는 알 + 링 궤도 | 250 (중간) |
| bank | 은행 | 금화 더미 + 금고 문 | 280 (금고 블록) |
| blacksmith | 대장간 | 망치 + 모루 + 불꽃 | 300 (높은 구조) |
| academy | 아카데미 | 펼친 책 + 스킬 오브 + 교환 화살표 | 300 (높은 구조) |

- **실루엣은 기능별로 차별화**: 은행=견고한 볼트 블록, 선술집=아늑한 낮은 파드,
  대장간/아카데미=높은 타워형, 가챠/링펫=중간 라운지형. display_height 티어를 실루엣
  질량으로 뒷받침(수치는 재생성 불요, 소스만 그 비율감으로).
- 엠블럼은 밝은 홀로 색광 위계 1순위: **사인 > 창 > 바닥 회로**(플라자 시선 위계 계약).

### 2.4 NPC 디자인 언어 (이름/역할/인사 보존, 아트만 리스킨)

NPC는 **링피아 네이티브 VR 허브 운영자** — 한옥 복장이 아니라 테크웨어/홀로-유니폼 +
사이버 액센트. 각자 역할 소품을 든다. 이름·역할·인사말은 그대로 유지
(`plaza_scene.gd:68` `INTERIOR_NPC_NAMES` / `:78` `INTERIOR_GREETING_LINES`).

| type | 이름 | 역할 | 역할 소품(홀로) |
|---|---|---|---|
| shop | 모라 | 상점주인 | 아이템 홀로 크레이트 |
| bank | 도윤 | 은행원 | 금고/코인 홀로 |
| gacha | 루미 | 가챠 오퍼레이터 | 캡슐 |
| lingpet_store | 링링 | 링펫 사육사 | 공명 알 |
| blacksmith | 강철 | 대장장이 | 망치/포지 |
| tavern | 하랑 | 선술집 주인 | 의뢰 두루마리/잔 |
| academy | 서율 | 교관 | 책/스킬 오브 |

- 규격: **512×880 세로 포트레이트**, 마젠타 `#ff00ff` 크로마키 → `tools/chroma_key.py`
  누끼(visible_magenta=0, corner_alpha=0). 런타임 fit zone 224×418(`NPC_RECT` 안).
- 7명이 **하나의 스타일 락**(같은 광원·같은 라인웨이트·같은 사이버 유니폼 언어) — 캐릭터
  선택 시트처럼 정체성 일관. 개별 색상 액센트로만 구분.

### 2.5 생산 문법 (현 문법 재사용)

- **건물 본체 = imagegen 정적 생성**(Gemini, AutoSprite 금지 — CLAUDE.md 건물 규칙).
  sign_emissive/window_glow_mask = **2-edit 발광 분리**(sign-ON / window-ON 에디트를 base와
  diff → 발광 마스크 추출, 현 §5.3 문법 그대로). 간판 그림은 imagegen에 굽되 텍스트는 굽지 않음.
- **NPC = imagegen 포트레이트**(Gemini), 마젠타 크로마키 → chroma_key.py 누끼.
- 시트 계열(움직이는 부품 루프)이 필요하면 그때만 AutoSprite 경유(현 v1은 정적이라 불요).

## 3. 네이밍 / 코드 정리 슬라이스 (사용자·Codex 배선, Claude 게이트)

새 중립 slug = **`lingpia`** (권장). 파일명에서 `stage1`·`cyber_joseon`를 빼고 `lingpia`로.
`interior/` 디렉터리와 `_imagegen_v1` 접미사는 **유지**(스모크 assert 최소 변경). 기존 파일을
git mv 하는 게 아니라 **새 이름으로 신규 생성 → repoint → 구 파일 제거**(아트가 새로
만들어지므로).

### 3.1 신규 생산 → 구 제거 대상 (에셋)

| 대상 | 구(제거) | 신(생산) |
|---|---|---|
| 건물 매니페스트 ×7 | `plaza_stage1_cyber_joseon_<type>_v{1,2}_manifest.json` | `plaza_lingpia_<type>_v1_manifest.json` |
| 건물 레이어 PNG ×7×3 | `…_building_base / _sign_emissive / _window_glow_mask.png` | `plaza_lingpia_<type>_v1_<layer>.png` |
| 건물 소스 chromakey ×7×3 + lit_preview | `…_source_chromakey / _lit_preview.png` | `plaza_lingpia_<type>_v1_…` |
| NPC 포트레이트 ×7 | `plaza_stage1_interior_npc_<type>_<name>_imagegen_v1.png` (+`_magenta_source`) | `plaza_lingpia_interior_npc_<type>_<name>_imagegen_v1.png` |
| interior NPC set/QA 매니페스트 | `plaza_stage1_interior_npc_imagegen_v1_manifest.json` (theme:cyber_joseon), `…_qa.json` | `plaza_lingpia_interior_npc_imagegen_v1_manifest.json` (theme:lingpia), `…_qa.json` |

**제외(손대지 않음)**: 모든 바닥/패럴랙스 `plaza_stage1_floor_*` / `plaza_stage1_sidescroll_*`
(stage1 테마), `plaza_shop_strewn_*`(AutoSprite, 이미 중립 명명), 그리고
`stage_landing_intro.gd`의 `stage1_landing_zoom_background_cyber_joseon_*`(스테이지 랜딩 UI,
광장 무관).

### 3.2 코드 편집 지점

- `godot/scripts/plaza/plaza_asset_loader.gd`
  - `BUILDING_MANIFEST_PATHS`(:77-83) → 7개 `plaza_lingpia_<type>_v1_manifest.json` 경로.
  - `INTERIOR_NPC_TEXTURE_PATHS`(:23-30) → 7개 `plaza_lingpia_interior_npc_*` 경로.
  - `INTERIOR_ROOM_TEXTURE_PATHS`(:33-34) / `INTERIOR_OBJECT_TEXTURE_PATHS`(:37-40): §5 스코프
    노트 참조(shop 인테리어 방/오브젝트 = P2 선택).
- 매니페스트 내부 필드: `asset_id`, `stage_theme`(→`"lingpia"` 또는 필드 제거), `layers.*.res_path`,
  `source_layers.*.res_path`, `qa.preview_lit_res_path`를 신규 경로로. **레이어 스키마·필드 구성은
  그대로**(§4 계약) — 드롭인이어야 함.

### 3.3 매니페스트 신규 slug import 게이트 (Solar Bolt 교훈)

신규 PNG는 **Godot import(.import + .ctex remap)까지 완료**돼야 로더/스모크가 집는다.
`ProjectResourceLoader.texture_resource_exists()` 통과 확인 없이 커밋 금지. 반입 시 import
pass 필수.

## 4. 매니페스트 레이어 계약 (신규 아트가 반드시 만족)

`build_building_specs`(`plaza_asset_loader.gd:458-482`)가 소비하는 필드 — 신규 매니페스트가
드롭인이 되려면 이 구조를 유지한다(참조: `plaza_stage1_cyber_joseon_shop_v2_manifest.json`):

- 톱레벨: `building_type`, `source_size [w,h]`, `origin_pivot [x,y]`(바텀-센터),
  `display_height`(또는 로더 `BUILDING_LAYOUT` 티어가 override — §2.3 표), `display_scale`.
- `layers`: `base`, `sign_emissive`, `window_glow_mask` 각 `{res_path}`(필수 3키).
- `identity_emblem`: `{id, canonical_across_themes:true, description}`(엠블럼 보존 메타).
- 렌더는 `base`=`draw_texture_rect`, `sign_emissive`=flicker alpha `0.72+pulse*0.22`,
  `window_glow_mask`=warm `(1.0,0.93,0.78, 0.56+pulse*0.12)`. **신규 레이어는 이 합성 규칙에
  맞게 분리**(sign은 발광 마스크, window는 창 하이라이트만).
- NPC: 512×880 소스 → `NPC_RECT` 224×418 fit zone bottom-align. 룸 배경/오브젝트와 독립.

## 5. 스모크 갱신 (Claude 게이트, 배선과 원자적으로)

`godot/tests/plaza_scene_smoke.gd`(경로 grep으로 재확인) assert:
1. NPC 경로 7종이 `res://assets/ui/plaza/interior/`로 시작 + `_imagegen_v1.png`로 끝 →
   **`interior/`·`_imagegen_v1` 유지하면 그대로 통과**(중간 slug만 바뀜).
2. NPC 512×880 + 투명 모서리 → 신규 아트 동일 규격이면 통과(신규 아트가 규격 지켜야 함).
3. QA 매니페스트 `plaza_stage1_interior_npc_imagegen_v1_qa.json`(7 NPC, visible_magenta=0,
   corner_alpha_max=0) → **경로 갱신 필요**(신규 `plaza_lingpia_…_qa.json`).
4. 건물 카운트 7(full-layout) / 건물 타입·메뉴 타이틀 → 불변(타입 문자열·개수 유지).

**트랩(CLAUDE.md 예약-에셋)**: 스모크가 파일 존재/규격을 assert하는 경로는 **신규 아트가 실제
반입·import된 같은 슬라이스에서** 갱신한다. 아트 없이 경로만 신규로 바꾸면 스위트가 레드 →
사전-푸시 게이트 차단(의도된 게이트, 순서 준수하면 문제 없음).

## 6. 수락 게이트 (Claude — 픽셀 검증)

기존 4축(프린지 0 / 발광 정렬 / 엠블럼 240px 판독 / 3레이어 분리)에 **theme-neutrality 축 추가**:

1. **on-floor 합성 검증(핵심)**: 신규 건물을 **최소 3개 스테이지 바닥** 위에 합성 —
   stage1 cyber_joseon(박석), stage2 jungle_relic(정글 석판), stage3 neon_city(젖은 아스팔트).
   세 바닥 모두에서 이질감 없이 얹히는지(문화 충돌 0, 팔레트 안정). `tools/plaza_scene_capture.gd`로
   스테이지 전환 캡처.
2. **팔레트 안정**: 세 바닥 컷에서 건물 팔레트가 동일(바닥 따라 물들지 않음).
3. **엠블럼 판독**: 7종 홀로 엠블럼이 240px에서 원 모티프대로 읽힘(§2.3 사전 일치).
4. **3레이어 분리**: sign_emissive-ON/OFF diff, window flicker 정상, additive 발광.
5. **NPC 누끼**: 7종 512×880, magenta 0, corner alpha 0, 어두운/밝은 배경 프린지 0, 7종
   스타일 락(한 명만 크거나 톤 다르면 재생성).
6. **실렌더 픽셀 QA**: 실제 광장 씬 windowed 캡처(스폰/건물/인테리어 NPC 244×420 패널 핏).
   상태 스모크만으로 sign-off 금지(플라자 매몰/픽셀 트랩 전례).

## 7. 분담 & 순서

- **Claude**: 아트 디렉션(이 문서 §2)·엠블럼/NPC 보존 스펙·프롬프트 레시피·수락 게이트(§6)·
  이 슬라이스 문서 소유·적대 리뷰.
- **Codex/사용자**: imagegen 생산(건물 7×3레이어 + NPC 7)·chroma_key 누끼·매니페스트 작성·
  로더 상수 repoint(§3.2)·스모크 경로 갱신(§5)·Godot import·구 에셋 제거.
- **순서 권장**: ①앵커 1동(예: 상점) + 앵커 NPC 1명 생산 → Claude on-floor 게이트로 **링피아
  룩 확정**(화풍 락) → ②나머지 6동 + 6 NPC 양산(락된 문법 재사용) → ③로더/매니페스트/스모크
  배선 → ④3바닥 합성 + 실렌더 게이트 → ⑤구 cyber_joseon 건물/NPC 제거 → ⑥커밋(plaza 격리).
- **Codex 실행 패킷 = `docs/plaza_lingpia_unify_codex_handoff.md`** — 앵커(상점+모라)의 구체
  image_gen 프롬프트·발광 분리 레시피·누끼·매니페스트·출력 경로·Claude 반환 형식.
  화풍 락 후 §4 양산으로 확장.
- **①앵커 완료 — 게이트 PASS, 화풍 락 (2026-07-02)**: `plaza_lingpia_shop_v1`(3레이어+매니
  페스트) + 모라 NPC 납품·검증 완료. 판정 상세와 **양산 레시피 수정 4건(A1~A4: 고정좌표
  발광 오버레이가 1차 레시피, border-seeded 키잉 고정, 플랫 홀로 픽토그램 사인 언어 락,
  base 창 self-lit 허용)** = 핸드오프 문서 §6. stage3 바닥은 repo에 실 에셋이 없어 proxy
  목업 판정(런타임도 stage1 fallback이라 비차단). 현재 단계 = **②나머지 6동+6 NPC 양산**.

## 8. 스코프 노트 / 오픈

- **인테리어 방·오브젝트(P2 선택)**: `INTERIOR_ROOM_TEXTURE_PATHS`(shop only) +
  `INTERIOR_OBJECT_TEXTURE_PATHS`(crystal/capsule/sell_device)는 현재 shop 전용이고 대체로
  중립 사이버(크리스탈/캡슐/데이터큐브)라 급하지 않다. 일관성 위해 함께 `lingpia`로 리스킨·
  rename하는 건 **선택**. 사용자 명시 스코프("건물 및 npc")엔 미포함 — 기본은 P2 후속.
- **커밋 위생**: 워킹트리에 비-plaza dirty 대량 상존([[project-godot-wip-branch-moving-head]]).
  이 피벗 커밋은 plaza 파일 + 신규 lingpia 에셋만으로 스코프 격리, lingpet/리팩터 헌크 분리.

## 9. ②양산 게이트 결과 (2026-07-02) — **PASS (시각+기계), 전 7종 화풍 락**

신규 6동(bank/gacha/lingpet_store/blacksmith/tavern/academy) + 6 NPC(도윤/루미/링링/강철/
하랑/서율)가 앵커 화풍 기준 게이트를 통과. 배선은 아직 미착수(로더/스모크 무변경).

**시각 게이트(Claude 직접 픽셀 판정)**: theme-neutral ✓(전부 사이버/VR 파드, 문화모티프0)·
팔레트 안정 ✓(stage1 lineup서 바닥 물듦0)·실루엣 티어 차별화 ✓(은행 볼트/블랙스미스·
아카데미 타워/가챠·링펫 라운지/선술집 저층)·엠블럼 7종 사전 정합 ✓·NPC 스타일 락 ✓·
누끼(다크/라이트) 프린지0 ✓.

**기계 게이트(워크플로우 4갈래)**: ①매니페스트 7종 전부 드롭인 — building_type·source_size·
origin_pivot(정확 바텀-센터 x=w/2, y≈97~98%)·layers 3키 res_path 실존·identity_emblem 정규
id 일치(shop_coin_item_box/bank_coin_vault/gacha_capsule_rotation/lingpet_egg_ring_orbit/
tavern_quest_scroll_cup/academy_book_orb_exchange/blacksmith_hammer_anvil_flame)·
stage_theme="lingpia"·canonical_across_themes=true, issues 0. ②core 28 PNG(21빌딩+7NPC)
.import+.ctex 100% (누락0). ③NPC set 매니페스트 theme=lingpia, 7엔트리, 전부 512×880·
magenta0·corner0. ④구 cyber_joseon(빌딩105+NPC30) 잔존=배선 전이라 정상.

**비차단 findings**: (코스메틱)컨택트 8번째 빈 셀 검정/흰색 채움 = 시각화 아티팩트. (설계
의도)모라↔루미 외형 유사 = 스타일 락, 인게임 동시노출 없어 무영향. (커버리지)신규 6동은
stage1 바닥 합성만 — 팔레트 락+앵커 3바닥 통과로 중립성 상속, 실질 커버는 배선 실렌더 게이트.

### 9.1 배선 델타 (다음 슬라이스 — ⚠ 바닥 참조 오인 rename 금지)

스모크(`godot/tests/plaza_scene_smoke.gd`)는 대부분 slug-agnostic이라 통과하나, 아래만
**정확히** 손댄다. **워크플로우가 바닥 참조까지 "갱신 필요"로 과다 표기했음 — 바닥/패럴랙스는
stage1 테마라 절대 rename 금지.**

**변경(건물·NPC만)**:
- `plaza_asset_loader.gd` `BUILDING_MANIFEST_PATHS`(:77-83) → 7 × `plaza_lingpia_<type>_v1_manifest.json`.
- `plaza_asset_loader.gd` `INTERIOR_NPC_TEXTURE_PATHS`(:23-30) → 7 × `plaza_lingpia_interior_npc_*`.
- `plaza_scene_smoke.gd`: 건물-base 픽셀샘플 1개(구 `plaza_stage1_cyber_joseon_shop_v2_building_base.png`
  참조 ~line20) → lingpia shop base. interior NPC set 매니페스트(~line151) +
  QA 매니페스트(~line153 `plaza_stage1_interior_npc_imagegen_v1_qa.json`) → `plaza_lingpia_..._{manifest,qa}.json`.

**유지(절대 변경 금지 — 바닥 테마)**:
- `PIXEL_SAMPLE_PATHS`의 **바닥/패럴랙스** 항목(`plaza_stage1_floor_*_cyber_joseon`,
  `plaza_stage1_sidescroll_ground_strip_cyber_joseon` 등) — floor는 stage1 테마.
- 테마 id assert `stage1_cyber_joseon`(~line77) + `jungle_relic`(~line82) = floor 테마.

**제거(배선·스모크 GREEN 확인 후)**: 구 `plaza_stage1_cyber_joseon_*`(건물 105) +
`plaza_stage1_interior_npc_*`(NPC 30). floor `plaza_stage1_floor_*`/`_sidescroll_*`는 잔존.

**게이트(배선 후)**: 실 광장 씬 windowed 캡처(신규 7동 렌더 + 인테리어 244×420 NPC 핏) +
plaza 스모크 GREEN + `run_headless_load_check.ps1` + warning scan. 이때 신규 6동이 실제
스테이지 바닥 위에 렌더되므로 §9의 on-floor 커버리지 갭이 자연 종료.

## 9.2 배선 슬라이스 완료 + 리뷰 PASS (2026-07-02) — **통일 피벗 live**

배선 2파일(`plaza_asset_loader.gd` +14/-14, `plaza_scene_smoke.gd`) 완료. `BUILDING_MANIFEST_PATHS`
7종 + `INTERIOR_NPC_TEXTURE_PATHS` 7종 → lingpia repoint, 스모크 건물-base 픽셀샘플 1줄 +
NPC set/QA 매니페스트 경로 → lingpia. 구 에셋 제거(건물 105 + NPC 30), floor 계열 잔존.
**바닥/패럴랙스·테마 id·strewn 참조 무변경**(트랩 회피 확인).

**Claude 적대 리뷰 = PASS(직접, 보고 미신뢰 재검증)**:
- diff 직접 확인 — 정확히 델타대로, floor 오인 rename 0.
- 픽셀 게이트 — street 5컷(신규 7동 바닥 위 자연 렌더·상호작용 프롬프트 동작) + menu 7컷
  (신규 NPC 7종 244×420 패널 클린 렌더, shop 리치룸/나머지 절차 인테리어 그대로).
- 적대 스윕(워크플로우 3갈래): live dangling ref 0 · orphan `.import` 0 · 신규경로 broken 0 ·
  `get_prewarm_texture_paths`가 두 상수 동적 열거라 rename 자동 추종 · 다른 소비자 stale 0.
  구 이름 잔존 11건은 전부 docs/memory 히스토리(비버그).
- 사용자 검증: plaza 스모크 PASS · warning scan 0(2062 스크립트) · headless load PASS · rg 0.

**남은(선택)**: (a) plaza 격리 커밋(사용자 요청 시) (b) P2 — 비-shop 6동 인테리어 룸/오브젝트
lingpia화(현재 절차형 + shop만 리치룸, 사용자 명시 스코프 밖).
