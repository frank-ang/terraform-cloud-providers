# Hashicorp Vault (Hault) Secrets Manager module

## Connecting to Hault endpoint via socks tunnel

If the host running Terraform does not have direct connectivity to the Hault endpoint, one solution is a socks tunnel through a bastion host.
* Create a reachable EC2 bastion host with connectivity to the EKS cluster.
* On the Terraform host, start a socks proxy connection to that bastion host.
    ```sh
    ssh -i $PEM_FILE -N -D 1080 ubuntu@$BASTION_HOST &
    ```
* On the Terraform host, configure environment to the proxy:
    ```sh
    export VAULT_SKIP_VERIFY=1
    export VAULT_HTTP_PROXY="socks5://localhost:1080"
    ```
* Terraform Vault Provider should now be able to successfully connect to vault, 
this is required to e.g. create secrets.
