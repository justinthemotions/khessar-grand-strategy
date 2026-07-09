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
	"vael_aristocratic": {"parents": ["vael", "aelindran"], "years": 30},
	"vael_ironvault": {"parents": ["vael", "kharak_dum"], "years": 40},
	"brushgate_ironvault": {"parents": ["brushgate", "kharak_dum"], "years": 20},
	"drevak_compact": {"parents": ["drevak", "karn_vol"], "years": 10},  # effectively already blended
	"border_compact_aristocratic": {"parents": ["karn_vol", "aelindran"], "years": 60},  # once in canonical history
	"commercial_compact": {"parents": ["southern_reach", "halveni"], "years": 20},
	"high_court_elven": {"parents": ["aelindran", "veldarin"], "years": 30},
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
	return CULTURE_SATISFIES.get(province_culture, []).has(wanted)


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
