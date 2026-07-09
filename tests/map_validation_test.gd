extends SceneTree

## Headless validation of the hand-authored Khessar map. Run from the
## project folder:
##   <godot.exe> --headless --path . --script res://tests/map_validation_test.gd
## Asserts the PART 10 contract: 60 provinces, unique names, adjacency
## sanity, realm records, duchy structure, canonical placements, the
## Silence/ruin flags, the Silence calendar, and full determinism.

const CANONICAL_NAMES: Array[String] = [
	"Vael", "Irnholt", "Pellar", "Carath", "Dunmore", "Halven", "Durn",
	"Kharak-Dum", "Saren-Vesh", "Mirathen", "Halvet", "Vellan-on-the-River",
	"Vesper's End", "Sennel", "Marn's Crossing", "Ashford", "Veilkeep",
	"Voss-Hold", "Brem's Reach", "Marling Fields", "Caer Velmond",
]

const EXPECTED_GOVERNMENTS := {
	"Magistocracy of Vael": "administrative",
	"Karn-Vol Clan": "tribal",
	"Pellar": "feudal",
	"Carath": "feudal",
	"Dunmore": "feudal",
	"Halven": "merchant_republic",
	"Free City-States Compact": "merchant_republic",
	"Vor-Grim Clan": "tribal",
	"Kharak-Dum": "feudal",
	"House Veldarin": "clan",
	"House Thaladris": "clan",
	"Saren-Vesh Trade Council": "merchant_republic",
}

# capitals and settlements introduced by the Faction Map at Year Zero (v1.0)
const FACTION_MAP_NAMES: Array[String] = ["Karn-Vol-Gar", "Grim-Vor-Kaz", "Elasilwe", "Thaladris"]

const EXPECTED_REGION_COUNTS := {
	"vael": 18, "free_city": 12, "drevak_orc": 8, "dwarven": 4,
	"elven_veldarin": 3, "elven_thaladris": 3, "southern_reach": 5,
	"ashfields": 4, "aurath": 3,
}


