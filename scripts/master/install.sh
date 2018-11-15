#!/bin/bash
# Script voor automatische installatie van de Master server.
# Gemaakt door:		Rick Wolthuis
# Leerling nummer:	335682


# Array met software dat nodig is.
PREREQUISITES=('curl' 'apt-transport-https' 'ca-certificates' 'gnupg2' 'software-properties-common' 'git')



# Defineer de shell kleurtjes die gebruikt worden voor de status logging.
RED='\033[0;31m'		# Rode kleur
GREEN='\033[1;32m'		# Groene kleur
GRAY='\033[1;30m'		# Donker grijze kleur
ORANGE='\033[0;33m'		# Orangje kleur
NC='\033[0m'			# Default kleur (NC = Normal Color)


# Het plekje waar de join string van kubernetes in wordt opgeslagen.
KUBE_JOIN=''

# Het plekje waar de geselecteerde IP in wordt opgeslagen.
IP_ADDR=''



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


# Functie om de NodeJS install script te downloaden.
function nodejs_fetch () {
	
	# Zoals aangegeven staat, dient bij Ubuntu/Debian de install script gebruikt te worden: https://github.com/nodesource/distributions/blob/master/README.md#deb
	# Geef aan dat we de installatie script van NodeJS aan het downloaden zijn.
	status_msg_show "NodeJS installatie downloaden."
	
	# Download de install script van NodeJS, en sla hem op in /tmp/install_nodejs.sh.
	curl -sL https://deb.nodesource.com/setup_11.x -o /tmp/install_nodejs.sh
	
	# Geef completed aan.
	status_msg_complete
}


# Functie om NodeJS te installeren.
function nodejs_install () {

	# Geef weer een bericht.
	status_msg_show "NodeJS installeren."
	
		# Is nodejs al geinstalleerd?
		if ! type "nodejs" > /dev/null 2>&1; then
			
			# Nee, nog niet. Run het script nu.
			sh /tmp/install_nodejs.sh > /dev/null 2>&1
			
			# Installeer NodeJS nu via de package manager.
			apt-get install -y nodejs > /dev/null 2>&1
			
			# Installeer forever globaal, voor het runnen van een nodejs service.
			npm install -g forever > /dev/null 2>&1
			
			# Geef completed aan.
			status_msg_complete
		else
		
			# NodeJS is al geinstalleerd.
			status_msg_skipped
		fi
}


