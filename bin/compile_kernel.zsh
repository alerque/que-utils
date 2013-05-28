#!/bin/zsh

function auth () {
	ssh-agent | source /dev/stdin
	ssh-add ~/.ssh/id_rsa
}

function keepalive () {
	while [ true ]; do
		ssh $1 sudo test true
		sleep 60
	done &
}

function check_connection() {
	thishost=$1
	show "Checking if $thishost is up"; busy
	ping -q -w2 $thishost > /dev/null && ok || flunk

	show "Checking for ssh and sudo access on $thishost"; busy
	ssh $thishost sudo test true && ok || flunk
	keepalive $thishost
}

[ -z "$SSH_AGENT_PID" ] && auth
pgrep ssh-agent | grep -q "$SSH_AGENT_PID" || auth

. /etc/rc.d/init.d/functions

BUILDDIR=~/tmp

mkdir -p $BUILDDIR
cd $BUILDDIR

function latest_kernel {
	curl -s http://www.kernel.org/kdist/finger_banner |
		grep 'latest stable' |
		head -n 1 |
		perl -pne 's/.*:\s*([\d.]+)/\1/g'
}

function latest_subver {
	main_ver=$1
	curl -s "http://www.kernel.org/pub/linux/kernel/people/gregkh/v$main_ver/" |
		grep "patch-$main_ver" |
		grep 'bz2' |
		perl -pne 's/.*patch-([\d.]+)\..*/\1/g'
}

function latest_patch {
	curl -s http://www.kernel.org/kdist/finger_banner |
		grep 'latest prepatch for the stable' |
		perl -pne 's/.*:\s*([\d.rc]+)/\1/g'
}

function flunk {
	fail
	echo $*
	exit
}

reuse=n
default=n
dryrun=n

while getopts v:h:p:m:nesdcryt OPT; do
	case ${OPT} in
		v) version=$OPTARG ;;
		d) default=y && yes=y && source=y && edit=n && net=n && patch=n && reuse=y;;
		h) host=$OPTARG ;;
		m) model=$OPTARG ;;
		r) reuse=y ;;
		c) reuse=n ;;
		p) patch=$OPTARG ;;
		n) net=y ;;
		e) edit=y ;;
		s) source=y ;;
		t) dryrun=y ;;
		y) yes=y ;;
	esac
done

if is_yes $dryrun; then
	dryrun="echo"
	yes=n
	function ok () {}
	function flunk () {}
	function show () {}
	function busy () {}
else
	dryrun=""
fi

show "Testing for needed tools"; busy
for app in wget patch gcc make curl perl scp rsync grep curl zcat; do
	which $app > /dev/null 2>&1 || flunk "Could not find $app"
done && ok

latest_kernel | read latest_kernel
latest_subver $latest_kernel | read latest_subver

is_yes $default && version=$latest_kernel || read "version?Kernel Version ($latest_kernel): "
[ -n "$latest_subver" ] && read -q "use_subver?Use x.y tree $latest_subver? (y/n): " || use_subver=n

[ -n "$version" ] || version=$latest_kernel

latest_patch | read patch_version

[ -n "$patch_version" ] && ! is_yes $default && read -q "patch?Use patch $patch_version? (y/n): " || patch=n

[ -z "$host" ] && is_yes $default && hostname | read hostname
[ -z "$host" ] && read "host?For Host ($HOSTNAME): "
[ -n "$host" ] || host="$HOSTNAME"

patchdir=~/projects/ouraynet/kernels/patches/$host

check_connection $host

ssh $host rpm -q lilo > /dev/null && bconfig="/etc/lilo.conf" && bloader=lilo 2>&1 > /dev/null
ssh $host rpm -q grub > /dev/null && bconfig="/boot/grub/menu.lst" && bloader=grub 2>&1 >/dev/null

is_yes $default && [ -z "$model" ] && model="$host"
[ -z "$model" ] && read "model?Get base config from ($host): "
[ -n "$model" ] || model="$host"

