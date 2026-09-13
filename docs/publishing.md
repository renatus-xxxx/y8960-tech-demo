[日本語](publishing.ja.md)

# Publishing 0.5.0 (maintainers)

0.5.0 is the first public release. Attach these three assets to GitHub Releases v0.5.0:

1. `y8960-tech-demo-0.5.0.zip`: the user package, with two root BATs (setup and launch), demo ROM, sources and documentation.
2. `openmsx-y8960-78469c4-windows-x64.zip`: the pinned emulator, C-BIOS, configuration and notices downloaded by setup.
3. `openmsx-y8960-78469c4-source.zip`: corresponding emulator sources, dependency sources, patches and build instructions.

## Package preparation

Download destinations are pinned in config/versions.json. Configuring a URL does not publish an asset or verify downloading it. Publication and tests using public URLs are separate steps.

Preserve the tone authors, source and original CC BY-SA wording without inferring a version. Contacting the authors is not a prerequisite for preparation. Keep the fork's tone tables unchanged and add OPLL-NOTICE.txt to both emulator and source ZIPs. This notice alone does not resolve the unspecified version or compatibility of embedding the data in the executable. See [third-party components](licenses.md).

The corresponding-source ZIP retains the original source archive, dependency sources and build materials including patches. The executable is not rebuilt in this update; only notices are added. An independent rebuild from the source ZIP has not been performed.

## Release sequence

1. Check the names, contents and SHA-256 of all three assets against config/versions.json and the release work record.
2. Review both READMEs, notices and corresponding sources.
3. After approval, commit, push, create the v0.5.0 tag and Release, and attach all three assets. Do not do this during preparation.
4. Download each public asset and check its SHA-256.
5. Extract the application ZIP into a local folder without runtime/cache; run setup-y8960.bat, then launch-y8960-tech-demo.bat.
6. Check startup, controls and audio. Record the public-download test separately from earlier local-ZIP tests.

## Verify and rebuild the application ZIP

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate-public.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\package.ps1
```

The first checks the allowlist, Git-visible files, ROM hash, BAT count, PowerShell syntax and documentation links. The second creates the dist ZIP only from allowlisted files and compares every file hash. Existing ZIPs are not overwritten. These commands do not decide legal compliance or verify public downloads.

## Build and sources

Follow README.txt and build-local.ps1 in the corresponding-source ZIP. Use C++23-capable Visual Studio, Windows SDK and Python, building dependencies and openMSX in Release/x64. Original notices are preserved in the emulator ZIP's doc directory.

- [Pinned fork](https://github.com/madscient/openMSX_Y8960/tree/78469c4a0c2010f3252f1c55267f4036ccf8fd74)
- [GPL v2 section 3](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
- [Font terms](../third-party/fonts/README.md)

Checked 2026-09-13.

## Technical guides

Japanese and English editions each contain 30 pages.

- Japanese: [PDF](technical/Y8960-TECH-DEMO-technical.ja.pdf)
- English: [PDF](technical/Y8960-TECH-DEMO-technical.en.pdf)

If an installed environment has a different hash, extract the current distribution ZIP into a separate local folder, run setup, then test there. Do not modify the old runtime to bypass validation.
