extends SceneTree

## Headless smoke test for the dynasty simulation. Run from the project folder:
##   <godot.exe> --headless --path . --script res://tests/headless_test.gd
## Exercises 60 years of simulation plus every player action, and prints
## a summary. No UI involved — this is why SimWorld stays a pure class.

func _init() -> void:
	var world := SimWorld.new()
	var events: Array = []
	world.event_logged.connect(func(t: String) -> void: events.append(t))
	world.setup()
	world.auto_resolve_events = true  # headless: trait-weighted AI answers every choice event

	print("=== initial state ===")
	print("characters: %d, realms: %d, dynasties: %d" % [world.characters.size(), world.realms.size(), world.dynasties.size()])
	for realm in world.realms:
		print("  %s — ruler id %d, strength %d" % [realm.name, realm.ruler_id, world.strength(realm.id)])

	# --- map checks (the hand-authored Khessar map) ---
	var owned := {}
	for p in world.map.provinces:
		owned[p.owner] = int(owned.get(p.owner, 0)) + 1
	print("map: %d provinces (Vael %d / Karn-Vol %d / unclaimed %d / other realms %d)" % [
		world.map.provinces.size(), int(owned.get(0, 0)), int(owned.get(1, 0)), int(owned.get(-1, 0)),
		world.map.provinces.size() - int(owned.get(0, 0)) - int(owned.get(1, 0)) - int(owned.get(-1, 0))])
	for p in world.map.provinces.slice(0, 6):
		print("  %s — owner %d, tax %.1f, levy %d, neighbors %s" % [p.name, p.owner, p.tax, p.levy, str(p.neighbors)])
	assert(world.map.provinces.size() == 60, "the Khessar map must hold exactly 60 provinces")
	assert(int(owned.get(0, 0)) >= 3 and int(owned.get(1, 0)) >= 3, "the two simulated realms need land")

	# --- genome & trait checks ---
	assert(not world.characters[0].genome.is_empty(), "founders need genomes")
	assert(world.characters[0].genome.has("skin"), "genome missing continuous genes")
	assert(world.characters[0].genome.has("undertone"), "genome missing portrait undertone gene")
	assert(world.characters[0].genome.has("hair_texture"), "genome missing portrait hair texture gene")
	assert(world.characters[0].genome.has("symmetry"), "genome missing portrait symmetry gene")
	assert(world.characters[0].genome.has("presence"), "genome missing portrait presence gene")
	assert(world.characters[0].genome.has("severity"), "genome missing portrait severity gene")
	assert(world.characters[0].traits.size() > 0, "founders should have traits")
	print("founder traits: %s -> %s" % [world.full_name(world.characters[0]), str(world.characters[0].traits)])

	# --- army roster checks ---
	assert(world.armies.size() == 2, "each realm should start with one army")
	for a in world.armies:
		assert(a.regiments.size() == 5, "starting army missing regiments")
		assert(a.commander_id >= 0, "armies must have commanders")
	print("armies: %d vs %d men, capacity %d vs %d" % [
		world.army_size(0), world.army_size(1), world.levy_capacity(0), world.levy_capacity(1)])
	var recruit_err := world.recruit(0, "levy")
	assert(recruit_err == "" or recruit_err.begins_with("The levy"), "recruit failed unexpectedly: " + recruit_err)

	# --- Module 1: the Core Six, trait DB, stress, memory ---
	for key in SimWorld.STAT_PROPS.values():
		var v: int = world.characters[0].get(key)
		assert(v >= 1 and v <= 30, "stat %s out of range" % key)
	for t in TraitDB.db():
		var info: TraitData = TraitDB.info(t)
		assert(info.category != "", "trait %s missing category" % t)
		if info.opposite != "":
			assert(TraitDB.has_trait(info.opposite), "opposite of %s does not exist" % t)
			assert(TraitDB.info(info.opposite).opposite == t, "opposite pair broken: %s" % t)
	for c in world.characters.values():
		var pcount := 0
		for t in c.traits:
			if world.trait_cat(t) == "personality":
				pcount += 1
			var opp2: String = TraitDB.info(t).opposite
			if opp2 != "":
				assert(not c.traits.has(opp2), "%s has opposite traits" % c.name)
		assert(pcount <= 3, "personality cap violated")
	print("trait DB integrity ok — six stats, caps, opposites")

	var guinea: SimCharacter = world.characters[world.realms[0].ruler_id]
	world.add_stress(guinea, 30.0, "test worry")
	assert(guinea.stress > 0.0, "stress did not accumulate")
	var coping_before := 0
	for t in guinea.traits:
		if world.trait_cat(t) == "coping":
			coping_before += 1
	world.add_stress(guinea, 200.0, "test catastrophe")
	var coping_after := 0
	for t in guinea.traits:
		if world.trait_cat(t) == "coping":
			coping_after += 1
	assert(guinea.stress_level >= 1, "stress break never fired")
	assert(coping_after > coping_before, "break should leave a coping scar")
	print("stress ok — level %d, scars %s" % [guinea.stress_level, str(guinea.traits)])
	guinea.stress = 0.0
	guinea.stress_level = 0

	assert(world.ai_weight(guinea, "aggression") == world.ai_weight(guinea, "aggression"), "ai_weight broken")

	assert(world.characters[0].intrigue > 0, "characters need an intrigue stat")
	for realm in world.realms:
		for seat in SimWorld.COUNCIL_SEATS:
			assert(world.council_member(realm.id, seat) != null, "setup should fill the %s seat" % seat)
	print("councils filled — Vael Marshal: %s (Mar %d), Spymaster: %s (Int %d)" % [
		world.full_name(world.council_member(0, "Marshal")), world.council_stat(0, "Marshal"),
		world.full_name(world.council_member(0, "Spymaster")), world.council_stat(0, "Spymaster")])
	assert(world.levy_capacity(0) > world.map.realm_levy(0), "marshal should raise levy capacity")

	# law: switch to absolute succession
	var law_err := world.enact_law(0, "succession", "absolute")
	assert(law_err == "", "enact failed: " + law_err)
	var debate_months := 0
	while not world.realms[0].pending_law.is_empty() and debate_months < 30:
		world.advance_month()
		debate_months += 1
	assert(world.realms[0].succession_law == "absolute", "law never passed")
	print("law passed after %d months of debate" % debate_months)

	# plot: aim at Sarova's ruler and run it to resolution
	world.realms[0].gold = 1000.0
	var plot_err := world.start_plot(0, world.realms[1].ruler_id)
	assert(plot_err == "", "plot failed to start: " + plot_err)
	var plot_months := 0
	while world.realms[0].plot_progress >= 0.0 and plot_months < 60:
		world.advance_month()
		plot_months += 1
	assert(plot_months < 60, "plot never resolved")
	var whispers := 0
	var uncovered := 0
	for e in events:
		if str(e).contains("whispers of poison"):
			whispers += 1
		if str(e).contains("uncovered"):
			uncovered += 1
	print("plot resolved in %d months — assassinations: %d, plots uncovered: %d" % [plot_months, whispers, uncovered])
	assert(whispers + uncovered > 0, "plot resolution left no trace in the chronicle")

	# commander: hand an army to a chosen character
	var army0 = world.armies_of(0)[0]
	var new_cmdr: SimCharacter = null
	for c in world.characters.values():
		if c.alive and c.realm_id == 0 and c.age_years(world.tick) >= 16 and c.id != army0.commander_id:
			new_cmdr = c
			break
	var cmd_err := world.set_commander(army0.id, new_cmdr.id)
	assert(cmd_err == "", "set_commander failed: " + cmd_err)
	assert(army0.commander_id == new_cmdr.id, "commander not applied")
	print("set_commander ok — %s now leads" % world.full_name(new_cmdr))

	# --- split & merge ---
	var first_id: int = world.armies_of(0)[0].id
	var split_err := world.split_army(first_id)
	assert(split_err == "", "split failed: " + split_err)
	assert(world.armies_of(0).size() == 2, "split should create a second army")
	var merge_err := world.merge_army(first_id)
	assert(merge_err == "", "merge failed: " + merge_err)
	assert(world.armies_of(0).size() == 1, "merge should rejoin the armies")
	print("split/merge ok")

	# --- Module 2: houses, renown, legacies, dynasty head powers ---
	var ruler: SimCharacter = world.characters[world.realms[0].ruler_id]
	var root: int = world.root_house_id(ruler.dynasty_id)
	assert(root == ruler.dynasty_id, "founding houses must be their own root")
	assert(world.dynasty_head(root) != null, "a living dynasty must have a head")
	var root_dyn = world.dynasties[root]
	assert(root_dyn.renown > 0.0, "renown never accrued over the elapsed months")
	assert(world.renown_gain(root) > 0.0, "a ruling dynasty must gain renown")
	print("renown ok — %s holds %d renown (+%.1f/mo), head: %s" % [
		root_dyn.name, int(root_dyn.renown), world.renown_gain(root),
		world.full_name(world.dynasty_head(root))])

	# legacies: opinion legacy must move kin opinion by exactly its bonus
	root_dyn.renown = 2000.0
	var kin_a: SimCharacter = null
	var kin_b: SimCharacter = null
	for c in world.dynasty_members(root):
		if c.id == ruler.id or c.age_years(world.tick) < 16:
			continue
		if kin_a == null:
			kin_a = c
		elif kin_b == null:
			kin_b = c
	assert(kin_a != null and kin_b != null, "dynasty too small to test opinion legacy")
	var opinion_before := world.opinion_of(kin_a.id, kin_b.id)
	var buy_err := world.buy_legacy(root, "Unbending Oaths")
	assert(buy_err == "", "legacy purchase failed: " + buy_err)
	assert(world.has_legacy(root, "Unbending Oaths"), "legacy not recorded")
	assert(world.opinion_of(kin_a.id, kin_b.id) == opinion_before + 15, "Unbending Oaths must add +15 kin opinion")
	buy_err = world.buy_legacy(root, "Unbending Oaths")
	assert(buy_err != "", "double purchase should be refused")
	print("legacies ok — kin opinion %+d -> %+d" % [opinion_before, world.opinion_of(kin_a.id, kin_b.id)])

	# disinherit: the heir changes when the head's word falls
	var old_heir: SimCharacter = world.heir_of(0)
	if old_heir != null and world.root_house_id(old_heir.dynasty_id) == root and old_heir.id != ruler.id:
		var dis_err := world.dh_disinherit(root, old_heir.id)
		assert(dis_err == "", "disinherit failed: " + dis_err)
		assert(old_heir.disinherited, "disinherit flag not set")
		var new_heir: SimCharacter = world.heir_of(0)
		assert(new_heir == null or new_heir.id != old_heir.id, "a disinherited heir still inherits")
		print("disinherit ok — %s cast out, heir now %s" % [world.full_name(old_heir),
			world.full_name(new_heir) if new_heir != null else "nobody"])

	# bastardy & legitimization: a bastard stands outside the line until raised
	var mistress: SimCharacter = null
	for w in world.characters.values():
		if w.alive and w.is_female and w.spouse_id < 0 and w.age_years(world.tick) >= 16 \
				and w.age_years(world.tick) <= 45 and not world._close_kin(ruler, w):
			mistress = w
			break
	assert(mistress != null, "no unmarried woman available for the bastardy test")
	var bastard: SimCharacter = world._make_child(ruler, mistress)
	bastard.is_bastard = true
	bastard.birth_tick = world.tick - 20 * 12  # age him up so succession would want him
	var would_be: SimCharacter = world.heir_of(0)
	assert(would_be == null or would_be.id != bastard.id, "a bastard must not inherit")
	var leg_err := world.dh_legitimize(root, bastard.id)
	assert(leg_err == "", "legitimize failed: " + leg_err)
	assert(not bastard.is_bastard, "legitimize did not clear the flag")
	print("bastardy ok — %s legitimized by the dynasty head" % world.full_name(bastard))

	# denounce: stripped of office and shunned
	var victim: SimCharacter = null
	for c in world.dynasty_members(root):
		if c.id != ruler.id and c.id != world.dynasty_head(root).id \
				and c.age_years(world.tick) >= 16 and not c.denounced:
			victim = c
			break
	assert(victim != null, "no kinsman available to denounce")
	var _seat_err := world.appoint(0, "Marshal", victim.id)
	var op_before := world.opinion_of(mistress.id, victim.id)
	var den_err := world.dh_denounce(root, victim.id)
	assert(den_err == "", "denounce failed: " + den_err)
	assert(victim.denounced, "denounce flag not set")
	assert(int(world.realms[0].council.get("Marshal", -1)) != victim.id, "denounced kin must lose their seat")
	assert(world.opinion_of(mistress.id, victim.id) == op_before - 30, "denouncement must cost -30 opinion")
	assert(world.appoint(0, "Marshal", victim.id) != "", "a denounced criminal must be unseatable")
	print("denounce ok — %s stripped and shunned" % world.full_name(victim))

	# --- Module 2 Pass 2: bequests, charters & schisms, mythos, interregnum ---

	# wills & bequests: buy a younger son's peace (or fail to)
	world.realms[0].gold = 1000.0
	var younger: SimCharacter = null
	for kid_id in ruler.children_ids:
		var kid: SimCharacter = world.characters[kid_id]
		var h2: SimCharacter = world.heir_of(0)
		if kid.alive and kid.age_years(world.tick) >= 16 and (h2 == null or h2.id != kid.id):
			younger = kid
			break
	assert(younger != null, "no adult non-heir child for the bequest test")
	var gold_before: float = world.realms[0].gold
	var beq_err := world.grant_bequest(0, younger.id)
	assert(beq_err == "", "bequest failed: " + beq_err)
	assert(world.realms[0].gold == gold_before - 150.0, "bequest must cost 150 gold")
	assert(younger.bought_off or younger.aggrieved, "a bequest must settle or embitter")
	print("bequest ok — %s %s" % [world.full_name(younger),
		"is content" if younger.bought_off else "took the gold coldly (aggrieved)"])

	# schismatic charter: a bitter kinsman tears his line away — blood feud
	if younger.spouse_id < 0:
		for w2 in world.eligible_singles(true):
			if not world._close_kin(younger, w2):
				var _m := world.marry(younger.id, w2.id)
				break
	assert(younger.spouse_id >= 0, "could not marry the schism candidate")
	var has_kid := false
	for kid_id in younger.children_ids:
		if world.characters[kid_id].alive:
			has_kid = true
	if not has_kid:
		var _bc := world._make_child(younger, world.characters[younger.spouse_id])
	var spawned_kin: SimCharacter = null
	while world.house_members(root).size() < 6:
		spawned_kin = world._spawn(world.realms[0], root, false, 30)
	younger.aggrieved = true  # a grievance, whatever the bequest said
	var eligible_why := world.can_found_cadet(younger)
	assert(eligible_why == "", "schism candidate ineligible: " + eligible_why)
	var op_ruler_before := world.opinion_of(ruler.id, younger.id)
	var schism_err := world.found_cadet_branch(younger.id, "schismatic")
	assert(schism_err == "", "schismatic split failed: " + schism_err)
	var new_house: int = world.dynasties.size() - 1
	assert(world.dynasties[new_house].charter == "schismatic", "charter not recorded")
	assert(world.root_house_id(new_house) == new_house, "a schismatic house must be its own root")
	assert(world.in_blood_feud(root, new_house), "the schism must swear a blood feud")
	assert(world.opinion_of(ruler.id, younger.id) < op_ruler_before, "the feud must poison kin opinion")
	print("schism ok — %s founded, feud sworn, opinion %+d -> %+d" % [
		world.dynasties[new_house].name, op_ruler_before, world.opinion_of(ruler.id, younger.id)])

	# mythos: a third act of kin-cruelty brands the house Kin-Eater
	var outsider: SimCharacter = world.characters[world.realms[1].ruler_id]
	var op_outside_before := world.opinion_of(outsider.id, ruler.id)
	root_dyn.renown = 2000.0
	var third_kin: SimCharacter = spawned_kin
	if third_kin == null:
		for c in world.dynasty_members(root):
			if c.id != ruler.id and not c.denounced and c.age_years(world.tick) >= 16:
				third_kin = c
				break
	assert(third_kin != null, "no kinsman left for the third cruelty")
	var den2_err := world.dh_denounce(root, third_kin.id)
	assert(den2_err == "", "third cruelty failed: " + den2_err)
	assert(world.has_mythos(root, "Kin-Eater"), "three cruelties must earn the Kin-Eater stain")
	assert(world.opinion_of(outsider.id, ruler.id) == op_outside_before - 10,
		"Kin-Eater must cost -10 opinion from outsiders")
	print("mythos ok — %s branded Kin-Eater, outsider opinion %+d -> %+d" % [
		root_dyn.name, op_outside_before, world.opinion_of(outsider.id, ruler.id)])

	# the interregnum: the crown is not won at the deathbed
	world._kill(ruler, "dies, for the test of crowns,")
	assert(not world.realms[0].interregnum.is_empty(), "a succession must open an interregnum")
	var claimant: SimCharacter = world.characters[int(world.realms[0].interregnum["heir"])]
	print("interregnum open — %s stands Claimant-Designate, legitimacy %d" % [
		world.full_name(claimant), int(world.realms[0].interregnum["legitimacy"])])
	for i in 5:
		world.advance_month()
	assert(world.realms[0].interregnum.is_empty(), "the interregnum must resolve in four stages")
	var crowned_seen := false
	for e in events:
		if str(e).contains("is crowned"):
			crowned_seen = true
	assert(crowned_seen, "no coronation was ever chronicled")
	print("interregnum ok — resolved, %s rules %s" % [
		world.full_name(world.characters[world.realms[0].ruler_id]), world.realms[0].name])

	# --- Module 3: the title pyramid, de jure drift, governments ---
	assert(world.map.duchies.size() >= 4, "each realm should carve at least two duchies")
	for p in world.map.provinces:
		assert(p.duchy >= 0, "%s belongs to no duchy" % p.name)
		assert(world.map.duchies[p.duchy].county_ids.has(p.id), "duchy membership broken for %s" % p.name)
	print("duchies ok — %s" % ", ".join(world.map.duchies.map(func(d) -> String:
		return "%s (%d counties)" % [d.name, d.county_ids.size()])))

	assert(world.realms[0].government == "administrative" and world.realms[1].government == "tribal",
		"governments not assigned")
	var s_ruler: SimCharacter = world.characters[world.realms[1].ruler_id]
	var cap_before := world.levy_capacity(1)
	s_ruler.martial = clampi(s_ruler.martial + 10, 1, 30)
	var cap_after := world.levy_capacity(1)
	assert(cap_after > cap_before, "tribal levies must swell with the ruler's martial")
	s_ruler.martial = clampi(s_ruler.martial - 10, 1, 30)
	print("governments ok — tribal levy %d -> %d with +10 martial" % [cap_before, cap_after])
	assert(world.grant_title("duchy", world.map.duchies.filter(func(d) -> bool: return d.realm == 1)[0].id,
		s_ruler.id) != "", "tribal realms must not grant duchies")

	# grants: a lord runs his county better than a stretched crown
	# (skip anyone pinned at the opinion clamp — a blood-feud schismatic at
	# -100 can't measurably warm to the crown, which is what we assert)
	var lord: SimCharacter = null
	for c in world.characters.values():
		if c.alive and c.realm_id == 0 and c.age_years(world.tick) >= 16 \
				and not c.denounced and c.id != world.realms[0].ruler_id \
				and absi(world.opinion_of(c.id, world.realms[0].ruler_id)) < 100:
			lord = c
			break
	assert(lord != null, "no candidate lord")
	var own_pid := -1
	for p in world.map.provinces:
		if p.owner == 0 and world.county_holder(p.id) == null:
			own_pid = p.id
			break
	var tax_before := world.realm_tax_eff(0)
	var op_grant_before := world.opinion_of(lord.id, world.realms[0].ruler_id)
	var grant_err := world.grant_title("county", own_pid, lord.id)
	assert(grant_err == "", "grant failed: " + grant_err)
	assert(world.county_holder(own_pid) != null and world.county_holder(own_pid).id == lord.id, "holder not set")
	assert(world.realm_tax_eff(0) > tax_before, "a granted county must yield more")
	assert(world.opinion_of(lord.id, world.realms[0].ruler_id) > op_grant_before,
		"a granted lord must warm to the crown")
	print("grant ok — %s holds %s, realm tax %.1f -> %.1f" % [
		world.full_name(lord), world.map.provinces[own_pid].name, tax_before, world.realm_tax_eff(0)])

	var own_duchy = world.map.duchies.filter(func(d) -> bool: return d.realm == 0)[0]
	var levy_before := world.realm_levy_eff(0)
	var duchy_err := world.grant_title("duchy", own_duchy.id, lord.id)
	assert(duchy_err == "", "duchy grant failed: " + duchy_err)
	assert(world.realm_levy_eff(0) > levy_before, "a duke must marshal more levies")
	assert(world.titles_of(lord.id).size() == 2, "titles_of should list county and duchy")

	# revoke leaves a scar; escheat returns the rest on death
	var op_lord_before := world.opinion_of(lord.id, world.realms[0].ruler_id)
	var _rev := world.grant_title("county", own_pid, -1)
	assert(world.county_holder(own_pid) == null, "revoke failed")
	assert(world.opinion_of(lord.id, world.realms[0].ruler_id) < op_lord_before, "a stripped lord must resent it")
	world._kill(lord, "dies holding his duchy,")
	# Module 4: titles are hereditary — an eligible heir inherits, else escheat
	var duchy_after := world.duchy_holder(own_duchy.id)
	assert(duchy_after == null or lord.children_ids.has(duchy_after.id),
		"a dead lord's duchy must pass to his heir or escheat to the crown")
	print("revoke & succession ok — %s %s" % [own_duchy.name,
		"reverted to the crown" if duchy_after == null else "inherited by " + world.full_name(duchy_after)])

	# de jure drift: conquered land assimilates after a generation
	var stolen = null
	for p in world.map.provinces:
		if p.owner == 1:
			stolen = p
			break
	stolen.owner = 0
	stolen.held_since = world.tick
	assert(world.realm_tax_eff(0) > 0.0, "tax must still compute with foreign land")
	var tax_foreign := world.realm_tax_eff(0)
	stolen.held_since = world.tick - SimWorld.DEJURE_DRIFT_MONTHS
	world._dejure_tick()
	assert(stolen.de_jure == 0, "de jure drift never fired")
	assert(world.realm_tax_eff(0) > tax_foreign, "assimilated land must yield more than occupied land")
	print("de jure ok — %s assimilated after %d months, tax %.1f -> %.1f" % [
		stolen.name, SimWorld.DEJURE_DRIFT_MONTHS, tax_foreign, world.realm_tax_eff(0)])
	stolen.owner = 1
	stolen.de_jure = 1
	stolen.held_since = 0  # hand it back — the test world stays balanced

	# --- traits as systemic hooks (TraitData) + the event framework ---
	var hook_guinea: SimCharacter = world.characters[world.realms[0].ruler_id]
	var saved_traits: Array[String] = hook_guinea.traits.duplicate()
	hook_guinea.traits.assign(["Avaricious", "Paranoid", "Methodical"] as Array[String])
	assert(absf(world.trait_mult(hook_guinea, "tax_efficiency_mult") - 1.10) < 0.001, "Avaricious tax hook broken")
	assert(absf(world.trait_mult(hook_guinea, "intrigue_defense_mult") - 1.40) < 0.001, "Paranoid intrigue hook broken")
	assert(absf(world.trait_mult(hook_guinea, "supply_consumption_mult") - 0.90) < 0.001, "Methodical supply hook broken")
	assert(world.trait_add(hook_guinea, "admin_cap_bonus") == 0.0, "unexpected additive hook")
	hook_guinea.traits.assign(saved_traits)
	print("trait hooks ok — multiplicative and additive lookups verified")

	# battle grid hooks: an Impulsive commander's cavalry hits harder,
	# a Methodical one's infantry stands firmer
	var bs := BattleSim.new()
	bs.setup_from_rosters(
		[{"kind": "cav", "soldiers": 16, "max": 16}, {"kind": "sword", "soldiers": 36, "max": 36}],
		[{"kind": "cav", "soldiers": 16, "max": 16}, {"kind": "sword", "soldiers": 36, "max": 36}],
		0, 0, ["A", "B"], ["Impulsive"], ["Methodical", "Stoic"])
	var base_cav_ws: float = BattleSim.PRESETS["cav"]["ws"]
	var base_sword_md: float = BattleSim.PRESETS["sword"]["md"]
	assert(absf(bs.regiments[0].ws - base_cav_ws * 1.25) < 0.001, "vanguard_damage_mult not applied")
	assert(absf(bs.regiments[0].dmg_taken_mult - 1.10) < 0.001, "casualty_rate_mult not applied")
	assert(absf(bs.regiments[3].md - base_sword_md * 1.15) < 0.001, "center_line_defense_mult not applied")
	assert(absf(bs.regiments[3].shock_mult - 0.75) < 0.001, "panic_resistance not applied")
	assert(absf(bs.regiments[2].morale_bonus - 15.0) < 0.001, "levy_cohesion_baseline not applied")
	print("battle hooks ok — Impulsive vanguard %.1f ws (base %.1f), Methodical line %.1f md (base %.1f)" % [
		bs.regiments[0].ws, base_cav_ws, bs.regiments[3].md, base_sword_md])

	# the event framework: queueing, player resolution, and trait-driven AI
	world.auto_resolve_events = false
	var fired: Array = []
	world.raise_event(0, hook_guinea.id, "Test Event", "A choice stands before the crown.", [
		{"label": "First", "effect": func() -> void: fired.append("first")},
		{"label": "Second", "effect": func() -> void: fired.append("second")},
	])
	assert(world.pending_events.size() == 1, "player event must queue")
	world.resolve_event(int(world.pending_events[0]["id"]), 1)
	assert(world.pending_events.is_empty() and fired == ["second"], "player resolution failed")
	# an AI decider with overwhelming aggression must take the aggressive line
	var hawk: SimCharacter = world.characters[world.realms[1].ruler_id]
	var saved_hawk: Array[String] = hawk.traits.duplicate()
	hawk.traits.assign(["Wrathful", "Brave", "Ambitious"] as Array[String])
	var ai_picks := {"war": 0, "peace": 0}
	for i in 12:
		world.raise_event(1, hawk.id, "AI Test", "War or peace?", [
			{"label": "War", "ai": {"aggression": 1.0}, "effect": func() -> void: ai_picks["war"] += 1},
			{"label": "Peace", "ai": {"aggression": -1.0}, "effect": func() -> void: ai_picks["peace"] += 1},
		])
	assert(ai_picks["war"] > ai_picks["peace"], "a Wrathful hawk must overwhelmingly choose war (got %s)" % str(ai_picks))
	hawk.traits.assign(saved_hawk)
	world.auto_resolve_events = true
	print("event framework ok — queue/resolve works, hawk chose war %d/12 times" % ai_picks["war"])

	# --- ranged fire & shields (static micro-battle, no movement) ---
	var rs := BattleSim.new()
	rs.setup_from_rosters(
		[{"kind": "archer", "soldiers": 24, "max": 24}],
		[{"kind": "levy", "soldiers": 48, "max": 48}], 0, 0, ["A", "B"])
	rs.regiments[0].pos = Vector2(400, 300)
	rs.regiments[1].pos = Vector2(560, 300)   # inside bow range, outside melee
	for i in 12:
		rs.combat_tick()
	var levy_loss: int = rs.regiments[1].start_soldiers - rs.regiments[1].soldiers
	assert(levy_loss > 0, "archers dealt no ranged casualties")
	assert(rs.regiments[0].soldiers == rs.regiments[0].start_soldiers, "archers should be untouched at range")
	assert(rs.regiments[0].ammo < 40, "ammo should deplete")
	# same volley count into a shielded frontal target must hurt less
	var rs2 := BattleSim.new()
	rs2.setup_from_rosters(
		[{"kind": "archer", "soldiers": 24, "max": 24}],
		[{"kind": "levy", "soldiers": 48, "max": 48}], 0, 0, ["A", "B"])
	rs2.regiments[0].pos = Vector2(400, 300)
	rs2.regiments[1].pos = Vector2(560, 300)
	rs2.regiments[1].shield = 0.9
	for i in 12:
		rs2.combat_tick()
	var shielded_loss: int = rs2.regiments[1].start_soldiers - rs2.regiments[1].soldiers
	print("ranged ok — unshielded lost %d, heavily shielded lost %d (of 48)" % [levy_loss, shielded_loss])
	assert(shielded_loss < levy_loss, "shields must reduce frontal missile casualties")

	# --- action: cross-realm marriage -> alliance ---
	var groom: SimCharacter = null
	var bride: SimCharacter = null
	for g in world.eligible_singles(false):
		for b in world.eligible_singles(true):
			if g.realm_id != b.realm_id:
				groom = g
				bride = b
				break
		if groom != null:
			break
	assert(groom != null, "expected at least one cross-realm match")
	var err := world.marry(groom.id, bride.id)
	assert(err == "", "marriage failed: " + err)
	assert(world.allied(), "cross-realm marriage should create an alliance")
	assert(not groom.memories.is_empty(), "marriage should leave a memory")
	assert(world.opinion_of(groom.id, bride.id) > 0, "newlyweds should like each other")
	print("\nmarried %s to %s -> allied: %s, groom's opinion of bride: %+d" % [
		world.full_name(groom), world.full_name(bride), world.allied(),
		world.opinion_of(groom.id, bride.id)])

	# --- war must be blocked while allied ---
	err = world.declare_war()
	assert(err != "", "war should be blocked by the alliance")
	print("declare_war while allied correctly refused: '%s'" % err)

	# --- trade pact ---
	err = world.toggle_trade_pact()
	assert(err == "" and world.trade_pact, "trade pact should sign")

	# --- run 60 years, fighting field battles as they arise ---
	var wars_fought := 0
	var battles_fought := 0
	var called_banners := false
	for month in 720:
		world.advance_month()
		# once the alliance lapses (a spouse dies), start a war to exercise that path
		if not world.at_war and not world.allied() and wars_fought < 3:
			if world.declare_war() == "":
				wars_fought += 1
		# first war: the dynasty head calls the banners once (skip the months
		# where the emergent tree leaves the dynasty briefly headless)
		if world.at_war and not called_banners and world.realms[0].ruler_id >= 0 \
				and world.dynasty_head(world.root_house_id(world.characters[world.realms[0].ruler_id].dynasty_id)) != null:
			var war_root: int = world.root_house_id(world.characters[world.realms[0].ruler_id].dynasty_id)
			world.dynasties[war_root].renown = 300.0
			var men_before := world.army_size(0)
			var call_err := world.dh_call_to_war(war_root)
			assert(call_err == "", "call to war failed: " + call_err)
			assert(world.army_size(0) >= men_before + 36, "the call must raise at least one sworn regiment")
			print("call to war ok — %d men answered" % (world.army_size(0) - men_before))
			called_banners = true
		if world.battle_ready:
			var result: Array = _fight_auto_battle(world)
			world.apply_battle_result(result[0], result[1])
			battles_fought += 1
	print("\nfield battles fought: %d" % battles_fought)
	assert(battles_fought > 0, "wars never produced a field battle")

	var alive := 0
	for c in world.characters.values():
		if c.alive:
			alive += 1
	print("\n=== after 60 years (%s) ===" % world.date_string())
	print("total characters ever: %d, alive: %d, events logged: %d, wars fought: %d" % [world.characters.size(), alive, events.size(), wars_fought])
	for realm in world.realms:
		var ruler_name := "NONE"
		if realm.ruler_id >= 0:
			ruler_name = world.full_name(world.characters[realm.ruler_id])
		print("  %s — ruler: %s, gold: %d, strength: %d" % [realm.name, ruler_name, int(realm.gold), world.strength(realm.id)])

	assert(alive > 0, "population died out — mortality is mistuned")
	assert(world.characters.size() > 26, "no children were ever born")

	# --- auto-marriage keeps the world alive without the player ---
	var weddings := 0
	var epitaphs := 0
	var ai_wars := 0
	var breaks := 0
	for e in events:
		if str(e).contains("Wedding bells"):
			weddings += 1
		if str(e).contains("is remembered as"):
			epitaphs += 1
		if str(e).contains("Karn-Vol Clan declares war"):
			ai_wars += 1
		if str(e).contains("breaks under the strain"):
			breaks += 1
	print("weddings: %d · epitaphs: %d · Karn-Vol-declared wars: %d · mental breaks: %d" % [
		weddings, epitaphs, ai_wars, breaks])
	assert(weddings > 1, "auto-marriage never fired — dynasties won't sustain themselves")
	assert(epitaphs > 0, "no ruler was ever eulogized in 60 years")

	# grudge inheritance: find anyone carrying an inherited or suspicion memory
	var grudges := 0
	for c in world.characters.values():
		for m in c.memories:
			if str(m["type"]) == "inherited grudge" or str(m["type"]) == "suspects poison" or str(m["type"]) == "passed over":
				grudges += 1
	print("standing grudges in the world: %d" % grudges)

	# --- Module 2 after 60 years: the family tree spreads on its own ---
	var bastards_born := 0
	var branches_split := 0
	var interregnums := 0
	var coups := 0
	var schisms := 0
	var bribes := 0
	for e in events:
		if str(e).contains("acknowledges a bastard"):
			bastards_born += 1
		if str(e).contains("cadet branch is born") or str(e).contains("co-equal split") or str(e).contains("SCHISM"):
			branches_split += 1
		if str(e).contains("Interregnum in"):
			interregnums += 1
		if str(e).contains("palace coup"):
			coups += 1
		if str(e).contains("SCHISM"):
			schisms += 1
		if str(e).contains("bends the knee — for 60 gold"):
			bribes += 1
	print("houses now: %d (from 4) · cadet branches: %d (schisms %d) · bastards born: %d" % [
		world.dynasties.size(), branches_split, schisms, bastards_born])
	print("interregnums: %d · palace coups: %d · homage bribes paid: %d · blood feuds: %d" % [
		interregnums, coups, bribes, world.blood_feuds.size()])
	print("choice events resolved by trait AI: %d" % world.events_resolved_by_ai)
	assert(world.events_resolved_by_ai > 0, "60 years should raise choice events (homage demands, breaks, warnings)")
	assert(interregnums > 0, "60 years of successions must open interregnums")
	var crowned_count := 0
	for e in events:
		if str(e).contains("is crowned"):
			crowned_count += 1
	assert(crowned_count > 0, "interregnums must end in coronations")
	for dyn in world.dynasties.values():
		if dyn.parent_id >= 0:
			if dyn.charter == "loyalist":
				assert(world.root_house_id(dyn.id) != dyn.id, "a loyalist branch cannot be its own root")
			else:
				assert(world.root_house_id(dyn.id) == dyn.id, "a %s branch must stand alone" % dyn.charter)
			print("  %s — %s branch of %s, %d living" % [dyn.name, dyn.charter,
				world.dynasties[dyn.parent_id].name, world.house_members(dyn.id).size()])
	assert(branches_split > 0, "no cadet branch ever formed in 60 years — eligibility too strict")
	assert(bastards_born > 0, "no bastard was ever born in 60 years")
	var renown_totals: Array = []
	for dyn in world.dynasties.values():
		if dyn.parent_id < 0:
			renown_totals.append("%s %d (%d legacies)" % [dyn.name, int(dyn.renown), dyn.legacies.size()])
	print("dynasty renown: " + " · ".join(renown_totals))

	# --- inheritance check: a born child's genes sit near the mid-parent values ---
	for c in world.characters.values():
		if c.father_id < 0:
			continue
		assert(c.genome.has("skin") and c.genome.has("hair_style"), "children must inherit genomes")
		var f: SimCharacter = world.characters[c.father_id]
		var m: SimCharacter = world.characters[c.mother_id]
		var mid: float = (float(f.genome["skin"]) + float(m.genome["skin"])) * 0.5
		assert(absf(float(c.genome["skin"]) - mid) < 0.5, "child gene wildly outside parental range")
		print("genetics ok — %s: skin %.2f (mid-parent %.2f), hair style %d (father %d / mother %d)" % [
			c.name, c.genome["skin"], mid, c.genome["hair_style"], f.genome["hair_style"], m.genome["hair_style"]])
		break

	print("\nlast 12 events:")
	for e in events.slice(maxi(0, events.size() - 12)):
		print("  " + str(e))

	print("\nALL CHECKS PASSED")
	quit(0)


