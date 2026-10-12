#!/usr/bin/env python3
"""Decode Nintendo DS graphics (NCGR/RGCN tiles + NCLR/RLCN palettes, BTX0 /
BMD0 textures) into PNGs. Usage: nds2png.py <in_dir> <out_dir>"""
import os, struct, sys, glob
from PIL import Image

def u16(d, o): return struct.unpack_from("<H", d, o)[0]
def u32(d, o): return struct.unpack_from("<I", d, o)[0]

def bgr555(c):
    r, g, b = c & 31, (c >> 5) & 31, (c >> 10) & 31
    return (r << 3 | r >> 2, g << 3 | g >> 2, b << 3 | b >> 2)

def read_nclr(path):
    d = open(path, "rb").read()
    o = d.find(b"TTLP")
    depth = u32(d, o + 8)
    size = u32(d, o + 16)
    off = o + 8 + u32(d, o + 20)
    size = min(size, len(d) - off)
    cols = [bgr555(u16(d, off + i)) for i in range(0, size - 1, 2)]
    return cols, (16 if depth == 3 else 256)

def decrypt(words, forward):
    # DP/Pt/HGSS Pokemon and trainer pics are XORed with an LCRNG stream.
    w = list(words)
    idx = range(len(w)) if forward else range(len(w) - 1, -1, -1)
    seed = w[0] if forward else w[-1]
    for i in idx:
        w[i] ^= seed & 0xFFFF
        seed = (seed * 0x41C64E6D + 0x6073) & 0xFFFFFFFF
    return w

def pixels_4bpp(data):
    out = bytearray()
    for b in data:
        out.append(b & 15); out.append(b >> 4)
    return out

def read_ncgr(path):
    d = open(path, "rb").read()
    o = d.find(b"RAHC")
    th, tw = u16(d, o + 8), u16(d, o + 10)
    depth = u32(d, o + 12)
    scanned = u32(d, o + 20) & 1
    size = u32(d, o + 24)
    off = o + u32(d, o + 28) + 8
    data = d[off:off + size]
    return dict(th=th, tw=tw, bpp=4 if depth == 3 else 8, scanned=scanned, data=data)

def entropy_score(px):
    # lower = more like a sprite: count changes between neighbours
    return sum(1 for a, b in zip(px, px[1:]) if a != b) / max(1, len(px))

