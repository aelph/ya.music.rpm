#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"

PACKAGE_ID="yandexmusic"
RPM_PATTERN="${PACKAGE_ID}-*.rpm"
DESKTOP_FILE="/usr/share/applications/yandexmusic.desktop"

echo "--- Поиск готового RPM пакета ---"
echo "--- Looking for a ready RPM package ---"

RPM_FILE=$(find . -maxdepth 1 -type f -name "$RPM_PATTERN" -printf '%T@ %p\n' | sort -nr | awk 'NR==1 {print $2}')

if [ -z "${RPM_FILE:-}" ] || [ ! -f "$RPM_FILE" ]; then
    echo "RPM пакет не найден. Запускаю сборку..."
    echo "RPM package not found. Starting the build..."
    ./build_rpm.sh
    RPM_FILE=$(find . -maxdepth 1 -type f -name "$RPM_PATTERN" -printf '%T@ %p\n' | sort -nr | awk 'NR==1 {print $2}')
fi

if [ -z "${RPM_FILE:-}" ] || [ ! -f "$RPM_FILE" ]; then
    echo "Ошибка: RPM пакет не найден после сборки"
    echo "Error: RPM package not found after the build"
    exit 1
fi

echo "--- Установка/Обновление пакета $RPM_FILE ---"
echo "--- Installation/Updating the $RPM_FILE package ---"
sudo dnf install -y "$RPM_FILE"

echo "Обновление базы desktop-файлов..."
echo "Updating the desktop file database..."
sudo update-desktop-database

echo "--- Проверка установки ---"
echo "--- Verifying the installation ---"
if ! rpm -q "$PACKAGE_ID" >/dev/null 2>&1; then
    echo "Ошибка: пакет $PACKAGE_ID не установлен"
    echo "Error: package $PACKAGE_ID is not installed"
    exit 1
fi

if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Ошибка: desktop-файл не найден: $DESKTOP_FILE"
    echo "Error: desktop file not found: $DESKTOP_FILE"
    exit 1
fi

echo "--- Всё готово! Пакет установлен и проверен. ---"
echo "--- Everything is ready! The package is installed and verified. ---"
