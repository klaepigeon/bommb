class_name EconomyManager
extends RefCounted
## TEETH, the spendable currency: earned from squares, minigame placings, battles, events,
## gambling, the facility, stealing and each other; spent in the shops, on wagers, tolls,
## bribes, gambling and other people. Every Tooth in and out goes through here, so it's
## counted (stats for the Caller's Awards, and the economy report the tests print).
## DEAD RATS (the score) are MatchCore.change_rats; the Dead Rat on the board is bought here.

var core: MatchCore
var house_pile := 30        # what's on the table to be palmed
var gamble_odds := 0.5
var flow := {"earned": 0, "spent": 0, "lost": 0}   # the whole match, for the report


func _init(c: MatchCore) -> void:
	core = c
	gamble_odds = float(Assets.load_json("res://assets/data/shop.json").get("gamble_odds", 0.5))


## A reward. The Cage can shrink it.
func award(seat: int, n: int, why: String, cageable := true) -> int:
	if n <= 0:
		return 0
	if cageable and core.cage.tip(seat, "rewards"):
		n = maxi(1, n / 2)
	var p := core.p(seat)
	p.teeth += n
	p.stat("teeth_earned", n)
	flow.earned += n
	core.emit({"e": "teeth", "seat": seat, "delta": n, "why": why})
	return n


## Spending: all or nothing.
func charge(seat: int, n: int, why: String) -> bool:
	var p := core.p(seat)
	if n <= 0:
		return true
	if p.teeth < n:
		return false
	p.teeth -= n
	p.stat("teeth_spent", n)
	flow.spent += n
	core.emit({"e": "teeth", "seat": seat, "delta": -n, "why": why})
	return true


## Losing: as much as they have.
func take(seat: int, n: int, why: String) -> int:
	var p := core.p(seat)
	var k := mini(n, p.teeth)
	if k <= 0:
		return 0
	p.teeth -= k
	p.stat("teeth_lost", k)
	flow.lost += k
	core.emit({"e": "teeth", "seat": seat, "delta": -k, "why": why})
	if k >= 5:
		core.items.claim_insurance(seat, "lost %d Teeth" % k)
	return k


## From one player to another (gifts, theft, debts, wagers).
func transfer(from: int, to: int, n: int, why: String) -> int:
	var k := mini(n, core.p(from).teeth)
	if k <= 0:
		return 0
	core.p(from).teeth -= k
	core.p(to).teeth += k
	core.emit({"e": "teeth", "seat": from, "delta": -k, "why": why})
	core.emit({"e": "teeth", "seat": to, "delta": k, "why": why})
	return k


func resurrect_cost() -> int:
	return 1   # one Dead Rat


func rat_price() -> int:
	return maxi(5, core.graph.rat_price + int(core.rulebook.value("rat_delta", 0)))


## Double or nothing. He decides how lucky you are.
func gamble(seat: int, wager: int) -> bool:
	var p := core.p(seat)
	wager = clampi(wager, 1, p.teeth)
	if wager <= 0:
		return false
	var win := core.rng.randf() < gamble_odds
	if win and core.cage.tip(seat, "encounter"):
		win = false
	p.stat("gambles")
	if win:
		award(seat, wager, "gamble", false)
	else:
		charge(seat, wager, "gamble")
		p.stat("gamble_lost", wager)
	core.emit({"e": "gamble", "seat": seat, "wager": wager, "won": win})
	core.say("gamble_win" if win else "gamble_lose", {"name": p.name, "n": wager})
	return win


## Debts: `debtor` owes `creditor` n Teeth.
func add_debt(debtor: int, creditor: int, n: int) -> void:
	var p := core.p(debtor)
	p.debts[creditor] = int(p.debts.get(creditor, 0)) + n
	core.emit({"e": "debt", "seat": debtor, "to": creditor, "n": n})


## Pay what you owe (as much as you can). mult: the debt collector's interest.
func settle(debtor: int, creditor := -1, mult := 1.0) -> int:
	var p := core.p(debtor)
	var paid := 0
	for c in p.debts.keys():
		if creditor >= 0 and c != creditor:
			continue
		var owed := int(ceil(int(p.debts[c]) * mult))
		var k := transfer(debtor, int(c), owed, "debt")
		paid += k
		var left := owed - k
		if left <= 0:
			p.debts.erase(c)
		else:
			p.debts[c] = int(ceil(left / mult))
	return paid
