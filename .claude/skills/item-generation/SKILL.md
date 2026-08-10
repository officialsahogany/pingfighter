---
name: item-generation
description: |
  Item visual generation pipeline for 환격전. Covers active item icons,
  passive item icons, legendary / mythic item icons (empty_legendary
  frame rules), character paddle-part equip visuals, mood-based glow /
  border / particle rules, Claude-ready copy-paste prompts, and the
  reject / regenerate QA checklist. This skill ONLY owns visual asset
  creation for items. Runtime integration (Godot item registration, shop /
  gacha / crane / treasure hunt, active vs passive routing, roll
  options, polish perks, enhancement buffs, equip visual wiring) lives
  in docs/item_runtime_checklist.md and is NOT covered here. Boss /
  character sprite sheets live in the sprite-generation skill and are
  NOT covered here. Use this skill whenever the user asks to create,
  regenerate, redraw, or fix an item icon, an active / passive / legendary
  item visual, a character paddle-part equip visual, or item mood /
  theme art. 한국어 트리거 키워드 - 아이템 아이콘, 액티브 아이콘, 패시브 아이콘,
  전설 아이콘, 신화 아이콘, 장착 외형, 파츠 외형, 아이템 파티클, empty_legendary,
  아이템 비주얼, 아이템 프롬프트, 아이템 제작.
---

# Item Generation Pipeline (환격전)

Asset-generation plays for **item icons** and **character equip visuals**.
Current runtime target is the Godot project **환격전** under
`godot/`. Original Python/Pygame PingFighter item paths are legacy porting
references only.
Runtime integration is NOT covered here — hand off to
`docs/item_runtime_checklist.md` after the asset is accepted.

Companion files in this skill directory:

- `references/active_icon_prompt.md` — copy-paste active item icon prompt
- `references/passive_icon_prompt.md` — copy-paste passive item icon prompt
- `references/legendary_icon_prompt.md` — copy-paste legendary / mythic icon prompt
- `references/equip_visual_prompt.md` — character paddle-part equip visual prompt
- `references/mood_palette.md` — theme → palette / glow / particle mapping

---

## 0. Scope boundary (do not confuse with sprite-generation)

This skill is narrow. Stay inside it.

Runtime character perk / skill work does NOT belong here. Use
`docs/character_skill_perk_checklist.md` for unlock perks, player-skill /
5-orb HUD integration, tooltip sync, skill-gold reward policy, and
save/load/reset audits. That checklist §4-§5 owns the companion
`draw_skill_icon_mini()`, perk-text, tooltip, and cooldown invariants.

If the report is "an invested passive should also show synergy text in
the affected active-skill / orb tooltip," treat that as runtime
character perk / skill integration too. It belongs in
`docs/character_skill_perk_checklist.md`, not in this
item-asset skill.

If the report is "a skill / perk icon still looks too small," "the HUD
version and perk-card version do not match," or "the skill orb rim /
alpha edge looks dirty in the live HUD," treat that as runtime character
perk / skill integration, not item-asset work. The fix belongs in
`docs/character_skill_perk_checklist.md` and must audit:

- `draw_skill_icon_mini()`
- `_draw_skill_icon_symbol()`
- live id aliases (`perk id`, unlock id, runtime skill id, legacy id)
- unlock-style alias pairs (`unlock_*` perk-card id plus equipped
  5-orb skill id), including any unlock badge overlay expected on the
  card / offer path
- perceived subject size at the smallest real UI box
- PNG alpha / padding / draw-size behavior in the real HUD orb slot

A generated mockup, PNG, or one successful large-card preview is not
enough to call a runtime character perk / skill icon "done."

| Question | Answer |
|---|---|
| Boss walk / attack / dash / turn sheet? | **sprite-generation skill** (not here) |
| Boss or character nukki (PNG background removal)? | **sprite-generation skill** (not here) |
| Item icon (active / passive / legendary)? | **this skill** |
| Character paddle-part visual for an equipped item? | **this skill** |
| Wiring the item into `items.py`, shop, gacha, reset, rolls? | **`docs/item_runtime_checklist.md`** (not here) |
| Registering a new viper perk / skill icon? | `docs/character_skill_perk_checklist.md` §4 — not here |

Routing override:
- Any runtime character perk / skill icon registration or size/readability
  fix should route through
  `docs/character_skill_perk_checklist.md`, not this skill.
- That review must cover mini icon rendering, orb symbol rendering, live id
  aliases, and the smallest real UI box where the icon appears.
- If the asset was created with imagegen for a runtime perk / skill icon,
  do not stop at the generated preview. Copy the selected PNG into the repo,
  wire a PNG-first loader/cache path, and verify no procedural fallback or
  special-case early return bypasses the new file.
