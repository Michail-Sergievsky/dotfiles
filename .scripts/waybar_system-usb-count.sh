#!/usr/bin/env bash
lsblk -rno NAME,TYPE,RM | awk '$2=="disk" && $3=="1" {c++} END {print c+0}'
