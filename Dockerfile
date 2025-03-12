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
