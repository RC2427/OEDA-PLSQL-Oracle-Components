# OEDA - Oracle EBS Deploy Assistant
Artifact Download Utility for Oracle EBS Application.

This Application will enable download of EBS code components like LDTs, WFX, template etc via a template driven app.

## OEDA ORACLE - Components
This repository contains the Oracle Components Required for the OEDA tool and the required tar file for container side of OEDA.

**========================================================================================**

## **Installation Guide for OEDA Backend and Frontend (Not Oracle Side)**

**1. Download the prebuilt images bundle**

curl -L -o oeda-stack-images.tar.gz
https://github.com/RC2427/OEDA-PLSQL-Oracle-Components/releases/download/v1.0.0/oeda-stack-images.tar

**2. Unpack everything**

tar xzf oeda-stack-images.tar.gz 

This will yield : oeda-stack-images.tar + docker-compose.yml + .env + vault/config/vault_config.hcl

**3. Load all Docker images**

docker load < oeda-stack-images.tar

**4. Start Vault**

docker-compose up -d vault

**5. Initialize Vault (5 keys, threshold 3)**

docker-compose exec vault vault operator init
-key-shares=5
-key-threshold=3 \

vault-init.txt

**6. Unseal Vault (use any 3 of the keys)**

for i in 1 2 3; do
KEY=$(grep "Unseal Key $i:" vault-init.txt | awk '{print $NF}')
docker-compose exec vault vault operator unseal $KEY
done

**7. Update .env with your Root Token**

Open .env and set:

VAULT_TOKEN=to_your_generated_vault_token

    i) Create a KV pair engine in the vault with the name 'Secrets'
    and default context 'oeda' 
    
    ii) Under oeda have jwt-secret and postgres-password defined so 
    that backend can pick it up.

    iii) Under a new context have oeda/your_ords_instance_name define
    ords client secret.

**8. Start the backend & frontend**

docker-compose up -d backend frontend

**9. Rotate your PostgreSQL password in Vault**

(Do NOT continue using the initial password in .env)

docker-compose exec vault vault kv put Secrets/oeda

postgres-password="<YOUR_NEW_STRONG_PASSWORD>"

**10. Restart the backend so it picks up the new DB password**

docker-compose restart backend

(NOTE : From the next release valut engine name, valut context will be configurable as well as the path of the ORDS secrets.

P.S Was to lazy change the default setup in application properties since I had already made the tar file and setup the relase for v.0.0.1 and it was already 2 AM so ... will see if actually do it in the next release)
**========================================================================================**
