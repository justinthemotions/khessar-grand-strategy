# Combat System — Technical Briefing (v1.1, Tactical Combat System pass)

A complete description of the combat stack in the Khessar Grand Strategy prototype
(Godot 4.x, GDScript). Written for onboarding: everything here reflects the actual
code, with exact constants and formulas. §14 documents the Tactical Combat System
v1.0 pass (Opus's doc, 2026-07-08): binary casting gates, Silence-terrain combat,
threshold-work, the Order / Ashfields / Forsaken units, terror, vigour, and the
deterministic critical layer.

## 1. Design philosophy

- **Three-tier model.** (1) *Decorative soldiers* — the individual pixel men drawn in
  formation are pure rendering, they carry no state. (2) *Regiments* — the gameplay
  entity; all combat math happens per regiment. (3) *Heroes* — commanders are real
  characters from the dynasty layer (the same `SimCharacter` objects), so battle
  outcomes feed back into succession, memories, and stress.
- **Deterministic expected-value resolution.** No to-hit dice. Damage each tick is a
  continuous expected value; the only RNG in the whole battle layer is campaign-side
  (commander death rolls) plus the battle-local casting-gate stream (§14.1).
  Identical inputs always produce identical battles.
- **Morale decides battles, not annihilation.** Units rout when morale hits zero;
  battles typically end with the loser at 40–60% casualties, not 0%.
- **Casualties persist.** Survivors are written back to the campaign roster, so a lost
  battle weakens every following month — attrition compounds into campaign momentum.

The math was tuned in a standalone HTML "Regiment Combat Lab" simulator and ported 1:1.

## 2. File map

| File | Role |
|---|---|
| `scripts/world.gd` (SimWorld) | Campaign layer: armies, marching, war score, recruitment, casualty write-back, commander fate |
| `scripts/battle/battle_sim.gd` (BattleSim) | The resolver: pure RefCounted, no rendering, runs headless |
| `scripts/battle/battle_view.gd` (BattleView) | Rendering + player input for interactive battles; owns a BattleSim |
| `scripts/trait_db.gd` / `trait_data.gd` | Trait hooks that modify battle behavior (see §9) |
| `tests/headless_test.gd` | Auto-fights battles during a 60-year sim; micro-tests for ranged/shields/trait hooks |

## 3. Campaign layer (world.gd)

**Armies** (`SimWorld.Army`): `{id, realm_id, pos (normalized 0..1 map coords), target,
regiments: [{kind, soldiers, max}], commander_id}`. Up to **3 armies per realm**;
split/merge supported. New recruits report to the army nearest the realm centroid
(`muster_army`).

**Unit kinds** exist in TWO tables that must both be updated when adding a kind:
- `world.gd`: `UNIT_LABELS`, `UNIT_WEIGHTS` (~cost/200, used for strategic strength),
  `RECRUIT_COST`, `RECRUIT_SIZE`, and `UNIT_UPKEEP` for kinds priced above the flat rate.
- `battle_sim.gd`: `PRESETS` (full battle stats, see §5).

There are **29 kinds**: the universal roster (levy 120g / sword 240g / cav 450g /
archer 200g, open to every realm), **20 cultural specialty kinds** from the
Cultural Roster v1.0 (see §10b), and **5 Tactical Combat System kinds** — the Order,
Caeris's forces, and the Forsaken militia (see §14.3).

**Recruitment** is capped by `levy_capacity(realm)` = effective province levies × tax-law
multiplier (+ Marshal bonus, tribal ruler bonus, legacies, interregnum penalty), and
culture-gated for specialty kinds (`recruit_gate`, §10b). Upkeep is `0.05 gold/man/month`
for the universal roster and per-kind (`UNIT_UPKEEP`, up to 0.15 for the Arcane Retinue)
for cultural units, × commander's `supply_consumption_mult` trait hook; regiments
replenish toward `max` at ~8%/month for 0.3 gold/man while the treasury allows.

**Engagement**: each month at war, armies march 0.10 map units toward their targets.
When hostile armies come within **0.05**, the campaign locks into `battle_ready` with
`pending_battle = [army_a_id, army_b_id]` and waits — the war score freezes until the
battle is fought (interactive or auto-resolve). Exception: a **4:1 size mismatch is an
overrun** — no battle, the smaller army is destroyed outright, ±15 war score.

**War score** drifts monthly by `10 × (strength_A − strength_B) / (strength_A + strength_B)
± rng(2)`, clamps at ±100 which forces peace. A fought battle swings it by
`20 + 30 × loser_loss_fraction` toward the winner. Decisive peace (|score| > 40): loser
pays up to 80 gold tribute and **cedes a border province** (de facto only — see the
de jure system).

**AI (Sarova)**: her armies march at the nearest enemy army in war, home in peace. She
recruits when gold > 700. Aggression is trait-driven (+15 flat for tribal government).

## 4. Battle pipeline

`BattleSim.setup_from_rosters(roster_a, roster_b, lead_bonus_a, lead_bonus_b, side_names,
cmdr_traits_a=[], cmdr_traits_b=[], terrain="plains", ground={})` builds `Regiment`
objects from the campaign rosters.
Each keeps a `roster_index` pointing back to its campaign entry so survivors can be
written back. `lead_bonus` is the commander's Martial stat: **leadership += martial × 0.5**
for every regiment on that side (leadership drives morale regen, §7).

Two clocks:
- **`move_step(delta)`** runs per frame: movement, facing, engagement locking, collision.
- **`combat_tick()`** runs every 0.5s (`TICK_SECONDS`): all damage and morale.

Interactive battles tick both from `BattleView._process`; **auto-resolve** calls
`run_headless()` — `move_step(0.1)` per frame, a combat tick + AI step every 5 frames,
both sides AI-controlled, same sim, instant result.

## 4b. The battle interface: the unit card bar (`battle_view.gd`)

A Total War-style card bar runs along the bottom of the battle screen, drawn
immediate-mode in `_draw` like everything else in the view:

- **The hero card** comes first (present when `sim.commanders[0]` is set): gold-framed,
  crown notch, plumed portrait. Clicking it (`commander_selected`) turns the bottom-left
  panel into the commander's sheet — name (`_cmdr_info` now carries `world.full_name`),
  Martial/Intrigue/Prowess, traits, faith, oath-token state, and the battle's running
  stress/corruption ledgers. **Hero System v1.0**: when the commander is hero-tier
  (`world.hero_info` non-empty, passed via `sim.set_hero`), the card's band shows the
  level tag with a red personal-HP strip beneath, the sheet adds class/level/HP and
  DOWN/dead states, and a **spell bar** of the hero's field orders docks above the card
  bar — targeted casting with a reach preview under the cursor. Zones burn on the field;
  workings flash where they land. Full mechanics in HERO_SYSTEM.md §5-7.
- **One card per side-0 regiment**: remaining men over a green strength band
  (`soldiers / start_soldiers`), a gold morale strip, an orange ammunition strip for
  missile units (`ammo_start` records the starting pouch), the unit's own pixel soldier
  as a portrait, and an **archetype glyph** in the TW-style bottom notch —
  `_card_archetype` maps silence (`silence_kind`, a skull) / cavalry / caster
  (`ward_shield`) / support (`aura_lead > 0`) / missile / spear (`bonus_cav ≥ 10`) /
  sword, in that priority order.
- **States on the card**: gold `»»` while charging; a white flag over a greyed card
  when routed; a near-black shade and a skull once the regiment is dead or fled.
  Cards persist after death, TW-style.
- **Clicks**: a card click selects its regiment exactly like clicking the field (gold
  frame + bottom-left panel); every other click inside the bar is consumed so strays
  never reach the grass beneath. A right-drag order already in progress completes even
  if the button lifts over the bar. Hovering a card names it above the bar.
- **Geometry** lives in `_card_layout()` — a pure function of `size` + sim state
  (cards shrink below 54px when the line outgrows the window), so the headless suite
  asserts layout and click routing without a renderer.

## 5. Unit stats (`PRESETS`)

| stat | levy | sword | cav | archer | meaning |
|---|---|---|---|---|---|
| soldiers | 48 | 36 | 16 | 24 | default company size |
| hp | 8 | 10 | 16 | 7 | HP per man (damage pool = soldiers × hp) |
| armour | 4 | 12 | 20 | 2 | proportional damage reduction (§6) |
| ma / md | 22/26 | 32/32 | 38/28 | 14/14 | melee attack / defence (hit chance) |
| ws | 8 | 11 | 13 | 6 | weapon strength (damage per hit) |
| charge | 6 | 10 | 34 | 3 | decaying attack+damage bonus on impact |
| lead | 35 | 50 | 65 | 35 | leadership (morale regen) |
| files | 12 | 9 | 8 | 12 | formation width (frontage = files × 7px) |
| speed | 26 | 30 | 60 | 32 | px/s |
| bonus_cav | 12 | 0 | 0 | 0 | levy spears get +12 ma vs cavalry |
| shield | 0.30 | 0.45 | 0.20 | 0.05 | frontal missile block fraction |
| range/ammo/missile | — | — | — | 230px / 40 / 9.0 | bow range, volleys, missile strength |

The 20 cultural presets follow the same schema plus optional special keys, absent by
default: `never_routs_above` (Berserkers 0.25), `panic_resistance` (Brushgate 0.60),
`silence_immunity`, `ward_shield` (Arcane Retinue — shield works at every arc),
`aura_lead`/`aura_range` (Ward-Speakers +10/200px, Song-Bound +8/180px),
`forest_bonus_ma`/`forest_bonus_speed` (Forest-Sworn +8/+12), `coastal_bonus_ma`
(Marines +6). Stat blocks are 1:1 from the Cultural Roster v1.0 document.

The Tactical Combat System pass (§14) brings the count to **29** with five new kinds
(`vigil_sworn_elite`, `reactionary_chaplain`, `warden_dead`, `caeris_retinue`,
`forsaken_militia`) and new special keys: `silence_immunity` now accepts a 0..1 float
(the Order's 0.60 ward vs Brushgate's full `true`), plus `no_morale`, `silence_terror`,
`silence_kind`, `defensive`, `oath_bound`, `conviction_lead`, `aura_filter`, and
`vigour_mult`.

## 6. Melee math (per combat tick)

For attacker `r` engaged with target `t`:

```
engaged_count = min(r.files_now, t.files_now × 1.4, r.soldiers, t.soldiers)   # envelopment
ma = r.ma (+ bonus_cav if t is cavalry)
ws = r.ws (+ bonus_cav × 0.5 if t is cavalry)
charge (first 10 ticks after impact, linear decay):  ma += charge_bonus × decay
                                                     mult ×= 1 + (charge_bonus / 20) × decay
arc multiplier: flank ×1.5, rear ×2.0                (see §8 for arc geometry)
hit  = clamp(0.35 + (ma − t.md) × 0.02, 0.08, 0.90)
per_hit = max(ws × 35 / (35 + t.armour),  ws × 0.15)   # proportional armour, 15% chip floor
damage → t = engaged_count × 0.12 × hit × per_hit × mult
```

(Since the Tactical Combat pass, ma/ws/md also wear the fatigue penalty, and `mult`
carries the Khessari layer: silence-born ×1.05 on their own ground, confusion ×0.7,
oath-conflict ×1.10, threshold-work ×1.20 vs the Silence-born, and the EV critical
layer — see §14.)

Damage accumulates in a `dmg` dictionary and is applied simultaneously at the end of the
tick (no first-strike advantage): `hp_pool −= damage × dmg_taken_mult`, then
`soldiers = ceil(hp_pool / hp_per)`.

Key behaviors this produces:
- **Envelopment**: a wider line brings up to 1.4× the enemy's frontage to bear — wide
  formations beat narrow ones frontally, but are thinner against flank charges.
- **Armour is proportional** (pivot 35), so ws 13 cavalry still chips ws×0.15 minimum
  through anything.
- **Charges matter most for cavalry** (charge 34 ≈ +170% damage on impact, decaying over
  5 seconds) and also add +10 morale shock to the target on contact.

## 7. Morale

```
morale = 100 + morale_bonus − shock − flank_penalty − depletion
depletion = (1 − soldiers/start_soldiers) × 70
shock += (casualties_this_tick / soldiers_before) × 160 × shock_mult      # casualty shock
shock += 10 on being charged
shock −= effective_leadership × 0.03 per tick                             # regen (see §14.4)
flank_penalty = 20 while flanked, 40 while struck in rear (recomputed each tick)
```

At morale ≤ 0 the regiment **routs**: it flees toward its map edge at 1.35× speed and is
removed (`fled`) off-field. Routed units can't fight and don't rally. When one side has no
active regiments the battle ends; if both are empty simultaneously, `winner = -1`
(mutual ruin). Sudden mass casualties (a rear charge) can spike shock faster than
leadership regen can bleed it off — that's the hammer-and-anvil kill condition.
Exceptions since the Tactical Combat pass: Berserkers above their oath threshold,
`oath_bound` regiments whose commander's token is whole, and `no_morale` Returned
(§14.4).

## 8. The positional model (what makes tactics real)

- **Facing** is a real vector. Engaged units face their foe; idle units turn toward the
  nearest threat *slowly* (slerp at 1.8/s), so facing is a commitment.
- **Arcs** from the defender's facing: `d = normalize(def.pos − att.pos) · def.facing`;
  `d > 0.5` → rear (×2.0 damage, −40 morale), `d > −0.5` → flank (×1.5, −20), else front.
- **Sticky engagement**: a regiment keeps fighting its current foe while in contact
  (`engaged_id`), so a unit pinned frontally holds facing while a second attacker hits
  the flank — hammer and anvil works because the anvil can't turn.
- **Collision** (`_separate`): regiments are solid. Allies keep 0.9× combined radius,
  enemies compress to 0.55× (melee press) but never stack.
- **Player orders** (interactive only): left-click select, right-click move; right-DRAG
  draws a battle line — the regiment reforms to that frontage (files change, trading
  width vs depth) and holds that facing on arrival (`hold_facing`).
- **Battle AI** (`ai_step`): unengaged infantry marches at the nearest enemy; **archers
  skirmish** — kite anything inside 110px, advance to 90% of bow range, hold there;
  **cavalry rides for a rear point** behind the nearest enemy infantry
  (`prey.pos − prey.facing × (radius + 80)`) before committing.

## 9. Ranged fire & shields

Archers loose one volley per combat tick when: not in melee, ammo > 0, target within
230px. Expected-value like melee:

```
block = target.shield × SHIELD_ARC_FACTOR[arc]        # front 1.0, flank 0.5, rear 0.0
per_hit = max(missile × 35/(35 + armour), missile × 0.15)
damage = shooters × 0.06 × 0.35 × per_hit × (1 − block)
ammo −= 1   (40 volleys total)
```

Shields only block missiles **by facing arc** — full from the front, half flank, nothing
rear — so maneuvering archers around a shieldwall is a real tactic. Melee parry is
already inside `md`. Volley visuals are consumed from `sim.volleys` by the view.
Arcane volleys (ward-shield retinues) strike Silence-born targets at ×1.4 (§14.3).

## 10. Commanders and trait hooks

The commander is a real dynasty character:
- **Martial** buffs every regiment's leadership (+0.5/point → morale regen).
- **TraitData battle hooks** (passed as `cmdr_traits` at setup, side-wide):
  - `vanguard_damage_mult` (Impulsive 1.25): cavalry `ws` ×.
  - `center_line_defense_mult` (Methodical 1.15): non-cav `md` ×.
  - `casualty_rate_mult` (Impulsive 1.10): all damage *taken* ×.
  - `panic_resistance` (Methodical 0.25): casualty shock × (1 − value).
  - `levy_cohesion_baseline` (Stoic +15 / Mercurial −10): flat morale bonus.
- **After the battle**, `SimWorld._commander_fate` rolls death:
  `chance = 0.04 if won else 0.15 + 0.20 × loss_fraction`, then
  `× clamp(1.4 − prowess × 0.03, 0.5, 1.4)` (Prowess keeps you alive) and
  `× commander_risk_mult` (Impulsive 1.15). Survivors of a defeat take +25 stress, a
  −25 memory of the enemy commander, and a 25% chance of the *Wounded* trait. If a
  ruler dies at the head of the army, succession (and the Interregnum) fires immediately.

## 10b. The culture system (Cultural Roster v1.0)

Culture is martial tradition, not blood. `scripts/data/culture_data.gd` holds the twelve
cultures of Khessar (Vael, Aelindran, Free City, Halveni, Drevak, Karn-Vol, Kharak-Dum
Dwarven, Brushgate, Veldarin, Thaladris, Southern Reach, and the dead Sovereignty) with
their specialty unit rosters, marriage acceptance tables, government compatibility,
traditions, and syncretism affinities (the last three are designer data until their
modules land).

- **Province majority culture** (`Province.culture`) derives from the map region plus
  canonical exceptions: four Vael counties (Veilkeep, Marling Fields, Voss-Hold,
  Caer Velmond) are Aelindran noble countryside, Halven is Halveni, Karn-Vol land is the
  Karn-Vol subvariant, the Aurath ruins keep the dead Sovereignty culture.
- **Recruit gating** (Design Decision A): `SimWorld.recruit_gate` allows a specialty kind
  only if the realm holds a province of its culture (`CultureData.KIND_CULTURE`).
  Karn-Vol land satisfies parent-Drevak requirements; the Brushgate Column is anchored to
  Dwarven land (monastery access). Unavailable kinds are hidden from the muster panel.
- **Compact-Sworn** dissolve the moment war breaks between the realms (`declare_war` →
  `_dissolve_compact_sworn`) and cannot muster during it.
- **Character culture** (`SimCharacter.culture`): the simulated Vael court is
  Aelindran-cultured (the great houses), the border clan Karn-Vol. Cross-culture
  weddings apply the symmetrized acceptance modifier as a spousal memory.
- **Trade-Guard** companies add +15 to their realm's plot-detection roll while mustered.
- **Battle terrain**: `setup_from_rosters(..., terrain)` receives the battle province's
  terrain (`SimWorld.battle_site_terrain`); forest and coast wake the terrain bonuses.
- **Sovereignty units** (Draconic Breath-Sworn, Sovereignty-Guard, Song-Warden) are
  dormant names in `CultureData.DORMANT_UNITS` for the late-game Pale Court arc.

## 11. Aftermath

`main.gd._apply_battle_sim_results` (same path for fought and auto-resolved battles):
1. For each side, collect `{roster_index, soldiers, routed}` per regiment.
2. `SimWorld.apply_battle_casualties`: survivors overwrite the campaign roster; **routed
   units on the losing side lose a further 25% in the pursuit**; empty regiments are
   deleted; an army with no regiments is destroyed.
3. `SimWorld.apply_battle_result`: war score swings `20 + 30 × loser_loss` toward the
   winner; the beaten army retreats to its realm centroid; both commanders roll fate
   and collect the field's corruption and stress ledgers; |score| ≥ 100 forces peace.

## 12. Testing & debugging

- Headless run (from the project folder):
  `Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tests/headless_test.gd`
  — runs 60 years, auto-fighting every battle via `run_headless()`, plus static
  micro-battles asserting ranged damage, shield arcs, and trait hook application.
- `tests/culture_roster_test.gd` validates the culture data, all 20 cultural presets,
  recruit gating, the Compact-Sworn dissolution, auras, the Berserker oath, terrain
  bonuses, and Brushgate panic resistance.
- `tests/tactical_combat_test.gd` (13 groups) validates the Tactical Combat System
  v1.0 layer: the five new kinds, every binary reliability gate against doc §3's
  numbers, oath-routing, Warden-Dead morale/terror/dispersal, silence-ground regen,
  the reap-vs-threshold interaction, the Chaplain aura filter, conviction and
  oath-conflict arming, vigour, arcane fire vs the Returned, full Order-vs-Warden-Dead
  auto-battles, battle determinism, and the campaign recruit gates.
- `tests/battle_ui_test.gd` (6 groups) validates the unit card bar (§4b): layout
  geometry, the archetype glyph mapping, click routing (unit cards, the hero card,
  consumed bar clicks), remaining-men/ammunition tracking, the commander panel, and
  card shrinking on narrow windows — all headless, via `_card_layout()`.
- `tests/hero_system_test.gd` (8 groups, Hero System v1.0) validates the hero layer's
  battle half here: ability gates and cooldowns, Fireball through the standard damage
  pipeline, fizzle-whole on grey ground, the paladin aura in `_aura_tick`, faith-gated
  healing, death saves, Legendary Resistance, and battle determinism with heroes live.
- Visual check: `--path . -- --battle-screenshot` boots straight into a battle and saves
  a PNG to `user://`.
- The sim is deterministic given the same rosters; campaign RNG uses a fixed seed (1066),
  so changing anything that consumes RNG earlier (e.g. adding traits) reshuffles history.

## 13. Known gotchas for future work

- Adding a unit kind requires **both** `battle_sim.PRESETS` and the three `world.gd`
  UNIT tables — missing one throws "Invalid access to property or key".
- `run_headless` has a 30,000-frame safety cap; if neither side can win it awards the
  side with more survivors.
- Regiment `files` is fixed per preset except when the player drag-orders a new frontage.
- The battle layer plugs into the campaign at `SimWorld._skirmish_death` (abstract
  attrition still runs alongside battles) and `pending_battle` (real battles).
- Module 7's planned expansions (battle grid lanes, baggage trains, tactical cards like
  *Commit the Reserve* / *Chivalric Charge*) will extend `BattleSim` — the trait hooks
  for them (`panic_resistance`, vanguard/center mults) are already in TraitData.

