# Khessar Grand Strategy — Canon Pass Two (Implementation) v1.0
## Entity Density, the Underneath, and the Houses

Implements **"Khessar — Fable Brief Pass Two (v1.0)"** (Opus, 2026-07-14).
Companion doc: `SCALE_FAMINE_WREN.md` (Pass One). Code: `scripts/world.gd`
(the `CANON PASS TWO` section), `scripts/data/canon_data.gd`. Tests:
`tests/entity_density_test.gd`, `tests/underneath_test.gd`,
`tests/houses_test.gd`. All 22 suites green.

---

## 1. Entity density (`erng`, seed 60 — the Shade's anchor-bond; 47 is hers)

**Deferred maintenance, not an awakening.** Nothing spawns. Density is a
function of ABANDONMENT, not elapsed time — asserted with two worlds at the
same tick, one depopulated, diverging (5 anchors vs 3).

- **Vacancies** (`province_vacancies`): from famine's emptied villages
  (Pass One wiring — one vacancy per emptied village, direct), scorched and
  salted fields (+0.05/mo), decaying shrine networks (shrine-net ground,
  Orthodox coherence < 0.4, untended: +0.02/mo), and **unburied battlefields**
  — `apply_battle_result` now writes the field's dead to `unburied_fields`;
  two months later they convert at 1 vacancy per 1,000 dead (asserted).
- **Claims:** a vacancy becomes an anchor on an `erng` roll —
  `0.015 × ground pressure × min(vacancies, 10)` monthly. **Anchors never
  un-claim** on their own.
- **The inversion (§1.3, the load-bearing correction):**
  `ENTITY_PRESSURE_BY_GROUND` — wardstone 1.0 > shrine_net 0.8 > library 0.5
  > base 0.3 > unwarded 0.1. Piety was infrastructure; the deep passages are
  the proof case. Ward-stone ground stays GOOD for faith (0.60 dampening)
  and WORST for entities — deliberate, Rule Two, not flattened. Asserted:
  equal vacancies on Kharak-Dum vs the orc lowlands → 7 anchors vs 2.
  - Ground classes by region: dwarven → wardstone; vael + free_city (the
    Aelindran heartland) → shrine_net; Iron Library province → library;
    southern reach + Aurath → base (the Sovereignty's maintenance ended two
    centuries ago — FLAGGED); elven + orc → unwarded (the Elder Ways and the
    Drevak Rites kept their own). Sealed holds start with 3 vacancies each —
    the things behind them were counting.
- **The Ashfields are EXCLUDED entirely** (asserted: 50 vacancies in
  Greyreach, zero claims ever). That density has an author, fully modeled on
  `srng`. No double-counting Caeris.
- **Volume mapping:** Volume I is the working density above. **Volume II is
  the accumulation tier** — `regional_tension` accrues from war, Forsaken
  stage ≥2, and anchor-heavy ground; at 240 tension-months a region keeps
  its appointment once (the Grudge Manifest; the Pale Court for Aurath).
  Volumes III/IV are not spawnable and have no code surface.
  `silence_reform_province()` implements the living-spell rule: the Silence
  reforms where the gods' absence is most felt (highest devotion-minus-
  dampening deficit — asserted to land on shrine-net ground).
- **Counter-play** (player-initiated, may touch own realm): `cleanse_anchor`
  (25g — the only permanent answer for the old things), `resettle_province`
  (40g, −3 vacancies), `tend_shrines` (15g, 24 months), `bury_the_dead`
  (10g — asserted to remove exactly the battlefield's contribution). A ruler
  who feeds their people flattens BOTH curves; the correlation is the
  module's best argument for existing.
- **No tax/economy coupling in v1.0** — density reducing live-realm income
  would violate the stream invariant for an auto-firing system. The famine
  weight bump (+5%/anchor) and refugee pressure carry the feedback loop
  instead. FLAGGED: economy coupling belongs to Module 8, player-visible.

## 2. The Underneath (`urng`, seed 12 — the twelve pact-families)

Extends intrigue and religion rather than standing alone. Auto-fire:
ledgers only (asserted).

- **Organizations** (10 records): the Ash Vein (TOLERATED — Section Three's
  pressure valve, marked as such; strength feeds on Salt Road anchors), the
  Hidden Grain (feeds on sieges and scorch), the Bone Court (feeds on the
  refugee flow), plus the regional web (Vael Shadows, Salt Kings, Iron
  Circle, Twelve Bells, Northern Raiders, Inner Sea Circle, Ashfield Flies).
  **NAMING FLAG:** the brief's "Mediterranean Circle" is a real-world word —
  rendered as the Inner Sea Circle for Opus to re-rule.
- **The refugee loop:** famine → depopulation → refugees → Bone Court
  harvest + anchor vacancies → worse province → more famine. Pressed
  provinces (Ashfields, scorched/salted, anchor-heavy, or emptied below 60%)
  bleed 0.1–0.2%/mo toward their realm's capital (Halven for the unclaimed);
  96% arrive; the Bone Court takes 2% (4% from the Ashfields — the Flies
  feed it the ones nobody counts). Four displaced categories ledger the
  flow. By Year Six: ~159,800 taken (asserted > 0, deterministic).
- **Ten cults** — one per silent deity plus the Pale Accord, all named
  leaders from the brief. Not heretics: COERCIONISTS. Growth couples to the
  Orthodox coherence collapse (the fracture-into-coercion hook), and the
  **Empty Bowl (Ossa, the harvest god) grows on the famine curve itself** —
  asserted to accelerate (yearly growth 2.47 → 9.24) and to outgrow the
  quiet cults. States: gathering → active (33) → zealous (66).
- **Canon-pinned threads:** the Sword's Return cell (Merla Blade-True,
  Kellan Steel-Vow, Torak Iron-Word) forms at tick 54 — eighteen months of
  tracking by the Year Six present — and comes due at tick 72. **With
  `underneath_lethal = false` (default), Tavisol's Devotion oath holds the
  door** and the failed attempt leaves Iron-Faith's signed authorization as
  evidence (an event). The lethal branch exists in code, gated — whether
  cult cells may kill named souls is JUSTIN'S RULING to make. The
  Unpublished Record is PREPARING Rorend's vote by tick 66 (Sera already
  knows and has told no one — which is itself information); publication is a
  strength-gated long-campaign beat that reveals the buried secret to every
  realm.
