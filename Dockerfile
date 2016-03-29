FROM alpine:3.3
MAINTAINER Alexis Ducastel <alexis@ducastel.net>

RUN apk --update add python py-pip bash wget docker && rm -rf /var/cache/apk/ && \
    pip install awscli

COPY *.sh /bin/

RUN chmod 755 /bin/backup-manager.sh && \
    chown root:root /bin/backup-manager.sh && \
    chmod 755 /bin/entry.sh && \
    chown root:root /bin/entry.sh && \
    chmod 755 /bin/backup-task.sh && \
    chown root:root /bin/backup-task.sh

CMD ["/bin/entry.sh"]
