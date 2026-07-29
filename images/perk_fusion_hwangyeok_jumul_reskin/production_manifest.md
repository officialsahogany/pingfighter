# 합일 환격전 주물 의식 리스킨 — 생성 매니페스트

생성일: 2026-07-29

런타임 착지: `godot/assets/sprites/effects/perk_fusion_cold_boot/`

구조 계약: 기본 리스킨의 기존 9개 `res://` 경로와 4x4 ignition atlas를
유지한다. §10 프리미엄 업그레이드는 정적 제단 백플레이트 경로 1개만 새로
배선하고, 헤딩 장식은 절차 드로만 사용한다.

## 생성기와 참조

- 정지 에셋 8종: Codex built-in `imagegen`.
- ignition 16프레임: AutoSprite asset animation.
- 재질 참조: `godot/assets/sprites/orbs/dash_token_frame_imagegen_v3.png`,
  `godot/assets/sprites/orbs/skill_orb_frame_imagegen_v2.png`.
- `chassis_on`은 승인된 `chassis_off`를 구도 고정 편집했다.
- 오른쪽 무공패는 승인된 왼쪽 무공패를 결정적으로 수평 반전했다.
- 모든 정지 원본은 평면 `#ff00ff` 배경으로 생성했다. 실제 문자, 워터마크,
  장면 배경, 캐릭터는 금지했다.

## 최종 정지 에셋 프롬프트 세트

아래는 최종 승인 호출을 재현하기 위한 정규화된 production prompt set이다.
각 항목에는 다음 공통 꼬리를 적용한다.

```text
Front-facing isolated game UI/VFX asset, crisp silhouette, generous empty
margin, same dark lacquer / aged polished brass / muted cinnabar / deep teal
dancheong material language as the supplied Ringpia HUD references. Perfectly
flat solid #ff00ff chroma-key background. No text, no readable Chinese or
Korean characters, no character, no scene, no watermark, no drop shadow
outside the object. Do not use #ff00ff inside the art.
```

1. `cold_boot_chassis_off_raw_magenta.png`

```text
Create a circular Korean mythic-martial ritual crucible altar for a game
cinematic, top-lit front view. Dark lacquered brown-black altar disc, double
polished brass rims, a ring band of unlit invented seal-script talisman
engravings drawn only as abstract recessed ink marks, dancheong geometric
accents in muted cinnabar / deep teal / gold with thin black outlines, four
small knotted norigae ornaments at the cardinal points, and two vertical empty
docking recesses at the center for martial-art tablets. Unlit cold state.
```

2. `cold_boot_chassis_on_raw_magenta.png`

```text
Edit the supplied accepted unlit ritual crucible without changing silhouette,
camera, docking-bay geometry, ornaments, or crop. Ignite the two inner furnace
bays with bright white-hot orange cores and molten amber falloff; light the
abstract seal ring in jade-blue flame and raise the saturation of the teal
dancheong band. Keep enough real internal luminance to drive the runtime heat-
haze shader. The outer lacquer and brass remain readable, not blown out.
```

3. `cold_boot_cartridge_left_raw_magenta.png`

```text
Create one compact vertical Korean mythic-martial metal tablet, approximately
0.72 width-to-height, dark lacquer body with an aged brass rim, small top knot,
subtle invented dancheong corner marks, and a large plain matte-black inset
face plate centered in the body. The plate must remain empty and broad enough
for a 32 px runtime icon; no emblem or writing inside it. Formal forged object,
not a scroll and not a long hanging tag.
```

4. `cold_boot_cartridge_right_raw_magenta.png`: deterministic horizontal mirror
of item 3; no additional generative call.

5. `cold_boot_module_shoulder_pod_raw_magenta.png`

```text
Create a compact bronze Korean ritual bell module: small top suspension ring,
short engraved bell body, dark lacquer recesses, fine brass rim, restrained
cinnabar and deep-teal dancheong details. It must read clearly as a tiny
deployable hardware ornament at roughly 88 px runtime width.
```

