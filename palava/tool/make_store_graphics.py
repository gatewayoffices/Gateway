"""Draws the Google Play feature graphic (1024 x 500) for StoriStory.

Run from the palava folder:  python3 tool/make_store_graphics.py
Writes store/feature-graphic-1024x500.png.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "assets/fonts"
NAME = "StoriStory"
TAGLINE = "African stories, one minute at a time."
SUBLINE = "Original micro-dramas from Liberia and across Africa"

BACKGROUND = (26, 18, 13)
CREAM = (246, 238, 226)
SECONDARY = (205, 191, 174)
EMBER = (226, 98, 43)
GOLD = (232, 176, 74)

W, H = 1024, 500
S = 3  # draw at 3x, then shrink, for smooth edges


def font(name, size):
    return ImageFont.truetype(str(FONTS / name), int(size * S))


def glow(img, centre, radius, colour, strength):
    layer = Image.new("RGB", img.size, colour)
    mask = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(mask)
    cx, cy = centre
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=strength)
    mask = mask.filter(ImageFilter.GaussianBlur(radius * 0.5))
    return Image.composite(layer, img, mask)


def card(size, top, bottom, title):
    """A vertical episode poster: gradient, soft vignette, play button."""
    w, h = size
    c = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(c)
    for y in range(h):
        t = y / h
        d.line(
            [(0, y), (w, y)],
            fill=tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)),
        )
    c = glow(c, (w * 0.7, h * 0.25), w * 0.6, (255, 214, 160), 70)
    d = ImageDraw.Draw(c)
    # Play button.
    r = w * 0.13
    cx, cy = w / 2, h * 0.45
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(246, 238, 226))
    tri = r * 0.5
    d.polygon(
        [(cx - tri * 0.6, cy - tri), (cx - tri * 0.6, cy + tri), (cx + tri, cy)],
        fill=BACKGROUND,
    )
    # Title and progress line at the bottom.
    f = font("Fraunces-SemiBold.ttf", 14)
    d.text((w * 0.1, h * 0.78), title, font=f, fill=CREAM)
    d.rounded_rectangle(
        [w * 0.1, h * 0.9, w * 0.9, h * 0.9 + 4 * S], radius=2 * S, fill=(90, 70, 58)
    )
    d.rounded_rectangle(
        [w * 0.1, h * 0.9, w * 0.55, h * 0.9 + 4 * S], radius=2 * S, fill=EMBER
    )
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=18 * S, fill=255)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(c, (0, 0), mask)
    return out


def shadow_of(img, blur):
    """A soft shadow, on a canvas padded by [blur] * 3 on every side so the
    blur is never cut off."""
    pad = int(blur * 3)
    alpha = Image.new("L", (img.width + 2 * pad, img.height + 2 * pad), 0)
    alpha.paste(img.split()[-1], (pad, pad))
    alpha = alpha.filter(ImageFilter.GaussianBlur(blur))
    sh = Image.new("RGBA", alpha.size, (0, 0, 0, 0))
    sh.putalpha(alpha.point(lambda a: int(a * 0.5)))
    return sh, pad


def main():
    img = Image.new("RGB", (W * S, H * S), BACKGROUND)
    img = glow(img, (W * S * 0.72, H * S * 0.45), W * S * 0.38, (70, 40, 24), 255)
    img = glow(img, (W * S * 0.2, H * S * 0.4), W * S * 0.3, (48, 30, 20), 200)
    img = img.convert("RGBA")

    # Episode cards on the right, fanned out.
    # (colours, title, tilt, top-left corner); the middle one is drawn last.
    cards = [
        ((122, 33, 20), (40, 18, 12), "Market Queen", 8, (622, 112)),
        ((58, 36, 92), (24, 14, 34), "Sinkor Nights", -8, (818, 112)),
        ((92, 54, 18), (34, 20, 10), "The Returnee", 0, (724, 84)),
    ]
    for top, bottom, title, angle, (x, y) in cards:
        c = card((150 * S, 266 * S), top, bottom, title)
        c = c.rotate(angle, resample=Image.BICUBIC, expand=True)
        sh, pad = shadow_of(c, 22 * S)
        img.alpha_composite(sh, (int(x * S) - pad, int((y + 12) * S) - pad))
        img.alpha_composite(c, (int(x * S), int(y * S)))

    d = ImageDraw.Draw(img)
    # Wordmark: name in cream, full stop in ember.
    big = font("Fraunces-Bold.ttf", 92)
    x, y = 64 * S, 128 * S
    d.text((x, y), NAME, font=big, fill=CREAM)
    nw = d.textlength(NAME, font=big)
    d.text((x + nw, y), ".", font=font("Fraunces-Bold.ttf", 100), fill=EMBER)
    d.text(
        (x + 4 * S, y + 128 * S), TAGLINE, font=font("DMSans-Medium.ttf", 27), fill=CREAM
    )
    d.text(
        (x + 4 * S, y + 172 * S), SUBLINE, font=font("DMSans-Regular.ttf", 19), fill=SECONDARY
    )
    # A short gold rule under the tagline block.
    d.rounded_rectangle(
        [x + 4 * S, y + 222 * S, x + 74 * S, y + 226 * S], radius=2 * S, fill=GOLD
    )

    out = img.convert("RGB").resize((W, H), Image.LANCZOS)
    (ROOT / "store").mkdir(exist_ok=True)
    out.save(ROOT / "store/feature-graphic-1024x500.png")
    print("Feature graphic written.")


if __name__ == "__main__":
    main()
