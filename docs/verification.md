[日本語](verification.ja.md)

# Verification — 0.5.0

Checked 2026-09-13 on Windows 10 22H2 x64, PowerShell 5.1, the pinned Y8960 fork, C-BIOS MSX2+, Z80 and NTSC. ROM/emulator hashes are in [detailed results (JSON)](results.json).

- Current demo ROM: startup, four sections, looping, pause/mute/resume/reset/stop and pixel-exact text/shadow checks PASS.
- 70 seconds, 280 notes and eight boundaries PASS. Maximum quiet-to-play time: 8.507 ms; maximum boundary interval error: 8.063 ms.
- Negative controls detect missing notes, 100 ms delays and 50 ms PCM silence.
- Six seconds of PCM per section: zero clipping. Mute/stop converge to silence.

See [timing results](timing-results.json) and [test instructions](development.md#audio-first-updates-and-automated-tests). Bars show note events, not measured sound levels.

Physical Y8960, Windows 11, a clean OS VM and cache-free installation from public URLs are unverified. These tests do not detect host audio-buffer underruns or every audible click. See [publishing prerequisites](publishing.md).

The full suite was rerun with the current ROM. Maximum interval error is 23.002 ms and drift is 23.003 ms, both below the 33.376 ms limit. Boundary and quiet-to-play limits are 16.688 and 10 ms. The test tolerates roughly one frame of delay; it does not guarantee exact per-frame scheduling. PCM/I/O onset difference is 0.291 ms (limit 5 ms). Relative-level dropouts and identity mismatches were detected by negative controls. The included scripts reproduce the 4,096-byte ADPCM comparison and isolated recording analysis. Physical speaker playback was not tested.

The final ROM passes the nine-line text comparison plus checks of all 16 sprite positions and colors, 17 height patterns, and VDP configuration. The bar region of the bitmap is also checked to contain only the background.

## 0.5.0 release preparation recheck (2026-09-13)

Installed the emulator ZIP with added notices in isolation and rechecked startup, controls, looping, audio, text, sprites, ADPCM and note timing. All eight negative controls passed. A temporary-directory permission error initially interrupted the negative controls; that part was rerun with normal permissions. The executable and ROM hashes are unchanged from the existing measurements.

Converted the 45 additional C++ tone parameter sets back to eight-byte format: all 45 match the original wiki. This is a technical comparison, not a license compatibility determination.

Release URLs are configured, but publication and downloads from public URLs have not been tested. An independent rebuild from the corresponding-source ZIP has not been performed.

## Setup path checks

On Windows 10 22H2 with Windows PowerShell 5.1, the root BAT files were run from outside a fresh folder containing Japanese characters and spaces. Setup from the verified local emulator ZIP, repeat setup and startup checks passed. Launch without a runtime, a changed ZIP and a connection failure with an empty cache were rejected. Public downloads and physical speaker playback were not tested in this run. See [Detailed test results (JSON)](results.json).
