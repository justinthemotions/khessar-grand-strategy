class_name CanonData
extends RefCounted

## Canon Briefs Pass One & Two (Opus, 2026-07-14/15): the data layer.
## Pass One — continental scale, the famine curve's parameters, and the
## Iron Wren's world. Pass Two — entity pressure by ground, the
## Underneath's organizations and cults, and the ~46 noble houses and
## institutions. Everything here is setting data; world.gd reads it and
## never invents its own. Figures marked INVENTED are Fable's and are
## flagged for Justin in the implementation briefing.

# ---------------------------------------------------------------- scale
# Pass One §1: Khessar is Pangea-scale and holds 100-120 million souls
# at Year Zero. 110M is the canon working figure. Density ~0.74/km2 —
# eleven percent of Earth's pre-industrial ceiling. Khessar is EMPTY.
const CONTINENTAL_POP := 110_000_000

# Settlement (city-proper) populations from the Settlements & Geography
# doc, keyed by the PROVINCE NAME that holds the settlement on the map.
# Provincial populations are larger — the hinterland multiplier below.
# Mapping deviations (flag for Justin): the doc's "Iron Deep" reads as
# Kharak-Dum's under-mountain city; "Grimhold surface hold" lands on
# Bronhold (the Ironvault realm's surface province — the map has no
# Grimhold province); "Veldarin" and "Thaladris" land on each great
# house's seat province (Elasilwe / Thaladris); "Kag'thuk" lands on
# Karn-Vol-Gar (the clan seat — the doc's name is not on the map).
const SETTLEMENT_POP := {
	"Vael": 800_000,
	"Halven": 400_000,
	"Saren-Vesh": 350_000,
	"Kharak-Dum": 300_000,    # the Iron Deep
	"Pellar": 200_000,
	"Carath": 190_000,        # Carathwell, the free city
	"Dunmore": 140_000,       # Dunmoreth
	"Bronhold": 80_000,       # the Grimhold surface hold
	"Elasilwe": 80_000,       # House Veldarin's seat
	"Thaladris": 60_000,      # House Thaladris's seat
	"Karn-Vol-Gar": 40_000,   # Kag'thuk, the clan seat
}
# INVENTED (flagged): how much rural hinterland a named settlement's
# province carries per city soul, and the per-region base weights for
# unnamed provinces. The distribution is design; the 110M total is canon.
const HINTERLAND_MULT := 3.0
const REGION_POP_BASE := {
	"vael": 1_700_000, "free_city": 1_500_000, "southern_reach": 1_300_000,
	"elven_veldarin": 850_000, "elven_thaladris": 850_000,
	"drevak_orc": 800_000, "dwarven": 500_000,
	"ashfields": 300_000,     # still inhabited — Durn holds on under the Silence
	"aurath": 120_000,        # the Sovereignty's ruins, two centuries empty
}
const TERRAIN_POP_MULT := {
	"river_valley": 1.35, "coast": 1.1, "plains": 1.0, "forest": 0.9,
	"hills": 0.85, "wetland": 0.7, "mountain": 0.55, "ashfields": 1.0, "ruined": 1.0,
}

# ---------------------------------------------------------------- famine
# Pass One §2.2: the corrected curve (Architect's Number v2.0). A single
# logistic pinned at Year 1 = 0.36%/yr and Year 6 = 1.50%/yr, plateau
# 2.00%/yr (Justin's ruling, 2026-07-14). Baseline hunger mortality was
# 0.1%/yr — what the gods' maintenance held it to.
const FAMINE_PLATEAU := 0.0200
const FAMINE_SHAPE_A := 7.687
const FAMINE_SHAPE_R := 0.5230
const FORECAST_YEARS := 40            # the Architect's forecast window, not the seal's expiry
# INVENTED (flagged): the per-province famine modulation. The continental
# curve is canon; the distribution below it is design, renormalized every
# month so the weighted sum still walks the canon curve.
const FAMINE_TERRAIN := {
	"ashfields": 1.6, "ruined": 1.4, "wetland": 1.2, "mountain": 1.15,
	"hills": 1.05, "forest": 1.0, "coast": 0.95, "plains": 0.9, "river_valley": 0.85,
}
const VILLAGE_SOULS := 2_000          # one emptied village per this many famine dead (INVENTED)

