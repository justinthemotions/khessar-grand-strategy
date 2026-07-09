class_name BattleView
extends Control

## Full-screen battle overlay: pixel-style soldier sprites in formation,
## floating banners with HP and morale bars, a unit panel bottom-left,
## and speed controls top-right. Left-click selects a regiment,
## right-click orders your (blue, side 0) regiments to move.

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


func start(roster_a: Array, roster_b: Array, lead_a: int, lead_b: int,
		p_side_names: Array, p_side_colors: Array, p_title: String,
		cmdr_traits_a: Array = [], cmdr_traits_b: Array = []) -> void:
	side_names = p_side_names
	side_colors = p_side_colors
	battle_title = p_title
	sim.setup_from_rosters(roster_a, roster_b, lead_a, lead_b, side_names, cmdr_traits_a, cmdr_traits_b)
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
	unit_panel.offset_top = -272.0
	unit_panel.offset_right = 244.0
	unit_panel.offset_bottom = -12.0
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


func _process(delta: float) -> void:
	if not over and speed_scale > 0.0:
		var scaled := delta * speed_scale
		sim.move_step(scaled)
		tick_accum += scaled
		while tick_accum >= BattleSim.TICK_SECONDS:
			tick_accum -= BattleSim.TICK_SECONDS
			sim.combat_tick()
			sim.ai_step(false)
		# consume fresh volleys from the sim and animate them
		for v in sim.volleys:
			arrows.append({"from": v["from"], "to": v["to"], "age": 0.0})
		sim.volleys.clear()
		var kept: Array = []
		for a in arrows:
			a["age"] = float(a["age"]) + scaled
			if float(a["age"]) < 0.5:
				kept.append(a)
		arrows = kept
	_refresh_unit_panel()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if over:
		return
	if event is InputEventMouseMotion:
		mouse_now = event.position
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected_id = -1
			for r: BattleSim.Regiment in sim.regiments:
				if r.alive() and _to_screen(r.pos).distance_to(event.position) < maxf(r.radius() * _scale(), 26.0):
					selected_id = r.id
					break
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if selected_id >= 0:
					var r: BattleSim.Regiment = sim.regiments[selected_id]
					if r.side == 0 and r.active():
						dragging = true
						drag_start = event.position
			elif dragging:
				dragging = false
				_issue_order(drag_start, event.position)


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

func _scale() -> float:
	return minf(size.x / sim.field.x, size.y / sim.field.y)


func _offset() -> Vector2:
	return (size - sim.field * _scale()) * 0.5


func _to_screen(p: Vector2) -> Vector2:
	return (_offset() + p * _scale()).floor()


func _to_field(p: Vector2) -> Vector2:
	return (p - _offset()) / _scale()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), GRASS_BASE)
	for patch in patches:
		var p: Vector2 = Vector2(patch["pos"].x * size.x, patch["pos"].y * size.y)
		var ps: float = patch["size"]
		match int(patch["kind"]):
			0:
				draw_rect(Rect2(p, Vector2(ps * 0.8, ps * 0.5)), ROCK)
			1, 2:
				draw_circle(p, ps * 0.9, TREE)
			_:
				draw_rect(Rect2(p, Vector2(ps, ps * 0.6)), GRASS_DARK if int(patch["kind"]) % 2 == 0 else GRASS_LIGHT)

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


func _draw_regiment(r: BattleSim.Regiment) -> void:
	var body: Color = side_colors[r.side]
	if r.routed:
		body = body.lerp(Color(0.5, 0.5, 0.5), 0.35)
	var files := r.files_now()
	var angle := r.facing.angle() + PI / 2.0
	for i in r.soldiers:
		var col := i % files
		var row := i / files
		var local := Vector2((float(col) - float(files - 1) * 0.5) * BattleSim.SPACING,
			float(row) * BattleSim.SPACING * 0.85)
		var jitter := Vector2(
			float((i * 2654435761 + r.id * 97) % 5) - 2.0,
			float((i * 40503 + r.id * 31) % 5) - 2.0) * 0.6
		if r.routed:
			jitter *= 4.0
		var world := r.pos + (local + jitter).rotated(angle)
		_draw_soldier(_to_screen(world), r.kind, body)


func _draw_soldier(p: Vector2, kind: String, body: Color) -> void:
	var s := _scale()
	if kind == "cav":
		draw_rect(Rect2(p + Vector2(-5, -3) * s, Vector2(10, 4) * s), HORSE)
		draw_rect(Rect2(p + Vector2(4, -5) * s, Vector2(3, 3) * s), HORSE)          # horse head
		draw_rect(Rect2(p + Vector2(-2, -8) * s, Vector2(4, 5) * s), body)          # rider
		draw_rect(Rect2(p + Vector2(-1.5, -11) * s, Vector2(3, 3) * s), HELMET)
		draw_line(p + Vector2(3, -10) * s, p + Vector2(6, -13) * s, HELMET, maxf(1.0, s))
	else:
		draw_rect(Rect2(p + Vector2(-2, -6) * s, Vector2(4, 6) * s), body)          # tunic
		draw_rect(Rect2(p + Vector2(-1.5, -9) * s, Vector2(3, 3) * s), HELMET)      # helm
		draw_rect(Rect2(p + Vector2(0, -1) * s, Vector2(1.5, 2) * s), SKIN)         # legs hint
		if kind == "levy":
			draw_line(p + Vector2(3, 1) * s, p + Vector2(3, -13) * s, HELMET, maxf(1.0, s))   # spear
			draw_rect(Rect2(p + Vector2(-5, -6) * s, Vector2(2.5, 4) * s), body.darkened(0.3))  # shield
		elif kind == "archer":
			draw_arc(p + Vector2(3.5, -4.5) * s, 3.2 * s, -1.25, 1.25, 8, Color("6b4a30"), maxf(1.0, s))  # bow
		else:
			draw_line(p + Vector2(3, -4) * s, p + Vector2(6, -9) * s, HELMET, maxf(1.0, s))   # sword
			draw_rect(Rect2(p + Vector2(-5, -6) * s, Vector2(2.5, 4) * s), body.darkened(0.3))  # shield


func _draw_banner(r: BattleSim.Regiment) -> void:
	if r.routed:
		return
	var top := _to_screen(r.pos) + Vector2(0, -r.radius() * _scale() - 12.0)
	var pole_base := top + Vector2(0, 16.0)
	draw_line(pole_base, top + Vector2(0, -14.0), Color("3a2b1c"), 2.0)
	var flag := Rect2(top + Vector2(1, -14.0), Vector2(18, 11))
	draw_rect(flag, side_colors[r.side])
	draw_rect(flag, Color("1c1410"), false, 1.0)
	draw_line(flag.position + Vector2(4, 8), flag.position + Vector2(14, 2), GOLD, 1.5)
	var bar_pos := top + Vector2(-12.0, 3.0)
	var hp := float(r.soldiers) / maxf(1.0, float(r.start_soldiers))
	var mor := clampf(r.morale() / BattleSim.START_MORALE, 0.0, 1.0)
	draw_rect(Rect2(bar_pos, Vector2(24, 3)), Color("1c1410"))
	draw_rect(Rect2(bar_pos, Vector2(24.0 * hp, 3)), HP_COLOR)
	draw_rect(Rect2(bar_pos + Vector2(0, 4), Vector2(24, 3)), Color("1c1410"))
	draw_rect(Rect2(bar_pos + Vector2(0, 4), Vector2(24.0 * mor, 3)), MORALE_COLOR)


# ---------------------------------------------------------------- HUD

func _refresh_unit_panel() -> void:
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
