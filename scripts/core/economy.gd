class_name EconomyManager
extends RefCounted
## Dead Rats: the collectible (what Mario Party calls stars) and the money. Earned from
## games, squares, the room, gambling, other people, and (for ghosts) scavenging; spent on
## the black market, medicine, limbs, and coming back from the dead. Prices and odds:
## assets/data/shop.json.

var core: MatchCore
var shop: Dictionary = {}
var house_pile := 30        # what's on the table to be palmed


func _init(c: MatchCore) -> void:
	core = c
	shop = Assets.load_json("res://assets/data/shop.json")


func resurrect_cost() -> int:
	return int(shop.get("resurrect_cost", 10))


## A reward. The Cage can shrink it.
func award(seat: int, n: int, why: String) -> int:
	if n <= 0:
		return 0
	if core.cage.tip(seat, "rewards"):
		n = maxi(1, n / 2)
	core.p(seat).rats += n
	core.emit({"e": "rats", "seat": seat, "delta": n, "why": why})
	return n


func charge(seat: int, n: int, why: String) -> bool:
	var p := core.p(seat)
	if p.rats < n:
		return false
	p.rats -= n
	core.emit({"e": "rats", "seat": seat, "delta": -n, "why": why})
	return true


func take(seat: int, n: int, why: String) -> int:
	var p := core.p(seat)
	var k := mini(n, p.rats)
	p.rats -= k
	if k > 0:
		core.emit({"e": "rats", "seat": seat, "delta": -k, "why": why})
	return k


func prices(which: String) -> Dictionary:
	return shop.get(which, {})


func buy(seat: int, item: String, which: String) -> bool:
	var price: int = int(prices(which).get(item, -1))
	if price < 0 or core.p(seat).items.size() >= Items.MAX_HELD:
		return false
	if not charge(seat, price, "bought " + item):
		core.toast("You can't afford it.", seat)
		return false
	core.give_item(seat, item, which)
	return true


## Double or nothing. He decides how lucky you are.
func gamble(seat: int, wager: int) -> bool:
	var p := core.p(seat)
	wager = clampi(wager, 1, p.rats)
	if wager <= 0:
		return false
	var win := core.rng.randf() < float(shop.get("gamble_odds", 0.5))
	if win and core.cage.tip(seat, "encounter"):
		win = false
	if win:
		p.rats += wager
	else:
		p.rats -= wager
	core.emit({"e": "gamble", "seat": seat, "wager": wager, "won": win})
	core.say("gamble_win" if win else "gamble_lose", {"name": p.name, "n": wager})
	return win
