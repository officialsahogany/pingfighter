# Character Runtime Skill / Perk Integration Checklist

Single source of truth for the code locations and QA checkpoints that
must be touched when adding, removing, or modifying a runtime character
perk, character-exclusive skill, unlock-style perk, or player-skill /
5-orb skill in PingFighter, including academy / NPC perk-offer and
skill-swap flows.

Four-way role split:

| Document | Owns |
|---|---|
| **this file** | Every runtime code location and verification checkpoint for character perks / skills |
| `CLAUDE.md` | Hidden-knowledge rules: icon-render traps, seven UI text paths, final-cooldown HUD rule, routing |
| `AGENTS.md` | Boss-sprite runtime only; not the source of truth for character perk / skill integration |
| `docs/item_runtime_checklist.md` | Item runtime only; use it when the change is item-driven rather than perk-driven |

Character perk / skill runtime does NOT belong in `AGENTS.md`. Boss
sprite runtime lives there; character perk / skill integration lives
here.

If this file and `CLAUDE.md` appear to overlap:

- **This file wins** for runtime code-location coverage and end-to-end
  verification.
- **`CLAUDE.md` wins** for the hidden-knowledge UI traps it calls out
  explicitly (`draw_skill_icon_mini()`, seven render paths, cooldown
  display consistency).

---

## 0. Pre-flight before touching code

Before adding ANY runtime character perk / skill, confirm:

- [ ] Character decided (`smasher`, `viper`, `soldier`, `optimus`, etc.)
- [ ] Feature type decided:
      general perk / scaling perk / unlock perk / 5-orb skill /
      active-skill enhancer
- [ ] Code id decided in `snake_case`
- [ ] Correct pool decided:
      `RUNTIME_SKILL_POOL` or the character-exclusive pool
- [ ] If this unlocks or adds an active skill:
      input, gauge cost, cooldown, icon, tooltip text, and swap behavior
      are all specified
- [ ] If this adds or modifies an active skill that can directly hit the
      ball or boss, absorb / destroy objects, or generate a sustained
      owned reward event, the skill-gold policy is specified:
      appropriate payout amount / cadence / bonus conditions, or an
      explicit no-gold exception
- [ ] If this is offered through an academy / NPC / downtown modal:
      visit scope, reroll policy, exhausted-after-success policy,
      ownership-vs-equipped filtering, and currency/AP sync target are
      all specified
- [ ] If this changes player-skill cooldowns:
      decide whether it affects only gameplay, or gameplay + all HUD
      readouts (default: both)
- [ ] Decide whether `transcendent_crown` / `sage_ring` should change
      the behavior at effective levels above the base cap
- [ ] Decide whether the effect is boolean-only (`unlock_*` style) or
      scales with level

Every checklist below assumes these are already decided.

### 0.1. Default runtime assumptions for new character skill work

Unless the user explicitly overrides them, use these defaults:

- A new character perk request means **end-to-end runtime work**:
  registration, actual gameplay effect, UI / tooltip sync, save/load,
  reset, and verification.
- Character-exclusive perks should live in the matching character pool
  (`SMASHER_EXCLUSIVE_SKILLS`, `VIPER_EXCLUSIVE_SKILLS`, etc.) unless
  the perk is intentionally shared.
- Unlock-style perks that grant a player-skill / 5-orb skill should
  **auto-equip into the first free slot**. If no slot is free, they
  should use the existing swap dialog flow instead of silently failing.
- If a perk modifies an existing active skill's cost / damage / size /
  cooldown / duration, the **player-facing tooltip and HUD must reflect
  the final effective value** when that value is shown to the player.
- Unless the user explicitly asks otherwise, a new active skill with a
  clear owned reward moment should have an intentional skill-gold bonus
  policy. Default to a moderate payout consistent with comparable
  same-character skills; "no skill gold" should be an explicit design
  choice, not a silent omission.
- If a skill uses directional input and the game already supports both
  letter keys and arrow keys for that direction, treat them as
  equivalent by default in gameplay and UI. Do not ship a new
  directional skill that only listens to one key family unless the user
  explicitly asked for that restriction.
- If the perk is an invested runtime perk, assume it must be audited
  under `transcendent_crown` and `sage_ring`.
- If the perk is `max_level == 1` and is meant to stay boolean-only,
  verify that bonus items do **not** accidentally create bogus `Lv.2`
  gameplay expectations in UI text.
- Unless the user explicitly asks otherwise, **round transition resets
  runtime active state** for character skills. Active buffs, remaining
  duration, command buffers, charge state, temporary spawned entities,
  and transient FX should not silently carry into the next round.
