# Integration workflows

This repository's workflows cover uploads, registration, the action's unit
tests, and branch-aware selector integration. The branch smoke workflow runs
the checked-out action against the labeled definitions in `.autosana/`, including
their suite setup hook.

Explicit `flow-ids` and `suite-ids` payloads remain covered by the Bats suite.
New branch-only definitions are exercised by label because they do not have a
stable UUID before their first mainline sync.
