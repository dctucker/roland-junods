const fs = require('fs');
const midi = require('midi');
const input = new midi.Input();

const roland_sysex = [ 240, 65, 16, 0, 0, 58 ];


channel_data = [
	{},{},{},{},
	{},{},{},{},
	{},{},{},{},
	{},{},{},{}
];
for(i=0; i < 16; i++){ channel_data[i].pc = [0,0,0]; }

names = {};
cats = {};

model = {
	channel_data: channel_data,
	names: names,
	cats: cats,
};
fs.readFile('./data.json', 'utf-8', (err, data) => {
	model = JSON.parse(data);
	channel_data = model.channel_data;
	names = model.names;
	cats = model.cats;
});

function array_equals(array1,array2){
	return array1.length === array2.length && array1.every((value, index) => value === array2[index])
}
function starts_with(array1, array2){
	return array_equals(array1.slice(0,array2.length), array2);
}

function data_req(addr, len){
	ret = [].concat(roland_sysex);
	ret.push(17);
	ret = ret.concat(addr);
	ret = ret.concat(len);
	sum = addr.reduce((s,a) => s + a);
	//sum += len.reduce((s,a) => s + a);
	ret.push(127 - (sum % 128));
	ret.push(247);
	return ret;
}

function data_set(addr, val){
	ret = [].concat(roland_sysex);
	ret.push(18);
	ret = ret.concat(addr);
	ret = ret.concat(val);
	sum = addr.reduce((s,a) => s + a);
	sum += val.reduce((s,a) => s + a);
	ret.push(127 - (sum % 128));
	ret.push(247);
	return ret;
}

function name_req(ch, drum){
	msb = parseInt((ch / 4) + 17);
	lsb = parseInt((ch % 4) * 32);
	if( drum ){
		lsb += 16;
	}
	return data_req([msb, lsb, 0, 0], [0,0,0,13]);
}

function pc_req(ch){
	return data_req([16,0,32+ch,4], [0,0,0,3]);
}

function pc_set(ch, pc){
	//0xbf 0x00 0x55
	//0xbf 0x20 0x40 0xcf 0x02
	ccs = 0xb0 + (ch % 16);
	pcs = 0xc0 + (ch % 16);
	return [
		[ ccs, 0,  parseInt(pc[0]) ],
		[ ccs, 32, parseInt(pc[1]) ],
		[ pcs,     parseInt(pc[2]) ]
	];
}

function is_drum(pc){
	if(pc[0]==86 || pc[0]== 92 || pc[0] ==120){
		return true;
	} else {
		return false;
	}
}

input.on('message', (dt,m) => {
	cmd = m.slice( roland_sysex.length, -1 );
	if( starts_with(m, roland_sysex) && cmd[0] == 18 ){
		addr = cmd.slice(1,5);
		if( array_equals( cmd.slice(3,5), [0,0] ) ){
			ch = parseInt((addr[0]-17) * 4 + (addr[1]/32));
			str = cmd.slice(5,-2).map((e) => String.fromCharCode(e)).join('');
			cat = parseInt(cmd.slice(-2,-1)[0]);
			console.log(`${ch+1} ${str}`);
			if( ch >= 0 && ch <= 15 ){
				channel_data[ch].name = str;
				channel_data[ch].cat = cat;
				names[ channel_data[ch].pc ] = str;
				cats[ channel_data[ch].pc ] = cat;
			} else {
				console.log(ch);
			}
		} else if( addr[0] == 16 && addr[1] == 0 && addr[3] == 4 ){
			ch = addr[2];
			if( ch >= 32 && ch <= 47 ){
				ch -= 32;
				pc = cmd.slice(5,-1);
				console.log(`${ch+1} ${pc}`);
				channel_data[ch].pc = pc;
			}
		} else if( array_equals( addr, [1,0,0,1] ) ){
			pc = cmd.slice(5,-1);
			console.log(`pc ${pc}`);
			query_all_pc();
		} else {
			console.log(`roland ${cmd}`);
		}
	}
});
input.openPort(0);
input.ignoreTypes(false,true,true);
output = new midi.Output();
output.openPort(0);

query_all_pc = () => {
	dt = 30;
	let time = 0;
	for(var i=0; i < 16; i++){
		time += dt;
		let ch = i;
		setTimeout(() => {
			message = pc_req(ch);
			console.log(message);
			output.sendMessage( message );
		}, time);
	}


	time += dt;
	for(var i=0; i < 16; i++){
		time += dt;
		let ch = i;
		setTimeout(() => {
			pc = channel_data[ch].pc;
			if( pc ){
				message = name_req(ch, is_drum(channel_data[ch].pc));
				console.log(message);
				output.sendMessage( message );
			}
		}, time);
	}

	time += dt;
	setTimeout(() => {
		console.log(channel_data);
	}, time);

};

function query_pc(ch){
	message = pc_req(ch);
	output.sendMessage( message );
}

send_pc = (ch, pc) => {
	pc_msg = pc_set(ch, pc);
	output.sendMessage( pc_msg[0] );
	output.sendMessage( pc_msg[1] );
	output.sendMessage( pc_msg[2] );
}

function init_op92(){
	output.sendMessage( data_set([1,0,0,0], [1]) );
	send_pc(15, [85,0,91]);
}

function write_model(){
	model.names = names;
	model.cats = cats;
	model.channel_data = channel_data;
	fs.writeFileSync('./data.json', JSON.stringify(model, null, 2), 'utf-8');
}


