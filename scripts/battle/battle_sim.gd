class_name BattleSim
extends RefCounted

## Real-time battle simulation. Regiments are the gameplay entities;
## individual soldiers are pure decoration drawn by BattleView.
## Combat math is the Regiment Combat Lab model ported 1:1 —
## deterministic expected-value resolution, morale decides battles.
## Movement runs per frame; combat resolves in half-second ticks.

signal battle_ended(winner_side: int)
signal event(text: String)

const TICK_SECONDS := 0.5
const SPACING := 7.0            # px between soldiers in formation
const CHARGE_DURATION := 10     # combat ticks of decaying charge impact

# --- Combat Lab tuning (same constants as the calculator) ---
const BASE_HIT := 0.35
const HIT_PER_POINT := 0.02
const HIT_MIN := 0.08
const HIT_MAX := 0.90
const ARMOUR_PIVOT := 35.0
const CHIP_FRACTION := 0.15
const ATTACKS_PER_TICK := 0.12
const CHARGE_SCALE := 20.0
const FLANK_MULT := 1.5
const REAR_MULT := 2.0
const START_MORALE := 100.0
const CASUALTY_SHOCK := 160.0
const CHARGE_SHOCK := 10.0
const FLANKED_PENALTY := 20.0
const REAR_PENALTY := 40.0
const DEPLETION := 70.0
const LEADERSHIP_REGEN := 0.03

# Battle Grid orders (Module 7): once-per-battle commander tactics, gated
# by who the commander actually is. Deterministic — no dice on the field.
const TACTIC_LABELS := {
	"feigned_retreat": "Feigned Retreat",
	"commit_reserve": "Commit the Reserve",
	"chivalric_charge": "Chivalric Charge",
	# Magic Injection v1.0: the desperate-caster cards
	"uncontrolled_channel": "Uncontrolled Channel",
	"reap_the_bargain": "Reap the Bargain",
}
const REAP_SHOCK := 25.0         # the Patron collects from every enemy line at once
const CHANNEL_MISSILE_MULT := 1.6  # untrained arcana, poured out raw
const LURE_TICKS := 12           # how long a feigned retreat drags its victim out of line
const LURE_CENTER_SHOCK := 15.0  # the exposed center feels the line come apart
const RESERVE_HEART := 25.0      # shock lifted from the line the reserve reinforces
const RESERVE_COHESION := 15.0   # the reserve fights above itself
const CHARGE_WS_MULT := 1.3      # a chivalric charge hits like a hammer...
const CHARGE_TAKEN_MULT := 1.25  # ...and bleeds for riding into the press

# Levy morale cascade (Module 7): when a formation breaks and runs, the
# conscripts near it look over their shoulders. Professional squads hold.
const CASCADE_RANGE := 170.0     # px — panic is contagious only up close
const CASCADE_SHOCK := 30.0      # base fear, before the commander steadies them
const CASCADE_LEAD_DAMP := 0.8   # each point of commander martial calms the line
const CASCADE_MIN := 8.0

# Ranged fire: deterministic expected-value volleys, one per combat tick.
const RANGED_RATE := 0.06        # shots landing per shooter per tick
const RANGED_HIT := 0.35
# Shields block missiles by arc: full from the front, half from the flank,
# nothing from the rear. (Melee parry is already inside Melee Defence.)
const SHIELD_ARC_FACTOR := [1.0, 0.5, 0.0]

