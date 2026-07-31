## Milestone
- [ ] Single MVP Roadmap milestone ID (see `docs/ROADMAP.md`) — nothing else

## Product alignment
- [ ] Which screen owns this? (Responsibility Matrix in `docs/LEXICON.md`)
- [ ] Fits Screen Blueprint owner screen(s) only
- [ ] No new permanent screen / product area
- [ ] Player copy uses lexicon (Mountain, Destination, Mission, Battle, Today’s Battle Plan, Journey, You)
- [ ] Today changes respect One Battle Plan Law (one plan; multiple Battles OK; no inbox)
- [ ] Does not reopen anything in `docs/DECISIONS.md` Rejected (or updates DECISIONS.md if deliberately reversing)

## Engineering
- [ ] Follows `docs/ENGINEERING.md`
- [ ] Logic in services when non-trivial
- [ ] No schema change unless required and justified
- [ ] Stimulus only for UI behavior; Turbo Streams follow existing patterns
- [ ] CSS uses `--lp-*` / existing `.lp-*` where possible
- [ ] Locales updated for player-facing strings; dual-name hotspots fixed if this PR touches them (`docs/LEXICON.md`)

## Quality
- [ ] Tests cover acceptance criteria
- [ ] `bin/rails test` (relevant files) green locally
- [ ] RuboCop clean on touched files
- [ ] QA checklist from the milestone run (manual)
- [ ] Regression risks from the milestone reviewed

## PR hygiene
- [ ] Clear title: `M#: …`
- [ ] Description: goal, user value, test plan, screenshots if UI
- [ ] Branch: `cursor/<descriptive-name>-97b6`
