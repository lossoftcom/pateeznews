# Pateeznews Web Stories Editor

Isolated React 18 build of the official **Google Web Stories** editor
(`@googleforcreators/story-editor`). It is embedded inside the Flutter admin
(Stories → row menu → "Editörde Düzenle") through an iframe (web) or
`InAppWebView` + `InAppLocalhostServer` (native), talking over the
`PATEEZ_WS_*` postMessage / `PateezWebStories` JavaScript-handler bridge.

## Build

```bash
cd admin/web_stories_editor
npm install
npm run build
```

`npm run build` emits the static bundle into `admin/assets/web_stories/`
(declared in `admin/pubspec.yaml`). The built bundle is committed to the repo —
exactly like the vendored `admin/assets/posta_builder/` bundle — so deploys do
**not** rebuild it. Re-run `npm run build` and commit the output whenever this
editor's source (`src/`) changes.

`node_modules/` is git-ignored.
