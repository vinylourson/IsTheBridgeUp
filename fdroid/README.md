# F-Droid submission

`fr.vinylourson.is_the_bridge_up.yml` is a **draft** of the file that goes into
[fdroiddata](https://gitlab.com/fdroid/fdroiddata) as
`metadata/fr.vinylourson.is_the_bridge_up.yml`, via a merge request.

**Reproducibility is verified.** An independent rebuild of `v1.1.3` on a clean
runner produced a byte-identical `libapp.so` to the published APK, and every
entry outside `META-INF/` matched:

```
rebuilt   libapp.so 4e1e2f75f11c5de81c7cb313d9336599b4c1a5e3bc8c3f31dd61eaa51e3a1805
published libapp.so 4e1e2f75f11c5de81c7cb313d9336599b4c1a5e3bc8c3f31dd61eaa51e3a1805
Reproducible: every non-signature entry matches.
```

Re-run it on any tag before submitting:

```bash
gh workflow run reproducible.yml -f tag=v1.1.3 --ref main
```

The recipe itself still has to be exercised on F-Droid's buildserver, which
only they can do.

## Why `binary:` is worth the trouble

It asks F-Droid to rebuild the tag and compare byte for byte with our published
APK. On a match they publish **our** signed binary instead of re-signing with
F-Droid's key, so there is one signing identity everywhere and a user can move
between F-Droid and a direct download without uninstalling. Without it, those
are two mutually exclusive apps.

## What made it fail first

The very first rebuild check failed, and the cause was not Flutter at all: the
release job passed `--dart-define=GIT_SHA` and the rebuild did not, and that
value is compiled into `libapp.so`. The build command now has one shape,
mirrored in `release.yml`, `reproducible.yml` and this recipe, with a test
asserting all three agree.

`--short` also became `--short=10`. Git's default abbreviation length scales
with repository size, so two clones can abbreviate the same commit differently
and produce different binaries from identical source.

## The Flutter reproducibility problem, measured

Three builds of the same commit with the same vendored SDK:

| build | where | `libapp.so` sha256 |
|---|---|---|
| 1 | repo path | `1eef638c…` |
| 2 | repo path, clean rebuild | `1eef638c…` |
| 3 | a different directory | `089138 91…` |

So the build **is** deterministic, and it **is** path-dependent —
`strings libapp.so` shows the absolute build path embedded in it. That is the
whole problem, and matching the path is the whole fix.

Our releases are built by GitHub Actions at
`/home/runner/work/IsTheBridgeUp/IsTheBridgeUp`, with the SDK pinned at
`.flutter`. The recipe moves F-Droid's checkout to that same path and uses that
same SDK. Both halves have to hold: a different SDK revision changes the bytes
just as surely as a different path.

To check a rebuild before asking F-Droid to:

```bash
unzip -p ours.apk    lib/arm64-v8a/libapp.so | sha256sum
unzip -p rebuilt.apk lib/arm64-v8a/libapp.so | sha256sum
```

If they differ, `strings libapp.so | grep -F /home/` usually shows why.

## The SDK is vendored

`.flutter` is a git submodule pinned to the exact Flutter revision releases are
built with (currently `3.47.1`). The release workflow builds with it rather
than with `flutter-action`, and fails if the two disagree.

Clones that init submodules pay about 184 MB for it. Upgrading Flutter is now a
deliberate act: bump `FLUTTER_VERSION`, move the submodule, and expect the
rebuilt bytes to change.

## Validation

`fdroid lint` runs clean against a real fdroiddata checkout:

```
fdroid readmeta
fdroid lint fr.vinylourson.is_the_bridge_up     # no findings
```

It caught one thing first time round: `Categories: Time` is not a valid
F-Droid category. The valid list lives in `config/categories.yml` in
fdroiddata; this app uses `Navigation` and `Schedule`.

Install the tooling with `brew install fdroidserver`, and lint inside a
fdroiddata clone with the file copied into `metadata/`.

## Submitting

Needs a GitLab account, which is the only step left that cannot be automated
from here.

1. Fork <https://gitlab.com/fdroid/fdroiddata>.
2. Copy `fr.vinylourson.is_the_bridge_up.yml` to
   `metadata/fr.vinylourson.is_the_bridge_up.yml` in the fork.
3. Validate: `fdroid readmeta && fdroid lint fr.vinylourson.is_the_bridge_up`
4. Open a merge request against fdroiddata.

The listing text, icon and screenshots are read from `metadata/` at the root of
**this** repository, so they do not need duplicating in fdroiddata.

### Worth saying in the merge request

- The build is reproducible and `binary:` is set, so F-Droid can publish our
  signed APK rather than re-signing. The verification workflow in this
  repository runs the same comparison.
- The SDK is vendored at `.flutter` and pinned, which is why `submodules: true`
  and the path juggling in `prebuild`/`build` are there.
- Most of this app was written with an AI coding assistant. F-Droid has no
  policy on that, unlike IzzyOnDroid, but reviewers may reasonably want to
  know rather than discover it from the commit log.
