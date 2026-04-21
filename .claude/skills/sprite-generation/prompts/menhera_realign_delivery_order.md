# Menhera Realign Delivery Order

Claude / Gemini 전달 순서표 for the Stage 3 Menhera post-walk realignment pass.

Current state:
- `items/menhera_boss_sheet.png` has already been regenerated and accepted as
  the NEW canonical walk sheet.
- This means all downstream sheets must now align to the NEW walk sheet's:
  identity, body-scale reference, face readability, glove/arm separation,
  bangs/face separation, and black-trim readability.

---

## Send Order

### 1. Attack realign

Send:
- [menhera_attack_realign.md](./menhera_attack_realign.md)

Expected outputs:
- `items/menhera_boss_attack.jpeg`
- `items/menhera_boss_attack.png`

Gate before moving on:
- Hair / face / eyes / ribbon / gloves / tail all read as the same character as
  the NEW walk sheet
- Head / torso / pelvis stay within +/-5% of the NEW walk sheet
- Face readability survives gameplay-scale downread
- Black glove vs arm vs dress separation is clear
- Black trim readability does not drop below the NEW walk sheet

If any of the above fail:
- Reject and regenerate attack again
- Do NOT proceed to dash yet

---

### 2. Dash realign

Send:
- [menhera_dash_realign.md](./menhera_dash_realign.md)

Expected outputs:
- `items/menhera_boss_dash.jpeg`
- `items/menhera_boss_dash.png`

Gate before moving on:
- Character still reads as the exact same Menhera as the NEW walk sheet
- Visible body read is NOT smaller than the NEW walk sheet
- Trails / motion accents extend outward without compressing the body
- Face, bangs, eyes, gloves, trim, and tail remain readable at gameplay size
- Front-readable framing survives the fastest frames

If any of the above fail:
- Reject and regenerate dash again
- Do NOT proceed to victory yet

---

### 3. Victory realign

Send:
- [menhera_victory_realign.md](./menhera_victory_realign.md)

Expected outputs:
- `items/menhera_boss_victory.jpeg`
- `items/menhera_boss_victory.png`

Gate before moving on:
- Same identity and body class as the NEW walk sheet
- Celebration pose stays front-readable and clean at gameplay size
- Eyes / eyelids / mouth / bangs still read clearly
- Gloves, trim, and silhouette remain crisp
- No oversized celebratory FX that make the body feel smaller

If any of the above fail:
- Reject and regenerate victory again
- Do NOT proceed to defeat yet

---

### 4. Defeat realign

Send:
- [menhera_defeat.md](./menhera_defeat.md)

Expected outputs:
- `items/menhera_boss_defeat.jpeg`
- `items/menhera_boss_defeat.png`

Gate before final acceptance:
- Same identity and body class as the NEW walk sheet
- Collapse / slump progression reads clearly without becoming comedic,
  grotesque, or side-profile dominant
- Face / bangs / gloves / trim / tail remain readable at gameplay size
- Ground plane and body silhouette stay coherent across F4-F8
- Body does NOT visually shrink during collapse

If any of the above fail:
- Reject and regenerate defeat again

---

## Hard Rule During This Sequence

- Do NOT batch-accept all four sheets at once.
- Finish one sheet, run nukki, compare against the NEW walk sheet, and only
  then move to the next.
- If identity drift or visible body read drift appears at any step, stop there
  and regenerate that same step before continuing.

---

## Quick QA Focus Per Step

For every regenerated sheet, compare directly against:
- `items/menhera_boss_sheet.png`

Check these every time:
- Same hair mass / face / eyes / ribbon / cat ears
- Same glove shape and darkness
- Same dress silhouette and black trim visibility
- Same tail thinness and readability
- Same body read at gameplay size
- No return to the older softer / blurrier face treatment

---

## Final Handoff After All Four Pass

After attack + dash + victory + defeat all pass QA:

1. Notify Codex that the downstream Menhera sheets have been realigned to the
   NEW canonical walk sheet.
2. Ask for an in-game visual smoke check in Stage 3.
3. Ask Codex to verify:
   - walk / attack / dash / victory / defeat body-read continuity
   - gameplay-scale face readability
   - no runtime scaling side effects after the art refresh

Use this existing handoff template as a base when needed:
- [handoff_codex.md](./handoff_codex.md)
