"""Draws the StoriStory app icon in every size Android, iOS and Google Play
need.

The icon is the logo's Fraunces "S" in cream with the ember full stop, on the
fireside background. Run from the palava folder:

    python3 tool/make_icons.py

Needs Python 3 with Pillow (pip install pillow).
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / "assets/fonts/Fraunces-Bold.ttf"
LETTER = "S"  # first letter of the app name

BACKGROUND = (26, 18, 13)  # #1A120D
GLOW = (61, 36, 22)  # warm centre
CREAM = (246, 238, 226)  # #F6EEE2
EMBER = (226, 98, 43)  # #E2622B


def background(size):
    """Fireside background: a soft warm glow in the middle."""
    img = Image.new("RGB", (size, size), BACKGROUND)
    glow = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(glow)
    steps = 60
    for i in range(steps):
        r = size * (0.75 - 0.6 * i / steps)
        d.ellipse(
            [size * 0.5 - r, size * 0.42 - r, size * 0.5 + r, size * 0.42 + r],
            fill=int(255 * i / steps),
        )
    warm = Image.new("RGB", (size, size), GLOW)
    return Image.composite(warm, img, glow)


def mark(size, scale, colour_p=CREAM, colour_dot=EMBER):
    """The letter-and-dot mark on a transparent square, filling [scale] of
    its width."""
    big = size * 4  # draw large, then shrink, for smooth edges
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    font = ImageFont.truetype(str(FONT), int(big * 0.9))
    left, top, right, bottom = d.textbbox((0, 0), LETTER, font=font)
    p_w, p_h = right - left, bottom - top
    dot = p_h * 0.22
    gap = p_h * 0.04
    total_w = p_w + gap + dot
    target = big * scale
    k = target / max(total_w, p_h)
    font = ImageFont.truetype(str(FONT), int(big * 0.9 * k))
    left, top, right, bottom = d.textbbox((0, 0), LETTER, font=font)
    p_w, p_h = right - left, bottom - top
    dot, gap = p_h * 0.22, p_h * 0.04
    total_w = p_w + gap + dot
    x0 = (big - total_w) / 2
    y0 = (big - p_h) / 2
    d.text((x0 - left, y0 - top), LETTER, font=font, fill=colour_p)
    dx = x0 + p_w + gap
    dy = y0 + p_h - dot
    d.ellipse([dx, dy, dx + dot, dy + dot], fill=colour_dot)
    return layer.resize((size, size), Image.LANCZOS)


def full_icon(size, scale=0.56):
    img = background(size).convert("RGBA")
    img.alpha_composite(mark(size, scale))
    return img


def rounded(img, radius_ratio=0.22):
    size = img.size[0]
    m = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, size * 4 - 1, size * 4 - 1], radius=int(size * 4 * radius_ratio), fill=255
    )
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), m.resize(img.size, Image.LANCZOS))
    return out


def main():
    res = ROOT / "android/app/src/main/res"
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, f in densities.items():
        folder = res / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        # Older Android: a ready-made rounded square, 48dp.
        rounded(full_icon(int(48 * f))).save(folder / "ic_launcher.png")
        # Android 8+: layers the phone shapes itself, 108dp. The mark stays
        # inside the 66dp safe zone in the middle.
        layer = int(108 * f)
        mark(layer, 0.42).save(folder / "ic_launcher_foreground.png")
        background(layer).save(folder / "ic_launcher_background.png")
        # Android 13+ themed icons: one colour, the phone tints it.
        mark(layer, 0.42, colour_p=(255, 255, 255), colour_dot=(255, 255, 255)).save(
            folder / "ic_launcher_monochrome.png"
        )
        # Start-up screen picture (Android 7 to 11), 96dp.
        drawable = res / f"drawable-{name}"
        drawable.mkdir(parents=True, exist_ok=True)
        rounded(full_icon(int(96 * f))).save(drawable / "splash_icon.png")

    # iOS: square, no transparency (iOS rounds the corners itself).
    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    master = full_icon(1024).convert("RGB")
    for png in ios.glob("Icon-App-*.png"):
        dims = png.stem.split("-")[-1]  # e.g. 20x20@2x
        points, scale = dims.split("@")
        px = round(float(points.split("x")[0]) * int(scale.rstrip("x")))
        master.resize((px, px), Image.LANCZOS).save(png)

    # Google Play listing: 512 x 512, square (Play rounds it).
    store = ROOT / "store"
    store.mkdir(exist_ok=True)
    master.resize((512, 512), Image.LANCZOS).save(store / "play-icon-512.png")
    # Admin panel and app favicons.
    for web in [ROOT / "web", ROOT / "admin/web"]:
        if (web / "favicon.png").exists():
            rounded(full_icon(64)).save(web / "favicon.png")
        icons = web / "icons"
        if icons.exists():
            for png in icons.glob("Icon-*.png"):
                px = int("".join(c for c in png.stem.split("-")[-1] if c.isdigit()))
                img = full_icon(px, 0.42 if "maskable" in png.stem else 0.56)
                img.convert("RGB").save(png)
    print("Icons written.")


if __name__ == "__main__":
    main()
