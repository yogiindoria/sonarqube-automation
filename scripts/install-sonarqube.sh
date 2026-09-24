#!/bin/bash

set -e

echo "===== SonarQube installation started ====="

# -----------------------------
# 1. Create 2 GB Swap
# -----------------------------

if ! swapon --show | grep -q "/swapfile"; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    fi
fi

echo "Swap configured:"
free -h


# -----------------------------
# 2. SonarQube host settings
# -----------------------------

cat > /etc/sysctl.d/99-sonarqube.conf <<EOF
vm.max_map_count=524288
fs.file-max=131072
EOF

sysctl --system


# -----------------------------
# 3. Install Docker
# -----------------------------

apt-get update

if ! command -v docker >/dev/null 2>&1; then
    apt-get install -y docker.io
fi

systemctl enable --now docker


# -----------------------------
# 4. Install Docker Compose
# -----------------------------

if ! docker compose version >/dev/null 2>&1; then
    apt-get install -y docker-compose-v2
fi


# -----------------------------
# 5. Create SonarQube directory
# -----------------------------

mkdir -p /opt/sonarqube
cd /opt/sonarqube


# -----------------------------
# 6. Create Docker Compose
# -----------------------------

cat > docker-compose.yml <<'EOF'
services:

  db:
    image: postgres:17
    container_name: sonarqube-db
    restart: unless-stopped

    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonar

    volumes:
      - postgresql_data:/var/lib/postgresql/data

  sonarqube:
    image: sonarqube:community
    container_name: sonarqube
    restart: unless-stopped

    depends_on:
      - db

    ports:
      - "9000:9000"

    environment:
      SONAR_JDBC_URL: jdbc:postgresql://db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar

    ulimits:
      nofile:
        soft: 131072
        hard: 131072
      nproc:
        soft: 8192
        hard: 8192

    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs

volumes:
  postgresql_data:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
EOF


# -----------------------------
# 7. Start SonarQube
# -----------------------------

docker compose up -d


# -----------------------------
# 8. Show status
# -----------------------------

docker compose ps

echo "===== SonarQube installation completed ====="