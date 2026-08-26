# Yangui Hoechun wave visual QA

The Yangui Hoechun wave redesign has a manual, hardware-local Vulkan acceptance
lane. Run it from `godot/`:

```powershell
./tools/run_yangui_hoechun_visual_qa.ps1
```

The wrapper opens a 760x750 Vulkan/mobile render, saves six captures under
`.godot/codex_artifacts/yangui_hoechun_wave_redesign/`, and fails unless all of
these gates pass:

- center, left-corner, and right-corner cast/wall captures;
- effect-isolated gold, strongly cyan-dominant, filled bright-core, and wall
  pixels (each capture is compared with the same scene rendered without the
  effect, so the paddle and floor cannot satisfy the effect thresholds);
- the runtime wall timing seal; and
- a reproducible one-wave/three-wave CPU draw-submission benchmark whose
  three-wave median must remain at or below 1750 microseconds on the acceptance
  machine.

This lane is intentionally not listed in headless focused CI or pre-push. It
requires a real Vulkan window, produces pixel captures, and records
hardware-local timing. The headless contract smoke remains in CI/pre-push and
owns deterministic gameplay, lifecycle, production wiring, and list-lockstep
coverage; this wrapper is the required manual visual/performance complement.
