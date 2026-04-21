# CLAUDE.md

This file is the standing rulebook for Claude working on PingFighter. It
captures invariants and hidden-knowledge bug patterns that cannot be safely
re-derived from the code. Procedural setup (how to run, how to build, how to
test) is intentionally NOT listed here -- read the repo state, `AGENTS.md`,
or `README.md` when needed.

## 0. Implementation Boundary with `AGENTS.md` and asset / item docs

- `CLAUDE.md` (this file) = Claude-side project standing rules and
  routing. Kept thin on purpose -- detailed playbooks live in the skill
  and doc directories.
- `AGENTS.md` = runtime integration, performance, and implementation source
  of truth for Codex/agent work **on boss sprite sheets**. Item runtime
  is NOT owned by `AGENTS.md` -- see `docs/item_runtime_checklist.md`.
- `.claude/skills/sprite-generation/` = the full boss / character sprite
  sheet pipeline (prompts, nukki, QA).
- `.claude/skills/item-generation/` = the full item-visual pipeline (icon
  prompts, legendary frame rules, equip visuals, icon QA).
- `docs/item_runtime_checklist.md` = source of truth for every code
  location that must be touched when adding, removing, or modifying an
  item (active / passive / legendary / mythic).
- `docs/character_skill_perk_checklist.md` = source of truth for every
  code location and QA checkpoint that must be touched when adding,
  removing, or modifying a runtime character perk, unlock perk, or
  player-skill / 5-orb skill.

If the documents conflict:
- Boss-sprite runtime / performance -> `AGENTS.md` wins.
- Boss-sprite generation details -> the `sprite-generation` skill wins.
- Item visual / icon details -> the `item-generation` skill wins.
- Item runtime integration -> `docs/item_runtime_checklist.md` wins.
- Character runtime perk / skill integration ->
  `docs/character_skill_perk_checklist.md` wins.
- Everything else (hidden-knowledge rules, coordinate standards, stage
  mapping) -> this file wins.

**Do not mix skill scopes.** Boss sprite rules do not belong in the
`item-generation` skill, and item icon rules do not belong in the
`sprite-generation` skill. Item runtime rules do not belong in this
file or in `AGENTS.md` -- they live in `docs/item_runtime_checklist.md`.
Character runtime perk / skill code-location checklists also do not
belong in `AGENTS.md` -- they live in
`docs/character_skill_perk_checklist.md`, with the companion hidden-
knowledge UI invariants staying in this file.

## Boss Sprite Work

Any work involving boss/character sprite sheets -- creation, regeneration,
walk / attack / dash / turn (facing transition) sheets, background removal
(nukki), or Gemini MCP / FLUX Kontext / AutoSprite image generation or
editing -- must be handled via the
**`sprite-generation` skill** at `.claude/skills/sprite-generation/`. That
skill owns the full pipeline: prompt templates, identity and scale lock
rules, content-filter bypass vocabulary, the nukki algorithm, and the
reject/regenerate QA checklists.

**If the skill is not auto-triggered, explicitly invoke
`/sprite-generation` before proceeding.** Do not recreate sprite rules
from memory -- always route through the skill so identity and scale lock
stay consistent across bosses.

Tool-routing note inside that skill:
- **FLUX Kontext** is the preferred path for reference-conditioned
  image-to-image work: peak-pose correction, narrow touch-ups, and
  frame-expansion passes after a strong anchor already exists.
- **Gemini MCP** remains a known-good path for fresh full-sheet generation
  and for cases where FLUX or AutoSprite drift on pixel class or identity.
- **AutoSprite** is primarily for motion ideation, pose blocking, and
  structural probes unless it independently proves the same pixel /
  identity class at QA.
- **AutoSprite + FLUX** works best as a role-split pipeline, not a
  sheet-to-sheet relay. Use AutoSprite to discover motion / peak acting,
  then lock a canonical FLUX peak from the strongest single pose and
  expand the surrounding frames in FLUX. Do NOT assume
  `AutoSprite full-sheet -> FLUX full-sheet` will preserve the acting
  beat.
- **Legacy victory / motion sheets can leak obsolete identity branches.**
  If an old sheet starts pushing outdated hair / ribbon / cap language
  back into FLUX, remove it from the generation stack and keep it as QA
  comparison only, not as a motion master.

### Sprite Workflow Mode

Before starting a new sprite branch, check:

- `.claude/sprite_workflow_settings.json`

Default:
- `spriteWorkflowMode = "fast"`

Mode policy:
- **fast** = default. Use quick candidate generation, early visual
  judgment, and aggressive rejection. Do NOT jump into deep frame
  expansion, publish-pack work, or runtime wire-up until a candidate
  already looks promising.
- **precise** = promotion mode. Use the full strip QA / frame-expansion /
  publish / nukki / runtime-handoff path when the user explicitly wants
  depth or when the candidate is already near shipping quality.

Utility:
- `tools/set_sprite_workflow_mode.ps1 fast`
- `tools/set_sprite_workflow_mode.ps1 precise`

### Invariants that remain here (do not re-derive from the skill)

- **Canonical reference = walking sheet.** `items/[name]_boss_sheet.png`
  is the identity anchor for every subsequent sheet of the same boss.
  Attack, dash, and turn sheets must read as the same character.
- **Keep "canonical identity anchor" separate from "runtime-accepted
  auxiliary sheet."** A turn sheet may be accepted for runtime playback
  while still remaining a non-anchor asset. If that happens, document the
  turn as `runtime-only auxiliary sheet, non-anchor` before handing off to
  Codex. The walking sheet remains the sole identity anchor unless a later
  explicit decision reclassifies another sheet.
- **A regenerated walk sheet does NOT become the new canonical just
  because it exists.** Keep the previous accepted walk sheet as the
  rollback reference until the new walk passes gameplay-scale QA for
  identity, body read, and frontal combat readability.
- **Same boss, same identity across all sheets.** Hair color, hairstyle,
  face, eyes, skin tone, proportions, outfit, and signature accessories
  must not drift between walk / attack / dash / turn.
- **Same boss, same readability class across all sheets.** Do not accept
  a mixed set where one sheet reads obviously cleaner, crisper, pinker,
  or more legible at gameplay size while the others look softer or
  muddier. That is a regenerate problem, not a runtime fix.
