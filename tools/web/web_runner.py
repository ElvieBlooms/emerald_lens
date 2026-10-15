"""Glue between the web page and the sprite tools. The page copies uploads
into Pyodide's virtual filesystem; this runs the tools' own command lines on
them (the same argv as the CLI), so the site and the CLI share one source.
-Elvie"""
import io, json, os, runpy, shutil, sys, zipfile
from contextlib import redirect_stderr, redirect_stdout

TOOLS = "/lens/tools"
WORK = "/lens/work"

def setup():
    os.makedirs(TOOLS, exist_ok=True)
    os.makedirs(WORK, exist_ok=True)
    if TOOLS not in sys.path:
        sys.path.insert(0, TOOLS)
    os.chdir(WORK)

def run(script, argv):
    """Run tools/<script> as the CLI would. Returns (exit code, output)."""
    os.chdir(WORK)
    buf = io.StringIO()
    old = sys.argv
    sys.argv = [script] + list(argv)
    code = 0
    with redirect_stdout(buf), redirect_stderr(buf):
        try:
            runpy.run_path(os.path.join(TOOLS, script), run_name="__main__")
        except SystemExit as e:
            if isinstance(e.code, str):
                print(e.code)
                code = 1
            else:
                code = e.code or 0
        except Exception as e:
            import traceback
            traceback.print_exc()
            code = 1
        finally:
            sys.argv = old
    return code, buf.getvalue()

def clear(path):
    p = os.path.join(WORK, path)
    if os.path.isdir(p):
        shutil.rmtree(p)
    elif os.path.exists(p):
        os.remove(p)

def files(path):
    """Every file under path, relative to it, sorted."""
    root = os.path.join(WORK, path)
    out = []
    for d, _, names in os.walk(root):
        for n in names:
            out.append(os.path.relpath(os.path.join(d, n), root))
    return json.dumps(sorted(out))

def image_info(path):
    from PIL import Image
    with Image.open(os.path.join(WORK, path)) as im:
        return json.dumps({"w": im.size[0], "h": im.size[1]})

def zip_dir(path, top):
    """Zip WORK/path with everything under one top folder named top."""
    root = os.path.join(WORK, path)
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        for d, _, names in sorted(os.walk(root)):
            for n in sorted(names):
                full = os.path.join(d, n)
                z.write(full, os.path.join(top, os.path.relpath(full, root)))
    return buf.getvalue()

def single_dir(path):
    """If WORK/path holds just one folder (as zips often do), its path;
    otherwise path itself."""
    root = os.path.join(WORK, path)
    names = [n for n in os.listdir(root) if not n.startswith(("__MACOSX", "."))]
    if len(names) == 1 and os.path.isdir(os.path.join(root, names[0])):
        return os.path.join(path, names[0])
    return path

def replace_dir(src, dst):
    clear(dst)
    shutil.copytree(os.path.join(WORK, src), os.path.join(WORK, dst))

def sheet_family(path, family):
    """The family to hand transfer: the extras family when the sheet is
    extras-sized, as pack works it out. -Elvie"""
    import pack_gen3 as P
    from PIL import Image
    extras = P.EXTRAS_OF.get(family)
    full = os.path.join(WORK, path)
    if extras and os.path.isfile(full):
        with Image.open(full) as im:
            if im.size == P.layout(extras)[0]:
                return extras
    return family

def sheet_file(family):
    import pack_gen3 as P
    return P.SHEET_FILE[family]

def layout(family):
    """Each section's slots, as (file, frame index) per facing, and each
    file's frame size and foot row, for a family and its extras."""
    import import_sheet as I
    import pack_gen3 as P
    sections, frames = {}, {}
    for fam in (family, P.EXTRAS_OF[family]):
        for key, facings in I.sections(fam).items():
            sections[key] = {"family": fam, "facings": {f: [[n, i] for n, i in slots] for f, slots in facings.items()}}
            for n, _ in [s for slots in facings.values() for s in slots]:
                w, h, count = P.spec(fam, n)
                frames[n] = [w, h, count, I.foot(fam, n, h)]
    return sections, frames

