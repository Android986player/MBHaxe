package src;

import mis.MisParser;
import mis.MissionElement.MissionElementScriptObject;
import mis.MissionElement.MissionElementType;
import mis.MisFile;
import mis.MissionElement.MissionElementSimGroup;
import src.ResourceLoader;

class Mission {
	public var root:MissionElementSimGroup;
	public var title:String;
	public var artist:String;
	public var description:String;
	public var qualifyTime = Math.POSITIVE_INFINITY;
	public var goldTime:Float = 0;
	public var type:String;
	public var path:String;
	public var missionInfo:MissionElementScriptObject;
	public var index:Int;

	public function new() {}

	public function load() {
		var misParser = new MisParser(ResourceLoader.fileSystem.get(this.path).getText());
		var contents = misParser.parse();
		root = contents.root;
	}

	public static function fromMissionInfo(path:String, mInfo:MissionElementScriptObject) {
		var mission = new Mission();
		mission.path = path;
		mission.missionInfo = mInfo;

		var missionInfo = mInfo;

		mission.title = missionInfo.name;
		mission.artist = missionInfo.artist == null ? '' : missionInfo.artist;
		mission.description = missionInfo.desc == null ? '' : missionInfo.desc;
		if (missionInfo.time != null && missionInfo.time != "0")
			mission.qualifyTime = MisParser.parseNumber(missionInfo.time) / 1000;
		if (missionInfo.goldtime != null) {
			mission.goldTime = MisParser.parseNumber(missionInfo.goldtime) / 1000;
		}
		mission.type = missionInfo.type.toLowerCase();
		mission.missionInfo = missionInfo;
		return mission;
	}

	public function getPreviewImage() {
		var basename = haxe.io.Path.withoutExtension(this.path);
		if (ResourceLoader.fileSystem.exists(basename + ".png")) {
			return ResourceLoader.getImage(basename + ".png").toTile();
		}
		if (ResourceLoader.fileSystem.exists(basename + ".jpg")) {
			return ResourceLoader.getImage(basename + ".jpg").toTile();
		}
		return null;
	}

	public function getDifPath(rawElementPath:String) {
		rawElementPath = rawElementPath.toLowerCase();
		var path = StringTools.replace(rawElementPath.substring(rawElementPath.indexOf('data/')), "\"", "");
		if (StringTools.contains(path, 'interiors_mbg/'))
			path = StringTools.replace(path, 'interiors_mbg/', 'interiors/');
		if (ResourceLoader.fileSystem.exists(path))
			return path;
		return "";
	}
}
