package;
import sys.FileStat;
import haxe.xml.Fast;
import sys.io.Process;
import haxe.io.Input;
import openfl.geom.Rectangle;
import sys.FileSystem;
import openfl.utils.ByteArray;
import StringTools;
import openfl.geom.Point;
import openfl.net.URLRequest;
import sys.io.FileInput;
import sys.io.File;
import openfl.net.URLRequest;
import openfl.display.Loader;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.Assets;
import haxe.io.Path;
import openfl.display.Sprite;
import openfl.events.Event;
import neko.Lib;

class Main extends Sprite {

	var mImageToResize : Array<BitmapData>;
	var mImageToLoad : Int = 0;
	var mLoaders : Array<{loader : Loader, url : String}>;
	var mSizes : Array<Point>;
	var mBaseSize : Point;
	var mName : String;
	var mDest : String;
	var mIphoneRes : Array<String> = ["640x960","640x1136","750x1334","1242x2208","1536x2048"];
	var mIosMode : Bool;
	var mLandScape : Bool;

	static inline var ITUNES_FOLDER = "itunes_ScreenShots";
	static inline var iTMSTransporter = "/Applications/Xcode.app/Contents/Applications/Application Loader.app/Contents/MacOS/itms/bin/iTMSTransporter";

	var mBackgroundColor : Int = 0x000000;

	public function new () {

		super ();

		mImageToResize = new Array<BitmapData>();
		mLoaders = new Array<{loader : Loader, url : String}>();
		mSizes = new Array<Point>();

		var args : Array<String> = Sys.args();

		if(args.length < 4){
			Lib.println("Not enough arguments : you need a source folder, a prefix, a resolution and et destination folder.");
			return;
		}

		var sourcePath : String = Path.removeTrailingSlashes(args[0]);
		mName = args[1];
		var resolutionParam : String = args[2];
		mDest = Path.removeTrailingSlashes(args[3])+"/";

		if(args[4] != null){
			mBaseSize = new Point();
			var a = args[4].split("x");
			mBaseSize.x = Std.parseInt(a[0]);
			mBaseSize.y = Std.parseInt(a[1]);
		}

		if(args.length > 4)
			mBackgroundColor = Std.parseInt(args[5]);

		if(args.length > 5)
			if(args[6] == "landscape")
				mLandScape = true;

		var files : Array<String> = sys.FileSystem.readDirectory(sourcePath);

		for(file in files){
			var filePath = sourcePath + "/" + file;
			var ext : String = Path.extension(filePath);

			if(ext != 'jpg' && ext != "jpeg" && ext != "png")
				continue;

			mImageToLoad++;

			var loader = new Loader();
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onComplete);
			mLoaders.push({loader : loader, url : filePath});
		}

		Lib.println("Loading images...");

		var sizes : Array<String>;

		if(resolutionParam == "iphone"){
			sizes = mIphoneRes;
			mIosMode = true;
		}
		else
			sizes = resolutionParam.split(",");
		for(size in sizes){
			var dim : Array<String> = size.split("x");
			mSizes.push(new Point(Std.parseInt(dim[0]), Std.parseInt(dim[1])));
		}

