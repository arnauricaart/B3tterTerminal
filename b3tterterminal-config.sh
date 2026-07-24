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

LANGUAGE=${B3TTER_LANG:-${B3TTER_LANGUAGE:-es}}
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
  printf '\n%b %s %s, %s %s. %s: %s\n' \
    "$ERR" "$(tr 'Error en' 'Error in')" "$APP" \
    "$(tr 'linea' 'line')" "${BASH_LINENO[0]:-?}" \
    "$(tr 'Estado' 'Status')" "$status" >&2
}

trap cleanup EXIT INT TERM
trap on_error ERR

clear_screen() { printf '\033[2J\033[H'; }
tr() {
  case ${LANGUAGE:-es} in
    en|EN|eng|ENG|english|English) printf '%s' "$2" ;;
    *) printf '%s' "$1" ;;
  esac
}

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
  left_plain "$(tr 'Configuracion post-instalacion' 'Post-install configuration')" "${MAGENTA}${BOLD}"
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
  printf "\n${DIM}%s${NC}" "$(tr 'Pulsa ENTER para continuar...' 'Press ENTER to continue...')"
  read -r _ || true
}

yes_label() {
  [[ $1 == yes ]] && tr Si Yes || tr No No
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
      printf "  ${CYAN}1)${NC} %s ${DIM}[%s]${NC}\n  ${CYAN}2)${NC} %s\n" \
        "$(tr Si Yes)" "$(tr predeterminado default)" "$(tr No No)"
    else
      printf "  ${CYAN}1)${NC} %s\n  ${CYAN}2)${NC} %s ${DIM}[%s]${NC}\n" \
        "$(tr Si Yes)" "$(tr No No)" "$(tr predeterminado default)"
    fi
    printf '%b ' "$SELECT"
    read -r value || value=''
    [[ -n $value ]] || { [[ $default == yes ]] && return 0 || return 1; }
    case ${value,,} in
      1|y|yes|s|si) return 0 ;;
      2|n|no) return 1 ;;
      *) printf '%b %s\n' "$WARN" "$(tr 'Selecciona 1 o 2.' 'Select 1 or 2.')" ;;
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
        printf "  ${CYAN}%d)${NC} %s ${DIM}[%s]${NC}\n" "$((i+1))" "${options[i]}" "$(tr predeterminado default)" >&2
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
    printf '%b %s\n' "$WARN" "$(tr 'Opcion no valida.' 'Invalid option.')" >&2
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
    printf '\n%b %s\n' "$WARN" "$(tr 'Usa HEX, por ejemplo #00d7ff.' 'Use HEX, for example #00d7ff.')" >&2
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
    printf '\n%b %s\n' "$WARN" "$(tr 'Valor no valido. Usa un numero entre 0.10 y 1.00.' 'Invalid value. Use a number between 0.10 and 1.00.')" >&2
  done
}

select_language() {
  case ${LANGUAGE:-es} in
    en|EN|eng|ENG|english|English) LANGUAGE=en ;;
    es|ES|spa|SPA|spanish|Spanish|espanol|Espanol) LANGUAGE=es ;;
    *) LANGUAGE=es ;;
  esac
  if [[ -n ${B3TTER_LANG:-}${B3TTER_LANGUAGE:-} ]]; then
    return 0
  fi
  [[ -t 0 ]] || return 0

  clear_screen
  banner
  printf '\n'
  left_plain 'Choose language / Elegir idioma' "${GREEN}${BOLD}"
  rule
  printf "\n  ${CYAN}1)${NC} EN - English\n"
  printf "  ${CYAN}2)${NC} ES - Espanol ${DIM}[default/predeterminado]${NC}\n\n"
  printf '%b Select EN or ES / Selecciona EN o ES: ' "$SELECT"

  local choice
  read -r choice || choice=''
  case ${choice,,} in
    1|en|english) LANGUAGE=en ;;
    *) LANGUAGE=es ;;
  esac
}

