#!/system/bin/sh
#
# dump-boot.sh — back up the Retroid Pocket 6's stock firmware before rooting.
#
# HOW TO RUN: on the handheld, go to
#   Handheld Settings -> Advanced -> "Run script as Root"
# and paste in this whole file.
#
# It creates a folder called rp6-dump in internal storage. Copy that folder to
# your PC. It only reads your partitions - nothing is modified.
#
# NOTE IF YOU EDIT THIS: that Retroid menu runs each line separately, so nothing
# carries between lines (no variables, no cd, no multi-line if/for blocks). Every
# line below is written to stand on its own.

mkdir -p /sdcard/rp6-dump

# Record which build and slot these came from.
getprop ro.build.display.id > /sdcard/rp6-dump/build.txt
getprop ro.boot.slot_suffix >> /sdcard/rp6-dump/build.txt
date >> /sdcard/rp6-dump/build.txt

# Copy the partitions. Names differ between builds, so try them all and skip any
# that don't exist on this unit.
for p in init_boot init_boot_a init_boot_b boot boot_a boot_b vbmeta vbmeta_a vbmeta_b; do if [ -e /dev/block/by-name/$p ]; then dd if=/dev/block/by-name/$p of=/sdcard/rp6-dump/$p.img; fi; done

# Checksums, and a quick signature check so a bad copy is obvious.
sha256sum /sdcard/rp6-dump/*.img > /sdcard/rp6-dump/SHA256SUMS
for f in /sdcard/rp6-dump/*.img; do echo "$f: $(dd if=$f bs=8 count=1 2>/dev/null)"; done > /sdcard/rp6-dump/magic.txt

chmod 0644 /sdcard/rp6-dump/*

ls -l /sdcard/rp6-dump/

# Now connect USB, set the handheld to File Transfer mode, and drag the rp6-dump
# folder to your PC. Sizes should be roughly: init_boot 8 MB, boot 96 MB.
