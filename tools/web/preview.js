// Animated previews: a section's frames played back in the game's order,
// on a tile like the overworld (or alone, for battle pics and the like).
// Used by the builder (frames as build will place them) and by step 4
// (the packed files, as the game reads them). -Elvie

const TICK = 1000 / 60; // the game runs at 60 frames a second

// Back pics, as frame numbers of back.png with durations in game frames,
// from the games' own back_anims. FRLG stands on 0; RSE stands on 3. -Elvie
const BACK = {
  frlg: { idle: 0, throw: [[1, 20], [2, 6], [3, 6], [4, 24]] },
  rse: { idle: 3, throw: [[0, 24], [1, 9], [2, 24], [0, 9]] },
};

// Overworld cycles with three frames a facing (stand, step, step): played
// step, stand, step, stand, the ground moving `move` pixels a game frame.
// Durations are pokeemerald's sAnim_GoSouth (8 game frames a frame) and
// sAnim_GoFastSouth (4). -Elvie
const WALKERS = {
  walk: { ticks: 8, move: 1 },
  run: { ticks: 4, move: 2 },
  bike: { ticks: 4, move: 2 },
  "mach bike": { ticks: 4, move: 2 },
  underwater: { ticks: 8, move: 1 },
};
// Acro Bike tricks, from pokeemerald's object_event_anims.h and
// event_object_movement.c: frame numbers of acroBike.png per facing, 4 game
// frames each. Popping a wheelie plays 9, 10 and holds 10 while balancing;
// landing plays 9, 0. A bunny hop holds 10 through a 16-frame low jump
// (sJumpY_Low). Riding a wheelie plays 21, 10, 22, 10, moving 2 px a frame.
// Frames 11/12 (front wheel up) only belong to actions the game never
// uses. Right is left mirrored. -Elvie
const ACRO = {
  down: { stand: 0, back: [9, 10], front: [11, 12], ride: [21, 22] },
  up: { stand: 1, back: [13, 14], front: [15, 16], ride: [23, 24] },
  left: { stand: 2, back: [17, 18], front: [19, 20], ride: [25, 26] },
};
const JUMP_LOW = [0, -2, -3, -4, -5, -6, -6, -6, -5, -5, -4, -3, -2, 0, 0, 0];
const BALANCE = 48;  // how long the preview holds a wheelie before landing

const BOB = 16;      // surf bob: game frames per half (approximate)
// Underwater the game bobs the diver 1px every 4 frames, turning round
// every 16 (field_effect_helpers.c, SpriteCB_UnderwaterSurfBlob): down 4px
// and back up, 32 frames a round. Moving or not. -Elvie
const DIVE_BOB = 32;
const diveBob = (t) => {
  const k = Math.floor(t) % DIVE_BOB;
  return k < 16 ? Math.floor(k / 4) + 1 : 3 - Math.floor((k - 16) / 4);
};
const CYCLE = 8;     // anything else: each frame in turn
const HOLD = 60;     // battle idle between throws

const FACES = ["down", "up", "left", "right"];
const NAMES = { down: "Down", up: "Up", left: "Left", right: "Right", frames: "" };

