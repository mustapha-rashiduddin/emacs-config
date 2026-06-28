Emacs Configuration

This is an Evil-based Emacs configuration centered around Org-mode, C/C++/Python/Bash
development, and a custom SQLite-backed workspace bookmark system.

Requirements:

  - Emacs 29+ (tested on 30.2) compiled with SQLite support.
  - Fonts: CMU Typewriter Text, Scheherazade New (for Arabic), and a Nerd Font /
    Hack (for symbols).

Core Technologies & Packages

  - Base: Evil, Evil Collection, Use-package
  - Code/LSP: Eglot (clangd for C/C++, basedpyright for Python), Corfu,
    Yasnippet
  - Terminal: Eat (Terminal emulation within Eshell)
  - Knowledge Management: Org-mode, Org-roam, Org-transclusion, Org-download
  - Utilities: PDF Tools, Elfeed, Imenu-list, Avy, SQLite (for
    my-speed-dial.el), Xclip

Global Keybindings (SPC Leader)

| Keybinding  | Action                                           |
| :---------- | :----------------------------------------------- |
| `SPC f f`   | Find file                                        |
| `SPC h r r` | Reload `init.el`                                 |
| `SPC h c c` | Native-compile (or byte-compile) config files    |
| `SPC a`     | Open Speed Dial Hydra menu                       |
| `SPC b l`   | List standard bookmarks                          |
| `SPC b s`   | Set standard bookmark                            |
| `SPC b j`   | Jump to standard bookmark                        |
| `SPC b p`   | Jump to speed dial bookmark in current workspace |
| `SPC b m`   | Set absolute bookmark                            |
| `SPC b t`   | Tag current file into speed dial                 |
| `SPC e w`   | Open Eshell in current workspace root            |
| `SPC e f`   | Open Eshell in current file's directory          |
| `SPC n l`   | Toggle Org-roam UI buffer                        |
| `SPC n f`   | Find Org-roam node                               |
| `SPC n i`   | Insert Org-roam node                             |
| `SPC n d`   | Delete current Org-roam node                     |
| `SPC n S`   | Sync Org-roam database                           |
| `SPC n g`   | Start Org-roam-ui (browser graph)                |
| `SPC n c`   | Org capture (to `inbox.org`)                     |
| `SPC n u`   | Generate Org ID for heading                      |
| `SPC n t`   | Toggle Org-transclusion mode                     |
| `SPC n a`   | Add Org-transclusion                             |
| `SPC n m`   | Make Org-transclusion from link                  |
| `SPC n r`   | Remove Org-transclusion                          |
| `SPC t t`   | Toggle ef-themes                                 |
| `SPC c o`   | Toggle Imenu-list (symbol outline sidebar)       |
| `SPC c r`   | Eglot rename (Code)                              |
| `SPC c a`   | Eglot code actions (Code)                        |
| `SPC c f`   | Eglot format buffer (Code)                       |
| `SPC s`     | Jump to inline mark (e.g., `mark:a`)             |

Contextual Keybindings

Org Mode & Transclusions

| Keybinding | Action                                                           |
| :--------- | :--------------------------------------------------------------- |
| `g m`      | Drill down: Transclusion Clone → Org Source Block → Tangled Code |
| `g c`      | Surface up: Tangled Code → Org Source Block → Transclusion Clone |
| `g d`      | Open source of transclusion or ID link at point                  |
| `g r`      | Show notes transcluding the current ID (spawns reference buffer) |
| `g s`      | Toggle manual unfold of link under cursor                        |
| `g y`      | Store smart link (captures `[[id:UUID][Heading]]`)               |
| `g p`      | Insert clean stored link (strips search targets)                 |
| `K`        | Smart Toggle: Open/Hide wrappers/Close blocks, or toggle beacons |

Code (C/C++ & Python)

| Keybinding    | Action                                            |
| :------------ | :------------------------------------------------ |
| `g d`         | Eglot: Find definitions                           |
| `g D`         | Eglot: Find references                            |
| `K`           | Eglot: Eldoc (Hover documentation)                |
| `C-n`         | Corfu: Manually trigger completion in Insert mode |
| `RET` / `C-j` | Corfu: Cycle selection down                       |
| `C-k`         | Corfu: Cycle selection up                         |
| `TAB` / `C-l` | Corfu: Accept completion                          |

PDF Tools

| Keybinding | Action                                         |
| :--------- | :--------------------------------------------- |
| `O`        | Open PDF outline                               |
| `P`        | Show full chapter path/breadcrumb in echo area |

Misc

| Keybinding | Action                                           |
| :--------- | :----------------------------------------------- |
| `g k`      | Avy jump to character                            |
| `G`        | Go to last non-empty line (avoids EOF void)      |
| `v`        | Elfeed: Open current entry's video link in `mpv` |
| `C-l`      | Eshell: Clear buffer                             |

Evil Ex Commands

| Command        | Action                                                       |
| :------------- | :----------------------------------------------------------- |
| `:vintage`     | Switch to CMU Typewriter font                                |
| `:oldschool`   | Switch to IBM VGA font                                       |
| `:beacon`      | Deploy/deactivate hidden transclusion beacon in Org          |
| `:testjmp`     | Smart dispatcher jump to active beacon                       |
| `:tangle`      | Silently tangle current Org file and refresh open targets    |
| `:detangle`    | Silently detangle current source file back to Org            |
| `:org-it`      | Wrap current source buffer into an Org file `src` block      |
| `:colo`        | Select ef-theme (with completion)                            |
| `:command`     | Set Speed Dial HUD to persistent top/bottom view             |
| `:menu`        | Set Speed Dial HUD to default Hydra menu                     |
| `:find-anchor` | Find nearest parent directory that is a registered workspace |

Speed Dial System (SPC a)

The speed dial system uses an SQLite database (speed-dial.sqlite) to store
bookmarks scoped to specific "workspaces" (directories). It utilizes a
two-handed layout: Left hand (a s d f z x c v) for global/inherited slots, and
Right hand (j k l ; m , . /) for tag-specific slots.

Hydra Keybindings (Active after pressing SPC a):

  - Navigation:
      - a-v: Jump to Left Hand slot (Global) 1-8
      - j-/: Jump to Right Hand slot (Dynamic Tag) 1-8
  - Bookmark Management:
      - T: Tag current file to a slot
      - F: Find file on disk and tag to a slot
      - U: Untag a specific slot
      - M: Move/Swap a slot to another key
      - O: Organize (consolidates slots to remove empty gaps)
  - Tag Management:
      - t: Lock/Switch active Right Hand tag
      - C: Create a new tag
      - R: Rename the current tag
      - Y: Copy the current tag's layout to a new tag
      - W: Wipe (delete) a tag
  - Workspace Management:
      - p: Lock to a new workspace directory
      - A: Anchor to a previously used workspace (sorted by path proximity)
      - P: Clone layout from another workspace into the current one
      - I: Inherit global slots from the nearest parent workspace
      - X: Nuke all speed dial entries in the current workspace

Eshell Speed Dial Commands:

  - plant [dir]: Lock workspace to [dir] (defaults to current directory).
  - anchor [dir]: Switch to a known workspace (supports TAB completion sorted by
    proximity).
