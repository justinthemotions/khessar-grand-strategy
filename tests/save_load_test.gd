extends SceneTree

## The Save & Menu pass: a saved reign must come back EXACTLY — same
## souls, same ledgers, same dice mid-roll — and then advance
## bit-identically to a world that never left memory. Run:
##   <godot.exe> --headless --path . --script res://tests/save_load_test.gd

const SLOT_A := "__test_a"
const SLOT_B := "__test_b"


func _init() -> void:
	print("=== save/load test (Save & Menu pass) ===")

	# --- group 1: exact round-trip at tick 30 ---
	var wa := SimWorld.new()
	wa.auto_resolve_events = true
	wa.setup()
	for i in 30:
		wa.advance_month()
	var err := SaveLoad.save_game(wa, SLOT_A)
	assert(err == "", "the save must succeed (got: %s)" % err)
	var path_a := SaveLoad.slot_path(SLOT_A)
	assert(FileAccess.file_exists(path_a), "the save file must exist on disk")
	print("saved tick-30 world: %d bytes" % FileAccess.get_file_as_bytes(path_a).size())

	var wb := SaveLoad.load_game(path_a)
	assert(wb != null, "the save must load back")
	assert(wb.tick == wa.tick, "tick must round-trip (%d vs %d)" % [wb.tick, wa.tick])
	assert(wb.characters.size() == wa.characters.size(),
		"every soul returns (%d vs %d)" % [wb.characters.size(), wa.characters.size()])
	assert(wb.rng.state == wa.rng.state and wb.grng.state == wa.grng.state \
		and wb.wrng.state == wa.wrng.state and wb.urng.state == wa.urng.state,
		"the dice must resume mid-roll — every stream's state round-trips")
	var diffs: Array = []
	_diff(SaveLoad._encode_obj(wa, "world"), SaveLoad._encode_obj(wb, "world"), "world", diffs)
	assert(diffs.is_empty(), "the round-trip must be exact; first diffs: %s" % str(diffs))
	print("round-trip: %d characters, %d provinces, every field identical" % [
		wb.characters.size(), wb.map.provinces.size()])

	# --- group 2: a loaded world advances bit-identically ---
	for i in 24:
		wa.advance_month()
		wb.advance_month()
	diffs.clear()
	_diff(SaveLoad._encode_obj(wa, "world"), SaveLoad._encode_obj(wb, "world"), "world", diffs)
	assert(diffs.is_empty(),
		"24 months after loading, the histories must not have diverged; first diffs: %s" % str(diffs))
	assert(wb.famine_deaths_total == wa.famine_deaths_total and wb.wren_tokens == wa.wren_tokens,
		"the famine ledger and the Wren's tokens agree after the shared march")
	print("determinism: ticks %d, famine dead %d, wren tokens %d — histories identical" % [
		wb.tick, wb.famine_deaths_total, wb.wren_tokens])

	# --- group 3: metadata, listing, and Continue's choice ---
	var meta := SaveLoad.read_meta(path_a)
	assert(int(meta.get("version", -1)) == SaveLoad.SAVE_VERSION, "the meta carries a version")
	assert(int(meta.get("tick", -1)) == 30, "the meta remembers tick 30 without loading the world")
	assert(str(meta.get("realm", "")) != "", "the meta names the realm")
	var err_b := SaveLoad.save_game(wb, SLOT_B)
	assert(err_b == "", "the second save must succeed (got: %s)" % err_b)
	assert(SaveLoad.latest_save() == SaveLoad.slot_path(SLOT_B),
		"Continue picks the newest page of the chronicle")
	var listed_test := 0
	for entry: Dictionary in SaveLoad.list_saves():
		if str(entry["path"]).contains("__test_"):
			listed_test += 1
	assert(listed_test == 2, "both test saves appear in the load list (got %d)" % listed_test)
	print("meta: %s under %s, saved %s — latest_save picks slot B" % [
		str(meta.get("date")), str(meta.get("ruler")), str(meta.get("saved_text"))])

	# --- group 4: the Callable gate — no saving mid-decision ---
	var wc := SimWorld.new()
	wc.setup()  # auto_resolve stays false: realm-0 events queue for the player
	var ruler_id: int = wc.realms[0].ruler_id
	wc.raise_event(0, ruler_id, "A Test of the Scribes", "The ledger cannot close mid-sentence.",
		[{"label": "So be it", "effect": func() -> void: pass}])
	assert(not wc.pending_events.is_empty(), "the staged event must be pending")
	var err_c := SaveLoad.save_game(wc, "__test_pending")
	assert(err_c != "", "saving with a pending decision must be refused")
	assert(not FileAccess.file_exists(SaveLoad.slot_path("__test_pending")),
		"no file may be written for a refused save")
	print("callable gate: refused with '%s'" % err_c)

	SaveLoad.delete_save(SaveLoad.slot_path(SLOT_A))
	SaveLoad.delete_save(SaveLoad.slot_path(SLOT_B))
	assert(SaveLoad.load_game(SaveLoad.slot_path(SLOT_A)) == null, "a deleted save is gone")

	print("ALL SAVE/LOAD CHECKS PASSED")
	quit()


func _diff(a: Variant, b: Variant, path: String, out: Array) -> void:
	## Reports the first dozen divergent paths — assert-friendly diagnostics.
	if out.size() >= 12:
		return
	if typeof(a) != typeof(b):
		out.append("%s: type %s vs %s" % [path, type_string(typeof(a)), type_string(typeof(b))])
		return
	if a is Dictionary:
		for k: Variant in a:
			if not (b as Dictionary).has(k):
				out.append("%s.%s: missing in b" % [path, str(k)])
			else:
				_diff(a[k], b[k], "%s.%s" % [path, str(k)], out)
		for k: Variant in b:
			if not (a as Dictionary).has(k):
				out.append("%s.%s: missing in a" % [path, str(k)])
		return
	if a is Array:
		if (a as Array).size() != (b as Array).size():
			out.append("%s: size %d vs %d" % [path, (a as Array).size(), (b as Array).size()])
			return
		for i in (a as Array).size():
			_diff(a[i], b[i], "%s[%d]" % [path, i], out)
		return
	if a != b:
		out.append("%s: %s vs %s" % [path, str(a).left(60), str(b).left(60)])
