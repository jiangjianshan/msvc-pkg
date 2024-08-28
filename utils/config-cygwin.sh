#!/bin/bash
# https://www.cygwin.com/faq.html#faq.using.startup-slow
echo [$0] To make cygwin run faster
if [ ! -f "/etc/passwd" ]; then getent passwd $(id -u) > /etc/passwd; fi
if [ ! -f "/etc/group" ]; then getent group $(id -G) > /etc/group; fi
grep -qxF "passwd: files db" /etc/nsswitch.conf || echo 'passwd: files db' >>/etc/nsswitch.conf
grep -qxF "group: files db" /etc/nsswitch.conf || echo 'group: files db' >>/etc/nsswitch.conf

cygserver-config

# Dealing with line endings
# See https://stackoverflow.com/questions/1967370/git-replacing-lf-with-crlf
git config --global core.autocrlf input
git config --global core.autocrlf false

# speed up git handling if on cygwin environment
git config --system core.fileMode false
# SSL certificate problem: Unable to get local issuer certificate
# https://learn.microsoft.com/en-us/archive/blogs/phkelley/adding-a-corporate-or-self-signed-certificate-authority-to-git-exes-store
git config --global http.sslbackend schannel
git config --global http.sslVerify false

echo "done."
