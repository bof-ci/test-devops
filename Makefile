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
	@echo "Not implemented"
