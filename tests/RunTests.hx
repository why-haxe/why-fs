package ;

import tink.unit.*;
import tink.unit.Helper.*;
import tink.testrunner.*;
import why.Fs;
import why.fs.*;

using tink.CoreApi;
using StringTools;
using haxe.io.Path;
using tink.io.Source;
using tink.io.PipeResult;
using Lambda;

@:asserts
@:access(why.fs)
@:build(futurize.Futurize.build())
class RunTests {

  static function main() {
    Runner.run(TestBatch.make([
      new RunTests(new Local({root: Sys.getCwd() + '/test-folder', getDownloadUrl: null, getUploadUrl: null})),
      // new RunTests(new S3('test-bucket', {endpoint: 'http://localhost:4572/test-bucket', s3BucketEndpoint: true})),
    ])).handle(Runner.exit);
  }
  
  var fs:Fs;
  function new(fs) this.fs = fs;
  
  @:setup
  public function setup():Promise<Noise> {
    return fs.delete('.').recover(function(_) return Noise);
  }
  
  // @:teardown
  // public function teardown():Promise<Noise> {
  // }
  
  public function readWriteDelete() {
    var path = '/foo/bar.txt';
    var data = 'foobar';
    seq([
      lazy(
        function() return fs.exists(path),
        function(exists) asserts.assert(!exists)
      ),
      lazy(
        function() return (data:IdealSource).pipeTo(fs.write(path), {end: true}),
        function(result) asserts.assert(result == AllWritten)
      ),
      lazy(function() return delay(100)),
      lazy(
        function() return fs.exists(path),
        function(exists) asserts.assert(exists)
      ),
      lazy(
        function() return fs.read(path).all(),
        function(chunk) asserts.assert(chunk.length == data.length)
      ),
      lazy(
        function() return fs.delete(path)
      ),
      lazy(
        function() return fs.exists(path),
        function(exists) asserts.assert(!exists)
      ),
    ]).handle(asserts.handle);
    return asserts;
  }
  
  @:variant('Recursive'(true, false))
  @:variant('Non-Recursive'(false, true))
  @:variant('Default'(null, false))
  public function list(recursive:Null<Bool>, result) {
    seq([
      lazy(
        function() return Promise.inParallel([for(path in ['dir/foo/bar.txt', 'dir/foo/baz/poo.txt'])
          (path:IdealSource).pipeTo(fs.write(path), {end: true})
        ])
      ),
      lazy(function() return delay(100)),
      lazy(
        fs.list.bind('dir/foo', recursive),
        function(entries) asserts.assert(entries.exists(function(entry) return entry == 'baz') == result)
      ),
      lazy(
        function() return Promise.inParallel([for(path in ['dir/foo/bar.txt', 'dir/foo/baz/poo.txt'])
          fs.delete(path)
        ])
      ),
    ]).handle(asserts.handle);
    return asserts;
  }
}