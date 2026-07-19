extends SceneTree

## Focused regression suite for Hero System v1.2:
##   <godot.exe> --headless --path . --script res://tests/single_entity_hero_test.gd


func _hero(class_id: String, level: int, name: String = "Test Hero") -> Dictionary:
	var hp := HeroDB.hp_max(class_id, level)
	return {
		"id": 9000 + level, "name": name, "class": class_id,
		"subclass": HeroDB.default_subclass(class_id),
		"level": level, "combat_level": level, "legendary": level >= HeroDB.LEGENDARY_LEVEL,
		"hp": hp, "hp_max": hp, "traits": [], "names": 0, "oath_intact": true,
	}


func _sim(ours: Array = [{"kind": "sword", "soldiers": 36}],
		theirs: Array = [{"kind": "levy", "soldiers": 48}]) -> BattleSim:
	var sim := BattleSim.new()
	sim.setup_from_rosters(ours, theirs, 0, 0, ["Blue", "Red"], [], [], "plains", {})
	return sim


func _init() -> void:
	# --- independent entity and formation-level collision ---
	var movement := _sim()
	movement.set_hero(0, _hero("fighter", 5, "Independent"))
	var unit: BattleSim.HeroRuntime = movement.hero_units[0]
	var host: BattleSim.Regiment = movement.regiments[movement.hero_host[0]]
	assert(unit.pos.distance_to(host.pos) > 10.0, "hero starts as an independent entity, not at the host center")
	var start := unit.pos
	assert(movement.order_hero(0, start + Vector2(60.0, 35.0)), "hero move order accepted")
	for i in 30:
		movement.move_step(0.05)
	assert(unit.pos.distance_to(start) > 15.0, "independent hero advances under its own speed")

	var blocker: BattleSim.Regiment = movement.regiments[1]
	unit.pos = blocker.pos - Vector2(120.0, 0.0)
	movement.order_hero(0, blocker.pos + Vector2(120.0, 0.0))
	for i in 160:
		movement.move_step(0.05)
	assert(movement._hero_regiment_surface_gap(unit, blocker) >= -0.05,
		"sub-stepped collision prevents penetration at fast movement")
	assert(unit.pos.x < blocker.pos.x, "hero cannot tunnel through the opposing formation")
	print("single entity: independent movement and solid formation collision")

	# --- Rage: collision mass, physical mitigation, melee pressure ---
	var rage_sim := _sim()
	rage_sim.set_hero(0, _hero("barbarian", 5, "Rager"))
	var barbarian: BattleSim.HeroRuntime = rage_sim.hero_units[0]
	var normal_weight := barbarian.weight()
	rage_sim.combat_ticks = 5
	assert(rage_sim.use_hero_ability(0, "rage", barbarian.pos) == "", "Rage activates")
	assert(barbarian.raging() and barbarian.weight() >= normal_weight * 2.49,
		"Rage increases formation-relative collision mass")
	var rage_hp := float(rage_sim.hero_hp[0])
	rage_sim._hero_take_damage(0, 20.0, true)
	assert(absf(float(rage_sim.hero_hp[0]) - (rage_hp - 10.0)) < 0.01,
		"Rage halves physical damage without a saving-throw subsystem")
	print("rage: weight, mitigation, and compact-level melee scaling")

	# --- Wild Shape: footprint, temporary HP, and overflow ---
	var shape_sim := _sim()
	shape_sim.set_hero(0, _hero("druid", 2, "Shaper"))
	var druid: BattleSim.HeroRuntime = shape_sim.hero_units[0]
	var normal_radius := druid.radius()
	shape_sim.combat_ticks = 5
	assert(shape_sim.use_hero_ability(0, "wild_shape", druid.pos) == "", "Wild Shape activates")
	assert(druid.shaped() and druid.radius() > normal_radius, "Wild Shape swaps the visual and collision footprint")
	var shape_hp := float(shape_sim.hero_hp[0])
	var temp_hp := druid.wild_shape_hp
	shape_sim._hero_take_damage(0, temp_hp + 7.0, true)
	assert(not druid.shaped() and absf(float(shape_sim.hero_hp[0]) - (shape_hp - 7.0)) < 0.01,
		"temporary beast HP absorbs damage and overflow reaches campaign HP")
	print("wild shape: transformed footprint, temporary HP, and overflow")

	# --- Sneak Attack: front denied; flank accepted by dot product ---
	var sneak_sim := _sim()
	sneak_sim.set_hero(0, _hero("rogue", 5, "Flanker"))
	var rogue: BattleSim.HeroRuntime = sneak_sim.hero_units[0]
	var victim: BattleSim.Regiment = sneak_sim.regiments[1]
	rogue.pos = victim.pos + victim.facing * (victim.depth() * 0.5 + rogue.radius() + 0.5)
	assert(sneak_sim.hero_ability_target_gate(0, "sneak_strike", victim.pos) != "",
		"front-arc Sneak Attack is denied")
	rogue.pos = victim.pos + victim.facing.rotated(PI * 0.5) * (victim.frontage() * 0.5 + rogue.radius() + 0.5)
	assert(sneak_sim.hero_ability_target_gate(0, "sneak_strike", victim.pos) == "",
		"flank dot product exposes the regiment")
	var victim_before := victim.soldiers
	sneak_sim.combat_ticks = 5
	assert(sneak_sim.use_hero_ability(0, "sneak_strike", victim.pos) == "", "flanking Sneak Attack resolves")
	assert(victim.soldiers < victim_before, "Sneak Attack reduces aggregate regiment strength")
	print("sneak attack: facing geometry and cooperative engagement gate")

	# --- spatial spell scenes: circle, cone, line ---
	var fire := _sim([{"kind": "sword", "soldiers": 36}],
		[{"kind": "levy", "soldiers": 48}, {"kind": "levy", "soldiers": 48}])
	fire.set_hero(0, _hero("wizard", 5, "Evoker"))
	var fire_near: BattleSim.Regiment = fire.regiments[1]
	var fire_far: BattleSim.Regiment = fire.regiments[2]
	fire_far.pos = fire_near.pos + Vector2(0.0, 240.0)
	var fire_near_before := fire_near.soldiers
	var fire_far_before := fire_far.soldiers
	fire.combat_ticks = 5
	fire.use_hero_ability(0, "fireball", fire_near.pos)
	assert(fire_near.soldiers < fire_near_before and fire_far.soldiers == fire_far_before,
		"Fireball uses bounded circular intersection")

	var cone := _sim([{"kind": "sword", "soldiers": 36}],
		[{"kind": "levy", "soldiers": 48}, {"kind": "levy", "soldiers": 48}])
	cone.set_hero(0, _hero("wizard", 5, "Cryomancer"))
	var cone_origin := cone.hero_pos(0)
	var cone_front: BattleSim.Regiment = cone.regiments[1]
	var cone_back: BattleSim.Regiment = cone.regiments[2]
	cone_front.pos = cone_origin + Vector2(105.0, 0.0)
	cone_back.pos = cone_origin - Vector2(105.0, 0.0)
	var cone_front_before := cone_front.soldiers
	var cone_back_before := cone_back.soldiers
	cone.combat_ticks = 5
	cone.use_hero_ability(0, "cone_of_cold", cone_origin + Vector2.RIGHT * 150.0)
	assert(cone_front.soldiers < cone_front_before and cone_back.soldiers == cone_back_before,
		"Cone of Cold is directional and excludes targets behind the caster")

	var bolt := _sim([{"kind": "sword", "soldiers": 36}],
		[{"kind": "levy", "soldiers": 48}, {"kind": "levy", "soldiers": 48}])
	bolt.set_hero(0, _hero("wizard", 4, "Stormcaller"))
	var bolt_origin := bolt.hero_pos(0)
	var bolt_line: BattleSim.Regiment = bolt.regiments[1]
	var bolt_off: BattleSim.Regiment = bolt.regiments[2]
	bolt_line.pos = bolt_origin + Vector2(120.0, 0.0)
	bolt_off.pos = bolt_origin + Vector2(120.0, 120.0)
	var bolt_line_before := bolt_line.soldiers
	var bolt_off_before := bolt_off.soldiers
	bolt.combat_ticks = 5
	bolt.use_hero_ability(0, "lightning_bolt", bolt_origin + Vector2.RIGHT * 240.0)
	assert(bolt_line.soldiers < bolt_line_before and bolt_off.soldiers == bolt_off_before,
		"Lightning Bolt pierces only its bounded line corridor")
	print("spatial spells: circle, cone, and line intersections")

	print("\nALL SINGLE-ENTITY HERO CHECKS PASSED")
	quit(0)
