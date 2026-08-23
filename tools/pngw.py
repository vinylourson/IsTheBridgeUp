import zlib, struct
def write_png(path, pixels):
    """pixels: list of rows, each a list of (r,g,b) tuples."""
    h=len(pixels); w=len(pixels[0])
    raw=b''.join(b'\x00'+b''.join(bytes(p) for p in row) for row in pixels)
    def chunk(t,d):
        c=struct.pack('>I',len(d))+t+d
        return c+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
    png=(b'\x89PNG\r\n\x1a\n'
         +chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))
         +chunk(b'IDAT',zlib.compress(raw,9))
         +chunk(b'IEND',b''))
    open(path,'wb').write(png)
