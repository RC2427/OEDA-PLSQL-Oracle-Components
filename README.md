# OEDA - Oracle EBS Deploy Assistant
Artifact Download Utility for Oracle EBS Application.

This Application will enable download of EBS code components like LDTs, WFX, template etc via a template driven app.

## OEDA ORACLE - Components
This repository contains the Oracle Components Required for the OEDA tool and the required tar file for container side of OEDA.

## **Installation Guide for OEDA Backend and Frontend (Not Oracle Side)**

**1. Download the prebuilt images bundle**

    curl -L -o OEDA-RELEASE.7z https://github.com/RC2427/OEDA-PLSQL-Oracle-Components/releases/download/v.0.0.1/OEDA_PROJECT.7z

**2. Unpack everything**

    unzip OEDA-RELEASE.zip
    cd OEDA-RELEASE

This will yield : oeda-stack-images.tar + docker-compose.yml + .env + vault + configure-env.bat/configure-env.sh

**3. Run BAT or SH file to set environment variables**

     configure-env.bat

              or

     ./configure-env.sh

**3. Load all Docker images**

    docker pull hashicorp/vault:latest && docker pull postgres:15-alpine && docker compose build

**4. Start Vault**

    docker-compose up -d vault

**5.Initialize the Vault**

    Go to vault using your set VAULT_API_ADDR.
    Initialize the Vault and generated 5 keys with 3 threshold (3 keys to unlock) 
    or generate as per requirement.
    Make sure to save the root token.

**6. Unseal Vault (use any 3 of the keys)**

    Unseal the vault using any 3 of the generated keys.
    Use Root Token to login the first time.

**7. Update .env with your Root Token**

    Open .env and set:
    
    VAULT_TOKEN=to_your_generated_vault_token

    In your vault do the following : 
 
      i) Create a KV pair engine in the vault with the name 'Secrets'
      and default context 'oeda' 
      
      ii) Under oeda have jwt-secret and postgres-password defined so 
      that backend can pick it up.
  
      iii) Under a new context have oeda/your_ords_instance_name define
      ords client secret.

**8. Start the backend & frontend**

    docker-compose up -d backend frontend

**10. (OPTIONAL) Restart the backend or frontend in case you had not setup the vault before**

    docker-compose restart backend

(NOTE : From the next release vault engine name, valut context will be configurable as well as the path of the ORDS secrets.

P.S Was to lazy change the default setup in application properties since I had already made the ZIP file and setup the release for v.0.0.1 and it was already 2 AM so ... will see if I actually do it in the next release)