// What to play for a section. sec is {facings: {facing: [[file, index]]}}.
export function sceneFor(key, family, sec) {
  const base = family.startsWith("frlg") ? "frlg" : "rse";
  const facings = Object.keys(sec.facings);
  if (family === "gb" && (WALKERS[key] || key === "surf") && sec.facings.down) {
    // Game Boy: stand and one step a facing; down and up flip every
    // other step, left doesn't (gameboy.lua's WALK). Surfing walks the
    // same, on water with no blob. -Elvie
    const w = WALKERS[key] || WALKERS.walk;
    const seq = (f) => [[1, w.ticks], [0, w.ticks], [1, w.ticks, f !== "left"], [0, w.ticks]];
    return { key, kind: "facing", seq: seq("down"), seqs: { down: seq("down"), up: seq("up"), left: seq("left") },
             move: w.move, water: key === "surf",
             note: "Step, stand, flipped step, stand, as the mod plays Game Boy art." };
  }
  if (key === "back" && sec.facings.frames && family !== "gb") {
    const slotOf = (frame) => sec.facings.frames.findIndex(([, i]) => i === frame);
    const b = BACK[base];
    const seq = [[slotOf(b.idle), HOLD], ...b.throw.map(([f, t]) => [slotOf(f), t])].filter(([s]) => s >= 0);
    return { key, kind: "frames", seq, note: "Idle, then the throw, at the game's speed." };
  }
  if (!sec.facings.down) {
    const n = sec.facings.frames.length;
    return { key, kind: "frames", seq: sec.facings.frames.map((_, i) => [i, n > 1 ? 12 : Infinity]) };
  }
  if (key === "surf") {
    return { key, kind: "facing", surf: true, seq: [[0, Infinity]], move: 0,
             note: "The sit frame on the surf blob, bobbing while still, as the game lines them up." };
  }
  if (key === "acro bike") return acroScene(key, sec);
  if (key === "underwater") {
    const w = WALKERS[key];
    const seq = [[1, w.ticks], [0, w.ticks], [2, w.ticks], [0, w.ticks]];
    return { key, kind: "facing", dive: true, seq, move: w.move,
             note: "Diving: step, stand, step, stand, bobbing as the game does. A dive blob, if the look has one, goes behind, where the surf blob would." };
  }
  const w = WALKERS[key];
  if (w) {
    const seq = [[1, w.ticks], [0, w.ticks], [2, w.ticks], [0, w.ticks]];
    return { key, kind: "facing", seq, move: w.move,
             note: "Step, stand, step, stand; the ground moves as the game would." };
  }
  const n = sec.facings[facings[0]].length;
  return { key, kind: "facing", seq: Array.from({ length: n }, (_, i) => [i, key === "surf blob" ? BOB : CYCLE]), move: 0 };
}

// The Acro Bike: riding plus its tricks, each a variant the stage offers.
// Frames become slots of this section (each facing's own list). -Elvie
function acroScene(key, sec) {
  const per = (fn) => Object.fromEntries(["down", "up", "left"].map((f) => {
    const slot = (frame) => sec.facings[f].findIndex(([, i]) => i === frame);
    return [f, fn(ACRO[f]).map(([frame, t]) => [slot(frame), t]).filter(([i]) => i >= 0)];
  }));
  const riding = Object.fromEntries(["down", "up", "left"].map((f) => [f, [[1, 4], [0, 4], [2, 4], [0, 4]]]));
  const variants = [
    { id: "ride", label: "Riding", seqs: riding, move: 2,
      note: "Riding: the first three frames of each facing, step, stand, step, stand." },
    { id: "wheelie", label: "Wheelie", move: 0,
      seqs: per((a) => [[a.back[0], 4], [a.back[1], BALANCE], [a.back[0], 4], [a.stand, 32]]),
      note: "Popping a wheelie and landing it, at the game's timing. The balance is held longer here than you'd hold B." },
    { id: "hop", label: "Bunny hop", move: 0, hop: true,
      seqs: per((a) => [[a.back[1], 16]]),
      note: "Bunny hopping in place: the balance frame through the game's low jump, 16 frames a hop. The shadow is a stand-in." },
    { id: "wheelie-ride", label: "Wheelie, moving", move: 2,
      seqs: per((a) => [[a.ride[0], 4], [a.back[1], 4], [a.ride[1], 4], [a.back[1], 4]]),
      note: "Riding on the back wheel: the two wheelie pedal frames between balance frames, moving 2 px a frame." },
    { id: "front", label: "Front-wheel frames", move: 0,
      seqs: per((a) => [[a.front[0], 4], [a.front[1], 4]]),
      note: "Frames 11-12, 15-16 and 19-20: on the sheet, but only used by actions the game never runs. Fine to leave blank." },
  ];
  return { key, kind: "facing", seq: riding.down, move: 2, variants };
}

// ------------------------------------------------------------------ stage

