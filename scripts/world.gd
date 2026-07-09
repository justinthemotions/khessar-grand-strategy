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

# The standing-army model: regiments persist between battles.
const UNIT_LABELS := {"levy": "Levy Spears", "sword": "Sword Infantry", "cav": "Heavy Cavalry", "archer": "Archers"}
const UNIT_WEIGHTS := {"levy": 1.0, "sword": 1.4, "cav": 2.2, "archer": 1.2}
const RECRUIT_COST := {"levy": 120.0, "sword": 240.0, "cav": 450.0, "archer": 200.0}
const RECRUIT_SIZE := {"levy": 48, "sword": 36, "cav": 16, "archer": 24}
const UPKEEP_PER_MAN := 0.05
const REPLENISH_COST_PER_MAN := 0.3

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
var county_holders: Dictionary = {}  # province id -> character id (granted county titles)
var duchy_holders: Dictionary = {}   # duchy id -> character id

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
	characters[c.id] = c
	return c


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
	_stress_relief_tick()
	_renown_tick()
	_cadet_branch_tick()
	_ai_dynasty()
	_interregnum_tick()
	_dejure_tick()
	_council_tick()
	_laws_tick()
	_plots_tick()
	_ai_diplomacy()
	_economy()
	_military_upkeep()
	_ai_recruit()
	_campaign_military()
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
	_blend_stats(child, father, mother)
	child.genome = Genetics.inherit(rng, father.genome, mother.genome)
	_inherit_traits(child, father, mother)
	if has_legacy(root_house_id(father.dynasty_id), "Blood of the Wolf"):
		child.martial = clampi(child.martial + 1, 1, 30)
		child.prowess = clampi(child.prowess + 1, 1, 30)
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
		return  # at most one scandal a month — the chronicle can only take so much


func _deaths() -> void:
	var doomed: Array = []
	for c in characters.values():
		if c.alive and rng.randf() < _death_chance(c.age_years(tick)):
			doomed.append(c)
	for c in doomed:
		_kill(c, "has died")


func _death_chance(age: int) -> float:
	var q := 0.0004
	if age < 5:
		q += 0.002
	if age > 45:
		var over := float(age - 45)
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
	_escheat_titles(c)
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


func recruit(realm_id: int, kind: String) -> String:
	var realm: Realm = realms[realm_id]
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
		# a Methodical commander wastes nothing on the march
		var supply := UPKEEP_PER_MAN
		if a.commander_id >= 0:
			supply *= trait_mult(characters.get(a.commander_id), "supply_consumption_mult")
		realms[a.realm_id].gold -= a.size() * supply
	for a: Army in armies:
		if battle_ready and pending_battle.has(a.id):
			continue  # no reinforcements reach an army standing on the field
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
	war_score += 10.0 * (sa - sb) / maxf(sa + sb, 1.0) + rng.randf_range(-2.0, 2.0)
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


func declare_war(by_realm: int = 0) -> String:
	if at_war:
		return "The realms are already at war."
	if allied():
		return "A marriage alliance binds the realms. It holds while the couple lives."
	at_war = true
	war_score = 0.0
	battle_ready = false
	pending_battle = []
	if trade_pact:
		trade_pact = false
		_log("The trade pact is torn up.")
	var aggressor: Realm = realms[by_realm]
	var defender: Realm = realms[1 - by_realm]
	if aggressor.ruler_id >= 0 and defender.ruler_id >= 0:
		add_memory(characters[defender.ruler_id], "invaded my realm", aggressor.ruler_id, -40.0, 3.0)
		add_memory(characters[aggressor.ruler_id], "my enemy", defender.ruler_id, -20.0, 3.0)
	if aggressor.ruler_id >= 0:
		var r: SimCharacter = characters[aggressor.ruler_id]
		if r.traits.has("Compassionate"):
			add_stress(r, 15.0, "marching others' sons to die")
		if r.traits.has("Content"):
			add_stress(r, 10.0, "the burden of ambition")
	_log("[b]WAR![/b] %s declares war on %s." % [aggressor.name, defender.name])
	return ""


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
		if strength(1) < int(strength(0) * 0.9):
			return  # even the Wrathful wait until the odds are fair
		var chance := clampf(0.004 + aggression * 0.0002, 0.0, 0.03)
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
		var tribute := minf(80.0, maxf(loser.gold, 0.0))
		loser.gold -= tribute
		winner.gold += tribute
		_log("[b]Peace.[/b] %s yields — %d gold in tribute flows to %s." % [loser.name, int(tribute), winner.name])
		_cede_border_province(winner, loser)
	else:
		_log("[b]White peace.[/b] The war ends with nothing gained.")
	at_war = false
	war_score = 0.0
	battle_ready = false
	pending_battle = []
	for a: Army in armies:
		a.target = map.realm_centroid(a.realm_id)
		a.has_target = a.pos.distance_to(a.target) > 0.02
	return ""


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
	armies.erase(victim)
	war_score += 15.0 if winner_army.realm_id == 0 else -15.0
	war_score = clampf(war_score, -100.0, 100.0)
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
		elif not a.has_target:
			a.target = map.realm_centroid(1)
			a.has_target = a.pos.distance_to(a.target) > 0.02


