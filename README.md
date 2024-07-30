### A powershell scripts library

# Chaste Scripts

This is my PowerShell script library for various Windows tasks. No need to download anything; just enter a command and gain access. Chaste Scripts is particularly useful for IT professionals who need to perform tasks on the backend without disrupting the user. It can handle tasks such as modifying user data (including groups and passwords), making changes to the network adapter, and more.

## Before we begin

NOTE
There are some anti-virus softwares that block Chaste Scripts. Some do and some don't. If you encounter an av software that does there are some steps you can take.

You may also need to enable running powershell scripts on your system.

## Getting started

Open powershell as an administrator, paste in the command below and hit Enter. Thats it!

Getting started\
`irm chastescripts.com | iex`

The above command is shorthand Powershell. It is the same as\
`Invoke-RestMethod chastescripts.com | Invoke-Expression`

## Using the menu

If you don't know any commands, you can just enter the `menu` command. Once in the menu, you can use the _up_ and _down_ arrow keys to make selections and then the enter key to confirm your selection.\
![Chaste scripts menu](https://guided.chaste.pro/images/chaste-scripts/chaste-scripts.png)

## Using commands

You don't need to rely on the menu. You can accomplish more, faster, by accessing commands directly. For instance, creating a new user or editing the target PC's network adapter can be done with short intuitive commands.

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

View WiFi ssid and passwords for the currently enabled NIC's.\
`get wifi creds`

## Enable running powershell

Its fairly common that running powershell scripts is disabled by default. You can enable running powershell scripts by opening powershell as an administrator and entering this command.

Set the execution policy to unrestricted.
`Set-ExecutionPolicy Unrestricted`

## Bypass anti-virus

Some anti-virus programs will block the use of Chaste Scripts. Most of the time the inital connection command is what triggers the anti-virus. Thats because of the irm (Invoke-RestMethod) portion of the command. The reason anti-virus softwares will sometimes block this command is because it can be used to send and retrieve information over the internet. In this case you retrieve the root powershell functions of Chaste Scripts.

To bypass this problem you can download and run or paste in the root functions of Chaste Scripts.

Chaste Scripts Root
`foo`
