#!/bin/bash

# Generate SSH Key
if [ ! -f /home/jenkins/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f /home/jenkins/.ssh/id_rsa -q -N ""
fi

# Fix Permissions
chmod 700 /home/jenkins/.ssh
chmod 600 /home/jenkins/.ssh/id_rsa
chmod 644 /home/jenkins/.ssh/id_rsa.pub

# Start SSH Agent
eval $(ssh-agent -s)
ssh-add /home/jenkins/.ssh/id_rsa

# Connect to Jenkins
exec /usr/local/bin/jenkins-agent "$@"
