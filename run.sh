#!/bin/bash

# This script starts a new instance of the cloudycube/docker-zimbra container and opens a shell in it.
# It is useful in cases where some debugging is needed...

# run the container
docker run -it \
           --rm \
           --hostname zimbra.my-domain.com \
           --env CC_STARTUP_VERBOSITY=5 \
           cloudycube/zimbra \
           run-and-enter
