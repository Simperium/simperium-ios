window.onload = function() {
    M_WIDTH = 990;
    M_HEIGHT = 660;
    X_CELLS = 30;
    Y_CELLS = 25;
    REAL_CELL_WIDTH = 100;
    REAL_CELL_HEIGHT = 80;
    REAL_TOTAL_WIDTH = REAL_CELL_WIDTH*X_CELLS;
    REAL_TOTAL_HEIGHT = REAL_CELL_HEIGHT*Y_CELLS;
    CELL_WIDTH = M_WIDTH/X_CELLS;
    CELL_HEIGHT = M_HEIGHT/Y_CELLS;

    WEB_TO_REAL_SCALE_X = REAL_TOTAL_WIDTH/M_WIDTH;
    WEB_TO_REAL_SCALE_Y = REAL_TOTAL_HEIGHT/M_HEIGHT;
    REAL_TO_WEB_SCALE_X = M_WIDTH/REAL_TOTAL_WIDTH;
    REAL_TO_WEB_SCALE_Y = M_HEIGHT/REAL_TOTAL_HEIGHT;

    IPHONE_HEIGHT = 6*M_HEIGHT/Y_CELLS;
    IPHONE_WIDTH = 3.2*M_WIDTH/X_CELLS;

    IPAD_HEIGHT = 12.8*M_HEIGHT/Y_CELLS;
    IPAD_WIDTH = 7.68*M_WIDTH/X_CELLS;

    PLAYER_OFFSET_X = 1;
    PLAYER_OFFSET_Y = -26;
    PLAYER_SCALE_X = M_WIDTH/X_CELLS*1;
    PLAYER_SCALE_Y = M_HEIGHT/Y_CELLS*2;

    app_id = 'SIMPERIUM_APP_ID';
    simperium = new Simperium(app_id, {token: 'SIMPERIUM_ACCESS_TOKEN'});

    portsbucket = simperium.bucket('viewport');
    playerbucket = simperium.bucket('player');

    paper = Raphael(0, 0, M_WIDTH, M_HEIGHT);
    var img = paper.image("map.png", 0, 0, M_WIDTH, M_HEIGHT);

    // localstate
    var viewports = {};
    var players = {};

    var getScreenCoords = function(tileX, tileY) {
        var x=PLAYER_OFFSET_X, y=PLAYER_OFFSET_Y;
        x = x + tileX*CELL_WIDTH;
        y = y + (Y_CELLS-(tileY+1))*CELL_HEIGHT;
        return {x:x, y:y};
    };


    playerbucket.on('notify_init', function(id, data) {
        var coords = getScreenCoords(data.tileX, data.tileY)
        players[id] = paper.image("boy.png", coords.x, coords.y, PLAYER_SCALE_X, PLAYER_SCALE_Y);
    });

    playerbucket.on('notify', function(id, data) {
        var coords = getScreenCoords(data.tileX, data.tileY);
        if (id in players) {
            players[id].animate({x: coords.x, y: coords.y}, 1500);
        } else {
            players[id] = paper.image("boy.png", coords.x, coords.y, PLAYER_SCALE_X, PLAYER_SCALE_Y);
        }
    });

    playerbucket.on('ready', function() {
        var count = 0;
        for (var p in players) {
            if (players.hasOwnProperty(p)) count++;
        }
        if (count == 0) {
            console.log("player null!");
            var coords = getScreenCoords(5, 5);
            paper.image("boy.png", coords.x, coords.y, PLAYER_SCALE_X, PLAYER_SCALE_Y);
        }
    });


    portsbucket.on('notify_init', function(id, data) {
        console.log("notify_init:");
        console.log(data);
        if (('kind' in data) && ('orientation' in data) && ('x' in data) && ('y' in data)) {
            addPort(id, data.kind, data.orientation, data.x, data.y);
        }
    });

    portsbucket.on('notify', function(id, data) {
        if (id in viewports) {
            console.log("got notify for id in viewports");
            var port = viewports[id];
            var target_x = REAL_TO_WEB_SCALE_X*data.x;
            var target_y = (M_HEIGHT-REAL_TO_WEB_SCALE_Y*data.y)-port.attrs.height;
            var translate_x = target_x - port.attrs.x;
            var translate_y = target_y - port.attrs.y;

            port.realx = data.x;
            port.realy = data.y;

            port.freeTransform.attrs.translate.x = translate_x;
            port.freeTransform.attrs.translate.y = translate_y;
            port.freeTransform.apply();
        } else {
            console.log("got notify for id not in viewports");
            console.log(data);
            if (('kind' in data) && ('orientation' in data) && ('x' in data) && ('y' in data)) {
                addPort(id, data.kind, data.orientation, data.x, data.y);
            }
        }
    });

    portsbucket.on('local', function(id) {
        var data = null;
        if (id in viewports) {
            data = {
                'kind' : viewports[id].kind,
                'orientation' : viewports[id].orientation,
                'x' : Math.round(viewports[id].realx),
                'y' : Math.round(viewports[id].realy),
            };
        }
        return data;
    });

    var addPort = function(id, kind, orientation, realx, realy) {
        var width, height, x, y;
        if (kind == "iphone") {
            if (orientation == "portrait") {
                width = IPHONE_WIDTH;
                height = IPHONE_HEIGHT;
            } else {
                width = IPHONE_HEIGHT;
                height = IPHONE_WIDTH;
            }
            width = IPHONE_WIDTH;
            height = IPHONE_HEIGHT;
        } else if (kind == "ipad") {
            if (orientation == "portrait") {
                width = IPAD_WIDTH;
                height = IPAD_HEIGHT;
            } else {
                width = IPAD_HEIGHT;
                height = IPAD_WIDTH;
            }
            width = IPAD_WIDTH;
            height = IPAD_HEIGHT;
        }
        x = REAL_TO_WEB_SCALE_X*realx;
        y = (M_HEIGHT-REAL_TO_WEB_SCALE_Y*realy)-height;
        var port = paper.rect(x, y, width, height);
        viewports[id] = port;
        port.id = id;
        port.kind = kind;
        port.orientation = orientation;

        port.callback = function() {
            var x, y;
            var realx, realy;
            x = this.attrs.x + this.attrs.translate.x;
            y = this.attrs.y + this.attrs.translate.y;
            realx = WEB_TO_REAL_SCALE_X*x;
            realy = (M_HEIGHT-(y+height))*WEB_TO_REAL_SCALE_Y;
            console.log("("+x+", "+y+") -> ("+realx+", "+realy+")");
            var obj = this.items[0].el;
            obj.realx = realx;
            obj.realy = realy;
            portsbucket.update(obj.id);
        };

        var ft = paper.freeTransform(port);
        ft.setOpts({
            boundary: {
                x: port.attrs.width/2,
                y: port.attrs.height/2,
                width: (M_WIDTH-port.attrs.width),
                height: (M_HEIGHT-port.attrs.height)
            },
            drag: true,
            dragRotate: false,
            dragSnap: false,
            rotate: false,
            scale: false,
            animate: true,
            delay: 150,
        }, port.callback);
        port.freeTransform = ft;
    };
    portsbucket.on('ready', function() {
        console.log('portsbucket ready');
    });

    portsbucket.start();
    playerbucket.start();

}
