# The Architect's Vigil — Technical Briefing (v1.0)

The specific canonical shape of Veril Ormand's last six years in the
grand strategy timeline — where the Traveler he spent forty years
preparing for **does not exist**. Implements Opus's standalone
character-arc doc *The Architect's Vigil* (2026-07-08), voiced against
*The Architect's Voice* (Thessaly Vorn's working notes). Not a module:
an arc. The mechanics follow the psychology, not the reverse. Sim logic
in `scripts/world.gd` (the `Architect's Vigil` section); the Records
Sublevel readout joins the Council tab in `main.gd`; the test is
`tests/architect_vigil_test.gd`.

## 1. The determinism contract

The pattern's seventh stream: **all vigil randomness rolls on `vrng`,
seeded 112 — the year the bargain was signed.** Vigil-born events
resolve their AI jitter on it. Veril himself stays exactly where the
Administrative pass left him — in the main stream, drawing his monthly
dice as he always did — but two things are now canon instead of chance:

- **He is 77 at Year Zero** (Vigil doc §1; 83 at his death, matching
  the TTRPG chamber's timeline). A birth-date correction, no dice.
- **He dies in Year Six** — Month 72, six years of the Silence to the
  month. The actuarial die is still *drawn* every month (the main
  stream must not shift), but the answer belongs to the vigil's clock,
  not the tables. This is the same discipline as Odric's canon-fixed
  coin: consume the die, fix the answer.

One accepted divergence, flagged like the Administrative pass's: in the
old fixed-seed history Veril's death was actuarial and could fall
anywhere; pinning it to Year Six moves the point where his dice leave
the main stream, so realm-0/1 emergent history after his old death tick
is re-rolled. That is the arc's *point* — the Architect's Chamber was
never supposed to open at a random funeral.

## 2. The five phases (doc §2)

`architect_phase`, ticked monthly, transitions on the doc's exact
schedule:

| Month | Phase | Observable |
|---|---|---|
| 0 | 1 — Confident waiting | Nothing. The door has not opened in 34 years. |
| 30 | 2 — Quiet uncertainty | The Sublevel requests the Iron Library's correspondence indices — and does not find the pattern forty years taught him to expect. |
| 42 | 3 — Acknowledged crisis | He attends every sitting for a month, says nothing, watches the chamber like an assessor watches a bridge. Five names go into the second journal. |
| 54 | 4 — Active recomposing | A letter leaves under his personal seal — the first outbound correspondence in the archive's living memory. |
| 66 | 5 — Termination | Acceptance (5A) or active delivery (5B). |
| 72 | Death | The clock the chamber was always running on. |

The court sees only the observable column: `vigil_status_line()` feeds
the Council tab one line that changes as the phases do. Phase Two is
per the doc invisible-in-substance — a flavor beat, no mechanics.

## 3. The evaluation (doc §6 Phase 2)

`vigil_candidates()` — the doc's weights, live against the world:

| Candidate | Base | Doc arithmetic |
|---|---|---|
| Marek Vovel | 20 | +40 the Library's protection, −20 the years he doesn't know he lacks |
| Sevrin Vorontheim | 15 → 30 | +25 Pragmatic, −10 youth, +15 once he holds a Council seat |
| Halvar Stenn | 25+ | +30 the Order's structural opposition, +10 respect, −15 the outsider |
| Sera Halvenard-Veil | 15+ | +20 House, −20 youth, +15 Aelindran-Legitimate access |
| Thessaly Vorn | 35 | the Library's discipline inherited whole — **requires Vovel's death** |

**The player never picks Veril's recipient** — but the landscape the
player shaped is the landscape he observes: carved birds on the roads
raise Halvar (up to +10, +5 more once the Patron network is visibly
active); a House sworn to the Iron Library Compact raises the archive's
standing (+10 to Marek/Thessaly); a woken Aelindran-Legitimate mythos
raises Sera (+10). This is the doc's emergent-agency clause, verified
in test.

Supporting canon this pass adds: **Thessaly Vorn** is now a seeded cast
character (Pellar, 44, Learning 21, Methodical/Patient/Honest,
Academy-Sworn, Pragmatic — stats Fable-invented, flagged for the
Gazetteer), created at the tail of the cast stream so no existing cast
die shifts. **Marek Vovel dies at Month 44** (Year Four, doc §2), a
scheduled beat; the Library passes to Thessaly the same month. **Sera
Halvenard-Veil** now exists from setup: Garran's eldest rolled daughter
takes the canonical name and the canonical birth date — 17 at Year
Zero, 23 by Year Six, the very timing Opus aged Garran to produce. The
same corrections Garran himself got; no dice touched. And because
Phase Four begins at Month 54, **Marek's window closes before Veril
moves** — the doc's "-20, only works if Veril moves early" resolves
itself: another recipient the world removes.

## 4. The contact and the player's lever (doc §6 Phase 3)

At Month 54 the top-weighted candidate gets the contact — *The Iron
Library Contact*, *The Council Approach*, *The Order Contact*, or *The
House Delivery* — raised as a realm-0 event to the crown, who saw the
letter move: **let it pass** (default), **copy it in transit**
(contact succeeds, but `vigil_fragments` marks the truth in more hands
than its keeper chose), or **intercept it**. Interception writes one
line into the second journal: *"The road is watched. I am — I am out
of roads."*

## 5. Phase Five: acceptance or delivery (doc §2)

At Month 66: delivery (5B) requires the contact received **and** the
candidate at weight ≥ 25 — and survives one further vigil die: one
chance in ten that the standards he built for forty years refuse the
substitute anyway. Otherwise 5A: the volumes are completed,
cross-referenced, unaccompanied; the chamber holds them; he writes the
dates again, out of season, to verify they are still what he remembers.

5B schedules the **modified ritual** three months out, in the doc §4's
recipient-specific forms: nearly-archival for Thessaly ("I have been
keeping records. I have — I have wanted them to exist. They are yours
now."), truncated for Sevrin ("Count the chamber first. You are — you
are good at counting."), transformed into threshold-recognition for
Halvar (who carves, that evening, a bird for a man not yet dead),
politically weighted for Sera (two pages on what the truth is, eleven
on what it will do).

## 6. Death and the truth's escape (doc §3)

Veril dies at Month 72, at 83, "the ledgers in order, the door locked
from within." In the first room: a small ledger, the same dates written
over again every spring, forty springs deep.

**5A — the race for the door** (death+3): the effective recipient is
proximity, not choice. Weighted on the vigil's die: Sevrin 25 (deputy
of the very sublevel), Davriand 20 (the wing that wants a weapon), Tess
Mareck 15, the crown 10. If the crown reaches it first, the classic
five-option Architect's Chamber event fires for the player; anyone else
resolves it by **their own character's AI weights** — the first reading
shapes everything after, and the first reader was not the crown. (If
the Spymaster copied the Phase Four letter and the chamber was sealed,
the fragments preempt the race entirely: `leveraged`, weak hooks on
every complicit house — Ending Four's distributed-consequences shape.)

**5B — the recipients' roads** (death+2 onward), each a distinguishable
ending mechanism per doc §5:

- **Thessaly**: `contained` → a first unanswerable paper at +14 months
  (coherence dips) → **gradual revelation** at +26 months
  (`_ending_revealed_gradual()` — half the fury, all the finality;
  resignations, not mobs). Ending Two, the archival road.
- **Sevrin**: puts the Year 112 record to a **recorded Council
  division** (doc: "Council-level revelation attempt, partial and
  contested"). Passed → `contained`, reform from inside. Failed → a
  declined motion about a secret is a secret with a vote count
  attached: full `_ending_revealed()`. Ending Two or Ending One.
- **Halvar**: the Order receives the truth as it receives the dead. At
  +8 months the road forks on the Patron's visibility: network active →
  the Order coordinates the anchor's destruction (`_ending_destroyed()`,
  Ending Three); nothing to burn → the volumes go under a
  threshold-shrine's floor (`suppressed`, Ending Five in the Order's
  key). Both forks verified in test.
- **Sera**: House Halvenard-Veil **earns the Aelindran-Legitimate
  mythos** — the dormant tag from the mythos table finally wakes, and
  it wakes here. At +8 months, *House Halvenard-Veil Moves* (player
  event): let the House publish (Ending One at its most explosive),
  bargain (Ending Four's `leveraged`, the House's silence bought with
  precedence and renown), or break it (Ending Five's `suppressed`,
  +15 tyranny, and Sera survives remembering).

All five of the intrigue doc's endings remain reachable —
`revealed`, `contained`, `destroyed`, `leveraged`, `suppressed` — each
through timeline-specific mechanisms, which is the shared-world/
divergent-histories point (doc §7).

## 7. Integrations

- `_architect_tick` (Magic v1.0) hands the chamber to the vigil: the
  post-death path defers to the vigil's scheduled beats, and the
  loose-pages die is still drawn monthly but leads nowhere once a
  delivery has left the chamber. A containment leak or loose-pages
  fire *before* the arc concludes aborts the vigil cleanly (the truth
  is already loose). An unscheduled death — poison, plague, a plot —
  also aborts it: the chamber opens haphazardly, the doc's
  proximity-recipient case in its bluntest form.
- `raise_event(...)` gains a `vigil` flag; `_ai_resolve_event` draws
  vigil jitter from `vrng` (precedence: vigil > admin > faith > magic).
- The reveal cascade's Module 9 wiring (`_shift_coherence` on
  Orthodox/Rationalist/Silent Path) fires through every road that ends
  in revelation, gradual or not.

