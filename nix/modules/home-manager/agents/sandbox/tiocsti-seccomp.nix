# Compiled seccomp filter blocking just TIOCSTI -- lets bwrap drop --new-session (which broke SIGWINCH/resize) while still blocking terminal-injection (CVE-2017-5226)
{pkgs}:
pkgs.runCommand "tiocsti-seccomp.bpf" {
  nativeBuildInputs = [pkgs.gcc pkgs.libseccomp];
} ''
  cat >gen.c <<'EOF'
  #include <errno.h>
  #include <seccomp.h>
  #include <stdio.h>
  #include <sys/ioctl.h>

  int main(int argc, char **argv) {
    if (argc != 2) {
      fprintf(stderr, "usage: %s outfile\n", argv[0]);
      return 1;
    }

    scmp_filter_ctx ctx = seccomp_init(SCMP_ACT_ALLOW);
    if (!ctx) {
      fprintf(stderr, "seccomp_init failed\n");
      return 1;
    }

    int rc = seccomp_rule_add(ctx, SCMP_ACT_ERRNO(EPERM), SCMP_SYS(ioctl), 1,
                               SCMP_A1(SCMP_CMP_EQ, (scmp_datum_t) TIOCSTI));
    if (rc < 0) {
      fprintf(stderr, "seccomp_rule_add failed: %d\n", rc);
      return 1;
    }

    FILE *f = fopen(argv[1], "wb");
    if (!f) {
      perror("fopen");
      return 1;
    }
    rc = seccomp_export_bpf(ctx, fileno(f));
    fclose(f);
    seccomp_release(ctx);
    if (rc < 0) {
      fprintf(stderr, "seccomp_export_bpf failed: %d\n", rc);
      return 1;
    }
    return 0;
  }
  EOF
  gcc gen.c -o gen -lseccomp
  ./gen "$out"
''
