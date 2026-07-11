# The World the Silence Made — Technical Briefing (v1.0 implementation of Opus's doc v1.1)

Implements **"Khessar Grand Strategy — The World the Silence Made (v1.1)"** (Opus,
2026-07-08, Drive `19Cmw0eZS4AHKx3nymYC3n3jKJrcYDYc-uENjeGOmOkM`): Caeris the
Unfinished as the **ethical antagonist** — the v1.0 tactical-necromancer miscast is
dead — plus the Forsaken regional movements and a light Year-50 convergence.
Everything lives in `scripts/world.gd` (section "The World the Silence Made") with
UI in `scripts/main.gd`'s Diplomacy tab and tests in `tests/silence_made_test.gd`.

## 1. The stream discipline (read this first)

All Silence-made dice roll on **`srng`, seed 63** — the percentage of himself Caeris
still measures as alive. `raise_event` gained a tenth argument `silence := true`
routing AI jitter to `srng` (precedence: silence > vigil > admin > faith > magic).

The invariant, stricter here than in any prior module: **auto-firing beats touch only
the Ashfields ledger, the Forsaken counters, and (only past tick 250, behind the
religion brief's canon-asserted Year-20 numbers) the Silent Path's membership.** They
never touch live realms' gold, tyranny, prestige, or opinions. Player-initiated
actions (envoy, commit, endorsement embassies, the march) may — the player's own
history is theirs to bend. This is why all 15 prior suites pass unmodified.

Caeris's scripted deaths (settling at tick 660, or destruction) draw **zero** dice:
`_kill` is stream-silent for him — no spouse, no parents, no titles, not notable to
the epitaph writer, and `_threshold_on_death` finds only himself in realm 99 and
returns before the frng roll.

## 2. Caeris the Unfinished (doc §2)

Seeded in `_seed_silence_made()` (end of `setup()`), on srng only — the cast stream
closed with Thessaly and never feels him.

- **Male scholar, 62** (born Year −62), human, `free_city` culture (a Pellar
  healer's son; twenty years in the Iron Library). `caeris_id`.
- Core Six **14/8/16/12/26/6** — set AFTER traits so trait stat-mods cannot drift
  the canon numbers (gotcha: `_add_trait` applies `TraitData.stats`).
- Traits: `Threshold-Sensitive`, `Patient`, `Methodical` (canon says "Focused" —
  nearest db trait, **flagged for Opus**). NO Patron-Bound, NO Corruption Marks —
  those were v1.0's miscast.
- `realm_id = ASHFIELDS_REALM (99)` — a sentinel: `is_cast()` is true by
  construction (≥2), so every main-stream guard covers him for free.
  `map.realm_display_name(99)` → "The Ashfields"; `cast_title_of` → "Scholar of
  the Ashfields" (no crown — a research environment).
- `full_name` → **"Caeris the Unfinished"** via dynasty "House the Unfinished".
- **Maret** (`maret_id`, "House of the Ashfields") — the Revenant research
  associate, MM Vol. II. Gender/stats Fable-invented, **flagged**.

## 3. The Ashfields ledger (`world.ashfields`, doc §3–4)

Year Zero: `living 4000`, Returned ≈500 (`recently 300 / settling 150 / settled 40 /
hollow 10`), `warden_dead 200` (defense, never a sword), `anchored 0`.

`_ashfields_tick()` (monthly, inside `_silence_made_tick()` after `_vigil_tick`):

- **Settling flows** (unanchored only): recently→settling 10%/mo,
  settling→settled 3.5%/mo, settled→hollow 1.2%/mo. The tragedy is ongoing.
- **Intake, never conquest**: 8–17 souls/mo (srng) × `ashfields_intake_mult()` —
  doc §3's modifiers: framework collaboration +50%, active consent research +25%,
  confident Orthodoxy (coh ≥.45 ∧ mem ≥.45) −30%, Silent Path active +40%, Halvar
  alive (proper witnessing elsewhere) −20%, floor 0.2. Living +25% of intake
  (families who stay), warden_dead +5%. Ashfields provinces stay `owner -1` forever.
- **Recognition thresholds** 5k/10k/25k → chronicle beats, once each.
- **Framework staging** and **Caeris's decline** (below).

## 4. The consent framework (doc §5) — the collaboration path

Player API (all on the Diplomacy tab):

1. `ashfields_send_envoy(0)` — gated by `ashfields_envoy_gate`: ruler Learning ≥ 16,
   tick ≥ 12. Raises "The Scholar of the Ashfields" (silence event): four
   conversation options per the doc; every one sets `contacted`. The fourth —
   "ask about the anchoring working directly" — appears only when ruler Learning ≥ 20
   **or** Thessaly leads the Library, and sets `finding_heard`.
2. `ashfields_commit_framework(0)` — needs `finding_heard` + **Thessaly free to
   lead** (`_thessaly_leads_library()`: alive ∧ Marek dead — i.e. post-Year-Four).
   Stage 1 begins; the committing realm's seal is endorsement #1.
3. `ashfields_seek_endorsement(map_realm_id)` — 40g embassies. Dispositions are
   **deterministic trait scores, no dice**: Compassionate +2, Patient/Methodical/
   Gregarious/Honest +1, Zealous −3, Wrathful −2, Paranoid −1; accept at ≥1.
   Canon fallout: **Eithne of Pellar declines** (Zealous) even though her own
   archivist sponsors the work; Ferren and Vessa accept. Three seals needed.
4. Stage 1→2 at 3 seals + 12 months (the drafting council convenes — Halvar speaks
   for the Gravewardens if alive, Brushgate observes, Free City law drafts).
   Stage 2→3 after 18 months → `_framework_implemented()`.

**Publication**: `resolved = "framework"`. Retroactive anchors save 60% of
recently + 30% of settling into `anchored`; the Settled cannot be brought back
(Caeris's covering letter says so plainly). New intake Returns anchored. Orthodox
coherence −0.05. Caeris gains a purpose beyond waiting; his settling (if begun)
stops. The doc's most transformative and stable outcome.

## 5. The military option (doc §6) — `ashfields_march(0)`

Runs the realm's main army against ⌈warden_dead/40⌉ Warden-Dead companies + Caeris's
Retinue, on `"ashfields"` terrain with silence ground — the Tactical Combat layer's
binary gates, terror, and regen starvation all apply. Caeris commands side 1
(M8/I12/P6, Threshold-Sensitive/Patient/Methodical — **supersedes** the old
Tactical-doc commander block of terror 0.50 / corruption_channel 1.60, which was
v1.0-Caeris). Casualties write back to the player roster.

**Win** → `_ashfields_destroyed()`: Caeris and Maret die; **the finding is lost and
the settling problem becomes unsolvable**; the Returned disperse undirected
(`dispersed`, decaying 1%/mo with wandering-shade chronicle beats); 4,000 living
scatter as refugees; the Iron Library records "one of the most consequential wrong
choices of the post-Silence period"; Orthodox coherence +0.10; Silent Path +3%
membership +0.05 coherence (suppression over understanding); the ruler takes
**+2 corruption and +20 stress** — the ethical weight is mechanical.

**Loss** → the Warden-Dead do not pursue past the boundary stones. Caeris files the
engagement with the Library as a failure of communication he finds professionally
frustrating.

**Ignored** → at tick 600 Caeris begins to settle (Thessaly's field note: he
repeated himself); at 660 he settles entirely — `resolved = "settled"`, the finding
unpublished on his desk. The specific late-game tragedy, on schedule.

## 6. The Forsaken (doc §7–8)

`forsaken_movements`: five regional variants (vael academy cells, Halven
Underground, Free City independence circles, Karn-Vol new-compact generation,
Southern Reach cosmopolitan current), each `{strength, stage, growth_mult, engaged}`.

`_forsaken_tick()` monthly: growth `(0.5 + 0.05·years) × jitter(0.8–1.2) ×
growth_mult`, ×1.4 under an active Silent Path, ×0.9 Southern Reach. Stages at
**10/50/200/500** (whispered/visible/political/dominance). At *visible*, live realms
(0→vael, 1→karn_vol) get the engage-or-suppress event — **effects stay inside the
movement's own ledger** (engage: growth ×0.85; suppress: −15 strength now, growth
×1.15 — suppression is the best recruiter the movement ever had). At *dominance* the
**`forsaken_militia` recruit gate opens** (`recruit_gate` now checks
`forsaken_region_of(realm_id)` strength ≥ 500 — the Tactical Combat pass's IOU paid).
Movements at dominance feed Silent Path membership +0.0004/mo each, only past tick
250 (canon-assert protection). Traveler Forsaken occasionally cross into the
Ashfields to study — regional and character-specific, per the doc, not
movement-uniform.

## 7. Convergence (doc §9) — deliberately light

At tick 600 (Year 50) `_convergence_tick()` fires "The World the Silence Made" once:
a summary of all three antagonist structures' states, then four options — **Unified
Response** (only offered if the framework holds AND the Architect's truth is
revealed/leveraged/contained), Military Solution, Ideological Surrender, Endure.
The choice names `world.convergence` ("unified"/"military"/"ideological"/
"fragmented") and writes the chronicle. **The full Silence-cascade mechanics are
deferred to the endgame module** — every option's log says so. This keeps the
auto-firing event stream-neutral for the 60-year headless run.

## 8. UI

Diplomacy tab, "The Ashfields" section: status line (`ashfields_status_line()` +
`forsaken_status_line()`), Send an Envoy, Commit to the Framework, endorsement
OptionButton + Seek Endorsement (40g), and March on the Ashfields (tooltip: "The
military option. Consider what is lost.").

## 9. Testing

`tests/silence_made_test.gd`, 8 groups: canonical shape (male, 62, L26, no Patron
taint, realm 99, names), intake-not-conquest (+191 souls/2yr, provinces untouched),
settling progression, the full collaboration arc (envoy → Marek-gate → 3 seals with
Eithne's canonical refusal → council → publication → anchored intake), the military
option (18 picked regiments win; finding lost, corruption +2, 500 dispersed,
Orthodox +coherence), Forsaken stages + militia gate, Year-50 convergence resolution,
and two-world determinism. All 15 prior suites green unmodified.

## 10. Flags for Opus

- "Focused" has no TraitDB entry — Caeris carries `Methodical` as the nearest
  discipline-shaped trait. Add "Focused" to the db, or bless the proxy.
- Maret's gender and stats are Fable-invented (MM Vol. II gives the name and the
  Revenant state only).
- The old Tactical Combat doc's Caeris commander block (terror 0.50,
  corruption_channel 1.60) described v1.0-Caeris and is superseded; the implemented
  block is the v1.1 scholar. COMBAT_SYSTEM.md §14.7's "Caeris awaits her faction"
  flag is resolved — *he* is on the map now.
- Legendary Actions (Observe, Redirect, Settling Touch) are folded into the
  commander-scale defense; per-action tactical mechanics await hero-scale battle
  units.
- Contact currently requires the *ruler's* Learning ≥ 16 — the engine has no
  envoy-character abstraction yet; when characters travel, gate on the envoy.
- Endgame convergence is chronicle-level; the four endings' full mechanical
  consequences (cascade, fragmentation into successor states) belong to the
  endgame-cascade module already on the roadmap.
- Refugee mechanics (doc §3, 5%/yr of adjacent provinces) are folded into the
  intake/living flows — per-province refugee flows need the population layer
  (Module 8+).
