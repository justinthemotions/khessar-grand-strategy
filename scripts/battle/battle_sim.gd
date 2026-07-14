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
const ROW_SPACING := SPACING * 0.85
const SOLDIER_FOOTPRINT := 4.8  # formation collision width of one sprite
const CONTACT_GAP := 1.2        # weapon/body gap between opposing front ranks
const CONTACT_TOLERANCE := 2.0  # sticky allowance for floating-point movement
const ALLY_GAP := 5.0           # friendly formations retain a readable seam
const MAX_MOVE_SUBSTEP := 1.5   # prevents fast simulation steps tunnelling through a line
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

# Tactical Combat System v1.0 (Opus doc, 2026-07-08): the Khessari layer.
# Casting is BINARY — a working either fires or fizzles (reliability gates,
# never damage multipliers). The battle rolls its gates on its own seeded
# stream (`brng`) so the campaign's streams never feel the field; identical
# setups still produce identical battles.
const BATTLE_SEED := 212                 # the battle's own dice
const SILENCE_LEAD_PENALTY := 8.0        # leadership starved by unquiet ground (non-immune lines)
const SILENCE_DMG_BONUS := 1.05          # silence-born units fight harder under their own sky
const TERROR_RANGE := 150.0              # how far a Warden-Dead company's wrongness carries
const CONFUSION_THRESHOLD := 0.25        # Returned below quarter strength lose coordination...
const CONFUSION_MULT := 0.7              # ...their strikes land without purpose
const OATH_CONFLICT_MULT := 1.10         # the Order's oath answers heresy with real weight
const THRESHOLD_VS_SILENCE_MULT := 1.20  # Gravewarden war against the unwitnessed dead
const ARCANE_VS_RETURNED_MULT := 1.4     # arcane volleys find what swords cannot
const CRIT_BASE := 0.05                  # deterministic EV critical layer: dmg × (1 + chance/4)
const CRIT_BRUSHGATE := 0.05             # the study of anatomical vulnerability
const CRIT_OATH_VS_MARKED := 0.03        # oath-magic reads corrupted flesh precisely
# the Cleric's office on the field (doc §3.3)
const CLERIC_PRESENCE := 5.0             # the candles steady the line even unanswered
const CLERIC_PRESENCE_ZEALOUS := 8.0     # a Zealous office grows regardless of results
const BLESS_MA := 4.0                    # +ma when the prayer is actually answered
const BLESS_MD := 2.0
# the Paladin's aura (doc §3.4)
const DEVOTION_LEAD := 8.0
const DEVOTION_MD := 2.0
const OATH_REGEN_MULT := 1.25            # oath-sworn recover their nerve faster
# vigour (doc §8): TW's six stages folded to five, scaled to this sim's
# tick economy (battles run ~100-250 combat ticks, not 30k vigour points)
const VIGOUR_STAGES: Array[float] = [30.0, 60.0, 95.0, 130.0]
const VIGOUR_PENALTY: Array[float] = [0.0, 0.05, 0.10, 0.15, 0.20]
const VIGOUR_FIGHT := 1.0                # per combat tick locked in melee
const VIGOUR_MOVE := 0.35                # per combat tick on the march
const VIGOUR_CHARGE := 1.0               # charging is spent on top of fighting

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
	"brushgate_column":     {"label": "Brushgate Column",   "soldiers": 18, "hp": 12.0, "armour": 10.0, "ma": 32.0, "md": 32.0, "ws": 12.0, "charge": 8.0,  "lead": 70.0, "files": 6,  "speed": 30.0, "bonus_cav": 4.0,  "cav": false, "shield": 0.30, "range": 0.0,   "ammo": 0,  "missile": 0.0, "panic_resistance": 0.60, "silence_immunity": true, "vigour_mult": 0.60},
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

	# --- Tactical Combat System v1.0: the forces the Silence made ---
	# The Order of the Vigil-Sworn: devastating in the defense, oath-bound
	# (cannot rout while their commander's oath holds), and 60% warded
	# against Silence-touched attack — the Order's version, not Brushgate's.
	"vigil_sworn_elite":    {"label": "Vigil-Sworn Elite",  "soldiers": 24, "hp": 12.0, "armour": 18.0, "ma": 32.0, "md": 34.0, "ws": 12.0, "charge": 12.0, "lead": 65.0, "files": 8,  "speed": 30.0, "bonus_cav": 4.0,  "cav": false, "shield": 0.40, "range": 0.0,   "ammo": 0,  "missile": 0.0, "panic_resistance": 0.45, "silence_immunity": 0.60, "oath_bound": true},
	# Chaplains sing the old litany at the rear: a +12 leadership aura that
	# reaches only the Order's own regiments (300px, doc §5.12).
	"reactionary_chaplain": {"label": "Reactionary Chaplains", "soldiers": 16, "hp": 10.0, "armour": 8.0, "ma": 22.0, "md": 26.0, "ws": 8.0, "charge": 4.0, "lead": 65.0, "files": 8, "speed": 28.0, "bonus_cav": 0.0, "cav": false, "shield": 0.20, "range": 0.0, "ammo": 0, "missile": 0.0, "aura_lead": 12.0, "aura_range": 300.0, "aura_filter": "order"},
	# Caeris's Warden-Dead: Returned in various stages of settling. No
	# morale mechanic at all — they cannot be broken, only dispersed; below
	# quarter strength they grow confused instead. Their wrongness starves
	# nearby enemy nerve (silence_terror), and arcane volleys find them
	# where swords cannot. Defensive by nature: they hold, never seek.
	"warden_dead":          {"label": "Warden-Dead",        "soldiers": 40, "hp": 8.0,  "armour": 2.0,  "ma": 22.0, "md": 20.0, "ws": 8.0,  "charge": 4.0,  "lead": 0.0,  "files": 10, "speed": 24.0, "bonus_cav": 0.0,  "cav": false, "shield": 0.15, "range": 0.0,   "ammo": 0,  "missile": 0.0, "no_morale": true, "silence_terror": 0.30, "silence_kind": true, "defensive": true},
	# Caeris's personal retinue: elite Settled, deployed only when she
	# herself takes the field. Not recruitable by any living crown.
	"caeris_retinue":       {"label": "Caeris's Retinue",   "soldiers": 12, "hp": 12.0, "armour": 8.0,  "ma": 30.0, "md": 30.0, "ws": 12.0, "charge": 12.0, "lead": 55.0, "files": 6,  "speed": 30.0, "bonus_cav": 0.0,  "cav": false, "shield": 0.25, "range": 0.0,   "ammo": 0,  "missile": 0.0, "silence_immunity": 1.0, "silence_kind": true},
	# Forsaken militia: conviction instead of drill — +8 leadership when
	# the enemy line carries the old order's banners (Order regiments).
	"forsaken_militia":     {"label": "Forsaken Militia",   "soldiers": 36, "hp": 9.0,  "armour": 8.0,  "ma": 26.0, "md": 26.0, "ws": 10.0, "charge": 8.0,  "lead": 55.0, "files": 10, "speed": 30.0, "bonus_cav": 2.0,  "cav": false, "shield": 0.30, "range": 0.0,   "ammo": 0,  "missile": 0.0, "conviction_lead": 8.0},
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
	var silence_immune := false  # full silence immunity (Brushgate; immunity ≥ 1.0)
	var ward_shield := false     # Arcane Retinue: wards block missiles from every arc
	var aura_lead := 0.0         # Ward-Speakers / Song-Bound: lead projected to friends...
	var aura_range := 0.0        # ...within this distance (px)
	var aura_bonus := 0.0        # lead currently received from friendly auras
	# Tactical Combat System v1.0 hooks
	var silence_immunity := 0.0  # 0..1 — how much of the Silence's pressure never lands
	var no_morale := false       # Returned: cannot be broken, only dispersed
	var silence_terror := 0.0    # wrongness projected onto enemy nerve within TERROR_RANGE
	var silence_kind := false    # a Silence-born entity (Warden-Dead, the Settled)
	var defensive := false       # holds its ground; never seeks the enemy
	var oath_bound := false      # an Order regiment whose discipline is oath-magic
	var oath_holds := false      # set at setup: the commander's oath-token is whole
	var conviction_lead := 0.0   # Forsaken: +lead against the old order's banners...
	var conviction_on := false   # ...armed once the enemy line shows them
	var aura_filter := ""        # "" = all friends; "order" = oath-bound regiments only
	var vigour := 0.0            # fatigue accumulator (doc §8)
	var vigour_mult := 1.0       # Brushgate 0.60 — the discipline spends itself slowly
	var fatigue := 0.0           # current stage penalty, cached each combat tick
	var lead_regen_mult := 1.0   # oath-sworn recover 25% faster
	var terror_penalty := 0.0    # fraction of morale regen starved by nearby terror
	var crit_mult := 1.0         # deterministic EV critical layer (commander-set)
	var dmg_vs_silence := 1.0    # Gravewarden-witnessed side: × vs silence-born units
	var oath_conflict := false   # the Order facing heresy: OATH_CONFLICT_MULT applies
	# Hero System v1.0 hooks: the hero's hand on this line
	var hero_ma_bonus := 0.0     # projected by hero auras, recomputed each aura tick
	var hero_md_bonus := 0.0
	var hero_missile_block := 0.0
	var hero_terror_block := 0.0
	var fx_ticks := 0            # a timed working holds this line (one at a time)
	var fx_ma := 0.0
	var fx_md := 0.0
	var fx_ws_mult := 1.0
	var fx_dmg_mult := 1.0       # damage-taken multiplier while the working holds
	var fx_speed_mult := 1.0
	var fx_lead := 0.0
	var fx_missile_immune := false

	func fx_on() -> bool:
		return fx_ticks > 0
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

	func files_for_count(count: int) -> int:
		## Preserve the ordered aspect ratio while contracting both frontage and
		## depth as casualties mount. Full-strength formations still obey the
		## player's exact files order.
		count = maxi(count, 1)
		var maximum := mini(maxi(files, 1), count)
		if count >= start_soldiers:
			return maximum
		var start_rows := int(ceil(float(maxi(start_soldiers, 1)) / float(maxi(files, 1))))
		var aspect := float(maxi(files, 1)) / float(maxi(start_rows, 1))
		var contracted := int(ceil(sqrt(float(count) * aspect)))
		return clampi(contracted, 1, maximum)

	func rows_for_count(count: int) -> int:
		return int(ceil(float(maxi(count, 1)) / float(files_for_count(count))))

	func soldier_footprint() -> float:
		return 15.0 if is_cav else BattleSim.SOLDIER_FOOTPRINT

	func file_spacing() -> float:
		return 10.0 if is_cav else BattleSim.SPACING

	func row_spacing() -> float:
		return 10.0 if is_cav else BattleSim.ROW_SPACING

	func files_now() -> int:
		return files_for_count(soldiers)

	func rows_now() -> int:
		return rows_for_count(soldiers)

	func frontage_for_count(count: int) -> float:
		return float(files_for_count(count) - 1) * file_spacing() + soldier_footprint()

	func depth_for_count(count: int) -> float:
		return float(rows_for_count(count) - 1) * row_spacing() + soldier_footprint()

	func frontage() -> float:
		return frontage_for_count(soldiers)

	func depth() -> float:
		return depth_for_count(soldiers)

	func half_extent_along(direction: Vector2) -> float:
		if direction.length_squared() < 0.0001:
			return 0.0
		var d := direction.normalized()
		var forward := facing.normalized()
		var across := forward.rotated(PI * 0.5)
		return absf(d.dot(across)) * frontage() * 0.5 + absf(d.dot(forward)) * depth() * 0.5

	func radius() -> float:
		return Vector2(frontage(), depth()).length() * 0.5

	func morale() -> float:
		if no_morale:
			return BattleSim.START_MORALE  # the Returned do not check their courage
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
var commander_stress := [0.0, 0.0]       # what the field asked of each commander's nerve (Tactical v1.0)
var combat_ticks := 0                # rounds fought — the AI times its cards by it
var battle_terrain := "plains"       # the province's ground — primal magic reads it
# Tactical Combat System v1.0: the ground's theology, and the battle's own dice
var brng := RandomNumberGenerator.new()  # binary casting gates roll here — never on campaign streams
var ground_silence := false          # silence-touched ground (the Ashfields, the spreading edge)
var ground_ruined := false           # the Aurath ruins
var ground_library := false          # Iron Library adjacency (Pellar)
var ground_wardstone := false        # the sealed Kharak-Dum holds
var side_threshold := [false, false] # a Gravewarden-Sworn hand commands this side
var side_faith := ["", ""]           # the commander's faith — oath-conflict reads it

