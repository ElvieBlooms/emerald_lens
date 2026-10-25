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
const BLANK = { frlg: "recipes/blank_frlg.json", rse: "recipes/blank_rse.json", gb: "recipes/blank_gb.json" };
const FAMILY_NAMES = { frlg: "FireRed / LeafGreen", rse: "Ruby / Sapphire / Emerald", gb: "Game Boy" };

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

// The backdrop option: "" finds it, "none" clears nothing, or a colour. -Elvie
function backdrop() {
  const mode = $("o-bgmode").value;
  if (mode !== "colour") return mode;
  const c = $("o-bg").value.trim();
  return /^#?[0-9a-fA-F]{6}$/.test(c) ? (c.startsWith("#") ? c : "#" + c) : "";
}

function sliceArgs() {
  const a = ["slice", state.src, "numbers.png"];
  const scale = $("o-scale").value.trim();
  const bg = backdrop();
  const reach = $("o-reach").value.trim();
  if (scale) a.push("--scale", scale);
  if (bg) a.push("--bg", bg);
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
$("o-bgmode").addEventListener("change", (e) => { $("o-bg-box").hidden = e.target.value !== "colour"; });

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
    if (!["frlg", "rse", "frlg_wide", "rse_wide", "gb"].includes(r.family))
      throw new Error('Set "family" to "frlg", "rse", "frlg_wide", "rse_wide" or "gb".');
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
  const bg = backdrop();
  const reach = $("o-reach").value.trim();
  if (scale) o.scale = Number(scale);
  if (bg) o.background = bg;
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
// Where a family's packed files go: Game Boy art sits at the look's root,
// as in Crystal Lens; Gen 3 art under gen3/<family> -Elvie
const lookDir = (fam) => (baseFamily(fam) === "gb" ? "look" : `look/gen3/${baseFamily(fam)}`);
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
  return baseFamily(fam) === "gb" ? gbHas().length > 0 : list(lookDir(fam)).length > 0;
}

function packOne(fam, path, logEl, picks = [], box = null) {
  const dst = lookDir(fam);
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
  // packed Game Boy art: show it in step 4's Game Boy panel -Elvie
  if (baseFamily(fam) === "gb" && failed < paths.length && !isGb()) {
    $("m-generation").value = "gb";
    $("m-generation").dispatchEvent(new Event("change"));
  } else if (baseFamily(fam) === "gb") {
    showGb();
  }
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
      // a Game Boy sheet starts both Gen 3 sheets -Elvie
      for (const to of from === "gb" ? ["frlg", "rse"] : [otherFamily(from)]) {
        const out = `transfer/${W.sheet_file(to)}`;
        if (run("pack_gen3.py", ["transfer", from, p, to, out], $("pack-log")) === 0 && exists(out)) made.push([to, out]);
      }
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
  addCombine(lookDir(fam), `the look's ${FAMILY_NAMES[baseFamily(fam)]} files`);
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
    p.textContent = isGb()
      ? "No Gen 3 sheets, which is fine for a Game Boy look. Its Game Boy files are below."
      : "Nothing packed yet. Pack a sheet in step 3 and it shows up here.";
    box.replaceChildren(p);
    refreshLookPreview({});
    $("look-feet").hidden = true;
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
  checkFeet();
  refresh();
}

