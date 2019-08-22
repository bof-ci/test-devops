SOLUTION
========

Estimation
----------
Estimated: 4 hours

Spent: 7 hours


Solution
--------
Comments on your solution

Problem 1: bad gateway

502 errors are usually caused because the load balancer can't hit the backend service.

Log into docker container and check to see if it responds locally:

    docker ps                                           # find docker container id
    docker exec -it -u root b643b09c5bae /bin/bash      # log in
    apt-get update && apt-get install -y procps curl    # install tools
    ps aux                                              # see that service is running
    curl -i localhost:8800                              # see that service is responding

So according to the app container, service is running fine. Looks for bad wiring between the two containers? Log into LB container and see if we can connect.

    docker ps
    docker exec -it -u root 9aca2870a04e /bin/bash
    apt-get update && apt-get install -y procps curl netcat  # install tools
    curl -i testserver:8800                                 # no dice!

Okay, so the LB container can't connect to the app container. Looking at the docker-compose, there's no port listing for the app container, so tried adding that in.
That got us some progress.

    $ curl localhost:8800
    curl: (7) Failed to connect to localhost port 8800: Connection refused

now we get

    $ curl localhost:8800
    curl: (52) Empty reply from server

that's a new one for me. Did a bit of googling and found some information about configuring app servers to bind on 0.0.0.0 instead of localhost. Peeped inside the `main.go` to see if it supported anything like that and found it had an address string, so I added that flag to the entrypoint.sh and tried again. Success!

    $ curl -i http://testserver.lan
    HTTP/1.1 200 OK
    Server: nginx/1.17.3
    Date: Thu, 22 Aug 2019 11:52:43 GMT
    Content-Type: text/plain; charset=utf-8
    Content-Length: 79
    Connection: keep-alive

    {"hostname":"fd1463c65069","name":"","email":"","project":"","ip":"172.80.1.2"}

Was curious to see if I still needed the port mapping, so I removed that and it still worked, so I removed that bit from the compose file.

Problem 2: Configure Nginx to load balance without restart

Ran `curl -i testserver.lan` a few times in a row and hostname was `77b764c27ce4` for each value, indicating it is not routing to each LB container. Per the documentation, I restarted the nginx container by looking up the container id and then running the command `docker restart 9cc376d74cfd`. After which, each curl command returned a different hostname.

The nginx configuration is just pointing to `testserver.lan`, depending on the docker networking to handle routing the requests. It's likely caching the DNS value it's getting. Some googling revealed that storing the address in a variable forces nginx to resolve it every time, so I made that change and restarted everything and got the empty reply from server error again!

After some debugging, I realized that the first thing the LB container is doing is running `envsubt` to basically just copy the file from one location to another, which was interpretting my var declaration as a env var to be substituted. As it stands now, no vars are being substituted, removed that. After that, I deployed 6 app servers, and each curl call (usually) would direct me to a different hostname.

Problem 3: Configure entrypoint.sh to consume .env

Added `source .env` to enterpoint.sh. `curl` call responded but without the project variable populated. Added debug message to `entrypoint.sh` to echo the value of `$COMPOSE_PROJECT_NAME` to see what would happen.

    testserver_1    | COMPOSE_PROJECT_NAME is [testserver]

So the go app can't see it. Added an export directive to the entrypoint.sh and voila, the project field is populated. But that sucks if we ever need to add another variable, because we have to list it in both places. Instead I swapped out the export logic for:

    set -a
    . ./.env
    set +a

The `a` flag exports everything.

Problem 4: Gracefully shutdown the app by sending it a SIGUSR1 signal.

Tried calling `docker-compose kill -s SIGUSR1 testserver` and docker-compose said it was killing the containers, but `docker ps` showed them still alive. Let's take the hint and log into the container:

    docker ps
    docker exec -it -u root 3c4b332741b3 /bin/bash
    apt-get update && apt-get install -y procps curl netcat dnsutils

Logged in and looked at the processes. Ran the kill command again, and no change to any of the processes. Hm. After a quick google, added this to the docker-compose.yml

    stop_signal: SIGUSR1

Docker down'd and up'd and tried to kill again, and they still remained! This is probably because the bash script is just eating the SIGUSR1 signal and not passing it to the actual application which knows how to handle it. By adding an `exec` to the front of the script's call of testserver, the signal is now correctly handed to the app.

