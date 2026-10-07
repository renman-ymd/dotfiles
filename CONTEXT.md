# Dotfiles

Nix configuration for Renaud's machines: one repository, one flake, and one host per machine.

## Machines

**Air**:
The MacBook Air, the main personal machine.

**Framework**:
The Framework 16 laptop, the personal Linux machine.

**Streaming box**:
The family's shared old laptop that plays streaming video on the projector. It is not one of Renaud's personal machines, and it may later double as a small home server.
_Avoid_: streaming machine, media box

**Work machine**:
A machine owned by an employer. It carries only the work-machine config and no personal key.

## Configuration

**Toolbox**:
The set of features available on one platform: home, darwin or NixOS. Every feature in it stays off until a recipe turns it on.

**Feature**:
One capability behind a single on/off switch, such as the shell, the editor or version control. A feature that spans platforms has one part per toolbox, all under the same name.

**Host**:
The folder that configures one machine: its system part and its home part, which choose the features that are on. The work-machine config is a host with only a home part.
_Avoid_: recipe, profile (clashes with Nix profiles)

**Shared host**:
A host that is no machine of its own, and that holds the choices several hosts share. A host imports it and then adds or overrides.
_Avoid_: common host, base

**Work-machine config**:
The single config that the install script puts on a work machine and the remove script takes away.
_Avoid_: kit, light config, emergency config

## Identity

**Identity**:
Who commits and signs: a name, email addresses and signing keys. The personal identity and a work identity never share a key.

**Primary key**:
The personal PGP key that carries the identity's email addresses and certifies every signing subkey.

**Signing subkey**:
The PGP subkey a single machine signs its commits with.
_Avoid_: machine key, signing key
