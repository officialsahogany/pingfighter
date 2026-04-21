# Teddy Bear Attack -- Gemini Full-Sheet V2 Direction Fix

Use `CLAUDE.md`, `AGENTS.md`, and the `sprite-generation` skill.

This is the one fast-mode retake for the Gemini teddy attack branch.

## Why V1 is not accepted yet

Gemini attack v1 landed the first real success in this branch:
- 8 frames / 4x2 correct
- pixel-art class correct
- identity mostly correct
- clear prep -> impact -> recovery arc
- frame 6 clearly strongest impact

But the user flagged the actual blocker:
- the strike reads as slightly rightward / side-jabbing
- it does NOT read enough like a downward / centered ball-hit
- f5/f6 also inherit a slight rightward-looking feel

That is the main correction target.

## Goal

Keep everything V1 got right, but fix the strike direction:

- make the attack read as a centered, downward / downward-forward plush smack
- not a rightward jab
- not a side hit
- not a 3/4 strike pose

## Reference / context

Use the same teddy identity branch as before:
- walk candidate identity and proportion language
- attack v1 should be treated as "near miss" guidance only if needed conceptually,
  but do NOT let it preserve the rightward jab angle

## Required motion read

This is a contact-based attack for short anticipatory runtime use.

Sequence must remain:
- f1 ready
- f2 gather
- f3 compact coil
- f4 max charge
- f5 launch
- f6 strongest impact
- f7 follow-through
- f8 recovery

But:
- f5/f6/f7 must feel centered and downward
- paws should drive toward the ball lane in front of the teddy
- the face and torso must stay front-facing

## Identity locks

- LEFT red X button eye
- RIGHT empty socket + hanging button on white thread
- big pink gingham head bow on head
- cream neck ribbon
- heart belly patch
- upper chest safety pin
- left paw black bow
- same cocoa plush teddy, same body scale

## Visual locks

- 8 frames exactly
- 4 columns x 2 rows exactly
- pixel-art class exactly
- hard edges
- thick black outlines
- pure white background
- NO cell borders / divider lines

## New QA focus

Report explicitly:

1. Does the strike still read as rightward / sideways anywhere?
2. Does f6 now read as a centered downward impact?
3. Does the face stay centered in f5/f6/f7?
4. Did the dangling-eye structure survive again?
5. Were the stray cell borders removed?

## Decision policy

Allowed outcomes:
- `ACCEPT for runtime-facing candidate`
- `REJECT and stop`

Do not recommend another Gemini retake after this one.
