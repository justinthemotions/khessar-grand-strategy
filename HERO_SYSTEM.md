# The Hero System — Technical Briefing (v1.0)

This document covers the hero-tier character layer: distinguished practitioners who can singlehandedly influence battles while remaining real diplomats, commanders, and decision-makers in the campaign. It implements Opus's design doc **"Khessar Grand Strategy — The Hero System (v1.0)"** (2026-07-08, Drive `1KJZwBXhxogVA5PmdgYJRcHpDFCbuRfAmSzJEUzTLJMg`), all seven phases of its implementation journey. The static tables live in `scripts/hero_db.gd` (class `HeroDB`); the campaign layer (seeds, XP, wounds, deployment) in `scripts/world.gd`; the battle layer (abilities, personal HP, death saves, Legendary Actions) in `scripts/battle/battle_sim.gd`; the spell bar and targeting UI in `scripts/battle/battle_view.gd`. The test is `tests/hero_system_test.gd`. Written for onboarding: everything here reflects the actual code, with exact constants and formulas.

The design law, from the doc's first page: **heroes amplify their armies; they do not replace them.** A level-5 Wizard commanding a formed line is devastating. The same Wizard alone against a Compact-Sworn Company gets overwhelmed.

## 1. The hero stream discipline (read this first)

Every hero die rolls on `hrng` (seed **75** — the XP capstone, what a level-10 life amounts to). The seeded canonical heroes are `hero_cast`, folded into `is_cast()` — so every existing pool guard (births, deaths, marriages, skirmishes, champions, plots, council fills, commander assignment) excludes them for free, and **the fixed-seed history never feels their arrival**.

