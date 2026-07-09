class_name FaceView
extends Control

## Draws a procedural dynastic portrait from a genome plus character context.
## The look aims for flat saga illustration: strong silhouettes, angular
## face planes, readable beauty/menace, and simple inherited shapes.

signal pressed

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


func _skin_color() -> Color:
	var warm := Color(1.0, 0.82, 0.62).lerp(Color(0.55, 0.34, 0.22), _g("skin"))
	var cool := Color(0.92, 0.78, 0.70).lerp(Color(0.43, 0.31, 0.27), _g("skin"))
	return cool.lerp(warm, _g("undertone"))


func _hair_color() -> Color:
	var t := _g("hair_hue")
	var col: Color
	if t < 0.33:
		col = Color(0.85, 0.72, 0.45).lerp(Color(0.55, 0.27, 0.12), t / 0.33)
	elif t < 0.66:
		col = Color(0.55, 0.27, 0.12).lerp(Color(0.32, 0.20, 0.11), (t - 0.33) / 0.33)
	else:
		col = Color(0.32, 0.20, 0.11).lerp(Color(0.08, 0.07, 0.06), (t - 0.66) / 0.34)
	if age > 40:
		col = col.lerp(Color(0.78, 0.77, 0.74), clampf((age - 40) / 28.0, 0.0, 0.85))
	return col


func _eye_color() -> Color:
	var t := _g("eye_hue")
	if t < 0.5:
		return Color(0.30, 0.45, 0.62).lerp(Color(0.30, 0.48, 0.30), t / 0.5)
	return Color(0.30, 0.48, 0.30).lerp(Color(0.28, 0.18, 0.10), (t - 0.5) / 0.5)


func _realm_color() -> Color:
	var realm_id := int(_ctx("realm_id", -1))
	if realm_id == 0:
		return Color("8f2f2c")
	if realm_id == 1:
		return Color("355a70")
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


func _draw_background(s: float) -> void:
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
	var asym := (_hash01(str(_ctx("id", 0)) + "asym") - 0.5) * _irregularity() * s * 0.08
	var jaw_w := fw * lerpf(0.47, 0.78, _g("jaw"))
	var brow_w := fw * lerpf(0.62, 0.80, _g("severity"))
	var cheek_w := fw * lerpf(0.86, 1.08, _g("cheek"))
	var chin_drop := fh * lerpf(0.78, 1.02, _g("chin"))
	var head := PackedVector2Array([
		head_c + Vector2(-brow_w + asym * 0.3, -fh * 0.72),
		head_c + Vector2(brow_w + asym * 0.2, -fh * 0.72),
		head_c + Vector2(cheek_w + asym, -fh * 0.06),
		head_c + Vector2(jaw_w + asym * 0.5, fh * 0.43),
		head_c + Vector2(asym * 0.25, chin_drop),
		head_c + Vector2(-jaw_w + asym * 0.2, fh * 0.43),
		head_c + Vector2(-cheek_w + asym * 0.4, -fh * 0.06),
	])
	draw_colored_polygon(head, skin)
	draw_colored_polygon(PackedVector2Array([
		head_c + Vector2(-brow_w + asym * 0.3, -fh * 0.72),
		head_c + Vector2(asym * 0.1, -fh * 0.55),
		head_c + Vector2(asym * 0.2, fh * 0.55),
		head_c + Vector2(-jaw_w + asym * 0.2, fh * 0.43),
		head_c + Vector2(-cheek_w + asym * 0.4, -fh * 0.06),
	]), skin.darkened(0.05 + _wear_level() * 0.09))
	draw_colored_polygon(PackedVector2Array([
		head_c + Vector2(asym * 0.1, -fh * 0.55),
		head_c + Vector2(brow_w + asym * 0.2, -fh * 0.72),
		head_c + Vector2(cheek_w + asym, -fh * 0.06),
		head_c + Vector2(asym * 0.2, fh * 0.55),
	]), skin.lightened(0.035 + _beauty_score() * 0.045))


