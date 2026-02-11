//**************************************************************************************
// Copyright (C) 2024 Mary E. Cole / CFO Tool
// First Release Date: September 2024
//**************************************************************************************


requires("1.53g");

var filemenu = newMenu("CFO Tool Menu Tool", newArray("WMGL", "-", "About"));

//macro "CFO Menu Tool - C000D14D23D32D51D5bD7cC000D5eD79D99DbcDc7Dc8C000D37D4aD68D89Da1Dc9DebC000D67DabDcaDe6C000D71DbeC000D66D81D95C000D1aD4bDc6DcdC000Da7C000D3cD61C000D36Dc3Dd4C000DeaC000D4dC000D6cDa8C111Db2C111D91DcbDe9C111D4cC111D15DbaC111D42De7C111D6eDe8C111D2bC111DccC111D3aC111D82DbdC111D8dC111DdcC111D65Da6Dd6C111D35C222D19DaeC222D5cD6bD9dC222Dd5C222DadC222D9bDb4C222D69D74D84Db5C222D9eC222D49Dd8C333D8eC333Dd9C333D16C333D9aC333D33C333D24C333Dd7C333D72C333D44C333D5aC333D18D62D7eDa9C444D52C444D17C444Dc5C444D29D8aC444D8bC444D2aC444DaaC444Da5Db6C444Dc4C444D7bC444Db9C555D28D3bC555D92Db7DdaC555D27C555D53Db3C555D5dDdbC555D34C555D43D83Da2C555Db8C555C666D57C666D58D7dC666D7aC666D45C666D48C666D26C777D56C777D94Da4C777C888Da3C888D93C888D25C888D6aD6dC999D64C999D47C999D46C999D59C999D63C999CaaaD55CaaaD73CaaaCbbbD54"{

