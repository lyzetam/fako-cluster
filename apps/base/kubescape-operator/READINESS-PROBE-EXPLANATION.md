# Why Readiness Probes Are Needed for Kubevuln

## What Are Readiness Probes?

Readiness probes are health checks in Kubernetes that determine when a pod is ready to accept traffic. They serve a different purpose than liveness probes:

- **Liveness Probe**: Determines if a pod is healthy and should be restarted if unhealthy
- **Readiness Probe**: Determines if a pod is ready to serve requests

## Why Kubevuln Needs a Readiness Probe

### 1. **Startup Dependencies**
Kubevuln requires the grype vulnerability database to be downloaded and initialized before it can process requests. This process typically takes 1-2 minutes on startup.

### 2. **Service Discovery & Load Balancing**
- Without a readiness probe, Kubernetes would add the pod to the service endpoints immediately after the container starts
- Other components (like the kubescape operator) would try to send vulnerability scan requests to kubevuln before it's ready
- This would result in failed requests and errors in the scanning pipeline

### 3. **Graceful Rolling Updates**
During deployments:
- New pods won't receive traffic until they pass readiness checks
- Old pods continue serving traffic until new ones are ready
- Ensures zero-downtime deployments

### 4. **Prevents Cascading Failures**
- If kubevuln isn't ready but receives requests, it returns errors
- These errors can cause retries and additional load
- Other components may fail or enter error states
- The readiness probe prevents this by keeping unready pods out of service

## What Happens Without Proper Readiness Probes?

In the case we fixed:
1. Pod starts and is immediately added to service endpoints
2. Kubescape operator sends vulnerability scan requests
3. Kubevuln is still downloading its database and can't respond
4. Requests timeout after 1 second (too short)
5. Scanning fails and components report errors

## The Solution

By configuring the readiness probe with:
- **60s initial delay**: Gives time for database download
- **10s timeout**: Allows for slower responses during initialization
- **Proper health endpoint**: `/v1/readiness` that accurately reports service status

We ensure that kubevuln only receives traffic when it's truly ready to process vulnerability scans.

## Architecture Context

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  Kubescape      │────▶│  K8s Service    │────▶│  Kubevuln Pod   │
│  Operator       │     │  (Endpoints)    │     │                 │
│                 │     │                 │     │  ✓ Ready        │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                              │
                              │ Readiness probe
                              │ controls inclusion
                              ▼
                        ┌─────────────────┐
                        │                 │
                        │  Kubevuln Pod   │
                        │                 │
                        │  ✗ Not Ready    │
                        │  (Downloading)  │
                        └─────────────────┘
```

Without readiness probes, both pods would be in the service endpoints, causing failures when traffic is routed to the unready pod.
