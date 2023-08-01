# Installation

To install the Bellus-PMA software in Windows, follow these steps.

1. Download and install Julia (version 1.9.2) from https://julialang.org/downloads/. When asked by the installer, select the option "add Julia to PATH".
2. Unpack the provided ZIP file `Bellus-PMA.zip`.
3. Double-click on the `windows_installer.cmd` file. The installer may take a while (approximately 15 minutes on my computer). You can close the window
once it says "Installer completed".

# Running the software

The software can be run in a terminal or the command prompt.

To open the command prompt, press the Windows key + R, then type `cmd.exe` and press return. Instead of the command prompt, I recommend installing a modern
terminal such as the (free) Microsoft Windows Terminal available at https://www.microsoft.com/store/productid/9N0DX20HK701.

The software is run by typing `bpma` and pressing return. To see all options for the software, use the option `bpma --help`. Example buyer and supplier
CSV files are provided in the `examples` folder.

Examples:

`bpma -b examples/buyers1.csv -s suppliers1.csv`

`bpma -b examples/buyers2.csv -s supplier2.csv -m exhaustivesearch -o numbuyers`
