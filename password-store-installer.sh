#!/usr/bin/env bash

###########################
# This script init and restore personal password-store repo solution
# @author Thomas Letsch Groch
###########################

# trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG

# include library helpers for colorized
source ./lib/echos.sh

ask.transcrypt.password(){
    while [ -z "$response_transcrypt" ]; do
        read -r -p "What is your password for decrypt transcrypt? " response_transcrypt
    done
}
ask.username.on(){
    while [ -z "$response_username" ]; do
        read -r -p "What is your username on $1? " response_username
    done
}
ask.custom.repo(){
    while [ -z "$response_custom" ]; do
        read -r -p "Where is password-store git repository? (must be a clonable git URL) " response_custom
    done
}
ask.provider() {
	PS3=$1

	options=("Gitlab")
	options+=("GitHub")
	options+=("Bitbucket")
	# options+=("KeyBase")
	options+=("Custom")
	options+=("Quit")

	select opt in "${options[@]}"; do
	    case $opt in
	        "Gitlab")
				ask.username.on $opt
	            http_url_to_repo="https://gitlab.com/${response_username}/password-store.git"
	            break
	            ;;
	        "GitHub")
				ask.username.on $opt
	            http_url_to_repo="https://github.com/${username}/password-store.git"
	            break
	            ;;
	        "Bitbucket")
				ask.username.on $opt
	            http_url_to_repo="https://${username}@bitbucket.org/${username}/password-store.git"
	            break
	            ;;
	        "Custom")
	            echo "Ok, using $opt" >&2
	            ask.custom.repo
	            http_url_to_repo=$response_custom
	            break
	            ;;
	        "Quit")
	            echo "Quitting.." >&2
	            exit 0;;
	        *) echo "invalid option $REPLY" >&2;exit 1;
	    esac
	done
}

bot "Hi! I'm going to configure password-store on your system.\nYou supposed use gpg-suite to generate and have GPG already imported.\nHere I go..."


if brew ls --versions pass > /dev/null; then
	ok "pass installed."
else
	error "you must have pass installed"
	exit 1
fi


# # TODO: Import GPG keypair.
# $ gpg --import pubkey.asc
# $ gpg --allow-secret-key-import --import privkey.asc

gpg_email=$(gpg --list-keys --fingerprint | grep uid | awk -F"[<>]" '{print $2}')

echo -e "The best I can make out, your GPG email address is $COL_YELLOW$gpg_email$COL_RESET"
read -r -p "Is this correct? (Y|n) [default=Y] " response
response=${response:-Y}

if [[ $response =~ ^(no|n|N) ]];then
	read -r -p "What is your GPG email? " gpg_email
	if [[ ! $gpg_email ]];then
		error "you must provide an email as gpg fingerprint"
		exit 1
	fi
fi

read -r -p "(I)nitialize or (R)estore [default=R] " response
response=${response:-Y}
if [[ $response =~ (i|I) ]];then
	
	ask.provider 'Where should password-store repo should be initialized? '
	warn "This remote repository should exist: ${http_url_to_repo}"

	bot "Creating local password-store repository "
    read -n 1 -s -r -p "Press any key to continue"

	action "pass init ${gpg_email}"
	pass init "${gpg_email}"
	cd /Users/$(whoami)/.password-store
	ok "~/.password-store created"

	action "pass git init"
	pass git init;ok

	action "pass git remote add origin ${http_url_to_repo}"
	pass git remote add origin $http_url_to_repo

	ok 'Local password-store repository initialized. Now let me transcrypt it.'


	action "transcrypt -c aes-256-cbc"
	transcrypt -c aes-256-cbc
	cat > .gitattributes << EOF
*.gpg filter=crypt diff=crypt
*.key filter=crypt diff=crypt
*.properties filter=crypt diff=crypt
*.jks filter=crypt diff=crypt
EOF
	warn "Save your password on a safe place."
	ok 'Local password-store repository transcrypted.'


	bot "Adding example password and commit."
	pass generate Others/example.com 15

	bot "Now I'm going to push it to: \n${http_url_to_repo}"
	read -n 1 -s -r -p "Press any key to continue"

    action "git add . && git commit -m \"Initial password-store commit\" && git push -u origin master"
	git add . && git commit -m "Initial password-store commit" && git push -u origin master
	ok

	bot "Password-store repository are now available on: \n${http_url_to_repo}"

elif [[ $response =~ (q|Q) ]];then
	echo "Quitting.." >&2
    exit 0
elif [[ $response =~ (d|D) ]];then
	echo "deleting.." >&2
	rm -Rf /Users/$(whoami)/.password-store
    exit 0
else


	ask.provider 'Where is your password-store repo? '

	bot "Restoring from remote repository: \n${http_url_to_repo}"
	read -n 1 -s -r -p "Press any key to continue"

	action "git clone ${http_url_to_repo} /Users/$(whoami)/.password-store"
	git clone $http_url_to_repo /Users/$(whoami)/.password-store
	ok "Repository downloaded"

	bot "Unlocking local password-store"
	cd /Users/$(whoami)/.password-store
	ask.transcrypt.password
	action "transcrypt -c aes-256-cbc -p ${response_transcrypt}"
	transcrypt -c aes-256-cbc -p "${response_transcrypt}"
	ok "store transcrypt unlocked"


	bot "Done. Your store should be available."

fi
