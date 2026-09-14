# F-Droid submission

`fr.vinylourson.is_the_bridge_up.yml` is a **draft** of the file that goes into
[fdroiddata](https://gitlab.com/fdroid/fdroiddata) as
`metadata/fr.vinylourson.is_the_bridge_up.yml`, via a merge request.

The recipe itself is unverified — it can only really be exercised on F-Droid's
buildserver — but the premise underneath it has been measured.

## Why `binary:` is worth the trouble

It asks F-Droid to rebuild the tag and compare byte for byte with our published
APK. On a match they publish **our** signed binary instead of re-signing with
F-Droid's key, so there is one signing identity everywhere and a user can move
between F-Droid and a direct download without uninstalling. Without it, those
are two mutually exclusive apps.

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

## Submitting

1. Fork <https://gitlab.com/fdroid/fdroiddata> (needs a GitLab account).
2. Add the file as `metadata/fr.vinylourson.is_the_bridge_up.yml`.
3. Run `fdroid readmeta && fdroid lint fr.vinylourson.is_the_bridge_up`.
4. Open a merge request.

The listing text, icon and screenshots are read from `metadata/` at the root of
this repository and do not need to be duplicated in fdroiddata.
