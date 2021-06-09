package src;

import gui.PlayGui;
import src.ParticleSystem.ParticleManager;
import src.Util;
import h3d.Quat;
import shapes.PowerUp;
import collision.SphereCollisionEntity;
import src.Sky;
import h3d.scene.Mesh;
import src.InstanceManager;
import h3d.scene.MeshBatch;
import src.DtsObject;
import src.PathedInterior;
import hxd.Key;
import h3d.Vector;
import src.InteriorObject;
import h3d.scene.Scene;
import h3d.scene.CustomObject;
import collision.CollisionWorld;
import src.Marble;

class MarbleWorld extends Scheduler {
	public var collisionWorld:CollisionWorld;
	public var instanceManager:InstanceManager;
	public var particleManager:ParticleManager;

	var playGui:PlayGui;

	public var interiors:Array<InteriorObject> = [];
	public var pathedInteriors:Array<PathedInterior> = [];
	public var marbles:Array<Marble> = [];
	public var dtsObjects:Array<DtsObject> = [];

	var shapeImmunity:Array<DtsObject> = [];
	var shapeOrTriggerInside:Array<DtsObject> = [];

	public var currentTime:Float = 0;
	public var elapsedTime:Float = 0;
	public var bonusTime:Float = 0;
	public var sky:Sky;

	public var scene:Scene;

	public var marble:Marble;
	public var worldOrientation:Quat;
	public var currentUp = new Vector(0, 0, 1);
	public var outOfBounds:Bool = false;

	var orientationChangeTime = -1e8;
	var oldOrientationQuat = new Quat();

	/** The new target camera orientation quat  */
	public var newOrientationQuat = new Quat();

	public function new(scene:Scene, scene2d:h2d.Scene) {
		this.collisionWorld = new CollisionWorld();
		this.scene = scene;
		this.playGui = new PlayGui();
		this.instanceManager = new InstanceManager(scene);
		this.particleManager = new ParticleManager(cast this);
		this.sky = new Sky();
		sky.dmlPath = "data/skies/sky_day.dml";
		sky.init(cast this);
		playGui.init(scene2d);
		scene.addChild(sky);
	}

	public function start() {
		restart();
		for (interior in this.interiors)
			interior.onLevelStart();
		for (shape in this.dtsObjects)
			shape.onLevelStart();
	}

	public function restart() {
		this.currentTime = 0;
		this.elapsedTime = 0;
		this.bonusTime = 0;
		this.outOfBounds = false;
		this.marble.camera.CameraPitch = 0.45;

		for (shape in dtsObjects)
			shape.reset();
		for (interior in this.interiors)
			interior.reset();

		this.currentUp = new Vector(0, 0, 1);
		this.orientationChangeTime = -1e8;
		this.oldOrientationQuat = new Quat();
		this.newOrientationQuat = new Quat();
		this.deselectPowerUp();

		this.clearSchedule();
	}

	public function updateGameState() {
		if (this.currentTime < 0.5) {
			this.playGui.setCenterText('none');
		}
		if (this.currentTime >= 0.5 && this.currentTime < 2) {
			this.playGui.setCenterText('ready');
		}
		if (this.currentTime >= 2 && this.currentTime < 3.5) {
			this.playGui.setCenterText('set');
		}
		if (this.currentTime >= 3.5 && this.currentTime < 5.5) {
			this.playGui.setCenterText('go');
		}
		if (this.currentTime >= 5.5) {
			this.playGui.setCenterText('none');
		}
		if (this.outOfBounds) {
			this.playGui.setCenterText('outofbounds');
		}
	}

	public function addInterior(obj:InteriorObject) {
		this.interiors.push(obj);
		obj.init(cast this);
		this.collisionWorld.addEntity(obj.collider);
		if (obj.useInstancing)
			this.instanceManager.addObject(obj);
		else
			this.scene.addChild(obj);
	}

	public function addPathedInterior(obj:PathedInterior) {
		this.pathedInteriors.push(obj);
		obj.init(cast this);
		this.collisionWorld.addMovingEntity(obj.collider);
		if (obj.useInstancing)
			this.instanceManager.addObject(obj);
		else
			this.scene.addChild(obj);
	}

	public function addDtsObject(obj:DtsObject) {
		this.dtsObjects.push(obj);
		obj.init(cast this);
		if (obj.useInstancing) {
			this.instanceManager.addObject(obj);
		} else
			this.scene.addChild(obj);
		for (collider in obj.colliders) {
			if (collider != null)
				this.collisionWorld.addEntity(collider);
		}
		this.collisionWorld.addEntity(obj.boundingCollider);
	}

	public function addMarble(marble:Marble) {
		this.marbles.push(marble);
		marble.level = cast this;
		if (marble.controllable) {
			marble.camera.init(cast this);
			marble.init(cast this);
			this.scene.addChild(marble.camera);
			this.marble = marble;
			// Ugly hack
			sky.follow = marble;
		}
		this.collisionWorld.addMovingEntity(marble.collider);
		this.scene.addChild(marble);
	}

	public function update(dt:Float) {
		this.tickSchedule(currentTime);
		this.updateGameState();
		for (obj in dtsObjects) {
			obj.update(currentTime, dt);
		}
		for (marble in marbles) {
			marble.update(currentTime, dt, collisionWorld, this.pathedInteriors);
		}
		this.instanceManager.update(dt);
		this.particleManager.update(1000 * currentTime, dt);
		this.updateTimer(dt);
		this.playGui.update(currentTime, dt);

		if (this.marble != null) {
			callCollisionHandlers(marble);
		}
	}

