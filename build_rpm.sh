#!/bin/bash

# Скопируй ссылку на кнопке с сайта: https://music.yandex.ru/download/ и вставь в строку ниже
DEB_URL="https://desktop.app.music.yandex.net/stable/Yandex_Music_amd64_5.82.0.deb"
# Выцепляем оригинальное имя файла из ссылки
ORIGINAL_NAME=$(basename "$DEB_URL")

echo "--- Сборка RPM на основе $ORIGINAL_NAME ---"

# 1. Скачивание (сохраняем как есть)
if [ ! -f "$ORIGINAL_NAME" ]; then
    echo "Скачивание..."
    curl -L "$DEB_URL" -o "$ORIGINAL_NAME"
fi

# 2. Конвертация
# Alien сам добавит единицу к версии и сменит расширение на .rpm
echo "Конвертация через Alien..."
sudo alien -r --scripts "$ORIGINAL_NAME"

# 3. Подготовка ярлыка (StartupWMClass и категории)
echo "Создание исправленного ярлыка..."
cat <<EOF > yandex-music.desktop
[Desktop Entry]
Name=Яндекс Музыка
Exec="/opt/Яндекс Музыка/yandexmusic" %U
Terminal=false
Type=Application
Icon=yandexmusic
StartupWMClass=YandexMusic
Comment=Personal recommendations, mixes for any occasion and the latest musical releases
MimeType=x-scheme-handler/yandexmusic;
Categories=Audio;Music;AudioVideo;
EOF

echo "--- Готово ---"
echo "Установите созданный .rpm пакет и замените ярлык в /usr/share/applications/"