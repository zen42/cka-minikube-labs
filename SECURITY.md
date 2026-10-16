# Security Policy

## Supported versions

Only the `main` branch is supported. There are no versioned releases.

## Reporting a vulnerability

Please do not open a public issue for security problems. Use GitHub's
private reporting instead: open the **Security** tab of this repository and
choose **Report a vulnerability**.

Include what you found, how to reproduce it, and the impact you expect.
You can expect an acknowledgement within a few days; this is a hobby
project maintained on a best-effort basis.

## Scope

In scope: anything that could harm a learner who runs these scripts, for
example:

- `scripts/install-tools.sh` downloading or verifying binaries unsafely.
- Scripts that delete data outside the lab's own directories
  (`teardown-minikube.sh`, lab `teardown.sh`).
- The firewall/sudo handling in `setup-minikube.sh` and `common.sh`
  (these scripts only detect and instruct; they should never change the
  host firewall or run privileged containers).
- The optional TUI (`cka-tui.sh`, `scripts/tui.py`).

Out of scope: the deliberately broken workloads and the fake credentials
(for example `bob` / `pass`, `S3cr3t!`) that the labs create inside the
disposable `cka-labs` minikube cluster. They exist to be fixed or used as
lab data.
