# Claude Handoff Prompt: Menhera Victory FLUX V2 4-Bow Touch-Up

아래 프롬프트를 그대로 Claude에게 전달하면 됩니다.

```text
이번 작업은 PingFighter Stage 3 Menheragirl victory sheet의 FLUX Kontext V2 narrow touch-up 패스다.

중요:
- `d:\main\bosspong\CLAUDE.md`를 따르고
- 반드시 `d:\main\bosspong\.claude\skills\sprite-generation\SKILL.md` 기준으로 진행해줘
- 이번 패스는 victory sheet의 4-bow count correction only
- walk / attack / dash / turn / defeat는 건드리지 않는다
- runtime integration은 하지 않는다
- canonical overwrite는 하지 않고 `.tmp` 후보 + QA까지만 한다

현재 상태:
- `menhera_flux_kontext_victory_v1.png`는 current live victory보다 훨씬 좋다
- 8프레임 전체에서 canonical walk와 같은 Menhera 얼굴 / identity lock은 PASS
- plain white thigh-highs, cap, syringe, eyes, cheek heart, paw pads, med-kit, cloth-tail 모두 PASS
- hard-reject급 문제는 사실상 하나:
  - white center panel의 black bow count가 4가 아니라 3으로 읽힌다

핵심 목표:
- victory V1의 장점은 그대로 유지
- ONLY fix the center-panel bow count so every frame reads as exactly FOUR black bows
- 다른 요소는 건드리지 않는다

reference stack:
1. primary base
- `d:\main\bosspong\.tmp\menhera_flux_kontext_victory_v1.png`

2. identity master
- `d:\main\bosspong\items\menhera_boss_sheet.png`

3. current live victory (motion intent only)
- `d:\main\bosspong\items\menhera_boss_victory.png`

4. dense identity board
- `d:\main\bosspong\.tmp\menhera_autosprite_reference_board_v2.png`

모델 / 방식:
- FLUX Kontext
- 가능하면 `flux_kontext_max`
- narrow image-to-image edit
- base image는 반드시 `menhera_flux_kontext_victory_v1.png`

수정할 것 only:
- add the missing fourth black bow on the white center front panel
- the four bows must read as a clean vertical stack in every frame

절대 바꾸면 안 되는 것:
- face / eye / lash treatment
- cream/blonde inner bangs
- pink outer hair silhouette
- gingham cap
- syringe
- cheek heart mark
- gray cat-paw gloves + pink pads
- med-kit pouch
- cloth-tail motif
- plain white thigh-highs
- black X ankle accessories
- pose / celebration energy
- body read
- pixel class

특히 중요한 보존 규칙:
- do NOT let FLUX "improve" or reinterpret the face
- do NOT turn the 8-frame sheet into a softer anime render
- do NOT add pink trim back onto the white thigh-highs
- do NOT move or simplify the med-kit
- do NOT change the celebration pose sequencing

identity / style lock:
- exact same Menhera as canonical walk
- 16-bit retro pixel art
- chibi proportions
- thick black pixel outlines
- flat limited-saturation pastel palette
- clean hard-edged pixels
- no anime-soft rendering
- no painterly shading
- same clarity class as victory V1 and canonical walk

hard reject:
- bow count still reads as 3
- face drift
- eye / lash drift
- cream bangs drift
- syringe loss
- paw pad loss
- med-kit drift
- pink trim reappears on thigh-highs
- overall softness / anime drift

output:
- `.tmp/menhera_flux_kontext_victory_v2.png`
- `.tmp/menhera_flux_kontext_victory_v2.jpeg`
- optional:
  - `.tmp/menhera_flux_kontext_victory_v2_zoom.png`
  - `.tmp/menhera_flux_kontext_victory_v1_vs_v2.png`
  - `.tmp/menhera_flux_kontext_victory_v2_report.md`

QA:
- compare directly against `items/menhera_boss_sheet.png`
- compare against `menhera_flux_kontext_victory_v1.png`
- verify that V2 is a true upgrade, not a lateral move
- if FLUX refuses the fourth bow but keeps everything else perfect, say so clearly
- if V2 becomes a lateral move, explicitly recommend P2:
  - accept 3-bow as cosmetic runtime drift because victory is non-anchor

최종 보고 형식:
1. fourth bow correction 성공 여부
2. collateral drift 발생 여부
3. V2가 V1보다 명백한 upgrade인지 여부
4. publishing candidate로 바로 올릴 수 있는지 여부
5. 실패 시 P2 acceptance로 내려가도 되는지 여부
```