macro "CFO Tool Menu Tool - C000C111C222C333C444Dd4C444D7eC444C555D47C555D15C555D46C555C666D48C666D8bC666D45D72DaaC666D6aC666D59C666D19D7bDb2De6C666D3cC666D4dDe5C666D2bD6eDa3Db9C777D16C777D54C777D5aD93C777D5dC777D91C777D23C777D44D63C777D9eC777D62Da1De7C777D18C777Dd5C777D17C777D49Dc3C888D8eC888D53C888D9bC888D42C888Da2DaeC888D24D55C888DbeC888Db5C888C999DbaC999D8aDe8C999D14D6bD81C999D51C999D58D7aDdcC999Db6C999D1aC999DeaC999D61C999D37C999D32C999Da4Db8C999DcdC999D36Db4DebCaaaDc8CaaaD33D57CaaaD52CaaaD71D9aCaaaD35De9CaaaDc4CaaaD56Da9CaaaD43D83DabCaaaD82CaaaDb7Dc9CaaaD92CbbbD5eDacCbbbDbbCbbbD73CbbbD64D8fDb3CbbbD80Dc7CbbbD4cCbbbD9cCbbbD6dCbbbDa5CbbbCcccD2aCcccD07D3bD8cCcccD9fDddCcccDdbCcccDceCcccD34CcccDcaCcccD08D90De4CcccD38D69CcccDc6CdddD06CdddDd3CdddDecCdddD41Dd6CdddDc2CdddDbdDf6CdddD2cCdddD3dCdddD7fDbcCdddD60CdddD70D94DadDc5CdddDb1CdddD25CeeeD7dCeeeD4aCeeeDa6CeeeD65CeeeD09D1bDafCeeeD05D27CeeeD68CeeeD9dDccDd7CeeeD5bD7cDf5Df7CeeeD26D99DdaCeeeDd8CeeeD22D79CeeeCfffD29CfffD13D4eD8dCfffDcbDf8CfffD95Da8CfffDd9CfffD39D5cD89Da0CfffD84Da7CfffD28Df9CfffD50D74DbfCfffD3aCfffD0aD6fCfffD31D4bD6cDdeDedDfaCfffD04D66De3CfffD2dD67Dc1"{

//Call user-selected function 

		CFOmacro = getArgument();
		if (CFOmacro!="-") {
			if (CFOmacro=="WMGL") { WMGL(); }
			else if (CFOmacro=="About") { About(); }
		}
	}
	
	function WMGL() {

//this code will make a ROI manager appear in batchmode, which seems necessary for some code
//roiManager("show none");
setBatchMode(true);

//Check for BoneJ Slice Geometry Installation 

List.setCommands;
    
if (List.get("Slice Geometry")=="") {
    Dialog.createNonBlocking("BoneJ Slice Geometry Not Detected");
    Dialog.addMessage("Use Help --> Update --> Manage Update Sites --> BoneJ --> Apply and Close --> Apply Changes");
    Dialog.addMessage("Then restart ImageJ and retry");
	Dialog.show();
	exit("BoneJ Installation Required");
	}

//Set measurements for area and circularity (for rib regions)
run("Set Measurements...", "area shape redirect=None decimal=9");

//Required to scale the RGB values when converting to 8-bit
run("Conversions...", "scale weighted");

//**Loading Dialog****************************************************************************************************************

//Variable placeholders

var CPOpath = "";
var scale_num = call("ij.Prefs.get", "scale.number", "");
var unit_opts = newArray("mm",fromCharCode(956) + "m");
var unit_opts_choice = call("ij.Prefs.get", "unit_opts_choice.string", "mm");
var borderpath = "";
var porechoice_none = call("ij.Prefs.get", "porechoice_none.boolean", true);
var porechoice_range = call("ij.Prefs.get", "porechoice_range.boolean", false);
var porechoice_range_start = call("ij.Prefs.get", "porechoice_range_start.number", "0");
var porechoice_range_end = call("ij.Prefs.get", "porechoice_range_end.number", "28");
var porechoice_roi = call("ij.Prefs.get", "porechoice_roi.boolean", false);
var porepath = "";
var regionopts = newArray("Do Not Subdivide Regions","Create New Regions From Border","Load Folder of Region .roi Files");
var regionchoice = call("ij.Prefs.get", "regionchoice.string", "Do Not Subdivide Regions");
var regiondir = "";
var mapchoice = call("ij.Prefs.get", "mapchoice.boolean", true);

//Placeholders to warn if values not entered correctly
var CPOrepeat = "N";
var CPOerror= "";
var borderrepeat = "N";
var bordererror= "";
var porerepeat_none = "N";
var poreerror_none = "";
var porerepeat_range = "N";
var poreerror_range = "";
var porerepeat_roi = "N";
var poreerror_roi = "";
var regionrepeat = "N";
var regionerror = "";
var lutrepeat = "N";
var luterror = "";

//lutdirname="luts";
//lutdir=getDirectory("startup")+lutdirname+File.separator;
var lutlist = getList("LUTs");
var lutlist_choice = call("ij.Prefs.get", "lutlist_choice.string", "CFO");
var binchoice = call("ij.Prefs.get", "binchoice.boolean", false);
var lutbins = call("ij.Prefs.get", "lutbins.number", "9");

//Loop dialog until everything correctly entered

do{

//Display Dialog

Dialog.createNonBlocking("Weighted Mean Gray Level Setup");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Load Circularly Polarized (CPO) Image",14,"#00008B");

//Load CPO Image
if (CPOrepeat == "Y"){
	Dialog.setInsets(0,0,0);
	Dialog.addMessage(CPOerror,14,"#7f0000");
	}
Dialog.setInsets(1,0,0);
Dialog.addFile("CPO Image", CPOpath);

//Set scale for scalebar generation
Dialog.addNumber("CPO Image Scale",scale_num);
Dialog.addToSameRow();
Dialog.addChoice("pixels per", unit_opts, unit_opts_choice);

//Load cortical border ROIs
Dialog.setInsets(0,0,0)
Dialog.addMessage("Load Border ROI (.roi) or Border Set (.zip)",14,"#00008B");
Dialog.setInsets(1,0,0);
if (borderrepeat == "Y"){
	Dialog.setInsets(0,0,0);
	Dialog.addMessage(bordererror,14,"#7f0000");
	}
Dialog.addFile("Border File", borderpath);

//Load pore ROIs
Dialog.setInsets(5,0,0)
Dialog.addMessage("Choose Pore Removal Method(s)",14,"#00008B");
if (porerepeat_none == "Y"){
	Dialog.setInsets(0,0,0);
	Dialog.addMessage(poreerror_none,14,"#7f0000");
	}
Dialog.setInsets(0,10,0);
Dialog.addCheckbox("No Pore Removal",porechoice_none);
Dialog.setInsets(0,10,0);
if (porerepeat_range == "Y"){
	Dialog.setInsets(0,0,0);
	Dialog.addMessage(poreerror_range,14,"#7f0000");
	}
Dialog.addCheckbox("Exclude Dark Pixels",porechoice_range);
Dialog.setInsets(0,0,0);
Dialog.addNumber("Exclude Start",porechoice_range_start);
Dialog.addNumber("Exclude End",porechoice_range_end);
if (porerepeat_roi == "Y"){
	Dialog.setInsets(0,0,0);
	Dialog.addMessage(poreerror_roi,14,"#7f0000");
	}
Dialog.setInsets(0,10,0);
Dialog.addCheckbox("Load Pore ROI File (.zip)",porechoice_roi);
Dialog.setInsets(0,0,0);
Dialog.addFile("Pore ROI File", porepath);

//Load region ROIs
Dialog.setInsets(5,0,0)
Dialog.addMessage("Choose Regional Subdivision",14,"#00008B");
if (regionrepeat == "Y"){
	Dialog.setInsets(0,0,0);
	Dialog.addMessage(regionerror,14,"#7f0000");
	}
Dialog.setInsets(0,10,0);
Dialog.addRadioButtonGroup("", regionopts, 3, 1, regionchoice);
Dialog.setInsets(0,0,0);
Dialog.addDirectory("Region Folder", regiondir);

//Option to generate colormap
Dialog.setInsets(5,0,0)
Dialog.addMessage("Generate Colormap of CPO Brightness",14,"#00008B");
Dialog.setInsets(0,10,0);
Dialog.addCheckbox("Generate Colormap?",mapchoice);
Dialog.addToSameRow();
Dialog.addChoice("Lookup Table",lutlist,lutlist_choice);
if (lutrepeat == "Y"){
	Dialog.setInsets(0,0,0);
	Dialog.addMessage(luterror,14,"#7f0000");
	}
Dialog.setInsets(0,10,0);
Dialog.addCheckbox("Modify Number of Colors?",binchoice);
Dialog.addToSameRow();
Dialog.addNumber("Colors",lutbins);
Dialog.setInsets(10,0,0)
Dialog.addMessage("Warning: Any current images or windows will be closed!",16,"#7f0000");


Dialog.show();

//Get values from dialog

CPOpath = Dialog.getString();

scale_num = Dialog.getNumber();
call("ij.Prefs.set", "scale.number", scale_num);

unit_opts_choice = Dialog.getChoice();
call("ij.Prefs.set", "unit_opts_choice.string",unit_opts_choice);

if(unit_opts_choice == "mm"){scale = scale_num;}
if(unit_opts_choice != "mm"){scale = scale_num/1000;}

borderpath = Dialog.getString();;

porechoice_none = Dialog.getCheckbox();
call("ij.Prefs.set", "porechoice_none.boolean", porechoice_none);

porechoice_range = Dialog.getCheckbox();;
call("ij.Prefs.set", "porechoice_range.boolean", porechoice_range);

porechoice_range_start = Dialog.getNumber();;; 
call("ij.Prefs.set", "porechoice_range_start.number", porechoice_range_start);

porechoice_range_end = Dialog.getNumber();; 
call("ij.Prefs.set", "porechoice_range_end.number", porechoice_range_end);

porechoice_roi = Dialog.getCheckbox();;;
call("ij.Prefs.set", "porechoice_roi.boolean", porechoice_roi);

porepath = Dialog.getString();;;

regionchoice = Dialog.getRadioButton();
call("ij.Prefs.set", "regionchoice.string", regionchoice);

regiondir = Dialog.getString();;;;

mapchoice = Dialog.getCheckbox();;;;
call("ij.Prefs.set", "mapchoice.boolean", mapchoice);

lutlist_choice = Dialog.getChoice();
call("ij.Prefs.set", "lutlist_choice.string", lutlist_choice);

binchoice = Dialog.getCheckbox();;;;;
call("ij.Prefs.set", "binchoice.boolean", binchoice);

lutbins = Dialog.getNumber();;;;
call("ij.Prefs.set", "lutbins.number", lutbins);


//print(CPOpath);
//print(scale);
//print(scale_um);
//print(borderpath);
//print(porechoice_none);
//print(porechoice_range);
//print(porechoice_range_start);
//print(porechoice_range_end);
//print(porechoice_roi);
//print(porepath);
//print(regionchoice);
//print(regionpath);
//print(mapchoice);
//print(lutlist_choice);
//print(lutbins);
//print(binchoice);

//Check if CPO entered
if(CPOpath == ""){
	CPOerror = "Missing file path:";
	CPOrepeat = "Y";
	}
	
//Check if CPO is an image format
if(!(CPOpath == "")){
	//Get image file name
	CPOimg = File.getName(CPOpath);
	//Repeat if not image format
	if (!endsWith(CPOimg, "tiff") && !endsWith(CPOimg, "tif") && !endsWith(CPOimg, "bmp") && !endsWith(CPOimg, "jpg") && !endsWith(CPOimg, "png")){
	CPOerror = "Image file must be TIFF, BMP, JPG, or PNG:";
	CPOrepeat = "Y";
	}
	//Approve file path with image format
	if (endsWith(CPOimg, "tiff") || endsWith(CPOimg, "tif") || endsWith(CPOimg, "bmp") || endsWith(CPOimg, "jpg") || endsWith(CPOimg, "png")){
	CPOerror = "";
	CPOrepeat = "N";
	}
}

//Check if border path entered
if(borderpath == ""){
	bordererror = "Missing file path:";
	borderrepeat = "Y";
	}
	
//Check if border is not an ROI zip
if(!(borderpath == "")){
	//Repeat if not .zip
	if (!endsWith(borderpath, "zip") && !endsWith(borderpath, "roi")){
	bordererror = "Border file must be .roi or .zip:";
	borderrepeat = "Y";
	}
	//Approve file path with .zip format
	if (endsWith(borderpath, "zip") || endsWith(borderpath, "roi")){
	bordererror = ""; 
	borderrepeat = "N";
	}
}

//Make sure at least one pore option selected 
if(porechoice_none == true || porechoice_range == true || porechoice_roi == true){
	poreerror_none = "";
	porerepeat_none = "N";
}
if(porechoice_none == false && porechoice_range == false && porechoice_roi == false){
	poreerror_none = "Select a pore removal option:";
	porerepeat_none = "Y";
}

//Pore range: Check if numbers are correct
if(porechoice_range == false){
	poreerror_range = "";
	porerepeat_range = "N";
}
if(porechoice_range == true && porechoice_range_end < porechoice_range_start){
	poreerror_range = "Range start cannot exceed range end:";
	porerepeat_range = "Y";
	}
if(porechoice_range == true && porechoice_range_end > 254){
	poreerror_range = "Excluded range must be between 0 and 254:";
	porerepeat_range = "Y";
	}
if(porechoice_range == true && porechoice_range_end > porechoice_range_start && porechoice_range_end < 255){
		poreerror_range = "";
		porerepeat_range = "N";
}

//Pore ROI: Check if pore path entered
if(porechoice_roi == false){
	poreerror_roi = "";
	porerepeat_roi = "N";
}
if(porechoice_roi == true && porepath == ""){
	poreerror_roi = "Missing file path:";
	porerepeat_roi = "Y";
	}
	
//Check if pore set is not an ROI zip
if(porechoice_roi == true && !(porepath == "")){
	//Repeat if not .zip
	if (!endsWith(porepath, "zip")){
	poreerror_roi = "File must be ROI zip:";
	porerepeat_roi = "Y";
	}
	//Approve file path with .zip format
	if (endsWith(porepath, "zip")){
	poreerror_roi = "";
	porerepeat_roi = "N";
	}
}

//Check if region path entered
if(regionchoice != "Load Folder of Region .roi Files"){
	regionerror = "";
	regionrepeat = "N";
}
if(regionchoice == "Load Folder of Region .roi Files" && regiondir == ""){
	regionerror = "Missing folder path:";
	regionrepeat = "Y";
	}

//Check if folder contains .roi files
if(regionchoice == "Load Folder of Region .roi Files" && !(regiondir == "")){
	
	//Get region list from folder

	regionpath=getFileList(regiondir); 

	//Delete all except .roi files

	for (i=regionpath.length-1; i>=0; i--) {
		if (!endsWith(regionpath[i], "roi")){
		regionpath = Array.deleteIndex(regionpath, i);
	}}

	//Repeat if no .roi files
	if (regionpath.length == 0){
	regionerror = "Folder must contain .roi file(s):";
	regionrepeat = "Y";
	}
	//Approve if .roi file(s)
	if (regionpath.length != 0){
	regionerror = "";
	regionrepeat = "N";
	}
}

//Check if color map entered
if(mapchoice == false){   
	luterror = "";
	lutrepeat = "N";
}
if(mapchoice == true && binchoice == true && (lutbins < 2 || lutbins > 256)){
	luterror = "Select between 2 and 256 bins for lookup table:";
	lutrepeat = "Y";
	}
if(mapchoice == true && binchoice == true && lutbins > 1 && lutbins < 257){
	luterror = "";
	lutrepeat = "N";
	}
	
//Process macro if all checks passed

}while(CPOrepeat == "Y" ||
borderrepeat == "Y" ||
porerepeat_none == "Y" ||
porerepeat_range == "Y" ||
porerepeat_roi == "Y" ||
regionrepeat == "Y" ||
lutrepeat == "Y");

//**Setup macro to run****************************************************************************************************************

//Close existing images and windows

while (nImages>0) { 
selectImage(nImages); 
close(); 
      }

openwindows = getList("window.titles"); 
     for (i=0; i<lengthOf(openwindows); i++){ 
     window = openwindows[i]; 
     	selectWindow(window); 
     run("Close"); 
     } 

//Clear any current results 

run("Clear Results");

//Output location: Same as the CPO image 

dir = File.getParent(CPOpath);
call("ij.Prefs.set", "appendimage.dir", dir);


//**Check Cortical Borders****************************************************************************************************************

showStatus("!Loading Image and Border...");

//Open the CPO image

open(CPOpath); 

origimg=getTitle();
origname = File.nameWithoutExtension;

//Create region for CFO Outputs 

cfodir=dir+"/"+origname+" WMGL Results/";
File.makeDirectory(cfodir); 

//Remove scale 

selectImage(origimg);
run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

//Clear overlays

selectImage(origimg);
run("Select None");
run("Remove Overlay");

//Reset colors to normal 

run("Colors...", "foreground=white background=black");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Select cortical border if ROI set-----------------------------------------

if (endsWith(borderpath, "zip")){

var bordername = call("ij.Prefs.get", "bordername.string", "CtAr");

roiManager("Open", borderpath); 

borderlist = newArray();

for (i=0; i < roiManager("count"); i++) {
	borderlist = Array.concat(borderlist,RoiManager.getName(i));
}

Dialog.createNonBlocking("Border Set Loaded");
Dialog.addChoice("Select Border from Set:", borderlist, bordername);
Dialog.show();

bordername = Dialog.getChoice();
call("ij.Prefs.set", "bordername.string",bordername);

borderindex = RoiManager.getIndex(bordername);

}

//Select cortical border if ROI file-----------------------------------------

if (endsWith(borderpath, "roi")){

roiManager("Open", borderpath);

bordername = RoiManager.getName(0);
borderindex = RoiManager.getIndex(bordername);

}

//Border ROI set remains open to generate cortical borders OR to skip past regional division

//**Make grayscale version for colormap and running LUTS for region folder display********************************************************

//Convert image to 8-bit grayscale 

showStatus("!Creating Grayscale Image...");

selectImage(origimg);
run("Select None");
run("Remove Overlay");

//Make grayscale version
selectImage(origimg);
run("Duplicate...", " ");
origimg_gray=getTitle();
rename("Grayscale");
origimg_gray=getTitle();

selectImage(origimg_gray);
roiManager("Select",borderindex);
setBackgroundColor(0, 0, 0);
run("Clear Outside");

//Clear overlays

selectImage(origimg_gray);
run("Select None");
run("Remove Overlay");

//Confirm 8-bit
selectImage(origimg_gray);
run("8-bit");


//Generate white pore image from ROIs****************************************************************************************************************

if(porechoice_roi == true){
	
showStatus("!Creating Pore Mask...");
	
//Clear ROI manager to prepare for pore removal

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}
	
//Duplicate image

selectImage(origimg);
run("Select None");
run("Remove Overlay");

selectImage(origimg);
run("Duplicate...", " ");

origimg_pores_temp=getTitle();
	
//Open the pore ROIs on the duplicated image

selectImage(origimg_pores_temp);
run("Select None");
run("Remove Overlay");

roiManager("Open", porepath); 

//Change pore color to black, fill, and flatten

roiManager("Deselect");
RoiManager.setGroup(0);
RoiManager.setPosition(0);
roiManager("Set Color", "black");
roiManager("Set Line Width", 0);
roiManager("Set Fill Color", "black");

selectImage(origimg_pores_temp);
roiManager("Show All without Labels");
run("Flatten");

//Need to rename so this new image isn't closed
origimg_pores=getTitle();
rename("Black Pores");
origimg_pores=getTitle();

//Close non-flattened image

selectImage(origimg_pores_temp);
close();

//Duplicate image to create blank

selectImage(origimg); 
run("Duplicate...", " ");
pores_temp=getTitle();

//Clear blank duplicate 

selectImage(pores_temp);
run("Select All");
setBackgroundColor(0, 0, 0);
run("Clear", "slice");
run("Clear Outside", "slice");
run("Select None");
run("Remove Overlay");

//Change pore color to white, fill, and flatten

roiManager("Deselect");
RoiManager.setGroup(0);
RoiManager.setPosition(0);
roiManager("Set Color", "white");
roiManager("Set Line Width", 0);
roiManager("Set Fill Color", "white");

selectImage(pores_temp);
roiManager("Show All without Labels");
run("Flatten");

pores=getTitle();
rename("White Pores");
pores=getTitle();

//Convert to 8-bit

selectImage(pores);
run("Select None");
run("Remove Overlay");
run("8-bit");

//Close non-flattened image

selectImage(pores_temp);
close();

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Re-load borders 

roiManager("Open", borderpath); 
borderindex = RoiManager.getIndex(bordername);

//End pore removal
}


