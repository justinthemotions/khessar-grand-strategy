class_name WorldMap
extends RefCounted

## The continent of Khessar, hand-traced from the Khessar_mapv2
## illustration. All content lives in data/khessar_map_data.gd — bands of
## province cells between hand-drawn boundary polylines, realm records,
## duchy groupings, and the mountain/forest adjacency blocklist. This
## file only assembles runtime structures from those tables.
## Coordinates are normalized 0..1 — MapView scales them to the screen.
## Generation stays seeded (777) and deterministic, and uses its own RNG
## so the map never disturbs the character-history random sequence; the
## RNG touches only generated county names and cosmetic border jitter.

const ADJ_EPS := 0.015   # minimum x-overlap before stacked cells count as adjacent


class Province:
	## The County tier of the title pyramid (Module 3). `owner` is the
	## de facto ruler today; `de_jure` is who the land *rightfully*
	## belongs to — and the two drift together only over generations.
	var id: int
	var name: String
	var owner: int                      # realm id — de facto (-1 = uncontrolled)
	var de_jure: int                    # realm id — the historical legal right
	var held_since: int = 0             # world tick the current owner took it
	var duchy: int = -1                 # index into duchies
	var polygon: PackedVector2Array     # normalized coords
	var center: Vector2
	var tax: float
	var levy: int
	var neighbors: Array[int] = []
	# Khessar map pass — additive fields (appended; the order above is preserved)
	var terrain: String = "plains"      # plains|hills|forest|mountain|coast|wetland|ashfields|ruined|river_valley
	var coastal: bool = false           # touches the sea on the illustration
	var cultural_region: String = ""    # name pool + later cultural mechanics
	var silence_touched: bool = false   # the Ashfields — inhabited, but under the Silence
	var ruined: bool = false            # the Aurath Sovereignty ruins
	var special_feature: String = ""    # "iron_library", "durn_caeris_seat", ...
	var culture: String = ""            # majority culture (Cultural Roster v1.0) — see CultureData


class Duchy:
	## The middle tier: a named region of counties, grantable as a title.
	var id: int
	var name: String                    # "Duchy of Vael"
	var realm: int                      # the realm it historically belongs to (-1 = ghost duchy)
	var county_ids: Array[int] = []


class MapRealm:
	## A realm *record* on the map. Only realms 0 (Vael) and 1 (Karn-Vol)
	## are simulated live as SimWorld.Realm; the rest exist here as
	## setting data until later modules bring them online.
	var id: int
	var name: String
	var government: String              # feudal|tribal live; administrative|merchant_republic|clan planned
	var capital_province_id: int = -1
	var founding_house: String = ""
	var ruler: String = ""              # named ruler at Year Zero (Faction Map v1.0) — setting data until simulated


var provinces: Array = []
var duchies: Array = []
var realms: Array = []                  # MapRealm records for every power at Year Zero


