# Teddy Bear Attack V1 -- FLUX Anticipatory Contact Pass

Use `CLAUDE.md`, `AGENTS.md`, and the `sprite-generation` skill.

We are in `fast` mode by default, but this pass must still respect the repo's
attack-sheet rule: contact-based strike sheets should assume SHORT,
conservative anticipatory / pre-contact runtime triggering.

## Objective

Generate the first real attack-sheet candidate for the Stage 3 teddy bear boss.

This is **not** a generic "cute swipe" pass. The result must support a runtime
where Codex may start the sheet slightly before predicted ball contact so the
prep frames are visible and the strongest impact frame lands at or near the
actual hit.

## Canonical branch-local references

Use these references in this order:

1. `d:\main\bosspong\.tmp\teddy_bear_walk_gemini_plush_locomotion_v1_nukki_gapclean2.png`
   - Current accepted branch-local walk candidate
   - Absolute identity and body-scale master for this attack pass

2. `d:\main\bosspong\.tmp\teddy_bear_stage3_redesign_anchor_v1.png`
   - Original redesign anchor
   - Use to reinforce exact accessory language if FLUX softens details

3. `d:\main\bosspong\.tmp\teddy_bear_procedural_reference_v1.png`
   - Plush-body mechanics / stuffed-toy mass reference only
   - Do NOT regress to plain procedural teddy styling

Do NOT use old rejected teddy walk sheets as references.

## Tooling route

- Prefer `FLUX Kontext max`
- Use the walk candidate as `input_image`
- Use the redesign anchor as `input_image_2`
- Use the procedural teddy as `input_image_3`

## Motion brief

Use:
- short anticipatory double-paw plush smack / clap strike

Do NOT use:
- long cinematic wind-up
- human boxing jab
- side-facing slap
- profile rotation
- cute idle gallery with tiny paw wiggles

## Timing brief

This sheet is being authored for **anticipatory runtime**.

That means:
- frame 1 = ready
- frame 2 = paws gather
- frame 3 = compact coil
- frame 4 = max charge
- frame 5 = launch
- frame 6 = strongest impact frame
- frame 7 = follow-through
- frame 8 = recovery

The prep must be visible, but conservative.
Do NOT make a wind-up so slow that frame 6 would visually land before contact
if the runtime starts the sheet a little early.

## Identity hard locks

The teddy must remain the exact same character:
- LEFT red X button eye
- RIGHT dangling black button eye on white thread
- large pink gingham head bow on head
- cream neck ribbon
- heart belly patch
- safety pin on upper chest
- left paw black bow
- same cocoa fur, same face, same plush species read

## Visual constraints

- 8 frames
- 4x2 sheet
- 2K
- pure white background
- thick black outlines
- flat pixel-art read
- front-facing in every frame
- body scale tied to walk candidate

## Fast-mode execution rule

Do one strong first pass.
If the first pass is obviously broken, you may do at most one tightly scoped
retry.
Do NOT spiral into a long regeneration ladder in this branch.

## Output files

Save to:
- `.tmp/teddy_bear_attack_v1.jpeg`
- `.tmp/teddy_bear_attack_v1.png` if available
- `.tmp/teddy_bear_attack_v1_zoom.png`
- `.tmp/teddy_bear_attack_v1_report.md`

## QA checklist

Check these explicitly:

1. Same exact teddy as walk candidate
2. Frame 6 is clearly the strongest impact frame
3. Early frames contain meaningful prep
4. Prep is short enough for anticipatory runtime use
5. Front-facing read survives the whole sequence
6. No same-pose repeat or idle-gallery failure
7. Body read does not shrink below walk baseline

## Decision output

At the end, report one of:
- `ACCEPT for runtime-facing candidate`
- `HOLD for one scoped retry`
- `REJECT and stop`

If rejected, explain whether the failure is:
- identity drift
- prep too weak
- prep too long
- impact too flat
- body-scale drift
- front-facing read failure
