# {{ ansible_managed }}
#installphp.sh
#/bin/bash
phpbrew install --old {{ phpbrew_init.version }}
