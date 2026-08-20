# Tower map iconography S2 v3 boss candidate prompt set

Generator: built-in IMAGEGEN. The approved S2 v2 noncombat sheet was the style
reference. Production boss art and procedural renderers were inspected for
identity before each boss prompt was written. Every icon was generated as an
individual candidate.

## Corrected canon reading

The boss icon always exposes a unique visual identity. Only the boss name text
is hidden. Creature, weapon, element, costume, and prop motifs are therefore
allowed and preferred. The prohibited material is limited to text, numbers,
writing-like marks, a symbol that directly spells or labels the name, logos,
signatures, and watermarks.

The common prompt contract was:

```text
Create exactly one 32px tower-map boss icon candidate. Match the approved S2 v2
family: bold black ink contour, broad flat lacquer and hanji color masses, a
compact Korean-fantasy silhouette, and minimal internal detail. Use a concrete
motif from the production boss identity. Keep three to five large shapes and
make all parts touch or overlap into one connected emblem. No micro-detail,
thin cords, detached specks, glow, aura, cast shadow, scenery, frame, text,
letters, Hangul, Chinese characters, numbers, runes, writing-like marks,
watermark, signature, or logo. Use a perfectly flat palette-safe green or
magenta background to every edge, and exclude that key family from the subject.
```

## Global family-pair plan

The 20-icon board is ordered in adjacent family pairs. Every broad family is
used exactly twice. Within each pair, hue or value shifts support a deliberately
different silhouette.

| board pair | family | approved noncombat or first icon | paired boss or second icon | silhouette separation |
|---:|---|---|---|---|
| 1 | gold | shop, bright chest and coins | `ponk`, tall horned mask and three beads | wide box vs tall mask |
| 2 | red | training, post and sash | `gaksital`, red mask and fan | upright post vs wide face and fan |
| 3 | purple | fallen monk, satgat and staff | `tetriser`, blue-violet block spiral | diagonal figure vs angular square |
| 4 | green | guardian spring, basin and plume | `cheongringwi`, moss turtle-dragon and paddle | upright basin vs low reptile mass |
| 5 | orange | rest, campfire shelter | `hongryun`, scarlet fire-beast head | squat triangle vs swept asymmetric flame |
| 6 | cream | map hint, parchment | `minotaur`, ivory horns and axe | scroll rectangle vs wide bull horns |
| 7 | blue | `podo`, deep-navy gat and baton | `alice`, sky bow, mirror, rabbit ears | wide horizontal hat vs tall ears and oval |
| 8 | pink | `arachne`, eight-leg radial spider | `yeonmyo`, round cat nurse and paw | radial legs vs compact head |
| 9 | brown | `molewang`, crown and three claws | `teddy_bear`, round ears and stitched face | low claw triangle vs round toy head |
| 10 | neutral | `dalji`, black hat, white ribbon, drum | `akamu_rigo`, steel shuriken and hood | sweeping hat and sash vs sharp X |

## Final boss deltas and key choice

| floor order | `boss_id` | concrete identity motif | broad family | key |
|---:|---|---|---|---|
| 1 | `dalji` | black sangmo hat, open white ribbon, janggu | neutral | magenta |
| 2 | `gaksital` | red Hahoe-style mask and folding fan | red | green |
| 3 | `podo` | wide navy gat, solid baton, solid badge | blue | magenta |
| 4 | `cheongringwi` | moss turtle-dragon head, shell, paddle | green | magenta |
| 5 | `molewang` | crowned mole, mound, three ivory claws | brown | green |
| 6 | `arachne` | black abdomen and exactly eight hot-pink legs | pink | green |
| 7 | `yeonmyo` | pink cat nurse head, blank cap, large paw | pink | green |
| 8 | `teddy_bear` | caramel stitched bear, heart patch, button eye | brown | green |
| 9 | `alice` | sky-blue bow, gold mirror, two rabbit ears | blue | magenta |
| 10 | `ponk` | tall ivory oni mask, horns, three gold beads | gold | magenta |
| 11 | `hongryun` | scarlet-orange fire-beast head and black hair | orange | green |
| 12 | `tetriser` | resurrected blue-violet block spiral | purple | green |
| 13 | `akamu_rigo` | steel four-point shuriken and charcoal hood | neutral | green |
| 14 | `minotaur` | brown bull head, huge ivory horns, axe blade | cream | magenta |

## Palette-safe chroma route

1. Choose green only when the subject palette contains no green, jade, teal, or
   lime. Choose magenta only when it contains no pink, rose, or purple.
2. Run `.claude/skills/sprite-generation/chroma_key.py` with the explicit key
   and `--pad 12`.
3. Reject the source if the cleaned alpha retains any visible key-family pixel
   or any nontransparent outer-edge pixel.
4. Never erase an enclosed pocket or paint an alpha mask by hand. Regenerate a
   simpler connected silhouette instead.
5. Fit the alpha into a 30x30 content box in the actual 32x32 cell. Inspect both
   dark and light boards before inspecting the large source.

## Reconsidered and rejected provenance

The old abstract candidates were not rejected merely because they revealed a
creature, prop, element, or weapon. They were reconsidered under the corrected
canon:

| source or concept | v3 decision |
|---|---|
| `s2_boss_tetriser_raw_green_reject_grid.png` | restored unchanged as the final v3 block motif |
| `s2_boss_arachne_raw_green_reject_radial.png` | radial spider direction restored, then regenerated because the source had six hooks rather than a clear eight-leg spider |
| `s2_boss_minotaur_raw_magenta_reject_horns.png` | horn direction restored, then regenerated because the source still read as a stone shard instead of a bull |
| `s2_boss_teddy_bear_raw_magenta_reject_paw.png` | paw motif is allowed, but this source created a third blue-family icon and did not convey the stitched toy identity |
| old `dalji` crescent | remains rejected because it did not convey Dalji's production identity, not because boss-specific motifs are forbidden |
| old `ponk` glyph and digit variants | remain rejected because writing-like marks and digits are still prohibited |

The first v3 Dalji sources left green or magenta pockets between separated
parts. The first v3 Podo retained 65 magenta-family pixels. The first v3 Ponk
measured only 21.96% gold. All were retained with descriptive `reject_*`
suffixes and regenerated without manual cleanup.

## Approval boundary

All v3 files remain documentation-only candidates. Nothing is copied into
`godot/assets/`, no `.import` sidecar is created, and S3 map wiring remains
untouched until the user explicitly approves promotion.
