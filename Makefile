init-mac:
	@docker-compose down || true
	@printf 'COMPOSE_PROJECT_NAME=testserver\nCOMPOSE_BIND_ADDR=0.0.0.0\nCOMPOSE_HTTP_PORT=80\nCOMPOSE_HTTPS_PORT=443\n' > ./.env
	@make build
	@make image
	@docker-compose up -d

init-linux:
	@docker-compose down || true
	@printf 'COMPOSE_PROJECT_NAME=testserver\nCOMPOSE_BIND_ADDR=172.80.1.1\nCOMPOSE_HTTP_PORT=80\nCOMPOSE_HTTPS_PORT=443\n' > ./.env
	@make build
	@make image
	@docker-compose up -d

build:
	@docker build -f ./Dockerfile-build -t dlabs/testserver:build .
	@docker run --rm -it -v $$(pwd):/go/src/github.com/dlabs/testserver -e "CGO_ENABLED=0" -e "GOOS=linux" dlabs/testserver:build go build -o release/testserver_linux_64 github.com/dlabs/testserver

image:
	@docker build -t dlabs/testserver:latest .

certs:
	@openssl genrsa -out crt/rootCA.key 4096
	@openssl req -x509 -new -nodes -key crt/rootCA.key -sha256 -days 1024 -out crt/rootCA.crt -config crt/csr.conf
	@openssl genrsa -out crt/testserver.lan.key 2048
	@openssl req -new -key crt/testserver.lan.key -out crt/testserver.lan.csr -config crt/csr.conf
	@openssl x509 -req -in crt/testserver.lan.csr -CA crt/rootCA.crt -CAkey crt/rootCA.key -CAcreateserial -out crt/testserver.lan.crt -days 500 -sha256

	@openssl genrsa -out crt/client.key 2048
	@openssl req -new -key crt/client.key -out crt/client.csr -config crt/client.conf
	@openssl x509 -req -in crt/client.csr -CA crt/rootCA.crt -CAkey crt/rootCA.key -CAcreateserial -out crt/client.crt -days 500 -sha256