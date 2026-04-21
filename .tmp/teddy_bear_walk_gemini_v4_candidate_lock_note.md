# Teddy Bear Walk Gemini V4 Candidate Lock Note

Date: 2026-04-18
Workflow mode: fast
Branch: Teddy Bear front-facing walk (Gemini single-shot)
Scope: candidate lock only — no canonical overwrite, no runtime wire-up

---

## Decision

- **V4 = current best Gemini fast-mode candidate for Teddy Bear front-facing walk.**
- **Gemini single-shot retake branch is STOPPED here.** V5 proved that further
  narrow Gemini corrections break other identity elements (pink bow moved
  from head to neck, motion flattened). Gemini has hit its local optimum on
  this brief.
- No `items/` canonical overwrite at this step. V4 stays in `.tmp/` as a
  locked candidate pending either in-game review or a precise FLUX yaw-only
  touch-up.

---

## V4 strengths (why it locks)

- Pure front-facing body lock: shoulders level, chest / heart patch facing
  the viewer, face centered, no torso / shoulder / pelvis rotation.
- Identity restored after V3 drift:
  - LEFT eye: attached black button with red X stitch
  - RIGHT eye: empty dark socket + small detached black button hanging
    straight down on a short white thread (no "coin / magnifying glass /
    mouth-side pin" drift)
  - Pink gingham bow: large, on top of the head, clear gingham pattern,
    same on all frames
  - Cream neck ribbon: small bow under the chin
  - Stitched heart belly patch: center of the belly, visible outline
  - Safety pin: on the upper chest, above the heart patch, not overlapping
  - Small black paw bow: on the same paw (viewer's left) across all frames
  - Bandage patches and plush stitching preserved
- Canvas: no cell borders, no dividers, pure white background.
- Motion: legs visibly alternate across the 8 frames (f1 left-forward,
  f4 right-contact, etc.), frame separation readable.

## V4 weaknesses (accepted at fast-mode lock)

- Slight rightward glance / very faint head yaw across the sheet.
- Arm swing is asymmetric: left paw lifts slightly in f1 / f5, right paw
  stays close to the side across all frames.
- Vertical body bob is mild; frame-to-frame head-top Y does not move as
  much as the prompt asked for.

These are tolerated here because V5 showed that pushing Gemini further to
fix them causes identity regressions.

---

## V5 reject reasons (recorded)

- Pink gingham bow moved from the top of the head to the neck area,
  merging with the ribbon into a neck-tie look (identity-class change).
- Cream neck ribbon deformed into a trailing tail under the moved bow.
- Safety pin drifted from center-upper chest to the left shoulder.
- Heart patch color drifted toward red.
- Motion flattened: leg alternation weakened, arm swing disappeared,
  vertical bob vanished — closer to idle gallery than V4.
- One win: rightward glance was actually corrected in V5, but the cost
  was too high.

## V3 reject reasons (for record)

- Dangling right eye turned into a round pin near the mouth instead of a
  button hanging from an empty socket.
- Cell dividers / borders appeared between frames.
- Pink gingham bow weakened in size and pattern.
- Safety pin overlapped the heart patch.
- Black paw bow disappeared on some frames.

## V2 reject reason (for record)

- Squared-torso lock landed perfectly, but the 8 frames collapsed into an
  idle gallery (no alternating legs, no arm swing, no bob).

---

## File locations

- V4 raw (Gemini output, actual current path):
  `C:\Users\woduq\AppData\Roaming\gemini-mcp\output\6dfd1a58ab9954b9\image-1776523484118.jpeg`
- Expected tmp-naming if V4 is copied into the repo tmp pool:
  - `.tmp/teddy_bear_walk_gemini_frontwalk_v4.jpeg`
  - `.tmp/teddy_bear_walk_gemini_frontwalk_v4.png` (preview; nukki is a
    separate step and does not run at this lock)

Prompts and handoffs for this branch:
- `.tmp/teddy_bear_walk_frontfacing_gemini_prompt_v1.txt` (initial brief)
- `.tmp/teddy_bear_walk_frontfacing_gemini_prompt_v2.txt` (pure front-facing
  squared torso)
- `.tmp/teddy_bear_walk_frontfacing_gemini_prompt_v3.txt` (motion retry)
- `.tmp/teddy_bear_walk_frontfacing_gemini_prompt_v4.txt` (identity pin)
- `.tmp/teddy_bear_walk_frontfacing_gemini_prompt_v5.txt` (yaw-only
  correction attempt — caused drift)
- `.tmp/claude_teddy_bear_walk_frontfacing_gemini_handoff_v1.md`
- `.tmp/claude_teddy_bear_walk_frontfacing_gemini_handoff_v2.md` (V5 retake)
- `.tmp/claude_teddy_bear_walk_gemini_v4_candidate_lock_handoff.md`
  (this lock branch)

---

## Next-step options (only two)

1. **In-game candidate review.**
   Move V4 into `.tmp/` under the expected tmp name, run nukki, and judge
   V4 at gameplay scale side-by-side with the current accepted FLUX-based
   walk before committing to a canonical overwrite.

2. **FLUX yaw-only precise touch-up.**
   Use V4 as the reference and apply a narrow FLUX Kontext correction
   targeting only head yaw / eye aim / muzzle alignment. No frame
   expansion, no redesign, no motion re-brief. See
   `.tmp/claude_teddy_bear_walk_flux_yaw_only_touchup_handoff_v1.md`.

Do NOT start nukki, frame expansion, publish staging, or runtime wire-up
from this lock step. Those belong to precise-mode branches downstream.

---

## Explicit scope split (handoff usage)

- `claude_teddy_bear_walk_gemini_v4_candidate_lock_handoff.md` = freeze
  V4 as the Gemini fast-mode candidate and stop Gemini retakes. This note
  is the deliverable of that handoff.
- `claude_teddy_bear_walk_flux_yaw_only_touchup_handoff_v1.md` = optional
  precise-mode FLUX branch that consumes V4 and tries a surgical yaw-only
  correction. Triggered only on explicit user request.
