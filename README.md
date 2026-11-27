# FORGE OS v1.4 — by Blacksmith Games

FORGE OS turns a gaming PC into a console. It boots straight into a liquid-glass console UI that has a golden particle intro, shows your installed Steam games with their official art, and switches to game mode when you play so the game gets the GPU, CPU and RAM.

---

## What's inside

| Folder | What it is |
|---|---|
| `shell/` | The console UI (Godot 4). Includes the intro, Home, Library, Media, Settings, widgets, the quick menu, benchmarks and the on-screen keyboard. |
| `system/` | The parts that run the console: the session supervisor, the Gamescope launcher, the root helper and gaming tweaks. |
| `installer/` | The all-in-one installer that runs from the USB. |
| `iso/` | Builds the bootable installer USB image. |
| `.github/workflows/` | Builds the ISO on GitHub's servers for free. |

---

## Step 1: Build the installer image (one time, about 20 minutes, free)

You can't build the image on Windows, so GitHub builds it for you.

1. Make a free account at **github.com**.
2. Click **+** (top right), then **New repository**. Name it `forge-os`, set it to **Private**, and click **Create**.
3. Click **uploading an existing file**. Drag **everything inside** the `forge-os` folder into the page, including the hidden `.github` folder. In Windows Explorer, turn on View › Show › Hidden items to see it. Click **Commit changes**.
4. Open the **Actions** tab. Click **Build FORGE OS ISO**, then **Run workflow**.
5. Wait for the green tick (around 15–25 minutes). Open the finished run and download **forge-os-iso** at the bottom. Unzip it to get `forge-os-….iso`.

## Step 2: Make the USB

1. Install **balenaEtcher** (free) on your main PC.
2. Choose **Flash from file** and pick the `.iso`. Choose your USB stick (8 GB or more; it will be erased) and click **Flash**.

## Installing next to your files (no spare drive needed)