- By default, **cooldown-state reset and runtime-state reset are separate
  responsibilities**. A helper that clears cooldowns should not also
  terminate or preserve active runtime state unless that behavior is
  explicitly intended and documented.
- Cross-round carryover / pause-resume behavior is an exception, not the
  default. Only add it when the user or design explicitly wants that
  gameplay identity, and document the dedicated pause/resume path
  separately from the hard reset path.
- Keep **round-transition reset** and **real stage-transition reset**
  separate. Stage-scoped ammo refills, rental / temporary cleanup, and
  "once per stage" reset rules belong on the actual stage-entry /
  stage-advance hook, not in a generic `reset_round()` path.

Do not stop for clarification on the items above unless the user's
request directly conflicts with one of these defaults.

---

## 1. Classify the work before wiring it

| Type | Meaning | Typical audit focus |
|---|---|---|
| General perk | Passive runtime bonus, no new active input | pool entry, level-up effect, UI text, effective level |
| Unlock perk | Grants an active skill or orb slot entry | unlock flow, auto-equip / swap, save/load, actual skill gating |
| 5-orb skill | Active skill shown in the left-side orb HUD | metadata row, icon, cooldown, tooltip, gauge cost, gameplay trigger |
| Active-skill enhancer | Perk that modifies another active skill | effect path, target-skill tooltip, cooldown / cost display |
| Cooldown modifier | Perk or skill that changes player-skill cooldowns | final cooldown helper path, orb wedge, countdown text, tooltip |

Do not treat all of these as the same problem. The common bug pattern is
"registered in the perk pool, but not actually wired into the active
skill system."

---

## 2. Common runtime registration

### 2.1. Add the perk to the correct pool

- [ ] Add the entry to the correct dict:
      `RUNTIME_SKILL_POOL` or the matching character-exclusive pool
      such as `SMASHER_EXCLUSIVE_SKILLS`, `VIPER_EXCLUSIVE_SKILLS`,
      `SOLDIER_EXCLUSIVE_SKILLS`, or `OPTIMUS_EXCLUSIVE_SKILLS`.
- [ ] Provide the minimum fields used by existing runtime UI:
      `name`, `max_level`, `descriptions`, `detail`, `icon_color`,
      and `tree`.
- [ ] If the perk is character-specific, set
      `character_restriction` correctly.
- [ ] If the perk is unlock-style or otherwise special-cased, do NOT
      assume the pool entry alone is enough; continue through Sections
      3 through 7.

### 2.2. Register the actual effect

- [ ] `apply_runtime_skill_effect()` must handle the new id.
- [ ] If the effect needs special unlock / equip / give-item /
      immediate-apply behavior, implement it here rather than relying
      on the generic `runtime_skill_levels[id] += 1` fallback.
- [ ] `recalculate_skill_effects()` must mirror any special behavior
      that can be reached via debug level edits, load-time sync, or
      bonus-state recalculation.
- [ ] If the perk mutates globals or caches, add the needed `global`
      declarations in every mutating function.
- [ ] Apply the effect at the **stat consumption point**, not display
      time only.

### 2.3. Effective-level support

- [ ] If the perk can exceed its base cap because of
      `transcendent_crown` or `sage_ring`, confirm
      `get_runtime_skill_level()` is the number the gameplay path reads.
- [ ] If the displayed description must change at `Lv.6+`, add a
      pattern or special case to `get_runtime_skill_description()`.
- [ ] If the perk is intentionally boolean-only, verify the gameplay
      path still behaves as boolean-only even when the effective level
      becomes 2+ from bonus items.

---

## 3. Character-specific active skill / 5-orb systems

Only do this section when the change touches a character's active skill
HUD, unlock perk, or orb-slot system.

### 3.1. If the perk grants a new active skill

- [ ] Add a metadata row to the character's orb-skill data list
      (`*_SKILL_ICONS_DATA`) with:
      `name`, `korean`, `cost`, `color`, `cooldown`, `key`,
      `description`, `how_to_use`, and any extra flags the tooltip or
      renderer needs.
- [ ] Add the skill to the character's cooldown registry.
- [ ] Add the skill to activation-time / active-state registries if the
      HUD glow or activity effect depends on them.
- [ ] Add the skill to the character's unlocked-state registry.
- [ ] Add the skill to the character's equipped-skill list defaults or
      unlock flow as appropriate.
