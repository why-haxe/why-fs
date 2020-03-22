package why;

import haxe.DynamicAccess;
import tink.http.Method;
import tink.http.Header;
import tink.state.Progress;

using tink.CoreApi;
using tink.io.Sink;
using tink.io.Source;

interface Fs {
	/**
	 *  Download a file
	 *  @param req -
	 *  @param local - loca path
	 *  @return Progress<Outcome<Noise, Error>>
	 */
	function download(req:RequestInfo, local:String):Progress<Outcome<Noise, Error>>;

	/**
	 *  List all files that starts with the path prefix.
	 *  Returned values have the prefix stripped
	 *  @param path -
	 *  @return Promise<Array<String>>
	 */
	function list(path:String, ?recursive:Bool):Promise<ListResult>;

	function file(path:String):File;

	function delete(path:String):Promise<Noise>;
}

interface File {
	final info:Info;
	final path:String;

	/**
	 *  Check if a file exists
	 *  @return Promise<Bool>
	 */
	function exists():Promise<Bool>;

	/**
	 *  Move (rename) a file
	 *  @param to -
	 *  @return Promise<Noise>
	 */
	function move(to:String):Promise<Noise>;

	/**
	 *  Copy a file
	 *  @param to -
	 *  @return Promise<Noise>
	 */
	function copy(to:String):Promise<Noise>;

	/**
	 *  Create a read stream to the target file
	 *  @return RealSource
	 */
	function read():RealSource;

	/**
	 *  Create a write stream to the target file
	 *  @return RealSink
	 */
	function write(source:RealSource, ?options:WriteOptions):Promise<Noise>;

	/**
	 *  Delete (recursively) all files with the path prefix
	 *  @return Promise<Noise>
	 */
	function delete():Promise<Noise>;

	/**
	 *  Get the file information
	 *  @return Promise<Stat>
	 */
	function getInfo():Promise<Info>;

	/**
	 *  Create a URL that can be used to download the file
	 *  @return Promise<String>
	 */
	function getDownloadUrl(?options:DownloadOptions):Promise<RequestInfo>;

	/**
	 *  Create a URL that can be used to upload the file
	 *  @return Promise<String>
	 */
	function getUploadUrl(?options:UploadOptions):Promise<RequestInfo>;
}

typedef ListResult = {
	files:Array<File>,
	directories:Array<String>,
}

typedef Info = {
	?size:Int,
	?mime:String,
	?lastModified:Date,
	?metadata:DynamicAccess<String>,
}

typedef RequestInfo = {
	method:Method,
	url:String,
	headers:Array<HeaderField>,
}

typedef WriteOptions = UploadOptions;

typedef DownloadOptions = {
	?isPublic:Bool,
	?saveAsFilename:String,
}

typedef UploadOptions = {
	?mime:String,
	?isPublic:Bool,
	?cacheControl:String,
	?expires:Date,
	?metadata:DynamicAccess<String>,
}
