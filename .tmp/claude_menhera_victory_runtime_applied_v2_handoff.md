# Claude Handoff Prompt: Menhera Victory Runtime Applied V2

아래 프롬프트를 그대로 Claude에 전달하면 됩니다.

```text
이번 브랜치 상태 기록:

Menhera victory P3A publish pack has been applied to runtime.

적용 완료 내용:
- live asset swap completed
- `d:\main\bosspong\items\menhera_boss_victory.png`
- `d:\main\bosspong\items\menhera_boss_victory.jpeg`
- both now point to the approved P3A publish pack derived from:
  - `.tmp/menhera_flux_kontext_victory_publish_v2_nukki.png`
  - `.tmp/menhera_flux_kontext_victory_publish_v2.jpeg`

backup:
- previous live P2 victory assets were backed up at:
  - `d:\main\bosspong\.tmp\menhera_victory_runtime_backup_20260418_p2\menhera_boss_victory_p2.png`
  - `d:\main\bosspong\.tmp\menhera_victory_runtime_backup_20260418_p2\menhera_boss_victory_p2.jpeg`

Codex local QA status:
- syntax compile check passed
- MenheraBossSprite headless load passed
- victory frames loaded: 8
- publish pack size confirmed: 2752x1536
- runtime victory playback reached final frame cleanly
- no loader edit was required because victory already uses the standard 4x2 walk-style grid

policy status:
- P3A accepted
- victory frame-expansion publish pack is approved as a runtime-only non-anchor auxiliary sheet
- canonical walk remains the sole identity anchor
- do NOT use the applied victory sheet as a future identity anchor for regeneration work

accepted notes:
- f1/f2/f8 remain slightly more celebratory than the older calmer P2 entry/close
- accepted as non-blocking taste difference

important guardrail:
- any future attack / dash / defeat / victory regeneration must still anchor on canonical walk plus approved prop references
- do not anchor future work on the applied victory runtime sheet alone

branch status:
- victory asset-side branch is closed
- no further FLUX / AutoSprite / Gemini passes are requested for this victory branch unless a new regression is found in live gameplay
```
