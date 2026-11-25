extends Node
## World time. Minutes since midnight of day 0, advanced at `minutes_per_second`.
## The whole simulation reads time from here, so tests can fast-forward with `advance()`.

signal minute_passed(minute_of_day: int)
signal hour_passed(hour: int)

const START_DATE := "Thursday 7 July 1977"
var total_minutes := 21.0 * 60.0     ## the game starts at 21:00
var minutes_per_second := 1.0        ## a 10-hour night lasts 10 real minutes
var running := true

var _last_minute := -1

func _process(delta: float) -> void:
	if running:
		advance(delta * minutes_per_second)

func advance(minutes: float) -> void:
	total_minutes += minutes
	var m := int(total_minutes)
	while _last_minute < m:
		_last_minute = m if _last_minute < 0 else _last_minute + 1
		minute_passed.emit(_last_minute % 1440)
		if _last_minute % 60 == 0:
			hour_passed.emit((_last_minute / 60) % 24)

func minute_of_day() -> float:
	return fmod(total_minutes, 1440.0)

func day() -> int:
	return int(total_minutes / 1440.0)

func text() -> String:
	var m := int(minute_of_day())
	return "%02d:%02d" % [m / 60, m % 60]

## "HH:MM" → minute of day.
static func parse(hhmm: String) -> int:
	var p := hhmm.split(":")
	return int(p[0]) * 60 + int(p[1])

## True if minute-of-day `m` falls in [from, to), wrapping past midnight.
static func in_span(m: float, from: int, to: int) -> bool:
	if from <= to:
		return m >= from and m < to
	return m >= from or m < to
