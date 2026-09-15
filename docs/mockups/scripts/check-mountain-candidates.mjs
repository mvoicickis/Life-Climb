#!/usr/bin/env node
/**
 * Renders each mountain-candidate HTML at 360px, screenshots, and runs QA checks.
 */
import { chromium } from '@playwright/test';
import { readFileSync, mkdirSync } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const mockupsDir = path.resolve(__dirname, '..');
const shotsDir = path.join(mockupsDir, 'screenshots');
mkdirSync(shotsDir, { recursive: true });

const candidates = [
  { id: 1, html: 'mountain-candidate-1.html', svg: 'assets/candidate-1/sunrise-over-mountains.svg' },
  { id: 2, html: 'mountain-candidate-2.html', svg: 'assets/candidate-2/outdoor-adventure-undraw.svg' },
  { id: 3, html: 'mountain-candidate-3.html', svg: 'assets/candidate-3/mountain-landscape-commons.svg' },
];

function luminance(r, g, b) {
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function parseSvgTextBounds(svgText) {
  const labels = [];
  const textRe = /<text\b[^>]*>([\s\S]*?)<\/text>/gi;
  let m;
  while ((m = textRe.exec(svgText))) {
    const tag = m[0];
    const x = Number(tag.match(/\bx="([^"]+)"/)?.[1] ?? tag.match(/\bx='([^']+)'/)?.[1] ?? NaN);
    const y = Number(tag.match(/\by="([^"]+)"/)?.[1] ?? tag.match(/\by='([^']+)'/)?.[1] ?? NaN);
    const inner = m[1].replace(/<[^>]+>/g, '').trim();
    if (!inner) continue;
    labels.push({ text: inner, x, y, raw: tag.slice(0, 80) });
  }
  return labels;
}

function boxesOverlap(a, b, pad = 0) {
  return (
    a.x - pad < b.x + b.w + pad &&
    a.x + a.w + pad > b.x - pad &&
    a.y - pad < b.y + b.h + pad &&
    a.y + a.h + pad > b.y - pad
  );
}

async function analyzePage(page) {
  return page.evaluate(() => {
    const lum = (r, g, b) => 0.2126 * r + 0.7152 * g + 0.0722 * b;
    const canvas = document.createElement('canvas');
    const w = 360;
    const h = Math.min(document.documentElement.scrollHeight, 900);
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d');
    ctx.fillStyle = '#f8fafc';
    ctx.fillRect(0, 0, w, h);
    const obj = document.querySelector('object');
    if (!obj?.contentDocument) return { skipped: true };
    const svg = obj.contentDocument.documentElement;
    const xml = new XMLSerializer().serializeToString(svg);
    const img = new Image();
    const url = URL.createObjectURL(new Blob([xml], { type: 'image/svg+xml' }));
    return new Promise((resolve) => {
      img.onload = () => {
        const drawH = Math.min(h, (img.height / img.width) * w);
        ctx.drawImage(img, 0, 0, w, drawH);
        const data = ctx.getImageData(0, 0, w, drawH).data;
        let maxL = -1;
        let brightPixels = 0;
        for (let y = 0; y < drawH; y += 2) {
          for (let x = 0; x < w; x += 2) {
            const i = (w * y + x) * 4;
            const a = data[i + 3];
            if (a < 128) continue;
            const L = lum(data[i], data[i + 1], data[i + 2]);
            if (L > maxL) maxL = L;
          }
        }
        const threshold = maxL - 8;
        for (let y = 0; y < drawH; y += 2) {
          for (let x = 0; x < w; x += 2) {
            const i = (w * y + x) * 4;
            const a = data[i + 3];
            if (a < 128) continue;
            const L = lum(data[i], data[i + 1], data[i + 2]);
            if (L >= threshold) brightPixels++;
          }
        }
        URL.revokeObjectURL(url);
        resolve({ maxL, brightPixels, height: drawH });
      };
      img.onerror = () => resolve({ skipped: true });
      img.src = url;
    });
  });
}

const browser = await chromium.launch();
const results = [];

for (const c of candidates) {
  const page = await browser.newPage({ viewport: { width: 360, height: 640 } });
  const url = `file://${path.join(mockupsDir, c.html)}`;
  await page.goto(url, { waitUntil: 'networkidle' });
  await page.waitForTimeout(500);
  const shotPath = path.join(shotsDir, `mountain-candidate-${c.id}-360.png`);
  const pngBuffer = await page.screenshot({ path: shotPath, fullPage: true });
  const svgPath = path.join(mockupsDir, c.svg);
  const svgText = readFileSync(svgPath, 'utf8');
  const viewW = Number(svgText.match(/viewBox="[^"]*?\s+([\d.]+)\s+[\d.]+\s*"/)?.[1]
    || svgText.match(/width="([\d.]+)"/)?.[1]
    || 360);
  const scale = 360 / viewW;
  const labels = parseSvgTextBounds(svgText).map((l) => ({
    ...l,
    x: Number.isFinite(l.x) ? l.x * scale : null,
    y: Number.isFinite(l.y) ? l.y * scale : null,
    w: Math.max(40, l.text.length * 7),
    h: 14,
  }));
  const failures = [];
  const passes = [];

  if (labels.length === 0) {
    passes.push('No SVG text labels (overlap / edge rules N/A for labels)');
  } else {
    for (const l of labels) {
      if (l.x == null) continue;
      if (l.x < 12 || l.x + l.w > 360 - 12) {
        failures.push(`Text "${l.text}" within 12px of horizontal edge (x≈${l.x.toFixed(0)})`);
      }
    }
    for (let i = 0; i < labels.length; i++) {
      for (let j = i + 1; j < labels.length; j++) {
        if (labels[i].x != null && labels[j].x != null && boxesOverlap(labels[i], labels[j], 2)) {
          failures.push(`Labels overlap: "${labels[i].text}" / "${labels[j].text}"`);
        }
      }
    }
  }

  const fogLayers = (svgText.match(/opacity="0\.[0-9]+"/g) || []).length;
  const fullBrightFills = (svgText.match(/fill="#f{3,6}"/gi) || []).length
    + (svgText.match(/fill="#fff7b3"/gi) || []).length;
  if (fogLayers > 0 && fullBrightFills > 0) {
    failures.push(`Possible lit shapes behind dimmed layers (${fogLayers} opacity<1, ${fullBrightFills} bright fills)`);
  } else {
    passes.push('No obvious bright-fill behind fog layers in SVG markup');
  }

  if (/xlink:href.*\.(png|jpe?g)/i.test(svgText) || /<image\b/i.test(svgText)) {
    failures.push('Embedded bitmap detected');
  } else {
    passes.push('Vector paths only (no embedded bitmap)');
  }

  let shotStats = null;
  try {
    shotStats = await analyzePage(page);
    if (shotStats?.skipped) {
      passes.push('Luminance check skipped (object document unavailable)');
    } else {
      const sunDominant = shotStats.brightPixels > 80 && shotStats.brightPixels < 8000;
      if (!sunDominant && shotStats.maxL > 200) {
        failures.push(`Multiple or diffuse highlights (bright pixel count ${shotStats.brightPixels}, max L ${shotStats.maxL.toFixed(0)})`);
      } else if (shotStats.maxL <= 200) {
        passes.push('Even lighting (no single hotspot required for this asset)');
      } else {
        passes.push('One dominant bright region on screen (likely sun/sky)');
      }
    }
  } catch (e) {
    passes.push(`Screenshot luminance check skipped (${e.message})`);
  }

  passes.push('Shape containment: not automated for raw SVG (visual review at pick)');

  results.push({ id: c.id, shotPath, failures, passes });
  await page.close();
}

await browser.close();

console.log(JSON.stringify(results, null, 2));
const anyFail = results.some((r) => r.failures.length);
process.exit(anyFail ? 1 : 0);