const PRESETS := {
	# --- the universal roster: every culture fields these ---
	"levy":   {"label": "Levy Spears",    "soldiers": 48, "hp": 8.0,  "armour": 4.0,  "ma": 22.0, "md": 26.0, "ws": 8.0,  "charge": 6.0,  "lead": 35.0, "files": 12, "speed": 26.0, "bonus_cav": 12.0, "cav": false, "shield": 0.30, "range": 0.0,   "ammo": 0,  "missile": 0.0},
	"sword":  {"label": "Sword Infantry", "soldiers": 36, "hp": 10.0, "armour": 12.0, "ma": 32.0, "md": 32.0, "ws": 11.0, "charge": 10.0, "lead": 50.0, "files": 9,  "speed": 30.0, "bonus_cav": 0.0,  "cav": false, "shield": 0.45, "range": 0.0,   "ammo": 0,  "missile": 0.0},
	"cav":    {"label": "Heavy Cavalry",  "soldiers": 16, "hp": 16.0, "armour": 20.0, "ma": 38.0, "md": 28.0, "ws": 13.0, "charge": 34.0, "lead": 65.0, "files": 8,  "speed": 60.0, "bonus_cav": 0.0,  "cav": true,  "shield": 0.20, "range": 0.0,   "ammo": 0,  "missile": 0.0},
	"archer": {"label": "Archers",        "soldiers": 24, "hp": 7.0,  "armour": 2.0,  "ma": 14.0, "md": 14.0, "ws": 6.0,  "charge": 3.0,  "lead": 35.0, "files": 12, "speed": 32.0, "bonus_cav": 0.0,  "cav": false, "shield": 0.05, "range": 230.0, "ammo": 40, "missile": 9.0},

	# --- cultural specialty rosters (Cultural Roster v1.0) ---
	# Vael: modest conventional units backed by academy-trained arcanists.
	# The retinue's wards block missiles from every arc (ward_shield).
	"vael_arcane_retinue":  {"label": "Arcane Retinue",     "soldiers": 24, "hp": 8.0,  "armour": 6.0,  "ma": 20.0, "md": 22.0, "ws": 9.0,  "charge": 4.0,  "lead": 45.0, "files": 12, "speed": 28.0, "bonus_cav": 0.0,  "cav": false, "shield": 0.15, "range": 240.0, "ammo": 20, "missile": 14.0, "ward_shield": true},
	"vael_court_company":   {"label": "Court Company",      "soldiers": 40, "hp": 9.0,  "armour": 10.0, "ma": 28.0, "md": 30.0, "ws": 10.0, "charge": 8.0,  "lead": 55.0, "files": 10, "speed": 28.0, "bonus_cav": 6.0,  "cav": false, "shield": 0.40, "range": 0.0,   "ammo": 0,  "missile": 0.0},
	# Aelindran: classical feudal doctrine — household cavalry and sworn swords.
	"aelindran_household_cavalry": {"label": "Household Cavalry", "soldiers": 18, "hp": 14.0, "armour": 22.0, "ma": 36.0, "md": 30.0, "ws": 12.0, "charge": 32.0, "lead": 60.0, "files": 8, "speed": 55.0, "bonus_cav": 0.0, "cav": true, "shield": 0.35, "range": 0.0, "ammo": 0, "missile": 0.0},
	"aelindran_sworn_sword": {"label": "Sworn Swords",      "soldiers": 32, "hp": 10.0, "armour": 14.0, "ma": 32.0, "md": 32.0, "ws": 11.0, "charge": 10.0, "lead": 55.0, "files": 9,  "speed": 30.0, "bonus_cav": 2.0,  "cav": false, "shield": 0.50, "range": 0.0,   "ammo": 0,  "missile": 0.0},
	# Free City: policing infantry and shoot-when-needed contract militia.
	"city_watch":           {"label": "City Watch",         "soldiers": 32, "hp": 10.0, "armour": 12.0, "ma": 30.0, "md": 34.0, "ws": 10.0, "charge": 6.0,  "lead": 50.0, "files": 10, "speed": 30.0, "bonus_cav": 4.0,  "cav": false, "shield": 0.45, "range": 0.0,   "ammo": 0,  "missile": 0.0},
	"contract_militia":     {"label": "Contract Militia",   "soldiers": 36, "hp": 9.0,  "armour": 8.0,  "ma": 26.0, "md": 28.0, "ws": 10.0, "charge": 5.0,  "lead": 42.0, "files": 10, "speed": 30.0, "bonus_cav": 4.0,  "cav": false, "shield": 0.35, "range": 150.0, "ammo": 20, "missile": 7.0},
	# Halveni: harbor specialists and contractual professionals (fight well, rout readily).
	"harbor_guard":         {"label": "Harbor Guard",       "soldiers": 32, "hp": 10.0, "armour": 14.0, "ma": 30.0, "md": 34.0, "ws": 10.0, "charge": 4.0,  "lead": 50.0, "files": 10, "speed": 32.0, "bonus_cav": 4.0,  "cav": false, "shield": 0.45, "range": 130.0, "ammo": 15, "missile": 7.0},
	"coin_sworn":           {"label": "Coin-Sworn Retainers", "soldiers": 24, "hp": 11.0, "armour": 16.0, "ma": 34.0, "md": 34.0, "ws": 11.0, "charge": 10.0, "lead": 40.0, "files": 9, "speed": 30.0, "bonus_cav": 4.0, "cav": false, "shield": 0.45, "range": 0.0, "ammo": 0, "missile": 0.0},
	# Drevak: berserkers cannot rout above 25% strength (and need 40%
	# deeper shock below it); war-columns carry clan-identity hardiness.
	"drevak_berserker":     {"label": "Berserkers",         "soldiers": 20, "hp": 14.0, "armour": 8.0,  "ma": 40.0, "md": 24.0, "ws": 14.0, "charge": 20.0, "lead": 55.0, "files": 8,  "speed": 32.0, "bonus_cav": 0.0,  "cav": false, "shield": 0.10, "range": 0.0,   "ammo": 0,  "missile": 0.0, "never_routs_above": 0.25},
	"drevak_war_column":    {"label": "War-Column",         "soldiers": 32, "hp": 12.0, "armour": 14.0, "ma": 32.0, "md": 30.0, "ws": 12.0, "charge": 12.0, "lead": 55.0, "files": 10, "speed": 28.0, "bonus_cav": 6.0,  "cav": false, "shield": 0.35, "range": 0.0,   "ammo": 0,  "missile": 0.0},
	# Karn-Vol: the mixed Drevak/Human compact formation — highest
	# non-arcane leadership in Khessar; dissolves if the compact breaks.
	"compact_sworn":        {"label": "Compact-Sworn",      "soldiers": 28, "hp": 11.0, "armour": 12.0, "ma": 32.0, "md": 32.0, "ws": 11.0, "charge": 14.0, "lead": 60.0, "files": 9,  "speed": 30.0, "bonus_cav": 4.0,  "cav": false, "shield": 0.40, "range": 0.0,   "ammo": 0,  "missile": 0.0},
	# Kharak-Dum: the anvil, and the ward-speakers whose aura steadies it.
	"dwarven_ironside":     {"label": "Ironsides",          "soldiers": 24, "hp": 14.0, "armour": 24.0, "ma": 30.0, "md": 36.0, "ws": 12.0, "charge": 8.0,  "lead": 50.0, "files": 10, "speed": 22.0, "bonus_cav": 8.0,  "cav": false, "shield": 0.55, "range": 0.0,   "ammo": 0,  "missile": 0.0},
	"ward_speaker_retinue": {"label": "Ward-Speakers",      "soldiers": 16, "hp": 10.0, "armour": 12.0, "ma": 22.0, "md": 28.0, "ws": 8.0,  "charge": 4.0,  "lead": 65.0, "files": 8,  "speed": 26.0, "bonus_cav": 0.0,  "cav": false, "shield": 0.30, "range": 180.0, "ammo": 30, "missile": 10.0, "aura_lead": 10.0, "aura_range": 200.0},
	# Brushgate: the anti-Silence specialists — panic resistance now,
	# silence_immunity ready for the endgame entities when they arrive.
	"brushgate_column":     {"label": "Brushgate Column",   "soldiers": 18, "hp": 12.0, "armour": 10.0, "ma": 32.0, "md": 32.0, "ws": 12.0, "charge": 8.0,  "lead": 70.0, "files": 6,  "speed": 30.0, "bonus_cav": 4.0,  "cav": false, "shield": 0.30, "range": 0.0,   "ammo": 0,  "missile": 0.0, "panic_resistance": 0.60, "silence_immunity": true},
	# Veldarin: fight in forests, avoid open ground.
	"veldarin_forest_sworn": {"label": "Forest-Sworn Archers", "soldiers": 20, "hp": 8.0, "armour": 4.0, "ma": 18.0, "md": 20.0, "ws": 8.0, "charge": 3.0, "lead": 45.0, "files": 10, "speed": 35.0, "bonus_cav": 0.0, "cav": false, "shield": 0.10, "range": 280.0, "ammo": 50, "missile": 11.0, "forest_bonus_ma": 8.0, "forest_bonus_speed": 12.0},
	"veldarin_elder_guard": {"label": "Elder-Guard",        "soldiers": 16, "hp": 14.0, "armour": 18.0, "ma": 36.0, "md": 36.0, "ws": 13.0, "charge": 12.0, "lead": 65.0, "files": 8,  "speed": 32.0, "bonus_cav": 6.0,  "cav": false, "shield": 0.40, "range": 0.0,   "ammo": 0,  "missile": 0.0},
	# Thaladris: song-bound skirmishers sing to the battle; the Elder-Guard
	# doctrine is shared between the two Great Houses.
	"thaladris_song_bound": {"label": "Song-Bound Skirmishers", "soldiers": 22, "hp": 8.0, "armour": 6.0, "ma": 22.0, "md": 22.0, "ws": 9.0, "charge": 4.0, "lead": 55.0, "files": 10, "speed": 38.0, "bonus_cav": 0.0, "cav": false, "shield": 0.15, "range": 200.0, "ammo": 35, "missile": 8.0, "aura_lead": 8.0, "aura_range": 180.0},
	"thaladris_elder_guard": {"label": "Elder-Guard",       "soldiers": 16, "hp": 14.0, "armour": 18.0, "ma": 36.0, "md": 36.0, "ws": 13.0, "charge": 12.0, "lead": 65.0, "files": 8,  "speed": 32.0, "bonus_cav": 6.0,  "cav": false, "shield": 0.40, "range": 0.0,   "ammo": 0,  "missile": 0.0},
	# Southern Reach: marines at home on the coasts, trade-guards whose
	# real value is campaign-level intrigue detection (world.gd).
	"southern_marine":      {"label": "Marines",            "soldiers": 32, "hp": 10.0, "armour": 10.0, "ma": 30.0, "md": 32.0, "ws": 10.0, "charge": 6.0,  "lead": 50.0, "files": 10, "speed": 32.0, "bonus_cav": 4.0,  "cav": false, "shield": 0.40, "range": 130.0, "ammo": 15, "missile": 7.0, "coastal_bonus_ma": 6.0},
	"trade_guard":          {"label": "Trade-Guard",        "soldiers": 24, "hp": 10.0, "armour": 12.0, "ma": 28.0, "md": 32.0, "ws": 10.0, "charge": 4.0,  "lead": 45.0, "files": 10, "speed": 30.0, "bonus_cav": 4.0,  "cav": false, "shield": 0.40, "range": 0.0,   "ammo": 0,  "missile": 0.0},
}


