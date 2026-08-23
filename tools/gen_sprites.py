"""Single source of truth for the pixel sprites; emits Dart + a preview PNG."""
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

# ---- sprites (light outlines: the app is dark-themed throughout) ----

def bicycle(O='l',A='W'):
    g=G(23,14)
    for cx in (5,17): g.ring(cx,9,4,O)
    g.line(5,9,11,9,O); g.line(11,9,8,4,O); g.line(5,9,8,4,O)   # rear triangle
    g.line(11,9,15,4,O); g.line(8,4,15,4,O)                     # down + top tube
    g.line(15,4,17,9,O)                                         # fork
    g.rect(7,3,9,3,A)                                           # saddle
    g.line(13,2,18,2,O); g.line(15,2,15,4,O)                    # bar + stem
    g.put(5,9,A); g.put(17,9,A)                                 # hubs
    return g

def moto(O='l'):
    g=G(23,14)
    for cx in (5,17): g.ring(cx,9,4,O)
    g.disc(5,9,2,'d'); g.disc(17,9,2,'d')
    g.rect(6,5,14,8,O,fill=True); g.rect(7,6,13,7,'r',fill=True)   # engine
    g.rect(8,3,14,5,O,fill=True); g.rect(9,4,13,4,'y',fill=True)   # tank
    g.rect(4,3,7,4,O); g.line(15,2,19,2,O); g.line(15,2,15,5,O)    # seat + bars
    g.line(15,5,18,8,O); g.line(14,8,17,9,O)                       # fork
    return g

def car(O='l'):
    g=G(20,12)
    g.rect(4,1,14,3,O); g.rect(5,2,13,3,'c',fill=True)      # cabin + glass
    g.put(9,2,O); g.put(9,3,O)                              # b-pillar
    g.rect(1,4,18,8,O); g.rect(2,5,17,7,'R',fill=True)      # body
    g.rect(2,5,17,5,'r',fill=True)                          # shading
    g.put(1,6,'y'); g.put(18,6,'R')                         # headlight
    for cx in (5,14):
        g.ring(cx,9,2,O); g.disc(cx,9,1,'d')
    return g

def ship(O='W'):
    g=G(44,17)
    g.rect(3,10,40,14,'r',fill=True)                        # hull
    g.rect(3,10,40,10,O); g.line(3,11,1,10,O)               # bow line
    g.rect(6,15,37,15,'n',fill=True)                        # waterline shadow
    g.rect(5,4,36,9,O)                                      # superstructure
    g.rect(6,5,35,8,'W',fill=True)
    for x in range(8,34,3): g.rect(x,6,x+1,7,'b',fill=True) # portholes
    g.rect(12,1,16,3,O,fill=True); g.rect(24,1,28,3,O,fill=True)   # funnels
    g.rect(13,2,15,3,'r',fill=True); g.rect(25,2,27,3,'r',fill=True)
    g.rect(37,6,40,9,O); g.rect(38,7,39,8,'c',fill=True)    # bridge wing
    return g

def cone():
    g=G(13,15)
    spans=[(6,6),(5,7),(5,7),(4,8),(4,8),(3,9),(3,9),(2,10),(2,10),(1,11),(1,11)]
    for i,(a,b) in enumerate(spans):
        y=i+2; g.rect(a,y,b,y,'K')
        if b-a>1: g.rect(a+1,y,b-1,y,'R',fill=True)
    for y in (6,7,10,11):
        a,b=spans[y-2]
        if b-a>1: g.rect(a+1,y,b-1,y,'W',fill=True)
    g.rect(0,13,12,14,'K',fill=True); g.rect(1,13,11,13,'d',fill=True)
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

SPRITES=[('bicycle',bicycle()),('moto',moto()),('car',car()),
         ('ship',ship()),('cone',cone()),('water',water())]

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
