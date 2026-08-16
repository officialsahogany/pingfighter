# 환격전 Agent Harness Maintenance

This document owns the repository procedure for changing the active AI-agent
harness. The English product title is undecided. Compatibility identifiers are
not rebrand targets.

## Routing contract

- `AGENTS.md` is the shared Codex contract and must remain below the configured
  32 KiB project-document budget. It contains routing and non-negotiable safety,
  not accumulated implementation history.
- `CLAUDE.md` imports `@AGENTS.md`, adds Claude-specific routing, and keeps the
  one-line GRT discovery registry. Target fewer than 200 lines.
- Detailed standing rules live in focused owner docs, `.claude/rules/`, and
  skills. Incident evidence and seals for cross-cutting Godot traps live in
  `docs/godot_runtime_traps.md`.
- A generic unreferenced instruction folder is not an owner. Every new detail
  must have an active loader or an explicit route from an active surface.

## Backfill and graduation

Backfill a lesson when it is non-obvious, likely to recur, crosses owners, or
can silently pass ordinary tests. Do not paste a full postmortem into a root
instruction file.

1. Put owner-local mechanics and acceptance checks in the focused owner doc.
2. If the lesson is a cross-cutting runtime trap, strengthen an existing GRT
   or append the next immutable ID/title. Update the manifest, full ledger,
   3-8 line path-rule essence, and one-line CLAUDE registry together.
3. Name the production-path smoke or invariant that seals the lesson. Include a
   reverse leg that fails when the guard is removed.
4. Add only the minimum discovery/routing sentence to a root file when agents
   must know the rule before they can identify the owner.
5. Extend `tools/verify_agent_harness.ps1` when structural drift could otherwise
   remain GREEN.

## Compaction and archive recovery

Before deleting or moving root detail:

1. Inventory inbound references, including line numbers, quoted headings,
   skills, prompts, checklists, and non-Claude agent surfaces.
2. Create stable owner anchors before shortening the source. Never remove the
   only discovery phrase first.
3. Preserve an exact inactive snapshot and pin the payload byte count and hash.
   Historical relative links may remain root-relative when byte identity is the
   contract; state that limitation in the archive preface.
4. Move durable detail to active owners, restore any required compact aliases,
   then update every caller to the new owner.
5. Run the verifier, exercise an intentional RED counterexample, restore it,
   and re-run GREEN. Re-measure AGENTS bytes and CLAUDE lines afterward.

Archive files are provenance only. They must never be imported or treated as
current instructions.

## CI and mirror boundaries

- A workflow is not an active remote gate until its file and inputs are tracked
  on the branch where GitHub can load it. Path filters must include every file
  whose mutation can invalidate the verifier.
- CI and pre-push checks that claim lockstep must call the same regression
  policies; a green focused lane does not prove the nightly suite completed.
- Stage tracked callers and every newly referenced untracked script, policy,
  workflow, manifest, rule, and fixture atomically. A local GREEN with an
  omitted untracked dependency is not a deliverable commit.
- The current smoke runner still aborts on the first genuine failing test. Until
  a separate continue-and-aggregate slice is implemented and sealed, nightly
  RED proves only the tests reached before that first failure; it does not prove
  full-suite coverage.
- A credential gate must scan tracked files plus the exact ignored project MCP
  configs, match Context7/AutoSprite/provider-key and signed-URL forms, and emit
  only path plus rule ID. Enable it only after provider revocation and local
  plaintext removal; a tracked-only GREEN does not close the current exposure.
- `.claude/skills/` is canonical. `.agents/skills/` remains an ignored local
  loader mirror until its tracked-generation policy is explicitly settled; a
  CI check must not silently skip an absent mirror.

## Interactive-play validation contract

- Routine Godot validation continues while the same project is running in a
  non-editor game process. A repository wrapper must opt in explicitly with
  `-AllowDuringPlay`; the shared guard remains fail-closed for undeclared tools.
- Declaring wrappers inherit a verified BelowNormal caller priority into their
  Godot child and restore the original caller priority in `finally`, including
  error exits. Never use a process-wide environment variable as a global bypass.
- Concurrent runs require PID/timestamp-unique engine log paths and must never
  remove or overwrite the live game's logs. Import-materializing headless runs
  remain forbidden while the editor is open.
- Keep a pure guard regression with both the undeclared RED leg and declared
  GREEN/priority-restore leg. The harness verifier owns the wrapper declarations
  and CI path-filter coverage.
