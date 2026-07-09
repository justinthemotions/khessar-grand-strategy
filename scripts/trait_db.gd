class_name TraitDB
extends RefCounted

## The trait database: every TraitData the simulation knows, keyed by name.
## Built in code so the headless sim needs no editor assets; .tres trait
## files can be merged in later without changing any consumer.

static var _db: Dictionary = {}


static func db() -> Dictionary:
	if _db.is_empty():
		_build()
	return _db


static func info(t: String) -> TraitData:
	return db()[t]


static func has_trait(t: String) -> bool:
	return db().has(t)


static func _add(t: TraitData) -> void:
	_db[t.trait_name] = t


static func _build() -> void:
	# --- personality: the classic dispositions (Module 1) ---
	_add(TraitData.make("Brave", "personality", {"mar": 3, "prw": 2},
		{"opposite": "Craven", "ai": {"aggression": 30}, "eulogy": "who never turned from a fight"}))
	_add(TraitData.make("Craven", "personality", {"mar": -3, "int": 2},
		{"opposite": "Brave", "ai": {"aggression": -40, "scheming": 10}, "eulogy": "who watched every door"}))
	_add(TraitData.make("Honest", "personality", {"dip": 2, "int": -3},
		{"opposite": "Deceitful", "ai": {"scheming": -40}, "eulogy": "whose word was oak"}))
	_add(TraitData.make("Deceitful", "personality", {"int": 4, "dip": -1},
		{"opposite": "Honest", "ai": {"scheming": 40}, "eulogy": "whom no one dared trust"}))
	_add(TraitData.make("Ambitious", "personality", {"mar": 1, "dip": 1, "stw": 1, "int": 1},
		{"opposite": "Content", "ai": {"aggression": 25, "scheming": 25, "greed": 10},
		"eulogy": "who reached for more until the end"}))
	_add(TraitData.make("Content", "personality", {"lrn": 1},
		{"opposite": "Ambitious", "ai": {"aggression": -30, "scheming": -30, "patience": 20},
		"eulogy": "who wanted for nothing"}))
	_add(TraitData.make("Cruel", "personality", {"int": 2, "dip": -2},
		{"opposite": "Compassionate", "ai": {"aggression": 25, "scheming": 15}, "eulogy": "feared by all who served them"}))
	_add(TraitData.make("Compassionate", "personality", {"dip": 2, "int": -2},
		{"opposite": "Cruel", "ai": {"aggression": -25, "scheming": -25}, "eulogy": "mourned by the small folk"}))
	_add(TraitData.make("Wrathful", "personality", {"mar": 2, "prw": 1, "dip": -2},
		{"opposite": "Patient", "ai": {"aggression": 35, "patience": -25}, "eulogy": "whose temper was legend"}))
	_add(TraitData.make("Patient", "personality", {"lrn": 2, "stw": 1},
		{"opposite": "Wrathful", "ai": {"aggression": -15, "patience": 30}, "eulogy": "who outwaited every rival"}))
	_add(TraitData.make("Gregarious", "personality", {"dip": 3},
		{"opposite": "Shy", "ai": {}, "eulogy": "who filled every hall with laughter"}))
	_add(TraitData.make("Shy", "personality", {"dip": -3, "lrn": 1},
		{"opposite": "Gregarious", "ai": {"scheming": 5}, "eulogy": "who kept their own counsel"}))

	# --- personality: tactical dispositions (battle grid hooks) ---
	_add(TraitData.make("Methodical", "personality", {"stw": 1, "lrn": 1},
		{"opposite": "Impulsive", "ai": {"aggression": -10, "patience": 30},
		"eulogy": "who never moved before the hour was right",
		"mods": {"center_line_defense_mult": 1.15, "supply_consumption_mult": 0.90, "panic_resistance": 0.25}}))
	_add(TraitData.make("Impulsive", "personality", {"mar": 1, "dip": -1},
		{"opposite": "Methodical", "ai": {"aggression": 20, "patience": -30},
		"eulogy": "who charged first and counted after",
		"mods": {"vanguard_damage_mult": 1.25, "casualty_rate_mult": 1.10, "commander_risk_mult": 1.15}}))
	_add(TraitData.make("Stoic", "personality", {"prw": 1},
		{"opposite": "Mercurial", "ai": {"patience": 20},
		"eulogy": "whom no hardship ever bent",
		"mods": {"levy_cohesion_baseline": 15.0}}))
	_add(TraitData.make("Mercurial", "personality", {"dip": 1, "int": 1},
		{"opposite": "Stoic", "ai": {"patience": -15},
		"eulogy": "of a hundred moods, all of them loud",
		"mods": {"levy_cohesion_baseline": -10.0}}))

	# --- personality: economic dispositions (ledger hooks) ---
	_add(TraitData.make("Avaricious", "personality", {"stw": 2, "dip": -2},
		{"opposite": "Altruistic", "ai": {"greed": 30},
		"eulogy": "who counted every coin twice",
		"mods": {"tax_efficiency_mult": 1.10, "guild_concession_cost_mult": 1.25}}))
	_add(TraitData.make("Altruistic", "personality", {"dip": 2, "stw": -1},
		{"opposite": "Avaricious", "ai": {"greed": -30},
		"eulogy": "whose door was never barred",
		"mods": {"tax_efficiency_mult": 0.95, "court_opinion_baseline": 10.0}}))

	# --- personality: operational dispositions (imperial hooks) ---
	_add(TraitData.make("Paranoid", "personality", {"int": 2, "dip": -2},
		{"ai": {"scheming": 10, "patience": 10},
		"eulogy": "who was right about one of the knives",
		"mods": {"intrigue_defense_mult": 1.40, "distance_decay_offset": -3.0}}))
	_add(TraitData.make("Bureaucrat", "personality", {"stw": 2, "lrn": 1},
		{"ai": {"patience": 15},
		"eulogy": "who ruled from behind a wall of ledgers",
		"mods": {"admin_cap_bonus": 2.0, "distance_decay_mitigation": 0.20}}))

	# --- congenital: the blood itself ---
	_add(TraitData.make("Genius", "congenital", {"dip": 2, "mar": 2, "stw": 2, "int": 2, "lrn": 5}, {"inherit": 0.20}))
	_add(TraitData.make("Quick", "congenital", {"dip": 1, "stw": 1, "lrn": 2}, {"inherit": 0.30}))
	_add(TraitData.make("Slow", "congenital", {"dip": -2, "stw": -2, "lrn": -3}, {"inherit": 0.25}))
	_add(TraitData.make("Herculean", "congenital", {"mar": 2, "prw": 5}, {"inherit": 0.25}))
	_add(TraitData.make("Frail", "congenital", {"mar": -1, "prw": -4}, {"inherit": 0.25}))
	_add(TraitData.make("Comely", "congenital", {"dip": 2}, {"inherit": 0.30}))
	_add(TraitData.make("Homely", "congenital", {"dip": -2}, {"inherit": 0.25}))

	# --- health ---
	_add(TraitData.make("Wounded", "health", {"prw": -4, "mar": -1}))
	_add(TraitData.make("Ailing", "health", {"prw": -2, "stw": -1}))

	# --- coping (stress scars) ---
	_add(TraitData.make("Drunkard", "coping", {"stw": -2, "mar": -1}))
	_add(TraitData.make("Reclusive", "coping", {"dip": -3, "lrn": 1}))
	_add(TraitData.make("Irritable", "coping", {"dip": -2, "int": 1}))
