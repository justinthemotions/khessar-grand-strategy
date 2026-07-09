extends Control

## CK-style UI shell: character panel with procedural portrait on the
## left, the world map in the middle, diplomacy and the chronicle on the
## right, resources and time controls in a top bar. All styling is built
## in code from one theme function — no external art assets.

const SPEEDS: Array[float] = [0.0, 2.0, 12.0]   # months of sim time per real second
const SPEED_LABELS: Array[String] = ["Paused", "Playing", "Fast"]

const INK := Color("e8dcc0")
const GOLD := Color("d9c07a")
const MUTED := Color("a8987f")
const REALM_INK: Array[Color] = [Color("a9c4da"), Color("d9a99d")]

var world: SimWorld
var speed_index: int = 1
var month_accum: float = 0.0
var selected_id: int = -1
var battle_layer: BattleView = null
var battle_announced: bool = false
var battle_panel: PanelContainer
var btn_battle: Button
var btn_autoresolve: Button
var selected_army_id: int = -1
var army_list_box: VBoxContainer
var commander_label: Label
var roster_box: VBoxContainer
var btn_split: Button
var btn_merge: Button
var capacity_label: Label
var enemy_label: Label
var mil_msg: Label
var recruit_buttons: Dictionary = {}
# Module 7: warfare readouts and the defender's last resort
var supply_label: Label
var war_label: Label
var champions_label: Label
var opt_scorch: OptionButton
var btn_scorch: Button
var tabs_container: TabContainer
var opt_commander: OptionButton
var council_opts: Dictionary = {}
var council_faces: Dictionary = {}
var opt_tax: OptionButton
var opt_succession: OptionButton
var btn_enact: Button
var law_status: Label
var opt_plot_target: OptionButton
var btn_plot: Button
var plot_status: Label
var council_msg: Label

# Dynasty tab (Module 2)
var dyn_title: Label
var dyn_renown_label: Label
var dyn_head_face: FaceView
var dyn_head_label: Label
var houses_box: VBoxContainer
var legacy_box: VBoxContainer
var opt_disinherit: OptionButton
var opt_legitimize: OptionButton
var opt_denounce: OptionButton
var opt_cadet: OptionButton
var opt_charter: OptionButton
var opt_bequest: OptionButton
var btn_disinherit: Button
var btn_legitimize: Button
var btn_denounce: Button
var btn_call_war: Button
var btn_cadet: Button
var btn_bequest: Button
var dyn_mythos_label: Label
var dyn_msg: Label

# Event popup (the event framework)
var event_panel: PanelContainer
var event_title: Label
var event_face: FaceView
var event_text: Label
var event_options_box: VBoxContainer

# Realm tab (Module 3)
var gov_label: Label
var demesne_label: Label
var titles_box: VBoxContainer
var vassals_box: VBoxContainer     # Module 4: contracts, blocs, opinions
var factions_box: VBoxContainer    # Module 4: what the crown can see
var opt_title: OptionButton
var opt_grantee: OptionButton
var btn_grant: Button
var btn_revoke: Button
var realm_msg: Label

const SEAT_BLURB := {
	"Marshal": "Raises levy capacity, speeds replenishment",
	"Steward": "Grows the realm's income",
	"Lawspeaker": "Enables laws; skill speeds the debate",
	"Spymaster": "Weaves plots — and wards against them",
}

var date_label: Label
var status_label: Label
var realm_chips: Array = []
var portrait: FaceView
var name_label: Label
var title_label: Label
var info_label: Label
var family_box: VBoxContainer
var map_view: MapView
var log_text: RichTextLabel
var opt_groom: OptionButton
var opt_bride: OptionButton
var msg_label: Label
var btn_war: Button
var btn_peace: Button
var btn_trade: Button
var diplo_label: Label          # Module 5: prestige, truce, CBs, treaty burdens
var btn_fabricate: Button
var opt_ward: OptionButton
var btn_ward: Button
var btn_ransom: Button
var intrigue_label: Label       # Module 6: the web — plot phases, hooks, the lab
var btn_ferret: Button
var opt_scheme_kind: OptionButton
var opt_scheme_target: OptionButton
var btn_scheme: Button
var btn_apothecary: Button
var opt_vector: OptionButton
var btn_mithridate: Button
var hooks_box: VBoxContainer
var intrigue_msg: Label


func _ready() -> void:
	theme = _make_theme()
	world = SimWorld.new()
	_build_ui()
	world.event_logged.connect(_on_event)
	world.event_raised.connect(_on_event_raised)
	world.setup()
	map_view.world = world
	selected_id = world.realms[0].ruler_id
	_refresh()
	# dev aids: `godot --path . -- --screenshot` (campaign UI) or
	# `-- --battle-screenshot` (mid-battle) save a png to user:// and quit
	if OS.get_cmdline_user_args().has("--screenshot"):
		tabs_container.current_tab = 1  # show the Military tab in the capture
		# stage a sample choice event so the popup is in the shot
		var demo_ruler: SimCharacter = world.characters[world.realms[0].ruler_id]
		world.raise_event(0, demo_ruler.id, "The Homage Tour",
			"Godgifu Aurath-Voss of House Aurath-Voss kneels — but does not swear. A gift of 60 gold, she murmurs, would loosen the oath.",
			[{"label": "Pay her price (60 gold)", "effect": func() -> void: pass},
			{"label": "Refuse — the crown begs no one", "effect": func() -> void: pass}])
		_capture_screenshot("user://ui_screenshot.png", 1.2)
	elif OS.get_cmdline_user_args().has("--battle-screenshot"):
		var _err := world.declare_war()
		world.battle_ready = true
		world.pending_battle = [world.armies_of(0)[0].id, world.armies_of(1)[0].id]
		_start_battle()
		battle_layer.speed_scale = 2.5
		_capture_screenshot("user://battle_screenshot.png", 10.0)


func _capture_screenshot(path: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("screenshot saved: ", ProjectSettings.globalize_path(path))
	get_tree().quit()


func _process(delta: float) -> void:
	var months_per_second: float = SPEEDS[speed_index]
	if months_per_second <= 0.0:
		return
	month_accum += delta * months_per_second
	var advanced := false
	while month_accum >= 1.0:
		month_accum -= 1.0
		world.advance_month()
		advanced = true
	if advanced:
		_refresh()


# ---------------------------------------------------------------- theme

func _make_theme() -> Theme:
	var t := Theme.new()

	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Times New Roman"])
	t.default_font = serif
	t.default_font_size = 14

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("241a12")
	panel.border_color = Color("6b5226")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(3)
	panel.set_content_margin_all(10)
	t.set_stylebox("panel", "PanelContainer", panel)

	var btn := StyleBoxFlat.new()
	btn.bg_color = Color("3a2b1c")
	btn.border_color = Color("7a5f33")
	btn.set_border_width_all(1)
	btn.set_corner_radius_all(3)
	btn.content_margin_left = 12.0
	btn.content_margin_right = 12.0
	btn.content_margin_top = 6.0
	btn.content_margin_bottom = 6.0

	var btn_hover: StyleBoxFlat = btn.duplicate()
	btn_hover.bg_color = Color("47351f")
	var btn_pressed: StyleBoxFlat = btn.duplicate()
	btn_pressed.bg_color = Color("2b2015")
	var btn_disabled: StyleBoxFlat = btn.duplicate()
	btn_disabled.bg_color = Color("2a211a")
	btn_disabled.border_color = Color("4a3c26")

	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, btn)
		t.set_stylebox("hover", cls, btn_hover)
		t.set_stylebox("pressed", cls, btn_pressed)
		t.set_stylebox("disabled", cls, btn_disabled)
		t.set_color("font_color", cls, INK)
		t.set_color("font_hover_color", cls, Color("fff3d6"))
		t.set_color("font_disabled_color", cls, Color("6f6455"))

	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)

	t.set_stylebox("panel", "TabContainer", panel)
	var tab_sel: StyleBoxFlat = btn.duplicate()
	tab_sel.bg_color = Color("241a12")
	tab_sel.border_color = Color("6b5226")
	var tab_unsel: StyleBoxFlat = btn.duplicate()
	tab_unsel.bg_color = Color("1a120c")
	tab_unsel.border_color = Color("4a3c26")
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_unsel)
	t.set_stylebox("tab_hovered", "TabContainer", tab_sel)
	t.set_color("font_selected_color", "TabContainer", GOLD)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", INK)
	return t


func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", GOLD)
	return l