//**Create Region Borders****************************************************************************************************************

if (regionchoice == "Create New Regions From Border"){

showStatus("!Creating New Regions From Border...");

//User chooses rib or long bone 

var bonetype = call("ij.Prefs.get", "bonetype.string", "Long Bone");
var tilt = call("ij.Prefs.get", "tilt.string", "Section Alignment With Image Borders");

Dialog.createNonBlocking("Create New Regions From Border");

Dialog.setInsets(0, 35, 0)
Dialog.addMessage("Select Cross-Section Type:", 14,"#00008B");
Dialog.setInsets(0, 0, 0)
Dialog.addRadioButtonGroup("", newArray("Rib","Long Bone"), 2, 1, bonetype);

Dialog.setInsets(0, 25, 0)
Dialog.addMessage("Draw Long Bone Quadrants Using:",12,"#00008B");
Dialog.setInsets(0, 15, 0)
Dialog.addRadioButtonGroup("", newArray("Section Alignment With Image Borders","Section Major Axis"), 2, 1, tilt);

Dialog.show();

bonetype = Dialog.getRadioButton();
call("ij.Prefs.set", "bonetype.string", bonetype);

tilt = Dialog.getRadioButton();;
call("ij.Prefs.set", "tilt.string", tilt);

//Create cortical mask******************************************

selectImage(origimg);
run("Select None");
run("Remove Overlay");

//Make binary filled cortical mask 
selectImage(origimg);
run("Duplicate...", " ");
cortical=getTitle();
run("8-bit");

selectImage(cortical);
roiManager("Select",borderindex);
setBackgroundColor(0, 0, 0);
run("Clear Outside");
roiManager("Select",borderindex);
roiManager("Fill");

selectImage(cortical);
run("8-bit");

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Clear results

run("Clear Results");

//Regional subdivision for long bones******************************************

if (bonetype == "Long Bone"){

//Set scale for cross-sectional geometry according to user input in mm

run("Set Scale...", "distance=scale known=1 pixel=1 unit=mm global");

//Run BoneJ Slice Geometry 

selectImage(cortical);
run("Select None");
run("Remove Overlay");

selectImage(cortical);
run("Slice Geometry", "bone=unknown bone_min=1 bone_max=255 slope=0.0000 y_intercept=0");

//Hide results window 
selectWindow("Results");
setLocation(screenWidth, screenHeight);

selectImage(cortical);
getPixelSize(unit, pw, ph);

//Get row numbers of columns

selectWindow("Results");
text = getInfo();
lines = split(text, "\n");
columns = split(lines[0], "\t");

if (columns[0]==" ")
 {columns[0]= "Number";}

//Pull variables from BoneJ results table and divide by pixel size to obtain pixel coordinates

 cX= getResult(columns[5],0)/pw;
 cY = getResult(columns[6],0)/pw;

 th = abs(getResult(columns[10],0));
 rMin = getResult(columns[11],0)/pw;
 rMax = getResult(columns[12],0)/pw;
 thPi = th + PI / 2;

 //Loop to define tilt value for major axis quadrant subdivision 

if (tilt == "Section Major Axis"){

//Define major axis - this will be vertical for a long image, and horizontal for a short image

Majorx1 = floor(cX - cos(-th) * 2 * rMax);
Majory1 = floor(cY + sin(-th) * 2 * rMax);
Majorx2 = floor(cX + cos(-th) * 2 * rMax);
Majory2 = floor(cY - sin(-th) * 2 * rMax);

//Slope of line 

Major_m = (Majory1 - Majory2)/(Majorx1 - Majorx2);

//Because the coordinates are inverted (increase from top to bottom of frame), a  negative slope inclines to the right, and a positive slope inclines to the left
//Angle of line compared to vertical axis is tan angle = 1/m for a positive slope and -1/m for a negative slope
//Since a right incline is negative in slope and resulting angle, but rotation is clockwise, get absolute value so that line rotates properly
//Multiply by 180/PI to convert from radians to degrees

Major_angle=abs(atan(1/Major_m) * 180/PI);

//Define minor axis

Minorx1 = floor(cX - cos(thPi) * 2 * rMin);
Minory1 = floor(cY - sin(thPi) * 2 * rMin);
Minorx2 = floor(cX + cos(thPi) * 2 * rMin);
Minory2 = floor(cY + sin(thPi) * 2 * rMin);

//Slope of line 

Minor_m = (Minory1 - Minory2)/(Minorx1 - Minorx2);

//Multiply by 180/PI to convert from radians to degrees

Minor_angle=(atan(1/Minor_m) * 180/PI);

//Detrmine coordinates for quadrant lines

//Get width and height of image 

w = getWidth();
h = getHeight();

//Length of the diagonal via pythagorean theorem 

d = sqrt((h*h) + (w*w));

//Difference between diagonal and height 

hdiff=((d-h)/2);

//Extend 10000 pixels further beyond diagonal

hboost=hdiff+10000;

//Clear slice geometry results as all values have been extracted 

run("Clear Results");

var x1 = "";
var y1 = "";
var x2 = "";
var y2 = "";
var Final_angle = "";

var linestop = "lineredo";

selectImage(origimg);
setBatchMode("show");
run("Select None");
run("Remove Overlay");

do {

//Erase ROIs 

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//For the adjusted centerline, make it the boosted diagonal length so it is sure to go out of frame by 1000 pixels even at the longest (diagonal) rotation

selectImage(origimg);
makeLine(cX, -hboost, cX, (h+hboost),30);

//Rotate line to major axis tilt angle 

run("Rotate...", "  angle=Major_angle");

Roi.setStrokeColor("cyan")
roiManager("Add");
roiManager("Show All without labels");

//Ask user to inspect regional subdivision

Dialog.createNonBlocking("Confirm Longest Axis");
Dialog.setInsets(5, 0, 5)
Dialog.addRadioButtonGroup("Are you satisfied with longest axis?",  newArray("Yes, Proceed", "No, Use Minor Axis"), 2, 1, "Yes, Proceed");

Dialog.show();

lineswap= Dialog.getRadioButton();

//If user chooses to proceed with major axis, exit do while loop

if (lineswap == "Yes, Proceed"){
	Final_angle = Major_angle;
	linestop = "linestop";
	}
else{linestop = "lineredo";}

//Swap names if chosen by user

if (lineswap == "No, Use Minor Axis"){

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//For the adjusted centerline, make it the boosted diagonal length so it is sure to go out of frame by 1000 pixels even at the longest (diagonal) rotation

selectImage(origimg);
makeLine(cX, -hboost, cX, (h+hboost),30);

//Rotate line to minor axis tilt angle 

run("Rotate...", "  angle=Minor_angle");

Roi.setStrokeColor("cyan")
roiManager("Add");
roiManager("Show All without labels");

//Show cortical image 
selectImage(origimg);
setBatchMode("show");

//Ask user to inspect regional subdivision

Dialog.createNonBlocking("Confirm Longest Axis");
Dialog.setInsets(5, 0, 5)
Dialog.addRadioButtonGroup("Are you satisfied with longest axis?",  newArray("Yes, Proceed", "No, Use Major Axis"), 2, 1, "Yes, Proceed");

Dialog.show();

lineswapredo= Dialog.getRadioButton();

//If user chooses to proceed, exit do while loop
//If user chooses to revert to major axis, the loop will repeat

if (lineswapredo == "Yes, Proceed"){
	Final_angle = Minor_angle;
	linestop = "linestop";
	}
else{linestop = "lineredo";}

}

}


while (linestop=="lineredo");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Hide cortical image again

selectImage(origimg);
setBatchMode("hide");

//END get tilt angle from BoneJ section major axis
}
//If get from section borders, no tilt angle
else{
	Final_angle = 0;
	run("Clear Results");
	};

//Then proceed from final angle - re-run extraction in case no tilt was selected

//Detrmine coordinates for quadrant lines

showStatus("!Creating Region Quadrants...");

//Get width and height of image 

selectImage(cortical); 

w = getWidth();
h = getHeight();

//Length of the diagonal via pythagorean theorem 

d = sqrt((h*h) + (w*w));

//Difference between diagonal and height 

hdiff=((d-h)/2);

//Extend 10000 pixels further beyond diagonal

hboost=hdiff+10000;

//For the adjusted centerline, make it the boosted diagonal length so it is sure to go out of frame by 1000 pixels even at the longest (diagonal) rotation

makeLine(cX, -hboost, cX, (h+hboost));

//Rotate line to tilt angle 

run("Rotate...", "  angle=Final_angle");


//Rotate major axis right 45 degrees to top of octant 2

run("Rotate...", "  angle=45");

//Get coordinates for opposing lines 2 and 4

getSelectionCoordinates(x, y);

o2x=x[0];
o2y=y[0];

o4x=x[1];
o4y=y[1];


//Rotate major axis right 90 degrees to top of octant 3

run("Rotate...", "  angle=90");

//Get coordinates for opposing lines 3 and 7

getSelectionCoordinates(x, y);

o3x=x[0];
o3y=y[0];

o1x=x[1];
o1y=y[1];

//Duplicate image for drawing all quadrants on the slice

selectImage(cortical); 
run("Select None");
run("Remove Overlay");
run("Duplicate...", "title=[Drawn]");

drawquad=getImageID();

//Change foreground to black to draw in black 

run("Colors...", "foreground=black background=black selection=cyan");
run("Line Width...", "line=1");

//Drawn octants on duplicate

selectImage(drawquad);
run("Select None");
run("Remove Overlay");

makePolygon(o1x,o1y,o2x,o2y,cX,cY);
run("Draw");
makePolygon(o3x,o3y,o4x,o4y,cX,cY);
run("Draw");
run("Select None");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Add and combine in ROI manager 

makePolygon(o1x,o1y,o2x,o2y,cX,cY);
roiManager("Add");
makePolygon(o3x,o3y,o4x,o4y,cX,cY);
roiManager("Add");

roiManager("Select", newArray(0,1));
roiManager("XOR");
roiManager("Add");
roiManager("Delete");

run("From ROI Manager");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}


//Change foreground back to white 

run("Colors...", "foreground=white background=black selection=cyan");

//Create folder subdivision for regional output 

regiondir=cfodir+"/WMGL Regions/";
File.makeDirectory(regiondir); 

selectImage(drawquad);
saveAs("TIFF", regiondir+origname+"_"+"DrawnQuadrants.tif");

drawquad=getImageID();
selectImage(drawquad);
close();


//Clear outside Octant 1 on CA

selectImage(cortical); 
run("Select None");
run("Remove Overlay");

selectImage(cortical); 
run("Duplicate...", "title=[Quad1]");

quad1=getTitle();

selectImage(quad1); 

makePolygon(o1x,o1y,o2x,o2y,cX,cY);
run("Create Mask");
run("Create Selection");
close();
selectImage(quad1); 
run("Restore Selection");
roiManager("Add");

setBackgroundColor(0, 0, 0);
run("Clear Outside");

setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");

//Quadrant 1 Bounding
//Counts particle(s), if multiple ROIs combines them in a single ROI and deletes individual ROIs

run("Clear Results");

selectImage(quad1); 

run("Analyze Particles...", "display clear add");

var roicount = "";

roicount=roiManager("Count");

//Combine multiple ROIs for fragmented cortex region

if (roicount>1){

roiManager("show all without labels");

roiManager("Combine");

roiManager("Add");

newcount=roiManager("Count")-1;

deleteroi=Array.getSequence(newcount);

roiManager("Select", deleteroi);

roiManager("Delete");

roiManager("Select", 0);
}

//Or select single ROI for non-fragmented cortex region

else
{roiManager("Select", 0);}

run("Clear Results");

//Temporarily save ROI

roiManager("Select", 0);
roiManager("Save", regiondir+"TempQuad1.roi");

//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Close quad 1 image 

selectImage(quad1);
close();

//Clear outside Quadrant 2 on CA

selectImage(cortical); 
run("Select None");
run("Remove Overlay");

selectImage(cortical); 
run("Duplicate...", "title=[Quad2]");

quad2=getTitle();

selectImage(quad2); 

makePolygon(o2x,o2y,o3x,o3y,cX,cY);
run("Create Mask");
run("Create Selection");
close();
selectImage(quad2); 
run("Restore Selection");
roiManager("Add");

setBackgroundColor(0, 0, 0);
run("Clear Outside");

setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");

//Quadrant 2 Bounding
//Counts particle(s), if multiple ROIs combines them in a single ROI and deletes individual ROIs

run("Clear Results");

selectImage(quad2); 

run("Analyze Particles...", "display clear add");

var roicount = "";

roicount=roiManager("Count");

//Combine multiple ROIs for fragmented cortex region

if (roicount>1){

roiManager("show all without labels");

roiManager("Combine");

roiManager("Add");

newcount=roiManager("Count")-1;

deleteroi=Array.getSequence(newcount);

roiManager("Select", deleteroi);

roiManager("Delete");

roiManager("Select", 0);
}

//Or select single ROI for non-fragmented cortex region

else
{roiManager("Select", 0);}

run("Clear Results");

//Temporarily save ROI

roiManager("Select", 0);
roiManager("Save", regiondir+"TempQuad2.roi");


//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Close quad 2 image 

selectImage(quad2);
close();

//Clear outside Quadrant 3 on CA

selectImage(cortical); 
run("Select None");
run("Remove Overlay");

selectImage(cortical); 
run("Duplicate...", "title=[Quad3]");

quad3=getTitle();

selectImage(quad3); 

makePolygon(o3x,o3y,o4x,o4y,cX,cY);
run("Create Mask");
run("Create Selection");
close();
selectImage(quad3); 
run("Restore Selection");
roiManager("Add");

setBackgroundColor(0, 0, 0);
run("Clear Outside");

setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");

//Quadrant 3 Bounding
//Counts particle(s), if multiple ROIs combines them in a single ROI and deletes individual ROIs

run("Clear Results");

selectImage(quad3); 

run("Analyze Particles...", "display clear add");

var roicount = "";

roicount=roiManager("Count");

//Combine multiple ROIs for fragmented cortex region

if (roicount>1){

roiManager("show all without labels");

roiManager("Combine");

roiManager("Add");

newcount=roiManager("Count")-1;

deleteroi=Array.getSequence(newcount);

roiManager("Select", deleteroi);

roiManager("Delete");

roiManager("Select", 0);
}

//Or select single ROI for non-fragmented cortex region

else
{roiManager("Select", 0);}

run("Clear Results");

//Temporarily save ROI

roiManager("Select", 0);
roiManager("Save", regiondir+"TempQuad3.roi");

//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}


//Close quad 3 image 

selectImage(quad3);
close();



//Clear outside Quadrant 4 on CA

selectImage(cortical); 
run("Select None");
run("Remove Overlay");

selectImage(cortical); 
run("Duplicate...", "title=[Quad4]");

quad4=getTitle();

selectImage(quad4); 

makePolygon(o4x,o4y,o1x,o1y,cX,cY);
run("Create Mask");
run("Create Selection");
close();
selectImage(quad4); 
run("Restore Selection");
roiManager("Add");

setBackgroundColor(0, 0, 0);
run("Clear Outside");

setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");

//Quadrant 4 Bounding
//Counts particle(s), if multiple ROIs combines them in a single ROI and deletes individual ROIs

run("Clear Results");

selectImage(quad4); 

run("Analyze Particles...", "display clear add");

var roicount = "";

roicount=roiManager("Count");

//Combine multiple ROIs for fragmented cortex region

if (roicount>1){

roiManager("show all without labels");

roiManager("Combine");

roiManager("Add");

newcount=roiManager("Count")-1;

deleteroi=Array.getSequence(newcount);

roiManager("Select", deleteroi);

roiManager("Delete");

roiManager("Select", 0);
}

//Or select single ROI for non-fragmented cortex region

else
{roiManager("Select", 0);}

run("Clear Results");

//Temporarily save ROI

roiManager("Select", 0);
roiManager("Save", regiondir+"TempQuad4.roi");


//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Close quad 4 image 

selectImage(quad4);
close();

//Close cortical image 

selectImage(cortical);
close();


//Adjust temp regions to match any inclusions from border-------------------------------------

//Reopen ROIs on original image

selectImage(origimg);
run("Select None");
run("Remove Overlay");

roiManager("Open", regiondir+"TempQuad1.roi"); 
roiManager("Open", regiondir+"TempQuad2.roi");
roiManager("Open", regiondir+"TempQuad3.roi"); 
roiManager("Open", regiondir+"TempQuad4.roi");  

showStatus("!Confirming Regions Match Border...");

//Combine the regions 

roiManager("Select", newArray(0,1,2,3));
roiManager("XOR");
roiManager("Add");

//Create region mask

mergeindex=roiManager("Count")-1;

roiManager("Select", mergeindex);

run("Create Mask");
rename("RegionMask");
regionmask = getTitle();

//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Reopen cortical area

roiManager("Open", borderpath); 

//For zip file, delete all from border zip file except the named border

roiend=roiManager("count")-1;

if (endsWith(borderpath, "zip")){
for (i=roiManager("count")-1; i>roiend; i--){
	roiManager("Select",i);
	if(RoiManager.getName(i) != bordername){roiManager("delete")};
};
}

//Re-identify border index

borderindex = RoiManager.getIndex(bordername);

//Create border mask

roiManager("Select", borderindex);

run("Create Mask");
rename("BorderMask");
bordermask = getTitle();

//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Get difference between bordermask and regionmask

imageCalculator("Difference create", bordermask,regionmask);
diffmask = getTitle();

//Close mask images

selectImage(bordermask);
close();

selectImage(regionmask);
close();

//Loop to adjust regions 

tempregionarray= newArray("TempQuad1.roi","TempQuad2.roi","TempQuad3.roi","TempQuad4.roi");

//r=0;
for(r = 0; r<tempregionarray.length; r++){

//Duplicate diffmask

selectImage(diffmask);
run("Select None");
run("Remove Overlay");
run("Duplicate...", "title=[diffmaskregion]");

diffmaskregion=getImageID();

//Reopen region and clear outside on diffmask

roiManager("Open", regiondir+tempregionarray[r]); 

roiManager("Select", 0);
setBackgroundColor(0, 0, 0);
run("Clear Outside");

//Analyze particles to get border inclusions associated with region
roiManager("Deselect");

selectImage(diffmaskregion); 
run("Remove Overlay");
run("Select None");

run("Analyze Particles...", "display add");

if (roiManager("Count")>1){

//If any particles, combine particles with region 

roiManager("XOR");
roiManager("Add");

//Delete all except new last region 

newcount=roiManager("count")-1;

deleteroi=Array.getSequence(newcount);

roiManager("Select", deleteroi);

roiManager("Delete");

//Save new region over original temp region

roiManager("Select", 0);

roiManager("Save", regiondir+tempregionarray[r]); 

}

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}


//Clear results 

run("Clear Results");

//Delete temp region particles

selectImage(diffmaskregion);
close();

//End loop through region
}

