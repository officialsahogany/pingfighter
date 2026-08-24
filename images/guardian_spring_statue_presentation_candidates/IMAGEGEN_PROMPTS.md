# 샘터 석상 씬·캡슐 A단계 이미지 생성 프롬프트

- 모드: built-in `image_gen`
- 기준 커밋: `c6038daeb198e74b6cebdf269fb254895ebf1d7a`
- 생성 정책: 서로 다른 자산/변형마다 별도 호출
- 런타임 등록: 없음

## 공통 참조 이미지

- 환경 미술·팔레트 참조:
  `godot/assets/sprites/tower/noncombat/guardian_spring_arena_background_imagegen_v1.png`
- 샘터 모티프 참조:
  `godot/assets/sprites/tower/map_icons/node_guardian_spring_imagegen_v1.png`
- 캡슐 내부 비침·비율 검토 참조:
  `nekuring_cutin_art.png`, `rabi_cutin_art_sd_identity_v3_clean.png`

참조 이미지는 스타일·팔레트·컷인 비율 참조에만 사용했다. 기존 이미지를
덮어쓰거나 런타임 자산으로 편집하지 않았다.

## 배경 A — 추천

```text
Use case: stylized-concept
Asset type: 2D game environment background candidate for a 760x750 fullscreen Godot scene
Input images: Image 1 is a style and palette reference only; create a new scene, do not edit or copy its composition
Primary request: a mystical Korean guardian spring sanctuary with a sacred natural fountain, rolling mist, and Joseon garden atmosphere
Scene/backdrop: secluded mountain spring enclosed by weathered stone walls, pines, moss, shallow jade water channels, a restrained hanok gate and tiled eaves in the distance
Style/medium: polished hand-painted Korean fantasy game environment, painterly detail and clean readable shapes, consistent with Image 1
Composition/framing: near-square 760x750 gameplay canvas, slightly elevated frontal view; keep a large clear low-contrast placement zone centered in the lower-middle from roughly 32% to 72% of canvas width and 50% to 88% of canvas height for a separate rock statue; paths and water visually lead toward that empty zone; no object occupies it
Lighting/mood: mysterious dawn light, soft teal and pale jade spring glow, drifting volumetric mist, sacred and inviting
Color palette: deep pine green, weathered gray stone, muted celadon, pale jade water, small warm brass accents
Materials/textures: wet granite, moss, old roof tile, hanji-like painterly grain, translucent mist
Constraints: background only; no statue, no character, no spirit creature, no card, no UI frame, no text, no letters, no symbols, no watermark; no circular magic sigil; no closed ring or dotted ring; no modern architecture; no border; no black void; preserve strong silhouette separation around the reserved statue zone
Output intent: approval-stage candidate source; intended final review crop is exactly 760x750
```

## 배경 B — 거부

```text
Use case: stylized-concept
Asset type: 2D game environment background candidate for a 760x750 fullscreen Godot scene
Input images: Image 1 is a style and palette reference only; create a new scene, do not edit or copy its composition
Primary request: an intimate moonlit Korean sacred spring garden with ethereal fog and an ancient stone terrace
Scene/backdrop: hidden Joseon-era garden among cliffs, cascading spring water at the far sides, pine silhouettes, low stone balustrades and a small distant pavilion, mist drifting between layers
Style/medium: premium hand-painted Korean fantasy game backdrop with elegant brush texture and game-readable depth, consistent with Image 1
Composition/framing: near-square 760x750 canvas, eye-level to gently elevated view; upper half carries architecture and cliffs; reserve an uncluttered central lower stone-and-mist stage for a separate statue, roughly x=240..520 and y=380..680; do not place a focal object there
Lighting/mood: moon-before-dawn ambience, luminous turquoise water, pearly mist, quiet numinous atmosphere
Color palette: midnight teal, charcoal stone, jade and celadon, soft moon cream, restrained antique gold
Materials/textures: wet rock, rough granite, moss, aged wood, ceramic roof tiles, layered translucent fog
Constraints: background only; no statue, no character, no guardian creature, no cards or UI, no text, no watermark; no circular portal, halo, closed ring, dotted ring, runic circle, or flat graphic shapes; no modern objects; no frame or border; central lower zone remains calm and readable
Output intent: approval-stage candidate source; intended final review crop is exactly 760x750
```

## 석상 A — 추천

