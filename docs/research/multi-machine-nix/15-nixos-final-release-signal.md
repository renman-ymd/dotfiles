## NixOS final-release signal

Research date: 2026-11-02. Revisions seen:

- **nixpkgs:** `release-26.05` = `nixos-26.05` = `9bb52223f4f6a0cc606fd0852d8784f896c137d5` (2026-11-01, channel build `nixos-26.05.13375.9bb52223f4f6` of 2026-11-02 06:07 UTC). The 26.05 cycle commits: beta `705e9929918b43bd7b715dc0a878ac870449bb03`, last pre-release channel build `ec942ba042dad5ef097e2ef3a3effc034241f011`, release `8c50a710ddca43d7a530fb805ad55bde8d0141c5`.
- **NixOS/infra:** `main` (`channels.nix`), read live. Commits `c34f1487fb80` (26.05 beta) and `2db391810f21` (26.05 stable).
- **NixOS/release-wiki:** `6ea1f27ea66cd938487d32d08c94a13f58a31d70`.
- **NixOS/nixos-channel-scripts:** `09c884825a2c6c4a56abbaf8fe1eed9799f8fde1`. The repo says it was merged into NixOS/infra.
- **NixOS/nixos-homepage:** `main`, plus `795c4d05ff3e9c8d0d5665b6b527463e0b4e2300`.
- **Local tooling:** Lix 2.95.4 (`nix --version`), aarch64-darwin.

Times are UTC. Live endpoints (`channels.nixos.org`, `prometheus.nixos.org`, `hydra.nixos.org`, the GitHub API) were queried on 2026-11-02 between 11:20 and 12:00. Everything under "Local observations" at the end was run, not recalled. The ticket is [45](../../../../.scratch/multi-machine/issues/45-nixos-final-release-signal.md); it feeds ticket 08.

### Short answer

