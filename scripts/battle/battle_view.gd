class_name BattleView
extends Control

## Full-screen battle overlay: pixel-style soldier sprites in formation,
## floating banners with HP and morale bars, a unit panel bottom-left,
## and speed controls top-right. Left-click selects a regiment,
## right-click orders your (blue, side 0) regiments to move.
## A Total War-style card bar runs along the bottom: the commander's
## hero card, then one card per regiment — men remaining over a green
## strength band, morale and ammunition strips, the unit's own pixel
## soldier as a portrait, and an archetype glyph in the bottom notch.
## Cards click to select, exactly like clicking the field.

signal finished(winner_side: int, loser_loss_fraction: float)

const GRASS_BASE := Color("4a6238")
const GRASS_DARK := Color("41573180")
const GRASS_LIGHT := Color("57724280")
const ROCK := Color("7b7a72")
const TREE := Color("32452a")
const SKIN := Color("caa07a")
const HELMET := Color("9a9a94")
const HORSE := Color("5f4630")
const GOLD := Color("d9c07a")
const HP_COLOR := Color("4f9e3c")
const MORALE_COLOR := Color("d9b13a")
const Appearance = preload("res://scripts/portrait_appearance.gd")

# The card bar (TW-style unit cards along the bottom edge)
const AMMO_COLOR := Color("d97b2f")
const CARD_BG := Color("221d16")
const CARD_BAND := Color("14110c")
const CARD_INK := Color("d9c07a")
const CARD_W := 54.0
const CARD_H := 88.0
const CARD_GAP := 5.0
const BAR_PAD := 8.0
const CAMERA_MIN_ZOOM := 0.80
const CAMERA_MAX_ZOOM := 3.25
const CAMERA_ZOOM_STEP := 1.16
const CAMERA_PAN_PX_PER_SEC := 520.0
const CASUALTY_LIFETIME := 0.85
const MAX_FALLEN_SPRITES := 96
const ATTACK_CYCLE_PER_SECOND := 1.65

var sim := BattleSim.new()
var side_names: Array = ["Aldmark", "Sarova"]
var side_colors: Array = [Color("3f5f83"), Color("8c4a3f")]
var battle_title := "The Battle"
var speed_scale := 1.0
var selected_id := -1
var tick_accum := 0.0
var over := false

var patches: Array = []       # seeded decorative grass/rock patches
var dragging := false         # right-drag draws the new battle line
var drag_start := Vector2.ZERO
var mouse_now := Vector2.ZERO
var arrows: Array = []        # animated volleys consumed from the sim
var title_label: Label
var unit_panel: PanelContainer
var unit_name: Label
var unit_status: Label
var unit_stats: Label
var end_box: CenterContainer
var tactic_buttons: Dictionary = {}   # kind -> Button (the Battle Grid's command cards)
var commander_selected := false       # the hero card is clicked — the panel shows him
var ammo_start: Dictionary = {}       # regiment id -> starting ammunition (the orange strip)
# Hero System v1.0: the hero's spell bar and targeted casting
var hero_bar: HBoxContainer = null    # built lazily once sim.heroes[0] is set
var hero_buttons: Dictionary = {}     # ability id -> Button
var hero_actors: Array = [null, null] # independent HeroActor2D visual adapters
var pending_ability := ""             # a working awaiting its target on the field
var spell_fx: Array = []              # consumed sim.casts, animated locally
var camera_center := Vector2.ZERO
var camera_zoom := 1.0
var battle_time := 0.0
var visual_soldier_counts: Dictionary = {}  # regiment id -> last synchronized strength
var fallen_soldiers: Array = []             # brief local death/fall animations


func start(roster_a: Array, roster_b: Array, lead_a: int, lead_b: int,
		p_side_names: Array, p_side_colors: Array, p_title: String,
		cmdr_traits_a: Array = [], cmdr_traits_b: Array = [], terrain: String = "plains",
		ground: Dictionary = {}) -> void:
	side_names = p_side_names
	side_colors = p_side_colors
	battle_title = p_title
	sim.setup_from_rosters(roster_a, roster_b, lead_a, lead_b, side_names, cmdr_traits_a, cmdr_traits_b, terrain, ground)
	camera_center = sim.field * 0.5
	camera_zoom = 1.0
	battle_time = 0.0
	visual_soldier_counts.clear()
	fallen_soldiers.clear()
	ammo_start.clear()
	for r: BattleSim.Regiment in sim.regiments:
		visual_soldier_counts[r.id] = r.soldiers
		if r.ammo > 0:
			ammo_start[r.id] = r.ammo
	sim.battle_ended.connect(_on_battle_ended)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 240:
		patches.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"size": rng.randf_range(3.0, 14.0),
			"kind": rng.randi_range(0, 10),
		})

	title_label = Label.new()
	title_label.text = battle_title
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title_label.offset_left = -220.0
	title_label.offset_right = 220.0
	title_label.offset_top = 10.0
	title_label.offset_bottom = 42.0
	add_child(title_label)

	var speed_bar := HBoxContainer.new()
	speed_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	speed_bar.offset_left = -240.0
	speed_bar.offset_right = -12.0
	speed_bar.offset_top = 10.0
	speed_bar.offset_bottom = 48.0
	speed_bar.add_theme_constant_override("separation", 6)
	for cfg in [["Pause", 0.0], ["Play", 1.0], ["Fast", 2.5]]:
		var b := Button.new()
		b.text = cfg[0]
		var scale_value: float = cfg[1]
		b.pressed.connect(func() -> void: speed_scale = scale_value)
		speed_bar.add_child(b)
	add_child(speed_bar)

	unit_panel = PanelContainer.new()
	unit_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	unit_panel.offset_left = 12.0
	unit_panel.offset_top = -388.0
	unit_panel.offset_right = 244.0
	unit_panel.offset_bottom = -128.0  # clears the card bar below
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	unit_panel.add_child(box)
	unit_name = Label.new()
	unit_name.add_theme_font_size_override("font_size", 15)
	unit_name.add_theme_color_override("font_color", GOLD)
	box.add_child(unit_name)
	unit_status = Label.new()
	unit_status.add_theme_font_size_override("font_size", 13)
	box.add_child(unit_status)
	unit_stats = Label.new()
	unit_stats.add_theme_font_size_override("font_size", 13)
	box.add_child(unit_stats)
	unit_panel.visible = false
	add_child(unit_panel)

	# The command tent (Module 7): once-per-battle tactical orders, gated
	# by who the commander is. Grey means the card cannot be played — the
	# tooltip says why.
	var orders := VBoxContainer.new()
	orders.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	orders.offset_left = 12.0
	orders.offset_top = 10.0
	orders.offset_right = 210.0
	orders.add_theme_constant_override("separation", 4)
	for kind in BattleSim.TACTIC_LABELS:
		var b2 := Button.new()
		b2.text = BattleSim.TACTIC_LABELS[kind]
		b2.add_theme_font_size_override("font_size", 13)
		var k: String = kind
		b2.pressed.connect(func() -> void:
			var _e := sim.use_tactic(0, k))
		orders.add_child(b2)
		tactic_buttons[kind] = b2
	add_child(orders)


func _refresh_tactic_buttons() -> void:
	for kind in tactic_buttons:
		var b: Button = tactic_buttons[kind]
		var gate: String = sim.tactic_gate(0, str(kind))
		b.disabled = gate != ""
		b.tooltip_text = gate if gate != "" else "Give the order."


func _ensure_hero_bar() -> void:
	## The hero's spell bar, built once the sim knows a hero rides with
	## side 0 (main.gd sets the hero after the view is constructed).
	if hero_bar != null or (sim.heroes[0] as Dictionary).is_empty():
		return
	hero_bar = HBoxContainer.new()
	hero_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hero_bar.offset_left = -560.0
	hero_bar.offset_right = -12.0
	hero_bar.offset_top = -158.0
	hero_bar.offset_bottom = -132.0  # sits just above the card bar
	hero_bar.alignment = BoxContainer.ALIGNMENT_END
	hero_bar.add_theme_constant_override("separation", 4)
	add_child(hero_bar)
	for aid in sim.hero_abilities(0):
		var info: Dictionary = HeroDB.info(str(aid))
		var b := Button.new()
		b.text = str(info.get("label", aid))
		b.add_theme_font_size_override("font_size", 12)
		var a: String = str(aid)
		b.pressed.connect(func() -> void: _hero_button_pressed(a))
		hero_bar.add_child(b)
		hero_buttons[a] = b


func _hero_button_pressed(aid: String) -> void:
	if pending_ability == aid:
		pending_ability = ""  # pressing again puts the working down
		return
	var kind := str(HeroDB.info(aid).get("kind", ""))
	if kind in ["dispel", "hero_strike", "hero_state"]:
		var _e := sim.use_hero_ability(0, aid, sim.hero_pos(0))
		pending_ability = ""
	else:
		pending_ability = aid  # the next click on the field places it


