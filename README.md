# GLX rendering using containers in Azure 

Virtual machines with GPU cost is compartible high, so idea to share GPU resource to render in a container looks great.
But we have a challenge, NVIDIA docker runtime does not support GLX rendering which is normaly used in most cases.
But we can connect to a host X server and enable GLX render on it. NVIDIA has a good example of how to do it 
https://gitlab.com/nvidia/samples/blob/master/opengl/ubuntu16.04/glxgears/Dockerfile  