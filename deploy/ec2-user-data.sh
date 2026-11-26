#!/bin/bash
set -euxo pipefail

dnf update -y
dnf install -y docker git curl openssl
systemctl enable --now docker
usermod -aG docker ec2-user

install -d -m 0755 /usr/local/lib/docker/cli-plugins
curl -fSL \
  https://github.com/docker/compose/releases/download/v5.6.0/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod 0755 /usr/local/lib/docker/cli-plugins/docker-compose

docker --version
docker compose version
