extends SceneTree

## Headless validation of The World the Silence Made (v1.1) — Opus's doc,
## 2026-07-08 (Drive 19Cmw0eZS4AHKx3nymYC3n3jKJrcYDYc-uENjeGOmOkM):
##   <godot.exe> --headless --path . --script res://tests/silence_made_test.gd
## Checks Caeris's corrected canonical shape (male scholar, not a Magister),
## growth through intake rather than conquest, the settling progression, the
## consent-framework collaboration arc, the military option's documented
## consequences, the Forsaken movements, and the Year-50 convergence.


func _init() -> void:
	# --- 1. Caeris the Unfinished: the corrected canonical shape (doc §2) ---
	var world := SimWorld.new()
	world.auto_resolve_events = true
	world.setup()
	var caeris: SimCharacter = world.characters.get(world.caeris_id)
	assert(caeris != null and caeris.alive, "Caeris is seeded at Year Zero")
	assert(not caeris.is_female, "Caeris is a man — the v1.0 miscast is corrected")
	assert(caeris.age_years(world.tick) == 62, "sixty-two years old, got %d" % caeris.age_years(world.tick))
	assert(caeris.learning == 26 and caeris.stewardship == 16 and caeris.martial == 8,
		"Core Six per doc §2 (L26/S16/M8)")
	assert(caeris.traits.has("Threshold-Sensitive") and caeris.traits.has("Patient"),
		"the researcher's traits, not a Patron-Bound Magister's")
	assert(caeris.traits.has("Focused") and caeris.traits.has("Methodical"),
		"Focused is what defines him; Methodical is how he works (Canon Updates v1.0)")
	assert(not caeris.traits.has("Patron-Bound") and not caeris.traits.has("Corruption Mark II"),
		"v1.0's Patron accommodation is gone — he is a scholar")
	assert(caeris.realm_id == SimWorld.ASHFIELDS_REALM, "the Ashfields is his, and no realm's")
	assert(world.is_cast(caeris), "outside the main stream's actuarial dice")
	assert(world.full_name(caeris) == "Caeris the Unfinished", "the name, got %s" % world.full_name(caeris))
	assert(world.cast_title_of(caeris.id) == "Scholar of the Ashfields", "no crown — a research environment")
	assert(world.map.realm_display_name(SimWorld.ASHFIELDS_REALM) == "The Ashfields", "the sheet names the grey country")
	var maret: SimCharacter = world.characters.get(world.maret_id)
	assert(maret != null and maret.alive, "Maret the Revenant works beside him")
	assert(maret.age_years(world.tick) == 47 and maret.learning == 18 and maret.traits.has("Focused"),
		"Maret canonized: 47, Learning 18, Returned-Focused (Canon Updates v1.0 §2)")
	# the Focused trait itself, per the canon doc's exact definition
	assert(TraitDB.has_trait("Focused") and TraitDB.has_trait("Restless"), "Focused/Restless in the db")
	assert(TraitDB.info("Focused").category == "personality" and TraitDB.info("Focused").opposite == "Restless",
		"Focused is personality, opposite Restless")
	assert(absf(float(TraitDB.info("Focused").mods["corruption_gain_mult"]) - 1.15) < 0.001,
		"sustained purpose pays costs the unfocused would not")
	var veril: SimCharacter = world.characters.get(world.architect_id)
	assert(veril != null and veril.traits.has("Focused"), "thirty-four years in the Sublevel is Focused")
	var halvar: SimCharacter = world.characters.get(world.halvar_id)
	assert(halvar != null and halvar.traits.has("Focused"), "the Gravewarden practice is Focused")
	var marek_c: SimCharacter = world.characters.get(world.marek_id)
	assert(marek_c != null and marek_c.traits.has("Focused") and marek_c.learning == 26,
		"Marek: Focused, Learning 26 (canon lock)")
	assert(float(world.ashfields["living"]) == 4000.0, "4,000 living residents at Year Zero (doc §4)")
	assert(absf(world.ashfields_returned_total() - 500.0) < 0.01, "≈500 Returned in various stages (doc §10)")
	assert(float(world.ashfields["warden_dead"]) == 200.0, "200 Warden-Dead — defense, not an army")
	assert(world.forsaken_movements.size() == 5, "five regional Forsaken variants (doc §7)")
	print("Caeris canonical shape: male scholar, 62, L26, Threshold-Sensitive — v1.1 corrections hold")

	# --- 2. growth through intake, never conquest (doc §3) ---
	var start_pop := world.ashfields_population()
	for pid in world.map.provinces.size():
		if world.map.provinces[pid].cultural_region == "ashfields":
			assert(world.map.provinces[pid].owner == -1, "the Ashfields provinces start unowned")
	for i in 24:
		world.advance_month()
	assert(world.ashfields_population() > start_pop + 100.0,
		"two years of pilgrimages grow the community (got %+.0f)" % (world.ashfields_population() - start_pop))
	for pid in world.map.provinces.size():
		if world.map.provinces[pid].cultural_region == "ashfields":
			assert(world.map.provinces[pid].owner == -1, "no province changes hands — intake is not conquest")
	print("growth through intake: +%d souls in two years, zero provinces taken" % int(world.ashfields_population() - start_pop))

	# --- 3. the settling problem progresses (doc §4) ---
	assert(float(world.ashfields["settled"]) > 40.0, "the Settled grow — the tragedy is ongoing")
	assert(float(world.ashfields["hollow"]) > 10.0, "and the Hollow accumulate behind them")
	assert(float(world.ashfields["anchored"]) == 0.0, "no anchors without the framework")
	print("settling progression: Settled %.0f, Hollow %.0f — the problem Caeris cannot solve alone" % [
		float(world.ashfields["settled"]), float(world.ashfields["hollow"])])

	# --- 4. the consent framework: contact, sponsorship, three seals, publication (doc §5) ---
	var ruler: SimCharacter = world.characters[world.realms[0].ruler_id]
	ruler.learning = 14
	assert(world.ashfields_envoy_gate(0) != "", "understanding the research requires Learning 16")
	ruler.learning = 21
	assert(world.ashfields_envoy_gate(0) == "", "a prepared crown may send the envoy")
	var msg := world.ashfields_send_envoy(0)
	assert(msg.contains("east"), "the envoy rides")
	assert(bool(world.ashfields["contacted"]), "every conversation option leaves him contacted")
	world.ashfields["finding_heard"] = true  # rig the specific question — the AI's pick is srng's
	var marek: SimCharacter = world.characters[world.marek_id]
	if marek.alive:
		assert(world.ashfields_commit_gate(0) != "", "the Library cannot sponsor while Marek holds the desk")
		marek.alive = false  # rig the Year-Four death without touching any stream
	assert(world.ashfields_commit_gate(0) == "", "Thessaly free to lead → the framework may begin")
	var commit := world.ashfields_commit_framework(0)
	assert(commit.contains("begun"), "the work he could not ask for has begun")
	assert(int(world.ashfields["framework_stage"]) == 1, "stage 1: political coordination")
	world.realms[0].gold = 500.0
	var pellar := world._map_realm_named("Pellar")
	var halven := world._map_realm_named("Halven")
	var saren := world._map_realm_named("Saren-Vesh")
	assert(world.ashfields_seek_endorsement(pellar, 0).contains("declines"),
		"Eithne of Pellar declines — a Zealous crown does not seal the Returned's charter, Library or no")
	assert(world.ashfields_seek_endorsement(halven, 0).contains("seal"), "Ferren of Halven endorses (Gregarious)")
	assert(world.ashfields_seek_endorsement(saren, 0).contains("seal"), "Vessa of Saren-Vesh endorses (Methodical)")
	assert((world.ashfields["endorsements"] as Array).size() >= 3, "three seals gathered, the crown's own included")
	for i in 14:
		world.advance_month()
	assert(int(world.ashfields["framework_stage"]) == 2, "stage 2: the drafting council convenes")
	for i in 20:
		world.advance_month()
	assert(int(world.ashfields["framework_stage"]) == 3 and str(world.ashfields["resolved"]) == "framework",
		"the finding is published")
	assert(float(world.ashfields["anchored"]) > 0.0, "Returned in early stages receive the anchor retroactively")
	var caeris_after: SimCharacter = world.characters[world.caeris_id]
	assert(caeris_after.alive, "Caeris gains a purpose beyond waiting")
	var anchored_before := float(world.ashfields["anchored"])
	var recently_before := float(world.ashfields["recently"])
	world.advance_month()
	assert(float(world.ashfields["anchored"]) > anchored_before, "new intake Returns under the framework")
	assert(float(world.ashfields["recently"]) <= recently_before, "no one new enters the settling track")
	var thessaly: SimCharacter = world.characters[world.thessaly_id]
	assert(thessaly.traits.has("Focused"), "the Chief Archivist's desk makes her Focused (tick-44 beat)")
	print("consent framework: envoy → sponsorship → 3 seals → council → published; %d anchored" % int(world.ashfields["anchored"]))

	# --- 5. the military option loses the finding (doc §6) ---
	var w2 := SimWorld.new()
	w2.auto_resolve_events = true
	w2.setup()
	var army: SimWorld.Army = w2.main_army_of(0)
	assert(army != null, "the realm musters at setup")
	army.regiments = []
	for i in 10:
		army.regiments.append({"kind": "sword", "soldiers": 36, "max": 36})
	for i in 4:
		army.regiments.append({"kind": "vael_arcane_retinue", "soldiers": 24, "max": 24})
	for i in 4:
		army.regiments.append({"kind": "vigil_sworn_elite", "soldiers": 24, "max": 24})
	var orth_before := float(w2.faiths["Aelindran Orthodox"]["coherence"])
	var w2_ruler: SimCharacter = w2.characters[w2.realms[0].ruler_id]
	var corruption_before := w2_ruler.corruption
	var verdict := w2.ashfields_march(0)
	assert(verdict.contains("falls"), "eighteen picked regiments carry the grey country: %s" % verdict)
	assert(str(w2.ashfields["resolved"]) == "destroyed", "the Ashfields is destroyed")
	var caeris2: SimCharacter = w2.characters[w2.caeris_id]
	assert(not caeris2.alive, "Caeris dies — and the anchor working dies with him")
	assert(float(w2.ashfields["dispersed"]) > 400.0, "the Returned disperse, undirected")
	assert(float(w2.faiths["Aelindran Orthodox"]["coherence"]) > orth_before,
		"the destruction of heresy reads as orthodox victory")
	assert(w2_ruler.corruption > corruption_before, "the crown carries the ethical weight")
	assert(w2.ashfields_commit_gate(0) != "", "there is nothing left to build")
	print("military option: achievable, and the finding is lost — corruption %.1f, dispersed %d" % [
		w2_ruler.corruption, int(w2.ashfields["dispersed"])])

	# --- 6. the Forsaken organize by stages (doc §8) ---
	for i in 70:
		world.advance_month()  # world is at ~tick 60 → past tick 130
	var any_stage2 := false
	for region in world.forsaken_movements:
		var mv: Dictionary = world.forsaken_movements[region]
		assert(float(mv["strength"]) > 0.0, "%s movement grows" % region)
		assert(int(mv["stage"]) >= 1, "%s past the whispered threshold by Year 10" % region)
		if int(mv["stage"]) >= 2:
			any_stage2 = true
	assert(any_stage2, "at least one movement is organizing openly")
	assert(world.recruit_gate(0, "forsaken_militia") != "", "no militia below regional dominance")
	world.forsaken_movements["vael"]["strength"] = 600.0
	assert(world.recruit_gate(0, "forsaken_militia") == "", "dominance (500+) opens the muster")
	assert(world.forsaken_status_line().contains("Forsaken"), "the status line reads the movements")
	print("Forsaken: five regional variants growing, stage events firing, militia gated on dominance")

	# --- 7. the Year-50 convergence names an ending (doc §9) ---
	world.tick = SimWorld.CONVERGENCE_TICK
	world.central_secret_state = "revealed"
	world._silence_made_tick()
	assert(world.convergence in ["unified", "military", "ideological", "fragmented"],
		"the convergence resolves to a named shape, got '%s'" % world.convergence)
	print("convergence: Year 50 resolves as '%s' (full cascade deferred to the endgame module)" % world.convergence)

	# --- 8. the Silence-made stream is deterministic and self-contained ---
	var wa := SimWorld.new()
	wa.auto_resolve_events = true
	wa.setup()
	var wb := SimWorld.new()
	wb.auto_resolve_events = true
	wb.setup()
	for i in 12:
		wa.advance_month()
		wb.advance_month()
	assert(absf(wa.ashfields_population() - wb.ashfields_population()) < 0.001,
		"identical worlds grow identical Ashfields — srng is deterministic")
	assert(absf(float(wa.forsaken_movements["vael"]["strength"]) - float(wb.forsaken_movements["vael"]["strength"])) < 0.001,
		"and identical movements")
	print("determinism: two worlds, twelve months, identical grey countries")

	print("\nALL SILENCE-MADE CHECKS PASSED")
	quit(0)
