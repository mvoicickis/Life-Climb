#!/usr/bin/env python3
"""Rebuild mountain-stages mockup: 130% world, downward open stacks, honest collisions."""

from __future__ import annotations

import re
import sys
from pathlib import Path

HTML_PATH = Path(__file__).resolve().parents[1] / "docs" / "mockups" / "mountain-stages.html"

TENT_OPEN = (
    '<svg class="lp-trail-camp__tent-svg" viewBox="0 0 56 44" aria-hidden="true">'
    '<path class="lp-tent-side" d="M34 44 L56 44 L44 6 Z"/>'
    '<path class="lp-tent-front" d="M0 44 L34 44 L28 6 Z"/>'
    '<path class="lp-tent-door" d="M12 44 L12 30 L20 30 L20 44 Z"/>'
    "</svg>"
)
TENT_FOG = (
    '<svg class="lp-trail-camp__tent-svg lp-trail-camp__tent-svg--fog" viewBox="0 0 56 44" aria-hidden="true">'
    '<path class="lp-tent-side" d="M34 44 L56 44 L44 6 Z"/>'
    '<path class="lp-tent-front" d="M0 44 L34 44 L28 6 Z"/>'
    '<path class="lp-tent-door" d="M12 44 L12 30 L20 30 L20 44 Z"/>'
    "</svg>"
)

TENT_SVG_OLD = re.compile(
    r'<svg class="lp-trail-camp__tent-svg"[^>]*>.*?</svg>',
    re.DOTALL,
)
LETTER = re.compile(r'\s*<span class="lp-trail-camp__letter">[^<]*</span>')
CLIP_PEG = re.compile(
    r'<span class="lp-trail-camp__peg">\s*<span class="lp-trail-camp__tent"></span>\s*</span>',
)
STANDALONE_DONE = re.compile(
    r'\s*<p class="lp-trail-done-badge lp-frost"[^>]*>([^<]*)</p>\s*',
)
OPEN_LABEL = re.compile(r'\s*<p class="lp-trail-stage__label lp-frost">([^<]*)</p>\s*')
META_BLOCK = re.compile(
    r'\s*<div class="lp-trail-stage__meta">\s*.*?\s*</div>\s*',
    re.DOTALL,
)


def frame_audit_name(label_id: str) -> str | None:
    mapping = {
        "f1-label": "Frame 1",
        "f2-label": "Frame 2",
        "f3-label": "Frame 3",
        "f4-label": "Frame 4",
        "f5-label": "Frame 5",
        "f6-label": "Frame 6",
        "m1-label": "M1",
        "m2-label": "M2",
    }
    return mapping.get(label_id)


def meta_html(label: str, done: str | None) -> str:
    parts = [f'<p class="lp-trail-stage__label lp-frost">{label}</p>']
    if done:
        parts.append(f'<p class="lp-trail-done-badge lp-frost">{done}</p>')
    inner = "\n                        ".join(parts)
    return (
        '\n                      <div class="lp-trail-stage__meta">\n'
        f"                        {inner}\n"
        "                      </div>"
    )


def insert_before_closing_div(block: str, open_tag: str, insert: str) -> str:
    start = block.find(open_tag)
    if start == -1:
        return block
    i = block.find(">", start) + 1
    depth = 1
    while i < len(block) and depth > 0:
        if block.startswith("<div", i):
            depth += 1
            i += 4
            continue
        if block.startswith("</div>", i):
            depth -= 1
            if depth == 0:
                return block[:i] + insert + "\n                    " + block[i:]
            i += 6
            continue
        i += 1
    return block


def fix_open_stage_block(block: str, done_text: str | None) -> str:
    block = META_BLOCK.sub("\n", block, count=1)
    label_m = OPEN_LABEL.search(block)
    if not label_m:
        return block
    label = label_m.group(1).strip()
    block = OPEN_LABEL.sub("\n", block, count=1)
    meta = meta_html(label, done_text)
    return insert_before_closing_div(block, '<div class="lp-trail-stage__floor">', meta)


