# :zap: Iodine Kernel

Lean and simple performance oriented build of the Linux kernel.

Every change aims to maintain - or, possibly, optimize - the power usage-to-performance ratio.

[![license: WTFPL](https://img.shields.io/badge/license-WTFPL-brightgreen.svg)](http://www.wtfpl.net/about/)


### Features

- Kernel compression mode LZ4
- BMQ Process Scheduler
- BFQ I/O Scheduler
- Swap Pages LZ4/z3fold
- Westwood+ TCP Congestion Control + FQ_CODEL Queue Scheduler
- Disabled several hardening and debugging options
- Low swappiness value
- GCC optimization -O3, graysky2's patch
- LLVM/Clang build facility


### Releases

Compiled and packaged on **Debian Buster** using **GCC 10.2.0**


### Build

Optionally, before jumping to the actual build, you may wish to edit the `build.sh` to set your personal configs under `Configurations`.

To build a DEB package (you could omit --deb as it's the default option), use:
```sh
./build.sh --deb --build
```

for a RPM package, use:
```sh
./build.sh --rpm --build
```

Append `--generic` to build a generic kernel.

Complete usage `./build.sh -h`:
```
  -h, --help
  Print these options

  -g, --get-kernel
  Clone the Linux repository only

  -p, --apply-patches
  Apply patches only

  -c, --set-config
  Generate the kernel config with the selected options

  -b, --build
  Run over all the commands to build the kernel

  --llvm
  Use LLVM

  --deb, --rpm
  Package to either DEB or RPM

  --generic
  Optimize for generic x86_64 CPUs

  --sign-modules
  Signing facility
```

To sign the modules, proceed to update the option in the build.sh file to `IODINE_SIGNING="y"` and use `IODINE_SIGNING_KEY` to assign the signing key path.

### Requirements

Since the kernel is compressed using LZ4, be sure to have it installed!
```sh
$ sudo apt install lz4
```

For a faster, less safe, experience you could disable the security mitigations editing the GRUB default (/etc/default/grub), appending `mitigations=off` to the GRUB_CMDLINE_LINUX_DEFAULT option:
```sh
GRUB_CMDLINE_LINUX_DEFAULT="quiet mitigations=off"
```

