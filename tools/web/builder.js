// Recipe builder: pick a frame, click the sprite that goes in it. The
// recipe JSON stays the one source: every click rewrites the recipe box,
// and editing the box redraws the builder. Piece numbers, slots, frame
// sizes and foot rows all come from import_sheet itself (builder_data in
// web_runner.py), so they always match slice and build. -Elvie

import { createStage, sceneFor } from "./preview.js";

const FACING_NAMES = { down: "Down", up: "Up", left: "Left", frames: "Frames" };
const SHEET_KEYS = ["scale", "background", "reach", "lossy", "colors", "split", "cells"];

// ------------------------------------------------------------ recipe values
// A slot holds null, a piece ("12", "29.2", "walk:3"), a list of pieces
// drawn as one sprite, or {"piece": ..., "flip", "hang", "shift"}.

function piecesOf(v) {
  if (v === null || v === undefined || v === 0) return [];
  if (Array.isArray(v)) return v.map(String);
  if (typeof v === "object") return piecesOf(v.piece);
  return [String(v)];
}

function optsOf(v) {
  const o = v && typeof v === "object" && !Array.isArray(v) ? v : {};
  return { flip: !!o.flip, hang: Number(o.hang) || 0, shift: Number(o.shift) || 0 };
}

const asRef = (p) => (/^\d+$/.test(p) ? Number(p) : p);

function makeValue(pieces, opts) {
  if (!pieces.length) return null;
  const base = pieces.length === 1 ? asRef(pieces[0]) : pieces.map(asRef);
  const extra = {};
  if (opts.flip) extra.flip = true;
  if (opts.hang) extra.hang = opts.hang;
  if (opts.shift) extra.shift = opts.shift;
  return Object.keys(extra).length ? { piece: base, ...extra } : base;
}

// Short lists and objects on one line, the way the example recipes read.
function inline(v) {
  if (Array.isArray(v)) return "[" + v.map(inline).join(", ") + "]";
  if (v && typeof v === "object") return "{" + Object.entries(v).map(([k, x]) => `${JSON.stringify(k)}: ${inline(x)}`).join(", ") + "}";
  return JSON.stringify(v) ?? "null";
}

export function formatRecipe(v, indent = "") {
  const flat = inline(v);
  if (v === null || typeof v !== "object" || flat.length + indent.length <= 78) return flat;
  const inner = indent + "  ";
  if (Array.isArray(v)) return "[\n" + v.map((x) => inner + formatRecipe(x, inner)).join(",\n") + "\n" + indent + "]";
  return "{\n" + Object.entries(v).map(([k, x]) => `${inner}${JSON.stringify(k)}: ${formatRecipe(x, inner)}`).join(",\n") + "\n" + indent + "}";
}

// ------------------------------------------------------------------ builder

