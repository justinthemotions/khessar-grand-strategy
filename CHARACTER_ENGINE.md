# Character Engine — Technical Briefing (Module 1)

How a person works in the Khessar Grand Strategy prototype (Godot 4.x, GDScript).
Everything below reflects the actual code.

## 1. Design philosophy

- **Data drives narrative.** Characters are pure data (`SimCharacter extends RefCounted`);
  every dramatic beat — epitaphs, grudges, coups — is *generated from* stats, traits, and
  memories, never scripted.
- **Integer IDs everywhere.** Every cross-reference (spouse, parents, children, ruler,
  title holders, memories) is an integer id into `SimWorld.characters`, never an object
  reference. This is the save/load discipline: serialization later is just dumping dicts.
- **The same character object crosses layers**: a courtier can be a council seat, an army
  commander, a title holder, a plot target, and an heir simultaneously.

## 2. SimCharacter fields (`scripts/character.gd`)

- Identity: `id, name, dynasty_id (house), realm_id, is_female, birth_tick, alive`
- Family: `spouse_id, father_id, mother_id, children_ids[], last_birth_tick`
- Status flags (dynasty layer levers): `is_bastard, disinherited, denounced,
  aggrieved` (nurses a claim), `bought_off` (accepted a bequest)
- **The Core Six** (0–30): `diplomacy` (negotiation, opinion), `martial` (command,
  levies), `stewardship` (income, admin reach), `intrigue` (schemes, spy defense),
  `learning` (law debates, later tech/faith), `prowess` (personal lethality,
  battlefield survival)
- `traits: Array[String]` — keys into TraitDB
- `stress: float`, `stress_level: int` (0–3 breaks suffered)
- `memories: Array` — the Memory Log (§6)
- `genome: Dictionary` — heritable appearance genes (§8)
- `age_years(tick)` — age from `birth_tick` (tick = months since Jan 1066)

## 3. Stat generation and inheritance

- Founders: each Core Six stat rolled uniform 3–16 (`_roll_stats`).
- Children: `mid-parent ± rng(−3..+4)`, clamped 1–30 (`_blend_stats`), then trait stat
  mods apply on top. Trait inheritance is separate (§4).
- Births happen monthly for married women 16–45 (3.5%/month, 18-month cooldown).
  Bastards: adult men have 0.003/month chance to father a child with an unmarried
  woman of the realm — child joins the father's house, `is_bastard = true`, excluded
  from succession until legitimized.

## 4. Traits (`trait_data.gd` + `trait_db.gd`)

Every trait is a `TraitData` **Resource**: identity (name, category, opposite, eulogy),
`inherit_chance`, Core Six `stats` mods, **AI behavioral weights** (`ai`), and **named
systemic hooks** (`mods`) queried by subsystems at the point of effect.

Categories and rules (enforced by `_can_add_trait` / `_add_trait` in world.gd):
- **personality** — max 3 per character (`PERSONALITY_CAP`), mutually exclusive with
  their `opposite`. Inherit at 30% per parent copy; children are guaranteed at least 2;
  3% mutation chance adds a random congenital. Includes the classic dispositions
  (Brave/Craven, Honest/Deceitful, Ambitious/Content, Cruel/Compassionate,
  Wrathful/Patient, Gregarious/Shy) and the system-native ones
  (Methodical/Impulsive, Stoic/Mercurial, Avaricious/Altruistic, Paranoid, Bureaucrat).
- **congenital** — genetic; each parent copy rolls its own `inherit_chance`
  (Genius 0.20, Quick 0.30, Slow 0.25, Herculean 0.25, Frail 0.25, Comely 0.30, Homely 0.25).
- **health** — acquired (Wounded from lost battles, Ailing).
- **coping** — stress-break scars (Drunkard, Reclusive, Irritable).

AI weight axes (`ai_weight(c, axis)` sums across traits): `aggression`, `scheming`,
`greed`, `patience`, `orthodoxy` (dormant until Module 9). These drive Sarova's war
declarations, plot frequency, peace-seeking, and every event option choice.

Systemic hooks are read via `trait_mult(c, key)` (product) and `trait_add(c, key)` (sum).
Live keys: `tax_efficiency_mult`, `admin_cap_bonus`, `supply_consumption_mult`,
`commander_risk_mult`, `intrigue_defense_mult`, `court_opinion_baseline`, plus the
battle-grid keys (see COMBAT_SYSTEM.md §10). Declared-but-dormant keys exist for
Modules 8–10 (guilds, heresy, decadence, distance decay).