As an added bonus, the `make` call completes about 10s faster.

Problem 5.1: Slim down the docker image

Let's see how big the image is:

    [test-devops 15:27:07]$ docker images
    REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
    dlabs/testserver    latest              c8e2b69c2aad        22 seconds ago      68MB

We're using the debian image as a base though -- maybe try alpine to see how much smaller that makes it?

    REPOSITORY          TAG                 IMAGE ID            CREATED              SIZE
    dlabs/testserver    latest              9e9e3fe6949c        12 seconds ago       18.3MB

That's pretty close to 15 MB. However, when we switched to alpine, the application server stopped working!

Looking at `docker logs` for the container, we see

    standard_init_linux.go:211: exec user process caused "no such file or directory"

Over and over. Let's look at the script. First line is referencing `/bin/bash`, which probably doesn't exist in alpine. Change that to `/bin/sh` and re-run and we get a bit further, but now it's complaining about testserver

    /entrypoint.sh: exec: line 18: /usr/local/bin/testserver: not found

Odd, especially since when we sneak in a `ls /usr/local/bin/testserver` it shows us the file exists! A bit of googlin reveals that alpine will say a file is missing if it just can't locate its dependencies. After googling a bit (and reading [this enlightening blog post](https://blog.codeship.com/building-minimal-docker-containers-for-go-applications/)), adding `CGO_ENABLED=0` might help by forcing the dependencies into the binary, so let's add that. Clean and build and things are working again!

There are some other tricks, but they won't work so great here:
* Chain together multiple `RUN` commands with `&&` instead -- but there's only one!
* Clean up after running `apt-get install ...` -- but we're not installing anything!

The testserver binary is 6 megs though, let's see if we can shrink that at all. We can strip debugging markers with the following linker flags:

    -ldflags="-s -w"

That brings the docker image size down under 15 MB:

    [test-devops 15:40:55]$ docker images
    REPOSITORY          TAG                 IMAGE ID            CREATED              SIZE
    dlabs/testserver    latest              3eb5ad6aa528        4 minutes ago        14.1MB

Problem 5.2: Organization

Assumptions:
* all three are running separately -- ie there's no desire to have them all in the same container.
* PHP scripts are just for backend logic -- ie all page rendering is handled via nodejs.
* No breaking or non-backwards compatible changes made to PHP scripts -- any such changes would be behind feature flags or other toggling solution
* Both Sidekiq and Nodejs will call PHP scripts for various reasons.

I'd create PHP and Ruby containers that have the appropriate runtimes and slimmed down using techniques listed above. The Nodejs assets would be better served by using some sort of global caching system (akamai, cloudfront, etc) so the build process would look something like:

* Each container/package would have its own repo
* A build pipeline would trigger on changes made to each repo
* Pipeline will build the container/package, and then follow appropriate deployment steps to automatically push out changes

Problem 6: Create certs

Added the following command to the Makefile:

    openssl req -x509 -newkey rsa:4096 -keyout crt/testdevops.pem -out crt/testdevops.crt -days 365

Problem 6.1: SSL Termination

Now that we have our certs, we have to make nginx use them. The requires just telling it to listen on 443 and the location of the cert and key files.

Problem 6.2: TLS between LB and App

To get encryption / auth between the LB and the app server, first thing we'll need is a bunch stuff generated by openssl. Put that all into `make certs`, as well as renamed the lb certs to specifically point out that they're for the load balancer.

*Note*: to keep things easy for me, I just hardcoded the password for the certs into the makefile. In the "real world" you'd want to pull that from a secrets manager.

Once I was sure that there was no problem with the new cert names, they neeed to be wired into the app and nginx. I updated entrypoint.sh to take in the new files, and then I updated the nginx configuration to pass in the appropriate matching certs and keys.

Honestly, it took a second to make sure I had the right paths but it once I got that set it worked the first time which more was shocking to me than anyone.

Problem 7: why isn't the name field populated.

After doing a victory lap and running `curl` a bunch of times, I noticed the `name` field wasn't being populated.

Poked around at the go code and saw it was looking for that value from the X-NAME header. Configured nginx to pass that in with the value `wolverine`, the name of the coolest X-Man. ![wolverine](wolverine.png =32x32)
