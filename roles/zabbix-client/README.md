# ATB Team Zabbix Client - atbank-zabbix-client

This playbook is designed to install the Zabbix monitoring agent on either Linux or Windows based systems. It will auto detect the OS and install the appropriate client as needed. The playbook has the secondary function of also adding the system in which the client is installed to the Zabbix server specified in the defaults main YAML file.

The playbook is location aware. Whereas the SIS location relation is used for configuration of the zabbix proxy as well as which location based Zabbix host group to add a system to (if this feature is used)

## Prerequisites

### Zabbix Client Requirments

* Redhat/CentOS 7.x systems, or;
* Windows 64-bit systems

### Zabbix Server Requirements

If the functionality of automatically adding a client to the zabbix monitoring server is used, the following requirements must be met:

* Zabbix server is v3.0+

### Ansible Node Requirements

If the functionality of automatically adding a client to the zabbix monitoring server is used, the ansible node that executes this playbook also has the following requirements:

* Ansible v2.1.0.0+
* zabbix-api python module

## Usage

### Standard Usage

Usage of the playbook can be as simple as just including the infra-zabbix-client role. Zabbix server settings are all defined in the defaults section of the role.

```YAML
---
  - hosts:
    - atb-linux-p01

    roles:
      - atb-zabbix-client

    vars:
      zabbix_agent_add_servers: "127.0.0.1"    # Optional - Zabbix server/proxies that can access the agent on the client in addition to the one auto supplied based on location
      zabbix_agent_enable_remote: false		   # Optional - Wether remote servers/proxies can execute system commands. Default value is true
      zabbix_agent_enable_complex_chars: false # Optional - Wether complex chars like |,/,[,] can be used in commands to the client. Default is true
```

### Enhanced Usage

The playbook has the additional capability for adding hosts to the zabbix monitoring inventory using the Zabbix server API. The connection for modifying clients in Zabbix is over https from the ansible node to the zabbix server directly. If a client does not exist in the zabbix inventory, the playbook can add it, along with which templates and roles the system belongs to.

```YAML
---
  - hosts:
    - atb-linux-p01

    roles:
      - atbank-zabbix-client

    vars:
      add_monitoring: true    # This flag will add the system to the hosts list of the zabbix server

      zabbix_templates:
        - "Template MySQL Server"
      zabbix_groups:
        - "SQL Servers"
```

When the add_monitoring var is set to true, the ansible node will also add the client to the zabbix host inventory. It will also ake the follow adjustments:

#### Groups

* Add the system to the groups listed in the zabbix_default_groups variable in defaults [Ansible Added Host]
* Add the system to the group name defined for the location in variable defaults [Linux Servers or Windows Servers]
* Add the system to the groups specified in the zabbix_groups variable in the playbook vars section

#### Templates

* Add the system to the OS template based on the OS of the system. [Template OS Linux or Template OS Windows]
* Add the system to the templates listed in the zabbix_default_templates default variable [Template ICMP Ping]
* Add the system to the templates specified in the zabbix_teplates variable in the playbook vars section.

Keep in mind that all exisiting zabbix host templates and groups of the system being added to zabbix will be over written if changed in the zabbix console.
