package why.fs;

import why.Fs;

@:allow(why.fs)
class Util {
	static function removeLeadingSlash(path:String) {
		if(path.charCodeAt(0) == '/'.code) path = path.substr(1);
		return path;
	}
	
	static function endsWithCharCode(v:String, code:Int) {
		return v.length > 0 && v.charCodeAt(v.length - 1) == code;
	}
	
	static function createEntry(prefix:String, fullpath:String, stat) {
		var path = fullpath.substr(prefix.length);
		if(path == '') return null;
		var isDir = endsWithCharCode(path, '/'.code);
		return new Entry(
			isDir ? path.substr(0, path.length - 1) : path,
			isDir ? Directory : File,
			stat
		);
	}
}