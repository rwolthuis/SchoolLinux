/* Require fs. */
const fs = require ('fs');


/* Log class. */
class Log
{
	/* Constructor. */
	constructor (log_path)
	{
		/* Sla de path op. */
		this.path = log_path;
		
		/* Defineer of de file veranderd is of niet. */
		this.changed = false;
		
		/* Defineer of we aan het sturen zijn. */
		this.sending = false;
		
		/* Maak een timeout die elke X seconde save aan roept. */
		setTimeout (this.save.bind (this), (global.config.logging.sync_time * 1000));
		
		/* Kijk of de file bestaat. */
		this.exists ();
	}
	
	
	/* Functie om te kijken of het bestand bestaat. */
	exists ()
	{
		/* Stat de file. */
		fs.stat (this.path, (err, stat) =>
		{
			/* Bestaat de file? */
			if (err == null)
			{
				/* Ja, roep monitor aan. */
				this.monitor ();
			}
			else
			{
				/* File bestaat niet. Probeer over 10 seconde nog een keer. */
				setTimeout (this.exists.bind (this), 10000);
			}
		});
	}
	
	
	/* Functie om de log file te monitoren. */
	monitor ()
	{
		/* Houd het bestand in de gaten voor veranderingen. */
		fs.watch (this.path, (event, filename) =>
		{
			/* Is event 'close'? */
			if (event == 'close')
			{
				/* Ja, roep exists aan. */
				return this.exists ();
			}
			
			/* Is er een filename? */
			if (filename)
			{
				/* Ja, zet changed op true. */
				this.changed = true;
			}
		});
	}
	
	
	/* Functie om veranderingen op te slaan naar de server. */
	save ()
	{
		/* Is changed true, en is sending false? */
		if (this.changed === true && this.sending === false)
		{
			/* Ja, zet sending op true. */
			this.sending = true;
			
			/* Haal de inhoud van de file op. */
			fs.readFile (this.path, 'utf8', (err, contents) =>
			{
				/* Base64 de contents van de file. */
				var base64 = new Buffer.from (contents).toString ('base64');
				
				/* Maak een data object. */
				var data = {
					'cmd': 'log',
					'file': this.path,
					'data': base64
				};
				
				/* Stuur de data naar de server. */
				global.transport.send_to_server (JSON.stringify (data));
				
				/* Zet changed en sending op false. */
				this.changed = false;
				this.sending = false;
			});
		}
		
		/* Maak een nieuwe timeout. */
		setTimeout (this.save.bind (this), (global.config.logging.sync_time * 1000));
	}
}


/* Export de Log class. */
module.exports = Log;