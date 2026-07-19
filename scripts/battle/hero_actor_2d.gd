class_name HeroActor2D
extends Node2D

## Visual adapter for BattleSim.HeroRuntime. Physics stays in the deterministic
## aggregate simulation; this node gives the independent entity a readable
## pixel-art body, class silhouette, state animation, and personal HP bar.

const GOLD := Color("d9c07a")
const INK := Color("17130f")
const SKIN := Color("caa07a")
const STEEL := Color("b9bab4")
const Appearance = preload("res://scripts/portrait_appearance.gd")

var sim: BattleSim
var side := 0
var side_color := Color("3f5f83")
var selected := false
var animation_time := 0.0


func configure(p_sim: BattleSim, p_side: int, color: Color) -> void:
	sim = p_sim
	side = p_side
	side_color = color
	z_index = 0


func appearance_profile() -> Dictionary:
	if sim == null or side < 0 or side >= sim.heroes.size():
		return {}
	var hero = sim.heroes[side]
	if not (hero is Dictionary):
		return {}
	var raw = (hero as Dictionary).get("appearance", {})
	return raw if raw is Dictionary else {}


func _appearance_color(key: String, fallback: Color) -> Color:
	return Appearance.profile_color(appearance_profile(), key, fallback)


func _appearance_number(key: String, fallback: float = 0.5) -> float:
	return clampf(float(appearance_profile().get(key, fallback)), 0.0, 1.0)


func _skin_color() -> Color:
	return _appearance_color("skin_color", SKIN)


func _hair_color() -> Color:
	return _appearance_color("hair_color", Appearance.DEFAULT_HAIR)


func _eye_color() -> Color:
	return _appearance_color("eye_color", Appearance.DEFAULT_EYE)


func sync_from_view(view, is_selected: bool) -> void:
	selected = is_selected
	animation_time = view.battle_time
	visible = sim != null and side < sim.hero_units.size() and sim.hero_units[side] != null
	if not visible:
		return
	position = view._to_screen(sim.hero_pos(side))
	scale = Vector2.ONE * view._scale()
	# The unit-card bar is drawn by BattleView itself (not as a child
	# Control), so explicitly occlude actors that move behind it.
	var card_bar: Rect2 = view._card_layout()["bar"]
	if card_bar.size.x > 0.0 and card_bar.grow(sim.hero_radius(side) * view._scale()).has_point(position):
		visible = false
		return
	queue_redraw()


func _draw() -> void:
	if sim == null or sim.hero_units[side] == null:
		return
	var unit: BattleSim.HeroRuntime = sim.hero_units[side]
	var state := str(sim.hero_state[side])
	var radius := unit.radius()
	if selected:
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 32, GOLD, 1.5)
	if unit.raging():
		var pulse := 0.45 + 0.15 * sin(animation_time * 9.0)
		draw_circle(Vector2.ZERO, radius + 2.5, Color(0.85, 0.18, 0.08, pulse * 0.25))
		draw_arc(Vector2.ZERO, radius + 2.5, 0.0, TAU, 24, Color(0.95, 0.32, 0.12, pulse), 1.0)
	if state != "fighting":
		_draw_fallen(unit, state)
		_draw_health(unit)
		return
	if unit.shaped():
		_draw_war_beast(unit)
	else:
		_draw_humanoid(unit)
	_draw_health(unit)


func _facing_sign(unit: BattleSim.HeroRuntime) -> float:
	if absf(unit.facing.x) >= 0.1:
		return signf(unit.facing.x)
	return 1.0 if side == 0 else -1.0


func _attack_lunge(unit: BattleSim.HeroRuntime) -> float:
	var elapsed := animation_time - float(unit.attack_phase) * BattleSim.TICK_SECONDS
	if elapsed < 0.0 or elapsed > 0.42:
		return 0.0
	return sin((elapsed / 0.42) * PI)


