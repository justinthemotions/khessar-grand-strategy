class_name CultureData
extends RefCounted

## The twelve cultures of Khessar at Year Zero, per the Cultural Roster
## (v1.0) companion document. Culture is martial tradition, not blood:
## it decides specialty unit rosters, marriage acceptance, government
## compatibility, naming pools, and (in later modules) traditions and
## syncretism. This file is data — the mechanics that read it live in
## battle_sim.gd (unit presets) and world.gd (recruiting, marriage).
##
## Implemented now: unit rosters + recruit gating (Design Decision A),
## marriage acceptance modifiers, province/character culture assignment.
## Data-only until their modules land: traditions, syncretism timelines,
## government-compatibility lists, the Sovereignty recovery arc.

# ---------------------------------------------------------------- cultures
# id -> record. `units` are the specialty kinds beyond the universal
# roster (levy/sword/cav/archer, available to everyone). `marriage` is
# the opinion modifier applied when a cross-culture match is made.
# `governments` (compatibility) and `traditions`/`syncretism` are design
# data for later modules — kept faithful to the Roster document.
const CULTURES := {
	"vael": {
		"label": "Vael",
		"blurb": "The Magistocracy's administrative class: academy training, arcane forces organized at scale",
		"units": ["vael_arcane_retinue", "vael_court_company"],
		"governments": ["administrative", "feudal", "merchant_republic"],
		"marriage": {"aelindran": 5, "free_city": 0, "halveni": 0, "drevak": -10, "karn_vol": -5,
			"kharak_dum": 0, "brushgate": 5, "veldarin": 10, "thaladris": 10, "southern_reach": 0},
		"traditions": ["Academy Network", "Administrative Rigor", "Arcane Patronage"],
		"name_pool": "vael",
	},
	"aelindran": {
		"label": "Aelindran",
		"blurb": "The old feudal culture of the plains — the noble houses under Magistocracy rule; their loyalty is political, their culture is older",
		"units": ["aelindran_household_cavalry", "aelindran_sworn_sword"],
		"governments": ["feudal", "administrative", "clan"],
		"marriage": {"vael": 5, "free_city": -5, "halveni": -10, "drevak": -25, "karn_vol": -15,
			"kharak_dum": -5, "brushgate": 0, "veldarin": 15, "thaladris": 10, "southern_reach": -5},
		"traditions": ["Hereditary Martial Line", "House Sworn Oath", "Courtly Grace"],
		"name_pool": "vael",
	},
	"free_city": {
		"label": "Free City",
		"blurb": "Pellar, Carath and Dunmore: civic militia, professional watch, and a habit of resisting central authority",
		"units": ["city_watch", "contract_militia"],
		"governments": ["feudal", "merchant_republic", "administrative"],
		"marriage": {"vael": 0, "aelindran": -5, "halveni": 15, "drevak": -15, "karn_vol": -10,
			"kharak_dum": 0, "brushgate": 5, "veldarin": 5, "thaladris": 5, "southern_reach": 10},
		"traditions": ["Civic Charter", "Watch-Trained", "Mercantile Flexibility"],
		"name_pool": "free_city",
	},
	"halveni": {
		"label": "Halveni",
		"blurb": "Halven's merchant-democrat tradition — merchant leadership legitimate on its own terms, contracts over crowns",
		"units": ["harbor_guard", "coin_sworn"],
		"governments": ["merchant_republic", "feudal", "administrative"],
		"marriage": {"vael": 0, "aelindran": -10, "free_city": 15, "drevak": -10, "karn_vol": -10,
			"kharak_dum": 5, "brushgate": 10, "veldarin": 5, "thaladris": 5, "southern_reach": 15},
		"traditions": ["Mercantile Council", "Coin-Sworn Oath", "Harbor Network"],
		"name_pool": "free_city",
	},
	"drevak": {
		"label": "Drevak",
		"blurb": "The warrior culture of the northern clans: prowess, clan-identity, and combat without conventional morale collapse",
		"units": ["drevak_berserker", "drevak_war_column"],
		"governments": ["tribal", "clan", "feudal"],
		"marriage": {"vael": -10, "aelindran": -25, "free_city": -15, "halveni": -10, "karn_vol": 30,
			"kharak_dum": 15, "brushgate": 10, "veldarin": -20, "thaladris": -15, "southern_reach": -5},
		"traditions": ["Ancestral Witness", "Berserker Oath", "Clan-Bound"],
		"name_pool": "drevak_orc",
	},
	"karn_vol": {
		"label": "Karn-Vol",
		"blurb": "The border clan's Drevak subvariant: sixty years of compact-holding taught it the etiquette of peace with Humans",
		"units": ["drevak_berserker", "drevak_war_column", "compact_sworn"],  # parent roster + the compact's own
		"governments": ["tribal", "clan", "feudal"],
		"marriage": {"vael": 0, "aelindran": -15, "free_city": -5, "halveni": 0, "drevak": 20,
			"kharak_dum": 20, "brushgate": 15, "veldarin": -10, "thaladris": -5, "southern_reach": 5},
		"traditions": ["Compact-Holding", "Border Diplomacy", "Shared-Meal Ceremony"],
		"name_pool": "drevak_orc",
	},
	"kharak_dum": {
		"label": "Kharak-Dum Dwarven",
		"blurb": "Hold-hall culture: ward-craft, metalwork, and defense measured in generations",
		"units": ["dwarven_ironside", "ward_speaker_retinue"],
		"governments": ["feudal", "clan", "tribal"],
		"marriage": {"vael": 0, "aelindran": -5, "free_city": 0, "halveni": 5, "drevak": 15,
			"karn_vol": 20, "brushgate": 25, "veldarin": -5, "thaladris": -5, "southern_reach": 0},
		"traditions": ["Ward-Craft Tradition", "Hold-Hall Defense", "Ward-Stone Maintenance"],
		"name_pool": "dwarven",
	},
	"brushgate": {
		"label": "Brushgate",
		"blurb": "A martial-philosophical order, Dwarven in origin and open to all: body-discipline, breath-work, being-present-with-the-dying",
		"units": ["brushgate_column"],
		"governments": ["feudal", "tribal", "administrative", "merchant_republic", "clan"],  # overlays any governance
		"marriage": {"vael": 5, "aelindran": 0, "free_city": 5, "halveni": 10, "drevak": 10,
			"karn_vol": 15, "kharak_dum": 25, "veldarin": 5, "thaladris": 5, "southern_reach": 10},
		"traditions": ["Order of the Body", "Being-Present", "Column Discipline"],
		"name_pool": "",  # practitioners keep their race-of-origin's names
	},
	"veldarin": {
		"label": "Veldarin Elven",
		"blurb": "The elder Great House: contemplative, withdrawn for 180 years, and lethal under its own trees",
		"units": ["veldarin_forest_sworn", "veldarin_elder_guard"],
		"governments": ["clan", "feudal"],
		"marriage": {"vael": 10, "aelindran": 15, "free_city": 5, "halveni": 5, "drevak": -20,
			"karn_vol": -10, "kharak_dum": -5, "brushgate": 5, "thaladris": -10, "southern_reach": 0},
		"traditions": ["Elven Longevity", "Forest-Bound", "Elder-Council"],
		"name_pool": "elven_veldarin",
	},
	"thaladris": {
		"label": "Thaladris Elven",
		"blurb": "The younger Great House: the 'practical' Elven tradition, singing to the battle and writing to the Iron Library",
		"units": ["thaladris_song_bound", "thaladris_elder_guard"],
		"governments": ["clan", "feudal"],
		"marriage": {"vael": 10, "aelindran": 10, "free_city": 5, "halveni": 5, "drevak": -15,
			"karn_vol": -5, "kharak_dum": -5, "brushgate": 5, "veldarin": -10, "southern_reach": 5},
		"traditions": ["Elven Longevity", "Song-Bound Discipline", "Correspondence Network"],
		"name_pool": "elven_thaladris",
	},
	"southern_reach": {
		"label": "Southern Reach",
		"blurb": "Saren-Vesh's coastal-commercial culture — genuinely mixed by race, secular by long habit",
		"units": ["southern_marine", "trade_guard"],
		"governments": ["merchant_republic", "feudal", "administrative"],
		"marriage": {"vael": 0, "aelindran": -5, "free_city": 10, "halveni": 15, "drevak": -5,
			"karn_vol": 5, "kharak_dum": 0, "brushgate": 10, "veldarin": 0, "thaladris": 5},
		"traditions": ["Coastal Mercantile", "Trade-Guard Network", "Cosmopolitan Court"],
		"name_pool": "southern_reach",
	},
	"sovereignty": {
		"label": "Sovereignty",
		"blurb": "The dead culture of the Aurath Dragonborn — no living practitioners; the Pale Court preserves but does not teach",
		"units": [],  # unit kinds are dormant — see DORMANT_UNITS
		"governments": [],
		"marriage": {},
		"traditions": [],
		"name_pool": "aurath",
	},
}