func _refresh_hero_buttons() -> void:
	_ensure_hero_bar()
	if hero_bar == null:
		return
	for aid in hero_buttons:
		var b: Button = hero_buttons[aid]
		var gate: String = sim.hero_ability_gate(0, str(aid))
		var info: Dictionary = HeroDB.info(str(aid))
		b.disabled = gate != ""
		b.text = "%s (%d)" % [str(info.get("label", aid)), int(sim.hero_uses[0].get(aid, 0))]
		if pending_ability == str(aid):
			b.text = "» %s «" % str(info.get("label", aid))
		b.tooltip_text = str(info.get("desc", "")) + ("" if gate == "" else "\n" + gate)


func _ensure_hero_actors() -> void:
	for side in 2:
		if sim.hero_units[side] == null or hero_actors[side] != null:
			continue
		var actor := HeroActor2D.new()
		actor.configure(sim, side, side_colors[side])
		add_child(actor)
		move_child(actor, 0) # battlefield actor below the HUD controls
		hero_actors[side] = actor


func _process(delta: float) -> void:
	if not over and speed_scale > 0.0:
		var scaled := delta * speed_scale
		battle_time += scaled
		sim.move_step(scaled)
		tick_accum += scaled
		while tick_accum >= BattleSim.TICK_SECONDS:
			tick_accum -= BattleSim.TICK_SECONDS
			sim.combat_tick()
			_sync_visual_casualties()
			sim.ai_step(false)
		# consume fresh volleys from the sim and animate them
		for v in sim.volleys:
			arrows.append({"from": v["from"], "to": v["to"], "age": 0.0})
		sim.volleys.clear()
		# consume the heroes' workings the same way
		for cst in sim.casts:
			var fresh: Dictionary = cst.duplicate()
			fresh["age"] = 0.0
			spell_fx.append(fresh)
		sim.casts.clear()
		var fx_kept: Array = []
		for fx in spell_fx:
			fx["age"] = float(fx["age"]) + scaled
			if float(fx["age"]) < 0.7:
				fx_kept.append(fx)
		spell_fx = fx_kept
		var kept: Array = []
		for a in arrows:
			a["age"] = float(a["age"]) + scaled
			if float(a["age"]) < 0.5:
				kept.append(a)
		arrows = kept
		var fallen_kept: Array = []
		for fallen in fallen_soldiers:
			fallen["age"] = float(fallen["age"]) + scaled
			fallen["pos"] = Vector2(fallen["pos"]) + Vector2(fallen["velocity"]) * scaled
			if float(fallen["age"]) < float(fallen["duration"]):
				fallen_kept.append(fallen)
		fallen_soldiers = fallen_kept
	_update_camera(delta)
	_ensure_hero_actors()
	for side in 2:
		if hero_actors[side] != null:
			(hero_actors[side] as HeroActor2D).sync_from_view(self, commander_selected and side == 0)
	_refresh_unit_panel()
	_refresh_tactic_buttons()
	_refresh_hero_buttons()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if over:
		return
	if event is InputEventMouseMotion:
		mouse_now = event.position
		return
	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP
				or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var lay := _card_layout()
			var bar: Rect2 = lay["bar"]
			if bar.size.x > 0.0 and bar.has_point(event.position):
				return
			var before := _to_field(event.position)
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera_zoom = minf(CAMERA_MAX_ZOOM, camera_zoom * CAMERA_ZOOM_STEP)
			else:
				camera_zoom = maxf(CAMERA_MIN_ZOOM, camera_zoom / CAMERA_ZOOM_STEP)
			var sc := _scale()
			if sc > 0.0:
				camera_center = before - (event.position - size * 0.5) / sc
			_clamp_camera()
			return
		# a drag in progress finishes wherever the button lifts — even over the bar
		if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed and dragging:
			dragging = false
			_issue_order(drag_start, event.position)
			return
		if _card_click(event.position, event.button_index, event.pressed):
			return
		# a working awaiting its target lands where the next click falls
		if pending_ability != "" and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var _e := sim.use_hero_ability(0, pending_ability, _to_field(event.position))
				pending_ability = ""
				return
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				pending_ability = ""  # the working is put down unspent
				return
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected_id = -1
			commander_selected = false
			if sim.hero_active(0) and _to_screen(sim.hero_pos(0)).distance_to(event.position) \
					<= maxf(sim.hero_radius(0) * _scale() + 8.0, 22.0):
				commander_selected = true
				return
			for r: BattleSim.Regiment in sim.regiments:
				if r.alive() and _to_screen(r.pos).distance_to(event.position) < maxf(r.radius() * _scale(), 26.0):
					selected_id = r.id
					break
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if commander_selected and sim.hero_active(0):
				sim.order_hero(0, _to_field(event.position))
				return
			if selected_id >= 0:
				var r: BattleSim.Regiment = sim.regiments[selected_id]
				if r.side == 0 and r.active():
					dragging = true
					drag_start = event.position


func _issue_order(a: Vector2, b: Vector2) -> void:
	## Right-click = march there. Right-DRAG = draw the battle line:
	## the regiment reforms to that frontage and faces perpendicular
	## to the drawn line, toward the enemy.
	if selected_id < 0:
		return
	var r: BattleSim.Regiment = sim.regiments[selected_id]
	if r.side != 0 or not r.active():
		return
	var drag_px := a.distance_to(b)
	if drag_px < 24.0:
		r.has_move_order = true
		r.move_target = _to_field(a)
		r.has_face_order = false
		r.hold_facing = false
		return
	var dir := (b - a).normalized()
	r.files = clampi(int(drag_px / _scale() / BattleSim.SPACING), 3, 40)
	r.has_move_order = true
	r.move_target = _to_field((a + b) * 0.5)
	var perp := Vector2(-dir.y, dir.x)
	var enemy := sim._nearest_enemy(r)
	if enemy != null and perp.dot((enemy.pos - r.move_target).normalized()) < 0.0:
		perp = -perp
	r.has_face_order = true
	r.face_dir = perp


# ---------------------------------------------------------------- coords

func _base_scale() -> float:
	return minf(size.x / sim.field.x, size.y / sim.field.y)


func _scale() -> float:
	return _base_scale() * camera_zoom


func _offset() -> Vector2:
	return size * 0.5 - camera_center * _scale()


func _to_screen(p: Vector2) -> Vector2:
	return (_offset() + p * _scale()).floor()


func _to_field(p: Vector2) -> Vector2:
	return (p - _offset()) / _scale()


func _clamp_camera() -> void:
	if camera_center == Vector2.ZERO:
		camera_center = sim.field * 0.5
	var sc := _scale()
	if sc <= 0.0:
		return
	var half := size * 0.5 / sc
	if half.x >= sim.field.x * 0.5:
		camera_center.x = sim.field.x * 0.5
	else:
		camera_center.x = clampf(camera_center.x, half.x, sim.field.x - half.x)
	if half.y >= sim.field.y * 0.5:
		camera_center.y = sim.field.y * 0.5
	else:
		camera_center.y = clampf(camera_center.y, half.y, sim.field.y - half.y)


