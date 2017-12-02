import hxd.Key in K;

@:publicFields
class Game extends hxd.App {

	static var LW = 13;
	static var LH = 13;

	static var LAYER_SOIL = 0;
	static var LAYER_ENT_UNDER = 1;
	static var LAYER_COL = 2;
	static var LAYER_ENT = 3;
	static var LAYER_CARRY = 4;

	var tiles : h2d.Tile;
	var level : Data.Level;
	var soils : Array<Data.Soil>;
	var entities : Array<ent.Entity> = [];
	var world : h2d.Layers;
	var collides : Array<Int> = [];
	var dbgCol : h2d.TileGroup;
	var hero : ent.Hero;
	var currentLevel = 9;
	var soilLayer : h2d.TileGroup;
	var pad : hxd.Pad;
	var allActive : Bool;

	override function init() {
		s2d.setFixedSize(LW * 32, LH * 32);

		world = new h2d.Layers(s2d);
		world.filter = new h2d.filter.Bloom(0.5,0.1,2,3);
		tiles = hxd.Res.tiles.toTile();
		soilLayer = new h2d.TileGroup(tiles);
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

	function initLevel( ?reload ) {


		level = Data.level.all[currentLevel];
		if( level == null )
			return;

		if( !reload )
			for( e in entities.copy() )
				e.remove();

		soils = level.soils.decode(Data.soil.all);

		var objects = level.objects.decode(Data.object.all);
		var empty = tiles.sub(0, 2 * 32, 32, 32);
		soilLayer.clear();
		for( y in 0...LH )
			for( x in 0...LW ) {
				var s = soils[x + y * LW];
				soilLayer.add(x * 32, y * 32, empty);
				if( s.id != Empty )
					soilLayer.add(x * 32, y * 32, tiles.sub(s.image.x * 32, s.image.y * 32, 32, 32));
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
		if( i > (Std.is(e,ent.Hero) ? 16 : 0) )
			return true;

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


		allActive = true;
		for( e in entities.copy() ) {
			e.update(dt);
			var o = Std.instance(e, ent.Object);
			if( o != null && !o.active && o.hasFlag(NeedActive) )
				allActive = false;
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