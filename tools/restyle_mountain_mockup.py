#!/usr/bin/env python3
"""Restyle mountain-stages.html mockup with dark glass frames and collision detection."""

from __future__ import annotations

import re
import sys
from pathlib import Path

HTML_PATH = Path(__file__).resolve().parents[1] / "docs" / "mockups" / "mountain-stages.html"

GLASS_FRAME_LABELS = {"f1-label", "f2-label", "f3-label", "f5-label", "m1-label"}

MOUNTAIN_ICON_SVG = (
    '<svg class="lp-trail-stage__label-icon" viewBox="0 0 16 16" width="14" height="14" '
    'aria-hidden="true"><path fill="currentColor" d="M2 13h12L10 6 7 10 5 7 2 13zm0-11 3 5 3-4 3 3 5-8H2z"/></svg>'
)

GLASS_CSS = """
    /* —— Dark glass trail reference (.lp-trail.is-glass) —— */
    .lp-trail.is-glass {
      --lp-glass-bg: rgba(10, 36, 40, 0.75);
      --lp-glass-border: rgba(255, 255, 255, 0.14);
      --lp-glass-blur: 12px;
      --lp-tent-h: 64px;
      --lp-camp-foot-glass: 64px;
      --lp-camp-foot: var(--lp-camp-foot-glass);
      --lp-rpg-ink: #ffffff;
      --lp-rpg-muted: rgba(255, 255, 255, 0.78);
      color: #ffffff;
    }

    .lp-trail.is-glass .lp-trail-hud__pill,
    .lp-trail.is-glass .lp-trail-arrange,
    .lp-trail.is-glass .lp-trail__goal-plaque,
    .lp-trail.is-glass .lp-trail-stage__label,
    .lp-trail.is-glass .lp-trail-stage__cloud,
    .lp-trail.is-glass .lp-trail-stage__nav,
    .lp-trail.is-glass .lp-trail-done-badge,
    .lp-trail.is-glass .lp-trail-base-fire,
    .lp-trail.is-glass .lp-trail-today {
      background: var(--lp-glass-bg);
      border-color: var(--lp-glass-border);
      backdrop-filter: blur(var(--lp-glass-blur));
      -webkit-backdrop-filter: blur(var(--lp-glass-blur));
      color: #ffffff;
      box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.08), 0 4px 16px rgba(0, 0, 0, 0.18);
    }

    .lp-trail.is-glass .lp-trail-arrange {
      background: color-mix(in srgb, var(--lp-glass-bg) 82%, transparent);
    }

    .lp-trail.is-glass .lp-trail__dock {
      background: transparent;
      border-top-color: var(--lp-glass-border);
    }

    .lp-trail.is-glass .lp-trail-today__headline,
    .lp-trail.is-glass .lp-trail-today__sub,
    .lp-trail.is-glass .lp-trail__goal-title,
    .lp-trail.is-glass .lp-trail__goal-tagline {
      color: #ffffff;
    }

    .lp-trail.is-glass .lp-trail-today__sub {
      color: var(--lp-rpg-muted);
    }

    .lp-trail.is-glass .lp-trail-today__tick::before {
      border-color: rgba(255, 255, 255, 0.35);
      background: color-mix(in srgb, var(--lp-glass-bg) 70%, transparent);
    }

    .lp-trail.is-glass .lp-trail-today__badge {
      flex-shrink: 0;
      width: 2rem;
      height: 2rem;
      min-width: 2rem;
      border-radius: 50%;
      display: grid;
      place-items: center;
      font-size: 0.82rem;
      font-weight: 900;
      color: #ffffff;
      background: var(--lp-badge-color, var(--lp-trail-accent, #0f9488));
      border: 2px solid rgba(255, 255, 255, 0.22);
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
    }

    /* Summit soft golden glow */
    .lp-trail.is-glass .lp-trail__map::before {
      content: "";
      position: absolute;
      left: calc(var(--lp-goal-x) - 18%);
      top: calc(var(--lp-goal-y) - 6%);
      width: 42%;
      height: 28%;
      transform: translate(-10%, -20%);
      background: radial-gradient(ellipse at center, rgba(255, 210, 120, 0.42) 0%, rgba(255, 180, 80, 0.12) 42%, transparent 72%);
      pointer-events: none;
      z-index: 2;
    }

    /* Stage pill — two-line label with mountain icon */
    .lp-trail.is-glass .lp-trail-stage__label {
      display: flex;
      align-items: center;
      gap: 0.4rem;
      padding: 0.35rem 0.65rem;
      border-radius: var(--lp-radius-pill);
      white-space: normal;
      text-align: left;
      max-width: calc(100% - (2 * var(--map-safe)));
    }

    .lp-trail.is-glass .lp-trail-stage__label-icon {
      flex-shrink: 0;
      opacity: 0.9;
    }

    .lp-trail.is-glass .lp-trail-stage__label-copy {
      display: grid;
      gap: 1px;
      min-width: 0;
    }

    .lp-trail.is-glass .lp-trail-stage__label-title {
      font-size: 0.62rem;
      font-weight: 800;
      line-height: 1.15;
    }

    .lp-trail.is-glass .lp-trail-stage__label-meta {
      font-size: 0.52rem;
      font-weight: 600;
      line-height: 1.15;
      color: var(--lp-rpg-muted);
    }

    .lp-trail.is-glass .lp-trail-stage.is-open.is-carousel .lp-trail-stage__label {
      left: 50%;
      transform: translateX(-50%);
      bottom: calc(100% + 0.35rem);
    }

    /* Later / fog stages — muted, no blur overlay */
    .lp-trail.is-glass .lp-trail-stage.is-fog,
    .lp-trail.is-glass .lp-trail-stage.is-later {
      opacity: 0.6;
      filter: saturate(0.6);
    }

    .lp-trail.is-glass .lp-trail-stage.is-fog::after {
      display: none;
    }

    .lp-trail.is-glass .lp-trail-stage.is-fog .lp-trail-camp__tent,
    .lp-trail.is-glass .lp-trail-stage.is-fog .lp-trail-camp__tent-svg {
      opacity: 1;
      filter: none;
    }

    /* Fog terrace — up to 4 tents, tight gap, no names */
    .lp-trail.is-glass .lp-trail-stage.is-fog .lp-trail-stage__camps {
      gap: 4px;
      max-width: 100%;
    }

    .lp-trail.is-glass .lp-trail-stage.is-fog .lp-trail-camp {
      min-width: 0;
      max-width: none;
      flex: 0 0 auto;
    }

    /* Open terrace — max 2 camps with name pills */
    .lp-trail.is-glass .lp-trail-stage.is-open .lp-trail-stage__camps {
      gap: var(--lp-camp-pair-gap);
    }

    .lp-trail.is-glass .lp-trail-stage.is-open .lp-trail-camp__caption {
      background: var(--lp-glass-bg);
      border: 1px solid var(--lp-glass-border);
      backdrop-filter: blur(var(--lp-glass-blur));
      -webkit-backdrop-filter: blur(var(--lp-glass-blur));
      color: #ffffff;
      max-height: calc(2 * 1.2em);
      overflow: hidden;
    }

    .lp-trail.is-glass .lp-trail-stage.is-open .lp-trail-camp__title {
      color: #ffffff;
      text-shadow: none;
    }

    .lp-trail.is-glass .lp-trail-stage.is-fog .lp-trail-camp__caption,
    .lp-trail.is-glass .lp-trail-stage.is-cloud .lp-trail-camp__caption {
      display: none;
    }

    .lp-trail.is-glass .lp-trail-camp.is-current .lp-trail-camp__caption {
      border: 2px solid var(--lp-green);
      box-shadow: 0 0 0 1px rgba(87, 211, 91, 0.35);
    }

    .lp-trail.is-glass .lp-trail-camp.is-current.is-name-hidden .lp-trail-camp__caption {
      display: block;
    }

    .lp-trail.is-glass .lp-trail-camp.is-current.is-name-hidden .lp-trail-camp__peg {
      box-shadow: none;
      border-radius: 0;
    }

    /* Glossy SVG tents */
    .lp-trail.is-glass .lp-trail-camp__tent {
      display: none;
    }

    .lp-trail.is-glass .lp-trail-camp__peg {
      width: var(--lp-camp-foot-glass);
      height: var(--lp-camp-foot-glass);
    }

    .lp-trail.is-glass .lp-trail-camp__tent-svg {
      width: 36px;
      height: var(--lp-tent-h);
      display: block;
      filter: drop-shadow(0 3px 6px rgba(0, 0, 0, 0.35));
    }

    .lp-trail.is-glass .lp-trail-camp__letter {
      position: absolute;
      left: 50%;
      top: 38%;
      transform: translate(-50%, -50%);
      font-size: 0.72rem;
      font-weight: 900;
      color: #ffffff;
      text-shadow: 0 1px 3px rgba(0, 0, 0, 0.45);
      pointer-events: none;
      z-index: 2;
    }

    .lp-trail.is-glass .lp-trail-stage.is-open .lp-trail-camp.is-current .lp-trail-camp__tent-svg {
      width: 40px;
      animation: lp-trail-camp-pulse 2.4s ease-in-out infinite;
    }

    /* Nav arrows — dark glass circles at terrace edges */
    .lp-trail.is-glass .lp-trail-stage__nav {
      width: 44px;
      height: 44px;
      min-width: 44px;
      min-height: 44px;
      flex: 0 0 44px;
      font-size: 1.25rem;
    }

    .lp-trail.is-glass .lp-trail-stage__nav.is-prev {
      left: 0;
    }

    .lp-trail.is-glass .lp-trail-stage__nav.is-next {
      right: 0;
    }

    .lp-trail.is-glass .lp-trail-stage.is-carousel .lp-trail-stage__row .lp-trail-stage__camps {
      margin-left: 48px;
      margin-right: 48px;
    }

    /* Done badge — dark glass */
    .lp-trail.is-glass .lp-trail-done-badge {
      color: rgba(255, 255, 255, 0.88);
      opacity: 1;
    }

    /* Fox stays round on grass */
    .lp-trail.is-glass .lp-trail__companion {
      border-radius: 50%;
      overflow: hidden;
    }

    .lp-trail.is-glass .lp-trail-stage__dot {
      background: rgba(255, 255, 255, 0.28);
    }

    .lp-trail.is-glass .lp-trail-stage__dot.is-active {
      background: #ffffff;
    }

    /* Collision report banner */
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
          '.lp-trail__companion',
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

      function auditMap(map) {
        clearOutlines(map);
        var collisions = 0;
        var targets = collectTargets(map);
        var rects = targets.map(function (el) {
          return { el: el, rect: el.getBoundingClientRect() };
        });

        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
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
          var textEls = el.matches('.lp-trail-camp__caption, .lp-trail-stage__label, .lp-trail__goal-plaque')
            ? [el, el.querySelector('.lp-trail-camp__title'), el.querySelector('.lp-trail-stage__label-title')]
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


def tent_svg_block() -> str:
    """Inline glossy tent SVG using --lp-trail-accent CSS variable."""
    return (
        '<svg class="lp-trail-camp__tent-svg" viewBox="0 0 48 64" aria-hidden="true">'
        '<path d="M6 58 L24 8 L42 58 Z" fill="color-mix(in srgb, var(--lp-trail-accent, #0f9488) 55%, #0a1a14)"/>'
        '<path d="M24 8 L42 58 L24 58 Z" fill="color-mix(in srgb, var(--lp-trail-accent, #0f9488) 78%, #1a2e28)"/>'
        '<path d="M6 58 L24 8 L24 58 Z" fill="color-mix(in srgb, var(--lp-trail-accent, #0f9488) 88%, #ffffff)"/>'
        '<circle cx="24" cy="9" r="4.5" fill="color-mix(in srgb, var(--lp-trail-accent, #0f9488) 70%, #ffffff)"/>'
        '<ellipse cx="24" cy="50" rx="7" ry="5" fill="rgba(255,255,255,0.28)"/>'
        "</svg>"
    )


def tent_peg_html(letter: str) -> str:
    letter = (letter or "?")[0].upper()
    return (
        f'<span class="lp-trail-camp__peg">{tent_svg_block()}'
        f'<span class="lp-trail-camp__letter">{letter}</span></span>'
    )


def parse_stage_label(text: str) -> tuple[str, str]:
    text = re.sub(r"\s+", " ", text.strip())
    if "·" in text:
        parts = [p.strip() for p in text.split("·", 1)]
        return parts[0], parts[1]
    return text, ""


def stage_label_html(label_text: str) -> str:
    title, meta = parse_stage_label(label_text)
    return (
        f'<div class="lp-trail-stage__label">{MOUNTAIN_ICON_SVG}'
        f'<span class="lp-trail-stage__label-copy">'
        f'<span class="lp-trail-stage__label-title">{title}</span>'
        f'<span class="lp-trail-stage__label-meta">{meta}</span>'
        f"</span></div>"
    )


def extract_camp_name(camp_html: str) -> str:
    m = re.search(r'aria-label="([^"]*)"', camp_html)
    if m:
        return m.group(1)
    m = re.search(r'<span class="lp-trail-camp__title">([^<]*)</span>', camp_html)
    if m:
        return re.sub(r"&amp;", "&", m.group(1))
    m = re.search(r"\bis-(teal|coral|purple|amber|green|blue)\b", camp_html)
    if m:
        return m.group(1)
    return "?"


def extract_camp_color(camp_html: str) -> str:
    m = re.search(r"--lp-trail-accent:\s*([^;\"]+)", camp_html)
    return m.group(1).strip() if m else "#0f9488"


PEG_PATTERN = re.compile(
    r'<span class="lp-trail-camp__peg">\s*<span class="lp-trail-camp__tent"></span>\s*</span>',
    re.DOTALL,
)

BUTTON_CAMP_PATTERN = re.compile(
    r"<button\b[^>]*\bclass=\"[^\"]*\blp-trail-camp\b[^\"]*\"[^>]*>.*?</button>",
    re.DOTALL,
)

FOG_CAMP_PATTERN = re.compile(
    r'<span\b[^>]*\bclass="[^"]*\blp-trail-camp\b[^"]*"[^>]*>\s*<span class="lp-trail-camp__peg">.*?</span>\s*</span>',
    re.DOTALL,
)


def replace_tent_in_camp(camp_html: str) -> str:
    name = extract_camp_name(camp_html)
    return PEG_PATTERN.sub(tent_peg_html(name), camp_html)


def replace_all_tents(html: str) -> str:
    html = BUTTON_CAMP_PATTERN.sub(lambda m: replace_tent_in_camp(m.group(0)), html)
    html = FOG_CAMP_PATTERN.sub(lambda m: replace_tent_in_camp(m.group(0)), html)
    return html


def replace_stage_labels(html: str) -> str:
    pattern = re.compile(
        r'<p class="lp-trail-stage__label(?:\s+lp-frost)?">([^<]*)</p>',
        re.DOTALL,
    )
    return pattern.sub(lambda m: stage_label_html(m.group(1)), html)


def add_is_glass_to_trail(section_html: str) -> str:
    return re.sub(
        r'(<section class="lp-trail)(\s[^"]*)(")',
        lambda m: (
            f'{m.group(1)}{m.group(2)}{" is-glass" if "is-glass" not in m.group(2) else ""}{m.group(3)}'
        ),
        section_html,
        count=1,
    )


def transform_today_card(html: str) -> str:
    def replacer(match: re.Match[str]) -> str:
        block = match.group(0)
        if "lp-trail-today__badge" in block:
            return block
        sub_m = re.search(r'<span class="lp-trail-today__sub">(?:Next in\s+)?([^<]*)</span>', block)
        camp_name = sub_m.group(1).strip() if sub_m else "?"
        letter = camp_name[0].upper() if camp_name else "?"
        color = "#0f9488"
        current_m = re.search(
            r'class="[^"]*\blp-trail-camp\b[^"]*\bis-current\b[^"]*"[^>]*style="--lp-trail-accent:\s*([^;"]+)',
            html,
        )
        if not current_m:
            current_m = re.search(
                r'style="--lp-trail-accent:\s*([^;"]+)[^"]*"[^>]*class="[^"]*\blp-trail-camp\b[^"]*\bis-current\b',
                html,
            )
        if current_m:
            color = current_m.group(1).strip()
        badge = (
            f'<span class="lp-trail-today__badge" style="--lp-badge-color: {color};" '
            f'aria-hidden="true">{letter}</span>'
        )
        return block.replace(
            '<span class="lp-trail-today__copy">',
            badge + '\n                  <span class="lp-trail-today__copy">',
            1,
        )

    return re.sub(
        r'<button type="button" class="lp-trail-today[^"]*">.*?</button>',
        replacer,
        html,
        flags=re.DOTALL,
    )


def transform_lp_trail(lp_trail_html: str, frame_label: str) -> str:
    html = add_is_glass_to_trail(lp_trail_html)
    html = replace_stage_labels(html)
    html = replace_all_tents(html)

    if frame_label == "f1-label":
        html = html.replace("is-current is-name-hidden", "is-current")
        html = html.replace("is-name-hidden is-current", "is-current")

    html = transform_today_card(html)
    return html


def extract_frame_section(html: str, label_id: str) -> str | None:
    pattern = re.compile(
        rf'(<!--[^\n]*-->\s*)?<section class="frame-block" aria-labelledby="{label_id}">.*?</section>',
        re.DOTALL,
    )
    m = pattern.search(html)
    return m.group(0) if m else None


def make_frame_l(frame2_html: str) -> str:
    out = frame2_html
    out = re.sub(r"<!-- Frame 2[^>]*-->\s*", "", out, count=1)
    out = out.replace('id="f2-label"', 'id="fL-label"')
    out = out.replace('aria-labelledby="f2-label"', 'aria-labelledby="fL-label"')
    out = re.sub(
        r'<p class="frame-block__label" id="fL-label">Frame 2</p>',
        '<p class="frame-block__label" id="fL-label">Frame L</p>',
        out,
    )
    out = re.sub(
        r"<h2 class=\"frame-block__title\">[^<]*</h2>",
        '<h2 class="frame-block__title">Light style · Frame 2 comparison</h2>',
        out,
        count=1,
    )
    out = out.replace(" is-glass", "")
    return out


def transform_glass_frame_section(section_html: str, label_id: str) -> str:
    trail_pattern = re.compile(r"<section class=\"lp-trail[^\"]*\".*?</section>", re.DOTALL)
    m = trail_pattern.search(section_html)
    if not m:
        return section_html
    new_trail = transform_lp_trail(m.group(0), label_id)
    return section_html[: m.start()] + new_trail + section_html[m.end() :]


def insert_collision_banner(html: str) -> str:
    banner = '    <div id="collision-report" role="status">0 collisions</div>\n'
    if 'id="collision-report"' in html:
        return html
    return html.replace('  <div class="doc">\n', f'  <div class="doc">\n{banner}', 1)


def insert_glass_css(html: str) -> str:
    marker = "    /* —— Dark glass trail"
    if marker in html:
        return html
    return html.replace("  </style>", f"{GLASS_CSS}\n  </style>", 1)


def replace_script(html: str) -> str:
    return re.sub(
        r"<script>.*?</script>",
        f"<script>{COLLISION_SCRIPT}\n  </script>",
        html,
        count=1,
        flags=re.DOTALL,
    )


def insert_frame_after(html: str, after_label: str, frame_html: str) -> str:
    pattern = re.compile(
        rf'(<section class="frame-block" aria-labelledby="{after_label}">.*?</section>)',
        re.DOTALL,
    )
    m = pattern.search(html)
    if not m:
        raise RuntimeError(f"Could not find frame section for {after_label}")
    insert_at = m.end()
    comment = "\n\n      <!-- Frame L — Light style Frame 2 comparison -->\n      "
    frame_html = frame_html.lstrip()
    return html[:insert_at] + comment + frame_html + html[insert_at:]


def transform_html(html: str) -> str:
    frame2_original = extract_frame_section(html, "f2-label")
    if not frame2_original:
        raise RuntimeError("Frame 2 section not found")

    frame_l = make_frame_l(frame2_original)

    for label_id in GLASS_FRAME_LABELS:
        section = extract_frame_section(html, label_id)
        if not section:
            print(f"Warning: frame {label_id} not found", file=sys.stderr)
            continue
        transformed = transform_glass_frame_section(section, label_id)
        html = html.replace(section, transformed, 1)

    if 'aria-labelledby="fL-label"' not in html:
        html = insert_frame_after(html, "f2-label", frame_l)

    html = insert_glass_css(html)
    html = insert_collision_banner(html)
    html = replace_script(html)
    return html


def main() -> int:
    if not HTML_PATH.is_file():
        print(f"Error: {HTML_PATH} not found", file=sys.stderr)
        return 1

    source = HTML_PATH.read_text(encoding="utf-8")
    result = transform_html(source)
    HTML_PATH.write_text(result, encoding="utf-8")
    print(f"Transformed {HTML_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
