package ent;
import hxd.Key in K;

enum Event {
	Get( o : Object, x : Int, y : Int );
	Put( o : Object );
	Hue( old : Int );
}

class ColorReplacer extends hxsl.Shader {
	static var SRC = {
		@param var colorSrc : Vec4;
		@param var colorDst : Vec4;
		var pixelColor : Vec4;
		function fragment() {
			pixelColor = mix( pixelColor, colorDst, float( (pixelColor - colorSrc).length() < 0.0001 ) );
		}
	}
	public function new( colorSrc, colorDst = 0 ) {
		super();
		this.colorSrc.setColor(colorSrc);
		this.colorDst.setColor(colorDst);
	}
}

class Hero extends Entity {

	public static var STEP = 8;

	var acc = 0.;
	var colX = -1;
	var colY = -1;
	var colTile : h2d.Tile;
	var colView : h2d.TileGroup;
	var eventHist : Array<{ e : Event, hLen : Int }> = [];
	public var history : Array<{ x : Int, y : Int }> = [];

	public var carry : Array<Object> = [];

	var undoAcc : Float = 0.;
	var tag : h2d.Graphics;
	var moving : { x : Int, y : Int, dx : Int, dy : Int, k : Float, way : Float, ?undo : Bool };

	var time : Float = 0.;
	var flying = 0.;


	var colHero : h2d.Bitmap;
	var dir(default, set) : hxd.Direction;

	var colorRepl = new ColorReplacer( 0xFF000000 | (54 << 16) | (69 << 8) | 79 );

	public var movingAmount : Float = 0.;

	public function new(x,y) {
		super(Hero, x, y);
		colX = Std.int(this.x * STEP);
		colY = Std.int(this.y * STEP);
		colTile = game.tiles.sub(38, 38, 20, 20, -10, -10);
		colView = new h2d.TileGroup(colTile);
		var m = h3d.Matrix.I();
		m._44 = 0.1;
		colView.blendMode = Add;
		colView.addShader(new h3d.shader.SinusDeform(20,0.005,3));
		colView.filter = new h2d.filter.ColorMatrix(m);

		colHero = new h2d.Bitmap(game.tiles.sub(32, 32, 32, 32, -16, -16), colView);

		game.world.add(colView, Game.LAYER_COL);
		game.world.add(spr, Game.LAYER_HERO);

		spr.addShader(colorRepl);

		colorRepl.colorDst.load(colorRepl.colorSrc);

		tag = new h2d.Graphics();
		game.world.add(tag, Game.LAYER_ENT + 1);
		tag.x = -1000;
		tag.lineStyle(1, 0xFF0000);
		tag.drawRect(0, 0, 32, 32);
	}

	override function remove() {
		super.remove();
		colView.remove();
	}

	override function getAnim() {
		switch( dir ) {
		case Up:
			return [for( i in 0...5 ) game.tiles.sub(i * 32, 96 + 32, 32, 32, -16, -16)];
		default:
		}
		return [for( i in 0...5 ) game.tiles.sub(i * 32, 96, 32, 32, -16, -16)];
	}

	function set_dir(d) {
		if( dir != d ) {
			dir = d;
			spr.play(getAnim(), spr.currentFrame);
		}
		return d;
	}

	function undoEvents() {
		while( eventHist.length > 0 && eventHist[eventHist.length - 1].hLen > history.length ) {
			switch( eventHist.pop().e ) {
			case Get(o, x, y):
				carry.remove(o);
				o.x = x + 0.5;
				o.y = y + 0.5;
				o.carried = false;
			case Put(o):
				o.carried = true;
				carry.push(o);
			case Hue(v):
				game.hueValue = v;
			}
		}
	}