- [ ] Add the unlock map inside `apply_runtime_skill_effect()`.
- [ ] Mirror that unlock map inside `recalculate_skill_effects()`.
- [ ] Use the existing swap dialog when slots are full; do NOT silently
      drop the unlocked skill.
- [ ] Save and restore both the unlocked-state dict and equipped-skill
      list.
- [ ] If the character participates in "hide unlock perks when slots
      are full" behavior, update `_CHARACTER_UNLOCK_PERKS`,
      `_are_character_skill_slots_full()`, and the real slot-full offer
      structure as one set. In the current repo that means the strict
      tutorial / fixed-offer path (`filter_full_slot_unlock_perks_strict()`)
      plus the normal runtime-offer helpers (`_weighted_perk_sample()`,
      `_active_perk_weight()`, `enforce_full_slot_perk_cap()`). Missing
      any one of these silently breaks slot-full perk filtering,
      weighted swap offers, or tutorial behavior.
- [ ] If swap cleanup removes a previously equipped active skill, derive
      the removed `perk_id` from the unlock map instead of assuming
      `perk_id == skill_id`. `double_marshal_kick -> phantom_kick` and
      `soldier_pistol_perk -> commando_pistol` are the canonical failure
      modes.
- [ ] If slot-full choice capping can remove sampled cards, apply the
      cap before instant fillers / gold-conversion append so the final
      card count is preserved.
- [ ] If the character has an acquired-skill list in
      `show_perk_status()` or a local `get_acquired_skills()` helper,
      include the character-exclusive skill pool there too. A skill can
      be fully wired in gameplay yet still disappear from the ESC perk
      status UI if this list is stale.
- [ ] Treat `*_SKILL_ICONS_DATA` as metadata, not as the source of
      truth for the visible orb lineup. Visible slot order should come
      from the equipped-skill list / slot model.
- [ ] If the design has permanent ownership, currently equipped skills,
      and temporary / rental holdings, keep them as separate canonical
      states and rebuild the live runtime list from them. Do not merge
      all three concepts into one mutable list and hope later code can
      infer the difference.
- [ ] When adding or moving a skill through one of the icon registries
      (`_SMASHER_ORB_ICON_REGISTRY`, `_VIPER_ORB_ICON_REGISTRY`,
      `_OPTIMUS_SKILL_ICON_REGISTRY`, `BLACKSMITH_SKILL_ICON_REGISTRY`,
      `_SOLDIER_ORB_ICON_REGISTRY`), explicitly set
      `slot_occupancy`, `cooldown_reduction_eligible`, and
      `cleanup_policy` on the registry entry. Use this matrix unless the
      design intentionally changes the runtime model:

      | Registry family | `slot_occupancy` | `cooldown_reduction_eligible` | `cleanup_policy` |
      |-----------------|------------------|-------------------------------|------------------|
      | Smasher active / unlock orbs | `active_orb` | `True` | `perk_id_lookup` |
      | Viper active / unlock orbs | `active_orb` | `True` | `perk_id_lookup` |
      | Optimus framed skill-card icons | `active_orb` | `False` | `perk_id_lookup` |
      | Baltor / Blacksmith active icons | `active_orb` | `True` | `perk_id_lookup` |
      | Soldier `supply_drop`, `emergency_supply` | `base_fixed` | `True` | `base_only` |
      | Soldier permanent firearm shared slots | `shared_slot` | `True` | `shared_swap` |
      | Soldier `commando_pistol` via `soldier_pistol_perk` | `passive_orb` | `True` | `perk_id_lookup` |

      `slot_occupancy` owns slot-full math, `cooldown_reduction_eligible`
      owns whether generic player-skill cooldown reduction should apply,
      and `cleanup_policy` records the only safe removal path. Soldier
      `shared_swap` skills must be cleaned up through the shared swap
      helper; normal active / unlock aliases need perk-id lookup through
      `_CHARACTER_UNLOCK_PERKS`; base skills are not cleanup candidates.

### 3.2. Smasher concrete audit points in the current repo

When the work is Smasher-specific, audit all of these current anchors:

- [ ] `SMASHER_SKILL_ICONS_DATA`
- [ ] `_smasher_skill_cooldowns`
- [ ] `_smasher_skill_activation_times`
- [ ] `_smasher_skill_was_active`
- [ ] `_smasher_skill_unlocked`
- [ ] `_smasher_equipped_skills`
- [ ] `reset_smasher_skill_unlocks()`
- [ ] `reset_smasher_skill_cooldowns()`
- [ ] `equip_smasher_skill()`
- [ ] `swap_smasher_skill()`
- [ ] `unlock_smasher_skill()`
- [ ] `is_smasher_skill_unlocked()`
- [ ] `_show_smasher_skill_swap_dialog()` / themed swap flow
- [ ] `_draw_smasher_skill_tooltip()`
- [ ] save/load keys:
      `smasher_skill_unlocked`, `smasher_equipped_skills`

