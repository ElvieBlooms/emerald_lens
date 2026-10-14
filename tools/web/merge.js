// Clash picker: where two sources draw the same frame differently,
// pack_gen3.py merge keeps the first and reports the clash (--report) with
// each version saved as a PNG (--clash-frames). This shows them side by
// side; the choices go back to merge as --pick file:frame=source. -Elvie

export function createClashPicker(root, api) {
  // api: {imageURL(path, owner), freeURLs(owner), label(family, file, frame), busy}
  root.classList.add("clashes");

  // run: {report, framesDir, names: [source names], apply(picks)}
  function show(run) {
    api.freeURLs(root.id);
    root.replaceChildren();
    const clashes = run.report.clashes;
    root.hidden = !clashes.length;
    if (!clashes.length) return;
    const chosen = new Map(clashes.map((c) => [`${c.file}:${c.frame}`, c.kept]));

    const head = document.createElement("div");
    head.className = "clash-head";
    const h = document.createElement("h3");
    h.className = "sub";
    h.textContent = clashes.length === 1 ? "1 frame is drawn differently" : `${clashes.length} frames are drawn differently`;
    const p = document.createElement("p");
    p.className = "hint";
    p.textContent = "Pick the version to keep for each, then apply. The first source is kept until you choose.";
    head.append(h, p);
    const bulk = document.createElement("div");
    bulk.className = "row";
    const sources = [...new Set(clashes.flatMap((c) => c.sources))].sort((a, b) => a - b);
    for (const k of sources) {
      const b = document.createElement("button");
      b.type = "button";
      b.className = "btn quiet";
      b.textContent = `Keep all from ${k}: ${run.names[k - 1] || "source " + k}`;
      b.addEventListener("click", () => {
        for (const c of clashes) if (c.sources.includes(k)) chosen.set(`${c.file}:${c.frame}`, k);
        mark();
      });
      bulk.append(b);
    }
    head.append(bulk);
    root.append(head);

    const grid = document.createElement("div");
    grid.className = "clash-grid";
    const buttons = [];
    for (const c of clashes) {
      const card = document.createElement("fieldset");
      card.className = "clash";
      const legend = document.createElement("legend");
      legend.textContent = `${c.file} frame ${c.frame}`;
      const sub = document.createElement("span");
      sub.className = "clash-where";
      sub.textContent = api.label(c.family, c.file, c.frame);
      legend.append(sub);
      card.append(legend);
      const row = document.createElement("div");
      row.className = "clash-row";
      for (const k of c.sources) {
        const b = document.createElement("button");
        b.type = "button";
        b.className = "clash-pick";
        const img = new Image();
        img.alt = `${c.file} frame ${c.frame}, source ${k}`;
        img.src = api.imageURL(`${run.framesDir}/${c.file.replace(/\.png$/, "")}_${c.frame}_${k}.png`, root.id);
        const same = (c.same_as[String(k)] || []).map(String);
        const cap = document.createElement("span");
        cap.textContent = `${[k, ...same].join(", ")}: ${run.names[k - 1] || "source " + k}`;
        b.append(img, cap);
        b.addEventListener("click", () => {
          chosen.set(`${c.file}:${c.frame}`, k);
          mark();
        });
        buttons.push({ b, key: `${c.file}:${c.frame}`, k });
        row.append(b);
      }
      card.append(row);
      grid.append(card);
    }
    root.append(grid);

    const apply = document.createElement("button");
    apply.type = "button";
    apply.className = "btn primary";
    apply.textContent = "Apply these choices";
    apply.addEventListener("click", (e) =>
      api.busy(e.currentTarget, async () => {
        const picks = [...chosen].map(([key, k]) => `${key}=${k}`);
        await run.apply(picks);
      })
    );
    const row = document.createElement("div");
    row.className = "row";
    row.append(apply);
    root.append(row);

    function mark() {
      for (const { b, key, k } of buttons) {
        const on = chosen.get(key) === k;
        b.classList.toggle("on", on);
        b.setAttribute("aria-pressed", on ? "true" : "false");
      }
    }
    mark();
  }

  return {
    show,
    hide() {
      api.freeURLs(root.id);
      root.replaceChildren();
      root.hidden = true;
    },
  };
}
