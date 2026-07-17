# Khessar Grand Strategy — Canon Pass One (Implementation) v1.0
## Scale, Famine, and the Iron Wren

Implements **"Khessar — Fable Brief Pass One (v1.1)"** (Opus, 2026-07-15 — the
revision that retracted the forty-year Architect timeline). Companion doc:
`ENTITY_UNDERNEATH_HOUSES.md` (Pass Two). Code: `scripts/world.gd` (the
`CANON PASS ONE` section), `scripts/data/canon_data.gd`,
`scripts/world_map.gd` (the `pop` field). Tests: `tests/famine_module_test.gd`,
`tests/iron_wren_test.gd`. All 22 suites green.

---

## 1. Scale and the census

- `CanonData.CONTINENTAL_POP = 110_000_000` — Pangea-scale, ~0.74 souls/km²,
  eleven percent of Earth's pre-industrial ceiling. Khessar is EMPTY, and
  nobody is coming to help.
- Every province carries `pop`, seeded deterministically (no dice) from the
  Settlements doc's named figures × a hinterland multiplier (3.0, INVENTED),
  plus per-region base weights (INVENTED), normalized to exactly 110,000,000.
  The rounding remainder settles on the primate province (Vael, 6.023M).
- **Mapping deviations, flagged:** "Iron Deep" → Kharak-Dum's province;
  "Grimhold surface hold" → Bronhold; "Veldarin"/"Thaladris" → each house's
  seat province; "Kag'thuk" → Karn-Vol-Gar. The map has no provinces by the
  doc's names; the seats hold the figures.
