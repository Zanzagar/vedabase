# Sources

The instructions this repo automates, and where they came from.

## Tāraka dāsa (WhatsApp, 2026-10-18)

- The desktop VedaBase is built on Folio, which was written for Windows. It
  runs on Windows 11, on various Linux distributions, and in a VM. Some
  features have been broken by Windows updates; he said he would explain which
  later, and is asking other devotees which setup would work best.
- The current release is **VedaBase 25**. It is two infobases: *VedaBase 25*,
  mostly Śrīla Prabhupāda's works, and *VaniBase 25*, works by other devotees.
- Contents lists: *VedaBase Contents Full.pdf*
  (`1CGylFnQ6fRlcs9Ul2QmUNP4QemeFUepx`) and *VaniBase Contents Full.pdf*
  (`1KcGmRK82EfIr9ihDs6OGsnAQ3PUElCcH`).
- Install files: the Drive folders *VedaBase with Program*
  (`1DLtXVHhfHDjwo7A6TKha1SyvhkYhQ5u_`) and *VaniBase*
  (`1a5-ZLiuBYLU9xGNa37f4ZEQhPG82vyFz`). Both are owned by Ekanatha dāsa.

## Ekanatha dāsa's README (`README.docx`, and the older `Nfo/VedaBase-with-Program Installation.pdf`)

1. Uninstall any earlier VedaBase from the Control Panel.
2. Put `Fonts\`, `Nfo\`, `Spec\` and `Install.exe` at the root of `C:\`.
   Some PCs will not let you copy an .exe there directly; download them to a
   temporary folder first, then move them.
3. Run `Install.exe` and finish the wizard.
4. If the diacritics do not show, install every font in `C:\Fonts` (drag them
   onto the Fonts icon in Control Panel) and restart VedaBase.

The 2025 infobase `VB2025.NFO` was renamed to
`Bhaktivedanta VedaBase 2003.NFO` so that the 2003 install script finds it.
That rename is what breaks the shadow file; see
[how-it-works.md](how-it-works.md#the-fix-the-readme-doesnt-mention-vedabase_25nfo).

## The CrossOver report (`VedaBase_CrossOver_Installation.pdf`)

A report on installing VedaBase on macOS with CrossOver (the commercial Wine).
What worked:

- Use a **Windows 7 or XP bottle**. A Windows 10 bottle crashed, or VedaBase
  would not start.
- Install MSXML and the Microsoft core fonts in the bottle **before**
  VedaBase. This reportedly avoided runtime errors.
- Then run the setup inside the bottle. Add the diacritic fonts if Sanskrit
  shows as garbage.
- Right-click menus and the toolbar may misbehave.
- Keep a backup of the working bottle.

The Linux install here does not need MSXML or the core fonts. Everything
listed in [how-it-works.md](how-it-works.md#what-was-verified)
works without them.
