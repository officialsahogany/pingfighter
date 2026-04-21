# Teddy Bear Attack -- Gemini Full-Sheet Fast Route

Use `CLAUDE.md`, `AGENTS.md`, and the `sprite-generation` skill.

## Branch state

- Teddy walk branch currently uses the Gemini plush-locomotion candidate in
  runtime review.
- Teddy attack FLUX branch is paused and should NOT be retried.
- `teddy_bear_attack_v1` and `teddy_bear_attack_v2` are both rejected.

Reason:
- FLUX Kontext multi-reference mode kept collapsing this task into
  near-idle standing galleries instead of a real action sequence.
- The scoped retry policy is exhausted for the FLUX attack branch.

## New route

Switch to **Gemini full-sheet fast mode** for attack ideation.

This is a fast-mode branch:
- get one strong first candidate
- if obviously close-but-not-there, do at most one retake
- do NOT build a long expansion ladder yet

## Goal

Generate the first Gemini attack-sheet candidate for the Stage 3 teddy boss.

This is a **contact-based anticipatory strike** sheet, not a projectile cast
and not a generic cute pose sheet.

Target read:
- short prep visible before contact
- strongest impact at frame 6
- quick follow-through and recovery

## Identity locks

The teddy must stay the same character:
- LEFT red X button eye
- RIGHT empty socket with detached hanging button on white thread
- large pink gingham head bow
- cream neck ribbon
- heart belly patch
- upper-chest safety pin
- left paw black bow
- cocoa plush body, same chibi teddy species read

## Motion brief

Attack concept:
- front-facing double-paw plush smack / clap strike
- compact stuffed-toy spring
- no human boxing
- no side turn
- no long cinematic wind-up

Required attack arc:
- f1 ready
- f2 gather
- f3 compact coil
- f4 max charge
- f5 launch
- f6 strongest impact frame
- f7 follow-through
- f8 recovery

## Output expectations

Save:
- `.tmp/teddy_bear_attack_gemini_v1.png` or `.jpeg`
- `.tmp/teddy_bear_attack_gemini_v1_zoom.png`
- `.tmp/teddy_bear_attack_gemini_v1_report.md`

## QA gates

Report explicitly:

1. Is it really 8 frames in 4x2?
2. Does frame 6 read as the strongest impact?
3. Are early frames meaningful prep instead of idle posing?
4. Did the dangling-eye structure survive?
5. Did front-facing read survive in every frame?
6. Does it feel more like a real strike than the rejected FLUX attempts?

## Decision

End with one of:
- `ACCEPT for runtime-facing candidate`
- `HOLD for one Gemini retake`
- `REJECT and stop`

If rejected, stop and summarize the failure mode instead of starting another
deep pipeline automatically.