def replace_tents(html: str) -> str:
    html = LETTER.sub("", html)
    html = TENT_SVG_OLD.sub(TENT_OPEN, html)
    html = CLIP_PEG.sub(lambda _m: f'<span class="lp-trail-camp__peg">{TENT_OPEN}</span>', html)

    def fog_stage_repl(m: re.Match[str]) -> str:
        body = m.group(1)
        body = re.sub(
            r'(<span class="lp-trail-camp__peg">).*?(</span>)',
            lambda peg: peg.group(1) + TENT_FOG + peg.group(2),
            body,
            flags=re.DOTALL,
        )
        return m.group(0).replace(body, body) if body != m.group(1) else m.group(0)

    html = re.sub(
        r'(<div class="lp-trail-stage is-fog"[^>]*>)(.*?)(</div>\s*</div>)',
        lambda m: m.group(1) + re.sub(
            r'(<span class="lp-trail-camp__peg">).*?(</span>)',
            lambda peg: peg.group(1) + TENT_FOG + peg.group(2),
            m.group(2),
            flags=re.DOTALL,
        ) + m.group(3),
        html,
        flags=re.DOTALL,
    )
    return html


def fix_nav(html: str) -> str:
    html = html.replace("is-prev is-disabled", "is-prev is-hidden")
    html = re.sub(
        r'(<div class="lp-trail-stage is-open[^"]*has-nav-both[^"]*"[^>]*>.*?'
        r'<button type="button" class="lp-trail-stage__nav is-prev) is-hidden"',
        r"\1",
        html,
        flags=re.DOTALL,
    )

    def add_prev(m: re.Match[str]) -> str:
        row = m.group(0)
        if "is-prev" in row:
            return row
        return row.replace(
            '<div class="lp-trail-stage__row">',
            '<div class="lp-trail-stage__row">\n'
            '                        <button type="button" class="lp-trail-stage__nav is-prev is-hidden" aria-label="Previous camps">‹</button>',
            1,
        )

    html = re.sub(
        r'(<div class="lp-trail-stage is-open is-carousel[^"]*"[^>]*>.*?<div class="lp-trail-stage__row">.*?</div>)',
        add_prev,
        html,
        flags=re.DOTALL,
    )
    return html


def wrap_world(html: str) -> str:
    html = re.sub(
        r'(<div class="lp-trail__map lp-trail__map--anchors">)(.*?)(</div>\s*</div>\s*</section>)',
        lambda m: f'{m.group(1)}<div class="lp-trail__world">{m.group(2)}</div>{m.group(3)}'
        if "lp-trail__world" not in m.group(2)
        else m.group(0),
        html,
        count=1,
        flags=re.DOTALL,
    )
    html = re.sub(
        r'(<div class="lp-trail__map">)(.*?)(</div>\s*\n\s*</div>\s*\n\s*<div class="lp-trail__dock")',
        lambda m: f'{m.group(1)}<div class="lp-trail__world">{m.group(2)}</div>{m.group(3)}'
        if "lp-trail__world" not in m.group(2)
        else m.group(0),
        html,
        flags=re.DOTALL,
    )
    return html


def iter_open_stage_blocks(html: str) -> list[tuple[int, int]]:
    spans: list[tuple[int, int]] = []
    pos = 0
    needle = '<div class="lp-trail-stage is-open'
    while True:
        idx = html.find(needle, pos)
        if idx == -1:
            break
        start = idx
        depth = 0
        i = start
        end = start
        while i < len(html):
            if html.startswith("<div", i):
                depth += 1
                i += 4
                continue
            if html.startswith("</div>", i):
                depth -= 1
                i += 6
                if depth == 0:
                    end = i
                    break
                continue
            i += 1
        spans.append((start, end))
        pos = end
    return spans


def trail_section_for(html: str, index: int) -> str:
    trail_start = html.rfind('<section class="lp-trail', 0, index)
    if trail_start == -1:
        return ""
    trail_end = html.find("</section>", index)
    return html[trail_start:trail_end] if trail_end != -1 else ""


def restructure_open_stages(html: str) -> str:
    done_queue: list[str] = []

    def collect_done(m: re.Match[str]) -> str:
        done_queue.append(m.group(1).strip())
        return "\n"

    html = STANDALONE_DONE.sub(collect_done, html)

    spans = iter_open_stage_blocks(html)
    parts: list[str] = []
    cursor = 0
    done_idx = 0
    for start, end in spans:
        parts.append(html[cursor:start])
        block = html[start:end]
        section = trail_section_for(html, start)
        if "is-new-user" in section:
            done = None
        else:
            done = done_queue[done_idx] if done_idx < len(done_queue) else None
            done_idx += 1
        parts.append(fix_open_stage_block(block, done))
        cursor = end
    parts.append(html[cursor:])
    return "".join(parts)


