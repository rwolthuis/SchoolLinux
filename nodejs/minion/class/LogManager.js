/* Require Log. */
const Log = require ('./Log');

/* LogManager class. */
class LogManager
{
	/* Constructor. */
	constructor ()
	{
		/* Object met Log objecten. */
		this.log_obj = {};
		
			/* Doorloop de log_files. */
			for (var i in global.log_files)
			{
				/* Bestaat het log object al? */
				if (!(global.log_files[i] in this.log_obj))
				{
					/* Nee, maak een Log object aan. */
					this.log_obj[global.log_files[i]] = new Log (global.log_files[i]);
				}
			}
	}
}

/* Export de LogManager class. */
module.exports = LogManager;