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
var central_secret_state: String = "buried"  # buried|revealed|contained|destroyed|leveraged|suppressed
var patron_network_broken: bool = false      # Ending 3: the anchor is ash
var faith_failures: Dictionary = {}   # char id -> failed prayers this year (Faith Crisis at 3)
var silence_mark_deaths: Dictionary = {}  # root house id -> members lost bearing Corruption Marks

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
		if not (c.alive and c.is_female and c.spouse_id >= 0):
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
		if not c.alive or c.is_female or c.is_bastard:
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
		if not c.alive:
			continue
		var age: int = c.age_years(tick)
		var chance := _death_chance(age, c.race)
		if c.traits.has("Wasting"):
			chance *= 4.0  # the Slow Weep does its patient, deniable work
		if rng.randf() < chance:
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
		if not (c.alive and c.realm_id == a.realm_id) or c.denounced:
			continue
		if c.age_years(tick) < ADULT_AGE or taken.has(c.id):
			continue
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
		if c.alive and not c.is_female and c.realm_id == realm.id and c.age_years(tick) >= ADULT_AGE:
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


func _site_name_at(target: Vector2) -> String:
	var best_name := "the frontier"
	var best_d := INF
	for p in map.provinces:
		var d: float = p.center.distance_squared_to(target)
		if d < best_d:
			best_d = d
			best_name = p.name
	return best_name


func apply_battle_result(winner_side: int, loser_loss_fraction: float, charged: Array = [false, false], cmdr_corruption: Array = [0.0, 0.0]) -> void:
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
	# what the field cost each commander's ledger (Magic v1.0)
	for i in 2:
		var host: Army = pa if i == 0 else pb
		if float(cmdr_corruption[i]) > 0.0 and host != null and host.commander_id >= 0:
			var cmdr: SimCharacter = characters.get(host.commander_id)
			if cmdr != null and cmdr.alive:
				add_corruption(cmdr, float(cmdr_corruption[i]), "what was channeled at %s" % site)
	_commander_fate(pa, pb, winner_side == 0, loser_loss_fraction, site, bool(charged[0]))
	_commander_fate(pb, pa, winner_side == 1, loser_loss_fraction, site, bool(charged[1]))
	_champion_fates(pa, pb, winner_side == 0, loser_loss_fraction, site)
	_champion_fates(pb, pa, winner_side == 1, loser_loss_fraction, site)
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
				and not wards.has(c.id):
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
	var out := _traits_of_cat("congenital")
	out.erase("Bicultural")
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
	var house := Dynasty.new(dynasties.size(), "House Ormand")
	dynasties[house.id] = house
	var ormand := _create_character("Veril", false, tick - 71 * 12 - 5, house.id, 0)
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


func faith_reliability(c: SimCharacter, p) -> float:
	## The Cleric geography formula (doc §4.3): base × the ground's
	## dampening × shared attention × the caster's answer to the Silence.
	## The world's remaining faith works — sometimes, in specific places,
	## when the right conditions align.
	var damp := FAITH_DAMPENING_BASE
	if p != null:
		if p.silence_touched:
			damp = FAITH_DAMPENING_ASHFIELDS
		elif str(p.special_feature) == "iron_library":
			damp = FAITH_DAMPENING_LIBRARY
		elif str(p.special_feature) == "sealed_hold":
			damp = FAITH_DAMPENING_WARDSTONE  # the Kharak-Dum wards still hold a little sky up
	var r := trait_mult(c, "faith_channel_reliability_baseline") * damp
	# shared attention: every ten faithful in the hall stand in for the sky
	var crowd := 0
	for o in characters.values():
		if o.alive and o.realm_id == c.realm_id and o.id != c.id:
			crowd += 1
	r *= 1.0 + 0.01 * float(mini(crowd, 100))
	for resp in RESPONSE_FAITH_MULT:
		if c.traits.has(resp):
			r *= float(RESPONSE_FAITH_MULT[resp])
			break
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
		if not c.alive or not c.traits.has("Faith-Practicing"):
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
		if c.alive and c.stress >= 180.0 and not c.traits.has("Patron-Bound") \
				and c.age_years(tick) >= ADULT_AGE and mrng.randf() < 0.06:
			_raise_patron_offer(c)
			break
	for c in characters.values():
		if c.alive and c.traits.has("Patron-Bound") and mrng.randf() < 0.04:
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
				if not c.alive or c.realm_id != realm.id or c.age_years(tick) < ADULT_AGE:
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
		if c.alive and c.traits.has("Oath-Sworn") and mrng.randf() < 0.015:
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
		_raise_architect_chamber()
		return
	if tick >= 60 and mrng.randf() < 0.002:
		_log("[b]Loose pages surface from the Aurath-Voss archives[/b] — fragments of a vote taken in Year 112 of the Council, and of what it purchased.")
		_raise_architect_chamber()


