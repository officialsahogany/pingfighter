# Menhera Boss Turn Sheet Decision — R1 Accepted

## Decision

Adopt `turn V3` as the runtime playback turn sheet candidate.

Do **NOT** treat `turn V3` as a canonical identity anchor.

`items/menhera_boss_sheet.png` remains the **sole canonical identity anchor**
for all future regeneration work:
- attack
- dash
- victory
- defeat
- any derived animation or corrective pass

`turn V3` is accepted only as a **runtime playback auxiliary turn sheet**.
It is a **non-anchor** asset.

## Reason

Repeated narrow FLUX Kontext passes established a stable pattern:

- already-solved identity props are preserved reliably
- selective detail removal is reliable
- prominent color-element relocation is unreliable
- the cap side-accent language behaves like a persistent attractor and does not
  relocate cleanly to a single front-center ribbon

Further V5-style narrow passes are expected to produce lateral moves rather than
clear upgrades.

## Accepted Divergence

The turn sheet retains side-accent cap ribbon language instead of the canonical
walk's front-center ribbon language.

This divergence is accepted **only** as a runtime cosmetic deviation for the
turn sheet.

It must **not** propagate into future generated assets.

## Guardrails

- Canonical walk is the **only** identity anchor.
- `turn V3` is runtime-only and non-anchor.
- Do **not** use `turn V3` or `turn V4` as reference for future
  attack/dash/victory/defeat regeneration.
- Future regen must reference the canonical walk plus approved prop references,
  never the turn sheet alone.
- If later art work needs a turn reference, treat `turn V3` as motion/playback
  reference only, not identity reference.

## Runtime Status

Asset-side lock is accepted under `R1`.

Code-side runtime migration to the `4x2` turn loader may proceed only after:
- explicit frame-order definition
- local playback QA
- reconnect-to-walk QA

## Runtime QA Gates Before Swap

- correct `4x2` slicing
- explicit `TURN_FRAME_ORDER` for intended 8-frame playback
- no face clipping
- reconnect from final turn frame back into walk remains natural
- no regressions in hop-only fallback behavior
- keep `RENDER_TURN_FRAMES` disabled in shipping until playback QA passes

## Rejected Options

- more `V5`-style narrow passes: rejected as likely lateral move
- using `turn V3` as a future identity anchor: rejected
- relaxing future regen policy without anchor guardrails: rejected
