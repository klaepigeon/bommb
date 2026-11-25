#!/usr/bin/env python3
"""Regenerate ASSET_CREDITS.md from data/asset_registry.json (the single source of truth).
Usage: python3 -I tools/credits.py"""
import json, os
root = os.path.join(os.path.dirname(__file__), "..")
reg = json.load(open(os.path.join(root, "data", "asset_registry.json")))
used = {}
for kind in ("props", "characters"):
    for k, v in reg[kind].items():
        used.setdefault(v["pack"], []).append(k)
used["ambientcg"] = ["(24 textures — see tools/process_textures.py MAP)"]
out = ["# NIGHT PEOPLE — Third-party asset credits", "",
       "Generated from `data/asset_registry.json` by `tools/credits.py`. Do not edit by hand: edit the",
       "registry and re-run. Every external asset in the game is listed here with its verified licence.", "",
       "All assets currently used are **CC0 1.0 (public domain dedication)**: no attribution is legally",
       "required, commercial use and modification are permitted. We credit the creators anyway.", ""]
for pid, p in reg["packs"].items():
    out += [f"## {p['name']}", "",
            f"| | |", "|---|---|",
            f"| Creator | {p['creator']} |", f"| Source | {p['source']} |", f"| Licence | {p['license']} |",
            f"| Attribution required | {'yes' if p['attribution_required'] else 'no (given voluntarily)'} |",
            f"| Modification permitted | {'yes' if p['modification'] else 'no'} |",
            f"| Commercial use permitted | {'yes' if p['commercial'] else 'no'} |",
            f"| Acquired | {p['acquired']} |", f"| Location | `{p['path']}` |",
            f"| Notes | {p['notes']} |",
            f"| Used | {', '.join(sorted(used.get(pid, [])))} |", ""]
out += ["## Original work", "",
        "Everything else (code, shaders, the generated architecture, level and character data, writing) is",
        "original to this project.", ""]
open(os.path.join(root, "ASSET_CREDITS.md"), "w").write("\n".join(out))
print("wrote ASSET_CREDITS.md")
