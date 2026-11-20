<p align="center">
  <img src="docs/assets/icone.png" width="112" alt="">
</p>

<h1 align="center">Aero IPTV</h1>

<p align="center">
  <strong>Your channels, movies and series on TV and PC, in an interface made of glass and light.</strong><br>
  For Android TV, Fire TV and Windows. Free, no account, no ads.
</p>

<p align="center">
  <a href="https://github.com/B2TN/aero-iptv/issues/new?template=feedback.yml"><img src="docs/assets/bouton-avis.svg" alt="Share your feedback" height="68"></a>
</p>
<p align="center">
  <a href="https://github.com/B2TN/aero-iptv/issues/new?template=bug.yml"><img src="docs/assets/bouton-bug.svg" alt="Report a bug" height="48"></a>
  &nbsp;
  <a href="https://github.com/B2TN/aero-iptv/issues/new?template=idea.yml"><img src="docs/assets/bouton-idee.svg" alt="Suggest an idea" height="48"></a>
</p>

<p align="center">
  <img src="docs/captures/0.3.0/01_home.png" alt="Aero IPTV home screen: a full-frame featured title, then rows of series and movies" width="860">
</p>

Aero IPTV is a player for your own IPTV subscription, designed first for the TV remote. Its look comes from the Frutiger Aero style of the late 2000s: deep blue, glass panels, ribbons of light. Underneath, it works like the streaming apps you already know: a home screen with what's popular, one page per title, and playback that picks up where you left off.

## Install

Pick your device. The download starts right away.

| Device | File | |
|---|---|---|
| Windows 10 or 11 PC (64-bit) | Installer, `.exe` | <a href="https://github.com/B2TN/aero-iptv/releases/latest/download/aero-iptv-windows-x64-setup.exe"><img src="docs/assets/bouton-windows.svg" alt="Download for Windows" height="44"></a> |
| Fire TV Stick, Android TVs and boxes | `.apk`, the same file for all | <a href="https://github.com/B2TN/aero-iptv/releases/latest/download/aero-iptv-fire-tv-armeabi-v7a.apk"><img src="docs/assets/bouton-firetv.svg" alt="Download for Fire TV Stick" height="44"></a> <a href="https://github.com/B2TN/aero-iptv/releases/latest/download/aero-iptv-fire-tv-armeabi-v7a.apk"><img src="docs/assets/bouton-androidtv.svg" alt="Download for Android TV" height="44"></a> |

