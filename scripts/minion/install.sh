#!/bin/bash
# Script voor automatische installatie van een slave server
# Gemaakt door:		Rick Wolthuis
# Leerling nummer:	335682



# Defineer de shell kleurtjes die gebruikt worden voor de status logging.
RED='\033[0;31m'		# Rode kleur
GREEN='\033[1;32m'		# Groene kleur
GRAY='\033[1;30m'		# Donker grijze kleur
ORANGE='\033[0;33m'		# Orangje kleur
NC='\033[0m'			# Default kleur (NC = Normal Color)

# Array met software dat nodig is.
PREREQUISITES=('curl' 'apt-transport-https' 'ca-certificates')


# Het plekje waar de geselecteerde IP in wordt opgeslagen.
MASTER_IP=''



# Functie om een array te joinen.
# Bron: https://zaiste.net/how_to_join_elements_of_an_array_in_bash/
function array_to_string {

	# Maak een lokale var IFS, alleen beschikbaar in deze functie. Deze var bevat de delimiter voor het joinen van de array stukjes.
	local IFS="$1";
	
	# Shift, verwijder het eerst volgende array item (de IFS).
	shift;
	
	# Laat de rest van de array zien, en gebruik de IFS variable om de stukjes te joinen.
	echo "$*";
}



# Functie om te kijken of een package geinstalleerd is.
function is_package_installed () {
	
	# Informatie ophalen van de opgevraagde pakket ($1), en tel hoe vaak 'ok installed' voor komt d.m.v. grep.
	# Bron: https://stackoverflow.com/a/22592801
	if [ $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
		
		# Pakket is niet geinstalleerd omdat 'ok installed' niet is voor gekomen in de output. Echo 0.
		echo 0
	else
	
		# Pakket is geinstalleerd omdat 'ok installed' meer dan 0x is voor gekomen in de output. Echo 1.
		echo 1
	fi
}



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



# Functie om prerequisites te installeren
function install_prerequisites () {

	# Laat zien dat we prerequisites aan het installeren zijn.
	status_msg_show "Installatie van prerequisites."

	# Maak een install var.
	INSTALL=0
	
		# Doorloop alle prerequisites.
		for i in ${PREREQUISITES[@]}; do
		
			# Check of de betreffende software al geinstalleerd is.
			if [ $(is_package_installed $i) -eq 0 ]; then
			
				# Zet install op 1.
				INSTALL=1
				
				# Break nu, zodat we niet verder loopen.
				break
			fi
		done
	
		# Is INSTALL 1? 
		if [ ${INSTALL} -eq 1 ]; then
			
			# Ja, join de prerequisites array met spaties.
			INSTALL_STRING=$(array_to_string " " ${PREREQUISITES[@]})
			
			# Installeer de prerequisites.
			apt-get install -y ${INSTALL_STRING} > /dev/null
			
			# Geef completed aan.
			status_msg_complete
		else
		
			# Geef skipped aan.
			status_msg_skipped
		fi
}



# Functie om saltstack bootstrap te downloaden.
function saltstack_fetch () {
	
	# Geef aan dat we de installatie script van saltstack aan het downloaden zijn.
	status_msg_show "SaltStack bootstrap downloaden."
	
	# Download de bootstrap saltstack script, en sla hem op in /tmp/install_salt.sh.
	curl -sL https://bootstrap.saltstack.com -o /tmp/install_salt.sh
	
	# Echo een OK.
	status_msg_complete
}



# Functie om een salt-stack slave te installeren.
function saltstack_install () {

	# Geef weer een bericht.
	status_msg_show "SaltStack slave installatie met master naar ${MASTER_IP}."
	
		# Is saltstack al geinstalleerd?
		if ! type "salt" > /dev/null 2>&1; then
			
			# Nee, nog niet. Run het script nu.
			sh /tmp/install_salt.sh -A ${MASTER_IP} > /dev/null
			
			# Echo een OK.
			status_msg_complete
		else
		
			# Salt is al geinstalleerd.
			status_msg_skipped
		fi
}



# Functie om te kijken of saltstack geinstalleerd is.
function saltstack_validate () {

	# Geef bericht weer.
	status_msg_show "SaltStack installatie controleren."
	
		# Bestaat de salt commando?
		if ! type "salt-minion" > /dev/null 2>&1; then
		
			# Saltstack is niet geinstalleerd. Geef foutmelding.
			status_msg_error
			
			# Exit nu.
			exit
		else
		
			# Echo een OK.
			status_msg_complete
		fi
}



# Functie om een salt-stack master te configureren.
function saltstack_configure () {
	
	# Geef bericht weer.
	status_msg_show "SaltStack configureren."
	
	# Haal de laatste lijn uit de configuratie op.
	LASTLINE=$(awk '/./{line=$0} END{print line}' /etc/salt/master)
	
		# Is file_roots al geconfigureerd?
		if [ "${LASTLINE}" != "    - /srv/salt" ]; then
		
			# Nee, set de salt state tree.
			echo '' >> /etc/salt/master
			echo 'file_roots:' >> /etc/salt/master
			echo '  base:' >> /etc/salt/master 
			echo '    - /srv/salt' >> /etc/salt/master
			
			# Maak de /srv/salt map aan.
			mkdir -p /srv/salt > /dev/null 2>&1
			
			# Restart de saltmaster nu.
			pkill salt-master > /dev/null 2>&1
			salt-master -d > /dev/null 2>&1
			
			# Echo een OK.
			status_msg_complete
		else
			# Salt stack is al geinstalleerd. Skip.
			status_msg_skipped
		fi
}




# Functie om een master server in te voeren en te controleren d.m.v. een ping.
function ping_check () {

	# Maak een oneindige while loop.
	while true
	do
		# Lege regel.
		echo ""
		
		# Vraag om het IP van de master server.
		read -r -p "Vul het IP-adres in van de master server: " INPUT_IP
		
		# Sla het master IP op.
		MASTER_IP=${INPUT_IP}
		
		# Lege regel.
		echo ""
		
		# Laat zien wat we doen.
		status_msg_show "Ping check naar IP ${MASTER_IP}."
		
		# Voer een ping uit op het ingevulde IP.
		PING_RES=$(ping -c 1 ${MASTER_IP} > /dev/null 2>&1 ; echo $?)
		
			# Is de ping gelukt?
			if [ "${PING_RES}" -eq 0 ]; then
				
				# Ja, geef OK.
				status_msg_complete
				
				# Break de while loop nu.
				break
			else
			
				# Nee, geef Error
				status_msg_error
			fi	
	done
}



# Functie om te starten met de installatie van de benodigde pakketten.
function install_slave_server () {
	
	# Leeg de console.
	clear
	
	# Laat de banner zien.
	banner_show
	
	# Laat wat tekst zien.
	echo "De installatie van de slave server is gestart."
	
	
	# Voer een ping check uit.
	ping_check
	
	
	# Laat zien wat we doen.
	status_msg_show "Apt-get update uitvoeren."
	
	# Doe een apt-get update.
	apt-get update > /dev/null
	
	# Zeg dat we klaar zijn.
	status_msg_complete
	
	# Laat zien wat we doen.
	status_msg_show "Apt-get upgrade uitvoeren."
	
	# Doe een apt-get upgrade.
	apt-get upgrade -y > /dev/null
	
	# Zeg dat we klaar zijn.
	status_msg_complete
	
	
	# Installeer de prerequisites.
	install_prerequisites
	
	
	# Fetch saltstack.
	saltstack_fetch
	
	# Installeer saltstack.
	saltstack_install
	
	# Controleer of saltstack geinstalleerd is.
	saltstack_validate
	
	
	# Echo een nieuwe line.
	echo ""
	
	# Maak een verhaaltje
	echo "De minion versie van SaltStack is nu geinstalleerd. Accepteer de key op de master om de verbinding tot stand te brengen."
	
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



# Functie om het menu te laten zien.
function menu_show () {

	# Leeg de console.
	clear

	# Laat de banner zien.
	banner_show
	
	# Maak een banner aan.
	echo "1) Installatie voor slave server starten"
	echo "2) Script afsluiten"
	echo ""
	
	# Vraag om een input van de gebruiker dat bestaat uit 1 char, en niet weiger backslashes.
	read -n1 -r -p "Kies een optie [1 - 2]: " optie
	
	# Case de optie.
	case $optie in
		1) install_slave_server ;;								# Start de installatie.
		2) echo "" && exit 0;;									# Er is gekozen om het script af te sluiten.
		*) echo -e "Onbekende optie." && sleep 2 && menu_show	# Er is geen 1, 2 of 3 ingevuld. Echo een foutmelding, wacht 2 seconde en laat het menu opnieuw zien.
	esac
}



# Roep de menu_show functie aan.
menu_show
