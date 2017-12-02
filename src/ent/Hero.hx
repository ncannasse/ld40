package ent;
import hxd.Key in K;

enum Event {
	Get( o : Object, x : Int, y : Int );
	Put( o : Object );
}

class Hero extends Entity {

	public static var STEP = 8;

	var lastMX = 0;
	var lastMY = 0;
	var acc = 0.;

	var colX = -1;
	var colY = -1;
	var colTile : h2d.Tile;
	var colView : h2d.TileGroup;
	var eventHist : Array<Event> = [];
	public var history : Array<{ x : Int, y : Int, evt : Int }> = [];

	public var carry : Array<Object> = [];

	var undoAcc : Float;
	var undoTimer : Float = 0.;

	var tag : h2d.Graphics;


	public function new(x,y) {
		super(Hero, x, y);
		colX = Std.int(this.x * STEP);
		colY = Std.int(this.y * STEP);
		colTile = game.tiles.sub(38, 38, 20, 20, -10, -10);
		colView = new h2d.TileGroup(colTile);
		var m = h3d.Matrix.I();
		m._44 = 0.1;
		colView.blendMode = Add;
		colView.filter = new h2d.filter.ColorMatrix(m);
		game.world.add(colView, Game.LAYER_COL);

		tag = new h2d.Graphics();
		game.world.add(tag, Game.LAYER_ENT + 1);
		tag.x = -1000;
		tag.lineStyle(1, 0xFF0000);
		tag.drawRect(0, 0, 32, 32);
	}

	function undoEvents( len ) {
		while( eventHist.length > len ) {
			switch( eventHist.pop() ) {
			case Get(o, x, y):
				carry.remove(o);
				o.carried = false;
				o.x = x + 0.5;
				o.y = y + 0.5;
			case Put(o):
				o.carried = true;
				carry.push(o);
			}
		}
	}

	function setCol(ox, oy) {
		if( history.length > 0 ) {
			var h = history[history.length - 1];
			if( h.x == colX && h.y == colY ) {
				history.pop();
				undoEvents(h.evt);
				return;
			}
		}
		history.push({ x : ox, y : oy, evt : eventHist.length });
	}

	function rebuildCol() {
		colView.clear();
		game.collides = [];
		var k = Std.int(32 / STEP);
		for( i in 0...history.length ) {
			var h = history[i];
			colView.add(h.x * k, h.y * k, colTile);
			var cx = Std.int(h.x / STEP);
			var cy = Std.int(h.y / STEP);
			game.collides[cx + cy * Game.LW] = history.length - i;
		}
		game.collides[Std.int(x - 0.5) + Std.int(y - 0.5) * Game.LW] = 1;
		game.collides[Math.round(x - 1e-3) + Math.round(y - 1e-3) * Game.LW] = 1;
		game.updateCol();
	}

	function setTag(x:Float, y:Float) {
		tag.x = Std.int(x) * 32;
		tag.y = Std.int(y) * 32;
	}

	function updateUndo(dt:Float) {
		undoAcc += dt * 0.1;
		if( undoAcc > 10 ) undoAcc = 10;
		undoTimer += undoAcc * 0.5;
		var change = false;
		while( undoTimer > 0 ) {
			undoTimer -= 1;
			var h = history.pop();
			if( h == null ) break;
			undoEvents(h.evt);
			x = h.x / STEP;
			y = h.y / STEP;
			colX = h.x;
			colY = h.y;
			change = true;
		}
		if( change ) rebuildCol();
	}

	function updateMove(dt:Float) {
		if( acc > 5 ) acc = 5;

		var dacc = dt * 0.1;
		var dmove = dt * 0.01 * (acc + 7);
		var drec = dmove * 0.9;

		var fric = Math.pow(0.8, dt);

		var left = K.isDown(K.LEFT);
		var right = K.isDown(K.RIGHT);
		var up = K.isDown(K.UP);
		var down = K.isDown(K.DOWN);
		var rx = x - 0.5;
		var ry = y - 0.5;

		if( left || right ) {
			var nextY = lastMY > 0 ? Math.ceil(ry - 0.3) : Std.int(ry + 0.3);
			var nextX = left ? Std.int(rx - 1e-3) : Std.int(rx) + 1;
			if( !game.isCollide(this,nextX, nextY) ) {
				if( ry < nextY ) {
					ry += drec;
					if( ry > nextY ) ry = nextY;
					acc *= fric;
				} else if( ry > nextY ) {
					ry -= drec;
					if( ry < nextY ) ry = nextY;
					acc *= fric;
				} else if( rx > nextX ){
					rx -= dmove;
					lastMY = 0;
					lastMX = -1;
					if( rx < nextX ) rx = nextX;
					acc += dacc;
				} else {
					rx += dmove;
					lastMY = 0;
					lastMX = 1;
					if( rx > nextX ) rx = nextX;
					acc += dacc;
				}
			}
		} else if( up || down ) {
			var nextX = lastMX > 0 ? Math.ceil(rx - 0.3) : Std.int(rx + 0.3);
			var nextY = up ? Std.int(ry - 1e-3) : Std.int(ry) + 1;
			if( !game.isCollide(this,nextX, nextY) ) {
				if( rx < nextX ) {
					rx += drec;
					if( rx > nextX ) rx = nextX;
					acc *= fric;
				} else if( rx > nextX ) {
					rx -= drec;
					if( rx < nextX ) rx = nextX;
					acc *= fric;
				} else if( ry > nextY ){
					ry -= dmove;
					lastMX = 0;
					lastMY = -1;
					if( ry < nextY ) ry = nextY;
					acc += dacc;
				} else {
					ry += dmove;
					lastMX = 0;
					lastMY = 1;
					if( ry > nextY ) ry = nextY;
					acc += dacc;
				}
			}
		} else {
			acc *= fric * fric;
		}
		this.x = rx + 0.5;
		this.y = ry + 0.5;


		var action = K.isPressed(K.SPACE);

		if( action ) {
			var frontX = lastMX < 0 ? Math.round(x - 0.1) : Math.round(x - 0.9);
			var frontY = lastMY < 0 ? Math.round(y - 0.1) : Math.round(y - 0.9);
			frontX += lastMX;
			frontY += lastMY;
			//setTag(frontX, frontY);
			var obj = Std.instance(game.pick(frontX, frontY), Object);
			if( obj != null ) {
				obj.carried = true;
				carry.push(obj);
				eventHist.push(Get(obj, frontX, frontY));
				game.updateCol();
			} else if( obj == null && carry.length > 0 ) {
				var putX = Std.int(x) + lastMX;
				var putY = Std.int(y) + lastMY;
				//setTag(putX, putY);
				if( !game.isCollide(null, putX, putY) ) {
					var c = carry.pop();
					c.x = putX + 0.5;
					c.y = putY + 0.5;
					c.carried = false;
					game.updateCol();
					eventHist.push(Put(c));
				}
			}
		}


		var newX = Std.int(x * STEP);
		var newY = Std.int(y * STEP);
		var change = false;
		while( colX != newX || colY != newY ) {
			var oldX = colX, oldY = colY;
			if( colX < newX ) colX++ else if( colX > newX ) colX--;
			if( colY < newY ) colY++ else if( colY > newY ) colY--;
			setCol(oldX, oldY);
			change = true;
		}
		if( change ) rebuildCol();
	}

	override function update(dt:Float) 	{

		if( K.isDown(K.ESCAPE) ) {
			updateUndo(dt);
		} else {
			undoAcc *= Math.pow(0.7, dt);
			undoTimer = 0;
			updateMove(dt);
		}

		super.update(dt);
	}

}