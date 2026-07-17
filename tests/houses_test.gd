extends SceneTree

## Canon Pass Two §3: the noble houses. Forty-six houses and
## institutions, governments that follow lore rather than genre
## convention, the anchor-mage lineages, and the Ironbrand concealment —
## the discoverable that unlocks a mechanical understanding. Run:
##   <godot.exe> --headless --path . --script res://tests/houses_test.gd

func _init() -> void:
	print("=== houses test (Canon Pass Two) ===")

	# --- group 1: the substrate — 46 houses, structure and hooks ---
	assert(CanonData.HOUSES.size() == 46,
		"forty-six houses and institutions (got %d)" % CanonData.HOUSES.size())
	for key in ["sarkenvault", "ossrel", "vanneth", "vessrel"]:
		assert(CanonData.HOUSES.has(key), "the four anchor-mage lineages are houses too (%s)" % key)
		assert(str(CanonData.HOUSES[key]["kind"]) == "anchor_lineage", "%s is marked for what it is" % key)
	assert(bool(CanonData.HOUSES["straven"]["refuses_compact"]),
		"House Straven KNOWS what it carries and refuses to draw on it — the blood-compact is not 'the Tiefling lineage'")
	print("substrate: 46 houses, four lineages, the counter-example on the record")

	# --- group 2: governments follow lore, not genre convention ---
	var world := SimWorld.new()
	world.setup()
	world.auto_resolve_events = true
	assert(str(world.map.realms[0].government) == "administrative",
		"the Magistocracy is a rotating mage oligarchy — NOT feudal, and never a kingdom")
	assert(str(world.realms[0].government) == "administrative", "the live realm carries the same truth")
	assert(str(world.map.realms[5].government) == "merchant_republic", "Halven is a merchant council")
	assert(str(world.map.realms[9].government) == "clan" and str(world.map.realms[10].government) == "clan",
		"the Elven Great Houses are houses, not crowns")
	assert(str(world.map.realms[1].government) == "tribal", "the Orc clans are bloodline structures")
	print("governments: oligarchy, councils, clans — no crowns where canon has none")

	# --- group 3: the buried hooks are in the web, outside the tavern pool ---
	var buried := {}
	for s in world.secrets:
		if bool(s.get("under", false)):
			buried[str(s["type"])] = s
	for type in ["rorend_patron_vote", "iorek_confession", "crannock_mira_forsaken",
			"vannin_memories", "talan_faerith_romance", "ironbrand_concealment", "bone_court_patronage"]:
		assert(buried.has(type), "the hook must be planted: %s" % type)
		assert((buried[type]["known"] as Dictionary).is_empty(),
			"buried means buried — no realm knows %s at Year Zero" % type)
	var mira_found := false
	for c in world.characters.values():
		if c.name == "Mira" and world.dynasties.has(c.dynasty_id) \
				and world.dynasties[c.dynasty_id].name == "House Crannock-Vey":
			mira_found = true
			assert(int(buried["crannock_mira_forsaken"]["subject"]) == c.id,
				"the Forsaken daughter hook lands on the real Mira Crannock-Vey")
	assert(mira_found, "Mira Crannock-Vey exists in the cast")
	print("hooks: seven buried secrets planted, all outside the informants' pool")

	# --- group 4: the Ironbrand concealment — the integration that matters most ---
	world.realms[0].gold = 100.0
	assert(not world.wardstone_linkage_known, "the WHY starts hidden")
	var err := world.investigate_house(0, "ironbrand")
	assert(err == "", "the Spymaster's season should succeed (got '%s')" % err)
	assert(world.wardstone_linkage_known,
		"uncovering Ironbrand unlocks a mechanical understanding, not just a scandal")
	assert(bool(world.house_records["ironbrand"]["discovered"]), "the vault is read")
	var known := false
	for s in world.secrets:
		if str(s["type"]) == "ironbrand_concealment" and (s["known"] as Dictionary).has(0):
			known = true
	assert(known, "the crown now holds the concealment")
	var again := world.investigate_house(0, "ironbrand")
	assert(again != "", "a vault reads once")
	print("ironbrand: the house lying about the ward-stones was lying about the mechanism — now the crown knows why")

	# --- group 5: the Rorend vote reaches daylight through the cult, or the vault ---
	var w2 := SimWorld.new()
	w2.setup()
	w2.auto_resolve_events = true
	w2.realms[0].gold = 100.0
	var err2 := w2.investigate_house(0, "halvenard_veil")
	assert(err2 == "", "the crown may read its own great house's vault (got '%s')" % err2)
	var rorend_known := false
	for s in w2.secrets:
		if str(s["type"]) == "rorend_patron_vote" and (s["known"] as Dictionary).has(0):
			rorend_known = true
	assert(rorend_known, "Rorend's Patron vote is discoverable")
	print("rorend: eighty-eight years buried, one season of vault-work to read")

	# --- group 6: the roster wiring — anchor-mages live where the houses say ---
	for key in world.anchor_mages:
		var m: Dictionary = world.anchor_mages[key]
		assert(CanonData.HOUSES.has(str(m["house"])) or str(m["house"]) == "ossrel"
			or str(m["house"]) == "sarkenvault" or str(m["house"]) == "vanneth" or str(m["house"]) == "vessrel",
			"every anchor-mage belongs to a lineage the houses know (%s)" % key)
		var pid := int(m["pid"])
		assert(pid >= 0 and pid < world.map.provinces.size(), "and to a real province")
	print("roster: fifteen anchor-mages, four lineages, all on the map")

	print("ALL HOUSES CHECKS PASSED")
	quit()
