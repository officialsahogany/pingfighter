# Codex 핸드오프 — 광장 링피아 통일 앵커 생산 (건물·NPC imagegen)

작성 2026-07-02. **생산 = Codex built-in image_gen. 아트 디렉션·수락 게이트 = Claude.**
상위 설계·계약의 단일 소스 = `docs/plaza_lingpia_unify_slice_plan.md`. 이 문서는 그 슬라이스의
**Codex 실행 패킷**(자족적 프롬프트 + 레시피 + 경로 + 반환 형식)이다.

이 패킷은 **앵커 1동(상점) + 앵커 NPC 1명(모라)만** 다룬다. 화풍이 Claude 게이트를 통과해
**락된 뒤에** 나머지 6동 + 6 NPC를 같은 문법으로 양산한다(§4). 락 전에 7종을 미리 뽑지 말 것
— 화풍이 틀어지면 전량 재작업이다.

전제(사용자 확정): slug = **`lingpia`**, 앵커 = **상점(shop)**. 바닥·패럴랙스는 스테이지별
테마 유지라 이 패킷 범위 밖(손대지 않음).

---

## 0. Codex 세션 사전 점검

- `~/.codex/config.toml`에 `service_tier = "default"` 줄이 있으면 핸드오프 로드가 실패한다 —
  **그 줄을 제거**하고 세션을 시작할 것(기존 사고 기록).
- 출력 경로 규약: 런타임 PNG는 `godot/assets/ui/plaza/buildings/` (건물) /
  `godot/assets/ui/plaza/interior/` (NPC). 반입 후 **Godot import(.import + .ctex)**까지 완료해야
  로더/스모크가 집는다(`texture_resource_exists()` 게이트). import 안 하면 조용히 폴백.

---

## 1. 목표 (앵커)

theme-neutral **링피아 VR 허브** 룩으로 상점 건물 1동 + 상점 NPC 모라 1명을 생성한다.
"어떤 스테이지 바닥(사이버 조선 박석 / 정글 석판 / 네온 젖은 아스팔트) 위에도 이질감 없이
얹히는" 것이 유일한 성공 기준이다. **실세계 문화 모티프 금지**(한옥 기와/단청/처마, 정글,
사찰, 중화 시장 등 stage 연상 요소 일절 없음).

팔레트 시그니처: 딥 인디고/차콜 베이스 + CYBER_CYAN `#00E5FF` 엣지 트림 + CYBER_MAGENTA
`#FF1FC2` 소액센트 + 창 웜 `#FFEDC7`. 바닥 색이 뭐든 **건물 팔레트는 불변**(건물 = 시각적 상수).

---

## 2. 상점 건물 — 3레이어 (base + sign_emissive + window_glow_mask)

제작 문법 = **2-edit 발광 분리**(현 shop_v2 문법 그대로): base 1장 생성 → 동일 구도에서
sign-ON / window-ON 에디트 2장 → base와 diff로 발광 마스크 추출.

### 2.1 image_gen — BASE (프롬프트)

```
A single free-standing shop / market kiosk building, 3/4 front view, isolated on a
perfectly flat pure magenta (#ff00ff) background. Style: sleek virtual-reality "hub
facility" architecture — a holographic data-construct storefront, NOT a real-world
cultural building. Clean geometric modular volume, low wide single-storey pod
silhouette (cozy, approachable). Materials: dark charcoal / deep-indigo paneling with
thin glowing cyan (#00E5FF) edge trim and small magenta (#FF1FC2) accents; frosted
data-glass shopfront windows; a projected holographic signboard frame above the
entrance left as a clean dark unlit panel (NO icon yet, NO text). Cyberpunk night
ambience, soft neon rim light, faint floating holo particles. ABSOLUTELY NO hanok,
tiled roof, dancheong, Korean/Asian traditional motif, NO jungle, NO temple, NO
market-stall culture — pure futuristic VR hub. Front-facing so it reads as a storefront
the player walks up to. Generous transparent/magenta margin on all sides, nothing
touching the image edges, NO ground, NO baked shadow. High detail, painterly-clean,
game-ready facade asset. Square canvas ~1536.
```

### 2.2 image_gen — SIGN-ON (base 에디트)

```
Same building, identical composition, camera, materials and lighting, but the
holographic signboard above the entrance is now FULLY LIT with a bright emissive
pictogram: a glowing GOLD COIN overlapping a small ITEM BOX / pouch (the shop emblem).
Cyan-and-gold holographic glow, crisp icon, NO text. Everything else identical to the
base image so a difference mask isolates only the lit sign.
```

### 2.3 image_gen — WINDOW-ON (base 에디트)

```
Same building, identical composition, camera, materials, but all shopfront windows are
now brightly lit warm amber (#FFEDC7) glow from inside, as if the shop is open and
occupied. Everything else identical to the base image so a difference mask isolates
only the lit windows.
```

### 2.4 후처리 레시피

