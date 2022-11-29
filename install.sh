#!/bin/bash

rm -rf /var/run/saslauthd && \
ln -s /var/spool/postfix/var/run/saslauthd /var/run/saslauthd 

usermod -a -G sasl postfix 
    
#judgement
if [[ -a /etc/supervisor/conf.d/supervisord.conf ]]; then
  exit 0
fi

#supervisor
cat > /etc/supervisor/conf.d/supervisord.conf <<EOF
[supervisord]
nodaemon=true

[program:postfix]
process_name	= master
directory	= /etc/postfix
command		= /usr/sbin/postfix -c /etc/postfix start
startsecs	= 0
autorestart	= false
stdout_logfile=/var/log/supervisor/%(program_name)s.log
stderr_logfile=/var/log/supervisor/%(program_name)s.log

[program:saslauthd]
command=/opt/saslauthd.sh
stdout_logfile=/var/log/supervisor/%(program_name)s.log
stderr_logfile=/var/log/supervisor/%(program_name)s.log


[program:readlog]
command=/usr/bin/tail -f /var/log/maillog
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
EOF

############
#  postfix
############
# cat >> /opt/postfix.sh <<EOF
# #!/bin/bash
# service postfix start
# tail -f /var/log/mail.log
# EOF
# chmod +x /opt/postfix.sh

############
#  saslauthd
############
cat >> /opt/saslauthd.sh <<EOF
#!/bin/bash
service saslauthd start
EOF
chmod +x /opt/saslauthd.sh


postconf -F '*/*/chroot = n'

###########################
#  /etc/postfix/sasl/smtpd.conf
###########################
cat >> /etc/postfix/sasl/smtpd.conf <<EOF
pwcheck_method: saslauthd
mech_list: PLAIN LOGIN
EOF

######################
# sasldb2
#######################
echo $SMTP_USERS | tr , \\n > /tmp/passwd
while IFS=':' read -r _user _pwd; do
  echo $MAIL_DOMAIN $_user $_pwd 
  echo $_pwd | saslpasswd2 -p -c -u $MAIL_DOMAIN $_user
done < /tmp/passwd
chown postfix.sasl /etc/sasldb2

############
#  postfix
############
# Выставляем 2 для отключения обратной совместимости с старыми версиями конфигурации postfix
postconf -e 'compatibility_level = 2'
# Явно выключаем ipv6
postconf -e  'inet_protocols = ipv4'
# Указываем SMTP сервер который мы проксируем, например SMTP сервер от mail.ru
postconf -e  relayhost=[$RELAY_HOST]:$RELAY_PORT
# Разрешаем использловать TLS при подключении к проксируемому SMTP
postconf -e  'smtp_use_tls = yes'
# Разрешаем использовать SASL аутентификацию при подключении к проксируемому SMTP
postconf -e  'smtp_sasl_auth_enable = yes'
# Указываем файл в котором будет лежать логин и пароль от проксируемого SMTP
postconf -e  'smtp_sasl_password_maps = hash:/etc/postfix/relay_pass'
# Запрещаем использовать анонимное соединение с проксируемыми SMTP
postconf -e  'smtp_sasl_security_options = noanonymous'
# Отключение STARTTLS в пользу SUBMISSIONS/SMTPS
postconf -e  'smtp_tls_wrappermode = yes'
# Нужен для smtp_tls_wrappermode
postconf -e  'smtp_tls_security_level = encrypt'
# Включаем режим белого списка для получателей, в файле мы перечислим каким получателям можно отправлять письма
postconf -e  'smtpd_recipient_restrictions = check_recipient_access hash:/etc/postfix/rcpt_whitelist, reject'
# Указываем где искать отправителя в письмах от клиентов для его замены
postconf -e  'sender_canonical_classes = envelope_sender, header_sender'
# Указываем файл в котором лежит регулярное выражение, которое будет анализовать указанных клиентами отправителей и менять
# на нужный для внешнего SMTP. Простыми словами мы хардкодим отправителя
postconf -e  'sender_canonical_maps = regexp:/etc/postfix/sender_canonical_maps'
# Выбираем аутентификацию клиентов через демон Cyrus
postconf -e  'smtpd_sasl_type = cyrus'
postconf -e  'smtpd_sasl_path = smtpd'
# Включаем аутентификацию для клиентов
postconf -e  'smtpd_sasl_auth_enable = yes'
# Выключаем поддержку аутентификации от устаревших клиентов
postconf -e  'broken_sasl_auth_clients = no'
# Запрещаем анонимную аутентификацию от клиентов
postconf -e  'smtpd_sasl_security_options = noanonymous'
# Разрешаем отправку клиентам из общей сети после авторизации
postconf -e  'smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated reject_unauth_destination'

postconf -e  'maillog_file=/var/log/maillog'

###########################
#  /etc/postfix/relay_pass
###########################
cat >> /etc/postfix/relay_pass <<EOF
[$RELAY_HOST]:$RELAY_PORT $RELAY_USER:$RELAY_PASS
EOF
postmap /etc/postfix/relay_pass

##############################
# /etc/postfix/rcpt_whitelist
##############################
IFS=' '
read -ra ADDR <<<"$WHITE_DOMAIN"

for domain in "${ADDR[@]}"
do
  echo "$domain OK" >> /etc/postfix/rcpt_whitelist 
done
postmap /etc/postfix/rcpt_whitelist

####################################
#/etc/postfix/sender_canonical_maps
####################################
cat >> /etc/postfix/sender_canonical_maps <<EOF
/.+/    $RELAY_FROM
EOF
postmap /etc/postfix/sender_canonical_maps

####################################
#/etc/postfix/smtp_header_checks
####################################
if [ ! -z "${RELAY_FROM}" ]; then
  echo -e "/^From:.*$/ REPLACE From: $RELAY_FROM" > /etc/postfix/smtp_header_checks
  postmap /etc/postfix/smtp_header_checks
  postconf -e 'smtp_header_checks = regexp:/etc/postfix/smtp_header_checks'
  echo "Setting configuration option RELAY_FROM with value: ${RELAY_FROM}"
fi
