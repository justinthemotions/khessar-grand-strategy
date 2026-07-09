# Intrigue, Secrets & Subterfuge — Technical Briefing (Module 6)

The underground rule engine of the Khessar Grand Strategy prototype: how
information becomes leverage, how murders are assembled rather than rolled,
and how a discovered plot becomes a weapon in the defender's hand. Sim logic
in `scripts/world.gd`; UI on the Intrigue tab of `scripts/main.gd`; the test
is `tests/intrigue_module_test.gd`.

## 1. Secrets

The world accumulates leverage on its own (`secrets`): acknowledging a
bastard records **bastard blood**; a successful assassination records **a
murderer's hand**; a completed seduction records **a secret affair**. A
secret is inert until a court *knows* it.

**Ferreting** (`start_ferreting`, 30 gold): the Spymaster's informants roll
`0.10 + intrigue×0.012` monthly to surface a random unknown secret — in any
hall, including the crown's own vassals'. They give up after 18 dry months.

## 2. Hooks — programmatic leverage

A known secret becomes a **hook** (`hooks`): *weak* for bastardy, *strong*
for murder and affairs. Weak hooks spend on use; a strong hook is a lifetime
of leverage. Hooks are wired straight into earlier modules:

- **The Curia** (Module 4): a hooked lord's vote is forced to *aye* —
  `curia_vote` flips any non-supporting hooked stance. Wars have been carried
  on blackmail alone.
- **Feudal contracts** (Module 4): `hook_force_contract` mandates harsher
  tax/levy terms with **no tyranny gained and no grudge memory** — the lord
  signs without a word.
- **Plot assets** (§3): a hook on the chosen inside agent subverts them free
  of charge.
- Failed plots hand the *victim's* realm a strong hook on the plotter —
  caught red-handed is leverage too.

## 3. The Anatomy of a Trap — component murder plots

`start_plot` still opens one plot per realm, but the single progress bar is
now four phases:

| Phase | At | What happens |
|---|---|---|
| 1 — Infiltrate | 0–33 | the Spymaster maps the household's routine |
| 2 — The Asset | 33 | the sharpest courtier near the target is bought (40 gold) or hooked (free) — a cupbearer, food taster, chamberlain… |
| 3 — The Vector | 66 | nightshade from the market, or whatever the Apothecary Lab brewed |
| 4 — The Strike | 100 | **player-triggered**: strike now, or hold for an open window (the target realm's interregnum, up to 24 months) |

Strike odds: `0.30 + (spymaster − theirs)×0.02`, +0.10 with an asset inside
the walls, **+0.20 during the target's interregnum** (chaos is an unguarded
kitchen door), **×0.2 against a Mithridatic target**. Failure costs 150 gold,
20 prestige, "plotted my death" memories — which now also feed the Module 5
**Redress of Grievances CB** — and that strong hook for the victim.

## 4. Double Agents — the Subversion Matrix

When the victim's court catches wind of a plot (the existing warning event),
a new option appears once the plotter's asset is placed: **turn their agent**
(`0.40 + intrigue difference`). The plot walks on, apparently healthy — but
when it strikes, the *defender* chooses the ending:

- **The Switcheroo** — the plotter drinks their own vintage: the vector they
  paid for is applied to them, at their own feast.
- **Expose the plot** — read aloud before both courts: −30 prestige for the
  plotter, a strong hook and a "sent knives after my kin" memory for you.

## 5. Minor schemes — slander, seduction, abduction

One quiet scheme per realm (`start_minor_scheme`, 60 gold), woven monthly,
detectable once past the halfway mark (−20 prestige if dragged into
daylight):

- **Seduction**: the ruler takes a foreign lover — +40 opinion, and the
  affair is a **strong hook** on them forever.
- **Abduction**: the target vanishes and reappears under guard as a
  **hostage ward** (Module 5) — abduct the heir and their realm cannot
  declare war.
- **Slander: the False Lineage**: forged monastery pages name the target
  bastard-born — the realm's lords take memories against them, and if they
  ever open an interregnum, they start it **25 legitimacy short** (coup
  country).
- **Slander: the Manufactured Vice**: planted evidence forces a public trial
  in the target's own court — condemn them (stripped of office and standing)
  or stand by them (50 gold, and a coin-flip chance the forgers are named).

Karn-Vol's AI weaves its own: a slandered heir is cheaper than a war.
*(The Fabricated Cowardice slander waits on Module 1 Pass 2's Facade system —
there is no Perceived Martial score to tank yet.)*

## 6. The Apothecary & Poison Ecosystem

`establish_apothecary` (80 gold) digs a hidden room and appoints the most
learned unlanded courtier (learning 10+) as Alchemist — officially, a
physician. The lab sets the plot's vector:

- **Nightshade** (default, no lab needed): kills; leaves whispers, suspicion
  memories, and the Whispered Poisoners mythos count.
- **The Slow Weep**: the perfect crime — the target gains the **Wasting**
  trait (×4 monthly mortality, −2 prowess) and fades like consumption. No
  whispers, no suspicion, no secret recorded, no mythos.
- **The Mad Mind**: the target survives; their sanity does not — **Paranoid**
  plus a full stress break.

**Mithridatization** (`toggle_mithridatism`, 2 gold/month): the ruler takes a
drop of poison with every dawn meal; after 24 months the **Mithridatic**
trait is permanent, and every poison vector against them works at one-fifth
strength. No cup can kill them now.

## 7. UI (Intrigue tab)

The web at a glance: the current plot's phase and components, informants in
the field, schemes weaving, the lab and its current brew, the morning-draughts
clock, and every hook held — with a force-harsh-terms button beside any
hooked vassal of the crown. Strike windows, turned-asset choices, switcheroo
endings, and vice trials all arrive as choice-event popups.

## 8. Scoping notes & hooks

- Fabricate Claim (the doc's fifth scheme) already shipped in Module 5's CB
  system; Romance-as-distinct-from-Seduction is folded into seduction.
- Slander effects run on real variables (legitimacy, memories, offices); the
  full Facade/Perceived-stats layer remains Module 1 Pass 2.
- The smuggler's *physical* traversal to fetch venom (map-tile travel risk)
  waits for an agent-travel layer; Phase 3 abstracts it through the lab.
- Secrets currently have three sources; Module 9's faiths (deviancy, heresy)
  and Module 8's guilds (embezzlement) are natural new ones.
- The emergent fixed-seed history reshuffles again this pass (the plot
  engine itself changed shape); headless statistics all hold, and two
  headless asserts were hardened — the lord-pick now skips opinion-clamped
  schismatics, and duchy succession accepts Module 4's hereditary heirs.