Important current behavior:

- `is_smasher_skill_unlocked()` effectively means
  **unlocked AND equipped**.
- Unlocking the perk without slot integration is not enough; the skill
  still will not fire if it is not in `_smasher_equipped_skills`.
- Existing Smasher skills such as Magnum Grip, Plasma, Recovery,
  Cleanse, and Ghost Shot each have separate gameplay trigger paths.
  A new skill must have its own real trigger/update path too.

### 3.3. Viper concrete audit points in the current repo

When the work is Viper-specific, audit the equivalent registries:

- [ ] `VIPER_SKILL_ICONS_DATA`
- [ ] `_viper_skill_unlocked`
- [ ] `_viper_equipped_skills`
- [ ] `_viper_skill_cooldowns`
- [ ] `_viper_skill_activation_times`
- [ ] `_viper_skill_was_active`
- [ ] `unlock_viper_skill()`
- [ ] `equip_viper_skill()`
- [ ] `swap_viper_skill()`
- [ ] `_show_viper_skill_swap_dialog()`

If another character uses a different active-skill model, follow that
character's existing pattern rather than forcing the Smasher/Viper
5-orb model where it does not belong.

### 3.4. Academy / NPC offer flows for unlock-style perks

Only do this section when the perk or skill can be acquired through an
downtown / academy / NPC interaction instead of the standard perk cards.

- [ ] Define the offer pool in terms of **unowned / never unlocked**
      skills, not merely "currently unequipped" skills.
- [ ] If the same visit should keep one rolled offer, cache the offered
      perk for the visit.
- [ ] If the same visit should stop after one success, cache a separate
      consumed / exhausted flag; caching the offer alone is not enough.
- [ ] Define the reset boundary explicitly:
      close dialog only / same building visit / building re-entry /
      next stage / next run.
- [ ] If the flow spends gold or another resource from a helper module,
      resync the final value back to the shared manager / player state
      after the modal closes.
- [ ] If the flow launches a swap dialog when slots are full, verify the
      same visit cannot open a second free swap after a successful one
      unless the design explicitly wants multiple swaps.
- [ ] If a parent confirm dialog opens a child perk / skill modal, make
      sure the parent UI is fully closed and the interior is redrawn
      before the child modal snapshots the background.

---

## 4. Icon rendering, HUD, and tooltip audits

### 4.1. Generic perk icon rendering

- [ ] Add a `_MINI_SKILL_ICON_REGISTRY` entry when the icon can reuse an
      existing PNG / orb-symbol path; otherwise add the bespoke
      `draw_skill_icon_mini()` branch.
- [ ] For Smasher / Viper orb-backed skills, keep the runtime skill id in
      the character orb registry (`_SMASHER_ORB_ICON_REGISTRY`,
      `_VIPER_ORB_ICON_REGISTRY`) and point both the runtime mini icon
      and any unlock / alias mini icon at that shared entry. The unlock
      entry should add only the unlock badge policy.
- [ ] For Commando / Soldier orb-backed skills, keep the runtime skill id
      in `_SOLDIER_ORB_ICON_REGISTRY`, then point runtime mini icons and
      unlock / perk aliases through `_CHARACTER_UNLOCK_PERKS["soldier"]`.
      If the runtime HUD path is Soldier-specific procedural art instead
      of the shared orb renderer, mark the registry entry with
      `symbol_renderer: "soldier"` so the mini path reuses the correct
      Soldier renderer instead of the generic shared symbol renderer.
- [ ] For Optimus framed skill-card icons, keep the skill id in
      `_OPTIMUS_SKILL_ICON_REGISTRY` and let `draw_optimus_skill_icon()`
      dispatch through that registry before falling back to the legacy
      procedural branch.
- [ ] For Baltor / Blacksmith active icons that intentionally render
      through the bespoke HUD path, keep the skill id in
      `BLACKSMITH_SKILL_ICON_REGISTRY` with
      `family: "blacksmith_bespoke"` so coverage can distinguish the
      intentional exception from a missing shared renderer.
- [ ] If both the registry entry and bespoke branch are missing, the UI
      falls back to the first letter of the skill name, which is a
      broken-icon state.
- [ ] Audit every live id that can reference the icon:
      perk-pool id, unlock id, runtime skill id, and any legacy alias.
      If perk choice uses one name and the live HUD uses another, both
      must land in an intentional bespoke branch.
