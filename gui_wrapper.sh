#!/bin/bash
set -uo pipefail

INSTALLER='/opt/Яндекс Музыка/updater/install_rpm.sh'
LOG="$(mktemp /tmp/yandexmusic-rpm-update.XXXXXX.log)"

have() { command -v "$1" >/dev/null 2>&1; }

run_pkexec() {
    pkexec --disable-internal-agent /bin/bash -c '"$0" "$@"' "$INSTALLER" "$@"
}

if have zenity; then
    : >"$LOG"
    run_pkexec "$@" >"$LOG" 2>&1 &
    PID=$!

    # Фаза 1: ожидание авторизации polkit. Индикатор НЕ показываем,
    # polkit-агент рисует своё окно ввода пароля сам. Ждём либо первой
    # строки в логе (install_rpm.sh уже стартовал), либо смерти процесса
    # (отказ в авторизации).
    while kill -0 "$PID" 2>/dev/null && [ ! -s "$LOG" ]; do
        sleep 0.2
    done

    if [ ! -s "$LOG" ]; then
        wait "$PID" 2>/dev/null || true
        rc=$?
        zenity --error --title="Яндекс Музыка" --width=420 \
               --text="Не удалось получить права суперпользователя (код ${rc:-1})." \
               2>/dev/null || true
        exit "${rc:-1}"
    fi

    # Фаза 2: установка пошла — показываем индикатор.
    # Поллинг вместо tail -f, чтобы жёстко привязать жизнь цикла к жизни
    # pkexec: пока процесс жив, крутим. Как только умер — echo 100 и выход,
    # zenity получит "100" и корректно закроется.
    (
        last=""
        while kill -0 "$PID" 2>/dev/null; do
            cur=$(tail -n 1 "$LOG" 2>/dev/null || true)
            if [ -n "$cur" ] && [ "$cur" != "$last" ]; then
                # Санитизируем символы, которые могут сломать pango-разметку
                safe=${cur//&/&amp;}
                safe=${safe//</&lt;}
                safe=${safe//>/&gt;}
                printf '# %s\n' "$safe"
                last=$cur
            fi
            sleep 0.3
        done
        echo 100
    ) | zenity --progress --pulsate --auto-close --no-cancel \
               --title="Обновление Яндекс Музыки" \
               --width=560 --text="Идёт обновление..." || true

    wait "$PID"
    rc=$?
    if [ "$rc" = "0" ]; then
        zenity --info --title="Яндекс Музыка" --width=320 \
               --text="Обновление успешно установлено."
    else
        zenity --error --title="Яндекс Музыка" --width=480 \
               --text="Обновление не выполнено (код $rc)."
        zenity --text-info --title="Журнал обновления" \
               --width=760 --height=520 --filename="$LOG" || true
    fi
    exit "$rc"
elif have kdialog; then
    run_pkexec "$@" >"$LOG" 2>&1
    rc=$?
    if [ "$rc" = "0" ]; then
        kdialog --title "Яндекс Музыка" --msgbox "Обновление успешно установлено."
    else
        kdialog --title "Яндекс Музыка" --error "Обновление не выполнено (код $rc)."
        kdialog --title "Журнал обновления" --textbox "$LOG" 760 520
    fi
    exit "$rc"
else
    exec pkexec --disable-internal-agent /bin/bash -c '"$0" "$@"' "$INSTALLER" "$@"
fi
