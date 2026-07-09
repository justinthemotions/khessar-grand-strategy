# Titles, Land & Governments — Technical Briefing (Module 3)

How land is legally held in the Khessar Grand Strategy prototype. Map generation in
`scripts/world_map.gd`, rules in `scripts/world.gd`, UI in the Realm tab + map tooltip.

## 1. The map (`world_map.gd`)

A seeded, fictional continent: a 5×6 jittered lattice carved against a noisy ellipse —
~22 land provinces with 8-sided polygons, generated deterministically from its own RNG
seed (777) so the map never disturbs character-history RNG. Each `Province`:
`{id, name, owner (de facto realm), de_jure (rightful realm), held_since (tick),
duchy, polygon, center, tax (1.2–3.2), levy (12–35), neighbors[]}`.
Adjacency = lattice cells sharing an edge. Names from realm-flavored syllable pools.

## 2. The title pyramid

**County** (= province) → **Duchy** → **Kingdom** (= realm). Baronies wait for a
holdings layer (Module 3 Pass 2).

- Duchies (`_carve_duchies`): each realm's counties are split into 2–3 north-to-south
  bands; each duchy is named for its richest county ("Duchy of Hartmere") and keeps
  `county_ids`. Membership is de jure and never changes after generation.
- **Title holders** live in `world.county_holders` / `world.duchy_holders`
  (title id → character id), validated on read (`county_holder`/`duchy_holder` return
  null if dead/foreign). The crown implicitly holds everything ungranted.

`grant_title(kind, title_id, char_id)` — grants to living adults of the owning realm
(not the ruler, not denounced). `char_id = -1` revokes. Effects:
- Granted lord: +40 "granted me land" memory toward the ruler; his dynasty gains
  renown (+0.3/county, +0.8/duchy per month).
- Revoked lord: −50 "stripped my land" memory. Lords remember.
- **Escheat**: on the holder's death all titles revert to the crown (`_escheat_titles`,
  called from `_kill`). Hereditary lordships arrive with Module 4's vassal contracts.
- Conquest clears the county's holder (`_cede_border_province`).

## 3. Effective yields (why granting matters)

`realm_tax_eff(realm)` replaces raw province sums in the economy:
- A **granted county** yields `tax × (1 + lord.stewardship × 0.02)`.
- **Crown counties** beyond the admin cap yield 75% (`OVERREACH_YIELD`) — the cap is
  `4 + ruler.stewardship/5 + admin_cap_bonus trait hooks` (Bureaucrat +2), best
  counties administered first.
- Occupied foreign land yields 60% (§4).

`realm_levy_eff(realm)`: county lords add `martial × 0.5` men; a **duke** adds
`martial × 1.5 × (owned counties in the duchy)`. Feeds `levy_capacity` along with tax
law, Marshal bonus, legacies, tribal bonus, and the interregnum ×0.75 penalty.

## 4. De jure vs de facto

Conquest (`_cede_border_province`) moves **de facto ownership only**: `owner` changes,
`held_since = tick`, the local lord is dispossessed. While `owner != de_jure` the
province yields **60%** tax and levy (`FOREIGN_LAND_YIELD`) — "the people remember
older banners" (shown in the map tooltip). After **480 months (40 years)** of unbroken
holding, `_dejure_tick` flips `de_jure` to the occupier and logs that the old banners
are forgotten. Conquest is an investment, not an instant paint job.

## 5. Government paradigms (`GOVERNMENTS`, `Realm.government`)

- **Feudal** (Aldmark): power rests on contracts. Steady land yields; duchies and
  counties grantable as above.
- **Tribal** (Sarova): power is personal. Income ×0.75 ("herds and tribute, not
  ledgers and tolls"); **cannot grant duchies** ("power is personal, not legal");
  +15 flat AI aggression; levy capacity gains `ruler.martial × 6 + dynasty renown / 50`
  — a famous warlord fields a horde, a weak heir inherits a warband.

## 6. Economy summary (monthly, `_economy`)

```
income = (2 + realm_tax_eff) × tax_law_mult            (light 0.8 / moderate 1.0 / heavy 1.25)
       × (1 + Steward_seat × 0.015)
       × (1 + ruler.stewardship × 0.008)
       × ruler tax_efficiency_mult trait hooks          (Avaricious 1.10 / Altruistic 0.95)
       × 1.10 if Golden Ledgers legacy
       × 0.75 if tribal
       + 3 trade pact  − 4 at war
       × 0.6 during an interregnum
```
Tax law also trades levy capacity the other way (light ×1.15 … heavy ×0.85).

## 7. UI

- **Realm tab**: government line; demesne summary ("the crown holds N counties and
  administers M well", plus a conquered-land warning); Grant/Revoke controls (title
  picker with metadata `c<id>`/`d<id>`, grantee dropdown showing Stewardship/Martial);
  the full pyramid listing — duchies in gold with counties beneath, holders or "the
  Crown", lost counties marked.
- **Map tooltip**: county name, duchy, realm, tax/levy, lord if granted, and the
  de jure warning when occupied.

## 8. Hooks for future modules

- Module 4 (vassals): title holders are the proto-vassals — contracts, opinions
  feeding tax/levy ratios, and hereditary succession of titles land here.
- De jure mismatches are natural casus belli material (Module 5 diplomacy).
- `distance_decay_*` trait hooks (Paranoid, Bureaucrat) are declared in TraitData for
  Module 10's administrative-distance mechanics.
