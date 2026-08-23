# 수련 타이밍 게이지 imagegen 프롬프트 기록

실행 경로는 Codex 내장 `image_gen`이다. 제품 영문명은 사용하지 않았고,
환격전의 수련장 목재·황동·진사·먹 재질만 지정했다.

## 1. 트랙 프레임 v1 - 승인 후보

```text
Use case: stylized-concept
Asset type: production game HUD chrome component, training timing gauge track frame
Primary request: Create exactly one very long, narrow Korean-fantasy timing-gauge track frame for 환격전, designed as a 9-patch-friendly horizontal rail with distinct left cap, repeatable center rail, and right cap.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background; the entire inner track window must also be exactly flat #00ff00 so it becomes transparent after keying.
Style/medium: polished hand-painted 2D game UI asset, crisp readable silhouette at small runtime scale.
Composition/framing: center one isolated frame only; 12.3:1 frame silhouette, approximately 94% of canvas width and 7.6% of canvas height, straight horizontal geometry, generous green padding on all sides, fully visible closed rim. No perspective angle.
Color palette: dark walnut lacquer and ink-black recesses, aged brass edges, restrained cinnabar-red knots and seal-like corner accents, tiny warm hanji highlights.
Materials/textures: carved training-yard timber, hammered brass, subtle brush-grain; keep texture restrained and edges clean.
Constraints: actual bitmap art; transparent-ready empty inner track window; symmetrical caps; repeatable quiet center span; no shadows outside the object; no floor plane.
Avoid: text, numbers, glyphs, icons, characters, gameplay scene, colored judgment zones, pointer, tick marks, watermark, logo, neon, sci-fi, Diablo-like ornament, green within the frame itself, gradients or texture in the #00ff00 background.
```

생성기는 요청과 달리 진짜 알파 PNG를 반환했다. 외곽 알파 1 잔여를 제거한
뒤 닫힌 내부 투명 창과 목표 해상도 가독성을 확인해 후보로 채택했다.

## 2. 최초 틱 - 거부

```text
Use case: stylized-concept
Asset type: production game HUD chrome component, reusable timing-gauge boundary tick
Primary request: Create exactly one isolated vertical boundary tick marker for a Korean-fantasy training timing gauge in 환격전.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background.
Style/medium: polished hand-painted 2D game UI asset, crisp and readable at roughly 40 pixels tall in game.
Composition/framing: one centered upright marker only, straight front view, narrow vertical silhouette around 1:4 width-to-height, generous green padding. It should extend above and below a horizontal gauge track and visually clamp onto the rail, but include no rail.
Color palette: aged brass and restrained warm gold leaf, tiny dark-ink engraved recesses, a minute cinnabar knot accent.
Materials/textures: hammered brass, engraved Korean-fantasy scrollwork, crisp hard edges.
Constraints: neutral reusable marker; closed clean silhouette; no cast shadow, glow, halo, floor plane, or perspective.
Avoid: text, numbers, glyphs, icons, characters, gameplay scene, red or blue judgment fill, pointer arrow, watermark, logo, neon, sci-fi, green inside the object, gradient or texture in the #00ff00 background.
```

장창처럼 읽히고 넓은 광원 헤일로가 있어 거부했다.

## 3. 최초 중심추 - 거부

```text
Use case: stylized-concept
Asset type: production game HUD chrome component, moving timing-gauge center weight pointer
Primary request: Create exactly one isolated moving center-weight pointer for a Korean-fantasy training timing gauge in 환격전, combining a bright neutral aged-brass plumb weight with an ink-brush-nib silhouette.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background.
Style/medium: polished hand-painted 2D game UI asset, crisp readable silhouette at small runtime scale.
Composition/framing: one centered front-view marker only, vertically symmetrical clasp that visibly bites across the top and bottom of a horizontal track, thin central shaft, compact diamond/plumb center weight, subtle tapered brush-nib tips; narrow vertical silhouette around 1:3 width-to-height; generous green padding; no rail.
Color palette: bright neutral pale brass, ivory-gold highlights, charcoal ink recesses only. Keep it neutral so runtime red/blue color modulation remains legible.
Materials/textures: hammered brass, lacquered ink nib, restrained engraved detail, clean hard edges.
Constraints: no colored aura, no baked glow, no cast shadow, no floor plane, no perspective; closed silhouette.
Avoid: text, numbers, glyphs, icons, characters, gameplay scene, red, blue, green within the object, watermark, logo, neon, sci-fi, gradient or texture in the #00ff00 background.
```

소형 UI 포인터가 아니라 긴 무기 전체처럼 생성되어 거부했다.

