# CLAUDE.md — 환격전

@AGENTS.md

This repository develops **환격전** in the repo-local Godot project. The English
title is undecided. Never invent one. PingFighter/Pygame is frozen parity
reference only.

`pingfighter`, `DiskHearts`, `Ringpia` / `Lingpia`, package IDs, CLI/env names,
save keys, resource paths, and export filenames are compatibility identifiers.
Do not rename them as branding cleanup. Preserve `config/name="pingfighter"`
until a tested `user://` migration exists.

## Loading and authority contract

- Root `CLAUDE.md` is a short routing/index file; do not grow detailed incident
  histories here.
- For `godot/**`, `.claude/rules/godot-runtime-traps.md` carries the 3–8 line
  actionable essence for all runtime traps.
- `docs/godot_runtime_traps.md` carries full incidents, mechanisms, rules, and
  seals under immutable `GRT-NNN` anchors.
- The imported `AGENTS.md` owns implementation, build/test, performance, and
  commit guardrails.
- Owner checklists and architecture documents win for their runtime domains.
- `docs/agent_harness_archive/CLAUDE.full.md` preserves an exact, hash-pinned
  pre-compaction payload. It is inactive provenance; current instructions live
  only in the active root, rules, skills, and owner documents.

## Fast reading map

- Work posture: `docs/agent_operating_posture.md`.
- Godot owners/porting: `docs/godot_port_checklist.md`, then
  `docs/godot_port_architecture.md`.
- Items: `docs/item_runtime_checklist.md`.
- Character skills/perks: `docs/character_skill_perk_checklist.md`.
- VFX handoff: `docs/skill_vfx_workflow.md`.
- Boss sprite runtime: `docs/sprites/boss_sprite_runtime_contract.md` and the
  focused boss document.
- Current Godot-vs-legacy boundary: `docs/current_development_boundary.md`.

## Claude / Codex delivery split

- Claude leads aesthetic direction, palette, silhouette, layer recipe, prompt
  wording, alpha/nukki review, and character-read/beauty review.
- Codex owns executable delivery: accepted asset placement, loaders/prewarm,
  shaders/particles/tweens, runtime coordinates and clip, audio/hitstop/camera,
  lifecycle cleanup, tests, warnings, and live/pixel verification.
- Art direction alone is not runtime completion.

## Asset request routing

- A request to draw/redraw/generate a bitmap routes to the matching image skill;
  do not silently replace it with procedural geometry or a placeholder.
- Boss/character sheets and nukki: `.claude/skills/sprite-generation/SKILL.md`.
- Item icons/equip visuals: `.claude/skills/item-generation/SKILL.md`.
- Fullscreen/pillar HUD chrome: `.claude/skills/ui-hud-generation/SKILL.md`.
- Runtime item integration is not owned by the item-art skill; use the runtime
  checklist.
- Preserve accepted identity, crop, scale, facing, palette, alpha, and runtime
  naming contracts. Candidate art is not promoted without explicit acceptance.

## Direct Draw Request Routing

A draw/redraw request routes to the matching image skill and a real bitmap.
Do not silently substitute procedural geometry, SVG, CSS, or a placeholder;
after acceptance, wire and verify the actual PNG-first runtime route.

## Ringpet Visual Terminology

Player-facing copy says `수호령`; keep Ringpet/Lingpet only as compatibility
identifiers. `링파츠` means body-mounted identity hardware such as chest cores,
head/shoulder plates, cuffs, tail modules, sockets, and trim—not only rings.

## Character Live2D Source Art Backgrounds

Raw cutout/rigging anchors use perfectly flat `#ff00ff` chroma, or `#00ff00`
only on palette conflict. Preserve raw and cleaned-alpha files and inspect the
alpha box, corners, and color fringe on dark and light previews.

## Character Live2D Idle / Click Dialogue Continuity

Treat click dialogue as `idle -> click/speech -> idle`; lock crop, props, and
stage fit, measure both transition seams, and verify mouth timing against the
real voice before promotion.

