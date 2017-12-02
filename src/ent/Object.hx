package ent;

class Object extends Entity {

	var speed = 0.2;
	var angle = 0.;
	var wasCarried = false;
	var color : h3d.shader.ColorAdd;
	var pulse : Float = 0.;
	public var active : Bool;
	public var carried(default,set) : Bool = false;

	function set_carried(b) {
		var ix = Std.int(x);
		var iy = Std.int(y);
		if( b )
			active = false;
		else {
			switch( kind ) {
			case Square1 if( hasObj(ix, iy, Plate1) ):
				active = true;
			case Square2 if( hasObj(ix, iy, Plate2) ):
				active = true;
			default:
			}
		}
		wasCarried = carried;
		game.world.add(spr, b ? Game.LAYER_CARRY : Game.LAYER_ENT);
		if( b )
			angle = Math.atan2(game.hero.y - y, game.hero.x - x);
		return carried = b;
	}

	override function isCollide( with : ent.Entity ) {
		if( kind == Plate1 )
			return with == null || (with.kind != Hero && with.kind != Square1);
		if( kind == Plate2 )
			return with == null || (with.kind != Hero && with.kind != Square2);
		return !carried;
	}

	override function canPick() {
		if( kind == Plate1 || kind == Plate2 )
			return false;
		return !carried;
	}

	override public function update(dt:Float) {


		if( active ) {
			pulse += dt * 0.1;
			spr.adjustColor({ saturation : Math.abs(Math.sin(pulse)) * 0.5, lightness : Math.abs(Math.sin(pulse)) * 0.2 });
		} else if( pulse != 0 ) {
			pulse %= Math.PI;
			pulse += dt * 0.1;
			if( pulse > Math.PI )
				pulse = 0;
			spr.adjustColor({ saturation : Math.abs(Math.sin(pulse)) * 0.5, lightness : Math.abs(Math.sin(pulse)) * 0.2 });
		}


		if( carried ) {
			var hero = game.hero;
			var index = hero.carry.length - 1 - hero.carry.indexOf(this);
			var hpos = hero.history[hero.history.length - 4 - index * 8];
			if( hpos == null ) hpos = hero.history[hero.history.length - 1];
			if( hpos == null ) hpos = { x : Std.int(hero.x * Hero.STEP), y : Std.int(hero.y * Hero.STEP), evt : 0, mx : 0, my : 0 };
			var tx = (hpos.x / Hero.STEP) * 32;
			var ty = (hpos.y / Hero.STEP) * 32;
			var tangle = Math.atan2(ty - spr.y, tx - spr.x);

			angle = hxd.Math.angleMove(angle, tangle, 0.4 * dt);
			var ds = speed * dt * hxd.Math.distance(spr.x - tx, spr.y - ty);
			spr.x += Math.cos(angle) * ds;
			spr.y += Math.sin(angle) * ds;
			return;
		} else {

			switch( kind ) {
			case Plate1:
				active = hasObj(Std.int(x), Std.int(y), Square1);
			case Plate2:
				active = hasObj(Std.int(x), Std.int(y), Square2);
			default:
			}

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