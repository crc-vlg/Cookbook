# Docker

### Установка
##### официальная докуметация по установке [тут](https://docs.docker.com/engine/install/ubuntu/)
Перед началом установки на чистую ОС необходимо добавить репозитории Docker
```bash
# Обновим список доступных пакетов
sudo apt-get update
# Установим curl и пакета с сертификатами
sudo apt-get install ca-certificates curl
# создаем директорию с правами доступа
sudo install -m 0755 -d /etc/apt/keyrings
# Скачиваем GPG ключ Docker
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
# задаем права
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Добавим репозиторий в список источников apt:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```
Производим установку нужных для работы пакетов
```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
Проверим, что все корректно установлено, для этого скачаем и запустим тестовый образ. Когда контейнер будет запущен, он сообщит об этом
```bash
sudo docker run hello-world
```

Добавим текущего пользователя в группу docker, чтобы выполнять команды без использования `sudo`
```bash
sudo usermod -aG docker $USER
```