//Close difference mask

selectImage(diffmask);
close();

//Display and name regions-------------------------------------

//Reopen ROIs on original image

selectImage(origimg);
run("Select None");
run("Remove Overlay");

setBatchMode("show");

origimg = getTitle();

roiManager("Open", regiondir+"TempQuad1.roi"); 
roiManager("Open", regiondir+"TempQuad2.roi");
roiManager("Open", regiondir+"TempQuad3.roi"); 
roiManager("Open", regiondir+"TempQuad4.roi");  


//Use labels as names 

run("Labels...", "color=black font=14 show draw bold back");
roiManager("UseNames", "true");

roiManager("Select", 0);
roiManager("Rename", "Quadrant_1");
roiManager("Set Color", "red");

roiManager("Select", 1);
roiManager("Rename", "Quadrant_2");
roiManager("Set Color", "blue");

roiManager("Select", 2);
roiManager("Rename", "Quadrant_3");
roiManager("Set Color", "yellow");

roiManager("Select", 3);
roiManager("Rename", "Quadrant_4");
roiManager("Set Color", "green");

selectImage(origimg);
roiManager("Show None");
roiManager("Show All with labels");


var regionstop = "regionredo";

//Do-while loop for user to rename quadrants

do {

//Dialog for quadrants set by anatomical orientation (directional display)

if (tilt == "Section Alignment With Image Borders"){
	
var regiontop = call("ij.Prefs.get", "regiontop.string", "Anterior");
var regionleft = call("ij.Prefs.get", "regionleft.string", "Lateral");
var regionright = call("ij.Prefs.get", "regionright.string", "Medial");
var regionbottom = call("ij.Prefs.get", "regionbottom.string", "Posterior");

orientation=newArray("Anterior", "Posterior", "Medial", "Lateral", "Superior", "Inferior", "Custom");

Dialog.createNonBlocking("Quadrant Naming");
Dialog.setInsets(0, 50, 0)
Dialog.addMessage("Choose anatomical regions as they appear on the image:", 14,"#00008B");
Dialog.addMessage("");
Dialog.setInsets(0, 85, 5)
Dialog.addChoice("", orientation, regiontop);
Dialog.setInsets(5, 0, 5)
Dialog.addChoice("Orientation:", orientation, regionleft);
Dialog.addToSameRow();
Dialog.setInsets(5, 0, 5)
Dialog.addChoice("", orientation, regionright);
Dialog.setInsets(5, 85, 5)
Dialog.addChoice("", orientation, regionbottom);
Dialog.show();

//Get user choices

regionname1 = Dialog.getChoice();
call("ij.Prefs.set", "regiontop.string", regionname1);

regionname4 = Dialog.getChoice();
call("ij.Prefs.set", "regionleft.string", regionname4);

regionname2 = Dialog.getChoice();
call("ij.Prefs.set", "regionright.string", regionname2);

regionname3 = Dialog.getChoice();
call("ij.Prefs.set", "regionbottom.string", regionname3);

}

//Dialog for quadrants set by major axis (no directional display)

else{

orientation=newArray("Anterior", "Posterior", "Medial", "Lateral", "Superior", "Inferior", "Custom");

var regionname1 = call("ij.Prefs.get", "regionname1.string", "Anterior");
var regionname2 = call("ij.Prefs.get", "regionname2.string", "Lateral");
var regionname3 = call("ij.Prefs.get", "regionname3.string", "Medial");
var regionname4 = call("ij.Prefs.get", "regionname4.string", "Posterior");

Dialog.createNonBlocking("Quadrant Naming");
Dialog.setInsets(0, 0, 0)
Dialog.addMessage("Choose anatomical regions", 14,"#00008B");
Dialog.setInsets(-5, 0, 0)
Dialog.addMessage("as they appear on the image:", 14,"#00008B");
Dialog.setInsets(5, 0, 5)
Dialog.addChoice("Quadrant 1 :", orientation, regionname1);
Dialog.setInsets(5, 0, 5)
Dialog.addChoice("Quadrant 2 :", orientation, regionname2);
Dialog.setInsets(5, 0, 5)
Dialog.addChoice("Quadrant 3 :", orientation, regionname3);
Dialog.setInsets(5, 0, 5)
Dialog.addChoice("Quadrant 4: ", orientation, regionname4);
Dialog.show();

//Get user choices

regionname1 = Dialog.getChoice();
call("ij.Prefs.set", "regionname1.string", regionname1);
regionname2 = Dialog.getChoice();
call("ij.Prefs.set", "regionname2.string", regionname2);
regionname3 = Dialog.getChoice();
call("ij.Prefs.set", "regionname3.string", regionname3)
regionname4 = Dialog.getChoice();
call("ij.Prefs.set", "regionname4.string", regionname4);

	
}

//Loop for custom user-entered names

if(regionname1 == "Custom" || regionname2 == "Custom" || regionname3 == "Custom" || regionname4 == "Custom"){

loopcount=0;

Dialog.createNonBlocking("Custom Quadrant Name Entry");
Dialog.setInsets(0, 0, 0)
Dialog.addMessage("Enter custom region names:", 14,"#00008B");

if(regionname1 == "Custom")
{Dialog.setInsets(5, 0, 0);
Dialog.addString("Quadrant 1 : ", "");
loopcount=loopcount+1;}
else
{Dialog.setInsets(5, 0, 0);
Dialog.addMessage("Quadrant 1 : " + regionname1);
}

if(regionname2 == "Custom")
{Dialog.setInsets(5, 0, 0);
Dialog.addString("Quadrant 2 :", "");
loopcount=loopcount+1;}
else
{Dialog.setInsets(5, 0, 0);
Dialog.addMessage("Quadrant 2 : " + regionname2);}

if(regionname3 == "Custom")
{Dialog.setInsets(5, 0, 0);
Dialog.addString("Quadrant 3 :", "");
loopcount=loopcount+1;}
else
{Dialog.setInsets(5, 0, 0);
Dialog.addMessage("Quadrant 3 : " +regionname3);}

if(regionname4 == "Custom")
{Dialog.setInsets(5, 0, 0);
Dialog.addString("Quadrant 4 :", "");
loopcount=loopcount+1;}
else
{Dialog.setInsets(5, 0, 0);
Dialog.addMessage("Quadrant 4 : " +regionname4);}

Dialog.show();

//Fill an array with the entered strings

loopout = newArray(loopcount);

for(i = 0; i<loopcount; i++){
looptemp = Dialog.getString();
loopout[i] = looptemp;
}

//Make an array of current names of regions

regionarray=newArray(regionname1,regionname2,regionname3,regionname4);

//Loop through the region name array and replace each next instance of "Custom" with the next instance of the custom string from loopout

loopoutpos=0;

for(i = 0; i<regionarray.length; i++){
	name=regionarray[i];
	if(name == "Custom"){
	regionarray[i] = loopout[loopoutpos];
	loopoutpos=loopoutpos+1;
	}
}

//Rename regions from the corrected regionarray

regionname1=regionarray[0];
regionname2=regionarray[1];
regionname3=regionarray[2];
regionname4=regionarray[3];

//Custom value correction end
}

//Rename ROIs

roiManager("Select", 0);
roiManager("Rename", regionname1);

roiManager("Select", 1);
roiManager("Rename", regionname2);

roiManager("Select", 2);
roiManager("Rename", regionname3);

roiManager("Select", 3);
roiManager("Rename", regionname4);

selectImage(origimg);
roiManager("Show None");
roiManager("Show All with labels");

//Ask user to inspect region names

Dialog.createNonBlocking("Confirm Quadrant Naming");
Dialog.setInsets(5, 0, 5)
Dialog.addRadioButtonGroup("Are you satisfied with quadrant labels?",  newArray("Yes, Proceed", "No, Rename Regions"), 2, 1, "Yes, Proceed");

Dialog.show();

regionredochoice= Dialog.getRadioButton();

if (regionredochoice == "No, Rename Regions"){

roiManager("Select", 0);
roiManager("Rename", "Quadrant_1");

roiManager("Select", 1);
roiManager("Rename", "Quadrant_2");

roiManager("Select", 2);
roiManager("Rename", "Quadrant_3");

roiManager("Select", 3);
roiManager("Rename", "Quadrant_4");

selectImage(origimg);
roiManager("Show None");
roiManager("Show All with labels");

regionredo = "regionredo";

}

else{

regionstop = "regionstop";

}
}

