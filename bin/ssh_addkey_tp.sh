#!/bin/sh

mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAguQl+vaaMp1KNGPIjnf64D/hhfV2XbcvnpUghSjen0Xr63G05shYYasLngdXbI9Hxr9BE456Qw1+Y78VUks88ZWat+wENCVvZpLHwyjTFk7yupExYpctZBgoPZyaTiTIILjVLAhIDKk6/gAXviRF6UwRKtltZJE0k0fiFnLwSFPw7b0MpjZnS8sUKQR4ZvK87yJhx+p5LVQRwRwVILBRWVAkdHLqtxACzoykac1GbtUFgpqkMzhF6kUfb75ozYkHoLSH7CLs5ac13SYml3Hl5DoIKsBQfoDlOoI7V1WKgH8G4yd9lYobEbc2hGZDkdcqSA2jvSNeKHpo1fEKpja/Cw== b6:f3:5b:e0:ff:68:1a:02:68:04:3d:7d:bd:cb:2a:fd TP03" >> ~/.ssh/authorized_keys
if [ -L ~/.ssh/authorized_keys -a -f ~/.ssh/authorized_keys2 ] ; then rm ~/.ssh/authorized_keys && mv ~/.ssh/authorized_keys2 ~/.ssh/authorized_keys ; fi
ln -s ~/.ssh/authorized_keys ~/.ssh/authorized_keys2
chmod -R 700 ~/.ssh
chmod 0600 ~/.ssh/authorized_keys*