# ---------------------------------------------------------------- entity ground
# Pass Two §1.3: the inversion. Density rises fastest where divine
# supervision was heaviest — piety was infrastructure, and the lid is
# failing over exactly the things it was holding down. Ward-stone ground
# is BOTH better for faith (the stones still hold a little sky up) AND
# worst for entities (the things behind them were counting). Deliberate,
# per the doc's Rule Two.
const ENTITY_PRESSURE_BY_GROUND := {
	"wardstone": 1.0,    # forty years of maintained blessing, dark in one night
	"shrine_net": 0.8,   # dense pre-Silence devotion = dense post-Silence vacancy
	"library": 0.5,      # the Iron Library still holds more of the sky up than most
	"base": 0.3,
	"unwarded": 0.1,     # nothing was maintaining it, so nothing withdrew
}
# Which ground each cultural region reads as. The Ashfields are EXCLUDED
# entirely (Caeris's active work — an author, not deferred maintenance).
# Aurath's maintenance ended with the Sovereignty two centuries ago —
# whatever was going to find its level there found it long since (flag).
const REGION_GROUND := {
	"dwarven": "wardstone",           # the deep passages — the doc's proof case
	"vael": "shrine_net", "free_city": "shrine_net",  # the Aelindran heartland
	"southern_reach": "base", "aurath": "base",
	"elven_veldarin": "unwarded", "elven_thaladris": "unwarded",  # the Elder Ways kept their own
	"drevak_orc": "unwarded",         # the Drevak Rites never asked the pantheon for wards
}

# ---------------------------------------------------------------- anchor-mages
# Pass Two §3.4: the four lineages, on an atrocity spectrum. An
# anchor-mage pays a working's cost with OTHER PEOPLE'S LIVES. Most
# mages are not anchor-mages — the Iron Wren's line is at the anchoring.
# Ages are YEAR ZERO ages (the briefs give campaign-start figures, six
# years on). `records` is what their papers are worth to her un-making.
# Sark's age and the six unnamed pre-campaign targets are INVENTED
# (flagged) — the legend counts seven tokens by Year Six and names only
# Sark; somebody had to be the other six.
const ANCHOR_MAGES := {
	"sark": {"name": "Sark of House Sarkenvault", "house": "sarkenvault", "age": 51,
		"pid": 29, "working": "green", "records": 8.0,
		"note": "the green-wizard of Vetral — her first"},
	"um_fen": {"name": "Fenwick Sarkenvault-Vane", "house": "sarkenvault", "age": 44,
		"pid": 30, "working": "green", "records": 5.0, "note": "a cousin in the craft"},
	"um_ostler": {"name": "the Ostler of Sennel", "house": "ossrel", "age": 58,
		"pid": 36, "working": "debt", "records": 6.0, "note": "a district bled quiet for coin"},
	"um_marle": {"name": "Marle Vessrel", "house": "vessrel", "age": 39,
		"pid": 57, "working": "blood", "records": 4.0, "note": "a compact drawn on strangers"},
	"um_hessen": {"name": "Hessen of the Ledger-Row", "house": "ossrel", "age": 62,
		"pid": 59, "working": "debt", "records": 6.0, "note": "Halven's patient exhaustion"},
	"um_corve": {"name": "Corve Vanneth-Adjunct", "house": "vanneth", "age": 47,
		"pid": 32, "working": "memory", "records": 5.0, "note": "husks in two river towns"},
	"um_dray": {"name": "Dray of the Crossing", "house": "vessrel", "age": 35,
		"pid": 16, "working": "blood", "records": 4.0, "note": "tolls taken in years, not coin"},
	# --- the named roster at campaign start (alive at Year Six; her list) ---
	"velren": {"name": "Master Velren Sarkenvault", "house": "sarkenvault", "age": 56,
		"pid": 56, "working": "green", "records": 15.0,
		"note": "the craft-knowledge itself — theatrical, leaves a grove"},
	"ferrin": {"name": "Ferrin Sarkenvault", "house": "sarkenvault", "age": 28,
		"pid": 56, "working": "green", "records": 8.0, "note": "apprentice, first chair"},
	"sella": {"name": "Sella Vane-Sarkenvault", "house": "sarkenvault", "age": 23,
		"pid": 48, "working": "green", "records": 8.0, "note": "apprentice, second chair"},
	"selva": {"name": "Matriarch Selva Ossrel", "house": "ossrel", "age": 52,
		"pid": 59, "working": "debt", "records": 20.0,
		"note": "keeps the Ossrel ledger — the most valuable object on the continent, to her"},
	"kell": {"name": "Brother Kell Ossrel", "house": "ossrel", "age": 48,
		"pid": 58, "working": "debt", "records": 6.0, "note": "runs the Bone Court liaison"},
	"mira_ossrel": {"name": "Mira Ossrel", "house": "ossrel", "age": 20,
		"pid": 54, "working": "debt", "records": 10.0,
		"note": "the lineage's first possible defector"},
	"arren": {"name": "Master Arren Vanneth", "house": "vanneth", "age": 43,
		"pid": 31, "working": "memory", "records": 18.0,
		"note": "retained by Drome — the Vanneth records map every house's concealment"},
	"vessrel_prime": {"name": "Weyland Vessrel", "house": "vessrel", "age": 54,
		"pid": 57, "working": "blood", "records": 8.0,
		"note": "the blood-compact line of the Free Cities — the Patron's old arithmetic"},
}