- **Poverty is not a new variable** — the famine module plus the existing
  scalars read from below. Only the flow is new. FLAGGED: the outflow rates
  are invented tunables; six-year cumulative displacement (~7.9M
  person-moves) reads high and awaits Justin's eye.

## 3. The houses (~46) and the anchor-mage lineages

`CanonData.HOUSES` — exactly 46 entries: the Pass One twelve (with their
buried hooks), the ten class-specialization houses, Starfall (the other four
Pass Two Aelindran houses await Drive import), the three Halfling/Gnome, the
four merchant, the six regional, the six lost/Sovereignty-era, and the four
anchor-mage lineages. **Structure and hooks, per the brief** — full
heraldry/mottos/rosters stay in Drive until a data-import pass.

- **Governments follow lore** (asserted): the Magistocracy is a rotating
  mage oligarchy — administrative, never feudal, never a kingdom; Halven and
  Saren-Vesh are merchant councils; the Elven Great Houses are clans; the
  Orc clans are bloodline structures. No crowns where canon has none.
- **Seven buried secrets** planted at setup, `under: true` — OUTSIDE the
  tavern-informant and Patron-whisper pools (guards added to both sampling
  loops; asserted unknown at Year Zero): Rorend's Patron vote (subject:
  Garran — the living head carries the liability), Iorek's confession, Mira
  Crannock-Vey's Forsaken tie (subject: the real cast Mira — asserted),
  Vannin's altered memories, the Talan/Faerith romance, the Bone Court's
  noble patronage, and **the Ironbrand concealment**.
- **`investigate_house(realm, key)`** (25g, needs a Spymaster, one read per
  vault): reveals the house's buried hook to the crown. **The Ironbrand read
  is the integration that matters most:** it sets `wardstone_linkage_known`
  — the crown learns WHY the deep passages worsen (the house lying about the
  ward-stones was lying about the exact mechanism that drives entity
  density; Deepstone's research underlies the lie). A discoverable that
  unlocks a mechanical understanding, not just a scandal (asserted).
- **The anchor-mage lineages** (Pass Two §3.4 = Pass One's target list):
  Sarkenvault (green — theatrical, leaves a grove), Ossrel (debt —
  INVISIBLE; the ledger, the Bone Court liaison, the possible defector),
  Vanneth (memory — retained by Drome; their records map every house's
  concealment), the Vessrels (blood-compact — with House Straven on the
  record as the counter-example that REFUSES; the compact is not "the
  Tiefling lineage"). Dual-nature throughout: her targets, your assets.
- The Ossrel-as-famine-residual investigation hook (a province whose
  mortality exceeds its development's prediction) is carried by the
  cultivation mechanic's famine-weight bump; the full detection surface is
  FLAGGED as future work (it was the brief's own flagged invention).

## 4. Flags for Justin (Pass Two)

1. **Ward-stone double-nature** — implemented as specified (Rule Two). If it
   reads wrong in play, split "the lid muffles" from "the lid is failing."
2. **Ashfields exclusion** — implemented; confirm.
3. **Seed collision** — `erng` 60 per the brief's own resolution; 47 stays hers.
4. **Houses in code** — all 46 as data records; the twelve + four lineages
   carry live hooks. The four unnamed Pass Two Aelindran houses await import.
5. **`underneath_lethal`** — default false; the Tavisol attempt fails
   honorably until you rule cult cells may kill named characters.
6. **"Inner Sea Circle"** — renamed from the brief's "Mediterranean Circle";
   for Opus to re-rule.
7. **Refugee tunables** — outflow/intake rates invented; totals await review.
8. **Aurath ground class** — "base" (its maintenance ended with the
   Sovereignty, not the Silence); could argue "shrine_net." Yours.
