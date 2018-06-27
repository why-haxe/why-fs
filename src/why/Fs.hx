package why;

import tink.http.Method;

using tink.CoreApi;
using tink.io.Sink;
using tink.io.Source;

interface Fs {
	/**
	 *  List all files with the path prefix
	 *  @param path - 
	 *  @return Promise<Array<String>>
	 */
	function list(path:String):Promise<Array<String>>;
	
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
	function getDownloadUrl(path:String, ?options:DownloadOptions):Promise<UrlRequest>;
	
	/**
	 *  Create a URL that can be used to upload the file
	 *  @param path - 
	 *  @return Promise<String>
	 */
	function getUploadUrl(path:String, ?options:UploadOptions):Promise<UrlRequest>;
}

typedef Stat = {
  size:Int,
  mime:String,
}

typedef UrlRequest = {
	method:Method,
	url:String,
}

typedef WriteOptions = {
	?isPublic:Bool,
}

typedef DownloadOptions = {
	?isPublic:Bool,
}

typedef UploadOptions = {
	?mime:String,
	?isPublic:Bool,
}