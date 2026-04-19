#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BUILD_SCRIPT="$SCRIPT_DIR/build_rpm.sh"

PACKAGE_ID="yandexmusic"
RPM_PATTERN="${PACKAGE_ID}-*.rpm"
DESKTOP_FILE="/usr/share/applications/yandexmusic.desktop"
LOCK_FILE="/tmp/yandexmusic-rpm-updater.lock"
DEB_FILE=""
WORKDIR_OVERRIDE=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --deb-file)
            if [ "$#" -lt 2 ]; then
                echo "Ошибка: --deb-file требует путь к .deb"
                echo "Error: --deb-file requires a .deb path"
                exit 1
            fi
            DEB_FILE="$2"
            shift 2
            ;;
        --workdir)
            if [ "$#" -lt 2 ]; then
                echo "Ошибка: --workdir требует путь к рабочей директории"
                echo "Error: --workdir requires a work directory path"
                exit 1
            fi
            WORKDIR_OVERRIDE="$2"
            shift 2
            ;;
        *)
            echo "Ошибка: неизвестный аргумент: $1"
            echo "Error: unknown argument: $1"
            exit 1
            ;;
    esac
done

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    exec pkexec --disable-internal-agent /bin/bash -c '"$0" "$@"' "$0" "$@"
fi

if [ ! -x "$BUILD_SCRIPT" ]; then
    echo "Ошибка: скрипт сборки не найден или не исполняем: $BUILD_SCRIPT"
    echo "Error: build script not found or not executable: $BUILD_SCRIPT"
    exit 1
fi

if [ -n "$DEB_FILE" ] && [ ! -f "$DEB_FILE" ]; then
    echo "Ошибка: указанный deb-файл не найден: $DEB_FILE"
    echo "Error: specified deb file not found: $DEB_FILE"
    exit 1
fi

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "Обновление уже выполняется другим процессом."
    echo "Update is already running in another process."
    exit 0
fi

if [ -n "$WORKDIR_OVERRIDE" ]; then
    mkdir -p "$WORKDIR_OVERRIDE"
    TMP_WORKDIR=$(cd "$WORKDIR_OVERRIDE" && pwd)
else
    TMP_WORKDIR=$(mktemp -d /tmp/yandexmusic-rpm-build.XXXXXX)
fi

cleanup() {
    if [ -z "$WORKDIR_OVERRIDE" ]; then
        rm -rf "$TMP_WORKDIR"
    fi
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

echo "--- Поиск/сборка RPM пакета ---"
echo "--- Looking for/building an RPM package ---"
echo "--- Рабочая директория: $TMP_WORKDIR ---"
echo "--- Working directory: $TMP_WORKDIR ---"

BUILD_ARGS=(--workdir "$TMP_WORKDIR")
if [ -n "$DEB_FILE" ]; then
    BUILD_ARGS+=(--deb-file "$DEB_FILE")
fi

"$BUILD_SCRIPT" "${BUILD_ARGS[@]}"

RPM_FILE=$(find "$TMP_WORKDIR" -maxdepth 1 -type f -name "$RPM_PATTERN" -printf '%T@ %p\n' | sort -nr | awk 'NR==1 {print $2}')
if [ -z "${RPM_FILE:-}" ] || [ ! -f "$RPM_FILE" ]; then
    echo "Ошибка: RPM пакет не найден после сборки"
    echo "Error: RPM package not found after the build"
    exit 1
fi

echo "--- Установка/Обновление пакета $RPM_FILE ---"
echo "--- Installation/Updating the package $RPM_FILE ---"
if rpm -q "$PACKAGE_ID" >/dev/null 2>&1; then
    INSTALLED_NEVRA=$(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "$PACKAGE_ID")
else
    INSTALLED_NEVRA=""
fi
TARGET_NEVRA=$(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "$RPM_FILE")

echo "Установлено: ${INSTALLED_NEVRA:-<не установлено>}"
echo "Installed: ${INSTALLED_NEVRA:-<not installed>}"
echo "Целевой пакет: $TARGET_NEVRA"
echo "Target package: $TARGET_NEVRA"

if [ -n "$INSTALLED_NEVRA" ] && [ "$INSTALLED_NEVRA" = "$TARGET_NEVRA" ]; then
    /usr/bin/rpm -Uvh --replacepkgs "$RPM_FILE"
else
    /usr/bin/rpm -Uvh "$RPM_FILE"
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    echo "Обновление базы desktop-файлов..."
    echo "Updating the desktop file database..."
    update-desktop-database || true
fi

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
