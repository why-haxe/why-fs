package why;

import haxe.DynamicAccess;
import tink.http.Request;
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
	function download(req:OutgoingRequestHeader, local:String):Progress<Outcome<Noise, Error>>;

	/**
	 *  List all files that starts with the path prefix.
	 *  Returned values have the prefix stripped
	 *  @param path -
	 *  @return Promise<ListResult>
	 */
	function list(path:String, ?recursive:Bool):Promise<ListResult>;

	/**
	 *  Get a file object for the specified path
	 *  @return File
	 */
	function file(path:String):File;

	/**
	 *  Delete (recursively) all files with the path prefix
	 *  @return Promise<Noise>
	 */
	function delete(path:String):Promise<Noise>;
}

interface File {
	final info:Info;
	final path:String;

	/**
	 *  Check if this file exists
	 *  @return Promise<Bool>
	 */
	function exists():Promise<Bool>;

	/**
	 *  Move (rename) this file
	 *  @param to destination
	 *  @return Promise<Noise>
	 */
	function move(to:String):Promise<Noise>;

	/**
	 *  Copy this file
	 *  @param to destination
	 *  @return Promise<Noise>
	 */
	function copy(to:String):Promise<Noise>;

	/**
	 *  Create a read stream to this file
	 *  @return RealSource
	 */
	function read():RealSource;

	/**
	 *  Write data to this file (completely replace the existing file)
	 *  @return RealSink
	 */
	function write(source:RealSource, ?options:WriteOptions):Promise<Noise>;

	/**
	 *  Delete this file
	 *  @return Promise<Noise>
	 */
	function delete():Promise<Noise>;

	/**
	 *  Get the information of this file
	 *  @return Promise<Stat>
	 */
	function getInfo():Promise<Info>;

	/**
	 *  Create a URL that can be used to download this file
	 *  @return Promise<String>
	 */
	function getDownloadUrl(?options:DownloadOptions):Promise<OutgoingRequestHeader>;

	/**
	 *  Create a URL that can be used to upload this file
	 *  @return Promise<String>
	 */
	function getUploadUrl(?options:UploadOptions):Promise<OutgoingRequestHeader>;
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