- **If one accepted sheet is clearly the quality leader, regenerate the
  weaker sheets upward instead of downgrading the leader.** When victory
  or any other accepted sheet is visibly sharper / cleaner / more
  resolved than the rest of the set, treat that sharper sheet as the
  quality target and regenerate the blurrier sheets to match it. Do NOT
  accept a mixed-quality final set and do NOT solve the mismatch by
  softening the better sheet.
- **Body scale lock (+/-5%).** Head, torso, and pelvis must stay within
  +/-5% of the walking sheet. Express speed with pose, lean, effects, and
  motion lines -- never by resizing the body.
- **Attack sheets should assume anticipatory runtime triggering by default.**
  For contact-based melee / strike attacks, prompt for a readable prep ->
  impact -> recovery arc, because Codex may start the sheet slightly
  before predicted ball contact rather than only on the exact hit frame.
  Early frames must contain meaningful coil / intent, not dead air.
- **The preferred anticipation style is short and conservative.** The
  goal is to reveal the prep a little before contact, not to start a
  long wind-up so early that the strike visibly happens before the ball
  arrives. If an attack only works when triggered far too early, the
  prep arc is too slow and should be regenerated tighter.
- **Attack prompts should identify the intended impact frame when one
  frame is the clear strike moment.** If the attack has a strongest hit
  frame or a frame that should be held briefly at contact, say so in the
  prompt / QA / hand-off so runtime can align the pre-contact trigger and
  hold timing correctly. If an attack is supposed to snap instantly with
  almost no prep, that must be stated explicitly rather than left for
  Codex to infer.
- **Visible body read, not just canvas size.** Cross-sheet consistency is
  judged by how large the body/face actually read in-game. Attack / dash
  effects may extend outward, but the body and face must not read smaller
  than the accepted walk baseline. Details in the `sprite-generation`
  skill (QA) and `AGENTS.md` (runtime).
- **Front-facing bosses must feel lively through whole-body rhythm.**
  Front-facing lock is fine, but limb-wiggle-only motion is not. Lateral
  / idle life must come from body bob, weight shift, hip / shoulder
  sway, and hair / ribbon / cloth / flame motion. Details in the
  `sprite-generation` skill.
- **Walk-sheet strip gate: inspect the accepted 8 frames side by side
  before handoff.** Do NOT judge a walk candidate only from a stitched
  preview, loop playback, or a vague "gameplay read." If the direct
  `f1..f8` strip still looks like the same pose repeated eight times, or
  like a static idle gallery with only tiny paw / foot shifts, reject and
  regenerate the walk sheet asset-side.
- **Pair-level mirror success is not enough for walk promotion.** A walk
  branch does not pass just because `F1↔F5` mirror discipline landed or
  because sequence-level identity is stable. `F2/F3/F4/F6/F7/F8` must each
  contribute a visibly different walk-slot role (rise / shift / rebound /
  return) at sheet-review scale, not only after runtime inference.
- **Front-biased walk must still read as forward-facing in motion.**
  If the walk sheet makes the boss read as consistently looking left or
  right during stable movement because of hair asymmetry, ribbon
  placement, eye placement, cheek visibility, shoulder exposure, or
  torso angle, reject and regenerate it. "Front-biased" is not a hidden
  3/4 walk.
- **Do not trade frontal readability for liveliness.** A walk sheet that
  is more animated but noticeably more side-facing than the last
  accepted walk sheet is a regression and must be rejected.
- **For front-biased bosses, turn is no longer an angle-rotation brief.**
  If the walk stays frontal, the turn sheet should usually be a short
  characterful direction-change gesture tied to the walk -- head lift,
  shoulder hitch, arm swap, knee lift, hop / pivot accent, ribbon or
  hem rebound, or another boss-specific habit -- not a `+90 -> 0 -> -90`
  profile chart.
- **Apparent turn-face clipping is usually an asset-side QA problem, not
  an automatic runtime crop bug.** When a turn frame looks forehead-cut,
  face-clipped, or vertically squashed in gameplay, compare the raw cell,
  post-inset crop, trimmed frame, and gameplay-size render before handing
  the issue to Codex. If the same clipped-looking read survives before
  runtime fitting, reject / regenerate the art instead of asking for more
  turn-only runtime scaling.
- **Do not keep "solving" a bad turn by shrinking it harder.** Extra
  turn-only downscale can make the frame smaller without fixing the
  clipped-face impression. If the key transition frames still look
  chopped after a conservative fit, the correct hand-off is visible-turn
  disable / hop-only fallback until the turn art is replaced.
- **Do not hand off asset-side facing failures to Codex as runtime work.**
  If the walk no longer reads as forward-facing, the fix is regenerate /
  rollback on the asset side -- not runtime left/right remaps, blind
  sprite flips, or semantic redefinition of travel directions.
- **Turn-hop requests do not require visible turn-sheet playback.** If
  the user wants "walk stays frontal, direction changes get a brief hop,"
  a hop-only runtime transition on top of the frontal walk is acceptable;
  do not force a mismatched turn sheet into gameplay just because a hop
  was requested.
- **No transparent silhouette gaps between side hair and shoulders.**
  Head -> hair -> shoulder -> torso must read as one closed shape;
  background must not show through. Use a rear hair layer behind the
  shoulders if needed. Details in the `sprite-generation` skill.
- **File path convention:**
  - Walk:   `items/[name]_boss_sheet.{jpeg,png}`
  - Attack: `items/[name]_boss_attack.{jpeg,png}`
  - Dash:   `items/[name]_boss_dash.{jpeg,png}`
  - Turn:   `items/[name]_boss_turn.{jpeg,png}` (optional aux sheet)
  - Class:  `entities/[name]_boss_sprite.py`
- **Current Stage 3 Menhera turn policy (R1 accepted):**
  `items/menhera_boss_sheet.png` remains the sole identity anchor.
  FLUX-derived turn V3 is accepted only as a runtime playback auxiliary
  sheet and is explicitly **non-anchor**. Do NOT use Menhera turn V3 or
  V4 as regeneration reference for attack / dash / victory / defeat.
