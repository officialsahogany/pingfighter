# Tower map iconography S2 boss candidate prompt set

Generator: built-in IMAGEGEN. The user-approved S2 v2 noncombat sheet was used
as the style reference for every call. The final 14 icons were generated one at
a time. No unified sheet generation or manually painted alpha mask was used.

## Canonical production method

1. Generate one icon on a palette-safe flat key background.
2. Use magenta when the icon contains no pink, purple, or rose. Use green when
   the icon contains those colors and no green, lime, jade, teal, or cyan.
3. Run `.claude/skills/sprite-generation/chroma_key.py` with the explicit key
   and `--pad 12`.
4. Reject any source whose cleaned alpha retains key-family pixels. Do not erase
   an enclosed pocket by hand.
5. Fit the clean alpha into a 30x30 content box inside the actual 32x32 cell,
   then inspect nearest-neighbor 8x views on both dark and light backgrounds.

The key is deliberately chosen per icon. A single global key is not the
canonical route because it would collide with either the lime/green or
pink/rose boss palettes.

## Shared prompt contract

```text
Use the approved S2 v2 sheet as a style reference only. Create exactly one
anonymous boss-node map icon for the Korean fantasy martial-arts game. Match the
bold black ink contour, broad flat painted masses, subtle traditional material
texture, and crisp 32px UI readability. Use one compact asymmetric omen object,
only two to four large interior shapes, a generous clean margin, and no thin
trim, tiny debris, glow, aura, particles, or micro-engraving. The icon must leave
an impression without revealing a named boss identity. No creature, face,
weapon, boss-specific object, recognizable crest, name-inferable motif, text,
letters, Hangul, Chinese characters, digits, runes, labels, question marks,
watermarks, signatures, logos, border, or frame.
```

Each call also required a perfectly flat, edge-to-edge `#ff00ff` or `#00ff00`
background with no checkerboard, transparency, gradient, texture, floor,
shadow, lighting, or glow. The chosen key family was explicitly excluded from
the painted object.

## Final boss deltas and grid order

The table order is also the 5-column QA board order, left to right and then top
to bottom. The last cell is intentionally empty.

| # | `boss_id` | dominant accent | key | anonymous silhouette delta |
|---:|---|---|---|---|
| 1 | `dalji` | electric cobalt | magenta | three uneven blunt lacquer slabs on a small black stone base; no moon or circular emblem |
| 2 | `gaksital` | bright azure | magenta | two offset broad folded planes around a dark oval core; no face or mask marks |
| 3 | `podo` | arctic ice blue | magenta | one split three-part monolith with a heavy ink fissure |
| 4 | `cheongringwi` | ultramarine | magenta | four broad inward planes around an empty dark center; no lettering |
| 5 | `molewang` | pale periwinkle | magenta | low layered trapezoid mass with two blunt side weights |
| 6 | `arachne` | cool powder pink | green | one lopsided rounded pebble with two broad ink fissures; no radial form or appendages |
| 7 | `yeonmyo` | acid yellow-lime | magenta | four broad smoke-like lobes around an irregular black pebble |
| 8 | `teddy_bear` | powder blue | magenta | one flattened disk split into two unequal halves by a diagonal ink fissure; no paw or toy motif |
| 9 | `alice` | saturated hot rose | green | three interlocked asymmetric lacquer slabs with one broad black divide |
| 10 | `ponk` | green chartreuse | magenta | three offset blunt wedges; no writing-like curl or digit |
| 11 | `hongryun` | steel blue-gray | magenta | two narrow leaning plates forming an asymmetric tall split silhouette |
| 12 | `tetriser` | electric blue-violet | green | one irregular folded silk shard with a diagonal black fold; no grid, blocks, or right angles |
| 13 | `akamu_rigo` | cold silver | magenta | three broad swept metal plates in a staggered diagonal stack |
| 14 | `minotaur` | cold porcelain white | magenta | two uneven rounded river stones joined by one broad black band; no horns, skull, or V shape |

The noncombat accents remain gold, cinnabar, mulberry, jade/turquoise, orange,
and cream. Boss colors use colder blues, pinks, yellow-limes, violet, and cool
neutrals. Their 32px values and silhouettes were judged together on the
20-icon collision board rather than in isolated full-resolution views.

## Rejected sources retained as provenance

| file suffix | rejection reason |
|---|---|
| `dalji_*_reject_pocket.png` | thin brush tip enclosed 40 pixels of magenta key |
| `dalji_*_reject_crescent.png` | crescent arrangement could suggest a name-linked motif |
| `arachne_*_reject_radial.png` | radial hooked appendages suggested an arachnid |
| `arachne_*_reject_hot_rose.png` | 32px color collided with `alice` hot rose |
| `teddy_bear_*_reject_pocket.png` | enclosed magenta center pocket and circuit-like detail |
| `teddy_bear_*_reject_paw.png` | four-lobed silhouette could read as a paw |
| `ponk_*_reject_glyph.png` | pale ornament read like a glyph |
| `ponk_*_reject_digit.png` | curved loop read like the digit 6 |
| `tetriser_*_reject_grid.png` | square spiral exposed the name-linked block motif |
| `minotaur_*_reject_horns.png` | V-shaped white silhouette suggested horns |

Rejected sources are not included in the alpha sheet or either 32px QA board.

## Approval boundary

Everything in this directory remains documentation-only candidate material.
No file is copied into `godot/assets/`, no `.import` sidecar is generated, and
no S3 runtime map wiring is performed until the user explicitly approves the
boss candidate board for promotion.
