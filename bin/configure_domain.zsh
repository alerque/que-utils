#!/usr/bin/env zsh

set -e
set -x

: ${PAGES:=false}

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

if ! $PAGES; then
	vmail="$etc/mail/virtual/$domain"
	pushd $(dirname $vmail)
	if [[ ! -a $vmail ]]; then
		if [[ -n $target ]]; then
			$exe ln -s $target $domain
		fi
	fi
	nvim $domain
	popd
fi

vhost="$etc/httpd/conf/extra/httpd-vhosts.conf"
if ! grep -sF "Host $domain" $vhost; then
	if [[ -z $target ]]; then
		if $PAGES; then
			$exe tee -a $vhost <<< "Use PagesHost $domain"
		else
			$exe tee -a $vhost <<< "Use VHost $domain"
		fi
	else
		if $PAGES; then
			$exe tee -a $vhost <<< "Use PagesSubHost $domain $target"
		else
			$exe tee -a $vhost <<< "Use RedirectHost $domain $target"
		fi
	fi
fi
nvim $vhost

if $PAGES && [[ -n $target ]]; then
	certs="$etc/acme-redirect.d/$target.conf"
	$exe sed -i -e "/^]$/i\  \"$domain\"," $certs
	nvim $certs
else
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
fi

echo VISIT: "https://hstspreload.org/?domain=$domain"
