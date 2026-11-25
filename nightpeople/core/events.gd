extends Node
## Global event bus. Gameplay systems announce things here; listeners (HUD, memory, crime,
## later the network layer) subscribe. Nothing here holds state.

## Something happened that people could notice. `data` carries at least: kind, actor (Node),
## position (Vector3), place (String id, may be ""). See simulation/perception.gd for kinds.
signal world_event(data: Dictionary)
## A short line spoken out loud by someone (NPC barks, the player's character).
signal bark(speaker: String, text: String, from: Node3D)
## Something the player should be told (HUD toast).
signal notice(text: String)
## Text to show full-screen (notes, letters, books).
signal read(title: String, text: String)
