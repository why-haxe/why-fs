using tink.CoreApi;
using tink.io.Source;

class Playground {
	static function main() {
		why.fs.S3;
		why.fs.GoogleCloudStorage;
		var oss:why.Fs = new why.fs.AliOss({
			region: 'oss-cn-beijing',
			accessKeyId: Sys.getEnv('ALI_ACCESS_KEY_ID'),
			accessKeySecret: Sys.getEnv('ALI_ACCESS_KEY_SECRET'),
			bucket: 'why-fs-test'
		});
		
		function list(prefix)
			oss.list(prefix).handle(function(o) switch o {
				case Success(e): for(e in e) trace(e.type, e.path, e.stat);
				case Failure(e): trace(e);
			});
			
		// list('/');
		// list('myfolder');
		
		oss.read('yarn.lock').all().handle(o -> trace(o.sure().toString()));
		
		// oss.exists('yarn.lock').handle(o -> trace(o));
		// oss.stat('yarn.lock').handle(o -> trace(o));
	}
}