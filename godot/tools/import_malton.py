"""Import the archived Urban Dead Wiki coordinate map; no third-party packages.

Usage: python tools/import_malton.py --input PATH/TO/map.html --suburbs PATH/TO/suburbs.txt
The output contains factual geography, not Wiki descriptions or group annotations.
"""
import argparse
import hashlib
import html
import json
import re
from collections import Counter
from pathlib import Path

SOURCE_COMMIT = "2392369bac6a20e3ea88a912289dc1926f2cd3a0"
SOURCE_URL = f"https://github.com/IFTClerk/urbandead_map/blob/{SOURCE_COMMIT}/map.html"
COLORS = {
    "#545454": "street", "#DDF": "police_department", "white": "church",
    "#9C9": "park", "#666": "carpark", "#EEE": "tower", "#888": "railway_station",
    "#876": "pub", "#AAD": "office", "#AAA": "factory", "#DDD": "cinema",
    "#898": "museum", "#765": "wasteland", "#C94": "hotel", "#C9C": "nightclub",
    "#CCC": "auto_repair", "#DED": "bank", "#FDD": "fire_station", "#F99": "hospital",
    "#987": "warehouse", "#899": "school", "#EEF": "mall", "#965": "zoo_ground",
    "#999": "storehouse", "#797": "training_ground", "#373": "vehicle_depot",
}


def convert(map_text, suburb_text):
    suburbs = re.findall(r'href="/index.php/([^"]+)"', suburb_text)
    assert len(suburbs) == 100, f"Expected 100 suburb names, got {len(suburbs)}"
    suburbs = [html.unescape(name.replace("_", " ")) for name in suburbs]
    rows = re.findall(r'<tr style="height:10%">(.*?)</tr>', map_text, re.S)
    assert len(rows) == 100, f"Expected 100 rows, got {len(rows)}"
    blocks = []
    for y, row in enumerate(rows):
        cells = re.findall(r'<td style="([^"]*)">(.*?)</td>', row, re.S)
        assert len(cells) == 100, f"Row {y} has {len(cells)} cells"
        for x, (style, content) in enumerate(cells):
            # EP/RP/MPM are later player annotations, not place-name components.
            name = " ".join(html.unescape(re.sub(r"<[^>]+>", " ", content)).split())
            name = re.sub(r"\s+(?:EP|RP|MPM|TRP)$", "", name)
            assert name, f"Missing place name at {x},{y}"
            color = re.search(r"background:([^;]+)", style).group(1)
            kind = COLORS[color]
            lower = name.lower()
            if "border:3px solid #D13" in style:
                kind = "necrotech_lab"
            elif "border:5px solid #9C9" in style and color == "#EEE":
                kind = "library"
            elif "border:5px solid #DDD" in style and color == "#9C9":
                kind = "cemetery"
            elif "border:2px dotted" in style and color == "#765":
                kind = "junkyard"
            elif "monument" in lower:
                kind = "monument"
            elif "cathedral" in lower:
                kind = "cathedral"
            elif "mansion" in lower:
                kind = "mansion"
            elif "stadium" in lower:
                kind = "stadium"
            elif "power station" in lower:
                kind = "power_station"
            block = {"id": y * 100 + x, "x": x, "y": y, "type": kind, "name": name,
                     "suburb": suburbs[(y // 10) * 10 + x // 10]}
            if lower.startswith("fort creedy") or lower.startswith("fort perryn"):
                block["fort"] = "Fort Creedy" if lower.startswith("fort creedy") else "Fort Perryn"
                for part in ["infirmary", "armoury", "storehouse", "barracks", "gatehouse", "exercise yard", "training ground", "vehicle depot"]:
                    if part in lower:
                        block["type"] = part.replace(" ", "_")
                        break
                else:
                    raise ValueError(f"Unrecognised fort component: {name}")
            elif color == "#965":
                block.update(zoo="Malton Zoo", complex="Malton Zoo", unbarricadable=True)
                for part in ["aquarium", "bear pit", "elephant house", "giraffe house", "lion enclosure", "reptile house"]:
                    if part in lower:
                        block["type"] = part.replace(" ", "_")
                        break
                block["unbarricadable"] = block["type"] == "zoo_ground"
            elif kind in ["mall", "mansion", "cathedral", "stadium", "power_station"]:
                block["complex"] = name
            blocks.append(block)
    return blocks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--suburbs", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "assets/maps/malton.json")
    args = parser.parse_args()
    raw = args.input.read_bytes()
    blocks = convert(raw.decode("utf-8"), args.suburbs.read_text(encoding="utf-8"))
    malls = Counter(b.get("complex") for b in blocks if b["type"] == "mall")
    forts = Counter(b.get("fort") for b in blocks if "fort" in b)
    assert len(malls) == 20 and sorted(malls.values()) == [2, 3] + [4] * 18, malls
    assert forts == {"Fort Creedy": 9, "Fort Perryn": 9}, forts
    assert sum(b.get("zoo") == "Malton Zoo" for b in blocks) == 20
    mast_file = Path(__file__).resolve().parents[1] / "assets/maps/malton-masts.json"
    masts = json.loads(mast_file.read_text(encoding="utf-8"))
    for x, y in masts["coordinates"]:
        blocks[y*100+x]["mast"] = True
    result = {"version": 1, "width": 100, "height": 100,
              "source": {"url": SOURCE_URL, "commit": SOURCE_COMMIT,
                         "sha256": hashlib.sha256(raw).hexdigest(),
                         "derived_from": "Urban Dead Wiki suburb map tables",
                         "phone_masts": masts["source"], "mast_notes": masts["notes"],
                         "wiki": "https://wiki.urbandead.com/index.php/Suburb",
                         "notes": "Player EP/RP/MPM/TRP labels removed. Original block names, coordinates and map-category markers retained. Live barricades, mast symbols and power states were not included in the archive."},
              "blocks": blocks}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"Imported {len(blocks)} squares, 100 suburbs, {len(malls)} malls, {len(forts)} forts and one zoo.")
    print("Building categories:", dict(Counter(b["type"] for b in blocks)))


if __name__ == "__main__":
    main()
