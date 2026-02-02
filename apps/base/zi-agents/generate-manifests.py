#!/usr/bin/env python3
"""Generate K8s deployment and service manifests for all zI agents.

NOTE: AGENT_TOOLS is NOT defined here - it's defined in each agent's Dockerfile
to maintain a single source of truth. Only AGENT_NAME, AGENT_DESCRIPTION, and
AGENT_MAX_ITERATIONS are set in K8s manifests.
"""

from pathlib import Path

# Agent configurations: slug -> (description, max_iterations, resource_tier)
# Resource tiers: "standard" (100m/256Mi), "complex" (250m/512Mi)
# AGENT_TOOLS is defined in Dockerfile, not here
AGENTS = {
    "ai-engineer": ("Builds MCP servers, AI integrations, and agent systems", 15, "standard"),
    "app-security": ("Secures application code, OWASP vulnerabilities", 15, "standard"),
    "app-sre": ("Application reliability and performance", 15, "standard"),
    "backend-engineer": ("Builds APIs, services, and backend systems", 15, "standard"),
    "ceo-cto": ("Strategic decisions and executive leadership", 10, "standard"),
    "cloud-engineer": ("AWS infrastructure and cloud services", 15, "standard"),
    "code-reviewer": ("Reviews code for quality, correctness, and best practices", 15, "complex"),
    "data-engineer": ("Data pipelines, schemas, and ETL", 15, "standard"),
    "debugger": ("Root cause analysis and debugging", 20, "complex"),
    "devops-engineer": ("CI/CD pipelines and deployment automation", 15, "standard"),
    "frontend-engineer": ("UI development and frontend systems", 15, "standard"),
    "hr-partner": ("Performance reviews and feedback", 10, "standard"),
    "k8s-engineer": ("Kubernetes deployment and operations", 15, "standard"),
    "platform-security": ("K8s security, CIS benchmarks", 15, "standard"),
    "platform-sre": ("Infrastructure reliability and monitoring", 15, "standard"),
    "product-manager": ("Requirements, roadmap, and product strategy", 10, "standard"),
    "qa-engineer": ("Test strategy and quality assurance", 15, "standard"),
    "security-engineer": ("Organization-wide security policy", 15, "standard"),
    "solutions-architect": ("Architecture design and scalability", 15, "complex"),
    "tdd-engineer": ("Test-driven development", 15, "standard"),
    "tech-lead": ("Technical decisions and planning", 15, "complex"),
    "tech-writer": ("Documentation and technical writing", 12, "standard"),
    "ux-designer": ("UI/UX design and user experience", 10, "standard"),
    "verifier": ("Pre-completion verification checks", 15, "standard"),
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
}


def generate_deployment(slug: str, description: str, max_iter: int, tier: str) -> str:
    """Generate deployment manifest for an agent.

    NOTE: AGENT_TOOLS is NOT set here - it comes from the Dockerfile ENV.
    This ensures Dockerfile is the single source of truth for agent tools.
    """
    resources = RESOURCE_TIERS[tier]

    return f'''apiVersion: apps/v1
kind: Deployment
metadata:
  name: agent-{slug}
  namespace: zi
  labels:
    app.kubernetes.io/name: agent-{slug}
    app.kubernetes.io/component: agent
    app.kubernetes.io/part-of: zi-agents
spec:
  replicas: 1
  selector:
    matchLabels:
      app: agent-{slug}
  template:
    metadata:
      labels:
        app: agent-{slug}
        app.kubernetes.io/name: agent-{slug}
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
          image: lzetam/zi-agent-{slug}:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 8000
              name: http
          env:
            # AGENT_TOOLS is defined in Dockerfile - single source of truth
            - name: AGENT_NAME
              value: "{slug}"
            - name: AGENT_DESCRIPTION
              value: "{description}"
            - name: AGENT_MAX_ITERATIONS
              value: "{max_iter}"
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
              subPath: {slug}
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
    return f'''apiVersion: v1
kind: Service
metadata:
  name: agent-{slug}
  namespace: zi
  labels:
    app.kubernetes.io/name: agent-{slug}
    app.kubernetes.io/component: agent
    app.kubernetes.io/part-of: zi-agents
spec:
  selector:
    app: agent-{slug}
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

    print("Generating K8s manifests for zi-agents...")
    print("NOTE: AGENT_TOOLS comes from Dockerfile, not manifests\n")

    for slug, (description, max_iter, tier) in AGENTS.items():
        # Generate deployment
        deployment = generate_deployment(slug, description, max_iter, tier)
        (deployments_dir / f"{slug}.yaml").write_text(deployment)

        # Generate service
        service = generate_service(slug)
        (services_dir / f"{slug}.yaml").write_text(service)

        print(f"  Generated: {slug} (tier: {tier})")

    print(f"\nGenerated {len(AGENTS)} deployment and service manifests.")
    print("\nNext steps:")
    print("1. Review manifests in deployments/ and services/")
    print("2. Add to kustomization.yaml")
    print("3. Commit and push - Flux will reconcile")


if __name__ == "__main__":
    main()