# Functie om te kijken of NodeJS geinstalleerd is.
function nodejs_validate () {

	# Geef bericht weer.
	status_msg_show "NodeJS installatie controleren."
	
		# Bestaat de nodejs commando?
		if ! type "nodejs" > /dev/null 2>&1; then
		
			# NodeJS is niet geinstalleerd. Geef foutmelding.
			status_msg_error
			
			# Exit nu.
			exit
		else
		
			# Echo een OK.
			status_msg_complete
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


# Functie om een salt-stack master te installeren.
function saltstack_install () {

	# Geef weer een bericht.
	status_msg_show "SaltStack master installatie."
	
		# Is saltstack al geinstalleerd?
		if ! type "salt" > /dev/null 2>&1; then
			
			# Nee, nog niet. Run het script nu.
			sh /tmp/install_salt.sh -M > /dev/null
			
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
		if ! type "salt" > /dev/null 2>&1; then
		
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
			
			# En daarin een scripts map.
			mkdir -p /srv/salt/script > /dev/null 2>&1
			
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


# Functie om docker binnen te halen, in dit geval het toevoegen van een repository.
function docker_fetch () {
	
	# Geef bericht weer.
	status_msg_show "Docker repository toevoegen."
	
	# Download de GPG key.
	curl -fsSL https://download.docker.com/linux/debian/gpg -o /tmp/docker_gpg
	
	# Voeg de GPG key toe.
	apt-key add /tmp/docker_gpg > /dev/null 2>&1
	
	# Voeg de repository toe.
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /dev/null 2>&1
	
	# En doe als laatste een apt-get update, zodat de packages van de nieuwe respository worden toegevoegd.
	apt-get update > /dev/null 2>&1
	
	# Geef complete weer.
	status_msg_complete
}
	
	
# Functie om docker te installeren
function docker_install () {
	
	# Geef bericht weer.
	status_msg_show "Docker installeren."
	
		# Is docker al geinstalleerd?
		if ! type "docker" > /dev/null 2>&1; then
			
			# Installeer nu docker-ce versie 18.06.01 (omdat de nieuwste niet met kubenetes werkt).
			apt-get install -y docker-ce=18.06.1~ce~3-0~debian > /dev/null
			
			# Echo een OK.
			status_msg_complete
		else
		
			# Docker is al geinstalleerd.
			status_msg_skipped
		fi
}


# Functie om docker te valideren.
function docker_validate () {
	
	# Geef bericht weer.
	status_msg_show "Docker installatie controleren."
	
		# Bestaat de docker commando?
		if ! type "docker" > /dev/null 2>&1; then
		
			# Docker is niet geinstalleerd. Geef foutmelding.
			status_msg_error
			
			# Exit nu.
			exit
		else
		
			# Haal de docker versie op.
			# DOCKERVERSION=$(docker --version)
			
			# Echo een OK.
			status_msg_complete
		fi
}


# Functie om de repository van kubernetes toe te voegen.
function kubernetes_fetch () {
	
	# Geef bericht weer.
	status_msg_show "Kubernetes repository toevoegen."
	
	# Download de GPG key.
	curl -fsL https://packages.cloud.google.com/apt/doc/apt-key.gpg -o /tmp/kubernetes_gpg
	
	# Voeg de GPG key toe.
	apt-key add /tmp/kubernetes_gpg > /dev/null 2>&1
	
	# Voeg de repository toe.
	add-apt-repository "deb https://apt.kubernetes.io/ kubernetes-xenial main"
	
	# En doe als laatste een apt-get update, zodat de packages van de nieuwe respository worden toegevoegd.
	apt-get update > /dev/null 2>&1
	
	# Geef complete weer.
	status_msg_complete
}


# Functie om kubernetes te installeren.
function kubernetes_install () {
	
	# Geef bericht weer.
	status_msg_show "Kubernetes installeren."
	
		# Is kubernetes al geinstalleerd?
		if [ $(is_package_installed "kubelet") -eq 0 ] || [ $(is_package_installed "kubeadm") -eq 0 ] || [ $(is_package_installed "kubectl") -eq 0 ]; then
		
			# Niet alle pakketten zijn geinstalleerd. Installeer de kubernetes pakketten.
			apt-get install -y kubelet kubeadm kubectl > /dev/null 2>&1
			
			# Zorg ervoor dat de geinstalleerde pakketten niet automatische worden geupdate.
			apt-mark hold kubelet kubeadm kubectl > /dev/null 2>&1
			
			# Echo een OK.
			status_msg_complete
		else
		
			# Docker is al geinstalleerd.
			status_msg_skipped
		fi
}


# Functie om de kubernetes installatie te controleren.
function kubernetes_validate () {

	# Geef bericht weer.
	status_msg_show "Kubernetes installatie controleren."
	
		# Bestaat de docker commando?
		if ! type "kubelet" > /dev/null && ! type "kubeadm" > /dev/null && ! type "kubectl" > /dev/null; then
		
			# Docker is niet geinstalleerd. Geef foutmelding.
			status_msg_error
			
			# Exit nu.
			exit
		else
		
			# Echo een OK.
			status_msg_complete
		fi
}


# Functie om kubernetes te configureren
function kubernetes_configure () {
	
	# Swap uitschakelen.
	status_msg_show "Uitschakelen van de swap partitie."
	
	# Haal de inhoud van de 3e kolom uit de fstab file. Zoek dan binnen alle regels het woord 'swap' en geef hiervan de regel nummer,
	# welke nu bestaat uit bijv '11:swap'. Gebruik cut om alleen 11 te krijgen.
	SWAPLINE=$(cat /etc/fstab | awk '{print $3}' | grep -n swap | cut -d : -f 1)
	
	# Gebruik sed om een # voor de swap regel te zetten, zodat deze weg gecomment is en niet meer opnieuw gemount wordt bij een reboot.
	$(sed -i "${SWAPLINE}s/^/#/" /etc/fstab) > /dev/null 2>&1
	
	# Schakel swap nu uit.
	$(swapoff -a) > /dev/null 2>&1
	
	# Geef een OK.
	status_msg_complete
	
	
	
	# Geef bericht weer.
	status_msg_show "Kubernetes configureren."
	
	# Geef aan dat gebridge IPv4 verkeer naar de iptables chains gestuurd moet worden.
	sysctl net.bridge.bridge-nf-call-iptables=1 > /dev/null 2>&1
	
	# Start kubeadm, en sla de output op in de 'output_array' array, waarbij elke new line een element in de array wordt.
	mapfile -t output_array < <( kubeadm init --apiserver-advertise-address=${IP_ADDR} 2> /dev/null )
	
	# Pak nu de enelaatste regel, deze bevat de join regel voor kubernetes met de token en sha256 key.
	KUBE_JOIN=${output_array[-2]}
	
	# Maak een map aan in de home map van de gebruiker met de naam '.kube'. (/root? :D).
	mkdir -p $HOME/.kube > /dev/null 2>&1
	
	# Kopieer de admin.conf nu naar de zojuist aangemaakte map in de home directory.
	cp /etc/kubernetes/admin.conf $HOME/.kube/config > /dev/null 2>&1
	
	# Verander nu de owner van de config file naar de gebruiker van de $HOME map.
	chown $(id -u):$(id -g) $HOME/.kube/config > /dev/null 2>&1
	
	# Installeer de Weave Net pod network add-on voor kubernetes.
	kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')" > /dev/null 2>&1
	
	# Geef een OK.
	status_msg_complete	
}


# Functie om Wordpress te installeren in kubernetes.
function kubernetes_wordpress () {

	# Geef bericht weer.
	status_msg_show "Wordpress pod aanmaken in Kubernetes."
	
	# Maak een MysQL password aan.
	kubectl create secret generic mysql-pass --from-literal=password=P@$$w0rd > /dev/null 2>&1
	
	# Maak de PV mappen aan.
	mkdir -p /var/lib/pv1 /var/lib/pv2 > /dev/null 2>&1
	
	# Maak een de PV aan.
	kubectl create -f /home/repository/kubernetes/pv.yaml > /dev/null 2>&1
	
	# Deploy MySQL.
	kubectl create -f /home/repository/kubernetes/mysql-deployment.yaml > /dev/null 2>&1
	
	# En deploy wordpress.
	kubectl create -f /home/repository/kubernetes/wordpress-deployment.yaml --validate=false > /dev/null 2>&1
	
	# Geef een OK.
	status_msg_complete	
}


# Functie om apache te installeren
function apache_install () {

	# Geef bericht weer.
	status_msg_show "Apache2 installeren."
	
	# Installeer apache.
	apt-get install -y apache2 > /dev/null 2>&1
	
	# Configure rewrite mod.
	a2enmod rewrite > /dev/null 2>&1
	
	# Geef success.
	status_msg_complete
}


# Functie om PHP te installeren
function php_install () {

	# Geef bericht weer.
	status_msg_show "PHP7.0 installeren."
	
	# Installeer apache.
	apt-get install -y php7.0 php7.0-cli libapache2-mod-php7.0 php7.0-curl php7.0-json > /dev/null 2>&1
	
	# Geef success.
	status_msg_complete
}


# Functie om files uit de git respository te halen.
function git_fetch () {
	
	# Geef bericht weer.
	status_msg_show "Git repository clonen."
	
	# Clone de repository naar de /home/repository map.
	git clone https://github.com/rwolthuis/SchoolLinux.git /home/repository > /dev/null 2>&1
	
	# Kopieer de install script naar de saltstack fileserver.
	cp /home/repository/scripts/minion/install_docker_kubernetes.sh /srv/salt/script/install_docker_kubernetes.sh
	
	# Kopieer de init state naar de saltstack fileserver.
	cp /home/repository/salt/InitState.sls /srv/salt/InitState.sls
	
	# Geef success.
	status_msg_complete
}


# Functie om de nodejs server op te zetten.
function nodejs_activate () {
	
	# Geef bericht weer.
	status_msg_show "SSL-certificaat genereren."
	
	# Maak de map aan, mocht git die niet mee genomen hebben.
	mkdir -p /home/repository/nodejs/master/cert > /dev/null 2>&1
	
	# Maak ook een PID map aan.
	mkdir -p /home/repository/nodejs/master/pid > /dev/null 2>&1
	
	# Maak een 4096 bit key.
	openssl genrsa -out /home/repository/nodejs/master/cert/server-key.pem 4096 > /dev/null 2>&1
	
	# Maak een CSR aan.
	openssl req -new -key /home/repository/nodejs/master/cert/server-key.pem -out /home/repository/nodejs/master/cert/server-csr.pem -subj "/C=NL/ST=A/L=B/O=C/CN=localhost" > /dev/null 2>&1
	
	# Maak nu een selfsigned certificaat aan.
	openssl x509 -req -in /home/repository/nodejs/master/cert/server-csr.pem -signkey /home/repository/nodejs/master/cert/server-key.pem -out /home/repository/nodejs/master/cert/server-cert.pem > /dev/null 2>&1
	
	# Geef success.
	status_msg_complete
	
	
	
	# Geef bericht weer.
	status_msg_show "Log- en monitoring server activeren."
	
	# Kopieer de service file vanuit de repo naar de init.d map.
	mv /home/repository/nodejs/master/logmonitorserver /etc/init.d/logmonitorserver > /dev/null 2>&1
	
	# Geef het script de juiste rechten.
	chmod a+x /etc/init.d/logmonitorserver > /dev/null 2>&1
	
	# Maak de service aan.
	update-rc.d logmonitorserver defaults > /dev/null 2>&1
	
	# Reload de systemctl daemon.
	systemctl daemon-reload > /dev/null 2>&1
	
	# Start de service.
	service logmonitorserver restart > /dev/null 2>&1
	
	# Geef success.
	status_msg_complete
}





# Functie om te starten met de installatie van de benodigde pakketten.
function install_master_server () {
	
	# Leeg de console.
	clear
	
	# Laat de banner zien.
	banner_show
	
	# Laat wat tekst zien.
	echo "De installatie van de master server is gestart."
	echo ""
	
	
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
	
	
	# Fetch NodeJS.
	nodejs_fetch
	
	# Installeer NodeJS
	nodejs_install
	
	# Controleer of nodejs geinstalleerd is.
	nodejs_validate
	
	
	# Fetch saltstack.
	saltstack_fetch
	
	# Installeer saltstack.
	saltstack_install
	
	# Controleer of saltstack geinstalleerd is.
	saltstack_validate
	
	# Configureer saltstack.
	saltstack_configure
	
	
	# Fetch docker.
	docker_fetch
	
	# Installeer docker
	docker_install
	
	# Valideer docker
	docker_validate
	
	
	# Haal de files uit de git repository.
	git_fetch	
	
	
	# Fetch kubernetes
	kubernetes_fetch
	
	# Installeer kubernetes
	kubernetes_install
	
	# Valideer kubernetes
	kubernetes_validate
	
	# Configureer kubernetes
	kubernetes_configure
	
	# Installeer wordpress in kubernetes.
	kubernetes_wordpress
	
	
	# Installeer Apache
	apache_install
	
	
	# Installeer php
	php_install
	
	
	# Zet de nodejs server aan.
	nodejs_activate
	
	
	# chmod provision_minion.sh zodat die direct gerunt kan worden.
	chmod +x /home/repository/scripts/master/provision_minion.sh > /dev/null
	
	
	# New line
	echo ""
	
	# Uitleg.
	echo "Accepteer de salt minions met salt-key -A, en run vervolgens het provisioning script:"
	echo "	/home/repository/scripts/master/provision_minion.sh"
	
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
	echo "1) Installatie voor master server starten"
	echo "2) Script afsluiten"
	echo ""
	
	# Vraag om een input van de gebruiker dat bestaat uit 1 char, en niet weiger backslashes.
	read -n1 -r -p "Kies een optie [1 - 2]: " optie
	
	# Case de optie.
	case $optie in
		1) menu_show_ip ;;										# Ga naar het IP kies menu.
		2) echo "" && exit 0;;									# Er is gekozen om het script af te sluiten.
		*) echo -e "Onbekende optie." && sleep 2 && menu_show	# Er is geen 1, 2 of 3 ingevuld. Echo een foutmelding, wacht 2 seconde en laat het menu opnieuw zien.
	esac
}