- If the visual request is for a one-shot / instant-trigger runtime perk
  (`instant_*` ids or similar immediate reward effects), treat the default
  deliverable as an 8-frame horizontal PNG icon sheet, not a static-only
  icon, unless the user explicitly asks for a still. Preserve the accepted
  static PNG as the identity anchor and fallback; animate charge, glow,
  sweep, sparkle, portal, reward, or item-spill motion around that motif.
  Save the sibling sheet as `items/<perk_id>_perk_icon_sheet.png` and hand
  off the runtime requirement: sheet-first loader/cache, static PNG
  fallback, procedural fallback last, plus alpha / small-grid label checks.
- For generated PNG perk / skill icons, validate the smallest live UI box,
  especially 32 px TAB character-info perk cells and academy / NPC offer
  grids. Clamp the draw size to the owning cell; a large-card
  `scale_multiplier` must not let the icon bleed outside its box or cover
  the bottom level label. In the TAB character-info perk tab, use the
  current `dash_module_control` / `모듈제어` icon as the preferred small-cell
  size reference: present and polished, but not overlapping `Lv.1` /
  `Lv.5` text.
- When the runtime renderer is `draw_skill_icon_mini()`, prefer the repo's
  per-id small-cell sizing helper (currently
  `_get_small_cell_perk_icon_size()`) or an equivalent clamp for generated
  PNGs before scaling them. Baked circular rims / glows and source padding
  need their own draw-size check in both directions: shrink if the rim or
  glow crowds labels, enlarge if the central motif reads smaller than
  neighboring icons. Verify both `Lv.1` and `Lv.5` labels, because a good
  large-card preview can still hide the TAB-level text or a too-small
  subject-fill read.
- Before producing or selecting a runtime perk / skill icon asset, classify
  the visual family and hand that classification to the runtime checklist:
  character-exclusive active-skill / unlock perk, character passive /
  enhancer skill perk, or basic shared perk. Character-exclusive active and
  passive/enhancer skill perks should keep the established round / orb-style
  language; basic shared perks may use freer object / symbol silhouettes.
- For a 5-orb skill unlocked by a perk, that review must cover both the
  runtime skill id shown in the orb HUD and the `unlock_*` perk id shown
  in perk cards, academy / NPC offers, and swap / status panels. Reusing
  the accepted PNG for only the orb HUD while leaving the unlock card on
  stale procedural art is incomplete.
- Any runtime character perk / skill tooltip-synergy fix should also
  route there. Audit the target orb tooltip / bonus-line helper, the
  effective values that feed it, and the limited shared line budget when
  multiple enhancers can affect the same skill.
- If the symptom is "after adding synergy text, the control hint or
  effect preview became hard to read," that is still runtime character
  perk / skill work. Route it to
  `docs/character_skill_perk_checklist.md` and audit the
  tooltip's real rendered-height / section-layout budget, not only the
  text copy.
- If the symptom is "the TAB character-info perk tooltip clips when the
  perk is in the first row / panel edge," that is also runtime
  character perk / skill work. Route it to
  `docs/character_skill_perk_checklist.md` and audit the
  grid-hover tooltip's rect-anchored placement, wrap width, and panel /
  viewport clamp behavior.
- If the symptom is "the tooltip string contains `\\n` but renders like
  one flattened paragraph" or "a newly appended synergy line exists in
  the list but is invisible on screen," that is still runtime character
  perk / skill work. Route it to
  `docs/character_skill_perk_checklist.md` and audit the
  shared `_get_wrapped_tooltip_lines()` path plus the real rendered
  shared-budget / max-invested tooltip state.

Upscaling override:
- If the user asks to "upscale", "upscaling", "hires", "업스케일",
  "업스케일링", or "real / Real-ESRGAN처럼" for an item icon, perk icon,
  skill icon, equip visual, or item animation sheet, run the Real-ESRGAN
  upscale gate in `.claude/skills/sprite-generation/checklists.md` §0.1.
- Do not treat icon draw-size tuning, Godot import filtering, ordinary
  resampling, or imagegen repainting as completion of an upscale request.
- Preserve transparent corners by upscaling RGB separately from alpha and
  recombining the resized source alpha before final 32 / 64 px HUD-scale QA.

Legacy wording note: the Viper-specific row in the table above is
representative only. For any runtime character perk / skill integration
work, use `docs/character_skill_perk_checklist.md` first; its §4-§5 are the
companion icon, tooltip, text-path, and cooldown trap reference.

**Do not import boss / character sprite-sheet rules (scale lock,
turn-sheet layout, front-biased walk, etc.) into this skill.** Item icons
are flat 32 or 64 px single-cell renders; cross-sheet identity lock is not
relevant. The instant-trigger perk icon sheet exception above is a runtime
perk-icon handoff rule, not a boss sprite or normal item-icon rule.

---

## 1. When to use this skill

Trigger on any of these user intents:

- If the user says "그려줘", "그려달라", "draw", or "make an icon" for an
  item / perk / skill icon or equip visual, use imagegen to create or edit
  a bitmap asset first. Do not substitute procedural code-drawn art or a
  placeholder unless the user explicitly asks for code-drawn art or accepts a
  fallback after imagegen is blocked.