func _update_camera(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir == Vector2.ZERO:
		return
	var sc := _scale()
	if sc <= 0.0:
		return
	camera_center += dir.normalized() * (CAMERA_PAN_PX_PER_SEC / sc) * delta
	_clamp_camera()


func _soldier_pose(r: BattleSim.Regiment, index: int, count: int,
		at_time: float = -1.0, animate: bool = true) -> Dictionary:
	## A stable procedural pose for one decorative soldier. This is deliberately
	## local animation rather than a physics body: regiment collision remains
	## authoritative while hundreds of sprites can move cheaply.
	count = maxi(count, 1)
	var files := r.files_for_count(count)
	var rows := r.rows_for_count(count)
	var row := int(index / files)
	var col := index % files
	var row_count := mini(files, count - row * files)
	var across_offset := (float(col) - float(maxi(row_count, 1) - 1) * 0.5) * r.file_spacing()
	var depth_offset := (float(rows - 1) * 0.5 - float(row)) * r.row_spacing()
	var forward := r.facing.normalized()
	if forward.length_squared() < 0.001:
		forward = Vector2.RIGHT if r.side == 0 else Vector2.LEFT
	var across := forward.rotated(PI * 0.5)
	var seed: int = absi((index + 1) * 92821 + (r.id + 7) * 68917)
	var jitter_across := (float(seed % 7) - 3.0) * 0.16
	var jitter_depth := (float((seed / 7) % 5) - 2.0) * 0.08
	if r.routed:
		jitter_across *= 5.0
		jitter_depth *= 5.0
	var world := r.pos + across * (across_offset + jitter_across) + forward * (depth_offset + jitter_depth)
	var action := 0.0
	var phase := 0.0
	if at_time < 0.0:
		at_time = battle_time
	if animate:
		phase = fposmod(at_time * ATTACK_CYCLE_PER_SECOND + float(seed % 997) / 997.0, 1.0)
		if r.engaged_id >= 0 and not r.routed and row <= 1:
			if phase < 0.34:
				action = sin((phase / 0.34) * PI)
			elif phase < 0.62:
				action = -0.34 * sin(((phase - 0.34) / 0.28) * PI)
			var rank_weight := 1.0 if row == 0 else 0.38
			world += forward * action * 2.4 * rank_weight
			world += across * sin(phase * TAU) * 0.28 * rank_weight
		else:
			# Breathing, footing, and shield adjustment keep idle ranks alive
			# without making the formation itself wobble.
			world += across * sin(phase * TAU) * 0.10
			world += forward * cos(phase * TAU) * 0.06
	return {"world": world, "action": action, "phase": phase, "row": row}


func _sync_visual_casualties() -> void:
	## Strength is read directly from BattleSim. This cache exists only to know
	## how many transient bodies to leave behind when that authoritative count
	## drops between combat ticks.
	for r: BattleSim.Regiment in sim.regiments:
		var previous := int(visual_soldier_counts.get(r.id, r.soldiers))
		var lost := maxi(0, previous - r.soldiers)
		if lost > 0:
			var shown := mini(lost, 14)
			var old_files := r.files_for_count(previous)
			for n in shown:
				var index := r.soldiers + n
				if r.engaged_id >= 0:
					index = n % maxi(1, mini(old_files, previous))
				var pose := _soldier_pose(r, index, maxi(previous, 1), battle_time, false)
				var forward := r.facing.normalized()
				if forward.length_squared() < 0.001:
					forward = Vector2.RIGHT if r.side == 0 else Vector2.LEFT
				var across := forward.rotated(PI * 0.5)
				var seed: int = absi((r.id + 3) * 7919 + (n + 11) * 104729 + sim.combat_ticks * 17)
				fallen_soldiers.append({
					"pos": Vector2(pose["world"]),
					"velocity": -forward * lerpf(3.0, 7.0, float(seed % 101) / 100.0)
						+ across * (float(seed % 7) - 3.0) * 0.45,
					"kind": r.kind,
					"body": side_colors[r.side],
					"age": 0.0,
					"duration": CASUALTY_LIFETIME * lerpf(0.82, 1.14, float(seed % 89) / 88.0),
				})
		visual_soldier_counts[r.id] = r.soldiers
	while fallen_soldiers.size() > MAX_FALLEN_SPRITES:
		fallen_soldiers.pop_front()


func _cone_screen_points(origin: Vector2, direction: Vector2, length: float,
		half_angle: float, segments: int = 16) -> PackedVector2Array:
	var points := PackedVector2Array([_to_screen(origin)])
	var base_angle := direction.angle()
	for i in range(segments + 1):
		var angle := base_angle - half_angle + (half_angle * 2.0) * float(i) / float(segments)
		points.append(_to_screen(origin + Vector2.from_angle(angle) * length))
	return points


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GRASS_BASE)
	_clamp_camera()
	for patch in patches:
		var field_p: Vector2 = Vector2(patch["pos"].x * sim.field.x, patch["pos"].y * sim.field.y)
		var p: Vector2 = _to_screen(field_p)
		var ps: float = float(patch["size"]) * _scale() / maxf(0.001, _base_scale())
		if p.x < -ps or p.y < -ps or p.x > size.x + ps or p.y > size.y + ps:
			continue
		match int(patch["kind"]):
			0:
				draw_rect(Rect2(p, Vector2(ps * 0.8, ps * 0.5)), ROCK)
			1, 2:
				draw_circle(p, ps * 0.9, TREE)
			_:
				draw_rect(Rect2(p, Vector2(ps, ps * 0.6)), GRASS_DARK if int(patch["kind"]) % 2 == 0 else GRASS_LIGHT)

	# persistent workings burn on the ground beneath the formations
	for z in sim.zones:
		var zp := _to_screen(z["pos"])
		var zr := float(z["radius"]) * _scale()
		var pulse := 0.55 + 0.15 * sin(battle_time * 5.0)
		draw_circle(zp, zr, Color(0.85, 0.35, 0.10, 0.16 * pulse))
		draw_arc(zp, zr, 0.0, TAU, 40, Color(0.95, 0.55, 0.15, 0.65), 2.0)
		draw_arc(zp, zr * 0.7, battle_time * 1.5, battle_time * 1.5 + TAU * 0.7, 30,
			Color(0.95, 0.45, 0.10, 0.35), 1.5)

	# Fallen sprites sit below the surviving formations and fade quickly; the
	# authoritative soldier count has already changed in the sim and UI.
	for fallen in fallen_soldiers:
		_draw_fallen_soldier(fallen)

	# regiments, painter-sorted by field y
	var order: Array = sim.regiments.filter(func(r) -> bool: return not r.fled)
	order.sort_custom(func(a, b) -> bool: return a.pos.y < b.pos.y)

	for r: BattleSim.Regiment in order:
		if r.id == selected_id:
			var c := _to_screen(r.pos)
			var rr := r.radius() * _scale() + 8.0
			draw_arc(c, rr, 0.0, TAU, 40, GOLD, 2.0)
		_draw_regiment(r)
	# arrows in flight, arcing between shooter and target
	for a in arrows:
		var t: float = float(a["age"]) / 0.5
		var from := _to_screen(a["from"])
		var to := _to_screen(a["to"])
		var p := from.lerp(to, t) + Vector2(0, -sin(t * PI) * 16.0)
		var dir := (to - from).normalized()
		draw_line(p - dir * 4.0, p + dir * 4.0, Color("2a2118"), 1.5)

	# the heroes' workings flare and fade where they landed
	for fx in spell_fx:
		var age: float = float(fx["age"]) / 0.7
		var col := Color(0.95, 0.55, 0.15)
		match str(fx["color"]):
			"gold": col = Color(0.85, 0.75, 0.35)
			"bolt": col = Color(0.55, 0.75, 0.95)
			"dread": col = Color(0.55, 0.30, 0.65)
			"cold": col = Color(0.62, 0.88, 1.0)
			"primal": col = Color(0.35, 0.72, 0.32)
			"rage": col = Color(0.95, 0.22, 0.10)
		col.a = (1.0 - age) * 0.8
		match str(fx.get("shape", "circle")):
			"line":
				var line_from := _to_screen(Vector2(fx["origin"]))
				var line_to := _to_screen(Vector2(fx["origin"]) + Vector2(fx["dir"]) * float(fx["length"]))
				draw_line(line_from, line_to, col, maxf(2.0, float(fx.get("width", 18.0)) * _scale() * (1.0 - age * 0.55)))
				draw_line(line_from, line_to, Color(0.9, 0.95, 1.0, col.a), 1.2)
			"cone":
				var points := _cone_screen_points(Vector2(fx["origin"]), Vector2(fx["dir"]),
					float(fx["length"]) * (0.55 + age * 0.45), float(fx["angle"]) * 0.5)
				draw_colored_polygon(points, Color(col, col.a * 0.30))
				draw_polyline(points, col, 2.0)
			_:
				var fp := _to_screen(Vector2(fx["pos"]))
				var fr := float(fx["radius"]) * _scale() * (0.4 + 0.6 * age)
				draw_arc(fp, fr, 0.0, TAU, 40, col, 3.0 * (1.0 - age) + 1.0)
				draw_circle(fp, fr * 0.25 * (1.0 - age), Color(col, col.a * 0.5))

	for r: BattleSim.Regiment in order:
		_draw_banner(r)

	# drag preview: the new battle line and its frontage
	if dragging:
		draw_line(drag_start, mouse_now, GOLD, 2.0)
		var drag_px := drag_start.distance_to(mouse_now)
		if drag_px >= 24.0:
			var files := clampi(int(drag_px / _scale() / BattleSim.SPACING), 3, 40)
			var font := get_theme_default_font()
			draw_string(font, mouse_now + Vector2(12, -6), "%d files" % files,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)

	# a working awaiting its target: the reach previewed under the cursor
	if pending_ability != "":
		var pinfo: Dictionary = HeroDB.info(pending_ability)
		var preview_color := Color(0.95, 0.65, 0.25, 0.85)
		var kind := str(pinfo.get("kind", ""))
		if kind == "line":
			var origin_screen := _to_screen(sim.hero_pos(0))
			var toward := mouse_now - origin_screen
			if toward.length_squared() < 1.0:
				toward = Vector2.RIGHT
			var endpoint := origin_screen + toward.normalized() * float(pinfo.get("length", 240.0)) * _scale()
			draw_line(origin_screen, endpoint, Color(preview_color, 0.20), float(pinfo.get("width", 18.0)) * _scale())
			draw_line(origin_screen, endpoint, preview_color, 2.0)
		elif kind == "cone":
			var origin := sim.hero_pos(0)
			var direction := _to_field(mouse_now) - origin
			if direction.length_squared() < 1.0:
				direction = Vector2.RIGHT
			var cone_points := _cone_screen_points(origin, direction.normalized(), float(pinfo.get("length", 150.0)),
				deg_to_rad(float(pinfo.get("angle", 60.0)) * 0.5))
			draw_colored_polygon(cone_points, Color(preview_color, 0.16))
			draw_polyline(cone_points, preview_color, 2.0)
		else:
			var preview := float(pinfo.get("radius", 20.0)) * _scale()
			draw_arc(mouse_now, preview, 0.0, TAU, 40, preview_color, 2.0)
		draw_arc(mouse_now, 4.0, 0.0, TAU, 12, Color(0.95, 0.65, 0.25, 0.85), 2.0)
		var pfont := get_theme_default_font()
		draw_string(pfont, mouse_now + Vector2(12, -10), str(pinfo.get("label", pending_ability)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)

	_draw_card_bar()


func _draw_regiment(r: BattleSim.Regiment) -> void:
	var body: Color = side_colors[r.side]
	if r.routed:
		body = body.lerp(Color(0.5, 0.5, 0.5), 0.35)
	for i in r.soldiers:
		var pose := _soldier_pose(r, i, r.soldiers)
		var facing_side := signf(r.facing.x)
		if absf(facing_side) < 0.1:
			facing_side = 1.0 if r.side == 0 else -1.0
		_draw_soldier(_to_screen(Vector2(pose["world"])), r.kind, body, -1.0,
			float(pose["action"]), facing_side)


func _soldier_role(kind: String) -> String:
	if kind == "cav" or kind.contains("cavalry"):
		return "cav"
	if kind.contains("warden") or kind.contains("caeris"):
		return "dead"
	if kind.contains("elder_guard") or kind.contains("trade_guard") or kind.contains("coin_sworn") \
			or kind.contains("sworn_sword") or kind.contains("court_company") or kind.contains("vigil"):
		return "sword"
	if kind == "levy" or kind.contains("spear") or kind.contains("ironside") \
			or kind.contains("column") or kind.contains("militia"):
		return "spear"
	if kind == "archer" or kind.contains("archer") or kind.contains("skirmisher") \
			or kind.contains("arcane") or kind.contains("speaker") \
			or kind.contains("marine") or kind.contains("harbor_guard"):
		return "missile"
	return "sword"


func _soldier_metal(kind: String) -> Color:
	if kind.contains("ironside") or kind.contains("vigil") or kind.contains("elder") \
			or kind.contains("cavalry") or kind == "cav":
		return Color("c9c6b8")
	if kind.contains("warden") or kind.contains("caeris"):
		return Color("d8d2c4")
	return HELMET


func _soldier_cloth(kind: String, body: Color) -> Color:
	if kind.contains("warden"):
		return Color("d8d2c4")
	if kind.contains("caeris"):
		return Color("665d5e")
	if kind.contains("drevak") or kind.contains("berserker") or kind.contains("compact"):
		return body.lerp(Color("9a4f34"), 0.42)
	if kind.contains("dwarven") or kind.contains("ironside") or kind.contains("ward"):
		return body.lerp(Color("7d6a47"), 0.38)
	if kind.contains("veldarin") or kind.contains("thaladris"):
		return body.lerp(Color("315a3e"), 0.40)
	if kind.contains("arcane"):
		return body.lerp(Color("6f5aa6"), 0.38)
	return body


func _draw_pixel_shadow(p: Vector2, w: float, h: float, s: float) -> void:
	draw_rect(Rect2(p + Vector2(-w * 0.5, -h * 0.2) * s, Vector2(w, h) * s),
		Color("16200f70"))


static func _fade(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)


func _draw_fallen_soldier(fallen: Dictionary) -> void:
	var duration := maxf(0.01, float(fallen["duration"]))
	var t := clampf(float(fallen["age"]) / duration, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.48, 1.0, t)
	var p := _to_screen(Vector2(fallen["pos"]))
	var kind := str(fallen["kind"])
	var body: Color = fallen["body"]
	var cloth := _fade(_soldier_cloth(kind, body).darkened(0.12), fade)
	var metal := _fade(_soldier_metal(kind).darkened(0.10), fade)
	var skin := _fade(Color("d8d2c4") if _soldier_role(kind) == "dead" else SKIN, fade)
	var s := _scale() * 1.16
	var settle := minf(1.0, t / 0.24)
	p += Vector2(0.0, settle * 1.2 * s)
	draw_rect(Rect2(p + Vector2(-5.2, 1.0) * s, Vector2(10.4, 2.0) * s), _fade(Color("16200f"), fade * 0.34))
	if _soldier_role(kind) == "cav":
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-8.0, -1.8) * s,
			p + Vector2(5.7, -2.4) * s,
			p + Vector2(8.0, 0.6) * s,
			p + Vector2(-6.7, 1.5) * s,
		]), _fade(HORSE.darkened(0.08), fade))
		draw_line(p + Vector2(-5.0, 0.4) * s, p + Vector2(-8.2, 3.3) * s, _fade(Color("1c1410"), fade), maxf(1.0, s * 0.7))
		draw_circle(p + Vector2(1.0, -3.2) * s, 1.8 * s, skin)
	else:
		# Horizontal body, loosened limbs, and dropped weapon: enough motion to
		# read as a fall without allocating a node or rigid body per casualty.
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-4.7, -1.8) * s,
			p + Vector2(3.4, -2.4) * s,
			p + Vector2(5.0, 0.3) * s,
			p + Vector2(-3.8, 1.4) * s,
		]), cloth)
		draw_circle(p + Vector2(5.3, -1.4) * s, 1.9 * s, skin)
		draw_line(p + Vector2(-3.4, 0.4) * s, p + Vector2(-6.4, 3.0) * s, _fade(Color("1a1511"), fade), maxf(1.0, s * 0.75))
		draw_line(p + Vector2(-1.2, 0.8) * s, p + Vector2(-2.0, 3.6) * s, _fade(Color("1a1511"), fade), maxf(1.0, s * 0.75))
		draw_line(p + Vector2(-5.5, -2.7) * s, p + Vector2(6.8, 2.7) * s, metal, maxf(1.0, s * 0.50))