# Hero System v1.0: heroes on the field. A hero rides with a host line
# (personal HP separate from unit HP), spends leveled abilities on
# cooldowns, and at 0 HP rolls death saves on the battle's own dice.
const HERO_GLOBAL_CD := 10           # combat ticks between any two workings...
const HERO_GLOBAL_CD_LEGENDARY := 5  # ...halved for Legendary Actions (doc §7)
const HERO_SAVE_CHANCE := 0.55       # a death save succeeds at this rate
const HERO_SPLASH := 0.15            # abilities striking the host splash onto the hero
const HERO_CHIP := 0.45              # hero damage per host casualty in the press
var heroes: Array = [{}, {}]         # per side: world.hero_info dict (empty = none)
var hero_hp := [0.0, 0.0]
var hero_state := ["", ""]           # "" | fighting | unconscious | stable | dead
var hero_saves: Array = [[0, 0], [0, 0]]  # [fails, successes] while unconscious
var hero_resist := [0, 0]            # Legendary Resistance charges (3/battle at L8+)
var hero_cd: Array = [{}, {}]        # ability id -> combat tick it comes off cooldown
var hero_uses: Array = [{}, {}]      # ability id -> uses left this battle
var hero_global_cd := [0, 0]         # combat tick the hero may act again
var hero_host := [-1, -1]            # regiment id the hero rides with
var hero_host_pool := [0.0, 0.0]     # host hp_pool last tick (chip-damage bookkeeping)
var hero_counterspells := [0, 0]     # interceptions left (wizard passive)
var hero_death_ward := [false, false]  # the first killing blow is refused (cleric passive)
var hero_dodge := [1.0, 1.0]         # damage-in multiplier (rogue passive 0.5)
var hero_auras: Array = [[], []]     # armed passive auras: [{radius, lead, md, ma, ...}]
var hero_actions_used := [0, 0]      # successful workings (XP for Legendary Actions)
var zones: Array = []                # persistent workings: {pos, radius, dpt, ticks, side, label}
var casts: Array = []                # visual flashes the view consumes: {pos, radius, ttl, color}