func _init() -> void:
	var map := WorldMap.new()
	map.generate(777)

	# --- province count, names, geometry ---
	assert(map.provinces.size() == 60, "the Khessar map must hold exactly 60 provinces, got %d" % map.provinces.size())
	var names := {}
	for p in map.provinces:
		assert(str(p.name) != "", "province %d has no name" % p.id)
		assert(not names.has(p.name), "duplicate province name: %s" % p.name)
		names[p.name] = p.id
		assert(p.polygon.size() >= 6, "%s has a degenerate polygon (%d verts)" % [p.name, p.polygon.size()])
		for v in p.polygon:
			assert(v.x >= 0.0 and v.x <= 1.0 and v.y >= 0.0 and v.y <= 1.0, "%s has a vertex off the map: %s" % [p.name, str(v)])
		assert(p.tax >= 1.2 and p.tax <= 3.2, "%s tax %.1f out of range" % [p.name, p.tax])
		assert(p.levy >= 12 and p.levy <= 35, "%s levy %d out of range" % [p.name, p.levy])
		assert(p.owner == p.de_jure, "at Year Zero every county is rightfully held (%s)" % p.name)
	print("60 provinces, unique names, sane polygons, tax/levy in range")

	for canon in CANONICAL_NAMES:
		assert(names.has(canon), "canonical settlement missing from the map: %s" % canon)
	for fname in FACTION_MAP_NAMES:
		assert(names.has(fname), "Faction Map settlement missing: %s" % fname)
	print("all %d canonical settlements placed exactly once" % (CANONICAL_NAMES.size() + FACTION_MAP_NAMES.size()))

	# --- adjacency: symmetric, no self-links, connected enough ---
	for p in map.provinces:
		assert(not p.neighbors.has(p.id), "%s neighbors itself" % p.name)
		for nid in p.neighbors:
			assert(map.provinces[nid].neighbors.has(p.id), "asymmetric adjacency %s <-> %s" % [p.name, map.provinces[nid].name])
		var minimum := 1 if p.ruined else 2
		assert(p.neighbors.size() >= minimum, "%s has only %d neighbors" % [p.name, p.neighbors.size()])
	print("adjacency symmetric, every province connected (ruins may have 1 neighbor)")

	# --- the mountain wall: exactly two passes through the Carath range ---
	var passes: Array = []
	for p in map.provinces:
		if p.cultural_region != "drevak_orc":
			continue
		for nid in p.neighbors:
			var n = map.provinces[nid]
			if n.cultural_region != "drevak_orc" and n.cultural_region != "dwarven":
				passes.append("%s <-> %s" % [p.name, n.name])
	assert(passes.size() == 2, "the Carath range must have exactly two passes, got %s" % str(passes))
	var pass_text := " · ".join(passes)
	assert(pass_text.contains("Marn's Crossing") and pass_text.contains("Ashford"),
		"the passes must be Marn's Crossing and Ashford, got %s" % pass_text)
	print("mountain wall holds — passes: %s" % pass_text)

	# --- the deep forests: each Elven house touches the world at few points ---
	for region in ["elven_veldarin", "elven_thaladris"]:
		var external := 0
		for p in map.provinces:
			if p.cultural_region != region:
				continue
			for nid in p.neighbors:
				if map.provinces[nid].cultural_region != region:
					external += 1
		assert(external <= 3, "%s forest too open: %d outside borders" % [region, external])
	print("elven forests sealed to a few gate provinces each")

	# --- realm records ---
	assert(map.realms.size() == EXPECTED_GOVERNMENTS.size(), "expected %d realms" % EXPECTED_GOVERNMENTS.size())
	for r in map.realms:
		assert(EXPECTED_GOVERNMENTS.has(r.name), "unexpected realm: %s" % str(r.name))
		assert(r.government == EXPECTED_GOVERNMENTS[r.name], "%s has government %s" % [r.name, r.government])
		var cap = map.provinces[r.capital_province_id]
		assert(cap.owner == r.id, "%s's capital %s is not its own land" % [r.name, cap.name])
		if r.name != "Free City-States Compact":
			assert(str(r.ruler) != "", "%s needs its Faction Map ruler" % r.name)
	var vael_realm = map.realms[0]
	assert(vael_realm.founding_house == "House Vorontheim", "the Magistocracy is administered by House Vorontheim")
	print("%d realms with correct governments, capitals and Year Zero rulers" % map.realms.size())

	# --- region allocation matches the illustration's proportions ---
	var region_counts := {}
	for p in map.provinces:
		region_counts[p.cultural_region] = int(region_counts.get(p.cultural_region, 0)) + 1
	for region in EXPECTED_REGION_COUNTS:
		assert(int(region_counts.get(region, 0)) == int(EXPECTED_REGION_COUNTS[region]),
			"region %s: expected %d provinces, got %d" % [region, EXPECTED_REGION_COUNTS[region], int(region_counts.get(region, 0))])
	print("regional allocation ok — %s" % str(region_counts))

	# --- duchies: 18-22, each 2-4 counties, consistent membership ---
	assert(map.duchies.size() >= 18 and map.duchies.size() <= 22,
		"expected 18-22 duchies, got %d" % map.duchies.size())
	var ghost_duchies := 0
	for d in map.duchies:
		assert(d.county_ids.size() >= 2 and d.county_ids.size() <= 4,
			"%s has %d counties" % [d.name, d.county_ids.size()])
		assert(str(d.name).begins_with("Duchy of "), "duchy naming convention broken: %s" % d.name)
		if d.realm < 0:
			ghost_duchies += 1
		for pid in d.county_ids:
			assert(map.provinces[pid].duchy == d.id, "duchy membership broken for %s" % map.provinces[pid].name)
	for p in map.provinces:
		assert(p.duchy >= 0, "%s belongs to no duchy" % p.name)
	assert(ghost_duchies == 3, "the Sealed Holds, Ashfields and Aurath must be ghost duchies")
	print("%d duchies (3 ghosts), naming and membership consistent" % map.duchies.size())

	# --- canonical features and flags ---
	var pellar = map.provinces[names["Pellar"]]
	assert(pellar.special_feature == "iron_library", "the Iron Library must stand in Pellar")
	assert(pellar.id == map.realms[2].capital_province_id, "Pellar must be its realm's capital")
	assert(map.provinces[names["Durn"]].special_feature == "durn_caeris_seat", "Durn must be Caeris's seat")
	assert(map.provinces[names["Marn's Crossing"]].special_feature == "marn_crossing", "Marn's Crossing must be flagged")
	for p in map.provinces:
		if p.cultural_region == "ashfields":
			assert(p.silence_touched and p.owner == -1, "the Ashfields must be silence_touched and unclaimed (%s)" % p.name)
		else:
			assert(not p.silence_touched, "%s should not be silence_touched" % p.name)
		if p.cultural_region == "aurath":
			assert(p.ruined and p.owner == -1, "the Sovereignty must be ruined and unclaimed (%s)" % p.name)
		elif p.special_feature == "sealed_hold":
			# LOCKED rather than dead — ruined for map purposes per Faction Map v1.0
			assert(p.ruined and p.owner == -1, "sealed holds must be ruined and unclaimed (%s)" % p.name)
		else:
			assert(not p.ruined, "%s should not be ruined" % p.name)
	assert(map.provinces[names["Mirathen"]].special_feature == "iliana_home", "Mirathen is Iliana Vesh's home")
	assert(map.provinces[names["Halven"]].special_feature == "guildhall", "Halven's civic council needs its guildhall")
	assert(map.provinces[names["Saren-Vesh"]].coastal, "Saren-Vesh is a coastal trading city")
	assert(not map.provinces[names["Vael"]].coastal, "Vael sits inland on the plains")
	assert(map.provinces[names["Vael"]].tax >= 3.0, "the capital is the richest city on the continent")
	print("special features, Silence flags and ruin flags all in place")

	# --- the frontier: the sim's two live realms meet at the pass ---
	var fm := map.frontier_midpoint()
	assert(fm.x >= 0.0, "realms 0 and 1 must share a frontier for the war sim")
	print("Vael / Karn-Vol frontier found at %s (the Marn's Crossing pass)" % str(fm))

	# --- determinism: two generations must be identical ---
	var map2 := WorldMap.new()
	map2.generate(777)
	for i in map.provinces.size():
		var a = map.provinces[i]
		var b = map2.provinces[i]
		assert(a.name == b.name and a.owner == b.owner and a.tax == b.tax, "non-deterministic province data at %d" % i)
		assert(a.polygon == b.polygon, "non-deterministic polygon at %s" % a.name)
		assert(a.neighbors == b.neighbors, "non-deterministic adjacency at %s" % a.name)
	for i in map.duchies.size():
		assert(map.duchies[i].name == map2.duchies[i].name, "non-deterministic duchy naming")
	print("deterministic — two generations produced identical maps")

	# --- the Silence calendar (PART 8) ---
	var world := SimWorld.new()
	world.setup()
	assert(world.realms[0].government == "administrative" and world.realms[1].government == "tribal",
		"live realm governments not assigned")
	assert(world.realms[0].name == "Magistocracy of Vael" and world.realms[1].name == "Karn-Vol Clan",
		"live realms must carry their Khessar names")
	assert(world.date_string() == "Year 0, Month 1 of the Silence",
		"tick 0 must read 'Year 0, Month 1 of the Silence', got '%s'" % world.date_string())
	world.tick = 72
	assert(world.date_string() == "Year 6, Month 1 of the Silence",
		"tick 72 must read 'Year 6, Month 1 of the Silence', got '%s'" % world.date_string())
	world.tick = 0
	print("the Silence calendar reads correctly (tick 0 and tick 72)")
	assert(world.in_blood_feud(0, 1), "the canonical Halvenard-Veil / Aurath-Voss feud must smolder from Year Zero")
	print("the 200-year feud between Halvenard-Veil and Aurath-Voss is live")

	print("\nrealms at Year Zero:")
	for r in map.realms:
		var held := 0
		for p in map.provinces:
			if p.owner == r.id:
				held += 1
		print("  %s — %s, %d counties, capital %s, %s%s" % [r.name, r.government, held,
			map.provinces[r.capital_province_id].name, r.founding_house,
			(" — " + str(r.ruler)) if str(r.ruler) != "" else ""])

	print("\nALL MAP CHECKS PASSED")
	quit(0)
