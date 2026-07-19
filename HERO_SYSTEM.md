# The Hero System — Technical Briefing (v1.2, single-entity tactical pass)

This document covers the hero-tier character layer for the **grand-strategy game**. It is a streamlined Total War/Crusader Kings hybrid, not the separate one-for-one TTRPG rules adaptation. The twelve familiar class chassis and their recognizable spells/features are retained, but progression is compressed to levels 1–10 and battlefield resolution remains deterministic and real-time. No second six-attribute sheet, turn economy, prepared-spell UI, or per-soldier saving-throw simulation is introduced. Static data lives in `scripts/hero_db.gd`; campaign state in `scripts/world.gd`; deterministic tactical state in `scripts/battle/battle_sim.gd`; the visual actor in `scripts/battle/hero_actor_2d.gd`; and input/rendering in `scripts/battle/battle_view.gd`.

Two design laws govern everything below:

1. **Heroes amplify their armies; they do not replace them** (Opus's doc, first page).
2. **Not every soul has the potential for greatness** — most people are their office, not a class, ordinary until the day they pass, and that is fine. It is what makes the class-bearing few worth acquiring.
3. **Class and compressed level are the tactical progression surface.** A Khessar level is approximately two tabletop levels of battlefield significance, so level 5 is a mid/high-tier hero and level 7 is roughly a level-14 analogue.

## 1. The hero stream discipline (read this first)

Every hero die rolls on `hrng` (seed **75** — the XP capstone, what a level-10 life amounts to). The hero-pass-seeded souls (class-bearing or not) are `hero_cast`, folded into `is_cast()` — so every existing pool guard (births, deaths, marriages, skirmishes, champions, plots, council fills, commander assignment) excludes them for free, and **the fixed-seed history never feels their arrival**.

Three subtler guards were required, found the hard way (each one, unguarded, flipped the Architect's Vigil recipient by a single wooden bird):

- **`faith_reliability`'s shared-attention crowd** skips `hero_cast` — 17 new souls in Vael must not make every prayer 17% more answerable than the history already prayed.
- **`_cathedral_tick`'s priest scan** skips `hero_cast` — the quarterly rite keeps its pre-hero hands.
- **`_faith_change_tick`'s conversion weather** skips `hero_cast` — the hero cast converts by scheduled beats, not by per-soul consideration dice.

Verified byte-identical: `frng`, `mrng`, and the main `rng` states match the pre-hero build tick-for-tick through the Vigil horizon, and the recipient is Thessaly again, twentieth bird and all.

The discipline extends the house invariant one step: **auto-firing beats fill only the hero ledger** (XP, personal HP, the pool counts) — **the Core Six move only under the player's hand.** `award_hero_xp(cid, amount, reason, by_hand)` banks XP and grows the HP pool on any level-up, but applies the class's +1/+1 stat growth only when `by_hand` is true.

## 2. Classes are for heroes; everyone else is their office (SRD rule)

`hero_level 0` means ordinary — the vast majority. Ordinary souls have no class, no level, no personal HP pool; they are identified by **`world.position_of(c)`**, resolved in priority order:

1. `court_positions[id]` — canonical offices set at seed or by beats ("Master Merchant of the Salt Road", "Chief Archivist of the Iron Library", "Secretary to the Council", "Baroness"...)
2. `cast_title_of` — the canonical crowns ("Queen of Pellar", "First Voice of Halven", "Scholar of the Ashfields")
3. live-realm rulership (`live_ruler_title`), magister seats, realm council seats (Marshal / Steward / Lawspeaker / Spymaster)
4. army command ("Commander"), county lordship ("Lord"/"Lady"), hostage-wardship ("Hostage")
5. defaults: **"Courtier"** for adults, **"Child of the Court"** for the young. ("Commoner" enters the vocabulary with the population layer — the sim currently models courts.)

The Thessaly promotion beat now moves her *office*: tick 44 sets `court_positions[thessaly_id] = "Chief Archivist of the Iron Library"`. Offices and classes coexist where canon wants both — Tess Mareck is a Level 6 Rogue *and* Chief Spymaster; Duke Harrold Carathwell is a Level 5 Fighter *and* Duke of Carath.

Hero fields on `SimCharacter`: `hero_level` (1–10), `hero_xp`, `hero_class` (one of the twelve), `hero_subclass` ("" resolves to the class's default subclass), `hero_hp`/`hero_hp_max`, `hero_combat_level` (field tier when it lags the craft: Anselm 1, Veril 1, Vovel 2), `hero_wounded_until`. Deployment styles (doc §6) in `world.hero_deploys`; the wound gate is enforced in `_assign_commander` and `set_commander`.

## 3. Levels and experience (doc §3)

Thresholds: **0 / 500 / 1500 / 3500 / 7000 / 12000 / 20000 / 32000 / 50000 / 75000.** These are ten compressed campaign tiers rather than a literal truncation of tabletop progression. HP is 40 at level 1 and +8 per level (112 at 10); Wizards and Sorcerers begin at 30, Paladins/Fighters/Rangers at 50, and Barbarians at 55. Existing campaign growth hooks remain for continuity, but the new tactical actor derives movement, weight, footprint, melee pressure, reach, and cadence from **class + level**, not from six individual attributes.

XP hooks wired (awards in `HeroDB.XP_AWARDS`, doc ranges at midpoints): battles survived/won (+50/+100, by-hand), enemy hero killed (+300), Legendary Actions used (+100 each), Council votes (+25 per speaking magister), Council appointment (+200), the Chief Archivist succession (+500, by name — self-activates if the desk's holder ever bears a chassis), marriages/alliances arranged (+100/+150 to the crowns), dictated peace (+200), threshold rites (+40), quarterly carving (+30), bardic seasons (+25), research published (+200), the consent framework carried (+250, by-hand). None of the auto-firing awards can reach a threshold inside the canon-asserted horizons (verified two-world).

## 4. The twelve classes, and the subclasses where Khessar lives (doc §4)

`HeroDB.CLASSES` holds twelve recognizable chassis: barbarian, wizard, sorcerer, cleric, paladin, druid, warlock, bard, monk, fighter, ranger, and rogue. Each carries campaign HP/growth data and an optional practice gate. `HeroDB.HERO_PROFILES` separately defines tactical role, speed, radius, collision weight, melee pressure, reach, and attack cadence.

The SRD provides **one subclass per class**; `HeroDB.SUBCLASSES` holds those (srd: true) plus **Khessar's own traditions** — this is the setting's creative shelf:

| class | SRD subclass | Khessari subclasses |
|---|---|---|
| Barbarian | Path of the Berserker (Rage) | (setting-specific paths can be added without changing the runtime entity) |
| Wizard | School of Evocation (pow ×1.10) | **School of the Unfinished** (exclusive, never gates — Caeris's threshold anchor-work: Observe/Redirect/Settling Touch at L8+); **School of Ward-Speech** (exclusive, never gates — the Kharak-Dum lattice: Stone-Word, Ward Lattice, the Deep Ward); **School of the Archive** (exclusive, no field orders — the Iron Library's craft is the campaign) |
| Sorcerer | Draconic Bloodline | **Silence-Touched Bloodline** (pow ×1.15 — awaits its named canon) |
| Cleric | Life Domain (heal ×1.25) | **Threshold Domain** (never gates — the Gravewarden's kit: Witness, Threshold Ward, the Last Rite, Hold the Door); **Domain of the Reclaimed Rites** (rally ×1.30 + a standing litany aura — the Reactionary liturgy) |
| Paladin | Oath of Devotion | **Oath of the Vigil** (smites read the wrongness: ×2.0 vs the Silence-born) |
| Druid | Circle of the Land | (the green roads await their named canon) |
| Warlock | The Fiend | **The Patron of the Quiet** (awaits its named canon) |
| Bard | College of Lore (song cap ×1.75) | **College of Carried Names** (song cap ×2.0 — the Song-Marked tradition) |
| Monk | Way of the Open Hand | **The Brushgate Way** (rally ×1.20 — stillness as countermeasure) |
| Fighter | Champion (host line ma +2) | **Clan-Sworn** (rally ×1.20 + host ma +1 — the Drevak doctrine) |
| Ranger | Hunter | **Beastwarden** (awaits its named canon) |
| Rogue | Thief | **The Watchful** (hero-hunting ×1.5 — the Spymaster's craft) |

Subclass hooks: `practice` overrides the class gate (threshold-work and ward-speech run on older theologies that never gate), `grants` add abilities into the level flow, `exclusive: true` **replaces** the class table (Caeris never learned a fireball — asserted in the suite), and `mods` tune the battle math (pow/heal/rally/vs-silence/song-cap/hero-strike multipliers, plus standing auras).

**A class is the chassis; the campaign's practice traits stay a separate layer.** Caeris is a Level 9 Wizard by chassis and holds no Arcane-Blooded trait — his school never touched the academy, and the magic census never counts him. Fireball still unlocks at **level 5**, per the doc's "(per your instinct)" ruling.

## 5. Independent heroes on the field

`BattleSim.set_hero(side, world.hero_info(cid))` now creates a `HeroRuntime`: an independently positioned circle with its own facing, move target, class profile, melee cadence, collision weight, and temporary states. Movement uses the same sub-step budget as formations. Collision is circle-versus-oriented-formation geometry; normal heroes are displaced by a line, while heavy Rage/Wild Shape actors can transfer a bounded amount of correction into the formation center. Heroes therefore press against units without stacking, passing through, or requiring rigid bodies for every soldier. The legacy side-indexed HP/state/resource arrays remain synchronized for UI, older callers, deterministic autoresolve, and campaign write-back.

`HeroActor2D` is a visual adapter over that runtime state. The commander card and field actor select the same entity; right-click moves it independently; zoom/camera transforms remain owned by `BattleView`. Its pixel silhouette changes for melee/caster/flanker roles, Rage, Wild Shape, attacks, unconsciousness, and personal/temporary HP.

Visual identity is handed off explicitly rather than rerolled. `world.hero_info()` includes a compact profile resolved by `PortraitAppearance` from the same genome, age, presentation, race, and culture used by `FaceView`. The campaign medallion, commander card, active field actor, and fallen actor therefore share skin, hair, age greying, eyes, hairstyle, beard, and ancestry cues. Natural skin spans the inherited human range; Orc blood uses green/olive hues; Tiefling blood spans cool blue/violet through warm crimson; half ancestries blend their parent palettes; authored skin/hair/eye overrides pass through unchanged. Heroes lacking the new payload retain the old readable palette for save/test compatibility.

Signature mechanics are streamlined spatial rules: **Rage** multiplies collision weight by 2.5, halves physical damage, and increases melee pressure; **Sneak Attack** requires melee range plus a flank/rear dot product or an already engaged target; **Wild Shape** enlarges radius, mass, speed, and melee pressure while adding temporary beast HP, with overflow applied to personal HP. **Fireball** is a circle, **Cone of Cold** a 60-degree sector, and **Lightning Bolt** a bounded piercing corridor. Each intersects oriented formations and independent heroes deterministically and sends damage through the existing aggregate HP/casualty pipeline.

After the field, `world.apply_hero_battle` writes back XP, wounds (`Wounded` + 6 months), capture (the champion's-chains hostage rule), or death. Hero-tier commanders skip the classic `_commander_fate` roll — personal HP already decided their fate. `ashfields_march` fields **Caeris himself**: Level 9 Legendary, School of the Unfinished, his three Legendary Actions live behind the Warden-Dead — and because his school never gates, the Ashfields' sky does not silence him on his own ground.

## 6. The canonical roster at Year Zero (doc §8, under the SRD rule)

**43 class-bearing heroes** stand at Year Zero; the continent carries ~348 with the unnamed `hero_pool` (inside the doc's 200–400 band; the pool drifts yearly, deterministically, toward the 500 steady-state cap). The figures Opus's §8 labeled with civil callings ("Level 5 Diplomat", "Level 8 Scholar") are now **their offices** — the SRD's answer, flagged for Opus in §9.

Class-bearers (highlights): Caeris the Unfinished (Wizard 9, School of the Unfinished, Legendary), Analinth Veldarin (Wizard 8), Ariorwe Thaladris (Bard 8, Carried Names, 120 names), Veril Ormand and Marek Vovel (Wizards 8, School of the Archive, combat 1/2), Halvar Stenn (**Cleric 7, Threshold Domain** — the Gravewarden is a domain, not a class), Grimhold Ironvault / Vossa Thaledrin (Fighters 6), Aldric Vaelmark (Paladin 6, Oath of the Vigil), Tess Mareck (Rogue 6, the Watchful), Bronvor Iron-Deep (**Wizard 6, School of Ward-Speech**), Odric Vasse (Wizard 5; Solvey/Draeth/Nym at 4), Marak Khorul (Wizard 5, Evocation), Maret (Wizard 5, School of the Unfinished — his one student), Dame Ilsen / Kaal Vor-Grathkaz / Garran / Vorak / Grimkar / Pellburn / Veldrin / Grim Vol-Gar / Carathwell (5s), **Drev Karn-Vol (Barbarian 4, Berserker, eager to deploy)**, the Reactionary clerics (Velmarin 6 and Mareldin 5 in the Reclaimed Rites; Veskren 4 and Youngric 3 in Life), Selene Tharn (Cleric 4, Life), Iliana Vesh (Bard 4, Carried Names, 40 names), Marek Voss (Paladin 4, Vigil), Halloran 4 / Davriand 3 / Kreth 3 / Anselm 3 (combat 1), Mira (Rogue 3, Thief), Tavisol (Paladin 3, Devotion).

Office-holders (no class, plenty of consequence): Queen Eithne, Princess Ilyra, First Voice Ferren, Counselor Selia, First Councilor Vessa, Master Envoy Verrik, Envoy Ren, Master Merchant Otter Straven, Lord Aldon Halven-Rothe, Baroness Vell Thornhardt, Baron Thelren of Dunmore, Secretary Sevrin, Archivist Thessaly (Chief Archivist at tick 44, by beat), and Sera — a Courtier, ordinary until the Vigil proves otherwise.

## 7. The player's hands on it

The commander's battle sheet names class/subclass, personal HP, tactical role and effective collision weight, plus active Rage or Wild Shape HP. The campaign's character pickers continue to label hero tier by compressed class level and everyone else by office.

## 8. Testing

`tests/hero_system_test.gd` preserves campaign integration, seeded canon, resource gates, wounds/death/capture and two-world determinism. `tests/single_entity_hero_test.gd` covers independent movement, no tunnelling, Rage mass/mitigation, Wild Shape transformation and overflow, Sneak Attack geometry, and circle/cone/line spell intersections. `tests/battle_ui_test.gd` covers actor/card selection and right-click movement in addition to cards, camera and casualty rendering. `tests/portrait_battle_parity_test.gd` proves exact portrait/field color parity, brown/green/blue palettes, ancestry cues, deterministic campaign handoff, and the legacy fallback.

Run focused: `Godot_v4.4.1-stable_win64_console.exe --headless --path . --script res://tests/single_entity_hero_test.gd`

All 16 prior suites stayed green unmodified through both passes — including the exact-canon tripwires (the Vigil's recipient and 80-month two-world determinism, religion's Y20 numbers, the magic census, the silence-made grey-country determinism).

## 9. Scoping notes for Opus (deviations & deferrals)

- **The SRD reinterpretation of §8's civil labels** (Justin's ruling): "Level 5 Diplomat" and kin are offices now, not classes — the fourteen civil figures hold positions and no chassis. If Opus wants any of them class-bearing later (Thessaly the obvious candidate), a beat can bless them — the machinery self-activates, and her named +500 XP award is already waiting at the desk.
- **The Khessari subclasses are Fable-drafted** to fill the SRD's one-per-class gap: the Unfinished, Ward-Speech, the Archive, the Threshold Domain, the Reclaimed Rites, the Oath of the Vigil, the Carried Names, the Brushgate Way, Clan-Sworn, the Watchful, plus three canon-awaiting stubs (Silence-Touched, the Patron of the Quiet, Beastwarden). All names, kits, and tunings are open to re-ruling.
- **Range picks stand from v1.0**: Caeris 9 / Analinth 8 (both "8-9"), Vossa 6 ("5-6"), Odric 5 over the other three magisters ("4-5").
- **Iliana Vesh carries 40 names without the Song-Marked trait** (`_bard_tick` draws an `mrng` die per singer; a guarded exemption can grant it later).
- **Hero-preference in AI commander assignment stays deferred** (a tie-break measurably moved the streams); the wound gate ships.
- **Carathwell and Thelren are not `cast_rulers`** — the Carath/Dunmore crown pass stays with Faction Cast v1.2.
- **Youngric Halden joins House Halden** (Anra's house, by find-or-create) — bless or rename.
- **AI heroes' Core Six never grow** (the stream discipline's cost); scheduled beats are the clean path for canonical growth.
- **Capture requires a live enemy realm**; marches on the Ashfields wound rather than capture — the Warden-Dead do not take prisoners, and Caeris files a complaint about the entire premise.
