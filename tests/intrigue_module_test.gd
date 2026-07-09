extends SceneTree

## Module 6 test: Intrigue, Secrets & Subterfuge and its expansions —
## secrets & hooks, phased component plots, the strike window, double
## agents, minor schemes (seduction/abduction/slander), the apothecary,
## and mithridatization. Run from the project folder:
##   <godot.exe> --headless --path . --script res://tests/intrigue_module_test.gd

func _init() -> void:
	var world := SimWorld.new()
	var events: Array = []
	world.event_logged.connect(func(t: String) -> void: events.append(t))
	world.setup()
	world.auto_resolve_events = true

	var vael: SimWorld.Realm = world.realms[0]
	var karn: SimWorld.Realm = world.realms[1]
	var karn_ruler: SimCharacter = world.characters[karn.ruler_id]

	# --- 1. secrets & ferreting: the informants earn their keep ---
	world._add_secret(karn_ruler.id, "bastard blood")
	vael.gold = 1000.0
	var f_err := world.start_ferreting(0)
	assert(f_err == "", "ferreting failed to start: " + f_err)
	var dug := 0
	while not world.has_hook(0, karn_ruler.id) and dug < 60:
		world._ferret_tick()
		if not world.ferreting.has(0) and not world.has_hook(0, karn_ruler.id):
			var _f2 := world.start_ferreting(0)  # the well was dry; dig again
		dug += 1
	assert(world.has_hook(0, karn_ruler.id), "ferreting never uncovered the seeded secret")
	print("ferreting ok — the secret surfaced after %d months of listening" % dug)

	# --- 2. hooks: weak spends, strong persists ---
	var spent := world._spend_hook(0, karn_ruler.id)
	assert(spent, "an unspent hook must be spendable")
	assert(not world.has_hook(0, karn_ruler.id), "a weak hook must spend on use")
	world._gain_hook(0, karn_ruler.id, "strong", "a murderer's hand")
	var _s1 := world._spend_hook(0, karn_ruler.id)
	assert(world.has_hook(0, karn_ruler.id), "a strong hook must survive being used")
	print("hooks ok — weak spends, strong is a lifetime of leverage")

	# --- 3. the hooked Curia: a vote in the crown's pocket ---
	var ruler0: SimCharacter = world.characters[vael.ruler_id]
	var lords: Array = []
	for c in world.characters.values():
		var cc: SimCharacter = c
		if cc.alive and cc.realm_id == 0 and cc.age_years(world.tick) >= 16 \
				and not cc.denounced and cc.id != vael.ruler_id:
			lords.append(cc)
		if lords.size() >= 3:
			break
	assert(lords.size() >= 3, "the curia test needs three lords")
	var pids: Array = []
	for p in world.map.provinces:
		if p.owner == 0 and world.county_holder(p.id) == null:
			pids.append(p.id)
		if pids.size() >= 3:
			break
	for i in 3:
		var lord: SimCharacter = lords[i]
		var g_err: String = world.grant_title("county", pids[i], lord.id)
		assert(g_err == "", "grant failed: " + g_err)
		lord.traits.assign(["Honest"] as Array[String])  # Constitutionalists: against war
		lord.memories.clear()  # no gratitude, no grudges — ideology votes alone
		world.contract_of(lord.id)["tax"] = "harsh"  # and sour terms keep loyalty at bay
	vael.tyranny = 0.0
	var vote: Dictionary = world.curia_vote(0, "war")
	assert(not bool(vote["passed"]), "three sour Constitutionalists must vote a war down (got %s)" % str(vote))
	world._gain_hook(0, lords[0].id, "weak", "bastard blood")
	world._gain_hook(0, lords[1].id, "weak", "bastard blood")
	vote = world.curia_vote(0, "war")
	assert(bool(vote["passed"]), "two hooked lords must swing the vote (got %s)" % str(vote))
	assert(not world.has_hook(0, lords[0].id), "a weak hook forced into a vote is spent")
	print("hooked curia ok — the war carried on blackmail alone")

	# --- 4. hooks mandate contract changes without tyranny ---
	world._gain_hook(0, lords[2].id, "weak", "bastard blood")
	var tyr_before: float = vael.tyranny
	var mem_count: int = lords[2].memories.size()
	var hc_err := world.hook_force_contract(0, lords[2].id, "tax", "harsh")
	assert(hc_err == "", "hook_force_contract failed: " + hc_err)
	assert(str(world.contract_of(lords[2].id)["tax"]) == "harsh", "the term must change")
	assert(vael.tyranny == tyr_before, "blackmail must add no tyranny")
	assert(lords[2].memories.size() == mem_count, "blackmail must leave no grudge memory")
	print("hooked contract ok — harsh terms signed without a word")

	# --- 5. the anatomy of a trap: phases assemble the components ---
	var victim: SimCharacter = null
	for c in world.characters.values():
		var cc2: SimCharacter = c
		if cc2.alive and cc2.realm_id == 1 and cc2.id != karn.ruler_id and cc2.age_years(world.tick) >= 16:
			victim = cc2
			break
	assert(victim != null, "no victim available at the Karn-Vol court")
	karn.gold = 0.0  # Sarova's spymaster sits this one out — no counter-plots mid-test
	var p_err := world.start_plot(0, victim.id)
	assert(p_err == "", "start_plot failed: " + p_err)
	var saw_asset := false
	var saw_vector := false
	var months := 0
	while vael.plot_progress >= 0.0 and months < 80:
		world._plots_tick()
		var details: Dictionary = world.plot_details.get(0, {})
		if details.has("asset_id"):
			saw_asset = true
		if details.has("vector"):
			saw_vector = true
		months += 1
	assert(vael.plot_progress < 0.0, "the plot never resolved")
	assert(saw_asset, "Phase 2 must subvert an inside asset")
	assert(saw_vector, "Phase 3 must secure a vector")
	var traced := false
	for e in events:
		if str(e).contains("whispers of poison") or str(e).contains("uncovered"):
			traced = true
	assert(traced, "the strike must leave a trace in the chronicle")
	print("plot anatomy ok — asset bought, vector secured, resolved in %d months" % months)

	# --- 6. the strike window is the player's to choose ---
	world.auto_resolve_events = false
	var victim2: SimCharacter = null
	for c in world.characters.values():
		var cc3: SimCharacter = c
		if cc3.alive and cc3.realm_id == 1 and cc3.id != karn.ruler_id and cc3.age_years(world.tick) >= 16:
			victim2 = cc3
			break
	assert(victim2 != null, "no second victim available")
	vael.plot_target_id = victim2.id
	vael.plot_progress = 99.0
	vael.plot_warned = true  # skip the detection roll for this check
	world.plot_details[0] = {"vector": "nightshade", "asset_id": victim2.id, "asset_role": "cupbearer"}
	world._plots_tick()
	assert(world.pending_events.size() >= 1, "a ready trap must ask the player for the trigger")
	var trap_ev: Dictionary = world.pending_events[world.pending_events.size() - 1]
	assert(str(trap_ev["title"]) == "The Trap Is Set", "wrong event raised: %s" % str(trap_ev["title"]))
	world.resolve_event(int(trap_ev["id"]), 0)  # strike now
	assert(vael.plot_progress < 0.0, "striking must resolve the plot")
	print("strike window ok — the trigger waited for the crown's word")

	# --- 7. the double game: their poison, their cup ---
	karn.plot_target_id = ruler0.id
	karn.plot_progress = 100.0
	world.plot_details[1] = {"vector": "nightshade", "asset_id": ruler0.id,
		"asset_role": "cupbearer", "double_agent": true}
	world._plot_strike(karn, ruler0)
	assert(world.pending_events.size() >= 1, "a turned plot must hand the defender the ending")
	var sw_ev: Dictionary = world.pending_events[world.pending_events.size() - 1]
	assert(str(sw_ev["title"]) == "The Double Game Closes", "wrong event: %s" % str(sw_ev["title"]))
	world.resolve_event(int(sw_ev["id"]), 0)  # the Switcheroo
	assert(not karn_ruler.alive, "the plotter must drink their own vintage")
	assert(ruler0.alive, "the intended victim toasts their health")
	print("switcheroo ok — %s died at their own feast" % world.full_name(karn_ruler))
	world.auto_resolve_events = true
	for i in 6:
		world.advance_month()  # let Karn-Vol crown a new chief
	var karn_ruler2: SimCharacter = world.characters.get(karn.ruler_id)

	# --- 8. the apothecary lab and its custom brews ---
	vael.gold = 1000.0
	# a small Year Zero court may hold no one bookish enough — school one
	for c in world.characters.values():
		var cc7: SimCharacter = c
		if cc7.alive and cc7.realm_id == 0 and cc7.age_years(world.tick) >= 16 \
				and cc7.id != vael.ruler_id and world.counties_of(cc7.id).is_empty() \
				and not world._on_council(0, cc7.id):
			cc7.learning = maxi(cc7.learning, 12)
			break
	var a_err := world.establish_apothecary(0)
	assert(a_err == "", "apothecary failed: " + a_err)
	assert(vael.apothecary and vael.alchemist_id >= 0, "the lab needs an alchemist")
	assert(world.set_plot_vector(0, "slow_weep") == "", "the lab must brew the Slow Weep")
	assert(world.set_plot_vector(1, "mad_mind") != "", "no lab, no custom toxins")
	print("apothecary ok — %s tends the stills" % world.full_name(world.characters[vael.alchemist_id]))

	# --- 9. the Slow Weep, delivered by a turned asset (deterministic path) ---
	world.auto_resolve_events = false
	if karn_ruler2 != null and karn_ruler2.alive:
		karn.plot_target_id = ruler0.id
		karn.plot_progress = 100.0
		world.plot_details[1] = {"vector": "slow_weep", "asset_id": ruler0.id,
			"asset_role": "food taster", "double_agent": true}
		world._plot_strike(karn, ruler0)
		var sw2: Dictionary = world.pending_events[world.pending_events.size() - 1]
		world.resolve_event(int(sw2["id"]), 0)
		assert(karn_ruler2.alive, "the Slow Weep does not kill outright")
		assert(karn_ruler2.traits.has("Wasting"), "the Slow Weep must leave the Wasting trait")
		print("slow weep ok — %s fades like consumption, and no one suspects" % world.full_name(karn_ruler2))
	world.auto_resolve_events = true

	# --- 10. mithridatization: a thousand small deaths ---
	var m_err := world.toggle_mithridatism(0)
	assert(m_err == "", "mithridatism failed to start: " + m_err)
	for i in SimWorld.MITHRIDATIC_MONTHS + 2:
		world._mithridatism_tick()
	assert(ruler0.traits.has("Mithridatic"), "two years of doses must grant Mithridatic")
	print("mithridatism ok — no cup can kill %s now" % world.full_name(ruler0))

	# --- 11. minor schemes: seduction, slander, abduction ---
	# seduction: the affair becomes a strong hook
	var mark: SimCharacter = null
	for c in world.characters.values():
		var cc4: SimCharacter = c
		if cc4.alive and cc4.realm_id == 1 and cc4.age_years(world.tick) >= 16 \
				and not world._close_kin(ruler0, cc4) and not world.wards.has(cc4.id):
			mark = cc4
			break
	assert(mark != null, "no one at the Karn-Vol court to seduce")
	var ms_err := world.start_minor_scheme(0, "seduce", mark.id)
	assert(ms_err == "", "seduction failed to start: " + ms_err)
	world.minor_schemes[0]["checked"] = true  # this check is about the payoff, not the risk
	var wove := 0
	while not world.minor_schemes.is_empty() and wove < 40:
		world._minor_schemes_tick()
		wove += 1
	assert(world.has_hook(0, mark.id), "a seduction must end in a strong hook")
	print("seduction ok — %s writes letters in unmarked hands" % world.full_name(mark))

	# slander — the False Lineage
	var smear: SimCharacter = world.heir_of(1)
	if smear == null or smear.age_years(world.tick) < 16 or world.wards.has(smear.id):
		smear = mark
	var sl_err := world.start_minor_scheme(0, "slander_lineage", smear.id)
	assert(sl_err == "", "slander failed to start: " + sl_err)
	for s in world.minor_schemes:
		if int(s["realm"]) == 0:
			s["checked"] = true
	wove = 0
	while not world.minor_schemes.is_empty() and wove < 40:
		world._minor_schemes_tick()
		wove += 1
	assert(smear.slandered, "the forged pages must stick")
	var expected_legit: int = clampi(40 + smear.diplomacy
		- 15 * world._claimants_against(karn, smear).size()
		+ (5 if smear.traits.has("Gregarious") else 0) - 25, 5, 95)
	var saved_ir: Dictionary = karn.interregnum
	world._begin_interregnum(karn, smear, false)
	assert(int(karn.interregnum["legitimacy"]) == expected_legit,
		"a slandered heir must open the interregnum 25 legitimacy short")
	karn.interregnum = saved_ir
	print("false lineage ok — %s would be crowned under a cloud (legitimacy %d)" % [
		world.full_name(smear), expected_legit])

	# abduction: the target reappears under guard
	var prize: SimCharacter = null
	for c in world.characters.values():
		var cc5: SimCharacter = c
		if cc5.alive and cc5.realm_id == 1 and cc5.age_years(world.tick) >= 16 and not world.wards.has(cc5.id):
			prize = cc5
			break
	assert(prize != null, "no one left at Karn-Vol to abduct")
	var ab_err := world.start_minor_scheme(0, "abduct", prize.id)
	assert(ab_err == "", "abduction failed to start: " + ab_err)
	for s in world.minor_schemes:
		if int(s["realm"]) == 0:
			s["checked"] = true
	wove = 0
	while not world.minor_schemes.is_empty() and wove < 40:
		world._minor_schemes_tick()
		wove += 1
	assert(world.wards.has(prize.id) and bool(world.wards[prize.id]["hostage"]), "the abducted become hostages")
	assert(prize.realm_id == 0, "the abducted live under the abductor's guard")
	print("abduction ok — %s vanished from one court and surfaced at another" % world.full_name(prize))

	# --- 12. the world keeps turning with the whole web wired in ---
	for i in 120:
		world.advance_month()
	var alive := 0
	for c in world.characters.values():
		var cc6: SimCharacter = c
		if cc6.alive:
			alive += 1
	assert(alive > 0, "the world must survive ten years of the new intrigue")
	print("10-year soak ok — %d alive, %d events, %d resolved by AI, %d secrets on record" % [
		alive, events.size(), world.events_resolved_by_ai, world.secrets.size()])

	print("\nALL INTRIGUE CHECKS PASSED")
	quit(0)