# Sovereignty unit kinds exist only in the Pale Court's archives at Year
# Zero. Late-game content (standing with the Pale Court + acknowledging
# the Sovereignty's history) unlocks cultural recovery and these kinds.
const DORMANT_UNITS := ["draconic_breath_sworn", "sovereignty_guard", "song_warden"]

# Hybrid cultures that syncretism can produce (Roster v1.0 reference
# section). Designer data — full entries are authored if/when one emerges.
const HYBRIDS := {
	"vael_aristocratic": {"label": "Vael-Aristocratic", "parents": ["vael", "aelindran"], "years": 30},
	"vael_ironvault": {"label": "Vael-Ironvault", "parents": ["vael", "kharak_dum"], "years": 40},
	"vael_halveni_banking": {"label": "Vael-Halveni-Banking", "parents": ["vael", "halveni"], "years": 30},
	"brushgate_ironvault": {"label": "Brushgate-Ironvault", "parents": ["brushgate", "kharak_dum"], "years": 20},
	"drevak_compact": {"label": "Drevak-Compact", "parents": ["drevak", "karn_vol"], "years": 10},  # effectively already blended
	"border_compact_aristocratic": {"label": "Border-Compact-Aristocratic", "parents": ["karn_vol", "aelindran"], "years": 60},  # once in canonical history
	"commercial_compact": {"label": "Commercial-Compact", "parents": ["southern_reach", "halveni"], "years": 20},
	"coastal_commercial": {"label": "Coastal-Commercial", "parents": ["free_city", "southern_reach"], "years": 25},
	"free_city_merchant_democrat": {"label": "Free-City-Merchant-Democrat", "parents": ["free_city", "halveni"], "years": 20},
	"high_court_elven": {"label": "High-Court-Elven", "parents": ["aelindran", "veldarin"], "years": 30},
}