## 14. Tactical Combat System v1.0 — the Khessari layer

Implements Opus's "Khessar Grand Strategy — Tactical Combat System (v1.0)" doc
(2026-07-08). The TW-derived Combat Lab backbone (§6–§9) is preserved untouched;
everything below plugs into it. Test: `tests/tactical_combat_test.gd` (13 groups).

### 14.1 The determinism contract, extended

The doc demands **binary reliability gates** — a working fires whole or fizzles whole,
never "40% damage." Gates need dice, and the engine's law is *no dice on the field*.
Resolution: a battle-local stream, `brng` (seed **212**), seeded at every
`setup_from_rosters`. Identical setups still produce identical battles (asserted in the
test), and no campaign stream is ever consumed by the field. A die is drawn **only when
the gate is genuinely uncertain** — reliability 1.0 and 0.0 consume nothing, so open and
closed gates never shift the stream.

### 14.2 Binary casting gates (`casting_reliability`, doc §3)

Rolled once per working at `set_commander_info`; the ground arrives from the campaign as
`battle_site_ground()` = `{silence, ruined, special}` alongside the terrain string.

| practice | detector | gate | on success | cost (always) |
|---|---|---|---|---|
| arcane (Wizard) | `arcane_channel_mult > 1` + a ward-shield retinue fielded | 1.0 ordinary / 0.5 silence-touched (0.6 untrained) / 0.0 Ashfields & ruins — **Corruption Mark III casts anywhere** | retinue `missile ×` channel mult | stress +0.5; sorcerers +0.15 corruption (+0.5 on fizzle) |
| faith (Cleric) | `Faith-Practicing` | dampening 0.30 base / 0.10 silence / 0.60 ward-stone / 0.80 Iron Library, × response (Zealous 1.15, Pragmatic 0.85, Opportunistic 0.70, Broken 0.60) | *Bless*: +4 ma / +2 md to the foot | stress +2; **+5 more on an unanswered prayer**. Presence (+5 lead, +8 Zealous) applies regardless — the office is presence first |
| primal (Druid) | `primal_channel_mult > 1` | terrain table: forest/wetland/river 1.0, plains/hills 0.9, coast 0.8, mountain 0.6, **0.0 silence/ruins/elsewhere** | the full footsoldier ma boost (no longer scaled by ground — binary) | stress +0.85 |
| oath (Paladin) | `Oath-Sworn` + `oath_token_intact` (now passed in commander info) | 1.0 with the token whole, 0.0 broken/Oathbreaker | Aura of Devotion: +8 lead, +2 md, regen ×1.25; **arms `oath_holds` on Order regiments** | none — oaths don't Silence-degrade |
| corruption (Warlock) | `corruption_channel_mult > 1` | **always 1.0** — the Patron operates in Silence-adjacent space | setup terror on enemy lines (now scaled by 1 − silence_immunity) | +1.5 corruption ledger |
| song (Bard) | `song_aura_baseline` | 1.0 (the army is the audience) | names-scaled morale (unchanged) | — |
| discipline (Monk) | `discipline_binding_mult > 1` | 1.0 (the body is not casting) | shock ×0.90 **and vigour ×0.85** | — |

