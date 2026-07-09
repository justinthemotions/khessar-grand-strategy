class_name KhessarMapData
extends RefCounted

## The Khessar continent, hand-traced from Justin's illustrated map
## (Khessar_mapv2). This file IS the content: boundary polylines, the 60
## province cells between them, realm records, duchy groupings, and the
## adjacency blocklist for mountain walls and deep forests. world_map.gd
## assembles runtime structures from these tables and never invents
## geography of its own.
##
## NOTE — where the illustration and the written Record disagree, the
## illustration wins (per the map brief). Deviations taken here:
## - Irnholt sits on the WEST coast with the Salt Road running east to
##   Vael, as drawn (the Record calls Irnholt a northeastern hub).
## - The Ashfields lie in the SOUTHEAST (the Record places them east of
##   Pellar in the northeast). Durn sits inside them, still inhabited.
## - Carath the free city is on the SOUTHERN coast, as drawn, far from
##   the Carath Mountains that share its name.
## NOTE — added where the illustration is silent (flag for Justin's review):
## - The two Elven great houses (Veldarin / Thaladris, confirmed by the
##   Faction Map at Year Zero v1.0) occupy the wooded interior southwest
##   and south-center of the plains.
## - Saren-Vesh and its southern reach hold the far southwest coast.
## - Two sealed Dwarven holds (Grimdeep, Kedvault) sit in the central
##   Carath range west of Kharak-Dum.
## - Ashford is placed as the border province north of Pellar — the
##   Record calls it both "northern border checkpoint" and "waystation on
##   the Salt Road"; the checkpoint reading fits the drawn geography.

# ---------------------------------------------------------------- lines
# Boundary polylines, west to east, in normalized 0..1 map space (y down).
# Each is a y(x) contour; province rows live between consecutive lines.
const LINES := {
	"n_coast": [Vector2(0.06, 0.075), Vector2(0.25, 0.055), Vector2(0.45, 0.065), Vector2(0.62, 0.05), Vector2(0.78, 0.06), Vector2(0.91, 0.09)],
	"l1":      [Vector2(0.06, 0.16), Vector2(0.2, 0.145), Vector2(0.4, 0.155), Vector2(0.6, 0.14), Vector2(0.75, 0.15), Vector2(0.9, 0.16)],
	"l2":      [Vector2(0.06, 0.27), Vector2(0.18, 0.255), Vector2(0.3, 0.265), Vector2(0.42, 0.25), Vector2(0.54, 0.265), Vector2(0.66, 0.255), Vector2(0.78, 0.27), Vector2(0.91, 0.285)],
	"l3":      [Vector2(0.05, 0.365), Vector2(0.2, 0.355), Vector2(0.35, 0.365), Vector2(0.5, 0.355), Vector2(0.65, 0.365), Vector2(0.9, 0.36)],
	"l4":      [Vector2(0.04, 0.455), Vector2(0.2, 0.445), Vector2(0.4, 0.455), Vector2(0.6, 0.445), Vector2(0.75, 0.455), Vector2(0.9, 0.45)],
	"l5":      [Vector2(0.04, 0.545), Vector2(0.2, 0.535), Vector2(0.4, 0.545), Vector2(0.6, 0.535), Vector2(0.8, 0.545), Vector2(0.89, 0.54)],
	"l5b":     [Vector2(0.04, 0.635), Vector2(0.2, 0.625), Vector2(0.4, 0.635), Vector2(0.6, 0.625), Vector2(0.8, 0.635), Vector2(0.87, 0.63)],
	"l6":      [Vector2(0.04, 0.71), Vector2(0.2, 0.7), Vector2(0.4, 0.71), Vector2(0.6, 0.7), Vector2(0.74, 0.71), Vector2(0.8, 0.69), Vector2(0.87, 0.665)],
	"s_coast": [Vector2(0.04, 0.775), Vector2(0.12, 0.79), Vector2(0.22, 0.78), Vector2(0.32, 0.795), Vector2(0.44, 0.785), Vector2(0.55, 0.8), Vector2(0.64, 0.785), Vector2(0.74, 0.755)],
}

