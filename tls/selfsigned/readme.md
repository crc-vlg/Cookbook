# Cамоподписанный TLS-сертификат
Создадим самоподписанный TLS-сертификат для своего сайта (стоит отметить, что данные сертификаты по умолчанию не доверяются браузерами).

Проверим, установлен ли OpenSSL в системе:
```bash
openssl version
```
Если команда не найдена, то произведем установку пакета `sudo apt install openssl`

Создадим папку, где у нас будут храниться ключи с сертификатом и перейдем в нее:
```bash
mkdir -p cert && cd cert
```

### Создание ключей

Создадим закрытый RSA-ключ `private.key`
```bash
# Сгенерируем 2048-битный закрытый RSA-ключ
# Для продакшена лучше 4096
openssl genrsa -out private.key 2048
# Ограничим к нему доступ
chmod 600 private.key
```
Создаем CSR (Certificate Signing Request) запрос, на подпись нашего сертификата
```bash
openssl req -key private.key -new -out cert.csr
```
Можно ничего не заполнять (используя символ `.`), однако дойдя до выбора `Common name (e.g. server FQDN or YOUR name)` необходимо указать наш доменное имя или IP-адрес нашего сервера

Подпишем CSR своим же ключем, создав самоподписанный сертификат
```bash
openssl x509 -signkey private.key -in cert.csr -req -days 365 -out cert.crt
```
Проверим содержимое нашего сертификата:
```bash
openssl x509 -in cert.crt -text -noout
```