def fix_frame_audit_attrs(html: str) -> str:
    def section_repl(m: re.Match[str]) -> str:
        block = m.group(0)
        label_id = m.group(1)
        audit = frame_audit_name(label_id)
        if not audit:
            return block
        if "data-frame-audit=" in block:
            return re.sub(
                r'data-frame-audit="[^"]*"',
                f'data-frame-audit="{audit}"',
                block,
                count=1,
            )
        return block.replace(
            '<div class="phone phone--map"',
            f'<div class="phone phone--map" data-frame-audit="{audit}"',
            1,
        )

    return re.sub(
        r'<section class="frame-block" aria-labelledby="([^"]+)">.*?</section>',
        section_repl,
        html,
        flags=re.DOTALL,
    )


SVG_DEFS = """
  <svg xmlns="http://www.w3.org/2000/svg" style="position:absolute;width:0;height:0;overflow:hidden" aria-hidden="true">
    <symbol id="lp-tent-aframe" viewBox="0 0 56 44">
      <path class="lp-tent-side" d="M34 44 L56 44 L44 6 Z"/>
      <path class="lp-tent-front" d="M0 44 L34 44 L28 6 Z"/>
      <path class="lp-tent-door" d="M12 44 L12 30 L20 30 L20 44 Z"/>
    </symbol>
  </svg>
"""

