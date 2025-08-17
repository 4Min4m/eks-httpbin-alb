# Installs AWS Load Balancer Controller via Helm for Ingress support

resource "time_sleep" "wait_for_cluster" {
  depends_on = [aws_eks_node_group.main]
  create_duration = "180s"
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  timeout = 900

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }
  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller.arn
  }
  set {
    name  = "enableServiceMutatorWebhook"
    value = "false"
  }
  set {
    name  = "logLevel"
    value = "info"
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main,
    aws_iam_role.alb_controller,
    aws_iam_role_policy_attachment.alb_controller_policy,
    aws_subnet.public,
    aws_subnet.private,
    time_sleep.wait_for_cluster
  ]
}