[ "$model" != "$host" ] && [ ! -f "$model" ] && check_connection $model

mkdir -p $BUILDDIR/$host
cd $BUILDDIR/$host

[ -z "$net" ] && read -q "net?Is $host netboot? [y|(n)]: "
[ -z "$yes" ] && read -q "yes?Should I go ahead and copy files? [(y)|n]: "
[ -z "$source" ] && read -q "source?Should I copy source tree? [(y)|n]: "
[ -z "$edit" ] && read -q "edit?Do you want to edit the kernel config? [(y)|n): "

is_yes $net && check_connection rootserver

is_yes $yes && cmd='' || cmd='echo'

date +%Y%m%d | read ds
src="/usr/src/linux-$version.tar.bz2"
if [ ! -f $src ]; then
	show "Downloading $version source"; busy
	echo $version | grep -q rc && sdir=v2.6/testing || sdir=v2.6
	$dryrun wget -c http://kernel.org/pub/linux/kernel/$sdir/linux-$version.tar.bz2 \
		-O $BUILDDIR/linux-$version.tar.bz2 && ok || flunk "Cannot download $version source"
	$dryrun sudo mv $BUILDDIR/linux-$version.tar.bz2 /usr/src/
fi

if is_yes $use_subver; then
	show "Clearing Old...."; busy
	$dryrun rm -rf $BUILDDIR/$host/{lib/modules/$version,linux-$version} && 
	$dryrun rm -rf $BUILDDIR/$host/{lib/modules/$latest_subver,linux-$latest_subver} && ok || flunk
	show "Extracting $version source"; busy
	$dryrun tar xfj $src && ok || flunk
	$dryrun cd $BUILDDIR/$host
	$dryrun mv linux-$version linux-$latest_subver
	main_version=$version
	version=$latest_subver
	show "Applying patch $latest_subver"; busy
	$dryrun wget -c "http://kernel.org/pub/linux/kernel/people/gregkh/v$main_version/patch-$version.bz2" || flunk
	cd $BUILDDIR/$host/linux-$version
	$dryrun cp ../patch-$version.bz2 .
	$dryrun bunzip2 patch-$version.bz2 || flunk
	$dryrun patch -p1 < patch-$version > /dev/null && ok || flunk
elif is_yes $patch; then
	show "Clearing Old...."; busy
	$dryrun rm -rf $BUILDDIR/$host/{lib/modules/$version,linux-$version} && 
	$dryrun rm -rf $BUILDDIR/$host/{lib/modules/$patch_version,linux-$patch_version} && ok || flunk
	show "Extracting $version source"; busy
	$dryrun tar xfj $src && ok || flunk
	$dryrun cd $BUILDDIR/$host
	$dryrun mv linux-$version linux-$patch_version
	version=$patch_version
	show "Applying patch $patch_version"; busy
	$dryrun wget -c "http://www.kernel.org/pub/linux/kernel/v2.6/testing/patch-$version.bz2" || flunk
	cd $BUILDDIR/$host/linux-$version
	$dryrun cp ../patch-$version.bz2 .
	$dryrun bunzip2 patch-$version.bz2 || flunk
	$dryrun patch -p1 < patch-$version > /dev/null && ok || flunk
else
	if is_no $reuse || [ ! -d $BUILDDIR/$host/linux-$version ]; then
		show "Clearing Old...."; busy
		$dryrun rm -rf $BUILDDIR/$host/{lib/modules/$version,linux-$version} && ok || flunk
		show "Extracting $version source"; busy
		$dryrun tar xfj $src && ok || flunk
		$dryrun cd $BUILDDIR/$host/linux-$version
	else
		show "Reusing old source directory by making clean"; busy
		$dryrun cd $BUILDDIR/$host/linux-$version
		$dryrun make clean && ok || flunk
	fi
fi

