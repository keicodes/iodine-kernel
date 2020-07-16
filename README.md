# :zap: Iodine Kernel

Lean and simple performance oriented build of the Linux kernel.

[![license: WTFPL](https://img.shields.io/badge/license-WTFPL-brightgreen.svg)](http://www.wtfpl.net/about/)


### Features

- Kernel compression mode LZ4
- BMQ Process Scheduler
- BFQ I/O Scheduler
- Swap Pages LZ4/z3fold
- Westwood+ TCP Congestion Control + FQ_CODEL Queue Scheduler
- Disabled several hardening and debugging options
- Low swappiness value
- GCC optimization -O3 -march=native, graysky2's patch


### Releases

Compiled and packaged on **Debian Buster** using **GCC 10.1.0**


### Build

Before jumping to the actual build command, you may wish to edit the `build.sh` file and add your correct GCC bin path to the compiler variable, which might commonly be:
`IODINE_COMPILER="gcc"`

If you wish to edit the make flags, use `IODINE_MAKE_FLAGS`.

To build a DEB package, use:
```sh
./build.sh --deb --build
```

for a RPM package, use:
```sh
./build.sh --rpm --build
```

Complete usage `./build -h`:
```sh
  -h, --help
  Prints these options

  -g, --get-kernel
  Clones the Linux repository only

  -p, --apply-patches
  Apply patches only

  -b, --build
  Runs over all the commands to build the kernel
```

To sign the modules, proceed to update the option in the build.sh file to `IODINE_SIGNING="y"` and use `IODINE_SIGNING_KEY` to assign the signing key path.

### Requirements

Since the kernel is compressed using LZ4, be sure to have it installed!
```sh
$ sudo apt install lz4
```

For a faster, less safe, experience you could disable the security mitigations editing the GRUB default (/etc/default/grub), appending `migrations=off` to the GRUB_CMDLINE_LINUX_DEFAULT option:
```sh
GRUB_CMDLINE_LINUX_DEFAULT="quiet mitigations=off"
```