```text
Use case: stylized-concept
Asset type: isolated 2D game prop candidate, mystical Korean rock statue for a fullscreen interaction scene
Input images: Image 1 is the environment style/palette reference; Image 2 is a guardian-spring motif reference only
Primary request: one Joseon-fantasy sacred rock statue that invites a player to place a palm on it, blending jangseung guardian character, altar stone, and compact stone cairn sensibilities
Subject: a broad weathered granite guardian stele with a gentle ancient face, a clearly readable shallow palm-rest ledge at chest height, subtle carved water-and-cloud motifs, sturdy stacked-stone pedestal; mystical but not frightening
Style/medium: polished hand-painted Korean fantasy game prop, painterly with clean silhouette and readable 760x750 scene scale; compatible with Image 1
Composition/framing: single centered full object, three-quarter frontal view with slight top visibility on the palm ledge, fully contained, generous transparent padding, wide grounded base, no crop
Lighting/mood: cool jade spring light from within stone cracks, restrained numinous glow, weathered and benevolent
Color palette: charcoal gray and mossy granite, muted celadon, faint turquoise inner light, tiny antique brass offerings
Materials/textures: rough wet granite, softened carved edges, moss in crevices, mineral veins
Constraints: genuinely transparent background; exactly one statue; no environment, no character, no human hand, no text, no letters, no watermark; no circular halo, no closed magic ring, no dotted ring, no flat rectangular glow, no UI frame, no bright white outer aura; prop remains mostly opaque with clean alpha edges
Output intent: high-resolution approval-stage prop candidate to be scaled into the central lower area of a 760x750 scene
```

## 석상 B — 거부

```text
Use case: stylized-concept
Asset type: isolated 2D game prop candidate, hand-contact guardian spring idol
Input images: Image 1 is the environment style/palette reference; Image 2 is a guardian-spring motif reference only
Primary request: one compact Joseon-fantasy stone shrine idol, combining a jangseung-like guardian head with a sacred stacked doltap and a natural basin-like palm contact surface
Subject: low broad stone idol with a calm guardian-beast visage, asymmetrical stacked boulders, a prominent flat palm-sized offering surface facing the viewer, carved wave motifs and one narrow luminous mineral seam
Style/medium: premium hand-painted Korean fantasy game prop, storybook-realistic painterly rendering, bold readable silhouette, consistent with Image 1
Composition/framing: single centered full object in frontal three-quarter view, no crop, generous transparent margin, heavier and wider than tall, stable ground base
Lighting/mood: mystical celadon spring radiance, moist stone highlights, subtle sacred presence
Color palette: warm gray granite, ink-dark creases, moss green, pale jade core, restrained oxidized bronze
Materials/textures: layered river stone, old chisel marks, wet moss, translucent mineral vein
Constraints: genuinely transparent background; one statue only; no scene or floor, no person, no hand, no text, no watermark, no shrine gate; no circular halo, closed ring, dotted ring, rune circle, rectangular glow, card frame, or outer border; no bright outline around the entire silhouette
Output intent: high-resolution approval-stage prop candidate for a 760x750 game scene
```

## 석상 A 발광 오버레이 — 추천 RGB + 석상 A 알파 정본

```text
Use case: precise-object-edit
Asset type: separate hover-emissive overlay texture for a 2D game prop
Input images: Image 1 is the exact statue silhouette and alignment source
Primary request: transform Image 1 into a luminous hover overlay that aligns pixel-for-pixel with the same statue framing: retain the full physical statue silhouette, replace the statue interior with a bright filled jade-white energy core, and add fine celadon edge highlights and luminous mineral seams only inside the silhouette
Style/medium: hand-painted game emissive texture, soft layered jade light with a solid bright inner core, not a flat vector mask
Composition/framing: exact same canvas size, object position, scale, crop, and silhouette as Image 1
Color palette: pale jade, mint-celadon, warm ivory-white core, subtle antique-gold highlights
Constraints: genuinely transparent everywhere outside the statue silhouette; no glow pixels outside the silhouette; no rectangular halo, no full-canvas tint, no circular halo, no closed ring, no dotted ring, no background, no checkerboard pixels, no text, no watermark; the interior must be visibly filled and bright rather than hollow or only outlined; preserve all alignment landmarks including top stone, palm ledge, side cairns, basin, and base
Avoid: black or colored background, outer aura, drop shadow, neon outline-only treatment, flat rectangle, transparent empty core
```