func setup_from_rosters(roster_a: Array, roster_b: Array, lead_bonus_a: int, lead_bonus_b: int, side_names: Array,
		cmdr_traits_a: Array = [], cmdr_traits_b: Array = [], terrain: String = "plains",
		ground: Dictionary = {}) -> void:
	## Armies come from the campaign's persistent rosters — the men who
	## fall here stay fallen when the map returns. The commander's traits
	## reach onto the field: TraitData battle hooks shape every regiment.
	## `terrain` is the battle province's terrain — forest and coast
	## activate the cultural units' terrain bonuses (Roster v1.0).
	## `ground` is the province's theology (Tactical Combat v1.0):
	## {silence, ruined, special} — the binary casting gates read it.
	regiments.clear()
	side_lead = [lead_bonus_a, lead_bonus_b]
	battle_terrain = terrain
	brng.seed = BATTLE_SEED
	ground_silence = bool(ground.get("silence", false)) or terrain == "ashfields"
	ground_ruined = bool(ground.get("ruined", false)) or terrain == "ruined"
	ground_library = str(ground.get("special", "")) == "iron_library"
	ground_wardstone = str(ground.get("special", "")) == "sealed_hold"
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
			var si = p.get("silence_immunity", 0.0)  # bool (legacy, full) or 0..1 float
			r.silence_immunity = 1.0 if (si is bool and si) else float(si)
			r.silence_immune = r.silence_immunity >= 1.0
			r.ward_shield = bool(p.get("ward_shield", false))
			r.aura_lead = float(p.get("aura_lead", 0.0))
			r.aura_range = float(p.get("aura_range", 0.0))
			# Tactical Combat v1.0 hooks
			r.no_morale = bool(p.get("no_morale", false))
			r.silence_terror = float(p.get("silence_terror", 0.0))
			r.silence_kind = bool(p.get("silence_kind", false))
			r.defensive = bool(p.get("defensive", false))
			r.oath_bound = bool(p.get("oath_bound", false))
			r.conviction_lead = float(p.get("conviction_lead", 0.0))
			r.aura_filter = str(p.get("aura_filter", ""))
			r.vigour_mult = float(p.get("vigour_mult", 1.0))
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
	_arm_static_opposition()


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
	## {martial, intrigue, prowess, traits[], names, oath_intact, faith} —
	## what the commander brings to the command tent. Without it, no
	## tactical orders can be given — and no craft reaches the field.
	## Tactical Combat v1.0: every Silence-affected working rolls a BINARY
	## reliability gate first — it fires whole, or it fizzles and only the
	## cost lands. There are no half-answered prayers.
	commanders[side] = info
	var traits: Array = info.get("traits", [])
	# the commander's magical practice, read from the same trait database
	var arcane := 1.0
	var primal := 1.0
	var corrupt := 1.0
	var song := 0.0
	var discipline := 1.0
	var vigour_cap := 1.0  # Restless: capacity for many efforts (Canon Updates v1.0)
	for tname in traits:
		if not TraitDB.has_trait(str(tname)):
			continue
		var mods: Dictionary = TraitDB.info(str(tname)).mods
		arcane *= float(mods.get("arcane_channel_mult", 1.0))
		primal *= float(mods.get("primal_channel_mult", 1.0))
		corrupt *= float(mods.get("corruption_channel_mult", 1.0))
		song += float(mods.get("song_aura_baseline", 0.0))
		discipline *= float(mods.get("discipline_binding_mult", 1.0))
		vigour_cap *= float(mods.get("vigour_points_max", 1.0))
	side_faith[side] = str(info.get("faith", ""))
	side_threshold[side] = traits.has("Gravewarden-Sworn")
	var oath_holds_now: bool = traits.has("Oath-Sworn") and not traits.has("Oathbreaker") \
		and bool(info.get("oath_intact", true))
	# --- the workings, each through its own gate ---
	var arcane_fires := false
	if arcane > 1.0 and _has_ward_retinue(side):
		arcane_fires = _gate(casting_reliability("arcane", traits))
		commander_stress[side] += 0.5  # the channel asks, either way
		if not traits.has("Academy-Sworn"):
			# a sorcerer's untrained casting always costs; failure spikes it
			commander_corruption[side] += 0.15 if arcane_fires else 0.5
		if not arcane_fires:
			event.emit("The commander reaches for the arcane formula — and this ground does not carry it. The wards stay cold.")
	var cleric := traits.has("Faith-Practicing")
	var bless_fires := false
	if cleric:
		bless_fires = _gate(casting_reliability("faith", traits))
		commander_stress[side] += 2.0
		if bless_fires:
			event.emit("The commander's prayer is answered — the line feels a weight it cannot name lift.")
		else:
			commander_stress[side] += 5.0  # praying and not receiving has a specific cost
			event.emit("The commander's prayer goes unanswered. The candles are lit anyway.")
	var primal_fires := false
	if primal > 1.0:
		primal_fires = _gate(casting_reliability("primal", traits))
		commander_stress[side] += 0.85
		if not primal_fires:
			event.emit("The primal channel is gone from this ground — nothing green answers the calling.")
	for r: Regiment in regiments:
		if r.side == side:
			# a Wizard's wards ride with the arcane retinues' volleys
			if arcane_fires and r.ward_shield:
				r.missile *= arcane
			# the primal channel steadies footsoldiers on living ground —
			# binary now: it fires whole, or not at all
			if primal_fires and not r.is_cav and r.rng_range <= 0.0:
				r.ma += 6.0 * (primal - 1.0) / 0.3
			# the song of the carried names steadies every line that hears it
			if song > 0.0:
				var names := int(info.get("names", 0))
				r.morale_bonus += 100.0 * song * clampf(1.0 + float(names) / 200.0, 1.0, 2.0)
			# the Brushgate stillness spreads from the command tent
			if discipline > 1.0:
				r.shock_mult *= 0.90
				r.vigour_mult *= 0.85  # the morning forms spend the body slowly
			# a Restless commander runs the line through many efforts —
			# the men pace themselves for all of them (Canon Updates v1.0)
			if vigour_cap != 1.0:
				r.vigour_mult /= vigour_cap
			# the Cleric's office is presence first, prayer second (doc §3.3):
			# a Zealous office grows regardless of results
			if cleric:
				r.morale_bonus += CLERIC_PRESENCE_ZEALOUS if traits.has("Zealous") else CLERIC_PRESENCE
				if bless_fires and r.rng_range <= 0.0:
					r.ma += BLESS_MA
					r.md += BLESS_MD
			# the Paladin's Aura of Devotion, and the oath that does not
			# permit routing while the token is whole (doc §3.4, §7)
			if oath_holds_now:
				r.morale_bonus += DEVOTION_LEAD
				r.md += DEVOTION_MD
				r.lead_regen_mult = maxf(r.lead_regen_mult, OATH_REGEN_MULT)
				if r.oath_bound:
					r.oath_holds = true
			# the Gravewarden's war (doc §4): deaths properly witnessed
			# shake the line less, and the unwitnessed dead feel the rite
			if side_threshold[side]:
				r.shock_mult *= 0.85
				r.dmg_vs_silence = THRESHOLD_VS_SILENCE_MULT
			# the deterministic critical layer (doc §2, expected value)
			var crit := CRIT_BASE
			if traits.has("Brushgate-Trained"):
				crit += CRIT_BRUSHGATE
			r.crit_mult = maxf(r.crit_mult, 1.0 + crit * 0.25)
		elif corrupt > 1.0 and r.silence_immunity < 1.0:
			# something rides with the enemy commander, and the lines feel
			# it — partial immunity (the Order's ward) blunts what lands
			r.shock += 10.0 * (corrupt - 1.0) / 0.4 * (1.0 - r.silence_immunity) * r.shock_mult
	if corrupt > 1.0:
		commander_corruption[side] += 1.5  # commanding with the Patron's help goes on the ledger
	_arm_opposition()


func casting_reliability(practice: String, traits: Array, oath_intact: bool = true) -> float:
	## The binary gates (Tactical Combat v1.0 §3): what this ground permits
	## each practice. 1.0 and 0.0 consume no dice; anything between rolls.
	match practice:
		"arcane":
			if ground_ruined:
				return 0.0
			if battle_terrain == "ashfields":
				# only the entity-adjacent cast under the Ashfields' sky
				return 1.0 if traits.has("Corruption Mark III") else 0.0
			if ground_silence:
				# academy formulas Silence-degrade; untrained casting less so
				return 0.5 if traits.has("Academy-Sworn") else 0.6
			return 1.0
		"faith":
			var damp := 0.30
			if ground_silence:
				damp = 0.10
			elif ground_wardstone:
				damp = 0.60
			elif ground_library:
				damp = 0.80
			var resp := 1.0
			if traits.has("Zealous"):
				resp = 1.15
			elif traits.has("Broken"):
				resp = 0.60
			elif traits.has("Opportunistic"):
				resp = 0.70
			elif traits.has("Pragmatic"):
				resp = 0.85
			return clampf(damp * resp, 0.0, 1.0)
		"primal":
			if ground_silence or ground_ruined:
				return 0.0
			match battle_terrain:
				"forest", "wetland", "river_valley":
					return 1.0
				"plains", "hills":
					return 0.9
				"coast":
					return 0.8
				"mountain":
					return 0.6
			return 0.0  # urban ground and stranger places: the channel is gone
		"oath":
			return 1.0 if oath_intact and not traits.has("Oathbreaker") else 0.0
	# corruption, song, discipline: the Patron, the carried names, and the
	# body never Silence-degrade — that is exactly what makes them what they are
	return 1.0


