// Redraws the stack of books as seen from slightly above, like the standing spines on a shelf, instead of from the right: the cream
// page block at each book's right end is covered with more spine, the bottom book gets the rounded foot the other pieces have, and every
// book gets a top face (stack-top<N>.png: the cover seen from above, in the book's own colour) for when it is the top of the stack.
// Needs ImageMagick. Usage: node tools/art/restack.js <dir with the lab's stack-book<N>.png> <output dir>
const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const [src, out] = process.argv.slice(2);
fs.mkdirSync(out, { recursive: true });
const magick = (...a) => execFileSync("magick", a, { maxBuffer: 1 << 28 });

const TOP = 14; // px (7 art units): the top face
const FOOT = 5, FOOT_BAND = 12, FOOT_EXT = 6; // the bottom book's rounded foot: how far it drops, how much is stretched, how much taller

function read(file) {
  const [w, h] = magick("identify", "-format", "%w %h", file).toString().split(" ").map(Number);
  return { w, h, px: magick(file, "-depth", "8", "rgba:-") };
}
function write(img, file) {
  execFileSync("magick", ["-size", `${img.w}x${img.h}`, "-depth", "8", "rgba:-", file], { input: img.px, maxBuffer: 1 << 28 });
}
const at = (img, x, y) => (y * img.w + x) * 4;
const cream = (r, g, b, a) => a > 200 && r > 200 && g > 190 && b > 150 && r - b < 80; // the pages: pale and not yellow (gold tooling and tan covers are)
const gold = (r, g, b) => r - b > 100 && g > 185; // the gold tooling (a tan cover is yellow too, but darker)
const dark = (r, g, b) => r + g + b < 150;

for (let n = 0; fs.existsSync(path.join(src, `stack-book${n}.png`)); n++) {
  const img = read(path.join(src, `stack-book${n}.png`));
  const { w, h, px } = img;
  // where the page block is: the cream pixels in the right third
  let x0 = w, x1 = -1, y0 = h, y1 = -1;
  for (let y = 0; y < h; y++) for (let x = Math.floor(w * 0.66); x < w; x++) {
    const i = at(img, x, y);
    if (cream(px[i], px[i + 1], px[i + 2], px[i + 3])) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
  }
  if (x1 < 0) throw new Error(`stack-book${n}: no page block found`);
  // a column left of it that is plain spine: not gold, not the dark separator
  let sx = -1;
  for (let c = x0 - 6; c >= x0 - 30 && sx < 0; c--) {
    let bad = 0;
    for (let y = y0; y <= y1; y++) {
      const i = at(img, c, y), j = at(img, c + 3, y), k = at(img, c - 3, y);
      const apart = Math.abs(px[i] - px[j]) + Math.abs(px[i + 1] - px[j + 1]) + Math.abs(px[i + 2] - px[j + 2])
        + Math.abs(px[i] - px[k]) + Math.abs(px[i + 1] - px[k + 1]) + Math.abs(px[i + 2] - px[k + 2]);
      if (gold(px[i], px[i + 1], px[i + 2]) || apart > 30) bad++; // not plain: a line or an edge is near
    }
    if (bad <= (y1 - y0 + 1) * 0.1) sx = c;
  }
  if (sx < 0) throw new Error(`stack-book${n}: no plain spine column`);
  // cover it, a pixel more each way for the block's own edge; the dark outline of the book stays
  // the separator and the block's bevel reach past the cream, so the cover goes the whole height of the spine, but never over the outline
  for (let y = 0; y < h; y++) for (let x = sx + 1; x <= x1 + 1; x++) {
    const from = at(img, sx, y), to = at(img, x, y);
    if (px[to + 3] < 100 || px[from + 3] < 200) continue;
    if (px[from] + px[from + 1] + px[from + 2] < 100) continue; // the outline (a very dark cover is still lighter than it)
    px[to] = px[from]; px[to + 1] = px[from + 1]; px[to + 2] = px[from + 2]; px[to + 3] = px[from + 3];
  }
  const file = path.join(out, `stack-book${n}.png`);
  write(img, file);

  // the top face: the cover from above, in this book's colour (lighter, as a top face catches the light), a thin gold border inside
  const mid = at(img, Math.floor(w * 0.3), Math.floor(h * 0.5));
  const lift = c => Math.min(255, Math.round(c * 1.22 + 14));
  const fill = `rgb(${lift(px[mid])},${lift(px[mid + 1])},${lift(px[mid + 2])})`;
  // foreshortened: the far edge is a little shorter than the near one, as a face seen from slightly above is
  const inset = 11, near = TOP - 2, far = 2;
  magick("-size", `${w}x${TOP}`, "xc:none", "-fill", fill, "-stroke", "#1c1c1c", "-strokewidth", "3", "-strokewidth", "3",
    "-draw", `polygon 4,${near} ${w - 5},${near} ${w - 5 - inset},${far} ${4 + inset},${far}`,
    "-fill", "none", "-stroke", "#d9b560", "-strokewidth", "1",
    "-draw", `line ${4 + inset + 8},${Math.round((near + far) / 2)} ${w - 5 - inset - 8},${Math.round((near + far) / 2)}`,
    path.join(out, `stack-top${n}.png`));

  // the bottom book gets the rounded foot (the same warp as the other pieces' feet): taller below, middle of the base dropped
  if (n === 0) {
    let yb = -1;
    for (let y = h - 1; y >= 0 && yb < 0; y--) for (let x = 0; x < w; x++) if (px[at(img, x, y) + 3] > 200) { yb = y; break; }
    const cx = w / 2, hw = w / 2 + 2, Y0 = yb - FOOT_BAND;
    const expr = `yy=(j<${Y0})?j:${Y0}+(j-${Y0})*(${h}-${Y0})/(${h}-${Y0}+${FOOT}*max(0,1-((i-${cx})/${hw})^2)); u.p{i,yy}`;
    magick(file, "-background", "none", "-gravity", "north", "-extent", `${w}x${h + FOOT_EXT}`, "+gravity", "-alpha", "set", "-channel", "RGBA", "-fx", expr, file);
  }
  console.log(`stack-book${n}: page block x ${x0}-${x1}, y ${y0}-${y1}, spine column ${sx}`);
}
