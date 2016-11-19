Kimengumi Command Line Interface Environnement
===================

Usefull command line environnement & tools

Installation
-------------

### Generate Deploy key on local system

`ssh-keygen -t rsa -b 4096`
`cat ~/.ssh/id_rsa.pub`

Allow the key on the GIT repository

### Install & configure the environement 

`apt-get install htop git vim-nox zsh`
`mkdir -p /opt/kimengumi/`
`cd /opt/kimengumi/`
`git clone ssh://git@git.kimengumi.fr:617/sys/kclie.git`
`cd kclie && ./configure`