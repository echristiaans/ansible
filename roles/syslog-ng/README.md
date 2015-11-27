syslog-ng
=========

This playbook will uninstall rsyslog and replace it with syslog-ng. All local system logs will continue to be placed in the default
/var/log/ locations. The additional variables are used to define the syslog-ng network receiver.

/etc/syslog-ng/conf.d/varadm.conf is created for network receiver filters.

Requirements
------------

Yum must have Internet access and the epel-release must be installed. This playbook will only run on REHL and CentOS.

Port UDP/514 must be enabled on iptables if it is used for local firewall purposes.

Role Variables
--------------

syslog_ng_root: "/var/adm"	- (optional) Sets the default logging folder destination for the network receiver.
syslog_ng_clients:		- (required) List name for defining network receiver filters
        - foldername: "test1"	- (required) subfolder name in {{syslog_ng_root}} to store filtered items
          comment: "sometext"	- (optional) Descriptive comment that will be in the syslog-ng configuration file
          networks:		- (required) List name for defineing network receiver sources
          - "172.16.197.208/32" - (at least 1 required) Network address of sysloging client/source
          - "10.10.12.0/24"	- (optional) additional network addresses of sysloging client/source
        - foldername: "test2"	- (optional) 2nd filter and related sources if needed
          comment: "some more"
          networks:
          - "10.2.2.3/32"
          - "10.2.2.2/32"

Dependencies
------------

epel-release

Example Playbook
----------------

---
  - hosts: localhost
    roles:
     - role: syslog-ng

    vars:
      syslog_ng_root: "/var/adm"
      syslog_ng_clients:
        - foldername: "test1"
          comment: "Log some host 1"
          networks:
          - "172.16.197.208/32"
        - foldername: "test2"
          comment: "log some hosts 2"
          networks:
          - "10.2.2.3/32"
          - "10.2.2.2/32"


Author Information
------------------

Michael van den Berg - Team Charlie
