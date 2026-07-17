extends SceneTree

## Canon Pass Two §2: the Underneath. Ten cults that grow on collapse
## and hunger, three continental organizations, the refugee loop feeding
## the Bone Court, and the two canon-pinned intrigue threads. Run:
##   <godot.exe> --headless --path . --script res://tests/underneath_test.gd

func _init() -> void:
	print("=== underneath test (Canon Pass Two) ===")

	# --- group 1: the cast of the under-floor ---
	var world := SimWorld.new()
	world.setup()
	world.auto_resolve_events = true
	assert(world.cults.size() == 10, "ten cults: one per silent deity plus the Pale Accord")
	assert(world.criminal_orgs.size() == 10, "three continental organizations and the regional web")
	assert(bool(world.criminal_orgs["ash_vein"]["tolerated"]),
		"the Ash Vein is quietly tolerated — Section Three's pressure valve")
	assert(str(world.cults["empty_bowl"]["deity"]) == "Ossa",
		"the Empty Bowl argues with the harvest god — the most naturally explosive of the ten")
	print("cast: 10 cults, 10 organizations, the valve marked as a valve")

	# --- group 2: the Empty Bowl grows on the famine curve ---
	var s_start: float = float(world.cults["empty_bowl"]["strength"])
	for i in 12:
		world.advance_month()
	var bowl_y1: float = float(world.cults["empty_bowl"]["strength"]) - s_start
	var mark: float = float(world.cults["empty_bowl"]["strength"])
	for i in 48:
		world.advance_month()
	var mark5: float = float(world.cults["empty_bowl"]["strength"])
	for i in 12:
		world.advance_month()
	var bowl_y6: float = float(world.cults["empty_bowl"]["strength"]) - mark5
	assert(bowl_y6 > bowl_y1,
		"Ossa's cult must accelerate as the famine curve rises (y1 %.2f, y6 %.2f)" % [bowl_y1, bowl_y6])
	assert(float(world.cults["empty_bowl"]["strength"]) > float(world.cults["fifth_road"]["strength"]),
		"during a famine that kills one in sixty-six, the Empty Bowl outgrows the road-god's riddle")
	print("empty bowl: yearly growth %.2f -> %.2f — wired to the hunger itself" % [bowl_y1, bowl_y6])

	# --- group 3: refugees walk, and the Bone Court waits ---
	assert(world.refugee_flow_month >= 0.0, "the flow ledger exists")
	assert(world.bone_court_taken > 0,
		"six years of Ashfields outflow: the Bone Court's count cannot be zero")
	assert(float(world.criminal_orgs["bone_court"]["strength"]) > 22.0,
		"intake feeds the one unambiguous evil")
	var total_displaced := 0
	for k in world.displaced:
		total_displaced += int(world.displaced[k])
	assert(total_displaced > 0 and int(world.displaced["ashfields"]) > 0,
		"the displaced categories fill from the pressed provinces")
	print("the roads: %d displaced, %d taken — famine -> refugees -> harvest, the loop is the module" % [
		total_displaced, world.bone_court_taken])

	# --- group 4: the canon-pinned threads at the Year Six present ---
	assert(int(world.cults["swords_return"]["cell_formed"]) == 54,
		"the cell has tracked Tavisol for eighteen months at Year Six — it formed at tick 54")
	assert(bool(world.cults["swords_return"]["attempt_done"]),
		"eighteen months of patience come due at tick 72")
	var tavisol_alive := false
	for c in world.characters.values():
		if c.alive and c.name == "Tavisol" and c.hero_level > 0:
			tavisol_alive = true
	assert(tavisol_alive,
		"with underneath_lethal false (Justin's ruling pending), the Devotion oath holds the door")
	assert(bool(world.cults["unpublished_record"]["prepared"]),
		"the Unpublished Record is preparing Rorend's vote at the Year Six present")
	assert(not bool(world.cults["unpublished_record"]["published"]),
		"prepared is not published — the thread is live, not spent")
	print("threads: the cell formed, the attempt held, the Record prepares — Sera has told no one")

	# --- group 5: stream discipline ---
	var probe := SimWorld.new()
	probe.setup()
	probe.auto_resolve_events = true
	probe.tick = 30
	var gold0: float = probe.realms[0].gold
	var tyr0: float = probe.realms[0].tyranny
	var pres0: float = probe.realms[0].prestige
	for i in 12:
		probe._underneath_tick()
	assert(probe.realms[0].gold == gold0 and probe.realms[0].tyranny == tyr0 and probe.realms[0].prestige == pres0,
		"the Underneath's auto-fire must never touch a live realm's stats")
	print("discipline: 12 direct underneath ticks, ledgers only")

	# --- group 6: two-world determinism ---
	var w2 := SimWorld.new()
	w2.setup()
	w2.auto_resolve_events = true
	for i in 72:
		w2.advance_month()
	assert(w2.bone_court_taken == world.bone_court_taken, "the same roads carry the same losses")
	for key in w2.cults:
		assert(absf(float(w2.cults[key]["strength"]) - float(world.cults[key]["strength"])) < 0.001,
			"cult growth must be deterministic (%s)" % key)
	print("determinism: two worlds, the same under-floor")

	print("ALL UNDERNEATH CHECKS PASSED")
	quit()