- Create a new item icon (active / passive / legendary / mythic)
- Regenerate or repaint an item icon that reads poorly in HUD
- Draw a character paddle-part equip visual for a new passive item
- Decide the glow / border / particle mood for an item's theme
- Prepare a Claude-ready prompt to hand to Gemini MCP for an item asset
- Resolve the `empty_legendary` frame convention for a new legendary icon

If the user is wiring item runtime behavior, acquisition routes, shop / gacha
/ crane / treasure-hunt equivalents, reset flow, or roll options — that is
**`docs/item_runtime_checklist.md`** territory. Do not drive it from here.
Legacy Python files such as `items.py` are reference anchors only unless the
user explicitly asks for original PingFighter source work.
The same routing applies when the report is "runtime item scaling uses
the wrong level basis / wrong per-level constant" or "`Lv.6+`
description text dropped one of a perk's multiple effects." Those are
runtime item-integration bugs, not visual-asset bugs.
If the user is wiring a runtime character perk, unlock skill, 5-orb
skill HUD path, or deciding a new character skill's gold reward /
anti-double-pay behavior, that is
**`docs/character_skill_perk_checklist.md`** territory. Do not drive it
from here either.
The same routing applies when the task is "show this passive's runtime
synergy on the affected orb tooltip" rather than a new visual asset.
The same routing also applies when the task is "show this timed skill /
buff in the standard right-bottom horizontal timer bar" rather than a
new visual asset.

---

## 2. Role split (three-way source-of-truth)

| Document | Owns |
|---|---|
| `.claude/skills/item-generation/` (this) | Item icons, equip visuals, prompts, mood rules, icon QA |
| `docs/item_runtime_checklist.md` | Every code location that must be touched to make the item work at runtime |
| `CLAUDE.md` | Thin routing rule pointing at both of the above |

### 2.1. Gemini session-size guardrail

Gemini can generate a `2048x2048` item candidate successfully and still
make the *next* request fail if that image remains attached in the same
chat/session. The common error is a `many-image request` rejection caused
by the client-side `>2000 px` long-side limit, not by a bad prompt.

Rules:

- For iterative item-icon work in the same session, default to `1536` or
  `1024` square.
- Treat `2K` as an explicit escalation for a final/detail pass or for a
  fresh session, not the default for batch exploration.
- If a previous `2048` result must be reattached, analyzed, or continued
  in chat, resize it to `<=2000 px` first.
- If generation succeeded but the next turn fails immediately with that
  error, diagnose it as a session-history/image-size issue before
  blaming the prompt or model.

Do not copy runtime rules into this skill. Do not copy icon / prompt
rules into `docs/item_runtime_checklist.md`. If the two documents
conflict, the runtime checklist wins for runtime behavior; this skill
wins for visual asset decisions.

### 2.2. Gemini MCP connection-stability guardrail

If Gemini MCP alternates between connected and disconnected, or reports
`connection timed out after 30000ms`, check the MCP launcher before
changing item prompts:

- Prefer the repo launcher `.claude/gemini_mcp_launcher.mjs` through an
  absolute `node.exe` path instead of `npx -y @rlabs-inc/gemini-mcp`.
- Keep `@rlabs-inc/gemini-mcp` installed under `mcp/package.json`; if
  dependency folders are half-installed, reinstall `mcp/node_modules`
  cleanly.
- Do not let startup block on a Gemini API test call. The server should
  initialize first and report API problems only when a real tool runs.
- Keep MCP stdout clean for JSON-RPC; noisy startup/progress logs belong
  on stderr or quiet mode.
- Verify with `initialize`, `listTools`, and one lightweight tool call
  before continuing item-icon generation.

---

## 3. Style unification — match existing icon wall

All existing item icons share one look: 32 or 64 px pixel art, thick
black pixel outlines, flat limited-saturation palette, clear center
subject, readable at ~24 px in the inventory HUD. Painterly rendering,
anti-aliased blur, photoreal product shots, and oil-painting style are
all forbidden.

Required English phrasing inside every item icon prompt:

```
pixel art item icon, 32px (or 64px) canvas, centered subject,
thick black pixel outline, flat limited-saturation palette,
clean hard-edged pixels, readable at ~24px in-game HUD,
NO painterly rendering, NO soft shading, NO photoreal product shot
```

Style knobs:

| Aspect | Required |
|---|---|
| Canvas | 32 × 32 px (inventory / HUD icon) or 64 × 64 px (shop card) |
| Subject fill | 60–75 % of canvas, centered, with breathing room |
| Outline | 1–2 px thick black pixel outline |
| Color | Flat, limited-saturation, hard-edged; no gradient-heavy renders |
| Background | Pure transparent OR the legendary frame stack (see §6) |
| Forbidden | Painterly shading, anti-aliased blur, photoreal, realistic metal SSS |

### 3.1. Readability at HUD scale is a first-generation requirement

Item icons must read at roughly 24 px in the inventory / HUD — not
just at 256 px preview size. An icon that is clear at source size but
becomes a colored blob in-game must be regenerated, not patched with a
runtime outline.

