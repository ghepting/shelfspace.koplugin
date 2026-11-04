// Gives the pieces a rounded bottom, so they sit on the plank like the plants do instead of on a flat line (the tops are already drawn
// from slightly above). The bottom rows of every layer that reaches the base are stretched downward by a curve: most in the middle,
// none at the edges. One function of absolute position is applied to the back, liquid and front alike, so they stay in step.
// Needs ImageMagick. Usage: node tools/art/curve.js <dir with the lab's PNGs and spec.json> <output dir>
const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const [src, out] = process.argv.slice(2);
fs.mkdirSync(out, { recursive: true });
const spec = JSON.parse(fs.readFileSync(path.join(src, "spec.json"), "utf8"));
const magick = (...a) => execFileSync("magick", a, { maxBuffer: 1 << 28 });
const size = f => magick("identify", "-format", "%w %h", f).toString().split(" ").map(Number);

for (const f of fs.readdirSync(src)) if (f.endsWith(".png")) fs.copyFileSync(path.join(src, f), path.join(out, f));

// Where a front layer's dark outline ends at the bottom, and how wide it is there: { yb, cx, hw } in px
function foot(file) {
  const [w, h] = size(file);
  const a = magick(file, "-alpha", "extract", "-depth", "8", "gray:-");
  let yb = -1;
  for (let y = h - 1; y >= 0 && yb < 0; y--) for (let x = 0; x < w; x++) if (a[y * w + x] > 200) { yb = y; break; }
  let l = w, r = 0;
  for (let x = 0; x < w; x++) if (a[(yb - 2) * w + x] > 200) { l = Math.min(l, x); r = Math.max(r, x); }
  return { yb, cx: (l + r) / 2, hw: (r - l) / 2 + 4 };
}

const D = 8; // how far the middle of the bottom drops, px (4 art units)
const BAND = 44; // how much of the bottom is stretched, px
function curve(file, ox, oy, H0, f, depth, band, extend) {
  const [w, h] = size(file);
  const Y0 = f.yb - band;
  const drop = `${depth}*max(0,1-((i-${f.cx - ox})/${f.hw})^2)`; // how far down this column goes
  const expr = `yy=(j+${oy}<${Y0})?j:${Y0 - oy}+(j-${Y0 - oy})*(${H0}-${Y0})/(${H0}-${Y0}+${drop}); u.p{i,yy}`;
  magick(file, "-background", "none", "-gravity", "north", "-extent", `${w}x${h + extend}`, "+gravity", "-alpha", "set", "-channel", "RGBA", "-fx", expr, file);
  return extend;
}

for (const id of ["flask", "glass", "whiskey", "decanter", "inkwell"]) {
  const o = spec[id], f = foot(path.join(out, `${id}-front.png`));
  const H0 = size(path.join(out, `${id}-front.png`))[1];
  for (const name of ["back", "liquid", "front"]) {
    const l = o.layers[name], file = path.join(out, `${id}-${name}.png`);
    const reaches = (l.y + l.h) * 2 >= H0 - 2;
    const e = reaches ? D : 2;
    curve(file, l.x * 2, l.y * 2, H0, f, D, BAND, e);
    l.h += e / 2;
  }
  console.log(id, f);
}
{ // the candle's dish is a low plate: a shorter band and a smaller drop
  const l = spec.candle.layers.dish, file = path.join(out, "candle-dish.png"), f = foot(file), H0 = size(file)[1];
  const ox = l.x * 2, oy = l.y * 2;
  f.yb += oy; f.cx += ox; // the foot is measured in the sprite; the curve works in the piece's own coordinates
  curve(file, ox, oy, H0 + oy, f, 6, 14, 6);
  l.h += 3;
  console.log("candle dish", f);
}
fs.writeFileSync(path.join(out, "spec.json"), JSON.stringify(spec, null, 1));
