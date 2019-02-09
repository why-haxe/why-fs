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
	function list(path:String, ?recursive:Bool):Promise<Array<Entry>>;
	
	/**
	 *  Check if a file exists
	 *  @param path - 
	 *  @return Promise<Bool>
	 */
	function exists(path:String):Promise<Bool>;
	
	/**
	 *  Move (rename) a file
	 *  @param from - 
	 *  @param to - 
	 *  @return Promise<Noise>
	 */
	function move(from:String, to:String):Promise<Noise>;
	
	/**
	 *  Copy a file
	 *  @param from - 
	 *  @param to - 
	 *  @return Promise<Noise>
	 */
	function copy(from:String, to:String):Promise<Noise>;
	
	/**
	 *  Create a read stream to the target file
	 *  @param path - 
	 *  @return RealSource
	 */
	function read(path:String):RealSource;
	
	/**
	 *  Create a write stream to the target file
	 *  @param path - 
	 *  @return RealSink
	 */
	function write(path:String, ?options:WriteOptions):RealSink;
	
	/**
	 *  Delete (recursively) all files with the path prefix
	 *  @param path - 
	 *  @return Promise<Noise>
	 */
	function delete(path:String):Promise<Noise>;
	
	/**
	 *  Get the file information
	 *  @param path - 
	 *  @return Promise<Stat>
	 */
	function stat(path:String):Promise<Stat>;
	
	/**
	 *  Create a URL that can be used to download the file
	 *  @param path - 
	 *  @return Promise<String>
	 */
	function getDownloadUrl(path:String, ?options:DownloadOptions):Promise<RequestInfo>;
	
	/**
	 *  Create a URL that can be used to upload the file
	 *  @param path - 
	 *  @return Promise<String>
	 */
	function getUploadUrl(path:String, ?options:UploadOptions):Promise<RequestInfo>;
}

typedef Stat = {
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

enum EntryType {
  File;
  Directory;
}

@:forward
abstract Entry({path:String, type:EntryType, stat:Stat}) to {path:String, type:EntryType, stat:Stat} {
  public inline function new(path, type, stat) 
    this = {path: path, type: type, stat: stat}
  
  @:to
  public inline function toString():String
    return this.path;
}