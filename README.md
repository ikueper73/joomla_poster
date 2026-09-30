# Joomla Poster

A small desktop app (Windows, Linux) that creates new articles in **one fixed
category** of a Joomla 5 site, with an intro image and inline images. It
uses the Joomla Web Services API. It can't edit or list articles and isn't
meant to replace the Joomla backend.

## Installation

### Windows

Download from the
[Releases page](https://github.com/ikueper73/joomla_poster/releases):

- **`…-windows-x64-setup.exe`** (recommended): installs Joomla Poster for
  your user without admin rights, with a start menu entry and an uninstall
  entry in the Windows settings.
- **`…-windows-x64.zip`**: unpack anywhere and start `joomla_poster.exe`.

The app is not code-signed yet, so Windows SmartScreen may show "Windows
protected your PC". Click **More info → Run anyway**. You can compare the
file with `SHA256SUMS` first (`Get-FileHash <file>` in PowerShell).

### Linux

Download the latest files from the
[Releases page](https://github.com/ikueper73/joomla_poster/releases):

- **Debian, Ubuntu, TUXEDO OS and other derivatives**: the `.deb` file.
  ```
  sudo apt install ./joomla-poster_<version>_amd64.deb
  ```
  This adds "Joomla Poster" to the application menu and installs the needed
  libraries. Remove it with `sudo apt remove joomla-poster`.
- **Other distributions**: the `.tar.gz` file. Unpack it anywhere and start
  `joomla_poster` inside. Needs GTK 3, libsecret, and zenity or kdialog from
  your distribution. The folder also contains a `.desktop` file and an icon
  if you want a menu entry.

`SHA256SUMS` lets you check the download: `sha256sum -c SHA256SUMS
--ignore-missing`.

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

1. On first start, click **Open settings**. The language (English, German or
   the system language) can be changed there at any time. Enter the site URL (`https://…`),
   the token and the category ID. Choose whether articles are published
   immediately (default: off, so an editor reviews them first). Then click
   **Test connection and save**. Settings are only saved when the test
   succeeds.
2. Write the article in Markdown. Separate paragraphs with a blank line.
   - `### Lead sentence` → an h3 heading (e.g. for the lead).
   - `**bold**`, `*italic*`, `- list item`, `1. item`, `> quote`,
     `[link text](https://…)`.
   - A line with only `---` is Joomla's **Read more** break: the text above
     it is the intro text shown in blog views.
   - HTML you type is shown literally, not interpreted. Markdown images
     (`![](…)`) are not supported; use the image buttons instead.
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

- Windows 10 or 11, 64-bit. The token goes into the Credential Manager.
  The Visual C++ runtime DLLs are shipped with the app.
- To build: Visual Studio 2022 with the "Desktop development with C++"
  workload. Windows builds must be made on Windows (or by the GitHub
  workflow). For the installer, [Inno Setup 6](https://jrsoftware.org/isinfo.php):
  ```
  flutter build windows --release
  iscc /DAppVersion=1.0.0 packaging\windows\installer.iss
  ```

## Development

```
flutter pub get
flutter analyze        # must report no issues
flutter test           # all tests use a mocked HTTP client
flutter run -d linux   # or -d windows
flutter build linux    # or: flutter build windows
```

Project structure and API details are in [CLAUDE.md](CLAUDE.md).

## Publishing a release

Releases are built by GitHub Actions
([.github/workflows/release.yml](.github/workflows/release.yml)) on Ubuntu
22.04, so the Linux binary also runs on older distributions.

1. Raise `version:` in `pubspec.yaml` (e.g. `1.1.0+2`) and add a matching
   entry at the top of `<releases>` in
   `packaging/linux/io.github.ikueper73.joomla_poster.metainfo.xml`
   (e.g. `<release version="1.1.0" date="2026-11-15"/>`). Commit both; the
   build fails if the metainfo entry is missing.
2. Tag that version and push:
   ```
   git tag v1.1.0
   git push origin master v1.1.0
   ```
3. The workflow runs analyze and tests, builds the Linux `.deb` and
   `.tar.gz` (on Ubuntu 22.04) and the Windows installer and `.zip` (on
   Windows Server 2022), and creates the GitHub release with all files,
   `SHA256SUMS` and generated release notes. It fails if the
   tag doesn't match the pubspec version.

For a test build without a release, run the workflow manually (Actions →
Release → Run workflow); the packages are attached to the run as an
artifact. To build the packages locally:
```
flutter build linux --release
packaging/linux/build_packages.sh
```
Local builds only run on systems with a glibc at least as new as yours.

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

## License

Copyright © 2026 Ingo Kueper

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version. See [LICENSE](LICENSE).

The app bundles the Flutter engine and Dart packages under their own
licenses (BSD-3-Clause, MIT and others); they are listed in the app under
Settings → About → View licenses.
