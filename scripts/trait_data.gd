class_name TraitData
extends Resource

## One trait as a data asset (Khessar GS): identity, inheritance, Core Six
## modifiers, AI behavioral weights, and *named systemic hooks* that the
## engine's subsystems query directly — the battle grid reads vanguard and
## cohesion mults, the ledger reads tax efficiency, the scheme system reads
## intrigue defense. Traits are conditional flags and math, not stat blocks.
##
## Being a Resource, traits can also be authored as .tres files in the
## editor and dragged onto characters or event conditions later; the
## built-in database lives in TraitDB so the headless sim needs no assets.

@export_category("Identity")
@export var trait_name: String = ""
@export var category: String = "personality"   # personality | congenital | health | coping
@export var opposite: String = ""              # mutually exclusive trait, by name
@export var eulogy: String = ""                # epitaph fragment: "who ..."

@export_category("Inheritance")
@export var inherit_chance: float = 0.0        # congenital: chance per parent copy

@export_category("Core Six Modifiers")
@export var stats: Dictionary = {}             # {"mar": 3, "stw": -2, ...}

@export_category("AI Behavioral Weights")
## Axes the AI reads when scoring event options and strategic decisions:
##   aggression — war declarations, ultimatums, risky attacks
##   scheming   — plots, double-crosses, baited traps
##   greed      — debasement, taxation, taking gold over goodwill
##   patience   — delaying, attrition, weathering sieges (negative = rash)
##   orthodoxy  — faith and heresy interactions (dormant until Module 9)
@export var ai: Dictionary = {}

@export_category("Systemic Engine Hooks")
## Named modifiers, queried by key at the point of effect. Live hooks:
##   vanguard_damage_mult, center_line_defense_mult, casualty_rate_mult,
##   panic_resistance, levy_cohesion_baseline    (battle grid)
##   supply_consumption_mult, commander_risk_mult (campaign military)
##   tax_efficiency_mult, admin_cap_bonus         (the ledger)
##   intrigue_defense_mult                        (the scheme system)
##   court_opinion_baseline                       (opinion web)
## Magic Injection v1.0 hooks (live):
##   corruption_gain_mult, corruption_gain_baseline   (the Patron's ledger)
##   stress_gain_mult                                 (add_stress, now trait-aware)
##   faith_channel_reliability_baseline               (Cleric geography formula)
##   arcane_channel_mult, primal_channel_mult,
##   oath_binding_mult, word_binding_mult,
##   song_aura_baseline, discipline_binding_mult,
##   corruption_channel_mult                          (battle commander hooks)
##   silence_immunity                                 (≥1.0 = Silence-touched land cannot mark you)
## Declared now, wired when their module lands:
##   guild_concession_cost_mult (M8), heresy_spread_chance (M9),
##   decadence_generation, distance_decay_offset (M10)
@export var mods: Dictionary = {}


static func make(p_name: String, p_category: String, p_stats: Dictionary, extra: Dictionary = {}) -> TraitData:
	var t := TraitData.new()
	t.trait_name = p_name
	t.category = p_category
	t.stats = p_stats
	t.opposite = extra.get("opposite", "")
	t.eulogy = extra.get("eulogy", "")
	t.inherit_chance = extra.get("inherit", 0.0)
	t.ai = extra.get("ai", {})
	t.mods = extra.get("mods", {})
	return t
