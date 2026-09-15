# Rooting the Retroid Pocket 6 (GKI 2.0 / Android 13)

Magisk on a Retroid Pocket 6 (`kalama`, Snapdragon 8 Gen 2, Android 13, build
`RP6_V1.0.0.406_20260616_145755DE_user`), written up after doing it — including the two mistakes
that cost the most time, one of which produces a device that looks **completely bricked** while
nothing has actually been written to it.

No wipe is required if your bootloader is already unlocked. Unlocking is the step that wipes.

> **Read the two ⚠️ sections before touching fastboot.** They are the whole point of this guide.
> Generic "root any Android phone" tutorials get both of them wrong on GKI 2.0 devices.

---

## ⚠️ 1. Back up your stock images FIRST — there is no factory image to fall back on

**Retroid publishes no factory firmware, and the ADUPS OTA server offers nothing.** If you corrupt
`init_boot` without a backup, there is no download that will save you. This is not the usual
situation where a stock ROM is a search away.

You can dump the partitions *before* you have root, using Retroid's own built-in root-script
feature: **Handheld Settings → Advanced → "Run script as Root"**.

Use **[`dump-boot.sh`](dump-boot.sh)** from this repo — paste the whole file into that box. It dumps
every boot-related partition, records the build and active slot, writes checksums, and verifies the
image magic bytes.

> **Why it is written the way it is:** that feature ships **each line** to a root daemon as its own
> `sh -c`. Nothing carries between lines — no variables, no `cd`, no `set -e`, no multi-line
> `if`/`for` blocks. Every line in `dump-boot.sh` is independently valid and complete, and a
> single-line `for` loop is used where iteration is needed. Keep that property if you edit it.

It is read-only with respect to your partitions — they are only ever used as `dd` **input**. The
only writes are new files under `/sdcard/rp6-dump`.

Then, from your computer:

```bash
adb pull /sdcard/rp6-dump ./rp6-dump
cd rp6-dump && sha256sum -c SHA256SUMS
```

**Verify before you trust it.** A truncated or all-zero dump is worse than no dump, because you will
rely on it in exactly the moment you cannot afford to. Check `magic.txt` — boot images must show
`ANDROID!`, `vbmeta` must show `AVB0` — and check the sizes: `init_boot` ~8 MB, `boot` ~96 MB,
`vbmeta` 64 KB. Then **copy the directory to a second machine.**

A/B naming varies between builds (bare `boot`/`init_boot` vs slot-suffixed `boot_a`/`boot_b`), so the
script tries every plausible name and skips the ones that do not exist. On this device `boot.img` was
byte-identical to `boot_b.img` while `boot_a.img` differed — slot A held an older build, which makes
it a genuine rollback target.

---

## 2. Patch `init_boot.img`, not `boot.img`

This device is **GKI 2.0**, so the ramdisk lives in its own `init_boot` partition:

```
init_boot.img   kernel_size=0           ramdisk_size=2015865
boot_b.img      kernel_size=56048128    ramdisk_size=0
```

Magisk patches the **ramdisk**, so `init_boot.img` is the file you feed it. Patching `boot.img` on a
GKI 2.0 device is the classic wasted evening.

1. Install the Magisk app on the device (30.7+; 31.0 tested).
2. Magisk → Install → **Select and Patch a File** → pick `init_boot.img`.
3. Pull the result back: `adb pull /sdcard/Download/magisk_patched_*.img .`

Verify which partition an image really is, rather than trusting a filename:

```bash
python3 -c "import struct;d=open('init_boot.img','rb').read(32);print('kernel_size',struct.unpack('<I',d[8:12])[0])"
```

`kernel_size 0` = ramdisk-only = `init_boot`. Nonzero = it is a `boot` image.

---

## ⚠️ 3. Never `fastboot boot` a patched init_boot — it cannot work, and it fakes a brick

Almost every rooting guide says to test-boot the patched image first:

```bash
fastboot boot magisk_patched_init_boot.img   # ❌ DO NOT DO THIS ON GKI 2.0
```

**On GKI 2.0 this can never succeed.** `fastboot boot` requires a complete bootable image, and
`init_boot` has `kernel_size=0` — you are handing the bootloader a null kernel. There is no
RAM-only dry run for a patched `init_boot`. Full stop.

**The dangerous part is the side effect.** A failed `fastboot boot` counts as a failed boot attempt
against your *current slot*. Enough of them and the bootloader marks that slot `unbootable` and
silently falls back to the other one. On this device that meant landing on slot `_a` — an older
build — against a `/data` written by `_b`. Result: a frozen boot logo that looks exactly like a
bricked device, **despite nothing having been flashed**.

