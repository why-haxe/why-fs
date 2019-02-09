package why.fs;

import why.Fs;

using asys.io.File;
using asys.FileSystem;
using tink.CoreApi;
using tink.io.Sink;
using tink.io.Source;
using haxe.io.Path;
using StringTools;

@:require('asys')
class Local implements Fs {
  
  var root:String;
  var _getDownloadUrl:String->DownloadOptions->Promise<RequestInfo>;
  var _getUploadUrl:String->UploadOptions->Promise<RequestInfo>;
  
  public function new(options:LocalOptions) {
    root = options.root;
    _getDownloadUrl = options.getDownloadUrl;
    _getUploadUrl = options.getUploadUrl;
  }
  
  public function download(req:RequestInfo, local:String):Progress<Outcome<Noise, Error>> {
    throw 'download not implemented';
  }
    
  public function list(path:String, ?recursive:Bool = true):Promise<Array<Entry>> {
    var fullpath = getFullPath(path);
    inline function trim(v:String) return v.charCodeAt(0) == '/'.code ? v.substr(1) : v;
    return 
      fullpath.exists().next(function(exists) {
        var ret:Array<Entry> = [];
        return 
          if(!exists) {
            ret;
          } else {
            function read(f:String):Promise<Noise> {
              return 
                f.readDirectory()
                  .next(function(files) {
                      return Promise.inParallel([for(item in files) {
                        var path = Path.join([f, item]);
                        path.isDirectory().next(function(isDir) {
                          return
                            if(isDir) {
                              if(recursive) {
                                read(path);
                              } else {
                                ret.push(new Entry(trim(path.substr(fullpath.length)), Directory, {}));
                                Noise;
                              }
                            } else {
                              ret.push(new Entry(trim(path.substr(fullpath.length)), File, {}));
                              Noise;
                            }
                        });
                      }]);
                  });
            }
            read(fullpath).swap(ret);
          }
      });
  }
    
  public function exists(path:String):Promise<Bool>
    return getFullPath(path).exists();
    
  public function move(from:String, to:String):Promise<Noise> {
    var to = getFullPath(to);
    return ensureDirectory(to.directory())
      .next(function(_) return getFullPath(from).rename(to));
  }
    
  public function copy(from:String, to:String):Promise<Noise> {
    var to = getFullPath(to);
    return ensureDirectory(to.directory())
      .next(function(_) return getFullPath(from).copy(to));
  }
    
  public function read(path:String):RealSource
    return getFullPath(path).readStream();
  
  public function write(path:String, ?options:WriteOptions):RealSink {
    path = getFullPath(path);
    return ensureDirectory(path.directory())
      .next(function(_) return path.writeStream());
  }
  
  public function delete(path:String):Promise<Noise> {
    var fullpath = getFullPath(path);
    return fullpath.exists()
      .next(function(exists) {
        return
          if(!exists) new Error(NotFound, 'Path "$fullpath" does not exist');
          else fullpath.isDirectory();
      })
      .next(function(isDir) {
        return isDir ? fullpath.deleteDirectory() : fullpath.deleteFile();
      });
  }
  
  public function stat(path:String):Promise<Stat> {
    return getFullPath(path).stat().asPromise()
      .next(function(stat):Stat return {
        size: stat.size,
        mime: mime.Mime.lookup(path),
        lastModified: stat.mtime,
      });
  }
  
  public function getDownloadUrl(path:String, ?options:DownloadOptions):Promise<RequestInfo>
    return _getDownloadUrl(path, options);
    
  public function getUploadUrl(path:String, ?options:UploadOptions):Promise<RequestInfo>
    return _getUploadUrl(path, options);
  
  inline function getFullPath(path:String) {
    var full = Path.join([root, path]);
    while(full.startsWith('.//')) full = '.' + full.substr(2); // https://github.com/HaxeFoundation/haxe/issues/7548
    return full.normalize();
  }
    
  function ensureDirectory(dir:String):Promise<Noise>
    return dir.exists().next(function(e) return e ? Noise : dir.createDirectory());
}

typedef LocalOptions = {
  root:String,
  getDownloadUrl:String->DownloadOptions->Promise<RequestInfo>,
  getUploadUrl:String->UploadOptions->Promise<RequestInfo>,
}