- **Current Stage 3 Menhera victory policy (P3A accepted):**
  `items/menhera_boss_sheet.png` remains the sole identity anchor.
  FLUX frame-expansion victory publish V2 is accepted only as a runtime
  playback auxiliary sheet and is explicitly **non-anchor**. Do NOT use
  the applied Menhera victory runtime sheet, the older victory backup,
  or rejected V3 variants as regeneration reference for future attack /
  dash / turn / defeat / victory work.
- **Offline nukki is a runnable CLI.** The algorithm lives in
  `.claude/skills/sprite-generation/remove_bg.py` and runs as
  `py .claude/skills/sprite-generation/remove_bg.py <src.jpeg> <dst.png>`.
  The in-class JPEG cleanup inside sprite classes is a runtime safety
  net only; the offline PNG is the source of truth.

### Role split with `AGENTS.md`

- **Claude + this skill:** sheet generation, prompt design, nukki,
  offline PNG preparation, standalone sprite class scaffold.
- **Codex + `AGENTS.md`:** `pingfighter.py` import/init/reset wiring,
  stage render branch, loader caching, runtime scaling, per-frame
  performance. Runtime integration is `AGENTS.md`'s source of truth
  and is not duplicated into the skill.

---

## Item Work

Any work on **item visuals** (active / passive / legendary / mythic
icons, character paddle-part equip overlays, item mood / theme art)
must be handled via the **`item-generation` skill** at
`.claude/skills/item-generation/`. That skill owns the full visual
pipeline: per-tier prompt templates, legendary frame stack routing
(see `LEGENDARY_ITEM_TEMPLATE.md`), `empty_legendary` conventions,
equip-visual prompts, mood / glow / particle rules, and the icon
reject/regenerate QA checklist.

Any work on **item runtime integration** (registering a new item in
`items.py`, routing it correctly through active / passive / legendary
paths, wiring shop / gacha / crane / treasure hunt, hooking roll
options / polish perks / enhancement buffs, handling reset on death /
main menu return, auto-equipping into body-part slots, and keeping
every hardcoded list in sync) must be handled via
**`docs/item_runtime_checklist.md`**. That document is the single
source of truth for the code locations that must be touched.

**If a skill or doc is not auto-triggered, explicitly invoke it
before proceeding.** Do not recreate item rules from memory -- always
route through the skill (for visuals) or the checklist (for runtime)
so new items land cleanly.

### Role split

- **`item-generation` skill:** icon generation, legendary frame stack
  decisions, equip-visual assets, mood / palette / particle theme,
  icon QA. Does NOT own any runtime code location.
- **`docs/item_runtime_checklist.md`:** every runtime code location
  that must be touched when an item is added, removed, or modified.
  Covers `items.py`, `pingfighter.py`, `legendary_items.py`, `gacha.py`,
  `downtown/`, `item_state_manager.py`, equip-visual registry, and
  the Pandora exclusion list. Does NOT own visual asset decisions.
- **This file (`CLAUDE.md`):** thin routing rule (this section).

### Invariants that remain here (do not re-derive from the checklist)

These are the rules most likely to cause silent, hard-to-trace bugs
if re-derived from memory. Keep them in mind even while the full
checklist is open.

- **Item work never goes into `AGENTS.md`.** Item runtime lives in
  `docs/item_runtime_checklist.md`; `AGENTS.md` is for boss-sprite
  runtime only.
- **Legendaries are always passive, never active.** They must be in
  `store_active_item()`'s passive-filter list or they misroute on
  pickup.
- **Duplicate-allowed passive / legendary: `skip_append = True` is
  forbidden.** First acquire activates; every acquire (first and
  later) rolls and falls through to inventory append. Setting
  `skip_append = True` on a duplicate silently loses the pickup.
- **"Duplicates allowed" is path-specific, not global.** Field drops,
  Pandora / treasure routes, shop / crane pools, and stage-clear gacha
  can intentionally diverge. Do not summarize an item loosely as
  "duplicate-allowed" unless you verified which acquisition paths
  actually repeat after first obtain.
- **`PASSIVE_SLOT_ORDER` is not the only hardcoded list.** The
  developer-mode `all_items` block in `pingfighter.py` instantiates
  a SEPARATE hardcoded list of item dicts. You must update both, or
  the dev-mode 2-key menu will hide the new item.
- **`gacha.py` pool labels are not the full gacha path.** The actual
  stage-clear gacha candidates are built separately in `pingfighter.py`
  via `available_items.append(...)`. Updating the passive-name pool
  alone does not make the item pullable in-game.
- **Pandora Legacy keeps its own `passive_names` exclusion set in
  `legendary_items.py`.** Every new passive / legendary must be added
  there too, or Pandora can spawn them as actives.
- **Character-info UI keeps separate name / description maps.** A new
  item is not fully integrated until `get_item_name_korean()` and
  `get_item_description()` can render it cleanly in inventory, shop,
  tooltips, and dev mode.
- **Passive effects are equip-gated.** A passive sitting only in the
  inventory should not grant gameplay benefits. The live effect path,
  equip visual, and any roll / polish / enhancement sync should turn on
  only while the item is actually equipped, and must shut off on
  unequip or reset.
- **A written icon file is not "done" until runtime precedence is
  verified.** If `items.py`, `pingfighter.py`, or another loader has a
  special-case icon branch, procedural fallback, or cache
  (`ITEM_ICONS`, `icon_cache`, etc.), verify that the named PNG is the
  path actually winning at runtime instead of being silently bypassed by
  an earlier return.
- **Online / multiplayer passive classification is separate.** The
  `_passive_names` sync set in `pingfighter.py` must also include new
  passive items, or they can be misclassified as actives in synced
  state.
- **Gameplay body-part family and visual overlay slot are different
  systems.** `ITEM_SLOT_BASE_MAP` / `PASSIVE_SLOT_ORDER` decide
  equip-family logic, while `item_parts_registry.ITEM_SLOT_MAP` and
  `CharacterSkin.parts` decide visual overlay slots. If two wearable
  families can co-equip (for example top + belt), they must not share
  the same visual slot unless the overwrite is explicitly intended.
- **Economy integration is split across separate hardcoded values.**
  `items.py` carries per-item `sell_price`, while
  `downtown/building_interior.py` carries the shop `base_price`.
  A new passive / legendary is not economically integrated until both
  are set to a sensible value relative to comparable items.
