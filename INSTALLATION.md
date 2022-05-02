# Installing FPGA Tools

## WORK IN PROGRESS...

For most operating systems, nightly binary builds of the tools can be downloaded
from
[YosysHQ oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build/releases)

### Windows 10 and 11

See [How to install WSL2](https://docs.microsoft.com/en-us/windows/wsl/install)

After installing WSL2 and oss-cad-suite, the same as Linux except you also want
a Windows executable build of `iceprog` (to allow talking to USB devices).
See
[Gojimmypi's Blog](https://gojimmypi.blogspot.com/2020/12/ice40-fpga-programming-with-wsl-and.html)

You can get Windows `iceprog` and related executables from
[fpga-toolchain-progtools](https://github.com/YosysHQ/fpga-toolchain/releases/download/nightly-20210318/fpga-toolchain-progtools-windows_amd64-nightly-20210318.zip) (This are older but nice static binaries)

### Linux

Other than [YosysHQ oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build/releases)
typically you only need `sudo apt install build-essential`

### macOS

You need `make`, you can use [Homebrew](https://brew.sh/) or
[Apple command line tools](https://www.embarcadero.com/starthere/xe5/mobdevsetup/ios/en/installing_the_commandline_tools.html)

