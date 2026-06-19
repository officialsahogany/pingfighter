# Plaza 6-Building Interior Recipes (imagegen room + objects)

Companion to `docs/plaza_port_plan.md` §0.11. Replicates the gated SHOP interior
pattern (§0.10) to the remaining 6 plaza buildings. **Generation = Codex
imagegen; art direction + gate = Claude.** Verbatim copy-paste room prompts +
per-action object recipes below. All grounded in real repo data (NPC names,
action counts) by a per-building design pass (2026-06-17).

## Shared contract (from §0.10.2/§0.10.4 — applies to every building)
- Room = **opaque base PNG** (no transparency / no chroma key), near-square
  authored 1:1 → filled to 760×750 (~1.3% squish ok). Runtime composites NPC +
  objects + HUD on top.
- **Left third = NPC portrait zone** (`NPC_RECT 26,118,236,500`): bake NO
  character; only the keeper's station ambiance. NPC sprite (already exists per
  building) composited at runtime.
- **Center-lower counter = exactly N empty round pedestals** (N = action count).
  Objects composited on the pedestals at runtime → pedestals EMPTY in backdrop.
- Keep top-left (title), top-right (gold), bottom-left (exit) corners
  low-clutter for HUD overdraw.
- **VR substrate consistency**: every room keeps the Lingpia cyberpunk
  data-glyph / circuit / arcane-circle glow; each building has its OWN distinct
  identity/palette accent.
- Objects = one **512×512 transparent cutout** per action, generous margin
  (glow not touching edges), palette-matched, symbolizing the action.
- Loader = `load_imported_texture` (NOT raw), `.import`+`.ctex` committed.
  Object-glow shader (if new) → `battle_pso_prewarmer` register (§0.10.6).
- Resolution: 1K candidate → final 2K or Real-ESRGAN 2× upscale.
- Asset paths: `godot/assets/ui/plaza/interior/plaza_stage1_interior_<bld>_room_imagegen_v1.png`
  + `..._<bld>_object_<kind>_imagegen_v1.png`.

## Per-building summary

| Building | NPC | Actions (order) | Pedestals | Object kinds (idx order) |
|---|---|---|---|---|
| bank | 은행원 도윤 | 예금 100G / 출금 100G / 이자 정산 | 3 | deposit_vault / withdraw_coins / interest_growth |
| gacha | 가챠 오퍼레이터 루미 | 액티브 캡슐 뽑기 150G | 1 | capsule |
| blacksmith | 대장장이 강철 | 마지막 아이템 강화 | 1 | enhance |
| academy | 아카데미 교관 서율 | 스킬 수업 200G / 스킬 교환 | 2 | lesson_scroll / exchange_prism |
| lingpet_store | 링펫 사육사 링링 | 공명 알 뽑기 250G / 링코어 강화(동적) | 2 | resonance_egg / ring_core |
| tavern | 선술집 주인 하랑 | 의뢰 받기 / 의뢰 보고 | 2 | quest_scroll / reward_stamp |

## ⚠️ Critical integration findings (Codex must heed)
1. **Per-building per-index object kind mapping required.** Current
   `_get_object_kind` (plaza_interior_view.gd:615-618) maps lingpet_store BOTH
   objects to `capsule` and tavern fallback to `crystal` → identical/wrong
   objects. Add per-(building,index) kind→texture mapping so each pedestal shows
   its distinct object (esp. lingpet_store idx0=resonance_egg / idx1=ring_core).
2. **tavern static-vs-runtime count mismatch.** `BUILDING_MENU_SPECS["tavern"]`
   (plaza_scene.gd:111-115) statically lists 1 label, but runtime overrides to 2
   via `PlazaTavernTransactions.get_menu_action_labels()` (plaza_scene.gd:1826-1827)
   = ["의뢰 받기","의뢰 보고"]. **Real count = 2 → bake 2 pedestals.** Trust the
   transactions file, not the static spec.
3. **bank ledger HUD line** draws bottom-center text (plaza_scene.gd:1308
   "보유 %dG | 예금 %dG | 열쇠 %d") — keep the bank room's lower-center region
   low-contrast behind it.
4. **lingpet_store ring_core label is dynamic** (`_build_ring_core_action_label`
   transactions.gd:252-265: tier name + cost, or capped/loading fallback) — still
   one pedestal slot.
