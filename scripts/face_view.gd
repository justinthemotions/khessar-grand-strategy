class_name FaceView
extends Control

## Draws a procedural dynastic portrait from a genome plus character context.
## The renderer is a 2D paper-doll stack: rear hair, clothes, neck and ears,
## a three-quarter head, facial features, facial hair, foreground hair,
## culture-coded headwear, accessories, and finally the medallion rim.

signal pressed

const Appearance = preload("res://scripts/portrait_appearance.gd")

var genome: Dictionary = {}
var age: int = 30
var is_female: bool = false
var framed: bool = true
var context: Dictionary = {}


func set_person(p_genome: Dictionary, p_age: int, p_female: bool, p_context: Dictionary = {}) -> void:
	genome = p_genome
	age = p_age
	is_female = p_female
	context = p_context
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()


func _g(key: String, def: float = 0.5) -> float:
	return float(genome.get(key, def))


func _ctx(key: String, def = null):
	return context.get(key, def)


func _is_medallion() -> bool:
	var shape := str(_ctx("shape", "medallion"))
	return shape == "medallion" or bool(_ctx("medallion", false))


func _traits() -> Array:
	var raw = _ctx("traits", [])
	if raw is Array:
		return raw
	return []


func _hash01(value: String) -> float:
	return float(abs(value.hash()) % 1000) / 999.0


static func _ellipse(c: Vector2, rx: float, ry: float, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _lens(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(-rx, 0.0),
		c + Vector2(-rx * 0.55, -ry * 0.72),
		c + Vector2(0.0, -ry),
		c + Vector2(rx * 0.58, -ry * 0.60),
		c + Vector2(rx, 0.0),
		c + Vector2(rx * 0.52, ry * 0.70),
		c + Vector2(0.0, ry),
		c + Vector2(-rx * 0.58, ry * 0.62),
	])


static func _tilted_lens(c: Vector2, rx: float, ry: float, tilt: float) -> PackedVector2Array:
	var points := _lens(c, rx, ry)
	for i in points.size():
		var p := points[i]
		p.y += ((p.x - c.x) / maxf(rx, 0.001)) * tilt
		points[i] = p
	return points


static func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


func _portrait_pose(cx: float, head_c: Vector2, fw: float, fh: float) -> Dictionary:
	# Every portrait uses a three-quarter turn toward screen-right. Keeping the
	# pose consistent makes inherited differences legible across a family while
	# unequal eye, cheek, ear, and jaw spacing supplies the depth cue.
	var turn := lerpf(0.09, 0.15, _g("presence"))
	var axis_x := cx + fw * turn
	var spacing := lerpf(0.92, 1.08, _g("eye_spacing"))
	return {
		"axis_x": axis_x,
		"near_eye": Vector2(axis_x - fw * 0.39 * spacing, head_c.y - fh * 0.15),
		"far_eye": Vector2(axis_x + fw * 0.29 * spacing, head_c.y - fh * 0.17),
		"near_ear": Vector2(cx - fw * 0.91, head_c.y - fh * 0.015),
		"far_ear": Vector2(cx + fw * 0.79, head_c.y - fh * 0.045),
		"nose_root": Vector2(axis_x - fw * 0.015, head_c.y - fh * 0.08),
		"nose_tip": Vector2(axis_x + fw * lerpf(0.14, 0.25, _g("nose")), head_c.y + fh * lerpf(0.13, 0.22, _g("nose"))),
		"mouth": Vector2(axis_x + fw * 0.075, head_c.y + fh * 0.43),
		"chin": Vector2(axis_x + fw * 0.015, head_c.y + fh * lerpf(0.73, 0.86, _g("chin"))),
	}


func _skin_color() -> Color:
	return Appearance.skin_color(genome, str(_ctx("race", "human")), context)


func _hair_color() -> Color:
	return Appearance.hair_color(genome, age, context)


func _eye_color() -> Color:
	return Appearance.eye_color(genome, context)


func _realm_color() -> Color:
	var realm_id := int(_ctx("realm_id", -1))
	if realm_id == 0:
		return Color("8f2f2c")
	if realm_id == 1:
		return Color("355a70")
	var culture := str(_ctx("culture", ""))
	if culture == "veldarin" or culture == "thaladris":
		return Color("315a3e")
	if culture == "kharak_dum" or culture == "brushgate":
		return Color("60503a")
	if culture == "free_city" or culture == "halveni" or culture == "southern_reach":
		return Color("5c4b75")
	return Color("5d5244")


func _house_color() -> Color:
	var dynasty := str(_ctx("dynasty", "House"))
	var t := _hash01(dynasty)
	var red_gold := Color("6d2630").lerp(Color("a17b36"), fposmod(t * 1.7, 1.0))
	return red_gold.lerp(Color("264e58"), fposmod(t * 2.3, 1.0) * 0.45)


func _wear_level() -> float:
	var traits := _traits()
	var wear := clampf((age - 35.0) / 40.0, 0.0, 0.65)
	if traits.has("Craven") or traits.has("Simple"):
		wear += 0.12
	if traits.has("Ambitious") or traits.has("Cruel"):
		wear += 0.08
	if bool(_ctx("ruler", false)):
		wear += 0.08
	return clampf(wear, 0.0, 1.0)


func _beauty_score() -> float:
	var centered := 1.0 - (
		absf(_g("face_width") - 0.48) +
		absf(_g("jaw") - 0.45) +
		absf(_g("chin") - 0.46) +
		absf(_g("mouth") - 0.54) +
		absf(_g("eye_spacing") - 0.52)
	) / 2.5
	var traits := _traits()
	var score := centered * 0.38 + _g("symmetry") * 0.32 + _g("presence") * 0.22 + _g("eye_size") * 0.08
	if traits.has("Genial"):
		score += 0.08
	if traits.has("Shrewd"):
		score += 0.04
	if traits.has("Cruel") or traits.has("Simple"):
		score -= 0.08
	return clampf(score, 0.0, 1.0)


func _menace_score() -> float:
	var traits := _traits()
	var score := _g("severity") * 0.36 + _g("brow") * 0.22 + _g("jaw") * 0.14 + _wear_level() * 0.18
	if traits.has("Cruel"):
		score += 0.18
	if traits.has("Strong") or traits.has("Brave"):
		score += 0.08
	if _beauty_score() > 0.72:
		score -= 0.05
	return clampf(score, 0.0, 1.0)


func _irregularity() -> float:
	return clampf((1.0 - _g("symmetry")) * 0.65 + _wear_level() * 0.25 + _g("severity") * 0.12, 0.0, 1.0)


