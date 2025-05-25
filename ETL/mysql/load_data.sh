#!/bin/bash
#
# Скрипт для определения оставшегося объема данных
# загружаемых через LOAD DATA в MySQL
#

# Цвета для основного скрипта
BLUE='\033[1;34m'
RED='\033[1;31m'
NC='\033[0m'

# Проверяем, запущен ли скрипт от root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Ошибка: ${NC}Скрипт должен быть запущен от root"
  exit 1
fi

# Проверка аргумента
if [ -z "$1" ]; then
  echo -e "${RED}Использование:${NC} $0 <имя_файла>"
  exit 1
fi

FILENAME="$1"

# Получаем PID, FD, FSIZE
params_str=$(sudo lsof 2>/dev/null | grep "$FILENAME" | head -n1 | awk '{print $2, $4, $7}')
if [ -z "$params_str" ]; then
  echo -e "${RED}Файл '${FILENAME}' не найден в выводе lsof.${NC}"
  exit 1
fi

# Извлекаем параметры
params_names=$(echo "$params_str" | sed -E 's/[^0-9 ]+//g; s/ +/,/g')
IFS=',' read -r -a params <<< "$params_names"

PID="${params[0]}"
FD="${params[1]}"
FSIZE="${params[2]}"
FDINFO_PATH="/proc/$PID/fdinfo/$FD"

# Создаём временный скрипт
TMP_SCRIPT=$(mktemp)
# который будет удален при выходе
trap "rm -f '$TMP_SCRIPT'" EXIT

cat <<EOF > "$TMP_SCRIPT"
#!/bin/bash

# Цвета для вывода
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

FILE_SIZE=$FSIZE

echo -e "\${BLUE}Файл:\${NC} $FILENAME"
echo -e "\${BLUE}Размер:\${NC} \$FILE_SIZE"
echo -e "\${BLUE}PID:\${NC} $PID"
echo -e "\${BLUE}FD:\${NC} $FD"
echo -e "\${BLUE}Путь:\${NC} $FDINFO_PATH"

if [ ! -f "$FDINFO_PATH" ]; then
  echo -e "\${YELLOW}Файл fdinfo не найден. Возможно, процесс завершился.\${NC}"
  exit 1
fi

READ_BYTES=\$(sudo awk '/pos:/ {print \$2}' "$FDINFO_PATH")
echo -e "\${BLUE}Прочитано байт:\${NC} \$READ_BYTES"
REMAINING_BYTES=\$(( FILE_SIZE - READ_BYTES ))
echo -e "\${BLUE}Осталось байт:\${NC} \$REMAINING_BYTES"
echo -e "\${BLUE}Осталось загрузить:\${NC} \$((REMAINING_BYTES / 1024 / 1024)) Мбайт"
EOF

chmod +x "$TMP_SCRIPT"

# Запуск через watch с поддержкой цветов, 
# который каждые 30 сек будет выводить обновленную информацию
watch -c -tn 30 "$TMP_SCRIPT"