func _draw_humanoid(unit: BattleSim.HeroRuntime) -> void:
	var facing := _facing_sign(unit)
	var lunge := _attack_lunge(unit)
	var p := Vector2(facing * lunge * 2.0, 0.0)
	draw_ellipse_shadow(Vector2(0.0, 4.8), Vector2(6.2, 2.0), Color(0.08, 0.10, 0.05, 0.42))
	# cloak, torso, boots
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-4.2, -1.0), p + Vector2(3.8, -1.0),
		p + Vector2(5.0, 5.2), p + Vector2(-5.0, 5.2),
	]), side_color.darkened(0.08))
	draw_rect(Rect2(p + Vector2(-4.3, 1.0), Vector2(8.6, 1.4)), side_color.lightened(0.18))
	draw_line(p + Vector2(-2.0, 4.2), p + Vector2(-2.0, 6.1), INK, 1.7)
	draw_line(p + Vector2(2.0, 4.2), p + Vector2(2.0, 6.1), INK, 1.7)
	# The tiny face is the same inherited phenotype as the campaign portrait,
	# reduced to a readable three-quarter pixel silhouette.
	_draw_hero_head(p + Vector2(0.0, -4.0), facing, unit.role)
	# Class-readable equipment silhouette.
	match unit.role:
		"caster", "support":
			var hand := p + Vector2(facing * 3.5, 0.0)
			draw_circle(hand, 0.85, _skin_color().darkened(0.04))
			draw_line(hand + Vector2(0, 4.0), hand + Vector2(facing * 1.5, -8.0), Color("765b35"), 1.5)
			draw_circle(hand + Vector2(facing * 1.5, -8.0), 1.4, GOLD)
		"flanker":
			var hand2 := p + Vector2(facing * 3.0, 0.5)
			draw_circle(hand2, 0.75, _skin_color().darkened(0.05))
			draw_line(hand2, hand2 + Vector2(facing * (5.0 + lunge * 2.5), -1.0), STEEL, 1.4)
		_:
			var hand3 := p + Vector2(facing * 2.8, 0.2)
			draw_circle(hand3, 0.78, _skin_color().darkened(0.05))
			draw_line(hand3, hand3 + Vector2(facing * (6.5 + lunge * 3.0), -2.8), STEEL, 1.7)
			draw_line(hand3 + Vector2(facing * 0.3, -1.0), hand3 + Vector2(facing * 2.0, 1.0), GOLD, 1.2)
	# The small gold plume makes heroes legible amid same-color soldiers.
	draw_line(p + Vector2(0.0, -7.2), p + Vector2(-facing * 2.0, -10.0), GOLD, 1.8)