// Feet: pack_gen3.py feet on each family's packed files. Frames that sit
// higher or lower than the game's own (the walking bob, bikes on the
// ground, back pics reaching the bottom...) float or sink in game, so the
// look says so and offers to move them. -Elvie
function checkFeet() {
  const off = [];
  for (const fam of ["frlg", "rse"]) {
    if (!exists(`look/gen3/${fam}`)) continue;
    const result = W.run("pack_gen3.py", py.toPy(["feet", fam, `look/gen3/${fam}`]));
    const [, out] = result.toJs();
    result.destroy();
    let high = 0, low = 0, side = 0;
    const files = {};
    for (const m of out.matchAll(/differs (\S+)\.png frame \d+: (?:feet|head) on row (\d+), the game's is (\d+)/g)) {
      files[m[1]] = (files[m[1]] || 0) + 1;
      if (Number(m[2]) < Number(m[3])) high++;
      else if (Number(m[2]) > Number(m[3])) low++;
      else side++; // in line, but shifted sideways
    }
    if (high + low + side) {
      const parts = [];
      if (high) parts.push(`${high} too high`);
      if (low) parts.push(`${low} too low`);
      if (side) parts.push(`${side} shifted sideways`);
      const which = Object.entries(files).map(([f, n]) => `${f} ${n}`).join(", ");
      off.push(`${FAMILY_NAMES[fam]}: ${high + low + side} frame${high + low + side === 1 ? "" : "s"} off the game's rows (${which}; ${parts.join(", ")})`);
    }
  }
  $("look-feet").hidden = !off.length;
  $("feet-what").textContent = off.length
    ? `${off.join(". ")}. In game they'd float, sink or lose the walking bob next to other looks. Fishing and underwater aren't checked.`
    : "";
}

$("feet-match").addEventListener("click", (e) =>
  busy(e.currentTarget, async () => {
    for (const fam of ["frlg", "rse"]) {
      if (exists(`look/gen3/${fam}`)) run("pack_gen3.py", ["feet", fam, `look/gen3/${fam}`, "--match"], $("feet-log"));
    }
    showLook();
  })
);

// The dive helpers: pack_gen3.py dive on the look's R/S/E folder. -Elvie
function runDive(flag, e) {
  busy(e.currentTarget, async () => {
    const argv = ["dive", "look/gen3/rse", flag];
    if ($("dive-force").checked) argv.push("--force");
    if (flag === "--underwater" && !$("dive-shade").checked) argv.push("--no-shade");
    run("pack_gen3.py", argv, $("dive-log"));
    showLook();
  });
}
$("dive-blob").addEventListener("click", (e) => runDive("--blob", e));

// --------------------------------------------------- 4a. blob sets
// Ready-made surf and dive blobs in sprite-templates/blobs/; pack_gen3.py
// blobs copies them into the look, the page just shows them. -Elvie

const BLOB_KITS = [
  { id: "set1", name: "Round" }, { id: "set2", name: "Ray" },
  { id: "set3", name: "Finned" }, { id: "set4", name: "Flippers" },
];
const BLOB_FILES = ["frlg/surfBlob.png", "rse/surfBlob.png", "rse/diveBlob.png"];
const blobLoaded = new Set();

async function blobKit() {
  const id = $("blob-kit").value;
  if (!blobLoaded.has(id)) {
    for (const f of BLOB_FILES) {
      const r = await fetch(TOOLS + `blobs/${id}/${f}`, { cache: "no-cache" });
      if (!r.ok) throw new Error(`blobs/${id}/${f} answered ${r.status}`);
      writeFile(`blobs/${id}/${f}`, new Uint8Array(await r.arrayBuffer()));
    }
    blobLoaded.add(id);
  }
  return `blobs/${id}`;
}

async function blobPreview() {
  const kit = await blobKit();
  const c = $("blob-c"), g = c.getContext("2d"), z = 3;
  g.imageSmoothingEnabled = false;
  g.clearRect(0, 0, c.width, c.height);
  // [file, frames, row, first column]
  const rows = [["frlg/surfBlob.png", 6, 0, 0], ["rse/surfBlob.png", 3, 1, 0], ["rse/diveBlob.png", 3, 1, 3]];
  for (const [f, n, row, col] of rows) {
    const img = new Image();
    img.src = imageURL(`${kit}/${f}`, "blob");
    await img.decode();
    for (let i = 0; i < n; i++) g.drawImage(img, 0, i * 32, 32, 32, (col + i) * 32 * z, row * 32 * z, 32 * z, 32 * z);
  }
  freeURLs("blob");
}

for (const k of BLOB_KITS) $("blob-kit").add(new Option(k.name, k.id));
const blobShow = () => blobPreview().catch((err) => log($("blob-log"), String(err) + "\n"));
$("blob-kit").addEventListener("change", blobShow);
$("blob-save").addEventListener("click", (e) => busy(e.currentTarget, async () => {
  const kit = await blobKit();
  const argv = ["blobs", "look/gen3", kit];
  if ($("blob-surf").checked && !$("blob-dive").checked) argv.push("--surf");
  if ($("blob-dive").checked && !$("blob-surf").checked) argv.push("--dive");
  if (!$("blob-surf").checked && !$("blob-dive").checked) {
    log($("blob-log"), "Tick surf blobs, the dive blob, or both.\n");
    return;
  }
  if ($("blob-force").checked) argv.push("--force");
  run("pack_gen3.py", argv, $("blob-log"));
  showLook();
}));

// --------------------------------------------------- 4a. fly bird kits
// Ready-made birds in sprite-templates/flybirds/. The rider is the look's
// FR/LG surf frame; pack_gen3.py flybird does the layering, the page only
// keeps the nudges and shows the result. -Elvie

const FLY_KITS = [{ id: "pidgeot", name: "Pidgeot" }, { id: "fearow", name: "Fearow" }];
const fly = { nudge: [[0, 0], [0, 0]], tilt: [null, null], loaded: new Set(), shown: "", kit: "" };

async function flyKit() {
  const id = $("fly-kit").value;
  if (!fly.loaded.has(id)) {
    for (const f of ["back.png", "front.png", "kit.json", "bird.png"]) {
      const r = await fetch(TOOLS + `flybirds/${id}/${f}`, { cache: "no-cache" });
      if (!r.ok && f === "bird.png") continue; // the lone bird is optional -Elvie
      if (!r.ok) throw new Error(`flybirds/${id}/${f} answered ${r.status}`);
      writeFile(`flybirds/${id}/${f}`, new Uint8Array(await r.arrayBuffer()));
    }
    fly.loaded.add(id);
  }
  if (fly.kit !== id) {
    // a new bird starts from its own placement and tilt -Elvie
    fly.kit = id;
    const conf = JSON.parse(new TextDecoder().decode(FS.readFile(work(`flybirds/${id}/kit.json`))));
    const frames = conf.frames || [];
    fly.nudge = [[0, 0], [0, 0]];
    fly.tilt = [0, 1].map((i) => (frames[i] && frames[i].tilt) ?? conf.tilt ?? 10.23);
  }
  return `flybirds/${id}`;
}

function flyArgs(kit, out) {
  const [a, b] = fly.nudge;
  return ["flybird", "look/gen3/frlg", kit, "--off", `${a[0]},${a[1]}`, "--in", `${b[0]},${b[1]}`,
    "--off-tilt", String(fly.tilt[0]), "--in-tilt", String(fly.tilt[1]), "--out", out, "--force"];
}

async function flyPreview() {
  if (!exists("look/gen3/frlg/surf.png")) return;
  const kit = await flyKit();
  const res = W.run("pack_gen3.py", py.toPy([...flyArgs(kit, "fly/preview.png"), "--no-bird"]));
  const [code, out] = res.toJs();
  res.destroy();
  if (code !== 0) {
    log($("fly-log"), out);
    return;
  }
  const img = new Image();
  img.src = imageURL("fly/preview.png", "fly");
  await img.decode();
  for (const i of [0, 1]) {
    const c = $(`fly-c-${i}`), g = c.getContext("2d");
    g.imageSmoothingEnabled = false;
    g.clearRect(0, 0, c.width, c.height);
    g.drawImage(img, 0, i * 64, 64, 64, 0, 0, c.width, c.height);
    $(`fly-pos-${i}`).textContent = fly.nudge[i].join(", ");
    $(`fly-tilt-${i}`).value = fly.tilt[i];
  }
  const alone = exists(`${kit}/bird.png`);
  $("fly-alone").hidden = !alone;
  $("fly-bird").disabled = !alone;
  if (alone) {
    const b = new Image();
    b.src = imageURL(`${kit}/bird.png`, "fly");
    await b.decode();
    const c = $("fly-c-2"), g = c.getContext("2d");
    g.imageSmoothingEnabled = false;
    g.clearRect(0, 0, c.width, c.height);
    g.drawImage(b, 0, 0, c.width, c.height);
  }
  freeURLs("fly");
}

for (const k of FLY_KITS) $("fly-kit").add(new Option(k.name, k.id));
const flyShow = () => flyPreview().catch((err) => log($("fly-log"), String(err)));
$("fly-kit").addEventListener("change", flyShow);
for (const i of [0, 1]) {
  $(`fly-tilt-${i}`).addEventListener("change", (e) => {
    const v = Number(e.target.value);
    if (Number.isFinite(v)) fly.tilt[i] = v;
    flyShow();
  });
}
document.querySelectorAll(".fly-nudge").forEach((box) => {
  box.addEventListener("click", (e) => {
    const b = e.target.closest("button");
    if (!b) return;
    const n = fly.nudge[Number(box.dataset.frame)];
    n[0] += Number(b.dataset.dx);
    n[1] += Number(b.dataset.dy);
    flyShow();
  });
});
$("fly-save").addEventListener("click", (e) => busy(e.currentTarget, async () => {
  const kit = await flyKit();
  const out = "look/gen3/frlg/flyBird.png";
  if (exists(out) && !$("fly-force").checked) {
    log($("fly-log"), "The look already has a flyBird.png; tick \"Replace what's there\" to swap it.\n");
    return;
  }
  const argv = flyArgs(kit, out);
  if (!$("fly-bird").checked || $("fly-bird").disabled) argv.push("--no-bird");
  run("pack_gen3.py", argv, $("fly-log"));
  showLook();
}));
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

// --------------------------------------------------------- Game Boy looks
// A Game Boy look is Crystal Lens's files at the folder's top level; the
// mod fits them to Gen 3 sizes as the game loads them (gameboy.lua), so
// nothing is converted here. The preview draws them the way the mod
// will. -Elvie

// Every file Crystal Lens reads from a look folder, so a folder made here
// works in both mods. -Elvie
const GB_FILES = ["front.png", "frontColor.png", "back.png", "backColor.png", "overworldWalk.png",
  "overworldBike.png", "overworldFishSide.png", "overworldFishFront.png", "overworldFishBack.png",
  "trainerCard.png", "trainerCardColor.png", "overworldSurf.png", "overworldFishRod.png"];
// gameboy.lua's fishing: pose file per facing, and Gen 1's rod offsets
// { dx, dy, tile } from the sprite's top-left, in Gen 3's order -Elvie
const GB_FISH = [["left", "overworldFishSide.png", [-8, 4, 1]], ["up", "overworldFishBack.png", [4, -8, 0]],
  ["down", "overworldFishFront.png", [4, 15, 0]]];
const GB_STAND = { down: 0, up: 1, left: 2 };
// Crystal Lens's own overworld colours, for overworldWalk.png -Elvie
const CRYSTAL_COLORS = [[255, 255, 255], [255, 173, 99], [1, 99, 198], [0, 0, 0]];
// gameboy.lua's WALK: Game Boy frame, mirrored, step (a row lower) -Elvie
const GB_WALK = [[0], [1], [2], [3, false, true], [3, true, true], [4, false, true], [4, true, true],
  [5, false, true], [5, false, true]];
const isGb = () => $("m-generation").value === "gb";
const gbHas = () => GB_FILES.filter((n) => exists(`look/${n}`));
// meta.json keys this page doesn't edit (nameChoices, overworldColors...),
// kept from an opened look so downloading again doesn't drop them -Elvie
let keptMeta = {};

function loadImg(path, owner) {
  return new Promise((res, rej) => {
    const img = new Image();
    img.onload = () => res(img);
    img.onerror = () => rej(new Error(`${path} didn't load as a picture`));
    img.src = imageURL(path, owner);
  });
}

function scaled(canvas, zoom = 3) {
  canvas.style.width = `${canvas.width * zoom}px`;
  canvas.style.height = `${canvas.height * zoom}px`;
}

// The pic in a w x h box: centred across, feet on the bottom edge; a
// taller pic keeps its top rows, a wider one its middle (gameboy.lua fit). -Elvie
function fitPic(canvas, img) {
  const { width: w, height: h } = canvas;
  const ctx = canvas.getContext("2d");
  ctx.clearRect(0, 0, w, h);
  const cw = Math.min(img.width, w), ch = Math.min(img.height, h);
  ctx.drawImage(img, Math.floor((img.width - cw) / 2), 0, cw, ch, Math.floor((w - cw) / 2), h - ch, cw, ch);
  return img.width > w || img.height > h;
}

// Crystal Lens's overworld art is four shades, sometimes tinted: ranked by
// brightness, the lightest (or see-through) is the backdrop, the rest take
// the look's colours. -Elvie
function shadeWalk(img, colors) {
  const c = document.createElement("canvas");
  c.width = img.width;
  c.height = img.height;
  const ctx = c.getContext("2d");
  ctx.drawImage(img, 0, 0);
  const data = ctx.getImageData(0, 0, c.width, c.height);
  const px = data.data, seen = new Map();
  let clear = false;
  for (let i = 0; i < px.length; i += 4) {
    if (px[i + 3] < 128) { clear = true; continue; }
    const key = (px[i] << 16) | (px[i + 1] << 8) | px[i + 2];
    if (!seen.has(key)) seen.set(key, 0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2]);
  }
  const ranked = [...seen.keys()].sort((a, b) => seen.get(b) - seen.get(a));
  const shade = new Map(ranked.map((k, i) => [k, Math.min(3, (clear ? 1 : 0) + i)]));
  for (let i = 0; i < px.length; i += 4) {
    const s = px[i + 3] < 128 ? 0 : shade.get((px[i] << 16) | (px[i + 1] << 8) | px[i + 2]);
    if (!s) { px[i + 3] = 0; continue; }
    [px[i], px[i + 1], px[i + 2]] = colors[s];
    px[i + 3] = 255;
  }
  ctx.putImageData(data, 0, 0);
  return c;
}

