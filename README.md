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

ShellCLI reads `config.json` from the root of the repo each time it starts. It sets the repository ShellCLI downloads from, the folders it uses, the
list of commands and which of them runs at startup. The file is required, and ShellCLI has no built-in defaults and no built-in commands. If it cannot be downloaded, is not valid
JSON, lacks a setting or has a wrong one, ShellCLI stops with an error that lists every problem it found. When ShellCLI opens its own administrator
window (the UAC prompt), that window waits for Enter after an error, so the message can be read.

Every setting below must be present. There is nothing to leave out.

### Repository

- `repository` is the link to the GitHub repository, for example `https://github.com/badsyntaxx/shellcli`. Command modules are downloaded from it. Any
  other https address works too, as long as the files are served at `<address>/main/user.ps1` and so on. Plain http is refused.
- `branch` is the branch, tag or commit to download modules from. It is required for a GitHub link, and not allowed for any other address (put the
  branch in that address instead).

One address cannot come from `config.json`: the one `config.json` itself is downloaded from. It is the line `$global:shellcliBootstrapBase` at the top
of `init.ps1`, for example `https://raw.githubusercontent.com/owner/repo/main` (no trailing slash). ShellCLI downloads `init.ps1`, `framework.ps1`,
`main/core.ps1` and `config.json` from there, and the command modules only from the `repository` in `config.json`. A tag in `branch` therefore pins
the modules but not the framework; to pin everything, put the same tag in the bootstrap line.

`repository` and the bootstrap line must name the same repository (the branch may differ). If they do not, ShellCLI refuses to start, before it writes
anything to disk, so a fork that changes only one of the two cannot run another repository's modules as administrator. `.\test-config.ps1` makes the
same comparison, so you hear about it before you push. The bootstrap address must be https too, because everything downloaded from it runs as
administrator; ShellCLI refuses to start otherwise.

To fork ShellCLI, change these:

1. `$global:shellcliBootstrapBase` in `init.ps1`.
2. `repository` and `branch` in `config.json`. The `config.json` that ships here points at the original repository.
3. The command at the top of this README, and the initializer link at the bottom.
4. The documentation link in `writeHelp` in `main/core.ps1`, and the one in `plugins/core.ps1`.

Keep the folder layout (`main`, `plugins`, `framework.ps1`, `init.ps1`, `config.json`).

### Folders

- `rootDirectory` is ShellCLI's own folder, and nobody else's. Every time ShellCLI starts it removes the folder's inherited permissions and leaves
  only SYSTEM and Administrators, which everything inside inherits. ShellCLI does not check what is already in the folder, so never point this at a
  folder that holds anything else.
- `logDirectory` is where the daily log files are written. The logs record the commands that were run, so keep them somewhere administrators control.
- `cacheDirectory` is where downloaded command modules are kept, for when a later download fails. A cached module is run as administrator.
- `tempDirectory` is where downloads go when no folder is given: `get apps` and its installers, `download` when the folder is left blank, and anything
  that calls `getDownload` without a target. Treat it as scratch space: installers are downloaded into a temporary folder inside it and deleted again,
  and WinDirStat and BGInfo are unpacked into folders of their own.

**Adding a folder.** Any setting named like `logDirectory` (starts with a lower case letter, ends in `Directory`) is a folder. Add as many as you like,
for example `"backupDirectory": "%rootDirectory%\\Backups"`. ShellCLI checks the path, creates the folder at startup and makes it available to code
as `getConfigPath -name backup` (the setting name without `Directory`). No other file needs to change. The four above are the ones ShellCLI itself
uses, so they must be present. `.\test-config.ps1` also checks that every `getConfigPath -name ...` in the code has a setting in `config.json`, so a
folder that is renamed or removed while something still asks for it is caught before you push. Asking for a folder that is not in the config is an
error that says which setting to add.