- [ ] Do NOT stop at a placeholder symbol or minimal debug shape.
      Draw a bespoke polished icon that matches the existing in-game
      icon language: readable silhouette, layered highlights, clean
      outline, and enough internal structure to look intentional at the
      actual UI size.
- [ ] Match the repo's existing pixel / drawn-icon quality bar rather
      than introducing a flat generic glyph. "Works" is not enough; the
      icon should look shippable beside existing perks.
- [ ] Check perceived subject fill in the smallest real UI box that uses
      this icon. A branch can exist and still fail QA if the motif is
      technically present but reads materially smaller than neighboring
      icons.
- [ ] If multiple callsites pass different `scale_multiplier` values or
      box sizes into `draw_skill_icon_mini()`, test them all. Passing in
      the large choice card does not guarantee the 32 px perk grid,
      academy offer, or status-panel version is readable.
- [ ] Treat the `CLAUDE.md` "Perk Icon Rendering" section as a
      companion invariant while doing this work.

### 4.2. Polished orb-HUD icon rendering

- [ ] If the skill appears in the left-side orb HUD, add or audit the
      `_draw_skill_icon_symbol()` branch too.
- [ ] Do not assume `draw_skill_icon_mini()` alone gives a polished orb
      icon even though it prevents total fallback breakage.
- [ ] Audit `_draw_skill_icon_symbol()` under the actual equipped-skill /
      orb-metadata ids, not only the perk acquisition id.
- [ ] If the HUD uses a different name from the unlock perk or perk-pool
      entry, cover both names explicitly or normalize the dispatch path
      before sign-off.
- [ ] The orb icon should feel like a premium HUD symbol, not a scaled
      copy of a rough menu icon. Keep it bold, centered, and instantly
      readable at small size.
- [ ] Judge the orb by the visible main subject, not by total effect
      area. Rings, glows, ghost layers, and particle dots do not count
      as acceptable size if the central motif still reads tiny.
- [ ] If the orb icon has animated motion, audit its behavior by state
      instead of using one always-on loop for everything.
- [ ] Default expectation:
      cooldown / unusable = visually still or subdued,
      ready = normal motion / sparkle allowed,
      actively running = stronger or faster motion only if that helps
      the player immediately read "this skill is live right now."
- [ ] Strong default for new animated orb skills:
      idle / cooldown / low-gauge = static pose,
      ready = animation starts,
      active = animation can intensify.
- [ ] If a static pose exists, prefer a deliberate "rest" frame or
      `phase = 0` style hold over leaving the orb in constant ambient
      motion before the skill is actually ready.
- [ ] Cooldown or low-gauge states should not look falsely "ready" just
      because the icon keeps spinning or sparkling all the time.

### 4.3. Orb tooltip rendering

- [ ] Audit the character-specific orb tooltip renderer
      (`_draw_smasher_skill_tooltip()` and similar paths).
- [ ] Match the existing active-skill tooltip structure instead of
      inventing a new layout. The default format is:
      Korean skill name in the header, `ACTIVE` tag, gauge-cost line,
      cooldown line, main description body, and the existing
      `how_to_use` / control-hint block style.
- [ ] If the skill supports both letter keys and arrow keys, show both
      mappings in the `how_to_use` / control-hint block using the same
      existing visual style instead of documenting only one key family.
- [ ] Reuse the established tone and formatting of existing skill
      tooltips: concise action-first wording, same field order, same
      color emphasis, and no one-off sentence style that reads like a
      different UI system.
- [ ] If the skill's player-facing numbers change with effective level,
      cooldown reduction, or another perk, make sure the orb tooltip
      line does not stay stale on the original metadata string.
- [ ] If the orb tooltip is intentionally static flavor text, confirm
      that any changing numeric values are shown somewhere else
      consistently.

### 4.4. Perk / skill UI text audit

Run the full `CLAUDE.md` text audit for every new perk / skill:

- [ ] Perk choice card: `show_runtime_skill_choices()`
- [ ] Stage clear perk choice: `show_stage_clear_choices()`
- [ ] Stage clear overlay: `draw_stage_choice_overlay()`
- [ ] Perk status screen: `show_perk_status()` / `draw_level_gauge()`
- [ ] TAB character info panel: `draw_character_info_panel()`
- [ ] Tooltip paths: `draw_tooltip()` / `draw_skill_tooltip_mini()`
- [ ] Victory-screen tooltip: `show_victory_screen()`

