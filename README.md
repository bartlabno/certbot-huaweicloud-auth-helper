# Certbot authorisation helper for Let's Encrypt
Authorisation helper script for certbot to use with huaweicloud for letsencrypt

# Requirements
Befere you will run certbot with this helper you need to meet some criteria

## Dependencies
To use you need to install dig, jq and curl on your local machine

## Authorisation
You have two options:
- Fill auth.json file
- Set environment variables with your username (HW_USER), password (HW_PASSWORD), region (REGION) and account name (ACCOUNT)

# Usage
Use with certbot as usual:
```
sudo certbot certonly --manual --manual-auth-hook ./huaweicloud_auth.sh --manual-cleanup-hook ./huaweicloud_auth.sh --preferred-challenges=dns -d domain.example.com
```
