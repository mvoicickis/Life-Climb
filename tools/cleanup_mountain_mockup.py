#!/usr/bin/env python3
"""Clean up mountain-stages.html: light brand, centred symmetry, no fox, no glass frames."""

from __future__ import annotations

import re
import sys
from pathlib import Path

HTML_PATH = Path(__file__).resolve().parents[1] / "docs" / "mockups" / "mountain-stages.html"

TENT_SVG = (
    '<svg class="lp-trail-camp__tent-svg" viewBox="0 0 48 64" aria-hidden="true">'
    '<path d="M6 58 L24 8 L42 58 Z" fill="color-mix(in srgb, var(--lp-trail-accent, #0f9488) 55%, #0a1a14)"/>'
    '<path d="M24 8 L42 58 L24 58 Z" fill="color-mix(in srgb, var(--lp-trail-accent, #0f9488) 78%, #1a2e28)"/>'
    '<path d="M6 58 L24 8 L24 58 Z" fill="color-mix(in srgb, var(--lp-trail-accent, #0f9488) 88%, #ffffff)"/>'
    '<circle cx="24" cy="9" r="4.5" fill="color-mix(in srgb, var(--lp-trail-accent, #0f9488) 70%, #ffffff)"/>'
    '<ellipse cx="24" cy="50" rx="7" ry="5" fill="rgba(255,255,255,0.28)"/>'
    "</svg>"
)

PEG_CLIP = re.compile(
    r'<span class="lp-trail-camp__peg">\s*<span class="lp-trail-camp__tent"></span>\s*</span>',
    re.DOTALL,
)

LABEL_DIV = re.compile(
    r'<div class="lp-trail-stage__label">'
    r'<svg class="lp-trail-stage__label-icon"[^>]*>.*?</svg>'
    r'<span class="lp-trail-stage__label-copy">'
    r'<span class="lp-trail-stage__label-title">([^<]*)</span>'
    r'<span class="lp-trail-stage__label-meta">([^<]*)</span>'
    r"</span></div>",
    re.DOTALL,
)

COMPANION = re.compile(
    r'\s*<div class="lp-trail__companion"[^>]*>.*?</div>\s*',
    re.DOTALL,
)

TODAY_BADGE = re.compile(
    r'\s*<span class="lp-trail-today__badge"[^>]*>.*?</span>\s*',
    re.DOTALL,
)

FRAME_0B = re.compile(
    r"\n\s*<!-- Frame 0b.*?<!-- Frame 1",
    re.DOTALL,
)

FRAME_L = re.compile(
    r"\n\s*<!-- Frame L.*?<!-- Frame 3",
    re.DOTALL,
)

GLASS_CSS = re.compile(
    r"\n\s*/\* —— Dark glass trail reference.*?\.lp-trail\.is-glass \.lp-trail-stage__dot\.is-active \{[^}]+\}\n",
    re.DOTALL,
)

COMPANION_CSS = re.compile(
    r"\n\s*/\* Fox beside current camp.*?\.lp-trail__companion-img \{[^}]+\}\n",
    re.DOTALL,
)


def tent_peg(letter: str = "") -> str:
    letter_html = f'<span class="lp-trail-camp__letter">{letter[0].upper()}</span>' if letter else ""
    return f'<span class="lp-trail-camp__peg">{TENT_SVG}{letter_html}</span>'


def extract_letter(camp_html: str) -> str:
    m = re.search(r'aria-label="([^"]*)"', camp_html)
    if m:
        return m.group(1)
    m = re.search(r'<span class="lp-trail-camp__title">([^<]*)</span>', camp_html)
    if m:
        return re.sub(r"&amp;", "&", m.group(1))
    m = re.search(r'<span class="lp-trail-camp__letter">([^<]*)</span>', camp_html)
    return m.group(1) if m else "?"


def one_line_label(title: str, meta: str) -> str:
    meta = meta.strip()
    title = title.strip()
    if meta.startswith("open now"):
        text = f"{title} · open now"
    elif meta:
        text = f"{title} · {meta}"
    else:
        text = title
    return f'<p class="lp-trail-stage__label lp-frost">{text}</p>'


def replace_clip_tents(html: str) -> str:
    def repl(match: re.Match[str]) -> str:
        # Walk backwards in surrounding context for aria-label / title
        start = max(0, match.start() - 400)
        ctx = html[start : match.end()]
        letter = extract_letter(ctx)
        return tent_peg(letter)

    return PEG_CLIP.sub(repl, html)


