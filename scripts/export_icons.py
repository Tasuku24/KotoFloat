import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Design/AppIcon/KotoFloat-Graphite.vectorcraft"
CATALOG = ROOT / "App/Assets.xcassets"
MENU_ICON = ROOT / "Sources/KotoFloatKit/Resources/MenuBarIcon.pdf"
SVG = "http://www.w3.org/2000/svg"


def convert(cli, source, target, scale=None):
    command = [str(cli), "convert", str(source), str(target)]
    if scale is not None:
        command += ["--scale", str(scale)]
    result = json.loads(subprocess.check_output(command, text=True))
    if result.get("warnings") or result.get("importWarnings"):
        raise RuntimeError(result)


def main():
    parser = argparse.ArgumentParser(
        description="Export the app and menu bar icons. / アプリとメニューバーのアイコンを出力します。"
    )
    parser.add_argument("--vectorcraft-cli", required=True, type=Path)
    args = parser.parse_args()
    iconset = CATALOG / "AppIcon.appiconset"
    iconset.mkdir(parents=True, exist_ok=True)
    info = {"info": {"author": "xcode", "version": 1}}
    (CATALOG / "Contents.json").write_text(json.dumps(info, indent=2) + "\n")

    with tempfile.TemporaryDirectory(prefix="kotofloat-icons-") as folder:
        temporary = Path(folder)
        for pixels in [16, 32, 64, 128, 256, 512, 1024]:
            convert(args.vectorcraft_cli, SOURCE, temporary / f"{pixels}.png", pixels / 1024)
        images = []
        for size in [16, 32, 128, 256, 512]:
            for scale in [1, 2]:
                filename = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
                shutil.copyfile(temporary / f"{size * scale}.png", iconset / filename)
                images.append({"filename": filename, "idiom": "mac", "size": f"{size}x{size}", "scale": f"{scale}x"})
        (iconset / "Contents.json").write_text(json.dumps({"images": images, **info}, indent=2) + "\n")

        artwork = temporary / "artwork.svg"
        convert(args.vectorcraft_cli, SOURCE, artwork)
        paths = [node for node in ET.parse(artwork).iter(f"{{{SVG}}}path")
                 if node.get("data-name") in {
                     "K stem and lower arm / Kの縦線と下腕 · bevel / 面取り",
                     "Detached upper arm / 離れた上腕 · bevel / 面取り",
                 }]
        if len(paths) != 2:
            raise ValueError("Expected two K outlines. / Kの輪郭が2つ必要です。")
        ET.register_namespace("", SVG)
        svg = ET.Element(f"{{{SVG}}}svg", {"width": "18", "height": "18", "viewBox": "0 0 18 18"})
        group = ET.SubElement(svg, f"{{{SVG}}}g", {
            "transform": "translate(2.216216216216216 1) scale(0.02702702702702703) translate(-277 -224)"
        })
        for path in paths:
            ET.SubElement(group, f"{{{SVG}}}path", {"d": path.attrib["d"], "fill": "#000000"})
        silhouette = temporary / "MenuBarIcon.svg"
        ET.ElementTree(svg).write(silhouette, encoding="utf-8", xml_declaration=True)
        convert(args.vectorcraft_cli, silhouette, MENU_ICON)


if __name__ == "__main__":
    main()
