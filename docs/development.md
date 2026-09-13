[日本語](development.ja.md)

# Development

This demo targets `madscient/openMSX_Y8960` commit `78469c4a0c2010f3252f1c55267f4036ccf8fd74`, C-BIOS MSX2+ (60 Hz), a Z80, and a normal V9958. Cartridge A contains the 16 KiB demo; cartridge B contains HRA_Y8960. In this machine, B is primary slot 2. Other slot configurations and physical hardware are not supported by this demo.

## Rebuild the demo

Install z88dk and Python 3, then run from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\build-demo.ps1 -Z88dk "path\to\z88dk"
```

Without `-Z88dk`, detection tries Z88DK, ZCCCFG, and PATH, then displays a folder chooser. An invalid explicit path stops the build. Only process-local environment variables change. Python generates the pitch tables, original melody and ADPCM percussion; z88dk compiles `src/main.c`. The script checks ROM size and BSS boundaries, writes `demo/Y8960-DEMO.rom`, and updates its hash in `config/versions.json`. Re-run verification after any change.

The generator uses note numbers and durations rather than sheet music. `melody` and `bass_notes` are the musical material. The BIOS JIFFY counter drives the timeline, including interrupts elapsed during drawing. One step lasts 15 ticks: 128 steps at 60 Hz is about 32 seconds. Section changes silence the previous voices. The display is SCREEN 5; meter heights are note activity, not audio measurements.

## Sound and machine assumptions

- BIOS WRTSLT enables OPLL at 0x7ff6 and the remaining selected I/O at 0x7fff in slot 2.
- SSGS: A0/A1, register groups 0x00/0x20 and pan registers 0x10–0x12.
- OPLL: 7C/7D and 7A/7B. OPL2/ADPCM-B: C0/C1 and C2/C3.
- Two original 2 KiB ADPCM samples occupy the start of shared sample RAM. The second OPL2 instance is used for its ADPCM voice, not a second FM bass.
- The fork's default Y8960 mixer output excludes built-in MSX audio. DCSG, SCC and hardware-timer playback are not demonstrated.
- MSX 8x8 font by 1re1 supplies the glyphs. C-BIOS supplies cartridge BIOS calls, but does not provide MSX BASIC or Disk BASIC for this cartridge demo.

## Emulator distribution

See the [maintainer publishing guide](publishing.md) for assets, builds, source delivery and release requirements.

## Packaging

`tests/validate-public.ps1` checks the allowlist, ROM hash, root BATs, script syntax and local document links. `scripts/package.ps1` creates a ZIP using that allowlist and refuses to overwrite an existing ZIP. Runtime, caches, logs and compiler intermediates are excluded. The source/demo ZIP alone does not contain the local emulator archive.

## Sources and licenses

Checked 2026-09-13:

- [Fork source and build instructions](https://github.com/madscient/openMSX_Y8960/tree/78469c4a0c2010f3252f1c55267f4036ccf8fd74)
- [Current fork notes](https://github.com/madscient/openMSX_Y8960/blob/78469c4a0c2010f3252f1c55267f4036ccf8fd74/doc/fork/README.md)
- [Cartridge wiring](https://github.com/madscient/openMSX_Y8960/blob/78469c4a0c2010f3252f1c55267f4036ccf8fd74/share/extensions/HRA_Y8960.xml)
- [openMSX 21.0 official package](https://github.com/openMSX/openMSX/releases/tag/RELEASE_21_0)
- [z88dk](https://github.com/z88dk/z88dk)

The demo and original generated sound data use this repository's MIT license. openMSX uses GPL; C-BIOS and other components retain their original licenses and notices. No FS-A1GT or commercial BIOS is used.

## Rendering and memory

The normal V9958 uses SCREEN 5 (256×212, 16 colors). The title reads `Y8960 TECH DEMO`. Palette entries are background 4 (RGB 1,2,3), foreground 15 (7,7,7), and shadow 1 (0,1,1), with components in 0–7. The shadow is offset one pixel down and right; foreground wins overlaps.

The visible page-0 bitmap occupies VRAM bytes 0–27135. HMMV fills backgrounds and progress; the CPU composes one row of pixels at a time and sends it to video memory (VRAM), using the Z80 OTIR instruction for repeated port output. Register 14 handles the 16 KiB boundary. CE polling restores status-register selection 0 before enabling interrupts. Each text call owns a full-width, nine-scanline region. A generated four-pixel blend table reduces rendering cost.

BSS must end before 0xC100. Addresses 0xC100–0xC107 are the test mailbox; 0xC200–0xC27F reserve a 128-byte scanline buffer. No heap is used. Playback copies pre-rendered text and processes audio before visual work. Elapsed JIFFY ticks maintain the timeline; playback is not sample-synchronous.

See [font sources and usage terms](../third-party/fonts/README.md).

## Audio-first updates and automated tests

The main loop accounts for elapsed JIFFY ticks and plays notes before drawing. Scene changes use `quiet → play → draw_slice`. This is a cooperative scheduler, not interrupt-driven audio.

At startup, all four shadowed captions are rendered into hidden VRAM page 1 (Y=256–383). PLAYING/MUTED/PAUSED use Y=384, 400 and 416. Playback uses HMMM to copy them without waiting synchronously for completion. Scene changes copy the prepared images. Text images are prepared at startup.

`draw_slice()` performs one visual job per loop: captions and status have priority, then eight bars and progress rotate. A busy VDP or a note due within one tick causes drawing to be skipped. Small HMMV fills for the progress indicator still wait for completion. Visual updates may lag under load instead of delaying playback with a large redraw.

With the runtime installed, run from the repository root (Python 3 is required for development tests):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\test-audio-timing.ps1
```

