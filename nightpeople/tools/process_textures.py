#!/usr/bin/env python3
"""Turn ambientCG 1K colour maps into the game's PS1-style textures.

Usage: python3 -I tools/process_textures.py SOURCE_DIR
SOURCE_DIR holds one folder per ambientCG asset id, each containing its *_Color.jpg
(download the "1K-JPG" zip from https://ambientcg.com/view?id=<ID>; all ambientCG assets are CC0).
Output: assets/textures/ambientcg/<name>.png — 128x128 (64 for small detail), box-filtered,
slightly desaturated and darkened, reduced to a 48-colour palette. The mapping below is the
single source of truth for which ambientCG asset becomes which game texture.
"""
import glob, os, sys
from PIL import Image, ImageEnhance

MAP = {
    "brick_red": "Bricks090", "brick_dirty": "Bricks097", "brick_yellow": "Bricks094",
    "asphalt": "Asphalt031", "road": "Road007", "tar_roof": "Asphalt033",
    "sidewalk": "Concrete034", "concrete_dirty": "Concrete031", "concrete_stain": "Concrete042C",
    "plaster_stained": "PaintedPlaster006", "plaster": "PaintedPlaster017",
    "wallpaper_peeling": "Wallpaper001C", "wallpaper_plain": "Wallpaper002A",
    "wood_floor": "WoodFloor051", "wood_floor_dark": "WoodFloor043", "planks": "Planks023A",
    "tile_white": "Tiles107", "tile_dark": "Tiles138", "carpet": "Carpet016",
    "shutter": "CorrugatedSteel005", "rust": "Rust009", "metal_worn": "Metal041B",
    "diamond_plate": "DiamondPlate008A", "fabric": "Fabric061",
}

def main(src: str) -> None:
    out = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "ambientcg")
    os.makedirs(out, exist_ok=True)
    for name, aid in MAP.items():
        files = glob.glob(os.path.join(src, aid, "*Color*.jpg"))
        if not files:
            print("missing", aid); continue
        im = Image.open(files[0]).convert("RGB").resize((128, 128), Image.BOX)
        im = ImageEnhance.Color(im).enhance(0.8)
        im = ImageEnhance.Brightness(im).enhance(0.9)
        im = im.quantize(48, method=Image.Quantize.MEDIANCUT).convert("RGB")
        im.save(os.path.join(out, name + ".png"), optimize=True)
        print(name, "<-", aid)

if __name__ == "__main__":
    main(sys.argv[1])
