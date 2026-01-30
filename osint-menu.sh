#!/bin/bash

# ========= НАСТРОЙКИ =========
RESULTS_DIR="$HOME/osint-results"
LOG_DIR="$RESULTS_DIR/logs"
TOR_PROXY="socks5://127.0.0.1:9050"
USE_TOR=0

# Пути к проектам (при необходимости поправь)
SHERLOCK_ENV="$HOME/sherlock-env/bin/activate"
MAIGRET_ENV="$HOME/maigret-env/bin/activate"
HOLEHE_ENV="$HOME/holehe-env/bin/activate"
PHONEINFOGA_ENV="$HOME/phoneinfoga-env/bin/activate"

HOLEHE_DIR="$HOME/holehe"
PHONEINFOGA_DIR="$HOME/phoneinfoga"
SHERLOCK_DIR="$HOME/sherlock"

# ========= ЦВЕТА =========
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
RESET="\e[0m"

mkdir -p "$RESULTS_DIR" "$LOG_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_DIR/osint.log"
}

apply_tor() {
  if [ "$USE_TOR" -eq 1 ]; then
    export http_proxy="$TOR_PROXY"
    export https_proxy="$TOR_PROXY"
    log "Tor-прокси включён: $TOR_PROXY"
  else
    unset http_proxy
    unset https_proxy
  fi
}

banner() {
  clear
  echo -e "${CYAN}"
  echo      "██╗  ██╗ ██████╗ ███████╗██╗███╗   ██╗████████╗"
  echo      "██║  ██║██╔═══██╗██╔════╝██║████╗  ██║╚══██╔══╝"
  echo      "███████║██║   ██║███████╗██║██╔██╗ ██║   ██║   "
  echo      "██╔══██║██║   ██║╚════██║██║██║╚██╗██║   ██║   "
  echo      "██║  ██║╚██████╔╝███████║██║██║ ╚████║   ██║   "
  echo      "╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝╚═╝  ╚═══╝   ╚═╝   "
  echo -e "${RESET}"
  echo -e "${GREEN}         OSINT MENU BY PARAXXDOXX${RESET}"
  echo ""
}

pause() {
  echo ""
  read -p "Нажми Enter, чтобы вернуться в меню..." _
}

check_dep() {
  command -v "$1" >/dev/null 2>&1
}

check_requirements() {
  MISSING=0
  for cmd in python3 git chromium; do
    if ! check_dep "$cmd"; then
      echo -e "${RED}Не найдено: $cmd${RESET}"
      MISSING=1
    fi
  done
  if [ "$MISSING" -eq 1 ]; then
    echo -e "${YELLOW}Установи недостающие зависимости и перезапусти скрипт.${RESET}"
    exit 1
  fi
}

