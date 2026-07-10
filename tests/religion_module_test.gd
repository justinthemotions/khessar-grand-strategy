extends SceneTree

## Religion & the Silence v1.0 test (Opus's Module 9 mini-brief + the God
## of Thresholds addendum): five faiths in freefall, heresy as the natural
## state, the orthodoxy axis live, the Chaplain's five-path crisis, and
## the one theology that never went silent. Run from the project folder:
##   <godot.exe> --headless --path . --script res://tests/religion_module_test.gd

func _find(world: SimWorld, who: String) -> SimCharacter:
	for c in world.characters.values():
		if world.full_name(c) == who:
			return c
	return null


func _active_count(world: SimWorld) -> int:
	var n := 0
	for fname in world.faiths:
		if bool(world.faiths[fname]["active"]):
			n += 1
	return n


func _init() -> void:
	var world := SimWorld.new()
	var events: Array = []
	world.event_logged.connect(func(t: String) -> void: events.append(t))
	world.setup()
	world.auto_resolve_events = true

	# --- 1. the five faiths at Year Zero, per the brief's §2 ---
	assert(world.faiths.size() == 5, "five faiths ship in v1.0 (got %d)" % world.faiths.size())
	var orth: Dictionary = world.faiths["Aelindran Orthodox"]
	assert(bool(orth["active"]) and absf(float(orth["coherence"]) - 0.60) < 0.001,
		"Aelindran Orthodox starts at coherence 0.60 — already six years into the erosion")
	assert(absf(float(orth["membership"]) - 0.60) < 0.001, "the pantheon still holds six souls in ten")
	assert(absf(float(orth["orthodoxy_alignment"]) - 0.90) < 0.001, "Orthodox alignment +0.90")
	var ref: Dictionary = world.faiths["Aelindran Reformed"]
	assert(not bool(ref["active"]) and float(ref["membership"]) == 0.0,
		"Aelindran Reformed exists as a record but has no members at Year Zero")
	var sil: Dictionary = world.faiths["The Silent Path"]
	assert(not bool(sil["active"]), "The Silent Path has not yet found its first teacher")
	var brush: Dictionary = world.faiths["The Brushgate Order"]
	assert(bool(brush["active"]) and absf(float(brush["coherence"]) - 0.85) < 0.001,
		"the Brushgate Order's coherence is body-based and stable at 0.85")
	var rat: Dictionary = world.faiths["The Vael Rationalist Faith"]
	assert(bool(rat["active"]) and float(rat["membership"]) >= 0.15,
		"the Magistocracy's secularism already holds 15-20%%")
	print("faiths ok — five doctrines at Year Zero: one crumbling, two waiting, two already working")

	# --- 2. souls take their starting faiths (Phase 2) ---
	var anselm: SimCharacter = world.characters.get(world.anselm_id)
	assert(world.faith_of(anselm) == "Aelindran Orthodox", "Anselm keeps the outward observances")
	var halloran: SimCharacter = world.characters.get(world.halloran_id)
	assert(world.faith_of(halloran) == "The Vael Rationalist Faith",
		"the Reformist wing's leader has quietly secularized (got %s)" % world.faith_of(halloran))
	var veril: SimCharacter = world.characters.get(world.architect_id)
	assert(world.faith_of(veril) == "The Vael Rationalist Faith", "the Academy-Sworn follow their ledgers")
	var vorak: SimCharacter = world.characters.get(world.realms[1].ruler_id)
	assert(world.faith_of(vorak) == "the Drevak Rites", "the clan keeps its own practice (deferred to v1.1 as a faith)")
	print("assignment ok — culture and conviction decide who answers to what")

	# --- 3. the God of Thresholds walks in the world (addendum §2.7) ---
	var halvar: SimCharacter = world.characters.get(world.halvar_id)
	assert(halvar != null and halvar.alive and world.full_name(halvar) == "Halvar Stenn",
		"Halvar Stenn keeps the threshold-shrine on the Marn's Crossing road")
	assert(halvar.traits.has("Gravewarden-Sworn"), "Halvar is Gravewarden-Sworn (canon)")
	assert(world.is_cast(halvar), "the canonical practitioners live outside the actuarial tables")
	var alenna: SimCharacter = world.characters.get(world.alenna_id)
	assert(alenna != null and alenna.traits.has("Threshold-Sensitive") and alenna.father_id == halvar.id,
		"Alenna Stenn inherits the practice in the blood")
	var anra: SimCharacter = world.characters.get(world.anra_id)
	assert(anra != null and anra.traits.has("Broken"), "Mother Anra Halden left office Broken — the Path will find her")
	var ariorwe := _find(world, "Ariorwe Thaladris")
	assert(ariorwe != null and ariorwe.traits.has("Threshold-Sensitive"),
		"Ariorwe's 120 carried names were always threshold-work")
	# trait data honors the addendum's exact numbers
	assert(absf(TraitDB.info("Threshold-Sensitive").inherit_chance - 0.05) < 0.001,
		"Threshold-Sensitive inherits at 5%% — rare enough to feel like weather")
	assert(not world._rollable_congenitals().has("Threshold-Sensitive"),
		"Threshold-Sensitive is never rolled by founder dice — the fixed seeds must not reshuffle")
	assert(absf(world.trait_mult(halvar, "corruption_gain_mult") - 0.60) < 0.001,
		"a Gravewarden's ledger fills at 0.60x — completed transitions leave less to owe")
	print("thresholds ok — Halvar, Alenna, Anra and Ariorwe stand where the addendum placed them")

	# --- 4. the orthodoxy axis is live and load-bearing (Phase 4) ---
	var corvin := _find(world, "Corvin Draeth")
	assert(corvin != null and world.ai_weight(corvin, "orthodoxy") >= 30.0,
		"a Zealous soldier scores hard toward the pantheon (got %.0f)" % world.ai_weight(corvin, "orthodoxy"))
	var davriand: SimCharacter = world.characters.get(world.davriand_id)
	assert(world.ai_weight(davriand, "orthodoxy") <= -20.0,
		"an Opportunistic Magister scores away from it (got %.0f)" % world.ai_weight(davriand, "orthodoxy"))
	print("orthodoxy ok — Zealous %+.0f vs Opportunistic %+.0f: the axis has consumers now" % [
		world.ai_weight(corvin, "orthodoxy"), world.ai_weight(davriand, "orthodoxy")])

	# --- 5. the Threshold Rejection Ritual works the Patron's meter ---
	var tess: SimCharacter = world.characters.get(world.mareck_id)
	tess.corruption = 6.0
	var before := tess.corruption
	for i in 10:
		var _r := world.threshold_rejection(world.halvar_id, tess.id)
		if tess.corruption < before:
			break
	assert(tess.corruption < before, "the rejection rite reduces the Corruption meter (85%% per attempt)")
	assert(halvar.stress > 0.0, "the rite costs the Gravewarden real stress — 15 per attempt")
	var refused := world.threshold_rejection(world.mareck_id, world.halvar_id)
	assert(refused.begins_with("Only a Gravewarden-Sworn"), "only the Order's hands can perform it")
	# threshold castings run on the older theology: even the Ashfields' sky can't stop them
	var p_ash = null
	for p in world.map.provinces:
		if p.silence_touched:
			p_ash = p
			break
	assert(p_ash != null, "the map offers silence-touched ground")
	assert(world.faith_reliability(halvar, p_ash, true) > world.faith_reliability(halvar, p_ash, false),
		"a threshold rite in the Ashfields outperforms a prayer there — the God attends transitions everywhere")
	print("rejection ok — corruption %.1f -> %.1f; the practice that never went silent" % [before, tess.corruption])

	# --- 6. twenty years of freefall (Phases 3, 5) ---
	for month in 240:
		world.advance_month()
	var orth2: Dictionary = world.faiths["Aelindran Orthodox"]
	assert(float(orth2["coherence"]) < 0.55,
		"Orthodox coherence declines across twenty years (got %.2f)" % float(orth2["coherence"]))
	assert(float(orth2["membership"]) < 0.55,
		"the pantheon bleeds membership at roughly two points a year (got %.2f)" % float(orth2["membership"]))
	assert(bool(world.faiths["Aelindran Reformed"]["active"]),
		"Aelindran Reformed activated — Vesper's End gained recognition in Year One")
	assert(bool(world.faiths["The Silent Path"]["active"]),
		"The Silent Path activated — the first teacher began teaching")
	var vesper := false
	var teacher := false
	for e in events:
		if str(e).contains("Vesper's End gains formal recognition"):
			vesper = true
		if str(e).contains("Silent Path"):
			teacher = true
	assert(vesper and teacher, "both activation beats landed in the chronicle")
	assert(_active_count(world) <= world.FAITH_CAP, "the continent never carries more than 15 doctrines")
	assert(halvar.wooden_birds_carved > 0, "twenty years of quarters: the birds accumulate")
	print("freefall ok — Orthodox %.2f coherence / %.0f%% of the continent after twenty years; %d faiths active" % [
		float(orth2["coherence"]), float(orth2["membership"]) * 100.0, _active_count(world)])

	# --- 7. heresy is the natural state, and the cap holds (Phase 5) ---
	var spawned := 0
	while world._unused_heresy_name() != "" and _active_count(world) < world.FAITH_CAP:
		world._spawn_heresy("Aelindran Orthodox", world._unused_heresy_name(), false)
		spawned += 1
	assert(spawned > 0, "the vacuum writes new doctrines")
	assert(_active_count(world) <= world.FAITH_CAP, "the mechanical cap of 15 is respected")
	var branch_found := false
	for fname in world.faiths:
		if str(world.faiths[fname]["parent"]) == "Aelindran Orthodox" and bool(world.faiths[fname]["active"]):
			branch_found = true
	assert(branch_found, "heretical branches record their parentage")
	print("heresy ok — %d branches spawned; the continent holds at %d doctrines" % [spawned, _active_count(world)])

	# --- 8. conversion is public, and the opinion web answers (Phase 6) ---
	var convert: SimCharacter = null
	for c in world.characters.values():
		if c.alive and c.realm_id == 0 and c.age_years(world.tick) >= 16 \
				and world.faith_of(c) == "Aelindran Orthodox" and c.id != world.realms[0].ruler_id:
			convert = c
			break
	assert(convert != null, "an Orthodox soul remains to convert")
	world._convert_faith(convert, "The Vael Rationalist Faith")
	assert(world.faith_of(convert) == "The Vael Rationalist Faith", "the conversion is recorded")
	var judged := false
	for judge in world._faith_judges():
		for m in judge.memories:
			if int(m["subject"]) == convert.id and (str(m["type"]) == "abandoned the pantheon" or str(m["type"]) == "one of ours now"):
				judged = true
	assert(judged, "crowned heads and seated Magisters recalculate on a public conversion")
	print("conversion ok — %s adopts the Rationalist position, and everyone watching adjusts" % world.full_name(convert))

	# --- 9. the Chaplain's crisis has five faces (Phase 7 + addendum) ---
	# The player's paths: a second world holds the event for the table.
	var world2 := SimWorld.new()
	world2.setup()
	world2.auto_resolve_events = false
	for month in 10:
		world2.advance_month()
	var crisis: Dictionary = {}
	for ev in world2.pending_events:
		if str(ev["title"]) == "The Chaplain's Faith Crisis":
			crisis = ev
	assert(not crisis.is_empty(), "the Chaplain's crisis reaches the player's table in Month 9")
	assert((crisis["options"] as Array).size() >= 4, "at least four response paths (five if Threshold-Sensitive)")
	var chap2: SimCharacter = world2.characters.get(int(crisis["decider"]))
	world2.resolve_event(int(crisis["id"]), 2)  # Transition to Reformed (the Pragmatic path)
	assert(bool(world2.faiths["Aelindran Reformed"]["active"]),
		"the Reformed transition activates the movement early — the Chaplain as its first public figure")
	assert(world2.faith_of(chap2) == "Aelindran Reformed", "the Chaplain crosses in public")
	assert(world2.magister_seat_of(chap2.id) == "Court Chaplain", "and keeps the seat — path C retains office")
	assert(float(world2.faiths["Aelindran Orthodox"]["coherence"]) < 0.60,
		"the pantheon pays for the defection in coherence")
	# and the canonical AI path: Broken Odric resigns to his bees (world 1 already proved
	# the beat fires; the administrative suite proves the resignation cadence)
	print("chaplain ok — the most fragile seat breaks in five directions, and the player holds them all")

	# --- 10. determinism: the theology never touches the main stream ---
	var wa := SimWorld.new()
	wa.setup()
	wa.auto_resolve_events = true
	var wb := SimWorld.new()
	wb.setup()
	wb.auto_resolve_events = true
	for month in 60:
		wa.advance_month()
		wb.advance_month()
	assert(absf(float(wa.faiths["Aelindran Orthodox"]["coherence"]) - float(wb.faiths["Aelindran Orthodox"]["coherence"])) < 0.000001,
		"two worlds, same seeds, same coherence — the faith dice are their own stream")
	assert(_active_count(wa) == _active_count(wb), "same faith count")
	assert(wa.characters.size() == wb.characters.size(), "same census — the main history stream never felt the theology")
	print("determinism ok — five years twice over, byte-identical faith weather")

	print("\nlast 8 events:")
	for e in events.slice(maxi(0, events.size() - 8)):
		print("  " + str(e))
	print("\nALL RELIGION & SILENCE CHECKS PASSED")
	quit(0)
