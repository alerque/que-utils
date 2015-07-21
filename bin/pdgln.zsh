#!/usr/bin/env zsh

while getopts d:t: opt; do
	case $opt in
		d) date=$OPTARG;;
		t) time=$OPTARG;;
	esac
done

: ${date:=today}
: ${time:=21:15}

export LANG=tr_TR.UTF8

BUILDDIR=$(mktemp --dir --tmpdir)
trap 'rm -rf $BUILDDIR' EXIT SIGHUP SIGTERM
pushd $BUILDDIR

for i in $(seq 0 1); do
	formatdate=$(date --date "$date + $i days" "+%A günü %F")
	> ${i}.sil <<- EOF
		\begin[papersize=a5]{document}
		\nofolios
		\begin[first-content-frame=content]{pagetemplate}
		\frame[id=content, top=12%, bottom=90%, left=8%, right=84%]
		\end{pagetemplate}
		\set[parameter=current.parindent,value=0]
		\set[parameter=document.parindent,value=0]
		\font[language=tr,family=Crimson,size=14pt]

		Dalyan Gümrük İşhanı'nın dikkatine:
		\bigskip

		$formatdate tarihinde 802 numaralı ofiste akşam \font[weight=800]{saat $time} olana kadar çalışıyor olacağım.
		\skip[height=4em]

		Caleb Maclennan

		\end{document}
	EOF

	sile ${i}.sil -o ${i}.pdf
done

pdfjam 0.pdf 1.pdf --nup 2x1 --landscape --outfile 2up.pdf
lpr 2up.pdf
