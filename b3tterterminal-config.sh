#!/usr/bin/env bash
set -Eeuo pipefail

APP='B3tterTerminal Config'
START_MARK='# >>> B3TTERTERMINAL START >>>'
END_MARK='# <<< B3TTERTERMINAL END <<<'

if [[ -t 1 ]]; then
  NC=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m'; MAGENTA=$'\033[35m'; CYAN=$'\033[36m'
else
  NC=''; BOLD=''; DIM=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''
fi

OK="${GREEN}[+]${NC}"
INFO="${BLUE}[i]${NC}"
WARN="${YELLOW}[!]${NC}"
ERR="${RED}[x]${NC}"
SELECT="${MAGENTA}[>]${NC}"

TARGET_USER=''
TARGET_HOME=''
TARGET_UID=''
TARGET_GID=''
TARGET_DBUS=''

KITTY_ENABLED=yes
KITTY_BG='#0b0f14'
KITTY_FG='#e6edf3'
KITTY_OPACITY='0.85'
KITTY_FONT_SIZE='11.0'
KITTY_CURSOR='block'
KITTY_TRAIL=no
KITTY_TRAIL_COLOR='#00d7ff'

POSH_ENABLED=yes
POSH_THEME=''
LSD_ALIASES=yes
BAT_ALIASES=yes
FASTFETCH_ENABLED=yes
FASTFETCH_START=no
ZSH_AUTOSUGGEST=yes
ZSH_SYNTAX=yes

SET_KITTY_DEFAULT=no
SET_KITTY_SHORTCUT=no
SET_ZSH_DEFAULT=no

cleanup() {
  tput cnorm 2>/dev/null || true
}

on_error() {
  local status=$?
  printf '\n%b Error en %s, linea %s. Estado: %s\n' "$ERR" "$APP" "${BASH_LINENO[0]:-?}" "$status" >&2
}

trap cleanup EXIT INT TERM
trap on_error ERR

clear_screen() { printf '\033[2J\033[H'; }

term_cols() {
  local cols=${COLUMNS:-}
  [[ $cols =~ ^[0-9]+$ ]] || cols=$(tput cols 2>/dev/null || printf '80')
  (( cols < 60 )) && cols=60
  printf '%d' "$cols"
}

CONTENT_MARGIN=2

left_plain() {
  local text=$1 style=${2:-}
  printf '%*s%b%s%b\n' "$CONTENT_MARGIN" '' "$style" "$text" "$NC"
}

rule() {
  local cols width i
  cols=$(term_cols)
  width=$(( cols - (CONTENT_MARGIN * 2) ))
  (( width > 92 )) && width=92
  (( width < 40 )) && width=40
  printf '%*s%b' "$CONTENT_MARGIN" '' "$DIM"
  for ((i=0; i<width; i++)); do printf '-'; done
  printf '%b\n' "$NC"
}

declare -a ASCII_ART=(
' ____  _____ _   _             _____                   _             _'
'| __ )|___ /| |_| |_ ___ _ __ |_   _|__ _ __ _ __ ___ (_)_ __   __ _| |'
'|  _ \  |_ \| __| __/ _ \ '\''__|  | |/ _ \ '\''__| '\''_ ` _ \| | '\''_ \ / _` | |'
'| |_) |___) | |_| ||  __/ |     | |  __/ |  | | | | | | | | | | (_| | |'
'|____/|____/ \__|\__\___|_|     |_|\___|_|  |_| |_| |_|_|_| |_|\__,_|_|'
)

draw_ascii_logo() {
  local art
  for art in "${ASCII_ART[@]}"; do
    left_plain "$art" "${CYAN}${BOLD}"
  done
}

banner() {
  draw_ascii_logo
  left_plain "Post-install configuration" "${MAGENTA}${BOLD}"
  left_plain 'Kitty - ZSH - Oh My Posh - LSD - BAT - Fastfetch' "$DIM"
  rule
}

page() {
  local title=$1
  clear_screen
  banner
  printf '\n'
  left_plain "$title" "${GREEN}${BOLD}"
  rule
  printf '\n'
}

press_enter() {
  printf "\n${DIM}%s${NC}" "Pulsa ENTER para continuar..."
  read -r _ || true
}

yes_label() {
  [[ $1 == yes ]] && printf 'Si' || printf 'No'
}

toggle_yes_no() {
  local name=$1
  if [[ ${!name} == yes ]]; then
    printf -v "$name" '%s' no
  else
    printf -v "$name" '%s' yes
  fi
}

ask_yes_no() {
  local question=$1 default=${2:-yes} value
  while true; do
    printf "\n%b %s\n" "$SELECT" "$question"
    if [[ $default == yes ]]; then
      printf "  ${CYAN}1)${NC} Si ${DIM}[default]${NC}\n  ${CYAN}2)${NC} No\n"
    else
      printf "  ${CYAN}1)${NC} Si\n  ${CYAN}2)${NC} No ${DIM}[default]${NC}\n"
    fi
    printf '%b ' "$SELECT"
    read -r value || value=''
    [[ -n $value ]] || { [[ $default == yes ]] && return 0 || return 1; }
    case ${value,,} in
      1|y|yes|s|si) return 0 ;;
      2|n|no) return 1 ;;
      *) printf '%b %s\n' "$WARN" "Selecciona 1 o 2." ;;
    esac
  done
}

