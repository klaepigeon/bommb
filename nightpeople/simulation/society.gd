class_name Society
extends Node
## Everyone on the block: spawns the people in data/npcs.json, decides how much simulation each
## gets (tiers by distance to the nearest player), ages needs and memories with the clock, and
## lets people who spend time together pass on what they know (gossip).

const DATA := "res://data/npcs.json"
const NEARBY := 55.0
const GOSSIP_RANGE := 3.5

## What overhearing a piece of news teaches the player.
const CLUES := {"missing": "abe_gone_heard", "saw_vesper": "witness_vesper"}

var npcs: Array[NPC] = []
var _tier_t := 0.0

func spawn(parent: Node3D) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	for d in data.npcs:
		var n := NPC.new()
		parent.add_child(n)
		n.setup(d)
		World.npcs[n.id] = n
		npcs.append(n)
	for n in npcs:
		n.start()
	retier()
	Clock.minute_passed.connect(_on_minute)

func _process(delta: float) -> void:
	_tier_t -= delta
	if _tier_t <= 0.0:
		_tier_t = 0.25
		retier()

## ACTIVE near a player at normal speed: physics, navigation, perception. NEARBY: visible and
## animated, moved kinematically. DISTANT: hidden, moved kinematically. Fast-forwarded time makes
## everyone kinematic so routines keep pace with the clock.
func retier() -> void:
	var fast := Clock.minutes_per_second > Clock.BASE_RATE * 1.5
	for n in npcs:
		var d := INF
		for p in World.players:
			d = minf(d, n.global_position.distance_to(p.global_position))
		var tier := NPC.Tier.ACTIVE if d < Settings.npc_active_distance else (NPC.Tier.NEARBY if d < NEARBY else NPC.Tier.DISTANT)
		n.set_mode(tier, tier == NPC.Tier.ACTIVE and not fast)

func _on_minute(m: int) -> void:
	if m % 10 != 0:
		return
	for n in npcs:
		n.mind.grow(1.0 / 6.0)
		n.memory.fade(1.0 / 6.0)
	_gossip()

## People together for a while share the most striking thing they know, if they trust each
## other at all. The listener remembers it as told, by whom; it can reach someone who never saw
## anything, and it can reach the victim.
func _gossip() -> void:
	for a in npcs:
		if a.hidden_away or not a.arrived or a.asleep():
			continue
		var news := a.memory.gossip()
		if news.is_empty():
			continue
		for b in npcs:
			if b == a or b.hidden_away or b.asleep() or a.global_position.distance_to(b.global_position) > GOSSIP_RANGE:
				continue
			if float(a.def.relationships.get(b.id, 0.0)) < -0.2:
				continue
			var detail := {}
			for k in ["item", "victim"]:
				if news.has(k):
					detail[k] = news[k]
			if b.memory.remember(news.kind, news.culprit, Memory.Source.TOLD, detail, news.place, a.id):
				a.say(news_line(news), CLUES.get(news.kind, ""))

## How someone passes on a memory, from the templates in data/story.json "news".
static func news_line(e: Dictionary) -> String:
	var t: String = Journal.story.news.get(e.kind, "You hear about {place}?")
	var place: String = World.rooms.get(e.get("place", ""), {"name": "a place around here"}).name
	t = t.replace("{item}", NPC._short(e.get("item", "something"))).replace("{place}", place)
	if e.get("culprit", "") == "player":
		t = t.replace("Somebody", "That stranger").replace("There was a stranger", "That stranger was")
	return "You hear? " + t