class Regiment:
	var id: int
	var side: int
	var kind: String
	var label: String
	var soldiers: int
	var start_soldiers: int
	var hp_per: float
	var hp_pool: float
	var armour: float
	var ma: float
	var md: float
	var ws: float
	var charge_bonus: float
	var leadership: float
	var bonus_cav: float
	var is_cav: bool
	var shield: float            # missile block fraction (frontal)
	var rng_range: float         # 0 = melee-only
	var ammo: int
	var missile: float           # missile weapon strength
	var files: int
	var speed: float
	var roster_index := -1       # index into the realm's persistent army roster
	# commander trait hooks (TraitData mods), applied at setup
	var dmg_taken_mult := 1.0    # Impulsive commanders spend lives freely
	var morale_bonus := 0.0      # Stoic cohesion / Mercurial mood swings
	var shock_mult := 1.0        # Methodical panic resistance (× unit panic_resistance)
	# cultural unit hooks (Cultural Roster v1.0), read from PRESETS at setup
	var never_routs_above := 0.0 # Berserkers: no rout while strength ≥ this fraction
	var silence_immune := false  # Brushgate: unaffected by Silence terror (endgame content)
	var ward_shield := false     # Arcane Retinue: wards block missiles from every arc
	var aura_lead := 0.0         # Ward-Speakers / Song-Bound: lead projected to friends...
	var aura_range := 0.0        # ...within this distance (px)
	var aura_bonus := 0.0        # lead currently received from friendly auras
	var pos := Vector2.ZERO
	var facing := Vector2.RIGHT
	var has_move_order := false
	var move_target := Vector2.ZERO
	var has_face_order := false  # face this way on arrival (drag orders)
	var face_dir := Vector2.RIGHT
	var hold_facing := false     # ordered facing persists until a new order
	var shock := 0.0
	var lure_ticks := 0          # feigned retreat: dragged out of formation (Module 7)
	var flank_penalty := 0.0     # standing penalty, recomputed each combat tick
	var routed := false
	var fled := false
	var charging_ticks := 0
	var charge_spent := false
	var was_moving := false
	var engaged_id := -1

	func alive() -> bool:
		return not fled and soldiers > 0

	func active() -> bool:
		return alive() and not routed

	func files_now() -> int:
		return mini(files, maxi(soldiers, 1))

	func rows_now() -> int:
		return int(ceil(float(maxi(soldiers, 1)) / files_now()))

	func frontage() -> float:
		return files_now() * BattleSim.SPACING

	func radius() -> float:
		return maxf(frontage(), rows_now() * BattleSim.SPACING * 0.85) * 0.5

	func morale() -> float:
		var depletion := (1.0 - float(soldiers) / maxf(1.0, float(start_soldiers))) * BattleSim.DEPLETION
		return BattleSim.START_MORALE + morale_bonus - shock - flank_penalty - depletion


