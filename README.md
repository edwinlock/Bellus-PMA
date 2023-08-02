# Installation

To install the Bellus-PMA software in Windows, follow these steps.

1. Download and install Julia (version 1.9.2) from https://julialang.org/downloads/. When asked by the installer, select the option "add Julia to PATH".
2. Right-click on the `windows_installer.cmd` file and select 'Run as administrator'. The installer may take a while (approximately 10 minutes on my computer).
You can close the window once it says "Installer completed".
3. (Optional.) I recommend installing a modern terminal such as the (free) Microsoft Windows Terminal available at https://www.microsoft.com/store/productid/9N0DX20HK701.


# Using the software

The software can be run in a terminal or the command prompt. (To open the command prompt, press the Windows key + R, then type `cmd.exe` and press return.)

In the terminal or command prompt, run the software by typing `belluspma` and pressing return. To see all options for the software, use the option `belluspma --help`. Example buyer and supplier
CSV files are provided in the `examples` folder.

Examples:

`belluspma -b examples/buyers2.csv -s suppliers2.csv`

`belluspma -b examples/buyers_large1.csv -s suppliers_large.csv -m exhaustivesearch -o numbuyers`
