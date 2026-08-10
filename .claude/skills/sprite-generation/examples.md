# Canonical Reference Examples

Short snapshots of bosses where the pipeline ran end-to-end. Use these as
"this is what good looks like" references when drafting prompts for new
bosses, and as continuity anchors when regenerating sheets.

For current mapping, see `AGENTS.md`: Godot `current_stage == 5` is current
Stage 5 Hongryun/Honglyeon; Godot `current_stage == 6` is current Stage 6
Tetriser, ported from legacy Python Stage 7. Python Stage 6 Nemesis is excluded.

---

## Tauren (real Stage 9)

- Role: template boss for the current pipeline — the rules in SKILL.md
  were finalized during Tauren production.
- Sprite class: `entities/tauren_boss_sprite.py` — reference implementation
  for PNG-first loading, `FRAME_INSET`, bounding-box trim, and target
  scaling. See AGENTS.md for the runtime-side patterns it validates.
- Walk: `items/tauren_boss_sheet.{jpeg,png}`
- Attack: `items/tauren_boss_attack.{jpeg,png}`
- Target size in game: `width=72, height=80` (balanced vs other bosses)
- Identity hooks: tribal totem pole held diagonally across body, tribal
  markings, fierce-but-heroic impression.

## Menhera (real Stage 3)

- Role: the case that established Section 8.2 (identity lock). The first
  dash sheet drifted visually from the walking sheet (pink -> magenta,
  curly -> straight) and had to be rejected.
- Walk: `items/menhera_boss_sheet.{jpeg,png}`
- Attack: `items/menhera_boss_attack.{jpeg,png}`
- Turn: `items/menhera_boss_turn.{jpeg,png}` (aux sheet — the case that
  established Section 5-3 / Section 9 rules for brief facing transitions)
- Identity hooks: pink curly hair, pink nurse outfit with black trim,
  cat tail and cat-paw gloves, nurse cap + ribbon, olive large eyes,
  chibi 2-head proportions.

## Honglyeon (current Godot Stage 5, `current_stage == 5`)

- Role: the boss that validated the dash sheet pattern.
- Dash: `items/honglyeon_boss_dash.{jpeg,png}`
- Identity hooks: Chinese fire theme, red-and-gold palette, lantern motifs,
  flame trail particles.

---

## Angled walk (experimental — Appendix A in SKILL.md)

Not promoted to a rule. If tried on a new boss, record:

- Boss: `[name]`
- Angle count: `[N]`
- In-game readability: pass / fail + 1-line notes
- Verdict: keep / reject

Update this file with outcomes so future runs can evaluate whether
angled walk should graduate into the standard pipeline.