func _gate(rel: float) -> bool:
	## A die is consumed only when the answer is genuinely uncertain, so
	## open and closed gates never shift the battle's stream.
	if rel >= 1.0:
		return true
	if rel <= 0.0:
		return false
	return brng.randf() < rel


func _has_ward_retinue(side: int) -> bool:
	for r: Regiment in regiments:
		if r.side == side and r.ward_shield:
			return true
	return false


# --------------------------------------------- heroes on the field (v1.0)

func set_hero(side: int, h: Dictionary) -> void:
	## A hero takes the field: personal HP, leveled abilities on
	## cooldowns, passives armed. Consumes no dice — the gates roll at
	## each working, and only when genuinely uncertain.
	heroes[side] = h
	hero_hp[side] = float(h.get("hp", 40))
	hero_state[side] = "fighting"
	hero_saves[side] = [0, 0]
	hero_resist[side] = 3 if bool(h.get("legendary", false)) else 0
	hero_cd[side] = {}
	hero_uses[side] = {}
	hero_global_cd[side] = 0
	hero_counterspells[side] = 0
	hero_death_ward[side] = false
	hero_dodge[side] = 1.0
	hero_auras[side] = []
	hero_actions_used[side] = 0
	var cls := str(h.get("class", ""))
	var lvl := int(h.get("combat_level", h.get("level", 1)))
	var legendary := bool(h.get("legendary", false))
	for aid in HeroDB.battle_actives(cls, lvl):
		# Legendary heroes take additional actions: +1 use of everything
		hero_uses[side][aid] = int(HeroDB.info(aid).get("uses", 1)) + (1 if legendary else 0)
		hero_cd[side][aid] = 0
	for aid in HeroDB.battle_passives(cls, lvl):
		var info := HeroDB.info(aid)
		match str(info["kind"]):
			"aura":
				hero_auras[side].append(info)
			"counterspell":
				# doc §4.1: the L6 wizard's Contingency covers a second interruption
				hero_counterspells[side] += int(info.get("uses", 1)) + (1 if lvl >= 6 else 0)
			"death_ward":
				hero_death_ward[side] = true
			"dodge":
				hero_dodge[side] = minf(hero_dodge[side], float(info.get("mult", 1.0)))
	_hero_host_assign(side)


func hero_active(side: int) -> bool:
	return not heroes[side].is_empty() and hero_state[side] == "fighting"


func hero_abilities(side: int) -> Array:
	## The hero's field orders, in grant order (the view's button bar).
	if heroes[side].is_empty():
		return []
	return HeroDB.battle_actives(str(heroes[side].get("class", "")),
		int(heroes[side].get("combat_level", heroes[side].get("level", 1))))


func _hero_host_assign(side: int) -> void:
	## The hero rides with the strongest line still standing.
	var best: Regiment = null
	for r: Regiment in regiments:
		if r.side == side and r.active():
			if best == null or r.soldiers > best.soldiers:
				best = r
	hero_host[side] = best.id if best != null else -1
	hero_host_pool[side] = best.hp_pool if best != null else 0.0


func hero_pos(side: int) -> Vector2:
	if hero_host[side] >= 0 and hero_host[side] < regiments.size():
		return (regiments[hero_host[side]] as Regiment).pos
	return Vector2(120.0, field.y * 0.5) if side == 0 else Vector2(field.x - 120.0, field.y * 0.5)


func hero_ability_gate(side: int, aid: String) -> String:
	## "" = the working can be attempted. Otherwise, why not.
	if ended:
		return "The field is decided."
	if heroes[side].is_empty():
		return "No hero stands on this field."
	if hero_state[side] != "fighting":
		return "The hero is down."
	if not hero_uses[side].has(aid):
		return "That working is beyond this hero."
	if int(hero_uses[side][aid]) <= 0:
		return "That working is spent."
	if combat_ticks < int(hero_cd[side].get(aid, 0)):
		return "The working is not ready again yet."
	if combat_ticks < int(hero_global_cd[side]):
		return "The hero has just acted."
	return ""


func use_hero_ability(side: int, aid: String, target: Vector2 = Vector2.ZERO) -> String:
	## A hero's working: the binary gate rolls first (Tactical v1.0 law —
	## it fires whole or fizzles whole), the enemy's Counterspell may
	## interrupt, and the cost lands either way.
	var gate := hero_ability_gate(side, aid)
	if gate != "":
		return gate
	var info := HeroDB.info(aid)
	var h: Dictionary = heroes[side]
	var cls := str(h.get("class", ""))
	var legendary := bool(h.get("legendary", false))
	hero_uses[side][aid] = int(hero_uses[side][aid]) - 1
	hero_cd[side][aid] = combat_ticks + int(info.get("cd", 20))
	hero_global_cd[side] = combat_ticks + (HERO_GLOBAL_CD_LEGENDARY if legendary else HERO_GLOBAL_CD)
	# --- the cost of asking, answered or not ---
	var practice := HeroDB.practice(cls)
	if practice != "":
		commander_stress[side] += 1.0 if practice == "faith" else 0.5
	if CLASSES_CAST_CORRUPTION.has(cls):
		commander_corruption[side] += float(CLASSES_CAST_CORRUPTION[cls])
	commander_corruption[side] += float(info.get("corruption", 0.0))
	# --- the enemy's counter-formula (magical workings only) ---
	if practice != "" and hero_counterspells[1 - side] > 0 and hero_active(1 - side):
		hero_counterspells[1 - side] -= 1
		event.emit("%s begins the working — and %s's counter-formula snuffs it mid-air." % [
			str(h.get("name", "The hero")), str(heroes[1 - side].get("name", "the enemy hero"))])
		return ""
	# --- the binary gate ---
	var rel := 1.0
	if practice == "oath":
		rel = casting_reliability("oath", h.get("traits", []), bool(h.get("oath_intact", true)))
	elif practice != "":
		rel = casting_reliability(practice, h.get("traits", []))
	if cls == "sorcerer":
		rel *= float(HeroDB.CLASSES["sorcerer"].get("unreliable", 1.0))
	if not _gate(rel):
		if practice == "faith":
			commander_stress[side] += 5.0  # asking and not receiving has its cost
		event.emit("%s reaches for %s — and this ground does not carry it." % [
			str(h.get("name", "The hero")), str(info.get("label", aid))])
		return ""
	# --- the working fires whole ---
	hero_actions_used[side] += 1
	_hero_apply_effect(side, aid, info, target)
	return ""


# Sorcerers pay corruption on every casting (doc §4.2).
const CLASSES_CAST_CORRUPTION := {"sorcerer": 0.5}


func _hero_song_scale(side: int, info: Dictionary) -> float:
	## The Bard's law: what the carried names weigh (the commander-scale
	## song aura's own formula, reused).
	if not bool(info.get("song_scaled", false)):
		return 1.0
	return clampf(1.0 + float(heroes[side].get("names", 0)) / 200.0, 1.0, 2.0)