## Runtime Skill-Effect Sprite Sheets

Gameplay-effect bitmap work defaults to a stable looping 16-frame 4x4 sheet
through the sprite workflow unless the user approves a shorter one-shot. Keep
cell margins clear; accepted art still needs loader/prewarm/lifecycle/live QA.

## MCP and credential safety

- Never place access tokens, bearer headers, signed URLs, or API keys in tracked
  or ignored project config. Use environment-variable references or a user-local
  credential helper.
- Never print secret values during scanning; report paths and redacted findings.
- Rotation/revocation is a provider-console action. Local replacement does not
  invalidate a credential already exposed in public history.
- Keep MCP stdout reserved for JSON-RPC. Prefer stable repo launchers and absolute
  runtime paths over transient `npx` startup.

## Runtime trap registry contract

Contract changed during harness compaction: root entries below are discovery
pointers, not full stubs. The actionable 3–8 line essence moved to the
path-scoped rule file and remains mandatory for Godot work. Full evidence stays
in the ledger. IDs are append-only; do not renumber, reuse, swap, or retarget
them. Heading text must match between registry essence and ledger.

## Godot Runtime Hidden-Trap Registry

- [GRT-001](docs/godot_runtime_traps.md#grt-001) — Godot ConfigFile UTF-8 BOM Trap
- [GRT-002](docs/godot_runtime_traps.md#grt-002) — Godot High-Refresh Pacing Trap
- [GRT-003](docs/godot_runtime_traps.md#grt-003) — Godot Hot-Path Lazy Init Trap
- [GRT-004](docs/godot_runtime_traps.md#grt-004) — Godot Missing Reserved-Asset Per-Frame Re-Stat Trap
- [GRT-005](docs/godot_runtime_traps.md#grt-005) — Godot Threaded Texture Cross-Path Timeout Trap
- [GRT-006](docs/godot_runtime_traps.md#grt-006) — Godot Animated Polygon Triangulation Trap
- [GRT-007](docs/godot_runtime_traps.md#grt-007) — Godot Effect Drawer Static-Frame Trap
- [GRT-008](docs/godot_runtime_traps.md#grt-008) — Godot Negative-Z Backdrop Host vs Ancestor Opaque Fill Trap
- [GRT-009](docs/godot_runtime_traps.md#grt-009) — Godot 보스 예측 모델 트랩 ("불규칙하게 흔들면 막기 어렵다"는 거짓)
- [GRT-010](docs/godot_runtime_traps.md#grt-010) — Godot 회복 램프 플레이어 재개입 트랩 (해제는 구조적으로 한 프레임 늦다)
- [GRT-011](docs/godot_runtime_traps.md#grt-011) — Godot Per-Frame Probability Roll Trap
- [GRT-012](docs/godot_runtime_traps.md#grt-012) — Godot Companion Walk/Idle Ratio Trap (treadmill in place)
- [GRT-013](docs/godot_runtime_traps.md#grt-013) — Godot Companion Teleport/Reposition Locomotion Trap (ground pet keeps Y)
- [GRT-014](docs/godot_runtime_traps.md#grt-014) — Godot Emergency-Assist Static-Paddle Gate Trap (committed player dash reads as "can't block")
- [GRT-015](docs/godot_runtime_traps.md#grt-015) — Godot Lingpet Companion Incapacitation Body-Hit Trap (parked ≠ disabled)
- [GRT-016](docs/godot_runtime_traps.md#grt-016) — Godot 링펫 스킬 idle-업데이트 게이트 "보이는 것 ≠ 살아있는 것" 트랩 (VISIBLE vs LIVE)
- [GRT-017](docs/godot_runtime_traps.md#grt-017) — Godot Owner-Field Schema Trap (runtime stat → character-info panel)
- [GRT-018](docs/godot_runtime_traps.md#grt-018) — Godot Two-Update-Path Context-Flag Trap (effects-path flag read on the ball path)
- [GRT-019](docs/godot_runtime_traps.md#grt-019) — Godot Shared Stateful Input-Reader Edge-Eating Trap (extra get_snapshot() consumer)
- [GRT-020](docs/godot_runtime_traps.md#grt-020) — Godot Lazy Applied-Key Re-Apply Trap
- [GRT-021](docs/godot_runtime_traps.md#grt-021) — Godot Stats-Panel Row Budget Trap
- [GRT-022](docs/godot_runtime_traps.md#grt-022) — Godot 공유 레이아웃 빌더 요소-추가 트랩 (그린 자리와 클릭 자리가 갈라진다)
- [GRT-023](docs/godot_runtime_traps.md#grt-023) — Godot Boss Skill Card Rail Commando-Avoidance Trap
- [GRT-024](docs/godot_runtime_traps.md#grt-024) — Godot Lingpet Second-Active-Slot HUD Parity Trap
- [GRT-025](docs/godot_runtime_traps.md#grt-025) — Godot Boss-Paddle-Scripting Skill Trap (drag / grab / displace the boss)
- [GRT-026](docs/godot_runtime_traps.md#grt-026) — Godot Boss-Paddle-Range-Restriction Skill Trap (clamp / cage the boss)
- [GRT-027](docs/godot_runtime_traps.md#grt-027) — Godot Boss-Paddle-Resizing Skill Trap (shrink / grow the boss paddle)
- [GRT-028](docs/godot_runtime_traps.md#grt-028) — Godot Shared HUD Wrapper Prep-Before-Gate Trap (build-then-discard per frame)
- [GRT-029](docs/godot_runtime_traps.md#grt-029) — Godot 공유 파티클 배열 꼬리-윈도우 렌더 컷 × 스폰 순서 트랩
- [GRT-030](docs/godot_runtime_traps.md#grt-030) — Godot Slot-Indexed HUD State Array-Shift Trap
- [GRT-031](docs/godot_runtime_traps.md#grt-031) — Godot 반쪽-랜딩 슬라이스 트랩 (표시가 없는 브리지를 근거로 댄다)
- [GRT-032](docs/godot_runtime_traps.md#grt-032) — Godot Per-Frame Catalog Lookup Trap (miss-case full scan + deep copies)
- [GRT-033](docs/godot_runtime_traps.md#grt-033) — Godot draw_polygon Un-Normalized UV Invisible-Quad Trap
- [GRT-034](docs/godot_runtime_traps.md#grt-034) — Godot Modal-Block Gate Skips Loop-Audio Maintenance Trap
- [GRT-035](docs/godot_runtime_traps.md#grt-035) — Godot 공유 큐 목록 삽입 × 형제 씰 절대-인덱스 트랩 (배치가 첫 실패에서 끊긴다)
- [GRT-036](docs/godot_runtime_traps.md#grt-036) — Godot 벤더 WAV 컨테이너 결함 트랩 (임포트는 되는데 매 로드마다 경고 → 러너 RED)
- [GRT-037](docs/godot_runtime_traps.md#grt-037) — Godot Per-Tick Float Drain Rail-Residue Trap (is_equal_approx write-gating)
- [GRT-038](docs/godot_runtime_traps.md#grt-038) — Godot TextureRect Min-Size Clamp Renders At Native Texture Size Trap (use Sprite2D for scaled/rotated shader sprites)
- [GRT-039](docs/godot_runtime_traps.md#grt-039) — Godot 전역 물리 보간 오버레이 스폰-글라이드 트랩 (spawn-frame reposition glide)
- [GRT-040](docs/godot_runtime_traps.md#grt-040) — Godot 스모크 임의 프로퍼티 대입 조용한 레그-abort 공허 GREEN 트랩
- [GRT-041](docs/godot_runtime_traps.md#grt-041) — Godot 퍽 표시 Projection-분기 후처리 탈락 트랩 (라이브=항상 projection)
- [GRT-042](docs/godot_runtime_traps.md#grt-042) — Godot 프리웜 경량-값-위해 무거운-모듈 콜드생성 트랩 (전환 프레임 1초+ 스톨)
- [GRT-043](docs/godot_runtime_traps.md#grt-043) — Godot HUD 상시-가시성 승격 × 프리미엄 절차 드로우 트랩 (봉인 예산 락스텝)
- [GRT-044](docs/godot_runtime_traps.md#grt-044) — Godot Fullscreen Screen-Read Overlay Context-Fallback Sizing Trap
- [GRT-045](docs/godot_runtime_traps.md#grt-045) — Godot 스크린-공간 FX 호스트 플레이필드 클립 트랩 (구조 GREEN ≠ 픽셀 클립)
- [GRT-046](docs/godot_runtime_traps.md#grt-046) — Godot Fragment-Clip 캔버스-단위 vs 프레임버퍼-픽셀 트랩
- [GRT-047](docs/godot_runtime_traps.md#grt-047) — Godot VFX 리브랜드 발광 예산 트랩 (ADD × 어두운 아트 = 더할 빛이 없다)
- [GRT-048](docs/godot_runtime_traps.md#grt-048) — Godot Duck-Typed `has_method`-Gated Dynamic-Call Arity Trap (caller-path seal, not direct-runtime seal)
- [GRT-049](docs/godot_runtime_traps.md#grt-049) — Godot Ball-Path Owner-Snapshot Stat-Refund Trap (owner.set mid-collision → refunded at frame end)
- [GRT-050](docs/godot_runtime_traps.md#grt-050) — Godot 커맨드-버퍼 스킬 활성화 게이트 트랩 (막힌 게이트는 입력을 버리지 않고 미룬다)
- [GRT-051](docs/godot_runtime_traps.md#grt-051) — Typed 배열에 조건식 리터럴을 대입하는 draw-time 런타임 트랩
- [GRT-052](docs/godot_runtime_traps.md#grt-052) — Godot 패들-상대 오프셋 상수 1:1 포팅 트랩 (원본 패들은 바닥에서 24px 떠 있다)
- [GRT-053](docs/godot_runtime_traps.md#grt-053) — Godot 포팅 파리티 판정 트랩 (수식이 같아도 "그 경로에서 호출되는가"가 다르다)
- [GRT-054](docs/godot_runtime_traps.md#grt-054) — Godot 룰 상수 파생-임계값 리터럴 트랩 (승리 점수를 올리면 보상이 조용히 전멸한다)
- [GRT-055](docs/godot_runtime_traps.md#grt-055) — Godot `draw_line`에는 라인 캡이 없다 — pygame `draw.ellipse` 실루엣 포팅 트랩
- [GRT-056](docs/godot_runtime_traps.md#grt-056) — Godot 바닥밀착 패들 지면 VFX 트랩 (회전한 쿼드는 클램프를 뚫는다)
- [GRT-057](docs/godot_runtime_traps.md#grt-057) — Godot 페인티드 크롬 뒤 평면 헤일로 rect 트랩 (그림틀 투명 여백이 상자를 드러낸다)
- [GRT-058](docs/godot_runtime_traps.md#grt-058) — Godot 물리차단 모달 개폐 계약 트랩 (새 진입점은 형제 모달의 훅을 상속하지 않는다)
- [GRT-059](docs/godot_runtime_traps.md#grt-059) — Godot 스프라이트 셀 여백 × 패들 배율 트랩 (캐릭터가 벽에 못 닿는다)

## Legacy reference

Old stage order, Python coordinate rules, Pygame icon chains, and other historical
details are preserved in the archive and focused legacy documents. They never
override the current Godot boundary, owner checklists, or stable GRT rules.

Run `tools/verify_agent_harness.ps1` after changing this file, the rule file,
the ledger, AGENTS, skills, or harness workflows.
