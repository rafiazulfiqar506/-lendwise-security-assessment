# A minimal Ubuntu "Linux host" standing in for LendWise's server —
# this is what Task 3 actually hardens: SSH, firewall, services, patching.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# --- Fully update/patch the host (deliverable requirement) ---
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y openssh-server iptables sudo iproute2 && \
    rm -rf /var/lib/apt/lists/*

# --- Service reduction: only what's needed is installed above.
# No extra services (cron, mail, ftp, telnet, etc.) are added, keeping
# the attack surface minimal.

# --- Create a non-root admin user (no direct root SSH login) ---
RUN useradd -m -s /bin/bash labadmin && \
    usermod -aG sudo labadmin && \
    mkdir -p /home/labadmin/.ssh && \
    chmod 700 /home/labadmin/.ssh

# --- SSH key-only auth: public key installed, password auth disabled ---
COPY keys/lendwise_host_key.pub /home/labadmin/.ssh/authorized_keys
RUN chmod 600 /home/labadmin/.ssh/authorized_keys && \
    chown -R labadmin:labadmin /home/labadmin/.ssh

# --- Hardened sshd_config (see file for details) ---
COPY sshd_config /etc/ssh/sshd_config

RUN mkdir -p /run/sshd

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
