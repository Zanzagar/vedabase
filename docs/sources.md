# Sources

The instructions this repository automates, and where they came from.

## The files

Tāraka dāsa shared the current release, **VedaBase 25**, in October 2026. It is
two infobases:

- *VedaBase 25*: mostly Śrīla Prabhupāda's works.
- *VaniBase 25*: works by other devotees.

The desktop program is Folio Views, written for Windows. It also runs on Linux
under Wine and in a virtual machine. Some of its features have been affected by
Windows updates over the years.

| What | Google Drive ID |
| --- | --- |
| Contents list, *VedaBase Contents Full.pdf* | `1CGylFnQ6fRlcs9Ul2QmUNP4QemeFUepx` |
| Contents list, *VaniBase Contents Full.pdf* | `1KcGmRK82EfIr9ihDs6OGsnAQ3PUElCcH` |
| Install folder, *VedaBase with Program* | `1DLtXVHhfHDjwo7A6TKha1SyvhkYhQ5u_` |
| Install folder, *VaniBase* | `1a5-ZLiuBYLU9xGNa37f4ZEQhPG82vyFz` |

Ekanatha dāsa maintains both install folders. `manifest/drive-files.tsv`
records every file in them, with its size and SHA-256.

## Ekanatha dāsa's README (`README.docx`, and the older `Nfo/VedaBase-with-Program Installation.pdf`)

1. Uninstall any earlier VedaBase from the Control Panel.
2. Put `Fonts\`, `Nfo\`, `Spec\` and `Install.exe` at the root of `C:\`. Some
   PCs will not let you copy an .exe there directly; download them to a
   temporary folder first, then move them.
3. Run `Install.exe` and finish the wizard.
4. If the diacritics do not show, install every font in `C:\Fonts` by
   dragging them onto the Fonts icon in Control Panel, then restart VedaBase.

The README notes that the 2025 infobase, `VB2025.NFO`, was renamed to
`Bhaktivedanta VedaBase 2003.NFO` so that the 2003 install script finds it.
The shadow file shipped next to it, though, still names its infobase
`VedaBase_25.nfo`, the name on the machine where it was made. Under Wine, the
first launch therefore fails until the infobase also has that name; see
[how-it-works.md](how-it-works.md#the-infobase-name-the-shadow-file-expects).

## The CrossOver report (`VedaBase_CrossOver_Installation.pdf`)

A short report in Ekanatha dāsa's Drive folder on installing VedaBase on macOS
with CrossOver, the commercial Wine. It names no author and leaves some
template fields unfilled. What it says worked:

- Use a **Windows 7 or XP bottle**. A Windows 10 bottle crashed, or VedaBase
  would not start.
- Install MSXML and the Microsoft core fonts in the bottle **before**
  VedaBase. This reportedly avoided runtime errors.
- Then run the setup inside the bottle. Add the diacritic fonts if Sanskrit
  shows as garbage.
- Right-click menus and the toolbar may misbehave.
- Keep a backup of the working bottle.

The Linux install here does not need MSXML or the core fonts. Everything
listed in [how-it-works.md](how-it-works.md#what-was-verified) works without
them.