func _draw_medallion_background(s: float) -> void:
	var center := size * 0.5
	var r := s * 0.485
	var menace := _menace_score()
	var realm := _realm_color()
	var base := Color("252a30").lerp(realm.darkened(0.34), 0.50).lerp(Color("121114"), menace * 0.25)
	var stone := Color("74736d").lerp(Color("343337"), menace * 0.48)
	var recess := Color("26333b").lerp(realm.darkened(0.42), 0.36)
	var trim := stone.lightened(0.13)

	draw_circle(center, r, Color("080706"))
	draw_circle(center, r * 0.955, base)
	# A quiet hall/arcade backdrop gives the CK-like sense that each person is
	# posed in a place, while staying subdued enough for small UI portraits.
	draw_rect(Rect2(center + Vector2(-r * 0.70, -r * 0.59), Vector2(r * 1.40, r * 1.14)), recess)
	draw_arc(center + Vector2(-r * 0.08, r * 0.06), r * 0.55, PI, TAU, 28,
		_with_alpha(trim, 0.42), maxf(1.0, s * 0.010), true)
	draw_arc(center + Vector2(-r * 0.08, r * 0.06), r * 0.46, PI, TAU, 28,
		_with_alpha(stone.darkened(0.20), 0.72), maxf(1.0, s * 0.016), true)
	for xoff in [-0.62, 0.48]:
		var x: float = center.x + r * float(xoff)
		draw_rect(Rect2(Vector2(x - r * 0.075, center.y - r * 0.26), Vector2(r * 0.15, r * 0.72)), stone.darkened(0.10))
		draw_line(Vector2(x - r * 0.085, center.y - r * 0.28), Vector2(x + r * 0.085, center.y - r * 0.28),
			_with_alpha(trim, 0.60), maxf(0.8, s * 0.008), true)
		draw_line(Vector2(x - r * 0.09, center.y + r * 0.45), Vector2(x + r * 0.09, center.y + r * 0.45),
			stone.darkened(0.30), maxf(0.8, s * 0.010), true)
	var floor := realm.darkened(0.36).lerp(Color("241d1a"), 0.45)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-r * 0.78, r * 0.39),
		center + Vector2(r * 0.74, r * 0.35),
		center + Vector2(r * 0.58, r * 0.68),
		center + Vector2(-r * 0.57, r * 0.68),
	]), floor)
	draw_circle(center + Vector2(-r * 0.30, -r * 0.28), r * 0.50,
		Color(1.0, 0.93, 0.76, 0.055 + _beauty_score() * 0.075))
	draw_arc(center, r * 0.90, -2.85, -0.28, 36, Color(1.0, 0.92, 0.72, 0.10), maxf(1.0, s * 0.010), true)


func _draw_background(s: float) -> void:
	if _is_medallion():
		_draw_medallion_background(s)
		return
	var sky := Color("b7c9c9").lerp(Color("73858d"), _menace_score() * 0.35)
	draw_rect(Rect2(Vector2.ZERO, size), sky)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-s * 0.08, s * 0.48),
		Vector2(s * 0.24, s * 0.12),
		Vector2(s * 0.52, s * 0.48),
	]), Color("6f7e82").lerp(Color("4e575d"), _menace_score() * 0.35))
	draw_colored_polygon(PackedVector2Array([
		Vector2(s * 0.34, s * 0.50),
		Vector2(s * 0.78, s * 0.10),
		Vector2(s * 1.16, s * 0.50),
	]), Color("87979a").lerp(Color("5f6870"), _menace_score() * 0.35))
	draw_rect(Rect2(Vector2(0, s * 0.66), Vector2(size.x, size.y - s * 0.66)), Color("263b34"))
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, maxf(3.0, s * 0.04))), _realm_color().darkened(0.1))
	draw_rect(Rect2(Vector2(0, size.y - maxf(4.0, s * 0.055)), Vector2(size.x, maxf(4.0, s * 0.055))), _house_color().darkened(0.06))


func _draw_house_mark(s: float) -> void:
	var dynasty := str(_ctx("dynasty", "House"))
	var t := _hash01(dynasty)
	var c := _house_color().lightened(0.25)
	var p := Vector2(size.x - s * 0.15, s * 0.13)
	var r := s * 0.04
	if _is_medallion():
		p = size * 0.5 + Vector2(s * 0.315, s * 0.285)
		r = s * 0.017
	if t < 0.33:
		draw_circle(p, r, c)
		draw_circle(p, r * 0.42, Color("1b1411"))
	elif t < 0.66:
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(0, -r),
			p + Vector2(r, 0),
			p + Vector2(0, r),
			p + Vector2(-r, 0),
		]), c)
	else:
		draw_line(p + Vector2(-r, -r), p + Vector2(r, r), c, maxf(2.0, s * 0.015))
		draw_line(p + Vector2(-r, r), p + Vector2(r, -r), c, maxf(2.0, s * 0.015))


func _draw_clothing(cx: float, s: float, shoulder_y: float) -> void:
	var cloak := _realm_color().darkened(0.08).lerp(Color("2f2c27"), _wear_level() * 0.35)
	var house := _house_color().darkened(_menace_score() * 0.2)
	if _is_medallion():
		var left := cx - s * lerpf(0.28, 0.34, _g("presence"))
		var right := cx + s * lerpf(0.23, 0.29, _g("presence"))
		var hem_y := minf(size.y * 0.91, shoulder_y + s * 0.34)
		draw_colored_polygon(PackedVector2Array([
			Vector2(left, hem_y),
			Vector2(cx - s * 0.23, shoulder_y + s * 0.025),
			Vector2(cx - s * 0.08, shoulder_y - s * 0.018),
			Vector2(cx + s * 0.18, shoulder_y + s * 0.018),
			Vector2(right, hem_y),
			Vector2(cx, hem_y + s * 0.04),
		]), cloak)
		# A far-side shoulder shadow reinforces the same turn as the face.
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx + s * 0.07, shoulder_y),
			Vector2(right, hem_y),
			Vector2(cx + s * 0.02, hem_y + s * 0.03),
		]), _with_alpha(cloak.darkened(0.28), 0.62))
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - s * 0.135, shoulder_y + s * 0.02),
			Vector2(cx - s * 0.015, hem_y),
			Vector2(cx + s * 0.105, shoulder_y + s * 0.025),
			Vector2(cx + s * 0.065, hem_y + s * 0.02),
			Vector2(cx - s * 0.07, hem_y + s * 0.02),
		]), house)
		var trim := Color("c7a448") if bool(_ctx("ruler", false)) else house.lightened(0.22)
		draw_polyline(PackedVector2Array([
			Vector2(cx - s * 0.19, shoulder_y + s * 0.04),
			Vector2(cx - s * 0.015, shoulder_y + s * 0.085),
			Vector2(cx + s * 0.145, shoulder_y + s * 0.045),
		]), trim, maxf(1.0, s * 0.012), true)
		var clasp := Vector2(cx - s * 0.015, shoulder_y + s * 0.083)
		draw_circle(clasp, maxf(1.2, s * 0.018), trim.darkened(0.15))
		draw_circle(clasp, maxf(0.7, s * 0.008), _eye_color().lightened(0.22))
		return
	var left := cx - s * lerpf(0.43, 0.49, _g("presence"))
	var right := cx + s * lerpf(0.43, 0.49, _g("presence"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(left, size.y),
		Vector2(cx - s * 0.25, shoulder_y),
		Vector2(cx + s * 0.25, shoulder_y),
		Vector2(right, size.y),
	]), cloak)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - s * 0.17, shoulder_y + s * 0.02),
		Vector2(cx, size.y - s * 0.08),
		Vector2(cx + s * 0.17, shoulder_y + s * 0.02),
		Vector2(cx + s * 0.08, size.y),
		Vector2(cx - s * 0.08, size.y),
	]), house)
	if bool(_ctx("ruler", false)):
		draw_line(Vector2(cx - s * 0.23, shoulder_y + s * 0.02), Vector2(cx + s * 0.23, shoulder_y + s * 0.02), Color("c7a448"), maxf(2.0, s * 0.016))
	else:
		draw_circle(Vector2(cx, shoulder_y + s * 0.06), maxf(2.0, s * 0.025), house.lightened(0.25))


