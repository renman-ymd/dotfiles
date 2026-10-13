## PGP signing subkeys with jj and GitHub

Research date: 2026-10-13. Versions seen while researching: jj 0.45.1 (local `jj --version`, source and docs read at tag `v0.45.1`), GnuPG 2.4.9 with libgcrypt 1.12.2 (local `gpg --version`; source read at tag `gnupg-2.4.9`). GitHub docs were read from the `main` branch of `github/docs` on that date (the source of docs.github.com); one removed page was read at a pinned commit. All local tests ran against throwaway keys in throwaway `GNUPGHOME` directories; nothing of Renaud's keyring, `~/.gnupg`, `~/.config/jj` or repos was read or written.

### 1. How jj passes `signing.key` to gpg (source)

- jj reads `signing.key` as an optional string and hands it to the backend untouched: `signing_key: Option<String>` in `UserSettings`, filled by `config.get("signing.key").optional()` and returned in `sign_settings()` ([settings.rs v0.45.1](https://github.com/jj-vcs/jj/blob/v0.45.1/lib/src/settings.rs), lines 58, 152, 233-237).
- The GPG backend signs with `let key = key.unwrap_or(&self.default_key);` then `self.create_command().args(["-abu", key])`, with the data on stdin; `default_key` is `settings.user_email()` ([gpg_signing.rs v0.45.1](https://github.com/jj-vcs/jj/blob/v0.45.1/lib/src/gpg_signing.rs#L213-L218), [L182](https://github.com/jj-vcs/jj/blob/v0.45.1/lib/src/gpg_signing.rs#L182)). `-abu <key>` is `--armor --detach-sign --local-user <key>`. The key is a single `Command` argument (no shell), so a trailing `!` reaches gpg literally. jj never parses, validates or strips the string.
- Verification runs `gpg --keyid-format=long --status-fd=1 --verify <sigfile> -` and reads the `[GNUPG:]` status lines. It recognises `GOODSIG`, `EXPKEYSIG` (bad unless `signing.backends.gpg.allow-expired-keys`), `NO_PUBKEY` and `BADSIG`; the first two arguments of the line become the signature's `key` (the long key ID of the signing key, subkey included) and `display` (the primary user ID) ([gpg_signing.rs L35-L93](https://github.com/jj-vcs/jj/blob/v0.45.1/lib/src/gpg_signing.rs#L35-L93), [L221-L233](https://github.com/jj-vcs/jj/blob/v0.45.1/lib/src/gpg_signing.rs#L221-L233)).
- The config docs say only: "You can set `key` to anything accepted by `gpg -u`" ([config.md v0.45.1](https://github.com/jj-vcs/jj/blob/v0.45.1/docs/config.md#gnupg-signing)). `docs/templates.md` describes `CryptographicSignature.key()` as "the public key fingerprint" for GPG ([templates.md v0.45.1](https://github.com/jj-vcs/jj/blob/v0.45.1/docs/templates.md)); the test below shows the 16-hex long key ID instead, so the docs are loose on this point.

### 2. GnuPG: what `!` means and how the signing subkey is chosen (manual and source)

- Manual: "an exclamation mark (!) may be appended to force using the specified primary or secondary key and not to try and calculate which primary or secondary key to use" ([GnuPG manual, Specify a User ID](https://www.gnupg.org/documentation/manuals/gnupg/Specify-a-User-ID.html)). The manual does not say which subkey is used without `!`; the source does.
- Source: the `!` suffix sets `desc->exact` only on hex IDs (short or long key ID, or fingerprint) ([common/userids.c L286-L288](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/common/userids.c#L286-L288)). So `fpr!` and `keyid!` work; an email address with `!` does not.
- Source: without `!`, `finish_lookup()` loops over the subkeys of the matched key block and skips those that are not valid, lack the signing usage, are revoked ([L3867](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/g10/getkey.c#L3867)), expired ([L3874](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/g10/getkey.c#L3874)), created in the future ([L3881](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/g10/getkey.c#L3881)), or, when a secret key is wanted, have no secret key in the agent (`agent_probe_secret_key`, [L3888](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/g10/getkey.c#L3888)). Among the remaining ones it keeps the one with the greatest creation timestamp, using a strict `>`, so on a tie the earlier one in the key block wins ([L3919](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/g10/getkey.c#L3919)). With `!`, `foundk` is the exact subkey and only that one is considered ([L3831-L3835](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/g10/getkey.c#L3831-L3835)); the revoked, expired and secret-key checks still apply to it.
- The same code explains why giving a subkey fingerprint without `!` does not pin that subkey: the match is on the key block, and the best subkey is then recomputed.

### 3. Local test setup and isolation

The scratch path from the ticket gives a 138-byte socket path (`.../t02/gnupg-a/S.gpg-agent.extra`), over the macOS limit of about 104 bytes. I used `mktemp -d` under `$TMPDIR` instead (77 bytes): `/var/folders/9z/.../T/t02.O5se`, abbreviated `$D` below. Every gpg call had `GNUPGHOME` set to a directory under `$D`; every jj call had `JJ_CONFIG=$D/jj-a.toml`. Shell was zsh/bash, never Nushell.

```sh
jj --version      # jj 0.45.1
gpg --version     # gpg (GnuPG) 2.4.9, libgcrypt 1.12.2
```

Keyring `a` (the "enrolment machine": primary secret plus three signing subkeys, created two seconds apart so creation times differ):

```sh
export GNUPGHOME=$D/a
# gen.batch: %no-protection, Key-Type: eddsa, Key-Curve: ed25519, Key-Usage: cert, Expire-Date: 0
gpg --batch --pinentry-mode loopback --gen-key $D/gen.batch
for n in 1 2 3; do gpg --batch --pinentry-mode loopback --passphrase '' --quick-add-key $P ed25519 sign 0; sleep 2; done
gpg --list-keys --with-subkey-fingerprints --keyid-format long
```

```text
pub   ed25519/15C8EB3C92F8B322 2026-10-13 [C]
      C1782095469855AFB8615A0F15C8EB3C92F8B322         # P (primary, certify only)
sub   ed25519/81B9C4BB6FE5C659 2026-10-13 [S]
      F03C6F76827DE4D36E1A0DB481B9C4BB6FE5C659         # S1 (oldest)
sub   ed25519/76DB12F2722D0E62 2026-10-13 [S]
      DCDA03136D233086D77930E176DB12F2722D0E62         # S2
sub   ed25519/A5607FC35EA0B4F5 2026-10-13 [S]
      7E6D5051E16A9A3766E98A30A5607FC35EA0B4F5         # S3 (newest)
```

Keyring `b` (a "machine that only imports its own subkey": public key of `a`, plus the secret of S1 only):

```sh
GNUPGHOME=$D/a gpg --export $P > $D/pub.gpg
GNUPGHOME=$D/a gpg --batch --pinentry-mode loopback --passphrase '' --export-secret-subkeys "$S1!" > $D/sec-s1.gpg
export GNUPGHOME=$D/b
gpg --batch --import $D/pub.gpg
gpg --batch --pinentry-mode loopback --passphrase '' --import $D/sec-s1.gpg
gpg --list-secret-keys --with-subkey-fingerprints --keyid-format long
```

```text
sec#  ed25519/15C8EB3C92F8B322 2026-10-13 [C]       # '#' = primary secret absent
ssb   ed25519/81B9C4BB6FE5C659 2026-10-13 [S]       # S1: secret present
ssb#  ed25519/76DB12F2722D0E62 2026-10-13 [S]       # S2: public only
ssb#  ed25519/A5607FC35EA0B4F5 2026-10-13 [S]       # S3: public only
```

jj config (`$D/jj-a.toml`), plus a scratch repo made with `jj git init` in `$D/repo`:

```toml
[user]
name = "Throwaway Test"
email = "throwaway@example.invalid"
[signing]
backend = "gpg"
behavior = "own"
key = "F03C6F76827DE4D36E1A0DB481B9C4BB6FE5C659!"
[ui]
show-cryptographic-signatures = true
```

Isolation check, before signing anything: `jj config list --include-defaults --include-overridden user`, `... signing` and `... ui.show-cryptographic-signatures` showed only the throwaway values (`user.email = "throwaway@example.invalid"`, `signing.key = "F03C...C659!"`); `jj config list --include-defaults | grep -n 'renman\|CB49EE'` matched only `operation.username = "renman-ymd"`, which is jj's OS-user default, not config. `jj config path --user` printed `$D/jj-a.toml`. (`jj config path --repo` prints a path under the user config dir, but the repo is new, so no file exists for it and the effective config showed nothing extra.)

To see which key signed, I used two independent views. The jj template:

```sh
T='description.first_line() ++ " | " ++ if(signature, signature.status() ++ " key=" ++ signature.key() ++ " display=" ++ signature.display(), "(no sig)") ++ "\n"'
jj log -r '@-' --no-graph -T "$T"
```

and, for the first commit, the raw signature packet (`git cat-file commit <id>`, extract the `gpgsig` header, `gpg --list-packets`; git was used only for `cat-file` with `GIT_CONFIG_GLOBAL=/dev/null`):

```text
:signature packet: algo 22, keyid 81B9C4BB6FE5C659
	hashed subpkt 33 len 21 (issuer fpr v4 F03C6F76827DE4D36E1A0DB481B9C4BB6FE5C659)
	subpkt 16 len 8 (issuer key ID 81B9C4BB6FE5C659)
```

jj's `key=` matched the packet's issuer key ID in every case I cross-checked.

### 4. Q1: does `signing.key = "<subkey fpr>!"` work in jj 0.45.1?

Yes. Each row is one `jj commit -m ... --config 'signing.key="<value>"'` on keyring `a`, then the template above on `@-`. Result column is the subkey that signed.

| `signing.key` | signed by |
|---|---|
| `S1!` (oldest subkey) | S1 `81B9C4BB6FE5C659`, `status=good` |
| `S2!` | S2 `76DB12F2722D0E62` |
| `S3!` | S3 `A5607FC35EA0B4F5` |
| `76DB12F2722D0E62!` (long key ID plus `!`) | S2 |
| `P!` (primary fingerprint plus `!`) | fails: `gpg: skipped "C178...B322!": Unusable secret key`, `gpg: signing failed: Unusable secret key`; jj reports `Signing error` / `GPG failed with exit status: 2` and creates no commit |

Because S1 is the oldest subkey, signing with `S1!` rather than S3 proves that `!` overrides the default choice. `jj log` with `ui.show-cryptographic-signatures = true` showed the commit with the `[✓︎]` marker; `jj show -s` printed `Signature: good signature by Throwaway Test <throwaway@example.invalid> 81B9C4BB6FE5C659`.

**Form to copy:** `signing.key = "<40-hex subkey fingerprint>!"`, for example `key = "F03C6F76827DE4D36E1A0DB481B9C4BB6FE5C659!"`. A long key ID with `!` also works, but the GnuPG manual suggests "a fingerprint or at least a long keyID" for `--default-key` ([GPG Configuration Options](https://www.gnupg.org/documentation/manuals/gnupg/GPG-Configuration-Options.html)), so use the fingerprint. The `!` must be inside the TOML string. Using the primary fingerprint with `!` fails because the primary is certify-only.

### 5. Q3: which subkey does GnuPG pick without `!`?

**Keyring `a` (S1, S2, S3 all have secrets).** Every selector without `!` signed with S3 `A5607FC35EA0B4F5`, the newest signing subkey:

| `signing.key` (no `!`) | signed by |
|---|---|
| `S1` (oldest subkey's fingerprint) | S3 |
| `S2` | S3 |
| `S3` | S3 |
| `P` (primary fingerprint) | S3 |
| `throwaway@example.invalid` | S3 |

So naming a subkey without `!` does not pin it.

**Creation-time versus file-order check** (keyring `c`, primary `52CC0FB9FAC520931924DC1E6872A242CEFD1232`, created with `--faked-system-time`): subkeys added in file order `A4D4B9E1C626861A` (2026-03-01), `8CF7A80C61F31867` (2026-04-01), `7529744B34156DB7` (2026-02-01), `CAC154A7043433D8` (2026-05-01, expires 2026-05-02, so already expired).

```text
echo hi | gpg --status-fd=2 -abu $P2            -> SIG_CREATED ... 22A22E28F61099F0862D10278CF7A80C61F31867   # 8CF7..., newest valid by creation time, not last in file, expired CAC1... skipped
# revoke 8CF7... (gpg --edit-key: key 2, revkey, reason 0), then:
echo hi | gpg --status-fd=2 -abu $P2            -> SIG_CREATED ... AB745D057DDF9ED07F67FCD2A4D4B9E1C626861A   # A4D4..., next newest
gpg -abu '22A22E28F61099F0862D10278CF7A80C61F31867!'  (revoked)   -> Unusable secret key
gpg -abu 'CAC154A7043433D8!'                          (expired)   -> Unusable secret key
gpg -abu '7529744B34156DB7!'  (valid, not newest)                 -> SIG_CREATED with 7529744B...
gpg -abu 'order@example.invalid!'                                 -> No secret key
```

This matches the source reading in section 2: newest creation time among valid, unrevoked, unexpired subkeys that have a secret key; `!` on a revoked or expired subkey is refused, not forced; `!` on an email does nothing useful.

**Keyring `b` (only S1's secret, public key has all three subkeys).** Without `!`, the signer is S1 whichever selector names the key, because the other subkeys have no secret and are skipped:

| `signing.key` on `b` | result |
|---|---|
| `P` (no `!`) | signed by S1 `81B9C4BB6FE5C659` |
| `S1`, `S1!`, `81B9C4BB6FE5C659!` | S1 |
| `S3` (no `!`; S3 is public-only here) | S1 (it is the only secret subkey) |
| `throwaway@example.invalid` | S1 |
| `S3!` | fails: `gpg: skipped "7E6D...B4F5!": Unusable secret key`, `gpg: signing failed: Unusable secret key` |

`jj log` on `b` afterwards showed all earlier commits signed by S1, S2, S3 as `good`, because `b` holds the full public key.

**What `--export-secret-subkeys 'S1!'` carries.** Importing `sec-s1.gpg` alone into an empty keyring `e` gave `sec# 15C8EB3C92F8B322 [C]` and `ssb 81B9C4BB6FE5C659 [S]` only: the public primary, the user ID, the public part of the chosen subkey, and a stub for the primary's secret (`--list-packets`: secret key packet, user ID, secret sub key packet). Other machines' subkeys are not included, so such a machine cannot verify their commits until it also imports the full public key. This matches the manual's description of `--export-secret-subkeys` as a GNU extension ([GnuPG manual, Operational GPG Commands](https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html)).

**Answer to Q3:** with several signing subkeys with secrets in one keyring, gpg picks the one with the newest creation date, regardless of which fingerprint (primary, subkey, or email) is named without `!`. On a machine that holds only its own subkey's secret, it picks that subkey. So, for a machine that imports only its own subkey, the key without `!` already works, but pinning with `!` is safer: it fails loudly (`Unusable secret key`) instead of silently signing with another subkey if a second secret subkey ever lands in that keyring (for example on the enrolment machine that holds all subkeys), and it avoids a signer change when someone later adds a newer subkey.

### 6. jj verification and display of subkey signatures

- Good case (tested): a commit signed by a subkey gets `status=good`, `key=<subkey long key ID>`, `display=<primary user ID>`. The signing subkey is visible in `key`, the identity in `display`. `jj log` shows `[✓︎]`; `jj show -s` shows `Signature: good signature by <uid> <subkey long ID>`.
- Missing public key (tested): in an empty keyring `d`, the same commit showed `unknown key= display=`; after `gpg --import pub.gpg` it showed `good`. A machine therefore needs the full public key (all subkeys) to see commits from other machines as good.
- Revoked subkey (tested): after `gpg --edit-key` revoked S2 in keyring `a`, `gpg --status-fd=1 --verify` on a commit signed by S2 printed `[GNUPG:] REVKEYSIG 76DB12F2722D0E62 ...` (and `KEYREVOKED`, `gpg: WARNING: This subkey has been revoked by its owner!`, but also `Good signature`). jj 0.45.1 showed that commit as `unknown key= display=`. Reason from source: `REVKEYSIG` is not in the list handled by `parse_gpg_verify_output`; the other status lines make it return `InvalidSignatureFormat`, and `Signer::verify` skips that error and ends with `Verification::unknown()` ([gpg_signing.rs L46-L93](https://github.com/jj-vcs/jj/blob/v0.45.1/lib/src/gpg_signing.rs#L46-L93), [signing.rs L232-L283](https://github.com/jj-vcs/jj/blob/v0.45.1/lib/src/signing.rs#L232-L283)). So in jj a revoked subkey's old commits drop from `good` to `unknown`, even though they were good when made. Commits signed by the other subkeys stayed `good`.
- Expired subkey: from source, `EXPKEYSIG` gives `bad` unless `signing.backends.gpg.allow-expired-keys = true`. Not run locally (Unverified by test).

### 7. GitHub

All statements below come from GitHub's docs; I did not log in or call authenticated APIs.

**How GitHub verifies a GPG signature.** "When verifying a signature, GitHub extracts the signature and attempts to parse its key ID. The key ID is then matched with keys added to GitHub. Until a matching GPG key is added to GitHub, it cannot verify your signatures." ([Adding a GPG key](https://docs.github.com/en/authentication/managing-commit-signature-verification/adding-a-gpg-key-to-your-github-account)). The key ID in a subkey-made signature is the subkey's (section 3, `--list-packets`: `issuer key ID 81B9C4BB6FE5C659` is S1, not the primary). The committer email must match a user ID of the key and be a verified email on the account ([Using a verified email address in your GPG key](https://docs.github.com/en/authentication/troubleshooting-commit-signature-verification/using-a-verified-email-address-in-your-gpg-key)). GitHub's docs never use the word "subkey" in the verification, add-key, generate-key, telling-Git or associating-email pages (I grepped all of them); the only primary-source trace of subkey handling is the REST schema for a GPG key, which has a required `subkeys` array and `can_sign`, `expires_at` and `revoked` fields ([REST: GPG keys](https://docs.github.com/en/rest/users/gpg-keys)). That the issuer subkey ID is matched against the subkeys of the uploaded key block is therefore an inference. **Unverified**: GitHub's docs don't say how a subkey signature is matched.

**New subkey on the primary key: re-upload?** GitHub's docs don't say. Facts that bound it:
- The only key operations are list, create, get and delete on `/user/gpg_keys`; there is no update/PATCH endpoint, and the UI offers "New GPG key" and delete ([REST: GPG keys](https://docs.github.com/en/rest/users/gpg-keys), [Adding a GPG key](https://docs.github.com/en/authentication/managing-commit-signature-verification/adding-a-gpg-key-to-your-github-account)). Create takes `armored_public_key` (required) and `name`.
- The old page "Updating an expired GPG key", removed on 2022-07-19 (it now redirects to "Adding a GPG key"; removal in [commit ddb4d39](https://github.com/github/docs/commit/ddb4d39e00e3a42edebc93fac31e5f83a6c0534c)), said: "If your key is expired, you must update the expiration, export the new key, delete the expired key in your GitHub account, and upload the new key to GitHub. Your previous commits and tags will show as verified, as long as the key meets all other verification requirements." ([page before removal](https://github.com/github/docs/blob/ddb4d39e00e3a42edebc93fac31e5f83a6c0534c~1/content/authentication/troubleshooting-commit-signature-verification/updating-an-expired-gpg-key.md)). This is the only documented "changed key, re-upload" procedure; it is for expiry, not for a new subkey.
- **Unverified**: that a new subkey requires re-uploading at all, whether re-pasting the updated key while the old entry exists is accepted or rejected as duplicate, and whether GitHub ever refreshes an uploaded key by itself. GitHub's docs don't say.

Procedure consistent with the docs (the delete-then-add form is the old page's pattern; the ordering advice is mine): export the primary's public key after adding the subkey (`gpg --armor --export <primary fpr>`, which includes every subkey and revocation), then in Settings, SSH and GPG keys: delete the old entry and click "New GPG key", paste, "Add GPG key", authenticate if prompted. Do not push commits signed by the new subkey until the new key is added, because a commit's verification record is made when it is pushed (next point).

**Do earlier commits stay Verified?** Yes for commits verified at push time, per two separate statements. "When a commit signature is verified upon being pushed to GitHub, a verification record is stored alongside the commit. This record can't be edited and will persist so that signatures remain verified over time, even if signing keys are rotated, revoked, or if contributors leave the organization." ([About commit signature verification, persistent verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#persistent-commit-signature-verification)). And: "Once a commit has been verified, any commits signed by the corresponding private key will continue to show as verified, even if the public key is removed." ([Adding a GPG key](https://docs.github.com/en/authentication/managing-commit-signature-verification/adding-a-gpg-key-to-your-github-account)). The record is scoped to the repository network (the repo and its forks). Commits that predate the feature get a record "the next time the commit's signature is verified on GitHub", so a commit that has never been verified and whose key is deleted may not be re-verifiable until the key is back. For commits already pushed and verified, delete-and-re-add does not change their status.

**Revoked subkey.** What the docs state:
- Commits verified before the revocation keep their status: "if a signing key is later revoked, expired, or otherwise altered, previously verified commits retain their verified status... GitHub will not re-verify previously signed commits or retroactively adjust their verification status" ([About commit signature verification, Records persist even after revocation and expiration](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#records-persist-even-after-revocation-and-expiration)).
- "To verify as many of your commits as possible, you can add expired and revoked keys. If the key meets all other verification requirements, commits that were previously signed by any of the corresponding private keys will show as verified and indicate that their signing key is expired or revoked." ([Adding a GPG key](https://docs.github.com/en/authentication/managing-commit-signature-verification/adding-a-gpg-key-to-your-github-account)).
- "A GPG key can expire or be revoked when no longer used. The GPG signature may include the information about it being expired or revoked." ([About commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification)).
- The removed 2022 page said: "When verifying a signature, GitHub checks that the key is not revoked or expired. If your signing key is revoked or expired, GitHub cannot verify your signatures. If your key is revoked, use the primary key or another key that is not revoked to sign your commits." That text is no longer published, and I could not tell whether the newer pages replace it or leave it in force.
- **Unverified**: the status of a commit signed by a revoked subkey and pushed for the first time after the revocation, and whether GitHub treats a subkey-level revocation (the primary stays valid) the same as a whole-key revocation. GitHub's docs don't say.

### 8. Consequences for the plan

- `signing.key = "<subkey fingerprint>!"` works in jj 0.45.1 and in GnuPG 2.4.9, and is the only form that pins a subkey on a keyring that holds more than one secret subkey. Without `!`, gpg signs with the newest valid secret subkey, whatever fingerprint is named.
- A machine that imports only its own subkey (`--export-secret-subkeys '<fpr>!'` from the enrolment machine, plus the full public key) signs correctly with either form; `fpr!` is recommended because it errors if the secret ever goes missing and is immune to later subkey additions.
- The subkey fingerprint is a per-machine value in the config: the identity record needs one fingerprint per machine, in addition to the primary's.
- After a new machine is enrolled: re-export the primary's public key, refresh GitHub (delete and add; no in-place update exists in the docs or the REST API), and re-import the full public key on every machine so jj shows the new machine's commits as `good` rather than `unknown`.
- Retiring a machine means revoking its subkey (primary secret needed), re-uploading the public key (so it carries the revocation) to GitHub and to each machine. GitHub keeps already-pushed commits Verified; jj will show that subkey's old commits as `unknown`, not `good`, once the revocation is imported.

### Sources

- jj v0.45.1: [gpg_signing.rs](https://github.com/jj-vcs/jj/blob/v0.45.1/lib/src/gpg_signing.rs), [signing.rs](https://github.com/jj-vcs/jj/blob/v0.45.1/lib/src/signing.rs), [settings.rs](https://github.com/jj-vcs/jj/blob/v0.45.1/lib/src/settings.rs), [docs/config.md](https://github.com/jj-vcs/jj/blob/v0.45.1/docs/config.md), [docs/templates.md](https://github.com/jj-vcs/jj/blob/v0.45.1/docs/templates.md)
- GnuPG: [manual, Specify a User ID](https://www.gnupg.org/documentation/manuals/gnupg/Specify-a-User-ID.html), [manual, Operational GPG Commands](https://www.gnupg.org/documentation/manuals/gnupg/Operational-GPG-Commands.html), [g10/getkey.c @ gnupg-2.4.9](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/g10/getkey.c), [common/userids.c @ gnupg-2.4.9](https://github.com/gpg/gnupg/blob/gnupg-2.4.9/common/userids.c)
- GitHub docs: [About commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification), [Adding a GPG key to your GitHub account](https://docs.github.com/en/authentication/managing-commit-signature-verification/adding-a-gpg-key-to-your-github-account), [Using a verified email address in your GPG key](https://docs.github.com/en/authentication/troubleshooting-commit-signature-verification/using-a-verified-email-address-in-your-gpg-key), [REST: GPG keys](https://docs.github.com/en/rest/users/gpg-keys), [removed page "Updating an expired GPG key" at its last commit](https://github.com/github/docs/blob/ddb4d39e00e3a42edebc93fac31e5f83a6c0534c~1/content/authentication/troubleshooting-commit-signature-verification/updating-an-expired-gpg-key.md), [commit that merged it into the add-key page](https://github.com/github/docs/commit/ddb4d39e00e3a42edebc93fac31e5f83a6c0534c); page source read from the `main` branch of [github/docs](https://github.com/github/docs/tree/main/content/authentication/managing-commit-signature-verification) on 2026-10-13
- Local tests (not links): commands and trimmed outputs in sections 3 to 6, run against throwaway keys in `mktemp -d` directories under `$TMPDIR` with `GNUPGHOME` and `JJ_CONFIG` set explicitly; throwaway agents stopped with `GNUPGHOME=<dir> gpgconf --kill all` for each directory