# ---------------------------------------------------------------- realms
# Map-level realm records for every power at Year Zero, per the Faction
# Map at Year Zero (v1.0) companion document. Only realms 0 and 1 are
# simulated live (SimWorld); the rest are setting data — including their
# named rulers — until later modules bring them online. Governments:
# feudal/tribal implemented; administrative/merchant_republic/clan are
# placeholder strings (planned).
const REALMS := [
	{"name": "Magistocracy of Vael", "government": "administrative", "capital": 31,
		"house": "House Vorontheim", "ruler": "Grand Magister Anselm Vorontheim"},
	{"name": "Karn-Vol Clan", "government": "tribal", "capital": 9,
		"house": "House Karn-Vol", "ruler": "Chief Vorak Karn-Vol"},
	{"name": "Pellar", "government": "feudal", "capital": 14,
		"house": "House Vellian", "ruler": "Queen Eithne the Merciful"},  # canonical (Iron Wren)
	{"name": "Carath", "government": "feudal", "capital": 56,
		"house": "House Carathwell", "ruler": "Duke Harrold Carathwell"},
	{"name": "Dunmore", "government": "feudal", "capital": 58,
		"house": "House Dunmoreth", "ruler": "Baron Thelren Dunmoreth"},
	{"name": "Halven", "government": "merchant_republic", "capital": 59,
		"house": "House Crannock-Vey", "ruler": "Ferren Crannock-Vey, First Voice"},
	# The illustration labels the south "Free City-States"; the smaller
	# municipalities (Irnholt, Sennel, Fordreach) are grouped under one
	# loose compact realm. NOTE: the Faction Map v1.0 does not count this
	# compact among its twelve realms — flag for Justin's review (dissolve
	# into neighbors, or keep as the Record's "twelve smaller municipalities").
	{"name": "Free City-States Compact", "government": "merchant_republic", "capital": 28,
		"house": "House Irnhart", "ruler": ""},  # loose coalition — no single ruler
	{"name": "Vor-Grim Clan", "government": "tribal", "capital": 6,
		"house": "House Vor-Grim", "ruler": "Chieftain Grimkar Vor-Grim"},  # second Drevak clan per Faction Map v1.0
	{"name": "Kharak-Dum", "government": "feudal", "capital": 10,
		"house": "House Ironvault", "ruler": "King Grimhold Ironvault"},
	{"name": "House Veldarin", "government": "clan", "capital": 38,
		"house": "House Veldarin", "ruler": "Matriarch Analinth Veldarin"},
	{"name": "House Thaladris", "government": "clan", "capital": 41,
		"house": "House Thaladris", "ruler": "Matriarch Ariorwe Thaladris"},
	{"name": "Saren-Vesh Trade Council", "government": "merchant_republic", "capital": 54,
		"house": "House Korren", "ruler": "First Councilor Vessa Korren"},
]