func _draw_little_shield(c: Vector2, s: float, col: Color, metal: Color, round: bool = false) -> void:
	if round:
		draw_circle(c, 2.5 * s, col.darkened(0.25))
		draw_circle(c, 1.7 * s, col.lightened(0.10))
		draw_line(c + Vector2(-1.6, 0) * s, c + Vector2(1.6, 0) * s, metal.darkened(0.1), maxf(1.0, s * 0.55))
	else:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-2.1, -2.8) * s,
			c + Vector2(2.1, -2.2) * s,
			c + Vector2(1.7, 2.1) * s,
			c + Vector2(0.0, 3.1) * s,
			c + Vector2(-2.0, 2.0) * s,
		]), col.darkened(0.25))
		draw_line(c + Vector2(-1.4, -2.0) * s, c + Vector2(1.0, 1.8) * s,
			metal.lightened(0.18), maxf(1.0, s * 0.45))


func _draw_soldier(p: Vector2, kind: String, body: Color, s: float = -1.0,
		action: float = 0.0, facing_side: float = 1.0) -> void:
	if s < 0.0:
		s = _scale() * 1.16
	var role := _soldier_role(kind)
	var cloth := _soldier_cloth(kind, body)
	var metal := _soldier_metal(kind)
	var leather := Color("563b24")
	var skin := SKIN
	var side := 1.0 if facing_side >= 0.0 else -1.0
	var strike := maxf(0.0, action)
	if role == "dead":
		skin = Color("d8d2c4")
		cloth = cloth.darkened(0.12)

	if role == "cav":
		_draw_pixel_shadow(p + Vector2(0, 2.0) * s, 15.0, 4.0, s)
		var horse := HORSE.lerp(body.darkened(0.35), 0.18)
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-7.6 * side, -3.0) * s,
			p + Vector2(-3.0 * side, -5.0) * s,
			p + Vector2(4.8 * side, -4.2) * s,
			p + Vector2(7.2 * side, -2.0) * s,
			p + Vector2(5.5 * side, 1.0) * s,
			p + Vector2(-6.8 * side, 1.1) * s,
		]), horse)
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(4.8 * side, -4.0) * s,
			p + Vector2(8.2 * side, -6.0) * s,
			p + Vector2(9.4 * side, -4.3) * s,
			p + Vector2(6.9 * side, -1.6) * s,
		]), horse.lightened(0.04))
		draw_line(p + Vector2(-7.2 * side, -3.0) * s, p + Vector2(-10.0 * side, -5.1) * s,
			horse.darkened(0.28), maxf(1.0, s * 0.9))
		for lx in [-5.0, -1.5, 3.2, 6.0]:
			draw_line(p + Vector2(lx * side, 0.2) * s, p + Vector2((lx - 0.9) * side, 4.4) * s,
				Color("1c1410"), maxf(1.0, s * 0.65))
		draw_line(p + Vector2(-2.6, -6.2) * s, p + Vector2(0.8, -5.0) * s,
			metal.darkened(0.28), maxf(1.0, s * 0.75))
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-2.6, -8.7) * s,
			p + Vector2(1.6, -8.2) * s,
			p + Vector2(2.4, -3.8) * s,
			p + Vector2(-1.8, -3.4) * s,
		]), cloth)
		draw_circle(p + Vector2(-0.1, -10.4) * s, 2.0 * s, skin)
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-2.5, -11.0) * s,
			p + Vector2(0.0, -13.0) * s,
			p + Vector2(2.6, -11.0) * s,
			p + Vector2(1.6, -9.5) * s,
			p + Vector2(-1.8, -9.5) * s,
		]), metal)
		draw_line(p + Vector2(2.8 * side, -8.6) * s,
			p + Vector2((8.8 + strike * 4.0) * side, -12.4 + strike * 5.0) * s,
			metal.lightened(0.2), maxf(1.0, s * 0.75))
		return

	_draw_pixel_shadow(p + Vector2(0, 2.0) * s, 8.0, 2.4, s)
	# legs and boots
	draw_line(p + Vector2(-1.4, -0.4) * s, p + Vector2(-2.7, 3.8) * s,
		Color("1a1511"), maxf(1.0, s * 0.85))
	draw_line(p + Vector2(1.2, -0.4) * s, p + Vector2(2.2, 3.8) * s,
		Color("1a1511"), maxf(1.0, s * 0.85))
	# tunic/armour silhouette
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-3.2, -7.2) * s,
		p + Vector2(3.1, -7.2) * s,
		p + Vector2(3.6, -1.1) * s,
		p + Vector2(1.4, 0.7) * s,
		p + Vector2(-1.6, 0.7) * s,
		p + Vector2(-3.8, -1.1) * s,
	]), cloth.darkened(0.08))
	draw_rect(Rect2(p + Vector2(-2.3, -6.4) * s, Vector2(4.6, 4.7) * s),
		cloth.lightened(0.08))
	draw_line(p + Vector2(-2.6, -1.7) * s, p + Vector2(2.7, -1.7) * s,
		leather, maxf(1.0, s * 0.55))

	# arms, head, helmet
	draw_line(p + Vector2(-3.2, -5.4) * s, p + Vector2(-5.0, -2.0) * s,
		skin.darkened(0.12), maxf(1.0, s * 0.75))
	draw_line(p + Vector2(3.2, -5.4) * s, p + Vector2(5.0, -2.0) * s,
		skin.darkened(0.12), maxf(1.0, s * 0.75))
	draw_circle(p + Vector2(0.0, -9.2) * s, 2.05 * s, skin)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-2.5, -9.6) * s,
		p + Vector2(-1.0, -11.6) * s,
		p + Vector2(1.3, -11.6) * s,
		p + Vector2(2.6, -9.6) * s,
		p + Vector2(1.6, -8.3) * s,
		p + Vector2(-1.7, -8.3) * s,
	]), metal)
	draw_line(p + Vector2(-1.8, -8.5) * s, p + Vector2(1.8, -8.5) * s,
		metal.darkened(0.35), maxf(1.0, s * 0.45))

	if role == "spear":
		var spear_base := p + Vector2(4.4 * side, 2.6) * s
		var spear_tip := p + Vector2((4.5 + strike * 8.0) * side, -13.8 + strike * 7.0) * s
		draw_line(spear_base, spear_tip,
			Color("6b4a30"), maxf(1.0, s * 0.55))
		draw_colored_polygon(PackedVector2Array([
			spear_tip + Vector2(0.0, -1.6) * s,
			spear_tip + Vector2(-0.9 * side, 1.0) * s,
			spear_tip + Vector2(1.0 * side, 1.0) * s,
		]), metal.lightened(0.25))
		_draw_little_shield(p + Vector2(-4.1 * side, -4.5) * s, s, cloth, metal, false)
	elif role == "missile":
		if absf(action) > 0.04:
			# Once caught in contact, missile troops use a short sidearm instead
			# of continuing to loose arrows through the melee.
			draw_line(p + Vector2(2.3 * side, -4.0) * s,
				p + Vector2((6.0 + strike * 3.0) * side, -8.0 + strike * 3.0) * s,
				metal.lightened(0.18), maxf(1.0, s * 0.62))
		else:
			draw_arc(p + Vector2(4.8 * side, -5.2) * s, 4.0 * s, -1.35, 1.28, 10,
				Color("8a5b2c"), maxf(1.0, s * 0.55))
			draw_line(p + Vector2(4.9 * side, -9.0) * s, p + Vector2(4.8 * side, -1.6) * s,
				Color("d8d2c4"), maxf(1.0, s * 0.35))
			draw_line(p + Vector2(-3.0 * side, -6.4) * s, p + Vector2(2.5 * side, -6.0) * s,
				Color("6b4a30"), maxf(1.0, s * 0.45))
			if kind.contains("arcane") or kind.contains("speaker") or kind.contains("song"):
				draw_circle(p + Vector2(5.6 * side, -8.0) * s, maxf(1.0, 0.9 * s), GOLD.lightened(0.15))
	elif role == "dead":
		draw_line(p + Vector2(3.0 * side, -4.0) * s,
			p + Vector2((6.0 + strike * 3.0) * side, -8.8 + strike * 3.2) * s,
			Color("7b7a72"), maxf(1.0, s * 0.6))
		draw_circle(p + Vector2(0.0, -9.2) * s, 0.7 * s, Color("1a1511"))
		draw_circle(p + Vector2(-0.9, -9.3) * s, 0.45 * s, Color("1a1511"))
	else:
		draw_line(p + Vector2(3.2 * side, -3.4) * s,
			p + Vector2((7.0 + strike * 4.2) * side, -9.0 + strike * 5.0) * s,
			metal.lightened(0.22), maxf(1.0, s * 0.75))
		draw_line(p + Vector2(2.6 * side, -3.2) * s, p + Vector2(4.2 * side, -1.9) * s,
			GOLD.darkened(0.1), maxf(1.0, s * 0.55))
		_draw_little_shield(p + Vector2(-4.0 * side, -4.2) * s, s, cloth, metal, true)