Three subtler guards were required, found the hard way (each one, unguarded, flipped the Architect's Vigil recipient by a single wooden bird):

- **`faith_reliability`'s shared-attention crowd** skips `hero_cast` — 17 new souls in Vael must not make every prayer 17% more answerable than the history already prayed.
- **`_cathedral_tick`'s priest scan** skips `hero_cast` — the quarterly rite keeps its pre-hero hands; the Reactionary clergy do not inherit the cathedral's dice.
- **`_faith_change_tick`'s conversion weather** skips `hero_cast` — the hero cast converts by scheduled beats, not by per-soul consideration dice.

Verified byte-identical: `frng`, `mrng`, and the main `rng` states match the pre-hero build tick-for-tick through the Vigil horizon, and the recipient is Thessaly again, twentieth bird and all.

The discipline extends the house invariant one step: **auto-firing beats fill only the hero ledger** (XP, personal HP, the pool counts) — **the Core Six move only under the player's hand.** `award_hero_xp(cid, amount, reason, by_hand)` banks XP and grows the HP pool on any level-up, but applies the class's +1/+1 stat growth only when `by_hand` is true (player battles, the player's framework). A canonical stat block can never drift mid-history because a magister attended enough votes.

## 2. Hero-tier vs ordinary (doc §2)

`SimCharacter` carries the hero fields; `hero_level 0` means ordinary (most of the population):

| field | meaning |
|---|---|
| `hero_level` | 1–10; 0 = not hero-tier |
| `hero_xp` | lifetime experience; seeded at exactly `HeroDB.xp_for_level(level)` |
| `hero_class` | one of the 18 class ids (§4) |
| `hero_hp` / `hero_hp_max` | the personal HP pool, separate from any unit's (doc §3 curve) |
| `hero_combat_level` | field-ability tier when it lags the craft (−1 = `hero_level`); Anselm 1, Veril 1, Vovel 2 |
| `hero_wounded_until` | campaign tick before which the hero takes no field |

Deployment styles (doc §6) live in `world.hero_deploys[id]`: `never` (Caeris, the Matriarchs, Velmarin, Grimhold), `rarely` (the diplomats, the magisters, Thessaly), `normal`, `eager` (Ilsen, Voss, Kaal, Drev, Marak, Iliana). v1.0 enforces the wound gate everywhere (`_assign_commander` and `set_commander` both refuse a recovering hero); style-driven AI assignment is deferred (§9).

## 3. Levels and experience (doc §3)

Thresholds, verbatim: **0 / 500 / 1500 / 3500 / 7000 / 12000 / 20000 / 32000 / 50000 / 75000.** HP: 40 at level 1, +8 per level (112 at 10); Wizards and Sorcerers start frail at 30, Paladins/Fighters/Rangers hearty at 50. Stat growth per level, class-keyed (doc's "Intelligence" maps to the Core Six's Intrigue): Wizard lrn/int, Sorcerer dip/lrn, Cleric dip/lrn, Paladin prw/dip, Druid lrn/prw, Warlock lrn/int, Bard dip/int, Monk prw/lrn, Fighter prw/mar, Ranger mar/lrn, Rogue int/prw.

XP awards (`HeroDB.XP_AWARDS`, doc ranges landing on midpoints) and the hooks already wired:

| award | value | fires from |
|---|---|---|
| `battle_survived` / `battle_victory` | 50 / 100 | `apply_battle_result` (player battles, by-hand), `apply_hero_battle` |
| `enemy_hero_killed` | 300 | `apply_hero_battle` when the enemy hero died on the field |
| `legendary_action` | 100 × uses | `apply_hero_battle`, from `sim.hero_actions_used` |
| `council_vote` | 25 | `magister_vote` — every non-abstaining seated magister |
| `council_appointment` | 200 | `_seat_magister` (new holders only; seed-time seats award nothing — heroes do not exist yet) |
| `chief_archivist` | 500 | the tick-44 beat, by name (doc §3 names this succession) |
| `marriage_arranged` / `alliance_formed` | 100 / 150 | `marry` — the arranging crowns |
| `peace_treaty` | 200 | `negotiate_peace`, dictated peace, winner's crown |
| `threshold_rite` | 40 | `_threshold_on_death` — the bird carved |
| `ceremony` | 30 | `_threshold_maintenance_tick` quarterly carving |
| `bardic_performance` | 25 | `_bard_tick` quarterly, Song-Marked hero-tier |
| `research_published` | 200 | Thessaly's Year-112 paper; Caeris when the finding publishes |
| `political_conversion` | 250 | `_framework_implemented` — the player's crown (by-hand) |

None of the auto-firing awards can reach a level threshold inside the canon-asserted horizons (verified: two worlds, twelve months, identical ledgers; the full suites green).

## 4. The classes (doc §4)

`HeroDB.CLASSES` holds 18: the doc's **eleven progression classes** (wizard, sorcerer, cleric, paladin, druid, warlock, bard, monk, fighter, ranger, rogue), the **two Khessar-specific callings** the doc's §5 names as distinctive hero types (**gravewarden**, **ward_speaker**), and the **five civil classes** the §8 roster requires (**scholar, diplomat, merchant, bureaucrat, noble** — no battle actives; their craft is the campaign). Each class carries `base_hp`, `growth`, and `practice` — which binary casting gate its workings roll (`arcane`, `faith`, `oath`, `primal`, or `""` for crafts that never gate: the Patron, the carried names, the body, the threshold, the ward-lattice).

Ability grants are cumulative per level in `HeroDB.GRANTS`, doc-faithful including the utility spells (Detect Magic, Invisibility, Divination, Wish — recorded, not field orders). **Fireball unlocks at level 5**, per the doc's "(per your instinct)" ruling; level 4 keeps Lightning Bolt, Ice Storm, and Counterspell. Sorcerers cast the Wizard table with the doc's §4.2 costs: every gate ×0.8, +0.5 corruption per casting. Bard amounts scale ×(1 + names_carried/200), capped ×2 — the same law as the commander-scale song aura. The scholar's grants begin at level 8: **Observe, Redirect, The Settling Touch** — Caeris's Legendary Actions, translated exactly as the Canon Updates documented them.

## 5. Heroes on the field (doc §7)

`BattleSim.set_hero(side, world.hero_info(cid))` puts a hero on the field. The hero rides with a **host line** (the strongest friendly regiment, reassigned if it breaks), projects any standing auras from wherever the host stands, and spends **field orders** — the class's unlocked actives — through `use_hero_ability(side, aid, target)`:

- **Every working rolls its binary gate first** (Tactical Combat v1.0 law): `casting_reliability(practice, hero traits)` — it fires whole or fizzles whole, and the cost lands either way (stress to the commander's ledger; corruption for Warlocks per ability, Sorcerers per cast). A fizzled Fireball on Ashfields ground consumes the use and burns nothing.
- **Counterspell** (wizard passive, 1 use, 2 at L6+): the first enemy *magical* working dies mid-air.
- **Cooldowns**: per-ability `cd` plus a global window — `HERO_GLOBAL_CD` 10 combat ticks, **halved to 5 for Legendary heroes** (L8+), who also get +1 use of everything. That is what "Legendary Actions: additional actions per battle turn" cashes out to at this sim's tick economy.
- **Effect primitives**: `aoe` / `line` / `multi` / `single` (damage through the same pipeline as combat — pool, soldiers, casualty shock), `zone` (persistent ground effects, drawn burning on the field), `timed` (one working per line: ma/md/ws/damage-taken/speed/lead, Web slows, Wall of Force stops arrows, Hunter's Mark marks), `rally` / `shockwave` (morale, respecting `no_morale` and silence immunity), `heal` / `heal_area` (pools refill, men stand back up, capped at starting strength), `hero_strike` (Assassinate: the enemy hero bleeds), `dispel`.
- **Personal HP**: riding a bleeding, engaged host chips the hero — `casualties × 0.45 × max(0.2, 1 − prowess × 0.025)`, halved by Uncanny Dodge; abilities striking the host splash ×0.15 onto the rider. At 0 HP the hero falls **unconscious** and rolls **death saves** on the battle's own dice (`brng`, 0.55 to succeed, one per combat tick): three failures = dead, three successes = stable and out of the battle. Death Ward (cleric passive) refuses the first killing blow. **Legendary Resistance**: 3 charges convert failed saves.
- **The AI** (`_ai_hero`, both sides under `run_headless`) is deterministic: mend what is breaking (< 60% strength), break what is massed (≥ 24 soldiers under the blast), steady what wavers (shock > 45), mark what is engaged — one working per window, dice only at the gates.

After the field, `world.apply_hero_battle(sim, side, player_initiated)` writes it back: XP (§3), wounds (the `Wounded` trait + `hero_wounded_until = tick + 6`), **capture** on a lost field (the champion's-chains rule — a hostage ward of the enemy realm, ransomable), or death (`_kill`, with everything that cascades). Hero-tier commanders **skip the classic `_commander_fate` roll** — their fate was decided on the field itself, through personal HP; the abstract dice would be double jeopardy.

`ashfields_march` now fields **Caeris himself**: Level 9 Legendary scholar with Observe, Redirect, and The Settling Touch live behind the Warden-Dead, on top of the scholar-commander defense mods. The march remains winnable, and the finding remains lost. He would note the data.

## 6. The canonical roster at Year Zero (doc §8)

30 already-living figures took their levels (no dice — pure field assignment), and **27 the chronicle owed a body were seeded** on `hrng` with canonical stat blocks (the Caeris rule: Core Six land AFTER traits), exactly one Silence Response each (the magic census holds), and `hero_cast` guards. Highlights — full table in `_seed_heroes()`:

| figure | class | level | note |
|---|---|---|---|
| Caeris the Unfinished | scholar | **9** | Legendary; doc range 8-9, upper picked (§9 flag) |
| Analinth Veldarin / Ariorwe Thaladris | wizard / bard | 8 / 8 | Ariorwe already carried 120 names — canon matched code |
| Veril Ormand / Marek Vovel | scholar | 8 / 8 | combat 1 / 2 — the craft outlived the field |
| Halvar Stenn | gravewarden | 7 | |
| Grimhold Ironvault / Tess Mareck / Vaelmark / Vossa Thaledrin / Bronvor | fighter / rogue / paladin / fighter / ward_speaker | 6 | Vossa: doc 5-6, upper picked |
| Marak Khorul (new) | wizard | 5 | walked away; walks the Salt Road; Restless |
| Odric Vasse | wizard | 5 | the senior of the four (doc "4-5"); Solvey/Draeth/Nym at 4 |
| Garran, Vorak, Grimkar, Ilsen, Kaal, Pellburn, Veldrin, Grim Vol-Gar, Otter, Eithne, Ferren, Vessa, Maret, Mareldin, Thossmar, Arlina, Carathwell | — | 5 | per doc §8 |
| Selene Tharn, Halloran, Voss, Veskren, Selia, Karth, Drev, Thornhardt, Aldon, Verrik, Iliana, Thelren | — | 4 | Iliana: 40 names carried |
| Anselm (combat 1), Davriand, Kreth, Sevrin, Ilyra, Mira, Ren, Youngric, Tavisol | — | 3 | |
| Sera Halvenard-Veil | noble | 2 | |

The **unnamed hero-tier population** (doc §2 density) is the `hero_pool` ledger — 15 regional counts summing to ~295, putting the continent at ~352 with the named (inside the doc's 200–400 band). It drifts yearly and deterministically: +28/year scaled by remaining room toward the 500 steady-state cap, −21/year scaled by fullness — no dice, identical in any two worlds.

## 7. The player's hands on it

- **The spell bar** (`battle_view.gd`): when the side-0 commander is hero-tier, their field orders appear as buttons above the card bar — label, uses remaining, tooltip with the working's description or why it cannot be given. Click an order, and the field shows the working's reach under the cursor; left-click places it, right-click puts it down unspent. Dispel and Assassinate fire without a target.
- **The commander card** gains the hero's level tag and a red personal-HP strip; a fallen hero shades his own card with the same skull the lines get. The commander sheet shows class, level, LEGENDARY when it applies, personal HP, and DOWN/dead state.
- **Zones burn on the field** (pulsing rings), workings flash where they land, and the campaign's commander pickers label every hero-tier option "— L5 Fighter".

## 8. Testing

`tests/hero_system_test.gd` (8 groups): the HeroDB tables (thresholds verbatim, HP curves, eleven distinct progressions, Fireball at five); the canonical instantiation (≥55 named, density band, key figures' exact levels/classes); the 27 owed bodies (guards, responses, census bounds, Iliana's withheld trait); the stream discipline (auto XP banks without stat drift, by-hand XP grows prw/dip on a paladin); hero combat (fireball kills through the standard pipeline, identical setups identical fire, fizzles whole on grey ground, the paladin aura carries, the prayer lands on ward-stone ground); death saves and Legendary Resistance; the field-to-campaign write-back (wounds gate deployment, XP banks); and two-world twelve-month determinism over the whole hero ledger.

Run: `Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tests/hero_system_test.gd`

All 16 prior suites stayed green **unmodified** — including the exact-canon tripwires (the Vigil's recipient weights and 80-month two-world determinism, religion's Y20 numbers, the magic census, the silence-made grey-country determinism). One test-adjacent canon note: `culture_roster_test`'s realm-court rule (realm-0 souls are Aelindran-cultured) is why Marak Khorul carries `aelindran` culture despite his Vael academy training.

## 9. Scoping notes for Opus (deviations & deferrals)

- **Caeris at 9, Analinth at 8** (both "8-9" in the doc): the ethical antagonist got the upper bound, the longevity Matriarch the lower — so the grey country holds the continent's peak. Re-rule freely; it is one integer each.
- **Vossa Thaledrin at 6** ("5-6"): the Marshal of the Faithful peers the founding commander. **Odric Vasse 5, Solvey/Draeth/Nym 4** ("4-5"): Odric's arc earned the edge. **Eithne 5** ("4-5"), **Verrik 4** ("3-4").
- **Iliana Vesh carries 40 names but not the Song-Marked trait**: `_bard_tick` draws an `mrng` die per Song-Marked soul, and her arrival must not reshuffle the magic stream. Her bard class carries the identity; a guarded exemption can grant the trait when Opus wants her singing on the campaign layer.
- **Hero-preference in AI commander assignment is deferred**: a martial tie-break on hero level measurably moved commanders' field positions and, through the magic residents' ground dice, the streams. v1.0 ships the wound gate only; deployment styles are data awaiting a stream-safe reader.
- **Harrold Carathwell and Thelren Dunmoreth are seeded as heroes but not as `cast_rulers`** — the Carath/Dunmore crown pass (diplomacy wiring, scheduled beats) stays with Faction Cast v1.2.
- **Youngric Halden joins House Halden** — Anra Halden's house, by find-or-create. Kinship unplanned but plausible; bless or rename.
- **The unnamed archetypes** (the Brushgate Dwarven Monk, the Warlock woman at Corruption Mark II, the Half-Elf Druid) live in the pool, not as characters — they are reserved slots, and slots stay reserved until their docs name them.
- **No named Sorcerers exist** (the doc queues them for future canon); the class is fully implemented and tested via crafted hero dicts.
- **AI heroes' Core Six never grow** (the stream discipline's cost). If Opus wants canonical NPCs to strengthen over decades, the clean path is scheduled beats ("Ilyra reaches level 5 in Year Twelve") — beats may move cast stats deliberately, exactly like every other canon assignment.
- **Capture requires a live enemy realm** (the hostage-ward machinery needs a court to hold the chains); marches on the Ashfields wound rather than capture — the Warden-Dead do not take prisoners, and Caeris files a complaint about the entire premise.
