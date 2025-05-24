# fail2ban

[Установка](#Установка)

[Настройка](#Настройка)

[Перманентная блокировка](#ПерманентнаяБлокировка)

[Частые команды](#ЧастыеКоманды)

## <a id="Установка">Установка</a>
```bash
sudo apt install fail2ban
```

## <a id="Настройка">Настройка</a>

Настройка fail2ban для защиты SSH, сканирования портов и блокировки повторных нарушителей на более длительный срок

### 1. Cоздаем файл jail.local
```bash
sudo touch /etc/fail2ban/jail.local
```
Прописываем [там](jail.local) правила
```
[DEFAULT]
# Указываем, что ведутся journalctl
backend = systemd

bantime.increment = true
bantime.factor = 1
bantime.formula = ban.Time * (1<<(ban.Count if ban.Count<20 else 20)) * banFactor

# чтоб не забанить самого себя
ignoreself = true
ignoreip = 127.0.0.0/24 ::1 1.2.3.4

bantime = 1d
findtime = 3h
maxretry = 3
banaction = iptables-allports

# Защита SSH
[sshd]
port = 22, 12345
enabled = true
mode = extra

# Защита от сканирования портов
[portscan]
enabled = true
filter = portscan
backend = systemd
logpath = journalmatch:_SYSTEMD_UNIT=kernel.service
maxretry = 1
findtime = 1h
bantime = 6h

# Перманентный банлист
[manualban]
enabled  = true
filter   = manualban
action   = iptables-allports[name=ManualBan]
logpath  = /dev/null
bantime  = -1
maxretry = 1
```
Здесь в `ignoreip` мы задали игнорировать IP-адреса локальной сети, а также для примера указали игнорировать IP-адрес 1.2.3.4

В jail `[sshd]` мы следим за 22 и 12345 портами
### 2. Cоздаем файл portscan.conf
```bash
sudo touch /etc/fail2ban/filter.d/portsacn.conf
```
Прописываем [там](portscan.conf) настройки фильтра сканирования портов
```
[Definition]
failregex = (\[.*?\])?\s*\S+\s+kernel:.*IN=.*SRC=<HOST>.*PROTO=TCP.*
ignoreregex =
```
### 3. Cоздаем файл manualban.conf
```bash
sudo touch /etc/fail2ban/filter.d/manualban.conf
```
Прописываем [там](manualban.conf) настройки фильтра для перманентных банов (пустой)
```
[Definition]
# Этот фильтр не анализирует логи, нужен для запуска действия при бане
failregex = 
ignoreregex =
```
### 4. Настройка уровня логирования SSH
```bash
sudo nano /etc/ssh/sshd_config
```
Задать LogLevel значение VERBOSE

## <a id="ПерманентнаяБлокировка">Перманентная блокировка</a>
Сервер регулярно подвергается воздействию различных сканеров, для блокировки наиболее актинвных IP-адресов (регулярно сканируют ваш хост и блокируются portscan), их можно добавить в перманентный банлист.

Автоматизируем этот процесс, чтобы выявлять IP-адреса, которые ранее попадали в бан более определенного количества раз и внесем их в постоянный банлист (manualban).

Для этого создать файл [ban_persistent_ips.sh](ban_persistent_ips.sh), дать права выполнения
```bash
sudo touch /usr/local/bin/ban_persistent_ips.sh
sudo chmod +x /usr/local/bin/ban_persistent_ips.sh
```
После выполнения скрипта, все IP-адреса, которые блокировались ранее более 50 раз будут внесены в постоянный банлист. Или можно задать свой порог, например:
```bash
sudo ban_persistent_ips.sh 120
```
Будут внесены в постоянный бан IP-адреса, которые ранее блокировались более 120 раз
## <a id="ЧастыеКоманды">Частые команды</a>
|Команда|Описание|
|-|-|
|`fail2ban-client status`|Просмотр текущего статуса|
|`fail2ban-client status <имя_jail>`|Просмотр статуса для конкретного jail|
|`fail2ban-client unban <IP-адрес>`|Разблокировка IP|
|`fail2ban-client set <имя_jail> banip <IP>`|Блокировка IP вручную в кокретном jail|
|`fail2ban-client set <имя_jail> unbanip <IP>`|Разблокировка IP вручную в кокретном jail|
|`fail2ban-client -t`|Проверить конфигурацию Fail2ban на ошибки|
|`fail2ban-client set <имя_jail> reset`|Сбросить статистику для конкретного jail|
|`fail2ban-client stop <имя_jail>`|Остановить блокировку новых IP для конкретного jail|
|`fail2ban-client start <имя_jail>`|Включить jail|
|`grep 'Ban' /var/log/fail2ban.log \| awk '{print $NF}' \| sort \| uniq -c \| sort -nr \| head`|Вывести список уникальных IP адресов, заблокированных по несколько раз и количество их блокировок в порядке убывания|
