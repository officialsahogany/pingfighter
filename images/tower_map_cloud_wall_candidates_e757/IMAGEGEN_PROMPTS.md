# Imagegen prompts — Tower map cloud wall Stage A

Mode: built-in `image_gen`, one call per distinct asset. The user-provided
reference was supplied as a style/palette/cloud-shape reference, not an edit
target. The fourth call was a targeted background-extraction edit after the
first dissolve source returned false transparency.

## Interior A — dense connected wall

```text
Use case: stylized-concept
Asset type: 2D game texture source for a continuous locked-region cloud wall on a vertical Korean fantasy tower map
Primary request: generate a dense, full-frame wall of connected Korean ink-wash storm clouds inspired by the reference image; this is a new texture, not an edit of the screenshot
Input image: Image 1 is style, palette, and cloud-shape reference only; do not reproduce its map nodes, route lines, scoreboard, labels, terrain, or UI
Scene/backdrop: the entire rectangular frame is filled edge-to-edge with cloud matter; no scenery and no separate background
Subject: one continuous massive cloud body made from interlocking dark meok cloud vortices and lighter warm mist, with organic ruyi-head spiral curls embedded throughout
Style/medium: traditional Korean ink-and-wash painting on aged hanji, soft fibrous brush diffusion, atmospheric and hand-painted, closely matching the reference's warm parchment family
Composition/framing: wide 2:1 texture; distributed detail with no single focal center; left and right edges should visually continue when tiled; top and bottom should also avoid hard horizontal bands so vertical repetition can overlap invisibly
Lighting/mood: ominous concealed territory, dense enough to hide map nodes and routes
Color palette: deep warm ink #30271f, smoky warm gray-brown, muted paper ochre #d7bd88; restrained pale mist only; absolutely no pure white or cream stripe
Materials/textures: layered opaque ink cores plus translucent-looking internal wash, but the final rectangular texture must have a fully opaque core everywhere with no transparent holes
Constraints: no text, no symbols, no watermark, no map, no nodes, no routes, no icons, no characters, no buildings, no borders, no straight horizontal division, no repeated stripes, no isolated cloud stickers, no blue-gray, cyan, green, magenta, or saturated colors; seamless tile source; high-resolution RGBA or RGB bitmap
```

## Interior B — macro-flow comparison

```text
Use case: stylized-concept
Asset type: alternate 2D game texture source for a continuous locked-region cloud wall on a vertical Korean fantasy tower map
Primary request: generate a second, clearly different dense full-frame wall of connected Korean ink-wash storm clouds inspired by the reference; use fewer, larger cloud masses and long interwoven fog currents so the wall reads as one enormous atmospheric body instead of many repeated small curls
Input image: Image 1 is style, palette, and cloud-shape reference only; do not reproduce its map nodes, route lines, scoreboard, labels, terrain, or UI
Scene/backdrop: edge-to-edge cloud matter fills the entire rectangle; no scenery and no separate background
Subject: broad dark meok vortices, large ruyi-head spiral lobes, deep smoky pockets, and pale warm mist braided organically between them
Style/medium: traditional Korean ink-and-wash on aged hanji, soft fibrous brush diffusion, restrained antique map painting, close to the reference
Composition/framing: wide 2:1 texture; asymmetrical macro flow from lower-left toward upper-right, but balanced enough to tile; left and right edges visually continue; no horizontal layers or stripes; top and bottom have overlapping cloud forms suitable for vertical repetition
Lighting/mood: ominous, deep, immersive, dense enough that nodes and route lines beneath cannot be read
Color palette: deep warm ink #30271f, smoky gray-brown, muted paper ochre #d7bd88; limited warm pale mist; no pure white or cream band
Materials/textures: wet sumi pooling, dry-brush fibers, diffuse vapor; final rectangular texture has a fully opaque core everywhere with no transparent holes
Constraints: no text, no symbols, no watermark, no map, no nodes, no routes, no icons, no figures, no architecture, no borders, no straight horizontal division, no repeated stripe, no blue-gray, cyan, green, magenta, or saturated color; seamless tile source; high-resolution bitmap
```

## Lower dissolve — initial generation

```text
Use case: stylized-concept
Asset type: transparent 2D game transition texture for the lower edge of a continuous locked-region cloud wall
Primary request: generate one wide seamless-x dissolve strip in the reference's Korean ink-wash storm-cloud style; the upper edge is a connected dense opaque cloud wall and it organically thins downward into curling wisps and complete transparency
Input image: Image 1 is style, palette, and cloud-shape reference only; do not reproduce its map, terrain, route lines, nodes, scoreboard, labels, or UI
Scene/backdrop: genuinely transparent background; no parchment rectangle baked behind the cloud
Subject: dark warm meok cloud mass across the full top width, irregular scalloped ruyi-head and spiral silhouettes descending at varied depths, smoky filaments and dry-brush vapor dissolving toward the bottom
Style/medium: traditional Korean ink-and-wash, fibrous sumi diffusion, aged hanji color family in the cloud pigment only
Composition/framing: very wide 3:1 strip; top 30 percent continuously cloud-filled and opaque enough to join a wall; transition is irregular and organic with no straight line; bottom 15 percent completely transparent; left and right edges match in cloud height, density, direction, and alpha for seamless horizontal tiling; no centered focal motif
Color palette: deep warm ink #30271f, smoky warm gray-brown, muted ochre #d7bd88; restrained pale warm mist; absolutely no pure white or cream horizontal ribbon
Opacity/material: real RGBA transparency; alpha decreases generally from top to bottom, with soft organic local variation; no opaque pixels touching the bottom edge
Constraints: transparent background, no text, no symbols, no watermark, no map, no routes, no nodes, no icons, no people, no buildings, no border, no hard horizontal cutoff, no straight edge, no repeated stripe, no blue-gray, cyan, green, magenta, or saturated colors; seamless-x source; high-resolution bitmap
```

## Lower dissolve — targeted background-extraction edit

```text
Use case: background-extraction
Asset type: transparent 2D game lower-edge dissolve strip
Primary request: remove only the checkerboard and pale rectangular background from this image and replace it with genuine transparent alpha; preserve the upper storm-cloud artwork, warm ink palette, organic ruyi-head silhouettes, composition, and dimensions
Input image: Image 1 is the edit target
Transparency contract: the top cloud mass remains opaque/near-opaque; alpha falls organically through the descending wisps; the entire bottom 15 percent must be alpha 0; no visible checkerboard pixels or white/cream background pixels; cloud edge must retain soft intermediate alpha
Seam contract: keep left and right edge cloud height and density compatible for seamless horizontal tiling
Constraints: change only background extraction and alpha; do not add text, symbols, scenery, map nodes, routes, borders, or new objects; no checker pattern; no white rectangle; no watermark
```