export function createBuilder(api) {
  const $ = (id) => document.getElementById(id);
  const el = {
    open: $("b-open"), family: $("b-family"), work: $("b-work"), empty: $("b-empty"),
    canvas: $("b-canvas"), zoom: $("b-zoom"), tip: $("b-tip"), sections: $("b-sections"),
    where: $("b-where"), chips: $("b-chips"), flip: $("b-flip"), hang: $("b-hang"), shift: $("b-shift"),
    typed: $("b-typed"), clear: $("b-clear"), undo: $("b-undo"), cols: $("b-cols"), rows: $("b-rows"),
    cut: $("b-cut"), cutRow: $("b-cutrow"), cutWhat: $("b-cutwhat"), cutPiece: $("b-cutpiece"),
    cutInto: $("b-cutinto"),
    other: $("b-other"), log: $("b-log"),
    pager: $("b-pager"), page: $("b-page"),
  };
  const stage = createStage($("b-preview"), { zoom: 2, saveGif: api.saveGif, busy: api.busy });
  let data = null;        // from builder_data
  let sheet = null;       // ImageBitmap-like <img> of the cleaned sheet
  let pixels = null;      // its ImageData, for tight boxes
  let sheetKey = "";      // recipe keys the data was made with
  let active = null;      // {key, facing, index}
  let hover = null;       // piece name under the pointer
  let page = 0;           // which page of a big folder is shown
  let notes = {};
  let writing = false;    // true while the builder writes the recipe box
  const history = [];
  const tightCache = new Map();

  // ---------------------------------------------------------- recipe I/O

  function recipe() {
    try {
      const r = JSON.parse(api.getText());
      return r && typeof r === "object" && !Array.isArray(r) ? r : null;
    } catch {
      return null;
    }
  }

  function write(r) {
    const text = formatRecipe(r) + "\n";
    if (text === api.getText()) return;
    history.push(api.getText());
    if (history.length > 200) history.shift();
    writing = true;
    api.setText(text);
    writing = false;
    afterRecipeChange();
  }

  function undo() {
    if (!history.length) return;
    writing = true;
    api.setText(history.pop());
    writing = false;
    afterRecipeChange();
  }

  // The recipe's own slot list for a section, as {facing: [values]}.
  function sectionValues(r, key) {
    const s = r.sections && (r.sections[key] ?? r.sections[Object.keys(r.sections).find((k) => k.toLowerCase() === key)]);
    if (Array.isArray(s)) return { frames: s };
    return s && typeof s === "object" ? s : {};
  }

  function getValue(r, key, facing, index) {
    const f = sectionValues(r, key)[facing];
    return Array.isArray(f) ? f[index] ?? null : null;
  }

  function setValue(key, facing, index, value) {
    const r = recipe();
    if (!r) return;
    r.sections ||= {};
    const realKey = Object.keys(r.sections).find((k) => k.toLowerCase() === key) || key;
    let s = r.sections[realKey];
    const wasList = Array.isArray(s);
    s = wasList ? { frames: s } : s && typeof s === "object" ? s : {};
    const slots = data.sections[key].facings[facing].length;
    const list = Array.isArray(s[facing]) ? s[facing].slice() : [];
    while (list.length < slots) list.push(null);
    list[index] = value;
    s[facing] = list;
    r.sections[realKey] = wasList && facing === "frames" ? list : s;
    write(r);
  }

  // ------------------------------------------------------------- loading

  function keyOf(r) {
    return JSON.stringify([r.family, ...SHEET_KEYS.map((k) => r[k] ?? null), api.sourceId()]);
  }

  async function load() {
    let r = recipe();
    if (!r) {
      if (api.getText().trim()) {
        api.status("Fix the recipe JSON first; the builder edits that same recipe.", "failed");
        return;
      }
      r = { family: el.family.value, sections: {} };
    }
    if (r.files) {
      api.status('This recipe reads a folder of charsets ("files"); edit it as JSON.', "failed");
      return;
    }
    // The builder numbers the sheet the way build will, so the slicing
    // options from step 1 go into the recipe. -Elvie
    Object.assign(r, api.sliceOptions(r));
    if (!["frlg", "rse", "frlg_wide", "rse_wide"].includes(r.family)) r.family = el.family.value;
    r.sections ||= {};
    data = null; // reload below, not from write()
    write(r);
    await reload(true);
  }

  let loading = 0; // reloads in flight; redraws wait for them

  async function reload(force) {
    const r = recipe();
    if (!r || !api.sourceId()) return;
    const key = keyOf(r);
    if (!force && key === sheetKey) return;
    let fresh;
    try {
      fresh = await api.load(r);
    } catch (e) {
      api.status(`The builder couldn't read the sheet: ${e.message}`, "failed");
      return;
    }
    sheetKey = key;
    loading++;
    try {
      // Load everything first, then swap it in at once, so nothing draws
      // half-loaded data. -Elvie
      const img = await new Promise((res, rej) => {
        const im = new Image();
        im.onload = () => res(im);
        im.onerror = () => rej(new Error("the sheet image didn't load"));
        im.src = api.sheetURL();
      });
      const c = document.createElement("canvas");
      c.width = img.width;
      c.height = img.height;
      const cx = c.getContext("2d");
      cx.drawImage(img, 0, 0);
      const px = cx.getImageData(0, 0, c.width, c.height);
      const freshNotes = await api.notes(r.family.replace(/_wide$/, ""));
      if (sheetKey !== key) return; // a newer reload took over
      data = fresh;
      sheet = img;
      pixels = px;
      notes = freshNotes;
      tightCache.clear();
    } catch (e) {
      api.status(`The builder couldn't show the sheet: ${e.message}`, "failed");
      return;
    } finally {
      loading--;
    }
    el.log.hidden = !data.log.trim();
    el.log.textContent = data.log.trim();
    el.family.value = r.family;
    if (!active || !data.sections[active.key]) {
      const first = Object.keys(data.sections)[0];
      active = { key: first, facing: Object.keys(data.sections[first].facings)[0], index: 0 };
    }
    el.empty.hidden = true;
    el.work.hidden = false;
    renderPages();
    if (!el.zoom.dataset.set) {
      const fit = Math.max(1, Math.min(4, Math.floor((el.work.clientWidth - 4) / data.width)));
      el.zoom.value = String(fit);
    }
    renderSections();
    draw();
  }


  // -------------------------------------------------------------- pieces

  function resolve(name) {
    name = String(name);
    return data.pieces[name] ? name : data.aliases[name] && data.pieces[data.aliases[name]] ? data.aliases[name] : null;
  }

  function tight(name) {
    if (tightCache.has(name)) return tightCache.get(name);
    const [x0, y0, x1, y1] = data.pieces[name];
    let a = x1, b = y1, c = x0, d = y0;
    const w = pixels.width, px = pixels.data;
    for (let y = Math.max(0, y0); y < Math.min(y1, pixels.height); y++) {
      for (let x = Math.max(0, x0); x < Math.min(x1, w); x++) {
        if (px[(y * w + x) * 4 + 3]) {
          if (x < a) a = x;
          if (x >= c) c = x + 1;
          if (y < b) b = y;
          if (y >= d) d = y + 1;
        }
      }
    }
    const box = c > a && d > b ? [a, b, c, d] : null;
    tightCache.set(name, box);
    return box;
  }

  // The sprite a slot value makes, placed in its frame the way build's
  // place() does. Returns {canvas, over, shrunk, missing}.
  // The first frame of this file holding the same value: a sprite used for
  // several frames sits on that frame's row, as build does. -Elvie
  function firstUse(file, index, value) {
    const r = recipe() || {};
    const want = JSON.stringify(value ?? null);
    let best = index;
    for (const [key, sec] of Object.entries(data.sections)) {
      const vals = (r.sections || {})[key];
      if (!vals) continue;
      for (const [facing, slots] of Object.entries(sec.facings)) {
        const list = Array.isArray(vals) ? (facing === "frames" ? vals : null) : vals[facing];
        if (!Array.isArray(list)) continue;
        slots.forEach(([f, i], k) => {
          if (f === file && i < best && JSON.stringify(list[k] ?? null) === want) best = i;
        });
      }
    }
    return best;
  }

  function placed(value, file, sectionKey, index) {
    const [w, h, , fileBottom, rows] = data.frames[file];
    const bottom = rows && index !== undefined ? rows[firstUse(file, index, value)] : fileBottom;
    const out = document.createElement("canvas");
    out.width = w;
    out.height = h;
    const names = piecesOf(value);
    if (!names.length) return { canvas: out };
    const missing = names.filter((n) => !resolve(n));
    if (missing.length) return { canvas: out, missing };
    const real = names.map(resolve);
    const o = optsOf(value);
    const cell = real.length === 1 && data.cells.includes(real[0]);
    const boxes = cell ? [data.pieces[real[0]]] : real.map(tight).filter(Boolean);
    if (!boxes.length) return { canvas: out };
    const x0 = Math.min(...boxes.map((b) => b[0])), y0 = Math.min(...boxes.map((b) => b[1]));
    const x1 = Math.max(...boxes.map((b) => b[2])), y1 = Math.max(...boxes.map((b) => b[3]));
    let sw = x1 - x0, sh = y1 - y0;
    const spr = document.createElement("canvas");
    spr.width = sw;
    spr.height = sh;
    const sx = spr.getContext("2d");
    for (const b of boxes) sx.drawImage(sheet, b[0], b[1], b[2] - b[0], b[3] - b[1], b[0] - x0, b[1] - y0, b[2] - b[0], b[3] - b[1]);
    let src = spr, shrunk = false;
    const r = recipe() || {};
    const shrinkKeys = (r.shrink || []).map((k) => String(k).toLowerCase());
    // strip frames shrink too, whole cell and all, as build's shrink() does -Elvie
    if (shrinkKeys.includes(sectionKey)) {
      const k = Math.min(1, w / sw, bottom / sh);
      if (k < 1) {
        const small = document.createElement("canvas");
        small.width = Math.max(1, Math.floor(sw * k));
        small.height = Math.max(1, Math.floor(sh * k));
        const s2 = small.getContext("2d");
        s2.imageSmoothingEnabled = false;
        s2.drawImage(spr, 0, 0, small.width, small.height);
        src = small;
        sw = small.width;
        sh = small.height;
        shrunk = true;
      }
    }
    const x = Math.floor((w - sw) / 2) + o.shift;
    const y = (cell ? h : bottom) - sh + o.hang;
    const over = !cell && (x < 0 || x + sw > w || y < 0 || y + sh > h + o.hang);
    const cx = out.getContext("2d");
    cx.save();
    if (o.flip) {
      cx.translate(x + sw, 0);
      cx.scale(-1, 1);
      cx.drawImage(src, 0, y);
    } else {
      cx.drawImage(src, x, y);
    }
    cx.restore();
    return { canvas: out, over, shrunk, size: [sw, sh] };
  }

  // ------------------------------------------------------------ sections

  function slotsOf(key) {
    return data.sections[key].facings;
  }

  function renderSections() {
    const r = recipe() || {};
    const open = new Set([...el.sections.querySelectorAll("details[open]")].map((d) => d.dataset.key));
    const firstRender = !el.sections.children.length;
    el.sections.replaceChildren();
    for (const [key, sec] of Object.entries(data.sections)) {
      const values = sectionValues(r, key);
      const total = Object.values(sec.facings).reduce((n, s) => n + s.length, 0);
      const filled = Object.entries(sec.facings).reduce(
        (n, [f, s]) => n + s.filter((_, i) => piecesOf((values[f] || [])[i]).length).length, 0);
      const det = document.createElement("details");
      det.dataset.key = key;
      det.className = "b-section";
      det.open = open.has(key) || (active && active.key === key) || (firstRender && filled > 0);
      const sum = document.createElement("summary");
      const name = document.createElement("span");
      name.className = "b-name";
      name.textContent = key;
      const count = document.createElement("span");
      count.className = "b-count";
      count.textContent = `${filled} of ${total}`;
      sum.append(name, count);
      det.append(sum);
      const note = notes[key];
      if (note) {
        const p = document.createElement("p");
        p.className = "b-note";
        p.textContent = note;
        det.append(p);
      }
      const shrinkKeys = (r.shrink || []).map((k) => String(k).toLowerCase());
      const shrinkBox = document.createElement("label");
      shrinkBox.className = "b-shrink";
      const cb = document.createElement("input");
      cb.type = "checkbox";
      cb.checked = shrinkKeys.includes(key);
      cb.addEventListener("change", () => {
        const rr = recipe();
        if (!rr) return;
        const list = (rr.shrink || []).filter((k) => String(k).toLowerCase() !== key);
        if (cb.checked) list.push(key);
        if (list.length) rr.shrink = list;
        else delete rr.shrink;
        write(rr);
      });
      shrinkBox.append(cb, " Shrink sprites that are too big");
      const grid = document.createElement("div");
      grid.className = "b-grid";
      for (const [facing, slots] of Object.entries(sec.facings)) {
        const label = document.createElement("span");
        label.className = "b-facing";
        label.textContent = FACING_NAMES[facing] || facing;
        const row = document.createElement("div");
        row.className = "b-row";
        slots.forEach(([file, frame], i) => row.append(slotButton(key, facing, i, file, frame, (values[facing] || [])[i] ?? null)));
        grid.append(label, row);
      }
      det.append(grid, shrinkBox);
      // Opening a section moves the selection to its first frame.
      sum.addEventListener("click", () => {
        if (!det.open && (!active || active.key !== key)) select({ key, facing: Object.keys(sec.facings)[0], index: 0 });
      });
      el.sections.append(det);
    }
    const known = new Set(Object.keys(data.sections));
    const others = Object.keys(r.sections || {}).filter((k) => !known.has(k.toLowerCase()));
    el.other.hidden = !others.length;
    el.other.textContent = others.length
      ? `Also in the recipe, edited in the JSON only: ${others.join(", ")}.` +
        (others.some((k) => k.toLowerCase() === "surf with blob") ? "" : " A section the family doesn't have is skipped by build.")
      : "";
    inspect();
    preview();
  }

  // ------------------------------------------------------------- preview

  // A section's frames as build will place them, for the preview stage.
  function sectionFrames(r, key) {
    const sec = data.sections[key];
    if (!sec) return () => null;
    const values = sectionValues(r, key);
    const made = new Map();
    return (facing, i) => {
      const id = facing + i;
      if (!made.has(id)) {
        const slot = (sec.facings[facing] || [])[i];
        const v = slot ? (values[facing] || [])[i] ?? null : null;
        const p = slot && piecesOf(v).length ? placed(v, slot[0], key, slot[1]) : null;
        made.set(id, p && !p.missing ? p.canvas : null);
      }
      return made.get(id);
    };
  }

  function preview() {
    if (!data || !active) return;
    const r = recipe() || {};
    const sec = data.sections[active.key];
    const blobSec = data.sections["surf blob"];
    const first = Object.values(sec.facings)[0][0][0];
    stage.show(sceneFor(active.key, r.family || "rse", sec), {
      frame: sectionFrames(r, active.key),
      blob: sectionFrames(r, "surf blob"),
      blobCount: (facing) => (blobSec && blobSec.facings[facing] ? blobSec.facings[facing].length : 0),
      diveBlob: (facing) => sectionFrames(r, "dive blob")(facing, 0),
      size: () => data.frames[first].slice(0, 2),
    }, `Preview: ${active.key}`, api.gifName ? api.gifName(r.family || "rse", active.key) : null);
  }

  function slotButton(key, facing, index, file, frame, value) {
    const b = document.createElement("button");
    b.type = "button";
    b.className = "b-slot";
    const isActive = active && active.key === key && active.facing === facing && active.index === index;
    if (isActive) b.classList.add("active");
    const p = placed(value, file, key, frame);
    const [w, h] = data.frames[file];
    const scale = w <= 16 && h <= 16 ? 3 : w <= 32 && h <= 32 ? 2 : 1;
    p.canvas.style.width = w * scale + "px";
    p.canvas.style.height = h * scale + "px";
    b.append(p.canvas);
    const names = piecesOf(value);
    const tag = document.createElement("span");
    tag.className = "b-tag";
    tag.textContent = names.length ? names.join("+") + (optsOf(value).flip ? " ↔" : "") : String(index + 1);
    b.append(tag);
    let what = `${key}, ${FACING_NAMES[facing] || facing} ${index + 1}: ${file} frame ${frame}, ${w}x${h}`;
    if (!names.length) b.classList.add("empty");
    if (p.missing) {
      b.classList.add("bad");
      what += `. ${p.missing.join(", ")} isn't on the sheet`;
    } else if (p.over) {
      b.classList.add("bad");
      what += `. The sprite is ${p.size[0]}x${p.size[1]}, so its edges get cut off`;
    } else if (p.shrunk) {
      what += ". Shrunk to fit";
    }
    b.title = what;
    b.setAttribute("aria-label", what + (names.length ? `. Pieces ${names.join(", ")}` : ". Empty"));
    b.setAttribute("aria-pressed", isActive ? "true" : "false");
    b.addEventListener("click", () => select({ key, facing, index }));
    return b;
  }

  function select(slot) {
    const hadFocus = document.activeElement && document.activeElement.classList.contains("b-slot");
    active = slot;
    follow(current());
    renderSections();
    draw();
    const btn = el.sections.querySelector(".b-slot.active");
    if (btn && hadFocus) btn.focus();
  }

  function next() {
    const facings = slotsOf(active.key);
    const order = Object.keys(facings);
    let { facing, index } = active;
    if (index + 1 < facings[facing].length) index++;
    else if (order.indexOf(facing) + 1 < order.length) {
      facing = order[order.indexOf(facing) + 1];
      index = 0;
    }
    active = { key: active.key, facing, index };
  }

  // ----------------------------------------------------------- inspector

  function current() {
    const r = recipe();
    return r && active ? getValue(r, active.key, active.facing, active.index) : null;
  }

  function inspect() {
    if (!active) return;
    const [file, frame] = slotsOf(active.key)[active.facing][active.index];
    el.where.textContent = `${active.key}, ${(FACING_NAMES[active.facing] || active.facing).toLowerCase()} ${active.index + 1} (${file} frame ${frame})`;
    const v = current();
    const names = piecesOf(v);
    el.chips.textContent = names.length ? names.join(" + ") : "empty";
    const o = optsOf(v);
    el.flip.checked = o.flip;
    el.hang.value = o.hang || "";
    el.shift.value = o.shift || "";
    if (document.activeElement !== el.typed) el.typed.value = names.join(" ");
    [el.flip, el.hang, el.shift, el.clear].forEach((x) => (x.disabled = !names.length));
    showCut(names);
    el.undo.disabled = !history.length;
  }

  function setActive(names, opts) {
    setValue(active.key, active.facing, active.index, makeValue(names, opts));
  }

  el.flip.addEventListener("change", () => setActive(piecesOf(current()), { ...optsOf(current()), flip: el.flip.checked }));
  el.hang.addEventListener("change", () => setActive(piecesOf(current()), { ...optsOf(current()), hang: Number(el.hang.value) || 0 }));
  el.shift.addEventListener("change", () => setActive(piecesOf(current()), { ...optsOf(current()), shift: Number(el.shift.value) || 0 }));
  el.clear.addEventListener("click", () => setActive([], {}));
  el.undo.addEventListener("click", undo);
  el.typed.addEventListener("keydown", (e) => {
    if (e.key !== "Enter") return;
    e.preventDefault();
    const names = el.typed.value.split(/[\s,+]+/).filter(Boolean);
    const bad = names.filter((n) => !resolve(n));
    if (bad.length) {
      api.status(`${bad.join(", ")} isn't on the sheet.`, "failed");
      return;
    }
    setActive(names, optsOf(current()));
    follow(names);
    if (names.length) {
      next();
      afterRecipeChange();
    }
  });
  // Cut is offered for any piece in the frame, strip frames and pieces
  // already cut included: a cut piece is cut again from the whole one, and
  // 1 by 1 puts it back together. -Elvie
  let cutTarget = null; // the piece the Cut row is for
  let cutFilled = null; // the piece whose cut is filled in below

  function baseOf(name) {
    return name.includes(".") ? name.slice(0, name.indexOf(".")) : name;
  }

  function showCut(names) {
    const bases = [...new Set(names.map(resolve).filter(Boolean).map(baseOf))];
    el.cutRow.hidden = !bases.length;
    if (!bases.length) return;
    let target = bases[0];
    if (bases.length > 1) {
      const keep = bases.includes(cutTarget) ? cutTarget : bases[0];
      el.cutPiece.replaceChildren(...bases.map((b) => new Option(`piece ${b}`, b)));
      el.cutPiece.value = target = keep;
    }
    el.cutPiece.hidden = bases.length < 2;
    const split = (recipe() || {}).split || {};
    const grid = split[target];
    const again = grid !== undefined;
    const into = again ? "(1 by 1 puts it back together) into" : "into";
    const what = again ? "Cut again" : "Two sprites stuck together? Cut";
    el.cutWhat.textContent = bases.length > 1 ? what : `${what} piece ${target} ${into}`;
    el.cutInto.textContent = into;
    el.cutInto.hidden = bases.length < 2;
    cutTarget = target;
    if (target === cutFilled) return; // only when the piece changes, not while typing
    cutFilled = target;
    const [cols, rows] = grid === undefined ? [2, 1] : Array.isArray(grid) ? grid : [grid, 1];
    el.cols.value = String(cols);
    el.rows.value = String(rows);
  }

  el.cutPiece.addEventListener("change", () => {
    cutTarget = el.cutPiece.value;
    showCut(piecesOf(current()));
  });

  el.cut.addEventListener("click", async () => {
    const name = cutTarget;
    const cols = Number(el.cols.value) || 1, rows = Number(el.rows.value) || 1;
    if (!name || !data.pieces[name]) return;
    const r = recipe();
    const split = { ...(r.split || {}) };
    if (cols * rows < 2) {
      if (!(name in split)) return;
      delete split[name];
    } else {
      split[name] = rows > 1 ? [cols, rows] : cols;
    }
    if (Object.keys(split).length) r.split = split;
    else delete r.split;
    cutFilled = null;
    write(r); // the new split reloads the sheet
    api.status(cols * rows < 2 ? `Piece ${name} is whole again.` : `Piece ${name} is now cut into ${name}.1 to ${name}.${cols * rows}.`, "ready");
  });

  // --------------------------------------------------------------- sheet

  function zoom() {
    return Number(el.zoom.value) || 1;
  }

  function usedPieces() {
    const r = recipe();
    const used = new Set();
    if (!r || !r.sections) return used;
    for (const s of Object.values(r.sections)) {
      const facings = Array.isArray(s) ? { frames: s } : s || {};
      for (const list of Object.values(facings)) {
        if (Array.isArray(list)) list.forEach((v) => piecesOf(v).forEach((n) => resolve(n) && used.add(resolve(n))));
      }
    }
    return used;
  }

  // A big folder is drawn a page at a time (the pages slice's preview
  // uses), since one canvas that tall runs out of memory, on phones most
  // of all. Typed numbers still reach every page. -Elvie
  function pageBox() {
    const p = data.pages[page] || data.pages[0];
    return { top: p.top, bottom: p.bottom };
  }

  function renderPages() {
    const pages = data.pages;
    if (page >= pages.length) page = 0;
    el.page.replaceChildren(
      ...pages.map((p, k) => {
        const a = data.rows[p.from], b = data.rows[p.to - 1];
        const nums = a && b && b.last >= a.first ? `: pieces ${a.first}-${b.last}` : "";
        return new Option(`${k + 1} of ${pages.length}${nums}`, k);
      })
    );
    el.page.value = String(page);
    el.pager.hidden = pages.length < 2;
  }

  // Show the page with this frame's piece on it.
  function follow(v) {
    if (!data || data.pages.length < 2) return;
    const n = piecesOf(v).map(resolve).find((x) => x && data.pieces[x]);
    if (!n) return;
    const y = data.pieces[n][1];
    const k = data.pages.findIndex((p) => y >= p.top && y < p.bottom);
    if (k >= 0 && k !== page) {
      page = k;
      el.page.value = String(k);
    }
  }

  el.page.addEventListener("change", () => {
    page = Number(el.page.value) || 0;
    hover = null;
    draw();
  });

  function draw() {
    if (!data || !sheet) return;
    const z = zoom();
    const c = el.canvas;
    const { top, bottom } = pageBox();
    c.width = data.width * z;
    c.height = (bottom - top) * z;
    const g = c.getContext("2d");
    g.imageSmoothingEnabled = false;
    g.drawImage(sheet, 0, top, data.width, bottom - top, 0, 0, c.width, c.height);
    g.translate(0, -top * z);
    const used = usedPieces();
    const mine = new Set(piecesOf(current()).map(resolve).filter(Boolean));
    const style = getComputedStyle(document.documentElement);
    const guide = style.getPropertyValue("--guide").trim() || "#ff00ff";
    const act = style.getPropertyValue("--act").trim() || "#0d5c48";
    g.font = `${Math.max(9, 4 * z + 2)}px ui-monospace, monospace`;
    g.textBaseline = "top";
    for (const row of data.rows) {
      if (row.y < top || row.y >= bottom) continue;
      g.fillStyle = act;
      g.fillText(`${row.file}  (${row.first}-${row.last})`, 2, row.y * z + 1);
    }
    const names = Object.keys(data.pieces);
    for (const n of names) {
      const [x0, y0, x1, y1] = data.pieces[n];
      if (y1 <= top || y0 >= bottom) continue;
      const strong = mine.has(n) || hover === n;
      g.globalAlpha = strong ? 1 : used.has(n) ? 0.25 : 0.55;
      g.strokeStyle = guide;
      g.lineWidth = strong ? 2 : 1;
      g.strokeRect(x0 * z + 0.5, y0 * z + 0.5, (x1 - x0) * z - 1, (y1 - y0) * z - 1);
      if (strong || z >= 2) {
        const label = n;
        const tw = g.measureText(label).width + 4;
        const th = Math.max(9, 4 * z + 2) + 2;
        g.globalAlpha = strong ? 1 : used.has(n) ? 0.35 : 0.8;
        g.fillStyle = guide;
        g.fillRect(x0 * z, y0 * z, tw, th);
        g.fillStyle = "#ffffff";
        g.fillText(label, x0 * z + 2, y0 * z + 1);
      }
    }
    g.globalAlpha = 1;
    inspect();
  }

  function pieceAt(e) {
    const rect = el.canvas.getBoundingClientRect();
    const z = zoom();
    const x = (e.clientX - rect.left) * (el.canvas.width / rect.width) / z;
    const y = (e.clientY - rect.top) * (el.canvas.height / rect.height) / z + pageBox().top;
    let best = null, area = Infinity;
    for (const [n, [x0, y0, x1, y1]] of Object.entries(data.pieces)) {
      if (x >= x0 && x < x1 && y >= y0 && y < y1) {
        const a = (x1 - x0) * (y1 - y0);
        if (a < area) {
          best = n;
          area = a;
        }
      }
    }
    return best;
  }

  el.canvas.addEventListener("pointermove", (e) => {
    if (!data) return;
    const n = pieceAt(e);
    if (n !== hover) {
      hover = n;
      draw();
    }
    el.tip.textContent = n ? `Piece ${n}` : "";
  });
  el.canvas.addEventListener("pointerleave", () => {
    hover = null;
    el.tip.textContent = "";
    draw();
  });
  el.canvas.addEventListener("click", (e) => {
    if (!data || !active) return;
    const n = pieceAt(e);
    if (!n) return;
    const v = current();
    if (e.shiftKey || e.ctrlKey || e.metaKey) {
      // add to this frame, drawn together as one sprite
      const names = piecesOf(v).map((x) => resolve(x) || x);
      const at = names.indexOf(n);
      if (at >= 0) names.splice(at, 1);
      else names.push(n);
      setActive(names, optsOf(v));
      return;
    }
    setActive([n], optsOf(v));
    next();
    afterRecipeChange();
  });

  el.zoom.addEventListener("change", () => {
    el.zoom.dataset.set = "1";
    draw();
  });

  // ----------------------------------------------------------- the rest

  function afterRecipeChange() {
    if (!data || loading) return;
    const r = recipe();
    if (!r) return;
    if (keyOf(r) !== sheetKey) {
      reload(false);
      return;
    }
    renderSections();
    draw();
  }

  let timer = 0;
  api.onRecipeInput(() => {
    if (writing) return;
    clearTimeout(timer);
    timer = setTimeout(afterRecipeChange, 400);
  });

  el.family.addEventListener("change", () => {
    const r = recipe();
    if (!r || !data) return;
    r.family = el.family.value;
    write(r);
    reload(true);
  });

  el.open.addEventListener("click", () => api.busy(el.open, load));

  document.addEventListener("keydown", (e) => {
    if (!data || el.work.hidden) return;
    const t = e.target;
    if (t && (t.tagName === "TEXTAREA" || t.tagName === "INPUT" || t.tagName === "SELECT")) return;
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "z") {
      e.preventDefault();
      undo();
    }
  });

  return {
    sourceChanged() {
      sheetKey = "";
      if (data && api.sourceId()) reload(true);
      else if (!api.sourceId()) {
        el.work.hidden = true;
        el.empty.hidden = false;
      }
    },
    refreshTheme: draw,
  };
}
