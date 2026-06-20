This folder is for the active Setapp lane.

SaneClip ships through direct Lemon Squeezy/Sparkle distribution, the App
Store, and Setapp. Keep the Setapp lane separate from the other channels:
Setapp builds use the `SaneClipSetapp` scheme, the
`com.saneclip.app-setapp` bundle ID, Setapp Framework access,
Setapp-managed updates, and Setapp-managed Pro access.

Keep the Setapp-provided `setappPublicKey.pem` in this folder. The Setapp
build script copies `Setapp/setappPublicKey.pem` into the app bundle at build
time so the Setapp SDK can verify subscription receipts.

Before any Setapp upload, verify `.saneprocess`, `ARCHITECTURE.md`, release
notes, listing copy, licensing copy, reviewer notes, and listing screenshots
agree with the active Setapp lane. The Setapp screenshots are declared in
`.saneprocess` and must come from the dedicated owned-site app-in-use Setapp
asset root. The current approved order is:

- `docs/images/setapp/saneclip-setapp-01-clipboard-history.png`
- `docs/images/setapp/saneclip-setapp-02-menu-capture.png`
- `docs/images/setapp/saneclip-setapp-03-touch-id-privacy-settings.png`
- `docs/images/setapp/saneclip-setapp-04-snippets.png`
- `docs/images/setapp/saneclip-setapp-05-private-storage.png`

Then follow the canonical SaneProcess lane:

```bash
./scripts/SaneMaster.rb setapp_package --project "$(pwd)" --app-name SaneClip --scheme SaneClipSetapp
./scripts/SaneMaster.rb setapp_media_sync --app SaneClip
./scripts/SaneMaster.rb setapp_upload --zip /path/to/SaneClip-Setapp.zip --release-notes-file /path/to/setapp-public-notes.txt --review-comments-file /path/to/setapp-private-review-comments.txt
./scripts/SaneMaster.rb setapp_status
```

After media sync, verify `https://setapp.com/apps/saneclip` because the public
Setapp page can lag behind the developer portal media list.

Setapp release notes are public customer copy. Do not put review-team comments,
Setapp process details, icon geometry, archive/signing details, direct-store
licensing/update terms, or placeholders in that field. Put private review
context in `--review-comments-file`, or explicitly use
`--no-review-comments-needed` when there is nothing private to add.

Do not ignore Setapp validation alerts. A package is not ready until the final
ZIP passes strict validation, quarantined launch proof, upload/hosted-archive
byte-match proof, and `setapp_status` shows no action required. Approval is not
release; after manual release, rerun `setapp_status` and confirm the public
Setapp status has moved to released/live.