def normalize_labels(html: str) -> str:
    return LABEL_DIV.sub(lambda m: one_line_label(m.group(1), m.group(2)), html)


def ensure_carousel_nav(html: str) -> str:
    """Both ‹ › on carousel rows; page-1 frames fade prev."""

    def fix_row(row_html: str, fade_prev: bool) -> str:
        if "is-prev" not in row_html:
            row_html = row_html.replace(
                '<div class="lp-trail-stage__row">',
                '<div class="lp-trail-stage__row">\n'
                '                        <button type="button" class="lp-trail-stage__nav is-prev'
                + (" is-disabled" if fade_prev else "")
                + '" aria-label="Previous camps">‹</button>',
                1,
            )
        elif fade_prev and "is-prev is-disabled" not in row_html and 'class="lp-trail-stage__nav is-prev"' in row_html:
            row_html = row_html.replace(
                'class="lp-trail-stage__nav is-prev"',
                'class="lp-trail-stage__nav is-prev is-disabled"',
            )
        if "is-next" not in row_html:
            row_html = row_html.replace(
                "</div>\n                      </div>",
                '                        <button type="button" class="lp-trail-stage__nav is-next" aria-label="Next camps">›</button>\n                      </div>\n                      </div>',
                1,
            )
        return row_html

    stage_pattern = re.compile(
        r'(<div class="lp-trail-stage is-open is-carousel[^"]*"[^>]*>.*?<div class="lp-trail-stage__row">.*?</div>\s*</div>)',
        re.DOTALL,
    )

    def repl(m: re.Match[str]) -> str:
        block = m.group(1)
        fade_prev = "m2-label" not in html[max(0, m.start() - 800) : m.start()] and "has-nav-both" not in block
        if "has-nav-both" in block:
            fade_prev = False
        row_m = re.search(r'(<div class="lp-trail-stage__row">.*?</div>\s*)(?=\s*</div>\s*<div class="lp-trail-stage__dots")', block, re.DOTALL)
        if not row_m:
            return block
        new_row = fix_row(row_m.group(1), fade_prev)
        return block[: row_m.start(1)] + new_row + block[row_m.end(1) :]

    return stage_pattern.sub(repl, html)


def restructure_open_floors(html: str) -> str:
    """Move label above row/camps stack (column layout)."""

    # Carousel / row layout: label left of row -> label above row
    pattern = re.compile(
        r'(<div class="lp-trail-stage__floor">\s*)'
        r'(<p class="lp-trail-stage__label lp-frost">[^<]*</p>\s*)'
        r'(<div class="lp-trail-stage__label">.*?</div>\s*)?'
        r'(<div class="lp-trail-stage__row">)',
        re.DOTALL,
    )

    def repl(m: re.Match[str]) -> str:
        label = m.group(2) or m.group(3) or ""
        if m.group(3) and not m.group(2):
            label = m.group(3)
        return m.group(1) + label + m.group(4)

    html = pattern.sub(repl, html)

    # Non-carousel open: label beside camps -> label above camps
    pattern2 = re.compile(
        r'(<div class="lp-trail-stage is-open(?![^"]*is-carousel)[^"]*"[^>]*>\s*<div class="lp-trail-stage__floor">\s*)'
        r'(<p class="lp-trail-stage__label lp-frost">[^<]*</p>\s*)'
        r'(<div class="lp-trail-stage__label">.*?</div>\s*)?'
        r'(<div class="lp-trail-stage__camps">)',
        re.DOTALL,
    )

    def repl2(m: re.Match[str]) -> str:
        label = m.group(2) or m.group(3) or ""
        return m.group(1) + label + m.group(4)

    html = pattern2.sub(repl2, html)

    # Fog: label beside camps -> label above camps
    pattern3 = re.compile(
        r'(<div class="lp-trail-stage is-fog[^"]*"[^>]*>\s*<div class="lp-trail-stage__floor">\s*)'
        r'(<p class="lp-trail-stage__label lp-frost">[^<]*</p>\s*)'
        r'(<div class="lp-trail-stage__label">.*?</div>\s*)?'
        r'(<div class="lp-trail-stage__camps">)',
        re.DOTALL,
    )

    return pattern3.sub(repl2, html)


