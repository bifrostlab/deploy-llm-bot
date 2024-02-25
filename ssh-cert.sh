#!/bin/bash
# This script is used to sign and issue SSH certificates for login into the llm-assistant VMs.
#
# The VMs are configured to use SSH certificates for login. Your public key must be signed by the
# Vault SSH client signer to be able to login into the VMs.
# If you don't have a public key, a new SSH certificate can be issued using the `issue` command.

VAULT_API="https://vault.midgardlab.io/v1"
TOKEN_FILE="$HOME/.config/vault/token"
VAULT_ROLE="hyperstack-appadmin"

# Usage example
if [[ $# -lt 2 ]]; then
    cat << EOF
Usage: $0 [sign|issue] [ARGUMENTS]
  sign [PATH_TO_PUBLIC_KEY]: Sign an existing SSH public key for login into the llm-assistant VMs.
  issue [CERTIFICATE_NAME]: Issue a new SSH certificate for login into the llm-assistant VMs.
EOF
    exit 1
fi

# Login to Vault
vault_login() {

    if [[ ! -d "$HOME/.config/vault" ]]; then
        mkdir -p "$HOME/.config/vault"
    fi

    read -p "Enter your GitHub personal token: " github_token

    json="{ \"token\": \"$github_token\" }"

    result=$(curl -s -X POST -d "$json" "$VAULT_API/auth/github/login")

    if [[ $(echo "$result" | jq -r '.errors') == "null" ]]; then
        client_token=$(echo "$result" | jq -r '.auth.client_token')

        echo "$client_token" > "$TOKEN_FILE"
        echo "Vault client token saved to $TOKEN_FILE"
    else
        echo "Error: Invalid GitHub personal token. Please try again."
        vault_login
    fi
}

# Check if the token file exists
if [[ ! -f "$TOKEN_FILE" ]]; then
    vault_login
fi
# Then load the Vault token
VAULT_TOKEN=$(cat "$TOKEN_FILE")
AUTH_HEADER="X-Vault-Token: $VAULT_TOKEN"

# Issue a new SSH certificate
issue_cert() {
    certificate_name=$1
    json="{ \"key_type\": \"ed25519\" }"

    result=$(curl -s -X POST -H "$AUTH_HEADER" -d "$json" "$VAULT_API/ssh-client-signer/issue/$VAULT_ROLE")

    if [[ $(echo "$result" | jq -r '.errors') == "null" ]]; then

        private_key=$(echo "$result" | jq -r '.data.private_key')
        signed_key=$(echo "$result" | jq -r '.data.signed_key')

        echo "$private_key" > "$certificate_name"
        echo "$signed_key" > "$certificate_name-cert.pub"

        echo "Private key saved to $certificate_name"
        echo "Public key saved to $certificate_name-cert.pub"

    else
        echo "Error: Authentication failed. Please login again."
        vault_login
        VAULT_TOKEN=$(cat "$TOKEN_FILE")
        AUTH_HEADER="X-Vault-Token: $VAULT_TOKEN"
        issue_cert "$certificate_name"
    fi
}

# Sign an existing SSH public key
sign_cert() {
    public_key_file=$1
    public_key=$(cat "$public_key_file")

    cert_file="$(dirname $public_key_file)/$(basename -s .pub $public_key_file)-cert.pub"

    json="{ \"public_key\": \"$public_key\" }"

    result=$(curl -s -X POST -H "$AUTH_HEADER" -d "$json" "$VAULT_API/ssh-client-signer/sign/$VAULT_ROLE")

    if [[ $(echo "$result" | jq -r '.errors') == "null" ]]; then
        signed_key=$(echo "$result" | jq -r '.data.signed_key')

        echo "$signed_key" > "$cert_file"
        echo "Signed key saved to $cert_file"

    else
        echo "Error: Authentication failed. Please login again."
        vault_login
        VAULT_TOKEN=$(cat "$TOKEN_FILE")
        AUTH_HEADER="X-Vault-Token: $VAULT_TOKEN"
        sign_cert "$public_key_file"
    fi
}

command=$1
shift

case $command in
    # Sign an existing SSH public key
    sign)
        if [[ $# -lt 1 ]]; then
            echo "Usage: $0 sign [PATH_TO_PUBLIC_KEY]"
            exit 1
        fi

        sign_cert "$1"

        ;;
    # Issue a new SSH certificate along with a private key
    issue)
        if [[ $# -lt 1 ]]; then
            echo "Usage: $0 issue [CERTIFICATE_NAME]"
            exit 1
        fi

        issue_cert "$1"
        ;;
    *)
        echo "Invalid command: $command"
        exit 1
        ;;
esac
