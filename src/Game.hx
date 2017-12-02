
@:publicFields
class Game extends hxd.App {

	static var LW = 13;
	static var LH = 13;

	static var LAYER_SOIL = 0;
	static var LAYER_COL = 1;
	static var LAYER_ENT = 2;
	static var LAYER_CARRY = 3;

	var tiles : h2d.Tile;
	var level : Data.Level;
	var soils : Array<Data.Soil>;
	var entities : Array<ent.Entity> = [];
	var world : h2d.Layers;
	var collides : Array<Int> = [];
	var dbgCol : h2d.TileGroup;
	var hero : ent.Hero;

	override function init() {
		s2d.setFixedSize(LW * 32, LH * 32 + 16);

		world = new h2d.Layers(s2d);
		tiles = hxd.Res.tiles.toTile();

		var soilLayer = new h2d.TileGroup(tiles);
		world.add(soilLayer, LAYER_SOIL);
		level = Data.level.all[0];
		soils = level.soils.decode(Data.soil.all);

		var objects = level.objects.decode(Data.object.all);
		for( y in 0...LH )
			for( x in 0...LW ) {
				var s = soils[x+y*LW];
				soilLayer.add(x * 32, y * 32, tiles.sub(s.image.x * 32, s.image.y * 32, 32, 32));
				createObject(objects[x + y * LW].id, x, y);
			}
		updateCol();
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
		for( e in entities.copy() )
			e.update(dt);
	}


	public static var inst : Game;

	static function main() {
		hxd.Res.initLocal();
		Data.load(hxd.Res.data.entry.getText());
		inst = new Game();
	}

}