Prefer a portable copy on Windows? Take [`aero-iptv-windows-x64.zip`](https://github.com/B2TN/aero-iptv/releases/latest/download/aero-iptv-windows-x64.zip). All versions are on the [releases page](https://github.com/B2TN/aero-iptv/releases).

<details>
<summary><strong>Install on Windows</strong></summary>

1. Run `aero-iptv-windows-x64-setup.exe`. It installs Aero IPTV in your user profile, without administrator rights, and adds it to the Start menu.
2. If Windows shows "Windows protected your PC", click **More info**, then **Run anyway**. This message appears for any app without a paid signature.

The portable `.zip` works too: extract it, keep all the files together, and run `aero_iptv.exe`. Both share the same playlist and history.

</details>

<details>
<summary><strong>Install on Fire TV</strong></summary>

1. On your Fire TV, install the free **Downloader** app from the Appstore.
2. In **Settings**, **My Fire TV**, **Developer options**, allow apps from unknown sources for Downloader.
3. In Downloader, enter the address of the **Fire TV Stick** button above, then install the file.

</details>

<details>
<summary><strong>Install on Android TV</strong></summary>

1. Copy the `.apk` file to a USB drive, or download it with an app such as Downloader.
2. Open it with a file manager, then allow the installation when the TV asks.

The same file works on 32-bit and 64-bit TVs.

</details>

## Add your playlist

Aero IPTV is a player: it provides **no channels and no content**. You need a playlist or a subscription from a provider.

On the first launch, a short tutorial helps you add it. You can enter:

- an **Xtream Codes** login: the server address, your username and your password;
- or an **M3U** playlist address, with an optional XMLTV guide address.

The app then imports your catalog. A large catalog takes a few minutes the first time; after that, a daily sync only fetches what changed. **Settings**, **Playlist**, **Last sync** shows how long each step took.

You can skip the tutorial at any time and open it again from **Settings**, **About**.

## What's inside

- **A home screen like a streaming app**: a full-frame featured title, "Continue watching", and what's popular in your country among the titles you can actually watch.
- **One page per movie or series**: the large image, summary and genre from your provider, every version and language in one place, and the next announced episodes with their air dates.
- **Continue watching that keeps up**: a series you've caught up on stays at the end of the row while new episodes are announced, with "Next episode in 3 days".
- **Live TV** by country and group, with what's on now.
- **Full playback controls**: audio tracks, subtitles, 30-second jumps, and **Skip intro** and **Next episode** during the intro and the end credits.
- **Translated subtitles** in the language of your choice, with a free DeepL key.
- **Real remote-control navigation**, plus mouse support on Windows.
- **Your choice of grouping**: series versions, movie versions and channel qualities can each be grouped or listed one by one.
- **Single-connection subscriptions** are supported.
- **Five languages**: English, French, Spanish, German and Arabic.

## Preview

<table>
  <tr>
    <td><img src="docs/captures/0.3.0/02_series.png" alt="Series page: the large image, the summary, then seasons and episodes"></td>
    <td><img src="docs/captures/0.3.0/03_movie.png" alt="Movie page with its large image and play button"></td>
  </tr>
  <tr>
    <td><img src="docs/captures/0.3.0/04_player.png" alt="Player with the title, time bar and controls"></td>
    <td><img src="docs/captures/0.3.0/05_channels.png" alt="Live TV: groups on the left, channels and what's on now on the right"></td>
  </tr>
  <tr>
    <td><img src="docs/captures/0.3.0/06_settings.png" alt="Settings, with categories on the left"></td>
    <td><img src="docs/captures/0.3.0/07_performance.png" alt="The home screen in Performance mode"></td>
  </tr>
</table>

## Updates

Aero IPTV checks GitHub for a new version when it starts, then once a day. When one is out, a banner appears at the top right: **Install** downloads it and updates the app, keeping your playlist, favorites and watch history. On Android TV and Fire TV, the system asks once for permission to install apps.

With **Settings**, **Updates**, **Beta updates** turned on, the app also offers test versions before they're released.

## Performance mode

Small devices such as the Fire TV Stick have little memory and a modest graphics chip. Performance mode keeps the same screens, but without blur, animation or blended effects: the glass becomes solid, the background stays still and is decoded at a lower resolution.

It turns itself on for low-memory devices. You can switch it on or off in **Settings**, **Appearance**.

## FAQ

<details>
<summary><strong>Does Aero IPTV come with channels?</strong></summary>

No. It only plays the playlist or subscription you add. Aero IPTV does not provide, host or recommend any content.

</details>

<details>
<summary><strong>The first import is long. Is that normal?</strong></summary>

Yes, for large catalogs: hundreds of thousands of titles take a few minutes the first time. The daily sync after that only processes what changed. **Settings**, **Playlist**, **Last sync** shows where the time went.

</details>

<details>
<summary><strong>Why is the popular list different from my friend's?</strong></summary>

It depends on your country and on your playlist: the app only shows popular titles you can actually watch. The country comes from your IP address; you can pick another one in **Settings**, **Catalog**, which helps with a VPN.

</details>

<details>
<summary><strong>A movie or a channel won't start.</strong></summary>

Try another version from its page or from the player, or **External player** to open it in another app. If it still fails, [report a bug](https://github.com/B2TN/aero-iptv/issues/new?template=bug.yml) with the device and what you see, but never your playlist address or login.

</details>

<details>
<summary><strong>Subtitles aren't translated.</strong></summary>

Translation needs a free [DeepL](https://www.deepl.com/your-account/keys) key, entered in **Settings**, **Subtitles**. Subtitles come from the video itself: the app downloads none, and subtitles drawn as images (PGS, VobSub) contain no text to translate.

</details>

<details>
<summary><strong>Can I use a mouse and keyboard?</strong></summary>

On Windows, yes: click anything, scroll the rows, and use the arrow keys, Enter and Escape like a remote.

</details>

## Your feedback shapes the app

Aero IPTV is a young project built in spare time. Every bit of feedback counts: a first impression, a confusing screen, a channel that won't start, an idea. All you need is a free GitHub account, and the form takes a minute.

<p align="center">
  <a href="https://github.com/B2TN/aero-iptv/issues/new?template=feedback.yml"><img src="docs/assets/bouton-avis.svg" alt="Share your feedback" height="68"></a>
</p>
<p align="center">
  <a href="https://github.com/B2TN/aero-iptv/issues/new?template=bug.yml"><img src="docs/assets/bouton-bug.svg" alt="Report a bug" height="48"></a>
  &nbsp;
  <a href="https://github.com/B2TN/aero-iptv/issues/new?template=idea.yml"><img src="docs/assets/bouton-idee.svg" alt="Suggest an idea" height="48"></a>
</p>

Feedback is public: **never post your username, password or playlist address.**

## Your data

- Your login details stay on your device, encrypted by the system vault (DPAPI on Windows, Keystore on Android), and are only sent to your provider.
- No account, no ads, no analytics.
- The app only contacts your provider, the services listed here, and DeepL if you've entered a key.
- Once a day, the popular titles come from [TMDB](https://www.themoviedb.org), or from Apple's public charts in builds without a TMDB key. They only receive a country code.
- To know that country, the app asks [country.is](https://country.is) once which country your IP address is in, and keeps only the country code. You can also pick the country in **Settings**.
- To find the intro and the end credits of an episode, it asks [TheIntroDB](https://theintrodb.org), [IntroDB](https://introdb.app) and [TVmaze](https://www.tvmaze.com). They only receive the series title, its public IDs, and the season and episode numbers.
- To list the upcoming episodes of a series, it asks TVmaze with the series title only.

## Content and rights

Aero IPTV does not provide, host or recommend any content. You are responsible for what you open with it: only use sources you have the right to watch. Playlist links are not accepted in feedback.

## For developers

The project is written in Flutter, with media_kit (libmpv) for playback and Drift for the local database. Everything is in the [development guide](docs/DEVELOPMENT.md).

## License

© 2026 B2TN. Aero IPTV's code is released under the [GPL v3 license](LICENSE): you can use, modify and redistribute it, as long as your versions stay open under the same license. The Inter and Noto Sans Arabic typefaces are under the SIL Open Font License. See the [third-party licenses](docs/THIRD_PARTY_LICENSES.md).
