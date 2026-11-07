#!/usr/bin/env python3
"""Generates assets/data/murderland.json: the MURDERLAND board (LAST CALL 3 v0.2.5).

Seven districts round a loop, each with its own detour and its own machine, all run from
THE MURDERLAND CONTROL SYSTEM in the middle. Positions are on the table's board, 0..1 in x
(left to right) and y (back to front, the stage end is 0). Every edge can carry a gate:
{"to": id, "gate": name, "when": value}; it's walkable only while that gate is in that
state (BoardGraph.next_of reads graph.gates).
"""
import json, math, os, sys

nodes = []
def node(t, district, pos, **kw):
    n = {"id": len(nodes), "type": t, "district": district, "pos": [round(pos[0], 4), round(pos[1], 4)], "next": []}
    n.update(kw)
    nodes.append(n)
    return n["id"]

# the loop: a rounded rectangle (superellipse) round the middle of the table
def loop_pos(u):
    a = 2 * math.pi * u - math.pi / 2  # u=0 at the front middle (nearest the players)
    c, s = math.cos(a), math.sin(a)
    p = 4.0
    x = math.copysign(abs(c) ** (2 / p), c)
    y = math.copysign(abs(s) ** (2 / p), s)
    return (0.5 + 0.43 * x, 0.5 - 0.40 * y)

DISTRICTS = [
    ("welcome", "THE WELCOME DISTRICT", ["start", "normal", "bonus", "normal", "shop", "normal", "event", "normal", "item", "normal", "bad"]),
    ("woods", "THE WISHING WOODS", ["normal", "signpost", "normal", "hidden", "normal", "item", "bad", "normal", "event", "normal", "minigame"]),
    ("funhouse", "THE FUNHOUSE DISTRICT", ["normal", "bonus", "rotator", "normal", "bad", "duel", "normal", "event", "gamble", "normal", "trap"]),
    ("sunken", "THE SUNKEN KINGDOM", ["normal", "floodgate", "normal", "medical", "normal", "bad", "resurrect", "normal", "poison", "normal", "event"]),
    ("giggleworks", "THE GIGGLEWORKS", ["normal", "switch", "conveyor", "conveyor", "normal", "trap", "shop", "normal", "bad", "battle", "normal"]),
    ("carnival", "THE CARNIVAL OF LAST CHANCES", ["normal", "wheel", "normal", "roulette", "bonus", "normal", "death", "event", "gamble", "normal", "caller"]),
    ("royal", "THE ROYAL DISTRICT", ["normal", "rulebook", "normal", "item", "normal", "control", "bonus", "veto", "normal", "black_market", "normal"]),
]
main = []
per = len(DISTRICTS[0][2])
total = per * len(DISTRICTS)
for di, (did, dname, types) in enumerate(DISTRICTS):
    for k, t in enumerate(types):
        u = (di * per + k) / total
        main.append(node(t, did, loop_pos(u)))
M = len(main)
for i in range(M):
    nodes[main[i]]["next"].append({"to": main[(i + 1) % M]})

def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)

branches = []
def branch(name, district, frm, to, types, side, desc, toll=0, gate=None, when=None, bulge=0.12):
    """A detour from main index frm to main index to: `side` 1 = toward the middle, -1 = out."""
    a = nodes[main[frm]]["pos"]
    b = nodes[main[to]]["pos"]
    mid = lerp(a, b, 0.5)
    cx, cy = 0.5, 0.5
    dx, dy = cx - mid[0], cy - mid[1]
    dl = math.hypot(dx, dy) or 1.0
    ids = []
    for k, t in enumerate(types):
        f = (k + 1) / (len(types) + 1)
        p = lerp(a, b, f)
        off = math.sin(math.pi * f) * bulge * side
        p = (p[0] + dx / dl * off, p[1] + dy / dl * off)
        p = (min(0.97, max(0.03, p[0])), min(0.95, max(0.05, p[1])))
        ids.append(node(t, district, p, branch=name))
    edge = {"to": ids[0]}
    if gate:
        edge["gate"] = gate
        edge["when"] = when
    nodes[main[frm]]["next"].append(edge)
    for k in range(len(ids) - 1):
        nodes[ids[k]]["next"].append({"to": ids[k + 1]})
    nodes[ids[-1]]["next"].append({"to": main[to]})
    if toll:
        nodes[ids[0]]["toll"] = toll
    branches.append({"name": name, "district": district, "from": main[frm], "to": main[to], "ids": ids, "toll": toll,
                     "desc": desc, "gate": gate or "", "when": when or ""})
    return ids

D = {d[0]: i * per for i, d in enumerate(DISTRICTS)}
# A: the ticket booth shortcut (and the parade route is the main road of the district)
branch("THE TICKET BOOTH", "welcome", D["welcome"] + 4, D["welcome"] + 9, ["item", "gamble", "normal"], 1,
       "A queue for tickets. Shorter than the road, and somebody's selling things in it.")
# B: the signpost garden: two ways through the trees, the signposts say which is open
branch("THE MUSHROOM PATH", "woods", D["woods"] + 1, D["woods"] + 6, ["normal", "bonus", "normal", "hidden"], -1,
       "Under the giant mushrooms. Pretty. The signposts decide if it's open.", gate="woods_sign", when="left", bulge=0.07)
branch("THE HOLLOW TRUNK", "woods", D["woods"] + 8, D["woods"] + 10, ["trap", "item"], 1,
       "Through the inside of a tree. Something lives in it.")
