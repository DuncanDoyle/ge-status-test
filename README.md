# Gloo-Edge Status Test

## Installation

Add Gloo EE Helm repo:
```
helm repo add glooe https://storage.googleapis.com/gloo-ee-helm
```

Export your Gloo Edge License Key to an environment variable:
```
export GLOO_EDGE_LICENSE_KEY={your license key}
```

Install Gloo Edge:
```
cd install
./install-gloo-edge-enterprise-with-helm.sh
```

> NOTE
> The Gloo Edge version that will be installed is set in a variable at the top of the `install/install-gloo-edge-enterprise-with-helm.sh` installation script.

## Setup the environment

Run the `install/setup.sh` script to setup the environment:

- Deploy the 2 HTTPBin services
- Deploy the GRPCBin service
- Deploy the Upstreams
- Deploy the RouteTables
- Deploy the VirtualServices

```
./setup.sh
```

## Run the test

Check the status of the Routetables and VirtualServices. All the statusses should be "Accepted" and no errors should be reported.

```
kubectl -n gloo-system get rt httpbin2-routes -o yaml
kubectl -n gloo-system get rt bookstore-routes -o yaml
kubectl -n gloo-system get vs api-example-com-vs -o yaml
kubectl -n gloo-system get vs grpc-example-com-vs -o yaml
```

All services are accessible. We can test the HTTPBin2 service:

```
curl -v http://api.example.com/httpbin2/get
```


### Deleting the Upstream

Next delete the HTTPBin2 Upstream:

```
kubectl -n gloo-system delete upstream httpbin2-8000
```

Notice that the `api-example-com-vs` virtual service will now print a warning: _"Route Warning: InvalidDestinationWarning. Reason:*v1.Upstream { gloo-system.httpbin2-8000 } not found"

```
kubectl -n gloo-system get vs api-example-com-vs -o yaml
```

But not only that routetable prints that error, also the unrelated `grpc-example-com-vs` prints this error:

```
kubectl -n gloo-system get vs grpc-example-com-vs -o yaml
```

As well as both routetables and gateway-proxy:

```
kubectl -n gloo-system get rt httpbin2-routes -o yaml
kubectl -n gloo-system get rt bookstore-routes -o yaml
kubectl -n gloo-system get gateway gateway-proxy -o yaml
```

The HTTPBin2 service is no longer accessible (as expected):

```
curl -v http://api.example.com/httpbin2/get
```

> [!NOTE]
> Sometime only the `api-example-com-vs` Virtual Service will print the initial "warning". But when you then apply an unrelated change to any of the other resources, e.g. adding a label to an unrelated routetable, the "warning" will be printed on all aforementioned resources. E.g.
>
> ```
> kubectl apply -f - <<EOF
> apiVersion: gateway.solo.io/v1
> kind: RouteTable
> metadata:
>   name: bookstore-routes
>   namespace: gloo-system
>   labels:
>     completely: unrelated-label
> spec:
>   routes:
>   - matchers:
>     - prefix: /
>     routeAction:
>       single:
>         upstream:
>           name: grpc-bookstore-8080
>           namespace: gloo-system
> EOF
> ```

### Fixing the Upstream

You would expect the system to get back to a valid state after re-applying the `httpbin2-8000`:

```
kubectl apply -f upstreams/httpbin2-upstream.yaml
```

However, that does not happen. All routetables and virtual services keep printing the warning:

```
kubectl -n gloo-system get rt httpbin2-routes -o yaml
kubectl -n gloo-system get rt bookstore-routes -o yaml
kubectl -n gloo-system get vs api-example-com-vs -o yaml
kubectl -n gloo-system get vs grpc-example-com-vs -o yaml
kubectl -n gloo-system get gateway gateway-proxy -o yaml
```

Note however that htrpbin2 service is accessible again!!!!

```
curl -v http://api.example.com/httpbin2/get
```

When we now apply a small (unrelated) change to any of these resources, the status of the system gets back to "Accepted" and the HTTPBin2 service is accessibl again. Simply apply a new label the `bookstore-routetable.yaml` for example and reapply the resouce:

```
kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteTable
metadata:
  name: bookstore-routes
  namespace: gloo-system
  labels:
    another-completely: unrelated-label
spec:
  routes:
    - matchers:
      - prefix: /
      routeAction:
        single:
          upstream:
            name: grpc-bookstore-8080
            namespace: gloo-system
      
EOF
```

## Conclusion
It seems that fixing a missing `Upstream` does not trigger a status update on (some) of the resources. Although the service becomes accessible again, the fact that the system is back in a correct state is not reflected in statuses of the various GE resources (e.g. VirtualServices, RouteTables, etc.).
