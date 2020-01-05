# Player data sample from jump_mowi_rc2  

Included:  
`jump.dem` - STV demo file  
`jump.csv` - Player position data output from `jump.js`  
`jump.js` - Sript for exporting data from STV demo  

Usage:  
`npm i`  
`node jump.js`  
The script will output `jump.csv` file containing player positional data.  
Move `jump.csv` to `/tf/heatmaps/jump.csv`, then run `hm_load jump.csv` in-game with jump_mowi_rc2 map loaded.  
You may need to be in a team (not spectator) for the plugin to work.