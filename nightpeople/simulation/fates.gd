class_name Fates
extends Node
## Things that happen in the world whether or not the player is watching (data/story.json).
## A fate only starts things; everything after is the ordinary simulation: the person walks
## there through the street and the doors, whoever is around sees it, the absence is noticed by
## whoever expected them, the news travels by gossip, businesses stay shut, the police react.
## The player can get in the way: take what the errand needs, or talk someone out of it.

const ItemScript := preload("res://world/item.gd")

var hood: Neighbourhood
var story: Dictionary
var done: Dictionary = {}           ## summons id → "went" | "cancelled" | "no_item"
var _errand := {}                   ## the summons in progress (phase 2: walking to the Vesper)
var _watch_t := 0.0
var _investigated := {}
var feeders: Array[Feeder] = []
var captive: NPC                    ## who is in the cage, if anyone
const STATION_ROOMS := ["chapel", "platform", "hall", "trackbed", "larder", "larder_cell", "nest", "service", "pump"]

func setup(h: Neighbourhood) -> void:
	hood = h
	story = Journal.story
	Clock.minute_passed.connect(_on_minute)
	Events.world_event.connect(_on_event)
	var floor_y: float = float(hood.under.areas[0].y) + Neighbourhood.FLOOR_Y
	for f in hood.under.get("feeders", []):
		var feeder := Feeder.new()
		hood.add_child(feeder)
		feeder.setup(f, floor_y)
		feeders.append(feeder)

func _on_minute(m: int) -> void:
	for s in story.summons:
		if not done.has(s.id) and m == Clock.parse(s.at):
			_summon(s)
	if m % 5 == 0:
		_notice_absences()
		_police()
	if m == Clock.parse("02:00"):
		for s in story.summons:
			if done.get(s.id, "") in ["cancelled", "no_item"] and not World.gone.has(s.who) and done.get(s.id + "_by_player", false):
				Journal.learn("abe_safe")

# ------------------------------------------------------------------ the summons

func _summon(s: Dictionary) -> void:
	var npc: NPC = World.npcs.get(s.who)
	if npc == null or npc.gone:
		return
	if Journal.knows_any(s.cancel_if):
		done[s.id] = "cancelled"
		done[s.id + "_by_player"] = true
		_shelter(npc)
		return
	done[s.id] = "fetching"
	npc.command({"do": "errand", "place": s.fetch.place}, _fetched.bind(s, npc))

func _fetched(s: Dictionary, npc: NPC) -> void:
	var box := _item(s.fetch.item)
	if box == null:
		done[s.id] = "no_item"
		done[s.id + "_by_player"] = true      # only the player takes things here
		npc.say(s.lines.fetch_missing)
		_shelter(npc)
		return
	box.queue_free()
	npc.carry(s.fetch.item)
	npc.say(s.lines.fetch_ok)
	World.guests[s.guest_room] = [s.who]
	done[s.id] = "walking"
	_errand = {"s": s, "npc": npc}
	npc.command({"do": "errand", "place": s.to}, _arrived.bind(s, npc))

func _arrived(s: Dictionary, npc: NPC) -> void:
	npc.say(s.lines.arrive)
	var door: Door = hood.find_child("Door_" + s.watchers_door, true, false)
	var at: Vector3 = door.global_position if door else npc.global_position
	# Whoever could see the Vesper's door just watched him go in.
	for other in World.npcs.values():
		if other == npc or other.gone or other.hidden_away or other.asleep() or other.id in s.complicit:
			continue
		var room := World.room_at(other.global_position + Vector3.UP * 0.5)
		if other.global_position.distance_to(at) < 18.0 and (room == "" or room.begins_with("club")):
			other.memory.remember("saw_vesper", s.who, Memory.Source.WITNESSED, {}, s.guest_room)
	for p in World.players:
		if World.room_at(p.global_position + Vector3.UP * 0.5) == s.guest_room:
			Events.notice.emit("He lifts the hatch, climbs down into the dark, and the bolt slides shut beneath him.")
			Journal.learn("witness_vesper")
	_drop_item(s.evidence.duplicate())
	if npc.carrying != "":
		var box := {"id": npc.carrying, "name": "Locked tin box, very heavy, marked 'NOT FOR SALE'", "value": 0, "owner": s.who, "prop": "cardboardBoxClosed", "clue": "box_taken", "at": s.box_to, "offset": [0.3, 0.0], "y": 0.86}
		_drop_item(box)
	World.guests.erase(s.guest_room)
	npc.carry("")
	# Down the hatch: off the street (World.gone keeps his shop shut and his absence noticed),
	# into the cage below.
	World.gone[s.who] = true
	npc.global_position = World.places[s.captive_at].pos
	npc.command({"do": "captive", "place": s.captive_at})
	captive = npc
	done[s.id] = "went"
	_errand = {}