func _draw_head(cx: float, head_c: Vector2, fw: float, fh: float, skin: Color, s: float) -> void:
	var pose := _portrait_pose(cx, head_c, fw, fh)
	var chin: Vector2 = pose["chin"]
	var asym := (_hash01(str(_ctx("id", 0)) + "asym") - 0.5) * _irregularity() * fw * 0.11
	var near_cheek := fw * lerpf(0.84, 0.98, _g("cheek"))
	var far_cheek := fw * lerpf(0.67, 0.79, _g("cheek"))
	var near_jaw := fw * lerpf(0.54, 0.74, _g("jaw"))
	var far_jaw := fw * lerpf(0.47, 0.65, _g("jaw"))
	var chin_w := fw * lerpf(0.34, 0.48, _g("jaw"))
	var neck_w := fw * lerpf(0.34, 0.53, _g("neck_width")) * lerpf(0.94, 1.06, _g("jaw"))
	var forehead_w := lerpf(0.92, 1.06, 1.0 - _g("forehead"))
	var forehead_h := lerpf(0.88, 1.00, _g("forehead"))
	var neck_cx := cx - fw * 0.02
	var neck_top := head_c.y + fh * 0.52
	var neck_bottom := head_c.y + fh * 1.02

	# Neck and ears sit behind the face layer. Only the near ear is strongly
	# visible in a three-quarter pose; matching ears were a major source of the
	# old front-facing mask appearance.
	draw_colored_polygon(PackedVector2Array([
		Vector2(neck_cx - neck_w, neck_top),
		Vector2(neck_cx + neck_w * 0.82, neck_top - fh * 0.01),
		Vector2(neck_cx + neck_w * 0.72, neck_bottom),
		Vector2(neck_cx - neck_w * 0.88, neck_bottom),
	]), skin.darkened(0.075 + _wear_level() * 0.04))
	var neck_shadow := skin.darkened(0.24)
	draw_colored_polygon(PackedVector2Array([
		Vector2(neck_cx + neck_w * 0.20, neck_top),
		Vector2(neck_cx + neck_w * 0.82, neck_top),
		Vector2(neck_cx + neck_w * 0.72, neck_bottom),
		Vector2(neck_cx + neck_w * 0.05, neck_bottom),
	]), _with_alpha(neck_shadow, 0.34))

	var near_ear: Vector2 = pose["near_ear"]
	var far_ear: Vector2 = pose["far_ear"]
	var ear_scale := lerpf(0.78, 1.20, _g("ear_size"))
	var ear_rx := maxf(1.2, fw * 0.115 * ear_scale)
	var ear_ry := maxf(1.8, fh * 0.18 * ear_scale)
	var race := str(_ctx("race", "human"))
	if race in ["elf", "half_elf", "tiefling", "half_tiefling"]:
		# Pointed ears remain unequal in the three-quarter pose; the near ear is
		# a full paper-doll layer while the far one is compressed by perspective.
		draw_colored_polygon(PackedVector2Array([
			far_ear + Vector2(-ear_rx * 0.32, -ear_ry * 0.55),
			far_ear + Vector2(ear_rx * 1.85, -ear_ry * 0.33),
			far_ear + Vector2(-ear_rx * 0.10, ear_ry * 0.62),
		]), skin.darkened(0.11))
		draw_colored_polygon(PackedVector2Array([
			near_ear + Vector2(ear_rx * 0.35, -ear_ry * 0.75),
			near_ear + Vector2(-ear_rx * 2.55, -ear_ry * 0.24),
			near_ear + Vector2(ear_rx * 0.25, ear_ry * 0.82),
		]), skin.darkened(0.035))
		draw_line(near_ear + Vector2(ear_rx * 0.15, -ear_ry * 0.38),
			near_ear + Vector2(-ear_rx * 1.62, -ear_ry * 0.19), skin.darkened(0.24),
			maxf(0.7, s * 0.006), true)
	elif race in ["orc", "half_orc"]:
		draw_colored_polygon(_ellipse(far_ear, ear_rx * 0.82, ear_ry * 0.82, 18), skin.darkened(0.11))
		draw_colored_polygon(_ellipse(near_ear + Vector2(-ear_rx * 0.18, 0.0), ear_rx * 1.35, ear_ry * 1.04, 22), skin.darkened(0.035))
		draw_arc(near_ear + Vector2(-ear_rx * 0.12, 0.0), ear_rx * 0.78, -PI * 0.70, PI * 0.70,
			14, skin.darkened(0.24), maxf(0.7, s * 0.006), true)
	else:
		draw_colored_polygon(_ellipse(far_ear, ear_rx * 0.56, ear_ry * 0.76, 18), skin.darkened(0.11))
		draw_colored_polygon(_ellipse(near_ear, ear_rx, ear_ry, 22), skin.darkened(0.035))
		draw_arc(near_ear + Vector2(ear_rx * 0.04, 0.0), ear_rx * 0.58, -PI * 0.70, PI * 0.70,
			14, skin.darkened(0.24), maxf(0.7, s * 0.006), true)
		draw_arc(near_ear + Vector2(ear_rx * 0.12, ear_ry * 0.16), ear_rx * 0.30, -PI * 0.45, PI * 0.55,
			9, skin.lightened(0.04), maxf(0.6, s * 0.004), true)

	# Rounded, unequal contours replace the old mirrored jaw diamond.
	var face := PackedVector2Array([
		head_c + Vector2(-fw * 0.44 * forehead_w, -fh * 0.88 * forehead_h),
		head_c + Vector2(-fw * 0.10, -fh * 0.96 * forehead_h),
		head_c + Vector2(fw * 0.25 * forehead_w, -fh * 0.93 * forehead_h),
		head_c + Vector2(fw * 0.53 * forehead_w, -fh * 0.82 * forehead_h),
		head_c + Vector2(fw * 0.71, -fh * 0.65),
		head_c + Vector2(fw * 0.78, -fh * 0.42),
		head_c + Vector2(far_cheek, -fh * 0.15),
		head_c + Vector2(far_cheek * 0.96, fh * 0.10),
		head_c + Vector2(far_jaw, fh * 0.35),
		head_c + Vector2(far_jaw * 0.84, fh * 0.50),
		Vector2(chin.x + chin_w * 0.98, chin.y - fh * 0.15),
		Vector2(chin.x + chin_w * 0.72, chin.y - fh * 0.065),
		Vector2(chin.x + chin_w * 0.30, chin.y - fh * 0.010),
		Vector2(chin.x - chin_w * 0.18, chin.y),
		Vector2(chin.x - chin_w * 0.63, chin.y - fh * 0.025),
		Vector2(chin.x - chin_w * 1.02, chin.y - fh * 0.10),
		head_c + Vector2(-near_jaw * 0.90 + asym, fh * 0.52),
		head_c + Vector2(-near_jaw + asym, fh * 0.38),
		head_c + Vector2(-near_cheek + asym, fh * 0.13),
		head_c + Vector2(-near_cheek * 1.01 + asym, -fh * 0.15),
		head_c + Vector2(-fw * 0.87 + asym * 0.5, -fh * 0.42),
		head_c + Vector2(-fw * 0.71, -fh * 0.66),
	])
	draw_colored_polygon(face, skin)

	# Broad translucent volumes read as soft painted modelling instead of flat
	# facets. They stay inside the silhouette and remain legible at 36 px.
	var far_shade := skin.darkened(0.27 + _g("severity") * 0.06)
	draw_colored_polygon(PackedVector2Array([
		head_c + Vector2(fw * 0.12, -fh * 0.84),
		head_c + Vector2(fw * 0.53, -fh * 0.78),
		head_c + Vector2(fw * 0.73, -fh * 0.52),
		head_c + Vector2(far_cheek * 0.95, -fh * 0.08),
		head_c + Vector2(far_jaw * 0.96, fh * 0.38),
		Vector2(chin.x + chin_w * 0.56, chin.y - fh * 0.12),
		Vector2(pose["axis_x"], head_c.y + fh * 0.48),
		Vector2(pose["axis_x"] - fw * 0.02, head_c.y - fh * 0.48),
	]), _with_alpha(far_shade, 0.26))
	var cheek_light := skin.lightened(0.18 + _beauty_score() * 0.04)
	draw_colored_polygon(_ellipse(head_c + Vector2(-fw * 0.30, fh * 0.08), fw * 0.43, fh * 0.40, 28),
		_with_alpha(cheek_light, 0.20))
	var cheek_warm := Color("b85f4d").lerp(skin, 0.54)
	draw_colored_polygon(_ellipse(head_c + Vector2(-fw * 0.43, fh * 0.20), fw * 0.25, fh * 0.15, 22),
		_with_alpha(cheek_warm, 0.10 + _beauty_score() * 0.10))
	var jaw_shadow := skin.darkened(0.29)
	draw_colored_polygon(PackedVector2Array([
		head_c + Vector2(-near_jaw * 0.88, fh * 0.37),
		Vector2(chin.x - chin_w * 0.85, chin.y - fh * 0.13),
		chin,
		Vector2(chin.x + chin_w * 0.62, chin.y - fh * 0.13),
		head_c + Vector2(fw * 0.08, fh * 0.51),
	]), _with_alpha(jaw_shadow, 0.23))

	var outline := face.duplicate()
	outline.append(face[0])
	draw_polyline(outline, _with_alpha(skin.darkened(0.38), 0.34), maxf(0.65, s * 0.0045), true)