async function gbPreview() {
  freeURLs("gb-preview");
  const notes = [];
  const pick = (names) => names.find((n) => exists(`look/${n}`));
  const front = pick(["frontColor.png", "front.png"]);
  const back = pick(["backColor.png", "back.png"]);
  const walk = exists("look/overworldWalk.png") ? "overworldWalk.png" : null;
  const surf = exists("look/overworldSurf.png") ? "overworldSurf.png" : null;
  const fishOwn = GB_FISH.some(([, f]) => exists(`look/${f}`)) || exists("look/overworldFishRod.png");
  $("gb-preview").hidden = !(front || back || walk || surf);
  for (const [id, file] of [["gb-front", front], ["gb-back", back]]) {
    const canvas = $(id);
    scaled(canvas);
    canvas.parentElement.hidden = !file;
    if (!file) continue;
    const img = await loadImg(`look/${file}`, "gb-preview");
    if (fitPic(canvas, img)) {
      notes.push(`${file} is ${img.width}x${img.height}: the game shows ${img.height > canvas.height ? `its top ${canvas.height} rows` : `its middle ${canvas.width} columns`}.`);
    }
  }
  const colors = Array.isArray(keptMeta.overworldColors) && keptMeta.overworldColors.length === 4
    ? keptMeta.overworldColors : CRYSTAL_COLORS;
  // Loads the overworld files, checks their sizes and shades them together,
  // as the mod does: { name: canvas } -Elvie
  const sizes = { "overworldWalk.png": [16, 96], "overworldSurf.png": [16, 96], "overworldFishFront.png": [16, 8],
    "overworldFishBack.png": [16, 8], "overworldFishSide.png": [16, 8], "overworldFishRod.png": [8, 16] };
  const imgs = {};
  for (const [name, [w, h]] of Object.entries(sizes)) {
    if (!exists(`look/${name}`)) continue;
    const img = await loadImg(`look/${name}`, "gb-preview");
    if (img.width === w && img.height === h) imgs[name] = img;
    else notes.push(`${name} is ${img.width}x${img.height}; it needs ${w}x${h}, so the game won't use it.`);
  }
  const shaded = {};
  const fishNames = Object.keys(imgs).filter((n) => n.startsWith("overworldFish"));
  if (imgs["overworldWalk.png"] || fishNames.length) {
    // the walk and the fishing files ranked as one picture -Elvie
    const names = [...(imgs["overworldWalk.png"] ? ["overworldWalk.png"] : []), ...fishNames];
    const stack = document.createElement("canvas");
    stack.width = 16;
    stack.height = names.reduce((n, k) => n + imgs[k].height, 0);
    let y = 0;
    const at = {};
    for (const k of names) { stack.getContext("2d").drawImage(imgs[k], 0, y); at[k] = y; y += imgs[k].height; }
    const all = shadeWalk(stack, colors);
    for (const k of names) {
      const c = document.createElement("canvas");
      c.width = imgs[k].width;
      c.height = imgs[k].height;
      c.getContext("2d").drawImage(all, 0, at[k], c.width, c.height, 0, 0, c.width, c.height);
      shaded[k] = c;
    }
  }
  if (imgs["overworldSurf.png"]) shaded["overworldSurf.png"] = shadeWalk(imgs["overworldSurf.png"], colors);
  const strip = (id, file, rowOf) => {
    const c = $(id);
    scaled(c);
    c.parentElement.hidden = !shaded[file];
    const ctx = c.getContext("2d");
    ctx.clearRect(0, 0, c.width, c.height);
    if (!shaded[file]) return;
    GB_WALK.forEach(([f, mirror, step], i) => {
      const y = rowOf(step);
      ctx.save();
      if (mirror) {
        ctx.translate(i * 16 + 16, 0);
        ctx.scale(-1, 1);
        ctx.drawImage(shaded[file], 0, f * 16, 16, 16, 0, y, 16, 16);
      } else {
        ctx.drawImage(shaded[file], 0, f * 16, 16, 16, i * 16, y, 16, 16);
      }
      ctx.restore();
    });
  };
  strip("gb-walk", "overworldWalk.png", (step) => (step ? 31 : 30) - 15);
  // surfing: the tile the player stands on, the bottom 16 rows -Elvie
  strip("gb-surf", "overworldSurf.png", () => 16);
  // fishing, when the look has its own fishing art and a walk to put it under -Elvie
  const fc = $("gb-fish");
  scaled(fc);
  const fishReady = shaded["overworldWalk.png"] && GB_FISH.every(([, f]) => shaded[f]) && shaded["overworldFishRod.png"];
  fc.parentElement.hidden = !fishReady;
  if (fishOwn && !fishReady) {
    notes.push("Fishing needs all three overworldFish files, overworldFishRod.png and overworldWalk.png to show here. In the game, missing parts come from an installed Red, Blue or Yellow.");
  }
  if (fishReady) {
    const ctx = fc.getContext("2d");
    ctx.clearRect(0, 0, fc.width, fc.height);
    GB_FISH.forEach(([facing, file, [dx, dy, tile]], i) => {
      const x0 = i * 32 + 8, y0 = 30 - 15;
      ctx.drawImage(shaded["overworldWalk.png"], 0, GB_STAND[facing] * 16, 16, 8, x0, y0, 16, 8);
      ctx.drawImage(shaded[file], 0, 0, 16, 8, x0, y0 + 8, 16, 8);
      ctx.drawImage(shaded["overworldFishRod.png"], 0, tile * 8, 8, 8, x0 + dx, y0 + dy, 8, 8);
    });
  }
  const logEl = $("gb-log");
  logEl.hidden = !notes.length;
  logEl.textContent = notes.join("\n");
}

