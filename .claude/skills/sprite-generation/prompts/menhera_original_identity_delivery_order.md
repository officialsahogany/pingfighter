# Menhera Original-Identity Delivery Order

Claude / Gemini delivery order for the Stage 3 Menhera downstream realignment
sequence after `.tmp/menhera_original_identity_walk_v1.png` passed identity,
quality, and frontal QA.

Current state:
- `items/menhera_boss_sheet.png` is still the old file and has NOT been touched.
- `.tmp/menhera_original_identity_walk_v1.png` is the accepted provisional
  canonical walk anchor for the next regeneration steps.
- `items/menhera_boss_victory.png` is quality/readability reference only.
- All downstream sheets must now align to the NEW original-identity walk anchor,
  not to the old in-game Menhera identity.

---

## Send Order

### 1. Attack realign

Send:
- [menhera_original_identity_attack_realign.md](./menhera_original_identity_attack_realign.md)

Expected outputs:
- `.tmp/menhera_original_identity_attack_v1.jpeg`
- `.tmp/menhera_original_identity_attack_v1.png`

Gate before moving on:
- Same character as `.tmp/menhera_original_identity_walk_v1.png`
- Body read stays within +/-5% of the walk anchor
- Med-kit accessory, four black bows, and cloth/tail motif still read clearly
- Sheet is at least as crisp as `items/menhera_boss_victory.png`

If any fail:
- Reject and regenerate attack again
- Do NOT proceed to dash yet

---

### 2. Dash realign

Send:
- [menhera_original_identity_dash_realign.md](./menhera_original_identity_dash_realign.md)

Expected outputs:
- `.tmp/menhera_original_identity_dash_v1.jpeg`
- `.tmp/menhera_original_identity_dash_v1.png`

Gate before moving on:
- Same character as the walk anchor
- Visible body read is NOT smaller than the walk anchor
- Trails / motion accents do NOT compress the body
- Sheet is at least as crisp as `items/menhera_boss_victory.png`

If any fail:
- Reject and regenerate dash again
- Do NOT proceed to turn yet

---

### 3. Turn realign

Send:
- [menhera_original_identity_turn_realign.md](./menhera_original_identity_turn_realign.md)

Expected outputs:
- `.tmp/menhera_original_identity_turn_v1.jpeg`
- `.tmp/menhera_original_identity_turn_v1.png`

Gate before moving on:
- Same character as the walk anchor
- Adjacent angles interpolate smoothly
- Mid-angles do not collapse into fake front copies
- Sheet is at least as crisp as `items/menhera_boss_victory.png`

If full 13-frame fails:
- Use the documented strip fallback ladder
- Document the accepted usable subset before moving on

---

### 4. Victory realign

Send:
- [menhera_original_identity_victory_realign.md](./menhera_original_identity_victory_realign.md)

Expected outputs:
- `.tmp/menhera_original_identity_victory_v1.jpeg`
- `.tmp/menhera_original_identity_victory_v1.png`

Gate before moving on:
- Same original-identity Menhera as the walk anchor
- Same or better crispness as current `items/menhera_boss_victory.png`
- Celebration pose is readable without shrinking the body

If any fail:
- Reject and regenerate victory again
- Do NOT proceed to defeat yet

---

### 5. Defeat realign

Send:
- [menhera_original_identity_defeat_realign.md](./menhera_original_identity_defeat_realign.md)

Expected outputs:
- `.tmp/menhera_original_identity_defeat_v1.jpeg`
- `.tmp/menhera_original_identity_defeat_v1.png`

Gate before final acceptance:
- Same original-identity Menhera as the walk anchor
- Collapse / slump progression stays readable from the front
- Sheet is at least as crisp as `items/menhera_boss_victory.png`
- Body does NOT visually shrink during defeat

If any fail:
- Reject and regenerate defeat again

---

## Hard Rule During This Sequence

- Do NOT batch-accept all downstream sheets at once.
- Finish one sheet, run nukki, compare against the walk anchor and quality
  reference, and only then move to the next.
- If identity drift or body-read drift appears at any step, stop there and
  regenerate that same step before continuing.
- Do NOT overwrite `items/` files until the user explicitly decides to promote
  the accepted `.tmp` candidates.

---

## Quick QA Focus Every Time

Compare directly against:
- `.tmp/menhera_original_identity_walk_v1.png`
- `items/menhera_boss_victory.png`

Check every sheet for:
- Same fluffy curly pink+cream hair mass
- Same check cap + red ribbon + syringe
- No black cat ears
- Same gray / silver eyes + strong lashes
- Same heart cheek mark
- Same four black bows + white front panel
- Same gray cat-paw gloves + pink toe beans
- Same med-kit / bunny-ear accessory
- Same pink check cloth/tail motif
- Same white sheer thigh-highs + black ankle X accessories
- Same body read at gameplay size
- Same or better crispness than the old victory sheet

---

## Final Handoff After All Downstream Passes

After attack + dash + turn + victory + defeat all pass QA:

1. Decide whether to promote the accepted `.tmp` sheets into `items/`.
2. Then notify Codex for runtime smoke check / integration verification.
3. Ask Codex to verify:
- walk / attack / dash / turn / victory / defeat body-read continuity
- gameplay-scale face readability
- no runtime scaling side effects after the art refresh
```