func _muted(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", MUTED)
	return l


# ---------------------------------------------------------------- UI construction

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("15100a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	root.add_child(_make_top_bar())

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 8)
	root.add_child(middle)

	middle.add_child(_make_character_panel())

	var map_panel := PanelContainer.new()
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view = MapView.new()
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.province_clicked.connect(_on_province_clicked)
	map_view.army_clicked.connect(_on_army_clicked)
	map_view.map_right_clicked.connect(_on_map_right_clicked)
	map_panel.add_child(map_view)
	middle.add_child(map_panel)

	middle.add_child(_make_right_column())
	_build_event_popup()


func _build_event_popup() -> void:
	## A modal choice window, built last so it draws over everything.
	event_panel = PanelContainer.new()
	event_panel.visible = false
	event_panel.custom_minimum_size = Vector2(420, 0)
	add_child(event_panel)
	event_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	event_panel.add_child(box)

	event_title = Label.new()
	event_title.add_theme_font_size_override("font_size", 17)
	event_title.add_theme_color_override("font_color", GOLD)
	event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(event_title)

	var center := CenterContainer.new()
	event_face = FaceView.new()
	event_face.custom_minimum_size = Vector2(84, 84)
	center.add_child(event_face)
	box.add_child(center)

	event_text = Label.new()
	event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_text.custom_minimum_size = Vector2(390, 0)
	event_text.add_theme_font_size_override("font_size", 13)
	box.add_child(event_text)

	event_options_box = VBoxContainer.new()
	event_options_box.add_theme_constant_override("separation", 6)
	box.add_child(event_options_box)


func _on_event_raised() -> void:
	_show_next_event()


func _show_next_event() -> void:
	if world.pending_events.is_empty():
		event_panel.visible = false
		return
	speed_index = 0  # the realm holds its breath while you decide
	var ev: Dictionary = world.pending_events[0]
	event_title.text = str(ev["title"])
	event_text.text = str(ev["text"])
	var decider: SimCharacter = world.characters.get(int(ev["decider"]))
	if decider != null:
		event_face.set_person(decider.genome, decider.age_years(world.tick), decider.is_female, _portrait_context(decider))
	for child in event_options_box.get_children():
		child.queue_free()
	for i: int in ev["options"].size():
		var b := Button.new()
		b.text = str(ev["options"][i]["label"])
		var ev_id: int = int(ev["id"])
		var idx: int = i
		b.pressed.connect(func() -> void:
			world.resolve_event(ev_id, idx)
			_show_next_event()
			_refresh())
		event_options_box.add_child(b)
	event_panel.visible = true
	_refresh()


func _make_top_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	bar.add_child(box)

	for i in 2:
		var chip := Label.new()
		chip.add_theme_color_override("font_color", REALM_INK[i])
		box.add_child(chip)
		realm_chips.append(chip)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	status_label = Label.new()
	status_label.add_theme_color_override("font_color", GOLD)
	box.add_child(status_label)

	date_label = Label.new()
	date_label.add_theme_font_size_override("font_size", 17)
	box.add_child(date_label)

	for i in SPEEDS.size():
		var b := Button.new()
		b.text = ["Pause", "Play", "Fast"][i]
		b.pressed.connect(func() -> void:
			speed_index = i
			_refresh())
		box.add_child(b)
	return bar


func _make_character_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(290, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var center := CenterContainer.new()
	portrait = FaceView.new()
	portrait.custom_minimum_size = Vector2(150, 150)
	center.add_child(portrait)
	box.add_child(center)

	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", MUTED)
	box.add_child(title_label)

	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 13)
	box.add_child(info_label)

	box.add_child(HSeparator.new())
	box.add_child(_header("Family"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	family_box = VBoxContainer.new()
	family_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	family_box.add_theme_constant_override("separation", 4)
	scroll.add_child(family_box)
	box.add_child(scroll)
	return panel


func _make_right_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(300, 0)
	col.add_theme_constant_override("separation", 8)

	# --- battle call-to-arms (only when armies have met) ---
	battle_panel = PanelContainer.new()
	battle_panel.visible = false
	var battle_box := VBoxContainer.new()
	battle_box.add_theme_constant_override("separation", 6)
	battle_panel.add_child(battle_box)
	btn_battle = Button.new()
	btn_battle.add_theme_color_override("font_color", Color("e0684f"))
	btn_battle.pressed.connect(_start_battle)
	battle_box.add_child(btn_battle)
	btn_autoresolve = Button.new()
	btn_autoresolve.text = "Auto-resolve (let the captains fight it)"
	btn_autoresolve.pressed.connect(_auto_resolve)
	battle_box.add_child(btn_autoresolve)
	col.add_child(battle_panel)

	# --- tabs: Diplomacy | Military | Council ---
	tabs_container = TabContainer.new()
	tabs_container.add_child(_make_diplomacy_tab())
	tabs_container.add_child(_make_military_tab())
	tabs_container.add_child(_make_council_tab())
	tabs_container.add_child(_make_intrigue_tab())
	tabs_container.add_child(_make_dynasty_tab())
	tabs_container.add_child(_make_realm_tab())
	col.add_child(tabs_container)

	# --- chronicle ---
	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_box := VBoxContainer.new()
	log_panel.add_child(log_box)
	log_box.add_child(_header("Chronicle"))
	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = true
	log_text.scroll_following = true
	log_text.selection_enabled = true
	log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_text.add_theme_font_size_override("normal_font_size", 12)
	log_box.add_child(log_text)
	col.add_child(log_panel)
	return col


func _make_diplomacy_tab() -> VBoxContainer:
	var actions := VBoxContainer.new()
	actions.name = "Diplomacy"
	actions.add_theme_constant_override("separation", 6)

	btn_war = Button.new()
	btn_war.text = "Declare War"
	btn_war.pressed.connect(func() -> void:
		msg_label.text = world.declare_war()
		_refresh())
	actions.add_child(btn_war)

	btn_peace = Button.new()
	btn_peace.text = "Negotiate Peace"
	btn_peace.pressed.connect(func() -> void:
		msg_label.text = world.negotiate_peace()
		_refresh())
	actions.add_child(btn_peace)

	btn_trade = Button.new()
	btn_trade.text = "Sign Trade Pact"
	btn_trade.pressed.connect(func() -> void:
		msg_label.text = world.toggle_trade_pact()
		_refresh())
	actions.add_child(btn_trade)

	# --- Module 5: the state of the world between crowns ---
	diplo_label = Label.new()
	diplo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diplo_label.add_theme_font_size_override("font_size", 12)
	diplo_label.add_theme_color_override("font_color", MUTED)
	actions.add_child(diplo_label)

	btn_fabricate = Button.new()
	btn_fabricate.text = "Fabricate a Claim (%d gold)" % int(SimWorld.FABRICATE_COST)
	btn_fabricate.pressed.connect(func() -> void:
		msg_label.text = world.fabricate_claim(0)
		_refresh())
	actions.add_child(btn_fabricate)

	actions.add_child(HSeparator.new())
	actions.add_child(_header("Wards & Hostages"))
	opt_ward = OptionButton.new()
	opt_ward.clip_text = true
	opt_ward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(opt_ward)
	var ward_row := HBoxContainer.new()
	ward_row.add_theme_constant_override("separation", 6)
	btn_ward = Button.new()
	btn_ward.text = "Send as Ward"
	btn_ward.pressed.connect(func() -> void:
		var idx := opt_ward.selected
		if idx >= 0:
			msg_label.text = world.send_ward(int(opt_ward.get_item_metadata(idx)), 1)
		_refresh())
	ward_row.add_child(btn_ward)
	btn_ransom = Button.new()
	btn_ransom.text = "Ransom Home (%d gold)" % int(SimWorld.RANSOM_COST)
	btn_ransom.pressed.connect(func() -> void:
		var idx := opt_ward.selected
		if idx >= 0:
			msg_label.text = world.ransom_ward(int(opt_ward.get_item_metadata(idx)))
		_refresh())
	ward_row.add_child(btn_ransom)
	actions.add_child(ward_row)

	actions.add_child(HSeparator.new())
	actions.add_child(_header("Arrange a Marriage"))

	actions.add_child(_muted("Groom"))
	opt_groom = OptionButton.new()
	opt_groom.clip_text = true
	opt_groom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(opt_groom)

	actions.add_child(_muted("Bride"))
	opt_bride = OptionButton.new()
	opt_bride.clip_text = true
	opt_bride.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(opt_bride)

	var btn_marry := Button.new()
	btn_marry.text = "Marry"
	btn_marry.pressed.connect(_on_marry)
	actions.add_child(btn_marry)

	msg_label = Label.new()
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.custom_minimum_size = Vector2(0, 40)
	msg_label.add_theme_font_size_override("font_size", 12)
	msg_label.add_theme_color_override("font_color", Color("d98a5f"))
	actions.add_child(msg_label)
	return actions


func _make_intrigue_tab() -> ScrollContainer:
	## Module 6: the web — the plot's anatomy, the Spymaster's digging,
	## minor schemes, hooks held, and the hidden lab.
	var scroll := ScrollContainer.new()
	scroll.name = "Intrigue"
	scroll.custom_minimum_size = Vector2(0, 300)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	intrigue_label = Label.new()
	intrigue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intrigue_label.add_theme_font_size_override("font_size", 12)
	box.add_child(intrigue_label)

	btn_ferret = Button.new()
	btn_ferret.text = "Ferret Out Secrets (%d gold)" % int(SimWorld.FERRET_COST)
	btn_ferret.pressed.connect(func() -> void:
		intrigue_msg.text = world.start_ferreting(0)
		_refresh())
	box.add_child(btn_ferret)

	box.add_child(HSeparator.new())
	box.add_child(_header("A Quiet Scheme"))
	opt_scheme_kind = OptionButton.new()
	opt_scheme_kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for kind in SimWorld.MINOR_SCHEME_LABELS:
		opt_scheme_kind.add_item(SimWorld.MINOR_SCHEME_LABELS[kind])
		opt_scheme_kind.set_item_metadata(opt_scheme_kind.item_count - 1, kind)
	box.add_child(opt_scheme_kind)
	opt_scheme_target = OptionButton.new()
	opt_scheme_target.clip_text = true
	opt_scheme_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(opt_scheme_target)
	btn_scheme = Button.new()
	btn_scheme.text = "Begin the Scheme (%d gold)" % int(SimWorld.MINOR_SCHEME_COST)
	btn_scheme.pressed.connect(func() -> void:
		var k := opt_scheme_kind.selected
		var t := opt_scheme_target.selected
		if k >= 0 and t >= 0:
			intrigue_msg.text = world.start_minor_scheme(0,
				str(opt_scheme_kind.get_item_metadata(k)), int(opt_scheme_target.get_item_metadata(t)))
		_refresh())
	box.add_child(btn_scheme)

	box.add_child(HSeparator.new())
	box.add_child(_header("The Apothecary Lab"))
	btn_apothecary = Button.new()
	btn_apothecary.text = "Establish an Apothecary Lab (%d gold)" % int(SimWorld.APOTHECARY_COST)
	btn_apothecary.pressed.connect(func() -> void:
		intrigue_msg.text = world.establish_apothecary(0)
		_refresh())
	box.add_child(btn_apothecary)
	opt_vector = OptionButton.new()
	opt_vector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for v in SimWorld.VECTOR_LABELS:
		opt_vector.add_item("Brew: %s" % SimWorld.VECTOR_LABELS[v])
		opt_vector.set_item_metadata(opt_vector.item_count - 1, v)
	opt_vector.item_selected.connect(func(idx: int) -> void:
		intrigue_msg.text = world.set_plot_vector(0, str(opt_vector.get_item_metadata(idx)))
		call_deferred("_refresh"))
	box.add_child(opt_vector)
	btn_mithridate = Button.new()
	btn_mithridate.pressed.connect(func() -> void:
		intrigue_msg.text = world.toggle_mithridatism(0)
		_refresh())
	box.add_child(btn_mithridate)

	box.add_child(HSeparator.new())
	box.add_child(_header("Hooks Held"))
	hooks_box = VBoxContainer.new()
	hooks_box.add_theme_constant_override("separation", 2)
	box.add_child(hooks_box)

	intrigue_msg = Label.new()
	intrigue_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intrigue_msg.custom_minimum_size = Vector2(0, 32)
	intrigue_msg.add_theme_font_size_override("font_size", 12)
	intrigue_msg.add_theme_color_override("font_color", Color("d98a5f"))
	box.add_child(intrigue_msg)
	return scroll


func _refresh_intrigue() -> void:
	var realm = world.realms[0]
	var lines: Array = []
	if realm.plot_progress >= 0.0:
		var details: Dictionary = world.plot_details.get(0, {})
		var phase := "Phase 1 — mapping the household"
		if realm.plot_progress >= 100.0:
			phase = "Phase 4 — the trap is set" + (", holding for a window" if bool(details.get("waiting", false)) else "")
		elif realm.plot_progress >= 66.0:
			phase = "Phase 3 — the vector: %s" % SimWorld.VECTOR_LABELS[str(details.get("vector", "nightshade"))]
		elif realm.plot_progress >= 33.0:
			phase = "Phase 2 — the asset: %s" % str(details.get("asset_role", "still unbought"))
		var tname := "?"
		if world.characters.has(realm.plot_target_id):
			tname = world.full_name(world.characters[realm.plot_target_id])
		lines.append("Plot against %s: %d%% — %s." % [tname, int(realm.plot_progress), phase])
	if world.ferreting.has(0):
		lines.append("The informants are out — %d months listening." % int(world.ferreting[0]))
	for s in world.minor_schemes:
		if int(s["realm"]) == 0 and world.characters.has(int(s["target"])):
			lines.append("%s against %s — %d%% woven." % [
				SimWorld.MINOR_SCHEME_LABELS[str(s["kind"])],
				world.full_name(world.characters[int(s["target"])]), int(s["progress"])])
	if realm.apothecary:
		var alch_name := "the stills stand untended"
		if world.characters.has(realm.alchemist_id) and world.characters[realm.alchemist_id].alive:
			alch_name = world.full_name(world.characters[realm.alchemist_id])
		lines.append("The lab bubbles beneath the estate — %s. Brewing: %s." % [
			alch_name, SimWorld.VECTOR_LABELS[realm.plot_vector_pref]])
	var ruler_mith := false
	if realm.ruler_id >= 0:
		var r: SimCharacter = world.characters[realm.ruler_id]
		if world.mithridatism.has(r.id):
			lines.append("The ruler takes the morning draughts — %d of %d months." % [
				int(world.mithridatism[r.id]), SimWorld.MITHRIDATIC_MONTHS])
			ruler_mith = true
		elif r.traits.has("Mithridatic"):
			lines.append("No cup can kill the ruler — the mithridatic work is done.")
	if lines.is_empty():
		lines.append("The web is quiet. Nothing moves that the crown has ordered.")
	intrigue_label.text = "\n".join(lines)

	btn_ferret.disabled = world.ferreting.has(0)
	btn_apothecary.disabled = realm.apothecary
	btn_mithridate.text = "Cease the Morning Draughts" if ruler_mith else "Begin Mithridatization (2 gold/month)"
	for v_idx in opt_vector.item_count:
		if str(opt_vector.get_item_metadata(v_idx)) == realm.plot_vector_pref:
			opt_vector.select(v_idx)

	# foreign adults as scheme targets
	var picks: Array = []
	for c in world.characters.values():
		if c.alive and c.realm_id != 0 and c.age_years(world.tick) >= 16 and not world.wards.has(c.id):
			picks.append(c)
	picks.sort_custom(func(a, b) -> bool: return a.birth_tick < b.birth_tick)
	var keep_id := -1
	if opt_scheme_target.selected >= 0 and opt_scheme_target.selected < opt_scheme_target.item_count:
		keep_id = int(opt_scheme_target.get_item_metadata(opt_scheme_target.selected))
	opt_scheme_target.clear()
	for c in picks:
		opt_scheme_target.add_item("%s (%d)" % [world.full_name(c), c.age_years(world.tick)])
		opt_scheme_target.set_item_metadata(opt_scheme_target.item_count - 1, c.id)
		if c.id == keep_id:
			opt_scheme_target.select(opt_scheme_target.item_count - 1)

	# hooks: what the crown holds, and what it can force
	for child in hooks_box.get_children():
		child.queue_free()
	var held: Array = world.hooks_of(0)
	if held.is_empty():
		hooks_box.add_child(_muted("No hooks held. Ferret out secrets, or catch a plotter red-handed."))
	for h in held:
		var t: SimCharacter = world.characters[int(h["target"])]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lab := Label.new()
		lab.add_theme_font_size_override("font_size", 12)
		lab.text = "%s — %s (%s)" % [world.full_name(t),
			SimWorld.SECRET_LABELS.get(str(h["source"]), str(h["source"])), str(h["strength"])]
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		if world.vassal_contracts.has(t.id) and t.realm_id == 0:
			var b := Button.new()
			b.text = "Force harsh tax"
			var tid: int = t.id
			b.pressed.connect(func() -> void:
				intrigue_msg.text = world.hook_force_contract(0, tid, "tax", "harsh")
				_refresh())
			row.add_child(b)
		hooks_box.add_child(row)


func _make_military_tab() -> VBoxContainer:
	var mil := VBoxContainer.new()
	mil.name = "Military"
	mil.add_theme_constant_override("separation", 6)

	capacity_label = Label.new()
	capacity_label.add_theme_font_size_override("font_size", 13)
	mil.add_child(capacity_label)

	army_list_box = VBoxContainer.new()
	army_list_box.add_theme_constant_override("separation", 2)
	mil.add_child(army_list_box)

	commander_label = Label.new()
	commander_label.add_theme_font_size_override("font_size", 12)
	commander_label.add_theme_color_override("font_color", MUTED)
	mil.add_child(commander_label)

	opt_commander = OptionButton.new()
	opt_commander.clip_text = true
	opt_commander.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_commander.item_selected.connect(func(idx: int) -> void:
		mil_msg.text = world.set_commander(selected_army_id, int(opt_commander.get_item_metadata(idx)))
		call_deferred("_refresh"))
	mil.add_child(opt_commander)

	roster_box = VBoxContainer.new()
	roster_box.add_theme_constant_override("separation", 2)
	mil.add_child(roster_box)

	supply_label = Label.new()
	supply_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	supply_label.add_theme_font_size_override("font_size", 12)
	supply_label.add_theme_color_override("font_color", MUTED)
	mil.add_child(supply_label)

	var split_row := HBoxContainer.new()
	split_row.add_theme_constant_override("separation", 6)
	btn_split = Button.new()
	btn_split.text = "Split Army"
	btn_split.pressed.connect(func() -> void:
		mil_msg.text = world.split_army(selected_army_id)
		_refresh())
	split_row.add_child(btn_split)
	btn_merge = Button.new()
	btn_merge.text = "Merge Nearby"
	btn_merge.pressed.connect(func() -> void:
		mil_msg.text = world.merge_army(selected_army_id)
		_refresh())
	split_row.add_child(btn_merge)
	mil.add_child(split_row)

	mil.add_child(HSeparator.new())
	mil.add_child(_header("Muster"))
	# The universal roster first, then every cultural specialty kind —
	# buttons for kinds the realm's provinces cannot culturally muster
	# stay hidden (Roster v1.0, Design Decision A: identity is geography).
	var muster_kinds: Array = ["levy", "archer", "sword", "cav"]
	for kind in SimWorld.UNIT_LABELS:
		if not muster_kinds.has(kind):
			muster_kinds.append(kind)
	for kind in muster_kinds:
		var b := Button.new()
		b.text = "%s — %dg" % [SimWorld.UNIT_LABELS[kind], int(SimWorld.RECRUIT_COST[kind])]
		var k: String = kind
		b.pressed.connect(func() -> void:
			mil_msg.text = world.recruit(0, k)
			_refresh())
		mil.add_child(b)
		recruit_buttons[kind] = b

	mil_msg = Label.new()
	mil_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mil_msg.custom_minimum_size = Vector2(0, 30)
	mil_msg.add_theme_font_size_override("font_size", 12)
	mil_msg.add_theme_color_override("font_color", Color("d98a5f"))
	mil.add_child(mil_msg)

	mil.add_child(HSeparator.new())
	mil.add_child(_header("The War in the Land"))
	war_label = Label.new()
	war_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	war_label.add_theme_font_size_override("font_size", 12)
	mil.add_child(war_label)

	champions_label = Label.new()
	champions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	champions_label.add_theme_font_size_override("font_size", 12)
	champions_label.add_theme_color_override("font_color", MUTED)
	mil.add_child(champions_label)

	var scorch_row := HBoxContainer.new()
	scorch_row.add_theme_constant_override("separation", 6)
	opt_scorch = OptionButton.new()
	opt_scorch.clip_text = true
	opt_scorch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorch_row.add_child(opt_scorch)
	btn_scorch = Button.new()
	btn_scorch.text = "Scorch the Earth"
	btn_scorch.tooltip_text = "Burn your own crops and foul your own wells: the county feeds no invader, and its peasants turn partisan. Defensive wars only — and the land takes five years to forgive you."
	btn_scorch.pressed.connect(func() -> void:
		if opt_scorch.selected >= 0:
			mil_msg.text = world.scorch_earth(0, int(opt_scorch.get_item_metadata(opt_scorch.selected)))
		_refresh())
	scorch_row.add_child(btn_scorch)
	mil.add_child(scorch_row)

	mil.add_child(HSeparator.new())
	enemy_label = Label.new()
	enemy_label.add_theme_font_size_override("font_size", 12)
	enemy_label.add_theme_color_override("font_color", MUTED)
	mil.add_child(enemy_label)
	return mil


func _make_council_tab() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "Council"
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	scroll.add_child(box)

	for seat in SimWorld.COUNCIL_SEATS:
		box.add_child(_header(seat))
		box.add_child(_muted(SEAT_BLURB[seat]))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var face := FaceView.new()
		face.custom_minimum_size = Vector2(34, 34)
		row.add_child(face)
		var opt := OptionButton.new()
		opt.clip_text = true
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var seat_name: String = seat
		opt.item_selected.connect(func(idx: int) -> void:
			council_msg.text = world.appoint(0, seat_name, int(opt.get_item_metadata(idx)))
			call_deferred("_refresh"))
		row.add_child(opt)
		box.add_child(row)
		council_faces[seat] = face
		council_opts[seat] = opt

	box.add_child(HSeparator.new())
	box.add_child(_header("Laws"))
	box.add_child(_muted("Taxation — income vs levy capacity"))
	opt_tax = OptionButton.new()
	opt_tax.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for law in ["light", "moderate", "heavy"]:
		opt_tax.add_item(law.capitalize() + " taxation")
		opt_tax.set_item_metadata(opt_tax.item_count - 1, law)
	box.add_child(opt_tax)
	box.add_child(_muted("Succession"))
	opt_succession = OptionButton.new()
	opt_succession.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_succession.add_item("Male-preference primogeniture")
	opt_succession.set_item_metadata(0, "male")
	opt_succession.add_item("Absolute primogeniture")
	opt_succession.set_item_metadata(1, "absolute")
	box.add_child(opt_succession)
	btn_enact = Button.new()
	btn_enact.text = "Put Before the Council"
	btn_enact.pressed.connect(_on_enact)
	box.add_child(btn_enact)
	law_status = _muted("")
	box.add_child(law_status)

	box.add_child(HSeparator.new())
	box.add_child(_header("Intrigue"))
	box.add_child(_muted("Target"))
	opt_plot_target = OptionButton.new()
	opt_plot_target.clip_text = true
	opt_plot_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(opt_plot_target)
	btn_plot = Button.new()
	btn_plot.pressed.connect(_on_plot)
	box.add_child(btn_plot)
	plot_status = _muted("")
	box.add_child(plot_status)

	council_msg = Label.new()
	council_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	council_msg.custom_minimum_size = Vector2(0, 30)
	council_msg.add_theme_font_size_override("font_size", 12)
	council_msg.add_theme_color_override("font_color", Color("d98a5f"))
	box.add_child(council_msg)
	return scroll


func _make_dynasty_tab() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "Dynasty"
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	scroll.add_child(box)

	dyn_title = _header("")
	box.add_child(dyn_title)
	dyn_renown_label = Label.new()
	dyn_renown_label.add_theme_font_size_override("font_size", 13)
	box.add_child(dyn_renown_label)

	dyn_mythos_label = Label.new()
	dyn_mythos_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dyn_mythos_label.add_theme_font_size_override("font_size", 12)
	dyn_mythos_label.add_theme_color_override("font_color", Color("c98ad9"))
	box.add_child(dyn_mythos_label)

	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	dyn_head_face = FaceView.new()
	dyn_head_face.custom_minimum_size = Vector2(34, 34)
	head_row.add_child(dyn_head_face)
	dyn_head_label = Label.new()
	dyn_head_label.add_theme_font_size_override("font_size", 12)
	dyn_head_label.add_theme_color_override("font_color", MUTED)
	head_row.add_child(dyn_head_label)
	box.add_child(head_row)

	box.add_child(_header("Houses of the Blood"))
	houses_box = VBoxContainer.new()
	houses_box.add_theme_constant_override("separation", 2)
	box.add_child(houses_box)

	box.add_child(HSeparator.new())
	box.add_child(_header("Legacies"))
	box.add_child(_muted("Permanent bloodline perks, bought with Renown"))
	legacy_box = VBoxContainer.new()
	legacy_box.add_theme_constant_override("separation", 4)
	box.add_child(legacy_box)

	box.add_child(HSeparator.new())
	box.add_child(_header("The Head's Word"))
	box.add_child(_muted("Powers only the dynasty head may wield"))

	opt_disinherit = OptionButton.new()
	opt_disinherit.clip_text = true
	opt_disinherit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(opt_disinherit)
	btn_disinherit = Button.new()
	btn_disinherit.text = "Disinherit (%dr)" % int(SimWorld.POWER_COST["disinherit"])
	btn_disinherit.pressed.connect(func() -> void:
		dyn_msg.text = world.dh_disinherit(_player_root(), _selected_id(opt_disinherit))
		_refresh())
	box.add_child(btn_disinherit)

	opt_legitimize = OptionButton.new()
	opt_legitimize.clip_text = true
	opt_legitimize.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(opt_legitimize)
	btn_legitimize = Button.new()
	btn_legitimize.text = "Legitimize Bastard (%dr)" % int(SimWorld.POWER_COST["legitimize"])
	btn_legitimize.pressed.connect(func() -> void:
		dyn_msg.text = world.dh_legitimize(_player_root(), _selected_id(opt_legitimize))
		_refresh())
	box.add_child(btn_legitimize)

	opt_denounce = OptionButton.new()
	opt_denounce.clip_text = true
	opt_denounce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(opt_denounce)
	btn_denounce = Button.new()
	btn_denounce.text = "Denounce (%dr)" % int(SimWorld.POWER_COST["denounce"])
	btn_denounce.pressed.connect(func() -> void:
		dyn_msg.text = world.dh_denounce(_player_root(), _selected_id(opt_denounce))
		_refresh())
	box.add_child(btn_denounce)

	btn_call_war = Button.new()
	btn_call_war.text = "Call Dynasty to War (%dr)" % int(SimWorld.POWER_COST["call_to_war"])
	btn_call_war.pressed.connect(func() -> void:
		dyn_msg.text = world.dh_call_to_war(_player_root())
		_refresh())
	box.add_child(btn_call_war)

	box.add_child(HSeparator.new())
	box.add_child(_header("Wills & Bequests"))
	box.add_child(_muted("Buy a younger child's peace before the crown passes (150g)"))
	opt_bequest = OptionButton.new()
	opt_bequest.clip_text = true
	opt_bequest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(opt_bequest)
	btn_bequest = Button.new()
	btn_bequest.text = "Grant a Bequest"
	btn_bequest.pressed.connect(func() -> void:
		dyn_msg.text = world.grant_bequest(0, _selected_id(opt_bequest))
		_refresh())
	box.add_child(btn_bequest)

	box.add_child(HSeparator.new())
	box.add_child(_header("Found a Cadet Branch"))
	box.add_child(_muted("A married kinsman with children strikes out on his own"))
	opt_cadet = OptionButton.new()
	opt_cadet.clip_text = true
	opt_cadet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(opt_cadet)
	opt_charter = OptionButton.new()
	opt_charter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in ["loyalist", "coequal", "schismatic"]:
		opt_charter.add_item(str(SimWorld.CHARTERS[key]["label"]))
		opt_charter.set_item_metadata(opt_charter.item_count - 1, key)
	opt_charter.select(0)
	opt_charter.item_selected.connect(func(_idx: int) -> void:
		dyn_msg.text = str(SimWorld.CHARTERS[str(opt_charter.get_item_metadata(opt_charter.selected))]["blurb"]))
	box.add_child(opt_charter)
	btn_cadet = Button.new()
	btn_cadet.text = "Found the Branch"
	btn_cadet.pressed.connect(func() -> void:
		var charter := str(opt_charter.get_item_metadata(opt_charter.selected)) if opt_charter.selected >= 0 else "loyalist"
		dyn_msg.text = world.found_cadet_branch(_selected_id(opt_cadet), charter)
		_refresh())
	box.add_child(btn_cadet)

	dyn_msg = Label.new()
	dyn_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dyn_msg.custom_minimum_size = Vector2(0, 30)
	dyn_msg.add_theme_font_size_override("font_size", 12)
	dyn_msg.add_theme_color_override("font_color", Color("d98a5f"))
	box.add_child(dyn_msg)
	return scroll


func _make_realm_tab() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "Realm"
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	scroll.add_child(box)

	box.add_child(_header("The Realm"))
	gov_label = Label.new()
	gov_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gov_label.add_theme_font_size_override("font_size", 12)
	box.add_child(gov_label)
	demesne_label = Label.new()
	demesne_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	demesne_label.add_theme_font_size_override("font_size", 12)
	demesne_label.add_theme_color_override("font_color", MUTED)
	box.add_child(demesne_label)

	box.add_child(HSeparator.new())
	box.add_child(_header("Grant a Title"))
	box.add_child(_muted("Lords run their land well — and remember who raised them"))
	opt_title = OptionButton.new()
	opt_title.clip_text = true
	opt_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(opt_title)
	opt_grantee = OptionButton.new()
	opt_grantee.clip_text = true
	opt_grantee.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(opt_grantee)
	var grant_row := HBoxContainer.new()
	grant_row.add_theme_constant_override("separation", 6)
	btn_grant = Button.new()
	btn_grant.text = "Grant"
	btn_grant.pressed.connect(func() -> void:
		realm_msg.text = _do_grant(_selected_id(opt_grantee))
		_refresh())
	grant_row.add_child(btn_grant)
	btn_revoke = Button.new()
	btn_revoke.text = "Revoke"
	btn_revoke.pressed.connect(func() -> void:
		realm_msg.text = _do_grant(-1)
		_refresh())
	grant_row.add_child(btn_revoke)
	box.add_child(grant_row)

	box.add_child(HSeparator.new())
	box.add_child(_header("Vassals & the Curia"))
	box.add_child(_muted("Contracts set what each lord owes; blocs decide how he votes"))
	vassals_box = VBoxContainer.new()
	vassals_box.add_theme_constant_override("separation", 2)
	box.add_child(vassals_box)

	box.add_child(HSeparator.new())
	box.add_child(_header("Factions"))
	factions_box = VBoxContainer.new()
	factions_box.add_theme_constant_override("separation", 2)
	box.add_child(factions_box)

	box.add_child(HSeparator.new())
	box.add_child(_header("The Title Pyramid"))
	titles_box = VBoxContainer.new()
	titles_box.add_theme_constant_override("separation", 2)
	box.add_child(titles_box)

	realm_msg = Label.new()
	realm_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	realm_msg.custom_minimum_size = Vector2(0, 30)
	realm_msg.add_theme_font_size_override("font_size", 12)
	realm_msg.add_theme_color_override("font_color", Color("d98a5f"))
	box.add_child(realm_msg)
	return scroll


func _do_grant(char_id: int) -> String:
	if opt_title.selected < 0:
		return "Pick a title."
	var meta := str(opt_title.get_item_metadata(opt_title.selected))
	var kind := "duchy" if meta.begins_with("d") else "county"
	return world.grant_title(kind, int(meta.substr(1)), char_id)


func _refresh_realm_tab() -> void:
	var realm = world.realms[0]
	var gov: Dictionary = SimWorld.GOVERNMENTS[realm.government]
	gov_label.text = "%s rule — %s." % [gov["label"], gov["blurb"]]
	var crown_count := 0
	var foreign_count := 0
	for p in world.map.provinces:
		if p.owner != 0:
			continue
		if world.county_holder(p.id) == null:
			crown_count += 1
		if p.de_jure != 0:
			foreign_count += 1
	var admin_cap: int = SimWorld.CROWN_ADMIN_BASE
	if realm.ruler_id >= 0:
		admin_cap += int(world.characters[realm.ruler_id].stewardship / 5.0)
	demesne_label.text = "The crown holds %d counties and administers %d of them well.%s%s" % [
		crown_count, mini(crown_count, admin_cap),
		"\n%d conquered count%s still fly older banners (reduced yield)." % [
			foreign_count, "y" if foreign_count == 1 else "ies"] if foreign_count > 0 else "",
		"\nTyranny %d — the lords remember every injustice." % int(realm.tyranny) if realm.tyranny >= 1.0 else ""]

	_refresh_vassals_and_factions()

	# title picker: our duchies, then our counties
	var prev_title := str(opt_title.get_item_metadata(opt_title.selected)) if opt_title.selected >= 0 else ""
	opt_title.clear()
	if realm.government != "tribal":
		for d in world.map.duchies:
			if d.realm != 0:
				continue
			opt_title.add_item(str(d.name))
			opt_title.set_item_metadata(opt_title.item_count - 1, "d%d" % d.id)
	for p in world.map.provinces:
		if p.owner != 0:
			continue
		opt_title.add_item("County of %s" % p.name)
		opt_title.set_item_metadata(opt_title.item_count - 1, "c%d" % p.id)
	for i in opt_title.item_count:
		if str(opt_title.get_item_metadata(i)) == prev_title:
			opt_title.select(i)
	_fill_char_options(opt_grantee, _adults_of_realm(0, true), "— choose a lord —",
		_selected_id(opt_grantee), ["stewardship", "martial"])

	for child in titles_box.get_children():
		child.queue_free()
	var crown_name := "the Crown"
	if realm.ruler_id >= 0:
		crown_name = world.characters[realm.ruler_id].name
	for d in world.map.duchies:
		if d.realm != 0:
			continue
		var duke = world.duchy_holder(d.id)
		var duke_row := Label.new()
		duke_row.add_theme_font_size_override("font_size", 12)
		duke_row.add_theme_color_override("font_color", GOLD)
		duke_row.text = "%s — %s" % [d.name, world.full_name(duke) if duke != null else crown_name]
		titles_box.add_child(duke_row)
		for pid in d.county_ids:
			var p = world.map.provinces[pid]
			if p.owner != 0:
				titles_box.add_child(_muted("   %s — lost to %s" % [p.name,
					str(world.realms[p.owner].name).trim_prefix("Kingdom of ")]))
				continue
			var lord = world.county_holder(pid)
			var row := Label.new()
			row.add_theme_font_size_override("font_size", 12)
			var mark := " ⚑" if p.de_jure != 0 else ""
			row.text = "   %s — %s%s" % [p.name, world.full_name(lord) if lord != null else crown_name, mark]
			if lord == null:
				row.add_theme_color_override("font_color", MUTED)
			titles_box.add_child(row)
	# counties we conquered from the other realm (they sit in foreign duchies)
	for p in world.map.provinces:
		if p.owner == 0 and p.duchy >= 0 and world.map.duchies[p.duchy].realm != 0:
			var row2 := Label.new()
			row2.add_theme_font_size_override("font_size", 12)
			row2.add_theme_color_override("font_color", Color("d9853a"))
			var lord2 = world.county_holder(p.id)
			row2.text = "%s (conquered) — %s" % [p.name, world.full_name(lord2) if lord2 != null else crown_name]
			titles_box.add_child(row2)


func _refresh_vassals_and_factions() -> void:
	## Module 4: each landed lord's contract, bloc and regard; the
	## factions the crown can actually see.
	for child in vassals_box.get_children():
		child.queue_free()
	var lords: Array = world.landed_vassals(0)
	if lords.is_empty():
		vassals_box.add_child(_muted("No lords hold granted land — the crown rules alone, and votes alone."))
	for c in lords:
		var op: int = world.vassal_opinion(c.id, 0)
		var contract: Dictionary = world.contract_of(c.id)
		var privs: Array = []
		for p in contract["privileges"]:
			privs.append(str(SimWorld.PRIVILEGES[p]["label"]))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		lbl.text = "%s — %d cty · %s · %+d%s" % [world.full_name(c),
			world.counties_of(c.id).size(), world.bloc_of(c), op,
			(" · " + ", ".join(privs)) if not privs.is_empty() else ""]
		lbl.add_theme_color_override("font_color",
			Color("7fae72") if op >= 20 else (Color("c25a4a") if op <= -20 else Color("c9b896")))
		row.add_child(lbl)
		for which in ["tax", "levy"]:
			var b := Button.new()
			b.add_theme_font_size_override("font_size", 11)
			b.text = "%s: %s" % [which, contract[which]]
			var w: String = which
			var cid: int = c.id
			b.pressed.connect(func() -> void:
				var order := ["lenient", "normal", "harsh"]
				var cur: String = world.contract_of(cid)[w]
				var next_rate: String = order[(order.find(cur) + 1) % 3]
				realm_msg.text = world.set_contract_rate(cid, w, next_rate)
				_refresh())
			row.add_child(b)
		var sway := Button.new()
		sway.add_theme_font_size_override("font_size", 11)
		sway.text = "Sway 40g"
		var sid: int = c.id
		sway.pressed.connect(func() -> void:
			realm_msg.text = world.sway_curia(0, sid)
			_refresh())
		row.add_child(sway)
		vassals_box.add_child(row)

	for child in factions_box.get_children():
		child.queue_free()
	var seen: Array = world.visible_factions(0)
	var hidden := 0
	for f in world.factions:
		if int(f["realm"]) == 0 and bool(f["covert"]) and not bool(f["discovered"]):
			hidden += 1
	if seen.is_empty():
		factions_box.add_child(_muted("No conspiracies known to the crown."
			+ (" (A Spymaster might know better.)" if hidden > 0 and world.council_member(0, "Spymaster") == null else "")))
	for f in seen:
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 6)
		var strength: int = int(world.faction_strength(f))
		var cap: int = world.levy_capacity(0)
		var lbl2 := Label.new()
		lbl2.add_theme_font_size_override("font_size", 12)
		lbl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl2.clip_text = true
		lbl2.text = "%s faction — %d men (%d%% of the levy)%s" % [
			SimWorld.FACTION_LABELS[str(f["type"])], strength,
			int(100.0 * strength / maxf(1.0, float(cap))),
			" · covert" if bool(f["covert"]) else " · OVERT"]
		lbl2.add_theme_color_override("font_color", Color("c25a4a"))
		row2.add_child(lbl2)
		if not f["members"].is_empty():
			var bribe := Button.new()
			bribe.add_theme_font_size_override("font_size", 11)
			var first: int = int(f["members"][0])
			bribe.text = "Bribe %s (60g)" % world.characters[first].name
			bribe.pressed.connect(func() -> void:
				realm_msg.text = world.bribe_faction_member(first)
				_refresh())
			row2.add_child(bribe)
		factions_box.add_child(row2)


func _player_root() -> int:
	var ruler_id: int = world.realms[0].ruler_id
	if ruler_id < 0:
		return -1
	return world.root_house_id(world.characters[ruler_id].dynasty_id)


func _refresh_dynasty() -> void:
	var root := _player_root()
	if root < 0:
		return
	var dyn = world.dynasties[root]
	dyn_title.text = "The Dynasty of %s" % str(dyn.name).trim_prefix("House ")
	dyn_renown_label.text = "Renown %d   (+%.1f / month)" % [int(dyn.renown), world.renown_gain(root)]
	var mythos_bits: Array = []
	for tag in dyn.mythos:
		mythos_bits.append("%s — %s" % [tag, str(SimWorld.MYTHOS[tag]["blurb"])])
	for f in world.blood_feuds:
		var other := -1
		if int(f[0]) == root:
			other = int(f[1])
		elif int(f[1]) == root:
			other = int(f[0])
		if other >= 0:
			mythos_bits.append("Blood Feud with %s" % world.dynasties[other].name)
	dyn_mythos_label.text = "\n".join(mythos_bits)
	dyn_mythos_label.visible = not mythos_bits.is_empty()

	var head: SimCharacter = world.dynasty_head(root)
	var ruler_is_head: bool = head != null and head.id == world.realms[0].ruler_id
	if head != null:
		dyn_head_face.set_person(head.genome, head.age_years(world.tick), head.is_female, _portrait_context(head))
		dyn_head_label.text = "Dynasty Head: %s%s" % [world.full_name(head),
			"" if ruler_is_head else "\n(not your ruler — the head's powers are theirs)"]
	else:
		dyn_head_face.set_person({}, 30, false)
		dyn_head_label.text = "The dynasty has no head."

	for child in houses_box.get_children():
		child.queue_free()
	for hid in world.dynasty_house_ids(root):
		var h: SimCharacter = world.house_head(hid)
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 12)
		var charter_note := ""
		if world.dynasties[hid].parent_id >= 0:
			charter_note = " (%s)" % str(SimWorld.CHARTERS[world.dynasties[hid].charter]["label"])
		row.text = "%s%s — %d living%s" % [world.dynasties[hid].name, charter_note,
			world.house_members(hid).size(), ", head " + h.name if h != null else ""]
		houses_box.add_child(row)

	for child in legacy_box.get_children():
		child.queue_free()
	for key in SimWorld.LEGACIES:
		var owned: bool = dyn.legacies.has(key)
		var b := Button.new()
		b.text = "%s — %s" % [key, "held" if owned else "%dr" % int(SimWorld.LEGACIES[key]["cost"])]
		b.add_theme_font_size_override("font_size", 12)
		b.disabled = owned or dyn.renown < float(SimWorld.LEGACIES[key]["cost"])
		var k: String = key
		b.pressed.connect(func() -> void:
			dyn_msg.text = world.buy_legacy(_player_root(), k)
			_refresh())
		legacy_box.add_child(b)
		legacy_box.add_child(_muted(str(SimWorld.LEGACIES[key]["blurb"])))

	# powers: dropdown pools drawn from the whole dynasty tree
	var kin: Array = []
	var bastards: Array = []
	var cadet_ok: Array = []
	for c in world.dynasty_members(root):
		if head != null and c.id == head.id:
			continue
		if c.age_years(world.tick) >= 16:
			if c.is_bastard:
				bastards.append(c)
			elif not c.disinherited:
				kin.append(c)
		if world.can_found_cadet(c) == "":
			cadet_ok.append(c)
	_fill_char_options(opt_disinherit, kin, "— choose kin to cast out —", _selected_id(opt_disinherit))
	_fill_char_options(opt_legitimize, bastards, "— no bastards to raise —" if bastards.is_empty() else "— choose a bastard —", _selected_id(opt_legitimize))
	_fill_char_options(opt_denounce, kin, "— choose kin to denounce —", _selected_id(opt_denounce))
	_fill_char_options(opt_cadet, cadet_ok, "— no kinsman is ready —" if cadet_ok.is_empty() else "— choose a founder —", _selected_id(opt_cadet))

	# wills & bequests: the ruler's adult children who are not the heir
	var bequest_pool: Array = []
	var pruler: SimCharacter = world.characters.get(world.realms[0].ruler_id)
	var pheir: SimCharacter = world.heir_of(0)
	if pruler != null:
		for kid_id in pruler.children_ids:
			var kid: SimCharacter = world.characters[kid_id]
			if kid.alive and kid.age_years(world.tick) >= 16 and not kid.bought_off \
					and (pheir == null or kid.id != pheir.id):
				bequest_pool.append(kid)
	_fill_char_options(opt_bequest, bequest_pool,
		"— no child needs buying off —" if bequest_pool.is_empty() else "— choose a child —",
		_selected_id(opt_bequest))
	btn_bequest.disabled = bequest_pool.is_empty() or world.realms[0].gold < 150.0

	for b: Button in [btn_disinherit, btn_legitimize, btn_denounce, btn_call_war]:
		b.disabled = not ruler_is_head
	btn_legitimize.disabled = btn_legitimize.disabled or bastards.is_empty()
	btn_call_war.disabled = btn_call_war.disabled or not world.at_war
	btn_cadet.disabled = cadet_ok.is_empty()


func _on_enact() -> void:
	var tax_v := str(opt_tax.get_item_metadata(opt_tax.selected)) if opt_tax.selected >= 0 else ""
	var suc_v := str(opt_succession.get_item_metadata(opt_succession.selected)) if opt_succession.selected >= 0 else ""
	var realm = world.realms[0]
	if tax_v != "" and tax_v != realm.tax_law:
		council_msg.text = world.enact_law(0, "tax", tax_v)
	elif suc_v != "" and suc_v != realm.succession_law:
		council_msg.text = world.enact_law(0, "succession", suc_v)
	else:
		council_msg.text = "Choose a law that differs from the current one."
	_refresh()


func _on_plot() -> void:
	var realm = world.realms[0]
	if realm.plot_progress >= 0.0:
		world.abandon_plot(0)
		council_msg.text = ""
	else:
		var target := _selected_id(opt_plot_target)
		if target < 0:
			council_msg.text = "Pick a target."
		else:
			council_msg.text = world.start_plot(0, target)
	_refresh()


# ---------------------------------------------------------------- refresh

func _refresh() -> void:
	date_label.text = "%s · %s" % [world.date_string(), SPEED_LABELS[speed_index]]

	for i in 2:
		var realm = world.realms[i]
		realm_chips[i].text = "%s   %d gold · %d men · str %d" % [
			str(realm.name).trim_prefix("Kingdom of "), int(realm.gold),
			world.army_size(realm.id), world.strength(realm.id)]

	if world.at_war:
		var leader := "even fight"
		if world.war_score > 5.0:
			leader = "favours " + str(world.realms[0].name).trim_prefix("Kingdom of ")
		elif world.war_score < -5.0:
			leader = "favours " + str(world.realms[1].name).trim_prefix("Kingdom of ")
		status_label.text = "AT WAR — %+d (%s)" % [int(world.war_score), leader]
	else:
		var extras := ""
		if world.trade_pact:
			extras += " · trade pact"
		if world.allied():
			extras += " · allied by marriage"
		status_label.text = "At peace" + extras
	if not world.realms[0].interregnum.is_empty():
		status_label.text = "INTERREGNUM — legitimacy %d · " % int(world.realms[0].interregnum["legitimacy"]) \
			+ status_label.text

	_refresh_character()
	_fill_singles(opt_groom, false)
	_fill_singles(opt_bride, true)

	btn_war.disabled = world.at_war
	btn_peace.disabled = not world.at_war or world.battle_ready
	btn_trade.disabled = world.at_war
	btn_trade.text = "Dissolve Trade Pact" if world.trade_pact else "Sign Trade Pact"
	_refresh_diplomacy()

	battle_panel.visible = world.at_war and world.battle_ready and battle_layer == null
	if battle_panel.visible:
		btn_battle.text = "Fight the Battle of %s" % world.battle_site_name()
		if not battle_announced:
			battle_announced = true
			speed_index = 0  # the realm holds its breath
	elif not world.battle_ready:
		battle_announced = false

	_refresh_military()
	_refresh_council()
	_refresh_intrigue()
	_refresh_dynasty()
	_refresh_realm_tab()
	map_view.queue_redraw()


func _refresh_diplomacy() -> void:
	## Module 5: prestige, truce, casus belli, treaty burdens, and the wards list.
	var lines: Array = []
	lines.append("Prestige: %s %+d · %s %+d" % [
		str(world.realms[0].name).trim_prefix("Kingdom of "), int(world.realms[0].prestige),
		str(world.realms[1].name).trim_prefix("Kingdom of "), int(world.realms[1].prestige)])
	if world.tick < world.truce_until:
		lines.append("A truce holds for %d more months — breaking it stains the crown." % (world.truce_until - world.tick))
	var cbs: Array = world.available_cbs(0)
	if cbs.is_empty():
		lines.append("No casus belli — war now would be unjust (−40 prestige, +15 tyranny).")
	else:
		var labels: Array = []
		for cb in cbs:
			labels.append(SimWorld.CB_LABELS[cb])
		lines.append("Casus belli in hand: %s." % ", ".join(labels))
	if not world.fabrication.is_empty():
		lines.append("The Lawspeaker's forgers need %d more months." % int(world.fabrication["months_left"]))
	if not world.reparations.is_empty():
		var to_us: bool = int(world.reparations["to"]) == 0
		lines.append("Reparations %s for %d more months." % [
			"flow to the crown" if to_us else "bleed the treasury", int(world.reparations["months_left"])])
	if int(world.demilitarized_until.get(0, -1)) > world.tick:
		lines.append("Demilitarized by treaty — levies only, %d months remain." % (int(world.demilitarized_until[0]) - world.tick))
	var hostage := world.hostage_heir_of(0)
	if hostage != null:
		lines.append("Your heir %s is a hostage abroad — no war while they are held." % world.full_name(hostage))
	if not world.free_companies.is_empty():
		var loose := 0
		for fc in world.free_companies:
			loose += fc.size()
		lines.append("%d masterless swords roam the roads — free companies pillage until an army answers." % loose)
	for root in world.dispossessed:
		var d: Dictionary = world.dispossessed[root]
		lines.append("The %s plot from exile in %s." % [world.dynasties[root].name,
			str(world.realms[int(d["host"])].name).trim_prefix("Kingdom of ")])
	diplo_label.text = "\n".join(lines)

	btn_fabricate.disabled = not world.fabrication.is_empty() \
		or bool(world.fabricated_claims.get(0, false)) or world.at_war

	# ward candidates: the crown's children young enough to foster, plus anyone already abroad
	var picks: Array = []
	for c in world.characters.values():
		if not c.alive:
			continue
		if world.wards.has(c.id) and int(world.wards[c.id]["home"]) == 0:
			picks.append(c)
		elif c.realm_id == 0 and c.age_years(world.tick) < 16 and c.age_years(world.tick) >= 4:
			picks.append(c)
	picks.sort_custom(func(a, b) -> bool: return a.birth_tick < b.birth_tick)
	var keep_id := -1
	if opt_ward.selected >= 0 and opt_ward.selected < opt_ward.item_count:
		keep_id = int(opt_ward.get_item_metadata(opt_ward.selected))
	opt_ward.clear()
	for c in picks:
		var tag := ""
		if world.wards.has(c.id):
			tag = " — hostage abroad" if bool(world.wards[c.id]["hostage"]) else " — fostered abroad"
		opt_ward.add_item("%s (%d)%s" % [world.full_name(c), c.age_years(world.tick), tag])
		opt_ward.set_item_metadata(opt_ward.item_count - 1, c.id)
		if c.id == keep_id:
			opt_ward.select(opt_ward.item_count - 1)


const STAT_ABBR := {"diplomacy": "D", "martial": "M", "stewardship": "St",
	"intrigue": "I", "learning": "L", "prowess": "P"}


func _fill_char_options(opt: OptionButton, chars: Array, vacant_label: String, want_id: int,
		stat_keys: Array = []) -> void:
	opt.clear()
	if vacant_label != "":
		opt.add_item(vacant_label)
		opt.set_item_metadata(0, -1)
		if want_id < 0:
			opt.select(0)
	for c in chars:
		var label: String = world.full_name(c)
		if stat_keys.is_empty():
			label += " (%d)" % c.age_years(world.tick)
		else:
			var bits: Array = []
			for key in stat_keys:
				bits.append("%s%d" % [STAT_ABBR[key], int(c.get(key))])
			label += " — " + " ".join(bits)
		opt.add_item(label)
		opt.set_item_metadata(opt.item_count - 1, c.id)
		if c.id == want_id:
			opt.select(opt.item_count - 1)


func _adults_of_realm(realm_id: int, exclude_ruler: bool) -> Array:
	var out: Array = []
	for c in world.characters.values():
		if not (c.alive and c.realm_id == realm_id):
			continue
		if c.age_years(world.tick) < 16:
			continue
		if exclude_ruler and c.id == world.realms[realm_id].ruler_id:
			continue
		out.append(c)
	out.sort_custom(func(a, b) -> bool: return a.birth_tick < b.birth_tick)
	return out


func _refresh_council() -> void:
	var realm = world.realms[0]
	for seat in SimWorld.COUNCIL_SEATS:
		var member = world.council_member(0, seat)
		var face: FaceView = council_faces[seat]
		if member != null:
			face.set_person(member.genome, member.age_years(world.tick), member.is_female)
		else:
			face.set_person({}, 30, false)
		_fill_char_options(council_opts[seat], _adults_of_realm(0, true), "— vacant —",
			member.id if member != null else -1, [SimWorld.SEAT_STAT[seat]])

	# laws: dropdowns track the law of the land unless a debate is running
	_select_by_metadata(opt_tax, realm.tax_law)
	_select_by_metadata(opt_succession, realm.succession_law)
	if not realm.pending_law.is_empty():
		law_status.text = "Debating %s law — %d months remain." % [
			str(realm.pending_law["law"]), int(realm.pending_law["months_left"])]
	elif world.council_member(0, "Lawspeaker") == null:
		law_status.text = "No Lawspeaker — no laws can change."
	else:
		law_status.text = "The council awaits a proposal."
	btn_enact.disabled = not realm.pending_law.is_empty() or world.council_member(0, "Lawspeaker") == null

	# intrigue
	var foreigners: Array = _adults_of_realm(1, false)
	if realm.plot_progress >= 0.0:
		btn_plot.text = "Abandon the Plot"
		var t = world.characters.get(realm.plot_target_id)
		var tname := world.full_name(t) if t != null else "?"
		plot_status.text = "Plot against %s — %d%% woven." % [tname, int(realm.plot_progress)]
		_fill_char_options(opt_plot_target, foreigners, "", realm.plot_target_id)
		opt_plot_target.disabled = true
	else:
		btn_plot.text = "Hatch a Plot (100g)"
		plot_status.text = "" if world.council_member(0, "Spymaster") != null else "No Spymaster — no plots."
		var prev := _selected_id(opt_plot_target)
		_fill_char_options(opt_plot_target, foreigners, "", prev)
		opt_plot_target.disabled = false
	btn_plot.disabled = world.council_member(0, "Spymaster") == null and realm.plot_progress < 0.0


func _select_by_metadata(opt: OptionButton, value: String) -> void:
	for i in opt.item_count:
		if str(opt.get_item_metadata(i)) == value:
			opt.select(i)
			return


func _refresh_military() -> void:
	capacity_label.text = "%s — %d / %d men under arms" % [
		str(world.realms[0].name).trim_prefix("Kingdom of "),
		world.army_size(0), world.levy_capacity(0)]

	# validate the selected army; default to the first
	var own: Array = world.armies_of(0)
	if world.army_by_id(selected_army_id) == null or world.army_by_id(selected_army_id).realm_id != 0:
		selected_army_id = own[0].id if not own.is_empty() else -1
	map_view.selected_army_id = selected_army_id

	for child in army_list_box.get_children():
		child.queue_free()
	if own.is_empty():
		army_list_box.add_child(_muted("No armies in the field."))
	for a in own:
		var b := Button.new()
		var marker := "»  " if a.id == selected_army_id else ""
		var cmdr := "no commander"
		if a.commander_id >= 0:
			cmdr = world.full_name(world.characters[a.commander_id])
		b.text = "%sArmy of %d — %s" % [marker, a.size(), cmdr]
		b.add_theme_font_size_override("font_size", 12)
		var aid: int = a.id
		b.pressed.connect(func() -> void:
			selected_army_id = aid
			_refresh())
		army_list_box.add_child(b)

	for child in roster_box.get_children():
		child.queue_free()
	var sel = world.army_by_id(selected_army_id)
	if sel != null:
		var cmdr_text := "Unled"
		if sel.commander_id >= 0:
			var c: SimCharacter = world.characters[sel.commander_id]
			cmdr_text = "Led by %s (Martial %d)" % [world.full_name(c), c.martial]
		commander_label.text = cmdr_text
		# commander picker: adults not already leading a different army
		var busy := {}
		for other in world.armies:
			if other.id != sel.id and other.commander_id >= 0:
				busy[other.commander_id] = true
		var candidates: Array = []
		for c2 in _adults_of_realm(0, false):
			if not busy.has(c2.id):
				candidates.append(c2)
		_fill_char_options(opt_commander, candidates, "", sel.commander_id, ["martial", "prowess"])
		opt_commander.disabled = false
		for reg in sel.regiments:
			var row := Label.new()
			row.add_theme_font_size_override("font_size", 13)
			row.text = "%s — %d / %d" % [SimWorld.UNIT_LABELS[reg["kind"]], int(reg["soldiers"]), int(reg["max"])]
			if int(reg["soldiers"]) < int(reg["max"]) / 2:
				row.add_theme_color_override("font_color", Color("d9853a"))
			roster_box.add_child(row)
		btn_split.disabled = sel.regiments.size() < 2 or own.size() >= 3
		btn_merge.disabled = own.size() < 2
		# Module 7: what the ground under the army can actually feed
		var rep: Dictionary = world.army_supply_report(sel)
		var p = rep["province"]
		var supply_text := "Encamped at %s — supply for %d men" % [str(p.name), int(rep["limit"])]
		if int(rep["over"]) > 0:
			supply_text += "  ·  %d TOO MANY — the host is starving" % int(rep["over"])
		if sel.train_active:
			supply_text += "\nBaggage train on the road" + (
				"  ·  SEVERED %d months — no food, no reinforcements" % sel.severed_months
				if sel.severed_months > 0 else " — guard it, or the host starves")
		supply_label.text = supply_text
		supply_label.add_theme_color_override("font_color",
			Color("d24a35") if (int(rep["over"]) > 0 or sel.severed_months > 0) else MUTED)
	else:
		commander_label.text = ""
		opt_commander.clear()
		opt_commander.disabled = true
		btn_split.disabled = true
		btn_merge.disabled = true
		supply_label.text = ""

	for kind in recruit_buttons:
		var b2: Button = recruit_buttons[kind]
		var cost: float = SimWorld.RECRUIT_COST[kind]
		var too_big: bool = world.army_size(0) + int(SimWorld.RECRUIT_SIZE[kind]) > world.levy_capacity(0)
		b2.visible = world.recruit_gate(0, str(kind)) == ""
		b2.disabled = world.realms[0].gold < cost or too_big

	# Module 7: sieges, occupations, and the fires we set ourselves
	var war_lines: Array = []
	for pid in world.sieges:
		var s: Dictionary = world.sieges[pid]
		war_lines.append("%s besieges %s — %d%%" % [
			str(world.realms[int(s["attacker"])].name).trim_prefix("Kingdom of "),
			world.map.provinces[pid].name,
			int(100.0 * float(s["progress"]) / maxf(float(s["threshold"]), 1.0))])
	for pid in world.occupied:
		war_lines.append("%s stands occupied by %s" % [world.map.provinces[pid].name,
			str(world.realms[int(world.occupied[pid])].name).trim_prefix("Kingdom of ")])
	for pid in world.scorched:
		war_lines.append("%s lies scorched — %d months until the fields bear" % [
			world.map.provinces[pid].name, maxi(0, int(world.scorched[pid]) - world.tick)])
	if world.is_winter():
		war_lines.append("It is WINTER — armies on foreign soil starve at twice the rate.")
	war_label.text = "\n".join(war_lines) if not war_lines.is_empty() else "No sieges, no occupations, no burned fields."

	var champs: Array = world.champions_of(0)
	if champs.is_empty():
		champions_label.text = "No champions ride with the host."
	else:
		var names: Array = []
		for c3: SimCharacter in champs:
			names.append("%s (Prowess %d)" % [world.full_name(c3), c3.prowess])
		champions_label.text = "Champions with the main host: " + ", ".join(names)

	# the scorch picker: your own rightful counties, not yet burned
	opt_scorch.clear()
	var can_scorch: bool = world.at_war and world.war_aggressor != 0
	for p2 in world.map.provinces:
		if p2.owner == 0 and p2.de_jure == 0 and int(world.scorched.get(p2.id, -1)) <= world.tick:
			opt_scorch.add_item(str(p2.name))
			opt_scorch.set_item_metadata(opt_scorch.item_count - 1, p2.id)
	btn_scorch.disabled = not can_scorch or opt_scorch.item_count == 0
	opt_scorch.disabled = btn_scorch.disabled

	enemy_label.text = "Enemy muster: ~%d men in %d armies (strength %d)" % [
		int(round(world.army_size(1) / 10.0) * 10), world.armies_of(1).size(), world.strength(1)]


func _refresh_character() -> void:
	var c: SimCharacter = null
	if world.characters.has(selected_id):
		c = world.characters[selected_id]
	if c == null or not c.alive:
		var fallback: int = world.realms[0].ruler_id
		if fallback < 0:
			fallback = world.realms[1].ruler_id
		if fallback < 0:
			return
		selected_id = fallback
		c = world.characters[selected_id]

	portrait.set_person(c.genome, c.age_years(world.tick), c.is_female, _portrait_context(c))
	name_label.text = world.full_name(c)

	var title := ""
	for realm in world.realms:
		if realm.ruler_id == c.id:
			title = ("Queen of %s" if c.is_female else "King of %s") % str(realm.name).trim_prefix("Kingdom of ")
	if title == "":
		title = "of %s" % str(world.dynasties[c.dynasty_id].name)
	title_label.text = title
	var traits_line := "No notable traits"
	if not c.traits.is_empty():
		traits_line = ", ".join(c.traits)
	if c.is_bastard:
		traits_line += " · Bastard"
	if c.disinherited:
		traits_line += " · Disinherited"
	if c.denounced:
		traits_line += " · Denounced"
	var stress_word := "Composed"
	if c.stress >= 200.0:
		stress_word = "Fraying"
	elif c.stress >= 100.0:
		stress_word = "Strained"
	elif c.stress >= 50.0:
		stress_word = "Uneasy"
	# race is shown when it isn't the realm's default blood — a Half-Orc
	# heir at a Human court is worth a word (Cross-Cultural Marriage v1.0)
	var blood := ""
	if c.race != ("human" if c.realm_id == 0 else "orc"):
		blood = " · %s" % CultureData.race_label(c.race)
	var lines := "Age %d · %s%s\nDip %d · Mar %d · Stw %d\nInt %d · Lrn %d · Prw %d\n%s\nStress %d (%s)" % [
		c.age_years(world.tick), str(world.realms[c.realm_id].name).trim_prefix("Kingdom of "),
		blood, c.diplomacy, c.martial, c.stewardship, c.intrigue, c.learning, c.prowess,
		traits_line, int(c.stress), stress_word]
	var liege_id: int = world.realms[c.realm_id].ruler_id
	if liege_id >= 0 and liege_id != c.id:
		lines += "\nOpinion of liege: %+d" % world.opinion_of(c.id, liege_id)
	info_label.text = lines

	for child in family_box.get_children():
		child.queue_free()
	if c.spouse_id >= 0:
		_add_family_row("Spouse", world.characters[c.spouse_id])
	for realm in world.realms:
		if realm.ruler_id == c.id:
			var heir := world.heir_of(realm.id)
			if heir != null:
				_add_family_row("Heir", heir)
	for kid_id in c.children_ids:
		var kid: SimCharacter = world.characters[kid_id]
		if kid.alive:
			_add_family_row("Child", kid)
	if c.father_id >= 0 and world.characters[c.father_id].alive:
		_add_family_row("Father", world.characters[c.father_id])
	if c.mother_id >= 0 and world.characters[c.mother_id].alive:
		_add_family_row("Mother", world.characters[c.mother_id])


func _add_family_row(role: String, person: SimCharacter) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var face := FaceView.new()
	face.custom_minimum_size = Vector2(44, 44)
	face.set_person(person.genome, person.age_years(world.tick), person.is_female, _portrait_context(person))
	face.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var pid := person.id
	face.pressed.connect(func() -> void:
		selected_id = pid
		_refresh())
	row.add_child(face)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	var nm := Label.new()
	nm.text = world.full_name(person)
	nm.add_theme_font_size_override("font_size", 13)
	text.add_child(nm)
	text.add_child(_muted("%s · age %d" % [role, person.age_years(world.tick)]))
	row.add_child(text)

	family_box.add_child(row)


func _portrait_context(person: SimCharacter) -> Dictionary:
	var ruler := false
	for realm in world.realms:
		if realm.ruler_id == person.id:
			ruler = true
			break
	return {
		"id": person.id,
		"traits": person.traits,
		"realm_id": person.realm_id,
		"realm": world.realms[person.realm_id].name if person.realm_id >= 0 else "",
		"dynasty": world.dynasties[person.dynasty_id].name if person.dynasty_id >= 0 else "",
		"ruler": ruler,
	}


func _fill_singles(opt: OptionButton, female: bool) -> void:
	var prev_id := _selected_id(opt)
	opt.clear()
	for c in world.eligible_singles(female):
		opt.add_item("%s (%d) — %s" % [world.full_name(c), c.age_years(world.tick),
			str(world.realms[c.realm_id].name).trim_prefix("Kingdom of ")])
		opt.set_item_metadata(opt.item_count - 1, c.id)
		if c.id == prev_id:
			opt.select(opt.item_count - 1)


func _selected_id(opt: OptionButton) -> int:
	if opt.selected < 0:
		return -1
	return int(opt.get_item_metadata(opt.selected))


# ---------------------------------------------------------------- handlers

func _on_marry() -> void:
	var groom := _selected_id(opt_groom)
	var bride := _selected_id(opt_bride)
	if groom < 0 or bride < 0:
		msg_label.text = "Pick a groom and a bride."
		return
	msg_label.text = world.marry(groom, bride)
	_refresh()


func _on_province_clicked(province_id: int) -> void:
	var owner: int = world.map.provinces[province_id].owner
	var ruler_id: int = world.realms[owner].ruler_id
	if ruler_id >= 0:
		selected_id = ruler_id
		_refresh()


func _on_army_clicked(army_id: int) -> void:
	var a = world.army_by_id(army_id)
	if a == null:
		return
	if a.realm_id == 0:
		selected_army_id = army_id
	if a.commander_id >= 0:
		selected_id = a.commander_id
	_refresh()


func _on_map_right_clicked(pos: Vector2) -> void:
	var a = world.army_by_id(selected_army_id)
	if a != null and a.realm_id == 0:
		world.set_army_target(selected_army_id, pos)
		_refresh()


func _on_event(text: String) -> void:
	log_text.append_text(text + "\n")


# ---------------------------------------------------------------- battle

func _pending_armies() -> Array:
	if world.pending_battle.size() != 2:
		return [null, null]
	return [world.army_by_id(world.pending_battle[0]), world.army_by_id(world.pending_battle[1])]


func _army_lead(a) -> int:
	## Commander martial, plus what the campaign lends or starves away:
	## champions riding with the host, hunger from a severed train, and
	## the defender's ambush edge on chosen ground (Module 7).
	var lead := 0
	if a != null and a.commander_id >= 0:
		lead = world.characters[a.commander_id].martial
	return lead + world.battle_lead_mod(a)


func _cmdr_info(a) -> Dictionary:
	## What the commander brings to the map table — the Battle Grid's
	## tactical orders are gated on who he actually is (Module 7).
	if a == null or a.commander_id < 0:
		return {}
	var c: SimCharacter = world.characters[a.commander_id]
	return {"martial": c.martial, "intrigue": c.intrigue, "prowess": c.prowess,
		"traits": c.traits.duplicate()}


func _army_traits(a) -> Array:
	## The commander's traits ride onto the field with him.
	if a != null and a.commander_id >= 0:
		return world.characters[a.commander_id].traits
	return []


func _start_battle() -> void:
	if battle_layer != null:
		return
	var pair := _pending_armies()
	if pair[0] == null or pair[1] == null:
		return
	speed_index = 0
	battle_layer = BattleView.new()
	battle_layer.start(pair[0].regiments, pair[1].regiments, _army_lead(pair[0]), _army_lead(pair[1]),
		[str(world.realms[0].name).trim_prefix("Kingdom of "),
		str(world.realms[1].name).trim_prefix("Kingdom of ")],
		[Color("3f5f83"), Color("8c4a3f")],
		"The Battle of %s" % world.battle_site_name(),
		_army_traits(pair[0]), _army_traits(pair[1]), world.battle_site_terrain())
	battle_layer.sim.set_commander_info(0, _cmdr_info(pair[0]))
	battle_layer.sim.set_commander_info(1, _cmdr_info(pair[1]))
	battle_layer.finished.connect(_on_battle_finished)
	battle_layer.sim.event.connect(_on_event)
	add_child(battle_layer)
	_refresh()


func _auto_resolve() -> void:
	## The battle happens without you: both sides fight under AI captains.
	var pair := _pending_armies()
	if pair[0] == null or pair[1] == null:
		return
	var sim := BattleSim.new()
	sim.setup_from_rosters(pair[0].regiments, pair[1].regiments, _army_lead(pair[0]), _army_lead(pair[1]),
		[str(world.realms[0].name).trim_prefix("Kingdom of "),
		str(world.realms[1].name).trim_prefix("Kingdom of ")],
		_army_traits(pair[0]), _army_traits(pair[1]), world.battle_site_terrain())
	sim.set_commander_info(0, _cmdr_info(pair[0]))
	sim.set_commander_info(1, _cmdr_info(pair[1]))
	sim.run_headless()
	_apply_battle_sim_results(sim)
	_refresh()


func _on_battle_finished(winner_side: int, _loser_loss_fraction: float) -> void:
	_apply_battle_sim_results(battle_layer.sim)
	battle_layer.queue_free()
	battle_layer = null
	battle_announced = false
	_refresh()


func _apply_battle_sim_results(sim: BattleSim) -> void:
	## Casualties persist: survivors are written back to the two armies
	## that fought, then the outcome swings the war score.
	var winner: int = sim.winner
	var army_ids: Array = world.pending_battle.duplicate()
	for side in 2:
		if side >= army_ids.size():
			break
		var results: Array = []
		for r: BattleSim.Regiment in sim.regiments:
			if r.side == side:
				results.append({"index": r.roster_index, "soldiers": r.soldiers, "routed": r.routed})
		world.apply_battle_casualties(army_ids[side], results, winner >= 0 and winner != side)
	var loss := 0.0
	if winner >= 0:
		loss = 1.0 - sim.survivors_fraction(1 - winner)
	world.apply_battle_result(winner, loss, sim.commander_charged)
