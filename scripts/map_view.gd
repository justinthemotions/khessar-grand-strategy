class_name MapView
extends Control

## Renders the WorldMap and handles hover/click. Clicking a province
## emits province_clicked so the UI can select that realm's ruler.

signal province_clicked(province_id: int)
signal army_clicked(army_id: int)
signal map_right_clicked(pos: Vector2)

const SEA := Color("17222e")
const BORDER := Color(0.06, 0.05, 0.04, 0.85)
# one fill per map realm, indexed by realm id (see KhessarMapData.REALMS)
const REALM_FILL: Array[Color] = [
	Color("4a6d8c"),  # 0 Magistocracy of Vael — steel blue
	Color("8c4a3f"),  # 1 Karn-Vol Clan — rust red
	Color("3f7a8c"),  # 2 Pellar — cold teal
	Color("a3743a"),  # 3 Carath — amber
	Color("6e7a3f"),  # 4 Dunmore — olive
	Color("4a8c6b"),  # 5 Halven — sea green
	Color("5d6b7a"),  # 6 Free City-States Compact — slate
	Color("7a3a5d"),  # 7 Grath-Hun Clan — plum
	Color("8c6b4a"),  # 8 Kharak-Dum — bronze
	Color("3f8c4f"),  # 9 House Veldarin — bright green
	Color("2e6e46"),  # 10 House Thaladris — deep green
	Color("b08c3f"),  # 11 Saren-Vesh Trade Council — gold
]
const REALM_INK: Array[Color] = [
	Color("bdd4e6"), Color("e6bdb2"), Color("b8dde6"), Color("e6cfa8"),
	Color("d4dcae"), Color("b5e0c9"), Color("c3ccd6"), Color("dcb3c8"),
	Color("e0cbb0"), Color("b8e0be"), Color("a8ccb4"), Color("e6d6a3"),
]
# uncontrolled land is greyed out by what killed it
const UNCLAIMED_FILL := {
	"ruined": Color("4a4642"),      # the Aurath Sovereignty
	"ashfields": Color("3b3542"),   # Caeris's blight
	"mountain": Color("514b45"),    # sealed holds
}
const SPECIAL_LABELS := {
	"iron_library": "The Iron Library",
	"durn_caeris_seat": "Seat of Caeris the Unfinished",
	"marn_crossing": "The Marn's Crossing border post",
	"ashford_checkpoint": "The Ashford checkpoint",
	"veilkeep": "Seat of House Halvenard-Veil",
	"voss_hold": "Seat of House Aurath-Voss",
	"sealed_hold": "A sealed Dwarven hold",
	"guildhall": "The Civic Council guildhall",
	"iliana_home": "Childhood home of Iliana Vesh",
}

var world: SimWorld
var hover_id: int = -1
var selected_army_id: int = -1
var mouse_pos := Vector2.ZERO


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover_id = -1
		queue_redraw()


func _map_rect() -> Rect2:
	var pad := 10.0
	return Rect2(pad, pad, size.x - pad * 2.0, size.y - pad * 2.0)


func _to_screen(p: Vector2) -> Vector2:
	var r := _map_rect()
	return r.position + p * r.size


func _to_map(p: Vector2) -> Vector2:
	var r := _map_rect()
	return (p - r.position) / r.size