		for(loader in mLoaders)
			loader.loader.load(new URLRequest(loader.url));

	}

	function onComplete(e : Event){
		var data : BitmapData = e.target.content.bitmapData;
		mImageToResize.push(data);
		mImageToLoad--;

		if(mImageToLoad == 0){
			resizeAll();
			onResizeEnd();
		}
	}

	function onResizeEnd(){
		if(mIosMode){
			Sys.println("Resizing ended. Upload to iTunes ? o/n");
			var rep : Int = Sys.getChar(false);
			if(rep == 111)
				iTuneUpload();
			else
				Sys.exit(0);
		}else
			Sys.exit(0);
	}

	function resizeAll(){
		Lib.println("resizing...");

		for(size in mSizes){
			var suffix : Int = 0;
			createSizeFolder(size);
			for(bitmap in mImageToResize){
				resize(bitmap, size, suffix);
				suffix++;
			}
		}
	}

	function createSizeFolder(size : Point){
		if(!mIosMode)
			FileSystem.createDirectory(mDest+"/"+size.x+"x"+size.y);
		else
			FileSystem.createDirectory(mDest+"/"+ITUNES_FOLDER);
	}

	function resize(data : BitmapData, size : Point, suffix : Int){

		var resized : BitmapData;
		if(!mLandScape)
			resized = new BitmapData(Std.int(size.x), Std.int(size.y),false,mBackgroundColor);
		else
			resized = new BitmapData(Std.int(size.y), Std.int(size.x),false,mBackgroundColor);

		var clipRect : Rectangle = new Rectangle(0,0,data.width,data.height);

		if(mBaseSize != null)
		{
			clipRect.width = mBaseSize.x;
			clipRect.height = mBaseSize.y;

			var tempScaleX = data.width / clipRect.width;
			var tempScaleY = tempScaleX;

			if(tempScaleY * clipRect.height >= data.height){
				tempScaleY = data.height / clipRect.height;
				tempScaleX = tempScaleY;
			}

			clipRect.width = clipRect.width * tempScaleX;
			clipRect.height = clipRect.height * tempScaleY;

			clipRect.x = (data.width - clipRect.width) / 2;
			clipRect.y = (data.height - clipRect.height) / 2;
		}

		var stamp = new BitmapData(cast clipRect.width,cast clipRect.height);
		stamp.copyPixels(data, clipRect, new Point(0,0));

		// compute matrice
		var scaleX = resized.width / clipRect.width;
		var scaleY = scaleX;

		if(clipRect.height * scaleY > resized.height){
			scaleY = resized.height / clipRect.height;
			scaleX = scaleY;
		}

		var mat = new openfl.geom.Matrix();
		mat.scale(scaleX, scaleY);

		var tX = (resized.width - stamp.width * scaleX) / 2;
		var tY = (resized.height - stamp.height * scaleY) / 2;

		mat.translate(tX, tY);

		resized.draw(stamp, mat);

		// write file
		var byte : ByteArray = resized.encode("jpg");

		var outputPath : String = makeFilePath(size, suffix); // mDest+"/"+size.x+"x"+size.y+"/"+mName+"_"+suffix+".jpg";

		var output = File.write(outputPath, true);
		output.write(byte);
		output.close();
	}

	function makeFilePath(size : Point, suffix : Int) : String
	{
		if(mIosMode){

			var screenSizeName : String = "none";

			if(size.x == 640 && size.y == 960)
				screenSizeName = "iOS-3.5-in";
			else if(size.x == 640 && size.y == 1136)
				screenSizeName = "iOS-4-in";
			else if(size.x == 750 && size.y == 1334)
				screenSizeName = "iOS-4.7-in";
			else if(size.x == 1242 && size.y == 2208)
				screenSizeName = "iOS-5.5-in";
			else if(size.x == 1536 && size.y == 2048)
				screenSizeName = "iOS-iPad";

			return mDest+"/"+ITUNES_FOLDER+"/"+mName + "_"+screenSizeName+"_"+suffix+".jpg";

		}else{
			return mDest+"/"+size.x+"x"+size.y+"/"+mName+"_"+suffix+".jpg";
		}
	}

	function iTuneUpload(){

		var screensPath = mDest + "/" + ITUNES_FOLDER;

		Sys.print("User account : ");
		var userName : String = Sys.stdin().readLine();
		Sys.print("password : ");
		var passWord : String = Sys.stdin().readLine();
		Sys.print("App SKU : ");
		var vendorId = Sys.stdin().readLine();

		Sys.println("Downloading metadata...");

		var process : Process = new Process(iTMSTransporter, ["-m","lookupMetadata","-u",userName,"-p",passWord,"-vendor_id",vendorId,"-destination",screensPath]);
		var error = process.exitCode();

		if(error != 0){
			Sys.println("error : \n" + process.stderr.readAll().toString());
			Sys.exit(1);
			process.close();
		}
		else{
			process.close();
			Sys.println("Moving screenShot in package...");

			var screenList = FileSystem.readDirectory(screensPath);

			var indexPackage = screenList.indexOf(vendorId+".itmsp");
			screenList.remove(screenList[indexPackage]);

			var elemToRemove : Array<String> = new Array<String>();

			for(screen in screenList){
				if(Path.extension(screen) != "jpg"){
					elemToRemove.push(screen);
					continue;
				}

				Sys.println("Moving " + screen + " in " + vendorId+".itmsp");
				var mvProc = new Process("mv", [screensPath+"/"+screen, screensPath+"/"+vendorId+".itmsp"]);
				var error : Int = mvProc.exitCode();

				if(error != 0){
					Sys.println("error : " + mvProc.stderr.readAll().toString());
					elemToRemove.push(screen);
				}

			}

			for(elem in elemToRemove){
				var index = screenList.indexOf(elem);
				screenList.remove(screenList[index]);
			}

			updateMetadata(screensPath + "/" + vendorId+".itmsp", screenList);

			Sys.println("Metadata updated");

			verifyPackage(screensPath + "/" + vendorId+".itmsp", userName, passWord);

			uploadPackage(screensPath + "/" + vendorId+".itmsp", userName, passWord);

			Sys.exit(0);
		}

	}

	function verifyPackage(packagePath : String, userName : String, passWord : String){
		Sys.println("Verifying package...");

		var exitCode = Sys.command(iTMSTransporter, ["-m", "verify", "-u", userName, "-p", passWord, "-f", packagePath]);

		if(exitCode!= 0){
			Sys.println("Error while verifying... exit...");
			Sys.exit(exitCode);
		}

		Sys.println("Success!");
	}

	function uploadPackage(packagePath : String, userName : String, passWord : String){
		Sys.println("Uploading package...");

		var exitCode = Sys.command(iTMSTransporter, ["-m", "upload", "-u", userName, "-p", passWord, "-f", packagePath]);

		if(exitCode!= 0){
			Sys.println("Error while uploading... exit...");
			Sys.exit(exitCode);
		}

		Sys.println("Success!");
	}

	function updateMetadata(packagePath : String, screenList : Array<String>){

		Sys.println("Version to update : ");
		var versionToUpdate : String = Sys.stdin().readLine();

		var xmlPath : String = packagePath + "/" + "metadata.xml";
		var xmlContent : String = File.getContent(xmlPath);
		var xml = Xml.parse(xmlContent);

		var metadata : Fast = new Fast(xml.firstElement());

		// get locales
		var versions : List<Fast> = metadata.node.software.node.software_metadata.node.versions.nodes.version;
		var updatedVersion : Fast = null;
		for (version in versions){
			var currentVersion : String = version.att.string;
			if(currentVersion == versionToUpdate){
				updatedVersion = version;
				break;
			}
		}

		var locales : List<Fast> = updatedVersion.node.locales.nodes.locale;

		for(locale in locales)
			updateLocale(locale, packagePath, screenList);

		var output = File.write(xmlPath, false);
		output.writeString(metadata.x.toString());
		output.close();
	}

	function updateLocale(locale : Fast, packagePath : String, screenList : Array<String>){
		if(locale.hasNode.software_screenshots)
			locale.x.removeChild(locale.node.software_screenshots.x);

		var screenShotsXml : Xml = Xml.createElement("software_screenshots");

		for(screen in screenList){
			var screenXml : Xml = Xml.createElement("software_screenshot");
			var screenPart = screen.split("_");
			var display_target = screenPart[1];
			var position = screenPart[2].charAt(0);
			screenXml.set("display_target", display_target);
			screenXml.set("position", position);
			var fileNameXml = Xml.parse("<file_name>"+screen+"</file_name>");

			var fileSize = FileSystem.stat(packagePath+"/"+screen).size;
			var fileByte = File.getBytes(packagePath+"/"+screen);
			var checkSum = haxe.crypto.Md5.encode(fileByte.toString());

			var sizeXml = Xml.parse("<size>"+fileSize+"</size>");
			var checksumXml = Xml.parse("<checksum>"+checkSum+"</checksum>");

			screenXml.addChild(fileNameXml);
			screenXml.addChild(sizeXml);
			screenXml.addChild(checksumXml);

			screenShotsXml.addChild(screenXml);
		}

		locale.x.addChild(screenShotsXml);
	}
	
}