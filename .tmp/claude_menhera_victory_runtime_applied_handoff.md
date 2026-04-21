# Claude Handoff Prompt: Menhera Victory Runtime Applied

아래 프롬프트를 그대로 Claude에 전달하면 됩니다.

```text
이번 브랜치 상태 기록:

Menhera victory P2 publish pack has been applied to runtime.

적용 완료 내용:
- live asset swap completed
- `d:\main\bosspong\items\menhera_boss_victory.png`
- `d:\main\bosspong\items\menhera_boss_victory.jpeg`
- both now point to the approved P2 publish pack derived from:
  - `.tmp/menhera_flux_kontext_victory_publish_v1_nukki.png`
  - `.tmp/menhera_flux_kontext_victory_publish_v1.jpeg`

backup:
- previous live victory assets were backed up at:
  - `d:\main\bosspong\.tmp\menhera_victory_runtime_backup_20260418\menhera_boss_victory_old.png`
  - `d:\main\bosspong\.tmp\menhera_victory_runtime_backup_20260418\menhera_boss_victory_old.jpeg`

Codex local QA status:
- syntax compile check passed
- MenheraBossSprite headless load passed
- victory frames loaded: 8
- publish pack size confirmed: 2752x1536
- in-class runtime victory playback reached final frame cleanly
- no loader edit was required because victory already uses the standard 4x2 walk-style grid

policy status:
- P2 accepted
- victory V1 publish pack is approved as a runtime-only non-anchor auxiliary sheet
- canonical walk remains the sole identity anchor
- do NOT use the applied victory sheet as a future identity anchor for regeneration work

accepted divergence:
- center white panel reads as 3 bows instead of 4
- accepted as cosmetic runtime divergence only
- not a new canonical rule

important guardrail:
- any future attack / dash / defeat / victory regeneration must still anchor on canonical walk plus approved prop references
- do not anchor future work on the applied victory runtime sheet alone

branch status:
- victory asset-side branch is closed
- no further FLUX / AutoSprite / Gemini passes are requested for this victory branch unless a new regression is found in live gameplay
```
