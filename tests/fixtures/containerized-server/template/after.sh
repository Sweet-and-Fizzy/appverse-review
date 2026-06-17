#!/bin/bash

echo "Waiting for MLflow on port ${app_port}..."
wait_until_port_used "${port}" 300
echo "MLflow is running on port ${app_port}"
sleep 5
