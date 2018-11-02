This terraform template installs an instance of IBM Cloud Private CE on AWS.
A VPC is created with three VMs:
- boot
- master
- worker

You need to provide your own keypair as files (hardcoded in the template) and
place them in the same directory as the terraform template
- icp_id
- icp_id.pub (the key here is also used in the sample.tfvars file)


