# Чистка системы Ubuntu

### 1. Очистить кеш apt/dpkg
```bash
# очищаем кеш пакетов
sudo apt-get clean
# удаляем только устаревшие пакеты
sudo apt-get autoclean
# удаляем неиспользуемые зависимости
sudo apt-get autoremove --purge -y  
```

### 2. Очистить остатки старых ядер и заголовков
```bash
sudo apt-get purge $(dpkg --list | egrep "linux-image|linux-headers" | grep '^rc' | awk '{print $2}' | grep -v "$(uname -r)")
```
Как это работает? - Выводится список всех пакетов в системе, затем отбираются только ядра и заголовки. Показываются пакеты в состоянии "rc" (removed, config-files remain), т.е. мусор от старых ядер. После чего берутся только имена пакетов из списка и исключается текущая работающая версия ядра. Затем все найденные пакеты удаляются вместе с конфигами.

### 3. Snap (очистка старых ревизий)
```bash
snap list --all | awk '/disabled/{print $1, $3}' | \
	while read snapname revision; do
		sudo snap remove "$snapname" --revision="$revision"
	done
```

### 4. Flatpak
Flatpak содержит установленные приложения, а также старые версии
```bash
flatpak uninstall --unused
flatpak repair
```

### 5. Systemd journals
```bash
# смотрим сколько занимают логи
sudo journalctl --disk-usage
# очищаем до нужного размера или времени
sudo journalctl --vacuum-size=500M
sudo journalctl --vacuum-time=14d
```

### 6. Виртуальные машины (если используются)
Проверить наличие образов (qcow2/raw) и снапшотов можно глянув внутренности:
```bash
sudo du -h -d1 /var/lib/libvirt/images | sort -h
```
или
```bash
# проверить наличие VM
virsh list --all
# удалить ненужные машины
virsh undefine <vmname> --remove-all-storage
```
Также можно проверить снапшоты
```bash
virsh snapshot-list <vmname>
# удалить ненужные
virsh snapshot-delete <vmname> <snapshot-name>
```

### 7. Общий анализ
Смотрим, что больше всего занимает места
```bash
sudo du -h -d1 / | sort -h
```
Затем проваливаемся в каждый жирный каталог и смотрим что там