func _draw_hair_back(cx: float, head_c: Vector2, fw: float, fh: float, s: float, hair: Color, style: int) -> void:
	var texture := _g("hair_texture")
	var long_hair := (is_female and style != 1) or style == 2
	if long_hair:
		var fall := fh * (1.02 if style == 2 else 0.82)
		var width := fw * lerpf(1.02, 1.18, texture)
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(-width * 0.82, -fh * 0.66),
			head_c + Vector2(-width, -fh * 0.15),
			head_c + Vector2(-width * 0.84, fall * 0.72),
			head_c + Vector2(-fw * 0.42, fall),
			head_c + Vector2(fw * 0.32, fall * 0.93),
			head_c + Vector2(width * 0.83, fall * 0.64),
			head_c + Vector2(width * 0.91, -fh * 0.18),
			head_c + Vector2(fw * 0.62, -fh * 0.71),
		]), hair.darkened(0.13))
		var hair_glow := hair.lightened(0.10)
		for i in 4:
			var t := float(i) / 3.0
			var x := lerpf(cx - width * 0.72, cx - fw * 0.28, t)
			draw_line(Vector2(x, head_c.y - fh * 0.30),
				Vector2(x - fw * 0.06 * texture, head_c.y + fall * lerpf(0.46, 0.88, t)),
				_with_alpha(hair_glow, 0.48), maxf(0.7, s * 0.005), true)
	if style == 3:
		# Coils and braids deliberately break the outline into rounded forms.
		for i in 5:
			var t := float(i) / 4.0
			var p := head_c + Vector2(lerpf(-fw * 0.92, -fw * 0.69, t), lerpf(-fh * 0.48, fh * 0.67, t))
			draw_colored_polygon(_ellipse(p, fw * 0.13, fh * 0.105, 16), hair.darkened(0.06 + t * 0.08))
	if style == 1:
		var hood := _realm_color().darkened(0.34)
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(-fw * 1.08, -fh * 0.50),
			head_c + Vector2(-fw * 0.56, -fh * 1.08),
			head_c + Vector2(fw * 0.34, -fh * 1.11),
			head_c + Vector2(fw * 0.92, -fh * 0.58),
			head_c + Vector2(fw * 0.86, fh * 0.79),
			head_c + Vector2(fw * 0.38, fh * 0.96),
			head_c + Vector2(fw * 0.48, -fh * 0.61),
			head_c + Vector2(-fw * 0.65, -fh * 0.53),
			head_c + Vector2(-fw * 0.70, fh * 0.83),
			head_c + Vector2(-fw * 1.01, fh * 0.63),
		]), hood)


func _draw_hair_front(cx: float, head_c: Vector2, fw: float, fh: float, s: float, hair: Color, style: int) -> void:
	var texture := _g("hair_texture")
	var cap := PackedVector2Array([
		head_c + Vector2(-fw * 0.88, -fh * 0.33),
		head_c + Vector2(-fw * 0.86, -fh * 0.57),
		head_c + Vector2(-fw * 0.70, -fh * 0.78),
		head_c + Vector2(-fw * 0.43, -fh * 0.94),
		head_c + Vector2(-fw * 0.10, -fh * 1.01),
		head_c + Vector2(fw * 0.23, -fh * 0.97),
		head_c + Vector2(fw * 0.52, -fh * 0.84),
		head_c + Vector2(fw * 0.70, -fh * 0.66),
		head_c + Vector2(fw * 0.76, -fh * 0.43),
		head_c + Vector2(fw * 0.57, -fh * 0.49),
		head_c + Vector2(fw * 0.28, -fh * 0.56),
		head_c + Vector2(-fw * 0.04, -fh * 0.48),
		head_c + Vector2(-fw * 0.35, -fh * 0.40),
		head_c + Vector2(-fw * 0.63, -fh * 0.28),
	])
	if style != 1 or not is_female:
		draw_colored_polygon(cap, hair.darkened(0.025))

	if style == 0:
		# Side-parted court hair: one broad sweep and a narrow far-side lock.
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(-fw * 0.66, -fh * 0.65),
			head_c + Vector2(-fw * 0.22, -fh * 0.82),
			head_c + Vector2(fw * 0.47, -fh * 0.58),
			head_c + Vector2(fw * 0.18, -fh * 0.38),
			head_c + Vector2(-fw * 0.12, -fh * 0.47),
			head_c + Vector2(-fw * 0.52, -fh * 0.27),
		]), hair)
	elif style == 2:
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(fw * 0.47, -fh * 0.82),
			head_c + Vector2(fw * 0.66, -fh * 0.48),
			head_c + Vector2(fw * 0.32, -fh * 0.18),
			head_c + Vector2(fw * 0.01, -fh * 0.31),
			head_c + Vector2(-fw * 0.33, -fh * 0.52),
			head_c + Vector2(-fw * 0.54, -fh * 0.72),
		]), hair)
	elif style == 3:
		for i in 6:
			var t := float(i) / 5.0
			var p := head_c + Vector2(lerpf(-fw * 0.69, fw * 0.63, t), -fh * (0.52 + sin(t * PI) * 0.20))
			draw_colored_polygon(_ellipse(p, fw * lerpf(0.15, 0.11, t), fh * 0.105, 16), hair.lightened(0.025 * (i % 2)))
	else:
		draw_arc(head_c + Vector2(-fw * 0.02, -fh * 0.48), fw * 0.62, PI * 1.08, PI * 1.88,
			18, hair.lightened(0.08), maxf(0.7, s * 0.006), true)

	# Front side-locks are separate layers, which keeps hair from reading like
	# a single helmet-shaped polygon.
	if is_female and style != 1:
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(-fw * 0.82, -fh * 0.42),
			head_c + Vector2(-fw * 0.69, -fh * 0.28),
			head_c + Vector2(-fw * 0.66, fh * 0.56),
			head_c + Vector2(-fw * 0.89, fh * 0.75),
			head_c + Vector2(-fw * 0.96, fh * 0.02),
		]), hair.darkened(0.02))
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(fw * 0.66, -fh * 0.46),
			head_c + Vector2(fw * 0.77, -fh * 0.23),
			head_c + Vector2(fw * 0.67, fh * 0.47),
			head_c + Vector2(fw * 0.52, fh * 0.58),
			head_c + Vector2(fw * 0.55, -fh * 0.28),
		]), hair.darkened(0.12))

	var strands := 3 + int(round(texture * 3.0))
	for i in strands:
		var t := float(i) / maxf(1.0, float(strands - 1))
		var start := head_c + Vector2(lerpf(-fw * 0.63, fw * 0.57, t), -fh * lerpf(0.74, 0.59, t))
		var sway := sin((t + _g("hair_hue")) * TAU) * fw * 0.08 * texture
		draw_line(start, start + Vector2(sway + fw * 0.06, fh * lerpf(0.18, 0.10, t)),
			_with_alpha(hair.lightened(0.18), 0.55), maxf(0.65, s * 0.0045), true)


