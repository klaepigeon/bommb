class_name WorldScript
extends RefCounted
## The little language the building's data is written in: what happens when you use a thing,
## open a lock, or walk into a trigger. Each step is {"do": <action>, ...}. Conditions ("when")
## read the world's memory: items you carry and flags that are set. That memory lives in the
## profile, so a door you unlocked stays unlocked, run after run.
##
## The walk screen is the host: it knows how to make a line be said, a light flicker, a door
## swing, the Caller be standing behind you.

const ACTIONS := {
	"say": "the Caller says something, in a face (persona, text)",
	"aside": "a mute line in the subtitles (text)",
	"sfx": "a sound (id, db)",
	"flag": "set a flag (id, value=true; scope=profile|run|walk)",
	"give": "you pick something up (item)",
	"take": "something is taken off you (item)",
	"unlock": "a door's lock opens for good (portal)",
	"open": "a door swings open (portal)",
	"close": "a door slams shut (portal)",
	"lights": "the lights in an area (area, mode=flicker|off|on, time)",
	"scare": "a scare (kind=behind|lights|face, persona, text)",
	"caller": "move the Caller (at [x,y,z], rot, persona, unseen=true)",
	"wait": "a pause (t)",
	"dial": "bring up a combination lock (lock = the portal it locks)",
	"lore": "read the lore for a station (station)",
	"search": "search a room spot (room, spot)",
	"if": "branch (when {...}, then [...], else [...])",
	"shake": "the camera shakes (amount)",
}

## Run a list of steps. Awaitable.
static func run(steps: Array, host) -> void:
	for s in steps:
		if not test(s.get("when", {}), host):
			continue
		var what: String = s.get("do", "")
		match what:
			"say":
				host.ws_say(s.get("persona", "caller"), s.get("text", ""))
			"aside":
				host.ws_aside(s.get("text", ""))
			"sfx":
				host.ws_sfx(s.get("id", "click"), float(s.get("db", -4.0)))
			"flag":
				set_flag(s.get("id", ""), s.get("value", true), s.get("scope", "profile"), host)
			"give":
				give(s.get("item", ""))
			"take":
				take(s.get("item", ""))
			"unlock":
				set_flag("unlocked:" + str(s.get("portal", "")), true, "profile", host)
			"open":
				await host.ws_open(s.get("portal", ""), true)
			"close":
				await host.ws_open(s.get("portal", ""), false)
			"lights":
				host.ws_lights(s.get("area", ""), s.get("mode", "flicker"), float(s.get("time", 1.0)))
			"scare":
				await host.ws_scare(s)
			"caller":
				host.ws_caller(s)
			"wait":
				await host.ws_wait(float(s.get("t", 0.5)))
			"dial":
				host.ws_dial(s.get("lock", ""))
			"lore":
				host.ws_lore(s.get("station", ""))
			"search":
				host.ws_search(s.get("room", ""), s.get("spot", ""))
			"if":
				if test(s.get("test", {}), host):
					await run(s.get("then", []), host)
				else:
					await run(s.get("else", []), host)
			"shake":
				host.ws_shake(float(s.get("amount", 0.3)))
			_:
				push_warning("world script: unknown action '%s'" % what)

# ------------------------------------------------------------------ the world's memory

static func world() -> Dictionary:
	var w = Profile.data.get("world", null)
	if typeof(w) != TYPE_DICTIONARY:
		w = {"items": [], "flags": {}}
		Profile.data["world"] = w
	if not w.has("items"):
		w["items"] = []
	if not w.has("flags"):
		w["flags"] = {}
	return w

static func has_item(id: String) -> bool:
	return id in world()["items"]

static func give(id: String) -> void:
	if id != "" and not has_item(id):
		world()["items"].append(id)
		Profile.save()

static func take(id: String) -> void:
	world()["items"].erase(id)
	Profile.save()

static func flag(id: String, host = null) -> bool:
	if host != null and host.has_method("ws_flag") and host.ws_flag(id):
		return true
	return bool(world()["flags"].get(id, false))

static func set_flag(id: String, value, scope: String, host) -> void:
	if id == "":
		return
	if scope == "profile":
		world()["flags"][id] = value
		Profile.save()
	elif host != null:
		host.ws_set_flag(id, value, scope)

## {item, not_item, flag, not_flag, in_run}: all must hold.
static func test(cond: Dictionary, host = null) -> bool:
	if cond.is_empty():
		return true
	if cond.has("item") and not has_item(cond["item"]):
		return false
	if cond.has("not_item") and has_item(cond["not_item"]):
		return false
	if cond.has("flag") and not flag(cond["flag"], host):
		return false
	if cond.has("not_flag") and flag(cond["not_flag"], host):
		return false
	if cond.has("in_run") and bool(cond["in_run"]) != (host != null and host.ws_in_run()):
		return false
	return true

## Is this door's lock still shut?
static func locked(p: Dictionary) -> bool:
	var lock: Dictionary = p.get("lock", {})
	if lock.is_empty():
		return false
	return not flag("unlocked:" + str(p["id"]))
