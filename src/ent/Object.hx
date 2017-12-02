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
			case Square1 if( getObj(ix, iy, Plate1, [CanPutOver]) != null ):
				active = true;
			case Square2 if( getObj(ix, iy, Plate2, [CanPutOver]) != null ):
				active = true;
			case Wings if( getObj(ix, iy, [CanPutOver]) != null ):
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
		return with != null && with.kind != Hero;
	}

	override function canPick() {
		if( hasFlag(Under) )
			return false;
		if( carried )
			return false;
		return true;
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
			var hpos = hero.history[hero.history.length - 2 - index * 3];
			if( hpos == null ) hpos = hero.history[hero.history.length - 1];
			if( hpos == null ) hpos = { x : Std.int(hero.x * Hero.STEP), y : Std.int(hero.y * Hero.STEP) };
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
			case Plate1, Plate2:
				active = getObj(Std.int(x), Std.int(y)) != null;
			default:
			}
		}

		if( wasCarried ) {
			var tx = x * 32, ty = y * 32;
			var d = hxd.Math.distance(tx - spr.x, ty - spr.y);
			if( d > 1 ) {
				spr.x = hxd.Math.lerp(spr.x, tx, 1 - Math.pow(0.7, dt));
				spr.y = hxd.Math.lerp(spr.y, ty, 1 - Math.pow(0.7, dt));
				return;
			}
			wasCarried = false;
		}
		super.update(dt);
	}

}