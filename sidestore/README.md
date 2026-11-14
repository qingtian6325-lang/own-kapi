# SideStore / AltStore source

Published via GitHub Pages from this folder.

| | |
|---|---|
| **Stable URL** | `https://qingtian6325-lang.github.io/own-mimi/apps.json` |
| **Fallback (raw)** | `https://raw.githubusercontent.com/qingtian6325-lang/own-mimi/main/sidestore/apps.json` |
| **Bundle ID** | `com.jinghao.mimimoney` |

CI: after a successful IPA publish on `main`, `build-mimi-ios.yml` upserts `apps.json`, commits `chore(sidestore): …` (raw), uploads a Pages artifact from that tree, and the **Deploy SideStore Pages** job publishes it. `GITHUB_TOKEN` pushes do not start other workflows, so release bumps must not rely on `sidestore-pages.yml`. That workflow still covers normal `sidestore/**` push/PR merges.

