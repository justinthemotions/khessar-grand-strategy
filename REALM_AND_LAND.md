# Titles, Land & Governments — Technical Briefing (Module 3)

How land is legally held in the Khessar Grand Strategy prototype. Map generation in
`scripts/world_map.gd`, rules in `scripts/world.gd`, UI in the Realm tab + map tooltip.

## 1. The map (`world_map.gd` + `data/khessar_map_data.gd`)

The hand-authored continent of **Khessar**, traced from Justin's Khessar_mapv2
illustration: 60 provinces in 8 west-east bands between hand-drawn boundary polylines,
assembled deterministically (seed 777 touches only generated names and border jitter,
never character-history RNG). Each `Province`:
`{id, name, owner (de facto realm, -1 = unclaimed), de_jure, held_since (tick), duchy,
polygon, center, tax (1.2–3.2), levy (12–35), neighbors[], terrain, coastal,
cultural_region, silence_touched, ruined, special_feature}`.
Adjacency comes from the band tables, then a blocklist severs the Carath mountain wall
(two passes only: Ashford, Marn's Crossing) and seals the deep Elven forests to 2–3
gate provinces per house. Names from nine cultural-region syllable pools
(`data/province_name_pools.gd`); canonical settlements (Vael, Pellar, Kharak-Dum,
Saren-Vesh, Durn…) are hand-placed and reserved.

**Twelve realm records** (`WorldMap.MapRealm`, per the Faction Map at Year Zero v1.0)
carry name, government, capital, founding house, and named Year Zero ruler — only
realms 0 (Magistocracy of Vael) and 1 (Karn-Vol Clan) are simulated live; the rest are
setting data until later modules. Uncontrolled land: the Ashfields (silence_touched,
Durn is Caeris's seat), the Aurath ruins (ruined), and two sealed Dwarven holds
(ruined = LOCKED, not dead). The calendar is the Silence calendar: tick 0 =
"Year 0, Month 1 of the Silence". Allocation: Vael 18, free cities 12, Drevak orcs 8
(Karn-Vol + Vor-Grim), dwarves 4, elves 6 (Veldarin/Thaladris), southern reach 5,
Ashfields 4, Aurath 3. The canonical Halvenard-Veil / Aurath-Voss blood feud is live
from setup inside the Vael court.

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

- **Feudal** (Pellar, Carath, Dunmore, Kharak-Dum): power rests on contracts. Steady
  land yields; duchies and counties grantable as above.
- **Administrative** (Magistocracy of Vael), **Merchant Republic** (Halven, Saren-Vesh,
  the Compact), **Clan** (the Elven houses): placeholder strings on the realm records —
  they behave feudal until their modules land.
- **Tribal** (Karn-Vol, Vor-Grim): power is personal. Income ×0.75 ("herds and tribute, not
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
