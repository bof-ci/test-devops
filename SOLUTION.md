SOLUTION
========

Estimation
----------
Estimated: 8 hours

Spent: 5.5 hours


Solution
--------
Comments on your solution


### 1. Initial setup

Go application is by default listening on 127.0.0.1 because of this
```
var address = flag.String("address", "127.0.0.1", "server address")
```
to fix this added 
```
ip=$(hostname -i)
/usr/local/bin/testserver -address $ip
```
to `entrypoint.sh`
started docker-compose with -d to see the logs, from the logs it is clear main.go is listening on 127.0.0.1. Ping from nginx to testserver was working fine.

### 2. Nginx as a load balancer
If I understood correctly the problem it's about nginx never resolve DNS on runtime, just at startup, but we can force nginx to re-resolve DNS during the application uptime using resolver.

### 3. Environment configuration
We can use to set .env file variables as environment variables
```
set -o allexport
. .env
```

### 4. Graceful shutdown
Make it work with docker-compose (stop, restart): We can fix this by adding `stop_signal: SIGUSR1` to docker-compose.yml.
You will notice that sending a SIGUSR1 to container won't have any effect. App just won't pick up that signal. Why? Can you solve this?
Solution: Use exec "$@", It will replace the current running shell with the command that "$@" is pointing to.
and we can add CMD ["/usr/local/bin/testserver", "-address", "0.0.0.0"] to Dockerfile.

### 5. Docker images
Optimisation: Right now we are using Debian as a base image if we replace that with alpine it will reduce the image size to 18mb

#### 5.2 Organization (optional/bonus)
Imagine that you have an app with the following requirements:
- PHP
- Ruby (sidekiq which calls PHP scripts)
- NodeJS (for building frontend assets)

I would like to have one base image that contains PHP runtime, for PHP and Ruby apps and another one for Nodejs. 
