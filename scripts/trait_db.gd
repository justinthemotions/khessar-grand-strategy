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
	# Canon Updates Post-Caeris v1.0: Focused is what defines someone (one
	# overwhelming purpose, exclusive); Methodical is how they work. The
	# corruption_gain_mult is the trait's tragedy — sustained purpose pays
	# costs the unfocused would not accept. vigour_points_max and
	# intrigue_detection_mult are dormant until their hooks read them.
	_add(TraitData.make("Focused", "personality", {"lrn": 2, "stw": 1, "dip": -1},
		{"opposite": "Restless", "ai": {"aggression": -10, "patience": 25, "scheming": 5},
		"eulogy": "who never turned aside from what they set themselves to do",
		"mods": {"arcane_channel_mult": 1.10, "corruption_gain_mult": 1.15,
		"stress_gain_mult": 0.95, "intrigue_defense_mult": 1.10}}))
	_add(TraitData.make("Restless", "personality", {"prw": 1, "int": 1, "stw": -1},
		{"opposite": "Focused", "ai": {"aggression": 10, "patience": -20, "scheming": 15},
		"eulogy": "who could not settle to any one thing",
		"mods": {"vigour_points_max": 1.20, "corruption_gain_mult": 0.90,
		"supply_consumption_mult": 1.05, "intrigue_detection_mult": 1.10}}))
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

	# --- personality: cultural attitude axis (Cross-Cultural Marriage v1.0) ---
	_add(TraitData.make("Syncretist", "personality", {"dip": 2, "lrn": 1},
		{"opposite": "Purist", "ai": {"patience": 10},
		"eulogy": "who set two traditions at one table",
		"mods": {"syncretism_gain": 2.0, "cross_culture_spouse_opinion": 25.0}}))
	_add(TraitData.make("Purist", "personality", {"lrn": 1, "dip": -1},
		{"opposite": "Syncretist", "ai": {"orthodoxy": 20, "patience": 5},
		"eulogy": "who kept the old ways whole",
		"mods": {"syncretism_gain": -3.0, "cross_culture_spouse_opinion": -30.0}}))

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

	# --- congenital: household heritage (Cross-Cultural Marriage v1.0) ---
	# Bicultural is raised, not rolled: assigned to children of syncretism-
	# path households by SimWorld, never by blood inheritance (inherit 0).
	_add(TraitData.make("Bicultural", "congenital", {"dip": 5},
		{"eulogy": "at home in both their parents' worlds"}))

	# --- health ---
	_add(TraitData.make("Wounded", "health", {"prw": -4, "mar": -1}))
	_add(TraitData.make("Ailing", "health", {"prw": -2, "stw": -1}))
	# long-reign fatigue: a ruler past their race's span rules a court that
	# stopped hoping for advancement a generation ago
	_add(TraitData.make("Long-Reigned", "health", {"stw": -1, "dip": -1},
		{"eulogy": "who outlived their own era",
		"mods": {"court_opinion_baseline": -10.0}}))
	# the apothecary's craft (Module 6): the Slow Weep mimics a natural
	# consumption; mithridatization is bought with years of careful dosing
	_add(TraitData.make("Wasting", "health", {"prw": -2, "mar": -1},
		{"eulogy": "who faded before their time"}))
	_add(TraitData.make("Mithridatic", "health", {},
		{"eulogy": "whom no cup could kill"}))

	# --- coping: the Silence Response substrate (Magic Injection v1.0) ---
	# Every soul alive on the Night of the Third Hour answered it somehow.
	# Coping-category by design: event-assigned, never rolled — the Year
	# Zero founder seeds stay exactly as the Faction Map wrote them.
	_add(TraitData.make("Zealous", "coping", {"dip": 1, "mar": -1},
		{"opposite": "Broken", "ai": {"orthodoxy": 30, "patience": -10, "aggression": 10},
		"eulogy": "who kept the rites when the rites no longer answered",
		"mods": {"faith_channel_reliability_baseline": 1.15, "corruption_gain_mult": 0.90}}))
	_add(TraitData.make("Broken", "coping", {"lrn": -1, "stw": -1},
		{"opposite": "Zealous", "ai": {"patience": 5, "scheming": -10},
		"eulogy": "who could not carry what the pantheon had left them",
		"mods": {"stress_gain_mult": 1.20, "faith_channel_reliability_baseline": 0.60}}))
	_add(TraitData.make("Pragmatic", "coping", {"stw": 1, "dip": 1},
		{"opposite": "Opportunistic", "ai": {"patience": 15},
		"eulogy": "who accepted what was and worked from there",
		"mods": {"tax_efficiency_mult": 1.05, "court_opinion_baseline": 5.0}}))
	_add(TraitData.make("Opportunistic", "coping", {"int": 1, "dip": 1},
		{"opposite": "Pragmatic", "ai": {"orthodoxy": -20, "scheming": 15, "patience": -5},
		"eulogy": "who found their moment in the silence",
		"mods": {"corruption_gain_mult": 1.15, "intrigue_defense_mult": 1.10}}))

	# --- coping: the eight practices (Magic Injection v1.0) ---
	# Event-authored in v1.0 (academy detection, seminaries, oaths sworn);
	# the congenital Arcane-Blooded promotion is documented for v1.1.
	_add(TraitData.make("Arcane-Blooded", "coping", {"lrn": 2, "int": 1},
		{"eulogy": "who read the world in symbols nobody else could see",
		"ai": {"orthodoxy": -5, "scheming": 5},
		"mods": {"arcane_channel_mult": 1.20, "corruption_gain_mult": 0.85,
		"supply_consumption_mult": 1.05, "intrigue_defense_mult": 1.10}}))
	_add(TraitData.make("Academy-Sworn", "coping", {"lrn": 1, "dip": 1},
		{"eulogy": "who kept the archive faith when the archive lost the mandate",
		"ai": {"orthodoxy": -10, "patience": 10},
		"mods": {"admin_cap_bonus": 1.0, "court_opinion_baseline": 5.0,
		"tax_efficiency_mult": 1.05}}))
	_add(TraitData.make("Faith-Practicing", "coping", {"dip": 1, "lrn": 1},
		{"eulogy": "who lit the candles no one answered",
		"ai": {"orthodoxy": 20, "patience": 10, "scheming": -5},
		"mods": {"faith_channel_reliability_baseline": 1.0,
		"court_opinion_baseline": 3.0, "stress_gain_mult": 1.10}}))
	_add(TraitData.make("Oath-Sworn", "coping", {"mar": 1, "dip": 1},
		{"opposite": "Oathbreaker", "eulogy": "who kept the oath the world stopped enforcing",
		"ai": {"orthodoxy": 10, "patience": 15, "aggression": -5},
		"mods": {"oath_binding_mult": 1.30, "panic_resistance": 0.15,
		"court_opinion_baseline": 5.0, "commander_risk_mult": 0.90}}))
	_add(TraitData.make("Oathbreaker", "coping", {"dip": -2, "mar": -1},
		{"opposite": "Oath-Sworn", "eulogy": "who did not keep what they had sworn",
		"ai": {"orthodoxy": -25, "scheming": 15},
		"mods": {"oath_binding_mult": 0.0, "court_opinion_baseline": -15.0,
		"corruption_gain_mult": 1.25, "intrigue_defense_mult": 0.70}}))
	_add(TraitData.make("Primal-Practiced", "coping", {"lrn": 2, "prw": 1},
		{"eulogy": "who kept faith with the roots when the sky fell silent",
		"ai": {"orthodoxy": -10, "patience": 20, "scheming": -10},
		"mods": {"primal_channel_mult": 1.30, "panic_resistance": 0.20,
		"stress_gain_mult": 0.85, "corruption_gain_mult": 0.50}}))
	_add(TraitData.make("Patron-Bound", "coping", {"lrn": 1, "int": 1},
		{"eulogy": "who bought power at a price they never fully understood",
		"ai": {"orthodoxy": -30, "scheming": 20, "aggression": 5},
		"mods": {"corruption_channel_mult": 1.40, "corruption_gain_baseline": 0.10,
		"arcane_channel_mult": 1.15, "court_opinion_baseline": -10.0}}))
	_add(TraitData.make("Song-Marked", "coping", {"dip": 2, "lrn": 1},
		{"eulogy": "who carried the names between the fires",
		"ai": {"scheming": 5, "patience": 10},
		"mods": {"word_binding_mult": 1.20, "court_opinion_baseline": 5.0,
		"song_aura_baseline": 0.05, "stress_gain_mult": 1.10}}))
	_add(TraitData.make("Brushgate-Trained", "coping", {"prw": 1, "lrn": 1},
		{"eulogy": "who remained present with the dying when others turned away",
		"ai": {"orthodoxy": -5, "patience": 25, "aggression": -5},
		"mods": {"discipline_binding_mult": 1.20, "panic_resistance": 0.40,
		"silence_immunity": 0.5, "stress_gain_mult": 0.60,
		"casualty_rate_mult": 0.85}}))

	# --- the God of Thresholds (Module 9 addendum) ---
	# An older theology that never went silent: practice is presence at
	# the moment of transition, not petition. Threshold-Sensitive is
	# congenital but NEVER rolled by chance at Year Zero (see
	# _rollable_congenitals) — it enters the world seeded canonically and
	# travels by blood at 5%, the rarity that makes it feel like weather.
	_add(TraitData.make("Threshold-Sensitive", "congenital", {"lrn": 1, "int": 1},
		{"inherit": 0.05,
		"eulogy": "who felt the crossings before others saw them",
		"ai": {"orthodoxy": 5, "patience": 15, "scheming": -5},
		"mods": {"threshold_binding_strength": 1.20, "silence_immunity": 0.25,
		"faith_channel_reliability_baseline": 1.10, "stress_gain_mult": 1.05}}))
	_add(TraitData.make("Gravewarden-Sworn", "coping", {"dip": 1, "prw": 1, "lrn": 1},
		{"eulogy": "who carved the birds for those who could not carry themselves",
		"ai": {"orthodoxy": 10, "patience": 25, "aggression": -10},
		"mods": {"threshold_binding_strength": 1.40, "silence_immunity": 0.40,
		"faith_channel_reliability_baseline": 1.20, "stress_gain_mult": 0.85,
		"corruption_gain_mult": 0.60, "panic_resistance": 0.20}}))

	# --- health: the Corruption Marks (Magic Injection v1.0) ---
	# The meter made flesh, at thresholds 5 / 10 / 15. Mark III grants
	# full silence_immunity — sufficiently entity-adjacent that the
	# Ashfields no longer bite; the only souls who walk there freely.
	_add(TraitData.make("Corruption Mark I", "health", {},
		{"eulogy": "whose hands began to darken",
		"mods": {"corruption_gain_mult": 1.10}}))
	_add(TraitData.make("Corruption Mark II", "health", {"dip": -1, "prw": -1},
		{"eulogy": "whose eye caught light wrong",
		"mods": {"corruption_gain_mult": 1.20, "court_opinion_baseline": -10.0,
		"intrigue_defense_mult": 1.30}}))
	_add(TraitData.make("Corruption Mark III", "health", {"dip": -3, "prw": -2},
		{"eulogy": "who became what they had bargained for",
		"mods": {"corruption_gain_mult": 1.30, "court_opinion_baseline": -30.0,
		"intrigue_defense_mult": 1.60, "silence_immunity": 1.0}}))

	# --- coping (stress scars) ---
	_add(TraitData.make("Drunkard", "coping", {"stw": -2, "mar": -1}))
	_add(TraitData.make("Reclusive", "coping", {"dip": -3, "lrn": 1}))
	_add(TraitData.make("Irritable", "coping", {"dip": -2, "int": 1}))
	# the failure mode of syncretism: a child who never consented to the
	# household's cultural negotiation (Cross-Cultural Marriage v1.0)
	_add(TraitData.make("Cross-Sworn", "coping", {"dip": -1, "int": 1},
		{"eulogy": "who belonged wholly to neither world"}))
