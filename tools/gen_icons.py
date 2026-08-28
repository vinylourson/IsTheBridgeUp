"""Generates the launcher icons and a wordmark from a 24x24 pixel design.

24 was chosen because it divides every Android launcher density exactly
(48=x2, 72=x3, 96=x4, 144=x6, 192=x8), so each source pixel stays a perfect
square. A 32-grid would have needed fractional scaling at 48 and 144, which
makes pixel art look like a mistake.

The palette is sampled from the reference logo (a pixelated photo of the
bridge with its span raised), not invented: daylight azure sky, warm stone
towers, red aviation bands, Garonne blue below.

Run: python3 tools/gen_icons.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_sprites import G  # noqa: E402  (drawing primitives)
from pngw import write_png  # noqa: E402

SIZE = 24

# Sampled from the reference logo, then nudged for contrast at 48px.
PAL = {
    'S': (0x45, 0x91, 0xEA),   # sky, azure
    'H': (0x8F, 0xBC, 0xE8),   # sky near the horizon
    'W': (0xEA, 0xF2, 0xFC),   # cloud
    'T': (0xDC, 0xD9, 0xC6),   # tower stone, lit face
    'D': (0xA8, 0xA5, 0x94),   # tower stone, shaded face
    'G': (0x3C, 0x5A, 0x78),   # glazed strip up the pylons
    'R': (0xD2, 0x40, 0x2F),   # aviation band
    'P': (0x9C, 0x87, 0x60),   # deck / pier
    'K': (0x6E, 0x5C, 0x40),   # skyline
    'B': (0x2F, 0x56, 0x86),   # water
    'L': (0x4A, 0x79, 0xAE),   # water highlight
}

DECK_Y = 18
WATER_Y = 19
TOWER_TOP = 2
TOWER_A = (7, 8)
TOWER_B = (15, 16)
SPAN = (9, 14)
SPAN_Y = 5


def icon():
    """Two lift towers with the span raised, and clear sky in the gap beneath.

    That gap is the whole message -- it is what says a ship can get through
    and you cannot. Everything else is trimmed to keep it readable at 48px:
    no skyline, no horizon gradient, towers only two pixels wide.
    """
    g = G(SIZE, SIZE)

    # Flat sky. A horizon gradient just muddled things at this size.
    for y in range(SIZE):
        for x in range(SIZE):
            g.put(x, y, 'S')

    # A few clouds, kept clear of the towers and the span.
    for cx, cy in ((1, 9), (19, 4), (20, 14)):
        g.rect(cx, cy, cx + 2, cy, 'W', fill=True)
        g.put(cx + 1, cy - 1, 'W')

    # Water.
    for y in range(WATER_Y, SIZE):
        for x in range(SIZE):
            g.put(x, y, 'B')
    # Scattered single-pixel glints, not 2px blocks in rows -- blocks read as
    # brickwork at this size rather than water.
    for x in range(0, SIZE, 2):
        g.put(x, WATER_Y, 'L')
    for x, y in ((1, 20), (6, 21), (11, 20), (13, 22), (18, 21), (22, 20), (4, 23), (20, 23)):
        g.put(x, y, 'L')

    # Approach decks -- deliberately NOT across the middle: the span is up.
    for a, b in ((0, TOWER_A[0] - 1), (TOWER_B[1] + 1, SIZE - 1)):
        g.rect(a, DECK_Y, b, DECK_Y, 'P', fill=True)
        g.rect(a, DECK_Y - 1, b, DECK_Y - 1, 'T', fill=True)

    # The raised span, bridging the gap between the towers near the top.
    g.rect(SPAN[0], SPAN_Y, SPAN[1], SPAN_Y, 'T', fill=True)
    g.rect(SPAN[0], SPAN_Y + 1, SPAN[1], SPAN_Y + 1, 'D', fill=True)

    # Towers, in front of everything, two pixels wide so they stay slender.
    for x0, x1 in (TOWER_A, TOWER_B):
        g.rect(x0, TOWER_TOP, x1, SIZE - 1, 'T', fill=True)
        g.rect(x1, TOWER_TOP, x1, SIZE - 1, 'G', fill=True)   # glazed strip
        g.rect(x0, DECK_Y + 1, x1, SIZE - 1, 'D', fill=True)  # pier into water
        g.rect(x0, 12, x1, 12, 'R', fill=True)                # aviation band
    return g


# ---- 5x7 pixel font, only the glyphs the wordmark needs ----
FONT = {
    'I': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '#####'],
    'S': ['.####', '#....', '#....', '.###.', '....#', '....#', '####.'],
    'T': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
    'H': ['#...#', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
    'E': ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
    'B': ['####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.'],
    'R': ['####.', '#...#', '#...#', '####.', '#..#.', '#...#', '#...#'],
    'D': ['####.', '#...#', '#...#', '#...#', '#...#', '#...#', '####.'],
    'G': ['.###.', '#...#', '#....', '#..##', '#...#', '#...#', '.###.'],
    'U': ['#...#', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
    'P': ['####.', '#...#', '#...#', '####.', '#....', '#....', '#....'],
    '?': ['.###.', '#...#', '....#', '..##.', '..#..', '.....', '..#..'],
    ' ': ['.....', '.....', '.....', '.....', '.....', '.....', '.....'],
}


def render(grid, scale, pad_to=None):
    """Integer-scales the grid; pads with sky so any remainder is invisible."""
    rows = grid.rows()
    art = SIZE * scale
    canvas = pad_to or art
    off = (canvas - art) // 2
    bg = PAL['S']
    out = [[bg] * canvas for _ in range(canvas)]
    for y in range(SIZE):
        for x in range(SIZE):
            c = PAL[rows[y][x]]
            for dy in range(scale):
                r = out[off + y * scale + dy]
                s = off + x * scale
                r[s:s + scale] = [c] * scale
    return out


def render_foreground(grid, scale, canvas):
    """Adaptive-icon foreground: the art centred on a transparent canvas.

    Android composites this over a separate background layer and may mask
    anything outside the inner 72dp of the 108dp canvas, so the art is kept
    within that safe zone. Sky pixels become transparent because the
    background layer supplies the same azure.
    """
    rows = grid.rows()
    art = SIZE * scale
    off = (canvas - art) // 2
    clear = (0, 0, 0, 0)
    out = [[clear] * canvas for _ in range(canvas)]
    for y in range(SIZE):
        for x in range(SIZE):
            ch = rows[y][x]
            if ch == 'S':          # sky -> let the background layer show
                continue
            r, g, b = PAL[ch]
            for dy in range(scale):
                row = out[off + y * scale + dy]
                start = off + x * scale
                row[start:start + scale] = [(r, g, b, 255)] * scale
    return out


def wordmark(scale=8, text='IS THE BRIDGE UP?'):
    """Icon beside the app name, for the README and store listings.

    The launcher icons carry no text on purpose: at 48px it would be
    illegible, and both Apple and Google advise against words in app icons.
    """
    art = render(icon(), scale)
    gap = 4 * scale
    glyph_w, glyph_h = 5, 7
    tracking = 1
    text_w = len(text) * (glyph_w + tracking) * scale
    W = len(art) + gap + text_w + gap
    H = len(art)
    bg = PAL['S']
    out = [[bg] * W for _ in range(H)]
    for y, row in enumerate(art):
        out[y][0:len(row)] = row

    baseline = (H - glyph_h * scale) // 2
    x0 = len(art) + gap
    ink = PAL['W']
    shadow = PAL['G']
    for ch in text:
        rows = FONT.get(ch, FONT[' '])
        for gy in range(glyph_h):
            for gx in range(glyph_w):
                if rows[gy][gx] != '#':
                    continue
                for dy in range(scale):
                    for dx in range(scale):
                        py = baseline + gy * scale + dy
                        px_ = x0 + gx * scale + dx
                        if 0 <= py < H and px_ + scale < W:
                            out[py + scale][px_ + scale] = shadow
                for dy in range(scale):
                    r = out[baseline + gy * scale + dy]
                    s = x0 + gx * scale
                    r[s:s + scale] = [ink] * scale
        x0 += (glyph_w + tracking) * scale
    return out


# ---- Android status-bar icon ----
#
# Android builds the notification small icon from the ALPHA CHANNEL alone:
# every opaque pixel is painted flat white, whatever colour it was. Handing it
# the launcher icon -- opaque azure, corner to corner -- therefore produced a
# solid white blob in the status bar.
#
# Drawn on a 12x12 grid because 12 divides every notification-icon density
# exactly: mdpi 24 (x2), hdpi 36 (x3), xhdpi 48 (x4), xxhdpi 72 (x6),
# xxxhdpi 96 (x8). Only the silhouette matters, so it is the bridge reduced to
# the one shape that is unmistakably this bridge: two pylons and a raised deck.

STAT_SIZE = 12


def stat_icon():
    g = G(STAT_SIZE, STAT_SIZE)
    for x0 in (2, 8):                       # two pylons, rising past the deck
        g.rect(x0, 0, x0 + 1, 9, 'W', fill=True)
    g.rect(4, 3, 7, 4, 'W', fill=True)      # the span, held high
    # Approach roadway either side, with the channel left open between them.
    # That gap is what stops the glyph reading as the letter H: the deck is
    # missing precisely where the span has lifted out of it.
    g.rect(0, 9, 3, 9, 'W', fill=True)
    g.rect(8, 9, 11, 9, 'W', fill=True)
    return g


def render_stat(grid, scale):
    """White-on-transparent: Android only reads alpha, so colour is moot."""
    rows = grid.rows()
    n = STAT_SIZE * scale
    clear = (0, 0, 0, 0)
    out = [[clear] * n for _ in range(n)]
    for y in range(STAT_SIZE):
        for x in range(STAT_SIZE):
            if rows[y][x] == '.':
                continue
            for dy in range(scale):
                row = out[y * scale + dy]
                row[x * scale:x * scale + scale] = [(255, 255, 255, 255)] * scale
    return out


def emit_stat_icons(root):
    grid = stat_icon()
    for density, scale in (('mdpi', 2), ('hdpi', 3), ('xhdpi', 4),
                           ('xxhdpi', 6), ('xxxhdpi', 8)):
        rel = f'android/app/src/main/res/drawable-{density}/ic_stat_bridge.png'
        path = os.path.join(root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        write_png(path, render_stat(grid, scale))
        print(f'  {rel:66} {STAT_SIZE * scale}x{STAT_SIZE * scale}')
    write_png(os.path.join(root, 'tools/stat_preview.png'), render_stat(grid, 16))


if __name__ == '__main__':
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    grid = icon()

    targets = [
        # Android launcher densities -- all exact multiples of 24.
        ('android/app/src/main/res/mipmap-mdpi/ic_launcher.png', 2, None),
        ('android/app/src/main/res/mipmap-hdpi/ic_launcher.png', 3, None),
        ('android/app/src/main/res/mipmap-xhdpi/ic_launcher.png', 4, None),
        ('android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png', 6, None),
        ('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', 8, None),
        # iOS wants a single 1024; 24x42=1008 padded with sky to 1024.
        ('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png', 42, 1024),
        # Web / PWA.
        ('web/favicon.png', 2, None),
        ('web/icons/Icon-192.png', 8, None),
        ('web/icons/Icon-512.png', 21, 512),
        ('web/icons/Icon-maskable-192.png', 6, 192),
        ('web/icons/Icon-maskable-512.png', 16, 512),
    ]
    for rel, scale, pad in targets:
        path = os.path.join(root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        write_png(path, render(grid, scale, pad))
        px = pad or SIZE * scale
        print(f'  {rel:74} {px}x{px}')

    # Android adaptive icons (API 26+, i.e. every current device). A legacy
    # PNG alone gets shrunk and letterboxed by modern launchers.
    # Canvas is 108dp; art is kept inside the guaranteed-visible inner 72dp.
    adaptive = [('mdpi', 108, 3), ('hdpi', 162, 4), ('xhdpi', 216, 6),
                ('xxhdpi', 324, 9), ('xxxhdpi', 432, 12)]
    for density, canvas, scale in adaptive:
        rel = f'android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png'
        path = os.path.join(root, rel)
        write_png(path, render_foreground(grid, scale, canvas))
        inner = SIZE * scale
        print(f'  {rel:74} {canvas}x{canvas} (art {inner}px, {inner * 100 // canvas}%)')

    anydpi = os.path.join(root, 'android/app/src/main/res/mipmap-anydpi-v26')
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, 'ic_launcher.xml'), 'w') as fh:
        fh.write('''<?xml version="1.0" encoding="utf-8"?>
<!-- GENERATED by tools/gen_icons.py -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''')
    sky = '#%02X%02X%02X' % PAL['S']
    colours = os.path.join(root, 'android/app/src/main/res/values/ic_launcher_background.xml')
    with open(colours, 'w') as fh:
        fh.write(f'''<?xml version="1.0" encoding="utf-8"?>
<!-- GENERATED by tools/gen_icons.py -->
<resources>
    <color name="ic_launcher_background">{sky}</color>
</resources>
''')
    print('  android/.../mipmap-anydpi-v26/ic_launcher.xml + values/ic_launcher_background.xml')

    emit_stat_icons(root)

    write_png(os.path.join(root, 'tools/icon_preview.png'), render(grid, 14))
    write_png(os.path.join(root, 'docs/wordmark.png'), wordmark())
    print('  tools/icon_preview.png (gitignored), docs/wordmark.png')
