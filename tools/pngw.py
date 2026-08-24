import zlib, struct


def write_png(path, pixels):
    """pixels: rows of (r,g,b) or (r,g,b,a) tuples.

    Alpha is needed for Android adaptive-icon foregrounds, where the sky must
    be transparent so the background layer shows through.
    """
    h = len(pixels)
    w = len(pixels[0])
    has_alpha = len(pixels[0][0]) == 4
    colour_type = 6 if has_alpha else 2
    raw = b''.join(
        b'\x00' + b''.join(bytes(p) for p in row) for row in pixels
    )

    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)

    png = (
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, colour_type, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(raw, 9))
        + chunk(b'IEND', b'')
    )
    with open(path, 'wb') as fh:
        fh.write(png)