- **If an item or perk reduces player-skill cooldowns, the HUD must
  display the reduced final cooldown too.** The left-side 5-orb orb
  countdown text, cooldown wedge timing, and skill tooltip cooldown
  line must read from the same final effective cooldown path as the
  runtime logic. Do not leave display code on raw
  `skill_data["cooldown"]` while gameplay uses a reduced value.
- **Every legendary roll-option stat read must pass
  `apply_polish=True` AND `enhancement_bonus_pct=...`** through
  `get_legendary_roll_value()`. Missing either one means the polish
  perk or enhancement buff is invisible at runtime even though the
  number displays in the tooltip.
- **Changing a passive roll range is not just `PASSIVE_OPTION_RANGES`.**
  When a passive's min/max changes, also sync every fallback/default
  path that can still supply the stat when `rolled_options` are absent:
  module-level default globals, `_reset_roll_bonuses_to_default()`,
  and any per-item effect-module default/reset value. Otherwise legacy
  saves or pre-roll fallback paths can keep using out-of-range numbers
  even though the item card shows the new range.
- **Fixed option lines should stay visually plain.** If an item has a
  guaranteed option alongside rolled data, the option tooltip should
  present it in the same understated style used by `dashholder`.
  Do not add a special `(고정)` suffix unless the user explicitly asks
  for that wording.
- **Do not overwrite `items/unknown_item.png` or `empty_legendary*`
  placeholders.** The unknown asset is the fallback; `empty_legendary*`
  are blank developer-mode grid slots whose layout the UI depends on.
- **Character-transformation / revival items must force the paddle
  to land on transform finalize.** Items that replace the player's
  character kit on activation -- Yachaman Soul (passive, revival on
  score loss), Odin's Eye (legendary, revival on score loss), Horn
  Strawberry Mask (passive, command-triggered transform) -- each
  gate the Viper jetpack update block off via
  `is_yachaman_transformed()`, `is_odins_eye_transformed()`, or
  `_viper_original_skills_blocked` (Horn Strawberry). If a Viper is
  mid-jetpack when the transform finalizes, `_viper_jetpack_offset_y`
  stays negative and the jetpack block that normally writes
  `PLAYER.bottom` no longer runs -- the transformed form walks in
  mid-air. On the exact frame the transform becomes authoritative
  (animation-done for revival items, `TRANSFORM_EVENT -> TRANSFORMED`
  edge for command-triggered transforms), call
  `_reset_viper_jetpack_state()` (Viper only) and
  `apply_equipment_paddle_modifiers()` so the paddle snaps to the
  floor baseline under the transformed scale. If the transform also
  repositions the ball (e.g. `BALL.centery = PLAYER.top - 20`), do
  the landing reset BEFORE the ball reposition. Full code-location
  checklist lives in `docs/item_runtime_checklist.md` §7.

Full per-tier checklists, hardcoded-list audits, and the smoke test
live in `docs/item_runtime_checklist.md`.

### Default assumptions for new item requests

When the user asks to add a new item and provides only the item's
specification (name / body part / description / roll option / theme),
do NOT stop to ask routine follow-up questions unless the request is
truly ambiguous in a way that would materially change gameplay design.

Default assumptions:

- A new item request means **end-to-end work** by default:
  visual asset creation, runtime registration, acquisition-path wiring,
  UI / inventory / developer-mode sync, reset handling, and verification.
- New item names default to **snake_case** in code, even if the user
  provides a Korean display name only.
- If the user does not specify an unlock condition, default to
  **unlocked by default** (`unlocked_items["name"] = True`).
- Ordinary active and passive items default to **no duplicate farming**.
  Only add the item to `PASSIVE_DUPLICATE_ALLOWED` when the design
  explicitly calls for duplicate roll-farming.
- If duplicate farming is explicitly enabled, verify it **per
  acquisition path** before reporting it as done. Field drops,
  Pandora / treasure routes, and stage-clear gacha may intentionally
  behave differently.
- A passive item with a valid body-part slot should default to the
  established behavior: on acquire, if that body-part slot is empty,
  the item should auto-equip into that slot.
- If the user asks for item addition, assume the matching item visual
  should also be created unless the user explicitly says runtime only.
- If the user asks to regenerate or replace an item icon, assume the
  follow-up includes one runtime sanity check that the new file path is
  the asset actually being loaded, not just that the PNG was written to
  disk.
- "Skill cooldown reduction" defaults to **player skill-system cooldowns**,
  not active-item cooldowns, unless the user explicitly says otherwise.
  Active-item cooldown reduction is treated as a separate category.
- "Skill cooldown reduction" (`스킬 쿨타임 감소`) defaults to the
  cooldowns of the **left-side 5-orb player skill HUD** for **all five
  playable characters**: Smasher, Viper, Soldier / Commando,
  Blacksmith / Baltor, and Optimus.
- This includes both **base skills** and **skills unlocked through
  character-exclusive perks** (`unlock_*` style additions).
- This does **not** include active-item cooldowns unless the user
  explicitly says item cooldown / active cooldown.
- Do not forget Optimus: its cooldown path uses a different
  until-timestamp mechanic and may not appear in the same reduction
  chain as the other four characters.
- If an item or perk changes those cooldowns, assume the **HUD display
  must change with it**: orb countdown text, cooldown wedge timing,
  and skill tooltip cooldown text should all show the final effective
  cooldown, not the base data value.
- If an item belongs to an existing body-part family (head / top / arm /
  belt / knee / shoes / back / accessory), follow that family without
  asking for confirmation. If the slot family does not exist yet,
  extend the existing system in the most consistent minimal way and
  report the assumption afterward.
- If an item needs an equip visual, assume the runtime hand-off must
  name both the **gameplay body-part family** and the **visual overlay
  slot**. They are often related but not interchangeable.
- Prefer existing repo patterns over asking the user to choose between
  multiple routine implementation variants.

Only ask a clarifying question when one unanswered choice would create
a genuinely different gameplay identity, balance target, or system scope.
Otherwise, make the most conservative repo-consistent assumption and continue.

---

## Character Skill / Perk Work

