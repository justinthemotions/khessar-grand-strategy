# The Hero System — Technical Briefing (v1.1, SRD-discipline pass)

This document covers the hero-tier character layer: distinguished individuals who can singlehandedly influence battles while remaining real diplomats, commanders, and decision-makers in the campaign. It implements Opus's design doc **"Khessar Grand Strategy — The Hero System (v1.0)"** (2026-07-08, Drive `1KJZwBXhxogVA5PmdgYJRcHpDFCbuRfAmSzJEUzTLJMg`), all seven phases of its implementation journey, **revised to the SRD 5.1 discipline** (Justin's ruling, July 2026): classes are the PC chassis — the SRD's eleven, exactly — and the setting's creativity lives in **subclasses**, never in new classes. Everyone without a chassis is an ordinary soul identified by **court position**, exactly as D&D runs its commoners and NPC templates. The static tables live in `scripts/hero_db.gd` (class `HeroDB`); the campaign layer in `scripts/world.gd`; the battle layer in `scripts/battle/battle_sim.gd`; the spell bar and targeting UI in `scripts/battle/battle_view.gd`. The test is `tests/hero_system_test.gd`. Written for onboarding: everything here reflects the actual code, with exact constants and formulas.

Two design laws govern everything below:

1. **Heroes amplify their armies; they do not replace them** (Opus's doc, first page).
2. **Not every soul has the potential for greatness** — most people are their office, not a class, ordinary until the day they pass, and that is fine. It is what makes the class-bearing few worth acquiring.

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

Hero fields on `SimCharacter`: `hero_level` (1–10), `hero_xp`, `hero_class` (one of the eleven), `hero_subclass` ("" resolves to the class's SRD subclass), `hero_hp`/`hero_hp_max`, `hero_combat_level` (field tier when it lags the craft: Anselm 1, Veril 1, Vovel 2), `hero_wounded_until`. Deployment styles (doc §6) in `world.hero_deploys`; the wound gate is enforced in `_assign_commander` and `set_commander`.

## 3. Levels and experience (doc §3)

Thresholds, verbatim: **0 / 500 / 1500 / 3500 / 7000 / 12000 / 20000 / 32000 / 50000 / 75000.** HP: 40 at level 1, +8 per level (112 at 10); Wizards and Sorcerers frail at 30, Paladins/Fighters/Rangers hearty at 50. Stat growth per level (doc's "Intelligence" = the Core Six's Intrigue): Wizard lrn/int, Sorcerer dip/lrn, Cleric dip/lrn, Paladin prw/dip, Druid lrn/prw, Warlock lrn/int, Bard dip/int, Monk prw/lrn, Fighter prw/mar, Ranger mar/lrn, Rogue int/prw.

XP hooks wired (awards in `HeroDB.XP_AWARDS`, doc ranges at midpoints): battles survived/won (+50/+100, by-hand), enemy hero killed (+300), Legendary Actions used (+100 each), Council votes (+25 per speaking magister), Council appointment (+200), the Chief Archivist succession (+500, by name — self-activates if the desk's holder ever bears a chassis), marriages/alliances arranged (+100/+150 to the crowns), dictated peace (+200), threshold rites (+40), quarterly carving (+30), bardic seasons (+25), research published (+200), the consent framework carried (+250, by-hand). None of the auto-firing awards can reach a threshold inside the canon-asserted horizons (verified two-world).

## 4. The eleven classes, and the subclasses where Khessar lives (doc §4)

`HeroDB.CLASSES` holds **exactly the SRD 5.1 eleven**: wizard, sorcerer, cleric, paladin, druid, warlock, bard, monk, fighter, ranger, rogue. Each carries `base_hp`, `growth`, and `practice` — which binary casting gate its workings roll (`arcane`, `faith`, `oath`, `primal`, or `""`).

The SRD provides **one subclass per class**; `HeroDB.SUBCLASSES` holds those (srd: true) plus **Khessar's own traditions** — this is the setting's creative shelf:

| class | SRD subclass | Khessari subclasses |
|---|---|---|
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

## 5. Heroes on the field (doc §7)

Unchanged from v1.0 in structure, now subclass-aware: `BattleSim.set_hero(side, world.hero_info(cid))` arms the class+subclass grants, the subclass's standing aura and tuning mods, and resolves the casting gate through `HeroDB.practice_for(class, subclass)`. The rest of the machinery: binary gates (fires whole or fizzles whole, cost lands either way), Counterspell interception, per-ability cooldowns plus a global window (10 combat ticks, **5 for Legendary** heroes at L8+, who also carry +1 use of everything and **Legendary Resistance**, 3 charges), effect primitives (aoe/line/multi/single/zone/timed/rally/shockwave/heal/hero-strike/dispel) through the standard damage pipeline, personal HP chipped by riding a bleeding host (prowess guards, Uncanny Dodge halves), death saves on the battle's own dice at 0 HP (3 fails = dead, 3 successes = stable), Death Ward, and a deterministic hero AI on both sides.

After the field, `world.apply_hero_battle` writes back XP, wounds (`Wounded` + 6 months), capture (the champion's-chains hostage rule), or death. Hero-tier commanders skip the classic `_commander_fate` roll — personal HP already decided their fate. `ashfields_march` fields **Caeris himself**: Level 9 Legendary, School of the Unfinished, his three Legendary Actions live behind the Warden-Dead — and because his school never gates, the Ashfields' sky does not silence him on his own ground.

## 6. The canonical roster at Year Zero (doc §8, under the SRD rule)

**43 class-bearing heroes** stand at Year Zero; the continent carries ~348 with the unnamed `hero_pool` (inside the doc's 200–400 band; the pool drifts yearly, deterministically, toward the 500 steady-state cap). The figures Opus's §8 labeled with civil callings ("Level 5 Diplomat", "Level 8 Scholar") are now **their offices** — the SRD's answer, flagged for Opus in §9.

Class-bearers (highlights): Caeris the Unfinished (Wizard 9, School of the Unfinished, Legendary), Analinth Veldarin (Wizard 8), Ariorwe Thaladris (Bard 8, Carried Names, 120 names), Veril Ormand and Marek Vovel (Wizards 8, School of the Archive, combat 1/2), Halvar Stenn (**Cleric 7, Threshold Domain** — the Gravewarden is a domain, not a class), Grimhold Ironvault / Vossa Thaledrin (Fighters 6), Aldric Vaelmark (Paladin 6, Oath of the Vigil), Tess Mareck (Rogue 6, the Watchful), Bronvor Iron-Deep (**Wizard 6, School of Ward-Speech**), Odric Vasse (Wizard 5; Solvey/Draeth/Nym at 4), Marak Khorul (Wizard 5, Evocation), Maret (Wizard 5, School of the Unfinished — his one student), Dame Ilsen / Kaal Vor-Grathkaz / Garran / Vorak / Grimkar / Pellburn / Veldrin / Grim Vol-Gar / Carathwell (5s), the Reactionary clerics (Velmarin 6 and Mareldin 5 in the Reclaimed Rites; Veskren 4 and Youngric 3 in Life), Selene Tharn (Cleric 4, Life), Iliana Vesh (Bard 4, Carried Names, 40 names), Marek Voss (Paladin 4, Vigil), Halloran 4 / Davriand 3 / Kreth 3 / Anselm 3 (combat 1), Mira (Rogue 3, Thief), Tavisol (Paladin 3, Devotion).

Office-holders (no class, plenty of consequence): Queen Eithne, Princess Ilyra, First Voice Ferren, Counselor Selia, First Councilor Vessa, Master Envoy Verrik, Envoy Ren, Master Merchant Otter Straven, Lord Aldon Halven-Rothe, Baroness Vell Thornhardt, Baron Thelren of Dunmore, Secretary Sevrin, Archivist Thessaly (Chief Archivist at tick 44, by beat), and Sera — a Courtier, ordinary until the Vigil proves otherwise.

## 7. The player's hands on it

Unchanged from v1.0, plus: the commander's battle sheet names the subclass under the class line, and the campaign's character pickers now label everyone — hero-tier as "— L5 Fighter", everyone else by office ("— Queen of Pellar", "— Master Merchant of the Salt Road"; plain Courtiers stay unbadged to keep the lists readable).

## 8. Testing

`tests/hero_system_test.gd` (8 groups, revised for v1.1): exactly eleven classes and the seven removed ids rejected; every class carries its SRD subclass and the nine Khessari traditions exist beside them; exclusive schools stand apart (the Unfinished at 9 knows exactly three workings and cannot throw a fireball — asserted twice, once in the tables and once at Caeris's own gate); practice overrides; the 43-hero instantiation with subclasses; the office rule (Eithne is "Queen of Pellar", Thessaly her desk, Sevrin his ledgers, Sera a Courtier, Otter his Salt Road — all at `hero_level 0`); the stream discipline; hero combat incl. Threshold/Vigil/Carried-Names behavior; death saves and Legendary Resistance; wounds and deployment gates; two-world determinism.

Run: `Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tests/hero_system_test.gd`

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