function showGb() {
  $("look-gb").hidden = !isGb();
  $("gb-rom-note").hidden = !$("gb-rom").value;
  if (!isGb() || !W) return;
  const box = $("gb-list");
  freeURLs("gb-list");
  const have = gbHas();
  if (!have.length) {
    const p = document.createElement("p");
    p.className = "empty";
    p.textContent = $("gb-rom").value
      ? "No files needed: the sprites come from your game. Add a front or back pic if you have them."
      : "No Game Boy files yet. Add a Crystal Lens look's PNGs, or pick a game to take the sprites from.";
    box.replaceChildren(p);
  } else {
    const row = document.createElement("div");
    row.className = "list";
    for (const name of have) {
      const fig = document.createElement("figure");
      fig.className = "file";
      fig.style.margin = "0";
      const frame = document.createElement("div");
      frame.className = "frame";
      const img = new Image();
      img.alt = name;
      img.src = imageURL(`look/${name}`, "gb-list");
      frame.append(img);
      const cap = document.createElement("figcaption");
      cap.textContent = name + " ";
      const rm = document.createElement("button");
      rm.type = "button";
      rm.className = "btn quiet";
      rm.textContent = "Remove";
      rm.setAttribute("aria-label", `Remove ${name}`);
      rm.addEventListener("click", () => {
        W.clear(`look/${name}`);
        showGb();
        refresh();
      });
      cap.append(rm);
      fig.append(frame, cap);
      row.append(fig);
    }
    box.replaceChildren(row);
  }
  gbPreview().catch((err) => {
    $("gb-log").hidden = false;
    $("gb-log").textContent = err.message;
  });
}

