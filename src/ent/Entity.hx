package ent;

class Entity {

	var game : Game;
	var inf : Data.Object;
	public var kind : Data.ObjectKind;
	public var x : Float;
	public var y : Float;
	public var spr : h2d.Anim;

	public function new( kind, x : Int, y : Int ) {
		game = Game.inst;
		this.kind = kind;
		inf = Data.object.get(kind);
		this.x = x + 0.5;
		this.y = y + 0.5;
		spr = new h2d.Anim(getAnim(), 15);
		game.world.add(spr, Game.LAYER_ENT);
		game.entities.push(this);
	}

	public function isCollide( with : ent.Entity ) {
		return true;
	}

	function hasObj( x : Int, y : Int, k : Data.ObjectKind ) {
		for( e in game.entities ) {
			var o = Std.instance(e, Object);
			if( o == null || o.carried ) continue;
			if( Std.int(o.x) != x || Std.int(o.y) != y ) continue;
			if( o.kind == k )
				return true;
		}
		return false;
	}

	public function canPick() {
		return false;
	}

	public function remove() {
		spr.remove();
		game.entities.remove(this);
	}

	function getAnim() {
		return [game.tiles.sub(inf.image.x * 32, inf.image.y * 32, 32, 32, -16, -16)];
	}

	public function update( dt : Float ) {
		spr.x = Std.int(x * 32);
		spr.y = Std.int(y * 32);
	}


	function toString() {
		return kind + "(" + Std.int(x) + "," + Std.int(y) + ")";
	}


}