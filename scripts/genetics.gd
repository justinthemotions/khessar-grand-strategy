class_name Genetics
extends RefCounted

## Heritable appearance genes, the "mathematical faces" system.
##
## Continuous genes live in 0..1. A child's gene is the mid-parent value
## plus a gaussian mutation term — classic polygenic inheritance:
##     child = clamp( (father + mother) / 2  +  N(0, 0.08),  0, 1 )
## Discrete genes (hair style) inherit one parent's allele outright, with
## a small chance of a novel mutation. Faces are a pure function of the
## genome (see face_view.gd), so the same genome always draws the same
## face, and family resemblance falls out of the math for free.

const CONTINUOUS: Array[String] = [
	"skin",        # skin tone
	"undertone",   # cool -> warm undertone
	"hair_hue",    # blonde -> red -> brown -> black
	"eye_hue",     # blue -> green -> brown
	"face_width",  # narrow -> broad
	"jaw",         # tapered chin -> square jaw
	"chin",        # short -> long chin
	"cheek",       # soft -> sharp cheekbones
	"nose",        # nose length
	"eye_size",
	"eye_spacing",
	"symmetry",    # irregular -> harmonious features
	"brow",        # brow thickness
	"mouth",       # mouth width
	"presence",    # plain -> striking face
	"severity",    # gentle -> intimidating planes
	"beard",       # males: expresses as a beard above 0.45
	"hair_texture", # straight -> coarse/wavy silhouette
]
const DETAIL_CONTINUOUS: Array[String] = [
	"nose_width",  # narrow -> broad bridge and nostrils
	"eye_tilt",    # downturned -> upturned outer corners
	"lip_fullness",
	"forehead",    # low/broad hairline -> tall/narrow brow
	"ear_size",
	"neck_width",
]
const HAIR_STYLES: int = 4
const MUTATION_SIGMA: float = 0.08
const STYLE_MUTATION_CHANCE: float = 0.1


static func founder(rng: RandomNumberGenerator) -> Dictionary:
	var g := {}
	for key in CONTINUOUS:
		g[key] = rng.randf()
	g["hair_style"] = rng.randi_range(0, HAIR_STYLES - 1)
	# Appearance-only additions use a forked stream. The main RNG therefore
	# advances exactly as it did before these genes existed, preserving world
	# generation, traits, council appointments, and event outcomes by seed.
	var detail_rng := RandomNumberGenerator.new()
	detail_rng.seed = int(rng.state) ^ 0x2D4C6B8A1735
	for key in DETAIL_CONTINUOUS:
		g[key] = detail_rng.randf()
	return g


static func inherit(rng: RandomNumberGenerator, father: Dictionary, mother: Dictionary) -> Dictionary:
	var g := {}
	for key in CONTINUOUS:
		var mid: float = (float(father.get(key, 0.5)) + float(mother.get(key, 0.5))) * 0.5
		g[key] = clampf(mid + rng.randfn(0.0, MUTATION_SIGMA), 0.0, 1.0)
	if rng.randf() < STYLE_MUTATION_CHANCE:
		g["hair_style"] = rng.randi_range(0, HAIR_STYLES - 1)
	else:
		g["hair_style"] = father["hair_style"] if rng.randf() < 0.5 else mother["hair_style"]
	var detail_rng := RandomNumberGenerator.new()
	detail_rng.seed = int(rng.state) ^ 0x63A91D5E2047
	for key in DETAIL_CONTINUOUS:
		var mid: float = (float(father.get(key, 0.5)) + float(mother.get(key, 0.5))) * 0.5
		g[key] = clampf(mid + detail_rng.randfn(0.0, MUTATION_SIGMA), 0.0, 1.0)
	return g
