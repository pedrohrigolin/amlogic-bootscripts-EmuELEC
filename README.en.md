# Amlogic Boot Scripts for EmuELEC

**Language / Idioma:** [🟢 English](README.en.md) | [Português](README.md)

## Table of Contents
- [Overview](#overview)
- [Setup](#setup)
- [Customizing `aml_autoscript`](#customizing-aml_autoscript)
- [Supported Devices](#supported-devices)
- [Troubleshooting — Running `aml_autoscript` Manually](#troubleshooting--running-aml_autoscript-manually)
- [How It Works Internally](#how-it-works-internally)

---

## Overview

This project is a **fusion of the [amlogic-bootscripts-Armbian](https://github.com/projetotvbox/amlogic-bootscripts-Armbian) scripts with EmuELEC's boot script**. It boots EmuELEC from a USB drive using the box's factory u-boot, and brings along what the Armbian scripts offer, such as the u-boot bootlogo and booting mainline Linux that uses autoscripts. It should also work with CoreELEC derivatives, but it has **only been tested on EmuELEC**.

The code is derived from devmfc's work, this project's changes, and EmuELEC's original code.

**Why it exists**

EmuELEC's original boot script starts with `defenv`, which resets all u-boot variables to factory defaults. That wipes `start_autoscript`, `start_mmc_autoscript`, `start_usb_autoscript`, and `start_emmc_autoscript`, exactly the variables an installed mainline Linux (such as Armbian) relies on to be found by the bootloader.

The result: **even without installing EmuELEC, just booting from the USB drive to try it out**, the box loses the ability to start the mainline Linux on its eMMC. It is still physically there, but the bootloader no longer knows how to find it.

The scripts in this project are a customization of EmuELEC's bootscript that recreates those variables after `defenv`. That way EmuELEC boots normally and mainline keeps working.

**Differences from the Armbian project**

| | Armbian | EmuELEC |
|---|---|---|
| System that boots | Armbian (mainline) | EmuELEC |
| `cvbs_boot` | `0` (disabled) | `1` (enabled) |
| How it works | Writes the boot route and boots Armbian | Runs **only once**; the three scripts are **aliases** (see [How It Works Internally](#how-it-works-internally)) |

> **Prerequisite:** the vendor u-boot must be running on eMMC. If your box was reflashed with a different bootloader, restore the stock Android image using the [Amlogic USB Burning Tool](https://androidmtk.com/download-amlogic-usb-burning-tool) before continuing.

> ⚠️ **Android no longer boots from eMMC.** As in the Armbian project, the script removes the Android variables from u-boot, including `storeboot`. To go back to Android, restore the stock image with the Amlogic USB Burning Tool.

---

## Setup

### Step 1 — Download the EmuELEC image

Download the EmuELEC image for your box from the [releases page](https://github.com/EmuELEC/EmuELEC/releases). The scripts were tested on version 4.8, but most likely work on any version.

---

### Step 2 — Prepare the installation media

Flash the image to the USB drive using **[balenaEtcher](https://etcher.balena.io/)** — the simplest option — or via command line:

```bash
sudo dd if=EmuELEC_*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

> ⚠️ Replace `/dev/sdX` with your USB drive. Use `lsblk` or `fdisk -l` to confirm the correct device. With `dd`, writing to the wrong device will erase its data without any confirmation prompt.

Mount the `EMUELEC` partition of the USB drive (FAT32, usually the first one) and copy the three scripts, overwriting the existing files:

- **[aml_autoscript](https://github.com/projetotvbox/amlogic-bootscripts-EmuELEC/blob/main/aml_autoscript)**
- **[s905_autoscript](https://github.com/projetotvbox/amlogic-bootscripts-EmuELEC/blob/main/s905_autoscript)**
- **[emmc_autoscript](https://github.com/projetotvbox/amlogic-bootscripts-EmuELEC/blob/main/emmc_autoscript)**

> The three files are **identical**, just with different names. You need to copy all three: each name covers a different situation in the box's u-boot (see [How It Works Internally](#how-it-works-internally)).

```bash
git clone https://github.com/projetotvbox/amlogic-bootscripts-EmuELEC.git

# Adjust /dev/sdX1 as needed (use lsblk to find the EMUELEC partition)
sudo mount /dev/sdX1 /mnt/emuelec

sudo cp amlogic-bootscripts-EmuELEC/aml_autoscript /mnt/emuelec/
sudo cp amlogic-bootscripts-EmuELEC/s905_autoscript /mnt/emuelec/
sudo cp amlogic-bootscripts-EmuELEC/emmc_autoscript /mnt/emuelec/

sudo umount /mnt/emuelec
```

> **Preparing multiple USB drives or distributing your own images?** You can modify the `.img` file directly before flashing, using `losetup`:
>
> ```bash
> sudo losetup -fP EmuELEC_*.img
> lsblk | grep loop          # identify the FAT32 partition (usually loop0p1)
> sudo mkdir -p /mnt/emuelec
> sudo mount /dev/loop0p1 /mnt/emuelec
> ```
>
> Copy the three scripts normally to `/mnt/emuelec/` and, only at the end, unmount and flash:
>
> ```bash
> sudo umount /mnt/emuelec
> sudo losetup -d /dev/loop0
> sudo dd if=EmuELEC_*.img of=/dev/sdX bs=4M status=progress conv=fsync
> ```

---

### Step 3 — Boot from USB

1. Power off the box.
2. Insert the USB drive.
3. Power on the box. Depending on the u-boot it has today, the script is found in a different way:
   - **Box with factory u-boot:** press and **hold** the reset button, power on the box and keep holding for approximately **7 seconds**. This runs `aml_autoscript`.
   - **Box that already has mainline Linux with autoscripts:** no reset needed. The u-boot already looks for `s905_autoscript` (on USB or SD) and `emmc_autoscript` (on eMMC), and the script runs on its own.
4. The script saves the variables (`saveenv`) and boots EmuELEC right away.

> If the box does not boot EmuELEC automatically, try again holding the reset button: some firmwares require it to boot from USB. If reset has no effect, see [Troubleshooting](#troubleshooting--running-aml_autoscript-manually).

---

### Step 4 — Later boots

The script **runs only once**: EmuELEC does not use autoscripts to boot. Once the variables are saved, the `bootcmd` stored in u-boot loads EmuELEC before any autoscript, with no reset and no need for the scripts:

- **With the EmuELEC USB drive connected:** the box boots EmuELEC.
- **Without the drive:** the box tries EmuELEC on SD and eMMC and, if it finds none, moves on to `start_autoscript`, which looks for a mainline Linux (such as Armbian) on SD, USB, and eMMC. This is why the mainline on eMMC boots normally again when you remove the drive.

> The mainline Linux stays protected, as long as nothing is written in its place on the eMMC.

---

## Customizing `aml_autoscript`

This project's `aml_autoscript` is derived from devmfc's code, this project's changes, and EmuELEC's original code. Like the Armbian project's, it removes dozens of variables that only exist for Android (recovery, burning, Dolby Vision, A/B slots, etc.) and keeps the u-boot environment clean, making debugging and understanding the code easier. If you want to keep using Android, use the original autoscripts by **devmfc**.

The editable source is `aml_autoscript.command`. The `aml_autoscript`, `s905_autoscript`, and `emmc_autoscript` files (no extension) are the compiled version, the ones that go on the `EMUELEC` partition.

> **Any change only takes effect after you recompile the script and run it again on the box** (by holding reset, or manually via serial console — see the troubleshooting section). The variables are only written by `saveenv` during the run.

> ⚠️ **Since the three files are aliases, every change must be applied to all three.** Compile once and generate the other two as copies (see below).

### Workflow for testing your changes

1. Edit `aml_autoscript.command`.
2. [Recompile the script](#recompiling-the-script) and generate the three files.
3. Copy all three to the root of the USB drive's `EMUELEC` partition.
4. Run it on the box in one of two ways:
   - **Reset button**, as in [Step 3](#step-3--boot-from-usb). The first time, this works with the factory u-boot; afterwards, it only works if you have [re-enabled the button](#reusing-another-aml_autoscript).
   - **Manually, over the serial console**, as in [Running `aml_autoscript` Manually](#troubleshooting--running-aml_autoscript-manually).

> 💡 **Tip:** while you are creating or tweaking a custom `aml_autoscript`, **keep the reset button enabled**. That way you can test without needing the serial console on every attempt. Only once you have the final version, and if you want to, disable the button.

---

### Recompiling the script

```bash
sudo apt install u-boot-tools   # provides mkimage (Debian/Ubuntu)
mkimage -C none -A arm -T script -d aml_autoscript.command aml_autoscript

# The three files are identical: generate the aliases as copies
cp aml_autoscript s905_autoscript
cp aml_autoscript emmc_autoscript
```

Copy the three generated files to the `EMUELEC` partition, overwriting the existing ones.

---

### Reusing another `aml_autoscript`

By default, this feature comes **disabled**: u-boot no longer looks for a new `aml_autoscript` at power-on, which keeps boot simpler and more predictable.

> 💡 **If you are going to customize `aml_autoscript`, enable this option from your first custom version** and only disable it once you have the final version. To disable it again, recompile with those lines commented out and the `setenv update` line active (the repository default).

To re-enable it, edit `aml_autoscript.command`: **uncomment** the four lines in the indicated block and **comment out** the `setenv update` line right below it.

```bash
# Uncomment these lines:
setenv check_update_button ${upgrade_key}
setenv update 'run load_aml_autoscript'
setenv load_aml_autoscript 'if mmcinfo; then if fatload mmc 0 1020000 aml_autoscript; then autoscr 1020000; fi; fi; if usb start; then for usbdev in 0 1 2 3; do if fatload usb ${usbdev} 1020000 aml_autoscript; then autoscr 1020000; fi; done; fi'
setenv bootcmd 'run check_update_button; if test ${bootfromnand} = 1; then setenv bootfromnand 0; saveenv; else run bootfromsd; run bootfromusb; run bootfromemmc; fi; run start_autoscript'

# And comment out this one (further down in the file):
#setenv update
```

With this, `bootcmd` checks the reset button again and `load_aml_autoscript` looks for an `aml_autoscript` on SD and USB. Recompile and run the script to apply.

---

### U-Boot bootlogo on EmuELEC

`aml_autoscript` injects a bootlogo function into U-Boot, something normally only Android provides. The logo shows as soon as the box powers on, before the kernel loads.

All you need to do is place a file named **`bootlogo.bmp`** on **partition 1 (the FAT `EMUELEC` partition)** of the media. U-Boot looks for the file in this order and uses the first one found:

1. USB drive (ports 0 to 3)
2. SD card
3. eMMC

If no file is found, the box simply boots without a logo. To use a different name, change the `bootlogo_filename` variable in `aml_autoscript.command` (without the `.bmp` extension) and recompile.

**Accepted format**

The box's U-Boot only displays BMPs in a specific format. In most cases it is this one (RGB565, 16 bits):

```bash
file bootlogo.bmp
# bootlogo.bmp: PC bitmap, Windows 3.x format, 320 x 388 x 16, 3 compression, image size 248320, cbSize 248386, bits offset 66
```

**Converting a PNG or JPEG to the correct format**

```bash
ffmpeg -i bootlogo.png -pix_fmt rgb565 -compression_level 0 bootlogo.bmp
```

> ⚠️ **This format is the most common, not a guaranteed standard.** Each U-Boot may have its own quirks (resolution, color depth, etc.). If the logo does not show or looks distorted, you will need to adapt the conversion to your case — there is no single solution that covers every box.

---

### Showing the bootlogo on CVBS output

Unlike the Armbian project, here the CVBS output comes **enabled** (`cvbs_boot` set to `1`). If the box is configured for CVBS output and has that hardware, the bootlogo shows on it. To disable it:

1. In `aml_autoscript.command`, change:
   ```bash
   setenv cvbs_boot 1
   ```
   to:
   ```bash
   setenv cvbs_boot 0
   ```
2. [Recompile the script](#recompiling-the-script) and generate the three files.
3. Copy the files to the `EMUELEC` partition and run the script again on the box.

> ⚠️ **CVBS video standard.** `aml_autoscript` ships with the mode set to `480cvbs` (525 lines / 60 Hz), the format accepted in Brazil and the United States:
>
> ```bash
> setenv cvbsmode 480cvbs
> ```
>
> If your TV uses a 625-line / 50 Hz standard (common in Europe, for example), change it to `576cvbs`, recompile, and run the script again:
>
> ```bash
> setenv cvbsmode 576cvbs
> ```

---

### Background color before the bootlogo (blue or green screen)

Depending on the firmware, some boxes show a background color between video initialization and the logo being displayed, while U-Boot searches for `bootlogo.bmp`. In testing, the default (Option A) worked well on the **HTV H8** and the **ATV A5**. The **BTV B9**, however, showed a **green** screen with the default and needed a different variant. And that B9 variant, when used on the A5, produced a **blue** screen: what fixes one box can make another worse.

`aml_autoscript.command` ships with four `init_display` variants (options **A**, **B**, **C**, and **D**). All of them still run `osd open; osd clear` before displaying the logo (inside `logo_show`). The difference is whether the OSD is **also** opened and cleared before and/or after `vout`:

| Option | When the OSD is opened and cleared |
|--------|------------------------------------|
| A *(default)* | Only in `logo_show` |
| B | Before `vout` |
| C | After `vout` |
| D | Before and after `vout` |

> ⚠️ **This was discovered through empirical testing, not by analyzing the U-Boot source code.** Behavior depends on each box's firmware: what fixes one may change nothing on another. No single option works on every box.

One (unconfirmed) hypothesis is that `osd clear` only zeroes the OSD framebuffer, leaving it transparent instead of black, and the color you see is the video pipeline's background, defined by the vendor's U-Boot. That is why no OSD command solves this portably.

**How to pick the option for your box**

1. Start with **Option A**, the default.
2. If the background color bothers you, try **B** and then **C**.
3. **D** is only worth trying if neither of the others helps, or if the result varies between boots.
4. If an option does not improve anything, go back to A.

To switch, edit `aml_autoscript.command`, leave **only one** option uncommented, [recompile](#recompiling-the-script), and run the script again.

**Testing an option before adopting it**

Typing long commands straight into the U-Boot prompt tends to cause errors. Instead, create a test autoscript, for example `test_autoscript.command`, containing the `init_display` you want to try:

```bash
setenv init_display '<content of the chosen option>'
run init_display
```

[Compile](#recompiling-the-script) the script (`mkimage -C none -A arm -T script -d test_autoscript.command test_autoscript`), copy `test_autoscript` to the root of the USB drive, and run it in one of two ways:

- **Manually, over the serial console** (see [Running `aml_autoscript` Manually](#troubleshooting--running-aml_autoscript-manually)), swapping the file name:
  ```bash
  usb start
  fatload usb 0 $loadaddr test_autoscript
  autoscr $loadaddr
  ```
- **With the reset button:** the button loads a file named `aml_autoscript`, so in that case the compiled file must have that name, and the button must be enabled (see [Reusing another `aml_autoscript`](#reusing-another-aml_autoscript)).

This test filters out bad options, but does not prove an option is safe in `preboot`, which may behave differently from a script run after U-Boot has booted.

---

## Supported Devices

**✅ Tested & Working:**
- S905X4 (HTV H8), S905X3, with EmuELEC 4.8

**❓ Untested:**
- Other Amlogic SoCs, other EmuELEC versions (likely compatible), and CoreELEC derivatives

**Mainline Linux preserved:** Armbian (any version with compatible bootscripts).

All files and source files are available on [Github](https://github.com/projetotvbox/amlogic-bootscripts-EmuELEC).

---

## Troubleshooting — Running `aml_autoscript` Manually

> ⚠️ **This section is for when holding the reset button does not run `aml_autoscript`.** If the main method worked, you do not need this.
>
> You no longer need to type U-Boot variables by hand: `aml_autoscript` already does all the configuration. The only thing left is running it manually by interrupting U-Boot over the serial console.

### Prerequisites

- **Serial TTL adapter (3.3V UART):** ⚠️ **Use 3.3V only. 5V will damage the device.** Requires soldering TX/RX/GND pads on the board.
- **Serial terminal software:** PuTTY, Minicom, or picocom.
- **A USB drive formatted as FAT32** with the `aml_autoscript` file in its root.

### 🔒 Back Up eMMC Before Anything Else

`aml_autoscript` wipes the factory U-Boot environment (`defenv`) and removes the Android variables. If there is any chance you will want to go back, back up first (from an ARM Linux system running from the USB drive):

```bash
# Compressed backup (a 16GB backup becomes 2-4GB)
sudo dd if=/dev/mmcblkX bs=1M status=progress | gzip -c > backup_emmc_full.img.gz

# To restore:
# gunzip -c backup_emmc_full.img.gz | sudo dd of=/dev/mmcblkX bs=1M status=progress
```

### Step 1 — Connect the serial cable

Solder TX, RX, and GND to the device's UART pads and connect to your PC.

### Step 2 — Open the serial console

```bash
ls -la /dev/ttyUSB*

picocom -b 115200 /dev/ttyUSB0
# or:
minicom -D /dev/ttyUSB0 -b 115200
```

### Step 3 — Interrupt U-Boot

With the USB drive connected, power on the device and quickly press `Ctrl+C` or `Enter` to interrupt U-Boot before it boots.

### Step 4 — Run `aml_autoscript`

In the U-Boot console, run:

```bash
usb start
fatload usb 0 $loadaddr aml_autoscript
autoscr $loadaddr
```

> ⚠️ **Keep only 1 USB drive connected** during this procedure. The command above reads the first USB device (`0`).

The script rewrites the variables, runs `saveenv`, and then tries to boot EmuELEC. If it finds none, it moves on to `start_autoscript` (mainline Linux). From then on, you will no longer need the serial console or the reset button.

---

## How It Works Internally

For those who want to understand what happens under the hood.

### The three files are aliases

In the original concept of autoscripts, as in the Armbian project, these three files are **not** the same: `aml_autoscript` installs the new boot route once, `s905_autoscript` loads the system from USB or SD, and `emmc_autoscript` loads the one on eMMC.

**With EmuELEC that changes**, because it does not use autoscripts to boot the system. So `aml_autoscript`, `s905_autoscript`, and `emmc_autoscript` are here **the same file**, just with different names: they are aliases. Each name exists only so the script gets found, since a different u-boot looks for a different name:

- **`aml_autoscript`** — loaded by the factory u-boot when you hold the reset button while powering on the box.
- **`s905_autoscript`** — searched for on USB and SD by a u-boot that has already been customized to boot mainline with autoscripts.
- **`emmc_autoscript`** — searched for on eMMC by that same kind of u-boot.

This way the script runs regardless of the u-boot the box has today. Since the script runs only once and saves the variables, after that `bootcmd` loads EmuELEC before any autoscript. Since they are copies, **every change must be made to all three**.

### What the script does

Runs **only once**. Since the variables are written with `saveenv`, the result persists across later boots. In order, it:

1. **Restores the factory environment** (`defenv`, `env default -a`, and `saveenv`), starting from a clean base. This is the step that, in EmuELEC's original script, wiped the mainline variables.
2. **Defines the EmuELEC variables**: `cfgloadsd`, `cfgloadusb`, and `cfgloademmc` look for the `cfgload` file on SD, USB, and the eMMC partitions; `bootfromsd`, `bootfromusb`, and `bootfromemmc` load `kernel.img` and `dtb.img` (falling back to the box's own dtb via `store dtb read`) and start with `bootm`.
3. **Recreates the mainline Linux boot route** (`start_autoscript`): SD card → USB → eMMC, looking for Armbian's `s905_autoscript` and `emmc_autoscript`. **This is the fix** that stops EmuELEC from leaving the box unable to boot mainline.
4. **Sets `bootcmd`**: tries EmuELEC (SD → USB → eMMC) and, if none boots, moves on to `start_autoscript`, that is, to mainline Linux.
5. **Sets up the bootlogo and video output** (`init_display`, run from `preboot`): picks the output mode (HDMI or CVBS), looks for `bootlogo.bmp` on USB, SD, and eMMC, and displays it. The position of `osd open; osd clear` relative to `vout` can be adjusted in four variants (A to D), explained in [Background color before the bootlogo](#background-color-before-the-bootlogo-blue-or-green-screen).
6. **Removes the Android variables** (recovery, burning, Dolby Vision, networking, A/B slots, etc.), keeping the environment lean.
7. **Saves everything** with `saveenv` and starts booting right away, running the same routines as `bootcmd`.

---

Feito com 🐧 no IFSP Salto · Tecnologia a serviço da educação pública