6. `cold_boot_module_collar_ring_raw_magenta.png`

```text
Create a compact knotted norigae collar module: tight decorative knot, short
loop and very short tassel, dark lacquer / aged brass / muted cinnabar / jade
thread. Keep the silhouette squat and self-contained, with no long dangling
cords, for a roughly 58 px runtime-width deployable ornament.
```

7. `cold_boot_module_gem_plate_raw_magenta.png`

```text
Create a compact jade seal plaque module: polished celadon-jade center held by
a dark lacquer and aged-brass bezel, tiny knot attachment, invented non-text
seal grooves, restrained cinnabar accent. It must read at roughly 66 px runtime
width as a premium awakened hardware plate.
```

8. `cold_boot_spark_shard_raw_magenta.png`

```text
Create one narrow incandescent forge shard: sharp irregular brass-orange
molten fragment, white-hot inner edge, ember-red falloff, clean pointed
silhouette and no smoke. It must remain readable around 12 px runtime width.
```

Two rejected generations were not landed: an overly long tablet (32 px face
plate became unreadable) and an overly long-tassel norigae (runtime silhouette
failed). Only the accepted compact replacements are archived here.

## AutoSprite ignition

- Preview/source asset ID: `cms5ji80n00l512y8hcnyjhbt`
- Animation job ID: `wf_1044e39b-f4ff-4a7d-a235-d9663f9af0f4`
- Sprite sheet ID: `cms5jkoty001l12pu7df0q8l7`
- Mode: turbo, non-loop, 2 seconds, 16 frames, 512 px, background removal ultra.

Final animation prompt:

```text
Animate this molten Korean ritual crest as one non-looping forge ignition.
Camera and crest center stay perfectly locked. Begin as a compact dim ember;
radially kindle brass-orange molten spokes and a jade-blue flame rim; expand
to a bright ceremonial casting seal with maximum intensity around frames 6-7;
then cool, fragment, and dissipate smoothly through frame 16. Preserve the
source silhouette and material identity. No translation, camera motion, text,
new objects, background, or loop seam.
```

AutoSprite delivered a 2048x2048 4x4 sheet of 512 px cells. Deterministic
postprocessing only: center-connected near-white hole removal per cell, fixed
whole-cell 512→236 Lanczos scale (no per-frame recenter), 10 px inset into each
256 px output cell, and one-shot alpha envelope
`[0.28, 0.42, 0.58, 0.76, 0.90, 1.00, 1.00, 0.98, 0.93, 0.86, 0.76, 0.64, 0.52, 0.40, 0.28, 0.14]`.
Final atlas: 1024x1024, 4x4, transparent center and transparent cell edges.

## 누끼와 런타임 후처리

1. Repo `chroma_key.py --key magenta --pad N` flood-fill pass.
2. Built-in imagegen `remove_chroma_key.py` global soft-matte/despill pass with
   key `#ff00ff`, transparent threshold 12, opaque threshold 140.
3. Maximum source edge limited to 1024 px with deterministic Lanczos scaling.
4. Alpha QA: all four corners zero, outer 2 px zero, alpha bbox inset at least
   2 px, alpha-bearing magenta pixel count zero for all 9 final files.

Measured tablet face plate safe rect is `Rect2(0.247, 0.323, 0.506, 0.503)`.
Runtime constants are X `0.500`, Y `0.587`, icon span `32.0`, draw height `96.0`.

## §10 프리미엄 업그레이드 (Codex built-in imagegen)

### 제단 바닥 진법 백플레이트

- raw: `imagegen_raw/cold_boot_altar_backplate_raw_magenta.png`
- processed/runtime:
  `processed/cold_boot_altar_backplate.png` =
  `godot/assets/sprites/effects/perk_fusion_cold_boot/cold_boot_altar_backplate.png`
- built-in imagegen 결과:
  `C:/Users/woduq/.codex/generated_images/019fac9e-5784-7e02-ae84-8227d1de10bf/exec-3a4a304c-b82e-49dc-9c83-23069cf475bd.png`
