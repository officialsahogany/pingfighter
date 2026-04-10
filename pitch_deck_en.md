# PingFighter — Game Pitch Deck

---

## 1. Elevator Pitch

> **"Pong × Boss Battles × RPG Progression — An arcade action game where you defeat bosses with a single paddle."**

PingFighter reinvents the classic Pong formula by adding **boss AI combat**, **perk builds**, **item collection**, **an explorable hub world**, and **online PvP** — creating an entirely new sub-genre of arcade action.

---

## 2. Game Overview

| | |
|---|---|
| **Title** | PingFighter (핑파이터) |
| **Genre** | Arcade Action / Boss-Battle Pong |
| **Platforms** | Windows, macOS (Console & Web planned) |
| **Engine** | Python + Pygame (Custom Engine) |
| **Art Style** | Pixel Art + Procedural Backgrounds |
| **Resolution** | 1488 × 918 (pillar UI overlay, play area 760 × 750) |
| **Target Audience** | Casual-to-midcore arcade gamers, ages 15–35 |
| **Play Time** | Campaign 5–10 hrs · Endgame unlimited |
| **Languages** | Korean (Full) · English (In Progress) · Japanese, Chinese (Planned) |

---

## 3. Core Gameplay

### The Basics
- Control a bottom paddle to rally a ball against a **boss paddle** at the top
- **No HP bars** — pure point-based matches (first to 5 points wins)
- Deuce system: 4-4 tie extends to 6, then 7 (max)
- Each boss has **unique AI patterns and special attacks**
- Strategic depth via **dashes**, **active items**, and **perk builds**

### Signature Mechanic: "Half-Dash" System
- Even when dash tokens are depleted, a **50% distance emergency dash** is always available
- Eliminates complete helplessness — skilled play is always rewarded
- Creates clutch reversal moments that define high-level play

### Game Loop
```
Stage Select → Boss Battle → Item Drops → Perk Investment → Next Stage
      ↕                                         ↕
  Downtown Hub ← → Gacha Shop / Store / Forge / Colosseum
```

---

## 4. Boss Characters — 15 Unique Enemies

8 stages featuring 15 bosses (8 main + 7 sub-bosses), each with distinct themes, AI behaviors, and special attacks.

| Stage | Theme | Main Boss | Sub-Bosses | Signature Mechanic |
|-------|-------|-----------|------------|-------------------|
| 1 | Korean Traditional | **Pungak Boy** | Grapemaster, Gaksital | Fan projectiles, rope throws |
| 2 | Jungle / Swamp | **Gator General** | Mole King, Arachne | Tunnel spikes, spider web slow zones |
| 3 | Menhera / Dolls | **Menhera Girl** | Teddy Bear, Alice | Cotton shotgun, mirror world (screen flip!) |
| 4 | Shaolin Temple | **Ponk** | Inwang | Counter mechanics, speed debuffs |
| 5 | Naval Warfare | **Nemesis** | — | Laser / shield / spin modes, barrier system |
| 6 | Chinese Fire | **Hongren** | — | Fireball attacks, 10-hit set limit, flame events |
| 7 | Tetris Arena | **Tetriser** | — | Tetris block field hazards |
| 8 | Shadow Dojo | **Akamu Rigo** | — | Max stats (speed 9.4), ninja mansion |

- Boss difficulty scales from speed 6.3 → 9.4
- Fighting-game feel: stun frames, invincibility, screen shake

---

## 5. Key Systems

### A. Perk System (In-Battle Builds) — 49 Perks
- Earn **Star Points** during battle to choose from 3 random perks
- **21 universal** + **23 character-exclusive** + **5 instant** perks
- Every run produces a different build

### B. Item System — 78 Items Total
| Category | Count | Examples |
|----------|-------|---------|
| Active Items | 31 | Grenade, Molotov, Holy Barrier, AI Pill, Stopwatch, Weather Capsule |
| Passive Items | 32 | Persistent stat boosts with random roll options |
| Mythic Items | 11 | Ragnarok Hammer, Poseidon's Trident, Hermes' Shoes, Odin's Eye, Pandora's Legacy, Valhalla Warplate |