Any work on **runtime character perks / skills** -- adding or modifying
character-exclusive perks, unlock-style perks such as `unlock_*`,
player-skill / 5-orb HUD entries, active-skill tooltip text, effective-
level behavior under `transcendent_crown` or `sage_ring`, cooldown HUD
sync, skill-specific gold bonus policy, or save/load/reset handling for
character skill state -- must be
handled via **`docs/character_skill_perk_checklist.md`**.

That checklist is the single source of truth for the code locations and
verification path required to land runtime character skill work cleanly.

Companion-rule split:

- **`docs/character_skill_perk_checklist.md`:** end-to-end runtime
  integration checklist for character perks / skills, including unlock /
  equip flow, 5-orb slot behavior, academy / NPC offer flows, actual
  gameplay effect wiring, skill-gold reward wiring,
  tooltip sync, effective-level QA, save/load, and reset.
- **This file (`CLAUDE.md`):** hidden-knowledge rules that are easy to
  miss while following the checklist, especially the `draw_skill_icon_mini()`
  trap, the seven perk / skill text render paths, and the final-cooldown
  HUD rule.
- **`AGENTS.md`:** not the source of truth for this work unless the task
  also touches boss-sprite runtime.

**If the checklist is not already open, explicitly open it before
proceeding.** Do not recreate character perk / skill integration rules
from memory.

### Hidden-knowledge rules for academy / NPC perk-offer UI

These are easy to miss even when the runtime checklist is open:

- **Visit-scoped offer caching needs both `offered` and `consumed`
  state.** Caching only the proposed perk blocks free rerolls, but it
  does NOT stop the same visit from purchasing / swapping a second time
  after success. Same-visit post-success state should become
  "already taught / exhausted" until the manager resets the visit cache
  on re-entry.
- **`ownership` and `equipped` are different concepts for unlock-style
  active skills.** Any academy / NPC "show an unowned skill" flow must
  filter against "ever unlocked / owned", not merely "currently not
  equipped", or old swapped-out skills can reappear as false-new offers.
- **Nested interior modals must refresh the background after the launcher
  dialog closes.** If a confirm dialog opens a second modal and that
  second modal snapshots the old frame, the first dialog can remain as a
  dim ghost behind the new UI. Redraw the interior first, then open /
  snapshot the child modal.
- **Mouse and keyboard menu paths often diverge on flag clearing.** If a
  flow uses `open_*_requested` or similar one-shot signals, audit both
  click handlers and key handlers. A fix only in the keyboard path is not
  enough.
- **Settings screens can have multiple live entry points.** Before handing
  a settings / options task to Codex, confirm which screen the player
  actually reaches (`start_menu.py` main-menu settings, `option.py`,
  pause options, helper settings UI, etc.). A patch to an unused or
  dormant settings screen is not a valid accept state.
- **Use the visible UI strings to find the live screen.** When a report is
  "the BGM/SFX/settings screen still does not show X," search for the
  actual on-screen labels / tab names (`BGM 볼륨`, `효과음 볼륨`,
  `사운드`, `설정`) and trace the reachable call path instead of assuming
  a legacy `option.py`-style module is the active menu.
- **Silent freetype failure can make the whole dialog look blank.** A
  helper that catches `font.render()` exceptions and returns `None`
  without a visible fallback can hide a bad font path entirely. For
  Korean UI, verify the actual repo path exists under `resource_path()`
  before trusting the dialog.
- **Repo font reality beats guessed subpaths.** In this repo,
  `NanumSquareB.ttf` exists at the repo root, while `fonts/NanumSquareB.ttf`
  may not. Do not assume a `fonts/` subpath exists just because other
  modules use fonts under `fonts/`.
- **When helper modules mutate `pingfighter.downtown_gold`, manager-side
  player state must be resynced after the modal closes.** Otherwise the
  next manager tick or exit path can overwrite the spent / gained value.
- **New active skills should not silently inherit "no gold" as the
  default.** If a skill creates a distinct owned reward moment -- ball
  hit, boss hit, object absorb, sustained field tick, release burst, or
  similar -- decide an explicit gold policy. The normal default is an
  intentional reward sized against comparable same-character skills;
  zero-gold should be an explicit design choice, not an omission.
- **Skill gold belongs on the real owned event path, not the animation
  start.** Wire the reward where the skill actually hits / absorbs /
  consumes, and audit all alternate branches that can reach the same
  result so the reward is neither skipped nor double-paid.
- **Skill gold can silently stack with generic rally gold if the local
  duplicate-prevention path is missed.** When adding or modifying a
  skill-owned gold bonus, also inspect the generic rally-gold path and
  any character-local same-frame guard / hit-consume flags so one skill
  event cannot pay twice through primary + fallback logic.

### Hidden-knowledge rules for orb-slot / stage-transition integration

These came out of the Commando firearm overhaul and apply to any future
character that joins the 5-orb system or gains multi-path skill
acquisition. They are easy to miss even when
`docs/character_skill_perk_checklist.md` is open.

- **When a new character (or a new unlock skill) joins the 5-orb system,
  the cooldown-reduction scope expands with it.** `transcendent_crown`,
  `sage_ring`, and any generic cooldown-reduction perk / effect that
  applies to character orb skills must also apply to the newly
  orb-registered skills. Orb wedge fill, remaining-time text, and tooltip
  cooldown text must all read the final effective cooldown after
  reductions, not the raw constant. Optimus uses an `until`-timestamp
  path, so audit it separately even when the other characters share a
  common reduction chain.
- **`reset_round()` and the real stage-transition hook are not
  interchangeable.** `reset_round()` fires every lost-point round.
  Resets that should only happen on stage boundaries -- rental /
  temporary holdings cleanup, permanent-resource ammo refill,
  once-per-stage flag clear -- must be attached to the actual
  stage-advance path (`current_stage += 1`, `current_stage = stage_num`,
  or the stage-start hook), never to `reset_round()`. Otherwise they
  silently re-fire on every lost point.
- **`*_SKILL_ICONS_DATA` is a metadata table, not the visible-order
  truth.** `SOLDIER_SKILL_ICONS_DATA`, `SMASHER_SKILL_ICONS_DATA`, and
  `VIPER_SKILL_ICONS_DATA` describe orb-capable skill metadata; the
  actually visible orb lineup and slot order are driven by
  `_*_equipped_skills`. Renderers that iterate over `*_SKILL_ICONS_DATA`
  directly, or trust `len(*_SKILL_ICONS_DATA)` as the slot count, break
  the moment the character gains dynamic equip / unequip / swap flow.