LAYOUT_CSS = """
    /* —— 130% zoom world + downward terrace stacks —— */
    :root {
      --map-zoom: 1.3;
      --map-world-y: -15%;
      --lp-goal-y: 11%;
      --lp-tent-open-w: 56px;
      --lp-tent-open-h: 44px;
      --lp-tent-fog-w: 40px;
      --lp-tent-fog-h: 32px;
      --lp-camp-name-min: 112px;
      --lp-camp-name-max: 140px;
      --lp-meta-gap: 8px;
      --lp-fog-opacity: 0.4;
    }

    .lp-trail__map {
      overflow: hidden;
    }

    .lp-trail__world {
      position: absolute;
      left: 50%;
      top: 0;
      width: calc(100% * var(--map-zoom));
      transform: translateX(-50%) translateY(var(--map-world-y));
      transform-origin: top center;
    }

    .lp-trail__world .lp-trail__photo {
      width: 100%;
      height: auto;
      display: block;
    }

    .lp-trail__stages,
    .lp-trail__goal,
    .lp-trail__anchor-layer,
    .lp-trail__map--anchors .terrace-anchor {
      /* positions are % of world box */
    }

    .lp-trail__map--anchors .lp-trail__world {
      position: relative;
      left: 50%;
      transform: translateX(-50%) translateY(var(--map-world-y));
    }

    .lp-trail-stage {
      left: 50%;
      width: calc(100% / var(--map-zoom) - (2 * var(--map-safe)));
      transform: translateX(-50%);
      align-items: center;
    }

    .lp-trail-stage__floor {
      flex-direction: column;
      align-items: center;
      gap: 0;
    }

    /* Open terrace: tent feet on dot row, names + meta stack downward */
    .lp-trail-stage.is-open .lp-trail-stage__floor {
      align-items: center;
      transform: translateY(calc(-1 * var(--lp-tent-open-h)));
    }

    .lp-trail-stage.is-open .lp-trail-stage__row,
    .lp-trail-stage.is-open:not(.is-carousel) .lp-trail-stage__camps {
      width: 100%;
    }

    .lp-trail-stage.is-open .lp-trail-stage__row {
      align-items: flex-start;
    }

    .lp-trail-stage__meta {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: var(--lp-meta-gap);
      margin-top: var(--lp-meta-gap);
      flex-wrap: wrap;
    }

    .lp-trail-done-badge {
      position: static;
      left: auto;
      top: auto;
      transform: none;
      opacity: 1;
    }

    .lp-trail.is-new-user .lp-trail-stage__meta .lp-trail-done-badge {
      display: none;
    }

    /* Fog terraces: label 6px above tent tops, feet on dot row */
    .lp-trail-stage.is-fog .lp-trail-stage__floor {
      flex-direction: column-reverse;
      align-items: center;
      gap: 6px;
      transform: translateY(calc(-1 * var(--lp-tent-fog-h)));
    }

    .lp-trail-stage.is-fog::after {
      display: none;
    }

    .lp-trail-stage.is-fog .lp-trail-stage__camps {
      filter: none;
      opacity: 1;
      padding-inline: 0;
      gap: 6px;
    }

    .lp-trail-stage.is-fog .lp-trail-camp {
      opacity: var(--lp-fog-opacity);
    }

    .lp-trail-stage__cloud {
      left: 50%;
      top: var(--lp-stage-y);
      transform: translate(-50%, -100%);
    }

    /* Tents — A-frame symbol */
    .lp-trail-camp__tent {
      display: none;
    }

    .lp-trail-camp__peg {
      width: var(--lp-tent-open-w);
      height: var(--lp-tent-open-h);
    }

    .lp-trail-stage.is-fog .lp-trail-camp__peg {
      width: var(--lp-tent-fog-w);
      height: var(--lp-tent-fog-h);
    }

    .lp-trail-camp__tent-svg {
      width: 100%;
      height: 100%;
      display: block;
      filter: drop-shadow(0 2px 4px rgba(15, 23, 42, 0.2));
    }

    .lp-trail-camp__peg svg .lp-tent-front {
      fill: var(--lp-trail-accent, #0f9488);
    }

    .lp-trail-camp__peg svg .lp-tent-side {
      fill: color-mix(in srgb, var(--lp-trail-accent, #0f9488) 55%, #000000);
    }

    .lp-trail-camp__peg svg .lp-tent-door {
      fill: color-mix(in srgb, var(--lp-trail-accent, #0f9488) 62%, #ffffff);
    }

    .lp-trail-camp__letter {
      display: none;
    }

    .lp-trail-camp__caption {
      margin-top: var(--lp-gap-tent-name);
      min-width: var(--lp-camp-name-min);
      max-width: var(--lp-camp-name-max);
      width: max-content;
    }

    .lp-trail-stage.is-open .lp-trail-camp__caption {
      min-height: var(--lp-pill-h);
      padding: 0 0.45rem;
    }

    .lp-trail-camp__title {
      overflow-wrap: normal;
      word-break: normal;
      hyphens: none;
      text-overflow: clip;
      display: -webkit-box;
      -webkit-box-orient: vertical;
      -webkit-line-clamp: 2;
      line-clamp: 2;
      overflow: hidden;
    }

    .lp-trail-stage__nav {
      top: calc(var(--lp-tent-open-h) / 2);
      bottom: auto;
      transform: translateY(-50%);
    }

    .lp-trail-stage__nav.is-hidden {
      display: none;
    }

    .lp-trail-stage.is-carousel .lp-trail-stage__row .lp-trail-stage__camps {
      margin-left: calc(var(--lp-tap) + var(--lp-frame-nav-inset));
      margin-right: calc(var(--lp-tap) + var(--lp-frame-nav-inset));
    }

    .lp-trail-stage__label,
    .lp-trail-done-badge {
      height: var(--lp-pill-h);
      min-height: var(--lp-pill-h);
      padding: 0 0.55rem;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      white-space: nowrap;
      background: var(--lp-frost);
      border: 1px solid var(--lp-border);
      border-radius: var(--lp-radius-pill);
      font-size: 0.62rem;
      font-weight: 700;
      backdrop-filter: blur(10px);
      -webkit-backdrop-filter: blur(10px);
      box-shadow: 0 2px 8px rgba(15, 23, 42, 0.06);
    }

    .lp-trail-camp.is-current .lp-trail-camp__peg::after {
      content: "";
      position: absolute;
      left: 50%;
      bottom: -4px;
      width: 2.75rem;
      height: 1rem;
      transform: translateX(-50%);
      background: radial-gradient(ellipse at center, var(--lp-green-soft) 0%, transparent 72%);
      pointer-events: none;
      z-index: -1;
    }

    .lp-trail-camp.is-current .lp-trail-camp__caption {
      border: 2px solid var(--lp-green);
      font-weight: 800;
      box-shadow: 0 0 12px var(--lp-green-soft);
    }

    .lp-trail-camp.is-current .lp-trail-camp__title {
      font-weight: 800;
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

COLLISION_SCRIPT = r"""
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

      function isVisible(el, trail) {
        if (!el || !el.getClientRects().length) return false;
        var style = window.getComputedStyle(el);
        if (style.display === 'none' || style.visibility === 'hidden') return false;
        if (parseFloat(style.opacity) === 0) return false;
        if (el.classList.contains('is-hidden')) return false;
        if (el.closest('[hidden]')) return false;
        if (el.closest('.lp-trail-stage') && parseFloat(window.getComputedStyle(el.closest('.lp-trail-stage')).opacity) < 0.5) return false;
        var sheet = trail.querySelector('.lp-trail-sheet:not([hidden])');
        if (sheet) {
          var panel = sheet.querySelector('.lp-trail-sheet__panel');
          if (panel) {
            var pr = panel.getBoundingClientRect();
            var r = el.getBoundingClientRect();
            if (r.top >= pr.top - TOLERANCE) return false;
          }
        }
        return true;
      }

      function isTruncated(el) {
        if (!el) return false;
        if (el.scrollWidth > el.clientWidth + 1) return true;
        if (el.scrollHeight > el.clientHeight + 1) return true;
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

      function collectTargets(trail) {
        var selectors = [
          '.lp-trail-camp__peg',
          '.lp-trail-camp__caption',
          '.lp-trail-stage__label',
          '.lp-trail-done-badge',
          '.lp-trail-stage__cloud',
          '.lp-trail-stage__nav:not(.is-hidden)',
          '.lp-trail-hud__pill',
          '.lp-trail-arrange',
          '.lp-trail__goal-plaque',
          '.lp-trail-base-fire',
          '.lp-trail-today'
        ];
        var nodes = [];
        selectors.forEach(function (sel) {
          trail.querySelectorAll(sel).forEach(function (el) {
            if (isVisible(el, trail)) nodes.push(el);
          });
        });
        return nodes;
      }

      function shareCamp(a, b) {
        var campA = a.closest('.lp-trail-camp');
        var campB = b.closest('.lp-trail-camp');
        return campA && campA === campB;
      }

      function auditTrail(trail, map) {
        clearOutlines(map);
        var collisions = 0;
        var targets = collectTargets(trail);
        var rects = targets.map(function (el) {
          return { el: el, rect: el.getBoundingClientRect() };
        });

        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            if (shareCamp(rects[i].el, rects[j].el)) continue;
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

        trail.querySelectorAll('.lp-trail-camp__title').forEach(function (title) {
          if (!isVisible(title, trail)) return;
          if (isTruncated(title)) {
            collisions++;
            addOutline(map, title.getBoundingClientRect());
            title.style.outline = '2px solid #ef4444';
            title.setAttribute('data-collision-highlight', '1');
          }
        });

        return collisions;
      }

      function runCollisionAudit() {
        var lines = [];
        var total = 0;
        document.querySelectorAll('.phone--map[data-frame-audit]').forEach(function (phone) {
          var name = phone.getAttribute('data-frame-audit');
          var trail = phone.querySelector('.lp-trail');
          var map = phone.querySelector('.lp-trail__map');
          if (!trail || !map) return;
          var count = auditTrail(trail, map);
          total += count;
          lines.push(name + ': ' + count);
        });
        var banner = document.getElementById('collision-report');
        if (banner) {
          banner.textContent = lines.join(' · ') || '0 collisions';
          banner.classList.toggle('has-collisions', total > 0);
        }
      }

      window.addEventListener('load', runCollisionAudit);
      window.addEventListener('resize', runCollisionAudit);
      runCollisionAudit();
    })();
