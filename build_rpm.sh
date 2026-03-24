#!/bin/bash

echo "--- Поиск актуальной версии Яндекс Музыки ---"
echo "--- Search for the current version of Yandex Music ---"

# Request the latest release and link to the current deb package
# Запрашиваем последний релиз и выцепляем ссылку на актуальный deb-пакет
DEB_PATH=$(curl -Ls https://desktop.app.music.yandex.net/stable/latest-linux.yml | awk '/^path:/ {print $2; exit}')

if [ -z "$DEB_PATH" ]; then
    echo "Ошибка: Не удалось получить путь к актуальному deb-пакету"
    echo "Error: Couldn't get the path to the current deb package"
    exit 1
fi

DEB_URL="https://desktop.app.music.yandex.net/stable/$DEB_PATH"

# Extract the file name from the found link
# Выцепляем имя файла из найденной ссылки
PACKAGE_NAME=$(basename "$DEB_URL")

echo "Актуальный пакет: $PACKAGE_NAME"
echo "Current package: $PACKAGE_NAME"

# Determine how to run privileged commands: prefer running the script as regular user
# and use sudo only for commands that require root. If the script was invoked via
# sudo, SUDO_UID/SUDO_GID will be set and we'll restore ownership at the end.
if [ "$(id -u)" -eq 0 ]; then
    if [ -n "$SUDO_UID" ]; then
        SUDO_PREFIX=""
        ORIGINAL_UID="$SUDO_UID"
        ORIGINAL_GID="$SUDO_GID"
    else
        echo "Внимание: скрипт запущен как root. Рекомендуется запускать без sudo." >&2
        SUDO_PREFIX=""
        ORIGINAL_UID=0
        ORIGINAL_GID=0
    fi
else
    SUDO_PREFIX="sudo"
    ORIGINAL_UID=$(id -u)
    ORIGINAL_GID=$(id -g)
fi

# If we will use sudo for privileged commands, request credentials once to cache them
# so the script won't prompt for a password at each privileged command.
if [ "${SUDO_PREFIX}" = "sudo" ]; then
    echo "Запрашиваю sudo для кеширования пароля перед выполнением привилегированных команд..."
    if ! sudo -v; then
        echo "Не удалось получить sudo права" >&2
        exit 1
    fi
fi

# 1. Download (save as is)
# 1. Скачивание (сохраняем как есть)
if [ ! -f "$PACKAGE_NAME" ]; then
    echo "Скачивание..."
    echo "Download..."
    curl -L "$DEB_URL" -o "$PACKAGE_NAME"
else
    echo "Файл $PACKAGE_NAME уже существует. Пропускаем скачивание."
    echo "The $PACKAGE_NAME file already exists. Skip the download."
fi

PACKAGE_VERSION_RAW=$(dpkg-deb --field "$PACKAGE_NAME" Version 2>/dev/null)
PACKAGE_ID=$(dpkg-deb --field "$PACKAGE_NAME" Package 2>/dev/null)
PACKAGE_ARCH_DEB=$(dpkg-deb --field "$PACKAGE_NAME" Architecture 2>/dev/null)

if [ -z "$PACKAGE_VERSION_RAW" ] || [ -z "$PACKAGE_ID" ] || [ -z "$PACKAGE_ARCH_DEB" ]; then
    echo "Ошибка: Не удалось получить метаданные deb-пакета"
    echo "Error: Couldn't read deb package metadata"
    exit 1
fi

PACKAGE_VERSION=${PACKAGE_VERSION_RAW%%-*}

case "$PACKAGE_ARCH_DEB" in
    amd64)
        PACKAGE_ARCH_RPM="x86_64"
        ;;
    i386)
        PACKAGE_ARCH_RPM="i386"
        ;;
    arm64)
        PACKAGE_ARCH_RPM="aarch64"
        ;;
    armhf)
        PACKAGE_ARCH_RPM="armhfp"
        ;;
    *)
        PACKAGE_ARCH_RPM="$PACKAGE_ARCH_DEB"
        ;;
esac

BUILD_DIR="${PACKAGE_ID}-${PACKAGE_VERSION}"
RPM_GLOB="${PACKAGE_ID}-${PACKAGE_VERSION}-*.${PACKAGE_ARCH_RPM}.rpm"

echo "--- Сборка RPM на основе $PACKAGE_NAME ---"
echo "--- RPM build based on $PACKAGE_NAME ---"

