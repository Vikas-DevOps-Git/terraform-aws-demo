output "cluster_role_arn"    { value = aws_iam_role.eks_cluster.arn }
output "node_role_arn"       { value = aws_iam_role.eks_node.arn }
output "pod_identity_role_arn" { value = aws_iam_role.pod_identity.arn }
