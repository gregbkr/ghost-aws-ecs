# My old Ghost blog on aws

## Overview

### Scope
- I need to keep my old ghost blog running. My version of ghost is too old to be upgraded and I don't want to spend time re-develop a static site. I did not find any nice gasby/hugo templates. I will use the smallest EC2 instance (5$/months), and ASG (free), and a cloudfront (cheap) to keep the site up. However, it is not 100% HA, need to link manually the DNS to cloudfront if the instance get destroyed.

### Tech
- Hosting: AWS cloud
- Front: Ghost in docker (version 0.11.3, newer makes my blog fail)
- Container orchestrator: ECS (1 EC2 instance t2.nano)
- Data: EFS + snapshot
- CDN: Cloudfront + Cert
- Code: Github
- Infra: Terraform cloud
- Price: < 5$ / month

### Flow
User --> Route53 --> Cloudfront --> EC2 DNS (docker ghost on ECS) <-- EFS (blog data)

## Infra

### Prerequisit
- Purchase domain `d3vblog.com` in route53
- Create custom certificate in zone `us-east-1` (for cloudfront to see)

### Terraform

- Deploy with:
```
cd terraform 
nano main.tf <-- edit variables
terraform init
terraform apply
```
- First deploy should not work because the blog data are not in EFS.

#### Fix the data
- Connect to the EC2 instances, mount the EFS volume:
```
sudo mkdir /mnt/efs
sudo mount -t efs fs-9921c253.efs.eu-west-1.amazonaws.com /mnt/efs/
```
- And copy the data from `blog-data` to `/mnt/efs/.`

#### Fix CloudFront -> EC2 (ECS) link
- There are no LB because of cost (20$ per month). So if instance goes down, I have to update cloudfront origin with the EC2 instance public DNS.
- Get the DNS of the ECS instance and replace the variable `instance_dns` in `terraform/main.tf`
- Run again a `terraform deploy`


### Check
- Try the website on CloudFront url
- Try with your DNS: d3vblog.com

## Annexes
- To run manually the container: `docker run -d -p 2368:2368 -e NODE_ENV=production --name ghost -v $PWD/ghost-backup:/var/lib/ghost ghost:0.11.3`
- Check that blog data are present, and the rights are set