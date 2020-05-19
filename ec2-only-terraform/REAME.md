# My old Ghost blog on aws

## Overview

### Scope
- I need to keep my old ghost blog running. My version of ghost is too old to be upgraded and I don't want to spend time re-develop a static site. I did not find any nice gasby/hugo templates. I will use the smallest EC2 instance (5$/months), and ASG (free), and a cloudfront (cheap) to keep the site up. However, it is not 100% HA, need to link manually the DNS to cloudfront if the instance get destroyed.

### Tech
- Hosting: EC2 instance
- Front: Ghost in docker
- Data: from S3 for import, and versioned backup
- CDN: Cloudfront + Cert
- Code: github
- Infra: Terraform

### Flow
User --> Route53 --> Cloudfront --> EC2 (docker ghost) <-- S3 data

## Infra

### Requisit
- Purchase domain `swisscovid.com` in route53
- Create custom certificate: swisscovid.com in zone `us-east-1` (for cloudfront to see)


### Terraform
```
cd terraform 
nano main.tf <-- edit variables
terraform init
terraform apply
```
- Copy ghost data to s3 (if new): `aws s3 sync s3-data s3://ghost-terra-backup-gg/ghost --delete`
- Wait for the ASG to launch the instance, find the instance public DNS
- Edit main.tf and replace the var: `instance_dns` --> this is cloudfront origin. Run again terraform.
- Note: there are no LB because of cost (20$ per month). So if instance goes down, I have to update cloudfront origin with new instance public DNS.

### Check
- Try the website on Cloudfront url
- CYour DNS


--user="uid:gid"

docker run -d -p 2369:2368 -e NODE_ENV=production --name ghost1 -v $PWD/ghost-backup:/var/lib/ghost ghost:0.11.3


 cat /entrypoint.sh
#!/bin/bash
set -e

# allow the container to be started with `--user`
if [[ "$*" == npm*start* ]] && [ "$(id -u)" = '0' ]; then
        chown -R user "$GHOST_CONTENT"
        exec gosu user "$BASH_SOURCE" "$@"
fi

if [[ "$*" == npm*start* ]]; then
        baseDir="$GHOST_SOURCE/content"
        for dir in "$baseDir"/*/ "$baseDir"/themes/*/; do
                targetDir="$GHOST_CONTENT/${dir#$baseDir/}"
                mkdir -p "$targetDir"
                if [ -z "$(ls -A "$targetDir")" ]; then
                        tar -c --one-file-system -C "$dir" . | tar xC "$targetDir"
                fi
        done

        if [ ! -e "$GHOST_CONTENT/config.js" ]; then
                sed -r '
                        s/127\.0\.0\.1/0.0.0.0/g;
                        s!path.join\(__dirname, (.)/content!path.join(process.env.GHOST_CONTENT, \1!g;
                ' "$GHOST_SOURCE/config.example.js" > "$GHOST_CONTENT/config.js"
        fi
fi

exec "$@"
# 