COLLISION_SCRIPT = """
    (function () {
      var TOLERANCE = 2;

      function rectsOverlap(a, b) {
        return !(
          a.right <= b.left + TOLERANCE ||
          a.left >= b.right - TOLERANCE ||
          a.bottom <= b.top + TOLERANCE ||
          a.top >= b.bottom - TOLERANCE
        );
      }

      function isTruncated(el) {
        if (!el || el.matches('.lp-trail-stage__label')) return false;
        if (el.scrollWidth > el.clientWidth + 1) return true;
        var style = window.getComputedStyle(el);
        return style.textOverflow === 'ellipsis' && style.overflow === 'hidden';
      }

      function clearOutlines(map) {
        map.querySelectorAll('.collision-outline').forEach(function (n) { n.remove(); });
        map.querySelectorAll('[data-collision-highlight]').forEach(function (el) {
          el.style.outline = '';
          el.removeAttribute('data-collision-highlight');
        });
      }

      function addOutline(map, rect) {
        var box = document.createElement('div');
        box.className = 'collision-outline';
        var mapRect = map.getBoundingClientRect();
        box.style.left = (rect.left - mapRect.left) + 'px';
        box.style.top = (rect.top - mapRect.top) + 'px';
        box.style.width = rect.width + 'px';
        box.style.height = rect.height + 'px';
        map.appendChild(box);
      }

      function collectTargets(map) {
        var selectors = [
          '.lp-trail-camp__caption',
          '.lp-trail-camp__peg',
          '.lp-trail-stage__nav',
          '.lp-trail-done-badge',
          '.lp-trail-stage__label',
          '.lp-trail__goal-plaque'
        ];
        var nodes = [];
        selectors.forEach(function (sel) {
          map.querySelectorAll(sel).forEach(function (el) {
            if (el.offsetParent !== null || el.getClientRects().length) {
              nodes.push(el);
            }
          });
        });
        return nodes;
      }

      function shareCamp(a, b) {
        var campA = a.closest('.lp-trail-camp');
        var campB = b.closest('.lp-trail-camp');
        return campA && campA === campB;
      }

      function shareStageFloor(a, b) {
        var floorA = a.closest('.lp-trail-stage__floor');
        var floorB = b.closest('.lp-trail-stage__floor');
        return floorA && floorA === floorB;
      }

      function shareStageRow(a, b) {
        var rowA = a.closest('.lp-trail-stage__row');
        var rowB = b.closest('.lp-trail-stage__row');
        return rowA && rowA === rowB;
      }

      function shouldSkipPair(a, b) {
        if (shareCamp(a, b)) return true;
        if (shareStageFloor(a, b)) {
          if (a.matches('.lp-trail-stage__label') || b.matches('.lp-trail-stage__label')) return true;
          if (a.matches('.lp-trail-camp__peg') && b.matches('.lp-trail-camp__caption')) return true;
          if (b.matches('.lp-trail-camp__peg') && a.matches('.lp-trail-camp__caption')) return true;
        }
        if (shareStageRow(a, b) && (a.matches('.lp-trail-stage__nav') || b.matches('.lp-trail-stage__nav'))) {
          return true;
        }
        return false;
      }

      function auditMap(map) {
        clearOutlines(map);
        var collisions = 0;
        var targets = collectTargets(map);
        var rects = targets.map(function (el) {
          return { el: el, rect: el.getBoundingClientRect() };
        });

        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            if (shouldSkipPair(rects[i].el, rects[j].el)) continue;
            if (rectsOverlap(rects[i].rect, rects[j].rect)) {
              collisions++;
              addOutline(map, rects[i].rect);
              addOutline(map, rects[j].rect);
              rects[i].el.style.outline = '2px solid #ef4444';
              rects[i].el.setAttribute('data-collision-highlight', '1');
              rects[j].el.style.outline = '2px solid #ef4444';
              rects[j].el.setAttribute('data-collision-highlight', '1');
            }
          }
        }

        targets.forEach(function (el) {
          var textEls = el.matches('.lp-trail-camp__caption, .lp-trail__goal-plaque')
            ? [el, el.querySelector('.lp-trail-camp__title')]
            : [];
          textEls.forEach(function (t) {
            if (t && isTruncated(t)) {
              collisions++;
              var r = t.getBoundingClientRect();
              addOutline(map, r);
              t.style.outline = '2px solid #ef4444';
              t.setAttribute('data-collision-highlight', '1');
            }
          });
        });

        return collisions;
      }

      function runCollisionAudit() {
        var total = 0;
        document.querySelectorAll('.phone--map .lp-trail__map').forEach(function (map) {
          if (map.classList.contains('lp-trail__map--anchors')) return;
          total += auditMap(map);
        });
        var banner = document.getElementById('collision-report');
        if (banner) {
          banner.textContent = total + ' collision' + (total === 1 ? '' : 's');
          banner.classList.toggle('has-collisions', total > 0);
        }
      }

      window.addEventListener('load', runCollisionAudit);
      window.addEventListener('resize', runCollisionAudit);
      runCollisionAudit();
    })();
"""


