# Grafana и Prometheus
Grafana - платформа с открытым исходным кодом для визуализации данных и аналитики. Чаще всего используется для построения интерактивных дашбордов

Prometheus - система мониторинга и оповещения, которая собирает метрики по модели pull с заданных HTTP-интерфейсов через регулярные промежутки времени

[Создание каталогов и прав доступа](#create)

[Настройка Prometheus](#prometheus)

[Настройка контейнеров](#pg_docker)

[Настройка Grafana](#grafana)

Пример развертывания системы на сервере будем осуществлять через docker-контейнеры:
## <a id="create">Создание каталогов и прав доступа</a>
Создадим в домашнем каталоге пользователя каталог `monitoring`, в котором будет находится Grafana и Prometheus
```bash
cd ~ && mkdir monitoring && cd monitoring && mkdir grafana-data prometheus-data
```
Также там создадутся каталоги `grafana-data` (для хранения данных от Grafana) и `prometheus-data` (хранение данных Prometheus), мы сделаем проброс этих каталогов в их контейнеры

Для нормальной работы приложений, нужно задать права доступа к их каталогам:
```bash
# права на каталог пользователю с UID 472
sudo chown 472:472 -R ~/monitoring/grafana-data/
# права на каталог пользователю с UID 65534 (nobody)
sudo chown 65534:65534 -R ~/monitoring/prometheus-data/
```
## <a id="prometheus">Настройка Prometheus</a>
Создадим файл `prometheus.yml` и зададим настройку экспортеров и служб:
```bash
touch ~/monitoring/prometheus.yml
```
Файл `prometheus.yml`:
```yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
```

## <a id="pg_docker">Настройка контейнеров</a>
Создадим два файла: `.env` (для хранения логин/пароля Grafana) и `docker-compose.yml`, где опишем процедуру развертывания
```bash
touch ~/monitoring/.env
touch ~/monitoring/docker-compose.yml
```

Файл `.env`:
```
GF_SECURITY_ADMIN_USER=your_user_name
GF_SECURITY_ADMIN_PASSWORD=your_password
```
Файл `docker-compose.yml`:
```yml
version: '3.8'

networks:
  monitoring:
    driver: bridge

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: always
    mem_limit: 128M
    cpus: '0.2'
    ports:
      - "127.0.0.1:9090:9090"
    command: 
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=30d'
    user: "65534:65534"
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    # задать для prometheus-data владельца nobody (UID 65534)
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus-data:/etc/prometheus
    networks:
      - monitoring
  
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: always
    mem_limit: 256M
    cpus: '0.2'    
    ports:
      - "127.0.0.1:3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=${GF_SECURITY_ADMIN_USER}
      - GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}
    user: "472:472"
    read_only: true    
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL      
    # задать для grafana-data владельца UID 472
    volumes:
      - ./grafana-data:/var/lib/grafana
    networks:
      - monitoring
  
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: always
    mem_limit: 32M
    cpus: '0.1'    
    ports:
      - "127.0.0.1:9100:9100"
    user: "65534:65534"
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL      
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.processes'
    networks:
      - monitoring
```
Все готово для сборки, выполняем:
```bash
cd ~/monitoring/
docker compose up -d
```
Порты из контейненров node-exporter (9100), grafana (3000) и prometheus (9090) проброшены только для доступа из локальной сети (127.0.0.1), проверим вывод:
```bash
ss -lntup | egrep "9100|3000|9090" | awk '{print $2, $5}'
```
Должно быть так:
```bash
LISTEN 127.0.0.1:3000
LISTEN 127.0.0.1:9100
LISTEN 127.0.0.1:9090
```
Дополнительно гарантированно заблокируем доступ к этим портам извне:
```bash
sudo ufw deny 3000/tcp
sudo ufw deny 9090/tcp
sudo ufw deny 9100/tcp
```

## <a id="grafana">Настройка Grafana</a>
Открываем в браузере адрес localhost:3000, авторизуемся используя ваши данные из файла `.env`

Переходим в Data Source > Add data source > Prometheus

В разделе Connection (Prometheus server URL *) указываем `http://prometheus:9090` и жмем `Save & test`

Далее переходим Dashboards > New > Import , в поле `Find and import dashboards...` указываем ID: 1860, жмем `Load`

Далее на следующей странице в поле `prometheus` из выподающего списка выбрать `prometheus`, жмем `Import`

Готово, наш сервис мониторинга настроен и осуществляет сбор метрик сервера, просмотр состояния можно увидеть в `Dashboards`