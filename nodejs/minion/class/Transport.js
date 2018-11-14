/* Require TLS. */
const tls = require ('tls');

/* Require de encryption class. */
const Encryption = require ('./Encryption');


/* Transport class. */
class Transport extends Encryption
{
	/* Constructor. */
	constructor ()
	{
		/* Super de Encryption class. */
		super ();
		
		/* Send queue, voor als er data gebufferd moet worden als we offline zijn. */
		this.send_queue = [];
		
		/* Plekje voor de send_queue timeout. */
		this.send_queue_timeout = '';
		
		/* Log dat we gaan verbinden. */
		console.log ('Bezig met verbinden naar server ' + global.config.salt.master_ip + ':' + global.config.salt.master_port + '...');
		
		/* Roep tls_connect aan. */
		this.tls_connect ();
	}
	
	
	/* Functie om te connecten. */
	tls_connect ()
	{
		/* Defineer auth als false. */
		this.auth = false;
		
		/* Maak een TLS client, en accepteer self-signed certificaten. */
		this.client = tls.connect (global.config.salt.master_port, global.config.salt.master_ip, {rejectUnauthorized: false}, () =>
		{
			/* Log dat we verbonden zijn met de server. */
			console.log ('Verbonden met de server.');
		});
		
		/* Zet de encoding op utf8. */
		this.client.setEncoding ('utf8');
		
		/* Hook de client events. */
		this.hook_client_events ();		
	}
	
	
	/* Functie om data naar de server te sturen. */
	send_to_server (data)
	{
		/* Zijn we geauthorizeerd? */
		if (this.auth === true)
		{
			/* Ja, stuur naar server. */
			this.client.write (data);
		}
		else
		{
			/* Nee, voeg toe aan queue. */
			this.send_queue.push (data);
			
			/* Clear eventueel lopende timeouts. */
			clearTimeout (this.send_queue_timeout);
			
			/* Set een nieuwe timeout, en wacht 2,5 sec. */
			this.send_queue_timeout = setTimeout (() =>
			{
				/* Haal het eerste element uit de queue. */
				var queue_data = this.send_queue.shift ();
				
				/* Stuur dit naar de server. */
				this.send_to_server (queue_data);
			}, 2500);
		}
	}
	
	
	/* Functie om de client events te hooken. */
	hook_client_events ()
	{
		/* Wanneer er data binnen komt. */
		this.client.on ('data', (data) =>
		{
			/* Probeer het volgende. */
			try
			{
				/* JSON parse de data. */
				data = JSON.parse (data);
				
					/* Komt er een cmd voor in de data? */
					if ('cmd' in data)
					{
						/* Ja, switch de CMD. */
						switch (data.cmd)
						{
							/* Authorize gedeelte. */
							case 'authorize':
								if ('number' in data)
								{
									this.tls_auth (data);
								}
							break;
							
							default: 
								/* Onbekende commando. Log foutmelding. */
								console.log ('Onbekende commando \'' + data.cmd + '\' ontvangen.');
						}
					}
			}
			catch (e)
			{
				/* Ongeldige JSON. Doe niks. */
			}
		});
		
		
		/* Wanneer we disconnecten. */
		this.client.on ('end', () =>
		{
			/* Log. */
			console.log ('Verbinding verloren. Opnieuw verbinden...')
			
			/* Roep tls_connect aan na 2,5 sec. */
			return setTimeout (this.tls_connect.bind (this), 2500);
		});
		
		
		/* Wanneer er een foutmelding is. */
		this.client.on ('error', () =>
		{
			/* Roep tls_connect aan na 2,5 sec. */
			return setTimeout (this.tls_connect.bind (this), 2500);
		});		
	}
	
	
	/* Functie om te authorizeren met de server. */
	tls_auth (data)
	{
		/* Ja, gaat het om de eerste nummer? */
		if (data.number == 1)
		{
			/* Ja, stuur numemr 1 terug met de naam van de minion_id. */
			this.client.write (JSON.stringify ( {cmd: 'authorize', number: 1, name: global.config.salt.minion_id} ));
		}
		
		/* Gaat het om de 2e nummer? */
		if (data.number == 2)
		{
			/* Ja, decode de vraag d.m.v. de minion private key. */
			var nr = this.decrypt_private_key (data.auth, global.config.salt.minion_priv).split (' ');
			
			/* Bereken het antwoord, maak hier een string van en encrypt het antwoord d.m.v. de master public key. */
			var awnser = this.encrypt_public_key ('' + (nr[0] * nr[1]), global.config.salt.master_pub);
			
			/* Stuur het antwoord terug naar de master. */
			this.client.write (JSON.stringify ( {cmd: 'authorize', number: 2, auth: awnser} ));
		}
		
		/* Gaat het om de 3e nummer? */
		if (data.number == 3)
		{
			/* Ja, log. */
			console.log ('Authorizatie succesvol!');
			
			/* Zet auth op true. */
			this.auth = true;
		}
	}
}


/* Export de Transport class. */
module.exports = Transport;