func _draw_banner(r: BattleSim.Regiment) -> void:
	if r.routed:
		return
	var top := _to_screen(r.pos) + Vector2(0, -r.radius() * _scale() - 12.0)
	var pole_base := top + Vector2(0, 18.0)
	var pole_top := top + Vector2(0, -18.0)
	draw_line(pole_base + Vector2(1.0, 0.0), pole_top + Vector2(1.0, 0.0), Color("14100b"), 2.0)
	draw_line(pole_base, pole_top, Color("6b4a30"), 2.0)
	draw_circle(pole_top, 2.2, GOLD.darkened(0.15))

	var flag_p := top + Vector2(2.0, -17.0)
	var flag_col: Color = side_colors[r.side]
	var flag_dark := flag_col.darkened(0.32)
	var flag_light := flag_col.lightened(0.20)
	var cloth := PackedVector2Array([
		flag_p,
		flag_p + Vector2(21.0, 1.0),
		flag_p + Vector2(19.0, 7.0),
		flag_p + Vector2(21.0, 13.0),
		flag_p + Vector2(0.0, 12.0),
	])
	draw_colored_polygon(cloth, flag_dark)
	draw_colored_polygon(PackedVector2Array([
		flag_p + Vector2(2.0, 1.0),
		flag_p + Vector2(18.0, 2.0),
		flag_p + Vector2(16.0, 6.8),
		flag_p + Vector2(18.0, 11.0),
		flag_p + Vector2(2.0, 10.5),
	]), flag_col)
	draw_line(flag_p + Vector2(3.0, 2.0), flag_p + Vector2(18.0, 2.6), flag_light, 1.0)
	if r.side == 1:
		draw_colored_polygon(PackedVector2Array([
			flag_p + Vector2(7.0, 1.4),
			flag_p + Vector2(12.0, 1.8),
			flag_p + Vector2(10.0, 11.2),
			flag_p + Vector2(5.2, 11.0),
		]), Color("e8e2d4"))
	var icon_c := flag_p + Vector2(10.8, 7.0)
	if r.is_cav:
		draw_arc(icon_c + Vector2(0.0, 1.0), 4.2, PI * 1.08, PI * 1.92, 10, GOLD, 1.4)
	elif r.rng_range > 0.0:
		draw_arc(icon_c + Vector2(-1.0, 0.0), 4.3, -PI * 0.42, PI * 0.42, 10, GOLD, 1.4)
	else:
		draw_line(icon_c + Vector2(-4.0, 4.0), icon_c + Vector2(4.0, -4.0), GOLD, 1.5)
		draw_line(icon_c + Vector2(-3.0, -0.8), icon_c + Vector2(0.8, 3.0), GOLD, 1.1)

	var bar_pos := top + Vector2(-12.0, 4.0)
	var hp := float(r.soldiers) / maxf(1.0, float(r.start_soldiers))
	var mor := clampf(r.morale() / BattleSim.START_MORALE, 0.0, 1.0)
	draw_rect(Rect2(bar_pos, Vector2(24, 3)), Color("1c1410"))
	draw_rect(Rect2(bar_pos, Vector2(24.0 * hp, 3)), HP_COLOR)
	draw_rect(Rect2(bar_pos + Vector2(0, 4), Vector2(24, 3)), Color("1c1410"))
	draw_rect(Rect2(bar_pos + Vector2(0, 4), Vector2(24.0 * mor, 3)), MORALE_COLOR)