var regiments: Array = []
var field := Vector2(1200, 640)
var ended := false
var winner := -1
var volleys: Array = []   # [{from, to}] arrows fired this tick; the view consumes these
# Module 7: the Battle Grid's command layer
var side_lead := [0, 0]              # commander lead bonus per side (cascade dampening)
var commanders: Array = [{}, {}]     # per side: {martial, intrigue, prowess, traits[]} — empty = no orders
var tactics_used: Array = [{}, {}]   # per side: tactic kind -> true (each plays once)
var commander_charged := [false, false]  # a chivalric charge was sounded — the fate rolls remember
var commander_corruption := [0.0, 0.0]   # what the field cost each commander's ledger (Magic v1.0)
var combat_ticks := 0                # rounds fought — the AI times its cards by it
var battle_terrain := "plains"       # the province's ground — primal magic reads it


func setup_from_rosters(roster_a: Array, roster_b: Array, lead_bonus_a: int, lead_bonus_b: int, side_names: Array,
		cmdr_traits_a: Array = [], cmdr_traits_b: Array = [], terrain: String = "plains") -> void:
	## Armies come from the campaign's persistent rosters — the men who
	## fall here stay fallen when the map returns. The commander's traits
	## reach onto the field: TraitData battle hooks shape every regiment.
	## `terrain` is the battle province's terrain — forest and coast
	## activate the cultural units' terrain bonuses (Roster v1.0).
	regiments.clear()
	side_lead = [lead_bonus_a, lead_bonus_b]
	battle_terrain = terrain
	for side in 2:
		var roster: Array = roster_a if side == 0 else roster_b
		var lead_bonus := lead_bonus_a if side == 0 else lead_bonus_b
		var cmdr_traits: Array = cmdr_traits_a if side == 0 else cmdr_traits_b
		var vanguard_mult := 1.0     # cavalry damage (Impulsive)
		var center_def_mult := 1.0   # infantry melee defence (Methodical)
		var casualty_mult := 1.0     # own losses (Impulsive spends lives)
		var panic_resist := 0.0      # shock dampening (Methodical)
		var cohesion := 0.0          # baseline morale (Stoic / Mercurial)
		for tname in cmdr_traits:
			if not TraitDB.has_trait(str(tname)):
				continue
			var mods: Dictionary = TraitDB.info(str(tname)).mods
			vanguard_mult *= float(mods.get("vanguard_damage_mult", 1.0))
			center_def_mult *= float(mods.get("center_line_defense_mult", 1.0))
			casualty_mult *= float(mods.get("casualty_rate_mult", 1.0))
			panic_resist += float(mods.get("panic_resistance", 0.0))
			cohesion += float(mods.get("levy_cohesion_baseline", 0.0))
		var n := roster.size()
		for i in n:
			var entry: Dictionary = roster[i]
			var kind: String = entry["kind"]
			var p: Dictionary = PRESETS[kind]
			var r := Regiment.new()
			r.id = regiments.size()
			r.side = side
			r.kind = kind
			r.roster_index = i
			r.label = "%s %s" % [side_names[side], p["label"]]
			r.soldiers = maxi(1, int(entry["soldiers"]))
			r.start_soldiers = r.soldiers
			r.hp_per = p["hp"]
			r.hp_pool = r.soldiers * r.hp_per
			r.armour = p["armour"]
			r.ma = p["ma"]
			r.md = p["md"]
			r.ws = p["ws"]
			r.charge_bonus = p["charge"]
			r.leadership = p["lead"] + float(lead_bonus) * 0.5
			r.bonus_cav = p["bonus_cav"]
			r.is_cav = p["cav"]
			r.shield = p["shield"]
			r.rng_range = p["range"]
			r.ammo = p["ammo"]
			r.missile = p["missile"]
			r.files = p["files"]
			r.speed = p["speed"]
			# cultural unit hooks — absent keys leave the defaults
			r.never_routs_above = float(p.get("never_routs_above", 0.0))
			r.silence_immune = bool(p.get("silence_immunity", false))
			r.ward_shield = bool(p.get("ward_shield", false))
			r.aura_lead = float(p.get("aura_lead", 0.0))
			r.aura_range = float(p.get("aura_range", 0.0))
			if terrain == "forest":
				r.ma += float(p.get("forest_bonus_ma", 0.0))
				r.speed += float(p.get("forest_bonus_speed", 0.0))
			elif terrain == "coast":
				r.ma += float(p.get("coastal_bonus_ma", 0.0))
			if r.is_cav:
				r.ws *= vanguard_mult
			else:
				r.md *= center_def_mult
			r.dmg_taken_mult = casualty_mult
			# commander panic resistance and the unit's own compound
			r.shock_mult = maxf(0.1, 1.0 - panic_resist) * (1.0 - float(p.get("panic_resistance", 0.0)))
			r.morale_bonus = cohesion
			var x := 190.0 if side == 0 else field.x - 190.0
			r.pos = Vector2(x, field.y * 0.5 + (float(i) - float(n - 1) * 0.5) * 110.0)
			r.facing = Vector2.RIGHT if side == 0 else Vector2.LEFT
			regiments.append(r)


func run_headless(max_frames: int = 30000) -> void:
	## Auto-resolve: both sides fight under AI, no rendering.
	var frames := 0
	while not ended and frames < max_frames:
		move_step(0.1)
		frames += 1
		if frames % 5 == 0:
			combat_tick()
			ai_step(true)
	if not ended:
		ended = true
		winner = 0 if survivors_fraction(0) >= survivors_fraction(1) else 1
		battle_ended.emit(winner)


# --------------------------------------- the Battle Grid's orders (Module 7)