# Functie om een IP adres te selecteren.
function menu_show_ip () {
	
	# Leeg de console.
	clear

	# Laat de banner zien.
	banner_show
	
	# Geef aan wat de bedoeling is.
	echo "Kies in de onderstaande lijst het IP waar de server op moet luisteren."
	
	# Lege regel.
	echo ""
	
	# Haal de lijst met IPv4's op.
	# Bron: https://stackoverflow.com/questions/12523872/bash-script-to-get-all-ip-addresses/12624100#comment42263284_12624100
	IP_LIST=($(ip -o addr show scope global | awk '{gsub(/\/.*/, " ",$4); print $4}'))
	
		# Loop door de IP_LIST.
		for i in "${!IP_LIST[@]}"
		do
			# Laat de optie zien.
			echo "$(($i+1))) ${IP_LIST[$i]}"
		done
	
	# Lege regel.
	echo ""
	
	# Vraag om een optie van de gebruiker.
	read -n1 -r -p "Kies een optie [1 - ${#IP_LIST[@]}]: " ip_optie
	
	# Lege regel.
	echo ""
	
		# Is de ingevulde optie binnen de range en hoger dan 0?
		if [ "$ip_optie" -le ${#IP_LIST[@]} ] && ! [ "$ip_optie" -lt 1 ] ; then
		
			# Ja, tel -1 van de nummer af (zodat deze weer gelijk lopen met de index van de IP_LIST array) en sla de keuze op in IP_ADDR.
			IP_ADDR=${IP_LIST[((${ip_optie}-1))]}
			
			# Start nu de installatie.
			install_master_server
		else
		
			# Nee, ongeldige keuze. Geef foutmelding.
			read -n1 -r -p "Ongelidge keuze. Druk op een toets om nog een keer te proberen. "
			
			# Roep menu_show_ip nogmaals aan.
			menu_show_ip
		fi
}



# Roep de menu_show functie aan.
menu_show

