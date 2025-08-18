# AWS EKS HTTPBin Deployment
This project deploys an HTTPBin application on AWS Elastic Kubernetes Service (EKS) using Infrastructure as Code (IaC) with Terraform and Kubernetes manifests. It provides two endpoints:

Public Endpoint: /get (internet-facing, globally accessible via an Application Load Balancer).
Private Endpoint: /post (internal, accessible only within the VPC).

The implementation ensures a secure, scalable, and highly available architecture, leveraging Terraform for infrastructure provisioning and Kubernetes for application orchestration. This README details the implementation, tool choices, security measures, testing instructions, and troubleshooting insights to ensure reproducibility.
Project Overview
The goal is to deploy the HTTPBin application on an EKS cluster (<cluster-name>) with:

A public ALB for /get requests, accessible globally (e.g., http://<public-alb-address>/get).
A private ALB for /post requests, restricted to VPC-internal access (e.g., http://<private-alb-address>/post).
A multi-AZ infrastructure with worker nodes in private subnets for enhanced security.

The project uses AWS services (EKS, VPC, ALB) and IaC to automate deployment, ensuring consistency and scalability.
Tool Choices and Rationale

## Terraform for IaC:
Why: Declarative infrastructure management ensures consistent deployments across environments. The AWS provider simplifies VPC, EKS, and ALB configuration.
Benefit: Reduces manual errors, supports versioning, and integrates with CI/CD pipelines.


## AWS Load Balancer Controller and Ingress:
Why: The AWS Load Balancer Controller integrates with Kubernetes to create ALBs for Ingress resources, enabling fine-grained routing for /get and /post.
Benefit: Automates ALB provisioning, supports internal/external schemes, and ensures VPC-internal routing for private endpoints.


## Session Manager for EC2 Access:
Why: AWS Systems Manager (SSM) Session Manager provides secure access to EC2 instances in private subnets without public IPs or SSH keys.
Benefit: Enhances security by eliminating bastion hosts and public exposure.


## kubectl and Helm:
Why: kubectl manages Kubernetes resources, and Helm simplifies the AWS Load Balancer Controller installation.
Benefit: Industry-standard tools for Kubernetes orchestration and package management.



# Implementation Process
The implementation followed a structured approach to build a secure, scalable EKS-based application, with troubleshooting to resolve issues like IAM permissions and ALB accessibility.
Infrastructure Setup with Terraform

## VPC Configuration (vpc.tf):
Created a VPC (<vpc-id>) with:
Public Subnets: <public-subnet-1>, <public-subnet-2> (tagged kubernetes.io/role/elb=1).
Private Subnets: <private-subnet-1>, <private-subnet-2> (tagged kubernetes.io/role/internal-elb=1).
A NAT Gateway in a public subnet for outbound internet access from private subnets.




## EKS Cluster (eks.tf):
Deployed an EKS cluster (<cluster-name>) with worker nodes in private subnets, using t3.micro instances for cost efficiency.


## ALB Controller (alb.tf):
Installed the AWS Load Balancer Controller via Helm (aws-load-balancer-controller, version v2.13.4) in the kube-system namespace.
Created an IAM role (<alb-role>) with a comprehensive policy (<alb-policy>) including permissions like elasticloadbalancing:DescribeListenerAttributes.



## Kubernetes Configuration

### Deployed the HTTPBin application in the httpbin namespace with:
A deployment (httpbin) with two replicas, using pod anti-affinity for distribution across nodes.
A service (httpbin-service) exposing port 80.
### Two Ingress resources:
Public Ingress (httpbin-public): Routes /get to an internet-facing ALB.
Private Ingress (httpbin-private): Routes /post to an internal ALB, restricted to VPC access.

Manifests are in k8s/ (deployment.yaml, service.yaml, ingress-public.yaml, ingress-private.yaml).

# Key Implementation Challenges and Resolutions

## Duplicate IAM Role/Policy:
### Issue: EntityAlreadyExists errors for <alb-role> and <alb-policy> due to duplicates in eks.tf and alb.tf.
### Resolution: Consolidated definitions in alb.tf, removed duplicates from eks.tf, and cleaned the Terraform state:terraform state rm aws_iam_role.alb_controller
### terraform state rm aws_iam_policy.alb_controller

## Missing ALB Controller:
### Issue: No controller pods in kube-system because the Helm release was missing.
### Resolution: Added helm_release.aws_load_balancer_controller to alb.tf.

## Duplicate Helm Provider:
### Issue: Duplicate provider configuration error due to helm provider in both alb.tf and provider.tf.
### Resolution: Moved helm provider to provider.tf.


## IAM Permission Error:
### Issue: AccessDenied for elasticloadbalancing:DescribeListenerAttributes, causing FailedDeployModel errors.
### Resolution: Added the permission to the IAM policy in alb.tf.


## Incorrect ALB Scheme:
### Issue: httpbin-private ALB was accessible externally despite alb.ingress.kubernetes.io/scheme: internal.
### Resolution: Added subnet annotations (alb.ingress.kubernetes.io/subnets) to ingress-private.yaml and verified private subnets.


## Subnet Tags:
### Issue: Missing kubernetes.io/role/elb and kubernetes.io/role/internal-elb tags on subnets.
### Resolution: Added tags to aws_subnet resources in eks.tf.



## Security and Policy Measures

### IAM Policies:
#### Created <alb-role> with a policy granting necessary permissions for ALB management (e.g., elasticloadbalancing:*, ec2:CreateTags).
#### Used an IAM role for SSM (AmazonSSMManagedInstanceCore) to enable Session Manager access to EC2 instances.
#### Ensured least-privilege principles by scoping permissions to specific resources where possible (e.g., aws:ResourceTag/elbv2.k8s.aws/cluster=<cluster-name>).


### Network Security:
#### Placed worker nodes in private subnets (<private-subnet-1>, <private-subnet-2>) with no public IPs.
#### Configured security groups to allow:
1. Outbound HTTPS (port 443) for SSM and AWS API communication.
2. Inbound HTTP (port 80) from the ALB (<alb-security-group>) for application traffic.

#### Used a NAT Gateway for private subnet outbound traffic.


### Kubernetes RBAC:
Configured the aws-load-balancer-controller ServiceAccount with the correct IAM role annotation (eks.amazonaws.com/role-arn: arn:aws:iam::<account-id>:role/<alb-role>).



# Instructions for Deployment
## Prerequisites

1. Tools: Terraform, Helm CLI, AWS CLI, kubectl.
2. AWS CLI Configuration: Configure credentials with permissions for EKS, EC2, ELB, and IAM.
3. Repository: Clone the project repository:
```bash
git clone <repository-url>
cd <repository-directory>/terraform
```


## Deployment Steps

Initialize Terraform:
```bash
terraform init
```

Apply Infrastructure:
```bash
terraform apply -auto-approve
```

Configure kubectl:
```bash
aws eks update-kubeconfig --region <your-region> --name <cluster-name>
```

Configure AWS Auth for Console Access:
To enable access to Kubernetes objects in the AWS EKS console and via `kubectl`, update the `aws-auth` ConfigMap to include your IAM user.

1. **Download the `aws-auth` ConfigMap**:

```bash
   kubectl get configmap aws-auth -n kube-system -o yaml > aws-auth.yaml
```

2. **Edit `aws-auth.yaml`**:
    Open aws-auth.yaml in an editor.
    Add your IAM user under `mapUsers`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::<account-id>:role/<node-role>
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
  mapUsers: |
    - userarn: arn:aws:iam::<account-id>:user/<your-username>
      username: <your-username>
      groups:
        - system:masters

```

Replace <account-id> with your AWS account ID and <your-username> with your IAM user name.
Ensure <node-role> matches the EKS node group role ARN (from eks.tf).

3. **Apply the Updated ConfigMap:**:
```bash
kubectl apply -f aws-auth.yaml
```

Apply Kubernetes Manifests (first namespace, then others):
```bash
kubectl apply -f ../k8s/
```

Check cluster and application:
```bash
kubectl get nodes
kubectl get pods -n httpbin
kubectl get ingress -n httpbin
```

Check ALB Controller:
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

Retrieve ALB URLs:
```bash
kubectl get ingress httpbin-public -n httpbin -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get ingress httpbin-private -n httpbin -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Testing the Deployment

Public Endpoint:

Test /get from outside the VPC:
```bash
curl http://<public-alb-address>/get
```

Expected: JSON response with request details (e.g., headers, origin).


Private Endpoint:
Launch an EC2 instance in a private subnet with the AmazonSSMManagedInstanceCore IAM role.
Connect via Session Manager:
```bash
aws ssm start-session --target <instance-id> --region <your-region>
```

Install curl and test /post:
```bash
sudo yum install curl -y
curl -X POST http://<private-alb-address>/post -d 'test'
```

Expected: JSON response confirming VPC-internal access (e.g., origin IP from private subnet).


Alternatively, test from a pod:
```bash
kubectl run test --image=curlimages/curl -n httpbin --rm -it -- /bin/sh
$ curl -X POST http://internal-k8s-httpbin-httpbinp-d07dae6130-828027314.us-east-1.elb.amazonaws.com/post -d 'test'
```

Cleanup

Delete Kubernetes resources:
```bash
kubectl delete -f ../k8s/
kubectl get ingress -n httpbin  # Wait for deletion
```

Destroy infrastructure:
```bash
terraform destroy -auto-approve
```

Verify cleanup:
```bash
aws elbv2 describe-load-balancers --names <private-alb-name> <public-alb-name> --region <your-region> || echo "ALBs deleted"
aws iam get-role --role-name <alb-role> || echo "Role deleted"
```


```
Files Structure

├── terraform/
│ ├── alb.tf # ALB Controller and IAM policies
│ ├── eks.tf # EKS cluster and node groups
│ ├── vpc.tf # VPC, subnets, NAT Gateway, routing
│ ├── provider.tf # Terraform providers
│ ├── variables.tf # Input variables
│ └── outputs.tf # Output values
└── k8s/
├── deployment.yaml # HTTPBin deployment
├── service.yaml # Kubernetes service
├── ingress-public.yaml # Public ingress (/get)
└── ingress-private.yaml # Private ingress (/post)

```

## Security and Production Considerations

### Security:
Worker nodes in private subnets with no public IPs.
Least-privilege IAM policies for the ALB Controller and SSM.
Security groups restrict traffic to necessary ports (e.g., HTTP/80 for ALBs, HTTPS/443 for AWS APIs).


### Production:
Enable EKS control plane encryption.
Use private cluster endpoints to restrict control plane access.
Implement Kubernetes network policies to isolate namespaces.
Add monitoring (e.g., CloudWatch, Prometheus) for ALB and pod health.
Configure auto-scaling for the HTTPBin deployment and EKS node group.
Configure S3 bucket with versioning and encryption for Terraform state backup.
Utilize DynamoDB for state locking to prevent concurrent modifications.


## Troubleshooting Tips

### No Ingress Addresses:
Check controller logs: 
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --since=10m | grep -E 'httpbin-private|httpbin-public|error|failed'
```
Verify IAM role permissions:
```bash
aws iam get-policy --policy-arn arn:aws:iam::<account-id>:policy/<alb-policy>
```
Verify the EKS cluster’s OIDC issuer:
```bash
aws eks describe-cluster --name <cluster-name> --region <your-region> --query 'cluster.identity.oidc.issuer' --output text
```
Ensure subnet tags: 
```bash
aws ec2 describe-subnets --subnet-ids <public-subnet-1> <public-subnet-2> <private-subnet-1> <private-subnet-2> --region <your-region>
```

### Private ALB Accessible Externally:
Verify ALB scheme: 
```bash
aws elbv2 describe-load-balancers --names <private-alb-name> --region <your-region> --query 'LoadBalancers[*].Scheme'
```
Check Ingress annotations:
```bash
kubectl get ingress httpbin-private -n httpbin -o yaml
```

### Pod Access Issues:
Check pod events:
```bash
kubectl get events -n httpbin --sort-by='.metadata.creationTimestamp'
```
Verify ALB target health:
```bash
aws elbv2 describe-target-health --target-group-arn <target-group-arn> --region <your-region>
```


This setup has been tested to ensure httpbin-public is globally accessible and httpbin-private is restricted to VPC-internal access, with all infrastructure managed via Terraform for reproducibility.