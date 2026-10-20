"""Convert the largest image in a Windows .ico file to PNG, standard library only.

Usage: python3 ico2png.py ICON.ico OUT.png

Handles the formats VedaBase's icons use (palette and true-colour DIBs with an
AND mask) and icons that already embed a PNG.
"""

import struct
import sys
import zlib


def largest_entry(data):
    _, kind, count = struct.unpack_from("<HHH", data, 0)
    if kind != 1 or count == 0:
        raise ValueError("not an icon file")
    entries = []
    for i in range(count):
        w, h, _, _, _, bpp, size, offset = struct.unpack_from("<BBBBHHII", data, 6 + 16 * i)
        entries.append(((w or 256) * (h or 256), bpp, data[offset:offset + size]))
    return max(entries, key=lambda e: (e[0], e[1]))[2]


def dib_to_rgba(dib):
    hsize, width, height2, _, bpp = struct.unpack_from("<IiiHH", dib, 0)
    height = abs(height2) // 2  # icon DIBs stack the colour image on the AND mask
    colours = struct.unpack_from("<I", dib, 32)[0] or (1 << bpp if bpp <= 8 else 0)
    palette = [dib[hsize + 4 * i:hsize + 4 * i + 4] for i in range(colours)]
    pixels = hsize + 4 * colours
    stride = ((width * bpp + 31) // 32) * 4
    mask = pixels + stride * height
    mask_stride = ((width + 31) // 32) * 4
    rows = []
    for y in range(height):
        src = height - 1 - y  # bottom-up
        row = bytearray()
        for x in range(width):
            if bpp == 32:
                b, g, r, a = dib[pixels + src * stride + 4 * x:pixels + src * stride + 4 * x + 4]
            elif bpp == 24:
                b, g, r = dib[pixels + src * stride + 3 * x:pixels + src * stride + 3 * x + 3]
                a = 255
            else:
                bit = x * bpp
                byte = dib[pixels + src * stride + bit // 8]
                index = (byte >> (8 - bpp - bit % 8)) & ((1 << bpp) - 1)
                b, g, r = palette[index][:3]
                a = 255
            if bpp != 32:
                masked = dib[mask + src * mask_stride + x // 8] >> (7 - x % 8) & 1
                a = 0 if masked else 255
            row += bytes((r, g, b, a))
        rows.append(bytes(row))
    return width, height, rows


def png(width, height, rows):
    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body))

    raw = b"".join(b"\0" + row for row in rows)
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))


def main(src, dst):
    image = largest_entry(open(src, "rb").read())
    if image.startswith(b"\x89PNG"):
        out = image
    else:
        out = png(*dib_to_rgba(image))
    with open(dst, "wb") as f:
        f.write(out)


if __name__ == "__main__":
    main(*sys.argv[1:3])
