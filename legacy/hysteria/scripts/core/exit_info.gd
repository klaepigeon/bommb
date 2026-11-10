class_name ExitInfo
## Why Android says the app died last time (Android 11+: ActivityManager's historical process
## exit reasons): the reason, the signal, and for a native crash the crashing thread's stack out
## of the tombstone. Read through JNI at the next launch. Everything here is belt and braces: a
## marker file means that if reading it ever kills the app, it's tried once and never again.

const MARK := "user://exitinfo_trying"
const REASONS := {0: "unknown", 1: "exit (the app quit itself)", 2: "killed by a signal", 3: "LOW MEMORY (the system killed it)",
	4: "crash (Java)", 5: "CRASH (native)", 6: "ANR (not responding)", 7: "initialisation failure", 8: "permission change",
	9: "excessive resource usage", 10: "user requested (swiped away / force stop)", 11: "user stopped", 12: "dependency died",
	13: "other (killed by the system)", 14: "freezer", 15: "package state change", 16: "package updated"}

static func read() -> String:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"): return ""
	if FileAccess.file_exists(MARK): return "(reading Android's exit record failed last time; skipped)"
	var mk := FileAccess.open(MARK, FileAccess.WRITE); mk.store_line("x"); mk.flush(); mk = null
	var out := _read()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MARK))
	return out

static func _read() -> String:
	var rt = Engine.get_singleton("AndroidRuntime")
	var act = rt.getActivity()
	if act == null: return "(no activity)"
	var am = act.getSystemService("activity")
	if am == null: return "(no activity manager)"
	var list = am.getHistoricalProcessExitReasons(str(act.getPackageName()), 0, 3)
	if list == null: return "(no exit record)"
	var n := int(list.size())
	var out := ""
	for i in n:
		var e = list.get(i)
		if e == null: continue
		var reason := int(e.getReason())
		out += "%s · status %d · %s · rss %d MB · pss %d MB · %s\n" % [REASONS.get(reason, str(reason)), int(e.getStatus()),
			str(e.getDescription()), int(e.getRss()) / 1024, int(e.getPss()) / 1024,
			Time.get_datetime_string_from_unix_time(int(e.getTimestamp()) / 1000)]
		if i == 0 and reason in [5, 6]:
			var st = e.getTraceInputStream()
			if st != null:
				var bytes: PackedByteArray = PackedByteArray()
				var got = st.readAllBytes()
				if got is PackedByteArray: bytes = got
				st.close()
				out += (tombstone(bytes) if reason == 5 else bytes.slice(0, 3000).get_string_from_utf8()) + "\n"
	return out.strip_edges()

# ---------------------------------------------------------------- the tombstone (protobuf)
static func _varint(b: PackedByteArray, at: int) -> Array:
	var v := 0; var sh := 0
	while at < b.size():
		var c := b[at]; at += 1
		v |= (c & 0x7f) << sh; sh += 7
		if c < 0x80 or sh > 63: break
	return [v, at]

## the fields of one message: [[number, wire type, value (int or PackedByteArray)], ...]
static func fields(b: PackedByteArray) -> Array:
	var out := []; var at := 0
	while at < b.size():
		var k := _varint(b, at); at = k[1]
		var num: int = k[0] >> 3; var wt: int = k[0] & 7
		if wt == 0:
			var v := _varint(b, at); at = v[1]; out.append([num, 0, v[0]])
		elif wt == 2:
			var l := _varint(b, at); at = l[1]
			if l[0] < 0 or at + l[0] > b.size(): break
			out.append([num, 2, b.slice(at, at + l[0])]); at += l[0]
		elif wt == 1: at += 8
		elif wt == 5: at += 4
		else: break
	return out

static func tombstone(b: PackedByteArray) -> String:
	if b.is_empty(): return "(no tombstone)"
	var tid := -1; var out := ""; var threads := []
	for f in fields(b):
		match [f[0], f[1]]:
			[6, 0]: tid = f[2]
			[10, 2]:
				var name := ""; var code := ""; var addr := -1
				for s in fields(f[2]):
					if s[0] == 2 and s[1] == 2: name = (s[2] as PackedByteArray).get_string_from_utf8()
					elif s[0] == 4 and s[1] == 2: code = (s[2] as PackedByteArray).get_string_from_utf8()
					elif s[0] == 9 and s[1] == 0: addr = s[2]
				out += "signal %s (%s) fault address 0x%x\n" % [name, code, addr]
			[14, 2]: out += "abort message: %s\n" % (f[2] as PackedByteArray).get_string_from_utf8().substr(0, 400)
			[16, 2]: threads.append(f[2])
	for entry in threads:
		var key := -1; var th := PackedByteArray()
		for f in fields(entry):
			if f[0] == 1 and f[1] == 0: key = f[2]
			elif f[0] == 2 and f[1] == 2: th = f[2]
		if key != tid: continue
		var n := 0
		for f in fields(th):
			if f[0] == 2 and f[1] == 2: out += "thread: %s\n" % (f[2] as PackedByteArray).get_string_from_utf8()
			elif f[0] == 4 and f[1] == 2 and n < 28:
				var pc := 0; var fn := ""; var file := ""; var off := 0
				for g in fields(f[2]):
					if g[0] == 1 and g[1] == 0: pc = g[2]
					elif g[0] == 4 and g[1] == 2: fn = (g[2] as PackedByteArray).get_string_from_utf8()
					elif g[0] == 5 and g[1] == 0: off = g[2]
					elif g[0] == 6 and g[1] == 2: file = (g[2] as PackedByteArray).get_string_from_utf8()
				out += "#%02d %s  pc %x  %s%s\n" % [n, file.get_file(), pc, fn.substr(0, 90), ("+%d" % off) if fn != "" else ""]
				n += 1
	return out
