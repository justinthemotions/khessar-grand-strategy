class_name HeroDB

## The Hero System v1.0 (Opus doc, 2026-07-08): the static tables.
##
## Heroes are distinguished individuals — practitioners whose personal
## actions meaningfully affect battles and campaigns. They amplify their
## armies; they do not replace them. This file holds everything that is
## data rather than simulation: the class list, per-level ability grants,
## XP thresholds, stat-growth pairs, and HP curves. The living state
## (level, XP, personal HP) rides on SimCharacter; the battle behavior
## lives in battle_sim.gd; the campaign wiring lives in world.gd.
##
## Doc fidelity notes:
##  - Fireball unlocks at LEVEL 5, per the doc's "(per your instinct)"
##    ruling — level 4 keeps Lightning Bolt / Ice Storm / Counterspell.
##  - Khessar follows the SRD 5.1: EXACTLY the eleven progression
##    classes, and classes belong to hero-tier (PC-chassis) characters
##    only. Everyone else is an ordinary soul identified by court
##    position (world.position_of) — spymaster, envoy, lord, courtier,
##    commoner — with no class, no level, no personal HP pool. Not
##    every soul has the potential for greatness, and that is what
##    makes the ones who do worth acquiring.
##  - The SRD provides ONE subclass per class; Khessar's own traditions
##    fill the gaps as SUBCLASSES (the Threshold Domain, the School of
##    Ward-Speech, the Oath of the Vigil, the College of Carried
##    Names...), never as new classes.
##  - A class is the D&D chassis; the campaign's practice TRAITS
##    (Arcane-Blooded, Faith-Practicing, Gravewarden-Sworn...) remain a
##    separate layer. Caeris is a level-9 Wizard by chassis and holds
##    no arcane practice trait — his school never touched the academy.
##  - "Intelligence" in the doc's stat-growth table maps to the Core
##    Six's Intrigue (the `int` short key), as in TraitData stats.

# XP required to STAND at a level (index = level; level 1 is the baseline).
const LEVEL_XP: Array[int] = [0, 0, 500, 1500, 3500, 7000, 12000, 20000, 32000, 50000, 75000]
const MAX_LEVEL := 10
const LEGENDARY_LEVEL := 8      # Legendary Actions and Legendary Resistance (doc §7)
const HP_PER_LEVEL := 8

# XP awards (doc §3). Ranges in the doc land on their midpoints.
const XP_AWARDS := {
	"battle_survived": 50,
	"battle_victory": 100,
	"tactical_success": 100,     # routing the enemy commander, destroying a unit
	"enemy_hero_killed": 300,    # personal combat contribution (doc: 200-500)
	"legendary_action": 100,     # per Legendary Action used successfully
	"council_vote": 25,          # attending with speaking participation
	"convocation": 150,
	"canonical_role": 200,       # coronations, ceremonies, treaty signings (100-300)
	"secret_discovered": 100,
	"research_published": 200,
	"bardic_performance": 25,
	"marriage_arranged": 100,
	"alliance_formed": 150,
	"peace_treaty": 200,
	"political_conversion": 250,
	"council_appointment": 200,
	"faction_leadership": 200,   # 150-300
	"order_promotion": 150,      # 100-200
	"chief_archivist": 500,      # the Marek-to-Thessaly succession, by name (doc §3)
	"threshold_rite": 40,
	"ceremony": 30,
}

# ---------------------------------------------------------------- classes
#
# base_hp: level-1 personal HP (doc §3: 40 baseline, wizards 30 frail,
# warriors 50 hearty). growth: the two Core Six short keys that gain +1
# per level. practice: which binary casting gate the class's workings
# roll (battle_sim.casting_reliability); "" = the craft never gates.
const CLASSES := {
	# --- the eleven, exactly as the SRD gives them (doc §4) ---
	"wizard":      {"label": "Wizard",      "base_hp": 30, "growth": ["lrn", "int"], "practice": "arcane"},
	"sorcerer":    {"label": "Sorcerer",    "base_hp": 30, "growth": ["dip", "lrn"], "practice": "arcane",
		"unreliable": 0.8, "cast_corruption": 0.5},   # doc §4.2: 20% less reliable, corruption per casting
	"cleric":      {"label": "Cleric",      "base_hp": 40, "growth": ["dip", "lrn"], "practice": "faith"},
	"paladin":     {"label": "Paladin",     "base_hp": 50, "growth": ["prw", "dip"], "practice": "oath"},
	"druid":       {"label": "Druid",       "base_hp": 40, "growth": ["lrn", "prw"], "practice": "primal"},
	"warlock":     {"label": "Warlock",     "base_hp": 40, "growth": ["lrn", "int"], "practice": ""},
	"bard":        {"label": "Bard",        "base_hp": 40, "growth": ["dip", "int"], "practice": ""},
	"monk":        {"label": "Monk",        "base_hp": 40, "growth": ["prw", "lrn"], "practice": ""},
	"fighter":     {"label": "Fighter",     "base_hp": 50, "growth": ["prw", "mar"], "practice": ""},
	"ranger":      {"label": "Ranger",      "base_hp": 50, "growth": ["mar", "lrn"], "practice": ""},
	"rogue":       {"label": "Rogue",       "base_hp": 40, "growth": ["int", "prw"], "practice": ""},
}

