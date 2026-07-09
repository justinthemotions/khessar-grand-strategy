# Magic & the Silence — Technical Briefing (Magic Injection v1.0)

How Opus's Magic Injection Design (2026-07-08) landed in the engine: the
Corruption meter, the Silence Response substrate, the eight practices,
faith geography, the Patron, and the Magistocracy's central secret. Sim
logic in `scripts/world.gd` (the `Magic Injection v1.0` section) and
`scripts/trait_db.gd`; field effects in `scripts/battle/battle_sim.gd`;
the test is `tests/magic_module_test.gd`.

## 0. The determinism contract (read this first)

Every die in the magic layer — assignments, detections, prayers, offers,
even the AI resolution of magic-born choice events — rolls on a
**dedicated seeded RNG** (`mrng`, seed 333), exactly the pattern the map
uses. Consequence: the Year Zero founder seeds are **byte-identical** to
the pre-magic build, the main emergent history stream is never consumed
by magic, and all seven prior test suites passed unmodified. This was
the doc's core constraint (coping-category, no reshuffle) taken one step
further. The v1.1 congenital Arcane-Blooded promotion remains the one
documented reshuffle trigger.

## 1. The Corruption meter

`SimCharacter.corruption` copies the stress pattern: `add_corruption(c,
amount, reason)` applies `corruption_gain_mult` (and the Patron-Bound's
additive baseline), thresholds at **5 / 10 / 15** fire the **Corruption
Marks I/II/III** health traits — darkened fingertips, the cold-gold eye,
full Silence-Touched status. Mark III carries `silence_immunity: 1.0`:
sufficiently entity-adjacent that the Ashfields no longer bite — the only
souls who walk there freely. Corruption never decays; only Brushgate
meditation (−0.5/quarter) works it back down in v1.0 (Iron Library
confession is deferred until characters can travel there). Dying at
Mark II+ counts toward the dynasty's **Silence-Scarred** mythos.

## 2. The Silence Response substrate

At setup, every living soul takes exactly one of **Zealous / Broken /
Pragmatic / Opportunistic** (coping-category, opposite-enforced — the
`_can_add_trait` opposite check now applies to every category), weighted
by who they already were: the Cruel and Ambitious turn Opportunistic,
the Compassionate keep the rites, the Paranoid break. Children born
under the Silence answer at fifteen. The dormant **orthodoxy** AI axis
is now live — its first consumers are these four traits and the eight
practices, and every magic event scores options against it.

## 3. The eight practices

All practice traits are event-authored coping traits (doc §4):

| Practice | How it arrives | Signature mechanics |
|---|---|---|
| **Wizard** | Vael academy detection (children 10–14, Learning 12+/Genius) → Arcane-Blooded + Academy-Sworn | arcane_channel_mult sharpens Arcane Retinue volleys; discipline = low corruption |
| **Sorcerer** | manifestation beyond the academies (Arcane-Blooded alone) → the `arcane_manifestation_hidden` secret; Magistocracy recruitment events (fold them in, or open a file — a hook) | may sound **Uncontrolled Channel** in battle — Academy-Sworn are forbidden exactly this |
| **Cleric** | seeded at Year Zero; Faith-Practicing | the geography formula (§4); Faith Crisis at three failed years |
| **Paladin** | the realm's finest blade swears, rarely | Oath-Sworn: panic resistance, protected fate rolls; **Oath Challenged** events — breaking pays gold and costs everything else (Oathbreaker: oath_binding 0, corruption, shunned) |
| **Druid** | seeded in the clan; Primal-Practiced | 100% reliable on living ground; the channel is *gone* in ash, ruin — and the commander bonus with it |
| **Warlock** | **The Patron's Offer** — fires at stress 180+, at the breaking point | Patron-Bound: corruption baseline on everything; the Patron whispers secrets no informant could reach; **Reap the Bargain** in battle (+5.0 corruption) |
| **Bard** | the calling finds the young whose words carry (Diplomacy 12+, capped two singers per realm) | `names_carried` grows with every death the Bard attends and every village fire; names are battle morale for every line that hears the song |
| **Monk** | seeded in the clan; Brushgate-Trained | stress ×0.60, meditation works corruption down, sits with manifestations; the Brushgate Column's `silence_immunity` reads through at unit level |

## 4. The Cleric geography formula

