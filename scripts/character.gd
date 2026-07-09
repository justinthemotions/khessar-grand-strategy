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

# Module 2 flags — the dynasty layer's levers on a single life.
var is_bastard: bool = false       # born outside wedlock; barred from succession until legitimized
var disinherited: bool = false     # cast out of the line of succession by the dynasty head
var denounced: bool = false        # branded a house criminal: shunned, unseatable, uncommandable
var aggrieved: bool = false        # nurses a claim: refused a bequest or passed over — coup material
var bought_off: bool = false       # accepted a bequest; will not rise at the coronation

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

# The Memory Log: typed, decaying opinions of other characters.
# Entries: {"type": String, "subject": int, "value": float, "tick": int, "decay": float(/year)}
var memories: Array = []

# Heritable appearance genes (see genetics.gd); faces are drawn from this.
var genome: Dictionary = {}


func age_years(current_tick: int) -> int:
	return floori((current_tick - birth_tick) / 12.0)
