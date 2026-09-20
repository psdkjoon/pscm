# pscm

psdk's smart copy and move CLI tool.

## Usage

```
pc <source> <destination> [-f|--force] [-j|--jobs N]
pm <source> <destination> [-f|--force] [-j|--jobs N]
```

Works on files and directories, no `-r` needed. Empty directories, symlinks,
permissions and modification times are preserved.

## Install

Download the installer for your platform from the latest release.

Linux:

```
chmod +x pscm-linux-x64-installer
./pscm-linux-x64-installer
```

The installer asks for sudo when needed, installs `pc` and `pm` to
`/usr/local/bin` and sets up bash, zsh and fish completions.

To remove it:

```
./pscm-linux-x64-installer --uninstall
```

Windows: run `pscm-windows-x64-installer.exe`.

## Completion

The Linux installer already installs completions. To manage them by hand:

```
sudo pc --install-completion
sudo pc --uninstall-completion
```

To print a script instead of installing it:

```
pc --completion bash
pc --completion zsh
pc --completion fish
```

bash needs the `bash-completion` package (`sudo pacman -S bash-completion` on
Arch). If zsh does not pick the completion up, delete `~/.zcompdump*` and
restart it.

## Building the Linux installer

```
dart compile exe bin/pc.dart -o dist/pc
dart compile exe bin/pm.dart -o dist/pm
dart run tool/build_installer.dart dist/pc dist/pm dist/pscm-linux-x64-installer
```