if [ -d $patchdir ]; then
	/bin/ls $patchdir/*-$version.patch |
		while read patchfile; do
			show "Patching with $patchfile"; busy
			$dryrun patch -p1 < $patchfile && ok || flunk
		done
fi

show "Getting $host current config";busy
if [ -f "$model" ] ; then
	file "$model" | grep -s 'Linux kernel' && ./scripts/extract-ikconfig "$model" > .config > config-nondist || cp "$model" .config || 
else
	ssh $model zcat /proc/config.gz > .config > config-nondist && ok || flunk
fi
show "Configuring new $version kernel"; busy
echo
$dryrun make silentoldconfig && ok || flunk

is_yes $edit && ( $dryrun make menuconfig && ok || flunk )

if is_yes $source;then
	show "Sending $version source tree (configured but not compiled) to $host"; busy
	$cmd rsync -aqe ssh --rsync-path='sudo rsync' --delete $BUILDDIR/$host/linux-$version/ $host:/usr/src/linux-$version/ && ok || flunk
fi

show "Compiling new $version kernel"; busy
cat /proc/cpuinfo | grep -c processor | read cpucount
$dryrun make -j $(($cpucount*4)) > /dev/null && ok || flunk
show "Creating modules"; busy
$dryrun INSTALL_MOD_PATH=$BUILDDIR/$host make modules_install > /dev/null && ok || flunk

echo

if is_yes $net; then
	$dryrun rsync -aqe ssh --rsync-path='sudo rsync' rootserver:/var/lib/tftp/pxelinux.cfg/$host $BUILDDIR/$host/bootconfig
	echo "#	kernel vmlinuz-$version-$host-$ds" >> $BUILDDIR/$host/bootconfig
	$dryrun vim $BUILDDIR/$host/bootconfig
	$cmd rsync -aqe ssh --rsync-path='sudo rsync' $BUILDDIR/$host/bootconfig rootserver:/var/lib/tftp/pxelinux.cfg/$host
	$cmd rsync -aqe ssh --rsync-path='sudo rsync' --copy-links $BUILDDIR/$host/linux-$version/arch/x86/boot/bzImage rootserver:/var/lib/tftp/vmlinuz-$version-$host-$ds
else
	rsync -aqe ssh --rsync-path='sudo rsync' $host:$bconfig $BUILDDIR/$host/bootconfig
	if [ "$bloader" = "grub" ]; then
		echo "#title Linux $version $ds" >> $BUILDDIR/$host/bootconfig
		echo "#	kernel /vmlinuz-$version-$host-$ds\n" >> $BUILDDIR/$host/bootconfig
	elif [ "$bloader" = "lilo" ]; then
		echo "#image=/boot/vmlinuz-$version-$host-$ds"  >> $BUILDDIR/$host/bootconfig
		echo "#	"`grep -m 1 root= $BUILDDIR/$host/bootconfig`  >> $BUILDDIR/$host/bootconfig
		echo "#	label=$ds"  >> $BUILDDIR/$host/bootconfig
	fi
	$dryrun vim $BUILDDIR/$host/bootconfig
	$cmd rsync -aqe ssh --rsync-path='sudo rsync' $BUILDDIR/$host/bootconfig $host:$bconfig
	$cmd rsync -aqe ssh --rsync-path='sudo rsync' --copy-links $BUILDDIR/$host/linux-$version/arch/x86/boot/bzImage $host:/boot/vmlinuz-$version-$host-$ds
fi

$dryrun rm -f $BUILDDIR/$host/lib/modules/$version/{build,source}
$dryrun ln -sf $BUILDDIR/$host/linux-$version $BUILDDIR/$host/lib/modules/$version/build
$dryrun ln -sf /usr/src/linux-$version $BUILDDIR/$host/lib/modules/$version/source

show "Sending $version modules to $host"; busy
$cmd rsync -aqe ssh --rsync-path='sudo rsync' --delete $BUILDDIR/$host/lib/modules/$version/ $host:/lib/modules/$version/ && ok || flunk

echo
