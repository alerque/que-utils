#/bin/zsh

mkdir -p ~/rpm/{SPECS,SOURCES,BUILD,RPMS,SRPMS}
mkdir ~/rpm/{SPECS,SOURCES}/CVS
echo ':pserver:cvs@cvs.pld-linux.org:/cvsroot' > ~/rpm/SPECS/CVS/Root
echo ':pserver:cvs@cvs.pld-linux.org:/cvsroot' > ~/rpm/SOURCES/CVS/Root
touch ~/rpm/{SPECS,SOURCES}/CVS/Entries
echo 'SPECS' > ~/rpm/SPECS/CVS/Repository
echo 'SOURCES' > ~/rpm/SOURCES/CVS/Repository
poldek -i cvs rpm-build
cd ~/rpm/SPECS
cvs up builder
