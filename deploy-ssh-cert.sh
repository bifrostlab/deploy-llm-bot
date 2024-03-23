#!/bin/bash
# Deploy SSHD to accept signed SSH certificates

# Install the Vault CA public key
sudo curl -o /etc/ssh/vault-CA.pem https://vault.midgardlab.io/v1/ssh-client-signer/public_key

# Configure SSHD to accept signed SSH certificates
sudo tee /etc/ssh/sshd_config.d/vault-CA.conf <<EOF
TrustedUserCAKeys /etc/ssh/vault-CA.pem
AuthorizedPrincipalsFile /etc/ssh/principals/%u
EOF

# Add a deploy user that can run docker commands
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG docker deploy

# Ensure the AuthorizedPrincipalsFile directory exists
sudo mkdir -p /etc/ssh/principals
sudo tee /etc/ssh/principals/deploy <<EOF
appadmin
EOF
sudo tee /etc/ssh/principals/ubuntu <<EOF
admin
EOF

# Restart SSHD
sudo systemctl restart sshd
