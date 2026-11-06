extends Node
## One process of the network test (tools/net_test.sh runs several):
##   --role=host --via=relay|lan --humans=N   opens a room, waits for N-1 others, plays
##   --role=client --code=XXXXX | --ip=A      joins, plays its seat with a ViewBot
## Writes what happened to --out=path. Exits when the match ends (or on --timeout).

var args := {}
var bot := ViewBot.new()
var ended := ""
var out_path := ""
var started := false
var events_seen := 0
var deaths := 0
var timeout := 600.0
var _t := 0.0
var _drop_at := -1.0
var _rejoined := false
var _readied := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=")
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Audio.muted = true
	out_path = str(args.get("out", "user://net_test.txt"))
	timeout = float(args.get("timeout", "600"))
	_drop_at = float(args.get("drop_at", "-1"))
	Settings.values.name = str(args.get("name", "BOT%d" % (randi() % 1000)))
	if args.has("relay"):
		Settings.values.relay_url = str(args.relay)
	Net.status.connect(func(s): print("[%s] %s" % [Settings.values.name, s]))
	Net.state.connect(_on_state)
	Net.match_started.connect(func():
		started = true
		bot.seat = Net.my_seats[0] if not Net.my_seats.is_empty() else 0
		print("[%s] match started, seat %d" % [Settings.values.name, bot.seat]))
	Net.left.connect(func(r):
		if ended == "":
			_write("LEFT " + r))
	if args.get("role") == "host":
		if args.get("via") == "relay":
			Net.host_relay()
		else:
			Net.host_lan()
	else:
		if args.has("ip"):
			Net.join_ip(str(args.ip))
		else:
			Net.join_code(str(args.code))


func _process(delta: float) -> void:
	_t += delta
	if _t > timeout:
		_write("TIMEOUT phase=%s" % str(Net.last_view.get("phase", "?")))
		return
	if args.get("role") == "host":
		if Net.code != "" and Net.code != "....." and not FileAccess.file_exists(str(args.get("codefile", "user://code"))):
			var f := FileAccess.open(str(args.get("codefile", "user://code")), FileAccess.WRITE)
			f.store_string(Net.code)
			f.close()
		if not started and Seats.humans() >= int(args.get("humans", "2")) and Net.all_ready():
			Net.launch(int(args.get("seed", "42")))
			Net.core.fast = args.has("fast")
	elif not started and Net.role == "client" and Net.my_seats.size() > 0 and not _readied:
		_readied = true
		Net.set_ready(true)
	# a client that drops out mid-match and comes back
	if _drop_at > 0.0 and started and _t > _drop_at and not _rejoined:
		_rejoined = true
		print("[%s] dropping out" % Settings.values.name)
		Net.leave_quiet()
		started = false
		_readied = true
		get_tree().create_timer(3.0).timeout.connect(func():
			print("[%s] rejoining" % Settings.values.name)
			Net.join_code(str(args.code)))
	if started:
		bot.step(Net.last_view, delta)


func _on_state(view: Dictionary, events: Array) -> void:
	events_seen += events.size()
	for e in events:
		if e.e == "death":
			deaths += 1
		if e.e == "ending":
			ended = str(e.kind)
	if view.get("ending", "") != "" and ended == "":
		ended = str(view.ending)
	if ended != "":
		_write("ENDING %s round=%s deaths_seen=%d events=%d players=%s" % [ended, str(view.get("round", "?")), deaths, events_seen,
			str(view.players.map(func(p): return "%s:%s:%s" % [p.name, p.kind, "alive" if p.alive else p.death]))])


func _write(s: String) -> void:
	print("[%s] %s" % [Settings.values.name, s])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(s + "\n")
	f.close()
	get_tree().create_timer(4.0 if args.get("role") == "host" else 0.5).timeout.connect(func(): get_tree().quit())
	set_process(false)