# ---------------------------------------------------------------- cells
# Province rows, north to south, each cell west to east. Cell ids are
# assigned in table order (band by band): band 0 = ids 0..4, band 1 =
# 5..11, band 2 = 12..19, band 3 = 20..27, band 4 = 28..35, band 5 =
# 36..44, band 6 = 45..53, band 7 = 54..59. A cell with name "" gets a
# generated name from its region's pool. owner -1 = uncontrolled.
const BANDS := [
	# --- band 0 (ids 0-4): orc lowlands north of the Carath crest ---
	{"top": "n_coast", "bot": "l1", "cells": [
		{"x0": 0.08, "x1": 0.24, "name": "", "region": "drevak_orc", "owner": 7, "tax": 1.3, "levy": 26, "terrain": "hills"},
		{"x0": 0.24, "x1": 0.42, "name": "", "region": "drevak_orc", "owner": 7, "tax": 1.4, "levy": 28, "terrain": "hills"},
		{"x0": 0.42, "x1": 0.60, "name": "", "region": "drevak_orc", "owner": 1, "tax": 2.2, "levy": 30, "terrain": "hills"},
		{"x0": 0.60, "x1": 0.76, "name": "", "region": "drevak_orc", "owner": 1, "tax": 2.4, "levy": 32, "terrain": "hills"},
		{"x0": 0.76, "x1": 0.90, "name": "", "region": "drevak_orc", "owner": 1, "tax": 2.2, "levy": 28, "terrain": "hills"},
	]},
	# --- band 1 (ids 5-11): the Carath range — clans, sealed holds, Kharak-Dum ---
	{"top": "l1", "bot": "l2", "cells": [
		{"x0": 0.06, "x1": 0.17, "name": "", "region": "drevak_orc", "owner": 7, "tax": 1.2, "levy": 24, "terrain": "mountain"},
		{"x0": 0.17, "x1": 0.28, "name": "Grim-Vor-Kaz", "region": "drevak_orc", "owner": 7, "tax": 1.6, "levy": 30, "terrain": "mountain"},
		# the sealed holds are LOCKED rather than dead — ruined=true for map
		# purposes per Faction Map v1.0, but architecturally distinct from Aurath
		{"x0": 0.28, "x1": 0.38, "name": "Grimdeep", "region": "dwarven", "owner": -1, "tax": 1.2, "levy": 12, "terrain": "mountain", "special": "sealed_hold", "ruined": true},
		{"x0": 0.38, "x1": 0.50, "name": "Kedvault", "region": "dwarven", "owner": -1, "tax": 1.2, "levy": 12, "terrain": "mountain", "special": "sealed_hold", "ruined": true},
		{"x0": 0.50, "x1": 0.60, "name": "Karn-Vol-Gar", "region": "drevak_orc", "owner": 1, "tax": 2.6, "levy": 35, "terrain": "mountain"},
		{"x0": 0.60, "x1": 0.72, "name": "Kharak-Dum", "region": "dwarven", "owner": 8, "tax": 3.0, "levy": 18, "terrain": "mountain"},
		{"x0": 0.72, "x1": 0.88, "name": "Bronhold", "region": "dwarven", "owner": 8, "tax": 2.4, "levy": 16, "terrain": "mountain"},
	]},
	# --- band 2 (ids 12-19): the northern march — Pellar, the passes, Vael's north ---
	{"top": "l2", "bot": "l3", "cells": [
		{"x0": 0.07, "x1": 0.18, "name": "", "region": "free_city", "owner": 2, "tax": 1.8, "levy": 18, "terrain": "hills"},
		{"x0": 0.18, "x1": 0.30, "name": "Ashford", "region": "free_city", "owner": 2, "tax": 1.6, "levy": 20, "terrain": "hills", "special": "ashford_checkpoint"},
		{"x0": 0.30, "x1": 0.42, "name": "Pellar", "region": "free_city", "owner": 2, "tax": 2.8, "levy": 22, "terrain": "hills", "special": "iron_library"},
		{"x0": 0.42, "x1": 0.51, "name": "", "region": "vael", "owner": 0, "tax": 2.4, "levy": 20},
		{"x0": 0.51, "x1": 0.63, "name": "Marn's Crossing", "region": "vael", "owner": 0, "tax": 2.0, "levy": 24, "terrain": "hills", "special": "marn_crossing"},
		{"x0": 0.63, "x1": 0.71, "name": "", "region": "vael", "owner": 0, "tax": 2.4, "levy": 18},
		{"x0": 0.71, "x1": 0.78, "name": "", "region": "vael", "owner": 0, "tax": 2.3, "levy": 18},
		{"x0": 0.78, "x1": 0.91, "name": "Aurdrevath", "region": "aurath", "owner": -1, "tax": 1.2, "levy": 12, "terrain": "ruined", "coastal": true, "ruined": true},
	]},
	# --- band 3 (ids 20-27): the upper plains ---
	{"top": "l3", "bot": "l4", "cells": [
		{"x0": 0.06, "x1": 0.16, "name": "", "region": "vael", "owner": 0, "tax": 2.5, "levy": 20},
		{"x0": 0.16, "x1": 0.26, "name": "Vellan-on-the-River", "region": "vael", "owner": 0, "tax": 2.7, "levy": 20, "terrain": "river_valley"},
		{"x0": 0.26, "x1": 0.36, "name": "", "region": "vael", "owner": 0, "tax": 2.5, "levy": 18},
		{"x0": 0.36, "x1": 0.46, "name": "Veilkeep", "region": "vael", "owner": 0, "tax": 2.6, "levy": 22, "terrain": "hills", "special": "veilkeep"},
		{"x0": 0.46, "x1": 0.56, "name": "Marling Fields", "region": "vael", "owner": 0, "tax": 2.8, "levy": 18},
		{"x0": 0.56, "x1": 0.66, "name": "", "region": "vael", "owner": 0, "tax": 2.4, "levy": 18},
		{"x0": 0.66, "x1": 0.76, "name": "Voss-Hold", "region": "vael", "owner": 0, "tax": 2.5, "levy": 20, "special": "voss_hold"},
		{"x0": 0.76, "x1": 0.90, "name": "Vekoraksen", "region": "aurath", "owner": -1, "tax": 1.2, "levy": 12, "terrain": "ruined", "coastal": true, "ruined": true},
	]},
	# --- band 4 (ids 28-35): the Salt Road latitude — Irnholt to the capital ---
	{"top": "l4", "bot": "l5", "cells": [
		{"x0": 0.05, "x1": 0.15, "name": "Irnholt", "region": "free_city", "owner": 6, "tax": 2.6, "levy": 18, "coastal": true},
		{"x0": 0.15, "x1": 0.25, "name": "", "region": "vael", "owner": 0, "tax": 2.5, "levy": 18},
		{"x0": 0.25, "x1": 0.34, "name": "Brem's Reach", "region": "vael", "owner": 0, "tax": 2.6, "levy": 18},
		{"x0": 0.34, "x1": 0.46, "name": "Vael", "region": "vael", "owner": 0, "tax": 3.2, "levy": 24},
		{"x0": 0.46, "x1": 0.56, "name": "Vesper's End", "region": "vael", "owner": 0, "tax": 2.4, "levy": 16},
		{"x0": 0.56, "x1": 0.65, "name": "", "region": "vael", "owner": 0, "tax": 2.5, "levy": 18},
		{"x0": 0.65, "x1": 0.74, "name": "Caer Velmond", "region": "vael", "owner": 0, "tax": 2.4, "levy": 18},
		{"x0": 0.74, "x1": 0.88, "name": "Drevathorak", "region": "aurath", "owner": -1, "tax": 1.2, "levy": 12, "terrain": "ruined", "coastal": true, "ruined": true},
	]},
	# --- band 5 (ids 36-44): the lower plains — forests west and east, the blight begins ---
	{"top": "l5", "bot": "l5b", "cells": [
		{"x0": 0.04, "x1": 0.13, "name": "Sennel", "region": "free_city", "owner": 6, "tax": 1.9, "levy": 16, "coastal": true},
		{"x0": 0.13, "x1": 0.22, "name": "Mirathen", "region": "southern_reach", "owner": 11, "tax": 1.8, "levy": 16, "special": "iliana_home"},
		{"x0": 0.22, "x1": 0.31, "name": "Elasilwe", "region": "elven_veldarin", "owner": 9, "tax": 1.8, "levy": 24, "terrain": "forest"},
		{"x0": 0.31, "x1": 0.40, "name": "", "region": "elven_veldarin", "owner": 9, "tax": 1.7, "levy": 22, "terrain": "forest"},
		{"x0": 0.40, "x1": 0.49, "name": "Halvet", "region": "vael", "owner": 0, "tax": 2.5, "levy": 18},
		{"x0": 0.49, "x1": 0.58, "name": "Thaladris", "region": "elven_thaladris", "owner": 10, "tax": 1.8, "levy": 24, "terrain": "forest"},
		{"x0": 0.58, "x1": 0.66, "name": "", "region": "elven_thaladris", "owner": 10, "tax": 1.7, "levy": 22, "terrain": "forest"},
		{"x0": 0.66, "x1": 0.77, "name": "Greyreach", "region": "ashfields", "owner": -1, "tax": 1.3, "levy": 12, "terrain": "ashfields", "silence": true},
		{"x0": 0.77, "x1": 0.89, "name": "Hollowburn", "region": "ashfields", "owner": -1, "tax": 1.3, "levy": 12, "terrain": "ashfields", "silence": true},
	]},
	# --- band 6 (ids 45-53): hinterlands above the coast; Durn under Caeris ---
	{"top": "l5b", "bot": "l6", "cells": [
		{"x0": 0.04, "x1": 0.13, "name": "", "region": "southern_reach", "owner": 11, "tax": 1.9, "levy": 16, "coastal": true},
		{"x0": 0.13, "x1": 0.21, "name": "", "region": "southern_reach", "owner": 11, "tax": 1.8, "levy": 14},
		{"x0": 0.21, "x1": 0.30, "name": "", "region": "elven_veldarin", "owner": 9, "tax": 1.7, "levy": 22, "terrain": "forest"},
		{"x0": 0.30, "x1": 0.39, "name": "", "region": "free_city", "owner": 3, "tax": 1.9, "levy": 16},
		{"x0": 0.39, "x1": 0.48, "name": "", "region": "free_city", "owner": 4, "tax": 1.9, "levy": 16},
		{"x0": 0.48, "x1": 0.57, "name": "", "region": "elven_thaladris", "owner": 10, "tax": 1.7, "levy": 22, "terrain": "forest"},
		{"x0": 0.57, "x1": 0.66, "name": "", "region": "free_city", "owner": 5, "tax": 2.0, "levy": 16},
		{"x0": 0.66, "x1": 0.76, "name": "Durn", "region": "ashfields", "owner": -1, "tax": 1.6, "levy": 14, "terrain": "ashfields", "silence": true, "special": "durn_caeris_seat"},
		{"x0": 0.76, "x1": 0.87, "name": "Ashwaste", "region": "ashfields", "owner": -1, "tax": 1.2, "levy": 12, "terrain": "ashfields", "silence": true, "coastal": true},
	]},
	# --- band 7 (ids 54-59): the southern coast — Saren-Vesh and the free cities ---
	{"top": "l6", "bot": "s_coast", "cells": [
		{"x0": 0.04, "x1": 0.15, "name": "Saren-Vesh", "region": "southern_reach", "owner": 11, "tax": 3.0, "levy": 18, "terrain": "coast", "coastal": true},
		{"x0": 0.15, "x1": 0.24, "name": "", "region": "southern_reach", "owner": 11, "tax": 2.0, "levy": 16, "terrain": "coast", "coastal": true},
		{"x0": 0.24, "x1": 0.34, "name": "Carath", "region": "free_city", "owner": 3, "tax": 2.7, "levy": 20, "terrain": "coast", "coastal": true},
		{"x0": 0.34, "x1": 0.44, "name": "Fordreach", "region": "free_city", "owner": 6, "tax": 2.0, "levy": 16, "terrain": "coast", "coastal": true},
		{"x0": 0.44, "x1": 0.56, "name": "Dunmore", "region": "free_city", "owner": 4, "tax": 2.7, "levy": 20, "terrain": "coast", "coastal": true},
		{"x0": 0.56, "x1": 0.74, "name": "Halven", "region": "free_city", "owner": 5, "tax": 2.9, "levy": 20, "terrain": "coast", "coastal": true, "special": "guildhall"},
	]},
]

