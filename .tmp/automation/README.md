# Claude Automation

This folder stores local Claude handoff automation artifacts.

Typical usage:

```powershell
.\tools\run_claude_handoff.ps1 .tmp\claude_teddy_bear_walk_flux_peak_then_frame_expansion_handoff_v1.md
```

Each run creates:

- `.tmp/automation/<timestamp>_<label>/prompt.md`
- `.tmp/automation/<timestamp>_<label>/response.txt`
- `.tmp/automation/<timestamp>_<label>/stderr.txt`
- `.tmp/automation/<timestamp>_<label>/job.json`

The latest job path is also written to:

- `.tmp/automation/latest/last_job.txt`

Notes:

- This runner is for local automation only.
- Claude still follows the handoff prompt you give it.
- Codex remains the QA / runtime-application side of the workflow.
