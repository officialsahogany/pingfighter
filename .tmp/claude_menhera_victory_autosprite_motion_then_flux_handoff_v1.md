# Claude Handoff Prompt: Menhera Victory AutoSprite Motion Block -> FLUX Render

아래 프롬프트를 그대로 Claude에 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Menheragirl victory sheet 재제작의 새 실험 경로다.

핵심 전략:
- old victory를 motion master로 쓰지 않는다
- 대신 AutoSprite로 새 victory motion block을 만든다
- 그다음 FLUX Kontext로 canonical Menhera identity를 입힌다

즉 역할 분리는 이렇게 한다:
- canonical walk = sole identity anchor
- AutoSprite = motion ideation / celebration blocking only
- FLUX = final identity-preserving render

중요:
- `d:\main\bosspong\CLAUDE.md`를 따른다
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행한다
- 이번 패스는 runtime integration이 아니다
- canonical overwrite는 하지 말고 `.tmp` 후보 + QA까지만 한다
- old victory backup은 입력 레퍼런스로 사용하지 않는다
- current runtime victory도 입력 레퍼런스로 사용하지 않는다

왜 이 경로를 쓰는가:
- old victory는 celebration acting은 있었지만 디자인이 낡아서 FLUX에 identity leak를 유발했다
- direct FLUX full-sheet는 identity는 잡아도 celebration acting이 너무 평평해졌다
- 따라서 motion source와 identity source를 완전히 분리해야 한다

==================================================
STEP 1. AUTOSPRITE MOTION BLOCK
==================================================

목표:
- Menhera victory 8-frame motion block만 만든다
- 여기서는 final pixel identity가 목적이 아니다
- 중요한 건 "승리했을 때 진짜 기쁜 모션"의 리듬과 peak/recovery arc다

AutoSprite reference:
1. canonical walk for proportions / front-read only
- `d:\main\bosspong\items\menhera_boss_sheet.png`

2. dense identity board for broad silhouette only
- `d:\main\bosspong\.tmp\menhera_autosprite_reference_board_v2.png`

AutoSprite prompt direction:
- 8-frame victory sequence
- 4x2 sheet
- front-facing chibi nurse-girl celebration
- must read as unmistakable victory celebration
- NOT a walk loop
- NOT a turn extension
- NOT a left-right sway cycle
- NOT idol dancing
- small hop / bounce / excited paw lift / delighted body rise
- clear build -> peak triumph -> hold -> afterglow
- keep figure front-biased and gameplay-readable

critical AutoSprite rule:
- identity precision is NOT the acceptance criterion here
- motion readability is the acceptance criterion
- if AutoSprite invents wrong ribbons / props / face details, that is acceptable at this step
- but if the sequence still reads flat or turn-like, reject and retry

AutoSprite outputs:
- `.tmp/menhera_victory_autosprite_motion_v1.png`
- optional:
  - `.tmp/menhera_victory_autosprite_motion_v1_zoom.png`
  - `.tmp/menhera_victory_autosprite_motion_v1_report.md`

AutoSprite QA:
1. does the sequence clearly read as victory?
2. is there a true peak triumph frame?
3. does the motion rise vertically rather than sway laterally?
4. can this serve as motion-only blocking for FLUX?

If NO, retry AutoSprite once with stronger "victory hop / triumph / happy rise" wording.
Do not move to FLUX unless the motion block is clearly better than the current runtime victory in celebration acting.

==================================================
STEP 2. FLUX KONTEXT FINAL RENDER
==================================================

목표:
- AutoSprite motion block의 acting만 가져오고
- canonical walk identity를 완전히 유지한 Menhera victory sheet를 만든다

FLUX reference stack:
1. primary identity master
- `d:\main\bosspong\items\menhera_boss_sheet.png`

2. motion block only
- `.tmp/menhera_victory_autosprite_motion_v1.png`

3. dense identity board
- `d:\main\bosspong\.tmp\menhera_autosprite_reference_board_v2.png`

explicit exclusions:
- do NOT use old victory backup as input
- do NOT use current runtime victory as input
- do NOT use turn sheet as an identity anchor

FLUX method:
- prefer `flux_kontext_max`
- first try full 8-frame sheet direct render
- if full-sheet holds identity and celebration, keep it
- if full-sheet still wobbles, recommend peak-first descent using the AutoSprite motion block only for the peak pose design

identity lock (must match canonical walk exactly):
- fluffy pink outer hair
- cream/blonde inner front bangs
- rounded fluffy hair silhouette
- pink/white gingham nurse cap
- syringe on cap
- large gray/silver eyes with lashes
- exactly one pink heart cheek mark on viewer-right cheek
- pink outfit with white center panel
- target is four black bows in a clean vertical stack
- gray cat-paw gloves with visible pink pads
- same-side med-kit pouch
- pink check cloth-tail motif
- plain white thigh-highs
- black X ankle accessories
- same petite chibi body class
- thick black pixel outlines

hard anti-drift rules:
- no old-victory twin-tail branch
- no random red side-ribbon redesign
- no anime-soft rendering
- no turn-like sway sequence
- no flat idle posing
- no loss of syringe / paw pads / med-kit
- no pink trim reappearing on socks

celebration acting rules:
- keep the AutoSprite celebration energy
- preserve the rise -> peak triumph -> hold -> afterglow arc
- at least one frame must read as a real "I won!" peak
- expression can brighten or smile, but must remain the same Menhera

FLUX outputs:
- `.tmp/menhera_flux_kontext_victory_from_autosprite_v1.png`
- `.tmp/menhera_flux_kontext_victory_from_autosprite_v1.jpeg`
- optional:
  - `.tmp/menhera_flux_kontext_victory_from_autosprite_v1_zoom.png`
  - `.tmp/menhera_flux_kontext_victory_from_autosprite_v1_vs_runtime.png`
  - `.tmp/menhera_flux_kontext_victory_from_autosprite_v1_vs_walk.png`
  - `.tmp/menhera_flux_kontext_victory_from_autosprite_v1_report.md`

final QA:
1. AutoSprite motion block was usable or not?
2. FLUX preserved canonical walk identity or not?
3. final sequence reads as true victory celebration or not?
4. any old-victory-like leak present or not?
5. is this a true upgrade over the currently applied runtime victory?
6. can this go to publish candidate, or should we descend to peak + frame expansion next?

important success definition:
- better celebration acting than the current runtime victory
- no old-victory identity leak
- same exact Menhera as canonical walk
```
