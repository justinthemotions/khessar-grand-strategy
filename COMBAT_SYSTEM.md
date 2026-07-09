# Combat System — Technical Briefing

A complete description of the combat stack in the Khessar Grand Strategy prototype
(Godot 4.x, GDScript). Written for onboarding: everything here reflects the actual
code, with exact constants and formulas.

## 1. Design philosophy

- **Three-tier model.** (1) *Decorative soldiers* — the individual pixel men drawn in
  formation are pure rendering, they carry no state. (2) *Regiments* — the gameplay
  entity; all combat math happens per regiment. (3) *Heroes* — commanders are real
  characters from the dynasty layer (the same `SimCharacter` objects), so battle
  outcomes feed back into succession, memories, and stress.
- **Deterministic expected-value resolution.** No to-hit dice. Damage each tick is a
  continuous expected value; the only RNG in the whole battle layer is campaign-side
  (commander death rolls). Identical inputs always produce identical battles.
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
- `world.gd`: `UNIT_LABELS`, `UNIT_WEIGHTS` (levy 1.0, sword 1.4, cav 2.2, archer 1.2 —
  used for strategic strength), `RECRUIT_COST` (120/240/450/200 gold), `RECRUIT_SIZE`
  (48/36/16/24 men).
- `battle_sim.gd`: `PRESETS` (full battle stats, see §5).

**Recruitment** is capped by `levy_capacity(realm)` = effective province levies × tax-law
multiplier (+ Marshal bonus, tribal ruler bonus, legacies, interregnum penalty). Upkeep is
`0.05 gold/man/month` (× commander's `supply_consumption_mult` trait hook); regiments
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
cmdr_traits_a=[], cmdr_traits_b=[])` builds `Regiment` objects from the campaign rosters.
Each keeps a `roster_index` pointing back to its campaign entry so survivors can be
written back. `lead_bonus` is the commander's Martial stat: **leadership += martial × 0.5**
for every regiment on that side (leadership drives morale regen, §7).

Two clocks:
- **`move_step(delta)`** runs per frame: movement, facing, engagement locking, collision.
- **`combat_tick()`** runs every 0.5s (`TICK_SECONDS`): all damage and morale.

Interactive battles tick both from `BattleView._process`; **auto-resolve** calls
`run_headless()` — `move_step(0.1)` per frame, a combat tick + AI step every 5 frames,
both sides AI-controlled, same sim, instant result.

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
shock −= leadership × 0.03 per tick                                       # regen
flank_penalty = 20 while flanked, 40 while struck in rear (recomputed each tick)
```

At morale ≤ 0 the regiment **routs**: it flees toward its map edge at 1.35× speed and is
removed (`fled`) off-field. Routed units can't fight and don't rally. When one side has no
active regiments the battle ends; if both are empty simultaneously, `winner = -1`
(mutual ruin). Sudden mass casualties (a rear charge) can spike shock faster than
leadership regen can bleed it off — that's the hammer-and-anvil kill condition.

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

## 11. Aftermath

`main.gd._apply_battle_sim_results` (same path for fought and auto-resolved battles):
1. For each side, collect `{roster_index, soldiers, routed}` per regiment.
2. `SimWorld.apply_battle_casualties`: survivors overwrite the campaign roster; **routed
   units on the losing side lose a further 25% in the pursuit**; empty regiments are
   deleted; an army with no regiments is destroyed.
3. `SimWorld.apply_battle_result`: war score swings `20 + 30 × loser_loss` toward the
   winner; the beaten army retreats to its realm centroid; both commanders roll fate;
   |score| ≥ 100 forces peace.

## 12. Testing & debugging

- Headless run (from the project folder):
  `Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tests/headless_test.gd`
  — runs 60 years, auto-fighting every battle via `run_headless()`, plus static
  micro-battles asserting ranged damage, shield arcs, and trait hook application.
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
