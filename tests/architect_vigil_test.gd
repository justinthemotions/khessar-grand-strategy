extends SceneTree

## The Architect's Vigil v1.0 test (Opus's Vigil doc, 2026-07-08): Veril
## Ormand's five phases of dawning awareness, the alternate-recipient
## evaluation, the Phase Four contact, the Phase Five choice, the Year
## Six death, and the truth's escape into a world that was not the world
## he prepared for. Run from the project folder:
##   <godot.exe> --headless --path . --script res://tests/architect_vigil_test.gd

func _init() -> void:
	var world := SimWorld.new()
	var events: Array = []
	world.event_logged.connect(func(t: String) -> void: events.append(t))
	world.setup()
	world.auto_resolve_events = true

	# --- 1. the Architect at Year Zero (doc §1) ---
	var veril: SimCharacter = world.characters.get(world.architect_id)
	assert(veril != null and veril.alive, "Veril Ormand exists at Year Zero")
	assert(veril.age_years(world.tick) == 77,
		"Veril is 77 on the Night of the Third Hour (doc §1 canon; got %d)" % veril.age_years(world.tick))
	assert(world.architect_phase == 1, "Phase One: confident waiting — he does not yet know")
	assert(world.vigil_status_line() != "", "the Records Sublevel reads out to the court")
	var thessaly: SimCharacter = world.characters.get(world.thessaly_id)
	assert(thessaly != null and thessaly.alive, "Thessaly Vorn is seeded with the cast")
	assert(world.is_cast(thessaly), "Thessaly lives outside the main stream's dice")
	var marek: SimCharacter = world.characters.get(world.marek_id)
	assert(marek != null and marek.alive, "Marek Vovel keeps the Iron Library at Year Zero")
	print("year zero ok — the Architect is 77, confident, and wrong about who is coming")

	# --- 2. the recipient weights at Year Zero (doc §6 Phase 2) ---
	var w := world.vigil_candidates()
	assert(w.has("marek") and absf(float(w["marek"]) - 20.0) < 0.001,
		"Marek: +40 the Library, -20 the years he lacks (got %s)" % str(w.get("marek")))
	assert(w.has("sevrin") and absf(float(w["sevrin"]) - 15.0) < 0.001,
		"Sevrin unseated: +25 Pragmatic, -10 youth (got %s)" % str(w.get("sevrin")))
	assert(w.has("halvar") and absf(float(w["halvar"]) - 25.0) < 0.001,
		"Halvar: +30 the Order, +10 respect, -15 the outsider (got %s)" % str(w.get("halvar")))
	assert(not w.has("thessaly"), "Thessaly requires Vovel's death first")
	assert(w.has("sera") and absf(float(w["sera"]) - 15.0) < 0.001,
		"Sera: +20 House, -20 youth, +15 the old claim's access (got %s)" % str(w.get("sera")))
	var sera: SimCharacter = world.characters.get(world.sera_id)
	assert(sera != null and sera.age_years(world.tick) == 17,
		"Sera Halvenard-Veil is 17 at Year Zero — 23 by Year Six, as Garran's aging was for (got %d)" % sera.age_years(world.tick))
	print("weights ok — the doc's numbers, live against the world")

	# --- 3. the landscape the player shaped moves the weights (doc §3) ---
	var halvar: SimCharacter = world.characters.get(world.halvar_id)
	halvar.wooden_birds_carved += 8
	var w2 := world.vigil_candidates()
	assert(float(w2["halvar"]) > float(w["halvar"]),
		"the Order's visible work raises Halvar in Veril's ledgers")
	halvar.wooden_birds_carved -= 8
	var vroot: int = world.root_house_id(veril.dynasty_id)
	world.dynasties[vroot].legacies.append("The Iron Library Compact")
	var w3 := world.vigil_candidates()
	assert(float(w3["marek"]) > float(w["marek"]),
		"a House bound to the archive raises the archive's standing")
	world.dynasties[vroot].legacies.erase("The Iron Library Compact")
	print("landscape ok — player-shaped state reaches the second journal")

	# --- 4. the arc on schedule (doc §2, §6 Phase 1) ---
	while world.tick < 30:
		world.advance_month()
	assert(world.architect_phase == 2, "Month 30: quiet uncertainty (got phase %d)" % world.architect_phase)
	while world.tick < 42:
		world.advance_month()
	assert(world.architect_phase == 3, "Month 42: acknowledged crisis")
	while world.tick < 45:
		world.advance_month()
	assert(not marek.alive, "Marek Vovel dies in Year Four (doc §2 Phase Four) — a scheduled beat")
	var w4 := world.vigil_candidates()
	assert(w4.has("thessaly") and float(w4["thessaly"]) >= 35.0,
		"the Library's discipline passes to Thessaly, inherited whole")
	assert(not w4.has("marek"), "the dead do not stand in the evaluation")
	while world.tick < 54:
		world.advance_month()
	assert(world.architect_phase == 4, "Month 54: active recomposing")
	assert(world.vigil_contact_target != "", "Veril reached for someone at Month 54")
	while world.tick < 66:
		world.advance_month()
	assert(world.architect_phase == 5, "Month 66: the termination phase")
	assert(world.vigil_sealed or world.vigil_delivery_tick > 0 or world.vigil_recipient != "",
		"Phase Five resolves to acceptance or active delivery")
	assert(veril.spouse_id < 0,
		"he did not marry again (the Voice doc's canon) — the pool draws his die and passes him by")
	while world.tick < 72:
		world.advance_month()
	assert(not veril.alive, "Veril Ormand dies in Year Six — the clock the chamber was always running on")
	assert(veril.age_years(world.tick) == 83, "he dies at 83, as the chamber's timeline holds (got %d)" % veril.age_years(world.tick))
	while world.tick < 100:
		world.advance_month()
	assert(world.central_secret_state != "buried",
		"the truth escapes into the world after the vigil (state: %s)" % world.central_secret_state)
	assert(world.architect_phase == 6, "the vigil is over")
	var found_ledger := false
	for e in events:
		if str(e).contains("forty springs deep"):
			found_ledger = true
	assert(found_ledger, "the small ledger is found in the first room")
	print("arc ok — five phases on schedule, death in Year Six, and the truth loose: %s" % world.central_secret_state)

	# --- 5. the player's lever: an intercepted contact forces 5A (doc §2 Phase Five) ---
	var world2 := SimWorld.new()
	world2.setup()
	world2.auto_resolve_events = false
	while world2.tick < 54:
		world2.advance_month()
		# resolve everything the crown is asked EXCEPT the vigil contact:
		# intercept that. Default everything else to option 0.
		while not world2.pending_events.is_empty():
			var ev: Dictionary = world2.pending_events[0]
			if bool(ev.get("vigil", false)):
				world2.resolve_event(int(ev["id"]), 2)  # intercept the letter
			else:
				world2.resolve_event(int(ev["id"]), 0)
	assert(world2.vigil_contact == "intercepted", "the crown intercepted the letter (got %s)" % world2.vigil_contact)
	world2.auto_resolve_events = true
	while world2.tick < 76:
		world2.advance_month()
	assert(world2.vigil_sealed, "a watched road forces acceptance: the chamber is sealed (5A)")
	assert(world2.vigil_recipient == "", "no delivery happened on the intercepted road")
	assert(world2.central_secret_state != "buried",
		"the race for the door still puts the truth in someone's hands (state: %s)" % world2.central_secret_state)
	print("player lever ok — interception forces 5A, and the chamber race decides the first reader")

	# --- 6. the recipients' roads reach distinguishable endings (doc §5) ---
	var world3 := SimWorld.new()
	world3.setup()
	world3.auto_resolve_events = true
	world3.vigil_recipient = "halvar"
	world3.central_secret_state = "contained"
	world3.patron_state = "dormant"
	world3._vigil_order_decides()
	assert(world3.central_secret_state == "suppressed",
		"the Order with nothing to burn keeps the truth (Ending Five, Order-flavored)")
	var world4 := SimWorld.new()
	world4.setup()
	world4.auto_resolve_events = true
	world4.vigil_recipient = "halvar"
	world4.central_secret_state = "contained"
	world4.patron_state = "active"
	world4._vigil_order_decides()
	assert(world4.central_secret_state == "destroyed",
		"the Order with a visible Patron coordinates the anchor's destruction (Ending Three)")
	assert(world4.patron_network_broken, "the anchor is ash")
	print("order fork ok — Ending Three and Ending Five both reachable through Halvar's road")

	# --- 7. determinism: the vigil never reshuffles the fixed history ---
	var wa := SimWorld.new()
	wa.setup()
	wa.auto_resolve_events = true
	var wb := SimWorld.new()
	wb.setup()
	wb.auto_resolve_events = true
	for i in 80:
		wa.advance_month()
		wb.advance_month()
	assert(wa.architect_phase == wb.architect_phase, "same phase, same seed")
	assert(wa.vigil_recipient == wb.vigil_recipient, "same recipient, same seed")
	assert(wa.central_secret_state == wb.central_secret_state, "same escape, same seed")
	var census_a := 0
	var census_b := 0
	for c in wa.characters.values():
		if c.alive:
			census_a += 1
	for c in wb.characters.values():
		if c.alive:
			census_b += 1
	assert(census_a == census_b, "byte-identical census at month 80 (%d vs %d)" % [census_a, census_b])
	var coh_a := ""
	var coh_b := ""
	for fname in wa.faiths:
		coh_a += "%s:%f;" % [fname, float(wa.faiths[fname]["coherence"])]
	for fname in wb.faiths:
		coh_b += "%s:%f;" % [fname, float(wb.faiths[fname]["coherence"])]
	assert(coh_a == coh_b, "byte-identical faith weather at month 80")
	print("determinism ok — two worlds, one history")

	print("ALL ARCHITECT VIGIL TESTS PASSED")
	quit()