The tactic cards gate too: *Uncontrolled Channel* rolls the arcane gate (fizzle = +0.5
corruption, nothing else); *Reap the Bargain* never gates (§3.6) but is **halved against
a side whose commander is Gravewarden-Sworn** and scaled by each line's
`1 − silence_immunity`. `commander_stress` feeds back to the campaign next to
`commander_corruption` via `apply_battle_result`.

### 14.3 The new units (doc §5.12–5.14)

| kind | the point | specials |
|---|---|---|
| `vigil_sworn_elite` (380g) | the Order's blade — devastating in defense | armour 18/md 34/lead 65, panic_res 0.45, **silence_immunity 0.60** (the Order's ward, not Brushgate's), `oath_bound` |
| `reactionary_chaplain` (360g) | the litany at the rear | aura +12 lead / 300px, **`aura_filter: "order"`** — reaches only Order regiments |
| `warden_dead` (0g) | Caeris's Returned | **`no_morale`** (morale() pins at 100 — dispersed, never broken; below 25% strength strikes at ×0.7 *confusion*), **`silence_terror` 0.30**, `silence_kind`, `defensive` (AI never marches them), arcane volleys strike them at ×1.4 |
| `caeris_retinue` (0g) | her Settled, when she takes the field | silence_immunity 1.0, `silence_kind` |
| `forsaken_militia` (200g) | conviction instead of drill | `conviction_lead` +8 morale, armed when the enemy fields Order units or an Orthodox commander |

