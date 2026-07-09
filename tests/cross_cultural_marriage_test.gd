extends SceneTree

## Headless validation of Cross-Cultural Marriage (v1.0):
##   <godot.exe> --headless --path . --script res://tests/cross_cultural_marriage_test.gd
## Covers the biology layer (races, half-races, lifespans), the household
## paths, the syncretism engine and Cultural Hybridization event, culture
## drift, the new traits, legacies, and mythos tags.


func _pick(world: SimWorld, realm_id: int, female: bool):
	## Deterministically pick an adult of the given court, preferring the
	## unmarried; forcibly widow one otherwise (test-only surgery).
	var best = null
	var best_score := -1
	for cid in world.characters:
		var c = world.characters[cid]
		if not c.alive or c.is_female != female or c.realm_id != realm_id:
			continue
		if c.age_years(world.tick) < 18 or c.age_years(world.tick) > 45:
			continue
		var score := 1 if c.spouse_id < 0 else 0
		if score > best_score:
			best_score = score
			best = c
	assert(best != null, "realm %d must hold an adult %s" % [realm_id, "woman" if female else "man"])
	if best.spouse_id >= 0:
		var ex = world.characters[best.spouse_id]
		ex.spouse_id = -1
		best.spouse_id = -1
	return best


func _init() -> void:
	# --- new traits registered correctly ---
	assert(TraitDB.info("Syncretist").opposite == "Purist" and TraitDB.info("Purist").opposite == "Syncretist",
		"Syncretist and Purist are one axis")
	assert(float(TraitDB.info("Syncretist").mods["syncretism_gain"]) == 2.0, "Syncretist +2 syncretism gain")
	assert(float(TraitDB.info("Purist").mods["syncretism_gain"]) == -3.0, "Purist -3 syncretism gain")
	assert(TraitDB.info("Bicultural").category == "congenital" and TraitDB.info("Bicultural").inherit_chance == 0.0,
		"Bicultural is raised, never blood-inherited")
	assert(TraitDB.info("Cross-Sworn").category == "coping", "Cross-Sworn is a coping scar")
	assert(TraitDB.info("Long-Reigned").category == "health", "Long-Reigned is a health trait")
	print("marriage traits registered: Syncretist/Purist axis, Bicultural, Cross-Sworn, Long-Reigned")

	# --- the biology layer ---
	assert(CultureData.child_race("human", "orc") == "half_orc", "Human + Orc = Half-Orc")
	assert(CultureData.child_race("orc", "human") == "half_orc", "race order must not matter")
	assert(CultureData.child_race("half_orc", "half_orc") == "half_orc", "half-races breed true")
	assert(CultureData.child_race("half_orc", "human") == "human", "quarter heritage is described by dominance")
	assert(CultureData.child_race("human", "dwarf") == "half_dwarf", "the new Half-Dwarf demographic")
	assert(CultureData.race_lifespan("half_orc") == 90 and CultureData.race_lifespan("half_elf") == 200,
		"canonical half-race lifespans")
	print("child race resolution and lifespans follow the doc")

	# mortality scales to the race's span; long lives age later
	var w0 := SimWorld.new()
	assert(w0._death_chance(60, "human") > w0._death_chance(60, "half_elf"),
		"a 60-year-old Half-Elf is young; a 60-year-old Human is not")
	assert(absf(w0._death_chance(30, "human") - w0._death_chance(30, "orc")) < 0.0001,
		"below the pivot the curves agree")
	print("mortality curves scale with racial lifespan")

	# --- syncretism affinity table ---
	assert(CultureData.syncretism_months("drevak", "karn_vol") == 120, "Drevak/Karn-Vol are nearly one already")
	assert(CultureData.syncretism_months("karn_vol", "drevak") == 120, "affinity is symmetric")
	assert(CultureData.syncretism_months("free_city", "halveni") == 240, "near-family cultures blend in 20 years")
	assert(CultureData.syncretism_months("aelindran", "karn_vol") == 720, "the border-aristocratic blend takes 60 years")
	assert(CultureData.syncretism_months("drevak", "veldarin") == 960, "mutual antipathy all but never blends")
	assert(CultureData.syncretism_months("vael", "sovereignty") == -1, "the dead culture never blends")
	assert(CultureData.syncretism_months("vael", "vael") == -1, "same culture has nothing to blend")
	print("syncretism thresholds match the Roster affinities")

	# --- hybrids: named, runtime, and roster rights ---
	assert(CultureData.hybrid_of("aelindran", "karn_vol") == "border_compact_aristocratic",
		"the named Roster hybrid is found regardless of order")
	var novel := CultureData.hybrid_of("free_city", "karn_vol")
	assert(CultureData.hybrid_parents(novel).has("free_city") and CultureData.hybrid_parents(novel).has("karn_vol"),
		"a hybrid the world has not seen registers at first use (Scenario 1)")
	assert(CultureData.satisfies("border_compact_aristocratic", "aelindran"), "hybrids muster both parents' rosters")
	assert(CultureData.satisfies("border_compact_aristocratic", "karn_vol"), "hybrids muster both parents' rosters")
	assert(CultureData.satisfies("border_compact_aristocratic", "drevak"),
		"subvariant rights chain through: a Karn-Vol hybrid still fields Drevak doctrine")
	assert(not CultureData.satisfies("vael_aristocratic", "kharak_dum"), "no rights to unrelated rosters")
	print("hybrid cultures inherit both parents' martial rosters")

	# --- the live sim: races seeded, cross-realm wedding opens a record ---
	var world := SimWorld.new()
	world.auto_resolve_events = true
	world.setup()
	for cid in world.characters:
		var c = world.characters[cid]
		assert(c.race == ("human" if c.realm_id == 0 else "orc"), "the Vael court is Human, the clan is Orc")
	print("Year Zero courts carry their canonical races")

	# arrange a syncretism-path Human-Orc marriage: an adult Vael man and
	# an adult clan woman, dispositions forced for determinism
	var groom = _pick(world, 0, false)
	var bride = _pick(world, 1, true)
	groom.traits.erase("Purist")
	bride.traits.erase("Purist")
	bride.traits.erase("Syncretist")  # keep the gain formula deterministic
	if not groom.traits.has("Syncretist"):
		groom.traits.append("Syncretist")
	var groom_root: int = world.root_house_id(groom.dynasty_id)
	var bride_root: int = world.root_house_id(bride.dynasty_id)
	var err: String = world.marry(groom.id, bride.id)
	assert(err == "", "the wedding must proceed: %s" % err)
	var rec: Dictionary = world._marriage_record(groom.id, bride.id)
	assert(not rec.is_empty(), "a cross-culture wedding opens a household record")
	assert(str(rec["path"]) == "syncretism", "a Syncretist groom sets a syncretism household")
	assert(int(rec["threshold"]) == 720, "Aelindran + Karn-Vol ripens in 60 years")
	assert(world.has_mythos(groom_root, "Compact-Bound"), "a Human-Orc union marks the groom's line")
	assert(world.has_mythos(bride_root, "Compact-Bound"), "and the bride's")
	print("cross-realm wedding: syncretism path, Compact-Bound earned on both roots")

	# opinion: the Syncretist loves his cross-culture wife
	var base_opinion: int = world.opinion_of(groom.id, bride.id)
	groom.traits.erase("Syncretist")
	assert(world.opinion_of(groom.id, bride.id) == base_opinion - 25,
		"Syncretist is worth +25 toward a cross-culture spouse")
	groom.traits.append("Syncretist")
	print("cross-culture spouse opinion follows disposition")

	# --- children of the household: Half-Orc and Bicultural ---
	var child = world._make_child(groom, bride)
	assert(child.race == "half_orc", "the child of Human and Orc is a Half-Orc")
	assert(child.traits.has("Bicultural"), "a syncretism household raises Bicultural children")
	assert(child.culture == groom.culture, "the child practices at the father's court")
	print("a Half-Orc, Bicultural child is born to the compact marriage")

	# --- the syncretism engine ---
	var gain: float = world.syncretism_gain(rec)
	# base 1 + Syncretist 2 + one bicultural child 1 (realm 0 holds no karn_vol land)
	assert(absf(gain - 4.0) < 0.001, "gain = 1 base + 2 Syncretist + 1 bicultural child, got %f" % gain)
	world.at_war = true
	assert(absf(world.syncretism_gain(rec) - (gain - 5.0)) < 0.001, "war with the other culture's realm costs -5")
	world.at_war = false
	print("the monthly accumulation formula matches the doc")

	# The Preserving Line freezes it; the Syncretic Charter hastens it
	var gdyn = world.dynasties[groom_root]
	gdyn.renown = 1000.0
	var buy_err: String = world.buy_legacy(groom_root, "The Preserving Line")
	assert(buy_err == "", "the dynasty can afford the legacy: %s" % buy_err)
	assert(not world.has_mythos(groom_root, "Pure of Blood"),
		"no Pure of Blood for a line with a cross-race marriage in it")
	assert(world.buy_legacy(groom_root, "The Syncretic Charter") != "", "the two legacies are mutually exclusive")
	var before: float = float(rec["progress"])
	world._syncretism_tick()
	assert(float(rec["progress"]) == before, "The Preserving Line stops the clock")
	gdyn.legacies.erase("The Preserving Line")
	world._syncretism_tick()
	assert(float(rec["progress"]) > before, "with the legacy gone, the household ripens again")
	# a clean line that forswears the blending earns the name for it
	var clean_root := -1
	for house_id in [0, 1, 2, 3]:
		var root: int = world.root_house_id(house_id)
		if root != groom_root and root != bride_root:
			clean_root = root
			break
	assert(clean_root >= 0, "one founding house stayed out of the match")
	world.dynasties[clean_root].renown = 500.0
	var _b2: String = world.buy_legacy(clean_root, "The Preserving Line")
	assert(world.has_mythos(clean_root, "Pure of Blood"), "a clean Preserving line claims Pure of Blood")
	print("legacies: exclusivity, the frozen clock, Pure of Blood")

	# --- Cultural Hybridization fires and can be adopted ---
	rec["progress"] = float(rec["threshold"])
	var resolved_before: int = world.events_resolved_by_ai
	world._syncretism_tick()
	assert(world.events_resolved_by_ai == resolved_before + 1,
		"reaching the threshold raises the event, and the AI resolves it headlessly")
	# whatever the AI chose, force the Adopt outcome deterministically
	if groom.culture != "border_compact_aristocratic":
		world._adopt_hybrid(rec, groom, bride, "border_compact_aristocratic")
	assert(groom.culture == "border_compact_aristocratic" and bride.culture == "border_compact_aristocratic",
		"the household adopts the hybrid")
	assert(child.culture == "border_compact_aristocratic", "the bicultural children ARE the new culture")
	assert(world.culture_drift.size() == 4, "the realm's four Aelindran counties begin to drift, got %d" % world.culture_drift.size())
	print("Cultural Hybridization: Border-Compact-Aristocratic is born (the once-in-history blend)")

	# --- drift converts land and opens both rosters ---
	for i in 100:
		world._culture_drift_tick()
	assert(world.culture_drift.is_empty(), "a hundred months completes every drift")
	var drifted := 0
	for p in world.map.provinces:
		if p.culture == "border_compact_aristocratic":
			drifted += 1
	assert(drifted == 4, "the four counties now follow the hybrid's ways")
	assert(world.recruit_gate(0, "compact_sworn") == "", "hybrid land musters the Compact-Sworn (in peace)")
	assert(world.recruit_gate(0, "drevak_berserker") == "", "and the parent Drevak doctrine")
	assert(world.recruit_gate(0, "aelindran_household_cavalry") == "", "without losing Household Cavalry")
	print("culture drift converts the land and unlocks both parents' rosters")

	# --- rejection produces the Cross-Sworn ---
	var world2 := SimWorld.new()
	world2.auto_resolve_events = true
	world2.setup()
	var g2 = _pick(world2, 0, false)
	var b2 = _pick(world2, 1, true)
	g2.traits.erase("Purist")
	b2.traits.erase("Purist")
	if not g2.traits.has("Syncretist"):
		g2.traits.append("Syncretist")
	var _e2: String = world2.marry(g2.id, b2.id)
	var rec2: Dictionary = world2._marriage_record(g2.id, b2.id)
	var kids: Array = []
	for i in 3:
		b2.last_birth_tick = -999
		kids.append(world2._make_child(g2, b2))
	world2._reject_hybrid(rec2, g2, b2)
	assert(str(rec2["path"]) == "imposition" and float(rec2["progress"]) == 0.0,
		"rejection reverts the household to imposition")
	var scarred := 0
	for k in kids:
		if k.traits.has("Cross-Sworn"):
			scarred += 1
	print("rejection reverts to imposition; %d of 3 bicultural children grow Cross-Sworn" % scarred)

	# --- household paths at the extremes ---
	var world3 := SimWorld.new()
	world3.auto_resolve_events = true
	world3.setup()
	var g3 = _pick(world3, 0, false)
	var b3 = _pick(world3, 1, true)
	g3.traits.erase("Syncretist")
	b3.traits.erase("Syncretist")
	if not g3.traits.has("Purist"):
		g3.traits.append("Purist")
	if not b3.traits.has("Purist"):
		b3.traits.append("Purist")
	var _e3: String = world3.marry(g3.id, b3.id)
	assert(str(world3._marriage_record(g3.id, b3.id)["path"]) == "parallelism",
		"two Purists keep two courts under one roof")
	var stress_before: float = g3.stress
	world3._syncretism_tick()
	assert(g3.stress > stress_before, "parallelism grinds on both spouses monthly")
	print("household paths: two Purists produce parallelism and its monthly toll")

	print("\nALL CROSS-CULTURAL MARRIAGE CHECKS PASSED")
	quit(0)