func _gui_input(event: InputEvent) -> void:
	if world == null:
		return
	if event is InputEventMouseMotion:
		mouse_pos = event.position
		var m := _to_map(event.position)
		var new_hover := -1
		for p in world.map.provinces:
			if Geometry2D.is_point_in_polygon(m, p.polygon):
				new_hover = p.id
				break
		hover_id = new_hover
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# armies sit on top of provinces, so they get first claim
			for a in world.armies:
				if _to_screen(a.pos).distance_to(event.position) < 15.0:
					army_clicked.emit(a.id)
					return
			if hover_id >= 0:
				province_clicked.emit(hover_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			map_right_clicked.emit(_to_map(event.position))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SEA)
	if world == null:
		return
	var font := get_theme_default_font()

	for p in world.map.provinces:
		var pts := PackedVector2Array()
		for v in p.polygon:
			pts.append(_to_screen(v))
		var shade := 0.88 + fmod(float(p.id) * 0.618, 1.0) * 0.22
		var col: Color
		if p.owner >= 0:
			col = REALM_FILL[p.owner] * shade
		else:
			col = UNCLAIMED_FILL.get(p.terrain, Color("4a4642")) * shade
		col.a = 1.0
		if int(world.scorched.get(p.id, -1)) > world.tick:
			col = col.lerp(Color("2a1c12"), 0.55)  # burned fields under ash (Module 7)
		elif int(world.occupied.get(p.id, -1)) >= 0:
			col = col.lerp(REALM_FILL[int(world.occupied[p.id])], 0.45)  # the occupier's shadow
		draw_colored_polygon(pts, col)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, BORDER, 1.6, true)

	# hover highlight
	if hover_id >= 0:
		var hp = world.map.provinces[hover_id]
		var pts := PackedVector2Array()
		for v in hp.polygon:
			pts.append(_to_screen(v))
		draw_colored_polygon(pts, Color(1, 1, 1, 0.08))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color("d9c07a"), 2.4, true)

	# realm names across their territory — the great powers loud, the small quiet
	for r in world.map.realms:
		var count := 0
		var cpos := Vector2.ZERO
		for p in world.map.provinces:
			if p.owner == r.id:
				cpos += p.center
				count += 1
		if count == 0:
			continue
		var spos := _to_screen(cpos / float(count))
		var label := str(r.name).to_upper()
		var fsize := 18 if count >= 6 else 11
		draw_string(font, spos + Vector2(-110, 5), label, HORIZONTAL_ALIGNMENT_CENTER, 220, fsize, Color(0, 0, 0, 0.5))
		draw_string(font, spos + Vector2(-110, 3), label, HORIZONTAL_ALIGNMENT_CENTER, 220, fsize, REALM_INK[r.id])
		# who actually rules here (Faction Cast v1.0): the live crowns and
		# the canonical cast alike — the map reads as people, not territory
		var ruler_line := ""
		if r.id < world.realms.size():
			var rid: int = world.realms[r.id].ruler_id
			if rid >= 0:
				var rc = world.characters[rid]
				ruler_line = "%s %s" % [world.live_ruler_title(r.id, rc), world.full_name(rc)]
		elif world.cast_rulers.has(r.id):
			var cr = world.cast_ruler_of(r.id)
			if cr != null and cr.alive:
				ruler_line = "%s %s" % [str(world.cast_rulers[r.id]["title"]), world.full_name(cr)]
		if ruler_line != "":
			draw_string(font, spos + Vector2(-110, fsize + 4), ruler_line,
				HORIZONTAL_ALIGNMENT_CENTER, 220, 10, Color(REALM_INK[r.id], 0.85))
	# the dead lands are named too
	_draw_region_label(font, "THE ASHFIELDS", "ashfields")
	_draw_region_label(font, "AURATH RUINS", "aurath")

	# standing armies — always on the map, in war and peace
	var font2 := get_theme_default_font()
	for a in world.armies:
		var apos := _to_screen(a.pos)
		if a.id == selected_army_id:
			draw_arc(apos + Vector2(0, -2), 14.0, 0.0, TAU, 24, Color("d9c07a"), 2.0)
		if a.has_target:
			draw_line(apos, _to_screen(a.target), Color(1, 1, 1, 0.18), 1.5)
		# banner: pole, pennant in realm colour, base disc
		draw_line(apos + Vector2(0, 6), apos + Vector2(0, -16), Color("2a1f14"), 2.0)
		var flag := Rect2(apos + Vector2(1, -16), Vector2(13, 8))
		draw_rect(flag, REALM_FILL[a.realm_id].lightened(0.15))
		draw_rect(flag, Color("1c1410"), false, 1.0)
		draw_line(flag.position + Vector2(3, 6), flag.position + Vector2(10, 2), Color("d9c07a"), 1.5)
		draw_circle(apos + Vector2(0, 6), 3.5, Color("2a1f14"))
		draw_circle(apos + Vector2(0, 6), 2.2, REALM_INK[a.realm_id])
		draw_string(font2, apos + Vector2(-30, 20), str(a.size()), HORIZONTAL_ALIGNMENT_CENTER, 60, 11, REALM_INK[a.realm_id])

	# baggage trains (Module 7) — the wagons trailing an army on foreign
	# soil: the campaign's softest target, drawn so it can be hunted
	for a in world.armies:
		if not a.train_active:
			continue
		var tpos := _to_screen(a.train_pos)
		var wagon := Color("8a6a3c") if a.severed_months == 0 else Color("b3402a")
		draw_line(_to_screen(a.pos), tpos, Color(wagon, 0.4), 1.5)
		draw_rect(Rect2(tpos + Vector2(-4, -3), Vector2(8, 5)), wagon)
		draw_rect(Rect2(tpos + Vector2(-4, -3), Vector2(8, 5)), Color("1c1410"), false, 1.0)
		draw_circle(tpos + Vector2(-2.5, 3), 1.6, Color("2a1f14"))
		draw_circle(tpos + Vector2(2.5, 3), 1.6, Color("2a1f14"))

	# siege lines (Module 7) — a broken ring around the county seat
	for pid in world.sieges:
		var sp := _to_screen(world.map.provinces[pid].center)
		var s: Dictionary = world.sieges[pid]
		var frac: float = clampf(float(s["progress"]) / maxf(float(s["threshold"]), 1.0), 0.0, 1.0)
		draw_arc(sp, 11.0, 0.0, TAU, 24, Color("1c1410"), 3.0)
		draw_arc(sp, 11.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 24, REALM_INK[int(s["attacker"])], 3.0)

	# free companies — masterless swords under a black rag (Module 5)
	for fc in world.free_companies:
		var fpos := _to_screen(fc.pos)
		draw_line(fpos + Vector2(0, 6), fpos + Vector2(0, -16), Color("2a1f14"), 2.0)
		var rag := Rect2(fpos + Vector2(1, -16), Vector2(13, 8))
		draw_rect(rag, Color("1c1410"))
		draw_rect(rag, Color("b3402a"), false, 1.0)
		draw_circle(fpos + Vector2(0, 6), 3.5, Color("2a1f14"))
		draw_circle(fpos + Vector2(0, 6), 2.2, Color("b3402a"))
		draw_string(font2, fpos + Vector2(-30, 20), str(fc.size()), HORIZONTAL_ALIGNMENT_CENTER, 60, 11, Color("b3402a"))

	# crossed swords where a battle waits to be fought
	if world.battle_ready and world.pending_battle.size() == 2:
		var pa = world.army_by_id(world.pending_battle[0])
		var pb = world.army_by_id(world.pending_battle[1])
		if pa != null and pb != null:
			var c := _to_screen((pa.pos + pb.pos) * 0.5) + Vector2(0, -22)
			draw_line(c + Vector2(-9, -9), c + Vector2(9, 9), Color("2a0d08"), 5.0)
			draw_line(c + Vector2(-9, 9), c + Vector2(9, -9), Color("2a0d08"), 5.0)
			draw_line(c + Vector2(-9, -9), c + Vector2(9, 9), Color("d24a35"), 2.5)
			draw_line(c + Vector2(-9, 9), c + Vector2(9, -9), Color("d24a35"), 2.5)

	# hover tooltip
	if hover_id >= 0:
		var hp = world.map.provinces[hover_id]
		var lines: Array[String] = [
			str(hp.name),
			world.map.realm_display_name(hp.owner),
			"Tax %.1f · Levy %d · %s" % [hp.tax, hp.levy, str(hp.terrain).capitalize()],
		]
		if hp.duchy >= 0:
			lines.insert(1, str(world.map.duchies[hp.duchy].name))
		if hp.special_feature != "":
			lines.append(str(SPECIAL_LABELS.get(hp.special_feature, str(hp.special_feature).capitalize())))
		var lord = world.county_holder(hp.id)
		if lord != null:
			lines.append("Lord: %s" % world.full_name(lord))
		if hp.silence_touched:
			lines.append("The Silence lies heavy here")
		if hp.ruined:
			lines.append("Dead land of the old Sovereignty")
		if hp.de_jure != hp.owner:
			lines.append("De jure %s — the people" % world.map.realm_display_name(hp.de_jure))
			lines.append("remember older banners")
		var box_w := 210.0
		var box_h := 12.0 + lines.size() * 18.0
		var pos := mouse_pos + Vector2(16, 12)
		pos.x = minf(pos.x, size.x - box_w - 6.0)
		pos.y = minf(pos.y, size.y - box_h - 6.0)
		draw_rect(Rect2(pos, Vector2(box_w, box_h)), Color("241a12ee"))
		draw_rect(Rect2(pos, Vector2(box_w, box_h)), Color("6b5226"), false, 1.0)
		for i in lines.size():
			var ink := Color("d9c07a") if i == 0 else Color("e8dcc0")
			draw_string(font, pos + Vector2(10, 22 + i * 18), lines[i], HORIZONTAL_ALIGNMENT_LEFT, box_w - 20.0, 13, ink)


func _draw_region_label(font: Font, text: String, region: String) -> void:
	var count := 0
	var cpos := Vector2.ZERO
	for p in world.map.provinces:
		if p.cultural_region == region:
			cpos += p.center
			count += 1
	if count == 0:
		return
	var spos := _to_screen(cpos / float(count))
	draw_string(font, spos + Vector2(-90, 5), text, HORIZONTAL_ALIGNMENT_CENTER, 180, 13, Color(0, 0, 0, 0.5))
	draw_string(font, spos + Vector2(-90, 3), text, HORIZONTAL_ALIGNMENT_CENTER, 180, 13, Color("8f8a80"))