5. **Pedestal alignment** (per shop §0.10.4): measure baked pedestal centers in
   the final PNG, align runtime object rects, disable/soften procedural pedestal
   draw (avoid double pedestals). count==1 rect Rect2(438,392,126,132);
   count==2/3 rects per plaza_interior_view.gd:584-588 — Codex measures + aligns.

---

## bank — 은행원 도윤 (3 actions)
**Identity:** Secure holographic data-vault — clean, orderly, bright gold+cyan
bank hall, mirror-bright vault door, calm ledgers; the cleanest/safest room
(contrast the moody purple junk-shop).

**Room prompt:**
> Fullscreen BACKGROUND illustration for a cyberpunk VR bank-vault interior in a video game. Clean, orderly, trustworthy, brightly lit yet still cyberpunk — highly detailed digital painting, eye-level three-quarter interior view. This is a BACKDROP layer — leave specific zones open for game elements drawn on top later. LEFT THIRD: a bank teller's station — a polished brass-and-frosted-glass teller window corner, an empty leather-cushioned stool, a neat stack of glowing cyan ledger slates and a small holographic balance terminal behind it; this left area MUST be free of any person/character (a portrait is placed here separately), kept calm, readable, and uncluttered. CENTER and LOWER-CENTER: a long polished brass-and-marble bank counter with a glass top, minimal and tidy (a few stacked gold coin columns, a sealed deposit slot, a soft cyan ledger glow), with THREE empty round brass-rimmed display pedestals in a row across the open center — each pedestal completely EMPTY, nothing displayed. BACKGROUND WALL: a massive circular mirror-steel vault door with concentric brass locking rings and faint glowing cyan circuit seams, flanked by orderly rows of small numbered safe-deposit lockers and a calm holographic interest-rate chart with no readable numbers. FLOOR/counter: faint glowing cyan-and-gold data-glyph / circuit / arcane-circle pattern (virtual-reality substrate), holographic floor seams. PALETTE/LIGHTING: clean deep navy-and-charcoal base, bright and orderly (NOT moody), warm polished gold + cool cyan accents, soft warm rim light on brass edges, gentle volumetric haze, a feeling of safety and order. STRICT EXCLUSIONS: no people/characters/banker/teller; the three pedestals EMPTY (no coins, crystals, glowing products, merchandise stacked on the pedestals); no UI, no readable text labels, no numbers, no price tags, no health bars, no cursor, no watermark, no logo, no border frame. Single full-bleed opaque scene filling the entire near-square frame.

**Objects (512² transparent, idx order):**
- `deposit_vault` (예금 100G): floating brass-and-cyan secure deposit cube/safe, lid open, glowing gold coins/data-motes pouring DOWNWARD INTO the slot (deposit), cyan circuit seams + tiny lock glyph, warm gold+cyan halo, generous margin. Gold+cyan+brass on transparent.
- `withdraw_coins` (출금 100G): floating open brass coin-purse/vault hatch, gold coins/motes rising/spilling OUTWARD+UPWARD (mirror of deposit), cyan arrow/release glyph, bright gold glow + cyan rim, margin clear. Gold+cyan+brass on transparent.
- `interest_growth` (이자 정산): floating holographic cyan growth emblem — rising bar-chart/upward arrow of cyan data-bars ringed by orbiting gold coins (interest accruing), growth feel via upward motion/sparkle NOT readable numbers, cyan core + gold accents, margin clear.

## gacha — 가챠 오퍼레이터 루미 (1 action)
**Identity:** Playful neon-arcade capsule parlor — glossy magenta + electric cyan
candy palette, gachapon machines + translucent capsule-vending tube, VR
data-glyph glowing under glass like an arcade floor.

