"""Builds the README images in docs/images from the widget's own renders.

Run from the project root (needs Pillow):
    PREVIEW_OUT=/tmp/previews flutter test tool/preview_test.dart
    python3 tool/make_screenshots.py /tmp/previews
"""
import sys

from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else "/tmp/previews"
OUT = "docs/images"


def gradient(size, stops):
    """Diagonal gradient through the given RGB stops."""
    w, h = size
    small = Image.new("RGB", (64, 64))
    px = small.load()
    for y in range(64):
        for x in range(64):
            t = (x + y) / 126 * (len(stops) - 1)
            i = min(int(t), len(stops) - 2)
            f = t - i
            px[x, y] = tuple(
                round(stops[i][c] + (stops[i + 1][c] - stops[i][c]) * f)
                for c in range(3)
            )
    return small.resize((w, h), Image.BICUBIC).convert("RGBA")


def load(name, theme):
    return Image.open(f"{SRC}/{name}_{theme}_clear.png").convert("RGBA")


def compose(path, size, stops, items):
    canvas = gradient(size, stops)
    for image, (x, y) in items:
        canvas.alpha_composite(image, (x, y))
    canvas.convert("RGB").save(path, optimize=True)
    print(path, canvas.size)


WALL = [(43, 92, 138), (155, 74, 122), (227, 154, 76)]

compose(
    f"{OUT}/hero.png",
    (1880, 780),
    WALL,
    [
        (load("pill", "dark"), (104, 80)),
        (load("details", "dark"), (40, 270)),
        (load("menu", "dark"), (644, 80)),
        (load("pill_high", "light"), (1312, 80)),
        (load("details", "light"), (1248, 270)),
    ],
)
compose(
    f"{OUT}/themes.png",
    (1320, 520),
    WALL,
    [(load("details", "dark"), (60, 40)), (load("details", "light"), (700, 40))],
)
compose(
    f"{OUT}/modes.png",
    (1480, 300),
    [(36, 36, 40), (24, 24, 28)],
    [
        (load("pill", "dark"), (20, 50)),
        (load("pill_api", "dark"), (500, 50)),
        (load("pill_empty", "dark"), (980, 50)),
    ],
)
