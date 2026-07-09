class_name ProvinceNamePools
extends RefCounted

## Cultural-region syllable pools for county names on the Khessar map.
## Canonical settlement names are hand-placed in khessar_map_data.gd and
## pre-seeded into the used-names set before any roll, so a pool can never
## shadow a canonical place (e.g. the free-city pool can build "Ashford",
## but the real Ashford is already reserved).

const POOLS := {
	# classical, slightly Latin-inflected — the Magistocracy's registers
	"vael": {
		"first": ["Vael", "Ren", "Sil", "Mor", "Vor", "Kal", "Ath", "Ser", "Tor", "Cael"],
		"last": ["ren", "morath", "vorus", "athir", "enus", "irum", "alia", "oris", "entis", "arum"],
	},
	# pragmatic, real-world-adjacent — the free cities name things after what they are
	"free_city": {
		"first": ["Car", "Dun", "Pell", "Hart", "Ford", "Mere", "Wex", "Bram", "Ash", "Stan"],
		"last": ["mere", "burgh", "hart", "ford", "reach", "wick", "dale", "holm", "gate", "field"],
	},
	# harsh and guttural — the Drevak tongue of the northern clans
	"drevak_orc": {
		"first": ["Kar", "Grath", "Stein", "Vor", "Drev", "Brakh", "Gor", "Maz"],
		"last": ["hun", "gar", "kaz", "brakh", "vol", "druk", "grod", "zan"],
	},
	# compound, hard consonants, mountain-referent — Kharak-Dum's register
	"dwarven": {
		"first": ["Grim", "Ked", "Bron", "Kar", "Dur", "Thur", "Bal", "Khaz"],
		"last": ["deep", "hold", "vault", "stone", "dum", "forge", "delve", "gate"],
	},
	# soft, flowing, vowel-heavy
	"elven_veldarin": {
		"first": ["Vel", "Ela", "Sil", "Ana", "Lia", "Thae"],
		"last": ["athion", "silwe", "linth", "noril", "wenna", "rion"],
	},
	# a sister tongue with a distinct root
	"elven_thaladris": {
		"first": ["Thal", "Ari", "Mor", "Ela", "Syl", "Vae"],
		"last": ["adris", "orwe", "iven", "uen", "ithra", "enor"],
	},
	# warmer phonemes around the established "vesh" root
	"southern_reach": {
		"first": ["Sar", "Mir", "En", "Vesh", "Cal", "Or"],
		"last": ["envesh", "athen", "orath", "essa", "ira", "enne"],
	},
	# withered, negative-space names for the blighted land
	"ashfields": {
		"first": ["Ash", "Grey", "Hollow", "Dust", "Pale", "Cinder"],
		"last": ["waste", "reach", "burn", "fall", "mark", "fen"],
	},
	# the pre-Silence Sovereignty's tongue, foreign to modern Khessari
	"aurath": {
		"first": ["Aur", "Drev", "Vek", "Sor", "Zha"],
		"last": ["drevath", "oraksen", "ath", "orak", "sen"],
	},
}


static func make_name(rng: RandomNumberGenerator, region: String, used: Dictionary) -> String:
	var pool: Dictionary = POOLS.get(region, POOLS["vael"])
	var first: Array = pool["first"]
	var last: Array = pool["last"]
	for attempt in 60:
		var n: String = str(first[rng.randi_range(0, first.size() - 1)]) + str(last[rng.randi_range(0, last.size() - 1)])
		if not used.has(n):
			used[n] = true
			return n
	var fallback := "%s %d" % [str(first[0]), used.size() + 1]
	used[fallback] = true
	return fallback