- **5-orb "slot full" checks must count shared-slot occupancy, not only
  one skill category.** If a character mixes multiple shared-slot skill
  types (for example permanent firearms plus a passive orb like
  `soldier_pistol_perk`), the fullness test must count every skill that
  occupies the shared slots. Counting only one subtype silently reopens
  perk-choice offers that no longer fit in the orb budget.
- **A once-per-stage active flag must be persisted across save/load
  within the same stage.** Cooldown wedges alone do not guarantee
  "once per stage"; loading a save after using such a skill must
  restore the spent / disabled state until the next real stage
  transition, and stage-advance must clear it.

---

## CRITICAL: Stage Order Reference (code stage != real stage)

Stage 5 and Stage 6 were swapped in code variable names. The code name and
the user-facing stage number do not agree. This is the single biggest
source of "wrong stage edited" bugs.

| Stage | Boss           | Theme                   | Pillar               | Code name (mismatch alert)   |
|-------|----------------|-------------------------|----------------------|------------------------------|
| 1     | Pungakboi      | Korean traditional      | pillar_stadium       | stage1                       |
| 2     | Akeojanggun    | Jungle / swamp          | pillar_jungle        | stage2                       |
| 3     | Menheragirl    | Menhera / doll          | pillar_menhera       | stage3                       |
| 4     | Pongk          | Temple                  | pillar_temple        | stage4                       |
| **5** | **Nemesis**    | **Ocean / Battleship**  | pillar_nemesis_ocean | **animated_bg_stage6** !!    |
| **6** | **Honglyeon**  | **Chinese fire**        | (TBD)                | **animated_bg_stage5** !!    |
| 7     | Tetriser       | Tetris arena            | -                    | stage7 / `game_logic/stage7_tetriser.py`, `stages/stage7_boss.py` |
| 8     | Akamu Rigo     | Shadow dojo (reuses stage7_field) | -          | stage8 / `entities/stage8_boss_sprite.py` |

### Code names vs real stage mapping

- Code `stage5`, `animated_bg_stage5`, `Stage5ChineseMarket` = **real Stage 6 Honglyeon (fire)**
- Code `stage6`, `animated_bg_stage6`, `AnimatedBackgroundStage6` = **real Stage 5 Nemesis (ocean)**

When the user says "work on stage 5" they mean Nemesis (ocean). When they
say "work on stage 6" they mean Honglyeon (fire). Do not trust the
variable name -- always confirm by theme.

---

## CRITICAL: Screen Coordinate Standards

All items, skills, projectiles, and effects must follow this coordinate
contract. Key point: the game physics area is the **full screen 0 to WIDTH**.
Pillars are only UI overlays, not physical boundaries.

```
+------------------------ 760px (WIDTH) ------------------------+
|         Physics area: 0 - 760 (ball, paddle, projectiles)    |
|                                                              |
|   +- pillar -+                             +- pillar -+      |
|   | 0 - 79   |    UI overlay drawn on top  | 680-759  |      |
|   | 80px     |    item spawn center: 380px | 80px     |      |
|   +----------+                             +----------+      |
|                                                              |
|  Ball bounces at: BALL.left <= 0 and BALL.right >= WIDTH     |
+--------------------------------------------------------------+
```

### Screen size constants (see `config/constants.py`)

| Constant                     | Value | Meaning |
|------------------------------|-------|---------|
| `WIDTH` / `INTERNAL_WIDTH`   | 760px | Physics area width (ball, paddle, effects all in this range) |
| `HEIGHT` / `INTERNAL_HEIGHT` | 750px | Screen height |
| `PILLAR_UI_WIDTH`            | 80px  | Each pillar UI overlay width (NOT a physics boundary) |
| `GAME_AREA_OFFSET_X`         | 80px  | Pillar offset (for UI placement only) |
| `GAME_PLAY_WIDTH`            | 600px | Pillar-excluded center width (for UI placement / item spawn) |

### Which width to use

| Work type                      | Width to use         | Range     | Why |
|--------------------------------|----------------------|-----------|-----|
| Effects / barriers / walls     | `WIDTH` (760)        | 0 - 760   | Ball travels full width |
| Ball bounce / paddle motion    | `WIDTH` (760)        | 0 - 760   | Physics boundary = full screen |
| Item spawn                     | `GAME_PLAY_WIDTH` (600) | 80 - 680 | Do not spawn behind pillars |
| UI element placement           | `GAME_PLAY_WIDTH` (600) | 80 - 680 | Avoid pillar overlap |
| Boss / paddle center X         | `WIDTH // 2` (380)   | -         | Center relative to full screen |

```python
# Wrong: barrier / effect uses GAME_PLAY_WIDTH -> leaves 80px gap on left
barrier_left = GAME_AREA_OFFSET_X
barrier_width = GAME_PLAY_WIDTH

# Right: barrier / effect uses full screen width
barrier_left = 0
barrier_width = WIDTH

# Right: item spawn stays within pillar-excluded area
spawn_x = GAME_AREA_OFFSET_X + random(0, GAME_PLAY_WIDTH)  # 80 - 680
```

### Y coordinate reference

| Object                   | Y       | Notes |
|--------------------------|---------|-------|
| Boss paddle              | 25      | Top 25px of screen |
| Boss hitbox bottom       | ~65     | BOSS_Y(25) + BOSS_HEIGHT(40) |
| Boss side region         | 0 - 120 | Top area where the boss acts |
| Center line              | 375     | HEIGHT / 2 |
| Player paddle            | 710     | HEIGHT(750) - 40 |
| Player side region       | 630 - 750 | Bottom area where the player acts |

### Side classification (projectiles, items)

| Side         | Y range       |
|--------------|---------------|
| Boss side    | Y < 120       |
| Neutral      | 120 <= Y < 630 |
| Player side  | Y >= 630      |

---

## Resource Loading and Korean Text

- **Always** load assets via `resource_path(relative)`. Never hardcode
  absolute paths. Use `os.path.join` for path construction. This is what
  makes PyInstaller builds work on both Windows and macOS.
