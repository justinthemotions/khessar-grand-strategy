extends SceneTree

## Canon Pass One §2: the famine module. The curve's anchors, the 110M
## census, the Architect's forecast agreeing with the ledger, stream
## discipline, and the one action that bends the actual below the
## forecast. Run:
##   <godot.exe> --headless --path . --script res://tests/famine_module_test.gd

func _init() -> void:
	print("=== famine module test (Canon Pass One) ===")

	# --- group 1: the curve, verified to the brief's decimals ---
	var world := SimWorld.new()
	world.setup()
	world.auto_resolve_events = true
	assert(absf(world.famine_rate(1.0) - 0.0036) < 0.0002,
		"Year 1 must be 0.36%%/yr (got %.5f)" % world.famine_rate(1.0))
	assert(absf(world.famine_rate(6.0) - 0.0150) < 0.0005,
		"Year 6 must be 1.50%%/yr — one in sixty-six (got %.5f)" % world.famine_rate(6.0))
	assert(absf(world.famine_rate(40.0) - 0.0200) < 0.0005,
		"the plateau is 2.00%%, per Justin's ruling of 2026-07-14")
	var six_year := 0
	var forty_year := 0
	for y in range(1, 41):
		forty_year += int(world.architect_forecast[y])
		if y <= 6:
			six_year += int(world.architect_forecast[y])
	assert(six_year > 5_900_000 and six_year < 6_150_000,
		"the six-year cumulative is ~6,023,000 (got %d)" % six_year)
	assert(forty_year > 78_000_000 and forty_year < 82_000_000,
		"the forty-year cumulative is ~79,870,000 (got %d)" % forty_year)
	print("curve: Y1 %.4f, Y6 %.4f, six-year %d, forty-year %d — the arithmetic holds" % [
		world.famine_rate(1.0), world.famine_rate(6.0), six_year, forty_year])

	# --- group 2: the census — 110M exactly, distributed by tier ---
	var total_pop := 0
	var vael_pop := 0
	var ash_pop := 0
	for p in world.map.provinces:
		total_pop += p.pop
		if p.name == "Vael":
			vael_pop = p.pop
		if p.terrain == "ashfields":
			ash_pop += p.pop
	assert(total_pop == 110_000_000, "the continent holds 110,000,000 exactly (got %d)" % total_pop)
	assert(vael_pop >= 4_000_000, "the primate province carries the capital's 800k and its hinterland")
	assert(ash_pop > 0 and ash_pop < 4_000_000, "the Ashfields are inhabited, thinly — Durn holds on")
	print("census: %d total, Vael province %d, Ashfields %d" % [total_pop, vael_pop, ash_pop])

	# --- group 3: stream discipline — famine auto-fire is ledger-only ---
	var probe := SimWorld.new()
	probe.setup()
	probe.auto_resolve_events = true
	probe.tick = 13  # inside Year 2, so the tick has work to do
	var gold0: float = probe.realms[0].gold
	var gold1: float = probe.realms[1].gold
	var tyr0: float = probe.realms[0].tyranny
	var pres0: float = probe.realms[0].prestige
	for i in 12:
		probe._famine_tick()
	assert(probe.realms[0].gold == gold0 and probe.realms[1].gold == gold1,
		"famine auto-fire must never touch live realms' gold")
	assert(probe.realms[0].tyranny == tyr0 and probe.realms[0].prestige == pres0,
		"famine auto-fire must never touch tyranny or prestige")
	assert(probe.famine_deaths_total > 0, "the ledger itself must fill — that is its module")
	print("discipline: 12 direct famine ticks moved the ledger and nothing else")

	# --- group 4: forecast vs actual — the two columns agree ---
	var w2 := SimWorld.new()
	w2.setup()
	w2.auto_resolve_events = true
	for i in 24:
		w2.advance_month()
	assert(w2.famine_actual_by_year.has(1) and w2.famine_actual_by_year.has(2),
		"two completed years belong in the ledger")
	var fc1 := int(w2.architect_forecast[1])
	var ac1 := int(w2.famine_actual_by_year[1])
	assert(absf(float(ac1 - fc1)) / float(fc1) < 0.01,
		"Year 1 actual must agree with the forecast under no player action (fc %d, ac %d)" % [fc1, ac1])
	assert(w2.villages_emptied >= 0, "the village counter is the player-facing surface")
	assert(w2.famine_records_lines() != "", "the Records Sublevel readout must exist")
	print("forecast Y1 %d vs actual %d — the columns agree; %d villages emptied" % [fc1, ac1, w2.villages_emptied])

	# --- group 5: two-world determinism ---
	var w3 := SimWorld.new()
	w3.setup()
	w3.auto_resolve_events = true
	for i in 24:
		w3.advance_month()
	assert(int(w3.famine_actual_by_year[1]) == ac1, "the same history writes the same ledger")
	assert(w3.famine_deaths_total == w2.famine_deaths_total, "totals must match across worlds")
	for pid in [14, 31, 59]:
		assert(w3.map.provinces[pid].pop == w2.map.provinces[pid].pop,
			"province %d population must be deterministic" % pid)
	print("determinism: two worlds, identical ledgers")

	# --- group 6: open granaries — bending the actual below the forecast ---
	var wa := SimWorld.new()
	wa.setup()
	wa.auto_resolve_events = true
	var wb := SimWorld.new()
	wb.setup()
	wb.auto_resolve_events = true
	var target_pid := 31  # the capital province — the biggest share
	wb.realms[0].gold = 200.0
	var gold_before: float = wb.realms[0].gold
	var err := wb.open_granaries(0, target_pid)
	assert(err == "", "opening the granaries should succeed (got '%s')" % err)
	assert(wb.realms[0].gold == gold_before - 30.0, "the grain costs the crown 30 gold — player actions MAY touch the player's realm")
	for i in 12:
		wa.advance_month()
		wb.advance_month()
	var dead_a := int(wa.famine_dead_by_pid.get(target_pid, 0))
	var dead_b := int(wb.famine_dead_by_pid.get(target_pid, 0))
	assert(dead_b < dead_a,
		"open stores must bend the province's deaths below the unaided line (a %d, b %d)" % [dead_a, dead_b])
	assert(int(wa.famine_actual_by_year[1]) >= int(wb.famine_actual_by_year[1]),
		"a fed province bends the continental actual at or below the forecast")
	print("granaries: %d dead unaided vs %d fed — the only argument the curve listens to" % [dead_a, dead_b])

	print("ALL FAMINE MODULE CHECKS PASSED")
	quit()
