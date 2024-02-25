# deploy-llm-bot
Configuration-as-Code repo to deploy LLM Assist Bot.

## Accessing the LLM VMs

A combination of security measures is employed to secure access to the LLM Virtual Machines (VMs):

- [Hashicorp Vault](https://www.hashicorp.com/products/vault): Signing SSH certificate at runtime, ensuring only our team members have access to the server. This certificate will expire after 8h.
- [Github Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens): Validating that only members of the dev team can SSH into the VMs.
- [Cloudflare Tunnel](https://github.com/cloudflare/cloudflared): The VMs do not have public IP addresses exposing to the internet, enhancing their security.

As such, following the steps below to ensure you can access to the LLM VMs through a combination of secure tunnels, authenticated access, and signed certificates:

### Install `cloudflared`

Before proceeding, you must install `cloudflared` on your local machine. This tool creates a secure tunnel to the VMs, facilitating a secure connection without a public IP. For installation instructions, visit the [Cloudflare Tunnel documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/).

### Generate a GitHub Personal Access Token

Next, create a GitHub personal access token with the `read:org` permission to log into Vault. Generate this token by visiting: https://github.com/settings/tokens/new?scopes=read:org.

Safeguard this token as it will be used for authentication.

### Update SSH Configuration

Copy the host definition from the provided [ssh-config](ssh-config) file into your local `~/.ssh/config` to ensure your SSH client recognises how to connect to the VMs.

### Option 1: Existing SSH Key on Private Computer

If you're on a private computer and prefer using an `id_ed25519` key (recommended due to its security benefits over `id_rsa`, which is deprecated in recent Ubuntu LTS releases), follow these instructions to generate a new key pair:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

Replace `"your_email@example.com"` with your email address. When prompted, you can specify a file in which to save the key, or preferably press Enter to use the default location.

This key can then be reused for future authenticate with Vault. You will then need to sign your SSH public key and receive a signed SSH certificate:

```bash
./ssh-cert.sh issue ~/.ssh/id_ed25519.pub
```

You can then connect to the VM by using:

```bash
ssh llm-bastion
```

### Option 2: Ephemeral SSH Key on Public Computer

For users on a public computer, authenticate and generate an ephemeral SSH private key and certificateby running:

```bash
./ssh-cert.sh issue $name
```

This script produces an SSH certificate and private key. Connect to the VM using:

```bash
ssh -i $name-cert.pub -i $name llm-bastion
```