def patch_css(html: str) -> str:
    html = GLASS_CSS.sub("\n", html)
    html = COMPANION_CSS.sub("\n", html)

    html = html.replace(" is-glass", "")

    html = html.replace(
        "        <li><strong>3+ camps</strong> — 2 visible, ‹ › arrows (44px), dots under the ledge (one per camp); always opens on the next camp (fox + green outline); bottom battle card stays fixed while paging</li>",
        "        <li><strong>3+ camps</strong> — 2 visible, ‹ › arrows (44px), dots under the ledge (one per camp); current camp = green outline name pill; bottom battle card stays fixed while paging</li>",
    )
    html = html.replace(
        "        <li><strong>Terrace order</strong> — bottom=open, second=fog, third=fog, top=cloud; done badge on stairs below bottom terrace; Frame 0b overlays dots on Frame 2</li>",
        "        <li><strong>Terrace order</strong> — bottom=open, second=fog, third=fog, top=cloud; done badge centred on stairs below bottom terrace</li>",
    )

    # :root tokens
    html = html.replace(
        "      --lp-green-deep: #3dbd48;\n",
        "      --lp-green-deep: #3dbd48;\n      --lp-green-soft: rgba(87, 211, 91, 0.28);\n",
    )
    html = html.replace("      --lp-camp-foot: 44px;\n", "      --lp-camp-foot-open: 52px;\n      --lp-camp-foot-later: 36px;\n      --lp-camp-foot: var(--lp-camp-foot-open);\n")
    html = html.replace("      --lp-camp-name-min: 112px;\n", "      --lp-camp-name-min: 120px;\n      --lp-pill-h: 26px;\n      --lp-gap-pill-tent: 8px;\n      --lp-gap-tent-name: 6px;\n")

    # HUD light frosted
    html = html.replace(
        """    .lp-trail-hud__pill {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.4rem 0.6rem;
      border-radius: var(--lp-radius-pill);
      background: var(--lp-rpg-glass);
      border: 1px solid var(--lp-rpg-glass-border);
      backdrop-filter: blur(12px);
      -webkit-backdrop-filter: blur(12px);
      box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.08);
      color: var(--lp-rpg-ink);
    }""",
        """    .lp-trail-hud__pill {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.4rem 0.6rem;
      border-radius: var(--lp-radius-pill);
      background: var(--lp-frost);
      border: 1px solid var(--lp-border);
      backdrop-filter: blur(10px);
      -webkit-backdrop-filter: blur(10px);
      box-shadow: 0 2px 8px rgba(15, 23, 42, 0.06);
      color: var(--lp-ink);
    }""",
    )

    html = html.replace(
        """    .lp-trail-arrange {
      justify-self: start;
      margin-left: 0.3rem;
      border: 0;
      border-radius: var(--lp-radius-pill);
      background: rgba(18, 32, 26, 0.28);
      color: var(--lp-rpg-muted);
      font: inherit;
      font-size: 0.68rem;
      font-weight: 700;
      padding: 0.35rem 0.7rem;
      cursor: pointer;
      backdrop-filter: blur(8px);
      -webkit-backdrop-filter: blur(8px);
    }""",
        """    .lp-trail-arrange {
      justify-self: start;
      margin-left: 0.3rem;
      border: 1px solid var(--lp-border);
      border-radius: var(--lp-radius-pill);
      background: var(--lp-frost);
      color: var(--lp-muted);
      font: inherit;
      font-size: 0.68rem;
      font-weight: 700;
      padding: 0.35rem 0.7rem;
      cursor: pointer;
      backdrop-filter: blur(10px);
      -webkit-backdrop-filter: blur(10px);
      box-shadow: 0 2px 8px rgba(15, 23, 42, 0.06);
    }""",
    )

    html = html.replace(
        """    .lp-trail-hud__level {
      position: absolute;
      right: -0.15rem;
      bottom: -0.15rem;
      min-width: 1rem;
      height: 1rem;
      padding: 0 0.2rem;
      border-radius: var(--lp-radius-pill);
      background: var(--lp-green);
      color: #0f172a;
      font-size: 0.58rem;
      font-weight: 900;
      display: grid;
      place-items: center;
      border: 1.5px solid #fff;
    }""",
        """    .lp-trail-hud__level {
      position: absolute;
      right: -0.15rem;
      bottom: -0.15rem;
      min-width: 1rem;
      height: 1rem;
      padding: 0 0.2rem;
      border-radius: var(--lp-radius-pill);
      background: var(--lp-green);
      color: var(--lp-ink);
      font-size: 0.58rem;
      font-weight: 900;
      display: grid;
      place-items: center;
      border: 1.5px solid var(--lp-surface);
    }""",
    )

    stage_css = """
    /* —— Centred terrace stacks (Life Climb light) —— */
    .lp-trail-stage {
      left: 50%;
      width: calc(100% - (2 * var(--map-safe)));
      transform: translateX(-50%);
    }

    .lp-trail-stage.is-open.is-carousel {
      left: 50%;
      width: calc(100% - (2 * var(--map-safe)));
      transform: translateX(-50%);
    }

    .lp-trail-stage__floor {
      flex-direction: column;
      align-items: center;
      gap: var(--lp-gap-pill-tent);
      transform: translateY(calc(-1 * var(--lp-camp-foot)));
    }

    .lp-trail-stage.is-fog .lp-trail-stage__floor,
    .lp-trail-stage.is-later .lp-trail-stage__floor,
    .lp-trail-stage.is-done .lp-trail-stage__floor {
      --lp-camp-foot: var(--lp-camp-foot-later);
    }

    .lp-trail-stage.is-open .lp-trail-stage__floor {
      --lp-camp-foot: var(--lp-camp-foot-open);
    }

    .lp-trail-stage__label {
      align-self: center;
      height: var(--lp-pill-h);
      min-height: var(--lp-pill-h);
      padding: 0 0.55rem;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      font-size: 0.62rem;
      font-weight: 700;
      white-space: nowrap;
      background: var(--lp-frost);
      backdrop-filter: blur(10px);
      -webkit-backdrop-filter: blur(10px);
      box-shadow: 0 2px 8px rgba(15, 23, 42, 0.06);
    }

    .lp-trail-stage.is-open:not(.is-carousel) .lp-trail-stage__label,
    .lp-trail-stage.is-fog .lp-trail-stage__label,
    .lp-trail-stage.is-open.is-carousel .lp-trail-stage__label {
      position: relative;
      left: auto;
      bottom: auto;
      margin: 0;
    }

    .lp-trail-stage.is-open:not(.is-carousel) .lp-trail-stage__floor,
    .lp-trail-stage.is-fog .lp-trail-stage__floor {
      flex-direction: column;
      align-items: center;
    }

    .lp-trail-stage.is-open:not(.is-carousel) .lp-trail-stage__label {
      margin-right: 0;
    }

    .lp-trail-stage.is-fog .lp-trail-stage__label {
      margin-right: 0;
    }

    .lp-trail-stage__row {
      width: 100%;
      align-items: flex-end;
    }

    .lp-trail-stage__nav {
      bottom: calc(var(--lp-camp-foot-open) - var(--lp-tap));
    }

    .lp-trail-stage__nav.is-disabled {
      opacity: 0.35;
      pointer-events: none;
    }

    .lp-trail-stage.is-carousel .lp-trail-stage__row .lp-trail-stage__camps {
      margin-left: calc(var(--lp-tap) + var(--lp-frame-nav-inset));
      margin-right: calc(var(--lp-tap) + var(--lp-frame-nav-inset));
    }

    .lp-trail-stage__cloud {
      left: 50%;
      transform: translate(-50%, -100%);
    }

    .lp-trail-done-badge {
      height: var(--lp-pill-h);
      min-height: var(--lp-pill-h);
      padding: 0 0.55rem;
      display: inline-flex;
      align-items: center;
      background: var(--lp-frost);
      backdrop-filter: blur(10px);
      -webkit-backdrop-filter: blur(10px);
    }

    .lp-trail-camp__peg {
      width: var(--lp-camp-foot);
      height: var(--lp-camp-foot);
    }

    .lp-trail-camp__tent {
      display: none;
    }

    .lp-trail-camp__tent-svg {
      width: var(--lp-camp-foot);
      height: var(--lp-camp-foot);
      display: block;
      filter: drop-shadow(0 2px 4px rgba(15, 23, 42, 0.18));
    }

    .lp-trail-camp__letter {
      position: absolute;
      left: 50%;
      top: 38%;
      transform: translate(-50%, -50%);
      font-size: 0.62rem;
      font-weight: 900;
      color: #ffffff;
      text-shadow: 0 1px 2px rgba(15, 23, 42, 0.35);
      pointer-events: none;
      z-index: 2;
    }

    .lp-trail-camp__caption {
      margin-top: var(--lp-gap-tent-name);
    }

    .lp-trail-stage.is-open .lp-trail-camp__caption {
      min-height: var(--lp-pill-h);
      padding: 0 0.45rem;
      display: inline-flex;
      align-items: center;
      justify-content: center;
    }

    .lp-trail-camp.is-current .lp-trail-camp__peg::after {
      content: "";
      position: absolute;
      left: 50%;
      bottom: -4px;
      width: 2.4rem;
      height: 1rem;
      transform: translateX(-50%);
      background: radial-gradient(ellipse at center, var(--lp-green-soft) 0%, transparent 72%);
      pointer-events: none;
      z-index: -1;
    }

    .lp-trail-camp.is-current .lp-trail-camp__caption {
      border: 2px solid var(--lp-green);
      box-shadow: 0 0 12px var(--lp-green-soft);
    }

    .lp-trail-camp.is-current.is-name-hidden .lp-trail-camp__caption {
      display: inline-flex;
    }

    .lp-trail-camp.is-current.is-name-hidden .lp-trail-camp__peg {
      box-shadow: none;
      border-radius: 0;
    }

    .lp-trail-stage.is-fog .lp-trail-stage__camps {
      gap: 6px;
      padding-inline: 0;
    }

    .lp-trail-stage.is-fog .lp-trail-camp {
      min-width: 0;
      max-width: none;
      flex: 0 0 auto;
    }

    #collision-report {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      z-index: 9999;
      padding: 0.45rem 1rem;
      font-size: 0.78rem;
      font-weight: 800;
      text-align: center;
      background: rgba(15, 23, 42, 0.92);
      color: #ffffff;
      border-bottom: 2px solid transparent;
    }

    #collision-report.has-collisions {
      background: rgba(127, 29, 29, 0.95);
      border-bottom-color: #ef4444;
    }

    .collision-outline {
      position: absolute;
      border: 2px solid #ef4444;
      background: rgba(239, 68, 68, 0.12);
      pointer-events: none;
      z-index: 100;
      box-sizing: border-box;
    }
"""

    marker = "    .frame-section-label {"
    if "Centred terrace stacks" not in html:
        html = html.replace(marker, stage_css + "\n" + marker, 1)

    # Remove duplicate collision-report if glass block had it
    html = re.sub(r"(#collision-report \{[^}]+\}\s*)+", "", html, count=0)
    if '#collision-report' not in html.split('</style>')[0]:
        html = html.replace("  </style>", stage_css.split("#collision-report")[0] + "\n  </style>", 1)

    return html


def replace_script(html: str) -> str:
    return re.sub(
        r"<script>.*?</script>",
        f"<script>{COLLISION_SCRIPT}\n  </script>",
        html,
        count=1,
        flags=re.DOTALL,
    )


def transform(html: str) -> str:
    html = FRAME_0B.sub("\n\n      <!-- Frame 1", html)
    html = FRAME_L.sub("\n\n      <!-- Frame 3", html)
    html = COMPANION.sub("\n", html)
    html = TODAY_BADGE.sub("\n", html)
    html = normalize_labels(html)
    html = replace_clip_tents(html)
    html = restructure_open_floors(html)
    html = ensure_carousel_nav(html)
    html = patch_css(html)
    html = replace_script(html)
    return html


def main() -> int:
    if not HTML_PATH.is_file():
        print(f"Error: {HTML_PATH} not found", file=sys.stderr)
        return 1
    source = HTML_PATH.read_text(encoding="utf-8")
    result = transform(source)
    HTML_PATH.write_text(result, encoding="utf-8")
    print(f"Cleaned {HTML_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
