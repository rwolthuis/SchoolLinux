/*
	Script gemaakt door Rick Wolthuis (LLN.: 335682).
*/

/* Maak een transport object. */
const Transport = require ('./class/Transport');

/* Require LogServer. */
const LogServer = require ('./class/LogServer');



/* Defineer een globaal config object. */
global.config = {
	
	/* De poort waarop de log en monitoring servers draaien (TCP). */
	server_port: 1234,
	
	
	/* Salt gedeelte. */
	salt: {
		
		/* De path naar de geaccepteerde minions. */
		minion_path: '/etc/salt/pki/master/minions',
		
		/* De path naar de private key van de master. */
		private_key: '/etc/salt/pki/master/master.pem'
	},
	
	
	/* Log server gedeelte. */
	log: {
		
		/* De path waar de logs opgeslagen moeten worden (zonder / aan het einde). */
		log_path: '/var/log/rwlogging'
	}
	
};


/* Maak een globaal LogServer object. */
global.logserver = new LogServer;

/* Maak een globaal transport object. */
global.transport = new Transport;