func _oriented_points(center: Vector2, facing: float, local_points: PackedVector2Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in local_points:
		points.append(center + Vector2(point.x * facing, point.y))
	return points


func _draw_hero_head(center: Vector2, facing: float, role: String) -> void:
	var profile := appearance_profile()
	var skin := _skin_color()
	var skin_shadow := _appearance_color("skin_shadow", skin.darkened(0.20))
	var hair := _hair_color()
	var eyes := _eye_color()
	var style := clampi(int(profile.get("hair_style", 0)), 0, 3)
	var texture := clampf(float(profile.get("hair_texture", 0.5)), 0.0, 1.0)
	var female := bool(profile.get("is_female", false))
	var age := int(profile.get("age", 30))
	var face_width := clampf(float(profile.get("face_width", 0.5)), 0.0, 1.0)
	var jaw := clampf(float(profile.get("jaw", 0.5)), 0.0, 1.0)
	var fw := lerpf(2.85, 3.65, face_width)
	var jaw_w := fw * lerpf(0.58, 0.82, jaw)
	var long_hair := (female and style != 1) or style == 2

	# Rear paper-doll layers: long hair, ancestry ears, and horns.
	if long_hair:
		draw_colored_polygon(_oriented_points(center, facing, PackedVector2Array([
			Vector2(-fw * 0.88, -2.4), Vector2(fw * 0.72, -2.7),
			Vector2(fw * 0.92, 0.0), Vector2(fw * 0.65, 4.8),
			Vector2(-fw * 0.55, 4.5), Vector2(-fw * 1.00, 0.2),
		])), hair.darkened(0.15))
	if bool(profile.get("has_horns", false)):
		var horn := hair.darkened(0.30).lerp(Color("493d38"), 0.45)
		draw_colored_polygon(_oriented_points(center, facing, PackedVector2Array([
			Vector2(-fw * 0.66, -2.25), Vector2(-fw * 1.18, -5.65), Vector2(-fw * 0.10, -3.00),
		])), horn)
		draw_colored_polygon(_oriented_points(center, facing, PackedVector2Array([
			Vector2(fw * 0.28, -2.75), Vector2(fw * 0.62, -5.25), Vector2(fw * 0.92, -2.05),
		])), horn.lightened(0.04))

	var ear_kind := str(profile.get("ear_kind", "round"))
	var ear_center := center + Vector2(-facing * fw * 0.88, -0.05)
	match ear_kind:
		"pointed":
			draw_colored_polygon(PackedVector2Array([
				ear_center + Vector2(facing * 0.30, -0.85),
				ear_center + Vector2(-facing * fw * 0.95, -0.28),
				ear_center + Vector2(facing * 0.20, 0.90),
			]), skin.darkened(0.06))
		"broad":
			draw_circle(ear_center + Vector2(-facing * 0.30, 0.0), 1.25, skin.darkened(0.06))
			draw_line(ear_center, ear_center + Vector2(-facing * 0.72, 0.15), skin_shadow, 0.65)
		_:
			draw_circle(ear_center, 0.95, skin.darkened(0.04))

	var face := _oriented_points(center, facing, PackedVector2Array([
		Vector2(-fw * 0.68, -2.75), Vector2(-fw * 0.12, -3.45),
		Vector2(fw * 0.48, -3.08), Vector2(fw * 0.88, -1.55),
		Vector2(fw * 0.92, 0.20), Vector2(jaw_w, 2.05),
		Vector2(fw * 0.20, 3.32), Vector2(-jaw_w * 0.86, 2.35),
		Vector2(-fw * 0.94, 0.35), Vector2(-fw * 0.90, -1.35),
	]))
	draw_colored_polygon(face, skin)
	draw_colored_polygon(_oriented_points(center, facing, PackedVector2Array([
		Vector2(fw * 0.08, -3.08), Vector2(fw * 0.52, -2.90),
		Vector2(fw * 0.88, -1.45), Vector2(fw * 0.90, 0.30),
		Vector2(jaw_w * 0.75, 1.95), Vector2(fw * 0.10, 2.85),
	])), Color(skin_shadow, 0.32))

	# Unequal eye placement and a projecting nose preserve the portrait's
	# three-quarter turn, even at battlefield scale.
	var near_eye := center + Vector2(facing * fw * 0.42, -0.78)
	var far_eye := center + Vector2(-facing * fw * 0.32, -0.91)
	draw_circle(far_eye, 0.34, eyes.darkened(0.10))
	draw_circle(near_eye, 0.48, eyes.lightened(0.08))
	draw_circle(near_eye + Vector2(facing * 0.07, 0.02), 0.18, INK)
	draw_line(center + Vector2(facing * 0.42, -0.35), center + Vector2(facing * fw * 0.82, 0.38),
		skin_shadow, 0.75)
	draw_circle(center + Vector2(facing * fw * 0.82, 0.42), 0.38, skin.darkened(0.07))
	draw_line(center + Vector2(facing * 0.15, 1.55), center + Vector2(facing * fw * 0.48, 1.48),
		skin.darkened(0.38), 0.65)
	if bool(profile.get("has_tusks", false)):
		var tusk := Color("ead9b3")
		draw_line(center + Vector2(facing * fw * 0.34, 1.47), center + Vector2(facing * fw * 0.50, 2.05), tusk, 0.80)
	if age >= 52:
		draw_line(near_eye + Vector2(-facing * 0.60, 0.65), near_eye + Vector2(facing * 0.20, 0.76),
			Color(skin_shadow, 0.62), 0.55)

	# Foreground hair keeps all four inherited styles distinct.
	match style:
		0:
			draw_colored_polygon(_oriented_points(center, facing, PackedVector2Array([
				Vector2(-fw * 0.86, -1.55), Vector2(-fw * 0.62, -2.92),
				Vector2(-fw * 0.08, -3.70), Vector2(fw * 0.72, -2.85),
				Vector2(fw * 0.18, -2.35), Vector2(-fw * 0.25, -2.55),
			])), hair)
		1:
			draw_arc(center + Vector2(-facing * 0.05, -0.65), fw * 0.96, PI, TAU, 10,
				hair.darkened(0.08), 1.55 + texture * 0.55)
		2:
			draw_colored_polygon(_oriented_points(center, facing, PackedVector2Array([
				Vector2(-fw * 0.88, -1.55), Vector2(-fw * 0.62, -3.05),
				Vector2(-fw * 0.08, -3.62), Vector2(fw * 0.62, -3.00),
				Vector2(fw * 0.78, -1.72), Vector2(fw * 0.18, -2.52),
				Vector2(-fw * 0.12, -2.22),
			])), hair)
		3:
			for i in 5:
				var t := float(i) / 4.0
				var coil := center + Vector2(facing * lerpf(-fw * 0.72, fw * 0.60, t),
					-2.65 - sin(t * PI) * 0.85)
				draw_circle(coil, lerpf(0.72, 0.55, t), hair.lightened(0.025 * float(i % 2)))
	if female and style != 1:
		draw_line(center + Vector2(-facing * fw * 0.78, -1.25),
			center + Vector2(-facing * fw * 0.88, 3.75), hair.darkened(0.08), 1.15)

	var beard_gene := clampf(float(profile.get("beard", 0.0)), 0.0, 1.0)
	if not female and age >= 16 and beard_gene > 0.45:
		var fullness := clampf((beard_gene - 0.45) / 0.55, 0.0, 1.0)
		if fullness < 0.30:
			draw_line(center + Vector2(-facing * jaw_w * 0.66, 1.65),
				center + Vector2(facing * jaw_w * 0.55, 2.18), Color(hair, 0.55), 0.85)
		else:
			draw_colored_polygon(_oriented_points(center, facing, PackedVector2Array([
				Vector2(-jaw_w * 0.70, 1.45), Vector2(-jaw_w * 0.45, 2.55),
				Vector2(0.05, 3.20 + fullness * 1.45), Vector2(jaw_w * 0.58, 2.35),
				Vector2(jaw_w * 0.55, 1.45), Vector2(jaw_w * 0.15, 1.72),
				Vector2(-jaw_w * 0.18, 1.75),
			])), hair.darkened(0.08))

	# Class gear remains readable without replacing the inherited hair layer.
	match role:
		"caster", "support":
			draw_line(center + Vector2(-fw * 0.72, -2.05), center + Vector2(fw * 0.72, -2.05), GOLD, 0.75)
			draw_circle(center + Vector2(facing * 0.35, -2.12), 0.42, eyes.lightened(0.22))
		"flanker":
			draw_arc(center + Vector2(0.0, -0.20), fw + 0.35, PI * 0.92, TAU * 0.98, 12,
				side_color.darkened(0.28), 0.80)
		_:
			draw_line(center + Vector2(-fw * 0.78, -2.18), center + Vector2(fw * 0.74, -2.18),
				STEEL.darkened(0.08), 1.05)
			draw_line(center + Vector2(-facing * fw * 0.74, -2.05),
				center + Vector2(-facing * fw * 0.76, -0.20), STEEL.darkened(0.18), 0.75)


func _draw_war_beast(unit: BattleSim.HeroRuntime) -> void:
	var facing := _facing_sign(unit)
	var lunge := _attack_lunge(unit)
	var p := Vector2(facing * lunge * 2.8, 0.0)
	draw_ellipse_shadow(Vector2(0.0, 4.5), Vector2(9.2, 2.6), Color(0.08, 0.10, 0.05, 0.45))
	var fur := side_color.lerp(_hair_color(), 0.62)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-7.5, -2.0), p + Vector2(5.0, -3.2),
		p + Vector2(8.0, 1.3), p + Vector2(4.8, 4.0),
		p + Vector2(-7.0, 3.3),
	]), fur)
	draw_circle(p + Vector2(facing * 7.2, -2.0), 3.6, fur.lightened(0.06))
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(facing * 5.2, -4.3), p + Vector2(facing * 7.0, -7.0),
		p + Vector2(facing * 8.1, -4.0),
	]), fur.darkened(0.12))
	draw_circle(p + Vector2(facing * 8.4, -1.9), 0.55, INK)
	draw_line(p + Vector2(-4.5, 2.0), p + Vector2(-5.4, 6.1), INK, 2.0)
	draw_line(p + Vector2(3.5, 2.0), p + Vector2(4.7, 6.1), INK, 2.0)


