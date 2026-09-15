# Rooting the Retroid Pocket 6

Magisk root on a Retroid Pocket 6 (Android 13). Bootloader must already be unlocked — unlocking is
the step that wipes your data; everything here does not.

Most of this is taps and drag-and-drop. Only the final flashing step needs a terminal.

## What you'll need

| | |
|---|---|
| [Magisk](https://github.com/topjohnwu/Magisk/releases) | `Magisk-v31.0.apk` — install on the handheld |
| [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools) | `adb` + `fastboot` for your PC |
| [`dump-boot.sh`](dump-boot.sh) | from this repo |
| A USB cable | fastboot does not work wirelessly |

macOS users also need [Android File Transfer](https://www.android.com/filetransfer/) to see the
handheld's files.

---

## 1. Back up your stock firmware

> **Don't skip this.** Retroid publishes no factory image, so this backup is the only way to undo
> anything later.

1. Open [`dump-boot.sh`](dump-boot.sh) and copy its contents (use the **Copy raw file** button).
2. On the handheld: **Handheld Settings → Advanced → "Run script as Root"**.
3. Paste it in and run it.

It creates a folder called **`rp6-dump`** in internal storage. It only reads your partitions — it
doesn't change anything.

## 2. Copy the backup to your PC

Plug in the USB cable, then swipe down on the handheld and set USB mode to **File Transfer**.

The handheld now appears in your file manager. Open **Internal shared storage → `rp6-dump`** and drag
it somewhere safe on your PC.

**Quick check:** `init_boot.img` should be about 8 MB and `boot.img` about 96 MB. If anything is
0 bytes, run the script again.

## 3. Patch the image

1. Drag `init_boot.img` from your backup into the handheld's **Download** folder.
2. Install the [Magisk](https://github.com/topjohnwu/Magisk/releases) APK on the handheld and open it.
3. Tap **Install → Select and Patch a File** → choose `init_boot.img`.
4. Magisk saves a `magisk_patched_*.img` into **Download**. Drag it back to your PC.

> Patch `init_boot.img`, not `boot.img`. This device keeps the part Magisk needs in a separate
> `init_boot` partition, and patching `boot.img` silently does nothing.

## 4. Flash it

Unzip [Platform-Tools](https://developer.android.com/tools/releases/platform-tools) and put your
`magisk_patched_*.img` in that same folder. Then open a terminal there:

- **Windows** — click the address bar in File Explorer, type `cmd`, press Enter
- **macOS / Linux** — right-click the folder → *Open Terminal Here*

```
adb reboot bootloader
fastboot flash init_boot magisk_patched_init_boot.img
fastboot reboot
```

Use whatever filename Magisk actually produced. Open the Magisk app afterwards — it should now show
as installed. Done.

> ⚠️ **Do not run `fastboot boot`** on the patched file, even though many guides suggest it. It
> cannot work on this device and repeated attempts make it boot to a frozen logo that looks bricked.
> If that happens, `fastboot set_active b` fixes it and your data is safe.

---

## Good to know

- A **red "device is corrupt" screen appears on every cold boot** — press Power to continue. This is
  normal after rooting and is not a problem.
- Hold **Volume Down** while booting for safe mode, which disables all Magisk modules. Use this if a
  module ever stops the device booting.
- **OTA updates:** take the update, then *before rebooting* use Magisk → Install → **Install to
  Inactive Slot (After OTA)**.

## Undo it

```
fastboot flash init_boot init_boot.img
```

Uses the `init_boot.img` from your step 1 backup.

## Next: Zygisk modules

If you're installing Zygisk modules, use [NeoZygisk](https://github.com/JingMatrix/NeoZygisk/releases)
rather than Magisk's built-in Zygisk, and **turn Magisk's own Zygisk off** in settings — otherwise
NeoZygisk silently does nothing.

For a worked example, see
**[openfg-retroid-pocket-6](https://github.com/schindlershadow/openfg-retroid-pocket-6)** — frame
generation on this device.

---

Tested on a Retroid Pocket 6 (`kalama`), Android 13, build `RP6_V1.0.0.406_20260616_145755DE_user`,
Magisk 30.7 and 31.0.

No warranty — flashing can damage a device, and there's no vendor factory image for this one. Back up
first.
