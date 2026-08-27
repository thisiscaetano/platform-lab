# EKS - platform-lab

Provisiona um cluster EKS com addons gerenciados e ArgoCD via Helm.

## O que é criado

- Cluster EKS `platform-lab` (Kubernetes 1.36)
- Node group gerenciado: AL2023, instâncias `m6i.large` / `c6a.large` (2–4 nós)
- EKS Auto Mode com node pool `general-purpose`
- Addons: `vpc-cni`, `coredns`, `kube-proxy`, `aws-ebs-csi-driver`, `aws-efs-csi-driver`, `eks-pod-identity-agent`
- IAM Roles via Pod Identity para EBS e EFS CSI drivers
- ArgoCD (chart `argo-cd` v10.4.0) no namespace `argocd`

## Pré-requisitos

- Terraform >= 1.x
- AWS CLI configurado
- VPC e subnets privadas existentes

## Variáveis

| Nome | Descrição | Default |
|------|-----------|---------|
| `cluster_name` | Nome do cluster | `platform-lab` |
| `cluster_version` | Versão do Kubernetes | `1.36` |
| `aws_region` | Região AWS | `us-east-1` |
| `vpc_id` | ID da VPC | `""` |
| `private_subnet_ids` | Lista de subnets privadas | `["", ""]` |

## Outputs

| Nome | Descrição |
|------|-----------|
| `cluster_name` | Nome do cluster |
| `cluster_endpoint` | Endpoint da API do cluster |
| `cluster_certificate_authority_data` | CA do cluster |
| `oidc_provider_arn` | ARN do OIDC provider |

## Uso

```bash
# Inicializar com backend remoto
terraform init -backend-config=backend.hcl

# Planejar
terraform plan -var="vpc_id=vpc-xxxx" -var='private_subnet_ids=["subnet-aaa","subnet-bbb"]'

# Aplicar
terraform apply -var="vpc_id=vpc-xxxx" -var='private_subnet_ids=["subnet-aaa","subnet-bbb"]'
```

## Backend

Estado armazenado no S3:
