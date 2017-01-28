#!/bin/bash

if [ `ip -4 addr show | grep "/32" -c` -gt 1 ];then 
  echo MASTER; 
else 
  echo BACKUP; 
fi