# ---------------------------------------------------------------- walls
# Adjacencies severed by terrain the illustration draws as impassable.
# The Carath range blocks every north-south crossing except the two
# canonical passes (Grathkaz-Ashford in the west, Karn-Vol-Gar-Marn's
# Crossing in the east); the deep Elven forests admit outsiders only
# through each house's gate provinces. Pairs are province ids.
const BLOCKED_ADJACENCY := [
	# the mountain wall (band 1 vs band 2)
	[5, 12],    # western range vs Pellar hinterland
	[7, 13],    # Grimdeep vs Ashford
	[7, 14],    # Grimdeep vs Pellar
	[8, 14],    # Kedvault vs Pellar
	[8, 15],    # Kedvault vs Vael's north march
	[10, 16],   # Kharak-Dum vs Marn's Crossing (the pass belongs to Karn-Vol-Gar)
	[10, 17],   # Kharak-Dum vs Vael's north march
	[11, 18],   # Bronhold vs Vael's north march
	[11, 19],   # Bronhold vs the Aurath ruins
	# House Veldarin's deep forest (gates: Halvet in the east, Carath's hinterland in the south)
	[37, 38],   # Mirathen vs Elasilwe
	[29, 38],   # Vael west plains vs Elasilwe
	[30, 38],   # Brem's Reach vs Elasilwe
	[30, 39],   # Brem's Reach vs the inner forest
	[31, 39],   # Vael (capital) vs the inner forest
	[39, 48],   # inner forest vs Carath's hinterland
	[46, 47],   # southern reach vs the forest's south march
	[47, 55],   # forest south march vs the Saren-Vesh coast
	[47, 56],   # forest south march vs Carath
	# House Thaladris's deep forest (gates: Vesper's End in the north, Dunmore in the south)
	[40, 41],   # Halvet vs Thaladris
	[33, 41],   # Vael southeast vs Thaladris
	[33, 42],   # Vael southeast vs the inner forest
	[42, 51],   # inner forest vs Halven's hinterland
	[49, 50],   # Dunmore's hinterland vs the forest's south march
	[50, 51],   # forest south march vs Halven's hinterland
]

# ---------------------------------------------------------------- duchies
# De jure duchy groupings (2-4 counties each; ~22 total). Named at build
# time for the richest county. realm -1 = ghost duchy (Sealed Holds,
# Ashfields, Aurath) — the record exists for endgame reclamation content.
const DUCHIES := [
	{"realm": 0, "counties": [15, 16, 17, 18]},   # the North March (Marn's Crossing)
	{"realm": 0, "counties": [20, 21, 22, 29]},   # the West Reach (Vellan-on-the-River)
	{"realm": 0, "counties": [23, 30, 31, 40]},   # the Crownlands (Vael, Veilkeep, Halvet)
	{"realm": 0, "counties": [24, 25, 26]},       # the East March (Voss-Hold)
	{"realm": 0, "counties": [32, 33, 34]},       # the Southeast (Vesper's End, Caer Velmond)
	{"realm": 2, "counties": [12, 13, 14]},       # Pellar and its march
	{"realm": 6, "counties": [28, 36]},           # Irnholt and Sennel
	{"realm": 3, "counties": [48, 56]},           # Carath
	{"realm": 4, "counties": [49, 57, 58]},       # Dunmore (Fordreach is de jure Dunmore land, held by the Compact)
	{"realm": 5, "counties": [51, 59]},           # Halven
	{"realm": 1, "counties": [2, 9]},             # Karn-Vol-Gar and the crest
	{"realm": 1, "counties": [3, 4]},             # the eastern clanholds
	{"realm": 7, "counties": [0, 5]},             # Vor-Grim west
	{"realm": 7, "counties": [1, 6]},             # Grim-Vor-Kaz
	{"realm": 8, "counties": [10, 11]},           # Kharak-Dum and Bronhold
	{"realm": -1, "counties": [7, 8]},            # the Sealed Holds (ghost)
	{"realm": 9, "counties": [38, 39, 47]},       # House Veldarin's forest
	{"realm": 10, "counties": [41, 42, 50]},      # House Thaladris's forest
	{"realm": 11, "counties": [54, 45]},          # Saren-Vesh and its coast
	{"realm": 11, "counties": [37, 46, 55]},      # Mirathen and the inland reach
	{"realm": -1, "counties": [43, 44, 52, 53]},  # the Ashfields (ghost — Caeris the Unfinished)
	{"realm": -1, "counties": [19, 27, 35]},      # the Aurath Sovereignty (ghost)
]
