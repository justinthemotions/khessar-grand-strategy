extends SceneTree

## Headless validation of the Cultural Roster (v1.0) implementation:
##   <godot.exe> --headless --path . --script res://tests/culture_roster_test.gd
## Checks the culture data, the 20 new unit presets, recruit gating
## (Design Decision A), the Compact-Sworn dissolution, marriage
## acceptance, upkeep tables, and the new battle-sim mechanics.

const NEW_KINDS: Array[String] = [
	"vael_arcane_retinue", "vael_court_company",
	"aelindran_household_cavalry", "aelindran_sworn_sword",
	"city_watch", "contract_militia",
	"harbor_guard", "coin_sworn",
	"drevak_berserker", "drevak_war_column",
	"compact_sworn",
	"dwarven_ironside", "ward_speaker_retinue",
	"brushgate_column",
	"veldarin_forest_sworn", "veldarin_elder_guard",
	"thaladris_song_bound", "thaladris_elder_guard",
	"southern_marine", "trade_guard",
]

const TWELVE_CULTURES: Array[String] = [
	"vael", "aelindran", "free_city", "halveni", "drevak", "karn_vol",
	"kharak_dum", "brushgate", "veldarin", "thaladris", "southern_reach",
	"sovereignty",
]


func _init() -> void:
	# --- culture data integrity ---
	assert(CultureData.CULTURES.size() == 12, "twelve cultures at Year Zero, got %d" % CultureData.CULTURES.size())
	for cid in TWELVE_CULTURES:
		assert(CultureData.CULTURES.has(cid), "missing culture: %s" % cid)
	for cid in CultureData.CULTURES:
		var m: Dictionary = CultureData.CULTURES[cid]["marriage"]
		for other in m:
			assert(CultureData.CULTURES.has(other), "%s marriage table names unknown culture %s" % [cid, other])
		for kind in CultureData.CULTURES[cid]["units"]:
			assert(BattleSim.PRESETS.has(kind), "%s roster kind %s has no battle preset" % [cid, kind])
	assert(CultureData.CULTURES["sovereignty"]["units"].is_empty(), "Sovereignty units must be dormant at Year Zero")
	assert(CultureData.DORMANT_UNITS.size() == 3, "the Pale Court archives hold three dormant unit kinds")
	for dormant in CultureData.DORMANT_UNITS:
		assert(not BattleSim.PRESETS.has(dormant), "dormant Sovereignty kind %s must not be recruitable data" % dormant)
	print("culture data: 12 cultures, tables consistent, Sovereignty dormant")

	# marriage acceptance is symmetrized: aelindran-drevak is the coldest match
	assert(CultureData.marriage_acceptance("aelindran", "drevak") == -25, "aelindran/drevak averages (-25 + -25)/2")
	assert(CultureData.marriage_acceptance("drevak", "karn_vol") == 25, "drevak/karn_vol averages (+30 + +20)/2")
	assert(CultureData.marriage_acceptance("vael", "vael") == 0, "same-culture matches carry no modifier")
	print("marriage acceptance tables symmetrized correctly")

	# --- battle presets: all 20 new kinds, sane stats, special hooks ---
	# (24 Roster kinds + 5 Tactical Combat v1.0 kinds — the Order, Caeris's
	# forces, and the Forsaken militia have their own test suite)
	assert(BattleSim.PRESETS.size() == 29, "4 universal + 20 cultural + 5 Tactical Combat kinds, got %d" % BattleSim.PRESETS.size())
	for kind in NEW_KINDS:
		assert(BattleSim.PRESETS.has(kind), "missing preset: %s" % kind)
		var p: Dictionary = BattleSim.PRESETS[kind]
		assert(int(p["soldiers"]) > 0 and float(p["hp"]) > 0.0 and float(p["lead"]) > 0.0, "%s has degenerate stats" % kind)
		assert(SimWorld.UNIT_LABELS.has(kind), "%s missing from UNIT_LABELS" % kind)
		assert(SimWorld.UNIT_WEIGHTS.has(kind), "%s missing from UNIT_WEIGHTS" % kind)
		assert(SimWorld.RECRUIT_COST.has(kind), "%s missing from RECRUIT_COST" % kind)
		assert(SimWorld.RECRUIT_SIZE.has(kind), "%s missing from RECRUIT_SIZE" % kind)
		assert(int(SimWorld.RECRUIT_SIZE[kind]) == int(p["soldiers"]), "%s recruit size != preset soldiers" % kind)
		assert(CultureData.recruit_culture(kind) != "", "%s must be culture-gated" % kind)
	assert(float(BattleSim.PRESETS["dwarven_ironside"]["armour"]) == 24.0, "Ironsides carry the heaviest armour in the game")
	assert(float(BattleSim.PRESETS["drevak_berserker"]["never_routs_above"]) == 0.25, "the Berserker oath holds at 25%")
	assert(bool(BattleSim.PRESETS["brushgate_column"]["silence_immunity"]), "Brushgate Columns are silence-immune")
	assert(bool(BattleSim.PRESETS["vael_arcane_retinue"]["ward_shield"]), "arcane wards work at all arcs")
	assert(BattleSim.PRESETS["veldarin_elder_guard"]["ma"] == BattleSim.PRESETS["thaladris_elder_guard"]["ma"],
		"the Elder-Guard doctrine is shared between the Great Houses")
	print("24 battle presets with the Roster's stat blocks and special hooks")

	# --- province majority cultures on the Khessar map ---
	var map := WorldMap.new()
	map.generate(777)
	var counts := {}
	for p in map.provinces:
		assert(p.culture != "", "%s has no majority culture" % p.name)
		assert(CultureData.CULTURES.has(p.culture), "%s has unknown culture %s" % [p.name, p.culture])
		counts[p.culture] = int(counts.get(p.culture, 0)) + 1
	assert(int(counts.get("aelindran", 0)) == 4, "the old noble countryside is four Aelindran counties")
	assert(int(counts.get("halveni", 0)) == 1, "Halven alone practices the merchant-democrat variant")
	assert(int(counts.get("karn_vol", 0)) == 4, "the border clan holds four Karn-Vol counties")
	assert(int(counts.get("drevak", 0)) == 4, "Vor-Grim's interior clans hold four Drevak counties")
	assert(int(counts.get("sovereignty", 0)) == 3, "the dead culture holds only the Aurath ruins")
	assert(int(counts.get("brushgate", 0)) == 0, "Brushgate has no majority province at Year Zero")
	print("province cultures assigned — %s" % str(counts))

	# --- the live sim: gating, dissolution, character culture ---
	var world := SimWorld.new()
	world.setup()
	assert(world.realm_cultures(0).has("vael") and world.realm_cultures(0).has("aelindran"),
		"the Magistocracy holds both Vael and Aelindran land")
	assert(world.recruit_gate(0, "levy") == "", "the universal roster is always open")
	assert(world.recruit_gate(0, "aelindran_household_cavalry") == "", "Vael's noble houses field Household Cavalry")
	assert(world.recruit_gate(0, "vael_arcane_retinue") == "", "the academies muster the Arcane Retinue")
	assert(world.recruit_gate(0, "dwarven_ironside") != "", "no Dwarven province, no Ironsides")
	assert(world.recruit_gate(0, "drevak_berserker") != "", "no Drevak province, no Berserkers")
	assert(world.recruit_gate(1, "drevak_berserker") == "", "Karn-Vol land satisfies the parent Drevak culture")
	assert(world.recruit_gate(1, "compact_sworn") == "", "the compact holds at Year Zero")
	assert(world.recruit_gate(1, "brushgate_column") != "", "no monastery access without Dwarven land")
	print("recruit gating follows Design Decision A (identity is geography)")

	# character culture: the Vael court is Aelindran-cultured (Roster §2);
	# the Faction Cast (realm 2+) carry their own canonical cultures
	for cid in world.characters:
		var c = world.characters[cid]
		if c.realm_id >= 2:
			continue
		assert(c.culture == ("aelindran" if c.realm_id == 0 else "karn_vol"),
			"%s has culture %s in realm %d" % [c.name, c.culture, c.realm_id])
	print("court characters carry their canonical cultures")

	# Compact-Sworn dissolve when the compact breaks
	world.realms[1].gold = 1000.0
	var err: String = world.recruit(1, "compact_sworn")
	assert(err == "", "Karn-Vol should muster Compact-Sworn in peace: %s" % err)
	var found := false
	for a in world.armies:
		for reg in a.regiments:
			if str(reg["kind"]) == "compact_sworn":
				found = true
	assert(found, "the Compact-Sworn company should stand in the roster")
	var _war := world.declare_war(1)
	for a in world.armies:
		for reg in a.regiments:
			assert(str(reg["kind"]) != "compact_sworn", "the Compact-Sworn must dissolve when the compact breaks")
	assert(world.recruit_gate(1, "compact_sworn") != "", "no Compact-Sworn muster during the war")
	print("the Compact-Sworn dissolve the moment the compact breaks")

	# per-kind upkeep is wired: elite units cost more than the flat rate
	assert(float(SimWorld.UNIT_UPKEEP["vael_arcane_retinue"]) == 0.15, "Arcane Retinue upkeep per the Roster")
	assert(not SimWorld.UNIT_UPKEEP.has("levy"), "the universal roster keeps the flat rate")
	print("per-kind upkeep follows the Roster's stat blocks")

	# --- battle-sim mechanics smoke tests ---
	# never-routs: a berserker company under absurd shock keeps fighting
	var sim := BattleSim.new()
	sim.setup_from_rosters([{"kind": "drevak_berserker", "soldiers": 20}], [{"kind": "sword", "soldiers": 36}],
		0, 0, ["A", "B"])
	var zerk: BattleSim.Regiment = sim.regiments[0]
	zerk.shock = 500.0
	assert(zerk.morale() <= 0.0, "sanity: shock this deep breaks ordinary men")
	sim.combat_tick()
	assert(not zerk.routed, "Berserkers at full strength cannot rout")
	zerk.soldiers = 3  # below the 25% oath threshold
	zerk.shock = 500.0
	sim.combat_tick()
	assert(zerk.routed, "below the oath threshold, deep shock finally breaks them")
	print("the Berserker oath holds above 25% strength")

	# auras: a ward-speaker projects lead onto a neighbor, not itself
	var sim2 := BattleSim.new()
	sim2.setup_from_rosters([{"kind": "ward_speaker_retinue", "soldiers": 16}, {"kind": "sword", "soldiers": 36}],
		[{"kind": "sword", "soldiers": 36}], 0, 0, ["A", "B"])
	sim2.regiments[1].pos = sim2.regiments[0].pos + Vector2(50, 0)
	sim2.combat_tick()
	assert(sim2.regiments[1].aura_bonus == 10.0, "the ward aura reaches a neighbor at 50px")
	assert(sim2.regiments[0].aura_bonus == 0.0, "auras project outward, never onto their bearers")
	assert(sim2.regiments[2].aura_bonus == 0.0, "enemy regiments feel no friendly aura")
	print("ward and song auras project correctly")

	# terrain: forest wakes the Forest-Sworn, coast wakes the Marines
	var sim3 := BattleSim.new()
	sim3.setup_from_rosters([{"kind": "veldarin_forest_sworn", "soldiers": 20}],
		[{"kind": "southern_marine", "soldiers": 32}], 0, 0, ["A", "B"], [], [], "forest")
	assert(sim3.regiments[0].ma == 26.0 and sim3.regiments[0].speed == 47.0, "forest bonuses apply in forest")
	assert(sim3.regiments[1].ma == 30.0, "coastal bonuses stay dormant in forest")
	var sim4 := BattleSim.new()
	sim4.setup_from_rosters([{"kind": "veldarin_forest_sworn", "soldiers": 20}],
		[{"kind": "southern_marine", "soldiers": 32}], 0, 0, ["A", "B"], [], [], "coast")
	assert(sim4.regiments[0].ma == 18.0, "forest bonuses stay dormant on the coast")
	assert(sim4.regiments[1].ma == 36.0, "coastal bonuses apply on the coast")
	print("terrain bonuses wake in the right terrain")

	# panic resistance: Brushgate shock_mult is 40% of a sword's
	var sim5 := BattleSim.new()
	sim5.setup_from_rosters([{"kind": "brushgate_column", "soldiers": 18}], [{"kind": "sword", "soldiers": 36}],
		0, 0, ["A", "B"])
	assert(absf(sim5.regiments[0].shock_mult - 0.4) < 0.001, "panic_resistance 0.60 leaves 40% shock")
	assert(sim5.regiments[0].silence_immune, "silence immunity flag carried onto the field")
	print("Brushgate panic resistance and silence immunity in place")

	# a full auto-resolved battle with cultural rosters ends cleanly
	var sim6 := BattleSim.new()
	sim6.setup_from_rosters(
		[{"kind": "dwarven_ironside", "soldiers": 24}, {"kind": "ward_speaker_retinue", "soldiers": 16}],
		[{"kind": "drevak_berserker", "soldiers": 20}, {"kind": "drevak_war_column", "soldiers": 32}],
		0, 0, ["Hold", "Clan"])
	sim6.run_headless()
	assert(sim6.ended and sim6.winner >= -1, "the cultural battle must resolve")
	print("Ironsides vs Berserkers auto-resolves (winner: side %d)" % sim6.winner)

	print("\nALL CULTURE ROSTER CHECKS PASSED")
	quit(0)
