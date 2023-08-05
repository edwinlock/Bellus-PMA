# The Bellus-PMA: a Product-Mix Auction variant designed for Bellus Ventures.

In case of issues, get in touch with [Edwin](edwinlock@gmail.com).

## Installation
### Windows instructions

1. Download and install Julia (version 1.9.2) from https://julialang.org/downloads/. When asked by the installer, select the option "add Julia to PATH".
2. Right-click on the `windows_installer.cmd` file and select 'Run as administrator'. The installer may take a while (approximately 10 minutes on my computer).
You can close the window once it says "Installer completed".
3. (Recommended.) Install the (free) Microsoft Windows Terminal available at https://www.microsoft.com/store/productid/9N0DX20HK701.

### Linux / macOS instructions

These instructions assume some familiarity with common development tools such as `git` and the terminal.
1. Clone the github repository.
2. Install Julia 1.9 from your preferred repository or from https://julialang.org/. Following the installation instructions, ensure that Julia has been added to the path.
3. Run `julia --threads auto install.jl` in the terminal. This should take 5-15 minutes and create a compiled `sys_bellus.so` sysimage file for faster loading.
4. Create an alias `alias belluspma="julia --threads auto --sysimage=path/to/sys_bellus.so path/to/run.jl"`, replacing the dummy path with the correct path. Optionally,
add this alias permanently to your shell configuration.

## Using the software

The software can be run in a terminal or the command prompt (in Windows). (To open the command prompt in Windows, press the Windows key + R, then type `cmd.exe` and press
return.)

To use the software, open the command prompt or terminal, and ensure you are in the folder containing your buyer and supplier CSV files. In Windows with the Terminal installed,
one way of doing this is to right-click on the folder in question in File Explorer and select "Open in Terminal".
Then run the software by typing `belluspma` together with the appropriate options, and pressing return. The buyer and supplier CSV files are provided using the `-b` and `-s` options,
as shown in the examples below. To see all options for the software, use the option `belluspma --help`. Example buyer and supplier CSV files are provided in the `examples` folder.

### Examples

Right-click on the `examples/` folder and select "Open in Terminal". Then run

`belluspma -b buyers_medium2.csv -s suppliers_medium.csv`

or 

`belluspma -b buyers_large1.csv -s suppliers_large.csv -m exhaustive -o numsuppliers`

