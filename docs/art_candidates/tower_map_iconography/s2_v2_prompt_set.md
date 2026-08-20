# Tower map iconography S2 v2 prompt set

Generator: built-in IMAGEGEN. CLI/API fallback was not used.

The accepted-direction v1 sheet was used only as a style reference. The six
v2 subjects were generated one at a time so the background around each
silhouette stayed connected. Each final call was assembled from the common
block, one subject block, and the matching chroma block below.

## Common block

```text
Use case: stylized-concept
Asset type: single 32px tower-map UI icon candidate for the Korean fantasy martial-arts game 환격전
Input image: style reference only. Match its bold black ink outline, broad flat color masses, subtle material texture, camera angle, and ceremonial Korean-fantasy family.
Composition: exactly one centered isolated object, filling about 72 percent of a square canvas, generous clean margin, extremely simple outer silhouette, only 2-4 large interior shapes. Designed to be unmistakable when reduced to 32x32.
Style: crisp hard-edged game UI icon, thick black ink contour, 16-bit-inspired readability but not literal pixel art; same approved 환격전 icon family.
Constraints: all pixels of the object fully inside canvas; no glow halo, aura, particles, soft shimmer, thin trim, micro-engraving, or detached tiny debris.
Avoid: text, letters, Hangul, Chinese characters, numbers, runes, labels, question marks, writing-like emblems, watermarks, signatures, logos, borders, frames, cyberpunk, neon, science fiction, photorealism.
```

## Palette-safe chroma blocks

Magenta, used for shop, guardian spring, and rest:

```text
Background: perfectly flat, uniform solid chroma-key magenta #ff00ff to every canvas edge. No checkerboard, no transparency, no gradient, no texture, no floor, no cast shadow, no lighting or glow on the background.
Avoid any pink, magenta, purple, rose, or fuchsia inside the object.
```

Green, used for training, fallen monk, and map hint:

```text
Background: perfectly flat, uniform solid chroma-key green #00ff00 to every canvas edge. No checkerboard, no transparency, no gradient, no texture, no floor, no cast shadow, no lighting or glow on the background.
Avoid any green, lime, jade, turquoise, teal, cyan, or chartreuse inside the object.
```

## Final subject blocks

Shop:

```text
Subject: SHOP only — one wide open dark-lacquer merchant chest dominated by three oversized bright golden coins or ingots. Make saturated yellow-gold the immediate visual read, not brown wood. Gold must cover at least 45 percent of the painted object silhouette.
```

Training:

```text
Subject: TRAINING only — one broad wooden martial-arts striking post with two extremely clear thick side arms, wrapped by one very large cinnabar-red training sash/banner whose broad red body and two chunky tails dominate the icon. Cinnabar red must cover at least 40 percent of the painted object silhouette. The two side arms must remain unmistakable at 32x32; never read as a plain vertical stick.
```

Fallen monk, initial generation:

```text
Subject: FALLEN MONK only — no person and no face: one huge ink-gray conical satgat hat forming a wide triangular cap, one bold crooked pilgrim staff on the right, and one large deep mulberry-purple torn mantle flowing under the hat as a single solid mass. Replace the begging bowl and prayer beads entirely. Deep mulberry-purple alone must cover at least 40 percent of the painted object silhouette; ink-gray plus purple must dominate. The outer contour must never resemble a bowl, chest, coin ring, or necklace.
Avoid begging bowl, prayer beads, face, or body.
```

Fallen monk, final targeted edit:

```text
Change only the color-area balance and relative mass. Preserve the same FALLEN MONK identity, same satgat + crooked staff + torn mantle silhouette, same thick black ink style, same camera, same square composition, and same flat green background.
Make the deep mulberry-purple mantle much larger and broader so purple covers at least 55 percent of the painted object silhouette and still at least 40 percent after reduction to 32x32. Shrink the ink-gray satgat slightly and make the gray staff slightly narrower. Keep the purple as one large contiguous mass, not thin strips. Maintain a clear wide satgat and crooked staff silhouette.
```

Guardian spring:

```text
Subject: GUARDIAN SPRING only — one broad jade-green carved spring basin with one single chunky upward turquoise water plume. Keep the basin silhouette wide and compact. Jade green plus turquoise must cover at least 55 percent of the painted object silhouette. Simplify the carved guardian face to two or three broad marks only; no micro-detail.
```

Rest, initial generation:

```text
Subject: REST only — one very large compact bright-orange campfire flame beneath a drastically simplified folded cream-hanji lean-to made from two broad paper planes. Bright orange must cover at least 40 percent of the painted object silhouette. Keep stones and logs to only a few chunky shapes; the orange flame is the immediate read.
```

Rest, final targeted edit:

```text
Change only the color-area balance and relative mass. Preserve the same REST identity, same campfire-under-simple-hanji-shelter silhouette, same thick black ink style, same camera, same square composition, and same flat magenta background.
Make the bright-orange flame dramatically larger and broader so orange covers at least 55 percent of the painted object silhouette and still at least 40 percent after reduction to 32x32. Reduce the cream shelter to two narrower broad side planes, and reduce the stones/logs to a minimal chunky base. Keep orange as one huge contiguous central mass, not thin tongues or sparks.
```

Map hint:

```text
Subject: MAP HINT only — one large cream-hanji rolled map with one bold pictorial ascending dotted route made from large cinnabar dots and only two simplified dark mountain wedges. Cream parchment must cover at least 65 percent of the painted object silhouette. The path is purely pictorial and contains no writing of any kind.
```

## Rejected route probe

Before the individual-keyed set, IMAGEGEN was asked for one unified 3x2 sheet
with genuine transparent alpha. The returned 1536x1024 PNG was RGB-only and
contained a baked checkerboard. That route is not suitable for production and
was not kept as a project candidate.