생성 편집은 체크 무늬를 RGB에 구웠다. 따라서 추천 후보는 생성 결과의 발광
RGB만 사용하고 석상 A의 알파를 그대로 다시 적용했다. 알파 SHA-256과 완전
일치 여부는 `review/A_STAGE_QA.json`에 기록했다.

## 캡슐 A — 거부

```text
Use case: stylized-concept
Asset type: isolated transparent 2D game UI capsule frame overlay for guardian-character selection
Input images: Image 1 is the environment palette/style reference; Images 2 and 3 show the varied guardian cutin proportions that must remain visible behind the frame; do not include or redraw those characters
Primary request: one empty tall floating spirit capsule frame, a translucent glass sphere stretched into a gentle vertical oval with restrained Joseon-fantasy bronze fittings and cloud-water motifs
Subject: clear empty central viewing chamber, very thin celadon glass shell, strong curved surface highlights, small antique-gold cap and base ornaments, subtle jade energy at the bottom
Style/medium: premium hand-painted game UI chrome, dimensional transparent glass, elegant Korean fantasy ornament, readable when shown three copies side by side
Composition/framing: one centered vertical capsule only, portrait proportion about 0.68 width to 1 height, full object visible with generous transparent padding; frame hugs outer perimeter; central 72% width and 74% height stays visually clear for a guardian cutin
Lighting/mood: soft jade inner glow and pearly specular highlights, mystical and calm
Color palette: translucent celadon and pale turquoise glass, antique brass, small warm ivory highlights
Materials/textures: transparent curved glass, aged bronze, polished jade accents
Constraints: genuinely transparent outside the capsule; no character, no creature, no text, no icon, no card rectangle, no solid backplate, no opaque interior fill, no checkerboard pixels, no watermark; no circular magic ring, no dotted ring, no closed ritual circle, no flat rectangular halo; side-by-side readability at about 200x360 pixels
Output intent: approval-stage single-frame overlay asset reused for each of three floating guardian presentations
```

## 캡슐 B — 추천

```text
Use case: stylized-concept
Asset type: isolated transparent 2D game UI spirit-vessel frame overlay
Input images: Image 1 is the environment palette/style reference; Images 2 and 3 show guardian cutin scale diversity only; do not include their characters
Primary request: one empty floating spirit vessel shaped like a rounded jade seed capsule with a glassy central chamber, restrained doltap-stone crown and Joseon brass clasps
Subject: transparent central chamber, slim stone-and-bronze outer ribs, asymmetric painterly glass reflections, a softly lit plinth at the bottom, small cloud curls near the shoulders
Style/medium: hand-painted Korean fantasy game UI frame, organic and sacred rather than sci-fi, dimensional clear material
Composition/framing: single centered full capsule, vertical 3:4 proportion, no crop, generous transparent margin; unobstructed central window sized for a whole guardian character; legible as three copies across a 674-pixel-wide selection row
Lighting/mood: pale spring-water luminescence, subtle gold highlights, tranquil floating relic
Color palette: muted celadon, jade, wet gray stone, antique gold, pearl white
Materials/textures: translucent glass, polished jade, weathered carved stone, aged brass
Constraints: genuinely transparent outside; no character, animal, face, text, letters, watermark, card background, opaque backplate, rendered checkerboard, black backdrop; no magic-circle ring, dotted ring, closed loop VFX, rectangle halo, or neon sci-fi tube; interior must remain mostly see-through
Output intent: approval-stage single-frame overlay for three side-by-side guardian cutins
```

## 거부된 배경 추출 편집

```text
Use case: background-extraction
Asset type: transparent 2D game prop
Input images: Image 1 is the edit target
Primary request: remove the entire dark green gradient backdrop and every aura or haze outside the physical statue silhouette, producing a clean isolated statue on a genuinely transparent background
Constraints: change only the background and outside-silhouette glow; preserve the statue itself exactly, including its face, hand-shaped palm ledge, carved stones, moss, brass details, turquoise mineral seam, water drops, base proportions, lighting, colors, sharpness, and full framing; keep all physical pixels of the statue opaque or naturally antialiased; no recoloring, no redesign, no cropping, no added outline, no shadow, no text, no watermark
Avoid: colored matte, black backdrop, green backdrop, white backdrop, checkerboard rendered into pixels, halo outside the statue, glow spilling beyond the silhouette
```

거부 사유: 결과가 투명 알파가 아니라 체크 무늬가 픽셀에 구워진 24bpp RGB였다.
