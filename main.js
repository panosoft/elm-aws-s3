// compile with:
//		elm make Test/App.elm --output elm.js

// load Elm module
const elm = require('./elm.js');

// Get credentials
const accessKeyId = process.argv[2];
const secretAccessKey = process.argv[3];

const flags = {
    accessKeyId,
    secretAccessKey
};

// get Elm ports
const ports = elm.App.worker(flags).ports;

// keep our app alive until we get an exitCode from Elm or SIGINT or SIGTERM (see below)
setInterval(id => id, 86400);

ports.exitApp.subscribe(exitCode => {
	console.log('Exit code from Elm:', exitCode);
	process.exit(exitCode);
});

process.on('uncaughtException', err => {
	console.log(`Uncaught exception:\n`, err);
	process.exit(1);
});

process.on('SIGINT', _ => {
	console.log(`SIGINT received.`);
	ports.externalStop.send(null);
});

process.on('SIGTERM', _ => {
	console.log(`SIGTERM received.`);
	ports.externalStop.send(null);
});
