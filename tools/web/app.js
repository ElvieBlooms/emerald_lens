// Emerald Lens sprite tools, page side. All the work is done by the tools'
// own Python, run in the browser with Pyodide (web_runner.py). -Elvie

import { createBuilder } from "./builder.js";
import { createStage, sceneFor } from "./preview.js";
import { createClashPicker } from "./merge.js";

const PYODIDE_VERSION = "314.0.7";
const CDN = `https://cdn.jsdelivr.net/pyodide/v${PYODIDE_VERSION}/full/`;
// A copy of Pyodide in web/pyodide/ is used instead of the CDN when present.
const LOCAL = new URL("pyodide/", import.meta.url).href;
const TOOLS = new URL("../sprite-templates/", import.meta.url).href;
const TOOL_FILES = ["pack_gen3.py", "import_sheet.py"];
const BLANK = { frlg: "recipes/blank_frlg.json", rse: "recipes/blank_rse.json" };
const FAMILY_NAMES = { frlg: "FireRed / LeafGreen", rse: "Ruby / Sapphire / Emerald" };

const $ = (id) => document.getElementById(id);
let py = null, FS = null, W = null;
const state = {
  src: null,          // source sheet or folder, under src/
  srcIsFolder: false,
  srcVersion: 0,      // bumped on every new source, so the builder reloads
  built: [],          // sheets from build, under built/
  builtFamily: null,
  own: [],            // own sheets to pack, under pack/
  ownFolder: null,
  recipeName: "recipe.json",
  folderTouched: false,
};

// ------------------------------------------------------------------ setup

function status(msg, kind = "") {
  const el = $("status");
  el.textContent = msg;
  el.className = "status " + kind;
}

async function fetchText(url) {
  const r = await fetch(url, { cache: "no-cache" });
  if (!r.ok) throw new Error(`${url} answered ${r.status}`);
  return r.text();
}

async function pyodideBase() {
  try {
    const r = await fetch(LOCAL + "pyodide.mjs", { method: "HEAD" });
    if (r.ok) return LOCAL;
  } catch {}
  return CDN;
}

async function boot() {
  try {
    const base = await pyodideBase();
    const { loadPyodide } = await import(base + "pyodide.mjs");
    py = await loadPyodide({ indexURL: base });
    await py.loadPackage("pillow");
    FS = py.FS;
    FS.mkdirTree("/lens/tools");
    FS.mkdirTree("/lens/work");
    FS.writeFile("/lens/web_runner.py", await fetchText(new URL("web_runner.py", import.meta.url)));
    for (const f of TOOL_FILES) FS.writeFile("/lens/tools/" + f, await fetchText(TOOLS + f));
    py.runPython("import sys; sys.path.insert(0, '/lens')");
    W = py.pyimport("web_runner");
    W.setup();
    status("Ready.", "ready");
  } catch (e) {
    console.error(e);
    status(`The tools didn't load: ${e.message}. Check your connection and reload the page.`, "failed");
  }
  refresh();
}

// ------------------------------------------------------------- filesystem

const work = (p) => "/lens/work/" + p;

function writeFile(path, bytes) {
  const full = work(path);
  FS.mkdirTree(full.slice(0, full.lastIndexOf("/")));
  FS.writeFile(full, bytes);
}

function list(path) {
  if (!FS.analyzePath(work(path)).exists) return [];
  return JSON.parse(W.files(path));
}

const exists = (path) => FS.analyzePath(work(path)).exists;

// Object URLs per container, freed when the container is redrawn.
const urls = new Map();
function imageURL(path, owner) {
  const url = URL.createObjectURL(new Blob([FS.readFile(work(path))], { type: "image/png" }));
  if (!urls.has(owner)) urls.set(owner, []);
  urls.get(owner).push(url);
  return url;
}
function freeURLs(owner) {
  for (const u of urls.get(owner) || []) URL.revokeObjectURL(u);
  urls.delete(owner);
}

function download(bytes, name, type) {
  const url = URL.createObjectURL(new Blob([bytes], { type }));
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}

// Uploads become [{file, path}], path relative and with folders kept.
function fromInput(input) {
  return [...input.files].map((f) => ({ file: f, path: f.webkitRelativePath || f.name }));
}

async function fromDrop(dt) {
  const entries = [...dt.items].map((i) => i.webkitGetAsEntry && i.webkitGetAsEntry()).filter(Boolean);
  if (!entries.length) return [...dt.files].map((f) => ({ file: f, path: f.name }));
  const out = [];
  async function walk(entry, prefix) {
    if (entry.isFile) {
      const file = await new Promise((res, rej) => entry.file(res, rej));
      out.push({ file, path: prefix + file.name });
      return;
    }
    const reader = entry.createReader();
    for (;;) {
      const batch = await new Promise((res, rej) => reader.readEntries(res, rej));
      if (!batch.length) break;
      for (const e of batch) await walk(e, prefix + entry.name + "/");
    }
  }
  for (const e of entries) await walk(e, "");
  return out;
}

