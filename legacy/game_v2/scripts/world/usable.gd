extends StaticBody3D
## Something solid the crosshair can use (a door leaf, a drawer front, a readable thing): the
## same shape as a Hotspot to the player (`used`, `enabled`, `prompt`).

signal used

var enabled := true
var prompt := "Use"
