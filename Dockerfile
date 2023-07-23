FROM alpine:latest

LABEL maintainer="morganzero@sushibox.dev"
LABEL description="Cronjobs"
LABEL name="myCron"

RUN apk update && apk add curl docker jq bash
COPY cronpoint.sh /opt/cronpoint.sh
RUN chmod +x /opt/cronpoint.sh

CMD ["/opt/cronpoint.sh"]
