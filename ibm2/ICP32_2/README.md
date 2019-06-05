# ICP 3.2 provisioning on IBM Cloud
This template provisions two nodes, one mgmt/proxy and one worker.

You should provide a keypair (no passphrase) and name them 
- id_icp 
- id_icp.pub

Also, the template needs a few variables that be provided in a file.
The variables needed are:
bxapikey = "<< your key here, not really needed >>"
slusername = "<<your IBM CLOUD ID>>"
slapikey  = "<<your IBM Cloud API Key>>"
hostname="<<hostname, like icp32>>"
domainname="<<yourdomain.com>>"
datacenter="<<dc, like fra04>>"

With the required four files available, nad IBM Cloud terraform provided installed, run
terraform init
terraform apply --var-file=<<your variable file, e.g myvars.tfvars>>

Takes roughly 30 minutes to set up VMs and install ICP 3.2 Community Edition