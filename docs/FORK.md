# Fork maintenance notes

This file lives on `buggerman/kaset` only. Do not upstream it.

## Branch model

| Branch | Role |
|---|---|
| `main` | The primary / release branch. Carries fork-branding + all features (fork-only and upstream-pending). Releases are cut from here (`v*` tags trigger `release.yml`). |
| `upstream` | **A mirror of `sozercan/kaset:main`.** Only updated by fast-forwarding from the upstream remote. Never worked on directly. Used as the base for branches that need an upstream-clean diff. |
| `feat/*`, `fix/*`, `chore/*` | Topic branches. See rules below for which base to pick. |

`buggerman:main` is **yours** — your Sparkle feed, your public key, your
"What's New" owner, your release workflow. Upstream improvements flow in by
merging `upstream` into `main`.

## Fork-only changes (why the branches diverge permanently)

The fork-branding commit on `main` replaces upstream's Sparkle config and
"What's New" fetcher with fork-owned equivalents:

| Concern | Upstream | Fork |
|---|---|---|
| `SUFeedURL` | `raw.githubusercontent.com/sozercan/kaset/main/appcast.xml` | `raw.githubusercontent.com/buggerman/kaset/main/appcast.xml` |
| `SUPublicEDKey` | upstream's Ed25519 public key | fork's Ed25519 public key (private half in GitHub secret `SPARKLE_PRIVATE_KEY`) |
| `WhatsNewProvider.owner` | `"sozercan"` | `"buggerman"` |
| Release workflow's Homebrew tap | hardcoded `sozercan/homebrew-repo` | `${{ github.repository_owner }}/homebrew-repo`, gated on `HOMEBREW_REPO_TOKEN` |
| `appcast.xml` | upstream's entries | reset; populated by fork's release workflow on each `v*` tag |
| `LICENSE` | `Copyright (c) 2025 sozercan` | upstream line retained (MIT requires it) + added `Copyright (c) 2026 Kaset contributors` |
| `NSHumanReadableCopyright` (`Scripts/build-app.sh`) | `Copyright © 2025 Sertac Ozercan. All rights reserved.` | `Copyright © 2026 Kaset contributors.` |
| `GeneralSettingsView` About → GitHub link | `https://github.com/sozercan/kaset` | `https://github.com/buggerman/kaset` |
| `README.md` Download link | `sozercan/kaset/releases` | `buggerman/kaset/releases`; Homebrew section removed until fork tap exists |
| `CONTRIBUTING.md` clone URL | `sozercan/kaset.git` | `buggerman/kaset.git` |
| `.github/ISSUE_TEMPLATE/config.yml` Discussions link | `sozercan/kaset/discussions` | `buggerman/kaset/discussions` |

These changes **cannot be upstreamed** — they'd point every upstream user at
the fork. Because topic branches destined for upstream are always based on
`origin/upstream` (see the branch model above), they never include these
edits. If you cherry-pick from `main` onto an upstream-PR branch, re-verify
by running `git diff origin/upstream...HEAD` and confirm none of the paths
above show up in the diff.

Known upstream-infra dependency (not rewritten — fork has no replacement):

- `Sources/Kaset/Services/Scrobbling/LastFMService.swift` — `workerBaseURL`
  points at `kaset-lastfm.sozercan.workers.dev` (upstream's Cloudflare
  Worker). Last.fm scrobbling therefore still routes through upstream
  infrastructure. Rewrite when a fork-owned worker is available, or
  disable Last.fm for the fork if this becomes a concern.

## Keeping `upstream` current

```bash
git fetch upstream
git push origin upstream/main:refs/heads/upstream
```

That's it — no local checkout needed. `origin/upstream` advances to match
`sozercan:main`. Because it's never diverged, this is always a fast-forward.

You can automate this with a `.github/workflows/sync-upstream.yml` cron if you
prefer, but the two-line command is fine.

## Pulling upstream changes into `main`

When upstream ships something you want, merge `upstream` into `main` through a
PR so CI runs and you see the diff:

```bash
# After the upstream-sync push above
gh pr create --repo buggerman/kaset --base main --head upstream \
    --title "chore: sync upstream" --body "Merging upstream/main into main."
```

Or just merge locally if no CI review is needed:

```bash
git checkout main
git pull
git merge origin/upstream
git push origin main
```

Conflicts typically surface only against the fork-branding commit (Sparkle
config, WhatsNewProvider, release workflow). Resolve by keeping the fork side.

## Sending a PR upstream

When you have a change on `main` that's generic enough to upstream:

```bash
git fetch origin
git checkout -b feat/whatever origin/upstream    # base from the tracking branch
# cherry-pick from main, or rewrite the change here
git cherry-pick <commit-from-main>                # or re-implement cleanly
git push origin feat/whatever                     # optional — for your CI

# Open PR against sozercan:main
gh pr create --repo sozercan/kaset --base main --head buggerman:feat/whatever
```

Because the branch is based on `origin/upstream` (= `sozercan:main`), the PR
diff is **upstream-clean** — no fork-branding, no unrelated local features.

If the same work should also land on your fork's `main` (e.g. you're shipping
it to your users before upstream accepts it), open a second PR:

```bash
gh pr create --repo buggerman/kaset --base main --head feat/whatever
```

This pattern keeps main free to carry fork-branding without polluting the
upstream-facing branch.

## Pre-flight conflict check

To see if upcoming upstream changes would conflict with your fork before
merging, do a dry-run merge locally:

```bash
git fetch upstream
git checkout main
git pull
git merge --no-commit --no-ff origin/upstream
# inspect
git merge --abort    # revert the dry-run
```

Or use `git merge-tree`:

```bash
git merge-tree --name-only --write-tree main origin/upstream
# prints conflicting files if any, nothing if clean
```

## Releasing from the fork

Push a `v*` tag on `main`. `.github/workflows/release.yml` will:

1. Build a Universal DMG, sign with `SPARKLE_PRIVATE_KEY` secret.
2. Create a GitHub release and upload the DMG.
3. Update `appcast.xml` at repo root with the new `<item>` (Sparkle clients
   pick it up within `SUScheduledCheckInterval` seconds).
4. **Skip** the Homebrew tap step unless `HOMEBREW_REPO_TOKEN` is configured.

```bash
git checkout main
git pull
git tag v0.9.0
git push origin v0.9.0
```

If you want the Homebrew path too, create `buggerman/homebrew-repo` and add a
PAT with `contents:write` scope as `HOMEBREW_REPO_TOKEN`.

## Rotating the Sparkle key

If the private key is compromised:

1. `Scripts/sign-update.sh` or `.build/artifacts/sparkle/Sparkle/bin/generate_keys` → new keypair.
2. Update `SUPublicEDKey` in `Info.plist` and `Scripts/build-app.sh`.
3. Update `SPARKLE_PRIVATE_KEY` GitHub secret.
4. Bump the version and tag a release immediately — old installs with the old
   public key will keep auto-updating from the last-good signed build until
   users reinstall.
