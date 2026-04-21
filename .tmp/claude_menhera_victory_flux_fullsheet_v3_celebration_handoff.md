# Claude Handoff Prompt: Menhera Victory FLUX Full-Sheet V3 Celebration-First

아래 프롬프트를 그대로 Claude에 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Menheragirl victory sheet의 재제작이다.

중요:
- `d:\main\bosspong\CLAUDE.md`를 따른다
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행한다
- 이번 패스는 victory 전용 full-sheet regeneration이다
- walk / attack / dash / turn / defeat / runtime code는 건드리지 않는다
- canonical overwrite는 하지 말고 `.tmp` 후보 + QA까지만 한다

왜 다시 만드는가:
- 직전 publish/runtime 적용본은 identity lock 자체는 좋았지만
- 실제 인게임에서는 "승리 celebration"보다는 "좌우 이동 / turn 연장선"처럼 읽힌다
- 즉 이번 문제는 character drift보다 acting drift다
- 이번 regen은 identity 유지 + unmistakable victory acting이 동시에 필요하다

핵심 정책:
- canonical walk remains the sole identity anchor
- old victory is NOT an identity anchor
- 하지만 이번에는 old victory를 motion / emotion master로 더 강하게 사용한다
- turn sheet는 이번 victory regen의 기준으로 사용하지 않는다
- "front-facing victory celebration"이 목표지 "turn-like sway"가 목표가 아니다

reference stack:
1. identity master (strongest identity lock)
- `d:\main\bosspong\items\menhera_boss_sheet.png`

2. motion / celebration master (use strongly for acting, not identity)
- `d:\main\bosspong\.tmp\menhera_victory_runtime_backup_20260418\menhera_boss_victory_old.png`

3. dense identity board
- `d:\main\bosspong\.tmp\menhera_autosprite_reference_board_v2.png`

4. optional current applied runtime victory for "what to avoid"
- `d:\main\bosspong\items\menhera_boss_victory.png`
- use only as a negative comparison reference after generation
- do NOT anchor on it

모델 / 방식:
- FLUX Kontext
- 가능하면 `flux_kontext_max`
- full 8-frame sheet direct generation first
- framewise descent는 이번 패스의 기본 경로가 아니다
- full-sheet가 celebration acting을 제대로 잡지 못할 때만 descent를 고려한다

시트 목표:
- 8-frame victory sheet
- 4x2 grid
- aspectRatio 16:9
- imageSize 2K
- pure white background
- no grid lines
- no labels
- no borders
- full body fully visible in every frame
- generous white margin

identity lock (must match canonical walk):
- fluffy pink outer hair
- cream/blonde inner front bangs
- rounded fluffy hair silhouette
- pink/white gingham nurse cap
- syringe on cap
- same Menhera face structure
- large gray/silver eyes with lashes
- exactly one pink heart cheek mark on viewer-right cheek
- pink outfit with white center panel
- preferred target is four black bows; if 3 bows appears but all other acting/identity wins are strong, note it explicitly instead of forcing a destructive retry
- gray cat-paw gloves with visible pink pads
- same-side med-kit pouch
- pink check cloth-tail motif
- white thigh-highs
- black X ankle accessories
- same petite chibi body class
- thick black pixel outlines

style lock:
- 16-bit retro pixel art
- chibi proportions
- thick black pixel outlines
- flat limited-saturation pastel palette
- clean hard-edged pixels
- NO anime-soft rendering
- NO painterly shading
- NO glossy mobile-game chibi feel

critical acting brief:
- this must read as a boss victory celebration
- NOT a walk loop
- NOT a turn extension
- NOT a left-right sway cycle
- NOT idle posing

required emotional read:
- delighted / thrilled / triumphant Menhera
- clear "I won" energy
- small but unmistakable joy burst
- same eerie-cute Menhera personality, not generic idol dance

required motion language:
- include visible upward celebration energy
- small hop / bounce / lift is allowed and encouraged
- at least one peak frame should read as a true victory moment, not just posture variation
- arm / paw gesture should feel like triumphant lift, clingy cheer, or excited paw-up expression
- hair / ribbon / skirt / tail rebound should support the upward beat
- body rhythm should rise and release, not just sway sideways

required face / expression language:
- face must remain the same Menhera across all 8 frames
- but expression is allowed to progress
- acceptable changes:
  - brighter eyes
  - pleased smile
  - slightly open happy mouth
  - subtle delighted squint on peak frames
- unacceptable changes:
  - becoming a different girl
  - hero-frame prettifying
  - different eye spacing
  - different bangs treatment
  - random closed-eye emoji face on unrelated frames

recommended 8-frame celebration arc:
- row 1
  1. post-win recognition
  2. joy starts to rise
  3. excited gather / paw lift
  4. upward push into celebration
- row 2
  5. peak triumph / happiest frame / slight hop or lifted body energy
  6. held celebration with strong proud-delighted read
  7. soft satisfied afterglow
  8. final happy hold

very important negative constraints:
- do NOT make the sequence read like lateral travel
- do NOT make the sequence read like turn frames
- do NOT make every frame keep both feet planted in the same neutral stance if that kills celebration
- do NOT collapse the victory into quiet idle variations
- do NOT treat "same face every frame" as "same blank expression every frame"

gameplay-scale readability:
- face, cap, syringe, cheek heart, paw pads, med-kit, socks, bows, and cloth-tail must remain readable at gameplay size
- body read must stay within about +/-5% of the canonical walk
- motion accents must not shrink the visible body

hard reject conditions:
- sequence reads like walk / idle / turn instead of celebration
- no obvious peak triumph frame
- face drift from canonical walk
- anime-soft rendering
- med-kit loss
- syringe loss
- pink paw-pad loss
- pink trim reappears on thigh-highs
- body read shrinks below walk
- one or more frames read like a different Menhera

output targets:
- `.tmp/menhera_flux_kontext_victory_v3.png`
- `.tmp/menhera_flux_kontext_victory_v3.jpeg`
- optional:
  - `.tmp/menhera_flux_kontext_victory_v3_zoom.png`
  - `.tmp/menhera_flux_kontext_victory_v3_gameplay.png`
  - `.tmp/menhera_flux_kontext_victory_v3_vs_old_victory.png`
  - `.tmp/menhera_flux_kontext_victory_v3_vs_runtime_v2.png`
  - `.tmp/menhera_flux_kontext_victory_v3_report.md`

QA priorities:
1. does it still read as the exact same Menhera as canonical walk?
2. does it now clearly read as a victory celebration?
3. is the peak frame actually joyful / triumphant?
4. is the expression progression controlled rather than random?
5. is it a true upgrade over BOTH:
   - the old pre-swap victory in face consistency
   - the currently applied runtime victory in celebration acting

stop-and-ask:
- if FLUX preserves identity but celebration is still too flat, HOLD and say full-sheet direct is not enough for acting
- if FLUX gets stronger celebration but breaks face identity, HOLD and reject
- this pass succeeds only if it improves acting without losing Menhera

최종 보고 형식:
1. reference stack을 어떻게 사용했는지
2. current applied runtime victory의 acting 문제를 해결했는지
3. canonical walk identity lock 통과 여부
4. celebration arc가 실제 승리모션으로 읽히는지 여부
5. 바로 publish candidate로 갈 수 있는지, 아니면 peak + frame expansion으로 내려가야 하는지
```
