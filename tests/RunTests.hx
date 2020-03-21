package;

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
		// js.aws.Aws.config.logger = cast js.Node.console;
		Runner
			.run(TestBatch.make([
				// new RunTests(new Local({root: Sys.getCwd() + '/test-folder', getDownloadUrl: null, getUploadUrl: null})),
				new RunTests(new S3('test-bucket', {endpoint: 'http://localhost:4572/test-bucket', s3BucketEndpoint: true})),
			]))
			.handle(Runner.exit);
	}

	var fs:Fs;

	function new(fs)
		this.fs = fs;

	@:setup
	@:timeout(200000)
	public function setup():Promise<Noise> {
		return switch Std.instance(fs, S3) {
			case null: Promise.NOISE;
			case s3:
				Future
					.async(function(cb) {
						var trials = 60;
						function wait() {
							// trace('Checking if localstack is ready... ($trials)');
							// var proc = new Process('docker-compose', ['-f', 'submodules/localstack/docker-compose.yml', 'logs']);
							// proc.stdout.all().handle(function(o) switch o {
							//   case Success(chunk):
							//     if(chunk.toString().indexOf('Ready.') != -1) cb(Success(Noise));
							//     else if(trials-- > 0) haxe.Timer.delay(wait, 3000);
							//     else cb(Failure(new Error('Localstack not ready')));
							//   case Failure(e):
							//     cb(Failure(e));
							// });
							cb(Noise);
						}
						wait();
					})
					.next(function(_) return @:futurize s3.s3.createBucket({Bucket: s3.bucket}, $cb1));
		}
	}

	@:before
	public function before():Promise<Noise> {
		return fs
			.delete('./')
			.recover(function(_) return Noise);
	}

	@:teardown
	public function teardown():Promise<Noise> {
		return switch Std.instance(fs, S3) {
			case null: Promise.NOISE;
			case s3: fs
					.delete('./')
					.next(function(_) return @:futurize s3.s3.deleteBucket({Bucket: s3.bucket}, $cb1));
		}
	}

	public function readWriteDelete() {
		var path = 'foo/bar.txt';
		var data = 'foobar';
		var file = fs.file(path);
		seq([
			lazy(
				() -> file.exists(),
				exists -> asserts.assert(!exists)
			),
			lazy(
				() -> file.write(data)
			),
			lazy(
				() -> delay(100)
			),
			lazy(
				() -> file.exists(),
				exists -> asserts.assert(exists)
			),
			lazy(
				() -> file
					.read()
					.all()
					,
				chunk -> asserts.assert(chunk.length == data.length)
			),
			lazy(
				() -> file.delete()
			),
			lazy(
				() -> file.exists(),
				exists -> asserts.assert(!exists)
			),
		])
			.handle(asserts.handle);
		return asserts;
	}

	@:variant('Recursive'(true, false))
	@:variant('Non-Recursive'(false, true))
	@:variant('Default'(null, false))
	public function list(recursive:Null<Bool>, result:Bool) {
		seq([
			lazy(() -> Promise.inParallel([for (path in ['dir/foo/bar.txt', 'dir/foo/baz/poo.txt'])
				fs
					.file(path)
					.write(path)
			])),
			lazy(() -> delay(100)), lazy(
				fs.list.bind('dir/foo', recursive),
				v -> asserts.assert(v.directories.exists(dir -> dir == 'dir/foo/baz/') == result)
			),
			lazy(
				() -> Promise.inParallel([for (path in ['dir/foo/bar.txt', 'dir/foo/baz/poo.txt'])
					fs
						.file(path)
						.delete()
				])
			),
		])
			.handle(asserts.handle);
		return asserts;
	}

	@:variant('foo/bar.txt', 'foo/bar2.txt')
	public function copy(from:String, to:String) {
		var data = 'foobar';
		var file = fs.file(from);
		seq([
			lazy(
				() -> file.write(data)
			),
			lazy(
				() -> file.copy(to)
			),
			lazy(
				() -> file.exists() && fs
					.file(to)
					.exists()
					,
				result -> asserts.assert(result.a && result.b)
			),
		])
			.handle(asserts.handle);
		return asserts;
	}

	public function deleteFolder() {
		seq([
			lazy(
				() -> Promise.inParallel([for (path in ['dir/foo/bar.txt', 'dir/foo/baz/poo.txt'])
					fs
						.file(path)
						.write(path)
				])
			),
			lazy(
				() -> fs.list('dir/foo/'),
				v -> asserts.assert(v.files.length == 2)
			),
			lazy(
				() -> fs.delete('dir/foo/')
			),
			lazy(
				() -> fs.list('dir/foo/'),
				v -> asserts.assert(v.files.length == 0)
			),
		])
			.handle(asserts.handle);
		return asserts;
	}
}
