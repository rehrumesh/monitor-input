# monitor-input

A tiny CLI to switch the input source of a **Dell U2724DE** monitor from the command
line on macOS, using DDC/CI (no menu fumbling with the monitor's joystick).

Built for a setup with a laptop on **USB-C** and a Mac mini on **HDMI**, but the values
are easy to change at the top of the script for other inputs/monitors.

## Install

```sh
curl -fsSL https://rehrumesh.github.io/monitor-input/install.sh | bash
```

This installs [`m1ddc`](https://github.com/waydabber/m1ddc) (via Homebrew) if needed,
drops the `monitor-input` command into your Homebrew bin, and adds shell aliases.

> Requires [Homebrew](https://brew.sh) and an Apple Silicon Mac.

## Usage

```sh
monitor-input laptop     # switch Dell to the laptop   (USB-C)
monitor-input macmini    # switch Dell to the Mac mini (HDMI)
monitor-input toggle     # flip to the other input
monitor-input status     # show the current input
```

Aliases added to `~/.zshrc`: `mlaptop`, `mmini`, `mtoggle`, `mstatus`.

The labels are **absolute** — `monitor-input macmini` always selects the HDMI input
regardless of which machine you run it from, so installing on both machines lets you
hand the screen back and forth from either keyboard.

## How it works

It uses `m1ddc` to send the monitor a DDC/CI command on VCP code `0x60` (input source).
Confirmed values for the Dell U2724DE:

| Input            | VCP `0x60` value |
| ---------------- | ---------------- |
| USB-C (laptop)   | `0x19` (25)      |
| HDMI (Mac mini)  | `0x11` (17)      |

To adapt it, edit `MONITOR_MATCH`, `USBC_VALUE`, and `HDMI_VALUE` at the top of the
`monitor-input` script.

## Manual install

Clone and run the installer locally:

```sh
git clone https://github.com/rehrumesh/monitor-input.git
cd monitor-input
bash install.sh
```
