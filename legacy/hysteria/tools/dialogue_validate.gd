extends SceneTree
## Checks every conversation in content/dialogue against the rules, and lists what's wrong,
## by conversation and node: missing text or speaker, unknown speakers, links to nodes that don't
## exist, nodes nothing reaches, dead ends, duplicate option ids, conditions and actions it can't
## read; and, as warnings, lines with no recorded voice yet.
## godot --headless --path hysteria -s tools/dialogue_validate.gd

const TYPES := ["line", "choice", "branch", "action", "socko", "end"]
const COND := ["flag:", "skill:", "seen:", "knows:", "rel:", "memory"]
const ACT := ["set:", "unset:", "know:", "rel:"]
var errors := 0
var warnings := 0

func err(c: String, n: String, m: String) -> void:
	errors += 1; print("  ERROR   %s · %s · %s" % [c, n, m])
func warn(c: String, n: String, m: String) -> void:
	warnings += 1; print("  warning %s · %s · %s" % [c, n, m])

func _initialize() -> void:
	var chars: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/characters.json"))
	var voices: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://content/voice/index.json")) as Dictionary).get("lines", {})
	var d := DirAccess.open("res://content/dialogue")
	var ids := {}
	var n_conv := 0; var n_lines := 0; var n_voiced := 0
	for f in d.get_files():
		if not f.ends_with(".json"): continue
		n_conv += 1
		var g = JSON.parse_string(FileAccess.get_file_as_string("res://content/dialogue/" + f))
		var cid := f.trim_suffix(".json")
		if not g is Dictionary: err(cid, "-", "not valid JSON"); continue
		if String(g.get("id", "")) != cid: err(cid, "-", "id '%s' doesn't match the file name" % g.get("id", ""))
		if ids.has(cid): err(cid, "-", "duplicate conversation id")
		ids[cid] = true
		var nodes: Dictionary = g.get("nodes", {})
		var start := String(g.get("start", ""))
		if not nodes.has(start): err(cid, "-", "start node '%s' doesn't exist" % start)
		for p in g.get("participants", []):
			if not chars.has(p): err(cid, "-", "participant '%s' isn't in characters.json" % p)
		var edges := {}
		for nid in nodes:
			var n: Dictionary = nodes[nid]
			var t := String(n.get("type", "line"))
			var outs := []
			if not TYPES.has(t): err(cid, nid, "unknown type '%s'" % t)
			for c in n.get("cond", []): _cond(cid, nid, String(c))
			for a in n.get("set", []): _act(cid, nid, String(a))
			match t:
				"line", "socko":
					var sp := "socko" if t == "socko" else String(n.get("speaker", ""))
					if sp == "": err(cid, nid, "line has no speaker")
					elif not chars.has(sp): err(cid, nid, "speaker '%s' isn't in characters.json" % sp)
					if String(n.get("text", "")).strip_edges() == "": err(cid, nid, "no text")
					n_lines += 1
					var vid := String(n.get("id", "%s.%s" % [cid, nid]))
					if voices.has(vid): n_voiced += 1
					else: warn(cid, nid, "no recorded voice for '%s' (TTS stands in)" % vid)
					outs.append(n.get("next", ""))
					if String(n.get("next", "")) == "": err(cid, nid, "dead end: no next and not an end node")
				"action":
					outs.append(n.get("next", ""))
				"branch":
					for c in n.get("cases", []):
						outs.append(c.get("next", ""))
						for cc in c.get("cond", []): _cond(cid, nid, String(cc))
					if not n.has("else"): warn(cid, nid, "branch has no else: if no case holds, the conversation ends here")
					else: outs.append(n.else)
				"choice":
					var oids := {}
					var all_cond := true
					for o in n.get("options", []):
						var oid := String(o.get("id", ""))
						if oid == "" or oids.has(oid): err(cid, nid, "option id '%s' missing or duplicated" % oid)
						oids[oid] = true
						if String(o.get("intent", "")) == "": err(cid, nid + "/" + oid, "option has no intent label")
						if not o.has("cond") and not o.get("once", false): all_cond = false
						for c in o.get("cond", []): _cond(cid, nid + "/" + oid, String(c))
						for a in o.get("set", []): _act(cid, nid + "/" + oid, String(a))
						var sk: Dictionary = o.get("socko", {})
						if not sk.is_empty() and not ["aside", "interrupt", "proxy", "hijack"].has(String(sk.get("mode", ""))): err(cid, nid + "/" + oid, "socko mode '%s' unknown" % sk.get("mode", ""))
						outs.append(o.get("next", ""))
						n_lines += 1
					if all_cond and not n.has("else"): err(cid, nid, "every option can disappear and there's no else: a branch with no exit")
			for o in outs:
				if String(o) != "" and not nodes.has(String(o)): err(cid, nid, "links to '%s', which doesn't exist" % o)
			edges[nid] = outs
		# what the start reaches
		var seen := {start: true}; var q := [start]
		while q.size() > 0:
			var c: String = q.pop_front()
			for o in edges.get(c, []):
				if String(o) != "" and not seen.has(String(o)): seen[String(o)] = true; q.append(String(o))
		for nid in nodes:
			if not seen.has(nid): err(cid, nid, "unreachable: nothing leads here")
	print("DIALOGUE: %d conversations, %d lines, %d voiced · %d errors, %d warnings" % [n_conv, n_lines, n_voiced, errors, warnings])
	print("VALIDATE ", "PASS" if errors == 0 else "FAIL")
	quit(0 if errors == 0 else 1)

func _cond(c: String, n: String, s: String) -> void:
	var b := s.trim_prefix("!")
	for p in COND:
		if b.begins_with(p): return
	err(c, n, "condition '%s' can't be read" % s)

func _act(c: String, n: String, s: String) -> void:
	for p in ACT:
		if s.begins_with(p): return
	err(c, n, "action '%s' can't be read" % s)
