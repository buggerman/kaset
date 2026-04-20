# Fork maintenance notes

This file lives on `buggerman/kaset` only. Do not upstream it.

## Why the fork diverges

The fork adds a small, dedicated commit — `chore(fork): …` — that replaces
upstream's Sparkle config and "What's New" fetcher with fork-owned equivalents:

| Concern | Upstream | Fork |
|---|---|---|
| `SUFeedURL` | `raw.githubusercontent.com/sozercan/kaset/main/appcast.xml` | `raw.githubusercontent.com/buggerman/kaset/main/appcast.xml` |
| `SUPublicEDKey` | upstream's Ed25519 public key | fork's Ed25519 public key (private half in GitHub secret `SPARKLE_PRIVATE_KEY`) |
| `WhatsNewProvider.owner` | `"sozercan"` | `"buggerman"` |
| Release workflow's Homebrew tap | hardcoded `sozercan/homebrew-repo` | `${{ github.repository_owner }}/homebrew-repo`, gated on `HOMEBREW_REPO_TOKEN` |
| `appcast.xml` | upstream's entries | reset; populated by fork's release workflow on each `v*` tag |

These changes **cannot be upstreamed** — they'd point every upstream user at
the fork.

## Branching discipline

To avoid accidentally including the fork-branding commit in an upstream PR:

> **Always branch new features from `upstream/main`, not from
> `buggerman/main`.**

```bash
git fetch upstream
git checkout -b feat/whatever upstream/main
# ... work ...
```

Then push the branch to both remotes as needed:

```bash
# To fork (for your own testing + a PR into buggerman/main):
git push origin feat/whatever
gh pr create --repo buggerman/kaset --base main --head feat/whatever

# To upstream for review:
gh pr create --repo sozercan/kaset --base main --head buggerman:feat/whatever
```

Because the branch is based on `upstream/main`, the **upstream PR diff is
clean** — no fork-branding noise. When the same branch merges into
`buggerman/main`, it lands on top of the fork-branding commit.

## When upstream moves, sync `buggerman/main`

If `buggerman/main` has no local commits beyond the fork-branding one:

```bash
git fetch upstream
git checkout main
git merge upstream/main   # or: git pull upstream main
git push origin main
```

A merge commit is expected (fork-branding is local). That's fine.

Alternatively, rebase the fork-branding commit on top of upstream:

```bash
git fetch upstream
git checkout main
git rebase upstream/main
git push --force-with-lease origin main
```

Cleaner history, but forces anyone else with the branch checked out to reset.

## Releasing from the fork

Push a `v*` tag. `.github/workflows/release.yml` will:

1. Build a Universal DMG, sign with `SPARKLE_PRIVATE_KEY` secret.
2. Create a GitHub release and upload the DMG.
3. Update `appcast.xml` at repo root with the new `<item>` (Sparkle clients
   pick it up within `SUScheduledCheckInterval` seconds).
4. **Skip** the Homebrew tap step unless `HOMEBREW_REPO_TOKEN` is configured.

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
