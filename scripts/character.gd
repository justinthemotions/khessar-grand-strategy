class_name SimCharacter
extends RefCounted

## One person in the dynasty simulation (Khessar GS, Module 1).
##
## Every cross-reference is an integer id into SimWorld.characters,
## never an object reference — this keeps save/load trivial later
## and lets a battle-layer hero point back at the same person.

var id: int = -1
var name: String = ""
var dynasty_id: int = -1
var realm_id: int = -1
var is_female: bool = false
var birth_tick: int = 0            # world tick (months since Jan 1066); negative = born before game start
var alive: bool = true
var spouse_id: int = -1
var father_id: int = -1
var mother_id: int = -1
var children_ids: Array[int] = []
var last_birth_tick: int = -999    # mothers only: cooldown between children
var culture: String = ""           # martial tradition practiced (Cultural Roster v1.0) — set by SimWorld
var race: String = "human"         # biology layer (Cross-Cultural Marriage v1.0) — set by SimWorld

# Module 2 flags — the dynasty layer's levers on a single life.
var is_bastard: bool = false       # born outside wedlock; barred from succession until legitimized
var disinherited: bool = false     # cast out of the line of succession by the dynasty head
var denounced: bool = false        # branded a house criminal: shunned, unseatable, uncommandable
var aggrieved: bool = false        # nurses a claim: refused a bequest or passed over — coup material
var bought_off: bool = false       # accepted a bequest; will not rise at the coronation
var slandered: bool = false        # Module 6: forged documents question this blood before the world

# The Core Six (design doc Module 1). 0–30 scale; traits push them around.
var diplomacy: int = 0     # negotiation, opinion gain, peacetime stability
var martial: int = 0       # army command, levy mobilization
var stewardship: int = 0   # domain capacity, tax revenue
var intrigue: int = 0      # scheme power and spy detection
var learning: int = 0      # law debate, technology, faith (later modules)
var prowess: int = 0       # personal lethality and battlefield survival

# Traits by category (see SimWorld.TRAITS): personality (max 3, drives AI),
# congenital (inheritable), health (acquired), coping (from stress breaks).
var traits: Array[String] = []

# Stress & mental health: contradicting your own personality has a price.
var stress: float = 0.0
var stress_level: int = 0          # breaks suffered: 0..3

# Magic Injection v1.0: the Patron's ledger and the Bard's burden.
var corruption: float = 0.0        # parallel to stress — but it never decays on its own
var corruption_marks: int = 0      # thresholds crossed at 5/10/15: 0..3
var names_carried: int = 0         # Song-Marked: dead-names carried between the fires
var oath_token_intact: bool = true # Oath-Sworn: the sworn object, still whole

# Religion & the Silence (Module 9 v1.0): what this soul answers to now,
# and the God of Thresholds' quiet ledger (addendum).
var faith: String = ""             # faith name; "" falls back by culture (SimWorld.faith_of)
var threshold_binding_bonus_permanent: float = 0.0  # earned rite by rite, capped at +0.6
var wooden_birds_carved: int = 0   # Gravewarden-Sworn: one per dead received

# The Hero System v1.0: hero-tier characters carry a class, a level, and
# a personal HP pool separate from any unit's. hero_level 0 = ordinary.
var hero_level: int = 0
var hero_xp: int = 0
var hero_class: String = ""
var hero_hp: int = 0               # current personal HP (battles spend it; months restore it)
var hero_hp_max: int = 0
var hero_combat_level: int = -1    # field-ability tier when it lags the craft (-1 = hero_level)
var hero_wounded_until: int = -1   # campaign tick before which the hero cannot take a field

# The Memory Log: typed, decaying opinions of other characters.
# Entries: {"type": String, "subject": int, "value": float, "tick": int, "decay": float(/year)}
var memories: Array = []

# Heritable appearance genes (see genetics.gd); faces are drawn from this.
var genome: Dictionary = {}


func age_years(current_tick: int) -> int:
	return floori((current_tick - birth_tick) / 12.0)
