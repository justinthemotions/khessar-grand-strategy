# Dynasty Base Layer — prototype

The smallest playable spine of the Crusader Kings layer: **time passes, characters
age and die, crowns pass to heirs** — with marriage, war, and trade as the three
player actions on top. Two realms, two noble houses each, ~20 characters at start.
Presented in a CK-style shell: character panel with **procedural genetic portraits**
on the left, a **fictional province map** in the middle, diplomacy and the
chronicle on the right.

## Run it

1. Open Godot 4.4+ → **Import** → select this folder's `project.godot` → Edit → press **F5** (Run Project).
2. The sim starts playing at 2 months/second. `Pause` / `Play` / `Fast` control speed.
3. Dev aid: running with `-- --screenshot` saves a UI screenshot to `user://` and quits.

## Portraits are math (genetics.gd + face_view.gd)

Every character carries a `genome`: continuous genes in 0..1 (skin tone,
undertone, hair color and texture, eye color, face width, jaw, chin, cheekbones,
nose, eye size and spacing, symmetry, brow, mouth, presence, severity, beard)
plus a discrete hair-style allele.
A child's gene is **mid-parent plus gaussian mutation**:

```
child = clamp( (father + mother) / 2 + N(0, 0.08), 0, 1 )
```

Faces are drawn as pure vector functions of the genome (no art assets), then
layered with realm, house, rank, traits, and age as a flat saga-illustration
treatment: angular face planes, bold cloak silhouettes, house marks, ruler trim,
tired eyes, harsher age lines, and occasional life scars. Beauty and menace are
read from inherited proportions plus traits, so one bloodline can produce a
radiant heir, a plain cousin, or a terrifying uncle without hand-authored art.
The same genome always produces the same face, family resemblance emerges from the
math, hair grays with age, and the beard gene only expresses on adult males.
Click any family portrait to inspect that character.

## The map (world_map.gd + map_view.gd)

A seeded, fictional continent: a jittered lattice carved against a noisy ellipse —
~22 named provinces (Thornholm, Krasomir, Hartmere…) split between the realms.
Provinces are real gameplay objects: their **tax** funds realm income and their
**levy** feeds war strength, and a decisive peace **cedes a border province** to the
winner, so wars visibly redraw the map. Hover a province for details; click it to
select its realm's ruler. Change the map seed in `SimWorld.setup()` for a new world.

## What to try

- **Watch a succession**: let time run until a ruler dies. The crown passes by
  male-preference primogeniture: eldest son → any dynasty member → any adult in the realm.
- **Arrange a cross-realm marriage** (pause first): the bride joins the groom's court,
  and the realms become **allied** — try declaring war and watch the council refuse.
  The alliance holds only while both spouses live.
- **Declare war** when unallied: war score drifts monthly with relative levy strength,
  nobles die in border skirmishes, and peace at a decisive score costs the loser tribute.
- **Sign a trade pact**: +3 gold/month each — and watch it get torn up when war comes.
- **Do nothing for 60 years**: the houses wither, because nobody marries unless *you*
  arrange it. Dynasties die without management — that's the game, but it also means
  the first real "AI" this project needs is characters arranging their own marriages.

## Field battles (battle_sim.gd + battle_view.gd)

When war is declared, **army banners appear on the campaign map** and march
toward the frontier each month. When they meet, the campaign pauses and a red
**"Fight the Battle of &lt;province&gt;"** button appears. The battle plays out on a
grass field in real time:

- **Three-tier model, live**: regiments are the gameplay entities; the individual
  pixel soldiers are pure decoration drawn in formation (frontage always faces the
  enemy). 4 regiments per side to start — cavalry, two sword, one levy — scaled by
  each realm's levy strength.
- **Left-click** selects a regiment (stat panel bottom-left: Armour, Leadership,
  Speed, Melee Attack/Defence, Weapon Strength, Charge Bonus, morale state).
  **Right-click** orders your (blue) regiments to move. Pause/Play/Fast top-right.
- **The resolver is the Regiment Combat Lab ported 1:1**: deterministic
  expected-value ticks, proportional armour, decaying charge impact, flank (1.5×)
  and rear (2×) arcs computed from real positions and facing, morale shock with
  leadership regen — battles end in routs, not annihilation.
- **The ruler is the commander**: their Martial stat buffs every regiment's
  leadership — the dynasty layer reaching into the battle layer.
- The outcome feeds back: a decisive slaughter swings the war score up to 50
  points; at ±100 the war ends, tribute + a border province change hands.