## 4. 틱 v1 - 승인 후보

트랙 프레임 v1은 재질 참고 이미지로만 제공했다.

```text
Use case: stylized-concept
Asset type: production game HUD component, reusable timing-gauge boundary tick
Input image: visual style and material reference only; do not copy the long rail or its end ornaments.
Primary request: Create a new, separate, extremely compact vertical divider tick for the referenced Korean-fantasy timing-gauge frame.
Scene/backdrop: genuinely transparent background with clean alpha.
Style/medium: match the reference's carved dark walnut, aged brass, tiny restrained cinnabar binding, crisp hand-painted 2D UI finish.
Composition/framing: exactly one short front-view UI tick centered with generous transparent padding. Overall silhouette about 1:5 width-to-height. A thin straight brass stem with a tiny square cap above, a tiny square cap below, and a small dark-wood clamp at the middle where it crosses the gauge rail. It should read clearly at 8 by 41 runtime pixels.
Constraints: simple reusable boundary divider, hard clean edges, no shadow, no glow, no halo, no floor plane, no rail.
Avoid: weapon, spear, sword, arrowhead, staff, long pole, cloud motif, dragon head, text, numbers, glyphs, characters, gameplay scene, judgment colors, watermark, logo, neon, sci-fi.
```

생성기가 흰색 중성 체크무늬를 RGB에 구워 반환했으므로 전용
`remove_bg.py`로 제거했다. 8x41 목표에서 경계선으로 읽혀 채택했다.

## 5. 중심추 v1 - 거부

트랙 프레임 v1은 재질 참고 이미지로만 제공했다.

```text
Use case: stylized-concept
Asset type: production game HUD component, moving timing-gauge slider thumb
Input image: visual style and material reference only; do not copy the long rail or its end ornaments.
Primary request: Create a new, separate, compact moving slider-thumb marker for the referenced Korean-fantasy training timing gauge.
Scene/backdrop: genuinely transparent background with clean alpha.
Style/medium: match the reference's aged-brass edgework and dark ink-lacquer recess, crisp hand-painted 2D UI finish.
Composition/framing: exactly one compact front-view vertical marker centered with generous transparent padding. Overall silhouette about 1:2.7 width-to-height. A small bright neutral brass diamond/plumb weight at center, one short thin stem upward ending in a tiny flat clamp tab, and one short thin stem downward ending in a restrained black-ink brush-nib tab. The top and bottom tabs should overhang a horizontal track slightly. It should read clearly at about 14 by 43 runtime pixels.
Color palette: pale neutral brass, ivory-gold highlights, charcoal ink recesses. No cinnabar, red, blue, or colored aura, because runtime modulate supplies judgment color.
Constraints: compact UI slider thumb, hard clean silhouette, no shadow, no glow, no halo, no floor plane, no rail.
Avoid: weapon, spear, halberd, sword, arrow, staff, long pole, ornate cloud wings, dragon head, text, numbers, glyphs, characters, gameplay scene, watermark, logo, neon, sci-fi.
```

배경 제거는 통과했지만 넓은 방패형 판이 중심추보다 장식판으로 읽혀 거부했다.

## 6. 중심추 v2 - 승인 후보

중심추 v1을 편집 대상으로 사용해 넓은 판만 제거했다.

```text
Use case: precise-object-edit
Asset type: production game HUD component, moving timing-gauge slider thumb
Input image: edit target.
Primary request: Change only the silhouette and simplify it into a narrow timing-gauge pointer. Remove the entire broad shield-shaped black backplate and all wide scrollwork wings.
Keep unchanged: aged neutral brass material, ivory highlight, charcoal ink brush-nib detail, front-view lighting, no red or blue.
New shape: a tiny flat brass clamp tab at the top, a short thin central stem, one compact faceted brass plumb diamond at the exact center, another short thin stem, and a small tapered black-ink brush-nib tab at the bottom. Overall silhouette must be narrow and about 1:3.2 width-to-height. The center diamond may be only 1.6 times the stem width. It must read as a moving slider thumb at 12 by 43 runtime pixels, not as a plaque.
Scene/backdrop: genuinely transparent background with clean alpha and generous padding.
Constraints: no shadow, no glow, no halo, no floor plane, no rail.
Avoid: shield, plaque, weapon, spear, arrow, sword, halberd, staff, wings, cloud curls, dragon, text, glyphs, watermark, logo, neon, sci-fi.
```

중성 황동 추, 짧은 축, 먹 붓촉이 12x43 목표에서 분리되어 보여 채택했다.
