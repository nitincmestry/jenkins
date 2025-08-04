# Jenkins with Custom Agent on Podman (macOS)

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Pod Creation](#1-pod-creation)
3. [Jenkins Setup](#2-jenkins-setup)
4. [Custom Agent Setup](#3-custom-agent-setup)
5. [Network Configuration](#4-network-configuration)
6. [Verification](#5-verification)
7. [Maintenance](#6-maintenance)
8. [Troubleshooting](#7-troubleshooting)

---

## Prerequisites
- Podman installed on macOS
- Minimum 4GB RAM allocated to Podman VM
- Git account with SSH key access
- Basic terminal familiarity

---

## 1. Pod Creation

### Create Shared Pod
```bash
podman pod create \
  --name jenkins-pod \
  --publish 8080:8080 \
  --publish 50000:50000 \
  --network bridge
```

**Verify:**
```bash
podman pod ps
```

---

## 2. Jenkins Setup

### Start Jenkins Container
```bash
podman run -d \
  --pod jenkins-pod \
  --name jenkins \
  -v jenkins_home:/var/jenkins_home \
  --security-opt label=disable \
  docker.io/jenkins/jenkins:lts
```

### Get Initial Password
```bash
podman exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

**Access UI:** `http://localhost:8080`

---

## 3. Custom Agent Setup

### 3.1 Create Agent Image

**Dockerfile:**
```dockerfile
FROM jenkins/inbound-agent:latest

USER root

# Install Tools
RUN apt-get update && apt-get install -y \
    bash \
    python3 \
    python3-pip \
    python3-venv \
    git \
    openssh-client \
    iputils-ping \
    net-tools \
    vim \
    curl \
    && rm -rf /var/lib/apt/lists/*

# SSH Setup
RUN mkdir -p /home/jenkins/.ssh && \
    chmod 700 /home/jenkins/.ssh && \
    chown jenkins:jenkins /home/jenkins/.ssh

# Entrypoint Script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER jenkins

ENTRYPOINT ["/entrypoint.sh"]
```

**entrypoint.sh:**
```bash
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
```

### 3.2 Build Image
```bash
podman build -t custom-jenkins-agent .
```

### 3.3 Push Image to Dockerhub or your private registry.
```bash
podman push -t custom-jenkins-agent docker.io/nitincmestry/custom-jenkins-agent:latest.
```

---

## 4. Network Configuration

### Start Agent Container
```bash
podman run -d \
  --pod jenkins-pod \
  --name jenkins-agent \
  -v agent_ssh:/home/jenkins/.ssh \
  --security-opt label=disable \
  nitincmestry/custom-jenkins-agent \
  -url http://localhost:8080 \
  -workDir /home/jenkins/agent \
  -secret <YOUR_SECRET> \
  -name python-agent
```

**Get Secret:**
1. Jenkins UI → **Manage Jenkins** → **Nodes**
2. Click agent → **Secret**

---

## 5. Verification

### Check Containers
```bash
podman ps --pod

# Expected output:
# CONTAINER ID  IMAGE                               COMMAND
# ...           jenkins/jenkins:lts                /usr/bin/tini -- ...
# ...           localhost/custom-jenkins-agent     /entrypoint.sh ...
```

### Test Tools
```bash
podman exec jenkins-agent \
  sh -c "git --version && python3 --version && ssh -T git@github.com"
```

### Verify Jenkins Node
1. Access `http://localhost:8080/computer/python-agent/`
2. Check for "Connected" status

---

## 6. Maintenance

### Start/Stop Pod
```bash
podman pod stop jenkins-pod
podman pod start jenkins-pod
```

### Backup Data
```bash
# Jenkins config
podman volume export jenkins_home > jenkins_backup.tar

# SSH keys
podman volume export agent_ssh > ssh_backup.tar
```

### Update Containers
```bash
podman stop jenkins jenkins-agent
podman pull docker.io/jenkins/jenkins:lts
podman pull localhost/custom-jenkins-agent
podman pod start jenkins-pod
```

---

## 7. Troubleshooting

### Common Issues
1. **Agent Connection Failures:**
   ```bash
   podman exec jenkins-agent curl -I http://localhost:8080
   ```

2. **SSH Permission Errors:**
   ```bash
   podman exec jenkins-agent ls -l /home/jenkins/.ssh
   ```

3. **Missing Tools:**
   ```bash
   podman exec jenkins-agent which git python3 ssh
   ```

### Key Files
| File | Purpose | Location |
|------|---------|----------|
| `entrypoint.sh` | Agent initialization | Agent container |
| `jenkins_home` | Jenkins configuration | Host volume |
| `agent_ssh` | SSH keys | Host volume |

---

## Architecture Diagram
``` 
+-----------------------+
|     Jenkins Pod       |
+-----------------------+
|  Jenkins Master       |
|  - Port 8080          |
|  - Volume: jenkins_home|
+-----------------------+
|  Custom Agent         |
|  - Python/Git/SSH     |
|  - Volume: agent_ssh  |
+-----------------------+
```

[Download Complete Code Samples]([https://your-docs-site.com/jenkins-podman-setup](https://github.com/nitincmestry/jenkins/archive/refs/heads/main.zip))

---

This document provides a complete reference for your Jenkins setup. Let me know if you need any section expanded or additional details!