- Mythic items feature **random stat rolls** + **polishing** (enhancement) system

### C. Gacha System
- 3-tier distribution: Mythic (5%–30%) / Active (50%) / Passive (45%)
- Full capsule machine animation (coin insert → spin → capsule drop → reveal)
- 500 Gold per pull, 40 capsules per session

### D. Downtown (Hub World)
- **13 building types** (7 active) — explorable pixel-art town
- Gacha shop, item store, bank, colosseum, minigames, forge, tavern
- NPC dialogue, merchants, tile-based free movement
- **Bodyguard system**: captured arena heroes follow you as companions

### E. Online PvP
- P2P socket-based multiplayer
- Host/guest matchmaking with character & stage selection lobby
- Recent IP auto-save for quick reconnection

### F. Replay System
- 60fps full-screen capture with async compression (zero frame drops)
- Sound event auto-recording & playback
- Up to 10-minute recordings

### G. Quest System — 8 Quests
- Accept quests at the Downtown **Tavern**
- Combat missions: Perfect Victory, Speed Run (3 min), No Dash, 15-Rally Streak, etc.
- Rewards: 800–2,500 Gold

### H. Dynamic Weather — 7 Types
- 10% chance per round: Breeze, Gale, Fire, Ice, Rain, Hail, Sandstorm
- Each weather type changes physics (slippery ice, fire acceleration, rain speed debuff)
- Full particle systems per weather type

### I. Colosseum Arena Meta-Loop
- **Capture → Servant → Bodyguard** promotion loop with 15 arena heroes
- 3 tiers of seals: Beginner (Quarterfinals), Intermediate (Semifinals), Bodyguard (Finals, permanent)
- Up to 2 bodyguards equipped, visible as Downtown followers

### J. Tutorial
- 6-chapter progressive tutorial (sub, dash, drive, power smash)
- 5 arena-specific tutorials

### K. Opening & Stage Intros
- Story cutscene with protagonist "Yuian"
- 8 unique stage intro videos (OpenCV playback + boss text overlay)
- 5-scene cinematic: paddle-ball meeting → boss reveal → battle → power-up → final showdown

---

## 6. Playable Heroes — 6 Characters

| Hero | Specialty | Exclusive Skills |
|------|-----------|-----------------|
| **Smasher** | All-rounder, chain power smash | Dash Spirit, Plasma, Recovery, Cleanse |
| **Commando** | Firepower specialist, arm cannon | Magazine Mod, Fire Support, Net Gun, Bowling Trap, Suicide Drone |
| **Baltor** | Defense/construction | Thor Shield, build system |
| **Viper** | Aerial mobility, jetpack | Jetpack, Marshal Kick, Phantom Kick (4-hit combo), EMP Strike |
| **Optimus** | Mechanic, expanded hitbox | Optimus Arm, Emergency Charge, Elec Pad, Star Change |
| **Normal** | Basic paddle | — |

> Additional heroes (Guardian, Mystic, etc.) are shown on character cards — combat integration is planned for future updates.

---

## 7. Visual & Audio

### Art Style
- Pixel art characters + procedurally generated animated backgrounds
- 8 unique stage themes with parallax scrolling, particles, and dynamic effects
- Cyberpunk-inspired UI with glow effects
- Mythic item legendary glow animations

### Sound Design
- **40+ sound effects** (hits, explosions, level-ups, UI feedback)
- Per-stage BGM with dynamic music transitions
- Full sound event system for replays

---

## 8. Content Scale

| Content | Count |
|---------|-------|
| Boss Characters | 15 (8 main + 7 sub) |
| Playable Heroes | 6 (5 with perk builds + 1 basic) |
| Stages | 8 + 1 Arena |
| Total Items | 78 (31 active + 32 passive + 11 mythic + 4 special) |
| Perks | 49 (21 universal + 23 exclusive + 5 instant) |
| Downtown Buildings | 7 active (of 13 total) |
| Quests | 8 |
| Weather Types | 7 |
| Tutorials | 6 chapters + 5 arena |
| Sound Effects | 40+ |
| Animated Backgrounds | 8 |

---

