#!/usr/bin/env python3
"""
incident_triage.py — PagerDuty + Slack incident triage dispatcher
Classifies incident by keyword, posts formatted Slack message with runbook link
Usage: python incident_triage.py --payload '{"title":"OOM kill on payment-api"}'
       or run as webhook receiver: python incident_triage.py --serve --port 8080
"""
import argparse
import json
import logging
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

import urllib.request
import urllib.parse

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [incident_triage] %(message)s"
)
log = logging.getLogger(__name__)

RUNBOOK_BASE = "https://github.com/my-git-2024/terraform-aws-demo/blob/main/docs"

CLASSIFICATION_RULES = [
    {"keywords": ["oom", "oomkill", "out of memory", "memory limit"],
     "severity": "P1", "category": "OOM",
     "runbook": f"{RUNBOOK_BASE}/runbook-eks.md#oom-kills",
     "team": "platform-team"},
    {"keywords": ["node not ready", "node failure", "nodepressure", "diskpressure"],
     "severity": "P1", "category": "NODE_FAILURE",
     "runbook": f"{RUNBOOK_BASE}/runbook-eks.md#node-failures",
     "team": "platform-team"},
    {"keywords": ["eks scaling", "hpa", "autoscaler", "scaling failed"],
     "severity": "P2", "category": "SCALING",
     "runbook": f"{RUNBOOK_BASE}/runbook-eks.md#scaling-issues",
     "team": "platform-team"},
    {"keywords": ["split brain", "elasticsearch", "elk", "kibana down"],
     "severity": "P2", "category": "OBSERVABILITY",
     "runbook": f"{RUNBOOK_BASE}/runbook-elk.md",
     "team": "observability-team"},
    {"keywords": ["vault", "secret", "auth failed", "token expired"],
     "severity": "P1", "category": "SECURITY",
     "runbook": f"{RUNBOOK_BASE}/runbook-vault.md",
     "team": "security-team"},
    {"keywords": ["pipeline", "github actions", "deploy failed", "rollback"],
     "severity": "P2", "category": "CICD",
     "runbook": f"{RUNBOOK_BASE}/runbook-cicd.md",
     "team": "platform-team"},
]

SEVERITY_EMOJI = {"P1": "🔴", "P2": "🟠", "P3": "🟡", "P4": "🟢"}


def classify_incident(title, description=""):
    text = (title + " " + description).lower()
    for rule in CLASSIFICATION_RULES:
        if any(kw in text for kw in rule["keywords"]):
            return rule
    return {
        "severity": "P3",
        "category": "GENERAL",
        "runbook":  f"{RUNBOOK_BASE}/runbook-general.md",
        "team":     "platform-team",
    }


def post_slack(webhook_url, message):
    data = json.dumps(message).encode("utf-8")
    req  = urllib.request.Request(
        webhook_url,
        data=data,
        headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            log.info(f"Slack response: {resp.status}")
            return resp.status == 200
    except Exception as e:
        log.error(f"Slack post failed: {e}")
        return False


def build_slack_message(incident, classification):
    emoji    = SEVERITY_EMOJI.get(classification["severity"], "⚪")
    severity = classification["severity"]
    category = classification["category"]
    runbook  = classification["runbook"]
    team     = classification["team"]
    title    = incident.get("title", "Unknown incident")
    inc_id   = incident.get("id", "N/A")
    env      = incident.get("environment", "production")

    return {
        "blocks": [
            {
                "type": "header",
                "text": {"type": "plain_text", "text": f"{emoji} {severity} Incident — {category}"}
            },
            {
                "type": "section",
                "fields": [
                    {"type": "mrkdwn", "text": f"*Title:*\n{title}"},
                    {"type": "mrkdwn", "text": f"*Environment:*\n{env}"},
                    {"type": "mrkdwn", "text": f"*Severity:*\n{severity}"},
                    {"type": "mrkdwn", "text": f"*Category:*\n{category}"},
                    {"type": "mrkdwn", "text": f"*Incident ID:*\n{inc_id}"},
                    {"type": "mrkdwn", "text": f"*Assigned Team:*\n@{team}"},
                ]
            },
            {
                "type": "section",
                "text": {"type": "mrkdwn", "text": f"*Runbook:* <{runbook}|View Runbook>"}
            },
            {"type": "divider"},
            {
                "type": "context",
                "elements": [{"type": "mrkdwn", "text": "Auto-triaged by incident_triage.py — BNY Platform Engineering"}]
            }
        ]
    }


def process_incident(payload_str, slack_webhook=None, dry_run=False):
    try:
        incident = json.loads(payload_str)
    except json.JSONDecodeError as e:
        log.error(f"Invalid JSON payload: {e}")
        sys.exit(1)

    title       = incident.get("title", "")
    description = incident.get("description", "")
    classification = classify_incident(title, description)

    log.info(f"Classified: severity={classification['severity']}, category={classification['category']}")

    message = build_slack_message(incident, classification)

    if dry_run:
        log.info("DRY RUN — Slack message:")
        print(json.dumps(message, indent=2))
    elif slack_webhook:
        success = post_slack(slack_webhook, message)
        if not success:
            sys.exit(1)
    else:
        log.warning("No Slack webhook configured — printing message only")
        print(json.dumps(message, indent=2))

    result = {
        "incident_id":     incident.get("id", "N/A"),
        "title":           title,
        "classification":  classification,
        "slack_notified":  bool(slack_webhook) and not dry_run,
    }
    print(json.dumps(result, indent=2))
    return result


class WebhookHandler(BaseHTTPRequestHandler):
    slack_webhook = None
    def do_POST(self):
        length  = int(self.headers.get("Content-Length", 0))
        payload = self.rfile.read(length).decode("utf-8")
        process_incident(payload, self.slack_webhook)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK")
    def log_message(self, format, *args):
        log.info(f"HTTP {args[1]} {args[0]}")


def main():
    parser = argparse.ArgumentParser(description="Incident Triage Dispatcher")
    parser.add_argument("--payload",       default=None, help="JSON incident payload string")
    parser.add_argument("--slack-webhook", default=os.environ.get("SLACK_WEBHOOK_URL"))
    parser.add_argument("--serve",         action="store_true", help="Run as HTTP webhook server")
    parser.add_argument("--port",          type=int, default=8080)
    parser.add_argument("--dry-run",       action="store_true")
    args = parser.parse_args()

    if args.serve:
        WebhookHandler.slack_webhook = args.slack_webhook
        server = HTTPServer(("0.0.0.0", args.port), WebhookHandler)
        log.info(f"Webhook server listening on port {args.port}")
        server.serve_forever()
    elif args.payload:
        process_incident(args.payload, args.slack_webhook, args.dry_run)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
