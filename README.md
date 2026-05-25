# DevOps Infrastructure & Automation — Ansible + Terraform + GitHub Actions

> **Module** : DevOps — Culture, Practices and Tools (CI/CD, IaC, Observability, Security)  
> **Niveau** : Master 1 Architecte Logiciel & Développeur  
> **Année** : 2026

---

## Table des matières

1. [Architecture globale](#1-architecture-globale)
2. [Stack technologique](#2-stack-technologique)
3. [Structure du projet](#3-structure-du-projet)
4. [Prérequis](#4-prérequis)
5. [Configuration des VMs VirtualBox](#5-configuration-des-vms-virtualbox)
6. [Setup du contrôleur Ubuntu](#6-setup-du-contrôleur-ubuntu)
7. [Setup du nœud Windows 11 (WinRM)](#7-setup-du-nœud-windows-11-winrm)
8. [Configuration du GitHub Actions Runner](#8-configuration-du-github-actions-runner)
9. [Variables dynamiques et Terraform](#9-variables-dynamiques-et-terraform)
10. [Lancer le pipeline](#10-lancer-le-pipeline)
11. [Description détaillée des jobs CI/CD](#11-description-détaillée-des-jobs-cicd)
12. [Playbooks Ansible](#12-playbooks-ansible)
13. [Résolution de problèmes](#13-résolution-de-problèmes)

---

## 1. Architecture globale

```
┌─────────────────────────────────────────────────────────────────┐
│                      GitHub Repository                          │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │  Ansible         │    │  Terraform        │                   │
│  │  Playbooks       │    │  + Jinja2 TPL     │                   │
│  └──────────────────┘    └──────────────────┘                   │
│           │ push to main        │                               │
│           └────────┬────────────┘                               │
│                    ▼                                            │
│         GitHub Actions Pipeline                                 │
└────────────────────┬────────────────────────────────────────────┘
                     │ triggers (self-hosted runner)
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│              VirtualBox — Host Machine                          │
│                                                                 │
│  ┌──────────────────────────────────┐                           │
│  │   Ubuntu VM  (192.168.56.100)    │  ← Ansible Controller     │
│  │   + GitHub Actions Runner        │  ← CI/CD Executor         │
│  │   + Terraform                    │  ← IaC Engine             │
│  └──────────┬───────────────────────┘                           │
│             │ SSH (port 22)                                      │
│             ▼                                                   │
│  ┌──────────────────────────┐                                   │
│  │  Ubuntu Node             │  ← Managed Node Linux             │
│  │  192.168.56.101          │                                   │
│  └──────────────────────────┘                                   │
│             │ WinRM (port 5985)                                  │
│             ▼                                                   │
│  ┌──────────────────────────┐                                   │
│  │  Windows 11 VM           │  ← Managed Node Windows           │
│  │  192.168.56.102          │                                   │
│  └──────────────────────────┘                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Flux d'exécution

```
push → main
  │
  ├─► Job 1: Terraform
  │     └─ Génère inventory/hosts.ini + group_vars depuis templates .tpl
  │
  ├─► Job 2: Gather Facts (localhost)
  │     └─ Ansible collecte les informations système du contrôleur
  │
  ├─► Job 3: Timezone Linux
  │     ├─ Applique Europe/Paris sur Ubuntu Node
  │     ├─ Vérifie le changement
  │     └─ Applique Africa/Abidjan (GMT) sur Ubuntu Node
  │
  └─► Job 4: Timezone Windows
        ├─ Teste la connexion WinRM
        ├─ Applique "Romance Standard Time" (Europe/Paris)
        ├─ Vérifie le changement
        └─ Applique "Greenwich Standard Time" (Africa/Abidjan)
```

---

## 2. Stack technologique

| Composant | Technologie | Version |
|-----------|-------------|---------|
| Hyperviseur | VirtualBox | 7.x |
| OS Contrôleur | Ubuntu 22.04 LTS | - |
| OS Nœud Linux | Ubuntu 22.04 LTS | - |
| OS Nœud Windows | Windows 11 | - |
| Automation | Ansible | 2.16+ |
| IaC | Terraform | 1.7.0 |
| CI/CD | GitHub Actions | - |
| Runner | Self-hosted (local) | - |
| Protocole Windows | WinRM / HTTP (5985) | - |

---

## 3. Structure du projet

```
devops-project/
├── .github/
│   └── workflows/
│       └── devops-pipeline.yml      # Pipeline GitHub Actions
│
├── terraform/
│   ├── main.tf                      # Ressources Terraform
│   ├── variables.tf                 # Déclaration des variables
│   ├── terraform.tfvars             # Valeurs locales (IPs, users)
│   └── templates/
│       ├── inventory.ini.tpl        # Template Jinja2 → hosts.ini
│       ├── group_vars_all.yml.tpl   # Template → group_vars/all.yml
│       └── group_vars_windows.yml.tpl
│
├── ansible/
│   ├── playbooks/
│   │   ├── 01_gather_facts.yml      # Facts sur le contrôleur
│   │   ├── 02_timezone_linux.yml    # Timezone Ubuntu Node
│   │   ├── 03_gather_facts_windows.yml
│   │   └── 04_timezone_windows.yml  # Timezone Windows via WinRM
│   ├── roles/
│   │   └── timezone/
│   │       ├── tasks/main.yml
│   │       ├── handlers/main.yml
│   │       └── defaults/main.yml
│   ├── group_vars/                  # Générés par Terraform (gitignored)
│   └── requirements.yml            # Collections Ansible Galaxy
│
├── inventory/
│   └── hosts.ini                    # Généré par Terraform (gitignored)
│
├── docs/
│   ├── setup_ubuntu_controller.sh  # Script setup contrôleur
│   └── setup_winrm.ps1             # Script setup WinRM Windows
│
├── ansible.cfg
├── .gitignore
└── README.md
```

---

## 4. Prérequis

- Machine hôte avec au moins **16 GB RAM** et **4 CPU cores**
- **VirtualBox 7.x** installé
- Compte **GitHub** avec un dépôt créé
- **ISO Ubuntu 22.04** : https://ubuntu.com/download/server
- **ISO Windows 11** : https://www.microsoft.com/software-download/windows11

---

## 5. Configuration des VMs VirtualBox

### Réseau recommandé

Créer un réseau **Host-Only** dans VirtualBox :
- Fichier → Gestionnaire de réseau hôte → Créer
- IPv4 : `192.168.56.1/24`
- Désactiver le serveur DHCP (IPs fixes manuellement)

### VM Ubuntu Controller (192.168.56.100)
| Paramètre | Valeur |
|-----------|--------|
| RAM | 4 GB |
| CPU | 2 cores |
| Disque | 30 GB |
| Réseau 1 | NAT (accès internet) |
| Réseau 2 | Host-Only (192.168.56.100) |

### VM Ubuntu Node (192.168.56.101)
| Paramètre | Valeur |
|-----------|--------|
| RAM | 2 GB |
| CPU | 1 core |
| Disque | 20 GB |
| Réseau 1 | NAT |
| Réseau 2 | Host-Only (192.168.56.101) |

### VM Windows 11 (192.168.56.102)
| Paramètre | Valeur |
|-----------|--------|
| RAM | 4 GB |
| CPU | 2 cores |
| Disque | 60 GB |
| Réseau 1 | NAT |
| Réseau 2 | Host-Only (192.168.56.102) |

---

## 6. Setup du contrôleur Ubuntu

```bash
# Sur la VM Ubuntu Controller
git clone https://github.com/<votre-user>/<votre-repo>.git
cd devops-project

chmod +x docs/setup_ubuntu_controller.sh
./docs/setup_ubuntu_controller.sh
```

Le script installe automatiquement : Ansible, Terraform, Python3/pywinrm, crée l'utilisateur `ansible` et génère la paire de clés SSH.

### Copier la clé SSH vers le nœud Ubuntu

```bash
ssh-copy-id -i ~/.ssh/ansible_key.pub ansible@192.168.56.101
```

### Tester la connexion

```bash
ansible linux_hosts -i inventory/hosts.ini -m ping
```

---

## 7. Setup du nœud Windows 11 (WinRM)

Sur la VM Windows 11, ouvrir **PowerShell en tant qu'Administrateur** :

```powershell
# Autoriser l'exécution de scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

# Exécuter le script de configuration WinRM
.\docs\setup_winrm.ps1
```

### Tester la connexion WinRM depuis le contrôleur

```bash
ansible windows_hosts -i inventory/hosts.ini -m ansible.windows.win_ping
```

---

## 8. Configuration du GitHub Actions Runner

1. Aller dans votre dépôt GitHub → **Settings → Actions → Runners**
2. Cliquer **New self-hosted runner** → Linux / x64
3. Suivre les instructions affichées (download + configure)
4. Lors de la configuration, utiliser ces labels : `self-hosted,linux,ansible`

```bash
# Installer comme service systemd
sudo ./svc.sh install
sudo ./svc.sh start

# Vérifier le statut
sudo ./svc.sh status
```

Le runner apparaît alors comme **Idle** dans GitHub → Settings → Actions → Runners.

---

## 9. Variables dynamiques et Terraform

### Variables d'environnement GitHub (Settings → Variables/Secrets)

| Nom | Type | Valeur exemple |
|-----|------|----------------|
| `UBUNTU_HOST_IP` | Variable | `192.168.56.101` |
| `WINDOWS_HOST_IP` | Variable | `192.168.56.102` |
| `ANSIBLE_USER_LINUX` | Variable | `ansible` |
| `ANSIBLE_USER_WINDOWS` | Variable | `ansible` |
| `SSH_KEY_PATH` | Variable | `~/.ssh/ansible_key` |
| `WINRM_PASSWORD` | **Secret** | `AnsiblePass123!` |

### Génération de l'inventaire par Terraform

Terraform lit les variables → applique les templates Jinja2 → génère :

```
inventory/hosts.ini          # Inventaire Ansible complet
ansible/group_vars/all.yml   # Variables globales (timezones, etc.)
ansible/group_vars/windows_hosts.yml  # Credentials WinRM
```

### Déclencher avec des timezones personnalisées

Via **workflow_dispatch** dans GitHub Actions :
- `ansible_target` : `all` | `linux` | `windows`
- `timezone_first` : ex. `Europe/Paris`
- `timezone_second` : ex. `Africa/Abidjan`

---

## 10. Lancer le pipeline

```bash
# Méthode 1 : push sur main
git add .
git commit -m "feat: configure timezone automation"
git push origin main

# Méthode 2 : déclenchement manuel
# GitHub → Actions → DevOps Pipeline → Run workflow
```

---

## 11. Description détaillée des jobs CI/CD

### Job 1 — Terraform: Generate Inventory
- Initialise et valide la configuration Terraform
- Génère `inventory/hosts.ini` depuis `inventory.ini.tpl`
- Génère `group_vars/all.yml` depuis `group_vars_all.yml.tpl`
- Publie l'inventaire comme artifact pour les jobs suivants

### Job 2 — Ansible: Gather Facts (localhost)
- Collecte les informations système du contrôleur (CPU, RAM, OS, IP, timezone)
- Génère un rapport dans `/tmp/controller_facts_report.txt`
- Publie le rapport comme artifact GitHub Actions

### Job 3 — Ansible: Timezone Linux
- Applique `Europe/Paris` sur le nœud Ubuntu
- Vérifie via `timedatectl`
- Applique `Africa/Abidjan` sur le nœud Ubuntu
- Vérifie de nouveau avec assertion

### Job 4 — Ansible: Timezone Windows
- Teste la connectivité WinRM (`win_ping`)
- Collecte les facts Windows
- Applique `Romance Standard Time` (Europe/Paris)
- Applique `Greenwich Standard Time` (Africa/Abidjan)
- Vérifie via PowerShell `Get-TimeZone`

---

## 12. Playbooks Ansible

### Test manuel d'un playbook

```bash
# Gather facts localhost
ansible-playbook -i inventory/hosts.ini ansible/playbooks/01_gather_facts.yml

# Timezone Linux (Paris)
ansible-playbook -i inventory/hosts.ini ansible/playbooks/02_timezone_linux.yml \
  -e "target_timezone=Europe/Paris"

# Timezone Linux (Abidjan)
ansible-playbook -i inventory/hosts.ini ansible/playbooks/02_timezone_linux.yml \
  -e "target_timezone=Africa/Abidjan"

# Timezone Windows (Paris)
ansible-playbook -i inventory/hosts.ini ansible/playbooks/04_timezone_windows.yml \
  -e "target_timezone=Europe/Paris"
```

---

## 13. Résolution de problèmes

### Connexion SSH refusée
```bash
# Vérifier que l'utilisateur ansible existe sur le nœud
ssh ansible@192.168.56.101 -i ~/.ssh/ansible_key

# Vérifier les permissions de la clé
chmod 600 ~/.ssh/ansible_key
```

### WinRM connection timeout
```powershell
# Sur Windows, vérifier que WinRM écoute
netstat -an | findstr 5985

# Redémarrer le service
Restart-Service WinRM
```

### Le pipeline s'exécute sur un runner partagé GitHub
Vérifier que le job contient bien `runs-on: self-hosted` dans le workflow YAML, et que le runner local est bien en statut **Idle** dans GitHub Settings.

### Terraform ne trouve pas les templates
```bash
ls -la terraform/templates/
# Vérifier les chemins dans main.tf
```
