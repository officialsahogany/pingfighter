# Claude Handoff Prompt: Stage 3 Teddy Bear Menhera Redesign Anchor V1

아래 프롬프트를 그대로 Claude에 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Teddy Bear boss의 리디자인 anchor 제작이다.

목표:
- 먼저 스프라이트 시트가 아니라 "새 canonical redesign anchor"를 만든다
- 기존 프로시저럴 테디베어의 핵심 실루엣/정체성은 유지하되
- Stage 3의 menhera-themed, decorated, eerie-cute plush direction으로 업그레이드한다
- 이 anchor가 통과하면 그 다음에 walk / hit / victory 등 시트 작업으로 내려간다

중요:
- `d:\main\bosspong\CLAUDE.md`를 따른다
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행한다
- 이번 패스는 redesign anchor / concept lock용이다
- 아직 runtime integration이나 canonical overwrite는 하지 않는다
- `.tmp` 후보 + QA까지만 만든다

현재 상황:
- Teddy Bear는 아직 Menhera처럼 accepted sprite sheet set이 없다
- 현재 live visual identity는 procedural drawing 기반이다
- 따라서 이번 작업의 목적은 "procedural teddy를 대체할 새 시트"가 아니라
  먼저 "시트 작업의 기준이 될 새 디자인 anchor"를 정하는 것이다

reference stack:
1. current procedural teddy reference
- `d:\main\bosspong\.tmp\teddy_bear_procedural_reference_v1.png`

2. Stage 3 menhera identity / accessory language reference
- `d:\main\bosspong\items\menhera_boss_sheet.png`

3. optional stage mood / quality reference
- `d:\main\bosspong\items\menhera_boss_victory.png`
- use only for mood/readability tier, not for copying Menhera body design

디자인 목표:
- a lavish, eerie-cute plush teddy bear boss
- still unmistakably a teddy bear first
- but clearly belonging to Stage 3's menhera / yamikawa / nurse-adjacent aesthetic
- more decorated and memorable than the current procedural teddy
- suitable as a future gameplay sprite anchor, not just standalone illustration

must preserve from current teddy:
- plush teddy silhouette
- warm brown / dusty cocoa fur base
- stitched / seam language
- damaged / uncanny plush details
- button-eye / dangling-eye horror-cute energy
- heart motif on the body
- ribbon / bow presence
- plush paw / stuffed-limb body logic

Stage 3 redesign additions (encouraged):
- pink / cream / rose palette accents
- menhera-themed decorative accessories
- gingham or nurse-adjacent accent language
- heart / bandage / safety-pin / charm details
- more striking head accessory and torso accessory language
- clearer paw-pad / ribbon / stitch / button hierarchy
- richer silhouette read at gameplay scale

design constraints:
- DO NOT just turn the teddy into "Menhera girl as a bear"
- DO NOT give it a human face
- DO NOT lose the plush / stuffed-animal body logic
- DO NOT flatten it into generic cute mascot bear
- DO NOT overcomplicate so badly that the small gameplay read collapses

recommended redesign direction:
- silhouette:
  - big head, compact plush body, readable ears, readable paws
  - one memorable asymmetry

- face:
  - keep button-eye / dangling-eye horror-cute language
  - one eye can be more intact, the other more damaged / hanging / patched
  - same face must remain toy-like, not humanized

- accessory language:
  - one strong main bow / ribbon statement
  - one or two secondary Stage 3 menhera props only
  - examples:
    - gingham nurse bow
    - tiny syringe charm
    - safety pin charm
    - stitched heart belly emblem
    - bandage patch
    - heart lock / charm on ribbon
  - keep the accessory count controlled enough for sprite readability

- torso language:
  - stitched belly
  - heart motif can become more iconic
  - seam / burst seam / patchwork can stay

- paw / leg language:
  - plush paws should stay readable
  - paw pads or plush sole accents can be cleaner and cuter

style / render target:
- 16-bit retro pixel-art-friendly concept
- chibi / plush proportions
- thick black pixel outline logic
- flat limited-saturation palette
- clean hard-edged readability
- avoid painterly softness that will not transfer well to sprites

deliverable preference:
- create ONE strong front-facing full-body redesign anchor first
- 1024x1024 square framing preferred
- pure white background
- full body fully visible
- generous margin
- if helpful, optional secondary variant is okay, but one strongest primary candidate is preferred

output targets:
- `.tmp/teddy_bear_stage3_redesign_anchor_v1.png`
- `.tmp/teddy_bear_stage3_redesign_anchor_v1.jpeg`
- optional:
  - `.tmp/teddy_bear_stage3_redesign_anchor_v1_zoom.png`
  - `.tmp/teddy_bear_stage3_redesign_anchor_v1_vs_procedural.png`
  - `.tmp/teddy_bear_stage3_redesign_anchor_v1_report.md`

QA priorities:
1. still unmistakably the same teddy-bear boss species / silhouette?
2. clearly upgraded into Stage 3 menhera-themed decorated plush direction?
3. accessory language is richer, but still sprite-readable?
4. not too humanized, not too generic, not too muddy?
5. strong enough to become the future identity anchor for teddy sprite-sheet work?

hard reject:
- reads like a human girl in bear cosplay
- loses button-eye / uncanny plush energy completely
- too many tiny details to read in sprites
- generic teddy mascot with no Stage 3 identity
- over-rendered painterly look that breaks pixel-art transfer

final report format:
1. reference stack actually used
2. which current teddy traits were preserved
3. which Stage 3 / menhera redesign traits were added
4. whether this is strong enough to become the canonical teddy redesign anchor
5. if accepted, what the next sprite step should be (walk first / hit first / etc.)
```
