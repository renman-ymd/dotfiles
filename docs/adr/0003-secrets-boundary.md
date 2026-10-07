# Secrets: agenix in the repo, Vaultwarden only for keys a human holds

Runtime secrets, only the wakatime key for now, are encrypted with agenix in the public repo. Each machine decrypts them at the system level with a dedicated key it generated itself. Vaultwarden keeps only what a person uses: the age admin key that edits the encrypted files, plus the PGP primary key and its revocation certificates ([ADR 0001](0001-one-signing-subkey-per-machine.md)). These are fetched when editing secrets or enrolling and retiring a machine, never during a rebuild. Wi-Fi passwords are entered by hand on each machine, and work machines get no personal secret.

## Considered options

- **Shared keys in an Ansible Vault, unlocked by a plaintext `.vault_pass` file on every machine**, as Ciznia/dotfiles does. Anything running as the user can read that file and decrypt every key, and it puts the personal identity on any machine where it runs.
- **sops-nix.** Its encrypted files leave key names readable in a public repo, and its macOS module imports the host RSA key into GPG by default, with an open activation issue. Its templates aren't needed for today's secrets.
- **Reading secrets from Vaultwarden at runtime.** It needs an unlocked vault and a network connection, which can't work for a Wi-Fi password, and it makes rebuilds depend on a server a friend runs.
- **SSH host keys as agenix identities.** That ties agenix to sshd being configured, and nobody knows whether macOS updates keep its host key.

## Consequences

- A new machine generates its agenix key on the spot. Its public key is added to the recipients and the secrets are re-encrypted with the admin key from Vaultwarden.
- Losing access to the vault loses the ability to edit secrets, not to rebuild, so an encrypted export of the vault is kept somewhere Renaud controls.