func set_commander_info(side: int, info: Dictionary) -> void:
	## {martial, intrigue, prowess, traits[], names} — what the commander
	## brings to the command tent. Without it, no tactical orders can be
	## given — and no craft reaches the field (Magic Injection v1.0).
	commanders[side] = info
	# the commander's magical practice, read from the same trait database
	var arcane := 1.0
	var primal := 1.0
	var corrupt := 1.0
	var song := 0.0
	var discipline := 1.0
	for tname in info.get("traits", []):
		if not TraitDB.has_trait(str(tname)):
			continue
		var mods: Dictionary = TraitDB.info(str(tname)).mods
		arcane *= float(mods.get("arcane_channel_mult", 1.0))
		primal *= float(mods.get("primal_channel_mult", 1.0))
		corrupt *= float(mods.get("corruption_channel_mult", 1.0))
		song += float(mods.get("song_aura_baseline", 0.0))
		discipline *= float(mods.get("discipline_binding_mult", 1.0))
	var primal_ground: float = 0.0
	match battle_terrain:
		"forest", "wetland", "river_valley":
			primal_ground = 1.0
		"plains", "hills":
			primal_ground = 0.9
		"coast":
			primal_ground = 0.8
		"mountain":
			primal_ground = 0.6
		_:
			primal_ground = 0.0  # ashfields and ruins: the channel is gone
	for r: Regiment in regiments:
		if r.side == side:
			# a Wizard's wards ride with the arcane retinues' volleys
			if arcane > 1.0 and r.ward_shield:
				r.missile *= arcane
			# the primal channel steadies footsoldiers on living ground
			if primal > 1.0 and primal_ground > 0.0 and not r.is_cav and r.rng_range <= 0.0:
				r.ma += 6.0 * (primal - 1.0) * primal_ground / 0.3
			# the song of the carried names steadies every line that hears it
			if song > 0.0:
				var names := int(info.get("names", 0))
				r.morale_bonus += 100.0 * song * clampf(1.0 + float(names) / 200.0, 1.0, 2.0)
			# the Brushgate stillness spreads from the command tent
			if discipline > 1.0:
				r.shock_mult *= 0.90
		elif corrupt > 1.0 and not r.silence_immune:
			# something rides with the enemy commander, and the lines feel it
			r.shock += 10.0 * (corrupt - 1.0) / 0.4 * r.shock_mult
	if corrupt > 1.0:
		commander_corruption[side] += 1.5  # commanding with the Patron's help goes on the ledger


func tactic_gate(side: int, kind: String) -> String:
	## "" = the order can be given. Otherwise, why it cannot.
	if ended:
		return "The field is decided."
	var cmdr: Dictionary = commanders[side]
	if cmdr.is_empty():
		return "No commander stands at the map table."
	if tactics_used[side].has(kind):
		return "That card has been played."
	var traits: Array = cmdr.get("traits", [])
	match kind:
		"feigned_retreat":
			if not (traits.has("Deceitful") or int(cmdr.get("intrigue", 0)) >= 12):
				return "It takes a Deceitful mind (or Intrigue 12+) to sell a false rout."
		"commit_reserve":
			if not (traits.has("Patient") or int(cmdr.get("martial", 0)) >= 12):
				return "Only a Patient hand (or Martial 12+) holds a reserve this long."
			if _rearmost_own(side) == null:
				return "There is no reserve left to commit."
		"chivalric_charge":
			if not (traits.has("Wrathful") or int(cmdr.get("prowess", 0)) >= 12):
				return "It takes Wrathful blood (or Prowess 12+) to lead the charge yourself."
			if _charge_regiment(side) == null:
				return "No formation fit to carry the charge."
		"uncontrolled_channel":
			if not traits.has("Arcane-Blooded"):
				return "There is no arcane blood at the map table."
			if traits.has("Academy-Sworn"):
				return "Academy discipline forbids exactly this — that is what the discipline is."
			if not _has_ranged(side):
				return "Nothing on the field can carry the channel."
		"reap_the_bargain":
			if not traits.has("Patron-Bound"):
				return "There is no bargain here to reap."
	return ""


func _has_ranged(side: int) -> bool:
	for r: Regiment in regiments:
		if r.side == side and r.active() and r.rng_range > 0.0:
			return true
	return false


func use_tactic(side: int, kind: String) -> String:
	var gate := tactic_gate(side, kind)
	if gate != "":
		return gate
	tactics_used[side][kind] = true
	match kind:
		"feigned_retreat":
			_do_feigned_retreat(side)
		"commit_reserve":
			_do_commit_reserve(side)
		"chivalric_charge":
			_do_chivalric_charge(side)
		"uncontrolled_channel":
			_do_uncontrolled_channel(side)
		"reap_the_bargain":
			_do_reap_the_bargain(side)
	return ""


func _do_uncontrolled_channel(side: int) -> void:
	## The desperate untrained-caster move (Magic v1.0): raw arcana poured
	## through every volley on the field — and straight onto the ledger.
	for r: Regiment in regiments:
		if r.side == side and r.rng_range > 0.0:
			r.missile *= CHANNEL_MISSILE_MULT
			r.ammo += 10
	commander_corruption[side] += 2.0
	event.emit("The commander opens an uncontrolled channel! Every volley burns brighter — and something takes note.")


func _do_reap_the_bargain(side: int) -> void:
	## The Patron collects (Magic v1.0): every enemy line feels it at
	## once. The price is immediate, personal, and not negotiable.
	for r: Regiment in regiments:
		if r.side != side and r.active() and not r.silence_immune:
			r.shock += REAP_SHOCK * r.shock_mult
	commander_corruption[side] += 5.0
	event.emit("The commander reaps the bargain! A wrongness sweeps the enemy lines — and the ledger turns another page.")


func _do_feigned_retreat(side: int) -> void:
	## The opposing flank is baited out of the line; the center it was
	## guarding stands exposed while the lure lasts.
	var bait := _flankmost_enemy(side)
	if bait == null:
		return
	bait.lure_ticks = LURE_TICKS
	bait.engaged_id = -1
	bait.has_move_order = true
	var toward_x := 140.0 if side == 0 else field.x - 140.0
	bait.move_target = Vector2(toward_x, bait.pos.y).clamp(Vector2(30, 30), field - Vector2(30, 30))
	var center := _centermost(1 - side, bait)
	if center != null:
		center.shock += LURE_CENTER_SHOCK * center.shock_mult
	event.emit("A feigned retreat! %s break formation to give chase — and the line behind them opens." % bait.label)


