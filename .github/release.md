# Release maintenance

`Release` is the sole automated LSP tag publisher. Its serialized writer first
publishes merged normal Release Please releases, verifies/reconciles the current
master boundary, checks that master has not advanced, then generates release PRs
through the pinned `release-please@17.6.0` public API. Generation constructs one
Manifest, validates its retained root version and the observed tag SHA against the
checkout, retains that tag observation, and requires history to reach the boundary.
Conflicting release objects or missing/truncated history fail before PR writes.
Manual dispatch must select `master`; other branches and forks cannot run the writer.

Require the **Validate LSP release PR** check and **Require branches to be up to
date before merging** in master protection. This change does not configure those
settings. The check validates same-repository updater PRs against freshly fetched
master using master's trusted helper; other PRs skip it. Base advancement requires
updating/rebasing the updater branch and a new check. A stale patch allocation must
be regenerated, not bypassed. For bot-created PRs, inspect Actions and **approve
pending workflow runs first** when GitHub requests approval. If the required check
has no run, explicitly reopen the PR as a maintainer to request validation. Never
bypass a pending required check.

## Recovery

- If master advances during release publication, dispatch `Release` on `master`
  again. The next run checks the latest snapshot; there is no sleep/retry loop.
- If GitHub's tag API has not yet exposed a just-pushed tag, rerun after it is
  visible. Reconciliation verifies existing tags and never moves them.
- If provenance, ancestry, or a version boundary fails validation, investigate the
  failing commit/PR and restore a valid published boundary through the normal
  reviewed release process. Do not force tags or bypass the check.
- On rollout, inspect existing release/updater PRs created under the old ordering.
  Close/recreate stale proposals after a successful boundary reconciliation.

The generation baseline is fixed to the verified version/tag observation, not to a
globally frozen latest head. Newer commits may still be analyzed, but history before
the boundary cannot be replayed. There is no atomic PR-write/latest-head lock; the
outer master check is only a freshness best effort. Required up-to-date checks
protect updater merges; a failed/stale run is recovered by rerun.

The adapter deliberately supports only the current single-root `simple` config,
default stable `vX.Y.Z` tags, and canonical stable release names (`vX.Y.Z` or
`X.Y.Z`). Config changes and noncanonical release names fail closed and require
reviewing the guards. Tooling is installed with npm `--ignore-scripts` into runner
temporary storage; no plugin runtime dependency or repository package files are
added. Rerun the Node native tests when updating the pinned library.

Workflow changes must be merged before these protections are live.
