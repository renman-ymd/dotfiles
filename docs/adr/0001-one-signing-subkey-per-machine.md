# One signing subkey per machine under a single PGP identity

Every machine signs commits with its own PGP subkey, and one personal primary key certifies all of them. A signature therefore shows which machine made the commit, while every subkey still belongs to one identity whose user IDs carry the email addresses. SSH authentication keys are also one per machine. A work identity gets its own key on the work machine and never shares the personal primary key, and no personal key ever goes on a work machine.

## Considered options

- **One shared SSH and GPG key on every machine**, as Ciznia/dotfiles does with an Ansible Vault. It's the most convenient, but machines can't be told apart, and one lost machine exposes the identity everywhere.
- **jj's SSH signing with one SSH key per machine.** It tells machines apart, but an SSH key carries no email, so the signature doesn't bind the address.
- **Independent PGP keys per machine.** These tell machines apart and bind the emails, but they look like several separate identities rather than one person signing from different places.

## Consequences

- Enrolling or retiring a machine needs the primary key's secret. Either the primary visits the machine, or the new subkey's secret is exported to it once. Where the primary lives is a separate decision.
- It is unverified whether jj's `signing.key` accepts a subkey selector (a trailing `!`). Check before relying on it.
