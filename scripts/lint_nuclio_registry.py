#!/usr/bin/env python3
"""Nuclio on-build must push to the in-cluster registry.

An empty registry.pushPullUrl makes Kaniko push nuclio/processor-<name> to
Docker Hub, which fails with UNAUTHORIZED. The registry Service and the
core-pvc subPath live next to CrowdSec because that claim is namespace-local.
"""
import sys

import yaml

INFRA_PATH = "k8s/argocd-apps/infra.yaml"
REGISTRY_MANIFEST = "k8s/infra/crowdsec/registry.yaml"
APP_NAME = "infra-nuclio"
PUSH_PULL_URL = "registry.crowdsec.svc.cluster.local:5000"


def load_docs(path: str) -> list:
    with open(path, encoding="utf-8") as f:
        return [doc for doc in yaml.safe_load_all(f) if isinstance(doc, dict)]


def nuclio_values() -> dict:
    for doc in load_docs(INFRA_PATH):
        if (doc.get("metadata") or {}).get("name") != APP_NAME:
            continue
        sources = doc["spec"]["sources"]
        values_str = sources[0]["helm"]["values"]
        return yaml.safe_load(values_str) or {}
    raise SystemExit(f"[FAIL] {APP_NAME} Application not found in {INFRA_PATH}")


def main() -> int:
    values = nuclio_values()
    dashboard = values.get("dashboard") or {}
    registry = values.get("registry") or {}
    errors = []

    if dashboard.get("containerBuilderKind") != "kaniko":
        errors.append("dashboard.containerBuilderKind must be kaniko")
    if registry.get("pushPullUrl") != PUSH_PULL_URL:
        errors.append(f"registry.pushPullUrl must be {PUSH_PULL_URL}")
    build = dashboard.get("build") or {}
    if build.get("insecurePushRegistry") is not True:
        errors.append("dashboard.build.insecurePushRegistry must be true")

    docs = load_docs(REGISTRY_MANIFEST)
    service = next(
        (doc for doc in docs if doc.get("kind") == "Service" and (doc.get("metadata") or {}).get("name") == "registry"),
        None,
    )
    deployment = next(
        (doc for doc in docs if doc.get("kind") == "Deployment" and (doc.get("metadata") or {}).get("name") == "registry"),
        None,
    )
    if service is None:
        errors.append(f"{REGISTRY_MANIFEST} has no Service registry")
    elif (service.get("metadata") or {}).get("namespace") != "crowdsec":
        errors.append("Service registry must be in namespace crowdsec")
    if deployment is None:
        errors.append(f"{REGISTRY_MANIFEST} has no Deployment registry")
    else:
        rendered = yaml.safe_dump(deployment)
        if "subPath: registry" not in rendered or "claimName: core-pvc" not in rendered:
            errors.append("Deployment registry must mount core-pvc subPath registry")
    manifest_text = open(REGISTRY_MANIFEST, encoding="utf-8").read()
    if PUSH_PULL_URL not in manifest_text:
        errors.append(f"{REGISTRY_MANIFEST} must publish {PUSH_PULL_URL} to the nodes")

    if errors:
        print("[FAIL] Nuclio registry convention")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(f"[OK] Nuclio pushes to {PUSH_PULL_URL} on core-pvc subPath registry")
    return 0


if __name__ == "__main__":
    sys.exit(main())
