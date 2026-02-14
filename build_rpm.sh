#!/bin/bash

echo "--- Поиск актуальной версии Яндекс Музыки ---"
echo "--- Search for the current version of Yandex Music ---"

# Request the latest release and link to the current deb package
# Запрашиваем последний релиз и выцепляем ссылку на актуальный deb-пакет
DEB_URL="https://desktop.app.music.yandex.net/stable/$(curl -Ls https://desktop.app.music.yandex.net/stable/latest-linux.yml | grep '^path:' | awk '{print $2}')"

if [ -z "$DEB_URL" ]; then
    echo "Ошибка: Не удалось получить ссылку на страницу скачивания"
    echo "Error: Couldn't get the link to the download page"
    exit 1
fi

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

echo "--- Сборка RPM на основе $PACKAGE_NAME ---"
echo "--- RPM build based on $PACKAGE_NAME ---"

# 2. Conversion
# Alien will add one to the version in the rpm package name
# 2. Конвертация
# Alien добавит единицу к версии в названии rpm-пакета
echo "Конвертация через Alien..."
echo "Conversion via Alien..."
# Intercepting the alien output to know exactly the name of the created file
# Use process substitution and tee to output to the console and write to a variable
# Add the -v flag for talkativeness and 2>&1 for capturing errors in real time
# Перехватываем вывод alien, чтобы точно знать имя созданного файла
# Используем process substitution и tee для вывода в консоль и записи в переменную
# Добавляем флаг -v для разговорчивости и 2>&1 для захвата ошибок в реальном времени
ALIEN_OUTPUT=$(alien -v --to-rpm --scripts "$PACKAGE_NAME" 2>&1 | tee /dev/stderr)

# Extract the file name from the string "name.rpm generated"
# Извлекаем имя файла из строки "имя.rpm generated"
RPM_FILE=$(echo "$ALIEN_OUTPUT" | grep -oP '\S+\.rpm(?=\s+generated)')

# 3. Preparing the shortcut (StartupWMClass and categories)
# Use quotation marks in Exec to avoid the "Invalid escape sequence" error in KDE
# 3. Подготовка ярлыка (StartupWMClass и категории)
# Используем кавычки в Exec, чтобы избежать ошибки "Invalid escape sequence" в KDE
echo "Создание исправленного ярлыка..."
echo "Creating a corrected shortcut..."
cat <<EOF > yandexmusic.desktop
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

# 4. Installing or updating a package
# 4. Установка или обновление пакета
if [ -f "$RPM_FILE" ]; then
    echo "--- Установка/Обновление пакета $RPM_FILE ---"
    echo "--- Installation/Updating the $RPM_FILE package ---"
    # dnf install для локального файла работает и как установка, и как обновление
    ${SUDO_PREFIX} dnf install -y "./$RPM_FILE"

    # 5. Replacing the default shortcut
    # 5. Замена дефолтного ярлыка
    echo "Копирование исправленного ярлыка в системную директорию..."
    echo "Copying the corrected shortcut to the system directory..."
    ${SUDO_PREFIX} cp yandexmusic.desktop /usr/share/applications/

    # Updating the desktop file database so that the changes catch up immediately
    # Обновляем базу данных десктоп-файлов, чтобы изменения подтянулись сразу
    ${SUDO_PREFIX} update-desktop-database

    echo "--- Всё готово! Приложение обновлено и настроено. ---"
    echo "--- Everything is ready! The app has been updated and configured. ---"
else
    echo "Ошибка: RPM файл не найден. Проверьте вывод Alien выше."
    echo "Error: RPM file not found. Check the Alien output above."
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