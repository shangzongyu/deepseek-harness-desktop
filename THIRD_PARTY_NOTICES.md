# Third-Party Notices

This project packages third-party software. Licenses are as follows:

| Component | Source | License |
|---|---|---|
| pake (Tauri app shell template) | https://github.com/tw93/pake | GPL-3.0-or-later, with the [Pake Output Exception](https://github.com/tw93/pake/blob/main/LICENSE-EXCEPTION). The code under `app/src-tauri/` is derived from pake's template; see `LICENSE` (GPL-3.0). |
| DeepSeek Harness (`@deepseek-ai/dsh`) | https://github.com/deepseek-ai/deepseek-harness | MIT. Bundled inside the app at `Contents/Resources/runtime/app/node_modules`. |
| Node.js | https://nodejs.org | MIT. Bundled inside the app at `Contents/Resources/runtime/node`. |
| DeepSeek Harness Web UI logo (used for the app icon) | https://github.com/deepseek-ai/deepseek-harness | MIT (see `apps/web/public/favicon.svg` upstream). |

All other bundled npm packages retain their own licenses inside `node_modules`.

This project itself is released under the GNU General Public License v3 (see `LICENSE`), because it modifies pake's GPL-licensed template source (the `Pake Output Exception` does not cover modified pake source). The **packaged app binary** is governed by the Pake Output Exception and may be distributed under terms of your own choosing.