func generate(seed_value: int) -> void:
	provinces.clear()
	duchies.clear()
	realms.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	# Cells sharing a stretch of boundary line must emit identical
	# vertices, so every edge samples the full union of breakpoints
	# (cell boundaries + the line's own control points) on its line.
	var line_breaks := {}
	for line_name in KhessarMapData.LINES:
		var xs: Array = []
		for pt: Vector2 in KhessarMapData.LINES[line_name]:
			xs.append(pt.x)
		line_breaks[line_name] = xs
	for band: Dictionary in KhessarMapData.BANDS:
		for cell: Dictionary in band["cells"]:
			for line_name in [band["top"], band["bot"]]:
				line_breaks[line_name].append(float(cell["x0"]))
				line_breaks[line_name].append(float(cell["x1"]))

	# canonical names are reserved before any name is rolled
	var used := {}
	for band: Dictionary in KhessarMapData.BANDS:
		for cell: Dictionary in band["cells"]:
			if str(cell["name"]) != "":
				used[str(cell["name"])] = true

	var mids := {}
	var cell_spans: Array = []   # per band: [[province_id, x0, x1], ...]
	for band: Dictionary in KhessarMapData.BANDS:
		var spans: Array = []
		for cell: Dictionary in band["cells"]:
			var p := Province.new()
			p.id = provinces.size()
			p.owner = int(cell["owner"])
			p.de_jure = p.owner
			p.tax = float(cell["tax"])
			p.levy = int(cell["levy"])
			p.cultural_region = str(cell["region"])
			p.terrain = str(cell.get("terrain", "plains"))
			p.coastal = bool(cell.get("coastal", false))
			p.silence_touched = bool(cell.get("silence", false))
			p.ruined = bool(cell.get("ruined", false))
			p.special_feature = str(cell.get("special", ""))
			p.culture = CultureData.province_culture(p.cultural_region, p.owner, p.id)
			p.name = str(cell["name"])
			if p.name == "":
				p.name = ProvinceNamePools.make_name(rng, p.cultural_region, used)
			p.polygon = _cell_polygon(band, cell, line_breaks, mids, rng)
			var c := Vector2.ZERO
			for v in p.polygon:
				c += v
			p.center = c / float(p.polygon.size())
			provinces.append(p)
			spans.append([p.id, float(cell["x0"]), float(cell["x1"])])
		cell_spans.append(spans)

	_build_adjacency(cell_spans)

	for rr: Dictionary in KhessarMapData.REALMS:
		var mr := MapRealm.new()
		mr.id = realms.size()
		mr.name = str(rr["name"])
		mr.government = str(rr["government"])
		mr.capital_province_id = int(rr["capital"])
		mr.founding_house = str(rr["house"])
		mr.ruler = str(rr.get("ruler", ""))
		realms.append(mr)

	# de jure duchies, each named for its richest county (the ducal seat)
	for dd: Dictionary in KhessarMapData.DUCHIES:
		var d := Duchy.new()
		d.id = duchies.size()
		d.realm = int(dd["realm"])
		var seat: Province = provinces[int(dd["counties"][0])]
		for pid in dd["counties"]:
			d.county_ids.append(int(pid))
			provinces[int(pid)].duchy = d.id
			if provinces[int(pid)].tax > seat.tax:
				seat = provinces[int(pid)]
		d.name = "Duchy of %s" % seat.name
		duchies.append(d)


# ---------------------------------------------------------------- geometry

func _cell_polygon(band: Dictionary, cell: Dictionary, line_breaks: Dictionary, mids: Dictionary, rng: RandomNumberGenerator) -> PackedVector2Array:
	var top: Array = KhessarMapData.LINES[band["top"]]
	var bot: Array = KhessarMapData.LINES[band["bot"]]
	var x0: float = cell["x0"]
	var x1: float = cell["x1"]
	var pts := PackedVector2Array()
	var top_xs := _xs_between(line_breaks[band["top"]], x0, x1)
	var bot_xs := _xs_between(line_breaks[band["bot"]], x0, x1)
	# top edge west to east, east side down, bottom edge east to west,
	# west side back up — side edges get a shared jittered midpoint so
	# horizontal neighbours trace the exact same border.
	for x: float in top_xs:
		pts.append(Vector2(x, _line_y(top, x)))
	var ne := pts[pts.size() - 1]
	var se := Vector2(x1, _line_y(bot, x1))
	pts.append(_side_mid(mids, rng, ne, se))
	for i in range(bot_xs.size() - 1, -1, -1):
		pts.append(Vector2(bot_xs[i], _line_y(bot, bot_xs[i])))
	var sw := Vector2(x0, _line_y(bot, x0))
	var nw := Vector2(x0, _line_y(top, x0))
	pts.append(_side_mid(mids, rng, sw, nw))
	return pts


func _xs_between(xs_all: Array, x0: float, x1: float) -> Array:
	var seen := {}
	var out: Array = [x0]
	for xv in xs_all:
		var x := snappedf(float(xv), 0.0001)
		if x > x0 + 0.005 and x < x1 - 0.005 and not seen.has(x):
			seen[x] = true
			out.append(x)
	out.append(x1)
	out.sort()
	return out


