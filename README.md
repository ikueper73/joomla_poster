# Joomla Poster

A small desktop app (Windows, Linux) that creates new articles in **one fixed
category** of a Joomla 5 site, with an intro image and inline images. It
uses the Joomla Web Services API. It can't edit or list articles and isn't
meant to replace the Joomla backend.

## Joomla setup (once per site)

1. **Enable the plugins** (System → Plugins):
   - API Authentication - Web Services Joomla Token
   - User - Joomla API Token
   - Web Services - Content
   - Web Services - Media
2. **Create a user group** for the app, e.g. "API Poster", and give it only
   what it needs:
   - Global Configuration → Permissions: *Web Services Login*: Allowed.
   - Articles → Options → Permissions (or on the target category):
     *Create*: Allowed.
   - Media → Options → Permissions: *Create*: Allowed.
3. **Allow the group to have tokens**: open the plugin "User - Joomla API
   Token" and add the group under *Allowed User Groups*. By default only Super
   Users can have tokens.
4. **Create a dedicated user** in that group, log in as that user (or edit
   the user as admin), and copy the token from the *Joomla API Token* tab.

> **Never use a Super User token.** Anyone who gets the token can do
> everything its user can. A low-privilege user limits the damage.

5. Note the **category ID** from the ID column of Content → Categories.

## Using the app

1. On first start, click **Open settings**. Enter the site URL (`https://…`),
   the token and the category ID. Choose whether articles are published
   immediately (default: off, so an editor reviews them first). Then click
   **Test connection and save**. Settings are only saved when the test
   succeeds.
2. Write the article. Separate paragraphs with a blank line. Everything is
   posted as plain text; HTML you type is shown literally, not interpreted.
3. **Intro image**: shown in blog and category views, and also used as the
   full-article image.
4. **Inline images**: add them, then place each one in the text with its
   marker `[img1]`, `[img2]`, … (the arrow button inserts it at the cursor).
   A marker on its own line becomes its own paragraph. Images without a
   marker are added at the end of the article.
5. Click **Post article**. Images are resized to max. 1920 px, saved as
   JPEG, and their EXIF data (including GPS location) is removed. All images
   are uploaded first; if one fails, no article is created.

Images are stored in `images/articles/<year>/` on the site.

### Security notes

- The token is stored in the OS keyring (Windows Credential Manager, the
  Secret Service on Linux), never in plain files, and is never shown in
  error messages.
- Only `https://` site URLs are accepted (`http://localhost` for
  development).

## Requirements

### Linux

- A running keyring (GNOME Keyring or KWallet), unlocked after login.
  Without it, the token can't be saved.
- `zenity` or `kdialog` for the file chooser.
- To build: the usual Flutter Linux dependencies plus `libsecret-1-dev`:
  ```
  sudo apt install libsecret-1-dev
  ```

### Windows

- No extra runtime setup; the token goes into the Credential Manager.
- To build: Visual Studio with the "Desktop development with C++" workload.
  Windows builds must be made on Windows.

## Development

```
flutter pub get
flutter analyze        # must report no issues
flutter test           # all tests use a mocked HTTP client
flutter run -d linux   # or -d windows
flutter build linux    # or: flutter build windows
```

Project structure and API details are in [CLAUDE.md](CLAUDE.md).

## Known limitations

- If an image upload fails partway through, images already uploaded remain on
  the server (no article references them). Delete them in the Media manager
  if needed.
- File names contain the title and the posting time down to the minute.
  Posting two articles with the same title in the same minute fails with
  "A file with this name already exists".
- Not yet verified against a live site: the exact response format of
  `GET /media/adapters`, and whether Joomla creates the
  `articles/<year>/` folder automatically on the first upload of a year.
