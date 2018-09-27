# GLX rendering using containers in Azure 

## Intro
Virtual machines with GPU cost is compartible high, so idea to share GPU resource to render in a container looks great.
But we have a challenge, NVIDIA docker runtime does not support GLX rendering which is normaly used in most cases.
But we can connect to a host X server and enable GLX render on it. NVIDIA has a good example of how to do it https://gitlab.com/nvidia/samples/blob/master/opengl/ubuntu16.04/glxgears/Dockerfile. So let's try to implement it in Azure using Ubuntu Server 16.04-LTS as a base image.

## Install all
So we need the following on our VM:
- Ubuntu Server 16.04-LTS
- NVIDIA drivers
- Docker
- NVIDIA docker
- X server

At first, let's create VM with Ubuntu. You can use Azure Portal or Azure CLI. I like Azure CLI, so will use it.
We create azureglxrendering-rg Azure Resource Group in East US region and then create VM based on Ubuntu with Standrad_NV6 sku and generate ssh keys for simplicity. You can pass you own keys using --ssh-key-value param, if you don't specify any params, your default key will be used, if you specify --generate-ssh-keys and you already have a key it will be used. 

```
az group create -n azureglxrendering-rg -l eastus
az vm create -n azureglxrendering -g azureglxrendering-rg --public-ip-address-dns-name azureglxrendering \
            --image Canonical:UbuntuServer:16.04-LTS:latest --size Standard_NV6 \
            --generate-ssh-keys
```
Please, use you own public dns name :) for --public-ip-address-dns-name

By default when you create VM from Azure CLI SSH port opens, if you create VM from Azure Portal, you should add this rule manualy, as by default all external communications ports are disabled.

By default when you create VM from Azure CLI local user name uses for admin user name. You can pass any name using --admin-username param.

Connect to the created VM by ssh:
```
stas@MININT-O4Q5751:~$ ssh stas@azureglxrendering.eastus.cloudapp.azure.com
The authenticity of host 'azureglxrendering.eastus.cloudapp.azure.com (XX.XX.XX.XX)' can't be established.
ECDSA key fingerprint is SHA256:lXdWDwQd6GgbzZ7F1TaEQxD/LsAJhddpO4FXPNChg9w.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added 'azureglxrendering.eastus.cloudapp.azure.com,XX.XX.XX.XX' (ECDSA) to the list of known hosts.
Enter passphrase for key '/home/stas/.ssh/id_rsa':
Welcome to Ubuntu 16.04.5 LTS (GNU/Linux 4.15.0-1023-azure x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  Get cloud support with Ubuntu Advantage Cloud Guest:
    http://www.ubuntu.com/business/services/cloud

0 packages can be updated.
0 updates are security updates.



The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

stas@azureglxrendering:~$
```
Ok, so we are in. Let's check that NVIDIA is here.
```
stas@azureglxrendering:~$ lspci|grep NVIDIA
50c1:00:00.0 VGA compatible controller: NVIDIA Corporation GM204GL [Tesla M60] (rev a1)
```
Good. So now we need to install drivers. Detailed instructions can be found here https://docs.microsoft.com/en-us/azure/virtual-machines/linux/n-series-driver-setup. Or you can use extention on Azure Portal or Azure CLI. I prefer to use extention. Disconnect from the VM and return to Azure CLI.
```
az vm extension set  \
  --resource-group azureglxrendering-rg  \
  --vm-name azureglxrendering  \
  --name NvidiaGpuDriverLinux  \
  --publisher Microsoft.HpcCompute  \
  --version 1.1  \
  --settings '{  }'
```