func _line_y(line: Array, x: float) -> float:
	var first: Vector2 = line[0]
	if x <= first.x:
		return first.y
	for i in range(1, line.size()):
		var b: Vector2 = line[i]
		if x <= b.x:
			var a: Vector2 = line[i - 1]
			return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 0.0001))
	var last: Vector2 = line[line.size() - 1]
	return last.y


func _side_mid(mids: Dictionary, rng: RandomNumberGenerator, a: Vector2, b: Vector2) -> Vector2:
	var lo := a
	var hi := b
	if b.y < a.y or (b.y == a.y and b.x < a.x):
		lo = b
		hi = a
	var key := Vector4i(int(round(lo.x * 10000.0)), int(round(lo.y * 10000.0)),
		int(round(hi.x * 10000.0)), int(round(hi.y * 10000.0)))
	if not mids.has(key):
		mids[key] = (a + b) * 0.5 + Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.006, 0.006))
	return mids[key]


# ---------------------------------------------------------------- adjacency

func _build_adjacency(cell_spans: Array) -> void:
	# horizontal: consecutive cells of one band that share a border x
	for spans: Array in cell_spans:
		for i in range(spans.size() - 1):
			if absf(float(spans[i][2]) - float(spans[i + 1][1])) < 0.001:
				_link(int(spans[i][0]), int(spans[i + 1][0]))
	# vertical: stacked bands where the x-ranges genuinely overlap
	# (corner-touches don't count)
	for bi in range(cell_spans.size() - 1):
		for a: Array in cell_spans[bi]:
			for b: Array in cell_spans[bi + 1]:
				var overlap: float = minf(float(a[2]), float(b[2])) - maxf(float(a[1]), float(b[1]))
				if overlap > ADJ_EPS:
					_link(int(a[0]), int(b[0]))
	# the illustration's mountain walls and deep forests sever these
	for pair: Array in KhessarMapData.BLOCKED_ADJACENCY:
		_unlink(int(pair[0]), int(pair[1]))


func _link(a: int, b: int) -> void:
	var pa: Province = provinces[a]
	var pb: Province = provinces[b]
	if not pa.neighbors.has(b):
		pa.neighbors.append(b)
		pb.neighbors.append(a)


func _unlink(a: int, b: int) -> void:
	var pa: Province = provinces[a]
	var pb: Province = provinces[b]
	pa.neighbors.erase(b)
	pb.neighbors.erase(a)


# ---------------------------------------------------------------- queries

func realm_display_name(realm_id: int) -> String:
	if realm_id < 0:
		return "Unclaimed"
	if realm_id < realms.size():
		return str(realms[realm_id].name)
	if realm_id == 99:
		return "The Ashfields"  # Caeris's sentinel realm — a research environment, not a crown
	return "Unknown"


func realm_tax(realm_id: int) -> float:
	var total := 0.0
	for p in provinces:
		if p.owner == realm_id:
			total += p.tax
	return total


func realm_levy(realm_id: int) -> int:
	var total := 0
	for p in provinces:
		if p.owner == realm_id:
			total += p.levy
	return total


func realm_centroid(realm_id: int) -> Vector2:
	var total := Vector2.ZERO
	var count := 0
	for p in provinces:
		if p.owner == realm_id:
			total += p.center
			count += 1
	if count == 0:
		return Vector2(0.5, 0.5)
	return total / float(count)


func frontier_midpoint() -> Vector2:
	# the Vael / Karn-Vol frontier — in practice, the Marn's Crossing pass
	for p in provinces:
		if p.owner != 0:
			continue
		for nid in p.neighbors:
			if provinces[nid].owner == 1:
				return (p.center + provinces[nid].center) * 0.5
	# fallback: any border of the player realm
	for p in provinces:
		if p.owner != 0:
			continue
		for nid in p.neighbors:
			if provinces[nid].owner != 0:
				return (p.center + provinces[nid].center) * 0.5
	return Vector2(-1, -1)
