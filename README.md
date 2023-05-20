Kimengumi Command Line Interface Environnement (kclie)
===================

KCLIE is a useful command line environment, tools & libraries.

It gives you :

- A standardized Bash & Zsh terminal environment.
- A set of additional users commands, increasing your efficiency.
- A set of additional admin commands, simplifying your admin life.
- A set of wizards, for faster & standardized deployments
- A set of batch libraries, for faster/reliable script writing

Compatibility
-------------

Best to use on active Debian or Ubuntu LTS releases

But allow used _(with partial support)_ on :

- Mac OSX
- Red Hat Enterprise Linux / CentOS / Rocky Linux
- WSL (Windows Subsystem for Linux)
- Older releases

Installation
-------------

### for a whole system (all users)

    sudo git clone https://github.com/kimengumi/kclie.git /opt/kclie
    sudo /opt/kclie/configure

### for a single user

    git clone https://github.com/kimengumi/kclie.git ~/.kclie
    ~/.kclie/configure

Docker Sandbox
-------------

#### Debian

    docker compose run kclie-debian

#### Ubuntu

    docker compose run kclie-ubuntu

On both a user "user", sudoer with password "user" is created within the sandbox container.

License
-------------

Licensed under the EUPL, Version 1.2 or – as soon they will be approved by
the European Commission - subsequent versions of the EUPL (the "Licence");
You may not use this work except in compliance with the Licence.
You may obtain a copy of the Licence at:

https://joinup.ec.europa.eu/software/page/eupl

Unless required by applicable law or agreed to in writing, software
distributed under the Licence is distributed on an "AS IS" basis,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the Licence for the specific language governing permissions and
limitations under the Licence.