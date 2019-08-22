init-mac:
	@docker-compose down || true
	@printf 'COMPOSE_PROJECT_NAME=testserver\nCOMPOSE_BIND_ADDR=0.0.0.0\nCOMPOSE_HTTP_PORT=80\nCOMPOSE_HTTPS_PORT=443\n' > ./.env
	@make build
	@make image
	@make certs
	@docker-compose up --scale testserver=6 -d
	@curl -i http://testserver.lan
	@curl -ik https://testserver.lan

init-linux:
	@docker-compose down || true
	@printf 'COMPOSE_PROJECT_NAME=testserver\nCOMPOSE_BIND_ADDR=172.80.1.1\nCOMPOSE_HTTP_PORT=80\nCOMPOSE_HTTPS_PORT=443\n' > ./.env
	@make build
	@make image
	@docker-compose up -d

build:
	@docker build -f ./Dockerfile-build -t dlabs/testserver:build .
	@docker run --rm -it -v $$(pwd):/go/src/github.com/dlabs/testserver -e "GOOS=linux" -e "GOARCH=amd64" -e "CGO_ENABLED=0" dlabs/testserver:build go build -ldflags="-s -w" -o release/testserver_linux_64 github.com/dlabs/testserver

image:
	@docker build -t dlabs/testserver:latest .

certs:
	@openssl req -subj '/O=jsywulak./C=US/CN=jsywulak@gmail.com' -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -keyout crt/testdevops-lb.key -out crt/testdevops-lb.crt
	@openssl req -subj '/O=jsywulak./C=US/CN=jsywulak@gmail.com' -newkey rsa:4096 -keyform PEM -keyout crt/ca.key -x509 -days 3650 -outform PEM -out crt/ca.crt -passin pass:password -passout pass:password
	@openssl genrsa -out crt/appserver.key 4096
	@openssl req -subj '/O=jsywulak./C=US/CN=jsywulak@gmail.com' -new -key crt/appserver.key -out crt/appserver.req -sha256
	@openssl x509 -req -in crt/appserver.req -CA crt/ca.crt -CAkey crt/ca.key -set_serial 100 -extensions server -days 1460 -outform PEM -out crt/appserver.crt -sha256 -passin pass:password
	@openssl genrsa -out crt/lb-client.key 4096
	@openssl req -subj '/O=jsywulak./C=US/CN=jsywulak@gmail.com' -new -key crt/lb-client.key -out crt/lb-client.req
	@openssl x509 -req -in crt/lb-client.req -CA crt/ca.crt -CAkey crt/ca.key -set_serial 101 -extensions client -days 365 -outform PEM -out crt/lb-client.crt -sha256 -passin pass:password

clean:
	@docker-compose down || true
	@docker system prune -f
	@rm -rf crt/* release/*