func _drop_item(ev: Dictionary) -> void:
	var item: Item = ItemScript.new()
	item.setup(ev)
	var vis := Assets.prop(ev.get("prop", "books"))
	vis.scale = Vector3.ONE * 0.4
	item.add_child(vis)
	hood.add_child(item)
	item.global_position = World.places[ev.at].pos + Vector3(ev.offset[0], 0.02 + float(ev.get("y", 0.0)), ev.offset[1])

## Too frightened to go, or with nothing to bring: home, door locked, until tomorrow evening.
func _shelter(npc: NPC) -> void:
	var seat := npc.mind._home_place(["seat"], npc.global_position)
	if seat == "":
		return
	npc.command({"do": "home", "place": seat}, Callable(), Clock.total_minutes + Mind.minutes_until(Clock.parse("17:00")))

func _physics_process(delta: float) -> void:
	_station_checks()
	if _errand.is_empty():
		return
	_watch_t -= delta
	if _watch_t > 0.0:
		return
	_watch_t = 0.3
	var npc: NPC = _errand.npc
	var room := World.room_at(npc.global_position + Vector3.UP * 0.5)
	if not room.begins_with("club"):
		return
	for p in World.players:
		var eye: Vector3 = p.camera.global_position
		var to := npc.global_position + Vector3.UP * 1.2 - eye
		if to.length() > 22.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, eye + to, 1 | 8)
		if p.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			Journal.learn("witness_vesper")

# ------------------------------------------------------------------ consequences

## People who expect someone somewhere notice when they're not there.
func _notice_absences() -> void:
	var na: Dictionary = story.notice_absence
	if not World.gone.has(na.who):
		return
	var m := Clock.minute_of_day()
	for e in na.expected:
		if not Clock.in_span(m, Clock.parse(e.from), Clock.parse(e.to)) or not World.rooms.has(e.room):
			continue
		var box: AABB = World.rooms[e.room].aabb
		for n in World.npcs.values():
			if n.gone or n.hidden_away or n.asleep() or n.id == na.who:
				continue
			var room := World.room_at(n.global_position + Vector3.UP * 0.5)
			var near: bool = room == e.room or (room == "" and box.grow(5.0).has_point(n.global_position + Vector3.UP))
			if near and n.memory.remember("missing", na.who, Memory.Source.FOUND, {}, e.room):
				n.say("Where's Abe? He's always here by now." if room == e.room else "Abe's shop is dark. On a weeknight?", "abe_gone_heard")

## The beat cop looks into a disappearance once he hears of it.
func _police() -> void:
	var doyle: NPC = World.npcs.get("doyle")
	if doyle == null or doyle.hidden_away or _investigated.has("abe"):
		return
	if doyle.memory.knows("missing", "abe"):
		_investigated["abe"] = true
		doyle.command({"do": "errand", "place": "pawn.front"}, func(): doyle.say("Kessler's place dark at this hour. That ain't like him."),
			Clock.total_minutes + 20.0)

func _on_event(e: Dictionary) -> void:
	match e.kind:
		"reported":
			var doyle: NPC = World.npcs.get("doyle")
			for b in doyle.mind.schedule:
				if b.do == "patrol":
					b.do = "work"
					b["at"] = "street.vesper_watch"
			doyle.release()

func _item(id: String) -> Item:
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Item and n.data.get("id", "") == id and not n.is_queued_for_deletion():
			return n
	return null

# ------------------------------------------------------------------ under the street

var _station_t := 0.0

func _station_checks() -> void:
	_station_t -= get_physics_process_delta_time()
	if _station_t > 0.0 or World.players.is_empty():
		return
	_station_t = 0.25
	var p: Player = World.players[0]
	var room := World.room_at(p.global_position + Vector3.UP * 0.5)
	if room in STATION_ROOMS:
		Journal.learn("found_station")
	if captive and is_instance_valid(captive):
		if room == "larder_cell" or (room == "larder" and p.global_position.distance_to(captive.global_position) < 6.0):
			Journal.learn("abe_found")
		var cage: Door = hood.find_child("Door_cage", true, false)
		if cage and cage.is_open and p.global_position.distance_to(captive.global_position) < 6.0:
			_free(captive)

## Out of the cage: he goes home on his own, the long way (ladders and all), and his life resumes.
func _free(npc: NPC) -> void:
	captive = null
	Journal.learn("abe_freed")
	World.gone.erase(npc.id)
	npc.say("You came. You actually came. I'm going home. God help me, I'm going home.")
	var seat := npc.mind._home_place(["seat"], npc.global_position)
	npc.command({"do": "errand", "place": seat}, _home_again.bind(npc))

func _home_again(npc: NPC) -> void:
	if World.players[0].global_position.distance_to(npc.global_position) < 20.0:
		Journal.learn("abe_home")
	npc.release()
