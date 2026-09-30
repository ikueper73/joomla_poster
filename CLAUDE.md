# Joomla Article Poster

A minimal Flutter app (Windows, Linux) that creates new
articles in ONE fixed category of an existing Joomla 5 site, with optional
images. Keep it simple: this is a single-purpose tool, not a CMS client.

## Scope

In scope:
- Settings screen: UI language, site URL, API token, target category ID
- Compose screen: title, body text, intro image, additional inline images
- Upload images, then create the article referencing them
- Clear success/error feedback

Out of scope (do not build unless asked):
- Editing, listing, or deleting existing articles
- Category selection, tags, custom fields, multilingual Joomla content
  (articles are always posted with `language: "*"`)
- Offline drafts, sync, user accounts, analytics, telemetry, Firebase

## Tech stack

- Flutter stable, Dart 3, null safety, Material 3
- State: plain `StatefulWidget` + `ChangeNotifier`; no state-management
  framework unless complexity clearly demands it
- Packages (ask before adding anything else):
  - `http` – API calls
  - `flutter_secure_storage` – API token (never shared_preferences)
  - `shared_preferences` – non-secret settings (URL, category ID)
  - `file_picker` – image selection on all platforms
  - `image` – resize/compress before upload
  - `flutter_localizations` (SDK) + `intl` – UI translations via gen-l10n
  - `markdown` – parses the body text (we render the HTML ourselves)

## Joomla Web Services API

Base URL: `{siteUrl}/api/index.php/v1`

Headers on every request:
- `X-Joomla-Token: {token}` (used instead of `Authorization: Bearer`,
  because some hosts strip the Authorization header)
- `Accept: application/vnd.api+json`
- `Content-Type: application/json` for POST

### Verify settings
`GET /content/categories/{catid}` → 200 means the URL, token, and category
are valid. Use it for a "Test connection" button. Settings are only saved
after a successful test (together with the media adapter); posting requires
a stored adapter.

### Upload an image
`POST /media/files`
```json
{ "path": "local-images:/articles/<yyyy>/<slug>-<n>.jpg", "content": "<base64>" }
```
- The adapter prefix (`local-images`) can differ per site; check it with
  `GET /media/adapters` during connection test and use the returned name.
- Resulting public path for use in articles: `images/articles/<yyyy>/<file>`
- Before upload: resize to max 1920px on the long edge, JPEG quality ~85,
  strip EXIF (privacy: GPS data).
- Only jpg/jpeg/png/webp. Respect Joomla's upload size limit; show a clear
  error if the server rejects the file.

### Create the article
`POST /content/articles`
```json
{
  "title": "...",
  "catid": 12,
  "articletext": "<p>...</p>",
  "state": 0,
  "language": "*",
  "images": {
    "image_intro": "images/articles/2026/foo-1.jpg",
    "image_fulltext": "images/articles/2026/foo-1.jpg"
  }
}
```
- `state: 0` = unpublished (default: an editor reviews on the site).
  Make this a setting, default unpublished.
- Let Joomla generate the alias; don't send one.
- Body text: user writes Markdown (see below). Inline images are inserted as
  `<img src="images/..." alt="...">`.
- The intro image is used for both `image_intro` and `image_fulltext`; its alt
  text goes into `image_intro_alt` / `image_fulltext_alt`.

### Body text (Markdown)
`lib/api/article_html.dart` parses with the `markdown` package but renders
the HTML with its own whitelist renderer:
- Supported: headings (`### Lead` → `<h3>`, the usual intro style), paragraphs,
  bold, italic, lists, quotes, inline/fenced code, links. A single line break
  becomes `<br>`.
- `---` (or `***`) on its own line → Joomla's Read more separator
  `<hr id="system-readmore">`; Joomla splits intro/full text at it. Only the
  first one; later ones are plain `<hr>`.
- Disabled on purpose: raw HTML (block and inline, shown as escaped text),
  setext headings (`text` + `---` would become `<h2>`), indented code blocks,
  link reference definitions, Markdown images (reduced to alt text; images
  must be uploaded through the app).
- Security: all text is HTML-escaped; only whitelisted tags are emitted; links
  only for `http`, `https`, `mailto` or relative URLs without a scheme; no
  attributes except `href` (and `src`/`alt` on uploaded images).

### Image markers
The user places inline images with markers `[img1]`, `[img2]`, … in the body
(`lib/api/article_html.dart`):
- N is the image's 1-based position in the inline image list.
- Markers are replaced in escaped text nodes during rendering, so user text
  can never inject HTML. Markers inside code stay literal. A marker alone in
  a paragraph gives `<p><img …></p>`; inside a sentence (or heading, list,
  bold text) it stays inline. Markers may repeat.
- Unknown markers (no such image) block posting with an error.
- Images without a marker are appended at the end; the UI warns first.
- Removing an image renumbers later ones; the UI asks for confirmation when
  existing markers would be affected.

