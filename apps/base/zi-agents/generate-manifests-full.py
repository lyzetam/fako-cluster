#!/usr/bin/env python3
"""Generate K8s deployment and service manifests for ALL zI agents (Engineering + Digital Workforce)."""

import yaml
from pathlib import Path

# Load agents from zi registry.yaml
ZI_AGENTS_DIR = Path.home() / "dev/zi/agents"
registry_path = ZI_AGENTS_DIR / "registry.yaml"

if not registry_path.exists():
    print(f"ERROR: Registry not found at {registry_path}")
    exit(1)

with open(registry_path) as f:
    registry = yaml.safe_load(f)

# Engineering agents (already deployed) - kept for reference
ENGINEERING_AGENTS = {
    "ai-engineer", "app-security", "app-sre", "backend-engineer", "ceo-cto",
    "cloud-engineer", "code-reviewer", "data-engineer", "debugger", "devops-engineer",
    "frontend-engineer", "hr-partner", "k8s-engineer", "platform-security", "platform-sre",
    "product-manager", "qa-engineer", "security-engineer", "solutions-architect",
    "tdd-engineer", "tech-lead", "tech-writer", "ux-designer", "verifier"
}

RESOURCE_TIERS = {
    "standard": {
        "requests_cpu": "100m",
        "requests_memory": "256Mi",
        "limits_cpu": "500m",
        "limits_memory": "1Gi",
    },
    "complex": {
        "requests_cpu": "250m",
        "requests_memory": "512Mi",
        "limits_cpu": "1",
        "limits_memory": "2Gi",
    },
    "executive": {
        "requests_cpu": "200m",
        "requests_memory": "512Mi",
        "limits_cpu": "750m",
        "limits_memory": "1.5Gi",
    },
}


def generate_deployment(slug: str, description: str, tier: str = "standard") -> str:
    """Generate deployment manifest for an agent."""
    resources = RESOURCE_TIERS[tier]
    slug_hyphen = slug.replace("_", "-")

    return f'''apiVersion: apps/v1
kind: Deployment
metadata:
  name: agent-{slug_hyphen}
  namespace: zi
  labels:
    app.kubernetes.io/name: agent-{slug_hyphen}
    app.kubernetes.io/component: agent
    app.kubernetes.io/part-of: zi-agents
spec:
  replicas: 1
  selector:
    matchLabels:
      app: agent-{slug_hyphen}
  template:
    metadata:
      labels:
        app: agent-{slug_hyphen}
        app.kubernetes.io/name: agent-{slug_hyphen}
        app.kubernetes.io/component: agent
    spec:
      imagePullSecrets:
        - name: dockerhub-registry
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
        - name: agent
          image: lzetam/zi-agent-{slug_hyphen}:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 8000
              name: http
          env:
            - name: AGENT_NAME
              value: "{slug_hyphen}"
            - name: AGENT_DESCRIPTION
              value: "{description}"
            - name: AGENT_MAX_ITERATIONS
              value: "15"
            - name: ZI_BRAIN_URL
              value: "http://zi-brain.zi.svc.cluster.local:8100"
            - name: ZI_OLLAMA_URL
              value: "http://ollama-gpu.ollama.svc.cluster.local:11434"
            - name: ZI_KNOWLEDGE_REDIS_HOST
              value: "redis.zi.svc.cluster.local"
            - name: ZI_KNOWLEDGE_REDIS_PORT
              value: "6379"
            - name: ZI_API_URL
              value: "http://zi.zi.svc.cluster.local:8080"
          envFrom:
            - secretRef:
                name: zi-agents-ai-keys
            - secretRef:
                name: zi-brain-api-key
                optional: true
            - secretRef:
                name: zi-agents-discord
                optional: true
          volumeMounts:
            - name: agent-memory
              mountPath: /data
              subPath: {slug_hyphen}
          resources:
            requests:
              cpu: {resources["requests_cpu"]}
              memory: {resources["requests_memory"]}
            limits:
              cpu: {resources["limits_cpu"]}
              memory: {resources["limits_memory"]}
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
      volumes:
        - name: agent-memory
          persistentVolumeClaim:
            claimName: zi-agents-memory
'''


def generate_service(slug: str) -> str:
    """Generate service manifest for an agent."""
    slug_hyphen = slug.replace("_", "-")

    return f'''apiVersion: v1
kind: Service
metadata:
  name: agent-{slug_hyphen}
  namespace: zi
  labels:
    app.kubernetes.io/name: agent-{slug_hyphen}
    app.kubernetes.io/component: agent
    app.kubernetes.io/part-of: zi-agents
spec:
  selector:
    app: agent-{slug_hyphen}
  ports:
    - port: 8000
      targetPort: http
      name: http
'''


def main():
    script_dir = Path(__file__).parent
    deployments_dir = script_dir / "deployments"
    services_dir = script_dir / "services"

    deployments_dir.mkdir(exist_ok=True)
    services_dir.mkdir(exist_ok=True)

    print("Generating K8s manifests for ALL zI agents...")
    print(f"Registry: {registry_path}\n")

    generated_count = 0
    skipped_count = 0

    for slug, info in registry["agents"].items():
        description = info.get("description", "")
        team = info.get("team", "")

        # Determine resource tier
        if team == "Executive":
            tier = "executive"
        elif slug in ["code-reviewer", "debugger", "solutions-architect", "tech-lead"]:
            tier = "complex"
        else:
            tier = "standard"

        slug_hyphen = slug.replace("_", "-")

        # Skip if agent directory doesn't exist in zi repo
        agent_dir = ZI_AGENTS_DIR / slug
        if not agent_dir.exists():
            print(f"  SKIP: {slug_hyphen} (no directory in zi repo)")
            skipped_count += 1
            continue

        # Skip if no Dockerfile
        if not (agent_dir / "Dockerfile").exists():
            print(f"  SKIP: {slug_hyphen} (no Dockerfile)")
            skipped_count += 1
            continue

        # Generate deployment
        deployment = generate_deployment(slug, description, tier)
        (deployments_dir / f"{slug_hyphen}.yaml").write_text(deployment)

        # Generate service
        service = generate_service(slug)
        (services_dir / f"{slug_hyphen}.yaml").write_text(service)

        print(f"  Generated: {slug_hyphen} ({team}, tier: {tier})")
        generated_count += 1

    print(f"\n✓ Generated {generated_count} deployment and service manifests")
    print(f"  Skipped {skipped_count} (no directory or Dockerfile)")
    print("\nNext steps:")
    print("1. Review manifests in deployments/ and services/")
    print("2. Update kustomization.yaml (run ./update-kustomization.sh)")
    print("3. Commit and push - Flux will reconcile")


if __name__ == "__main__":
    main()
