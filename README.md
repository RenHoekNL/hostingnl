# LetsEncrypt script for hosting.nl DNS API

If you want to have a wildcard SSL certificate, you need to do a challenge via the DNS server to prove you really own that domain. If you're using the hosting.nl DNS provider, you can use this script to automatically set the data needed, making it possible to automate your renewals.

1. Install certbot on your server: https://certbot.eff.org/instructions
2. You'll need to create an API KEY, which you can do in your dashboard: https://mijn.hosting.nl/index.php?m=APIKeyGenerator
3. Then these are the steps to renew your certificate
```
./hostingnl.sh cleanup
rm -f /var/log/letsencrypt/letsencrypt.log*
certbot certonly --manual --manual-auth-hook ./hostingnl.sh -d palli.nl -d *.palli.nl --preferred-challenges dns
./hostingnl.sh cleanup
```
4. Restart or reload any services that need to read the updated certificate
5. Once you got this working, you can put the instructions above in a script and use crontab to execute it every 2.5 months or so.
