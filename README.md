# trusted-proxies-updater
<img alt="GitHub" src="https://img.shields.io/github/license/adriankae/trusted-proxies-updater?color=black"> <img alt="GitHub last commit (branch)" src="https://img.shields.io/github/last-commit/adriankae/trusted-proxies-updater/main">

This script is updating the trusted proxies in the nextcloud config if nextcloud is running on the same machine as the reverse proxy.

## Support Me
<a href="https://decentech.eu/donations/">
  <img src="https://raw.githubusercontent.com/btcpayserver/btcpayserver-media/64ed9a60321a60026c00b89f711b1f6c48f5efa9/btcpay-logo-black-txt.svg" alt="Donate Via Bitcoin" width="100" height="50">
</a>

## Installation

```bash
sudo su -

git clone https://github.com/adriankae/trusted-proxies-updater.git
```

*Note: doesn't have to be done by the root user.*

## Usage
Edit path to your nextcloud config.php
```
sudo su -

nano {path to teh script}
```
Then make the script executable

```
sudo su -

chmod +x {path to the script}
```
This script is used with crontab. 
```
crontab -e
```

Specify the frequency of execution through crontab.

```bash
# ┌───────────── minute (0 - 59)
# │ ┌───────────── hour (0 - 23)
# │ │ ┌───────────── day of the month (1 - 31)
# │ │ │ ┌───────────── month (1 - 12)
# │ │ │ │ ┌───────────── day of the week (0 - 6) (Sunday to Saturday 7 is also Sunday on some systems)
# │ │ │ │ │ ┌───────────── command to issue                               
# │ │ │ │ │ │
# │ │ │ │ │ │
# * * * * * /bin/bash {path to the script}
```

Save and exit.

I run it every minute.

## Tested Environments:
Debian Bookworm 12 (Linux kernel: 6.6.63 | aarch64) <br />

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
[GPL-3.0](https://github.com/adriankae/trusted-proxies-updater/blob/main/LICENSE)
