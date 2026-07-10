extends SceneTree

## Headless validation of Module 4 (Vassal-Liege Internal Management):
##   <godot.exe> --headless --path . --script res://tests/vassal_module_test.gd
## Covers feudal contracts and privileges, hereditary titles, vassal
## opinion and tyranny, the Estate Curia, the covert faction lifecycle,
## civil war resolution, council snubs, and the Liege's Court.


func _adult(world: SimWorld, realm_id: int, skip: Array = []):
	for cid in world.characters:
		var c = world.characters[cid]
		if c.alive and c.realm_id == realm_id and c.age_years(world.tick) >= 18 \
				and c.id != world.realms[realm_id].ruler_id and not skip.has(c.id) \
				and world.counties_of(c.id).is_empty():
			return c
	assert(false, "realm %d must offer an adult" % realm_id)
	return null


func _own_county(world: SimWorld, skip: Array = []) -> int:
	for p in world.map.provinces:
		if p.owner == 0 and not world.county_holders.has(p.id) and not skip.has(p.id):
			return p.id
	assert(false, "realm 0 must have an ungranted county")
	return -1


func _init() -> void:
	var world := SimWorld.new()
	world.auto_resolve_events = true
	world.setup()
	var realm = world.realms[0]
	var ruler = world.characters[realm.ruler_id]

	# --- contracts: granting opens one; rates move yields and tyranny ---
	var lord_a = _adult(world, 0)
	var county_a := _own_county(world)
	var err: String = world.grant_title("county", county_a, lord_a.id)
	assert(err == "", "grant must succeed: %s" % err)
	assert(world.vassal_contracts.has(lord_a.id), "a grant opens the feudal contract")
	assert(str(world.contract_of(lord_a.id)["tax"]) == "normal", "default terms are fair")
	var tax_normal: float = world.realm_tax_eff(0)
	var _e1: String = world.set_contract_rate(lord_a.id, "tax", "harsh")
	assert(world.realm_tax_eff(0) > tax_normal, "harsh terms squeeze more gold")
	assert(realm.tyranny >= 5.0, "and every lord notices")
	var _e2: String = world.set_contract_rate(lord_a.id, "tax", "lenient")
	assert(world.realm_tax_eff(0) < tax_normal, "lenient terms cost the ledger")
	var _e3: String = world.set_contract_rate(lord_a.id, "tax", "normal")
	print("feudal contracts: rates move the ledger, harshness breeds tyranny")

	# --- vassal opinion: contract, culture, tyranny all stack ---
	var base_op: int = world.vassal_opinion(lord_a.id, 0)
	var _e4: String = world.set_contract_rate(lord_a.id, "tax", "harsh")
	assert(world.vassal_opinion(lord_a.id, 0) < base_op, "harsh terms are resented")
	var _e5: String = world.set_contract_rate(lord_a.id, "tax", "normal")
	realm.tyranny = 40.0
	assert(world.vassal_opinion(lord_a.id, 0) < base_op, "tyranny stains every lord's regard")
	realm.tyranny = 0.0
	print("granular vassal opinion stacks contract, culture and tyranny")

	# --- privileges: each wired where it bites ---
	var levy_before: float = world.realm_levy_eff(0)
	var _p1: String = world.grant_privilege(lord_a.id, "marcher_lord")
	assert(world.realm_levy_eff(0) < levy_before, "a marcher owes no levies")
	var tax_before: float = world.realm_tax_eff(0)
	var _p2: String = world.grant_privilege(lord_a.id, "coinage_rights")
	assert(world.realm_tax_eff(0) < tax_before, "their coin, their cut")
	var _p3: String = world.grant_privilege(lord_a.id, "judicial_immunity")
	assert(world.grant_title("county", county_a, -1) != "", "judicial immunity blocks revocation")
	assert(world.county_holders.has(county_a), "the county stays held")
	print("privileges bite: marcher levies, coinage taxes, immunity from revocation")

	# guaranteed seat: honored by the AI fill, protected from removal
	var lord_b = _adult(world, 0, [lord_a.id])
	var county_b := _own_county(world)
	var _g2: String = world.grant_title("county", county_b, lord_b.id)
	var _p4: String = world.grant_privilege(lord_b.id, "guaranteed_seat")
	var vacated := ""
	for seat in SimWorld.COUNCIL_SEATS:
		if int(realm.council.get(seat, -1)) != lord_b.id:
			vacated = seat
			break
	realm.council.erase(vacated)
	world._ai_fill_council(0)
	var seated := false
	for seat in SimWorld.COUNCIL_SEATS:
		if int(realm.council.get(seat, -1)) == lord_b.id:
			seated = true
			vacated = seat
	assert(seated, "the contract seats them before merit")
	assert(world.appoint(0, vacated, -1) != "", "a guaranteed seat cannot be vacated")
	assert(world.appoint(0, vacated, lord_a.id) != "", "nor given to another")
	print("the Guaranteed Council Seat privilege is honored and protected")

	# --- the Estate Curia ---
	# two lords is below quorum: the crown rules alone
	assert(bool(world.curia_vote(0, "war")["passed"]), "too few lords — the crown rules alone")
	var lord_c = _adult(world, 0, [lord_a.id, lord_b.id])
	var county_c := _own_county(world)
	var _g3: String = world.grant_title("county", county_c, lord_c.id)
	# force ideology: all three lords are Constitutionalists who hate war.
	# (Administrative v1.0 note: realm 0's crown is now Grand Magister
	# Anselm, whom the lords bear no feud — so cool their regard below
	# the loyalty-bends-ideology threshold to test the bloc's own vote.)
	for lord in [lord_a, lord_b, lord_c]:
		lord.traits.clear()
		lord.traits.append("Honest")
		lord.traits.append("Patient")
		world.add_memory(lord, "no friend of the new chair", realm.ruler_id, -30.0, 0.1)
	assert(world.bloc_of(lord_a) == "Constitutionalists", "Honest and Patient caucus for the law")
	var vote: Dictionary = world.curia_vote(0, "war")
	assert(not bool(vote["passed"]), "the Constitutionalists vote the war down: %s" % vote["detail"])
	assert(world.declare_war(0) != "" and not world.at_war, "the Curia gate holds the war back")
	# loyalty bends ideology: court the lords until the vote carries
	for lord in [lord_a, lord_b, lord_c]:
		world.add_memory(lord, "the crown's steadfast friend", realm.ruler_id, 80.0, 0.1)
	assert(bool(world.curia_vote(0, "war")["passed"]), "sworn friends abstain from opposing")
	# tribal realms know no Curia
	assert(world.realms[1].government == "tribal", "the clan is tribal")
	print("the Estate Curia: blocs, quorum, the war gate, and loyalty bending ideology")

	# --- the faction engine ---
	# manual cabal: lord_c conspires for liberty
	world.add_memory(lord_c, "the crown's steadfast friend", realm.ruler_id, -160.0, 0.1)  # cancel + hatred
	assert(world.vassal_opinion(lord_c.id, 0) <= -20, "lord_c is now bitter")
	world.factions.append({"realm": 0, "type": "liberty", "members": [lord_c.id], "provinces": [],
		"covert": true, "discovered": false, "claimant": -1})
	assert(world.faction_strength(world.factions[0]) > 0.0, "a landed lord musters real men")
	assert(world.visible_factions(0).is_empty(), "covert factions are invisible to the crown")
	assert(world.bribe_faction_member(lord_c.id) != "", "no acting on hidden knowledge")
	# discovery needs a Spymaster digging
	assert(world.council_member(0, "Spymaster") != null, "the realm keeps a Spymaster")
	var guard := 0
	while world.visible_factions(0).is_empty() and guard < 400:
		world._faction_discovery(realm)
		guard += 1
	assert(not world.visible_factions(0).is_empty(), "the Spymaster uncovers the cabal")
	# a discovered conspirator can be bought
	realm.gold = 200.0
	var _b1: String = world.bribe_faction_member(lord_c.id)
	assert(_b1 == "", "the bribe goes through")
	assert(world.factions.is_empty() or world.factions[0]["members"].is_empty(),
		"the cabal loses its only member")
	world._faction_maintenance(realm)
	assert(world.factions.is_empty(), "an empty conspiracy dissolves")
	print("the covert lifecycle: hidden, discovered, bought, dissolved")

	# concessions per faction type
	world._concede_faction(realm, {"realm": 0, "type": "liberty", "members": [], "provinces": [], "claimant": -1})
	assert(realm.tax_law == "light", "a liberty concession lightens taxation")
	var _cl = _adult(world, 0, [lord_a.id, lord_b.id, lord_c.id])
	var old_ruler_id: int = realm.ruler_id
	world._concede_faction(realm, {"realm": 0, "type": "claimant", "members": [], "provinces": [], "claimant": _cl.id})
	assert(realm.ruler_id == _cl.id, "a claimant concession swaps the crown")
	realm.ruler_id = old_ruler_id  # put the rightful ruler back for the rest of the test
	var conq = world.map.provinces[9]   # Karn-Vol-Gar, de jure realm 1
	conq.owner = 0
	conq.held_since = world.tick
	world._concede_faction(realm, {"realm": 0, "type": "populist", "members": [], "provinces": [conq.id], "claimant": -1})
	assert(conq.owner == 1, "a populist concession returns the conquered county")
	print("concessions: liberty lightens, claimant crowns, populist returns the land")

	# civil war: the crown meets a rising in the field, resolved by the sim
	world.add_memory(lord_a, "an insult past bearing", realm.ruler_id, -160.0, 0.1)
	var war_faction := {"realm": 0, "type": "liberty", "members": [lord_a.id], "provinces": [],
		"covert": false, "discovered": true, "claimant": -1}
	world.factions.append(war_faction)
	var men_before: int = world.army_size(0)
	world._civil_war(realm, war_faction)
	assert(not world.factions.has(war_faction), "the civil war resolves the faction, win or lose")
	assert(world.army_size(0) <= men_before, "the crown's host carries its dead home")
	print("civil war: fought in the real battle sim, faction resolved either way")

	# --- populist unrest forms without dice ---
	var world_p := SimWorld.new()
	world_p.auto_resolve_events = true
	world_p.setup()
	var taken := 0
	for p in world_p.map.provinces:
		if p.de_jure == 1 and taken < 2:
			p.owner = 0
			p.held_since = -48  # held long enough to seethe
			taken += 1
	world_p._populist_unrest(world_p.realms[0])
	var found_pop := false
	for f in world_p.factions:
		if str(f["type"]) == "populist" and int(f["realm"]) == 0:
			found_pop = true
			assert(f["provinces"].size() == 2, "both oppressed counties rise together")
	assert(found_pop, "conquered counties breed a populist faction")
	print("populist unrest: the conquered land remembers its own")

	# --- hereditary titles ---
	var world_h := SimWorld.new()
	world_h.auto_resolve_events = true
	world_h.setup()
	var father = null
	for cid in world_h.characters:
		var c = world_h.characters[cid]
		if not c.alive or c.realm_id != 0 or c.is_female or c.id == world_h.realms[0].ruler_id:
			continue
		for kid_id in c.children_ids:
			var kid = world_h.characters[kid_id]
			if kid.alive and not kid.is_bastard and kid.age_years(world_h.tick) >= 18 and kid.realm_id == 0:
				father = c
				break
		if father != null:
			break
	assert(father != null, "some lord has a grown heir")
	var county_h := -1
	for p in world_h.map.provinces:
		if p.owner == 0 and not world_h.county_holders.has(p.id):
			county_h = p.id
			break
	var _gh: String = world_h.grant_title("county", county_h, father.id)
	var _ch: String = world_h.set_contract_rate(father.id, "tax", "harsh")
	world_h._kill(father, "has died")
	var heir_id := int(world_h.county_holders.get(county_h, -1))
	assert(heir_id >= 0, "the county did not escheat")
	assert(father.children_ids.has(heir_id), "the eldest trueborn child inherits")
	assert(str(world_h.contract_of(heir_id)["tax"]) == "harsh", "the contract binds the line")
	print("hereditary lordships: land and contract pass to the heir")

	# --- council snubs ---
	var world_s := SimWorld.new()
	world_s.auto_resolve_events = true
	world_s.setup()
	var realm_s = world_s.realms[0]
	var great = null
	for cid in world_s.characters:
		var c = world_s.characters[cid]
		var on_council := false
		for seat in SimWorld.COUNCIL_SEATS:
			if int(realm_s.council.get(seat, -1)) == c.id:
				on_council = true
		if c.alive and c.realm_id == 0 and c.age_years(world_s.tick) >= 18 \
				and c.id != realm_s.ruler_id and not on_council:
			great = c
			break
	var granted := 0
	for p in world_s.map.provinces:
		if p.owner == 0 and not world_s.county_holders.has(p.id) and granted < 2:
			var _gs: String = world_s.grant_title("county", p.id, great.id)
			granted += 1
	great.martial = 30  # unquestionably better than whoever holds the Marshal's chair
	world_s._council_snub_tick(realm_s)
	assert(world_s.council_snubbed.has(great.id), "the snub is voiced")
	var snub_found := false
	for m in great.memories:
		if str(m["type"]) == "snubbed for the council":
			snub_found = true
	assert(snub_found, "and remembered")
	print("council snubs: the passed-over great lord marks the lesser man")

	# --- the Liege's Court ---
	var resolved_before: int = world_s.events_resolved_by_ai
	var lord_x = great
	var lord_y = null
	for cid in world_s.characters:
		var c = world_s.characters[cid]
		if c.alive and c.realm_id == 0 and c.age_years(world_s.tick) >= 18 \
				and c.id != realm_s.ruler_id and c.id != lord_x.id:
			lord_y = c
			break
	for p in world_s.map.provinces:
		if p.owner == 0 and not world_s.county_holders.has(p.id):
			var _gy: String = world_s.grant_title("county", p.id, lord_y.id)
			break
	world_s.add_memory(lord_x, "a border torched", lord_y.id, -60.0, 0.1)
	world_s._raise_arbitration(realm_s, lord_x, lord_y)
	assert(world_s.events_resolved_by_ai == resolved_before + 1, "the court sits and the AI liege rules")
	print("the Liege's Court hears the feud and issues a verdict")

	print("\nALL VASSAL MODULE CHECKS PASSED")
	quit(0)
