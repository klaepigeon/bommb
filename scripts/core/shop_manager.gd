class_name ShopManager
extends RefCounted
## The shops (assets/data/shop.json): the tuck shop (general), the black market, the
## infirmary (medical) and the ghost shop. Each restocks at the start of every round from
## its pool (weighted by rarity, limited quantities, one item on special). What you pay
## depends on the shop, the amendments and your Cage: he charges the ones he's caged more.
## Black market stock can be stolen (a cheat); a coupon opens the stock under the counter.

var core: MatchCore
var data: Dictionary = {}
var stock: Dictionary = {}       # shop -> [{id, price, qty, special}]


func _init(c: MatchCore) -> void:
	core = c
	data = Assets.load_json("res://assets/data/shop.json")


func shops() -> Dictionary:
	return data.get("shops", {})


func name_of(shop: String) -> String:
	return str(shops().get(shop, {}).get("name", shop.to_upper()))


func restock() -> void:
	var rw: Dictionary = data.get("rarity_weight", {})
	for sid in shops().keys():
		var sh: Dictionary = shops()[sid]
		var pool: Array = (sh.get("pool", []) as Array).duplicate()
		var picked := []
		var slots := mini(int(sh.get("slots", 4)), pool.size())
		while picked.size() < slots:
			var total := 0
			for id in pool:
				total += int(rw.get(str(Items.def(id).get("rarity", "common")), 1))
			var r := core.rng.randi_range(0, maxi(0, total - 1))
			for id in pool:
				r -= int(rw.get(str(Items.def(id).get("rarity", "common")), 1))
				if r < 0:
					picked.append(id)
					pool.erase(id)
					break
		picked.sort()
		var lst := []
		var special := core.rng.randi_range(0, maxi(0, picked.size() - 1))
		for i in picked.size():
			var base := int(round(Items.price_of(picked[i]) * float(sh.get("mult", 1.0))))
			if i == special:
				base = maxi(1, base / 2)
			lst.append({"id": picked[i], "base": base, "qty": int(sh.get("qty", 2)), "special": i == special})
		stock[sid] = lst
	core.emit({"e": "restock"})


## What it costs this player right now.
func price(seat: int, shop: String, id: String, coupon := false) -> int:
	var e := entry(shop, id, coupon)
	if e.is_empty():
		return -1
	var p := float(e.base) * float(core.rulebook.value("price_mult", 1.0, seat))
	p *= 1.0 + float(data.get("cage_tax", 0.12)) * core.p(seat).cage
	if coupon:
		p *= 0.5
	return maxi(1, int(round(p)))


func entry(shop: String, id: String, coupon := false) -> Dictionary:
	for e in stock.get(shop, []):
		if e.id == id:
			return e
	if coupon and shop == "black_market" and (shops().black_market.get("under_counter", []) as Array).has(id):
		return {"id": id, "base": Items.price_of(id), "qty": 1, "special": false, "under": true}
	return {}


## The shelf as this player sees it: [{id, name, desc, price, qty, special, can}].
func shelf(seat: int, shop: String, coupon := false) -> Array:
	var out := []
	var lst: Array = stock.get(shop, []).duplicate()
	if coupon and shop == "black_market":
		for id in shops().black_market.get("under_counter", []):
			lst.append({"id": id, "base": Items.price_of(id), "qty": 1, "special": false, "under": true})
	for e in lst:
		var pr := price(seat, shop, e.id, coupon)
		out.append({"id": e.id, "name": Items.name_of(e.id), "desc": Items.desc_of(e.id), "price": pr, "qty": int(e.qty),
			"special": e.get("special", false), "under": e.get("under", false), "rarity": str(Items.def(e.id).get("rarity", "")),
			"can": int(e.qty) > 0 and core.p(seat).teeth >= pr and core.p(seat).items.size() < Items.MAX_HELD})
	return out


func buy(seat: int, shop: String, id: String, coupon := false) -> bool:
	var p := core.p(seat)
	var e := entry(shop, id, coupon)
	if e.is_empty() or int(e.qty) <= 0:
		core.toast("Sold out.", seat)
		return false
	if p.items.size() >= Items.MAX_HELD:
		core.toast("Your pockets are full (three things).", seat)
		return false
	# the Caller's thumb on the till
	if p.cage >= 3 and core.cage.tip(seat, "items"):
		core.toast("The shopkeeper looks at the stage, then at you. \"Not for you.\"", seat)
		core.say("shop_refused", {"name": p.name})
		return false
	var pr := price(seat, shop, id, coupon)
	if not core.economy.charge(seat, pr, "bought " + id):
		core.toast("You can't afford it (%d Teeth)." % pr, seat)
		return false
	e.qty = int(e.qty) - 1
	p.stat("items_bought")
	core.give_item(seat, id, shop)
	core.emit({"e": "buy", "seat": seat, "shop": shop, "item": id, "price": pr})
	core.say("shop_buy", {"name": p.name, "item": Items.name_of(id)})
	return true


## Shoplifting (the black market only; a cheat).
func steal(seat: int, shop: String, id: String) -> bool:
	var e := entry(shop, id)
	if e.is_empty() or int(e.qty) <= 0 or core.p(seat).items.size() >= Items.MAX_HELD:
		return false
	if not core.cheats.attempt(seat, "shoplift", "pocket a " + Items.name_of(id).to_lower()):
		core.economy.take(seat, 5, "caught shoplifting")
		return false
	e.qty = int(e.qty) - 1
	core.p(seat).stat("steals")
	core.give_item(seat, id, "stolen")
	return true


func to_save() -> Dictionary:
	return stock.duplicate(true)


func load_save(d: Dictionary) -> void:
	stock = d.duplicate(true)
	for k in stock.keys():
		for e in stock[k]:
			e.qty = int(e.qty)
			e.base = int(e.base)
