# Teddy Bear Attack V2 Report — Scoped Retry Outcome

Date: 2026-04-19
Workflow mode: fast
Tool: FLUX Kontext max
Inputs:
- `input_image`  = `teddy_bear_walk_gemini_plush_locomotion_v1_nukki_gapclean2.png` (walk candidate, branch-local canonical)
- `input_image_2` = `teddy_bear_stage3_redesign_anchor_v1.png` (redesign anchor)
- procedural teddy reference intentionally NOT passed (per v2 handoff, to reduce style drift competition)

Output: `.tmp/teddy_bear_attack_v2.jpeg`

---

## Decision

**REJECT and STOP.**

Per v2 handoff policy: "Do NOT recommend another retry after this one." No further
retry on this branch. Attack asset work pauses here until a different tool route
or a different design route is chosen.

---

## QA gates

| # | Gate | Result |
|---|---|---|
| 1 | Exactly 8 frames in a 4x2 grid | PASS |
| 2 | Pixel-art class matched to walk candidate | PASS (close enough to walk class, no painterly drift) |
| 3 | RIGHT dangling eye = empty socket + button hanging on white thread | **FAIL** — dangling structure lost; both eyes read as flat black buttons |
| 4 | No frame drifts to 3/4 or side-profile | PASS |
| 5 | Frame 6 is clearly the strongest impact frame | **FAIL** — all 8 frames read as near-identical standing poses |
| 6 | Early frames contain meaningful prep rather than idle posing | **FAIL** — no visible anticipation arc |

Additional identity drift outside the listed hard-reject gates:
- Heart belly patch shifts from solid tan/cream (walk baseline) to a split-color
  design (tan half + red/pink half with a bandage strip). Not in the same color
  family as the walk candidate.

Identity elements that DID survive:
- Layout (8 / 4x2) corrected from v1.
- Pixel-art style class recovered from v1's painterly drift.
- Front-facing lock held in every frame.
- LEFT red X button eye stayed on the left.
- Pink gingham bow stayed on the head.
- Cream neck ribbon under the chin.
- Safety pin on upper chest.
- Left paw black bow on every frame.

---

## Why this failed

Primary failure is motion, not identity. The v2 output is essentially eight
near-identical plush-standing poses — an idle gallery with minor pose jitter —
not an attack sequence. No clear ready / gather / coil / charge / launch /
impact / follow / recovery arc lands. Frame 6 is indistinguishable from f1.

Secondary failure is partial identity drift: the dangling right eye (a
canonical identity element of this teddy) flattened into a regular button in
every frame, and the heart patch color family drifted.

## Root-cause read

Pattern across attack v1 and v2:

- Given multi-image references, FLUX Kontext interprets the brief as
  "render variations of the reference pose" rather than authoring a new
  action sequence. The walk candidate's calm standing pose dominates, and
  the prompt's action language (ready / coil / impact / recovery) is
  treated as soft suggestions that do not override the reference posture.
- The dangling-eye gimmick is one of the fastest-to-collapse identity
  elements under FLUX Kontext, regardless of how explicitly the prompt
  describes it.
- Tightening the prompt further has diminishing returns. Layout and
  style-class issues corrected across v1 → v2, but motion did not.

This looks like a tool-fit issue for authoring a NEW action sheet
on this character, not a prompt engineering issue.

---

## Recommended next moves (branch-paused)

No automatic next step. Decision belongs to the user.

1. **Switch tool route for attack sheet.**
   Go back to Gemini MCP full-sheet generation (the known-good route in
   `sprite-generation` skill when FLUX drifts on pixel class or identity).
   Walk candidate stays as the identity description reference, but the
   action sequence is generated from scratch rather than image-to-imaged
   off a standing pose.

2. **Split the pipeline.**
   Use AutoSprite for motion ideation / peak-pose discovery on the attack
   action, then lock the strongest single peak pose in FLUX Kontext and
   expand the surrounding frames from that anchor — not from the walk
   candidate's standing pose.

3. **Pause attack work entirely.**
   Return to attack later, only after the walk branch is fully settled
   (nukki clean, in-game readability confirmed, runtime wire-up done).
   Current attack asset work does not block walk work.

Do NOT recommend another direct FLUX Kontext retry with the same reference
stack. That has now failed twice with the same tool-fit failure mode.

---

## File trail

Branch files used / produced for this attack pass:

- `.tmp/teddy_bear_attack_flux_anticipatory_prompt_v1.txt`
- `.tmp/claude_teddy_bear_attack_flux_anticipatory_handoff_v1.md`
- `.tmp/teddy_bear_attack_v1.jpeg` — REJECTED (layout 3x2, style drift, dangling eye loss, 3/4 drift, safety pin drift)
- `.tmp/teddy_bear_attack_flux_anticipatory_prompt_v2.txt`
- `.tmp/claude_teddy_bear_attack_flux_anticipatory_handoff_v2.md`
- `.tmp/teddy_bear_attack_v2.jpeg` — REJECTED (idle gallery, dangling eye loss, heart color drift)
- `.tmp/teddy_bear_attack_v2_report.md` — this file

No `items/` canonical overwrite. No runtime wire-up. Branch paused.
