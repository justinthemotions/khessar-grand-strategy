# Diplomacy & Inter-State Relations — Technical Briefing (Module 5)

How the crowns of Khessar deal with each other when they are not marching —
and, above all, what happens the day the marching stops. All sim logic in
`scripts/world.gd`; UI on the Diplomacy tab of `scripts/main.gd`; the test is
`tests/diplomacy_module_test.gd`.

## 1. The Casus Belli system

Wars are not launched on a whim. `available_cbs(realm_id)` lists every
justification the realm could march under today, best first:

| CB | Granted by |
|---|---|
| **De Jure Reclamation** | the enemy holds a province whose `de_jure` is yours |
| **Restoration** | you shelter a dispossessed house-in-exile of the enemy realm (§6) |
| **Redress of Grievances** | your ruler remembers "invaded my realm" / "took my land" |
| **Fabricated Claim** | the Lawspeaker's forgers finished their work (below) |
| **Subjugation** | tribal government — raiding needs no lawyers |

`declare_war` takes the best CB automatically and chronicles it. **A war
without any CB is still possible — it is simply infamous**: −40 prestige,
+15 tyranny (non-tribal), and the defender's ruler takes an "invaded without
cause" memory. `fabricate_claim(realm)` costs 50 gold and runs a clock of
`max(3, 12 − Lawspeaker/3)` months; the sealed forgery is spent when sworn.

## 2. Prestige, truces, alliances, hostages

- `Realm.prestige` (±100, decays 0.2/month): international standing. Won by
  victory, treaty terms, magnanimous peaces, hosting wards, breaking free
  companies; bled by unjust wars, broken truces, and defeat. A prestigious
  Vael measurably deters Karn-Vol's AI war rolls.
- **Truce**: every peace binds for 60 months (`truce_until`). Declaring war
  over a truce is allowed — at −30 prestige and +10 tyranny more.
- **Marriage alliances** (existing) still hard-block war while the couple lives.
- **Hostages & wards** (`wards`, `send_ward`, `ransom_ward`): a child fostered
  abroad is shaped by the court that raises it — on coming of age it gains +2
  to its guardian's strongest stat, may inherit one of the guardian's
  personality traits, and after 6+ years adopts the guardian's culture.
  A **hostage** is the same arrangement as collateral: the home realm cannot
  declare war while its heir is held (ransom: 100 gold; and no court dares
  keep a ward who inherits a crown). Hostage wards stay at the host court
  even when grown.

## 3. The War Leverage treaty drafting table

No binary war conclusion. Winning field battles is tracked
(`war_battles_won`), and a decisive peace (|war score| > 40) computes
**leverage** `= |war score| + 10·battles won + prestige/5`, then raises a
choice event — the winner (player popup or trait-weighted AI) drafts the
treaty from a leverage-gated menu:

| Term | Gate | Effect |
|---|---|---|
| Magnanimous peace | always | +20 prestige, the loser's ruler remembers the mercy |
| Tribute | always | gold ≈ 1.2× leverage moves at the table |
| Cession | 50 leverage (35 with a de jure/fabricated claim) | border province + 40 gold |
| **The Yoke** | 60 | reparations (15% of tax yield, 120 months) + demilitarization (professional muster barred 120 months) |
| **Collateral** | 45 | the loser's heir becomes a permanent hostage ward |
| **Salt the earth** | 75 | a border province stays with the loser but yields ×0.4 tax and levy for 240 months |
| **Restoration** | Restoration CB | the exiled house is reinstated on the loser's land — sworn to the loser, owing everything to the winner |

Reparations, demilitarization (checked in `recruit_gate`), and salt scars
(checked in `realm_tax_eff` / `realm_levy_eff`) are live burdens the
Diplomacy tab reports until they lapse.

## 4. The Traitor's Tribunal

Crushing a noble civil war (Module 4) no longer auto-hangs anyone. The crown
convenes a tribunal — a choice event with **Loyalist Expectations**: the
landed lords who did *not* rebel judge the judgment.

| Verdict | The traitors | The loyalists | The realm |
|---|---|---|---|
| **The Scaffold** | attainted, then hanged | +30 (enthusiastic) | +20 tyranny; each hanged house swears a **blood feud** against the crown's line |
| **Attainder** | stripped, spared | −10 (they expected the spoils) | +10 tyranny; a house left landless **flees into exile** (§5) |
| **Forced Tonsure** | stripped, disinherited, cloistered | +10 (tradition upheld) | but the cloistered pen still cuts: −5 "pamphlets" memory to every lord |
| **The King's Pardon** | keep their halls, owe a debt | **−40** (furious) | +10 prestige abroad — and nothing stops them rebelling again |

Populist risings are still crushed the old way — conquered land has no lords
to try.

## 5. The Dispossessed & the Shadow Court

A noble house stripped of its last acre does not linger as harmless
courtiers. `_dispossess` flags the root house, and every member flees to the
rival realm as a **court-in-exile** (`dispossessed`). Monthly, the shadow
court bleeds the homeland's treasury (old keys still open doors), feeds the
host's assassination plots against it, and — the Foreign Proxy War — hands
the host a standing **Restoration CB**. Win a war under it and the treaty can
reinstate the exiles on their old land: sworn to the loser's crown, owing
everything to yours.

## 6. The Broken Blade Cycle

When any peace is signed, `_demobilization` counts each realm's professional
soldiers (everything but common levies) against what peacetime can pay
(`max(120, levy capacity/2)`). Sixty or more men over the line raises the
choice: **pay the demobilization bounty** (0.5 gold/man — they go home as
farmers) or **turn them out** — and a **Free Company** forms: a masterless
army (black-rag banner on the map) that wanders province to province,
pillaging 1–4 gold a month from whoever owns the ground under it, slowly
deserting, and mauling any army that closes carelessly. They persist until an
army physically marches out and destroys them (+10 prestige) — Karn-Vol's AI
armies hunt them in peacetime on their own.

## 7. UI (Diplomacy tab)

Prestige for both crowns, standing truce, every CB in hand (or the price of
marching without one), the fabrication clock, reparations/demilitarization
burdens, a hostage warning, loose free companies, and known courts-in-exile.
Buttons: Fabricate a Claim, Send as Ward / Ransom Home over a picker of the
crown's fosterable children and everyone already abroad. Treaties, tribunals,
and demobilization all arrive as choice-event popups.

## 8. Scoping notes & hooks

- With two live realms, "alliance networks" resolve to the existing
  marriage-alliance hard-block plus prestige; multi-party defensive calls
  wait for the multi-realm engine.
- Dismantle-fortifications waits for a fort layer (Module 8 economy pass);
  Demilitarization carries that treaty's weight meanwhile.
- The tribunal's martyr unrest is expressed as blood feuds + tyranny; popular
  unrest per-province arrives with Module 8's control metrics.
- Free companies do not yet take contracts — hiring them back as mercenaries
  is a natural Module 8 economy hook.
- Every Module 5 subsystem returns before touching the RNG when it has no
  work, but the treaty table itself replaces the old flat tribute+cede peace
  — so the fixed-seed emergent history legitimately diverges from the first
  decisive peace onward.
