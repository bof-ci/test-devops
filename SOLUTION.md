SOLUTION
========

Estimation
----------
Estimated: 8 hours

Spent: 1.5 hour


Solution
--------
Comments on your solution


## Initial setup

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

## Nginx as a loadbalancer
If I understood correctly the problem it's about nginx never resolve DNS on runtime, just at startup, but we can force nginx to re-resolve DNS during the application uptime using resolver.