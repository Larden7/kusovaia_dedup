#!/bin/bash

# Create user and group if they don't exist
if ! getent group dedup >/dev/null; then
    groupadd -r dedup
fi

if ! getent passwd dedup >/dev/null; then
    useradd -r -g dedup -s /sbin/nologin -c "Dedup Service User" dedup
fi

# Set proper permissions
chown root:dedup /usr/sbin/dedup-service
chmod 0750 /usr/sbin/dedup-service

chown root:root /etc/dedup-service.conf
chmod 0644 /etc/dedup-service.conf

# Enable and start the service
systemctl daemon-reload
systemctl enable dedup-service

echo "Dedup service installed successfully"
echo "Edit /etc/dedup-service.conf to configure scan paths"
echo "Start with: systemctl start dedup-service"
