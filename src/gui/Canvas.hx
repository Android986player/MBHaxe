package gui;

import src.MarbleGame;
import h3d.Vector;
import h2d.Scene;
import gui.GuiControl.MouseState;

@:publicFields
class Canvas extends GuiControl {
	var scene2d:Scene;
	var marbleGame:MarbleGame;

	public function new(scene, marbleGame:MarbleGame) {
		super();
		this.scene2d = scene;
		this.marbleGame = marbleGame;

		this.position = new Vector();
		this.extent = new Vector(640, 480);
		this.horizSizing = Width;
		this.vertSizing = Height;
	}

	public function setContent(content:GuiControl) {
		this.dispose();
		this.addChild(content);
		this.render(scene2d);
	}

	public function pushDialog(content:GuiControl) {
		this.addChild(content);
		this.render(scene2d);
	}

	public function popDialog(content:GuiControl) {
		content.dispose();
		this.removeChild(content);
		this.render(scene2d);
	}

	public function clearContent() {
		this.dispose();
		this.render(scene2d);
	}

	public override function update(dt:Float, mouseState:MouseState) {
		super.update(dt, mouseState);
	}
}
