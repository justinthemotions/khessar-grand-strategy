extends SceneTree

## Module 5 test: Diplomacy & Inter-State Relations and its expansions —
## casus belli, prestige & truces, hostages & wards, the war-leverage
## treaty table, the Traitor's Tribunal, houses-in-exile, and the
## Broken Blade demobilization cycle. Run from the project folder:
##   <godot.exe> --headless --path . --script res://tests/diplomacy_module_test.gd

func _init() -> void:
	var world := SimWorld.new()
	var events: Array = []
	world.event_logged.connect(func(t: String) -> void: events.append(t))
	world.setup()
	world.auto_resolve_events = true

	# --- 1. casus belli: the tribal way needs no lawyers ---
	assert(world.available_cbs(1).has("subjugation"), "a tribal realm must always carry Subjugation")
	var vael_cbs: Array = world.available_cbs(0)
	print("Year Zero CBs — Vael: %s · Karn-Vol: %s" % [str(vael_cbs), str(world.available_cbs(1))])

	# --- 2. an unjust war is remembered everywhere ---
	var prestige_before: float = world.realms[0].prestige
	var tyranny_before: float = world.realms[0].tyranny
	var err := world.declare_war(0)
	assert(err == "", "declare_war failed: " + err)
	if vael_cbs.is_empty():
		assert(world.war_cb == "", "no CB in hand must mean an unjust war")
		assert(world.realms[0].prestige <= prestige_before - 40.0, "an unjust war must cost 40 prestige")
		assert(world.realms[0].tyranny >= tyranny_before + 15.0, "an unjust war must stain the crown at home")
		var defender: SimCharacter = world.characters[world.realms[1].ruler_id]
		var noted := false
		for m in defender.memories:
			if str(m["type"]) == "invaded without cause":
				noted = true
		assert(noted, "the defender must remember an unjust invasion")
		print("unjust war ok — prestige %+d, tyranny %.0f, and the Clan remembers" % [
			int(world.realms[0].prestige), world.realms[0].tyranny])
	else:
		assert(world.war_cb == str(vael_cbs[0]), "a war must march under its best claim")
		print("justified war ok — declared under %s" % SimWorld.CB_LABELS[world.war_cb])

	# --- 3. war leverage counts the battles carried ---
	world.war_battles_won = [2, 0]
	world.war_score = 80.0
	var truce_expected: int = world.tick + SimWorld.TRUCE_MONTHS
	var winner_prestige_before: float = world.realms[0].prestige
	var _p := world.negotiate_peace()
	assert(not world.at_war, "peace must end the war")
	assert(world.truce_until == truce_expected, "a peace must set a truce")
	assert(world.realms[0].prestige > winner_prestige_before, "victory must raise the winner's standing")
	print("treaty ok — the drafting table sat, truce until tick %d" % world.truce_until)

	# --- 4. breaking a truce is its own infamy ---
	var p_before: float = world.realms[0].prestige
	var err2 := world.declare_war(0)
	assert(err2 == "", "truce-breaking must be possible, just infamous: " + err2)
	assert(world.realms[0].prestige <= p_before - 30.0, "breaking a truce must cost 30 prestige")
	world.at_war = false
	world.war_score = 0.0
	world.war_cb = ""
	print("truce-breaking ok — prestige bled for the broken word")

	# --- 5. treaty terms, taken one by one ---
	var w: SimWorld.Realm = world.realms[0]
	var l: SimWorld.Realm = world.realms[1]
	# tribute
	w.gold = 100.0
	l.gold = 100.0
	world._term_tribute(w, l, 60.0)
	assert(w.gold == 160.0 and l.gold == 40.0, "tribute must move gold at the table")
	# the yoke: reparations flow, professional muster is barred
	world._term_yoke(w, l)
	assert(not world.reparations.is_empty(), "the yoke must open reparations")
	var demil_err := world.recruit(1, "sword")
	assert(demil_err.contains("demilitarization"), "a demilitarized realm must muster levies only (got '%s')" % demil_err)
	assert(world.recruit_gate(1, "levy") == "", "levies stay open under demilitarization")
	var l_gold_before: float = l.gold
	var w_gold_before: float = w.gold
	world._diplomacy_tick()
	assert(l.gold < l_gold_before and w.gold > w_gold_before, "reparations must flow monthly")
	print("the yoke ok — reparations flow, %d months remain, muster barred" % int(world.reparations["months_left"]))
	world.reparations = {}
	world.demilitarized_until.clear()
	# salted earth
	world.salted.clear()  # the AI's own treaty pick may already have salted land
	var tax_before: float = world.realm_tax_eff(1)
	world._term_salt(w, l)
	assert(not world.salted.is_empty(), "salting must scar a province")
	assert(world.realm_tax_eff(1) < tax_before, "salted land must yield less")
	var salted_pid: int = world.salted.keys()[0]
	world.salted[salted_pid] = world.tick  # heal it instantly for the next check
	world._diplomacy_tick()
	assert(world.salted.is_empty(), "healed scars must clear")
	print("salted earth ok — tax %.1f -> below, then the years heal it" % tax_before)

	# --- 6. collateral hostages sheathe the loser's sword ---
	var heir: SimCharacter = world.heir_of(1)
	assert(heir != null, "Karn-Vol needs an heir for the hostage test")
	world._term_hostage(w, l)
	assert(world.wards.has(heir.id) and bool(world.wards[heir.id]["hostage"]), "the heir must be taken hostage")
	assert(heir.realm_id == 0, "the hostage lives at the winner's court")
	var war_err := world.declare_war(1)
	assert(war_err.contains("hostage"), "a realm whose heir is held must not declare war (got '%s')" % war_err)
	l.gold = 200.0
	var ransom_err := world.ransom_ward(heir.id)
	assert(ransom_err == "", "ransom failed: " + ransom_err)
	assert(not world.wards.has(heir.id) and heir.realm_id == 1, "a ransomed ward comes home")
	print("hostage ok — %s held, war refused, ransomed home for %d gold" % [
		world.full_name(heir), int(SimWorld.RANSOM_COST)])

	# --- 7. fostering shapes the child ---
	var father: SimCharacter = world.characters[world.realms[0].ruler_id]
	var mother: SimCharacter = null
	for c in world.characters.values():
		var cc: SimCharacter = c
		if cc.alive and cc.is_female and cc.realm_id == 0 and cc.age_years(world.tick) >= 16 \
				and cc.age_years(world.tick) <= 45 and not world._close_kin(father, cc):
			mother = cc
			break
	assert(mother != null, "no mother available for the fostering test")
	var child: SimCharacter = world._make_child(father, mother)
	child.birth_tick = world.tick - 8 * 12  # eight years old
	var ward_err := world.send_ward(child.id, 1)
	assert(ward_err == "", "send_ward failed: " + ward_err)
	assert(child.realm_id == 1, "a ward lives at the host court")
	var guardian: SimCharacter = world.characters[int(world.wards[child.id]["guardian"])]
	var best_key := "diplomacy"
	var best_v := -1
	for key in SimWorld.STAT_PROPS.values():
		if int(guardian.get(key)) > best_v:
			best_v = int(guardian.get(key))
			best_key = str(key)
	var stat_before: int = child.get(best_key)
	# eight years pass in a heartbeat: of age, fostered since long ago
	child.birth_tick = world.tick - 16 * 12
	world.wards[child.id]["since"] = world.tick - 8 * 12
	world._wards_tick()
	assert(not world.wards.has(child.id), "a fostered ward comes home at 16")
	assert(child.realm_id == 0, "the returned ward rejoins the home realm")
	assert(int(child.get(best_key)) > stat_before, "mentorship must sharpen the guardian's best art")
	assert(child.culture == guardian.culture, "a long fostering must turn the child's culture")
	print("fostering ok — %s returns home %s-made, %s %d -> %d" % [
		world.full_name(child), CultureData.culture_label(child.culture),
		best_key, stat_before, int(child.get(best_key))])

	# --- 8. the Traitor's Tribunal: four verdicts ---
	# two traitors of another house, and a loyal kinsman of the crown's own —
	# so that attainder leaves the traitor house wholly landless
	var ruler_root: int = world.root_house_id(father.dynasty_id)
	var lords: Array = []
	for c in world.characters.values():
		var cc2: SimCharacter = c
		if cc2.alive and cc2.realm_id == 0 and cc2.age_years(world.tick) >= 16 \
				and not cc2.denounced and cc2.id != world.realms[0].ruler_id \
				and world.root_house_id(cc2.dynasty_id) != ruler_root:
			lords.append(cc2)
		if lords.size() >= 2:
			break
	assert(lords.size() >= 2, "the tribunal test needs two lords of another house")
	for c in world.characters.values():
		var cc4: SimCharacter = c
		if cc4.alive and cc4.realm_id == 0 and cc4.age_years(world.tick) >= 16 \
				and not cc4.denounced and cc4.id != world.realms[0].ruler_id \
				and world.root_house_id(cc4.dynasty_id) == ruler_root:
			lords.append(cc4)
			break
	assert(lords.size() >= 3, "the tribunal test needs a loyal kinsman of the crown")
	var free_pids: Array = []
	for p in world.map.provinces:
		if p.owner == 0 and world.county_holder(p.id) == null:
			free_pids.append(p.id)
	assert(free_pids.size() >= 3, "the tribunal test needs three crown counties to grant")
	for i in 3:
		var g_err: String = world.grant_title("county", free_pids[i], lords[i].id)
		assert(g_err == "", "grant failed: " + g_err)
	var loyal: SimCharacter = lords[2]

	# pardon: the traitor keeps his hall, the loyal remember
	world._tribunal_pardon(0, [lords[0].id])
	assert(world.county_holder(free_pids[0]) != null, "a pardoned traitor keeps his land")
	var bitter := false
	for m in loyal.memories:
		if str(m["type"]) == "mercy for traitors, nothing for the loyal":
			bitter = true
	assert(bitter, "loyalists must resent a total pardon")

	# the scaffold: death, attainder first, and a blood feud sworn
	var t_root: int = world.root_house_id(lords[0].dynasty_id)
	var tyr_before: float = world.realms[0].tyranny
	world._tribunal_scaffold(0, [lords[0].id])
	assert(not lords[0].alive, "the scaffold must hang the traitor")
	assert(world.county_holder(free_pids[0]) == null, "attainder must precede the rope")
	assert(world.in_blood_feud(ruler_root, t_root), "martyrs must breed a blood feud")
	assert(world.realms[0].tyranny > tyr_before, "mass execution must raise tyranny")
	print("scaffold ok — %s hanged, feud sworn, tyranny %.0f" % [
		world.full_name(lords[0]), world.realms[0].tyranny])

	# attainder: the landless house flees abroad and arms the enemy with a CB
	var exile_root: int = world.root_house_id(lords[1].dynasty_id)
	world._tribunal_attainder(0, [lords[1].id])
	assert(world.county_holder(free_pids[1]) == null, "attainder must strip the land")
	assert(world.dispossessed.has(exile_root), "a landless house must flee into exile")
	assert(lords[1].realm_id == 1, "the exiles live at the rival court")
	assert(world.available_cbs(1).has("restoration"), "sheltering exiles must grant a Restoration CB")
	var home_gold: float = world.realms[0].gold
	world._shadow_court_tick()
	assert(world.realms[0].gold < home_gold, "the shadow court must bleed the homeland")
	print("shadow court ok — the %s plot from exile, %s bleeds coin" % [
		world.dynasties[exile_root].name, world.realms[0].name])

	# restoration: the proxy war pays off and the exiles come home landed
	world._term_restore(world.realms[1], world.realms[0])
	assert(not world.dispossessed.has(exile_root), "restoration must close the exile")
	assert(lords[1].realm_id == 0, "the restored house comes home")
	assert(not world.counties_of(lords[1].id).is_empty(), "the restored lord must hold a county again")
	print("restoration ok — %s holds land again, owing everything to Karn-Vol" % world.full_name(lords[1]))

	# tonsure: out of the succession, into the scriptorium
	world._tribunal_tonsure(0, [lords[1].id])
	assert(lords[1].disinherited, "the tonsured stand outside every line of succession")
	assert(world.counties_of(lords[1].id).is_empty(), "the cloister keeps no counties")
	print("tonsure ok — %s takes unchosen vows" % world.full_name(lords[1]))

	# --- 9. the Broken Blade cycle: free companies ---
	var host := world.muster_army(0)
	var need: int = maxi(120, int(world.levy_capacity(0) / 2.0)) + 120
	var added := 0
	while added < need:
		host.regiments.append({"kind": "sword", "soldiers": 36, "max": 36})
		added += 36
	world._demob_turn_out(0, 120)
	assert(world.free_companies.size() == 1, "turned-out veterans must form a free company")
	var fc: SimWorld.Army = world.free_companies[0]
	assert(fc.size() >= 100, "the company must muster the stripped regiments")
	var gold_before_pillage: float = world.realms[0].gold + world.realms[1].gold
	world._free_company_tick()
	assert(world.realms[0].gold + world.realms[1].gold < gold_before_pillage,
		"a free company must pillage someone every month")
	# an army marches out to destroy them
	var hunters := world.muster_army(0)
	for i in 12:
		hunters.regiments.append({"kind": "sword", "soldiers": 36, "max": 36})
	var tries := 0
	while not world.free_companies.is_empty() and tries < 5:
		hunters.pos = world.free_companies[0].pos
		world._fight_free_company(hunters, world.free_companies[0])
		tries += 1
	assert(world.free_companies.is_empty(), "an army must be able to destroy a free company")
	print("broken blade ok — company formed, pillaged, and was ridden down (%d battles)" % tries)

	# --- 10. prestige decays toward the world's short memory ---
	world.realms[0].prestige = 10.0
	world.reparations = {}
	world._diplomacy_tick()
	assert(absf(world.realms[0].prestige - (10.0 - SimWorld.PRESTIGE_DECAY)) < 0.001,
		"prestige must decay by %0.1f a month" % SimWorld.PRESTIGE_DECAY)

	# --- 11. the Lawspeaker's forgers ---
	world.realms[0].gold = 200.0
	var fab_err := world.fabricate_claim(0)
	assert(fab_err == "", "fabricate failed: " + fab_err)
	var months := 0
	while not world.fabrication.is_empty() and months < 15:
		world._fabricate_tick()
		months += 1
	assert(bool(world.fabricated_claims.get(0, false)), "the forgery must finish inside a year")
	assert(world.available_cbs(0).has("fabricated"), "a sealed forgery must offer a CB")
	print("fabrication ok — a claim forged in %d months" % months)

	# --- 12. the world keeps turning with all of it wired in ---
	world.truce_until = -999
	for i in 120:
		world.advance_month()
	var alive := 0
	for c in world.characters.values():
		var cc3: SimCharacter = c
		if cc3.alive:
			alive += 1
	assert(alive > 0, "the world must survive ten years of the new diplomacy")
	print("10-year soak ok — %d alive, %d events, %d resolved by AI" % [
		alive, events.size(), world.events_resolved_by_ai])

	print("\nALL DIPLOMACY CHECKS PASSED")
	quit(0)
