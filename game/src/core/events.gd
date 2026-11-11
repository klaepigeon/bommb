extends Node
## Global signal bus. Systems talk through these instead of holding references to each other,
## so any of them can be absent (tests, menus) without breaking the rest.

## A sound something could hear. `radius` is how far (metres, open air) it carries before the
## wall/door attenuation applied by listeners. `kind` lets listeners tell a footstep from a gunshot.
signal noise(pos: Vector3, radius: float, kind: String, source: Node)

## The player's inventory changed.
signal inventory_changed

## A toast: a short line of system text (item taken, nothing more). Used sparingly.
signal toast(text: String)

## An interactable changed state (door opened, light switched...). Systems that care (AI
## noticing environmental change, the save system) listen to this.
signal world_changed(thing: Node, what: String)

## The player was caught by a hunter.
signal player_caught(by: Node)

## Ask the UI to show a document / inspection / inventory.
signal show_document(doc_id: String)
signal open_inventory
signal ui_closed

## The chapter director moved to a new beat.
signal beat(name: String)

## Level loaded and ready (name)
signal level_ready(name: String)

## Request a level change (from triggers inside levels); main.gd handles it.
signal request_level(name: String, spawn: String)
