extends SceneTree

## Module 7 test: Warfare & Combat Mechanics and its expansions — supply
## limits & starvation attrition, the Baggage Train & severed lines of
## communication, sieges & occupation, the Battle Grid's tactical orders,
## the levy panic cascade, Scorched Earth & partisan cells, and the named
## champions who ride with the host. Run from the project folder:
##   <godot.exe> --headless --path . --script res://tests/warfare_module_test.gd

func _init() -> void:
	var world := SimWorld.new()
	var events: Array = []
	world.event_logged.connect(func(t: String) -> void: events.append(t))
	world.setup()
	world.auto_resolve_events = true

	# --- 1. the Supply Limit: terrain feeds, home granaries stretch, fire empties ---
	var karn_p = null       # a Karn-Vol county for the invasion tests
	var karn_border = null  # one that touches Vael, for the cession test
	for p in world.map.provinces:
		if p.owner != 1:
			continue
		if karn_p == null:
			karn_p = p
		for nid in p.neighbors:
			if world.map.provinces[nid].owner == 0:
				karn_border = p
				break
		if karn_border != null:
			break
	assert(karn_p != null and karn_border != null, "the map must give Karn-Vol land and a shared border")
	var base: int = SimWorld.SUPPLY_BY_TERRAIN.get(karn_p.terrain, 300)
	assert(world.province_supply(karn_p, 0) == base, "an invader lives off the raw land")
	assert(world.province_supply(karn_p, 1) == int(base * SimWorld.SUPPLY_HOME_MULT), "home granaries must stretch the limit")
	world.scorched[karn_p.id] = world.tick + 10
	assert(world.province_supply(karn_p, 1) == 0, "scorched fields feed no one — not even their own")
	world.scorched.clear()
	print("supply limits ok — %s (%s): %d for invaders, %d at home, 0 under ash" % [
		karn_p.name, karn_p.terrain, base, int(base * SimWorld.SUPPLY_HOME_MULT)])

	# --- 2. starvation attrition abroad; the home network feeds any host ---
	var inv: SimWorld.Army = world.armies_of(0)[0]
	inv.regiments = [{"kind": "levy", "soldiers": 400, "max": 400}, {"kind": "sword", "soldiers": 200, "max": 200}]
	inv.pos = karn_p.center
	world.tick = 5  # high summer — no winter doubling yet
	var before := inv.size()
	world._army_supply_tick(inv)
	var summer_loss := before - inv.size()
	assert(summer_loss > 0, "600 men on a county that feeds %d must starve" % base)
	# winter doubles the hunger on foreign soil
	for reg in inv.regiments:
		reg["soldiers"] = 300
	world.tick = 11
	assert(world.is_winter(), "month 12 must be winter")
	before = inv.size()
	world._army_supply_tick(inv)
	var winter_loss := before - inv.size()
	world.tick = 5
	for reg in inv.regiments:
		reg["soldiers"] = 300
	before = inv.size()
	world._army_supply_tick(inv)
	var summer_loss2 := before - inv.size()
	assert(winter_loss > summer_loss2, "winter must starve a foreign host faster (winter %d vs summer %d)" % [winter_loss, summer_loss2])
	# the same oversized host on its own intact soil is fed by the realm
	var vael_home = null
	for p in world.map.provinces:
		if p.owner == 0 and p.de_jure == 0:
			vael_home = p
			break
	inv.pos = vael_home.center
	for reg in inv.regiments:
		reg["soldiers"] = 400
	before = inv.size()
	world._army_supply_tick(inv)
	assert(inv.size() == before, "a host on its own intact soil is fed by the granary network")
	print("attrition ok — summer %d men, winter %d men lost abroad; zero at home" % [summer_loss2, winter_loss])

	# --- 3. the Baggage Train: severed lines starve and stop reinforcement ---
	var werr := world.declare_war(0)
	assert(werr == "", "the invasion must march: " + werr)
	assert(world.war_aggressor == 0, "the war must remember who marched first")
	inv.pos = karn_p.center
	world._army_supply_tick(inv)
	assert(inv.train_active, "an army on foreign soil must trail a baggage train")
	assert(inv.severed_months == 0, "no raider on the wagons yet")
	# a Karn-Vol army loops behind and sits on the wagons
	var raider: SimWorld.Army = world.armies_of(1)[0]
	raider.pos = inv.train_pos
	world._army_supply_tick(inv)
	assert(inv.severed_months == 1, "an enemy on the train must sever the line of communication")
	var sev_before := inv.size()
	world._army_supply_tick(inv)
	assert(inv.severed_months == 2, "the severance compounds by the month")
	assert(inv.size() < sev_before, "a severed army starves even under the supply limit")
	# no reinforcements reach a severed army
	inv.regiments[0]["soldiers"] = int(inv.regiments[0]["soldiers"]) - 20
	world.realms[0].gold = 500.0
	var hungry: int = int(inv.regiments[0]["soldiers"])
	world._military_upkeep()
	assert(int(inv.regiments[0]["soldiers"]) == hungry, "no recruits reach an army whose wagons burn")
	raider.pos = world.map.realm_centroid(1)
	world._army_supply_tick(inv)
	assert(inv.severed_months == 0, "the line reopens when the raider rides off")
	world._military_upkeep()
	assert(int(inv.regiments[0]["soldiers"]) > hungry, "reinforcement resumes once the road is open")
	print("baggage train ok — severed, starved, cut off from muster, then reopened")

	# --- 4. sieges: circumvallation, the fall, and what occupation denies ---
	# clear the field so the siege is uncontested
	for a in world.armies_of(1):
		a.pos = world.map.realm_centroid(1) + Vector2(0.2, 0.2)
		a.has_target = false
	inv.pos = karn_border.center
	inv.severed_months = 0
	var tax_before := world.realm_tax_eff(1)
	var score_before := world.war_score
	var months := 0
	while not world.occupied.has(karn_border.id) and months < 40:
		world._sieges_tick()
		months += 1
	assert(world.occupied.get(karn_border.id, -1) == 0, "an uncontested siege must end in occupation")
	assert(world.war_score > score_before, "a county's fall must swing the war")
	assert(world.realm_tax_eff(1) < tax_before, "an occupied county pays its crown nothing")
	print("siege ok — %s fell after %d months (fort level %d), and its taxes fell silent" % [
		karn_border.name, months, world.fort_level(karn_border)])

	# --- 5. occupation is leverage, and the treaty cedes what the sword holds ---
	world.war_score = 80.0
	world.war_battles_won = [1, 0]
	var _peace := world.negotiate_peace()
	assert(not world.at_war, "the treaty must end the war")
	assert(world.occupied.is_empty(), "occupation armies march home at the peace")
	assert(world.last_war_occupied.has(karn_border.id), "the table must remember what was held")
	# the cession preference, tested directly at the drafting table
	var owner_before: int = karn_border.owner
	if owner_before == 1:
		world._cede_border_province(world.realms[0], world.realms[1])
		assert(karn_border.owner == 0, "the county held under the sword changes hands first")
		print("cession ok — %s, occupied at war's end, is what the treaty takes" % karn_border.name)
	else:
		print("cession ok — the treaty already took %s at the table" % karn_border.name)

	# --- 6. Scorched Earth: a defender's protocol, with partisan teeth ---
	# Vael marches again; Karn-Vol defends its own de jure soil
	world.truce_until = -999
	world.dispossessed.clear()
	var werr2 := world.declare_war(0)
	assert(werr2 == "", "the second invasion must march: " + werr2)
	var scorch_target = null
	for p in world.map.provinces:
		if p.owner == 1 and p.de_jure == 1:
			scorch_target = p
			break
	assert(scorch_target != null, "Karn-Vol must still hold rightful soil")
	assert(world.scorch_earth(0, scorch_target.id) != "", "the aggressor may not invoke the protocol")
	var serr := world.scorch_earth(1, scorch_target.id)
	assert(serr == "", "the defender must be able to burn its own fields: " + serr)
	assert(world.province_supply(scorch_target, 0) == 0, "a scorched county feeds no invader")
	assert(int(world.partisans.get(scorch_target.id, -1)) == 1, "the peasants must take to the hills")
	# partisans sever any invader's train and freeze any siege on that ground
	inv.pos = scorch_target.center
	inv.severed_months = 0
	world._army_supply_tick(inv)
	assert(inv.severed_months == 1, "partisan night raids must sever the invader's train")
	world._sieges_tick()
	assert(not world.sieges.has(scorch_target.id), "no siege makes progress on partisan ground")
	var levy_scorched := world.realm_levy_eff(1)
	world.scorched.erase(scorch_target.id)
	var levy_whole := world.realm_levy_eff(1)
	world.scorched[scorch_target.id] = world.tick + SimWorld.SCORCH_MONTHS
	assert(levy_scorched < levy_whole, "the burned county musters fewer spears for its own crown too")
	print("scorched earth ok — %s burned: supply 0, partisans up, train severed, siege frozen" % scorch_target.name)
	world.negotiate_peace()

	# --- 7. the Battle Grid: tactical orders are gated on the commander ---
	var ts := BattleSim.new()
	ts.setup_from_rosters(
		[{"kind": "cav", "soldiers": 16, "max": 16}, {"kind": "sword", "soldiers": 36, "max": 36}, {"kind": "levy", "soldiers": 48, "max": 48}],
		[{"kind": "sword", "soldiers": 36, "max": 36}, {"kind": "sword", "soldiers": 36, "max": 36}],
		10, 8, ["Vael", "Karn-Vol"])
	assert(ts.tactic_gate(0, "feigned_retreat") != "", "no commander info means no orders")
	ts.set_commander_info(0, {"martial": 8, "intrigue": 14, "prowess": 13, "traits": ["Wrathful"]})
	assert(ts.tactic_gate(0, "feigned_retreat") == "", "Intrigue 14 can sell a false rout")
	assert(ts.tactic_gate(0, "commit_reserve") != "", "Martial 8 without Patience holds no reserve")
	assert(ts.tactic_gate(0, "chivalric_charge") == "", "Wrathful blood leads the charge")
	var terr := ts.use_tactic(0, "feigned_retreat")
	assert(terr == "", "the feigned retreat must play: " + terr)
	var lured := 0
	for r: BattleSim.Regiment in ts.regiments:
		if r.side == 1 and r.lure_ticks > 0:
			lured += 1
	assert(lured == 1, "exactly one enemy formation takes the bait")
	assert(ts.tactic_gate(0, "feigned_retreat").contains("played"), "each card plays once")
	var cerr := ts.use_tactic(0, "chivalric_charge")
	assert(cerr == "", "the charge must sound: " + cerr)
	assert(ts.commander_charged[0], "the fate rolls must remember who rode in front")
	ts.set_commander_info(0, {"martial": 8, "intrigue": 14, "prowess": 13, "traits": ["Patient"]})
	var reserve: BattleSim.Regiment = ts._rearmost_own(0)
	reserve.shock = 40.0
	var rerr := ts.use_tactic(0, "commit_reserve")
	assert(rerr == "", "the Patient hand must commit the reserve: " + rerr)
	assert(reserve.shock == 0.0 and reserve.morale_bonus >= BattleSim.RESERVE_COHESION, "fresh men fight above themselves")
	print("battle grid ok — false rout lured %d formation, the charge sounded, the reserve marched" % lured)

	# --- 8. the levy panic cascade: conscripts break, professionals hold ---
	var cs := BattleSim.new()
	cs.setup_from_rosters(
		[{"kind": "sword", "soldiers": 36, "max": 36}, {"kind": "levy", "soldiers": 48, "max": 48}, {"kind": "sword", "soldiers": 36, "max": 36}],
		[{"kind": "sword", "soldiers": 36, "max": 36}],
		0, 0, ["Vael", "Karn-Vol"])
	var router: BattleSim.Regiment = cs.regiments[0]
	var conscripts: BattleSim.Regiment = cs.regiments[1]
	var pros: BattleSim.Regiment = cs.regiments[2]
	router.pos = Vector2(300, 300)
	conscripts.pos = Vector2(300, 400)
	pros.pos = Vector2(300, 460)
	cs._cascade_panic(router)
	assert(conscripts.shock > 0.0, "levies near a breaking formation must check their courage")
	assert(pros.shock == 0.0, "professional squads hold when the levies look over their shoulders")
	var panicked := conscripts.shock
	conscripts.shock = 0.0
	cs.side_lead = [20, 0]
	cs._cascade_panic(router)
	assert(conscripts.shock < panicked, "a commander's presence must dampen the cascade (%.0f vs %.0f)" % [conscripts.shock, panicked])
	print("panic cascade ok — levies shocked %.0f unled, %.0f under a Martial-20 hand; the swords held" % [panicked, conscripts.shock])

	# --- 9. champions: the named blades who steady the host ---
	var champs: Array = world.champions_of(0)
	assert(champs.size() > 0 and champs.size() <= SimWorld.CHAMPION_COUNT, "the realm must field champions")
	for i in range(1, champs.size()):
		assert(champs[i - 1].prowess >= champs[i].prowess, "champions rank by prowess")
	var commanders := {}
	for a in world.armies:
		if a.commander_id >= 0:
			commanders[a.commander_id] = true
	for c in champs:
		assert(not commanders.has(c.id), "a commander is not also a champion")
	var host: SimWorld.Army = world.main_army_of(0)
	var mod_fed := world.battle_lead_mod(host)
	host.severed_months = 3
	var mod_starved := world.battle_lead_mod(host)
	assert(mod_starved <= mod_fed - 5, "three severed months hollow ~6 leadership from the line (%d -> %d)" % [mod_fed, mod_starved])
	host.severed_months = 0
	print("champions ok — %d ride with the host (+%d leadership); hunger costs 2 a month" % [champs.size(), mod_fed])

	# --- 10. ten-year soak: the whole engine grinds together ---
	world.realms[0].gold = 800.0
	world.realms[1].gold = 800.0
	var wars := 0
	var battles := 0
	for month in 120:
		world.advance_month()
		if not world.at_war and not world.allied() and world.tick >= world.truce_until and wars < 2:
			if world.declare_war(0) == "":
				wars += 1
		if world.battle_ready:
			var pa = world.army_by_id(world.pending_battle[0])
			var pb = world.army_by_id(world.pending_battle[1])
			var sim := BattleSim.new()
			sim.setup_from_rosters(pa.regiments, pb.regiments, 8, 8, ["Vael", "Karn-Vol"])
			sim.set_commander_info(0, {"martial": 12, "intrigue": 8, "prowess": 10, "traits": ["Patient"]})
			sim.set_commander_info(1, {"martial": 10, "intrigue": 8, "prowess": 14, "traits": ["Wrathful"]})
			sim.run_headless()
			var ids: Array = world.pending_battle.duplicate()
			for side in 2:
				var results: Array = []
				for r: BattleSim.Regiment in sim.regiments:
					if r.side == side:
						results.append({"index": r.roster_index, "soldiers": r.soldiers, "routed": r.routed})
				world.apply_battle_casualties(ids[side], results, sim.winner >= 0 and sim.winner != side)
			var loss := 0.0
			if sim.winner >= 0:
				loss = 1.0 - sim.survivors_fraction(1 - sim.winner)
			world.apply_battle_result(sim.winner, loss, sim.commander_charged)
			battles += 1
	var siege_logs := 0
	var hunger_logs := 0
	var severed_logs := 0
	var scorch_logs := 0
	var champion_logs := 0
	for e in events:
		if str(e).contains("lays siege to") or str(e).contains("falls to"):
			siege_logs += 1
		if str(e).contains("Hunger stalks"):
			hunger_logs += 1
		if str(e).contains("supply line of"):
			severed_logs += 1
		if str(e).contains("Scorched Earth Protocol"):
			scorch_logs += 1
		if str(e).contains("championing the host") or str(e).contains("champion of the host") or str(e).contains("champion in chains"):
			champion_logs += 1
	print("\n=== after the soak (%s) ===" % world.date_string())
	print("wars declared: %d · field battles: %d" % [wars, battles])
	print("siege chronicle lines: %d · hunger: %d · severed trains: %d · scorched earth: %d · champion fates: %d" % [
		siege_logs, hunger_logs, severed_logs, scorch_logs, champion_logs])
	for a in world.armies:
		for reg in a.regiments:
			assert(int(reg["soldiers"]) > 0, "no ghost regiments after the soak")
	assert(wars > 0, "a decade of bad neighbors must produce a war")
	print("\nlast 10 events:")
	for e in events.slice(maxi(0, events.size() - 10)):
		print("  " + str(e))
	print("\nALL WARFARE CHECKS PASSED")
	quit(0)
