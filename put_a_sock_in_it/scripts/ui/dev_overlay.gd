class_name DevOverlay
extends CanvasLayer
## Developer-only inspection (docs/CHAPTER2.md): F3 toggles it. Never in a player's build: it
## only exists when Godot runs a debug build from the editor or with `-- --dev` on the command
## line (an exported release has OS.is_debug_build() false, so Level never adds it).
## Shows: relationships (the super's numbers and disposition, Socko's anger), Chapter 2's flags
## and puzzle state, and every inhabitant: what it's doing, its objective, its target, its
## awareness of Kurt, its health.

var level: Node
var _lb: Label
var _on := false

static func wanted() -> bool:
	if not OS.is_debug_build(): return false
	return OS.has_feature("editor") or OS.get_cmdline_user_args().has("--dev") or OS.get_cmdline_args().has("--dev")

func _ready() -> void:
	layer = 90
	_lb = Label.new(); _lb.position = Vector2(12, 120); _lb.add_theme_font_size_override("font_size", 13)
	_lb.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6)); _lb.add_theme_color_override("font_shadow_color", Color.BLACK)
	_lb.visible = false; add_child(_lb)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_F3:
		_on = not _on; _lb.visible = _on

func _process(_d: float) -> void:
	if _on: _lb.text = report()

## The whole state, as text (the overlay; tests print it too).
func report() -> String:
	var t := PackedStringArray()
	for who in Game.rel:
		var r: Dictionary = Game.rel[who]
		if who == "socko": t.append("socko  anger %.1f" % float(r.get("anger", 0.0))); continue
		t.append("%s  %s  susp %.1f  host %.1f  trust %.1f  threat %s  lied %s  approach %s  known %s" % [who, Game.disposition(who), float(r.suspicion), float(r.hostility), float(r.trust), r.threatened, r.lied, r.approach, r.known])
	var f := PackedStringArray()
	for k in Game.flags: if String(k).begins_with("ch2_"): f.append("%s=%s" % [k, Game.flags[k]])
	t.append("flags  " + ", ".join(f))
	if level:
		t.append("power %s  fuses %s  boiler %s  heat %.2f  hatch %s  lift at %s" % [level.get("power_on"), level.get("fuses"), level.get("boiler_on"), float(level.get("heat") if level.get("heat") != null else 0.0), level.get("hatch_open"), level.lift.at if level.get("lift") else "-"])
	t.append("inventory  %s" % Game.inventory)
	for n in get_tree().get_nodes_in_group("inhabitant"):
		var tg: String = "-" if not is_instance_valid(n.target) else (n.target.name if n.target != n.player else "KURT")
		t.append("%-12s %-11s obj %-11s tgt %-10s aware %.2f hp %.0f at %s" % [n.id, n.state, n.objective, tg, n.awareness, n.hp, n.global_position.snapped(Vector3.ONE * 0.1)])
	return "\n".join(t)