`faith_reliability(c, province) = trait baseline × silence_dampening ×
shared attention × the caster's own Response`, with dampening **0.10**
in silence-touched ground, **0.30** ordinary, **0.60** at the sealed
Kharak-Dum holds (the ward-stones), **0.80** in Iron Library adjacency;
+1% per soul in the court (shared attention as reception substitute);
Zealous ×1.15 down to Broken ×0.60. Verified ordering in the test:
Ashfields 0.14 < ordinary 0.43 < Iron Library 1.00 (clamped). Quarterly
devotions roll against it: failure is stress and a step toward **Faith
Crisis** (intensify → Zealous / set down the candles → Broken, the
office abandoned / seek another listener → the Patron's Offer). Success
at reliability *below 0.25* is the theologically dangerous outcome: a
prayer answered where no answer should reach — +0.5 corruption, because
something answered, and it was not the pantheon.

## 5. Regional modifiers

Rulers (at their capitals), landed lords (on their counties), and army
commanders (wherever they stand) are the sim's "residents." On
silence-touched ground they take monthly corruption and stress, and may
meet a manifestation — most souls break a little; the Brushgate-Trained
sit with it until it passes. Ruined Aurath ground marks more slowly.
Mark III characters are immune to all of it.

## 6. Secrets, legacies, mythos

Six new string-typed secrets (`patron_bargain_signed`,
`silence_cause_complicity`, `oath_object_broken`,
`corruption_marks_hidden`, `silence_encounter_witnessed`,
`arcane_manifestation_hidden`) ride the existing ferret/hook machinery —
and a bargain dragged into daylight marks the whole blood
**Patron-Touched** (plots ×1.20, the Kin-Eater opinion treatment). Six
legacies: **The Patron's Bargain** (children born +2 Mar/+2 Int and
*born owing* — corruption 2.0 at birth, and the whole blood gains
corruption 10% faster), **The Iron Library Compact** (every death of
the blood is recorded renown), **The Vael Compact** (+1 admin cap),
**The Salt Road Concord** (+6 gold on trade pacts, +5% levies),
**The Brushgate Continuity** (stress relief for the whole blood),
**The Ward-Speaker Line** (Ward-Speaker retinues muster anywhere).

## 7. The Magistocracy's central secret

**Veril Ormand** — House Ormand, 71 at Year Zero, Academy-Sworn, Broken,
Reclusive, already bearing Mark I from what was signed in Year 112 — is
created at setup as the last surviving yes-vote, and
`silence_cause_complicity` is held by him alone. It is **excluded from
ferreting entirely**: only his death (the chamber opens), or a rare late
surfacing from the Aurath-Voss archives, brings it up. The chamber event
offers the five endings as one grave choice: **publish** (Magistocracy
legitimacy collapses — tyranny +30, prestige −50, every landed lord
remembers that *their crowns knew*), **contain** (reform quietly, with a
monthly leak risk that detonates into the publish outcome),
**destroy the anchor** (the Patron network breaks: every Patron-Bound
soul is freed, the marks already paid remain, and `add_corruption`
permanently refuses new entries), **leverage** (a strong hook on every
complicit landed house), or **suppress** (the Silence continues,
unexamined, toward the endgame).

## 8. Scoping notes for Opus (deviations & deferrals)

- **Canonical practitioners** (Marak Khorul, Selene Tharn, the named
  Magisters, Iliana Vesh) are not in the 2-realm sim yet — they arrive
  with the Faction Cast pass. Until then each court seeds its own
  practitioners from the founding cast. Veril Ormand *is* in, literally.
- **Opinion-scale conversion**: the doc's fractional
  `court_opinion_baseline` values (0.05 etc.) were converted to the
  engine's point scale (5.0) to match the existing Altruistic wiring.
- **Oath-Token as inventory item** → `oath_token_intact` flag on the
  character; the theft/reforging scheme integration is deferred to the
  next intrigue pass (the `oath_object_broken` secret is already
  registered for it).
- **Deferred events**: Grimoire Theft, Circuit Round, Grove Awakening /
  Territory Documentation, Song Sung Back / Firelight Meeting / Name
  Forgotten, Present With Dying, Iron Library confession — all need
  either items, character travel, or per-village state that later
  modules provide. The load-bearing chains (detection, crisis, offer,
  communication, challenge, encounter, chamber) are all live.
- **Corruption reduction** is Brushgate-only in v1.0 (see above).
- Ashfields residency in practice touches army commanders and the rare
  lord — the live realms hold no silence-touched counties. The
  mechanics are in place for when Caeris's Durn and the Ashfields
  powers come online.
- **Aelindran-Legitimate** and **Ward-Broken** mythos are defined but
  dormant (need Module 9 faith and a ward-decay layer respectively).
- v1.1 queue per the doc: congenital Arcane-Blooded (accepting the
  reshuffle), congenital Silence-Touched (Caeris), full Warlock
  trajectory depth, Aurath recovery paths, the endgame Silence cascade.
