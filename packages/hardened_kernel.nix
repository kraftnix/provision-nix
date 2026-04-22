{
  version,
  hash,
  branch,
  kernelConfigOverrides ? { },
}:
{
  fetchFromGitHub,
  buildLinux,
  lib,
  ...
}@args:
buildLinux (
  args
  // rec {
    inherit version hash;
    extraMeta.branch = branch;

    modDirVersion = version;
    src = fetchFromGitHub {
      inherit hash;
      owner = "anthraxx";
      repo = "linux-hardened";
      tag = "v${version}";
    };
    kernelPatches = [ ];

    structuredExtraConfig =
      with lib.kernel;
      {
        # Perform additional validation of commonly targeted structures.
        DEBUG_NOTIFIERS = yes;
        DEBUG_PLIST = yes;
        DEBUG_SG = yes;
        DEBUG_VIRTUAL = yes;
        SCHED_STACK_END_CHECK = yes;

        # tell EFI to wipe memory during reset
        # https://lwn.net/Articles/730006/
        RESET_ATTACK_MITIGATION = yes;

        # restricts loading of line disciplines via TIOCSETD ioctl to CAP_SYS_MODULE
        CONFIG_LDISC_AUTOLOAD = option no;

        # Enable init_on_free by default
        INIT_ON_FREE_DEFAULT_ON = yes;

        # Initialize all stack variables on function entry
        INIT_STACK_ALL_ZERO = yes;

        # Wipe all caller-used registers on exit from a function
        ZERO_CALL_USED_REGS = yes;

        # Enable the SafeSetId LSM
        SECURITY_SAFESETID = yes;

        # Reboot devices immediately if kernel experiences an Oops.
        PANIC_TIMEOUT = freeform "-1";

        # Enable gcc plugin options
        GCC_PLUGINS = yes;

        # A port of the PaX stackleak plugin
        GCC_PLUGIN_STACKLEAK = yes;

        # Runtime undefined behaviour checks
        # https://www.kernel.org/doc/html/latest/dev-tools/ubsan.html
        # https://developers.redhat.com/blog/2014/10/16/gcc-undefined-behavior-sanitizer-ubsan
        UBSAN = yes;
        UBSAN_TRAP = yes;
        UBSAN_BOUNDS = yes;
        UBSAN_LOCAL_BOUNDS = option yes; # clang only
        CFI_CLANG = option yes; # clang only Control Flow Integrity since 6.1

        # Disable various dangerous settings
        PROC_KCORE = no; # Exposes kernel text image layout
        INET_DIAG = no; # Has been used for heap based attacks in the past

        # INET_DIAG=n causes the following options to not exist anymore, but since they are defined in common-config.nix,
        # make them optional
        INET_DIAG_DESTROY = option no;
        INET_RAW_DIAG = option no;
        INET_TCP_DIAG = option no;
        INET_UDP_DIAG = option no;
        INET_MPTCP_DIAG = option no;

        # CONFIG_DEVMEM=n causes these to not exist anymore.
        STRICT_DEVMEM = option no;
        IO_STRICT_DEVMEM = option no;

        # stricter IOMMU TLB invalidation
        IOMMU_DEFAULT_DMA_STRICT = option yes;
        IOMMU_DEFAULT_DMA_LAZY = option no;

        # not needed for less than a decade old glibc versions
        LEGACY_VSYSCALL_NONE = yes;
      }
      // kernelConfigOverrides;
  }
  // (args.argsOverride or { })
)
