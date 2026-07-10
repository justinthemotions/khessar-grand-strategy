# Administrative Government — Technical Briefing (v1.0)

The Vael Magistocracy, playable as itself: a non-hereditary bureaucratic
government where the ruler is **elected by the nine-seat Council of
Magisters** and succession never flows to the dead ruler's heirs.
Implements Opus's Administrative Government mini-brief (2026-07-08),
all seven phases. Sim logic in `scripts/world.gd` (the `Administrative
Government` section); the Council readout heads the Council tab in
`main.gd`; the test is `tests/administrative_module_test.gd`.

## 1. What changed at the top of the world

**Grand Magister Anselm Vorontheim now rules realm 0.** The
Halvenard-Veil placeholder crown stepped back to its House: Garran
remains head of House Halvenard-Veil (and, per the Gazetteer
reconciliation, is now **55** at Year Zero — a birth-date correction so
Sera's dynastic timing lands on the TTRPG's Year Six, not a dice roll).
Realm 0's `government` string — `"administrative"` since the Khessar map
pass — finally has mechanics behind it. Map labels and character sheets
now use government-aware titles: *Grand Magister* for Vael, *Chief* for
the clan, *King/Queen* for feudal crowns.

## 2. The Year Zero Council (brief §2)

| Seat | Holder | Age | Wing | Notes |
|---|---|---|---|---|
| Grand Magister | **Anselm Vorontheim** | 68 | — | Methodical, Content, Patient, Homely, **Broken**; 12 years in the chair |
| Economic Affairs | **Halloran Verith** | 45 | reformist | Ambitious, Honest, Pragmatic — the Reformist standard-bearer |
| Foreign Affairs | **Davriand Karn** | 40 | traditionalist | **Half-Orc**; Ambitious, Brave, Opportunistic; eight years at the borders |
| Clerical Registry | **Kreth Anford** | 62 | reformist-leaning | Broken; scheduled to die by Year Six (Month 70) |
| Records Sublevel | **Veril Ormand** | 77 | *silent* | Magic v1.0's Architect — the seat was always his |
| Chancellor | **Maren Solvey** | 57 | neutral | Reformist-aligned through 23 years of loyalty to the ledgers — never a standard-bearer |
| Master of War | **Corvin Draeth** | 51 | traditionalist | Zealous garrison soldier, Davriand-aligned |
| Chief Physician | **Ellard Nym** | 59 | neutral | Kreth's old confidant; will fail to detect the poison, and carry it |
| Court Chaplain | **Odric Vasse** | 61 | — | Patient, Content, **Broken** (the seed's coin-flip, now canon) — see §6 |

Off-council: **Chief Spymaster Tess Mareck** (51, Intrigue 19) — no
seat, reports only upward, knows more than she files. Also seeded:
**Sevrin Vorontheim** (34, Learning 20, Methodical/Ambitious/Bureaucrat,
Pragmatic), Anselm's nephew, a Records Sublevel deputy and the dynasty's
one Council-eligible spare.

All four once-unnamed seats — and Sevrin — are now **canonical per
Opus's Gazetteer v1.1 addendum** (Post-Administrative Canon Updates),
with ages, traits, and backstories reconciled into the seeds. Odric's
Broken response is canon-fixed: the historical die is still consumed
(the `arng` stream must not shift) but the answer no longer floats.

House Vorontheim declares **The Vael Compact** legacy at setup (250 of
its 280 renown) — the brief's §6 recommendation.

## 3. The determinism contract

Same architecture as Magic and the Faction Cast: **all Council
randomness runs on `arng` (seed 888)**, Council-raised events resolve
their AI jitter on `arng` (a third event stream beside main and magic),
and the seeded Council characters are `admin_cast` — `is_cast()` now
covers them, so every main-RNG per-character loop skips them. New
guards went onto commander assignment, skirmish deaths, champion
rosters, oath pools, plot target/asset selection, and the apothecary
pick. **Veril Ormand deliberately stays in the main stream** — his
natural death was always the Architect's Chamber clock, and guarding
him now would reshuffle the fixed history.

One accepted divergence: realm 0's ruler is a different person with
different traits, so realm-0 event choices and downstream history
differ from the Faction Cast era — that is the module's *point*, not a
leak. All ten prior suites still pass.

## 4. Council votes (brief §3, Phases 1 & 7)

`magister_vote(matter, proposer, base)` — **rng-free**, so any system
may call it. Each seated Magister scores base + opinion of the
proposer ×0.15 + wing bias + temperament; the Records Sublevel
abstains ("it never has" voted); the Grand Magister's vote counts
twice in a tie. Majority = filled seats / 2 + 1 — **a 9-seat Council
with 2 vacancies needs 4 votes, not 5**. Every division lands in
`council_vote_history` (Phase 7). Wired live: a realm-0 **declaration
of war** goes before the Council — advisory at v1.0 (the Curia still
gates the war legally), but marching over a recorded *nay* costs
tyranny and magister memories.

`call_no_confidence()` — needs 3+ Magisters at ≤ −30 opinion of the
chair to move, two-thirds of the seated Council to pass. Failure is
remembered by the chair; success deposes and opens an election.

## 5. Elections & the Administrative Interregnum (brief §7, Phase 2)

The feudal four stages, transformed: **Regency** (30 days, the
senior-most Magister presides) → **Council Endorsement** (60 days of
public assembly) → **Institutional Loyalty Consolidation** (90 days of
chamber visits — AI candidates campaign on `arng`; the Ambitious
campaign hard, the Content not at all; the **player lever is
`consolidate_support(candidate, magister)`**, 20 gold per sponsored
visit, verified in test to move real points) → **Council Election
Vote**: preferential ballots, top five ranked, points 5-4-3-2-1, ties
to seniority, office immediately — "no coronation; a signature, a
seal, and the weight of eight opinions."

Ballot scoring: opinion + wing loyalty (+25) + **Wing-Leader Standing**
(+8 per bloc follower, paid to the wing's *standard-bearer only* — the
chamber respects the man who can already count votes; it does not
mistake the counted votes for candidates) + **tenure** (up to +10 over
ten seated years — the chamber does not hand the seal to a man it
seated yesterday) + **the Regent's visibility** (+8: the chamber has
just watched him do the job) + competence ((stw+lrn+dip)/3) +
consolidation support + self (+60, +20 more if Ambitious). The
Wing-Leader Standing principle is canonized in the Gazetteer v1.1
addendum: *faction organization is a first-class political skill in
the Magistocracy.*

**Failed Council Vote Refusal** (the Administrative palace coup): a
loser within 2 points, with Master-of-War friendship ≥ +40 and ≤ −30
opinion of the winner, may refuse the count — concede with ice, or
**Failure of Institutional Order** (−25 prestige, +10 tyranny, seat
forfeited, and the Free Cities' pamphleteers get their line: *Vael's
own Council cannot count*).

## 6. The scheduled arc (brief §5, Phases 3 & 6)

| Month (tick) | Beat |
|---|---|
| 9 | **Court Chaplain crisis** — Zealous: redoubles, joins Davriand's wing; Broken: resigns to keep bees outside the walls, seat vacated |
| 20 | *The Grand Magister's Questions* — Anselm and the Year-112 anomaly (player event) |
| 27 | *The Spymaster's Silence* — Tess's two-page report standing in front of forty (player event) |
| 31 | *A Wrongness at Table* — the Physician's unfindable steward (player event) |
| 33 | **The autumn dinner** — Month 34 of the Silence, Year 3 Month 10: Anselm is poisoned by one of Tess Mareck's own operatives, suborned by coin that traces (unprovably) to the Traditionalist wing |
| 70 | Kreth Anford dies of the long fatigue |

**The player can foil the poisoning**: each event's non-default choice
adds protection; at 2+, the cup is caught, the operative confesses,
and the `magister_poisoning` secret lands on Davriand *known to realm
0* — leverage instead of a funeral. The defaults (which Anselm's
Broken, Content, Patient AI reliably picks) walk him to the canonical
death. Either way the secret exists and House Karn's ledger records
the poisoning.

### The canonical fixed-seed run (seeds 1066/333/555/777/888)

Odric Vasse breaks **Broken** (canon) — resigns in Month 9, and by
Month 13 the AI appointment machinery has nominated and confirmed
**Sevrin Vorontheim** to the vacant Chaplain seat: *the brief's "place
a nephew before the poisoning" puzzle resolved itself emergently.*
Anselm dies at the autumn dinner; Kreth Anford (senior-most) stands
Regent; and the first Council Election returns exactly the Gazetteer's
three named candidates in exactly its order: **Halloran Verith 22 —
Kreth Anford 20 — Davriand Karn 19** (the v1.1 timeline's 22-19-18,
re-derived one point apart after Sevrin's canonical stats entered the
ballots — ordering, margins, and meaning preserved; flagged for Opus).
Maren Solvey polls low-key at 15; Sevrin, junior at two years seated,
finishes mid-pack — a candidate but not a leading one, per canon.
Grand Magister Halloran Verith, the reformist, now holds the seal —
governing from a plurality, with Davriand's wing intact, angry, and
holding a grudge with eighty-eight years of sublevel history still
buried beneath it.

## 7. Non-hereditary mechanics (brief §4, Phase 5)

`_succession()` intercepts administrative realms before any feudal
logic runs: no heir, no interregnum-legitimacy, no coup — a Regent and
an election. The dead chair's House keeps its seats, its wealth, and
gains the **Former Grand Magister Family** mythos (+5 opinion from
Aelindran-Legitimate houses, −5 from reformists). Character sheets for
administrative rulers show no "Heir" row — the chair has electors.
Appointed Magisters from the main population remain fully mortal;
their deaths vacate seats, and `nominate_magister()` + Council
confirmation (5-of-9 scaled) refill them — the AI nominates the most
academy-fit name each season (Learning 12+ required, the brief's rule).

## 8. Scoping notes

- The Council vote on wars is **advisory** in v1.0; binding fiscal
  votes (budget > 1000 gold) arrive when Module 8 gives the
  Magistocracy institutional taxation.
- Seeded Council figures don't roll natural deaths (scheduled beats,
  like the cast); appointed successors from the population do.
- The Court Chaplain seat's long fate — "Master of the Silence's
  Records" / dissolution / "Coordinator of Post-Silence Faiths" — is
  Module 9's, per the brief's §9. The crisis vector is wired and fired.
- Davriand's slow-burn play (consolidating toward the reveal cascade),
  Tess Mareck's Section Three, and the Council's reaction to the
  complicity secret all key off state this module created
  (`magister_poisoning`, wings, vote history) — reveal cascade wiring
  remains with the Magic v1.1 / Module 9 passes.
