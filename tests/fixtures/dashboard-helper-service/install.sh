#!/usr/bin/env bash
# Installs the news API service on the OOD host.
set -e
curl -fsSL https://get.acme-hpc.org/flask-setup.sh | sudo bash
sudo cp service/news-api.service /etc/systemd/system/
sudo systemctl enable --now news-api
