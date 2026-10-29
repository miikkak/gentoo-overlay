# Copyright 2026 Miikka Karhuluoma
# Distributed under the terms of the MIT License

EAPI=8

inherit acct-user

DESCRIPTION="User for the Beszel monitoring hub"

KEYWORDS="~amd64 ~arm64"
ACCT_USER_ID=-1
ACCT_USER_GROUPS=( beszel )
ACCT_USER_HOME=/var/lib/beszel
ACCT_USER_HOME_PERMS=0750

acct-user_add_deps
