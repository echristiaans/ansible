Ik heb onderstaande stappen uitgevoerd om alles aan de praat te krijgen:

1. /yum install nano/ #guiltypleasure
2a. chmod -R 777 /var/www/html/sites/default/files
/    Kan eventueel ook chown <apachegebruiker> -R
/var/www/html/sites/default/files worden/
2b. chcon -R -t httpd_sys_rw_content_t /var/www/html/sites/default/files/
3. chown -R steven:steven /var/www/html/
4. php.ini: short_open_tag = On
5. yum install php-pecl-apcu
6. yum install memcached ; service memcached start
7. yum install mysql
8. httpd.conf AllowOverride All in /var/www/html sectie
9. yum install php-soap
10. yum install php-memcache
11. setsebool -P httpd_can_network_memcache 1
12. apachectl gracefull


Meeste commando's spreken voor zich denk ik. Zo niet hoor ik het wel.

Verder zou ik jou willen vragen om:
1. *.kbotablet.nl <http://kbotablet.nl> en kbotablet.nl
<http://kbotablet.nl> toe te staan
2. Te checken of memcached start als de server reboot
3. Hierop te reageren:

    [19-11-15 14:18:19] Steven: Is het tegen jullie beveiligingsbeleid
    om dit:
    %abergineit_admin ALL=(ALL) NOPASSWD:/bin/su 

    te veranderen naar
    %abergineit_admin ALL=(ALL) NOPASSWD:ALL
    [19-11-15 14:18:39] Steven: Nu moet ik telkens root worden voor elk
    command, en is het risico dat ik dat onnodig lang blijf.



