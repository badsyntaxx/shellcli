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

ShellCLI reads `config.json` from the root of the repo each time it starts. It sets the folders ShellCLI uses and the list of commands. If the
file cannot be downloaded, or a setting in it is wrong, ShellCLI starts anyway with the default for that setting and says so on the first screen. If
the whole file is unusable, only the built-in commands (`help`, `?`, `menu`, `commands`, `logs`) are available.

### Folders

- `rootDirectory` is ShellCLI's own folder. The module cache is kept in a `cache` folder inside it. ShellCLI restricts this folder to SYSTEM and
  Administrators, so use a folder that only ShellCLI uses. A folder that already exists and holds other files is left alone and ShellCLI warns.
- `logDirectory` is where the daily log files are written. The logs record the commands that were run, so keep them somewhere administrators control.
- `downloadDirectory` is where downloads go when no folder is given: `get apps` and its installers, `download` when the folder is left blank, and
  anything that calls `getDownload` without a target. Treat it as scratch space: installers are downloaded into a temporary folder inside it and
  deleted again, and WinDirStat and BGInfo are unpacked into folders of their own.

Use full paths. `%rootDirectory%` stands for the root folder, so by default the logs and downloads live inside it and changing only the root moves
everything. Other environment variables such as `%ProgramData%` work too. In JSON, write backslashes doubled (`D:\\ShellCLI`) or use forward slashes
(`D:/ShellCLI`). Square brackets in a folder name, a missing drive, a folder that cannot be written to, and drive roots are refused. The root is
also refused if it is inside a Windows, Program Files or Users folder, or is one of them or one of their parents. Network shares are refused for the
root. A setting that is refused falls back to its default.

Installers from `get apps` are run from the download folder with administrator rights. Keep it inside the root folder, as the default is, or
somewhere else only administrators can write to. Files from older versions stay where they were, in `ProgramData\shellcli`.

### Commands

The `commands` section lists every command, one per line:

    "add user": { "directory": "main", "file": "user", "function": "addUser", "description": "Add a new user." }

Typing `add user` downloads `main/user.ps1` from the repo, loads it and runs its `addUser` function. To add a command, put its function in a file in
the repo and add a line for it. A command with the same name as a built-in one replaces it. Names are not case sensitive. `directory` and `file` may
only contain letters, digits, `-` and `_`, and `function` must be a plain function name. An entry that breaks these rules is skipped with a warning
and the rest still load.

`dev.ps1` reads the local `config.json`, so changes to the folders or the commands can be tried before they are pushed.

## Bypass anti-virus

Some antivirus programs may block the use of ShellCLI. Typically when they do, it's the initial connection command triggers the warning or the block.
That's because of the irm (Invoke-RestMethod) portion of the command. The reason anti-virus software will sometimes block this command is because it
can be used to send and retrieve information over the internet. In this case you retrieve the root powershell functions of Shell CLI.

You should be able to bypass most anti-virus programs by pasting the ShellCLI initializer into an admin powershell or terminal directly. The link to
the initializer is below.

[Shell CLI Initializer](https://raw.githubusercontent.com/badsyntaxx/shellcli/main/init.ps1)
