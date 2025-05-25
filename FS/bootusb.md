# Создание загрузочной USB
1. Выполнить `sudo fdisk -l` и выяснить путь к своему USB накопителю, в данном случае это /dev/sdc (все действия производить на размонтированном устройстве)
2. Создать разделы для загрузчика и самого образа, в приведенном ниже примере xubuntu.iso это образ записываемой на USB системы
```bash
# Создаем GPT-разметку диска
sudo parted -s /dev/sdc mklabel gpt
# Создаем новый раздел на 100% диска
sudo parted -s --align=optimal /dev/sdc mkpart XUBUNTU 1MiB 100%
# Включаем boot флаг на первый раздел
sudo parted -s /dev/sdc set 1 boot on
# Форматируем весь диск в FAT32
sudo mkfs.vfat -IF 32 /dev/sdc
# Запись ISO на USB
sudo dd if=/path/to/iso/xubuntu.iso of=/dev/sdc bs=8MB status=progress oflag=direct
```