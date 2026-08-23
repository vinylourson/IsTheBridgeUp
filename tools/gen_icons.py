"""Generates the favicon and PWA icons as pixel art.

Designed on a 32x32 grid and scaled by whole-number factors only (32 -> 192 is
x6, 32 -> 512 is x16), so the pixels stay perfectly square with no resampling.

Run: python3 tools/gen_icons.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_sprites import G, PAL  # noqa: E402
from pngw import write_png  # noqa: E402

SIZE = 32
WATER_Y = 25
DECK_Y = 22
LT = (6, 9)
RT = (22, 25)
SPAN = (10, 21)
BEAM_Y = 7


def icon():
    """The bridge with its span raised and a ship passing under: the whole
    point of the app in one silhouette."""
    g = G(SIZE, SIZE)
    for y in range(SIZE):
        for x in range(SIZE):
            g.put(x, y, 'K')

    # Water.
    for y in range(WATER_Y, SIZE):
        for x in range(SIZE):
            g.put(x, y, 'b')
    for x in range(0, SIZE, 4):
        g.put(x, WATER_Y, 'B')
        g.put(x + 2, WATER_Y + 2, 'B')
        g.put(x + 1, WATER_Y + 4, 'B')

    # Ship, drawn before the structure so the piers overlap it.
    g.rect(12, 22, 20, 24, 'r', fill=True)
    g.rect(13, 20, 19, 21, 'W', fill=True)
    g.put(15, 19, 'r')
    g.put(17, 19, 'r')

    # Approach decks.
    for a, b in ((0, LT[0] - 1), (RT[1] + 1, SIZE - 1)):
        g.rect(a, DECK_Y, b, DECK_Y + 1, 'm', fill=True)
        g.rect(a, DECK_Y, b, DECK_Y, 'l', fill=True)

    # Piers and towers.
    for x0, x1 in (LT, RT):
        g.rect(x0, DECK_Y, x1, SIZE - 1, 'd', fill=True)
        g.rect(x0, 2, x1, DECK_Y, 'l', fill=True)
        g.rect(x0 + 1, 3, x1 - 1, DECK_Y - 1, 'W', fill=True)
        g.rect(x0 - 1, BEAM_Y, x1 + 1, BEAM_Y + 1, 'l', fill=True)

    # Cables down to the raised span.
    for cx in (LT[0] + 1, RT[0] + 1):
        g.rect(cx, 4, cx, 10, 'l', fill=True)

    # The lift span, up.
    g.rect(SPAN[0], 10, SPAN[1], 12, 'm', fill=True)
    g.rect(SPAN[0], 10, SPAN[1], 10, 'l', fill=True)
    return g


def render(grid, scale, maskable=False):
    """Scales the art by a whole number and centres it on a canvas of
    `SIZE * scale`.

    Maskable icons are padded rather than resampled: shrinking a 32px grid to
    24 is not an integer ratio and duplicates rows unevenly, which is exactly
    the mush pixel art is supposed to avoid. Instead the art is scaled by a
    smaller whole number and centred, keeping every pixel square. The result
    occupies 75% of the canvas, inside the 80% maskable safe zone.
    """
    rows = grid.rows()
    canvas_px = SIZE * scale
    art_scale = max(1, int(scale * 0.75)) if maskable else scale
    art_px = SIZE * art_scale
    offset = (canvas_px - art_px) // 2

    black = PAL['K']
    out = [[black] * canvas_px for _ in range(canvas_px)]
    for y in range(SIZE):
        for x in range(SIZE):
            ch = rows[y][x]
            color = black if ch == '.' else PAL[ch]
            for dy in range(art_scale):
                row = out[offset + y * art_scale + dy]
                start = offset + x * art_scale
                row[start:start + art_scale] = [color] * art_scale
    return out


if __name__ == '__main__':
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    grid = icon()
    targets = [
        ('web/favicon.png', 1, False),
        ('web/icons/Icon-192.png', 6, False),
        ('web/icons/Icon-512.png', 16, False),
        ('web/icons/Icon-maskable-192.png', 6, True),
        ('web/icons/Icon-maskable-512.png', 16, True),
    ]
    for rel, scale, maskable in targets:
        path = os.path.join(root, rel)
        write_png(path, render(grid, scale, maskable))
        note = ' (maskable, padded)' if maskable else ''
        print(f'  {rel:38} {SIZE * scale}x{SIZE * scale}{note}')
    write_png(os.path.join(root, 'tools/icon_preview.png'), render(grid, 8, False))
    print('  tools/icon_preview.png                 preview')