### Order of operations
1. Upload all images; collect their paths.
2. Create the article.
3. If any upload fails, stop and report; do not create a half-finished article.

## Security rules

- Never log, print, or include the token in error messages or crash output.
- Only allow `https://` site URLs (allow `http://localhost` for dev).
- The token belongs to a dedicated, low-privilege Joomla user
  (create + upload rights only), never a Super User. Mention this in the
  settings screen help text.
- Surface API error details from the JSON:API `errors` array, sanitized.

## Localization

- UI languages: English (`en`, template) and German (`de`). ARB files live
  in `lib/l10n/`; `flutter gen-l10n` (runs automatically on `pub get` /
  `run` / `test`) generates `lib/l10n/app_localizations*.dart`.
- Every user-visible string goes into both ARB files. No hard-coded UI text,
  except language names ("English", "Deutsch"), which stay in their own
  language.
- The language setting (`system`, `en`, `de`) applies immediately and is
  stored in shared preferences. `system` follows the OS language; any other
  OS language falls back to English (so `supportedLocales` in `main.dart`
  lists English first).
- Non-UI code (`lib/api`, `lib/services`) never builds user-facing
  sentences. It throws typed errors (`JoomlaApiException` with
  `ApiErrorKind`, `ImageUploadException`, `ImageProcessingException`,
  `TokenStoreException`, `SiteUrlError`); `lib/ui/error_text.dart` turns
  them into translated text. Server-provided details stay in the site's
  language.
- German texts use the neutral infinitive style ("Bitte den Titel
  eingeben"), no "du"/"Sie".

## Project structure

```
lib/
  main.dart
  api/joomla_client.dart     # all HTTP calls, no UI code
  api/models.dart
  api/article_html.dart      # Markdown + [imgN] markers → article HTML
  services/image_service.dart
  services/settings_store.dart
  ui/settings_screen.dart
  ui/compose_screen.dart
  ui/error_text.dart         # typed errors → translated messages
  ui/status_message.dart     # success/error line below a form
  l10n/app_en.arb            # English (template)
  l10n/app_de.arb            # German
test/
  helpers.dart               # localizedApp() for widget tests
  app_test.dart
  api/joomla_client_test.dart   # uses MockClient from package:http/testing
  api/article_html_test.dart
  api/models_test.dart
  services/image_service_test.dart
  services/settings_store_test.dart
  ui/settings_screen_test.dart  # widget tests with MockClient-based clients
  ui/compose_screen_test.dart   # fake image service + file picker
  ui/error_text_test.dart
```

UI screens take their dependencies (client factory, image service, file
picker) as constructor parameters so widget tests can inject fakes.

## Commands

- `flutter pub get`
- `flutter analyze` — must pass with no issues before a task is done
- `flutter test` — must pass; add tests for every API method
- `flutter run -d <device>`

## Packaging and releases

- Linux app ID: `io.github.ikueper73.joomla_poster` (`linux/CMakeLists.txt`).
  Don't change it: the keyring entry for the token is named after it, so a
  change loses the saved token.
- License: GPL-3.0-or-later, © Ingo Kueper. `LICENSE` is the unmodified
  GPLv3 text (keeps GitHub's license detection working); the copyright line
  lives in README, metainfo, `packaging/linux/copyright` and the About dialog.
- `packaging/linux/`: desktop entry, SVG icon, AppStream metainfo (developer,
  license, description for GNOME Software / KDE Discover), Debian copyright
  file, `build_packages.sh` (builds `dist/*.tar.gz`, `dist/*.deb`,
  `SHA256SUMS` from the release bundle).
- `packaging/windows/installer.iss`: Inno Setup installer (per-user, no
  admin). Its `AppId` GUID must never change (Windows uses it for updates).
  `windows/CMakeLists.txt` bundles the VC++ runtime DLLs next to the exe;
  `windows/runner/Runner.rc` holds publisher and copyright; the icon is
  `windows/runner/resources/app_icon.ico` (rendered from the SVG).
- Every release needs a `<release>` entry in the metainfo; the script fails
  without it. Validate with `appstreamcli validate --no-net <file>`.
- `.github/workflows/release.yml`: on a `v*` tag matching the pubspec
  version, builds Linux (Ubuntu 22.04) and Windows (windows-2022) packages,
  then one job publishes the GitHub release with all files and a combined
  `SHA256SUMS`. Manual runs only upload artifacts. Windows builds can't be
  tested locally on Linux; use a manual workflow run.
- Don't push, tag or publish releases unless explicitly asked.

## Working rules

- Test against a mocked HTTP client, never against the live site, unless
  explicitly asked.
- Small, focused changes; explain any new dependency before adding it.
- UI text via ARB files in English and German (see Localization); code,
  comments and commit messages in English. Keep the code readable over
  clever.
