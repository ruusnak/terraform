This terraform template installs an instance of IBM Cloud Private CE on AWS.
A VPC is created with three VMs:
- a boot node
- 1 master
- 1 worker

You need to provide your own keypair as files (names hardcoded in the template) and
place them in the same directory as the terraform template
- icp_id
- icp_id.pub (the key here is also used in the sample.tfvars file)

Note that the keys should be created without a passphrase, for example:
ssh-keygen -b 2048 -f  icp_id -N ""

You need to provide your own variable values using for example the provided sample.tfvars.
The contents of the tfvars file should be self-explanatory

After you have installed terraform, created the keys, and supplied your own variable values in the .tfvars file, 
you are ready to provision your environment using a command like this in the directory that hosts the files:
	- terraform init (only needed once)
	- terraform apply --var-file=sample.tfvars