- 생성 원본 1254px을 결정론적 Lanczos로 1024px 제한한 뒤, 설치된
  `remove_chroma_key.py`를 `--auto-key border --soft-matte
  --transparent-threshold 12 --opaque-threshold 220 --despill`로 적용했다.
  최종 알파 통계는 투명 422,573px / 부분 투명 3,031px이며 네 모서리와
  외곽 여백은 완전 투명이다.

최종 정규화 프롬프트:

```text
Use case: stylized-concept
Asset type: transparent-ready 2D game cinematic altar backplate texture,
square 1024 source
Primary request: one large circular Korean mythic ritual formation floor
plate viewed perfectly straight from the front, designed to sit quietly
behind a much brighter central crucible and two metal martial-art tablets.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background, one
uniform color with no shadows, gradients, texture, reflections, floor plane,
or lighting variation.
Subject: one centered, fully visible circular lacquered brown-black ritual
disc; two or three thin concentric ink rings; a faint continuous band of
invented seal-script talisman glyphs that do not form real Chinese characters
or readable writing; eight thin radial trigram-like rule motifs pointing to
the cardinal and intercardinal directions.
Style/medium: premium hand-painted Korean martial-fantasy game UI texture,
restrained flat orthographic asset, crisp clean silhouette.
Composition/framing: perfectly centered circular disc, generous magenta
padding, symmetric front-on presentation, no perspective tilt, no cropping.
Lighting/mood: low saturation, low contrast, quiet, ceremonial, subordinate to
the brighter crucible placed over its center.
Color/materials: very dark lacquered brown-black, recessed black ink, muted
antique brass only; subtle lacquer and aged ink; brass marks thin and dull.
Constraints: no real Chinese or Korean text, no readable symbols, characters,
extra objects, scene, bright highlights, glow, metallic shine, cast/contact
shadow, reflection, or watermark; background exactly flat #ff00ff; do not use
#ff00ff inside the disc; crisp edges and generous removal padding.
Avoid: bright gold, orange fire, turquoise, jade, cyan, red seals, thick
outlines, high contrast, embossed 3D medallion look, extra ornaments, letters,
or numbers.
```

런타임은 `altar_backplate` 키를 이산 prewarm 매니페스트에 추가하고 화로보다
먼저 520px 정적 1콜로 그린다. 비트 스냅샷 알파는 B0/B1 `0.22`, B2 이후
`0.32`의 두 단계뿐이다. 회전·트윈·스케일 펄스는 없으며, 텍스처 부재 시
저채도 동심원 3콜로 폴백한다.

### 헤딩 장식과 재채점

- 타이틀 실측 폭에서 시작하는 좌우 3세그먼트 놋쇠 괘선 6콜.
- 주사 낙관은 방형 프레임 1콜 + 추상 획 3콜; 실존 문자와 유니코드 장식
  글리프를 사용하지 않는다.
- 타이틀 그림자 1콜이 추가되어 총 추가 드로 콜은 `+11`이다(`+15` 예산 이내).
- 7언어 x 8개 실제 제목 변형(재료·확인·연출 + 리빌 5종)을 실측해 타이틀,
  낙관, 좌우 괘선의 비중첩과 최소 길이를 봉인했다. 별도 실렌더는
  4페이즈 x 7언어 = 28장이다.
- 정지 프레임 재채점: **연출 화면 8/10, 모달 크롬 7/10**. 백플레이트는
  중앙 화로보다 먼저 읽히지 않고, 추가 기물이나 알파 재조정 없이 목표 게이트를
  충족했다.

## SHA-256

Runtime/processed files:

