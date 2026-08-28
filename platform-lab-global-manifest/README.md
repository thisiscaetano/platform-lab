# platform-lab-global-manifest

Repositório GitOps central do **platform-lab**. Contém todas as ArgoCD Applications que definem o estado desejado do cluster `lab` — desde a infraestrutura base até a aplicação de exemplo.

O ArgoCD monitora este repositório e reconcilia automaticamente qualquer desvio entre o que está no Git e o que está rodando no cluster.

---

## Visão Geral da Arquitetura

```
                        ┌─────────────────────────────────────────────┐
                        │              Cluster EKS (lab)               │
                        │                                              │
  Git Push ──► ArgoCD ──►  Istio  ──► Ingress ──► web-app             │
                        │                                              │
                        │  Karpenter ──► Node Provisioning (EC2)       │
                        │                                              │
                        │  Crossplane ──► DNS (Cloudflare)             │
                        │                                              │
                        │  Prometheus + Grafana + OTel ──► Observability│
                        │                                              │
                        │  External Secrets ──► AWS Secrets Manager    │
                        └─────────────────────────────────────────────┘
```

---

## Estrutura de Diretórios

```
platform-lab-global-manifest/
├── kustomization.yaml          ← App of Apps: lista todas as ArgoCD Applications
└── apps/
    ├── argocd/                 ← Self-managed ArgoCD
    ├── crossplane/             ← Provisionamento de infra via Crossplane
    │   ├── providers/          ← Instalação dos providers (Cloudflare)
    │   └── claims/             ← Recursos provisionados (DNS records)
    ├── external-secrets/       ← Sincronização de secrets com AWS Secrets Manager
    ├── istio/                  ← Service mesh + Ingress Gateway
    ├── karpenter/              ← Auto-scaling de nodes EC2
    ├── otel/                   ← OpenTelemetry Operator
    ├── prometheus/             ← kube-prometheus-stack (Prometheus + Grafana)
    ├── stakater-reloader/      ← Reload automático de pods ao mudar ConfigMap/Secret
    └── web-app/                ← Aplicação de exemplo
```

---

## App of Apps

O arquivo `kustomization.yaml` na raiz é o ponto de entrada. O ArgoCD aplica este arquivo no cluster e ele referencia todas as Applications abaixo:

| Application | Namespace | Fonte |
|---|---|---|
| argocd | argocd | Helm + manifests locais |
| external-secrets | external-secrets | Helm chart |
| istio-base / istiod / istio-ingressgateway | istio-system | Helm chart oficial Istio |
| karpenter | karpenter | Helm chart ECR público |
| opentelemetry-operator | obs | Helm chart |
| kube-prometheus-stack | obs | Helm chart |
| stakater | stakater | Helm chart |
| crossplane-providers | crossplane-system | Helm + manifests locais |
| crossplane-claims | crossplane-system | Manifests locais |
| web-app | web-app | Manifests locais |

---

## Apps

### ArgoCD

Self-managed: o próprio ArgoCD gerencia sua instalação via GitOps.

- Exposto em `argocd.paulojuniorsre.com.br` via Istio VirtualService
- Acesso anônimo habilitado (lab)
- Reconciliação a cada 10 segundos

---

### Istio

Service mesh responsável por todo o tráfego de entrada no cluster. Instalado em 3 waves:

| Wave | Application | O que faz |
|---|---|---|
| 0 | `istio-base` | CRDs base do Istio |
| 1 | `istiod` | Control plane (Pilot) |
| 2 | `istio-ingressgateway` | Load Balancer externo (AWS NLB) |

Um `Gateway` global (`istio-system/global-gateway`) roteia todo tráfego `*.paulojuniorsre.com.br` para os serviços internos via `VirtualService`.

---

### External Secrets

Sincroniza secrets do **AWS Secrets Manager** para o cluster Kubernetes.

- Usa IRSA (IAM Roles for Service Accounts) — sem credenciais hardcoded
- `ClusterSecretStore` configurado para `us-east-1`
- Service account `external-secrets-lab` com permissão via JWT/IRSA

---

### Crossplane

Provisionamento de infraestrutura como código via Kubernetes. Organizado em waves para respeitar a ordem de criação de CRDs:

```
Wave 1 → crossplane-install           Helm chart (CRDs do Crossplane)
Wave 2 → crossplane-provider-packages Provider packages (CRDs do Cloudflare)
Wave 3 → crossplane-provider-configs  ProviderConfigs + credenciais via ESO
Wave 5 → crossplane-claims-prd        Claims (provisionam recursos reais)
```

Atualmente gerencia DNS records no **Cloudflare**:
- `istio-ingressgateway-lab.paulojuniorsre.com.br` → NLB AWS (CNAME)
- `argocd.paulojuniorsre.com.br` → ingressgateway (CNAME)
- `grafana.paulojuniorsre.com.br` → ingressgateway (CNAME)
- `app.paulojuniorsre.com.br` → ingressgateway (CNAME)

---

### Karpenter

Auto-scaling de nodes EC2 baseado em demanda real de pods.

- **NodePool** `ondemand-pool`: instâncias `m5.xlarge`, `c5.xlarge`, `m5.2xlarge` nas AZs `us-east-1a/b/c`
- **EC2NodeClass** `ondemand`: AMI AL2023, disco `gp3` 50Gi encriptado, IMDSv2 obrigatório
- Consolidação automática de nodes ociosos após 5 minutos

---

### Prometheus + Grafana

Stack de observabilidade via `kube-prometheus-stack`.

- Grafana exposto em `grafana.paulojuniorsre.com.br` via Istio VirtualService
- Dashboards customizados carregados via sidecar (label `grafana_dashboard: "1"`)
- CRDs instalados separadamente (wave `-1`) para evitar race condition

---

### OpenTelemetry Operator

Gerencia `OpenTelemetryCollector` e `Instrumentation` no namespace `obs`.

- Certificado TLS gerado automaticamente (sem cert-manager)
- Pronto para receber traces/métricas/logs de aplicações instrumentadas

---

### Stakater Reloader

Monitora `ConfigMap` e `Secret` e reinicia automaticamente os pods que os utilizam quando há mudança — sem necessidade de restart manual.

---

### Web App

Aplicação de exemplo que demonstra o funcionamento da plataforma end-to-end.

- Imagem: `paulocjuniordevops/web:web`
- HPA configurado: 1–10 réplicas, escala com CPU/memória > 80%
- Exposta em `app.paulojuniorsre.com.br` via Istio VirtualService

---

## Fluxo GitOps

```
1. Desenvolvedor faz push/PR neste repositório
2. ArgoCD detecta a mudança (polling a cada 10s)
3. ArgoCD aplica os manifests no cluster lab
4. Sync automático com prune=true e selfHeal=true
```

Qualquer recurso criado manualmente no cluster que não esteja no Git será removido pelo ArgoCD (`prune: true`). Qualquer desvio do estado desejado é corrigido automaticamente (`selfHeal: true`).