func _do_commit_reserve(side: int) -> void:
	## Fresh men into the worst of it: the rearguard marches for the
	## regiment closest to breaking, and the sight of banners steadies it.
	var reserve := _rearmost_own(side)
	if reserve == null:
		return
	var weakest := _worst_morale_own(side, reserve)
	reserve.shock = 0.0
	reserve.morale_bonus += RESERVE_COHESION
	reserve.charge_spent = false
	if weakest != null:
		reserve.has_move_order = true
		reserve.move_target = weakest.pos
		weakest.shock = maxf(0.0, weakest.shock - RESERVE_HEART)
		event.emit("The reserve is committed! %s march for %s's wavering line." % [reserve.label, weakest.label])
	else:
		event.emit("The reserve is committed! %s advance." % reserve.label)


func _do_chivalric_charge(side: int) -> void:
	## The commander couches his own lance. Massive output, paid for in
	## exposure — his fate rolls remember the charge after the battle.
	var spear := _charge_regiment(side)
	if spear == null:
		return
	spear.charging_ticks = CHARGE_DURATION * 2
	spear.charge_spent = true
	spear.ws *= CHARGE_WS_MULT
	spear.dmg_taken_mult *= CHARGE_TAKEN_MULT
	var prey := _centermost(1 - side, null)
	if prey != null:
		spear.has_move_order = true
		spear.move_target = prey.pos
		prey.shock += CHARGE_SHOCK
	commander_charged[side] = true
	event.emit("A chivalric charge! The commander rides at the head of %s." % spear.label)


func _flankmost_enemy(side: int) -> Regiment:
	## The enemy regiment farthest from the battle line's center — the
	## flank a false rout is most likely to peel loose. Melee only; a
	## skirmish screen chasing shadows costs its side nothing.
	var best: Regiment = null
	var best_off := -1.0
	for r: Regiment in regiments:
		if r.side == side or not r.active() or r.lure_ticks > 0 or r.rng_range > 0.0:
			continue
		var off := absf(r.pos.y - field.y * 0.5)
		if off > best_off:
			best_off = off
			best = r
	return best


func _centermost(side: int, excluding: Regiment) -> Regiment:
	var best: Regiment = null
	var best_off := INF
	for r: Regiment in regiments:
		if r.side != side or not r.active() or r == excluding:
			continue
		var off := absf(r.pos.y - field.y * 0.5)
		if off < best_off:
			best_off = off
			best = r
	return best


func _rearmost_own(side: int) -> Regiment:
	## The unengaged regiment deepest in its own half — the rearguard.
	var best: Regiment = null
	var best_x := 0.0
	for r: Regiment in regiments:
		if r.side != side or not r.active() or r.engaged_id >= 0:
			continue
		var depth := field.x - r.pos.x if side == 0 else r.pos.x
		if best == null or depth > best_x:
			best_x = depth
			best = r
	return best


func _worst_morale_own(side: int, excluding: Regiment) -> Regiment:
	var best: Regiment = null
	for r: Regiment in regiments:
		if r.side != side or not r.active() or r == excluding:
			continue
		if best == null or r.morale() < best.morale():
			best = r
	return best


func _charge_regiment(side: int) -> Regiment:
	## Cavalry carries the charge if any still rides; else the hardest
	## hitters afoot.
	var best: Regiment = null
	for r: Regiment in regiments:
		if r.side != side or not r.active() or r.rng_range > 0.0:
			continue
		if best == null or (r.is_cav and not best.is_cav) \
				or (r.is_cav == best.is_cav and r.ws * float(r.soldiers) > best.ws * float(best.soldiers)):
			best = r
	return best


func _ai_tactics(side: int) -> void:
	## The AI plays its cards on simple, deterministic cues: bait early,
	## charge once the lines are locked, commit the reserve when a line
	## wavers. A commander without the temperament simply never does.
	if commanders[side].is_empty():
		return
	if combat_ticks == 6 and tactic_gate(side, "feigned_retreat") == "":
		var _e := use_tactic(side, "feigned_retreat")
	if combat_ticks >= 10 and tactic_gate(side, "chivalric_charge") == "":
		var _e2 := use_tactic(side, "chivalric_charge")
	if combat_ticks >= 8 and tactic_gate(side, "uncontrolled_channel") == "":
		var _e4 := use_tactic(side, "uncontrolled_channel")
	if combat_ticks >= 14 and tactic_gate(side, "reap_the_bargain") == "":
		var _e5 := use_tactic(side, "reap_the_bargain")
	if tactic_gate(side, "commit_reserve") == "":
		for r: Regiment in regiments:
			if r.side == side and r.active() and r.morale() < 30.0:
				var _e3 := use_tactic(side, "commit_reserve")
				break


func _cascade_panic(router: Regiment) -> void:
	## The Cascade Panic Matrix: a breaking formation runs back through
	## its own lines, and the conscripts near it check their own courage.
	## Base fear, dampened by the commander's presence; professionals hold.
	var fear := maxf(CASCADE_MIN, CASCADE_SHOCK - float(side_lead[router.side]) * CASCADE_LEAD_DAMP)
	var spread := false
	for f: Regiment in regiments:
		if f.side != router.side or not f.active() or f == router or f.kind != "levy":
			continue
		if f.pos.distance_to(router.pos) > CASCADE_RANGE:
			continue
		f.shock += fear * f.shock_mult
		spread = true
	if spread:
		event.emit("Panic ripples through the levies as %s stream back through their own lines!" % router.label)


# ---------------------------------------------------------------- per-frame

