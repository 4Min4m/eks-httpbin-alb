# AWS EKS HTTPBin Deployment

This project deploys an HTTPBin application on AWS Elastic Kubernetes Service (EKS) using Infrastructure as Code (IaC). It provides two distinct endpoints: a public endpoint for GET requests and a private endpoint for POST requests, accessible only within the VPC. The implementation leverages Terraform for infrastructure provisioning and Kubernetes for application orchestration, ensuring a secure, scalable, and highly available architecture. This README explains the project, tool choices, implementation steps, security measures, and testing instructions.
Project Overview
The goal is to deploy the HTTPBin application on an EKS cluster with:

A public endpoint (internet-facing) for /get requests, accessible globally.
A private endpoint (VPC-internal) for /post requests, restricted to resources within the VPC.
A secure, multi-AZ infrastructure with worker nodes in private subnets for enhanced security.

The project uses AWS services (EKS, VPC, ALB) and IaC to automate deployment, ensuring reproducibility and scalability.
Tool Choices and Rationale

Terraform for IaC:

Why: Terraform enables declarative infrastructure management, supporting consistent deployments across environments. Its AWS provider simplifies VPC, EKS, and ALB configuration.
Benefit: Reduces manual errors, supports versioning, and integrates with CI/CD pipelines.


AWS Load Balancer Controller and Ingress:

Why: The ALB Controller integrates natively with Kubernetes, creating Application Load Balancers (ALBs) for public and private ingresses. Ingress resources simplify routing rules for HTTPBin endpoints.
Benefit: Provides fine-grained traffic management, automatic load balancer provisioning, and VPC-internal routing for private endpoints.


Session Manager for EC2 Access:

Why: AWS Systems Manager (SSM) Session Manager allows secure access to EC2 instances in private subnets without public IPs or SSH keys.
Benefit: Enhances security by avoiding bastion hosts and public exposure.


kubectl and Helm:

Why: kubectl manages Kubernetes resources, and Helm simplifies ALB Controller installation.
Benefit: Industry-standard tools for Kubernetes orchestration and package management.



# Implementation Process

The implementation followed a structured approach to build a secure and scalable EKS-based application.

Infrastructure Setup with Terraform:

Created a VPC (<VPC_ID>) with public and private subnets across two Availability Zones for high availability.
Configured a NAT Gateway in a public subnet for outbound internet access from private subnets.
Deployed an EKS cluster (<CLUSTER_NAME>) with worker nodes in private subnets, using t3.micro instances for cost efficiency.
Installed the AWS Load Balancer Controller via Helm to manage ALBs for ingress resources.
Terraform files (vpc.tf, eks.tf, alb.tf) defined the infrastructure.


Kubernetes Configuration:

Deployed the HTTPBin application with two replicas, using pod anti-affinity to ensure distribution across nodes.
Created a Kubernetes service to expose HTTPBin.
Defined two ingress resources:
Public Ingress: Routes /get to an internet-facing ALB.
Private Ingress: Routes /post to an internal ALB, accessible only within the VPC.


Kubernetes manifests (k8s/deployment.yaml, k8s/service.yaml, k8s/ingress-public.yaml, k8s/ingress-private.yaml) managed these resources.


Steps:
git clone <repository-url>
cd <repository-directory>/terraform
terraform init
terraform apply
aws eks update-kubeconfig --region us-east-1 --name <CLUSTER_NAME>
kubectl apply -f ../k8s/



# Security and Policy Measures

Security was prioritized through IAM policies, network isolation, and RBAC to protect the infrastructure and application.

IAM Policies:

Created an IAM role (<SSM_ROLE>) with AmazonSSMManagedInstanceCore for EC2 instances to enable Session Manager access.
Attached a policy (<SSM_POLICY>) to the IAM user, granting ssm:StartSession, ssm:GetConnectionStatus, ssm:DescribeSessions, ssm:TerminateSession, ssm:SendCommand, and ssm:GetCommandInvocation permissions:aws iam create-policy --policy-name <SSM_POLICY> --policy-document file://ssm-policy.json
aws iam attach-user-policy --user-name <IAM_USER> --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/<SSM_POLICY>


Ensured the EKS cluster role had permissions for cluster and node group management.

# Network Security:

Placed worker nodes in private subnets with no public IPs.
Configured security groups to allow:
Outbound HTTPS (port 443) for SSM and AWS API communication.
Inbound HTTP (port 80) from the ALB for application traffic.


Used a NAT Gateway for private subnet outbound traffic.



Post-Deployment Actions
After the infrastructure and application were deployed, the following steps ensured functionality and validation.

Verified Cluster and Application:kubectl get nodes
kubectl get pods
kubectl get ingress


Checked ALB Controller:kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller


# Retrieved ALB URLs:
Public: <PUBLIC_ALB_URL> for /get.
Private: <PRIVATE_ALB_URL> for /post.

kubectl get ingress httpbin-public -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get ingress httpbin-private -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'



# Testing the Deployment
The deployment was tested to validate public and private endpoint functionality.

Public Endpoint Test:

Tested /get from outside the VPC:curl http://<PUBLIC_ALB_URL>/get
curl http://<PUBLIC_ALB_URL>/status/200


Expected JSON response with request details (e.g., headers, origin).


Private Endpoint Test:

Launched an EC2 instance in a private subnet with the <SSM_ROLE> IAM role.
Connected via Session Manager:aws ssm start-session --target <INSTANCE_ID> --region us-east-1


Tested /post from the EC2 instance:sudo yum install curl -y
curl -X POST http://<PRIVATE_ALB_URL>/post


Expected JSON response confirming VPC-internal access (e.g., origin IP from private subnet).



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

Cleanup
kubectl delete -f ../k8s/
kubectl get ingress  # Wait for ingress deletion
terraform destroy

Note: Verify load balancers are deleted before running terraform destroy to avoid orphaned resources.
Security and Production Considerations

Security: Private subnets, IAM-based EKS access, least-privilege security groups.
Production: Enable EKS encryption, use private cluster endpoints, implement network policies, and add monitoring.