func _headwear_kind() -> int:
	if bool(_ctx("ruler", false)):
		return 1
	var culture := str(_ctx("culture", ""))
	var traits := _traits()
	if traits.has("Zealous") or traits.has("Faith-Practicing") or traits.has("Gravewarden-Sworn"):
		return 2
	if culture == "drevak" or culture == "karn_vol" or culture == "southern_reach":
		return 3
	if culture == "kharak_dum" or culture == "brushgate":
		return 4
	if culture == "veldarin" or culture == "thaladris":
		return 5
	var roll := _hash01(str(_ctx("id", 0)) + "headwear")
	return 0 if roll < 0.45 else (2 if roll < 0.62 else 3)


func _draw_headwear(cx: float, head_c: Vector2, fw: float, fh: float, s: float, hair: Color) -> void:
	var kind := _headwear_kind()
	var realm := _realm_color()
	var pose := _portrait_pose(cx, head_c, fw, fh)
	var axis_x: float = pose["axis_x"]
	if kind == 0:
		return
	if kind == 1:
		var y := head_c.y - fh * 0.83
		var crown := Color("d6b24b").lerp(_house_color().lightened(0.35), 0.22)
		var band := PackedVector2Array([
			Vector2(cx - fw * 0.70, y + fh * 0.035),
			Vector2(cx + fw * 0.67, y - fh * 0.022),
			Vector2(cx + fw * 0.66, y + fh * 0.085),
			Vector2(cx - fw * 0.68, y + fh * 0.13),
		])
		draw_colored_polygon(band, crown.darkened(0.12))
		draw_polyline(PackedVector2Array([band[0], band[1]]), crown.lightened(0.20), maxf(0.7, s * 0.006), true)
		for i in 5:
			var t := float(i) / 4.0
			var x := lerpf(cx - fw * 0.58, cx + fw * 0.55, t)
			var base_y := lerpf(y + fh * 0.05, y, t)
			var h := fh * (0.13 if i == 2 else (0.095 if i % 2 == 0 else 0.065))
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - fw * 0.055, base_y),
				Vector2(x, base_y - h),
				Vector2(x + fw * 0.055, base_y),
			]), crown)
			draw_circle(Vector2(x, base_y - h), maxf(0.8, s * 0.009), _eye_color().lightened(0.25))
	elif kind == 2:
		var cloth := realm.darkened(0.18).lerp(Color("d9d2c5"), 0.18 if is_female else 0.05)
		# A close cap plus two independent veil panels preserves the face rather
		# than laying one large angular polygon across it.
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(-fw * 0.80, -fh * 0.49),
			head_c + Vector2(-fw * 0.69, -fh * 0.78),
			head_c + Vector2(-fw * 0.33, -fh * 0.98),
			head_c + Vector2(fw * 0.19, -fh * 1.01),
			head_c + Vector2(fw * 0.62, -fh * 0.81),
			head_c + Vector2(fw * 0.74, -fh * 0.53),
			head_c + Vector2(fw * 0.48, -fh * 0.61),
			head_c + Vector2(-fw * 0.52, -fh * 0.54),
		]), cloth)
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(-fw * 0.83, -fh * 0.55),
			head_c + Vector2(-fw * 1.00, -fh * 0.18),
			head_c + Vector2(-fw * 0.91, fh * 0.73),
			head_c + Vector2(-fw * 0.62, fh * 0.88),
			head_c + Vector2(-fw * 0.66, -fh * 0.41),
		]), cloth.darkened(0.06))
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(fw * 0.66, -fh * 0.56),
			head_c + Vector2(fw * 0.84, -fh * 0.19),
			head_c + Vector2(fw * 0.73, fh * 0.68),
			head_c + Vector2(fw * 0.52, fh * 0.79),
			head_c + Vector2(fw * 0.51, -fh * 0.47),
		]), cloth.darkened(0.16))
		draw_line(head_c + Vector2(-fw * 0.66, -fh * 0.52), head_c + Vector2(fw * 0.60, -fh * 0.58),
			cloth.lightened(0.20), maxf(0.8, s * 0.008), true)
	elif kind == 3:
		var wrap := realm.lightened(0.12).lerp(_house_color().lightened(0.1), 0.35)
		draw_colored_polygon(_ellipse(head_c + Vector2(-fw * 0.02, -fh * 0.74), fw * 0.82, fh * 0.29, 28), wrap.darkened(0.04))
		draw_colored_polygon(_ellipse(head_c + Vector2(fw * 0.10, -fh * 0.88), fw * 0.56, fh * 0.20, 24), wrap.lightened(0.08))
		for i in 3:
			var yy := head_c.y - fh * (0.85 - i * 0.10)
			draw_line(Vector2(cx - fw * (0.66 + i * 0.04), yy + fh * 0.035),
				Vector2(cx + fw * (0.62 + i * 0.02), yy - fh * 0.035),
				wrap.darkened(0.18 + i * 0.025), maxf(0.7, s * 0.007), true)
		draw_circle(Vector2(axis_x + fw * 0.05, head_c.y - fh * 0.72), maxf(1.0, s * 0.015), _house_color().lightened(0.30))
	elif kind == 4:
		var metal := Color("a7a09a").lerp(Color("4a4745"), _menace_score() * 0.35)
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(-fw * 0.78, -fh * 0.45),
			head_c + Vector2(-fw * 0.73, -fh * 0.69),
			head_c + Vector2(-fw * 0.48, -fh * 0.90),
			head_c + Vector2(-fw * 0.12, -fh * 1.00),
			head_c + Vector2(fw * 0.27, -fh * 0.96),
			head_c + Vector2(fw * 0.57, -fh * 0.79),
			head_c + Vector2(fw * 0.73, -fh * 0.55),
			head_c + Vector2(fw * 0.61, -fh * 0.43),
		]), metal)
		draw_arc(head_c + Vector2(-fw * 0.04, -fh * 0.48), fw * 0.66, PI * 1.08, PI * 1.92,
			22, metal.lightened(0.28), maxf(0.8, s * 0.008), true)
		draw_line(Vector2(axis_x + fw * 0.02, head_c.y - fh * 0.78),
			Vector2(axis_x + fw * 0.11, head_c.y + fh * 0.11), metal.darkened(0.28), maxf(1.0, s * 0.015), true)
		draw_circle(Vector2(axis_x + fw * 0.02, head_c.y - fh * 0.68), maxf(0.8, s * 0.009), metal.lightened(0.28))
	elif kind == 5:
		var circlet := Color("d8d1b7").lerp(_eye_color().lightened(0.3), 0.18)
		var y2 := head_c.y - fh * 0.60
		draw_polyline(PackedVector2Array([
			Vector2(cx - fw * 0.67, y2 + fh * 0.035),
			Vector2(axis_x, y2 - fh * 0.045),
			Vector2(cx + fw * 0.62, y2 - fh * 0.015),
		]), circlet, maxf(0.8, s * 0.010), true)
		draw_circle(Vector2(axis_x, y2 - fh * 0.045), maxf(1.0, s * 0.014), circlet.lightened(0.18))
		draw_circle(Vector2(axis_x, y2 - fh * 0.045), maxf(0.55, s * 0.006), _eye_color())
		if is_female:
			draw_line(head_c + Vector2(-fw * 0.66, -fh * 0.55), head_c + Vector2(-fw * 0.91, fh * 0.44),
				circlet.darkened(0.12), maxf(0.7, s * 0.006), true)
			draw_line(head_c + Vector2(fw * 0.59, -fh * 0.56), head_c + Vector2(fw * 0.72, fh * 0.33),
				circlet.darkened(0.17), maxf(0.7, s * 0.005), true)


