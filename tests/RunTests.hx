package ;

import tink.unit.*;
import tink.unit.Helper.*;
import tink.testrunner.*;
import why.Fs;
import why.fs.*;
import asys.io.*;

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
      new RunTests(new S3('test-bucket', {endpoint: 'http://localhost:4572/test-bucket', s3BucketEndpoint: true})),
    ])).handle(Runner.exit);
  }
  
  var fs:Fs;
  function new(fs) this.fs = fs;
  
  @:setup
  @:timeout(200000)
  public function setup():Promise<Noise> {
    return switch Std.instance(fs, S3) {
      case null: Promise.NOISE;
      case s3: 
        Future.async(function(cb) {
          var trials = 60;
          function wait() {
            // trace('Checking if localstack is ready... ($trials)');
            var proc = new Process('docker-compose', ['-f', 'submodules/localstack/docker-compose.yml', 'logs']);
            proc.stdout.all().handle(function(o) switch o {
              case Success(chunk):
                if(chunk.toString().indexOf('Ready.') != -1) cb(Success(Noise));
                else if(trials-- > 0) haxe.Timer.delay(wait, 3000);
                else cb(Failure(new Error('Localstack not ready')));
              case Failure(e):
                cb(Failure(e));
            });
          }
          wait();
        }).next(function(_) return @:futurize s3.s3.createBucket({Bucket: s3.bucket}, $cb1));
    }
  }
  
  @:before
  public function before():Promise<Noise> {
    return fs.delete('./').recover(function(_) return Noise);
  }
  
  @:teardown
  public function teardown():Promise<Noise> {
    return switch Std.instance(fs, S3) {
      case null: Promise.NOISE;
      case s3: @:futurize s3.s3.deleteBucket({Bucket: s3.bucket}, $cb1);
    }
  }
  
  public function readWriteDelete() {
    var path = 'foo/bar.txt';
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
  
  @:include
  public function deleteFolder() {
    seq([
      lazy(
        function() return Promise.inParallel([for(path in ['dir/foo/bar.txt', 'dir/foo/baz/poo.txt'])
          (path:IdealSource).pipeTo(fs.write(path), {end: true})
        ])
      ),
      lazy(
        function() return fs.list('dir/foo/'),
        function(entries) asserts.assert(entries.length == 2)
      ),
      lazy(
        function() return fs.delete('dir/foo/')
      ),
      lazy(
        function() return fs.list('dir/foo/'),
        function(entries) asserts.assert(entries.length == 0)
      ),
    ]).handle(asserts.handle);
    return asserts;
  }
}