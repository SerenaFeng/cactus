# .bash_profile

# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
alias rebash="source ~/.bash_profile"
alias ll='ls -l'
alias d="bash ~/scripts/docker.sh"
alias k='bash ~/scripts/kubectl.sh'

