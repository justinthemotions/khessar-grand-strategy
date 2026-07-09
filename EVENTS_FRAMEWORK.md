# The Event Framework — Technical Briefing

Choice events with trait-weighted AI resolution. Core in `scripts/world.gd`
(§ "the event framework"), popup UI in `scripts/main.gd`. This is the pipe that
Module 4's vassal demands, faction ultimatums, and Curia politics will flow through.

## 1. Design

- **An event is pure data**: `{id, realm_id, decider, title, text, options}`.
  Each option: `{label: String, effect: Callable, ai: {axis: weight}, base: float}`.
- **One pipe for everyone.** Player-realm (realm 0) events queue in
  `world.pending_events` and emit `event_raised` → the UI pauses the game and shows a
  modal popup. Every other realm's events — and *all* events in headless mode
  (`world.auto_resolve_events = true`) — are resolved on the spot by the decider's
  personality. NPCs and the player face the same choices with the same consequences.
- **Effects are closures** created at raise time, capturing exactly the state they
  need. They log their own chronicle lines. (Save/load will require reifying these —
  a known future task, acceptable for the prototype.)

## 2. API

```gdscript
world.raise_event(realm_id, decider_id, title, text, options)
    # options empty → no-op. realm_id != 0 or auto_resolve_events → AI resolves now.

world.resolve_event(event_id, option_index)   # the player path, called by the popup

world.pending_events   # queue the UI reads (index 0 is shown)
world.events_resolved_by_ai   # counter, printed by the headless test
```

## 3. AI option scoring (`_ai_resolve_event`)

```
score(option) = option.base + rng() × 12 + Σ_axis ai_weight(decider, axis) × option.ai[axis]
```
`ai_weight` sums the decider's trait weights on that axis (see CHARACTER_ENGINE.md §4);
axes: `aggression`, `scheming`, `greed`, `patience`, `orthodoxy`. Option `ai` values are
scaled roughly −1..+1, so a trait weight of 30 contributes ±30 — dominant but not
deterministic against the ±12 jitter. Verified behavior: a Wrathful/Brave/Ambitious
decider (aggression 90) picks the `{aggression: +1}` option ~12/12 times.

Guidelines for authoring options:
- `base` is the "default temperament" — give the safe/boring option a positive base so
  neutral characters take it.
- Keep axis weights in −1..+1; reserve |1| for options that *define* the axis.
- Options must be safe to run months later (player may sit on the popup): re-check
  state inside the effect (e.g. `_adjust_legitimacy` no-ops if the interregnum closed).
- Build options conditionally — don't offer "Pay 60 gold" when the treasury can't
  cover it; `raise_event` with a single option is fine (it just resolves that way).

## 4. The three shipped conversions

1. **The Homage Tour** (`_homage_tour`, during an interregnum): each house head with a
   negative opinion of the claimant raises an event — *Pay their price (60 gold)*
   (base 14, greed −0.3, patience +0.2 → legitimacy +4) vs *Refuse — the crown begs no
   one* (aggression/greed positive → legitimacy −8, −20 memory on the head).
2. **A Mind at its Limit** (`add_stress` at a break threshold): choose the coping scar —
   *Drown it in wine* (Drunkard), *Withdraw from the world* (Reclusive), *Let the anger
   fester* (Irritable) — each option's `ai` leans on matching axes; only addable traits
   are offered; break bookkeeping (stress −60, level +1) happens before the choice.
3. **Whispers of a Plot** (`_plots_tick`): when a hostile plot crosses 50% progress the
   victim's court rolls detection once (`0.30 + Spymaster.intrigue × 0.015`, ×
   the target's `intrigue_defense_mult` — Paranoid targets hear more). On detection the
   target realm's ruler chooses: *Triple the guard (50 gold)* (kills the plot),
   *Bait a trap* (intrigue contest: expose the agents and cost the plotter 150 gold +
   a −40 memory, or catch nothing), *Dismiss the whispers* (nothing — maybe).
   `Realm.plot_warned` prevents repeat warnings per plot.

## 5. The popup UI (`main.gd`)

`_build_event_popup()` creates a hidden centered PanelContainer (built last → draws on
top; `set_anchors_and_offsets_preset(PRESET_CENTER)` — the runtime-overlay gotcha).
`event_raised` → `_show_next_event()`: pauses time (`speed_index = 0`), shows title,
the decider's procedural portrait, story text, and one button per option; a click calls
`world.resolve_event(id, index)` and shows the next queued event if any.
Dev aid: `--screenshot` stages a demo Homage Tour event so the popup is in the capture.

## 6. Testing

Headless tests set `world.auto_resolve_events = true` immediately after `setup()` so
every choice (mental breaks, homage demands, plot warnings) resolves synchronously via
trait AI — the 60-year run asserts `events_resolved_by_ai > 0`. The framework test
exercises: queueing for realm 0, `resolve_event` picking a specific option, and the
hawk test (aggression-loaded decider must overwhelmingly pick the aggressive option).

## 7. Adding a new event (checklist)

1. Build options conditionally; capture needed state in locals before the lambdas.
2. Give each option `label`, `effect`, sensible `base`, and −1..+1 `ai` axis weights.
3. Effects re-validate state and `_log` their own outcome lines.
4. `raise_event(realm_id, decider_id, title, text, options)` — decider is whoever's
   personality should choose (usually the realm's ruler, but any character works).
5. If the event should also fire for AI realms, you're done — the same call handles it.
6. Add a headless assertion if the event is load-bearing (count its chronicle line).
