<p align="center">
  <img src="assets/logo_b3tter.png" alt="B3tterTerminal" width="650">
</p>

B3tterTerminal is an interactive installer for Kali Linux that improves the visual terminal setup with ZSH, Kitty, Oh My Posh, LSD, BAT and Fastfetch.

The installer asks for all options first and only changes the system after the final confirmation.

## Preview

| Before | After |
| --- | --- |
| ![Terminal before](assets/videos/before-terminal.gif) | ![Terminal after](assets/videos/after-terminal.gif) |
| [Watch before video](assets/videos/before-terminal.mov) | [Watch after video](assets/videos/after-terminal.mov) |

## Command Upgrades

| Standard `ls` | B3tterTerminal `ls` |
| --- | --- |
| ![ls before](assets/screenshots/before-ls.png) | ![ls after](assets/screenshots/after-ls.png) |

| Standard `cat` | B3tterTerminal `cat` |
| --- | --- |
| ![cat before](assets/screenshots/before-cat.png) | ![cat after](assets/screenshots/after-cat.png) |

## Videos

- [Full installation demo](assets/videos/install-demo.mp4)
- [Animated terminal preview](assets/videos/animated-preview.mp4)

## Features

- ZSH setup with optional autosuggestions and syntax highlighting.
- Kitty configuration with palettes, opacity, tabs and optional cursor trail.
- Oh My Posh prompt with selectable theme and optional Meslo Nerd Font.
- LSD aliases for a nicer `ls`.
- BAT aliases for a nicer `cat`.
- Optional Fastfetch startup.
- User-aware setup: packages are installed as root, personal config is applied to the selected user.

## Usage

From a normal Kali user:

```bash
chmod +x b3tterterminal.sh
sudo ./b3tterterminal.sh
```

Install for root from a root shell:

```bash
B3TTER_USER=root ./b3tterterminal.sh
```

Install for root from a normal user:

```bash
sudo B3TTER_USER=root ./b3tterterminal.sh
```

Disable the animated ASCII header if the terminal feels slow:

```bash
sudo B3TTER_ASCII_ANIMATION=no ./b3tterterminal.sh
```

## What It Changes

- Installs selected packages with `apt-get`.
- Writes a managed block in the target user's `.zshrc`.
- Creates Kitty config under `~/.config/kitty`.
- Optionally changes the default shell to ZSH.
- Optionally sets Kitty as the default terminal emulator.
- Optionally writes XFCE settings for compositing and `Super+Enter`.

Existing `.zshrc` and Kitty helper files are backed up before changes.

## Roadmap

- Interactive configuration editor for changing colors, opacity, prompt theme, aliases, cursor effects and Fastfetch without editing config files manually.
- Restore/repair menu for rolling back or regenerating the managed terminal setup.

## Notes

The script downloads Oh My Posh, prompt themes and Meslo Nerd Font from their official upstream locations. Review the script before running it if you want to audit every network action.

## License

No license has been selected yet. Add a license before publishing if you want other people to know how they may use or modify the project.
