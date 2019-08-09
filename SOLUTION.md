SOLUTION
========

Estimation
----------
Estimated: 3 hours

Spent: 1 hour


Solution
--------
Comments on your solution


After you setup your project as described in Technical Setup section you will notice that running curl -i http://testserver.lan will return 502 response. You need to investigate and resolve this issue first. Describe your approach and solution. How did you pinpoint the problem?

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