func move_step(delta: float) -> void:
	if ended:
		return
	for r: Regiment in regiments:
		if not r.alive():
			continue
		if r.routed:
			var flee := Vector2.LEFT if r.side == 0 else Vector2.RIGHT
			r.pos += flee * r.speed * 1.35 * delta
			r.facing = flee
			if r.pos.x < -80.0 or r.pos.x > field.x + 80.0:
				r.fled = true
				_check_end()
			continue

		# a lured regiment chases the false rout — deaf to everything else
		if r.lure_ticks > 0 and r.has_move_order:
			var to_lure := r.move_target - r.pos
			if to_lure.length() >= 6.0:
				var lure_dir := to_lure.normalized()
				r.pos += lure_dir * r.speed * delta
				r.facing = lure_dir
				r.was_moving = true
				continue

		# sticky engagement: keep fighting the current foe while in contact,
		# so a unit pinned frontally can be struck in the rear by a second one
		var foe: Regiment = null
		if r.engaged_id >= 0:
			var held: Regiment = regiments[r.engaged_id]
			if held.active() and _in_contact(r, held):
				foe = held
		if foe == null:
			var enemy := _nearest_enemy(r)
			if enemy != null and _in_contact(r, enemy):
				foe = enemy
		r.engaged_id = foe.id if foe != null else -1

		if foe != null:
			r.has_move_order = false
			r.hold_facing = false
			r.facing = (foe.pos - r.pos).normalized()
			if r.was_moving and not r.charge_spent:
				r.charging_ticks = CHARGE_DURATION
				r.charge_spent = true
				foe.shock += CHARGE_SHOCK
				event.emit("%s charges into %s!" % [r.label, foe.label])
			r.was_moving = false
			continue

		if r.has_move_order:
			var to := r.move_target - r.pos
			if to.length() < 6.0:
				r.has_move_order = false
				r.was_moving = false
				if r.has_face_order:
					r.facing = r.face_dir
					r.has_face_order = false
					r.hold_facing = true
			else:
				var dir := to.normalized()
				r.pos += dir * r.speed * delta
				r.facing = dir
				r.was_moving = true
		else:
			r.was_moving = false
			# idle units turn toward the nearest threat, but slowly —
			# facing is a real commitment, which is what makes flanking work
			if not r.hold_facing:
				var enemy2 := _nearest_enemy(r)
				if enemy2 != null:
					var desired := (enemy2.pos - r.pos).normalized()
					r.facing = r.facing.slerp(desired, minf(1.0, 1.8 * delta)).normalized()
	_separate()


func _separate() -> void:
	## Regiments are solid: allies keep formation distance, enemies can
	## press to melee range but never stack on top of each other.
	for i in regiments.size():
		var a: Regiment = regiments[i]
		if not a.alive() or a.routed:
			continue
		for j in range(i + 1, regiments.size()):
			var b: Regiment = regiments[j]
			if not b.alive() or b.routed:
				continue
			var min_d := (a.radius() + b.radius()) * (0.9 if a.side == b.side else 0.55)
			var delta := b.pos - a.pos
			var d := delta.length()
			if d < 0.001:
				b.pos += Vector2(1.0, 0.0)
				continue
			if d < min_d:
				var push := delta.normalized() * (min_d - d) * 0.5
				a.pos -= push
				b.pos += push


func ai_step(control_side_0: bool) -> void:
	## Simple AI: unengaged regiments march at the nearest enemy.
	## Side 0 is normally the player; pass true to automate both sides.
	_ai_tactics(1)
	if control_side_0:
		_ai_tactics(0)
	for r: Regiment in regiments:
		if not r.active():
			continue
		if r.side == 0 and not control_side_0:
			continue
		if r.engaged_id >= 0 or r.lure_ticks > 0:
			continue
		if r.rng_range > 0.0 and r.ammo > 0:
			# archers skirmish: keep the range open, kite anything that closes
			var near := _nearest_enemy(r)
			if near != null:
				var d := r.pos.distance_to(near.pos)
				if d < 110.0:
					var away := (r.pos - near.pos).normalized()
					r.has_move_order = true
					r.move_target = (r.pos + away * 140.0).clamp(Vector2(30, 30), field - Vector2(30, 30))
				elif d > r.rng_range * 0.9:
					r.has_move_order = true
					r.move_target = near.pos
				else:
					r.has_move_order = false
			continue
		if r.is_cav:
			# cavalry ride for the enemy's rear before committing
			var prey := _flank_target(r)
			if prey != null:
				var rear_point: Vector2 = prey.pos - prey.facing * (prey.radius() + 80.0)
				rear_point = rear_point.clamp(Vector2(30, 30), field - Vector2(30, 30))
				r.has_move_order = true
				r.move_target = rear_point if r.pos.distance_to(rear_point) > 50.0 else prey.pos
				continue
		var enemy := _nearest_enemy(r)
		if enemy != null:
			r.has_move_order = true
			r.move_target = enemy.pos


func _flank_target(r: Regiment) -> Regiment:
	## Prefer the nearest enemy infantry; fall back to anyone.
	var best: Regiment = null
	var best_d := INF
	for other: Regiment in regiments:
		if other.side == r.side or not other.active() or other.is_cav:
			continue
		var d := r.pos.distance_squared_to(other.pos)
		if d < best_d:
			best_d = d
			best = other
	if best == null:
		best = _nearest_enemy(r)
	return best


# ---------------------------------------------------------------- combat tick

