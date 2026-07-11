extends SceneTree

## Magic Injection v1.0 test (Opus's design doc, 2026-07-08): the
## Corruption meter, the Silence Response substrate, the eight practices,
## faith geography, the Patron, oaths, songs, the Brushgate — and the
## Magistocracy's central secret. Run from the project folder:
##   <godot.exe> --headless --path . --script res://tests/magic_module_test.gd

func _init() -> void:
	var world := SimWorld.new()
	var events: Array = []
	world.event_logged.connect(func(t: String) -> void: events.append(t))
	world.setup()
	world.auto_resolve_events = true

	# --- 1. the Night of the Third Hour: every living soul answered it ---
	# (except the Ashfields: the Silence did not surprise Caeris or change
	# his work — his response is canonically N/A, The World the Silence
	# Made v1.1 §2)
	var responses := 0
	for c in world.characters.values():
		if not c.alive or c.realm_id == SimWorld.ASHFIELDS_REALM:
			continue
		var held := 0
		for r in SimWorld.SILENCE_RESPONSES:
			if c.traits.has(r):
				held += 1
		assert(held == 1, "%s must hold exactly one Silence Response (has %d)" % [world.full_name(c), held])
		responses += 1
	print("silence response ok — %d living souls, one answer each" % responses)

	# --- 2. the practices are seeded at Year Zero ---
	var wizard: SimCharacter = null
	var primal: SimCharacter = null
	for c in world.characters.values():
		if c.alive and c.realm_id == 0 and c.traits.has("Arcane-Blooded") and c.traits.has("Academy-Sworn") and c.id != world.architect_id:
			wizard = c
		if c.alive and c.realm_id == 1 and c.traits.has("Primal-Practiced"):
			primal = c
	assert(wizard != null, "Vael must keep a court wizard at Year Zero")
	assert(primal != null, "the clan must keep its primal ways at Year Zero")
	print("practices ok — %s keeps Vael's grimoires; %s keeps the clan's roots" % [
		world.full_name(wizard), world.full_name(primal)])

	# --- 3. the Architect of Silence ---
	assert(world.architect_id >= 0, "Veril Ormand must exist")
	var ormand: SimCharacter = world.characters[world.architect_id]
	assert(world.full_name(ormand) == "Veril Ormand", "the Architect is Veril Ormand")
	assert(ormand.corruption_marks >= 1, "what was signed in Year 112 left its mark")
	var complicity: Dictionary = {}
	for s in world.secrets:
		if str(s["type"]) == "silence_cause_complicity":
			complicity = s
	assert(not complicity.is_empty() and int(complicity["subject"]) == ormand.id,
		"the central secret is held by exactly one living character")
	assert(complicity["known"].is_empty(), "at Year Zero, nobody else knows")
	print("architect ok — %s, %d years old, Mark %d, and the only one who knows" % [
		world.full_name(ormand), ormand.age_years(world.tick), ormand.corruption_marks])

	# --- 4. the Corruption meter: thresholds at 5 / 10 / 15 ---
	var subject: SimCharacter = wizard
	var start_marks := subject.corruption_marks
	assert(start_marks == 0, "the court wizard starts clean (academy discipline)")
	world.add_corruption(subject, 7.0, "test: a grimoire ritual gone wrong")
	assert(subject.corruption_marks == 1 and subject.traits.has("Corruption Mark I"),
		"Mark I at 5 (corruption %.1f)" % subject.corruption)
	world.add_corruption(subject, 25.0, "test: the deep end")
	assert(subject.corruption_marks == 3 and subject.traits.has("Corruption Mark III"), "Marks II and III at 10 and 15")
	assert(world.trait_add(subject, "silence_immunity") >= 1.0,
		"Mark III is entity-adjacent — the Ashfields cannot bite them")
	print("corruption meter ok — marks fired at 5/10/15, Mark III grants silence immunity")

	# --- 5. stress_gain_mult is live ---
	var brave: SimCharacter = null
	for c in world.characters.values():
		if c.alive and c.realm_id == 0 and c.id != subject.id and c.age_years(world.tick) >= 16 \
				and not c.traits.has("Faith-Practicing") and not c.traits.has("Brushgate-Trained") \
				and not c.traits.has("Primal-Practiced") and not c.traits.has("Song-Marked") \
				and c.id != world.architect_id:
			brave = c
			break
	world._swap_silence_response(brave, "Broken")
	var s_before: float = brave.stress
	world.add_stress(brave, 10.0, "test: bad news")
	assert(absf((brave.stress - s_before) - 12.0) < 0.01, "the Broken carry it 1.2x heavier (got %+.1f)" % (brave.stress - s_before))
	print("stress hook ok — the Broken carry 10 stress as 12")

	# --- 6. the Cleric geography formula ---
	var cleric: SimCharacter = null
	for c in world.characters.values():
		if c.alive and c.traits.has("Faith-Practicing"):
			cleric = c
			break
	assert(cleric != null, "Vael keeps a candle-lighter at Year Zero")
	world._swap_silence_response(cleric, "Zealous")
	var p_ash = null
	var p_lib = null
	var p_ord = null
	for p in world.map.provinces:
		if p.silence_touched and p_ash == null:
			p_ash = p
		if str(p.special_feature) == "iron_library":
			p_lib = p
		if not p.silence_touched and not p.ruined and str(p.special_feature) == "" and p_ord == null:
			p_ord = p
	assert(p_ash != null and p_lib != null and p_ord != null, "the map must offer all three grounds")
	var r_ash := world.faith_reliability(cleric, p_ash)
	var r_ord := world.faith_reliability(cleric, p_ord)
	var r_lib := world.faith_reliability(cleric, p_lib)
	assert(r_ash < r_ord and r_ord < r_lib, "geography must order the faith: %.2f < %.2f < %.2f" % [r_ash, r_ord, r_lib])
	world._swap_silence_response(cleric, "Broken")
	assert(world.faith_reliability(cleric, p_ord) < r_ord, "a Broken priest prays worse than a Zealous one")
	world._swap_silence_response(cleric, "Zealous")
	print("faith geography ok — Ashfields %.2f · ordinary %.2f · Iron Library %.2f" % [r_ash, r_ord, r_lib])

	# --- 7. the central secret is beyond tavern informants ---
	for i in 80:
		world.ferreting[1] = 0  # re-arm Karn-Vol's informants every month
		world._ferret_tick()
	for s in world.secrets:
		if str(s["type"]) == "silence_cause_complicity":
			assert(not s["known"].has(1), "eighty months of ferreting must never surface the central secret")
	print("secret shielding ok — 80 months of informants, and the chamber stays shut")

	# --- 8. the Patron's Offer, taken deliberately ---
	world.auto_resolve_events = false
	var mark: SimCharacter = brave
	mark.stress = 200.0
	world._raise_patron_offer(mark)
	assert(not world.pending_events.is_empty(), "the offer must reach the player's table")
	var ev: Dictionary = world.pending_events[0]
	assert(str(ev["title"]) == "The Patron's Offer", "the right event waits")
	world.resolve_event(int(ev["id"]), 1)  # accept the bargain
	world.auto_resolve_events = true
	assert(mark.traits.has("Patron-Bound"), "the bargain binds")
	assert(mark.corruption > 0.0, "the bargain goes on the ledger")
	var signed := false
	for s in world.secrets:
		if int(s["subject"]) == mark.id and str(s["type"]) == "patron_bargain_signed":
			signed = true
	assert(signed, "a signed bargain is a secret the world can find")
	print("patron ok — %s accepts, corruption %.1f, and the secret exists" % [world.full_name(mark), mark.corruption])

	# --- 9. battle magic: the command tent's new cards ---
	var sim := BattleSim.new()
	sim.setup_from_rosters(
		[{"kind": "archer", "soldiers": 24, "max": 24}, {"kind": "sword", "soldiers": 36, "max": 36}],
		[{"kind": "sword", "soldiers": 36, "max": 36}, {"kind": "brushgate_column", "soldiers": 18, "max": 18}],
		8, 8, ["Vael", "Karn-Vol"])
	sim.set_commander_info(0, {"martial": 8, "intrigue": 10, "prowess": 8,
		"traits": ["Patron-Bound", "Arcane-Blooded"], "names": 0})
	var sword_b: BattleSim.Regiment = sim.regiments[2]
	var monk_b: BattleSim.Regiment = sim.regiments[3]
	assert(sword_b.shock > 0.0, "the Patron-touched commander's terror reaches ordinary lines")
	assert(monk_b.shock == 0.0, "the Brushgate column does not feel it (silence immunity)")
	assert(sim.tactic_gate(0, "reap_the_bargain") == "", "Patron-Bound may reap")
	assert(sim.tactic_gate(0, "uncontrolled_channel") == "", "untrained arcane blood may channel")
	var m_before: float = sim.regiments[0].missile
	var _e1 := sim.use_tactic(0, "uncontrolled_channel")
	assert(sim.regiments[0].missile > m_before, "the channel burns through the volleys")
	var shock_before: float = sword_b.shock
	var _e2 := sim.use_tactic(0, "reap_the_bargain")
	assert(sword_b.shock > shock_before and monk_b.shock == 0.0, "the reaping spares only the disciplined")
	assert(sim.commander_corruption[0] >= 7.0, "the ledger records the battle (got %.1f)" % sim.commander_corruption[0])
	# academy discipline forbids the channel
	var sim2 := BattleSim.new()
	sim2.setup_from_rosters([{"kind": "archer", "soldiers": 24, "max": 24}],
		[{"kind": "sword", "soldiers": 36, "max": 36}], 8, 8, ["A", "B"])
	sim2.set_commander_info(0, {"traits": ["Arcane-Blooded", "Academy-Sworn"], "names": 0})
	assert(sim2.tactic_gate(0, "uncontrolled_channel") != "", "Academy-Sworn discipline forbids exactly this")
	# the Bard's names steady the line
	var sim3 := BattleSim.new()
	sim3.setup_from_rosters([{"kind": "sword", "soldiers": 36, "max": 36}],
		[{"kind": "sword", "soldiers": 36, "max": 36}], 8, 8, ["A", "B"])
	sim3.set_commander_info(0, {"traits": ["Song-Marked"], "names": 200})
	assert(sim3.regiments[0].morale_bonus > 0.0, "carried names are morale on the field")
	print("battle magic ok — terror, the channel, the reaping, the song; the Brushgate untouched")

	# --- 10. the Bard asks for the name ---
	var bard: SimCharacter = null
	for c in world.characters.values():
		if c.alive and c.realm_id == 0 and not c.traits.has("Song-Marked") and c.age_years(world.tick) >= 16 \
				and c.id != world.realms[0].ruler_id:
			bard = c
			break
	world._add_trait(bard, "Song-Marked")
	var names_before := bard.names_carried
	var victim: SimCharacter = null
	for c in world.characters.values():
		if c.alive and c.realm_id == 0 and c.id != bard.id and c.id != world.realms[0].ruler_id \
				and c.id != world.architect_id and c.id != mark.id and c.id != subject.id and c.id != cleric.id:
			victim = c
			break
	world._kill(victim, "test: has died")
	assert(bard.names_carried == names_before + 1, "the Bard asks for the name of the dead")
	print("bard ok — %s carries %d names" % [world.full_name(bard), bard.names_carried])

	# --- 11. legacies: the ledger, the archive, the bargain ---
	var ruler: SimCharacter = world.characters[world.realms[0].ruler_id]
	var root: int = world.root_house_id(ruler.dynasty_id)
	world.dynasties[root].renown = 2000.0
	assert(world.buy_legacy(root, "The Iron Library Compact") == "", "the compact must be buyable")
	assert(world.buy_legacy(root, "The Patron's Bargain") == "", "the bargain must be buyable")
	var renown_before: float = world.dynasties[root].renown
	var member: SimCharacter = null
	for c in world.characters.values():
		if c.alive and world.root_house_id(c.dynasty_id) == root and c.id != ruler.id and c.id != mark.id:
			member = c
			break
	world._kill(member, "test: has died")
	assert(world.dynasties[root].renown > renown_before, "the Archive records the death as renown")
	# a child of the bargain is born owing
	var father: SimCharacter = null
	var mother: SimCharacter = null
	for c in world.characters.values():
		if c.alive and world.root_house_id(c.dynasty_id) == root and not c.is_female and c.spouse_id >= 0 \
				and world.characters[c.spouse_id].alive:
			father = c
			mother = world.characters[c.spouse_id]
			break
	if father != null:
		var child: SimCharacter = world._make_child(father, mother)
		assert(child.corruption >= 2.0, "children of the bargain are born owing")
		print("legacies ok — the Archive pays renown; the bargain's child is born at corruption %.1f" % child.corruption)
	else:
		print("legacies ok — the Archive pays renown (no married couple free for the bargain-birth check)")

	# --- 12. the Architect's chamber opens on his death — and the crown
	# chooses Ending 3: the anchor burns ---
	assert(mark.traits.has("Patron-Bound"), "the bargain still binds before the chamber opens")
	world.auto_resolve_events = false
	world._kill(ormand, "test: has died")
	world._architect_tick()
	var chamber: Dictionary = {}
	for pe in world.pending_events:
		if str(pe["title"]) == "The Architect's Chamber":
			chamber = pe
	assert(not chamber.is_empty(), "the chamber must open on the Architect's death")
	for s in world.secrets:
		if str(s["type"]) == "silence_cause_complicity":
			assert(s["known"].has(0), "the crown now knows")
	world.resolve_event(int(chamber["id"]), 2)  # Destroy the anchor — end the Patron itself
	world.auto_resolve_events = true
	assert(world.central_secret_state == "destroyed", "Ending 3 must be chosen")
	assert(world.patron_network_broken, "the network must break")
	assert(not mark.traits.has("Patron-Bound"), "the bargains fall silent")
	var corr_before: float = mark.corruption
	world.add_corruption(mark, 5.0, "test: should be impossible now")
	assert(mark.corruption == corr_before, "no new entries on a burned ledger")
	print("chamber ok — the truth surfaced, the anchor burned, %s owes nothing new; the marks already paid remain" % world.full_name(mark))

	# --- 14. ten-year soak ---
	var world2 := SimWorld.new()
	var events2: Array = []
	world2.event_logged.connect(func(t: String) -> void: events2.append(t))
	world2.setup()
	world2.auto_resolve_events = true
	for month in 120:
		world2.advance_month()
	var unanswered := 0
	for c in world2.characters.values():
		if c.alive and c.age_years(world2.tick) >= 16 and not world2._has_silence_response(c):
			unanswered += 1
	assert(unanswered == 0, "every grown soul must have answered the Silence (%d have not)" % unanswered)
	var prayer_logs := 0
	var mark_logs := 0
	var oath_logs := 0
	var magic_logs := 0
	for e in events2:
		var t := str(e)
		if t.contains("prayer") or t.contains("candles") or t.contains("Faith"):
			prayer_logs += 1
		if t.contains("Corruption Mark"):
			mark_logs += 1
		if t.contains("oath"):
			oath_logs += 1
		if t.contains("academy") or t.contains("Patron") or t.contains("Brushgate") or t.contains("names"):
			magic_logs += 1
	print("\n=== after the soak (%s) ===" % world2.date_string())
	print("prayer/faith lines: %d · corruption marks: %d · oath lines: %d · other magic lines: %d" % [
		prayer_logs, mark_logs, oath_logs, magic_logs])
	print("last 10 events:")
	for e in events2.slice(maxi(0, events2.size() - 10)):
		print("  " + str(e))
	print("\nALL MAGIC CHECKS PASSED")
	quit(0)