time = 0;
category_names = [
	"DRM","PNO","EP","KEY","BEL","MLT","ORG", "ACD","HRM", "AGT", "EGT", "DGT", "BS", "SBS", "STR", "ORC", "HIT", "WND",
	"FLT", "BRS", "SBR", "SAX", "HLD", "SLD", "TEK", "PLS", "FX", "SYN", "BPD", "SPD", "VOX", "PLK", "ETH", "FRT",
	"PRC", "SFX", "BTS", "DRM", "CMB", "SMP"
];
bank_names = {
	"0": "GM Patch",
	"1": "GM Patch",
	"63": "GM Patch",
	"85,0": "User Performance",
	"85,1": "User Pattern",
	"85,64": "Preset Performance",
	"85,65": "Preset Pattern",
	"86,0": "User Drum",
	"86,64": "Preset Drum",
	"86,65": "DS Drum",
	"87,0": "User Patch",
	"87,1": "User Patch",
	"87,64": "Preset Patch",
	"87,65": "Preset Patch",
	"87,66": "Preset Patch",
	"87,67": "Preset Patch",
	"87,68": "Preset Patch",
	"87,69": "Preset Patch",
	"87,70": "Preset Patch",
	"87,71": "Preset Patch",
	"87,72": "Preset Patch",
	"87,73": "DS Patch",
	"87,74": "DS Patch",
	"92": "Expansion Drum",
	"93": "Expansion Patch",
	"92,15": "EXP01 Drum",
	"93,15": "EXP01 Patch",
	"93,16": "EXP01 Patch",
	"93,17": "EXP01 Patch",
	"120": "GM Drum",
	"121": "GM Patch",
};
banks = {
	//"85": [0,1,64,65],
	"86": [0,64,65],
	/*
	"87": [0,1,64,65,66,67,68,69,70,71,72,73,74],
	//"92": [0,2,  7,15,                         19],
	//"93": [1,2,3,7,8,9,10,11,12,13,14,15,16,17,19,20,21,22,23,24,26],
	"92": [15],
	"93": [15,16,17],//,19,20,21,22,23,24,26],
	*/
};

main = () => {
	dt = 30;
	for(b in banks){
		for(sub in banks[b]){
			for(i=0; i < 128; i++){
				let bank = parseInt(b);
				let k = parseInt(banks[b][sub]);
				let j = i;
				setTimeout(() => {
					pc = [bank,k,j];
				//console.log(pc);
					send_pc(3, pc);
					channel_data[3].pc = pc;
					message = name_req(3, is_drum(pc));
					output.sendMessage(message);
				}, time);
				time += dt;

				setTimeout(() => {
					console.log(channel_data[3]);
				}, time);
				time += dt;
			}
		}

		time += dt * 10;
		setTimeout(() => {
			write_model();
		}, time + dt * 10);
		time += dt * 10;
	}
}


search = (str, skip) => {
	ret = [];
	for( pc in names ){
		name = names[pc].toLowerCase();
		if( name.includes(str.toLowerCase()) ){
			ret.push({pc: pc.split(','), name: names[pc], cat: cats[pc]});
		}
	}
	ret.sort((a, b) => {
		var nameA = a.name.toUpperCase();
		var nameB = b.name.toUpperCase();
		if (nameA < nameB) { return -1; }
		if (nameA > nameB) { return 1; }
		return 0;
	});
	return ret;
}

const readline = require('readline');
readline.emitKeypressEvents(process.stdin);
process.stdin.setRawMode(true);

readline.line = "";
readline.cursorTo(process.stdout, 0, 0);
readline.clearLine(process.stdout, 0);

selected_row = 0;
skip = 0;
search_results = [];

process.stdin.on('keypress', (str, key) => {
	redraw = true;

	if( key.ctrl && key.name === 'c' ){
		process.exit(); // eslint-disable-line no-process-exit
	} else if( key.name === 'backspace' ){
		readline.line = readline.line.substr(0, readline.line.length-1);
	} else if( key.name === 'pageup' ){
		skip -= 20;
		if( skip < 0 ){ skip = 0; }
		redraw = true;
	} else if( key.name === 'pagedown' ){
		skip += 20;
		redraw = true;
	} else if( key.name === 'up' ){
		readline.moveCursor(process.stdout, 0,-1);
		selected_row--;
		redraw = false;
		selected = search_results[ skip + selected_row - 1 ];
		send_pc(3, selected.pc );
	} else if( key.name === 'down' ){
		readline.moveCursor(process.stdout, 0, 1);
		selected_row++;
		redraw = false;
		selected = search_results[ skip + selected_row - 1 ];
		send_pc(3, selected.pc );
	} else if( key.name === 'return' ){
		if( selected_row > 0 ){
			selected = search_results[ skip + selected_row - 1 ];
			send_pc(3, selected.pc );
			redraw = false;
		}

		readline.line = "";
	} else {
		skip = 0;
		readline.line += key.sequence;
		redraw = true;
	}

	if( redraw ){
		readline.clearScreenDown(process.stdout);
		readline.cursorTo(process.stdout, 0,1);
		search_results = search(readline.line, skip);
		//console.log(search_results);

		row = 1;
		skip_now = skip;
		for( r in search_results ){
			if( skip_now > 0 ){ skip_now -= 1; continue; }
			res = search_results[r];
			console.log(`${res.name}  ${category_names[res.cat]} \t${res.pc}`);
			if( row >= process.stdout.rows - 2 ){
				break;
			}
			row += 1;
		}

		readline.cursorTo(process.stdout, 0, 0);
		readline.clearLine(process.stdout, 0);
		console.log(readline.line);
		readline.cursorTo(process.stdout, readline.line.length, 0);
		selected_row = 0;
	}
});

//main();
