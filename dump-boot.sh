#!/system/bin/sh
#
# dump-boot.sh — back up the Retroid Pocket 6's stock boot partitions BEFORE rooting.
#
# Retroid publishes no factory firmware and its OTA server offers nothing, so the
# images this produces are the ONLY stock recovery source that will exist for your
# device. Run this first. Keep the output on another machine.
#
# HOW TO RUN: Handheld Settings -> Advanced -> "Run script as Root", and paste the
# whole file in.
#
# ⚠️ That feature ships EACH LINE to a root daemon as its own `sh -c`. Nothing
#    carries between lines — no variables, no `cd`, no multi-line if/for blocks,
#    no `set -e`. Every line below is therefore independently valid and complete.
#    Keep it that way if you edit this. (Comments and blank lines are harmless
#    no-ops.)
#
# Read-only with respect to the partitions: this only ever uses them as dd INPUT.
# The only writes are new files under /sdcard/rp6-dump.

# --- where everything lands -------------------------------------------------
mkdir -p /sdcard/rp6-dump

# --- provenance: which build and slot these images actually came from --------
# Without this a dump is much less useful later; boot_a and boot_b are often
# different builds, and you need to know which slot was live.
getprop ro.build.display.id > /sdcard/rp6-dump/build.txt
getprop ro.boot.slot_suffix >> /sdcard/rp6-dump/build.txt
getprop ro.product.device >> /sdcard/rp6-dump/build.txt
date >> /sdcard/rp6-dump/build.txt

# --- record the partition layout before touching it -------------------------
# Also tells you which of the names below actually exist on your unit.
ls -l /dev/block/by-name/ > /sdcard/rp6-dump/partitions.txt

# --- dump ------------------------------------------------------------------
# A/B naming varies: some builds expose bare `boot`/`init_boot`, others only the
# slot-suffixed `boot_a`/`boot_b`. This tries every plausible name and silently
# skips the ones that do not exist, so it is correct either way.
for p in init_boot init_boot_a init_boot_b boot boot_a boot_b vbmeta vbmeta_a vbmeta_b; do if [ -e /dev/block/by-name/$p ]; then dd if=/dev/block/by-name/$p of=/sdcard/rp6-dump/$p.img; fi; done

# --- checksums, computed on-device so you can verify the copy off-device ----
sha256sum /sdcard/rp6-dump/*.img > /sdcard/rp6-dump/SHA256SUMS

# --- sanity check: boot images must start with ANDROID!, vbmeta with AVB0 ---
# An all-zero or truncated dump is worse than no dump, because you will trust it.
for f in /sdcard/rp6-dump/*.img; do echo "$f: $(dd if=$f bs=8 count=1 2>/dev/null)"; done > /sdcard/rp6-dump/magic.txt

# --- make sure it is all readable over adb/MTP ------------------------------
chmod 0644 /sdcard/rp6-dump/*

# --- show the result --------------------------------------------------------
ls -l /sdcard/rp6-dump/
cat /sdcard/rp6-dump/magic.txt

# Then, from your computer:
#   adb pull /sdcard/rp6-dump ./rp6-dump
#   cd rp6-dump && sha256sum -c SHA256SUMS
#
# Verify before trusting: every *.img must be non-zero and the right size
# (init_boot ~8 MB, boot ~96 MB, vbmeta 64 KB), boot images must show ANDROID!
# and vbmeta AVB0 in magic.txt. Copy the directory to a second machine.