1. In Windows, right-click **Start**, open **Disk Management**, right-click a drive and choose **Shrink Volume**. Free at least **40 GB** (50 GB or more recommended). A black **Unallocated** block appears; leave it empty.
2. **Turn off Fast Startup:** open Control Panel › Power Options › "Choose what the power buttons do" › "Change settings that are currently unavailable" › untick **Turn on fast startup** › Save. Without this, Windows leaves its drives "locked" and FORGE can't open them.
3. In the installer, pick that drive and choose **"Install into the free space — keeps all your files"**.
4. Your other Windows drives appear in FORGE under **/mnt/** (in Add a game, they're listed as drives). The Windows system drive is read-only, so FORGE can never damage Windows.

## Step 3: Install on the console PC

1. Plug in the USB, Ethernet (or have your Wi-Fi password ready) and a keyboard.
2. Turn the PC on and press the boot-menu key, usually **F11**, **F12** or **F8**. Pick the USB (UEFI).
   - In the BIOS: **UEFI on, CSM off, Secure Boot off.** NVIDIA drivers won't load with Secure Boot on.
3. The installer starts by itself. Connect to the internet, choose the drive (**it gets erased**), set a password and wait.
4. Remove the USB and restart. The console boots into the intro, then Home.
5. Sign in to Steam once when it appears. You can scan the QR code with the Steam app on your phone. Install games from the Steam app on your phone or another PC, and they appear on Home.

---

## Updating FORGE (no reinstall, the whole OS)

From v1.4, one update brings **everything**: the FORGE app, its system parts (root helper,
drives, tuning, services) and every OS package (kernel, drivers, Steam, Mesa). Packages are
pinned to one dated Arch Linux snapshot that you tested, so every console gets exactly the same
versions and nothing changes behind your back.

1. Change what you want and upload it to your GitHub repository.
2. Raise the version in `shell/scripts/core/tokens.gd` (`OS_VERSION`), for example `1.4.1`.
3. Optional, for newer drivers/Steam/kernel: set `system/os-snapshot` to a newer date
   (`YYYY/MM/DD`, any day up to yesterday). **Test that ISO or update on your own console
   first**, then release it. Leave it unchanged to keep the same packages.
4. On GitHub: **Releases › Draft a new release**, create a tag matching the version (`v1.4.1`),
   **Publish**. The same tag also builds a new ISO in Actions.
5. Each console shows **Update available**. Settings › System › Install update: it updates
   everything, then restarts (a full reboot only if the kernel or drivers changed).
   **Undo the last update** restores the previous app, system parts *and* package versions.

Your repository must be **public** for consoles to see updates (or add a GitHub access token
in Settings › System › Access token). **Repair system** reinstalls the system parts and puts
every package back to the tested versions.

---

## Controls

| Controller | Keyboard | Action |
|---|---|---|
| D-pad / left stick | Arrows / WASD | Move |
| A | Enter / Space | Play / Select |
| B | Esc | Back |
| X | F | Game details / delete a letter |
| Y | Tab | Search / Sort / Space |
| LB / RB | Q / E | Switch tabs |
| LT / RT | PgUp / PgDn | Jump |
| Guide | G / Home | Quick menu (in a game: the FORGE in-game menu) |
| View + Menu | — | Also opens the menu (if Steam grabs the Guide button) |
| Share, or Guide + X | F12 | Screenshot |
| Guide + Y | F11 | Save a clip (turn on clips in Settings › Capture) |
| Start | M | Quick menu / keyboard Done |

Hold a direction and the scrolling speeds up the longer you hold it.

---

## Preview it on your Windows PC (optional)

1. Download **Godot 4.4** or newer (the standard version, not .NET) from godotengine.org.
2. Open Godot, click **Import**, pick `shell/project.godot`, then press **F5**.
3. It finds your Windows Steam library and shows your real games and art. Press Esc/Alt+F4 to quit. (Power, Wi-Fi and similar actions only work on the console.)

---

## New in v1.4

- **Full-OS updates** (see above): app, system parts and all packages, pinned to a tested
  snapshot, with a real Undo.
- **FSR for every game**: Settings › Performance (or the Guide / in-game menu): **Off
  (Fidelity, default)**, **Balanced** (83% + FSR) or **Performance** (67% + FSR). Per game in
  the game's settings. Works on every Steam game and every game you added, even ones with no
  FSR option. Applies from the next game start. If a game has its own FSR/XeSS, use that *or*
  FORGE's, not both (they'd upscale twice). Steam games get `/usr/lib/forge/forge-fsr %command%`
  in their launch options automatically; anything you had there is kept.
- **Always maximum performance**: CPU and GPU at full speed all the time (no power modes).
- **AMD tuning** (NVIDIA still supported): NTSYNC, SteamOS's LAVD game scheduler, SteamOS
  kernel settings, compressed RAM swap, 16 GB shader cache. Older NVIDIA cards (GTX 900/1000)
  get the open-source driver: it works, but an AMD card is far better on FORGE.
- **New glass**, closer to modern liquid glass: clear, lens-like, thin light on the corners.
  Three styles in Settings › Appearance: **Liquid** (default), **Frosted**, **Matte**.
  Contour glow is now off by default; when on it starts at 80% brightness.
- **New wallpapers**: Nebula, Satin, Caustics, Northern Lights, Orbs (plus Silk Ribbons), all in
  your colour palette, or **your own photo** (any drive or USB stick).
- **Library**: focus starts on the top row (filters, **+**, sort); press down for your games.
- **Stability**: fixed a crash every time FORGE closed or restarted (since v1.0).
- The Windows edition is kept as a backup in `archive/`.

## New in v1.2

- **In-game menu:** press Guide while playing. You get Resume, Screenshot, Save clip and Quit game, plus volume, performance, overlay and this game's FPS limit. The game pauses while the menu is open (turn that off for online games in Settings › Capture).
- **First-boot setup**, **profiles** ("Who's playing?"), **rest mode** (power button), and **downloads** with speed and time left.
- **Games you own but haven't installed:** add your free Steam Web API key (steamcommunity.com/dev/apikey) in Settings › Library. This also turns on **achievements** on each game's page and "Achievement unlocked" pop-ups.
- **Epic & GOG:** Settings › Library & stores › Open Heroic. Sign in and install there, and the games appear in FORGE.
- **Classics:** put game files you own in `~/ROMs/<system>/`, or use Settings › Library › Import games from USB. Supported: NES, SNES, N64, GB/GBC/GBA, DS, Mega Drive, PS1, PSP. FORGE doesn't download games or BIOS files.
- **Per-game settings:** on a game's page, the gear button. Proton version and launch options apply after Steam restarts ("Apply now").
- **Media:** screenshots and clips. Press X to copy one to a USB drive, or Y to copy all of them.
- **Recovery mode:** hold **Space** while the console starts, then pick **FORGE OS Recovery**. It can reset the display, undo an update, repair the system, reset settings, sign out of Steam, set up Wi-Fi or open Big Picture.
- **Settings › System:** Visual quality preset, Reset console (factory reset; games stay installed).

**Steam and the Guide button:** if pressing Guide in a game also opens Steam's overlay, open Steam's settings › Controller and turn off "Guide button focuses Steam". You can also use View + Menu to open the FORGE menu.

## New in v1.3: add your own games

- In **Library**, press up to reach the top row and choose **+** (or go to Settings › Library & stores › Add a game).
- Browse to the game on this console, a second drive or a USB stick, and pick its `.exe` (Windows) or `.sh` / `.AppImage` / program file (Linux).
- FORGE suggests the name, finds the official art on Steam's store, and runs Windows games with **Proton** through umu-launcher. UMU-Proton downloads by itself the first time; Settings › Library & stores › Prepare Proton now does it ahead of time. You can also pick **GE-Proton** or any Proton Steam installed.
- Every game shows where it comes from: **Steam, Epic, GOG, Local disk, USB** or the console name. A game on an unplugged USB drive shows **Drive not connected**.
- Edit or remove a game you added with the gear button on its page. Removing never deletes your files.

See `ROADMAP.md` for what's planned next.

## New in v1.3.4: fixes from the first real install

- **Drives open on their own.** Every drive is mounted at start-up under /mnt (read-write; the Windows system drive stays read-only). No terminal commands. If Windows left a drive locked, FORGE still opens it, and the log at /var/log/forge-drives.log says what happened.
- **Setup works with any input.** Get online starts on Continue, no fake Wi-Fi entries, the name box shows what you type, and a real keyboard types straight into it.
- **One overlay in games.** FORGE's own counter no longer shows on top of the game's.
- **First Windows game:** a notice explains that Proton is downloading (a few minutes, once).
- **Library:** an empty library starts on the + button, rows only scroll when needed, cards never cover the filter buttons, and the mouse works (click, scroll wheel, click a tab).
- **Intro:** waits until your monitor is showing a picture, then plays in full.

## Game mode

When a game starts, the console UI stops drawing (no wallpaper, glass or animation) and drops to 4 updates per second. Steam keeps running in the background. The power profile stays on **Max performance** unless you change it. When you quit the game, the UI drops back in.

## Benchmarks

Settings › Performance:
- **Overlay:** Off / FPS only / Detailed / Everything. This is the in-game MangoHud overlay; Shift+F12 toggles it.
- **Record every game session:** logs every frame.
- **Benchmark results:** average FPS, 1% and 0.1% lows, min/max, frame-time average and 99th percentile, frame pacing jitter, stutter count, GPU/CPU load, temperatures, clocks, VRAM, power, a frame-time graph, an FPS distribution, and comparison with your last run of the same game.
- **Live system monitor** and a **console UI stress test**.

## If something goes wrong

- The UI restarts itself if it crashes. After 3 quick crashes it switches to **Steam Big Picture** so you're never stuck. Exit Steam from Big Picture to return to FORGE.
- If the display mode you picked doesn't work, the session falls back to 1080p 60 Hz after a few failed tries.
- Press **Ctrl+Alt+F2** for a text login (user `forge` with the password you set).
- Logs:
  - `~/.local/share/forge/logs/` (session, shell, steam)
  - `/var/log/forge-install.log`
- The boot menu has a **safe mode** entry. Hold Space while the PC starts to see it.