func _draw_hair(cx: float, head_c: Vector2, fw: float, fh: float, s: float, hair: Color, style: int) -> void:
	var texture := _g("hair_texture")
	var hooded := style == 1 or _menace_score() > 0.78
	if hooded:
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(-fw * 1.25, -fh * 0.76),
			head_c + Vector2(0, -fh * 1.15),
			head_c + Vector2(fw * 1.22, -fh * 0.72),
			head_c + Vector2(fw * 1.0, fh * 0.62),
			head_c + Vector2(0, fh * 1.05),
			head_c + Vector2(-fw * 1.0, fh * 0.62),
		]), _realm_color().darkened(0.3))
	if is_female or style == 2:
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(-fw * lerpf(1.05, 1.24, texture), -fh * 0.55),
			head_c + Vector2(-fw * 0.78, fh * 0.72),
			head_c + Vector2(-fw * 0.18, fh * 0.96),
			head_c + Vector2(fw * 0.82, fh * 0.70),
			head_c + Vector2(fw * lerpf(1.0, 1.22, texture), -fh * 0.52),
		]), hair.darkened(0.05))
	if style == 3 and not is_female:
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(-fw * 0.95, -fh * 0.42),
			head_c + Vector2(-fw * 0.45, -fh * 0.80),
			head_c + Vector2(-fw * 0.10, -fh * 0.58),
			head_c + Vector2(-fw * 0.65, -fh * 0.28),
		]), hair)
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(fw * 0.95, -fh * 0.42),
			head_c + Vector2(fw * 0.45, -fh * 0.80),
			head_c + Vector2(fw * 0.10, -fh * 0.58),
			head_c + Vector2(fw * 0.65, -fh * 0.28),
		]), hair)
	else:
		draw_colored_polygon(PackedVector2Array([
			head_c + Vector2(-fw * 1.02, -fh * 0.63),
			head_c + Vector2(-fw * 0.46, -fh * 0.96),
			head_c + Vector2(fw * 0.14, -fh * 0.86),
			head_c + Vector2(fw * 0.95, -fh * 0.52),
			head_c + Vector2(fw * 0.55, -fh * 0.32),
			head_c + Vector2(-fw * 0.15, -fh * 0.40),
		]), hair)
	if style == 2 and not is_female:
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - s * 0.05, head_c.y - fh * 1.06),
			Vector2(cx + s * 0.03, head_c.y - fh * 1.24),
			Vector2(cx + s * 0.09, head_c.y - fh * 1.05),
			Vector2(cx + s * 0.01, head_c.y - fh * 0.96),
		]), hair)


func _draw_features(cx: float, head_c: Vector2, fw: float, fh: float, s: float, skin: Color, hair: Color) -> void:
	var beauty := _beauty_score()
	var menace := _menace_score()
	var eye_y := head_c.y - fh * 0.12
	var eye_dx := fw * lerpf(0.38, 0.52, _g("eye_spacing"))
	var eye_w := s * lerpf(0.030, 0.052, _g("eye_size")) * lerpf(0.82, 1.12, beauty)
	var eye_h := eye_w * lerpf(0.22, 0.46, 1.0 - menace)
	var brow_thick := maxf(1.0, s * lerpf(0.010, 0.024, _g("brow")))
	for side in [-1.0, 1.0]:
		var ec := Vector2(cx + side * eye_dx, eye_y)
		draw_colored_polygon(PackedVector2Array([
			ec + Vector2(-eye_w * 1.5, 0),
			ec + Vector2(-eye_w * 0.35, -eye_h),
			ec + Vector2(eye_w * 1.35, -eye_h * 0.15),
			ec + Vector2(eye_w * 1.0, eye_h),
			ec + Vector2(-eye_w * 1.1, eye_h * 0.65),
		]), Color("f0e6d8"))
		draw_circle(ec + Vector2(eye_w * 0.08, 0), eye_w * 0.36, _eye_color().lightened(beauty * 0.12))
		draw_circle(ec + Vector2(eye_w * 0.08, 0), eye_w * 0.16, Color("0b0908"))
		var tilt := lerpf(0.05, 0.28, menace) * s
		draw_line(
			Vector2(ec.x - eye_w * 1.65, eye_y - eye_w * 1.05 + tilt * side),
			Vector2(ec.x + eye_w * 1.55, eye_y - eye_w * 1.35 - tilt * side),
			hair.darkened(0.28),
			brow_thick
		)

	var nose_len := lerpf(0.10, 0.17, _g("nose")) * s
	var crooked := (_hash01(str(_ctx("id", 0)) + "nose") - 0.5) * _irregularity() * s * 0.07
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, eye_y + eye_w * 0.45),
		Vector2(cx + fw * 0.10 + crooked, eye_y + nose_len),
		Vector2(cx - fw * 0.06 + crooked * 0.4, eye_y + nose_len + s * 0.025),
	]), skin.darkened(0.11 + menace * 0.06))
	draw_line(Vector2(cx + crooked * 0.35, eye_y + eye_w * 0.5), Vector2(cx + crooked, eye_y + nose_len), skin.darkened(0.28), maxf(1.0, s * 0.010))

	var mouth_y := head_c.y + fh * 0.43
	var mw := lerpf(0.30, 0.58, _g("mouth")) * fw
	var expression := lerpf(s * 0.012, -s * 0.018, menace)
	if beauty > 0.68 and menace < 0.55:
		expression += s * 0.014
	draw_polyline(PackedVector2Array([
		Vector2(cx - mw, mouth_y),
		Vector2(cx, mouth_y + expression),
		Vector2(cx + mw, mouth_y),
	]), Color("6e332e").lerp(skin.darkened(0.42), menace * 0.45), maxf(1.0, s * 0.013))