A fresh `logs/timing-timestamp/` contains 70 seconds of I/O tracing, PCM, the captured ROM hash and test results. `-Work` accepts a new output directory. openMSX I/O watchpoints measure actual SSG lead writes, rather than FPS or timing reported by the ROM.

Checks cover pitch/volume sequence, missing/duplicate notes, intervals, accumulated drift, scene boundaries and unscored mute gaps. Against the NTSC 15-VBlank step, interval error and drift must stay within two VBlanks, boundary error within one, and quiet-to-play within 10 ms. PCM around non-rest scene starts must not contain 20 ms of consecutive near-silence (RMS below 1). Failures propagate as PowerShell errors.

Negative controls for the analyzer:

```powershell
python tests\test-timing-analyzer.py logs\timing-timestamp
```

Copies of a passing capture are modified to remove one note, delay a boundary note by 100 ms, or insert 50 ms of PCM silence. All three must fail; the original CSV and WAV data are preserved; the analysis JSON is regenerated.

Lead timing is a proxy for the accompaniment update, not a guarantee for every register of every sound device. Host audio-buffer underruns, every type of audible click, real hardware and other CPUs are outside this test. It is a regression check for the pinned fork, C-BIOS MSX2+ and NTSC configuration.

The I/O check writes and reads 0x55 at B0h, an MSX-TIMER register. Playback is not driven by timer interrupts.

## Full test suite

Run from an installed repository with Python 3. The suite creates a new logs directory and does not overwrite earlier captures.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\run-all.ps1
```

It covers startup, controls, looping, audio, text/shadow, ADPCM RAM and isolated output, timing, negative controls and public files. For an individual ADPCM run use `scripts/launch.ps1 -TestScript tests/adpcm-solo.tcl -Work <new-directory>` followed by `python tests/analyze-adpcm.py <directory>`. The suite contains the corresponding audio and screen commands.

Capture verifies the executable and records its actual SHA-256. Analysis checks the recorded executable hash against the expected value and checks ROM and score hashes against current files. The commit ID is a configured identifier, not extracted from the executable. It independently detects the first PCM onset and requires alignment within 5 ms. Alongside digital silence, it detects levels below 10% of the local reference for 20 ms.

Installed emulator checks reject extra files absent from the receipt. This is not complete protection against an attacker modifying receipt.json itself. Failed setup removes only its own temporary extraction tree and preserves diagnostic logs; existing runtime is unchanged.

## Sprite event bars

Each of the eight event bars uses two vertically stacked 16×16 sprites: 16 sprites total, at most eight on a scanline. Seventeen height patterns are prepared at startup; each update writes two pattern-number bytes. No bitmap erase or fill is used for the bars. Update order and decay are retained, with one bar updated per loop.

VRAM 0x7400–0x74FF holds colors, 0x7600–0x7640 attributes and the terminator, and 0x7800–0x7A1F height patterns. These lie after the visible bitmap and before the page-1 caption cache at 0x8000. Additional sprites at the same height must respect the eight-per-scanline limit.

## Technical guides

Japanese and English editions each contain 30 pages.

- Japanese: [PDF](technical/Y8960-TECH-DEMO-technical.ja.pdf)
- English: [PDF](technical/Y8960-TECH-DEMO-technical.en.pdf)

## Technical PDF references by page

Use these implementation locations to check each explanation. Function names can be searched in the repository.

| Page | Topic | Implementation / reference |
|---|---|---|
| 1 | Cover and demo screen | `src/main.c`, [font sources](../third-party/fonts/README.md) |
| 2 | Enjoying Y8960 TECH DEMO | src/main.c; README.md |
| 3 | Starting the demo | scripts/common.ps1; config/versions.json |
| 4 | What is Y8960? | README.md; pinned fork doc/fork/README.md |
| 5 | How the sound generators work | src/main.c; scripts/generate-assets.py |
| 6 | PSG and SSG | Yamaha SSG manual; https://note.com/thara1129/n/n231074ae4be5 |
| 7 | OPLL and OPL2 | https://map.grauw.nl/resources/sound/yamaha_ym2413.pdf; https://www.ardent-tool.com/datasheets/Yamaha_YM3812.pdf |
| 8 | Why combine sound generators? | src/main.c: play() |
| 9 | Emulator features and demo coverage | fork doc/fork/README.md; src/main.c |
| 10 | Four sections, four layers | src/main.c: play(), cache_captions() |
| 11 | Writing notes as numbers | scripts/generate-assets.py; src/main.c |
| 12 | Music timing independent of drawing | src/main.c: ticks(), main() |
| 13 | Enabling sound I/O without unmapping ROM | src/main.c: enable_y8960(), audio_init(); fork RomY8960.cc |
| 14 | Sending register addresses and data | src/main.c: ssg(), fm(), opl() |
| 15 | SSGS pitch, volume and stereo | src/main.c; fork Y8960SSGS.cc, Y8960SsgCore.cc |
| 16 | OPLL melody and chords | src/main.c: note_fm(), play(); scripts/generate-assets.py |
| 17 | Designing an OPL2 bass sound | src/main.c: audio_init(), play(); scripts/generate-assets.py |
| 18 | Synthesizing percussion in Python | scripts/generate-assets.py: encode(), percussion generation |
| 19 | ADPCM encoding and shared RAM | tests/adpcm-solo.tcl; tests/analyze-adpcm.py |
| 20 | Playing ADPCM through two units | src/main.c: drum(); fork Y8960Adpcm.cc |
| 21 | Three-color text in SCREEN 5 | src/main.c: text(), blitrow(); scripts/generate-assets.py; font source |
| 22 | Drawing commands and interrupts | src/main.c: idle(), copy_band(), draw_slice(), ready() |
| 23 | The display update schedule | src/main.c: draw_slice(), main(), rect(); 9/59.923 = approximately 150ms |
| 24 | ROM, CPU RAM, VRAM and sound RAM | src/main.c; scripts/build-demo.ps1; tests/*.tcl |
| 25 | Controls and stopping playback | src/main.c: keyrow(), quiet(), main(); tests/audio-controls.tcl |
| 26 | Setup and release files | docs/publishing.md; scripts/setup.ps1; config/versions.json |
| 27 | Rebuilding and checking release files | scripts/build-demo.ps1; tests/validate-public.ps1; scripts/package.ps1 |
| 28 | What the automated tests check | docs/timing-results.json; docs/results.json; tests/analyze-timing.py |
| 29 | Detecting audio interruptions | tests/test-audio-timing.ps1; tests/test-timing-analyzer.py |
| 30 | Sources and acknowledgments | github.com/madscient/openMSX_Y8960; third-party/fonts/README.md |
