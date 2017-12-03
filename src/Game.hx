import hxd.Key in K;

class EnvPart extends h2d.SpriteBatch.BatchElement {

	public var speed : Float;
	public var rspeed : Float;

	public function new(t) {
		super(t);
		x = Math.random() * Game.LW * 32;
		y = Math.random() * Game.LH * 32;
		speed = 6 + Math.random() * 3;
		rspeed = 0.02 * (1 + Math.random());
	}

}

@:publicFields
class Game extends hxd.App {

	static var LW = 13;
	static var LH = 13;

	static var LAYER_SOIL = 0;
	static var LAYER_ENT_UNDER = 1;
	static var LAYER_COL = 2;
	static var LAYER_ENT = 3;
	static var LAYER_CARRY = 4;
	static var LAYER_HERO = 5;
	static var LAYER_PARTS = 6;
	static var LAYER_ENVP = 7;

	var tiles : h2d.Tile;
	var level : Data.Level;
	var soils : Array<Data.Soil>;
	var entities : Array<ent.Entity> = [];
	var world : h2d.Layers;
	var collides : Array<Int> = [];
	var dbgCol : h2d.TileGroup;
	var hero : ent.Hero;
	var currentLevel = 7;
	var soilLayer : h2d.TileGroup;
	var pad : hxd.Pad;
	var allActive : Bool;

	var bg : h2d.Sprite;
	var clouds = [];

	var parts : h2d.SpriteBatch;
	var way : Float = 1.;
	var bmpTrans : h2d.Bitmap;

	override function init() {
		s2d.setFixedSize(LW * 32, LH * 32);

		world = new h2d.Layers(s2d);
		//world.filter = new h2d.filter.Bloom(0.5,0.1,2,3);
		tiles = hxd.Res.tiles.toTile();
		soilLayer = new h2d.TileGroup(tiles);

		bg = new h2d.Sprite(world);
		bg.filter = new h2d.filter.Blur(1, 3);
		bg.filter.smooth = true;
		var tbg = tiles.sub(32 * 3, 64, 32, 32);
		tbg.scaleToSize(LW*32, LH*32);
		new h2d.Bitmap(tbg, bg);

		var rnd = new hxd.Rand(42);
		var ctiles = [for( i in 0...3 ) tiles.sub(i * 32 * 3, 192, 32 * 3, 64, -32 * 3 >> 1, -32)];
		for( i in 0...100 ) {
			var b = new h2d.Bitmap(ctiles[rnd.random(ctiles.length)], bg);
			b.smooth = true;
			clouds.push({ sc : 0.7 + rnd.rand(), x : rnd.rand() * (LW * 32 + 200) - 100, y : rnd.rand() * (LH * 32 + 200) - 100, speed : rnd.rand() + 1, spr : b, t : Math.random() * Math.PI * 2 });
		}

		var ptiles = hxd.Res.envParts.toTile().split();
		parts = new h2d.SpriteBatch(ptiles[0]);
		world.add(parts, LAYER_ENVP);
		for( i in 0...100 )
			parts.add(new EnvPart(ptiles[Std.random(ptiles.length)]));

		world.add(soilLayer, LAYER_SOIL);
		initLevel();

		pad = hxd.Pad.createDummy();
		hxd.Pad.wait(function(p) pad = p);

		hxd.Res.data.watch(onReload);
	}

	function onReload() {
		Data.load(hxd.Res.data.entry.getText());
		initLevel(true);
	}

	function nextLevel() {
		haxe.Timer.delay(function() {
			for( e in entities.copy() )
				if( e.hasFlag(NeedActive) )
					e.remove();
			bg.visible = false;
			parts.visible = false;
			hero.remove();

			var t = new h3d.mat.Texture(LW * 32, LH * 32, [Target]);
			var old = world.filter;
			world.filter = null;
			world.drawTo(t);
			world.filter = old;
			bmpTrans = new h2d.Bitmap(h2d.Tile.fromTexture(t));

			bg.visible = true;
			parts.visible = true;

			currentLevel++;
			initLevel();

			world.add(bmpTrans, LAYER_ENT - 1);

		},0);
	}

	function initLevel( ?reload ) {


		level = Data.level.all[currentLevel];
		if( level == null )
			return;

		if( !reload )
			for( e in entities.copy() )
				e.remove();

		soils = level.soils.decode(Data.soil.all);

		while( soilLayer.numChildren > 0 )
			soilLayer.getChildAt(0).remove();

		var cdb = new h2d.CdbLevel(Data.level, currentLevel);
		cdb.redraw();
		var layer = cdb.getLevelLayer("border");
		if( layer != null ) {
			layer.content.addShader(new h3d.shader.SinusDeform(20,0.002,3));
			soilLayer.addChild(layer.content);
		}
		var layer = cdb.getLevelLayer("border2");
		if( layer != null ) {
			layer.content.addShader(new h3d.shader.SinusDeform(20,0.002,3));
			soilLayer.addChild(layer.content);
		}

		var objects = level.objects.decode(Data.object.all);
		var empty = tiles.sub(0, 2 * 32, 32, 32);
		soilLayer.clear();
		for( y in 0...LH )
			for( x in 0...LW ) {
				var s = soils[x + y * LW];
				if( s.id != Block2 ) {
					if( s.id != Block )
						soilLayer.add(x * 32, y * 32, empty);
					if( s.id != Empty )
						soilLayer.add(x * 32, y * 32, tiles.sub(s.image.x * 32, s.image.y * 32, 32, 32));
				}
				if( !reload )
					createObject(objects[x + y * LW].id, x, y);
			}
		updateCol();
		collides = [];
		@:privateAccess hero.rebuildCol();
	}

