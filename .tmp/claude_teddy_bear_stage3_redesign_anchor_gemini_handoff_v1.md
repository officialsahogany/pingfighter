# Claude Handoff Prompt: Stage 3 Teddy Bear Redesign Anchor via Gemini V1

아래 프롬프트를 그대로 Claude에 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Teddy Bear boss의 리디자인 anchor 제작이다.

이번 패스에서는 FLUX가 아니라 Gemini MCP를 먼저 사용한다.

이유:
- 테디베어는 아직 accepted canonical sprite-sheet anchor가 없다
- 이번 목표는 "기존 자산 보정"이 아니라 "Stage 3용 새 디자인 발명"이다
- 따라서 reference-conditioned FLUX보다 Gemini 쪽이 초기 concept redesign에 더 적합하다

중요:
- `d:\main\bosspong\CLAUDE.md`를 따른다
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행한다
- 이번 단계는 sprite sheet가 아니라 redesign anchor 제작이다
- runtime integration / canonical overwrite는 하지 않는다
- `.tmp` 후보 + QA까지만 만든다

현재 테디베어 기준 reference:
1. current procedural teddy reference
- `d:\main\bosspong\.tmp\teddy_bear_procedural_reference_v1.png`

2. Stage 3 Menhera accessory / mood reference
- `d:\main\bosspong\items\menhera_boss_sheet.png`

3. optional mood / readability reference
- `d:\main\bosspong\items\menhera_boss_victory.png`
- use only for Stage 3 mood / readability tier, not for copying Menhera body design

핵심 목표:
- still unmistakably a plush teddy bear boss
- but upgraded into a richer Stage 3 menhera-themed decorated plush design
- more lavish, more memorable, more eerie-cute
- strong enough to become the future identity anchor for teddy sprite work

must preserve from current teddy:
- plush teddy silhouette
- warm brown / cocoa fur family
- stitched seam language
- uncanny damaged plush feeling
- button-eye / dangling-eye horror-cute logic
- belly heart motif
- ribbon / bow presence
- readable plush paws and stuffed limbs

must add / strengthen for Stage 3 redesign:
- pink / cream / rose accent language
- menhera / yamikawa accessory flavor
- nurse-adjacent accent details without turning it into a human nurse
- more striking head accessory
- richer torso motif / patchwork / charm hierarchy
- better gameplay-scale silhouette read

design guardrails:
- do NOT turn it into a human girl in bear cosplay
- do NOT give it a human face
- do NOT put it in a full human dress
- do NOT lose the plush stuffed-animal body logic
- do NOT over-detail it until it becomes unreadable in sprites
- keep accessory count controlled: one major statement accessory, one or two secondary details

good accessory examples:
- gingham nurse bow
- tiny syringe charm
- safety pin charm
- bandage patch
- stitched heart emblem / heart lock charm
- lace-edged plush bib / collar accent

bad direction examples:
- full maid dress
- full nurse uniform
- generic pastel mascot teddy with no uncanny edge
- fully realistic horror bear
- overly painterly soft illustration that will not transfer to sprites

render / framing target:
- one strong front-facing full-body redesign anchor
- square framing, preferably 1024x1024
- pure white background
- full body fully visible
- generous margin
- sprite-transfer-friendly clarity

prompt to use with Gemini MCP:

Design a front-facing full-body boss teddy bear for a retro pixel-art game. This is Stage 3's redesigned teddy bear: an eerie-cute lavish plush teddy with menhera-themed decoration. It must still read unmistakably as a stuffed teddy bear first, not a human girl, not a mascot costume, not a doll-human hybrid.

Keep these core teddy traits:
- plush teddy silhouette
- warm cocoa-brown fur
- visible stitched seams and patchwork logic
- one uncanny eye treatment: button-eye / dangling-eye / damaged plush eye language
- heart motif on the belly
- ribbon / bow accessory language
- plush paws and stuffed-limb body logic

Upgrade it into a richer Stage 3 menhera / yamikawa direction:
- dusty pink, cream, rose, and soft black accents
- a stronger main head accessory such as a gingham nurse bow or plush ribbon statement
- one or two secondary menhera-plush details such as a tiny syringe charm, safety pin charm, bandage patch, stitched heart lock, or plush bib accent
- more memorable asymmetry
- cute but unsettling plush-toy mood

Important constraints:
- do NOT humanize the face
- do NOT dress it like a full human nurse or maid
- do NOT remove the teddy-bear species read
- do NOT make it generic cute mascot art
- do NOT make it painterly or soft-anime illustration
- keep the design readable enough to later convert into sprite sheets

Style target:
- retro pixel-art-friendly concept art
- chibi plush proportions
- thick readable outline logic
- flat limited-saturation palette
- clean silhouette
- white background

Deliver one strongest redesign anchor candidate first.

output targets:
- `.tmp/teddy_bear_stage3_redesign_anchor_v1.png`
- optional:
  - `.tmp/teddy_bear_stage3_redesign_anchor_v1_zoom.png`
  - `.tmp/teddy_bear_stage3_redesign_anchor_v1_vs_procedural.png`
  - `.tmp/teddy_bear_stage3_redesign_anchor_v1_report.md`

QA priorities:
1. still reads as the same teddy-bear boss species?
2. clearly stronger Stage 3 menhera decoration?
3. not too humanized?
4. not too generic?
5. strong enough to become the future anchor for walk-sheet work?

최종 보고 형식:
1. 어떤 reference stack을 사용했는지
2. procedural teddy에서 무엇을 유지했는지
3. Stage 3 menhera 쪽에서 무엇을 추가했는지
4. canonical redesign anchor 후보로 충분한지
5. 다음 단계가 walk first인지, 다른 준비가 필요한지
```