Required prompt fragment:

```
HUD-scale readability is mandatory from the first generation.
The item must remain identifiable at ~24px in-game: keep the
silhouette strong, keep the central motif high-contrast, avoid muddy
midtones, and keep any text / numerals out of the icon. Outline must
survive downscaling without breaking.
```

### 3.2. Transparency-indicator caveat (Gemini outputs)

Some Gemini outputs bake the editor's transparency-indicator checker
pattern into the actual pixels instead of giving a real transparent
background. The common failure case is a neutral gray checkerboard
behind the icon, which can survive naive "whitish background" nukki and
then show up in inventory cells in-game.

Rules:

- Non-legendary item icons must end with a real transparent background,
  not a fake checkerboard baked into the canvas.
- During QA, explicitly inspect the four corners and a few empty-margin
  pixels; background corners should read as transparent after nukki.
- If a Gemini render contains a gray checker transparency-indicator
  pattern, route it through the checker-aware nukki path in
  `.claude/skills/sprite-generation/remove_bg.py` instead of accepting
  the asset as-is.
- **Nukki inspection must be numerical, not visual.** A 1024 px nukki
  output can look transparent in any PNG viewer — including VS Code's
  own transparency checker — while still carrying low-alpha
  (`alpha<230`) mid-gray (`saturation<14, luminance 55–160`) pixels
  from the baked checker. These pixels are invisible at source size
  but `LANCZOS` downsample blends them into an opaque gray square at
  32 px. The viewer's own transparency indicator masks the failure.
- **Verify alpha distribution of the FINAL 32 px PNG numerically.**
  Count `opaque (a>200)`, `semi (8<a<=200)`, and `transparent (a<=8)`
  pixels over the 1024-pixel canvas. For a well-cut item icon, `semi`
  should be at most ~5 % (roughly `<50`). A `semi` count in the 500s
  means checker residue survived and will render as a gray square on
  the in-game inventory cell, even though the file looks clean in a
  viewer.
- **If residue is detected, re-run cleanup on the 1024 source AND on
  every intermediate resize step before `NEAREST` to 32.** The
  canonical cleanup band is:
  `alpha < 230 AND saturation < 14 AND 55 < luminance < 160 -> alpha 0`,
  applied to the source and after each resample. A single pre-resize
  cleanup is not enough, because `LANCZOS` can promote near-invisible
  fringe back above the threshold during downscale.
- **Final-size QA must happen against a dark inventory-like
  background, not a viewer's transparency checker.** Blit the 32 px
  PNG onto a solid navy / charcoal surface (for example `(28, 36, 64)`)
  at 1x and 4–8x before shipping. The viewer's transparency indicator
  and the in-game dark inventory cell reveal completely different
  failures; only the dark preview catches the checker-survived case.
- **Do not rely on global color-band cleanup when the icon contains
  intentional low-saturation interior detail.** Embossed letters,
  engraved runes, pill imprints, or pale interior symbols can live in
  the same `low-sat / mid-luminance / low-alpha` band as checker residue
  after nukki + LANCZOS. In those cases, prefer a location-gated cleanup:
  build a silhouette/body mask from the clearly-opaque subject, preserve
  everything inside that mask, and only hard-clear residue outside it.
  Otherwise the cleanup can erase the intended interior motif together
  with the checker fringe.
- **Color glow / halo residue is a separate failure class from checker
  residue, and body-mask cleanup does not catch it.** If the Gemini
  render paints a soft outer glow (faint magenta / cyan / gold aura
  radiating beyond the intended silhouette), those pixels are
  opaque-colored and survive both the color-band checker cleanup AND
  the dilate-based body-mask cleanup from the previous bullet — the
  dilate simply captures the glow as part of the "body". They render
  as a faint square / round halo against a dark inventory cell even
  though the file corners look transparent. When glow residue is
  detected, pivot to **outline-boundary flood-fill**: detect the black
  silhouette outline at source resolution, morph-close any 1–2 px
  gaps, flood from the image borders through non-outline pixels, and
  keep only the outline plus the enclosed interior. Anything reachable
  by the border flood — including opaque colored glow — is discarded.
  This also handles checker residue in the same pass.
- **Outline-boundary flood-fill discards subject elements that have
  no dark outline of their own.** Flames, plasma, magical auras,
  energy bursts, light beams, and other colored-fill-only subject
  parts are often painted by Gemini as pure color layers without a
  black outline. The border flood therefore reaches them freely and
  marks them as "outside", so the cleanup deletes the flame / aura
  together with the checker residue. The bottle survives because it
  has an outline; the flame above it vanishes. Detect this by visual
  QA on the 32 / 64 px output — if a defining subject element is
  missing after cleanup, pivot to a **hybrid body mask**: union the
  outline-enclosed region with any clearly-opaque saturated pixel
  (`alpha > 180 AND (saturation > 40 OR luminance > 180)`). Such
  pixels are unambiguously subject content, not background residue,
  so keeping them is safe. Apply a 1 px dilate to the union to cover
  anti-aliasing fringe, then resample as usual.
