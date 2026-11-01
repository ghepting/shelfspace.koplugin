# ShelfSpace

A KOReader plugin in Lua. `tests/run.sh` runs the tests under plain `luajit`.

## Every pull request

- Before opening a pull request, check `README.md` against the change and update whatever it makes wrong: how a screen looks or behaves, what can be deleted, install or update steps, the file types, the device table, the development commands. If nothing in the README is affected, say so in the PR description.
- Do not describe something the app does not do. Read the code if unsure (for example, ShelfSpace never updates or checks for updates on its own).
- If the UI changed, the README screenshots may be out of date; say in the PR whether they were retaken (`tools/screenshots/run.sh <KOReader.app> --readme`).
- The PR title is a conventional commit (`feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`); pull requests are squash-merged.

## Wording

- Say "select" and "selected", never "tick" (in the README, the app and PR text).
