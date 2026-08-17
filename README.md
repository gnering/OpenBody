<p align="center">
  <img src="assets/banner.png" alt="OpenBody" width="100%">
</p>

# OpenBody

**English** · [Português](README.pt-BR.md)

**A native macOS app to read, manage, print and e-mail InBody bioimpedance body-composition exams.**

---

> **Not affiliated with, authorized by, or endorsed by InBody Co., Ltd.**
> This is an independent interoperability project. "InBody" is a trademark of its owner. Use with your own scale and your own data, under your own responsibility.

---

## Motivation

I am a sports medicine physician. My clinic has had an InBody 770 for ten years, and its software only runs on Windows. Since everything else in the clinic runs on Macs, a PC sat in a corner with a single job: talking to the scale. I wrote OpenBody to retire that PC.

## What it is

InBody scales ship with a Windows-only program to read the scale, store patients, and print/e-mail body-composition result sheets. There is no Mac version.

**OpenBody** is a native macOS app (SwiftUI) that does the same job on a Mac:

- Reads the exams from the scale's own database (`.mdb`), or live from the scale.
- Renders the **result sheets** in the layout patients and doctors already know, ready to print and e-mail.
- Manages patients, prints, e-mails the sheets as PDF, backs up the database.

It exists so a clinic running on Macs doesn't need a Windows machine just to use its InBody scale.

## Supported models

| Model | Result sheets |
|-------|---------------|
| **InBody 120** | Ported (not yet tested) |
| **InBody 270** | Ported (not yet tested) |
| **InBody 370S** | Ported (not yet tested) |
| **InBody 770** | Ported and tested (adult, body water, children, body-composition history) |
| 570, 970, J, R, S10, BWA | Not started (the 770 is a good template) |

## Current status & limitations

This is a working app used in a real clinic, but it is **not feature-complete**. Honest state:

- Data comes from importing the scale's **`.mdb`** database (or a live scale connection). The app does not replace the scale firmware.
- Live connection to the scale (network / Bluetooth / USB / serial cable) is implemented, but needs testing across different clinic setups.
- A few Setup functions still display an honest "not built yet" notice (tag/group history editing; the vendor's cloud login).
- Some sheet types are still open: Body Type, Compare, Nutrition, Visceral Fat, Interpretation.
- macOS only. Built and run on Apple Silicon.

## Features

Beyond what the original software does, OpenBody adds features it never had:

- **Exams sent through the Mac's native e-mail**: opens your Mail app with the exam PDF attached, ready to send, no setup. An optional SMTP-server screen is there for whoever wants their own server.
- **Cloud backup** by linking an iCloud Drive, Google Drive, OneDrive or similar folder
- **Patient merge** across different scales and clinics: automatic match by ID, with a review step on conflicts (merges, never deletes)

Plus the day-to-day essentials:

- Patient list with search, sorting and Excel-style adjustable columns
- Live InBody test over WiFi / serial
- **Result sheets**: InBody sheet, Body Water, Children, Body Composition History
- **Health Report** with per-metric evolution graphs (value + date per exam)
- Printing (with per-clinic alignment offset)
- Import from the scale's `.mdb` database (merges, never deletes)
- Database backup (full copy) + automatic backup on launch
- Data restoration from an `.mdb` file or a backup `.zip` (always merges)
- CSV / Excel export, group registration import
- Complete settings (country, units, date format, printer, custom logo, e-mail account, reference ranges, etc.)
- Optional login screen and screen auto-lock

## Requirements

- macOS on Apple Silicon
- An InBody scale and/or its `.mdb` database file to import from

## Install (end users)

Download `OpenBody.dmg` from **Releases**, open it, and drag **OpenBody** to **Applications**. It is signed and notarized by Apple, so it opens normally, no security workaround needed.

## Building from source

```bash
swift build --product OpenBody -c release
```

Reading `.mdb` files relies on **mdbtools** binaries, bundled in the app's `Contents/Helpers`. The project builds and runs complete with no extra configuration.

## Architecture

- **Swift 6 / SwiftUI**, built with **SwiftPM**.
- `InBodyKit`: the scale communication layer (network/serial), written from scratch in Swift.
- `InBodyApp`: the app (UI, sheet rendering, database, services).
- `inbody`: a small CLI used during development.
- Result sheets were validated against at least 17,000 real exams, exam by exam.
- InBody databases are Access `.mdb` files, mirrored into SQLite locally; some fields are AES-encrypted.

## How to contribute

Contributions are very welcome. High-value areas:

1. **Testing the ported models**: the 120 / 270 / 370S sheets are ported but not yet validated against real exams (the 770 is done and tested; it is a good template).
2. **More sheet types**: Body Type, Compare, Nutrition, Visceral Fat, Interpretation, etc.
3. **More scale models**: the 570 / 970 / J / R / S10 / BWA are still open.
4. **Testing the live scale connection** across different InBody models and networks.
5. **Intel Mac** build and testing.
6. Translations beyond pt-BR / en.

Open an issue describing what you want to work on, or send a pull request. Please keep the "no mute click" rule: every button either works or clearly says what's missing.

## License

[MIT](LICENSE). Use, modify and redistribute freely, keeping the copyright notice.

## Support this project

**Every donation goes entirely to [GACC Vale](https://hospitalgaccvale.org.br)**, a hospital in São José dos Campos, Brazil, dedicated to the diagnosis and treatment of children and adolescents (0 to 18 years old) with suspected cancer and onco-hematological diseases.

[![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-0070ba?style=for-the-badge&logo=paypal)](https://www.paypal.com/donate/?hosted_button_id=G5BZG5KEWYC9N)
