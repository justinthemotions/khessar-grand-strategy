# The Faction Cast — Technical Briefing (v1.0)

The canonical Year Zero rulers of Khessar's map-only realms, made flesh:
real SimCharacters with faces, races, ages, courts, and answers to the
Silence — so the continent reads as *people, not territory*. Sim logic in
`scripts/world.gd` (the `Faction Cast` section); ruler labels in
`map_view.gd`; the test is `tests/faction_cast_test.gd`. Cast source of
truth: `KhessarMapData.REALMS`' canonical ruler strings (Faction Map v1.0).

## 1. Canon reconciliation (Opus's two questions, answered)

- **Osric Halvenard-Veil was seed-emergent**, not canon — a random draw
  from the Vael name pool at world seed 1066. The live founders now take
  their Faction Map names at setup: the Vael crown is **Garran
  Halvenard-Veil**, the clan chief is **Vorak Karn-Vol**. Pure renames
  (no dice touched), so the fixed-seed history is unchanged; the sim's
  rolled ages/stats stand (Garran shows 47, canon says 55 — flagged for
  the Gazetteer to reconcile whichever direction is preferred).
- **Zoran** was likewise pool-emergent; "Zoran Karn-Vol died at his own
  feast" in earlier test chronicles was a *different* Zoran of the
  house. Canon Vorak now wears the Year Zero crown.

## 2. Who is seated (all seven, plus their courts)

| Realm | Ruler | Race · Age | Court |
|---|---|---|---|
| Pellar | **Queen Eithne Vellian** (Zealous) | Human · 52 | daughter Ilyra (24, Learning 17); **Chief Archivist Marek Vovel** (71, Academy-Sworn) |
| Halven | **First Voice Ferren Crannock-Vey** (Pragmatic) | Human-Halveni · 58 | wife Selia (Half-Elf), daughter Mira (26, Half-Elf, Deceitful, Opportunistic — the Underground waits) |
| Vor-Grim Clan | **Chieftain Grimkar Vor-Grim** (Wrathful, Brave, Opportunistic) | Orc · 50 | — |
| Kharak-Dum | **King Grimhold Ironvault** (Ailing) | Dwarf · 82 | son **Prince Karth** (48, Learning 22+) |
| House Veldarin | **Matriarch Analinth Veldarin** (Purist, withdrawn) | Elf · 340 | — |
| House Thaladris | **Matriarch Ariorwe Thaladris** (Song-Marked, 120 names carried) | Elf · 285 | — |
| Saren-Vesh | **First Councilor Vessa Korren** (Opportunistic, prepared) | Human-Southern-Reach · 47 | — |

**Grand Magister Anselm Vorontheim is deferred**: realm 0 (the live
Magistocracy) is currently modeled through its noble houses, with the
Halvenard-Veil head wearing the crown as the feudal-behaving placeholder.
Anselm — and his scheduled Year Three poisoning, and the
Halloran/Davriand succession fight — arrives when the **Administrative
government module** makes a Grand Magister mechanically real. That is
the recommended next government type to build, per Opus's
prioritize-by-implementation suggestion.

## 3. The determinism contract

Everything cast rolls on a **dedicated seeded RNG** (`crng`, 555), and
the cast is guarded out of every main-stream loop that rolls dice per
character (deaths, births, bastards, auto-marriages, cadet branches, and
the magic event generators). Consequence: **zero reshuffle** — the
fixed-seed history and all prior suites pass unchanged. Cast mortality is
*scheduled*, not rolled: they are narrative scaffolding until their
government modules bring their realms fully live.

## 4. The scheduled canonical beats (Faction Map starting crises)

| When | Beat |
|---|---|
| Month 7 | **Pellar refuses the Magistocracy's "consultation"** — the first Vael/Free-Cities crack |
| Month 11 | **The grain fleets fail Halven** — the six houses in emergency session |
| Year 1 | Saren-Vesh's warehouses stand full — Vessa's unexplained foresight (Vovel's letters) |
| Year 2 | **The ward-stones of Kharak-Dum are going dark**, oldest first (Magic Injection tie-in) |
| Year 2½ | **Grimkar spits on the border compact** — the compact-breaker asks the clans what an unleashed north might take |
| Year 4 | **Grimhold dies as the ward-lights gutter** → the first Dwarven Interregnum of the Silence; Karth Ironvault, a scholar-king, crowned in the dark |

## 5. What reads on the map (the "who is what race" answer)

Race is rendered by metadata, exactly as Opus prescribed: every realm
label now carries its crown's **title + name** ("Matriarch Analinth
Veldarin", "Chieftain Grimkar Vor-Grim", "King Grimhold Ironvault") —
names and titles do the racial legibility work at map fidelity. Clicking
a cast realm's land opens its ruler in the character panel: portrait,
race line (Dwarf, Elf, Half-Elf), canonical title, stats, traits, and
their answer to the Silence. Banner-color and silhouette differentiation
remain open work for the art pass.

## 6. Scoping notes

- Cast realms fight no wars, sign no treaties, and answer no marriage
  brokers yet — that is the multi-realm engine work their government
  modules bring (Administrative → Anselm/Vael; Merchant Republic →
  Ferren/Vessa; Clan → the Matriarchs; a second Tribal realm → Grimkar).
  Each module can promote its cast realm from scaffolding to simulation.
- The cast *do* participate in the world's texture: they hold Silence
  Responses and practice traits (Ariorwe's names grow with the dead of
  her realm's provinces), appear in the chronicle, and are selectable
  characters.
- Free City-States Compact stays unruled (canonically a loose coalition);
  Carath (Duke Harrold Carathwell) and Dunmore (Baron Thelren Dunmoreth)
  remain string-only rulers — minor crowns, easy to seat in a v1.1 if
  wanted.
