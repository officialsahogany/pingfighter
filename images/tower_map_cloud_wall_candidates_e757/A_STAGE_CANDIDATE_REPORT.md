# J3 Tower map cloud wall — Stage A report

Status: **candidate-only / approval waiting**. Nothing under this candidate
directory is registered in the Godot asset catalog, imported as a production
asset, or referenced by runtime code. Stage B remains blocked on explicit user
approval.

## Isolated scope

- Base: `e75728ba8fd05e7d547a60dce9ac890df70f70df`
- Worktree: `D:\codex_tmp\bosspong_cloudwall_e757`
- Branch: `codex/tower-map-cloud-wall-20260824`
- Reference SHA-256: `51D55AAB006ECA559EFA24EE6FFE3C266D861FEFD5F6C016D5E782FA58265FBA`
- Generation mode: built-in `image_gen`; one call per source/targeted edit

## Recommended approval set

1. `candidates/cloud_wall_interior_dense_a_imagegen_candidate_x4.png`
   - world `692×320`; texture `2768×1280`; seamless X/Y
   - fully opaque core (`alpha_min=max=255`), near-white pixels `0`
2. `candidates/cloud_wall_dissolve_imagegen_candidate_x4.png`
   - world `692×224`; texture `2768×896`; seamless X
   - top 20% mean alpha `253.999847`; bottom 15% max alpha `0`
   - row-mean alpha increase count `0`
   - Interior A join max RGBA delta `0`

The recommended pair reads as one connected meok cloud wall, removes the
current cream/white floor-band impression, and dissolves organically into the
public map. It is dense enough to serve as a future MIX concealment core while
preserving the approved warm ink/hanji palette.

## Review sheets

- `review/01_reference_and_candidates.png` — user reference beside A/B and the dissolve strip
- `review/02_interior_a_seam_3x2_world.png` — A, three horizontal by two vertical repeats
- `review/03_interior_b_seam_3x2_world.png` — B comparison seam proof
- `review/04_dissolve_seam_3x_world.png` — dissolve, three horizontal repeats over checker
- `review/05_reference_mockup_candidate_a.png` — recommended A wall + dissolve over the reference map
- `review/06_reference_mockup_candidate_b.png` — rejected B comparison
- `review/A_STAGE_QA.json` — dimensions, hashes, alpha, palette, and seam measurements

## Prompt record

Exact generation and edit prompts are in `IMAGEGEN_PROMPTS.md`.

## Rejected candidates / sources

- `candidates/cloud_wall_interior_macro_b_imagegen_candidate_x4.png`
  - Broad pale currents can read as another light band, and the shared
    A-matched dissolve exposes a join mismatch.
- `source_raw/cloud_wall_dissolve_imagegen_raw_v1_false_alpha.png`
- `source_raw/cloud_wall_dissolve_imagegen_raw_v2_false_alpha.png`
  - Both image-generation outputs visually drew a checkerboard but contained
    no actual transparency (`alpha_min=max=255`). They are retained only as
    provenance; the accepted candidate rebuilds the alpha offline and inherits
    its RGB join from Interior A.

## Gate state

- Runtime/catalog/import changes: `0`
- Commit: none
- Push/integration/main-tree edit: none
- Next action: wait for explicit approval of the recommended A+dissolve set