# ---------------------------------------------------------------- subclasses
#
# The SRD provides exactly one subclass per class (srd: true). Khessar's
# own traditions fill the rest of the shelf — this is where the setting's
# creativity lives, never in new classes. Optional keys:
#   practice: overrides the class's casting gate ("" = never gates —
#             threshold-work and ward-speech run on older theologies)
#   grants:   {level: [ability ids]} added to the class's grant flow
#   exclusive: true = the subclass's grants REPLACE the class table (a
#             tradition apart: Caeris never learned a fireball)
#   mods:     {pow_mult, heal_mult, rally_mult, vs_silence_mult,
#              song_cap, hero_strike_mult, aura: {...}} — battle tuning
const SUBCLASSES := {
	# --- Wizard ---
	"evocation":     {"class": "wizard", "label": "School of Evocation", "srd": true,
		"mods": {"pow_mult": 1.10}, "desc": "The academy's answer to most questions: more fire."},
	"unfinished":    {"class": "wizard", "label": "School of the Unfinished", "exclusive": true,
		"practice": "", "grants": {8: ["observe", "redirect", "settling_touch"]},
		"desc": "Old-tongue anchor-work at the threshold — one practitioner, one student, thirty-one years. It never touched the academy, and it does not fizzle under the Ashfields' sky."},
	"ward_speech":   {"class": "wizard", "label": "School of Ward-Speech", "exclusive": true,
		"practice": "", "grants": {1: ["stone_word"], 3: ["ward_lattice"], 6: ["deep_ward"]},
		"desc": "The Kharak-Dum lattice, spoken. Defense measured in generations, briefly portable."},
	"archive":       {"class": "wizard", "label": "School of the Archive", "exclusive": true,
		"practice": "", "grants": {},
		"desc": "The Iron Library's scholarship: the craft is the campaign — correspondence, cataloguing, the Record. No field orders; the field was never the point."},
	# --- Sorcerer ---
	"draconic":      {"class": "sorcerer", "label": "Draconic Bloodline", "srd": true,
		"mods": {"pow_mult": 1.05}, "desc": "The old blood, loud in the veins."},
	"silence_touched": {"class": "sorcerer", "label": "Silence-Touched Bloodline",
		"mods": {"pow_mult": 1.15}, "desc": "Manifestation the academies never caught — power with the ledger already open. (Awaits its named canon.)"},
	# --- Cleric ---
	"life":          {"class": "cleric", "label": "Life Domain", "srd": true,
		"mods": {"heal_mult": 1.25}, "desc": "The office of mending, kept whether or not anything answers."},
	"threshold":     {"class": "cleric", "label": "Threshold Domain",
		"practice": "", "grants": {1: ["witness"], 3: ["threshold_ward"], 5: ["last_rite"], 7: ["hold_the_door"]},
		"desc": "The Gravewarden's war: deaths witnessed, birds carved, doors held. The one practice that never stopped working — it does not gate."},
	"reclaimed_rites": {"class": "cleric", "label": "Domain of the Reclaimed Rites",
		"mods": {"rally_mult": 1.30, "aura": {"radius": 120.0, "lead": 3.0}},
		"desc": "The Reactionary liturgy: the old forms sung at full voice, because the singing is the argument."},
	# --- Paladin ---
	"devotion":      {"class": "paladin", "label": "Oath of Devotion", "srd": true,
		"desc": "The oath as the old orders swore it."},
	"vigil":         {"class": "paladin", "label": "Oath of the Vigil",
		"mods": {"vs_silence_mult": 2.0},
		"desc": "The Vigil-Sworn's oath: sworn against what the Silence left standing. Smites read the wrongness precisely."},
	# --- Druid ---
	"land":          {"class": "druid", "label": "Circle of the Land", "srd": true,
		"desc": "The green roads, where the green still answers."},
	# --- Warlock ---
	"fiend":         {"class": "warlock", "label": "The Fiend", "srd": true,
		"desc": "The SRD's patron. Khessar's is quieter."},
	"quiet_patron":  {"class": "warlock", "label": "The Patron of the Quiet",
		"mods": {"pow_mult": 1.10}, "desc": "The bargain Khessar actually offers — Silence-adjacent, patient, and always collecting. (Awaits its named canon.)"},
	# --- Bard ---
	"lore":          {"class": "bard", "label": "College of Lore", "srd": true,
		"mods": {"song_cap": 1.75}, "desc": "Songs learned from books."},
	"carried_names": {"class": "bard", "label": "College of Carried Names",
		"mods": {"song_cap": 2.0},
		"desc": "The Song-Marked tradition: dead-names carried between the fires, and every one of them weight and power both."},
	# --- Monk ---
	"open_hand":     {"class": "monk", "label": "Way of the Open Hand", "srd": true,
		"desc": "The body, precisely applied."},
	"brushgate":     {"class": "monk", "label": "The Brushgate Way",
		"mods": {"rally_mult": 1.20},
		"desc": "Stillness as countermeasure: sit with it until it passes. The morning forms spend the body slowly."},
	# --- Fighter ---
	"champion":      {"class": "fighter", "label": "Champion", "srd": true,
		"mods": {"aura": {"radius": 0.0, "ma": 2.0}},
		"desc": "Physical excellence; the hero's own line strikes harder for having them in it."},
	"clan_sworn":    {"class": "fighter", "label": "Clan-Sworn",
		"mods": {"rally_mult": 1.20, "aura": {"radius": 0.0, "ma": 1.0}},
		"desc": "The Drevak doctrine: clan-identity as armor, and a voice the war-columns answer."},
	# --- Ranger ---
	"hunter":        {"class": "ranger", "label": "Hunter", "srd": true,
		"desc": "The quarry named, the quarry taken."},
	"beastwarden":   {"class": "ranger", "label": "Beastwarden",
		"mods": {"pow_mult": 1.10}, "desc": "The northern territories' answer to what comes out of them. (Awaits its named canon.)"},
	# --- Rogue ---
	"thief":         {"class": "rogue", "label": "Thief", "srd": true,
		"desc": "The classic curriculum."},
	"watchful":      {"class": "rogue", "label": "The Watchful",
		"mods": {"hero_strike_mult": 1.5},
		"desc": "Counter-intelligence as a calling: the Spymaster's craft, the Order's quiet sister. Hero-hunting comes naturally."},
}