html_header() {
  local title="$1"
  cat <<EOF
<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<title>${title}</title>
<style>
body { background:#020202; color:#00ff66; font-family: monospace; padding:20px; }
h1,h2,h3 { color:#00ff88; }
.block { border:1px solid #00ff66; padding:10px; margin-bottom:15px; }
pre { background:#050505; padding:10px; overflow-x:auto; }
.tag { color:#ff00aa; }
.small { color:#888; font-size:12px; }
</style>
</head>
<body>
<h1>OSINT Report — ${title}</h1>
<div class="small">Generated: $(date)</div>
<hr>
EOF
}

html_footer() {
  cat <<EOF
</body>
</html>
EOF
}

generate_fullscan_report() {
    local target="$1"
    local dir="$2"
    local report_html="$dir/report.html"
    local report_pdf="$dir/report.pdf"

    {
        html_header "Fullscan: $target"

        echo '<div class="block"><h2>Target</h2>'
        echo "<p><span class=\"tag\">ID:</span> ${target}</p>"
        echo "</div>"

        for file in sherlock.txt maigret.csv holehe.txt phone.txt; do
            if [ -f "$dir/$file" ]; then
                echo "<div class=\"block\"><h2>${file}</h2><pre>"
                sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g' "$dir/$file"
                echo "</pre></div>"
            fi
        done

        html_footer
    } > "$report_html"

    chromium --headless --disable-gpu --print-to-pdf="$report_pdf" "file://$report_html" && \
        log "PDF отчёт создан: $report_pdf" || \
        log "Не удалось создать PDF отчёт (Chromium)."

    # 🔥 Авто‑открытие HTML‑отчёта
    if command -v xdg-open >/dev/null; then
        xdg-open "$report_html" >/dev/null 2>&1 &
    else
        echo -e "${YELLOW}Открой отчёт вручную: $report_html${RESET}"
    fi
}

menu() {
  banner
  echo -e "${GREEN}1${RESET} — Sherlock (никнейм)"
  echo -e "${GREEN}2${RESET} — Maigret (никнейм)"
  echo -e "${GREEN}3${RESET} — Holehe (email)"
  echo -e "${GREEN}4${RESET} — PhoneInfoga (телефон)"
  echo -e "${GREEN}5${RESET} — Массовый поиск по списку никнеймов (Sherlock)"
  echo -e "${GREEN}6${RESET} — Полный OSINT-скан (ник + email + телефон + отчёт)"
  echo -e "${GREEN}7${RESET} — Обновить инструменты"
  echo -e "${GREEN}8${RESET} — Переключить Tor (сейчас: $( [ "$USE_TOR" -eq 1 ] && echo "ON" || echo "OFF" ))"
  echo -e "${GREEN}0${RESET} — Выход"
  echo ""
  read -p "Выбор: " choice
}

run_sherlock() {
  apply_tor
  if [ ! -f "$SHERLOCK_ENV" ]; then
    echo -e "${RED}Не найдено окружение Sherlock: $SHERLOCK_ENV${RESET}"
    return
  fi
  source "$SHERLOCK_ENV"
  read -p "Никнейм: " nick
  [ -z "$nick" ] && return
  local outdir="$RESULTS_DIR/sherlock"
  mkdir -p "$outdir"
  log "Запуск Sherlock для никнейма: $nick"
  python3 -m sherlock_project "$nick" | tee "$outdir/$nick.txt"
  echo -e "${GREEN}Результат: $outdir/$nick.txt${RESET}"
}

run_maigret() {
  apply_tor
  if [ ! -f "$MAIGRET_ENV" ]; then
    echo -e "${RED}Не найдено окружение Maigret: $MAIGRET_ENV${RESET}"
    return
  fi
  source "$MAIGRET_ENV"
  read -p "Никнейм: " nick
  [ -z "$nick" ] && return
  local outdir="$RESULTS_DIR/maigret"
  mkdir -p "$outdir"
  log "Запуск Maigret для никнейма: $nick"
  maigret "$nick" --csv -o "$outdir/$nick.csv"
  echo -e "${GREEN}CSV: $outdir/$nick.csv${RESET}"
}

run_holehe() {
  apply_tor
  if [ ! -f "$HOLEHE_ENV" ]; then
    echo -e "${RED}Не найдено окружение Holehe: $HOLEHE_ENV${RESET}"
    return
  fi
  source "$HOLEHE_ENV"
  cd "$HOLEHE_DIR" || { echo -e "${RED}Нет директории $HOLEHE_DIR${RESET}"; return; }
  read -p "Email: " email
  [ -z "$email" ] && return
  local outdir="$RESULTS_DIR/holehe"
  mkdir -p "$outdir"
  log "Запуск Holehe для email: $email"
  holehe "$email" | tee "$outdir/$email.txt"
  echo -e "${GREEN}Результат: $outdir/$email.txt${RESET}"
}

send_report_to_telegram() {
    local dir="$1"
    local bot_token="8101765387:AAEpX93AAR4uZ7-u6_UYQ2__qhV99ic2aLs"
    local chat_id="5067005754"

    if [ -f "$dir/report.pdf" ]; then
        curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendDocument" \
            -F chat_id="${chat_id}" \
            -F document=@"$dir/report.pdf" \
            -F caption="OSINT отчёт: $(basename "$dir")"
    fi

    if [ -f "$dir/report.html" ]; then
        curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendDocument" \
            -F chat_id="${chat_id}" \
            -F document=@"$dir/report.html"
    fi
}


run_phoneinfoga() {
    clear
    banner
    echo -e "${GREEN}PhoneInfoga (Docker)${RESET}"
    echo
    read -p "Введи номер телефона (в формате +79991234567): " phone

    if [ -z "$phone" ]; then
        echo -e "${RED}Номер не введён.${RESET}"
        read -p "Нажми Enter, чтобы вернуться в меню..."
        return
    fi

    log "Запуск PhoneInfoga для номера: $phone"

    mkdir -p "$RESULTS_DIR/phoneinfoga"

    echo -e "${YELLOW}Сканирование... Пожалуйста, подожди.${RESET}"
    sudo docker run --rm sundowndev/phoneinfoga scan -n "$phone" | tee "$RESULTS_DIR/phoneinfoga/phone.txt"

    echo
    echo -e "${GREEN}Готово! Результат сохранён в phone.txt${RESET}"
    read -p "Нажми Enter, чтобы вернуться в меню..."
}


run_bulk_sherlock() {
  apply_tor
  if [ ! -f "$SHERLOCK_ENV" ]; then
    echo -e "${RED}Не найдено окружение Sherlock: $SHERLOCK_ENV${RESET}"
    return
  fi
  source "$SHERLOCK_ENV"
  read -p "Путь к файлу со списком никнеймов: " file
  if [ ! -f "$file" ]; then
    echo -e "${RED}Файл не найден.${RESET}"
    return
  fi
  local outdir="$RESULTS_DIR/bulk-sherlock"
  mkdir -p "$outdir"
  log "Массовый Sherlock по файлу: $file"
  while read -r nick; do
    [ -z "$nick" ] && continue
    echo -e "${BLUE}→ $nick${RESET}"
    python3 -m sherlock_project "$nick" | tee "$outdir/$nick.txt"
  done < "$file"
  echo -e "${GREEN}Массовый поиск завершён. Результаты: $outdir${RESET}"
}

run_fullscan() {
  apply_tor
  read -p "Никнейм: " nick
  read -p "Email: " email
  read -p "Телефон: " phone
  [ -z "$nick" ] && [ -z "$email" ] && [ -z "$phone" ] && return

  local dir="$RESULTS_DIR/fullscan-$nick-$(date '+%Y%m%d-%H%M%S')"
  mkdir -p "$dir"
  log "Полный OSINT-скан: nick=$nick email=$email phone=$phone"

  # Sherlock
  if [ -f "$SHERLOCK_ENV" ] && [ -n "$nick" ]; then
    echo -e "${BLUE}→ Sherlock...${RESET}"
    source "$SHERLOCK_ENV"
    python3 -m sherlock_project "$nick" | tee "$dir/sherlock.txt"
  fi

  # Maigret
  if [ -f "$MAIGRET_ENV" ] && [ -n "$nick" ]; then
    echo -e "${BLUE}→ Maigret...${RESET}"
    source "$MAIGRET_ENV"
    maigret "$nick" --csv -o "$dir/maigret.csv"
  fi

  # Holehe
  if [ -f "$HOLEHE_ENV" ] && [ -n "$email" ]; then
    echo -e "${BLUE}→ Holehe...${RESET}"
    source "$HOLEHE_ENV"
    cd "$HOLEHE_DIR" || true
    holehe "$email" | tee "$dir/holehe.txt"
  fi

  # PhoneInfoga
  if [ -f "$PHONEINFOGA_ENV" ] && [ -n "$phone" ]; then
    echo -e "${BLUE}→ PhoneInfoga...${RESET}"
    source "$PHONEINFOGA_ENV"
    cd "$PHONEINFOGA_DIR" || true
    python3 phoneinfoga.py -n "$phone" | tee "$dir/phone.txt"
  fi

  generate_fullscan_report "$nick" "$dir"
  echo -e "${GREEN}Полный скан завершён. Папка: $dir${RESET}"
  send_report_to_telegram "$report_dir"
}


update_tools() {
  log "Обновление инструментов..."
  if [ -d "$SHERLOCK_DIR/.git" ]; then
    echo -e "${YELLOW}Обновление Sherlock...${RESET}"
    cd "$SHERLOCK_DIR" && git pull
  fi
  echo -e "${YELLOW}Обновление Maigret...${RESET}"
  if check_dep maigret; then
    pip install -U maigret >/dev/null 2>&1
  fi
  if [ -d "$HOLEHE_DIR/.git" ]; then
    echo -e "${YELLOW}Обновление Holehe...${RESET}"
    cd "$HOLEHE_DIR" && git pull
  fi
  if [ -d "$PHONEINFOGA_DIR/.git" ]; then
    echo -e "${YELLOW}Обновление PhoneInfoga...${RESET}"
    cd "$PHONEINFOGA_DIR" && git pull
  fi
  echo -e "${GREEN}Обновление завершено.${RESET}"
}

toggle_tor() {
  if [ "$USE_TOR" -eq 0 ]; then
    USE_TOR=1
    echo -e "${GREEN}Tor-режим включён.${RESET}"
    log "Tor-режим включён."
  else
    USE_TOR=0
    echo -e "${YELLOW}Tor-режим выключен.${RESET}"
    log "Tor-режим выключен."
  fi
}

# ========= MAIN LOOP =========
check_requirements

while true; do
  menu
  case "$choice" in
    1) run_sherlock; pause ;;
    2) run_maigret; pause ;;
    3) run_holehe; pause ;;
    4) run_phoneinfoga; pause ;;
    5) run_bulk_sherlock; pause ;;
    6) run_fullscan; pause ;;
    7) update_tools; pause ;;
    8) toggle_tor; pause ;;
    0) echo -e "${BLUE}Выход.${RESET}"; exit 0 ;;
    *) echo -e "${RED}Неверный выбор.${RESET}"; pause ;;
  esac
done