func battle_site_name() -> String:
	var target: Vector2 = map.frontier_midpoint()
	if pending_battle.size() == 2:
		var a := army_by_id(pending_battle[0])
		var b := army_by_id(pending_battle[1])
		if a != null and b != null:
			target = (a.pos + b.pos) * 0.5
	return _site_name_at(target)


func _site_name_at(target: Vector2) -> String:
	var best_name := "the frontier"
	var best_d := INF
	for p in map.provinces:
		var d: float = p.center.distance_squared_to(target)
		if d < best_d:
			best_d = d
			best_name = p.name
	return best_name


func apply_battle_result(winner_side: int, loser_loss_fraction: float) -> void:
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
		_log("[b]The Battle of %s![/b] %s carries the field." % [site, realms[winner_side].name])
		var loser_army: Army = pb if winner_side == 0 else pa
		if loser_army != null and army_by_id(loser_army.id) != null:
			loser_army.target = map.realm_centroid(loser_army.realm_id)
			loser_army.has_target = true
	_commander_fate(pa, pb, winner_side == 0, loser_loss_fraction, site)
	_commander_fate(pb, pa, winner_side == 1, loser_loss_fraction, site)
	if absf(war_score) >= 100.0:
		var _msg := negotiate_peace()


func _commander_fate(a: Army, enemy: Army, won: bool, loss: float, site: String) -> void:
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


func _cede_border_province(winner: Realm, loser: Realm) -> void:
	var options: Array = []
	for p in map.provinces:
		if p.owner != loser.id:
			continue
		for nid in p.neighbors:
			if map.provinces[nid].owner == winner.id:
				options.append(p)
				break
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
	_log("[b]Wedding bells:[/b] %s weds %s." % [full_name(g), full_name(b)])
	if cross_realm:
		marriage_alliances.append([g.id, b.id])
		_log("[b]The marriage binds %s and %s in alliance.[/b]" % [realms[0].name, realms[1].name])
	return ""


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
	if info.category == "personality":
		if _count_cat(c, "personality") >= PERSONALITY_CAP:
			return false
		if info.opposite != "" and c.traits.has(info.opposite):
			return false
	return true


func _add_trait(c: SimCharacter, t: String) -> void:
	if not _can_add_trait(c, t):
		return
	c.traits.append(t)
	var mods: Dictionary = TraitDB.info(t).stats
	for k in mods:
		var prop: String = STAT_PROPS[k]
		c.set(prop, clampi(int(c.get(prop)) + int(mods[k]), 1, 30))


func _assign_founder_traits(c: SimCharacter) -> void:
	var personalities := _traits_of_cat("personality")
	for i in 2:
		_add_trait(c, personalities[rng.randi_range(0, personalities.size() - 1)])
	if rng.randf() < 0.15:
		var congenitals := _traits_of_cat("congenital")
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
		var congenitals := _traits_of_cat("congenital")
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
		c.stress = maxf(0.0, c.stress - relief)
		if c.stress < c.stress_level * 100.0 - 50.0 and c.stress_level > 0:
			c.stress_level -= 1


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
	## realms at setup, and monthly for Sarova.
	var realm: Realm = realms[realm_id]
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