while (regionstop=="regionredo");

//Silence batch mode

setBatchMode("hide");

//Reset quadrant ROIs to blank color and fill and save to region subfolders, but do not close

roiManager("Select", 0);
roiManager("Set Color", "cyan");

roiManager("Select", 1);
roiManager("Set Color", "cyan");

roiManager("Select", 2);
roiManager("Set Color", "cyan");

roiManager("Select", 3);
roiManager("Set Color", "cyan");

selectImage(origimg);
roiManager("Show None");
roiManager("Show All with labels");

//Save ROIs to output folders

roiManager("Select",0);
roiManager("Save", regiondir+origname+"_"+regionname1+".roi");
roiManager("deselect");

roiManager("Select",1);
roiManager("Save", regiondir+origname+"_"+regionname2+".roi");
roiManager("deselect");

roiManager("Select",2);
roiManager("Save", regiondir+origname+"_"+regionname3+".roi");
roiManager("deselect");

roiManager("Select",3);
roiManager("Save", regiondir+origname+"_"+regionname4+".roi");
roiManager("deselect");


//Delete temp ROIs

File.delete(regiondir+"TempQuad1.roi");
File.delete(regiondir+"TempQuad2.roi");
File.delete(regiondir+"TempQuad3.roi");
File.delete(regiondir+"TempQuad4.roi");

selectWindow("Log");
run("Close");

//Clear results 

run("Clear Results");

//End regional subdivision for long bones
}

//Regional subdivision for ribs ******************************************************************************************************


if (bonetype == "Rib"){
	

//Set scale for cross-sectional geometry according to user input in um

run("Set Scale...", "distance=scale known=1 pixel=1 unit=mm global");

//Run BoneJ Slice Geometry 

selectImage(cortical);
run("Select None");
run("Remove Overlay");


selectImage(cortical);
run("Slice Geometry", "bone=unknown bone_min=1 bone_max=255 slope=0.0000 y_intercept=0");

//Hide results window 
selectWindow("Results");
setLocation(screenWidth, screenHeight);

selectImage(cortical);
getPixelSize(unit, pw, ph);

//Get image width and height - these are in pixels regardless of scale

w = getWidth();
h = getHeight();

//Get row numbers of columns

selectWindow("Results");
text = getInfo();
lines = split(text, "\n");
columns = split(lines[0], "\t");

if (columns[0]==" ")
 columns[0]= "Number";

//Pull variables from BoneJ results table and divide by pixel size
cX= getResult(columns[5],0)/pw;
cY = getResult(columns[6],0)/pw;

th = getResult(columns[10],0);
rMin = getResult(columns[11],0)/pw;
rMax = getResult(columns[12],0)/pw;
thPi = th + PI / 2;

//Define major axis

Majorx1 = floor(cX - cos(-th) * 1.5 * rMax);
Majory1 = floor(cY + sin(-th) * 1.5 * rMax);
Majorx2 = floor(cX + cos(-th) * 1.5 * rMax);
Majory2 = floor(cY - sin(-th) * 1.5 * rMax);

//drawLine(Majorx1, Majory1, Majorx2, Majory2);

//Define minor axis

Minorx1 = floor(cX - cos(thPi) * 2 * rMin);
Minory1 = floor(cY - sin(thPi) * 2 * rMin);
Minorx2 = floor(cX + cos(thPi) * 2 * rMin);
Minory2 = floor(cY + sin(thPi) * 2 * rMin);

var x1 = "";
var y1 = "";
var x2 = "";
var y2 = "";

var linestop = "lineredo";

selectImage(origimg);
setBatchMode("show");
run("Select None");
run("Remove Overlay");

do {

//Erase ROIs 

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}
	
//Draw the major axis 

selectImage(origimg);
makeLine(Majorx1,Majory1,Majorx2,Majory2,30);
Roi.setStrokeColor("cyan")
roiManager("Add");
roiManager("Show All without labels");

//Ask user to inspect regional subdivision

Dialog.createNonBlocking("Confirm Regional Subdivision");
Dialog.setInsets(5, 0, 5)
Dialog.addRadioButtonGroup("Are you satisfied with cutaneous / pleural subdivision?",  newArray("Yes, Proceed", "No, Use Minor Axis"), 2, 1, "Yes, Proceed");

Dialog.show();

lineswap= Dialog.getRadioButton();

//If user chooses to proceed with major axis, exit do while loop

if (lineswap == "Yes, Proceed"){
	x1 = Majorx1;
	y1= Majory1;
	x2 = Majorx2;
	y2 = Majory2;
	
	linestop = "linestop";
	}
else{linestop = "lineredo";}

//Swap names if chosen by user

if (lineswap == "No, Use Minor Axis"){

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Draw the minor axis 

selectImage(origimg);
makeLine(Minorx1,Minory1,Minorx2,Minory2,30);
Roi.setStrokeColor("cyan")
roiManager("Add");
roiManager("Show All without labels");

//Ask user to inspect regional subdivision

Dialog.createNonBlocking("Confirm Regional Subdivision");
Dialog.setInsets(5, 0, 5)
Dialog.addRadioButtonGroup("Are you satisfied with cutaneous / pleural subdivision?",  newArray("Yes, Proceed", "No, Use Major Axis"), 2, 1, "Yes, Proceed");

Dialog.show();

lineswapredo= Dialog.getRadioButton();

//If user chooses to proceed, exit do while loop
//If user chooses to revert to major axis, the loop will repeat

if (lineswapredo == "Yes, Proceed"){

	x1 = Minorx1;
	y1= Minory1;
	x2 = Minorx2;
	y2 = Minory2;
	linestop = "linestop";
	}
else{linestop = "lineredo";}

}

}


