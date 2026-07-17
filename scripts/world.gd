class_name SimWorld
extends RefCounted

## The dynasty simulation. Pure data and rules — no Nodes, no UI.
## It runs headless (see tests/headless_test.gd), which is what keeps
## it testable and portable. The UI in main.gd only reads this and
## calls the action methods.

signal event_logged(text: String)
signal event_raised  # a choice event awaits the player — the UI shows a popup

const TICK_ZERO_YEAR: int = 0   # Year Zero of the Silence — the Night of the Third Hour
const ADULT_AGE: int = 16

# ---------------------------------------------------------------- traits
# The trait database lives in TraitDB as TraitData resources (Module 1,
# reworked): each trait carries Core Six modifiers, AI behavioral weights
# (aggression / scheming / greed / patience / orthodoxy), and named
# systemic hooks that subsystems query via trait_mult() / trait_add().
# Stat keys: dip mar stw int lrn prw (see STAT_PROPS).
const STAT_PROPS := {"dip": "diplomacy", "mar": "martial", "stw": "stewardship",
	"int": "intrigue", "lrn": "learning", "prw": "prowess"}
const PERSONALITY_CAP := 3
const COPING_TRAITS: Array[String] = ["Drunkard", "Reclusive", "Irritable"]
const COPING_FLAVOR := {
	"Drunkard": "Drown it in wine",
	"Reclusive": "Withdraw from the world",
	"Irritable": "Let the anger fester",
}

# The council: four seats, each keyed to a Core Six stat.
const COUNCIL_SEATS: Array[String] = ["Marshal", "Steward", "Lawspeaker", "Spymaster"]
const SEAT_STAT := {"Marshal": "martial", "Steward": "stewardship", "Lawspeaker": "learning", "Spymaster": "intrigue"}

# Laws: taxation trades income against levy capacity; succession law
# changes who actually inherits the crown.
const TAX_LAWS := {
	"light":    {"income": 0.8,  "levy": 1.15},
	"moderate": {"income": 1.0,  "levy": 1.0},
	"heavy":    {"income": 1.25, "levy": 0.85},
}

# Dynasty Legacies (Module 2): permanent bloodline-wide perks bought with
# Renown. Effects are wired where they act — income, levies, births, opinion.
const LEGACIES := {
	"Chronicled Deeds": {"cost": 150.0, "blurb": "Court chroniclers sing the house's fame: +25% Renown gain"},
	"Golden Ledgers":   {"cost": 250.0, "blurb": "+10% realm income while the dynasty holds the crown"},
	"Blood of the Wolf": {"cost": 350.0, "blurb": "Children of the blood are born to war: +1 Martial, +1 Prowess at birth; +8% levy capacity while ruling"},
	"Unbending Oaths":  {"cost": 500.0, "blurb": "Kin stand by kin: +15 opinion between dynasty members, and burdens weigh lighter"},
	# Cross-Cultural Marriage (v1.0): a dynasty declares where it stands
	# on the blending the Silence made possible. Mutually exclusive.
	"The Syncretic Charter": {"cost": 300.0, "blurb": "The house commits to cultural blending: syncretism ripens 25% faster in its marriages", "excludes": "The Preserving Line"},
	"The Preserving Line":   {"cost": 250.0, "blurb": "The house keeps the old ways whole: no marriage of this blood will ever hybridize", "excludes": "The Syncretic Charter"},
	# Magic Injection v1.0 (doc §7): what a bloodline does about the Silence
	"The Patron's Bargain":    {"cost": 100.0, "blurb": "Power on credit: children of the blood are born +2 Martial, +2 Intrigue — and every one of them is born already owing on the ledger"},
	"The Iron Library Compact": {"cost": 200.0, "blurb": "The Archive remembers the house's dead: every death of the blood is recorded, and recorded deeds are renown"},
	"The Vael Compact":        {"cost": 250.0, "blurb": "The academies' tradition runs in the line: rulers of the blood administer one county further"},
	"The Salt Road Concord":   {"cost": 300.0, "blurb": "The caravans know the house's seal: +6 gold monthly while a trade pact holds, and the roads raise 5% more levies"},
	"The Brushgate Continuity": {"cost": 400.0, "blurb": "The discipline is kept at the family hearth: the whole blood carries its burdens lighter"},
	"The Ward-Speaker Line":   {"cost": 450.0, "blurb": "The Kharak-Dum ward-craft was taught to this blood: Ward-Speaker retinues answer the house's muster anywhere"},
}

# Dynasty Head Powers: what the patriarch's word costs the house's Renown.
const POWER_COST := {"disinherit": 100.0, "legitimize": 150.0, "denounce": 50.0, "call_to_war": 200.0}

# House Charters (Module 2 expansion): the legal terms of a cadet split.
const CHARTERS := {
	"loyalist":   {"label": "Loyalist Branch", "blurb": "Stays in the fold: renown pools with the dynasty, +10 opinion across the family"},
	"coequal":    {"label": "Co-Equal Split", "blurb": "A friendly parting: the branch takes 100 renown as endowment and answers to no one"},
	"schismatic": {"label": "Schismatic House", "blurb": "Born of a grievance: full independence — and a Blood Feud that outlives everyone alive today"},
}

# The House Mythos file: what a bloodline is *known for* — permanent tags
# earned by deeds, remembered by everyone, inherited by every child born.
const MYTHOS := {
	"Kin-Eater":           {"blurb": "A house that devours its own: -10 opinion from all outsiders"},
	"Whispered Poisoners": {"blurb": "Two dead kings whisper their name: -10 opinion abroad, but their plots weave faster"},
	"Blood of Kings":      {"blurb": "Forty years unbroken on a throne: +5 opinion from all, +1 renown a month"},
	# Cross-Cultural Marriage (v1.0): what a bloodline's marriages say about it
	"Compact-Bound":       {"blurb": "A Human-Orc marriage runs in this blood: +20 opinion from the clans, -10 from Aelindran traditionalists"},
	"Half-Blooded Line":   {"blurb": "Three cross-race marriages in the line: +10 opinion from the half-races, -5 from Purists"},
	"Pure of Blood":       {"blurb": "The line has never married across race, and says so: +15 opinion from Purists, -10 from the half-races"},
	# Magic Injection v1.0 (doc §7)
	"Patron-Touched":      {"blurb": "The bargain is publicly known in this blood: -10 opinion from all outsiders, but their plots weave 20% faster"},
	"Silence-Scarred":     {"blurb": "The house has buried its own marked by the Silence: grief the whole land recognizes"},
	"Vael-Educated":       {"blurb": "Three of the blood have sworn the academies: the line thinks in ledgers and proofs"},
	"Aelindran-Legitimate": {"blurb": "The old divine-right claim, now mechanically uncertain — kept alive by refusing to secularize (dormant until Module 9)"},
	"Ward-Broken":         {"blurb": "The house's warded lands fell to the Silence: mourned by the Scarred, unforgiven by the ward-wrights (dormant until the ward layer)"},
	# Administrative Government v1.0 (brief §4): the office does not pass
	# to the blood — but the blood is remembered for having held it.
	"Former Grand Magister Family": {"blurb": "The chair was theirs once: +5 opinion from Aelindran-Legitimate houses, -5 from Vael reformists"},
}
const KIN_CRUELTY_THRESHOLD := 3   # disinherits/denouncements before the Kin-Eater stain
const POISONINGS_THRESHOLD := 2
const CROWN_MONTHS_THRESHOLD := 480

# Government paradigms (Module 3): how land is legally held. Feudal and
# tribal are implemented; the last three are Khessar-map placeholders —
# the string sits on the realm record, mechanics arrive with later modules.
const GOVERNMENTS := {
	"feudal": {"label": "Feudal", "blurb": "Power rests on contracts: steady taxes and levies from the land, and titles to grant"},
	"tribal": {"label": "Tribal", "blurb": "Power is personal: lean taxes, but the levies swell with the ruler's fame and prowess at war"},
	"administrative": {"label": "Administrative", "blurb": "Power rests on the ledger: non-hereditary magistracies govern by council and appointment"},
	"merchant_republic": {"label": "Merchant Republic", "blurb": "Power floats on trade: patrician families and civic councils rule the wharves"},
	"clan": {"label": "Clan", "blurb": "Power flows through kinship: the great house and the realm are one and the same"},
}
# Administrative Government v1.0 (Opus's mini-brief, 2026-07-08): the
# nine seats of the Council of Magisters. Odd-numbered so ties are rare;
# the Grand Magister breaks the ones that happen anyway.
const MAGISTER_SEATS: Array[String] = ["Grand Magister", "Economic Affairs",
	"Foreign Affairs", "Clerical Registry", "Records Sublevel", "Chancellor",
	"Master of War", "Chief Physician", "Court Chaplain"]
const MAGISTER_MIN_LEARNING := 12     # no seat without the academies' arithmetic
const ELECTION_RANKS := 5             # preferential ballot: rank your top five, points 5..1

const DEJURE_DRIFT_MONTHS := 480      # 40 years of holding before the land forgets its old banners
const FOREIGN_LAND_YIELD := 0.6       # tax/levy of land you hold but do not rightfully own
const CROWN_ADMIN_BASE := 4           # counties the crown runs well without lords (+ stewardship/5)
const OVERREACH_YIELD := 0.75         # tax of crown counties beyond that

# --- Module 4: Vassal-Liege management ---
# Individual feudal contracts: what each lord owes the crown. Harsher
# terms yield more but are remembered; leniency buys loyalty with gold.
const CONTRACT_RATES := {
	"lenient": {"tax": 0.7, "levy": 0.7, "opinion": 10},
	"normal":  {"tax": 1.0, "levy": 1.0, "opinion": 0},
	"harsh":   {"tax": 1.3, "levy": 1.25, "opinion": -15},
}
# Privilege addenda ("privilege creep"): legal exemptions vassals extract
# when they hold leverage. Each is wired where it bites.
const PRIVILEGES := {
	"guaranteed_seat":   {"label": "Guaranteed Council Seat", "blurb": "the crown must seat them at its council table"},
	"war_sanction":      {"label": "War Declaration Sanction", "blurb": "owes only half their levies to the crown's wars"},
	"coinage_rights":    {"label": "Coinage Rights", "blurb": "mints their own coin — the crown sees only 60% of their taxes"},
	"marcher_lord":      {"label": "Marcher Lord", "blurb": "owes no levies, but their fortified marches are never ceded in a peace"},
	"judicial_immunity": {"label": "Judicial Immunity", "blurb": "cannot be lawfully stripped of land, whatever they do"},
}
# The Faction Engine: covert unions of discontent lords. At the strength
# threshold they turn overt and present an ultimatum — concede or fight.
const FACTION_LABELS := {
	"liberty": "Liberty", "claimant": "Claimant",
	"independence": "Independence", "populist": "Populist",
}
const FACTION_OVERT_FRACTION := 0.4   # rebel strength vs levy capacity before the ultimatum
const FACTION_JOIN_OPINION := -20     # lords angrier than this begin to conspire
# The Estate Curia: landed vassals vote in permanent blocs on great
# matters (war, harsher taxes, succession law). Blocs come from traits.
const CURIA_BLOCS := {
	"Absolutists":       {"traits": ["Ambitious", "Cruel", "Avaricious", "Deceitful"],
		"agenda": {"war": 1, "tax_heavy": 1, "succession": 0}},
	"Constitutionalists": {"traits": ["Honest", "Patient", "Methodical", "Compassionate"],
		"agenda": {"war": -1, "tax_heavy": -1, "succession": 0}},
	"Traditionalists":   {"traits": ["Purist", "Content", "Stoic", "Paranoid"],
		"agenda": {"war": -1, "tax_heavy": 0, "succession": -1}},
}
const CURIA_MIN_MEMBERS := 3          # fewer landed lords than this and the crown rules alone
const TYRANNY_DECAY := 0.5            # per month — the realm slowly forgets

# The standing-army model: regiments persist between battles. The
# universal roster (levy/sword/cav/archer) is open to every realm;
# cultural specialty kinds (Cultural Roster v1.0) need a province of
# their culture — see recruit_gate() and CultureData.KIND_CULTURE.
const UNIT_LABELS := {
	"levy": "Levy Spears", "sword": "Sword Infantry", "cav": "Heavy Cavalry", "archer": "Archers",
	"vael_arcane_retinue": "Arcane Retinue", "vael_court_company": "Court Company",
	"aelindran_household_cavalry": "Household Cavalry", "aelindran_sworn_sword": "Sworn Swords",
	"city_watch": "City Watch", "contract_militia": "Contract Militia",
	"harbor_guard": "Harbor Guard", "coin_sworn": "Coin-Sworn Retainers",
	"drevak_berserker": "Berserkers", "drevak_war_column": "War-Column",
	"compact_sworn": "Compact-Sworn",
	"dwarven_ironside": "Ironsides", "ward_speaker_retinue": "Ward-Speakers",
	"brushgate_column": "Brushgate Column",
	"veldarin_forest_sworn": "Forest-Sworn Archers", "veldarin_elder_guard": "Elder-Guard (Veldarin)",
	"thaladris_song_bound": "Song-Bound Skirmishers", "thaladris_elder_guard": "Elder-Guard (Thaladris)",
	"southern_marine": "Marines", "trade_guard": "Trade-Guard",
	# Tactical Combat System v1.0: the forces the Silence made
	"vigil_sworn_elite": "Vigil-Sworn Elite", "reactionary_chaplain": "Reactionary Chaplains",
	"warden_dead": "Warden-Dead", "caeris_retinue": "Caeris's Retinue",
	"forsaken_militia": "Forsaken Militia",
}
# strength weighting for the war AI: roughly cost / 200
const UNIT_WEIGHTS := {
	"levy": 1.0, "sword": 1.4, "cav": 2.2, "archer": 1.2,
	"vael_arcane_retinue": 2.2, "vael_court_company": 1.4,
	"aelindran_household_cavalry": 1.9, "aelindran_sworn_sword": 1.4,
	"city_watch": 1.2, "contract_militia": 1.1,
	"harbor_guard": 1.2, "coin_sworn": 1.6,
	"drevak_berserker": 1.9, "drevak_war_column": 1.5,
	"compact_sworn": 1.7,
	"dwarven_ironside": 1.9, "ward_speaker_retinue": 2.1,
	"brushgate_column": 2.0,
	"veldarin_forest_sworn": 1.7, "veldarin_elder_guard": 2.1,
	"thaladris_song_bound": 1.6, "thaladris_elder_guard": 2.1,
	"southern_marine": 1.3, "trade_guard": 1.4,
	"vigil_sworn_elite": 1.9, "reactionary_chaplain": 1.8,
	"warden_dead": 0.6, "caeris_retinue": 2.0,
	"forsaken_militia": 1.0,
}
# gold costs per the Roster's stat blocks
const RECRUIT_COST := {
	"levy": 120.0, "sword": 240.0, "cav": 450.0, "archer": 200.0,
	"vael_arcane_retinue": 450.0, "vael_court_company": 260.0,
	"aelindran_household_cavalry": 380.0, "aelindran_sworn_sword": 280.0,
	"city_watch": 220.0, "contract_militia": 200.0,
	"harbor_guard": 240.0, "coin_sworn": 320.0,
	"drevak_berserker": 380.0, "drevak_war_column": 300.0,
	"compact_sworn": 350.0,
	"dwarven_ironside": 380.0, "ward_speaker_retinue": 420.0,
	"brushgate_column": 400.0,
	"veldarin_forest_sworn": 340.0, "veldarin_elder_guard": 420.0,
	"thaladris_song_bound": 320.0, "thaladris_elder_guard": 420.0,
	"southern_marine": 260.0, "trade_guard": 280.0,
	"vigil_sworn_elite": 380.0, "reactionary_chaplain": 360.0,
	"warden_dead": 0.0, "caeris_retinue": 0.0,  # not recruited — they rise, or she brings them
	"forsaken_militia": 200.0,
}
const RECRUIT_SIZE := {
	"levy": 48, "sword": 36, "cav": 16, "archer": 24,
	"vael_arcane_retinue": 24, "vael_court_company": 40,
	"aelindran_household_cavalry": 18, "aelindran_sworn_sword": 32,
	"city_watch": 32, "contract_militia": 36,
	"harbor_guard": 32, "coin_sworn": 24,
	"drevak_berserker": 20, "drevak_war_column": 32,
	"compact_sworn": 28,
	"dwarven_ironside": 24, "ward_speaker_retinue": 16,
	"brushgate_column": 18,
	"veldarin_forest_sworn": 20, "veldarin_elder_guard": 16,
	"thaladris_song_bound": 22, "thaladris_elder_guard": 16,
	"southern_marine": 32, "trade_guard": 24,
	"vigil_sworn_elite": 24, "reactionary_chaplain": 16,
	"warden_dead": 40, "caeris_retinue": 12,
	"forsaken_militia": 36,
}
const UPKEEP_PER_MAN := 0.05     # the universal roster's rate
# per-man monthly upkeep where the Roster departs from the universal rate
const UNIT_UPKEEP := {
	"vael_arcane_retinue": 0.15, "vael_court_company": 0.06,
	"aelindran_household_cavalry": 0.10,
	"coin_sworn": 0.09, "contract_militia": 0.04, "harbor_guard": 0.05,
	"drevak_berserker": 0.11, "drevak_war_column": 0.06,
	"compact_sworn": 0.08,
	"dwarven_ironside": 0.10, "ward_speaker_retinue": 0.14,
	"brushgate_column": 0.12,
	"veldarin_forest_sworn": 0.08, "veldarin_elder_guard": 0.13,
	"thaladris_song_bound": 0.08, "thaladris_elder_guard": 0.13,
	"southern_marine": 0.05, "trade_guard": 0.07,
	"vigil_sworn_elite": 0.11, "reactionary_chaplain": 0.12,
	"warden_dead": 0.0, "caeris_retinue": 0.0,  # the dead draw no pay
	"forsaken_militia": 0.04,
}
const REPLENISH_COST_PER_MAN := 0.3

# Module 5: diplomacy between crowns
const TRUCE_MONTHS := 60              # a sworn peace binds for five years
const CB_LABELS := {
	"de_jure": "De Jure Reclamation",    # they hold land the maps call yours
	"restoration": "Restoration",        # you shelter the rightful lords they cast out
	"revenge": "Redress of Grievances",  # they invaded, or took what was yours
	"fabricated": "a Fabricated Claim",  # the Lawspeaker's forgeries, sworn as truth
	"subjugation": "Subjugation",        # the tribal way: strength is its own law
}
const FABRICATE_COST := 50.0
const REPARATIONS_RATE := 0.15        # of the loser's tax yield, monthly
const REPARATIONS_MONTHS := 120
const DEMILITARIZED_MONTHS := 120     # professional muster barred by treaty
const SALT_MONTHS := 240              # a generation before salted land recovers
const SALT_YIELD := 0.4
const RANSOM_COST := 100.0
const PRESTIGE_DECAY := 0.2           # the world forgets, slowly
const DEMOB_BOUNTY_PER_MAN := 0.5
const FREE_COMPANY_MIN_MEN := 60      # smaller bands melt away on their own

# Module 6: intrigue — secrets, hooks, schemes, and poison
const FERRET_COST := 30.0
const FERRET_GIVE_UP_MONTHS := 18     # even the best spymaster admits a dry well
const MINOR_SCHEME_COST := 60.0
const APOTHECARY_COST := 80.0
const ASSET_BRIBE := 40.0             # what a cupbearer's loyalty costs in coin
const MITHRIDATIC_MONTHS := 24        # micro-doses, patiently, for two years
const ASSET_ROLES := ["cupbearer", "food taster", "chamberlain", "stable master", "captain of the night watch"]
const VECTOR_LABELS := {
	"nightshade": "Nightshade",       # the classic: quick, quiet, whispered about
	"slow_weep": "The Slow Weep",     # five patient years that look like consumption
	"mad_mind": "The Mad Mind",       # the target survives; their sanity does not
}
const SECRET_LABELS := {
	"bastard blood": "bastard blood in the line",
	"a murderer's hand": "a murder bought and paid for",
	"a secret affair": "a bed shared in secret",
	# Magic Injection v1.0 (doc §6)
	"patron_bargain_signed": "a Patron's bargain, signed",
	"silence_cause_complicity": "the Silence's cause, and their part in it",
	"oath_object_broken": "an oath, broken at its object",
	"corruption_marks_hidden": "Corruption marks, concealed",
	"silence_encounter_witnessed": "present when the Silence broke through",
	"arcane_manifestation_hidden": "the blood untaught",
	# Administrative Government v1.0 (Opus's mini-brief §5)
	"magister_poisoning": "a Grand Magister's cup, and who paid for it",
}
const MINOR_SCHEME_LABELS := {
	"seduce": "Seduction", "abduct": "Abduction",
	"slander_lineage": "Slander: the False Lineage",
	"slander_vice": "Slander: the Manufactured Vice",
}

# Module 7: warfare — supply, sieges, and the men who march
# How many mouths a county can feed (terrain sets the ceiling; home
# stores raise it; salt and fire empty it). Doc: exceed it and starve.
const SUPPLY_BY_TERRAIN := {
	"plains": 380, "river_valley": 480, "hills": 260, "forest": 260,
	"coast": 340, "wetland": 160, "mountain": 110, "ashfields": 90, "ruined": 130,
}
const SUPPLY_HOME_MULT := 1.6         # your own granaries stand open to you
const ATTRITION_MAX := 0.12           # starvation's monthly ceiling
const SEVERED_ATTRITION := 0.04       # a cut supply line, compounding by the month
const BAGGAGE_RAID_RANGE := 0.05      # how close a raider must ride to the train
const SIEGE_BASE_PROGRESS := 6.0      # months of circumvallation, before the Marshal
const SIEGE_THRESHOLD_BASE := 100.0
const SIEGE_FORT_STEP := 25.0         # each fort level buys the defenders another season
const SCORCH_MONTHS := 60             # five years before scorched fields bear again
const SCORCH_YIELD := 0.4             # what a burned county still renders
const CHAMPION_COUNT := 3             # the named blades who ride with the main host
const CHAMPION_LEAD_DIV := 6.0        # pooled champion prowess -> battle leadership

# Magic Injection v1.0: the Corruption meter, the Silence Response, and
# the eight practices. Design: Opus's Magic Injection doc, 2026-07-08.
const SILENCE_RESPONSES: Array[String] = ["Zealous", "Broken", "Pragmatic", "Opportunistic"]
const CORRUPTION_MARKS: Array[String] = ["Corruption Mark I", "Corruption Mark II", "Corruption Mark III"]
const CORRUPTION_THRESHOLDS: Array[float] = [5.0, 10.0, 15.0]
const MARK_FLAVOR := {
	"Corruption Mark I": "the fingertips begin to darken",
	"Corruption Mark II": "light catches wrong in one iris — the cold-gold gleam",
	"Corruption Mark III": "they have become what they bargained with",
}
# How each Silence Response bends the Cleric's reliability (doc §4.3)
const RESPONSE_FAITH_MULT := {"Zealous": 1.15, "Broken": 0.60, "Pragmatic": 0.85, "Opportunistic": 0.70}
# silence_dampening_factor by ground (doc §4.3): the Ashfields smother,
# the ward-stones and the Iron Library still hold a little of the sky up
const FAITH_DAMPENING_BASE := 0.30
const FAITH_DAMPENING_ASHFIELDS := 0.10
const FAITH_DAMPENING_WARDSTONE := 0.60
const FAITH_DAMPENING_LIBRARY := 0.80
# Druid terrain effectiveness (doc §4.5): 0 = the primal channel is gone
const PRIMAL_TERRAIN := {
	"forest": 1.0, "wetland": 1.0, "river_valley": 1.0, "plains": 0.9,
	"hills": 0.9, "coast": 0.8, "mountain": 0.6, "ashfields": 0.0, "ruined": 0.0,
}
const CORRUPTION_ASHFIELDS_MONTHLY := 0.05
const CORRUPTION_RUINED_MONTHLY := 0.02

# Religion & the Silence (Module 9 v1.0, Opus's mini-brief 2026-07-08).
# Not a religion module: the module that models the collapse of religious
# authority and the successor institutions rising in the vacuum.
const FAITH_CAP := 15                 # brief §4: the continent carries no more doctrines than this
const FAITH_NAMES: Array[String] = ["Aelindran Orthodox", "Aelindran Reformed",
	"The Silent Path", "The Brushgate Order", "The Vael Rationalist Faith"]
# cultures the five faiths never covered keep their own practices as
# character-level labels (brief §2: Druidic/primal deferred to v1.1)
const FOLK_FAITHS := {"karn_vol": "the Drevak Rites", "drevak": "the Drevak Rites",
	"veldarin": "the Elder Ways", "thaladris": "the Elder Ways",
	"kharak_dum": "the Ward-Rites"}
# heresy is the natural state (brief §4): names and tenets the vacuum writes
const HERESY_NAMES: Array[String] = ["The Waiting Vigil", "The Doctrine of Embers",
	"The Unanswered Office", "The Keepers of the Last Rite", "The Candle Schism",
	"The Order of the Closed Sky", "The Penitents of the Third Hour",
	"The New Litany", "The Quiet Communion", "The Gathered Remnant"]
const HERESY_TENETS: Array[String] = [
	"The Silence is a door, not a wall.",
	"The rites must change or die with the sky.",
	"Only the laity can carry what the priesthood dropped.",
	"The pantheon sleeps, and can be woken by the right observance.",
	"The old calendar of rites is abolished; only the dead-days remain.",
	"No ordination survives the Silence; every believer is their own priest.",
]

var rng := RandomNumberGenerator.new()
var tick: int = 0                  # months since Year Zero of the Silence
var characters: Dictionary = {}    # id -> SimCharacter
var dynasties: Dictionary = {}     # id -> Dynasty
var realms: Array = []             # [Realm, Realm]
var next_character_id: int = 0

var at_war: bool = false
var war_score: float = 0.0         # drifts toward +100 (realms[0] wins) or -100 (realms[1] wins)
var trade_pact: bool = false
var marriage_alliances: Array = [] # [husband_id, wife_id] pairs binding the realms
var map := WorldMap.new()          # provinces drive tax income and levy strength
var armies: Array = []             # standing armies on the map (Army), in war and peace
var next_army_id: int = 0
var battle_ready: bool = false     # two hostile armies have met — a battle must be fought
var pending_battle: Array = []     # [army_id of realm 0, army_id of realm 1]
var blood_feuds: Array = []        # [root_a, root_b] pairs — schismatic splits, inherited forever
# Cross-Cultural Marriage (v1.0): every cross-culture wedding opens a
# household record — its path (imposition/syncretism/parallelism), the
# syncretism clock, and whether Hybridization has been decided.
var cross_marriages: Array = []    # [{husband, wife, path, progress, threshold, decided}]
var culture_drift: Dictionary = {} # province id -> {target, progress 0..100} (1%/month toward a hybrid)
var county_holders: Dictionary = {}  # province id -> character id (granted county titles)
var duchy_holders: Dictionary = {}   # duchy id -> character id
# Module 4: the push-and-pull of governing landed men
var vassal_contracts: Dictionary = {} # char id -> {tax, levy, privileges[]}
var factions: Array = []              # [{realm, type, members[], provinces[], covert, discovered, claimant}]
var council_snubbed: Dictionary = {}  # char id -> true (the grievance is voiced only once)
var last_trial_tick: int = -999       # the liege's court hears one great feud at a time
# Module 5: diplomacy between crowns — justifications, treaties, wards,
# and what all the swords do when the fighting stops.
var truce_until: int = -999           # no honorable war before this tick
var war_cb: String = ""               # the justification the current war marches under
var war_battles_won: Array = [0, 0]   # field battles carried per realm this war
var fabrication: Dictionary = {}      # {realm, months_left} — a claim being forged
var fabricated_claims: Dictionary = {} # realm id -> true: a forged claim, sealed and ready
var wards: Dictionary = {}            # child id -> {home, host, guardian, hostage, since, of_age}
var reparations: Dictionary = {}      # {from, to, months_left} — the yoke of a lost war
var demilitarized_until: Dictionary = {} # realm id -> tick professional muster resumes
var salted: Dictionary = {}           # province id -> tick the scars heal
var dispossessed: Dictionary = {}     # root house id -> {home, host, since} — courts-in-exile
var free_companies: Array = []        # Army objects with realm_id -1, paid in plunder
# Module 6: the web — what is known, who is owned, and what is brewing.
var secrets: Array = []               # [{subject, type, known: {realm id: true}}]
var hooks: Array = []                 # [{realm, target, strength weak|strong, source, spent}]
var ferreting: Dictionary = {}        # realm id -> months spent digging for secrets
var plot_details: Dictionary = {}     # realm id -> {vector, asset_id, asset_role, double_agent, waiting}
var minor_schemes: Array = []         # [{realm, kind, target, progress}] — seduce/abduct/slander
var mithridatism: Dictionary = {}     # char id -> months of micro-doses endured
# Module 7: warfare — who marched first, what stands besieged, what burns.
var war_aggressor: int = -1           # the realm that declared the current war
var war_start_strength := [0, 0]      # what each side marched out with (ambush math)
var occupied: Dictionary = {}         # province id -> occupying realm id (held under the sword)
var sieges: Dictionary = {}           # province id -> {attacker, progress, threshold}
var scorched: Dictionary = {}         # province id -> tick the fields bear again
var partisans: Dictionary = {}        # province id -> defending realm id — night-raid cells
var last_war_occupied: Array = []     # counties the winner held when the war ended — ceded first
# Magic Injection v1.0: the world under the Silence. All magic randomness
# runs on its own seeded RNG (like the map's) so the Year Zero founder
# seeds — and the main emergent history — are never disturbed by it.
var mrng := RandomNumberGenerator.new()
var architect_id: int = -1            # Veril Ormand, the last surviving yes-vote
# Faction Cast v1.0: the canonical Year Zero rulers of the map-only
# realms, as real characters. They live outside the two simulated
# realms' machinery (their own seeded RNG, scheduled beats — never a
# draw from the main stream), so the map reads as people, not territory.
var crng := RandomNumberGenerator.new()
var cast_rulers: Dictionary = {}      # map realm id -> {"id": char id, "title": String}
# Administrative Government v1.0: the Magistocracy governs as itself.
# All Council randomness runs on its own seeded RNG; the seeded Council
# characters are guarded out of the main stream's dice like the cast.
var arng := RandomNumberGenerator.new()
var admin_cast: Dictionary = {}       # char id -> true — seeded Council figures (politics, not actuarial tables)
var magister_seats: Dictionary = {}   # seat name -> {"holder": char id (-1 vacant), "since": tick seated}
var magister_wing: Dictionary = {}    # char id -> "reformist"|"traditionalist"|"neutral"|"silent"
var council_vote_history: Array = []  # [{tick, matter, ayes, nays, passed, votes {id: "aye"|"nay"|"abstain"}}] (brief §Phase 7)
var admin_interregnum: Dictionary = {} # {stage 0..6, regent, support {cand id: {voter id: float}}}
var last_election: Dictionary = {}    # {winner, points {cand id: int}, refused} — the last Council election
var pending_nomination: Dictionary = {} # {seat, nominee} — awaiting next tick's confirmation vote
var rejected_nominees: Dictionary = {}  # char id -> tick the Council last refused them
var anselm_id := -1                   # Grand Magister Anselm Vorontheim
var odric_id := -1                    # Odric Vasse, Court Chaplain until Month 9 — then the bees
var halloran_id := -1                 # Magister Halloran Verith, the Reformist wing
var davriand_id := -1                 # Magister Davriand Karn, the Traditionalist wing
var kreth_id := -1                    # Magister Kreth Anford, the moderate voice (dying by Year Six)
var mareck_id := -1                   # Chief Spymaster Tess Mareck (off-council)
var anselm_protection := 0            # protective choices taken before Month 34 (2+ foils the cup)
var poisoning_fired := false
var chaplain_crisis_fired := false
var central_secret_state: String = "buried"  # buried|revealed|contained|destroyed|leveraged|suppressed
var patron_network_broken: bool = false      # Ending 3: the anchor is ash
var faith_failures: Dictionary = {}   # char id -> failed prayers this year (Faith Crisis at 3)
var silence_mark_deaths: Dictionary = {}  # root house id -> members lost bearing Corruption Marks

# Religion & the Silence (Module 9 v1.0): every faith die rolls on `frng`
# (own seed, like the map's, the magic's, the cast's, and the Council's);
# the seeded canonical practitioners are `faith_cast` — the fixed-seed
# history never feels the theology.
var frng := RandomNumberGenerator.new()
var faith_cast: Dictionary = {}       # char id -> true — seeded practitioners (Halvar, Alenna, Anra)
var faiths: Dictionary = {}           # name -> {active, coherence, equilibrium, membership, orthodoxy_alignment, tenets, authorities, parent, founded, pressure}
var patron_state: String = "dormant"  # the covert non-faith: dormant -> building -> active -> revealed (or broken)
var prayer_fails_ever: Dictionary = {}  # char id -> lifetime failed prayers (faith-change preconditions, brief §6)
var orthodoxy_snapshot: Dictionary = {} # char id -> orthodoxy weight at last yearly reading (Faith Consideration, brief §5)
var faith_change_cooldown: Dictionary = {}  # char id -> tick a conversion chain last reached them
var cathedral_repurposed := false     # the Cathedral Question is asked once
var halvar_id := -1                   # Halvar Stenn, the Gravewarden Order's most respected living member
var alenna_id := -1                   # Alenna Stenn, his daughter — the practice inheriting
var anra_id := -1                     # Mother Anra Halden of Halvet — the Silent Path's first teacher

# The Architect's Vigil (v1.0): Veril Ormand's five-phase reckoning with
# the recipient who will not arrive (Opus's Vigil doc, 2026-07-08). All
# vigil dice roll on `vrng` — seeded 112, the year the bargain was signed.
# Veril himself stays in the main stream as ever, but his death is now the
# canon's (Year Six), not the actuarial tables': the die is still drawn,
# the answer is fixed. The old man keeps his own clock.
var vrng := RandomNumberGenerator.new()
var architect_phase := 0              # 1 confident waiting | 2 quiet uncertainty | 3 acknowledged crisis | 4 active recomposing | 5 termination | 6 the vigil is over
var vigil_recipient := ""             # "" until a 5B delivery lands: marek|sevrin|halvar|sera|thessaly
var vigil_contact := ""               # Phase 4 contact outcome: ""|received|intercepted
var vigil_contact_target := ""        # who Veril reached for at Month 54
var vigil_fragments := false          # the Spymaster's copy: truth in more hands than Veril chose
var vigil_delivery_tick := -1         # the modified ritual's scheduled date (5B), -1 none
var thessaly_id := -1                 # Thessaly Vorn — the Iron Library's discipline, post-Marek
var marek_id := -1                    # Marek Vovel, Chief Archivist (dies Year Four, Vigil doc §2)
var sera_id := -1                     # Sera Halvenard-Veil — Garran's eldest daughter, birth-date-corrected to 17 at setup
var sevrin_id := -1                   # Sevrin Vorontheim (also a Vigil candidate)

# The World the Silence Made (v1.1, Opus 2026-07-08): Caeris the Unfinished —
# the ETHICAL antagonist, not a tactical one — and the Forsaken, the
# generation born under the silent sky. All dice roll on `srng`, seeded 63:
# the percentage of himself Caeris still measures as alive. The main history
# stream never feels the Ashfields.
const ASHFIELDS_REALM := 99           # sentinel realm id: uncontrolled, is_cast by construction
const FRAMEWORK_STAGE1_MONTHS := 12   # political coordination (doc §5: 12-18)
const FRAMEWORK_STAGE2_MONTHS := 18   # framework construction (doc §5: 12-24)
const ENDORSEMENTS_NEEDED := 3        # formal endorsement from at least three realms
const ENDORSE_COST := 40.0
const CAERIS_SETTLING_TICK := 600     # Year 50: the waiting begins to feel like unresolved failure
const CAERIS_SETTLED_TICK := 660      # five years on, the scholar himself begins to thin
const CONVERGENCE_TICK := 600         # the three antagonist structures reach threshold together
const FORSAKEN_STAGES := [10.0, 50.0, 200.0, 500.0]  # whispered | visible | political | dominance
const FORSAKEN_VARIANTS := {
	"vael": "the academy cells",
	"halven": "the Forsaken Underground",
	"free_city": "the independence circles",
	"karn_vol": "the new-compact generation",
	"southern_reach": "the cosmopolitan current",
}
var srng := RandomNumberGenerator.new()
var caeris_id := -1                   # Caeris the Unfinished — 63% alive by his own measurement
var maret_id := -1                    # Maret, the Revenant research associate (MM Vol. II)
var ashfields: Dictionary = {}        # the community ledger — see _seed_silence_made
var forsaken_movements: Dictionary = {}  # region -> {strength, stage, growth_mult, engaged}
var convergence := ""                 # "" until the Year-50 crisis names its shape

# The Hero System v1.0 (Opus doc, 2026-07-08): hero-tier characters —
# distinguished practitioners whose personal actions shape battles and
# campaigns. Every hero die rolls on `hrng` (seed 75 — the XP capstone);
# the seeded canonical heroes are `hero_cast`, folded into is_cast(), so
# the fixed-seed history never feels their arrival. The hero stream
# discipline extends the house invariant: auto-firing beats fill only
# the hero ledger (XP, personal HP, the pool counts) — the Core Six move
# only under the player's hand.
var hrng := RandomNumberGenerator.new()
var hero_cast := {}                   # id -> true: hero-pass-seeded souls guarded out of the main stream
var hero_deploys := {}                # id -> never|rarely|normal|eager (doc §6 deployment styles)
var hero_pool := {}                   # region key -> unnamed hero-tier count (doc §2/§5 density)
var hero_pool_carry := 0.0            # fractional accumulator for the yearly drift
var court_positions := {}             # id -> canonical position label (SRD rule: NPCs are their
                                      # office, not a class — Master Merchant, Chief Archivist...)

# Canon Pass One (Opus's brief v1.1, 2026-07-15): scale and the famine.
# Khessar holds 110 million souls, and the famine that has been running
# since Year Zero kills on a logistic curve the Architect priced to the
# decimal six years before dying. All famine dice roll on `grng`, seed
# 66 — one in sixty-six, the Year Six mortality. Auto-fire touches ONLY
# the famine ledger and province population counters; player-initiated
# grain actions may touch the player's own realm. The number is never a
# headline: it lives in the Records Sublevel, because that is the only
# place in Khessar where it is written down.
var grng := RandomNumberGenerator.new()
var famine_deaths_total: int = 0      # the running continental toll
var famine_deaths_year: int = 0       # the current (incomplete) year
var famine_actual_by_year := {}       # year -> deaths actually recorded
var architect_forecast := {}          # year -> the forecast, static from setup (his arithmetic)
var famine_carry := {}                # province id -> fractional deaths accumulator
var famine_dead_by_pid := {}          # province id -> cumulative famine dead
var famine_relief := {}               # province id -> tick relief expires (open granaries)
var villages_emptied: int = 0         # the quiet counter that IS the player-facing surface

# Canon Pass One §3: the Iron Wren. Wren of Vetral — Iron Library
# records say Wren Callister; twelve when the green-wizard Sark turned
# her village into a grove of forty-seven trees in Year One. She is not
# an interface: no opinions, no demands, no deals. Not a hero — the
# hero roster would be the natural place to put her, and it would be
# WRONG. She is an independent map-actor with her own logic, closer to
# a weather system with a grudge. Dice on `wrng`, seed 47 — the trees.
# Auto-fire touches only her ledger and the anchor-mage roster.
var wrng := RandomNumberGenerator.new()
var anchor_mages := {}                # key -> {name, house, age, pid, working, records, alive, ...}
var wren_alive := true
var wren_active := false              # false until Vetral burns (Year One)
var wren_tokens: int = 0              # seven by Year Six; the eighth is uncarved
var wren_target: String = ""          # anchor-mage roster key under study
var wren_study_months: int = 0
var wren_study_needed: int = 0
var wren_rest_until: int = -1         # between hunts: travel, reading, the mare
var wren_region_pid: int = 29         # Vetral — a Salt Road margin province
var wren_unmaking: float = 0.0        # progress toward the un-making (0..100)
var wren_knows_token := true          # she learned of the consent token in Year One
var wren_obstruction := {}            # realm id -> score: shield her targets and she remembers
var wren_avoid_realm := {}            # realm id -> tick she works elsewhere until
var wren_vetral_attempted := false
var wren_vetral_outcome := ""         # ""|"unmade"|"failed" — both are canon-compatible
var wren_token_retrieval := ""        # ""|"scheduled"|"taken"|"driven_off" — the eighth working
var wren_token_tick := -1
var patron_anchor_voided := false     # the consent token removed: authorization void — NOT ash

# Canon Pass Two §1: entity density. The Silence did not create new
# threats; it removed the supervision. Density is a function of
# ABANDONMENT, not elapsed time — vacancies are produced by human
# failure, and the correction that inverts intuition: density rises
# fastest where divine supervision was HEAVIEST. Piety was
# infrastructure. Dice on `erng`, seed 60 — the sixty feet of a Shade's
# anchor-bond (47 was taken; her grove is hers). Ledger-only. The
# Ashfields are EXCLUDED — that density has an author, and he is
# already fully modeled on `srng`.
var erng := RandomNumberGenerator.new()
var province_vacancies := {}          # province id -> float, unclaimed anchor sites
var province_anchors := {}            # province id -> int, claimed anchors (they do not un-claim)
var unburied_fields := {}             # province id -> {dead, tick} — five thousand reasons
var shrines_tended := {}              # province id -> tick the tending lapses
var regional_tension := {}            # region -> months of sustained unresolved grievance
var volume2_manifested: Array = []    # [{name, region, tick}] — appointments kept
var wardstone_linkage_known := false  # the Ironbrand discoverable: WHY the deep passages worsen

# Canon Pass Two §2: the Underneath — the criminal, poverty, and cult
# layer. Criminal organizations are intrigue actors; cults are faith
# actors: people who decided that if prayer will not work, leverage
# might. Poverty is not a new variable — it is the famine module plus
# the existing scalars read from below; what is new is the refugee
# flow, and the Bone Court waiting at the end of it. Dice on `urng`,
# seed 12 — the twelve pact-families of the Hollow Decades.
var urng := RandomNumberGenerator.new()
var criminal_orgs := {}               # key -> live record (CanonData seeds it)
var cults := {}                       # key -> live record: strength, state, beats fired
var displaced := {}                   # category -> souls on the road (ashfields|famine|war|silence_touched)
var refugee_flow_month: float = 0.0   # this month's continental movement
var bone_court_taken: int = 0         # the ledger of the one unambiguous evil
var underneath_lethal := false        # Justin's ruling gate: may cult cells kill named souls?
var house_records := {}               # house key -> {discovered: bool, ...} — the 46 houses' live state

# The event framework: choice events with trait-weighted AI resolution.
var pending_events: Array = []       # events awaiting the player's decision
var next_event_id: int = 0
var auto_resolve_events := false     # headless mode: AI decides even for realm 0
var events_resolved_by_ai: int = 0


class Dynasty:
	## One noble House (Module 2). Houses form a tree: cadet branches keep
	## a parent_id back to the house they split from, and the whole tree is
	## one *dynasty*, pooling its Renown on the root house.
	var id: int
	var name: String               # "House Varen"
	var parent_id: int = -1        # -1 = founding house (a dynasty root)
	var founder_id: int = -1       # the character who split the branch off
	var charter: String = "loyalist"  # cadet branches: "loyalist" | "coequal" | "schismatic"
	var renown: float = 0.0        # dynasty currency — meaningful on the root only
	var legacies: Array[String] = []  # bought perks — root only
	# The House Mythos file: permanent reputational marks and their counters.
	var mythos: Array[String] = []    # earned tags — root only
	var kin_cruelty: int = 0          # disinherits + denouncements by the head
	var poisonings: int = 0           # successful assassinations under this blood
	var crown_months: int = 0         # months a member has held a crown
	var cross_race_marriages: int = 0 # weddings across race lines under this blood

	func _init(p_id: int, p_name: String) -> void:
		id = p_id
		name = p_name

	func surname() -> String:
		return name.trim_prefix("House ")


class Realm:
	var id: int
	var name: String
	var ruler_id: int = -1
	var government: String = "feudal"   # feudal|tribal live; administrative|merchant_republic|clan planned (Module 3)
	var gold: float = 120.0
	var council: Dictionary = {}         # seat name -> character id
	var tax_law: String = "moderate"
	var succession_law: String = "male"  # "male" (male-preference) or "absolute"
	var pending_law: Dictionary = {}     # {law, value, months_left}
	var plot_target_id: int = -1
	var plot_progress: float = -1.0      # < 0 = no plot in motion
	var plot_warned: bool = false        # the victim's court has caught wind of it
	var tyranny: float = 0.0             # Module 4: remembered injustice — revocations, harsh terms, bad verdicts
	var prestige: float = 0.0            # Module 5: international standing — unjust wars and broken truces bleed it
	var apothecary: bool = false         # Module 6: a hidden lab beneath the estate
	var alchemist_id: int = -1           # the unlanded courtier who tends the stills
	var plot_vector_pref: String = "nightshade"  # what the lab brews for the next strike
	# The Interregnum (Module 2): between death and coronation the realm
	# holds its breath. {heir, stage 0..4, legitimacy 0..100}
	var interregnum: Dictionary = {}
	var male_names: Array = []
	var female_names: Array = []

	func _init(p_id: int, p_name: String) -> void:
		id = p_id
		name = p_name


class Army:
	## A standing army on the campaign map. Its regiments persist between
	## battles, and its commander is a real character from the dynasty.
	var id: int
	var realm_id: int
	var pos := Vector2.ZERO       # normalized map coords
	var has_target := false
	var target := Vector2.ZERO
	var regiments: Array = []     # [{kind, soldiers, max}]
	var commander_id := -1
	# Module 7: the physical supply train that trails an army abroad
	var train_active := false     # marching on foreign soil — the train is on the road
	var train_pos := Vector2.ZERO # where the wagons actually are
	var severed_months := 0       # months since the line of communication was cut

	func size() -> int:
		var total := 0
		for reg in regiments:
			total += int(reg["soldiers"])
		return total


# ---------------------------------------------------------------- setup

func setup() -> void:
	rng.seed = 1066  # fixed seed: the same history every run (a historic constant, not a calendar year)

	# The two realms simulated live at Year Zero: the Magistocracy and the
	# Drevak border clan across the Marn's Crossing pass. The other ten
	# powers on the Khessar map exist as map.realms records until later
	# modules bring them online. Name pools are placeholders for now.
	var vael := Realm.new(0, "Magistocracy of Vael")
	vael.government = "administrative"  # placeholder paradigm — behaves feudal until its module lands
	vael.male_names = ["Aldric", "Edmund", "Godwin", "Harold", "Osric", "Leofric", "Wulfric", "Cedric", "Dunstan", "Alfred"]
	vael.female_names = ["Edith", "Mildred", "Hilda", "Aldith", "Sunniva", "Wynflaed", "Godgifu", "Aefled", "Maerwynn", "Estrid"]

	var karn_vol := Realm.new(1, "Karn-Vol Clan")
	karn_vol.government = "tribal"  # power is personal beyond the mountains
	karn_vol.male_names = ["Radomir", "Boris", "Stanislav", "Milos", "Dragan", "Vukan", "Casimir", "Zoran", "Predrag", "Tihomir"]
	karn_vol.female_names = ["Milena", "Zorica", "Danica", "Ludmila", "Vesna", "Katarina", "Mira", "Bogdana", "Jelena", "Radost"]

	realms = [vael, karn_vol]
	map.generate(777)  # own seed — the map never disturbs character-history RNG
	_seed_house(vael, "House Halvenard-Veil", true)
	_seed_house(vael, "House Aurath-Voss", false)
	_seed_house(karn_vol, "House Karn-Vol", true)
	_seed_house(karn_vol, "House Vor-Grathkaz", false)
	# The canonical 200-year feud (Faction Map v1.0): Halvenard-Veil and
	# Aurath-Voss both serve the Magistocracy, and neither side forgets
	# the Sovereignty's fall. House ids 0 and 1 are the two Vael houses.
	blood_feuds.append([0, 1])
	_log("An old feud smolders between House Halvenard-Veil and House Aurath-Voss — two hundred years, and neither side forgets.")
	for realm: Realm in realms:
		var a := _create_army(realm.id, map.realm_centroid(realm.id))
		a.regiments = [
			{"kind": "cav", "soldiers": 16, "max": 16},
			{"kind": "archer", "soldiers": 24, "max": 24},
			{"kind": "sword", "soldiers": 36, "max": 36},
			{"kind": "levy", "soldiers": 48, "max": 48},
			{"kind": "sword", "soldiers": 36, "max": 36},
		]
		_assign_commander(a)
	_ai_fill_council(0)
	_ai_fill_council(1)
	_log("[b]Year 0, Month 1 of the Silence.[/b] The gods have stopped answering — and every crown must learn anew what its legitimacy rests on.")
	_seed_magic()  # the Night of the Third Hour answered by every living soul (Magic v1.0)
	# Faction Cast v1.0: the live founders take their canonical names
	# (the seed rolled placeholders from the pools; the Faction Map's
	# names win — a pure rename, no dice touched)...
	if realms[0].ruler_id >= 0:
		var garran: SimCharacter = characters[realms[0].ruler_id]
		garran.name = "Garran"
		# canon reconciliation (Opus, Gazetteer): Garran is 55 at Year Zero —
		# the Faction Map aged him so Sera reaches a canonical 23 by Year
		# Six. A birth-date correction, not a dice roll.
		garran.birth_tick = tick - 55 * 12 - 5
		# ...and the daughter the aging was FOR (Architect's Vigil v1.0):
		# Garran's eldest rolled daughter takes the canonical name and the
		# canonical birth date — 17 at Year Zero, 23 by Year Six. The same
		# corrections Garran himself got; no dice touched.
		var eldest: SimCharacter = null
		for cid in garran.children_ids:
			var kid: SimCharacter = characters.get(cid)
			if kid != null and kid.alive and kid.is_female:
				if eldest == null or kid.birth_tick < eldest.birth_tick:
					eldest = kid
		if eldest != null:
			eldest.name = "Sera"
			eldest.birth_tick = tick - 17 * 12 - 5
			sera_id = eldest.id
		else:
			# The Focused-trait reshuffle (Canon Updates v1.0) rolled Garran
			# no daughter — but Sera is canon (Vigil doc §6: 17 at Year Zero,
			# 23 by the TTRPG's present). She is spawned on her own one-off
			# seed: no main-stream die is drawn, the rest of history stands.
			var sera_rng := RandomNumberGenerator.new()
			sera_rng.seed = 23  # her canonical age when the TTRPG finds her
			var sera := _create_character("Sera", true, tick - 17 * 12 - 5, garran.dynasty_id, 0)
			sera.father_id = garran.id
			garran.children_ids.append(sera.id)
			var mother: SimCharacter = characters.get(garran.spouse_id) if garran.spouse_id >= 0 else null
			if mother != null:
				sera.mother_id = mother.id
				mother.children_ids.append(sera.id)
				sera.genome = Genetics.inherit(sera_rng, garran.genome, mother.genome)
				for key in STAT_PROPS.values():
					var mid := int((int(garran.get(key)) + int(mother.get(key))) / 2.0)
					sera.set(key, clampi(mid + sera_rng.randi_range(-3, 4), 1, 30))
			else:
				sera.genome = Genetics.founder(sera_rng)
				for key in STAT_PROPS.values():
					sera.set(key, sera_rng.randi_range(4, 14))
			_apply_racial_baseline(sera)
			# _seed_magic has already answered the Night of the Third Hour —
			# she answers it here, deterministically, like every living soul
			_add_trait(sera, "Pragmatic")
			sera_id = sera.id
	if realms[1].ruler_id >= 0:
		characters[realms[1].ruler_id].name = "Vorak"
	# ...and the map-only realms get their canonical crowns as real people
	_seed_faction_cast()
	# Administrative Government v1.0: the Magistocracy becomes playable as
	# itself — Anselm Vorontheim takes the chair the Halvenard-Veil head
	# has been keeping warm, and the Council of Magisters sits.
	_seed_administration()
	# Religion & the Silence v1.0: five faiths at Year Zero, the orthodoxy
	# axis goes live, and the God of Thresholds walks in the world.
	_seed_faiths()
	# The Architect's Vigil v1.0: Veril Ormand's clock starts — confident,
	# patient, and wrong about who is coming.
	_seed_vigil()
	# The World the Silence Made v1.1: the scholar in the Ashfields has been
	# waiting six years already, and the Forsaken are being born.
	_seed_silence_made()
	# The Hero System v1.0: the named canonical heroes take their levels,
	# and the ones the chronicle owed a body finally get one.
	_seed_heroes()
	# Canon Pass One (2026-07-15): 110 million souls take their provinces,
	# and the Architect's forecast table is written into the Records
	# Sublevel — forty years of arithmetic he will see six of.
	_seed_population()
	# Canon Pass Two: the 46 houses' buried hooks enter the web (outside
	# the tavern pool), and the anchor-mage lineages take their towers.
	_seed_houses()
	# Canon Pass Two §2: the Underneath — the organizations and the ten
	# cults, embryonic at Year Zero, growing with the hunger.
	_seed_underneath()
	# Canon Pass One §3: a twelve-year-old in Vetral, one year before the
	# grove. The map does not know her name yet.
	_seed_wren()
	# Canon Pass Two §1: the maintenance schedule has ended; the ground
	# starts keeping its own ledger of vacancies.
	_seed_entities()


func _seed_house(realm: Realm, house_name: String, ruling: bool) -> void:
	var dyn := Dynasty.new(dynasties.size(), house_name)
	dynasties[dyn.id] = dyn

	var patriarch := _spawn(realm, dyn.id, false, rng.randi_range(38, 50))
	var matriarch := _spawn(realm, dyn.id, true, rng.randi_range(34, 44))
	patriarch.spouse_id = matriarch.id
	matriarch.spouse_id = patriarch.id

	for i in rng.randi_range(2, 4):
		var child := _spawn(realm, dyn.id, rng.randf() < 0.5, rng.randi_range(2, 24))
		child.father_id = patriarch.id
		child.mother_id = matriarch.id
		# founding children inherit properly too, so families resemble
		# each other from the very first screen
		child.genome = Genetics.inherit(rng, patriarch.genome, matriarch.genome)
		child.traits.clear()
		_blend_stats(child, patriarch, matriarch)
		_inherit_traits(child, patriarch, matriarch)
		patriarch.children_ids.append(child.id)
		matriarch.children_ids.append(child.id)

	if ruling:
		realm.ruler_id = patriarch.id


func _spawn(realm: Realm, dyn_id: int, female: bool, age: int) -> SimCharacter:
	var birth := tick - age * 12 - rng.randi_range(0, 11)
	var c := _create_character(_pick_name(realm, female), female, birth, dyn_id, realm.id)
	_roll_stats(c)
	_apply_racial_baseline(c)
	c.genome = Genetics.founder(rng)
	_assign_founder_traits(c)
	return c


func _create_character(p_name: String, female: bool, birth: int, dyn_id: int, realm_id: int) -> SimCharacter:
	var c := SimCharacter.new()
	c.id = next_character_id
	next_character_id += 1
	c.name = p_name
	c.is_female = female
	c.birth_tick = birth
	c.dynasty_id = dyn_id
	c.realm_id = realm_id
	# Culture is martial tradition, not blood (Cultural Roster v1.0). The
	# simulated Vael court is the two great noble houses — Aelindran-
	# cultured per the Roster ("their loyalty is political; their culture
	# is older"); the border clan practices the Karn-Vol subvariant.
	# Race is blood (Cross-Cultural Marriage v1.0): the Vael houses are
	# Human, the clan is Orc; births override this from the parents.
	c.culture = "aelindran" if realm_id == 0 else "karn_vol"
	c.race = "human" if realm_id == 0 else "orc"
	characters[c.id] = c
	return c


func _apply_racial_baseline(c: SimCharacter) -> void:
	## Small racial stat baselines from the Cultural Roster (race is
	## biology; culture is tradition). Applied once, after stats roll.
	var mods: Dictionary = CultureData.RACES.get(c.race, {}).get("stats", {})
	for k in mods:
		var prop: String = STAT_PROPS[k]
		c.set(prop, clampi(int(c.get(prop)) + int(mods[k]), 1, 30))


func _roll_stats(c: SimCharacter) -> void:
	for key in STAT_PROPS.values():
		c.set(key, rng.randi_range(3, 16))


func _blend_stats(c: SimCharacter, father: SimCharacter, mother: SimCharacter) -> void:
	for key in STAT_PROPS.values():
		var mid := int((int(father.get(key)) + int(mother.get(key))) / 2.0)
		c.set(key, clampi(mid + rng.randi_range(-3, 4), 1, 30))


func _pick_name(realm: Realm, female: bool) -> String:
	var pool: Array = realm.female_names if female else realm.male_names
	return pool[rng.randi_range(0, pool.size() - 1)]


# ---------------------------------------------------------------- monthly tick

func advance_month() -> void:
	tick += 1
	_births()
	_bastards_tick()
	_deaths()
	_auto_marriages()
	_syncretism_tick()
	_culture_drift_tick()
	_stress_relief_tick()
	_renown_tick()
	_cadet_branch_tick()
	_ai_dynasty()
	_interregnum_tick()
	_dejure_tick()
	_factions_tick()
	_vassal_politics_tick()
	_council_tick()
	_laws_tick()
	_plots_tick()
	_intrigue_tick()
	_magic_tick()
	_cast_tick()
	_admin_tick()
	_religion_tick()
	_vigil_tick()
	_silence_made_tick()
	_hero_tick()
	# Canon Passes One & Two: precedence famine > wren > entity >
	# underneath — all auto-firing and ledger-only, at the chain's foot.
	_famine_tick()
	_wren_tick()
	_entity_tick()
	_underneath_tick()
	_diplomacy_tick()
	_ai_diplomacy()
	_economy()
	_military_upkeep()
	_ai_recruit()
	_campaign_military()
	_warfare_tick()
	# while two armies stand facing each other, the war waits on the battle
	if at_war and not battle_ready:
		_war_tick()


func _births() -> void:
	var mothers: Array = []
	for c in characters.values():
		if not (c.alive and c.is_female and c.spouse_id >= 0) or is_cast(c):
			continue
		var husband: SimCharacter = characters[c.spouse_id]
		if not husband.alive:
			continue
		var age: int = c.age_years(tick)
		if age < ADULT_AGE or age > 45:
			continue
		if tick - c.last_birth_tick < 18:
			continue
		if rng.randf() < 0.035:
			mothers.append(c)
	for mother in mothers:
		_birth(mother)


func _birth(mother: SimCharacter) -> void:
	var father: SimCharacter = characters[mother.spouse_id]
	var child := _make_child(father, mother)
	_log("%s and %s welcome a %s, %s." % [full_name(father), full_name(mother),
		"daughter" if child.is_female else "son", child.name])


func _make_child(father: SimCharacter, mother: SimCharacter) -> SimCharacter:
	## Shared machinery of every birth, wedded or not: inheritance of
	## stats, genes, and traits, plus the family bookkeeping.
	var female := rng.randf() < 0.5
	var realm: Realm = realms[father.realm_id]
	var child := _create_character(_pick_name(realm, female), female, tick, father.dynasty_id, father.realm_id)
	# the biology layer: races combine (Cross-Cultural Marriage v1.0 §2)
	child.race = CultureData.child_race(father.race, mother.race)
	_blend_stats(child, father, mother)
	_apply_racial_baseline(child)
	child.genome = Genetics.inherit(rng, father.genome, mother.genome)
	_inherit_traits(child, father, mother)
	# the cultural layer: a syncretism-path household raises its children
	# in both worlds — the Bicultural trait is upbringing, not blood
	if father.culture != mother.culture and _marriage_record(father.id, mother.id).get("path", "") == "syncretism":
		_add_trait(child, "Bicultural")
	if has_legacy(root_house_id(father.dynasty_id), "Blood of the Wolf"):
		child.martial = clampi(child.martial + 1, 1, 30)
		child.prowess = clampi(child.prowess + 1, 1, 30)
	if has_legacy(root_house_id(father.dynasty_id), "The Patron's Bargain"):
		# power on credit (Magic v1.0): born sharper — and born owing
		child.martial = clampi(child.martial + 2, 1, 30)
		child.intrigue = clampi(child.intrigue + 2, 1, 30)
		child.corruption = 2.0
	# Module 9: children inherit the parent faith by default (brief §3);
	# the God of Thresholds' blessing at the cradle rides its own dice
	child.faith = father.faith if father.faith != "" else mother.faith
	if not child.traits.has("Threshold-Sensitive"):
		for parent: SimCharacter in [father, mother]:
			if parent.traits.has("Threshold-Sensitive") and frng.randf() < 0.03:
				_add_trait(child, "Threshold-Sensitive")
				break
	child.father_id = father.id
	child.mother_id = mother.id
	father.children_ids.append(child.id)
	mother.children_ids.append(child.id)
	mother.last_birth_tick = tick
	for parent: SimCharacter in [father, mother]:
		add_stress(parent, -5.0, "a child is born")
		add_memory(parent, "child born", child.id, 30.0, 0.5)
		add_memory(child, "my parent", parent.id, 30.0, 0.0)
	return child


func _bastards_tick() -> void:
	## Noble men stray. A bastard joins the father's house but stands
	## outside the succession — until the dynasty head legitimizes them.
	for c in characters.values():
		if not c.alive or c.is_female or c.is_bastard or is_cast(c):
			continue
		var age: int = c.age_years(tick)
		if age < ADULT_AGE or age > 45:
			continue
		if rng.randf() > 0.003:
			continue
		var mother: SimCharacter = null
		for w in characters.values():
			if not (w.alive and w.is_female and w.spouse_id < 0):
				continue
			var wage: int = w.age_years(tick)
			if wage < ADULT_AGE or wage > 45 or w.realm_id != c.realm_id:
				continue
			if tick - w.last_birth_tick < 18 or _close_kin(c, w):
				continue
			mother = w
			break
		if mother == null:
			continue
		var child := _make_child(c, mother)
		child.is_bastard = true
		if c.spouse_id >= 0 and characters[c.spouse_id].alive:
			var wife: SimCharacter = characters[c.spouse_id]
			add_memory(wife, "a bastard shames me", c.id, -20.0, 2.0)
			add_stress(wife, 10.0, "a husband's betrayal")
		_log("%s acknowledges a bastard %s, %s." % [full_name(c),
			"daughter" if child.is_female else "son", child.name])
		_add_secret(c.id, "bastard blood")  # acknowledged at home; leverage abroad
		return  # at most one scandal a month — the chronicle can only take so much


func _deaths() -> void:
	var doomed: Array = []
	for c in characters.values():
		if not c.alive or is_cast(c):
			continue  # the cast's fates are scheduled beats, not dice (Faction Cast v1.0)
		var age: int = c.age_years(tick)
		var chance := _death_chance(age, c.race)
		if c.traits.has("Wasting"):
			chance *= 4.0  # the Slow Weep does its patient, deniable work
		if rng.randf() < chance:
			# The Architect's Vigil: Veril's death is Year Six canon (Vigil
			# doc §2, Phase Five). The actuarial die is still drawn — the
			# main stream must not shift — but the answer belongs to the
			# vigil's own clock, not the tables.
			if c.id != architect_id:
				doomed.append(c)
		# long-reign fatigue (Cross-Cultural Marriage v1.0): a life run
		# 20% past its race's span has outlived its own political era
		elif age > int(CultureData.race_lifespan(c.race) * 1.2) and _can_add_trait(c, "Long-Reigned"):
			_add_trait(c, "Long-Reigned")
			_log("%s has outlived their era — the court serves, but no longer hopes." % full_name(c))
	for c in doomed:
		_kill(c, "has died")


func _death_chance(age: int, race: String = "human") -> float:
	## Mortality curves scale to the race's lifespan (v1.0 biology layer):
	## the aging pivot sits where a Human's 45 sits against a Human's 78.
	var q := 0.0004
	if age < 5:
		q += 0.002
	var pivot := float(CultureData.race_lifespan(race)) * (45.0 / 78.0)
	if float(age) > pivot:
		var over := float(age) - pivot
		q += over * over * 0.00004
	return q


func _kill(c: SimCharacter, cause: String) -> void:
	c.alive = false
	if c.spouse_id >= 0:
		var spouse: SimCharacter = characters[c.spouse_id]
		spouse.spouse_id = -1
		c.spouse_id = -1
		add_stress(spouse, 15.0, "widowed")
	for pid in [c.father_id, c.mother_id]:
		if pid >= 0 and characters[pid].alive:
			var parent: SimCharacter = characters[pid]
			var grief := 20.0
			if parent.traits.has("Compassionate"):
				grief += 10.0
			add_stress(parent, grief, "a child in the grave")
	# grudges outlive the dead: children inherit their parent's deepest hatreds
	for kid_id in c.children_ids:
		var kid: SimCharacter = characters[kid_id]
		if not kid.alive:
			continue
		for m in c.memories:
			if float(m["value"]) <= -40.0 and characters.has(int(m["subject"])) and characters[int(m["subject"])].alive:
				add_memory(kid, "inherited grudge", int(m["subject"]), float(m["value"]) * 0.5, 2.0)
	_log("%s %s at %d." % [full_name(c), cause, c.age_years(tick)])
	# Magic Injection v1.0: the Bard asks for the name; the Archive
	# records the deed; a house that buries its marked is marked itself
	for b in characters.values():
		if b.alive and b.id != c.id and b.realm_id == c.realm_id and b.traits.has("Song-Marked"):
			b.names_carried += 1
	var dead_root := root_house_id(c.dynasty_id)
	if has_legacy(dead_root, "The Iron Library Compact"):
		dynasties[dead_root].renown += 0.5
	if c.corruption_marks >= 2:
		silence_mark_deaths[dead_root] = int(silence_mark_deaths.get(dead_root, 0)) + 1
		if int(silence_mark_deaths[dead_root]) >= 2:
			_earn_mythos(dead_root, "Silence-Scarred")
	# Module 9 addendum: a practitioner receives the dead at the threshold
	_threshold_on_death(c)
	_inherit_titles(c)  # Module 4: lordships are hereditary; no heir → escheat
	_epitaph(c)
	for realm in realms:
		if realm.ruler_id == c.id:
			_succession(realm, c)


const STAT_EPITHETS := {"diplomacy": "the Silver-Tongued", "martial": "the Warlike",
	"stewardship": "the Prudent", "intrigue": "the Spider",
	"learning": "the Learned", "prowess": "the Iron-Armed"}


func _epitaph(c: SimCharacter) -> void:
	## Data drives narrative: the dead are remembered by what they were.
	if c.age_years(tick) < ADULT_AGE:
		return
	var notable := false
	for realm: Realm in realms:
		if realm.ruler_id == c.id or realm.council.values().has(c.id):
			notable = true
	for a: Army in armies:
		if a.commander_id == c.id:
			notable = true
	if not notable:
		return
	var best_stat := "diplomacy"
	var best_v := -1
	for key in STAT_PROPS.values():
		if int(c.get(key)) > best_v:
			best_v = int(c.get(key))
			best_stat = key
	var phrase := ""
	for t in c.traits:
		if TraitDB.info(t).eulogy != "":
			phrase = ", " + TraitDB.info(t).eulogy
			break
	_log("[i]%s is remembered as %s%s.[/i]" % [full_name(c), STAT_EPITHETS[best_stat], phrase])


# ---------------------------------------------------------------- succession

func _succession(realm: Realm, dead: SimCharacter) -> void:
	# Administrative government (v1.0, brief §4): the office is not
	# heritable. The Council appoints a Regent and elects — the dead
	# ruler's House keeps its seats and its wealth, never the chair.
	if realm.government == "administrative" and not magister_seats.is_empty():
		_magister_succession(dead)
		return
	realm.interregnum = {}  # a death mid-interregnum resets the clock
	var rescue := false
	var heir := _pick_heir(realm, dead)
	if heir == null:
		# the line is spent — a distant kinsman is found in the provinces
		heir = _spawn(realm, dead.dynasty_id, false, rng.randi_range(22, 40))
		rescue = true
		_log("[b]The line of %s is spent.[/b] A distant kinsman, %s, is found and raised to the throne." % [
			realm.name, full_name(heir)])
	realm.ruler_id = heir.id
	if heir.realm_id != realm.id:
		heir.realm_id = realm.id
		_log("%s returns from abroad to take the crown." % full_name(heir))
	# passed-over siblings do not forget — the ambitious ones nurse a claim
	for sib_id in dead.children_ids:
		var sib: SimCharacter = characters[sib_id]
		if sib.alive and sib.id != heir.id and sib.age_years(tick) >= ADULT_AGE:
			add_memory(sib, "passed over", heir.id, -30.0, 2.0)
			if sib.traits.has("Ambitious") and not sib.bought_off:
				sib.aggrieved = true
	_begin_interregnum(realm, heir, rescue)


# ---------------------------------------------------------------- the Interregnum

func _begin_interregnum(realm: Realm, heir: SimCharacter, rescue: bool) -> void:
	## No one rules at 12:01. The Claimant-Designate must secure the
	## treasury, win a blessing, and take the homage of the houses before
	## the coronation — while rival claimants watch for weakness.
	var rivals := _claimants_against(realm, heir)
	var legit := 40 + heir.diplomacy - 15 * rivals.size()
	if heir.traits.has("Gregarious"):
		legit += 5
	if rescue:
		legit -= 10
	if heir.slandered:
		legit -= 25  # the False Lineage (Module 6): forged pages, remembered now
	realm.interregnum = {"heir": heir.id, "stage": 0, "legitimacy": clampi(legit, 5, 95)}
	var rival_note := ""
	if not rivals.is_empty():
		rival_note = " %s watches the throne with hungry eyes." % full_name(rivals[0])
	_log("[b]Interregnum in %s.[/b] %s stands Claimant-Designate — the crown is not yet won.%s" % [
		realm.name, full_name(heir), rival_note])


func _claimants_against(realm: Realm, heir: SimCharacter) -> Array:
	## Who might rise at the coronation: adult trueborn kinsmen who were
	## passed over or refused a bequest — and were never bought off.
	var out: Array = []
	for c in characters.values():
		if not c.alive or c.id == heir.id or c.realm_id != realm.id:
			continue
		if c.is_bastard or c.disinherited or c.denounced or c.bought_off or c.is_female:
			continue
		if c.age_years(tick) < ADULT_AGE or c.dynasty_id != heir.dynasty_id:
			continue
		var has_claim: bool = c.aggrieved
		for m in c.memories:
			if str(m["type"]) == "passed over":
				has_claim = true
		if has_claim:
			out.append(c)
	out.sort_custom(func(x: SimCharacter, y: SimCharacter) -> bool:
		return x.intrigue + x.martial > y.intrigue + y.martial)
	return out


func _interregnum_tick() -> void:
	for realm: Realm in realms:
		if realm.interregnum.is_empty():
			continue
		var heir: SimCharacter = characters.get(int(realm.interregnum["heir"]))
		if heir == null or not heir.alive or realm.ruler_id != heir.id:
			realm.interregnum = {}  # overtaken by events
			continue
		realm.interregnum["stage"] = int(realm.interregnum["stage"]) + 1
		var legit: int = int(realm.interregnum["legitimacy"])
		match int(realm.interregnum["stage"]):
			1:  # secure the treasury and the capital
				if realm.gold >= 50.0:
					legit += 5
					_log("%s seals the treasury and bars the castle gates." % full_name(heir))
				else:
					legit -= 5
					_log("%s finds the treasury bare — the household troops mutter." % full_name(heir))
			2:  # the blessing
				var speaker := council_member(realm.id, "Lawspeaker")
				if speaker != null:
					legit += maxi(2, int(speaker.learning / 4.0))
					_log("%s reads the omens and blesses the claim of %s." % [full_name(speaker), heir.name])
				else:
					legit -= 5
					_log("No voice of the law blesses %s — the claim rests on steel alone." % full_name(heir))
			3:  # the homage tour
				legit += _homage_tour(realm, heir)
			4:  # the coronation — and whoever means to spoil it
				_coronation(realm, heir, legit)
				continue
		realm.interregnum["legitimacy"] = clampi(legit, 5, 100)


func _homage_tour(realm: Realm, heir: SimCharacter) -> int:
	## The house heads come to swear — or to name their price. A demand
	## is a choice event: the claimant decides, and their traits decide
	## for them when no player is watching.
	var delta := 0
	for dyn: Dynasty in dynasties.values():
		var head := house_head(dyn.id)
		if head == null or head.realm_id != realm.id or head.id == heir.id:
			continue
		if opinion_of(head.id, heir.id) >= 0:
			delta += 4
			continue
		var head_id := head.id
		var realm_ref := realm
		var head_name := full_name(head)
		var house_name := dyn.name
		var options: Array = []
		if realm.gold >= 60.0:
			options.append({"label": "Pay their price (60 gold)",
				"base": 14.0, "ai": {"greed": -0.3, "patience": 0.2},
				"effect": func() -> void:
					realm_ref.gold -= 60.0
					_adjust_legitimacy(realm_ref, 4)
					_log("%s of %s bends the knee — for 60 gold and a promise." % [head_name, house_name])})
		options.append({"label": "Refuse — the crown begs no one",
			"base": 0.0, "ai": {"greed": 0.3, "aggression": 0.3, "patience": -0.2},
			"effect": func() -> void:
				_adjust_legitimacy(realm_ref, -8)
				if characters.has(head_id) and characters[head_id].alive:
					add_memory(characters[head_id], "spurned at the homage", realm_ref.ruler_id, -20.0, 2.0)
				_log("[b]%s of %s withholds the oath.[/b]" % [head_name, house_name])})
		raise_event(realm.id, heir.id, "The Homage Tour",
			"%s of %s kneels — but does not swear. A gift of 60 gold, they murmur, would loosen the oath." % [
				head_name, house_name], options)
	return delta


func _adjust_legitimacy(realm: Realm, amount: int) -> void:
	## Events resolve on their own clock; legitimacy only matters while
	## the interregnum is still open.
	if realm.interregnum.is_empty():
		return
	realm.interregnum["legitimacy"] = clampi(int(realm.interregnum["legitimacy"]) + amount, 5, 100)


func _coronation(realm: Realm, heir: SimCharacter, legit: int) -> void:
	realm.interregnum = {}
	var rivals := _claimants_against(realm, heir)
	if legit < 50 and not rivals.is_empty():
		var rival: SimCharacter = rivals[0]
		var chance := clampf(0.3 + float(50 - legit) * 0.012 + rival.intrigue * 0.01, 0.1, 0.8)
		_log("[b]A palace coup![/b] %s rises at the coronation feast of %s." % [full_name(rival), heir.name])
		if rng.randf() < chance:
			realm.ruler_id = rival.id
			rival.aggrieved = false
			add_memory(heir, "stole my crown", rival.id, -80.0, 0.5)
			add_memory(rival, "stood in my way", heir.id, -30.0, 2.0)
			add_stress(heir, 40.0, "a crown snatched from my head")
			_log("[b]The coup succeeds — %s is crowned in %s's place.[/b]" % [full_name(rival), heir.name])
			return
		if rng.randf() < 0.5:
			_kill(rival, "is hanged for treason after the failed coup —")
		else:
			add_memory(rival, "crushed my rising", heir.id, -60.0, 1.0)
			add_memory(heir, "rose against me", rival.id, -60.0, 1.0)
			_log("The coup is crushed; %s slinks from court, disgraced." % full_name(rival))
		add_stress(heir, 25.0, "knives at my own feast")
	dynasties[root_house_id(heir.dynasty_id)].renown += 25.0
	_log("[b]%s is crowned %s of %s[/b] (legitimacy %d)." % [full_name(heir),
		"Queen" if heir.is_female else "King", str(realm.name).trim_prefix("Kingdom of "), clampi(legit, 5, 100)])


func _pick_heir(realm: Realm, dead: SimCharacter) -> SimCharacter:
	# 1. children of the dead ruler (male-preference primogeniture);
	#    bastards and the disinherited stand outside the line
	var candidates: Array = []
	for cid in dead.children_ids:
		var c: SimCharacter = characters[cid]
		if c.alive and not c.is_bastard and not c.disinherited:
			candidates.append(c)
	if candidates.is_empty():
		# 2. anyone living of the same dynasty
		for c in characters.values():
			if c.alive and c.dynasty_id == dead.dynasty_id and c.id != dead.id \
					and not c.is_bastard and not c.disinherited:
				candidates.append(c)
	if candidates.is_empty():
		# 3. any living adult of the realm
		for c in characters.values():
			if c.alive and c.realm_id == realm.id and c.age_years(tick) >= ADULT_AGE and c.id != dead.id:
				candidates.append(c)
	if candidates.is_empty():
		return null
	# succession law decides the order: male-preference or absolute (eldest child)
	var law: String = realm.succession_law
	candidates.sort_custom(func(x: SimCharacter, y: SimCharacter) -> bool:
		if law == "male" and x.is_female != y.is_female:
			return y.is_female
		return x.birth_tick < y.birth_tick)
	return candidates[0]


func heir_of(realm_id: int) -> SimCharacter:
	## Preview of who would inherit if the current ruler died today.
	var realm: Realm = realms[realm_id]
	if realm.ruler_id < 0:
		return null
	return _pick_heir(realm, characters[realm.ruler_id])


# ---------------------------------------------------------------- economy & war

func _economy() -> void:
	for realm: Realm in realms:
		var law: Dictionary = TAX_LAWS[realm.tax_law]
		var income: float = (2.0 + realm_tax_eff(realm.id)) * float(law["income"])
		if realm.government == "tribal":
			income *= 0.75  # herds and tribute, not ledgers and tolls
		income *= 1.0 + council_stat(realm.id, "Steward") * 0.015
		if realm.ruler_id >= 0:
			var ruler: SimCharacter = characters[realm.ruler_id]
			income *= 1.0 + ruler.stewardship * 0.008
			income *= trait_mult(ruler, "tax_efficiency_mult")  # the Avaricious squeeze harder
			if has_legacy(root_house_id(ruler.dynasty_id), "Golden Ledgers"):
				income *= 1.10
		if trade_pact:
			income += 3.0
			if realm.ruler_id >= 0 and has_legacy(root_house_id(characters[realm.ruler_id].dynasty_id), "The Salt Road Concord"):
				income += 6.0  # the caravans know the house's seal (Magic v1.0)
		if at_war:
			income -= 4.0
		if not realm.interregnum.is_empty():
			income *= 0.6  # vassal taxes wait for a crowned head
		realm.gold += income


func strength(realm_id: int) -> int:
	## Fighting power comes from the standing armies — battle casualties
	## persist, so losing a field battle weakens every month that follows.
	var s := 0.0
	for a: Army in armies:
		if a.realm_id != realm_id:
			continue
		for reg in a.regiments:
			s += float(reg["soldiers"]) * float(UNIT_WEIGHTS[reg["kind"]])
	var realm: Realm = realms[realm_id]
	if realm.ruler_id >= 0:
		s += characters[realm.ruler_id].martial * 2.0
	return int(s)


func army_size(realm_id: int) -> int:
	var total := 0
	for a: Army in armies:
		if a.realm_id == realm_id:
			total += a.size()
	return total


func armies_of(realm_id: int) -> Array:
	var out: Array = []
	for a: Army in armies:
		if a.realm_id == realm_id:
			out.append(a)
	return out


func army_by_id(army_id: int) -> Army:
	for a: Army in armies:
		if a.id == army_id:
			return a
	return null


func levy_capacity(realm_id: int) -> int:
	## Provinces set how many men a realm can keep under arms; tax law
	## trades some of that away, a good Marshal raises it. Under tribal
	## rule the host swells with the ruler's personal fame instead.
	var realm: Realm = realms[realm_id]
	var law: Dictionary = TAX_LAWS[realm.tax_law]
	var cap := realm_levy_eff(realm_id) * float(law["levy"])
	if realm.ruler_id >= 0:
		var ruler: SimCharacter = characters[realm.ruler_id]
		if has_legacy(root_house_id(ruler.dynasty_id), "Blood of the Wolf"):
			cap *= 1.08
		if has_legacy(root_house_id(ruler.dynasty_id), "The Salt Road Concord"):
			cap *= 1.05  # the roads raise men as readily as coin (Magic v1.0)
		if realm.government == "tribal":
			cap += ruler.martial * 6.0 + dynasties[root_house_id(ruler.dynasty_id)].renown / 50.0
	if not realm.interregnum.is_empty():
		cap *= 0.75  # levies are not sworn to an uncrowned claimant
	return int(cap) + council_stat(realm_id, "Marshal") * 4


func _create_army(realm_id: int, pos: Vector2) -> Army:
	var a := Army.new()
	a.id = next_army_id
	next_army_id += 1
	a.realm_id = realm_id
	a.pos = pos
	armies.append(a)
	return a


func _assign_commander(a: Army) -> void:
	## The ruler leads the first army; other armies get the best available
	## martial mind of the realm. Commanders are real dynasty characters.
	var taken := {}
	for other: Army in armies:
		if other != a and other.commander_id >= 0:
			taken[other.commander_id] = true
	var realm: Realm = realms[a.realm_id]
	if realm.ruler_id >= 0 and not taken.has(realm.ruler_id):
		a.commander_id = realm.ruler_id
		return
	var best: SimCharacter = null
	for c in characters.values():
		if not (c.alive and c.realm_id == a.realm_id) or c.denounced or is_cast(c):
			continue  # magisters mind ledgers, not columns (Administrative v1.0)
		if c.age_years(tick) < ADULT_AGE or taken.has(c.id):
			continue
		if hero_wounded(c.id):
			continue  # a hero in recovery does not take a field (Hero System v1.0)
		if best == null or c.martial > best.martial:
			best = c
	a.commander_id = best.id if best != null else -1


func set_commander(army_id: int, char_id: int) -> String:
	## The player picks who leads: any living adult of the realm.
	var a := army_by_id(army_id)
	if a == null:
		return "No such army."
	if not characters.has(char_id):
		return "No such person."
	var c: SimCharacter = characters[char_id]
	if not c.alive or c.realm_id != a.realm_id:
		return "They cannot take this command."
	if c.age_years(tick) < ADULT_AGE:
		return "Too young to lead men to war."
	if c.denounced:
		return "No soldier follows a denounced criminal."
	if hero_wounded(char_id):
		return "%s is still recovering from the last field." % c.name
	for other: Army in armies:
		if other != a and other.commander_id == char_id:
			return "%s already commands another army." % c.name
	if a.commander_id == char_id:
		return ""
	a.commander_id = char_id
	_log("%s takes command of an army of %s." % [full_name(c), realms[a.realm_id].name])
	return ""


func muster_army(realm_id: int) -> Army:
	## New recruits report to the army nearest the realm's heartland.
	var home: Vector2 = map.realm_centroid(realm_id)
	var best: Army = null
	var best_d := INF
	for a: Army in armies:
		if a.realm_id != realm_id:
			continue
		var d := a.pos.distance_squared_to(home)
		if d < best_d:
			best_d = d
			best = a
	if best == null:
		best = _create_army(realm_id, home)
		_assign_commander(best)
	return best


func realm_cultures(realm_id: int) -> Dictionary:
	## The set of province cultures the realm holds — the geography its
	## military identity is anchored to (Roster Design Decision A).
	var out := {}
	for p in map.provinces:
		if p.owner == realm_id:
			out[p.culture] = true
	return out


func recruit_gate(realm_id: int, kind: String) -> String:
	## Cultural availability only ("" = may recruit). Gold and levy
	## limits are checked at muster time, not here.
	if kind != "levy" and int(demilitarized_until.get(realm_id, -1)) > tick:
		return "The treaty of demilitarization bars professional muster — common levies only."
	# Tactical Combat v1.0: the forces the Silence made answer no ordinary muster
	match kind:
		"warden_dead", "caeris_retinue":
			return "These dead are not yours to muster — they rise only under the Ashfields' sky."
		"forsaken_militia":
			# The World the Silence Made v1.1 §8: the militia musters only
			# where the movement has become the region's dominant voice
			var region := forsaken_region_of(realm_id)
			if float(forsaken_movements.get(region, {}).get("strength", 0.0)) >= FORSAKEN_STAGES[3]:
				return ""
			return "No Forsaken movement holds regional dominance — there is no militia to raise."
		"vigil_sworn_elite", "reactionary_chaplain":
			var vr: Realm = realms[realm_id]
			if vr.ruler_id < 0:
				return "The Order of the Vigil-Sworn answers no empty throne."
			var vruler: SimCharacter = characters[vr.ruler_id]
			if faith_of(vruler) != "Aelindran Orthodox" or not vruler.traits.has("Zealous"):
				return "The Order of the Vigil-Sworn answers only a Zealous crown of the old faith."
			return ""
	# The Ward-Speaker Line (Magic v1.0): the craft was taught to the
	# blood itself — the retinues answer this house's muster anywhere
	if kind == "ward_speaker_retinue":
		var wr: Realm = realms[realm_id]
		if wr.ruler_id >= 0 and has_legacy(root_house_id(characters[wr.ruler_id].dynasty_id), "The Ward-Speaker Line"):
			return ""
	var wanted := CultureData.recruit_culture(kind)
	if wanted == "":
		return ""  # the universal roster
	if kind == "compact_sworn" and at_war:
		return "The Compact-Sworn muster only while the border compact holds."
	for culture in realm_cultures(realm_id):
		if CultureData.satisfies(str(culture), wanted):
			return ""
	return "No province of %s culture answers the muster." % CultureData.culture_label(wanted)


func recruit(realm_id: int, kind: String) -> String:
	var realm: Realm = realms[realm_id]
	var gate := recruit_gate(realm_id, kind)
	if gate != "":
		return gate
	var cost: float = RECRUIT_COST[kind]
	if realm.gold < cost:
		return "Not enough gold — %d needed." % int(cost)
	var size_new: int = RECRUIT_SIZE[kind]
	if army_size(realm_id) + size_new > levy_capacity(realm_id):
		return "The levy is exhausted — the provinces can raise no more men."
	realm.gold -= cost
	muster_army(realm_id).regiments.append({"kind": kind, "soldiers": size_new, "max": size_new})
	_log("%s musters a company of %s." % [realm.name, UNIT_LABELS[kind]])
	return ""


func set_army_target(army_id: int, target: Vector2) -> void:
	var a := army_by_id(army_id)
	if a == null:
		return
	if battle_ready and pending_battle.has(army_id):
		return  # an army offered battle cannot slip away
	a.target = target.clamp(Vector2.ZERO, Vector2.ONE)
	a.has_target = true


func split_army(army_id: int) -> String:
	var a := army_by_id(army_id)
	if a == null or a.regiments.size() < 2:
		return "Too few regiments to split."
	if armies_of(a.realm_id).size() >= 3:
		return "Three armies is as much as the realm can command."
	if battle_ready and pending_battle.has(army_id):
		return "Not on the eve of battle."
	var b := _create_army(a.realm_id, a.pos + Vector2(0.035, 0.025))
	var keep: Array = []
	for i in a.regiments.size():
		if i % 2 == 0:
			keep.append(a.regiments[i])
		else:
			b.regiments.append(a.regiments[i])
	a.regiments = keep
	_assign_commander(b)
	_log("%s divides its host into two armies." % realms[a.realm_id].name)
	return ""


func merge_army(army_id: int) -> String:
	var a := army_by_id(army_id)
	if a == null:
		return ""
	for b: Army in armies:
		if b == a or b.realm_id != a.realm_id:
			continue
		if a.pos.distance_to(b.pos) < 0.08:
			a.regiments.append_array(b.regiments)
			armies.erase(b)
			_log("%s joins its armies into one host." % realms[a.realm_id].name)
			return ""
	return "No friendly army close enough to join."


func _military_upkeep() -> void:
	for a: Army in armies:
		# a Methodical commander wastes nothing on the march; elite
		# cultural units cost more per man (Roster stat blocks)
		var mult := 1.0
		if a.commander_id >= 0:
			mult = trait_mult(characters.get(a.commander_id), "supply_consumption_mult")
		var cost_total := 0.0
		for reg in a.regiments:
			cost_total += float(int(reg["soldiers"])) * float(UNIT_UPKEEP.get(reg["kind"], UPKEEP_PER_MAN))
		realms[a.realm_id].gold -= cost_total * mult
	for a: Army in armies:
		if battle_ready and pending_battle.has(a.id):
			continue  # no reinforcements reach an army standing on the field
		if a.severed_months > 0:
			continue  # nothing reaches an army whose wagons burn (Module 7)
		var realm: Realm = realms[a.realm_id]
		var heal_rate := 0.08 + council_stat(a.realm_id, "Marshal") * 0.002
		for reg in a.regiments:
			var missing: int = int(reg["max"]) - int(reg["soldiers"])
			if missing <= 0:
				continue
			var heal := mini(missing, maxi(1, int(int(reg["max"]) * heal_rate)))
			var cost := float(heal) * REPLENISH_COST_PER_MAN
			if realm.gold >= cost:
				realm.gold -= cost
				reg["soldiers"] = int(reg["soldiers"]) + heal


func _ai_recruit() -> void:
	## Sarova (realm 1) manages its own muster; Aldmark is the player's.
	var realm: Realm = realms[1]
	if realm.gold < 700.0 or rng.randf() > 0.25:
		return
	var kinds := ["sword", "levy", "archer", "cav"]
	var kind: String = kinds[rng.randi_range(0, 3)]
	if army_size(1) + int(RECRUIT_SIZE[kind]) <= levy_capacity(1):
		var _err := recruit(1, kind)


func apply_battle_casualties(army_id: int, results: Array, lost_the_battle: bool) -> void:
	## Writes battle survivors back into the army's persistent roster.
	## results: [{index, soldiers, routed}]. Routed units on the losing
	## side are cut down further in the pursuit.
	var a := army_by_id(army_id)
	if a == null:
		return
	var realm: Realm = realms[a.realm_id]
	var before := a.size()
	var new_regs: Array = []
	for res in results:
		var idx: int = res["index"]
		if idx < 0 or idx >= a.regiments.size():
			continue
		var reg: Dictionary = a.regiments[idx]
		var n: int = res["soldiers"]
		if lost_the_battle and bool(res["routed"]):
			n = int(float(n) * 0.75)
		if n > 0:
			new_regs.append({"kind": reg["kind"], "soldiers": n, "max": reg["max"]})
		else:
			_log("The %s of %s are wiped out." % [UNIT_LABELS[reg["kind"]], realm.name])
	a.regiments = new_regs
	var fallen := before - a.size()
	if fallen > 0:
		_log("%s loses %d men on the field." % [realm.name, fallen])
	if a.regiments.is_empty():
		_log("[b]An army of %s is destroyed![/b]" % realm.name)
		armies.erase(a)


func _war_tick() -> void:
	var sa := float(strength(0))
	var sb := float(strength(1))
	# every county under occupation leans on the scales (Module 7)
	var occ_bias := 0.0
	for pid in occupied:
		occ_bias += 0.8 if int(occupied[pid]) == 0 else -0.8
	war_score += 10.0 * (sa - sb) / maxf(sa + sb, 1.0) + occ_bias + rng.randf_range(-2.0, 2.0)
	war_score = clampf(war_score, -100.0, 100.0)
	for realm in realms:
		if rng.randf() < 0.04:
			_skirmish_death(realm)
	if absf(war_score) >= 100.0:
		var _msg := negotiate_peace()  # a decisive score forces the issue


func _skirmish_death(realm: Realm) -> void:
	var men: Array = []
	for c in characters.values():
		if c.alive and not c.is_female and c.realm_id == realm.id \
				and c.age_years(tick) >= ADULT_AGE and not is_cast(c):
			men.append(c)
	if men.is_empty():
		return
	# TODO battle layer: this is the seam where real battles replace
	# abstract skirmishes — the war deals casualties through combat instead.
	_kill(men[rng.randi_range(0, men.size() - 1)], "fell in a border skirmish")


func available_cbs(realm_id: int) -> Array:
	## The Casus Belli system (Module 5): every justification the realm
	## could march under today, best first. Tribal realms always carry
	## Subjugation — raiding needs no lawyers.
	var out: Array = []
	var enemy := 1 - realm_id
	for p in map.provinces:
		if p.owner == enemy and p.de_jure == realm_id:
			out.append("de_jure")
			break
	for root in dispossessed:
		var d: Dictionary = dispossessed[root]
		if int(d["host"]) == realm_id and int(d["home"]) == enemy:
			out.append("restoration")
			break
	var ruler_id: int = realms[realm_id].ruler_id
	if ruler_id >= 0:
		for m in characters[ruler_id].memories:
			if str(m["type"]) in ["invaded my realm", "took my land", "plotted my death", "plotted against my court"]:
				out.append("revenge")
				break
	if fabricated_claims.get(realm_id, false):
		out.append("fabricated")
	if realms[realm_id].government == "tribal":
		out.append("subjugation")
	return out


func hostage_heir_of(realm_id: int) -> SimCharacter:
	## The realm's heir, if a foreign court holds them as collateral.
	var heir := heir_of(realm_id)
	if heir != null and wards.has(heir.id) and bool(wards[heir.id]["hostage"]) \
			and int(wards[heir.id]["home"]) == realm_id:
		return heir
	return null


func declare_war(by_realm: int = 0) -> String:
	if at_war:
		return "The realms are already at war."
	if allied():
		return "A marriage alliance binds the realms. It holds while the couple lives."
	# Collateral hostages (Module 5): an heir in their keep is the whole point
	if not wards.is_empty() and hostage_heir_of(by_realm) != null:
		return "Your heir is a hostage in their court — the sword stays sheathed."
	# The Estate Curia (Module 4): an offensive war needs the landed
	# lords' assent — tribal war-making stays personal.
	if realms[by_realm].government != "tribal":
		var vote := curia_vote(by_realm, "war")
		if not bool(vote["passed"]):
			return "The Curia votes the war down — %s. Sway the lords, or rule without them." % vote["detail"]
	var aggressor: Realm = realms[by_realm]
	var defender: Realm = realms[1 - by_realm]
	# The Casus Belli (Module 5): a war wants a justification. Marching
	# without one — or over a standing truce — is remembered everywhere.
	var cbs := available_cbs(by_realm)
	war_cb = "" if cbs.is_empty() else str(cbs[0])
	if war_cb == "fabricated":
		fabricated_claims.erase(by_realm)  # the forgery is spent when it is sworn
	if war_cb == "":
		aggressor.prestige = maxf(-100.0, aggressor.prestige - 40.0)
		if aggressor.government != "tribal":
			aggressor.tyranny = minf(100.0, aggressor.tyranny + 15.0)
		if defender.ruler_id >= 0 and aggressor.ruler_id >= 0:
			add_memory(characters[defender.ruler_id], "invaded without cause", aggressor.ruler_id, -30.0, 2.0)
	if tick < truce_until:
		aggressor.prestige = maxf(-100.0, aggressor.prestige - 30.0)
		if aggressor.government != "tribal":
			aggressor.tyranny = minf(100.0, aggressor.tyranny + 10.0)
		_log("The ink of the truce is not yet dry — %s breaks its sworn word." % aggressor.name)
	at_war = true
	war_score = 0.0
	war_battles_won = [0, 0]
	war_aggressor = by_realm
	war_start_strength = [strength(0), strength(1)]
	occupied.clear()
	sieges.clear()
	battle_ready = false
	pending_battle = []
	if trade_pact:
		trade_pact = false
		_log("The trade pact is torn up.")
	if aggressor.ruler_id >= 0 and defender.ruler_id >= 0:
		add_memory(characters[defender.ruler_id], "invaded my realm", aggressor.ruler_id, -40.0, 3.0)
		add_memory(characters[aggressor.ruler_id], "my enemy", defender.ruler_id, -20.0, 3.0)
	if aggressor.ruler_id >= 0:
		var r: SimCharacter = characters[aggressor.ruler_id]
		if r.traits.has("Compassionate"):
			add_stress(r, 15.0, "marching others' sons to die")
		if r.traits.has("Content"):
			add_stress(r, 10.0, "the burden of ambition")
	if war_cb == "":
		_log("[b]WAR![/b] %s declares war on %s — without claim or cause, and the world takes note." % [
			aggressor.name, defender.name])
	else:
		_log("[b]WAR![/b] %s declares war on %s, claiming %s." % [
			aggressor.name, defender.name, CB_LABELS[war_cb]])
	# Administrative v1.0 (brief §3): a declaration of war goes before the
	# Council of Magisters. Advisory at v1.0 — the vote is recorded, and a
	# war marched against the Council's judgment is remembered as tyranny.
	if aggressor.government == "administrative" and not magister_seats.is_empty() \
			and aggressor.ruler_id >= 0:
		var mv := magister_vote("declaration of war", aggressor.ruler_id, -1.0)
		if not bool(mv["passed"]):
			aggressor.tyranny = minf(100.0, aggressor.tyranny + 5.0)
			for m in seated_magisters():
				if str(mv["votes"].get(m.id, "")) == "nay":
					add_memory(m, "marched over the Council's nay", aggressor.ruler_id, -15.0, 2.0)
			_log("The Council of Magisters voted the war down, %d to %d — and the Grand Magister marched anyway. The minutes record it." % [
				int(mv["nays"]), int(mv["ayes"])])
	_dissolve_compact_sworn()
	return ""


func fabricate_claim(realm_id: int) -> String:
	## The Lawspeaker's clerks forge the paperwork a clean war needs.
	if not fabrication.is_empty():
		return "The forgers are already at work."
	if fabricated_claims.get(realm_id, false):
		return "A claim already sits sealed in the archive."
	var realm: Realm = realms[realm_id]
	if realm.gold < FABRICATE_COST:
		return "Forgery is skilled work — %d gold." % int(FABRICATE_COST)
	realm.gold -= FABRICATE_COST
	var months := maxi(3, 12 - int(council_stat(realm_id, "Lawspeaker") / 3.0))
	fabrication = {"realm": realm_id, "months_left": months}
	_log("[b]The Lawspeaker's clerks begin their quiet work[/b] — old maps, older seals, and ink aged in smoke.")
	return ""


func _fabricate_tick() -> void:
	if fabrication.is_empty():
		return
	fabrication["months_left"] = int(fabrication["months_left"]) - 1
	if int(fabrication["months_left"]) <= 0:
		fabricated_claims[int(fabrication["realm"])] = true
		fabrication = {}
		_log("[b]The claim is ready[/b] — parchment old enough to pass, and witnesses paid enough to swear.")


func _dissolve_compact_sworn() -> void:
	## The Compact-Sworn are the border compact's practical arm — mixed
	## Drevak/Human companies that disintegrate the moment the compact
	## formally breaks (Cultural Roster v1.0, Karn-Vol entry).
	var dissolved := false
	for a: Army in armies:
		var kept: Array = []
		for reg in a.regiments:
			if str(reg["kind"]) == "compact_sworn":
				dissolved = true
			else:
				kept.append(reg)
		a.regiments = kept
	if dissolved:
		_log("The Compact-Sworn lay down their arms and scatter — the compact they embodied is broken.")


func _ai_diplomacy() -> void:
	## Sarova acts on her ruler's personality: aggressive rulers start wars,
	## timid ones sue for peace when the tide turns against them.
	var ruler_id: int = realms[1].ruler_id
	if ruler_id < 0:
		return
	var ruler: SimCharacter = characters[ruler_id]
	var aggression := ai_weight(ruler, "aggression")
	if realms[1].government == "tribal":
		aggression += 15.0  # raiding is the tribal way of life
	if not at_war:
		if allied() or trade_pact:
			return
		if tick < truce_until:
			return  # even Karn-Vol honors sworn iron — mostly
		if not wards.is_empty() and hostage_heir_of(1) != null:
			return  # their heir in Vael's keeping stays the axe
		if strength(1) < int(strength(0) * 0.9):
			return  # even the Wrathful wait until the odds are fair
		# a prestigious crown is a daunting target (Module 5)
		var chance := clampf(0.004 + aggression * 0.0002 - realms[0].prestige * 0.0002, 0.0, 0.03)
		if rng.randf() < chance:
			var _e := declare_war(1)
	elif war_score > 55.0 and not battle_ready:
		var chance := clampf(0.15 - aggression * 0.001, 0.02, 0.3)
		if rng.randf() < chance:
			var _e2 := negotiate_peace()


func negotiate_peace() -> String:
	if not at_war:
		return "The realms are at peace."
	if absf(war_score) > 40.0:
		var winner: Realm = realms[0] if war_score > 0.0 else realms[1]
		var loser: Realm = realms[1] if war_score > 0.0 else realms[0]
		# War Leverage (Module 5): the score, the battles carried, and the
		# winner's standing set what can be dictated at the table.
		var leverage := absf(war_score) + 10.0 * float(war_battles_won[winner.id]) + winner.prestige * 0.2
		# every county held under the sword is an argument at the table (Module 7)
		last_war_occupied = []
		for pid in occupied:
			if int(occupied[pid]) == winner.id:
				last_war_occupied.append(int(pid))
		leverage += 5.0 * float(last_war_occupied.size())
		winner.prestige = minf(100.0, winner.prestige + 15.0)
		loser.prestige = maxf(-100.0, loser.prestige - 10.0)
		_log("[b]Peace.[/b] %s comes to the drafting table with %d leverage over %s." % [
			winner.name, int(leverage), loser.name])
		_raise_treaty(winner, loser, leverage)
		if winner.ruler_id >= 0:
			award_hero_xp(winner.ruler_id, HeroDB.XP_AWARDS["peace_treaty"], "a war ended on their terms")
	else:
		_log("[b]White peace.[/b] The war ends with nothing gained.")
	_end_war()
	return ""


func _end_war() -> void:
	at_war = false
	war_score = 0.0
	war_cb = ""
	war_aggressor = -1
	battle_ready = false
	pending_battle = []
	truce_until = tick + TRUCE_MONTHS
	if not occupied.is_empty():
		occupied.clear()
		_log("The armies of occupation march home — the counties they held return to their crowns.")
	sieges.clear()
	partisans.clear()  # the cells disband; the scorched fields stay scorched
	for a: Army in armies:
		a.target = map.realm_centroid(a.realm_id)
		a.has_target = a.pos.distance_to(a.target) > 0.02
		a.train_active = false
		a.severed_months = 0
	_demobilization()


# ------------------------------------------- the treaty drafting table (Module 5)

func _raise_treaty(winner: Realm, loser: Realm, leverage: float) -> void:
	## No binary war conclusion: the winner drafts the peace from a menu
	## of terms, gated by the leverage the war actually earned.
	var options: Array = []
	options.append({"label": "A magnanimous peace — ask nothing, and be remembered for it",
		"base": 2.0, "ai": {"aggression": -0.6, "greed": -0.4},
		"effect": func() -> void: _term_magnanimous(winner, loser)})
	options.append({"label": "Tribute — gold to the victor's chests",
		"base": 4.0, "ai": {"greed": 0.8},
		"effect": func() -> void: _term_tribute(winner, loser, leverage * 1.2)})
	# a lawful claim makes taking land cheaper at the table
	var cede_cost := 35.0 if (war_cb == "de_jure" or war_cb == "fabricated") else 50.0
	if leverage >= cede_cost:
		options.append({"label": "Cession — a border province changes hands",
			"base": 5.0, "ai": {"aggression": 0.7},
			"effect": func() -> void: _term_cede(winner, loser)})
	if leverage >= 60.0:
		options.append({"label": "The Yoke — a decade of reparations, and demilitarization",
			"base": 4.0, "ai": {"patience": 0.5, "greed": 0.5},
			"effect": func() -> void: _term_yoke(winner, loser)})
	if leverage >= 45.0 and heir_of(loser.id) != null and not wards.has(heir_of(loser.id).id):
		options.append({"label": "Collateral — their heir, a permanent ward at your court",
			"base": 3.0, "ai": {"scheming": 0.8},
			"effect": func() -> void: _term_hostage(winner, loser)})
	if leverage >= 75.0:
		options.append({"label": "Salt the earth — return the land, ruined for a generation",
			"base": 1.0, "ai": {"aggression": 1.0},
			"effect": func() -> void: _term_salt(winner, loser)})
	if war_cb == "restoration":
		options.append({"label": "Restoration — the exiled house takes back its halls",
			"base": 8.0, "ai": {},
			"effect": func() -> void: _term_restore(winner, loser)})
	raise_event(winner.id, winner.ruler_id, "The Drafting Table",
		"%s dictates the peace. War leverage: %d. What the treaty takes now, the next twenty years will answer for." % [
			winner.name, int(leverage)], options)


func _term_magnanimous(winner: Realm, loser: Realm) -> void:
	winner.prestige = minf(100.0, winner.prestige + 20.0)
	if loser.ruler_id >= 0 and winner.ruler_id >= 0:
		add_memory(characters[loser.ruler_id], "a generous peace", winner.ruler_id, 30.0, 1.5)
	_log("[b]%s asks nothing.[/b] The chronicles will remember the mercy longer than the war." % winner.name)


func _term_tribute(winner: Realm, loser: Realm, amount: float) -> void:
	var tribute := minf(amount, maxf(loser.gold, 0.0))
	loser.gold -= tribute
	winner.gold += tribute
	_log("[b]%s yields %d gold in tribute to %s.[/b]" % [loser.name, int(tribute), winner.name])


func _term_cede(winner: Realm, loser: Realm) -> void:
	_term_tribute(winner, loser, 40.0)
	_cede_border_province(winner, loser)


func _term_yoke(winner: Realm, loser: Realm) -> void:
	reparations = {"from": loser.id, "to": winner.id, "months_left": REPARATIONS_MONTHS}
	demilitarized_until[loser.id] = tick + DEMILITARIZED_MONTHS
	_log("[b]The yoke:[/b] %s pays reparations for ten years and may muster only common levies." % loser.name)


func _term_hostage(winner: Realm, loser: Realm) -> void:
	var h := heir_of(loser.id)
	if h == null or wards.has(h.id):
		_term_tribute(winner, loser, 40.0)  # the heir slipped the net; take gold instead
		return
	var _e := send_ward(h.id, winner.id, true)


func _term_salt(winner: Realm, loser: Realm) -> void:
	var options: Array = []
	for p in map.provinces:
		if p.owner != loser.id:
			continue
		for nid in p.neighbors:
			if map.provinces[nid].owner == winner.id:
				options.append(p)
				break
	if options.is_empty():
		_term_tribute(winner, loser, 60.0)
		return
	var p2 = options[rng.randi_range(0, options.size() - 1)]
	salted[p2.id] = tick + SALT_MONTHS
	_log("[b]%s is salted[/b] — granaries burned, walls pulled down, wells fouled. A generation will pass before it matters again." % p2.name)


func _term_restore(winner: Realm, loser: Realm) -> void:
	## The Foreign Proxy War pays off: the house-in-exile is reinstated on
	## its old land, sworn to the loser's crown but owing everything to the
	## winner's — a knife left in the treaty.
	for root in dispossessed.keys():
		var d: Dictionary = dispossessed[root]
		if int(d["host"]) != winner.id or int(d["home"]) != loser.id:
			continue
		var exiles: Array = []
		for c in characters.values():
			if c.alive and root_house_id(c.dynasty_id) == int(root) and c.age_years(tick) >= ADULT_AGE:
				exiles.append(c)
		exiles.sort_custom(func(x: SimCharacter, y: SimCharacter) -> bool: return x.birth_tick < y.birth_tick)
		var granted := 0
		for c in characters.values():
			if c.alive and root_house_id(c.dynasty_id) == int(root):
				c.realm_id = loser.id  # the whole house comes home
		for e: SimCharacter in exiles:
			if granted >= 2:
				break
			for p in map.provinces:
				if p.owner == loser.id and county_holder(p.id) == null:
					county_holders[p.id] = e.id
					var _contract := contract_of(e.id)  # opens the feudal contract
					if winner.ruler_id >= 0:
						add_memory(e, "restored us to our halls", winner.ruler_id, 60.0, 2.0)
					_log("[b]%s is restored to %s[/b] — the exile ends at sword-point." % [full_name(e), p.name])
					granted += 1
					break
		dispossessed.erase(root)
		winner.prestige = minf(100.0, winner.prestige + 15.0)
		return
	_term_tribute(winner, loser, 40.0)  # no exiles left to restore


func _campaign_military() -> void:
	## Commanders are kept current, AI armies get orders, armies march,
	## and hostile armies that meet lock into a pending battle.
	for a: Army in armies:
		if a.commander_id >= 0:
			var c: SimCharacter = characters.get(a.commander_id)
			if c == null or not c.alive or c.realm_id != a.realm_id:
				a.commander_id = -1
		if a.commander_id < 0:
			_assign_commander(a)
	_ai_army_orders()
	if battle_ready:
		return
	for a: Army in armies:
		if not a.has_target:
			continue
		var step := 0.10
		if a.pos.distance_to(a.target) <= step:
			a.pos = a.target
			a.has_target = false
		else:
			a.pos += (a.target - a.pos).normalized() * step
	if not at_war:
		return
	for a: Army in armies:
		if a.realm_id != 0 or a.regiments.is_empty():
			continue
		for b: Army in armies:
			if b.realm_id != 1 or b.regiments.is_empty():
				continue
			if a.pos.distance_to(b.pos) < 0.05:
				# a hopeless mismatch is not a battle, it is an overrun
				if a.size() >= b.size() * 4:
					_overrun(a, b)
					return
				if b.size() >= a.size() * 4:
					_overrun(b, a)
					return
				battle_ready = true
				pending_battle = [a.id, b.id]
				_log("[b]The armies meet near %s. Battle must be joined![/b]" % battle_site_name())
				return


func _overrun(winner_army: Army, victim: Army) -> void:
	var victim_realm: Realm = realms[victim.realm_id]
	_log("[b]The army of %s is ridden down near %s — no battle, only slaughter.[/b]" % [
		victim_realm.name, _site_name_at(victim.pos)])
	_commander_fate(victim, winner_army, false, 1.0, _site_name_at(victim.pos))
	_champion_fates(victim, winner_army, false, 1.0, _site_name_at(victim.pos))
	armies.erase(victim)
	war_score += 15.0 if winner_army.realm_id == 0 else -15.0
	war_score = clampf(war_score, -100.0, 100.0)
	war_battles_won[winner_army.realm_id] += 1
	if absf(war_score) >= 100.0:
		var _msg := negotiate_peace()


func _ai_army_orders() -> void:
	## Sarova's armies march themselves: at the nearest enemy army in war,
	## home to the heartland in peace.
	for a: Army in armies:
		if a.realm_id != 1:
			continue
		if at_war:
			var best: Army = null
			var best_d := INF
			for e: Army in armies:
				if e.realm_id != 0 or e.regiments.is_empty():
					continue
				var d := a.pos.distance_squared_to(e.pos)
				if d < best_d:
					best_d = d
					best = e
			if best != null:
				a.target = best.pos
				a.has_target = true
			else:
				# no field army left to fight — march on the nearest county
				# still flying the enemy's banner and starve its walls
				var siege_target: Vector2 = a.target
				var sd := INF
				for p in map.provinces:
					if p.owner != 0 or int(occupied.get(p.id, -1)) == 1:
						continue
					var pd: float = p.center.distance_squared_to(a.pos)
					if pd < sd:
						sd = pd
						siege_target = p.center
				if sd < INF:
					a.target = siege_target
					a.has_target = a.pos.distance_to(a.target) > 0.01
		elif not free_companies.is_empty():
			# in peace, loose swords on the roads are hunted down
			var quarry: Army = null
			var quarry_d := INF
			for fc: Army in free_companies:
				var fd := a.pos.distance_squared_to(fc.pos)
				if fd < quarry_d:
					quarry_d = fd
					quarry = fc
			if quarry != null:
				a.target = quarry.pos
				a.has_target = true
		elif not a.has_target:
			a.target = map.realm_centroid(1)
			a.has_target = a.pos.distance_to(a.target) > 0.02


func _intrigue_detection_bonus(realm_id: int) -> int:
	for a: Army in armies:
		if a.realm_id != realm_id:
			continue
		for reg in a.regiments:
			if str(reg["kind"]) == "trade_guard":
				return 15
	return 0


func battle_site_name() -> String:
	var target: Vector2 = map.frontier_midpoint()
	if pending_battle.size() == 2:
		var a := army_by_id(pending_battle[0])
		var b := army_by_id(pending_battle[1])
		if a != null and b != null:
			target = (a.pos + b.pos) * 0.5
	return _site_name_at(target)


func battle_site_terrain() -> String:
	## Terrain of the province the pending battle is fought in — forest
	## and coast wake the cultural units' terrain bonuses (Roster v1.0).
	var target: Vector2 = map.frontier_midpoint()
	if pending_battle.size() == 2:
		var a := army_by_id(pending_battle[0])
		var b := army_by_id(pending_battle[1])
		if a != null and b != null:
			target = (a.pos + b.pos) * 0.5
	var best_terrain := "plains"
	var best_d := INF
	for p in map.provinces:
		var d: float = p.center.distance_squared_to(target)
		if d < best_d:
			best_d = d
			best_terrain = p.terrain
	return best_terrain


func battle_site_ground() -> Dictionary:
	## The battle province's theology (Tactical Combat v1.0): the binary
	## casting gates read whether the ground is silence-touched or ruined,
	## and whether the Iron Library or the ward-stones stand near enough
	## to hold a little of the sky up.
	var target: Vector2 = map.frontier_midpoint()
	if pending_battle.size() == 2:
		var a := army_by_id(pending_battle[0])
		var b := army_by_id(pending_battle[1])
		if a != null and b != null:
			target = (a.pos + b.pos) * 0.5
	var best = null
	var best_d := INF
	for p in map.provinces:
		var d: float = p.center.distance_squared_to(target)
		if d < best_d:
			best_d = d
			best = p
	if best == null:
		return {}
	return {"silence": best.silence_touched, "ruined": best.ruined,
		"special": str(best.special_feature)}


func _site_name_at(target: Vector2) -> String:
	var best_name := "the frontier"
	var best_d := INF
	for p in map.provinces:
		var d: float = p.center.distance_squared_to(target)
		if d < best_d:
			best_d = d
			best_name = p.name
	return best_name


func apply_battle_result(winner_side: int, loser_loss_fraction: float, charged: Array = [false, false], cmdr_corruption: Array = [0.0, 0.0], cmdr_stress: Array = [0.0, 0.0]) -> void:
	## Feeds a fought battle back into the war: the score swings, the
	## beaten army retreats home, and either commander may not come back.
	var site := battle_site_name()
	var pa: Army = army_by_id(pending_battle[0]) if pending_battle.size() == 2 else null
	var pb: Army = army_by_id(pending_battle[1]) if pending_battle.size() == 2 else null
	battle_ready = false
	pending_battle = []
	if winner_side < 0:
		_log("[b]The Battle of %s ends in mutual ruin.[/b]" % site)
	else:
		var swing := 20.0 + 30.0 * clampf(loser_loss_fraction, 0.0, 1.0)
		war_score += swing if winner_side == 0 else -swing
		war_score = clampf(war_score, -100.0, 100.0)
		war_battles_won[winner_side] += 1  # every field won is leverage at the table
		_log("[b]The Battle of %s![/b] %s carries the field." % [site, realms[winner_side].name])
		var loser_army: Army = pb if winner_side == 0 else pa
		if loser_army != null and army_by_id(loser_army.id) != null:
			loser_army.target = map.realm_centroid(loser_army.realm_id)
			loser_army.has_target = true
	# what the field cost each commander's ledger (Magic v1.0) and nerve
	# (Tactical Combat v1.0: the workings ask, answered or not)
	for i in 2:
		var host: Army = pa if i == 0 else pb
		if host == null or host.commander_id < 0:
			continue
		var cmdr: SimCharacter = characters.get(host.commander_id)
		if cmdr == null or not cmdr.alive:
			continue
		if float(cmdr_corruption[i]) > 0.0:
			add_corruption(cmdr, float(cmdr_corruption[i]), "what was channeled at %s" % site)
		if float(cmdr_stress[i]) > 0.0:
			add_stress(cmdr, float(cmdr_stress[i]), "what the field asked of the sky at %s" % site)
	# Canon Pass Two §1.2: the field's dead, if nobody buries them, become
	# vacancy — five thousand dead unburied is five thousand reasons for
	# an anchor. A ledger write only; bury_the_dead() is the player's answer.
	var field_p = _province_at(pa.pos) if pa != null else (_province_at(pb.pos) if pb != null else null)
	if field_p != null and not field_p.silence_touched:
		var fallen := int(120.0 + 240.0 * clampf(loser_loss_fraction, 0.0, 1.0))
		var rec: Dictionary = unburied_fields.get(field_p.id, {"dead": 0, "tick": tick})
		rec["dead"] = int(rec["dead"]) + fallen
		rec["tick"] = tick
		unburied_fields[field_p.id] = rec
	_commander_fate(pa, pb, winner_side == 0, loser_loss_fraction, site, bool(charged[0]))
	_commander_fate(pb, pa, winner_side == 1, loser_loss_fraction, site, bool(charged[1]))
	_champion_fates(pa, pb, winner_side == 0, loser_loss_fraction, site)
	_champion_fates(pb, pa, winner_side == 1, loser_loss_fraction, site)
	# hero-tier commanders bank the field (Hero System v1.0 §3). These
	# battles reach here only through the player's battle panel — the
	# award moves stats (by_hand) exactly because a hand moved it.
	for i in 2:
		var host2: Army = pa if i == 0 else pb
		if host2 == null or host2.commander_id < 0:
			continue
		var cmdr2: SimCharacter = characters.get(host2.commander_id)
		if cmdr2 == null or not cmdr2.alive or cmdr2.hero_level <= 0:
			continue
		var xp2: int = HeroDB.XP_AWARDS["battle_survived"]
		if winner_side == i:
			xp2 += int(HeroDB.XP_AWARDS["battle_victory"])
		award_hero_xp(cmdr2.id, xp2, "the Battle of %s" % site, true)
	if absf(war_score) >= 100.0:
		var _msg := negotiate_peace()


func _commander_fate(a: Army, enemy: Army, won: bool, loss: float, site: String, charged: bool = false) -> void:
	## Leading from the front has a price — Prowess is what keeps you alive
	## in the press. The beaten may fall, be scarred, and never forgive.
	if a == null or a.commander_id < 0:
		return
	var c: SimCharacter = characters.get(a.commander_id)
	if c == null or not c.alive:
		return
	if c.hero_level > 0:
		return  # a hero's fate was decided on the field itself — personal
		        # HP and death saves, not the abstract roll (Hero System v1.0)
	var chance := 0.04
	if not won:
		chance = 0.15 + 0.20 * clampf(loss, 0.0, 1.0)
	chance *= clampf(1.4 - c.prowess * 0.03, 0.5, 1.4)
	chance *= trait_mult(c, "commander_risk_mult")  # the Impulsive lead from the front
	if charged:
		chance *= 1.8  # a chivalric charge is glory bought on credit (Module 7)
	if rng.randf() < chance:
		_kill(c, "fell leading the army at %s," % site)
		return
	var foe_id := -1
	if enemy != null and enemy.commander_id >= 0:
		foe_id = enemy.commander_id
	if won:
		add_stress(c, -10.0, "victory")
	else:
		add_stress(c, 25.0, "defeat in the field")
		if foe_id >= 0:
			add_memory(c, "defeated me in battle", foe_id, -25.0, 2.0)
		if rng.randf() < 0.25:
			_add_trait(c, "Wounded")
			if c.traits.has("Wounded"):
				_log("%s is carried from the field at %s, badly wounded." % [full_name(c), site])


# ------------------------------------------- warfare: supply, sieges, fire (Module 7)

func province_supply(p, realm_id: int) -> int:
	## The Supply Limit: how many soldiers this county can feed in a month.
	## Terrain sets the ceiling, home granaries raise it, salt thins it —
	## and scorched fields feed no one at all.
	if int(scorched.get(p.id, -1)) > tick:
		return 0
	var s := float(SUPPLY_BY_TERRAIN.get(p.terrain, 300))
	if int(salted.get(p.id, -1)) > tick:
		s *= SALT_YIELD
	if p.owner == realm_id and int(occupied.get(p.id, -1)) < 0:
		s *= SUPPLY_HOME_MULT
	return int(s)


func is_winter() -> bool:
	return (tick % 12) in [11, 0, 1]  # the campaign season is long over


func army_supply_report(a: Army) -> Dictionary:
	## What the army lives on where it stands — the monthly tick and the
	## UI read the same arithmetic.
	var p = _province_at(a.pos)
	var limit := province_supply(p, a.realm_id)
	var foreign: bool = p != null and p.owner == 1 - a.realm_id
	return {"province": p, "limit": limit, "foreign": foreign,
		"over": maxi(0, a.size() - limit)}


func _warfare_tick() -> void:
	## Module 7's monthly grind: wagons, hunger, siege lines, and fire.
	## The dice stay untouched unless a siege is actually being pressed.
	for pid in scorched.keys():
		if int(scorched[pid]) <= tick:
			scorched.erase(pid)
			partisans.erase(pid)
			_log("The first green shoots return to %s — the burned years are over." % map.provinces[pid].name)
	if armies.is_empty():
		return
	for a: Army in armies.duplicate():
		if battle_ready and pending_battle.has(a.id):
			continue  # an army drawn up for battle stands on its last full ration
		_army_supply_tick(a)
	if at_war and not battle_ready:
		_ai_scorch()
		_sieges_tick()


func _army_supply_tick(a: Army) -> void:
	var rep := army_supply_report(a)
	var p = rep["province"]
	# The Baggage Train: the moment an army stands on foreign soil, its
	# wagons trail behind it on the road home — a physical thing on the
	# map, and the campaign's softest target.
	a.train_active = at_war and bool(rep["foreign"])
	var severed := false
	if a.train_active:
		var home: Vector2 = map.realm_centroid(a.realm_id)
		var best_d := INF
		for fp in map.provinces:
			if fp.owner == a.realm_id and int(occupied.get(fp.id, -1)) < 0:
				var d: float = fp.center.distance_squared_to(a.pos)
				if d < best_d:
					best_d = d
					home = fp.center
		var back := home - a.pos
		a.train_pos = a.pos + (back.normalized() * minf(0.06, back.length() * 0.5) if back.length() > 0.001 else Vector2.ZERO)
		# the Line of Communication: an enemy on the wagons — or partisan
		# cells in the county — and the army eats its own boots
		for e: Army in armies:
			if e.realm_id == 1 - a.realm_id and not e.regiments.is_empty() \
					and e.pos.distance_to(a.train_pos) < BAGGAGE_RAID_RANGE:
				severed = true
				break
		if p != null and int(partisans.get(p.id, -1)) == 1 - a.realm_id:
			severed = true  # night raids out of the burned hills
	if severed:
		a.severed_months += 1
		if a.severed_months == 1:
			_log("[b]The supply line of %s is severed![/b] The wagons burn on the road, and the host stops eating." % realms[a.realm_id].name)
	else:
		a.severed_months = 0
	# starvation attrition: compounding, doubled by winter on foreign soil.
	# On its own intact soil the realm's granary network feeds any host —
	# the Supply Limit bites abroad, under occupation, or on ruined ground.
	var home_fed: bool = p != null and p.owner == a.realm_id \
			and int(occupied.get(p.id, -1)) < 0 \
			and int(scorched.get(p.id, -1)) <= tick and int(salted.get(p.id, -1)) <= tick
	var frac := 0.0
	var limit: int = rep["limit"]
	if int(rep["over"]) > 0 and not home_fed:
		frac += clampf(0.02 + 0.04 * (float(a.size()) / maxf(float(limit), 1.0) - 1.0), 0.02, ATTRITION_MAX)
	if a.severed_months > 0:
		frac += SEVERED_ATTRITION + 0.01 * float(a.severed_months - 1)
	if frac <= 0.0:
		return
	if is_winter() and bool(rep["foreign"]):
		frac *= 2.0  # the Winter Trap
	frac = minf(frac, ATTRITION_MAX * 2.0)
	var before := a.size()
	for reg in a.regiments:
		reg["soldiers"] = maxi(0, int(reg["soldiers"]) - maxi(1, int(float(int(reg["soldiers"])) * frac)))
	a.regiments = a.regiments.filter(func(r) -> bool: return int(r["soldiers"]) > 0)
	var lost := before - a.size()
	if lost > 0 and (a.severed_months == 1 or tick % 3 == 0):
		var where := str(p.name) if p != null else "the field"
		_log("Hunger stalks the camp of %s at %s — %d men lost to the empty roads." % [
			realms[a.realm_id].name, where, lost])
	if a.regiments.is_empty():
		_log("[b]The army of %s starves to nothing[/b] — no battle, no glory, only the crows." % realms[a.realm_id].name)
		armies.erase(a)


func fort_level(p) -> int:
	## How long a county can shut its gates: the high places hold longest,
	## seats of power and storied sites are walled to match.
	var f := 0
	if p.terrain == "mountain":
		f += 2
	elif p.terrain == "hills":
		f += 1
	if str(p.special_feature) != "":
		f += 1
	if p.owner >= 0 and p.owner < map.realms.size() \
			and map.realms[p.owner].capital_province_id == p.id:
		f += 2
	return f


func _sieges_tick() -> void:
	## Sieges & Strongholds: an army encamped on an enemy county, with no
	## field army near enough to contest it, settles in to starve the walls.
	var pressed := {}
	for a: Army in armies:
		if a.regiments.is_empty() or a.realm_id < 0:
			continue
		var p = _province_at(a.pos)
		if p == null or p.owner != 1 - a.realm_id:
			continue
		if int(occupied.get(p.id, -1)) == a.realm_id:
			continue  # the banner already flies over the keep
		var contested := false
		for e: Army in armies:
			if e.realm_id == 1 - a.realm_id and not e.regiments.is_empty() \
					and e.pos.distance_to(a.pos) < 0.07:
				contested = true
				break
		if contested:
			continue
		if int(partisans.get(p.id, -1)) == p.owner:
			pressed[p.id] = true  # the siege stands, but makes no progress
			continue  # partisan night raids burn the works as fast as they rise
		if not sieges.has(p.id):
			sieges[p.id] = {"attacker": a.realm_id, "progress": 0.0,
				"threshold": SIEGE_THRESHOLD_BASE + float(fort_level(p)) * SIEGE_FORT_STEP}
			_log("[b]%s lays siege to %s[/b] — the gates shut, and the waiting begins." % [
				realms[a.realm_id].name, p.name])
		var s: Dictionary = sieges[p.id]
		if int(s["attacker"]) != a.realm_id:
			continue
		pressed[p.id] = true
		var gain := SIEGE_BASE_PROGRESS + council_stat(a.realm_id, "Marshal") * 0.5
		# the recurring siege event timer: breaches and camp fevers
		var roll := rng.randf()
		if roll < 0.10:
			gain += 15.0
			_log("A section of %s's wall comes down in the night — the breach is made." % p.name)
		elif roll < 0.22:
			for reg in a.regiments:
				reg["soldiers"] = maxi(1, int(float(int(reg["soldiers"])) * 0.96))
			_log("Camp fever spreads through the siege lines at %s — the latrines kill more than the garrison does." % p.name)
		s["progress"] = float(s["progress"]) + gain
		if float(s["progress"]) >= float(s["threshold"]):
			sieges.erase(p.id)
			occupied[p.id] = a.realm_id
			war_score = clampf(war_score + (10.0 if a.realm_id == 0 else -10.0), -100.0, 100.0)
			_log("[b]%s falls to %s![/b] The gates open — to hunger, not to storm." % [
				p.name, realms[a.realm_id].name])
	for pid in sieges.keys():
		if not pressed.has(pid):
			sieges.erase(pid)
			_log("The siege of %s is abandoned — the garrison sallies out to reopen the roads." % map.provinces[pid].name)


func scorch_earth(realm_id: int, pid: int) -> String:
	## The Scorched Earth Protocol (defensive wars only): burn your own
	## crops and foul your own wells on your own rightful soil. The county
	## feeds no invader — and its peasants take to the hills as partisans.
	if not at_war:
		return "Scorched earth is a measure of war."
	if war_aggressor == realm_id:
		return "The protocol is a defender's desperation — and you marched first."
	if pid < 0 or pid >= map.provinces.size():
		return "No such county."
	var p = map.provinces[pid]
	if p.owner != realm_id:
		return "Not your county to burn."
	if p.de_jure != realm_id:
		return "The people here fly older banners — they will not burn their fields for your war."
	if int(scorched.get(pid, -1)) > tick:
		return "Nothing is left there to burn."
	scorched[pid] = tick + SCORCH_MONTHS
	partisans[pid] = realm_id
	sieges.erase(pid)
	_log("[b]The Scorched Earth Protocol:[/b] %s burns its own crops at %s and fouls the wells. The county will feed no invader — and its people melt into the hills with knives." % [
		realms[realm_id].name, p.name])
	return ""


func _ai_scorch() -> void:
	## Karn-Vol will burn its own fields before it feeds an invader:
	## when Vael's armies stand on clan soil, the frontier goes up.
	if war_aggressor != 0:
		return
	for a: Army in armies:
		if a.realm_id != 0 or a.regiments.is_empty():
			continue
		var p = _province_at(a.pos)
		if p == null or p.owner != 1 or p.de_jure != 1:
			continue
		if int(scorched.get(p.id, -1)) > tick:
			continue
		if rng.randf() < 0.35:
			var _e := scorch_earth(1, p.id)
		return  # one county considered a month — the clan argues about the rest


# ------------------------------------------- knights & champions (Module 7)

func main_army_of(realm_id: int) -> Army:
	var best: Army = null
	for a: Army in armies:
		if a.realm_id == realm_id and (best == null or a.size() > best.size()):
			best = a
	return best


func champions_of(realm_id: int) -> Array:
	## The realm's named blades: its highest-Prowess adults after the
	## commanders are seated. They ride with the main host, trading their
	## lives' risk for the steadiness their names lend the line.
	var taken := {}
	for a: Army in armies:
		if a.commander_id >= 0:
			taken[a.commander_id] = true
	var pool: Array = []
	for c in characters.values():
		if c.alive and c.realm_id == realm_id and not c.denounced \
				and c.age_years(tick) >= ADULT_AGE and not taken.has(c.id) \
				and not wards.has(c.id) and not is_cast(c):
			pool.append(c)
	pool.sort_custom(func(x: SimCharacter, y: SimCharacter) -> bool:
		return x.prowess > y.prowess if x.prowess != y.prowess else x.id < y.id)
	return pool.slice(0, CHAMPION_COUNT)


func champions_with(a: Army) -> Array:
	if a == null or a != main_army_of(a.realm_id):
		return []
	return champions_of(a.realm_id)


func battle_lead_mod(a: Army) -> int:
	## What the campaign adds to — or starves from — an army's leadership
	## on the field: champions steady it, a severed train hollows it, and
	## a defender ambushing a bled invader in burned or high country owns
	## the ground it chose.
	if a == null:
		return 0
	var mod := 0.0
	for c: SimCharacter in champions_with(a):
		mod += float(c.prowess) / CHAMPION_LEAD_DIV
	mod -= float(a.severed_months) * 2.0
	if at_war and war_aggressor == 1 - a.realm_id and war_aggressor >= 0:
		var enemy_bled := float(strength(1 - a.realm_id)) < float(war_start_strength[1 - a.realm_id]) * 0.5
		var p = _province_at(a.pos)
		if enemy_bled and p != null and (p.terrain == "mountain" or int(scorched.get(p.id, -1)) > tick):
			mod += 8.0  # Phase 4: strike the exhausted host on ground of your choosing
	return int(mod)


func _champion_fates(a: Army, enemy: Army, won: bool, loss: float, site: String) -> void:
	## Champions enter the melee in person: death, wounds, or a lost
	## field's worst dishonor — taken alive, a hostage in the enemy's keep.
	if a == null:
		return
	for c: SimCharacter in champions_with(a):
		var chance := 0.03 if won else 0.10 + 0.10 * clampf(loss, 0.0, 1.0)
		chance *= clampf(1.5 - c.prowess * 0.03, 0.5, 1.5)
		if rng.randf() >= chance:
			continue
		var fate := rng.randf()
		if fate < 0.35:
			_kill(c, "fell championing the host at %s," % site)
		elif fate < 0.65 or won or enemy == null:
			_add_trait(c, "Wounded")
			_log("%s, champion of the host, is dragged from the press at %s — alive, barely." % [full_name(c), site])
		else:
			var captor := enemy.realm_id
			wards[c.id] = {"home": a.realm_id, "host": captor, "guardian": realms[captor].ruler_id,
				"hostage": true, "since": tick, "of_age": true}
			c.realm_id = captor
			_log("[b]%s is taken alive at %s[/b] — a champion in chains, awaiting ransom." % [full_name(c), site])


func _cede_border_province(winner: Realm, loser: Realm) -> void:
	var options: Array = []
	for p in map.provinces:
		if p.owner != loser.id:
			continue
		# a Marcher Lord's fortified county is never given away in a peace
		var lord := county_holder(p.id)
		if lord != null and has_privilege(lord.id, "marcher_lord"):
			continue
		for nid in p.neighbors:
			if map.provinces[nid].owner == winner.id:
				options.append(p)
				break
	# land already held under the sword changes hands first (Module 7)
	var occupied_options: Array = options.filter(func(p) -> bool:
		return last_war_occupied.has(p.id))
	if not occupied_options.is_empty():
		options = occupied_options
	if options.is_empty():
		return
	var ceded = options[rng.randi_range(0, options.size() - 1)]
	ceded.owner = winner.id
	ceded.held_since = tick        # de facto changes hands; de jure takes a generation
	county_holders.erase(ceded.id) # the local lord loses everything in the peace
	if loser.ruler_id >= 0 and winner.ruler_id >= 0:
		add_memory(characters[loser.ruler_id], "took my land", winner.ruler_id, -30.0, 1.5)
	_log("[b]%s is ceded to %s[/b] — though its people still fly older banners." % [ceded.name, winner.name])


func toggle_trade_pact() -> String:
	if at_war:
		return "No trade while at war."
	trade_pact = not trade_pact
	_log("[b]A trade pact is %s.[/b]" % ("signed" if trade_pact else "dissolved"))
	return ""


# ------------------------------------------- hostages & wards (Module 5)

func send_ward(child_id: int, to_realm: int, hostage: bool = false) -> String:
	## Fostering shapes a child at a foreign court; a hostage is the same
	## arrangement with a knife under the table.
	if not characters.has(child_id):
		return "No such child."
	var c: SimCharacter = characters[child_id]
	if not c.alive:
		return "%s is dead." % c.name
	if wards.has(child_id):
		return "%s is already fostered abroad." % c.name
	if to_realm == c.realm_id:
		return "A ward must cross a border."
	if not hostage and c.age_years(tick) >= ADULT_AGE:
		return "Fostering shapes the young — %s is grown." % c.name
	var host: Realm = realms[to_realm]
	if host.ruler_id < 0:
		return "No court stands to receive a ward."
	var home: Realm = realms[c.realm_id]
	wards[child_id] = {"home": c.realm_id, "host": to_realm,
		"guardian": host.ruler_id, "hostage": hostage, "since": tick, "of_age": false}
	c.realm_id = to_realm
	host.prestige = minf(100.0, host.prestige + 5.0)
	if home.ruler_id >= 0:
		add_memory(characters[host.ruler_id], "a child of their blood in my hall", home.ruler_id, 10.0, 1.0)
		add_memory(characters[home.ruler_id], "they raise my blood", host.ruler_id, 10.0, 1.0)
	_log("[b]%s rides to the court of %s[/b] — %s." % [full_name(c), host.name,
		"a hostage against the peace" if hostage else "to be fostered and shaped"])
	return ""


func ransom_ward(child_id: int) -> String:
	if not wards.has(child_id):
		return "They are not held abroad."
	var w: Dictionary = wards[child_id]
	var home: Realm = realms[int(w["home"])]
	if home.gold < RANSOM_COST:
		return "A ransom costs %d gold." % int(RANSOM_COST)
	home.gold -= RANSOM_COST
	realms[int(w["host"])].gold += RANSOM_COST
	var c: SimCharacter = characters[child_id]
	c.realm_id = int(w["home"])
	wards.erase(child_id)
	_log("[b]%s is ransomed home[/b] for %d gold." % [full_name(c), int(RANSOM_COST)])
	return ""


func _wards_tick() -> void:
	if wards.is_empty():
		return
	for cid in wards.keys():
		var w: Dictionary = wards[cid]
		var c: SimCharacter = characters.get(int(cid))
		if c == null or not c.alive:
			var home: Realm = realms[int(w["home"])]
			var host: Realm = realms[int(w["host"])]
			if bool(w["hostage"]) and home.ruler_id >= 0 and host.ruler_id >= 0:
				add_memory(characters[home.ruler_id], "my blood died in their keeping", host.ruler_id, -30.0, 2.0)
			wards.erase(cid)
			continue
		# a crowned head cannot be held
		if realms[int(w["home"])].ruler_id == c.id:
			c.realm_id = int(w["home"])
			wards.erase(cid)
			_log("[b]%s is released to take the crown[/b] — no court dares keep a king." % full_name(c))
			continue
		# the guardianship passes with the host's crown
		var g: SimCharacter = characters.get(int(w["guardian"]))
		if g == null or not g.alive:
			w["guardian"] = realms[int(w["host"])].ruler_id
			g = characters.get(int(w["guardian"]))
		if c.age_years(tick) >= ADULT_AGE and not bool(w.get("of_age", false)):
			_ward_comes_of_age(c, w, g)


func _ward_comes_of_age(c: SimCharacter, w: Dictionary, g: SimCharacter) -> void:
	## Custom mentorship pays out: the guardian's strongest art rubs off,
	## personality flows down the high table, and a long fostering turns
	## the child's culture to the court that raised them.
	var years := int(float(tick - int(w["since"])) / 12.0)
	if g != null and g.alive:
		var best_key := "diplomacy"
		var best_v := -1
		for key in STAT_PROPS.values():
			if int(g.get(key)) > best_v:
				best_v = int(g.get(key))
				best_key = str(key)
		c.set(best_key, clampi(int(c.get(best_key)) + 2, 1, 30))
		add_memory(c, "raised me as their own", g.id, 25.0, 1.0)
		if years >= 4 and rng.randf() < 0.5:
			for t in g.traits:
				if trait_cat(t) == "personality" and _can_add_trait(c, t):
					_add_trait(c, t)
					break
		if years >= 6 and c.culture != g.culture:
			c.culture = g.culture
			_log("%s comes of age more %s than anything of home — the fostering did its work." % [
				full_name(c), CultureData.culture_label(g.culture)])
	if bool(w["hostage"]):
		w["of_age"] = true
		_log("%s comes of age at a foreign court — an honored guest who may not leave." % full_name(c))
	else:
		c.realm_id = int(w["home"])
		wards.erase(c.id)
		_log("[b]%s returns home from fostering[/b], carrying another court's lessons." % full_name(c))


# ------------------------------------------- the shadow court (Module 5)

func _dispossess(root_id: int, home_realm: int) -> void:
	## A landless noble house does not become harmless courtiers — it
	## flees abroad and becomes a national security threat.
	if dispossessed.has(root_id):
		return
	var home: Realm = realms[home_realm]
	if home.ruler_id >= 0 and root_house_id(characters[home.ruler_id].dynasty_id) == root_id:
		return  # the royal house cannot exile itself
	var host := 1 - home_realm
	var fled := 0
	for c in characters.values():
		if c.alive and c.realm_id == home_realm and root_house_id(c.dynasty_id) == root_id:
			c.realm_id = host
			fled += 1
	if fled == 0:
		return
	dispossessed[root_id] = {"home": home_realm, "host": host, "since": tick}
	_log("[b]The %s are dispossessed[/b] — %d of the blood flee to %s and raise a court-in-exile." % [
		dynasties[root_id].name, fled, realms[host].name])


func _shadow_court_tick() -> void:
	if dispossessed.is_empty():
		return
	for root in dispossessed.keys():
		var d: Dictionary = dispossessed[root]
		var line_lives := false
		for c in characters.values():
			if c.alive and root_house_id(c.dynasty_id) == int(root):
				line_lives = true
				break
		if not line_lives:
			dispossessed.erase(root)
			_log("The line of %s ends in exile — the shadow court dissolves." % dynasties[root].name)
			continue
		# old keys still open doors: the exiles bleed the homeland and
		# sharpen the host's knives against it
		var home: Realm = realms[int(d["home"])]
		var host: Realm = realms[int(d["host"])]
		home.gold = maxf(0.0, home.gold - 1.5)
		if host.plot_progress >= 0.0 and host.plot_target_id >= 0 \
				and characters.has(host.plot_target_id) \
				and characters[host.plot_target_id].realm_id == home.id:
			host.plot_progress += 1.0
		if tick % 12 == int(d["since"]) % 12:
			_log("From exile, the %s feed secrets across the border — %s bleeds coin and quiet." % [
				dynasties[root].name, home.name])


# ------------------------------------------- the broken blade cycle (Module 5)

func _demobilization() -> void:
	## The Scourge of Peace: professional swords beyond what peace can
	## pay must be settled with a bounty — or turned out onto the roads.
	for realm: Realm in realms:
		var professional := 0
		for a: Army in armies:
			if a.realm_id != realm.id:
				continue
			for reg in a.regiments:
				if str(reg["kind"]) != "levy":
					professional += int(reg["soldiers"])
		var excess := professional - maxi(120, int(levy_capacity(realm.id) / 2.0))
		if excess < FREE_COMPANY_MIN_MEN:
			continue
		var bounty := float(excess) * DEMOB_BOUNTY_PER_MAN
		var rid := realm.id
		raise_event(realm.id, realm.ruler_id, "The Scourge of Peace",
			"%d professional soldiers of %s stand unneeded and unpaid now the war is done. Settle them with a bounty — or turn them out, and let the roads answer for it." % [
				excess, realm.name],
			[
				{"label": "Pay the demobilization bounty (%d gold)" % int(bounty),
					"base": 3.0, "ai": {"greed": -0.6, "patience": 0.4},
					"effect": func() -> void: _demob_pay(rid, excess, bounty)},
				{"label": "Turn them out — the realm owes them nothing",
					"base": 0.0, "ai": {"greed": 0.6, "aggression": 0.3},
					"effect": func() -> void: _demob_turn_out(rid, excess)},
			])


func _demob_pay(realm_id: int, excess: int, bounty: float) -> void:
	var realm: Realm = realms[realm_id]
	if realm.gold < bounty:
		_log("%s's coffers cannot meet the bounty — the men are turned out unpaid." % realm.name)
		_demob_turn_out(realm_id, excess)
		return
	realm.gold -= bounty
	var _stripped := _strip_professionals(realm_id, excess)
	_log("[b]%s pays %d gold in demobilization bounties[/b] — the soldiers go home as farmers, not brigands." % [
		realm.name, int(bounty)])


func _demob_turn_out(realm_id: int, excess: int) -> void:
	var stripped := _strip_professionals(realm_id, excess)
	if stripped.is_empty():
		return
	var fc := Army.new()
	fc.id = next_army_id
	next_army_id += 1
	fc.realm_id = -1
	fc.pos = map.realm_centroid(realm_id) + Vector2(0.04, -0.03)
	fc.regiments = stripped
	free_companies.append(fc)
	var men := 0
	for reg in stripped:
		men += int(reg["soldiers"])
	_log("[b]A Free Company forms![/b] %d unpaid veterans of %s's war take to the roads under their own banner." % [
		men, realms[realm_id].name])


func _strip_professionals(realm_id: int, target_men: int) -> Array:
	## Pulls whole professional regiments out of the realm's armies until
	## roughly target_men are mustered out. Levies always go home free.
	var out: Array = []
	var taken := 0
	for a: Army in armies:
		if a.realm_id != realm_id:
			continue
		var kept: Array = []
		for reg in a.regiments:
			if taken < target_men and str(reg["kind"]) != "levy":
				out.append(reg)
				taken += int(reg["soldiers"])
			else:
				kept.append(reg)
		a.regiments = kept
	for a: Army in armies.duplicate():
		if a.realm_id == realm_id and a.regiments.is_empty():
			armies.erase(a)
	return out


func _province_at(pos: Vector2):
	var best = null
	var best_d := INF
	for p in map.provinces:
		var d: float = p.center.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = p
	return best


func _free_company_tick() -> void:
	if free_companies.is_empty():
		return
	for fc: Army in free_companies.duplicate():
		# plunder is a poor paymaster — the company bleeds men every month
		for reg in fc.regiments:
			reg["soldiers"] = int(float(reg["soldiers"]) * 0.985)
		fc.regiments = fc.regiments.filter(func(r) -> bool: return int(r["soldiers"]) > 0)
		if fc.size() < 30:
			free_companies.erase(fc)
			_log("The free company scatters — too few blades left to hold the road.")
			continue
		# pillage whatever county the company squats on
		var p = _province_at(fc.pos)
		if p != null and p.owner >= 0 and p.owner < realms.size():
			var plunder := rng.randf_range(1.0, 4.0)
			realms[p.owner].gold = maxf(0.0, realms[p.owner].gold - plunder)
			if rng.randf() < 0.25:
				_log("The free company pillages %s — %s bleeds %d gold in burned barns and robbed roads." % [
					p.name, realms[p.owner].name, int(maxf(plunder, 1.0))])
		# then drift on toward the next unlucky county
		if not fc.has_target or fc.pos.distance_to(fc.target) < 0.02:
			if p != null and not p.neighbors.is_empty():
				var nid: int = p.neighbors[rng.randi_range(0, p.neighbors.size() - 1)]
				fc.target = map.provinces[nid].center
				fc.has_target = true
		else:
			fc.pos += (fc.target - fc.pos).normalized() * 0.05
		# any realm army that closes the distance forces the fight
		for a: Army in armies:
			if a.regiments.is_empty() or a.pos.distance_to(fc.pos) > 0.05:
				continue
			_fight_free_company(a, fc)
			break


func _fight_free_company(a: Army, fc: Army) -> void:
	## Free companies behave like aggressive unlanded armies — until an
	## army physically marches out and destroys them.
	var cmdr_martial := 0
	if a.commander_id >= 0 and characters.has(a.commander_id):
		cmdr_martial = characters[a.commander_id].martial
	var sim := BattleSim.new()
	sim.setup_from_rosters(a.regiments, fc.regiments, cmdr_martial, 8,
		[str(realms[a.realm_id].name), "Free Company"])
	sim.run_headless()
	for reg: BattleSim.Regiment in sim.regiments:
		var target: Array = a.regiments if reg.side == 0 else fc.regiments
		if reg.roster_index < target.size():
			target[reg.roster_index]["soldiers"] = reg.soldiers if reg.alive() else 0
	a.regiments = a.regiments.filter(func(r) -> bool: return int(r["soldiers"]) > 0)
	fc.regiments = fc.regiments.filter(func(r) -> bool: return int(r["soldiers"]) > 0)
	if a.regiments.is_empty():
		armies.erase(a)
	if sim.winner == 0 or fc.size() < 30:
		free_companies.erase(fc)
		realms[a.realm_id].prestige = minf(100.0, realms[a.realm_id].prestige + 10.0)
		_log("[b]The free company is broken[/b] by %s — the roads are safe again." % realms[a.realm_id].name)
	else:
		fc.pos += Vector2(0.06, 0.04)
		fc.has_target = false
		_log("The free company mauls %s's soldiers and melts away with the baggage." % realms[a.realm_id].name)


# ------------------------------------------- the monthly diplomacy tick

func _diplomacy_tick() -> void:
	## Module 5's slow machinery: forged claims, wards growing up abroad,
	## reparations, exiled courts, and the swords peace left loose. Every
	## subsystem returns before touching the dice when it has no work.
	for realm: Realm in realms:
		realm.prestige = move_toward(realm.prestige, 0.0, PRESTIGE_DECAY)
	_fabricate_tick()
	_wards_tick()
	if not reparations.is_empty():
		var from: Realm = realms[int(reparations["from"])]
		var to: Realm = realms[int(reparations["to"])]
		var cut := minf(maxf(1.0, (2.0 + realm_tax_eff(from.id)) * REPARATIONS_RATE), maxf(from.gold, 0.0))
		from.gold -= cut
		to.gold += cut
		reparations["months_left"] = int(reparations["months_left"]) - 1
		if int(reparations["months_left"]) <= 0:
			_log("[b]The reparations are paid in full[/b] — the yoke lifts from %s." % from.name)
			reparations = {}
	for pid in salted.keys():
		if int(salted[pid]) <= tick:
			salted.erase(pid)
			_log("Green returns to %s at last — the salted years are over." % map.provinces[pid].name)
	_shadow_court_tick()
	_free_company_tick()


# ---------------------------------------------------------------- marriage

func marry(groom_id: int, bride_id: int) -> String:
	if not characters.has(groom_id) or not characters.has(bride_id):
		return "Pick a groom and a bride."
	var g: SimCharacter = characters[groom_id]
	var b: SimCharacter = characters[bride_id]
	for c: SimCharacter in [g, b]:
		if not c.alive:
			return "%s is dead." % c.name
		if c.spouse_id >= 0:
			return "%s is already married." % c.name
		if c.age_years(tick) < ADULT_AGE:
			return "%s is too young." % c.name
	if g.is_female == b.is_female:
		return "This union needs a groom and a bride."
	if _close_kin(g, b):
		return "They are too closely related."

	var cross_realm := g.realm_id != b.realm_id
	g.spouse_id = b.id
	b.spouse_id = g.id
	b.realm_id = g.realm_id       # the bride joins her husband's court
	b.last_birth_tick = tick      # no same-month births
	add_memory(g, "wedding", b.id, 40.0, 1.0)
	add_memory(b, "wedding", g.id, 40.0, 1.0)
	add_stress(g, -10.0, "wedded")
	add_stress(b, -10.0, "wedded")
	if g.culture != b.culture:
		_open_cross_marriage(g, b)
	if g.race != b.race:
		_record_cross_race_marriage(g, b)
	_log("[b]Wedding bells:[/b] %s weds %s." % [full_name(g), full_name(b)])
	if cross_realm:
		marriage_alliances.append([g.id, b.id])
		_log("[b]The marriage binds %s and %s in alliance.[/b]" % [realms[0].name, realms[1].name])
	# diplomatic experience for the arranging crowns (Hero System v1.0 §3);
	# the bride has already joined her husband's court, so a cross-realm
	# match credits both live crowns
	for rid in ([0, 1] if cross_realm else [g.realm_id]):
		if rid >= 0 and rid < realms.size() and realms[rid].ruler_id >= 0:
			award_hero_xp(realms[rid].ruler_id, HeroDB.XP_AWARDS["marriage_arranged"] \
				+ (HeroDB.XP_AWARDS["alliance_formed"] if cross_realm else 0), "a match well made")
	return ""


# ------------------------------------------- cross-cultural marriage (v1.0)

func marriage_acceptance_score(g: SimCharacter, b: SimCharacter) -> int:
	## The proposal-time acceptance basis: the cultures' mutual regard
	## (Cultural Roster tables) shaded by each spouse's own attitude
	## toward marrying outward (Syncretist +25 / Purist -30).
	if g.culture == b.culture:
		return 0
	var total := float(CultureData.marriage_acceptance(g.culture, b.culture))
	total += (trait_add(g, "cross_culture_spouse_opinion")
		+ trait_add(b, "cross_culture_spouse_opinion")) * 0.5
	return int(total)


func _household_path(g: SimCharacter, b: SimCharacter) -> String:
	## Which of the doc's four household states this marriage enters.
	## Parallelism needs two Purists (two courts under one roof); one
	## Purist — or a cold match with no Syncretist to bridge it — means
	## Imposition; everyone else genuinely blends. Reverse Imposition
	## waits for a prestige system that can invert the household.
	var g_purist := g.traits.has("Purist")
	var b_purist := b.traits.has("Purist")
	if g_purist and b_purist:
		return "parallelism"
	if g_purist or b_purist:
		return "imposition"
	if g.traits.has("Syncretist") or b.traits.has("Syncretist"):
		return "syncretism"
	return "syncretism" if marriage_acceptance_score(g, b) >= 0 else "imposition"


func _open_cross_marriage(g: SimCharacter, b: SimCharacter) -> void:
	var path := _household_path(g, b)
	var acc := marriage_acceptance_score(g, b)
	if acc != 0:
		add_memory(g, "a match across cultures", b.id, float(acc), 2.0)
		add_memory(b, "a match across cultures", g.id, float(acc), 2.0)
	match path:
		"imposition":
			# the bride joins her husband's court; his culture rules the hall
			add_memory(b, "my traditions kept to private rooms", g.id, -20.0, 1.0)
			_log("%s's hall keeps %s ways — %s learns to practice hers behind closed doors." % [
				full_name(g), CultureData.culture_label(g.culture), full_name(b)])
		"syncretism":
			add_memory(g, "a household of two traditions", b.id, 10.0, 1.0)
			add_memory(b, "a household of two traditions", g.id, 10.0, 1.0)
			_log("Two traditions share one table: the household of %s and %s honors both %s and %s ways." % [
				full_name(g), full_name(b), CultureData.culture_label(g.culture), CultureData.culture_label(b.culture)])
		"parallelism":
			_log("Two courts under one roof: %s and %s keep their traditions apart — and exhausting." % [
				full_name(g), full_name(b)])
	cross_marriages.append({"husband": g.id, "wife": b.id, "path": path,
		"progress": 0.0, "threshold": CultureData.syncretism_months(g.culture, b.culture),
		"decided": false})


func _record_cross_race_marriage(g: SimCharacter, b: SimCharacter) -> void:
	## The mythos file notices marriages across race lines (v1.0 §6).
	var races := [g.race, b.race]
	for c: SimCharacter in [g, b]:
		var root := root_house_id(c.dynasty_id)
		if root < 0:
			continue
		var dyn: Dynasty = dynasties[root]
		dyn.cross_race_marriages += 1
		# a Human-Orc union is the Karn-Vol precedent made blood
		if races.has("human") and (races.has("orc") or races.has("half_orc")):
			_earn_mythos(root, "Compact-Bound")
		# approximates the doc's "three consecutive generations"
		if dyn.cross_race_marriages >= 3:
			_earn_mythos(root, "Half-Blooded Line")


func _marriage_record(a_id: int, b_id: int) -> Dictionary:
	for m in cross_marriages:
		if (int(m["husband"]) == a_id and int(m["wife"]) == b_id) \
				or (int(m["husband"]) == b_id and int(m["wife"]) == a_id):
			return m
	return {}


func _bicultural_children(g: SimCharacter, b: SimCharacter) -> Array:
	var out: Array = []
	for cid in g.children_ids:
		var c: SimCharacter = characters.get(cid)
		if c != null and c.alive and c.mother_id == b.id and c.traits.has("Bicultural"):
			out.append(c)
	return out


func syncretism_gain(m: Dictionary) -> float:
	## The doc's monthly accumulation formula, spouse-summed: base 1,
	## Syncretist +2 / Purist -3, +1 for holding land of both cultures,
	## +1 per living bicultural child, -5 while at war with the realm
	## whose culture sits on the other side of the bed.
	var g: SimCharacter = characters[int(m["husband"])]
	var b: SimCharacter = characters[int(m["wife"])]
	var gain := 1.0 + trait_add(g, "syncretism_gain") + trait_add(b, "syncretism_gain")
	var held := realm_cultures(g.realm_id)
	if held.has(g.culture) and held.has(b.culture):
		gain += 1.0
	gain += float(_bicultural_children(g, b).size())
	if at_war and g.realm_id <= 1:
		var enemy_culture: String = "aelindran" if g.realm_id == 1 else "karn_vol"
		if g.culture == enemy_culture or b.culture == enemy_culture:
			gain -= 5.0
	return gain


func _syncretism_threshold(m: Dictionary) -> float:
	var g: SimCharacter = characters[int(m["husband"])]
	var b: SimCharacter = characters[int(m["wife"])]
	var threshold := float(m["threshold"])
	# The Syncretic Charter: the dynasty has committed to the blending
	if has_legacy(root_house_id(g.dynasty_id), "The Syncretic Charter") \
			or has_legacy(root_house_id(b.dynasty_id), "The Syncretic Charter"):
		threshold *= 0.75
	return threshold


func _syncretism_tick() -> void:
	for m in cross_marriages:
		var g: SimCharacter = characters.get(int(m["husband"]))
		var b: SimCharacter = characters.get(int(m["wife"]))
		if g == null or b == null or not g.alive or not b.alive or g.spouse_id != b.id:
			continue
		if str(m["path"]) == "parallelism":
			# two courts under one roof: exhausting for both (v1.0 Path D)
			add_stress(g, 1.0, "a divided household")
			add_stress(b, 1.0, "a divided household")
			continue
		if str(m["path"]) != "syncretism" or bool(m["decided"]) or int(m["threshold"]) < 0:
			continue
		# The Preserving Line: this blood does not blend, ever
		if has_legacy(root_house_id(g.dynasty_id), "The Preserving Line") \
				or has_legacy(root_house_id(b.dynasty_id), "The Preserving Line"):
			continue
		m["progress"] = float(m["progress"]) + syncretism_gain(m)
		if float(m["progress"]) >= _syncretism_threshold(m):
			_raise_hybridization_event(m, g, b)


func _raise_hybridization_event(m: Dictionary, g: SimCharacter, b: SimCharacter) -> void:
	## The civilizational moment (v1.0 §4): decades of shared household
	## have made something neither culture fully was. Adopt, delay, or
	## reject — the pantheon that once blocked this choice is silent.
	m["decided"] = true
	var hybrid := CultureData.hybrid_of(g.culture, b.culture)
	var hybrid_name := CultureData.hybrid_label(hybrid)
	var years := int(float(m["progress"]) / 12.0)
	var bicultural := _bicultural_children(g, b).size()
	var rec := m
	var hus := g
	var wif := b
	raise_event(g.realm_id, g.id, "A Culture is Born",
		"%d years of marriage between %s (%s) and %s (%s). %d bicultural %s at their table. What the household practices is no longer either tradition — the world has a name for it now: [b]%s[/b]. The pantheon that once forbade this is silent." % [
			years, full_name(g), CultureData.culture_label(g.culture),
			full_name(b), CultureData.culture_label(b.culture),
			bicultural, "child grows" if bicultural == 1 else "children grow", hybrid_name],
		[{"label": "Adopt %s ways — both rosters, both worlds" % hybrid_name, "base": 30, "ai": {"patience": 0.2},
			"effect": func() -> void: _adopt_hybrid(rec, hus, wif, hybrid)},
		{"label": "Not yet — let the household ripen another twenty years", "base": 10, "ai": {"patience": 0.4},
			"effect": func() -> void:
				rec["decided"] = false
				rec["threshold"] = int(rec["threshold"]) + 240
				_log("The household of %s and %s keeps both traditions — and decides nothing, for now." % [full_name(hus), full_name(wif)])},
		{"label": "Reject it — one hall, one tradition", "base": 0, "ai": {"orthodoxy": 1.0},
			"effect": func() -> void: _reject_hybrid(rec, hus, wif)}])


func _adopt_hybrid(_m: Dictionary, g: SimCharacter, b: SimCharacter, hybrid: String) -> void:
	var hybrid_name := CultureData.hybrid_label(hybrid)
	var parents: Array = [g.culture, b.culture]
	g.culture = hybrid
	b.culture = hybrid
	for cid in g.children_ids:
		var c: SimCharacter = characters.get(cid)
		if c != null and c.alive and c.traits.has("Bicultural"):
			c.culture = hybrid  # the bicultural children ARE the new culture
	# the ruler's land follows the household, one percent a month
	for p in map.provinces:
		if p.owner == g.realm_id and parents.has(p.culture) and not culture_drift.has(p.id):
			culture_drift[p.id] = {"target": hybrid, "progress": 0}
	_log("[b]A new culture takes its name: %s.[/b] The household of %s and %s adopts it, and their lands begin to follow." % [
		hybrid_name, full_name(g), full_name(b)])


func _reject_hybrid(m: Dictionary, g: SimCharacter, b: SimCharacter) -> void:
	m["path"] = "imposition"
	m["progress"] = 0.0
	add_memory(g, "the blending we renounced", b.id, -10.0, 1.0)
	add_memory(b, "the blending we renounced", g.id, -10.0, 1.0)
	# the children who grew up bicultural did not consent to the retreat
	for c: SimCharacter in _bicultural_children(g, b):
		if rng.randf() < 0.35 and _can_add_trait(c, "Cross-Sworn"):
			_add_trait(c, "Cross-Sworn")
			add_memory(c, "they made me two things, then chose one", g.id, -5.0, 0.5)
			add_memory(c, "they made me two things, then chose one", b.id, -5.0, 0.5)
			_log("%s grows Cross-Sworn — raised between two worlds, then told to pick." % full_name(c))
	if rng.randf() < 0.5 and _can_add_trait(g, "Purist"):
		_add_trait(g, "Purist")
	_log("The household of %s and %s turns back: one hall, one tradition." % [full_name(g), full_name(b)])


func _culture_drift_tick() -> void:
	## Land under a hybrid-culture ruler drifts toward the household's
	## ways at 1% a month (v1.0 §10); at 100% the province converts and
	## its muster answers to both parent rosters.
	var done: Array = []
	for pid in culture_drift:
		var d: Dictionary = culture_drift[pid]
		d["progress"] = int(d["progress"]) + 1
		if int(d["progress"]) >= 100:
			var p = map.provinces[pid]
			p.culture = str(d["target"])
			done.append(pid)
			_log("%s now follows %s ways — the drift of a generation is complete." % [
				p.name, CultureData.hybrid_label(str(d["target"]))])
	for pid in done:
		culture_drift.erase(pid)


func trait_cat(t: String) -> String:
	return TraitDB.info(t).category


func _traits_of_cat(cat: String) -> Array:
	var out: Array = []
	for t in TraitDB.db():
		if trait_cat(t) == cat:
			out.append(t)
	return out


func _count_cat(c: SimCharacter, cat: String) -> int:
	var n := 0
	for t in c.traits:
		if trait_cat(t) == cat:
			n += 1
	return n


func _can_add_trait(c: SimCharacter, t: String) -> bool:
	if c.traits.has(t):
		return false
	var info := TraitDB.info(t)
	# opposites exclude in every category — a soul is not both Zealous
	# and Broken, nor Oath-Sworn and Oathbreaker (Magic Injection v1.0)
	if info.opposite != "" and c.traits.has(info.opposite):
		return false
	if info.category == "personality" and _count_cat(c, "personality") >= PERSONALITY_CAP:
		return false
	return true


func _remove_trait(c: SimCharacter, t: String) -> void:
	## The mirror of _add_trait: the trait goes, and its stats go with it.
	if not c.traits.has(t):
		return
	c.traits.erase(t)
	var mods: Dictionary = TraitDB.info(t).stats
	for k in mods:
		var prop: String = STAT_PROPS[k]
		c.set(prop, clampi(int(c.get(prop)) - int(mods[k]), 1, 30))


func _add_trait(c: SimCharacter, t: String) -> void:
	if not _can_add_trait(c, t):
		return
	c.traits.append(t)
	var mods: Dictionary = TraitDB.info(t).stats
	for k in mods:
		var prop: String = STAT_PROPS[k]
		c.set(prop, clampi(int(c.get(prop)) + int(mods[k]), 1, 30))


func _rollable_congenitals() -> Array:
	## Bicultural is raised in a two-culture household, never rolled by
	## chance — and no one at Year Zero was (the pantheon blocked it).
	## Threshold-Sensitive enters the world seeded canonically (Module 9
	## addendum) and travels only by blood — never the founder dice, or
	## every fixed-seed history would reshuffle.
	var out := _traits_of_cat("congenital")
	out.erase("Bicultural")
	out.erase("Threshold-Sensitive")
	return out


func _assign_founder_traits(c: SimCharacter) -> void:
	var personalities := _traits_of_cat("personality")
	for i in 2:
		_add_trait(c, personalities[rng.randi_range(0, personalities.size() - 1)])
	if rng.randf() < 0.15:
		var congenitals := _rollable_congenitals()
		_add_trait(c, congenitals[rng.randi_range(0, congenitals.size() - 1)])


func _inherit_traits(child: SimCharacter, father: SimCharacter, mother: SimCharacter) -> void:
	## Personality leans toward the parents; congenital traits are genetic,
	## each parent copy rolling its own inheritance chance.
	for parent: SimCharacter in [father, mother]:
		for t in parent.traits:
			match trait_cat(t):
				"personality":
					if rng.randf() < 0.30:
						_add_trait(child, t)
				"congenital":
					if rng.randf() < TraitDB.info(t).inherit_chance:
						_add_trait(child, t)
	var personalities := _traits_of_cat("personality")
	while _count_cat(child, "personality") < 2:
		_add_trait(child, personalities[rng.randi_range(0, personalities.size() - 1)])
	if rng.randf() < 0.03:
		var congenitals := _rollable_congenitals()
		_add_trait(child, congenitals[rng.randi_range(0, congenitals.size() - 1)])


func ai_weight(c: SimCharacter, key: String) -> float:
	## Personality is destiny: NPC decision chances are sums of trait weights.
	var total := 0.0
	for t in c.traits:
		total += float(TraitDB.info(t).ai.get(key, 0.0))
	return total


func trait_mult(c: SimCharacter, key: String) -> float:
	## Product of a named multiplier hook across a character's traits —
	## how subsystems (battle, ledger, schemes) read trait effects.
	var total := 1.0
	if c == null:
		return total
	for t in c.traits:
		total *= float(TraitDB.info(t).mods.get(key, 1.0))
	return total


func trait_add(c: SimCharacter, key: String) -> float:
	## Sum of a named additive hook across a character's traits.
	var total := 0.0
	if c == null:
		return total
	for t in c.traits:
		total += float(TraitDB.info(t).mods.get(key, 0.0))
	return total


# ---------------------------------------------------------------- stress & memory

func add_stress(c: SimCharacter, amount: float, reason: String) -> void:
	if amount > 0.0:
		# Magic Injection v1.0: temperament shapes the load — the Broken
		# carry it heavier, the Brushgate-Trained barely feel it
		amount *= trait_mult(c, "stress_gain_mult")
	c.stress = maxf(0.0, c.stress + amount)
	if amount > 0.0 and c.stress >= (c.stress_level + 1) * 100.0 and c.stress_level < 3:
		c.stress_level += 1
		c.stress = maxf(0.0, c.stress - 60.0)
		var options: Array = []
		for t in COPING_TRAITS:
			if not _can_add_trait(c, t):
				continue
			var scar := t
			var who := c
			var why := reason
			var ai := {}
			match t:
				"Drunkard":
					ai = {"patience": -0.3, "greed": 0.1}
				"Reclusive":
					ai = {"scheming": 0.2, "aggression": -0.3}
				"Irritable":
					ai = {"aggression": 0.4}
			options.append({"label": COPING_FLAVOR[t], "ai": ai,
				"effect": func() -> void:
					_add_trait(who, scar)
					_log("[b]%s breaks under the strain[/b] (%s) — and becomes %s." % [full_name(who), why, scar])})
		if options.is_empty():
			_log("[b]%s suffers a mental break[/b] (%s)." % [full_name(c), reason])
			return
		raise_event(c.realm_id, c.id, "A Mind at its Limit",
			"%s cannot carry it any longer (%s). Something has to give — the only choice left is what." % [
				full_name(c), reason], options)


func _stress_relief_tick() -> void:
	for c in characters.values():
		if not c.alive or c.stress <= 0.0:
			continue
		var relief := 1.5
		if c.traits.has("Patient"):
			relief += 0.5
		if has_legacy(root_house_id(c.dynasty_id), "Unbending Oaths"):
			relief += 0.5
		if has_legacy(root_house_id(c.dynasty_id), "The Brushgate Continuity"):
			relief += 0.3  # the discipline kept at the family hearth
		c.stress = maxf(0.0, c.stress - relief)
		if c.stress < c.stress_level * 100.0 - 50.0 and c.stress_level > 0:
			c.stress_level -= 1


# ------------------------------------------- Magic Injection v1.0
# The Corruption meter, the Silence Response, the eight practices, and
# the Magistocracy's central secret. Every die here rolls on `mrng`
# (own seed) so the founder seeds and the main history never feel it.

func add_corruption(c: SimCharacter, amount: float, reason: String) -> void:
	## The Patron's ledger: parallel to stress, but it never decays on
	## its own — only active work (meditation, confession) reduces it.
	if amount > 0.0:
		if patron_network_broken:
			return  # Ending 3: the anchor is ash — the ledger takes no new entries
		amount *= trait_mult(c, "corruption_gain_mult")
		amount += trait_add(c, "corruption_gain_baseline") * 0.1  # the Patron-Bound always owe a little more
		if has_legacy(root_house_id(c.dynasty_id), "The Patron's Bargain"):
			amount *= 1.10  # the blood was born owing
	c.corruption = maxf(0.0, c.corruption + amount)
	while c.corruption_marks < 3 and c.corruption >= CORRUPTION_THRESHOLDS[c.corruption_marks]:
		c.corruption_marks += 1
		var mark: String = CORRUPTION_MARKS[c.corruption_marks - 1]
		_add_trait(c, mark)
		_log("[b]%s bears the %s[/b] — %s (%s)." % [full_name(c), mark, MARK_FLAVOR[mark], reason])


func _has_silence_response(c: SimCharacter) -> bool:
	for r in SILENCE_RESPONSES:
		if c.traits.has(r):
			return true
	return false


func _swap_silence_response(c: SimCharacter, to: String) -> void:
	for r in SILENCE_RESPONSES:
		if r != to:
			_remove_trait(c, r)
	_add_trait(c, to)


func _pick_silence_response(c: SimCharacter) -> String:
	## Who you already were decides what the Night made of you (doc §3).
	var w := {"Zealous": 10.0, "Broken": 10.0, "Pragmatic": 10.0, "Opportunistic": 10.0}
	if c.traits.has("Methodical"):
		w["Pragmatic"] += 15.0
	if c.traits.has("Impulsive"):
		w["Opportunistic"] += 10.0
		w["Zealous"] += 10.0
	if c.traits.has("Paranoid"):
		w["Broken"] += 15.0
		w["Opportunistic"] += 5.0
	if c.traits.has("Compassionate"):
		w["Zealous"] += 15.0
		w["Pragmatic"] += 10.0
	if c.traits.has("Cruel"):
		w["Opportunistic"] += 20.0
	if c.traits.has("Content"):
		w["Pragmatic"] += 15.0
	if c.traits.has("Ambitious"):
		w["Opportunistic"] += 20.0
	if c.traits.has("Genius"):
		w["Pragmatic"] += 10.0  # they understood what had happened faster
	var total := 0.0
	for k in w:
		total += float(w[k])
	var roll := mrng.randf() * total
	for k in w:
		roll -= float(w[k])
		if roll <= 0.0:
			return str(k)
	return "Pragmatic"


func _seed_magic() -> void:
	## Year Zero, Month 1: the gods stop answering, and everyone answers
	## that. Runs once at setup, entirely on the magic RNG.
	mrng.seed = 333
	for c in characters.values():
		if c.alive and not _has_silence_response(c):
			_add_trait(c, _pick_silence_response(c))
	# the practices, seeded from the founding cast (the named canonical
	# practitioners — Marak, Selene, the Magisters — arrive with the
	# Faction Cast pass; until then the courts keep their own)
	var wizard := _best_unpracticed(0, "learning")
	if wizard != null:
		_add_trait(wizard, "Arcane-Blooded")
		_add_trait(wizard, "Academy-Sworn")
		_log("%s keeps the court's grimoires — academy-trained, and quietly indispensable." % full_name(wizard))
	var cleric := _best_unpracticed(0, "diplomacy")
	if cleric != null:
		_add_trait(cleric, "Faith-Practicing")
		_log("%s still lights the candles at the old altar. No one has told them to stop." % full_name(cleric))
	var druid := _best_unpracticed(1, "learning")
	if druid != null:
		_add_trait(druid, "Primal-Practiced")
		_log("%s keeps the clan's old ways with root and stone — the one craft the Silence never touched." % full_name(druid))
	var monk := _best_unpracticed(1, "prowess")
	if monk != null:
		_add_trait(monk, "Brushgate-Trained")
		_log("%s learned the Brushgate discipline in the passes. The body remembers what the gods forgot." % full_name(monk))
	# The Architect of Silence: Veril Ormand, the last surviving yes-vote
	# of Year 112. An old magister who keeps to his chambers — and keeps
	# the only complete record of what the Council bought, and with what.
	# 77 at Year Zero, canonized in the Vigil doc §1 (83 at his Year Six
	# death, matching the TTRPG's chamber) — a birth-date fact, not a die.
	var house := Dynasty.new(dynasties.size(), "House Ormand")
	dynasties[house.id] = house
	var ormand := _create_character("Veril", false, tick - 77 * 12 - 5, house.id, 0)
	ormand.learning = 18
	ormand.intrigue = 13
	ormand.stewardship = 10
	ormand.diplomacy = 5
	ormand.martial = 3
	ormand.prowess = 2
	ormand.genome = Genetics.founder(mrng)
	_add_trait(ormand, "Academy-Sworn")
	_add_trait(ormand, "Broken")
	_add_trait(ormand, "Reclusive")
	# Canon Updates Post-Caeris v1.0: thirty-four years in the Records
	# Sublevel is Focused, not merely reclusive — the preparation is the purpose
	_add_trait(ormand, "Focused")
	architect_id = ormand.id
	_add_secret(ormand.id, "silence_cause_complicity")
	add_corruption(ormand, 6.0, "what was signed in Year 112 of the Council")
	_log("An old magister, Veril Ormand, keeps to his chambers in Vael and receives no one. The court has stopped asking why.")


func _best_unpracticed(realm_id: int, stat: String) -> SimCharacter:
	var best: SimCharacter = null
	for c in characters.values():
		if not c.alive or c.realm_id != realm_id or c.age_years(tick) < ADULT_AGE:
			continue
		if realms[realm_id].ruler_id == c.id:
			continue  # crowns have realms to run
		var practiced := false
		for t in ["Arcane-Blooded", "Academy-Sworn", "Faith-Practicing", "Oath-Sworn",
				"Primal-Practiced", "Patron-Bound", "Song-Marked", "Brushgate-Trained"]:
			if c.traits.has(t):
				practiced = true
				break
		if practiced:
			continue
		if best == null or int(c.get(stat)) > int(best.get(stat)):
			best = c
	return best


# ------------------------------------------- the Faction Cast (v1.0)
# The canonical Year Zero rulers of Khessar's map-only realms, made
# flesh: real SimCharacters with faces, races, ages, and answers to the
# Silence — living outside the two simulated realms' machinery until
# their government modules bring their realms fully live. All dice on
# `crng`; the main history stream never feels them. The rulers come
# straight from KhessarMapData.REALMS' canonical strings (Faction Map).

func is_cast(c: SimCharacter) -> bool:
	## Outside the main stream's dice: the map-realm cast, the seeded
	## Council of Magisters (Administrative v1.0), the canonical
	## threshold practitioners (Module 9 — their fates are scheduled
	## beats and theology, never the monthly actuarial rolls), and the
	## seeded canonical heroes (Hero System v1.0 — their fates are
	## battles and the chronicle, never the marriage pools).
	return c != null and (c.realm_id >= 2 or admin_cast.has(c.id) or faith_cast.has(c.id) \
		or hero_cast.has(c.id))


func _map_realm_named(name_part: String) -> int:
	for mr in map.realms:
		if str(mr.name).contains(name_part):
			return mr.id
	return -1


func _cast_character(p_name: String, house_name: String, female: bool, age: int,
		map_realm_id: int, race: String, culture: String, stats: Dictionary,
		traits: Array, response: String) -> SimCharacter:
	var dyn: Dynasty = null
	for d: Dynasty in dynasties.values():
		if d.name == house_name:
			dyn = d
			break
	if dyn == null:
		dyn = Dynasty.new(dynasties.size(), house_name)
		dynasties[dyn.id] = dyn
	var c := _create_character(p_name, female, tick - age * 12 - crng.randi_range(0, 11), dyn.id, map_realm_id)
	c.race = race
	c.culture = culture
	for k in stats:
		c.set(STAT_PROPS[k], clampi(int(stats[k]), 1, 30))
	c.genome = Genetics.founder(crng)
	for t in traits:
		_add_trait(c, str(t))
	_add_trait(c, response)
	return c


func _seed_faction_cast() -> void:
	## Faction Map v1.0's named crowns, seated. Anselm Vorontheim (the
	## Grand Magister) waits for the Administrative government module —
	## realm 0 is modeled through its noble houses until then.
	crng.seed = 555
	# --- Pellar: the Iron Library's shield ---
	var pellar := _map_realm_named("Pellar")
	var eithne := _cast_character("Eithne", "House Vellian", true, 52, pellar, "human", "free_city",
		{"dip": 16, "stw": 12, "mar": 8, "int": 9, "lrn": 11, "prw": 5},
		["Compassionate", "Patient"], "Zealous")
	cast_rulers[pellar] = {"id": eithne.id, "title": "Queen"}
	var ilyra := _cast_character("Ilyra", "House Vellian", true, 24, pellar, "human", "free_city",
		{"dip": 11, "stw": 10, "mar": 5, "int": 10, "lrn": 17, "prw": 4},
		["Methodical"], "Pragmatic")
	ilyra.mother_id = eithne.id
	eithne.children_ids.append(ilyra.id)
	var vovel := _cast_character("Marek", "House Vovel", false, 71, pellar, "human", "free_city",
		{"dip": 10, "stw": 12, "mar": 3, "int": 13, "lrn": 20, "prw": 2},
		["Focused", "Methodical", "Honest", "Academy-Sworn"], "Pragmatic")
	vovel.learning = 26  # Canon Updates Post-Caeris v1.0: a lifetime of the archive
	marek_id = vovel.id  # the Vigil watches the Iron Library (doc §2 Phase Four)
	# --- Halven: the merchant-democrat First Voice ---
	var halven := _map_realm_named("Halven")
	var ferren := _cast_character("Ferren", "House Crannock-Vey", false, 58, halven, "human", "halveni",
		{"dip": 14, "stw": 16, "mar": 6, "int": 11, "lrn": 12, "prw": 5},
		["Ambitious", "Gregarious"], "Pragmatic")
	cast_rulers[halven] = {"id": ferren.id, "title": "First Voice"}
	var selia := _cast_character("Selia", "House Crannock-Vey", true, 54, halven, "half_elf", "halveni",
		{"dip": 13, "stw": 11, "mar": 4, "int": 9, "lrn": 14, "prw": 3},
		["Patient"], "Pragmatic")
	ferren.spouse_id = selia.id
	selia.spouse_id = ferren.id
	var mira := _cast_character("Mira", "House Crannock-Vey", true, 26, halven, "half_elf", "halveni",
		{"dip": 10, "stw": 9, "mar": 6, "int": 15, "lrn": 12, "prw": 6},
		["Deceitful"], "Opportunistic")
	mira.father_id = ferren.id
	mira.mother_id = selia.id
	ferren.children_ids.append(mira.id)
	selia.children_ids.append(mira.id)
	# --- Vor-Grim: the compact-breaker clan ---
	var vor_grim := _map_realm_named("Vor-Grim")
	var grimkar := _cast_character("Grimkar", "House Vor-Grim", false, 50, vor_grim, "orc", "drevak",
		{"dip": 4, "stw": 7, "mar": 15, "int": 8, "lrn": 4, "prw": 16},
		["Wrathful", "Brave"], "Opportunistic")
	cast_rulers[vor_grim] = {"id": grimkar.id, "title": "Chieftain"}
	# --- Kharak-Dum: the last open hold ---
	var kharak := _map_realm_named("Kharak-Dum")
	var grimhold := _cast_character("Grimhold", "House Ironvault", false, 82, kharak, "dwarf", "kharak_dum",
		{"dip": 10, "stw": 15, "mar": 12, "int": 8, "lrn": 12, "prw": 9},
		["Patient", "Content", "Ailing"], "Pragmatic")
	cast_rulers[kharak] = {"id": grimhold.id, "title": "King"}
	var karth := _cast_character("Karth", "House Ironvault", false, 48, kharak, "dwarf", "kharak_dum",
		{"dip": 9, "stw": 13, "mar": 8, "int": 9, "lrn": 22, "prw": 7},
		["Methodical", "Shy"], "Pragmatic")
	karth.father_id = grimhold.id
	grimhold.children_ids.append(karth.id)
	# --- the two Elven Great Houses: a 400-year rivalry ---
	var veldarin := _map_realm_named("Veldarin")
	var analinth := _cast_character("Analinth", "House Veldarin", true, 340, veldarin, "elf", "veldarin",
		{"dip": 12, "stw": 14, "mar": 9, "int": 12, "lrn": 19, "prw": 8},
		["Patient", "Content", "Purist"], "Pragmatic")
	cast_rulers[veldarin] = {"id": analinth.id, "title": "Matriarch"}
	var thaladris := _map_realm_named("Thaladris")
	var ariorwe := _cast_character("Ariorwe", "House Thaladris", true, 285, thaladris, "elf", "thaladris",
		{"dip": 18, "stw": 12, "mar": 7, "int": 11, "lrn": 16, "prw": 6},
		["Gregarious", "Patient", "Song-Marked"], "Pragmatic")
	ariorwe.names_carried = 120  # a century of corresponding with the Iron Library, and singing its dead
	cast_rulers[thaladris] = {"id": ariorwe.id, "title": "Matriarch"}
	# --- Saren-Vesh: the prepared ---
	var saren := _map_realm_named("Saren-Vesh")
	var vessa := _cast_character("Vessa", "House Korren", true, 47, saren, "human", "southern_reach",
		{"dip": 13, "stw": 17, "mar": 5, "int": 14, "lrn": 12, "prw": 4},
		["Ambitious", "Methodical"], "Opportunistic")
	cast_rulers[saren] = {"id": vessa.id, "title": "First Councilor"}
	# --- the Iron Library's discipline, seeded at the cast stream's tail
	# (Architect's Vigil v1.0): Thessaly Vorn, Marek Vovel's archivist and
	# eventual successor. Her creation draws after every existing cast die,
	# so the fixed cast history never feels her. Stats are Fable-invented —
	# flagged for the Gazetteer.
	# Canon Updates Post-Caeris v1.0: Learning 22 at Year Zero; Focused
	# arrives with the Chief Archivist's desk (the promotion beat), so
	# her seed carries two personality traits, leaving room for it.
	var thessaly := _cast_character("Thessaly", "House Vorn", true, 44, pellar, "human", "free_city",
		{"dip": 9, "stw": 11, "mar": 2, "int": 12, "lrn": 22, "prw": 2},
		["Methodical", "Patient", "Academy-Sworn"], "Pragmatic")
	thessaly_id = thessaly.id
	_log("[b]The crowns of Khessar at Year Zero:[/b] Queen Eithne in Pellar, First Voice Ferren Crannock-Vey in Halven, Chieftain Grimkar Vor-Grim beyond the passes, King Grimhold Ironvault under Kharak-Dum, the Matriarchs Analinth Veldarin and Ariorwe Thaladris in their forests, and First Councilor Vessa Korren at Saren-Vesh. Every one of them woke to the same silent sky.")
	_log("House Veldarin answers no letters — it has not for a hundred and eighty years, and a silent sky changes nothing.")


func cast_ruler_of(map_realm_id: int) -> SimCharacter:
	if not cast_rulers.has(map_realm_id):
		return null
	return characters.get(int(cast_rulers[map_realm_id]["id"]))


func cast_title_of(char_id: int) -> String:
	if char_id == caeris_id:
		return "Scholar of the Ashfields"  # no crown; the territory is a research environment
	for rid in cast_rulers:
		if int(cast_rulers[rid]["id"]) == char_id:
			return "%s of %s" % [str(cast_rulers[rid]["title"]), map.realms[rid].name]
	return ""


func _cast_tick() -> void:
	## The cast's scheduled canonical beats (Faction Map starting crises).
	## Deterministic by tick — chronicle drama, not simulation, until the
	## government modules bring these realms live.
	if cast_rulers.is_empty():
		return
	match tick:
		6:
			_log("[b]Pellar refuses the Magistocracy.[/b] A Vael delegation arrives at the Iron Library to offer 'consultation on the archives' safety.' Queen Eithne has the gates opened, the delegates fed — and the offer declined in writing. The first crack between Vael and the Free Cities is on parchment now.")
		10:
			_log("[b]The grain fleets fail Halven.[/b] The sea-weather has not been right since the Night of the Third Hour, and the shipping contracts written for the old winds are worthless. First Voice Ferren Crannock-Vey convenes the six houses in emergency session.")
		14:
			_log("Saren-Vesh's warehouses stand full — First Councilor Vessa Korren began stockpiling months before the Silence, on the advice of anonymous correspondence she has never explained. The Trade Council does not ask twice about profitable foresight.")
		24:
			_log("[b]The ward-stones of Kharak-Dum are going dark[/b] — one by one, oldest first. King Grimhold Ironvault orders the deep galleries sealed and the ward-speakers doubled. The wards held through the Silence itself; whatever is eating them now is patient.")
		30:
			_log("[b]Chieftain Grimkar Vor-Grim spits on the border compact.[/b] Word crosses the passes: the Vor-Grim call the Karn-Vol arrangement with the lowlanders a leash, and Grimkar has begun asking other clans what an unleashed north might take.")
		44:
			# The Vigil doc §2: Marek Vovel dies in Year Four — and the Iron
			# Library, with all its correspondence discipline, passes to
			# Thessaly Vorn. A scheduled beat, not a die.
			var vov: SimCharacter = characters.get(marek_id)
			if vov != null and vov.alive:
				_kill(vov, "dies among the Iron Library's stacks, a catalogue unfinished,")
				_log("[b]The Iron Library passes to Thessaly Vorn.[/b] Marek Vovel's archivist of twenty years takes the Chief Archivist's desk without ceremony — the correspondence goes out on schedule, and the Record does not miss a week.")
			# Canon Updates Post-Caeris v1.0: the desk is where she becomes
			# Focused — the archive stops being her work and becomes her
			# purpose. However Marek's end came, the desk is hers by now.
			var th: SimCharacter = characters.get(thessaly_id)
			if th != null and th.alive and not th.traits.has("Focused"):
				_add_trait(th, "Focused")
			# the office passes with the desk (Hero System v1.1: Thessaly is
			# her position, not a class — the SRD rule). The XP award the
			# doc names for this succession self-activates if Opus ever
			# gives her a chassis.
			if th != null and th.alive:
				court_positions[thessaly_id] = "Chief Archivist of the Iron Library"
				award_hero_xp(th.id, HeroDB.XP_AWARDS["chief_archivist"], "the Chief Archivist's desk")
		48:
			var grimhold2 := cast_ruler_of(_map_realm_named("Kharak-Dum"))
			if grimhold2 != null and grimhold2.alive:
				_kill(grimhold2, "dies as the ward-lights gutter,")
				var kharak2 := _map_realm_named("Kharak-Dum")
				var karth2: SimCharacter = null
				for cid in grimhold2.children_ids:
					var kid: SimCharacter = characters.get(cid)
					if kid != null and kid.alive:
						karth2 = kid
						break
				if karth2 != null:
					cast_rulers[kharak2] = {"id": karth2.id, "title": "King"}
					_log("[b]The first Dwarven Interregnum of the Silence opens under Kharak-Dum.[/b] The succession councils sit in the dark of the sealed galleries — and rise, at last, with Karth Ironvault. A scholar-king, crowned while the ward-stones dim.")


# --------------------------------- Administrative Government (v1.0)
# The mechanical shape of the Vael Magistocracy (Opus's mini-brief,
# 2026-07-08): a non-hereditary bureaucratic government. The Grand
# Magister is elected by the nine-seat Council of Magisters; succession
# goes to whoever the Council chooses — never to the dead ruler's heirs.
# All Council randomness runs on `arng` (its own seed, like the map's,
# the magic's, and the cast's), and the seeded Council characters are
# guarded out of the main stream's monthly dice: the fixed-seed history
# never feels the chamber's politics.

func _admin_character(p_name: String, house_name: String, female: bool, age: int,
		race: String, stats: Dictionary, traits: Array, response: String) -> SimCharacter:
	## A seeded Council figure: a real Vael courtier whose fate is
	## politics and scheduled beats, never the actuarial tables.
	var dyn: Dynasty = null
	for d: Dynasty in dynasties.values():
		if d.name == house_name:
			dyn = d
			break
	if dyn == null:
		dyn = Dynasty.new(dynasties.size(), house_name)
		dynasties[dyn.id] = dyn
	var c := _create_character(p_name, female, tick - age * 12 - arng.randi_range(0, 11), dyn.id, 0)
	c.race = race
	for k in stats:
		c.set(STAT_PROPS[k], clampi(int(stats[k]), 1, 30))
	c.genome = Genetics.founder(arng)
	for t in traits:
		_add_trait(c, str(t))
	_add_trait(c, response)
	admin_cast[c.id] = true
	return c


func _seat_magister(seat: String, char_id: int, since_tick: int) -> void:
	var newly := not magister_seats.has(seat) or int(magister_seats[seat]["holder"]) != char_id
	magister_seats[seat] = {"holder": char_id, "since": since_tick}
	if newly and char_id >= 0:
		award_hero_xp(char_id, HeroDB.XP_AWARDS["council_appointment"], "a Council seat taken")


func _seed_administration() -> void:
	## Brief §2: the Year Zero Council. Anselm Vorontheim takes realm 0's
	## chair from the Halvenard-Veil placeholder; nine seats sit; Tess
	## Mareck watches from off the ledger. The four seats the brief left
	## unnamed carry Fable-invented names — flagged for the Gazetteer.
	arng.seed = 888
	# Seat 1 — the Grand Magister. NOT Aelindran-Legitimate: House
	# Vorontheim's claim is administrative, which matters to the cascade.
	var anselm := _admin_character("Anselm", "House Vorontheim", false, 68, "human",
		{"dip": 18, "mar": 8, "stw": 22, "int": 15, "lrn": 16, "prw": 5},
		["Methodical", "Content", "Patient", "Homely"], "Broken")
	anselm_id = anselm.id
	realms[0].ruler_id = anselm.id
	_seat_magister("Grand Magister", anselm.id, tick - 144)  # twelve years in the chair
	magister_wing[anselm.id] = "neutral"
	# his nephew — the dynasty's one Council-eligible spare. Placing him
	# is Anselm's political puzzle (brief §4); he doesn't know it yet.
	# Canonized per the Gazetteer v1.1 addendum: 34, a Records Sublevel
	# deputy in the Magister's blue before he holds any seat.
	var sevrin := _admin_character("Sevrin", "House Vorontheim", false, 34, "human",
		{"dip": 16, "mar": 8, "stw": 20, "int": 14, "lrn": 20, "prw": 6},
		["Methodical", "Ambitious", "Bureaucrat"], "Pragmatic")
	sevrin.father_id = -1  # Anselm's brother's son; the brother died five years before the Silence
	sevrin_id = sevrin.id
	# the Vael Compact legacy (brief §6): the academy connection is real,
	# and twelve years of the chair paid for the declaration
	var vroot := root_house_id(anselm.dynasty_id)
	dynasties[vroot].renown = 280.0
	dynasties[vroot].legacies.append("The Vael Compact")
	dynasties[vroot].renown -= float(LEGACIES["The Vael Compact"]["cost"])
	# Seat 2 — Economic Affairs: the Reformist wing's leader (Canon Updates
	# Post-Caeris v1.0 locks his Diplomacy at 20)
	var halloran := _admin_character("Halloran", "House Verith", false, 45, "human",
		{"dip": 20, "mar": 6, "stw": 17, "int": 11, "lrn": 15, "prw": 5},
		["Ambitious", "Honest"], "Pragmatic")
	halloran_id = halloran.id
	_seat_magister("Economic Affairs", halloran.id, tick - 60)
	magister_wing[halloran.id] = "reformist"
	# Seat 3 — Foreign Affairs: the Traditionalist wing's leader
	# Canon Updates Post-Caeris v1.0 locks the composition: Paranoid and
	# Cruel join Ambitious (Brave superseded — the canon trio fills the
	# personality cap)
	var davriand := _admin_character("Davriand", "House Karn", false, 40, "half_orc",
		{"dip": 13, "mar": 14, "stw": 14, "int": 15, "lrn": 12, "prw": 12},
		["Ambitious", "Paranoid", "Cruel"], "Opportunistic")
	davriand_id = davriand.id
	# eight years at the borders — the Traditionalist standard-bearer's
	# career started early and never slowed
	_seat_magister("Foreign Affairs", davriand.id, tick - 96)
	magister_wing[davriand.id] = "traditionalist"
	# Seat 4 — Clerical Registry (now moot): the moderate voice
	# Canon Updates Post-Caeris v1.0 locks the composition: Content, Patient
	var kreth := _admin_character("Kreth", "House Anford", false, 62, "human",
		{"dip": 13, "mar": 5, "stw": 11, "int": 8, "lrn": 14, "prw": 3},
		["Content", "Patient"], "Broken")
	kreth_id = kreth.id
	_seat_magister("Clerical Registry", kreth.id, tick - 200)
	magister_wing[kreth.id] = "reformist"
	# Seat 5 — the Records Sublevel is already occupied: Veril Ormand
	# (Magic v1.0's Architect) has held it thirty-four silent years. He
	# stays in the main stream's dice — his death was always the clock.
	_seat_magister("Records Sublevel", architect_id, tick - 500)
	if architect_id >= 0:
		magister_wing[architect_id] = "silent"
	# Seats 6-9 — the career administration, canonized with backstories in
	# the Gazetteer v1.1 addendum (ages per Opus's entries)
	var maren := _admin_character("Maren", "House Solvey", true, 57, "human",
		{"dip": 12, "mar": 4, "stw": 16, "int": 10, "lrn": 13, "prw": 3},
		["Methodical", "Patient"], "Pragmatic")
	_seat_magister("Chancellor", maren.id, tick - 180)
	# Gazetteer v1.1: "firmly Reformist-aligned but low-key" — her votes
	# follow Halloran through twenty-three years of loyalty, not through
	# wing membership; she is never a standard-bearer
	magister_wing[maren.id] = "neutral"
	var corvin := _admin_character("Corvin", "House Draeth", false, 51, "human",
		{"dip": 7, "mar": 16, "stw": 9, "int": 9, "lrn": 8, "prw": 11},
		["Brave", "Stoic"], "Zealous")
	_seat_magister("Master of War", corvin.id, tick - 120)
	magister_wing[corvin.id] = "traditionalist"
	var ellard := _admin_character("Ellard", "House Nym", false, 59, "human",
		{"dip": 9, "mar": 3, "stw": 10, "int": 11, "lrn": 17, "prw": 2},
		["Methodical", "Compassionate"], "Broken")
	_seat_magister("Chief Physician", ellard.id, tick - 150)
	magister_wing[ellard.id] = "neutral"
	# Odric Vasse: the seed's coin-flip historically landed Broken, and the
	# Gazetteer v1.1 addendum canonized exactly that — the draw is still
	# consumed (the arng stream must not shift) but the answer is fixed.
	var _chaplain_roll := arng.randf()
	var odric := _admin_character("Odric", "House Vasse", false, 61, "human",
		{"dip": 12, "mar": 4, "stw": 8, "int": 7, "lrn": 14, "prw": 3},
		["Patient", "Content"], "Broken")
	odric_id = odric.id
	_seat_magister("Court Chaplain", odric.id, tick - 100)
	magister_wing[odric.id] = "neutral"
	# off-council: the Chief Spymaster, who reports only upward
	var tess := _admin_character("Tess", "House Mareck", true, 51, "human",
		{"dip": 10, "mar": 7, "stw": 11, "int": 19, "lrn": 13, "prw": 8},
		["Methodical", "Deceitful"], "Pragmatic")
	mareck_id = tess.id
	# the voting blocs, seeded as memories — opinion_of does the politics
	add_memory(halloran, "shared cause", kreth.id, 25.0, 0.5)
	add_memory(kreth, "shared cause", halloran.id, 25.0, 0.5)
	add_memory(halloran, "a useful ally in the ledgers", maren.id, 15.0, 0.5)
	add_memory(maren, "twenty-three years of shared work", halloran.id, 20.0, 0.5)
	add_memory(davriand, "shared cause", corvin.id, 25.0, 0.5)
	add_memory(corvin, "shared cause", davriand.id, 25.0, 0.5)
	add_memory(halloran, "the wing across the table", davriand.id, -35.0, 0.5)
	add_memory(davriand, "the wing across the table", halloran.id, -35.0, 0.5)
	add_memory(maren, "the Grand Magister's trust", anselm.id, 30.0, 0.5)
	add_memory(ellard, "an old confidence", kreth.id, 25.0, 0.5)
	add_memory(kreth, "an old confidence", ellard.id, 25.0, 0.5)
	add_memory(davriand, "a liability in the chair", anselm.id, -15.0, 0.5)
	_log("[b]The Council of Magisters sits.[/b] Grand Magister Anselm Vorontheim — twelve years in the chair, methodical, tired — presides over nine seats: Verith at the ledgers, Karn at the borders, Anford at the registry, the silent Records Sublevel, Solvey's administration, Draeth's garrisons, Nym's medicines, and Vasse's increasingly unanswered altar. Chief Spymaster Tess Mareck holds no seat, reports only upward, and knows more than she files.")
	_log("House Vorontheim declares the Vael Compact — the academies' tradition runs in the line, and the line has the renown to say so.")


func seated_magisters() -> Array:
	## The living Council, in seat order. Vacant seats simply aren't here.
	var out: Array = []
	for seat in MAGISTER_SEATS:
		if not magister_seats.has(seat):
			continue
		var hid := int(magister_seats[seat]["holder"])
		if hid < 0:
			continue
		var c: SimCharacter = characters.get(hid)
		if c != null and c.alive:
			out.append(c)
	return out


func magister_seat_of(char_id: int) -> String:
	for seat in MAGISTER_SEATS:
		if magister_seats.has(seat) and int(magister_seats[seat]["holder"]) == char_id:
			return seat
	return ""


func grand_magister() -> SimCharacter:
	if not magister_seats.has("Grand Magister"):
		return null
	var hid := int(magister_seats["Grand Magister"]["holder"])
	if hid < 0:
		return null
	var c: SimCharacter = characters.get(hid)
	if c == null or not c.alive:
		return null
	return c


func _senior_magister() -> SimCharacter:
	## Longest-serving seated Magister — the tie-breaker and the Regent.
	## The Records Sublevel is senior to everyone and eligible for nothing.
	var best: SimCharacter = null
	var best_since := 999999
	for m in seated_magisters():
		if str(magister_wing.get(m.id, "neutral")) == "silent":
			continue
		var since := int(magister_seats[magister_seat_of(m.id)]["since"])
		if best == null or since < best_since:
			best = m
			best_since = since
	return best


func _wing_bias(matter: String, wing: String) -> float:
	if matter == "declaration of war":
		if wing == "traditionalist":
			return 3.0
		if wing == "reformist":
			return -2.0
	return 0.0


func magister_vote(matter: String, proposer_id: int, base: float) -> Dictionary:
	## Brief §3: every seated Magister votes by opinion, wing, and
	## temperament; the Records Sublevel abstains (it always has); the
	## Grand Magister's vote counts twice in a tie. Deterministic — no
	## dice — so any system may call it without touching a stream.
	## Every division is recorded (brief §Phase 7).
	var votes: Dictionary = {}
	var ayes := 0
	var nays := 0
	for m in seated_magisters():
		if str(magister_wing.get(m.id, "neutral")) == "silent":
			votes[m.id] = "abstain"
			continue
		if m.id == proposer_id:
			votes[m.id] = "aye"
			ayes += 1
			continue
		var s := base + float(opinion_of(m.id, proposer_id)) * 0.15 \
			+ _wing_bias(matter, str(magister_wing.get(m.id, "neutral")))
		if matter == "declaration of war":
			s += ai_weight(m, "aggression") * 0.05
		if s > 0.0:
			votes[m.id] = "aye"
			ayes += 1
		else:
			votes[m.id] = "nay"
			nays += 1
	var gm := grand_magister()
	if ayes == nays and gm != null and votes.has(gm.id) and str(votes[gm.id]) != "abstain":
		if str(votes[gm.id]) == "aye":
			ayes += 1
		else:
			nays += 1
		_log("The chamber ties on %s — and the Grand Magister's vote counts twice. It always has." % matter)
	var filled := seated_magisters().size()
	# a 9-seat Council with 2 vacant seats needs 4 votes, not 5 (brief §3)
	var needed := filled / 2 + 1
	var record := {"tick": tick, "matter": matter, "ayes": ayes, "nays": nays,
		"passed": ayes >= needed, "votes": votes}
	council_vote_history.append(record)
	if council_vote_history.size() > 60:
		council_vote_history.pop_front()
	# a vote spoken in the chamber is experience (Hero System v1.0 §3) —
	# ledger-only: no stat drifts from an auto-firing division
	for m in seated_magisters():
		if str(votes.get(m.id, "abstain")) != "abstain":
			award_hero_xp(m.id, HeroDB.XP_AWARDS["council_vote"], "the chamber heard them")
	return record


func call_no_confidence() -> String:
	## Brief §3: three or more Magisters may put the chair itself to the
	## question; two-thirds of the seated Council deposes. The deposed
	## keeps their life, their House, and nothing else.
	var gm := grand_magister()
	if gm == null:
		return "There is no Grand Magister to question."
	if not admin_interregnum.is_empty():
		return "The Council is already electing."
	var movers := 0
	for m in seated_magisters():
		if m.id != gm.id and str(magister_wing.get(m.id, "neutral")) != "silent" \
				and opinion_of(m.id, gm.id) <= -30:
			movers += 1
	if movers < 3:
		return "Fewer than three Magisters will put their names to the motion."
	var votes: Dictionary = {}
	var ayes := 0
	var nays := 0
	for m in seated_magisters():
		if str(magister_wing.get(m.id, "neutral")) == "silent":
			votes[m.id] = "abstain"
			continue
		if m.id == gm.id or opinion_of(m.id, gm.id) > -10:
			votes[m.id] = "nay"
			nays += 1
		else:
			votes[m.id] = "aye"
			ayes += 1
	var needed := int(ceilf(float(seated_magisters().size()) * 2.0 / 3.0))
	var passed := ayes >= needed
	council_vote_history.append({"tick": tick, "matter": "no confidence in the Grand Magister",
		"ayes": ayes, "nays": nays, "passed": passed, "votes": votes})
	if not passed:
		_log("The motion of no confidence fails, %d to %d. The chair remembers every aye." % [ayes, nays])
		for m in seated_magisters():
			if str(votes.get(m.id, "")) == "aye":
				add_memory(gm, "moved against my chair", m.id, -25.0, 1.5)
		return ""
	_log("[b]No confidence, %d to %d.[/b] %s is deposed — the seal passed to the table, the chamber silent, the election clock already running." % [
		ayes, nays, full_name(gm)])
	magister_seats["Grand Magister"] = {"holder": -1, "since": tick}
	_open_admin_interregnum()
	return ""


func _magister_succession(dead: SimCharacter) -> void:
	## Brief §4: nothing passes to the blood. The House keeps its seats
	## and its wealth; the chair goes to whoever the Council elects.
	magister_seats["Grand Magister"] = {"holder": -1, "since": tick}
	_earn_mythos(root_house_id(dead.dynasty_id), "Former Grand Magister Family")
	_log("[b]The Grand Magister is dead, and no blood inherits.[/b] House %s keeps what it held — its seats, its wealth, its name — and not the chair." % dynasties[dead.dynasty_id].surname())
	_open_admin_interregnum()


func _open_admin_interregnum() -> void:
	## The Administrative Interregnum (brief §7): the feudal four stages,
	## transformed. Treasury -> a Regent's thirty days; Blessing -> the
	## Council Endorsement; Homage Tour -> the Institutional Loyalty
	## Consolidation; Coronation -> the Council Election Vote.
	var regent := _senior_magister()
	if regent == null:
		# a Council of ghosts: the highest learning in the realm takes
		# the chair directly — there is no one left to elect anyone
		var fallback: SimCharacter = null
		for c in characters.values():
			if c.alive and c.realm_id == 0 and c.age_years(tick) >= ADULT_AGE \
					and (fallback == null or c.learning > fallback.learning):
				fallback = c
		if fallback != null:
			_seat_magister("Grand Magister", fallback.id, tick)
			realms[0].ruler_id = fallback.id
			_log("With no Council left to elect anyone, %s simply takes the chair. History will call it a magistracy anyway." % full_name(fallback))
		return
	realms[0].ruler_id = regent.id
	admin_interregnum = {"stage": 0, "regent": regent.id, "support": {}, "started": tick}
	_log("[b]Regency.[/b] Magister %s, the chamber's senior voice, holds the seal for thirty days of Council business while the election is prepared." % full_name(regent))


func election_candidates() -> Array:
	## Every seated Magister is eligible (brief §3) — except the Records
	## Sublevel, which neither runs nor votes. It never has.
	var out: Array = []
	for m in seated_magisters():
		if str(magister_wing.get(m.id, "neutral")) != "silent":
			out.append(m)
	return out


func _wing_leader(wing: String) -> int:
	## A wing's standard-bearer: the seated member with the strongest
	## demonstrated competence. At Year Zero this is Halloran for the
	## reformists and Davriand for the traditionalists, by construction.
	var best := -1
	var best_score := -1
	for m in seated_magisters():
		if str(magister_wing.get(m.id, "neutral")) != wing:
			continue
		var score: int = m.stewardship + m.learning + m.diplomacy
		if score > best_score:
			best = m.id
			best_score = score
	return best


func _ballot_of(voter: SimCharacter, cands: Array) -> Array:
	## One Magister's preferential ranking: opinion, wing loyalty,
	## demonstrated competence, whatever was promised during the
	## Consolidation — and themselves first, naturally.
	var support: Dictionary = admin_interregnum.get("support", {})
	var scored: Array = []
	for cand: SimCharacter in cands:
		var s := float(opinion_of(voter.id, cand.id))
		var vw := str(magister_wing.get(voter.id, "neutral"))
		var cw := str(magister_wing.get(cand.id, "neutral"))
		if vw == cw and vw != "neutral":
			s += 25.0
		# tenure: the chamber does not hand the seal to a man it seated
		# yesterday — Sevrin at two years is "junior" by canon's own word
		s += minf(float(tick - int(magister_seats[magister_seat_of(cand.id)]["since"])), 120.0) / 12.0
		# the Regent has held the seal through the whole crisis — the
		# chamber has just watched him do the job
		if int(admin_interregnum.get("regent", -1)) == cand.id:
			s += 8.0
		if (cw == "reformist" or cw == "traditionalist") and _wing_leader(cw) == cand.id:
			# the Wing-Leader Standing principle (Gazetteer v1.1): faction
			# organization is a first-class political skill — but the bloc's
			# weight accrues to its standard-bearer, not to every member.
			# The chamber respects the man who can already count votes; it
			# does not mistake the counted votes for candidates.
			var followers := 0
			for m2 in seated_magisters():
				if m2.id != cand.id and str(magister_wing.get(m2.id, "neutral")) == cw:
					followers += 1
			s += float(followers) * 8.0
		s += float(cand.stewardship + cand.learning + cand.diplomacy) / 3.0
		s += float(support.get(cand.id, {}).get(voter.id, 0.0))
		if voter.id == cand.id:
			s += 60.0 + (20.0 if voter.traits.has("Ambitious") else 0.0)
		scored.append({"s": s, "c": cand})
	scored.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["s"]) > float(y["s"]))
	var out: Array = []
	for e in scored:
		out.append(e["c"])
	return out


func _ai_consolidation() -> void:
	## The ninety days of chamber visits, on the Council's own dice. The
	## ambitious campaign hard; the Content don't campaign at all. The
	## player's lever is consolidate_support().
	var support: Dictionary = admin_interregnum.get("support", {})
	var voters := seated_magisters()
	if voters.is_empty():
		return
	for cand: SimCharacter in election_candidates():
		if cand.traits.has("Content"):
			continue
		var drive := 0.45 + float(cand.diplomacy) * 0.02
		if cand.traits.has("Ambitious"):
			drive += 0.30
		if arng.randf() > drive:
			continue
		var voter: SimCharacter = voters[arng.randi_range(0, voters.size() - 1)]
		if voter.id == cand.id:
			continue
		if not support.has(cand.id):
			support[cand.id] = {}
		support[cand.id][voter.id] = float(support[cand.id].get(voter.id, 0.0)) \
			+ 4.0 + float(cand.diplomacy) * 0.25
	admin_interregnum["support"] = support


func consolidate_support(candidate_id: int, magister_id: int) -> String:
	## The player's Institutional Loyalty Consolidation lever (brief §7):
	## sponsor a candidate's chamber visit — 20 gold into loyalty.
	if admin_interregnum.is_empty() or int(admin_interregnum["stage"]) < 1 \
			or int(admin_interregnum["stage"]) > 4:
		return "No consolidation window is open — the Council is not electing."
	var cand: SimCharacter = characters.get(candidate_id)
	var mag: SimCharacter = characters.get(magister_id)
	if cand == null or magister_seat_of(candidate_id) == "" \
			or str(magister_wing.get(candidate_id, "")) == "silent":
		return "That name is not on the ballot."
	if mag == null or magister_seat_of(magister_id) == "" \
			or str(magister_wing.get(magister_id, "")) == "silent":
		return "That vote is not in the chamber."
	if realms[0].gold < 20.0:
		return "The treasury cannot fund the visit (20 gold)."
	realms[0].gold -= 20.0
	var support: Dictionary = admin_interregnum.get("support", {})
	if not support.has(candidate_id):
		support[candidate_id] = {}
	support[candidate_id][magister_id] = float(support[candidate_id].get(magister_id, 0.0)) + 12.0
	admin_interregnum["support"] = support
	_log("A chamber visit is arranged: %s calls on %s, and the conversation is productive." % [
		full_name(cand), full_name(mag)])
	return ""


func _magister_election() -> void:
	## The Council Election Vote (brief §3): preferential ballots, ranks
	## to points (5-4-3-2-1), ties to seniority, office immediately.
	var cands := election_candidates()
	admin_interregnum["stage"] = 5
	if cands.is_empty():
		admin_interregnum = {}
		_open_admin_interregnum()
		return
	var points: Dictionary = {}
	for cand: SimCharacter in cands:
		points[cand.id] = 0
	for voter in seated_magisters():
		if str(magister_wing.get(voter.id, "neutral")) == "silent":
			continue
		var ranked := _ballot_of(voter, cands)
		for i in mini(ELECTION_RANKS, ranked.size()):
			var ranked_cand: SimCharacter = ranked[i]
			points[ranked_cand.id] = int(points[ranked_cand.id]) + (ELECTION_RANKS - i)
	var order := cands.duplicate()
	order.sort_custom(func(x: SimCharacter, y: SimCharacter) -> bool:
		if int(points[x.id]) != int(points[y.id]):
			return int(points[x.id]) > int(points[y.id])
		return int(magister_seats[magister_seat_of(x.id)]["since"]) < int(magister_seats[magister_seat_of(y.id)]["since"]))
	var winner: SimCharacter = order[0]
	var old_seat := magister_seat_of(winner.id)
	if old_seat != "" and old_seat != "Grand Magister":
		magister_seats[old_seat] = {"holder": -1, "since": tick}
	_seat_magister("Grand Magister", winner.id, tick)
	realms[0].ruler_id = winner.id
	last_election = {"winner": winner.id, "points": points, "refused": false}
	admin_interregnum = {}
	var standings := ""
	for i in mini(3, order.size()):
		var oc: SimCharacter = order[i]
		standings += "%s%s %d" % ["" if i == 0 else " · ", full_name(oc), int(points[oc.id])]
	_log("[b]The Council Election.[/b] The ballots are ranked, counted, and burned: %s." % standings)
	_log("[b]%s is Grand Magister of Vael.[/b] No coronation — a signature, a seal, and the weight of eight opinions." % full_name(winner))
	if order.size() >= 2:
		_refusal_check(winner, order[1], points)


func _refusal_check(winner: SimCharacter, runner: SimCharacter, points: Dictionary) -> void:
	## Brief §7's failure mode — the Administrative palace coup. A narrow
	## loser with the Master of War's friendship and a grudge against the
	## new chair may refuse the count.
	var margin := int(points[winner.id]) - int(points[runner.id])
	var mow: SimCharacter = null
	if magister_seats.has("Master of War"):
		mow = characters.get(int(magister_seats["Master of War"]["holder"]))
	var mow_favor := 0
	if mow != null and mow.alive:
		mow_favor = opinion_of(mow.id, runner.id)
	if margin > 2 or mow_favor < 40 or opinion_of(runner.id, winner.id) > -30:
		return
	last_election["refused"] = true
	var loser := runner
	var new_gm := winner
	raise_event(0, runner.id, "The Count Refused",
		"%s lost the chair by %d point%s — with the Master of War's garrisons friendly and no love for the winner. The chamber holds its breath: accept the count, or break the thing that makes counts matter." % [
			full_name(runner), margin, "" if margin == 1 else "s"],
		[
			{"label": "Concede — with ice in the voice", "base": 8.0, "ai": {"patience": 0.5},
				"effect": func() -> void:
					for m in seated_magisters():
						if m.id != loser.id:
							add_memory(m, "refused the count, then bent", loser.id, -20.0, 1.0)
					_log("%s concedes. The word 'irregularities' is used. No one forgets it was used." % full_name(loser))},
			{"label": "Refuse the result", "base": 0.0, "ai": {"aggression": 0.6, "scheming": 0.3},
				"effect": func() -> void:
					realms[0].prestige = maxf(-100.0, realms[0].prestige - 25.0)
					realms[0].tyranny = minf(100.0, realms[0].tyranny + 10.0)
					var seat := magister_seat_of(loser.id)
					if seat != "" and seat != "Grand Magister":
						magister_seats[seat] = {"holder": -1, "since": tick}
					add_memory(new_gm, "refused my election", loser.id, -60.0, 1.0)
					_log("[b]Failure of Institutional Order.[/b] %s refuses the count; for nine days two Grand Magisters sign papers. The garrisons do not move, the refusal collapses — and the Free Cities' pamphleteers set it in type by week's end: Vael's own Council cannot count." % full_name(loser))},
		], false, true)


func nominate_magister(seat: String, char_id: int) -> String:
	## Brief §3: vacant seats fill by Grand Magister nomination plus
	## Council confirmation. The nominee needs Vael standing, Learning
	## 12+, and a name no investigation has touched.
	if not MAGISTER_SEATS.has(seat) or seat == "Grand Magister":
		return "That is not a seat the chair fills by nomination."
	if not magister_seats.has(seat) or int(magister_seats[seat]["holder"]) >= 0:
		return "The seat is occupied."
	if not admin_interregnum.is_empty():
		return "No appointments while the Council elects."
	if not pending_nomination.is_empty():
		return "A nomination already stands before the Council."
	var c: SimCharacter = characters.get(char_id)
	if c == null or not c.alive or c.realm_id != 0:
		return "The Council seats only the Magistocracy's own."
	if c.age_years(tick) < ADULT_AGE:
		return "Too young for the chamber."
	if c.learning < MAGISTER_MIN_LEARNING:
		return "Learning %d — the Council seats no one without the academies' arithmetic (12+)." % c.learning
	if c.denounced:
		return "The name is under investigation — the Council will not hear it."
	if magister_seat_of(c.id) != "":
		return "They already hold a seat."
	if c.id == realms[0].ruler_id:
		return "The chair cannot nominate itself."
	pending_nomination = {"seat": seat, "nominee": char_id}
	_log("The Grand Magister sends a name to the Council: %s, for the %s seat. Confirmation is next month's business." % [full_name(c), seat])
	return ""


func _confirmation_vote() -> void:
	var seat := str(pending_nomination["seat"])
	var nominee: SimCharacter = characters.get(int(pending_nomination["nominee"]))
	pending_nomination = {}
	if nominee == null or not nominee.alive or not magister_seats.has(seat) \
			or int(magister_seats[seat]["holder"]) >= 0:
		return
	var mv := magister_vote("confirmation of %s" % full_name(nominee), nominee.id, 2.0)
	if bool(mv["passed"]):
		_seat_magister(seat, nominee.id, tick)
		magister_wing[nominee.id] = "neutral"
		_log("[b]%s is confirmed to the Council[/b] — the %s seat, %d to %d." % [
			full_name(nominee), seat, int(mv["ayes"]), int(mv["nays"])])
	else:
		rejected_nominees[nominee.id] = tick
		_log("The Council refuses %s, %d to %d. The seat stays empty — and the quorum arithmetic shrinks with it." % [
			full_name(nominee), int(mv["ayes"]), int(mv["nays"])])


func _ai_nominations() -> void:
	## The government runs itself between player decisions: the Grand
	## Magister sends the most academy-fit name for the emptiest chair.
	## Deterministic pick — no dice.
	var gm := grand_magister()
	if gm == null:
		return
	for seat in MAGISTER_SEATS:
		if seat == "Grand Magister" or not magister_seats.has(seat):
			continue
		if int(magister_seats[seat]["holder"]) >= 0:
			continue
		var best: SimCharacter = null
		for c in characters.values():
			if not c.alive or c.realm_id != 0 or c.age_years(tick) < ADULT_AGE or c.denounced:
				continue
			if c.learning < MAGISTER_MIN_LEARNING or c.id == mareck_id or c.id == realms[0].ruler_id:
				continue
			if magister_seat_of(c.id) != "":
				continue
			if tick - int(rejected_nominees.get(c.id, -999)) < 24:
				continue
			if best == null or c.learning + c.stewardship > best.learning + best.stewardship:
				best = c
		if best != null:
			var _err := nominate_magister(seat, best.id)
			return  # one name a season


func _admin_tick() -> void:
	## The Council's month: vacancies noted, scheduled beats fired,
	## elections advanced, nominations heard. All dice on arng.
	if magister_seats.is_empty():
		return
	for seat in MAGISTER_SEATS:
		if not magister_seats.has(seat) or seat == "Grand Magister":
			continue
		var hid := int(magister_seats[seat]["holder"])
		if hid >= 0:
			var h: SimCharacter = characters.get(hid)
			if h == null or not h.alive:
				magister_seats[seat] = {"holder": -1, "since": tick}
				_log("The %s seat stands empty — the Council notes it, and moves the agenda." % seat)
	_admin_beats()
	if not admin_interregnum.is_empty():
		_admin_interregnum_tick()
		return
	if not pending_nomination.is_empty():
		_confirmation_vote()
	elif tick % 6 == 0:
		_ai_nominations()


func _admin_interregnum_tick() -> void:
	if int(admin_interregnum.get("started", -1)) == tick:
		return  # the month of the death belongs to the Regent's thirty days
	var stage := int(admin_interregnum["stage"]) + 1
	admin_interregnum["stage"] = stage
	match stage:
		1:
			var names := ""
			for cand: SimCharacter in election_candidates():
				names += ("" if names == "" else ", ") + full_name(cand)
			_log("[b]The Council Endorsement.[/b] Sixty days of public assembly: the candidates state their cases — %s — and the galleries keep score." % names)
		2:
			_log("[b]The Institutional Loyalty Consolidation opens.[/b] Ninety days of chamber visits: every vote is a door, and every door wants a different key.")
			_ai_consolidation()
		3, 4:
			_ai_consolidation()
		5:
			_magister_election()


func _admin_beats() -> void:
	## The scheduled canonical arc (brief §5): the Chaplain breaks first,
	## the Grand Magister asks his questions, and Month 34 answers them.
	match tick:
		9:
			_chaplain_crisis()
		20:
			_raise_anselm_questions()
		27:
			_raise_mareck_silence()
		31:
			_raise_tasters_doubt()
		33:
			# the 34th month of the Silence — Year 3, Month 10 (brief §5)
			_poisoning_beat()
		70:
			var kreth: SimCharacter = characters.get(kreth_id)
			if kreth != null and kreth.alive:
				_kill(kreth, "dies of the long fatigue he stopped hiding years ago,")


func _chaplain_crisis() -> void:
	## Module 9 §8 (via the Administrative brief's Phase 6): the most
	## fragile seat on the Council breaks first — and how it breaks is now
	## a choice with up to five faces. The AI walks its trait-matched path
	## (base 16 clears every jitter); the player holds all of them.
	if chaplain_crisis_fired or not magister_seats.has("Court Chaplain"):
		return
	chaplain_crisis_fired = true
	var chap: SimCharacter = characters.get(int(magister_seats["Court Chaplain"]["holder"]))
	if chap == null or not chap.alive:
		return
	var who := chap
	var zeal := chap.traits.has("Zealous")
	var broken := chap.traits.has("Broken")
	var prag := chap.traits.has("Pragmatic")
	var options: Array = [
		{"label": "Intensify the practice — the rites must not waver", "base": 16.0 if zeal else 2.0,
			"ai": {"orthodoxy": 0.2},
			"effect": func() -> void:
				magister_wing[who.id] = "traditionalist"
				var dav: SimCharacter = characters.get(davriand_id)
				if dav != null and dav.alive:
					add_memory(who, "the only wing that still kneels", davriand_id, 20.0, 0.5)
					add_memory(dav, "a useful conviction", who.id, 15.0, 0.5)
				var hal: SimCharacter = characters.get(halloran_id)
				if hal != null and hal.alive:
					add_memory(hal, "a reactionary at the altar", who.id, -15.0, 1.0)
				add_stress(who, 20.0, "prayers into a silent sky")
				_shift_coherence("Aelindran Orthodox", 0.05)
				_log("[b]The Court Chaplain redoubles.[/b] %s answers the Silence with more rite, not less — dawn offices, doubled fasts, and a seat that now votes with Davriand Karn's wing. The Council's arithmetic shifts by one." % full_name(who))},
		{"label": "Set down the office — the bees still answer", "base": 16.0 if broken else 1.0,
			"effect": func() -> void:
				magister_seats["Court Chaplain"] = {"holder": -1, "since": tick}
				_shift_coherence("Aelindran Orthodox", -0.05)
				_log("[b]The Court Chaplain resigns.[/b] %s sets the seal on the altar cloth, walks out the river gate, and takes up beekeeping outside the walls. The bees, he says, still answer. The Council's arithmetic shrinks by one seat until a name can be agreed." % full_name(who))},
		{"label": "Cross to the Reformed practice — the saying is ours; the hearing never was", "base": 16.0 if prag else 2.5,
			"effect": func() -> void:
				_activate_faith("Aelindran Reformed", 0.15)
				_shift_coherence("Aelindran Orthodox", -0.10)
				_convert_faith(who, "Aelindran Reformed")
				for m in seated_magisters():
					if str(magister_wing.get(m.id, "neutral")) == "traditionalist":
						add_memory(m, "the altar turned reformer", who.id, -20.0, 1.0)
				_log("[b]The Court Chaplain crosses to the Reformed practice.[/b] %s keeps the seat and the candles both — and now teaches that the saying of the rite was always the priest's whole responsibility. The Traditionalist wing takes notes." % full_name(who))},
		{"label": "Walk out — and teach what the Silence actually said", "base": 2.0 if broken else 0.0,
			"effect": func() -> void:
				magister_seats["Court Chaplain"] = {"holder": -1, "since": tick}
				_activate_faith("The Silent Path", 0.0)
				_shift_coherence("Aelindran Orthodox", -0.15)
				_convert_faith(who, "The Silent Path")
				_log("[b]The Court Chaplain leaves the government.[/b] %s abandons office and altar together, and takes a place in a quiet gathering that holds the Silence itself to be the pantheon's final word. The seat stands empty; the teaching does not." % full_name(who))},
	]
	if chap.traits.has("Threshold-Sensitive"):
		# the addendum's fifth path: attend what still answers
		options.append({"label": "Pivot to the thresholds — attend what still answers", "base": 18.0,
			"effect": func() -> void:
				_add_trait(who, "Gravewarden-Sworn")
				_log("[b]The Court Chaplain turns to the thresholds.[/b] %s keeps the seat but sets aside the pantheon's coordination for the older practice — births witnessed, deaths received, crossings marked. That work, everyone has noticed, still answers." % full_name(who))})
	raise_event(0, chap.id, "The Chaplain's Faith Crisis",
		"The Court Chaplain's prayers have failed all year, and the failure is now a matter of Council record. The altar is cold, the offices thinly attended — and the question can no longer be tabled: what is the seat *for* now?",
		options, false, false, true)


func _raise_anselm_questions() -> void:
	var a: SimCharacter = characters.get(anselm_id)
	if a == null or not a.alive or realms[0].ruler_id != anselm_id:
		return
	raise_event(0, anselm_id, "The Grand Magister's Questions",
		"Twelve years in the chair have taught Anselm which archives are best left unopened. But the Records Sublevel's history holds an anomaly — a Council session, eighty-eight years old, whose minutes exist only as a page-count. He could ask. Quietly.",
		[
			{"label": "Ask the questions — quietly", "base": 16.0, "ai": {"patience": 0.3},
				"effect": func() -> void:
					_log("The Grand Magister begins asking about the Records Sublevel — politely, obliquely, and to exactly the wrong people. Somewhere below the archive, operations become more difficult.")},
			{"label": "Let the archives sleep", "base": 0.0, "ai": {"scheming": -0.5},
				"effect": func() -> void:
					anselm_protection += 1
					_log("Anselm closes the file unread. Whatever Year 112 was, it will keep — and no one is provoked into anything.")},
		], false, true)


func _raise_mareck_silence() -> void:
	var a: SimCharacter = characters.get(anselm_id)
	if a == null or not a.alive or realms[0].ruler_id != anselm_id:
		return
	raise_event(0, anselm_id, "The Spymaster's Silence",
		"Tess Mareck's monthly report is two pages. Anselm has run enough committees to know when two pages are standing in front of forty. She is protecting him from something — or protecting something from him.",
		[
			{"label": "Trust her discretion", "base": 16.0, "ai": {"patience": 0.4},
				"effect": func() -> void:
					_log("Anselm signs the two-page report unquestioned. Tess Mareck files the other forty where no Council subpoena will ever find them.")},
			{"label": "Demand the full assessment", "base": 0.0, "ai": {"scheming": 0.4},
				"effect": func() -> void:
					anselm_protection += 1
					_log("Anselm demands everything. The full pattern is worse than he imagined — and it includes an anomaly inside Mareck's own operational team. He reads that page twice.")},
		], false, true)


func _raise_tasters_doubt() -> void:
	var a: SimCharacter = characters.get(anselm_id)
	if a == null or not a.alive or realms[0].ruler_id != anselm_id:
		return
	raise_event(0, anselm_id, "A Wrongness at Table",
		"Chief Physician Nym mentions it almost apologetically: a decanter moved between courses at the last Council dinner, and the steward who moved it cannot be found on any roster. Probably nothing. The Physician has been wrong before. He does not look like a man who thinks he is wrong.",
		[
			{"label": "The Council does not dine in fear", "base": 16.0, "ai": {"patience": 0.3},
				"effect": func() -> void:
					_log("Anselm thanks the Physician and changes the subject. The autumn dinner will be held as it has been held for two hundred years.")},
			{"label": "Double the cup-bearers; test every dish", "base": 0.0, "ai": {"scheming": 0.5},
				"effect": func() -> void:
					anselm_protection += 1
					_log("Quietly, without minutes, the Grand Magister's table acquires new protocols. The kitchen staff notice. So does someone else.")},
		], false, true)


func _poisoning_beat() -> void:
	## Month 34 — Year 3, Month 10 (brief §5). Scripted, not rolled: the
	## poisoner is one of Tess Mareck's own operatives, suborned by the
	## Traditionalist wing. Two protective choices before tonight foil it.
	if poisoning_fired:
		return
	poisoning_fired = true
	var a: SimCharacter = characters.get(anselm_id)
	if a == null or not a.alive or realms[0].ruler_id != anselm_id:
		return
	var dav: SimCharacter = characters.get(davriand_id)
	if anselm_protection >= 2:
		_log("[b]The cup is caught before it pours.[/b] At the Council's autumn dinner a doubled cup-bearer stops a hand at the decanter — one of Tess Mareck's own operatives, suborned by coin that traces toward the Traditionalist wing. The confession names no Magister. Everyone hears the name anyway.")
		if dav != null and dav.alive:
			_add_secret(davriand_id, "magister_poisoning")
			for s in secrets:
				if int(s["subject"]) == davriand_id and str(s["type"]) == "magister_poisoning":
					s["known"][0] = true
			add_memory(a, "sent poison to my table", davriand_id, -60.0, 1.0)
			for m in seated_magisters():
				if m.id != davriand_id and m.id != anselm_id:
					add_memory(m, "the autumn dinner", davriand_id, -20.0, 2.0)
		return
	if dav != null:
		_add_secret(davriand_id, "magister_poisoning")
		dynasties[root_house_id(dav.dynasty_id)].poisonings += 1
	_log("[b]The autumn dinner of the Council of Magisters.[/b] The wine is tested, the dishes shared, the cup the Grand Magister's own — and the hand that dosed it belonged to Tess Mareck's covert arm, turned by coin that traces, in ways no inquiry will ever prove, toward the Traditionalist wing.")
	_kill(a, "is poisoned at the Council's autumn dinner —")


# --------------------------------- Religion & the Silence (Module 9 v1.0)
# Opus's mini-brief (2026-07-08): NOT a religion module — the module that
# models the collapse of pre-Silence religious authority and the successor
# institutions rising in the vacuum. Five faiths at Year Zero, heresy as
# the natural state, the orthodoxy AI axis live as the decision-scoring
# spine — and the God of Thresholds (addendum) running underneath it all,
# the one theology that never went silent. All faith dice roll on `frng`
# (own seed); the canonical practitioners are `faith_cast`.

func _add_faith(fname: String, active: bool, coherence: float, equilibrium: float,
		membership: float, alignment: float, tenets: Array, authorities: Array,
		parent: String = "") -> void:
	faiths[fname] = {"name": fname, "active": active, "coherence": coherence,
		"equilibrium": equilibrium, "membership": membership,
		"orthodoxy_alignment": alignment, "tenets": tenets,
		"authorities": authorities, "parent": parent, "founded": tick,
		"pressure": 0.0}


func faith_of(c: SimCharacter) -> String:
	## What a soul answers to: the recorded faith, or the culture's
	## default where no conversion has ever been asked of them.
	if c == null:
		return ""
	if c.faith != "":
		return c.faith
	return _default_faith_of(c)


func _default_faith_of(c: SimCharacter) -> String:
	## Brief §2: the Magistocracy's academics and reformists have quietly
	## secularized; the uncovered cultures keep their own practices; the
	## rest of the continent is (still, at Year Zero) Aelindran Orthodox.
	if str(magister_wing.get(c.id, "")) == "reformist" or c.traits.has("Academy-Sworn"):
		return "The Vael Rationalist Faith"
	if FOLK_FAITHS.has(c.culture):
		return str(FOLK_FAITHS[c.culture])
	return "Aelindran Orthodox"


func _faith_character(p_name: String, house_name: String, female: bool, age: int,
		realm_id: int, race: String, stats: Dictionary, traits: Array,
		response: String) -> SimCharacter:
	## A seeded canonical practitioner: a real soul whose fate is theology
	## and scheduled beats, never the actuarial tables.
	var dyn: Dynasty = null
	for d: Dynasty in dynasties.values():
		if d.name == house_name:
			dyn = d
			break
	if dyn == null:
		dyn = Dynasty.new(dynasties.size(), house_name)
		dynasties[dyn.id] = dyn
	var c := _create_character(p_name, female, tick - age * 12 - frng.randi_range(0, 11), dyn.id, realm_id)
	c.race = race
	for k in stats:
		c.set(STAT_PROPS[k], clampi(int(stats[k]), 1, 30))
	c.genome = Genetics.founder(frng)
	for t in traits:
		_add_trait(c, str(t))
	_add_trait(c, response)
	faith_cast[c.id] = true
	return c


func _seed_faiths() -> void:
	## Year Zero: five faiths per the brief's §2, the Patron network as a
	## covert non-faith, and the God of Thresholds' canonical practitioners.
	frng.seed = 999
	_add_faith("Aelindran Orthodox", true, 0.60, 0.55, 0.60, 0.90,
		["The pantheon exists and receives prayer.",
		"Rite must be performed correctly regardless of visible response.",
		"The Silence is a test, a chastisement, or a temporary condition.",
		"Heresy must be actively opposed."],
		["the Vael cathedral", "the Pellar cathedral", "Halven's parish network",
		"roughly 200 circuit priests"])
	_add_faith("Aelindran Reformed", false, 0.50, 0.70, 0.0, 0.30,
		["Rite must be performed correctly regardless of divine response.",
		"The Silence's nature is unknown but not disqualifying.",
		"Ordination is community recognition, not divine mandate.",
		"Alternative traditions may be complementary rather than heretical."],
		["Vesper's End (Selene Tharn's unofficial temple)",
		"Halvet's post-priestess community"])
	_add_faith("The Silent Path", false, 0.35, 0.38, 0.0, -0.20,
		["The pantheon has spoken finally through their absence.",
		"The ceremony was itself the message; prayer is now meaningless.",
		"Institutional religion is a form of denial.",
		"The world's ordering must be secular from this point forward."],
		["quiet gatherings, not temples"])
	_add_faith("The Brushgate Order", true, 0.85, 0.85, 0.005, -0.10,
		["The body remembers what the gods forgot.",
		"Be present with what is dying.",
		"Practice is discipline, not devotion.",
		"Race is irrelevant; discipline is universal."],
		["local mentor networks", "roughly 200 wandering practitioners"])
	_add_faith("The Vael Rationalist Faith", true, 0.75, 0.75, 0.17, 0.00,
		["Institutions produce legitimacy through demonstrated effectiveness.",
		"Divine mandate is not required for governance.",
		"Scholarly reason is the foundation of political authority.",
		"Religion is a private matter; public authority is secular."],
		["the Vael Council of Magisters", "the Vael academies", "the Iron Library"])
	# every living soul takes a starting faith (brief Phase 2)
	for c in characters.values():
		if c.alive and c.faith == "":
			c.faith = _default_faith_of(c)
	# --- the God of Thresholds (addendum §2.7): the canonical practitioners ---
	# Halvar Stenn, the Order's most respected living member, keeps the
	# threshold-shrine work along the Marn's Crossing road; his daughter
	# carries the practice in the blood.
	var halvar := _faith_character("Halvar", "House Stenn", false, 50, 0, "half_orc",
		{"dip": 12, "mar": 9, "stw": 8, "int": 7, "lrn": 11, "prw": 12},
		["Focused", "Patient", "Stoic", "Gravewarden-Sworn"], "Pragmatic")
	halvar_id = halvar.id
	halvar.faith = "Aelindran Orthodox"  # the Order works under Aelindran auspices; its practice is its own
	var alenna := _faith_character("Alenna", "House Stenn", true, 20, 0, "half_orc",
		{"dip": 10, "mar": 5, "stw": 7, "int": 8, "lrn": 12, "prw": 8},
		["Compassionate", "Threshold-Sensitive"], "Pragmatic")
	alenna_id = alenna.id
	alenna.faith = "Aelindran Orthodox"
	alenna.father_id = halvar.id
	halvar.children_ids.append(alenna.id)
	# Mother Anra Halden of Halvet — she left religious office in Year Two
	# of the Silence, and the Silent Path will find her (canon, Faction Map)
	var pellar := _map_realm_named("Pellar")
	if pellar >= 0:
		var anra := _faith_character("Anra", "House Halden", true, 44, pellar, "human",
			{"dip": 13, "mar": 3, "stw": 9, "int": 8, "lrn": 14, "prw": 3},
			["Compassionate", "Patient"], "Broken")
		anra_id = anra.id
		anra.culture = "free_city"
		anra.faith = "Aelindran Orthodox"
	# Ariorwe Thaladris: 120 names carried is long-timescale threshold-work
	# (the Faction Cast promotion to canon) — the blood was always sensitive
	var thaladris := _map_realm_named("Thaladris")
	var ariorwe := cast_ruler_of(thaladris)
	if ariorwe != null and not ariorwe.traits.has("Threshold-Sensitive"):
		_add_trait(ariorwe, "Threshold-Sensitive")
	# Canon Updates Post-Caeris v1.0: 285 years of the Bardic tradition is
	# Focused — the practice defines her more than any single event
	if ariorwe != null and not ariorwe.traits.has("Focused"):
		_add_trait(ariorwe, "Focused")
	_log("[b]The faiths of Khessar at Year Zero:[/b] the Aelindran pantheon still holds six souls in ten — institutionally dominant, doctrinally fracturing, and six years into a sky that does not answer. The Magistocracy's chambers have quietly stopped expecting it to. The Brushgate Order's discipline needs no answer. And along the roads, the Gravewardens' carved birds still cross their dead properly — the one practice the Silence never touched.")
	_log("Halvar Stenn works the threshold-shrine on the Marn's Crossing road — the Gravewarden Order's most respected living member, receiving the dead of two peoples. His daughter Alenna feels the crossings before others see them.")


func faith_rec(fname: String) -> Dictionary:
	return faiths.get(fname, {})


func active_faiths() -> Array:
	var out: Array = []
	for fname in faiths:
		if bool(faiths[fname]["active"]):
			out.append(faiths[fname])
	return out


func _shift_coherence(fname: String, amount: float) -> void:
	if not faiths.has(fname):
		return
	var f: Dictionary = faiths[fname]
	if not bool(f["active"]):
		return
	f["coherence"] = clampf(float(f["coherence"]) + amount, 0.01, 0.99)


func _activate_faith(fname: String, coherence_bonus: float) -> void:
	## A movement crosses from data record to living faith (brief §2).
	if not faiths.has(fname):
		return
	var f: Dictionary = faiths[fname]
	if bool(f["active"]):
		_shift_coherence(fname, coherence_bonus)
		return
	f["active"] = true
	f["founded"] = tick
	f["coherence"] = clampf(float(f["coherence"]) + coherence_bonus, 0.01, 0.99)
	if float(f["membership"]) <= 0.0:
		f["membership"] = 0.01 if fname == "Aelindran Reformed" else 0.005


func _religion_tick() -> void:
	## The monthly theology: coherence drifts, membership bleeds, heresy
	## pressure accumulates, and the thresholds are attended.
	if faiths.is_empty():
		return
	_faith_beats()
	_coherence_tick()
	_membership_tick()
	_heresy_tick()
	_patron_state_tick()
	_ai_threshold_rejection_tick()
	if tick % 3 == 0:
		_cathedral_tick()
		_threshold_maintenance_tick()
		_compact_ceremony_tick()
	if tick % 6 == 3:
		_faith_change_tick()
	if tick % 12 == 0 and tick > 0:
		_faith_consideration_tick()


func _faith_beats() -> void:
	## The scheduled canonical arc (brief §2): the successor movements
	## arrive on the clock the Faction Map wrote for them.
	match tick:
		16:
			var f: Dictionary = faiths["Aelindran Reformed"]
			if not bool(f["active"]):
				_activate_faith("Aelindran Reformed", 0.0)
				_shift_coherence("Aelindran Orthodox", -0.03)
				_log("[b]Vesper's End gains formal recognition.[/b] Selene Tharn's unofficial temple is entered on a Free City charter roll, and the movement it anchors has a name now: Aelindran Reformed. Practice as its own reward — the saying of the prayer was always the priest's part; the hearing was someone else's.")
			# Gazetteer v1.1: Odric practices Reformed after his resignation —
			# quietly, among the hives, without ever announcing anything
			var odric: SimCharacter = characters.get(odric_id)
			if odric != null and odric.alive and magister_seat_of(odric_id) == "" \
					and faith_of(odric) == "Aelindran Orthodox":
				odric.faith = "Aelindran Reformed"
				_log("Word from outside the walls: the beekeeper who was Court Chaplain keeps the offices still — the Reformed way now, said for their own sake, to no one in particular. He has not announced anything. He simply changed what the saying was for.")
		30:
			var f2: Dictionary = faiths["The Silent Path"]
			if not bool(f2["active"]):
				_activate_faith("The Silent Path", 0.0)
				_shift_coherence("Aelindran Orthodox", -0.03)
				var anra: SimCharacter = characters.get(anra_id)
				if anra != null and anra.alive:
					anra.faith = "The Silent Path"
					_log("[b]The first teacher of the Silent Path.[/b] Mother Anra Halden — once priestess of Halvet, who set down the office in Year Two — begins receiving visitors at her cheese-house. Her teaching is short: the pantheon has already spoken, through their absence, and the ceremony was itself the message. The quiet gatherings multiply.")
				else:
					_log("[b]The Silent Path finds its first teachers[/b] — quiet gatherings in the Free Cities, holding the Silence itself to be the pantheon's final revelation. No temples. No offices. No further practice required, or possible.")
			_raise_bee_yard_gathering()


func _raise_bee_yard_gathering() -> void:
	## Gazetteer v1.1: Silent Path teachers approach Odric Vasse from Year
	## Two onward — a founding teacher's legitimacy, if he'll give it. His
	## arc is genuinely open (Opus's ruling): no trait-matched rail here;
	## the dice, or the player, decide.
	var odric: SimCharacter = characters.get(odric_id)
	if odric == null or not odric.alive or magister_seat_of(odric_id) != "":
		return
	if not bool(faiths["The Silent Path"]["active"]):
		return
	var who := odric
	raise_event(0, odric.id, "The Gathering at the Bee-Yard",
		"Three quiet visitors come to the beekeeper who was Court Chaplain. They do not ask him to pray. They ask him to teach — because a founding voice who once held the pantheon's highest seat in Vael would say, better than any argument could, that the Silence itself was the final sermon.",
		[
			{"label": "Teach — the absence was the message", "base": 3.0,
				"effect": func() -> void:
					_convert_faith(who, "The Silent Path")
					_shift_coherence("The Silent Path", 0.05)
					_shift_coherence("Aelindran Orthodox", -0.03)
					_log("[b]Odric Vasse becomes a founding teacher of the Silent Path.[/b] The man who kept Vael's highest altar now teaches, gently, that no altar was ever the point — and his old office does the arguing for him. The movement gains what it could not buy: legitimacy.")},
			{"label": "Decline — the bees still answer", "base": 3.0,
				"effect": func() -> void:
					_log("Odric Vasse hears the visitors out, feeds them, and sends them off with honey. He will not teach that nothing answers. Something does — it is small, and striped, and it was never the pantheon, and that is enough for him.")},
		], false, false, true)


func _coherence_tick() -> void:
	## Brief §3: coherence drifts toward each faith's equilibrium; the
	## pantheon's equilibrium itself erodes under the Silence.
	var orth: Dictionary = faiths["Aelindran Orthodox"]
	orth["equilibrium"] = maxf(0.25, float(orth["equilibrium"]) - 0.02 / 12.0)
	for fname in faiths:
		var f: Dictionary = faiths[fname]
		if not bool(f["active"]):
			continue
		var coh := float(f["coherence"])
		coh += (float(f["equilibrium"]) - coh) * 0.03
		# a Zealous crown publicly keeping the faith steadies it
		for realm: Realm in realms:
			var r: SimCharacter = characters.get(realm.ruler_id)
			if r != null and r.alive and r.traits.has("Zealous") and faith_of(r) == str(fname):
				coh += 0.002
		# a Broken chaplain in visible office bleeds the pantheon's credit
		if str(fname) == "Aelindran Orthodox" and magister_seats.has("Court Chaplain"):
			var chap: SimCharacter = characters.get(int(magister_seats["Court Chaplain"]["holder"]))
			if chap != null and chap.alive and chap.traits.has("Broken"):
				coh -= 0.002
		f["coherence"] = clampf(coh, 0.01, 0.99)


func _membership_tick() -> void:
	## Brief §3: the pantheon bleeds roughly two points a year (faster as
	## coherence fails); the successors grow toward their projections.
	var orth: Dictionary = faiths["Aelindran Orthodox"]
	# roughly -2% a year of what remains, a little faster as coherence
	# fails — proportional, so the bleed slows as the faithful thin out:
	# total collapse is the endgame cascade's job, not the drift's
	orth["membership"] = maxf(0.03, float(orth["membership"]) * (1.0 - (0.02 / 12.0) * minf(1.2, 1.5 - float(orth["coherence"]))))
	var ref: Dictionary = faiths["Aelindran Reformed"]
	if bool(ref["active"]) and float(ref["coherence"]) >= 0.45:
		ref["membership"] = minf(0.20, float(ref["membership"]) + 0.15 / 108.0)
	var sil: Dictionary = faiths["The Silent Path"]
	if bool(sil["active"]):
		sil["membership"] = minf(0.10, float(sil["membership"]) + 0.06 / 108.0)
	var brush: Dictionary = faiths["The Brushgate Order"]
	brush["membership"] = minf(0.02, float(brush["membership"]) + 0.003 / 12.0)
	var rat: Dictionary = faiths["The Vael Rationalist Faith"]
	var gm := grand_magister()
	if gm != null and (faith_of(gm) == "The Vael Rationalist Faith" or str(magister_wing.get(gm.id, "")) == "reformist"):
		rat["membership"] = minf(0.35, float(rat["membership"]) + 0.005 / 12.0)
	elif gm != null and str(magister_wing.get(gm.id, "")) == "traditionalist":
		rat["membership"] = maxf(0.05, float(rat["membership"]) - 0.002 / 12.0)
	# rulers who publicly practice a faith draw their people after them
	for realm: Realm in realms:
		var r: SimCharacter = characters.get(realm.ruler_id)
		if r == null or not r.alive:
			continue
		var rf: Dictionary = faiths.get(faith_of(r), {})
		if not rf.is_empty() and bool(rf["active"]):
			rf["membership"] = minf(0.90, float(rf["membership"]) + 0.005 / 12.0)
	# heretical branches live and die by their coherence
	for fname in faiths:
		var f: Dictionary = faiths[fname]
		if str(f["parent"]) != "" and bool(f["active"]):
			f["membership"] = maxf(0.0, float(f["membership"]) + (float(f["coherence"]) - 0.35) * 0.0008)


func _heresy_tick() -> void:
	## Brief §4: heresy pressure accumulates as (1 - coherence) ×
	## membership × 0.001 monthly; past 1.0 a new branch tries to form.
	## Most heresies collapse within their first decade.
	var active_count := 0
	for fname in faiths:
		if bool(faiths[fname]["active"]):
			active_count += 1
	for fname in faiths.keys():
		var f: Dictionary = faiths[fname]
		if not bool(f["active"]) or float(f["membership"]) < 0.02:
			continue
		f["pressure"] = float(f["pressure"]) + (1.0 - float(f["coherence"])) * (float(f["membership"]) * 100.0) * 0.001
		if float(f["pressure"]) >= 1.0:
			f["pressure"] = 0.0
			if active_count >= FAITH_CAP:
				_log("A new heresy stirs within %s — and is absorbed before it can organize. The continent already carries every doctrine it can hold." % str(fname))
			else:
				_raise_heretical_branch(str(fname))
				return  # one schism a month is all the chronicle can take
	# the collapse of the failed branches
	for fname in faiths.keys():
		var f: Dictionary = faiths[fname]
		if str(f["parent"]) == "" or not bool(f["active"]):
			continue
		if tick - int(f["founded"]) > 120 and (float(f["coherence"]) < 0.20 or float(f["membership"]) < 0.01):
			f["active"] = false
			var parent: Dictionary = faiths.get(str(f["parent"]), {})
			if not parent.is_empty():
				parent["membership"] = minf(0.90, float(parent["membership"]) + float(f["membership"]) * 0.5)
			_log("[b]%s collapses.[/b] The teachers scatter, the gatherings thin, and the remnant drifts home to %s — the usual fate of a doctrine born in a vacuum." % [str(fname), str(f["parent"])])
			return


func _unused_heresy_name() -> String:
	var pool: Array = []
	for n in HERESY_NAMES:
		if not faiths.has(n):
			pool.append(n)
	if pool.is_empty():
		return ""
	return str(pool[frng.randi_range(0, pool.size() - 1)])


func _spawn_heresy(parent_name: String, bname: String, legitimized: bool) -> void:
	var parent: Dictionary = faiths[parent_name]
	var share := 0.02 + frng.randf() * 0.03  # 2-5% of the parent walks (brief §4)
	var taken := float(parent["membership"]) * share
	parent["membership"] = maxf(0.0, float(parent["membership"]) - taken)
	var tenets: Array = (parent["tenets"] as Array).duplicate()
	var swaps := 1 + (1 if frng.randf() < 0.5 else 0)
	for i in swaps:
		if tenets.is_empty():
			break
		tenets[frng.randi_range(0, tenets.size() - 1)] = HERESY_TENETS[frng.randi_range(0, HERESY_TENETS.size() - 1)]
	_add_faith(bname, true, 0.35 + (0.10 if legitimized else 0.0), 0.40, taken,
		float(parent["orthodoxy_alignment"]) * 0.5, tenets,
		["a charismatic teaching circle"], parent_name)
	_log("[b]A new heretical branch: %s.[/b] Born out of %s's fracturing doctrine — no divine authority remains to say which reading of the Silence is correct, so every reading finds its congregation." % [bname, parent_name])


func _raise_heretical_branch(parent_name: String) -> void:
	var bname := _unused_heresy_name()
	if bname == "":
		return
	# heresies inside the realm-0-dominant faiths reach the crown's table;
	# the rest of the continent schisms without asking anyone
	if parent_name != "Aelindran Orthodox" and parent_name != "The Vael Rationalist Faith":
		_spawn_heresy(parent_name, bname, false)
		return
	var pname := parent_name
	var hname := bname
	var ruler_id: int = realms[0].ruler_id
	var ruler: SimCharacter = characters.get(ruler_id)
	raise_event(0, ruler_id, "A New Heresy: %s" % bname,
		"A teaching circle calling itself %s has split from %s — new tenets, a charismatic voice, and congregations forming faster than the registries can record them. There is no divine authority left to rule which reading of the Silence is correct. There is, however, a crown." % [bname, parent_name],
		[
			{"label": "Denounce the heresy from every pulpit", "base": 3.0,
				"ai": {"orthodoxy": 1.0},
				"effect": func() -> void:
					var r2: SimCharacter = characters.get(realms[0].ruler_id)
					var lrn := 10.0 if r2 == null else float(r2.learning)
					if frng.randf() < 0.35 + lrn * 0.015:
						_shift_coherence(pname, -0.03)
						_log("[b]The denouncement holds.[/b] %s is read out from every pulpit the crown can reach, its teachers dispersed before the movement can organize. The suppression costs the parent doctrine some of its own credit — force is what a faith uses when argument has stopped working." % hname)
					else:
						_spawn_heresy(pname, hname, true)
						_log("The denouncement fails — and fails publicly. Every pulpit that read the proscription has now advertised the teaching, and %s emerges legitimized by the attention." % hname)},
			{"label": "Let it find its level", "base": 2.5, "ai": {"patience": 0.5},
				"effect": func() -> void:
					_shift_coherence(pname, -0.02)
					_spawn_heresy(pname, hname, false)},
		], false, false, true)


func _cathedral_tick() -> void:
	## Brief §7: the cathedral ceremonies — success builds coherence,
	## failure spends it. Quarterly, alongside the devotions.
	var orth: Dictionary = faiths["Aelindran Orthodox"]
	var priest: SimCharacter = null
	for c in characters.values():
		if c.alive and c.realm_id == 0 and c.traits.has("Faith-Practicing") \
				and faith_of(c) == "Aelindran Orthodox" and not hero_cast.has(c.id):
			# the Reactionary clergy are hero_cast: the cathedral's quarterly
			# rite keeps its pre-hero hands, or the frng stream reshuffles
			priest = c
			break
	if priest != null:
		var p = province_of_character(priest)
		if frng.randf() < faith_reliability(priest, p):
			_shift_coherence("Aelindran Orthodox", 0.01)
			if frng.randf() < 0.15:
				_log("The cathedral ceremony holds — %s carries the great rite through whole, and for a season the doctrine remembers what it was." % full_name(priest))
		else:
			_shift_coherence("Aelindran Orthodox", -0.002)
	# the Cathedral Question is asked exactly once, when the Reformed
	# movement outnumbers the orthodoxy it grew out of
	var ref: Dictionary = faiths["Aelindran Reformed"]
	if not cathedral_repurposed and bool(ref["active"]) and float(ref["membership"]) > float(orth["membership"]):
		cathedral_repurposed = true
		raise_event(0, realms[0].ruler_id, "The Cathedral Question",
			"The Reformed congregations now outnumber the Orthodox ones — and the Vael cathedral stands mostly empty at the old offices. A petition reaches the Council: let the building serve the practice people actually keep.",
			[
				{"label": "Convert the cathedral to Reformed use", "base": 3.0,
					"effect": func() -> void:
						_shift_coherence("Aelindran Reformed", 0.05)
						_shift_coherence("Aelindran Orthodox", -0.05)
						_log("[b]The Vael cathedral passes to the Reformed practice.[/b] The candles are relit under new instruction — the saying is ours; the hearing never was. The remaining Orthodox clergy call it theft with paperwork.")},
				{"label": "The old faith keeps its house", "base": 2.0, "ai": {"orthodoxy": 0.8},
					"effect": func() -> void:
						_shift_coherence("Aelindran Orthodox", 0.02)
						_log("The petition is declined: the cathedral remains Orthodox, however thin the congregation. Some buildings are kept for what they meant, not what they hold.")},
			], false, false, true)


# ------------------------------------------- faith change (brief §6)

func _faith_judges() -> Array:
	## Who reacts to a public conversion: crowned heads and seated Magisters.
	var out: Array = []
	var seen := {}
	for realm: Realm in realms:
		var r: SimCharacter = characters.get(realm.ruler_id)
		if r != null and r.alive:
			out.append(r)
			seen[r.id] = true
	for m in seated_magisters():
		if not seen.has(m.id):
			out.append(m)
			seen[m.id] = true
	for rid in cast_rulers:
		var cr := cast_ruler_of(int(rid))
		if cr != null and cr.alive and not seen.has(cr.id):
			out.append(cr)
	return out


func _convert_faith(c: SimCharacter, to_name: String) -> void:
	## A public reshaping of identity, with the opinion web to match
	## (brief §6). Not a menu selection: only event chains reach here.
	var from := faith_of(c)
	if from == to_name:
		return
	c.faith = to_name
	var from_rec: Dictionary = faiths.get(from, {})
	if not from_rec.is_empty():
		from_rec["membership"] = maxf(0.0, float(from_rec["membership"]) - 0.002)
	var to_rec: Dictionary = faiths.get(to_name, {})
	if not to_rec.is_empty():
		to_rec["membership"] = minf(0.90, float(to_rec["membership"]) + 0.002)
	for judge in _faith_judges():
		var j: SimCharacter = judge
		if j.id == c.id:
			continue
		var jf := faith_of(j)
		if jf == to_name:
			add_memory(j, "one of ours now", c.id, 15.0, 1.0)
		elif jf == "Aelindran Orthodox":
			var sting := -15.0
			if to_name == "Aelindran Reformed":
				sting = -20.0
			elif to_name == "The Silent Path":
				sting = -30.0
			add_memory(j, "abandoned the pantheon", c.id, sting, 1.0)
		elif jf == "The Vael Rationalist Faith" and to_name == "The Silent Path":
			add_memory(j, "a secular ally, of a kind", c.id, 10.0, 1.0)
		elif jf == "Aelindran Reformed" and to_name == "Aelindran Orthodox":
			add_memory(j, "went back to the empty altar", c.id, -10.0, 1.0)
	# a Grand Magister's conversion shakes the chamber (brief §6)
	if c.id == realms[0].ruler_id and str(realms[0].government) == "administrative" \
			and not magister_seats.is_empty():
		var division := magister_vote("the chair's public conversion", c.id, -2.0)
		if not bool(division.get("passed", true)):
			realms[0].tyranny = minf(100.0, realms[0].tyranny + 5.0)
			_log("[b]The chamber does not follow the chair.[/b] The Grand Magister's conversion to %s is entered over a recorded Council majority against — the kind of division a vote of no confidence is made of." % to_name)
			# and if three Magisters are angry enough, the motion moves itself
			call_no_confidence()


func _faith_change_tick() -> void:
	## Semiannual: the conversion chains scan for souls at their own
	## thresholds (brief §6). At most one conversion event per pass —
	## faith change should feel like weather, not machinery.
	for c in characters.values():
		if not c.alive or c.age_years(tick) < ADULT_AGE:
			continue
		if c.realm_id != 0 and c.realm_id != 1 and not admin_cast.has(c.id):
			continue
		if hero_cast.has(c.id):
			continue  # the hero cast converts by beats, not by weather — their
			          # consideration dice would reshuffle the faith stream (v1.0)
		if tick - int(faith_change_cooldown.get(c.id, -999)) < 60:
			continue
		var cur := faith_of(c)
		# Reformed Conversion: a Pragmatic Orthodox soul who has watched prayer fail
		if cur == "Aelindran Orthodox" and c.traits.has("Pragmatic") \
				and bool(faiths["Aelindran Reformed"]["active"]) \
				and (int(prayer_fails_ever.get(c.id, 0)) >= 1 or frng.randf() < 0.04) \
				and frng.randf() < 0.15:
			faith_change_cooldown[c.id] = tick
			_raise_conversion(c, "Aelindran Reformed",
				"A Reformed teacher passes through, and their argument will not leave %s alone: the saying of the rite was always the priest's whole part. The hearing was someone else's — and its absence indicts no one." % full_name(c),
				"Cross to the Reformed practice", "Keep the old faith whole")
			return
		# Silent Path Acceptance: a Broken soul with three failures behind them
		if (cur == "Aelindran Orthodox" or cur == "Aelindran Reformed") and c.traits.has("Broken") \
				and bool(faiths["The Silent Path"]["active"]) \
				and int(prayer_fails_ever.get(c.id, 0)) >= 3 and frng.randf() < 0.20:
			faith_change_cooldown[c.id] = tick
			_raise_conversion(c, "The Silent Path",
				"A quiet gathering has been meeting near %s's door, and their teaching names the weight exactly: the pantheon has already spoken, through their absence. No further practice is required. Or possible." % full_name(c),
				"Accept the Silent Path", "The candles stay lit")
			return
		# Secular Rationalist Adoption: the academy's people, following their ledgers
		if cur == "Aelindran Orthodox" and c.traits.has("Pragmatic") and c.realm_id == 0 \
				and (c.traits.has("Academy-Sworn") or magister_seat_of(c.id) != "" \
				or has_mythos(root_house_id(c.dynasty_id), "Vael-Educated")) \
				and frng.randf() < 0.12:
			faith_change_cooldown[c.id] = tick
			_raise_conversion(c, "The Vael Rationalist Faith",
				"%s has kept the outward observances for years while the actual conviction migrated to the ledgers: institutions earn legitimacy by working. The academies teach it. The Council practices it. Saying it aloud is all that remains." % full_name(c),
				"Adopt the Rationalist position publicly", "Keep the observances")
			return
		# the Zealous road home: Reformed and Rationalist converts pulled back
		if (cur == "Aelindran Reformed" or cur == "The Vael Rationalist Faith") \
				and c.traits.has("Zealous") and frng.randf() < 0.15:
			faith_change_cooldown[c.id] = tick
			_raise_conversion(c, "Aelindran Orthodox",
				"%s's compromise has stopped holding. The reformed argument was tidy, the rationalist one tidier — and neither survives the hour before dawn, when the old rites are the only thing shaped like the ache. The pantheon is silent. The pantheon is still *there*." % full_name(c),
				"Return to the Orthodox rite", "The compromise stands")
			return
		# Brushgate Adoption: exposure to a practitioner, any response (trait, not faith)
		if not c.traits.has("Brushgate-Trained") and frng.randf() < 0.02:
			var mentor: SimCharacter = null
			for o in characters.values():
				if o.alive and o.realm_id == c.realm_id and o.id != c.id and o.traits.has("Brushgate-Trained"):
					mentor = o
					break
			if mentor != null:
				faith_change_cooldown[c.id] = tick
				var who: SimCharacter = c
				raise_event(c.realm_id, c.id, "The Brushgate Forms",
					"%s has watched %s at the morning forms long enough to ask. The answer is characteristically short: the body remembers what the gods forgot. The teaching is open to anyone willing to be present with what is dying." % [full_name(c), full_name(mentor)],
					[
						{"label": "Learn the discipline", "base": 2.5, "ai": {"patience": 0.6},
							"effect": func() -> void:
								_add_trait(who, "Brushgate-Trained")
								_log("%s takes up the Brushgate discipline — the faith they keep is their own business; the practice asks only presence." % full_name(who))},
						{"label": "Decline — the mornings are spoken for", "base": 2.0,
							"effect": func() -> void: pass},
					], false, false, true)
				return


func _raise_conversion(c: SimCharacter, to_name: String, text: String,
		adopt_label: String, refuse_label: String) -> void:
	var who := c
	var target := to_name
	var to_align := float(faiths.get(to_name, {}).get("orthodoxy_alignment", 0.0))
	var cur_align := float(faiths.get(faith_of(c), {}).get("orthodoxy_alignment", 0.0))
	# the orthodoxy axis scores the choice (brief §5): moving toward the
	# pantheon suits the Zealous; moving away suits the Opportunistic —
	# a full alignment gap times a Zealous +30 clears every jitter
	var adopt_w := to_align - cur_align
	raise_event(c.realm_id, c.id, "A Faith Reconsidered",
		text,
		[
			{"label": adopt_label, "base": 2.0, "ai": {"orthodoxy": adopt_w, "patience": 0.1},
				"effect": func() -> void:
					_convert_faith(who, target)
					_log("[b]%s publicly adopts %s.[/b] The realm's religious weather shifts by one soul — and everyone watching recalculates." % [full_name(who), target])},
			{"label": refuse_label, "base": 2.5, "ai": {"orthodoxy": -adopt_w},
				"effect": func() -> void: pass},
		], false, false, true)


func _faith_consideration_tick() -> void:
	## Brief §5: a character whose orthodoxy weight has moved more than 20
	## points since the last yearly reading faces the question directly.
	var candidate: SimCharacter = null
	var drop := false
	for c in characters.values():
		if not c.alive or c.age_years(tick) < ADULT_AGE:
			continue
		if c.realm_id != 0 and c.realm_id != 1 and not admin_cast.has(c.id):
			continue
		var cur := ai_weight(c, "orthodoxy")
		var had: bool = orthodoxy_snapshot.has(c.id)
		var snap := float(orthodoxy_snapshot.get(c.id, cur))
		orthodoxy_snapshot[c.id] = cur
		if not had or candidate != null:
			continue
		if cur - snap <= -20.0 and faith_of(c) == "Aelindran Orthodox":
			candidate = c
			drop = true
		elif cur - snap >= 20.0 and faith_of(c) != "Aelindran Orthodox" \
				and not FOLK_FAITHS.values().has(faith_of(c)):
			candidate = c
	if candidate == null or tick - int(faith_change_cooldown.get(candidate.id, -999)) < 60:
		return
	faith_change_cooldown[candidate.id] = tick
	if drop:
		var to := "The Vael Rationalist Faith" if candidate.realm_id == 0 else \
			("The Silent Path" if bool(faiths["The Silent Path"]["active"]) else "Aelindran Reformed")
		if not bool(faiths.get(to, {}).get("active", false)):
			return
		_raise_conversion(candidate, to,
			"The year has moved something in %s that the old faith no longer covers. What they actually believe and what they publicly practice have come apart — and the gap is starting to show." % full_name(candidate),
			"Let the change be public", "Hold to the old faith")
	else:
		_raise_conversion(candidate, "Aelindran Orthodox",
			"The year has carried %s back toward the pantheon — silent or not, it is the only thing the ache was ever shaped like." % full_name(candidate),
			"Return to the Orthodox rite", "Stay the newer course")


func _patron_state_tick() -> void:
	## Brief §2.6: the covert non-faith has an activation state, not a
	## coherence — dormant, building, active, revealed (or broken).
	if patron_network_broken:
		if patron_state != "broken":
			patron_state = "broken"
		return
	var order := ["dormant", "building", "active", "revealed"]
	var bound := 0
	var exposed := false
	for c in characters.values():
		if c.alive and c.traits.has("Patron-Bound"):
			bound += 1
	for s in secrets:
		if str(s["type"]) == "patron_bargain_signed":
			var subj: SimCharacter = characters.get(int(s["subject"]))
			for rid in s["known"]:
				if subj == null or int(rid) != subj.realm_id:
					exposed = true
	if central_secret_state == "revealed" or central_secret_state == "leveraged":
		exposed = true
	var target := "dormant"
	if exposed:
		target = "revealed"
	elif bound >= 3:
		target = "active"
	elif bound >= 1:
		target = "building"
	# Canon Pass One §3.6: the consent token removed is a DIFFERENT outcome
	# from the anchor burned. Voided, the network cannot ADVANCE — the
	# authorization under the foundation stone is gone and no new weight
	# accrues — but what is already bound stands, and exposure (knowledge)
	# still travels. Not ash: operationally vulnerable.
	if patron_anchor_voided and target != "revealed" \
			and order.find(target) > order.find(patron_state):
		target = patron_state
	if order.find(target) > order.find(patron_state):
		patron_state = target
		if target == "revealed":
			_log("[b]The Patron network stands revealed.[/b] What the bargain-holders were part of finally has a name spoken above a whisper — and every faith on the continent must now say something about it.")


# ------------------------------------------- the God of Thresholds (addendum)

func threshold_practitioner(realm_id: int) -> SimCharacter:
	## The realm's working threshold-hand: Gravewarden-Sworn first, the
	## Threshold-Sensitive as the untrained fallback.
	var fallback: SimCharacter = null
	for c in characters.values():
		if not c.alive or c.realm_id != realm_id or c.age_years(tick) < ADULT_AGE:
			continue
		if c.traits.has("Gravewarden-Sworn"):
			return c
		if fallback == null and c.traits.has("Threshold-Sensitive"):
			fallback = c
	return fallback


func _threshold_on_death(dead: SimCharacter) -> void:
	## "Proper Death Received": a practitioner attends the crossing, names
	## the dead properly, carves the bird. The one practice that never
	## stopped working.
	if faiths.is_empty():
		return
	var pr := threshold_practitioner(dead.realm_id)
	if pr == null or pr.id == dead.id:
		return
	var chance := 0.85 if pr.traits.has("Gravewarden-Sworn") else 0.45
	if frng.randf() >= chance:
		return
	pr.threshold_binding_bonus_permanent = minf(0.6, pr.threshold_binding_bonus_permanent + 0.02)
	pr.wooden_birds_carved += 1
	award_hero_xp(pr.id, HeroDB.XP_AWARDS["threshold_rite"], "a crossing witnessed")
	if dead.spouse_id >= 0:
		var sp: SimCharacter = characters.get(dead.spouse_id)
		if sp != null and sp.alive:
			add_memory(sp, "they carved the bird for our dead", pr.id, 5.0, 1.0)
	for kid_id in dead.children_ids:
		var kid: SimCharacter = characters.get(kid_id)
		if kid != null and kid.alive:
			add_memory(kid, "they carved the bird for our dead", pr.id, 5.0, 1.0)
	if is_ruler(dead.id) or frng.randf() < 0.10:
		_log("%s receives %s at the threshold — the name said properly, the crossing witnessed, a carved bird left with the family. That rite, whatever else has failed, still answers." % [full_name(pr), full_name(dead)])


func _threshold_maintenance_tick() -> void:
	## "Bird Carving": the Order's quarterly discipline — stress worked
	## into wood, one bird per dead received.
	for c in characters.values():
		if not c.alive or not c.traits.has("Gravewarden-Sworn"):
			continue
		add_stress(c, -4.0, "carving the birds")
		c.wooden_birds_carved += 1
		award_hero_xp(c.id, HeroDB.XP_AWARDS["ceremony"], "the quarter's carving discipline")
		if frng.randf() < 0.05:
			_log("%s spends the quarter's quiet hours carving — %d wooden birds now, one for every crossing witnessed." % [full_name(c), c.wooden_birds_carved])


func _compact_ceremony_tick() -> void:
	## The Marn's Crossing compact ceremony (addendum): a threshold-hand
	## present at the quarterly exchange steadies what treaties cannot.
	if at_war:
		return
	var pr := threshold_practitioner(0)
	if pr == null:
		return
	var r0: SimCharacter = characters.get(realms[0].ruler_id)
	var r1: SimCharacter = characters.get(realms[1].ruler_id)
	if r0 == null or r1 == null or not r0.alive or not r1.alive:
		return
	add_memory(r0, "the crossing rites held", r1.id, 2.0, 2.0)
	add_memory(r1, "the crossing rites held", r0.id, 2.0, 2.0)
	if frng.randf() < 0.04:
		_log("The quarterly compact ceremony at Marn's Crossing is held under %s's threshold-observance — both delegations watch the same rite performed for both peoples' dead, and leave a little slower to reach for their knives." % full_name(pr))


func threshold_rejection(warden_id: int, target_id: int) -> String:
	## The Threshold Rejection Ritual (addendum): a Gravewarden resolves
	## what the Patron requires to remain incomplete. Costs the warden 15
	## stress; reduces the target's Corruption meter by 1.0 on success.
	## Marks already paid for remain — the ritual works the meter, not
	## the flesh.
	var g: SimCharacter = characters.get(warden_id)
	var t: SimCharacter = characters.get(target_id)
	if g == null or not g.alive or not g.traits.has("Gravewarden-Sworn"):
		return "Only a Gravewarden-Sworn hand can perform the rejection rite."
	if t == null or not t.alive or t.corruption <= 0.0:
		return "There is nothing on that soul's ledger to reject."
	add_stress(g, 15.0, "the rejection rite")
	if frng.randf() < 0.85:
		t.corruption = maxf(0.0, t.corruption - 1.0)
		_log("[b]%s performs the Threshold Rejection over %s[/b] — the incomplete transition the bargain fed on is witnessed, named, and closed. The ledger lightens by a measure. The marks already paid for remain." % [full_name(g), full_name(t)])
		return "The rejection holds: their corruption recedes by a measure."
	_log("%s attempts the Threshold Rejection over %s — and the rite slips. Whatever holds that soul's transitions open held this time." % [full_name(g), full_name(t)])
	return "The rite slips — the corruption holds."


func _ai_threshold_rejection_tick() -> void:
	## The Order does not wait to be asked: a warden who sees a heavy
	## ledger works it, at their own cost.
	for g in characters.values():
		if not g.alive or not g.traits.has("Gravewarden-Sworn") or g.stress > 120.0:
			continue
		var worst: SimCharacter = null
		for t in characters.values():
			if t.alive and t.id != g.id and t.realm_id == g.realm_id and t.corruption >= 5.0:
				if worst == null or t.corruption > worst.corruption:
					worst = t
		if worst != null and frng.randf() < 0.10:
			threshold_rejection(g.id, worst.id)
		return


# --------------------------------------- The Architect's Vigil (v1.0)
# Opus's Vigil doc (2026-07-08): the specific canonical shape of Veril
# Ormand's last six years in a timeline where the Traveler he prepared
# for does not exist. Five phases of dawning awareness (months 30, 42,
# 54, 66), an evaluation of alternate recipients weighted by the world
# the player shaped, a Phase Four contact, a Phase Five choice between
# acceptance (5A — the chamber sealed, the truth escaping haphazardly)
# and active delivery (5B — a modified ritual under desperate necessity),
# and a Year Six death that was always the clock. All vigil dice roll on
# `vrng` (seed 112 — the year the bargain was signed); Veril's own
# monthly dice stay in the main stream, drawn as they always were.

const ARCHITECT_DEATH_TICK := 72  # Year Six's last month: six years of maintenance, to the day

var vigil_sealed := false  # Phase 5A taken: the chamber holds the truth until someone opens the door


func _seed_vigil() -> void:
	vrng.seed = 112
	architect_phase = 1  # confident waiting: the preparation is on schedule; he does not yet know


func vigil_candidates() -> Dictionary:
	## The Vigil doc §6 Phase 2 weights, read live against the world. The
	## player never picks Veril's recipient — but the landscape the player
	## shaped is the landscape Veril observes.
	var w := {}
	var marek: SimCharacter = characters.get(marek_id)
	if marek != null and marek.alive:
		w["marek"] = 20.0  # +40 the Iron Library's protection, -20 the years he does not know he lacks
	var sevrin: SimCharacter = characters.get(sevrin_id)
	if sevrin != null and sevrin.alive:
		var s := 15.0  # +25 the Pragmatic response, -10 the youth
		if magister_seat_of(sevrin.id) != "":
			s += 15.0  # +15 the Council seat: positioned inside the apparatus
		w["sevrin"] = s
	var halvar: SimCharacter = characters.get(halvar_id)
	if halvar != null and halvar.alive:
		var h := 25.0  # +30 the Order's structural opposition to the Patron, +10 respect, -15 the outsider
		var birds := 0
		for c in characters.values():
			var who: SimCharacter = c
			if who.alive:
				birds += who.wooden_birds_carved
		h += minf(10.0, float(birds) * 0.5)  # the Order's work, visible on every road Veril reads about
		if patron_state == "active" or patron_state == "revealed":
			h += 5.0  # the opposition finally has something to oppose in the open
		w["halvar"] = h
	var sera: SimCharacter = characters.get(sera_id)
	if sera != null and sera.alive:
		var e := 15.0  # +20 the House position, -20 the youth, +15 the Aelindran-Legitimate access
		if has_mythos(root_house_id(sera.dynasty_id), "Aelindran-Legitimate"):
			e += 10.0  # the old claim is already awake — the truth would land on a lit fuse
		w["sera"] = e
	var thessaly: SimCharacter = characters.get(thessaly_id)
	if thessaly != null and thessaly.alive and (marek == null or not marek.alive):
		w["thessaly"] = 35.0  # the Library's discipline, inherited whole — requires Vovel's death first
	# the Iron Library Compact: a realm-0 House formally bound to the
	# archive raises the archive's standing in Veril's ledgers
	for d: Dynasty in dynasties.values():
		if d.legacies.has("The Iron Library Compact"):
			if w.has("marek"):
				w["marek"] = float(w["marek"]) + 10.0
			if w.has("thessaly"):
				w["thessaly"] = float(w["thessaly"]) + 10.0
			break
	return w


func _vigil_top_candidate() -> String:
	var w := vigil_candidates()
	var top := ""
	var top_w := -INF
	for k in w:
		if float(w[k]) > top_w:
			top_w = float(w[k])
			top = str(k)
	return top


func _vigil_tick() -> void:
	## The old man's clock (Vigil doc §2, §6). Runs after the theology's
	## tick, every month, from Year Zero until the vigil ends.
	if architect_id < 0 or architect_phase == 0 or architect_phase >= 6:
		return
	var a: SimCharacter = characters.get(architect_id)
	if a == null:
		return
	if not a.alive and tick < ARCHITECT_DEATH_TICK and vigil_recipient == "" and not vigil_sealed:
		return  # an unscheduled end — _architect_tick aborts the vigil and opens the chamber
	if central_secret_state != "buried" and vigil_recipient == "" and not vigil_sealed:
		# Loose pages or a containment leak preempted the arc: the truth
		# is already loose, and there is nothing left to deliver.
		architect_phase = 6
		return
	match tick:
		30:
			architect_phase = 2  # quiet uncertainty (doc §2 Phase Two)
			_log("The Records Sublevel requests the Iron Library's correspondence indices — twice in one season, after thirty-four years of requesting nothing but the Year 112 files. The clerks fill the order and think no more of it. In the sublevel, an old man reads the lists of who has written to whom, and does not find the pattern he spent forty years learning to expect.")
		42:
			architect_phase = 3  # acknowledged crisis (doc §2 Phase Three)
			_log("[b]The old man attends the full session.[/b] Veril Ormand takes his Records Sublevel seat for every sitting this month — the first time in living clerical memory — and says nothing, and watches the chamber the way an assessor watches a bridge. That evening his lamp burns past the third hour. The person he prepared for is not coming. He has stopped testing the conclusion. What remains is six volumes, a ritual with no one to receive it, and however many mornings are left.")
			_log("Five names go into the second journal.")
		54:
			architect_phase = 4  # active recomposing (doc §2 Phase Four)
			_vigil_contact_event()
		66:
			_vigil_phase5()
	if vigil_delivery_tick > 0 and tick == vigil_delivery_tick and vigil_contact_target != "":
		_vigil_delivery()
	if tick == ARCHITECT_DEATH_TICK and a.alive:
		_vigil_death(a)
	# the post-death schedule (scheduled death only)
	if tick == ARCHITECT_DEATH_TICK + 1 and vigil_fragments and central_secret_state == "buried" and vigil_sealed:
		_vigil_fragments_escape()
	if tick == ARCHITECT_DEATH_TICK + 2 and vigil_recipient != "":
		_vigil_escape()
	if tick == ARCHITECT_DEATH_TICK + 3 and vigil_sealed and central_secret_state == "buried":
		_vigil_chamber_race()
	# the recipients' slower roads
	match vigil_recipient:
		"thessaly":
			if tick == ARCHITECT_DEATH_TICK + 14:
				_shift_coherence("Aelindran Orthodox", -0.10)
				_shift_coherence("The Vael Rationalist Faith", -0.10)
				_log("[b]The Iron Library publishes its first paper on the Council of Year 112.[/b] 'On the Administrative Continuity of the Magistocracy' — dry as bone, footnoted like a fortress, and unanswerable. It names no bargain. It establishes who was in the room. The second paper is already being set.")
				award_hero_xp(thessaly_id, HeroDB.XP_AWARDS["research_published"], "the Year-112 paper")
			elif tick == ARCHITECT_DEATH_TICK + 26:
				# the vigil closes here whatever became of the containment:
				# held → the gradual reveal (half fury); leaked or preempted →
				# the truth is already loose and there is nothing left to keep
				if central_secret_state == "contained":
					_ending_revealed_gradual()
				architect_phase = 6
		"halvar":
			if tick == ARCHITECT_DEATH_TICK + 8 and central_secret_state == "contained":
				_vigil_order_decides()
		"sera":
			if tick == ARCHITECT_DEATH_TICK + 8 and central_secret_state == "contained":
				_vigil_house_moves()


func _vigil_contact_event() -> void:
	## Doc §6 Phase 3: at Month 54, Veril initiates contact with his
	## top-weighted candidate. The crown sees the letter move — and what
	## the crown does with a sealed letter is the player's lever on
	## whether the contact succeeds.
	var target := _vigil_top_candidate()
	vigil_contact_target = target
	if target == "":
		vigil_contact = ""
		_log("The Records Sublevel's lamp burns late, and no letters leave. There is no one left worth writing to.")
		return
	var titles := {"marek": "The Iron Library Contact", "thessaly": "The Iron Library Contact",
		"sevrin": "The Council Approach", "halvar": "The Order Contact", "sera": "The House Delivery"}
	var texts := {
		"thessaly": "A letter leaves the Records Sublevel under Veril Ormand's personal seal — the first outbound correspondence from that office in the archive's living memory. It is addressed to Thessaly Vorn, Chief Archivist of the Iron Library at Pellar. The Spymaster's office flags it as a matter of course. The seal is unbroken. For now.",
		"marek": "A letter leaves the Records Sublevel under Veril Ormand's personal seal — addressed to Marek Vovel of the Iron Library at Pellar. The Spymaster's office flags it as a matter of course. The seal is unbroken. For now.",
		"sevrin": "Veril Ormand has requested a private audience with Sevrin Vorontheim — deputy of his own sublevel, whom he has passed in silence for two years. The request is on paper, in a slow precise hand, and it has to cross the Chancellor's desk to be scheduled. It sits there now.",
		"halvar": "A message is moving through Gravewarden channels toward Marn's Crossing — from Vael, from a sender the Order's people describe only as 'the man below the Council.' The border post that noticed it awaits instruction.",
		"sera": "Veril Ormand has written to House Halvenard-Veil — to the daughter, not the head. The courier is old, discreet, and paid in advance for silence. The Spymaster's office noticed anyway. The letter can arrive, arrive copied, or not arrive.",
	}
	raise_event(0, realms[0].ruler_id, str(titles.get(target, "A Letter from the Sublevel")),
		str(texts.get(target, texts["thessaly"])),
		[
			{"label": "Let it pass unread — the Sublevel's business is its own", "base": 10.0,
				"ai": {"patience": 0.2},
				"effect": func() -> void:
					vigil_contact = "received"
					_log("The letter goes where it was sent. Somewhere, a reply is being considered.")},
			{"label": "Have it copied in transit — then send it on", "base": 4.0,
				"ai": {"scheming": 0.3},
				"effect": func() -> void:
					vigil_contact = "received"
					vigil_fragments = true
					_log("The letter arrives with its seal immaculate — resealed by professionals. The copy is in the Spymaster's files now: fragments of something much larger, in an old man's careful hand. The truth is in more hands than its keeper chose.")},
			{"label": "Intercept it — nothing leaves that room unexamined", "base": 2.0,
				"ai": {"aggression": 0.15, "scheming": 0.1},
				"effect": func() -> void:
					vigil_contact = "intercepted"
					_log("The letter does not arrive. In the Records Sublevel, an old man counts the weeks a reply should take, then the weeks it should not, and writes one line in the second journal: 'The road is watched. I am — I am out of roads.'")},
		], false, false, false, true)


func _vigil_phase5() -> void:
	## Doc §2 Phase Five: acceptance or active delivery. The decision is
	## Veril's own — shaped by whether his contact was received, by the
	## candidate's weight in his ledgers, and by one dice-breadth of the
	## psychology no ledger holds.
	architect_phase = 5
	var w := vigil_candidates()
	var viable := vigil_contact == "received" and vigil_contact_target != "" \
		and w.has(vigil_contact_target) and float(w[vigil_contact_target]) >= 25.0
	# one chance in ten that the standards he built for forty years refuse
	# the substitute anyway (vrng — the vigil's own die)
	if viable and vrng.randf() >= 0.10:
		vigil_delivery_tick = tick + 3
		_log("[b]A decision, forty years late.[/b] The recognition-pattern was built for someone who does not exist, and the man who built it has concluded that a delivery under desperate necessity beats a sealed room and a haphazard reader. In the second journal: 'I am — I am not choosing correctly. I am choosing.'")
	else:
		vigil_sealed = true
		vigil_delivery_tick = -1
		if vigil_contact == "intercepted":
			_log("[b]The Sublevel goes quiet.[/b] The one road out was watched, and Veril Ormand will not spend the truth on a watched road. The six volumes are complete, cross-referenced, and unaccompanied. The chamber will keep them until someone opens the door. He writes the dates again, out of season, to verify they are still what he remembers.")
		else:
			_log("[b]The Sublevel goes quiet.[/b] Veril Ormand has concluded that no living candidate is the person he prepared for — and that a finished record matters more than a wrong delivery. The six volumes are complete, cross-referenced, and unaccompanied. The chamber will keep them until someone opens the door. He writes the dates again, out of season, to verify they are still what he remembers.")


func _vigil_delivery() -> void:
	## Doc §4: the modified ritual. Time, the recipient's preparation, and
	## the old man's health all shape the form — but in every form, the
	## documentation leaves the chamber while its keeper still breathes.
	vigil_recipient = vigil_contact_target
	vigil_delivery_tick = -1
	match vigil_recipient:
		"thessaly":
			_log("[b]The Delivery: the Iron Library.[/b] A sealed crate leaves the Records Sublevel for Pellar under a supply-line waybill that took three weeks to falsify properly. Six hand-written volumes, cross-referenced, and a letter of instruction in a slow precise hand: how to hold them, when to publish, what each page will cost its reader. It ends: 'I have been keeping records. I have — I have wanted them to exist. They are yours now.' Thessaly Vorn reads the first volume in one sitting.")
		"sevrin":
			_log("[b]The Delivery: the deputy.[/b] Sevrin Vorontheim is called down past the door no deputy has passed in thirty-four years. The ritual is truncated — more explanation than recognition, an old man spending what breath he has on context and trusting the rest to grow. At the end: 'You will want to act on this within the year. Do not. Count the chamber first. You are — you are good at counting.'")
		"halvar":
			_log("[b]The Delivery: the threshold.[/b] The documentation goes out through Gravewarden channels, framed not as institutional record but as threshold-recognition: an incomplete transition, still standing open, and the Order's work unfinished until it closes. Halvar Stenn receives the volumes at Marn's Crossing, reads until the lamp fails, and carves, that evening, a bird for a man not yet dead.")
		"sera":
			_log("[b]The Delivery: an old House.[/b] Veril Ormand's letter to Sera Halvenard-Veil spends two pages on what the truth is and eleven on what it will do — to her House, to the Magistocracy, to every claim the old families ever set aside. The volumes follow by a quieter road. She is twenty-two years old, and she now holds the most dangerous document in Khessar.")
		_:
			_log("[b]The Delivery.[/b] The documentation leaves the Records Sublevel, and its keeper watches it go.")


func _vigil_death(a: SimCharacter) -> void:
	## Year Six, the last month: the clock the chamber was always running
	## on. Six years of the Silence; forty years of the vigil.
	_kill(a, "dies in the Records Sublevel, the ledgers in order, the door locked from within,")
	_log("[b]The last surviving signature of Year 112 has left the table.[/b] In the chamber's first room they will eventually find a small ledger: the same dates, written over again every spring, forty springs deep. The final entry is this year's. The dates are what he remembered.")
	if vigil_recipient == "" and not vigil_sealed:
		# he died before Phase Five could conclude — treat as 5A by default
		vigil_sealed = true


func _vigil_fragments_escape() -> void:
	## Ending Four's seed (doc §5): the Spymaster's copy was the only
	## version outside the chamber — and a sealed chamber makes fragments
	## priceless. Distributed leverage, not institutional truth.
	central_secret_state = "leveraged"
	for lord: SimCharacter in landed_vassals(0):
		_gain_hook(0, lord.id, "weak", "silence_cause_complicity")
	_log("[b]The fragments do their work.[/b] The chamber is sealed and its keeper is dead — but the copy taken in transit is suddenly the only key anyone has, and the Spymaster's office knows exactly which houses appear in it. No publication. No reckoning. Just pressure, applied precisely, house by house.")
	architect_phase = 6


func _vigil_escape() -> void:
	## Doc §3: the truth's escape when a delivery happened (5B). The
	## specific manner of accessibility is the recipient's character.
	match vigil_recipient:
		"thessaly":
			central_secret_state = "contained"
			_log("[b]The Iron Library holds the truth.[/b] Thessaly Vorn does what the letter asked: nothing sudden. The volumes go into protection deeper than any vault the Magistocracy owns — and the work of releasing them begins the way the Record does everything, slowly and in order.")
		"sevrin":
			var rec := magister_vote("acknowledging the record of Year 112", sevrin_id, 2.0)
			if bool(rec["passed"]):
				central_secret_state = "contained"
				realms[0].tyranny = minf(100.0, realms[0].tyranny + 5.0)
				_log("[b]The Council acknowledges — quietly.[/b] Sevrin Vorontheim puts the Year 112 record before the chamber that inherited it, and the chamber, by recorded division, votes to own what it owns: reform from inside, publication deferred, the pages under Council seal. It is not justice. It is — it is administration. It may hold.")
			else:
				_log("[b]The acknowledgment spirals.[/b] A junior Magister asked the chamber to own the Year 112 record. The chamber declined the motion — and a declined motion about a secret is a secret with a vote count attached. The pages are out the windows within a season, and no one controls the reading now.")
				_ending_revealed()
			architect_phase = 6
		"halvar":
			central_secret_state = "contained"
			_log("[b]The Order receives the truth as it receives the dead:[/b] without ceremony, without publication, and without letting go. In the threshold-shrines from Marn's Crossing outward, the wardens now know what stands on the other side of the incomplete transitions they have been closing all their lives — and who bought it.")
		"sera":
			central_secret_state = "contained"
			var sera: SimCharacter = characters.get(sera_id)
			if sera != null:
				_earn_mythos(root_house_id(sera.dynasty_id), "Aelindran-Legitimate")
			_log("[b]An old House remembers what it set aside.[/b] House Halvenard-Veil's daughter holds the proof that the Magistocracy's foundation was a purchase — and the House's claim, dormant since the Sovereignty fell, is suddenly worth reading again. The elders convene. The question is not whether to use it. The question is how.")
		_:
			pass


func _vigil_order_decides() -> void:
	## The Gravewarden road forks (doc §5, Endings Three and Five): if the
	## Patron's network stands visible, the Order coordinates the anchor's
	## destruction; if not, the Order decides its protection is worth more
	## than the telling.
	if (patron_state == "active" or patron_state == "revealed") and not patron_network_broken:
		_log("[b]The Order moves on the Ashfields.[/b] Quietly, over one season, the Gravewarden Order does what it has structurally existed to do since before it had a name: it closes an incomplete transition. Wardens converge on the anchor with the truth of Year 112 in hand and every rite the thresholds ever taught them.")
		_ending_destroyed()
	else:
		central_secret_state = "suppressed"
		_log("[b]The Order keeps the truth.[/b] There is no network worth burning and no reader worth the ruin the pages would buy. The volumes go under a threshold-shrine's floor at Marn's Crossing, and the Order's answer to Year 112 is the same answer it gives every unquiet grave: guarded, tended, and closed.")
	architect_phase = 6


func _vigil_house_moves() -> void:
	## Sera's road (doc §5, Ending One's most explosive mechanism): House
	## Halvenard-Veil decides what a restored claim is worth — and the
	## crown decides whether to let the House speak, buy it, or break it.
	raise_event(0, realms[0].ruler_id, "House Halvenard-Veil Moves",
		"The House has the Year 112 record — the courier, the copies, the daughter who received them are all confirmed. Their claim predates the Magistocracy, and the record proves the Magistocracy's own foundation was a purchase paid in the Silence. Pamphlets are already set in type. The crown has days, not months.",
		[
			{"label": "Let the House speak — the age needs the truth", "base": 3.0,
				"ai": {"orthodoxy": 0.3},
				"effect": func() -> void:
					_log("[b]House Halvenard-Veil publishes.[/b] The old claim and the new proof land together — divine-right memory wrapped around administrative documentation — and no reading room in Khessar holds both without catching fire.")
					_ending_revealed()
					architect_phase = 6},
			{"label": "Bargain — the House's silence has a price", "base": 3.0,
				"ai": {"scheming": 0.4},
				"effect": func() -> void:
					central_secret_state = "leveraged"
					var sera2: SimCharacter = characters.get(sera_id)
					if sera2 != null:
						dynasties[root_house_id(sera2.dynasty_id)].renown += 40.0
					_log("[b]The bargain is struck in a single night.[/b] House Halvenard-Veil's silence costs precedence, offices, and a public restoration of honors the Sovereignty's fall took away — and the record becomes what records become in Vael: an instrument, held jointly, aimed at everyone else.")
					architect_phase = 6},
			{"label": "Suppress it — arrest the courier, burn the copies", "base": 2.0,
				"ai": {"aggression": 0.2, "scheming": 0.15},
				"effect": func() -> void:
					central_secret_state = "suppressed"
					realms[0].tyranny = minf(100.0, realms[0].tyranny + 15.0)
					var sera3: SimCharacter = characters.get(sera_id)
					if sera3 != null and realms[0].ruler_id >= 0:
						add_memory(sera3, "they burned the truth", realms[0].ruler_id, -60.0, 0.5)
					_log("[b]The presses are broken by dawn.[/b] The couriers vanish; the copies burn; House Halvenard-Veil is reminded, precisely, what happened to the last three dissenters of Year 112. The Magistocracy survives whole. Sera Halvenard-Veil survives remembering.")
					architect_phase = 6},
		], false, false, false, true)


func _vigil_chamber_race() -> void:
	## Doc §3, the 5A case: whoever opens the chamber first becomes the
	## effective recipient by proximity rather than by choice — and the
	## first reading shapes everything after. Weighted on the vigil's die.
	var pool: Array = []
	var sevrin: SimCharacter = characters.get(sevrin_id)
	if sevrin != null and sevrin.alive:
		pool.append({"id": sevrin.id, "w": 25.0})  # the deputy of the sublevel itself
	var davriand: SimCharacter = characters.get(davriand_id)
	if davriand != null and davriand.alive:
		pool.append({"id": davriand.id, "w": 20.0})  # the wing that wants a weapon
	var tess: SimCharacter = characters.get(mareck_id)
	if tess != null and tess.alive:
		pool.append({"id": tess.id, "w": 15.0})  # the office that files everything
	var crown: SimCharacter = characters.get(realms[0].ruler_id)
	if crown != null and crown.alive:
		pool.append({"id": crown.id, "w": 10.0})  # the seal moves last, but it moves
	if pool.is_empty():
		_raise_architect_chamber()
		architect_phase = 6
		return
	var total := 0.0
	for p in pool:
		total += float(p["w"])
	var roll := vrng.randf() * total
	var opener_id := int(pool[0]["id"])
	for p in pool:
		roll -= float(p["w"])
		if roll <= 0.0:
			opener_id = int(p["id"])
			break
	_raise_architect_chamber(opener_id)
	architect_phase = 6


func vigil_status_line() -> String:
	## The Records Sublevel as the court can see it (main.gd's Council
	## tab): observable behavior only — the phases behind the door are
	## the doc's, not the clerks'.
	match architect_phase:
		1:
			return "The Records Sublevel: the door has not opened in thirty-four years."
		2:
			return "The Records Sublevel: the old man's lamp burns later than it used to."
		3:
			return "The Records Sublevel: Veril Ormand has begun requesting the current correspondence."
		4:
			return "The Records Sublevel: letters leave under the old man's seal, for the first time in decades."
		5:
			if vigil_sealed:
				return "The Records Sublevel: the door is sealed from within."
			return "The Records Sublevel: a crate left under escort, and the old man watched it go."
		6:
			return "The Records Sublevel seat stands empty."
	return ""


# ================================================================
# The World the Silence Made (v1.1, Opus 2026-07-08): Caeris the
# Unfinished — the ethical antagonist — and the Forsaken. Every die
# rolls on srng (seed 63); auto-firing beats touch only the
# Ashfields ledger, the Forsaken counters, and (late, past the
# canon-asserted years) the Silent Path — never the live realms'
# gold, tyranny, or opinions. Player-initiated actions may.
# ================================================================

func _seed_silence_made() -> void:
	## Caeris predates the Silence: the working is thirty-one years old,
	## the Ashfields residence twenty. Seeded on srng alone — the cast
	## stream (crng) closed with Thessaly and never feels him.
	srng.seed = 63  # how much of himself he still measures as alive
	var house := Dynasty.new(dynasties.size(), "House the Unfinished")
	dynasties[house.id] = house
	var caeris := _create_character("Caeris", false, tick - 62 * 12 - 7, house.id, ASHFIELDS_REALM)
	caeris.race = "human"
	caeris.culture = "free_city"  # born the son of a Pellar healer; twenty years in the Iron Library
	caeris.genome = Genetics.founder(srng)
	_add_trait(caeris, "Threshold-Sensitive")  # the inclination that chose the research at fourteen
	_add_trait(caeris, "Focused")              # what defines him (Canon Updates v1.0) —
	_add_trait(caeris, "Methodical")           # — and how he works; canon keeps both
	_add_trait(caeris, "Patient")              # thirty-one years of discipline
	# the canonical Core Six land AFTER the traits — trait stat mods must
	# not drift the doc §2 numbers
	caeris.diplomacy = 14
	caeris.martial = 8
	caeris.stewardship = 16
	caeris.intrigue = 12
	caeris.learning = 26
	caeris.prowess = 6
	caeris_id = caeris.id
	# Maret the Revenant — canonized (Canon Updates Post-Caeris v1.0 §2):
	# 47 at Year Zero (dead three years before the Silence, at 44), Caeris's
	# most senior associate, running the community's practical operations.
	# Returned-Focused: her sustained purpose is what retards her own settling.
	var maret_house := Dynasty.new(dynasties.size(), "House of the Ashfields")
	dynasties[maret_house.id] = maret_house
	var maret := _create_character("Maret", true, tick - 47 * 12 - 3, maret_house.id, ASHFIELDS_REALM)
	maret.race = "human"
	maret.culture = "free_city"  # the Ashfields micro-culture awaits a CultureData entry — flagged
	maret.genome = Genetics.founder(srng)
	_add_trait(maret, "Focused")
	_add_trait(maret, "Compassionate")
	_add_trait(maret, "Patient")
	# canonical Core Six, locked after the traits (same rule as Caeris)
	maret.diplomacy = 14
	maret.martial = 12
	maret.stewardship = 16
	maret.intrigue = 12
	maret.learning = 18
	maret.prowess = 8
	maret_id = maret.id
	ashfields = {
		"living": 4000.0,       # farmers and families who chose to stay close (doc §4)
		"recently": 300.0,      # Returned, weeks-months: still fully themselves
		"settling": 150.0,      # personality thinning — the problem he cannot solve alone
		"settled": 40.0,        # outlines of the people their families knew
		"hollow": 10.0,         # nothing in particular (Volume I's Hollow Shades)
		"anchored": 0.0,        # framework-saved: the finding, implemented
		"warden_dead": 200.0,   # the territory's defense — never its sword
		"dispersed": 0.0,       # set only by the military solution
		"contacted": false, "finding_heard": false,
		"framework_stage": 0, "stage_started": -1, "endorsements": [],
		"recognition": 0, "resolved": "", "caeris_settling": false,
	}
	forsaken_movements = {}
	for region in FORSAKEN_VARIANTS:
		forsaken_movements[region] = {"strength": 0.0, "stage": 0, "growth_mult": 1.0, "engaged": false}
	_log("East of Pellar, the Ashfields go on as they have for twenty years: the grey farmland around Durn, the scholar who does not sleep, and the dead who came back and are still, for now, themselves. Thessaly Vorn has visited eleven times in three years. Six weeks ago, for the first time, Caeris asked her for something.")


func ashfields_population() -> float:
	if ashfields.is_empty():
		return 0.0
	return float(ashfields["living"]) + ashfields_returned_total()


func ashfields_returned_total() -> float:
	if ashfields.is_empty():
		return 0.0
	return float(ashfields["recently"]) + float(ashfields["settling"]) \
		+ float(ashfields["settled"]) + float(ashfields["hollow"]) + float(ashfields["anchored"])


func ashfields_intake_mult() -> float:
	## Doc §3: who comes to the boundary, and how confidently.
	var m := 1.0
	if int(ashfields["framework_stage"]) >= 1:
		m += 0.5   # Iron Library collaboration is formal — the work is legitimate now
	if int(ashfields["framework_stage"]) == 2:
		m += 0.25  # consent research active: people Return with confidence
	var orth: Dictionary = faiths.get("Aelindran Orthodox", {})
	if float(orth.get("coherence", 0.0)) >= 0.45 and float(orth.get("membership", 0.0)) >= 0.45:
		m -= 0.3   # a confident orthodoxy suppresses the road-knowledge
	if bool(faiths.get("The Silent Path", {}).get("active", false)):
		m += 0.4   # the Path reads the Ashfields as validation
	var halvar: SimCharacter = characters.get(halvar_id)
	if halvar != null and halvar.alive:
		m -= 0.2   # proper death-witnessing elsewhere: fewer bring their dying east
	return maxf(0.2, m)


func _silence_made_tick() -> void:
	if ashfields.is_empty():
		return
	_ashfields_tick()
	_forsaken_tick()
	_convergence_tick()


func _ashfields_tick() -> void:
	if str(ashfields["resolved"]) == "destroyed":
		# the military solution's long shadow: the undirected dead
		var shades := float(ashfields["dispersed"])
		if shades > 1.0:
			ashfields["dispersed"] = shades * 0.99
			if srng.randf() < 0.08:
				_log("Word from the east: Returned wander the Ashfields roads with no one to direct them — travellers give the grey country a wide berth, and the Iron Library's record of what was lost there grows another page.")
		return
	if str(ashfields["resolved"]) == "settled":
		return
	# the settling problem (doc §4): unanchored Returned thin, stage by stage
	var to_settling := float(ashfields["recently"]) * 0.10
	var to_settled := float(ashfields["settling"]) * 0.035
	var to_hollow := float(ashfields["settled"]) * 0.012
	ashfields["recently"] = float(ashfields["recently"]) - to_settling
	ashfields["settling"] = float(ashfields["settling"]) + to_settling - to_settled
	ashfields["settled"] = float(ashfields["settled"]) + to_settled - to_hollow
	ashfields["hollow"] = float(ashfields["hollow"]) + to_hollow
	# intake, not conquest (doc §3): the grieving bring their dying east
	var intake := srng.randf_range(8.0, 17.0) * ashfields_intake_mult()
	if int(ashfields["framework_stage"]) >= 3:
		ashfields["anchored"] = float(ashfields["anchored"]) + intake
	else:
		ashfields["recently"] = float(ashfields["recently"]) + intake
	ashfields["living"] = float(ashfields["living"]) + intake * 0.25
	ashfields["warden_dead"] = float(ashfields["warden_dead"]) + intake * 0.05
	if srng.randf() < 0.05:
		_log("A family reaches the Ashfields boundary with a cart and a dying man. Caeris reads them his documentation — every word of it — and accepts. The consent is imperfect. He knows. It is one of the things he has been trying to solve.")
	# recognition thresholds (doc §3): the community becomes undeniable
	var total := ashfields_population()
	var marks := [5000.0, 10000.0, 25000.0]
	while int(ashfields["recognition"]) < 3 and total >= float(marks[int(ashfields["recognition"])]):
		ashfields["recognition"] = int(ashfields["recognition"]) + 1
		match int(ashfields["recognition"]):
			1:
				_log("[b]The Ashfields passes five thousand souls[/b] — no longer an unusual community Pellar tolerates, but an institutional presence its correspondence must acknowledge.")
			2:
				_log("[b]The Ashfields passes ten thousand[/b] — formal correspondence between the Iron Library and Durn is standard practice now, and realm-level policy can no longer pretend the grey country is empty.")
			3:
				_log("[b]The Ashfields passes twenty-five thousand[/b] — a continental-scale phenomenon. No single realm has the capacity to answer what it asks.")
	# the consent framework, stage by stage (doc §5)
	match int(ashfields["framework_stage"]):
		1:
			if (ashfields["endorsements"] as Array).size() >= ENDORSEMENTS_NEEDED \
					and tick - int(ashfields["stage_started"]) >= FRAMEWORK_STAGE1_MONTHS:
				ashfields["framework_stage"] = 2
				ashfields["stage_started"] = tick
				var voices := "Free City legal scholars take the drafting chairs"
				var halvar: SimCharacter = characters.get(halvar_id)
				if halvar != null and halvar.alive:
					voices += "; Halvar Stenn speaks for the Gravewarden Order on what a threshold owes the crossing"
				_log("[b]The consent framework council convenes[/b] — %s, the Brushgate Order sends an observer, and Thessaly Vorn keeps the record. Caeris attends by correspondence. His letters are precise and slightly impatient." % voices)
		2:
			if tick - int(ashfields["stage_started"]) >= FRAMEWORK_STAGE2_MONTHS:
				_framework_implemented()
	# Maret's arc (Canon Updates v1.0 §2): without the anchor, forty years
	# of sustained purpose is not enough — by Year 40 she is settled
	if int(ashfields["framework_stage"]) < 3 and tick >= 480:
		var maret: SimCharacter = characters.get(maret_id)
		if maret != null and maret.alive:
			_kill(maret, "settles — the practical hands of the Ashfields losing their economy of motion, the measured voice its measure, until nothing in particular tends the intake ledgers,")
			_log("Caeris files a monograph on the progression. The methodology is rigorous. The subject is Maret. He does not enjoy writing it. He notes the data anyway.")
	# his own decline (doc §2): purpose is the anchor, and waiting wears it
	if int(ashfields["framework_stage"]) < 3:
		if tick >= CAERIS_SETTLING_TICK and not bool(ashfields["caeris_settling"]):
			ashfields["caeris_settling"] = true
			_log("[b]Thessaly Vorn's field note, filed without comment:[/b] Caeris repeated himself twice today. He has never repeated himself. Thirty-one years the purpose held him against the settling. The waiting has begun to feel like something other than purpose.")
		elif bool(ashfields["caeris_settling"]) and tick >= CAERIS_SETTLED_TICK:
			ashfields["resolved"] = "settled"
			var c: SimCharacter = characters.get(caeris_id)
			if c != null and c.alive:
				_kill(c, "settles at last — the scholar thinning to an outline of himself and then to nothing in particular, the finding unpublished on his desk,")
			_log("[b]The Ashfields' lamps still burn[/b], tended by hands that no longer remember why they were lit. The anchor working dies with the only man who knew it. The Iron Library files Thessaly Vorn's eleven field reports under a single heading: what was lost by waiting.")


func _framework_implemented() -> void:
	## Doc §5, the collaboration outcome: the game's most transformative
	## and stable resolution. The finding is published.
	ashfields["framework_stage"] = 3
	ashfields["resolved"] = "framework"
	ashfields["caeris_settling"] = false
	var saved := float(ashfields["recently"]) * 0.6 + float(ashfields["settling"]) * 0.3
	ashfields["anchored"] = float(ashfields["anchored"]) + saved
	ashfields["recently"] = float(ashfields["recently"]) * 0.4
	ashfields["settling"] = float(ashfields["settling"]) * 0.7
	_shift_coherence("Aelindran Orthodox", -0.05)  # formal collaboration costs the old faith
	_log("[b]The finding is published.[/b] Old-tongue anchoring enters the Iron Library's open archive as a consent-framework document: a freely chosen purpose, selected before death, held against the settling. %d Returned receive the anchor retroactively. The ones already Settled cannot be brought back — Caeris's covering letter says so plainly, because he has never once dressed a result." % int(saved))
	var maret: SimCharacter = characters.get(maret_id)
	if maret != null and maret.alive:
		_log("Maret is among the first to receive the anchor — three years of holding herself together by purpose alone, and now the purpose is held by something more than will. Thessaly Vorn records the placement personally.")
	# the framework is the player's diplomatic masterwork (Hero System §3)
	if realms[0].ruler_id >= 0:
		award_hero_xp(realms[0].ruler_id, HeroDB.XP_AWARDS["political_conversion"], "the consent framework carried", true)
	award_hero_xp(caeris_id, HeroDB.XP_AWARDS["research_published"], "the finding published at last")
	_log("[b]The Ashfields becomes an institution[/b] — boundary stones, a registry, and a scholar with a purpose beyond waiting. Thessaly Vorn's twelfth field note is one line: 'He offered me tea, and this time he remembered that he had already asked.'")


# ------------------------------------------------ player engagement

func ashfields_status_line() -> String:
	if ashfields.is_empty():
		return ""
	match str(ashfields["resolved"]):
		"framework":
			return "The Ashfields: %d souls under the published framework — the settling problem is solved for the willing." % int(ashfields_population())
		"destroyed":
			return "The Ashfields: destroyed. The finding is lost; the undirected dead wander the grey country."
		"settled":
			return "The Ashfields: the scholar has settled. The lamps burn on, tended by no one in particular."
	var line := "The Ashfields: ~%d souls (%d Returned), growing by intake." % [
		int(ashfields_population()), int(ashfields_returned_total())]
	match int(ashfields["framework_stage"]):
		1:
			line += " Framework: political coordination — %d of %d endorsements." % [
				(ashfields["endorsements"] as Array).size(), ENDORSEMENTS_NEEDED]
		2:
			line += " Framework: the council drafts."
		_:
			if bool(ashfields["finding_heard"]):
				line += " He has told you what he needs."
			elif bool(ashfields["contacted"]):
				line += " He receives correspondence."
			else:
				line += " He is waiting for someone to help him with what he cannot ask for."
	if bool(ashfields["caeris_settling"]):
		line += " Caeris has begun to repeat himself."
	return line


func ashfields_envoy_gate(realm_id: int = 0) -> String:
	if ashfields.is_empty() or str(ashfields["resolved"]) != "":
		return "There is no one left in the Ashfields to receive an envoy."
	var r: Realm = realms[realm_id]
	if r.ruler_id < 0:
		return "An empty throne sends no envoys."
	if characters[r.ruler_id].learning < 16:
		return "Understanding the Ashfields research requires preparation the crown does not have (Learning 16)."
	if tick < 12:
		return "The Ashfields is still a rumor from the east roads — there is nothing yet to answer."
	return ""


func ashfields_send_envoy(realm_id: int = 0) -> String:
	var gate := ashfields_envoy_gate(realm_id)
	if gate != "":
		return gate
	var ruler: SimCharacter = characters[realms[realm_id].ruler_id]
	var opts: Array = [
		{"label": "Ask about the research", "base": 10, "ai": {"patience": 1.0},
			"effect": func() -> void:
				ashfields["contacted"] = true
				_log("Caeris explains the settling problem the way a man explains weather: The Returned thin. Purpose retards the rate. His own thirty-one years are the evidence. He offers the envoy tea out of habit and does not drink any himself.")},
		{"label": "Press him on the consent documentation", "base": 8, "ai": {"scheming": 0.5},
			"effect": func() -> void:
				ashfields["contacted"] = true
				_log("He does not defend the documentation. 'Thessaly Vorn has told me it is insufficient. She is correct. The alternative requires a framework that exists before death, and I cannot build it alone.'")},
		{"label": "Challenge the work itself", "base": 6, "ai": {"orthodoxy": 1.0},
			"effect": func() -> void:
				ashfields["contacted"] = true
				_log("Caeris engages the argument seriously and concedes nothing. 'Then tell me what you offer the ones who die and could have been Returned. I have been waiting thirty-one years for a better answer than mine.' The envoy does not have one.")},
	]
	if ruler.learning >= 20 or _thessaly_leads_library():
		opts.append({"label": "Ask about the anchoring working directly", "base": 12, "ai": {"patience": 1.0, "scheming": 0.5},
			"effect": func() -> void:
				ashfields["contacted"] = true
				ashfields["finding_heard"] = true
				_log("[b]Caeris shares the finding.[/b] Old-tongue anchoring: a freely chosen purpose, selected before death, binds the Returned against the settling. Tested. Held. Unpublished — 'because I have the finding and I cannot implement it alone and I do not know how to ask for what I need.' He has now asked.")})
	raise_event(realm_id, ruler.id, "The Scholar of the Ashfields",
		"The envoy is received in a farmhouse study east of Durn, by a man who is sixty-two years old, does not sleep, and speaks with the specific irritation of someone with more important things to do. Approximately sixty-three percent alive, by his own measurement. Thirty-six monographs on the wall.",
		opts, false, false, false, false, true)
	return "An envoy rides east into the grey country."


func _thessaly_leads_library() -> bool:
	var thessaly: SimCharacter = characters.get(thessaly_id)
	var marek: SimCharacter = characters.get(marek_id)
	return thessaly != null and thessaly.alive and (marek == null or not marek.alive)


func ashfields_commit_gate(realm_id: int = 0) -> String:
	if ashfields.is_empty() or str(ashfields["resolved"]) != "":
		return "There is nothing left to build."
	if not bool(ashfields["finding_heard"]):
		return "You have not heard the finding — send an envoy who can ask the right question."
	if int(ashfields["framework_stage"]) > 0:
		return "The framework is already underway."
	if not _thessaly_leads_library():
		return "The Iron Library must sponsor the framework, and Thessaly Vorn is not yet free to lead it."
	return ""


func ashfields_commit_framework(realm_id: int = 0) -> String:
	var gate := ashfields_commit_gate(realm_id)
	if gate != "":
		return gate
	ashfields["framework_stage"] = 1
	ashfields["stage_started"] = tick
	ashfields["endorsements"] = [realm_id]
	_log("[b]The consent framework begins[/b] — %s commits its seal, and Thessaly Vorn brings the Iron Library's sponsorship. Political coordination first: the framework needs %d realms' formal endorsement before the drafting council can sit." % [realms[realm_id].name, ENDORSEMENTS_NEEDED])
	return "The work Caeris could not ask for has begun."


func ashfields_seek_endorsement(map_realm_id: int, realm_id: int = 0) -> String:
	if int(ashfields["framework_stage"]) != 1:
		return "There is no coordination underway to endorse."
	if (ashfields["endorsements"] as Array).has(map_realm_id):
		return "That seal is already on the framework."
	var r: Realm = realms[realm_id]
	if r.gold < ENDORSE_COST:
		return "The embassy costs %d gold." % int(ENDORSE_COST)
	var target: SimCharacter = cast_ruler_of(map_realm_id)
	if target == null and map_realm_id == 1 and realms[1].ruler_id >= 0:
		target = characters[realms[1].ruler_id]
	if target == null or not target.alive:
		return "No crown answers there."
	r.gold -= ENDORSE_COST
	# dispositions are the rulers' own — deterministic, no dice
	var score := 0
	for pair in [["Compassionate", 2], ["Patient", 1], ["Methodical", 1], ["Gregarious", 1],
			["Honest", 1], ["Zealous", -3], ["Wrathful", -2], ["Paranoid", -1]]:
		if target.traits.has(pair[0]):
			score += int(pair[1])
	if score >= 1:
		(ashfields["endorsements"] as Array).append(map_realm_id)
		_log("[b]%s endorses the consent framework[/b] — %d of %d seals gathered." % [
			full_name(target), (ashfields["endorsements"] as Array).size(), ENDORSEMENTS_NEEDED])
		return "%s sets their seal to the framework." % full_name(target)
	_log("%s declines the framework embassy — the dead, they answer, should stay received, not Returned." % full_name(target))
	return "%s declines." % full_name(target)


func ashfields_march(realm_id: int = 0) -> String:
	## Doc §6, the military option: legitimate, achievable, and a specific
	## choice about what the player is willing to lose.
	if ashfields.is_empty() or str(ashfields["resolved"]) != "":
		return "There is nothing in the Ashfields to march against."
	var a: Army = main_army_of(realm_id)
	if a == null or a.regiments.is_empty():
		return "No army stands ready to march east."
	var defense: Array = []
	for i in maxi(3, int(ceil(float(ashfields["warden_dead"]) / 40.0))):
		defense.append({"kind": "warden_dead", "soldiers": 40})
	defense.append({"kind": "caeris_retinue", "soldiers": 12})
	var cmdr_martial := 0
	var cmdr_traits: Array = []
	if a.commander_id >= 0 and characters.has(a.commander_id):
		cmdr_martial = characters[a.commander_id].martial
		cmdr_traits = characters[a.commander_id].traits
	var sim := BattleSim.new()
	sim.setup_from_rosters(a.regiments, defense, cmdr_martial, 8,
		[str(realms[realm_id].name), "The Ashfields"], cmdr_traits, [], "ashfields", {"silence": true})
	# Caeris's combat presence is a scholar's (Canon Updates v1.0 §3): no
	# terror aura, no relish — Learning 26 tactical intelligence (+12%) and
	# twenty years of knowing every ditch of this ground (+15%), applied to
	# the defense's positioning. The Warden-Dead's own wrongness (unit-level
	# silence_terror) is theirs, not his — he coordinates, never amplifies.
	for reg: BattleSim.Regiment in sim.regiments:
		if reg.side == 1:
			reg.md *= 1.12 * 1.15
	if a.commander_id >= 0 and characters.has(a.commander_id):
		var cmdr: SimCharacter = characters[a.commander_id]
		sim.set_commander_info(0, {"name": full_name(cmdr), "martial": cmdr.martial,
			"intrigue": cmdr.intrigue, "prowess": cmdr.prowess, "traits": cmdr.traits.duplicate(),
			"oath_intact": cmdr.oath_token_intact, "faith": faith_of(cmdr)})
		# the marching commander's hero tier walks with them (Hero System v1.0)
		var atk_hero := hero_info(a.commander_id)
		if not atk_hero.is_empty():
			sim.set_hero(0, atk_hero)
	sim.set_commander_info(1, {"name": "Caeris the Unfinished", "martial": 8, "intrigue": 12,
		"prowess": 6, "traits": ["Threshold-Sensitive", "Focused", "Methodical", "Patient"],
		"oath_intact": true, "faith": ""})
	# Caeris himself stands with the retinue: a level-9 Legendary scholar
	# whose actions on this field are Observe, Redirect, and the Settling
	# Touch (Hero System v1.0 §7; the Canon Updates translations, live).
	var caeris_hero := hero_info(caeris_id)
	if not caeris_hero.is_empty():
		sim.set_hero(1, caeris_hero)
	sim.run_headless()
	for reg: BattleSim.Regiment in sim.regiments:
		if reg.side == 0 and reg.roster_index < a.regiments.size():
			a.regiments[reg.roster_index]["soldiers"] = reg.soldiers if reg.alive() else 0
	a.regiments = a.regiments.filter(func(reg) -> bool: return int(reg["soldiers"]) > 0)
	apply_hero_battle(sim, 0, true)  # the marcher's wounds, capture has no meaning here
	if sim.winner == 0:
		_ashfields_destroyed(realm_id)
		return "The Ashfields falls. What was lost there will be counted for a long time."
	_log("[b]The Ashfields holds.[/b] The Warden-Dead do not pursue past the boundary stones — Caeris considers the entire engagement a failure of communication, and says so, in writing, to the Iron Library. He finds it professionally frustrating.")
	return "The assault breaks against the Warden-Dead. Caeris does not pursue."


func _ashfields_destroyed(realm_id: int) -> void:
	## Doc §6's consequences, all of them. The game does not judge the
	## choice; it writes down the price.
	ashfields["resolved"] = "destroyed"
	ashfields["dispersed"] = ashfields_returned_total()
	var c: SimCharacter = characters.get(caeris_id)
	if c != null and c.alive:
		_kill(c, "is destroyed among his instruments — thirty-six monographs, eleven field visits, one unpublished finding, ending as ash in a farmhouse study,")
	var m: SimCharacter = characters.get(maret_id)
	if m != null and m.alive:
		_kill(m, "is unmade beside her work,")
	_log("[b]The finding is lost.[/b] Nobody else in Khessar knows the anchor working. The settling problem is now unsolvable — every Returned in the grey country will thin to an outline and then to nothing in particular, with no one to direct them.")
	_log("Four thousand living residents of the Ashfields scatter west as refugees. The Iron Library archives Thessaly Vorn's field notes as historical documentation, and records the destruction, in the Record's driest hand, as one of the most consequential wrong choices of the post-Silence period.")
	_shift_coherence("Aelindran Orthodox", 0.10)   # the destruction of heresy reads as orthodox victory
	var sil: Dictionary = faiths.get("The Silent Path", {})
	if bool(sil.get("active", false)):
		sil["membership"] = minf(0.6, float(sil.get("membership", 0.0)) + 0.03)
		_shift_coherence("The Silent Path", 0.05)  # the institutions chose suppression over understanding
	var ruler: SimCharacter = characters.get(realms[realm_id].ruler_id) if realms[realm_id].ruler_id >= 0 else null
	if ruler != null and ruler.alive:
		add_corruption(ruler, 2.0, "what the Ashfields was, and what was done to it")
		add_stress(ruler, 20.0, "the weight of the grey country")
	ashfields["living"] = 0.0
	for key in ["recently", "settling", "settled", "hollow", "anchored", "warden_dead"]:
		ashfields[key] = 0.0


# ------------------------------------------------ the Forsaken (doc §7-8)

func forsaken_region_of(realm_id: int) -> String:
	## Which regional variant a live realm's politics answer to.
	return "vael" if realm_id == 0 else "karn_vol"


func _forsaken_tick() -> void:
	## The generation born under the Silence organizes — slowly, then
	## undeniably. Growth accelerates with the cohort's age.
	var years := float(tick) / 12.0
	var sp_active := bool(faiths.get("The Silent Path", {}).get("active", false))
	for region in forsaken_movements:
		var mv: Dictionary = forsaken_movements[region]
		var g := (0.5 + 0.05 * years) * srng.randf_range(0.8, 1.2) * float(mv["growth_mult"])
		if sp_active:
			g *= 1.4
		if region == "southern_reach":
			g *= 0.9  # the least ideologically consolidated variant
		mv["strength"] = float(mv["strength"]) + g
		while int(mv["stage"]) < 4 and float(mv["strength"]) >= float(FORSAKEN_STAGES[int(mv["stage"])]):
			mv["stage"] = int(mv["stage"]) + 1
			_forsaken_stage_reached(str(region), int(mv["stage"]))
	# organized movements feed the Silent Path — but only once the canon-
	# asserted years (religion brief's Y20 numbers) are safely behind us
	if sp_active and tick > 250:
		var organized := 0
		for region in forsaken_movements:
			if int(forsaken_movements[region]["stage"]) >= 4:
				organized += 1
		if organized > 0:
			var f: Dictionary = faiths["The Silent Path"]
			f["membership"] = minf(0.6, float(f["membership"]) + 0.0004 * organized)
	# travelers cross-fertilize — and some of them go east to study
	if str(ashfields.get("resolved", "")) == "" and srng.randf() < 0.02:
		_log("A traveler Forsaken crosses into the Ashfields with a letter of introduction and a list of questions. Caeris answers the good ones. Some stay a season; some leave arguing with him in their heads for years.")


func _forsaken_stage_reached(region: String, stage: int) -> void:
	var label: String = FORSAKEN_VARIANTS[region]
	match stage:
		1:
			_log("Whispers in %s: the first Forsaken cells of %s begin meeting — young enough that the Silence is the only sky they have known." % [region.capitalize().replace("_", "-"), label])
		2:
			_log("[b]The Forsaken of %s organize openly[/b] — %s can no longer be dismissed as youth. Their claim is simple: they belong to the world the Silence produced, not the one their parents lost." % [region.capitalize().replace("_", "-"), label])
			var live_realm := _forsaken_live_realm(region)
			if live_realm >= 0 and realms[live_realm].ruler_id >= 0:
				_raise_forsaken_visible(live_realm, region)
		3:
			_log("[b]The Forsaken of %s become a political movement[/b] — candidates, publications, organizational capacity. %s now shapes appointments and votes." % [region.capitalize().replace("_", "-"), label])
		4:
			_log("[b]Regional dominance: the Forsaken are the loudest political voice of %s[/b] — a generation with organizational capacity and no nostalgia. Their militias drill openly now." % region.capitalize().replace("_", "-"))


func _forsaken_live_realm(region: String) -> int:
	for rid in realms.size():
		if forsaken_region_of(rid) == region:
			return rid
	return -1


func _raise_forsaken_visible(realm_id: int, region: String) -> void:
	## The visible-movement choice (doc §8): engage or suppress. Effects
	## stay inside the movement's own ledger — the realm's history keeps
	## its stream regardless of the answer.
	var mv: Dictionary = forsaken_movements[region]
	raise_event(realm_id, realms[realm_id].ruler_id, "The Generation the Silence Made",
		"They organize in open view now — the young who never knew an answering sky. Petitions, meeting halls, a newspaper of sorts. They are not asking permission.",
		[
			{"label": "Engage the movement", "base": 9, "ai": {"patience": 1.0},
				"effect": func() -> void:
					mv["growth_mult"] = float(mv["growth_mult"]) * 0.85
					mv["engaged"] = true
					_log("The crown engages the Forsaken — seats at minor tables, petitions answered in writing. The movement grows slower for being heard.")},
			{"label": "Suppress the cells", "base": 7, "ai": {"aggression": 1.0, "orthodoxy": 0.5},
				"effect": func() -> void:
					mv["strength"] = maxf(0.0, float(mv["strength"]) - 15.0)
					mv["growth_mult"] = float(mv["growth_mult"]) * 1.15
					_log("The cells are broken up, the meeting halls shuttered. The movement loses a season's strength and gains a decade's conviction — suppression is the best recruiter the Forsaken ever had.")},
		], false, false, false, false, true)


func forsaken_status_line() -> String:
	if forsaken_movements.is_empty():
		return ""
	var stage_names := ["quiet", "whispered", "visible", "political", "dominant"]
	var parts: Array = []
	for region in FORSAKEN_VARIANTS:
		var mv: Dictionary = forsaken_movements[region]
		if int(mv["stage"]) >= 1:
			parts.append("%s %s (%d)" % [region.capitalize().replace("_", "-"),
				stage_names[int(mv["stage"])], int(float(mv["strength"]))])
	if parts.is_empty():
		return "The Forsaken: children still — the generation born under the Silence has not yet found its voice."
	return "The Forsaken: " + ", ".join(PackedStringArray(parts)) + "."


# ------------------------------------------------ endgame convergence (doc §9)

func _convergence_tick() -> void:
	## Year 50: the three antagonist structures reach threshold together.
	## This pass names the ending's shape; the full Silence-cascade
	## mechanics stay with the endgame module (flagged).
	if convergence != "" or tick < CONVERGENCE_TICK or realms[0].ruler_id < 0:
		return
	var caeris_state := str(ashfields.get("resolved", ""))
	var pieces: Array = []
	pieces.append("The Architect's truth: %s." % central_secret_state)
	match caeris_state:
		"framework":
			pieces.append("The Ashfields: the framework holds — the settling problem is solved for the willing.")
		"destroyed":
			pieces.append("The Ashfields: destroyed, the finding lost.")
		"settled":
			pieces.append("The Ashfields: the scholar settled, still waiting.")
		_:
			pieces.append("The Ashfields: Caeris waits, still.")
	var strongest := 0.0
	for region in forsaken_movements:
		strongest = maxf(strongest, float(forsaken_movements[region]["strength"]))
	pieces.append("The Forsaken: the Silence-born are the working generation now (strongest movement: %d)." % int(strongest))
	var opts: Array = []
	if caeris_state == "framework" and central_secret_state in ["revealed", "leveraged", "contained"]:
		opts.append({"label": "A unified response — build the new order", "base": 14, "ai": {"patience": 1.0},
			"effect": func() -> void:
				convergence = "unified"
				_log("[b]THE WORLD THE SILENCE MADE:[/b] the truth published, the framework holding, the Forsaken given chairs instead of gallows. Khessar becomes something new — not the world before the Silence restored, but a genuine post-Silence order. (The full cascade arrives with the endgame module.)")})
	opts.append({"label": "Hold the institutions by force", "base": 6, "ai": {"aggression": 1.0, "orthodoxy": 0.5},
		"effect": func() -> void:
			convergence = "military"
			_log("[b]THE WORLD THE SILENCE MADE:[/b] suppression as policy — the institutions keep their form at genuine cost, and the cascade gathers. (The full consequences arrive with the endgame module.)")})
	opts.append({"label": "Yield to the new orthodoxies", "base": 8, "ai": {"greed": 0.5},
		"effect": func() -> void:
			convergence = "ideological"
			_log("[b]THE WORLD THE SILENCE MADE:[/b] the Silent Path preaches openly, the Ashfields keeps its autonomy%s, and the Forsaken inherit by default — a peaceful, transformed continent. (The full consequences arrive with the endgame module.)" % ("" if caeris_state != "" else " — and the settling problem continues"))})
	opts.append({"label": "Endure — and let it fragment", "base": 4, "ai": {},
		"effect": func() -> void:
			convergence = "fragmented"
			_log("[b]THE WORLD THE SILENCE MADE:[/b] no coalition forms. The three pressures exceed the continent's political capacity, and Aelindran civilization begins its long fragmentation into successor states. (The full consequences arrive with the endgame module.)")})
	raise_event(0, realms[0].ruler_id, "The World the Silence Made",
		"Year Fifty of the Silence. " + " ".join(PackedStringArray(pieces)),
		opts, false, false, false, false, true)


# ================================================================
# The Hero System v1.0 (Opus doc, 2026-07-08). Heroes amplify their
# armies; they do not replace them. All hero dice roll on hrng (seed
# 75); the seeded heroes are hero_cast — the fixed-seed history never
# feels their arrival. Auto-firing beats fill only the hero ledger
# (XP, personal HP, pool counts); the Core Six move only under the
# player's hand (level-ups from player-initiated awards apply stat
# growth; the chronicle's own awards bank the experience).
# ================================================================

func _seed_heroes() -> void:
	## §8's comprehensive list: the 30 canonical figures already alive in
	## the sim take their levels, and the 27 the chronicle owed a body
	## get one — companions, the Reactionary Council, the Order's field
	## commanders, the dwarven court, the Southern Reach circle.
	hrng.seed = 75  # the XP capstone: what a level-10 life amounts to
	# SRD 5.1 discipline (v1.1): classes are the PC chassis — the eleven,
	# for hero-tier souls only. Everyone else is their office
	# (position_of): the Queen is a Queen, not a "level 5 diplomat";
	# the merchant is a merchant; most people are courtiers and
	# commoners, ordinary until the day they pass, and that is fine.
	# --- the Magistocracy of Vael (realm 0) ---
	_hero_bless(anselm_id, "wizard", 3, {"combat": 1, "deploys": "never"})   # L3 admin, L1 combat (doc §8)
	_hero_bless(halloran_id, "wizard", 4, {"deploys": "rarely"})
	_hero_bless(davriand_id, "wizard", 3, {"deploys": "rarely"})
	_hero_bless(kreth_id, "wizard", 3, {"deploys": "never"})                 # dying
	_hero_bless(architect_id, "wizard", 8, {"sub": "archive", "combat": 1, "deploys": "never"})  # Veril: the craft is the Sublevel
	_hero_bless(mareck_id, "rogue", 6, {"sub": "watchful", "deploys": "rarely"})
	court_positions[mareck_id] = "Chief Spymaster"
	court_positions[sevrin_id] = "Secretary to the Council"                  # no class — a very good clerk
	for seat_level in [["Chancellor", 4], ["Master of War", 4], ["Chief Physician", 4]]:
		if magister_seats.has(seat_level[0]):
			_hero_bless(int(magister_seats[seat_level[0]]["holder"]), "wizard", int(seat_level[1]),
				{"deploys": "rarely"})
	_hero_bless(odric_id, "wizard", 5, {"deploys": "rarely"})                # Vasse, the senior of the four
	# --- the noble houses and the clans (realms 0-1) ---
	var garran := _hero_find("Garran", 0)
	if garran != null:
		_hero_bless(garran.id, "fighter", 5, {})                             # aging, still the realm's sword
	# Sera: no class — a House heir the Vigil may yet find (Courtier)
	var vorak := _hero_find("Vorak", 1)
	if vorak != null:
		_hero_bless(vorak.id, "fighter", 5, {"sub": "clan_sworn"})           # Diplomacy 20 already canon
	# --- Pellar and the Iron Library (the crowns and scholars are their
	# offices, not classes; only Vovel's old wizardry is a chassis) ---
	var pellar := _map_realm_named("Pellar")
	var ilyra := _hero_find("Ilyra", pellar)
	if ilyra != null:
		court_positions[ilyra.id] = "Princess of Pellar"
	_hero_bless(marek_id, "wizard", 8, {"sub": "archive", "combat": 2, "deploys": "never"})  # Vovel: L7 evoker in his prime, archive now
	court_positions[marek_id] = "Chief Archivist of the Iron Library"
	court_positions[thessaly_id] = "Archivist of the Iron Library"           # the desk comes at tick 44
	# --- Halven ---
	var halven := _map_realm_named("Halven")
	var selia := _hero_find("Selia", halven)
	if selia != null:
		court_positions[selia.id] = "Counselor of Halven"
	var mira := _hero_find("Mira", halven)
	if mira != null:
		_hero_bless(mira.id, "rogue", 3, {"sub": "thief"})                   # the Forsaken Underground's future
	# --- the Drevak world ---
	var vor_grim := _map_realm_named("Vor-Grim")
	if cast_rulers.has(vor_grim):
		_hero_bless(int(cast_rulers[vor_grim]["id"]), "fighter", 5, {"sub": "clan_sworn"})  # Grimkar
	# --- Kharak-Dum ---
	var kharak := _map_realm_named("Kharak-Dum")
	if cast_rulers.has(kharak):
		_hero_bless(int(cast_rulers[kharak]["id"]), "fighter", 6, {"deploys": "never"})  # Grimhold, aging
	var karth := _hero_find("Karth", kharak)
	if karth != null:
		_hero_bless(karth.id, "fighter", 4, {})
	# --- the Elven Great Houses ---
	var veldarin := _map_realm_named("Veldarin")
	if cast_rulers.has(veldarin):
		_hero_bless(int(cast_rulers[veldarin]["id"]), "wizard", 8, {"deploys": "never"})  # Analinth (doc: 8-9)
	var thaladris := _map_realm_named("Thaladris")
	if cast_rulers.has(thaladris):
		_hero_bless(int(cast_rulers[thaladris]["id"]), "bard", 8, {"sub": "carried_names", "deploys": "never"})  # Ariorwe, 120 names
	# --- the Southern Reach ---
	var saren := _map_realm_named("Saren-Vesh")
	# Vessa: First Councilor — the office is the identity (cast_title_of)
	# --- the faith cast and the Ashfields ---
	_hero_bless(halvar_id, "cleric", 7, {"sub": "threshold", "deploys": "rarely"})  # the Gravewarden: a Cleric domain, not a class
	_hero_bless(caeris_id, "wizard", 9, {"sub": "unfinished", "deploys": "never"})  # Legendary (doc: 8-9; MM Vol. II) — his own school
	_hero_bless(maret_id, "wizard", 5, {"sub": "unfinished", "deploys": "never"})   # the Revenant research associate, his one student
	# ---------------- the 27 the chronicle owed a body (doc §8) ----------------
	# The wandering companions (Class Archetypes):
	var marak := _hero_character("Marak", "House Khorul", false, 41, 0, "human", "aelindran",
		{"dip": 10, "mar": 8, "stw": 9, "int": 12, "lrn": 22, "prw": 8},
		["Restless", "Honest", "Arcane-Blooded", "Academy-Sworn"], "Pragmatic")
	_hero_bless(marak.id, "wizard", 5, {"deploys": "eager"})                 # walked away; walks the Salt Road
	var selene := _hero_character("Selene", "House Tharn", true, 36, 0, "human", "aelindran",
		{"dip": 16, "mar": 6, "stw": 10, "int": 8, "lrn": 14, "prw": 6},
		["Compassionate", "Patient", "Faith-Practicing"], "Zealous")
	_hero_bless(selene.id, "cleric", 4, {"sub": "life", "deploys": "rarely"})  # Vesper's End keeps her close
	var tavisol := _hero_character("Tavisol", "House of the Road", false, 24, 0, "human", "aelindran",
		{"dip": 8, "mar": 12, "stw": 6, "int": 5, "lrn": 8, "prw": 16},
		["Brave", "Honest", "Oath-Sworn"], "Zealous")
	_hero_bless(tavisol.id, "paladin", 3, {"sub": "devotion", "deploys": "eager"})
	# The Council of Reclaimed Rites (the Reactionaries hold Vael's old cathedral):
	var velmarin := _hero_character("Henrak", "House Velmarin", false, 71, 0, "human", "aelindran",
		{"dip": 18, "mar": 6, "stw": 14, "int": 10, "lrn": 20, "prw": 3},
		["Patient", "Purist", "Faith-Practicing"], "Zealous")
	_hero_bless(velmarin.id, "cleric", 6, {"sub": "reclaimed_rites", "deploys": "never"})  # the Presiding Voice rarely leaves the cathedral
	var mareldin := _hero_character("Lucius", "House Mareldin", false, 52, 0, "human", "aelindran",
		{"dip": 14, "mar": 5, "stw": 10, "int": 14, "lrn": 18, "prw": 5},
		["Purist", "Methodical", "Faith-Practicing"], "Zealous")
	_hero_bless(mareldin.id, "cleric", 5, {"sub": "reclaimed_rites", "deploys": "rarely"})  # the Warden of Doctrine travels for doctrine
	var vossa := _hero_character("Vossa", "House Thaledrin", false, 48, 0, "human", "aelindran",
		{"dip": 8, "mar": 22, "stw": 10, "int": 8, "lrn": 8, "prw": 18},
		["Brave", "Methodical"], "Zealous")
	_hero_bless(vossa.id, "fighter", 6, {})                                  # Marshal of the Faithful (doc: 5-6)
	var veskren := _hero_character("Tamlin", "House Veskren", false, 39, 0, "human", "aelindran",
		{"dip": 20, "mar": 4, "stw": 8, "int": 8, "lrn": 12, "prw": 5},
		["Gregarious", "Altruistic", "Faith-Practicing"], "Zealous")
	_hero_bless(veskren.id, "cleric", 4, {"sub": "life"})                    # the Voice to the Common travels widest
	var thossmar := _hero_character("Olyric", "House Thossmar", false, 44, 0, "human", "aelindran",
		{"dip": 8, "mar": 4, "stw": 12, "int": 18, "lrn": 20, "prw": 6},
		["Methodical", "Paranoid"], "Zealous")
	_hero_bless(thossmar.id, "rogue", 5, {"sub": "watchful", "deploys": "rarely"})  # Keeper of Records; a scholar's rogue
	var arlina := _hero_character("Arlina", "House Veth", true, 37, 0, "human", "aelindran",
		{"dip": 10, "mar": 6, "stw": 8, "int": 22, "lrn": 12, "prw": 12},
		["Paranoid", "Deceitful"], "Zealous")
	_hero_bless(arlina.id, "rogue", 5, {"sub": "watchful"})                  # the Watchful — the subclass is named for her office
	var youngric := _hero_character("Youngric", "House Halden", false, 26, 0, "human", "aelindran",
		{"dip": 16, "mar": 6, "stw": 8, "int": 6, "lrn": 14, "prw": 7},
		["Gregarious", "Ambitious", "Faith-Practicing"], "Zealous")
	_hero_bless(youngric.id, "cleric", 3, {"sub": "life"})                   # the Rising Voice — Anra Halden's kin by house
	# The Order of the Vigil-Sworn's field commanders:
	var vaelmark := _hero_character("Aldric", "House Vaelmark", false, 45, 0, "human", "aelindran",
		{"dip": 12, "mar": 20, "stw": 10, "int": 6, "lrn": 10, "prw": 20},
		["Brave", "Honest", "Patient", "Oath-Sworn"], "Zealous")
	_hero_bless(vaelmark.id, "paladin", 6, {"sub": "vigil"})                 # the founding commander
	var ilsen := _hero_character("Ilsen", "House the Righteous", true, 38, 0, "human", "aelindran",
		{"dip": 8, "mar": 18, "stw": 6, "int": 5, "lrn": 6, "prw": 21},
		["Brave", "Wrathful", "Oath-Sworn"], "Zealous")
	_hero_bless(ilsen.id, "paladin", 5, {"sub": "vigil", "deploys": "eager"})  # Dame Ilsen leads infantry from the front
	var voss := _hero_character("Marek", "House Voss", false, 33, 0, "human", "aelindran",
		{"dip": 8, "mar": 16, "stw": 6, "int": 6, "lrn": 7, "prw": 17},
		["Brave", "Impulsive", "Oath-Sworn"], "Zealous")
	_hero_bless(voss.id, "paladin", 4, {"sub": "vigil", "deploys": "eager"})  # Brother-Captain, cavalry
	var thornhardt := _hero_character("Vell", "House Thornhardt", true, 42, 0, "human", "aelindran",
		{"dip": 16, "mar": 8, "stw": 16, "int": 12, "lrn": 10, "prw": 6},
		["Ambitious", "Purist"], "Zealous")
	court_positions[thornhardt.id] = "Baroness"                              # Reactionary-aligned; no class, plenty of leverage
	# The dwarven court (Kharak-Dum):
	var bronvor := _hero_character("Bronvor", "House Iron-Deep", false, 96, kharak, "dwarf", "kharak_dum",
		{"dip": 10, "mar": 10, "stw": 16, "int": 8, "lrn": 22, "prw": 8},
		["Methodical", "Patient", "Focused"], "Pragmatic")
	_hero_bless(bronvor.id, "wizard", 6, {"sub": "ward_speech", "deploys": "rarely"})  # Chief Ward-Speaker: a Wizard school, not a class
	court_positions[bronvor.id] = "Chief Ward-Speaker"
	var veldrin_oh := _hero_character("Veldrin", "House Oak-Hammer", false, 64, kharak, "dwarf", "kharak_dum",
		{"dip": 8, "mar": 20, "stw": 12, "int": 6, "lrn": 8, "prw": 16},
		["Brave", "Stoic"], "Pragmatic")
	_hero_bless(veldrin_oh.id, "fighter", 5, {})                             # Lord Marshal
	# The clans (Karn-Vol and the interior):
	var drev := _hero_character("Drev", "House Karn-Vol", false, 31, 1, "orc", "karn_vol",
		{"dip": 6, "mar": 16, "stw": 6, "int": 8, "lrn": 5, "prw": 18},
		["Brave", "Impulsive"], "Pragmatic")
	_hero_bless(drev.id, "fighter", 4, {"sub": "clan_sworn", "deploys": "eager"})
	var grim_vg := _hero_character("Grim", "House Vol-Gar", false, 61, 1, "orc", "karn_vol",
		{"dip": 12, "mar": 18, "stw": 10, "int": 10, "lrn": 9, "prw": 14},
		["Patient", "Stoic"], "Pragmatic")
	_hero_bless(grim_vg.id, "fighter", 5, {"sub": "clan_sworn", "deploys": "rarely"})  # the Elder
	var kaal := _hero_character("Kaal", "House Vor-Grathkaz", false, 39, 1, "orc", "karn_vol",
		{"dip": 4, "mar": 20, "stw": 6, "int": 12, "lrn": 5, "prw": 20},
		["Wrathful", "Ambitious", "Cruel"], "Opportunistic")
	_hero_bless(kaal.id, "fighter", 5, {"sub": "clan_sworn", "deploys": "eager"})  # the compact-breaker
	# Pellar's marshal:
	var pellburn := _hero_character("Harold", "House Pellburn", false, 51, pellar, "human", "free_city",
		{"dip": 10, "mar": 20, "stw": 12, "int": 8, "lrn": 10, "prw": 14},
		["Methodical", "Honest"], "Pragmatic")
	_hero_bless(pellburn.id, "fighter", 5, {})                               # Lord Marshal Sir Harold
	# Halven's merchants and houses — offices, not classes (SRD rule):
	var otter := _hero_character("Otter", "House Straven", false, 45, halven, "human", "halveni",
		{"dip": 18, "mar": 4, "stw": 22, "int": 14, "lrn": 12, "prw": 5},
		["Gregarious", "Avaricious"], "Opportunistic")
	court_positions[otter.id] = "Master Merchant of the Salt Road"
	var aldon := _hero_character("Aldon", "House Halven-Rothe", false, 50, halven, "human", "halveni",
		{"dip": 16, "mar": 8, "stw": 16, "int": 12, "lrn": 12, "prw": 6},
		["Patient", "Content"], "Pragmatic")
	court_positions[aldon.id] = "Lord of House Halven-Rothe"
	# The Southern Reach circle:
	var iliana := _hero_character("Iliana", "House Vesh", true, 27, saren, "human", "southern_reach",
		{"dip": 18, "mar": 5, "stw": 6, "int": 12, "lrn": 12, "prw": 8},
		["Gregarious", "Restless"], "Pragmatic")
	iliana.names_carried = 40  # canonical; the Song-Marked trait is withheld in v1.0 —
	# _bard_tick draws an mrng die per Song-Marked soul, and her arrival
	# must not reshuffle the magic stream (flagged for Opus)
	_hero_bless(iliana.id, "bard", 4, {"sub": "carried_names", "deploys": "eager"})  # the unlanded adventurer
	var ren := _hero_character("Ren", "House Korren", false, 22, saren, "human", "southern_reach",
		{"dip": 14, "mar": 6, "stw": 8, "int": 10, "lrn": 10, "prw": 8},
		["Ambitious", "Gregarious"], "Pragmatic")
	court_positions[ren.id] = "Envoy of Saren-Vesh"                          # Vessa's house, the next generation
	var verrik := _hero_character("Halven", "House Verrik", false, 55, saren, "human", "southern_reach",
		{"dip": 18, "mar": 4, "stw": 14, "int": 12, "lrn": 12, "prw": 4},
		["Patient", "Honest"], "Pragmatic")
	court_positions[verrik.id] = "Master Envoy of Saren-Vesh"                # Master Verrik: the office is the man
	# The Free City crowns the map already names (not yet cast_rulers —
	# the Carath/Dunmore crown pass stays with Faction Cast; flagged):
	var carath := _map_realm_named("Carath")
	var carathwell := _hero_character("Harrold", "House Carathwell", false, 47, carath, "human", "free_city",
		{"dip": 12, "mar": 18, "stw": 14, "int": 8, "lrn": 8, "prw": 12},
		["Brave", "Content"], "Pragmatic")
	_hero_bless(carathwell.id, "fighter", 5, {"deploys": "rarely"})          # a Duke who earned the chassis young
	court_positions[carathwell.id] = "Duke of Carath"
	var dunmore := _map_realm_named("Dunmore")
	var thelren := _hero_character("Thelren", "House Dunmoreth", false, 44, dunmore, "human", "free_city",
		{"dip": 14, "mar": 10, "stw": 16, "int": 12, "lrn": 8, "prw": 6},
		["Avaricious", "Patient"], "Opportunistic")
	court_positions[thelren.id] = "Baron of Dunmore"                         # no class; the ledgers are weapon enough
	# --- the unnamed hero-tier population (doc §2/§5 density) ---
	# Named ≈57; the pool carries the rest of the continent's 200-400.
	hero_pool = {
		"vael": 50, "pellar": 12, "halven": 9, "aelindran": 20,
		"free_cities": 12, "drevak": 18, "kharak_dum": 14, "elven": 10,
		"brushgate": 24, "reactionaries": 55, "southern_reach": 10,
		"gravewardens": 16, "druids": 15, "warlocks": 16, "bards": 24,
	}


func _hero_character(p_name: String, house_name: String, female: bool, age: int,
		realm_id: int, race: String, culture: String, stats: Dictionary,
		p_traits: Array, response: String) -> SimCharacter:
	## A seeded canonical hero: a real person whose fate is battles and
	## the chronicle, never the marriage pools or the actuarial tables.
	## All dice on hrng; the canonical Core Six land AFTER the traits
	## (the Caeris rule — trait mods must not drift the doc's numbers).
	var dyn: Dynasty = null
	for d: Dynasty in dynasties.values():
		if d.name == house_name:
			dyn = d
			break
	if dyn == null:
		dyn = Dynasty.new(dynasties.size(), house_name)
		dynasties[dyn.id] = dyn
	var c := _create_character(p_name, female, tick - age * 12 - hrng.randi_range(0, 11), dyn.id, realm_id)
	c.race = race
	c.culture = culture
	c.genome = Genetics.founder(hrng)
	for t in p_traits:
		_add_trait(c, str(t))
	if response != "":
		_add_trait(c, response)
	for k in stats:
		c.set(STAT_PROPS[k], clampi(int(stats[k]), 1, 30))
	if p_traits.has("Faith-Practicing") or p_traits.has("Oath-Sworn"):
		c.faith = "Aelindran Orthodox"  # the Reactionaries and the Order keep the old rites
	hero_cast[c.id] = true
	return c


func _hero_bless(cid: int, class_id: String, level: int, opts: Dictionary = {}) -> void:
	## Grant hero-tier to an existing character: class (SRD chassis),
	## subclass (where the tradition lives), level, the XP that level
	## implies, and the personal HP pool. No dice.
	var c: SimCharacter = characters.get(cid)
	if c == null or not HeroDB.has_class(class_id):
		return
	c.hero_class = class_id
	c.hero_subclass = str(opts.get("sub", HeroDB.default_subclass(class_id)))
	c.hero_level = clampi(level, 1, HeroDB.MAX_LEVEL)
	c.hero_xp = HeroDB.xp_for_level(c.hero_level)
	c.hero_hp_max = HeroDB.hp_max(class_id, c.hero_level)
	c.hero_hp = c.hero_hp_max
	c.hero_combat_level = int(opts.get("combat", -1))
	hero_deploys[cid] = str(opts.get("deploys", "normal"))


func position_of(c: SimCharacter) -> String:
	## The SRD rule (Hero System v1.1): ordinary souls have no class —
	## they are identified by what they do at court. Canonical offices
	## first, then the offices the sim itself hands out, then the
	## defaults every court has: courtiers, and the children who will be.
	if c == null or not c.alive:
		return ""
	if court_positions.has(c.id):
		return str(court_positions[c.id])
	var cast_t := cast_title_of(c.id)
	if cast_t != "":
		return cast_t
	if c.realm_id >= 0 and c.realm_id < realms.size() and realms[c.realm_id].ruler_id == c.id:
		return live_ruler_title(c.realm_id, c)
	var seat := magister_seat_of(c.id)
	if seat != "":
		return seat
	if c.realm_id >= 0 and c.realm_id < realms.size():
		for seat_name in SEAT_STAT:
			var m := council_member(c.realm_id, str(seat_name))
			if m != null and m.id == c.id:
				return str(seat_name)
	for a: Army in armies:
		if a.commander_id == c.id:
			return "Commander"
	for pid in county_holders:
		if int(county_holders[pid]) == c.id:
			return "Lady" if c.is_female else "Lord"
	if wards.has(c.id) and bool(wards[c.id].get("hostage", false)):
		return "Hostage"
	if c.age_years(tick) < ADULT_AGE:
		return "Child of the Court"
	return "Courtier"


func _hero_find(given_name: String, realm_id: int) -> SimCharacter:
	## The canonical figures seeded before ids were kept: found by given
	## name within their realm. Dictionary order is insertion order —
	## deterministic by construction.
	for c: SimCharacter in characters.values():
		if c.alive and c.name == given_name and c.realm_id == realm_id:
			return c
	return null


func hero_combat_level(c: SimCharacter) -> int:
	return c.hero_combat_level if c.hero_combat_level > 0 else c.hero_level


func hero_wounded(cid: int) -> bool:
	var c: SimCharacter = characters.get(cid)
	return c != null and c.hero_wounded_until > tick


func award_hero_xp(cid: int, amount: int, reason: String, by_hand: bool = false) -> void:
	## Experience lands on the hero ledger. Level-ups always raise the
	## personal HP pool; the Core Six grow only when the award was the
	## player's doing (the hero stream discipline — auto-firing beats
	## must never drift a canonical stat block mid-history).
	var c: SimCharacter = characters.get(cid)
	if c == null or not c.alive or c.hero_level <= 0 or amount <= 0:
		return
	c.hero_xp += amount
	while c.hero_level < HeroDB.MAX_LEVEL and c.hero_xp >= HeroDB.xp_for_level(c.hero_level + 1):
		c.hero_level += 1
		c.hero_hp_max = HeroDB.hp_max(c.hero_class, c.hero_level)
		c.hero_hp = c.hero_hp_max
		if by_hand:
			for k in HeroDB.growth(c.hero_class):
				var prop: String = STAT_PROPS[k]
				c.set(prop, clampi(int(c.get(prop)) + 1, 1, 30))
		_log("[b]%s reaches level %d[/b] as a %s — %s." % [full_name(c), c.hero_level,
			HeroDB.class_label(c.hero_class), reason])


func hero_info(cid: int) -> Dictionary:
	## The dict a battle carries: everything battle_sim.set_hero needs.
	var c: SimCharacter = characters.get(cid)
	if c == null or c.hero_level <= 0 or not c.alive:
		return {}
	return {
		"id": c.id, "name": full_name(c), "class": c.hero_class,
		"subclass": c.hero_subclass if c.hero_subclass != "" else HeroDB.default_subclass(c.hero_class),
		"level": c.hero_level, "combat_level": hero_combat_level(c),
		"legendary": c.hero_level >= HeroDB.LEGENDARY_LEVEL,
		"hp": c.hero_hp, "hp_max": c.hero_hp_max,
		"prowess": c.prowess, "names": c.names_carried,
		"traits": c.traits.duplicate(), "oath_intact": c.oath_token_intact,
	}


func apply_hero_battle(sim: BattleSim, side: int, player_initiated: bool = true) -> String:
	## After the field: the hero's disposition, wounds, capture, death —
	## and the experience the battle was worth. Returns a chronicle line.
	var h: Dictionary = sim.heroes[side]
	if h.is_empty():
		return ""
	var c: SimCharacter = characters.get(int(h["id"]))
	if c == null or not c.alive:
		return ""
	var won: bool = sim.winner == side
	var xp: int = HeroDB.XP_AWARDS["battle_survived"]
	if won:
		xp += int(HeroDB.XP_AWARDS["battle_victory"])
	if str(sim.hero_state[1 - side]) == "dead":
		xp += int(HeroDB.XP_AWARDS["enemy_hero_killed"])
	if bool(h.get("legendary", false)):
		xp += int(HeroDB.XP_AWARDS["legendary_action"]) * int(sim.hero_actions_used[side])
	var line := ""
	match str(sim.hero_state[side]):
		"dead":
			_kill(c, "fell on the field — the death saves ran out,")
			line = "%s fell on the field." % full_name(c)
		"unconscious", "stable":
			c.hero_hp = 1
			if won or sim.winner < 0:
				_add_trait(c, "Wounded")
				c.hero_wounded_until = tick + 6
				line = "%s is carried from the field alive, barely — months of recovery ahead." % full_name(c)
			else:
				# taken alive on a lost field: the champion's-chains rule
				var captor_realm := -1
				var enemy_h: Dictionary = sim.heroes[1 - side]
				if not enemy_h.is_empty():
					var ec: SimCharacter = characters.get(int(enemy_h["id"]))
					if ec != null and ec.realm_id >= 0 and ec.realm_id < realms.size():
						captor_realm = ec.realm_id
				if captor_realm >= 0 and realms[captor_realm].ruler_id >= 0:
					wards[c.id] = {"home": c.realm_id, "host": captor_realm,
						"guardian": realms[captor_realm].ruler_id,
						"hostage": true, "since": tick, "of_age": true}
					c.realm_id = captor_realm
					line = "[b]%s is taken alive[/b] — a hero in chains, awaiting ransom." % full_name(c)
				else:
					_add_trait(c, "Wounded")
					c.hero_wounded_until = tick + 6
					line = "%s is dragged from the rout alive, barely." % full_name(c)
		_:
			c.hero_hp = maxi(1, int(round(float(sim.hero_hp[side]))))
	if c.alive:
		award_hero_xp(c.id, xp, "the field taught what it teaches", player_initiated)
	if line != "":
		_log(line)
	return line


func _hero_tick() -> void:
	## The hero ledger's own month: wounds knit, the pool drifts.
	for c: SimCharacter in characters.values():
		if c.hero_level <= 0 or not c.alive:
			continue
		if c.hero_hp < c.hero_hp_max:
			c.hero_hp = mini(c.hero_hp_max, c.hero_hp + 8)  # a month of rest
	if tick % 12 != 0 or tick == 0:
		return
	# doc §2: +20-40 emerge and 15-30 die per year, steady state 300-500.
	# Deterministic midpoints, scaled by how full the continent already is.
	var total := hero_count()
	var room := clampf(1.0 - float(total) / 500.0, 0.0, 1.0)
	hero_pool_carry += 28.0 * room - 21.0 * minf(1.0, float(total) / 350.0)
	var order: Array = hero_pool.keys()  # insertion order: deterministic
	var i := 0
	while hero_pool_carry >= 1.0 and not order.is_empty():
		hero_pool_carry -= 1.0
		hero_pool[order[i % order.size()]] = int(hero_pool[order[i % order.size()]]) + 1
		i += 1
	while hero_pool_carry <= -1.0 and not order.is_empty():
		hero_pool_carry += 1.0
		var key: String = order[i % order.size()]
		hero_pool[key] = maxi(0, int(hero_pool[key]) - 1)
		i += 1


func hero_count() -> int:
	## Named living heroes plus the unnamed pool: the continent's total.
	var n := 0
	for c: SimCharacter in characters.values():
		if c.alive and c.hero_level > 0:
			n += 1
	for key in hero_pool:
		n += int(hero_pool[key])
	return n


func live_ruler_title(realm_id: int, c: SimCharacter) -> String:
	## What a live realm's crown is actually called (Administrative
	## v1.0): the Magistocracy elects a Grand Magister; the clan follows
	## a Chief; feudal realms crown Kings and Queens.
	match str(realms[realm_id].government):
		"administrative":
			return "Grand Magister"
		"tribal":
			return "Chief"
		_:
			return "Queen" if c.is_female else "King"


func province_of_character(c: SimCharacter):
	## Where a life is actually lived: commanders in the field, lords on
	## their land, everyone else at the realm's capital.
	for a: Army in armies:
		if a.commander_id == c.id:
			return _province_at(a.pos)
	for pid in county_holders:
		if int(county_holders[pid]) == c.id:
			return map.provinces[pid]
	if c.realm_id >= 0 and c.realm_id < map.realms.size():
		var cap: int = map.realms[c.realm_id].capital_province_id
		if cap >= 0 and cap < map.provinces.size():
			return map.provinces[cap]
	return null


func faith_reliability(c: SimCharacter, p, threshold: bool = false) -> float:
	## The Cleric geography formula (doc §4.3): base × the ground's
	## dampening × shared attention × the caster's answer to the Silence.
	## The world's remaining faith works — sometimes, in specific places,
	## when the right conditions align. Module 9 adds the caster's faith's
	## coherence to the chain — and threshold castings (deaths, oaths,
	## births, crossings) run on the older theology that never went silent.
	var damp := FAITH_DAMPENING_BASE
	if p != null:
		if p.silence_touched:
			damp = FAITH_DAMPENING_ASHFIELDS
		elif str(p.special_feature) == "iron_library":
			damp = FAITH_DAMPENING_LIBRARY
		elif str(p.special_feature) == "sealed_hold":
			damp = FAITH_DAMPENING_WARDSTONE  # the Kharak-Dum wards still hold a little sky up
	if threshold:
		# the God of Thresholds attends transitions everywhere — even the
		# Ashfields' sky cannot stop a properly witnessed crossing
		damp = maxf(damp, 0.55)
	var r := trait_mult(c, "faith_channel_reliability_baseline") * damp
	# shared attention: every ten faithful in the hall stand in for the sky.
	# The hero cast stands outside the crowd (Hero System v1.0): the seeded
	# canonical heroes must not thicken the halls the fixed-seed history
	# already prayed in — their congregations arrive with future beats.
	var crowd := 0
	for o in characters.values():
		if o.alive and o.realm_id == c.realm_id and o.id != c.id and not hero_cast.has(o.id):
			crowd += 1
	r *= 1.0 + 0.01 * float(mini(crowd, 100))
	for resp in RESPONSE_FAITH_MULT:
		if c.traits.has(resp):
			r *= float(RESPONSE_FAITH_MULT[resp])
			break
	# a fracturing doctrine prays worse (Module 9 §3): coherence reads
	# through into every channel the faith's members attempt
	var fr: Dictionary = faiths.get(faith_of(c), {})
	if not fr.is_empty() and bool(fr["active"]):
		r *= 0.6 + 0.5 * float(fr["coherence"])
	if threshold:
		r *= trait_mult(c, "threshold_binding_strength") + c.threshold_binding_bonus_permanent
	return clampf(r, 0.0, 1.0)


func _magic_tick() -> void:
	## The monthly weave: coming-of-age answers, the land's slow marking,
	## academies, prayers, patrons, oaths, songs, and the old man's door.
	_responses_coming_of_age()
	_regional_magic_tick()
	_academy_tick()
	_faith_tick()
	_patron_tick()
	_oath_tick()
	_bard_tick()
	_brushgate_tick()
	_architect_tick()


func _responses_coming_of_age() -> void:
	## Children raised in the Silence answer it around fifteen — shaped
	## by who they have already become (doc §3).
	for c in characters.values():
		if c.alive and c.age_years(tick) >= 15 and not _has_silence_response(c):
			var resp := _pick_silence_response(c)
			_add_trait(c, resp)
			if is_heir_of_any(c.id):
				_log("%s comes to their own answer to the Silence: %s." % [full_name(c), resp])


func is_heir_of_any(char_id: int) -> bool:
	for realm: Realm in realms:
		var h := heir_of(realm.id)
		if h != null and h.id == char_id:
			return true
	return false


func _magic_residents() -> Array:
	## The characters whose ground actually matters: crowned heads,
	## landed lords, and commanders in the field.
	var seen := {}
	var out: Array = []
	for realm: Realm in realms:
		if realm.ruler_id >= 0:
			seen[realm.ruler_id] = true
	for pid in county_holders:
		seen[int(county_holders[pid])] = true
	for a: Army in armies:
		if a.commander_id >= 0:
			seen[a.commander_id] = true
	for cid in seen:
		var c: SimCharacter = characters.get(int(cid))
		if c != null and c.alive:
			out.append(c)
	return out


func _regional_magic_tick() -> void:
	## The land under the Silence marks the people who live on it (doc §5).
	for c: SimCharacter in _magic_residents():
		var p = province_of_character(c)
		if p == null:
			continue
		if p.silence_touched and trait_add(c, "silence_immunity") < 1.0:
			add_corruption(c, CORRUPTION_ASHFIELDS_MONTHLY, "living under the Ashfields' sky")
			add_stress(c, 1.5, "the Silence presses close")
			if mrng.randf() < 0.03:
				_silence_encounter(c, p)
		elif p.ruined:
			add_corruption(c, CORRUPTION_RUINED_MONTHLY, "the Aurath ruins do not sleep")


func _silence_encounter(c: SimCharacter, p) -> void:
	## A Hollow Shade, a Settled village, a thing that should not stand
	## in daylight. Most souls break a little; the Brushgate sit with it.
	_add_secret(c.id, "silence_encounter_witnessed")
	if c.traits.has("Gravewarden-Sworn") and frng.randf() < 0.85:
		# the Threshold Rite (Module 9 addendum): the Shade is not fought —
		# it is received, named, and properly crossed
		c.threshold_binding_bonus_permanent = minf(0.6, c.threshold_binding_bonus_permanent + 0.02)
		c.wooden_birds_carved += 1
		_log("[b]A Hollow Shade rises near %s[/b] — and %s performs the Threshold Rite. The Shade is received, named, and crossed. No blade was drawn." % [p.name, full_name(c)])
		return
	if c.traits.has("Brushgate-Trained"):
		add_stress(c, 10.0, "sitting with a manifestation")
		_log("[b]Something manifests near %s[/b] — and %s sits with it until it passes. The Brushgate way." % [p.name, full_name(c)])
	else:
		add_stress(c, 40.0, "a Silence-touched manifestation")
		add_corruption(c, 0.5, "what was witnessed at %s" % p.name)
		_log("[b]Something manifests near %s.[/b] %s will not speak of what they saw — but their hands shake for weeks." % [p.name, full_name(c)])


func _academy_tick() -> void:
	## The Magistocracy's detection machinery — and everything it misses
	## (doc §4.1–4.2). Missed aptitude grows up untrained: a Sorcerer.
	for c in characters.values():
		if not c.alive or c.traits.has("Arcane-Blooded"):
			continue
		var age: int = c.age_years(tick)
		if age < 10 or age > 14:
			continue
		if c.learning < 12 and not c.traits.has("Genius"):
			continue
		if c.realm_id == 0 and mrng.randf() < 0.10:
			_add_trait(c, "Arcane-Blooded")
			_add_trait(c, "Academy-Sworn")
			_log("[b]The academy examiners come for %s[/b] — and the blood answers. Twelve years of training begin." % full_name(c))
			# three of the blood sworn to the academies marks the line
			var root := root_house_id(c.dynasty_id)
			var sworn := 0
			for m in characters.values():
				if m.alive and root_house_id(m.dynasty_id) == root and m.traits.has("Academy-Sworn"):
					sworn += 1
			if sworn >= 3:
				_earn_mythos(root, "Vael-Educated")
		elif c.realm_id != 0 and mrng.randf() < 0.04:
			_add_trait(c, "Arcane-Blooded")
			_add_secret(c.id, "arcane_manifestation_hidden")
			_log("Beyond any academy's reach, something wakes in %s — sparks answer their moods, and the household says nothing." % full_name(c))
	# Magistocracy recruitment: an untrained adult practitioner inside
	# Vael's own borders is a question the crown must answer
	for c in characters.values():
		if not c.alive or c.realm_id != 0 or c.age_years(tick) < ADULT_AGE:
			continue
		if not c.traits.has("Arcane-Blooded") or c.traits.has("Academy-Sworn"):
			continue
		if mrng.randf() < 0.05:
			_raise_recruitment(c)
			break


func _raise_recruitment(c: SimCharacter) -> void:
	var who := c
	raise_event(0, realms[0].ruler_id, "The Blood Untaught",
		"%s carries the arcane blood and no academy's discipline — uncontained, uncounted, and inside the crown's own borders. The Magistocracy's way is to bring such people in. Or to keep a file on them." % full_name(c),
		[
			{"label": "Bring them into the fold — a late apprenticeship", "base": 4.0,
				"ai": {"patience": 0.5},
				"effect": func() -> void:
					_add_trait(who, "Academy-Sworn")
					_log("%s takes the academy oath — late, watched, and warily welcome." % full_name(who))},
			{"label": "Open a file — leverage is cheaper than tuition", "base": 2.0,
				"ai": {"scheming": 0.7},
				"effect": func() -> void:
					_add_secret(who.id, "arcane_manifestation_hidden")
					for s in secrets:
						if int(s["subject"]) == who.id and str(s["type"]) == "arcane_manifestation_hidden":
							s["known"][0] = true
					_gain_hook(0, who.id, "weak", "arcane_manifestation_hidden")},
		], true)


func _faith_tick() -> void:
	## The quarterly devotions (doc §4.3): the candles are lit whether or
	## not anything answers. Three failures in a year is a Faith Crisis.
	if tick % 3 != 0:
		return
	for c in characters.values():
		if not c.alive or not c.traits.has("Faith-Practicing") or is_cast(c):
			continue
		var p = province_of_character(c)
		var rel := faith_reliability(c, p)
		if mrng.randf() < rel:
			add_stress(c, -10.0, "a rite that held")
			faith_failures.erase(c.id)
			if rel < 0.25:
				# an answer that mathematically should not have come —
				# the pantheon is silent; something else picked up
				add_corruption(c, 0.5, "a prayer answered by the wrong listener")
				_log("[b]A prayer is answered where no answer should reach[/b] — and %s does not ask by whom." % full_name(c))
		else:
			add_stress(c, 5.0, "praying into the silence")
			faith_failures[c.id] = int(faith_failures.get(c.id, 0)) + 1
			prayer_fails_ever[c.id] = int(prayer_fails_ever.get(c.id, 0)) + 1  # Module 9: the lifetime ledger
			if int(faith_failures[c.id]) >= 3:
				faith_failures.erase(c.id)
				_raise_faith_crisis(c)


func _raise_faith_crisis(c: SimCharacter) -> void:
	## Three unanswered years of candles. Something has to give (doc §4.3).
	var who := c
	raise_event(c.realm_id, c.id, "A Faith in Crisis",
		"%s has prayed three times into nothing. The candles gutter, the altar is cold, and the question can no longer be put off: what is the practice *for* now?" % full_name(c),
		[
			{"label": "Intensify the practice — the rites must be kept regardless", "base": 3.0,
				"ai": {"orthodoxy": 1.0, "patience": 0.3},
				"effect": func() -> void:
					_swap_silence_response(who, "Zealous")
					_log("%s answers the empty sky with harder devotion. The rites will be kept — whether or not anyone keeps them company." % full_name(who))},
			{"label": "Set down the candles — there is nothing there", "base": 2.0,
				"ai": {"patience": -0.3},
				"effect": func() -> void:
					_remove_trait(who, "Faith-Practicing")
					_swap_silence_response(who, "Broken")
					_log("%s snuffs the altar candles and walks out. The office stands empty." % full_name(who))},
			{"label": "Seek another listener — something answers, somewhere", "base": 1.0,
				"ai": {"orthodoxy": -1.0, "scheming": 0.5},
				"effect": func() -> void: _raise_patron_offer(who)},
		], true)


func _patron_tick() -> void:
	## The Offer comes when you have nothing left; the Communication
	## comes whenever it pleases (doc §4.6).
	if patron_network_broken:
		return
	for c in characters.values():
		if c.alive and not is_cast(c) and c.stress >= 180.0 and not c.traits.has("Patron-Bound") \
				and c.age_years(tick) >= ADULT_AGE and mrng.randf() < 0.06:
			_raise_patron_offer(c)
			break
	for c in characters.values():
		if c.alive and c.traits.has("Patron-Bound") and not is_cast(c) and mrng.randf() < 0.04:
			_raise_patron_communication(c)
			break


func _raise_patron_offer(c: SimCharacter) -> void:
	if patron_network_broken or c.traits.has("Patron-Bound"):
		return
	var who := c
	raise_event(c.realm_id, c.id, "The Patron's Offer",
		"Something has noticed %s. It speaks without sound, from the corner of the room where the light does not quite reach. Its terms are simple. Its price is not itemized." % full_name(c),
		[
			{"label": "Refuse — whatever it is, it is not help", "base": 4.0,
				"ai": {"orthodoxy": 1.0, "patience": 0.3},
				"effect": func() -> void:
					add_stress(who, -10.0, "the refusal itself was an answer")
					_log("%s refuses the thing in the corner of the room. It does not seem offended. It seems patient." % full_name(who))},
			{"label": "Accept the bargain", "base": 1.0,
				"ai": {"orthodoxy": -1.2, "scheming": 0.6, "greed": 0.4},
				"effect": func() -> void:
					_add_trait(who, "Patron-Bound")
					_add_secret(who.id, "patron_bargain_signed")
					who.stress = maxf(0.0, who.stress - 120.0)
					add_corruption(who, 2.5, "the bargain, signed")
					_log("[b]%s accepts the bargain.[/b] The weight lifts at once — every part of it except the part that was added." % full_name(who))},
		], true)


func _raise_patron_communication(c: SimCharacter) -> void:
	var who := c
	raise_event(c.realm_id, c.id, "The Patron Speaks",
		"The light goes wrong in the corner of %s's chamber, and the Patron has things to say — useful things, about people who believe themselves unwatched." % full_name(c),
		[
			{"label": "Listen", "base": 2.0, "ai": {"scheming": 0.8},
				"effect": func() -> void:
					add_corruption(who, 1.0, "listening to the Patron")
					var unknown: Array = []
					for s in secrets:
						if str(s["type"]) == "silence_cause_complicity" or s["known"].has(who.realm_id):
							continue
						if bool(s.get("under", false)):
							continue  # the house vaults are beyond even the Patron's small talk (Pass Two)
						var subj: SimCharacter = characters.get(int(s["subject"]))
						if subj != null and subj.alive and subj.id != realms[who.realm_id].ruler_id:
							unknown.append(s)
					if unknown.is_empty():
						_log("The Patron speaks to %s of small things, testing. Nothing useful — this time." % full_name(who))
						return
					var s3: Dictionary = unknown[mrng.randi_range(0, unknown.size() - 1)]
					s3["known"][who.realm_id] = true
					_gain_hook(who.realm_id, int(s3["subject"]),
						"weak" if str(s3["type"]) == "bastard blood" else "strong", str(s3["type"]))
					_log("The Patron shows %s a secret no informant could have reached. The price goes on the ledger." % full_name(who))},
			{"label": "Refuse to hear it", "base": 3.0, "ai": {"orthodoxy": 0.8},
				"effect": func() -> void:
					add_corruption(who, -0.5, "a door held shut")
					_log("%s turns their face to the wall until the corner of the room is only a corner again." % full_name(who))},
		], true)


func _oath_tick() -> void:
	## Oath-craft (doc §4.4): the ritual persists though the ratification
	## is gone. Sworn rarely; tested rarely; broken at real cost.
	if tick % 6 == 0:
		for realm: Realm in realms:
			var best: SimCharacter = null
			for c in characters.values():
				if not c.alive or c.realm_id != realm.id or c.age_years(tick) < ADULT_AGE or is_cast(c):
					continue
				if c.prowess < 12 or c.traits.has("Oath-Sworn") or c.traits.has("Oathbreaker") \
						or c.traits.has("Patron-Bound"):
					continue
				if best == null or c.prowess > best.prowess:
					best = c
			if best != null and mrng.randf() < 0.10:
				_add_trait(best, "Oath-Sworn")
				best.oath_token_intact = true
				_log("[b]%s swears the old oath[/b] — ring of witnesses, token forged, words said whole. Nothing ratifies it now. It holds anyway." % full_name(best))
	for c in characters.values():
		if c.alive and c.traits.has("Oath-Sworn") and not is_cast(c) and mrng.randf() < 0.015:
			_raise_oath_challenged(c)
			break


func _raise_oath_challenged(c: SimCharacter) -> void:
	var who := c
	var realm: Realm = realms[c.realm_id]
	raise_event(c.realm_id, c.id, "The Oath, Challenged",
		"The moment arrives that every oath eventually buys: %s can profit handsomely by looking away — or keep the words, and pay for them." % full_name(c),
		[
			{"label": "Keep the oath, whatever it costs", "base": 3.0,
				"ai": {"orthodoxy": 0.8, "patience": 0.5},
				"effect": func() -> void:
					add_stress(who, 10.0, "the price of kept words")
					_log("%s keeps the oath. It costs what it costs — that was always the arrangement." % full_name(who))},
			{"label": "Break it — the world stopped enforcing these", "base": 1.0,
				"ai": {"scheming": 0.7, "greed": 0.8},
				"effect": func() -> void:
					_remove_trait(who, "Oath-Sworn")
					_add_trait(who, "Oathbreaker")
					realm.gold += 40.0
					add_stress(who, 40.0, "the oath, broken")
					add_corruption(who, 3.0, "what broke when the words did")
					_log("[b]%s breaks the oath.[/b] The gold is real. So, it turns out, was the oath — and everyone who witnessed it can see what is missing now." % full_name(who))},
		], true)


func _bard_tick() -> void:
	## Word-binding (doc §4.7): the names accumulate through the deaths
	## the Bard attends (wired in _kill) and the fires they sing at.
	if tick % 3 == 0:
		for c in characters.values():
			if not c.alive or not c.traits.has("Song-Marked"):
				continue
			var settlements := 0
			for p in map.provinces:
				if p.owner == c.realm_id:
					settlements += 1
			c.names_carried += 1 + settlements / 8
			award_hero_xp(c.id, HeroDB.XP_AWARDS["bardic_performance"], "a season sung between the fires")
			if mrng.randf() < 0.10:
				_log("%s sings the dead of another village into the record — %d names carried now, and every one of them weight and power both." % [
					full_name(c), c.names_carried])
	# the calling finds the young whose words already carry — but the
	# roads only hold so many singers per realm
	var singers := [0, 0]
	for c in characters.values():
		if c.alive and c.traits.has("Song-Marked") and c.realm_id >= 0 and c.realm_id <= 1:
			singers[c.realm_id] += 1
	for c in characters.values():
		if not c.alive or c.traits.has("Song-Marked"):
			continue
		if c.realm_id < 0 or c.realm_id > 1 or singers[c.realm_id] >= 2:
			continue
		var age: int = c.age_years(tick)
		if age >= 15 and age <= 22 and c.diplomacy >= 12 and mrng.randf() < 0.03:
			_add_trait(c, "Song-Marked")
			_log("%s takes to the roads between fires, asking each village for the names of its dead. The asking is the craft." % full_name(c))
			break


func _brushgate_tick() -> void:
	## The discipline (doc §4.8): stress converted, corruption sat with.
	if tick % 3 != 0:
		return
	for c in characters.values():
		if c.alive and c.traits.has("Brushgate-Trained") and (c.stress > 20.0 or c.corruption > 0.0):
			add_stress(c, -20.0, "the morning forms")
			add_corruption(c, -0.5, "the morning forms")


func _architect_tick() -> void:
	## The old man's door (doc §8). His death opens the chamber; before
	## that, only the Aurath-Voss archives can give the truth up early —
	## and a contained truth can always leak.
	if central_secret_state == "contained" and mrng.randf() < 0.01:
		_log("[b]The containment fails.[/b] A clerk talks, a page walks, a copy circulates — the truth the Council kept is loose.")
		_ending_revealed()
		return
	if architect_id < 0 or central_secret_state != "buried":
		return
	var a: SimCharacter = characters.get(architect_id)
	if a == null:
		return
	if not a.alive:
		# The vigil concluded on schedule (a delivery made, or the chamber
		# sealed at Phase Five): its own post-death beats carry the truth
		# from here (_vigil_tick — delivery cascades, the race for the door).
		if vigil_recipient != "" or vigil_sealed or tick >= ARCHITECT_DEATH_TICK:
			return
		if architect_phase >= 1 and architect_phase <= 5:
			# an unscheduled end — poison, plague, a plot the chamber could
			# not refuse: the vigil aborts, and the chamber opens haphazardly
			# (Vigil doc §3's proximity-recipient case, in its bluntest form)
			architect_phase = 6
			_log("[b]The vigil ends off-schedule.[/b] Whatever Veril Ormand was still deciding, the deciding is over.")
		_raise_architect_chamber()
		return
	if tick >= 60 and mrng.randf() < 0.002:
		# the die is drawn as it always was; but once a delivery has left
		# the chamber, the loose pages have nowhere new to lead
		if vigil_recipient == "":
			_log("[b]Loose pages surface from the Aurath-Voss archives[/b] — fragments of a vote taken in Year 112 of the Council, and of what it purchased.")
			_raise_architect_chamber()


func _raise_architect_chamber(opener_id: int = -1) -> void:
	## The complete record: seven signatures under a bargain with the
	## Patron, and the Silence its price. Five ways to hold the truth.
	## With an opener (the Vigil's 5A race), the first reader's own
	## character decides — the crown only hears about it afterward.
	central_secret_state = "opened"
	for s in secrets:
		if str(s["type"]) == "silence_cause_complicity":
			s["known"][0] = true
	var decider: int = realms[0].ruler_id
	var text := "Veril Ormand's chamber stands open at last — and in it, the complete record. The Magistocracy's foundation transaction: seven signatures under a bargain with the Patron, dated Year 112 of the Council. Three dissenters, all dead within eighteen months. The Silence was the invoice. What the crown does with the truth decides the age."
	if opener_id >= 0 and characters.has(opener_id) and opener_id != realms[0].ruler_id:
		decider = opener_id
		text = "Veril Ormand's chamber stands open at last — and it is %s who reaches it first. In it, the complete record: seven signatures under a bargain with the Patron, dated Year 112 of the Council. Three dissenters, all dead within eighteen months. The Silence was the invoice. The first reading shapes everything after — and the first reader was not the crown." % full_name(characters[opener_id])
		_log("[b]The race for the door is over.[/b] %s stands in the Architect's chamber with the only complete account of what the Magistocracy is." % full_name(characters[opener_id]))
	var opts := [
		{"label": "Publish it all — the world deserves the truth", "base": 2.0,
			"ai": {"orthodoxy": 1.0, "aggression": 0.4},
			"effect": func() -> void: _ending_revealed()},
		{"label": "Contain it within the council — reform quietly", "base": 3.0,
			"ai": {"patience": 0.7},
			"effect": func() -> void:
				central_secret_state = "contained"
				realms[0].tyranny = minf(100.0, realms[0].tyranny + 10.0)
				_log("[b]The record is sealed inside the council chamber.[/b] The reformers take the pen; the traditionalists take notes. Contained truths have a way of finding doors.")},
		{"label": "Destroy the anchor — end the Patron itself", "base": 2.0,
			"ai": {"orthodoxy": 0.6, "aggression": 0.6},
			"effect": func() -> void: _ending_destroyed()},
		{"label": "Use it — every complicit house, on a hook", "base": 1.5,
			"ai": {"scheming": 1.2},
			"effect": func() -> void:
				central_secret_state = "leveraged"
				for lord: SimCharacter in landed_vassals(0):
					_gain_hook(0, lord.id, "strong", "silence_cause_complicity")
				_log("[b]The record becomes an instrument.[/b] Every house that profited from the Council's bargain now answers to whoever holds the pages.")},
		{"label": "Bury it deeper — some truths end worlds", "base": 2.5,
			"ai": {"scheming": 0.4, "patience": 0.6},
			"effect": func() -> void:
				central_secret_state = "suppressed"
				_log("[b]The chamber is bricked shut.[/b] The Magistocracy survives whole — and the Silence continues, unexamined, toward whatever it was always building to.")},
	]
	if decider != realms[0].ruler_id:
		# The Vigil's race was lost: the truth belongs to whoever opened
		# the door, and their character — not the crown's, not the
		# player's — shapes the first reading. Resolved on the vigil's die.
		var ev := {"id": next_event_id, "realm_id": 0, "decider": decider,
			"title": "The Architect's Chamber", "text": text, "options": opts,
			"magic": false, "admin": false, "faith": false, "vigil": true}
		next_event_id += 1
		_ai_resolve_event(ev)
	else:
		raise_event(0, decider, "The Architect's Chamber", text, opts, true)


func _ending_revealed() -> void:
	central_secret_state = "revealed"
	realms[0].tyranny = minf(100.0, realms[0].tyranny + 30.0)
	realms[0].prestige = maxf(-100.0, realms[0].prestige - 50.0)
	realms[1].prestige = minf(100.0, realms[1].prestige + 15.0)
	for lord: SimCharacter in landed_vassals(0):
		if realms[0].ruler_id >= 0:
			add_memory(lord, "their crowns knew", realms[0].ruler_id, -40.0, 1.0)
	# Module 9 §10: the reveal cascade lands on the faiths — catastrophic
	# for the pantheon and for institutional legitimacy, validation for
	# the teachers who said the gods had already spoken
	_shift_coherence("Aelindran Orthodox", -0.30)
	_shift_coherence("The Vael Rationalist Faith", -0.30)
	_shift_coherence("The Silent Path", 0.15)
	_log("[b]THE TRUTH IS PUBLISHED.[/b] The Magistocracy caused the Silence — bought it, signed for it, profited by it. Its legitimacy does not survive the reading. The old noble houses are suddenly the only authority anyone remembers trusting.")


func _ending_revealed_gradual() -> void:
	## Ending Two, the archival road (Vigil doc §5): the truth arrives in
	## institutional form, over years — sourced, footnoted, unanswerable.
	## The Magistocracy is remade, not beheaded: half the fury of
	## _ending_revealed, all of its finality.
	central_secret_state = "revealed"
	realms[0].tyranny = minf(100.0, realms[0].tyranny + 12.0)
	realms[0].prestige = maxf(-100.0, realms[0].prestige - 25.0)
	realms[1].prestige = minf(100.0, realms[1].prestige + 8.0)
	for lord: SimCharacter in landed_vassals(0):
		if realms[0].ruler_id >= 0:
			add_memory(lord, "their crowns knew", realms[0].ruler_id, -20.0, 1.0)
	_shift_coherence("Aelindran Orthodox", -0.20)
	_shift_coherence("The Vael Rationalist Faith", -0.20)
	_shift_coherence("The Silent Path", 0.10)
	_log("[b]THE TRUTH IS PUBLISHED — in the Iron Library's measured hand.[/b] Released over two years, sourced past refutation, each paper narrower and more damning than the last. The Magistocracy caused the Silence; the record proves it; the record is a *record*, and Khessar's institutions have nowhere to stand but inside it. There are no mobs. There are resignations, recorded divisions, and a legitimacy that must now be re-earned line by line.")


func _ending_destroyed() -> void:
	central_secret_state = "destroyed"
	patron_network_broken = true
	var freed := 0
	for c in characters.values():
		if c.alive and c.traits.has("Patron-Bound"):
			_remove_trait(c, "Patron-Bound")
			freed += 1
	_log("[b]THE ANCHOR BURNS.[/b] Across the land, bargains fall silent mid-sentence — %d bound souls wake owing nothing. The marks already paid for remain. No new ones will ever be made." % freed)


func add_memory(c: SimCharacter, type: String, subject_id: int, value: float, decay_per_year: float = 4.0) -> void:
	if subject_id < 0 or subject_id == c.id:
		return
	c.memories.append({"type": type, "subject": subject_id, "value": value, "tick": tick, "decay": decay_per_year})
	if c.memories.size() > 30:
		c.memories.pop_front()


func opinion_of(a_id: int, b_id: int) -> int:
	## What a thinks of b: kinship baseline plus the decaying Memory Log.
	if a_id == b_id or not characters.has(a_id) or not characters.has(b_id):
		return 0
	var a: SimCharacter = characters[a_id]
	var b: SimCharacter = characters[b_id]
	var total := 0.0
	if a.spouse_id == b_id:
		total += 25.0
		# a cross-culture spouse is loved or resented by disposition
		# (Syncretist +25 / Purist -30, Cross-Cultural Marriage v1.0)
		if a.culture != b.culture:
			total += trait_add(a, "cross_culture_spouse_opinion")
	if a.father_id == b_id or a.mother_id == b_id or b.father_id == a_id or b.mother_id == a_id:
		total += 20.0
	elif a.dynasty_id == b.dynasty_id:
		total += 5.0
	# the wider dynasty tree: cadet branches still count each other as kin
	var ra := root_house_id(a.dynasty_id)
	var rb := root_house_id(b.dynasty_id)
	if ra == rb:
		if has_legacy(ra, "Unbending Oaths"):
			total += 15.0
		# a loyalist charter binds branch and trunk closer still
		if a.dynasty_id != b.dynasty_id \
				and (dynasties[a.dynasty_id].parent_id >= 0 or dynasties[b.dynasty_id].parent_id >= 0):
			total += 10.0
	elif in_blood_feud(ra, rb):
		total -= 40.0  # the feud is older than either of them, and it does not care
	# the Mythos file: what b's bloodline is known for colours every meeting
	if ra != rb and has_mythos(rb, "Kin-Eater"):
		total -= 10.0
	if a.realm_id != b.realm_id and has_mythos(rb, "Whispered Poisoners"):
		total -= 10.0
	if has_mythos(rb, "Blood of Kings"):
		total += 5.0
	# Administrative v1.0: a House that held the chair is nodded to by
	# the old-claim families — and eyed by the reformist wing
	if ra != rb and has_mythos(rb, "Former Grand Magister Family"):
		if has_mythos(ra, "Aelindran-Legitimate"):
			total += 5.0
		if str(magister_wing.get(a.id, "")) == "reformist":
			total -= 5.0
	# the marriage mythos (Cross-Cultural Marriage v1.0 §6)
	if ra != rb:
		if has_mythos(rb, "Compact-Bound"):
			if a.culture == "karn_vol" or a.culture == "drevak":
				total += 20.0
			elif a.culture == "aelindran":
				total -= 10.0
		if has_mythos(rb, "Half-Blooded Line"):
			if a.race.begins_with("half_"):
				total += 10.0
			elif a.traits.has("Purist"):
				total -= 5.0
		if has_mythos(rb, "Pure of Blood"):
			if a.traits.has("Purist"):
				total += 15.0
			elif a.race.begins_with("half_"):
				total -= 10.0
	# the Cross-Sworn resent the peace other Biculturals found
	if a.traits.has("Cross-Sworn") and b.traits.has("Bicultural"):
		total -= 15.0
	if b.denounced:
		total -= 30.0  # a branded house criminal is shunned by all
	total += trait_add(b, "court_opinion_baseline")  # the Altruistic are simply liked
	for m in a.memories:
		if int(m["subject"]) != b_id:
			continue
		var years := float(tick - int(m["tick"])) / 12.0
		var v := float(m["value"])
		var faded := absf(v) - float(m["decay"]) * years
		if faded <= 0.0:
			continue
		total += signf(v) * faded
	return clampi(int(total), -100, 100)


# ---------------------------------------------------------------- council

func council_member(realm_id: int, seat: String) -> SimCharacter:
	var realm: Realm = realms[realm_id]
	if not realm.council.has(seat):
		return null
	var c: SimCharacter = characters.get(realm.council[seat])
	if c == null or not c.alive or c.realm_id != realm_id:
		return null
	return c


func council_stat(realm_id: int, seat: String) -> int:
	var c := council_member(realm_id, seat)
	if c == null:
		return 0
	return int(c.get(SEAT_STAT[seat]))


func appoint(realm_id: int, seat: String, char_id: int) -> String:
	var realm: Realm = realms[realm_id]
	if char_id < 0:
		var sitting := int(realm.council.get(seat, -1))
		if sitting >= 0 and has_privilege(sitting, "guaranteed_seat"):
			return "Their contract guarantees a council seat — the crown signed it."
		realm.council.erase(seat)
		return ""
	if not characters.has(char_id):
		return "No such person."
	var c: SimCharacter = characters[char_id]
	if not c.alive or c.realm_id != realm_id:
		return "They cannot serve this realm."
	if c.age_years(tick) < ADULT_AGE:
		return "Too young to serve."
	if c.denounced:
		return "No realm seats a denounced criminal."
	if c.id == realm.ruler_id:
		return "The crown does not sit on its own council."
	var displaced := int(realm.council.get(seat, -1))
	if displaced >= 0 and displaced != char_id and has_privilege(displaced, "guaranteed_seat"):
		return "Their contract guarantees a council seat — the crown signed it."
	# one seat per person — moving them vacates the old seat
	for other_seat in COUNCIL_SEATS:
		if other_seat != seat and int(realm.council.get(other_seat, -1)) == char_id:
			realm.council.erase(other_seat)
	realm.council[seat] = char_id
	_log("%s is appointed %s of %s." % [full_name(c), seat, realm.name])
	return ""


func _council_tick() -> void:
	for realm: Realm in realms:
		for seat in COUNCIL_SEATS:
			if realm.council.has(seat) and council_member(realm.id, seat) == null:
				realm.council.erase(seat)
	_ai_fill_council(1)


func _ai_fill_council(realm_id: int) -> void:
	## Fills empty seats with the best person for the job. Runs for both
	## realms at setup, and monthly for the AI realm.
	var realm: Realm = realms[realm_id]
	# a Guaranteed Council Seat privilege is honored before merit (Module 4)
	for c in landed_vassals(realm_id):
		if not has_privilege(c.id, "guaranteed_seat"):
			continue
		var seated := false
		for seat in COUNCIL_SEATS:
			if int(realm.council.get(seat, -1)) == c.id:
				seated = true
		if seated:
			continue
		var best_seat := ""
		var best_v := -1
		for seat in COUNCIL_SEATS:
			if council_member(realm_id, seat) == null and int(c.get(SEAT_STAT[seat])) > best_v:
				best_v = int(c.get(SEAT_STAT[seat]))
				best_seat = seat
		if best_seat != "":
			realm.council[best_seat] = c.id
			if realm_id == 0:
				_log("%s takes the %s's chair — the contract says so." % [full_name(c), best_seat])
	for seat in COUNCIL_SEATS:
		if council_member(realm_id, seat) != null:
			continue
		var best: SimCharacter = null
		var best_v := -1
		for c in characters.values():
			if not (c.alive and c.realm_id == realm_id) or c.id == realm.ruler_id or c.denounced:
				continue
			if c.age_years(tick) < ADULT_AGE:
				continue
			var taken := false
			for s2 in COUNCIL_SEATS:
				if int(realm.council.get(s2, -1)) == c.id:
					taken = true
			if taken:
				continue
			var v := int(c.get(SEAT_STAT[seat]))
			if v > best_v:
				best_v = v
				best = c
		if best != null:
			realm.council[seat] = best.id


# ---------------------------------------------------------------- laws

func enact_law(realm_id: int, law: String, value: String) -> String:
	var realm: Realm = realms[realm_id]
	var speaker := council_member(realm_id, "Lawspeaker")
	if speaker == null:
		return "The realm needs a Lawspeaker to change its laws."
	if not realm.pending_law.is_empty():
		return "A law is already before the council."
	var current: String = realm.tax_law if law == "tax" else realm.succession_law
	if value == current:
		return "That is already the law of the land."
	# The Estate Curia (Module 4): raising taxes or rewriting the
	# succession needs the landed lords' assent in non-tribal realms.
	if realm.government != "tribal":
		var matter := ""
		if law == "tax" and value == "heavy":
			matter = "tax_heavy"
		elif law == "succession":
			matter = "succession"
		if matter != "":
			var vote := curia_vote(realm_id, matter)
			if not bool(vote["passed"]):
				return "The Curia votes it down — %s." % vote["detail"]
	var months := maxi(6, 18 - int(speaker.learning * 0.5))
	realm.pending_law = {"law": law, "value": value, "months_left": months}
	_log("%s puts a new law before the council of %s — %d months of debate." % [full_name(speaker), realm.name, months])
	return ""


func _laws_tick() -> void:
	for realm: Realm in realms:
		if realm.pending_law.is_empty():
			continue
		realm.pending_law["months_left"] = int(realm.pending_law["months_left"]) - 1
		if int(realm.pending_law["months_left"]) > 0:
			continue
		var law: String = realm.pending_law["law"]
		var value: String = realm.pending_law["value"]
		realm.pending_law = {}
		if law == "tax":
			realm.tax_law = value
			_log("[b]%s adopts %s taxation.[/b]" % [realm.name, value])
		else:
			realm.succession_law = value
			var label := "absolute" if value == "absolute" else "male-preference"
			_log("[b]%s adopts %s succession.[/b]" % [realm.name, label])


# ---------------------------------------------------------------- plots

func start_plot(realm_id: int, target_id: int) -> String:
	var realm: Realm = realms[realm_id]
	if council_member(realm_id, "Spymaster") == null:
		return "The realm needs a Spymaster to hatch plots."
	if realm.plot_progress >= 0.0:
		return "A plot is already in motion."
	if not characters.has(target_id):
		return "No such target."
	var t: SimCharacter = characters[target_id]
	if not t.alive or t.realm_id == realm_id:
		return "The target must be a living foreigner."
	if realm.gold < 100.0:
		return "Plots need gold — 100 to begin."
	realm.gold -= 100.0
	realm.plot_target_id = target_id
	realm.plot_progress = 0.0
	realm.plot_warned = false
	# ordering murder gnaws at gentler souls
	if realm.ruler_id >= 0:
		var r: SimCharacter = characters[realm.ruler_id]
		if r.traits.has("Honest"):
			add_stress(r, 30.0, "a plot against my conscience")
		if r.traits.has("Compassionate"):
			add_stress(r, 25.0, "blood on my hands")
	if realm_id == 0:
		_log("Your Spymaster begins weaving a plot against %s..." % full_name(t))
	return ""


func abandon_plot(realm_id: int) -> void:
	realms[realm_id].plot_progress = -1.0
	realms[realm_id].plot_target_id = -1
	realms[realm_id].plot_warned = false
	plot_details.erase(realm_id)


func _plots_tick() -> void:
	## The Anatomy of a Trap (Module 6): a murder is no longer one progress
	## bar. Phase 1 infiltrates the household, Phase 2 subverts an inside
	## asset (at 33), Phase 3 secures the vector (at 66), and Phase 4 is
	## the strike — at once, or held for an open window.
	for realm: Realm in realms:
		if realm.plot_progress < 0.0:
			continue
		var t: SimCharacter = characters.get(realm.plot_target_id)
		if t == null or not t.alive or t.realm_id == realm.id:
			abandon_plot(realm.id)
			continue
		if realm.gold < 5.0:
			abandon_plot(realm.id)
			if realm.id == 0:
				_log("The plot withers for want of gold.")
			continue
		realm.gold -= 5.0
		var details: Dictionary = plot_details.get(realm.id, {})
		# Phase 4: components secured — strike, or hold for the window
		if realm.plot_progress >= 100.0:
			if bool(details.get("waiting", false)):
				details["waited"] = int(details.get("waited", 0)) + 1
				plot_details[realm.id] = details
				if realms[t.realm_id].interregnum.is_empty() and int(details["waited"]) < 24:
					continue  # patience: the couriers watch for chaos
				if realm.id == 0:
					_log("The window opens. The order goes out.")
			_plot_strike(realm, t)
			continue
		var own := council_stat(realm.id, "Spymaster")
		var their := council_stat(t.realm_id, "Spymaster")
		var pace := maxf(1.0, 3.0 + own * 0.5 - their * 0.35)
		pace /= trait_mult(t, "intrigue_defense_mult")  # the Paranoid sleep behind locked doors
		if realm.ruler_id >= 0 and has_mythos(root_house_id(characters[realm.ruler_id].dynasty_id), "Whispered Poisoners"):
			pace *= 1.15  # practice makes perfect
		if realm.ruler_id >= 0 and has_mythos(root_house_id(characters[realm.ruler_id].dynasty_id), "Patron-Touched"):
			pace *= 1.20  # something helps the work along (Magic v1.0)
		var before := realm.plot_progress
		realm.plot_progress += pace
		# Phase 2: someone with a position near the target must be owned
		if before < 33.0 and realm.plot_progress >= 33.0:
			_plot_subvert_asset(realm, t)
		# Phase 3: what the lab — or the knife-seller — provides
		if before < 66.0 and realm.plot_progress >= 66.0:
			_plot_secure_vector(realm)
		# past the halfway mark, the victim's court may catch wind of it
		if not realm.plot_warned and realm.plot_progress >= 50.0:
			realm.plot_warned = true
			# Trade-Guard companies watch the roads and counting-houses:
			# +15 to the target realm's detection while any are mustered
			# (Roster v1.0 — a province-stationing refinement can follow
			# when garrisons exist; armies are the stations for now).
			var detect := (0.30 + (council_stat(t.realm_id, "Spymaster")
				+ _intrigue_detection_bonus(t.realm_id)) * 0.015) * trait_mult(t, "intrigue_defense_mult")
			if rng.randf() < detect:
				_raise_plot_warning(realm, t)
		if realm.plot_progress >= 100.0:
			realm.plot_progress = 100.0
			# the player picks the moment; everyone else strikes next tick
			if realm.id == 0 and not auto_resolve_events:
				_raise_strike_window(realm, t)
	# Sarova's spymaster is never idle for long — schemers doubly so
	var plot_chance := 0.01
	if realms[1].ruler_id >= 0:
		plot_chance = clampf(0.01 + ai_weight(characters[realms[1].ruler_id], "scheming") * 0.0004, 0.002, 0.04)
	if realms[1].plot_progress < 0.0 and council_member(1, "Spymaster") != null and rng.randf() < plot_chance:
		var target: SimCharacter = null
		# the Grand Magister's fate belongs to the Council's own politics
		# (Administrative v1.0) — Sarova's knives find the noble houses
		if rng.randf() < 0.6 and realms[0].ruler_id >= 0 \
				and not is_cast(characters[realms[0].ruler_id]):
			target = characters[realms[0].ruler_id]
		else:
			var pool: Array = []
			for c in characters.values():
				if c.alive and c.realm_id == 0 and c.age_years(tick) >= ADULT_AGE and not is_cast(c):
					pool.append(c)
			if not pool.is_empty():
				target = pool[rng.randi_range(0, pool.size() - 1)]
		if target != null and realms[1].gold >= 100.0:
			var _e := start_plot(1, target.id)


func _plot_subvert_asset(realm: Realm, t: SimCharacter) -> void:
	## Phase 2 (Module 6): the Asset. The sharpest mind with a position
	## near the target — bought with coin, or owned outright by a hook.
	var details: Dictionary = plot_details.get(realm.id, {})
	var asset: SimCharacter = null
	for c in characters.values():
		if c.alive and c.realm_id == t.realm_id and c.id != t.id \
				and c.id != realms[t.realm_id].ruler_id and c.age_years(tick) >= ADULT_AGE \
				and not is_cast(c):
			if asset == null or c.intrigue > asset.intrigue:
				asset = c
	if asset == null:
		return  # a lonely court — the plot leans on outsiders, and suffers for it
	var role: String = ASSET_ROLES[rng.randi_range(0, ASSET_ROLES.size() - 1)]
	if _spend_hook(realm.id, asset.id):
		details["asset_id"] = asset.id
		details["asset_role"] = role
		if realm.id == 0:
			_log("Your hook sinks deep: %s — the target's %s — is yours without a coin spent." % [full_name(asset), role])
	elif realm.gold >= ASSET_BRIBE:
		realm.gold -= ASSET_BRIBE
		details["asset_id"] = asset.id
		details["asset_role"] = role
		if realm.id == 0:
			_log("The target's %s takes the purse. There is a knife inside the walls now." % role)
	plot_details[realm.id] = details


func _plot_secure_vector(realm: Realm) -> void:
	## Phase 3 (Module 6): the Vector. Nightshade from the market — or
	## whatever the hidden lab has been asked to brew.
	var details: Dictionary = plot_details.get(realm.id, {})
	var v := "nightshade"
	if realm.apothecary and realm.alchemist_id >= 0:
		var alch: SimCharacter = characters.get(realm.alchemist_id)
		if alch != null and alch.alive and VECTOR_LABELS.has(realm.plot_vector_pref):
			v = realm.plot_vector_pref
	details["vector"] = v
	plot_details[realm.id] = details
	if realm.id == 0:
		_log("The vector is secured: %s." % VECTOR_LABELS[v])


func _raise_strike_window(realm: Realm, t: SimCharacter) -> void:
	## Phase 4 (Module 6): the trigger is the player's to pull.
	var details: Dictionary = plot_details.get(realm.id, {})
	if details.has("window_raised"):
		return
	details["window_raised"] = true
	details["waiting"] = true  # hold until the crown decides
	plot_details[realm.id] = details
	var realm_ref := realm
	var t_ref := t
	raise_event(realm.id, realm.ruler_id, "The Trap Is Set",
		"Every component is in place against %s: the routine mapped, the %s bought, the %s ready. Strike now — or wait for an open window, when their court is in chaos and the kitchens unguarded." % [
			full_name(t), str(details.get("asset_role", "asset")),
			VECTOR_LABELS[str(details.get("vector", "nightshade"))]],
		[
			{"label": "Strike now", "base": 4.0, "ai": {"aggression": 0.5},
				"effect": func() -> void:
					if realm_ref.plot_progress >= 0.0 and t_ref.alive:
						_plot_strike(realm_ref, t_ref)},
			{"label": "Wait for an open window (interregnum, or 24 months)", "base": 2.0, "ai": {"patience": 0.6},
				"effect": func() -> void:
					if realm_ref.id == 0:
						_log("The knife stays sheathed. The couriers watch for chaos.")},
		])


func _plot_strike(realm: Realm, t: SimCharacter) -> void:
	## Phase 4 lands. A turned asset serves the other master; otherwise the
	## components decide the odds, and the vector decides what "success" means.
	var details: Dictionary = plot_details.get(realm.id, {})
	if bool(details.get("double_agent", false)):
		_raise_switcheroo(realm, t)
		return
	var own := council_stat(realm.id, "Spymaster")
	var their := council_stat(t.realm_id, "Spymaster")
	var v := str(details.get("vector", "nightshade"))
	var succeed := clampf(0.30 + (own - their) * 0.02, 0.10, 0.75)
	if details.has("asset_id"):
		succeed += 0.10  # a knife already inside the walls
	if not realms[t.realm_id].interregnum.is_empty():
		succeed += 0.20  # chaos is a ladder — and an unguarded kitchen door
	if t.traits.has("Mithridatic"):
		succeed *= 0.2   # a thousand small deaths answer for the wine
	succeed = clampf(succeed, 0.05, 0.90)
	var victim_name := full_name(t)
	var plotter_ruler_id: int = realm.ruler_id
	if rng.randf() < succeed:
		match v:
			"slow_weep":
				# the perfect crime: no corpse, no whispers, no suspicion
				_add_trait(t, "Wasting")
				add_stress(t, 15.0, "a weakness the physicians cannot name")
				_log("[i]%s grows pale and tired. The physicians speak of consumption.[/i]" % victim_name)
			"mad_mind":
				_add_trait(t, "Paranoid")
				add_stress(t, 100.0, "voices where there are none")
				_log("[i]%s wakes screaming of faces in the walls. The court begins to look away.[/i]" % victim_name)
			_:
				# the family suspects a foreign hand, even without proof
				var kin_ids: Array = [t.spouse_id, t.father_id, t.mother_id]
				kin_ids.append_array(t.children_ids)
				if plotter_ruler_id >= 0:
					var proot := root_house_id(characters[plotter_ruler_id].dynasty_id)
					dynasties[proot].poisonings += 1
					if dynasties[proot].poisonings >= POISONINGS_THRESHOLD:
						_earn_mythos(proot, "Whispered Poisoners")
					_add_secret(plotter_ruler_id, "a murderer's hand")
				_kill(t, "died suddenly in the night")
				_log("[i]There are whispers of poison in %s...[/i]" % realms[t.realm_id].name)
				for kid in kin_ids:
					if kid >= 0 and characters.has(kid) and characters[kid].alive and plotter_ruler_id >= 0:
						add_memory(characters[kid], "suspects poison", plotter_ruler_id, -40.0, 1.5)
		if plotter_ruler_id >= 0:
			var pr: SimCharacter = characters[plotter_ruler_id]
			if pr.traits.has("Compassionate") or pr.traits.has("Honest"):
				add_stress(pr, 20.0, "the deed is done")
	else:
		realm.gold = maxf(0.0, realm.gold - 150.0)
		realm.prestige = maxf(-100.0, realm.prestige - 20.0)
		_log("[b]A plot against %s is uncovered![/b] Agents of %s hang in the square." % [victim_name, realm.name])
		if plotter_ruler_id >= 0:
			add_memory(t, "plotted my death", plotter_ruler_id, -60.0, 1.0)
			# caught red-handed: the proof itself becomes leverage
			_gain_hook(t.realm_id, plotter_ruler_id, "strong", "a murderer's hand")
			var t_ruler: int = realms[t.realm_id].ruler_id
			if t_ruler >= 0 and t_ruler != t.id:
				add_memory(characters[t_ruler], "plotted against my court", plotter_ruler_id, -30.0, 2.0)
	abandon_plot(realm.id)


func _raise_switcheroo(realm: Realm, t: SimCharacter) -> void:
	## The Subversion Matrix pays off: the plotter's own asset serves the
	## defender now, and the defender chooses how the trap closes.
	var details: Dictionary = plot_details.get(realm.id, {})
	var v := str(details.get("vector", "nightshade"))
	var role := str(details.get("asset_role", "agent"))
	var plotter_ruler: SimCharacter = characters.get(realm.ruler_id)
	var defender: Realm = realms[t.realm_id]
	abandon_plot(realm.id)  # the plot is spent either way; only the ending differs
	if plotter_ruler == null or not plotter_ruler.alive or defender.ruler_id < 0:
		return
	var realm_ref := realm
	var t_ref := t
	var pr_ref := plotter_ruler
	raise_event(defender.id, defender.ruler_id, "The Double Game Closes",
		"%s's plot against %s is ready to strike — but their %s has served your Spymaster for months. Choose the ending." % [
			realm.name, full_name(t), role],
		[
			{"label": "The Switcheroo — let them drink their own vintage", "base": 3.0, "ai": {"scheming": 0.8},
				"effect": func() -> void:
					if not pr_ref.alive:
						return
					match v:
						"slow_weep":
							_add_trait(pr_ref, "Wasting")
							_log("[b]The cup returns to the sender.[/b] %s grows pale within the month — the physicians speak of consumption." % full_name(pr_ref))
						"mad_mind":
							_add_trait(pr_ref, "Paranoid")
							add_stress(pr_ref, 100.0, "the walls have faces")
							_log("[b]The cup returns to the sender.[/b] %s wakes screaming — the brew was their own commission." % full_name(pr_ref))
						_:
							_kill(pr_ref, "died suddenly at their own feast")
							_log("[b]The cup returns to the sender.[/b] %s toasts %s's health — and drinks the vintage they paid for." % [
								full_name(pr_ref), full_name(t_ref)])
					realms[t_ref.realm_id].prestige = minf(100.0, realms[t_ref.realm_id].prestige + 10.0)},
			{"label": "Expose the plot before the world", "base": 3.0, "ai": {"patience": 0.4, "aggression": -0.2},
				"effect": func() -> void:
					realm_ref.prestige = maxf(-100.0, realm_ref.prestige - 30.0)
					_gain_hook(t_ref.realm_id, pr_ref.id, "strong", "a murderer's hand")
					if realms[t_ref.realm_id].ruler_id >= 0:
						add_memory(characters[realms[t_ref.realm_id].ruler_id], "sent knives after my kin", pr_ref.id, -40.0, 2.0)
					_log("[b]The plot is read aloud before both courts.[/b] %s stands naked before the world — and the proof stays locked in your archive." % realm_ref.name)},
		])


func _raise_plot_warning(plotter: Realm, victim: SimCharacter) -> void:
	## The Spymaster hears whispers: a foreign plot, half-woven. What the
	## target's ruler does about it is a matter of temperament.
	var target_realm: Realm = realms[victim.realm_id]
	if target_realm.ruler_id < 0:
		return
	var victim_name := full_name(victim)
	var plotter_ref := plotter
	var ruler_id: int = target_realm.ruler_id
	var options: Array = [
		{"label": "Triple the guard (50 gold)", "base": 8.0, "ai": {"patience": 0.4, "greed": -0.3},
			"effect": func() -> void:
				realms[victim.realm_id].gold -= 50.0
				abandon_plot(plotter_ref.id)
				_log("The guard is tripled around %s — the plotters melt away, their coin wasted." % victim_name)},
		{"label": "Bait a trap for the agents", "base": 0.0, "ai": {"scheming": 0.5, "aggression": 0.2},
			"effect": func() -> void:
				var own_int := council_stat(victim.realm_id, "Spymaster")
				var their_int := council_stat(plotter_ref.id, "Spymaster")
				if rng.randf() < clampf(0.45 + (own_int - their_int) * 0.02, 0.15, 0.85):
					plotter_ref.gold = maxf(0.0, plotter_ref.gold - 150.0)
					abandon_plot(plotter_ref.id)
					if plotter_ref.ruler_id >= 0 and characters.has(ruler_id):
						add_memory(characters[ruler_id], "sent knives after my kin", plotter_ref.ruler_id, -40.0, 1.5)
					_log("[b]The trap springs![/b] Foreign agents hang in the square, and %s's plot dies with them." % realms[plotter_ref.id].name)
				else:
					_log("The trap catches nothing — the whispers fall silent, but the danger remains.")},
		{"label": "Dismiss the whispers", "base": 4.0, "ai": {"patience": -0.2, "scheming": -0.3},
			"effect": func() -> void:
				_log("The whispers are dismissed as courtly noise. Perhaps they are.")},
	]
	# Counter-Intrigue Subversion (Module 6): if their inside agent is
	# already placed, he can be bought twice — and the plot walks on, ours.
	var p_details: Dictionary = plot_details.get(plotter.id, {})
	if p_details.has("asset_id"):
		var role := str(p_details.get("asset_role", "agent"))
		options.append({"label": "Turn their %s — play the double game" % role,
			"base": 2.0, "ai": {"scheming": 0.8},
			"effect": func() -> void:
				var own_i := council_stat(victim.realm_id, "Spymaster")
				var their_i := council_stat(plotter_ref.id, "Spymaster")
				if rng.randf() < clampf(0.40 + (own_i - their_i) * 0.02, 0.15, 0.80):
					var d2: Dictionary = plot_details.get(plotter_ref.id, {})
					d2["double_agent"] = true
					plot_details[plotter_ref.id] = d2
					_log("[b]The %s is turned.[/b] The plot walks on — wearing your colors under theirs." % role)
				else:
					_log("The approach is rebuffed — the %s stays bought. The plot walks on." % role)})
	raise_event(victim.realm_id, target_realm.ruler_id, "Whispers of a Plot",
		"Your Spymaster brings grave word: a foreign hand weaves a plot against %s. The web is half-spun — there is still time to act." % victim_name,
		options)


# ---------------------------------------------------------------- secrets & hooks (Module 6)

func _add_secret(subject_id: int, type: String) -> void:
	## The world accumulates leverage: every sin leaves a record somewhere.
	for s in secrets:
		if int(s["subject"]) == subject_id and str(s["type"]) == type:
			return
	secrets.append({"subject": subject_id, "type": type, "known": {}})


func _gain_hook(realm_id: int, target_id: int, strength: String, source: String) -> void:
	for h in hooks:
		if int(h["realm"]) == realm_id and int(h["target"]) == target_id and not bool(h["spent"]):
			if strength == "strong" and str(h["strength"]) == "weak":
				h["strength"] = strength
				h["source"] = source
			return
	hooks.append({"realm": realm_id, "target": target_id, "strength": strength,
		"source": source, "spent": false})
	var t: SimCharacter = characters.get(target_id)
	if t != null and realm_id == 0:
		_log("[b]A hook sinks into %s[/b] — %s. Leverage, whenever the crown wants it." % [
			full_name(t), SECRET_LABELS.get(source, source)])


func has_hook(realm_id: int, target_id: int) -> bool:
	for h in hooks:
		if int(h["realm"]) == realm_id and int(h["target"]) == target_id and not bool(h["spent"]):
			return true
	return false


func hooks_of(realm_id: int) -> Array:
	var out: Array = []
	for h in hooks:
		if int(h["realm"]) == realm_id and not bool(h["spent"]):
			var t: SimCharacter = characters.get(int(h["target"]))
			if t != null and t.alive:
				out.append(h)
	return out


func _spend_hook(realm_id: int, target_id: int) -> bool:
	## Weak hooks buy one favor; a strong hook is a lifetime of leverage.
	for h in hooks:
		if int(h["realm"]) == realm_id and int(h["target"]) == target_id and not bool(h["spent"]):
			if str(h["strength"]) == "weak":
				h["spent"] = true
			return true
	return false


func hook_force_contract(realm_id: int, lord_id: int, part: String, rate: String) -> String:
	## The doc's programmatic leverage: blackmail mandates contract changes
	## with no tyranny gained and no grudge taken.
	if not characters.has(lord_id) or not vassal_contracts.has(lord_id):
		return "No such vassal."
	if not has_hook(realm_id, lord_id):
		return "The crown holds no hook on them."
	if not (part == "tax" or part == "levy") or not CONTRACT_RATES.has(rate):
		return "No such term."
	contract_of(lord_id)[part] = rate
	var _s := _spend_hook(realm_id, lord_id)
	_log("%s signs the new terms without a word — what the crown knows sits across the table." % full_name(characters[lord_id]))
	return ""


func start_ferreting(realm_id: int) -> String:
	## The Spymaster's task: dig for secrets — in every hall, including our own.
	if ferreting.has(realm_id):
		return "The Spymaster is already digging."
	if council_member(realm_id, "Spymaster") == null:
		return "Ferreting out secrets needs a Spymaster."
	var realm: Realm = realms[realm_id]
	if realm.gold < FERRET_COST:
		return "Informants cost %d gold." % int(FERRET_COST)
	realm.gold -= FERRET_COST
	ferreting[realm_id] = 0
	if realm_id == 0:
		_log("The Spymaster's informants spread through halls and taverns, listening.")
	return ""


func _ferret_tick() -> void:
	if ferreting.is_empty():
		return
	for rid in ferreting.keys():
		ferreting[rid] = int(ferreting[rid]) + 1
		var chance := 0.10 + council_stat(int(rid), "Spymaster") * 0.012
		if rng.randf() < chance:
			var unknown: Array = []
			for s in secrets:
				if s["known"].has(rid):
					continue
				# the central secret is beyond tavern informants (Magic v1.0):
				# it waits for the Architect's chamber or the family archives
				if str(s["type"]) == "silence_cause_complicity":
					continue
				# the canon-pass house secrets are buried deeper than taverns
				# (Pass Two §3): they surface through their own modules' beats
				if bool(s.get("under", false)):
					continue
				var subj: SimCharacter = characters.get(int(s["subject"]))
				if subj != null and subj.alive and subj.id != realms[int(rid)].ruler_id:
					unknown.append(s)
			if unknown.is_empty():
				continue  # keep listening — the well may yet fill
			var s2: Dictionary = unknown[rng.randi_range(0, unknown.size() - 1)]
			s2["known"][rid] = true
			var strength := "weak"
			if str(s2["type"]) != "bastard blood":
				strength = "strong"
			_gain_hook(int(rid), int(s2["subject"]), strength, str(s2["type"]))
			# a bargain dragged into daylight marks the whole blood (Magic v1.0)
			if str(s2["type"]) == "patron_bargain_signed":
				var subj2: SimCharacter = characters.get(int(s2["subject"]))
				if subj2 != null:
					_earn_mythos(root_house_id(subj2.dynasty_id), "Patron-Touched")
			ferreting.erase(rid)
		elif int(ferreting[rid]) >= FERRET_GIVE_UP_MONTHS:
			ferreting.erase(rid)
			if int(rid) == 0:
				_log("The informants come back with tavern songs and nothing else. The purse is spent.")


# ---------------------------------------------------------------- minor schemes (Module 6)

func start_minor_scheme(realm_id: int, kind: String, target_id: int) -> String:
	if not MINOR_SCHEME_LABELS.has(kind):
		return "No such scheme."
	for s in minor_schemes:
		if int(s["realm"]) == realm_id:
			return "The web can hold one such scheme at a time."
	if council_member(realm_id, "Spymaster") == null:
		return "Schemes need a Spymaster."
	if not characters.has(target_id):
		return "No such target."
	var t: SimCharacter = characters[target_id]
	if not t.alive:
		return "%s is dead." % t.name
	if t.realm_id == realm_id:
		return "The target must live at a foreign court."
	if kind == "seduce":
		if t.age_years(tick) < ADULT_AGE:
			return "Seduction waits on adulthood."
		var r: SimCharacter = characters.get(realms[realm_id].ruler_id)
		if r == null:
			return "No ruler to do the seducing."
		if _close_kin(r, t):
			return "Too close in blood."
	if kind.begins_with("slander") and t.age_years(tick) < ADULT_AGE:
		return "Slander wants a reputation to ruin — children have none."
	var realm: Realm = realms[realm_id]
	if realm.gold < MINOR_SCHEME_COST:
		return "Schemes need %d gold." % int(MINOR_SCHEME_COST)
	realm.gold -= MINOR_SCHEME_COST
	minor_schemes.append({"realm": realm_id, "kind": kind, "target": target_id,
		"progress": 0.0, "checked": false})
	if realm_id == 0:
		_log("A quiet scheme begins: %s, against %s." % [MINOR_SCHEME_LABELS[kind], full_name(t)])
	return ""


func _minor_schemes_tick() -> void:
	for s in minor_schemes.duplicate():
		var rid := int(s["realm"])
		var t: SimCharacter = characters.get(int(s["target"]))
		if t == null or not t.alive or t.realm_id == rid:
			minor_schemes.erase(s)
			continue
		var own := council_stat(rid, "Spymaster")
		var their := council_stat(t.realm_id, "Spymaster")
		s["progress"] = float(s["progress"]) + maxf(1.0, 4.0 + own * 0.4 - their * 0.25)
		# a half-woven web can be found
		if not bool(s["checked"]) and float(s["progress"]) >= 50.0:
			s["checked"] = true
			var detect := (0.20 + (their + _intrigue_detection_bonus(t.realm_id)) * 0.012) \
				* trait_mult(t, "intrigue_defense_mult")
			if rng.randf() < detect:
				minor_schemes.erase(s)
				realms[rid].prestige = maxf(-100.0, realms[rid].prestige - 20.0)
				var t_ruler: int = realms[t.realm_id].ruler_id
				if t_ruler >= 0 and realms[rid].ruler_id >= 0:
					add_memory(characters[t_ruler], "plotted against my court", realms[rid].ruler_id, -30.0, 2.0)
				_log("[b]A scheme is dragged into daylight![/b] %s's agents are caught weaving %s against %s." % [
					realms[rid].name, MINOR_SCHEME_LABELS[str(s["kind"])], full_name(t)])
				continue
		if float(s["progress"]) >= 100.0:
			minor_schemes.erase(s)
			_resolve_minor_scheme(s, t)
	# Sarova's court weaves its own smaller webs — a slandered heir is
	# cheaper than a war, and safer than poison
	var s_ruler_id: int = realms[1].ruler_id
	if s_ruler_id < 0 or council_member(1, "Spymaster") == null or realms[1].gold < MINOR_SCHEME_COST:
		return
	for s in minor_schemes:
		if int(s["realm"]) == 1:
			return
	var chance := clampf(0.003 + ai_weight(characters[s_ruler_id], "scheming") * 0.0002, 0.001, 0.02)
	if rng.randf() < chance:
		var heir := heir_of(0)
		if heir != null and not heir.slandered and heir.age_years(tick) >= ADULT_AGE:
			var _e := start_minor_scheme(1, "slander_lineage", heir.id)


func _resolve_minor_scheme(s: Dictionary, t: SimCharacter) -> void:
	var rid := int(s["realm"])
	var realm: Realm = realms[rid]
	match str(s["kind"]):
		"seduce":
			var r: SimCharacter = characters.get(realm.ruler_id)
			if r == null or not r.alive:
				return
			add_memory(t, "a secret love", r.id, 40.0, 1.0)
			add_memory(r, "a conquest abroad", t.id, 15.0, 1.0)
			_add_secret(t.id, "a secret affair")
			for sec in secrets:
				if int(sec["subject"]) == t.id and str(sec["type"]) == "a secret affair":
					sec["known"][rid] = true
			_gain_hook(rid, t.id, "strong", "a secret affair")
			_log("[i]Letters begin to cross the border in unmarked hands.[/i]")
		"abduct":
			var old_home := t.realm_id
			wards[t.id] = {"home": old_home, "host": rid, "guardian": realm.ruler_id,
				"hostage": true, "since": tick, "of_age": t.age_years(tick) >= ADULT_AGE}
			t.realm_id = rid
			var h_ruler: int = realms[old_home].ruler_id
			if h_ruler >= 0 and realm.ruler_id >= 0:
				add_memory(characters[h_ruler], "stole my blood from my hall", realm.ruler_id, -50.0, 2.0)
			_log("[b]%s vanishes from %s[/b] — and reappears, under guard, at the court of %s." % [
				full_name(t), realms[old_home].name, realm.name])
		"slander_lineage":
			t.slandered = true
			for lord: SimCharacter in landed_vassals(t.realm_id):
				add_memory(lord, "whispers of bastardy", t.id, -15.0, 2.0)
			_log("[b]Forged pages surface in a monastery archive:[/b] they name %s bastard-born. True or not, the ink is aged and the seals are good." % full_name(t))
		"slander_vice":
			_raise_vice_trial(rid, t)


func _raise_vice_trial(slanderer_rid: int, t: SimCharacter) -> void:
	## The Manufactured Vice: planted evidence forces a public trial in the
	## target's own court — and the crown must judge one of its own.
	var court: Realm = realms[t.realm_id]
	if court.ruler_id < 0:
		return
	var t_ref := t
	var s_realm: Realm = realms[slanderer_rid]
	raise_event(court.id, court.ruler_id, "A Trial of Vice",
		"Evidence surfaces that %s keeps forbidden practices — witnesses paid, letters planted, all of it damning and none of it checkable. The court demands a trial." % full_name(t),
		[
			{"label": "Condemn them — the evidence is damning", "base": 3.0, "ai": {"patience": 0.3, "scheming": 0.2},
				"effect": func() -> void:
					t_ref.slandered = true
					for seat in COUNCIL_SEATS:
						if int(realms[t_ref.realm_id].council.get(seat, -1)) == t_ref.id:
							realms[t_ref.realm_id].council.erase(seat)
					if realms[t_ref.realm_id].ruler_id >= 0:
						add_memory(t_ref, "condemned on forged evidence", realms[t_ref.realm_id].ruler_id, -60.0, 1.0)
					for lord: SimCharacter in landed_vassals(t_ref.realm_id):
						add_memory(lord, "convicted of secret vice", t_ref.id, -10.0, 2.0)
					_log("[b]%s is condemned[/b] — stripped of office and standing. The evidence is never questioned again." % full_name(t_ref))},
			{"label": "Stand by them — burn the forgeries (50 gold)", "base": 2.0, "ai": {"greed": -0.4, "aggression": 0.2},
				"effect": func() -> void:
					court.gold = maxf(0.0, court.gold - 50.0)
					if rng.randf() < 0.5:
						s_realm.prestige = maxf(-100.0, s_realm.prestige - 20.0)
						if court.ruler_id >= 0 and s_realm.ruler_id >= 0:
							add_memory(characters[court.ruler_id], "forged sins against my kin", s_realm.ruler_id, -40.0, 2.0)
						_log("[b]The forgeries burn — and the forgers are named.[/b] %s stands shamed before both courts." % s_realm.name)
					else:
						_log("The evidence is burned and the matter closed. Where it came from, no one can prove.")},
		])


# ---------------------------------------------------------------- the apothecary (Module 6)

func establish_apothecary(realm_id: int) -> String:
	## A hidden room beneath the estate, and an unlanded courtier with the
	## learning to tend it — officially, a physician.
	var realm: Realm = realms[realm_id]
	if realm.apothecary:
		return "The hidden lab already bubbles beneath the estate."
	if realm.gold < APOTHECARY_COST:
		return "Masons who can keep secrets cost %d gold." % int(APOTHECARY_COST)
	var alch: SimCharacter = null
	for c in characters.values():
		if c.alive and c.realm_id == realm_id and c.age_years(tick) >= ADULT_AGE \
				and c.id != realm.ruler_id and counties_of(c.id).is_empty() \
				and c.learning >= 10 and not _on_council(realm_id, c.id) and not is_cast(c):
			if alch == null or c.learning > alch.learning:
				alch = c
	if alch == null:
		return "No unlanded courtier has the learning for the stills (10+)."
	realm.gold -= APOTHECARY_COST
	realm.apothecary = true
	realm.alchemist_id = alch.id
	_log("[b]A hidden room takes shape beneath the estate.[/b] %s tends the stills — officially, a physician." % full_name(alch))
	return ""


func _on_council(realm_id: int, char_id: int) -> bool:
	for seat in COUNCIL_SEATS:
		if int(realms[realm_id].council.get(seat, -1)) == char_id:
			return true
	return false


func set_plot_vector(realm_id: int, v: String) -> String:
	if not VECTOR_LABELS.has(v):
		return "The lab knows no such brew."
	if v != "nightshade" and not realms[realm_id].apothecary:
		return "Custom toxins need an Apothecary Lab."
	realms[realm_id].plot_vector_pref = v
	return ""


func toggle_mithridatism(realm_id: int) -> String:
	## The defensive discipline: a drop of poison with every dawn meal,
	## for two years — and then no cup can kill you.
	var realm: Realm = realms[realm_id]
	if realm.ruler_id < 0:
		return "No ruler to guard."
	var r: SimCharacter = characters[realm.ruler_id]
	if r.traits.has("Mithridatic"):
		return "The work is done — no cup can kill them now."
	if mithridatism.has(r.id):
		mithridatism.erase(r.id)
		_log("%s abandons the bitter morning draughts." % full_name(r))
		return ""
	if not realm.apothecary:
		return "Micro-dosing needs an Apothecary Lab."
	mithridatism[r.id] = 0
	_log("%s begins the old discipline: a drop of poison with every dawn meal." % full_name(r))
	return ""


func _mithridatism_tick() -> void:
	if mithridatism.is_empty():
		return
	for cid in mithridatism.keys():
		var c: SimCharacter = characters.get(int(cid))
		if c == null or not c.alive:
			mithridatism.erase(cid)
			continue
		var realm: Realm = realms[c.realm_id]
		if realm.gold < 2.0:
			continue  # the draught waits for coin
		realm.gold -= 2.0
		mithridatism[cid] = int(mithridatism[cid]) + 1
		if int(mithridatism[cid]) >= MITHRIDATIC_MONTHS:
			mithridatism.erase(cid)
			_add_trait(c, "Mithridatic")
			_log("[b]%s has drunk a thousand small deaths[/b] — and no cup can kill them now." % full_name(c))


func _intrigue_tick() -> void:
	## Module 6's slow machinery between the plots: informants digging,
	## minor schemes weaving, the lab's patient disciplines. Every
	## subsystem returns before touching the dice when it has no work.
	_ferret_tick()
	_minor_schemes_tick()
	_mithridatism_tick()


func _auto_marriages() -> void:
	## Characters left unmarried past 25 find their own match within their
	## realm — the player brokers the strategic marriages while they're young.
	var bachelors: Array = []
	for c in characters.values():
		if c.alive and not c.is_female and c.spouse_id < 0 and c.age_years(tick) >= 22 and not is_cast(c):
			bachelors.append(c)
	for m: SimCharacter in bachelors:
		if m.spouse_id >= 0 or rng.randf() > 0.06:
			continue
		if m.id == architect_id:
			continue  # the die is drawn; the Reclusive old man does not remarry (Vigil canon — "He did not marry again")
		for f in characters.values():
			if not (f.alive and f.is_female and f.spouse_id < 0):
				continue
			if f.age_years(tick) < ADULT_AGE or f.realm_id != m.realm_id or _close_kin(m, f):
				continue
			if is_cast(f):
				continue  # the cast courts do not answer marriage brokers (Faction Cast v1.0)
			var _err := marry(m.id, f.id)
			break


func _close_kin(a: SimCharacter, b: SimCharacter) -> bool:
	if a.father_id >= 0 and a.father_id == b.father_id:
		return true
	if a.mother_id >= 0 and a.mother_id == b.mother_id:
		return true
	if a.id == b.father_id or a.id == b.mother_id:
		return true
	if b.id == a.father_id or b.id == a.mother_id:
		return true
	return false


func allied() -> bool:
	for pair in marriage_alliances:
		var a: SimCharacter = characters[pair[0]]
		var b: SimCharacter = characters[pair[1]]
		if a.alive and b.alive and a.spouse_id == b.id:
			return true
	return false


func eligible_singles(female: bool) -> Array:
	var out: Array = []
	for c in characters.values():
		# the cast courts do not answer marriage brokers yet (Faction Cast v1.0)
		if c.alive and c.is_female == female and c.spouse_id < 0 \
				and c.age_years(tick) >= ADULT_AGE and not is_cast(c):
			out.append(c)
	out.sort_custom(func(a: SimCharacter, b: SimCharacter) -> bool: return a.birth_tick < b.birth_tick)
	return out


# ---------------------------------------------------------------- the event framework
# A choice event is pure data: {id, realm_id, decider, title, text, options}.
# Each option: {label, effect: Callable, ai: {axis: weight}, base: float}.
# Player-realm events queue for a popup; everyone else's are decided on
# the spot by the decider's personality — the same trait AI weights
# (aggression / scheming / greed / patience) score every option.

func raise_event(realm_id: int, decider_id: int, title: String, text: String, options: Array, magic: bool = false, admin: bool = false, faith: bool = false, vigil: bool = false, silence: bool = false, famine: bool = false, wren: bool = false, entity: bool = false, under: bool = false) -> void:
	if options.is_empty():
		return
	# magic-born events resolve on the magic RNG (Magic v1.0), Council
	# events on the Council's (Administrative v1.0), faith events on the
	# theology's (Module 9), vigil events on the Architect's (Vigil v1.0),
	# Ashfields/Forsaken events on the Silence-made stream (v1.1), and
	# the Canon Pass modules on grng/wrng/erng/urng (Pass One/Two) —
	# the main history stream never feels any system's bookkeeping
	var ev := {"id": next_event_id, "realm_id": realm_id, "decider": decider_id,
		"title": title, "text": text, "options": options, "magic": magic, "admin": admin,
		"faith": faith, "vigil": vigil, "silence": silence,
		"famine": famine, "wren": wren, "entity": entity, "under": under}
	next_event_id += 1
	if realm_id != 0 or auto_resolve_events:
		_ai_resolve_event(ev)
	else:
		pending_events.append(ev)
		event_raised.emit()


func _ai_resolve_event(ev: Dictionary) -> void:
	## Personality picks: each option's axis weights are dotted with the
	## decider's trait weights, plus a little human unpredictability.
	var decider: SimCharacter = characters.get(int(ev["decider"]))
	var jitter_rng: RandomNumberGenerator = rng
	if bool(ev.get("silence", false)):
		jitter_rng = srng
	elif bool(ev.get("vigil", false)):
		jitter_rng = vrng
	elif bool(ev.get("admin", false)):
		jitter_rng = arng
	elif bool(ev.get("faith", false)):
		jitter_rng = frng
	elif bool(ev.get("magic", false)):
		jitter_rng = mrng
	elif bool(ev.get("famine", false)):
		jitter_rng = grng
	elif bool(ev.get("wren", false)):
		jitter_rng = wrng
	elif bool(ev.get("entity", false)):
		jitter_rng = erng
	elif bool(ev.get("under", false)):
		jitter_rng = urng
	var best := 0
	var best_score := -INF
	for i in ev["options"].size():
		var opt: Dictionary = ev["options"][i]
		var score: float = float(opt.get("base", 0.0)) + jitter_rng.randf() * 12.0
		if decider != null:
			for axis in opt.get("ai", {}):
				score += ai_weight(decider, axis) * float(opt["ai"][axis])
		if score > best_score:
			best_score = score
			best = i
	events_resolved_by_ai += 1
	_apply_event_option(ev, best)


func resolve_event(event_id: int, option_index: int) -> void:
	## The player's path: the UI calls this from the popup.
	for i in pending_events.size():
		if int(pending_events[i]["id"]) == event_id:
			var ev: Dictionary = pending_events[i]
			pending_events.remove_at(i)
			_apply_event_option(ev, option_index)
			return


func _apply_event_option(ev: Dictionary, idx: int) -> void:
	var opt: Dictionary = ev["options"][clampi(idx, 0, ev["options"].size() - 1)]
	if opt.has("effect"):
		(opt["effect"] as Callable).call()


# ---------------------------------------------------------------- titles & land (Module 3)

func county_holder(province_id: int) -> SimCharacter:
	if not county_holders.has(province_id):
		return null
	var c: SimCharacter = characters.get(int(county_holders[province_id]))
	var p = map.provinces[province_id]
	if c == null or not c.alive or c.realm_id != p.owner:
		return null
	return c


func duchy_holder(duchy_id: int) -> SimCharacter:
	if not duchy_holders.has(duchy_id):
		return null
	var c: SimCharacter = characters.get(int(duchy_holders[duchy_id]))
	var d = map.duchies[duchy_id]
	if c == null or not c.alive or c.realm_id != d.realm:
		return null
	return c


func realm_tax_eff(realm_id: int) -> float:
	## What the land really yields: granted counties gain their lord's
	## stewardship; conquered land yields little until de jure drift
	## claims it; crown counties beyond the ruler's reach are run badly.
	var realm: Realm = realms[realm_id]
	var admin_cap := CROWN_ADMIN_BASE
	if realm.ruler_id >= 0:
		admin_cap += int(characters[realm.ruler_id].stewardship / 5.0)
		admin_cap += int(trait_add(characters[realm.ruler_id], "admin_cap_bonus"))  # Bureaucrats delegate on paper
		if has_legacy(root_house_id(characters[realm.ruler_id].dynasty_id), "The Vael Compact"):
			admin_cap += 1  # the line thinks in ledgers and proofs (Magic v1.0)
	var total := 0.0
	var crown_taxes: Array = []
	for p in map.provinces:
		if p.owner != realm_id:
			continue
		if int(occupied.get(p.id, -1)) >= 0 and int(occupied.get(p.id, -1)) != realm_id:
			continue  # a county under occupation pays its crown nothing (Module 7)
		var t: float = p.tax
		if p.de_jure != realm_id:
			t *= FOREIGN_LAND_YIELD  # the people remember other banners
		if int(salted.get(p.id, -1)) > tick:
			t *= SALT_YIELD  # salted earth (Module 5): a generation of ash
		if int(scorched.get(p.id, -1)) > tick:
			t *= SCORCH_YIELD  # the fields you burned yourself (Module 7)
		var lord := county_holder(p.id)
		if lord != null:
			# the feudal contract sets what the crown actually collects
			t *= float(CONTRACT_RATES[contract_of(lord.id)["tax"]]["tax"])
			if has_privilege(lord.id, "coinage_rights"):
				t *= 0.6  # their coin, their cut
			total += t * (1.0 + lord.stewardship * 0.02)
		else:
			crown_taxes.append(t)
	# the crown administers its best counties well, the rest poorly
	crown_taxes.sort()
	crown_taxes.reverse()
	for i in crown_taxes.size():
		total += crown_taxes[i] * (1.0 if i < admin_cap else OVERREACH_YIELD)
	return total


func realm_levy_eff(realm_id: int) -> float:
	var total := 0.0
	for p in map.provinces:
		if p.owner != realm_id:
			continue
		if int(occupied.get(p.id, -1)) >= 0 and int(occupied.get(p.id, -1)) != realm_id:
			continue  # no muster answers from behind an occupier's pickets (Module 7)
		var l := float(p.levy)
		if p.de_jure != realm_id:
			l *= FOREIGN_LAND_YIELD
		if int(salted.get(p.id, -1)) > tick:
			l *= SALT_YIELD  # salted earth raises no spears
		if int(scorched.get(p.id, -1)) > tick:
			l *= SCORCH_YIELD  # the partisans fight, but they are not levies (Module 7)
		var lord := county_holder(p.id)
		if lord != null:
			l += lord.martial * 0.5  # a lord drills his own men
			if has_privilege(lord.id, "marcher_lord"):
				l = 0.0  # marchers keep their men on their own walls
			else:
				l *= float(CONTRACT_RATES[contract_of(lord.id)["levy"]]["levy"])
				if at_war and has_privilege(lord.id, "war_sanction"):
					l *= 0.5  # sanctioned lords owe only half to the crown's wars
		total += l
	for d in map.duchies:
		var duke := duchy_holder(d.id)
		if duke == null or d.realm != realm_id:
			continue
		var owned := 0
		for pid in d.county_ids:
			if map.provinces[pid].owner == realm_id:
				owned += 1
		total += duke.martial * 1.5 * owned  # the duke marshals his whole region
	return total


func grant_title(kind: String, title_id: int, char_id: int) -> String:
	## The crown parcels out the land: counties and duchies to living
	## adults of the realm. Pass char_id -1 to revoke — lords remember that.
	var realm_id := -1
	if kind == "county":
		if title_id < 0 or title_id >= map.provinces.size():
			return "No such county."
		realm_id = map.provinces[title_id].owner
	elif kind == "duchy":
		if title_id < 0 or title_id >= map.duchies.size():
			return "No such duchy."
		realm_id = map.duchies[title_id].realm
	else:
		return "No such title."
	var realm: Realm = realms[realm_id]
	var title_name: String = map.provinces[title_id].name if kind == "county" else map.duchies[title_id].name
	if char_id < 0:
		return _revoke_title(kind, title_id, title_name, realm)
	if realm.government == "tribal" and kind == "duchy":
		return "Tribal rule knows no dukes — power is personal, not legal."
	if not characters.has(char_id):
		return "No such person."
	var c: SimCharacter = characters[char_id]
	if not c.alive or c.realm_id != realm_id:
		return "They cannot hold land of this realm."
	if c.age_years(tick) < ADULT_AGE:
		return "Too young to hold a title."
	if c.denounced:
		return "No land for a denounced criminal."
	if c.id == realm.ruler_id:
		return "The crown already holds what it has not granted."
	var holders: Dictionary = county_holders if kind == "county" else duchy_holders
	if int(holders.get(title_id, -1)) == char_id:
		return ""
	holders[title_id] = char_id
	var _contract := contract_of(char_id)  # a grant opens the feudal contract (Module 4)
	if realm.ruler_id >= 0:
		add_memory(c, "granted me land", realm.ruler_id, 40.0, 0.5)
	_log("[b]%s is granted %s%s.[/b]" % [full_name(c),
		"the county of " if kind == "county" else "", title_name])
	return ""


func _revoke_title(kind: String, title_id: int, title_name: String, realm: Realm) -> String:
	var holders: Dictionary = county_holders if kind == "county" else duchy_holders
	if not holders.has(title_id):
		return "The crown holds it already."
	var old_id := int(holders[title_id])
	if has_privilege(old_id, "judicial_immunity"):
		return "Their contract grants Judicial Immunity — the law cannot touch them."
	holders.erase(title_id)
	realm.tyranny = minf(100.0, realm.tyranny + 15.0)  # every lord watches a revocation
	if characters.has(old_id) and characters[old_id].alive:
		var old: SimCharacter = characters[old_id]
		if realm.ruler_id >= 0:
			add_memory(old, "stripped my land", realm.ruler_id, -50.0, 1.0)
		_log("[b]%s is stripped of %s[/b] — and will not forget it. Neither will the others." % [full_name(old), title_name])
	return ""


func titles_of(char_id: int) -> Array:
	## Human-readable list of everything a character holds.
	var out: Array = []
	for did in duchy_holders:
		if int(duchy_holders[did]) == char_id and duchy_holder(did) != null:
			out.append(map.duchies[did].name)
	for pid in county_holders:
		if int(county_holders[pid]) == char_id and county_holder(pid) != null:
			out.append(map.provinces[pid].name)
	return out


func _escheat_titles(c: SimCharacter) -> void:
	## Pass 1 rule: titles die with the holder and revert to the crown.
	## (Hereditary lordships arrive with Module 4's vassal contracts.)
	var reverted: Array = []
	for pid in county_holders.keys():
		if int(county_holders[pid]) == c.id:
			reverted.append(map.provinces[pid].name)
			county_holders.erase(pid)
	for did in duchy_holders.keys():
		if int(duchy_holders[did]) == c.id:
			reverted.append(map.duchies[did].name)
			duchy_holders.erase(did)
	if not reverted.is_empty():
		_log("%s reverts to the crown." % " and ".join(reverted))


func _dejure_tick() -> void:
	## De Jure Drift: hold conquered land long enough and the old banners
	## fade from memory — the land becomes rightfully yours.
	for p in map.provinces:
		if p.owner == p.de_jure:
			continue
		if tick - p.held_since >= DEJURE_DRIFT_MONTHS:
			p.de_jure = p.owner
			_log("[b]%s is now rightful %s land[/b] — a generation has passed, and the old banners are forgotten." % [
				p.name, str(realms[p.owner].name).trim_prefix("Kingdom of ")])


# ---------------------------------------------------------------- vassals (Module 4)

func landed_vassals(realm_id: int) -> Array:
	## The lords who hold the realm's granted counties and duchies —
	## the men whose contracts, votes, and grudges Module 4 is about.
	var seen := {}
	var out: Array = []
	for pid in county_holders:
		var c := county_holder(pid)
		if c != null and map.provinces[pid].owner == realm_id and not seen.has(c.id):
			seen[c.id] = true
			out.append(c)
	for did in duchy_holders:
		var c2 := duchy_holder(did)
		if c2 != null and map.duchies[did].realm == realm_id and not seen.has(c2.id):
			seen[c2.id] = true
			out.append(c2)
	return out


func counties_of(char_id: int) -> Array:
	var out: Array = []
	for pid in county_holders:
		if int(county_holders[pid]) == char_id and county_holder(pid) != null:
			out.append(int(pid))
	return out


func contract_of(char_id: int) -> Dictionary:
	## Every landed vassal has a feudal contract; the default is fair terms.
	if not vassal_contracts.has(char_id):
		vassal_contracts[char_id] = {"tax": "normal", "levy": "normal", "privileges": []}
	return vassal_contracts[char_id]


func has_privilege(char_id: int, priv: String) -> bool:
	return vassal_contracts.has(char_id) and vassal_contracts[char_id]["privileges"].has(priv)


func set_contract_rate(char_id: int, which: String, value: String) -> String:
	if not characters.has(char_id) or not CONTRACT_RATES.has(value):
		return "No such contract."
	var c: SimCharacter = characters[char_id]
	var contract := contract_of(char_id)
	var old := str(contract[which])
	if old == value:
		return ""
	contract[which] = value
	var realm: Realm = realms[c.realm_id]
	var harsher := int(CONTRACT_RATES[value]["opinion"]) < int(CONTRACT_RATES[old]["opinion"])
	if harsher:
		realm.tyranny = minf(100.0, realm.tyranny + 5.0)
		if realm.ruler_id >= 0:
			add_memory(c, "the crown squeezes my lands", realm.ruler_id, -15.0, 1.0)
		_log("%s's %s obligations are raised to %s terms — the ledger gains, the loyalty pays." % [
			full_name(c), which, value])
	else:
		if realm.ruler_id >= 0:
			add_memory(c, "the crown eased my burdens", realm.ruler_id, 10.0, 1.0)
		_log("%s's %s obligations are eased to %s terms." % [full_name(c), which, value])
	return ""


func grant_privilege(char_id: int, priv: String) -> String:
	if not PRIVILEGES.has(priv):
		return "No such privilege."
	var contract := contract_of(char_id)
	if contract["privileges"].has(priv):
		return "They hold that privilege already."
	contract["privileges"].append(priv)
	var c: SimCharacter = characters[char_id]
	if realms[c.realm_id].ruler_id >= 0:
		add_memory(c, "a privilege written into my contract", realms[c.realm_id].ruler_id, 20.0, 0.5)
	_log("[b]%s extracts a privilege: %s[/b] — %s." % [full_name(c),
		PRIVILEGES[priv]["label"], PRIVILEGES[priv]["blurb"]])
	return ""


func vassal_opinion(char_id: int, realm_id: int) -> int:
	## The granular ledger of a lord's regard: personal opinion of the
	## ruler, contract terms, cultural alignment, privileges held, and
	## the realm's remembered tyranny.
	var realm: Realm = realms[realm_id]
	if realm.ruler_id < 0 or not characters.has(char_id):
		return 0
	var c: SimCharacter = characters[char_id]
	var total := float(opinion_of(char_id, realm.ruler_id))
	var contract := contract_of(char_id)
	total += float(CONTRACT_RATES[contract["tax"]]["opinion"])
	total += float(CONTRACT_RATES[contract["levy"]]["opinion"]) * 0.5
	total += contract["privileges"].size() * 5.0
	var ruler: SimCharacter = characters[realm.ruler_id]
	if c.culture == ruler.culture:
		total += 5.0
	elif not CultureData.hybrid_parents(c.culture).has(ruler.culture) \
			and not CultureData.hybrid_parents(ruler.culture).has(c.culture):
		total -= 10.0  # a lord of another tradition under a foreign crown
	total -= realm.tyranny * 0.5
	return clampi(int(total), -100, 100)


func _inherit_titles(dead: SimCharacter) -> void:
	## Module 4: lordships are hereditary. The eldest trueborn child of
	## the realm inherits the titles and the contract; a line with no
	## such heir escheats to the crown as before.
	var held_counties: Array = []
	var held_duchies: Array = []
	for pid in county_holders.keys():
		if int(county_holders[pid]) == dead.id:
			held_counties.append(pid)
	for did in duchy_holders.keys():
		if int(duchy_holders[did]) == dead.id:
			held_duchies.append(did)
	if held_counties.is_empty() and held_duchies.is_empty():
		return
	var heir: SimCharacter = null
	for cid in dead.children_ids:
		var ch: SimCharacter = characters[cid]
		if not ch.alive or ch.is_bastard or ch.disinherited or ch.denounced:
			continue
		if ch.realm_id != dead.realm_id or ch.age_years(tick) < ADULT_AGE:
			continue
		if heir == null or (not ch.is_female and heir.is_female) \
				or (ch.is_female == heir.is_female and ch.birth_tick < heir.birth_tick):
			heir = ch
	if heir == null:
		_escheat_titles(dead)
		return
	for pid in held_counties:
		county_holders[pid] = heir.id
	for did in held_duchies:
		duchy_holders[did] = heir.id
	if vassal_contracts.has(dead.id):
		vassal_contracts[heir.id] = vassal_contracts[dead.id]  # the contract binds the line
		vassal_contracts.erase(dead.id)
	var realm: Realm = realms[dead.realm_id]
	if realm.ruler_id >= 0 and realm.ruler_id != heir.id:
		add_memory(heir, "confirmed in my inheritance", realm.ruler_id, 15.0, 0.5)
	_log("%s inherits the lands of %s." % [full_name(heir), full_name(dead)])


# ---------------------------------------------------------------- the Curia

func bloc_of(c: SimCharacter) -> String:
	## Personality is ideology: lords caucus by disposition. The
	## unaligned default to the Traditionalists — the old ways ask
	## nothing of a man but his silence.
	var best := "Traditionalists"
	var best_score := 0
	for bloc in CURIA_BLOCS:
		var score := 0
		for t in CURIA_BLOCS[bloc]["traits"]:
			if c.traits.has(t):
				score += 1
		if score > best_score:
			best_score = score
			best = bloc
	return best


func curia_vote(realm_id: int, matter: String) -> Dictionary:
	## The Estate Curia: great matters need the landed lords' assent.
	## Vote weight is counties held (+1 for a duchy); each lord votes his
	## bloc's agenda, bent by his regard for the crown.
	var members := landed_vassals(realm_id)
	if members.size() < CURIA_MIN_MEMBERS:
		return {"passed": true, "for": 0, "against": 0,
			"detail": "too few landed lords — the crown rules alone"}
	var votes_for := 0
	var votes_against := 0
	var against_names: Array = []
	for c in members:
		var weight: int = counties_of(c.id).size()
		for did in duchy_holders:
			if int(duchy_holders[did]) == c.id:
				weight += 1
		weight = maxi(weight, 1)
		var stance := int(CURIA_BLOCS[bloc_of(c)]["agenda"].get(matter, 0))
		var regard := vassal_opinion(c.id, realm_id)
		if regard >= 40:
			stance += 1  # loyalty bends ideology
		elif regard <= FACTION_JOIN_OPINION:
			stance -= 1  # spite does too
		# a hook is a vote in the crown's pocket (Module 6: the Hook system)
		if stance <= 0 and has_hook(realm_id, c.id):
			var _spent := _spend_hook(realm_id, c.id)
			stance = 1
		if stance > 0:
			votes_for += weight
		elif stance < 0:
			votes_against += weight
			against_names.append(full_name(c))
	var passed := votes_for >= votes_against
	return {"passed": passed, "for": votes_for, "against": votes_against,
		"detail": ("carried %d to %d" % [votes_for, votes_against]) if passed
			else ("defeated %d to %d — led by %s" % [votes_against, votes_for,
				against_names[0] if not against_names.is_empty() else "the blocs"])}


func sway_curia(realm_id: int, char_id: int) -> String:
	## Horse-trading: the crown's gold warms a voting lord's regard.
	var realm: Realm = realms[realm_id]
	if realm.gold < 40.0:
		return "Not enough gold — 40 needed."
	if not characters.has(char_id) or characters[char_id].realm_id != realm_id:
		return "No such lord."
	realm.gold -= 40.0
	if realm.ruler_id >= 0:
		add_memory(characters[char_id], "the crown courts my vote", realm.ruler_id, 25.0, 2.0)
	_log("The crown spends 40 gold courting %s's voice in the Curia." % full_name(characters[char_id]))
	return ""


# ---------------------------------------------------------------- the Faction Engine

func faction_strength(f: Dictionary) -> float:
	## Men the faction could field: its lords' county levies and personal
	## followings, or — for a populist rising — the oppressed land itself.
	var total := 0.0
	if str(f["type"]) == "populist":
		for pid in f["provinces"]:
			total += float(map.provinces[pid].levy) * 1.5
		return total
	for cid in f["members"]:
		var c: SimCharacter = characters.get(cid)
		if c == null or not c.alive:
			continue
		for pid in counties_of(cid):
			total += float(map.provinces[pid].levy)
		total += c.martial * 2.0
	return total


func faction_of(char_id: int) -> Dictionary:
	for f in factions:
		if f["members"].has(char_id):
			return f
	return {}


func visible_factions(realm_id: int) -> Array:
	## What the crown can actually see: overt factions, and covert ones
	## the Spymaster has dug up. The rest conspire in the dark.
	var out: Array = []
	for f in factions:
		if int(f["realm"]) == realm_id and (not bool(f["covert"]) or bool(f["discovered"])):
			out.append(f)
	return out


func bribe_faction_member(char_id: int) -> String:
	## Preemptive politics: a discovered conspirator can be bought.
	var f := faction_of(char_id)
	if f.is_empty():
		return "They conspire with no one."
	if bool(f["covert"]) and not bool(f["discovered"]):
		return "The crown does not know of any conspiracy."  # no acting on hidden knowledge
	var c: SimCharacter = characters[char_id]
	var realm: Realm = realms[int(f["realm"])]
	if realm.gold < 60.0:
		return "Not enough gold — 60 needed."
	realm.gold -= 60.0
	f["members"].erase(char_id)
	if realm.ruler_id >= 0:
		add_memory(c, "the crown's gold bought my patience", realm.ruler_id, 30.0, 1.5)
	_log("%s takes the crown's gold and abandons the %s faction." % [
		full_name(c), FACTION_LABELS[str(f["type"])]])
	return ""


func _factions_tick() -> void:
	_tyranny_decay()
	for realm: Realm in realms:
		if realm.ruler_id < 0:
			continue
		_faction_maintenance(realm)
		_faction_formation(realm)
		_populist_unrest(realm)
		_faction_discovery(realm)
		_faction_ultimatums(realm)


func _tyranny_decay() -> void:
	for realm: Realm in realms:
		realm.tyranny = maxf(0.0, realm.tyranny - TYRANNY_DECAY)


func _faction_maintenance(realm: Realm) -> void:
	## The appeased and the dead leave; empty conspiracies dissolve.
	for f in factions.duplicate():
		if int(f["realm"]) != realm.id:
			continue
		if str(f["type"]) == "populist":
			var still: Array = []
			for pid in f["provinces"]:
				var p = map.provinces[pid]
				if p.owner == realm.id and p.de_jure != realm.id:
					still.append(pid)
			f["provinces"] = still
			if still.size() < 2:
				factions.erase(f)
			continue
		var kept: Array = []
		for cid in f["members"]:
			var c: SimCharacter = characters.get(cid)
			if c == null or not c.alive or c.realm_id != realm.id or c.denounced:
				continue
			if vassal_opinion(cid, realm.id) > 10:
				_log("%s's grievances cool, and the conspiracy loses him." % full_name(c))
				continue
			if counties_of(cid).is_empty():
				continue  # a stripped lord commands no rising
			kept.append(cid)
		f["members"] = kept
		if kept.is_empty():
			factions.erase(f)


func _faction_formation(realm: Realm) -> void:
	## Discontent landed lords conspire. The faction's cause follows the
	## lord's situation: a claimant if the dynasty offers one, autonomy
	## for a foreign-cultured march, liberty otherwise.
	for c in landed_vassals(realm.id):
		if c.id == realm.ruler_id or not faction_of(c.id).is_empty():
			continue
		if vassal_opinion(c.id, realm.id) > FACTION_JOIN_OPINION:
			continue
		var chance := 0.08 + ai_weight(c, "scheming") * 0.001 + ai_weight(c, "aggression") * 0.0005
		if rng.randf() > chance:
			continue
		var ruler: SimCharacter = characters[realm.ruler_id]
		var ftype := "liberty"
		var claimant := _find_claimant(realm, ruler)
		if claimant != null:
			ftype = "claimant"
		elif c.culture != ruler.culture and counties_of(c.id).size() >= 2:
			ftype = "independence"
		# join a standing faction of the same cause before founding a new one
		var joined := false
		for f in factions:
			if int(f["realm"]) == realm.id and str(f["type"]) == ftype and not f["members"].has(c.id):
				f["members"].append(c.id)
				joined = true
				break
		if not joined:
			factions.append({"realm": realm.id, "type": ftype, "members": [c.id], "provinces": [],
				"covert": true, "discovered": false,
				"claimant": claimant.id if claimant != null else -1})
		_log_covert(realm, "%s enters a %s conspiracy against the crown." % [
			full_name(c), FACTION_LABELS[ftype]])


func _find_claimant(realm: Realm, ruler: SimCharacter) -> SimCharacter:
	## A rival with better blood: an aggrieved or passed-over adult of the
	## ruling dynasty who is not the ruler.
	for c in characters.values():
		if not c.alive or c.id == ruler.id or c.realm_id != realm.id:
			continue
		if root_house_id(c.dynasty_id) != root_house_id(ruler.dynasty_id):
			continue
		if c.age_years(tick) < ADULT_AGE or c.is_bastard or c.denounced or c.bought_off:
			continue
		if c.aggrieved:
			return c
		for m in c.memories:
			if str(m["type"]) == "passed over":
				return c
	return null


func _populist_unrest(realm: Realm) -> void:
	## Conquered land remembers its own: two or more counties still flying
	## older banners rise together (culturally oppressed, per the design).
	var oppressed: Array = []
	for p in map.provinces:
		if p.owner == realm.id and p.de_jure != realm.id and tick - p.held_since >= 24:
			oppressed.append(p.id)
	if oppressed.size() < 2:
		return
	for f in factions:
		if int(f["realm"]) == realm.id and str(f["type"]) == "populist":
			f["provinces"] = oppressed
			return
	factions.append({"realm": realm.id, "type": "populist", "members": [], "provinces": oppressed,
		"covert": true, "discovered": false, "claimant": -1})
	_log_covert(realm, "In the conquered counties, older banners pass from hand to hand after dark.")


func _log_covert(realm: Realm, text: String) -> void:
	## Covert politics is only chronicled where the player could know it —
	## realm 1's conspiracies stay dark until they surface.
	if realm.id == 0:
		_log(text)


func _faction_discovery(realm: Realm) -> void:
	## The intelligence game: only a seated Spymaster finds the cabal
	## before it finds you.
	var spy := council_member(realm.id, "Spymaster")
	if spy == null:
		return
	for f in factions:
		if int(f["realm"]) != realm.id or not bool(f["covert"]) or bool(f["discovered"]):
			continue
		if rng.randf() < 0.04 + spy.intrigue * 0.008:
			f["discovered"] = true
			if realm.id == 0:
				_log("[b]The Spymaster uncovers a %s conspiracy[/b] — %d %s, mustering %d men in secret." % [
					FACTION_LABELS[str(f["type"])],
					maxi(f["members"].size(), f["provinces"].size()),
					"lords" if not f["members"].is_empty() else "counties",
					int(faction_strength(f))])


func _faction_ultimatums(realm: Realm) -> void:
	## Strength past the threshold turns the cabal overt: an ultimatum
	## lands on the throne, however inconvenient the hour.
	for f in factions.duplicate():
		if int(f["realm"]) != realm.id or not bool(f["covert"]):
			continue
		var cap := float(levy_capacity(realm.id))
		if faction_strength(f) < cap * FACTION_OVERT_FRACTION:
			continue
		f["covert"] = false
		f["discovered"] = true
		_raise_ultimatum(realm, f)


func _faction_demand_text(f: Dictionary) -> String:
	match str(f["type"]):
		"liberty":
			return "lighter taxation and a gentler crown"
		"claimant":
			var cl: SimCharacter = characters.get(int(f["claimant"]))
			return "the crown itself — for %s" % (full_name(cl) if cl != null else "a rival claimant")
		"independence":
			return "marcher autonomy: their own coin, their own walls, no levies owed"
		"populist":
			return "the return of the conquered counties to their rightful realm"
	return "concessions"


func _raise_ultimatum(realm: Realm, f: Dictionary) -> void:
	var strength := int(faction_strength(f))
	var demand := _faction_demand_text(f)
	var fac := f
	var r := realm
	_log("[b]ULTIMATUM:[/b] a %s faction steps into the open in %s — %d men strong, demanding %s." % [
		FACTION_LABELS[str(f["type"])], realm.name, strength, demand])
	raise_event(realm.id, realm.ruler_id, "The %s Ultimatum" % FACTION_LABELS[str(f["type"])],
		"The conspiracy is a conspiracy no longer. %d men stand behind a demand for %s. Concede, or meet them in the field." % [
			strength, demand],
		[{"label": "Concede — the crown bends", "base": 10, "ai": {"patience": 0.3, "aggression": -0.3},
			"effect": func() -> void: _concede_faction(r, fac)},
		{"label": "Refuse — let treason be answered in the field", "base": 20, "ai": {"aggression": 0.4},
			"effect": func() -> void: _civil_war(r, fac)}])


func _concede_faction(realm: Realm, f: Dictionary) -> void:
	match str(f["type"]):
		"liberty":
			realm.tax_law = "light"
			realm.tyranny = maxf(0.0, realm.tyranny - 20.0)
			_log("[b]The crown bends:[/b] taxation is lightened and old injuries pardoned. The lords disperse, satisfied.")
		"claimant":
			var cl: SimCharacter = characters.get(int(f["claimant"]))
			if cl != null and cl.alive:
				var old_id := realm.ruler_id
				realm.ruler_id = cl.id
				cl.aggrieved = false
				if old_id >= 0 and characters[old_id].alive:
					add_memory(characters[old_id], "stole my crown", cl.id, -80.0, 1.0)
				_log("[b]The crown bends: %s abdicates, and %s takes the throne the faction demanded.[/b]" % [
					full_name(characters[old_id]) if old_id >= 0 else "the ruler", full_name(cl)])
			else:
				_log("The claimant is dead — the faction's demand dies with them.")
		"independence":
			# True secession waits for the multi-realm engine; the marches
			# win autonomy so complete it is independence in all but name.
			for cid in f["members"]:
				var contract := contract_of(int(cid))
				for priv in ["marcher_lord", "coinage_rights"]:
					if not contract["privileges"].has(priv):
						contract["privileges"].append(priv)
			_log("[b]The crown bends:[/b] the marches win their own coin and keep their own levies — independent in all but the maps.")
		"populist":
			for pid in f["provinces"]:
				var p = map.provinces[pid]
				var back: int = p.de_jure
				p.owner = back
				p.held_since = tick
				county_holders.erase(pid)
				_log("%s returns to %s — the risen folk tear down the crown's banners themselves." % [
					p.name, realm_name_of(back)])
	for cid in f["members"]:
		var c: SimCharacter = characters.get(int(cid))
		if c != null and c.alive and realm.ruler_id >= 0:
			add_memory(c, "the crown yielded to our demand", realm.ruler_id, 20.0, 1.0)
	factions.erase(f)


func realm_name_of(realm_id: int) -> String:
	if realm_id >= 0 and realm_id < map.realms.size():
		return map.realm_display_name(realm_id)
	return "no crown"


func _civil_war(realm: Realm, f: Dictionary) -> void:
	## Treason answered in the field: the rebel muster meets the realm's
	## standing armies in one pitched battle, resolved by the real sim.
	var rebel_men := int(faction_strength(f))
	var rebel_roster: Array = []
	while rebel_men > 0 and rebel_roster.size() < 14:
		if rebel_roster.size() % 3 == 0 and rebel_men >= 36:
			rebel_roster.append({"kind": "sword", "soldiers": 36})
			rebel_men -= 36
		else:
			var n := mini(rebel_men, 48)
			rebel_roster.append({"kind": "levy", "soldiers": n})
			rebel_men -= n
	var loyal_roster: Array = []
	var sources: Array = []   # [army, regiment index] per loyal roster entry
	for a: Army in armies:
		if a.realm_id != realm.id:
			continue
		for i in a.regiments.size():
			loyal_roster.append({"kind": a.regiments[i]["kind"], "soldiers": int(a.regiments[i]["soldiers"])})
			sources.append([a, i])
	if loyal_roster.is_empty():
		loyal_roster.append({"kind": "levy", "soldiers": 24})  # the palace guard, and hope
	var ruler_martial := 0
	if realm.ruler_id >= 0:
		ruler_martial = characters[realm.ruler_id].martial
	var rebel_lead := 0
	for cid in f["members"]:
		var c: SimCharacter = characters.get(int(cid))
		if c != null and c.alive:
			rebel_lead = maxi(rebel_lead, c.martial)
	var sim := BattleSim.new()
	sim.setup_from_rosters(loyal_roster, rebel_roster, ruler_martial, rebel_lead,
		[str(realm.name).trim_prefix("Kingdom of "), "Rebel"])
	sim.run_headless()
	# the realm's armies carry their civil-war dead home
	for i in sources.size():
		for reg: BattleSim.Regiment in sim.regiments:
			if reg.side == 0 and reg.roster_index == i:
				var a: Army = sources[i][0]
				a.regiments[sources[i][1]]["soldiers"] = reg.soldiers if reg.alive() else 0
	for a: Army in armies.duplicate():
		if a.realm_id != realm.id:
			continue
		var kept: Array = []
		for reg in a.regiments:
			if int(reg["soldiers"]) > 0:
				kept.append(reg)
		a.regiments = kept
		if kept.is_empty():
			armies.erase(a)
	if sim.winner == 0:
		_log("[b]The rebellion is broken in the field.[/b] The crown's banners stand over the wreck of the %s faction." % FACTION_LABELS[str(f["type"])])
		if str(f["type"]) == "populist":
			for pid in f["provinces"]:
				map.provinces[pid].held_since = tick  # the rising crushed, the clock reset
			realm.tyranny = minf(100.0, realm.tyranny + 10.0)
		else:
			# The Traitor's Tribunal (Module 5): treason is not answered
			# with three buttons — the crown must convene and judge.
			_raise_tribunal(realm, (f["members"] as Array).duplicate())
		factions.erase(f)
	else:
		_log("[b]The crown's host is beaten by its own vassals.[/b] The demand is granted at sword-point.")
		realm.gold = maxf(0.0, realm.gold - 60.0)
		realm.tyranny = maxf(0.0, realm.tyranny - 30.0)
		_concede_faction(realm, f)


# ------------------------------------------- the traitor's tribunal (Module 5)

func _raise_tribunal(realm: Realm, traitor_ids: Array) -> void:
	## Loyalist Expectations: the lords who bled for the crown wait to see
	## what treason costs. Mercy reads as weakness; cruelty reads as tyranny.
	var names: Array = []
	for cid in traitor_ids:
		var c: SimCharacter = characters.get(int(cid))
		if c != null and c.alive:
			names.append(full_name(c))
	if names.is_empty():
		return
	var rid := realm.id
	raise_event(realm.id, realm.ruler_id, "The Traitor's Tribunal",
		"The rebels — %s — kneel in chains. The loyalists who bled for the crown watch what their loyalty was worth." % ", ".join(names),
		[
			{"label": "The Scaffold — hang them all", "base": 0.0, "ai": {"aggression": 0.8},
				"effect": func() -> void: _tribunal_scaffold(rid, traitor_ids)},
			{"label": "Attainder — strip their lands, spare their necks", "base": 3.0, "ai": {"greed": 0.6},
				"effect": func() -> void: _tribunal_attainder(rid, traitor_ids)},
			{"label": "Forced Tonsure — the cloister takes them", "base": 2.0, "ai": {"patience": 0.6},
				"effect": func() -> void: _tribunal_tonsure(rid, traitor_ids)},
			{"label": "The King's Pardon — total mercy", "base": 0.0, "ai": {"aggression": -0.8},
				"effect": func() -> void: _tribunal_pardon(rid, traitor_ids)},
		])


func _tribunal_loyalists(realm_id: int, traitor_ids: Array) -> Array:
	var out: Array = []
	for c in landed_vassals(realm_id):
		if not traitor_ids.has(c.id):
			out.append(c)
	return out


func _strip_traitor(c: SimCharacter) -> void:
	for pid in counties_of(c.id):
		county_holders.erase(pid)
	for did in duchy_holders.keys():
		if int(duchy_holders[did]) == c.id:
			duchy_holders.erase(did)


func _tribunal_scaffold(realm_id: int, traitor_ids: Array) -> void:
	var realm: Realm = realms[realm_id]
	var ruler_root := -1
	if realm.ruler_id >= 0:
		ruler_root = root_house_id(characters[realm.ruler_id].dynasty_id)
	for cid in traitor_ids:
		var c: SimCharacter = characters.get(int(cid))
		if c == null or not c.alive:
			continue
		_strip_traitor(c)
		var t_root := root_house_id(c.dynasty_id)
		if ruler_root >= 0 and t_root != ruler_root and not in_blood_feud(ruler_root, t_root):
			blood_feuds.append([ruler_root, t_root])  # the hanged become martyrs
		_kill(c, "went to the scaffold for treason")
	realm.tyranny = minf(100.0, realm.tyranny + 20.0)
	for l: SimCharacter in _tribunal_loyalists(realm_id, traitor_ids):
		add_memory(l, "traitors got what traitors earn", realm.ruler_id, 30.0, 1.0)
	_log("[b]The Scaffold.[/b] The traitors hang in a row — the loyal cheer, the realm shudders, and blood swears feuds against the crown.")


func _tribunal_attainder(realm_id: int, traitor_ids: Array) -> void:
	var realm: Realm = realms[realm_id]
	var stripped_roots := {}
	for cid in traitor_ids:
		var c: SimCharacter = characters.get(int(cid))
		if c == null or not c.alive:
			continue
		_strip_traitor(c)
		if realm.ruler_id >= 0:
			add_memory(c, "attainted — my line dispossessed", realm.ruler_id, -60.0, 1.0)
		stripped_roots[root_house_id(c.dynasty_id)] = true
	realm.tyranny = minf(100.0, realm.tyranny + 10.0)
	for l: SimCharacter in _tribunal_loyalists(realm_id, traitor_ids):
		add_memory(l, "the traitors' lands should be ours", realm.ruler_id, -10.0, 1.0)
	_log("[b]Attainder.[/b] The traitors are stripped of every hall and acre — and the loyal eye the vacant land, expecting.")
	# a house left with nothing does not linger — it flees (the Shadow Court)
	for root in stripped_roots:
		var holds_land := false
		for c2 in characters.values():
			if c2.alive and root_house_id(c2.dynasty_id) == int(root) and not counties_of(c2.id).is_empty():
				holds_land = true
				break
		if not holds_land:
			_dispossess(int(root), realm_id)


func _tribunal_tonsure(realm_id: int, traitor_ids: Array) -> void:
	var realm: Realm = realms[realm_id]
	for cid in traitor_ids:
		var c: SimCharacter = characters.get(int(cid))
		if c == null or not c.alive:
			continue
		_strip_traitor(c)
		c.disinherited = true
		add_stress(c, -20.0, "the quiet of the cloister")
		if realm.ruler_id >= 0:
			add_memory(c, "tonsured against my will", realm.ruler_id, -30.0, 1.0)
	# neutralized — but the cloistered pen still cuts
	for l: SimCharacter in landed_vassals(realm_id):
		if traitor_ids.has(l.id):
			continue
		add_memory(l, "pamphlets from the cloister", realm.ruler_id, -5.0, 2.0)
		add_memory(l, "holy tradition upheld", realm.ruler_id, 10.0, 1.0)
	_log("[b]Forced Tonsure.[/b] The traitors take vows they did not choose — out of the succession, into the scriptorium, and never quite silent.")


func _tribunal_pardon(realm_id: int, traitor_ids: Array) -> void:
	var realm: Realm = realms[realm_id]
	for cid in traitor_ids:
		var c: SimCharacter = characters.get(int(cid))
		if c == null or not c.alive:
			continue
		if realm.ruler_id >= 0:
			add_memory(c, "pardoned — and in the crown's debt", realm.ruler_id, 30.0, 1.0)
	realm.prestige = minf(100.0, realm.prestige + 10.0)
	for l: SimCharacter in _tribunal_loyalists(realm_id, traitor_ids):
		add_memory(l, "mercy for traitors, nothing for the loyal", realm.ruler_id, -40.0, 1.0)
	_log("[b]The King's Pardon.[/b] The traitors keep their heads and their halls — and every loyal lord remembers what rebellion did not cost.")


# ---------------------------------------------------------------- monthly grievances

func _vassal_politics_tick() -> void:
	## Council snubs, privilege demands, and the great feuds that drag
	## the liege into judgment — the slow politics between the crises.
	for realm: Realm in realms:
		if realm.ruler_id < 0 or realm.government == "tribal":
			continue  # tribal power is personal; these are legal institutions
		_council_snub_tick(realm)
		_privilege_demand_tick(realm)
		_court_trial_tick(realm)


func _council_snub_tick(realm: Realm) -> void:
	## Powerful vassals expect seats. A duke or great lord passed over
	## for a lesser man voices the grievance exactly once.
	for c in landed_vassals(realm.id):
		if council_snubbed.has(c.id) or has_privilege(c.id, "guaranteed_seat"):
			continue
		var is_great := counties_of(c.id).size() >= 2
		for did in duchy_holders:
			if int(duchy_holders[did]) == c.id:
				is_great = true
		if not is_great:
			continue
		var seated := false
		for seat in COUNCIL_SEATS:
			if int(realm.council.get(seat, -1)) == c.id:
				seated = true
		if seated:
			continue
		for seat in COUNCIL_SEATS:
			var holder := council_member(realm.id, seat)
			if holder != null and int(c.get(SEAT_STAT[seat])) > int(holder.get(SEAT_STAT[seat])) + 3:
				council_snubbed[c.id] = true
				add_memory(c, "snubbed for the council", realm.ruler_id, -20.0, 1.0)
				if realm.id == 0:
					_log("%s expected a council seat — and marks the lesser man who holds it." % full_name(c))
				break


func _privilege_demand_tick(realm: Realm) -> void:
	## Privilege creep: a lord with leverage — the crown at war needs his
	## levies — demands an addendum, not gold.
	if not at_war:
		return
	var lords := landed_vassals(realm.id)
	if lords.is_empty():
		return  # no rng draw when there is no one to demand (keeps history stable)
	if rng.randf() > 0.06:
		return
	for c in lords:
		if vassal_opinion(c.id, realm.id) > 20 or counties_of(c.id).size() < 2:
			continue
		var wanted := ""
		for priv in PRIVILEGES:
			if not has_privilege(c.id, str(priv)):
				wanted = str(priv)
				break
		if wanted == "":
			continue
		var lord: SimCharacter = c
		var pr := wanted
		var r := realm
		raise_event(realm.id, realm.ruler_id, "A Privilege Demanded",
			"%s holds %d counties the war cannot spare — and knows it. The price of loyalty is written out: [b]%s[/b] (%s)." % [
				full_name(c), counties_of(c.id).size(), PRIVILEGES[wanted]["label"], PRIVILEGES[wanted]["blurb"]],
			[{"label": "Grant the addendum", "base": 15, "ai": {"patience": 0.3},
				"effect": func() -> void: var _e := grant_privilege(lord.id, pr)},
			{"label": "Refuse — the crown is not for sale", "base": 15, "ai": {"aggression": 0.3},
				"effect": func() -> void:
					add_memory(lord, "my price refused in wartime", r.ruler_id, -20.0, 1.5)
					_log("%s withdraws, cold — the crown will remember the counties that march slowly." % full_name(lord))}])
		return  # one demand a month is plenty


func _court_trial_tick(realm: Realm) -> void:
	## The Liege's Court Trial: when two great houses of the realm turn
	## on each other, the map halts and the crown must judge.
	if tick - last_trial_tick < 24:
		return
	var lords := landed_vassals(realm.id)
	if lords.size() < 2:
		return  # no rng draw without a possible feud (keeps history stable)
	if rng.randf() > 0.1:
		return
	for i in lords.size():
		for j in lords.size():
			if i == j:
				continue
			var a: SimCharacter = lords[i]
			var b: SimCharacter = lords[j]
			if opinion_of(a.id, b.id) > -30:
				continue
			last_trial_tick = tick
			_raise_arbitration(realm, a, b)
			return


func _raise_arbitration(realm: Realm, aggressor: SimCharacter, defender: SimCharacter) -> void:
	var evidence := "The evidence favors %s" % full_name(defender if defender.diplomacy >= aggressor.diplomacy else aggressor)
	var agg := aggressor
	var def := defender
	var r := realm
	raise_event(realm.id, realm.ruler_id, "The Liege's Court",
		"%s moves against %s, and the defender appeals to the crown's justice. Both stand before the Curia. %s — but the verdict is yours, and every bloc is watching." % [
			full_name(aggressor), full_name(defender), evidence],
		[{"label": "Side with %s — reward the strong" % full_name(aggressor), "base": 5, "ai": {"aggression": 0.3},
			"effect": func() -> void:
				add_memory(agg, "the crown upheld my cause", r.ruler_id, 30.0, 1.0)
				add_memory(def, "denied the crown's justice", r.ruler_id, -40.0, 1.0)
				r.tyranny = minf(100.0, r.tyranny + 5.0)
				for c in landed_vassals(r.id):
					if bloc_of(c) == "Constitutionalists" and c.id != agg.id:
						add_memory(c, "a verdict bought by strength", r.ruler_id, -10.0, 1.0)
				_log("[b]The verdict favors %s.[/b] The Constitutionalists file out without bowing." % full_name(agg))},
		{"label": "Side with %s — uphold the law" % full_name(defender), "base": 15, "ai": {"patience": 0.2},
			"effect": func() -> void:
				add_memory(def, "the crown upheld my rights", r.ruler_id, 30.0, 1.0)
				add_memory(agg, "humbled before the court", r.ruler_id, -40.0, 1.0)
				if agg.traits.has("Wrathful") or agg.traits.has("Ambitious"):
					for pid in counties_of(agg.id):
						county_holders.erase(pid)
					add_memory(agg, "branded an outlaw of the realm", r.ruler_id, -60.0, 0.5)
					_log("[b]%s refuses the verdict and is branded a Realm Outlaw[/b] — stripped of every county at once." % full_name(agg))
				else:
					_log("[b]The verdict favors %s.[/b] The law holds; the realm exhales." % full_name(def))},
		{"label": "Force a compromise (50 gold)", "base": 10, "ai": {"patience": 0.3},
			"effect": func() -> void:
				var spent := minf(50.0, r.gold)
				r.gold -= spent
				add_memory(agg, "the crown's compromise", r.ruler_id, 10.0, 1.0)
				add_memory(def, "the crown's compromise", r.ruler_id, 10.0, 1.0)
				add_memory(agg, "a feud settled at court", def.id, 15.0, 1.0)
				add_memory(def, "a feud settled at court", agg.id, 15.0, 1.0)
				_log("The crown spends %d gold splitting the difference — neither lord loves the verdict, and neither draws steel." % int(spent))}])


# ---------------------------------------------------------------- dynasty (Module 2)

func root_house_id(house_id: int) -> int:
	## Walk the cadet tree up to the founding house — the dynasty.
	## Co-equal and schismatic charters cut the cord: those branches
	## are their own dynasty, whatever the family tree says.
	var id := house_id
	while id >= 0 and dynasties[id].parent_id >= 0 and dynasties[id].charter == "loyalist":
		id = dynasties[id].parent_id
	return id


func in_blood_feud(root_a: int, root_b: int) -> bool:
	for f in blood_feuds:
		if (int(f[0]) == root_a and int(f[1]) == root_b) or (int(f[0]) == root_b and int(f[1]) == root_a):
			return true
	return false


func has_mythos(root_id: int, tag: String) -> bool:
	return root_id >= 0 and dynasties[root_id].mythos.has(tag)


func _earn_mythos(root_id: int, tag: String) -> void:
	var dyn: Dynasty = dynasties[root_id]
	if dyn.mythos.has(tag):
		return
	dyn.mythos.append(tag)
	_log("[b]The name of %s is marked forever: %s.[/b] %s." % [dyn.name, tag, MYTHOS[tag]["blurb"]])


func dynasty_house_ids(root_id: int) -> Array:
	var out: Array = []
	for dyn: Dynasty in dynasties.values():
		if root_house_id(dyn.id) == root_id:
			out.append(dyn.id)
	return out


func house_members(house_id: int) -> Array:
	var out: Array = []
	for c in characters.values():
		if c.alive and c.dynasty_id == house_id:
			out.append(c)
	return out


func dynasty_members(root_id: int) -> Array:
	var out: Array = []
	for c in characters.values():
		if c.alive and root_house_id(c.dynasty_id) == root_id:
			out.append(c)
	return out


func is_ruler(char_id: int) -> bool:
	for realm: Realm in realms:
		if realm.ruler_id == char_id:
			return true
	return false


func house_head(house_id: int) -> SimCharacter:
	## Seniority: a crowned member first, then eldest man, then eldest.
	var best: SimCharacter = null
	for c in house_members(house_id):
		if c.age_years(tick) < ADULT_AGE or c.is_bastard:
			continue
		if best == null or _outranks(c, best):
			best = c
	return best


func dynasty_head(root_id: int) -> SimCharacter:
	## The doc: "the most powerful or senior House Head serves as the
	## global Dynasty Head." Same seniority rule, across all house heads.
	var best: SimCharacter = null
	for hid in dynasty_house_ids(root_id):
		var h := house_head(hid)
		if h != null and (best == null or _outranks(h, best)):
			best = h
	return best


func _outranks(a: SimCharacter, b: SimCharacter) -> bool:
	if is_ruler(a.id) != is_ruler(b.id):
		return is_ruler(a.id)
	if a.is_female != b.is_female:
		return b.is_female
	return a.birth_tick < b.birth_tick


func has_legacy(root_id: int, key: String) -> bool:
	return root_id >= 0 and dynasties[root_id].legacies.has(key)


func renown_gain(root_id: int) -> float:
	## Fame flows from members holding real power in the world.
	var gain := 0.0
	for c in dynasty_members(root_id):
		if c.age_years(tick) >= ADULT_AGE:
			gain += 0.1
		if is_ruler(c.id):
			gain += 3.0
		for realm: Realm in realms:
			if realm.council.values().has(c.id):
				gain += 0.6
		for a: Army in armies:
			if a.commander_id == c.id:
				gain += 0.4
		for pid in county_holders:
			if int(county_holders[pid]) == c.id:
				gain += 0.3
		for did in duchy_holders:
			if int(duchy_holders[did]) == c.id:
				gain += 0.8
	# a spreading family tree is fame in itself
	gain += 0.5 * float(dynasty_house_ids(root_id).size() - 1)
	if has_mythos(root_id, "Blood of Kings"):
		gain += 1.0
	if has_legacy(root_id, "Chronicled Deeds"):
		gain *= 1.25
	return gain


func _renown_tick() -> void:
	for dyn: Dynasty in dynasties.values():
		if root_house_id(dyn.id) == dyn.id:
			dyn.renown += renown_gain(dyn.id)
	# the Mythos file keeps count of years on the throne
	for realm: Realm in realms:
		if realm.ruler_id < 0:
			continue
		var root := root_house_id(characters[realm.ruler_id].dynasty_id)
		dynasties[root].crown_months += 1
		if dynasties[root].crown_months >= CROWN_MONTHS_THRESHOLD:
			_earn_mythos(root, "Blood of Kings")


func buy_legacy(root_id: int, key: String) -> String:
	var dyn: Dynasty = dynasties[root_id]
	if dyn.legacies.has(key):
		return "The dynasty already holds this legacy."
	# a house cannot both charter the blending and forswear it
	var excludes := str(LEGACIES[key].get("excludes", ""))
	if excludes != "" and dyn.legacies.has(excludes):
		return "The dynasty already holds %s — the two cannot coexist." % excludes
	var cost: float = LEGACIES[key]["cost"]
	if dyn.renown < cost:
		return "Not enough Renown — %d needed." % int(cost)
	dyn.renown -= cost
	dyn.legacies.append(key)
	_log("[b]%s claims a legacy: %s.[/b] %s." % [dyn.name, key, LEGACIES[key]["blurb"]])
	# a line that forswears the blending — and has never practiced it —
	# may claim the name for it (v1.0: "available on request")
	if key == "The Preserving Line" and dyn.cross_race_marriages == 0:
		_earn_mythos(root_id, "Pure of Blood")
	return ""


# --- cadet branches ---

func can_found_cadet(c: SimCharacter) -> String:
	## Empty string = eligible. Splitting takes a grown, married man with
	## an heir of his own, from a house big enough to survive losing him.
	if not c.alive or c.is_female or c.is_bastard or c.denounced:
		return "Only a trueborn man of the house may found a branch."
	if c.age_years(tick) < ADULT_AGE:
		return "Too young."
	var head := house_head(c.dynasty_id)
	if head != null and head.id == c.id:
		return "The head of the house does not leave it."
	if is_ruler(c.id):
		return "A crowned head founds no cadet branch — the house follows the crown."
	if c.spouse_id < 0 or not characters[c.spouse_id].alive:
		return "A branch needs a wife to grow from."
	var has_child := false
	for kid in c.children_ids:
		if characters[kid].alive:
			has_child = true
	if not has_child:
		return "A branch without children is a dead twig."
	if house_members(c.dynasty_id).size() < 6:
		return "The house is too small to divide."
	return ""


func charter_allowed(c: SimCharacter, charter: String) -> String:
	## Each charter has its own legal bar (the doc's Charter Typology).
	var root := root_house_id(c.dynasty_id)
	var head := dynasty_head(root)
	match charter:
		"loyalist":
			if head != null and opinion_of(c.id, head.id) < 0:
				return "A loyalist charter needs goodwill toward the dynasty head."
		"coequal":
			if dynasties[root].renown < 200.0:
				return "A co-equal split needs a dynasty rich in renown — 200 or more."
		"schismatic":
			if head != null and opinion_of(c.id, head.id) >= 0 and not c.aggrieved:
				return "A schismatic house is born of a grievance — and they hold none."
		_:
			return "No such charter."
	return ""


func found_cadet_branch(char_id: int, charter: String = "loyalist") -> String:
	if not characters.has(char_id):
		return "No such person."
	var c: SimCharacter = characters[char_id]
	var why := can_found_cadet(c)
	if why != "":
		return why
	why = charter_allowed(c, charter)
	if why != "":
		return why
	var old_house: Dynasty = dynasties[c.dynasty_id]
	var old_root := root_house_id(c.dynasty_id)
	var dyn := Dynasty.new(dynasties.size(), _cadet_name(c))
	dyn.parent_id = old_house.id
	dyn.founder_id = c.id
	dyn.charter = charter
	dynasties[dyn.id] = dyn
	# the founder and his living descendants (by the male line) follow him
	var moved := _move_line_to_house(c, old_house.id, dyn.id)
	match charter:
		"loyalist":
			dynasties[old_root].renown += 20.0  # the tree spreads, the name carries
			_log("[b]A cadet branch is born:[/b] %s splits from %s under a loyalist charter — %d kin follow %s." % [
				dyn.name, old_house.name, moved, full_name(c)])
		"coequal":
			dynasties[old_root].renown -= 100.0
			dyn.renown = 100.0  # the endowment travels with them
			_log("[b]A co-equal split:[/b] %s parts from %s as an equal, endowed and owing nothing — %d kin follow %s. Let the houses race for glory." % [
				dyn.name, old_house.name, moved, full_name(c)])
		"schismatic":
			blood_feuds.append([old_root, dyn.id])
			var head := dynasty_head(old_root)
			if head != null:
				add_memory(c, "the house that wronged me", head.id, -50.0, 0.5)
				add_memory(head, "the traitor branch", c.id, -50.0, 0.5)
			_log("[b]SCHISM![/b] %s tears itself from %s — a Blood Feud is sworn that will outlive every soul now living. %d kin follow %s into exile." % [
				dyn.name, old_house.name, moved, full_name(c)])
	return ""


func _move_line_to_house(c: SimCharacter, from_house: int, to_house: int) -> int:
	if c.dynasty_id != from_house:
		return 0
	c.dynasty_id = to_house
	var moved := 1
	for kid_id in c.children_ids:
		var kid: SimCharacter = characters[kid_id]
		if kid.alive:
			moved += _move_line_to_house(kid, from_house, to_house)
	return moved


func _cadet_name(founder: SimCharacter) -> String:
	if founder.realm_id == 1:
		return "House %sović" % founder.name
	return "House %sson" % founder.name


func _cadet_branch_tick() -> void:
	## Ambitious younger sons strike out on their own without being asked.
	## A man with a grievance against his own head splits in anger.
	for c in characters.values():
		if not c.alive or c.is_female or is_cast(c):
			continue
		if can_found_cadet(c) != "":
			continue
		var chance := 0.002
		if c.traits.has("Ambitious"):
			chance += 0.006
		if rng.randf() < chance:
			var charter := "loyalist"
			var head := dynasty_head(root_house_id(c.dynasty_id))
			var bitter: bool = c.aggrieved or (head != null and opinion_of(c.id, head.id) < 0)
			if bitter and (c.traits.has("Wrathful") or c.traits.has("Ambitious")):
				charter = "schismatic"
			if charter_allowed(c, charter) != "":
				charter = "loyalist"
				if charter_allowed(c, charter) != "":
					continue
			var _e := found_cadet_branch(c.id, charter)
			return  # one split a month at most


# --- dynasty head powers ---

func _power_check(root_id: int, power: String) -> String:
	if dynasty_head(root_id) == null:
		return "The dynasty has no head."
	if dynasties[root_id].renown < POWER_COST[power]:
		return "Not enough Renown — %d needed." % int(POWER_COST[power])
	return ""


func dh_disinherit(root_id: int, target_id: int) -> String:
	var why := _power_check(root_id, "disinherit")
	if why != "":
		return why
	var head := dynasty_head(root_id)
	if not characters.has(target_id):
		return "No such person."
	var t: SimCharacter = characters[target_id]
	if not t.alive or root_house_id(t.dynasty_id) != root_id:
		return "They are not of this dynasty."
	if t.id == head.id:
		return "The head cannot cast out himself."
	if t.disinherited:
		return "They are already cast out."
	dynasties[root_id].renown -= POWER_COST["disinherit"]
	t.disinherited = true
	dynasties[root_id].kin_cruelty += 1
	if dynasties[root_id].kin_cruelty >= KIN_CRUELTY_THRESHOLD:
		_earn_mythos(root_id, "Kin-Eater")
	add_memory(t, "cast out of the succession", head.id, -60.0, 1.0)
	if head.traits.has("Compassionate"):
		add_stress(head, 20.0, "casting out my own blood")
	_log("[b]%s is disinherited[/b] — %s strikes them from the line of succession." % [
		full_name(t), full_name(head)])
	return ""


func dh_legitimize(root_id: int, target_id: int) -> String:
	var why := _power_check(root_id, "legitimize")
	if why != "":
		return why
	var head := dynasty_head(root_id)
	if not characters.has(target_id):
		return "No such person."
	var t: SimCharacter = characters[target_id]
	if not t.alive or root_house_id(t.dynasty_id) != root_id:
		return "They are not of this dynasty."
	if not t.is_bastard:
		return "They are trueborn already."
	dynasties[root_id].renown -= POWER_COST["legitimize"]
	t.is_bastard = false
	add_memory(t, "raised to trueborn", head.id, 40.0, 0.5)
	# trueborn siblings do not thank you for a new rival in the line
	if t.father_id >= 0:
		for sib_id in characters[t.father_id].children_ids:
			var sib: SimCharacter = characters[sib_id]
			if sib.alive and sib.id != t.id and not sib.is_bastard and sib.age_years(tick) >= ADULT_AGE:
				add_memory(sib, "a bastard raised above me", t.id, -30.0, 1.5)
	_log("[b]%s is legitimized[/b] by the word of %s — trueborn now, with a place in the line." % [
		full_name(t), full_name(head)])
	return ""


func dh_denounce(root_id: int, target_id: int) -> String:
	var why := _power_check(root_id, "denounce")
	if why != "":
		return why
	var head := dynasty_head(root_id)
	if not characters.has(target_id):
		return "No such person."
	var t: SimCharacter = characters[target_id]
	if not t.alive or root_house_id(t.dynasty_id) != root_id:
		return "They are not of this dynasty."
	if t.id == head.id:
		return "The head cannot denounce himself."
	if t.denounced:
		return "They are already denounced."
	dynasties[root_id].renown -= POWER_COST["denounce"]
	t.denounced = true
	dynasties[root_id].kin_cruelty += 1
	if dynasties[root_id].kin_cruelty >= KIN_CRUELTY_THRESHOLD:
		_earn_mythos(root_id, "Kin-Eater")
	add_memory(t, "denounced before the world", head.id, -50.0, 1.0)
	# stripped of every office on the spot
	for realm: Realm in realms:
		for seat in COUNCIL_SEATS:
			if int(realm.council.get(seat, -1)) == t.id:
				realm.council.erase(seat)
	for a: Army in armies:
		if a.commander_id == t.id:
			a.commander_id = -1
	_log("[b]%s is denounced[/b] as a criminal of the house — stripped of office, shunned by all." % full_name(t))
	return ""


func dh_call_to_war(root_id: int) -> String:
	var why := _power_check(root_id, "call_to_war")
	if why != "":
		return why
	var head := dynasty_head(root_id)
	if not at_war:
		return "The realm is at peace — there is no war to call the dynasty to."
	dynasties[root_id].renown -= POWER_COST["call_to_war"]
	var host := muster_army(head.realm_id)
	var houses := dynasty_house_ids(root_id)
	for hid in houses:
		host.regiments.append({"kind": "sword", "soldiers": 36, "max": 36})
	_log("[b]%s calls the dynasty to war![/b] %d house%s send their sworn swords." % [
		full_name(head), houses.size(), "" if houses.size() == 1 else "s"])
	return ""


# --- wills & bequests ---

func grant_bequest(realm_id: int, target_id: int) -> String:
	## The doc's Will Customization Protocol, distilled: buy a younger
	## son's peace while you live. The ambitious may take the gold and
	## nurse the grievance anyway — and you will not know until the feast.
	var realm: Realm = realms[realm_id]
	if realm.ruler_id < 0:
		return "There is no ruler to write a will."
	var ruler: SimCharacter = characters[realm.ruler_id]
	if not characters.has(target_id):
		return "No such person."
	var t: SimCharacter = characters[target_id]
	if not t.alive or not ruler.children_ids.has(t.id):
		return "Bequests go to the ruler's living children."
	var heir := heir_of(realm_id)
	if heir != null and heir.id == t.id:
		return "The heir needs no bequest — the realm is theirs."
	if t.age_years(tick) < ADULT_AGE:
		return "Too young to bargain over a crown."
	if t.bought_off:
		return "Their portion is already settled."
	if realm.gold < 150.0:
		return "A bequest worth taking costs 150 gold."
	realm.gold -= 150.0
	t.stress = maxf(0.0, t.stress - 10.0)
	var refuse_chance := 0.15
	if t.traits.has("Ambitious"):
		refuse_chance += 0.45
	if t.traits.has("Content"):
		refuse_chance -= 0.15
	if rng.randf() < refuse_chance:
		# the hidden "Aggrieved Claimant" flag of the doc — the gold is
		# taken, the grievance is kept, and the chronicle only hints at it
		t.aggrieved = true
		add_memory(t, "bought with a purse", ruler.id, -20.0, 1.0)
		_log("%s takes the purse coldly. Gold is not a crown." % full_name(t))
	else:
		t.bought_off = true
		t.aggrieved = false
		add_memory(t, "provided for in the will", ruler.id, 40.0, 0.5)
		_log("%s is content with their portion — they will not rise when the crown passes." % full_name(t))
	return ""


func _ai_dynasty() -> void:
	## Sarova's ruling dynasty spends its Renown on legacies by itself.
	var ruler_id: int = realms[1].ruler_id
	if ruler_id < 0 or rng.randf() > 0.1:
		return
	var root := root_house_id(characters[ruler_id].dynasty_id)
	var dyn: Dynasty = dynasties[root]
	for key in LEGACIES:
		if not dyn.legacies.has(key) and dyn.renown >= float(LEGACIES[key]["cost"]):
			var _e := buy_legacy(root, key)
			return


# ---------------------------------------------------------------- helpers

func full_name(c: SimCharacter) -> String:
	var dyn: Dynasty = dynasties[c.dynasty_id]
	return "%s %s" % [c.name, dyn.surname()]


func date_string() -> String:
	# tick 0 = "Year 0, Month 1 of the Silence" (the Night of the Third Hour);
	# tick 72 = "Year 6, Month 1" — the canonical present of the TTRPG.
	return "Year %d, Month %d of the Silence" % [TICK_ZERO_YEAR + floori(tick / 12.0), tick % 12 + 1]


func _log(text: String) -> void:
	event_logged.emit("[color=#909090]%s[/color]  %s" % [date_string(), text])


# ================================================================
# CANON PASS ONE — scale, the famine, and the Iron Wren
# (Opus's Fable Brief Pass One v1.1, 2026-07-15)
# ================================================================

func famine_rate(years: float) -> float:
	## The corrected curve (Architect's Number v2.0): a single logistic,
	## Year 1 = 0.36%/yr, Year 6 = 1.50%/yr, plateau 2.00%/yr (Justin's
	## ruling, 2026-07-14). Returns the annual mortality fraction. The
	## deceleration is load-bearing: the world does not die, it
	## stabilizes at a permanently diminished level. Nothing is undone;
	## the diminishment becomes the new normal.
	return CanonData.FAMINE_PLATEAU / (1.0 + CanonData.FAMINE_SHAPE_A * exp(-CanonData.FAMINE_SHAPE_R * years))


func famine_year() -> int:
	## The famine ledger's year index: ticks 1..12 are Year 1 (the first
	## year of the Silence), ticks 61..72 are Year 6 — so the campaign's
	## opening present arrives with six completed lines in the ledger.
	return floori((tick - 1) / 12.0) + 1 if tick >= 1 else 0


func _seed_population() -> void:
	## Pass One §1: 110 million souls distributed across 60 provinces by
	## settlement tier and regional archetype (CanonData). Deterministic
	## arithmetic — no dice; the map never rolls for its people. The
	## distribution below the canon total is design, flagged for Justin.
	grng.seed = 66  # one in sixty-six — the Year Six mortality
	var weights: Array = []
	var total_w := 0.0
	for p in map.provinces:
		var base: float = float(CanonData.REGION_POP_BASE.get(p.cultural_region, 800_000))
		var w: float = base * float(CanonData.TERRAIN_POP_MULT.get(p.terrain, 1.0))
		if CanonData.SETTLEMENT_POP.has(p.name):
			w += float(CanonData.SETTLEMENT_POP[p.name]) * CanonData.HINTERLAND_MULT
		weights.append(w)
		total_w += w
	var assigned := 0
	var biggest_pid := 0
	var biggest_w := 0.0
	for p in map.provinces:
		var share: float = float(weights[p.id]) / total_w
		var pop_i := int(floor(share * float(CanonData.CONTINENTAL_POP) / 1000.0)) * 1000
		p.pop = pop_i
		assigned += pop_i
		if float(weights[p.id]) > biggest_w:
			biggest_w = float(weights[p.id])
			biggest_pid = p.id
	# the rounding remainder settles on the primate city, per convention
	map.provinces[biggest_pid].pop += CanonData.CONTINENTAL_POP - assigned
	# The Architect's forecast, generated at setup from the same formula
	# the ledger runs on. He ran this arithmetic six years before the
	# campaign opens and never had cause to revise it. He priced out
	# thirty-four years he will never see: the forecast runs to Year 40;
	# he dies at Month 72. That gap is the module's point.
	for y in range(1, CanonData.FORECAST_YEARS + 1):
		architect_forecast[y] = int(round(famine_rate(float(y)) * float(CanonData.CONTINENTAL_POP)))
	_log("The census the Magistocracy will never take: a hundred and ten million people under a silent sky, most of them a season's failed harvest from the edge. In the Records Sublevel, a forecast table already exists for all of them.")


func province_famine_weight(p) -> float:
	## Pass One §2.4: famine is not uniform. Development (tax proxy),
	## control, war state, terrain archetype, entity pressure (Pass Two's
	## feedback loop), and open granaries all bend a province's share.
	## All multipliers are INVENTED PARAMETERS, flagged; the continental
	## total is renormalized so the canon curve holds regardless.
	var dev_mitigation: float = clampf((p.tax - 1.2) / 2.0 * 0.5, 0.0, 0.5)
	var w: float = float(p.pop) * (1.0 - dev_mitigation)
	if p.owner < 0:
		w *= 1.25  # no one distributes food to unclaimed land
	if occupied.has(p.id) or partisans.has(p.id):
		w *= 1.5   # a province under the sword cannot distribute anything
	var war_mult := 1.0
	if sieges.has(p.id):
		war_mult = 2.5
	elif int(scorched.get(p.id, -1)) > tick:
		war_mult = 2.0
	elif int(salted.get(p.id, -1)) > tick:
		war_mult = 1.6
	w *= war_mult
	w *= float(CanonData.FAMINE_TERRAIN.get(p.terrain, 1.0))
	w *= 1.0 + 0.05 * float(mini(int(province_anchors.get(p.id, 0)), 6))  # the Shade makes the road worse
	if int(famine_relief.get(p.id, -1)) > tick:
		w *= 0.5   # open granaries: the only argument the curve listens to
	return w


func _famine_tick() -> void:
	## The moral clock. Auto-fire touches ONLY the famine ledger and the
	## province population counters — never live realms' gold, tyranny,
	## prestige, or opinions. The raw number is never a headline: it is
	## written in the Records Sublevel, beside a forecast that agrees.
	var fy := famine_year()
	if fy < 1:
		return
	var rate_y := famine_rate(float(fy)) if fy <= CanonData.FORECAST_YEARS else famine_rate(float(CanonData.FORECAST_YEARS))
	var quota := rate_y * float(CanonData.CONTINENTAL_POP) / 12.0
	var total_w := 0.0
	var w_by_pid := {}
	for p in map.provinces:
		if p.silence_touched or p.pop <= 0:
			continue  # the Ashfields hunger belongs to Caeris's ledger (srng)
		var w := province_famine_weight(p)
		w_by_pid[p.id] = w
		total_w += w
	if total_w <= 0.0:
		return
	for p in map.provinces:
		if not w_by_pid.has(p.id):
			continue
		var deaths_f: float = quota * float(w_by_pid[p.id]) / total_w + float(famine_carry.get(p.id, 0.0))
		var deaths := int(floor(deaths_f))
		famine_carry[p.id] = deaths_f - float(deaths)
		if deaths <= 0:
			continue
		deaths = mini(deaths, p.pop)
		p.pop -= deaths
		famine_deaths_total += deaths
		famine_deaths_year += deaths
		var before: int = int(famine_dead_by_pid.get(p.id, 0))
		famine_dead_by_pid[p.id] = before + deaths
		# the player-facing surface is domestic, not statistical: villages
		var v_before := before / CanonData.VILLAGE_SOULS
		var v_after := int(famine_dead_by_pid[p.id]) / CanonData.VILLAGE_SOULS
		if v_after > v_before:
			villages_emptied += v_after - v_before
			# Pass Two wiring: an emptied village is an untended shrine, a
			# well nobody draws from, a crossroads nobody sweeps — vacancy.
			province_vacancies[p.id] = float(province_vacancies.get(p.id, 0.0)) + float(v_after - v_before)
			if villages_emptied % 25 == 1 and p.owner == 0:
				raise_event(0, realms[0].ruler_id, "The Village That Stopped Writing",
					"The tax roll for a village in %s comes back marked 'no return'. The rider who carried it says the shutters are latched from outside, the well-rope is gone, and the shrine step is unswept. Nobody died there this month. Nobody lives there either." % p.name,
					[{"label": "Note it in the provincial record", "base": 3.0, "ai": {"stewardship": 0.5}},
					{"label": "Send no one — the roads eat riders now", "base": 2.0, "ai": {"caution": 0.5}}],
					false, false, false, false, false, true)
	# the year closes: the actual is written beside the forecast, and
	# the two columns agree. That is the horror, and it is visible.
	if tick % 12 == 0 and tick > 0:
		famine_actual_by_year[fy] = famine_deaths_year
		var fc: int = int(architect_forecast.get(fy, 0))
		if fc > 0:
			var drift := 0.0 if fc == 0 else absf(float(famine_deaths_year - fc)) / float(fc)
			if drift < 0.02:
				_log("The Records Sublevel closes the year: %s dead of hunger, against a forecast of %s written six years before the first of them missed a meal. The columns agree." % [_fmt_count(famine_deaths_year), _fmt_count(fc)])
			elif famine_deaths_year < fc:
				_log("The Records Sublevel closes the year: %s dead of hunger, against a forecast of %s. The actual runs BELOW the old man's arithmetic — somewhere, someone kept people fed he had already counted." % [_fmt_count(famine_deaths_year), _fmt_count(fc)])
			else:
				_log("The Records Sublevel closes the year: %s dead of hunger, against a forecast of %s. The actual runs above the forecast. The wars were not in his arithmetic." % [_fmt_count(famine_deaths_year), _fmt_count(fc)])
		famine_deaths_year = 0


func open_granaries(realm_id: int, pid: int) -> String:
	## The exception, and it is the point: player-initiated famine action
	## MAY touch the player's own realm. A ruler who opens the stores is
	## bending their own history — the only act in the game that proves
	## the Architect's forecast wrong about something.
	if pid < 0 or pid >= map.provinces.size():
		return "No such province."
	var p = map.provinces[pid]
	if p.owner != realm_id:
		return "The granaries there are not the crown's to open."
	var realm: Realm = realms[realm_id]
	if realm.gold < 30.0:
		return "Opening the stores costs 30 gold — carters, guards, and the grain itself."
	if int(famine_relief.get(pid, -1)) > tick:
		return "The stores already stand open there."
	realm.gold -= 30.0
	famine_relief[pid] = tick + 12
	_log("[b]The granaries of %s stand open.[/b] For a year, the crown's grain moves down roads the tax normally travels up. It will not show in any headline. It will show in the Records Sublevel, as a number smaller than a dead man predicted." % p.name)
	return ""


func famine_records_lines() -> String:
	## The Records Sublevel readout: the only place in Khessar where the
	## number is written down. Forecast and actual, side by side.
	var fy := famine_year()
	if fy < 1:
		return ""
	var lines := "The famine ledger (Records Sublevel) — Year %d of the Silence:" % fy
	var y0 := maxi(1, fy - 2)
	for y in range(y0, fy):
		if famine_actual_by_year.has(y):
			lines += "\n  Year %d — forecast %s · recorded %s" % [y,
				_fmt_count(int(architect_forecast.get(y, 0))), _fmt_count(int(famine_actual_by_year[y]))]
	lines += "\n  Year %d — forecast %s · recorded %s, and the year is not done" % [fy,
		_fmt_count(int(architect_forecast.get(fy, 0))), _fmt_count(famine_deaths_year)]
	if villages_emptied > 0:
		lines += "\n  Villages that stopped answering the tax roll: %d" % villages_emptied
	return lines


func _fmt_count(n: int) -> String:
	## 1650000 -> "1,650,000" — the ledger writes its figures properly.
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


func continental_pop_now() -> int:
	var total := 0
	for p in map.provinces:
		total += p.pop
	return total


# ------------------------------------------------------------ the Iron Wren

# The historical seven: the strike ticks are canon-pinned (seven tokens
# by Year Six is the brief's fixed fact — the past is a ledger, not a
# die). WHICH of the six unnamed anchor-mages dies in which season is
# hers to decide, on her own stream. From tick 72 the cycle runs live.
const WREN_HISTORICAL_STRIKES := [18, 27, 36, 45, 54, 63, 71]
const WREN_VETRAL_THRESHOLD := 60.0
const WREN_TOKEN_THRESHOLD := 85.0


func _seed_wren() -> void:
	wrng.seed = 47  # the forty-seven trees at Vetral
	anchor_mages = {}
	for key in CanonData.ANCHOR_MAGES:
		var src: Dictionary = CanonData.ANCHOR_MAGES[key]
		anchor_mages[key] = {"name": src["name"], "house": src["house"], "age": int(src["age"]),
			"pid": int(src["pid"]), "working": src["working"], "records": float(src["records"]),
			"note": src["note"], "alive": true, "cultivated_by": -1, "cultivate_pid": -1,
			"cultivate_until": -1, "shielded": false, "warned": false}
	# She is twelve, in Vetral, and the map does not know her name yet.
	# She is NOT a hero and NOT a character: no census entry, no court,
	# no diplomatic surface. An independent map-actor on her own ledger.


func wren_age() -> int:
	return 12 + floori(tick / 12.0)  # born Year -12: twelve at Year Zero, eighteen at Year Six


func _wren_tick() -> void:
	if not wren_alive:
		return
	# Year One: the grove. The Silence was the catalyst — it removed the
	# compacts restraining him. Forty-seven trees, and one twelve-year-old
	# the working missed because she was at the well before light.
	if not wren_active:
		if tick == 12:
			_log("[b]Vetral is a grove now.[/b] The green-wizard Sark, unrestrained since the compacts stopped answering, paid a working's cost with a village on the Salt Road margins: forty-seven people, forty-seven trees, bark where the mouths were. The Magistocracy files it under 'regional incident'. The Iron Library files the names. One name is missing from both lists — a girl nobody counted, who was at the well before light.")
		if tick == 14:
			wren_active = true
			wren_target = "sark"
			wren_study_months = 0
			wren_study_needed = 4
			_log("West of Vetral, a small quiet girl watches a tower for four months and learns when its master sleeps. The Iron Library will eventually record her as Wren Callister. The tellers will call her something else.")
		return
	# the historical seven: schedule-driven, canon-pinned
	if wren_tokens < 7:
		# THE MAGISTOCRACY'S REQUEST: Section Three's file on her grows,
		# and its interest is not benevolent. Both answers are ledger-only
		# here; the mechanical compliance is assist_hunt_wren, a council act.
		if tick == 40:
			raise_event(0, realms[0].ruler_id, "The Magistocracy's Request",
				"Section Three requests provincial cooperation in locating 'the Vetral irregular' — road-warden rosters, ferry manifests, the usual apparatus. The file is thicker than five dead mages should make it. Somebody upstairs is reading ahead. (Full compliance — wardens and coin — is a council action, if the crown wants her found.)",
				[{"label": "Note the request; share the rosters", "base": 2.5, "ai": {"scheming": 0.4},
					"effect": func() -> void:
						wren_obstruction[0] = int(wren_obstruction.get(0, 0)) + 1
						_log("The rosters go to Section Three. Somewhere west, a rider notices the checkpoints asking new questions, and adds a name to a list kept in no office.")},
				{"label": "Lose the request in the registry", "base": 3.0, "ai": {"caution": 0.4},
					"effect": func() -> void:
						_log("The request is filed under a heading nobody will think to search. The crown owes the rider nothing. The crown would simply rather not be on her list.")}],
				false, false, false, false, false, false, true)
		# Section Three leaves a file where she will find it — a Forsaken
		# organizer they would like removed. The refusal is characterizing.
		if tick == 58:
			_log("In a waystation west of Vael, a file is left where the small rider will find it: a Forsaken organizer, meetings mapped, habits noted, and payment offered in Sarkenvault records. She reads it twice, which is once more than she needed. The organizer is not an anchor-mage. The line is at the anchoring. She leaves the file squared to the table's edge, refused, and Section Three learns something about her that worries them more than the tokens.")
		if tick in WREN_HISTORICAL_STRIKES and wren_target != "":
			_wren_strike()
			if wren_tokens < 7:
				_wren_pick_target(true)
		return
	# Section Three leaves a file where she will find it (tick 58 handled
	# in the historical window; from here the live cycle runs)
	if tick < wren_rest_until:
		return
	if wren_target == "" or not bool(anchor_mages.get(wren_target, {}).get("alive", false)):
		_wren_pick_target(false)
		if wren_target == "":
			_wren_unmaking_tick()
			return
	wren_study_months += 1
	if wren_study_months >= wren_study_needed:
		_wren_strike()
		wren_target = ""
		wren_rest_until = tick + 3 + wrng.randi_range(0, 3)
	_wren_unmaking_tick()


func _wren_pick_target(historical: bool) -> void:
	## Hidden priority list, weighted by proximity (the Salt Road and its
	## margins), personal priority (Sarkenvault highest — Sark was her
	## first; his family is personal), and knowledge value (the Ossrel
	## ledger and the Vanneth records are the two most valuable objects
	## on the continent, to her). The hard constraint lives in the pool
	## itself: the list holds anchor-mages and nothing else, ever.
	var best := ""
	var best_score := -INF
	for key in anchor_mages:
		var m: Dictionary = anchor_mages[key]
		if not bool(m["alive"]):
			continue
		if historical and not str(key).begins_with("um_"):
			continue  # the first six after Sark are the unnamed roster — the named masters keep until Year Six
		var p = map.provinces[int(m["pid"])]
		if int(wren_avoid_realm.get(p.owner, -1)) > tick:
			continue
		var score: float = float(m["records"]) / 10.0
		if str(m["house"]) == "sarkenvault":
			score += 3.0
		if int(m["pid"]) == wren_region_pid:
			score += 1.0
		elif wren_region_pid >= 0 and map.provinces[wren_region_pid].neighbors.has(int(m["pid"])):
			score += 0.5
		var cult_realm := int(m["cultivated_by"])
		if cult_realm >= 0 and int(wren_obstruction.get(cult_realm, 0)) >= 3:
			score += 2.0  # obstruction: the obstructor's assets die at inconvenient moments
		if bool(m["shielded"]):
			score -= 1.5
		score += wrng.randf() * 0.5
		if score > best_score:
			best_score = score
			best = key
	wren_target = best
	if best == "":
		return
	var mage: Dictionary = anchor_mages[best]
	wren_study_months = 0
	if historical:
		wren_study_needed = 999  # the schedule strikes, not the counter
	else:
		wren_study_needed = 10 + wrng.randi_range(0, 4)  # the named masters keep guards
		if bool(mage["shielded"]):
			wren_study_needed += 6
		if bool(mage["warned"]):
			wren_study_needed += 3
	# THE HUNTER ARRIVES: a small hooded rider asking precise questions,
	# a mage growing nervous. Options are informational — the mechanical
	# answers (shield, warn, cultivate) are council actions, not clicks.
	var tp = map.provinces[int(mage["pid"])]
	if tp.owner == 0:
		raise_event(0, realms[0].ruler_id, "A Hooded Rider Asks Precise Questions",
			"In %s, a small rider on a bay mare with a white star has spent a week asking after %s — deliveries, habits, the hours the tower's lamps burn. She pays for her answers, listens more than she asks, and rides on before anyone thinks to hold her. %s has begun declining invitations. (The council may shield the mage, warn them quietly, or leave the road to its business.)" % [tp.name, str(mage["name"]), str(mage["name"])],
			[{"label": "Note it and watch the road", "base": 3.0, "ai": {"caution": 0.5}},
			{"label": "The road knows its own business", "base": 2.5, "ai": {"scheming": 0.3}}],
			false, false, false, false, false, false, true)


func _wren_strike() -> void:
	## Study -> strike. She wins by learning a target's guards and habits
	## and striking once, when the cost of their own magic has left them
	## spent. A successful strike removes the anchor-mage as an actor.
	if wren_target == "" or not anchor_mages.has(wren_target):
		return
	var mage: Dictionary = anchor_mages[wren_target]
	mage["alive"] = false
	wren_tokens += 1
	wren_unmaking += float(mage["records"])
	wren_region_pid = int(mage["pid"])
	var p = map.provinces[int(mage["pid"])]
	_log("[b]%s is found dead in %s[/b] — no wound anyone can name, the working-room cold, the ledgers gone. On the road west a rider carves something small from iron, and now there are %d. Somewhere the tellers add a verse." % [str(mage["name"]), p.name, wren_tokens])
	# THE MAGE YOU WERE CULTIVATING: the asset is gone; the capability
	# with it. The suppression her target was holding for you ends now.
	if int(mage["cultivated_by"]) == 0:
		var cp := int(mage["cultivate_pid"])
		if cp >= 0:
			mage["cultivate_until"] = -1
		raise_event(0, realms[0].ruler_id, "The Mage You Were Cultivating",
			"%s is dead, and with them the arrangement nobody wrote down. The district they were quieting will notice by spring. Somewhere a girl with seven iron tokens did not ask whose asset they were — the line was at the anchoring, and they were over it." % str(mage["name"]),
			[{"label": "The ledger closes — let it", "base": 3.0, "ai": {"caution": 0.5}},
			{"label": "Open a file on the rider", "base": 2.0, "ai": {"scheming": 0.6}}],
			false, false, false, false, false, false, true)
	# THE ACCIDENTAL ALLY: if the crown was besieging the same ground she
	# struck on, the two of them briefly wanted the same thing. She does
	# not thank anyone. She does not stay.
	if sieges.has(int(mage["pid"])) and int(sieges[int(mage["pid"])]["attacker"]) == 0:
		_log("The siege lines at %s report the tower inside went dark before the walls came down. Nobody on the ration books did it. She does not thank the crown. She does not stay." % p.name)
	# obstruction, spent: killing an obstructor's asset resets the ledger a step
	var cr := int(mage["cultivated_by"])
	if cr >= 0 and int(wren_obstruction.get(cr, 0)) >= 3:
		wren_obstruction[cr] = int(wren_obstruction[cr]) - 1


func _wren_unmaking_tick() -> void:
	## The long-campaign thread: she is not collecting tokens, she is
	## learning to READ in the direction no academy teaches — not to
	## cast, but to un-cast. The first attempt is Vetral. She will
	## probably fail. She knows the odds. She looks anyway.
	if not wren_vetral_attempted and wren_unmaking >= WREN_VETRAL_THRESHOLD:
		wren_vetral_attempted = true
		if wrng.randf() < 0.25:
			wren_vetral_outcome = "unmade"
			_log("[b]The grove at Vetral is a village again.[/b] Not the people — the working. Forty-seven trees stand down to forty-seven graves, which is not mercy, but it is TRUE, and true is what she had. The first un-making in recorded history was performed by someone no academy will ever claim, reading the old tongue backwards by lamplight. A small miracle, in a world starved of them.")
		else:
			wren_vetral_outcome = "failed"
			_log("[b]At Vetral, nothing happens.[/b] Six years of stolen craft-knowledge, three lineages' records, a working read backwards syllable by syllable through one whole night — and at dawn the forty-seven trees are still trees. She sits against the one that was the miller until the light comes up, then waters the mare and rides. The eighth token is still uncarved. She has not stopped.")
		return
	# THE EIGHTH WORKING IS THE CONSENT TOKEN (Secret Six): a coin-sized
	# piece of metal bound into the archive's foundation stone when the
	# bargain was signed — remove it and the Patron anchor's authorization
	# is VOIDED. Not destroyed: operationally vulnerable. Three people
	# know it exists. She is the third.
	if wren_vetral_attempted and wren_unmaking >= WREN_TOKEN_THRESHOLD and wren_token_retrieval == "":
		wren_token_retrieval = "scheduled"
		wren_token_tick = tick + 6
		_log("A reading-room clerk in the Vael archive later remembers a small woman who consulted the foundation-survey folios for nine days and asked nothing of anyone. The folios are two hundred years old. Three people alive know why they matter.")
	if wren_token_retrieval == "scheduled" and tick >= wren_token_tick:
		if patron_network_broken:
			wren_token_retrieval = "taken"
			_log("Beneath the archive she finds the foundation stone already cold — the anchor is ash, and the token in it is a coin again. She takes it anyway. Some ledgers you close even when someone else has burned them.")
			return
		if wrng.randf() < 0.5:
			wren_token_retrieval = "taken"
			patron_anchor_voided = true
			_log("[b]The eighth token.[/b] A coin-sized piece of metal, bound into the archive's foundation stone the year the bargain was signed, comes loose in a hand that has been working toward it for years. The Patron's primary anchor is not destroyed — it is UNAUTHORIZED. Whatever stands behind the Silence still stands; it now stands on paper nobody signed. Magister Vell Ondress will not notice the absence for months. The Architect would have noticed in a day, and the Architect is beyond noticing.")
		else:
			wren_token_retrieval = "driven_off"
			wren_token_tick = tick + 30
			wren_avoid_realm[0] = tick + 24
			wren_token_retrieval = "scheduled"
			_log("Section Three's night-wards catch an intruder two floors above the foundation vault. They catch, specifically, a cloak weighted to tear free, and keep it. She is gone west by morning, and the file on her grows a page. She will not abandon it. She has never abandoned anything since the well.")


func wren_offer_target(cid: int) -> String:
	## The hard constraints, as an API the world can test against: she
	## will not torture, will not harm the uninvolved, will not kill a
	## mage merely for being a mage. The line is at the ANCHORING —
	## paying a working's cost with other people's lives. Characters are
	## not on her list; only the anchor-mage roster is, ever.
	var c: SimCharacter = characters.get(cid)
	var who := full_name(c) if c != null else "the name in the file"
	return "She reads the file twice, which is once more than she needed. '%s is not an anchor-mage. The line is at the anchoring.' She leaves the file where it was left for her, squared to the table's edge, refused." % who


func shield_anchor_mage(realm_id: int, key: String) -> String:
	## Protect a monstrous but useful neighbor. She registers obstruction
	## — she does not declare war; she has no war to declare. She becomes
	## a low-grade disruption, and she can only be outlived.
	if realm_id != 0:
		return "Only the player's council shields."
	if not anchor_mages.has(key) or not bool(anchor_mages[key]["alive"]):
		return "There is no one there left to shield."
	var realm: Realm = realms[0]
	if realm.gold < 40.0:
		return "Doubled guards and warded locks cost 40 gold."
	realm.gold -= 40.0
	var mage: Dictionary = anchor_mages[key]
	mage["shielded"] = true
	if wren_target == key and wren_tokens >= 7:
		wren_study_needed += 6
	wren_obstruction[0] = int(wren_obstruction.get(0, 0)) + 1
	_log("The crown quietly doubles the watch around %s. Somewhere on the Salt Road, a rider adds the crown to a list that has no diplomatic surface." % str(mage["name"]))
	return ""


func warn_anchor_mage(realm_id: int, key: String) -> String:
	if realm_id != 0:
		return "Only the player's council warns."
	if not anchor_mages.has(key) or not bool(anchor_mages[key]["alive"]):
		return "The warning would reach a grave."
	var mage: Dictionary = anchor_mages[key]
	if bool(mage["warned"]):
		return "They have already been told. They did not sleep better."
	mage["warned"] = true
	if wren_target == key and wren_tokens >= 7:
		wren_study_needed += 3
	_log("A letter with no seal tells %s what is riding toward them. Mercy, of a kind — though the reader should ask what the mage did to earn the rider." % str(mage["name"]))
	return ""


func cultivate_anchor_mage(realm_id: int, key: String, pid: int) -> String:
	## The dual nature, and it is the design point: anchor-mages are Iron
	## Wren targets AND player assets. A debt-working quiets a district.
	## A player who uses them is cultivating monsters — and the rider is
	## coming for their assets. The district pays either way.
	if realm_id != 0:
		return "Only the player's council cultivates monsters."
	if not anchor_mages.has(key) or not bool(anchor_mages[key]["alive"]):
		return "That arrangement died with them."
	if pid < 0 or pid >= map.provinces.size() or map.provinces[pid].owner != 0:
		return "The working needs crown land to attach to."
	var realm: Realm = realms[0]
	if realm.gold < 50.0:
		return "The retainer — never written down — costs 50 gold."
	realm.gold -= 50.0
	var mage: Dictionary = anchor_mages[key]
	mage["cultivated_by"] = 0
	mage["cultivate_pid"] = pid
	mage["cultivate_until"] = tick + 24
	partisans.erase(pid)
	_log_covert(realm, "An arrangement nobody writes down: %s attaches a working to %s. The district grows quiet, and tired, and quieter. The crown has cultivated a monster, and monsters draw the rider." % [str(mage["name"]), map.provinces[pid].name])
	return ""


func assist_hunt_wren(realm_id: int) -> String:
	## THE MAGISTOCRACY'S REQUEST, answered: comply, and standing rises —
	## and an enemy is made of someone who does not forget. She cannot be
	## conquered. She relocates, and the file grows, and she remembers.
	if realm_id != 0:
		return "Section Three asks only its own crown."
	var realm: Realm = realms[0]
	if realm.gold < 25.0:
		return "Checkpoint rosters and road wardens cost 25 gold."
	realm.gold -= 25.0
	realm.prestige += 3.0
	wren_obstruction[0] = int(wren_obstruction.get(0, 0)) + 2
	wren_avoid_realm[0] = tick + 24
	_log("The crown lends Section Three its road wardens. For two years the small rider works other margins — and the crown's name moves up a list kept in no office. She does not declare war. She has no war to declare. She can only be outlived.")
	return ""


func wren_status_line() -> String:
	## The token counter is flavor and foreshadowing — surfaced somewhere
	## quiet, never a headline. An attentive player watches it climb and
	## understands that somewhere, another anchor-mage just died.
	if not wren_active:
		return ""
	if not wren_alive:
		return "The tellers' verses about the iron tokens have stopped growing."
	var s := "The tellers count %d iron tokens in the verses now." % wren_tokens
	if wren_vetral_outcome == "unmade":
		s += " The newest verse says Vetral is a village again."
	elif wren_vetral_outcome == "failed":
		s += " The newest verse is about a grove that stayed a grove."
	if patron_anchor_voided:
		s += " The eighth is not iron."
	return s


# ================================================================
# CANON PASS TWO — entity density, the Underneath, and the houses
# (Opus's Fable Brief Pass Two v1.0, 2026-07-14)
# ================================================================

func entity_ground(p) -> String:
	## Pass Two §1.3: which kind of lid the sky's maintenance left on
	## this ground. Ward-stone ground is BOTH better for faith AND worst
	## for entities — the lid still muffles the sky a little, and there
	## is something under it that has been counting. Deliberate (Rule
	## Two). The Ashfields return "" — that density has an author.
	if p.silence_touched:
		return ""
	if p.special_feature == "iron_library":
		return "library"
	if p.special_feature == "sealed_hold":
		return "wardstone"
	return str(CanonData.REGION_GROUND.get(p.cultural_region, "base"))


func _seed_entities() -> void:
	erng.seed = 60  # the sixty feet of a Shade's anchor-bond (47 is hers)
	# The deep passages are the proof case: divinely-sustained wards went
	# dark the night of the Silence, and the things behind them had been
	# paying attention to the maintenance schedule for forty years. They
	# were not asleep. They were counting.
	for p in map.provinces:
		if p.special_feature == "sealed_hold":
			province_vacancies[p.id] = 3.0
		elif p.ruined and p.cultural_region == "aurath":
			province_vacancies[p.id] = 1.5


func _entity_tick() -> void:
	## Deferred maintenance, not an awakening: nothing spawns, nothing
	## wakes. Entity density is a function of ABANDONMENT — vacancies are
	## produced by human failure, and anchors are vacancies claimed.
	## Auto-fire touches only the anchor ledger, density counters, and
	## vacancy counts. Realm 99's ground is excluded entirely.
	var orthodox_coherence := 1.0
	if faiths.has("Aelindran Orthodox"):
		orthodox_coherence = float(faiths["Aelindran Orthodox"]["coherence"])
	for p in map.provinces:
		var g := entity_ground(p)
		if g == "":
			continue
		# abandonment drips: burned fields, salted earth, decaying shrine
		# networks, provinces emptying past the point of recovery
		if int(scorched.get(p.id, -1)) > tick or int(salted.get(p.id, -1)) > tick:
			province_vacancies[p.id] = float(province_vacancies.get(p.id, 0.0)) + 0.05
		if g == "shrine_net" and orthodox_coherence < 0.4 and int(shrines_tended.get(p.id, -1)) <= tick:
			province_vacancies[p.id] = float(province_vacancies.get(p.id, 0.0)) + 0.02
	# unburied battlefields convert two months after the last cart leaves
	var to_convert: Array = []
	for pid in unburied_fields:
		if tick - int(unburied_fields[pid]["tick"]) >= 2:
			to_convert.append(pid)
	for pid in to_convert:
		var dead := int(unburied_fields[pid]["dead"])
		province_vacancies[pid] = float(province_vacancies.get(pid, 0.0)) + float(dead) / 1000.0
		unburied_fields.erase(pid)
		_log("The dead at %s were never buried, and the ground has noticed. Five thousand dead unburied is five thousand reasons for an anchor — these were fewer, and it only takes one." % map.provinces[pid].name)
	# claims: a vacancy becomes an anchor on an erng roll weighted by the
	# ground's pressure. Anchors do not un-claim on their own.
	for p in map.provinces:
		var g2 := entity_ground(p)
		if g2 == "":
			continue
		var v: float = float(province_vacancies.get(p.id, 0.0))
		if v < 1.0:
			continue
		var pressure: float = float(CanonData.ENTITY_PRESSURE_BY_GROUND.get(g2, 0.3))
		if erng.randf() < 0.015 * pressure * minf(v, 10.0):
			province_vacancies[p.id] = v - 1.0
			province_anchors[p.id] = int(province_anchors.get(p.id, 0)) + 1
			if int(province_anchors[p.id]) == 1:
				_log("Something has claimed the untended %s in %s. It is not new. It was always in the well; the gods were the maintenance schedule, and the schedule ended." % [
					"ward-gallery" if g2 == "wardstone" else "shrine" if g2 == "shrine_net" else "crossroads", p.name])
	# Volume II is the accumulation tier: ledgers that became bodies,
	# triggered on sustained unresolved tension — an appointment kept.
	if tick % 12 == 0 and tick > 0:
		_volume2_tick()


func _volume2_tick() -> void:
	var regions := {}
	for p in map.provinces:
		var region := str(p.cultural_region)
		if not regions.has(region):
			regions[region] = 0
		if at_war and (region == "vael" or region == "drevak_orc"):
			regions[region] = int(regions[region]) + 12
		var mv: Dictionary = forsaken_movements.get(region, {})
		if int(mv.get("stage", 0)) >= 2:
			regions[region] = int(regions[region]) + 6
		if int(province_anchors.get(p.id, 0)) >= 3:
			regions[region] = int(regions[region]) + 4
	for region in regions:
		regional_tension[region] = int(regional_tension.get(region, 0)) + int(regions[region])
		if int(regional_tension[region]) >= 240:
			var already := false
			for m in volume2_manifested:
				if str(m["region"]) == region:
					already = true
			if already:
				continue
			var vname := "the Grudge Manifest"
			if region == "aurath":
				vname = "the Pale Court, convening"
			volume2_manifested.append({"name": vname, "region": region, "tick": tick})
			_log("[b]An appointment is kept in the %s marches:[/b] %s — not a bigger monster, but an old ledger that has achieved singular form. Sixty years of catalogued grievance do not arrive suddenly. They arrive on time." % [region, vname])


func cleanse_anchor(realm_id: int, pid: int) -> String:
	## The counter-play, and why the module earns its place: for the old
	## things, destroying the anchor is the only permanent answer.
	if pid < 0 or pid >= map.provinces.size():
		return "No such province."
	var p = map.provinces[pid]
	if p.owner != realm_id:
		return "The crown cleanses its own ground first."
	if int(province_anchors.get(pid, 0)) <= 0:
		return "Nothing has claimed anything there — yet."
	var realm: Realm = realms[realm_id]
	if realm.gold < 25.0:
		return "Wardens, oil, and a mason to break the anchor cost 25 gold."
	realm.gold -= 25.0
	province_anchors[pid] = int(province_anchors[pid]) - 1
	_log("Wardens break the claimed anchor in %s — the old answer, and the only permanent one. What wore it must save or die, and either way it has nowhere to sit." % p.name)
	return ""


func resettle_province(realm_id: int, pid: int) -> String:
	if pid < 0 or pid >= map.provinces.size():
		return "No such province."
	var p = map.provinces[pid]
	if p.owner != realm_id:
		return "Settlers follow their own crown."
	var realm: Realm = realms[realm_id]
	if realm.gold < 40.0:
		return "Seed grain, roof-beams, and a year's remission cost 40 gold."
	if float(province_vacancies.get(pid, 0.0)) < 1.0:
		return "The villages there still answer the tax roll."
	realm.gold -= 40.0
	province_vacancies[pid] = maxf(0.0, float(province_vacancies.get(pid, 0.0)) - 3.0)
	_log("The crown reopens the emptied steads of %s — swept shrines, drawn wells, lamplight where the vacancy was. Occupied ground offers nothing to squat in." % p.name)
	return ""


func tend_shrines(realm_id: int, pid: int) -> String:
	if pid < 0 or pid >= map.provinces.size():
		return "No such province."
	var p = map.provinces[pid]
	if p.owner != realm_id:
		return "The shrines there keep other patrons."
	var realm: Realm = realms[realm_id]
	if realm.gold < 15.0:
		return "Lay tenders and lamp oil cost 15 gold."
	realm.gold -= 15.0
	shrines_tended[pid] = tick + 24
	_log("The crown pays lay hands to sweep and light the shrines of %s. Nobody answers the prayers. The POINT is the sweeping: a tended threshold is not a vacancy." % p.name)
	return ""


func bury_the_dead(realm_id: int, pid: int) -> String:
	if not unburied_fields.has(pid):
		return "The ground there holds no unburied field."
	var realm: Realm = realms[realm_id]
	if realm.gold < 10.0:
		return "Grave-details and quicklime cost 10 gold."
	realm.gold -= 10.0
	var dead := int(unburied_fields[pid]["dead"])
	unburied_fields.erase(pid)
	_log("The crown buries the dead at %s — %d of them, named where anyone knew the names. Battlefield anchors never form over a proper grave. The Gravewardens have been saying this for six years." % [map.provinces[pid].name, dead])
	return ""


func silence_reform_province() -> int:
	## The Silence itself is a Volume II living spell: reduced to zero it
	## disperses and REFORMS WHERE THE GODS' ABSENCE IS MOST FELT — the
	## highest faith-dampening deficit. The campaign as a stat block.
	var best_pid := -1
	var best_score := -INF
	for p in map.provinces:
		var g := entity_ground(p)
		if g == "":
			continue
		var missed: float = float(CanonData.ENTITY_PRESSURE_BY_GROUND.get(g, 0.3))
		var still_held := FAITH_DAMPENING_BASE
		if p.special_feature == "iron_library":
			still_held = FAITH_DAMPENING_LIBRARY
		elif g == "wardstone":
			still_held = FAITH_DAMPENING_WARDSTONE
		var score := missed - still_held
		if score > best_score:
			best_score = score
			best_pid = p.id
	return best_pid


func continental_anchors() -> int:
	var n := 0
	for pid in province_anchors:
		n += int(province_anchors[pid])
	return n


func entity_status_line() -> String:
	var anchors := continental_anchors()
	if anchors <= 0:
		return ""
	var worst_pid := -1
	var worst := 0
	for pid in province_anchors:
		if int(province_anchors[pid]) > worst:
			worst = int(province_anchors[pid])
			worst_pid = int(pid)
	var s := "Wardens' registry: %d claimed anchors on the continent" % anchors
	if worst_pid >= 0:
		s += " — the worst ground is %s (%d)" % [map.provinces[worst_pid].name, worst]
	if wardstone_linkage_known:
		s += ". The registry now understands WHY: the heaviest maintenance failed hardest."
	return s + "."


# ------------------------------------------------------------ the Underneath

func _seed_underneath() -> void:
	urng.seed = 12  # the twelve pact-families of the Hollow Decades
	criminal_orgs = {}
	for key in CanonData.CRIMINAL_ORGS:
		var src: Dictionary = CanonData.CRIMINAL_ORGS[key]
		criminal_orgs[key] = {"name": src["name"], "scope": src["scope"], "leader": src["leader"],
			"strength": float(src["strength"]), "tolerated": bool(src["tolerated"]), "note": src["note"]}
	cults = {}
	for key in CanonData.CULTS:
		var src2: Dictionary = CanonData.CULTS[key]
		cults[key] = {"name": src2["name"], "deity": src2["deity"], "leader": src2["leader"],
			"method": src2["method"], "strength": 4.0, "state": "gathering",
			"cell_formed": -1, "attempt_done": false, "prepared": false, "published": false}
	displaced = {"famine": 0, "war": 0, "ashfields": 0, "silence_touched": 0}


func _underneath_tick() -> void:
	## The criminal, poverty, and cult layer. Poverty is not a new
	## variable — it is the famine module and the existing scalars read
	## from below. What is new is the refugee flow, and what waits at the
	## end of it. Auto-fire: own ledgers only.
	_refugee_tick()
	_cult_tick()
	# organization drift: the Ash Vein feeds on a worsening Salt Road;
	# the Hidden Grain on every closed gate; the Bone Court on the flow
	var salt_anchors := 0
	for pid in range(28, 36):
		salt_anchors += int(province_anchors.get(pid, 0))
	var ash_vein: Dictionary = criminal_orgs["ash_vein"]
	ash_vein["strength"] = clampf(float(ash_vein["strength"]) + 0.02 * float(salt_anchors), 0.0, 100.0)
	var grain: Dictionary = criminal_orgs["hidden_grain"]
	grain["strength"] = clampf(float(grain["strength"]) + (0.04 if (not sieges.is_empty() or not scorched.is_empty()) else -0.01), 0.0, 100.0)


func _refugee_tick() -> void:
	## famine -> depopulation -> refugees -> Bone Court harvest + anchor
	## vacancies -> worse province -> more famine. The loop is the module.
	refugee_flow_month = 0.0
	var ash_flow := 0
	for p in map.provinces:
		if p.pop <= 0:
			continue
		var pressed := false
		var from_ash := false
		var category := "famine"
		if p.silence_touched:
			pressed = true
			from_ash = true
			category = "ashfields"
		elif int(scorched.get(p.id, -1)) > tick or int(salted.get(p.id, -1)) > tick:
			pressed = true
			category = "war"
		elif int(province_anchors.get(p.id, 0)) >= 2:
			pressed = true
		elif famine_dead_by_pid.has(p.id) and p.pop < int(float(_pop_zero(p.id)) * 0.6):
			pressed = true
		if not pressed:
			continue
		var out := int(float(p.pop) * (0.001 if from_ash else 0.002))
		if out <= 0:
			continue
		p.pop -= out
		refugee_flow_month += float(out)
		if from_ash:
			ash_flow += out
		displaced[category] = int(displaced.get(category, 0)) + out
		# they walk toward the nearest standing market — and arrive, mostly
		var dest_pid := 59  # Halven, the refugee city, when no crown claims them
		if p.owner >= 0 and p.owner < map.realms.size():
			dest_pid = map.realms[p.owner].capital_province_id
		var survivors := int(float(out) * 0.96)
		map.provinces[dest_pid].pop += survivors
		# the Bone Court works the roads between: refugees, veterans,
		# Half-Orcs — the desperate, sold by the desperate
		var taken := int(float(out) * (0.04 if from_ash else 0.02))
		if taken > 0:
			bone_court_taken += taken
			var bc: Dictionary = criminal_orgs["bone_court"]
			bc["strength"] = clampf(float(bc["strength"]) + float(taken) / 400.0, 0.0, 100.0)
	if bone_court_taken > 0 and tick % 12 == 0:
		_log("The year's roads: %s souls displaced and walking, and the Bone Court's ledgers heavier by %s. The Ashfield Flies feed it the ones nobody counts." % [_fmt_count(int(refugee_flow_month * 12.0)), _fmt_count(bone_court_taken)])


func _pop_zero(pid: int) -> int:
	## Year Zero baselines are reconstructible: current + everything the
	## ledgers took out. Close enough for the emptying test.
	return map.provinces[pid].pop + int(famine_dead_by_pid.get(pid, 0))


func _cult_tick() -> void:
	## Ten cults, one per silent deity plus the Pale Accord — people who
	## decided that if prayer will not work, LEVERAGE might. A faith at
	## low coherence does not only fracture into heresy; it fractures
	## into coercion. The Empty Bowl grows on the famine curve itself.
	var coherence := 1.0
	if faiths.has("Aelindran Orthodox"):
		coherence = float(faiths["Aelindran Orthodox"]["coherence"])
	var base := 0.25 * (1.0 - coherence) if coherence < 0.55 else 0.05
	for key in cults:
		var cult: Dictionary = cults[key]
		var growth := base
		if key == "empty_bowl":
			growth += 0.9 * famine_rate(float(tick) / 12.0) / CanonData.FAMINE_PLATEAU
		elif key == "swords_return":
			growth += 0.15 if at_war else 0.05
		elif key == "older_terms":
			growth = base * 0.6  # the Accord recruits slowly; its terms are older than hunger
		cult["strength"] = clampf(float(cult["strength"]) + growth, 0.0, 100.0)
		var s := float(cult["strength"])
		if str(cult["state"]) == "gathering" and s >= 33.0:
			cult["state"] = "active"
			_log("[b]%s is no longer a rumor.[/b] %s — %s. Not heretics: coercionists. An attempt to FORCE a silent god back to the table." % [str(cult["name"]), str(cult["leader"]) if str(cult["leader"]) != "" else "No one name leads it", str(cult["method"])])
		elif str(cult["state"]) == "active" and s >= 66.0:
			cult["state"] = "zealous"
			_log("[b]%s crosses into zealotry.[/b] What began as leverage is becoming liturgy — the most dangerous stage of any argument with heaven." % str(cult["name"]))
	_cult_beats()


func _cult_beats() -> void:
	## The scripted threads the brief names. Lethal outcomes are gated on
	## `underneath_lethal` (default false) — whether cult cells may kill
	## named souls is Justin's ruling to make, and flagged as such.
	# canon pin: the cell has been tracking Tavisol for EIGHTEEN MONTHS at
	# the Year Six present (brief §2.3) — so it forms at tick 54, a fact
	# of the setting rather than a die. Its resolution lands at tick 72.
	var sword: Dictionary = cults["swords_return"]
	if tick >= 54 and int(sword["cell_formed"]) < 0:
		sword["cell_formed"] = tick
		_log("Three of the Sword's Return stop attending the open gatherings: Sister Merla Blade-True, Brother Kellan Steel-Vow, Squire Torak Iron-Word. They hold, in Commander Halven Iron-Faith's own hand, an assassination authorization. The name on it serves the Vigil.")
	if int(sword["cell_formed"]) >= 0 and not bool(sword["attempt_done"]) and tick - int(sword["cell_formed"]) >= 18:
		sword["attempt_done"] = true
		var tavisol: SimCharacter = null
		for c in characters.values():
			if c.alive and c.name == "Tavisol" and c.hero_level > 0:
				tavisol = c
				break
		if tavisol != null:
			if underneath_lethal:
				_kill(tavisol, "is taken at prayer by three blades of the Sword's Return —")
			else:
				_log("[b]Eighteen months of patience come due:[/b] three blades of the Sword's Return close on Tavisol at prayer — and find the Oath of Devotion does not startle. The attempt fails; the cell scatters; the authorization, in Iron-Faith's own hand, is now evidence walking around loose. (The cell's blades stay sheathed pending Justin's ruling on lethal cult outcomes.)")
				raise_event(0, realms[0].ruler_id, "The Authorization, In His Own Hand",
					"A paladin was nearly murdered for the crime of serving a threshold the war-god's cult resents. The scattered cell left paper behind: Commander Halven Iron-Faith's signature under an assassination authorization. The Sword's Return has crossed from coercing heaven to killing its servants.",
					[{"label": "Circulate the evidence to every court", "base": 3.0, "ai": {"orthodoxy": 0.5}},
					{"label": "Hold it — leverage over the cult later", "base": 2.0, "ai": {"scheming": 0.7}}],
					false, false, false, false, false, false, false, false, true)
	# canon pin: at the Year Six present the Unpublished Record is already
	# PREPARING to publish Rorend's vote, and Sera already knows (brief).
	var record: Dictionary = cults["unpublished_record"]
	if (tick >= 66 or float(record["strength"]) >= 50.0) and not bool(record["prepared"]):
		record["prepared"] = true
		_log("Archive Master Ferren Truth-Speaks of the Unpublished Record is assembling something: a vote tally, eighty-eight years old, with House Halvenard-Veil's ancestor Rorend on the wrong side of it. Sera Halvenard-Veil has known for a year. She has told no one, which is itself information.")
	if float(record["strength"]) >= 75.0 and not bool(record["published"]):
		record["published"] = true
		for s in secrets:
			if str(s["type"]) == "rorend_patron_vote":
				s["known"][0] = true
				s["known"][1] = true
		_log("[b]The Unpublished Record publishes.[/b] Rorend Halvenard-Veil's Patron vote, eighty-eight years buried, is nailed to every notice-post the cult can reach: the truth forced into daylight so the record-god must acknowledge it. The house's buried secret is now everyone's breakfast reading.")


func _seed_houses() -> void:
	## Pass Two §3: the ~46 houses take their live records, and the ones
	## with buried hooks enter the intrigue web — OUTSIDE the tavern
	## pool. House secrets surface through their own beats and through
	## investigate_house, never through a ferreting informant's lucky month.
	house_records = {}
	for key in CanonData.HOUSES:
		house_records[key] = {"discovered": false}
	var garran_id := -1
	if sera_id >= 0 and characters.has(sera_id):
		garran_id = characters[sera_id].father_id
	_add_secret_under(garran_id, "rorend_patron_vote", "halvenard_veil")
	_add_secret_under(-1, "iorek_confession", "aurath_voss")
	var mira_id := -1
	for c in characters.values():
		if c.name == "Mira" and dynasties.has(c.dynasty_id) and dynasties[c.dynasty_id].name == "House Crannock-Vey":
			mira_id = c.id
			break
	_add_secret_under(mira_id, "crannock_mira_forsaken", "crannock_vey")
	_add_secret_under(-1, "vannin_memories", "drome")
	_add_secret_under(-1, "talan_faerith_romance", "velmarin_house")
	_add_secret_under(-1, "ironbrand_concealment", "ironbrand")
	_add_secret_under(-1, "bone_court_patronage", "bone_court")


func _add_secret_under(subject_id: int, type: String, house_key: String) -> void:
	## A buried secret: in the web, but beyond informants — the `under`
	## flag keeps it out of every generic sampling loop, so the fixed-
	## seed history never feels the house vaults existing.
	for s in secrets:
		if str(s["type"]) == type:
			return
	secrets.append({"subject": subject_id, "type": type, "known": {}, "under": true, "house": house_key})


func investigate_house(realm_id: int, key: String) -> String:
	## The Spymaster's deep work: one house's vault at a time. The
	## Ironbrand discoverable is the one that matters most — the house
	## lying about the ward-stones is lying about the exact mechanism
	## that drives entity density. Uncovering it unlocks understanding,
	## not just a scandal.
	if realm_id != 0:
		return "Other crowns run their own inquiries."
	if not CanonData.HOUSES.has(key):
		return "No such house in the registry."
	if council_member(0, "Spymaster") == null:
		return "Vault-work needs a Spymaster."
	var realm: Realm = realms[0]
	if realm.gold < 25.0:
		return "A season inside a house's ledgers costs 25 gold."
	if bool(house_records[key]["discovered"]):
		return "That vault has already been read."
	realm.gold -= 25.0
	house_records[key]["discovered"] = true
	var house: Dictionary = CanonData.HOUSES[key]
	var secret_type := str(house.get("secret", ""))
	if secret_type == "":
		_log("The Spymaster's season inside %s's ledgers finds them boring, which is its own kind of information." % str(house["name"]))
		return ""
	for s in secrets:
		if str(s["type"]) == secret_type:
			s["known"][0] = true
	match key:
		"ironbrand":
			wardstone_linkage_known = true
			_log("[b]The Ironbrand concealment, uncovered.[/b] The Dwarven surface merchants have been hiding the ward-stone decline since the Night of the Third Hour — increasing supply so nobody asks why demand rose. Deepstone's research underlies the lie. And the crown now understands something the wardens' registry only suspected: THE DEEP PASSAGES ARE WORST BECAUSE THEIR MAINTENANCE WAS HEAVIEST. Piety was infrastructure. The house lying about the ward-stones was lying about exactly that.")
		"halvenard_veil":
			_log("[b]Rorend's vote.[/b] Under Halvenard-Veil's oldest seal: the tally of Year 112, and the house's ancestor among the seven ayes. The feud with Aurath-Voss reads differently in this light. So does everything.")
		"crannock_vey":
			_log("The First Voice's daughter, Mira Crannock-Vey, runs with the Forsaken Underground — the generation that never met the gods, organizing in her father's own harbor. He does not know. The Spymaster now does.")
		"drome":
			_log("House Drome's head, Vannin, has gaps in his memory with WORKED EDGES — a Vanneth signature. He retains House Vanneth to this day, which means either he does not know, or the second working was to make him stop minding. Both readings are for sale now.")
		"velmarin_house":
			_log("Talan Velmarin and Faerith Thornback — heirs of two sorcerer houses that have spent a century feuding — have been exchanging letters through a bookbinder in the capital. The letters are not about the feud.")
		_:
			_log("The Spymaster's season inside %s's ledgers pays for itself." % str(house["name"]))
	return ""


func underneath_status_line() -> String:
	var worst := ""
	var worst_s := 0.0
	for key in cults:
		if float(cults[key]["strength"]) > worst_s:
			worst_s = float(cults[key]["strength"])
			worst = str(cults[key]["name"])
	if worst == "" or worst_s < 20.0:
		return ""
	var s := "Below the ledgers: %s is the loudest argument with heaven" % worst
	if bone_court_taken > 0:
		s += "; the Bone Court's count stands at %s" % _fmt_count(bone_court_taken)
	return s + "."
