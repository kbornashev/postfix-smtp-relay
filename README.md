# Docker smtp relay with sasl auth

## Сборка образа 

1. Требуется склонировать репозиторий. 
2. После этого выполняем сборку образа коммандой 

    docker build  -t postfix-relay .

В итоге имеем в системе образ с именем `postfix-relay`

## Запуск контейнера через docker compose
### Подготовить .env файл

Нужно создать `.env` файла. В репозитории есть файл образец `.env_example` поэтому переименовываем его командой

    mv .env_example .env 

И заполняем значение переменных по образцу данными для работы контейнера.  
Назначение переменных

`RELAY_HOST=smtp.mail.ru` - адрес внешнего smtp сервера для отпраки писем
`RELAY_PORT=465` - порт 
`RELAY_USER=test@mail.ru` - имя пользователя
`RELAY_PASS=super_strong_password` - пароль

`RELAY_FROM=noreply@example.com` - адрес для подмены адреса отправителя в пересылаемых письмах

`WHITE_DOMAIN=example.com` - домен на который можно отправлять письма


`MAIL_DOMAIN=internal_domain.com` - внутренний домен почтового сервера
`SMTP_USERS=test:password,user1:password` - список пользователей почтового домена

### Подготовить docker compose
Проверяем `docker-compose.yml` на то что указанно правильное имя собранного образа. При необходимости меняем внешний порт на котором будем принимать smtp соединения.

### Запуск
Для запуска контейнера в режиме демона выполняем комманду 

    docker compose up -d 

Просмотреть логи postfix

    docker logs postfix-test-relay

Войти в работающий контейнер

    docker exec -it postfix-test-relay /bin/bash

## Тесты

Для проверки отправки изнутри контейнера можно выполнить 

    echo "Test message" | mail -s "Test subject" -a "From: Batman <test@topgop.com>" i.voloshin@optimacros.com

Для проверки авторизации и подмены заголовков можно изменить `mail_send_test.py` указав верные учетные данные для авторизации на почтовом сервере и выполнить его. 


