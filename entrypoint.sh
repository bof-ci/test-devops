#!/bin/bash

ip=$(hostname -i)
/usr/local/bin/testserver -address $ip