func _plots_tick() -> void:
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
		var own := council_stat(realm.id, "Spymaster")
		var their := council_stat(t.realm_id, "Spymaster")
		var pace := maxf(1.0, 3.0 + own * 0.5 - their * 0.35)
		pace /= trait_mult(t, "intrigue_defense_mult")  # the Paranoid sleep behind locked doors
		if realm.ruler_id >= 0 and has_mythos(root_house_id(characters[realm.ruler_id].dynasty_id), "Whispered Poisoners"):
			pace *= 1.15  # practice makes perfect
		realm.plot_progress += pace
		# past the halfway mark, the victim's court may catch wind of it
		if not realm.plot_warned and realm.plot_progress >= 50.0:
			realm.plot_warned = true
			var detect := (0.30 + council_stat(t.realm_id, "Spymaster") * 0.015) * trait_mult(t, "intrigue_defense_mult")
			if rng.randf() < detect:
				_raise_plot_warning(realm, t)
		if realm.plot_progress < 100.0:
			continue
		var succeed := clampf(0.30 + (own - their) * 0.02, 0.10, 0.75)
		var victim_name := full_name(t)
		var plotter_ruler_id: int = realm.ruler_id
		if rng.randf() < succeed:
			# the family suspects a foreign hand, even without proof
			var kin_ids: Array = [t.spouse_id, t.father_id, t.mother_id]
			kin_ids.append_array(t.children_ids)
			if plotter_ruler_id >= 0:
				var proot := root_house_id(characters[plotter_ruler_id].dynasty_id)
				dynasties[proot].poisonings += 1
				if dynasties[proot].poisonings >= POISONINGS_THRESHOLD:
					_earn_mythos(proot, "Whispered Poisoners")
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
			_log("[b]A plot against %s is uncovered![/b] Agents of %s hang in the square." % [victim_name, realm.name])
			if plotter_ruler_id >= 0:
				add_memory(t, "plotted my death", plotter_ruler_id, -60.0, 1.0)
				var t_ruler: int = realms[t.realm_id].ruler_id
				if t_ruler >= 0 and t_ruler != t.id:
					add_memory(characters[t_ruler], "plotted against my court", plotter_ruler_id, -30.0, 2.0)
		abandon_plot(realm.id)
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
	raise_event(victim.realm_id, target_realm.ruler_id, "Whispers of a Plot",
		"Your Spymaster brings grave word: a foreign hand weaves a plot against %s. The web is half-spun — there is still time to act." % victim_name,
		options)


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

func raise_event(realm_id: int, decider_id: int, title: String, text: String, options: Array) -> void:
	if options.is_empty():
		return
	var ev := {"id": next_event_id, "realm_id": realm_id, "decider": decider_id,
		"title": title, "text": text, "options": options}
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
	var best := 0
	var best_score := -INF
	for i in ev["options"].size():
		var opt: Dictionary = ev["options"][i]
		var score: float = float(opt.get("base", 0.0)) + rng.randf() * 12.0
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
	var total := 0.0
	var crown_taxes: Array = []
	for p in map.provinces:
		if p.owner != realm_id:
			continue
		var t: float = p.tax
		if p.de_jure != realm_id:
			t *= FOREIGN_LAND_YIELD  # the people remember other banners
		var lord := county_holder(p.id)
		if lord != null:
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
		var l := float(p.levy)
		if p.de_jure != realm_id:
			l *= FOREIGN_LAND_YIELD
		var lord := county_holder(p.id)
		if lord != null:
			l += lord.martial * 0.5  # a lord drills his own men
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
	holders.erase(title_id)
	if characters.has(old_id) and characters[old_id].alive:
		var old: SimCharacter = characters[old_id]
		if realm.ruler_id >= 0:
			add_memory(old, "stripped my land", realm.ruler_id, -50.0, 1.0)
		_log("[b]%s is stripped of %s[/b] — and will not forget it." % [full_name(old), title_name])
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
	var cost: float = LEGACIES[key]["cost"]
	if dyn.renown < cost:
		return "Not enough Renown — %d needed." % int(cost)
	dyn.renown -= cost
	dyn.legacies.append(key)
	_log("[b]%s claims a legacy: %s.[/b] %s." % [dyn.name, key, LEGACIES[key]["blurb"]])
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