However they refer to each other, ShellCLI creates the root first and locks it down, and only then creates the others, in the order they are listed.
(A folder the root is built on, such as `C:\Nuvia` above, is created along with the root as its parent, before the lock-down.) A folder inside the root
therefore inherits the locked-down permissions from the moment it exists, which a folder created earlier would not. The cache and temp folders hold
code that runs as administrator, so keep them inside the root, as the shipped config does. A folder anywhere else is created exactly as written and
ShellCLI does nothing to protect it. Folders are only created: ShellCLI does not test that they can be written to, so a folder you cannot write to
fails the first time it is used.

Use full paths. A folder can refer to any other folder by name between percent signs: `%rootDirectory%`, `%logDirectory%`, `%nuviaDirectory%`. They
may be listed in any order, the root included, so the root can itself be built from another folder (`"rootDirectory": "%baseDirectory%\\Tools\\ShellCLI"`).
ShellCLI works each one out after the folders it refers to. A folder that refers to itself, or folders that refer to each other in a circle, are
errors. The shipped `config.json` puts everything inside the root, so changing only the root moves everything. Other environment variables such as
`%ProgramData%` work too. In JSON, write backslashes doubled (`D:\\ShellCLI`) or use forward
slashes (`D:/ShellCLI`). These are refused, and ShellCLI stops: square brackets in a folder name, a drive that does not exist, a folder that cannot be
created, and drive roots. The root is also refused if it is inside a Windows, Program Files or Users folder, or is one of them or one of their
parents, and network shares are refused for the root.

Installers from `get apps` are run from the temp folder with administrator rights. Files from older versions stay where they were, in
`ProgramData\shellcli`; the shipped config keeps the cache in `Cache`, the logs in `Logs` and downloads in `Temp` inside the root, so older files in
the top of that folder are no longer used.

### Commands

The `commands` section lists every command, one per line:

    "add user": { "directory": "main", "file": "user", "function": "addUser", "description": "Add a new user." }

Typing `add user` downloads `main/user.ps1` from the repo, loads it and runs its `addUser` function. To add a command, put its function in a file in
the repo and add a line for it. A module file must define at least one function, and a command can only run a function (not a cmdlet or a program).
There are no built-in commands: `help`, `?`, `menu`, `commands` and `logs` are entries like any other. Names are not case sensitive, must be unique, are at most 60 plain characters, and cannot be `keys`, `values`, `count` or `item`. `directory` and
`file` may only contain letters, digits, `-` and `_` (up to 64 characters), and `function` must be a plain function name.

`starterCommand` is the command ShellCLI runs when it starts, before the first prompt, for example `"starterCommand": "help"`. It is required and must
name one of the commands in the `commands` section (in any case), otherwise ShellCLI refuses to start. Set it to `menu`, or to any other command, to
start somewhere else.

Any entry that breaks these rules stops ShellCLI from starting, and so does invalid JSON (a trailing comment or comma), two names that differ only in
upper and lower case, or a command named `psobject`. Because one bad push stops every endpoint, run `.\test-config.ps1` before every push. It loads
`config.json` the way ShellCLI does, reports every problem ShellCLI would stop for, and checks that every command's function exists in its module
file.

`dev.ps1` reads the local `config.json`, so changes to the folders, the repository or the commands can be tried before they are pushed.

When the framework, `init.ps1` and `config.json` change together, push `config.json` first, then `init.ps1`, then `framework.ps1`. Each file is
downloaded on its own, so for a few minutes after a push old and new versions meet. In that order they still work together. In any other order a new
`framework.ps1` can meet an old `init.ps1` (which calls a function the new one no longer has) or an old `config.json` (one without `repository` and
`branch`), and ShellCLI refuses to start.

## Bypass anti-virus

Some antivirus programs may block the use of ShellCLI. Typically when they do, it's the initial connection command triggers the warning or the block.
That's because of the irm (Invoke-RestMethod) portion of the command. The reason anti-virus software will sometimes block this command is because it
can be used to send and retrieve information over the internet. In this case you retrieve the root powershell functions of Shell CLI.

You should be able to bypass most anti-virus programs by pasting the ShellCLI initializer into an admin powershell or terminal directly. The link to
the initializer is below.

[Shell CLI Initializer](https://raw.githubusercontent.com/badsyntaxx/shellcli/main/init.ps1)