ask_menu() {
  local prompt=$1 default=$2
  shift 2
  local -a options=("$@")
  local choice i

  while true; do
    printf "\n%b %s\n" "$SELECT" "$prompt" >&2
    for ((i=0; i<${#options[@]}; i++)); do
      if (( i + 1 == default )); then
        printf "  ${CYAN}%d)${NC} %s ${DIM}[default]${NC}\n" "$((i+1))" "${options[i]}" >&2
      else
        printf "  ${CYAN}%d)${NC} %s\n" "$((i+1))" "${options[i]}" >&2
      fi
    done
    printf '%b ' "$SELECT" >&2
    read -r choice || choice=''
    choice=${choice:-$default}
    if [[ $choice =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      printf '%s' "$choice"
      return
    fi
    printf '%b %s\n' "$WARN" "Opcion no valida." >&2
  done
}

ask_text() {
  local prompt=$1 default=$2 value
  printf "\n%b %s ${DIM}[%s]${NC}\n%b " "$SELECT" "$prompt" "$default" "$SELECT" >&2
  read -r value || value=''
  printf '%s' "${value:-$default}"
}

ask_hex() {
  local prompt=$1 default=$2 value
  while true; do
    value=$(ask_text "$prompt" "$default")
    [[ $value =~ ^#[0-9A-Fa-f]{6}$ ]] && { printf '%s' "$value"; return; }
    printf '\n%b %s\n' "$WARN" "Usa HEX, por ejemplo #00d7ff." >&2
  done
}

ask_opacity_value() {
  local prompt=$1 default=$2 value
  while true; do
    value=$(ask_text "$prompt" "$default")
    if awk -v n="$value" 'BEGIN{exit !(n>=0.10&&n<=1.00)}'; then
      printf '%s' "$value"
      return
    fi
    printf '\n%b %s\n' "$WARN" "Valor no valido. Usa un numero entre 0.10 y 1.00." >&2
  done
}

select_target_user() {
  local requested=${B3TTER_USER:-}

  if [[ -n $requested ]]; then
    getent passwd "$requested" >/dev/null || {
      printf '%b Usuario inexistente: %s\n' "$ERR" "$requested"
      exit 1
    }
    TARGET_USER=$requested
  elif (( EUID == 0 )) && [[ -n ${SUDO_USER:-} && ${SUDO_USER:-} != root ]] && getent passwd "$SUDO_USER" >/dev/null; then
    TARGET_USER=$SUDO_USER
  elif (( EUID == 0 )); then
    local -a users=() labels=()
    local user uid home shell choice

    while IFS=: read -r user _ uid _ _ home shell; do
      [[ $uid -ge 1000 && $uid -lt 60000 ]] || continue
      [[ $shell != */nologin && $shell != */false ]] || continue
      users+=("$user")
    done < <(getent passwd)

    users+=(root)
    for user in "${users[@]}"; do
      home=$(getent passwd "$user" | cut -d: -f6)
      labels+=("$user - $home")
    done

    page "Usuario objetivo"
    choice=$(ask_menu "Selecciona el usuario que quieres editar" 1 "${labels[@]}")
    TARGET_USER=${users[choice-1]}
  else
    TARGET_USER=$(id -un)
  fi

  TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
  TARGET_UID=$(id -u "$TARGET_USER")
  TARGET_GID=$(id -g "$TARGET_USER")
  TARGET_DBUS="unix:path=/run/user/${TARGET_UID}/bus"

  [[ -n $TARGET_HOME && $TARGET_HOME == /* ]] || {
    printf '%b No se pudo determinar HOME para %s\n' "$ERR" "$TARGET_USER"
    exit 1
  }

  if (( EUID != 0 )) && [[ $(id -un) != "$TARGET_USER" ]]; then
    printf '%b Para editar otro usuario usa sudo o B3TTER_USER.\n' "$ERR"
    exit 1
  fi
}

run_as_target() {
  if (( EUID == 0 )) && [[ $TARGET_USER != root ]]; then
    runuser -u "$TARGET_USER" -- env \
      HOME="$TARGET_HOME" \
      USER="$TARGET_USER" \
      LOGNAME="$TARGET_USER" \
      PATH="$TARGET_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin" \
      DISPLAY="${DISPLAY:-}" \
      XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
      DBUS_SESSION_BUS_ADDRESS="$TARGET_DBUS" \
      "$@"
  else
    env HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" "$@"
  fi
}

own_target() {
  (( EUID == 0 )) || return 0
  local path
  for path in "$@"; do
    [[ -e $path || -L $path ]] || continue
    chown -R "$TARGET_UID:$TARGET_GID" "$path"
  done
}

backup_file() {
  [[ ! -f $1 ]] || cp -a "$1" "$1.backup.$(date +%Y%m%d-%H%M%S)"
}

config_value() {
  local key=$1 default=$2 file=$3
  [[ -r $file ]] || { printf '%s' "$default"; return; }
  awk -v key="$key" '
    $1 == key {
      $1 = ""
      sub(/^ /, "")
      print
      found = 1
      exit
    }
    END { if (!found) exit 1 }
  ' "$file" 2>/dev/null || printf '%s' "$default"
}

load_state() {
  local rc="$TARGET_HOME/.zshrc"
  local kitty="$TARGET_HOME/.config/kitty/b3tterterminal.conf"
  local fastfetch_marker="$TARGET_HOME/.config/b3tterterminal/show-fastfetch"

  if [[ -r $kitty ]]; then
    KITTY_ENABLED=yes
    KITTY_BG=$(config_value background "$KITTY_BG" "$kitty")
    KITTY_FG=$(config_value foreground "$KITTY_FG" "$kitty")
    KITTY_OPACITY=$(config_value background_opacity "$KITTY_OPACITY" "$kitty")
    KITTY_FONT_SIZE=$(config_value font_size "$KITTY_FONT_SIZE" "$kitty")
    KITTY_CURSOR=$(config_value cursor_shape "$KITTY_CURSOR" "$kitty")
    KITTY_TRAIL_COLOR=$(config_value cursor_trail_color "$KITTY_TRAIL_COLOR" "$kitty")
    [[ $(config_value cursor_trail 0 "$kitty") == 1 ]] && KITTY_TRAIL=yes || KITTY_TRAIL=no
  fi

  if [[ -r $rc ]]; then
    grep -Fq "alias ls='lsd'" "$rc" && LSD_ALIASES=yes || LSD_ALIASES=no
    { grep -Fq "alias cat='batcat --paging=never'" "$rc" || grep -Fq "alias cat='bat --paging=never'" "$rc"; } && BAT_ALIASES=yes || BAT_ALIASES=no
    grep -Fq "command -v fastfetch" "$rc" && FASTFETCH_ENABLED=yes || FASTFETCH_ENABLED=no
    grep -Fq "oh-my-posh init zsh" "$rc" && POSH_ENABLED=yes || POSH_ENABLED=no
    grep -Fq "zsh-autosuggestions" "$rc" && ZSH_AUTOSUGGEST=yes || ZSH_AUTOSUGGEST=no
    grep -Fq "zsh-syntax-highlighting" "$rc" && ZSH_SYNTAX=yes || ZSH_SYNTAX=no
  fi

  if [[ -f $fastfetch_marker ]]; then
    FASTFETCH_START=yes
    FASTFETCH_ENABLED=yes
  else
    FASTFETCH_START=no
  fi
}

choose_palette() {
  local choice
  choice=$(ask_menu "Elige una paleta" 1 \
    'Midnight Cyan' 'Cyber Purple' 'Matrix Green' 'Crimson Red' 'Colores personalizados')

  case $choice in
    1) KITTY_BG='#0b0f14'; KITTY_FG='#e6edf3'; KITTY_TRAIL_COLOR='#00d7ff' ;;
    2) KITTY_BG='#100c18'; KITTY_FG='#f2e9ff'; KITTY_TRAIL_COLOR='#c77dff' ;;
    3) KITTY_BG='#07110a'; KITTY_FG='#d8ffe0'; KITTY_TRAIL_COLOR='#39ff88' ;;
    4) KITTY_BG='#14090b'; KITTY_FG='#ffe8ea'; KITTY_TRAIL_COLOR='#ff4d67' ;;
    5)
      KITTY_BG=$(ask_hex "Color de fondo" "$KITTY_BG")
      KITTY_FG=$(ask_hex "Color del texto" "$KITTY_FG")
      KITTY_TRAIL_COLOR=$(ask_hex "Color del cursor animado" "$KITTY_TRAIL_COLOR")
      ;;
  esac
}

choose_theme() {
  local choice
  choice=$(ask_menu "Elige el tema de Oh My Posh" 1 \
    powerline jandedobbeleer atomic paradox clean-detailed 'Nombre personalizado')

  case $choice in
    1) POSH_THEME=powerline ;;
    2) POSH_THEME=jandedobbeleer ;;
    3) POSH_THEME=atomic ;;
    4) POSH_THEME=paradox ;;
    5) POSH_THEME=clean-detailed ;;
    6) POSH_THEME=$(ask_text "Nombre sin .omp.json" "${POSH_THEME:-powerline}") ;;
  esac
}

kitty_menu() {
  local choice shape
  while true; do
    page "Kitty"
    printf "%s Usuario: ${CYAN}%s${NC} (${DIM}%s${NC})\n\n" "$INFO" "$TARGET_USER" "$TARGET_HOME"
    printf "  Fondo:      ${CYAN}%s${NC}\n" "$KITTY_BG"
    printf "  Texto:      ${CYAN}%s${NC}\n" "$KITTY_FG"
    printf "  Opacidad:   ${CYAN}%s${NC}\n" "$KITTY_OPACITY"
    printf "  Fuente:     ${CYAN}%s${NC}\n" "$KITTY_FONT_SIZE"
    printf "  Cursor:     ${CYAN}%s${NC}\n" "$KITTY_CURSOR"
    printf "  Trail:      ${CYAN}%s${NC} (${KITTY_TRAIL_COLOR})\n" "$(yes_label "$KITTY_TRAIL")"

    choice=$(ask_menu "Que quieres editar?" 7 \
      'Cambiar paleta/colores' \
      'Cambiar opacidad' \
      'Cambiar tamano de fuente' \
      'Cambiar forma del cursor' \
      'Activar/desactivar cursor animado' \
      'Activar/desactivar config Kitty' \
      'Volver')

    case $choice in
      1) choose_palette ;;
      2) KITTY_OPACITY=$(ask_opacity_value "Valor entre 0.10 y 1.00" "$KITTY_OPACITY") ;;
      3) KITTY_FONT_SIZE=$(ask_text "Tamano de fuente" "$KITTY_FONT_SIZE") ;;
      4)
        shape=$(ask_menu "Forma del cursor" 1 Block Beam Underline)
        case $shape in
          1) KITTY_CURSOR=block ;;
          2) KITTY_CURSOR=beam ;;
          3) KITTY_CURSOR=underline ;;
        esac
        ;;
      5) toggle_yes_no KITTY_TRAIL ;;
      6) toggle_yes_no KITTY_ENABLED ;;
      7) return ;;
    esac
  done
}

shell_menu() {
  local choice
  while true; do
    page "ZSH, aliases y Fastfetch"
    printf "  LSD aliases:              ${CYAN}%s${NC}\n" "$(yes_label "$LSD_ALIASES")"
    printf "  BAT aliases:              ${CYAN}%s${NC}\n" "$(yes_label "$BAT_ALIASES")"
    printf "  Fastfetch aliases:        ${CYAN}%s${NC}\n" "$(yes_label "$FASTFETCH_ENABLED")"
    printf "  Fastfetch al iniciar:     ${CYAN}%s${NC}\n" "$(yes_label "$FASTFETCH_START")"
    printf "  zsh-autosuggestions:      ${CYAN}%s${NC}\n" "$(yes_label "$ZSH_AUTOSUGGEST")"
    printf "  syntax errores en rojo:   ${CYAN}%s${NC}\n" "$(yes_label "$ZSH_SYNTAX")"

    choice=$(ask_menu "Que quieres cambiar?" 7 \
      'LSD aliases' \
      'BAT aliases' \
      'Fastfetch aliases' \
      'Fastfetch al abrir terminal' \
      'zsh-autosuggestions' \
      'zsh-syntax-highlighting rojo' \
      'Volver')

    case $choice in
      1) toggle_yes_no LSD_ALIASES ;;
      2) toggle_yes_no BAT_ALIASES ;;
      3)
        toggle_yes_no FASTFETCH_ENABLED
        if [[ $FASTFETCH_ENABLED == no ]]; then
          FASTFETCH_START=no
        fi
        ;;
      4)
        toggle_yes_no FASTFETCH_START
        if [[ $FASTFETCH_START == yes ]]; then
          FASTFETCH_ENABLED=yes
        fi
        ;;
      5) toggle_yes_no ZSH_AUTOSUGGEST ;;
      6) toggle_yes_no ZSH_SYNTAX ;;
      7) return ;;
    esac
  done
}

posh_menu() {
  page "Oh My Posh"
  printf "  Activado: ${CYAN}%s${NC}\n" "$(yes_label "$POSH_ENABLED")"
  printf "  Tema a descargar: ${CYAN}%s${NC}\n" "${POSH_THEME:-mantener actual}"

  if ask_yes_no "Usar Oh My Posh en el prompt?" "$POSH_ENABLED"; then
    POSH_ENABLED=yes
    choose_theme
  else
    POSH_ENABLED=no
  fi
}

desktop_menu() {
  local choice
  while true; do
    page "Defaults y atajos"
    printf "  Kitty como terminal predeterminada: ${CYAN}%s${NC}\n" "$(yes_label "$SET_KITTY_DEFAULT")"
    printf "  Atajo Super+Enter para Kitty:       ${CYAN}%s${NC}\n" "$(yes_label "$SET_KITTY_SHORTCUT")"
    printf "  ZSH como shell predeterminada:      ${CYAN}%s${NC}\n" "$(yes_label "$SET_ZSH_DEFAULT")"
    printf "\n%s Estas acciones se aplican al confirmar los cambios.\n" "$INFO"

    choice=$(ask_menu "Que quieres marcar?" 4 \
      'Kitty como terminal predeterminada' \
      'Atajo Super+Enter' \
      'ZSH como shell predeterminada' \
      'Volver')

    case $choice in
      1) toggle_yes_no SET_KITTY_DEFAULT ;;
      2) toggle_yes_no SET_KITTY_SHORTCUT ;;
      3) toggle_yes_no SET_ZSH_DEFAULT ;;
      4) return ;;
    esac
  done
}

zsh_features_enabled() {
  [[ $LSD_ALIASES == yes || $BAT_ALIASES == yes || $FASTFETCH_ENABLED == yes || $POSH_ENABLED == yes || $ZSH_AUTOSUGGEST == yes || $ZSH_SYNTAX == yes ]]
}

strip_blocks() {
  awk '
  /^# >>> B3TTERTERMINAL START >>>$/ {skip=1;next}
  /^# <<< B3TTERTERMINAL END <<<$/{skip=0;next}
  /^# >>> KALITERM STUDIO START >>>$/ {skip=1;next}
  /^# <<< KALITERM STUDIO END <<<$/{skip=0;next}
  /^# >>> KALISHELL FORGE START >>>$/ {skip=1;next}
  /^# <<< KALISHELL FORGE END <<<$/{skip=0;next}
  /^# >>> CLEANKALI START/ {skip=1;next}
  /^# <<< CLEANKALI END/ {skip=0;next}
  /^# >>> CLEAN TERMINAL KALI START/ {skip=1;next}
  /^# <<< CLEAN TERMINAL KALI END/ {skip=0;next}
  !skip{print}' "$1" > "$2"
}

write_zsh_config() {
  local rc="$TARGET_HOME/.zshrc" tmp marker_dir="$TARGET_HOME/.config/b3tterterminal"
  tmp=$(mktemp)

  if [[ ! -f $rc ]]; then
    [[ -r /etc/skel/.zshrc ]] && cp /etc/skel/.zshrc "$rc" || touch "$rc"
  fi

  backup_file "$rc"
  strip_blocks "$rc" "$tmp"
  mv "$tmp" "$rc"

  mkdir -p "$marker_dir"
  if [[ $FASTFETCH_START == yes ]]; then
    touch "$marker_dir/show-fastfetch"
  else
    rm -f "$marker_dir/show-fastfetch"
  fi

  if zsh_features_enabled; then
    {
      printf '\n%s\n' "$START_MARK"
      printf '%s\n' 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"' '[[ "$TERM" == *256color* ]] || export TERM=xterm-256color' ''

      if [[ $LSD_ALIASES == yes ]]; then
        command cat <<'Z'
if command -v lsd >/dev/null 2>&1; then
  alias ls='lsd'
  alias ll='lsd -la'
  alias la='lsd -a'
  alias l='lsd -l'
  alias lt='lsd --tree'
fi

Z
      fi

      if [[ $BAT_ALIASES == yes ]]; then
        command cat <<'Z'
if command -v batcat >/dev/null 2>&1; then
  alias bat='batcat'
  alias cat='batcat --paging=never'
  alias catn='batcat --paging=never --style=numbers'
  alias catp='batcat --paging=never --plain'
  alias catA='batcat --paging=never --show-all'
  alias batr='batcat --line-range'
  alias batl='batcat --language'
  alias batthemes='batcat --list-themes'
elif command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
  alias catn='bat --paging=never --style=numbers'
  alias catp='bat --paging=never --plain'
fi

Z
      fi

      if [[ $FASTFETCH_ENABLED == yes ]]; then
        command cat <<'Z'
if command -v fastfetch >/dev/null 2>&1; then
  alias ff='fastfetch'
  alias neofetch='fastfetch'
fi
if [[ $- == *i* && -f "$HOME/.config/b3tterterminal/show-fastfetch" ]] && command -v fastfetch >/dev/null 2>&1; then
  fastfetch
fi

Z
      fi

      if [[ $POSH_ENABLED == yes ]]; then
        command cat <<'Z'
export POSH_THEME="$HOME/.config/oh-my-posh/b3tterterminal.omp.json"
if command -v oh-my-posh >/dev/null 2>&1 && [[ -r "$POSH_THEME" ]]; then
  eval "$(oh-my-posh init zsh --config "$POSH_THEME")"
fi

Z
      fi

      if [[ $ZSH_AUTOSUGGEST == yes ]]; then
        command cat <<'Z'
# zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=245'
ZSH_AUTOSUGGEST_STRATEGY=(history)
ZSH_AUTOSUGGEST_USE_ASYNC=1

: ${HISTFILE:="$HOME/.zsh_history"}
: ${HISTSIZE:=10000}
: ${SAVEHIST:=10000}

if (( ! ${+functions[_zsh_autosuggest_start]} )); then
  for f in \
    /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
    if [[ -r $f ]]; then
      source "$f"
      break
    fi
  done
fi

bindkey -M emacs '^[[C' forward-char 2>/dev/null || true
bindkey -M viins '^[[C' forward-char 2>/dev/null || true
bindkey -M emacs '^F' forward-char 2>/dev/null || true
bindkey -M viins '^F' forward-char 2>/dev/null || true

Z
      fi

      if [[ $ZSH_SYNTAX == yes ]]; then
        command cat <<'Z'
# zsh-syntax-highlighting must be loaded at the end of the interactive config.
if (( ! ${+functions[_zsh_highlight_main]} && ! ${+functions[_zsh_highlight]} )); then
  for f in \
    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    if [[ -r $f ]]; then
      source "$f"
      break
    fi
  done
fi

typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=red,bold'
Z
      fi

      printf '%s\n' "$END_MARK"
    } >> "$rc"
  fi

  chmod 600 "$rc"
  own_target "$rc" "$marker_dir"
}

write_kitty_config() {
  local dir="$TARGET_HOME/.config/kitty"
  local main="$dir/kitty.conf"
  local studio="$dir/b3tterterminal.conf"
  local tmp zsh_path

  mkdir -p "$dir"
  touch "$main"
  backup_file "$main"
  tmp=$(mktemp)
  grep -vE '^[[:space:]]*include[[:space:]]+(kalishell-forge|kaliterm-studio|b3tterterminal)\.conf[[:space:]]*$' "$main" > "$tmp" || true
  mv "$tmp" "$main"

  if [[ $KITTY_ENABLED != yes ]]; then
    own_target "$dir"
    return
  fi

  printf '\ninclude b3tterterminal.conf\n' >> "$main"

  command cat > "$studio" <<K
# Managed by B3tterTerminal
font_family MesloLGM Nerd Font Mono
font_size $KITTY_FONT_SIZE
background $KITTY_BG
foreground $KITTY_FG
background_opacity $KITTY_OPACITY
dynamic_background_opacity yes
window_padding_width 8
cursor_shape $KITTY_CURSOR
cursor_blink_interval 0.5 ease-in-out
cursor_stop_blinking_after 0
tab_bar_style fade
tab_bar_edge top
tab_bar_min_tabs 2
tab_title_template " {index} "
active_tab_background $KITTY_BG
active_tab_foreground $KITTY_FG
inactive_tab_background $KITTY_BG
inactive_tab_foreground #6b7280
tab_bar_background $KITTY_BG
K

  zsh_path=$(command -v zsh || true)
  if [[ -n $zsh_path ]]; then
    printf 'shell %s\n' "$zsh_path" >> "$studio"
  fi

  if [[ $KITTY_TRAIL == yes ]]; then
    command cat >> "$studio" <<K
cursor_trail 1
cursor_trail_decay 0.08 0.25
cursor_trail_start_threshold 1
cursor_trail_color $KITTY_TRAIL_COLOR
K
  else
    printf 'cursor_trail 0\n' >> "$studio"
  fi

  own_target "$dir"
}

download_posh_theme() {
  [[ $POSH_ENABLED == yes ]] || return 0

  local dir="$TARGET_HOME/.config/oh-my-posh"
  local dest="$dir/b3tterterminal.omp.json"
  local theme="${POSH_THEME:-}"
  local url fallback

  if [[ -z $theme && -s $dest ]]; then
    return 0
  fi

  theme=${theme:-powerline}
  command -v curl >/dev/null 2>&1 || {
    printf '%b curl no esta disponible; no se pudo descargar el tema.\n' "$WARN"
    return 0
  }

  mkdir -p "$dir"
  url="https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/${theme}.omp.json"
  fallback='https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/powerline.omp.json'

  if curl -fsSL "$url" -o "$dest" || curl -fsSL "$fallback" -o "$dest"; then
    own_target "$dir"
    printf '%b Tema Oh My Posh aplicado: %s\n' "$OK" "$theme"
  else
    printf '%b No se pudo descargar el tema de Oh My Posh.\n' "$WARN"
  fi
}

apply_desktop_changes() {
  if [[ $SET_KITTY_DEFAULT == yes ]]; then
    if (( EUID == 0 )) && [[ -x /usr/bin/kitty ]]; then
      update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/kitty 90
      update-alternatives --set x-terminal-emulator /usr/bin/kitty
      printf '%b Kitty establecido como terminal predeterminada.\n' "$OK"
    else
      printf '%b Para cambiar la terminal predeterminada del sistema ejecuta con sudo.\n' "$WARN"
    fi
  fi

  if [[ $SET_KITTY_SHORTCUT == yes ]]; then
    if command -v xfconf-query >/dev/null 2>&1; then
      run_as_target xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Super>Return' -r -R >/dev/null 2>&1 || true
      run_as_target xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Super>Return' -n -t string -s /usr/bin/kitty >/dev/null 2>&1 || true
      printf '%b Atajo Super+Enter aplicado.\n' "$OK"
    else
      printf '%b xfconf-query no esta disponible; no se pudo aplicar Super+Enter.\n' "$WARN"
    fi
  fi

  if [[ $SET_ZSH_DEFAULT == yes ]]; then
    if (( EUID == 0 )) && command -v zsh >/dev/null 2>&1; then
      chsh -s "$(command -v zsh)" "$TARGET_USER"
      printf '%b ZSH establecido como shell predeterminada para %s.\n' "$OK" "$TARGET_USER"
    else
      printf '%b Para cambiar la shell predeterminada ejecuta con sudo y asegurate de tener zsh.\n' "$WARN"
    fi
  fi
}

validate_changes() {
  local rc="$TARGET_HOME/.zshrc"
  local ok=yes

  if command -v zsh >/dev/null 2>&1 && [[ -f $rc ]]; then
    if ! run_as_target zsh -n "$rc"; then
      printf '%b .zshrc tiene un error de sintaxis.\n' "$ERR"
      ok=no
    fi
  fi

  if [[ $KITTY_ENABLED == yes && ! -s "$TARGET_HOME/.config/kitty/b3tterterminal.conf" ]]; then
    printf '%b No se encontro la config de Kitty generada.\n' "$ERR"
    ok=no
  fi

  if [[ $ok == yes ]]; then
    printf '%b Validacion completada.\n' "$OK"
  else
    printf '%b Revisa los avisos anteriores antes de cerrar la terminal.\n' "$WARN"
  fi
}

summary_page() {
  page "Resumen"
  printf "Usuario: ${CYAN}%s${NC} (${DIM}%s${NC})\n\n" "$TARGET_USER" "$TARGET_HOME"
  printf "Kitty: %s | bg: %s | fg: %s | opacity: %s | font: %s | cursor: %s | trail: %s\n" \
    "$(yes_label "$KITTY_ENABLED")" "$KITTY_BG" "$KITTY_FG" "$KITTY_OPACITY" "$KITTY_FONT_SIZE" "$KITTY_CURSOR" "$(yes_label "$KITTY_TRAIL")"
  printf "Oh My Posh: %s | theme: %s\n" "$(yes_label "$POSH_ENABLED")" "${POSH_THEME:-mantener actual}"
  printf "LSD aliases: %s | BAT aliases: %s | Fastfetch: %s | startup: %s\n" \
    "$(yes_label "$LSD_ALIASES")" "$(yes_label "$BAT_ALIASES")" "$(yes_label "$FASTFETCH_ENABLED")" "$(yes_label "$FASTFETCH_START")"
  printf "Autosuggestions: %s | Syntax rojo: %s\n" "$(yes_label "$ZSH_AUTOSUGGEST")" "$(yes_label "$ZSH_SYNTAX")"
  printf "Defaults: Kitty=%s | Super+Enter=%s | ZSH=%s\n" \
    "$(yes_label "$SET_KITTY_DEFAULT")" "$(yes_label "$SET_KITTY_SHORTCUT")" "$(yes_label "$SET_ZSH_DEFAULT")"
}

apply_changes() {
  page "Aplicando cambios"
  printf "%s Usuario objetivo: ${CYAN}%s${NC} (${DIM}%s${NC})\n\n" "$INFO" "$TARGET_USER" "$TARGET_HOME"

  download_posh_theme
  write_zsh_config
  printf '%b Configuracion ZSH actualizada.\n' "$OK"

  write_kitty_config
  if [[ $KITTY_ENABLED == yes ]]; then
    printf '%b Configuracion Kitty actualizada.\n' "$OK"
  else
    printf '%b Include de B3tterTerminal retirado de kitty.conf.\n' "$OK"
  fi

  apply_desktop_changes
  validate_changes

  printf "\n${BOLD}%s${NC}\n" "Listo. Abre una terminal nueva o ejecuta:"
  printf "  ${CYAN}exec zsh${NC}\n"
  if [[ $KITTY_ENABLED == yes ]]; then
    printf "  ${CYAN}kitty${NC}\n"
  fi
  press_enter
}

main_menu() {
  local choice
  while true; do
    summary_page
    choice=$(ask_menu "Menu principal" 6 \
      'Editar Kitty' \
      'Editar ZSH, aliases y Fastfetch' \
      'Editar Oh My Posh' \
      'Defaults y atajos' \
      'Aplicar cambios' \
      'Salir sin aplicar')

    case $choice in
      1) kitty_menu ;;
      2) shell_menu ;;
      3) posh_menu ;;
      4) desktop_menu ;;
      5)
        summary_page
        if ask_yes_no "Aplicar esta configuracion?" yes; then
          apply_changes
          return
        fi
        ;;
      6)
        printf '\n%b Saliendo sin aplicar cambios.\n' "$WARN"
        return
        ;;
    esac
  done
}

main() {
  select_target_user
  load_state
  main_menu
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
