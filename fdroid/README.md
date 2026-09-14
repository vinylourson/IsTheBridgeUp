# F-Droid submission

`fr.vinylourson.is_the_bridge_up.yml` is a **draft** of the file that goes into
[fdroiddata](https://gitlab.com/fdroid/fdroiddata) as
`metadata/fr.vinylourson.is_the_bridge_up.yml`, via a merge request.

It is untested — the recipe can only really be exercised on F-Droid's own
buildserver — and two prerequisites are not met yet.

## Prerequisite 1 — vendor the Flutter SDK as a submodule

The recipe calls `.flutter/bin/flutter`, which does not exist in this
repository. F-Droid builds with a fully free toolchain on its own
infrastructure and will not install Flutter for us, so the SDK has to be pinned
as a git submodule at `.flutter`, at the exact revision our releases are built
with. This is what Obtainium does, and it is the only arrangement currently
known to work.

Consequences worth weighing before doing it:

- clones get much heavier, and CI has to check out submodules
- the pinned SDK revision becomes something to maintain deliberately
- our own release workflow should build with the same pinned SDK, or the
  "reproducible" claim is only accidentally true

## Prerequisite 2 — prove reproducibility locally first

`binary:` asks F-Droid to rebuild the tag and compare byte for byte with our
published APK. If it does not match, the app is still publishable but F-Droid
signs it with **their** key — which means an F-Droid install and a direct
download become two mutually exclusive apps.

The known Flutter obstacle is absolute build paths baked into `libapp.so`. The
recipe reproduces the GitHub Actions path (`/home/runner/work/IsTheBridgeUp/
IsTheBridgeUp`) for exactly that reason. Verify before submitting:

```bash
# unzip both APKs and compare the native library
unzip -p ours.apk lib/arm64-v8a/libapp.so | sha256sum
unzip -p rebuilt.apk lib/arm64-v8a/libapp.so | sha256sum
```

If they differ, `strings libapp.so | grep -F /home/` usually shows why.

## Submitting

1. Fork <https://gitlab.com/fdroid/fdroiddata> (needs a GitLab account).
2. Add the file as `metadata/fr.vinylourson.is_the_bridge_up.yml`.
3. Run `fdroid readmeta && fdroid lint fr.vinylourson.is_the_bridge_up`.
4. Open a merge request.

The listing text, icon and screenshots are read from `metadata/` at the root of
this repository and do not need to be duplicated in fdroiddata.
