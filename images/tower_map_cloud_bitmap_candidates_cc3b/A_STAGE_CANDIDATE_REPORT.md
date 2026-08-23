# Tower map cloud bitmap candidates — Stage A

Status: candidate-only. Nothing in this directory is registered in the Godot
asset catalog or referenced by runtime code. Runtime promotion remains gated on
explicit approval.

## Dimension rationale

The production scroll contract is a `692×320` world tile at x4 texture density
(`2768×1280`). Map rows are spaced every 160 world pixels. The cloud candidates
therefore use one floor row as the vertical design unit and preserve exactly
four texture pixels per world pixel:

| Asset | World size | Candidate texture | Rationale |
| --- | ---: | ---: | --- |
| `cloud_swirl_large` | `260×160` | `1040×640` | One full row high; a broad focal mass covering about 38% of the band width. |
| `cloud_swirl_medium` | `196×112` | `784×448` | Complementary mid-depth mass, below a row high. |
| `cloud_wisp` | `152×64` | `608×256` | Thin foreground strand that does not become another opaque band. |
| `cloud_haze_band` | `692×144` | `2768×576` | Exact full map width for horizontal wrap; below a row high so layered copies can overlap. |

Each motif is a separate PNG. There is no sheet grid to infer or risk slicing
incorrectly.

## Soft-alpha method

The generated sources already contain continuous alpha, but their low-alpha
edge RGB contains visible yellow-green and magenta contamination. The candidates
do not chroma-key those pixels. Instead, the offline builder:

1. preserves the generated alpha silhouette and blurs it by 1.65 x4 pixels for
   fibrous edge falloff;
2. derives local wash strength from source luminance;
3. reconstructs every visible RGB pixel only on the approved warm
   `#30271f`–`#f1dfb8` ink/hanji axis;
4. maps pale wash to low opacity and dark ink to higher opacity, with per-asset
   maxima from 0.46 through 0.68;
5. keeps zero-alpha RGB on the same ink gamut, preventing sampled fringe during
   filtering.

This retains the image-generated ruyi-head brushwork while removing chromatic
fringe. In the locked-floor composite, terrain luminance correlation is
`0.835243` across all covered pixels and `0.944132` beneath thin cloud. Every
visible candidate pixel has intermediate alpha; no candidate contains an opaque
binary-alpha pixel.

`cloud_haze_band` is made periodic after matting. A half-width roll places the
runtime repeat edge on an originally continuous interior span; the displaced
source edge is then replaced with a broad, center-weighted interior crossfade.
The final first/last RGBA columns are equal. The x4 edge delta is mean `0.0`, max
`0`, while the first interior step remains nonzero (`3.25217`) so the proof is
not a flat transparent edge.

Full numerical output is in `review/A_STAGE_QA.json`.

## Review deliverables

- `review/01_contact_sheet.png`
- `review/02_locked_floor_composite.png`
- `review/03_reveal_midpoint_composite.png`
- `review/04_fit_all_composite.png`
- `review/05_surround_edge_composite.png`
- `review/06_haze_band_3x_seam_proof_x4.png`
- `review/07_haze_band_3x_seam_review.png`

The four composites use the tracked x4 production band
`immortal_realm_02_cloud_cranes_rev2_x4.png` or the tracked six-band family.
The contact sheet's labels and checker are review furniture, not part of any
candidate asset.

## Image generation mode and prompts

Mode: built-in `image_gen`, one call per distinct asset. The final prompts used
for the four sources are recorded verbatim in `IMAGEGEN_PROMPTS.md`.