- **Hybrid body mask 후에도 AI 파스텔 halo 는 살아남는다 — 추가
  strip 패스가 필요하다.** 위의 hybrid body mask 규칙
  (`alpha > 180 AND (saturation > 40 OR luminance > 180)`) 은
  의도한 flame / aura / 발광 요소를 지키기 위해 `luminance > 180` 분기를
  포함한다. 바로 그 분기가 **AI 가 아이콘 바깥으로 뿌린 저채도 파스텔
  halo 까지 "subject" 로 인정해서 남겨버린다** (repair_kit 의 cyan fairy
  aura, berserk_potion 의 red glow, vitamin_pill 의 yellow shimmer,
  weather_capsule 의 cyan halo 사례). 1024 에서는 예쁜 발광으로 보여도
  32px 로 리샘플되면 아이콘 주변에 `1~2px 컬러 envelope border` 로
  변한다. 이걸 잡으려면 hybrid body mask 다음에 **halo strip 2차 패스**
  를 돌려라. 기존 투명 픽셀에서 BFS 확장, `V >= 220 AND (maxRGB -
  minRGB) <= 110` 인 이웃만 같이 투명화. 실루엣 내부의 채도 있는 본체는
  BFS 가 도달 못 해서 안전. 정식 CLI:
  `py .claude/skills/sprite-generation/halo_strip.py <src.png> <dst.png>`.
  자세한 내용과 QA 순서 (1024 먼저 보기, 어두운 HUD 위에서 최종 QA) 는
  `.claude/skills/sprite-generation/SKILL.md` §11.6 "AI pastel-halo
  residue trap" 참고.
- **Gemini 가 baked-checker 를 아이콘 픽셀에 구워버릴 때 hybrid body
  mask 의 `luminance > X` 분기는 light-square 체커와 충돌한다.** 기본
  `remove_bg.py` 가 잡는 체커는 `CHECKER_LUM=100` 이하 밝기의 연한
  체커만이고, Gemini 는 session / style 에 따라 전혀 다른 두 종류의
  체커를 굽는다: **어두운 체커 variant** (dark square `lum 70-100`,
  light square `lum 100-130`) 와 **밝은 체커 variant** (dark square
  `lum 195-200`, light square `lum 244-247`). 둘 다 subject mask 에
  `lum > 180` / `lum > 230` 같은 bright-highlight 분기를 넣으면
  **light-square 체커까지 subject 로 인정**되어 square halo 로
  잔존한다 (dowsing_pendulum / speedboots 사례). 해결 순서:
  1. 가장 먼저 raw JPEG 의 배경 corner 픽셀 (`(20,20)`, `(500,20)`
     등) 을 numerical probe 해서 실제 체커 luminance band 를 알아낸다.
  2. Subject mask 에서 bright-highlight 분기를 제거하고 `sat > 25 OR
     lum < 35` 만 사용해서 **채도 있는 색 + 진짜 검은 outline** 만
     subject 로 정의한다. 흰 sole / 흰 lace / 흰 highlight 처럼 의도한
     밝은 영역은 outline 으로 enclose 되어 있어서 flood-fill 이 도달
     못 해 자동 보존된다.
  3. Outline threshold 도 체커 dark-square 와 구분되도록 잡아라.
     어두운 체커 variant 에서는 `lum < 35` 정도로 매우 타이트해야
     체커가 outline 으로 오분류되어 flood 를 막지 않는다.
  4. border-seeded flood 로 non-subject 전부 죽이고, enclosed
     non-subject (`sat <= 15`) 도 추가로 쓸어라 (체인 링 내부, 아크
     사이, 턱 스트랩 opening 등).
  글로우 / 발광 / flame 처럼 밝은 highlight 를 본체로 쓰는 경우는 §3.2
  상단의 "hybrid body mask" 규칙 (`sat > 40 OR lum > 180`) 그대로
  쓰고, outline-enclosed subject (헬멧 / 신발 / 펜들럼 등) 는 이 `sat
  + outline` 타이트 규칙을 쓰면 된다.

### 3.3. Large acquisition / showcase scaling trap

Some item icons pass HUD-scale QA and still fail when the game enlarges
them inside pickup popups, treasure-hunt reveals, or legendary /
showcase-style acquisition effects. The common failure pattern is not the
main silhouette -- it is the leftover transparent padding or a faint
background residue around the icon, which becomes visible as a square /
rectangular ghost only at large presentation size.

Rules:

- Keep the real subject tightly centered; do not waste large transparent
  margin on one side of the canvas.
- Reject icons with faint off-black, off-white, checkerboard, or halo
  residue in the corners even if they look harmless in the small HUD.
- Before sign-off, imagine the icon enlarged 2x~4x inside an acquisition
  popup. If the empty margin is doing most of the work, the icon needs to
  be regenerated or re-nukkied.