func _draw_features(cx: float, head_c: Vector2, fw: float, fh: float, s: float, skin: Color, hair: Color) -> void:
	var beauty := _beauty_score()
	var menace := _menace_score()
	var pose := _portrait_pose(cx, head_c, fw, fh)
	var near_eye: Vector2 = pose["near_eye"]
	var far_eye: Vector2 = pose["far_eye"]
	var eye_rx := s * lerpf(0.032, 0.046, _g("eye_size")) * lerpf(0.93, 1.07, beauty)
	var eye_ry := eye_rx * lerpf(0.37, 0.50, 1.0 - menace)
	var brow_thick := maxf(0.75, s * lerpf(0.006, 0.013, _g("brow")))
	var eye_white := Color("e8ded1").lerp(skin.lightened(0.20), 0.18)
	var iris := _eye_color().lightened(beauty * 0.10)

	for eye_data in [
		{"center": near_eye, "scale": 1.0, "far": false},
		{"center": far_eye, "scale": 0.76, "far": true},
	]:
		var ec: Vector2 = eye_data["center"]
		var scale: float = eye_data["scale"]
		var rx := eye_rx * scale
		var ry := eye_ry * (0.88 if eye_data["far"] else 1.0)
		var tilt := ry * lerpf(-0.20, 0.20, _g("eye_tilt")) * (-1.0 if eye_data["far"] else 1.0)
		var eye_shape := _tilted_lens(ec, rx, ry, tilt)
		draw_colored_polygon(eye_shape, eye_white)
		var gaze := Vector2(rx * 0.16, ry * 0.03)
		draw_colored_polygon(_ellipse(ec + gaze, ry * 0.82, ry * 0.92, 18), iris)
		draw_circle(ec + gaze, maxf(0.65, ry * 0.38), Color("15100d"))
		if s >= 44.0:
			draw_circle(ec + gaze + Vector2(-ry * 0.18, -ry * 0.30), maxf(0.55, ry * 0.12), Color("fff7dc"))
		# Upper and lower lids make the eye belong to the face instead of float
		# as a white diamond.
		draw_polyline(PackedVector2Array([eye_shape[0], eye_shape[1], eye_shape[2], eye_shape[3], eye_shape[4]]),
			hair.darkened(0.38), maxf(0.7, s * 0.006), true)
		draw_polyline(PackedVector2Array([eye_shape[4], eye_shape[5], eye_shape[6], eye_shape[7], eye_shape[0]]),
			_with_alpha(skin.darkened(0.38), 0.56), maxf(0.55, s * 0.004), true)

		var brow_y := ec.y - eye_rx * lerpf(1.10, 1.38, _g("brow"))
		var inner_y := brow_y + eye_rx * lerpf(0.05, 0.22, menace)
		var outer_y := brow_y - eye_rx * lerpf(0.04, 0.18, menace)
		if eye_data["far"]:
			outer_y += eye_rx * 0.05
		draw_polyline(PackedVector2Array([
			Vector2(ec.x - rx * 0.92, outer_y),
			Vector2(ec.x - rx * 0.15, brow_y - eye_rx * 0.06),
			Vector2(ec.x + rx * 0.93, inner_y),
		]), hair.darkened(0.28), brow_thick * scale, true)

	# A restrained bridge and projecting tip establish the turn without
	# turning the entire center of the face into a dark triangular plane.
	var root: Vector2 = pose["nose_root"]
	var tip: Vector2 = pose["nose_tip"]
	var crooked := (_hash01(str(_ctx("id", 0)) + "nose") - 0.5) * _irregularity() * fw * 0.12
	tip.x += crooked
	var nose_width := lerpf(0.72, 1.26, _g("nose_width"))
	var nose_shadow := skin.darkened(0.30 + menace * 0.05)
	var bridge_mid := root.lerp(tip, 0.58) + Vector2(-fw * 0.025, 0.0)
	draw_polyline(PackedVector2Array([
		root + Vector2(fw * 0.035, 0.0),
		bridge_mid + Vector2(fw * 0.045, 0.0),
		tip + Vector2(fw * 0.025, -fh * 0.01),
	]), _with_alpha(nose_shadow, 0.27), maxf(0.6, s * 0.0045), true)
	draw_line(root + Vector2(-fw * 0.025, 0.0), tip + Vector2(-fw * 0.055, -fh * 0.015),
		_with_alpha(skin.lightened(0.30), 0.34), maxf(0.6, s * 0.004), true)
	draw_colored_polygon(_ellipse(tip + Vector2(-fw * 0.005, fh * 0.025), fw * 0.095 * nose_width, fh * 0.065, 16),
		_with_alpha(skin.lightened(0.08), 0.16))
	draw_arc(tip + Vector2(-fw * 0.015, fh * 0.020), maxf(1.0, fw * 0.085 * nose_width), 0.20, PI * 0.90,
		10, _with_alpha(nose_shadow, 0.43), maxf(0.65, s * 0.0045), true)
	draw_line(tip + Vector2(fw * 0.002, fh * 0.060), tip + Vector2(fw * 0.070 * nose_width, fh * 0.052),
		_with_alpha(nose_shadow, 0.72), maxf(0.65, s * 0.0045), true)
	draw_circle(tip + Vector2(fw * 0.070 * nose_width, fh * 0.050), maxf(0.5, s * 0.0035), _with_alpha(nose_shadow, 0.80))

	var mouth: Vector2 = pose["mouth"]
	var mw := lerpf(0.23, 0.40, _g("mouth")) * fw
	var lip_h := s * lerpf(0.006, 0.014, _g("lip_fullness"))
	var smile := lerpf(s * 0.010, -s * 0.010, menace)
	if beauty > 0.66 and menace < 0.55:
		smile += s * 0.010
	var left_corner := mouth + Vector2(-mw, 0.0)
	var right_corner := mouth + Vector2(mw * 0.72, -s * 0.002)
	var cupid := mouth + Vector2(-mw * 0.03, smile - lip_h * 0.22)
	var lip := Color("8d4d48").lerp(skin.darkened(0.34), 0.38 + menace * 0.30)
	draw_colored_polygon(PackedVector2Array([
		left_corner,
		mouth + Vector2(-mw * 0.28, smile - lip_h * 0.38),
		cupid,
		mouth + Vector2(mw * 0.23, smile - lip_h * 0.32),
		right_corner,
		mouth + Vector2(mw * 0.05, smile + lip_h * 0.42),
	]), _with_alpha(lip.darkened(0.08), 0.92))
	draw_colored_polygon(PackedVector2Array([
		left_corner + Vector2(mw * 0.06, 0.0),
		cupid + Vector2(0.0, lip_h * 0.45),
		right_corner + Vector2(-mw * 0.05, 0.0),
		mouth + Vector2(mw * 0.02, smile + lip_h),
	]), _with_alpha(lip.lightened(0.16), 0.72))
	draw_polyline(PackedVector2Array([left_corner, cupid + Vector2(0.0, lip_h * 0.30), right_corner]),
		lip.darkened(0.34), maxf(0.65, s * 0.0048), true)
	draw_line(Vector2(mouth.x - mw * 0.08, mouth.y - fh * 0.10), Vector2(mouth.x, mouth.y - fh * 0.045),
		_with_alpha(skin.darkened(0.30), 0.42), maxf(0.55, s * 0.004), true)


