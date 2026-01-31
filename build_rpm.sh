#!/bin/bash

# Скопируй ссылку на кнопке с сайта: https://music.yandex.ru/download/ и вставь в строку ниже
DEB_URL="https://desktop.app.music.yandex.net/stable/Yandex_Music_amd64_5.82.0.deb"
# Выцепляем оригинальное имя файла из ссылки
PACKAGE_NAME=$(basename "$DEB_URL")
NAME_WITHOUT_EXT="${PACKAGE_NAME%.*}"
RPM_NAME="$NAME_WITHOUT_EXT.rpm"

echo "--- Сборка RPM на основе $PACKAGE_NAME ---"

# 1. Скачивание (сохраняем как есть)
if [ ! -f "$PACKAGE_NAME" ]; then
    echo "Скачивание..."
    curl -L "$DEB_URL" -o "$PACKAGE_NAME"
else
    echo "Файл $PACKAGE_NAME уже существует. Пропускаем скачивание."
fi

# 2. Конвертация
# Alien сам добавит единицу к версии и сменит расширение на .rpm и изменит имя пакета
echo "Конвертация через Alien..."
alien --to-rpm --scripts "$PACKAGE_NAME"

# 3. Подготовка ярлыка (StartupWMClass и категории)
echo "Создание исправленного ярлыка..."
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

echo "--- Готово ---"
echo "Установите созданный .rpm пакет ($RPM_NAME) и замените ярлык в /usr/share/applications/"