# ---------------------------------------------------------------- the underneath
# Pass Two §2.2: three continental organizations, six regional. The Ash
# Vein is quietly tolerated by Section Three as a pressure valve. The
# Bone Court is the one unambiguously evil faction. NAMING NOTE (flag):
# the brief's "Mediterranean Circle" is a real-world word Khessar does
# not have — rendered here as the Inner Sea Circle, for Opus to re-rule.
const CRIMINAL_ORGS := {
	"ash_vein": {"name": "The Ash Vein", "scope": "continental", "leader": "Master Vessa Hollow-Boot",
		"strength": 34.0, "tolerated": true,
		"note": "Salt Road banditry, ~80 years old, veteran-descended cells — Section Three's pressure valve"},
	"hidden_grain": {"name": "The Hidden Grain", "scope": "continental", "leader": "the Weaver",
		"strength": 30.0, "tolerated": false,
		"note": "continental smuggling, hierarchical, professional — used discreetly by respectable houses"},
	"bone_court": {"name": "The Bone Court", "scope": "continental", "leader": "unnamed — the Court keeps no one name",
		"strength": 22.0, "tolerated": false,
		"note": "slavers. Preys on Ashfields refugees, war veterans, Half-Orcs. The one unambiguous evil."},
	"vael_shadows": {"name": "The Vael Shadows", "scope": "vael", "leader": "", "strength": 18.0,
		"tolerated": false, "note": "the capital's own under-floor"},
	"salt_kings": {"name": "The Salt Kings", "scope": "free_city", "leader": "", "strength": 16.0,
		"tolerated": false, "note": "the road's western tolls, unofficially"},
	"iron_circle": {"name": "The Iron Circle", "scope": "free_city", "leader": "", "strength": 14.0,
		"tolerated": false, "note": "Free City syndicate"},
	"twelve_bells": {"name": "The Twelve Bells", "scope": "free_city", "leader": "", "strength": 14.0,
		"tolerated": false, "note": "Free City syndicate"},
	"northern_raiders": {"name": "The Northern Raiders", "scope": "drevak_orc", "leader": "", "strength": 15.0,
		"tolerated": false, "note": "demobbed clan blades who never went home"},
	"inner_sea_circle": {"name": "The Inner Sea Circle", "scope": "southern_reach", "leader": "", "strength": 13.0,
		"tolerated": false, "note": "southern smuggling ring (brief said 'Mediterranean' — renamed, flagged)"},
	"ashfield_flies": {"name": "The Ashfield Flies", "scope": "ashfields", "leader": "", "strength": 12.0,
		"tolerated": false, "note": "predatory — feed the desperate to the Bone Court"},
}

