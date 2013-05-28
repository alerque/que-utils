#!/bin/zsh

echo "Database password: "
read PWD
[ -n "$PWD" ] || exit

function db () {
	mysql -uroot -p$PWD -hboa caleb -Bse "$*"
}

function odb () {
	mysql -uroot -p$PWD -hmysql ouraynet -Bse "$*"
}

case $1 in
	log)
		# Log mailbox status
		find ~/Maildir/new | grep -c boa | read new
		find ~/Maildir/cur | grep -c boa | read cur
		let tot=$cur+$new
		db "INSERT INTO log (k, v) VALUES ('inbox', '$tot'), ('unread', '$new')"
		;;
	graph)
		mktemp /tmp/grapher.XXXXXX | read t1
		mktemp /tmp/grapher.XXXXXX | read t2
		mktemp /tmp/grapher.XXXXXX | read t3
		mktemp /tmp/grapher.XXXXXX | read t4
		comstr='set term png
			set data style lines
			set size 1, .3
			set border 0
			set data style lines
			set ytics nomirror
			set xdata time
			set bmargin 0
			set tmargin 0
			set noytics
			set grid
			set timefmt "%s" '
		date +%s | read now
		db "SELECT UNIX_TIMESTAMP(one.t), one.v, two.v, (one.v - two.v) FROM log AS one, log AS two WHERE two.t=one.t AND two.k != one.k AND one.k='inbox' AND one.t >= DATE_ADD(NOW(), INTERVAL -30 DAY)" > $t1
		echo "$comstr
			set xlabel \"EMail\" 0, 12
			plot \"$t1\" using 1:3 title \"unread\" with lines, \
				\"$t1\" using 1:2 title \"inbox\" with lines, \
				\"$t1\" using 1:4 title \"load\" with steps lw 3" |
				gnuplot > ~alerque/www/graphs/mail.png
		odb "SELECT UNIX_TIMESTAMP(time), AVG(bytes) FROM host_traffic_log WHERE host='7500' AND direction='tx' AND bytes>='0' AND bytes <'12000' AND time >= DATE_ADD(NOW(), INTERVAL -30 DAY) GROUP BY LEFT(time,15)" > $t1
		odb "SELECT UNIX_TIMESTAMP(time), AVG(bytes) FROM host_traffic_log WHERE host='7500' AND direction='rx' AND bytes>='0' AND bytes <'12000' AND time >= DATE_ADD(NOW(), INTERVAL -30 DAY) GROUP BY LEFT(time,15)" > $t2
		echo "$comstr
			set yrange [ 0:8000 ]
			set xlabel \"DS3 Bandwidth\" 0, 12
			plot \"$t1\" using 1:2 title \"ds3 tx\", \
				\"$t2\" using 1:2 title \"ds3 rx\" " |
				gnuplot > ~alerque/www/graphs/ds3.png
		odb "SELECT UNIX_TIMESTAMP(time), wlantx FROM trango_log WHERE device='1182' AND time >= DATE_ADD(NOW(), INTERVAL -30 DAY)" > $t1
		odb "SELECT UNIX_TIMESTAMP(time), wlanrx FROM trango_log WHERE device='1182' AND time >= DATE_ADD(NOW(), INTERVAL -30 DAY)" > $t2
		odb "SELECT UNIX_TIMESTAMP(time), wlantx FROM trango_log WHERE device='140' AND time >= DATE_ADD(NOW(), INTERVAL -30 DAY)" > $t3
		odb "SELECT UNIX_TIMESTAMP(time), wlanrx FROM trango_log WHERE device='140' AND time >= DATE_ADD(NOW(), INTERVAL -30 DAY)" > $t4
		echo "$comstr
			set yrange [ 0:4000 ]
			set xlabel \"Trango Traffic\" 0, 12
			plot \"$t1\" using 1:2 title \"appt tx\", \
				\"$t2\" using 1:2 title \"appt rx\", \
				\"$t3\" using 1:2 title \"house tx\", \
				\"$t4\" using 1:2 title \"house rx\" " |
				gnuplot > ~alerque/www/graphs/trango.png
		rm -f $t1 $t2 $t3 $t4
		;;
	both)
		$0 log
		$0 graph
		;;
	*)
		;;
esac
