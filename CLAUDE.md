# Commits

A commit is a title, and in rare cases one body line after a blank line. Nothing more.

The title is `area: imperative summary`, all lowercase except proper names (`aerospace: float Finder and Preview windows`). The area is the component the change touches: a program (`emacs`, `aerospace`, `jj`, `gpg`), a module (`home`, `darwin`), or `homebrew`, `mas`, `flake`. Run `jj log` for the areas already in use and reuse them. Write expressive titles that say what changed and why when the why fits; keep the author's own phrasing when rewording existing commits.

Each commit holds one concern. When a change mixes unrelated work, split it.

- A `flake.lock` bump is its own `flake: update inputs` commit. Each bump stands alone: consecutive bumps are never merged. The only exception is a lock change that cannot be separated from a `flake.nix` change; then the title names both.
- Removing something is its own commit, kept apart from the commit that added it, unless the two land within about 1.5 weeks of each other; then fold the removal into the addition.
- Work in progress that is not ready for `main` goes on its own bookmark.
