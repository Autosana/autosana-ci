# Integration workflows

This repository's workflows cover uploads, registration, and the action's unit
tests. Direct selector integration tests live in
[`Autosana/quick-ci-test`](https://github.com/Autosana/quick-ci-test) because the
calling repository must be connected to Autosana and own its code-managed flow
definitions. That fixture covers branch flow labels, suite labels, and the
two-minute `wait: false` regression guard.

Explicit `flow-ids` and `suite-ids` payloads remain covered by the Bats suite.
New branch-only definitions are exercised by label because they do not have a
stable UUID before their first mainline sync.
