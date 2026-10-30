# Copyright 2026 Miikka Karhuluoma
# Distributed under the terms of the MIT License

EAPI=8

inherit acct-user

# Same text as the GECOS field of the account the Ansible system-users role
# creates, so installing this on an existing host changes nothing.
DESCRIPTION="user for alloy"

KEYWORDS="amd64 arm64"
ACCT_USER_ID=-1
ACCT_USER_GROUPS=( alloy )
ACCT_USER_HOME=/var/lib/alloy

acct-user_add_deps