func _draw_beard(cx: float, head_c: Vector2, fw: float, fh: float, hair: Color, s: float) -> void:
	if is_female or _g("beard") <= 0.45 or age < 16:
		return
	var pose := _portrait_pose(cx, head_c, fw, fh)
	var mouth: Vector2 = pose["mouth"]
	var chin: Vector2 = pose["chin"]
	var fullness := clampf((_g("beard") - 0.45) / 0.55, 0.0, 1.0)
	var beard_col := hair.darkened(0.05 + _wear_level() * 0.03)

	# Low alleles make a shaped stubble shadow; higher alleles add a separate
	# rounded beard silhouette and moustache, like another paper-doll layer.
	if fullness < 0.34:
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(-fw * 0.70, fh * 0.25),
			head_c + Vector2(-fw * 0.53, fh * 0.55),
			Vector2(chin.x - fw * 0.22, chin.y - fh * 0.02),
			chin,
			Vector2(chin.x + fw * 0.26, chin.y - fh * 0.06),
			head_c + Vector2(fw * 0.53, fh * 0.34),
			mouth + Vector2(fw * 0.26, fh * 0.05),
			mouth + Vector2(-fw * 0.36, fh * 0.08),
		]), _with_alpha(beard_col, 0.24 + fullness * 0.38))
		return

	var drop := fh * lerpf(0.07, 0.52, fullness)
	var beard := PackedVector2Array([
		head_c + Vector2(-fw * 0.73, fh * 0.23),
		head_c + Vector2(-fw * 0.70, fh * 0.44),
		head_c + Vector2(-fw * 0.52, fh * 0.68),
		Vector2(chin.x - fw * 0.33, chin.y + drop * 0.52),
		Vector2(chin.x - fw * 0.12, chin.y + drop * 0.88),
		Vector2(chin.x + fw * 0.06, chin.y + drop),
		Vector2(chin.x + fw * 0.27, chin.y + drop * 0.72),
		Vector2(chin.x + fw * 0.43, chin.y + drop * 0.36),
		head_c + Vector2(fw * 0.55, fh * 0.40),
		mouth + Vector2(fw * 0.30, fh * 0.09),
		mouth + Vector2(fw * 0.18, fh * 0.16),
		mouth + Vector2(-fw * 0.28, fh * 0.17),
		mouth + Vector2(-fw * 0.40, fh * 0.09),
	])
	draw_colored_polygon(beard, beard_col)
	var beard_shade := beard_col.darkened(0.25)
	draw_colored_polygon(PackedVector2Array([
		mouth + Vector2(fw * 0.08, fh * 0.13),
		mouth + Vector2(fw * 0.30, fh * 0.10),
		Vector2(chin.x + fw * 0.43, chin.y + drop * 0.34),
		Vector2(chin.x + fw * 0.08, chin.y + drop),
		Vector2(chin.x - fw * 0.02, chin.y + drop * 0.42),
	]), _with_alpha(beard_shade, 0.52))
	# Split moustache leaves the mouth readable.
	draw_colored_polygon(PackedVector2Array([
		mouth + Vector2(-fw * 0.34, -fh * 0.035),
		mouth + Vector2(-fw * 0.07, -fh * 0.085),
		mouth + Vector2(-fw * 0.015, -fh * 0.025),
		mouth + Vector2(-fw * 0.28, fh * 0.015),
	]), beard_col.darkened(0.06))
	draw_colored_polygon(PackedVector2Array([
		mouth + Vector2(fw * 0.00, -fh * 0.028),
		mouth + Vector2(fw * 0.11, -fh * 0.080),
		mouth + Vector2(fw * 0.29, -fh * 0.025),
		mouth + Vector2(fw * 0.08, fh * 0.014),
	]), beard_col.darkened(0.12))
	for i in 4:
		var t := float(i) / 3.0
		var start := Vector2(lerpf(chin.x - fw * 0.30, chin.x + fw * 0.29, t), chin.y + drop * lerpf(0.22, 0.30, t))
		draw_line(start, start + Vector2(fw * 0.025, drop * 0.46), _with_alpha(hair.lightened(0.13), 0.42),
			maxf(0.6, s * 0.004), true)


func _draw_marks(cx: float, head_c: Vector2, fw: float, fh: float, s: float, skin: Color) -> void:
	var beauty := _beauty_score()
	var menace := _menace_score()
	var wear := _wear_level()
	var pose := _portrait_pose(cx, head_c, fw, fh)
	var near_eye: Vector2 = pose["near_eye"]
	var far_eye: Vector2 = pose["far_eye"]
	if age > 50 or wear > 0.45:
		var wr := _with_alpha(skin.darkened(0.30), 0.52 + wear * 0.20)
		draw_arc(near_eye + Vector2(0.0, fh * 0.07), fw * 0.24, 0.16, PI * 0.82, 10, wr, maxf(0.55, s * 0.004), true)
		draw_arc(far_eye + Vector2(0.0, fh * 0.055), fw * 0.15, 0.18, PI * 0.78, 8, wr, maxf(0.5, s * 0.0035), true)
		for i in 2:
			var yy := head_c.y - fh * (0.43 - i * 0.09)
			draw_line(Vector2(pose["axis_x"] - fw * 0.33, yy), Vector2(pose["axis_x"] + fw * 0.27, yy - fh * 0.018),
				_with_alpha(wr, 0.34 + wear * 0.22), maxf(0.5, s * 0.0035), true)
		# Near-side crow's feet are visible; the far side is compressed by turn.
		for i in 2:
			draw_line(near_eye + Vector2(-fw * 0.18, fh * (0.01 + i * 0.035)),
				near_eye + Vector2(-fw * (0.29 + i * 0.025), fh * (0.02 + i * 0.075)), wr,
				maxf(0.5, s * 0.0035), true)
	if menace > 0.62 or _irregularity() > 0.55:
		var scar_seed := _hash01(str(_ctx("id", 0)) + str(_ctx("dynasty", "")))
		if scar_seed > 0.38:
			var sx := lerpf(near_eye.x - fw * 0.14, pose["axis_x"] + fw * 0.22, scar_seed)
			draw_line(Vector2(sx, head_c.y - fh * 0.24), Vector2(sx + fw * 0.13, head_c.y + fh * 0.30),
				_with_alpha(skin.darkened(0.42), 0.80), maxf(0.75, s * 0.007), true)
			draw_line(Vector2(sx + fw * 0.025, head_c.y - fh * 0.23), Vector2(sx + fw * 0.15, head_c.y + fh * 0.29),
				_with_alpha(skin.lightened(0.20), 0.28), maxf(0.5, s * 0.003), true)
	if beauty > 0.72 and menace < 0.58:
		draw_circle(head_c + Vector2(-fw * 0.47, fh * 0.21), maxf(0.65, s * 0.006), Color("513126").lerp(_eye_color(), 0.12))


