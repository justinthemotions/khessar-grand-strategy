# Religion & the Silence — Technical Briefing (v1.0)

Not a religion module: the module that models the **collapse of
pre-Silence religious authority and the successor institutions rising in
the vacuum** — Opus's Module 9 mini-brief (2026-07-08) and the God of
Thresholds addendum, all ten phases. Sim logic in `scripts/world.gd`
(the `Religion & the Silence` section), traits in `scripts/trait_db.gd`,
the Faiths readout on the Council tab in `main.gd`; the test is
`tests/religion_module_test.gd`.

## 1. The determinism contract

The pattern's fifth stream: **all faith randomness rolls on `frng` (seed
999)**, faith-born events resolve their AI jitter on it, and the seeded
canonical practitioners are `faith_cast` — covered by `is_cast()`, so no
main-stream loop ever feels them. `Threshold-Sensitive` is congenital
but **excluded from `_rollable_congenitals()`** (like Bicultural): it
enters the world seeded canonically and travels only by blood at 5%, or
every founder seed would reshuffle. All eleven prior suites pass
unmodified. Verified: two 60-month worlds are byte-identical in census
and faith weather.

## 2. The five faiths at Year Zero (brief §2)

| Faith | Coherence | Membership | Alignment | State |
|---|---|---|---|---|
| Aelindran Orthodox | 0.60 | 60% | +0.90 | active, crumbling |
| Aelindran Reformed | 0.50 | 0% | +0.30 | record only — activates Year One |
| The Silent Path | 0.35 | 0% | −0.20 | record only — activates Year Two-Three |
| The Brushgate Order | 0.85 | 0.5% | −0.10 | active, stable (body-based) |
| The Vael Rationalist Faith | 0.75 | 17% | 0.00 | active, faction-linked |

Each is a data record: `{active, coherence, equilibrium, membership,
orthodoxy_alignment, tenets, authorities, parent, founded, pressure}`.
The **Patron Network is not a faith**: it carries an activation state
(`patron_state`: dormant → building → active → revealed, or broken)
driven by living Patron-Bound counts and secret exposure. Cultures the
five faiths never covered keep folk labels (`the Drevak Rites`, `the
Elder Ways`, `the Ward-Rites`) — character-level practices awaiting the
v1.1 Druidic/primal pass.

Every soul takes a starting faith at setup (culture and conviction:
Academy-Sworn and the Reformist wing have quietly secularized to Vael
Rationalist — Halloran Verith and Veril Ormand included); children
inherit the parent faith at birth (brief §3).

## 3. Coherence and membership in freefall (brief §3)

Monthly: coherence drifts 3% of the gap toward each faith's equilibrium;
the **Orthodox equilibrium itself erodes** 0.02/year to a floor of 0.25.
A Zealous crown publicly of the faith steadies it (+0.002/mo); a Broken
Court Chaplain in visible office bleeds it (−0.002/mo); cathedral
ceremonies (quarterly, rolled against `faith_reliability`) build or
spend it; activations, conversions, and denouncements spike it.
Membership: Orthodox bleeds ~2%/year of what remains (faster at low
coherence, proportional so total collapse stays the endgame cascade's
job); Reformed grows toward ~18-20% once active; rulers who publicly
practice a faith draw their people after them. **Coherence reads through
into Cleric reliability**: `faith_reliability` now multiplies by
0.6 + 0.5 × the caster's faith's coherence.

Canonical 20-year run: Orthodox at **coherence 0.26, 32% of the
continent** — still the largest doctrine, no longer the authority.

## 4. Heresy as the natural state (brief §4)

Pressure accumulates monthly per active faith: `(1 − coherence) ×
membership% × 0.001`. Past 1.0, a **New Heretical Branch** forms — named
from a ten-name pool, 1-2 tenets swapped, 2-5% of the parent walking.
Branches inside the realm-0 faiths reach the crown's table: **Denounce**
(Learning-scaled roll — success suppresses at a coherence cost; failure
*legitimizes* the branch publicly) or let it find its level. Branches
older than ten years with coherence < 0.20 or membership < 1% collapse
back into the parent. Continent-wide cap: **15 doctrines** — enforced
and tested.

## 5. The orthodoxy axis goes live (brief §5)

The dormant axis's first real consumers: every conversion event weights
its adopt option by the **full alignment gap** between the two faiths —
so a Zealous +30 or a Patron-Bound −30 clears every jitter, and the AI
sorts itself exactly as the brief calls for (Zealous pro-pantheon,
Opportunistic away, reformists to the Rationalist position). Yearly,
any character whose orthodoxy weight moved >20 points since the last
reading faces **Faith Consideration** directly.

## 6. Faith change is event-driven, never a menu (brief §6)

Semiannual chains, preconditions honored: **Reformed Conversion**
(Pragmatic Orthodox + a failed prayer behind them), **Silent Path
Acceptance** (Broken + three lifetime prayer-fails — tracked in
`prayer_fails_ever`), **Secular Rationalist Adoption** (Pragmatic +
academy connection), **Brushgate Adoption** (exposure to a practitioner;
adds the trait, keeps the faith), the **Zealous road home**
(Reformed/Rationalist pulled back to Orthodox), and the **Patron's
Bargain** (already live in Magic v1.0). Conversion effects run the
opinion web: Orthodox judges remember "abandoned the pantheon" (−20
Reformed / −30 Silent Path / −15 secular), same-faith judges warm. A
**Grand Magister converting** puts the matter to a recorded Council
division — a failed vote costs tyranny and can move a live vote of no
confidence.