Also audit any acquired-skill list drawers that build their own skill
data objects. If one path still reads from raw `descriptions[base_level]`
or stale metadata while another uses `get_runtime_skill_description()`,
the UI is not fully integrated.

### 4.5. Modal UI rendering / input audit

Use this when the perk or skill introduces a new popup, academy screen,
NPC choice window, or other perk-adjacent modal.

- [ ] Verify the actual font path exists in the repo and resolves through
      `resource_path()` at runtime.
- [ ] Do not rely on a silent `font.render()` failure path; if the font
      load fails, the UI must still remain visibly debuggable.
- [ ] Check text visibility in-game, not just compile success.
- [ ] Audit both mouse and keyboard flows for confirm / cancel / ESC.
- [ ] Confirm one-shot menu-open flags are cleared after consume,
      cancel, outside-click close, and ESC close.
- [ ] If the modal opens on top of another dialog, verify the background
      snapshot is taken after the launcher dialog is gone so old text
      does not remain as a ghosted layer.

### 4.6. Tooltip writing style

- [ ] Write the tooltip in the same house style as nearby existing
      perks / skills for that character.
- [ ] Keep the first line player-meaningful immediately:
      what it unlocks, what it changes, or when it triggers.
- [ ] If the skill is an unlock perk, make the tooltip clearly separate
      "perk acquired" from "actual active skill behavior" so the player
      understands what the new orb does.
- [ ] If the perk modifies another active skill, mention the target
      skill name explicitly instead of assuming the player will infer it.
- [ ] Avoid dumping raw implementation jargon into the tooltip unless
      the surrounding UI already uses that term.

---

## 5. Effective level, `transcendent_crown`, `sage_ring`, and `Lv.5+`

This is the most common "looks right in one place, wrong in three other
places" bug category.

- [ ] Confirm whether the perk is supposed to scale from effective level
      (`get_runtime_skill_level()`) or from base invested level only.
- [ ] If the perk is supposed to scale, make sure the **gameplay path**
      reads the effective level too, not just the UI.
- [ ] If the perk is NOT supposed to scale even when effective level
      rises because of `transcendent_crown` / `sage_ring`, make the
      UI wording reflect that clearly.
- [ ] If the perk can exceed `max_level` in a player-visible way, add
      a `get_runtime_skill_description()` path for `Lv.6+` or the
      relevant overflow range.
- [ ] If the perk modifies another active skill's numbers, audit the
      target skill's tooltip and HUD too.

### 5.1. Cooldown-display rule

If the change affects player-skill cooldowns:

- [ ] Use the final effective cooldown helper path
      (`_get_effective_player_skill_cooldown_seconds()` /
      `_get_effective_player_skill_cooldown_ms()`).
- [ ] If you are moving a character or a newly unlocked skill into the
      5-orb system, make sure it also enters the same cooldown-
      reduction scope as that character's other orb skills.
- [ ] Verify orb countdown text uses the same final value.
- [ ] Verify cooldown wedge timing uses the same final value.
- [ ] Verify tooltip cooldown text uses the same final value.
- [ ] Do not leave gameplay on reduced cooldown while the UI still
      displays raw `skill_data["cooldown"]`.

### 5.2. Unlock-only perks with bonus items

Unlock perks (`unlock_*`) are easy to misread under bonus items:

- [ ] If the perk is meant to stay "ACTIVE" and not become a stronger
      version at effective level 2+, confirm all UI paths still read as
      a boolean unlock rather than an upgradable numeric perk.
- [ ] If the perk *is* meant to gain extra strength from bonus items,
      that must be implemented explicitly in both gameplay and text.

---

## 6. Actual gameplay effect wiring

The perk is not done when it appears in the choice UI. It is done when
the gameplay event actually uses it.

- [ ] Find the real trigger path:
      input poll / charge path / collision path / passive stat read /
      spawn hook / hit-confirm hook.
- [ ] If the trigger is directional input, wire the equivalent
      directional key families into the same command path by default
      (for example `A/W/D` and `LEFT/UP/RIGHT`) unless the design
      explicitly restricts it.
- [ ] Gate the skill with the correct unlock-and-equip predicate.
- [ ] Gate the skill with the correct cooldown predicate.
- [ ] Gate the skill with the correct gauge / resource predicate.
- [ ] Apply the real effect:
      projectile, buff, cleanse, pull, shield, spawn, damage mod, etc.
- [ ] Start and end the cooldown in the same character-specific system
      as the existing skills.
- [ ] If the skill owns a hit / absorb / consume reward moment, wire any
      skill-specific gold bonus at that real event path instead of at
      mere cast start or windup start.
