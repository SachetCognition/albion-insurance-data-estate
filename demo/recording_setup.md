# Recording setup — making every take identical

The take is captured with an **external screen recorder** (Loom, OBS, or
QuickTime). Nothing in the demo runs a live agent; the Agent-mode segment
replays an already-completed session, and validation runs on seeded local
data, so a clean take is reproducible on demand.

## Canonical Segment 3 source (pre-run session)

> https://partner-workshops.devinenterprise.com/sessions/a54e56721eb54a2fbcab7457cb5de42d?tab=information%3Aevent-01a036c3485276d18bbc21be5fd5a136

This session already executed the full plan (Session 0 foundation → parallel
Sessions A–D → PRs #8–#12 → 216/216 integrated Snowflake build). Scroll its
timeline live on camera; never start a fresh agent run during a take.

## Pre-stage these browser tabs (in on-screen order)

1. **DeepWiki** page for `SachetCognition/albion-insurance-data-estate`
   (architecture/overview section already scrolled into view).
2. **Ask Devin** for this repo (fresh conversation, input box empty).
3. **The pre-run session URL above** (logged in, timeline loaded, scrolled to
   the top / initial prompt).

## Terminal pre-stage (Segment 4, Option A)

```bash
cd <repo-root>
pip install -r transform/requirements.txt   # once per machine
./demo/run_validation.sh                    # dry-run BEFORE recording
```

The script is idempotent and rebuilds the DuckDB file from scratch each run,
so output is identical on every take. Keep the terminal font large (14pt+)
and the window sized so the final `PASS=… ERROR=0` summary fits on screen.

## Determinism rules

- Always use the same seeded data (`transform/seeds/` — committed to git);
  never point the build at live or mutated data for a take.
- Run `./demo/run_validation.sh` once *before* recording so `dbt deps` and
  package downloads are warm — the on-camera run then has no network pauses.
- Paste prompts verbatim from `prompts.md`; do not free-type.
- Use the default `duckdb` target on camera (zero credentials, no
  network variance). The `-t snowflake` variant is for off-camera parity
  evidence only.

## Pre-take checklist

- [ ] All three tabs open, in order, logged in where needed.
- [ ] Ask Devin conversation is fresh (no prior messages visible).
- [ ] Pre-run session tab loaded and scrolled to the initial prompt.
- [ ] `prompts.md` open in a side window/clipboard manager for pasting.
- [ ] Terminal at repo root; `./demo/run_validation.sh` dry-run completed
      green within the last hour.
- [ ] Notifications / do-not-disturb enabled; bookmarks bar hidden.
- [ ] Recorder set to capture the full screen at ≥1080p; mic checked.
- [ ] Timer visible to the presenter (target 2:20, hard cap 3:00).
