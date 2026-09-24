#!/usr/bin/env python3
"""
crowdsec subPath 컨벤션 린터

CONVENTION(관례): k8s/argocd-apps/infra.yaml 의 infra-crowdsec Application에서
lapi.persistentVolume.{data,config}.subPath 를 사용하면,
lapi.extraInitContainers 에 cleanup-subpath-dirs init container를 반드시 함께 유지해야 한다.

이 스크립트는 해당 컨벤션이 지켜졌는지 검증한다.
subPath 가 설정되어 있는데 cleanup init container 가 없으면 오류(fail)로 처리한다.
"""
import sys

import yaml

INFRA_PATH = "k8s/argocd-apps/infra.yaml"
APP_NAME = "infra-crowdsec"
INIT_CONTAINER_NAME = "cleanup-subpath-dirs"
SUBPATH_FIELDS = ("data", "config")


def load_app(path: str) -> dict:
    with open(path, encoding="utf-8") as f:
        docs = list(yaml.safe_load_all(f))

    for doc in docs:
        if not isinstance(doc, dict):
            continue
        meta = doc.get("metadata") or {}
        if meta.get("name") == APP_NAME:
            return doc
    raise SystemExit(f"[FAIL] {APP_NAME} Application not found in {path}")


def subpath_values(app: dict) -> dict:
    """return {data: <subpath-or-None>, config: <subpath-or-None>}"""
    try:
        values_str = app["spec"]["source"]["helm"]["values"]
    except (KeyError, TypeError):
        return {}

    values = yaml.safe_load(values_str) or {}
    lapi = values.get("lapi") or {}
    pv = lapi.get("persistentVolume") or {}

    result = {}
    for field in SUBPATH_FIELDS:
        sub = (pv.get(field) or {}).get("subPath")
        result[field] = sub if sub else None
    return result


def has_init_container(app: dict) -> bool:
    try:
        values_str = app["spec"]["source"]["helm"]["values"]
    except (KeyError, TypeError):
        return False
    values = yaml.safe_load(values_str) or {}
    lapi = values.get("lapi") or {}
    init_containers = lapi.get("extraInitContainers") or []
    return any(
        isinstance(c, dict) and c.get("name") == INIT_CONTAINER_NAME
        for c in init_containers
    )


def main() -> int:
    app = load_app(INFRA_PATH)
    subpaths = subpath_values(app)
    used = {k: v for k, v in subpaths.items() if v}

    if not used:
        print(f"[OK] subPath 미사용 - 컨벤션 적용 대상 아님")
        return 0

    if has_init_container(app):
        print(f"[OK] subPath {used} 사용 - cleanup init container 존재 (컨벤션 준수)")
        return 0

    print(
        f"[FAIL] subPath {used} 설정되어 있으나 "
        f"'{INIT_CONTAINER_NAME}' init container 가 없습니다.\n"
        f"  CONVENTION: subPath 를 사용하면 cleanup-subpath-dirs init container 를 "
        f"lapi.extraInitContainers 에 함께 유지하세요."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())