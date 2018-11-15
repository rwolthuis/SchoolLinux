#!/bin/bash
# Script voor automatische provisioning van minion.
# Gemaakt door:		Rick Wolthuis
# Leerling nummer:	335682


# Defineer de shell kleurtjes die gebruikt worden voor de status logging.
RED='\033[0;31m'		# Rode kleur
GREEN='\033[1;32m'		# Groene kleur
GRAY='\033[1;30m'		# Donker grijze kleur
ORANGE='\033[0;33m'		# Orangje kleur
NC='\033[0m'			# Default kleur (NC = Normal Color)



# Functie om een status bericht te laten zien.
function status_msg_show () {

	# Print de status message.
	printf "[${GRAY}BEZIG...${NC}] $1"
}


# Functie om een OK te laten zien als status.
function status_msg_complete () {

	# Vervang [BEZIG... met '[OK      '   
	printf "\r[${GREEN}OK      ${NC}\n"
}


# Functie om een error te laten zien als status.
function status_msg_error () {

	# Vervang [BEZIG... met '[ERROR   '
	printf "\r[${RED}ERROR   ${NC}\n"
}


# Functie om een skipped bericht te laten zien als status.
function status_msg_skipped () {

	# Vervang [BEZIG... met '[SKIPPED '
	printf "\r[${ORANGE}SKIPPED ${NC}\n"
}





# Functie om minions te provisionen.
function provision_minion () {
	
	# Leeg de console.
	clear
	
	# Laat de banner zien.
	banner_show
	
	# Laat wat tekst zien.
	echo "De provisioning van minions is gestart."
	echo ""
	
	# Log.
	status_msg_show "Genereren van Kubenetes join token."
	
	# Maak eerst een nieuwe kubernetes token aan, zodat we altijd een geldige token hebben.
	TOKEN=$(kubeadm token create)
	
	# Haal vervoglens de SHA256 key op.
	SHA256=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
	
	# Geef success.
	status_msg_complete
	
	
	# Log.
	status_msg_show "Klaarmaken van het installatie script."
	
	# Vervang de JOIN variables.
	sed -i "s/KUBERNETES_JOIN_TOKEN=.*/KUBERNETES_JOIN_TOKEN=\"${TOKEN}\"/g" /srv/salt/script/install_docker_kubernetes.sh
	sed -i "s/KUBERNETES_JOIN_SHA256=.*/KUBERNETES_JOIN_SHA256=\"${SHA256}\"/g" /srv/salt/script/install_docker_kubernetes.sh
	
	# Geef success.
	status_msg_complete
	
	
	
	# Log.
	status_msg_show "Provisionen van minions."
	
	# Apply de state op alle minions.
	salt '*' state.apply InitState > /dev/null 2>&1
	
	# Geef success.
	status_msg_complete
	
	
	
	
	# Een laatste new-line.
	echo ""
}



# Functie om de banner te laten zien
function banner_show () {

	# Laat banner zien.
	echo "-"
	echo "- Script gemaakt door Rick Wolthuis (LLN.: 335682)."
	echo "-"
	echo ""
}





# Roep de provision_minion functie aan.
provision_minion
