# Joomla Article Poster

A minimal Flutter app (Windows, Linux) that creates new
articles in ONE fixed category of an existing Joomla 5 site, with optional
images. Keep it simple: this is a single-purpose tool, not a CMS client.

## Scope

In scope:
- Settings screen: site URL, API token, target category ID
- Compose screen: title, body text, intro image, additional inline images
- Upload images, then create the article referencing them
- Clear success/error feedback

Out of scope (do not build unless asked):
- Editing, listing, or deleting existing articles
- Category selection, tags, custom fields, multilingual
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

## Joomla Web Services API

Base URL: `{siteUrl}/api/index.php/v1`

Headers on every request:
- `X-Joomla-Token: {token}` (used instead of `Authorization: Bearer`,
  because some hosts strip the Authorization header)
- `Accept: application/vnd.api+json`
- `Content-Type: application/json` for POST

### Verify settings
`GET /content/categories/{catid}` → 200 means the URL, token, and category
are valid. Use it for a "Test connection" button.

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
- Body text: user writes plain text; convert paragraphs to `<p>` and HTML-escape
  user input. Inline images are inserted as `<img src="images/..." alt="...">`.

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

## Project structure

```
lib/
  main.dart
  api/joomla_client.dart     # all HTTP calls, no UI code
  api/models.dart
  services/image_service.dart
  services/settings_store.dart
  ui/settings_screen.dart
  ui/compose_screen.dart
test/
  api/joomla_client_test.dart   # uses MockClient from package:http/testing
```

## Commands

- `flutter pub get`
- `flutter analyze` — must pass with no issues before a task is done
- `flutter test` — must pass; add tests for every API method
- `flutter run -d <device>`

## Working rules

- Test against a mocked HTTP client, never against the live site, unless
  explicitly asked.
- Small, focused changes; explain any new dependency before adding it.
- Keep UI text in English; keep the code readable over clever.
