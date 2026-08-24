"""Single source of truth for the pixel sprites; emits Dart + a preview PNG."""
import math

from pngw import write_png

PAL = {
 'K':(0x00,0x00,0x00), 'W':(0xFF,0xFF,0xFF),
 'r':(0x68,0x37,0x2B), 'R':(0x9A,0x67,0x59),
 'c':(0x70,0xA4,0xB2), 'p':(0x6F,0x3D,0x86),
 'g':(0x58,0x8D,0x43), 'G':(0x9A,0xD2,0x84),
 'b':(0x35,0x28,0x79), 'B':(0x6C,0x5E,0xB5),
 'y':(0xB8,0xC7,0x6F), 'o':(0x6F,0x4F,0x25),
 'n':(0x43,0x39,0x00), 'd':(0x44,0x44,0x44),
 'm':(0x6C,0x6C,0x6C), 'l':(0x95,0x95,0x95),
}

class G:
    def __init__(s,w,h): s.w,s.h=w,h; s.g=[['.']*w for _ in range(h)]
    def put(s,x,y,c):
        if 0<=x<s.w and 0<=y<s.h: s.g[y][x]=c
    def ring(s,cx,cy,r,c):
        x,y,d=r,0,1-r
        while x>=y:
            for px,py in ((x,y),(y,x),(-x,y),(-y,x),(x,-y),(y,-x),(-x,-y),(-y,-x)):
                s.put(cx+px,cy+py,c)
            y+=1
            if d<0: d+=2*y+1
            else: x-=1; d+=2*(y-x)+1
    def disc(s,cx,cy,r,c):
        for y in range(-r,r+1):
            for x in range(-r,r+1):
                if x*x+y*y<=r*r+r//2: s.put(cx+x,cy+y,c)
    def line(s,x0,y0,x1,y1,c):
        dx,dy=abs(x1-x0),abs(y1-y0); sx=1 if x0<x1 else -1; sy=1 if y0<y1 else -1
        err=dx-dy
        while True:
            s.put(x0,y0,c)
            if x0==x1 and y0==y1: break
            e2=2*err
            if e2>-dy: err-=dy; x0+=sx
            if e2<dx: err+=dx; y0+=sy
    def rect(s,x0,y0,x1,y1,c,fill=False):
        for y in range(y0,y1+1):
            for x in range(x0,x1+1):
                if fill or y in (y0,y1) or x in (x0,x1): s.put(x,y,c)
    def rows(s): return [''.join(r) for r in s.g]

# ---- sprites ----
#
# One scale for the whole scene: 8.5 px per metre. Before this the implied
# scale ran from 4.8 px/m (car, lengthwise) to 22 px/m (pedestrian), which is
# why the vehicles looked like they came from different sets.
#
#   pedestrian  0.5 x 1.75 m  ->  11 x 15
#   cyclist     1.75 x 1.9 m  ->  17 x 16
#   motorbike   2.1 x 1.8 m   ->  18 x 15
#   car         4.2 x 1.5 m   ->  36 x 13
#
# Figures are drawn from a skeleton rather than hand-placed per frame, so the
# proportions stay identical across a cycle and the motion reads as weight.
# Light outlines throughout: every screen sits on a dark background.