## 9. Market Analysis

### Comparable Titles
| Game | Similarity | PingFighter's Edge |
|------|-----------|-------------------|
| **Windjammers 2** | Arcade 1v1 sports | + RPG progression, boss AI, item system |
| **Lethal League Blaze** | Ball-based fighting | + PvE campaign, hub world, collection |
| **Pong Quest** | Pong + RPG | + Online PvP, perk builds, gacha, arena |
| **Nidhogg 2** | 1v1 arcade | + 15 bosses, 78 items, deep endgame |

### Target Audience
- **Primary**: Retro arcade fans & indie game enthusiasts (20–35)
- **Secondary**: Collection/progression-driven casual gamers
- **Tertiary**: Competitive players seeking local/online PvP

---

## 10. Localization Plan

| Language | Status | Timeline |
|----------|--------|----------|
| **Korean** | ✅ Complete | Shipped |
| **English** | 🔄 In Progress | Q3 2026 |
| **Japanese** | 📋 Planned | Q4 2026 |
| **Chinese (Simplified)** | 📋 Planned | Q4 2026 |

- Pixel font system supports CJK character sets
- UI layout designed for variable text lengths

---

## 11. Business Model

### Monetization Strategy
| Model | Description |
|-------|-------------|
| **Premium (Buy-to-Play)** | One-time purchase on Steam / itch.io |
| **DLC Expansion Packs** | Additional bosses, stages, characters |
| **Cosmetics** | Paddle skins, visual effect changes |

### Price Points
| Product | Price |
|---------|-------|
| Base Game | $9.99–$14.99 |
| Stage DLC Pack | $4.99 |
| Cosmetic Bundle | $2.99–$4.99 |

---

## 12. Development Status & Roadmap

### Current State
- **Codebase**: 173,000+ lines (main file) + 99 modules
- **Feature Completion**: Core gameplay complete, UI refactoring in progress
- **Playable Build**: Available for demo

### Roadmap

| Phase | Target | Details |
|-------|--------|---------|
| **Now** | UI Polish & Stabilization | Modular refactoring, bug fixes |
| **Q3 2026** | English Localization + Steam Page | Store page, trailer, wishlists |
| **Q4 2026** | Steam Early Access Launch | Full campaign + online PvP |
| **2027 H1** | Full Release + Console Port | Nintendo Switch / Xbox planned |
| **2027 H2** | DLC & Community Content | New bosses, stages, modding support |

---

## 13. What We're Looking For

PingFighter is seeking strategic partners to accelerate its global launch:

| Need | Details |
|------|---------|
| **Publishing Partner** | Global distribution, marketing, store page optimization |
| **Investment** | Localization, QA, console porting, marketing budget |
| **Marketing Support** | Trailer production, influencer outreach, event showcases |
| **Platform Partnerships** | Steam featuring, console dev kits, cloud gaming |

We are open to revenue-share, advance-against-royalties, or hybrid deal structures.

---

## 14. Why PingFighter?

1. **Simple yet Deep** — Pong's intuitive controls + 15 bosses' strategic depth
2. **Endless Progression** — 49 perks, mythic items, random roll farming
3. **Visual Spectacle** — Per-stage intro videos, 8 animated themes, gacha animations
4. **Competitive Fun** — Online PvP, 6 differentiated heroes, arena meta-loop
5. **Exploration** — Downtown hub with 7 buildings, 8 quests, bodyguard system
6. **Accessibility** — 6-chapter tutorial, keyboard-only instant play

---

## 15. Team

| Role | Member |
|------|--------|
| **Studio** | Dongne Games (동네게임즈) |
| **Development & Design** | Solo developer — programming, game design, art, sound |
| **Engine** | Custom Python/Pygame engine |
| **AI Assistance** | Claude Code (development acceleration) |

---

## 16. Contact

| | |
|---|---|
| **Studio** | Dongne Games (동네게임즈) |
| **GitHub** | [github.com/officialsahogany/pingfighter](https://github.com/officialsahogany/pingfighter) |
| **Email** | *(to be added)* |

---

*PingFighter — Boss-hunting arcade action, one paddle at a time.*
