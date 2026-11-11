class_name Mats
extends RefCounted
## The material library for both apartments. A RoomMats instance hands out one ShaderMaterial per
## style for one room, so the room's circuit (power) and its Backrooms alteration (wrong, mould,
## tint) can be set on that room alone. Textures are shared.

const ENV := preload("res://shaders/env.gdshader")

## style -> [texture, metres per tile, tint]
const STYLES := {
	"damask": ["wallpaper_damask", 1.1, Color(1, 1, 1)],
	"floral": ["wallpaper_floral", 1.0, Color(1, 1, 1)],
	"child": ["wallpaper_child", 0.6, Color(1, 1, 1)],
	"plaster": ["plaster", 1.2, Color(1, 1, 1)],
	"draft": ["plaster_draft", 1.0, Color(1, 1, 1)],
	"tile_wall": ["tile_wall", 0.6, Color(1, 1, 1)],
	"tile_floor": ["tile_floor", 0.6, Color(1, 1, 1)],
	"parquet": ["parquet", 0.9, Color(1, 1, 1)],
	"lino": ["lino", 0.8, Color(1, 1, 1)],
	"carpet": ["carpet", 2.0, Color(1, 1, 1)],
	"concrete": ["concrete", 1.5, Color(1, 1, 1)],
	"ceiling": ["ceiling", 1.6, Color(1, 1, 1)],
	"green_paint": ["green_paint", 2.6, Color(1, 1, 1)],
	"wood_dark": ["wood_dark", 0.6, Color(1, 1, 1)],
	"wood_light": ["wood_light", 0.6, Color(1, 1, 1)],
	"wood_raw": ["wood_raw", 0.8, Color(1, 1, 1)],
	"fabric_green": ["fabric_green", 0.4, Color(1, 1, 1)],
	"fabric_bed": ["fabric_bed", 0.6, Color(1, 1, 1)],
	"enamel": ["enamel", 0.5, Color(1, 1, 1)],
	"metal": ["metal", 0.4, Color(1, 1, 1)],
	"chrome": ["metal", 0.4, Color(1.6, 1.6, 1.6)],
	"brass": ["metal", 0.3, Color(1.5, 1.2, 0.6)],
	"rubber": ["metal", 0.4, Color(0.25, 0.25, 0.25)],
	"door_padded": ["door_padded", 1.0, Color(1, 1, 1)],
	"door_panel": ["door_panel", 1.0, Color(1, 1, 1)],
	"glass": ["glass_night", 1.0, Color(1, 1, 1)],
	"paper": ["paper", 0.3, Color(1, 1, 1)],
	"sticky": ["sticky", 0.1, Color(1, 1, 1)],
	"cardboard": ["cardboard", 0.5, Color(1, 1, 1)],
	"coral": ["coral", 0.3, Color(1, 1, 1)],
	"black": ["black", 1.0, Color(1, 1, 1)],
	"white": ["white", 1.0, Color(0.85, 0.85, 0.8)],
	"bulb": ["white", 1.0, Color(1, 0.95, 0.8)],
	"void": ["white", 1.0, Color(0.55, 0.55, 0.52)],
	"water": ["black", 1.0, Color(1, 1, 1)],
}

static var _tex := {}

static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://textures/%s.png" % name)
	return _tex[name]

static func uvm(style: String) -> float:
	return float(STYLES.get(style, ["white", 1.0])[1])

## a standalone material (props, moving parts): lit by `light` (a colour) instead of vertex colours
static func flat(style: String, light := Color(0.5, 0.5, 0.5), alter := {}) -> ShaderMaterial:
	var m := _make(style, alter)
	m.set_shader_parameter("flat_light", Vector3(light.r, light.g, light.b))
	return m

static func _make(style: String, alter := {}) -> ShaderMaterial:
	var s: Array = STYLES.get(style, STYLES["white"])
	var m := ShaderMaterial.new()
	m.shader = ENV
	m.set_shader_parameter("albedo_tex", tex(s[0]))
	m.set_shader_parameter("mould_tex", tex("mould"))
	var tint: Color = s[2]
	if alter.has("tint"):
		tint = tint * Color(alter.tint)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("wrong", float(alter.get("wrong", 0.0)))
	m.set_shader_parameter("mould", float(alter.get("mould", 0.0)))
	m.set_shader_parameter("breathe", bool(alter.get("breathe", false)))
	m.set_shader_parameter("snap_res", Vector2(320, 180))
	if style == "bulb":
		m.set_shader_parameter("emission_k", 1.6)
		m.set_shader_parameter("emission_powered", true)
	if style == "sticky":
		m.set_shader_parameter("emission_k", 0.25)
	if style == "void":
		m.set_shader_parameter("emission_k", 0.6)
	return m


class RoomMats:
	extends RefCounted
	var mats := {}
	var alter := {}
	var power := 1.0

	func _init(p_alter := {}) -> void:
		alter = p_alter

	func get_mat(style: String) -> ShaderMaterial:
		if not mats.has(style):
			var a := alter.duplicate()
			if style in ["bulb", "void", "sticky", "black", "glass"]:
				a.erase("mould")
			if style in ["damask", "floral", "child", "plaster", "tile_wall", "green_paint", "ceiling"]:
				a["breathe"] = true
			mats[style] = Mats._make(style, a)
			mats[style].set_shader_parameter("power", power)
		return mats[style]

	## everything MB might ask for, resolved lazily
	func dict_for(mb: MB) -> Dictionary:
		var d := {}
		for k in mb._s:
			d[k] = get_mat(k)
		return d

	func set_power(p: float) -> void:
		power = p
		for k in mats:
			mats[k].set_shader_parameter("power", p)