# Hybrids born in play between parents with no named hybrid above are
# registered here at Cultural Hybridization time (Cross-Cultural Marriage
# v1.0 — e.g. Scenario 1's Compact-Free-City). Runtime state, not const.
static var runtime_hybrids: Dictionary = {}

# ---------------------------------------------------------------- syncretism
# Months of shared household before Cultural Hybridization can fire, from
# the Roster's affinity grades via the Marriage doc's tier table (VERY
# HIGH 240 / HIGH 360 / MODERATE 480 / LOW-MODERATE 540 / LOW 720 / VERY
# LOW 960); where the Roster names an explicit timeline, that wins.
# Keys are "a|b" with the two culture ids sorted. Unlisted pairs default
# to 480 (MODERATE). The dead Sovereignty never blends.
const SYNCRETISM_MONTHS := {
	"aelindran|vael": 360, "free_city|vael": 360, "halveni|vael": 360,
	"drevak|vael": 600, "karn_vol|vael": 480, "kharak_dum|vael": 480,
	"brushgate|vael": 420, "vael|veldarin": 660, "thaladris|vael": 660,
	"southern_reach|vael": 420,
	"aelindran|free_city": 480, "aelindran|halveni": 720, "aelindran|drevak": 720,
	"aelindran|karn_vol": 720, "aelindran|kharak_dum": 420, "aelindran|brushgate": 420,
	"aelindran|veldarin": 360, "aelindran|thaladris": 420, "aelindran|southern_reach": 540,
	"free_city|halveni": 240, "drevak|free_city": 540, "free_city|karn_vol": 540,
	"free_city|kharak_dum": 420, "brushgate|free_city": 420, "free_city|veldarin": 420,
	"free_city|thaladris": 420, "free_city|southern_reach": 300,
	"drevak|halveni": 720, "halveni|karn_vol": 720, "halveni|kharak_dum": 360,
	"brushgate|halveni": 420, "halveni|veldarin": 420, "halveni|thaladris": 420,
	"halveni|southern_reach": 240,
	"drevak|karn_vol": 120, "drevak|kharak_dum": 420, "brushgate|drevak": 420,
	"drevak|veldarin": 960, "drevak|thaladris": 960, "drevak|southern_reach": 540,
	"karn_vol|kharak_dum": 420, "brushgate|karn_vol": 420, "karn_vol|veldarin": 960,
	"karn_vol|thaladris": 960, "karn_vol|southern_reach": 540,
	"brushgate|kharak_dum": 240, "kharak_dum|veldarin": 600, "kharak_dum|thaladris": 600,
	"kharak_dum|southern_reach": 480,
	"brushgate|veldarin": 420, "brushgate|thaladris": 420, "brushgate|southern_reach": 420,
	"thaladris|veldarin": 540, "southern_reach|veldarin": 540,
	"southern_reach|thaladris": 540,
}

