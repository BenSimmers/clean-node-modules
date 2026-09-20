# clean-node-modules

Find and delete `node_modules` directories under a root, with sizes reported
before anything is removed. Dry run by default.

```
$ clean-node-modules ~/code
scanning /Users/you/code ...
     394M  beerseeker/node_modules
     335M  map-collator/node_modules
     226M  dependencyviewer/client/node_modules
     ...
32 directories, 5.5 GB total
dry run -- nothing deleted. re-run with --delete to remove them.
```

## Install

One command, straight from the latest release:

```sh
curl -fsSL https://raw.githubusercontent.com/BenSimmers/clean-node-modules/main/install.sh | sh
```

That drops the script in `~/.local/bin` after checking it against the
release's `SHA256SUMS`. Two knobs:

```sh
curl -fsSL .../install.sh | PREFIX=/usr/local sh   # install somewhere else
curl -fsSL .../install.sh | VERSION=v1.0.0 sh      # pin a release
```

If you would rather not pipe a script into a shell, grab the same file from
the [releases page](https://github.com/BenSimmers/clean-node-modules/releases)
and put it on your `PATH` yourself:

```sh
curl -fsSLO https://github.com/BenSimmers/clean-node-modules/releases/latest/download/clean-node-modules
chmod +x clean-node-modules && mv clean-node-modules ~/.local/bin/
```

Or from a clone:

```sh
git clone https://github.com/BenSimmers/clean-node-modules.git
cd clean-node-modules
make install                      # -> ~/.local/bin/clean-node-modules
make install PREFIX=/usr/local    # or somewhere else
```
## Usage

```
clean-node-modules [options] [directory]
```

With no directory it uses the current one, or `$CLEAN_NODE_MODULES_ROOT` if
that is set.

| Option | Effect |
| --- | --- |
| `-d`, `--delete` | actually remove what was found |
| `-y`, `--yes` | skip the confirmation prompt |
| `-n`, `--dry-run` | report only (the default) |
| `-o`, `--older-than DAYS` | only match directories untouched for DAYS+ days |
| `-m`, `--max-depth N` | how deep to search (default: 8) |
| `-h`, `--help` | usage |
| `-V`, `--version` | version |

```sh
clean-node-modules                      # report on the current directory
clean-node-modules ~/code               # report on another directory
clean-node-modules --delete ~/code      # remove, after confirming
clean-node-modules -d -y -o 30 ~/code   # remove anything stale for 30+ days
```

Point it at a parent directory permanently with:

```sh
export CLEAN_NODE_MODULES_ROOT="$HOME/code"
```