while (linestop=="lineredo");

showStatus("!Creating Region Halves...");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Hide cortical image again 

selectImage(origimg);
setBatchMode("hide");

//Duplicate image for drawing the major axis on the slice

selectImage(cortical);
run("Select None");
run("Remove Overlay");
run("Duplicate...", "title=[Drawn]");

drawhalf=getImageID();

//Change foreground to black

run("Colors...", "foreground=black background=black selection=cyan");
run("Line Width...", "line=1");

//Drawn major axis on the duplicate

selectImage(drawhalf);
run("Select None");
run("Remove Overlay");
makeLine(x1, y1, x2, y2);
run("Draw");
run("Add Selection...");
run("Select None");

//Change foreground back to white 

run("Colors...", "foreground=white background=black selection=cyan");

//Create folder subdivision for regional output 

regiondir=cfodir+"/WMGL Regions/";
File.makeDirectory(regiondir); 

selectImage(drawhalf);
saveAs("TIFF", regiondir+origname+"_"+"DrawnHalves.tif");

drawhalf=getImageID();
selectImage(drawhalf);
close();

//Duplicate cortical image 

selectImage(cortical); run("Duplicate...", "title=[Region1]");
region1=getImageID();

selectImage(cortical); run("Duplicate...", "title=[Region2]");
region2=getImageID();

//Determine how the image is oriented with the long dimension of the rib 
//Vertically (height > width) or horizontally (width>height)
//Note: The axis drawn by the BoneJ macro is incorrect and extends the major axis beyond image bounds
//This corrected axis drawing will not match BoneJ macro axis output

setBackgroundColor(0, 0, 0);

setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");



if (w>=h){

//Draw the top polygon on the horizontally oriented image
//x1,0 is the top left corner
//x1,0 is the top right corner

selectImage(region1);
makePolygon(x1,0,x2,0,x2,y2,x1,y1);
run("Create Mask");
run("Create Selection");
close();
//selectImage(id);
run("Restore Selection");
roiManager("Add");

run("Clear Outside");
setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");


//Draw the bottom polygon on the horizontally oriented image
//x1,h is the bottom left corner
//x2,h is the bottom right corner

selectImage(region2);
makePolygon(x1,h,x2,h,x2,y2,x1,y1);
run("Create Mask");
run("Create Selection");
close();
//selectImage(id);
run("Restore Selection");
roiManager("Add");


run("Clear Outside");
setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");


}
else 
{

//Draw the left polygon on the vertically oriented image
//0,y1 is upper left corner
//0,y2 is lower left corner

selectImage(region1);
makePolygon(0,y1,0,y2,x2,y2,x1,y1);
run("Create Mask");
run("Create Selection");
close();
//selectImage(id);
run("Restore Selection");
roiManager("Add");


run("Clear Outside");
setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");


//Draw the right polygon on the vertically oriented image
//w,y1 is upper right corner
//w,y2 is lower right corner

selectImage(region2);
makePolygon(w,y1,w,y2,x2,y2,x1,y1);
run("Create Mask");
run("Create Selection");
close();
//selectImage(id);
run("Restore Selection");
roiManager("Add");


run("Clear Outside");
setAutoThreshold("Default dark");
//run("Threshold...");
setThreshold(1,255);
setOption("BlackBackground", true);
run("Convert to Mask");


}

//Clear results 

run("Clear Results");

//Clear ROI

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Region 1 measurement

//Analyze particles

selectImage(region1); 
run("Remove Overlay");
run("Select None");

run("Analyze Particles...", "display clear add");

//Combine multiple ROIs for fragmented cortex region

var roicount = "";

roicount=roiManager("Count");

if (roicount>1){

roiManager("show all without labels");

roiManager("Combine");

roiManager("Add");

newcount=roiManager("Count")-1;

deleteroi=Array.getSequence(newcount);

roiManager("Select", deleteroi);

roiManager("Delete");

roiManager("Select", 0);
}

//Or select single ROI for non-fragmented cortex region

else
{roiManager("Select", 0);}



//Temporarily save ROI

roiManager("Select", 0);
roiManager("Save", regiondir+"TempRegion1.roi");

//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Close region 1 image 

selectImage(region1);
close();


//Region 2 measurement

//Analyze particles

selectImage(region2); 
run("Remove Overlay");
run("Select None");

run("Analyze Particles...", "display clear add");

//Combine multiple ROIs for fragmented cortex region

var roicount = "";

roicount=roiManager("Count");

if (roicount>1){

roiManager("show all without labels");

roiManager("Combine");

roiManager("Add");

newcount=roiManager("Count")-1;

deleteroi=Array.getSequence(newcount);

roiManager("Select", deleteroi);

roiManager("Delete");

roiManager("Select", 0);
}

//Or select single ROI for non-fragmented cortex region

else
{roiManager("Select", 0);}



//Temporarily save ROI

roiManager("Select", 0);
roiManager("Save", regiondir+"TempRegion2.roi");

//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Close region 2 image 

selectImage(region2);
close();


//Adjust temp regions to match any inclusions from border-------------------------------------

//Reopen ROIs on original image

selectImage(origimg);
run("Select None");
run("Remove Overlay");

roiManager("Open", regiondir+"TempRegion1.roi"); 
roiManager("Open", regiondir+"TempRegion2.roi");

showStatus("!Confirming Regions Match Border...");

//Combine the regions 

roiManager("Select", newArray(0,1));
roiManager("XOR");
roiManager("Add");

//Create region mask

mergeindex=roiManager("Count")-1;

roiManager("Select", mergeindex);

run("Create Mask");
rename("RegionMask");
regionmask = getTitle();

//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Reopen cortical area

roiManager("Open", borderpath); 

//For zip file, delete all from border zip file except the named border

roiend=roiManager("count")-1;

if (endsWith(borderpath, "zip")){
for (i=roiManager("count")-1; i>roiend; i--){
	roiManager("Select",i);
	if(RoiManager.getName(i) != bordername){roiManager("delete")};
};
}

//Re-identify border index

borderindex = RoiManager.getIndex(bordername);

//Create border mask

roiManager("Select", borderindex);

run("Create Mask");
rename("BorderMask");
bordermask = getTitle();

//Clear results 

run("Clear Results");

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Get difference between bordermask and regionmask

imageCalculator("Difference create", bordermask,regionmask);
diffmask = getTitle();

//Close mask images

selectImage(bordermask);
close();

selectImage(regionmask);
close();

//Loop to adjust regions 

tempregionarray= newArray("TempRegion1.roi","TempRegion2.roi");

//r=0;
for(r = 0; r<tempregionarray.length; r++){

//Duplicate diffmask

selectImage(diffmask);
run("Select None");
run("Remove Overlay");
run("Duplicate...", "title=[diffmaskregion]");

diffmaskregion=getImageID();

//Reopen region and clear outside on diffmask

roiManager("Open", regiondir+tempregionarray[r]); 

roiManager("Select", 0);
setBackgroundColor(0, 0, 0);
run("Clear Outside");

//Analyze particles to get border inclusions associated with region
roiManager("Deselect");

selectImage(diffmaskregion); 
run("Remove Overlay");
run("Select None");

run("Analyze Particles...", "display add");

if (roiManager("Count")>1){

//If any particles, combine particles with region 

roiManager("XOR");
roiManager("Add");

//Delete all except new last region 

newcount=roiManager("count")-1;

deleteroi=Array.getSequence(newcount);

roiManager("Select", deleteroi);

roiManager("Delete");

//Save new region over original temp region

roiManager("Select", 0);

roiManager("Save", regiondir+tempregionarray[r]); 

}

//Clear ROI manager

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}


//Clear results 

run("Clear Results");

//Delete temp region particles

selectImage(diffmaskregion);
close();

//End loop through region
}

//Close difference mask

selectImage(diffmask);
close();

//Display and name regions-------------------------------------


//Reopen ROIs 

roiManager("Open", regiondir+"TempRegion1.roi"); 
roiManager("Open", regiondir+"TempRegion2.roi");

////Guess cutaneous vs. pleural orientation 

//Set measurements to include area and shape descriptors

run("Set Measurements...", "area shape redirect=None decimal=9");

//Measure area and shape descriptors for each region

roiManager("Deselect");
roiManager("Measure");

var regionCA1 = "";
var regionCA2 = "";

regionCA1 = getResult("Area",0);
Circ1 = getResult("Circ.",0);

regionCA2 = getResult("Area",1);
Circ2 = getResult("Circ.",1);

//Test whether region 1 or region 2 has higher circularity (likely pleural)

var region1guess = "";
var region1alt = "";
var region1fin = "";
var region2guess = "";
var region2alt = "";
var region2fin = "";

if (Circ1>Circ2){
	region1guess = "Pleural";
	region1alt = "Cutaneous";
	region2guess = "Cutaneous";
	region2alt = "Pleural";
	}
else{
	region1guess = "Cutaneous";
	region1alt = "Pleural";
	region2guess = "Pleural";
	region2alt = "Cutaneous";
}


//Close cortical image 

selectImage(cortical);
close();

//Superimpose on original image 

selectImage(origimg);
run("Select None");
run("Remove Overlay");

setBatchMode("show");

origimg = getTitle();

var regionstop = "regionredo";

do {

//Use labels as names 

run("Labels...", "color=black font=14 show draw bold back");
roiManager("UseNames", "true");

//Rename ROIs based on guess

roiManager("Select", 0);
roiManager("Rename", region1guess);
roiManager("Set Color", "red");

roiManager("Select", 1);
roiManager("Rename", region2guess);
roiManager("Set Color", "blue");

selectImage(origimg);
roiManager("Show None");
roiManager("Show All with labels");

//Ask user to inspect region names

Dialog.createNonBlocking("Confirm Rib Region Naming");
Dialog.setInsets(5, 0, 5)
Dialog.addRadioButtonGroup("Are you satisfied with rib region labels?",  newArray("Yes, Proceed", "No, Swap Names"), 2, 1, "Yes, Proceed");

Dialog.show();

regionswap= Dialog.getRadioButton();

//If user chooses to proceed with guessed names, exit do while loop

if (regionswap == "Yes, Proceed"){
	region1fin = region1guess;
	region2fin = region2guess;
	regionstop = "regionstop";
	}
else{regionstop = "regionredo";}

//Swap names if chosen by user

if (regionswap == "No, Swap Names"){

roiManager("Select", 0);
roiManager("Rename", region1alt);

roiManager("Select", 1);
roiManager("Rename", region2alt);

selectImage(origimg);
roiManager("Show None");
roiManager("Show All with labels");

//Ask user to inspect region names

Dialog.createNonBlocking("Confirm Rib Region Naming");
Dialog.setInsets(5, 0, 5)
Dialog.addRadioButtonGroup("Are you satisfied with rib region labels?",  newArray("Yes, Proceed", "No, Swap Names"), 2, 1, "Yes, Proceed");

Dialog.show();

regionswapredo= Dialog.getRadioButton();

//If user chooses to proceed, exit do while loop
//If user chooses to revert the labels to the original, the loop will repeat

if (regionswapredo == "Yes, Proceed"){
	region1fin = region1alt;
	region2fin = region2alt;
	regionstop = "regionstop";}
else{regionstop = "regionredo";}

}

}