// PNGs go in by their Crystal Lens name, from any folder; anything else is
// skipped with a note. -Elvie
async function addGb(items) {
  const added = [], skipped = [];
  for (const { file, path } of items) {
    const name = path.split("/").pop();
    if (!GB_FILES.includes(name)) {
      if (!name.startsWith(".")) skipped.push(name);
      continue;
    }
    writeFile(`look/${name}`, new Uint8Array(await file.arrayBuffer()));
    added.push(name);
  }
  showGb();
  const parts = [];
  if (added.length) parts.push(`Added ${added.join(", ")}.`);
  if (skipped.length) parts.push(`Skipped ${skipped.join(", ")}: not a Game Boy look file (${GB_FILES.join(", ")}).`);
  status(parts.join(" "), added.length ? "ready" : "failed");
}

$("gb-files").addEventListener("change", (e) => upload(fromInput(e.target), addGb, e.target));
$("gb-rom").addEventListener("change", () => {
  showGb();
  refresh();
});
$("m-generation").addEventListener("change", () => {
  showGb();
  showLook();
});

function metaJson() {
  const meta = { ...keptMeta, label: $("m-label").value.trim() };
  delete meta.character;
  const character = $("m-character").value.trim();
  if (character) meta.character = character;
  meta.genderMode = $("m-gender").value;
  // Game Boy looks are generation 2 in the mod's fallback order -Elvie
  meta.generation = isGb() ? 2 : Number($("m-generation").value);
  delete meta.romOverworld;
  if (isGb() && $("gb-rom").value) meta.romOverworld = $("gb-rom").value;
  delete meta.credit;
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
    keptMeta = { ...meta };
    $("m-folder").value = s.path.split("/").pop();
    state.folderTouched = true;
    $("m-label").value = meta.label || "";
    $("m-character").value = meta.character || "";
    $("m-gender").value = ["girl", "boy", "enby"].includes(meta.genderMode) ? meta.genderMode : "girl";
    // left out (or anything but 4) is Gen 3, as lens.lua reads it; a folder
    // with Game Boy art and no gen3 folder is a Game Boy look -Elvie
    const gb = !exists("look/gen3") && (gbHas().length > 0 || !!meta.romOverworld);
    $("m-generation").value = gb ? "gb" : Number(meta.generation) === 4 ? "4" : "3";
    $("gb-rom").value = ["red", "blue", "gold", "kris"].includes(meta.romOverworld) ? meta.romOverworld : "";
    showGb();
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
  $("gb-rom").value = "";
  keptMeta = {};
  showGb();
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
  // a Game Boy look can be just its files, or just a meta.json naming a game -Elvie
  const packed = ready && (list("look/gen3").length > 0 || (isGb() && (gbHas().length > 0 || !!$("gb-rom").value)));
  $("do-download").disabled = !packed;
  const rse = ready && exists("look/gen3/rse");
  $("look-dive").hidden = !rse;
  $("dive-blob").disabled = !rse || !exists("look/gen3/rse/surfBlob.png");
  $("dive-under").disabled = !rse || !exists("look/gen3/rse/surf.png");
  const blobLook = ready && (exists("look/gen3/frlg") || exists("look/gen3/rse"));
  if (blobLook && $("look-blobs").hidden) blobShow();
  $("look-blobs").hidden = !blobLook;
  const flySurf = ready && exists("look/gen3/frlg/surf.png");
  $("look-fly").hidden = !flySurf;
  $("fly-save").disabled = !flySurf;
  // redraw the bird when the look's rider changes -Elvie
  const key = flySurf ? String(FS.stat(work("look/gen3/frlg/surf.png")).mtime) : "";
  if (key !== fly.shown) {
    fly.shown = key;
    if (flySurf) flyShow();
  }
  $("do-clear").disabled = !packed;
}

refresh();
boot();
