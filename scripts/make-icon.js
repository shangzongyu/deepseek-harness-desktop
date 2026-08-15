// Renders the DSH favicon into a proper macOS app icon:
// white glyph on a DeepSeek-blue rounded square, 1024x1024.
// Usage: node scripts/make-icon.js   (requires: npm i sharp in this dir)
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'app-icon/favicon.svg');
const OUT = path.join(ROOT, 'app-icon/icon-1024.png');
const BLUE = '#4D6BFE';
const SIZE = 1024;
const GLYPH = 700; // glyph box size
const RADIUS = 228; // macOS icon corner radius ~ 22%

(async () => {
  let svg = fs.readFileSync(SRC, 'utf8');
  svg = svg.replace('fill="#000"', 'fill="#fff"');
  const glyph = await sharp(Buffer.from(svg)).resize(GLYPH, GLYPH).png().toBuffer();

  const bg = Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}">` +
      `<rect width="${SIZE}" height="${SIZE}" rx="${RADIUS}" fill="${BLUE}"/></svg>`
  );

  const pad = Math.floor((SIZE - GLYPH) / 2);
  await sharp(bg)
    .composite([{ input: glyph, left: pad, top: pad }])
    .png()
    .toFile(OUT);
  const meta = await sharp(OUT).metadata();
  console.log('icon written:', meta.width + 'x' + meta.height, OUT);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
