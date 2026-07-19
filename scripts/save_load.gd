class_name SaveLoad
extends RefCounted

## Save/load for the campaign (the Save & Menu pass).
##
## The whole reign lives on SimWorld as script variables, and every
## cross-reference is an integer id, never an object pointer (the
## contract character.gd has carried since Module 1) — so a save is a
## reflective walk over those variables. Three things need care:
##  - RandomNumberGenerator streams: seed + state round-trip exactly,
##    so a loaded history rolls the same dice it always would have.
##  - The map: geometry and adjacency are deterministic from the map
##    seed; only the mutable per-province fields (owner, pop, culture,
##    ...) are stored and re-applied over a fresh generate().
##  - pending_events hold Callables (option effects) and cannot cross
##    a save file — saving is refused while a decision awaits the
##    player, and the UI says so.
##
## Format: one FileAccess.store_var metadata dict (readable without
## loading the world), then one store_var payload dict. Binary, exact
## float round-trip — a loaded world advances bit-identically to one
## that never left memory (asserted in tests/save_load_test.gd).

const SAVE_DIR := "user://saves"
const SAVE_EXT := ".ks"
const SAVE_VERSION := 1


# ---------------------------------------------------------------- API

static func slot_path(slot: String) -> String:
	return SAVE_DIR + "/" + slot + SAVE_EXT


static func save_game(world: SimWorld, slot: String) -> String:
	## Returns "" on success, else the reason the scribes refused.
	return save_to_path(world, slot_path(slot))


static func save_to_path(world: SimWorld, path: String) -> String:
	if not world.pending_events.is_empty():
		return "a decision awaits the crown — the ledger cannot close mid-sentence."
	var dir := path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "cannot write %s (%s)." % [path, error_string(FileAccess.get_open_error())]
	f.store_var(_meta_for(world))
	f.store_var(_encode_obj(world, "world"))
	f.close()
	return ""


static func load_game(path: String) -> SimWorld:
	## Returns the restored world, or null if the file is missing/foreign.
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var meta: Variant = f.get_var()
	if not (meta is Dictionary) or int((meta as Dictionary).get("version", -1)) > SAVE_VERSION:
		f.close()
		return null
	var data: Variant = f.get_var()
	f.close()
	if not (data is Dictionary) or str((data as Dictionary).get("__t", "")) != "world":
		return null
	var w := SimWorld.new()
	_decode_into(w, data)
	return w


static func read_meta(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var meta: Variant = f.get_var()
	f.close()
	return meta if meta is Dictionary else {}


static func list_saves() -> Array:
	## [{path, meta}] sorted newest first.
	var out: Array = []
	var d := DirAccess.open(SAVE_DIR)
	if d == null:
		return out
	for fname in d.get_files():
		if not fname.ends_with(SAVE_EXT):
			continue
		var path := SAVE_DIR + "/" + fname
		var meta := read_meta(path)
		if not meta.is_empty():
			out.append({"path": path, "meta": meta})
	out.sort_custom(func(a, b) -> bool:
		return float(a["meta"].get("saved_unix", 0.0)) > float(b["meta"].get("saved_unix", 0.0)))
	return out


static func latest_save() -> String:
	var saves := list_saves()
	return "" if saves.is_empty() else str(saves[0]["path"])


static func delete_save(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _meta_for(world: SimWorld) -> Dictionary:
	var ruler := ""
	if not world.realms.is_empty():
		var r: SimWorld.Realm = world.realms[0]
		if world.characters.has(r.ruler_id):
			ruler = world.full_name(world.characters[r.ruler_id])
	return {
		"version": SAVE_VERSION,
		"tick": world.tick,
		"date": world.date_string(),
		"realm": "" if world.realms.is_empty() else str(world.realms[0].name),
		"ruler": ruler,
		"saved_unix": Time.get_unix_time_from_system(),
		"saved_text": Time.get_datetime_string_from_system(false, true),
	}


# ---------------------------------------------------------------- encode

static func _encode_obj(o: Object, tag: String) -> Dictionary:
	var d := {"__t": tag}
	for prop in o.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			d[prop["name"]] = _encode(o.get(prop["name"]))
	return d


static func _encode(v: Variant) -> Variant:
	if v is RandomNumberGenerator:
		return {"__t": "rng", "s": v.seed, "st": v.state}
	if v is SimCharacter:
		return _encode_obj(v, "char")
	if v is SimWorld.Dynasty:
		return _encode_obj(v, "dyn")
	if v is SimWorld.Realm:
		return _encode_obj(v, "realm")
	if v is SimWorld.Army:
		return _encode_obj(v, "army")
	if v is WorldMap:
		return _encode_map(v)
	if v is Callable or v is Signal:
		push_warning("SaveLoad: a Callable/Signal reached the encoder — dropped.")
		return null
	if v is Array:
		var out: Array = []
		for e in v:
			out.append(_encode(e))
		return out
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[k] = _encode(v[k])
		return out
	return v


static func _encode_map(m: WorldMap) -> Dictionary:
	# Geometry, adjacency, duchies and MapRealm records all rebuild
	# deterministically from the seed; only province fields mutate in play.
	var provs: Array = []
	for p: WorldMap.Province in m.provinces:
		var d := {}
		for prop in p.get_property_list():
			var n: String = prop["name"]
			if (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) \
					and n != "polygon" and n != "center" and n != "neighbors":
				d[n] = p.get(n)
		provs.append(d)
	return {"__t": "map", "seed": m.seed_used, "provinces": provs}


# ---------------------------------------------------------------- decode

static func _decode_into(o: Object, d: Dictionary) -> void:
	for prop in o.get_property_list():
		var n: String = prop["name"]
		if (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) and d.has(n):
			o.set(n, _decode(d[n], o.get(n)))


static func _decode(v: Variant, template: Variant = null) -> Variant:
	if v is Dictionary and (v as Dictionary).has("__t"):
		var d: Dictionary = v
		match str(d["__t"]):
			"rng":
				var r := RandomNumberGenerator.new()
				r.seed = int(d["s"])   # seed first: assigning it resets state
				r.state = int(d["st"])
				return r
			"char":
				var c := SimCharacter.new()
				_decode_into(c, d)
				return c
			"dyn":
				var dy := SimWorld.Dynasty.new(int(d.get("id", 0)), str(d.get("name", "")))
				_decode_into(dy, d)
				return dy
			"realm":
				var rm := SimWorld.Realm.new(int(d.get("id", 0)), str(d.get("name", "")))
				_decode_into(rm, d)
				return rm
			"army":
				var a := SimWorld.Army.new()
				_decode_into(a, d)
				return a
			"map":
				return _decode_map(d)
	if v is Array:
		var out: Array = []
		for e in v:
			out.append(_decode(e))
		if template is Array and (template as Array).is_typed():
			var t: Array = template
			return Array(out, t.get_typed_builtin(), t.get_typed_class_name(), t.get_typed_script())
		return out
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[k] = _decode(v[k])
		return out
	return v


static func _decode_map(d: Dictionary) -> WorldMap:
	var m := WorldMap.new()
	m.generate(int(d.get("seed", 777)))
	var provs: Array = d.get("provinces", [])
	for i in mini(provs.size(), m.provinces.size()):
		var p: WorldMap.Province = m.provinces[i]
		var fields: Dictionary = provs[i]
		for k: Variant in fields:
			p.set(str(k), fields[k])
	return m