	function setCol(ox, oy) {
		if( history.length > 0 ) {
			var h = history[history.length - 1];
			if( h.x == colX && h.y == colY ) {
				if( moving != null ) moving.undo = true;
				history.pop();
				undoEvents();
				return;
			}
		}
		if( moving != null ) moving.undo = false;
		history.push({ x : ox, y : oy });
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

	function put(x,y) {
		var c = carry.pop();
		c.x = x + 0.5;
		c.y = y + 0.5;
		c.carried = false;
		game.updateCol();
		addEvent(Put(c));
	}

	function addEvent(e) {
		eventHist.push({ e : e, hLen : history.length });
	}

	public function doCarry( k : Data.ObjectKind, ?first : Bool ) {
		for( c in carry )
			if( c.kind == k ) {
				if( first && c != carry[carry.length - 1] )
					continue;
				return true;
			}
		return false;
	}

	public var padActive = false;

	function updateMove(dt:Float) {
		if( acc > 5 ) acc = 5;

		var dacc = dt * 0.1;
		var dmove = dt * 0.01 * (acc + 7);

		var fric = Math.pow(0.8, dt);

		var padUndo = game.pad.isDown(hxd.Pad.DEFAULT_CONFIG.B) || game.pad.isDown(hxd.Pad.DEFAULT_CONFIG.A);

		var left = K.isDown(K.LEFT) || game.pad.xAxis < -0.5;
		var right = K.isDown(K.RIGHT) || game.pad.xAxis > 0.5;
		var up = K.isDown(K.UP) || game.pad.yAxis < -0.5;
		var down = K.isDown(K.DOWN) || game.pad.yAxis > 0.5;
		var undo = K.isDown(K.ESCAPE) || K.isDown(K.SPACE) || padUndo;

		if( padUndo ) padActive = true;

		if( undo ) {
			left = right = up = down = false;
			undoAcc += dt * 0.1;
			if( undoAcc > 10 ) undoAcc = 10;
			dmove *= undoAcc;

			if( moving != null )
				moving.way = -1;
			else {
				var h = history[history.length - 1];
				if( h != null ) {
					var ix = Std.int(x);
					var iy = Std.int(y);
					var ox = h.x / STEP;
					var oy = h.y / STEP;

					if( oy > y )
						moving = { x : ix, y : iy + 1, dx : 0, dy : -1, way : -1., k : 1. };
					else if( ox > x )
						moving = { x : ix + 1, y : iy, dx : -1, dy : 0, way : -1., k : 1. };
					else if( oy < y )
						moving = { x : ix, y : iy - 1, dx : 0, dy : 1, way : -1., k : 1. };
					else if( ox < x )
						moving = { x : ix - 1, y : iy, dx : 1, dy : 0, way : -1., k : 1. };


				}
			}

		} else {
			undoAcc *= Math.pow(0.7, dt);

			if( game.pad.xAxis != 0 || game.pad.yAxis != 0 ) {
				var k = Math.sqrt(game.pad.xAxis * game.pad.xAxis + game.pad.yAxis * game.pad.yAxis);
				if( k > 0.5 ) padActive = true;
				if( padActive ) {
					if( k < 0.5 ) k = 0.5;
					dmove *= k;
				}
			}
		}

		// cancel
		if( moving != null && !padActive ) {
			if( moving.dx < 0 ) {
				if( right )
					moving.way = -1;
				else if( left )
					moving.way = 1;
			} else if( moving.dx > 0 ) {
				if( right )
					moving.way = 1;
				else if( left )
					moving.way = -1;
			}
			if( moving.dy < 0 ) {
				if( up )
					moving.way = 1;
				else if( down )
					moving.way = -1;
			} else if( moving.dy > 0 ) {
				if( up )
					moving.way = -1;
				else if( down )
					moving.way = 1;
			}
		}

		if( moving != null ) {
			var prev = moving.k;

			movingAmount = dmove * moving.way;

			moving.k += dmove * moving.way;
			var end = false;
			if( moving.k >= 1 ) {
				moving.k = 1;
				end = true;
			} else if( moving.k <= 0 ) {
				moving.k = 0;
				end = true;
			}
			x = moving.x + moving.dx * moving.k + 0.5;
			y = moving.y + moving.dy * moving.k + 0.5;

			if( prev < 0.6 && moving.k >= 0.6 && !moving.undo ) {
				var obj = Std.instance(game.pick(x, y), Object);
				if( obj != null ) {
					switch( obj.kind ) {
					case Square1, Square2, Wings:
						obj.carried = true;
						carry.push(obj);
						game.updateCol();
						addEvent(Get(obj, Std.int(obj.x), Std.int(obj.y)));
					default:
					}
				}
			}


			if( dmove > 0 )
				acc += dacc;
			else
				acc *= fric;
			if( end && !moving.undo ) {

				var ix = Std.int(x), iy = Std.int(y);

				if( carry.length > 0 ) {
					var s = getObj(ix, iy - 1, Steal);
					if( s != null && !s.isOccupied() && carry.length > 0 )
						put(ix, iy - 1);
					var s = getObj(ix, iy + 1, Steal);
					if( s != null && !s.isOccupied() && carry.length > 0 )
						put(ix, iy + 1);
					var s = getObj(ix - 1, iy, Steal);
					if( s != null && !s.isOccupied() && carry.length > 0 )
						put(ix - 1, iy);
					var s = getObj(ix + 1, iy, Steal);
					if( s != null && !s.isOccupied() && carry.length > 0 )
						put(ix + 1, iy);
				}

				var obj = getObj(ix, iy);
				if( obj != null && !moving.undo ) {
					var ckind = carry.length == 0 ? null : carry[carry.length - 1].kind;
					switch( [obj.kind, ckind] ) {
					case [Exit,_]:
						if( game.allActive )
							game.nextLevel();
					case [Plate1, _], [Plate2, _] if( ckind != null ):
						put(ix, iy);
					case [HueSwitch, _]:
						addEvent(Hue(game.hueValue));
						game.hueValue = 1 - game.hueValue;
					default:
					}
				}
			}
			if( end )
				moving = null;
		} else
			movingAmount = 0;

		if( moving == null ) {

			var updateLR = null, updateUD = null;

			if( left || right ) {
				var nextY = Std.int(y);
				var nextX = Std.int(x) + (left ? -1 : 1);
				if( !game.isCollide(this, nextX, nextY) )
					updateLR = function() moving = { x : Std.int(x), y : Std.int(y), k : 0, way : 1, dx : left ? -1 : 1, dy : 0 };
			}

			if( up || down ) {
				var nextX = Std.int(x);
				var nextY = Std.int(y) + (up ? -1 : 1);
				if( !game.isCollide(this, nextX, nextY) )
					updateUD = function() moving = { x : Std.int(x), y : Std.int(y), k : 0, way : 1, dy : up ? -1 : 1, dx : 0 };
			}

			if( updateLR != null && updateUD != null ) {
				if( Math.abs(game.pad.xAxis) > Math.abs(game.pad.yAxis) )
					updateUD = null;
				else
					updateLR = null;
			}

			if( updateLR != null )
				updateLR();
			else if( updateUD != null )
				updateUD();
			else
				acc *= fric * fric;

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

		updateMove(dt);

		super.update(dt);


		if( moving != null ) {
			var m = moving;
			dir = hxd.Direction.from(m.dx * m.way, m.dy * m.way);
		}


		var targetR = 54, targetG = 69, targetB = 79;
		var cid = carry.length == 0 ? null : carry[carry.length - 1].kind;
		switch( cid ) {
		case null:
			//
		case Square1:
			targetR = 90;
			targetG = 230;
			targetB = 34;
		case Square2:
			targetR = 134;
			targetG = 43;
			targetB = 171;
		case Wings:
			targetR = targetG = targetB = 0;
			flying += dt * 0.05;
			if( flying > 1 ) flying = 1;
		default:
		}
		if( cid != Wings ) {
			flying -= dt * 0.02;
			if( flying < 0 ) flying = 0;
		}

		var p = 1 - Math.pow(0.95, dt);
		colorRepl.colorDst.r = hxd.Math.lerp(colorRepl.colorDst.r, targetR / 255, p);
		colorRepl.colorDst.g = hxd.Math.lerp(colorRepl.colorDst.g, targetG / 255, p);
		colorRepl.colorDst.b = hxd.Math.lerp(colorRepl.colorDst.b, targetB / 255, p);

		time += dt * 0.05;
		colHero.x = spr.x;
		colHero.y = spr.y;
		spr.y -= (Math.sin(time) + 1) * (1 + flying * 2) + 10 + flying * 8;
	}

}