- Render Korean text with `pygame.freetype` + `fonts/NanumSquareB.ttf`.
  The default pygame font does not cover Hangul.
- Open text files with `encoding="utf-8"`.

---

## CRITICAL: Perk Icon Rendering (hidden elif chains)

### The elif-chain trap

`draw_skill_icon_mini()` in `pingfighter.py` is a multi-thousand-line
hardcoded elif chain on `skill_id`. **New perks do not auto-render.** A
perk without an elif branch falls through to `else` and shows only the
first letter of the skill name -- which reads as a broken icon in QA.

This applies to both:
- General perks (entries in `VIPER_EXCLUSIVE_SKILLS`, e.g. `jetpack_enhance`).
- **Skill-unlock perks** with `unlock_*` prefix (e.g. `unlock_magnum_grip`,
  `unlock_plasma`, `unlock_recovery_skill`, `unlock_cleanse`,
  `unlock_ghost_shot`, `unlock_nerve_strike`, `unlock_dive_strike`). These
  live in a separate dict and are easy to forget.

Fix: always add the elif branch immediately above the final `else:` in
`draw_skill_icon_mini()`, and audit every live id alias that can reach the
icon. A perk can use one id in the perk pool and a different id in the real
5-orb HUD or unlock flow (`double_marshal_kick` vs `phantom_kick` is the
canonical failure mode).

```python
elif skill_id == "new_perk_id":
    ...  # pygame.draw a polished icon
elif skill_id in ("legacy_new_perk", "runtime_new_perk"):
    ...  # same bespoke icon for all live ids
elif skill_id == "unlock_new_skill":
    ...  # pygame.draw + a "+" unlock badge
else:
    symbol = skill.get("name", "?")[0]  # fallback -- means the branch is missing
```

Quality rule:
- The new branch should draw a **polished bespoke icon**, not just a
  temporary letter, flat circle, or debug placeholder. Match the visual
  richness and readability of the strongest existing perk icons at the
  actual in-game size.
- When the perk also appears in the 5-orb HUD, treat
  `_draw_skill_icon_symbol()` as a second quality pass rather than an
  optional afterthought.

### The "branch exists but still fails QA" trap

A perk icon can have the correct `elif` branch and still be wrong in-game:

- The **main subject can read too small** relative to the icon box even
  though the branch technically renders.
- One UI path can call the branch under a **different live id alias**
  than the one you tested.
- A large perk-choice card can look fine while the same icon still reads
  tiny in a 32 px perk grid, academy offer slot, or other small-box UI.

Sign-off rule:
- Audit the icon at the **smallest real box size** that uses it, not only
  the largest preview card.
- Compare against neighboring shipped icons; if the main motif reads
  materially smaller, it fails even if the canvas is "occupied" by glow,
  rings, or ghost layers.
- Audit both `draw_skill_icon_mini()` and `_draw_skill_icon_symbol()` under
  the actual runtime ids used by perk acquisition, unlock, and HUD metadata.

### New-perk registration checklist

| # | Step |
|---|------|
| 1 | Add to `VIPER_EXCLUSIVE_SKILLS` (name, max_level, descriptions, detail, icon_color) |
| 2 | Handle level-up in `apply_runtime_skill_effect()` |
| 3 | **Add elif branch in `draw_skill_icon_mini()` -- required, or icon breaks** |
| 4 | **Audit every live id alias (`perk_id`, unlock id, runtime skill id, legacy id) so all relevant UIs hit the intended branch** |
| 5 | **Check perceived subject-fill size in the smallest real icon box, not only the large choice card** |
| 6 | Apply the actual gameplay effect via `runtime_skill_levels.get("perk_id", 0)` |
| 7 | Add `global` declarations in every function that mutates perk-related globals |

### General perk vs skill-type perk (5-orb slot)

Perks have two kinds, registered differently:

| Kind                     | Defined in                                       | HUD                              | Cooldown |
|--------------------------|--------------------------------------------------|----------------------------------|----------|
| General (passive boost)  | `VIPER_EXCLUSIVE_SKILLS`                         | `draw_viper_perk_icons()` (small icon beside orbs) | none |
| Skill-type (5-orb slot)  | `VIPER_EXCLUSIVE_SKILLS` **and** `VIPER_SKILL_ICONS_DATA` | `draw_viper_skill_icons()` (5-orb slot) | `cooldown` field |

Any perk with a cooldown or activation condition MUST be registered as
skill-type. Skill-type perks require entries in `_viper_skill_unlocked`,
`_viper_skill_cooldowns`, `_viper_skill_activation_times`,
`_viper_skill_was_active`, plus `unlock_viper_skill()` +
`equip_viper_skill()` plumbing in `apply_runtime_skill_effect()`.

```python
# apply_runtime_skill_effect() -- skill-type unlock + equip pattern
if choice_id == "new_skill_perk":
    unlock_viper_skill("new_skill_perk")
    equip_result = equip_viper_skill("new_skill_perk")
    if not equip_result:
        removed = _show_viper_skill_swap_dialog("new_skill_perk")
        swap_viper_skill(removed, "new_skill_perk")
    runtime_skill_levels["new_skill_perk"] = 1
    return True
```

For a general-perk HUD icon:

```python
_new_perk_lv = get_runtime_skill_level("new_perk_id")
if _new_perk_lv > 0:
    viper_perks.append({
        "name": "new_perk_id",
        "color": (R, G, B),
        "cost": 0,
        "symbol": "XX",
        "always_active": True,
    })
```

### HUD 5-orb rendering goes through TWO functions

```
_viper_equipped_skills
  -> match in VIPER_SKILL_ICONS_DATA
    -> _draw_skill_icon_symbol()   (HUD-only polished symbol)
      -> fallback: draw_skill_icon_mini()
```

| Function | Role |
|----------|------|
| `draw_skill_icon_mini()` | Generic icon for perk choice UI, TAB info, etc. |
| `_draw_skill_icon_symbol()` | HUD 5-orb only -- polished symbol |

Adding the elif to `draw_skill_icon_mini()` alone keeps the HUD from
breaking (there is a fallback call inside `_draw_skill_icon_symbol()`).
For a polished HUD-specific icon, add a dedicated branch in
`_draw_skill_icon_symbol()` too.