**Room prompt:**
> Fullscreen BACKGROUND illustration for a cyberpunk VR gachapon capsule-arcade interior in a video game. Bright, playful, glossy, highly detailed digital painting in atmospheric anime game-background style, eye-level three-quarter interior view. This is a BACKDROP layer — leave specific zones open for game elements drawn on top later. LEFT THIRD: a capsule operator's station — a glossy magenta-and-chrome dispensing console corner with a big rounded crank dial and a curved acrylic capsule-collection chute, an empty rounded stool, and a tall translucent vertical tube packed with colorful round capsules rising behind it; this left area MUST be completely free of any person/character (a portrait is placed here separately), readable and not over-busy. CENTER and LOWER-CENTER: a single sleek rounded vending counter with a wide open top surface, holding EXACTLY ONE empty round glossy display pedestal (a small chrome-rimmed disc dais) centered in the open middle of the counter — the pedestal completely EMPTY, nothing displayed on it. UPPER WALLS: bustling arcade clutter — banks of rounded gachapon capsule machines with transparent globes, glowing magenta/cyan tube lights, a holographic prize-wheel sign upper-right, small hovering capsule props, ticket scatter, neon star and bubble motifs, hanging festoon lights. FLOOR/counter glass: faint glowing magenta + cyan data-glyph / circuit / arcane-circle pattern (virtual-reality substrate) lit from beneath like an arcade floor, with subtle holographic seams. PALETTE/LIGHTING: candy-bright but with depth — vivid magenta and electric cyan neon dominant, warm white sparkle highlights and pink rim light on capsule glass, soft volumetric haze, gentle dark pockets in the corners so the scene reads with contrast. STRICT EXCLUSIONS: no people, no characters, no operator, no mascot creature; the single pedestal EMPTY (no capsules, no glowing products, no merchandise, no prize on it); no UI, no readable text labels, no numbers, no price tags, no health bars, no cursor, no watermark, no logo, no border frame. Single full-bleed opaque scene filling the entire near-square frame.

**Object (512²):**
- `capsule` (액티브 캡슐 뽑기 150G): glowing gachapon prize capsule — transparent rounded two-half globe, chrome equator seam, upper dome clear / lower dome candy-magenta, inside a packed cluster of bright miniature active-item icons (coin, star token, power orb) pressing the glass, cyan↔magenta gradient glow + glass glints + orbiting data-glyph ring. Centered, margin clear. (Distinct from shop capsule via brighter parlor palette + visible item cluster.)

## blacksmith — 대장장이 강철 (1 action)
**Identity:** Cyber-forge workshop — soot-dark ironworks, molten-amber forge glow,
orange-amber embers/sparks cut by cold cyber-blue circuit seams; the ONLY room
whose VR substrate reads warm (glowing-hot data-metal).

**Room prompt:**
> Fullscreen BACKGROUND illustration for a cyberpunk VR cyber-forge / blacksmith workshop interior in a video game. Moody, atmospheric, highly detailed digital painting, eye-level three-quarter interior view. This is a BACKDROP layer — leave specific zones open for game elements drawn on top later. LEFT THIRD: a blacksmith's forging station — a soot-blackened brick-and-steel forge hearth with a low molten-amber coal glow, a worn leather-and-steel work corner, hanging tongs, hammers and chisels on a rack, coiled cables and a quench barrel; this left area MUST be free of any person/character (a portrait is placed here separately), readable not over-busy. CENTER and LOWER-CENTER: a massive scarred steel-and-iron anvil workbench scattered with hammers, glowing ingot offcuts, gear cogs and forge tools, BUT with exactly ONE empty round metal forging pedestal / anvil-disc in the open center — the pedestal completely EMPTY, nothing displayed on it. UPPER WALLS: dense cyber-forge clutter — a hulking automated trip-hammer rig and bellows pistons, hanging chains, gauges and pressure dials, sparking conduit pipes, a glowing forge-furnace mouth upper-right venting embers, racked weapon-blanks and tool silhouettes. FLOOR/anvil/surfaces: faint glowing amber-and-cyan data-glyph / circuit / arcane-forge-rune pattern with holographic seams (virtual-reality substrate), embers drifting upward. PALETTE/LIGHTING: deep dark soot base, dramatic low-key, dominant warm orange-amber forge glow and floating sparks, contrasted by cold cyber-blue circuit accents and rim light on the anvil edges, soft volumetric heat-haze and smoke. STRICT EXCLUSIONS: no people/characters/blacksmith; the single pedestal EMPTY (no item, no weapon, no glowing product, no merchandise on it); no UI, no readable text labels, no numbers, no price tags, no health bars, no cursor, no watermark, no logo, no border frame. Single full-bleed opaque scene filling the entire near-square frame.

**Object (512²):**
- `enhance` (마지막 아이템 강화): floating glowing item-core being upgraded above a small dark steel mini-anvil — compact amber-gold enchanted gear/weapon-core, spiral of rising forge sparks + three ascending chevron/upgrade arrows of light (enhancement-level up), molten orange-amber seams crackling, cold cyber-blue circuit filaments + tiny holographic +(plus) runes orbiting, warm amber inner glow + cyan rim, embers up, margin clear. (Reads as "powering an item UP", not a generic hammer.)

## academy — 아카데미 교관 서율 (2 actions)
**Identity:** Hushed holographic data-dojo / arcane library — scholarly teal +
deep-indigo, glowing knowledge-glyphs, suspended scroll-holograms, training-floor
mandala; calm mentor's hall.

