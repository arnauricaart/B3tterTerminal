#!/usr/bin/env bash
set -Eeuo pipefail

APP='B3tterTerminal'
START_MARK='# >>> B3TTERTERMINAL START >>>'
END_MARK='# <<< B3TTERTERMINAL END <<<'

# ---------- Visual style ----------
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

LANGUAGE='es'
LOG_FILE="/tmp/b3tterterminal-$(date +%Y%m%d-%H%M%S).log"
TARGET_USER=''
TARGET_HOME=''
TARGET_UID=''
TARGET_GID=''
TARGET_DBUS=''
# Active RGB color cycle for the ASCII header. Override with:
#   sudo B3TTER_ASCII_ANIMATION=no ./b3tterterminal.sh
ASCII_RGB_ANIMATION=${B3TTER_ASCII_ANIMATION:-yes}
ASCII_ANIMATION_PID=''

# ---------- Defaults ----------
INSTALL_ZSH=yes; ZSH_AUTOSUGGEST=yes; ZSH_SYNTAX=yes; ZSH_HISTORY=no; ZSH_DEFAULT=yes
INSTALL_KITTY=yes; KITTY_DEFAULT=yes; KITTY_SHORTCUT=yes
KITTY_BG='#0b0f14'; KITTY_FG='#e6edf3'; KITTY_OPACITY='0.85'; KITTY_FONT_SIZE='11.0'
KITTY_CURSOR='block'; KITTY_TRAIL=no; KITTY_TRAIL_COLOR='#00d7ff'
INSTALL_POSH=yes; POSH_THEME='powerline'; INSTALL_FONT=yes; DISABLE_OLD_PROMPTS=yes
INSTALL_LSD=yes; LSD_ALIASES=yes
INSTALL_BAT=yes; BAT_ALIASES=yes
INSTALL_FASTFETCH=yes; FASTFETCH_START=no

declare -a TASK_LABELS=() TASK_FUNCS=() FAILURES=()

cleanup() {
  stop_ascii_animation
  tput cnorm 2>/dev/null || true
}
trap cleanup EXIT INT TERM

tr() { [[ $LANGUAGE == en ]] && printf '%s' "$2" || printf '%s' "$1"; }
clear_screen() { stop_ascii_animation; printf '\033[2J\033[H'; }

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

left_colored() {
  local colored=$1
  printf '%*s%b\n' "$CONTENT_MARGIN" '' "$colored"
}

declare -a ASCII_ART=(
' ____  _____ _   _             _____                   _             _'
'| __ )|___ /| |_| |_ ___ _ __ |_   _|__ _ __ _ __ ___ (_)_ __   __ _| |'
'|  _ \  |_ \| __| __/ _ \ '\''__|  | |/ _ \ '\''__| '\''_ ` _ \| | '\''_ \ / _` | |'
'| |_) |___) | |_| ||  __/ |     | |  __/ |  | | | | | | | | | | (_| | |'
'|____/|____/ \__|\__\___|_|     |_|\___|_|  |_| |_| |_|_|_| |_|\__,_|_|'
)

draw_ascii_logo() {
  local color=${1:-$CYAN}
  local art
  for art in "${ASCII_ART[@]}"; do
    left_plain "$art" "${color}${BOLD}"
  done
}

ascii_color_loop() {
  # Smooth 256-color rainbow. It redraws only the five logo rows and restores
  # the typing cursor, so the questions remain usable while the logo animates.
  local -a colors=(
    39 45 51 50 49 48 47 46 82 118 154 190 226
    220 214 208 202 196 197 198 199 200 201 165
    129 93 57 21 27 33
  )
  local color art

  while true; do
    for color in "${colors[@]}"; do
      # Save cursor, move to the first row, repaint only the ASCII logo,
      # clear each row's remainder, then restore the user's cursor.
      printf '\033[s\033[H'
      for art in "${ASCII_ART[@]}"; do
        printf '%*s\033[1;38;5;%sm%s\033[0m\033[K\n' \
          "$CONTENT_MARGIN" '' "$color" "$art"
      done
      printf '\033[u'
      sleep 0.12
    done
  done
}

start_ascii_animation() {
  [[ $ASCII_RGB_ANIMATION == yes ]] || return 0
  [[ -t 1 ]] || return 0
  (( $(term_cols) >= 80 )) || return 0

  stop_ascii_animation
  ascii_color_loop &
  ASCII_ANIMATION_PID=$!
}

stop_ascii_animation() {
  if [[ -n ${ASCII_ANIMATION_PID:-} ]] &&
     kill -0 "$ASCII_ANIMATION_PID" 2>/dev/null; then
    kill "$ASCII_ANIMATION_PID" 2>/dev/null || true
    wait "$ASCII_ANIMATION_PID" 2>/dev/null || true
  fi
  ASCII_ANIMATION_PID=''
}

rule() {
  local cols width i
  cols=$(term_cols)
  width=$(( cols - (CONTENT_MARGIN * 2) ))
  (( width > 92 )) && width=92
  (( width < 40 )) && width=40
  printf '%*s%b' "$CONTENT_MARGIN" '' "$DIM"
  for ((i=0; i<width; i++)); do printf '─'; done
  printf '%b\n' "$NC"
}

banner() {
  draw_ascii_logo "$CYAN"
  left_plain "Terminal setup" "${MAGENTA}${BOLD}"
  left_plain 'ZSH · Kitty · Oh My Posh · LSD · BAT · Fastfetch' "$DIM"
  rule
  start_ascii_animation
}

