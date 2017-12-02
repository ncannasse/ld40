package ent;
import hxd.Key in K;

class Hero extends Entity {

	var lastMX = 0;
	var lastMY = 0;
	var acc = 0.;

	public function new(x,y) {
		super(Hero, x, y);
	}

	override function update(dt:Float) 	{

		if( acc > 5 ) acc = 5;

		var dacc = dt * 0.1;
		var dmove = dt * 0.01 * (acc + 7);
		var drec = dmove * 0.9;

		var fric = Math.pow(0.8, dt);

		var left = K.isDown(K.LEFT);
		var right = K.isDown(K.RIGHT);
		var up = K.isDown(K.UP);
		var down = K.isDown(K.DOWN);

		if( left || right ) {
			var nextY = lastMY > 0 ? Math.ceil(y - 0.3) : Std.int(y + 0.3);
			var nextX = left ? Std.int(x - 1e-3) : Std.int(x) + 1;
			if( !game.isCollide(nextX, nextY) ) {
				if( y < nextY ) {
					y += drec;
					if( y > nextY ) y = nextY;
					acc *= fric;
				} else if( y > nextY ) {
					y -= drec;
					if( y < nextY ) y = nextY;
					acc *= fric;
				} else if( x > nextX ){
					x -= dmove;
					lastMX = -1;
					if( x < nextX ) x = nextX;
					acc += dacc;
				} else {
					x += dmove;
					lastMX = 1;
					if( x > nextX ) x = nextX;
					acc += dacc;
				}
			}
		} else if( up || down ) {
			var nextX = lastMX > 0 ? Math.ceil(x - 0.3) : Std.int(x + 0.3);
			var nextY = up ? Std.int(y - 1e-3) : Std.int(y) + 1;
			if( !game.isCollide(nextX, nextY) ) {
				if( x < nextX ) {
					x += drec;
					if( x > nextX ) x = nextX;
					acc *= fric;
				} else if( x > nextX ) {
					x -= drec;
					if( x < nextX ) x = nextX;
					acc *= fric;
				} else if( y > nextY ){
					y -= dmove;
					lastMY = -1;
					if( y < nextY ) y = nextY;
					acc += dacc;
				} else {
					y += dmove;
					lastMY = 1;
					if( y > nextY ) y = nextY;
					acc += dacc;
				}
			}
		} else {
			acc *= fric * fric;
		}
		super.update(dt);
	}

}