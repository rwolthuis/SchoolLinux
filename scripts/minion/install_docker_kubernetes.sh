#!/bin/bash
# Script voor automatische installatie voor de verschillende software pakketten.
# Gemaakt door:		Rick Wolthuis
# Leerling nummer:	335682


# Array met software dat nodig is.
PREREQUISITES=('curl' 'apt-transport-https' 'ca-certificates' 'gnupg2' 'software-properties-common' 'git')



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





# Functie om prerequisites te installeren
function install_prerequisites () {

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
		fi
}


# Functie om de NodeJS install script te downloaden.
function nodejs_fetch () {
	
	# Zoals aangegeven staat, dient bij Ubuntu/Debian de install script gebruikt te worden: https://github.com/nodesource/distributions/blob/master/README.md#deb
	# Download de install script van NodeJS, en sla hem op in /tmp/install_nodejs.sh.
	curl -sL https://deb.nodesource.com/setup_11.x -o /tmp/install_nodejs.sh
}


# Functie om NodeJS te installeren.
function nodejs_install () {

	# Is nodejs al geinstalleerd?
	if ! type "nodejs" > /dev/null 2>&1; then
		
		# Nee, nog niet. Run het script nu.
		sh /tmp/install_nodejs.sh > /dev/null 2>&1
		
		# Installeer NodeJS nu via de package manager.
		apt-get install -y nodejs > /dev/null 2>&1
		
		# Installeer forever globaal, voor het runnen van een nodejs service.
		npm install -g forever > /dev/null 2>&1
	fi
}




# Functie om docker binnen te halen, in dit geval het toevoegen van een repository.
function docker_fetch () {
	
	# Download de GPG key.
	curl -fsSL https://download.docker.com/linux/debian/gpg -o /tmp/docker_gpg
	
	# Voeg de GPG key toe.
	apt-key add /tmp/docker_gpg > /dev/null 2>&1
	
	# Voeg de repository toe.
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
	
	# En doe als laatste een apt-get update, zodat de packages van de nieuwe respository worden toegevoegd.
	apt-get update > /dev/null 2>&1
}
	
	
# Functie om docker te installeren
function docker_install () {

	# Is docker al geinstalleerd?
	if ! type "docker" > /dev/null 2>&1; then
		
		# Installeer nu docker-ce versie 18.06.01 (omdat de nieuwste niet met kubenetes werkt).
		apt-get install -y docker-ce=18.06.1~ce~3-0~debian > /dev/null
	fi
}




# Functie om de repository van kubernetes toe te voegen.
function kubernetes_fetch () {
	
	# Download de GPG key.
	curl -fsL https://packages.cloud.google.com/apt/doc/apt-key.gpg -o /tmp/kubernetes_gpg
	
	# Voeg de GPG key toe.
	apt-key add /tmp/kubernetes_gpg > /dev/null 2>&1
	
	# Voeg de repository toe.
	add-apt-repository "deb https://apt.kubernetes.io/ kubernetes-xenial main"
	
	# En doe als laatste een apt-get update, zodat de packages van de nieuwe respository worden toegevoegd.
	apt-get update > /dev/null 2>&1
}


# Functie om kubernetes te installeren.
function kubernetes_install () {
	
	# Is kubernetes al geinstalleerd?
	if [ $(is_package_installed "kubelet") -eq 0 ] || [ $(is_package_installed "kubeadm") -eq 0 ] || [ $(is_package_installed "kubectl") -eq 0 ]; then
	
		# Niet alle pakketten zijn geinstalleerd. Installeer de kubernetes pakketten.
		apt-get install -y kubelet kubeadm kubectl > /dev/null 2>&1
		
		# Zorg ervoor dat de geinstalleerde pakketten niet automatische worden geupdate.
		apt-mark hold kubelet kubeadm kubectl > /dev/null 2>&1
	fi
}


# Functie om kubernetes te configureren
function kubernetes_configure () {
	
	# Haal de inhoud van de 3e kolom uit de fstab file. Zoek dan binnen alle regels het woord 'swap' en geef hiervan de regel nummer,
	# welke nu bestaat uit bijv '11:swap'. Gebruik cut om alleen 11 te krijgen.
	SWAPLINE=$(cat /etc/fstab | awk '{print $3}' | grep -n swap | cut -d : -f 1)
	
	# Gebruik sed om een # voor de swap regel te zetten, zodat deze weg gecomment is en niet meer opnieuw gemount wordt bij een reboot.
	$(sed -i "${SWAPLINE}s/^/#/" /etc/fstab) > /dev/null 2>&1
	
	# Schakel swap nu uit.
	$(swapoff -a) > /dev/null 2>&1
	
	# Defineer de kubenetus variables.
	KUBERNETES_MASTER_IP=$(cat /etc/salt/minion.d/99-master-address.conf | cut -d: -f 2)
	KUBERNETES_MASTER_PORT=6443
	KUBERNETES_JOIN_TOKEN=''
	KUBERNETES_JOIN_SHA256=''
	
	# Join de kubernetes master.
	kubeadm join ${KUBERNETES_MASTER_IP}:${KUBERNETES_MASTER_PORT} --token ${KUBERNETES_JOIN_TOKEN} --discovery-token-ca-cert-hash sha256:${KUBERNETES_JOIN_SHA256}
}


# Functie om files uit de git respository te halen.
function git_fetch () {
	
	# Clone de repository naar de /home/repository map.
	git clone https://github.com/rwolthuis/SchoolLinux.git /home/repository > /dev/null 2>&1
	
	# Kopieer de service file vanuit de repo naar de init.d map.
	mv /home/repository/nodejs/minion/logmonitorserver /etc/init.d/logmonitorserver > /dev/null 2>&1
	
	# Geef het script de juiste rechten.
	chmod a+x /etc/init.d/logmonitorserver > /dev/null 2>&1
	
	# Maak de service aan.
	update-rc.d logmonitorserver defaults > /dev/null 2>&1
	
	# Reload de systemctl daemon.
	systemctl daemon-reload > /dev/null 2>&1
	
	# Start de service.
	service logmonitorserver restart > /dev/null 2>&1
}





# Functie om de installatie van de benodigde software te starten.
function install_software () {
	
	# Doe een apt-get update.
	apt-get update > /dev/null
	
	# Doe een apt-get upgrade.
	apt-get upgrade -y > /dev/null
	
	
	
	# Installeer de prerequisites.
	install_prerequisites
	
	
	# Fetch NodeJS.
	nodejs_fetch
	
	# Installeer NodeJS
	nodejs_install
	
	
	# Fetch docker.
	docker_fetch
	
	# Installeer docker
	docker_install
	
	
	# Fetch kubernetes
	kubernetes_fetch
	
	# Installeer kubernetes
	kubernetes_install
	
	# Configureer kubernetes
	kubernetes_configure
	
	
	# Clone de git repository
	git_fetch
}




# Roep de menu_show functie aan.
install_software



