/* Require fs. */
const fs = require ('fs');


/* LogServer class. */
class LogServer
{
	/* Constructor. */
	constructor ()
	{
		/* Maak de root path aan. */
		this.create_path (global.config.log.log_path);
	}
	
	
	/* Functie om een path recursive aan te maken. */
	create_path (path)
	{
		/* Defineer de root path. */
		var root_path = path.split ('/');
		
		/* Defineer een current path. */
		var curr_path = '';
		
			/* Doorloop de root_path. */
			for (var i in root_path)
			{
				/* Voeg dit item aan de curr_path toe. */
				curr_path = curr_path + '/' + root_path[i];
				
					/* Bestaat de huidige curr_path? */
					if (!fs.existsSync (curr_path))
					{
						/* Nee, maak aan. */
						fs.mkdirSync (curr_path);
					}
			}		
	}
	
	
	/* Functie dat aangeroepen wordt als er log data binnen komt. */
	add_log (client, data)
	{
		/* Defineer de map naam. */
		var folder_name = client.client_ip + '-' + client.auth_name;
		
		/* Sloop de filenaam uit de data op slashes. */
		var log_path = data.file.split ('/');
		
		/* Haal het laatste element eraf, dit is de file naam zelf. */
		var filename = log_path.pop ();
		
		/* Maak nu de definitieve log path. */
		var full_log_path = global.config.log.log_path + '/' + folder_name + log_path.join ('/');
		
		/* Maak de full path aan. */
		this.create_path (full_log_path);
		
		/* Maak een buffer van base64. */
		var buffer = new Buffer.from (data.data, 'base64');
		
		/* Schrijf de data nu naar de log file toe. */
		fs.writeFile (full_log_path + '/' + filename, buffer.toString ('utf8'), {flag: 'w'}, (err) =>
		{
			/* Is er een foutmelding? */
			if (err)
			{
				/* Ja, log dit. */
				console.log ('Fout bij het schrijven naar \'' + full_log_path + '/' + filename + '\'.');
				console.log (err);
			}	
		}); 
	}
}

/* Export de LogServer class. */
module.exports = LogServer;