// Write uploads under dir. Returns {path, isFolder}: one plain file stays a
// file, a zip is unpacked, anything else becomes a folder.
async function store(items, dir, fallbackName) {
  W.clear(dir);
  items = items.filter((i) => !i.path.split("/").some((p) => p.startsWith(".")));
  if (!items.length) throw new Error("No files found there.");
  if (items.length === 1 && !items[0].path.includes("/")) {
    const { file } = items[0];
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (/\.zip$/i.test(file.name)) {
      const name = file.name.replace(/\.zip$/i, "");
      writeFile(`upload/${file.name}`, bytes);
      W.unzip(`upload/${file.name}`, `${dir}/${name}`);
      W.clear("upload");
      return { path: W.single_dir(`${dir}/${name}`), isFolder: true, name: file.name };
    }
    writeFile(`${dir}/${file.name}`, bytes);
    return { path: `${dir}/${file.name}`, isFolder: false, name: file.name };
  }
  const tops = new Set(items.map((i) => (i.path.includes("/") ? i.path.split("/")[0] : "")));
  const top = tops.size === 1 && !tops.has("") ? [...tops][0] : null;
  const folder = top || fallbackName;
  for (const { file, path } of items) {
    const rel = top ? path.slice(top.length + 1) : path;
    writeFile(`${dir}/${folder}/${rel}`, new Uint8Array(await file.arrayBuffer()));
  }
  return { path: `${dir}/${folder}`, isFolder: true, name: `${folder} (${items.length} files)` };
}

// ------------------------------------------------------------------ running