# 2. Generate the RPM build tree via alien
# 2. Генерация дерева сборки RPM через alien
echo "Генерация дерева сборки через Alien..."
echo "Generating the build tree via Alien..."
RPMBUILD_LOG=$(mktemp)
trap 'rm -f "$RPMBUILD_LOG"' EXIT
alien -v --to-rpm --scripts --generate "$PACKAGE_NAME"
ALIEN_DIR="./$BUILD_DIR"

if [ ! -d "$ALIEN_DIR" ]; then
    echo "Ошибка: Alien не создал дерево сборки RPM"
    echo "Error: Alien did not create the RPM build tree"
    exit 1
fi

SPEC_FILE=$(find "$ALIEN_DIR" -maxdepth 1 -type f -name '*.spec' | head -n 1)
if [ -z "$SPEC_FILE" ]; then
    echo "Ошибка: Не найден spec-файл в дереве сборки Alien"
    echo "Error: Spec file not found in the Alien build tree"
    exit 1
fi

# 3. Patch the desktop file inside the generated build tree
# 3. Правим desktop-файл внутри сгенерированного дерева сборки
DESKTOP_FILE="$ALIEN_DIR/usr/share/applications/yandexmusic.desktop"
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Ошибка: В дереве сборки Alien не найден desktop-файл"
    echo "Error: Desktop file not found in the Alien build tree"
    exit 1
fi

# Use quotation marks in Exec to avoid the "Invalid escape sequence" error in KDE
# Используем кавычки в Exec, чтобы избежать ошибки "Invalid escape sequence" в KDE
echo "Исправление ярлыка в дереве сборки..."
echo "Patching the launcher in the build tree..."
cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=Яндекс Музыка
Name[ru]=Яндекс Музыка
Comment=Personal recommendations, mixes for any occasion and the latest musical releases
Comment[ru]=Персональные рекомендации, миксы на любой случай и последние музыкальные новинки
Exec="/opt/Яндекс Музыка/yandexmusic" %U
Terminal=false
Type=Application
Icon=yandexmusic
StartupWMClass=YandexMusic
Keywords=music;yandex;яндекс;музыка;
MimeType=x-scheme-handler/yandexmusic;
Categories=Audio;Music;AudioVideo;
EOF

# 4. Build the RPM from the patched tree
# 4. Сборка RPM из исправленного дерева
echo "Сборка RPM из исправленного дерева..."
echo "Building the RPM from the patched tree..."
(
    cd "$ALIEN_DIR" && \
    rpmbuild \
        --buildroot "$(pwd)" \
        -bb "$(basename "$SPEC_FILE")"
) 2>&1 | tee "$RPMBUILD_LOG"
RPM_FILE=$(awk '/^Wrote:/ && /\.rpm$/ {print $2}' "$RPMBUILD_LOG" | tail -n 1)

if [ -z "$RPM_FILE" ] || [ ! -f "$RPM_FILE" ]; then
    RPM_FILE=$(find . -maxdepth 1 -type f -name "$RPM_GLOB" -printf '%T@ %p\n' | sort -nr | awk 'NR==1 {print $2}')
fi

if [ -f "$RPM_FILE" ]; then
    echo "--- Установка/Обновление пакета $RPM_FILE ---"
    echo "--- Installation/Updating the $RPM_FILE package ---"
    # dnf install для локального файла работает и как установка, и как обновление
    ${SUDO_PREFIX} dnf install -y "$RPM_FILE"

    # Updating the desktop file database so that the changes catch up immediately
    # Обновляем базу десктоп-файлов, чтобы изменения подтянулись сразу
    ${SUDO_PREFIX} update-desktop-database

    echo "--- Всё готово! Приложение обновлено и настроено. ---"
    echo "--- Everything is ready! The app has been updated and configured. ---"
else
    echo "Ошибка: RPM файл не найден. Проверьте вывод сборки выше."
    echo "Error: RPM file not found. Check the build output above."
    exit 1
fi

# regain ownership to the original (non-root) user if script ran under sudo
# возвращаем владельца оригинальному (не-root) пользователю, если скрипт запускался через sudo
# If the script was run via sudo, restore ownership of files in the current
# directory back to the original user who invoked sudo.
if [ -n "$SUDO_UID" ]; then
    chown -R "${SUDO_UID}:${SUDO_GID}" .
elif [ "$(id -u)" -eq 0 ] && [ "$ORIGINAL_UID" -ne 0 ]; then
    chown -R "${ORIGINAL_UID}:${ORIGINAL_GID}" .
else
    # No action: script wasn't run via sudo, or original user unknown.
    true
fi