"""


def inject_css(html: str) -> str:
    marker = "    /* —— Centred terrace stacks"
    if marker in html:
        start = html.index(marker)
        end = html.index("    .frame-section-label {", start)
        html = html[:start] + LAYOUT_CSS + "\n" + html[end:]

    html = html.replace(
        "      --lp-camp-name-min: 120px;\n",
        "      --lp-camp-name-min: 112px;\n",
    )
    html = html.replace(
        "      transform: translateY(calc(-1 * var(--lp-camp-foot)));\n    }\n\n    /* Done badge",
        "      transform: none;\n    }\n\n    /* Done badge",
    )
    return html


def inject_defs(html: str) -> str:
    if 'id="lp-tent-aframe"' not in html:
        html = html.replace("<body>", "<body>" + SVG_DEFS, 1)
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
    html = inject_defs(html)
    html = replace_tents(html)
    html = restructure_open_stages(html)
    html = fix_nav(html)
    html = wrap_world(html)
    html = fix_frame_audit_attrs(html)
    html = inject_css(html)
    html = replace_script(html)
    return html


def main() -> int:
    if not HTML_PATH.is_file():
        print(f"Missing {HTML_PATH}", file=sys.stderr)
        return 1
    html = HTML_PATH.read_text(encoding="utf-8")
    HTML_PATH.write_text(transform(html), encoding="utf-8")
    print(f"Rebuilt {HTML_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