const quote = (s) => (/^[\w./:#=-]+$/.test(s) ? s : `'${s.replace(/'/g, "'\\''")}'`);

function log(el, html) {
  el.hidden = false;
  el.append(html);
  el.scrollTop = el.scrollHeight;
}

function logRun(el, script, argv, code, out) {
  const cmd = document.createElement("span");
  cmd.className = "cmd";
  cmd.textContent = `$ python3 ${script} ${argv.map(quote).join(" ")}\n`;
  log(el, cmd);
  for (const line of out.replace(/\s+$/, "").split("\n")) {
    const span = document.createElement("span");
    const t = line.trim();
    if (/^(ERROR|Traceback)/.test(t) || (code && line === out.trim().split("\n").pop())) span.className = "bad";
    else if (/^(warning|skipped|skip |blank)/.test(t)) span.className = "warn";
    span.textContent = line + "\n";
    log(el, span);
  }
}

const pause = () => new Promise((r) => setTimeout(r, 20));

async function busy(button, fn) {
  const all = [...document.querySelectorAll("button")];
  const was = all.map((b) => b.disabled);
  all.forEach((b) => (b.disabled = true));
  button.classList.add("busy");
  const label = button.textContent;
  button.textContent = "Working…";
  await pause(); // let the page draw before Python takes the thread
  try {
    await fn();
  } catch (e) {
    console.error(e);
    status(e.message, "failed");
  } finally {
    button.textContent = label;
    button.classList.remove("busy");
    all.forEach((b, i) => b.isConnected && (b.disabled = was[i]));
    refresh();
  }
}

function run(script, argv, logEl) {
  const result = W.run(script, py.toPy(argv));
  const [code, out] = result.toJs();
  result.destroy();
  logRun(logEl, script, argv, code, out);
  return code;
}

// --------------------------------------------------------------- previews

// A preview's frames -> GIF via Pillow (web_runner.make_gif), downloaded.
async function saveGif({ width, height, frames, delays, name }) {
  const size = width * height * 4;
  const raw = new Uint8Array(size * frames.length);
  frames.forEach((f, i) => raw.set(f, i * size));
  W.clear("gif");
  writeFile("gif/frames.raw", raw);
  W.make_gif("gif/frames.raw", width, height, frames.length, JSON.stringify(delays), "gif/out.gif");
  const bytes = FS.readFile(work("gif/out.gif"));
  download(bytes, name, "image/gif");
  const kb = Math.round(bytes.length / 1024);
  status(`Saved ${name} (${frames.length} frame${frames.length === 1 ? "" : "s"}, ${kb} KB).`, "ready");
}

// "kris-rse-walk": the look's folder name, or "sprite" before it has one
function gifName(fam, key) {
  const folder = ($("m-folder").value || "").trim() || "sprite";
  return `${folder}-${fam}-${key}`;
}

function zoomed(img, zoom) {
  const apply = () => (img.style.width = img.naturalWidth * zoom + "px");
  img.complete ? apply() : img.addEventListener("load", apply, { once: true });
}

function showImage(container, path, zoom = 1) {
  freeURLs(container.id);
  container.replaceChildren();
  const img = new Image();
  img.alt = path.split("/").pop();
  img.src = imageURL(path, container.id);
  zoomed(img, zoom);
  container.append(img);
}

document.querySelectorAll("select.zoom").forEach((sel) =>
  sel.addEventListener("change", () => {
    const img = $(sel.dataset.for).querySelector("img");
    if (img) zoomed(img, Number(sel.value));
  })
);

function sheetCard(path, owner, extra) {
  const name = path.split("/").pop();
  const card = document.createElement("figure");
  card.className = "sheet";
  card.style.margin = "0";
  const frame = document.createElement("div");
  frame.className = "frame";
  const img = new Image();
  img.alt = name;
  img.src = imageURL(path, owner);
  frame.append(img);
  const cap = document.createElement("figcaption");
  cap.className = "cap";
  const strong = document.createElement("strong");
  strong.textContent = name;
  const dl = document.createElement("button");
  dl.type = "button";
  dl.className = "btn";
  dl.textContent = "Download";
  dl.addEventListener("click", () => download(FS.readFile(work(path)), name, "image/png"));
  cap.append(strong, dl);
  if (extra) cap.append(extra);
  card.append(frame, cap);
  return card;
}

// ------------------------------------------------------------- 1. source

async function setSource(items) {
  const s = await store(items, "src", "source");
  state.src = s.path;
  state.srcIsFolder = s.isFolder;
  const el = $("src-name");
  el.hidden = false;
  el.textContent = s.isFolder ? `Folder: ${s.name}` : `Sheet: ${s.name}`;
  $("slice-result").hidden = true;
  state.srcVersion++;
  builder.sourceChanged();
}

function sliceArgs() {
  const a = ["slice", state.src, "numbers.png"];
  const scale = $("o-scale").value.trim();
  const bg = $("o-bg").value.trim();
  const reach = $("o-reach").value.trim();
  if (scale) a.push("--scale", scale);
  if (bg && bg !== "auto") a.push("--bg", bg.startsWith("#") ? bg : "#" + bg);
  if (reach) a.push("--reach", reach);
  if (!state.srcIsFolder) {
    const lossy = $("o-lossy").value;
    const colors = $("o-colors").value.trim();
    if (lossy) a.push("--lossy", lossy);
    if (colors) a.push("--colors", colors);
  }
  return a;
}

// ------------------------------------------------------------ big folders
// A folder is read a file at a time (web_runner.folder_step) so a bar can
// show how far along it is; Python holds the page while it works, so it
// works in short steps. A big folder's preview comes in pages, the same
// pages slice writes on the command line. -Elvie

let folderQueue = Promise.resolve();

function progress(el, done, total, text) {
  el.hidden = false;
  const bar = el.querySelector("progress");
  bar.max = total || 1;
  bar.value = done;
  el.querySelector("span").textContent = text;
}

// Read the source folder with these options (kept for the builder too).
// One read at a time; a second waits for the first. -Elvie
function readFolder(opts, el) {
  const job = folderQueue.then(async () => {
    let p = JSON.parse(W.folder_start(state.src, JSON.stringify(opts), state.srcVersion));
    while (!p.finished) {
      progress(el, p.done, p.total, `Reading image ${p.done} of ${p.total}`);
      await pause();
      p = JSON.parse(W.folder_step(document.hidden ? 64 : 8));
    }
  });
  folderQueue = job.catch(() => {});
  return job;
}

let slicePages = [];

function showSlicePages(pages) {
  slicePages = pages;
  const sel = $("slice-page");
  sel.replaceChildren(
    ...pages.map((p, k) => new Option(p.first && p.last >= p.first ? `${k + 1} of ${pages.length}: pieces ${p.first}-${p.last}` : `${k + 1} of ${pages.length}`, k))
  );
  $("slice-pager").hidden = pages.length < 2;
  $("slice-result").hidden = false;
  showSlicePage(0);
}

function showSlicePage(k) {
  $("slice-page").value = String(k);
  showImage($("slice-view"), slicePages[k].name, Number(document.querySelector("[data-for=slice-view]").value));
}

$("slice-page").addEventListener("change", (e) => showSlicePage(Number(e.target.value)));

async function sliceFolder(argv) {
  const el = $("slice-progress");
  try {
    await readFolder(JSON.parse(W.slice_options(py.toPy(argv))), el);
    const pages = JSON.parse(W.slice_folder_pages("numbers.png"));
    for (let k = 0; k < pages.length; k++) {
      if (pages.length > 1) {
        progress(el, k, pages.length, `Drawing page ${k + 1} of ${pages.length}`);
        await pause();
      }
      W.slice_folder_page(k, "numbers.png");
    }
    logRun($("slice-log"), "import_sheet.py", argv, 0, W.slice_folder_report("numbers.png"));
    showSlicePages(pages);
  } catch (e) {
    console.error(e);
    // run the command itself, so the log shows the error as the CLI would
    if (run("import_sheet.py", argv, $("slice-log")) === 0) status("Numbered, but not in steps; see the console.", "failed");
  } finally {
    el.hidden = true;
  }
}

$("do-slice").addEventListener("click", (e) =>
  busy(e.currentTarget, async () => {
    for (const p of slicePages) W.clear(p.name);
    slicePages = [];
    $("slice-result").hidden = true;
    const argv = sliceArgs();
    if (state.srcIsFolder) return sliceFolder(argv);
    const code = run("import_sheet.py", argv, $("slice-log"));
    if (code === 0 && exists("numbers.png")) showSlicePages([{ name: "numbers.png" }]);
  })
);

// ------------------------------------------------------------- 2. recipe

const recipeBox = $("recipe");
try {
  const saved = localStorage.getItem("lens.recipe");
  if (saved) recipeBox.value = saved;
} catch {}

function parseRecipe() {
  const err = $("recipe-error");
  const text = recipeBox.value.trim();
  if (!text) {
    err.hidden = true;
    return null;
  }
  try {
    const r = JSON.parse(text);
    if (typeof r !== "object" || Array.isArray(r) || !r) throw new Error("A recipe is one JSON object { … }.");
    if (!["frlg", "rse", "frlg_wide", "rse_wide"].includes(r.family))
      throw new Error('Set "family" to "frlg", "rse", "frlg_wide" or "rse_wide".');
    if (!r.sections && !r.files)
      throw new Error('Put the sprites under "sections" (or "files" for a folder of charsets), as in the blank recipes.');
    err.hidden = true;
    return r;
  } catch (e) {
    err.hidden = false;
    err.textContent = e instanceof SyntaxError ? `The recipe isn't valid JSON: ${e.message}` : e.message;
    return null;
  }
}

recipeBox.addEventListener("input", () => {
  try { localStorage.setItem("lens.recipe", recipeBox.value); } catch {}
  parseRecipe();
  refresh();
});

document.querySelectorAll("[data-blank]").forEach((b) =>
  b.addEventListener("click", async () => {
    const fam = b.dataset.blank;
    if (recipeBox.value.trim() && !confirm("Replace the recipe in the box with a blank one?")) return;
    try {
      recipeBox.value = await fetchText(TOOLS + BLANK[fam]);
      state.recipeName = `${fam}_recipe.json`;
      recipeBox.dispatchEvent(new Event("input"));
    } catch (e) {
      status(e.message, "failed");
    }
  })
);

$("recipe-file").addEventListener("change", async (e) => {
  const f = e.target.files[0];
  if (!f) return;
  recipeBox.value = await f.text();
  state.recipeName = f.name;
  recipeBox.dispatchEvent(new Event("input"));
  e.target.value = "";
});

$("recipe-save").addEventListener("click", () =>
  download(new TextEncoder().encode(recipeBox.value), state.recipeName, "application/json")
);

$("do-build").addEventListener("click", (e) =>
  busy(e.currentTarget, async () => {
    const recipe = parseRecipe();
    if (!recipe) return;
    writeFile("recipe.json", new TextEncoder().encode(recipeBox.value));
    W.clear("built");
    const code = run("import_sheet.py", ["build", state.src, "recipe.json", "built"], $("build-log"));
    state.built = code === 0 ? list("built").map((f) => "built/" + f) : [];
    state.builtFamily = recipe.family;
    const box = $("build-result");
    freeURLs("build-result");
    box.replaceChildren(...state.built.map((p) => sheetCard(p, "build-result")));
    box.hidden = !state.built.length;
    if (code === 0 && !state.built.length) {
      const note = document.createElement("span");
      note.className = "warn";
      note.textContent = "Nothing was built: no frame in the recipe has a piece number yet.\n";
      log($("build-log"), note);
    }
    if (state.built.length) document.querySelector('input[name="pack-src"][value="built"]').checked = true;
    $("pack-own").hidden = true;
  })
);

// ------------------------------------------------------- 2b. the builder

// Step 1's slicing options, as recipe keys, so build numbers the sheet the
// same way the builder and the preview did. Only options that are set.
function sliceOptions() {
  const o = {};
  const scale = $("o-scale").value.trim();
  const bg = $("o-bg").value.trim();
  const reach = $("o-reach").value.trim();
  if (scale) o.scale = Number(scale);
  if (bg && bg !== "auto") o.background = bg.startsWith("#") ? bg : "#" + bg;
  if (reach) o.reach = Number(reach);
  if (!state.srcIsFolder) {
    const lossy = $("o-lossy").value;
    const colors = $("o-colors").value.trim();
    if (lossy) o.lossy = lossy === "yes";
    if (colors) o.colors = Number(colors);
  }
  return o;
}

const noteCache = {};
async function sectionNotes(base) {
  if (!noteCache[base]) {
    try {
      noteCache[base] = JSON.parse(await fetchText(TOOLS + BLANK[base]))._sections || {};
    } catch {
      noteCache[base] = {};
    }
  }
  return noteCache[base];
}

const builder = createBuilder({
  async load(recipe) {
    if (state.srcIsFolder) {
      const el = $("b-progress");
      try {
        await readFolder(recipe, el);
      } finally {
        el.hidden = true;
      }
    }
    return JSON.parse(W.builder_data(state.src, JSON.stringify(recipe), state.srcVersion));
  },
  sheetURL() {
    freeURLs("builder");
    return imageURL("builder/sheet.png", "builder");
  },
  sourceId: () => (W && state.src ? `${state.src}#${state.srcVersion}` : ""),
  sliceOptions,
  notes: sectionNotes,
  getText: () => recipeBox.value,
  setText(text) {
    recipeBox.value = text;
    recipeBox.dispatchEvent(new Event("input"));
  },
  onRecipeInput: (fn) => recipeBox.addEventListener("input", fn),
  busy,
  status,
  saveGif,
  gifName,
});

matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => builder.refreshTheme());

// --------------------------------------------------------------- 3. pack

const baseFamily = (fam) => fam.replace(/_wide$/, "").replace(/_extras$/, "");
const otherFamily = (fam) => (fam.startsWith("frlg") ? fam.replace("frlg", "rse") : fam.replace("rse", "frlg"));
const packMode = () => document.querySelector('input[name="pack-src"]:checked').value;

document.querySelectorAll('input[name="pack-src"]').forEach((r) =>
  r.addEventListener("change", () => {
    $("pack-own").hidden = packMode() !== "own";
    refresh();
  })
);

async function setOwn(items) {
  const s = await store(items, "pack", "templates");
  state.own = [s.path];
  state.ownFolder = s.isFolder ? s.path : null;
  // Several loose sheets: pack each one rather than as a templates folder.
  if (s.isFolder && items.length > 1 && !items.some((i) => i.path.includes("/"))) {
    state.own = list(s.path).map((f) => `${s.path}/${f}`);
    state.ownFolder = null;
  }
  const el = $("pack-name");
  el.hidden = false;
  el.textContent = state.ownFolder ? `Templates folder: ${s.name}` : `Sheets: ${state.own.map((p) => p.split("/").pop()).join(", ")}`;
}

// What to pack: [family, [paths]].
function packSource() {
  if (packMode() === "built") return [state.builtFamily, state.built];
  return [$("pack-family").value, state.own];
}

// ------------------------------------------------------ 3b. merging
// Packing into a look that already has files merges frame by frame
// (pack --merge); the combine panel merges any sources into one sheet.
// Clashes come back as a report plus one PNG per version, for the
// picker; choosing reruns the same command with --pick. -Elvie

let mergeRuns = 0;

function readJSON(path) {
  return JSON.parse(new TextDecoder().decode(FS.readFile(work(path))));
}

// "walk, down 2" for walk.png frame 4: where a frame sits in our sections.
function frameLabel(fam, file, frame) {
  const lay = familyLayout(baseFamily(fam));
  for (const [key, sec] of Object.entries(lay.sections)) {
    for (const [facing, slots] of Object.entries(sec.facings)) {
      const i = slots.findIndex(([f, n]) => f === file && n === frame);
      if (i >= 0) return facing === "frames" ? `${key}, ${i + 1}` : `${key}, ${facing} ${i + 1}`;
    }
  }
  return "";
}

const pickerApi = {
  imageURL,
  freeURLs,
  label: frameLabel,
  busy,
};

// Run a merge-style command with a report; returns the report, or null.
function runMerge(script, argv, logEl, tag) {
  const dir = `merge/${tag}-${++mergeRuns}`;
  W.clear(dir);
  FS.mkdirTree(work(dir));
  const full = [...argv, "--report", `${dir}/report.json`, "--clash-frames", `${dir}/frames`];
  if (run(script, full, logEl) !== 0 || !exists(`${dir}/report.json`)) return null;
  return { report: readJSON(`${dir}/report.json`), framesDir: `${dir}/frames` };
}

function lookHas(fam) {
  return list(`look/gen3/${baseFamily(fam)}`).length > 0;
}

function packOne(fam, path, logEl, picks = [], box = null) {
  const dst = `look/gen3/${baseFamily(fam)}`;
  if (!$("pack-keep").checked || !lookHas(fam)) {
    return run("pack_gen3.py", ["pack", fam, path, dst], logEl) === 0;
  }
  const argv = ["pack", fam, path, dst, "--merge", ...picks.flatMap((p) => ["--pick", p])];
  const got = runMerge("pack_gen3.py", argv, logEl, "pack");
  if (!got) return false;
  if (!box) {
    box = document.createElement("div");
    box.id = `pack-clash-${mergeRuns}`;
    $("pack-clashes").append(box);
    box.picker = createClashPicker(box, pickerApi);
  }
  box.picker.show({
    ...got,
    names: ["the look", path.split("/").pop()],
    apply: async (chosen) => {
      packOne(fam, path, logEl, chosen, box);
      showLook();
      status("Applied your choices to the look.", "ready");
    },
  });
  $("pack-clashes").hidden = !$("pack-clashes").querySelector(".clash");
  return true;
}

function packInto(fam, paths, logEl) {
  let failed = 0;
  for (const p of paths) if (!packOne(fam, p, logEl)) failed++;
  return failed;
}

$("do-pack").addEventListener("click", (e) =>
  busy(e.currentTarget, async () => {
    const [fam, paths] = packSource();
    $("pack-clashes").replaceChildren();
    $("pack-clashes").hidden = true;
    packInto(fam, paths, $("pack-log"));
    showLook();
  })
);

$("do-transfer").addEventListener("click", (e) =>
  busy(e.currentTarget, async () => {
    const [fam, paths] = packSource();
    W.clear("transfer");
    FS.mkdirTree(work("transfer"));
    const made = [];
    for (const p of paths) {
      const from = W.sheet_family(p, fam);
      const to = otherFamily(from);
      const out = `transfer/${W.sheet_file(to)}`;
      if (run("pack_gen3.py", ["transfer", from, p, to, out], $("pack-log")) === 0 && exists(out)) made.push([to, out]);
    }
    const box = $("transfer-result");
    freeURLs("transfer-result");
    box.replaceChildren(
      ...made.map(([to, out]) => {
        const packIt = document.createElement("button");
        packIt.type = "button";
        packIt.className = "btn";
        packIt.textContent = "Pack this into the look";
        packIt.addEventListener("click", (ev) =>
          busy(ev.currentTarget, async () => {
            packInto(to, [out], $("pack-log"));
            showLook();
          })
        );
        return sheetCard(out, "transfer-result", packIt);
      })
    );
    box.hidden = !made.length;
  })
);

// ------------------------------------------------------ 3c. combine

const combine = { sources: [], n: 0 };
const cbPicker = createClashPicker($("cb-clashes"), pickerApi);

function copyInto(src, dst) {
  if (FS.isDir(FS.stat(work(src)).mode)) W.replace_dir(src, dst);
  else writeFile(dst, FS.readFile(work(src)));
}

function addCombine(path, name) {
  const dst = `combine/${++combine.n}-${path.split("/").pop()}`;
  copyInto(path, dst); // a snapshot: rebuilding later doesn't change it
  combine.sources.push({ path: dst, name });
  showCombine();
}

async function addCombineUpload(items) {
  const s = await store(items, `combine/up-${++combine.n}`, "templates");
  if (s.isFolder && items.length > 1 && !items.some((i) => i.path.includes("/"))) {
    for (const f of list(s.path)) combine.sources.push({ path: `${s.path}/${f}`, name: f });
  } else {
    combine.sources.push({ path: s.path, name: s.name });
  }
  showCombine();
}

function showCombine() {
  const ol = $("cb-list");
  ol.replaceChildren(
    ...combine.sources.map((src, i) => {
      const li = document.createElement("li");
      const name = document.createElement("span");
      name.textContent = src.name;
      const tools = document.createElement("span");
      tools.className = "cb-tools";
      const mk = (text, label, fn, off) => {
        const b = document.createElement("button");
        b.type = "button";
        b.className = "btn quiet";
        b.textContent = text;
        b.setAttribute("aria-label", `${label} ${src.name}`);
        b.disabled = off;
        b.addEventListener("click", () => {
          fn();
          showCombine();
        });
        return b;
      };
      const swap = (j) => ([combine.sources[i], combine.sources[j]] = [combine.sources[j], combine.sources[i]]);
      tools.append(
        mk("Up", "Move up", () => swap(i - 1), i === 0),
        mk("Down", "Move down", () => swap(i + 1), i === combine.sources.length - 1),
        mk("Remove", "Remove", () => combine.sources.splice(i, 1), false)
      );
      li.append(name, tools);
      return li;
    })
  );
  $("cb-empty").hidden = combine.sources.length > 0;
  refresh();
}

function doCombine(picks = []) {
  const fam = $("cb-family").value;
  W.clear("combined");
  FS.mkdirTree(work("combined"));
  const out = `combined/${W.sheet_file(fam)}`;
  const argv = ["merge", fam, out, ...combine.sources.map((s) => s.path), ...picks.flatMap((p) => ["--pick", p])];
  const got = runMerge("pack_gen3.py", argv, $("cb-log"), "combine");
  const made = got ? list("combined").map((f) => `combined/${f}`) : [];
  const box = $("cb-result");
  freeURLs("cb-result");
  box.replaceChildren(
    ...made.map((p) => {
      const use = document.createElement("button");
      use.type = "button";
      use.className = "btn";
      use.textContent = "Pack these into the look";
      use.addEventListener("click", (ev) =>
        busy(ev.currentTarget, async () => {
          // the combined sheets become "my own sheets" in step 3
          W.clear("pack");
          for (const f of made) writeFile(`pack/${f.split("/").pop()}`, FS.readFile(work(f)));
          state.own = made.map((f) => `pack/${f.split("/").pop()}`);
          state.ownFolder = null;
          $("pack-family").value = fam;
          document.querySelector('input[name="pack-src"][value="own"]').checked = true;
          $("pack-own").hidden = false;
          $("pack-name").hidden = false;
          $("pack-name").textContent = `Sheets: ${state.own.map((x) => x.split("/").pop()).join(", ")} (combined)`;
          $("pack-clashes").replaceChildren();
          packInto(fam, state.own, $("pack-log"));
          showLook();
        })
      );
      return sheetCard(p, "cb-result", use);
    })
  );
  box.hidden = !made.length;
  if (got) {
    cbPicker.show({ ...got, names: combine.sources.map((s) => s.name), apply: async (chosen) => doCombine(chosen) });
  } else {
    cbPicker.hide();
  }
}

$("do-combine").addEventListener("click", (e) => busy(e.currentTarget, async () => doCombine()));
$("cb-built").addEventListener("click", () => {
  for (const p of state.built) addCombine(p, `${p.split("/").pop()} (built in step 2)`);
});
$("cb-look").addEventListener("click", () => {
  const fam = $("cb-family").value;
  addCombine(`look/gen3/${baseFamily(fam)}`, `the look's ${FAMILY_NAMES[baseFamily(fam)]} files`);
});
$("cb-files").addEventListener("change", (e) => upload(fromInput(e.target), addCombineUpload, e.target));
$("cb-folder").addEventListener("change", (e) => upload(fromInput(e.target), addCombineUpload, e.target));
$("cb-family").addEventListener("change", refresh);

// --------------------------------------------------------------- 4. look

const SHOWN = 8; // the options menu cuts choice values at 8 characters

function noteLength(input, note) {
  const v = input.value.trim();
  note.textContent = v.length > SHOWN ? `Shows as ${v.slice(0, SHOWN)}` : "";
}

function slug(s) {
  return s.trim().toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
}

$("m-label").addEventListener("input", () => {
  noteLength($("m-label"), $("m-label-note"));
  if (!state.folderTouched) $("m-folder").value = slug($("m-label").value);
});
$("m-character").addEventListener("input", () => noteLength($("m-character"), $("m-character-note")));
$("m-folder").addEventListener("input", () => (state.folderTouched = true));

function showLook() {
  const box = $("look-files");
  freeURLs("look-files");
  const files = list("look/gen3");
  if (!files.length) {
    const p = document.createElement("p");
    p.className = "empty";
    p.textContent = "Nothing packed yet. Pack a sheet in step 3 and it shows up here.";
    box.replaceChildren(p);
    refreshLookPreview({});
    refresh();
    return;
  }
  const groups = {};
  for (const f of files) {
    const [fam, ...rest] = f.split("/");
    (groups[fam] ||= []).push(rest.join("/"));
  }
  box.replaceChildren(
    ...Object.keys(groups).sort().map((fam) => {
      const div = document.createElement("div");
      div.className = "fam";
      const h = document.createElement("h4");
      h.textContent = `${FAMILY_NAMES[fam] || fam} (gen3/${fam})`;
      const rm = document.createElement("button");
      rm.type = "button";
      rm.className = "btn quiet";
      rm.style.marginLeft = "12px";
      rm.textContent = "Remove";
      rm.setAttribute("aria-label", `Remove the ${FAMILY_NAMES[fam] || fam} art`);
      rm.addEventListener("click", () => {
        W.clear(`look/gen3/${fam}`);
        showLook();
      });
      h.append(rm);
      const row = document.createElement("div");
      row.className = "list";
      for (const name of groups[fam]) {
        const path = `look/gen3/${fam}/${name}`;
        const fig = document.createElement("figure");
        fig.className = "file";
        fig.style.margin = "0";
        const frame = document.createElement("div");
        frame.className = "frame";
        const img = new Image();
        img.alt = name;
        img.src = imageURL(path, "look-files");
        frame.append(img);
        const cap = document.createElement("figcaption");
        cap.textContent = name;
        fig.append(frame, cap);
        row.append(fig);
      }
      div.append(h, row);
      return div;
    })
  );
  refreshLookPreview(groups);
  refresh();
}

// The dive helpers: pack_gen3.py dive on the look's R/S/E folder. -Elvie
function runDive(flag, e) {
  busy(e.currentTarget, async () => {
    const argv = ["dive", "look/gen3/rse", flag];
    if ($("dive-force").checked) argv.push("--force");
    run("pack_gen3.py", argv, $("dive-log"));
    showLook();
  });
}
$("dive-blob").addEventListener("click", (e) => runDive("--blob", e));
$("dive-under").addEventListener("click", (e) => runDive("--underwater", e));

// --------------------------------------------------- 4b. look preview

const lookStage = createStage($("look-preview"), { saveGif, busy });
const layouts = {};
let lookImages = {}; // "frlg/walk.png" -> loaded <img>

function familyLayout(fam) {
  if (!layouts[fam]) layouts[fam] = JSON.parse(W.layout_data(fam));
  return layouts[fam];
}

async function loadLookImages(groups) {
  freeURLs("look-preview");
  lookImages = {};
  const jobs = [];
  for (const [fam, names] of Object.entries(groups)) {
    for (const name of names) {
      const img = new Image();
      img.src = imageURL(`look/gen3/${fam}/${name}`, "look-preview");
      lookImages[`${fam}/${name}`] = img;
      jobs.push(img.decode().catch(() => {}));
    }
  }
  await Promise.all(jobs);
}

// One frame of a packed file: the strip is frames stacked top to bottom,
// each the game's height; the width is the file's own (16 or 32 wide).
function packedFrame(fam, file, index, h) {
  const img = lookImages[`${fam}/${file}`];
  if (!img || !img.naturalWidth || (index + 1) * h > img.naturalHeight) return null;
  const c = document.createElement("canvas");
  c.width = img.naturalWidth;
  c.height = h;
  c.getContext("2d").drawImage(img, 0, index * h, c.width, h, 0, 0, c.width, h);
  const px = c.getContext("2d").getImageData(0, 0, c.width, h).data;
  for (let i = 3; i < px.length; i += 4) if (px[i]) return c;
  return null; // a blank frame draws nothing
}

function showLookPreview() {
  const fam = $("lp-family").value;
  const key = $("lp-section").value;
  if (!fam || !key) return lookStage.hide();
  const lay = familyLayout(fam);
  const sec = lay.sections[key];
  const fromSection = (k) => (facing, i) => {
    const slot = lay.sections[k] && (lay.sections[k].facings[facing] || [])[i];
    return slot ? packedFrame(fam, slot[0], slot[1], lay.frames[slot[0]][1]) : null;
  };
  const first = Object.values(sec.facings)[0][0][0];
  const blobSec = lay.sections["surf blob"];
  lookStage.show(sceneFor(key, fam, sec), {
    frame: fromSection(key),
    blob: fromSection("surf blob"),
    blobCount: (facing) => (blobSec && blobSec.facings[facing] ? blobSec.facings[facing].length : 0),
    diveBlob: (facing) => fromSection("dive blob")(facing, 0),
    size: () => {
      const img = lookImages[`${fam}/${first}`];
      return [img && img.naturalWidth ? img.naturalWidth : lay.frames[first][0], lay.frames[first][1]];
    },
  }, `${FAMILY_NAMES[fam]}: ${key}`, gifName(fam, key));
}

// Sections the packed files can show, for the chosen family.
function fillSections(groups) {
  const fam = $("lp-family").value;
  const sel = $("lp-section");
  const keep = sel.value;
  sel.replaceChildren();
  if (!fam) return;
  const lay = familyLayout(fam);
  const have = new Set(groups[fam] || []);
  for (const [key, sec] of Object.entries(lay.sections)) {
    const files = new Set(Object.values(sec.facings).flat().map(([f]) => f));
    if (![...files].some((f) => have.has(f))) continue;
    const o = document.createElement("option");
    o.value = o.textContent = key;
    sel.append(o);
  }
  if ([...sel.options].some((o) => o.value === keep)) sel.value = keep;
}

let lookGroups = {};
async function refreshLookPreview(groups) {
  lookGroups = groups;
  const fams = Object.keys(groups).sort();
  $("look-play").hidden = !fams.length;
  if (!fams.length) return lookStage.hide();
  const famSel = $("lp-family");
  const keep = famSel.value;
  famSel.replaceChildren(...fams.map((f) => {
    const o = document.createElement("option");
    o.value = f;
    o.textContent = FAMILY_NAMES[f] || f;
    return o;
  }));
  if (fams.includes(keep)) famSel.value = keep;
  await loadLookImages(groups);
  fillSections(groups);
  showLookPreview();
}

$("lp-family").addEventListener("change", () => {
  fillSections(lookGroups);
  showLookPreview();
});
$("lp-section").addEventListener("change", showLookPreview);

function metaJson() {
  const meta = { label: $("m-label").value.trim() };
  const character = $("m-character").value.trim();
  if (character) meta.character = character;
  meta.genderMode = $("m-gender").value;
  meta.generation = Number($("m-generation").value);
  const credit = $("m-credit").value.split("\n").map((s) => s.trim()).filter(Boolean);
  if (credit.length) meta.credit = credit;
  return JSON.stringify(meta, null, 2) + "\n";
}

$("do-download").addEventListener("click", () => {
  const form = $("meta");
  if (!form.reportValidity()) return;
  const folder = $("m-folder").value.trim();
  writeFile("look/meta.json", new TextEncoder().encode(metaJson()));
  const zip = W.zip_dir("look", folder);
  download(zip.toJs(), `${folder}.zip`, "application/zip");
  zip.destroy();
});

$("look-zip").addEventListener("change", async (e) => {
  const f = e.target.files[0];
  e.target.value = "";
  if (!f || !W) return;
  try {
    const s = await store([{ file: f, path: f.name }], "lookzip", "look");
    W.replace_dir(s.path, "look");
    W.clear("lookzip");
    const meta = JSON.parse(W.read_meta("look/meta.json"));
    $("m-folder").value = s.path.split("/").pop();
    state.folderTouched = true;
    $("m-label").value = meta.label || "";
    $("m-character").value = meta.character || "";
    $("m-gender").value = ["girl", "boy", "enby"].includes(meta.genderMode) ? meta.genderMode : "girl";
    // left out (or anything but 4) is Gen 3, as lens.lua reads it -Elvie
    $("m-generation").value = Number(meta.generation) === 4 ? "4" : "3";
    $("m-credit").value = (Array.isArray(meta.credit) ? meta.credit : meta.credit ? [meta.credit] : []).join("\n");
    noteLength($("m-label"), $("m-label-note"));
    noteLength($("m-character"), $("m-character-note"));
    showLook();
    status(`Opened ${f.name}. Packing adds to it; files with the same name are replaced.`, "ready");
  } catch (err) {
    console.error(err);
    status(`That zip didn't open: ${err.message}`, "failed");
  }
});

$("do-clear").addEventListener("click", () => {
  if (!confirm("Clear the look you're assembling? Download it first if you want to keep it.")) return;
  W.clear("look");
  $("meta").reset();
  state.folderTouched = false;
  $("m-label-note").textContent = $("m-character-note").textContent = "";
  showLook();
});

// --------------------------------------------------------------- uploads

$("src-file").addEventListener("change", (e) => upload(fromInput(e.target), setSource, e.target));
$("src-folder").addEventListener("change", (e) => upload(fromInput(e.target), setSource, e.target));
$("pack-files").addEventListener("change", (e) => upload(fromInput(e.target), setOwn, e.target));
$("pack-folder").addEventListener("change", (e) => upload(fromInput(e.target), setOwn, e.target));

async function upload(items, fn, input) {
  if (!W) return;
  try {
    await fn(items);
  } catch (err) {
    console.error(err);
    status(err.message, "failed");
  }
  if (input) input.value = "";
  refresh();
}

document.querySelectorAll(".drop").forEach((zone) => {
  zone.addEventListener("dragover", (e) => {
    e.preventDefault();
    zone.classList.add("over");
  });
  zone.addEventListener("dragleave", () => zone.classList.remove("over"));
  zone.addEventListener("drop", async (e) => {
    e.preventDefault();
    zone.classList.remove("over");
    const items = await fromDrop(e.dataTransfer);
    const fn = { source: setSource, pack: setOwn, combine: addCombineUpload }[zone.dataset.target];
    await upload(items, fn);
  });
});

// ----------------------------------------------------------------- state

function refresh() {
  const ready = !!W;
  $("do-slice").disabled = !ready || !state.src;
  $("b-open").disabled = !ready || !state.src;
  $("do-build").disabled = !ready || !state.src || !parseRecipe();
  const [, paths] = ready ? packSource() : [null, []];
  $("do-pack").disabled = !ready || !paths.length;
  $("do-transfer").disabled = !ready || !paths.length;
  $("cb-built").disabled = !ready || !state.built.length;
  $("cb-look").disabled = !ready || !lookHas($("cb-family").value);
  $("do-combine").disabled = !ready || combine.sources.length < 2;
  const packed = ready && list("look/gen3").length > 0;
  $("do-download").disabled = !packed;
  const rse = ready && exists("look/gen3/rse");
  $("look-dive").hidden = !rse;
  $("dive-blob").disabled = !rse || !exists("look/gen3/rse/surfBlob.png");
  $("dive-under").disabled = !rse || !exists("look/gen3/rse/surf.png");
  $("do-clear").disabled = !packed;
}

refresh();
boot();
