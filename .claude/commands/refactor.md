---
description: Safely refactor inside Game.gd without fighting its intentional shape
---

Game.gd is one deliberately-consolidated 23k-line file (see AUDIT_2026-07-26.md's P3 finding and
CLAUDE.md's header) - the size and lack of scene/autoload structure are a chosen tradeoff, not
neglect. Ground rules before refactoring anything inside it:

1. **Don't split the file or extract classes/autoloads without asking first.** The project's own
   audit explicitly recommends an *incremental* direction only (pure data/config tables, save
   schema/migration, geometry/calibration helpers as tested scripts) and explicitly says not to
   split rendering or gameplay "merely for style until the seam has tests." Treat any full
   decomposition as a design decision for Louis to make, not a cleanup to just do.
2. **Preserve grouping-by-system, not by declaration type.** Consts/vars/funcs are organized by
   game system (throw model, shop, tailor, ...) throughout, and `.gdlintrc` deliberately disables
   `class-definitions-order` for exactly this reason. Moving a function to "the right place by
   type" is moving it to the wrong place here.
3. **Never run a DOTALL regex (`re.S`) to cut a range out of this file.** It has already deleted
   16,099 lines once by matching from the first anchor to the *last* occurrence of the end
   string in the whole file. Cut with two explicit `str.index()` anchors that fail loudly, or
   with an editor's own diff/patch application - never a greedy multiline regex.
4. **Preserve hand-aligned trailing comments.** Don't run `scripts/format.sh --write` (gdformat)
   across a refactor - see that script's header for why it's diff-only by default.
5. **A shared value that's a compromise struck for one caller** (documented pattern: torches used
   to straighten their flame in rotation solely for the wordmark's leaning A) **should be revisited
   the moment that one caller is deleted** - check for orphaned compromises when removing a caller.
6. Run `scripts/validate.sh` after any refactor, not just `--check-only` - see that script's
   header for why the plain parse check has already missed a real error once.

Commit before any structural edit (per CLAUDE.md's own explicit rule after the regex incident) so
a mistake is one `git checkout` away from undone, not an hour of transcript archaeology.
