import smtplib
from email.message import EmailMessage

# set your email and password
# please use App Password
email_address = "test@topgop.com"
email_password = "password"

# create email
msg = EmailMessage()
msg['Subject'] = "Email subject"
msg['From'] = 'no-reply <test@topgop.com>'
msg['To'] = "i.voloshin@optimacros.com"
msg.set_content("This is email message")

# send email
with smtplib.SMTP('192.168.4.0', 25) as smtp:
    smtp.login(email_address, email_password)
    smtp.send_message(msg)

# echo "Test message" | mail -s "Test subject" -a "From: Batman <test@topgop.com>" i.voloshin@optimacros.com