1. **base 누끼**: base 생성물 → `tools/chroma_key.py`로 `#ff00ff` 제거(흰배경 remove_bg 금지) →
   `plaza_lingpia_shop_v1_building_base.png`. 코너 alpha 0, 프린지 0, 가시 알파 bbox가 캔버스
   에지 미접촉.
2. **sign_emissive 추출**: SIGN-ON diff base → 사인 발광만 남긴 마스크 →
   `plaza_lingpia_shop_v1_sign_emissive.png` (엠블럼 픽토그램 영역만).
3. **window_glow_mask 추출**: WINDOW-ON diff base → 창 하이라이트만 →
   `plaza_lingpia_shop_v1_window_glow_mask.png`.
4. 원본 chromakey 소스 3장 보존: `..._building_base_source_chromakey.png`,
   `..._sign_on_source_chromakey.png`, `..._window_on_source_chromakey.png`.
5. lit 프리뷰 1장: `..._lit_preview.png` (base+sign+window additive 합성).

### 2.5 매니페스트 (드롭인 — 스키마 유지 필수)

`godot/assets/ui/plaza/buildings/plaza_lingpia_shop_v1_manifest.json`. 참조 스키마 =
`plaza_stage1_cyber_joseon_shop_v2_manifest.json`. 필드 그대로, 값만 신규:

- `building_type: "shop"`, `stage_theme: "lingpia"`(또는 필드 제거), `asset_id: "plaza_lingpia_shop_v1"`.
- `source_size: [w,h]`(실제 생성 캔버스), `origin_pivot: [x, y]`(**바텀-센터** = 접지선 중앙),
  `display_height`(정보용; 런타임은 `BUILDING_LAYOUT` shop=220이 override).
- `layers.base / layers.sign_emissive / layers.window_glow_mask` 각 `{res_path, sha256}`.
- `identity_emblem: {id:"shop_coin_item_box", canonical_across_themes:true, description:"gold coin plus item box/pouch pictogram; Lingpia hub, theme-neutral"}`.
- `source_layers` = 위 chromakey 소스 3종.

---

## 3. 상점 NPC — 모라 (포트레이트)

### 3.1 image_gen (프롬프트)

```
Full-body character portrait of a friendly VR-hub shopkeeper, standing 3/4 view,
centered on a perfectly flat uniform pure magenta (#ff00ff) chroma-key background.
Style: Korean-anime painterly + cyberpunk, clean consistent lineweight, cohesive with
a game character roster. A cheerful young shop clerk in sleek techwear / holographic-
trim uniform with cyan (#00E5FF) and warm amber accents, a small holo-visor or
holo-earpiece, presenting a small glowing holographic item crate in her hands. She
reads as staff of a futuristic virtual-reality marketplace — NOT hanbok, NOT any
traditional cultural dress. Warm welcoming expression. Even soft studio lighting, NO
baked ground shadow, full body inside the frame with generous margin, nothing touching
edges. The magenta background must be perfectly flat and uniform for clean chroma-key.
Vertical portrait, tall aspect (approx 512x880 ratio).
```

### 3.2 후처리

- `tools/chroma_key.py`로 `#ff00ff` 누끼 → `plaza_lingpia_interior_npc_shop_mora_imagegen_v1.png`
  (**512×880**, 코너 alpha 0, visible_magenta 0, 어두운/밝은 배경 프린지 0). 원본 보존
  `..._magenta_source.png`.