func _hero_apply_effect(side: int, aid: String, info: Dictionary, target: Vector2) -> void:
	var h: Dictionary = heroes[side]
	var hname := str(h.get("name", "The hero"))
	var label := str(info.get("label", aid))
	var scale := _hero_song_scale(side, info)
	match str(info["kind"]):
		"aoe":
			var radius := float(info.get("radius", 50.0))
			var struck := 0
			for r: Regiment in regiments:
				if r.side != side and r.alive() and r.pos.distance_to(target) <= radius + r.radius() * 0.5:
					_hero_damage(r, float(info.get("pow", 20.0)) * scale, float(info.get("shock", 0.0)))
					struck += 1
			casts.append({"pos": target, "radius": radius, "ttl": 10, "color": "fire"})
			if struck > 0:
				event.emit("%s casts %s — %d enemy line%s caught in it!" % [hname, label, struck, "" if struck == 1 else "s"])
			else:
				event.emit("%s casts %s — it lands on empty ground." % [hname, label])
		"line":
			var origin := hero_pos(side)
			var dir := (target - origin)
			if dir.length() < 1.0:
				dir = Vector2.RIGHT if side == 0 else Vector2.LEFT
			dir = dir.normalized()
			var length := float(info.get("length", 240.0))
			var struck2 := 0
			for r: Regiment in regiments:
				if r.side == side or not r.alive():
					continue
				var to := r.pos - origin
				var along := to.dot(dir)
				if along < 0.0 or along > length:
					continue
				if (to - dir * along).length() <= r.radius() * 0.6 + 14.0:
					_hero_damage(r, float(info.get("pow", 30.0)) * scale, 4.0)
					struck2 += 1
			casts.append({"pos": origin + dir * length * 0.5, "radius": length * 0.5, "ttl": 8, "color": "bolt"})
			event.emit("%s looses %s down the field%s" % [hname, label,
				" — %d lines struck!" % struck2 if struck2 > 0 else ". It grounds harmlessly."])
		"multi":
			var count := int(info.get("count", 3))
			var reach := float(info.get("range", 260.0))
			var pool: Array = []
			for r: Regiment in regiments:
				if r.side != side and r.alive() and r.pos.distance_to(target) <= reach:
					pool.append(r)
			pool.sort_custom(func(a, b) -> bool:
				return a.pos.distance_squared_to(target) < b.pos.distance_squared_to(target))
			for i in mini(count, pool.size()):
				_hero_damage(pool[i], float(info.get("pow", 15.0)) * scale, 3.0)
				casts.append({"pos": (pool[i] as Regiment).pos, "radius": 24.0, "ttl": 8, "color": "bolt"})
			event.emit("%s casts %s — %d strikes find their lines." % [hname, label, mini(count, pool.size())])
		"single":
			var t := _nearest_enemy_to_point(side, target)
			if t != null:
				var strike := float(info.get("pow", 20.0)) * scale
				if t.silence_kind:
					strike *= float(info.get("vs_silence", 1.0))
				_hero_damage(t, strike, float(info.get("shock", 0.0)))
				casts.append({"pos": t.pos, "radius": 20.0, "ttl": 8, "color": "bolt"})
				event.emit("%s strikes %s with %s!" % [hname, t.label, label])
		"zone":
			zones.append({"pos": target, "radius": float(info.get("radius", 50.0)),
				"dpt": float(info.get("dpt", 5.0)) * scale, "ticks": int(info.get("dur", 20)),
				"side": side, "label": label})
			casts.append({"pos": target, "radius": float(info.get("radius", 50.0)), "ttl": 12, "color": "fire"})
			event.emit("%s raises %s — the ground itself takes a side." % [hname, label])
		"timed":
			if bool(info.get("all_enemies", false)):
				for r: Regiment in regiments:
					if r.side != side and r.active():
						_apply_timed(r, info, scale)
				event.emit("%s casts %s — the whole enemy line staggers out of time." % [hname, label])
			elif str(info.get("target", "enemy")) == "friend":
				var f := _nearest_friend_to_point(side, target)
				if f != null:
					_apply_timed(f, info, scale)
					event.emit("%s lays %s on %s." % [hname, label, f.label])
			else:
				var t2 := _nearest_enemy_to_point(side, target)
				if t2 != null:
					_apply_timed(t2, info, scale)
					event.emit("%s casts %s on %s." % [hname, label, t2.label])
		"rally":
			var radius2 := float(info.get("radius", 90.0))
			var amount := float(info.get("amount", 15.0)) * scale
			var lifted := 0
			for r: Regiment in regiments:
				if r.side == side and r.active() and r.pos.distance_to(target) <= radius2:
					r.shock = maxf(0.0, r.shock - amount)
					lifted += 1
			casts.append({"pos": target, "radius": radius2, "ttl": 10, "color": "gold"})
			if lifted > 0:
				event.emit("%s: %s — the lines nearby remember their feet." % [hname, label])
		"shockwave":
			var amount2 := float(info.get("amount", 10.0)) * scale
			if str(info.get("target", "point")) == "enemy":
				var t3 := _nearest_enemy_to_point(side, target)
				if t3 != null and not t3.no_morale:
					t3.shock += amount2 * t3.shock_mult
					event.emit("%s turns %s on %s — the line flinches." % [hname, label, t3.label])
			else:
				var radius3 := float(info.get("radius", 120.0))
				for r: Regiment in regiments:
					if r.side != side and r.active() and not r.no_morale \
							and r.silence_immunity < 1.0 and r.pos.distance_to(target) <= radius3:
						r.shock += amount2 * (1.0 - r.silence_immunity) * r.shock_mult
				casts.append({"pos": target, "radius": radius3, "ttl": 10, "color": "dread"})
				event.emit("%s: %s — a wrongness sweeps the enemy lines." % [hname, label])
		"heal":
			var f2 := _nearest_friend_to_point(side, target)
			if f2 != null:
				_hero_heal(f2, float(info.get("amount", 40.0)) * scale)
				casts.append({"pos": f2.pos, "radius": 26.0, "ttl": 10, "color": "gold"})
				event.emit("%s: %s — %s's fallen stand back up." % [hname, label, f2.label])
		"heal_area":
			var radius4 := float(info.get("radius", 80.0))
			for r: Regiment in regiments:
				if r.side == side and r.alive() and r.pos.distance_to(target) <= radius4:
					_hero_heal(r, float(info.get("amount", 30.0)) * scale)
			casts.append({"pos": target, "radius": radius4, "ttl": 10, "color": "gold"})
			event.emit("%s: %s — the lines nearby are mended." % [hname, label])
		"hero_strike":
			if not heroes[1 - side].is_empty() and hero_state[1 - side] == "fighting":
				_hero_take_damage(1 - side, float(info.get("pow", 25.0)))
				event.emit("%s finds the enemy commander — %s bleeds for it!" % [hname,
					str(heroes[1 - side].get("name", "the enemy hero"))])
			else:
				event.emit("%s stalks the enemy command — and finds no one worth the knife." % hname)
		"dispel":
			var cleared := 0
			for z in zones:
				if int(z["side"]) != side:
					z["ticks"] = 0
					cleared += 1
			for r: Regiment in regiments:
				if r.side == side and r.fx_on() and (r.fx_ma < 0.0 or r.fx_dmg_mult > 1.0 or r.fx_speed_mult < 1.0):
					r.fx_ticks = 0
			event.emit("%s: %s — the workings on this field are dismissed." % [hname, label])


func _apply_timed(r: Regiment, info: Dictionary, scale: float = 1.0) -> void:
	r.fx_ticks = int(info.get("dur", 12))
	r.fx_ma = float(info.get("ma", 0.0)) * scale
	r.fx_md = float(info.get("md", 0.0)) * scale
	r.fx_ws_mult = float(info.get("ws_mult", 1.0))
	r.fx_dmg_mult = float(info.get("dmg_mult", 1.0))
	r.fx_speed_mult = float(info.get("speed_mult", 1.0))
	r.fx_lead = float(info.get("lead", 0.0)) * scale
	r.fx_missile_immune = bool(info.get("missile_immune", false))


func _hero_damage(r: Regiment, amount: float, shock_amt: float) -> void:
	## Ability damage runs the same pipeline as combat damage: pool,
	## soldiers, casualty shock — plus the working's own dread.
	var before := r.soldiers
	r.hp_pool = maxf(0.0, r.hp_pool - amount * r.dmg_taken_mult * (r.fx_dmg_mult if r.fx_on() else 1.0))
	r.soldiers = int(ceil(r.hp_pool / r.hp_per))
	var cas := before - r.soldiers
	if cas > 0 and not r.no_morale:
		r.shock += (float(cas) / maxf(1.0, float(before))) * CASUALTY_SHOCK * r.shock_mult
	if shock_amt > 0.0 and not r.no_morale:
		r.shock += shock_amt * (1.0 - r.silence_immunity if r.silence_kind else 1.0) * r.shock_mult
	# the enemy hero rides somewhere — a working that strikes the host
	# splashes onto the rider
	if r.id == hero_host[r.side] and hero_state[r.side] == "fighting":
		_hero_take_damage(r.side, amount * HERO_SPLASH)
	if r.soldiers <= 0:
		r.fled = true
		event.emit("%s %s under the working!" % [r.label,
			"are dispersed" if r.no_morale else "is annihilated"])
		_check_end()