	function createObject(kind : Data.ObjectKind, x, y) : ent.Entity {
		switch( kind ) {
		case None:
			return null;
		case Hero:
			return hero = new ent.Hero(x, y);
		default:
		}
		return new ent.Object(kind, x, y);
	}

	function getSoil( x, y ) : Data.SoilKind {
		if( x < 0 || y < 0 || x >= LW || y >= LH )
			return Block;
		return soils[x + y * LH].id;
	}

	function pick( x : Float, y : Float ) {
		var ix = Std.int(x);
		var iy = Std.int(y);
		for( e in entities )
			if( Std.int(e.x) == ix && Std.int(e.y) == iy && e.canPick() )
				return e;
		return null;
	}

	function isCollide( e : ent.Entity, x, y ) {
		switch( getSoil(x, y) ) {
		case Block:
			return true;
		case Block2 if( e != hero || !hero.doCarry(Wings,true) ):
			return true;
		default:
		}
		var i = collides[x + y * LW];
		if( i > 0 ) {

			if( !hero.padActive && e == hero && i < 16 ) {
				// skip
			} else {
				return true;
			}
		}

		for( e2 in entities )
			if( e2 != e && Std.int(e2.x) == x && Std.int(e2.y) == y && e2.isCollide(e) )
				return true;

		return false;
	}

	function updateCol() {
		return;
		var t = h2d.Tile.fromColor(0xFF0000, 32, 32);
		if( dbgCol == null ) {
			dbgCol = new h2d.TileGroup(t);
			dbgCol.alpha = 0.2;
			world.add(dbgCol, LAYER_COL);
		}
		dbgCol.clear();
		for( y in 0...LH )
			for( x in 0...LW )
				if( isCollide(null, x, y) )
					dbgCol.add(x * 32, y * 32, t);
	}


	override function update( dt : Float ) {

		if( bmpTrans != null ) {
			bmpTrans.alpha -= 0.05 * dt;
			if( bmpTrans.alpha < 0 ) {
				bmpTrans.tile.getTexture().dispose();
				bmpTrans.remove();
				bmpTrans = null;
			}
		}

		if( K.isPressed("R".code) || K.isPressed("K".code) )
			initLevel();

		if( (K.isPressed(K.BACKSPACE) || K.isPressed(K.PGUP)) && currentLevel > 0 ) {
			currentLevel--;
			initLevel();
		}

		if( K.isPressed(K.PGDOWN) && currentLevel < Data.level.all.length - 1 ) {
			currentLevel++;
			initLevel();
		}


		for( e in entities.copy() )
			e.update(dt);

		allActive = true;
		for( e in entities ) {
			var o = Std.instance(e, ent.Object);
			if( o != null && !o.active && o.hasFlag(NeedActive) )
				allActive = false;
		}

		var ang = -0.3;


		var curWay = hero.movingAmount < 0 ? hero.movingAmount * 4 : 1;
		way = hxd.Math.lerp(way, curWay, 1 - Math.pow(0.5, dt));


		for( c in clouds ) {
			var ds = c.speed * dt * 0.3 * way;

			c.t += ds * 0.01;
			c.spr.setScale(1 + Math.sin(c.t) * 0.2);
			c.spr.scaleX *= c.sc;

			c.x += Math.cos(ang) * ds;
			c.y += Math.sin(ang) * ds;
			c.spr.x = c.x;
			c.spr.y = c.y;
			if( c.x > LW * 32 + 100 )
				c.x -= LW * 32 + 300;
			if( c.y > LH * 32 + 100 )
				c.y -= LH * 32 + 300;
			if( c.x < -100 )
				c.x += LW * 32 + 300;
			if( c.y < -100 )
				c.y += LH * 32 + 300;

		}

		parts.hasRotationScale = true;
		for( p in parts.getElements() ) {
			var p = cast(p, EnvPart);
			var ds = dt * p.speed * way;
			p.x += Math.cos(ang) * ds;
			p.y += Math.sin(ang) * ds;
			p.rotation += ds * p.rspeed;
			if( p.x > LW * 32 )
				p.x -= LW * 32;
			if( p.y > LH * 32 )
				p.y -= LH * 32;
			if( p.y < 0 )
				p.y += LH * 32;
			if( p.x < 0 )
				p.x += LW * 32;
		}

	}


	public static var inst : Game;

	static function main() {
		hxd.res.Resource.LIVE_UPDATE = true;
		hxd.Res.initLocal();
		Data.load(hxd.Res.data.entry.getText());
		inst = new Game();
	}

}