package ent;

class Entity {

	var game : Game;
	var kind : Data.ObjectKind;
	var inf : Data.Object;
	var x : Float;
	var y : Float;
	var spr : h2d.Anim;

	public function new( kind, x : Float, y : Float ) {
		game = Game.inst;
		this.kind = kind;
		inf = Data.object.get(kind);
		this.x = x;
		this.y = y;
		spr = new h2d.Anim(getAnim(), 15);
		game.world.add(spr, Game.LAYER_ENT);
	}

	function getAnim() {
		return [game.tiles.sub(inf.image.x * 32, inf.image.y * 32, 32, 32, -16, -16)];
	}

	public function update( dt : Float ) {
		spr.x = Std.int(x * 32) + 16;
		spr.y = Std.int(y * 32) + 16;
	}

}