# ---------------------------------------------------------------- card bar

func _card_layout() -> Dictionary:
	## Where every card sits this frame. Pure geometry — the click handler
	## and the draw pass both read it, so headless tests can too.
	var mine: Array = sim.regiments.filter(func(r) -> bool: return r.side == 0)
	var has_cmdr: bool = not (sim.commanders[0] as Dictionary).is_empty()
	if mine.is_empty():
		return {"bar": Rect2(), "cards": [], "commander": Rect2(), "has_commander": false, "card_w": CARD_W}
	var n := mine.size() + (1 if has_cmdr else 0)
	var hero_gap := 8.0 if has_cmdr else 0.0   # heroes sit apart from the line, TW-style
	var card_w := CARD_W
	var inner := float(n) * card_w + float(n - 1) * CARD_GAP + hero_gap
	var avail := size.x - 24.0 - BAR_PAD * 2.0
	if inner > avail:
		card_w = maxf(30.0, (avail - float(n - 1) * CARD_GAP - hero_gap) / float(n))
		inner = float(n) * card_w + float(n - 1) * CARD_GAP + hero_gap
	var bar := Rect2(Vector2((size.x - inner) * 0.5 - BAR_PAD, size.y - CARD_H - BAR_PAD * 2.0 - 6.0),
		Vector2(inner + BAR_PAD * 2.0, CARD_H + BAR_PAD * 2.0))
	var x := bar.position.x + BAR_PAD
	var y := bar.position.y + BAR_PAD
	var cmdr_rect := Rect2()
	if has_cmdr:
		cmdr_rect = Rect2(Vector2(x, y), Vector2(card_w, CARD_H))
		x += card_w + CARD_GAP + hero_gap
	var cards: Array = []
	for r: BattleSim.Regiment in mine:
		cards.append({"rect": Rect2(Vector2(x, y), Vector2(card_w, CARD_H)), "id": r.id})
		x += card_w + CARD_GAP
	return {"bar": bar, "cards": cards, "commander": cmdr_rect, "has_commander": has_cmdr, "card_w": card_w}


func _card_archetype(r: BattleSim.Regiment) -> String:
	## Which glyph sits in the card's bottom notch — the unit's battlefield role.
	if r.silence_kind:
		return "silence"
	if r.is_cav:
		return "cavalry"
	if r.ward_shield:
		return "caster"
	if r.aura_lead > 0.0:
		return "support"
	if r.rng_range > 0.0:
		return "missile"
	if r.bonus_cav >= 10.0:
		return "spear"
	return "sword"


func _card_click(pos: Vector2, button: int, pressed: bool) -> bool:
	## True when the click lands on the card bar — it is consumed there
	## and never reaches the field beneath.
	var lay := _card_layout()
	var bar: Rect2 = lay["bar"]
	if bar.size.x <= 0.0 or not bar.has_point(pos):
		return false
	if button == MOUSE_BUTTON_LEFT and pressed:
		if bool(lay["has_commander"]) and (lay["commander"] as Rect2).has_point(pos):
			commander_selected = true
			selected_id = -1
			return true
		for c in lay["cards"]:
			if (c["rect"] as Rect2).has_point(pos):
				commander_selected = false
				selected_id = int(c["id"])
				return true
	return true


