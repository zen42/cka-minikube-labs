# Lab 09 – DNS & CoreDNS

**Domain:** Services & Networking (20%) · **Builds on:** Lab 08

How service discovery actually works: CoreDNS, service FQDNs, pod DNS names,
`dnsPolicy`/`dnsConfig`, and Corefile customization.

## Objectives

- `nslookup` services and pods; the `svc.cluster.local` domain layout
- Pod `/etc/resolv.conf`, `dnsPolicy`, `dnsConfig`
- Edit the `coredns` ConfigMap: `log` plugin, `hosts` entries, stub domains

> Note: busybox `nslookup` has two quirks: it may exit non-zero even when
> the name resolves (search-domain NXDOMAINs count against it), and it
> treats any name containing a dot as fully-qualified — `nslookup
> api.dns-other` will NOT apply the search list, so it NXDOMAINs even
> though the name resolves fine. Confirm dotted short names with
> `wget -qO- http://api.dns-other/` instead (libc honors `search`).

## Environment

- **Namespaces:** `dns` (deployment+service `web`, pod `client`), `dns-other`
  (deployment+service `api`).
- **Output dir:** `~/cka-labs-out/09/`
- **Start here:** `make lab-09`
- setup.sh first backs up the `coredns` ConfigMap to `.state/` — teardown
  restores it and restarts CoreDNS.

## Tasks

1. From pod `client` (ns `dns`), run `nslookup web` and save the output to
   `~/cka-labs-out/09/nslookup-web.txt`.
2. Write the FQDN of service `api` in namespace `dns-other` to
   `~/cka-labs-out/09/api-fqdn.txt`. From `client`, confirm both
   `api.dns-other` and the full FQDN resolve (for the short form use
   `wget -qO- http://api.dns-other/` — busybox `nslookup` skips the search
   list for dotted names, see the note above).
3. Save `client`'s `/etc/resolv.conf` to `~/cka-labs-out/09/resolv.conf`.
4. Write `client`'s pod DNS name (`<ip-with-dashes>.dns.pod.cluster.local`)
   to `~/cka-labs-out/09/client-pod-dns.txt` and verify it resolves from
   `client`.
5. Create pod `custom-dns` (busybox:1.36, `sleep 3600`) with
   `dnsPolicy: None` and a `dnsConfig` specifying: nameservers = the
   kube-dns ClusterIP; searches = `dns.svc.cluster.local`,
   `svc.cluster.local`, `cluster.local`; option `ndots` = `2`.
6. Edit the `coredns` ConfigMap in `kube-system` to (a) enable the `log`
   plugin and (b) add a `hosts` block mapping `10.1.2.3` →
   `legacy.internal` with `fallthrough`. Then
   `kubectl -n kube-system rollout restart deployment coredns`. From
   `client`, `nslookup legacy.internal` should answer `10.1.2.3`.
7. Add a stub domain: append a server block forwarding `example.internal`
   to `10.9.9.9`:
   `example.internal:53 { forward . 10.9.9.9 }`. Restart CoreDNS again.
8. Write the ClusterIP of service `kube-dns` (ns `kube-system`) to
   `~/cka-labs-out/09/kube-dns-ip.txt`.
9. From `client`, look up `legacy.internal` once more, then save the last
   50 lines of the CoreDNS pod logs to `~/cka-labs-out/09/coredns.log`.

## Verify

```bash
make verify-09
```

## Clean up

```bash
make teardown-09
```

Restores the original `coredns` ConfigMap, restarts CoreDNS, deletes both
namespaces and the output dir.

## Docs

- https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/
- https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/
- https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/