Recruit gates: Warden-Dead and the Retinue are never musterable ("these dead are not
yours"); Forsaken militia is structurally gated off until the Forsaken-movement module
lands; Vigil-Sworn kinds answer only a **Zealous Aelindran Orthodox ruler** (interim
gate — the Order as an institution isn't modeled yet, flag for Opus).

### 14.4 Silence on the field (doc §6–§7)

- **Silence-touched ground** (`ground_silence`, incl. the Ashfields): every line's
  morale regen loses 8 effective leadership × (1 − silence_immunity). The Brushgate
  Column literally does not notice. Silence-born units (`silence_kind`) deal ×1.05
  under their own sky.
- **Silence terror**: within 150px of a `silence_terror` unit, morale regen is starved
  by the terror fraction × (1 − immunity) — halved again if a Gravewarden-Sworn hand
  commands the side.
- **Threshold-work** (doc §4): a Gravewarden-Sworn commander gives the side
  shock ×0.85 (deaths properly witnessed) and ×1.20 damage against `silence_kind`
  units; holds reap-shock at half; the Threshold Rejection Ritual proper stays
  campaign-side (world.gd, Module 9).
- **Oath-conflict** (doc §5.12): Order regiments strike at ×1.10 against Silence-born
  rosters or a commander of the Reformed / Silent Path (armed at setup from the
  rosters, or at the map table from the enemy commander's faith).
- **Routing**: `oath_bound` regiments whose commander's token is whole **cannot rout**
  (the check is skipped, like the Berserker oath); `no_morale` units never rout and
  never take casualty shock.

### 14.5 Vigour and the critical layer

Vigour (doc §8, engine-scaled): +1.0/combat tick in melee, +0.35 marching, +1.0 extra
charging, × unit `vigour_mult` (Brushgate 0.60, discipline commander ×0.85). Stages at
30/60/95/130 → −5/−10/−15/−20% on ma, ws, md, and march speed. TW's 30k-point scale was
folded to this sim's ~100–250-tick battles; percentages preserved.

Criticals stay expected-value (no dice): damage × (1 + crit_chance/4), with
crit_chance = 5% base, +5% under a Brushgate-Trained commander, +3% for an Oath-Sworn
commander facing a Corruption-Mark-II+ enemy commander.

### 14.6 AI extensions (doc §9)

`defensive` units hold ground and let the war come to them. Chaplain-type units
(melee aura bearers) shadow the strongest friendly line instead of leading the advance.
Units with silence_immunity ≥ 0.6 (Brushgate, Vigil-Sworn) march for the nearest
Silence-born enemy first — that is what the discipline structurally exists for.

### 14.7 Scoping notes for Opus (deviations & deferrals)

- **Warden-Dead damage typing**: the doc's "Physical damage 1.0x, magical damage 0.3x"
  contradicts its own parenthetical ("resistant to conventional, vulnerable to
  threshold-work and arcane"). Implemented the parenthetical's intent: physical ×1.0
  as written, arcane volleys ×1.4, threshold-led sides ×1.2 — the literal 0.3x is
  unimplemented pending clarification.
- **Named spells** (Arcane Bombardment, Turn Undead, Entangle, Name the Dead, Sit With
  the Manifestation…) are folded into the practice-level workings — this sim resolves
  commander-scale effects, not per-spell targeting. The attack-roll/saving-throw split
  and mana economy from the source doc's D&D bridge are deferred with them.
- **Canonical commanders** (Aldric Vaelmark, Dame Ilsen, Brother-Captain Voss, Caeris
  herself, the Warlock woman) await their factions reaching the map; Caeris's commander
  block (terror 0.50, corruption_channel 1.60) is specified but unseeded.
- **Defensive-only deployment** of Caeris's forces is battle-AI truth; the campaign
  trigger ("deploys only when the Ashfields is threatened") needs Caeris's realm.
- **Hollow Shade emergence** from silence-touched province deaths is campaign wiring
  deferred to the endgame Silence cascade (v1.1 queue in MAGIC_AND_SILENCE.md).
- **Fatigue on reload** (TW's −20% exhausted reload) is unmodeled — volleys are
  per-tick, not per-reload.
- **Ceremonial concordance** (faith dampening 1.00) has no battle trigger yet — it
  needs the Module 9 ceremony events to reach the field.
