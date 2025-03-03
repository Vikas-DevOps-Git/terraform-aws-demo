# EKS Runbook — BNY Platform Engineering

## OOM Kills

**Symptoms:** Pod restarts, `OOMKilled` in `kubectl describe pod`

**Immediate steps:**
```bash
# Identify OOM pods
kubectl get pods -n finance | grep OOMKilled
kubectl describe pod <pod-name> -n finance | grep -A5 "Last State"

# Check VPA recommendations
kubectl describe vpa payment-api-vpa -n finance

# Temporary fix — increase limits
kubectl set resources deployment payment-api \
  --limits=memory=2Gi -n finance
```

**Root cause:** Resource limits too low vs actual usage. Apply VPA recommendation to values.yaml and redeploy via Helm.

---

## Node Failures

**Symptoms:** Node shows `NotReady`, pods evicted

```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name> | grep -A10 Conditions

# Check node events
kubectl get events --field-selector involvedObject.name=<node-name>

# Cordon and drain if hardware issue
kubectl cordon <node-name>
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Force new node via node group scaling
aws eks update-nodegroup-config \
  --cluster-name prod-eks-cluster \
  --nodegroup-name prod-on-demand \
  --scaling-config desiredSize=3,minSize=1,maxSize=10
```

---

## Scaling Issues

**Symptoms:** HPA not scaling, pods pending

```bash
# Check HPA status
kubectl describe hpa payment-api-hpa -n finance

# Check metrics-server
kubectl top pods -n finance
kubectl top nodes

# Check pending pods
kubectl get pods -n finance | grep Pending
kubectl describe pod <pending-pod> -n finance | grep Events -A10
```
