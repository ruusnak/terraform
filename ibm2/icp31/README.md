# Install IBM Cloud Private on IBM Cloud
This terraform template installs an instance of IBM Cloud Private CE on AWS.
A Single VM is created to host an ICP instance with master/management/worker functionality.
The VM is 16CPU/32GB configuration.

The defaul security groups don't allow access to the public IP, so you need to either allow addtional incoming ports
or use some other solution (such as VPN)

You need to use your own keypair.
The public key is also used in the sample.tfvars file

Note that the keys should be created without a passphrase, for example:
ssh-keygen -b 2048 -f  icp_id -N ""

You need to provide your own variable values using for example the provided sample.tfvars.
The contents of the tfvars file should be self-explanatory

After you have installed terraform, created the keys, and supplied your own variable values in the .tfvars file, 
you are ready to provision your environment using a command like this in the directory that hosts the files:
- terraform init (only needed once)
- terraform apply --var-file=sample.tfvars
