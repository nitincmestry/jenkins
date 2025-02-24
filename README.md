# Jenkins on Podman with Python Build Support and GitHub SSH Integration

This guide explains how to set up Jenkins on Podman with a custom Python-enabled agent and SSH key integration for GitHub.

---

## Prerequisites

- **Podman**: Installed and configured on your system.
- **Python**: Required for builds (installed in the agent image).
- **GitHub Account**: To add the SSH key for repository access.

---

## Steps

### 1. Create a Custom Jenkins Agent Image with Python and SSH

Create a `Dockerfile` for the agent:

```dockerfile
FROM jenkins/agent:latest
USER root

# Install Python, pip, virtualenv, and SSH
RUN apt-get update && \
    apt-get install -y python3 python3-pip openssh-client && \
    python3 -m pip install --upgrade pip virtualenv && \
    mkdir -p /home/jenkins/.ssh && \
    chown jenkins:jenkins /home/jenkins/.ssh && \
    chmod 700 /home/jenkins/.ssh

# Copy entrypoint script to generate SSH keys
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER jenkins

ENTRYPOINT ["/entrypoint.sh"]
```

Create an `entrypoint.sh` script to generate SSH keys (if missing):

```bash
#!/bin/sh
set -e

# Generate SSH key pair if it doesn't exist
if [ ! -f ~/.ssh/id_ed25519 ]; then
  echo "Generating SSH key pair..."
  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -q
fi

# Execute the command passed to the container
exec "$@"
```

**Build the image:**

```bash
podman build -t jenkins-python-agent .
```

---

### 2. Start Jenkins Master in a Podman Pod

Create a pod and run the Jenkins master:

```bash
podman pod create --name jenkins-pod -p 8080:8080 -p 50000:50000

podman run -d --pod jenkins-pod \
  --name jenkins-master \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts
```

Retrieve the initial admin password:

```bash
podman exec jenkins-master cat /var/jenkins_home/secrets/initialAdminPassword
```

---

### 3. Configure Jenkins Agent Node

1. Access Jenkins at `http://localhost:8080` and complete setup.
2. Create a new agent named `python-agent`:
   - **Remote root directory**: `/home/jenkins/agent`.
   - **Launch method**: `Launch agent via Java Web Start`.

---

### 4. Start the Agent with SSH Key Persistence

Run the agent with a volume to persist SSH keys:

```bash
podman run -d --pod jenkins-pod \
  --name jenkins-python-agent \
  -v jenkins_agent_ssh:/home/jenkins/.ssh \
  jenkins-python-agent \
  java -jar /usr/share/jenkins/agent.jar \
  -jnlpUrl http://localhost:8080/manage/computer/python-agent/jenkins-agent.jnlp \
  -secret <your-secret-here>
```

---

### 5. Add SSH Key to GitHub

1. **Retrieve the public key** from the agent container:

```bash
podman exec jenkins-python-agent cat /home/jenkins/.ssh/id_ed25519.pub
```

2. **Add the key to GitHub**:
   - Go to **GitHub Settings** > **SSH and GPG Keys** > **New SSH Key**.
   - Paste the public key and save.

---

### 6. Test SSH Connection to GitHub (Optional)

Run a shell inside the agent container to verify SSH access:

```bash
podman exec -it jenkins-python-agent /bin/bash
ssh -T git@github.com  # Should show "You've successfully authenticated!"
```

---

### 7. Configure Jenkins Job with SSH Access

1. Create a Jenkins job (e.g., Freestyle project).
2. Add a build step to clone a GitHub repository via SSH:
   ```bash
   git clone git@github.com:your-username/your-repo.git
   ```
3. Assign the job to the `python-agent`.

---

## Optional: Configure SSH for GitHub Host

Add GitHub to the SSH `known_hosts` file to avoid prompts:

```bash
podman exec -it jenkins-python-agent /bin/bash
ssh-keyscan github.com >> ~/.ssh/known_hosts
```

---

## Notes

- **SSH Key Persistence**: The `-v jenkins_agent_ssh:/home/jenkins/.ssh` volume ensures keys survive container restarts.
- **Security**: Never share the private key (`id_ed25519`). The agent runs as a non-root user (`jenkins`).
- **GitHub Permissions**: Ensure the SSH key has read/write access to your repositories.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

This `README.md` includes SSH key generation and GitHub integration. Adjust repository URLs and permissions as needed!
