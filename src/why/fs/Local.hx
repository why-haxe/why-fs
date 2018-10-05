package why.fs;

import why.Fs;

using asys.io.File;
using asys.FileSystem;
using tink.CoreApi;
using tink.io.Sink;
using tink.io.Source;
using haxe.io.Path;

@:require('asys')
class Local implements Fs {
  
  var root:String;
  var _getDownloadUrl:String->DownloadOptions->Promise<UrlRequest>;
  var _getUploadUrl:String->UploadOptions->Promise<UrlRequest>;
  
  public function new(options:LocalOptions) {
    root = options.root.removeTrailingSlashes();
    _getDownloadUrl = options.getDownloadUrl;
    _getUploadUrl = options.getUploadUrl;
  }
    
  public function list(path:String):Promise<Array<String>> {
    var fullpath = getFullPath(path).addTrailingSlash();
    return 
      fullpath.exists().next(function(exists) {
        var ret:Array<String> = [];
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
                            if(isDir)
                              read(path.addTrailingSlash());
                            else {
                              ret.push(path.substr(fullpath.length));
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
    
  public function read(path:String):RealSource
    return getFullPath(path).readStream();
  
  public function write(path:String, ?options:WriteOptions):RealSink {
    path = getFullPath(path);
    return ensureDirectory(path.directory())
      .next(function(_) return path.writeStream());
  }
  
  public function delete(path:String):Promise<Noise> {
    return Future.async(function(cb) {
      var fullpath = getFullPath(path).addTrailingSlash();
      var ret = [];
      var working = 0;
      
      function done() if(--working == 0) cb(Success(Noise));
      function fail(e) cb(Failure(e));
      
      var rm:String->Void;
      
      function rmfile(f:String) {
        working++;
        f.deleteFile().handle(function(o) switch o {
          case Success(_): done();
          case Failure(e): fail(e);
        });
      }
      
      function rmdir(f:String) {
        working ++;
        return 
          f.readDirectory()
            .handle(function(o) switch o {
              case Success(items):
                for(item in items) rm(f.addTrailingSlash() + item);
                done();
              case Failure(e):
                cb(Failure(e));
            });
      }
      
      rm = function(f:String) {
        working++;
        f.isDirectory().handle(function(isDir) {
          working--;
          if(isDir) rmdir(f.addTrailingSlash()) else rmfile(f);
        });
      }
      
      rm(fullpath);
    });
  }
  
  public function stat(path:String):Promise<Stat> {
    return getFullPath(path).stat().asPromise()
      .next(function(stat):Stat return {
        size: stat.size,
        mime: mime.Mime.lookup(path),
      });
  }
  
  public function getDownloadUrl(path:String, ?options:DownloadOptions):Promise<UrlRequest>
    return _getDownloadUrl(path, options);
    
  public function getUploadUrl(path:String, ?options:UploadOptions):Promise<UrlRequest>
    return _getUploadUrl(path, options);
  
  inline function getFullPath(path:String)
    return '$root/$path'.normalize();
    
  function ensureDirectory(dir:String):Promise<Noise>
    return dir.exists().next(function(e) return e ? Noise : dir.createDirectory());
}

typedef LocalOptions = {
  root:String,
  getDownloadUrl:String->DownloadOptions->Promise<UrlRequest>,
  getUploadUrl:String->UploadOptions->Promise<UrlRequest>,
}