/* Require fs. */
const fs = require('fs');

/* Require Transport. */
const Transport = require ('./class/Transport');

/* Require de LogManager. */
const LogManager = require ('./class/LogManager');



/* Maak een globale config. */
global.config = {
	
	/* Opties voor salt. */
	salt: {
		
		/* Bepaal het IP van de master. */
		master_ip: fs.readFileSync ('/etc/salt/minion.d/99-master-address.conf').toString ().split ('master: ')[1].replace ("\n", ''),
		
		/* Geef de poort van de master server op. */
		master_port: 1234,
		
		/* Het publieke certificaat van de master. */
		master_pub: fs.readFileSync ('/etc/salt/pki/minion/minion_master.pub'),
		
		/* Private ceritifcaat van de minion. */
		minion_priv: fs.readFileSync ('/etc/salt/pki/minion/minion.pem'),
		
		/* De ID van de minion zoals bekend bij de master. */
		minion_id: fs.readFileSync ('/etc/salt/minion_id').toString ()
	},
	
	/* Opties voor logging. */
	logging: {
		
		/* Bepaal om de hoeveel tijd aangepaste files naar de server gestuurd moeten worden (in secondes). */
		sync_time: 5
	}
};

/* Require de log_files.json global. */
global.log_files = require ('./log_files.json');

/* Maak een transport object. */
global.transport = new Transport;

/* Maak een LogManager object. */
new LogManager;