```text
e54b2ee56da381a3cab0e4e55fe42604579342908332d8098459cc56f4ff5cfa  cold_boot_cartridge_left.png
ff236a1cbc5456e778ce846d59ad462425fca0b01216acdcfd2d01cb144dd733  cold_boot_cartridge_right.png
9c3c10fa8624fb89c05ea60e7e572cb0a98b59dade6814c062fd09a4b29f0a84  cold_boot_chassis_off.png
80e800100763870fa40622586bdc0792015e0c13214256a583bb34ab5d9c1be2  cold_boot_chassis_on.png
9776cdb57fb8e2c6bd083860ba87e91b82c8f2b6cd4f1dd89bdd56927eb2d356  cold_boot_ignition_ring_sheet.png
7ad0a205cbd7bcb6fae4dd98be360b28e11b1f72a2c10812c6e4695ffabcd00c  cold_boot_module_collar_ring.png
f56ff47aa7daae242de9b82e169a9004e4c7f2f34debac540a6c53bd439d7e8d  cold_boot_module_gem_plate.png
20ea616e6aab39546125facd07b164b0d6618000491645d59d5cf21670386793  cold_boot_module_shoulder_pod.png
72e6ef08bb607e59aa097ef056fcb081bd8f784b97ad5729ebe73888076332da  cold_boot_spark_shard.png
27561521f47d82f0fc238add9b4b5ba177fcd12306a7ece1fd34806693d0621e  cold_boot_altar_backplate.png
```

§10 생성 원본/QA:

```text
73f5bb1241c9dee047405e4fd3d43be6f349f038a657524b180db647ee6d6a3c  cold_boot_altar_backplate_raw_magenta.png
646d3de5acb6eec495ae5a0630ed52a5224a5700b32f8c6a61662d8219f2a5cb  premium_upgrade_before_after.png
757b822aebb6c131a355ed83e9d39177282bfd6636901dfe151aa316eed82f1f  premium_upgrade_locale_matrix.png
2490b4dd2510af30a30ecc3f2c42ee83272c038e33c77ba8a7d8203252693467  premium_upgrade_tier_matrix.png
```

AutoSprite committed source bundle:

```text
4b27726217457858a83212ae6c3a48cb8a3a904fd0935c170f123d1e446d756f  cold_boot_ignition_crest_autosprite_preview_v1.png
470b815025a154c82bfa6a1ab3f615e0b96b37bcaa0d01a681372c023dee9a35  cold_boot_ignition_ring_autosprite_v1_atlas.json
b9a39188767e71c10c8cf677227f6cc5a857755cd962a65ed061a6c41aa92b3f  cold_boot_ignition_ring_autosprite_v1_raw.png
```

AutoSprite가 함께 반환한 MP4 preview
`cold_boot_ignition_ring_autosprite_v1.mp4`
(`cc189574b4141a82d4b3de6a655929bcb79627b7afdd83abf62ce12aae364f37`)는
repo의 `*.mp4` ignore 정책을 따라 로컬 진단 부산물로만 보존한다. 런타임 및
재현 authority는 raw 4x4 sheet와 atlas JSON이다.

## QA 산출물

- `qa/static_assets_runtime_dark.png`
- `qa/static_assets_runtime_light.png`
- `qa/before_after_runtime_comparison.png`
- `qa/cartridge_plate_probe.png`
- `qa/ignition_keyframes_dark.png`
- `qa/premium_upgrade_before_after.png`
- `qa/premium_upgrade_locale_matrix.png`
- `qa/premium_upgrade_tier_matrix.png`
- 최종 실렌더 22장과 fail-closed summary:
  `C:/Users/woduq/bosspong_backups/qa_evidence/perk_fusion_cold_boot_6697449_50564_0c49fedcfd4d/`
- §10 업그레이드 실렌더 50장(기존 22 + 4페이즈 x 7언어)과 fail-closed
  summary:
  `C:/Users/woduq/bosspong_backups/qa_evidence/perk_fusion_cold_boot_7613709_21328_79789b7ed94c/`

실렌더는 선택/확인/연출/리빌, success/stable/side_effect/byproduct,
무호스트 절차 폴백, B5 핸드오프, 즉시 스킵, 모듈 1/2/3개 전개와 스테일
호스트 재사용을 포함하며 최종 `RESULT: PASS`다.
