FROM jenkins/agent:latest
USER root

# Install Python, pip, and virtualenv
RUN apt-get update && \
    apt-get install -y python3 python3-pip && \
    python3 -m pip install --upgrade pip virtualenv

# Switch back to jenkins user
USER jenkins
