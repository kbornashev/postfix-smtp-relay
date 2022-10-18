FROM debian:11

# Set noninteractive mode for apt-get
ENV DEBIAN_FRONTEND noninteractive

# Update
RUN apt-get update

# Start editing
# Install package here for cache
RUN apt-get -y install supervisor postfix sasl2-bin libsasl2-modules cyrus-common rsyslog && \
    apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER root
WORKDIR /opt

# Fix saslauthd permissions
# RUN mkdir -p /var/run/saslauthd && \
#     mkdir -p /var/spool/postfix/var/run/saslauthd && \
#     mount --bind /var/spool/postfix/var/run/saslauthd /var/run/saslauthd && \
#     chown root:sasl /var/run/saslauthd && \
#     chmod 710 /var/run/saslauthd && \
#     chmod --reference=/var/run/saslauthd /var/spool/postfix/var/run/saslauthd 

RUN dpkg-statoverride --force-all --update --add root sasl 755 /var/spool/postfix/var/run/saslauthd 


# Ensure saslauthd start on boot
RUN sed -i "s/START=no/START=yes/" /etc/default/saslauthd && \
    sed -i 's/MECHANISMS=".*"/MECHANISMS="sasldb"/g' /etc/default/saslauthd && \
    sed -i 's/OPTIONS=.*/OPTIONS="-c -m \/var\/spool\/postfix\/var\/run\/saslauthd"/g' /etc/default/saslauthd


# Add files
COPY ./install.sh ./

EXPOSE 25
# Run
CMD /opt/install.sh;/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
