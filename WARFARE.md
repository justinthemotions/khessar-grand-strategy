# Warfare & Combat Mechanics — Technical Briefing (Module 7)

How the Khessar Grand Strategy prototype makes war cerebral: armies that
must eat, wagons that can be hunted, walls that starve before they storm,
commanders who play cards on the field, and peasants who will burn their
own fields before feeding an invader. Campaign logic in `scripts/world.gd`;
field logic in `scripts/battle/battle_sim.gd`; UI in `main.gd`,
`map_view.gd`, and `battle_view.gd`; the test is
`tests/warfare_module_test.gd`.

## 1. Supply Limits & Starvation Attrition

Every county has a **Supply Limit** set by terrain (`SUPPLY_BY_TERRAIN`:
river valleys feed 480, plains 380, mountains 110, the Ashfields 90).
Salted land feeds at 40%; **scorched land feeds no one**. An army on its
own intact soil is fed by the realm's granary network regardless of size —
the limit bites *abroad*, under occupation, or on ruined ground, where an
oversized host starves monthly (`clampf(0.02 + 0.04 × overload)`, capped
12%). **Winter** (months 12–2) doubles attrition on foreign soil.

## 2. The Baggage Train & the Severed Line

The moment an army stands on foreign soil in war, it trails a **physical
Baggage Train node** on the map, drawn on the road back toward the nearest
friendly county. If an enemy army rides onto the wagons — or the county
has partisan cells — the line of communication is **Severed**:

- no reinforcements reach the army (`_military_upkeep` skips it),
- compounding starvation (4% + 1% per month severed),
- −2 battle leadership per severed month (starving men fight poorly).

A small, fast army can break a doomstack without ever offering battle:
loop behind, sit on the wagons, and let the winter do the killing.

## 3. Sieges, Strongholds & Occupation

An army encamped on an enemy county with no enemy field army within reach
opens a siege. Progress accrues monthly (base 6 + Marshal/2) against a
threshold of `100 + fort level × 25` — fort level from terrain (mountains
+2, hills +1), special features, and capital seats (+2). The recurring
siege event timer rolls **breaches** (+15 progress) and **camp fever**
(the besieger loses 4%). At the threshold the county falls **occupied**:
war score swings ±10, and the county pays its crown *nothing* — no taxes,
no levies — until the peace. At the drafting table (Module 5), every
occupied county adds +5 leverage, and **cession takes occupied counties
first**. Occupations march home at war's end.

## 4. The Battle Grid: Interactive Combat Ticks

Battle already runs on the flank-arc regiment model (Combat Lab). Module 7
adds the **command tent**: once-per-battle tactical orders gated on who
the commander actually is (`set_commander_info` / `tactic_gate` /
`use_tactic`):

| Order | Requires | Effect |
|---|---|---|
| **Feigned Retreat** | *Deceitful* or Intrigue 12+ | the enemy's flank-most melee formation is lured out of line — attackers strike it at flank rates while the lure lasts, and the exposed enemy center takes shock |
| **Commit the Reserve** | *Patient* or Martial 12+ | the rearguard's shock clears, it gains +15 cohesion and marches for the worst-shaken friendly line, lifting 25 shock off it |
| **Chivalric Charge** | *Wrathful* or Prowess 12+ | the cavalry (or hardest hitters) doubles its charge and ×1.3 weapon strength, but takes ×1.25 casualties — and the commander's post-battle fate rolls run at ×1.8 |

The AI plays its own cards on deterministic cues (bait early, charge when
locked, reserve when a line wavers) — a commander without the temperament
simply never does. In the BattleView, grey buttons carry tooltips saying
exactly what the commander lacks.

## 5. Levy Morale & the Cascade Panic Matrix

When a formation breaks and runs, every friendly **levy** regiment within
170px takes cascade shock: `max(8, 30 − commander martial × 0.8)`,
scaled by the unit's own panic resistance. Professional squads hold.
A single flank collapse can dissolve an army of conscripts even at two-to-
one odds — unless someone worth following is holding the center.

## 6. Scorched Earth & Partisan Networks

A **defender** (never the realm that declared the war) may invoke the
Scorched Earth Protocol on its own *de jure* counties: `scorch_earth()`
burns the crops and fouls the wells. For five years (`SCORCH_MONTHS`):

- the county's Supply Limit is **zero** — any army parked there starves,
- its tax and levy yield drop to 40% (a self-inflicted wound),
- **partisan cells** rise: they sever any invader's baggage train in the
  county and freeze siege progress to nothing.

The four-phase play from the design doc emerges from the parts: salt the
wells (scorch), partisan raids (auto-severed trains), the Winter Trap
(doubled attrition), and **Strike the Exhausted Host** — a defender giving
battle on mountain or scorched ground against an invader bled below half
its war-start strength gets +8 leadership. Karn-Vol's AI burns its own
frontier when Vael marches on it.

## 7. Knights & Champions

The realm's three highest-Prowess adults (after commanders are seated)
ride with the main host as **champions**: pooled prowess/6 becomes battle
leadership. After every field battle each champion rolls a fate — death,
a wound, or on a lost field **capture**: the champion enters the enemy's
court as a hostage ward (Module 5), ransomable at the standard price.

## 8. UI & Scoping Notes

- Military tab: encampment supply, train state, sieges/occupations/
  scorched counties, winter warnings, the champions, and the Scorch the
  Earth action. The map draws wagons (red when severed), siege progress
  rings, occupation shading, and ash over burned counties.
- Siege engines (trebuchets) wait for their Men-at-Arms slot in the
  roster; the rock-paper-scissors counter system already lives in the
  Combat Lab stat blocks (bonus-vs-cavalry, armour pivots, shield arcs).
- Champions fight as leadership + fate rolls, not yet as individual
  grid units; that upgrade rides with a future battle pass.
- The emergent fixed-seed history reshuffles again (armies now starve,
  besiege, and occupy); headless statistics all hold unchanged.