while (regionstop=="regionredo");

//Silence batch mode

setBatchMode("hide");

//Reset rib ROIs to neutral color cyan and fill and save to region subfolders, but do not close

roiManager("Select", 0);
roiManager("Set Color", "cyan");

roiManager("Select", 1);
roiManager("Set Color", "cyan");

selectImage(origimg);
roiManager("Show None");
roiManager("Show All with labels");

//Save ROIs to output folders

roiManager("Select",0);
roiManager("Save", regiondir+origname+"_"+region1fin+".roi");
roiManager("deselect");

roiManager("Select",1);
roiManager("Save", regiondir+origname+"_"+region2fin+".roi");
roiManager("deselect");

//Delete temp ROIs

File.delete(regiondir+"TempRegion1.roi");
File.delete(regiondir+"TempRegion2.roi");

selectWindow("Log");
run("Close");

//Clear results 

run("Clear Results");

}

//End Create New Regions From Cortical Border
}

//Load regions from folder****************************************************************************************************************

if (regionchoice == "Load Folder of Region .roi Files"){

showStatus("!Loading Regions From Folder...");
	
//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Create LUT from grayscale image for displaying as many regions as needed 

selectImage(origimg_gray);
//Confirm 8-bit
run("8-bit");

//Recolor regions
roiColors= loadLutColors("glasbey on dark");

//Revert to grayscale

selectImage(origimg_gray);
run("Grays");

//Reopen ROIs on original image

selectImage(origimg);
run("Select None");
run("Remove Overlay");

setBatchMode("show");

origimg = getTitle();

for (i=regionpath.length-1; i>=0; i--) {
roiManager("Open", regiondir+regionpath[i]); 
}

//Guess regions from list of anatomical names

regionmatch=newArray(
"Anterior", 
"Posterior",
"Medial",
"Lateral",
"Superior",
"Inferior",
"SuperiorAnterior",
"SuperiorPosterior",
"SuperiorMedial",
"SuperiorLateral",
"InferiorAnterior",
"InferiorPosterior",
"InferiorMedial",
"InferiorLateral",
"AnteriorMedial",
"AnteriorLateral",
"PosteriorMedial",
"PosteriorLateral",
"Superior Anterior",
"Superior Posterior",
"Superior Medial",
"Superior Lateral",
"Inferior Anterior",
"Inferior Posterior",
"Inferior Medial",
"Inferior Lateral",
"Anterior Medial",
"Anterior Lateral",
"Posterior Medial",
"Posterior Lateral",
"Superoanterior",
"Superoposterior",
"Superomedial",
"Superolateral",
"Inferoanterior",
"Inferoposterior",
"Inferomedial",
"Inferolateral",
"Anteromedial",
"Anterolateral",
"Posteromedial",
"Posterolateral",
"Cutaneous",
"Pleural");

//Set empty array to collect region names

var regionload = newArray();

//Loop through loaded regions
for (i=0; i < roiManager("count"); i++) {

roiManager("Select", i);
regionloadname = RoiManager.getName(i);

//Append group number to set color based on LUT
roiManager("Select", i);
roiManager("Set Color", roiColors[i+1]);

//Trigger for no match to named region	
nomatch = true;

//Loop through named region array to try to match
for(j=0; j < regionmatch.length; j++){ 

//Append to array if it matches that region
if(matches(regionloadname,regionmatch[j]))
{
	regionload = Array.concat(regionload,regionmatch[j]);
	nomatch = false;
//End append to array if it matches that named region 
}
//End loop through named region array to try to match
}
//If none of the named regions match, add a numeric region
if(nomatch == true)
{
	regionload = Array.concat(regionload,"Region_"+i+1);
	//Rename in ROI manager 
	roiManager("Select", i);
	roiManager("Rename", "Region_"+i+1);
}

//End loop through region paths	
}

//Show ROIs on original image

selectImage(origimg);
run("Select None");
run("Remove Overlay");

setBatchMode("show");

origimg = getTitle();

//Use labels as names 

run("Labels...", "color=black font=14 show draw bold back");
roiManager("UseNames", "true");

selectImage(origimg);
roiManager("Show None");
roiManager("Show All with labels");

var regionstop = "regionredo";

//Do-while loop for user to rename quadrants

do {

//Allow user to adjust region names

loopcount=0;

Dialog.createNonBlocking("Set Region Names");

Dialog.setInsets(0,0,0)
Dialog.addMessage("Modify Detected Region Names",14,"#00008B");

for(k=0; k < regionload.length; k++){ 
Dialog.addString(regionload[k], regionload[k]);
loopcount=loopcount+1;
}

Dialog.show();

//Update array with the entered strings

for(i = 0; i<loopcount; i++){
looptemp = Dialog.getString();
regionload[i] = looptemp;
//Update the region name 
roiManager("Select", i);
roiManager("Rename", looptemp);
}

//Redisplay changed names 

selectImage(origimg);
roiManager("Show None");
roiManager("Show All with labels");

//Ask user to inspect region names

Dialog.createNonBlocking("Confirm Region Naming");
Dialog.setInsets(5, 0, 5)
Dialog.addRadioButtonGroup("Are you satisfied with region labels?",  newArray("Yes, Proceed", "No, Rename Regions"), 2, 1, "Yes, Proceed");

Dialog.show();

regionredochoice= Dialog.getRadioButton();

if (regionredochoice == "Yes, Proceed"){regionstop = "regionstop";}

}

while (regionstop=="regionredo");

//Re-hide image 
selectImage(origimg);

setBatchMode("hide");

//End load regions from folder
}

//Get region and border names and indices from ROI manager ******************************************************************************************************

if (regionchoice != "Do Not Subdivide Regions"){

//Sort in alphabetical order 
roiManager("sort");

var regionlist = newArray();
var regionindex = newArray();

for (i=0; i < roiManager("count"); i++) {
	regionname = RoiManager.getName(i);
	regionlist = Array.concat(regionlist,regionname);
	regionindex = Array.concat(regionindex,RoiManager.getIndex(regionname));
}

//Reopen border path with regions still open

roiend=roiManager("count")-1;

roiManager("Open", borderpath); 

//For zip file, delete all from border zip file except the named border

if (endsWith(borderpath, "zip")){
for (i=roiManager("count")-1; i>roiend; i--){
	roiManager("Select",i);
	if(RoiManager.getName(i) != bordername){roiManager("delete")};
};
}

//Re-identify border index

borderindex = RoiManager.getIndex(bordername);

//Append to loop list 

loopname = Array.concat(bordername, regionlist);
loopindex = Array.concat(borderindex, regionindex);

//End get region and border names and indices from ROI manager 
}

if (regionchoice == "Do Not Subdivide Regions"){

//For zip file, delete all from border zip file except the named border

if (endsWith(borderpath, "zip")){
for (i=roiManager("count")-1; i>=0; i--){
	roiManager("Select",i);
	if(RoiManager.getName(i) != bordername){roiManager("delete")};
};
}

loopname = newArray(bordername);
borderindex = RoiManager.getIndex(bordername);
loopindex = borderindex;
	
}


//Loops to calculate WMGL****************************************************************************************************************

//Use original RGB image so that the histogram does not scale within regions individually

selectImage(origimg);
run("Select None");
run("Remove Overlay");

//Remove scale from image to ensure counts in pixels

run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

//Create output table to hold histograms

hist="Histogram"; 
Table.create(hist);
//Hide window
selectWindow("Histogram");
setLocation(screenWidth, screenHeight);

pxvalues = Array.getSequence(256);

pxvalues[pxvalues.length] = "Total";

selectWindow(hist);
Table.setColumn("Pixel Brightness", pxvalues);

//Create output table to hold summary statistics

summary="Summary"; 
Table.create(summary);
//Hide window
selectWindow("Summary");
setLocation(screenWidth, screenHeight);

selectWindow(summary);

for (i=0; i < loopname.length; i++) {
//Repeating image name
Table.set("Image", i,origname);
//Loop names
Table.set("Region", i,loopname[i]);
}


//No pore removal----------------------------------------------------------------------

if(porechoice_none == true){
	
showStatus("!Calculating WMGL (No Pore Removal)...");
	
//Clear previous results 

run("Clear Results");

progstep = 1;

for (i=0; i < loopname.length; i++) {
	
	progstep = progstep + 1;
      			
    showProgress(progstep,loopname.length);
	
	//Clear previous results 

	run("Clear Results");
	
	//Get index from list 
	
	if(loopname.length>1){j = loopindex[i];}
	if(loopname.length==1){j = loopindex;}
	
	//Measure area in pixels
	
	roiManager("Select",j);
  
  	roiManager("Measure");
  	
  	//Hide results window 
	selectWindow("Results");
	setLocation(screenWidth, screenHeight);
	
	//Get area
  
  	roiarea = getResult("Area",0);
  	
  	//Clear previous results 

	run("Clear Results");

	//Set bin number to 256 for 8-bit 0-255 and get histogram
	
	roiManager("Select",j);

	nBins = 256;

	getHistogram(values, counts, nBins);

  //Calculate WMGL
  
  	wmgl = newArray();
  
  	wmgl_sum = 0;
  
  for (h=0; h<nBins; h++) {
  	
  	wmgl_bin = (values[h]*counts[h])/roiarea;
  	
  	wmgl[h] = wmgl_bin;
  	
  	wmgl_sum = wmgl_sum + wmgl_bin;
  	
  }

//Append WMGL to counts

counts[counts.length] = roiarea;

wmgl[wmgl.length] = wmgl_sum;

//Print to histogram table

selectWindow(hist);

//Print counts and WMGL for all
Table.setColumn(loopname[i]+" Counts (No Pores Removed)", counts);
Table.setColumn(loopname[i]+" WMGL (No Pores Removed)", wmgl);

//Print to summary table
selectWindow(summary);
Table.set("WMGL (No Pores Removed)", i,wmgl_sum);

//End loop through regions
}

//END No pore removal----------------------------------------------------------------------
}


//Ranged pore removal----------------------------------------------------------------------