**Room prompt:**
> Fullscreen BACKGROUND illustration for a cyberpunk VR skill-academy interior in a video game — a holographic data-library crossed with a serene training dojo. Moody, atmospheric, highly detailed digital painting, eye-level three-quarter interior view. This is a BACKDROP layer — leave specific zones open for game elements drawn on top later. LEFT THIRD: an instructor's lectern station — a sleek dark teak-and-brushed-steel reading desk corner, an empty high stool, and tall floating shelves of glowing holographic data-scrolls and tomes behind it; this left area MUST be free of any person/character (a portrait is placed here separately), readable and not over-busy. CENTER and LOWER-CENTER: a long polished low study counter / training table set on a circular dojo training mandala, bearing TWO empty round glowing display pedestals in a row across the open center — each pedestal completely EMPTY, nothing displayed on them. UPPER WALLS: a scholarly cyberpunk hall — tall arched racks of suspended holographic scrolls, a faintly rotating arcane knowledge-circle projected in the air, drifting glyph particles, soft hanging paper-lantern-style holo lamps, a calligraphic neon emblem high on the back wall (abstract, unreadable). FLOOR and table surfaces: a faint glowing cyan/teal data-glyph, circuit, and concentric arcane-circle pattern (virtual-reality substrate). PALETTE and LIGHTING: deep indigo-and-charcoal base, calm low-key scholarly mood, dominant teal/cyan glow with cool blue accents and a few warm golden book-light rims, soft volumetric haze and dust motes in light beams. STRICT EXCLUSIONS: no people/characters/instructor; the two pedestals EMPTY (no books, scrolls, crystals, orbs, glowing products, merchandise); no UI, no readable text, no letters, no numbers, no price tags, no health bars, no cursor, no watermark, no logo, no border frame. Single full-bleed opaque scene filling the entire near-square frame. Style: cyberpunk, detailed digital painting, atmospheric anime game background art.

**Objects (512², idx order):**
- `lesson_scroll` (스킬 수업 200G): floating holographic teaching scroll, half-unfurled luminous data-scroll, glowing cyan arcane glyphs + concentric knowledge-circles streaming off, warm golden book-light rim, drifting glyph particles, upward learning-aura. Teal/cyan + gold accents, indigo core. Margin clear.
- `exchange_prism` (스킬 교환): two interlocked luminous data-prisms / orbiting crystalline skill-runes joined by a glowing teal circular exchange-arrow ring (two arrows chasing in a loop), energy arcing between prisms = swap/trade. Cyan + cool-blue + gold ring accent. Margin clear.

## lingpet_store — 링펫 사육사 링링 (2 actions)
**Identity:** Organic-cyber lingpet incubator/shelter nursery — warm amber-gold
hatchery glow + soft cyan resonance light, resonance eggs in fluid cradles +
tech-shrine ring-core forge; nurturing, not industrial.

**Room prompt:**
> Fullscreen BACKGROUND illustration for a cyberpunk VR lingpet incubator / creature-shelter nursery interior in a video game. Warm, gentle, atmospheric, highly detailed digital painting, eye-level three-quarter interior view. This is a BACKDROP layer — leave specific zones open for game elements drawn on top later. LEFT THIRD: a caretaker's nursery station — a worn rounded wood-and-brass tending desk corner, an empty cushioned stool, a wall of softly glowing incubation pods and shelves of folded blankets, feeding bottles and small ring-shaped pet collars behind it; this left area MUST be completely free of any person/character or creature (a portrait is placed here separately), readable and not over-busy. CENTER and LOWER-CENTER: a curved organic-cyber hatchery counter of pale ceramic and brushed brass, with cradle slots holding faintly glowing resonance eggs and a small ring-core forge socket, BUT with EXACTLY TWO empty round display pedestals in a row across the open center-right of the counter — each pedestal completely EMPTY, nothing displayed on it. UPPER WALLS: warm nursery clutter — translucent egg-incubation tanks with drifting bubbles and soft inner light, a holographic creature-care chart, hanging mobile of tiny glowing rings, gentle gauges, potted bioluminescent plants, a softly glowing teal lingpet-paw sign upper-right. FLOOR and counter surface: faint glowing teal-and-amber data-glyph / circuit / arcane-summoning-circle pattern (virtual-reality substrate), holographic seams. PALETTE/LIGHTING: deep soft base, warm amber-gold hatchery glow as the dominant tone, cyan / teal resonance accents, magenta motes drifting, soft volumetric haze, cozy and nurturing mood, gentle rim light on the egg cradles. STRICT EXCLUSIONS: no people, no characters, no caretaker, no creatures or pets visible; the two pedestals EMPTY (no eggs, capsules, ring cores, glowing products or merchandise on the pedestals); no UI, no readable text labels, no numbers, no price tags, no health bars, no cursor, no watermark, no logo, no border frame. Single full-bleed opaque scene filling the entire near-square frame. Style: cyberpunk, detailed digital painting, atmospheric anime game background art.