func _draw_fallen(unit: BattleSim.HeroRuntime, state: String) -> void:
	var tint := Color("8f3d34") if state == "unconscious" else Color("6d685e")
	var skin := _skin_color()
	var hair := _hair_color()
	draw_ellipse_shadow(Vector2(0.0, 2.0), Vector2(8.0, 2.4), Color(0.08, 0.08, 0.05, 0.45))
	draw_rect(Rect2(Vector2(-7.0, -1.5), Vector2(11.0, 3.8)), side_color.lerp(tint, 0.55))
	draw_circle(Vector2(5.2, -0.2), 2.5, skin.lerp(tint, 0.35))
	draw_arc(Vector2(5.2, -0.5), 2.45, PI, TAU, 8, hair.lerp(tint, 0.30), 1.2)
	draw_line(Vector2(-4.0, -1.0), Vector2(7.0, -4.5), STEEL.darkened(0.35), 1.3)


func _draw_health(unit: BattleSim.HeroRuntime) -> void:
	var max_hp := maxf(1.0, float(sim.heroes[side].get("hp_max", 40.0)))
	var hp_fraction := clampf(float(sim.hero_hp[side]) / max_hp, 0.0, 1.0)
	var width := maxf(18.0, unit.radius() * 2.0)
	var y := -unit.radius() - 7.0
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width, 2.6)), INK)
	draw_rect(Rect2(Vector2(-width * 0.5, y), Vector2(width * hp_fraction, 2.6)), Color("c9403a"))
	if unit.shaped():
		var temp_fraction := clampf(unit.wild_shape_hp / maxf(1.0, unit.wild_shape_hp_max), 0.0, 1.0)
		draw_rect(Rect2(Vector2(-width * 0.5, y - 2.2), Vector2(width * temp_fraction, 1.5)), Color("73a85d"))


func draw_ellipse_shadow(center: Vector2, extents: Vector2, color: Color) -> void:
	# Polygon keeps the intentionally low-resolution pixel-art silhouette.
	var points := PackedVector2Array()
	for i in 12:
		var angle := TAU * float(i) / 12.0
		points.append(center + Vector2(cos(angle) * extents.x, sin(angle) * extents.y))
	draw_colored_polygon(points, color)