# C: the moving attractions: the rotating platform at the funhouse connects to one of two rides
branch("THE MIRROR MAZE", "funhouse", D["funhouse"] + 2, D["funhouse"] + 7, ["event", "normal", "hidden"], 1,
       "In one side of the mirrors. You come out where the platform's pointing.", gate="rotator", when="maze")
branch("THE COASTER", "funhouse", D["funhouse"] + 2, D["funhouse"] + 9, ["normal", "bonus"], -1,
       "Two stops on the roller coaster. Hold on to everything.", gate="rotator", when="coaster", bulge=0.06)
# D: the floodgates: low water opens the river walk, high water floats the boat
branch("THE RIVER WALK", "sunken", D["sunken"] + 1, D["sunken"] + 5, ["normal", "item", "normal"], 1,
       "Along the dry riverbed, past the drowned houses. Only when the water's low.", gate="flood", when="low")
branch("THE FERRY", "sunken", D["sunken"] + 1, D["sunken"] + 8, ["bonus", "normal"], -1,
       "A little boat, when the water's high. Faster than walking.", gate="flood", when="high", bulge=0.06)
# E: the production line (conveyor squares carry you on; the switch reverses them), and the packing room
branch("THE PACKING ROOM", "giggleworks", D["giggleworks"] + 4, D["giggleworks"] + 8, ["trap", "black_market", "normal"], 1,
       "Where the toys get boxed. The black market's in the back. Mind the stamping machine.", toll=4)
# F: the carnival wheel opens the big top
branch("THE BIG TOP", "carnival", D["carnival"] + 1, D["carnival"] + 7, ["bonus", "event", "item", "bonus"], 1,
       "Only open when the Carnival Wheel says so. The best seats in the house.", gate="big_top", when="open")
branch("THE GHOST TRAIN", "carnival", D["carnival"] + 5, D["carnival"] + 9, ["resurrect", "surgery", "normal"], -1,
       "A ride through the dark. The dead ride free.", bulge=0.06)
# G: the royal invitation
branch("THE ROYAL ROAD", "royal", D["royal"] + 2, D["royal"] + 8, ["bonus", "bonus", "item", "normal"], 1,
       "Up the grand staircase to the palace. By invitation only.", gate="royal", when="open")
# the long way round the palace gardens
branch("THE PALACE GARDENS", "royal", D["royal"] + 9, (D["welcome"] + 1) % M, ["normal", "medical", "normal"], -1,
       "Round the hedges and out by the front gate. Quiet. Too quiet.", bulge=0.05)

# the signposts close one way or the other: left sends you under the mushrooms, right keeps the road
nodes[main[D["woods"] + 1]]["next"][0].update({"gate": "woods_sign", "when": "right"})

# the parade route (district A's main road), the conveyors, the Dead Rat's spots
parade = [main[D["welcome"] + k] for k in range(1, 11)]
rat_spots = [main[D[d] + 3] for d in D] + [branches[i]["ids"][1] for i in (3, 9)]
rat_spots = [r for r in rat_spots if nodes[r]["type"] in ("normal", "bonus", "item", "hidden", "medical", "event")]
if len(rat_spots) < 6:
    rat_spots += [main[D[d] + 7] for d in D if nodes[main[D[d] + 7]]["type"] == "normal"]

board = {
    "_comment": "MURDERLAND (generated by tools/make_murderland.py). The robot's miniature theme park on the operating table: seven districts round a loop, a detour in every one, and THE MURDERLAND CONTROL SYSTEM in the middle that runs the machines (gates: woods_sign, rotator, flood, big_top, royal; the conveyors and the parade). Edges with a gate are walkable only while the gate's in that state. pos: where the space is on the board (0..1).",
    "name": "MURDERLAND",
    "format": "graph",
    "rat_price": 20,
    "districts": [{"id": d[0], "name": d[1]} for d in DISTRICTS],
    "gates": {"woods_sign": {"values": ["left", "right"], "start": "left", "name": "THE SIGNPOST GARDEN"},
              "rotator": {"values": ["maze", "coaster"], "start": "maze", "name": "THE ROTATING PLATFORM", "cycle": 1},
              "flood": {"values": ["low", "high"], "start": "low", "name": "THE FLOODGATES"},
              "big_top": {"values": ["shut", "open"], "start": "shut", "name": "THE BIG TOP"},
              "royal": {"values": ["shut", "open"], "start": "shut", "name": "THE ROYAL INVITATION"},
              "conveyor": {"values": ["forward", "back"], "start": "forward", "name": "THE PRODUCTION LINE"}},
    "parade": parade,
    "rat_spots": sorted(set(rat_spots)),
    "nodes": nodes,
    "branches": branches,
    "main_count": M,
    "notes": ["WELCOME TO MURDERLAND! EVERYONE'S HAVING FUN.", "PLEASE KEEP ALL LIMBS INSIDE THE RIDE (WE'LL KEEP THE REST).",
              "LOST CHILDREN WILL BE PROCESSED AT THE GIGGLEWORKS.", "THE PARADE STARTS EVERY ROUND! STAND CLEAR OF THE FLOATS."],
}
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets", "data", "murderland.json")
with open(out, "w") as f:
    json.dump(board, f, indent=1)
print("MURDERLAND:", len(nodes), "spaces,", M, "on the loop,", len(branches), "detours,", len(board["rat_spots"]), "rat spots")
