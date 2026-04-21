# Menhera Victory-Anchor Full Refresh Prompt

Use this when `items/menhera_boss_victory.png` is clearly the best-looking,
sharpest, most readable Menhera sheet in the set, and the lower-quality walk /
attack / dash / turn sheets must be regenerated upward to match it.

---

```text
Per d:\main\bosspong\CLAUDE.md and the sprite-generation skill, regenerate the
FULL gameplay sprite set for real-stage 3 boss Menheragirl
(code current_stage == 3).

This is a VICTORY-ANCHOR FULL REFRESH.

Current problem:
- items/menhera_boss_victory.png is visibly sharper, cleaner, and more
  high-resolution in character read than the current walk / attack / dash /
  turn sheets
- The current gameplay set feels mixed-quality: victory looks like the target
  render tier, while the other sheets look softer / lower-detail / lower-grade
- That mixed-quality state is NOT acceptable

Hard direction:
- Do NOT downgrade or simplify the victory sheet
- Regenerate the lower-quality gameplay sheets UP to the victory sheet's visual
  quality tier
- Victory is the MASTER visual-quality and exact-character anchor for this pass

Master visual / identity / quality anchor:
- items/menhera_boss_victory.png
Use this for:
- exact same Menhera identity
- face rendering quality
- hair rendering quality
- eye clarity
- palette and softness balance
- outline confidence
- fabric / trim readability
- overall crisp pixel readability at gameplay size

Secondary motion-intent references only:
- items/menhera_boss_sheet.png
  Use ONLY for broad front-biased walk intent and Stage 3 body class.
  Do NOT copy its lower-quality rendering tier.
- items/menhera_boss_attack.png
  Use ONLY for broad attack timing / emotional beat ideas.
  Do NOT copy its softer rendering tier.
- items/menhera_boss_dash.png
  Use ONLY for broad dash timing / speed-beat ideas.
  Do NOT copy its softer rendering tier.
- items/menhera_boss_turn.png
  Use ONLY for broad turn coverage intent.
  Do NOT copy its softer rendering tier or any mismatched character read.

Exact identity lock (must match the victory sheet):
- Very pale pastel pink bob haircut
- Pink nurse cap with pink cross
- ONE pink ribbon on the character's right side
- Black cat ears
- Olive eyes
- Black cat-paw gloves
- Thin black cat tail
- Pink nurse dress with black trim
- Small black shoes
- Chibi petite-human / about 2-head proportions
- Thick black pixel outlines

Cross-sheet quality lock:
- Walk / attack / dash / turn must all look like they belong to the SAME
  rendering tier as the victory sheet
- Do NOT accept a mixed set where victory is crisp and the gameplay sheets are
  visibly blurrier, muddier, flatter, or less resolved
- If a regenerated gameplay sheet still looks materially lower-quality than the
  victory sheet, reject and regenerate it

Cross-sheet body-read lock:
- Head / torso / pelvis scale must stay within +/-5% across walk / attack /
  dash / turn
- Visible body read must remain stable at gameplay size
- Effects or motion accents may extend outward, but the body itself must not
  read smaller than the walk baseline

Required generation order:
1. Walk
2. Attack
3. Dash
4. Turn

Do NOT batch-accept them all at once.
Generate one candidate, run nukki, QA it against the victory sheet and the
already-accepted regenerated sheets, then move on.

Step 1. WALK regeneration

Goal:
- Create a NEW walk candidate that finally matches the victory sheet's quality
  tier
- Keep the boss front-facing during stable left/right movement
- Add a slightly raised-head, farther-looking emotional read

Walk-specific art direction:
- Stable walk remains FRONT-FACING, not hidden 3/4
- The head posture is slightly lifted
- The face / eyes should feel like she is looking a little farther out into the
  middle distance, not down at her feet and not staring blankly straight ahead
- This should read as mildly aloof / slightly detached / faintly upward-looking,
  but still combat-readable and still the same character
- Do NOT overdo the chin lift into a profile or sky-looking pose
- Do NOT create left-looking or right-looking bias
- Normal lateral movement should feel composed and front-readable, not like a
  big bounce cycle
- Put most movement energy into legs, hem, ribbon, tail, and subtle whole-body
  rhythm instead of exaggerated torso hopping

Walk sheet composition:
- 8-frame walking sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- Pure flat white background (#FFFFFF) in every cell
- NO grid lines, NO borders, NO dividers, NO labels
- Character exactly centered in every frame
- Foot / baseline position consistent across frames
- Character remains front-facing in every frame
- Leave generous empty margin around each sprite
- Character fills only about 45-55% of each cell's height

Walk hard reject conditions:
- Reject if the result still looks lower-quality than the victory sheet
- Reject if stable movement reads as side-biased
- Reject if moving right feels like she is looking left
- Reject if moving left feels like she is looking right
- Reject if the head-lift / farther-looking note is missing
- Reject if the lifted-head note is achieved by turning into a 3/4 view

Step 2. ATTACK regeneration

Goal:
- Regenerate attack so it matches the NEW walk candidate and the victory
  sheet's render quality
- Preserve strong impact readability without shrinking the body

Attack direction:
- 8-frame attack sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- Front-readable attack flow: ready -> charge -> release / impact -> recovery
- Fierce, unstable, emotionally intense, but still the same Menhera
- Face / eyes / hair / trim / gloves must stay as crisp and readable as the
  victory sheet
- Motion can be strong, but body read must stay stable

Attack hard reject conditions:
- Reject if the result looks softer or blurrier than the victory sheet
- Reject if impact is expressed by shrinking the body
- Reject if the character reads as a different Menhera

Step 3. DASH regeneration

Goal:
- Regenerate dash so it matches the NEW walk candidate and the victory
  sheet's render quality
- Preserve speed without losing front readability

Dash direction:
- 8-frame dash sheet, 4x2 grid, aspectRatio 16:9, imageSize 2K
- Low, quick, unstable forward burst with crisp face / hair / trim readability
- Trails and motion accents are allowed, but must not visually compress the
  body
- The body and face must still read at the same quality tier as victory

Dash hard reject conditions:
- Reject if the result still feels lower-resolution than victory
- Reject if trails make the body read smaller
- Reject if the face collapses into muddy blur at gameplay size

Step 4. TURN regeneration

Goal:
- Regenerate turn support so it matches the NEW walk candidate and the victory
  sheet's render quality
- Keep it brief, auxiliary, and front-biased enough for PingFighter

Turn direction:
- Preferred full output: 13-frame turn sheet, 7x2 grid, last cell blank
- Use the skill's chibi turn fallback ladder if the full turn repeatedly fails
- Turn is NOT a default walking replacement
- Keep the same crisp identity and body read as victory / walk
- Brief direction-change support only
- Very light spring / poised pivot feeling is okay
- Do NOT make it look like a big jump or a different character

Turn hard reject conditions:
- Reject if the result looks like a softer or blurrier sheet than victory
- Reject if mid-angles collapse into fake frontal copies or a different face
- Reject if the turn sheet reads like a separate character

Gameplay-scale readability is mandatory for all four sheets:
- Face, eyes, bangs, mouth, gloves, trim, tail, and silhouette must stay
  readable at small in-game size
- Preserve clear separation between hair, face, arms, dress, gloves, and tail
- Reduce muddy midtones
- Preserve pastel softness, but do NOT solve readability with painterly
  rendering, realism, or harsh anime contrast

Style rules for all four sheets:
- 16-bit retro pixel art
- Chibi proportions
- Thick black pixel outlines
- Flat limited-saturation palette
- Clean hard-edged pixels
- NO painterly rendering
- NO soft shading
- NO photorealism

Output safety rule:
- Do NOT overwrite items/menhera_boss_sheet.png yet
- Do NOT overwrite items/menhera_boss_attack.png yet
- Do NOT overwrite items/menhera_boss_dash.png yet
- Do NOT overwrite items/menhera_boss_turn.png yet

First generate candidates only:
- .tmp/menhera_victory_anchor_walk_v1.jpeg
- .tmp/menhera_victory_anchor_attack_v1.jpeg
- .tmp/menhera_victory_anchor_dash_v1.jpeg
- .tmp/menhera_victory_anchor_turn_v1.jpeg

Then run:
- py .claude/skills/sprite-generation/remove_bg.py \
    .tmp/menhera_victory_anchor_walk_v1.jpeg \
    .tmp/menhera_victory_anchor_walk_v1.png
- py .claude/skills/sprite-generation/remove_bg.py \
    .tmp/menhera_victory_anchor_attack_v1.jpeg \
    .tmp/menhera_victory_anchor_attack_v1.png
- py .claude/skills/sprite-generation/remove_bg.py \
    .tmp/menhera_victory_anchor_dash_v1.jpeg \
    .tmp/menhera_victory_anchor_dash_v1.png
- py .claude/skills/sprite-generation/remove_bg.py \
    .tmp/menhera_victory_anchor_turn_v1.jpeg \
    .tmp/menhera_victory_anchor_turn_v1.png

These are candidates only.
Nothing becomes canonical until QA confirms:
- same exact Menhera as the victory sheet
- same render-quality tier as the victory sheet
- same body class across walk / attack / dash / turn
- front-biased walk still reads correctly in stable movement
```