Do not assume the same id reaches both functions. If the unlock perk id,
perk-pool id, and equipped-skill / orb-HUD id differ, `_draw_skill_icon_symbol()`
must still cover the actual equipped-skill name that lands in
`*_SKILL_ICONS_DATA`.

Tooltip-missing checkpoints: entry exists in `VIPER_SKILL_ICONS_DATA`
(name, korean, cost, description), `_viper_skill_icon_rects` updated every
frame, `is_viper_skill_unlocked()` returns True on hover.

Tooltip-format rule:
- New skill / perk tooltip copy should follow the surrounding UI's
  existing format and tone instead of inventing a new prose style.
- For active-skill / orb tooltips, preserve the established field order:
  header, state tag, cost / cooldown, description, then input / usage
  guidance.

---

## CRITICAL: Perk/Skill UI Text Audit -- seven render paths

When changing perk level display, name, or tooltip text, fix **all seven**
render paths below. Fixing one leaves stale text in the other six.

| # | Screen | Function |
|---|--------|----------|
| 1 | Perk choice card (in-game) | `show_runtime_skill_choices()` |
| 2 | Stage clear perk choice | `show_stage_clear_choices()` |
| 3 | Stage clear overlay | `draw_stage_choice_overlay()` |
| 4 | Perk status screen (ESC menu) | `show_perk_status()` -> `draw_level_gauge()` |
| 5 | TAB character info perk tab | `draw_character_info_panel()` perk grid |
| 6 | Perk status tooltip | `draw_tooltip()` / `draw_skill_tooltip_mini()` |
| 7 | Victory screen perk tooltip | `show_victory_screen()` `hovered_tooltip` |

Why the duplication: each screen composes its own `f"Lv.{level}"` instead
of sharing a renderer. Also check data-passing helpers like
`get_acquired_skills()` for the fields downstream branches expect.

Quick audit before calling the work done:

```bash
grep -n 'Lv\.' pingfighter.py | grep -i 'render\|text\|line'
grep -n 'name_line\|tooltip_name\|perk_name.*Lv' pingfighter.py
grep -n 'character_restriction' pingfighter.py | grep -v '#\|print\|CLAUDE'
```

---

## CRITICAL: Graphics & Effects Performance

Rendering pipeline today:
- **Windowed:** `pygame.SCALED` + GPU 2x upscale. No per-frame CPU scaling.
- **Fullscreen:** CPU software scaling, fast enough via DWM bypass.

### Usually cheap, but only while staying in-family

| Action | Why |
|--------|-----|
| Vary colors / alpha on an existing effect | Does not change object count or allocation pattern |
| Add detail to cached backgrounds | Drawn from cached layers |
| Improve fidelity with pooled / cached surfaces | Reuse beats recompute |
| Add modest direct-draw accents | Safe when particle count, lifetime, layer count, and radius stay close to the existing effect |

Not free: multiplying particle count, particle lifetime, layer count, and
translucent radius at the same time. Those factors multiply each other.

### Still watch for (CPU + pygame territory)

| Pattern | Why bad | Fix |
|---------|---------|-----|
| `pygame.Surface(..., SRCALPHA)` inside a loop | Per-frame allocation -- biggest killer | Surface pool or `gfxdraw` |
| `pygame.transform.rotate/scale` per frame | CPU-heavy | Cache results, key by angle/size |
| Particle count x lifetime x layer count growth | Each change looks small alone, but total draw volume explodes | Keep one axis flat or benchmark/cache |
| Large soft smoke / aura blobs redrawn every frame | High alpha overdraw plus repeated circle/ellipse work | Cache blob surfaces by size/color/alpha bucket and blit |
| Thousands of `pygame.draw` / `gfxdraw` calls | Volume matters even when per-call is cheap | Reduce count, collapse layers, or batch with cached surfaces |
| Full-screen `Surface.fill()` spam | 760*750*4 = 2.3MB cleared every time | Clear only the dirty region |
| Wide SRCALPHA blending | Alpha blending is CPU-expensive | Minimize transparent surfaces |

### Effect authoring pattern

```python
# Wrong: per-frame Surface + rotate
def update_particle(self):
    surf = pygame.Surface((20, 20), pygame.SRCALPHA)
    surf = pygame.transform.rotate(surf, self.angle)
    screen.blit(surf, self.pos)

# Right: gfxdraw direct for small/simple particles
def update_particle(self):
    pygame.gfxdraw.filled_circle(
        screen, int(self.x), int(self.y), self.radius, self.color
    )

# Right: surface pool + cached rotation
class ParticlePool:
    def __init__(self):
        self.cached = {}

    def get_rotated(self, base, angle):
        key = int(angle) % 360
        if key not in self.cached:
            self.cached[key] = pygame.transform.rotate(base, key)
        return self.cached[key]
```

One-liner: do not create a new `pygame.Surface` or call
`pygame.transform.rotate/scale` per frame per particle. Use `gfxdraw`
for small/simple shapes, and switch to cached blob surfaces or a surface
pool once an effect becomes layered smoke, aura, or other large soft
alpha work.

---

## CRITICAL: Safe Git Rollback

**Never run `git reset --hard` with uncommitted changes.** Work will be
lost silently.

Safe sequence:

```bash
# 1. Save current state
git stash -u -m "pre-rollback backup"
# or
git add -A && git commit -m "WIP: pre-rollback snapshot"

# 2. Roll back
git reset --hard <commit>

# 3. Restore (if stashed)
git stash pop
```

Safer alternatives:

| Scenario | Command |
|----------|---------|
| Revert one file | `git checkout <commit> -- <file>` |
| Test a revert without committing | `git checkout -b test-branch <commit>` |
| Undo a commit while keeping history | `git revert <commit>` |
| Full rollback safely | `git stash -u` -> `git reset --hard` |

Recovery:
- Stashed -> `git stash list`, then `git stash pop`
- Committed -> `git reflog`, then `git checkout <hash>`

When rolling back: `pingfighter.py` and its sibling modules (`start_menu.py`,
`items.py`, etc.) must land on the same version together. Spot-reverting one
file without the rest breaks imports and state.

---

## Repository info

- Remote: `https://github.com/officialsahogany/pingfighter.git`
- Working branch at start of this doc: `feature/refactor-ui`
