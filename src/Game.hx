
@:publicFields
class Game extends hxd.App {

	static var LW = 13;
	static var LH = 13;

	static var LAYER_SOIL = 0;
	static var LAYER_COL = 1;
	static var LAYER_ENT = 2;

	var tiles : h2d.Tile;
	var level : Data.Level;
	var soils : Array<Data.Soil>;
	var entities : Array<ent.Entity> = [];
	var world : h2d.Layers;
	var collides : Array<Bool> = [];
	var dbgCol : h2d.TileGroup;

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
				var s = getSoil(x, y);
				soilLayer.add(x * 32, y * 32, tiles.sub(s.image.x * 32, s.image.y * 32, 32, 32));
				var ent : ent.Entity = null;
				switch( objects[x + y * LW].id ) {
				case None:
				case Hero:
					ent = new ent.Hero(x, y);
				case var kind:
					ent = new ent.Object(kind, x, y);
				}
				if( ent != null )
					entities.push(ent);
			}
	}

	function getSoil( x, y ) {
		return soils[x + y * LH];
	}

	function isCollide( x, y ) {
		switch( getSoil(x, y).id ) {
		case Block:
			return true;
		default:
		}
		if( collides[x + y * LW] )
			return true;
		return false;
	}

	function setCol(ix:Int,iy:Int) {
		if( collides[ix + iy * Game.LW] )
			return;
		collides[ix + iy * Game.LW] = true;
		updateCol();
	}

	function updateCol() {
		var t = h2d.Tile.fromColor(0xFF0000, 32, 32);
		if( dbgCol == null ) {
			dbgCol = new h2d.TileGroup(t);
			dbgCol.alpha = 0.2;
			world.add(dbgCol, LAYER_COL);
		}
		dbgCol.clear();
		for( y in 0...LH )
			for( x in 0...LW )
				if( isCollide(x, y) )
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