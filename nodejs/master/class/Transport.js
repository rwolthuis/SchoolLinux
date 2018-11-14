/* Require fs. */
const fs = require ('fs');

/* Require tls. */
const tls = require ('tls');

/* Require crypto. */
const crypto = require ('crypto');

/* Require Encryption. */
const Encryption = require ('./Encryption');



/* Transport class. */
class Transport extends Encryption
{
	/* Constructor functie. */
	constructor ()
	{
		/* Roep de constructor van Encryption aan. */
		super ();
		
		/* Maak een object voor de minions. */
		this.minions = {};

		/* Maak een object voor de (verbonden) TLS clients. */
		this.tls_clients = {};
		
		/* Laad de master key in. */
		this.master_key = fs.readFileSync (global.config.salt.private_key);
		
		/* Start de TLS server. */
		this.tls_start ();
	}
	
	
	/* Functie om de minions op te halen uit salt, dit wordt onze auth. systeem. */
	update_minions (cb)
	{
		/* Lees de directories met minions uit. */
		fs.readdir (global.config.salt.minion_path, (err, files) =>
		{
			/* Doorloop de files array. */
			for (var i in files)
			{
				/* Lees de data (synced, yup..) uit, en sla op in de minion object. */
				this.minions[files[i]] = fs.readFileSync (global.config.salt.minion_path + '/' + files[i], 'utf8');
			}
		
			/* Callback nu. */
			return cb ();
		});
	}
	
	
	
	
	/* Functie om de TLS server te starten. */
	tls_start ()
	{
		/* Maak een option object en sla de certificaten hierin op. */
		const options = {
			key: fs.readFileSync ('./cert/server-key.pem'),
			cert: fs.readFileSync ('./cert/server-cert.pem'),
		};
		
		/* Maak een TLS server aan, en stuur inkomende verbindingen naar de tls_client functie. */
		this.server = tls.createServer (options, this.tls_client.bind (this));
		
		/* Start de server, en luister naar de ingestelde poort. */
		this.server.listen (global.config.server_port, () =>
		{
			/* Log dat we luisteren. */
			console.log ('Monitoring & Log server is gestart op poort ' + global.config.server_port + '.');
		});
	}
	
	
	
	/* Functie om nieuwe TLS verbindingen te verwerken. */
	tls_client (client)
	{
		/* Set een timeout op de client. */
		client.auth_timeout = setTimeout (() =>
		{
			/* Client heeft er te lang over gedaan om te authorizeren. Disconnect de client. */
			client.destroy ();
		}, 10000);
		
		/* Zet de encoding naar utf8. */
		client.setEncoding ('utf8');
		
		/* Wanneer de client data stuurt. */
		client.on ('data', (data) =>
		{
			/* Probeer het volgende. */
			try
			{
				/* JSON decode de data. */
				data = JSON.parse (data);
				
					/* Komt er een cmd voor in de data? */
					if ('cmd' in data)
					{
						/* Ja, switch deze. */
						switch (data.cmd)
						{
							/* Authorize gedeelte. */
							case 'authorize':
								if ('number' in data)
								{
									this.tls_auth (client, data);
								}
							break;
							
							/* Log gedeelte. */
							case 'log': 
								global.logserver.add_log (client, data);
							break;
							
							/* Monitor gedeelte. */
							case 'monitor':
								// doe wat.
							break;
							
							default: 
								/* Onbekende commando. Log foutmelding. */
								console.log ('Onbekende commando \'' + data.cmd + '\' ontvangen.');
						}
					}
			}
			catch (e)
			{
				/* Ongeldige JSON? Doe verder niks. */
			}
		});
		
		/* Wanneer de client disconnet. */
		client.on ('disconnect', () =>
		{
			/* Bestaat de client in de tls_clients object? */
			if (client in this.tls_clients)
			{
				/* Ja, verwijder hem. */
				delete this.tls_client[client];
			}
		});
		
		/* Sla de client IP op. */
		client.client_ip = ((client.remoteAddress.substring (0, 7) == '::ffff:') ? client.remoteAddress.substring (7) : client.remoteAddress);
		
		/* Voeg de client toe aan de tls_clients object. */
		this.tls_clients[client] = {};
		
		/* Stuur een authorize commando naar de client. */
		client.write ('{"cmd":"authorize","number":1}');
	}
	
	
	/* Functie om een client the authorizeren. */
	tls_auth (client, data)
	{
		/* Gaat het om auth nr. 1? */
		if (parseInt (data.number) == 1)
		{
			/* Ja, is er een name mee gegeven? */
			if ('name' in data)
			{
				/* Ja, update de minions. */
				this.update_minions (() =>
				{
					/* Bestaat de minion? */
					if (data.name in this.minions)
					{
						/* Ja, sla de naam in het client object op. */
						client.auth_name = data.name;
						
						/* Genereer twee random nummers tussen 10 en 99. */
						var nrA = Math.floor (Math.random () * 99) + 10;
						var nrB = Math.floor (Math.random () * 99) + 10;
						
						/* Vermenig vuldig de nummers met elkaar, en sla op als antwoord in het client object. */
						client.auth_awnser = nrA * nrB;
						
						/* Stuur de vraag encrypted (met public key van de minion) naar de minion. */
						client.write (JSON.stringify ({cmd: 'authorize', 'number': 2, 'auth': this.encrypt_public_key (nrA + ' ' + nrB, this.minions[data.name])}));
					}
				});
			}
		}
		else
		/* Nee, gaat het om auth. nummer 2? */
		if (parseInt (data.number) == 2)
		{
			/* Ja, is er een auth mee gegeven? */
			if ('auth' in data)
			{
				/* Ja, decrypt het antwoord. */
				var antwoord = this.decrypt_private_key (data.auth, this.master_key);
				
					/* Is het antwoord gelijk aan de opgeslagen? */
					if (antwoord == client.auth_awnser)
					{
						/* Ja, zet authed op true. */
						client.authed = true;
						
						/* Clear de timeout. */
						clearTimeout (client.auth_timeout);
						
						/* Stuur een nummer 3 terug om te laten weten dat er geauthorizeerd is. */
						client.write ('{"cmd":"authorize","number":3}');
						
						/* Log nu. */
						console.log ('Client \'' + client.auth_name + '\' is succesvol verbonden en geauthorizeerd.');
					}
			}
		}
		else
		{
			/* Log ongeldige auth nummer. */
			console.log ('Ongeldige auth. nummer ' + data.number + ' ontvangen.');
		}
	}
}


/* Export de Transport class. */
module.exports = Transport;