	public function render(e:h3d.Engine) {
		this.playGui.render(e);
	}

	public function updateTimer(dt:Float) {
		currentTime += dt;
		if (this.bonusTime != 0) {
			this.bonusTime -= dt;
			if (this.bonusTime < 0) {
				this.elapsedTime -= this.bonusTime;
				this.bonusTime = 0;
			}
		} else {
			this.elapsedTime += dt;
		}
		playGui.formatTimer(this.elapsedTime);
	}

	function callCollisionHandlers(marble:Marble) {
		var contacts = this.collisionWorld.radiusSearch(marble.getAbsPos().getPosition(), marble._radius);
		var newImmunity = [];
		var calledShapes = [];
		var inside = [];

		var contactsphere = new SphereCollisionEntity(marble);
		contactsphere.velocity = new Vector();

		for (contact in contacts) {
			if (contact.go != marble) {
				if (contact.go is DtsObject) {
					var shape:DtsObject = cast contact.go;

					var contacttest = shape.colliders.filter(x -> x != null).map(x -> x.sphereIntersection(contactsphere, 0));
					var contactlist:Array<collision.CollisionInfo> = [];
					for (l in contacttest) {
						contactlist = contactlist.concat(l);
					}

					if (!calledShapes.contains(shape) && !this.shapeImmunity.contains(shape) && contactlist.length != 0) {
						calledShapes.push(shape);
						newImmunity.push(shape);
						shape.onMarbleContact(currentTime);
					}

					shape.onMarbleInside(currentTime);
					if (!this.shapeOrTriggerInside.contains(shape)) {
						this.shapeOrTriggerInside.push(shape);
						shape.onMarbleEnter(currentTime);
					}
					inside.push(shape);
				}
			}
		}

		for (object in shapeOrTriggerInside) {
			if (!inside.contains(object)) {
				this.shapeOrTriggerInside.remove(object);
				object.onMarbleLeave(currentTime);
			}
		}

		this.shapeImmunity = newImmunity;
	}

	public function pickUpPowerUp(powerUp:PowerUp) {
		if (this.marble.heldPowerup == powerUp)
			return false;
		this.marble.heldPowerup = powerUp;
		this.playGui.setPowerupImage(powerUp.identifier);
		return true;
	}

	public function deselectPowerUp() {
		this.playGui.setPowerupImage("");
	}

	/** Get the current interpolated orientation quaternion. */
	public function getOrientationQuat(time:Float) {
		var completion = Util.clamp((time - this.orientationChangeTime) / 0.3, 0, 1);
		var q = this.oldOrientationQuat.clone();
		q.slerp(q, this.newOrientationQuat, completion);
		return q;
	}

	public function setUp(vec:Vector, time:Float) {
		this.currentUp = vec;
		var currentQuat = this.getOrientationQuat(time);
		var oldUp = new Vector(0, 0, 1);
		oldUp.transform(currentQuat.toMatrix());

		function getRotQuat(v1:Vector, v2:Vector) {
			function orthogonal(v:Vector) {
				var x = Math.abs(v.x);
				var y = Math.abs(v.y);
				var z = Math.abs(v.z);
				var other = x < y ? (x < z ? new Vector(1, 0, 0) : new Vector(0, 0, 1)) : (y < z ? new Vector(0, 1, 0) : new Vector(0, 0, 1));
				return v.cross(other);
			}

			var u = v1.normalized();
			var v = v2.normalized();
			if (u.multiply(-1).equals(v)) {
				var q = new Quat();
				var o = orthogonal(u).normalized();
				q.x = o.x;
				q.y = o.y;
				q.z = o.z;
				q.w = 0;
				return q;
			}
			var half = u.add(v).normalized();
			var q = new Quat();
			q.w = u.dot(half);
			var vr = u.cross(half);
			q.x = vr.x;
			q.y = vr.y;
			q.z = vr.z;
			return q;
		}

		var quatChange = getRotQuat(oldUp, vec);
		// Instead of calculating the new quat from nothing, calculate it from the last one to guarantee the shortest possible rotation.
		// quatChange.initMoveTo(oldUp, vec);
		quatChange.multiply(quatChange, currentQuat);

		this.newOrientationQuat = quatChange;
		this.oldOrientationQuat = currentQuat;
		this.orientationChangeTime = time;
	}
}

typedef ScheduleInfo = {
	var id:Float;
	var stringId:String;
	var time:Float;
	var callBack:Void->Any;
}

abstract class Scheduler {
	var scheduled:Array<ScheduleInfo> = [];

	public function tickSchedule(time:Float) {
		for (item in this.scheduled) {
			if (time >= item.time) {
				this.scheduled.remove(item);
				item.callBack();
			}
		}
	}

	public function schedule(time:Float, callback:Void->Any, stringId:String = null) {
		var id = Math.random();
		this.scheduled.push({
			id: id,
			stringId: '${id}',
			time: time,
			callBack: callback
		});
		return id;
	}

	/** Cancels a schedule */
	public function cancel(id:Float) {
		var idx = this.scheduled.filter((val) -> {
			return val.id == id;
		});
		if (idx.length == 0)
			return;
		this.scheduled.remove(idx[0]);
	}

	public function clearSchedule() {
		this.scheduled = [];
	}

	public function clearScheduleId(id:String) {
		var idx = this.scheduled.filter((val) -> {
			return val.stringId == id;
		});
		if (idx.length == 0)
			return;
		this.scheduled.remove(idx[0]);
	}
}
