#!/usr/bin/env python3
"""Renders the LiftDrop app icon: a paper plane on a flip-dot board.

The board dots use the Shoreline palette and the plane is lit in Amber, with
the same ordered dithering the in-app DotMatrixDisplay uses. Regenerate with:

    python3 Tools/generate_app_icon.py
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
GRID = 24
DOT_FILL = 0.82

# Shoreline, from the board backing through to the unlit disc face.
BOARD_TOP = (0x0A, 0x16, 0x1E)
BOARD_BOTTOM = (0x13, 0x2B, 0x3A)
UNLIT = (0x1B, 0x2F, 0x3D)

# Amber ramp, dark to bright, matching DotPalette.amber.
AMBER = [
    (0x73, 0x47, 0x11),
    (0xB0, 0x6F, 0x16),
    (0xEB, 0xA6, 0x21),
    (0xF5, 0xC9, 0x5E),
]

BAYER = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]

# A symmetric dart defined nose-first along +x, then rotated into a climb and
# scaled to fit. Keeping it symmetric about the flight axis is what makes it
# read as a paper plane rather than a bird.
CLIMB_DEGREES = 30
SAFE = 0.80  # iOS masks the corners, so keep the art inside the middle 80%.

PLANE = [(1.0, 0.0), (-0.78, -0.55), (-0.58, 0.0), (-0.78, 0.55)]


def placed_faces():
    """Returns the two lit faces as polygons in unit icon coordinates."""
    angle = math.radians(-CLIMB_DEGREES)
    cos_a, sin_a = math.cos(angle), math.sin(angle)
    rotated = [(x * cos_a - y * sin_a, x * sin_a + y * cos_a) for x, y in PLANE]

    xs = [p[0] for p in rotated]
    ys = [p[1] for p in rotated]
    span = max(max(xs) - min(xs), max(ys) - min(ys))
    scale = SAFE / span
    cx = (max(xs) + min(xs)) / 2
    cy = (max(ys) + min(ys)) / 2
    placed = [(0.5 + (x - cx) * scale, 0.5 + (y - cy) * scale) for x, y in rotated]

    tip, upper, notch, lower = placed
    # The upper face catches the light; the lower face sits in shadow.
    return [([tip, upper, notch], 1.0), ([tip, notch, lower], 0.5)]


FACES = placed_faces()


def coverage_masks():
    """Supersampled coverage per face so the dot edges land accurately."""
    masks = []
    for points, _ in FACES:
        mask = Image.new("L", (SIZE, SIZE), 0)
        ImageDraw.Draw(mask).polygon([(x * SIZE, y * SIZE) for x, y in points], fill=255)
        masks.append(mask.load())
    return masks


def cell_coverage(mask, x0, y0, x1, y1, step=6):
    hits = total = 0
    for y in range(y0, y1, step):
        for x in range(x0, x1, step):
            total += 1
            if mask[x, y] > 127:
                hits += 1
    return hits / max(1, total)


def main():
    icon = Image.new("RGB", (SIZE, SIZE), BOARD_TOP)
    draw = ImageDraw.Draw(icon)

    for y in range(SIZE):
        t = y / (SIZE - 1)
        draw.line(
            [(0, y), (SIZE, y)],
            fill=tuple(
                round(a + (b - a) * t) for a, b in zip(BOARD_TOP, BOARD_BOTTOM)
            ),
        )

    masks = coverage_masks()
    cell = SIZE / GRID
    dot = cell * DOT_FILL
    radius = dot * 0.28

    for row in range(GRID):
        for column in range(GRID):
            x0, y0 = int(column * cell), int(row * cell)
            x1, y1 = int((column + 1) * cell), int((row + 1) * cell)

            lit_face = None
            for index, mask in enumerate(masks):
                if cell_coverage(mask, x0, y0, x1, y1) > 0.42:
                    lit_face = index
                    break

            if lit_face is None:
                color = UNLIT
            else:
                # Brighten toward the nose so the plane reads as climbing.
                across = column / (GRID - 1)
                up = 1 - row / (GRID - 1)
                gradient = min(1.0, max(0.0, across * 0.5 + up * 0.5))
                gradient = gradient * 0.6 + FACES[lit_face][1] * 0.4
                threshold = (BAYER[row % 4][column % 4] + 0.5) / 16
                level = int(gradient * (len(AMBER) - 1) + threshold - 0.5)
                color = AMBER[min(len(AMBER) - 1, max(0, level))]

            inset = (cell - dot) / 2
            draw.rounded_rectangle(
                [x0 + inset, y0 + inset, x0 + inset + dot, y0 + inset + dot],
                radius=radius,
                fill=color,
            )

    out = (
        Path(__file__).resolve().parent.parent
        / "Sources/LiftDropApp/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
    )
    out.parent.mkdir(parents=True, exist_ok=True)
    icon.save(out)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