def walker(phase, O='l', S='m', A='W'):
    """Anatomy-driven walk cycle.

    Deriving frames from a skeleton keeps proportions identical across the
    cycle and makes the motion read as weight rather than a slide. Solid
    3px limbs and a 5px shoulder line stop the figure looking like an aerial.
    """
    W, H = 11, 15
    g = G(W, H)
    cx = 5
    SH, HIP = 4, 9
    t = phase * 2 * math.pi

    # head, sitting on the shoulders with no spindly neck
    g.rect(cx - 1, 0, cx + 1, 2, O, fill=True)
    g.put(cx, 1, A)
    # shoulders wider than the chest, chest wider than the waist
    g.rect(cx - 2, SH - 1, cx + 2, SH, O, fill=True)
    g.rect(cx - 1, SH + 1, cx + 1, SH + 3, O, fill=True)
    g.rect(cx - 1, SH + 4, cx + 1, HIP - 1, S, fill=True)

    # legs: near leg light, far leg darker so they separate
    for ph, col, thick in ((phase, O, True), (phase + 0.5, S, False)):
        a = math.sin(ph * 2 * math.pi)
        kx = cx + round(a * 2)
        ky = HIP + 3
        fx = cx + round(math.sin((ph + 0.12) * 2 * math.pi) * 3)
        fy = H - 2
        g.line(cx, HIP, kx, ky, col)
        g.line(kx, ky, fx, fy, col)
        if thick:                      # give the near leg some mass
            g.line(cx + 1, HIP, kx + 1, ky, col)
            g.line(kx, ky + 1, fx, fy, col)
        g.rect(fx - 1, H - 1, min(fx + 1, W - 1), H - 1, col, fill=True)

    # arms swing opposite the legs
    for ph, col in ((phase + 0.5, O), (phase, S)):
        a = math.sin(ph * 2 * math.pi)
        ex = cx + round(a * 2)
        hx = cx + round(math.sin((ph + 0.1) * 2 * math.pi) * 3)
        g.line(cx, SH, ex, SH + 3, col)
        g.line(ex, SH + 3, hx, SH + 5, col)
    return g


