# Dynasty, House & Inheritance — Technical Briefing (Module 2)

The multi-generational layer of the Khessar Grand Strategy prototype. All in
`scripts/world.gd` unless noted; UI in the Dynasty tab of `scripts/main.gd`.

## 1. Houses form a tree

`SimWorld.Dynasty` is one **House**: `{id, name, parent_id, founder_id, charter,
renown, legacies[], mythos[], kin_cruelty, poisonings, crown_months}`.
- `parent_id == -1` → a founding house (Varen, Coldwell, Drace, Mirel at start).
- Cadet branches keep `parent_id` pointing at the house they split from.
- `root_house_id(house_id)` walks up the tree **but stops at co-equal/schismatic
  charters** — those branches are their own dynasty. The whole loyalist tree pools
  its Renown and legacies **on the root house**.
- Characters carry `dynasty_id` = their *house*; children take the father's house.

**Heads are computed, never stored**: `house_head(house)` = crowned member first, then
eldest man, then eldest (`_outranks`); bastards excluded. `dynasty_head(root)` = the
most senior of all branch heads. Powers belong to whoever the math says — if the
player's ruler isn't the dynasty head, the Head's Word buttons are disabled.

## 2. Cadet branches & Charters

`found_cadet_branch(char_id, charter)` — requirements (`can_found_cadet`): trueborn
adult man, not house head, not a ruler, married with a living child, house ≥ 6 living,
not denounced. The founder and his living male-line descendants move to the new house
(`_move_line_to_house`). Names: "House <Name>son" (Aldmark) / "House <Name>ović" (Sarova).

Charter types (`CHARTERS`, gated by `charter_allowed`):
- **loyalist** — needs goodwill toward the dynasty head. Stays in the renown pool
  (+20 renown on founding); +10 opinion between branch and the rest of the tree.
- **coequal** — needs root renown ≥ 200; takes 100 renown as endowment; becomes its
  own root. No authority either way.
- **schismatic** — needs a grievance (negative opinion of the head, or `aggrieved`).
  Own root, plus a **Blood Feud** appended to `world.blood_feuds` — −40 opinion between
  the two trees, permanent, inherited by everyone ever born into either.

Auto-splitting (`_cadet_branch_tick`): eligible men roll 0.002/month (+0.006 if
Ambitious); bitter + Wrathful/Ambitious founders choose schismatic on their own.

## 3. Renown (dynasty currency)

`_renown_tick` accrues monthly on each root: +3 per crowned member, +0.6 per council
seat, +0.4 per army command, +0.3 per county title, +0.8 per duchy title, +0.1 per
living adult, +0.5 per extra branch, +1 with the Blood of Kings mythos; ×1.25 with the
Chronicled Deeds legacy. Fame flows from power held.

## 4. Legacies (`LEGACIES`, bought via `buy_legacy`)

Permanent bloodline-wide perks: **Chronicled Deeds** (150r, +25% renown gain),
**Golden Ledgers** (250r, +10% realm income while the dynasty holds the crown),
**Blood of the Wolf** (350r, children born +1 Martial/+1 Prowess, +8% levy capacity
while ruling), **Unbending Oaths** (500r, +15 opinion between all dynasty members,
+0.5 monthly stress relief). Effects are wired inline at their point of effect
(`_economy`, `levy_capacity`, `_make_child`, `opinion_of`, `_stress_relief_tick`).
Sarova's ruling dynasty buys its own (`_ai_dynasty`).

## 5. Dynasty Head Powers (`POWER_COST`, spend root renown)

- **dh_disinherit** (100r): flag `disinherited`; excluded from succession stages 1–2;
  target takes a −60 memory of the head; Compassionate heads take stress; counts as
  kin-cruelty (§6).
- **dh_legitimize** (150r): clears `is_bastard`; +40 memory toward the head; every
  trueborn adult sibling takes a −30 "a bastard raised above me" memory.
- **dh_denounce** (50r): flag `denounced` — instantly stripped of council seats and
  commands, −30 opinion from everyone, unseatable/uncommandable/ungrantable; −50
  memory; counts as kin-cruelty.
- **dh_call_to_war** (200r, only at war): every house in the tree sends a free sword
  regiment (36 men) to the head's realm muster, bypassing the levy cap.

## 6. The House Mythos file

Permanent reputational tags on the root (`mythos[]`), earned by counters:
- **Kin-Eater** — 3 acts of kin-cruelty (disinherits + denouncements): −10 opinion
  from everyone outside the dynasty.
- **Whispered Poisoners** — 2 successful assassinations while your dynasty rules the
  plotting realm: −10 opinion from foreigners, but plots progress ×1.15.
- **Blood of Kings** — 480 consecutive months with a member on a throne: +5 opinion
  from all, +1 renown/month.
All are checked in `opinion_of` / `_plots_tick` / `renown_gain`; tags never expire and
apply to every member of the bloodline, including the unborn.

## 7. The Interregnum (succession is a phase, not a click)

On a ruler's death, `_succession` picks the heir (law-ordered; bastards/disinherited
excluded; extinct line → spawned distant kinsman), then `_begin_interregnum`:
- Starting legitimacy = `40 + heir.diplomacy − 15 × rivals` (+5 Gregarious, −10 if a
  rescue kinsman), clamped 5–95. *Rivals* (`_claimants_against`) = adult trueborn
  kinsmen of the heir's house with a "passed over" memory or the `aggrieved` flag,
  not `bought_off` / disinherited / denounced.
- While open: realm income ×0.6, levy capacity ×0.75.
- Four monthly stages (`_interregnum_tick`):
  1. **Secure the treasury** (gold ≥ 50 → +5, else −5)
  2. **The blessing** (Lawspeaker's learning/4, or −5 with no Lawspeaker)
  3. **The Homage Tour** — loyal house heads +4 each; hostile heads raise a **choice
     event**: pay 60 gold (+4) or refuse (−8 and a −20 memory)
  4. **The Coronation** — if legitimacy < 50 and a rival exists: **palace coup**
     (success chance `0.3 + (50−legit)×0.012 + rival.intrigue×0.01`, capped 0.8).
     Success: the rival takes the crown (−80 "stole my crown" memory on the heir).
     Failure: 50% hanged for treason, else disgraced with mutual −60 memories.
     Otherwise: crowned, +25 root renown.

## 8. Wills & Bequests

`grant_bequest(realm, child_id)` — 150 gold to a living adult non-heir child of the
ruler. Refusal chance 15% (+45% Ambitious, −15% Content). Accepted → `bought_off`
(will never coup) and a +40 memory. Refused → the **hidden `aggrieved` flag** (+ a −20
"bought with a purse" memory) — they take the gold and rise at the coronation anyway.
Passed-over Ambitious siblings also become `aggrieved` automatically at succession.

## 9. Bastardy

Adult men roll 0.003/month to father a bastard with an unmarried woman of the realm
(`_bastards_tick`, max one scandal logged per month). The child joins the father's
house flagged `is_bastard` (no succession, no house headship) until legitimized.
A living wife takes a −20 memory and +10 stress.

## 10. UI (Dynasty tab, main.gd)

Renown ticker + gain rate; mythos & blood-feud lines; house list with charters and
heads; legacy purchase buttons; the four Head's Word powers with candidate dropdowns
(disabled unless the player ruler *is* the dynasty head); bequest section; cadet
founding with a charter picker. `_player_root()` = root of the player ruler's house.