- **Recommended signal:** the `status` of the `nixos-YY.MM` entry in [`channels.nix` of NixOS/infra](https://github.com/NixOS/infra/blob/main/channels.nix). It reads `beta` from branch-off and `stable` once the release managers merge the "mark stable" PR, within about half an hour of the release commit and tag in each of the three most recent cycles (25.05, 25.11, 26.05; 24.11 was the same day, see §4). The official release process names this step ([Final-Release](https://github.com/NixOS/release-wiki/blob/6ea1f27ea66cd938487d32d08c94a13f58a31d70/src/Final-Release.md): "Update `channels.nix` in the infra repository to reflect the `stable` channel status"). `status.nixos.org` and its Prometheus feed show the same value.
- **Fallback:** the first line of `nixos/doc/manual/release-notes/rl-YYMM.section.md` on `release-YY.MM`. It carries `2026.05/??` until the release commit and a day number after it. Alternatively, the git tag `YY.MM` in nixpkgs, which was late in one of four cycles.
- **Not signals:** the existence of the `nixos-YY.MM` branch or channel, and every value in `lib` (`release`, `codeName`, `version`, `versionSuffix`). They are identical in beta and final.
- **One caution:** the channel's beta suffix (`26.05beta1` → `26.05.590`) disappears early, when the release managers flip a Hydra input `stableBranch` to `true`. That was 35 hours before the release in 26.05, so it is not the signal. It is a free extra guard, because it always flipped before `status` did in the four cycles checked.

### 1. channels.nixos.org: existence, redirect target, git-revision

`https://channels.nixos.org/` is an S3 bucket (`nix-channels`) behind a CDN. The index page builds its listing with JavaScript, but the bucket lists as XML at `https://nix-channels.s3.amazonaws.com/?delimiter=/`. Each channel is an empty object with an `x-amz-website-redirect-location` header, so `GET /nixos-26.05` answers `302` ([mirror script](https://github.com/NixOS/nixos-channel-scripts/blob/09c884825a2c6c4a56abbaf8fe1eed9799f8fde1/mirror-nixos-branch.pl)). The release names are the Hydra "nixname" of the `tested` job: `nixos-26.05beta1.705e9929918b` during beta, `nixos-26.05.590.ec942ba042da` after the `stableBranch` flip (§3).

What the same script does at each channel update:

- It creates the release directory in the `nix-releases` bucket, with `git-revision` inside.
- It runs `git push origin $rev:refs/heads/$channelName`. **The `nixos-YY.MM` branch on GitHub is therefore created and advanced by the channel update, not at branch-off.** The first release directory of 26.05 is dated 2026-05-25 16:24, about 29 hours after the branch-off commit. The branch's creation time itself is not exposed by the GitHub API (Unverified; inferred from the script and the first directory date).
- It adds the redirects `nixos-YY.MM` → release directory and `nixos-YY.MM/git-revision` → `<dir>/git-revision`. `git-revision` is a bare commit id with no beta marker.

Live today:

- `https://channels.nixos.org/nixos-26.05` → `302 https://releases.nixos.org/nixos/26.05/nixos-26.05.13375.9bb52223f4f6`.
- `https://channels.nixos.org/nixos-26.11` and `…/nixos-26.11/git-revision` → `404`.

**Verdict:** machine-readable and very reliable, but it only says "a Hydra-tested build exists" and, via the name, whether `stableBranch` is on. Existence flips about a day after branch-off, and the name flips 2 to 35 hours before the release (§9).

### 2. Version files and values in the release branch

Evaluated with `nix eval --raw github:NixOS/nixpkgs/<rev>#lib.trivial.<attr>` at four 26.05 commits:

| Commit | Meaning | `release` | `codeName` | `version` (from a flake input) |
|---|---|---|---|---|
| `705e9929918b` | beta commit, 2026-05-24 | `26.05` | `Yarara` | `26.05.20260524.705e992` |
| `ec942ba042da` | last pre-release channel build, 2026-05-28 | `26.05` | `Yarara` | `26.05.20260528.ec942ba` |
| `8c50a710ddca` | release commit, 2026-05-30 | `26.05` | `Yarara` | `26.05.20260530.8c50a71` |
| `9bb52223f4f6` | today | `26.05` | `Yarara` | `26.05.20261101.9bb5222` |

- **`lib/.version` and `.version`:** `26.05` from the start. `lib/.version` was set to `26.05` on master by "26.05 is Yarara" on 2025-11-24, at the previous branch-off, so the release branch inherits it ([Branch-Off, "Direct changes"](https://github.com/NixOS/release-wiki/blob/6ea1f27ea66cd938487d32d08c94a13f58a31d70/src/Branch-Off.md)). `lib.trivial.codeName` is set the same way.
- **`lib.trivial.versionSuffix`:** in a flake input it is `.<date>.<shortRev>` in both phases, because `lib/trivial.nix` reads a `.version-suffix` file that GitHub archives don't contain, and flakes fill it in from `lastModifiedDate`. In the **channel tarball** (`nixexprs.tar.xz`) the file exists and differs. Evaluated on the tarballs: `26.05beta1.705e9929918b` (beta), `26.05.590.ec942ba042da` (first final-suffix build) and `26.05.13375.9bb52223f4f6` (today). The suffix comes from [`nixos/release.nix`](https://github.com/NixOS/nixpkgs/blob/9bb52223f4f6a0cc606fd0852d8784f896c137d5/nixos/release.nix): `(if stableBranch then "." else "beta") + "${toString (nixpkgs.revCount - 1004291)}.${nixpkgs.shortRev}"`. It reflects the Hydra input, not the git tree (§3).
- **No release marker exists in `lib`.** `lib.trivial` has `release`, `version`, `versionSuffix`, `codeName`, `oldestSupportedRelease`, `oldestSupportedReleaseIsAtLeast` and `isInOldestRelease`, and a name search of `lib` for `release|beta|stable` finds only the last two of those. There is no `isReleaseBranch`.
- **The "26.05 beta release" commit** changes three files: the default channel in `nix-channel.nix` to `nixos-26.05`, `SUPPORT_END = "2026-12-31"` in `version.nix`, and the `release.nix` suffix. It is a branch-off marker, not a release marker. No later commit on `release-26.05` touches them.

**Verdict:** nothing in the source tree flips at release except the release notes heading (§6).

### 3. Hydra: the `stableBranch` input

The Hydra jobset `nixos:release-26.05` has the input `stableBranch` (boolean). The [Branch-Off page](https://github.com/NixOS/release-wiki/blob/6ea1f27ea66cd938487d32d08c94a13f58a31d70/src/Branch-Off.md) creates it as `false` (version suffix `…beta…`) and says `true` leads to a final-looking suffix. The [Final-Release page](https://github.com/NixOS/release-wiki/blob/6ea1f27ea66cd938487d32d08c94a13f58a31d70/src/Final-Release.md) says: "Two days before expected release date, change `stableBranch` to `true` in Hydra and wait for the channel to update".

- **Today:** `curl -H 'Accept: application/json' https://hydra.nixos.org/jobset/nixos/release-26.05` returns `"stableBranch":{"value":"true",…}`.
- **History is in the evaluations**, whose `jobsetevalinputs` record the value used. The oldest three of `…/jobset/nixos/release-26.05/evals?page=7`:

| Eval | Time | `stableBranch` | nixpkgs rev |
|---|---|---|---|
| [1825633](https://hydra.nixos.org/eval/1825633) | 2026-05-24 12:50 | `false` | `705e9929918b` |
| [1825689](https://hydra.nixos.org/eval/1825689) | 2026-05-26 12:01 | `false` | `cb6554026c65` |
| [1825754](https://hydra.nixos.org/eval/1825754) | 2026-05-28 13:48 | `true` | `ec942ba042da` |

The channel built from eval 1825754 was published as `nixos-26.05.590.ec942ba042da` on 2026-05-29 02:26, 34.5 hours before the release commit. So the flip is a real, machine-readable step, but it is a preparation step, not the release.

**Verdict:** machine-readable (JSON, no auth) but early by up to two days, so it is not "final". Hydra only exposes the current value on the jobset page.

### 4. Channel status: NixOS/infra `channels.nix`, status.nixos.org, Prometheus

**The file.** [`channels.nix`](https://github.com/NixOS/infra/blob/main/channels.nix) is a plain attribute set (no imports, no functions except one `mapAttrs`). Its header documents the lifecycle:

- Directly after branch-off: `"beta"`.
- Once the channel is released: `"stable"`.
- Once the next channel is released: `"deprecated"`.
- N months after: `"unmaintained"`.

Each `nixos-YY.MM` entry has `job`, `variant` (`primary`, `small`, …) and `status`. Today: `nixos-26.05 = stable`, `nixos-25.11 = unmaintained`, `nixos-unstable = rolling`, and no 26.11 entry.

**It flips at the release.** The release managers open a PR, merged by the infra team, and the process page lists it as part of the release ("Update `channels.nix` … to reflect the `stable` channel status for $NEWVER and the `deprecated` status for $OLDVER"):

| Cycle | "Beta" PR merged | "Stable" PR merged | Release commit on the release branch |
|---|---|---|---|
| 24.11 | 2024-11-14 (commit date, PR not queried) | [#515](https://github.com/NixOS/infra/pull/515) 2024-11-30 16:26 | 2024-11-30 15:38 |
| 25.05 | not queried | [#694](https://github.com/NixOS/infra/pull/694) 2025-05-23 19:11 | 2025-05-23 18:56 |
| 25.11 | [#902](https://github.com/NixOS/infra/pull/902) 2025-11-24 20:38 | [#907](https://github.com/NixOS/infra/pull/907) 2025-11-30 17:33 | 2025-11-30 16:49 |
| 26.05 | [#1051](https://github.com/NixOS/infra/pull/1051) 2026-05-24 13:17 | [#1064](https://github.com/NixOS/infra/pull/1064) 2026-05-30 13:29 | 2026-05-30 12:58 |

The same lifecycle held for 23.11 and 24.05 in the commit history (stable PRs merged 2023-11-29 and 2024-05-31). The "stable" PR never merged before the release commit in any cycle listed.

**status.nixos.org shows the same value.** Its page is a shell; [`status.js`](https://status.nixos.org/js/status.js) fetches `https://prometheus.nixos.org/api/v1/query?query=channel_revision` and reads the labels `channel`, `revision` and `status`. The exporter ([`channel-exporter.py`](https://github.com/NixOS/infra/blob/main/build/pluto/prometheus/exporters/channel-exporter.py)) takes the `status` label straight from `channels.nix` (`about.get("status", "")`) and the revision from `https://nixos.org/channels/<name>/git-revision`. So Prometheus is a deployed copy of `channels.nix` with a deployment lag.

Prometheus kept history, so the flip is visible in `query_range` (step 1 h):

| Channel | `beta` first sample | `stable` first sample |
|---|---|---|
| nixos-24.11 | 2024-11-17 19:00 | 2024-11-30 17:00 |
| nixos-25.05 | 2025-05-17 14:00 | 2025-05-23 20:00 |
| nixos-25.11 | 2025-11-25 21:00 | 2025-11-30 18:00 |
| nixos-26.05 | 2026-05-25 17:00 | 2026-05-30 14:00 |

For 26.05 the revision `ec942ba042da` (the `.590` build, final-style name) was reported as `beta` from 2026-05-29 03:00 until 2026-05-30 13:00 and as `stable` after that. That is the cleanest evidence that the version name is early and `status` is on time.

**Verdict:** best candidate. Official (the file the release process names), machine-readable, no authentication, flips within an hour of the release commit, and is documented in the file header. Weaknesses:

- It is a human step. A forgotten PR delays the flip, which fails closed (no bump).
- The infra repo may reorganise the file (Unverified for the future; `channels.nix` has had a `status` field in every revision tested back to 2023-11, and the jobset keys were renamed once in 2025-12).
- `prometheus.nixos.org` has no documented stability promise for third parties. It is used by the status page, so it is less likely to break silently, but the file is the better source.

### 5. Git tags in nixpkgs

The release process creates annotated tags: `YY.MM-pre` on master at the previous branch-off, `YY.MM-beta` at branch-off, `YY.MM` on the release commit ([Branch-Off](https://github.com/NixOS/release-wiki/blob/6ea1f27ea66cd938487d32d08c94a13f58a31d70/src/Branch-Off.md), [Final-Release](https://github.com/NixOS/release-wiki/blob/6ea1f27ea66cd938487d32d08c94a13f58a31d70/src/Final-Release.md)). `git ls-remote --tags https://github.com/NixOS/nixpkgs.git refs/tags/26.05` needs no authentication or API quota.

| Tag | Tagger date | Target |
|---|---|---|
| `25.05-beta` / `25.05` | 2025-05-16 17:05 / 2025-05-23 18:58 | `abf9d678aaf6` / `11cb3517b3af` ("Release NixOS 25.05") |
| `25.11-beta` / `25.11` | 2025-11-24 19:23 / 2025-11-30 16:49 | `1dcdcf9efc6a` / `871b9fd269ff` |
| `26.05-beta` / `26.05` | 2026-05-24 11:33 / 2026-05-30 13:00 | `705e9929918b` / `8c50a710ddca` |
| `24.11-beta` / `24.11` | 2024-11-14 16:57 / **2025-03-07 11:17** | **both** `8b27c1239e5c` (the beta commit) |

The 24.11 tag was created more than three months after the 2024-11-30 release and points at the beta commit, so it does not mark the release commit. The tag never appeared early in the four cycles, but it can be late. Today `26.11-pre` exists (created 2026-05-24, target "26.11 is Zokor"); `26.11-beta` and `26.11` do not.

**Verdict:** simple and official, never early, but late in 1 of 4 cycles (fails closed). Good secondary signal.

### 6. The release notes heading

`nixos/doc/manual/release-notes/rl-YYMM.section.md` starts with `# Release 26.05 ("Yarara", 2026.05/??)` and the release commit replaces `??` with the day. Checked at the beta tag and at the final state of each cycle:

| Cycle | At `YY.MM-beta` | On `release-YY.MM` today | Commit that replaced `??` |
|---|---|---|---|
| 24.11 | `2024.11/??` | `2024.11/28` | `9a54d49cd306` "Release 24.11", 2024-11-30 15:38 |
| 25.05 | `2025.05/??` | `2025.05/23` | `11cb3517b3af` "Release NixOS 25.05", 2025-05-23 18:56 |
| 25.11 | `2025.11/??` | `2025.11/30` | `871b9fd269ff` "update references for 25.11", 2025-11-30 16:49 |
| 26.05 | `2026.05/??` | `2026.05/30` | `8c50a710ddca` "Release NixOS 26.05", 2026-05-30 12:58 |

- **It is the release commit itself**, the first thing in the Final-Release procedure ("Update `rl-$NEWVER.section.md` … with the final release date"), so it is the earliest official release marker in git. The same commit is tagged within two minutes.
- **The date text is not always the real date.** 24.11 says `28`, but the commit, the blog post file (`2024-11-30_nixos-24.11.md`) and the channel flip are all 2024-11-30. So check only that `??` is gone.
- **Minor format drift:** curly versus straight quotes around the codename, and `Nixos 25.05` in the 25.05 beta. Match on the `YYYY.MM/DD)` tail, not on the whole line.
- **On `master` the heading is not usable:** `rl-2611.section.md` on master reads `2026.11/??` today, and master gets the final date only through the release PR.

**Verdict:** reliable in 4 of 4 cycles, machine-readable (one `raw.githubusercontent.com` line), but it depends on a Markdown title format. Fallback candidate.

### 7. Release process docs, schedule issue and announcement

- **The process:** the [release wiki](https://nixos.github.io/release-wiki/) (source repo [NixOS/release-wiki](https://github.com/NixOS/release-wiki)). The only formal definition of "final" is the Final-Release checklist: the Hydra `stableBranch` flip two days before, then at release time the release commit (heading date), the `YY.MM` tag, the homepage update, the infra `channels.nix` change to `stable`, and the Discourse announcement.
- **The schedule issue** ([26.05](https://github.com/NixOS/nixpkgs/issues/503391), [26.11](https://github.com/NixOS/nixpkgs/issues/567567)) is a human-edited HTML table with planned dates and ticks. 26.05 planned branch-off 2026-05-18 and release 2026-05-25, and actually did 2026-05-24 (11:00 planned, 11:32 commit) and 2026-05-30. Dates slip by days. The issue was closed on 2026-06-03, after the retrospective, and is not machine-readable. Rejected.
- **The announcement** is a file `core/src/content/blog/announcements/2026-05-30_nixos-26.05.md` in nixos-homepage (front matter `date: 2026-05-30T07:00:00.000Z`, the commit is 13:21), published at <https://nixos.org/blog/announcements/2026/nixos-2605/> ("NixOS 26.05 released"). The title and URL are predictable but the front-matter time is a plan, not the release moment, and there is no index to poll. The Discourse thread was not looked up (Unverified). Rejected as a primary signal.

### 8. nixos.org

- **`flake.nix` in nixos-homepage** pins the stable release: `released-nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05"`. The release PR [#2031](https://github.com/NixOS/nixos-homepage/pull/2031) changed it from `nixos-25.11` on 2026-05-30 13:21, between the tag (13:00) and the infra merge (13:29). It is a one-line grep and it flips at release, but the URL form changed over time (`nixpkgs/nixos-25.11` before, `github:nixos/nixpkgs/nixos-26.05` now), which makes a regex fragile, and the file is website plumbing, not a status record.
- **`https://nixos.org/manual/nixos/stable/`** prints "Version 26.05" and its release-notes page lists `Release 26.05 ("Yarara", 2026.05/30)` first. The nixpkgs manual under `/manual/nixpkgs/stable/` prints "Version 26.05pre-git", so versions differ by manual. Human-facing HTML, so scraping only.
- **`https://nixos.org/download/`** links ISOs under `https://channels.nixos.org/nixos-26.05/latest-nixos-*.iso`. HTML scraping only.
- **No JSON API for the current stable** was found on nixos.org (Unverified beyond the pages above).

### 9. The 26.05 cycle as a worked example

| When (UTC) | Event | Source |
|---|---|---|
| 2025-11-24 20:17 | master becomes 26.05 ("26.05 is Yarara", tag `26.05-pre`) | commit `2493002b10cc` |
| 2026-05-24 11:16 | last master commit in `release-26.05`'s history (merge base) | compare API |
| 2026-05-24 11:32 | "26.05 beta release" commit on `release-26.05`; tag `26.05-beta` 11:33 | [commit](https://github.com/NixOS/nixpkgs/commit/705e9929918b43bd7b715dc0a878ac870449bb03) |
| 2026-05-24 12:50 | first Hydra eval, `stableBranch=false` | [eval 1825633](https://hydra.nixos.org/eval/1825633) |
| 2026-05-24 13:17 | infra: `nixos-26.05` added with `status = "beta"` | [#1051](https://github.com/NixOS/infra/pull/1051) |
| 2026-05-25 16:24 | first channel build `nixos-26.05beta1.705e9929918b` (channel and `nixos-26.05` branch exist from here, §1) | `nix-releases` bucket listing |
| 2026-05-28 13:48 | Hydra eval with `stableBranch=true` | [eval 1825754](https://hydra.nixos.org/eval/1825754) |
| 2026-05-29 02:26 | channel build `nixos-26.05.590.ec942ba042da` (no beta in the name; Prometheus still says `beta`) | bucket listing, Prometheus |
| 2026-05-30 12:58 | "Release NixOS 26.05": heading `??` → `30` | [commit](https://github.com/NixOS/nixpkgs/commit/8c50a710ddca43d7a530fb805ad55bde8d0141c5) |
| 2026-05-30 13:00 | tag `26.05` (signed) | tag object |
| 2026-05-30 13:21 | nixos.org announcement and homepage pin to `nixos-26.05` | homepage commit `795c4d05ff3e` |
| 2026-05-30 13:29 | infra: `nixos-26.05` → `stable`, `nixos-25.11` → `deprecated` | [#1064](https://github.com/NixOS/infra/pull/1064) |
| 2026-05-30 14:00 | Prometheus: `status="stable"` (first hourly sample) | `query_range` |

Branch-off to release was 6 days in 26.05 (25.05: 7, 25.11: 6, 24.11: 16), so "weeks before release" no longer holds; and the `nixos-YY.MM` channel and branch exist only from the first beta channel build, 1 to 3 days after branch-off.

The early flip of the version name, per cycle (first non-beta channel directory vs the "stable" PR):

| Cycle | First non-beta channel build | "Stable" PR merged | Name flips early by |
|---|---|---|---|
| 24.11 | 2024-11-30 06:59 | 2024-11-30 16:26 | 9.5 h |
| 25.05 | 2025-05-23 17:14 | 2025-05-23 19:11 | 2 h |
| 25.11 | 2025-11-29 09:07 | 2025-11-30 17:33 | 32 h |
| 26.05 | 2026-05-29 02:26 | 2026-05-30 13:29 | 35 h |

### 10. What each candidate shows

| Candidate | During beta (26.05, 2026-05-24 to 05-30) | After release | Flips at release? | Machine-readable |
|---|---|---|---|---|
| `nixos-YY.MM` branch / channel exists | no before 2026-05-25 16:24, then yes | yes | no, about 5 days early | yes |
| Channel redirect name (`beta` in it) | `nixos-26.05beta1.…` | `nixos-26.05.<n>.…` | no, 2 to 35 h early | yes (HEAD) |
| `git-revision`, `lib.*`, `.version`, `lib/.version` | same values | same values | no change at all | yes |
| Hydra `stableBranch` | `false` | `true` | no, same as name | yes (JSON) |
| infra `channels.nix` `status` | `beta` | `stable` | **yes** (within 30 min of the commit) | yes |
| status.nixos.org / Prometheus `status` | `beta` | `stable` | **yes** (next hourly sample, 14:00) | yes (JSON) |
| nixpkgs tag `YY.MM` | absent (only `26.05-beta`) | present | **yes**, but 24.11 was 3 months late | yes (`git ls-remote`) |
| `rl-YYMM` heading | `2026.05/??` | `2026.05/30` | **yes**, the release commit itself | yes (one line) |
| homepage `released-nixpkgs-stable` | `nixos-25.11` | `nixos-26.05` | yes (13:21) | yes, fragile format |
| Schedule issue | open, planned dates | ticks, closed 06-03 | no | no |
| Announcement | none | `2026-05-30_nixos-26.05.md` | yes, planned time | no |
| nixos.org manual / download page | 25.11 | 26.05 | yes | HTML scraping only |

### 11. Behaviour around 26.11 (checked 2026-11-02)

Nothing of 26.11 exists yet, so every candidate says "not final" or answers `404`, which is the correct result:

- **GitHub:** no `release-26.11` or `nixos-26.11` branch (`gh api repos/NixOS/nixpkgs/branches/…` → 404). Tags: `26.11-pre` only (no `26.11-beta`, no `26.11`). On master, `lib/.version` is `26.11`, and `rl-2611.section.md` reads `2026.11/??`.
- **Channels:** `https://channels.nixos.org/nixos-26.11` → `404`; the bucket lists no `nixos-26.11`. `channels.nix` has no 26.11 entry, and Prometheus returns only the 25.11, 26.05 and unstable channels. The check output is `nixos-26.05` (stable).
- **Hydra:** no `release-26.11` jobset (`/jobset/nixos/release-26.11` → 404).
- **Schedule** ([issue 567567](https://github.com/NixOS/nixpkgs/issues/567567), last shifted on 2026-10-28 by 5 to 7 days): branch-off on 2026-11-23 08:00 (was 11-16), release on 2026-11-30 08:00 (was 11-23). These are plans and may move again; this research does not rely on them.

When 26.11 branches off, the branch and tag `26.11-beta` appear first, then `channels.nix` gets `nixos-26.11` with `status = "beta"`, then the channel exists. The check below returns `nixos-26.05` until the "mark stable" PR for 26.11 merges, then `nixos-26.11`. The release-notes heading and the tag flip about half an hour earlier.

### 12. Recommendation

**Signal: `status == "stable"` for the highest `nixos-YY.MM` in NixOS/infra `channels.nix`.** Guard: the channel redirect must not point at a `beta` build.

```bash
# needs Nix, jq, curl; $current is the branch in flake.nix, e.g. nixos-26.05
curl -fsSL https://raw.githubusercontent.com/NixOS/infra/main/channels.nix -o "$RUNNER_TEMP/channels.nix"
latest=$(nix eval --json --file "$RUNNER_TEMP/channels.nix" channels \
  | jq -r 'to_entries[]
           | select(.key | test("^nixos-[0-9]{2}\\.[0-9]{2}$"))
           | select(.value.status == "stable")
           | .key' \
  | sort -V | tail -n 1)

# newer than the current one?
[ -n "$latest" ] && [ "$latest" != "$current" ] \
  && [ "$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -n 1)" = "$latest" ] || exit 0

# guard: the channel serves a non-beta build
loc=$(curl -fsSI "https://channels.nixos.org/$latest" | tr -d '\r' | awk 'tolower($1)=="location:"{print $2}')
case $loc in *beta*|"") exit 0 ;; esac
# → move nixpkgs-stable to github:NixOS/nixpkgs/$latest
```

- **Why this and not the others:** the file is the definition of channel status, a named step in the release process, and the only candidate that is both on time (4 of 4 cycles) and a single structured value. It also covers skipped releases (the workflow takes the highest stable, not "current + 6 months").
- **Tested** with Lix 2.95.4 against the file at commits from each phase of five cycles: it returned the previous release during each beta and the new release at each "stable" commit (e.g. `c34f1487fb80` → `nixos-25.11`; `2db391810f21` → `nixos-26.05`; `a50e09f83074` → `nixos-25.05`; `5b60cb1b0647` → `nixos-25.11`; `bce86f5d9fe1` → `nixos-24.05`). Against live `main` with `current=nixos-25.11` it prints `nixos-26.05`; with `nixos-26.05` or `nixos-26.11` it exits with nothing to do.
- **Failure mode:** fails closed. A 404 on the file, a missing key or an unmerged PR means no bump; only a mislabelled `stable` would bump early, and that never happened in the cycles checked.
- **Plain-JSON alternative to the first block** (no Nix needed, same data with a deployment lag): `curl -fsSG https://prometheus.nixos.org/api/v1/query --data-urlencode 'query=channel_revision{variant="primary",status="stable"}' | jq -r '.data.result[].metric.channel' | sort -V | tail -n 1`. It returned `nixos-26.05` today.

**Fallback if `channels.nix` changes shape or is unavailable: the release-notes heading on the release branch.**

```bash
v=${latest#nixos-}; n=${v/./}                       # 26.05 → 2605
h=$(curl -fsS "https://raw.githubusercontent.com/NixOS/nixpkgs/release-$v/nixos/doc/manual/release-notes/rl-$n.section.md" | sed -n 1p)
printf '%s' "$h" | grep -Eq '[0-9]{4}\.[0-9]{2}/[0-9]{2}\)'   # true = final; "/??)" = beta; 404 = no branch yet
```

`$latest` there has to come from the candidate version, e.g. the next `nixos-YY.MM` after the current one (+6 months) if `channels.nix` is the thing that broke. Run `sed -n 1p`, not `head -n1`, so `curl` isn't killed by a closed pipe. Use `git ls-remote --tags https://github.com/NixOS/nixpkgs.git "refs/tags/$v"` (non-empty = released) as a second cross-check, bearing in mind the 24.11 delay.

### Unverified

- **When GitHub's `nixos-YY.MM` branch is created.** Inferred from the channel script and the first release directory; the API gives no creation date.
- **The 26.11 release itself.** Whether `channels.nix` flips to `stable` for 26.11 within an hour of the release is a prediction from four cycles, not an observation. The schedule dates are plans.
- **Release moments before 24.11.** Infra PR merge times for 23.11 and 24.05 are known (2023-11-29, 2024-05-31), but their release commit and tag times were not compared.
- **Stability promises.** Nothing says `channels.nix` keeps its shape or that `prometheus.nixos.org` is a supported third-party API.
- **How the Discourse announcement for 26.05 reads**; it was not looked up.
- **Whether nixos.org exposes the current stable in JSON.** None was found; not exhaustively searched.
- **The PR times for 25.05's and 24.11's beta channel entries** (only commit dates were read for 24.11).

### Sources

- NixOS infrastructure: [channels.nixos.org](https://channels.nixos.org/), bucket listings [nix-channels](https://nix-channels.s3.amazonaws.com/?delimiter=/) and [nix-releases, 26.05](https://nix-releases.s3.amazonaws.com/?list-type=2&delimiter=/&prefix=nixos/26.05/), [status.nixos.org](https://status.nixos.org/) and [status.js](https://status.nixos.org/js/status.js), [prometheus.nixos.org `channel_revision`](https://prometheus.nixos.org/api/v1/query?query=channel_revision), Hydra [jobset nixos:release-26.05](https://hydra.nixos.org/jobset/nixos/release-26.05) and evals [1825633](https://hydra.nixos.org/eval/1825633), [1825689](https://hydra.nixos.org/eval/1825689), [1825754](https://hydra.nixos.org/eval/1825754).
- NixOS/infra: [channels.nix](https://github.com/NixOS/infra/blob/main/channels.nix), [channel-exporter.py](https://github.com/NixOS/infra/blob/main/build/pluto/prometheus/exporters/channel-exporter.py), [channel.nix](https://github.com/NixOS/infra/blob/main/build/pluto/prometheus/exporters/channel.nix), PRs [#515](https://github.com/NixOS/infra/pull/515), [#694](https://github.com/NixOS/infra/pull/694), [#902](https://github.com/NixOS/infra/pull/902), [#907](https://github.com/NixOS/infra/pull/907), [#1051](https://github.com/NixOS/infra/pull/1051), [#1064](https://github.com/NixOS/infra/pull/1064).
- nixos-channel-scripts: [mirror-nixos-branch.pl at 09c884825a2c](https://github.com/NixOS/nixos-channel-scripts/blob/09c884825a2c6c4a56abbaf8fe1eed9799f8fde1/mirror-nixos-branch.pl).
- Release process: [release-wiki Branch-Off](https://github.com/NixOS/release-wiki/blob/6ea1f27ea66cd938487d32d08c94a13f58a31d70/src/Branch-Off.md), [Final-Release](https://github.com/NixOS/release-wiki/blob/6ea1f27ea66cd938487d32d08c94a13f58a31d70/src/Final-Release.md), [Beta-Phase](https://github.com/NixOS/release-wiki/blob/6ea1f27ea66cd938487d32d08c94a13f58a31d70/src/Beta-Phase.md), published at [nixos.github.io/release-wiki](https://nixos.github.io/release-wiki/). Schedules: [NixOS 26.05 – Release schedule](https://github.com/NixOS/nixpkgs/issues/503391), [NixOS 26.11 – Release schedule](https://github.com/NixOS/nixpkgs/issues/567567).
- nixpkgs at pinned commits: [nixos/release.nix @ 9bb52223f4f6](https://github.com/NixOS/nixpkgs/blob/9bb52223f4f6a0cc606fd0852d8784f896c137d5/nixos/release.nix), [lib/trivial.nix @ 9bb52223f4f6](https://github.com/NixOS/nixpkgs/blob/9bb52223f4f6a0cc606fd0852d8784f896c137d5/lib/trivial.nix), [rl-2605.section.md @ 9bb52223f4f6](https://github.com/NixOS/nixpkgs/blob/9bb52223f4f6a0cc606fd0852d8784f896c137d5/nixos/doc/manual/release-notes/rl-2605.section.md), [26.05 beta commit](https://github.com/NixOS/nixpkgs/commit/705e9929918b43bd7b715dc0a878ac870449bb03), [Release NixOS 26.05](https://github.com/NixOS/nixpkgs/commit/8c50a710ddca43d7a530fb805ad55bde8d0141c5), [25.05 release commit](https://github.com/NixOS/nixpkgs/commit/11cb3517b3af6af300dd6c055aeda73c9bf52c48), [25.11 release commit](https://github.com/NixOS/nixpkgs/commit/871b9fd269ff6246794583ce4ee1031e1da71895), [24.11 release commit](https://github.com/NixOS/nixpkgs/commit/9a54d49cd306bcf7b6c2cc9df6fd004b110d66e8), [tags](https://github.com/NixOS/nixpkgs/tags), [`26.05` tag ref](https://api.github.com/repos/NixOS/nixpkgs/git/ref/tags/26.05).
- nixos.org: [26.05 announcement](https://nixos.org/blog/announcements/2026/nixos-2605/), [announcement source](https://github.com/NixOS/nixos-homepage/blob/795c4d05ff3e9c8d0d5665b6b527463e0b4e2300/core/src/content/blog/announcements/2026-05-30_nixos-26.05.md), [homepage flake.nix](https://github.com/NixOS/nixos-homepage/blob/main/flake.nix), [release PR #2031](https://github.com/NixOS/nixos-homepage/pull/2031), [NixOS manual (stable)](https://nixos.org/manual/nixos/stable/), [release notes (stable)](https://nixos.org/manual/nixos/stable/release-notes), [download page](https://nixos.org/download/).
- Local observations (not links): `nix --version`; `nix eval --raw github:NixOS/nixpkgs/<rev>#lib.trivial.{release,codeName,version,versionSuffix}` at the four 26.05 revisions; `nix eval` of `lib.trivial.version` and `.version-suffix` on the channel tarballs `nixos-26.05beta1.705e9929918b`, `nixos-26.05.590.ec942ba042da`, `nixos-26.05.13375.9bb52223f4f6` and `nixos-25.11beta186.2fecba995209`; `nix eval --json --file channels.nix channels` on `channels.nix` at ten infra commits plus `main`; `curl -I` on `channels.nixos.org/nixos-26.05` and `…/nixos-26.11`; Prometheus `query` and `query_range`; `git ls-remote --tags` on nixpkgs; the draft check scripts in the scratchpad `t45/` directory.
