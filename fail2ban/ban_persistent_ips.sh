#!/bin/bash

# ANSI-цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Счётчики
new_ips=0
existing_ips=0
errors=0

# Порог по умолчанию
THRESHOLD=50

# Проверяем, запущен ли скрипт от root
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Ошибка: ${NC}Скрипт должен быть запущен от root"
  exit 1
fi

# Проверяем, существует ли manualban
JAIL_EXISTS=$(fail2ban-client status | grep -c "manualban")

if [ "$JAIL_EXISTS" -eq 0 ]; then
    echo -e "${RED}Ошибка: ${NC}jail 'manualban' не найден или отключен"
    echo -e "Убедитесь, что он настроен в /etc/fail2ban/jail.local"
    exit 1
fi

# Проверяем, передан ли порог как аргумент
if [[ "$1" =~ ^[0-9]+$ ]]; then
    THRESHOLD=$1
fi

# Получаем список игнорируемых IP из jail.local
IGNORE_IPS=$(grep -E '^ignoreip' /etc/fail2ban/jail.local | \
  sed -e 's/^[^0-9]*//' -e 's/[[:space:]]+/ /g' -e 's/[[:space:]]*$//')
# Преобразуем в массив для удобства проверки
read -r -a IGNORE_ARRAY <<< "$IGNORE_IPS" 
echo -e "${GREEN}Игнорируемые IP-адреса:${NC}"
echo -e "$(printf "%s\n" "${IGNORE_ARRAY[@]}")"

# Получаем список IP, забаненных более $THRESHOLD раз
IP_LIST=$(grep 'Ban' /var/log/fail2ban.log | \
  awk '{print $NF}' | \
  sed -nE 's/^(([0-9]{1,3}\.){3}[0-9]{1,3})$/\1/p' | \
  sort | \
  uniq -c | \
  sort -nr | \
  awk -v t="$THRESHOLD" '$1 > t {print $2}')

# Если нет подходящих IP — выходим
if [ -z "$IP_LIST" ]; then
    echo -e "${YELLOW}Нет подходящих IP для добавления (порог: $THRESHOLD)${NC}"
    exit 0
fi

# Преобразует IP в 32-битное целое
ip_to_int() {
    local ip=$1
    local a b c d
    IFS=. read -r a b c d <<< "$ip"
    echo $(((a << 24)+(b << 16)+(c << 8)+d))
}

# Проверяет, попадает ли IP в подсеть network / cidr
ip_in_subnet() {
    local ip=$1
    local network=$2
    local cidr=$3

    local ip_int=$(ip_to_int "$ip")
    local net_int=$(ip_to_int "$network")

    # Маска CIDR
    local mask=$(( ( ~0 ) << (32 - cidr) ))

    # Применяем маску к IP и к сети
    if (( (ip_int & mask) == (net_int & mask) )); then
        return 0 # true
    else
        return 1 # false
    fi
}


# Проходим по каждому IP
for IP in $IP_LIST; do

    # Проверяем, находится ли IP в ignoreip
    for ignore_ip in "${IGNORE_ARRAY[@]}"; do
        if [[ "$IP" == "$ignore_ip" ]]; then
            echo -e "${YELLOW}${IP}\t${NC}в списке игнорируемых — пропускаем"
            ((existing_ips++))
            continue 2
        fi

        # Если это подсеть (CIDR), проверяем принадлежность
        if [[ "$ignore_ip" == */* ]]; then
            network_part=$(echo "$ignore_ip" | cut -d '/' -f 1)
            cidr_mask=$(echo "$ignore_ip" | cut -d '/' -f 2)

            if ip_in_subnet "$IP" "$network_part" "$cidr_mask"; then
                echo -e "${YELLOW}${IP}\t${NC}входит в игнорируемую подсеть $ignore_ip — пропускаем"
                ((existing_ips++))
                continue 2
            fi
        fi
    done

    # Проверяем, есть ли IP в manualban
    if fail2ban-client status manualban | grep -q "$IP"; then
        echo -e "${YELLOW}${IP}\t${NC}уже находится в manualban"
        ((existing_ips++))
        continue
    fi

    # Проверяем, находится ли IP в любом другом jail
    if fail2ban-client status | grep -A 10 'Currently banned:' | grep -q "$IP"; then
        echo -e "${YELLOW}${IP}\t${NC}уже заблокирован в другом jail"
        ((existing_ips++))
        continue
    fi

    # Пробуем добавить в manualban
    /usr/bin/fail2ban-client set manualban banip "$IP" >/dev/null 2>&1
    exit_code=$?

    # Дополнительно проверяем, был ли IP реально добавлен
    if fail2ban-client status manualban | grep -q "$IP"; then
        echo -e "${GREEN}${IP}\t${NC}успешно добавлен в manualban"
        ((new_ips++))
    else
        echo -e "${RED}${IP}\t${NC}ошибка при обработке (код $exit_code)"
        ((errors++))
    fi
done

# Итоговая статистика
echo -e "\n${GREEN}Новых IP добавлено:\t$new_ips${NC}"
echo -e "${YELLOW}Уже заблокировано:\t$existing_ips${NC}"
if [ $errors -gt 0 ]; then
    echo -e "${RED}Ошибок: $errors${NC}"
fi
