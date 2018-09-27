# GLX rendering using containers in Azure 

## Intro
Virtual machines with GPU cost is compartible high, so idea to share GPU resource to render in a container looks great.
But we have a challenge, NVIDIA docker runtime does not support GLX rendering which is normaly used in most cases.
But we can connect to a host X server and enable GLX render on it. NVIDIA has a good example of how to do it https://gitlab.com/nvidia/samples/blob/master/opengl/ubuntu16.04/glxgears/Dockerfile. So let's try to implement it in Azure using Ubuntu Server 16.04-LTS as a base image.

## Install it all
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
Please, use you own public dns name for --public-ip-address-dns-name

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
Good. So now we need to install drivers. Detailed instructions can be found here https://docs.microsoft.com/en-us/azure/virtual-machines/linux/n-series-driver-setup. 
```
CUDA_REPO_PKG=cuda-repo-ubuntu1604_9.1.85-1_amd64.deb

wget -O /tmp/${CUDA_REPO_PKG} http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/${CUDA_REPO_PKG} 

sudo dpkg -i /tmp/${CUDA_REPO_PKG}

sudo apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub 

rm -f /tmp/${CUDA_REPO_PKG}

sudo apt-get update -y

sudo apt-get install cuda-drivers -y
```
Wait until the installation ends and check that the drivers installed correctly:
```
stas@MININT-O4Q5751:~$ ssh stas@azureglxrendering.eastus.cloudapp.azure.com
...
stas@azureglxrendering:~$ nvidia-smi
Thu Sep 27 13:02:37 2018
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 410.48                 Driver Version: 410.48                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla M60           Off  | 000050C1:00:00.0 Off |                  Off |
| N/A   39C    P0    37W / 150W |      0MiB /  8129MiB |      1%      Default |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID   Type   Process name                             Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+

```
So the drivers succesfully installed. We need to install docker and nvidia-docker. You can find detailed instruction how to install docker on Ubuntu here: https://docs.docker.com/install/linux/docker-ce/ubuntu/#install-using-the-repository and I just copy-pasted it for you here:
```
sudo apt-get update -y

sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo apt-key fingerprint 0EBFCD88

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt-get update -y

sudo apt-get install docker-ce -y

sudo usermod -aG docker $USER
```
Last command added you to the docker group so you don't need to sudo to run it. To make it effective login/logoff from VM (exit SSH session, connect again). So now let's do simple test that docker installed correctly:
```
stas@azureglxrendering:~$ docker run hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
d1725b59e92d: Pull complete
Digest: sha256:0add3ace90ecb4adbf7777e9aacf18357296e799f81cabc9fde470971e499788
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/
```
If you see something like above, you on the right way. You can find detailed instruction how to install nvidia-docker2 on Ubuntu here: https://github.com/nvidia/nvidia-docker/wiki/Installation-(version-2.0) and I just copy-pasted it for you here:
```
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey|sudo apt-key add -

distribution=$(. /etc/os-release;echo $ID$VERSION_ID)

curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list|sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update -y

sudo apt-get install nvidia-docker2 -y

sudo pkill -SIGHUP dockerd
```
Last command we use to restart docker so we can use nvidia-docker runtume immidiatelly. Let's use it!
```
stas@azureglxrendering:~$ docker run --runtime=nvidia --rm nvidia/cuda nvidia-smi
Unable to find image 'nvidia/cuda:latest' locally
latest: Pulling from nvidia/cuda
124c757242f8: Pull complete
9d866f8bde2a: Pull complete
fa3f2f277e67: Pull complete
398d32b153e8: Pull complete
afde35469481: Pull complete
2daa37007a29: Pull complete
5499acc0a3fa: Pull complete
3510706284f2: Pull complete
c7aca7b79a5d: Pull complete
Digest: sha256:ccd45db16ba6c3236cedde93120d16cd12163e95f337450414ecd022b489ac84
Status: Downloaded newer image for nvidia/cuda:latest
Thu Sep 27 13:05:50 2018
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 410.48                 Driver Version: 410.48                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla M60           Off  | 000050C1:00:00.0 Off |                  Off |
| N/A   40C    P0    38W / 150W |      0MiB /  8129MiB |      3%      Default |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID   Type   Process name                             Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
```
So now we ready to start X server. For demo purposes and simplicity I use parameters to disable authentication for X server. You can consider other way of starting X server and connecting to them from containers. Please see this document: http://wiki.ros.org/docker/Tutorials/GUI#The_simple_way. All the needed stuff should be installed during previous installaton. So let's configure our X server to use GPU acceleration and possibility to start from anybody.

