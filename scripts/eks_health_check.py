#!/usr/bin/env python3
"""
eks_health_check.py — EKS cluster health reporter
Checks node readiness, OOM events, HPA threshold status
Usage: python eks_health_check.py --namespace finance --output json
"""
import argparse
import json
import logging
import sys
from datetime import datetime, timezone
from kubernetes import client, config
from kubernetes.client.exceptions import ApiException

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)
log = logging.getLogger(__name__)


def load_kube_config():
    try:
        config.load_incluster_config()
        log.info("Loaded in-cluster config")
    except config.ConfigException:
        config.load_kube_config()
        log.info("Loaded kubeconfig")


def check_nodes():
    v1 = client.CoreV1Api()
    nodes = v1.list_node()
    results = []
    for node in nodes.items:
        ready = False
        for cond in node.status.conditions:
            if cond.type == "Ready":
                ready = cond.status == "True"
        results.append({
            "name": node.metadata.name,
            "ready": ready,
            "labels": node.metadata.labels,
            "allocatable_cpu":    node.status.allocatable.get("cpu"),
            "allocatable_memory": node.status.allocatable.get("memory"),
        })
    not_ready = [n for n in results if not n["ready"]]
    if not_ready:
        log.warning(f"{len(not_ready)} node(s) NOT READY: {[n['name'] for n in not_ready]}")
    return results


def check_oom_events(namespace):
    v1 = client.CoreV1Api()
    events = v1.list_namespaced_event(namespace)
    oom_events = []
    for e in events.items:
        if "OOMKill" in (e.reason or "") or "OOMKilling" in (e.message or ""):
            oom_events.append({
                "pod":       e.involved_object.name,
                "namespace": e.involved_object.namespace,
                "message":   e.message,
                "count":     e.count,
                "timestamp": str(e.last_timestamp),
            })
    if oom_events:
        log.warning(f"Found {len(oom_events)} OOM events in namespace {namespace}")
    return oom_events


def check_hpa(namespace):
    autoscaling = client.AutoscalingV2Api()
    hpas = autoscaling.list_namespaced_horizontal_pod_autoscaler(namespace)
    results = []
    for hpa in hpas.items:
        current  = hpa.status.current_replicas or 0
        desired  = hpa.status.desired_replicas or 0
        max_rep  = hpa.spec.max_replicas
        at_max   = current >= max_rep
        results.append({
            "name":            hpa.metadata.name,
            "current_replicas": current,
            "desired_replicas": desired,
            "max_replicas":     max_rep,
            "at_max_capacity":  at_max,
        })
        if at_max:
            log.warning(f"HPA {hpa.metadata.name} is AT MAX capacity ({current}/{max_rep})")
    return results


def main():
    parser = argparse.ArgumentParser(description="EKS Cluster Health Check")
    parser.add_argument("--namespace", default="finance",  help="Kubernetes namespace")
    parser.add_argument("--output",    default="json",     choices=["json", "text"])
    args = parser.parse_args()

    load_kube_config()

    report = {
        "timestamp":  datetime.now(timezone.utc).isoformat(),
        "namespace":  args.namespace,
        "nodes":      check_nodes(),
        "oom_events": check_oom_events(args.namespace),
        "hpa_status": check_hpa(args.namespace),
    }

    unhealthy_nodes = len([n for n in report["nodes"] if not n["ready"]])
    report["summary"] = {
        "total_nodes":     len(report["nodes"]),
        "unhealthy_nodes": unhealthy_nodes,
        "oom_events":      len(report["oom_events"]),
        "hpas_at_max":     len([h for h in report["hpa_status"] if h["at_max_capacity"]]),
        "overall_status":  "DEGRADED" if (unhealthy_nodes > 0 or len(report["oom_events"]) > 0) else "HEALTHY",
    }

    if args.output == "json":
        print(json.dumps(report, indent=2))
    else:
        print(f"\n=== EKS Health Report — {report['timestamp']} ===")
        print(f"Nodes     : {report['summary']['total_nodes']} total, {report['summary']['unhealthy_nodes']} unhealthy")
        print(f"OOM Events: {report['summary']['oom_events']}")
        print(f"HPAs at max: {report['summary']['hpas_at_max']}")
        print(f"Status    : {report['summary']['overall_status']}")

    if report["summary"]["overall_status"] == "DEGRADED":
        sys.exit(1)


if __name__ == "__main__":
    main()


def check_restart_counts(namespace, threshold):
    """Flag pods with restart count above threshold in last hour."""
    v1 = client.CoreV1Api()
    pods = v1.list_namespaced_pod(namespace)
    flagged = []
    for pod in pods.items:
        for cs in (pod.status.container_statuses or []):
            if cs.restart_count >= threshold:
                flagged.append({
                    "pod":            pod.metadata.name,
                    "container":      cs.name,
                    "restart_count":  cs.restart_count,
                })
                log.warning(
                    f"Pod {pod.metadata.name}/{cs.name} has "
                    f"{cs.restart_count} restarts (threshold={threshold})"
                )
    return flagged
