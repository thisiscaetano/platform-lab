# EKS - platform-lab

Provisiona um cluster EKS com addons gerenciados e ArgoCD via Helm.

## O que é criado

- Cluster EKS `platform-lab` (Kubernetes 1.36)
- Node group gerenciado: AL2023, instâncias `m6i.large` / `c6a.large` (2–4 nós)
- EKS Auto Mode com node pool `general-purpose`
- Addons: `vpc-cni`, `coredns`, `kube-proxy`, `aws-ebs-csi-driver`, `aws-efs-csi-driver`, `eks-pod-identity-agent`
- IAM Roles via Pod Identity para EBS e EFS CSI drivers
- ArgoCD (chart `argo-cd` v10.4.0) no namespace `argocd`

## Node Group — Label e Taint

O node group `default` possui uma **label** e um **taint** configurados para isolar cargas de trabalho de sistema.

### Label

```hcl
labels = {
  "node-type" = "system"
}
```

Labels são metadados chave-valor atribuídos aos nós. Elas permitem que pods sejam direcionados a nós específicos usando `nodeSelector` ou `nodeAffinity`. Neste caso, qualquer pod que declare `nodeSelector: node-type: system` será elegível para rodar nesses nós.

### Taint

```hcl
taints = {
  dedicated = {
    key    = "node-type"
    value  = "system"
    effect = "NO_SCHEDULE"
  }
}
```

Taints funcionam como o inverso das labels: em vez de atrair pods, eles **repelem**. Com `NO_SCHEDULE`, nenhum pod será agendado nesses nós a menos que tenha uma **toleration** correspondente. Isso garante que apenas componentes de sistema (addons, controllers) rodem nesses nós, evitando que workloads de aplicação consumam esses recursos.

Para um pod tolerar esse taint:

```yaml
tolerations:
  - key: "node-type"
    operator: "Equal"
    value: "system"
    effect: "NoSchedule"
```

## Addons

Todos os addons com controllers (`coredns`, `aws-ebs-csi-driver`, `aws-efs-csi-driver`) são configurados com `tolerations` e `nodeSelector` apontando para os nós `node-type: system`, garantindo que rodem nos nós dedicados de sistema.

| Addon | Descrição | Configuração extra |
|-------|-----------|-------------------|
| `coredns` | DNS interno do cluster | `nodeSelector` + `toleration` para nós `system` |
| `kube-proxy` | Gerencia regras de rede nos nós | — |
| `vpc-cni` | Plugin de rede da AWS (IPs nativos da VPC) | `before_compute=true`, toleration `operator: Exists` |
| `eks-pod-identity-agent` | Permite que pods assumam IAM roles via Pod Identity | `before_compute=true`, toleration `operator: Exists` |
| `aws-ebs-csi-driver` | Provisiona volumes EBS como PersistentVolumes | Pod Identity + `nodeSelector`/`toleration` no controller |
| `aws-efs-csi-driver` | Provisiona volumes EFS como PersistentVolumes | Pod Identity + `nodeSelector`/`toleration` no controller |

> `before_compute = true` garante que `vpc-cni` e `eks-pod-identity-agent` sejam instalados antes dos nós subirem, evitando problemas de rede e identidade na inicialização.

### Toleration `operator: Exists` — vpc-cni e eks-pod-identity-agent

```yaml
tolerations:
  - operator: "Exists"
```

Quando `operator: Exists` é usado sem `key`, o pod tolera **qualquer taint** do cluster, independente de chave, valor ou efeito. Isso é intencional para esses dois addons:

- `vpc-cni` precisa rodar em **todos os nós** para configurar a rede antes que qualquer outro pod seja agendado. Se não tolerasse o taint `node-type=system:NoSchedule`, os nós de sistema ficariam sem rede e nenhum pod subiria neles.
- `eks-pod-identity-agent` roda como **DaemonSet** e precisa estar presente em todos os nós para interceptar requisições de credenciais. Se ficasse fora de algum nó, pods naquele nó não conseguiriam assumir IAM roles.

Diferente dos outros addons que usam `operator: Equal` para tolerar apenas o taint específico de sistema, esses dois precisam da toleration ampla para garantir cobertura total do cluster.

### Pod Identity (EBS e EFS)

Em vez de usar IRSA (IAM Roles for Service Accounts via OIDC), os CSI drivers utilizam **EKS Pod Identity**, que associa diretamente uma IAM Role a uma Service Account sem depender de anotações no pod. As roles criadas permitem que o principal `pods.eks.amazonaws.com` assuma a role via `sts:AssumeRole` e `sts:TagSession`.

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

Estado armazenado remotamente no S3. Configure o arquivo `backend.hcl` com os valores do seu ambiente antes de rodar o `terraform init`