# ---------------------------------------------------------------- races
# The biology layer (Cross-Cultural Marriage v1.0 §2). Lifespans are the
# doc's canon; full Orc span is unspecified there — 70 chosen to sit
# beside the Human 70-80 band (flag for Justin). Only human/orc/half_orc
# are reachable in the two simulated courts today; the rest are data for
# when more realms come online. `prowess` is the racial stat baseline
# from the Roster ("Half-Orcs +2 Prowess" etc.).
const RACES := {
	"human":         {"label": "Human",         "lifespan": 78,   "stats": {}},
	"orc":           {"label": "Orc",           "lifespan": 70,   "stats": {"prw": 2}},
	"half_orc":      {"label": "Half-Orc",      "lifespan": 90,   "stats": {"prw": 2}},
	"dwarf":         {"label": "Dwarf",         "lifespan": 350,  "stats": {"stw": 2}},
	"half_dwarf":    {"label": "Half-Dwarf",    "lifespan": 150,  "stats": {"stw": 1}},
	"elf":           {"label": "Elf",           "lifespan": 1000, "stats": {"lrn": 2}},
	"half_elf":      {"label": "Half-Elf",      "lifespan": 200,  "stats": {"lrn": 1}},
	"tiefling":      {"label": "Tiefling",      "lifespan": 90,   "stats": {"int": 1}},
	"half_tiefling": {"label": "Half-Tiefling", "lifespan": 85,   "stats": {}},
}

# one parent of each base race -> the half demographic
const HALF_OF := {
	"human|orc": "half_orc", "dwarf|human": "half_dwarf",
	"elf|human": "half_elf", "human|tiefling": "half_tiefling",
}

# ---------------------------------------------------------------- units
# Which culture each specialty kind belongs to (Design Decision A: the
# ruler's realm must hold at least one province of that culture to
# recruit it). Brushgate has no majority province at Year Zero — its ~200
# practitioners live around the old mountain monasteries, so the Column
# is anchored to Dwarven-culture land instead.
const KIND_CULTURE := {
	"vael_arcane_retinue": "vael", "vael_court_company": "vael",
	"aelindran_household_cavalry": "aelindran", "aelindran_sworn_sword": "aelindran",
	"city_watch": "free_city", "contract_militia": "free_city",
	"harbor_guard": "halveni", "coin_sworn": "halveni",
	"drevak_berserker": "drevak", "drevak_war_column": "drevak",
	"compact_sworn": "karn_vol",
	"dwarven_ironside": "kharak_dum", "ward_speaker_retinue": "kharak_dum",
	"brushgate_column": "kharak_dum",  # monastery access, not majority culture — see note above
	"veldarin_forest_sworn": "veldarin", "veldarin_elder_guard": "veldarin",
	"thaladris_song_bound": "thaladris", "thaladris_elder_guard": "thaladris",
	"southern_marine": "southern_reach", "trade_guard": "southern_reach",
}

# Karn-Vol provinces satisfy a "drevak" requirement (subvariant of the
# parent culture — the clans share the Berserker and War-Column doctrine).
const CULTURE_SATISFIES := {"karn_vol": ["drevak", "karn_vol"]}


# ---------------------------------------------------------------- lookups

static func kinds_of(culture: String) -> Array:
	if not CULTURES.has(culture):
		return []
	return CULTURES[culture]["units"]


static func culture_label(culture: String) -> String:
	if not CULTURES.has(culture):
		return culture.capitalize()
	return str(CULTURES[culture]["label"])


static func marriage_acceptance(a: String, b: String) -> int:
	## Symmetrized cross-culture opinion modifier for a match between
	## practitioners of a and b: each side has its own table; the couple
	## and their courts feel the average of the two receptions.
	if a == b or a == "" or b == "":
		return 0
	var ta: Dictionary = CULTURES.get(a, {}).get("marriage", {})
	var tb: Dictionary = CULTURES.get(b, {}).get("marriage", {})
	return int(round((float(ta.get(b, 0)) + float(tb.get(a, 0))) * 0.5))


static func recruit_culture(kind: String) -> String:
	## The province culture a realm must hold to muster this kind
	## ("" = universal roster, always available).
	return str(KIND_CULTURE.get(kind, ""))


static func satisfies(province_culture: String, wanted: String) -> bool:
	if province_culture == wanted:
		return true
	if CULTURE_SATISFIES.get(province_culture, []).has(wanted):
		return true
	# a hybrid culture inherits both parents' martial rosters ("Access to
	# both Arcane Retinue and Household Cavalry" — Roster hybrid reference);
	# recursion carries subvariant rights through (Karn-Vol hybrids still
	# muster the parent Drevak doctrine)
	for parent in hybrid_parents(province_culture):
		if satisfies(str(parent), wanted):
			return true
	return false


# ---------------------------------------------------------------- syncretism / hybrids

static func syncretism_months(a: String, b: String) -> int:
	## Months of syncretism-path marriage before Cultural Hybridization
	## can fire; -1 = these cultures never blend (the dead Sovereignty).
	if a == b or a == "" or b == "":
		return -1
	if a == "sovereignty" or b == "sovereignty":
		return -1
	var key := ("%s|%s" % [a, b]) if a < b else ("%s|%s" % [b, a])
	return int(SYNCRETISM_MONTHS.get(key, 480))


static func hybrid_of(a: String, b: String) -> String:
	## The hybrid culture id two parents produce — a named Roster hybrid
	## when one exists, else a runtime id registered on first use (new
	## hybrids "the world has not seen before" are part of the design).
	for hid in HYBRIDS:
		var parents: Array = HYBRIDS[hid]["parents"]
		if parents.has(a) and parents.has(b):
			return hid
	for hid in runtime_hybrids:
		var parents: Array = runtime_hybrids[hid]["parents"]
		if parents.has(a) and parents.has(b):
			return hid
	var lo: String = a if a < b else b
	var hi: String = b if a < b else a
	var hid := "%s_%s_hybrid" % [lo, hi]
	runtime_hybrids[hid] = {"label": "%s-%s" % [culture_label(lo), culture_label(hi)],
		"parents": [lo, hi]}
	return hid


static func hybrid_parents(culture: String) -> Array:
	if HYBRIDS.has(culture):
		return HYBRIDS[culture]["parents"]
	if runtime_hybrids.has(culture):
		return runtime_hybrids[culture]["parents"]
	return []


static func hybrid_label(culture: String) -> String:
	if HYBRIDS.has(culture):
		return str(HYBRIDS[culture]["label"])
	if runtime_hybrids.has(culture):
		return str(runtime_hybrids[culture]["label"])
	return culture_label(culture)


# ---------------------------------------------------------------- races

static func race_label(race: String) -> String:
	if not RACES.has(race):
		return race.capitalize()
	return str(RACES[race]["label"])


static func race_lifespan(race: String) -> int:
	if not RACES.has(race):
		return 78
	return int(RACES[race]["lifespan"])


static func child_race(father: String, mother: String) -> String:
	## Biology layer: one parent of each base race makes the half
	## demographic; half-race + half-race breeds true; half-race + base
	## race children are described by their dominant heritage (§2).
	if father == mother:
		return father
	var key := ("%s|%s" % [father, mother]) if father < mother else ("%s|%s" % [mother, father])
	if HALF_OF.has(key):
		return HALF_OF[key]
	# a half-race parent: the child takes the non-half parent's race
	# (quarter heritage is a description, not a demographic)
	if father.begins_with("half_"):
		return mother if not mother.begins_with("half_") else father
	if mother.begins_with("half_"):
		return father
	return father  # exotic base-race pairings default to the father's line


static func province_culture(region: String, owner: int, province_id: int) -> String:
	## Majority culture of a province, derived from its map region plus
	## the Roster's canonical exceptions.
	match region:
		"vael":
			# The academy cities and the crown's plains are Vael-cultured;
			# the old noble countryside — the feud houses' seats and the
			# eastern marches — kept its Aelindran identity under
			# Magistocracy rule (Roster §2: "their culture is older").
			if province_id in [23, 24, 26, 34]:  # Veilkeep, Marling Fields, Voss-Hold, Caer Velmond
				return "aelindran"
			return "vael"
		"free_city":
			if province_id == 59:  # Halven's merchant-democrat variant
				return "halveni"
			return "free_city"
		"drevak_orc":
			# the border clan practices the Karn-Vol subvariant
			return "karn_vol" if owner == 1 else "drevak"
		"dwarven":
			return "kharak_dum"
		"elven_veldarin":
			return "veldarin"
		"elven_thaladris":
			return "thaladris"
		"southern_reach":
			return "southern_reach"
		"ashfields":
			# The Roster names no Ashfields culture; the silence-touched
			# settlements are refugee-mixed, nearest the Reach's coastal
			# tradition. NOTE — flag for Justin's review.
			return "southern_reach"
		"aurath":
			return "sovereignty"  # dead culture holds the ruins — no living practitioners
	return ""