func _draw_accessories(cx: float, head_c: Vector2, fw: float, fh: float, s: float) -> void:
	var pose := _portrait_pose(cx, head_c, fw, fh)
	var near_ear: Vector2 = pose["near_ear"]
	var roll := _hash01(str(_ctx("id", 0)) + "jewelry")
	var metal := Color("d3b45f") if bool(_ctx("ruler", false)) else Color("b8aa91")
	var culture := str(_ctx("culture", ""))
	var wears_earring := is_female or roll > 0.76 or culture == "southern_reach" or culture == "free_city"
	if wears_earring:
		var stud := near_ear + Vector2(-fw * 0.005, fh * 0.12)
		draw_circle(stud, maxf(0.65, s * 0.006), metal.darkened(0.12))
		if s >= 52.0 and (roll > 0.42 or bool(_ctx("ruler", false))):
			draw_line(stud, stud + Vector2(-fw * 0.01, fh * 0.12), metal, maxf(0.6, s * 0.004), true)
			draw_colored_polygon(_ellipse(stud + Vector2(-fw * 0.01, fh * 0.15), maxf(0.8, s * 0.008), maxf(1.0, s * 0.011), 14),
				_eye_color().lightened(0.18))
	if bool(_ctx("ruler", false)) and s >= 58.0:
		var chain_y := head_c.y + fh * 0.92
		draw_arc(Vector2(cx - fw * 0.03, chain_y - fh * 0.14), fw * 0.50, 0.12, PI - 0.08, 20,
			_with_alpha(metal, 0.72), maxf(0.7, s * 0.005), true)


func _draw_frame(s: float) -> void:
	if _is_medallion():
		var center := size * 0.5
		var r := s * 0.485
		var frame_col := Color("8a7c68").lerp(Color("23201f"), _menace_score() * 0.30)
		draw_arc(center, r * 0.985, 0.0, TAU, 72, Color("0b0a09"), maxf(2.0, s * 0.030))
		draw_arc(center, r * 0.955, 0.0, TAU, 72, frame_col, maxf(1.0, s * 0.018))
		draw_arc(center, r * 0.895, 0.0, TAU, 72, Color(1.0, 0.92, 0.72, 0.18), maxf(1.0, s * 0.008))
	else:
		var frame_col := Color("7a6134").lerp(Color("2d2320"), _menace_score() * 0.35)
		draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2.0), frame_col, false, 2.0)


func _draw_ancestry_back(head_c: Vector2, fw: float, fh: float, hair: Color) -> void:
	var race := str(_ctx("race", "human"))
	if race not in ["tiefling", "half_tiefling"]:
		return
	var extent := 1.0 if race == "tiefling" else 0.68
	var horn := hair.darkened(0.34).lerp(Color("4a3d3a"), 0.48)
	# Unequal horns follow the same three-quarter perspective as the face.
	draw_colored_polygon(PackedVector2Array([
		head_c + Vector2(-fw * 0.50, -fh * 0.74),
		head_c + Vector2(-fw * (0.94 + 0.42 * extent), -fh * (1.05 + 0.55 * extent)),
		head_c + Vector2(-fw * 0.06, -fh * 0.91),
	]), horn)
	draw_colored_polygon(PackedVector2Array([
		head_c + Vector2(fw * 0.15, -fh * 0.91),
		head_c + Vector2(fw * (0.48 + 0.30 * extent), -fh * (1.16 + 0.42 * extent)),
		head_c + Vector2(fw * 0.67, -fh * 0.72),
	]), horn.lightened(0.055))
	draw_line(head_c + Vector2(-fw * 0.44, -fh * 0.82),
		head_c + Vector2(-fw * (1.00 + 0.22 * extent), -fh * (1.12 + 0.34 * extent)),
		horn.lightened(0.18), maxf(0.7, minf(fw, fh) * 0.035), true)


func _draw_ancestry_front(cx: float, head_c: Vector2, fw: float, fh: float, skin: Color, s: float) -> void:
	var race := str(_ctx("race", "human"))
	if race not in ["orc", "half_orc"]:
		return
	var pose := _portrait_pose(cx, head_c, fw, fh)
	var mouth: Vector2 = pose["mouth"]
	var size_mult := 1.0 if race == "orc" else 0.66
	var ivory := Color("ead9b3").lerp(skin.lightened(0.20), 0.12)
	# The near tusk is stronger; the far tusk is compressed with the far eye.
	draw_colored_polygon(PackedVector2Array([
		mouth + Vector2(fw * 0.25, fh * 0.015),
		mouth + Vector2(fw * (0.31 + 0.05 * size_mult), -fh * (0.04 + 0.11 * size_mult)),
		mouth + Vector2(fw * 0.39, fh * 0.045),
	]), ivory)
	draw_colored_polygon(PackedVector2Array([
		mouth + Vector2(-fw * 0.23, fh * 0.025),
		mouth + Vector2(-fw * (0.21 + 0.02 * size_mult), -fh * (0.02 + 0.07 * size_mult)),
		mouth + Vector2(-fw * 0.13, fh * 0.035),
	]), ivory.darkened(0.08))
	draw_line(mouth + Vector2(fw * 0.22, fh * 0.052), mouth + Vector2(fw * 0.41, fh * 0.055),
		skin.darkened(0.38), maxf(0.6, s * 0.0038), true)


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 0.0:
		return
	_draw_background(s)
	if genome.is_empty():
		if framed:
			_draw_frame(s)
		return

	var cx := size.x * 0.5
	var head_c := Vector2(cx, s * (0.50 if _is_medallion() else 0.47))
	var fw := lerpf(0.24, 0.35, _g("face_width")) * s
	var fh := lerpf(0.34, 0.43, _g("chin")) * s
	if age < 14:
		fw *= 0.86
		fh *= 0.88
	var skin := _skin_color()
	var hair := _hair_color()
	var style := int(genome.get("hair_style", 0))
	var shoulder_y := head_c.y + fh * 0.88

	_draw_clothing(cx, s, shoulder_y)
	_draw_hair_back(cx, head_c, fw, fh, s, hair, style)
	_draw_ancestry_back(head_c, fw, fh, hair)
	_draw_head(cx, head_c, fw, fh, skin, s)
	_draw_features(cx, head_c, fw, fh, s, skin, hair)
	_draw_ancestry_front(cx, head_c, fw, fh, skin, s)
	_draw_marks(cx, head_c, fw, fh, s, skin)
	_draw_beard(cx, head_c, fw, fh, hair, s)
	_draw_hair_front(cx, head_c, fw, fh, s, hair, style)
	_draw_accessories(cx, head_c, fw, fh, s)
	_draw_headwear(cx, head_c, fw, fh, s, hair)
	_draw_house_mark(s)

	if framed:
		_draw_frame(s)