func _draw_card_bar() -> void:
	var lay := _card_layout()
	var bar: Rect2 = lay["bar"]
	if bar.size.x <= 0.0:
		return
	draw_rect(bar, Color("14110ce0"))
	draw_rect(bar, Color("3a2b1c"), false, 2.0)
	var hover_text := ""
	if bool(lay["has_commander"]):
		var crect: Rect2 = lay["commander"]
		_draw_commander_card(crect)
		if crect.has_point(mouse_now):
			hover_text = str(sim.commanders[0].get("name", "The Commander"))
	for c in lay["cards"]:
		var r: BattleSim.Regiment = sim.regiments[int(c["id"])]
		_draw_unit_card(c["rect"] as Rect2, r)
		if (c["rect"] as Rect2).has_point(mouse_now):
			hover_text = "%s — %d men" % [r.label, r.soldiers]
	if hover_text != "":
		var font := get_theme_default_font()
		var tw := font.get_string_size(hover_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var tp := Vector2(clampf(mouse_now.x - tw * 0.5, 8.0, size.x - tw - 8.0), bar.position.y - 10.0)
		draw_rect(Rect2(tp + Vector2(-5, -14), Vector2(tw + 10, 19)), Color("14110cd8"))
		draw_string(font, tp, hover_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD)


func _draw_unit_card(rect: Rect2, r: BattleSim.Regiment) -> void:
	var font := get_theme_default_font()
	draw_rect(rect, CARD_BG)
	# the number band: men remaining, over a green bar of the unit's strength
	var band := Rect2(rect.position, Vector2(rect.size.x, 13.0))
	var hp := clampf(float(r.soldiers) / maxf(1.0, float(r.start_soldiers)), 0.0, 1.0)
	draw_rect(band, CARD_BAND)
	draw_rect(Rect2(band.position, Vector2(band.size.x * hp, band.size.y)), HP_COLOR.darkened(0.15))
	draw_string(font, band.position + Vector2(3, 10), str(r.soldiers),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	# thin strips beneath: morale (gold), then ammunition (orange, missile units)
	var y := band.end.y + 1.0
	var mor := clampf(r.morale() / BattleSim.START_MORALE, 0.0, 1.0)
	draw_rect(Rect2(Vector2(rect.position.x, y), Vector2(rect.size.x, 2.0)), CARD_BAND)
	draw_rect(Rect2(Vector2(rect.position.x, y), Vector2(rect.size.x * mor, 2.0)), MORALE_COLOR)
	y += 3.0
	if r.rng_range > 0.0:
		var am := clampf(float(r.ammo) / maxf(1.0, float(ammo_start.get(r.id, maxi(r.ammo, 1)))), 0.0, 1.0)
		draw_rect(Rect2(Vector2(rect.position.x, y), Vector2(rect.size.x, 2.0)), CARD_BAND)
		draw_rect(Rect2(Vector2(rect.position.x, y), Vector2(rect.size.x * am, 2.0)), AMMO_COLOR)
		y += 3.0
	# the portrait: the unit's own pixel soldier at parade scale
	var portrait := Rect2(Vector2(rect.position.x, y), Vector2(rect.size.x, rect.end.y - y))
	draw_rect(portrait, (side_colors[r.side] as Color).darkened(0.62))
	var ps := minf(3.4, portrait.size.y / 17.0)
	_draw_soldier(Vector2(portrait.get_center().x, portrait.end.y - 6.0), r.kind, side_colors[r.side], ps)
	if r.charging_ticks > 0 and r.active():
		draw_string(font, Vector2(rect.end.x - 17.0, band.end.y + 15.0), "»»",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
	# fallen and broken states shade the whole card
	if not r.alive():
		draw_rect(rect, Color(0.05, 0.04, 0.03, 0.78))
		_draw_skull(rect.get_center(), 7.0)
	elif r.routed:
		draw_rect(rect, Color(0.45, 0.45, 0.45, 0.45))
		_draw_white_flag(rect.get_center())
	# archetype notch at the card's foot, TW-style
	var nc := Vector2(rect.get_center().x, rect.end.y - 1.0)
	draw_circle(nc, 9.0, CARD_BAND)
	draw_arc(nc, 9.0, PI, TAU, 16, Color("6b5a3a"), 1.5)
	_draw_arch_icon(nc + Vector2(0, -2.5), _card_archetype(r))
	if r.id == selected_id:
		draw_rect(rect, GOLD, false, 2.0)
	else:
		draw_rect(rect, Color("3a2b1c"), false, 1.0)


func _draw_commander_card(rect: Rect2) -> void:
	var font := get_theme_default_font()
	draw_rect(rect, CARD_BG)
	var band := Rect2(rect.position, Vector2(rect.size.x, 13.0))
	draw_rect(band, Color("3a2b1c"))
	var is_hero := not (sim.heroes[0] as Dictionary).is_empty()
	var cmdr_tag := "CMDR"
	if is_hero:
		cmdr_tag = "L%d" % int(sim.heroes[0].get("level", 1))
	draw_string(font, band.position + Vector2(3, 10), cmdr_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GOLD)
	var y := band.end.y + 1.0
	if is_hero:
		# the hero's personal HP, TW-style: a red strip under the band
		var hp := clampf(float(sim.hero_hp[0]) / maxf(1.0, float(sim.heroes[0].get("hp_max", 40))), 0.0, 1.0)
		draw_rect(Rect2(Vector2(rect.position.x, y), Vector2(rect.size.x, 3.0)), CARD_BAND)
		draw_rect(Rect2(Vector2(rect.position.x, y), Vector2(rect.size.x * hp, 3.0)), Color("c9403a"))
		y += 4.0
	var portrait := Rect2(Vector2(rect.position.x, y), Vector2(rect.size.x, rect.end.y - y))
	draw_rect(portrait, (side_colors[0] as Color).darkened(0.5))
	var base := Vector2(portrait.get_center().x, portrait.end.y - 7.0)
	var ps := minf(3.4, portrait.size.y / 17.0)
	if is_hero:
		_draw_hero_card_portrait(base, ps, sim.heroes[0])
	else:
		_draw_soldier(base, "sword", side_colors[0], ps)
		# the plume marks an ordinary commander out among his own
		draw_line(base + Vector2(0.0, -9.0) * ps, base + Vector2(-3.0, -13.0) * ps, GOLD, 2.5)
	# a fallen hero shades his own card, exactly like a fallen line
	if is_hero and str(sim.hero_state[0]) in ["unconscious", "stable", "dead"]:
		draw_rect(rect, Color(0.05, 0.04, 0.03, 0.68))
		_draw_skull(rect.get_center(), 7.0)
	var nc := Vector2(rect.get_center().x, rect.end.y - 1.0)
	draw_circle(nc, 9.0, CARD_BAND)
	draw_arc(nc, 9.0, PI, TAU, 16, GOLD, 1.5)
	_draw_arch_icon(nc + Vector2(0, -2.5), "crown")
	if commander_selected:
		draw_rect(rect, GOLD, false, 2.0)
	else:
		draw_rect(rect, GOLD.darkened(0.35), false, 1.0)


func _draw_hero_card_portrait(base: Vector2, s: float, hero: Dictionary) -> void:
	var raw = hero.get("appearance", {})
	var profile: Dictionary = raw if raw is Dictionary else {}
	var skin := Appearance.profile_color(profile, "skin_color", SKIN)
	var hair := Appearance.profile_color(profile, "hair_color", Color("4f321c"))
	var eyes := Appearance.profile_color(profile, "eye_color", Color("526f82"))
	var style := clampi(int(profile.get("hair_style", 0)), 0, 3)
	var female := bool(profile.get("is_female", false))
	var beard := clampf(float(profile.get("beard", 0.0)), 0.0, 1.0)
	var face_width := lerpf(1.82, 2.25, clampf(float(profile.get("face_width", 0.5)), 0.0, 1.0))
	var role := str(hero.get("class", "fighter"))
	var cloth: Color = side_colors[0]

	_draw_pixel_shadow(base + Vector2(0, 2.0) * s, 8.5, 2.5, s)
	draw_line(base + Vector2(-1.4, -0.4) * s, base + Vector2(-2.5, 3.8) * s,
		Color("1a1511"), maxf(1.0, s * 0.85))
	draw_line(base + Vector2(1.2, -0.4) * s, base + Vector2(2.1, 3.8) * s,
		Color("1a1511"), maxf(1.0, s * 0.85))
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-3.5, -7.0) * s, base + Vector2(3.0, -7.1) * s,
		base + Vector2(3.7, -1.0) * s, base + Vector2(1.5, 0.7) * s,
		base + Vector2(-1.6, 0.7) * s, base + Vector2(-3.9, -1.0) * s,
	]), cloth.darkened(0.08))
	draw_rect(Rect2(base + Vector2(-2.2, -6.2) * s, Vector2(4.4, 4.3) * s), cloth.lightened(0.10))
	draw_line(base + Vector2(-3.0, -5.2) * s, base + Vector2(-4.8, -2.1) * s,
		skin.darkened(0.10), maxf(1.0, s * 0.78))
	draw_line(base + Vector2(3.0, -5.2) * s, base + Vector2(4.8, -2.0) * s,
		skin.darkened(0.10), maxf(1.0, s * 0.78))

	var head := base + Vector2(0.0, -9.2) * s
	var fw := face_width * s
	var fh := 2.15 * s
	if (female and style != 1) or style == 2:
		draw_colored_polygon(PackedVector2Array([
			head + Vector2(-fw * 0.95, -fh * 0.65), head + Vector2(fw * 0.78, -fh * 0.72),
			head + Vector2(fw * 0.94, fh * 1.45), head + Vector2(fw * 0.28, fh * 2.05),
			head + Vector2(-fw * 0.78, fh * 1.72), head + Vector2(-fw * 1.04, fh * 0.10),
		]), hair.darkened(0.14))
	if bool(profile.get("has_horns", false)):
		var horn := hair.darkened(0.35).lerp(Color("493d38"), 0.45)
		draw_colored_polygon(PackedVector2Array([
			head + Vector2(-fw * 0.62, -fh * 0.72), head + Vector2(-fw * 1.12, -fh * 2.10),
			head + Vector2(-fw * 0.05, -fh * 1.05),
		]), horn)
		draw_colored_polygon(PackedVector2Array([
			head + Vector2(fw * 0.20, -fh * 0.96), head + Vector2(fw * 0.52, -fh * 2.00),
			head + Vector2(fw * 0.82, -fh * 0.70),
		]), horn.lightened(0.05))
	var ear_kind := str(profile.get("ear_kind", "round"))
	if ear_kind == "pointed":
		draw_colored_polygon(PackedVector2Array([
			head + Vector2(-fw * 0.82, -fh * 0.22), head + Vector2(-fw * 1.65, -fh * 0.36),
			head + Vector2(-fw * 0.84, fh * 0.35),
		]), skin.darkened(0.06))
	elif ear_kind == "broad":
		draw_circle(head + Vector2(-fw * 1.02, 0.0), fh * 0.52, skin.darkened(0.06))

	# Asymmetric eight-point head: a tiny three-quarter version of FaceView.
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-fw * 0.72, -fh * 0.86), head + Vector2(-fw * 0.10, -fh * 1.05),
		head + Vector2(fw * 0.52, -fh * 0.90), head + Vector2(fw * 0.94, -fh * 0.36),
		head + Vector2(fw * 0.92, fh * 0.22), head + Vector2(fw * 0.54, fh * 0.88),
		head + Vector2(fw * 0.06, fh * 1.08), head + Vector2(-fw * 0.68, fh * 0.74),
		head + Vector2(-fw * 0.94, fh * 0.08), head + Vector2(-fw * 0.91, -fh * 0.48),
	]), skin)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(fw * 0.10, -fh * 0.92), head + Vector2(fw * 0.55, -fh * 0.82),
		head + Vector2(fw * 0.91, -fh * 0.30), head + Vector2(fw * 0.88, fh * 0.28),
		head + Vector2(fw * 0.45, fh * 0.80), head + Vector2(fw * 0.04, fh * 0.72),
	]), Color(skin.darkened(0.21), 0.30))
	draw_circle(head + Vector2(fw * 0.42, -fh * 0.22), maxf(1.0, s * 0.42), eyes)
	draw_circle(head + Vector2(fw * 0.45, -fh * 0.21), maxf(0.5, s * 0.16), Color("17130f"))
	draw_circle(head + Vector2(-fw * 0.28, -fh * 0.27), maxf(0.75, s * 0.31), eyes.darkened(0.08))
	draw_line(head + Vector2(fw * 0.18, -fh * 0.05), head + Vector2(fw * 0.82, fh * 0.20),
		skin.darkened(0.24), maxf(0.7, s * 0.28))
	if bool(profile.get("has_tusks", false)):
		draw_line(head + Vector2(fw * 0.38, fh * 0.55), head + Vector2(fw * 0.52, fh * 0.88),
			Color("ead9b3"), maxf(0.8, s * 0.30))

	match style:
		0, 2:
			draw_colored_polygon(PackedVector2Array([
				head + Vector2(-fw * 0.92, -fh * 0.42), head + Vector2(-fw * 0.60, -fh * 0.94),
				head + Vector2(-fw * 0.04, -fh * 1.16), head + Vector2(fw * 0.72, -fh * 0.86),
				head + Vector2(fw * 0.22, -fh * 0.66), head + Vector2(-fw * 0.24, -fh * 0.72),
			]), hair)
		1:
			draw_arc(head + Vector2(0, -fh * 0.10), fw, PI, TAU, 10, hair.darkened(0.08), maxf(1.0, s * 0.70))
		3:
			for i in 5:
				var t := float(i) / 4.0
				draw_circle(head + Vector2(lerpf(-fw * 0.72, fw * 0.62, t),
					-fh * (0.82 + sin(t * PI) * 0.24)), maxf(1.0, s * 0.43), hair)
	if not female and beard > 0.45 and int(profile.get("age", 30)) >= 16:
		var drop := fh * lerpf(0.18, 0.78, (beard - 0.45) / 0.55)
		draw_colored_polygon(PackedVector2Array([
			head + Vector2(-fw * 0.56, fh * 0.50), head + Vector2(-fw * 0.32, fh * 0.90),
			head + Vector2(fw * 0.04, fh + drop), head + Vector2(fw * 0.52, fh * 0.76),
			head + Vector2(fw * 0.44, fh * 0.49), head + Vector2(fw * 0.04, fh * 0.63),
		]), hair.darkened(0.08))

	# Equipment remains class-readable around the personal portrait.
	if role in ["wizard", "sorcerer", "cleric", "druid", "warlock", "bard"]:
		draw_line(base + Vector2(4.8, 2.0) * s, base + Vector2(6.0, -13.0) * s,
			Color("765b35"), maxf(1.0, s * 0.55))
		draw_circle(base + Vector2(6.0, -13.0) * s, maxf(1.0, s * 0.60), GOLD)
	else:
		draw_line(base + Vector2(4.4, -2.0) * s, base + Vector2(8.8, -10.0) * s,
			Color("c7c8c3"), maxf(1.0, s * 0.62))
	draw_line(head + Vector2(0, -fh * 0.86), head + Vector2(-fw * 1.25, -fh * 2.15), GOLD, maxf(1.0, s * 0.55))