# ---------------------------------------------------------------- abilities
#
# kind vocabulary (consumed by battle_sim.use_hero_ability):
#   aoe        {radius, pow, shock}         damage every enemy line in the circle
#   line       {length, pow}                damage along a bolt from the hero's host
#   multi      {count, range, pow}          strike the N nearest enemy lines
#   single     {pow, shock, vs_silence}     one enemy line takes it whole
#   zone       {radius, dpt, dur}           a persistent working on the ground
#   timed      {dur, ma, md, ws_mult, dmg_mult, speed_mult, lead}
#              target "friend" buffs a line; target "enemy" afflicts one
#   rally      {radius, amount}             lift shock from friendly lines
#   shockwave  {radius, amount}             drive shock into enemy lines
#   heal       {amount} / heal_area {radius, amount}
#   hero_strike {pow}                       hero-hunting: damage the enemy hero
#   dispel     {}                           clear enemy zones and friendly afflictions
#   aura       passive: {radius, lead, md, ma, terror_block, missile_block}
#              radius 0 reaches only the hero's own host line
#   counterspell {uses} / death_ward / dodge {mult}   passive self effects
#   utility    {}                           narrative only — no field mechanic
# target: "point" | "enemy" | "friend" | "none" (self/instant)
# song_scaled: amounts scale ×(1 + names_carried/200), capped ×2 (the
# same law as the commander-scale song aura).
const ABILITIES := {
	# --- Wizard (doc §4.1) ---
	"flame_hands":     {"label": "Flame Hands",     "kind": "aoe", "target": "point", "radius": 45.0, "pow": 25.0, "shock": 4.0, "cd": 16, "uses": 3, "desc": "A short cone of fire — local damage."},
	"detect_magic":    {"label": "Detect Magic",    "kind": "utility", "desc": "The formulas nearby declare themselves."},
	"prestidigitation": {"label": "Prestidigitation", "kind": "utility", "desc": "Minor manipulation; the small conveniences of the craft."},
	"burning_hands":   {"label": "Burning Hands",   "kind": "aoe", "target": "point", "radius": 55.0, "pow": 32.0, "shock": 5.0, "cd": 16, "uses": 3, "desc": "The wider cone."},
	"magic_missile":   {"label": "Magic Missile",   "kind": "single", "target": "enemy", "pow": 18.0, "shock": 2.0, "cd": 10, "uses": 4, "desc": "It does not miss."},
	"sleep_working":   {"label": "Sleep",           "kind": "timed", "target": "enemy", "dur": 14, "speed_mult": 0.3, "ma": -6.0, "cd": 22, "uses": 2, "desc": "The front rank's eyes grow heavy."},
	"scorching_ray":   {"label": "Scorching Ray",   "kind": "multi", "target": "point", "count": 3, "range": 260.0, "pow": 16.0, "cd": 18, "uses": 3, "desc": "Three rays, three lines struck."},
	"web_working":     {"label": "Web",             "kind": "timed", "target": "enemy", "dur": 20, "speed_mult": 0.35, "md": -4.0, "cd": 24, "uses": 2, "desc": "The ground itself holds them."},
	"invisibility":    {"label": "Invisibility",    "kind": "utility", "desc": "Personal utility; the field does not see it."},
	"lightning_bolt":  {"label": "Lightning Bolt",  "kind": "line", "target": "point", "length": 240.0, "pow": 40.0, "cd": 22, "uses": 2, "desc": "A line of ruin from the hero's hand."},
	"ice_storm":       {"label": "Ice Storm",       "kind": "aoe", "target": "point", "radius": 60.0, "pow": 28.0, "shock": 6.0, "slow_dur": 10, "slow_mult": 0.6, "cd": 24, "uses": 2, "desc": "Hail and cold; the advance stumbles."},
	"counterspell":    {"label": "Counterspell",    "kind": "counterspell", "uses": 1, "desc": "The enemy's working dies mid-air. Once."},
	"fireball":        {"label": "Fireball",        "kind": "aoe", "target": "point", "radius": 70.0, "pow": 85.0, "shock": 15.0, "cd": 30, "uses": 2, "desc": "The level-five spell. A formed regiment is not formed afterward."},
	"wall_of_fire":    {"label": "Wall of Fire",    "kind": "zone", "target": "point", "radius": 55.0, "dpt": 6.0, "dur": 24, "cd": 30, "uses": 1, "desc": "A persistent burning ground."},
	"cone_of_cold":    {"label": "Cone of Cold",    "kind": "aoe", "target": "point", "radius": 65.0, "pow": 60.0, "shock": 8.0, "slow_dur": 8, "slow_mult": 0.7, "cd": 28, "uses": 1, "desc": "A killing frost across the line."},
	"cloudkill":       {"label": "Cloudkill",       "kind": "zone", "target": "point", "radius": 50.0, "dpt": 7.0, "dur": 20, "cd": 30, "uses": 1, "desc": "A necrotic fog that holds its ground."},
	"chain_lightning": {"label": "Chain Lightning", "kind": "multi", "target": "point", "count": 5, "range": 300.0, "pow": 30.0, "cd": 30, "uses": 1, "desc": "It arcs until it runs out of lines to find."},
	"bigbys_hand":     {"label": "Bigby's Hand",    "kind": "zone", "target": "point", "radius": 45.0, "dpt": 5.0, "dur": 20, "cd": 28, "uses": 1, "desc": "A persistent presence on the field."},
	"wall_of_force":   {"label": "Wall of Force",   "kind": "timed", "target": "friend", "dur": 16, "dmg_mult": 0.5, "missile_immune": true, "cd": 30, "uses": 1, "desc": "An impenetrable barrier over one line."},
	"contingency":     {"label": "Contingency",     "kind": "utility", "desc": "Defensive planning; it pays off elsewhere."},
	"meteor_swarm":    {"label": "Meteor Swarm",    "kind": "aoe", "target": "point", "radius": 90.0, "pow": 150.0, "shock": 25.0, "cd": 40, "uses": 1, "desc": "The sky falls where the hero points."},
	"time_stop":       {"label": "Time Stop",       "kind": "timed", "target": "enemy", "dur": 4, "speed_mult": 0.01, "ma": -20.0, "all_enemies": true, "cd": 40, "uses": 1, "desc": "Very brief. Long enough."},
	"wish_limited":    {"label": "Wish (limited)",  "kind": "utility", "desc": "Limited utility; the chronicle decides what it cost."},
	"prismatic_wall":  {"label": "Prismatic Wall",  "kind": "timed", "target": "friend", "dur": 20, "dmg_mult": 0.6, "missile_immune": true, "cd": 34, "uses": 1, "desc": "Varied protection, layered."},

	# --- Cleric (doc §4.3) ---
	"bless":           {"label": "Bless",           "kind": "timed", "target": "friend", "dur": 16, "ma": 4.0, "md": 2.0, "cd": 20, "uses": 2, "desc": "The old blessing, spoken over one line."},
	"guiding_bolt":    {"label": "Guiding Bolt",    "kind": "single", "target": "enemy", "pow": 15.0, "shock": 3.0, "cd": 12, "uses": 3, "desc": "A small radiant strike."},
	"cure_wounds":     {"label": "Cure Wounds",     "kind": "heal", "target": "friend", "amount": 60.0, "cd": 16, "uses": 3, "desc": "Men who were down stand back up."},
	"sanctuary":       {"label": "Sanctuary",       "kind": "utility", "desc": "Personal protection; the office endures."},
	"spiritual_weapon": {"label": "Spiritual Weapon", "kind": "zone", "target": "point", "radius": 40.0, "dpt": 4.0, "dur": 16, "cd": 24, "uses": 2, "desc": "A persistent attacker that never tires."},
	"aid_working":     {"label": "Aid",             "kind": "timed", "target": "friend", "dur": 20, "lead": 6.0, "md": 1.0, "cd": 20, "uses": 2, "desc": "The line feels looked after."},
	"prayer_of_healing": {"label": "Prayer of Healing", "kind": "heal_area", "target": "point", "radius": 80.0, "amount": 40.0, "cd": 26, "uses": 2, "desc": "Multi-line healing, spoken aloud."},
	"beacon_of_hope":  {"label": "Beacon of Hope",  "kind": "rally", "target": "point", "radius": 90.0, "amount": 25.0, "cd": 24, "uses": 2, "desc": "The wavering remember why they stand."},
	"mass_healing_word": {"label": "Mass Healing Word", "kind": "heal_area", "target": "point", "radius": 100.0, "amount": 30.0, "cd": 26, "uses": 2, "desc": "One word, many lines."},
	"spirit_guardians": {"label": "Spirit Guardians", "kind": "zone", "target": "point", "radius": 50.0, "dpt": 5.0, "dur": 20, "cd": 28, "uses": 1, "desc": "A protective zone that bites."},
	"divination":      {"label": "Divination",      "kind": "utility", "desc": "Answers, for a price paid elsewhere."},
	"death_ward":      {"label": "Death Ward",      "kind": "death_ward", "desc": "The first killing blow is refused. Once."},
	"guardian_of_faith": {"label": "Guardian of Faith", "kind": "zone", "target": "point", "radius": 45.0, "dpt": 6.0, "dur": 20, "cd": 28, "uses": 1, "desc": "A persistent protective presence."},
	"flame_strike":    {"label": "Flame Strike",    "kind": "aoe", "target": "point", "radius": 60.0, "pow": 70.0, "shock": 12.0, "cd": 30, "uses": 1, "desc": "Fire from a clear sky."},
	"raise_dead":      {"label": "Raise Dead",      "kind": "utility", "desc": "Rare, canonical-event-only. Not a field mechanic — and in Khessar, a theological argument."},
	"contagion":       {"label": "Contagion",       "kind": "timed", "target": "enemy", "dur": 20, "ma": -5.0, "md": -3.0, "cd": 26, "uses": 1, "desc": "The debuff nobody sings about."},
	"insect_plague":   {"label": "Insect Plague",   "kind": "zone", "target": "point", "radius": 60.0, "dpt": 5.0, "dur": 24, "cd": 30, "uses": 1, "desc": "Persistent, indiscriminate misery."},
	"blade_barrier":   {"label": "Blade Barrier",   "kind": "zone", "target": "point", "radius": 65.0, "dpt": 8.0, "dur": 24, "cd": 34, "uses": 1, "desc": "A wall of turning blades."},
	"forbiddance":     {"label": "Forbiddance",     "kind": "utility", "desc": "Large-area protection; a campaign working, not a field one."},
	"harm_working":    {"label": "Harm",            "kind": "single", "target": "enemy", "pow": 80.0, "shock": 10.0, "cd": 32, "uses": 1, "desc": "Major damage, delivered personally."},
	"heal_major":      {"label": "Heal",            "kind": "heal", "target": "friend", "amount": 120.0, "cd": 30, "uses": 1, "desc": "Major healing — a line rebuilt."},

	# --- Paladin (doc §4.4) ---
	"divine_sense":    {"label": "Divine Sense",    "kind": "utility", "desc": "The wrongness declares itself to the sworn."},
	"lay_on_hands":    {"label": "Lay on Hands",    "kind": "heal", "target": "friend", "amount": 40.0, "cd": 20, "uses": 2, "desc": "Minor healing by touch."},
	"divine_smite":    {"label": "Divine Smite",    "kind": "single", "target": "enemy", "pow": 25.0, "shock": 4.0, "vs_silence": 1.5, "cd": 14, "uses": 3, "desc": "Oath-magic answers what should not stand."},
	"improved_smite":  {"label": "Improved Smite",  "kind": "single", "target": "enemy", "pow": 45.0, "shock": 6.0, "vs_silence": 1.5, "cd": 16, "uses": 3, "desc": "The oath speaks louder."},
	"channel_divinity": {"label": "Channel Divinity", "kind": "rally", "target": "point", "radius": 70.0, "amount": 20.0, "cd": 24, "uses": 2, "desc": "The sworn presence, made audible."},
	"divine_health":   {"label": "Divine Health",   "kind": "utility", "desc": "Immunity to disease; the campaign remembers it."},
	"aura_of_protection": {"label": "Aura of Protection", "kind": "aura", "radius": 140.0, "lead": 6.0, "md": 1.0, "terror_block": 1.0, "desc": "Allies near the paladin do not fear — anything."},
	"aura_of_devotion": {"label": "Aura of Devotion", "kind": "aura", "radius": 160.0, "lead": 8.0, "desc": "Protection against what charms and what breaks."},
	"cleansing_touch": {"label": "Cleansing Touch", "kind": "dispel", "target": "none", "cd": 30, "uses": 1, "desc": "The workings on this field are dismissed."},

	# --- Druid (doc §4.5) ---
	"entangle":        {"label": "Entangle",        "kind": "timed", "target": "enemy", "dur": 16, "speed_mult": 0.4, "cd": 18, "uses": 3, "desc": "The ground grows hands."},
	"cure_wounds_druid": {"label": "Cure Wounds",   "kind": "heal", "target": "friend", "amount": 50.0, "cd": 18, "uses": 2, "desc": "Green mending."},
	"speak_with_animals": {"label": "Speak with Animals", "kind": "utility", "desc": "The field has more scouts than it appears."},
	"barkskin":        {"label": "Barkskin",        "kind": "timed", "target": "friend", "dur": 20, "dmg_mult": 0.75, "cd": 22, "uses": 2, "desc": "One line weathers like old oak."},
	"beast_sense":     {"label": "Beast Sense",     "kind": "utility", "desc": "Eyes elsewhere."},
	"enhance_ability": {"label": "Enhance Ability", "kind": "timed", "target": "friend", "dur": 16, "ma": 3.0, "cd": 18, "uses": 2, "desc": "The body remembers what it can do."},
	"call_lightning":  {"label": "Call Lightning",  "kind": "aoe", "target": "point", "radius": 50.0, "pow": 45.0, "shock": 8.0, "cd": 24, "uses": 2, "desc": "The sky answers — where the sky still answers."},
	"wind_wall":       {"label": "Wind Wall",       "kind": "timed", "target": "friend", "dur": 16, "missile_immune": true, "cd": 24, "uses": 1, "desc": "Arrows have opinions; the wind disagrees."},
	"ice_storm_druid": {"label": "Ice Storm",       "kind": "aoe", "target": "point", "radius": 60.0, "pow": 28.0, "shock": 6.0, "slow_dur": 10, "slow_mult": 0.6, "cd": 24, "uses": 2, "desc": "Hail called, not conjured."},
	"wall_of_fire_druid": {"label": "Wall of Fire", "kind": "zone", "target": "point", "radius": 55.0, "dpt": 6.0, "dur": 24, "cd": 30, "uses": 1, "desc": "The old fire, the green way."},
	"awaken":          {"label": "Awaken",          "kind": "utility", "desc": "Canonical. Something in the wood now has a name."},
	"insect_plague_druid": {"label": "Insect Plague", "kind": "zone", "target": "point", "radius": 60.0, "dpt": 5.0, "dur": 24, "cd": 30, "uses": 1, "desc": "Persistent damage with wings."},
	"wall_of_stone":   {"label": "Wall of Stone",   "kind": "timed", "target": "enemy", "dur": 14, "speed_mult": 0.0, "cd": 30, "uses": 1, "desc": "One line finds the ground risen against it."},

	# --- Warlock (doc §4.6) — the Patron never gates, and always collects ---
	"eldritch_blast":  {"label": "Eldritch Blast",  "kind": "single", "target": "enemy", "pow": 22.0, "shock": 3.0, "corruption": 0.3, "cd": 10, "uses": 5, "desc": "The Patron's arithmetic, small change."},
	"eldritch_lash":   {"label": "Eldritch Lash",   "kind": "aoe", "target": "point", "radius": 45.0, "pow": 35.0, "shock": 8.0, "corruption": 0.8, "cd": 20, "uses": 2, "desc": "Wider terms. Higher price."},
	"hunger_of_the_void": {"label": "Hunger of the Void", "kind": "zone", "target": "point", "radius": 55.0, "dpt": 6.0, "dur": 18, "corruption": 1.5, "cd": 28, "uses": 1, "desc": "A patch of field stops being entirely here."},
	"patron_dread":    {"label": "Patron's Dread",  "kind": "shockwave", "target": "point", "radius": 120.0, "amount": 15.0, "corruption": 2.0, "cd": 30, "uses": 1, "desc": "Every line nearby feels what rides with the caster."},

	# --- Bard (doc §4.7) — scaled by the names carried ---
	"vicious_mockery": {"label": "Vicious Mockery", "kind": "shockwave", "target": "enemy", "amount": 8.0, "song_scaled": true, "cd": 12, "uses": 4, "desc": "Words, weaponized. It rhymes."},
	"bardic_inspiration": {"label": "Bardic Inspiration", "kind": "timed", "target": "friend", "dur": 16, "ma": 3.0, "lead": 5.0, "song_scaled": true, "cd": 14, "uses": 3, "desc": "One line fights like the song says they did."},
	"song_of_rest":    {"label": "Song of Rest",    "kind": "heal_area", "target": "point", "radius": 90.0, "amount": 25.0, "song_scaled": true, "cd": 24, "uses": 2, "desc": "The fires between battles, brought onto the field."},
	"song_of_courage": {"label": "Song of Courage", "kind": "rally", "target": "point", "radius": 100.0, "amount": 15.0, "song_scaled": true, "cd": 22, "uses": 2, "desc": "The names carried hold the line that hears them."},
	"countercharm":    {"label": "Countercharm",    "kind": "aura", "radius": 140.0, "terror_block": 1.0, "desc": "No wrongness out-sings a Bard at their work."},
	"legend_song":     {"label": "The Legend Song", "kind": "rally", "target": "point", "radius": 160.0, "amount": 30.0, "song_scaled": true, "cd": 40, "uses": 1, "desc": "Every carried name at once. Sung once per field."},

	# --- Monk (doc §4.8) — Brushgate: the body is not casting ---
	"focused_presence": {"label": "Focused Presence", "kind": "rally", "target": "point", "radius": 60.0, "amount": 15.0, "cd": 16, "uses": 3, "desc": "Stillness, projected."},
	"stunning_strike": {"label": "Stunning Strike", "kind": "timed", "target": "enemy", "dur": 12, "ma": -6.0, "ws_mult": 0.8, "cd": 22, "uses": 2, "desc": "The precise interruption of intent."},
	"ki_burst":        {"label": "Ki Burst",        "kind": "single", "target": "enemy", "pow": 40.0, "shock": 10.0, "cd": 24, "uses": 2, "desc": "The morning forms, concluded emphatically."},

	# --- Fighter / Champion (doc §4.9) ---
	"second_wind":     {"label": "Second Wind",     "kind": "heal", "target": "friend", "amount": 30.0, "cd": 20, "uses": 2, "desc": "The commander steadies their own."},
	"action_surge":    {"label": "Action Surge",    "kind": "timed", "target": "friend", "dur": 10, "ws_mult": 1.5, "cd": 26, "uses": 1, "desc": "Everything, now."},
	"rallying_cry":    {"label": "Rallying Cry",    "kind": "rally", "target": "point", "radius": 90.0, "amount": 18.0, "cd": 22, "uses": 2, "desc": "A voice that carries over the noise."},
	"extra_attack":    {"label": "Extra Attack",    "kind": "aura", "radius": 0.0, "ma": 6.0, "desc": "The hero's own line strikes with them in it."},
	"held_line":       {"label": "The Held Line",   "kind": "aura", "radius": 100.0, "md": 3.0, "desc": "Nearby lines dress on the hero's."},

	# --- Ranger / Beastwarden (doc §4.10) ---
	"hunters_mark":    {"label": "Hunter's Mark",   "kind": "timed", "target": "enemy", "dur": 20, "dmg_mult": 1.2, "cd": 16, "uses": 3, "desc": "That one. Everyone hit that one."},
	"hail_of_thorns":  {"label": "Hail of Thorns",  "kind": "aoe", "target": "point", "radius": 50.0, "pow": 30.0, "shock": 4.0, "cd": 20, "uses": 2, "desc": "The volley grows teeth."},
	"beast_strike":    {"label": "Beast Companion", "kind": "single", "target": "enemy", "pow": 25.0, "shock": 5.0, "cd": 18, "uses": 3, "desc": "Something fast with an opinion."},
	"volley":          {"label": "Volley",          "kind": "aoe", "target": "point", "radius": 65.0, "pow": 45.0, "shock": 5.0, "cd": 26, "uses": 2, "desc": "Everything airborne at once."},

	# --- Rogue (doc §4.11) ---
	"sneak_strike":    {"label": "Sneak Attack",    "kind": "single", "target": "enemy", "pow": 20.0, "shock": 3.0, "flat": true, "cd": 14, "uses": 3, "desc": "Armour is a suggestion from certain angles."},
	"cunning_action":  {"label": "Cunning Action",  "kind": "timed", "target": "friend", "dur": 12, "speed_mult": 1.3, "cd": 18, "uses": 2, "desc": "Somewhere else, suddenly."},
	"assassinate":     {"label": "Assassinate",     "kind": "hero_strike", "target": "none", "pow": 25.0, "cd": 30, "uses": 1, "desc": "Hero-hunting. The enemy's commander bleeds."},
	"uncanny_dodge":   {"label": "Uncanny Dodge",   "kind": "dodge", "mult": 0.5, "desc": "What reaches the hero, reaches half of them."},

	# --- Gravewarden (doc §5) — threshold-work on the field ---
	"witness":         {"label": "Witness",         "kind": "rally", "target": "point", "radius": 80.0, "amount": 12.0, "cd": 18, "uses": 3, "desc": "These dead are seen. The living hold."},
	"threshold_ward":  {"label": "Threshold Ward",  "kind": "aura", "radius": 120.0, "terror_block": 0.5, "desc": "The wrongness breaks against a held door."},
	"last_rite":       {"label": "The Last Rite",   "kind": "single", "target": "enemy", "pow": 60.0, "shock": 8.0, "vs_silence": 1.5, "cd": 24, "uses": 2, "desc": "What was never witnessed is witnessed now, emphatically."},
	"hold_the_door":   {"label": "Hold the Door",   "kind": "timed", "target": "enemy", "dur": 16, "ma": -5.0, "md": -5.0, "silence_only": true, "cd": 30, "uses": 1, "desc": "The unwitnessed dead feel the threshold close."},

	# --- Ward-Speaker (doc §5: the Dwarven-specific hero type) ---
	"stone_word":      {"label": "Stone-Word",      "kind": "timed", "target": "friend", "dur": 16, "dmg_mult": 0.8, "cd": 18, "uses": 3, "desc": "One line, spoken solid."},
	"ward_lattice":    {"label": "Ward Lattice",    "kind": "aura", "radius": 120.0, "missile_block": 0.15, "desc": "The old lattice, walking."},
	"deep_ward":       {"label": "The Deep Ward",   "kind": "aura", "radius": 130.0, "lead": 6.0, "terror_block": 0.5, "desc": "What held the holds for generations, briefly portable."},

	# --- Scholar: Caeris's Legendary Actions (Opus doc §4, Canon Updates) ---
	"observe":         {"label": "Observe",         "kind": "timed", "target": "enemy", "dur": 12, "md": -4.0, "cd": 20, "uses": 3, "desc": "He has read this formation. Twenty years ago. Twice."},
	"redirect":        {"label": "Redirect",        "kind": "timed", "target": "friend", "dur": 10, "dmg_mult": 0.6, "cd": 20, "uses": 3, "desc": "The blow lands where he decided it would."},
	"settling_touch":  {"label": "The Settling Touch", "kind": "single", "target": "enemy", "pow": 15.0, "shock": 20.0, "cd": 26, "uses": 2, "desc": "For a few of them, the settling comes early. He notes the data."},
}