A slot flip is invisible unless you go looking:

```bash
fastboot getvar current-slot
fastboot getvar slot-unbootable:a
fastboot getvar slot-unbootable:b
```

**Recovery** — restores the slot, clears the unbootable flag, resets the retry counter, and does
**not** touch `/data`:

```bash
fastboot set_active b
```

So your real options are: flash directly with a verified stock image ready for rollback (what this
guide does), or splice a hybrid test image (stock kernel + patched ramdisk) — which only tests an
artifact you will never actually flash.

---

## 4. Flash

**fastboot does not work over wireless adb.** Use a USB cable.

```bash
adb reboot bootloader
fastboot getvar current-slot          # note this; flashing targets the active slot
fastboot flash init_boot magisk_patched_init_boot.img
fastboot reboot
```

Leave `vbmeta` stock. Do **not** run `fastboot flashing lock` afterwards — relocking with a modified
boot chain is a reliable way to hard-brick.

Confirm it took: the Magisk app should report itself installed, and `su` should work. Note that on
this device `su` is at **`/debug_ramdisk/su`** and is *not* on adb shell's `PATH`.

---

## 5. Expected after rooting

- **A red "device is corrupt" AVB warning on every cold boot, needing a Power press.** This is
  expected with stock `vbmeta` and a modified boot chain. Not a fault.
- **Escape hatch:** hold **Volume Down** during boot for safe mode, which disables all Magisk
  modules. This is how you recover from a module that breaks booting. Note it also switches off
  benign modules (ad-blocking `hosts`, etc.) — re-enable them deliberately afterwards.

---

## Recovery / rollback

```bash
fastboot flash init_boot init_boot.img     # restore the stock ramdisk (un-root)
fastboot flash boot     boot_b.img         # restore the stock kernel, slot b
fastboot set_active a                      # or fall back to the other slot
```

## OTA updates while rooted

A/B + Virtual A/B, so updates do not wipe. Take the OTA, then **before rebooting**, use
Magisk → Install → **"Install to Inactive Slot (After OTA)"**. If an OTA refuses to apply, flash the
stock `init_boot.img` back, update, then re-patch.

---

## Gotchas that cost real time

- **Root access to `/data/adb` is intermittently denied while magiskd is under strain** — the *same*
  command fails, then succeeds seconds later. Retry in a loop before concluding you have a
  permissions problem. A single failed `cp` here sent one session down a long, wrong detour.
- **Toggling a module in the Magisk app strips the execute bit** from scripts under `/data/adb`
  (everything gets normalised to `0660`), and Magisk **silently skips** non-executable
  `post-fs-data.d` / `service.d` scripts. If you rely on such a script, re-`chmod 755` it after any
  module toggle — or package it as a real Magisk module (`post-fs-data.sh` / `service.sh`), which
  Magisk runs without needing +x.
- **`zygisk mappings = 0` in a child process is normal** — Zygisk unmaps itself after injecting.
  Look for the module's own `.so`, not `libzygisk.so`.
- This ROM's `surfaceflinger` SIGSEGVs once per boot in its ANGLE build
  (`libGLESv2_angle.so`, fault addr `0x18`), with tombstones predating rooting. It respawns
  instantly and is **not** caused by root — do not chase it.

## Zygisk modules

If you are installing Zygisk modules, be aware that Magisk's **built-in** Zygisk wedged `magiskd`
permanently with one module on this device (leaking a thread and an fd every 10 s until no app could
launch). Replacing it with [NeoZygisk](https://github.com/JingMatrix/NeoZygisk) — which runs its own
daemon — fixed it. If you do that, **Magisk's own Zygisk must be turned OFF**, or NeoZygisk silently
no-ops.

A worked example, including how to verify a module is actually doing anything, is in
[openfg-retroid-pocket-6](https://github.com/schindlershadow/openfg-retroid-pocket-6).

---

## Tested on

Retroid Pocket 6, Snapdragon 8 Gen 2 (QCS8550 / `kalama`), Adreno 740, Android 13 (API 33), ROM
`RP6_V1.0.0.406_20260616_145755DE_user`, bootloader already unlocked, active slot `_b`. Magisk 30.7
initially, later 31.0.

**No warranty.** Rooting and flashing can permanently damage a device, and on this one there is no
vendor factory image to restore from. Back up your stock partitions before you start, and do not
skip the two ⚠️ sections.
