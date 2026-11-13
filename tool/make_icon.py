"""Generates assets/icon.png: a dark squircle with two activity rings.

Run from the project root:  python3 tool/make_icon.py   (needs Pillow)
"""
import math

from PIL import Image, ImageDraw, ImageFilter

SIZE, SS = 512, 4  # output size, supersampling factor
N = SIZE * SS
INSET = 20 * SS
GREEN, ORANGE = (48, 209, 88), (255, 159, 10)


def squircle_mask(inset, n=5.0):
    """Superellipse |x|^n + |y|^n = 1, the continuous-corner shape."""
    mask = Image.new("L", (N, N), 0)
    centre, radius = N / 2, N / 2 - inset
    points = []
    for i in range(720):
        t = 2 * math.pi * i / 720
        ct, st = math.cos(t), math.sin(t)
        points.append(
            (
                centre + radius * math.copysign(abs(ct) ** (2 / n), ct),
                centre + radius * math.copysign(abs(st) ** (2 / n), st),
            )
        )
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return mask


def vertical_gradient(top, bottom):
    column = Image.new("RGB", (1, N))
    for y in range(N):
        t = y / (N - 1)
        column.putpixel(
            (0, y), tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        )
    return column.resize((N, N))


def ring(draw, radius, width, colour, fraction):
    centre = N // 2
    box = [centre - radius, centre - radius, centre + radius, centre + radius]
    draw.arc(box, 0, 360, fill=colour + (56,), width=width)
    start, end = -90, -90 + 360 * fraction
    draw.arc(box, start, end, fill=colour + (255,), width=width)
    mid = radius - width / 2
    for angle in (start, end):  # round caps
        a = math.radians(angle)
        x, y = centre + mid * math.cos(a), centre + mid * math.sin(a)
        half = width / 2
        draw.ellipse([x - half, y - half, x + half, y + half], fill=colour + (255,))


def main():
    mask = squircle_mask(INSET)
    body = vertical_gradient((58, 58, 68), (22, 22, 28)).convert("RGBA")

    rings = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    draw = ImageDraw.Draw(rings)
    ring(draw, 150 * SS, 44 * SS, GREEN, 0.72)
    ring(draw, 92 * SS, 44 * SS, ORANGE, 0.46)
    body = Image.alpha_composite(body, rings)

    icon = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    icon.paste(body, (0, 0), mask)

    # Hairline edge light, as on the widget's glass.
    inner = squircle_mask(INSET + 3 * SS)
    rim = Image.composite(Image.new("L", (N, N), 64), Image.new("L", (N, N), 0), mask)
    rim = Image.composite(Image.new("L", (N, N), 0), rim, inner)
    white = Image.new("L", (N, N), 255)
    icon = Image.alpha_composite(icon, Image.merge("RGBA", (white, white, white, rim)))

    # Soft shadow so the icon floats in docks and launchers.
    shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    shadow.putalpha(
        mask.filter(ImageFilter.GaussianBlur(9 * SS)).point(lambda v: int(v * 0.42))
    )
    canvas = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    canvas.alpha_composite(shadow, (0, 8 * SS))
    canvas.alpha_composite(icon)
    canvas.resize((SIZE, SIZE), Image.LANCZOS).save("assets/icon.png")


if __name__ == "__main__":
    main()
