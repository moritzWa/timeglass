#!/usr/bin/env python3
from pathlib import Path
import subprocess
from PIL import Image
root = Path(__file__).resolve().parent.parent
subprocess.run(["magick", "-background", "none", str(root / "assets/Timeglass.svg"), str(root / "assets/Timeglass.png")], check=True)
iconset = root / "build/Timeglass.iconset"
iconset.mkdir(parents=True, exist_ok=True)
with Image.open(root / "assets/Timeglass.png") as image:
    for size in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            suffix = "@2x" if scale == 2 else ""
            image.resize((size * scale, size * scale), Image.Resampling.LANCZOS).save(iconset / f"icon_{size}x{size}{suffix}.png")
subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(root / "assets/Timeglass.icns")], check=True)