func _raise_architect_chamber() -> void:
	## The complete record: seven signatures under a bargain with the
	## Patron, and the Silence its price. Five ways to hold the truth.
	central_secret_state = "opened"
	for s in secrets:
		if str(s["type"]) == "silence_cause_complicity":
			s["known"][0] = true
	raise_event(0, realms[0].ruler_id, "The Architect's Chamber",
		"Veril Ormand's chamber stands open at last — and in it, the complete record. The Magistocracy's foundation transaction: seven signatures under a bargain with the Patron, dated Year 112 of the Council. Three dissenters, all dead within eighteen months. The Silence was the invoice. What the crown does with the truth decides the age.",
		[
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
		], true)


func _ending_revealed() -> void:
	central_secret_state = "revealed"
	realms[0].tyranny = minf(100.0, realms[0].tyranny + 30.0)
	realms[0].prestige = maxf(-100.0, realms[0].prestige - 50.0)
	realms[1].prestige = minf(100.0, realms[1].prestige + 15.0)
	for lord: SimCharacter in landed_vassals(0):
		if realms[0].ruler_id >= 0:
			add_memory(lord, "their crowns knew", realms[0].ruler_id, -40.0, 1.0)
	_log("[b]THE TRUTH IS PUBLISHED.[/b] The Magistocracy caused the Silence — bought it, signed for it, profited by it. Its legitimacy does not survive the reading. The old noble houses are suddenly the only authority anyone remembers trusting.")


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
		if rng.randf() < 0.6 and realms[0].ruler_id >= 0:
			target = characters[realms[0].ruler_id]
		else:
			var pool: Array = []
			for c in characters.values():
				if c.alive and c.realm_id == 0 and c.age_years(tick) >= ADULT_AGE:
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
				and c.id != realms[t.realm_id].ruler_id and c.age_years(tick) >= ADULT_AGE:
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
				and c.learning >= 10 and not _on_council(realm_id, c.id):
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
		if c.alive and not c.is_female and c.spouse_id < 0 and c.age_years(tick) >= 22:
			bachelors.append(c)
	for m: SimCharacter in bachelors:
		if m.spouse_id >= 0 or rng.randf() > 0.06:
			continue
		for f in characters.values():
			if not (f.alive and f.is_female and f.spouse_id < 0):
				continue
			if f.age_years(tick) < ADULT_AGE or f.realm_id != m.realm_id or _close_kin(m, f):
				continue
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
		if c.alive and c.is_female == female and c.spouse_id < 0 and c.age_years(tick) >= ADULT_AGE:
			out.append(c)
	out.sort_custom(func(a: SimCharacter, b: SimCharacter) -> bool: return a.birth_tick < b.birth_tick)
	return out


# ---------------------------------------------------------------- the event framework
# A choice event is pure data: {id, realm_id, decider, title, text, options}.
# Each option: {label, effect: Callable, ai: {axis: weight}, base: float}.
# Player-realm events queue for a popup; everyone else's are decided on
# the spot by the decider's personality — the same trait AI weights
# (aggression / scheming / greed / patience) score every option.

func raise_event(realm_id: int, decider_id: int, title: String, text: String, options: Array, magic: bool = false) -> void:
	if options.is_empty():
		return
	# magic-born events resolve on the magic RNG (Magic v1.0) so the main
	# history stream never feels the Silence's bookkeeping
	var ev := {"id": next_event_id, "realm_id": realm_id, "decider": decider_id,
		"title": title, "text": text, "options": options, "magic": magic}
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
	var jitter_rng: RandomNumberGenerator = mrng if bool(ev.get("magic", false)) else rng
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
		if not c.alive or c.is_female:
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