select_target_user() {
  local requested=${B3TTER_USER:-}

  if [[ -n $requested ]]; then
    getent passwd "$requested" >/dev/null || {
      printf '%b %s: %s\n' "$ERR" "$(tr 'Usuario inexistente' 'Unknown user')" "$requested"
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

    page "$(tr 'Usuario objetivo' 'Target user')"
    choice=$(ask_menu "$(tr 'Selecciona el usuario que quieres editar' 'Select the user you want to edit')" 1 "${labels[@]}")
    TARGET_USER=${users[choice-1]}
  else
    TARGET_USER=$(id -un)
  fi

  TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
  TARGET_UID=$(id -u "$TARGET_USER")
  TARGET_GID=$(id -g "$TARGET_USER")
  TARGET_DBUS="unix:path=/run/user/${TARGET_UID}/bus"

  [[ -n $TARGET_HOME && $TARGET_HOME == /* ]] || {
    printf '%b %s %s\n' "$ERR" "$(tr 'No se pudo determinar HOME para' 'Could not determine HOME for')" "$TARGET_USER"
    exit 1
  }

  if (( EUID != 0 )) && [[ $(id -un) != "$TARGET_USER" ]]; then
    printf '%b %s\n' "$ERR" "$(tr 'Para editar otro usuario usa sudo o B3TTER_USER.' 'To edit another user, use sudo or B3TTER_USER.')"
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
  choice=$(ask_menu "$(tr 'Elige una paleta' 'Choose a palette')" 1 \
    'Midnight Cyan' 'Cyber Purple' 'Matrix Green' 'Crimson Red' "$(tr 'Colores personalizados' 'Custom colors')")

  case $choice in
    1) KITTY_BG='#0b0f14'; KITTY_FG='#e6edf3'; KITTY_TRAIL_COLOR='#00d7ff' ;;
    2) KITTY_BG='#100c18'; KITTY_FG='#f2e9ff'; KITTY_TRAIL_COLOR='#c77dff' ;;
    3) KITTY_BG='#07110a'; KITTY_FG='#d8ffe0'; KITTY_TRAIL_COLOR='#39ff88' ;;
    4) KITTY_BG='#14090b'; KITTY_FG='#ffe8ea'; KITTY_TRAIL_COLOR='#ff4d67' ;;
    5)
      KITTY_BG=$(ask_hex "$(tr 'Color de fondo' 'Background color')" "$KITTY_BG")
      KITTY_FG=$(ask_hex "$(tr 'Color del texto' 'Text color')" "$KITTY_FG")
      KITTY_TRAIL_COLOR=$(ask_hex "$(tr 'Color del cursor animado' 'Animated cursor color')" "$KITTY_TRAIL_COLOR")
      ;;
  esac
}

choose_theme() {
  local choice
  choice=$(ask_menu "$(tr 'Elige el tema de Oh My Posh' 'Choose the Oh My Posh theme')" 1 \
    powerline jandedobbeleer atomic paradox clean-detailed "$(tr 'Nombre personalizado' 'Custom name')")

  case $choice in
    1) POSH_THEME=powerline ;;
    2) POSH_THEME=jandedobbeleer ;;
    3) POSH_THEME=atomic ;;
    4) POSH_THEME=paradox ;;
    5) POSH_THEME=clean-detailed ;;
    6) POSH_THEME=$(ask_text "$(tr 'Nombre sin .omp.json' 'Name without .omp.json')" "${POSH_THEME:-powerline}") ;;
  esac
}

kitty_menu() {
  local choice shape
  while true; do
    page "Kitty"
    printf "%s %s: ${CYAN}%s${NC} (${DIM}%s${NC})\n\n" "$INFO" "$(tr Usuario User)" "$TARGET_USER" "$TARGET_HOME"
    printf "  %s:      ${CYAN}%s${NC}\n" "$(tr Fondo Background)" "$KITTY_BG"
    printf "  %s:      ${CYAN}%s${NC}\n" "$(tr Texto Text)" "$KITTY_FG"
    printf "  %s:   ${CYAN}%s${NC}\n" "$(tr Opacidad Opacity)" "$KITTY_OPACITY"
    printf "  %s:     ${CYAN}%s${NC}\n" "$(tr Fuente Font)" "$KITTY_FONT_SIZE"
    printf "  %s:     ${CYAN}%s${NC}\n" "$(tr Cursor Cursor)" "$KITTY_CURSOR"
    printf "  %s:      ${CYAN}%s${NC} (${KITTY_TRAIL_COLOR})\n" "$(tr Rastro Trail)" "$(yes_label "$KITTY_TRAIL")"

    choice=$(ask_menu "$(tr 'Que quieres editar?' 'What do you want to edit?')" 7 \
      "$(tr 'Cambiar paleta/colores' 'Change palette/colors')" \
      "$(tr 'Cambiar opacidad' 'Change opacity')" \
      "$(tr 'Cambiar tamano de fuente' 'Change font size')" \
      "$(tr 'Cambiar forma del cursor' 'Change cursor shape')" \
      "$(tr 'Activar/desactivar cursor animado' 'Enable/disable animated cursor')" \
      "$(tr 'Activar/desactivar config Kitty' 'Enable/disable Kitty config')" \
      "$(tr Volver Back)")

    case $choice in
      1) choose_palette ;;
      2) KITTY_OPACITY=$(ask_opacity_value "$(tr 'Valor entre 0.10 y 1.00' 'Value between 0.10 and 1.00')" "$KITTY_OPACITY") ;;
      3) KITTY_FONT_SIZE=$(ask_text "$(tr 'Tamano de fuente' 'Font size')" "$KITTY_FONT_SIZE") ;;
      4)
        shape=$(ask_menu "$(tr 'Forma del cursor' 'Cursor shape')" 1 Block Beam Underline)
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
    page "$(tr 'ZSH, aliases y Fastfetch' 'ZSH, aliases and Fastfetch')"
    printf "  LSD aliases:              ${CYAN}%s${NC}\n" "$(yes_label "$LSD_ALIASES")"
    printf "  BAT aliases:              ${CYAN}%s${NC}\n" "$(yes_label "$BAT_ALIASES")"
    printf "  Fastfetch aliases:        ${CYAN}%s${NC}\n" "$(yes_label "$FASTFETCH_ENABLED")"
    printf "  %s:     ${CYAN}%s${NC}\n" "$(tr 'Fastfetch al iniciar' 'Fastfetch on startup')" "$(yes_label "$FASTFETCH_START")"
    printf "  zsh-autosuggestions:      ${CYAN}%s${NC}\n" "$(yes_label "$ZSH_AUTOSUGGEST")"
    printf "  %s:   ${CYAN}%s${NC}\n" "$(tr 'errores de sintaxis en rojo' 'red syntax errors')" "$(yes_label "$ZSH_SYNTAX")"

    choice=$(ask_menu "$(tr 'Que quieres cambiar?' 'What do you want to change?')" 7 \
      'LSD aliases' \
      'BAT aliases' \
      'Fastfetch aliases' \
      "$(tr 'Fastfetch al abrir terminal' 'Fastfetch when opening terminal')" \
      'zsh-autosuggestions' \
      "$(tr 'zsh-syntax-highlighting en rojo' 'red zsh-syntax-highlighting')" \
      "$(tr Volver Back)")

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
  printf "  %s: ${CYAN}%s${NC}\n" "$(tr Activado Enabled)" "$(yes_label "$POSH_ENABLED")"
  printf "  %s: ${CYAN}%s${NC}\n" "$(tr 'Tema a descargar' 'Theme to download')" "${POSH_THEME:-$(tr 'mantener actual' 'keep current')}"

  if ask_yes_no "$(tr 'Usar Oh My Posh en el prompt?' 'Use Oh My Posh in the prompt?')" "$POSH_ENABLED"; then
    POSH_ENABLED=yes
    choose_theme
  else
    POSH_ENABLED=no
  fi
}

desktop_menu() {
  local choice
  while true; do
    page "$(tr 'Predeterminados y atajos' 'Defaults and shortcuts')"
    printf "  %s: ${CYAN}%s${NC}\n" "$(tr 'Kitty como terminal predeterminada' 'Kitty as default terminal')" "$(yes_label "$SET_KITTY_DEFAULT")"
    printf "  %s:       ${CYAN}%s${NC}\n" "$(tr 'Atajo Super+Enter para Kitty' 'Super+Enter shortcut for Kitty')" "$(yes_label "$SET_KITTY_SHORTCUT")"
    printf "  %s:      ${CYAN}%s${NC}\n" "$(tr 'ZSH como shell predeterminada' 'ZSH as default shell')" "$(yes_label "$SET_ZSH_DEFAULT")"
    printf "\n%s %s\n" "$INFO" "$(tr 'Estas acciones se aplican al confirmar los cambios.' 'These actions are applied when you confirm the changes.')"

    choice=$(ask_menu "$(tr 'Que quieres marcar?' 'What do you want to mark?')" 4 \
      "$(tr 'Kitty como terminal predeterminada' 'Kitty as default terminal')" \
      "$(tr 'Atajo Super+Enter' 'Super+Enter shortcut')" \
      "$(tr 'ZSH como shell predeterminada' 'ZSH as default shell')" \
      "$(tr Volver Back)")

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
    printf '%b %s\n' "$WARN" "$(tr 'curl no esta disponible; no se pudo descargar el tema.' 'curl is not available; the theme could not be downloaded.')"
    return 0
  }

  mkdir -p "$dir"
  url="https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/${theme}.omp.json"
  fallback='https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/powerline.omp.json'

  if curl -fsSL "$url" -o "$dest" || curl -fsSL "$fallback" -o "$dest"; then
    own_target "$dir"
    printf '%b %s: %s\n' "$OK" "$(tr 'Tema Oh My Posh aplicado' 'Oh My Posh theme applied')" "$theme"
  else
    printf '%b %s\n' "$WARN" "$(tr 'No se pudo descargar el tema de Oh My Posh.' 'The Oh My Posh theme could not be downloaded.')"
  fi
}

apply_desktop_changes() {
  if [[ $SET_KITTY_DEFAULT == yes ]]; then
    if (( EUID == 0 )) && [[ -x /usr/bin/kitty ]]; then
      update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/kitty 90
      update-alternatives --set x-terminal-emulator /usr/bin/kitty
      printf '%b %s\n' "$OK" "$(tr 'Kitty establecido como terminal predeterminada.' 'Kitty set as the default terminal.')"
    else
      printf '%b %s\n' "$WARN" "$(tr 'Para cambiar la terminal predeterminada del sistema ejecuta con sudo.' 'To change the system default terminal, run with sudo.')"
    fi
  fi

  if [[ $SET_KITTY_SHORTCUT == yes ]]; then
    if command -v xfconf-query >/dev/null 2>&1; then
      run_as_target xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Super>Return' -r -R >/dev/null 2>&1 || true
      run_as_target xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Super>Return' -n -t string -s /usr/bin/kitty >/dev/null 2>&1 || true
      printf '%b %s\n' "$OK" "$(tr 'Atajo Super+Enter aplicado.' 'Super+Enter shortcut applied.')"
    else
      printf '%b %s\n' "$WARN" "$(tr 'xfconf-query no esta disponible; no se pudo aplicar Super+Enter.' 'xfconf-query is not available; Super+Enter could not be applied.')"
    fi
  fi

  if [[ $SET_ZSH_DEFAULT == yes ]]; then
    if (( EUID == 0 )) && command -v zsh >/dev/null 2>&1; then
      chsh -s "$(command -v zsh)" "$TARGET_USER"
      printf '%b %s %s.\n' "$OK" "$(tr 'ZSH establecido como shell predeterminada para' 'ZSH set as default shell for')" "$TARGET_USER"
    else
      printf '%b %s\n' "$WARN" "$(tr 'Para cambiar la shell predeterminada ejecuta con sudo y asegurate de tener zsh.' 'To change the default shell, run with sudo and make sure zsh is installed.')"
    fi
  fi
}

validate_changes() {
  local rc="$TARGET_HOME/.zshrc"
  local ok=yes

  if command -v zsh >/dev/null 2>&1 && [[ -f $rc ]]; then
    if ! run_as_target zsh -n "$rc"; then
      printf '%b %s\n' "$ERR" "$(tr '.zshrc tiene un error de sintaxis.' '.zshrc has a syntax error.')"
      ok=no
    fi
  fi

  if [[ $KITTY_ENABLED == yes && ! -s "$TARGET_HOME/.config/kitty/b3tterterminal.conf" ]]; then
    printf '%b %s\n' "$ERR" "$(tr 'No se encontro la config de Kitty generada.' 'The generated Kitty config was not found.')"
    ok=no
  fi

  if [[ $ok == yes ]]; then
    printf '%b %s\n' "$OK" "$(tr 'Validacion completada.' 'Validation completed.')"
  else
    printf '%b %s\n' "$WARN" "$(tr 'Revisa los avisos anteriores antes de cerrar la terminal.' 'Review the warnings above before closing the terminal.')"
  fi
}

summary_page() {
  page "$(tr Resumen Summary)"
  printf "%s: ${CYAN}%s${NC} (${DIM}%s${NC})\n\n" "$(tr Usuario User)" "$TARGET_USER" "$TARGET_HOME"
  printf "Kitty: %s | %s: %s | %s: %s | %s: %s | %s: %s | %s: %s | %s: %s\n" \
    "$(yes_label "$KITTY_ENABLED")" \
    "$(tr fondo bg)" "$KITTY_BG" \
    "$(tr texto fg)" "$KITTY_FG" \
    "$(tr opacidad opacity)" "$KITTY_OPACITY" \
    "$(tr fuente font)" "$KITTY_FONT_SIZE" \
    "$(tr cursor cursor)" "$KITTY_CURSOR" \
    "$(tr rastro trail)" "$(yes_label "$KITTY_TRAIL")"
  printf "Oh My Posh: %s | %s: %s\n" "$(yes_label "$POSH_ENABLED")" "$(tr tema theme)" "${POSH_THEME:-$(tr 'mantener actual' 'keep current')}"
  printf "LSD aliases: %s | BAT aliases: %s | Fastfetch: %s | %s: %s\n" \
    "$(yes_label "$LSD_ALIASES")" "$(yes_label "$BAT_ALIASES")" "$(yes_label "$FASTFETCH_ENABLED")" "$(tr inicio startup)" "$(yes_label "$FASTFETCH_START")"
  printf "Autosuggestions: %s | %s: %s\n" "$(yes_label "$ZSH_AUTOSUGGEST")" "$(tr 'Sintaxis roja' 'Red syntax')" "$(yes_label "$ZSH_SYNTAX")"
  printf "%s: Kitty=%s | Super+Enter=%s | ZSH=%s\n" "$(tr Predeterminados Defaults)" \
    "$(yes_label "$SET_KITTY_DEFAULT")" "$(yes_label "$SET_KITTY_SHORTCUT")" "$(yes_label "$SET_ZSH_DEFAULT")"
}

apply_changes() {
  page "$(tr 'Aplicando cambios' 'Applying changes')"
  printf "%s %s: ${CYAN}%s${NC} (${DIM}%s${NC})\n\n" "$INFO" "$(tr 'Usuario objetivo' 'Target user')" "$TARGET_USER" "$TARGET_HOME"

  download_posh_theme
  write_zsh_config
  printf '%b %s\n' "$OK" "$(tr 'Configuracion ZSH actualizada.' 'ZSH configuration updated.')"

  write_kitty_config
  if [[ $KITTY_ENABLED == yes ]]; then
    printf '%b %s\n' "$OK" "$(tr 'Configuracion Kitty actualizada.' 'Kitty configuration updated.')"
  else
    printf '%b %s\n' "$OK" "$(tr 'Include de B3tterTerminal retirado de kitty.conf.' 'B3tterTerminal include removed from kitty.conf.')"
  fi

  apply_desktop_changes
  validate_changes

  printf "\n${BOLD}%s${NC}\n" "$(tr 'Listo. Abre una terminal nueva o ejecuta:' 'Done. Open a new terminal or run:')"
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
    choice=$(ask_menu "$(tr 'Menu principal' 'Main menu')" 6 \
      "$(tr 'Editar Kitty' 'Edit Kitty')" \
      "$(tr 'Editar ZSH, aliases y Fastfetch' 'Edit ZSH, aliases and Fastfetch')" \
      "$(tr 'Editar Oh My Posh' 'Edit Oh My Posh')" \
      "$(tr 'Predeterminados y atajos' 'Defaults and shortcuts')" \
      "$(tr 'Aplicar cambios' 'Apply changes')" \
      "$(tr 'Salir sin aplicar' 'Exit without applying')")

    case $choice in
      1) kitty_menu ;;
      2) shell_menu ;;
      3) posh_menu ;;
      4) desktop_menu ;;
      5)
        summary_page
        if ask_yes_no "$(tr 'Aplicar esta configuracion?' 'Apply this configuration?')" yes; then
          apply_changes
          return
        fi
        ;;
      6)
        printf '\n%b %s\n' "$WARN" "$(tr 'Saliendo sin aplicar cambios.' 'Exiting without applying changes.')"
        return
        ;;
    esac
  done
}

main() {
  select_language
  select_target_user
  load_state
  main_menu
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
