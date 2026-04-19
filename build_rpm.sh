#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR="$SCRIPT_DIR/build"
DEB_FILE=""

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
            WORK_DIR="$2"
            shift 2
            ;;
        *)
            echo "Ошибка: неизвестный аргумент: $1"
            echo "Error: unknown argument: $1"
            exit 1
            ;;
    esac
done

if [ -n "$DEB_FILE" ]; then
    DEB_FILE=$(cd "$(dirname "$DEB_FILE")" && pwd)/$(basename "$DEB_FILE")
fi

mkdir -p "$WORK_DIR"
WORK_DIR=$(cd "$WORK_DIR" && pwd)
cd "$WORK_DIR"

if [ -n "$DEB_FILE" ]; then
    if [ ! -f "$DEB_FILE" ]; then
        echo "Ошибка: указанный deb-файл не найден: $DEB_FILE"
        echo "Error: specified deb file not found: $DEB_FILE"
        exit 1
    fi

    PACKAGE_NAME=$(basename "$DEB_FILE")
    if [ "$DEB_FILE" != "$WORK_DIR/$PACKAGE_NAME" ]; then
        cp -f "$DEB_FILE" "$WORK_DIR/$PACKAGE_NAME"
    fi

    echo "Использую локальный deb-пакет: $PACKAGE_NAME"
    echo "Using local deb package: $PACKAGE_NAME"
else
    echo "--- Поиск актуальной версии Яндекс Музыки ---"
    echo "--- Search for the current version of Yandex Music ---"

    DEB_PATH=$(curl -Ls https://desktop.app.music.yandex.net/stable/latest-linux.yml | awk '/^path:/ {print $2; exit}')

    if [ -z "$DEB_PATH" ]; then
        echo "Ошибка: Не удалось получить путь к актуальному deb-пакету"
        echo "Error: Couldn't get the path to the current deb package"
        exit 1
    fi

    DEB_URL="https://desktop.app.music.yandex.net/stable/$DEB_PATH"
    PACKAGE_NAME=$(basename "$DEB_URL")

    echo "Актуальный пакет: $PACKAGE_NAME"
    echo "Current package: $PACKAGE_NAME"

    if [ ! -f "$PACKAGE_NAME" ]; then
        echo "Скачивание..."
        echo "Download..."
        curl -L "$DEB_URL" -o "$PACKAGE_NAME"
    else
        echo "Файл $PACKAGE_NAME уже существует. Пропускаем скачивание."
        echo "The $PACKAGE_NAME file already exists. Skip the download."
    fi
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

rm -rf "$BUILD_DIR"

echo "--- Сборка RPM на основе $PACKAGE_NAME ---"
echo "--- RPM build based on $PACKAGE_NAME ---"

echo "Генерация дерева сборки через Alien..."
echo "Generating the build tree via Alien..."
RPMBUILD_LOG=$(mktemp)
trap 'rm -f "$RPMBUILD_LOG"' EXIT
alien -v --to-rpm --scripts --generate "$PACKAGE_NAME"
ALIEN_DIR="$WORK_DIR/$BUILD_DIR"

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

DESKTOP_FILE="$ALIEN_DIR/usr/share/applications/yandexmusic.desktop"
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Ошибка: В дереве сборки Alien не найден desktop-файл"
    echo "Error: Desktop file not found in the Alien build tree"
    exit 1
fi

echo "Исправление ярлыка в дереве сборки..."
echo "Patching the launcher in the build tree..."
cat <<'EOF_DESKTOP' > "$DESKTOP_FILE"
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
Actions=Update

[Desktop Action Update]
Name=Обновить Yandex Music (RPM)
Name[ru]=Обновить Яндекс Музыку (RPM)
Exec=/usr/bin/yandexmusic-rpm-update
Terminal=false
EOF_DESKTOP

UPDATER_DIR="$ALIEN_DIR/opt/Яндекс Музыка/updater"
mkdir -p "$UPDATER_DIR"
cp -f "$SCRIPT_DIR/build_rpm.sh" "$UPDATER_DIR/build_rpm.sh"
cp -f "$SCRIPT_DIR/install_rpm.sh" "$UPDATER_DIR/install_rpm.sh"
cp -f "$SCRIPT_DIR/gui_wrapper.sh" "$UPDATER_DIR/gui_wrapper.sh"
chmod 0755 "$UPDATER_DIR/build_rpm.sh" "$UPDATER_DIR/install_rpm.sh" "$UPDATER_DIR/gui_wrapper.sh"

WRAPPER_BIN="$ALIEN_DIR/usr/bin/yandexmusic-rpm-update"
mkdir -p "$(dirname "$WRAPPER_BIN")"
cat <<'EOF_WRAPPER' > "$WRAPPER_BIN"
#!/bin/bash
exec "/opt/Яндекс Музыка/updater/gui_wrapper.sh" "$@"
EOF_WRAPPER
chmod 0755 "$WRAPPER_BIN"

if ! grep -Fq '"/opt/Яндекс Музыка/updater/install_rpm.sh"' "$SPEC_FILE"; then
    cat <<'EOF_SPEC' >> "$SPEC_FILE"
%dir "/opt/Яндекс Музыка/updater/"
"/opt/Яндекс Музыка/updater/build_rpm.sh"
"/opt/Яндекс Музыка/updater/install_rpm.sh"
"/opt/Яндекс Музыка/updater/gui_wrapper.sh"
"/usr/bin/yandexmusic-rpm-update"
EOF_SPEC
fi

echo "Сборка RPM из исправленного дерева..."
echo "Building the RPM from the patched tree..."
SPEC_COPY="$(mktemp "$WORK_DIR/alien-spec.XXXXXX.spec")"
cp -f "$SPEC_FILE" "$SPEC_COPY"
rm -f "$SPEC_FILE"
(
    cd "$ALIEN_DIR" && \
    LC_ALL=C rpmbuild \
        --buildroot "$(pwd)" \
        -bb "$SPEC_COPY"
) 2>&1 | tee "$RPMBUILD_LOG"

RPM_FILE=$(awk '/^Wrote:/ && /\.rpm$/ {print $2}' "$RPMBUILD_LOG" | tail -n 1)
if [ -z "$RPM_FILE" ] || [ ! -f "$RPM_FILE" ]; then
    SEARCH_PATHS=("$WORK_DIR")
    [ -d "$HOME/rpmbuild/RPMS" ] && SEARCH_PATHS+=("$HOME/rpmbuild/RPMS")
    RPM_FILE=$(find "${SEARCH_PATHS[@]}" -type f -name "$RPM_GLOB" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1 {print $2}' || true)
fi

if [ -f "$RPM_FILE" ]; then
    OUTPUT_RPM="$WORK_DIR/$(basename "$RPM_FILE")"
    if [ "$RPM_FILE" != "$OUTPUT_RPM" ]; then
        cp -f "$RPM_FILE" "$OUTPUT_RPM"
    fi
    echo "--- RPM пакет собран: $OUTPUT_RPM ---"
    echo "--- RPM package created: $OUTPUT_RPM ---"
else
    echo "Ошибка: RPM файл не найден. Проверьте вывод сборки выше."
    echo "Error: RPM file not found. Check the build output above."
    exit 1
fi