def render(px, w, h, pal, tiled, transparent=True):
    im = Image.new("RGBA", (w, h))
    put = im.load()
    for i, v in enumerate(px[:w * h]):
        if tiled:
            t, r = divmod(i, 64)
            tx, ty = t % (w // 8), t // (w // 8)
            x, y = tx * 8 + r % 8, ty * 8 + r // 8
        else:
            x, y = i % w, i // w
        if y >= h: break
        c = pal[v] if v < len(pal) else (255, 0, 255)
        put[x, y] = c + ((0,) if (transparent and v % 16 == 0) else (255,))
    return im

def ncgr_png(path, pal, out, chunk=None):
    g = read_ncgr(path)
    data = g["data"]
    notes = []
    if g["scanned"] and g["bpp"] == 4:
        words = struct.unpack("<%dH" % (len(data) // 2), data)
        best = (entropy_score(pixels_4bpp(data)), data, "plain")
        for fwd in (True, False):
            dec = struct.pack("<%dH" % len(words), *decrypt(words, fwd))
            s = entropy_score(pixels_4bpp(dec))
            if s < best[0] * 0.8:
                best = (s, dec, "decrypted " + ("forward" if fwd else "backward"))
        data = best[1]
        notes.append(best[2])
    px = pixels_4bpp(data) if g["bpp"] == 4 else bytearray(data)
    n = len(px)
    w, h = g["tw"] * 8, g["th"] * 8
    if g["tw"] == 0xFFFF or w * h != n:
        w = 64; h = n // w
    shape = [(w, h, not g["scanned"])]
    if g["scanned"] and n % (80 * 80) == 0:
        # trainer and Pokemon pics: 80x80 frames stored side by side as 160x80
        shape = [(160, n // 160, False)]
    for w, h, tiled in shape:
        im = render(px, w, h, pal, tiled)
        im.save(out)
    if chunk:
        cw, ch = chunk
        per = cw * ch
        n_chunks = len(px) // per
        im = Image.new("RGBA", (cw * n_chunks, ch))
        for c in range(n_chunks):
            im.paste(render(px[c * per:(c + 1) * per], cw, ch, pal, True), (c * cw, 0))
        im.save(out.replace(".png", f"_{cw}x{ch}.png"))
    return f"{w}x{h} {g['bpp']}bpp {'scanned' if g['scanned'] else 'tiled'} {' '.join(notes)}"

# ---------------------------------------------------------------- TEX0
FMT_BPP = {1: 8, 2: 2, 3: 4, 4: 8, 6: 8, 7: 16}

def dict_names(d, o):
    count = d[o + 1]
    hdr = o + 4 + 8 + 4 * count   # skip dict header + unknown block
    unit = u16(d, hdr)
    entries = hdr + 4
    names_at = entries + unit * count
    names = [d[names_at + 16 * i:names_at + 16 * i + 16].rstrip(b"\0").decode("latin1") for i in range(count)]
    return count, entries, unit, names

def tex0_pngs(d, base, out_prefix):
    t = base
    texdata = t + u32(d, t + 0x14)
    texinfo = t + u16(d, t + 0x0E)
    paldata = t + u32(d, t + 0x38)
    palinfo = t + u32(d, t + 0x34)
    palsize = u32(d, t + 0x30) << 3
    tc, te, tu, tnames = dict_names(d, texinfo)
    pc, pe, pu, pnames = dict_names(d, palinfo)
    pals = []
    for i in range(pc):
        po = paldata + (u16(d, pe + pu * i) << 3)
        n = max(0, min(256, (paldata + palsize - po) // 2, (len(d) - po) // 2))
        pals.append([bgr555(u16(d, po + 2 * k)) for k in range(n)])
    results = []
    for i in range(tc):
        off = texdata + (u16(d, te + tu * i) << 3)
        p = u16(d, te + tu * i + 2)
        w, h = 8 << ((p >> 4) & 7), 8 << ((p >> 7) & 7)
        fmt, c0 = (p >> 10) & 7, (p >> 13) & 1
        bpp = FMT_BPP.get(fmt)
        if bpp is None or fmt == 7 or fmt == 5:
            results.append(f"{tnames[i]}: format {fmt} skipped"); continue
        raw = d[off:off + w * h * bpp // 8]
        px = []
        if bpp == 4:
            px = list(pixels_4bpp(raw))
        elif bpp == 2:
            for b in raw: px += [b & 3, (b >> 2) & 3, (b >> 4) & 3, b >> 6]
        else:
            px = list(raw)
        # pick the palette with the same name if any, else the first
        pal = pals[0] if pals else [(i * 17,) * 3 for i in range(16)]
        tb = tnames[i].split(".")[0]
        for j, pn in enumerate(pnames):
            if pn in (tnames[i], tnames[i] + "_pl", tb, tb + "_pl"):
                pal = pals[j]
                break
        im = Image.new("RGBA", (w, h))
        put = im.load()
        for k, v in enumerate(px[:w * h]):
            if fmt in (1, 6):  # a3i5 / a5i3
                a_bits, i_bits = (3, 5) if fmt == 1 else (5, 3)
                idx, a = v & ((1 << i_bits) - 1), v >> i_bits
                c = pal[idx] if idx < len(pal) else (255, 0, 255)
                put[k % w, k // w] = c + (a * 255 // ((1 << a_bits) - 1),)
            else:
                c = pal[v] if v < len(pal) else (255, 0, 255)
                put[k % w, k // w] = c + ((0,) if (c0 and v == 0) else (255,))
        base, _, num = tnames[i].rpartition(".")
        name = f"{out_prefix}_{base}_{int(num):02d}.png" if num.isdigit() else f"{out_prefix}_{tnames[i]}.png"
        im.save(name)
        results.append((name, im))
    return results, pnames

def main(src, dst):
    for folder in sorted(glob.glob(os.path.join(src, "*"))):
        if not os.path.isdir(folder): continue
        label = os.path.basename(folder).split("-")[0].strip()
        od = os.path.join(dst, label)
        os.makedirs(od, exist_ok=True)
        files = sorted(glob.glob(os.path.join(folder, "*")))
        pals = []
        for f in files:
            d = open(f, "rb").read(4)
            if d == b"RLCN":
                pals.append(f)
        for f in files:
            raw = open(f, "rb").read()
            stem = os.path.splitext(os.path.basename(f))[0]
            try:
                if raw[:4] == b"RGCN":
                    # palette: the RLCN right after it in number order, else the first
                    num = int(stem.split("_")[1].split("-")[0])
                    pn = lambda p: int(os.path.basename(p).split("_")[1].split(".")[0])
                    cand = sorted(pals, key=lambda p: (abs(pn(p) - num), pn(p) < num))
                    pal, _ = read_nclr(cand[0]) if cand else ([(i * 17,) * 3 for i in range(16)], 16)
                    chunk = (16, 16) if label == "MapIcon" else None
                    info = ncgr_png(f, pal, os.path.join(od, stem + ".png"), chunk)
                    print(f"{label}/{stem}.png  {info}  pal {os.path.basename(cand[0]) if cand else 'grey'}")
                elif b"TEX0" in raw:
                    sub = os.path.join(od, stem)
                    os.makedirs(sub, exist_ok=True)
                    res, pn = tex0_pngs(raw, raw.find(b"TEX0"), os.path.join(sub, stem))
                    res.sort(key=lambda r: r[0])
                    ims = [im for _, im in res]
                    if ims and all(im.size == ims[0].size for im in ims):
                        strip = Image.new("RGBA", (ims[0].width, ims[0].height * len(ims)))
                        for k, im in enumerate(ims): strip.paste(im, (0, k * im.height))
                        strip.save(os.path.join(od, stem + "_strip.png"))
                    print(f"{label}/{stem}: {len(res)} textures {ims[0].size if ims else ''}, palettes {pn}")
            except Exception as e:
                print(f"{label}/{stem}: failed ({e})")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