func _hero_heal(r: Regiment, amount: float) -> void:
	var cap := float(r.start_soldiers) * r.hp_per
	r.hp_pool = minf(cap, r.hp_pool + amount)
	r.soldiers = mini(r.start_soldiers, int(ceil(r.hp_pool / r.hp_per)))


func _hero_take_damage(side: int, amount: float) -> void:
	if heroes[side].is_empty() or hero_state[side] != "fighting":
		return
	hero_hp[side] -= amount * hero_dodge[side]
	if hero_hp[side] <= 0.0:
		if hero_death_ward[side]:
			hero_death_ward[side] = false
			hero_hp[side] = 1.0
			event.emit("The killing blow reaches %s — and is refused. The ward is spent." % str(heroes[side].get("name", "the hero")))
			return
		hero_hp[side] = 0.0
		hero_state[side] = "unconscious"
		hero_saves[side] = [0, 0]
		event.emit("[b]%s goes down![/b] The line closes around the body — the saves begin." % str(heroes[side].get("name", "The hero")))


func _nearest_enemy_to_point(side: int, pos: Vector2) -> Regiment:
	var best: Regiment = null
	var best_d := INF
	for r: Regiment in regiments:
		if r.side == side or not r.alive():
			continue
		var d := r.pos.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = r
	return best


func _nearest_friend_to_point(side: int, pos: Vector2) -> Regiment:
	var best: Regiment = null
	var best_d := INF
	for r: Regiment in regiments:
		if r.side != side or not r.alive():
			continue
		var d := r.pos.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = r
	return best


func _hero_battle_tick() -> void:
	## The heroes' own combat tick: zones burn, hosts bleed onto their
	## riders, and the fallen roll their saves on the battle's dice.
	# persistent workings
	for z in zones:
		if int(z["ticks"]) <= 0:
			continue
		z["ticks"] = int(z["ticks"]) - 1
		for r: Regiment in regiments:
			if r.side != int(z["side"]) and r.alive() \
					and r.pos.distance_to(z["pos"]) <= float(z["radius"]) + r.radius() * 0.4:
				_hero_damage(r, float(z["dpt"]), 0.0)
	zones = zones.filter(func(z2) -> bool: return int(z2["ticks"]) > 0)
	for side in 2:
		if heroes[side].is_empty():
			continue
		match str(hero_state[side]):
			"fighting":
				# the host may have broken or fallen — find a new line
				var host_id: int = hero_host[side]
				var host: Regiment = regiments[host_id] if host_id >= 0 and host_id < regiments.size() else null
				if host == null or not host.active():
					_hero_host_assign(side)
					host_id = hero_host[side]
					host = regiments[host_id] if host_id >= 0 else null
					hero_host_pool[side] = host.hp_pool if host != null else 0.0
					continue
				# riding a bleeding line costs the rider (prowess keeps you alive)
				if host.engaged_id >= 0:
					var lost := maxf(0.0, hero_host_pool[side] - host.hp_pool)
					if lost > 0.0:
						var cas := lost / maxf(1.0, host.hp_per)
						var guard := maxf(0.2, 1.0 - float(heroes[side].get("prowess", 6)) * 0.025)
						_hero_take_damage(side, cas * HERO_CHIP * guard)
				hero_host_pool[side] = host.hp_pool
			"unconscious":
				# death saves, one per combat tick: three failures and the
				# campaign loses a name; three successes and it keeps one
				var ok := brng.randf() < HERO_SAVE_CHANCE
				if not ok and hero_resist[side] > 0:
					hero_resist[side] -= 1
					ok = true  # Legendary Resistance refuses the failure (doc §7)
					event.emit("%s refuses the dark — Legendary Resistance, %d left." % [
						str(heroes[side].get("name", "The hero")), hero_resist[side]])
				hero_saves[side][1 if ok else 0] += 1
				if hero_saves[side][0] >= 3:
					hero_state[side] = "dead"
					event.emit("[b]%s dies on the field.[/b] The chronicle will mark where." % str(heroes[side].get("name", "The hero")))
				elif hero_saves[side][1] >= 3:
					hero_state[side] = "stable"
					event.emit("%s is dragged clear, breathing — barely. Their part in this battle is over." % str(heroes[side].get("name", "The hero")))


func _ai_hero(side: int) -> void:
	## The hero AI plays deterministically: mend what is breaking, break
	## what is massed, steady what wavers. One working per window.
	if not hero_active(side) or combat_ticks < 4 or combat_ticks < int(hero_global_cd[side]):
		return
	var best_aid := ""
	var best_target := Vector2.ZERO
	var best_value := 0.0
	for aid in hero_abilities(side):
		if hero_ability_gate(side, aid) != "":
			continue
		var info := HeroDB.info(aid)
		match str(info["kind"]):
			"aoe", "zone", "line", "multi":
				# aim at the enemy line with the most company around it
				var radius := float(info.get("radius", info.get("length", 60.0)))
				for r: Regiment in regiments:
					if r.side == side or not r.active():
						continue
					var mass := 0
					for o: Regiment in regiments:
						if o.side != side and o.active() and o.pos.distance_to(r.pos) <= radius:
							mass += o.soldiers
					var value := float(mass) * (1.5 if str(info["kind"]) == "aoe" else 1.0)
					if value > best_value and mass >= 24:
						best_value = value
						best_aid = aid
						best_target = r.pos
			"heal", "heal_area":
				for r: Regiment in regiments:
					if r.side != side or not r.active():
						continue
					var frac := float(r.soldiers) / maxf(1.0, float(r.start_soldiers))
					if frac < 0.6:
						var value2 := (1.0 - frac) * 120.0
						if value2 > best_value:
							best_value = value2
							best_aid = aid
							best_target = r.pos
			"rally":
				for r: Regiment in regiments:
					if r.side == side and r.active() and r.shock > 45.0 and not r.no_morale:
						if r.shock > best_value:
							best_value = r.shock
							best_aid = aid
							best_target = r.pos
			"timed":
				if str(info.get("target", "enemy")) == "friend":
					var host: Regiment = regiments[hero_host[side]] if hero_host[side] >= 0 else null
					if host != null and host.active() and host.engaged_id >= 0 and best_value < 30.0:
						best_value = 30.0
						best_aid = aid
						best_target = host.pos
				else:
					var t := _biggest_enemy(side)
					if t != null and t.engaged_id >= 0 and best_value < 26.0:
						best_value = 26.0
						best_aid = aid
						best_target = t.pos
			"single", "shockwave":
				var t2 := _biggest_enemy(side)
				if t2 != null and best_value < 20.0:
					best_value = 20.0
					best_aid = aid
					best_target = t2.pos
			"hero_strike":
				if hero_active(1 - side) and hero_hp[1 - side] < float(heroes[1 - side].get("hp_max", 40)) * 0.6 \
						and best_value < 40.0:
					best_value = 40.0
					best_aid = aid
					best_target = hero_pos(1 - side)
	if best_aid != "":
		var _e := use_hero_ability(side, best_aid, best_target)


func _biggest_enemy(side: int) -> Regiment:
	var best: Regiment = null
	for r: Regiment in regiments:
		if r.side != side and r.active():
			if best == null or r.soldiers > best.soldiers:
				best = r
	return best