## 8. The theological weight (doc §8)

The arc is the Silence at the smallest human scale: one specific
person's decades-long preparation encountering the world that would not
receive it. He is not defeated by it. He responds, adapts, chooses —
but the choices are shaped by grief and by the specific absence of the
person he prepared for. The chronicle carries his register (the Voice
doc's halting precision) at exactly four beats: the second journal at
Phase Three, the intercepted road, the Phase Five commitment, and the
delivery letters. Sparingly, because the Voice doc is a chamber
document — the grand strategy player hears him only when a clerk or a
letter would.

## 9. The canonical fixed-seed run (seeds 1066/333/555/777/888/999/112)

The dice chose the threshold. At Month 54 Veril's ledger reads **Halvar
Stenn 35.0 — Thessaly Vorn 35.0**, a dead tie (the Order's carved birds
climbed Halvar from 25 to the cap; the Library's inheritance put
Thessaly at 35 flat), resolved in the evaluation's fixed order to
**Halvar**. The run had already justified it twice over: Halvar
performed the Threshold Rejection *over Veril himself* at Months 11 and
49 — the Architect chose the one warden who had personally worked his
ledger. The contact letter passes unintercepted; the Phase Five die
does not refuse; and at Year 5 Month 10 the six volumes go out through
Gravewarden channels as threshold-recognition. *Halvar Stenn receives
the volumes at Marn's Crossing, reads until the lamp fails, and carves,
that evening, a bird for a man not yet dead.*

Veril Ormand dies at Year 6 Month 1, at 83, the ledgers in order, the
door locked from within — and Halvar receives him at the threshold,
name said properly, crossing witnessed. At Month 80, with the Patron
network still dormant, the Order decides: no network worth burning, no
reader worth the ruin. **The volumes go under the threshold-shrine's
floor at Marn's Crossing — Ending Five, in the Order's key.** The
Silence continues, guarded, tended, and closed.

Coda the sim wrote itself: at Year 7 Month 2 the Council confirms
**Alenna Stenn** — Threshold-Sensitive, the practice inheriting — to
the vacant Records Sublevel seat, 8 to 0. The Architect's chair passes
to the daughter of the man who keeps the Architect's truth.

Player-divergent runs reach every other road: court the Iron Library
(Compact legacy, +10) and Thessaly takes the tie; expose the Patron
network before Month 80 and Halvar's road ends in the anchor's ash
(Ending Three); intercept the Month-54 letter and the chamber race
decides — in the pre-fix probe, Tess Mareck won it and chose
`leveraged`, exactly in character.

## 10. Scoping notes for Opus (deviations & deferrals)

- **Thessaly Vorn's stats and age are Fable-invented** (44 at Year
  Zero, Learning 21) — flag for a Gazetteer entry.
- **Marek Vovel as recipient is structurally unreachable** in v1.0:
  the doc's Phase Four begins at Month 54 and Marek dies at Month 44.
  His weight exists in the Phase Three evaluation (verified in test) —
  the window closing is rendered as canon, not simulated as a race.
  If Opus wants a "Veril moves early" variant (contact at Phase 3 for
  a dying archivist), it slots cleanly into `_vigil_tick`'s Month-42
  beat.
- **5A's "destroy the documentation in surrender" sub-shape** (doc
  §2) is not modeled — v1.0's 5A always leaves the volumes in the
  sealed chamber. The chamber race then decides the effective
  recipient.
- **Partial deliveries as tests of reception capacity** (doc §2 Phase
  Four) are folded into the single Phase Four contact + the Spymaster's
  fragment copy; a multi-fragment economy (Mira Crannock-Vey's
  Underground, Section Three) waits for the intrigue expansion pass.
- **Phase Two's deep-surveillance visibility** (intrigue-doc-level
  operations revealing Sublevel behavior changes) waits on those
  operations existing.
- The **Ilyra/Eithne Pellar succession** interacting with Thessaly's
  publication timing is unmodeled — the Library operates independently
  of its shield's crown in v1.0.