# ---------------------------------------------------------------- grants
#
# Per-class, per-level ability unlocks (cumulative). The doc's utility
# spells ride along for the record; only entries with field mechanics
# become buttons and AI options.
const GRANTS := {
	"wizard": {
		1: ["flame_hands", "detect_magic", "prestidigitation"],
		2: ["burning_hands", "magic_missile", "sleep_working"],
		3: ["scorching_ray", "web_working", "invisibility"],
		4: ["lightning_bolt", "counterspell", "ice_storm"],
		5: ["fireball", "wall_of_fire", "cone_of_cold", "cloudkill"],
		6: ["chain_lightning", "bigbys_hand", "wall_of_force", "contingency"],
		7: ["meteor_swarm", "time_stop", "wish_limited", "prismatic_wall"],
	},
	# Sorcerers cast the Wizard list with different costs (doc §4.2):
	# the class carries `unreliable` ×0.8 on every gate and corruption
	# per casting — the table itself is shared.
	"sorcerer": {
		1: ["flame_hands", "detect_magic", "prestidigitation"],
		2: ["burning_hands", "magic_missile", "sleep_working"],
		3: ["scorching_ray", "web_working", "invisibility"],
		4: ["lightning_bolt", "counterspell", "ice_storm"],
		5: ["fireball", "wall_of_fire", "cone_of_cold", "cloudkill"],
		6: ["chain_lightning", "bigbys_hand", "wall_of_force", "contingency"],
		7: ["meteor_swarm", "time_stop", "wish_limited", "prismatic_wall"],
	},
	"cleric": {
		1: ["bless", "guiding_bolt", "cure_wounds", "sanctuary"],
		2: ["spiritual_weapon", "aid_working", "prayer_of_healing"],
		3: ["beacon_of_hope", "mass_healing_word", "spirit_guardians"],
		4: ["divination", "death_ward", "guardian_of_faith"],
		5: ["flame_strike", "raise_dead", "contagion", "insect_plague"],
		6: ["blade_barrier", "forbiddance", "harm_working", "heal_major"],
	},
	"paladin": {
		1: ["divine_sense", "lay_on_hands", "divine_smite"],
		3: ["channel_divinity", "divine_health"],
		5: ["improved_smite", "aura_of_protection"],
		6: ["aura_of_devotion"],
		7: ["cleansing_touch"],
	},
	"druid": {
		1: ["entangle", "cure_wounds_druid", "speak_with_animals"],
		2: ["barkskin", "beast_sense", "enhance_ability"],
		3: ["call_lightning", "wind_wall"],
		4: ["ice_storm_druid", "wall_of_fire_druid"],
		5: ["awaken", "insect_plague_druid", "wall_of_stone"],
	},
	"warlock": {
		1: ["eldritch_blast"],
		3: ["eldritch_lash"],
		5: ["hunger_of_the_void"],
		6: ["patron_dread"],
	},
	"bard": {
		1: ["vicious_mockery", "bardic_inspiration"],
		2: ["song_of_rest"],
		3: ["song_of_courage"],
		6: ["countercharm"],
		7: ["legend_song"],
	},
	"monk": {
		1: ["focused_presence"],
		5: ["stunning_strike"],
		6: ["ki_burst"],
	},
	"fighter": {
		1: ["second_wind"],
		2: ["action_surge"],
		3: ["rallying_cry"],
		5: ["extra_attack"],
		6: ["held_line"],
	},
	"ranger": {
		1: ["hunters_mark"],
		2: ["hail_of_thorns"],
		3: ["beast_strike"],
		5: ["volley"],
	},
	"rogue": {
		1: ["sneak_strike"],
		2: ["cunning_action"],
		3: ["assassinate"],
		5: ["uncanny_dodge"],
	},
}