func _arm_opposition() -> void:
	## Cross-tent wiring, re-derived whenever a commander arrives: the
	## Order's oath answers heresy, the Forsaken's conviction answers the
	## old order's banners, and oath-magic reads corrupted flesh precisely.
	for side in 2:
		var theirs: Dictionary = commanders[1 - side]
		var enemy_faith := str(theirs.get("faith", ""))
		var heretic := enemy_faith == "Aelindran Reformed" or enemy_faith == "The Silent Path"
		var enemy_traits: Array = theirs.get("traits", [])
		var enemy_marked: bool = enemy_traits.has("Corruption Mark II") or enemy_traits.has("Corruption Mark III")
		var mine: Dictionary = commanders[side]
		var my_traits: Array = mine.get("traits", [])
		for r: Regiment in regiments:
			if r.side != side:
				continue
			if r.oath_bound and heretic:
				r.oath_conflict = true
			if enemy_faith == "Aelindran Orthodox":
				_arm_conviction(r)
			if my_traits.has("Oath-Sworn") and enemy_marked:
				r.crit_mult = maxf(r.crit_mult, 1.0 + (CRIT_BASE + CRIT_OATH_VS_MARKED) * 0.25)


func _arm_static_opposition() -> void:
	## The oppositions the rosters themselves declare (no command tent
	## needed): the Order against the Silence-born, the Forsaken against
	## the Order's banners.
	for side in 2:
		var enemy_silence := false
		var enemy_order := false
		for e: Regiment in regiments:
			if e.side != side:
				enemy_silence = enemy_silence or e.silence_kind
				enemy_order = enemy_order or e.oath_bound
		for r: Regiment in regiments:
			if r.side != side:
				continue
			if r.oath_bound and enemy_silence:
				r.oath_conflict = true
			if enemy_order:
				_arm_conviction(r)


func _arm_conviction(r: Regiment) -> void:
	if r.conviction_on or r.conviction_lead <= 0.0:
		return
	r.conviction_on = true  # conviction arms once; it does not stack
	r.morale_bonus += r.conviction_lead


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
	## Tactical v1.0: the channel rolls its binary gate like any working.
	if not _gate(casting_reliability("arcane", commanders[side].get("traits", []))):
		commander_corruption[side] += 0.5
		event.emit("The commander tears the channel open — and this ground swallows it whole. Nothing answers but the ledger.")
		return
	for r: Regiment in regiments:
		if r.side == side and r.rng_range > 0.0:
			r.missile *= CHANNEL_MISSILE_MULT
			r.ammo += 10
	commander_corruption[side] += 2.0
	event.emit("The commander opens an uncontrolled channel! Every volley burns brighter — and something takes note.")


func _do_reap_the_bargain(side: int) -> void:
	## The Patron collects (Magic v1.0): every enemy line feels it at
	## once. The price is immediate, personal, and not negotiable. The
	## Patron operates in Silence-adjacent space — no gate, ever (§3.6).
	## A Gravewarden at the enemy's table holds half of it at the threshold.
	var shielded: bool = side_threshold[1 - side]
	for r: Regiment in regiments:
		if r.side != side and r.active() and r.silence_immunity < 1.0:
			r.shock += REAP_SHOCK * (0.5 if shielded else 1.0) * (1.0 - r.silence_immunity) * r.shock_mult
	commander_corruption[side] += 5.0
	event.emit("The commander reaps the bargain! A wrongness sweeps the enemy lines — and the ledger turns another page.")
	if shielded:
		event.emit("A Gravewarden hand stands at the enemy's map table — the reaping breaks against a threshold already held.")


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
	var max_speed := 1.0
	for r: Regiment in regiments:
		if r.alive():
			max_speed = maxf(max_speed, r.speed * (1.35 if r.routed else 1.0))
	var steps := clampi(int(ceil(max_speed * maxf(delta, 0.0) / MAX_MOVE_SUBSTEP)), 1, 128)
	var sub_delta := delta / float(steps)
	for _step in steps:
		_move_substep(sub_delta)


func _move_substep(delta: float) -> void:
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
				r.pos += lure_dir * r.speed * (1.0 - r.fatigue) \
					* (r.fx_speed_mult if r.fx_on() else 1.0) * delta
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
				r.pos += dir * r.speed * (1.0 - r.fatigue) \
					* (r.fx_speed_mult if r.fx_on() else 1.0) * delta
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
			var delta := b.pos - a.pos
			var d := delta.length()
			if d < 0.001:
				b.pos += Vector2(1.0, 0.0)
				continue
			var dir := delta / d
			var min_d := _formation_clearance(a, b, dir) + (ALLY_GAP if a.side == b.side else CONTACT_GAP)
			if d < min_d:
				var overlap := min_d - d
				# Let a stationary or defensive line hold its ground while the
				# advancing formation absorbs the correction. Equal movers share it.
				if a.has_move_order and not b.has_move_order:
					a.pos -= dir * overlap
				elif b.has_move_order and not a.has_move_order:
					b.pos += dir * overlap
				else:
					a.pos -= dir * overlap * 0.5
					b.pos += dir * overlap * 0.5


func ai_step(control_side_0: bool) -> void:
	## Simple AI: unengaged regiments march at the nearest enemy.
	## Side 0 is normally the player; pass true to automate both sides.
	_ai_tactics(1)
	_ai_hero(1)
	if control_side_0:
		_ai_tactics(0)
		_ai_hero(0)
	for r: Regiment in regiments:
		if not r.active():
			continue
		if r.side == 0 and not control_side_0:
			continue
		if r.engaged_id >= 0 or r.lure_ticks > 0:
			continue
		if r.defensive:
			continue  # the Warden-Dead hold their ground; the war comes to them (doc §5.13)
		if r.aura_lead > 0.0 and r.rng_range <= 0.0:
			# a Chaplain company shadows the strongest friendly line, close
			# enough for the litany to carry, never leading the advance
			var anchor := _strongest_friend(r)
			if anchor != null and r.pos.distance_to(anchor.pos) > r.aura_range * 0.5:
				r.has_move_order = true
				r.move_target = anchor.pos
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
		# the anti-Silence specialists seek the Silence-born first: that is
		# what the discipline, and the Order, structurally exist for (§9)
		if r.silence_immunity >= 0.6:
			var quarry := _nearest_silence_enemy(r)
			if quarry != null:
				enemy = quarry
		if enemy != null:
			r.has_move_order = true
			r.move_target = enemy.pos


func _strongest_friend(r: Regiment) -> Regiment:
	## The friendly melee line with the most soldiers still standing.
	var best: Regiment = null
	for other: Regiment in regiments:
		if other == r or other.side != r.side or not other.active() or other.aura_lead > 0.0:
			continue
		if best == null or other.soldiers > best.soldiers:
			best = other
	return best


