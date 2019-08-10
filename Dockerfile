FROM debian:stretch-slim

COPY release/testserver_linux_64 /usr/local/bin/testserver
RUN chmod +x /usr/local/bin/testserver

EXPOSE 8800

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/local/bin/testserver", "-address", "0.0.0.0"]