static func has_class(class_id: String) -> bool:
	return CLASSES.has(class_id)


static func class_label(class_id: String) -> String:
	if not CLASSES.has(class_id):
		return class_id.capitalize()
	return str(CLASSES[class_id]["label"])


static func xp_for_level(level: int) -> int:
	return LEVEL_XP[clampi(level, 1, MAX_LEVEL)]


static func level_for_xp(xp: int) -> int:
	var level := 1
	while level < MAX_LEVEL and xp >= LEVEL_XP[level + 1]:
		level += 1
	return level


static func base_hp(class_id: String) -> int:
	if not CLASSES.has(class_id):
		return 40
	return int(CLASSES[class_id]["base_hp"])


static func hp_max(class_id: String, level: int) -> int:
	return base_hp(class_id) + HP_PER_LEVEL * (clampi(level, 1, MAX_LEVEL) - 1)


static func growth(class_id: String) -> Array:
	if not CLASSES.has(class_id):
		return []
	return CLASSES[class_id]["growth"]


static func has_subclass(sub_id: String) -> bool:
	return SUBCLASSES.has(sub_id)


static func default_subclass(class_id: String) -> String:
	## The SRD's own subclass — what an unspecified hero of the class walks.
	for sid in SUBCLASSES:
		if str(SUBCLASSES[sid]["class"]) == class_id and bool(SUBCLASSES[sid].get("srd", false)):
			return str(sid)
	return ""


