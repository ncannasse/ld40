package ent;

class Object extends Entity {

	var speed = 0.2;
	var angle = 0.;
	var wasCarried = false;
	public var carried(default,set) : Bool;

	public function new(kind,x,y) {
		super(kind, x, y);
		switch( kind ) {
		case Square:
			if( game.getSoil(x, y) == Square )
				activate();
		default:
		}
	}

	function set_carried(b) {
		wasCarried = carried;
		game.world.add(spr, b ? Game.LAYER_CARRY : Game.LAYER_ENT);
		if( b )
			angle = Math.atan2(game.hero.y - y, game.hero.x - x);
		return carried = b;
	}

	override function isCollide( with : ent.Entity ) {
		return !carried;
	}

	override function canPick() {
		return !carried;
	}

	function activate() {
		trace("ACTIVATE");
	}

	override public function update(dt:Float) {
		if( carried ) {
			var hero = game.hero;
			var index = hero.carry.length - 1 - hero.carry.indexOf(this);
			var hpos = hero.history[hero.history.length - 1 - index * 8];
			if( hpos == null ) hpos = hero.history[hero.history.length - 1];
			if( hpos == null ) hpos = { x : Std.int(hero.x * Hero.STEP), y : Std.int(hero.y * Hero.STEP), evt : 0 };
			var tx = (hpos.x / Hero.STEP) * 32;
			var ty = (hpos.y / Hero.STEP) * 32;
			var tangle = Math.atan2(ty - spr.y, tx - spr.x);

			angle = hxd.Math.angleMove(angle, tangle, 0.4 * dt);
			var ds = speed * dt * hxd.Math.distance(spr.x - tx, spr.y - ty);
			spr.x += Math.cos(angle) * ds;
			spr.y += Math.sin(angle) * ds;
			return;
		}
		if( wasCarried ) {
			var tx = x * 32, ty = y * 32;
			var d = hxd.Math.distance(tx - spr.x, ty - spr.y);
			if( d > 1 ) {
				spr.x = hxd.Math.lerp(spr.x, tx, 1 - Math.pow(0.5, dt));
				spr.y = hxd.Math.lerp(spr.y, ty, 1 - Math.pow(0.5, dt));
				return;
			}
			wasCarried = false;
		}
		super.update(dt);
	}

}