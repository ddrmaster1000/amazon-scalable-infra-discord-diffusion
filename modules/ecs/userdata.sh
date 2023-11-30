#!/bin/bash
# Neuron Configuration
# Configure Linux for Neuron repository updates
echo 'Starting UserData Script'

# Create a swap volume otherwise it runs out of space when loaded onto the neuron device.
# https://repost.aws/knowledge-center/ec2-memory-swap-file
sudo dd if=/dev/zero of=/swapfile bs=128M count=32
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo swapon -s
sudo sysctl vm.swappiness=10

sudo mkdir -p /etc/ecs/
sudo touch /etc/ecs/ecs.config
sudo cat <<EOT >> /etc/ecs/ecs.config
ECS_CLUSTER=${cluster-id}
EOT

echo 'DONE with Startup Script!'