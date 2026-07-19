extends SceneTree

## Headless validation of The Hero System (v1.0) — Opus's doc, 2026-07-08
## (Drive 1KJZwBXhxogVA5PmdgYJRcHpDFCbuRfAmSzJEUzTLJMg):
##   <godot.exe> --headless --path . --script res://tests/hero_system_test.gd
## Checks the HeroDB tables (thresholds, classes, Fireball-at-five), the
## canonical instantiation at Year Zero (§8), the hero stream discipline
## (XP ledger vs the player's hand), hero combat integration (abilities,
## gates, personal HP, death saves, Legendary Actions), the deployment
## rules, and two-world determinism with the heroes live.


func _find_hero(world: SimWorld, full: String) -> SimCharacter:
	## Heroes by FULL name — given names like "Aldric" also live in the
	## founder name pools, and the roster must not be fooled by them.
	for c: SimCharacter in world.characters.values():
		if c.alive and c.hero_level > 0 and world.full_name(c) == full:
			return c
	return null


func _init() -> void:
	# --- 1. the tables (doc §3-4) ---
	assert(HeroDB.LEVEL_XP == ([0, 0, 500, 1500, 3500, 7000, 12000, 20000, 32000, 50000, 75000] as Array[int]),
		"the level thresholds, doc §3 verbatim")
	assert(HeroDB.level_for_xp(0) == 1 and HeroDB.level_for_xp(499) == 1, "level 1 baseline")
	assert(HeroDB.level_for_xp(7000) == 5 and HeroDB.level_for_xp(6999) == 4, "7000 XP stands at level 5")
	assert(HeroDB.level_for_xp(75000) == 10 and HeroDB.level_for_xp(999999) == 10, "level 10 caps the craft")
	assert(HeroDB.base_hp("wizard") == 30 and HeroDB.base_hp("fighter") == 50 and HeroDB.base_hp("cleric") == 40,
		"frail wizards, hearty warriors, 40 baseline (doc §3)")
	assert(HeroDB.hp_max("wizard", 10) == 102 and HeroDB.hp_max("cleric", 10) == 112,
		"+8 HP per level: the doc's 112 at the 40-baseline")
	# Twelve familiar class chassis, compressed to the campaign's 1-10 scale.
	assert(HeroDB.CLASSES.size() == 12, "twelve class chassis, got %d" % HeroDB.CLASSES.size())
	for gone in ["scholar", "diplomat", "merchant", "bureaucrat", "noble", "gravewarden", "ward_speaker"]:
		assert(not HeroDB.has_class(gone), "'%s' is an office or a subclass, never a class" % gone)
	for cid in ["barbarian", "wizard", "sorcerer", "cleric", "paladin", "druid", "warlock", "bard", "monk",
			"fighter", "ranger", "rogue"]:
		assert(HeroDB.has_class(cid), "the twelve progression classes exist: %s" % cid)
		assert(HeroDB.growth(cid).size() == 2, "%s grows two stats per level" % cid)
		assert(HeroDB.default_subclass(cid) != "", "%s has its SRD subclass" % cid)
	# subclasses: the SRD ships one per class; Khessar's traditions fill the shelf
	for sid in HeroDB.SUBCLASSES:
		assert(HeroDB.has_class(str(HeroDB.SUBCLASSES[sid]["class"])),
			"subclass %s belongs to a real class" % sid)
	for khessari in ["unfinished", "ward_speech", "threshold", "reclaimed_rites", "vigil",
			"carried_names", "brushgate", "clan_sworn", "watchful"]:
		assert(HeroDB.has_subclass(khessari) and not bool(HeroDB.SUBCLASSES[khessari].get("srd", false)),
			"the Khessari tradition %s exists beside the SRD's" % khessari)
	# distinct progressions: no two classes share both growth stats AND grants
	var shapes := {}
	for cid in ["barbarian", "wizard", "cleric", "paladin", "druid", "warlock", "bard", "monk",
			"fighter", "ranger", "rogue"]:
		var shape := str(HeroDB.growth(cid)) + str(HeroDB.GRANTS.get(cid, {}).keys())
		assert(not shapes.has(shape), "%s duplicates another class's progression shape" % cid)
		shapes[shape] = cid
	# Fireball at LEVEL 5, per the doc's "(per your instinct)" ruling
	assert(not HeroDB.abilities_at("wizard", 4).has("fireball"), "no Fireball at level 4")
	assert(HeroDB.abilities_at("wizard", 5).has("fireball"), "Fireball arrives at level 5")
	assert(HeroDB.abilities_at("wizard", 4).has("lightning_bolt") and HeroDB.abilities_at("wizard", 4).has("counterspell"),
		"level 4 keeps Lightning Bolt and Counterspell")
	assert(not HeroDB.battle_actives("wizard", 5).has("detect_magic"), "utilities are not field orders")
	assert(HeroDB.battle_passives("paladin", 5).has("aura_of_protection"), "the paladin aura is a passive")
	assert(HeroDB.battle_actives("barbarian", 1).has("rage"), "barbarians enter the field with Rage")
	assert(HeroDB.battle_actives("druid", 2).has("wild_shape"), "compressed level 2 unlocks Wild Shape")
	# exclusive traditions stand apart from their class table
	assert(HeroDB.abilities_at("wizard", 9, "unfinished") == ["observe", "redirect", "settling_touch"],
		"the School of the Unfinished never learned a fireball")
	assert(not HeroDB.abilities_at("wizard", 6, "ward_speech").has("fireball")
		and HeroDB.abilities_at("wizard", 6, "ward_speech").has("deep_ward"),
		"the ward-speakers keep their own shelf")
	assert(HeroDB.battle_actives("wizard", 8, "archive").is_empty(),
		"the School of the Archive fights with correspondence")
	assert(HeroDB.practice_for("wizard", "unfinished") == "" and HeroDB.practice_for("wizard") == "arcane",
		"threshold anchor-work walks an older theology than the academy")
	print("HeroDB: twelve compressed class chassis, Khessari subclasses, spatial spells at five")

	# --- 2. canonical instantiation at Year Zero (doc §8) ---
	var world := SimWorld.new()
	world.auto_resolve_events = true
	world.setup()
	var named := 0
	for c: SimCharacter in world.characters.values():
		if c.alive and c.hero_level > 0:
			named += 1
			assert(HeroDB.has_class(c.hero_class), "%s carries a real class" % world.full_name(c))
			assert(c.hero_xp == HeroDB.xp_for_level(c.hero_level), "XP matches the level stood at")
			assert(c.hero_hp == c.hero_hp_max and c.hero_hp_max == HeroDB.hp_max(c.hero_class, c.hero_level),
				"personal HP pools full at Year Zero")
	assert(named >= 40, "the §8 roster's class-bearers stand: %d named heroes (expected ≥40)" % named)
	var total := world.hero_count()
	assert(total >= 200 and total <= 400, "continent-wide density 200-400 (doc §2), got %d" % total)
	# the key canonical figures, by the doc's own numbers — SRD chassis only
	var caeris: SimCharacter = world.characters.get(world.caeris_id)
	assert(caeris.hero_class == "wizard" and caeris.hero_subclass == "unfinished" and caeris.hero_level == 9,
		"Caeris: Level 9 Wizard, School of the Unfinished — his own tradition, not the academy's")
	assert(world.hero_info(world.caeris_id)["legendary"] == true, "Legendary at L8+ (doc §7)")
	assert(not caeris.traits.has("Arcane-Blooded"),
		"the chassis is a class; the campaign practice traits stay a separate layer")
	var vovel: SimCharacter = world.characters.get(world.marek_id)
	assert(vovel.hero_class == "wizard" and vovel.hero_subclass == "archive" and vovel.hero_combat_level == 2,
		"Marek Vovel: the L7 evoker of his prime keeps the Archive now")
	var halvar: SimCharacter = world.characters.get(world.halvar_id)
	assert(halvar.hero_class == "cleric" and halvar.hero_subclass == "threshold" and halvar.hero_level == 7,
		"Halvar Stenn: Level 7 Cleric of the Threshold Domain — the Gravewarden is a domain, not a class")
	assert((world.characters.get(world.halloran_id) as SimCharacter).hero_level == 4, "Halloran: Level 4 Wizard")
	assert((world.characters.get(world.odric_id) as SimCharacter).hero_level == 5, "Odric Vasse: the senior of the four")
	assert((world.characters.get(world.mareck_id) as SimCharacter).hero_class == "rogue"
		and (world.characters.get(world.mareck_id) as SimCharacter).hero_subclass == "watchful",
		"Tess Mareck: Level 6 Rogue, the Watchful — and Chief Spymaster by office")
	var thaladris := world._map_realm_named("Thaladris")
	var ariorwe: SimCharacter = world.characters.get(int(world.cast_rulers[thaladris]["id"]))
	assert(ariorwe.hero_class == "bard" and ariorwe.hero_subclass == "carried_names" and ariorwe.names_carried >= 120,
		"Ariorwe: Level 8 Bard of the College of Carried Names")
	# the SRD rule's other half: ordinary souls are their office, not a class
	var eithne: SimCharacter = world.characters.get(int(world.cast_rulers[world._map_realm_named("Pellar")]["id"]))
	assert(eithne.hero_level == 0 and world.position_of(eithne) == "Queen of Pellar",
		"Eithne is a Queen — not a 'level 5 diplomat'")
	var thessaly: SimCharacter = world.characters.get(world.thessaly_id)
	assert(thessaly.hero_level == 0 and world.position_of(thessaly) == "Archivist of the Iron Library",
		"Thessaly is her desk, and the desk is not a class")
	var sevrin: SimCharacter = world.characters.get(world.sevrin_id)
	assert(sevrin.hero_level == 0 and world.position_of(sevrin) == "Secretary to the Council",
		"Sevrin: a very good clerk, and only that")
	var sera: SimCharacter = world.characters.get(world.sera_id)
	assert(sera.hero_level == 0 and world.position_of(sera) == "Courtier",
		"Sera defaults to Courtier — ordinary until the day proves otherwise")
	print("canonical instantiation: %d class-bearing heroes, %d continent-wide; the rest are their offices" % [named, total])

	# --- 3. the 27 the chronicle owed a body (doc §8) ---
	var vaelmark := _find_hero(world, "Aldric Vaelmark")
	assert(vaelmark != null and vaelmark.hero_class == "paladin" and vaelmark.hero_level == 6
		and vaelmark.hero_subclass == "vigil",
		"Sir Aldric Vaelmark: Level 6 Paladin, Oath of the Vigil")
	assert(world.hero_cast.has(vaelmark.id) and world.is_cast(vaelmark),
		"the Order's commanders never enter the main stream's dice")
	assert(vaelmark.traits.has("Oath-Sworn") and vaelmark.faith == "Aelindran Orthodox",
		"oath-sworn to the old rites")
	var responses := 0
	for t in vaelmark.traits:
		if t in ["Zealous", "Broken", "Pragmatic", "Opportunistic"]:
			responses += 1
	assert(responses == 1, "exactly one Silence Response — the magic census holds")
	var ilsen := _find_hero(world, "Ilsen the Righteous")
	assert(ilsen != null and ilsen.hero_class == "paladin" and ilsen.hero_level == 5,
		"Dame Ilsen the Righteous: Level 5 Paladin")
	var iliana := _find_hero(world, "Iliana Vesh")
	assert(iliana != null and iliana.hero_class == "bard" and iliana.hero_subclass == "carried_names"
		and iliana.names_carried == 40, "Iliana Vesh: Level 4 Bard, College of Carried Names")
	assert(not iliana.traits.has("Song-Marked"),
		"the Song-Marked trait is withheld in v1.0 — _bard_tick draws mrng per singer (flagged)")
	var bronvor := _find_hero(world, "Bronvor Iron-Deep")
	assert(bronvor != null and bronvor.hero_class == "wizard" and bronvor.hero_subclass == "ward_speech"
		and bronvor.race == "dwarf",
		"Bronvor Iron-Deep: a Wizard of the School of Ward-Speech — the calling is a school, not a class")
	assert(world.position_of(bronvor) == "Chief Ward-Speaker", "and Chief Ward-Speaker by office")
	var kaal := _find_hero(world, "Kaal Vor-Grathkaz")
	assert(kaal != null and kaal.hero_level == 5 and kaal.hero_subclass == "clan_sworn"
		and world.hero_cast.has(kaal.id),
		"Kaal Vor-Grathkaz: the compact-breaker, Clan-Sworn, guarded out of the stream")
	var marak := _find_hero(world, "Marak Khorul")
	assert(marak != null and marak.hero_class == "wizard" and marak.hero_level == 5
		and marak.hero_subclass == "evocation" and marak.traits.has("Academy-Sworn"),
		"Marak Khorul: Level 5 Evoker on the Salt Road (the SRD default when no tradition is named)")
	# the seeded souls the SRD rule keeps ordinary: offices, not classes
	var otter: SimCharacter = null
	var thelren: SimCharacter = null
	for c: SimCharacter in world.characters.values():
		if world.full_name(c) == "Otter Straven":
			otter = c
		elif world.full_name(c) == "Thelren Dunmoreth":
			thelren = c
	assert(otter != null and otter.hero_level == 0
		and world.position_of(otter) == "Master Merchant of the Salt Road",
		"Otter Straven: the ledgers are the craft, and the craft is not a class")
	assert(thelren != null and thelren.hero_level == 0
		and world.position_of(thelren) == "Baron of Dunmore", "Thelren is a Baron, full stop")
	assert(world.hero_cast.has(otter.id) and world.hero_cast.has(thelren.id),
		"class or no class, the seeded souls stay guarded out of the stream")
	for h in [vaelmark, ilsen, iliana, bronvor, kaal, marak, otter, thelren]:
		for prop in ["diplomacy", "martial", "stewardship", "intrigue", "learning", "prowess"]:
			var v := int(h.get(prop))
			assert(v >= 1 and v <= 30, "the census bounds hold for %s" % world.full_name(h))
	print("the owed bodies: heroes with SRD chassis, officers with offices — all seeded, all guarded")

	# --- 4. the hero stream discipline: XP ledger vs the player's hand ---
	var tavisol := _find_hero(world, "Tavisol of the Road")
	assert(tavisol != null and tavisol.hero_level == 3 and tavisol.hero_xp == 1500, "Tavisol at L3")
	var prw_before := tavisol.prowess
	world.award_hero_xp(tavisol.id, 2000, "an auto-firing beat")  # not by_hand
	assert(tavisol.hero_level == 4 and tavisol.hero_xp == 3500, "the ledger levels: 3500 XP = level 4")
	assert(tavisol.prowess == prw_before, "auto-firing beats never move the Core Six")
	assert(tavisol.hero_hp_max == HeroDB.hp_max("paladin", 4), "the HP pool grows regardless")
	var voss := _find_hero(world, "Marek Voss")
	assert(voss != null and voss.hero_class == "paladin", "the find resolves the Brother-Captain")
	var voss_prw := voss.prowess
	var voss_dip := voss.diplomacy
	world.award_hero_xp(voss.id, 4000, "the player's own field", true)  # by_hand
	assert(voss.hero_level == 5, "3500+4000 = 7500 XP stands at level 5")
	assert(voss.prowess == voss_prw + 1 and voss.diplomacy == voss_dip + 1,
		"the player's hand moves the paladin's growth stats (+1 prw, +1 dip)")
	print("stream discipline: the ledger fills on its own; the Core Six wait for the hand")

	# --- 5. hero combat: the wizard's fire, the gates, the auras (doc §7) ---
	var sim := BattleSim.new()
	sim.setup_from_rosters(
		[{"kind": "sword", "soldiers": 36}, {"kind": "archer", "soldiers": 24}],
		[{"kind": "levy", "soldiers": 48}, {"kind": "levy", "soldiers": 48}],
		0, 0, ["Hero", "Line"], [], [], "plains", {})
	sim.set_hero(0, world.hero_info(marak.id))
	assert(sim.hero_active(0) and sim.hero_abilities(0).has("fireball"), "a L5 wizard carries Fireball")
	assert(sim.hero_ability_gate(0, "meteor_swarm") != "", "L7 workings are beyond a L5 wizard")
	var target: BattleSim.Regiment = sim.regiments[2]
	var before := target.soldiers
	sim.combat_ticks = 5
	var msg := sim.use_hero_ability(0, "fireball", target.pos)
	assert(msg == "", "the order is accepted: %s" % msg)
	assert(target.soldiers < before, "a formed regiment is not formed afterward (doc §10)")
	assert(sim.hero_ability_gate(0, "fireball") != "", "the global cooldown holds after a working")
	assert(sim.hero_actions_used[0] == 1, "the working is counted")
	# determinism: the same battle twice is the same battle
	var sim2 := BattleSim.new()
	sim2.setup_from_rosters(
		[{"kind": "sword", "soldiers": 36}, {"kind": "archer", "soldiers": 24}],
		[{"kind": "levy", "soldiers": 48}, {"kind": "levy", "soldiers": 48}],
		0, 0, ["Hero", "Line"], [], [], "plains", {})
	sim2.set_hero(0, world.hero_info(marak.id))
	sim2.combat_ticks = 5
	var _m2 := sim2.use_hero_ability(0, "fireball", (sim2.regiments[2] as BattleSim.Regiment).pos)
	assert((sim2.regiments[2] as BattleSim.Regiment).soldiers == target.soldiers,
		"identical setups, identical fire — the battle keeps its own dice")
	# the Ashfields swallow academy formulas whole (Tactical v1.0 gates)
	var sim3 := BattleSim.new()
	sim3.setup_from_rosters(
		[{"kind": "sword", "soldiers": 36}], [{"kind": "warden_dead", "soldiers": 40}],
		0, 0, ["Hero", "Grey"], [], [], "ashfields", {"silence": true})
	sim3.set_hero(0, world.hero_info(marak.id))
	sim3.combat_ticks = 5
	var wd_before: int = (sim3.regiments[1] as BattleSim.Regiment).soldiers
	var _m3 := sim3.use_hero_ability(0, "fireball", (sim3.regiments[1] as BattleSim.Regiment).pos)
	assert((sim3.regiments[1] as BattleSim.Regiment).soldiers == wd_before,
		"this ground does not carry the formula — the working fizzles whole")
	# the paladin's standing aura reaches the lines around him
	var sim4 := BattleSim.new()
	sim4.setup_from_rosters(
		[{"kind": "sword", "soldiers": 36}, {"kind": "levy", "soldiers": 48}],
		[{"kind": "levy", "soldiers": 48}], 0, 0, ["Order", "Foe"], [], [], "plains", {})
	sim4.set_hero(0, world.hero_info(ilsen.id))  # L5 paladin: Aura of Protection
	sim4._aura_tick()
	var aura_seen := false
	for r: BattleSim.Regiment in sim4.regiments:
		if r.side == 0 and r.aura_bonus >= 6.0:
			aura_seen = true
	assert(aura_seen, "Aura of Protection: +6 leadership around the paladin")
	# the cleric mends a bled line — on ward-stone ground, where the old
	# theology still answers most askings (damp 0.60 × the Zealous 1.15)
	var sim5 := BattleSim.new()
	sim5.setup_from_rosters(
		[{"kind": "sword", "soldiers": 36}], [{"kind": "levy", "soldiers": 48}],
		0, 0, ["Faith", "Foe"], [], [], "mountain", {"special": "sealed_hold"})
	var selene := _find_hero(world, "Selene Tharn")
	sim5.set_hero(0, world.hero_info(selene.id))
	var line: BattleSim.Regiment = sim5.regiments[0]
	line.hp_pool -= 120.0
	line.soldiers = int(ceil(line.hp_pool / line.hp_per))
	var bled := line.soldiers
	sim5.combat_ticks = 5
	# faith gates are genuinely uncertain — spend the heal askings; the
	# seeded battle dice make the outcome reproducible
	var healed := false
	for aid in ["cure_wounds", "prayer_of_healing", "mass_healing_word"]:
		for i in 4:
			sim5.combat_ticks += 30
			var _hm := sim5.use_hero_ability(0, str(aid), line.pos)
			if line.soldiers > bled:
				healed = true
				break
		if healed:
			break
	assert(healed, "the prayer lands within the battle's own dice — men stand back up")
	print("hero combat: fireball %d→%d men, gates hold, fizzles whole on grey ground, auras carry" % [before, target.soldiers])

	# --- 6. personal HP, death saves, Legendary Resistance (doc §7) ---
	var sim6 := BattleSim.new()
	sim6.setup_from_rosters(
		[{"kind": "levy", "soldiers": 48}], [{"kind": "sword", "soldiers": 36}],
		0, 0, ["Down", "Foe"], [], [], "plains", {})
	sim6.set_hero(0, world.hero_info(tavisol.id))
	sim6._hero_take_damage(0, 999.0)
	assert(sim6.hero_state[0] == "unconscious", "at 0 HP the hero falls, not dies (doc §7)")
	for i in 30:
		if sim6.hero_state[0] != "unconscious":
			break
		sim6._hero_battle_tick()
	assert(sim6.hero_state[0] in ["stable", "dead"], "three saves decide it, either way")
	var sim7 := BattleSim.new()
	sim7.setup_from_rosters(
		[{"kind": "levy", "soldiers": 48}], [{"kind": "sword", "soldiers": 36}],
		0, 0, ["Legend", "Foe"], [], [], "plains", {})
	sim7.set_hero(0, world.hero_info(world.caeris_id))
	assert(sim7.hero_resist[0] == 3, "Legendary Resistance: 3 charges (doc §7)")
	assert(sim7.hero_abilities(0) == ["observe", "redirect", "settling_touch"],
		"Caeris's Legendary Actions, translated exactly (Canon Updates)")
	assert(sim7.hero_ability_gate(0, "fireball") != "",
		"a level 9 Wizard of the Unfinished still cannot throw a fireball — the school stands apart")
	sim7._hero_take_damage(0, 999.0)
	for i in 40:
		if sim7.hero_state[0] != "unconscious":
			break
		sim7._hero_battle_tick()
	assert(sim7.hero_state[0] != "dead" or sim7.hero_resist[0] == 0,
		"a Legendary hero spends every refusal before dying")
	print("death saves: the fallen decide in three; the Legendary refuse three times first")

	# --- 7. the field feeds the campaign: wounds, XP, deployment gates ---
	var sim8 := BattleSim.new()
	sim8.setup_from_rosters(
		[{"kind": "sword", "soldiers": 36}], [{"kind": "levy", "soldiers": 48}],
		0, 0, ["Home", "Foe"], [], [], "plains", {})
	var drev := _find_hero(world, "Drev Karn-Vol")
	assert(drev != null and drev.hero_class == "barbarian" and drev.hero_subclass == "berserker",
		"Drev Karn-Vol makes the Rage chassis available to the current campaign")
	sim8.set_hero(0, world.hero_info(drev.id))
	sim8.hero_state[0] = "stable"
	sim8.ended = true
	sim8.winner = 0
	var xp_before := drev.hero_xp
	var _line8 := world.apply_hero_battle(sim8, 0, true)
	assert(drev.traits.has("Wounded") and drev.hero_wounded_until > world.tick,
		"carried from the field: the Wounded trait and months of recovery")
	assert(drev.hero_xp > xp_before, "the field taught what it teaches — XP banked")
	assert(world.set_commander(world.armies[1].id if world.armies.size() > 1 else world.armies[0].id, drev.id) != "",
		"a recovering hero does not take a command")
	print("the field feeds the campaign: wounds gate deployment, experience banks")

	# --- 8. two worlds, twelve months: the heroes keep the determinism ---
	var w1 := SimWorld.new()
	w1.auto_resolve_events = true
	w1.setup()
	var w2 := SimWorld.new()
	w2.auto_resolve_events = true
	w2.setup()
	for i in 12:
		w1.advance_month()
		w2.advance_month()
	assert(str(w1.hero_pool) == str(w2.hero_pool), "the pool drifts identically")
	for c1: SimCharacter in w1.characters.values():
		if c1.hero_level <= 0:
			continue
		var c2: SimCharacter = w2.characters.get(c1.id)
		assert(c2 != null and c2.hero_level == c1.hero_level and c2.hero_xp == c1.hero_xp,
			"hero ledgers identical across worlds: %s" % w1.full_name(c1))
	assert(w1.hero_count() == w2.hero_count(), "the continent counts the same heroes")
	print("determinism: two worlds, twelve months, identical hero ledgers")

	print("")
	print("ALL HERO SYSTEM CHECKS PASSED")
	quit()
