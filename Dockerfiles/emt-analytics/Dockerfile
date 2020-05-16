ARG PARENT_IMAGE
FROM $PARENT_IMAGE as builder

ARG DOCKER_IMAGE_ID
ARG ANALYTICS_PORT
ARG ANALYTICS_USERNAME
ARG METRICS_DB_URL
ARG METRICS_DB_USERNAME
ARG REPORTS_DIR
ARG EMAIL_REPORTS
ARG EMAIL_TO
ARG EMAIL_FROM
ARG SMTP_CONN_TYPE
ARG SMTP_HOST
ARG SMTP_PORT
ARG SMTP_USERNAME
ARG CLEANUP_REPORT

COPY APIGateway_Install.run /opt/APIGateway_Install.run
COPY scripts/runInstall.sh /opt/runInstall.sh
RUN chmod +x /opt/runInstall.sh && opt/runInstall.sh /opt/APIGateway_Install.run

COPY opt/emt_resources /opt/emt
COPY scripts/* /opt/Axway/analytics/posix/bin/

RUN cp /opt/emt/lic.lic /opt/Axway/analytics/conf/licenses && \
    cd /opt/Axway/analytics/posix/bin && \
    ./setup-emt-analytics \
        --props /opt/emt/config.props \
        --fed /opt/emt/fed.fed \
        --merge-dir /opt/emt/analytics \
        --docker-image-id "$DOCKER_IMAGE_ID" \
        --analytics-port "$ANALYTICS_PORT" \
        --analytics-username "$ANALYTICS_USERNAME" \
        --metrics-db-url "$METRICS_DB_URL" \
        --metrics-db-username "$METRICS_DB_USERNAME" \
        --reports-dir "$REPORTS_DIR" \
        --email-reports "$EMAIL_REPORTS" \
        --email-to "$EMAIL_TO" \
        --email-from "$EMAIL_FROM" \
        --smtp-conn-type "$SMTP_CONN_TYPE" \
        --smtp-host "$SMTP_HOST" \
        --smtp-port "$SMTP_PORT" \
        --smtp-username "$SMTP_USERNAME" \
        --cleanup-report "$CLEANUP_REPORT"


FROM $PARENT_IMAGE
LABEL maintainer="support@axway.com"

RUN yum install -y libXext && \
    yum install -y libXrender && \
    yum install -y xorg-x11-fonts-Type1 && \
    yum install -y xorg-x11-fonts-75dpi && \
    adduser emtuser -c "EMT User"
COPY --chown=emtuser --from=builder /opt/Axway /opt/Axway

USER emtuser
CMD ["/opt/Axway/analytics/posix/bin/start-emt-analytics"]