- If the item is likely to appear in a big reveal effect, prefer a clean
  visible-bounds crop / recenter pass rather than shipping a loose icon and
  hoping runtime scaling hides it.

---

## 4. Active item icon

Active items go into the active slot (5-orb cooldown UI). The icon must
read as a **usable consumable or gadget** — a thing the player clicks
to trigger an effect.

Required mood cues:

- **Silhouette reads as an object, not a buff aura.** A potion looks
  like a bottle; a bomb looks like a bomb; a dice looks like a dice.
- **No character limbs / body parts.** Active icons are props.
- **Subtle shine / spec highlight** on the object's main face — 1–2 px
  of lighter tone, not a painted gradient.
- **Bright saturated accent color** tied to the item's theme (red for
  damage, cyan for utility, gold for reward, purple for chaotic /
  pandora-like, green for heal / poison by context).

Transparent background. **No legendary frame stack.** (Active items
never use the legendary frame — that is reserved for legendary /
mythic items, see §6.)

Copy-paste prompt: `references/active_icon_prompt.md`.

File naming & path: §8.

---

## 5. Passive item icon

Passive items go into a body-part slot (head / 상의 / 팔 / 벨트 / 무릎 /
신발 / 등 / 장신구). The icon must read as a **wearable part or
equipment**, not a consumable.

Required mood cues:

- **Silhouette reads as gear** — boots, belt, helmet, vest, ring,
  amulet, goggles, glove, pendant, pouch.
- **Body-part hinting.** A belt icon should read as a belt at a
  glance, not an abstract buckle close-up; a helmet icon should be
  recognizable as head-worn.
- **Warm or utility palette** that matches the slot family. Rough
  palette bands: leather / brown for belts and pouches, steel / gray
  for armor, gold / white for rings and amulets, green for
  nature-themed passives, neon for tech-themed passives.
- **No weapon / projectile / explosion hint** — those read as active.

Transparent background. **No legendary frame stack** unless the item
is legendary or mythic.

Copy-paste prompt: `references/passive_icon_prompt.md`.

If the passive item also modifies the character's paddle / body when
equipped, you must also produce an equip visual (§7) and flag it in the
runtime hand-off (see §10 and `docs/item_runtime_checklist.md`).

---

## 6. Legendary / mythic item icon

Legendary items always have the full legendary frame stack (see
`LEGENDARY_ITEM_TEMPLATE.md` in the repo root for the exact pixel
values). This skill does not replace that template — it refers to it.
Read `LEGENDARY_ITEM_TEMPLATE.md` before generating any legendary
icon.

Summary of the frame stack (details in `LEGENDARY_ITEM_TEMPLATE.md`):

| Layer | Role |
|---|---|
| Oversized solid circular background (~28 px radius) | Frame-animated color band tied to item theme |
| 3 × 3 silver / purple corner ornaments | Frame-animated corner palette |
| 2 px red outer border, frame-animated | Legendary-tier signal |
| Central item subject | Drawn on top of the frame stack |
| 8 frames total | Animation is baked into the PNG(s), not composed at runtime |

### 6.1. Theme palette — pick before drawing

Pick the background-circle hue from the item's theme BEFORE drawing
the subject. Do not let the subject decide the frame color — the frame
color is a brand signal and should match the concept.

