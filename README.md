# B3tterTerminal

B3tterTerminal is an interactive installer for Kali Linux that improves the visual terminal setup with ZSH, Kitty, Oh My Posh, LSD, BAT and Fastfetch.

The installer asks for all options first and only changes the system after the final confirmation.

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

From a root shell, choose the target user explicitly:

```bash
B3TTER_USER=kali ./b3tterterminal.sh
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

## Notes

The script downloads Oh My Posh, prompt themes and Meslo Nerd Font from their official upstream locations. Review the script before running it if you want to audit every network action.

## License

No license has been selected yet. Add a license before publishing if you want other people to know how they may use or modify the project.