**Objects (512², idx order):**
- `resonance_egg` (공명 알 뽑기 250G): floating glowing resonance egg, iridescent warm amber-gold shell with cyan light-veins, faint hairline crack leaking inner glow, one slim holographic teal data-ring orbiting (summon-key), volumetric halo + drifting magenta motes. Amber+teal. Margin clear.
- `ring_core` (링코어 강화, dynamic label): floating ring-core upgrade module — glowing brushed-brass+cyan toroidal ring with bright hexagonal energy core centered, concentric inner segments + ascending tier-notch lights (upgrade/level-up), warm amber sparks rising, holographic seams + cyan power-glow. Reads as "power core enhancement", distinct from the organic egg. Margin clear.

## tavern — 선술집 주인 하랑 (2 actions)
**Identity:** Cozy cyber-tavern lounge bar — warm amber lamplight over a dark
lacquered bar counter, deep neon-purple twilight corners, holographic signboards
+ softly glowing quest-board substrate; intimate watering-hole warmth.

**Room prompt:**
> A single full-bleed opaque interior illustration of a cozy cyberpunk virtual-reality TAVERN / quest lounge inside the digital realm of Lingpia, near-square framing (760x750), no transparency. Warm amber + deep neon-purple palette: pools of golden lamplight from low hanging filament-style holo-lanterns over a dark lacquered wooden bar counter, with deep violet twilight shadows in the upper corners. Soft holographic seams and a faint glowing data-glyph / arcane-circle / circuit pattern subtly etched into the floor planks and the bar surface, plus a faint neon glyph haze in the air — the cyberpunk VR substrate of this world. LEFT THIRD of the image: keep an OPEN, atmospheric tavern-keeper station only — a section of the bar with shelves of glowing bottle silhouettes, a tap-handle row, a stool, and a softly lit corner; bake NO character or person here, just the empty cozy booth ambiance and warm light. CENTER-LOWER of the image, occupying roughly the right two-thirds: a long dark bar counter / quest-table running across, on top of which sit EXACTLY TWO empty round display pedestals (low glowing cylindrical neon-rimmed plinths) standing side by side in a row, both completely EMPTY with nothing resting on them — softly uplit by amber rim light with a faint cyan glow ring at the base. Behind and above the counter: a large softly glowing wall quest-board / holographic signboard wall covered in faint abstract neon glyph marks and circuit traces (NO readable text), hanging neon sign shapes, dangling cables, and warm bokeh light. Keep TOP-LEFT corner, TOP-RIGHT corner, and BOTTOM-LEFT corner relatively calm and uncluttered (only soft ambient light, no busy props) so HUD can overlay there. Mood: intimate, warm, inviting watering hole at neon night, cozy but high-tech. EXCLUSIONS: no people, no characters, no creatures, no bartender, the two pedestals must be EMPTY (no drinks, no items, no merchandise, no scrolls, no objects on them), no UI, no text, no letters, no numbers, no Korean text, no price tags, no labels, no signage text, no menu boards with words, no HUD, no cursor, no watermark, no border frame, no logo. Single cohesive opaque scene, painterly game-art style, soft volumetric lighting.

**Objects (512², idx order):**
- `quest_scroll` (의뢰 받기): rolled-up holographic quest scroll / digital request-paper, half-unfurled, tilted, hovering — translucent neon membrane warm amber-gold edged with thin cyan data-circuit border, faint abstract glyph-light (no readable text), a glowing hexagonal neon sigil "wax-seal" at the bottom. Amber core + cyan rim + upward sparks. Margin clear.
- `reward_stamp` (의뢰 보고): completed/reported quest — rolled scroll partly flat with a bright glowing CHECKMARK seal stamped on it (clean neon cyan-green tick in a circular sigil ring) + a small rise of amber-gold reward coins/motes above (a couple of hex coin discs, NOT a big pile). Amber scroll glow + cyan-green checkmark accent. Margin clear.