- **Right-drag draws a battle line**: the selected regiment reforms to that
  frontage (a wider line brings more men to bear via envelopment, but thins
  your depth) and holds that facing on arrival. Regiments are solid — allies
  keep spacing, enemies press to melee but never stack.
- **Enemy cavalry rides for your rear** before committing; engagement is
  sticky, so a unit pinned frontally keeps facing its foe while a second
  attacker hits the flank — hammer and anvil works.
- **Auto-resolve** hands the battle to AI captains on both sides — same sim,
  no rendering, instant result.
- Dev aid: `-- --battle-screenshot` runs straight into a battle and saves a png.

## Archers & shields

**Archers** are the fourth unit type: they loose deterministic expected-value
volleys at the nearest enemy in bow range (finite ammunition, shown on the unit
panel), skirmish on their own — kiting anything that closes, holding at range —
and fight poorly if caught in melee. Arrows arc visibly across the field.
**Shields** are a per-unit stat that blocks missiles *by facing*: full block
from the front, half from the flank, nothing from the rear — so getting archers
around a shieldwall's side is a real maneuver. (Melee parry stays inside Melee
Defence.) Sword infantry carry the heaviest shields, levies medium, archers none.

## Multiple armies & mortal commanders

Realms field up to **three independent armies**, always visible on the map with
their men-count. Click one to select it (gold ring), **right-click the map to
march it**; Split/Merge in the Military tab divides or rejoins hosts. New
recruits report to the army nearest your heartland. Each army is **led by a real
character** — the ruler first, then the realm's best martial minds — whose
Martial stat buffs its regiments. Commanders can **die in battle** (a beaten
commander especially; a slaughtered army's almost certainly), and if the king
falls at the head of his army, the succession fires on the spot. Hopeless
mismatches (4:1 or worse) don't spawn a battle — the smaller army is simply
ridden down.

## Persistent armies — the Military tab

Armies are no longer conjured per battle: each realm keeps a **standing roster**
of regiments. Battle survivors are written back after every fight (routed units
on the losing side are cut down further in the pursuit), so a won battle leaves
the enemy weaker *next* month — casualties compound into campaign momentum.
The **Military tab** shows your roster with live counts, levy capacity (set by
your provinces — losing land shrinks your army ceiling), recruitment (levy /
sword / cavalry for gold), and a rough read of the enemy muster. Regiments
replenish slowly for gold; upkeep drains the treasury per man. Sarova recruits
for itself.

## The Council — government by characters

Every realm has a four-seat council, each seat keyed to a stat and a real effect:
**Marshal** (Martial → +levy capacity, faster replenishment), **Steward**
(Diplomacy → +income), **Lawspeaker** (enables law changes; skill shortens the
debate), and **Spymaster** (Intrigue → plots and counter-plots). Appoint anyone
from the Council tab — one seat per person, the ruler can't sit on their own
council. Sarova staffs its council automatically by aptitude, and so does yours
at game start. Every character now has an **Intrigue** stat (inherited like the
others; Schemer and Honest joined the trait pool).

**Laws** are debated, not clicked: your Lawspeaker takes a proposal to the
council and 6–18 months later it becomes law. Taxation (light/moderate/heavy)
trades income against levy capacity; **succession law** (male-preference vs
absolute primogeniture) changes who actually inherits the crown.

**Plots**: point your Spymaster at any foreign character — 100 gold down,
5/month while the plot weaves. Progress and the final success roll pit your
Spymaster's Intrigue against theirs. Success reads "died suddenly in the
night… there are whispers of poison"; failure hangs your agents in the square.
**Sarova plots back** — usually against your ruler — so an empty Spymaster
seat is an invitation.

**Commanders are appointments too**: the Military tab now has a commander
dropdown per army — any living adult of the realm, one army each.

## Module 1 Pass 1 — the Character Engine (Khessar GS design doc)

- **The Core Six**: every character now carries Diplomacy, Martial, Stewardship,
  Intrigue, Learning, Prowess (0–30). Wired everywhere: Steward seat →
  Stewardship, Lawspeaker → Learning (debate speed), ruler Stewardship → income,
  Prowess → battlefield survival for commanders.
- **Categorized trait database**: personality (max 3, opposites excluded, carry
  AI decision weights), congenital (per-copy inheritance chances — Genius, Herculean,
  Frail…), health (Wounded from lost battles), coping (stress scars).
- **Stress & mental breaks**: acting against your nature (an Honest ruler
  ordering murder, a Compassionate one declaring war) builds stress; grief adds
  more; weddings, births, and victories relieve it. At 100/200/300 a break fires
  and leaves a coping scar (Drunkard, Reclusive, Irritable).
- **The Memory Log**: characters accumulate typed, decaying memories — weddings,
  invasions, battlefield defeats, being passed over for the crown, suspecting
  poison in a kinsman's death — and `opinion_of()` sums them with kinship.
  **Children inherit their parents' deepest grudges at half strength.** This is
  the substrate Module 4's vassal opinions will read.
- **Trait-driven AI**: Sarova now acts on her ruler's personality — a Wrathful,
  Ambitious ruler declares wars; a Deceitful one plots more; a Craven one sues
  for peace when losing.
- **Dynamic epitaphs**: notable dead are eulogized from their data — "remembered
  as the Spider, who watched every door."
- If a realm's line goes extinct, a distant kinsman is found and crowned.

## Module 2 Pass 1 — Dynasty, House & Inheritance (Khessar GS design doc)

- **Houses form a tree**: every noble house tracks a `parent_id`, and **cadet
  branches** split off on their own — a married, non-head kinsman with children
  (Ambitious men especially) founds "House Cedricson" or "House Zoranović" and
  takes his living descendants with him. The whole tree is one *dynasty*.
- **House Heads & the Dynasty Head**: each house has a computed head (crowned
  first, then eldest man); the senior head of all branches is the global
  Dynasty Head, whose word carries the powers below.
- **Renown**: a persistent dynasty currency, pooled on the founding house —
  earned monthly by members holding thrones (+3), council seats (+0.6), and
  army commands (+0.4), plus a bonus per living branch. Fame flows from power.
- **Dynasty Legacies**: permanent bloodline-wide perks bought with Renown from
  the Dynasty tab — Chronicled Deeds (+25% renown), Golden Ledgers (+10% income
  while ruling), Blood of the Wolf (children born +1 Martial/+1 Prowess, +8%
  levies), Unbending Oaths (+15 kin opinion, lighter stress). Sarova's ruling
  dynasty buys its own.
- **Dynasty Head Powers** (cost Renown; only usable when your ruler *is* the
  head): **Disinherit** strikes kin from the succession (they never forgive it),
  **Legitimize Bastard** raises a natural child to trueborn (their siblings
  never forgive *that*), **Denounce** brands a house criminal — stripped of
  every office, −30 opinion from all, unseatable — and **Call Dynasty to War**
  summons a sworn sword regiment from every branch of the tree.
- **Bastards**: noble men stray; a bastard joins the father's house but stands
  outside the line of succession until legitimized. Wives remember.

## Module 2 Pass 2 — Interregnum, Charters, Mythos, Bequests

- **The Interregnum**: no one rules at 12:01. On a ruler's death the heir
  stands *Claimant-Designate* through four staged months — sealing the
  treasury, winning the Lawspeaker's blessing, taking the **homage tour**
  (house heads who dislike the heir demand 60 gold before bending the knee) —
  while income runs at 60% and the levies at 75%. At the coronation feast, a
  **palace coup** may fire: any adult trueborn kinsman who was passed over,
  refused a bequest, or nurses a grievance can seize the crown outright if
  legitimacy is weak — or hang for treason if the rising fails.
- **House Charters**: cadet splits are legal acts now. **Loyalist** stays in
  the renown pool and binds the family +10 opinion; **Co-Equal** takes a
  100-renown endowment and answers to no one; **Schismatic** — born of a
  grievance — tears free and swears a **Blood Feud** (−40 opinion) that lives
  on the house files forever, outliving every soul now living.
- **The House Mythos file**: bloodlines are *known* for things. Three acts of
  kin-cruelty brand the house **Kin-Eater** (−10 opinion from all outsiders);
  two successful assassinations make them **Whispered Poisoners** (shunned
  abroad, but plots weave 15% faster); forty unbroken years on a throne earns
  **Blood of Kings** (+5 opinion from everyone, +1 renown a month). Tags are
  permanent and inherited by every child born.
- **Wills & Bequests**: buy a younger child's peace for 150 gold before the
  crown passes. The content ones will never rise; the Ambitious may take the
  purse coldly and nurse the grievance anyway — and you won't know which until
  the coronation feast.

## Module 3 Pass 1 — Titles, De Jure Land & Governments

- **The title pyramid**: County (province) → **Duchy** (2–3 named regions per
  realm, seated at their richest county) → Kingdom. Titles are grantable from
  the **Realm tab**: a lord runs his county better than a stretched crown
  (+2% tax per Stewardship; the crown only administers ~4 counties well),
  a duke marshals extra levies across his whole region, and both make their
  dynasty famous. Granted lords are grateful (+40 memory); **revoking is
  remembered** (−50). Titles escheat to the crown on death — hereditary
  lordships arrive with Module 4's vassal contracts. Baronies wait for the
  holdings layer.
- **De jure vs de facto**: conquest moves *de facto* ownership only. Occupied
  land yields 60% tax and levy — "the people remember older banners" (see the
  map tooltip) — until **de jure drift** assimilates it after 40 years of
  unbroken holding.
- **Governments**: Aldmark is **feudal** (contract-steady yields, titles to
  grant); Sarova is **tribal** — leaner taxes, no dukes ("power is personal,
  not legal"), naturally more aggressive, and its levies swell with the
  ruler's Martial and the dynasty's Renown. A famous tribal warlord fields a
  horde; a weak one, a warband.

## The Event Framework & Traits-as-Hooks

- **Choice events**: the sim now asks instead of telling. A house head
  demanding gold at the Homage Tour, a mind at its breaking point (pick the
  scar: wine, seclusion, or rage), a Spymaster's warning of a half-woven
  foreign plot (pay for guards, bait a trap, or dismiss it) — each pauses the
  game and opens a popup. Every NPC decision runs through the same pipe:
  **the decider's traits score the options** (aggression, scheming, greed,
  patience weights per option), so a Wrathful ruler refuses the bribe and a
  Patient one pays it. New events from any future module just call
  `raise_event()`.
- **Traits are systemic hooks now, not stat blocks** (`trait_data.gd` +
  `trait_db.gd`): every trait is a `TraitData` Resource carrying Core Six
  modifiers, AI behavioral weights, and *named engine hooks* that subsystems
  query at the point of effect. Live today: **Impulsive** commanders' cavalry
  hits 25% harder but their armies bleed 10% more and they die more often;
  **Methodical** lines stand firmer, panic less, and consume less supply;
  **Stoic/Mercurial** shift baseline cohesion; **Avaricious** rulers squeeze
  +10% tax; **Paranoid** targets slow hostile plots 40% and detect them more
  often; **Bureaucrats** administer two extra crown counties; **Altruistic**
  characters are simply liked. Hooks for guild concessions, heresy spread,
  decadence, and distance decay are declared in the data and light up when
  Modules 8–10 land.

## Dynasty autopilot: auto-marriage and traits

Characters left unmarried past 25 now find matches within their realm, so the
world sustains itself without micromanagement (the player still brokers the
strategic cross-realm marriages). Characters also carry up to two **traits**
(Brave, Craven, Shrewd, Cruel, Ambitious…) that modify Martial/Diplomacy, are
visible on the character sheet, and **run in families** — each parent trait has
a 35% chance to pass to a child.

## Architecture notes (the part that matters for the bigger game)

- **`scripts/world.gd` (SimWorld)** is the entire simulation: pure data + rules, zero
  Nodes, zero UI. It can run headless — see `tests/headless_test.gd`:

  ```
  Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tests/headless_test.gd
  ```

- **`scripts/character.gd` (SimCharacter)**: every cross-reference (spouse, parents,
  children, ruler) is an **integer id**, never an object reference. This is the
  save/load discipline decided on day one — serialization later is just dumping dicts.
- **`scripts/save_load.gd` (SaveLoad)** cashes that day-one check: a save is a
  reflective walk over SimWorld's script variables (RNG streams round-trip
  seed + state; the map re-generates from its seed and re-applies mutable
  province fields). Saves live in `user://saves/`; the title menu's Continue
  loads the newest, a yearly autosave runs unbidden, and saving is refused
  while an event decision is pending (option effects are Callables and cannot
  cross a file). See `tests/save_load_test.gd` — a loaded world must advance
  bit-identically to one that never left memory.
- **`scripts/main.gd`** is UI only. It reads SimWorld and calls its action methods;
  it never mutates simulation state directly.
- **The battle-layer seam is marked**: `SimWorld._skirmish_death()` is where abstract
  war attrition gets replaced by real battles. A character's `martial` already feeds
  levy strength; the same character object becomes a battle commander later.
- **Deterministic**: fixed RNG seed (1066) in `setup()` — every run is the same
  history until you change the seed. Change it for a new world.

## Deliberately not here yet

Opinion/relationship systems, character AI, events, council, plots, religion, a map,
save/load, more than two realms. Each is a bolt-on to this spine, not a rewrite.
