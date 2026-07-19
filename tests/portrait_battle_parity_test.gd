extends SceneTree

## Campaign-to-battle phenotype regression suite:
##   <godot.exe> --headless --path . --script res://tests/portrait_battle_parity_test.gd

const Appearance = preload("res://scripts/portrait_appearance.gd")


func _genome() -> Dictionary:
	return {
		"skin": 0.72, "undertone": 0.28, "hair_hue": 0.78, "eye_hue": 0.18,
		"face_width": 0.67, "jaw": 0.58, "chin": 0.52, "cheek": 0.61,
		"nose": 0.44, "eye_size": 0.55, "eye_spacing": 0.48, "symmetry": 0.63,
		"brow": 0.62, "mouth": 0.47, "presence": 0.71, "severity": 0.32,
		"beard": 0.76, "hair_texture": 0.69, "hair_style": 3,
		"nose_width": 0.56, "eye_tilt": 0.41, "lip_fullness": 0.50,
		"forehead": 0.48, "ear_size": 0.55, "neck_width": 0.62,
	}


func _same_color(a: Color, b: Color) -> bool:
	return a.is_equal_approx(b)


func _init() -> void:
	# --- one resolver drives FaceView and the serialized tactical profile ---
	var genome := _genome()
	var context := {"race": "orc", "culture": "drevak"}
	var profile := Appearance.battle_profile(genome, 54, false, "orc", "drevak", context)
	var portrait := FaceView.new()
	portrait.set_person(genome, 54, false, context)
	assert(_same_color(profile["skin_color"], portrait._skin_color()),
		"campaign portrait and battle payload resolve exactly the same skin")
	assert(_same_color(profile["hair_color"], portrait._hair_color()),
		"campaign portrait and battle payload resolve exactly the same age-greyed hair")
	assert(_same_color(profile["eye_color"], portrait._eye_color()),
		"campaign portrait and battle payload resolve exactly the same eyes")
	assert(str(profile["ear_kind"]) == "broad" and bool(profile["has_tusks"]),
		"Orc ancestry cues survive in the compact profile")
	var orc_skin: Color = profile["skin_color"]
	assert(orc_skin.g > orc_skin.r and orc_skin.g > orc_skin.b,
		"Orc skin resolves to a readable inherited green/olive palette")
	var brown_human := Appearance.battle_profile(genome, 32, false, "human", "vael", {})
	var brown_skin: Color = brown_human["skin_color"]
	assert(brown_skin.r > brown_skin.g and brown_skin.g > brown_skin.b and brown_skin.r < 0.72,
		"a dark-skinned Human keeps a visibly brown campaign and battle palette")
	print("shared resolver: portrait colors and tactical profile match exactly")

	# --- natural, fantasy, and authored hues remain deterministic ---
	var blue_genome := _genome()
	blue_genome["undertone"] = 0.0
	var blue_tiefling := Appearance.battle_profile(blue_genome, 31, true, "tiefling", "", {})
	var blue_skin: Color = blue_tiefling["skin_color"]
	assert(blue_skin.b > blue_skin.g and blue_skin.g > blue_skin.r,
		"cool Tiefling blood resolves to blue rather than a generic human tone")
	assert(bool(blue_tiefling["has_horns"]) and str(blue_tiefling["ear_kind"]) == "pointed",
		"Tiefling ancestry cues survive in the compact profile")
	var authored_green := _genome()
	authored_green["skin_color"] = "36a86b"
	var green_profile := Appearance.battle_profile(authored_green, 24, false, "human", "", {})
	assert(_same_color(green_profile["skin_color"], Color("36a86b")),
		"an authored fantasy skin color passes through without reinterpretation")
	var override_profile := Appearance.battle_profile(genome, 24, false, "orc", "",
		{"skin_color": Color("537ed6"), "hair_color": Color("ece8d8")})
	assert(_same_color(override_profile["skin_color"], Color("537ed6"))
		and _same_color(override_profile["hair_color"], Color("ece8d8")),
		"portrait context overrides support exact blue skin and authored hair")
	print("fantasy palettes: green, blue, ancestry cues, and explicit overrides are stable")

	# --- the world payload carries the real character rather than rerolling ---
	var world := SimWorld.new()
	world.auto_resolve_events = true
	world.setup()
	var campaign_hero: SimCharacter = null
	for candidate: SimCharacter in world.characters.values():
		if candidate.alive and candidate.hero_level > 0:
			campaign_hero = candidate
			break
	assert(campaign_hero != null, "the campaign generated a hero for parity validation")
	var hero_info := world.hero_info(campaign_hero.id)
	assert(hero_info.has("appearance"), "world.hero_info includes an authoritative appearance profile")
	var expected := Appearance.battle_profile(campaign_hero.genome, campaign_hero.age_years(world.tick),
		campaign_hero.is_female, campaign_hero.race, campaign_hero.culture,
		{"traits": campaign_hero.traits})
	var carried: Dictionary = hero_info["appearance"]
	assert(_same_color(carried["skin_color"], expected["skin_color"])
		and _same_color(carried["hair_color"], expected["hair_color"])
		and int(carried["hair_style"]) == int(campaign_hero.genome.get("hair_style", 0)),
		"hero_info carries the real genome-derived palette and style")
	var repeated: Dictionary = world.hero_info(campaign_hero.id)["appearance"]
	assert(_same_color(repeated["skin_color"], carried["skin_color"])
		and repeated.hash() == carried.hash(),
		"repeated hero_info calls do not reroll or mutate appearance")
	print("world handoff: phenotype is explicit, pure, and deterministic")

	# --- HeroActor2D consumes the profile and safely supports old saves/tests ---
	var sim := BattleSim.new()
	sim.setup_from_rosters([{"kind": "sword", "soldiers": 36}],
		[{"kind": "levy", "soldiers": 48}], 0, 0, ["Blue", "Red"], [], [], "plains", {})
	sim.set_hero(0, hero_info)
	var actor := HeroActor2D.new()
	actor.configure(sim, 0, Color("3f5f83"))
	assert(_same_color(actor._skin_color(), carried["skin_color"])
		and _same_color(actor._hair_color(), carried["hair_color"])
		and _same_color(actor._eye_color(), carried["eye_color"]),
		"field actor consumes the exact campaign skin, hair, and eye colors")

	var legacy := BattleSim.new()
	legacy.setup_from_rosters([{"kind": "sword", "soldiers": 36}],
		[{"kind": "levy", "soldiers": 48}], 0, 0, ["Blue", "Red"], [], [], "plains", {})
	legacy.set_hero(0, {"id": 999, "name": "Legacy Hero", "class": "fighter",
		"subclass": "champion", "level": 3, "combat_level": 3, "hp": 66, "hp_max": 66,
		"traits": [], "oath_intact": true})
	var legacy_actor := HeroActor2D.new()
	legacy_actor.configure(legacy, 0, Color("3f5f83"))
	assert(_same_color(legacy_actor._skin_color(), Color("caa07a")),
		"legacy heroes without an appearance payload retain a safe visible fallback")
	print("battle rendering: exact phenotype in, safe legacy fallback out")
	portrait.free()
	actor.free()
	legacy_actor.free()

	print("\nALL PORTRAIT/BATTLE APPEARANCE CHECKS PASSED")
	quit(0)