if(porechoice_range == true){
	
showStatus("!Calculating WMGL (Pore Removal By Pixel Range)...");
	
//Clear previous results 

run("Clear Results");

progstep = 1;

for (i=0; i < loopname.length; i++) {
	
	progstep = progstep + 1;
      			
    showProgress(progstep,loopname.length);
	
	//Clear previous results 

	run("Clear Results");
	
	//Get index from list 
	
	if(loopname.length>1){j = loopindex[i];}
	if(loopname.length==1){j = loopindex;}
	
	//Measure area in pixels
	
	roiManager("Select",j);
  
  	roiManager("Measure");
  	
  	//Hide results window 
	selectWindow("Results");
	setLocation(screenWidth, screenHeight);
	
	//Get area
  
  	roiarea = getResult("Area",0);
  	
  	//Clear previous results 

	run("Clear Results");

	//Set bin number to 256 for 8-bit 0-255 and get histogram
	
	roiManager("Select",j);

	nBins = 256;

	getHistogram(values, counts, nBins);

  //Calculate WMGL
  
  	wmgl_range = newArray();
  
  	wmgl_sum_range = 0;
  	
  //Replace range with 0 and subtract counts from roiarea
  
  roiarea_range = roiarea;
  
  counts_range = counts;
  
   for (r=porechoice_range_start; r<porechoice_range_end+1; r++) {
  
  roiarea_range = roiarea_range - counts[r];
  
  counts_range[r] = 0;
  
   }
  
  //Calculate WMGL with the modified histogram
  
  for (h=0; h<nBins; h++) {
  	
  	wmgl_bin_range = (values[h]*counts_range[h])/roiarea_range;
  	
  	wmgl_range[h] = wmgl_bin_range;
  	
  	wmgl_sum_range = wmgl_sum_range + wmgl_bin_range;
  	
  }

//Append WMGL to counts

counts_range[counts_range.length] = roiarea_range;

wmgl_range[wmgl_range.length] = wmgl_sum_range;


//Print to histogram table

selectWindow(hist);

//Print counts and WMGL for all
Table.setColumn(loopname[i]+" Counts (Removed Pixel Range "+porechoice_range_start+"-"+porechoice_range_end+")", counts_range);
Table.setColumn(loopname[i]+" WMGL (Removed Pixel Range "+porechoice_range_start+"-"+porechoice_range_end+")", wmgl_range);

//Print to summary table
selectWindow(summary);
Table.set("WMGL (Removed Pixel Range "+porechoice_range_start+"-"+porechoice_range_end+")", i,wmgl_sum_range);

//End loop through regions
}

//END No pore removal----------------------------------------------------------------------
}

//Remove pore ROIs----------------------------------------------------------------------
if(porechoice_roi == true){
	
showStatus("!Calculating WMGL (Remove Pore ROIs)...");
	
//Clear previous results 

run("Clear Results");

//Select image with pores cleared 

selectImage(origimg_pores);
run("Select None");
run("Remove Overlay");

//Remove scale from image to ensure counts in pixels

run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

progstep = 1;

for (i=0; i < loopname.length; i++) {
	
	progstep = progstep + 1;
      			
    showProgress(progstep,loopname.length);
	
	//Clear previous results 

	run("Clear Results");
	
	//Get index from list 
	
	if(loopname.length>1){j = loopindex[i];}
	if(loopname.length==1){j = loopindex;}
	
	//Measure area in pixels
	
	selectImage(origimg_pores);
	run("Select None");
	run("Remove Overlay");
	
	roiManager("Select",j);
  
  	roiManager("Measure");
  	
  	//Hide results window 
	selectWindow("Results");
	setLocation(screenWidth, screenHeight);
	
	//Get area
  
  	roiarea = getResult("Area",0);
  	
  	//Clear previous results 

	run("Clear Results");

	//Set bin number to 256 for 8-bit 0-255 and get histogram
	
	nBins = 256;
	
	//Get histogram from image with pores cleared 

	selectImage(origimg_pores);
	run("Select None");
	run("Remove Overlay");
	
	roiManager("Select",j);

	getHistogram(values, counts, nBins);
	
	//Get histogram from white pore image

	selectImage(pores);
	run("Select None");
	run("Remove Overlay");
	
	roiManager("Select",j);
	
	getHistogram(pore_values, pore_counts, nBins);

	//White value corresponds to pore areas in this region 

	porearea = pore_counts[255];
	
	//Subtract pore area from 0 counts and from region area 
	
	roiarea_pores = roiarea - porearea;
	
	counts_pores = counts;
	
	counts_pores[0] = counts[0]-porearea;

  //Calculate WMGL
  
  	wmgl_pores = newArray();
  
  	wmgl_sum_pores = 0;
  
  for (h=0; h<nBins; h++) {
  	
  	wmgl_bin_pores = (values[h]*counts_pores[h])/roiarea_pores;
  	
  	wmgl_pores[h] = wmgl_bin_pores;
  	
  	wmgl_sum_pores = wmgl_sum_pores + wmgl_bin_pores;
  	
  }

//Append WMGL to counts

values[values.length] = "Total";

counts_pores[counts.length] = roiarea_pores;

wmgl_pores[wmgl_pores.length] = wmgl_sum_pores;

//Print to histogram table

selectWindow(hist);

//Print counts and WMGL for all
Table.setColumn(loopname[i]+" Counts (Pore ROIs Removed)", counts_pores);
Table.setColumn(loopname[i]+" WMGL (Pore ROIs Removed)", wmgl_pores);

//Print to summary table
selectWindow(summary);
Table.set("WMGL (Pore ROIs Removed)", i,wmgl_sum_pores);

//End loop through regions
}


//END Pore ROI removal----------------------------------------------------------------------
}

//Close images except grayscale and white pores

selectImage(origimg);
close();

//Save output table
selectWindow(hist);
saveAs("Text", cfodir+origname+" WMGL Histogram"+".csv");
run("Close");

//Save summary table
selectWindow(summary);
saveAs("Text", cfodir+origname+" WMGL Summary"+".csv");
run("Close");

//Colormap ******************************************************************************************************

if(mapchoice == true){
	
showStatus("!Generating Colormap...");

//Apply colormap
selectImage(origimg_gray);
run(lutlist_choice);

//Modify bins if selected-------------------------------------------------

if(binchoice == true){
	
//Get RGB arrays from LUT

getLut(reds, greens, blues);

//Bin LUT

redsclip = newArray(lutbins);
greensclip = newArray(lutbins);
bluesclip = newArray(lutbins);

for(i = 0; i < lutbins; i++) {
	index = floor(i * (256/lutbins));
	redsclip[i] = reds[index];
	greensclip[i] = greens[index];
	bluesclip[i] = blues[index];
        }

//Expand binned arrays back to 256 arrays

redsfull = newArray();
greensfull = newArray();
bluesfull = newArray();

for(i = 0; i < 256; i++) {
	expand = floor(i * lutbins/256);
	redsfull[i] = redsclip[expand];
	greensfull[i] = greensclip[expand];
	bluesfull[i] = bluesclip[expand];
}

//Apply modified LUT 

setLut(redsfull, greensfull, bluesfull);

//End modify bins if selected-------------------------------------------------
}

//Calibration bar

run("Calibration Bar...", "location=[Separate Image] fill=Black label=White number=10 decimal=0 font=9 zoom=25 overlay");
cbar = getTitle();

//Add floating scalebar-------------------------------------------------

//Clear ROI manager 

finalcount=roiManager("count")-1;

if(finalcount>=0){
roiManager("Deselect");
roiManager("Delete");
}

//Remove overlays
selectImage(origimg_gray);
run("Select None");
run("Remove Overlay");	

//Set scale according to user input

selectImage(origimg_gray);

run("Set Scale...", "distance="+scale_num+" known=1 unit="+unit_opts_choice);

//Add scalebar

scalethickness = scale_num/15; 
scalefont = scalethickness * 3;

run("Scale Bar...", "width=1 height=1 thickness=" + scalethickness + " font=" + scalefont + " color=White background=None location=[Lower Right] horizontal bold overlay");

//Capture scalebar as as ROI overlay

run("To ROI Manager");

scaleroi = "1 " + unit_opts_choice + " scalebar";

roiManager("select", 0);
roiManager("Rename", scaleroi);
roiManager("deselect");

roiManager("select", 1);
roiManager("Rename", "Scalebar Label");
roiManager("deselect");

selectImage(origimg_gray);
roiManager("Show All without labels");

//Save image 

selectImage(origimg_gray);
saveAs("tiff", cfodir+origname+" Colormap.tif");

origimg_gray_color = getTitle();

//Save colorbar

selectImage(cbar);
saveAs("tiff", cfodir+origname+" Colormap Scale.tif");
close();

//Generate version with pore ROIs removed-------------------------------------------------

if(porechoice_roi == true){
	
	selectImage(pores);
	run("Select None");
	run("Remove Overlay");
	
	//Subtract pores from grayscale image
	
	imageCalculator("Subtract create", origimg_gray_color,pores);
	origimg_gray_color_pores = getTitle();
	
	//Add on scalebar
	selectImage(origimg_gray_color_pores);
	roiManager("Show All without labels");
	
	//Save image 
	selectImage(origimg_gray_color_pores);
	saveAs("tiff", cfodir+origname+" Colormap Pores Removed.tif");
	close();
	
	//Close pores image 
	selectImage(pores);
	close();

//End remove pore ROIs-------------------------------------------------	
}

selectImage(origimg_gray_color);
close();

//End colormap creation	
}

//Window cleanup ******************************************************************************************************

//Close any remaining images

while (nImages>0) { 
          selectImage(nImages); 
          close(); 
}

//Clear any past results

run("Clear Results");
close("Results");

//Close results window 

if (isOpen("Results")) {
         selectWindow("Results");
         run("Close" );
    }

//Close any remaining windows

list = getList("window.titles");
 for (i=0; i<list.length; i++){
  winame = list[i];
  selectWindow(winame);
  run("Close");
   }
               
    
showStatus("!WMGL Analysis Complete!");

//End WMGL function
}



//Helper functions ******************************************************************************************************

function loadLutColors(lut) {
  run(lut);
  getLut(reds, greens, blues);
  hexColors= newArray(256);
  for (i=0; i<256; i++) {
      r= toHex(reds[i]); g= toHex(greens[i]); b= toHex(blues[i]);
      hexColors[i]= ""+ pad(r) +""+ pad(g) +""+ pad(b);
  }
  return hexColors;
}

function pad(n) {
  if (lengthOf(""+n)==1) n= "0"+n; return n;
}


//-----------------------------------------------------------------------------------------------------------------------------------------

function About() {

	if(isOpen("Log")==1) { selectWindow("Log"); run("Close"); }
	Dialog.create("About");
	Dialog.addMessage("Copyright (C) 2024 Mary E. Cole / CFO Tool \n \n Redistribution and use in source and binary forms, with or without \n modification, are permitted provided that the following conditions are met:\n \n 1. Redistributions of source code must retain the above copyright notice, \n this list of conditions and the following disclaimer.\n \n 2. Redistributions in binary form must reproduce the above copyright \nnotice, this list of conditions and the following disclaimer in the \ndocumentation and/or other materials provided with the distribution. \n \n 3. Neither the name of CFO Tool nor the names of its \n contributors may be used to endorse or promote products derived from \nthis software without specific prior written permission.\n \n This program is free software: you can redistribute it and/or modify \n it under the terms of the GNU General Public License as published by \nthe Free Software Foundation, either version 3 of the License, or \n any later version. \n \n This program is distributed in the hope that it will be useful, \n but WITHOUT ANY WARRANTY; without even the implied warranty of \n MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the \n GNU General Public License for more details.");
	Dialog.addHelp("http://www.gnu.org/licenses/");
	Dialog.show();
	
}