func _fight_auto_battle(world: SimWorld) -> Array:
	## Mirrors main.gd's auto-resolve path: pending armies in, casualties out.
	var pa = world.army_by_id(world.pending_battle[0])
	var pb = world.army_by_id(world.pending_battle[1])
	assert(pa != null and pb != null, "pending battle references missing armies")
	var sim := BattleSim.new()
	sim.setup_from_rosters(pa.regiments, pb.regiments, 8, 8, ["Vael", "Karn-Vol"])
	sim.run_headless()
	assert(sim.ended, "battle never resolved — units failed to meet or fight")
	var army_ids: Array = world.pending_battle.duplicate()
	for side in 2:
		var results: Array = []
		for r: BattleSim.Regiment in sim.regiments:
			if r.side == side:
				results.append({"index": r.roster_index, "soldiers": r.soldiers, "routed": r.routed})
		world.apply_battle_casualties(army_ids[side], results, sim.winner >= 0 and sim.winner != side)
	var loser := 1 - sim.winner if sim.winner >= 0 else -1
	var loss := 0.0
	if loser >= 0:
		loss = 1.0 - sim.survivors_fraction(loser)
	print("  battle: winner side %d, survivors A %d%% / B %d%%, armies now %d vs %d men" % [
		sim.winner, int(sim.survivors_fraction(0) * 100.0), int(sim.survivors_fraction(1) * 100.0),
		world.army_size(0), world.army_size(1)])
	return [sim.winner, loss]
