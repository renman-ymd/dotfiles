# Toolboxes and hosts in one flake

Every machine is built from one flake on one branch. Features live in three toolboxes: `modules/home`, which uses Home Manager options only so it also runs standalone; `modules/darwin`; and `modules/nixos`. Each feature sits behind a `renman-ymd.<feature>.enable` switch. Each machine has a host folder whose system and home parts turn features on. Shared hosts (`shared-dev`, `shared-personal`) hold the choices several hosts share. The shape is adapted from Ciznia/dotfiles (`great-reset` branch), with one toolbox per platform added because that repo has no Mac.

## Considered options

- **One branch per machine.** Every lock update would conflict once per branch, nothing would evaluate the other machines before a push, and the rebuild tools already pick a machine by hostname from one flake.
- **One toolbox imported on every platform**, as Ciznia does with NixOS only. Defining an option the platform doesn't declare fails even under `lib.mkIf false`, which was tested against the locked nixpkgs. Only Home Manager declares `launchd` and `systemd` on every platform, so only the home toolbox can be imported everywhere.
- **A flake framework** (snowfall-lib, digga, flake-parts, nixos-unified). The first two are unmaintained, and four hosts don't need the others.

## Consequences

- Home modules may use Home Manager options only, never `osConfig`, so the work-machine config can import them standalone.
- A feature that spans platforms has one part per toolbox under the same name. Data a feature shares across platforms, such as the tiling keymap, belongs to the feature, not to a shared host.
- Shared hosts split their system part per platform (`system/darwin/`, `system/nixos/`).
