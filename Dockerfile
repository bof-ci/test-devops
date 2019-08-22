FROM alpine:latest

COPY release/testserver_linux_64 /usr/local/bin/testserver
RUN chmod +x /usr/local/bin/testserver

EXPOSE 8800

ENTRYPOINT ["/entrypoint.sh"]