func _draw_beard(cx: float, head_c: Vector2, fw: float, fh: float, hair: Color, s: float) -> void:
	if is_female or _g("beard") <= 0.45 or age < 16:
		return
	var blen := lerpf(0.18, 0.62, (_g("beard") - 0.45) / 0.55)
	draw_colored_polygon(PackedVector2Array([
		head_c + Vector2(-fw * 0.74, fh * 0.26),
		head_c + Vector2(fw * 0.72, fh * 0.24),
		head_c + Vector2(fw * 0.46, fh * (0.58 + blen)),
		head_c + Vector2(0, fh * (0.78 + blen)),
		head_c + Vector2(-fw * 0.48, fh * (0.58 + blen)),
	]), hair.darkened(0.03))
	draw_line(Vector2(cx - fw * 0.34, head_c.y + fh * 0.54), Vector2(cx + fw * 0.34, head_c.y + fh * 0.52), hair.lightened(0.08), maxf(1.0, s * 0.012))


func _draw_marks(cx: float, head_c: Vector2, fw: float, fh: float, s: float, skin: Color) -> void:
	var beauty := _beauty_score()
	var menace := _menace_score()
	var wear := _wear_level()
	if age > 50 or wear > 0.45:
		var wr := skin.darkened(0.22)
		draw_line(head_c + Vector2(-fw * 0.42, fh * 0.12), head_c + Vector2(-fw * 0.20, fh * 0.16), wr, maxf(1.0, s * 0.007))
		draw_line(head_c + Vector2(fw * 0.22, fh * 0.16), head_c + Vector2(fw * 0.44, fh * 0.12), wr, maxf(1.0, s * 0.007))
	if menace > 0.62 or _irregularity() > 0.55:
		var scar_seed := _hash01(str(_ctx("id", 0)) + str(_ctx("dynasty", "")))
		if scar_seed > 0.38:
			var sx := cx + lerpf(-fw * 0.38, fw * 0.34, scar_seed)
			draw_line(Vector2(sx, head_c.y - fh * 0.20), Vector2(sx + fw * 0.15, head_c.y + fh * 0.34), skin.darkened(0.34), maxf(1.0, s * 0.010))
	if beauty > 0.72 and menace < 0.58:
		draw_circle(head_c + Vector2(0, -fh * 0.01), maxf(1.0, s * 0.011), Color("f3dfb0").lerp(_eye_color(), 0.25))


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 0.0:
		return
	_draw_background(s)
	if genome.is_empty():
		if framed:
			draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2.0), Color("2a211c"), false, 2.0)
		return

	var cx := size.x * 0.5
	var head_c := Vector2(cx, s * 0.47)
	var fw := lerpf(0.23, 0.34, _g("face_width")) * s
	var fh := lerpf(0.34, 0.42, _g("chin")) * s
	if age < 14:
		fw *= 0.86
		fh *= 0.88
	var skin := _skin_color()
	var hair := _hair_color()
	var style := int(genome.get("hair_style", 0))
	var shoulder_y := head_c.y + fh * 0.88

	_draw_clothing(cx, s, shoulder_y)
	_draw_hair(cx, head_c, fw, fh, s, hair, style)
	_draw_head(cx, head_c, fw, fh, skin, s)
	_draw_beard(cx, head_c, fw, fh, hair, s)
	_draw_features(cx, head_c, fw, fh, s, skin, hair)
	_draw_marks(cx, head_c, fw, fh, s, skin)
	_draw_house_mark(s)

	if framed:
		var frame_col := Color("7a6134").lerp(Color("2d2320"), _menace_score() * 0.35)
		draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2.0), frame_col, false, 2.0)