- [ ] Size the gold payout against comparable existing skills for the
      same character unless the design explicitly calls for unusually
      high / low reward or no reward.
- [ ] Audit the generic rally-gold path and any character-local
      duplicate-prevention flags so the same skill event cannot pay
      twice through primary + fallback hit logic.
- [ ] If the effect spawns persistent entities, clear them on reset and
      state transitions.
- [ ] If the perk modifies an existing active skill rather than adding a
      new one, test both the source perk and the target skill flow.

For Smasher-style work, a good question is:
"After I take the unlock perk, what exact input path now does something
new that was impossible before?"

If the answer is unclear, the runtime wiring is incomplete.

---

## 7. Persistence and lifecycle

- [ ] Reset on new run / main menu return.
- [ ] Reset runtime active state on round transition by default unless an
      explicit exception was requested and documented.
- [ ] Reset temporary command buffers / input-history state on round
      transition.
- [ ] Reset charge / hold / spawned transient-entity state on round
      transition unless the design explicitly preserves it.
- [ ] Reset cooldown state.
- [ ] Reset temporary activation / glow / spawn state.
- [ ] Keep cooldown-reset helpers separate from full runtime-state reset
      helpers. Do not hide active-buff teardown inside a "cooldown reset"
      utility.
- [ ] If a skill, weapon, or state is "once per stage," save and
      restore a dedicated used-this-stage flag. Cooldown alone is not
      enough to preserve the contract across save/load.
- [ ] If a temporary / rental state should expire on the next stage
      only, clear it on the real stage-transition hook rather than on
      `reset_round()`.
- [ ] Save the unlocked-state dict if the character uses one.
- [ ] Save the equipped-skill list if the character uses one.
- [ ] Restore both on load.
- [ ] If the runtime uses a derived live list (for example equipped +
      temporary merged into one controller list), restore the canonical
      state first and rebuild the derived live list after load.
- [ ] Keep backward-compatibility behavior for older saves where
      unlocked skills may need to auto-equip on first load.
- [ ] If older saves used one combined list for ownership / equipped /
      temporary state, add an explicit migration rule that preserves the
      player's holdings instead of dropping ambiguous entries.
- [ ] If the effect depends on currently equipped items or transformed
      states, verify post-load resync still lands in the right state.
- [ ] If a debug or editor path can directly change levels,
      `recalculate_skill_effects()` must keep the runtime consistent.
- [ ] If the perk / skill is a **character-transformation** that flips
      any character-gate predicate (for example anything routed through
      `is_odins_eye_transformed()`, `is_yachaman_transformed()`, or
      `_viper_original_skills_blocked`), the transform finalize frame
      must force the paddle to land. A Viper who is mid-jetpack when
      the gate flips will otherwise walk in mid-air because the
      jetpack update block at `pingfighter.py:~83498` is gated off
      after finalize and `_viper_jetpack_offset_y` stays negative. On
      the exact finalize frame, call `_reset_viper_jetpack_state()`
      (Viper only) followed by `apply_equipment_paddle_modifiers()`.
      Full checklist (finalize-edge detection, ball-reposition
      ordering, reverse-path handling, current in-repo callsites)
      lives in `docs/item_runtime_checklist.md` §7. Character-
      transformation items today drive this rule; a future transform-
      style character skill must follow the same pattern.

---

## 8. Hardcoded integration points audit

Use this as the scan list before shipping.

| # | File / anchor | Purpose |
|---|---|---|
| 1 | `runtime_skill_levels` | Canonical invested runtime levels |
| 2 | `RUNTIME_SKILL_POOL` | Shared perk registry |
| 3 | `SMASHER_EXCLUSIVE_SKILLS` / other character pools | Character-specific registry |
| 4 | `get_runtime_skill_level()` | Effective level with bonus items |
| 5 | `get_runtime_skill_description()` | Dynamic `Lv.6+` and overflow text |
| 6 | `apply_runtime_skill_effect()` | Actual acquire / unlock / level-up behavior |
| 7 | `recalculate_skill_effects()` | Debug / load / bonus-state resync |
| 8 | `_MINI_SKILL_ICON_REGISTRY` / `draw_skill_icon_mini()` | Generic perk icon rendering |
| 9 | `_draw_skill_icon_symbol()` | Polished orb-HUD symbol |
| 10 | `show_runtime_skill_choices()` | Runtime choice card |
| 11 | `draw_stage_choice_overlay()` | Stage-clear overlay text |
| 12 | `show_stage_clear_choices()` | Stage-clear choice UI |
| 13 | `show_perk_status()` / `draw_level_gauge()` | ESC perk-status level display |
| 14 | `draw_character_info_panel()` | TAB panel |
| 15 | `draw_tooltip()` / `draw_skill_tooltip_mini()` | Generic tooltip text |
| 16 | `show_victory_screen()` | Victory tooltip path |
| 17 | Character `*_SKILL_ICONS_DATA` | Orb metadata and tooltip text |
| 18 | Character cooldown / unlocked / equipped registries | Orb runtime state |
| 19 | Character-specific orb tooltip renderer | Active-skill tooltip sync |
| 20 | Save/load keys in `save_data` | Persistence |
| 21 | Character reset functions | New-run cleanup |
| 22 | Actual gameplay trigger / update functions | Real effect path |
| 23 | `draw_skill_icon_mini()` callsites with custom `scale_multiplier` / box size | Small-box readability and alias-path audit |
| 24 | Skill-owned `add_ingame_gold()` / local duplicate-prevention path | Intentional skill reward and no double-pay against rally gold |

