extends SceneTree

## Headless validation of the Tactical Combat System (v1.0) — Opus's doc,
## 2026-07-08:
##   <godot.exe> --headless --path . --script res://tests/tactical_combat_test.gd
## Checks the five new unit kinds, the binary casting reliability gates,
## Silence-terrain combat effects, silence terror, threshold-work, the
## oath that does not permit routing, conviction, vigour, and determinism.


func _init() -> void:
	# --- 1. presets and campaign tables ---
	const NEW_KINDS: Array[String] = ["vigil_sworn_elite", "reactionary_chaplain",
		"warden_dead", "caeris_retinue", "forsaken_militia"]
	assert(BattleSim.PRESETS.size() == 29, "29 kinds after the Tactical Combat pass, got %d" % BattleSim.PRESETS.size())
	for kind in NEW_KINDS:
		assert(BattleSim.PRESETS.has(kind), "missing preset: %s" % kind)
		assert(SimWorld.UNIT_LABELS.has(kind), "%s missing from UNIT_LABELS" % kind)
		assert(SimWorld.UNIT_WEIGHTS.has(kind), "%s missing from UNIT_WEIGHTS" % kind)
		assert(SimWorld.RECRUIT_COST.has(kind), "%s missing from RECRUIT_COST" % kind)
		assert(int(SimWorld.RECRUIT_SIZE[kind]) == int(BattleSim.PRESETS[kind]["soldiers"]), "%s recruit size != preset" % kind)
	var vigil: Dictionary = BattleSim.PRESETS["vigil_sworn_elite"]
	assert(float(vigil["armour"]) == 18.0 and float(vigil["md"]) == 34.0 and float(vigil["lead"]) == 65.0,
		"Vigil-Sworn stats per doc §5.12")
	assert(float(vigil["panic_resistance"]) == 0.45 and float(vigil["silence_immunity"]) == 0.60,
		"the Order's ward is 0.60 — distinct from Brushgate's")
	var wd: Dictionary = BattleSim.PRESETS["warden_dead"]
	assert(bool(wd["no_morale"]) and float(wd["silence_terror"]) == 0.30 and bool(wd["defensive"]),
		"Warden-Dead per doc §5.13")
	assert(float(SimWorld.RECRUIT_COST["warden_dead"]) == 0.0, "the dead are not bought")
	assert(float(BattleSim.PRESETS["reactionary_chaplain"]["aura_lead"]) == 12.0
		and str(BattleSim.PRESETS["reactionary_chaplain"]["aura_filter"]) == "order",
		"the Chaplains' litany reaches only the Order")
	assert(float(BattleSim.PRESETS["forsaken_militia"]["conviction_lead"]) == 8.0, "conviction per doc §5.14")
	print("presets and campaign tables: 5 Tactical Combat kinds wired")

	# --- formation contact and collision regressions ---
	var contact := BattleSim.new()
	contact.setup_from_rosters([{"kind": "sword", "soldiers": 36}], [{"kind": "sword", "soldiers": 36}],
		0, 0, ["A", "B"])
	var line_a: BattleSim.Regiment = contact.regiments[0]
	var line_b: BattleSim.Regiment = contact.regiments[1]
	line_a.pos = Vector2(470.0, 320.0)
	line_b.pos = Vector2(730.0, 320.0)
	line_a.facing = Vector2.RIGHT
	line_b.facing = Vector2.LEFT
	var untouched_hp := line_b.hp_pool
	contact.combat_tick()
	assert(line_b.hp_pool == untouched_hp, "separated formations cannot inflict melee damage")
	line_a.has_move_order = true
	line_a.move_target = line_b.pos
	line_b.has_move_order = true
	line_b.move_target = line_a.pos
	# One intentionally large step exercises movement substeps and tunnelling prevention.
	contact.move_step(4.0)
	assert(line_a.pos.x < line_b.pos.x, "opposing formations never pass through one another")
	assert(line_a.engaged_id == line_b.id and line_b.engaged_id == line_a.id,
		"melee engagement begins only after the front ranks meet")
	assert(absf(contact._surface_gap(line_a, line_b)) <= BattleSim.CONTACT_TOLERANCE + 0.05,
		"engaged formations share a physical contact line")
	contact.combat_tick()
	assert(line_b.hp_pool < untouched_hp, "contact unlocks melee damage")

	var full_frontage := line_a.frontage_for_count(line_a.start_soldiers)
	var full_depth := line_a.depth_for_count(line_a.start_soldiers)
	assert(line_a.frontage_for_count(line_a.start_soldiers / 2) < full_frontage,
		"casualties contract formation frontage")
	assert(line_a.depth_for_count(line_a.start_soldiers / 2) < full_depth,
		"casualties contract formation depth")

	var friends := BattleSim.new()
	friends.setup_from_rosters([{"kind": "sword", "soldiers": 36}, {"kind": "sword", "soldiers": 36}],
		[{"kind": "sword", "soldiers": 36}], 0, 0, ["A", "B"])
	var friend_a: BattleSim.Regiment = friends.regiments[0]
	var friend_b: BattleSim.Regiment = friends.regiments[1]
	friend_a.pos = Vector2(400.0, 300.0)
	friend_b.pos = Vector2(402.0, 300.0)
	friend_a.facing = Vector2.RIGHT
	friend_b.facing = Vector2.RIGHT
	friends.move_step(0.05)
	var friendly_min := friends._formation_clearance(friend_a, friend_b) + BattleSim.ALLY_GAP
	assert(friend_a.pos.distance_to(friend_b.pos) >= friendly_min - 0.05,
		"non-engaged friendly formations retain separation")
	print("formation collision: contact-gated damage, contraction, separation and no tunnelling")

	# --- 2. the binary reliability gates (doc §3) ---
	var sim := BattleSim.new()
	sim.setup_from_rosters([{"kind": "sword", "soldiers": 36}], [{"kind": "sword", "soldiers": 36}], 0, 0, ["A", "B"])
	assert(sim.casting_reliability("arcane", ["Arcane-Blooded", "Academy-Sworn"]) == 1.0, "arcane fires on ordinary ground")
	assert(sim.casting_reliability("faith", []) == 0.30, "ordinary ground damps faith to 0.30")
	assert(absf(sim.casting_reliability("faith", ["Zealous"]) - 0.345) < 0.001, "the Zealous pray at 1.15x")
	assert(absf(sim.casting_reliability("faith", ["Broken"]) - 0.18) < 0.001, "the Broken pray at 0.60x")
	assert(sim.casting_reliability("primal", []) == 0.9, "plains carry the channel at 0.9")
	assert(sim.casting_reliability("oath", ["Oath-Sworn"]) == 1.0, "the oath holds everywhere")
	assert(sim.casting_reliability("oath", ["Oathbreaker"], true) == 0.0, "an Oathbreaker holds nothing")
	assert(sim.casting_reliability("corruption", []) == 1.0, "the Patron operates in Silence-adjacent space")
	sim.ground_silence = true
	assert(sim.casting_reliability("arcane", ["Academy-Sworn"]) == 0.5, "academy formulas Silence-degrade to 0.5")
	assert(sim.casting_reliability("arcane", ["Arcane-Blooded"]) == 0.6, "untrained casting degrades less")
	assert(absf(sim.casting_reliability("faith", []) - 0.10) < 0.001, "silence-touched ground smothers prayer")
	assert(sim.casting_reliability("primal", []) == 0.0, "the channel is gone from unquiet ground")
	sim.ground_silence = false
	sim.ground_library = true
	assert(absf(sim.casting_reliability("faith", []) - 0.80) < 0.001, "the Iron Library holds the sky up at 0.80")
	sim.ground_library = false
	sim.ground_wardstone = true
	assert(absf(sim.casting_reliability("faith", []) - 0.60) < 0.001, "the ward-stones hold it at 0.60")
	var sim_ash := BattleSim.new()
	sim_ash.setup_from_rosters([{"kind": "sword", "soldiers": 36}], [{"kind": "sword", "soldiers": 36}],
		0, 0, ["A", "B"], [], [], "ashfields")
	assert(sim_ash.ground_silence, "the Ashfields are silence-touched by definition")
	assert(sim_ash.casting_reliability("arcane", ["Arcane-Blooded"]) == 0.0, "no arcana under the Ashfields' sky")
	assert(sim_ash.casting_reliability("arcane", ["Arcane-Blooded", "Corruption Mark III"]) == 1.0,
		"except for the entity-adjacent")
	var sim_forest := BattleSim.new()
	sim_forest.setup_from_rosters([{"kind": "sword", "soldiers": 36}], [{"kind": "sword", "soldiers": 36}],
		0, 0, ["A", "B"], [], [], "forest")
	assert(sim_forest.casting_reliability("primal", []) == 1.0, "the forest carries the channel whole")
	print("binary reliability gates match doc §3 (arcane, faith, primal, oath, corruption)")

	# --- 3. workings through the gates ---
	# a Wizard's wards fire on ordinary ground and fizzle in the Ashfields
	var w1 := BattleSim.new()
	w1.setup_from_rosters([{"kind": "vael_arcane_retinue", "soldiers": 24}], [{"kind": "sword", "soldiers": 36}],
		0, 0, ["A", "B"])
	w1.set_commander_info(0, {"traits": ["Arcane-Blooded", "Academy-Sworn"], "names": 0})
	assert(w1.regiments[0].missile > 14.0, "the working fires on ordinary ground")
	assert(w1.commander_stress[0] == 0.5, "the channel asks 0.5 stress either way")
	var w2 := BattleSim.new()
	w2.setup_from_rosters([{"kind": "vael_arcane_retinue", "soldiers": 24}], [{"kind": "sword", "soldiers": 36}],
		0, 0, ["A", "B"], [], [], "ashfields")
	w2.set_commander_info(0, {"traits": ["Arcane-Blooded", "Academy-Sworn"], "names": 0})
	assert(w2.regiments[0].missile == 14.0, "the working fizzles under the Ashfields' sky")
	var w3 := BattleSim.new()
	w3.setup_from_rosters([{"kind": "vael_arcane_retinue", "soldiers": 24}], [{"kind": "sword", "soldiers": 36}],
		0, 0, ["A", "B"], [], [], "ashfields")
	w3.set_commander_info(0, {"traits": ["Arcane-Blooded", "Academy-Sworn", "Corruption Mark III"], "names": 0})
	assert(w3.regiments[0].missile > 14.0, "Mark III casts where the academy cannot")
	# the Cleric's office is presence first: the line steadies even unanswered
	var c1 := BattleSim.new()
	c1.setup_from_rosters([{"kind": "sword", "soldiers": 36}], [{"kind": "sword", "soldiers": 36}], 0, 0, ["A", "B"])
	c1.set_commander_info(0, {"traits": ["Faith-Practicing"], "names": 0})
	assert(c1.regiments[0].morale_bonus >= 5.0, "the candles steady the line")
	assert(c1.commander_stress[0] >= 2.0, "the office asks stress, answered or not")
	var c2 := BattleSim.new()
	c2.setup_from_rosters([{"kind": "sword", "soldiers": 36}], [{"kind": "sword", "soldiers": 36}], 0, 0, ["A", "B"])
	c2.set_commander_info(0, {"traits": ["Faith-Practicing", "Zealous"], "names": 0})
	assert(c2.regiments[0].morale_bonus >= 8.0, "a Zealous office grows regardless of results")
	# the sorcerer's channel meets the ground: fizzle in the Ashfields
	var s1 := BattleSim.new()
	s1.setup_from_rosters([{"kind": "archer", "soldiers": 24}], [{"kind": "sword", "soldiers": 36}],
		0, 0, ["A", "B"], [], [], "ashfields")
	s1.set_commander_info(0, {"traits": ["Arcane-Blooded"], "intrigue": 0, "martial": 0, "prowess": 0, "names": 0})
	var m_before: float = s1.regiments[0].missile
	var _e := s1.use_tactic(0, "uncontrolled_channel")
	assert(s1.regiments[0].missile == m_before, "the ground swallows the channel whole")
	assert(s1.commander_corruption[0] >= 0.5, "the failed channel still spikes the ledger")
	print("workings fire whole or fizzle whole — binary, with the costs landing either way")

	# --- 4. the oath does not permit routing (doc §3.4, §7) ---
	var o1 := BattleSim.new()
	o1.setup_from_rosters([{"kind": "vigil_sworn_elite", "soldiers": 24}], [{"kind": "sword", "soldiers": 36}],
		0, 0, ["A", "B"])
	o1.set_commander_info(0, {"traits": ["Oath-Sworn"], "oath_intact": true, "names": 0})
	var v1: BattleSim.Regiment = o1.regiments[0]
	assert(v1.oath_holds, "the commander's whole token holds the regiment's oath")
	assert(v1.md == 36.0, "the Aura of Devotion (+2 md)")
	v1.shock = 500.0
	o1.combat_tick()
	assert(not v1.routed, "the Vigil-Sworn oath does not permit routing")
	var o2 := BattleSim.new()
	o2.setup_from_rosters([{"kind": "vigil_sworn_elite", "soldiers": 24}], [{"kind": "sword", "soldiers": 36}],
		0, 0, ["A", "B"])
	o2.set_commander_info(0, {"traits": ["Oath-Sworn"], "oath_intact": false, "names": 0})
	var v2: BattleSim.Regiment = o2.regiments[0]
	assert(not v2.oath_holds, "a compromised token holds nothing")
	v2.shock = 500.0
	o2.combat_tick()
	assert(v2.routed, "without the oath they break like anyone else")
	print("the oath holds while the token is whole — and only while")

	# --- 5. the Warden-Dead: no morale, terror, dispersal (doc §5.13, §7) ---
	var wd1 := BattleSim.new()
	wd1.setup_from_rosters([{"kind": "warden_dead", "soldiers": 40}],
		[{"kind": "sword", "soldiers": 36}, {"kind": "brushgate_column", "soldiers": 18}], 0, 0, ["Ash", "Living"])
	var dead: BattleSim.Regiment = wd1.regiments[0]
	var sw: BattleSim.Regiment = wd1.regiments[1]
	var monk: BattleSim.Regiment = wd1.regiments[2]
	dead.shock = 900.0
	assert(dead.morale() == 100.0, "the Returned do not check their courage")
	sw.pos = dead.pos + Vector2(100, 0)
	monk.pos = dead.pos + Vector2(0, 100)
	wd1.combat_tick()
	assert(not dead.routed, "the Warden-Dead cannot be broken, only dispersed")
	assert(absf(sw.terror_penalty - 0.30) < 0.001, "silence terror starves nearby enemy nerve")
	assert(monk.terror_penalty == 0.0, "the Brushgate discipline does not feel it")
	assert(dead.oath_conflict == false and wd1.regiments[1].aura_bonus == 0.0, "sanity")
	# a Gravewarden commander holds the threshold: terror halved
	var wd2 := BattleSim.new()
	wd2.setup_from_rosters([{"kind": "warden_dead", "soldiers": 40}], [{"kind": "sword", "soldiers": 36}],
		0, 0, ["Ash", "Living"])
	wd2.set_commander_info(1, {"traits": ["Gravewarden-Sworn"], "names": 0})
	var sw2: BattleSim.Regiment = wd2.regiments[1]
	sw2.pos = wd2.regiments[0].pos + Vector2(100, 0)
	wd2.combat_tick()
	assert(absf(sw2.terror_penalty - 0.15) < 0.001, "a Gravewarden commander halves the terror felt")
	assert(sw2.dmg_vs_silence > 1.0, "threshold-work carries weight against the unwitnessed dead")
	print("Warden-Dead: no morale, silence terror projected, threshold-work answers it")

	# --- 6. silence-touched ground starves the nerve (doc §6) ---
	var g1 := BattleSim.new()
	g1.setup_from_rosters([{"kind": "sword", "soldiers": 36}, {"kind": "brushgate_column", "soldiers": 18}],
		[{"kind": "sword", "soldiers": 36}], 0, 0, ["A", "B"])
	var g2 := BattleSim.new()
	g2.setup_from_rosters([{"kind": "sword", "soldiers": 36}, {"kind": "brushgate_column", "soldiers": 18}],
		[{"kind": "sword", "soldiers": 36}], 0, 0, ["A", "B"], [], [], "plains", {"silence": true})
	assert(g2.ground_silence, "the ground dict marks the field silence-touched")
	for s in [g1, g2]:
		s.regiments[0].shock = 20.0
		s.regiments[1].shock = 20.0
		s.combat_tick()
	assert(g2.regiments[0].shock > g1.regiments[0].shock, "ordinary lines recover slower on unquiet ground")
	assert(absf(g2.regiments[1].shock - g1.regiments[1].shock) < 0.001, "the Brushgate Column does not feel the ground")
	print("silence-touched ground starves ordinary morale regen; the immune are untouched")

	# --- 7. the reaping meets the threshold (doc §3.6, §4) ---
	var rp := BattleSim.new()
	rp.setup_from_rosters([{"kind": "sword", "soldiers": 36}],
		[{"kind": "sword", "soldiers": 36}, {"kind": "vigil_sworn_elite", "soldiers": 24}], 0, 0, ["Patron", "Order"])
	rp.set_commander_info(0, {"traits": ["Patron-Bound"], "martial": 0, "intrigue": 0, "prowess": 0, "names": 0})
	rp.set_commander_info(1, {"traits": ["Gravewarden-Sworn"], "names": 0})
	var rp_sword: BattleSim.Regiment = rp.regiments[1]
	var rp_vigil: BattleSim.Regiment = rp.regiments[2]
	var sword_shock_0: float = rp_sword.shock  # setup-time patron terror already landed
	var _e2 := rp.use_tactic(0, "reap_the_bargain")
	var sword_taken := rp_sword.shock - sword_shock_0
	assert(sword_taken > 0.0, "the reaping reaches ordinary lines")
	assert(absf(sword_taken - 25.0 * 0.5 * rp_sword.shock_mult) < 0.01, "…but breaks against the held threshold (halved)")
	assert(rp_vigil.shock < rp_sword.shock, "the Order's ward blunts what lands")
	print("Reap the Bargain: halved at a Gravewarden's threshold, blunted by the Order's ward")

	# --- 8. the Chaplains' litany reaches only the Order (doc §5.12) ---
	var ch := BattleSim.new()
	ch.setup_from_rosters(
		[{"kind": "reactionary_chaplain", "soldiers": 16}, {"kind": "vigil_sworn_elite", "soldiers": 24}, {"kind": "sword", "soldiers": 36}],
		[{"kind": "sword", "soldiers": 36}], 0, 0, ["Order", "B"])
	ch.regiments[1].pos = ch.regiments[0].pos + Vector2(80, 0)
	ch.regiments[2].pos = ch.regiments[0].pos + Vector2(0, 80)
	ch.combat_tick()
	assert(ch.regiments[1].aura_bonus == 12.0, "the litany reaches the Vigil-Sworn")
	assert(ch.regiments[2].aura_bonus == 0.0, "ordinary swords are not of the Order")
	print("the Chaplain aura is filtered to the Order's own regiments")

	# --- 9. conviction and oath-conflict arm from the rosters (doc §5.12, §5.14) ---
	var cv := BattleSim.new()
	cv.setup_from_rosters([{"kind": "forsaken_militia", "soldiers": 36}], [{"kind": "vigil_sworn_elite", "soldiers": 24}],
		0, 0, ["Forsaken", "Order"])
	assert(cv.regiments[0].conviction_on and cv.regiments[0].morale_bonus == 8.0,
		"conviction arms against the old order's banners")
	assert(cv.regiments[1].oath_conflict == false, "the Forsaken are not heretics to the oath — yet")
	var oc := BattleSim.new()
	oc.setup_from_rosters([{"kind": "vigil_sworn_elite", "soldiers": 24}], [{"kind": "warden_dead", "soldiers": 40}],
		0, 0, ["Order", "Ash"])
	assert(oc.regiments[0].oath_conflict, "the oath answers the Silence-born")
	var oc2 := BattleSim.new()
	oc2.setup_from_rosters([{"kind": "vigil_sworn_elite", "soldiers": 24}], [{"kind": "sword", "soldiers": 36}],
		0, 0, ["Order", "Path"])
	oc2.set_commander_info(1, {"traits": [], "faith": "The Silent Path", "names": 0})
	assert(oc2.regiments[0].oath_conflict, "the oath answers heresy at the enemy's map table")
	print("oath-conflict and conviction arm from rosters and command tents")

	# --- 10. vigour: the field spends the body (doc §8) ---
	var vg := BattleSim.new()
	vg.setup_from_rosters([{"kind": "warden_dead", "soldiers": 40}], [{"kind": "brushgate_column", "soldiers": 18}],
		0, 0, ["Ash", "Order"])
	vg.regiments[1].pos = vg.regiments[0].pos + Vector2(20, 0)
	for i in 65:
		vg.move_step(0.05)
		vg.combat_tick()
	assert(vg.regiments[0].vigour >= 60.0, "an hour in the press is spent from the body")
	assert(vg.regiments[0].fatigue >= 0.10, "the Warden-Dead tire like any body")
	assert(vg.regiments[1].vigour < vg.regiments[0].vigour * 0.7, "the Brushgate forms spend it slowly (0.60x)")
	print("vigour accumulates in the press; the Brushgate discipline outlasts")

	# --- 11. arcane volleys find the Returned (doc §5.13) ---
	var av := BattleSim.new()
	av.setup_from_rosters([{"kind": "vael_arcane_retinue", "soldiers": 24}], [{"kind": "warden_dead", "soldiers": 40}],
		0, 0, ["Vael", "Ash"])
	var shooter: BattleSim.Regiment = av.regiments[0]
	var target: BattleSim.Regiment = av.regiments[1]
	target.pos = shooter.pos + Vector2(200, 0)
	var dmg := {}
	av._ranged_tick(dmg)
	var per_hit: float = maxf(14.0 * (35.0 / 37.0), 14.0 * 0.15) * 1.4
	var block: float = 0.15 * (1.0 if target.ward_shield else BattleSim.SHIELD_ARC_FACTOR[av._arc(shooter, target)])
	var expected: float = 24.0 * 0.06 * 0.35 * per_hit * (1.0 - block)
	assert(absf(float(dmg[target.id]) - expected) < 0.01, "arcane volleys strike the Returned at 1.4x")
	print("arcane fire finds what swords cannot")

	# --- 12. full battles resolve, deterministically ---
	var b1 := BattleSim.new()
	var b2 := BattleSim.new()
	for b in [b1, b2]:
		b.setup_from_rosters(
			[{"kind": "vigil_sworn_elite", "soldiers": 24}, {"kind": "reactionary_chaplain", "soldiers": 16}],
			[{"kind": "warden_dead", "soldiers": 40}, {"kind": "warden_dead", "soldiers": 40}],
			8, 0, ["Order", "Ashfields"], ["Zealous"], [], "plains", {"silence": true})
		b.set_commander_info(0, {"traits": ["Oath-Sworn", "Faith-Practicing", "Zealous"], "oath_intact": true,
			"faith": "Aelindran Orthodox", "martial": 12, "intrigue": 5, "prowess": 10, "names": 0})
		b.run_headless()
	assert(b1.ended and b2.ended, "the Order meets the Warden-Dead and the field resolves")
	assert(b1.winner == b2.winner, "identical setups produce identical battles")
	assert(b1.survivors_fraction(0) == b2.survivors_fraction(0), "…down to the survivor counts")
	assert(b1.commander_stress[0] == b2.commander_stress[0], "…and the commanders' ledgers")
	print("Order vs Warden-Dead resolves on silence-touched ground (winner: side %d), deterministically" % b1.winner)

	# --- 13. campaign wiring: ground, gates ---
	var world := SimWorld.new()
	world.setup()
	var ground: Dictionary = world.battle_site_ground()
	assert(ground.has("silence") and ground.has("ruined") and ground.has("special"),
		"battle_site_ground carries the province's theology")
	assert(world.recruit_gate(0, "warden_dead") != "", "the dead are not yours to muster")
	assert(world.recruit_gate(0, "caeris_retinue") != "", "Caeris's own are not for hire")
	assert(world.recruit_gate(0, "forsaken_militia") != "", "no Forsaken regional dominance yet")
	var ruler: SimCharacter = world.characters[world.realms[0].ruler_id]
	var vigil_open: bool = world.faith_of(ruler) == "Aelindran Orthodox" and ruler.traits.has("Zealous")
	assert((world.recruit_gate(0, "vigil_sworn_elite") == "") == vigil_open,
		"the Order answers only a Zealous crown of the old faith")
	print("campaign gates: the Silence's forces answer no ordinary muster (vigil open for realm 0: %s)" % str(vigil_open))

	print("\nALL TACTICAL COMBAT CHECKS PASSED")
	quit(0)
