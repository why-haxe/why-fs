package why.fs;

class Util {
	public static function removeLeadingSlash(path:String) {
		if(path.charCodeAt(0) == '/'.code) path = path.substr(1);
		return path;
	}
	public static function endsWithCharCode(v:String, code:Int) {
		return v.length > 0 && v.charCodeAt(v.length - 1) == code;
	}
}