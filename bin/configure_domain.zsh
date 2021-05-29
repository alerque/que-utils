#!/usr/bin/env zsh

set -e
set -x

domain="$1"
target="$2"

[[ -n $domain ]]

case $PWD in
	/|/etc*)
		etc=/etc
		exe=sudo
		sudo -v
		;;
	/home/caleb/projects/hosts/asper*)
		etc=/home/caleb/projects/hosts/asper/
		exe=
		;;
	*)
		exit 1
		;;
esac

vmail="$etc/mail/virtual/$domain"
pushd $(dirname $vmail)
if [[ ! -a $vmail ]]; then
	if [[ -n $target ]]; then
		$exe ln -s $target $domain
	fi
fi
nvim $domain
popd

vhost="$etc/httpd/conf/extra/httpd-vhosts.conf"
if ! grep -sF "Host $domain" $vhost; then
	if [[ -z $target ]]; then
		$exe tee -a $vhost <<< "Use VHost $domain"
	else
		$exe tee -a $vhost <<< "Use RedirectHost $domain $target"
	fi
fi
nvim $vhost

certs="$etc/acme-redirect.d/$domain.conf"
if [[ ! -a $certs ]]; then
	cat <<- EOF | $exe tee $certs
		[cert]
		name = "$domain"
		dns_names = [
		  "$domain",
		  "www.$domain",
		]

		# vim: ft=toml
	EOF
fi
nvim $certs