If you added a new hardcoded list not present here, add it to this table
in the same PR.

---

## 9. Smoke test before shipping

For every new character perk / skill, run this manual QA pass:

1. The perk appears only for the correct character and in the correct
   choice pool.
2. Taking the perk updates the correct runtime state:
   level-up, unlock flag, or both.
3. For an unlock perk, the new skill lands in the remaining orb slot;
   if slots are full, the swap dialog appears and the chosen result
   persists.
4. If the character uses slot-full unlock filtering, full-slot state
   suppresses the unlock perk or routes through the intended swap flow
   instead of quietly leaking into the normal perk-choice pool.
5. The perk / skill icon renders correctly in every relevant UI path;
   no first-letter fallback icon appears, no alias path lands in the
   wrong bespoke branch, and the main motif does not read materially
   smaller than adjacent shipped icons in the smallest relevant box.
6. If the orb icon is animated, cooldown / unusable / ready / active
   states are visually distinct and do not misread as "always active."
7. If the design uses a static-rest / ready-animate pattern, the orb is
   truly still before readiness and starts animating exactly when the
   skill becomes ready.
8. TAB / ESC / stage-clear / victory / tooltip text all show the same
   intended name and description, using the existing tooltip format for
   that UI path instead of a one-off layout or wording style.
9. With `transcendent_crown` and/or `sage_ring` equipped:
   the effective level changes where intended, the description changes
   where intended, and the real gameplay effect follows the same rule.
10. If the perk is boolean-only, bonus items do not create fake
   `Lv.2+` expectations in UI or gameplay.
11. The actual input / trigger fires the real effect in gameplay.
12. If the skill uses directional input, both supported key families
    (for example `WASD` and arrow keys) trigger the same intended
    command path and match the tooltip hint.
13. Gauge cost, cooldown start, cooldown end, orb wedge, orb countdown
    text, and tooltip cooldown line all agree with each other.
14. If the skill owns a gold reward, the payout amount / tick cadence /
    object bonus matches the design intent, and the same event does not
    also pay generic rally gold or a fallback reward path on top.
15. Save the game, load it, and confirm unlocked / equipped state
    remains correct.
16. If the design includes stage-only temporary / rental state or a
    once-per-stage skill, save and load within the same stage and
    confirm both the temporary state and the used-this-stage flag are
    preserved correctly.
17. Cross a real stage boundary and confirm stage-only cleanup / refill
    rules happen there and not on ordinary round resets.
18. Die mid-run or return to the main menu, then confirm the character
    starts fresh with the correct reset state.
19. Cross a round boundary and confirm runtime active state follows the
    intended policy: default = ends on round transition, exception =
    explicitly documented carryover / pause-resume only.
20. If a debug or direct-level-edit path exists for the perk, confirm
    `recalculate_skill_effects()` restores a consistent runtime state.
21. If the perk / skill is obtained through an academy / NPC modal,
    confirm the text actually renders in-game with the intended font and
    does not appear blank or nearly invisible.
22. For academy / NPC offer flows, confirm same-visit reroll,
    repurchase, and reswap behavior matches the design:
    cached if intended, exhausted after success if intended, reset only
    at the intended visit boundary.
23. For nested confirm -> offer flows, confirm the opened modal does not
    keep the previous dialog as a dim background ghost.
24. If the modal changes gold / AP / other visit currency, confirm the
    spent or granted amount persists correctly after closing the modal
    and after leaving the building.

Any failure = back to the checklist.
