extends SceneTree

## Faction Cast v1.0 test: the canonical Year Zero crowns as real
## characters, the live founders reconciled to their Faction Map names,
## and the scheduled canonical beats. Run from the project folder:
##   <godot.exe> --headless --path . --script res://tests/faction_cast_test.gd

func _init() -> void:
	var world := SimWorld.new()
	var events: Array = []
	world.event_logged.connect(func(t: String) -> void: events.append(t))
	world.setup()
	world.auto_resolve_events = true

	# --- 1. the live founders wear their canonical names ---
	# (Administrative v1.0: realm 0's chair passed from the Halvenard-Veil
	# placeholder to Grand Magister Anselm; Garran heads his House at 55.)
	var garran: SimCharacter = null
	for c in world.characters.values():
		if world.full_name(c) == "Garran Halvenard-Veil":
			garran = c
	var vorak: SimCharacter = world.characters[world.realms[1].ruler_id]
	assert(garran != null and garran.alive, "Garran Halvenard-Veil heads his House")
	assert(garran.age_years(world.tick) == 55, "Garran is 55 at Year Zero, per the Faction Map")
	assert(world.full_name(world.characters[world.realms[0].ruler_id]) == "Anselm Vorontheim",
		"the Magistocracy's chair is Grand Magister Anselm Vorontheim")
	assert(world.full_name(vorak) == "Vorak Karn-Vol", "the clan chief is Vorak Karn-Vol (got %s)" % world.full_name(vorak))
	print("reconciliation ok — %s (55) and %s, per the Faction Map; Anselm holds the chair" % [world.full_name(garran), world.full_name(vorak)])

	# --- 2. the seven canonical crowns are seated ---
	var expected := [
		["Pellar", "Eithne Vellian", "Queen", "human", 52],
		["Halven", "Ferren Crannock-Vey", "First Voice", "human", 58],
		["Vor-Grim", "Grimkar Vor-Grim", "Chieftain", "orc", 50],
		["Kharak-Dum", "Grimhold Ironvault", "King", "dwarf", 82],
		["Veldarin", "Analinth Veldarin", "Matriarch", "elf", 340],
		["Thaladris", "Ariorwe Thaladris", "Matriarch", "elf", 285],
		["Saren-Vesh", "Vessa Korren", "First Councilor", "human", 47],
	]
	for row in expected:
		var rid := world._map_realm_named(str(row[0]))
		assert(rid >= 2, "%s must be a map realm beyond the two live ones" % row[0])
		var ruler: SimCharacter = world.cast_ruler_of(rid)
		assert(ruler != null, "%s must have a seated ruler" % row[0])
		assert(world.full_name(ruler) == str(row[1]), "%s should rule %s (got %s)" % [row[1], row[0], world.full_name(ruler)])
		assert(str(world.cast_rulers[rid]["title"]) == str(row[2]), "%s carries the title %s" % [row[1], row[2]])
		assert(ruler.race == str(row[3]), "%s is %s" % [row[1], row[3]])
		assert(ruler.age_years(world.tick) == int(row[4]), "%s is %d at Year Zero (got %d)" % [row[1], int(row[4]), ruler.age_years(world.tick)])
		assert(world.is_cast(ruler), "the cast live outside the two simulated realms")
		assert(world._has_silence_response(ruler), "every crown answered the Night of the Third Hour")
		assert(world.cast_title_of(ruler.id).contains(str(row[2])), "cast_title_of must dress them properly")
	print("cast ok — seven canonical crowns seated: Human x3, Orc, Dwarf, Elf x2; every government type represented")

	# --- 3. the courts around them ---
	var kharak := world._map_realm_named("Kharak-Dum")
	var grimhold: SimCharacter = world.cast_ruler_of(kharak)
	assert(grimhold.traits.has("Ailing"), "Grimhold is Ailing at Year Zero — the clock is already running")
	var karth: SimCharacter = null
	for cid in grimhold.children_ids:
		karth = world.characters[cid]
	assert(karth != null and karth.name == "Karth" and karth.learning >= 22, "Prince Karth Ironvault, Learning 22+, stands heir (got %d)" % (karth.learning if karth != null else -1))
	var vovel: SimCharacter = null
	var mira: SimCharacter = null
	for c in world.characters.values():
		if world.full_name(c) == "Marek Vovel":
			vovel = c
		if world.full_name(c) == "Mira Crannock-Vey":
			mira = c
	assert(vovel != null and vovel.age_years(world.tick) == 71 and vovel.traits.has("Academy-Sworn"),
		"Chief Archivist Marek Vovel keeps the Iron Library at 71")
	assert(mira != null and mira.race == "half_elf", "Mira Crannock-Vey carries her mother's blood")
	var thaladris := world._map_realm_named("Thaladris")
	assert(world.cast_ruler_of(thaladris).names_carried > 0, "Ariorwe has sung the Library's dead for a century")
	print("courts ok — Karth heir under the mountain, Vovel at the Library, Mira on the wharves")

	# --- 4. the cast stand outside the live machinery ---
	for c in world.eligible_singles(true) + world.eligible_singles(false):
		assert(not world.is_cast(c), "the cast courts answer no marriage brokers yet")
	print("isolation ok — no cast face in the marriage pickers, no cast dice in the main stream")

	# --- 5. four years of scheduled canonical beats ---
	for month in 50:
		world.advance_month()
	var beats := {"pellar": false, "grain": false, "wards": false, "compact": false, "interregnum": false}
	for e in events:
		var t := str(e)
		if t.contains("Pellar refuses the Magistocracy"):
			beats["pellar"] = true
		if t.contains("grain fleets fail Halven"):
			beats["grain"] = true
		if t.contains("ward-stones of Kharak-Dum are going dark"):
			beats["wards"] = true
		if t.contains("spits on the border compact"):
			beats["compact"] = true
		if t.contains("first Dwarven Interregnum"):
			beats["interregnum"] = true
	for k in beats:
		assert(bool(beats[k]), "the '%s' canonical beat must fire on schedule" % k)
	assert(not grimhold.alive, "Grimhold dies in Year Four, as the ward-lights gutter")
	var new_king: SimCharacter = world.cast_ruler_of(kharak)
	assert(new_king != null and new_king.id == karth.id, "Karth Ironvault succeeds under the mountain")
	print("beats ok — Pellar's refusal, Halven's grain, the dimming wards, Grimkar's defiance, and the first Dwarven Interregnum: %s is King" % world.full_name(new_king))

	# --- 6. the ageless endure ---
	var veldarin := world._map_realm_named("Veldarin")
	var analinth: SimCharacter = world.cast_ruler_of(veldarin)
	assert(analinth != null and analinth.alive, "Analinth Veldarin outlives the opening years without a scratch")
	print("elders ok — the Matriarch of Veldarin is %d and has answered no letters" % analinth.age_years(world.tick))

	print("\nlast 8 events:")
	for e in events.slice(maxi(0, events.size() - 8)):
		print("  " + str(e))
	print("\nALL FACTION CAST CHECKS PASSED")
	quit(0)