func _draw_skull(c: Vector2, s: float) -> void:
	draw_circle(c, s, Color("d8d2c4"))
	draw_rect(Rect2(c + Vector2(-s * 0.45, s * 0.5), Vector2(s * 0.9, s * 0.5)), Color("d8d2c4"))
	draw_rect(Rect2(c + Vector2(-s * 0.5, -s * 0.3), Vector2(s * 0.35, s * 0.4)), CARD_BAND)
	draw_rect(Rect2(c + Vector2(s * 0.15, -s * 0.3), Vector2(s * 0.35, s * 0.4)), CARD_BAND)


func _draw_white_flag(c: Vector2) -> void:
	draw_line(c + Vector2(-2, 10), c + Vector2(-2, -10), Color("3a2b1c"), 2.0)
	draw_rect(Rect2(c + Vector2(-1, -10), Vector2(11, 7)), Color("e8e2d4"))


func _draw_arch_icon(c: Vector2, t: String) -> void:
	match t:
		"sword":
			draw_line(c + Vector2(-3.5, 3.5), c + Vector2(3.5, -3.5), CARD_INK, 1.6)
			draw_line(c + Vector2(-2.5, -1.0), c + Vector2(0.5, 2.0), CARD_INK, 1.4)
		"spear":
			draw_line(c + Vector2(0, 4.5), c + Vector2(0, -3.0), CARD_INK, 1.4)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -5.5), c + Vector2(-2.2, -2.2), c + Vector2(2.2, -2.2)]), CARD_INK)
		"missile":
			draw_arc(c + Vector2(-1.0, 0), 4.5, -PI * 0.45, PI * 0.45, 10, CARD_INK, 1.5)
			draw_line(c + Vector2(0.4, -4.4), c + Vector2(0.4, 4.4), CARD_INK, 1.0)
		"cavalry":
			draw_arc(c + Vector2(0, 0.5), 4.0, PI * 1.05, PI * 1.95, 10, CARD_INK, 1.8)
			draw_line(c + Vector2(-3.8, 1.4), c + Vector2(-3.8, 3.4), CARD_INK, 1.8)
			draw_line(c + Vector2(3.8, 1.4), c + Vector2(3.8, 3.4), CARD_INK, 1.8)
		"caster":
			draw_line(c + Vector2(0, -5), c + Vector2(0, 5), CARD_INK, 1.2)
			draw_line(c + Vector2(-5, 0), c + Vector2(5, 0), CARD_INK, 1.2)
			draw_line(c + Vector2(-3, -3), c + Vector2(3, 3), CARD_INK, 1.0)
			draw_line(c + Vector2(-3, 3), c + Vector2(3, -3), CARD_INK, 1.0)
		"support":
			draw_line(c + Vector2(-2, 5), c + Vector2(-2, -5), CARD_INK, 1.2)
			draw_rect(Rect2(c + Vector2(-1, -5), Vector2(6, 4)), CARD_INK)
		"silence":
			_draw_skull(c + Vector2(0, -0.5), 3.5)
		"crown":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-5, 3), c + Vector2(-5, -2), c + Vector2(-2.5, 0.5), c + Vector2(0, -3.5),
				c + Vector2(2.5, 0.5), c + Vector2(5, -2), c + Vector2(5, 3)]), CARD_INK)


# ---------------------------------------------------------------- HUD

func _refresh_unit_panel() -> void:
	if commander_selected and not (sim.commanders[0] as Dictionary).is_empty():
		var info: Dictionary = sim.commanders[0]
		unit_panel.visible = true
		unit_name.text = str(info.get("name", "The Commander"))
		unit_status.text = "Commander of %s" % str(side_names[0])
		unit_status.add_theme_color_override("font_color", GOLD)
		var lines := "Martial  %d\nIntrigue  %d\nProwess  %d" % [
			int(info.get("martial", 0)), int(info.get("intrigue", 0)), int(info.get("prowess", 0))]
		var h: Dictionary = sim.heroes[0]
		if not h.is_empty():
			lines += "\nHero: Level %d %s%s" % [int(h.get("level", 1)),
				HeroDB.class_label(str(h.get("class", ""))),
				" — LEGENDARY" if bool(h.get("legendary", false)) else ""]
			if str(h.get("subclass", "")) != "":
				lines += "\n%s" % HeroDB.sub_label(str(h.get("subclass", "")))
			lines += "\nPersonal HP: %d / %d" % [int(sim.hero_hp[0]), int(h.get("hp_max", 40))]
			if sim.hero_units[0] != null:
				var actor: BattleSim.HeroRuntime = sim.hero_units[0]
				lines += "\nField role: %s · Weight %.1f" % [actor.role.capitalize(), actor.weight()]
				if actor.raging():
					lines += "\nRAGING — physical damage halved"
				if actor.shaped():
					lines += "\nWILD SHAPE: %d / %d temporary HP" % [int(actor.wild_shape_hp), int(actor.wild_shape_hp_max)]
			match str(sim.hero_state[0]):
				"unconscious":
					lines += "\nDOWN — rolling death saves"
				"stable":
					lines += "\nCarried from the field, alive"
				"dead":
					lines += "\nDEAD"
		var traits: Array = info.get("traits", [])
		if not traits.is_empty():
			lines += "\nTraits: %s" % ", ".join(PackedStringArray(traits))
		if str(info.get("faith", "")) != "":
			lines += "\nFaith: %s" % str(info.get("faith"))
		if traits.has("Oath-Sworn"):
			lines += "\nOath-token: %s" % ("whole" if bool(info.get("oath_intact", true)) else "BROKEN")
		if float(sim.commander_stress[0]) > 0.0:
			lines += "\nStress taken: %.1f" % float(sim.commander_stress[0])
		if float(sim.commander_corruption[0]) > 0.0:
			lines += "\nCorruption taken: %.1f" % float(sim.commander_corruption[0])
		unit_stats.text = lines
		return
	if selected_id < 0 or selected_id >= sim.regiments.size():
		unit_panel.visible = false
		return
	var r: BattleSim.Regiment = sim.regiments[selected_id]
	unit_panel.visible = true
	unit_name.text = r.label
	var mor := r.morale()
	var word := "Broken"
	var word_color := Color("d24a35")
	if not r.routed:
		if mor > 66.0:
			word = "Confident"
			word_color = Color("6fbf4f")
		elif mor > 33.0:
			word = "Steady"
			word_color = Color("d9b13a")
		else:
			word = "Wavering"
			word_color = Color("d9853a")
	unit_status.text = "%d men · %s" % [r.soldiers, word]
	unit_status.add_theme_color_override("font_color", word_color)
	var text := "Armour  %d\nShield  %d%%\nLeadership  %d\nSpeed  %d\nMelee Attack  %d\nMelee Defence  %d\nWeapon Strength  %d\nCharge Bonus  %d\nFrontage  %d files" % [
		int(r.armour), int(r.shield * 100.0), int(r.leadership), int(r.speed),
		int(r.ma), int(r.md), int(r.ws), int(r.charge_bonus), r.files_now()]
	if r.rng_range > 0.0:
		text += "\nAmmunition  %d" % r.ammo
	unit_stats.text = text


func _on_battle_ended(winner_side: int) -> void:
	over = true
	speed_scale = 0.0
	var loser := 1 - winner_side if winner_side >= 0 else -1
	var loss := 0.0
	if loser >= 0:
		loss = 1.0 - sim.survivors_fraction(loser)

	end_box = CenterContainer.new()
	end_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var head := Label.new()
	head.add_theme_font_size_override("font_size", 22)
	if winner_side == 0:
		head.text = "Victory!"
		head.add_theme_color_override("font_color", Color("6fbf4f"))
	elif winner_side == 1:
		head.text = "Defeat"
		head.add_theme_color_override("font_color", Color("d24a35"))
	else:
		head.text = "Mutual Ruin"
		head.add_theme_color_override("font_color", GOLD)
	box.add_child(head)
	var detail := Label.new()
	detail.text = "%s: %d%% of your men stand.\n%s: %d%% of theirs remain." % [
		str(side_names[0]), int(sim.survivors_fraction(0) * 100.0),
		str(side_names[1]), int(sim.survivors_fraction(1) * 100.0)]
	box.add_child(detail)
	var btn := Button.new()
	btn.text = "Return to the Realm"
	btn.pressed.connect(func() -> void: finished.emit(winner_side, loss))
	box.add_child(btn)
	end_box.add_child(panel)
	add_child(end_box)