def layout_data(family):
    sections, frames = layout(family)
    return json.dumps({"sections": sections, "frames": frames})

# ------------------------------------------------------------ big folders
# A folder is read a file at a time (import_sheet.numbered_folder), so the
# page can show progress between steps, and the result is kept for the
# builder instead of reading it all again. -Elvie

_folder = {}

def _folder_key(src, version, opts):
    keep = {k: opts.get(k) for k in ("scale", "background", "lossy", "colors", "reach", "cells")}
    keep["background"] = keep["background"] or "auto"
    keep["lossy"] = "auto" if keep["lossy"] is None else keep["lossy"]
    keep["colors"] = keep["colors"] or 48
    keep["reach"] = 1 if keep["reach"] is None else keep["reach"]
    keep["cells"] = keep["cells"] or {}
    return json.dumps([src, version, keep], sort_keys=True)

def folder_start(src, opts_json, version):
    """Start reading a folder (or find it already read). Then call
    folder_step until it says finished."""
    import import_sheet as I
    opts = json.loads(opts_json)
    key = _folder_key(src, version, opts)
    if _folder.get("key") == key and "result" in _folder:
        return json.dumps({"finished": True})
    _folder.clear()
    _folder.update(key=key, steps=I.numbered_folder(os.path.join(WORK, src), opts))
    return folder_step(1)

def folder_step(n):
    """Read up to n more files: {done, total, finished}."""
    done = total = 0
    try:
        for _ in range(max(1, n)):
            done, total = next(_folder["steps"])
    except StopIteration as e:
        _folder["result"] = e.value
        del _folder["steps"]
        return json.dumps({"finished": True})
    except Exception:
        _folder.clear()
        raise
    return json.dumps({"done": done, "total": total, "finished": False})

def slice_options(argv):
    """The options slice uses for a folder, from its argv."""
    import import_sheet as I
    return json.dumps(I.folder_options(list(argv)[3:]))

def slice_folder_pages(out):
    """The page names the preview of the folder just read will use."""
    import import_sheet as I
    sheet, pieces, cells, rows, _ = _folder["result"]
    pages = _folder["pages"] = I.folder_pages(rows, sheet.width, sheet.height)
    return json.dumps([{"name": I.page_name(out, k), "first": rows[r0][3] if r1 > r0 else 0,
                        "last": rows[r1 - 1][4] if r1 > r0 else 0} for k, (_, _, r0, r1) in enumerate(pages)])

def slice_folder_page(k, out):
    """Draw page k of the preview, as slice does."""
    import import_sheet as I
    sheet, pieces, cells, rows, _ = _folder["result"]
    I.folder_preview(sheet, pieces, cells, rows, page=_folder["pages"][k]).save(
        os.path.join(WORK, I.page_name(out, k)))

def slice_folder_report(out):
    import import_sheet as I
    sheet, pieces, cells, rows, _ = _folder["result"]
    return I.folder_report(rows, pieces, _folder["pages"], out)