- **Travel scale (§1's flag): left untouched.** Army movement stays tuned to
  playability, per the brief's own advice. Justin holds the ruling.

## 2. The famine module (`grng`, seed 66 — one in sixty-six)

**The curve** — `famine_rate(t) = 0.0200 / (1 + 7.687·e^(−0.5230·t))`:

| anchor | canon | measured |
|---|---|---|
| Year 1 | 0.36%/yr (396,000) | 0.0036 ✓ |
| Year 6 | 1.50%/yr — one in 66 (1,650,000) | 0.0150 ✓ |
| plateau | 2.00%/yr (Justin's ruling 2026-07-14) | 0.0200 ✓ |
| six-year cumulative | ~6,023,000 | 6,023,140 ✓ |
| forty-year cumulative | ~79,870,000 (73%) | 79,869,898 ✓ |

The annual arithmetic is **year-end point rates** (`rate(Y) × 110M`), which is
exactly how the brief's own six-year figure reconciles — verified before
implementing. The monthly tick draws `rate(Y)/12 × 110M` through year Y.

**Distribution below the curve** (all INVENTED, flagged): each province's
share = pop × development mitigation (tax as the proxy — the repo has no CK
Development scalar; flagged) × control (occupied/partisan ×1.5, unclaimed
×1.25) × war state (siege ×2.5, scorch ×2.0, salt ×1.6) × terrain archetype ×
entity pressure (+5%/anchor — Pass Two's loop) × relief (granaries ×0.5).
Renormalized monthly so the weighted sum walks the canon curve regardless.
**The Ashfields are excluded** — that hunger belongs to Caeris's ledger
(`srng`), same principle as the entity exclusion.

**Stream discipline:** auto-fire touches only the famine ledger and province
pops (asserted). Player-initiated `open_granaries(realm, pid)` (30 gold, 12
months, halves the province's weight) may touch the player's own realm — a
fed province bends the actual BELOW the forecast, the only thing in the game
that proves the Architect wrong about something (asserted: 14,489 unaided vs
7,976 fed in the test year).

**The player-facing surface is domestic, not statistical.** The raw number
never headlines. It lives in the Records Sublevel readout (Council tab),
beside the forecast — plus the emptied-villages counter and the "Village That
Stopped Writing" events. `raise_event` gained `famine` as its eleventh
argument, routing AI jitter to `grng` (then `wren`/`entity`/`under`).

**The Architect's forecast as a data object:** `architect_forecast[1..40]`,
generated at setup from the same formula. Each year the actual is written
beside it. THE COLUMNS AGREE (asserted within 1%). He ran it six years ago at
seventy-seven, sealed it alone, and dies Month 72 with thirty-four forecast
years left. **FLAG (the brief's own):** who keeps the tally after Veril is
undesigned and belongs to Justin.

## 3. The Iron Wren (`wrng`, seed 47 — the trees at Vetral)

**Who she is in code: nobody.** Not a census character, not a hero, not in
any pool — asserted. She is world-state: an independent map-actor on her own
stream, a weather system with a grudge. No opinions, no demands, no deals.

- **Timeline, played out live from Year Zero:** at setup she is twelve and
  the map does not know her name. Tick 12: Vetral becomes a grove (Sark,
  forty-seven trees). Tick 14: the hunt begins. The historical seven strikes
  are **canon-pinned** to ticks [18, 27, 36, 45, 54, 63, 71] — seven tokens
  by Year Six is the brief's fixed fact, so the past is a ledger, not a die;
  WHICH unnamed mage dies in which season rolls on `wrng`. From tick 72 the
  study→strike cycle runs live (named masters take 10–14 months — they keep
  guards). Asserted at tick 72: **7 tokens, age 18, un-making 38.0**, Sark
  dead, every named master alive. The eighth strike lands ~tick 83 unaided.
- **The roster** (15): Sark + six unnamed pre-campaign targets (INVENTED,
  flagged — the legend counts seven tokens and names only Sark) + the named
  eight: Velren/Ferrin/Sella (Sarkenvault), Selva/Kell/Mira (Ossrel), Arren
  (Vanneth), Weyland (Vessrel). Ages stored at Year Zero (brief gives Year
  Six ages; subtract six).
- **Targeting:** records value + Sarkenvault ×3 (personal) + Salt Road
  proximity + obstructors' cultivated assets first, on `wrng`.
- **The five event chains:** Hunter Arrives (informational options only —
  the mechanical answers are council actions, so auto-resolve stays
  ledger-only), The Mage You Were Cultivating, The Magistocracy's Request
  (tick 40), The Accidental Ally (a strike inside your siege lines), and
  Obstruction (score ≥3 → your assets weight up; she can only be outlived).
- **Player actions:** `shield_anchor_mage` (40g, +6 study months, obstruction
  +1 — asserted to delay the strike), `warn_anchor_mage` (free, +3),
  `cultivate_anchor_mage` (50g — quiets a district off the books; the
  district pays; the rider comes for your assets), `assist_hunt_wren` (25g,
  +3 prestige, obstruction +2, she works elsewhere for two years, is never
  caught).
- **Hard constraints as API:** `wren_offer_target()` refuses anything not on
  the anchor-mage roster — "the line is at the anchoring" (asserted). The
  tick-58 beat plays the refusal on-screen: Section Three offers her a
  Forsaken organizer and learns something that worries them more than the
  tokens.
- **The un-making:** progress from records taken (38.0 by Year Six). At 60:
  the Vetral attempt, 25% — success is a small miracle, failure the honest
  ending, both canon-compatible, neither softened (this seed's history:
  **failed; she has not stopped**). At 85 (after Vetral): **the eighth
  working is the consent token** — `wren_knows_token = true` from setup;
  retrieval on a 50% attempt, retried every 30 months (she does not abandon
  it).
- **Voided ≠ ash (the brief's §3.6 check, resolved):** the consent token sets
  `patron_anchor_voided` — a DISTINCT state from `patron_network_broken`
  (main.gd:1340's ash path). Voided gates the Patron state machine from
  ADVANCING (no new authorization) while existing bindings stand and
  exposure still travels. The two mechanisms coexist; deeper wiring (e.g.
  refusing new Patron's Bargain legacy purchases while voided) is FLAGGED
  for a future ruling.

## 4. Flags for Justin (Pass One)

1. **Population distribution** — hinterland ×3.0, region bases, terrain
   multipliers: all invented; the 110M total and settlement figures are canon.
2. **Famine modifiers** — the four multiplier families are invented; the
   curve is canon and renormalization protects it.
3. **Travel scale** — untouched, per the brief's own advice. Your ruling.
4. **The tally after Veril** — undesigned, yours.
5. **The six unnamed tokens** — names/provinces/workings invented (flagged
   in `CanonData.ANCHOR_MAGES`); Sark's age invented (51 at Year Zero).
6. **Irnholt** — the map keeps it on the west coast (illustration wins);
   the Settlements doc omits it. Unresolved upstream; nothing here depends
   on the answer.
7. **Wren mortality** — she has no death path in v1.0 ("she can only be
   outlived"). If she should be killable, that is a design decision.
