ARG PARENT_IMAGE
FROM $PARENT_IMAGE as builder

ARG USER_UID
ARG USER_GID

COPY APIGateway_Install.run /opt/APIGateway_Install.run
COPY scripts/runInstall.sh /opt/runInstall.sh
RUN chmod +x /opt/runInstall.sh && opt/runInstall.sh /opt/APIGateway_Install.run


FROM $PARENT_IMAGE
LABEL maintainer="support@axway.com"

ARG USER_UID
ARG USER_GID

RUN groupadd emtuser -g $USER_GID
RUN adduser emtuser -u $USER_UID -g $USER_GID -c "EMT User" && \
    chmod 777 /opt
COPY --chown=emtuser --from=builder /opt/Axway /opt/Axway
