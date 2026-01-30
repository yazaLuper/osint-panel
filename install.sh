#!/bin/bash

echo "[*] Обновление системы..."
sudo apt update -y
sudo apt install -y python3 python3-pip python3-venv git curl tor

echo "[*] Создание папок..."
mkdir -p ~/osint-results

echo "[*] Создание виртуального окружения для панели..."
python3 -m venv ~/osint-env
source ~/osint-env/bin/activate

echo "[*] Установка Python-зависимостей панели..."
pip install requests trio

echo "[*] Установка Sherlock..."
if ! command -v sherlock &> /dev/null; then
    git clone https://github.com/sherlock-project/sherlock.git ~/sherlock
    pip install -r ~/sherlock/requirements.txt
fi

echo "[*] Установка Maigret..."
pip install maigret

echo "[*] Установка Holehe..."
python3 -m venv ~/holehe-env
source ~/holehe-env/bin/activate
pip install holehe requests trio

echo "[*] Установка PhoneInfoga..."
git clone https://github.com/sundowndev/phoneinfoga.git ~/phoneinfoga
cd ~/phoneinfoga
pip install -r requirements.txt

echo "[*] Установка завершена!"
echo "Запускай панель командой:"
echo "    ./osint-menu.sh"