## 5. Stress & mental breaks

`add_stress(c, amount, reason)` — acting against your nature has a price:
- Contradiction triggers: an Honest ruler starting a murder plot (+30), Compassionate
  (+25); Compassionate declaring war (+15); grief (widowed +15, child's death +20,
  +10 more if Compassionate); defeat in battle (+25); a coup at your feast (+25/+40).
- Relief: weddings (−10), births (−5), victories (−10), and a monthly decay of 1.5
  (+0.5 if Patient, +0.5 with the Unbending Oaths legacy).
- Crossing `(stress_level+1) × 100` fires a **mental break**: stress −60, level +1
  (max 3), and a **choice event** picks the coping scar — Drunkard / Reclusive /
  Irritable (player chooses for realm-0 characters; trait AI decides for everyone else).

## 6. The Memory Log & opinion

`add_memory(c, type, subject_id, value, decay_per_year)` — typed, decaying opinions of
other characters, capped at 30 entries. Notable producers: weddings (+40), child born
(+30), invaded my realm (−40), defeated me in battle (−25), passed over for the crown
(−30), granted me land (+40), stripped my land (−50), cast out of the succession (−60),
suspects poison (−40, applied to a plot victim's kin *without proof*), a bastard shames
me (−20), stole my crown (−80).

`opinion_of(a_id, b_id)` = kinship base (spouse +25, parent/child +20, same house +5)
+ dynasty-tree effects (Unbending Oaths legacy +15; loyalist-branch bond +10;
**blood feud −40**) + Mythos tags of b's bloodline (Kin-Eater −10 from outsiders,
Whispered Poisoners −10 abroad, Blood of Kings +5) + `court_opinion_baseline` trait
hooks + denounced −30 + Σ decayed memories, clamped ±100.

**Grudge inheritance**: when a character dies, every memory ≤ −40 passes to their
living children at half value (`inherited grudge`). Hatreds outlive the dead.

## 7. Death, succession, epitaphs

- Mortality: base 0.0004/month, +0.002 under age 5, + (age−45)² × 0.00004 past 45.
- On death: spouse/parents take grief stress, grudges pass to children, titles escheat
  to the crown, and **notables get an epitaph** generated from their data:
  highest stat → epithet ("the Spider", "the Warlike"...) + first trait with a eulogy
  line ("who watched every door").
- Ruler death fires `_succession`: heir by law (male-preference or absolute
  primogeniture; bastards and the disinherited excluded), extinct lines rescued by a
  spawned distant kinsman — then the **Interregnum** begins (see DYNASTY_SYSTEM.md §7).

## 8. Genetics & portraits (`genetics.gd` + `face_view.gd`)

Every character carries a `genome`: ~18 continuous genes in 0..1 (skin, undertone,
hair color/texture, eye color/size/spacing, face width, jaw, chin, cheekbones, nose,
symmetry, brow, mouth, presence, severity, beard) plus a discrete hair-style allele.
Inheritance: `child = clamp((father+mother)/2 + N(0, 0.08), 0, 1)` per gene.
Faces are drawn as pure vector functions of the genome (no art assets) in a flat
saga-illustration style, layered with realm, house, rank, traits, and age.
NOTE: `face_view.gd` and the genetics gene list are **user-authored art code** — do not
rewrite them; `set_person(genome, age, female, context={})` is the stable interface.

## 9. Marriage

`marry(groom, bride)` validates: alive, adult (16+), unmarried, opposite sex, not close
kin. The bride joins the groom's court (realm changes, house doesn't). **Cross-realm
marriages create an alliance** that blocks war while both spouses live. Auto-marriage:
unmarried men 22+ find same-realm matches on their own (6%/month), so the world
sustains itself; the player brokers the strategic matches.

## 10. Gotchas

- GDScript: values pulled from untyped Dictionaries/Arrays are Variant — `var x := c.foo`
  fails to infer; always type loop vars (`for r: Regiment in regiments`) and locals.
- Fixed RNG seed (1066) in `setup()`: any change to earlier RNG consumption (new traits,
  new rolls) reshuffles the entire deterministic history.
- Trait stat mods are applied when the trait is added — removing a trait does not
  currently reverse them (no removal path exists yet).
