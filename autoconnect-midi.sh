#!/bin/bash
# Автоподключение USB-MIDI к RTP-MIDI (поддержка новых устройств)
# Работает бесконечно с проверкой каждые 5 секунд

RTP_NAME="OrangePi-MIDI"
RTP_PORT=0
SLEEP=5

log() { logger -t midi-autoconnect "$1"; }

log "Сервис midi-autoconnect запущен"

# Функция проверки подключения
is_connected() {
    local src=$1
    echo "Port 1:" $1
    local dst=$2
    echo "Port 2:" $2
    echo aconnect -l | awk -v s="$src" -v d="$dst" '
        /^client/ {c=$2; sub(":","",c)}
        /^[[:space:]]+[0-9]+/ {p=$1; owner=c ":" p}
        /Connecting To:/ {if(owner==s){for(i=3;i<=NF;i++) if($i==d) exit 0}}
        END {exit 1}
    '
}

while true; do
    # Определяем RTP-клиент
    RTP_CLIENT=$(aconnect -l | awk -v name="$RTP_NAME" '/^client/ {c=$2; sub(":","",c); if(index($0,name)){print c; exit}}')
    if [ -z "$RTP_CLIENT" ]; then
        log "RTP клиент $RTP_NAME не найден"
        sleep $SLEEP
        continue
    fi
    DST="$RTP_CLIENT:$RTP_PORT"

    # Все клиенты кроме 0 (System) и RTP
    for client in $(aconnect -l | awk -v rtp="$RTP_CLIENT" '/^client/ {c=$2; sub(":","",c); if(c>0 && c!=rtp) print c}'); do
        # Порты клиента
        for port in $(aconnect -l | awk -v c="$client" '
            /^client/ {cur=$2; sub(":","",cur)}
            /^[[:space:]]+[0-9]+/ {if(cur==c) print $1}
        '); do
            SRC="$client:$port"

            # Подключаем только если ещё нет
            if ! is_connected "$SRC" "$DST"; then
                log "Подключаю $SRC -> $DST"
                aconnect "$SRC" "$DST" 2>/dev/null || log "Ошибка $SRC -> $DST"
            fi
        done
    done

    sleep $SLEEP
done