render_section_steps() {
  local current=$1
  local -a names=(ZSH Kitty Posh LSD BAT Fastfetch)
  local i plain='' colored='' item

  for ((i=1; i<=${#names[@]}; i++)); do
    if (( i < current )); then
      item="✓ ${names[i-1]}"
      plain+="$item"
      colored+="${GREEN}${BOLD}${item}${NC}"
    elif (( i == current )); then
      item="◆ ${names[i-1]}"
      plain+="$item"
      colored+="${CYAN}${BOLD}${item}${NC}"
    else
      item="○ ${names[i-1]}"
      plain+="$item"
      colored+="${DIM}${item}${NC}"
    fi

    if (( i < ${#names[@]} )); then
      plain+='  ›  '
      colored+="  ${DIM}›${NC}  "
    fi
  done

  left_colored "$colored"
}

page() {
  local title=$1 step=${2:-}
  local current total step_text

  clear_screen
  banner
  printf '\n'

  if [[ $step =~ ^([0-9]+)/([0-9]+)$ ]]; then
    current=${BASH_REMATCH[1]}
    total=${BASH_REMATCH[2]}
    step_text="$(tr 'PASO' 'STEP') ${current} $(tr 'DE' 'OF') ${total}"
    left_plain "$step_text" "${DIM}${BOLD}"
    render_section_steps "$current"
    printf '\n'
  fi

  left_plain "$title" "${GREEN}${BOLD}"
  rule
  printf '\n\n'
}

typewriter() {
  local text=$1 delay=${2:-0.002} i
  if [[ ! -t 1 ]]; then printf '%s\n' "$text"; return; fi
  for ((i=0; i<${#text}; i++)); do
    printf '%s' "${text:i:1}"
    sleep "$delay"
  done
  printf '\n'
}

press_enter() {
  printf "\n${DIM}%s${NC}" "$(tr 'Pulsa ENTER para continuar…' 'Press ENTER to continue…')"
  read -r _ || true
}

require_root() {
  (( EUID == 0 )) && return 0

  clear_screen
  banner
  printf '\n'
  left_plain 'ROOT REQUIRED / SE REQUIERE ROOT' "${RED}${BOLD}"
  rule
  printf "\n%s\n" "This installer must be started with root privileges."
  printf "%s\n\n" "Este instalador debe iniciarse con privilegios de root."

  printf "${BOLD}Recommended from a normal user / Recomendado desde usuario normal:${NC}\n"
  printf "  ${CYAN}chmod +x %q${NC}\n" "$0"
  printf "  ${CYAN}sudo %q${NC}\n\n" "$0"

  printf "${BOLD}From a root shell / Desde una shell root:${NC}\n"
  printf "  ${CYAN}sudo -i${NC}\n"
  printf "  ${CYAN}B3TTER_USER=kali %q${NC}\n\n" "$0"

  printf "${DIM}When started with sudo, system packages are installed as root, but the personal terminal configuration is applied to the normal user who launched sudo.${NC}\n"
  printf "${DIM}Al iniciarlo con sudo, los paquetes se instalan como root, pero la configuración personal se aplica al usuario normal que lanzó sudo.${NC}\n"
  exit 1
}

ask_yes_no() {
  local question=$1 default=${2:-yes} value
  while true; do
    printf "\n%b %s\n" "$SELECT" "$question"
    if [[ $default == yes ]]; then
      printf "  ${CYAN}1)${NC} %s ${DIM}[%s]${NC}\n  ${CYAN}2)${NC} %s\n" "$(tr Sí Yes)" "$(tr predeterminado default)" "$(tr No No)"
    else
      printf "  ${CYAN}1)${NC} %s\n  ${CYAN}2)${NC} %s ${DIM}[%s]${NC}\n" "$(tr Sí Yes)" "$(tr No No)" "$(tr predeterminado default)"
    fi
    printf '%b ' "$SELECT"
    read -r value || value=''
    [[ -n $value ]] || { [[ $default == yes ]] && return 0 || return 1; }
    case ${value,,} in
      1|y|yes|s|si|sí) return 0 ;;
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
    # UI to stderr: command substitution captures only the selected number.
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
    printf '%b %s\n' "$WARN" "$(tr 'Opción no válida.' 'Invalid option.')" >&2
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

select_language() {
  page 'Choose language / Elegir idioma' ''
  printf "${BOLD}Choose installer language / Elige el idioma del instalador${NC}\n\n"
  printf "  ${CYAN}1)${NC} EN — English\n"
  printf "  ${CYAN}2)${NC} ES — Español ${DIM}[default]${NC}\n\n"
  printf '%b Select EN or ES: ' "$SELECT"
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
  elif [[ -n ${SUDO_USER:-} && ${SUDO_USER:-} != root ]] && getent passwd "$SUDO_USER" >/dev/null; then
    TARGET_USER=$SUDO_USER
  else
    local -a users=() labels=()
    local user home choice
    while IFS=: read -r user _ uid _ _ home shell; do
      [[ $uid -ge 1000 && $uid -lt 60000 ]] || continue
      [[ $shell != */nologin && $shell != */false ]] || continue
      [[ $user == root ]] && continue
      users+=("$user")
    done < <(getent passwd)

    if ((${#users[@]} == 0)); then
      users=(root)
    else
      users+=(root)
    fi

    for user in "${users[@]}"; do
      home=$(getent passwd "$user" | cut -d: -f6)
      labels+=("$user — $home")
    done

    page "$(tr 'Usuario objetivo' 'Target user')" ''
    typewriter "$(tr 'El instalador se ejecuta como root, pero debes elegir qué usuario recibirá la configuración visual y los archivos personales.' 'The installer runs as root, but you must choose which user receives the visual configuration and personal files.')"
    choice=$(ask_menu "$(tr 'Selecciona el usuario que quieres configurar' 'Select the user you want to configure')" 1 "${labels[@]}")
    TARGET_USER=${users[choice-1]}
  fi

  TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
  TARGET_UID=$(id -u "$TARGET_USER")
  TARGET_GID=$(id -g "$TARGET_USER")
  TARGET_DBUS="unix:path=/run/user/${TARGET_UID}/bus"

  [[ -n $TARGET_HOME && $TARGET_HOME == /* ]] || {
    printf '%b %s\n' "$ERR" "$(tr 'No se pudo determinar el directorio HOME.' 'Could not determine the HOME directory.')"
    exit 1
  }

  mkdir -p "$TARGET_HOME"
  export HOME="$TARGET_HOME"
}

run_as_target() {
  if [[ $TARGET_USER == root ]]; then
    env HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" "$@"
  else
    runuser -u "$TARGET_USER" -- env \
      HOME="$TARGET_HOME" \
      USER="$TARGET_USER" \
      LOGNAME="$TARGET_USER" \
      PATH="$TARGET_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin" \
      DISPLAY="${DISPLAY:-}" \
      XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
      DBUS_SESSION_BUS_ADDRESS="$TARGET_DBUS" \
      "$@"
  fi
}

own_target() {
  local path
  for path in "$@"; do
    [[ -e $path || -L $path ]] || continue
    chown -R "$TARGET_UID:$TARGET_GID" "$path"
  done
}

welcome_page() {
  page "$(tr Bienvenida Welcome)" '0/6'
  typewriter "$(tr 'Primero eliges toda la configuración. No se instalará ni modificará nada hasta que confirmes el resumen final.' 'First you choose the complete configuration. Nothing is installed or modified until you confirm the final summary.')"
  printf "\n%s %s\n" "$INFO" "$(tr 'Los paquetes del sistema se instalarán como root.' 'System packages will be installed as root.')"
  printf "%s %s: ${CYAN}%s${NC} (${DIM}%s${NC})\n" "$INFO" "$(tr 'La configuración personal se aplicará a' 'Personal configuration will be applied to')" "$TARGET_USER" "$TARGET_HOME"
  printf "%s %s\n" "$INFO" "$(tr 'La instalación final utiliza una única barra de progreso acumulada.' 'The final installation uses one single cumulative progress bar.')"
  press_enter
}

zsh_page() {
  page ZSH '1/6'
  typewriter "$(tr 'ZSH es una shell interactiva con autocompletado avanzado, plugins y una experiencia más cómoda que una configuración básica de Bash.' 'ZSH is an interactive shell with advanced completion, plugins and a more comfortable experience than a basic Bash setup.')"
  printf "\n${CYAN}${BOLD}%s${NC}\n" "$(tr 'Opciones disponibles' 'Available options')"
  printf "  ${GREEN}autosuggestions${NC}      → %s\n" "$(tr 'sugiere comandos mientras escribes.' 'suggests commands while you type.')"
  printf "  ${GREEN}syntax highlighting${NC}  → %s\n" "$(tr 'colorea comandos válidos e inválidos.' 'colors valid and invalid commands.')"
  printf "  ${GREEN}history repair${NC}       → %s\n" "$(tr 'guarda una copia y crea un historial limpio.' 'backs up and creates a clean history.')"
  printf "  ${GREEN}default shell${NC}        → %s\n" "$(tr 'abre nuevas sesiones usando ZSH.' 'opens new sessions using ZSH.')"

  if ask_yes_no "$(tr '¿Instalar y configurar ZSH?' 'Install and configure ZSH?')" yes; then
    INSTALL_ZSH=yes
    ask_yes_no zsh-autosuggestions yes && ZSH_AUTOSUGGEST=yes || ZSH_AUTOSUGGEST=no
    ask_yes_no "zsh-syntax-highlighting — $(tr 'colores predeterminados' 'default colors')" yes && ZSH_SYNTAX=yes || ZSH_SYNTAX=no
    ask_yes_no "$(tr '¿Respaldar y reparar el historial?' 'Back up and repair history?')" no && ZSH_HISTORY=yes || ZSH_HISTORY=no
    ask_yes_no "$(tr '¿Usar ZSH como shell predeterminada?' 'Use ZSH as the default shell?')" yes && ZSH_DEFAULT=yes || ZSH_DEFAULT=no
  else
    INSTALL_ZSH=no; ZSH_AUTOSUGGEST=no; ZSH_SYNTAX=no; ZSH_HISTORY=no; ZSH_DEFAULT=no
  fi
}

choose_palette() {
  printf "\n${BOLD}%s${NC}\n" "$(tr 'Paletas disponibles' 'Available palettes')"
  printf "  ${CYAN}■${NC} Cyan    ${MAGENTA}■${NC} Purple    ${GREEN}■${NC} Green    ${RED}■${NC} Red\n"

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

choose_opacity() {
  local choice custom
  choice=$(ask_menu "$(tr 'Elige la opacidad' 'Choose opacity')" 3 \
    '1.00 — 100%' '0.90 — 90%' '0.85 — 85%' '0.80 — 80%' '0.70 — 70%' "$(tr 'Valor personalizado' 'Custom value')")

  case $choice in
    1) KITTY_OPACITY=1.00 ;;
    2) KITTY_OPACITY=0.90 ;;
    3) KITTY_OPACITY=0.85 ;;
    4) KITTY_OPACITY=0.80 ;;
    5) KITTY_OPACITY=0.70 ;;
    6)
      while true; do
        custom=$(ask_text "$(tr 'Valor entre 0.10 y 1.00' 'Value between 0.10 and 1.00')" 0.85)
        if awk -v n="$custom" 'BEGIN{exit !(n>=0.10&&n<=1.00)}'; then
          KITTY_OPACITY=$custom
          break
        fi
        printf '\n%b %s\n' "$WARN" "$(tr 'Valor no válido.' 'Invalid value.')"
      done
      ;;
  esac
}

kitty_page() {
  page Kitty '2/6'
  typewriter "$(tr 'Kitty es un emulador de terminal acelerado por GPU con transparencia, pestañas, fuentes Nerd Font y animación del cursor.' 'Kitty is a GPU-accelerated terminal emulator with transparency, tabs, Nerd Fonts and cursor animation.')"
  printf "\n${YELLOW}${BOLD}[!] %s${NC}\n%s\n" \
    "$(tr 'Animación del cursor' 'Cursor animation')" \
    "$(tr 'En VMware se recomienda activar Accelerate 3D Graphics y asignar suficiente RAM y memoria gráfica. No es obligatorio, pero una VM limitada puede mostrar tirones.' 'In VMware, enabling Accelerate 3D Graphics and assigning enough RAM and graphics memory is recommended. It is not mandatory, but a limited VM may stutter.')"

  if ask_yes_no "$(tr '¿Instalar y configurar Kitty?' 'Install and configure Kitty?')" yes; then
    INSTALL_KITTY=yes
    choose_palette
    choose_opacity

    local shape
    shape=$(ask_menu "$(tr 'Forma del cursor' 'Cursor shape')" 1 Block Beam Underline)
    case $shape in
      1) KITTY_CURSOR=block ;;
      2) KITTY_CURSOR=beam ;;
      3) KITTY_CURSOR=underline ;;
    esac

    KITTY_FONT_SIZE=$(ask_text "$(tr 'Tamaño de fuente' 'Font size')" "$KITTY_FONT_SIZE")
    ask_yes_no "$(tr '¿Activar el cursor animado?' 'Enable animated cursor trail?')" no && KITTY_TRAIL=yes || KITTY_TRAIL=no
    ask_yes_no "$(tr '¿Usar Kitty como terminal predeterminada?' 'Use Kitty as the default terminal?')" yes && KITTY_DEFAULT=yes || KITTY_DEFAULT=no
    ask_yes_no "$(tr '¿Crear el atajo Super+Enter?' 'Create the Super+Enter shortcut?')" yes && KITTY_SHORTCUT=yes || KITTY_SHORTCUT=no
  else
    INSTALL_KITTY=no; KITTY_TRAIL=no; KITTY_DEFAULT=no; KITTY_SHORTCUT=no
  fi
}

choose_theme() {
  local choice
  choice=$(ask_menu "$(tr 'Elige el tema' 'Choose the theme')" 1 \
    "powerline — $(tr 'actual/predeterminado' 'current/default')" \
    jandedobbeleer atomic paradox clean-detailed "$(tr 'Nombre personalizado' 'Custom name')")

  case $choice in
    1) POSH_THEME=powerline ;;
    2) POSH_THEME=jandedobbeleer ;;
    3) POSH_THEME=atomic ;;
    4) POSH_THEME=paradox ;;
    5) POSH_THEME=clean-detailed ;;
    6) POSH_THEME=$(ask_text "$(tr 'Nombre sin .omp.json' 'Name without .omp.json')" powerline) ;;
  esac
}

posh_page() {
  page 'Oh My Posh' '3/6'
  typewriter "$(tr 'Oh My Posh transforma el prompt y puede mostrar usuario, carpeta, Git, duración y estado del último comando.' 'Oh My Posh transforms the prompt and can show user, folder, Git, duration and the last command status.')"

  if ask_yes_no "$(tr '¿Instalar Oh My Posh?' 'Install Oh My Posh?')" yes; then
    INSTALL_POSH=yes
    choose_theme
    ask_yes_no "$(tr '¿Instalar Meslo Nerd Font?' 'Install Meslo Nerd Font?')" yes && INSTALL_FONT=yes || INSTALL_FONT=no
    ask_yes_no "$(tr '¿Desactivar inicializaciones anteriores de Starship/Oh My Posh para evitar prompts duplicados?' 'Disable previous Starship/Oh My Posh initializations to avoid duplicate prompts?')" yes && DISABLE_OLD_PROMPTS=yes || DISABLE_OLD_PROMPTS=no
  else
    INSTALL_POSH=no; INSTALL_FONT=no; DISABLE_OLD_PROMPTS=no
  fi
}

lsd_page() {
  page LSD '4/6'
  typewriter "$(tr 'LSD es como ls pero con esteroides: añade iconos, colores, listados detallados y vista en árbol.' 'LSD is like ls on steroids: it adds icons, colors, detailed listings and tree view.')"
  printf "\n  ls → lsd\n  ls -l → lsd -l\n  ll → lsd -la\n  lt → lsd --tree\n"

  if ask_yes_no "$(tr '¿Instalar LSD?' 'Install LSD?')" yes; then
    INSTALL_LSD=yes
    ask_yes_no "$(tr '¿Hacer que ls use LSD mediante aliases?' 'Make ls use LSD through aliases?')" yes && LSD_ALIASES=yes || LSD_ALIASES=no
  else
    INSTALL_LSD=no; LSD_ALIASES=no
  fi
}

bat_page() {
  page BAT '5/6'
  typewriter "$(tr 'BAT es como cat pero mejorado: resalta sintaxis, muestra números de línea y presenta los archivos de forma más legible.' 'BAT is like cat but upgraded: it highlights syntax, shows line numbers and presents files more clearly.')"
  printf "\n  cat file → batcat --paging=never file\n  catn file → batcat --style=numbers file\n  catp file → batcat --plain file\n"
  printf "\n%s %s\n" "$INFO" "$(tr 'El alias solo afecta a ZSH interactivo; no reemplaza /usr/bin/cat ni modifica scripts.' 'The alias only affects interactive ZSH; it does not replace /usr/bin/cat or modify scripts.')"

  if ask_yes_no "$(tr '¿Instalar BAT?' 'Install BAT?')" yes; then
    INSTALL_BAT=yes
    ask_yes_no "$(tr '¿Hacer que cat use BAT mediante aliases?' 'Make cat use BAT through aliases?')" yes && BAT_ALIASES=yes || BAT_ALIASES=no
  else
    INSTALL_BAT=no; BAT_ALIASES=no
  fi
}

fastfetch_page() {
  page Fastfetch '6/6'
  typewriter "$(tr 'Fastfetch muestra visualmente la distribución, kernel, CPU, RAM, shell, terminal y otros datos del sistema.' 'Fastfetch visually displays the distribution, kernel, CPU, RAM, shell, terminal and other system information.')"

  if ask_yes_no "$(tr '¿Instalar Fastfetch?' 'Install Fastfetch?')" yes; then
    INSTALL_FASTFETCH=yes
    ask_yes_no "$(tr '¿Ejecutarlo al abrir cada terminal?' 'Run it whenever a terminal opens?')" no && FASTFETCH_START=yes || FASTFETCH_START=no
  else
    INSTALL_FASTFETCH=no; FASTFETCH_START=no
  fi
}

yn() { [[ $1 == yes ]] && tr Sí Yes || tr No No; }

summary_page() {
  page "$(tr 'Resumen final' 'Final summary')" ''
  printf "${BOLD}%s${NC}\n\n" "$(tr 'Todavía no se ha instalado ni modificado nada.' 'Nothing has been installed or modified yet.')"
  printf "  ${CYAN}%s${NC}: %s — %s\n\n" "$(tr Usuario User)" "$TARGET_USER" "$TARGET_HOME"
  printf "  ${CYAN}ZSH${NC}: %s | autosuggest: %s | syntax: %s | history: %s | default: %s\n" "$(yn "$INSTALL_ZSH")" "$(yn "$ZSH_AUTOSUGGEST")" "$(yn "$ZSH_SYNTAX")" "$(yn "$ZSH_HISTORY")" "$(yn "$ZSH_DEFAULT")"
  printf "  ${CYAN}Kitty${NC}: %s | opacity: %s | cursor: %s | trail: %s | default: %s\n" "$(yn "$INSTALL_KITTY")" "$KITTY_OPACITY" "$KITTY_CURSOR" "$(yn "$KITTY_TRAIL")" "$(yn "$KITTY_DEFAULT")"
  printf "  ${CYAN}Oh My Posh${NC}: %s | theme: %s | font: %s\n" "$(yn "$INSTALL_POSH")" "$POSH_THEME" "$(yn "$INSTALL_FONT")"
  printf "  ${CYAN}LSD${NC}: %s | aliases: %s\n" "$(yn "$INSTALL_LSD")" "$(yn "$LSD_ALIASES")"
  printf "  ${CYAN}BAT${NC}: %s | aliases: %s\n" "$(yn "$INSTALL_BAT")" "$(yn "$BAT_ALIASES")"
  printf "  ${CYAN}Fastfetch${NC}: %s | startup: %s\n" "$(yn "$INSTALL_FASTFETCH")" "$(yn "$FASTFETCH_START")"
  rule

  ask_yes_no "$(tr '¿Empezar ahora la instalación completa?' 'Start the complete installation now?')" yes || {
    printf '\n%b %s\n' "$WARN" "$(tr 'Cancelado sin realizar cambios.' 'Cancelled without making changes.')"
    exit 0
  }
}

backup_file() {
  [[ ! -f $1 ]] || cp -a "$1" "$1.backup.$(date +%Y%m%d-%H%M%S)"
}

resolve_bat_pkg() {
  apt-cache show bat >/dev/null 2>&1 && printf bat || {
    apt-cache show cat-bat >/dev/null 2>&1 && printf cat-bat || printf bat
  }
}

task_apt_update() {
  apt-get update
}

task_install_packages() {
  local -a p=(curl unzip ca-certificates coreutils fontconfig xdg-utils git)
  [[ $INSTALL_ZSH == yes ]] && p+=(zsh)
  [[ $ZSH_AUTOSUGGEST == yes ]] && p+=(zsh-autosuggestions)
  [[ $ZSH_SYNTAX == yes ]] && p+=(zsh-syntax-highlighting)
  [[ $INSTALL_KITTY == yes ]] && p+=(kitty)
  [[ $INSTALL_LSD == yes ]] && p+=(lsd)
  [[ $INSTALL_BAT == yes ]] && p+=("$(resolve_bat_pkg)")
  [[ $INSTALL_FASTFETCH == yes ]] && p+=(fastfetch)
  env DEBIAN_FRONTEND=noninteractive apt-get install -y "${p[@]}"
}

task_install_posh() {
  run_as_target bash -c 'set -o pipefail; mkdir -p "$HOME/.local/bin" && curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"'
}

task_theme() {
  local dir="$TARGET_HOME/.config/oh-my-posh" dest="$TARGET_HOME/.config/oh-my-posh/b3tterterminal.omp.json"
  local url="https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/${POSH_THEME}.omp.json"
  local fallback='https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/powerline.omp.json'

  mkdir -p "$dir"
  curl -fsSL "$url" -o "$dest" || curl -fsSL "$fallback" -o "$dest"
  own_target "$dir"
}

task_font() {
  run_as_target bash -c '
    set -e
    mkdir -p "$HOME/.local/share/fonts/Meslo"
    zip=$(mktemp --suffix=.zip)
    curl -fL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip -o "$zip"
    unzip -oq "$zip" -d "$HOME/.local/share/fonts/Meslo"
    rm -f "$zip"
    fc-cache -f >/dev/null 2>&1 || true
  '
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

task_zsh_config() {
  local rc="$TARGET_HOME/.zshrc" tmp
  tmp=$(mktemp)

  if [[ ! -f $rc ]]; then
    [[ -r /etc/skel/.zshrc ]] && cp /etc/skel/.zshrc "$rc" || touch "$rc"
  fi

  backup_file "$rc"
  strip_blocks "$rc" "$tmp"

  if [[ $INSTALL_POSH == yes && $DISABLE_OLD_PROMPTS == yes ]]; then
    awk '/oh-my-posh init zsh|starship init zsh/{print "# [B3tterTerminal disabled] "$0;next}{print}' "$tmp" > "$tmp.clean"
    mv "$tmp.clean" "$tmp"
  fi

  mv "$tmp" "$rc"
  mkdir -p "$TARGET_HOME/.config/b3tterterminal"
  [[ $FASTFETCH_START == yes ]] && touch "$TARGET_HOME/.config/b3tterterminal/show-fastfetch" || rm -f "$TARGET_HOME/.config/b3tterterminal/show-fastfetch"

  {
    printf '\n%s\n' "$START_MARK"
    printf '%s\n' 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"' '[[ "$TERM" == *256color* ]] || export TERM=xterm-256color' ''

    if [[ $INSTALL_LSD == yes && $LSD_ALIASES == yes ]]; then
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

    if [[ $INSTALL_BAT == yes && $BAT_ALIASES == yes ]]; then
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

    if [[ $INSTALL_FASTFETCH == yes ]]; then
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

    if [[ $INSTALL_POSH == yes ]]; then
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
# A visible gray is chosen deliberately so suggestions do not disappear
# against the selected dark Kitty palette.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=245'
ZSH_AUTOSUGGEST_STRATEGY=(history)
ZSH_AUTOSUGGEST_USE_ASYNC=1

: ${HISTFILE:="$HOME/.zsh_history"}
: ${HISTSIZE:=10000}
: ${SAVEHIST:=10000}

if (( ! ${+functions[_zsh_autosuggest_start]} )); then
  for f in     /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh     /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
    if [[ -r $f ]]; then
      source "$f"
      break
    fi
  done
fi

# Right arrow or Ctrl+F accepts the visible suggestion.
bindkey -M emacs '^[[C' forward-char 2>/dev/null || true
bindkey -M viins '^[[C' forward-char 2>/dev/null || true
bindkey -M emacs '^F' forward-char 2>/dev/null || true
bindkey -M viins '^F' forward-char 2>/dev/null || true

Z
    fi

    if [[ $ZSH_SYNTAX == yes ]]; then
      command cat <<'Z'
# zsh-syntax-highlighting must be loaded at the end of the interactive config.
# Keep the official/default color palette from the installed plugin.
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
Z
    fi

    printf '%s\n' "$END_MARK"
  } >> "$rc"

  chmod 600 "$rc"
  own_target "$rc" "$TARGET_HOME/.config/b3tterterminal"
}

task_history() {
  local h="$TARGET_HOME/.zsh_history"
  [[ ! -f $h ]] || mv "$h" "$h.backup.$(date +%Y%m%d-%H%M%S)"
  : > "$h"
  chmod 600 "$h"
  own_target "$h" "$h.backup."* 2>/dev/null || true
}

task_kitty_config() {
  local dir="$TARGET_HOME/.config/kitty"
  local main="$dir/kitty.conf"
  local studio="$dir/b3tterterminal.conf"
  local tmp

  mkdir -p "$dir"
  touch "$main"
  backup_file "$main"
  tmp=$(mktemp)
  grep -vE '^[[:space:]]*include[[:space:]]+(kalishell-forge|kaliterm-studio|b3tterterminal)\.conf[[:space:]]*$' "$main" > "$tmp" || true
  mv "$tmp" "$main"
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

  if [[ $INSTALL_ZSH == yes ]] || command -v zsh >/dev/null 2>&1; then
    printf 'shell %s\n' "$(command -v zsh || printf zsh)" >> "$studio"
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

task_xfce() {
  command -v xfconf-query >/dev/null 2>&1 || return 0

  run_as_target xfconf-query -c xfwm4 -p /general/use_compositing -n -t bool -s true >/dev/null 2>&1 || true

  if [[ $KITTY_SHORTCUT == yes ]]; then
    run_as_target xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Super>Return' -r -R >/dev/null 2>&1 || true
    run_as_target xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Super>Return' -n -t string -s /usr/bin/kitty >/dev/null 2>&1 || true
  fi

  if [[ $KITTY_DEFAULT == yes ]]; then
    local helpers="$TARGET_HOME/.local/share/xfce4/helpers"
    local conf="$TARGET_HOME/.config/xfce4"
    local h="$conf/helpers.rc" tmp

    mkdir -p "$helpers" "$conf"
    command cat > "$helpers/kitty.desktop" <<'D'
[Desktop Entry]
NoDisplay=true
Version=1.0
Type=X-XFCE-Helper
Name=Kitty
X-XFCE-Category=TerminalEmulator
X-XFCE-Commands=/usr/bin/kitty
X-XFCE-CommandsWithParameter=/usr/bin/kitty --hold -e "%s"
D

    touch "$h"
    backup_file "$h"
    tmp=$(mktemp)
    grep -v '^TerminalEmulator=' "$h" > "$tmp" || true
    printf 'TerminalEmulator=kitty\n' >> "$tmp"
    mv "$tmp" "$h"
    own_target "$helpers" "$conf"
  fi
}

task_defaults() {
  if [[ $INSTALL_KITTY == yes && $KITTY_DEFAULT == yes && -x /usr/bin/kitty ]]; then
    update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/kitty 90
    update-alternatives --set x-terminal-emulator /usr/bin/kitty
  fi

  if [[ $INSTALL_ZSH == yes && $ZSH_DEFAULT == yes ]]; then
    chsh -s "$(command -v zsh)" "$TARGET_USER"
  fi
}

task_validate() {
  if [[ $INSTALL_ZSH == yes ]]; then
    run_as_target zsh -n "$TARGET_HOME/.zshrc"

    if [[ $ZSH_AUTOSUGGEST == yes ]]; then
      run_as_target zsh -ic '
        (( ${+functions[_zsh_autosuggest_start]} )) || return 1
        [[ ${ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE-} == *245* ]] || return 1
        [[ ${ZSH_AUTOSUGGEST_STRATEGY[1]-} == history ]] || return 1
      '
    fi

    if [[ $ZSH_SYNTAX == yes ]]; then
      run_as_target zsh -ic '
        (( ${+functions[_zsh_highlight_main]} || ${+functions[_zsh_highlight]} ))
      '
    fi
  fi

  [[ $INSTALL_KITTY != yes ]] || [[ -s "$TARGET_HOME/.config/kitty/b3tterterminal.conf" ]]
  [[ $INSTALL_POSH != yes ]] || [[ -x "$TARGET_HOME/.local/bin/oh-my-posh" ]]
  [[ $INSTALL_LSD != yes ]] || command -v lsd >/dev/null
  [[ $INSTALL_BAT != yes ]] || { command -v batcat >/dev/null || command -v bat >/dev/null; }
  [[ $INSTALL_FASTFETCH != yes ]] || command -v fastfetch >/dev/null
}

add_task() {
  TASK_LABELS+=("$1")
  TASK_FUNCS+=("$2")
}

build_tasks() {
  TASK_LABELS=()
  TASK_FUNCS=()
  FAILURES=()

  add_task "$(tr 'Actualizar repositorios' 'Update package repositories')" task_apt_update
  add_task "$(tr 'Instalar paquetes seleccionados' 'Install selected packages')" task_install_packages

  if [[ $INSTALL_POSH == yes ]]; then
    add_task "$(tr 'Instalar Oh My Posh' 'Install Oh My Posh')" task_install_posh
    add_task "$(tr 'Descargar el tema' 'Download the theme')" task_theme
    [[ $INSTALL_FONT == yes ]] && add_task "$(tr 'Instalar Meslo Nerd Font' 'Install Meslo Nerd Font')" task_font
  fi

  [[ $ZSH_HISTORY == yes ]] && add_task "$(tr 'Respaldar y reparar el historial' 'Back up and repair history')" task_history

  if [[ $INSTALL_ZSH == yes || $INSTALL_LSD == yes || $INSTALL_BAT == yes || $INSTALL_FASTFETCH == yes || $INSTALL_POSH == yes ]]; then
    add_task "$(tr 'Escribir la configuración de ZSH' 'Write ZSH configuration')" task_zsh_config
  fi

  if [[ $INSTALL_KITTY == yes ]]; then
    add_task "$(tr 'Escribir la configuración de Kitty' 'Write Kitty configuration')" task_kitty_config
    add_task "$(tr 'Integrar Kitty con XFCE' 'Integrate Kitty with XFCE')" task_xfce
  fi

  [[ $ZSH_DEFAULT == yes || $KITTY_DEFAULT == yes ]] && add_task "$(tr 'Aplicar aplicaciones predeterminadas' 'Apply default applications')" task_defaults
  add_task "$(tr 'Validar la instalación' 'Validate installation')" task_validate
}

draw_single_progress() {
  local completed=$1 total=$2 label=$3 frame=${4:-' '}
  local width=36 filled empty percent i

  (( total > 0 )) || total=1
  filled=$(( completed * width / total ))
  empty=$(( width - filled ))
  percent=$(( completed * 100 / total ))

  printf '\r\033[2K'
  printf "${CYAN}["
  for ((i=0; i<filled; i++)); do printf '█'; done
  for ((i=0; i<empty; i++)); do printf '░'; done
  printf "]${NC} ${BOLD}%3d%%${NC}  ${MAGENTA}%s${NC} ${DIM}%s${NC}" "$percent" "$frame" "$label"
}

run_task_with_single_bar() {
  local completed=$1 total=$2 label=$3 fn=$4
  local pid status frame=0
  local -a frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

  ( "$fn" ) >> "$LOG_FILE" 2>&1 &
  pid=$!
  tput civis 2>/dev/null || true

  while kill -0 "$pid" 2>/dev/null; do
    draw_single_progress "$completed" "$total" "$label" "${frames[frame]}"
    frame=$(( (frame + 1) % ${#frames[@]} ))
    sleep 0.08
  done

  if wait "$pid"; then
    status=0
    draw_single_progress "$((completed + 1))" "$total" "$label" '✓'
  else
    status=$?
    draw_single_progress "$((completed + 1))" "$total" "$label" '!'
  fi

  sleep 0.15
  tput cnorm 2>/dev/null || true
  return "$status"
}

install_page() {
  page "$(tr Instalación Installation)" ''
  build_tasks
  : > "$LOG_FILE"

  local total=${#TASK_LABELS[@]} i label fn
  printf "${BOLD}%s${NC}\n" "$(tr 'Instalando toda la selección para el usuario:' 'Installing the full selection for user:')"
  printf "  ${CYAN}%s${NC} — ${DIM}%s${NC}\n\n" "$TARGET_USER" "$TARGET_HOME"

  draw_single_progress 0 "$total" "$(tr 'Preparando…' 'Preparing…')" '·'

  for ((i=0; i<total; i++)); do
    label=${TASK_LABELS[i]}
    fn=${TASK_FUNCS[i]}
    if ! run_task_with_single_bar "$i" "$total" "$label" "$fn"; then
      FAILURES+=("$label")
    fi
  done

  draw_single_progress "$total" "$total" "$(tr 'Instalación completada' 'Installation complete')" '✓'
  printf '\n\n'

  if ((${#FAILURES[@]} == 0)); then
    printf "${GREEN}${BOLD}[+] %s${NC}\n" "$(tr 'B3tterTerminal terminó correctamente.' 'B3tterTerminal completed successfully.')"
  else
    printf "${YELLOW}${BOLD}[!] %s${NC}\n" "$(tr 'Terminó con errores. Revisa:' 'Finished with errors. Check:')"
    printf '  - %s\n' "${FAILURES[@]}"
    printf '%s Log: %s\n' "$INFO" "$LOG_FILE"
  fi

  printf "\n${BOLD}%s${NC}\n" "$(tr 'Cómo aplicar los cambios' 'How to apply the changes')"

  if [[ $TARGET_USER == root ]]; then
    printf "\n${CYAN}%s${NC}\n" "$(tr 'Si vas a usar la terminal como root:' 'If you will use the terminal as root:')"
    printf "  ${CYAN}exec zsh${NC}\n"
    [[ $INSTALL_KITTY == yes ]] && printf "  ${CYAN}kitty${NC}\n"
  else
    printf "\n${CYAN}%s${NC}\n" "$(tr 'Desde tu usuario normal:' 'From your normal user:')"
    printf "  ${CYAN}exec zsh${NC}\n"
    [[ $INSTALL_KITTY == yes ]] && printf "  ${CYAN}kitty${NC}\n"

    printf "\n${CYAN}%s${NC}\n" "$(tr 'Si ahora mismo estás dentro de una shell root:' 'If you are currently inside a root shell:')"
    printf "  ${CYAN}su - %s${NC}\n" "$TARGET_USER"
    printf "  ${CYAN}exec zsh${NC}\n"
  fi

  [[ $KITTY_SHORTCUT == yes ]] && printf "\n${CYAN}Super + Enter${NC} — %s\n" "$(tr 'abrir Kitty' 'open Kitty')"

  if [[ $ZSH_AUTOSUGGEST == yes ]]; then
    printf "\n${BOLD}%s${NC}\n" "$(tr 'Comprobar autosuggestions' 'Test autosuggestions')"
    printf "  1. ${CYAN}echo b3tter-autosuggestion${NC}\n"
    printf "  2. %s ${CYAN}echo kali${NC}\n" "$(tr 'Escribe' 'Type')"
    printf "  3. %s ${CYAN}→${NC} %s ${CYAN}Ctrl+F${NC}\n" "$(tr 'Acepta la sugerencia con' 'Accept the suggestion with')" "$(tr 'o' 'or')"
  fi

  printf "\n${BOLD}%s${NC}\n" "$(tr 'Cómo volver a ejecutar el instalador' 'How to run the installer again')"
  printf "  ${DIM}%s${NC}\n" "$(tr 'Desde un usuario normal (recomendado):' 'From a normal user (recommended):')"
  printf "  ${CYAN}sudo ./%s${NC}\n" "$(basename "$0")"
  printf "  ${DIM}%s${NC}\n" "$(tr 'Desde root indicando el usuario objetivo:' 'From root specifying the target user:')"
  printf "  ${CYAN}B3TTER_USER=%s ./%s${NC}\n" "$TARGET_USER" "$(basename "$0")"

  printf "\n${DIM}%s${NC}\n" "$(tr 'Puede ser necesario cerrar sesión y volver a entrar para que XFCE y la shell predeterminada se actualicen.' 'You may need to sign out and back in for XFCE and the default shell to refresh.')"
}

main() {
  require_root
  select_language
  select_target_user
  welcome_page
  zsh_page
  kitty_page
  posh_page
  lsd_page
  bat_page
  fastfetch_page
  summary_page
  install_page
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
