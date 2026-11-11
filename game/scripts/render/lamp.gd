class_name Lamp
extends Node3D
## A source of light for the light engine (Lights). It isn't a Godot light: it's a position, a
## colour, a reach and the zones (rooms) it lights, and the shader does the rest.

var color := Color(1.0, 0.85, 0.65)
var energy := 1.0
var reach := 5.0
var zones := PackedInt32Array([-1])  ## -1: every surface it reaches
var on := true
var circuit := ""                    ## "" = needs no power; else Power decides
var flicker := ""                    ## "", candle, tv, dying, fluoro, glow (slow breathing)
var level := 1.0                     ## eased toward on/off
var broken := false
var weight := 0.0                    ## the engine's slot fade
var slot := -1
var _seed := 0.0

static func make(parent: Node, at: Vector3, col: Color, e: float, r: float, zs := PackedInt32Array([-1]), circ := "", fl := "") -> Lamp:
	var l := Lamp.new()
	l.color = col; l.energy = e; l.reach = r; l.zones = zs; l.circuit = circ; l.flicker = fl
	parent.add_child(l)
	l.global_position = at
	return l

func _enter_tree() -> void:
	_seed = randf() * 100.0
	Lights.add(self)

func _exit_tree() -> void:
	Lights.remove(self)

func powered() -> bool:
	return on and not broken and (circuit == "" or Lights.circuit_live(circuit))

## This frame's brightness (0..energy), flicker included. Gentle: nothing strobes.
func current(t: float, delta: float) -> float:
	level = move_toward(level, 1.0 if powered() else 0.0, delta * (6.0 if powered() else 9.0))
	if level <= 0.0:
		return 0.0
	var k := 1.0
	var s := t + _seed
	match flicker:
		"candle": k = 0.82 + 0.1 * sin(s * 7.1) + 0.06 * sin(s * 13.3 + 1.0)
		"tv": k = 0.7 + 0.2 * sin(s * 3.1) * sin(s * 1.7) + 0.1 * sin(s * 11.0)
		"dying": k = 0.75 + 0.12 * sin(s * 0.9) + (0.13 if fmod(s, 9.0) > 8.6 else 0.0) * -1.0
		"fluoro": k = 0.92 + 0.05 * sin(s * 2.3)
		"glow": k = 0.75 + 0.25 * sin(s * 1.3)
	return energy * k * level