func combat_tick() -> void:
	if ended:
		return
	combat_ticks += 1
	var dmg := {}
	for r: Regiment in regiments:
		r.flank_penalty = 0.0
		if r.lure_ticks > 0:
			r.lure_ticks -= 1
			# out of formation: anyone striking the lured takes them in the flank
			r.flank_penalty = maxf(r.flank_penalty, FLANKED_PENALTY)
	for r: Regiment in regiments:
		if not r.active() or r.engaged_id < 0 or r.lure_ticks > 0:
			continue
		var t: Regiment = regiments[r.engaged_id]
		if not t.alive():
			continue
		# envelopment: a wider line brings up to 1.4× the enemy frontage to bear
		var engaged_count := mini(mini(r.files_now(), int(float(t.files_now()) * 1.4)), mini(r.soldiers, t.soldiers))
		var ma := r.ma
		var ws := r.ws
		var mult := 1.0
		if t.is_cav and r.bonus_cav > 0.0:
			ma += r.bonus_cav
			ws += r.bonus_cav * 0.5
		if r.charging_ticks > 0:
			var decay := float(r.charging_ticks) / float(CHARGE_DURATION)
			ma += r.charge_bonus * decay
			mult *= 1.0 + (r.charge_bonus / CHARGE_SCALE) * decay
			r.charging_ticks -= 1
		match _arc(r, t):
			1:
				mult *= FLANK_MULT
				t.flank_penalty = maxf(t.flank_penalty, FLANKED_PENALTY)
			2:
				mult *= REAR_MULT
				t.flank_penalty = maxf(t.flank_penalty, REAR_PENALTY)
		if t.lure_ticks > 0:
			mult *= FLANK_MULT  # a formation chasing shadows has no line to hold
		var hit := clampf(BASE_HIT + (ma - t.md) * HIT_PER_POINT, HIT_MIN, HIT_MAX)
		var per_hit := maxf(ws * (ARMOUR_PIVOT / (ARMOUR_PIVOT + t.armour)), ws * CHIP_FRACTION)
		dmg[t.id] = dmg.get(t.id, 0.0) + float(engaged_count) * ATTACKS_PER_TICK * hit * per_hit * mult

	_ranged_tick(dmg)
	_aura_tick()

	for r: Regiment in regiments:
		if not r.alive():
			continue
		if dmg.has(r.id):
			var before := r.soldiers
			r.hp_pool = maxf(0.0, r.hp_pool - dmg[r.id] * r.dmg_taken_mult)
			r.soldiers = int(ceil(r.hp_pool / r.hp_per))
			var cas := before - r.soldiers
			if cas > 0:
				r.shock += (float(cas) / maxf(1.0, float(before))) * CASUALTY_SHOCK * r.shock_mult
		r.shock = maxf(0.0, r.shock - (r.leadership + r.aura_bonus) * LEADERSHIP_REGEN)
		if r.soldiers <= 0:
			r.fled = true
			event.emit("%s is wiped out!" % r.label)
		elif not r.routed and r.morale() <= _rout_threshold(r):
			if r.never_routs_above > 0.0 and _strength_fraction(r) >= r.never_routs_above:
				continue  # the Berserker oath holds while a quarter of them stand
			r.routed = true
			event.emit("%s breaks and runs!" % r.label)
			_cascade_panic(r)
	_check_end()


func _rout_threshold(r: Regiment) -> float:
	## Berserkers past their oath-threshold still take 40% deeper shock
	## before breaking (Cultural Roster v1.0).
	return -40.0 if r.never_routs_above > 0.0 else 0.0


func _strength_fraction(r: Regiment) -> float:
	return float(r.soldiers) / maxf(1.0, float(r.start_soldiers))


func _aura_tick() -> void:
	## Ward-Speaker and Song-Bound auras: each regiment receives the best
	## friendly aura in range (auras project outward, never onto their
	## own bearers, and do not stack).
	for r: Regiment in regiments:
		r.aura_bonus = 0.0
	for src: Regiment in regiments:
		if src.aura_lead <= 0.0 or not src.active():
			continue
		for r: Regiment in regiments:
			if r == src or r.side != src.side or not r.active():
				continue
			if src.pos.distance_to(r.pos) <= src.aura_range:
				r.aura_bonus = maxf(r.aura_bonus, src.aura_lead)


func _ranged_tick(dmg: Dictionary) -> void:
	## Archers loose a volley at the nearest enemy in range — unless they
	## are locked in melee or out of arrows. Shields block by facing arc.
	if volleys.size() > 200:
		volleys.clear()
	for r: Regiment in regiments:
		if not r.active() or r.engaged_id >= 0 or r.rng_range <= 0.0 or r.ammo <= 0:
			continue
		var t := _nearest_enemy(r)
		if t == null or r.pos.distance_to(t.pos) > r.rng_range:
			continue
		r.ammo -= 1
		# arcane wards protect every arc; physical shields only by facing
		var block: float = t.shield * (1.0 if t.ward_shield else SHIELD_ARC_FACTOR[_arc(r, t)])
		var per_hit := maxf(r.missile * (ARMOUR_PIVOT / (ARMOUR_PIVOT + t.armour)), r.missile * CHIP_FRACTION)
		dmg[t.id] = dmg.get(t.id, 0.0) + float(r.soldiers) * RANGED_RATE * RANGED_HIT * per_hit * (1.0 - block)
		volleys.append({"from": r.pos, "to": t.pos})
		if r.ammo == 0:
			event.emit("%s have spent their arrows." % r.label)


# ---------------------------------------------------------------- queries

func survivors_fraction(side: int) -> float:
	var start := 0
	var now := 0
	for r: Regiment in regiments:
		if r.side != side:
			continue
		start += r.start_soldiers
		if r.alive():
			now += r.soldiers
	return float(now) / maxf(1.0, float(start))


func _nearest_enemy(r: Regiment) -> Regiment:
	var best: Regiment = null
	var best_d := INF
	for other in regiments:
		if other.side == r.side or not other.active():
			continue
		var d := r.pos.distance_squared_to(other.pos)
		if d < best_d:
			best_d = d
			best = other
	return best


func _in_contact(a: Regiment, b: Regiment) -> bool:
	return a.pos.distance_to(b.pos) < a.radius() + b.radius() + 4.0


func _arc(att: Regiment, def: Regiment) -> int:
	## 0 = front, 1 = flank, 2 = rear — from the angle between the attack
	## direction and the defender's facing (the Combat Lab arc model).
	var d := (def.pos - att.pos).normalized().dot(def.facing)
	if d > 0.5:
		return 2
	if d > -0.5:
		return 1
	return 0


func _check_end() -> void:
	if ended:
		return
	var active := [0, 0]
	for r: Regiment in regiments:
		if r.active():
			active[r.side] += 1
	if active[0] > 0 and active[1] > 0:
		return
	ended = true
	if active[0] == 0 and active[1] == 0:
		winner = -1
	else:
		winner = 0 if active[0] > 0 else 1
	battle_ended.emit(winner)