static func sub_label(sub_id: String) -> String:
	if not SUBCLASSES.has(sub_id):
		return sub_id.capitalize()
	return str(SUBCLASSES[sub_id]["label"])


static func sub_mods(sub_id: String) -> Dictionary:
	if not SUBCLASSES.has(sub_id):
		return {}
	return SUBCLASSES[sub_id].get("mods", {})


static func practice_for(class_id: String, sub_id: String = "") -> String:
	## The casting gate the hero's workings roll: a subclass may walk an
	## older theology than its class ("" = never gates).
	var sub: Dictionary = SUBCLASSES.get(sub_id, {})
	if sub.has("practice"):
		return str(sub["practice"])
	if not CLASSES.has(class_id):
		return ""
	return str(CLASSES[class_id]["practice"])


static func practice(class_id: String) -> String:
	return practice_for(class_id, "")


static func info(ability_id: String) -> Dictionary:
	return ABILITIES.get(ability_id, {})


static func abilities_at(class_id: String, level: int, sub_id: String = "") -> Array:
	## Every ability unlocked by `level`: the class table plus the
	## subclass's grants — or the subclass's grants ALONE when the
	## tradition stands apart (exclusive: Caeris never learned a
	## fireball, and the ward-speakers never wanted one).
	var out: Array = []
	var sub: Dictionary = SUBCLASSES.get(sub_id, {})
	if not bool(sub.get("exclusive", false)):
		var grants: Dictionary = GRANTS.get(class_id, {})
		for l in range(1, clampi(level, 1, MAX_LEVEL) + 1):
			if grants.has(l):
				out.append_array(grants[l])
	var sub_grants: Dictionary = sub.get("grants", {})
	for l in range(1, clampi(level, 1, MAX_LEVEL) + 1):
		if sub_grants.has(l):
			out.append_array(sub_grants[l])
	return out


static func battle_actives(class_id: String, level: int, sub_id: String = "") -> Array:
	## The unlocked abilities that are usable orders on the field —
	## everything except utility entries and passives.
	var out: Array = []
	for aid in abilities_at(class_id, level, sub_id):
		var kind := str(ABILITIES[aid]["kind"])
		if kind in ["utility", "aura", "counterspell", "death_ward", "dodge"]:
			continue
		out.append(aid)
	return out


static func battle_passives(class_id: String, level: int, sub_id: String = "") -> Array:
	var out: Array = []
	for aid in abilities_at(class_id, level, sub_id):
		var kind := str(ABILITIES[aid]["kind"])
		if kind in ["aura", "counterspell", "death_ward", "dodge"]:
			out.append(aid)
	return out
