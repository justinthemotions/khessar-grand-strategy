extends SceneTree

## Administrative Government v1.0 test (Opus's mini-brief): the Council
## of Magisters seated, Anselm in the chair, the Month-34 poisoning, the
## first Council election, non-hereditary succession, appointments, and
## the player's consolidation lever. Run from the project folder:
##   <godot.exe> --headless --path . --script res://tests/administrative_module_test.gd

func _find(world: SimWorld, who: String) -> SimCharacter:
	for c in world.characters.values():
		if world.full_name(c) == who:
			return c
	return null


func _init() -> void:
	var world := SimWorld.new()
	var events: Array = []
	world.event_logged.connect(func(t: String) -> void: events.append(t))
	world.setup()
	world.auto_resolve_events = true

	# --- 1. the Council sits, and the chair is Anselm's ---
	var anselm: SimCharacter = world.characters.get(world.anselm_id)
	assert(anselm != null and anselm.alive, "Anselm Vorontheim exists at Year Zero")
	assert(world.full_name(anselm) == "Anselm Vorontheim", "the chair is Anselm Vorontheim (got %s)" % world.full_name(anselm))
	assert(world.realms[0].ruler_id == anselm.id, "the Grand Magister rules realm 0")
	assert(world.realms[0].government == "administrative", "the Magistocracy is administrative")
	assert(anselm.age_years(world.tick) == 68, "Anselm is 68 at Year Zero (got %d)" % anselm.age_years(world.tick))
	assert(anselm.traits.has("Broken"), "Anselm answered the Night of the Third Hour Broken")
	assert(world.grand_magister() != null and world.grand_magister().id == anselm.id, "grand_magister() finds him")
	assert(world.seated_magisters().size() == 9, "nine seats sit at Year Zero (got %d)" % world.seated_magisters().size())
	var halloran: SimCharacter = world.characters.get(world.halloran_id)
	var davriand: SimCharacter = world.characters.get(world.davriand_id)
	var kreth: SimCharacter = world.characters.get(world.kreth_id)
	assert(world.full_name(halloran) == "Halloran Verith" and halloran.age_years(world.tick) == 45, "Halloran Verith, 45, at Economic Affairs")
	assert(world.full_name(davriand) == "Davriand Karn" and davriand.race == "half_orc", "Davriand Karn carries his mother's blood")
	assert(world.full_name(kreth) == "Kreth Anford" and kreth.traits.has("Broken"), "Kreth Anford, the Broken moderate")
	assert(world.magister_seat_of(halloran.id) == "Economic Affairs", "Halloran holds the ledgers")
	assert(world.magister_seat_of(davriand.id) == "Foreign Affairs", "Davriand holds the borders")
	assert(int(world.magister_seats["Records Sublevel"]["holder"]) == world.architect_id,
		"Veril Ormand holds the Records Sublevel — seat 5 was always his")
	assert(str(world.magister_wing.get(world.architect_id, "")) == "silent", "the Records Sublevel is silent")
	var tess: SimCharacter = world.characters.get(world.mareck_id)
	assert(tess != null and world.full_name(tess) == "Tess Mareck" and world.magister_seat_of(tess.id) == "",
		"Tess Mareck holds no seat and reports only upward")
	var sevrin := _find(world, "Sevrin Vorontheim")
	assert(sevrin != null and sevrin.learning >= 15, "Sevrin Vorontheim, the Council-eligible nephew, waits")
	var vroot := world.root_house_id(anselm.dynasty_id)
	assert(world.has_legacy(vroot, "The Vael Compact"), "House Vorontheim declared the Vael Compact at Year Zero")
	print("council ok — Grand Magister Anselm Vorontheim presides over nine seats; Tess Mareck watches from off the ledger")

	# --- 2. canon reconciliation: Garran is 55, alive, and not the crown ---
	var garran := _find(world, "Garran Halvenard-Veil")
	assert(garran != null and garran.alive, "Garran Halvenard-Veil lives")
	assert(garran.age_years(world.tick) == 55, "Garran is 55 at Year Zero, per the Faction Map (got %d)" % garran.age_years(world.tick))
	assert(world.realms[0].ruler_id != garran.id, "Garran heads his House now — the chair was never hereditary")
	var vorak := _find(world, "Vorak Karn-Vol")
	assert(vorak != null and world.realms[1].ruler_id == vorak.id, "Vorak still leads the clan")
	print("canon ok — Garran, 55, heads House Halvenard-Veil; the chair is the Council's to give")

	# --- 3. the vote machinery is deterministic and recorded ---
	var mv: Dictionary = world.magister_vote("declaration of war", anselm.id, -1.0)
	assert(mv.has("passed") and mv.has("votes"), "a division returns its record")
	assert(str(mv["votes"].get(world.architect_id, "")) == "abstain", "the Records Sublevel casts no vote — it never has")
	assert(world.council_vote_history.size() >= 1, "the minutes record every division (Phase 7)")
	var ncr := world.call_no_confidence()
	assert(ncr != "", "no confidence finds no movers at Year Zero — the chamber is not yet angry")
	print("votes ok — recorded, abstentions honored, no-confidence gated on real anger")

	# --- 4. thirty-four months: the Chaplain breaks, then the cup ---
	for month in 34:
		world.advance_month()
	var chaplain_beat := false
	var poison_beat := false
	for e in events:
		if str(e).contains("Court Chaplain"):
			chaplain_beat = true
		if str(e).contains("autumn dinner"):
			poison_beat = true
	assert(chaplain_beat, "the Court Chaplain crisis fired within Year One — the most fragile seat breaks first")
	assert(poison_beat, "the autumn dinner arrived on schedule at Month 34")
	assert(not anselm.alive, "Anselm Vorontheim is poisoned at Month 34 — Year 3, Month 10")
	assert(world.has_mythos(vroot, "Former Grand Magister Family"),
		"House Vorontheim is marked: the chair was theirs once")
	var karn_root := world.root_house_id(davriand.dynasty_id)
	assert(world.dynasties[karn_root].poisonings >= 1, "the coin traces to House Karn's ledger, provable or not")
	print("poisoning ok — %s; the Council's arithmetic now decides everything" % world.date_string())

	# --- 5. the first Council election: preferential, non-hereditary ---
	for month in 6:
		world.advance_month()
	assert(world.admin_interregnum.is_empty(), "the election completed inside six months")
	assert(not world.last_election.is_empty(), "the ballots were ranked, counted, and burned")
	var winner: SimCharacter = world.characters.get(int(world.last_election["winner"]))
	assert(winner != null and winner.alive, "a new Grand Magister holds the seal")
	assert(world.realms[0].ruler_id == winner.id, "the winner rules realm 0")
	assert(world.grand_magister().id == winner.id, "and holds the Grand Magister seat")
	assert(winner.id != world.anselm_id, "the dead do not succeed themselves")
	for kid_id in anselm.children_ids:
		assert(int(world.last_election["winner"]) != int(kid_id), "no child of Anselm inherits the chair (brief §4)")
	var points: Dictionary = world.last_election["points"]
	var order: Array = points.keys()
	order.sort_custom(func(a, b) -> bool: return int(points[a]) > int(points[b]))
	var top3: Array = order.slice(0, 3)
	assert(top3.has(world.halloran_id), "Halloran Verith stands in the top three")
	assert(top3.has(world.davriand_id), "Davriand Karn stands in the top three")
	print("election ok — %s is Grand Magister; Halloran and Davriand led the count as the brief calls for" % world.full_name(winner))

	# --- 6. appointments refill the chamber (nomination + confirmation) ---
	for month in 20:
		world.advance_month()
	var confirmed := false
	for e in events:
		if str(e).contains("is confirmed to the Council"):
			confirmed = true
	assert(confirmed, "the Grand Magister nominated and the Council confirmed — the chamber refills itself")
	print("appointments ok — vacancies are nominated, voted, and seated (%d divisions on record)" % world.council_vote_history.size())

	# --- 7. Kreth Anford's clock (dying by Year Six) ---
	for month in 12:
		world.advance_month()
	assert(world.tick >= 71, "we are past Month 70")
	assert(not kreth.alive, "Kreth Anford dies of the long fatigue before Year Six")
	print("clock ok — Kreth Anford is gone by %s, as the brief foretold" % world.date_string())

	# --- 8. the player's consolidation lever changes the count ---
	var world2 := SimWorld.new()
	world2.setup()
	world2.auto_resolve_events = true
	for month in 35:
		world2.advance_month()  # the poisoning has fired; the election clock runs
	assert(not world2.admin_interregnum.is_empty(), "the second world is mid-election")
	world2.realms[0].gold += 200.0
	for month in 3:
		for m in world2.seated_magisters():
			var _err := world2.consolidate_support(world2.davriand_id, m.id)
		world2.advance_month()
	for month in 3:
		world2.advance_month()
	assert(not world2.last_election.is_empty(), "the sponsored election also completed")
	var dav_base := int(points.get(world.davriand_id, 0))
	var dav_sponsored := int(world2.last_election["points"].get(world2.davriand_id, 0))
	assert(dav_sponsored > dav_base,
		"ninety days of sponsored chamber visits move real votes (%d > %d)" % [dav_sponsored, dav_base])
	print("consolidation ok — gold into loyalty into points: %d base, %d sponsored" % [dav_base, dav_sponsored])

	print("\nlast 8 events:")
	for e in events.slice(maxi(0, events.size() - 8)):
		print("  " + str(e))
	print("\nALL ADMINISTRATIVE GOVERNMENT CHECKS PASSED")
	quit(0)