def builder_data(src, recipe_json, version=None):
    """What the recipe builder needs, worked out by import_sheet's own
    functions so its numbers match slice and build exactly: the cleaned
    sheet (saved to builder/sheet.png), every piece's box, which pieces are
    whole strip frames, the folder's file rows, and each section's slots
    with their frame size and foot row. -Elvie"""
    import import_sheet as I
    recipe = json.loads(recipe_json)
    family = recipe["family"]
    path = os.path.join(WORK, src)
    out = io.StringIO()
    with redirect_stdout(out), redirect_stderr(out):
        rows, aliases = [], {}
        if os.path.isdir(path):
            if _folder.get("key") == _folder_key(src, version, recipe) and "result" in _folder:
                im, found, cells, rows, aliases = _folder["result"]
            else:
                im, found, cells, rows = I.load_numbered_folder(path, recipe)
                aliases = I.load_numbered_folder.aliases
            pieces = I.split_boxes([found[str(i)] for i in range(1, len(found) + 1)], recipe.get("split"))
            aliases = dict(aliases)
            pages = I.folder_pages(rows, im.width, im.height)
        else:
            im, _, _ = I.clean(path, recipe.get("scale"), recipe.get("background", "auto"),
                               recipe.get("lossy", "auto"), recipe.get("colors", 48))
            pieces = I.split_boxes(I.find_pieces(im, recipe.get("reach", 1)), recipe.get("split"))
            cells = set()
            pages = [(0, im.height, 0, 0)]
    os.makedirs(os.path.join(WORK, "builder"), exist_ok=True)
    im.save(os.path.join(WORK, "builder", "sheet.png"))
    sections, frames = layout(family)
    return json.dumps({
        "width": im.width, "height": im.height,
        "pieces": {k: list(v) for k, v in pieces.items()},
        "cells": sorted(cells, key=lambda s: float(s)),
        "aliases": aliases,
        "rows": [{"file": f, "y": y, "mode": m, "first": a, "last": b} for f, y, m, a, b in rows],
        # a big folder is shown a page at a time, like slice's preview -Elvie
        "pages": [{"top": t, "bottom": b, "from": r0, "to": r1} for t, b, r0, r1 in pages],
        "sections": sections, "frames": frames, "log": out.getvalue(),
    })

def make_gif(raw, width, height, count, delays_json, out):
    """Raw RGBA frames (one after another) -> a looping GIF. Pixel art
    rarely has 255 colours, so the palette is exact; only past that is it
    quantized. Mostly transparent pixels become the transparent index. -Elvie"""
    from PIL import Image
    data = open(os.path.join(WORK, raw), "rb").read()
    size = width * height * 4
    frames = [Image.frombytes("RGBA", (width, height), data[i * size:(i + 1) * size]) for i in range(count)]
    colours = set()
    for f in frames:
        for _, c in f.getcolors(width * height) or []:
            if c[3] >= 128:
                colours.add(c[:3])
    if len(colours) <= 255:
        flat = [v for c in sorted(colours) for v in c]
    else:
        strip = Image.new("RGB", (width, height * count))
        for i, f in enumerate(frames):
            strip.paste(f.convert("RGB"), (0, i * height))
        q = strip.quantize(255, method=Image.Quantize.MEDIANCUT)
        flat = q.getpalette()[:255 * 3]
    flat += [0] * (256 * 3 - len(flat))
    pal = Image.new("P", (1, 1))
    pal.putpalette(flat)
    out_frames = []
    for f in frames:
        p = f.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE)
        clear = f.getchannel("A").point(lambda a: 255 if a < 128 else 0)
        p.paste(255, mask=clear)
        out_frames.append(p)
    path = os.path.join(WORK, out)
    if count == 1:
        # one frame: a still GIF, no timing or looping -Elvie
        out_frames[0].save(path, transparency=255, optimize=False)
    else:
        out_frames[0].save(path, save_all=True, append_images=out_frames[1:],
                           duration=json.loads(delays_json), loop=0,
                           transparency=255, disposal=2, optimize=False)
    return len(colours)

def read_meta(path):
    """A look's meta.json, or {} when missing or unreadable."""
    try:
        with open(os.path.join(WORK, path)) as f:
            return json.dumps(json.load(f))
    except Exception:
        return "{}"

def unzip(src, dst):
    """Unpack an uploaded zip into WORK/dst, skipping anything that would
    land outside it."""
    target = os.path.realpath(os.path.join(WORK, dst))
    with zipfile.ZipFile(os.path.join(WORK, src)) as z:
        for info in z.infolist():
            out = os.path.realpath(os.path.join(target, info.filename))
            if not out.startswith(target + os.sep) or info.is_dir():
                continue
            os.makedirs(os.path.dirname(out), exist_ok=True)
            with z.open(info) as f, open(out, "wb") as g:
                g.write(f.read())