## 7. The Chaplain's crisis has five faces (brief §8, Phase 7)

The Month-9 beat is now a full event chain: **Intensify** (Zealous —
+0.05 Orthodox coherence, seat votes traditionalist), **Abandon**
(Broken — seat vacated, the bees still answer), **Transition to
Reformed** (Pragmatic — keeps the seat, activates the movement early,
−0.10 Orthodox), **Silent Path** (Broken variant — leaves government,
−0.15), and — for a Threshold-Sensitive Chaplain — **Pivot to the
thresholds** (keeps the seat, becomes Gravewarden-Sworn). Trait-matched
bases (16 vs a max jitter of 12) keep the canonical run intact: Odric
Vasse still rolls Broken, still resigns to his bees in Month 9, and
Sevrin Vorontheim still reaches the vacant seat by Month 13.

## 8. The God of Thresholds (addendum — the theology that never went silent)

Not a sixth faith: an overlay. Two traits per the addendum's exact
numbers — **Threshold-Sensitive** (congenital, 5% inheritance, +25%
silence immunity) and **Gravewarden-Sworn** (coping: binding ×1.40,
corruption gain ×0.60, stress ×0.85). New SimCharacter fields:
`threshold_binding_bonus_permanent` (earned +0.02 per rite, capped
+0.6) and `wooden_birds_carved`.

Seeded canon: **Halvar Stenn** (Gravewarden-Sworn, half-orc, 50) works
the Marn's Crossing threshold-shrine with his daughter **Alenna**
(Threshold-Sensitive); **Mother Anra Halden** waits in the Free Cities
(Broken — the Silent Path activates through her at Month 30, canon's
cheese-house included); **Ariorwe Thaladris** gains Threshold-Sensitive
— 120 carried names were always threshold-work.

**Odric Vasse's arc** (Gazetteer v1.1 addendum): after his Month-9
resignation he quietly practices Reformed among the hives (Month 16
beat), and at Month 30 the Silent Path's teachers come to the bee-yard
— *The Gathering at the Bee-Yard*, a genuinely open choice per Opus's
ruling (no trait-matched rail; the dice or the player decide). In the
canonical fixed-seed run the dice chose: **Odric Vasse becomes a
founding teacher of the Silent Path at Year 2, Month 7** — the
movement gains what it could not buy, legitimacy from the man who
once held Vael's highest altar.

Live mechanics: **Proper Death Received** (a practitioner attends every
same-realm death at 85%/45%, family remembers the carved bird),
**Threshold Rite vs Hollow Shades** (Gravewardens receive rather than
fight — no stress, no corruption), **Bird Carving** (quarterly stress
relief), **Compact Ceremony** (a practitioner at Marn's Crossing warms
both rulers quarterly), threshold castings ignore most silence
dampening (`faith_reliability(c, p, true)` — a rite in the Ashfields
outworks a prayer there), and the **Threshold Rejection Ritual**
(`threshold_rejection()`: 15 stress to the warden, −1.0 Corruption to
the target at 85% — one of the only counters to Patron progression;
marks already paid for remain). The Order works unprompted: a
Gravewarden who sees a ledger at 5+ corruption performs the rite on
their own.

## 9. The reveal cascade and endgame hooks (brief §10)

`_ending_revealed()` (the Architect's Chamber publish path) now lands on
the faiths: **Orthodox −0.30 coherence, Vael Rationalist −0.30**
(institutional legitimacy collapses with the institution's secret),
**Silent Path +0.15** (validation). The Patron state flips to
`revealed`. The Gravewarden Order's structural opposition to the Patron
(completed vs incomplete transitions) is wired and documented — the
Architect's late-game fear of the Order keys off state this module
created.

## 10. Scoping notes for Opus (deviations & deferrals)

- **Anra Halden's realm**: seeded into Pellar's realm (Halvet's Free
  Cities hinterland) — the map has no Halvet province yet.
- **Seminary finance** (budgets, treasuries) waits on Module 8;
  cathedral ceremonies and the one-time **Cathedral Question**
  (Reformed repurposing) are live. Vandalism chains deferred with them.
- **Iliana Vesh** is still not a SimCharacter (Faction Cast scoping) —
  her Threshold-Sensitive latency and the Name-Carrying Recognition
  event with Halvar arrive when she does.
- **Oath-swearing threshold blessings** are folded into the Compact
  Ceremony/reliability wiring rather than a separate +0.10 duration
  bonus; the full oath-object economy is still the intrigue pass's.
- **Race-weighted Threshold-Sensitive inheritance** (Half-Orc 8%, Elf
  6%…) is the v1.1 congenital pass's, per the addendum; v1.0 uses the
  flat 5% plus the cradle-blessing 3%.
- **Aelindran-Legitimate** mythos remains dormant one more pass — its
  natural trigger (a house publicly refusing secularization) wants the
  landed-house religion layer that Module 8's estates will give us.
- Faith records track continent-share membership, not per-realm arrays;
  realm-level dominance arrives when more realms go fully live.
