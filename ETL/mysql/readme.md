# ETL процессы (MySQL)

[MySQL. LOAD DATA. Определение объема загруженных данных](#loaddata_progress)

[MySQL. LOAD DATA. Загрузка больших объемов](#loaddata_split_l)

[MySQL. UPDATE. Обновление большого объема данных](#bigupdate)

[MySQL. Импорт только уникальных данных](#unique_import)

[MySQL. Прогресс импорта или экспорта дампа базы](#mysqldump_pv)

## <a id="loaddata_progress">MySQL. LOAD DATA. Определение объема загруженных данных</a>
При импорте большого объема данных в базу MySQL нет возможности отследить прогресс оставшегося объема файла.

Определить дескриптор процесса mysqld и открытого файла
```bash
sudo lsof 2>/dev/null | grep "somefile.txt"
```
Например результат выполнения команды:
```bash
mysqld 10720 systemd-coredump 41r REG  8,20 33054107590 7340383 /docker-entrypoint-initdb.d/somefile.txt
```
В данном выводе PID - 10720, FD - 41

Чтобы определить сколько данных было прочитано из файла, выполним команду вида `sudo cat /proc/<PID>/fdinfo/<FD>`
```bash
sudo cat /proc/10720/fdinfo/41
```
Результат выполнения команды (ниже), означает что в настоящий момент времени прочитано 2636120064 байт
```
pos:    2636120064
flags:	0100000
mnt_id: 1520
ino:    7340383
```
Также, данную команду можно заменить на следующую, которая покажет нам только число о прочитанных байтах
```bash
sudo cat /proc/10720/fdinfo/41 | awk '{print $2}' | head -n1
```
Можно автоматизировать весь этот процесс, для этого создадим скрипт [load_data.sh](load_data.sh)
```bash
sudo touch /usr/local/bin/load_data.sh
sudo chmod +x /usr/local/bin/load_data.sh
```
Теперь, чтобы отследить статус импорта данных в базу MySQL достаточно вызвать
```bash
load_data.sh somefile.txt
```

## <a id="loaddata_split_l">MySQL. LOAD DATA. Загрузка больших объемов</a>
При необходимости загружать файлы с большим объемом (десятки гигабайт), можно разбить файл построчно на части и производить их загрузку частями, например, пусть файл `somefile.csv` занимает 40 Гб, создадим скрипт который сделает дробление с загрузкой
```bash
#!/bin/bash

# разбить построчно по 5 млн строк
split -l 5000000 somefile.csv part_
# пробегаемся по разбитым файлам
for file in part_* ;
do
  echo ">>> $(date) загрузка файла $file"
  # загружеам данные в базу MySQL
  mysql -u root -pPASSWORD -e "
  LOAD DATA INFILE '/docker-entrypoint-initdb.d/split/"$file"'
  IGNORE INTO TABLE docker.sometable 
  FIELDS TERMINATED BY '\t'
  LINES TERMINATED BY '\n'"
done
```
Данный скрипт разбивает файл somefile.csv на множество файлов (part_aa, part_ab, part_ac, …), в каждом из которых содержится по 5 млн записей (строк). Затем происходит загрузка каждого файла в базу под именем docker, таблицу sometable. 

## <a id="bigupdate">MySQL. UPDATE. Обновление большого объема данных</a>
Если необходимо произвести UPDATE большого количество записей, то можно воспользоваться следующим скриптом
```bash
#!/bin/bash
echo "$(date) >>> Скрипт начал работу..."
i=0

while true; do
  # Выполнить частичное обновление и получить число затронутых строк
  ROWS_AFFECTED=$(mysql -u root -pPASSWORD docker -N -B -e "
    UPDATE docker.sometable 
    SET Column1 = Column2  
    WHERE Column1 = '' AND Column2 != '' 
    LIMIT 300000;
    SELECT ROW_COUNT();
  " 2>/dev/null)

  # проверка кода возврата MySQL
  if [ $? -ne 0 ]; then
    echo "Ошибка при выполнении команды MySQL" >&2
    exit 1
  fi

  # Если пустой результат или затронуто 0 строк, выйти из цикла
  if [ -z "$ROWS_AFFECTED" ] || [ "$ROWS_AFFECTED" -eq 0 ]; then
    break
  fi

  # Увеличить счётчик обработанных строк
  i=$((i + ROWS_AFFECTED))

  # Вывести прогресс
  echo "$(date) >>> Обработано за итерацию: $ROWS_AFFECTED записей. Всего: "$i""
done

echo "$(date) >>> Обновление завершено! Всего обработано "$i" записей."
```
Данный скрипт производит обновление по 300 тыс. записей, пока полностью не обновятся все записи, удовлетворяющие условию WHERE.

## <a id="unique_import">MySQL. Импорт только уникальных данных</a>
Допустим есть некая таблица sometable, которая содержит множество дубликатов. Необходимо создать на ее основе таблицу только с уникальными записями. Для этого создаем таблицу table_dist, где будут храниться только уникальные записи таблицы sometable
```sql
CREATE TABLE `table_dist` (
  `Column1` text,
  `Column2` text,
  `Column3` text,
  `hash` varchar(32) unique not null
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```
Далее запустим скрипт, который вычисляет md5 нужных нам данных и производит вставку в таблицу с уникальными записями
```bash
#!/bin/bash

echo "$(date) >>> Скрипт начал работу..."
# счетчик обработанных строк
i=0
# текущая позиция в таблице
offset=0
# количество вставляемых записей за раз
limit=10000

while true; do
  # бесконечный цикл, пока есть затронутые записи в результате
  # выполнения запроса
  ROWS_AFFECTED=$(mysql -u root -pPASSWORD docker -N -B -e "
    INSERT IGNORE INTO docker.table_dist 
    SELECT 
      Column1, Column2, Column3, md5(CONCAT(Column1, Column2)) AS hash 
    FROM docker.sometable 
    LIMIT $limit OFFSET $offset;
    SELECT ROW_COUNT();
  " 2>/dev/null)

  # Проверяем на ошибки
  if [ $? -ne 0 ]; then
    echo "Ошибка при выполнении команды MySQL" >&2
    exit 1
  fi

  # Если пустой результат или затронуто 0 строк, выйти из цикла
  if [ -z "$ROWS_AFFECTED" ] || [ "$ROWS_AFFECTED" -eq 0 ]; then
    break
  fi

  # Увеличить счётчик обработанных строк
  i=$((i + ROWS_AFFECTED))
  offset=$((offset + limit))

  # Выводим прогресс
  echo "$(date) >>> (offset: $offset) Вставлено за итерацию: $ROWS_AFFECTED записей. Всего: $i записей."
done

echo "$(date) >>> (offset: $offset) Вставка завершена! Всего вставлено $i записей."
```

## <a id="mysqldump_pv">MySQL. Прогресс импорта или экспорта дампа базы</a>
### Отображение импорта данных с использованием pv
Распаковка налету файла somedump.sql.gz и импорт данных в базу `somedb` через `pv` в MySQL
```bash
gzip -dc filename.sql.gz | pv | mysql -u root -p somedb
```
### Экспорт базы данных в файл c упаковкой в архив
Создание дампа базы somedb и упаковка в архив с использованием `gzip`
```bash
mysqldump -u root -p somedb | gzip > filename.sql.gz
```