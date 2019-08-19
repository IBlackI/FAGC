const needle = require("needle");
const fs = require("fs-extra")

const pluginConfig = require("./config");
const COMPRESS_LUA = false;

module.exports = class remoteCommands {
	constructor(mergedConfig, messageInterface, extras){
		this.messageInterface = messageInterface;
		this.config = mergedConfig;
		this.socket = extras.socket;

		(async ()=>{
			let hotpatchInstallStatus = await this.checkHotpatchInstallation();
			this.hotpatchStatus = hotpatchInstallStatus;
			this.messageInterface("Hotpach installation status: "+hotpatchInstallStatus);

			if(hotpatchInstallStatus){
				let mainCode = await this.getSafeLua("sharedPlugins/fagc/lua/control.lua");
				if(mainCode) var returnValue = await messageInterface(`/silent-command remote.call('hotpatch', 'update', '${pluginConfig.name}', '${pluginConfig.version}', '${mainCode}')`);
				if(returnValue) console.log(returnValue);
				this.updateRules();
			}
			
		})().catch(e => console.log(e));
	}

	scriptOutput(data) {
		if(data == null) {
			return;
		}
		if(data.startsWith("REPORT")) {
			var parts = data.split("~");
			var offences = parts[3].split(", ").map(Number);
			var report = {admin:parts[1], suspect:parts[2], offences:offences}
			console.log("FAGC | Received report data from ingame: " + JSON.stringify(report));
			this.report(report);
		} else {
			console.log("FAGC | ERROR: Cannot parse script output. Output:", data);
		}
	}
	
	async report(report){
		const reportUrl = pluginConfig.fagcApiBaseUrl + 'offence/report/';
		const options = { json: true,
						  headers: {
							Authorization: 'Token ' + pluginConfig.fagcApiKey
						  }
						};
		const mi = this.messageInterface;
		report.offences.forEach((offence) => {
			needle('post', reportUrl, { playername: report.suspect, rule_id:offence, admin:report.admin }, options)
			.then(function(response) {
				if(response.statusCode == 200) {
					console.log("FAGC | Successfully reported " + report.suspect + " for rule_id " + offence + ". Received offence_id: " + response.body.offence_id);
					mi(`/silent-command game.players["${report.admin}"].print("Successfully reported ${report.suspect} for rule_id ${offence}. Received offence_id: ${response.body.offence_id}")`);
				} else {
					console.log("FAGC | Reporting of " + report.suspect + " for rule_id " + offence + " failed: " + response.statusCode + " " + JSON.stringify(response.body));
					mi(`/silent-command game.players["${report.admin}"].print("Reporting of ${report.suspect} for rule_id ${offence} FAILED.")`);
				}
			})
			.catch(function(err) {
				console.error("FAGC | ", err);
			})
		});
		
	}
	
	async updateRules(){
		var rulesUrl = pluginConfig.fagcApiBaseUrl + 'rules/';
		const mi = this.messageInterface;
		await mi(`/silent-command remote.call("fagc", "clearRules")`);
		rulesUrl += "?mode=include";
		pluginConfig.fagcRules.forEach(id => {
			rulesUrl += "&id=" + id
		});
		console.log(rulesUrl);
		needle('get', rulesUrl)
		.then(function(response) {
			if(response.statusCode == 200) {
				console.log("FAGC | Successfully received rules " + JSON.stringify(response.body));
				response.body.forEach(rule => {
					mi(`/silent-command remote.call("fagc", "setRule", ${rule.id}, "${rule.short}", "${rule.detailed}")`);
				});
			} else {
				console.log("FAGC | Rules failed: " + response.statusCode + " " + JSON.stringify(response.body));
			}
		})
		.catch(function(err) {
			console.error("FAGC | ", err);
		})
		
	}
	
	async getSafeLua(filePath){
		return new Promise((resolve, reject) => {
			fs.readFile(filePath, "utf8", (err, contents) => {
				if(err){
					reject(err);
				} else {
                    // split content into lines
					contents = contents.split(/\r?\n/);

					// join those lines after making them safe again
					contents = contents.reduce((acc, val) => {
                        val = val.replace(/\\/g ,'\\\\');
                        // remove leading and trailing spaces
					    val = val.trim();
                        // escape single quotes
					    val = val.replace(/'/g ,'\\\'');

					    // remove single line comments
                        let singleLineCommentPosition = val.indexOf("--");
                        let multiLineCommentPosition = val.indexOf("--[[");

						if(multiLineCommentPosition === -1 && singleLineCommentPosition !== -1) {
							val = val.substr(0, singleLineCommentPosition);
						}

                        return acc + val + '\\n';
					}, ""); // need the "" or it will not process the first row, potentially leaving a single line comment in that disables the whole code
					if(COMPRESS_LUA) contents = require("luamin").minify(contents);
					
					resolve(contents);
				}
			});
		});
	}
	async checkHotpatchInstallation(){
		let yn = await this.messageInterface("/silent-command if remote.interfaces['hotpatch'] then rcon.print('true') else rcon.print('false') end");
		yn = yn.replace(/(\r\n\t|\n|\r\t)/gm, "");
		if(yn == "true"){
			return true;
		} else if(yn == "false"){
			return false;
		}
	}
}