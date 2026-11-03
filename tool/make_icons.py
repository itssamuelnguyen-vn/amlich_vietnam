"""Generates the Android launcher icons from tool/icon/logo.png.

Usage (needs Pillow):  python tool/make_icons.py [path/to/logo.png]

The logo is trimmed to its content, centred and scaled so that even a circular mask keeps all of it:
- mipmap-*/ic_launcher.png             legacy square icon (Android 7.x), white rounded square
- mipmap-*/ic_launcher_foreground.png  adaptive icon foreground (Android 8+), on a white background colour
- mipmap-*/ic_launcher_monochrome.png  themed icon (Android 13+): the logo's shape in white
"""
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android" / "app" / "src" / "main" / "res"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

# Adaptive icons are 108 dp with a 66 dp safe circle: keep every drawn pixel within a circle of ~60 % of the canvas.
SAFE_DIAMETER = 0.60
# Legacy icons are drawn edge to edge: content takes ~80 % of the width.
LEGACY_WIDTH = 0.80


def white_to_alpha(img: Image.Image) -> Image.Image:
    """Turns the white background transparent, keeping anti-aliased edges exact over white ("colour to alpha")."""
    rgb = img.convert("RGB")
    r, g, b = rgb.split()
    alpha = ImageChops.invert(ImageChops.darker(ImageChops.darker(r, g), b))  # 255 - min(r, g, b)

    def unmix(channel: Image.Image) -> Image.Image:
        # c' = 255 - (255 - c) * 255 / alpha
        out = Image.new("L", channel.size)
        c, a, o = channel.load(), alpha.load(), out.load()
        for y in range(channel.size[1]):
            for x in range(channel.size[0]):
                av = a[x, y]
                o[x, y] = 0 if av == 0 else max(0, min(255, round(255 - (255 - c[x, y]) * 255 / av)))
        return out

    return Image.merge("RGBA", (unmix(r), unmix(g), unmix(b), alpha))


def trimmed(path: Path) -> Image.Image:
    img = Image.open(path).convert("RGBA")
    # Composite on white first so transparent and white backgrounds are treated alike.
    flat = Image.alpha_composite(Image.new("RGBA", img.size, "white"), img).convert("RGB")
    ink = ImageChops.invert(flat).convert("L").point(lambda v: 255 if v > 12 else 0)
    box = ink.getbbox()
    if box is None:
        sys.exit("The logo is blank")
    return white_to_alpha(flat.crop(box))


def place(content: Image.Image, size: int, width: int) -> Image.Image:
    w, h = content.size
    scaled = content.resize((width, round(h * width / w)), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, ((size - scaled.width) // 2, (size - scaled.height) // 2))
    return canvas


def adaptive_width(content: Image.Image, size: int) -> int:
    """Width that keeps the farthest drawn pixel (not just the bounding box corner) inside the safe circle."""
    w, h = content.size
    small = content.getchannel("A").resize((max(1, w // 8), max(1, h // 8)))
    sw, sh = small.size
    px = small.load()
    farthest = max(
        (((x + 0.5) / sw - 0.5) * w) ** 2 + (((y + 0.5) / sh - 0.5) * h) ** 2
        for y in range(sh)
        for x in range(sw)
        if px[x, y] > 40
    ) ** 0.5
    return round(w * (SAFE_DIAMETER * size / 2) / farthest)


def main() -> None:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "tool" / "icon" / "logo.png"
    content = trimmed(src)
    for name, scale in DENSITIES.items():
        folder = RES / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)

        size = round(108 * scale)
        fg = place(content, size, adaptive_width(content, size))
        fg.save(folder / "ic_launcher_foreground.png", optimize=True)
        mono = Image.new("RGBA", fg.size, (255, 255, 255, 0))
        mono.putalpha(fg.getchannel("A").point(lambda v: 255 if v > 90 else 0))
        mono.save(folder / "ic_launcher_monochrome.png", optimize=True)

        # Legacy: drawn 4x larger then reduced, for smooth rounded corners.
        size = round(48 * scale)
        big = size * 4
        legacy = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        ImageDraw.Draw(legacy).rounded_rectangle((0, 0, big - 1, big - 1), radius=round(big * 0.22), fill="white")
        legacy.alpha_composite(place(content, big, round(big * LEGACY_WIDTH)))
        legacy.resize((size, size), Image.LANCZOS).save(folder / "ic_launcher.png", optimize=True)
        print(f"mipmap-{name}: {round(108 * scale)} / {size} px")


if __name__ == "__main__":
    main()