- 이름/역할/인사는 **코드 기존값 그대로**(모라 / 상점주인 / "어서오세요!|필요한 장비를
  골라볼까요?", `plaza_scene.gd:68/78`). 굽지 말 것. fit zone = `NPC_RECT` 224×418.

---

## 4. 배선 (앵커 게이트 통과 후)

앵커가 Claude 게이트를 통과해 **화풍이 락되면**, §2~3을 나머지 6동 + 6 NPC로 반복
(`docs/plaza_lingpia_unify_slice_plan.md` §2.3 엠블럼 표 / §2.4 NPC 표). 그 뒤 로더 배선:

- `plaza_asset_loader.gd` `BUILDING_MANIFEST_PATHS`(:77-83) → 7 × `plaza_lingpia_<type>_v1_manifest.json`.
- `INTERIOR_NPC_TEXTURE_PATHS`(:23-30) → 7 × `plaza_lingpia_interior_npc_*`.
- interior NPC set/QA 매니페스트 신규 `plaza_lingpia_interior_npc_imagegen_v1_{manifest,qa}.json`.
- 구 `plaza_stage1_cyber_joseon_*`(건물) + `plaza_stage1_interior_npc_*`(NPC) 에셋 제거.
- **렌더 코드 수정 없음**(매니페스트/로더 간접참조, 슬라이스 §4 계약).

### 스모크 (배선과 원자적으로 — 예약-에셋 트랩)

`godot/tests/plaza_scene_smoke.gd`: NPC `interior/`·`_imagegen_v1` 접미사 유지 시 경로 assert
통과, 512×880/투명모서리 assert는 신규 아트가 규격 지키면 통과, **QA 매니페스트 경로
assert만 신규 `plaza_lingpia_..._qa.json`로 갱신**. 아트 실반입·import 전에 경로만 신규로
바꾸면 스위트 레드(의도된 게이트) — 같은 슬라이스에서 함께 갱신.

---

## 5. Codex → Claude 반환 형식 (게이트 입력)

앵커 완료 후 아래를 반환하면 Claude가 수락 게이트를 돈다:

1. 산출 경로 목록(base/sign/window/누끼 소스/lit_preview/매니페스트/NPC png).
2. **on-floor 합성 컷 3장 (핵심)**: 신규 상점을 **cyber_joseon(stage1) / jungle_relic(stage2) /
   neon_city(stage3)** 바닥 위에 각각 합성한 760px 목업. `tools/plaza_scene_capture.gd`로
   스테이지 전환 캡처 권장. → 세 바닥 모두 이질감·팔레트 물듦 0인지 판정.
3. sign_emissive-ON/OFF diff 컷 + window flicker 확인 컷.
4. NPC 512×880 누끼 컨택트(어두운/밝은 배경), magenta/corner alpha 수치.
5. 실 광장 씬 windowed 캡처(인테리어 244×420 패널 핏, 모라 렌더).

Claude 게이트 5축(슬라이스 §6): ①3바닥 on-floor 무충돌 ②팔레트 안정 ③엠블럼 240px 판독
④3레이어 분리·발광 정상 ⑤NPC 누끼·스타일 락 + 실렌더 픽셀 QA. 통과 시 화풍 락 → §4 양산.

---

## 6. 앵커 게이트 결과 (2026-07-02) — **PASS, 화풍 락**

Claude 5축 게이트 통과. 앵커(상점 v1 + 모라 v1)가 **링피아 화풍 기준점**이다. 판정 근거:

1. **3바닥 무충돌**: stage1 박석(밝은 바닥 위 고대비, 문화 충돌 0) / stage2 정글 유적(네온
   대비 최상) 통과. stage3은 **repo에 실 광장 바닥 에셋이 없어 proxy 목업으로 대체 판정** —
   런타임도 stage3 바닥은 stage1 fallback이므로 비차단(실 에셋이 생기면 그때 재검).
2. **팔레트 안정**: 3컷 모두 건물 팔레트 불변, 바닥 물듦 0.
3. **엠블럼 판독**: lit_preview를 실제 런타임 스케일(display_scale 0.3207 → 높이 220px)로
   다운스케일 재검 — 금화+박스 픽토그램 판독 OK.
4. **3레이어 분리**: base 알파 bbox (14,14)-(1183,672) 에지 미접촉 / 코너 알파 0. 사인
   플리커 픽셀 델타 mean 9.4·max 50(가시적), 윈도우 글로우 ON-vs-OFF mean 6.2·max 38(웜
   앰비언스 기여), 펄스 델타 mean 1.15(의도된 미세 호흡 — 런타임 계약 0.56±0.12와 일치).
5. **NPC 누끼·스타일**: 512×880, 코너 알파 0, 마젠타 사실상 0(4px는 홀로 크레이트 보라 —
   오검출), bbox 에지 미접촉, 명/암 배경 프린지 0, 패널 핏 정상. 테크웨어+시안/앰버+홀로
   크레이트 = 로스터 스타일 락.

부수 확인: 매니페스트 드롭인 스키마 일치(3레이어 키·identity_emblem·collision/interaction
rect 포함), 전 신규 PNG `.import`+`.ctex` 생성 확인. `sign_diff_contact.png`의 "sign diff"
패널이 거의 빈 것은 컨택트 시각화 버그(코스메틱) — 레이어 자체는 독립 검증됨, 재생성 불요.

### 6.1 양산 레시피 수정 (락된 문법 — 나머지 6동 + 6 NPC에 적용)

- **A1. 발광 레이어 제작법 교체**: §2.2/2.3의 "2-edit diff" 문법은 앵커에서 **구도 드리프트로
  실패·폐기**됐다. 락된 1차 레시피 = **accepted base 위 고정좌표 로컬 발광 오버레이 분리**
  (앵커 방식). 에디트 프롬프트는 시도해볼 참고용으로만 남긴다 — 드리프트 나면 즉시 오버레이
  방식으로 전환하고 시간 낭비하지 말 것.
- **A2. 누끼는 border-seeded 키잉 고정**: 건물엔 의도된 CYBER_MAGENTA `#FF1FC2` 네온
  액센트가 있으므로 **글로벌 색상 키잉 금지**(액센트를 먹는다). 앵커의 border-seeded
  `#ff00ff` flood + pure-key hole cleanup 방식을 유지.
- **A3. 사인 언어 락**: 사인은 **틸 홀로 패널 + 플랫 벡터 픽토그램**(앵커의 금화+박스 스타일)
  으로 7종 통일. 페인털리 간판으로 회귀 금지 — 홀로 스크린이 링피아 세계관 정합.
- **A4. base 창은 self-lit 허용**: base 생성 시 창이 이미 시안 발광으로 나오는 건 수용
  (윈도우 레이어는 웜 앰비언스 오버레이 역할). 앵커와 동일한 읽힘 유지가 우선.
