/* Bron van de functies in deze class: https://stackoverflow.com/a/31061352 (door 'unzyn' en 'Jacob McKay')*/

/* Require crypto. */
const crypto = require("crypto");

/* Require path. */
const path = require("path");

/* Require fs. */
const fs = require("fs");


/* Encryption class. */
class Encryption
{
	/* Functie om data te encrypten met een public key. */
	encrypt_public_key (data, publicKey)
	{
		/* Maak een buffer aan met de te-encypten-data. */
		var buffer = new Buffer.from (data);
		
		/* Encrypt de data aan de hand van de public key. */
		var encrypted = crypto.publicEncrypt (publicKey, buffer);
		
		/* Return de encrypted data als base64. */
		return encrypted.toString ("base64");
	}
	
	
	/* Functie om data te decrypten met een private key. */
	decrypt_private_key (data, privateKey)
	{
		/* Maak een buffer aan met base64 data. */
		var buffer = new Buffer.from (data, "base64");
		
		/* Decrypt de buffer aan de hand van de private key. */
		var decrypted = crypto.privateDecrypt (privateKey, buffer);
		
		/* Return de decrypted data als utf8. */
		return decrypted.toString ("utf8");
	}
}


/* Export de Encryption class. */
module.exports = Encryption;