func _nearest_silence_enemy(r: Regiment) -> Regiment:
	var best: Regiment = null
	var best_d := INF
	for other: Regiment in regiments:
		if other.side == r.side or not other.active() or not other.silence_kind:
			continue
		var d := r.pos.distance_squared_to(other.pos)
		if d < best_d:
			best_d = d
			best = other
	return best


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
		var ma := (r.ma + r.hero_ma_bonus + (r.fx_ma if r.fx_on() else 0.0)) * (1.0 - r.fatigue)
		var ws := r.ws * (1.0 - r.fatigue) * (r.fx_ws_mult if r.fx_on() else 1.0)
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
		# Tactical Combat v1.0: what this war is actually about
		if r.silence_kind and ground_silence:
			mult *= SILENCE_DMG_BONUS  # the Silence-born fight under their own sky
		if r.no_morale and _strength_fraction(r) < CONFUSION_THRESHOLD:
			mult *= CONFUSION_MULT  # dispersed past coherence, the Returned grow confused
		if r.oath_conflict:
			mult *= OATH_CONFLICT_MULT  # the Order's oath answers heresy
		if t.silence_kind:
			mult *= r.dmg_vs_silence  # threshold-work against the unwitnessed dead
		mult *= r.crit_mult
		var hit := clampf(BASE_HIT + (ma - (t.md + t.hero_md_bonus + (t.fx_md if t.fx_on() else 0.0)) \
			* (1.0 - t.fatigue)) * HIT_PER_POINT, HIT_MIN, HIT_MAX)
		var per_hit := maxf(ws * (ARMOUR_PIVOT / (ARMOUR_PIVOT + t.armour)), ws * CHIP_FRACTION)
		dmg[t.id] = dmg.get(t.id, 0.0) + float(engaged_count) * ATTACKS_PER_TICK * hit * per_hit * mult

	_ranged_tick(dmg)
	_aura_tick()

	for r: Regiment in regiments:
		if not r.alive():
			continue
		# vigour: the field spends the body (Tactical v1.0 §8)
		if r.active():
			var spend := 0.0
			if r.engaged_id >= 0:
				spend = VIGOUR_FIGHT
			elif r.was_moving or r.has_move_order:
				spend = VIGOUR_MOVE
			if r.charging_ticks > 0:
				spend += VIGOUR_CHARGE
			r.vigour += spend * r.vigour_mult
			r.fatigue = _fatigue_penalty(r)
		if dmg.has(r.id):
			var before := r.soldiers
			var depth_before := r.depth_for_count(before)
			r.hp_pool = maxf(0.0, r.hp_pool - dmg[r.id] * r.dmg_taken_mult \
				* (r.fx_dmg_mult if r.fx_on() else 1.0))
			r.soldiers = int(ceil(r.hp_pool / r.hp_per))
			var cas := before - r.soldiers
			if cas > 0 and r.soldiers > 0 and r.engaged_id >= 0:
				# Ranks close from the rear. Moving the formation center forward by
				# half the lost depth keeps its front rank on the contact line.
				var lost_depth := maxf(0.0, depth_before - r.depth_for_count(r.soldiers))
				r.pos += r.facing.normalized() * lost_depth * 0.5
			if cas > 0 and not r.no_morale:
				r.shock += (float(cas) / maxf(1.0, float(before))) * CASUALTY_SHOCK * r.shock_mult
		# a timed working runs out where it stands
		if r.fx_ticks > 0:
			r.fx_ticks -= 1
		# morale regen: silence-touched ground starves the nerve of every
		# line the Silence can still reach; nearby terror starves it more
		var lead_eff := r.leadership + r.aura_bonus + (r.fx_lead if r.fx_on() else 0.0)
		if ground_silence:
			lead_eff -= SILENCE_LEAD_PENALTY * (1.0 - r.silence_immunity)
		lead_eff = maxf(0.0, lead_eff) * (1.0 - r.terror_penalty) * r.lead_regen_mult
		r.shock = maxf(0.0, r.shock - lead_eff * LEADERSHIP_REGEN)
		if r.soldiers <= 0:
			r.fled = true
			if r.no_morale:
				event.emit("%s are dispersed — the bodies settle where they fall." % r.label)
			else:
				event.emit("%s is wiped out!" % r.label)
		elif not r.routed and r.morale() <= _rout_threshold(r):
			if r.never_routs_above > 0.0 and _strength_fraction(r) >= r.never_routs_above:
				continue  # the Berserker oath holds while a quarter of them stand
			if r.oath_bound and r.oath_holds:
				continue  # the Vigil-Sworn oath does not permit it (doc §7)
			r.routed = true
			event.emit("%s breaks and runs!" % r.label)
			_cascade_panic(r)
	_hero_battle_tick()
	_check_end()


func _fatigue_penalty(r: Regiment) -> float:
	## Fresh / active / tiring / winded / exhausted (doc §8, engine-scaled).
	var stage := 0
	for th in VIGOUR_STAGES:
		if r.vigour >= float(th):
			stage += 1
	return VIGOUR_PENALTY[stage]


func _rout_threshold(r: Regiment) -> float:
	## Berserkers past their oath-threshold still take 40% deeper shock
	## before breaking (Cultural Roster v1.0).
	return -40.0 if r.never_routs_above > 0.0 else 0.0


func _strength_fraction(r: Regiment) -> float:
	return float(r.soldiers) / maxf(1.0, float(r.start_soldiers))


func _aura_tick() -> void:
	## Ward-Speaker, Song-Bound, and Chaplain auras: each regiment receives
	## the best friendly aura in range (auras project outward, never onto
	## their own bearers, and do not stack). A Chaplain's litany reaches
	## only the Order's own regiments (aura_filter "order", doc §5.12).
	for r: Regiment in regiments:
		r.aura_bonus = 0.0
		r.terror_penalty = 0.0
		r.hero_ma_bonus = 0.0
		r.hero_md_bonus = 0.0
		r.hero_missile_block = 0.0
		r.hero_terror_block = 0.0
	for src: Regiment in regiments:
		if src.aura_lead <= 0.0 or not src.active():
			continue
		for r: Regiment in regiments:
			if r == src or r.side != src.side or not r.active():
				continue
			if src.aura_filter == "order" and not (r.oath_bound or r.aura_filter == "order"):
				continue
			if src.pos.distance_to(r.pos) <= src.aura_range:
				r.aura_bonus = maxf(r.aura_bonus, src.aura_lead)
	# the heroes' standing auras (v1.0): projected from wherever the hero
	# rides, for as long as the hero still stands. Radius 0 reaches only
	# the host line itself (a hero fighting in the ranks).
	for side in 2:
		if not hero_active(side) or hero_host[side] < 0:
			continue
		var origin: Vector2 = hero_pos(side)
		for info in hero_auras[side]:
			var radius := float(info.get("radius", 0.0))
			for r: Regiment in regiments:
				if r.side != side or not r.active():
					continue
				if radius <= 0.0:
					if r.id != hero_host[side]:
						continue
				elif origin.distance_to(r.pos) > radius:
					continue
				r.aura_bonus = maxf(r.aura_bonus, float(info.get("lead", 0.0)))
				r.hero_ma_bonus = maxf(r.hero_ma_bonus, float(info.get("ma", 0.0)))
				r.hero_md_bonus = maxf(r.hero_md_bonus, float(info.get("md", 0.0)))
				r.hero_missile_block = maxf(r.hero_missile_block, float(info.get("missile_block", 0.0)))
				r.hero_terror_block = maxf(r.hero_terror_block, float(info.get("terror_block", 0.0)))
	# silence terror (doc §5.13): the Warden-Dead's wrongness starves the
	# nerve of every line near them — except those warded against it, and
	# halved where a Gravewarden commander holds the threshold
	for src: Regiment in regiments:
		if src.silence_terror <= 0.0 or not src.active():
			continue
		for r: Regiment in regiments:
			if r.side == src.side or not r.active() or r.silence_immunity >= 1.0:
				continue
			if src.pos.distance_to(r.pos) <= TERROR_RANGE:
				var felt := src.silence_terror * (1.0 - r.silence_immunity)
				if side_threshold[r.side]:
					felt *= 0.5
				# a hero's aura holds the door against the wrongness (v1.0)
				felt *= 1.0 - r.hero_terror_block
				r.terror_penalty = maxf(r.terror_penalty, felt)


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
		block = minf(1.0, block + t.hero_missile_block)  # a hero's lattice adds its own
		if t.fx_on() and t.fx_missile_immune:
			block = 1.0  # a wall of force does not negotiate with arrows
		var per_hit := maxf(r.missile * (ARMOUR_PIVOT / (ARMOUR_PIVOT + t.armour)), r.missile * CHIP_FRACTION)
		if t.silence_kind and r.ward_shield:
			per_hit *= ARCANE_VS_RETURNED_MULT  # arcane volleys find what swords cannot (doc §5.13)
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


func _formation_clearance(a: Regiment, b: Regiment, direction: Vector2 = Vector2.ZERO) -> float:
	var dir := direction
	if dir.length_squared() < 0.0001:
		dir = b.pos - a.pos
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	return a.half_extent_along(dir) + b.half_extent_along(-dir)


func _contact_distance(a: Regiment, b: Regiment) -> float:
	return _formation_clearance(a, b) + CONTACT_GAP


func _surface_gap(a: Regiment, b: Regiment) -> float:
	return a.pos.distance_to(b.pos) - _contact_distance(a, b)


func _in_contact(a: Regiment, b: Regiment) -> bool:
	return _surface_gap(a, b) <= CONTACT_TOLERANCE


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
