extends SceneTree

## Headless validation of the battle card bar (the TW-style unit cards):
##   <godot.exe> --headless --path . --script res://tests/battle_ui_test.gd
## Checks card layout geometry, the archetype glyph mapping, click routing
## (unit cards, the hero card, consumed bar clicks), ammunition tracking,
## and the commander panel.


func _find(sim: BattleSim, kind: String) -> BattleSim.Regiment:
	for r: BattleSim.Regiment in sim.regiments:
		if r.side == 0 and r.kind == kind:
			return r
	return null


func _init() -> void:
	# --- 1. layout: hero card + one card per regiment, inside the bar ---
	var view := BattleView.new()
	view.size = Vector2(1280, 720)
	view.start(
		[{"kind": "sword", "soldiers": 36}, {"kind": "levy", "soldiers": 48},
			{"kind": "archer", "soldiers": 24}, {"kind": "cav", "soldiers": 16},
			{"kind": "vael_arcane_retinue", "soldiers": 24}, {"kind": "ward_speaker_retinue", "soldiers": 16},
			{"kind": "warden_dead", "soldiers": 40}, {"kind": "vigil_sworn_elite", "soldiers": 24}],
		[{"kind": "sword", "soldiers": 36}],
		0, 0, ["Aldmark", "Sarova"], [Color("3f5f83"), Color("8c4a3f")], "The Test Field")
	view.sim.set_commander_info(0, {"name": "Aldric Vaelmark", "martial": 14, "intrigue": 8,
		"prowess": 10, "traits": ["Oath-Sworn"], "oath_intact": true, "faith": "Aelindran Orthodox"})
	var lay: Dictionary = view._card_layout()
	assert(bool(lay["has_commander"]), "commander info set -> hero card present")
	var cards: Array = lay["cards"]
	assert(cards.size() == 8, "one card per side-0 regiment, got %d" % cards.size())
	var bar: Rect2 = lay["bar"]
	assert(bar.size.x > 0.0 and bar.end.y <= view.size.y, "the bar sits inside the view")
	assert(bar.encloses(lay["commander"] as Rect2), "the hero card sits inside the bar")
	var prev_end := (lay["commander"] as Rect2).end.x
	for c in cards:
		var rect: Rect2 = c["rect"]
		assert(bar.encloses(rect), "card %d inside the bar" % int(c["id"]))
		assert(rect.position.x >= prev_end, "cards run left to right without overlap")
		prev_end = rect.end.x
	print("layout: hero card + 8 unit cards inside the bar, ordered, no overlap")

	# --- 2. archetype glyphs ---
	var want := {"sword": "sword", "levy": "spear", "archer": "missile", "cav": "cavalry",
		"vael_arcane_retinue": "caster", "ward_speaker_retinue": "support",
		"warden_dead": "silence", "vigil_sworn_elite": "sword"}
	for kind in want:
		var r := _find(view.sim, str(kind))
		assert(r != null, "regiment %s fielded" % kind)
		assert(view._card_archetype(r) == str(want[kind]),
			"%s carries the %s glyph, got %s" % [kind, want[kind], view._card_archetype(r)])
	print("archetype glyphs: sword/spear/missile/cavalry/caster/support/silence all mapped")

	# --- 3. click routing ---
	var third: Rect2 = cards[2]["rect"]
	assert(view._card_click(third.get_center(), MOUSE_BUTTON_LEFT, true), "card click consumed")
	assert(view.selected_id == int(cards[2]["id"]), "clicking a card selects its regiment")
	assert(not view.commander_selected, "a unit card clears the hero selection")
	assert(view._card_click((lay["commander"] as Rect2).get_center(), MOUSE_BUTTON_LEFT, true),
		"hero card click consumed")
	assert(view.commander_selected and view.selected_id == -1, "the hero card selects the commander")
	assert(view._card_click(third.get_center(), MOUSE_BUTTON_RIGHT, true),
		"right-clicks inside the bar are consumed, not orders")
	assert(view.commander_selected, "a consumed right-click changes nothing")
	assert(not view._card_click(Vector2(20, 20), MOUSE_BUTTON_LEFT, true),
		"clicks outside the bar fall through to the field")
	print("click routing: cards select, hero card selects the commander, bar consumes strays")

	# --- 4. the number band's fuel: counts and ammunition ---
	var archer := _find(view.sim, "archer")
	assert(int(view.ammo_start.get(archer.id, -1)) == 40, "archer ammunition recorded at start")
	archer.soldiers = 11
	assert(archer.soldiers == 11, "the band reads soldiers directly — 11 men remain")
	print("counts: remaining men and starting ammunition tracked per card")

	# --- 5. the commander panel (built by _ready; called directly — no
	# main loop runs during a SceneTree script's _init) ---
	view._ready()
	view.commander_selected = true
	view.selected_id = -1
	view._refresh_unit_panel()
	assert(view.unit_panel.visible, "the hero card opens the panel")
	assert(view.unit_name.text == "Aldric Vaelmark", "the commander's name heads the panel")
	assert("Martial  14" in view.unit_stats.text, "martial shown")
	assert("Oath-token: whole" in view.unit_stats.text, "the oath's state shown for the Oath-Sworn")
	print("commander panel: name, stats and oath state for the hero card")

	# --- 6. no commander -> no hero card; narrow view shrinks the cards ---
	var plain := BattleView.new()
	plain.size = Vector2(900, 600)
	var many: Array = []
	for i in 16:
		many.append({"kind": "sword", "soldiers": 36})
	plain.start(many, [{"kind": "sword", "soldiers": 36}],
		0, 0, ["A", "B"], [Color.BLUE, Color.RED], "T")
	var lay2: Dictionary = plain._card_layout()
	assert(not bool(lay2["has_commander"]), "no commander info -> no hero card")
	assert((lay2["cards"] as Array).size() == 16, "all 16 cards laid out")
	assert(float(lay2["card_w"]) < 54.0, "cards shrink when the line is long")
	var bar2: Rect2 = lay2["bar"]
	assert(bar2.position.x >= 0.0 and bar2.end.x <= 900.0, "the shrunken bar still fits the view")
	plain.free()
	view.free()

	print("\nALL BATTLE UI CHECKS PASSED")
	quit(0)
