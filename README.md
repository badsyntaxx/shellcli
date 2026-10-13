### A powershell scripts library

# Shell CLI

Shell CLI aims to simplify running PowerShell commands. It is no different from a regular PowerShell session, but it provides a more user-friendly
interface, simpler commands and interactive menus. The idea is to streamlines tasks on Windows computers such as user, system and network management,
by providing short, intuitive commands and/or menus.

## Before we begin

NOTE There are some anti-virus softwares that block Shell CLI. Some do and some don't. If you encounter an av software that does there are some
[steps you can take](https://github.com/badsyntaxx/shellcli?tab=readme-ov-file#bypass-anti-virus).

## Getting started

Open powershell as an administrator, paste in the command below and hit Enter. That's it!

Getting started\
`irm https://raw.githubusercontent.com/badsyntaxx/shellcli/main/init.ps1 | iex`

The above command is shorthand Powershell. It is the same as\
`Invoke-RestMethod https://raw.githubusercontent.com/badsyntaxx/shellcli/main/init.ps1 | Invoke-Expression`

## Using the menu

If you don't know any commands, you can just enter the `menu` command. Once in the menu, you can use the _up_ and _down_ arrow keys to make selections
and then the enter key to confirm your selection.\
![Shell CLI menu](https://otdxeogkplcwxljyshyd.supabase.co/storage/v1/object/public/images/shellcli/shellcli.webp)

## Using commands

You don't need to rely on the menu. You can accomplish more, faster, by accessing commands directly. For instance, creating a new user or editing the
target PC's network adapter can be done with short intuitive commands.

Add a new local user to the system.\
`add local user`

Edit the network adapters on target PC.\
`edit net adapter`

## Commands

### TOGGLE ADMINISTRATOR

Toggle the Windows built-in administrator account.\
`toggle admin`

### ADD USER ACCOUNTS

Add a new user to the target system. Gives option to add local or domain users.\
`add user`

Add a new local user to the target system. Skips prompt to choose local or domain.\
`add local user`

Add a new domain user to the target system. Skips prompt to choose local or domain.\
`add domain user`

### REMOVE USER ACCOUNTS

Remove an existing user account from the target system.\
`remove user`

### EDIT USER ACCOUNTS

Edit an existing user account on the system.\
`edit user`

Edit a user account name.\
`edit user name`

Edit a user account password.\
`edit user password`

Edit a user accounts groups.\
`edit user group`

### EDIT HOSTNAME & DESCRIPTION

Edit the hostname and description of the target computer.\
`edit hostname`

### EDIT NETWORK ADAPTERS

Edit network adapter settings on the target computer.\
`edit net adapter`

### GET WIFI CREDENTIALS

View WiFi SSID and passwords for the currently enabled NIC's.\
`get wifi creds`

### REPAIR WINDOWS

Run common Windows repair commands like system file checks and cleanup & restore.\
`repair windows`

## Configuration

ShellCLI reads `config.json` from the root of the repo each time it starts. It sets the repository ShellCLI downloads from, the folders it uses and
the list of commands. The file is required, and ShellCLI has no built-in defaults and no built-in commands. If it cannot be downloaded, is not valid
JSON, lacks a setting or has a wrong one, ShellCLI stops with an error that lists every problem it found. When ShellCLI opens its own administrator
window (the UAC prompt), that window waits for Enter after an error, so the message can be read.

Every setting below must be present. There is nothing to leave out.

### Repository

- `repository` is the link to the GitHub repository, for example `https://github.com/badsyntaxx/shellcli`. Command modules are downloaded from it.
  Any other https address works too, as long as the files are served at `<address>/main/user.ps1` and so on. Plain http is refused.
- `branch` is the branch, tag or commit to download modules from. It is required for a GitHub link, and not allowed for any other address (put the
  branch in that address instead).

One address cannot come from `config.json`: the one `config.json` itself is downloaded from. It is the line `$global:shellcliBootstrapBase` at the top of
`init.ps1`, for example `https://raw.githubusercontent.com/owner/repo/main` (no trailing slash). ShellCLI downloads `init.ps1`, `framework.ps1`,
`main/core.ps1` and `config.json` from there, and the command modules only from the `repository` in `config.json`. A tag in `branch` therefore pins
the modules but not the framework; to pin everything, put the same tag in the bootstrap line. If `repository` names a different repository than the
bootstrap line, ShellCLI starts but warns, so a fork that updates only one of the two gets told. It also warns if the bootstrap address is not https,
because that address is not otherwise checked.

To fork ShellCLI, change these:

1. `$global:shellcliBootstrapBase` in `init.ps1`.
2. `repository` and `branch` in `config.json`. The `config.json` that ships here points at the original repository.
3. The command at the top of this README, and the initializer link at the bottom.
4. The documentation link in `writeHelp` in `main/core.ps1`, and the one in `plugins/core.ps1`.

Keep the folder layout (`main`, `plugins`, `framework.ps1`, `init.ps1`, `config.json`).

### Folders

- `rootDirectory` is ShellCLI's own folder, and nobody else's. The module cache is kept in a `cache` folder inside it. Every time ShellCLI starts it
  removes the folder's inherited permissions and leaves only SYSTEM and Administrators, which everything inside inherits. ShellCLI does not check
  what is already in the folder, so never point this at a folder that holds anything else.
- `logDirectory` is where the daily log files are written. The logs record the commands that were run, so keep them somewhere administrators control.
- `downloadDirectory` is where downloads go when no folder is given: `get apps` and its installers, `download` when the folder is left blank, and
  anything that calls `getDownload` without a target. Treat it as scratch space: installers are downloaded into a temporary folder inside it and
  deleted again, and WinDirStat and BGInfo are unpacked into folders of their own.

Use full paths. `%rootDirectory%` stands for the root folder, so the shipped `config.json` puts the logs and downloads inside it and changing only the
root moves everything. Other environment variables such as `%ProgramData%` work too. In JSON, write backslashes doubled (`D:\\ShellCLI`) or use
forward slashes (`D:/ShellCLI`). These are refused, and ShellCLI stops: square brackets in a folder name, a drive that does not exist, a folder that
cannot be created or written to, and drive roots. The root is also refused if it is inside a Windows, Program Files or Users folder, or is one of
them or one of their parents, and network shares are refused for the root.

Installers from `get apps` are run from the download folder with administrator rights. Keep it inside the root folder, as the shipped config does, or
somewhere else only administrators can write to. Files from older versions stay where they were, in `ProgramData\shellcli`.

### Commands

The `commands` section lists every command, one per line:

    "add user": { "directory": "main", "file": "user", "function": "addUser", "description": "Add a new user." }

Typing `add user` downloads `main/user.ps1` from the repo, loads it and runs its `addUser` function. To add a command, put its function in a file in
the repo and add a line for it. A module file must define at least one function, and a command can only run a function (not a cmdlet or a
program). There are no built-in commands: `help`, `?`, `menu`, `commands` and `logs` are entries like any other, and `help` is what runs when
ShellCLI starts. Names are not case sensitive, must be unique, are at most 60 plain characters, and cannot be `keys`, `values`, `count` or `item`.
`directory` and `file` may only contain letters, digits, `-` and `_` (up to 64 characters), and `function` must be a plain function name.

Any entry that breaks these rules stops ShellCLI from starting, and so does invalid JSON (a trailing comment or comma), two names that differ only in
upper and lower case, or a command named `psobject`. Because one bad push stops every endpoint, run `.\test-config.ps1` before every push. It loads
`config.json` the way ShellCLI does, reports every problem ShellCLI would stop for, and checks that every command's function exists in its module file.

`dev.ps1` reads the local `config.json`, so changes to the folders, the repository or the commands can be tried before they are pushed.

When the framework, `init.ps1` and `config.json` change together, push `config.json` first, then `init.ps1`, then `framework.ps1`. Each file is
downloaded on its own, so for a few minutes after a push old and new versions meet. In that order they still work together. In any other order a
new `framework.ps1` can meet an old `init.ps1` (which calls a function the new one no longer has) or an old `config.json` (one without `repository`
and `branch`), and ShellCLI refuses to start.

## Bypass anti-virus

Some antivirus programs may block the use of ShellCLI. Typically when they do, it's the initial connection command triggers the warning or the block.
That's because of the irm (Invoke-RestMethod) portion of the command. The reason anti-virus software will sometimes block this command is because it
can be used to send and retrieve information over the internet. In this case you retrieve the root powershell functions of Shell CLI.

You should be able to bypass most anti-virus programs by pasting the ShellCLI initializer into an admin powershell or terminal directly. The link to
the initializer is below.

[Shell CLI Initializer](https://raw.githubusercontent.com/badsyntaxx/shellcli/main/init.ps1)