export function createStage(root, opts = {}) {
  root.classList.add("stage");
  root.innerHTML = `
    <div class="stage-bar">
      <strong class="stage-title"></strong>
      <button type="button" class="btn quiet stage-play">Pause</button>
      <button type="button" class="btn quiet stage-step">Next frame</button>
      <label class="stage-trick-label">Trick <select class="stage-trick"></select></label>
      <label>Speed <select class="stage-speed"><option value="0.25">¼</option><option value="0.5">½</option><option value="1" selected>1</option><option value="2">2</option></select></label>
      <label class="stage-move-label"><input type="checkbox" class="stage-move" checked> Moving</label>
      <label>Zoom <select class="stage-zoom"><option>2</option><option selected>3</option><option>4</option></select></label>
      <button type="button" class="btn quiet stage-gif">Save as GIF</button>
    </div>
    <div class="stage-cells"></div>
    <p class="hint stage-note"></p>`;
  const q = (s) => root.querySelector(s);
  const ui = { title: q(".stage-title"), play: q(".stage-play"), step: q(".stage-step"), speed: q(".stage-speed"),
               move: q(".stage-move"), moveLabel: q(".stage-move-label"), zoom: q(".stage-zoom"),
               cells: q(".stage-cells"), note: q(".stage-note"),
               trick: q(".stage-trick"), trickLabel: q(".stage-trick-label"), gif: q(".stage-gif") };
  ui.gif.hidden = !opts.saveGif;
  let fileName = "preview";
  ui.zoom.value = String(opts.zoom || 3);
  // base: the scene as given; scene: base with its chosen variant applied
  let base = null, scene = null, source = null, cells = [];
  const chosen = {}; // variant id per section key
  let tick = 0, playing = !matchMedia("(prefers-reduced-motion: reduce)").matches, last = 0, raf = 0;
  ui.play.textContent = playing ? "Pause" : "Play";

  const seqOf = (facing) => (scene.seqs && scene.seqs[facing]) || scene.seq;
  const total = () => seqOf("down").reduce((n, [, t]) => n + (Number.isFinite(t) ? t : 0), 0);
  const animated = () => scene && (scene.surf || scene.hop || scene.dive || total() > 0 && seqOf("down").length > 1 || (scene.move && ui.move.checked));

  // The seq entry at tick t: [slot, ticks, flipped?]. -Elvie
  function entryAt(t, facing) {
    const seq = seqOf(facing);
    if (!seq.length) return [-1];
    const len = seq.reduce((n, [, d]) => n + (Number.isFinite(d) ? d : 0), 0);
    if (!len) return seq[0];
    let r = t % len;
    for (const e of seq) {
      if (r < e[1]) return e;
      r -= e[1];
    }
    return seq[0];
  }

  function slotAt(t, facing) {
    return entryAt(t, facing)[0];
  }

  function apply() {
    const v = base.variants && (base.variants.find((x) => x.id === chosen[base.key]) || base.variants[0]);
    scene = v ? { ...base, ...v } : base;
    ui.trickLabel.hidden = !base.variants;
    ui.note.textContent = scene.note || "";
    ui.moveLabel.hidden = !scene.move;
    ui.step.hidden = ui.play.hidden = !(scene.surf || scene.hop || seqOf("down").length > 1);
  }

  function colors() {
    const s = getComputedStyle(document.documentElement);
    const v = (n, d) => s.getPropertyValue(n).trim() || d;
    return { ground: v("--check-a", "#fff"), line: v("--line", "#ccc"), water: v("--water", "#9cc8dc"),
             wave: v("--wave", "#c6e2ee"), guide: v("--guide", "#f0f") };
  }

  // Stand-in surf blob when the look has none: a plain shape, not game art.
  function standInBlob() {
    const c = document.createElement("canvas");
    c.width = c.height = 32;
    const g = c.getContext("2d");
    g.fillStyle = "rgba(60, 130, 200, 0.55)";
    g.beginPath();
    g.ellipse(16, 20, 14, 9, 0, 0, Math.PI * 2);
    g.fill();
    return c;
  }

  function build() {
    ui.cells.replaceChildren();
    cells = [];
    const faces = scene.kind === "frames" ? ["frames"] : FACES;
    for (const face of faces) {
      const fig = document.createElement("figure");
      fig.className = "stage-cell";
      const c = document.createElement("canvas");
      if (scene.kind === "frames") {
        const f = source.size();
        c.width = f[0];
        c.height = f[1];
      } else {
        c.width = 48;
        c.height = 48;
      }
      c.setAttribute("role", "img");
      c.setAttribute("aria-label", `${scene.key} ${NAMES[face] || ""}`.trim());
      fig.append(c);
      if (NAMES[face]) {
        const cap = document.createElement("figcaption");
        cap.textContent = NAMES[face];
        fig.append(cap);
      }
      ui.cells.append(fig);
      cells.push({ face, canvas: c });
    }
    sizeCells();
  }

  function sizeCells() {
    const z = Number(ui.zoom.value) || 3;
    const scale = scene && scene.kind === "frames" && cells[0] && cells[0].canvas.width >= 64 ? Math.max(1, z - 1) : z;
    for (const { canvas } of cells) {
      canvas.style.width = canvas.width * scale + "px";
      canvas.style.height = canvas.height * scale + "px";
    }
  }

  function draw() {
    if (!scene) return;
    const col = colors();
    for (const { face, canvas } of cells) {
      const g = canvas.getContext("2d");
      g.imageSmoothingEnabled = false;
      g.clearRect(0, 0, canvas.width, canvas.height);
      if (face === "frames") {
        const img = source.frame("frames", slotAt(tick, "frames"));
        if (img) g.drawImage(img, 0, 0);
        continue;
      }
      const facing = face === "right" ? "left" : face;
      const mirror = face === "right";
      const moving = scene.move && ui.move.checked;
      // the ground: 16px tiles, scrolling against the way the player faces
      const off = moving ? (tick * scene.move) % 16 : 0;
      const dx = { left: off, right: -off, up: 0, down: 0 }[face];
      const dy = { up: off, down: -off, left: 0, right: 0 }[face];
      const wet = scene.surf || scene.dive || scene.water;
      g.fillStyle = wet ? col.water : col.ground;
      g.fillRect(0, 0, 48, 48);
      g.strokeStyle = wet ? col.wave : col.line;
      g.lineWidth = 1;
      g.beginPath();
      for (let x = ((dx % 16) + 16) % 16; x <= 48; x += 16) { g.moveTo(x + 0.5, 0); g.lineTo(x + 0.5, 48); }
      for (let y = ((dy % 16) + 16) % 16 + 8; y <= 48; y += 16) { g.moveTo(0, y + 0.5); g.lineTo(48, y + 0.5); }
      g.stroke();
      // the player's tile: top-left at (16, 24), feet on its bottom edge
      // (4px higher underwater, so the blob's bob stays in the cell)
      const tx = 16, ty = scene.dive ? 20 : 24;
      let bob = 0, half = 0;
      if (scene.surf) {
        half = !moving && Math.floor(tick / BOB) % 2 === 1 ? 1 : 0;
        bob = -half;
        const blobs = source.blobCount(facing);
        const blob = source.blob(facing, blobs > 1 ? half : 0) || standInBlob();
        drawImg(g, blob, tx - 8, ty - 8 + bob, mirror);
      }
      if (scene.dive) {
        // the blob moves with the diver, as it does in the mod -Elvie
        bob = diveBob(tick);
        const blob = source.diveBlob && source.diveBlob(facing);
        if (blob) drawImg(g, blob, tx - 8, ty - 8 + bob, mirror);
      }
      if (scene.hop) {
        // the hop: the game's low jump arc, over a plain stand-in shadow
        bob = JUMP_LOW[Math.floor(tick) % JUMP_LOW.length];
        g.fillStyle = "rgba(0, 0, 0, 0.25)";
        g.beginPath();
        g.ellipse(tx + 8, ty + 15, 7, 2.5, 0, 0, Math.PI * 2);
        g.fill();
      }
      const [slot, , flip] = scene.surf ? [0] : entryAt(tick, facing);
      const img = slot >= 0 ? source.frame(facing, slot) : null;
      if (img) drawImg(g, img, tx + Math.floor((16 - img.width) / 2), ty + 16 - img.height + bob, mirror !== !!flip);
    }
  }

  function drawImg(g, img, x, y, mirror) {
    if (!mirror) {
      g.drawImage(img, x, y);
      return;
    }
    g.save();
    g.translate(x + img.width, y);
    g.scale(-1, 1);
    g.drawImage(img, 0, 0);
    g.restore();
  }

  function loop(now) {
    raf = 0;
    if (!playing || !scene || !root.isConnected) return;
    if (last) tick += ((now - last) / TICK) * Number(ui.speed.value);
    last = now;
    draw();
    raf = requestAnimationFrame(loop);
  }

  function start() {
    last = 0;
    if (!raf && playing && animated()) raf = requestAnimationFrame(loop);
  }

  ui.play.addEventListener("click", () => {
    playing = !playing;
    ui.play.textContent = playing ? "Pause" : "Play";
    start();
  });
  ui.step.addEventListener("click", () => {
    // on to the start of the next frame in the sequence
    if (!scene) return;
    if (scene.surf) {
      tick = (Math.floor(tick / BOB) + 1) * BOB;
    } else if (scene.hop) {
      tick = Math.floor(tick) + 2; // a hop is one frame; step through its arc
    } else {
      const len = total();
      if (!len) return;
      const at = Math.floor(tick / len) * len;
      let acc = 0;
      for (const [, d] of seqOf("down")) {
        acc += d;
        if (acc > tick - at) break;
      }
      tick = at + acc;
    }
    playing = false;
    ui.play.textContent = "Play";
    draw();
  });
  ui.zoom.addEventListener("change", sizeCells);

  // ------------------------------------------------------------ GIF export
  // The loop rendered one game frame at a time, at the zoom on screen:
  // every facing side by side, transparent between them. Frames that don't
  // change are merged, and their lengths become GIF delays (hundredths of
  // a second, rounded so the loop keeps the game's timing). Moving scenes
  // are sampled every 2 game frames: GIFs can't show 60 a second. -Elvie

  const gcd = (a, b) => (b ? gcd(b, a % b) : a);
  const lcm = (a, b) => (a / gcd(a, b)) * b;

  function loopLength() {
    let n = total() || 1;
    if (scene.surf) n = lcm(n, 2 * BOB);
    if (scene.dive) n = lcm(n, DIVE_BOB);
    if (scene.move && ui.move.checked) n = lcm(n, 16 / gcd(16, scene.move));
    return n;
  }

  function gifScale() {
    const z = Number(ui.zoom.value) || 3;
    return scene.kind === "frames" && cells[0] && cells[0].canvas.width >= 64 ? Math.max(1, z - 1) : z;
  }

  async function exportGif() {
    if (!scene || !opts.saveGif) return;
    const wasPlaying = playing, keep = tick;
    playing = false;
    const s = gifScale(), gap = 4 * s;
    const W = cells.reduce((n, c) => n + c.canvas.width * s, 0) + gap * (cells.length - 1);
    const H = Math.max(...cells.map((c) => c.canvas.height * s));
    const out = document.createElement("canvas");
    out.width = W;
    out.height = H;
    const g = out.getContext("2d", { willReadFrequently: true });
    g.imageSmoothingEnabled = false;
    const len = loopLength();
    const step = (scene.move && ui.move.checked) || scene.hop ? 2 : 1;
    const frames = [];
    for (let t = 0; t < len; t += step) {
      tick = t;
      draw();
      g.clearRect(0, 0, W, H);
      let x = 0;
      for (const { canvas } of cells) {
        g.drawImage(canvas, x, H - canvas.height * s, canvas.width * s, canvas.height * s);
        x += canvas.width * s + gap;
      }
      const data = g.getImageData(0, 0, W, H).data;
      const prev = frames[frames.length - 1];
      if (prev && sameBytes(prev.data, data)) prev.ticks += Math.min(step, len - t);
      else frames.push({ data, ticks: Math.min(step, len - t) });
    }
    // ticks -> hundredths of a second, carrying the remainder along
    const speed = Number(ui.speed.value) || 1;
    let carry = 0;
    const delays = frames.map((f) => {
      const exact = (f.ticks * 100) / 60 / speed + carry;
      const cs = Math.max(2, Math.round(exact));
      carry = exact - cs;
      return cs * 10;
    });
    tick = keep;
    playing = wasPlaying;
    draw();
    start();
    const variant = base.variants && scene.id ? `-${scene.id}` : "";
    await opts.saveGif({ width: W, height: H, frames: frames.map((f) => f.data), delays, name: `${fileName}${variant}.gif` });
  }

  function sameBytes(a, b) {
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
    return true;
  }

  ui.gif.addEventListener("click", (e) => (opts.busy ? opts.busy(e.currentTarget, exportGif) : exportGif()));
  ui.trick.addEventListener("change", () => {
    chosen[base.key] = ui.trick.value;
    tick = 0;
    apply();
    draw();
    start();
  });
  ui.move.addEventListener("change", () => { draw(); start(); });

  return {
    // source: {frame(facing, slot), blob(facing, k), blobCount(facing),
    // diveBlob(facing), size()}
    show(nextScene, nextSource, title, name) {
      fileName = (name || title || "preview").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "preview";
      const same = base && nextScene.key === base.key && nextScene.kind === base.kind;
      base = nextScene;
      source = nextSource;
      root.hidden = false;
      ui.title.textContent = title;
      if (base.variants) {
        ui.trick.replaceChildren(...base.variants.map((v) => {
          const o = document.createElement("option");
          o.value = v.id;
          o.textContent = v.label;
          return o;
        }));
        ui.trick.value = chosen[base.key] || base.variants[0].id;
      }
      apply();
      if (!same) tick = 0;
      build();
      draw();
      start();
    },
    hide() {
      root.hidden = true;
      base = scene = null;
    },
  };
}