def cyclist(phase, O='l', S='m', A='l'):
    """Bicycle with a rider, pedalling. 1.75 m long, 1.9 m tall.

    Built from a riding posture -- hip on the saddle, shoulders forward over
    the bars, legs down to the cranks -- rather than a standing figure parked
    behind a bike, which is what the first attempt looked like.
    """
    W, H = 17, 16
    g = G(W, H)
    RW = 3
    ry = H - 1 - RW                      # wheel centre line
    rear, front = RW + 1, W - RW - 2
    bb = 8                               # bottom bracket (cranks)
    saddle = (6, 7)
    bars = (front, 6)

    # frame first, so the rider sits in front of it
    for wx in (rear, front):
        g.ring(wx, ry, RW, S)
    g.line(rear, ry, bb, ry, O)                       # chainstay
    g.line(bb, ry, saddle[0], saddle[1], O)           # seat tube
    g.line(rear, ry, saddle[0], saddle[1], O)         # seat stay
    g.line(saddle[0], saddle[1], bars[0], bars[1], O) # top tube
    g.line(bb, ry, bars[0], bars[1], O)               # down tube
    g.line(bars[0], bars[1], front, ry, O)            # fork
    g.rect(bars[0] - 1, bars[1] - 1, bars[0] + 1, bars[1] - 1, O, fill=True)
    g.rect(saddle[0] - 1, saddle[1] - 1, saddle[0] + 1, saddle[1] - 1, O, fill=True)

    # rider: hip -> shoulder leans forward; head sits on the shoulders
    hip = (saddle[0], saddle[1] - 1)
    sh = (hip[0] + 3, 3)
    g.line(hip[0], hip[1], sh[0], sh[1], A)           # torso
    g.line(hip[0] + 1, hip[1], sh[0] + 1, sh[1], A)   # torso, 2px for mass
    g.rect(sh[0], sh[1] - 2, sh[0] + 1, sh[1] - 1, A, fill=True)   # head
    g.put(sh[0] + 1, sh[1] - 2, 'W')                  # face
    g.line(sh[0] + 1, sh[1] + 1, bars[0] - 1, bars[1] - 1, S)   # arm to bars

    # legs down to the rotating cranks
    for ph, col in ((phase, A), (phase + 0.5, S)):
        t = ph * 2 * math.pi
        px_ = bb + round(math.cos(t) * 2)
        py_ = ry + round(math.sin(t) * 2)
        knee = ((hip[0] + px_) // 2 + 1, (hip[1] + py_) // 2)
        g.line(hip[0], hip[1], knee[0], knee[1], col)
        g.line(knee[0], knee[1], px_, py_, col)
    return g


def phase_pedal(ph):
    t = ph * 2 * math.pi
    return (round(math.cos(t) * 2), round(math.sin(t) * 2))


def motorbike(phase, O='l', S='m', A='l', B='r'):
    """Motorbike with a rider, crouched forward. 2.1 m long, 1.8 m tall."""
    W, H = 18, 15
    g = G(W, H)
    RW = 3
    ry = H - 1 - RW
    rear, front = RW + 1, W - RW - 2
    for wx in (rear, front):
        g.ring(wx, ry, RW, S)
        g.disc(wx, ry, 1, S)
    g.rect(rear, ry - 3, front - 2, ry - 1, O, fill=True)        # engine mass
    g.rect(rear + 1, ry - 4, front - 4, ry - 3, B, fill=True)    # tank
    g.rect(rear - 1, ry - 5, rear + 3, ry - 4, O, fill=True)     # seat
    g.line(front - 2, ry - 4, front, ry - 1, O)                  # fork
    g.rect(front - 2, ry - 6, front, ry - 6, O, fill=True)       # bars

    hip = (rear + 2, ry - 6)
    sh = (hip[0] + 3, 3)
    g.line(hip[0], hip[1], sh[0], sh[1], A)
    g.line(hip[0] + 1, hip[1], sh[0] + 1, sh[1], A)
    g.rect(sh[0], sh[1] - 2, sh[0] + 1, sh[1] - 1, A, fill=True)
    g.put(sh[0] + 1, sh[1] - 2, 'W')
    g.line(sh[0] + 1, sh[1] + 1, front - 1, ry - 6, S)           # arm to bars
    g.line(hip[0], hip[1] + 1, hip[0] + 2, ry - 1, S)            # leg to peg
    return g


def car(phase, O='l', S='m', G_='c', B='R'):
    """Saloon car. 4.2 m long, 1.5 m tall -- the one that was most wrong."""
    W, H = 36, 13
    g = G(W, H)
    body_top, body_bot = 5, H - 4
    g.rect(1, body_top, W - 2, body_bot, O)
    g.rect(2, body_top + 1, W - 3, body_bot - 1, B, fill=True)
    # cabin
    g.rect(10, 1, 25, body_top, O)
    g.rect(11, 2, 24, body_top - 1, G_, fill=True)
    g.put(17, 2, O); g.put(17, 3, O); g.put(17, 4, O)            # b-pillar
    g.put(1, body_top + 2, 'y')                                  # headlight
    g.put(W - 2, body_top + 2, B)                                # tail light
    ry = H - 3
    for wx in (8, W - 9):
        g.ring(wx, ry, 2, O)
        g.put(wx + (1 if phase < 0.5 else -1), ry, S)            # hub spin
    g.rect(1, body_bot, W - 2, body_bot, S, fill=True)           # shadow line
    return g


def ship(O='W', H_='r'):
    """Non-literal, but must read as far bigger than a car."""
    W, H = 58, 20
    g = G(W, H)
    g.rect(4, 12, W - 3, 17, H_, fill=True)
    g.rect(4, 12, W - 3, 12, O)
    g.line(4, 13, 1, 12, O)
    g.rect(7, 18, W - 6, 18, 'n', fill=True)
    g.rect(6, 5, W - 10, 11, O)
    g.rect(7, 6, W - 11, 10, 'W', fill=True)
    for x in range(9, W - 13, 3):
        g.rect(x, 7, x + 1, 9, 'b', fill=True)
    for fx in (16, 30):
        g.rect(fx, 1, fx + 4, 4, O, fill=True)
        g.rect(fx + 1, 2, fx + 3, 4, H_, fill=True)
    g.rect(W - 9, 7, W - 4, 11, O)
    g.rect(W - 8, 8, W - 5, 10, 'c', fill=True)
    return g


def cone():
    """Roadworks cone, ~0.75 m. It was 1.8 m tall at the new scale."""
    g = G(7, 9)
    spans = [(3, 3), (2, 4), (2, 4), (1, 5), (1, 5)]
    for i, (a, b) in enumerate(spans):
        y = i + 2
        g.rect(a, y, b, y, 'K')
        if b - a > 1:
            g.rect(a + 1, y, b - 1, y, 'R', fill=True)
    for y in (4, 6):
        a, b = spans[y - 2]
        if b - a > 1:
            g.rect(a + 1, y, b - 1, y, 'W', fill=True)
    g.rect(0, 7, 6, 8, 'K', fill=True)
    g.rect(1, 7, 5, 7, 'd', fill=True)
    return g


def water():
    g=G(16,5)
    for y in range(5):
        for x in range(16): g.put(x,y,'b')
    for x0 in (0,8):
        g.line(x0+0,1,x0+2,0,'B'); g.line(x0+3,0,x0+5,1,'B'); g.line(x0+5,1,x0+7,2,'B')
        g.put(x0+3,0,'c'); g.put(x0+4,0,'c')
        g.line(x0+1,3,x0+3,3,'B'); g.put(x0+6,4,'B')
    return g

SPRITES = [
    # Four-frame walk cycle.
    ('walk0', walker(0.00)), ('walk1', walker(0.25)),
    ('walk2', walker(0.50)), ('walk3', walker(0.75)),
    # Two-frame pedal / wheel cycles.
    ('cyclist0', cyclist(0.0)), ('cyclist1', cyclist(0.5)),
    ('moto0', motorbike(0.0)), ('moto1', motorbike(0.5)),
    ('car0', car(0.0)), ('car1', car(0.5)),
    ('ship', ship()), ('cone', cone()), ('water', water()),
]

def preview(path,scale=7):
    tiles=[]
    BG=(0x20,0x20,0x28); CHK=(0x2c,0x2c,0x36)
    for name,g in SPRITES:
        rows=g.rows()
        px=[[(CHK if (x//2+y//2)%2==0 else BG) if ch=='.' else PAL[ch]
             for x,ch in enumerate(r)] for y,r in enumerate(rows)]
        px=[[p for p in r for _ in range(scale)] for r in px for _ in range(scale)]
        tiles.append(px)
    W=max(len(t[0]) for t in tiles)+6; H=sum(len(t)+6 for t in tiles)
    c=[[BG]*W for _ in range(H)]; y=3
    for t in tiles:
        for r,row in enumerate(t): c[y+r][3:3+len(row)]=row
        y+=len(t)+6
    write_png(path,c)

def emit_dart():
    lines=[
     "// GENERATED by tools/gen_sprites.py — do not edit by hand.",
     "// Re-run: python3 tools/gen_sprites.py",
     "//",
     "// Sprites are character matrices; PixelPalette.charToColor maps each",
     "// character to a C64 colour. '.' is transparent.",
     "",
     "/// Pixel-art sprite matrices, drawn with light outlines because every",
     "/// screen in the app sits on a dark background.",
     "class PixelSprites {",
     "  const PixelSprites._();",
    ]
    for name,g in SPRITES:
        rows=g.rows()
        body=',\n'.join(f"    '{r}'" for r in rows)
        lines.append(f"\n  /// {len(rows[0])}x{len(rows)}")
        lines.append(f"  static const List<String> {name} = <String>[")
        lines.append(body+',')
        lines.append("  ];")
    lines.append("}")
    return '\n'.join(lines)+'\n'


if __name__ == '__main__':
    import os
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for name, g in SPRITES:
        rows = g.rows()
        assert len({len(r) for r in rows}) == 1, f'{name} has ragged rows'
        for r in rows:
            for ch in r:
                assert ch == '.' or ch in PAL, f'{name} uses unknown char {ch!r}'
        print(f'  {name:8} {len(rows[0]):2}x{len(rows):2}')
    out = os.path.join(root, 'lib', 'src', 'ui', 'theme', 'pixel_sprites.dart')
    with open(out, 'w') as fh:
        fh.write(emit_dart())
    print('wrote', os.path.relpath(out, root))
    prev = os.path.join(root, 'tools', 'sprite_preview.png')
    preview(prev)
    print('wrote', os.path.relpath(prev, root))
