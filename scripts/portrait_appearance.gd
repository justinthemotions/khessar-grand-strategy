class_name PortraitAppearance
extends RefCounted

## Shared phenotype resolver for campaign portraits and tactical hero sprites.
##
## Appearance is a pure function of a SimCharacter's inherited genome, age,
## presentation, and ancestry.  Keeping the color math here prevents the
## battle layer from rolling or approximating a second version of the person.

const DEFAULT_SKIN := Color("caa07a")
const DEFAULT_HAIR := Color("4f321c")
const DEFAULT_EYE := Color("526f82")


static func _gene(genome: Dictionary, key: String, fallback: float = 0.5) -> float:
	return clampf(float(genome.get(key, fallback)), 0.0, 1.0)


static func _color_value(value, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is String and not str(value).is_empty():
		return Color.from_string(str(value), fallback)
	return fallback


static func profile_color(profile: Dictionary, key: String, fallback: Color) -> Color:
	return _color_value(profile.get(key, null), fallback)


static func natural_skin_color(genome: Dictionary) -> Color:
	var tone := _gene(genome, "skin")
	var undertone := _gene(genome, "undertone")
	var warm := Color(1.0, 0.82, 0.62).lerp(Color(0.55, 0.34, 0.22), tone)
	var cool := Color(0.92, 0.78, 0.70).lerp(Color(0.43, 0.31, 0.27), tone)
	return cool.lerp(warm, undertone)


static func _orc_skin_color(genome: Dictionary) -> Color:
	var tone := _gene(genome, "skin")
	var undertone := _gene(genome, "undertone")
	var light := Color("a8b975").lerp(Color("a79b59"), undertone)
	var dark := Color("3b5132").lerp(Color("5a472d"), undertone)
	return light.lerp(dark, tone)


static func _tiefling_skin_color(genome: Dictionary) -> Color:
	# The inherited undertone crosses a cool blue/violet to warm crimson
	# spectrum, allowing authored Khessari bloodlines to remain varied without
	# introducing battle-only random colors.
	var tone := _gene(genome, "skin")
	var family := _gene(genome, "undertone")
	var light := Color("7196bd").lerp(Color("b85c62"), family)
	var dark := Color("304964").lerp(Color("642c3a"), family)
	return light.lerp(dark, tone)


static func skin_color(genome: Dictionary, race: String = "", context: Dictionary = {}) -> Color:
	var natural := natural_skin_color(genome)
	# Authored overrides take priority and pass through unchanged. This also
	# leaves room for setting-specific hues beyond the currently simulated
	# ancestries without changing either renderer.
	if context.has("skin_color"):
		return _color_value(context["skin_color"], natural)
	if genome.has("skin_color"):
		return _color_value(genome["skin_color"], natural)
	match race:
		"orc":
			return _orc_skin_color(genome)
		"half_orc":
			return natural.lerp(_orc_skin_color(genome), 0.56)
		"tiefling":
			return _tiefling_skin_color(genome)
		"half_tiefling":
			return natural.lerp(_tiefling_skin_color(genome), 0.58)
		"dwarf":
			return natural.lerp(Color("9a6747"), 0.08)
		"half_dwarf":
			return natural.lerp(Color("9a6747"), 0.04)
		"elf":
			return natural.lightened(0.035)
		"half_elf":
			return natural.lightened(0.018)
		_:
			return natural


static func hair_color(genome: Dictionary, age: int, context: Dictionary = {}) -> Color:
	var t := _gene(genome, "hair_hue")
	var color: Color
	if t < 0.33:
		color = Color(0.85, 0.72, 0.45).lerp(Color(0.55, 0.27, 0.12), t / 0.33)
	elif t < 0.66:
		color = Color(0.55, 0.27, 0.12).lerp(Color(0.32, 0.20, 0.11), (t - 0.33) / 0.33)
	else:
		color = Color(0.32, 0.20, 0.11).lerp(Color(0.08, 0.07, 0.06), (t - 0.66) / 0.34)
	if context.has("hair_color"):
		color = _color_value(context["hair_color"], color)
	elif genome.has("hair_color"):
		color = _color_value(genome["hair_color"], color)
	if age > 40:
		color = color.lerp(Color(0.78, 0.77, 0.74), clampf((age - 40) / 28.0, 0.0, 0.85))
	return color


static func eye_color(genome: Dictionary, context: Dictionary = {}) -> Color:
	var t := _gene(genome, "eye_hue")
	var color: Color
	if t < 0.5:
		color = Color(0.30, 0.45, 0.62).lerp(Color(0.30, 0.48, 0.30), t / 0.5)
	else:
		color = Color(0.30, 0.48, 0.30).lerp(Color(0.28, 0.18, 0.10), (t - 0.5) / 0.5)
	if context.has("eye_color"):
		return _color_value(context["eye_color"], color)
	if genome.has("eye_color"):
		return _color_value(genome["eye_color"], color)
	return color


static func battle_profile(genome: Dictionary, age: int, is_female: bool,
		race: String = "human", culture: String = "", context: Dictionary = {}) -> Dictionary:
	var skin := skin_color(genome, race, context)
	var hair := hair_color(genome, age, context)
	var eyes := eye_color(genome, context)
	var ear_kind := "round"
	if race in ["elf", "half_elf", "tiefling", "half_tiefling"]:
		ear_kind = "pointed"
	elif race in ["orc", "half_orc"]:
		ear_kind = "broad"
	return {
		"version": 1,
		"skin_color": skin,
		"skin_shadow": skin.darkened(0.20),
		"hair_color": hair,
		"eye_color": eyes,
		"hair_style": clampi(int(genome.get("hair_style", 0)), 0, 3),
		"hair_texture": _gene(genome, "hair_texture"),
		"beard": _gene(genome, "beard"),
		"face_width": _gene(genome, "face_width"),
		"jaw": _gene(genome, "jaw"),
		"presence": _gene(genome, "presence"),
		"severity": _gene(genome, "severity"),
		"age": age,
		"is_female": is_female,
		"race": race,
		"culture": culture,
		"ear_kind": ear_kind,
		"has_tusks": race in ["orc", "half_orc"],
		"has_horns": race in ["tiefling", "half_tiefling"],
	}