```
sudo nvidia-xconfig --busid `nvidia-xconfig --query-gpu-info | grep BusID | sed 's/PCI BusID : PCI:/PCI:/'`

sudo sed -i 's/console/anybody/g'  /etc/X11/Xwrapper.config
```
And before we start X server let's create the test container.
```
mkdir glxgears
cd glxgears
wget https://gitlab.com/nvidia/samples/raw/master/opengl/ubuntu16.04/glxgears/Dockerfile
docker build -t glxgears .
```
Wait until the container is built and run X server. 
```
X :0 -ac&
```
Press enter to move to command line and check that X server uses acceleration.
```
stas@azureglxrendering:~/glxgears$ nvidia-smi
Thu Sep 27 13:25:54 2018
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 410.48                 Driver Version: 410.48                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla M60           Off  | 000050C1:00:00.0 Off |                  Off |
| N/A   39C    P8    14W / 150W |     21MiB /  8129MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID   Type   Process name                             Usage      |
|=============================================================================|
|    0      4228      G   /usr/lib/xorg/Xorg                            19MiB |
+-----------------------------------------------------------------------------+
```
Connect form other terminal to the VM and start the container:
```
docker run --runtime=nvidia -ti --rm -e 'DISPLAY=:0' -v /tmp/.X11-unix:/tmp/.X11-unix glxgears
```
You shoud see that rendering is started
```
34770 frames in 5.0 seconds = 6951.838 FPS
41998 frames in 5.0 seconds = 8399.594 FPS
43480 frames in 5.0 seconds = 8695.762 FPS
41839 frames in 5.0 seconds = 8367.718 FPS
40088 frames in 5.0 seconds = 8017.426 FPS
33011 frames in 5.0 seconds = 6601.986 FPS
38642 frames in 5.0 seconds = 7728.272 FPS
43334 frames in 5.0 seconds = 8666.554 FPS
40070 frames in 5.0 seconds = 8013.966 FPS
41270 frames in 5.0 seconds = 8253.893 FPS
43714 frames in 5.0 seconds = 8742.644 FPS
41937 frames in 5.0 seconds = 8387.150 FPS
40969 frames in 5.0 seconds = 8170.701 FPS
38638 frames in 5.0 seconds = 7727.560 FPS
```
Return to the previous terminal and check if it's realy use GPU:
```
stas@azureglxrendering:~/glxgears$ nvidia-smi
Thu Sep 27 13:29:33 2018 
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 410.48                 Driver Version: 410.48                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla M60           Off  | 000050C1:00:00.0 Off |                  Off |
| N/A   39C    P0    44W / 150W |     25MiB /  8129MiB |      1%      Default |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID   Type   Process name                             Usage      |
|=============================================================================|
|    0      4228      G   /usr/lib/xorg/Xorg                            21MiB |
|    0      4431      G   glxgears                                       2MiB |
+-----------------------------------------------------------------------------+
```
Open other terminal and connect to VM, let's start additional container.
```
docker run --runtime=nvidia --rm -e 'DISPLAY=:0' -v /tmp/.X11-unix:/tmp/.X11-unix glxgears
```
Return to the previous terminal and check if it's realy use GPU:
```
stas@azureglxrendering:~$ nvidia-smi
Thu Sep 27 13:35:22 2018
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 410.48                 Driver Version: 410.48                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla M60           Off  | 000050C1:00:00.0 Off |                  Off |
| N/A   40C    P0    44W / 150W |     30MiB /  8129MiB |     16%      Default |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID   Type   Process name                             Usage      |
|=============================================================================|
|    0      4228      G   /usr/lib/xorg/Xorg                            22MiB |
|    0      4431      G   glxgears                                       2MiB |
|    0      4925      G   glxgears                                       2MiB |
+-----------------------------------------------------------------------------+
```

## Conclusion
As result of this simple tutorial we created VM in Azure to share GPU for GLX rendering from containers.
I've created scripts for each task so you don't need to print or copy-n-paste.
 