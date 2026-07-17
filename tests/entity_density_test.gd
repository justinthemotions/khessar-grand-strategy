extends SceneTree

## Canon Pass Two §1: entity density. Abandonment drives it, not elapsed
## time; ward-stone ground outpaces unwarded ground (piety was
## infrastructure); the Ashfields are excluded; the counter-play works;
## the auto-fire is ledger-only. Run:
##   <godot.exe> --headless --path . --script res://tests/entity_density_test.gd

func _init() -> void:
	print("=== entity density test (Canon Pass Two) ===")

	# --- group 1: the pressure table and the ground classes ---
	assert(float(CanonData.ENTITY_PRESSURE_BY_GROUND["wardstone"]) > float(CanonData.ENTITY_PRESSURE_BY_GROUND["shrine_net"]),
		"the deep passages are the proof case — heaviest maintenance, hardest failure")
	assert(float(CanonData.ENTITY_PRESSURE_BY_GROUND["shrine_net"]) > float(CanonData.ENTITY_PRESSURE_BY_GROUND["base"]),
		"dense pre-Silence devotion is dense post-Silence vacancy")
	assert(float(CanonData.ENTITY_PRESSURE_BY_GROUND["unwarded"]) < float(CanonData.ENTITY_PRESSURE_BY_GROUND["base"]),
		"a region that never had wards barely changed")
	var world := SimWorld.new()
	world.setup()
	world.auto_resolve_events = true
	assert(world.entity_ground(world.map.provinces[10]) == "wardstone", "Kharak-Dum is ward-stone ground")
	assert(world.entity_ground(world.map.provinces[14]) == "library", "the Iron Library holds more of the sky up")
	assert(world.entity_ground(world.map.provinces[0]) == "unwarded", "the Drevak Rites never asked for wards")
	assert(world.entity_ground(world.map.provinces[43]) == "", "the Ashfields are EXCLUDED — that density has an author")
	assert(float(world.province_vacancies.get(7, 0.0)) >= 3.0, "the sealed holds start with vacancies — the things behind them were counting")
	print("ground: wardstone 1.0 > shrine_net 0.8 > library 0.5 > base 0.3 > unwarded 0.1; realm 99 excluded")

	# --- group 2: abandonment drives density, not elapsed time ---
	var wa := SimWorld.new()
	wa.setup()
	wa.auto_resolve_events = true
	var wb := SimWorld.new()
	wb.setup()
	wb.auto_resolve_events = true
	wb.province_vacancies[15] = 20.0  # a vael march empties (same tick, different abandonment)
	for i in 36:
		wa.advance_month()
		wb.advance_month()
	var anchors_a := int(wa.province_anchors.get(15, 0))
	var anchors_b := int(wb.province_anchors.get(15, 0))
	assert(anchors_b > anchors_a,
		"two worlds at the same tick: the depopulated one fills (a %d, b %d)" % [anchors_a, anchors_b])
	print("abandonment: same tick, vacancies %d anchors vs %d — time alone is inert" % [anchors_b, anchors_a])

	# --- group 3: the inversion — wardstone fills faster than unwarded ---
	var w3 := SimWorld.new()
	w3.setup()
	w3.auto_resolve_events = true
	w3.province_vacancies[10] = 10.0  # Kharak-Dum, wardstone
	w3.province_vacancies[0] = 10.0   # orc lowlands, unwarded
	for i in 48:
		w3.advance_month()
	var ward_anchors := int(w3.province_anchors.get(10, 0))
	var unwarded_anchors := int(w3.province_anchors.get(0, 0))
	assert(ward_anchors > unwarded_anchors,
		"equal vacancy, unequal ground: the ward-stone province must fill faster (%d vs %d)" % [ward_anchors, unwarded_anchors])
	print("inversion: wardstone %d anchors vs unwarded %d from equal vacancies" % [ward_anchors, unwarded_anchors])

	# --- group 4: the Ashfields never claim ---
	var w4 := SimWorld.new()
	w4.setup()
	w4.auto_resolve_events = true
	w4.province_vacancies[43] = 50.0
	for i in 24:
		w4.advance_month()
	assert(int(w4.province_anchors.get(43, 0)) == 0,
		"realm 99's ground never enters the continental pressure model — no double-counting Caeris")
	print("exclusion: 50 vacancies in Greyreach, zero claims — his work is his own")

	# --- group 5: unburied fields become vacancy ---
	var w5 := SimWorld.new()
	w5.setup()
	w5.auto_resolve_events = true
	var v_before: float = float(w5.province_vacancies.get(15, 0.0))
	w5.unburied_fields[15] = {"dead": 3000, "tick": w5.tick}
	for i in 3:
		w5.advance_month()
	var delta_unburied: float = float(w5.province_vacancies.get(15, 0.0)) - v_before
	assert(delta_unburied >= 2.9,
		"three thousand unburied dead are three vacancies — the ground notices")
	# ...and burial prevents exactly the battlefield's contribution (the
	# famine's own vacancies continue regardless — that loop is separate)
	var w6 := SimWorld.new()
	w6.setup()
	w6.auto_resolve_events = true
	w6.unburied_fields[15] = {"dead": 3000, "tick": w6.tick}
	w6.realms[0].gold = 50.0
	var berr := w6.bury_the_dead(0, 15)
	assert(berr == "", "burial is the cheapest ward there is (got '%s')" % berr)
	var v6: float = float(w6.province_vacancies.get(15, 0.0))
	for i in 3:
		w6.advance_month()
	var delta_buried: float = float(w6.province_vacancies.get(15, 0.0)) - v6
	assert(delta_buried <= delta_unburied - 2.5,
		"BURY YOUR DEAD — a proper grave removes the battlefield's three vacancies (unburied +%.2f, buried +%.2f)" % [delta_unburied, delta_buried])
	print("unburied: +%.2f vacancies in three months; buried: +%.2f — the grave-detail earns its wage" % [delta_unburied, delta_buried])

	# --- group 6: stream discipline + the counter-play ---
	var probe := SimWorld.new()
	probe.setup()
	probe.auto_resolve_events = true
	probe.province_vacancies[15] = 10.0
	var gold0: float = probe.realms[0].gold
	var tyr0: float = probe.realms[0].tyranny
	for i in 12:
		probe._entity_tick()
	assert(probe.realms[0].gold == gold0 and probe.realms[0].tyranny == tyr0,
		"entity auto-fire must never touch a live realm's stats")
	probe.province_anchors[15] = 2
	probe.realms[0].gold = 50.0
	var cerr := probe.cleanse_anchor(0, 15)
	assert(cerr == "" and int(probe.province_anchors[15]) == 1 and probe.realms[0].gold == 25.0,
		"cleansing an anchor is the only permanent answer, and the player pays for it")
	probe.realms[0].gold = 60.0
	var rerr := probe.resettle_province(0, 15)
	assert(rerr == "", "resettlement empties the vacancy ledger (got '%s')" % rerr)
	var reform_pid := probe.silence_reform_province()
	assert(reform_pid >= 0 and probe.entity_ground(probe.map.provinces[reform_pid]) == "shrine_net",
		"the Silence reforms where the gods' absence is most felt — the devout ground")
	print("counter-play: cleanse, resettle, bury — governance, not set-dressing")

	print("ALL ENTITY DENSITY CHECKS PASSED")
	quit()
