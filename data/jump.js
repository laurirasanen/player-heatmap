var fs = require("fs");
var heatmap = require("demo-heatmap");

heatmap.getPoints(
    // Demo file name
    "jump.dem",

    // Completion callback
    (err, data) => {
        if (err) throw err;

        // Comma delimited csv:
        // Each line is a new player
        // <int> tick, <float> x, <float> y, <float> z, ...

        var str = "";

        for (var player of data.players)
        {
            for (var point of player.points)
            {
                str += `${point.tick},${point.x},${point.y},${point.z},`;
            }

            str = str.substring(0, str.length - 1);
            str += "\n";
        }

        str = str.substring(0, str.length - 1);

        fs.writeFile("jump.csv", str, (err) => {
            if (err) throw err;

            console.log("Player data written to 'jump.csv'!");
        });
    }
);