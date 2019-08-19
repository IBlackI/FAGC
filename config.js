/*
	Clusterio plugin for the FAGC.
*/
module.exports = {
	// Name of package. For display somewhere I guess.
	name: "fagc",
	version: "1.0.2",
	binary: "nodePackage",
	description: "Allows reporting people to the Factorio Anti-griefer Coordination",
	scriptOutputFileSubscription: "fagc.txt",
	fagcApiBaseUrl: "API PATH",
	fagcApiKey: "API-Key",
	fagcRules: [1,2,3,4,5,6,7,8,9,10]
}