# Pass Two §2.3: ten cults — one per silent deity plus the Pale Accord.
# Not evil worshippers: people who decided that if prayer will not work,
# LEVERAGE might. Every cult is an attempt to FORCE a silent god back.
# Growth couples to the orthodoxy's coherence collapse; the Empty Bowl
# couples directly to the famine curve (Ossa is the harvest deity).
const CULTS := {
	"open_door": {"name": "The Open Door", "deity": "Vethara", "leader": "Sister Verella",
		"method": "forcing thresholds"},
	"swords_return": {"name": "The Sword's Return", "deity": "Aldeth", "leader": "Commander Halven Iron-Faith",
		"method": "a war worthy of a war-god's attention"},
	"burning_heart": {"name": "The Burning Heart", "deity": "Aelindra", "leader": "Mother Selena Heart-Flame",
		"method": "devotion turned to compulsion"},
	"fifth_road": {"name": "The Fifth Road", "deity": "Caras", "leader": "Master Vellin Four-Corners",
		"method": "a road no map carries"},
	"unpublished_record": {"name": "The Unpublished Record", "deity": "Moran", "leader": "Archive Master Ferren Truth-Speaks",
		"method": "truths withheld until the god must answer them"},
	"empty_bowl": {"name": "The Empty Bowl", "deity": "Ossa", "leader": "Sister Mira Hunger-Ground",
		"method": "the harvest god starved back to the table"},
	"ledger_rising": {"name": "The Ledger Rising", "deity": "Vernath", "leader": "Master Auditor Grim Halven Debt-Speaker",
		"method": "a debt demanded of heaven"},
	"deep_voice": {"name": "The Deep Voice", "deity": "Sellen", "leader": "Captain Selva Deep-Whisper",
		"method": "the sea made to speak"},
	"perfect_hammer": {"name": "The Perfect Hammer", "deity": "Davan", "leader": "Master Artisan Grim Iron-Heart",
		"method": "work so perfect the maker-god must look"},
	"older_terms": {"name": "The Older Terms", "deity": "the Pale Accord", "leader": "",
		"method": "terms that predate the pantheon's own"},
}

