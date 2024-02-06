#!/bin/bash

# Met à jour la liste des paquets et upgrade les paquets existants
sudo apt update && sudo apt upgrade -y

# Installe les paquets nécessaires
sudo apt install -y vim bat fd-find zsh fzf sqlite3

