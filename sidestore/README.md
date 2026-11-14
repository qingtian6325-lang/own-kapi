# SideStore / AltStore source

Published via GitHub Pages from this folder.

| | |
|---|---|
| **Stable URL** | `https://qingtian6325-lang.github.io/own-mimi/apps.json` |
| **Fallback (raw)** | `https://raw.githubusercontent.com/qingtian6325-lang/own-mimi/main/sidestore/apps.json` |
| **Bundle ID** | `com.jinghao.mimimoney` |

CI: after a successful IPA publish on `main`, `scripts/update-sidestore-source.mjs` upserts the new version into `apps.json` and commits `chore(sidestore): …`, which triggers `.github/workflows/sidestore-pages.yml`.

