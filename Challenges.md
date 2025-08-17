# Challenges and Solutions in AWS EKS HTTPBin Deployment

This document outlines the key challenges faced during the deployment of the HTTPBin application on AWS EKS and the solutions implemented to resolve them. These challenges focus on IAM policies, Kubernetes RBAC, Session Manager connectivity, and network configurations, providing insights for future deployments.
1. Kubernetes RBAC Access Denied

Challenge: The IAM user lacked access to the EKS cluster, resulting in the error: Your current IAM principal doesn't have access to Kubernetes objects on this cluster.
Solution: Updated the aws-auth ConfigMap to map the IAM user to the system:masters group for admin access.cat <<EOF > aws-auth.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapUsers: |
    - userarn: arn:aws:iam::<ACCOUNT_ID>:user/<IAM_USER>
      username: <IAM_USER>
      groups:
        - system:masters
EOF
kubectl apply -f aws-auth.yaml


Takeaway: Map IAM users to Kubernetes RBAC immediately after cluster creation to ensure access.

2. SSM Access Denied for Session Manager

Challenge: Connecting to an EC2 instance via Session Manager failed with: User: arn:aws:iam::<ACCOUNT_ID>:user/<IAM_USER> is not authorized to perform: ssm:StartSession.
Solution: Created and attached an IAM policy (<SSM_POLICY>) to the user, granting ssm:StartSession, ssm:GetConnectionStatus, ssm:DescribeSessions, ssm:TerminateSession, ssm:SendCommand, and ssm:GetCommandInvocation permissions.echo '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:StartSession",
        "ssm:GetConnectionStatus",
        "ssm:DescribeSessions",
        "ssm:TerminateSession"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:SendCommand",
        "ssm:GetCommandInvocation"
      ],
      "Resource": "*"
    }
  ]
}' > ssm-policy.json
aws iam create-policy --policy-name <SSM_POLICY> --policy-document file://ssm-policy.json
aws iam attach-user-policy --user-name <IAM_USER> --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/<SSM_POLICY>


Takeaway: Preconfigure SSM permissions for the IAM user to enable Session Manager access.

3. SSM Target Not Connected

Challenge: Session Manager returned TargetNotConnected and InvalidInstanceId errors when connecting to the EC2 instance.
Solution: 
Waited 5-10 minutes for the instance to register in SSM inventory.
Verified the EC2 instance had an IAM role (<SSM_ROLE>) with AmazonSSMManagedInstanceCore.
Confirmed the private subnet's route table had a NAT Gateway route for AWS API connectivity.
Ensured the EC2 security group allowed outbound HTTPS (port 443).

aws ssm describe-instance-information --region us-east-1
aws ec2 describe-route-tables --filters Name=vpc-id,Values=<VPC_ID>


Takeaway: Allow time for SSM registration and ensure network connectivity (NAT Gateway and security group rules).

4. EC2 Instance Connect Endpoint Configuration Issues

Challenge: Attempts to use EC2 Instance Connect Endpoint failed due to IAM permission errors (SendSSHPublicKey, OpenTunnel) and CLI inconsistencies (e.g., empty describe-vpc-endpoints output).
Solution: 
Created an IAM policy (<INSTANCE_CONNECT_POLICY>) with ec2-instance-connect:SendSSHPublicKey and ec2-instance-connect:OpenTunnel permissions.
Created the Endpoint in the AWS Console without subnet IDs, as it’s a VPC-level resource.
Reverted to Session Manager due to its simpler setup.

echo '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2-instance-connect:SendSSHPublicKey",
        "ec2-instance-connect:OpenTunnel"
      ],
      "Resource": [
        "arn:aws:ec2:us-east-1:<ACCOUNT_ID>:instance/*",
        "arn:aws:ec2:us-east-1:<ACCOUNT_ID>:instance-connect-endpoint/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus"
      ],
      "Resource": "*"
    }
  ]
}' > ec2-instance-connect-policy.json
aws iam create-policy --policy-name <INSTANCE_CONNECT_POLICY> --policy-document file://ec2-instance-connect-policy.json


Takeaway: Session Manager is more reliable for private subnet access; EC2 Instance Connect requires precise IAM and network setup.

5. DNS Propagation Delay for ALB

Challenge: Initial curl tests for the public ingress (/get) failed with Could not resolve host.
Solution: Waited 5-10 minutes for DNS propagation of the ALB hostname.curl http://<PUBLIC_ALB_URL>/get


Takeaway: Account for DNS propagation delays when testing ALBs.

Key Lessons for Redeployment

Configure aws-auth ConfigMap immediately after EKS creation.
Pre-attach IAM policies (<SSM_POLICY>, <INSTANCE_CONNECT_POLICY>) to the user and <SSM_ROLE> to EC2 instances.
Ensure private subnets have NAT Gateway routes and security groups allow outbound HTTPS.
Allow time for SSM registration and ALB DNS propagation.
Prefer Session Manager for private EC2 access due to its simplicity.