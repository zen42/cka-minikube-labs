# Lab 06 – Services & Endpoints

**Domain:** Services & Networking (20%) · **Builds on:** Lab 05

Expose pods with every Service type, fix a broken selector, and hand-build
an EndpointSlice — the layer between Services and Pods.

## Objectives

- `kubectl expose` / Service manifests: ClusterIP, NodePort, LoadBalancer,
  headless, ExternalName
- Endpoints/EndpointSlice debugging, selector typos
- Multi-port Services, `sessionAffinity`

## Environment

- **Namespace:** `services`
- **Seeded for you:** deployment `legacy-api` (2 replicas, serves the token
  `legacy-api` on port 80) and Service `legacy-svc` — whose selector has a
  typo, so it has **no endpoints**.
- **Output dir:** `~/cka-labs-out/06/`
- **Start here:** `make lab-06`
- All pods here serve HTTP with busybox `httpd`. Test connectivity **from
  inside the cluster** (`kubectl run --rm -i --image=busybox:1.36 -- wget`);
  host-side `curl http://$(minikube -p cka-labs ip):<nodePort>` is optional
  and depends on host networking.

## Tasks

1. Create deployment `web` (3 replicas): busybox:1.36 serving the token
   `web` on port 80 —
   `kubectl create deployment web --image=busybox:1.36 --replicas=3 -n services -- sh -c 'mkdir -p /www && echo web > /www/index.html && httpd -f -p 80 -h /www'`.
   Label the pods `app=web` (via template labels), then expose the
   deployment as ClusterIP Service `web-svc` on port 80.
2. Create NodePort Service `web-nodeport` for `web` with nodePort `30080`.
3. Create LoadBalancer Service `web-lb` on port 80. Note that `EXTERNAL-IP`
   stays `<pending>` — that is expected without `minikube tunnel`.
4. Service `legacy-svc` has no endpoints. Find why (`get endpoints`,
   `describe`) and fix it — the pods ARE running.
5. Create headless Service `web-headless` (`clusterIP: None`, selector
   `app=web`). Confirm `nslookup web-headless.services.svc.cluster.local`
   returns the pod IPs.
6. Create ExternalName Service `external-db` pointing to `db.example.com`,
   port 5432.
7. Create Service `manual-svc` with **no selector** (port 8080 →
   targetPort 80), then hand-write EndpointSlice `manual-svc-1`
   (label `kubernetes.io/service-name: manual-svc`, addressType `IPv4`)
   pointing at the IP of one `web` pod, port 80.
8. Save the EndpointSlice(s) of `web-svc`:
   `kubectl get endpointslices -n services -l kubernetes.io/service-name=web-svc -o wide > ~/cka-labs-out/06/web-endpoints.txt`
9. Make `web-svc` multi-port: `http` 80→80 and `alt` 8080→80.
10. Set `sessionAffinity: ClientIP` on `web-svc`.

## Verify

```bash
make verify-06
```

## Clean up

```bash
make teardown-06
```

## Docs

- https://kubernetes.io/docs/concepts/services-networking/service/
- https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
- https://kubernetes.io/docs/tutorials/services/source-ip/