| Concept | Background hue |
|---|---|
| Thunder / hammer / storm (Ragnarok Hammer) | Electric blue |
| Sky / wind / speed (Hermes Shoes) | Cyan-teal |
| Ocean / tide (Poseidon Trident) | Deep teal |
| Fire / rage (Megingjord-like) | Orange-red |
| Holy / blessing (Angel Blessing, Sacred Laurel) | Warm gold / white |
| Chaos / mystery (Pandora Legacy) | Purple-magenta |
| Divine judgment / crown (Transcendent Crown) | Deep violet with gold |
| Sight / prophecy (Odin's Eye) | Amber-gold |

When in doubt, consult `references/mood_palette.md`.

### 6.2. `empty_legendary` convention

`empty_legendary`, `empty_legendary2` … `empty_legendary6` are **blank
slots** in the developer-mode legendary grid. They are NOT real items
and have no visual. In `pingfighter.py` the icon function for anything
starting with `empty_legendary` returns an empty `Surface` on purpose
so the grid cell renders blank.

Rules:

- Do NOT generate an icon asset for `empty_legendary*`.
- When adding a new legendary item, **do not replace `empty_legendary*`
  strings in code.** They are placeholders the developer-mode grid
  relies on to keep its layout.
- If the user says "use empty_legendary for the mythic icon", they
  mean: slot the new mythic item's icon into a developer-mode grid
  cell that currently renders blank. Wiring that into the grid is a
  runtime step — see `docs/item_runtime_checklist.md`.

Copy-paste prompt: `references/legendary_icon_prompt.md`.

### 6.3. Theme particle rules (for mythic-tier pieces)

Every legendary / mythic item should have a theme-consistent particle
idea documented in the hand-off to runtime, even if the icon itself is
a still frame. The runtime side (effects manager) is the one who
actually spawns particles; this skill only prescribes the theme.

| Theme | Particle prescription |
|---|---|
| Thunder / hammer | Blue-white spark bursts, short zigzag bolts |
| Sky / wind / speed | Pale cyan streaks, soft feather puffs |
| Ocean / tide | Teal droplet arcs, foam ring |
| Fire / rage | Orange ember rise, black smoke tail |
| Holy / blessing | Gold dust upward, soft halo |
| Chaos / mystery | Purple magenta shimmer, flicker crackle |
| Divine judgment | Deep violet + gold flare, star snap |
| Sight / prophecy | Amber rune glyph flicker, narrow beam |

State the particle theme in the Codex / runtime hand-off (not in the
icon PNG).

---

## 7. Character paddle-part equip visual

For passive items that visually attach to the player character when
equipped (e.g. chargebag on the back, technical_vest on the torso,
bulletproof_hat on the head, bulkup on the arms), a second asset is
needed: the **equip visual** that overlays on the player paddle /
character skin.

This is a separate asset from the item icon — it is the thing that
renders ON the character, not the thing that renders IN the inventory.

Rules:

- Same 16-bit pixel art style as the player paddle and the item icons.
- Pose-locked to the paddle / player rig — the asset is drawn in the
  pose it will be composited in, not a standalone portrait.
- Consistent outline thickness and palette with the player character.
- Include an attach-point note (head top / torso / arms / legs / back
  / accessory) in the hand-off — runtime needs this to place the
  overlay correctly.
- Include the **intended visual overlay slot** in the hand-off
  (`head`, `torso`, `belt`, `back`, `l_arm`, etc.). The gameplay
  body-part family and the runtime visual slot are NOT always the same.
- If the item belongs to a wearable family that commonly coexists with
  another visible family (for example `top + belt`), design the equip
  visual as an independent overlay, not as torso art that assumes the
  other family is absent.
- Belt-family visuals should read as a **waist / buckle overlay** and
  be hand-offed as a belt-layer asset, not silently merged into a vest
  or torso layer.
- When the overlay could plausibly collide with another visible family,
  name at least one coexistence QA pair in the hand-off (for example
  `technical_vest + timer_belt` or `bulkup + megingjord`).

Current runtime wiring belongs in the owning Godot item / player-visual
module under `godot/scripts/` (see `docs/item_runtime_checklist.md`).
Legacy Python hooks such as
`entities/body_parts/item_parts_registry.apply_item_to_skin()` are
porting references only. This skill only owns the asset; the wiring
belongs in the runtime checklist.

Copy-paste prompt: `references/equip_visual_prompt.md`.

---

## 8. File naming & output paths

For current 환격전 work, `items/` is the legacy
Python/Pygame path and may be used only as a staging / parity reference
unless the user explicitly asks for original PingFighter source work.
Accepted runtime assets must be copied into the repo-local Godot asset
tree and wired through the owning Godot module.

| Asset | Path | Notes |
|---|---|---|
| Godot active item icon | `godot/assets/...` item icon folder used by the current item catalog | 32 × 32 px, transparent BG unless the catalog requires another size |
| Godot passive / legendary icon | `godot/assets/...` item icon folder used by the current item catalog | Preserve rarity frame / animation expectations from the runtime owner |
| Godot legendary animation frames / sheet | `godot/assets/...` item VFX or icon folder used by the current item owner | Document frame count and cadence beside the loader |
| Godot equip visual | `godot/assets/...` player / equipment visual folder used by the current visual owner | Pose-locked overlay, slot documented in the runtime note |
| Legacy Python item icon reference | `items/[name].png` or `items/[name]_icon.png` | Reference / staging only |
| Legacy Python equip visual reference | `items/[name]_equip.png` or `entities/body_parts/[name].png` | Reference / staging only |
| Legacy unknown-item placeholder | `items/unknown_item.png` | Already exists — do NOT overwrite |

**Do NOT overwrite `items/unknown_item.png`.** It is the fallback icon
for anything without a loaded texture. If a new item fails to load,
the HUD falls back to this asset.

**Do NOT generate an asset file named `empty_legendary*.png`.** See §6.2.

**Match the existing Godot runtime loader key exactly.** Do not silently
save a variant filename unless the runtime note explicitly includes the
catalog / loader update. For explicit legacy Python work, the same rule
applies to existing `items/[name].png` expectations.

---

## 9. QA checklist — reject or regenerate

Apply before accepting any item asset.

| # | Check | Reject if |
|---|---|---|
| 1 | Reads as the correct item at ~24 px HUD scale | silhouette blurs into a colored blob |
| 2 | Outline survives downscaling (1–2 px thick black) | outline breaks into dots or disappears |
| 3 | Palette matches theme band in §6.1 or §5 mood cues | hue drifts away from concept (e.g. fire item rendered cool gray) |
| 4 | Active icons read as props, not character parts | an active icon looks like an arm or head |
| 5 | Passive icons read as wearable gear | a passive icon looks like a bottle or bomb |
| 6 | Legendary icons have the full frame stack baked in | frame missing, corners missing, or frame drawn at runtime |
| 7 | No stray text / numerals / watermarks | any letters or numbers inside the canvas |
| 8 | Transparent background (non-legendary), verified BOTH on a dark inventory-like preview AND via numerical alpha distribution on the final 32 px PNG | any off-white fringe, JPEG halo, baked gray checkerboard transparency pattern, OR `semi-transparent (8<a<=200)` pixel count exceeding ~5 % of the 1024-pixel canvas on the final 32 px PNG (see §3.2) |
| 9 | If legendary: 8 frames consistent, only frame-color animates | subject drifts between frames |
| 10 | If equip visual: pose-locked to player rig, outline matches paddle | freestanding portrait or different outline weight |
| 11 | No painterly rendering / anti-aliased blur | soft gradient or oil-paint feel |
| 12 | Runtime loader precedence sanity check for replacements | the repo still shows an old/procedural icon because a special-case branch returns before reading the new PNG |
| 13 | Enlarged acquisition / showcase presentation stays clean | faint square padding box, leftover transparency indicator, or halo residue appears only when the icon is shown large |
| 14 | If the user asked for upscaling, the Real-ESRGAN gate was completed and recorded | the final asset only changed draw size, import filtering, local resize, or imagegen repaint |

If any check fails, regenerate — do not patch with post-processing.

Known failure pattern:

- The PNG exists on disk and passes art QA, but `items.py` or
  `pingfighter.py` has a special-case icon branch or cache that returns
  a procedural fallback before the file path is consulted. Treat this as
  a failed accept state until runtime precedence is verified.

---

## 10. Hand-off to runtime integration

Once an item asset passes QA, route the **runtime integration** to
`docs/item_runtime_checklist.md`. The runtime checklist is the single
source of truth for every code location that must be touched (items.py
registration, active / passive routing, shop / gacha / crane, dev
mode, reset, rolls, polish, enhancement, equip visual wiring).

Typical hand-off payload to include in the follow-up message:

- Asset type: active / passive / legendary / mythic / equip visual
- File path(s) written (see Section 8)
- For passive: which body-part slot it belongs to (`PASSIVE_SLOT_ORDER`
  family - head / top / arms / belt / knees / shoes / back / accessory)
- For equip visual: attach point (head top / torso / arms / back etc.)
  **and** intended visual overlay slot (`head`, `torso`, `belt`,
  `back`, `l_arm`, etc.)
- For legendary / mythic: roll-option concept, polish-perk applicability,
  enhancement-buff applicability, theme particle (from Section 6.3)
- If the user referenced a blank `empty_legendary*` cell, state the
  real item name that runtime should wire into the dev grid. Do not
  replace the placeholder strings themselves.
- Whether duplicates are allowed (affects `PASSIVE_DUPLICATE_ALLOWED`
  and `skip_append` rules - see runtime checklist)
- For legendary / mythic runtime hand-off, list each intended
  acquisition path separately instead of saying only "shop / gacha /
  crane / treasure hunt": field drop, Nemesis chest, treasure-hunt
  legendary pool, the stage-clear gacha candidate builder in
  `pingfighter.py`, `gacha.py` item classification / display sets,
  crane prize pool, crane reward routing, and Pandora routing decision.
- For any route that can award both passive and active items, state the
  required grant path explicitly (`store_passive_item()` vs
  `store_active_item()`). If the mythic is active, call out any needed
  legendary-active rarity bucket instead of assuming the common / epic
  active path will surface it.
- If stage-clear gacha should be one-time, say explicitly that the gate
  must use ownership / obtained state rather than current equipped-state
  sync flags.
- If the item is a protection / immunity item, state the intended target
  set and explicit exclusions in the hand-off (for example: boss
  non-ball skills yes, weather / event hazards no, ordinary ball path
  no), and call out whether runtime should add a new semantic helper
  instead of widening an existing geometry / VFX helper.
- If the item can visually coexist with a neighboring wearable family,
  name at least one coexistence QA pair for runtime verification.
- For icon replacements or regenerations, explicitly require a runtime
  asset-precedence audit: verify that the written PNG wins over any
  procedural fallback / special-case loader branch and that relevant
  icon caches are refreshed for QA.

- If the item changes any HUD-visible cooldown / charge readout
  (especially player-skill cooldowns on the left 5-orb HUD), say so
  explicitly in the hand-off and require runtime to update the orb
  countdown text, cooldown wedge timing, and tooltip cooldown line to
  the **final effective value**, not only the underlying gameplay
  cooldown logic.
- If a character skill / buff needs a HUD-visible active-duration timer,
  route that request to runtime and explicitly call for the shared
  right-bottom horizontal timer-gauge stack plus the matching effective-
  duration / teardown audit.

Do not attempt the runtime wiring from this skill. Point to the
checklist and stop.
