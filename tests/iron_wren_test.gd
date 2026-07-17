extends SceneTree

## Canon Pass One §3: the Iron Wren. Seven tokens and eighteen years old
## at the Year Six present; not a hero, not a character, not an
## interface; the hard constraints; the shield's delay; the un-making
## thread and the consent token. Run:
##   <godot.exe> --headless --path . --script res://tests/iron_wren_test.gd

func _init() -> void:
	print("=== iron wren test (Canon Pass One) ===")

	# --- group 1: the Year Six present — seven tokens, age eighteen ---
	var world := SimWorld.new()
	world.setup()
	world.auto_resolve_events = true
	assert(world.anchor_mages.size() == 15, "the roster: Sark, six unnamed, and the eight named at large")
	assert(bool(world.anchor_mages["sark"]["alive"]), "Sark lives at Year Zero — Vetral has not happened yet")
	assert(not world.wren_active, "at Year Zero she is twelve, and the map does not know her name")
	for i in 72:
		world.advance_month()
	assert(world.wren_active and world.wren_alive, "at Year Six the hunt is six years old")
	assert(world.wren_tokens == 7, "SEVEN tokens at campaign start — the eighth is uncarved (got %d)" % world.wren_tokens)
	assert(world.wren_age() == 18, "eighteen at Year Six — if any context says twelve or thirty, both are wrong (got %d)" % world.wren_age())
	assert(not bool(world.anchor_mages["sark"]["alive"]), "Sark was her first")
	for key in ["velren", "selva", "arren", "ferrin", "sella", "kell", "mira_ossrel", "vessrel_prime"]:
		assert(bool(world.anchor_mages[key]["alive"]),
			"the named roster is her REMAINING list — %s lives at Year Six" % key)
	assert(absf(world.wren_unmaking - 38.0) < 0.01,
		"seven kills' records: 38.0 points of un-making by Year Six (got %.1f)" % world.wren_unmaking)
	assert(world.wren_knows_token, "she learned of the consent token through her own research")
	print("Year Six: %d tokens, age %d, un-making %.1f — the legend runs ahead of the truth" % [
		world.wren_tokens, world.wren_age(), world.wren_unmaking])

	# --- group 2: she is NOT a hero and NOT a character ---
	for c in world.characters.values():
		assert(c.name != "Wren" and c.name != "Wren Callister",
			"she must never enter the census — no court, no marriage pool, no actuarial dice")
	assert(not world.hero_pool.has("wren"), "and never the hero pool")
	print("interface: none. She cannot be negotiated with, recruited, allied, or bought.")

	# --- group 3: the hard constraints ---
	var refusal := world.wren_offer_target(world.realms[0].ruler_id)
	assert(refusal.contains("not an anchor-mage"), "she will not kill a mage merely for being a mage")
	assert(refusal.contains("anchoring"), "the line is at the ANCHORING")
	print("constraints: the file comes back refused, squared to the table's edge")

	# --- group 4: two-world determinism (before anything mutates `world`) ---
	var w2 := SimWorld.new()
	w2.setup()
	w2.auto_resolve_events = true
	for i in 72:
		w2.advance_month()
	assert(w2.wren_tokens == 7 and absf(w2.wren_unmaking - 38.0) < 0.01,
		"the same seed hunts the same hunt")
	for key in w2.anchor_mages:
		assert(bool(w2.anchor_mages[key]["alive"]) == bool(world.anchor_mages[key]["alive"]),
			"the same mages die in the same seasons (%s)" % key)
	print("determinism: two worlds, the same seven strikes")

	# --- group 5: stream discipline — her auto-fire is ledger-only ---
	# (mutates `world`: direct ticks advance her study in the live phase)
	var gold0: float = world.realms[0].gold
	var tyr0: float = world.realms[0].tyranny
	var pres0: float = world.realms[0].prestige
	for i in 12:
		world._wren_tick()
	assert(world.realms[0].gold == gold0 and world.realms[0].tyranny == tyr0 and world.realms[0].prestige == pres0,
		"the Wren's auto-fire must never touch a live realm's stats")
	print("discipline: 12 direct wren ticks touched her ledger and nothing else")

	# --- group 6: the shield delays the eighth strike ---
	var wa := SimWorld.new()
	wa.setup()
	wa.auto_resolve_events = true
	var wb := SimWorld.new()
	wb.setup()
	wb.auto_resolve_events = true
	for i in 74:
		wa.advance_month()
		wb.advance_month()
	var live_target: String = wa.wren_target
	assert(live_target != "" and bool(wa.anchor_mages[live_target]["alive"]),
		"past Year Six she studies the named masters")
	wb.realms[0].gold = 100.0
	var serr := wb.shield_anchor_mage(0, live_target)
	assert(serr == "", "the crown may shield a monstrous but useful neighbor (got '%s')" % serr)
	assert(int(wb.wren_obstruction.get(0, 0)) >= 1, "she registers obstruction — she does not forget")
	var strike_tick := -1
	for i in 40:
		wa.advance_month()
		if not bool(wa.anchor_mages[live_target]["alive"]):
			strike_tick = wa.tick
			break
	assert(strike_tick > 0, "unshielded, the eighth strike lands")
	while wb.tick < strike_tick:
		wb.advance_month()
	assert(bool(wb.anchor_mages[live_target]["alive"]),
		"the shield buys months — the doubled watch is worth exactly that")
	print("shield: strike at tick %d unaided; the shielded tower still stands then" % strike_tick)

	# --- group 7: the un-making and the consent token ---
	var w3 := SimWorld.new()
	w3.setup()
	w3.auto_resolve_events = true
	for i in 72:
		w3.advance_month()
	w3.wren_unmaking = 60.0
	w3.advance_month()
	assert(w3.wren_vetral_attempted, "at threshold, she goes back to Vetral first")
	assert(w3.wren_vetral_outcome == "unmade" or w3.wren_vetral_outcome == "failed",
		"both outcomes are canon-compatible — success is a small miracle, failure the honest ending")
	w3.wren_unmaking = 90.0
	var resolved := false
	for i in 10:
		w3.advance_month()
		if w3.wren_token_retrieval != "":
			resolved = true
	assert(resolved, "the eighth working is the consent token — the thread must arm")
	if w3.patron_anchor_voided:
		assert(not w3.patron_network_broken,
			"voided is NOT ash: the anchor is unauthorized, not destroyed — two distinct outcomes")
	print("un-making: Vetral %s; token thread %s" % [w3.wren_vetral_outcome, w3.wren_token_retrieval])

	print("ALL IRON WREN CHECKS PASSED")
	quit()
