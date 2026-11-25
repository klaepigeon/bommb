class_name Memory
extends RefCounted
## What one person knows, and how they came to know it. Nobody learns anything except by
## seeing it, hearing it, finding the evidence, or being told; each entry keeps its source.
## Entries fade; witnessed things fade slowest. Disposition toward someone is derived from
## what is remembered about them, not stored separately.

enum Source { WITNESSED, HEARD, FOUND, TOLD, RUMOUR }
const SOURCE_NAMES := ["witnessed", "heard", "found", "told", "rumour"]
const FADE_PER_HOUR := [0.01, 0.03, 0.02, 0.04, 0.06]
## How worth passing on each kind of memory is (gossip tells the most newsworthy).
const NEWS := {"missing": 1.0, "saw_vesper": 0.95, "evidence": 0.9, "theft": 0.8, "break_in": 0.7, "trespass": 0.4, "lockpick": 0.3}
## How much each kind of memory sours someone on its culprit.
const WEIGHT := {"trespass": -0.35, "theft": -0.6, "break_in": -0.5, "lockpick": -0.3, "seen": 0.0, "met": 0.05, "assault": -0.9}

var entries: Array[Dictionary] = []

## Add or refresh a memory. Same kind + culprit + place refreshes the old one instead.
## Returns true if it is new.
func remember(kind: String, culprit: String, source: int, detail := {}, place := "", from := "") -> bool:
	for e in entries:
		if e.kind == kind and e.culprit == culprit and e.place == place and e.get("item", "") == detail.get("item", ""):
			e.strength = 1.0 if source == Source.WITNESSED else maxf(e.strength, 0.7)
			e.time = Clock.total_minutes
			if source < e.source:
				e.source = source
			return false
	var e := {"kind": kind, "culprit": culprit, "source": source, "place": place, "from": from,
		"time": Clock.total_minutes, "strength": 1.0 if source == Source.WITNESSED else 0.7}
	e.merge(detail)
	entries.append(e)
	return true

func fade(hours: float) -> void:
	for i in range(entries.size() - 1, -1, -1):
		var e := entries[i]
		e.strength -= FADE_PER_HOUR[e.source] * hours
		if e.strength <= 0.05:
			entries.remove_at(i)

func about(culprit: String, kind := "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in entries:
		if e.culprit == culprit and (kind == "" or e.kind == kind):
			out.append(e)
	return out

func knows(kind: String, culprit := "") -> bool:
	for e in entries:
		if e.kind == kind and (culprit == "" or e.culprit == culprit):
			return true
	return false

## -1 (hates) .. 1 (likes), from what's remembered about `who`.
func disposition(who: String) -> float:
	var d := 0.0
	for e in entries:
		if e.culprit == who:
			var w: float = WEIGHT.get(e.kind, 0.0)
			d += w * e.strength * (1.0 if e.source == Source.WITNESSED else 0.5)
	return clampf(d, -1.0, 1.0)

## The most notable thing worth passing on (crimes), or {} if nothing.
func gossip() -> Dictionary:
	var best := {}
	var best_score := 0.0
	for e in entries:
		var score: float = NEWS.get(e.kind, 0.0) * e.strength
		if score > 0.25 and score > best_score:
			best = e
			best_score = score
	return best

func describe(e: Dictionary) -> String:
	return "%s %s by %s at %s (%s, %.0f%%)" % [e.kind, e.get("item", ""), e.culprit, e.place, SOURCE_NAMES[e.source], e.strength * 100]
