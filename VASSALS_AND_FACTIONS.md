# Vassals, Factions & the Curia — Technical Briefing (Module 4)

The push-and-pull of governing landed men in the Khessar Grand Strategy prototype.
All in `scripts/world.gd`; UI in the Realm tab of `scripts/main.gd`. Everything here
activates only once titles are granted — a realm with no landed vassals rules alone
(and consumes no extra RNG, keeping the fixed-seed history stable).

## 1. Who is a vassal

`landed_vassals(realm_id)` = every living holder of a granted county or duchy of the
realm. Titles are now **hereditary** (`_inherit_titles`, called from `_kill`): the
eldest trueborn, non-disinherited, non-denounced adult child of the realm inherits the
land *and the contract*; no such heir → escheat to the crown as before. Attainder is
the exception: rebels beaten in a civil war are stripped before any hanging, so
treason never passes to the heirs.

## 2. Individual feudal contracts

`vassal_contracts[char_id] = {tax, levy, privileges[]}`, opened automatically at the
first grant. Rates (`CONTRACT_RATES`): **lenient** (×0.7 yield, +10 opinion),
**normal**, **harsh** (×1.3 tax / ×1.25 levy, −15 opinion, +5 realm Tyranny on the
change, plus a −15 memory). Wired into `realm_tax_eff` / `realm_levy_eff` per lord.

**Privilege addenda** (`PRIVILEGES`, "privilege creep"):
- **Guaranteed Council Seat** — `_ai_fill_council` seats them before merit; `appoint`
  cannot vacate or reassign their seat.
- **War Declaration Sanction** — their levy contribution halves while at war.
- **Coinage Rights** — the crown collects only 60% of their counties' taxes.
- **Marcher Lord** — they owe no levies at all, but their counties are never chosen by
  `_cede_border_province` in a peace.
- **Judicial Immunity** — `_revoke_title` refuses; the law cannot touch them.

Privileges arrive by player grant (`grant_privilege`), by **wartime demand events**
(`_privilege_demand_tick`: a bitter multi-county lord names his price while the war
needs his levies — grant or take a −20 memory), or as the Independence faction's
concession.

## 3. Granular vassal opinion & Tyranny

`vassal_opinion(char_id, realm_id)` = `opinion_of(lord, ruler)` + contract-rate
opinions + 5 per privilege + cultural alignment (+5 same culture, −10 foreign, 0 if
one is a hybrid of the other) − `realm.tyranny × 0.5`, clamped ±100.

`Realm.tyranny` accumulates from revocations (+15), harsher contract changes (+5),
bad court verdicts (+5), crushing populist risings (+10); it decays 0.5/month and is
shown on the Realm tab when above zero.

## 4. The Faction Engine (covert → overt)

`world.factions[]` = `{realm, type, members[], provinces[], covert, discovered,
claimant}`. Monthly (`_factions_tick`):

- **Formation**: a landed lord with `vassal_opinion ≤ −20` rolls
  `0.08 + scheming×0.001 + aggression×0.0005` to conspire. Cause by situation:
  **claimant** if the dynasty offers an aggrieved/passed-over rival, **independence**
  if he is foreign-cultured with 2+ counties, else **liberty**. Same-cause factions
  merge.
- **Populist**: 2+ conquered counties (owner ≠ de jure, held 24+ months) rise
  together — no dice, the oppressed land itself is the faction.
- **Discovery**: covert factions are invisible (`visible_factions`) — and cannot even
  be bribed — until a seated Spymaster rolls `0.04 + intrigue×0.008` monthly.
  Discovered members can be bought off (`bribe_faction_member`, 60 gold, +30 memory).
- **Maintenance**: the dead, denounced, stripped and appeased (opinion > 10) leave;
  empty factions dissolve.
- **The ultimatum**: at strength ≥ 40% of `levy_capacity`
  (`faction_strength` = members' county levies + martial×2, or province levies ×1.5
  for populists), the faction turns overt and raises a **choice event**: concede or
  civil war.

**Concessions** (`_concede_faction`): liberty → tax law forced light, −20 tyranny;
claimant → the ruler abdicates and the claimant takes the throne (−80 "stole my
crown" memory); independence → members gain Marcher Lord + Coinage Rights
(independence in all but name — true secession waits for the multi-realm engine);
populist → the conquered counties return to their de jure realm.

**Civil war** (`_civil_war`): the rebel muster (sword/levy regiments) meets every
standing army of the realm in one pitched battle run through the real `BattleSim`
(`run_headless`). The crown's armies carry their dead home either way. Crown victory:
rebels attainted, then 40% hanged / spared with a −60 memory; populist provinces get
their unrest clock reset (+10 tyranny). Rebel victory: the demand is enforced at
sword-point, −60 gold, −30 tyranny.

## 5. The Estate Curia

Landed lords caucus permanently by disposition (`bloc_of`):

| Bloc | Traits | War | Heavy tax | Succession change |
|---|---|---|---|---|
| Absolutists | Ambitious, Cruel, Avaricious, Deceitful | for | for | — |
| Constitutionalists | Honest, Patient, Methodical, Compassionate | against | against | — |
| Traditionalists (default) | Purist, Content, Stoic, Paranoid | against | — | against |

`curia_vote(realm, matter)`: weight = counties held (+1 per duchy); a lord's stance is
his bloc's agenda ±1 for loyalty (opinion ≥ 40) or spite (≤ −20). Fewer than 3 landed
lords → the crown rules alone (auto-pass). Gated actions: `declare_war` (non-tribal),
`enact_law` for heavy taxation and succession changes. Horse-trading: `sway_curia`
(40 gold → +25 memory). Tribal realms are exempt throughout — their power is personal.

## 6. Council snubs & the Liege's Court

- **Snubs** (`_council_snub_tick`): a great lord (2+ counties or a duchy) without a
  guaranteed seat, unseated while a clearly lesser man (stat gap > 3) holds a chair,
  voices the grievance exactly once: −20 memory.
- **The Liege's Court Trial** (`_court_trial_tick`, 24-month cooldown): when two
  landed lords hate each other (opinion ≤ −30), the crown must judge. Verdicts:
  side with the aggressor (+5 tyranny, every Constitutionalist takes a −10 memory),
  uphold the law (a Wrathful/Ambitious loser refuses the verdict and is branded a
  **Realm Outlaw** — stripped of every county at once), or force a compromise
  (50 gold, both lords +10 and the feud memories soften).

## 7. UI (Realm tab)

**Vassals & the Curia**: one row per lord — name, counties, bloc, colored opinion,
privileges — with tax/levy rate-cycling buttons and a 40g Sway button. **Factions**:
only what the crown can see (overt or Spymaster-discovered), with strength as % of the
levy and a bribe button; a hint appears if conspiracies could be hiding and no
Spymaster sits. Tyranny shows in the demesne summary. Ultimatums, privilege demands
and court trials arrive as choice-event popups through the events framework.

## 8. Hooks for future modules

- Curia horse-trading is built for Module 6's Hooks (leverage-forced votes).
- Privilege demands are the natural payload for Strong Hooks.
- The claimant faction reuses interregnum grievance flags (`aggrieved`, "passed over").
- True Independence secession and Reverse Imposition both wait on a multi-realm
  engine; the Marcher-autonomy concession marks the spot.
- Court Chaplain / Regent seats (design doc's fuller council) arrive with Modules 9
  and 10's institutions.
