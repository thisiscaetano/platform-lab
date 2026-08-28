# Crossplane — Estrutura GitOps

## Visão Geral

O Crossplane está dividido em **5 ArgoCD Applications**, aplicadas em ordem via sync-waves. A separação existe porque cada camada depende da anterior registrar CRDs no cluster antes de prosseguir.

```
apps/crossplane/
├── providers/
│   ├── base/
│   │   ├── packages/   #   Provider packages (instalam as CRDs de cada cloud)
│   │   └── configs/    #   ProviderConfigs + ExternalSecrets
│   └── overlays/prd/
│       ├── packages/   #   kustomization apontando para base/packages
│       └── configs/    #   kustomization apontando para base/configs
├── compositions/       #   XRDs + Compositions
└── claims/
    └── overlays/
        ├── dev/        #   claims do ambiente dev
        └── prd/        #   claims do ambiente prd
```

---

## Ordem de aplicação (sync-waves)

```
Wave 1 → crossplane-install           Helm chart → instala CRDs do Crossplane (pkg.crossplane.io)
Wave 2 → crossplane-provider-packages Provider packages → instala CRDs de AWS/Azure/Cloudflare
Wave 3 → crossplane-provider-configs  ProviderConfigs + ExternalSecrets (dependem das CRDs da wave 2)
Wave 4 → crossplane-compositions      XRDs + Compositions
Wave 5 → crossplane-claims-prd        Claims (provisionam recursos na cloud)
```

Cada wave só inicia quando a anterior está `Healthy` no ArgoCD.  
Essa ordem é obrigatória — cada camada depende das CRDs registradas pela camada anterior.

---

## 1. providers/

**O que faz:** Instala o Crossplane e configura os providers de cada cloud em 3 etapas separadas.  
Os recursos são definidos em `base/` e são iguais em qualquer cluster.

```
providers/
├── base/
│   ├── packages/                      ← só os Provider packages (sem ProviderConfig)
│   │   ├── kustomization.yaml
│   │   └── cloudflare/
│   │       └── provider.yaml
│   └── configs/                       ← ProviderConfigs + ExternalSecrets
│       ├── kustomization.yaml
│       └── cloudflare/
│           ├── providerconfig.yaml
│           └── external-secret.yaml   ← credenciais via ESO → Azure Key Vault
└── overlays/
    └── prd/
        ├── application.yaml           ← 3 ArgoCD Applications (waves 1, 2 e 3)
        ├── packages/
        │   └── kustomization.yaml     ← resources: ../../../base/packages
        └── configs/
            └── kustomization.yaml     ← resources: ../../../base/configs
```

**Por que packages e configs separados?**  
Os `Provider` packages, quando instalados, registram as CRDs de `ProviderConfig` (ex: `aws.upbound.io/ProviderConfig`). Se aplicados juntos, o ArgoCD tenta criar o `ProviderConfig` antes da CRD existir e falha.

**Para adicionar um novo provider** (ex: GCP):
1. Criar `providers/base/packages/gcp/provider-family.yaml` e `provider.yaml`
2. Criar `providers/base/configs/gcp/providerconfig.yaml`
3. Referenciar nos `kustomization.yaml` de `packages/` e `configs/`

**Para adicionar um novo cluster no futuro:**
1. Criar `providers/overlays/<nome-do-cluster>/packages/` e `configs/`
2. Criar `application.yaml` com as 3 Applications apontando para o cluster correto

---

## 2. compositions/

**O que faz:** Define os tipos de recursos customizados (`XRD`) e como criá-los (`Composition`).  
São cluster-scoped e não variam por ambiente.

```
compositions/
├── application.yaml               ← ArgoCD Application (wave 4)
├── kustomization.yaml
├── functions/
│   └── function-patch-and-transform.yaml
├── aws-rds-postgres/
│   ├── xrd.yaml                   ← define o tipo PostgresInstance
│   └── composition.yaml           ← cria SubnetGroup + RDS Instance na AWS
└── azure-storage/
    ├── xrd.yaml                   ← define o tipo StorageAccount
    └── composition.yaml           ← cria Storage Account + Blob Container no Azure
```

**Para adicionar uma nova Composition** (ex: S3 bucket):
1. Criar pasta `compositions/aws-s3/`
2. Criar `xrd.yaml` e `composition.yaml`
3. Adicionar as 2 entradas no `kustomization.yaml`

> **Regra:** Nunca coloque Claims aqui. XRD e Composition são a "API" — o Claim é o "uso da API".

---

## 3. claims/

**O que faz:** Pedidos concretos de recursos. Um Claim = "quero um PostgreSQL com esses parâmetros".  
Separado por ambiente. **É aqui que o Backstage cria arquivos via Software Templates.**

```
claims/
└── overlays/
    ├── dev/
    │   ├── application.yaml       ← ArgoCD Application (wave 5)
    │   ├── kustomization.yaml
    │   └── record.yaml            ← DNS records Cloudflare (dev)
    └── prd/
        ├── application.yaml       ← ArgoCD Application (wave 5)
        ├── kustomization.yaml
        ├── record.yaml            ← DNS records Cloudflare (prd)
        └── shared-postgres.yaml   ← RDS PostgreSQL compartilhado (Keycloak + Backstage)
```

**Para provisionar um novo recurso via Backstage:**
1. Template do Backstage cria um PR adicionando um `.yaml` em `claims/overlays/prd/`
2. PR aprovado → ArgoCD detecta → aplica o Claim
3. Crossplane lê o Claim → consulta a Composition → provisiona na AWS/Azure

**Para provisionar manualmente:**
1. Criar um `.yaml` com o `kind` do tipo registrado (ex: `PostgresInstance`)
2. Adicionar no `kustomization.yaml` do ambiente
3. Fazer PR → merge → ArgoCD aplica