# ---------------------------------------------------------------- houses
# Pass Two §3: the noble house substrate — 46 houses and institutions
# across Opus's six Drive passes. STRUCTURE AND HOOKS, per the brief;
# full heraldry/mottos/rosters stay in Drive until a data-import pass.
# Standing rule (Justin's): power structures follow LORE, not genre
# convention — the Magistocracy is a rotating mage oligarchy, the Free
# Cities are merchant councils, Orc clans are bloodline structures. No
# crowns where canon has none. `secret` entries are planted (buried)
# into the intrigue web at setup, outside the tavern-informant pool.
# The four remaining Pass-Two Aelindran houses are pending Drive import.
const HOUSES := {
	# --- Pass One: the twelve, with their buried hooks ---
	"halvenard_veil": {"name": "House Halvenard-Veil", "pass": 1, "kind": "noble", "realm": 0,
		"members": ["Garran (head, the Year Zero crown-keeper)", "Sera (heir)", "Rorend (dead — the vote)"],
		"secret": "rorend_patron_vote", "note": "Rorend's secret Patron vote is the house's buried secret"},
	"aurath_voss": {"name": "House Aurath-Voss", "pass": 1, "kind": "noble", "realm": 0,
		"members": ["Iorek (head)"], "secret": "iorek_confession",
		"note": "Iorek's buried confession — two hundred years of feud, and a reason for it"},
	"crannock_vey": {"name": "House Crannock-Vey", "pass": 1, "kind": "merchant_council", "realm": 5,
		"members": ["Ferren (First Voice)", "Selia (counselor)", "Mira (daughter — Forsaken)"],
		"secret": "crannock_mira_forsaken", "note": "the First Voice's daughter runs with the Forsaken Underground"},
	"straven": {"name": "House Straven", "pass": 1, "kind": "noble", "realm": 5,
		"members": ["the Matriarch", "Otter (Master Merchant of the Salt Road)"],
		"secret": "", "refuses_compact": true,
		"note": "Tiefling matriarchate — knows what it carries and REFUSES to draw on it; the blood-compact is not 'the Tiefling lineage'"},
	"karn_vol": {"name": "House Karn-Vol", "pass": 1, "kind": "clan", "realm": 1,
		"members": ["Vorak (the Year Zero clan chief)"], "secret": "",
		"note": "bloodline structure, not a crown"},
	"drome": {"name": "House Drome", "pass": 1, "kind": "noble", "realm": 0,
		"members": ["Vannin (head — the altered memories)"], "secret": "vannin_memories",
		"note": "Vannin's memories were altered by a Vanneth working — he retained the house that unmade him"},
	"therin_voss": {"name": "House Therin-Voss", "pass": 1, "kind": "noble", "realm": 0,
		"members": [], "secret": "", "note": "the third Vael house — Drive roster pending"},
	"pale_court_house": {"name": "The Pale Court", "pass": 1, "kind": "institution", "realm": -1,
		"members": [], "secret": "",
		"note": "two hundred years of prepared testimony — Volume II's accumulation tier as an institution"},
	"ironvault": {"name": "House Ironvault", "pass": 1, "kind": "noble", "realm": 8,
		"members": ["King Grimhold (148)"], "secret": "",
		"note": "the under-mountain crown — one of the few real crowns on the map"},
	"veldarin": {"name": "House Veldarin", "pass": 1, "kind": "clan", "realm": 9,
		"members": ["Matriarch Analinth"], "secret": "", "note": "Elven Great House"},
	"thaladris": {"name": "House Thaladris", "pass": 1, "kind": "clan", "realm": 10,
		"members": ["Matriarch Ariorwe"], "secret": "", "note": "Elven Great House"},
	"vaelmark": {"name": "House Vaelmark", "pass": 1, "kind": "noble", "realm": 0,
		"members": ["Sir Aldric Vaelmark (Oath of the Vigil)"], "secret": "",
		"note": "the paladin's family"},
	# --- class-specialization houses (every SRD class represented) ---
	"merellin": {"name": "House Merellin", "pass": 1, "kind": "noble", "realm": 0,
		"members": [], "secret": "", "class_house": "wizard", "note": ""},
	"velmarin_house": {"name": "House Velmarin", "pass": 1, "kind": "noble", "realm": 0,
		"members": ["Talan (heir)"], "secret": "talan_faerith_romance", "class_house": "sorcerer",
		"note": "feuding with Thornback; heir Talan and Thornback's Faerith are in secret romance"},
	"thornback": {"name": "House Thornback", "pass": 1, "kind": "noble", "realm": 0,
		"members": ["Faerith (heir)"], "secret": "", "class_house": "sorcerer",
		"note": "the other half of the sorcerer feud — and of the romance"},
	"ordric": {"name": "House Ordric", "pass": 1, "kind": "noble", "realm": 2,
		"members": [], "secret": "", "class_house": "paladin", "note": ""},
	"helethin": {"name": "House Helethin", "pass": 1, "kind": "clan", "realm": 9,
		"members": [], "secret": "", "class_house": "druid", "note": ""},
	"vessel": {"name": "House Vessel", "pass": 1, "kind": "noble", "realm": 6,
		"members": [], "secret": "", "class_house": "warlock", "note": ""},
	"silvertongue": {"name": "House Silvertongue", "pass": 1, "kind": "noble", "realm": 11,
		"members": [], "secret": "", "class_house": "bard", "note": ""},
	"stormward": {"name": "House Stormward", "pass": 1, "kind": "noble", "realm": 2,
		"members": [], "secret": "", "class_house": "fighter", "note": ""},
	"arrowheart": {"name": "House Arrowheart", "pass": 1, "kind": "clan", "realm": 10,
		"members": [], "secret": "", "class_house": "ranger", "note": ""},
	"vellis": {"name": "House Vellis", "pass": 1, "kind": "noble", "realm": 5,
		"members": [], "secret": "", "class_house": "rogue", "note": ""},
	# --- Pass Two: Aelindran houses (Starfall named; four pending Drive import) ---
	"starfall": {"name": "House Starfall", "pass": 2, "kind": "noble", "realm": 0,
		"members": [], "secret": "", "note": "Aelindran house — the rest of Pass Two awaits import"},
	# --- Pass Three: Halfling / Gnome ---
	"meadowlea": {"name": "House Meadowlea", "pass": 3, "kind": "noble", "realm": 5,
		"members": [], "secret": "", "note": "Halfling"},
	"fenwyck": {"name": "House Fenwyck", "pass": 3, "kind": "noble", "realm": 6,
		"members": [], "secret": "", "note": "Gnome"},
	"threl": {"name": "House Threl", "pass": 3, "kind": "merchant_council", "realm": 6,
		"members": ["Uncle Herrowyn (workshop master — the Perfect Hammer's target)"], "secret": "",
		"note": "Gnome workshops — currently being torched by the Perfect Hammer"},
	# --- Pass Four: merchant houses ---
	"halven_straven": {"name": "The Halven-Straven Company", "pass": 4, "kind": "merchant_council", "realm": 5,
		"members": [], "secret": "", "note": ""},
	"corran": {"name": "House Corran of Saren-Vesh", "pass": 4, "kind": "merchant_council", "realm": 11,
		"members": [], "secret": "", "note": ""},
	"carathwell": {"name": "House Carathwell", "pass": 4, "kind": "merchant_council", "realm": 3,
		"members": ["Duke Harrold Carathwell", "Ser Garran Carathwell (champion)"], "secret": "", "note": ""},
	"ironbrand": {"name": "House Ironbrand of Grimhold", "pass": 4, "kind": "merchant_council", "realm": 8,
		"members": [], "secret": "ironbrand_concealment",
		"note": "Dwarven surface merchants CONCEALING the ward-stone decline by increasing supply — lying about the exact mechanism that drives entity density"},
	# --- Pass Five: regional houses ---
	"vor_grim": {"name": "House Vor-Grim", "pass": 5, "kind": "clan", "realm": 7,
		"members": ["Chieftain Grimkar"], "secret": "", "note": ""},
	"grath_kaal": {"name": "House Grath-Kaal", "pass": 5, "kind": "clan", "realm": 1,
		"members": [], "secret": "", "note": ""},
	"silverleaf": {"name": "House Silverleaf", "pass": 5, "kind": "clan", "realm": 9,
		"members": [], "secret": "", "note": ""},
	"duskwind": {"name": "House Duskwind", "pass": 5, "kind": "clan", "realm": 10,
		"members": [], "secret": "", "note": ""},
	"deepstone": {"name": "House Deepstone", "pass": 5, "kind": "noble", "realm": 8,
		"members": [], "secret": "",
		"note": "their research underlies the Ironbrand concealment — the science of the lie"},
	"windmere": {"name": "House Windmere", "pass": 5, "kind": "noble", "realm": 2,
		"members": [], "secret": "", "note": ""},
	# --- Pass Six: lost / Sovereignty-era ---
	"voress": {"name": "House Voress", "pass": 6, "kind": "lost", "realm": -1,
		"members": [], "secret": "", "note": "Sovereignty-era"},
	"court_of_ashes": {"name": "The Court of Ashes", "pass": 6, "kind": "lost", "realm": -1,
		"members": ["~340 dispossessed, ash-leaf obsidian tokens"], "secret": "",
		"note": "the houses-in-exile system's canonical instance"},
	"ellensong": {"name": "House Ellensong", "pass": 6, "kind": "lost", "realm": -1,
		"members": [], "secret": "", "note": "Sovereignty-era"},
	"ferrenmark": {"name": "House Ferrenmark", "pass": 6, "kind": "lost", "realm": -1,
		"members": [], "secret": "", "note": "Sovereignty-era"},
	"grimtorn": {"name": "House Grimtorn", "pass": 6, "kind": "lost", "realm": -1,
		"members": [], "secret": "", "note": "Sovereignty-era"},
	"silent_chorus": {"name": "The Silent Chorus", "pass": 6, "kind": "lost", "realm": -1,
		"members": [], "secret": "", "note": "Sovereignty-era"},
	# --- the anchor-mage lineages (Pass Two §3.4) ---
	"sarkenvault": {"name": "House Sarkenvault", "pass": 2, "kind": "anchor_lineage", "realm": 6,
		"members": ["Master Velren", "Ferrin", "Sella Vane-Sarkenvault"], "secret": "",
		"note": "green-workings — theatrical, leaves a grove. Personal to the Wren."},
	"ossrel": {"name": "House Ossrel", "pass": 2, "kind": "anchor_lineage", "realm": 5,
		"members": ["Matriarch Selva (the ledger)", "Brother Kell (Bone Court liaison)", "Mira (the possible defector)"],
		"secret": "", "note": "debt-workings — INVISIBLE: diffuse exhaustion, illness, early death"},
	"vanneth": {"name": "House Vanneth", "pass": 2, "kind": "anchor_lineage", "realm": 0,
		"members": ["Master Arren"], "secret": "",
		"note": "memory-workings; living husks. Retained by Drome. Their records map every house's concealment."},
	"vessrel": {"name": "The Vessrel Lineages", "pass": 2, "kind": "anchor_lineage", "realm": 6,
		"members": ["Weyland Vessrel", "Marle Vessrel (dead — the Wren's fourth token)"],
		"secret": "", "note": "the blood-compact lines of the Free Cities — House Straven is the counter-example"},
}
